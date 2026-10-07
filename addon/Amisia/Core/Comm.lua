-- Amisia comm: the addon message layer between Amisia clients. Two prefixes (control and data), an
-- envelope with the protocol number, packing of tables through the client's own encoding functions,
-- chunking and reassembly, a send queue with its own throttle per prefix that waits in the chat
-- lockdown and reads every send result, no sending in battlegrounds, receive limits per sender.
local ADDON, ns = ...

ns.SYNC_PROTO = 1        -- protocol of this client
ns.SYNC_MIN_PROTO = 1    -- the oldest protocol this client still reads

local PREFIX_CTRL, PREFIX_DATA = "Amisia", "AmisiaD"
local MAX_TEXT = 250     -- bytes of one message (the client takes 255)
local CHUNK = 200        -- Base64 characters per data part
local MAX_PARTS, MAX_PARTS_OP, MAX_PARTS_DK = 60, 8, 20
local MAX_UNPACKED = 65536

local MSG_BURST, MSG_REFILL = 10, 1        -- messages per prefix at once, then per second
local BYTE_BURST, BYTE_REFILL = 1000, 500  -- bytes of both prefixes at once, then per second
local CTRL_RESERVE = 260                   -- bytes a data part leaves for a waiting control message
local MAX_QUEUE = 200
local TICK = 0.25
local LOCK_POLL = 2
local DEFAULT_TTL = 60
local LOW_TTL = 120        -- entries of lowest priority (opts.low) fall after this unless told otherwise
local MAX_TRIES = 5

local SET_TTL = 30          -- seconds a part set waits for its next part
local SETS_PER_SENDER = 3
local DONE_KEEP = 60        -- seconds a finished set is remembered (late doubles start nothing)
local RECV_WINDOW, RECV_MAX = 10, 40
local BYTE_WINDOW, BYTE_MAX = 60, 20480
local IGNORE_FOR = 60
local OPEN_PARTS, OPEN_BYTES = 90, 18000   -- parts and Base64 bytes of the open sets of one sender
local OUTSIDER_FOR = 60     -- seconds the data parts of a sender outside the guild are dropped unread
-- seconds between two handled messages per sender; a new keeper's gathering (RQ with "G") apart
local KIND_GAP = { VQ = 300, RQ = 20, RQG = 20, UQ = 5, NW = 10, DV = 60, CV = 60 }
-- the same per first field: a drop question per week, a drop request per (first) bucket; a source
-- question per kind, a source request per kind and bucket
local KEYED_GAP = { DQ = 60, DR = 60, CQ = 60, CR = 60 }
local KEYED_MAX = 64        -- keyed gaps remembered per sender before the old ones are cleared

local CHANNELS = { RAID = true, GUILD = true, WHISPER = true }
local BLOB_ARTS = { SP = true, SO = true, OP = true, DK = true, CK = true }
-- parts a blob of an art may have (default MAX_PARTS)
local ART_PARTS = { OP = MAX_PARTS_OP, DK = MAX_PARTS_DK, CK = MAX_PARTS_DK }

local available = false
local stats = { sent = 0, failed = 0, dropped = 0, expired = 0, bad = 0, limited = 0, throttled = 0, received = 0 }
local newerProto

local function now() return GetTime() end

local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

---------------------------------------------------------------------------
-- Debug lines (sync.debug): grey, at most 20 a minute
---------------------------------------------------------------------------
local debugTimes = {}
local function debugLine(text, always)
    if not ns.Get("sync.debug") then return end
    local t = now()
    if not always then
        local keep = {}
        for _, at in ipairs(debugTimes) do
            if t - at < 60 then keep[#keep + 1] = at end
        end
        debugTimes = keep
        if #keep >= 20 then return end
        keep[#keep + 1] = t
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff999999Amisia Sync: " .. text .. "|r")
end

local noted = {}   -- reason -> time of the last debug note, once a minute
local function noteOnce(reason, text)
    local t = now()
    if noted[reason] and t - noted[reason] < 60 then return end
    noted[reason] = t
    debugLine(text)
end

-- A message as one debug line: kind and fields with spaces, a data part without its payload.
local function describe(kind, fields)
    if kind == "BL" then
        return ("BL %s %s %s %s/%s"):format(fields[1] or "?", fields[2] or "?", fields[3] or "?", fields[4] or "?", fields[5] or "?")
    end
    return kind .. (fields[1] and (" " .. table.concat(fields, " ")) or "")
end

---------------------------------------------------------------------------
-- Prefixes
---------------------------------------------------------------------------
-- What the client answered to each registration (the self-test shows it): the result, or the
-- error text of a raising call.
local prefixResults = {}

do
    local info = _G.C_ChatInfo
    local register = type(info) == "table" and info.RegisterAddonMessagePrefix
    if type(register) == "function" and type(info.SendAddonMessage) == "function" then
        available = true
        for _, prefix in ipairs({ PREFIX_CTRL, PREFIX_DATA }) do
            local ok, result = pcall(register, prefix)
            prefixResults[#prefixResults + 1] = { prefix = prefix, ok = ok, result = result }
            -- 0 success, 1 already registered; 2 invalid and 3 too many prefixes switch the layer off
            if not ok or (result ~= 0 and result ~= 1 and result ~= true) then available = false end
        end
        if not available then
            ns.msg("Addon-Nachrichten sind nicht verfügbar (Präfix nicht angemeldet). Sync und Versionsprüfung sind aus.")
        end
    end
end

-- Whether the message layer works at all (prefixes registered, the send function there).
function ns.CommAvailable() return available end

-- The prefixes and what their registration returned: { { prefix, ok, result } }; empty when the
-- client has no registration function.
function ns.CommPrefixResults()
    local out = {}
    for i, r in ipairs(prefixResults) do out[i] = { prefix = r.prefix, ok = r.ok, result = r.result } end
    return out
end

-- The layer works and the raid sync is switched on.
function ns.CommReady() return available and ns.Get("sync.enabled") ~= false end

-- Whether the client can pack tables (C_EncodingUtil with the six functions).
function ns.CommPacking()
    local api = _G.C_EncodingUtil
    if type(api) ~= "table" then return false end
    for _, f in ipairs({ "SerializeCBOR", "DeserializeCBOR", "CompressString", "DecompressString", "EncodeBase64", "DecodeBase64" }) do
        if type(api[f]) ~= "function" then return false end
    end
    return true
end

function ns.CommStats()
    local out = {}
    for k, v in pairs(stats) do out[k] = v end
    return out
end

-- The highest protocol number seen above the own one, or nil.
function ns.CommNewerProto() return newerProto end

---------------------------------------------------------------------------
-- Packing
---------------------------------------------------------------------------
local function deflate()
    local e = _G.Enum and Enum.CompressionMethod
    return e and e.Deflate or 0
end

-- A table as Base64 text (CBOR, Deflate, Base64), or nil and the reason.
function ns.CommPack(tbl)
    if not ns.CommPacking() then return nil, "Packen ist auf diesem Client nicht möglich." end
    if type(tbl) ~= "table" then return nil, "Keine Daten." end
    local api = C_EncodingUtil
    local ok, out = pcall(function()
        local raw = api.SerializeCBOR(tbl)
        local packed = type(raw) == "string" and api.CompressString(raw, deflate()) or nil
        return type(packed) == "string" and api.EncodeBase64(packed) or nil
    end)
    if not ok then report(out) return nil, "Packen fehlgeschlagen." end
    if type(out) ~= "string" or out == "" then return nil, "Packen fehlgeschlagen." end
    return out
end

-- The table of a Base64 text, or nil. Never raises.
function ns.CommUnpack(text)
    if not ns.CommPacking() or type(text) ~= "string" or text == "" then return nil end
    local api = C_EncodingUtil
    local ok, out = pcall(function()
        local packed = api.DecodeBase64(text)
        if type(packed) ~= "string" or packed == "" then return nil end
        local raw = api.DecompressString(packed, deflate())
        if type(raw) ~= "string" or raw == "" or #raw > MAX_UNPACKED then return nil end
        return api.DeserializeCBOR(raw)
    end)
    if not ok or type(out) ~= "table" then return nil end
    return out
end

-- Text cut into pieces of 200 characters.
function ns.CommChunks(text)
    local out = {}
    for i = 1, #text, CHUNK do out[#out + 1] = text:sub(i, i + CHUNK - 1) end
    return out
end

---------------------------------------------------------------------------
-- Field checks of the received kinds
---------------------------------------------------------------------------
local function isKey(v) return type(v) == "string" and v:match("^%d%d%d%d%-%d%d%-%d%d:%d+$") ~= nil end
local function isNum(v, lo, hi)
    local n = type(v) == "string" and v:match("^%d+$") and tonumber(v)
    return n ~= nil and n >= lo and n <= hi
end
local function isHex(v, len) return type(v) == "string" and #v == len and v:match("^%x+$") ~= nil end
local function isFlags(v, set) return v == "-" or (type(v) == "string" and v ~= "" and #v <= #set and not v:find("[^" .. set .. "]")) end

local function itemList(v)
    if type(v) ~= "string" or v == "" then return false end
    local n = 0
    for id in (v .. ","):gmatch("([^,]*),") do
        n = n + 1
        if n > 8 or not isNum(id, 1, 999999) then return false end
    end
    return true
end

local function answerList(v)
    if type(v) ~= "string" or v == "" then return false end
    local n = 0
    for entry in (v .. ","):gmatch("([^,]*),") do
        n = n + 1
        local id, art, gain, pct, slot = entry:match("^([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)$")
        if n > 8 or not id or not isNum(id, 1, 999999) or not (art == "U" or art == "W" or art == "-")
            or not gain:match("^%-?%d+$") or not isNum(pct, 0, 999999) or not slot:match("^[%w_%-]+$") then
            return false
        end
    end
    return true
end

-- A comma list of at most max entries, each passing ok; "-" (empty) when allowEmpty.
local function commaList(v, max, ok, allowEmpty)
    if v == "-" then return allowEmpty == true end
    if type(v) ~= "string" or v == "" then return false end
    local n = 0
    for entry in (v .. ","):gmatch("([^,]*),") do
        n = n + 1
        if n > max or not ok(entry) then return false end
    end
    return true
end

-- The drop exchange (DropSync.lua): week "w:hhhh:n", bucket "day:inst:hhhh:n", a known kill as its
-- id (8 hex) and the digest of its items (4 hex).
local function weekEntry(e)
    local w, _, n = e:match("^(%d):(%x%x%x%x):(%d+)$")
    return w ~= nil and isNum(w, 0, 3) and isNum(n, 0, 999999)
end
local function bucketEntry(e)
    local day, inst, _, n = e:match("^(%d+):(%d+):(%x%x%x%x):(%d+)$")
    return day ~= nil and isNum(day, 0, 99999) and isNum(inst, 1, 99999) and isNum(n, 1, 999999)
end
local function killEntry(e) return isHex(e, 12) end
-- DR: pairs of a bucket key and its known kills (or "*"), 12 buckets at most
local function drPairs(f)
    if #f < 2 or #f % 2 ~= 0 or #f > 24 then return false end
    for i = 1, #f, 2 do
        if not isKey(f[i]) or not (f[i + 1] == "*" or commaList(f[i + 1], 16, killEntry)) then return false end
    end
    return true
end

-- The source exchange (CollectSync.lua): a kind "q:hhhh:n", a bucket "bb:hhhh:n" (bb two hex,
-- 00-3f), a known record as 4 hex.
local COLLECT_KINDS = { q = true, s = true, w = true }
local function collectKindEntry(e)
    local k, n = e:match("^([qsw]):%x%x%x%x:(%d+)$")
    return k ~= nil and isNum(n, 0, 999999)
end
local function collectBucket(b)
    return type(b) == "string" and b:match("^%x%x$") ~= nil and tonumber(b, 16) <= 63
end
local function collectBucketEntry(e)
    local b, n = e:match("^(%x%x):%x%x%x%x:(%d+)$")
    return b ~= nil and collectBucket(b) and isNum(n, 1, 999999)
end
local function hex4(e) return isHex(e, 4) end

local NO_REASONS = { CONFLICT = true, GONE = true, DENIED = true, NORAID = true, BAD = true }

-- kind -> fields check; more fields than these are allowed (a later client of the same protocol)
local VALID = {
    HI = function(f) return #f >= 4 and f[1]:match("^%d+%.%d+%.%d+$") and isNum(f[2], 0, 9) and isFlags(f[3], "OL")
                         and (f[4] == "-" or isKey(f[4])) end,
    VQ = function(f) return #f >= 1 and isHex(f[1], 4) end,
    ST = function(f) return #f >= 4 and isKey(f[1]) and isNum(f[2], 0, 999999) and isHex(f[3], 16) and isFlags(f[4], "KM") end,
    RQ = function(f) return #f >= 3 and isKey(f[1]) and isNum(f[2], 0, 999999) and (f[3] == "P" or f[3] == "O" or f[3] == "PO") end,
    BL = function(f)
        if #f < 6 or not BLOB_ARTS[f[1]] or not isKey(f[2]) or not isNum(f[3], 0, 999999) then return false end
        local i, n = tonumber(f[4]), tonumber(f[5])
        if not isNum(f[4], 1, MAX_PARTS) or not isNum(f[5], 1, MAX_PARTS) or i > n then return false end
        if ART_PARTS[f[1]] and n > ART_PARTS[f[1]] then return false end
        return #f[6] > 0 and #f[6] <= CHUNK and f[6]:match("^[A-Za-z0-9+/=]+$") ~= nil
    end,
    OK = function(f) return #f >= 3 and isKey(f[1]) and isHex(f[2], 12) and isNum(f[3], 0, 999999) end,
    NO = function(f) return #f >= 4 and isKey(f[1]) and isHex(f[2], 12) and NO_REASONS[f[3]] and isNum(f[4], 0, 999999) end,
    NW = function(f) return #f >= 4 and isKey(f[1]) and isNum(f[2], 0, 999999) and isHex(f[3], 16) and isNum(f[4], 0, 999999) end,
    UQ = function(f) return #f >= 2 and isHex(f[1], 4) and itemList(f[2]) end,
    UA = function(f) return #f >= 2 and isHex(f[1], 4) and answerList(f[2]) end,
    -- drop exchange: DV <drop proto> <records> <newest day> <weeks>; DQ <week>;
    -- DI <week> <part> <parts> <buckets>|-; DR (<bucket key> <known kills>|*)...; DW <seconds>
    -- (busy: ask again later)
    DV = function(f) return #f >= 4 and isNum(f[1], 0, 9) and isNum(f[2], 0, 999999) and isNum(f[3], 0, 99999)
                         and commaList(f[4], 4, weekEntry) end,
    DQ = function(f) return #f >= 1 and isNum(f[1], 0, 3) end,
    DI = function(f)
        if #f < 4 or not isNum(f[1], 0, 3) or not isNum(f[2], 1, 20) or not isNum(f[3], 1, 20) then return false end
        return tonumber(f[2]) <= tonumber(f[3]) and commaList(f[4], 12, bucketEntry, true)
    end,
    DR = drPairs,
    DW = function(f) return #f >= 1 and isNum(f[1], 1, 3600) end,
    -- source exchange: CV <collect proto> <records> <kinds>; CQ <kind>; CI <kind> <part> <parts>
    -- <buckets>|-; CR (<kind><bucket> <known records>|*)... (12 buckets of one kind at most); CW <seconds> (busy)
    CV = function(f) return #f >= 3 and isNum(f[1], 0, 9) and isNum(f[2], 0, 999999) and commaList(f[3], 3, collectKindEntry) end,
    CQ = function(f) return #f >= 1 and COLLECT_KINDS[f[1]] == true end,
    CI = function(f)
        if #f < 4 or not COLLECT_KINDS[f[1]] or not isNum(f[2], 1, 8) or not isNum(f[3], 1, 8) then return false end
        return tonumber(f[2]) <= tonumber(f[3]) and commaList(f[4], 20, collectBucketEntry, true)
    end,
    CR = function(f)
        if #f < 2 or #f % 2 ~= 0 or #f > 24 then return false end
        for i = 1, #f, 2 do
            if #f[i] ~= 3 or f[i]:sub(1, 1) ~= f[1]:sub(1, 1) or not COLLECT_KINDS[f[i]:sub(1, 1)] or not collectBucket(f[i]:sub(2))
                or not (f[i + 1] == "*" or commaList(f[i + 1], 45, hex4)) then
                return false
            end
        end
        return true
    end,
    CW = function(f) return #f >= 1 and isNum(f[1], 1, 3600) end,
}

local function prefixOf(kind) return kind == "BL" and PREFIX_DATA or PREFIX_CTRL end

---------------------------------------------------------------------------
-- Who may be talked to
---------------------------------------------------------------------------
local function withoutRealm(name)
    return type(name) == "string" and name:match("^(.+)%-[^%-]*$") or nil
end

-- The own echo: exactly the own full name, also with the own realm ending. Never a first name
-- alone (another character with that first name would be deaf to this client).
local function isSelf(sender)
    local me = ns.UnitFullName("player")
    local name = ns.FullName(sender)
    if not me or not name then return false end
    if name:lower() == me:lower() then return true end
    local base = ns.StripOwnRealm and ns.StripOwnRealm(name)
    return base ~= nil and base:lower() == me:lower()
end

-- A whisper target must be a name of the group or the guild (as the client gives it, a realm
-- ending allowed).
local function knownTarget(target)
    if ns.TrustName then return ns.TrustName(target) ~= nil end
    local roster = ns.GroupRoster()
    for _, cand in ipairs({ target, withoutRealm(target) }) do
        for _, n in ipairs(roster) do
            if ns.SameNameIn(cand, n, roster) then return true end
        end
    end
    return false
end

local function homeRaid()
    if _G.LE_PARTY_CATEGORY_HOME then return IsInRaid(LE_PARTY_CATEGORY_HOME) and true or false end
    return IsInRaid() and true or false
end

local function inGuild()
    return type(_G.IsInGuild) == "function" and IsInGuild() and true or false
end

-- Whether a channel can be used right now; nil and the reason otherwise.
local function channelOk(chan, target)
    if not CHANNELS[chan] then return nil, "Dieser Kanal wird nicht benutzt." end
    if chan == "RAID" and not homeRaid() then return nil, "Keine eigene Raidgruppe." end
    if chan == "GUILD" and not inGuild() then return nil, "Keine Gilde." end
    if chan == "WHISPER" then
        if type(target) ~= "string" or target == "" then return nil, "Kein Empfänger." end
        if not knownTarget(target) then return nil, "Der Empfänger ist weder in der Gruppe noch in der Gilde." end
    end
    return true
end

-- Battlegrounds and arenas: nothing is sent.
local function inPvP()
    local _, kind = GetInstanceInfo()
    if kind == "pvp" or kind == "arena" then return true end
    local pvp = _G.C_PvP
    if type(pvp) == "table" and type(pvp.IsActiveBattlefield) == "function" then
        local ok, on = pcall(pvp.IsActiveBattlefield)
        if ok and ns.Plain(on) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The lockdown
---------------------------------------------------------------------------
local function restricted()
    local api = _G.C_RestrictedActions
    local fn = type(api) == "table" and api.IsAddOnRestrictionActive
    if type(fn) ~= "function" then return false end
    local kind = _G.Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Chat or 5
    local ok, on = pcall(fn, kind)
    return ok and ns.Plain(on) == true
end

local function lockedNow()
    return ns.ChatLocked() or restricted()
end

local held = false        -- the queue waits for the lockdown to end (or after result 11)
local lockCheckedAt = 0

function ns.CommHeld() return held or lockedNow() end

---------------------------------------------------------------------------
-- The send queue
---------------------------------------------------------------------------
local queue = {}          -- { prefix, text, chan, target, key, expires, ready, tries, kind, desc }
local msgTokens = { [PREFIX_CTRL] = MSG_BURST, [PREFIX_DATA] = MSG_BURST }
local byteTokens, refilledAt = BYTE_BURST, nil
local pausedUntil = 0
local ticker

function ns.CommQueueSize() return #queue end

local function refill()
    local t = now()
    if refilledAt then
        local d = t - refilledAt
        for p, v in pairs(msgTokens) do msgTokens[p] = math.min(MSG_BURST, v + d * MSG_REFILL) end
        byteTokens = math.min(BYTE_BURST, byteTokens + d * BYTE_REFILL)
    end
    refilledAt = t
end

local function cost(e) return #e.prefix + #e.text end

local pump

local function startTicker()
    if ticker then return end
    ticker = C_Timer.NewTicker(TICK, function() pump(false) end)
end

local function stopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
end

local function removeAt(i)
    table.remove(queue, i)
end

-- One try: true when the queue may go on, false when it has to stop (pause or hold).
local function attempt(i)
    local e = queue[i]
    local ok = channelOk(e.chan, e.target)
    if not ok then
        stats.dropped = stats.dropped + 1
        removeAt(i)
        return true
    end
    local okCall, result = pcall(C_ChatInfo.SendAddonMessage, e.prefix, e.text, e.chan, e.chan == "WHISPER" and e.target or nil)
    if not okCall then result = 9 end
    result = ns.Plain(result)
    if result == true then result = 0 end
    if result == 0 then
        stats.sent = stats.sent + 1
        msgTokens[e.prefix] = msgTokens[e.prefix] - 1
        byteTokens = byteTokens - cost(e)
        removeAt(i)
        debugLine("> " .. e.chan .. (e.chan == "WHISPER" and (" " .. tostring(e.target)) or "") .. " " .. e.desc)
        return true
    elseif result == 3 or result == 8 then
        stats.throttled = stats.throttled + 1
        e.tries = (e.tries or 0) + 1
        if e.tries >= MAX_TRIES then
            stats.dropped = stats.dropped + 1
            removeAt(i)
            noteOnce("throttle", "Nachricht nach " .. MAX_TRIES .. " gedrosselten Versuchen verworfen.")
            pausedUntil = now() + 2
        else
            pausedUntil = now() + 2 ^ e.tries
        end
        return false
    elseif result == 11 then
        held = true
        lockCheckedAt = now()
        return false
    elseif result == 5 or result == 10 or result == 12 then
        stats.dropped = stats.dropped + 1
        removeAt(i)
        return true
    end
    stats.failed = stats.failed + 1
    removeAt(i)
    noteOnce("error", "Senden fehlgeschlagen (Ergebnis " .. tostring(result) .. ").")
    return true
end

-- Whether an entry's own condition (opts.when) lets it go now.
local function free(e)
    if not e.when then return true end
    local ok, yes = pcall(e.when)
    if not ok then report(yes) return false end
    return yes == true
end

-- The next entry that may go now: the first ready control message, else the first ready data part
-- (which leaves bytes for a waiting control message). Entries of lowest priority (opts.low) only
-- while nothing else waits in the queue. nil when nothing may go.
local function pick()
    local t = now()
    local urgent = false
    for _, e in ipairs(queue) do
        if not e.low then urgent = true break end
    end
    local ctrl, data
    for i, e in ipairs(queue) do
        if e.ready <= t and (not e.low or not urgent) and free(e) then
            if e.prefix == PREFIX_CTRL then
                if not ctrl then ctrl = i end
            elseif not data then
                data = i
            end
            if ctrl and data then break end
        end
    end
    if ctrl then
        local e = queue[ctrl]
        if msgTokens[PREFIX_CTRL] >= 1 and byteTokens >= cost(e) then return ctrl end
    end
    if data then
        local e = queue[data]
        local need = cost(e) + (ctrl and CTRL_RESERVE or 0)
        if msgTokens[PREFIX_DATA] >= 1 and byteTokens >= need then return data end
    end
    return nil
end

-- Sends what the allowances permit. force: check the lockdown now (event), not only every 2 s.
pump = function(force)
    local t = now()
    local keep = {}
    for _, e in ipairs(queue) do
        if e.expires > t then keep[#keep + 1] = e else stats.expired = stats.expired + 1 end
    end
    queue = keep
    if #queue == 0 then
        stopTicker()
        return
    end
    if held and not force and t - lockCheckedAt < LOCK_POLL then return end
    if t < pausedUntil or inPvP() then return end
    lockCheckedAt = t
    held = lockedNow()
    if held then return end
    refill()
    while true do
        local i = pick()
        if not i then break end
        if not attempt(i) then break end
    end
    if #queue == 0 then stopTicker() end
end

-- Puts entries into the queue (the oldest data part, then the oldest control message falls out
-- above 200) and sends what may go.
local function enqueue(entries, key)
    if key then
        local keep, at = {}, nil
        for _, q in ipairs(queue) do
            if q.key == key then
                at = at or #keep + 1
            else
                keep[#keep + 1] = q
            end
        end
        queue = keep
        -- a single message keeps the place of the one it replaces
        if at and #entries == 1 then
            table.insert(queue, at, entries[1])
            entries = {}
        end
    end
    for _, e in ipairs(entries) do queue[#queue + 1] = e end
    while #queue > MAX_QUEUE do
        -- the oldest entry of lowest priority, else the oldest data part, else the oldest message
        local drop
        for i, q in ipairs(queue) do
            if q.low then drop = i break end
        end
        for i, q in ipairs(queue) do
            if drop then break end
            if q.prefix == PREFIX_DATA then drop = i break end
        end
        table.remove(queue, drop or 1)
        stats.dropped = stats.dropped + 1
        noteOnce("full", "Sendeschlange voll, älteste Nachricht verworfen.")
    end
    startTicker()
    pump(false)
end

local function entry(kind, text, chan, target, opts, desc)
    local t = now()
    local jitter = tonumber(opts.jitter) or 0
    local low = opts.low and true or nil
    return { prefix = prefixOf(kind), text = text, chan = chan, target = target, key = opts.key, kind = kind,
             expires = t + (tonumber(opts.ttl) or (low and LOW_TTL or DEFAULT_TTL)), ready = t + (jitter > 0 and math.random() * jitter or 0),
             tries = 0, desc = desc, low = low, when = type(opts.when) == "function" and opts.when or nil }
end

local function envelope(kind, fields)
    if type(kind) ~= "string" or not kind:match("^%u%u$") then return nil, "Unbekannte Nachricht." end
    if type(fields) ~= "table" then return nil, "Keine Felder." end
    local parts = {}
    for i, f in ipairs(fields) do
        f = tostring(f)
        if f:find("[%c|]") then return nil, "Ungültiges Feld." end
        parts[i] = f
    end
    local text = ns.SYNC_PROTO .. kind .. (#parts > 0 and ("\t" .. table.concat(parts, "\t")) or "")
    if #text > MAX_TEXT then return nil, "Nachricht zu lang." end
    return text, parts
end

-- Sends one control message. kind: "HI", "VQ", ...; fields: list of strings; chan "GUILD", "RAID"
-- or "WHISPER" with target. opts.ttl (seconds, default 60), opts.key (a waiting entry with the same
-- key is replaced), opts.jitter (random delay of 0 to n seconds before the first try), opts.low
-- (lowest priority: goes only while nothing else waits, ttl default 120), opts.when (a function; the
-- entry waits while it does not return true).
function ns.CommSend(kind, fields, chan, target, opts)
    if not available then return nil, "Addon-Nachrichten sind nicht verfügbar." end
    if kind == "BL" then return nil, "Daten gehen über CommSendBlob." end
    local text, parts = envelope(kind, fields)
    if not text then return nil, parts end
    local ok, why = channelOk(chan, target)
    if not ok then return nil, why end
    enqueue({ entry(kind, text, chan, target, opts or {}, describe(kind, parts)) }, opts and opts.key)
    return true
end

local seq = 0

-- Packs tbl, cuts it into parts and queues them. art "SP", "SO", "OP", "DK" or "CK"; key the raid key
-- (DK: the bucket key, the same "date:instance" form; CK: "0000-00-00:<kind * 100 + bucket + 1>"). opts as CommSend. Returns true and the
-- number of parts and their bytes.
function ns.CommSendBlob(art, key, tbl, chan, target, opts)
    if not available then return nil, "Addon-Nachrichten sind nicht verfügbar." end
    if not BLOB_ARTS[art] then return nil, "Unbekannte Datenart." end
    if not isKey(key) then return nil, "Ungültiger Raid-Schlüssel." end
    local ok, why = channelOk(chan, target)
    if not ok then return nil, why end
    local packed, err = ns.CommPack(tbl)
    if not packed then return nil, err end
    local chunks = ns.CommChunks(packed)
    if #chunks > (ART_PARTS[art] or MAX_PARTS) then return nil, "Daten zu groß." end
    seq = seq % 999999 + 1
    opts = opts or {}
    local list, bytes = {}, 0
    for i, c in ipairs(chunks) do
        local fields = { art, key, tostring(seq), tostring(i), tostring(#chunks), c }
        list[i] = entry("BL", ns.SYNC_PROTO .. "BL\t" .. table.concat(fields, "\t"), chan, target, opts, describe("BL", fields))
        bytes = bytes + cost(list[i])
    end
    enqueue(list, opts.key)
    return true, #chunks, bytes
end

-- The restriction changed: read the state after the dispatch (it is not final during it).
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    C_Timer.After(0, function()
        if #queue > 0 then pump(true) else held = false end
    end)
end)

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local handlers, blobHandlers = {}, {}

function ns.CommOn(kind, fn)
    handlers[kind] = handlers[kind] or {}
    table.insert(handlers[kind], fn)
end

function ns.CommOnBlob(art, fn)
    blobHandlers[art] = blobHandlers[art] or {}
    table.insert(blobHandlers[art], fn)
end

local function run(list, ...)
    for _, fn in ipairs(list or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then report(err) end
    end
end

-- per sender (lower case): { times = { t }, bytes = { { t, n } }, ignoreUntil, kinds = { kind -> t } }
local senders = {}

local function senderState(key)
    local s = senders[key]
    if not s then
        s = { times = {}, bytes = {}, kinds = {}, sets = {}, done = {} }
        senders[key] = s
    end
    return s
end

-- Whether a message of n bytes from this sender is still within its limits.
local function withinLimits(s, sender, n)
    local t = now()
    if s.ignoreUntil and t < s.ignoreUntil then return false end
    local times, bytes, total = {}, {}, 0
    for _, at in ipairs(s.times) do
        if t - at < RECV_WINDOW then times[#times + 1] = at end
    end
    for _, b in ipairs(s.bytes) do
        if t - b[1] < BYTE_WINDOW then bytes[#bytes + 1] = b; total = total + b[2] end
    end
    times[#times + 1] = t
    bytes[#bytes + 1] = { t, n }
    total = total + n
    s.times, s.bytes = times, bytes
    if #times > RECV_MAX or total > BYTE_MAX then
        s.ignoreUntil = t + IGNORE_FOR
        s.times, s.bytes = {}, {}
        debugLine(("%s sendet zu viel, 60 s ignoriert."):format(sender), true)
        return false
    end
    return true
end

local function bad(reason)
    stats.bad = stats.bad + 1
    noteOnce("bad:" .. reason, "Ungültige Nachricht verworfen (" .. reason .. ").")
end

-- Drops part sets without a new part for 30 s and announces the loss.
local function sweep()
    local t = now()
    for _, s in pairs(senders) do
        local keep = {}
        for _, set in ipairs(s.sets) do
            if t - set.last >= SET_TTL then
                ns.Fire("COMM_BLOB_LOST", set.sender, set.art, set.key)
            else
                keep[#keep + 1] = set
            end
        end
        s.sets = keep
        for id, at in pairs(s.done) do
            if t - at >= DONE_KEEP then s.done[id] = nil end
        end
    end
end

local function dropSet(s, set)
    for j, x in ipairs(s.sets) do if x == set then table.remove(s.sets, j) break end end
end

-- A finished set: unpacked only for a member of the own guild (the roster may have to be read
-- first), then handed to the handlers of its kind.
local function finishSet(sender, name, set)
    local text = table.concat(set.parts, "", 1, set.n)
    local function unpack()
        local tbl = ns.CommUnpack(text)
        if not tbl then
            bad("Daten")
            return
        end
        run(blobHandlers[set.art], sender, tbl, set.chan, set.key)
    end
    if not ns.TrustWait then return unpack() end
    ns.TrustWait(name, "member", function(ok)
        if ok then unpack() else bad("Absender") end
    end)
end

-- Whether a part set of kind art for raid key from the raw sender is coming in right now.
function ns.CommIncoming(sender, art, key)
    local s = type(sender) == "string" and senders[sender:lower()]
    if not s then return false end
    sweep()
    for _, set in ipairs(s.sets) do
        if set.art == art and set.key == key then return true end
    end
    return false
end

local function onPart(s, sender, name, f, chan)
    local art, key, n, i = f[1], f[2], tonumber(f[5]), tonumber(f[4])
    local id = art .. ":" .. key .. ":" .. f[3]
    sweep()
    if s.done[id] then return end
    local set
    for _, x in ipairs(s.sets) do
        if x.id == id then set = x break end
    end
    if set and set.n ~= n then
        -- the same set with another part count: all of it is bad
        dropSet(s, set)
        bad("Teile")
        return
    end
    if not set then
        if #s.sets >= SETS_PER_SENDER then
            local oldest = 1
            for j, x in ipairs(s.sets) do if x.last < s.sets[oldest].last then oldest = j end end
            table.remove(s.sets, oldest)
        end
        set = { id = id, art = art, key = key, n = n, parts = {}, got = 0, bytes = 0, sender = sender, chan = chan }
        s.sets[#s.sets + 1] = set
    end
    set.last = now()
    C_Timer.After(SET_TTL + 0.5, sweep)
    if not set.parts[i] then
        -- the open parts and bytes of one sender are bounded before anything is unpacked
        local parts, bytes = 0, 0
        for _, x in ipairs(s.sets) do parts, bytes = parts + x.got, bytes + (x.bytes or 0) end
        if parts + 1 > OPEN_PARTS or bytes + #f[6] > OPEN_BYTES then
            dropSet(s, set)
            bad("Grenze")
            return
        end
        set.parts[i] = f[6]
        set.got = set.got + 1
        set.bytes = set.bytes + #f[6]
    end
    if set.got < n then return end
    dropSet(s, set)
    s.done[id] = now()
    finishSet(sender, name, set)
end

local function onMessage(prefix, text, chan, sender)
    if prefix ~= PREFIX_CTRL and prefix ~= PREFIX_DATA then return end
    if not available then return end
    text, chan, sender = ns.Plain(text), ns.Plain(chan), ns.Plain(sender)
    if type(text) ~= "string" or type(chan) ~= "string" or type(sender) ~= "string" or sender == "" then
        stats.bad = stats.bad + 1
        return
    end
    if isSelf(sender) then return end
    local s = senderState(sender:lower())
    if not withinLimits(s, sender, #text) then
        stats.limited = stats.limited + 1
        return
    end
    local proto, kind, rest = text:match("^(%d)(%u%u)(.*)$")
    proto = tonumber(proto)
    if not proto then return bad("Umschlag") end
    if proto > ns.SYNC_PROTO then
        if not newerProto or proto > newerProto then newerProto = proto end
        return
    end
    if proto < ns.SYNC_MIN_PROTO then return end
    if prefixOf(kind) ~= prefix then return bad("Präfix") end
    local fields = {}
    if rest ~= "" then
        if rest:sub(1, 1) ~= "\t" then return bad("Umschlag") end
        for field in (rest:sub(2) .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
    end
    local check = VALID[kind]
    if not check or not check(fields) then return bad(kind) end
    stats.received = stats.received + 1
    debugLine("< " .. sender .. " " .. describe(kind, fields))
    local gapKey = (kind == "RQ" and fields[5] == "G") and "RQG" or kind
    local gap = KIND_GAP[gapKey]
    if gap then
        local t = now()
        if s.kinds[gapKey] and t - s.kinds[gapKey] < gap then return end
        s.kinds[gapKey] = t
    end
    local keyed = KEYED_GAP[kind]
    if keyed then
        local t, k = now(), kind .. ":" .. fields[1]
        s.keyed = s.keyed or { n = 0, at = {} }
        if s.keyed.at[k] and t - s.keyed.at[k] < keyed then return end
        if not s.keyed.at[k] then
            if s.keyed.n >= KEYED_MAX then
                local keep, n = {}, 0
                for key, at in pairs(s.keyed.at) do
                    if t - at < 600 then keep[key], n = at, n + 1 end
                end
                s.keyed.at, s.keyed.n = keep, n
                if n >= KEYED_MAX then return end
            end
            s.keyed.n = s.keyed.n + 1
        end
        s.keyed.at[k] = t
    end
    if kind == "BL" then
        if not ns.CommPacking() then return end
        -- data only from members of the own guild: an outsider's parts are dropped from the first
        -- one on, unread, for a minute
        if s.outsider and now() < s.outsider then return end
        local name = ns.TrustName and ns.TrustName(sender) or sender
        local member = (name and ns.IsVerifiedMember) and ns.IsVerifiedMember(name)
        if not name or member == false then
            s.outsider, s.sets = now() + OUTSIDER_FOR, {}
            return bad("Absender")
        end
        return onPart(s, sender, name, fields, chan)
    end
    run(handlers[kind], sender, fields, chan, text)
end

ns.OnEvent("CHAT_MSG_ADDON", onMessage)

---------------------------------------------------------------------------
-- Settings and the sync command
---------------------------------------------------------------------------
-- The "sync" settings section; later parts add their items to SYNC_SETTINGS.items and register it
-- again.
ns.SYNC_SETTINGS = { key = "sync", label = "Sync und Version", order = 85, items = {
    { key = "sync.enabled", type = "toggle", label = "Raid-Stand mit anderen Amisia-Clients abgleichen", default = true,
      tip = "Vergaben, Plus-Eins, Ersatzbank und Bosskills des laufenden Raids. Die Lootleitung hält den Stand." },
    { key = "sync.debug", type = "toggle", label = "Sync-Nachrichten im Chat (Fehlersuche)", default = false, expert = true },
} }
ns.RegisterSettings(ns.SYNC_SETTINGS)

-- /amisia sync <word>: parts register their words here.
local syncWords = {}
function ns.RegisterSyncCommand(word, fn) syncWords[word] = fn end

local SYNC_USAGE = "[jetzt|an|aus|raenge|debug|selbsttest]"

ns.RegisterSlash("sync", { args = SYNC_USAGE, desc = "Stand des Abgleichs", run = function(rest)
    local word, more = (rest or ""):match("^(%S*)%s*(.-)$")
    word = (word or ""):lower()
    if word == "" then
        if not available then
            ns.msg("Addon-Nachrichten sind nicht verfügbar.")
            return
        end
        -- the raid sync tells its state itself (word ""); the layer alone says its queue
        if syncWords[""] then return syncWords[""](more) end
        ns.msg(("Sync %s · %d Nachrichten warten%s."):format(ns.Get("sync.enabled") ~= false and "an" or "aus",
            #queue, ns.CommHeld() and " (Sperre)" or ""))
        return
    end
    local fn = syncWords[word]
    if not fn then
        ns.msg("Aufruf: /amisia sync " .. SYNC_USAGE)
        return
    end
    fn(more)
end })

ns.RegisterSyncCommand("debug", function()
    if not ns.Get("ui.expert") then
        ns.msg("Nur im Expertenmodus.")
        return
    end
    local on = not ns.Get("sync.debug")
    ns.Set("sync.debug", on)
    ns.msg(on and "Sync-Fehlersuche an." or "Sync-Fehlersuche aus.")
end)
