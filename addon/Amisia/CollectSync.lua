-- Amisia source exchange: guild members share the collector's records (Collector.lua) quietly,
-- pulling only what they miss, in the manner of the drop exchange (DropSync.lua). Every kind
-- (q quests, s vendors, w world drops) falls into 64 buckets (id % 64). A client announces its
-- kinds to the guild (CV: per kind a checksum and a count); whoever holds another checksum asks that
-- sender for its buckets (CQ, answered by CI parts), then asks for the buckets that differ (CR, up
-- to 12 of one kind in one request, naming per bucket the own records as 4 hex each, or "*"); the
-- answer is a CK blob with only the records the asker does not hold the same. A record's checksum leaves its day out, so a record
-- seen again on another day starts no exchange.
--
-- Both sides pull, neither pushes: a blob nobody asked for is dropped, a request takes its one
-- answer. Every record heard is checked like a saved one (Collector.lua's one canonical form,
-- the bucket of the request); one bad record drops the whole blob. Only between guild members,
-- at the lowest priority of the queue, never in an instance, a battleground, in combat, in the
-- lockdown or while a raid is synced, within fixed byte caps. No player names travel.
--
-- Collect protocol 1. A client pulls only from announcements of its own collect protocol; clients
-- before the exchange do not know CV and drop it as an unknown message (they never get the
-- whispered kinds).
local ADDON, ns = ...

ns.COLLECT_PROTO = 1

local L = {
    firstMin = 90, firstSpread = 120,   -- the first announcement 90 to 210 s after the login
    every = 1800,                       -- later ones at most every 30 minutes, after new records
    tick = 5,
    ciWait = 60, crWait = 180,          -- seconds the bucket list and a blob may take (a busy sender
                                        -- answers one blob per 20 s and 40 parts per 10 minutes)
    retries = 2,                        -- a pull that missed answers is tried again this often
    askKeep = 600,
    crPerHour = 40,
    serveGap = 20, partsWindow = 600, partsMax = 40,
    blobParts = 20, blobRecords = 60,
    sessionBytes = 49152, askerShare = 3,
    peerKeep = 1800, peersMax = 10, pullJitter = 30,
    serveMax = 12, serveKeep = 1200, servePeers = 2, activeKeep = 120,
    busyWait = 120,
    senderMax = 1500,                   -- records new to this client from one sender in a session
    knownMax = 45, ciEntries = 20,
    crBuckets = 12, crChars = 220,      -- buckets and characters of one request
    buckets = 64,
}
ns.COLLECTSYNC_LIMITS = L

local KINDS = { "q", "s", "w" }
local KIND_INDEX = { q = 1, s = 2, w = 3 }
local PART_OVERHEAD = 45

local stats = { bytes = 0, cv = 0, cq = 0, ci = 0, cr = 0, cw = 0, served = 0, blobs = 0, records = 0, new = 0, merged = 0,
                bad = 0, unasked = 0, refused = 0, pulls = 0, capped = 0, busy = 0, other = 0 }
local crTimes = {}
local asked = {}          -- "<kind><first bb>|lower name" -> { at, kind, b (first bucket), bs = { [bucket] = true } }
local peers = {}          -- { name, low, kinds, at, nb, retry }
local pull                -- { name, low, kinds, at, retry, missed, wants, wi, kind, stage, parts, n, got, crs, akey, deadline }
local serve = {}          -- { name, low, kind, b (first bucket), ids, at }
local askers = {}         -- lower name -> { bytes, at, served }
local lastBlob
local partsLog = {}
local senderNew = {}
local firstAt, announced, lastCV, ownAtCV, learnedAtCV, reannounced, emptyAtFirst
local learned = 0

local function now() return GetTime() end
local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end
local function hex4(s) return ns.Checksum(s):sub(13, 16) end
local function debugLine(text)
    if ns.Get("sync.debug") then DEFAULT_CHAT_FRAME:AddMessage("|cff999999Amisia Quellen: " .. text .. "|r") end
end

---------------------------------------------------------------------------
-- When the exchange may talk
---------------------------------------------------------------------------
local function battlefield()
    local pvp = _G.C_PvP
    if type(pvp) ~= "table" or type(pvp.IsActiveBattlefield) ~= "function" then return false end
    local ok, on = pcall(pvp.IsActiveBattlefield)
    return ok and ns.Plain(on) == true
end

function ns.CollectSyncCanTalk()
    if not AmisiaDB or not ns.Get("collect.share") then return false end
    if not ns.CommAvailable() or not ns.CommPacking() then return false end
    if type(IsInGuild) ~= "function" or ns.Plain(IsInGuild()) ~= true then return false end
    if type(IsInInstance) == "function" and ns.Plain((IsInInstance())) == true then return false end
    local _, kind = GetInstanceInfo()
    kind = ns.Plain(kind)
    if kind ~= nil and kind ~= "none" then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return false end
    if ns.CommHeld() then return false end
    if (ns.Active and ns.Active() ~= nil and ns.CommReady()) or battlefield() then return false end
    return true
end
local canTalk = function() return ns.CollectSyncCanTalk() end

---------------------------------------------------------------------------
-- Sending within the session's bytes and each asker's share
---------------------------------------------------------------------------
local function askerOf(low)
    local a = askers[low]
    if not a then
        a = { bytes = 0 }
        askers[low] = a
    end
    return a
end
local function afford(n, low)
    if stats.bytes + n > L.sessionBytes then return false end
    if low and askerOf(low).bytes + n > L.sessionBytes / L.askerShare then return false end
    return true
end
local function charge(n, low)
    stats.bytes = stats.bytes + n
    if low then askerOf(low).bytes = askerOf(low).bytes + n end
end

local function send(kind, fields, chan, target, key, low)
    local n = #"Amisia" + #tostring(ns.SYNC_PROTO) + #kind + 1 + #table.concat(fields, "\t")
    if not afford(n, low) then
        debugLine("Sendegrenze erreicht.")
        return false
    end
    local ok = ns.CommSend(kind, fields, chan, target, { low = true, when = canTalk, key = key })
    if not ok then return false end
    charge(n, low)
    stats[kind:lower()] = stats[kind:lower()] + 1
    return true
end

---------------------------------------------------------------------------
-- The index: per kind 64 buckets with their checksums
---------------------------------------------------------------------------
local digests, nDigests = {}, 0   -- record string -> 4 hex of the record without its day
local function digest(s)
    local d = digests[s]
    if d then return d end
    if nDigests > 20000 then digests, nDigests = {}, 0 end
    d = hex4(s:match("^%d+;(.*)$") or s)
    digests[s] = d
    nDigests = nDigests + 1
    return d
end
local function known4(id, dig) return hex4(id .. "=" .. dig) end

local index
local function indexNow()
    local gen = ns.CollectGen()
    if index and index.gen == gen then return index end
    local c = ns.CollectDB()
    local kinds, total = {}, 0
    for _, kind in ipairs(KINDS) do
        local buckets = {}
        local n = 0
        for id, s in pairs(c and c[kind] or {}) do
            local b = id % L.buckets
            local bk = buckets[b]
            if not bk then
                bk = { ids = {}, dig = {} }
                buckets[b] = bk
            end
            bk.ids[#bk.ids + 1] = id
            bk.dig[id] = digest(s)
            n = n + 1
        end
        local parts = {}
        for b = 0, L.buckets - 1 do
            local bk = buckets[b]
            if bk then
                table.sort(bk.ids)
                local list = {}
                for i, id in ipairs(bk.ids) do list[i] = id .. "=" .. bk.dig[id] end
                bk.hash = hex4(table.concat(list, ","))
                parts[#parts + 1] = ("%02x=%s"):format(b, bk.hash)
            end
        end
        kinds[kind] = { buckets = buckets, n = n, hash = n == 0 and "0000" or hex4(table.concat(parts, ",")) }
        total = total + n
    end
    index = { gen = gen, kinds = kinds, total = total }
    return index
end

local function blobKey(kind, b) return ("0000-00-00:%d"):format(KIND_INDEX[kind] * 100 + b + 1) end

---------------------------------------------------------------------------
-- Announcing (CV)
---------------------------------------------------------------------------
local function sendCV()
    local ix = indexNow()
    if ix.total == 0 then return false end
    local list = {}
    for _, kind in ipairs(KINDS) do list[#list + 1] = ("%s:%s:%d"):format(kind, ix.kinds[kind].hash, ix.kinds[kind].n) end
    return send("CV", { tostring(ns.COLLECT_PROTO), tostring(ix.total), table.concat(list, ",") }, "GUILD", nil, "CV")
end

local function setFirst()
    if firstAt then return end
    local d = ns.DropsDB and ns.DropsDB()
    local spread = d and type(d.me) == "string" and tonumber(d.me:sub(5, 8), 16) or 0
    firstAt = now() + L.firstMin + spread % (L.firstSpread + 1)
end
ns.OnEvent("PLAYER_LOGIN", setFirst)

local function announce()
    if not firstAt and learned > 0 then setFirst() end
    if not firstAt or now() < firstAt or not canTalk() then return end
    -- the counts, not the index: the index is built again only when something is sent
    local c = ns.CollectCounts()
    local total = c.q + c.s + c.w
    if not announced then
        if total == 0 then
            emptyAtFirst = true
        elseif not (emptyAtFirst and pull) and sendCV() then
            announced, lastCV, ownAtCV, learnedAtCV = true, now(), ns.CollectOwnChanges(), learned
        end
        return
    end
    if now() - lastCV < L.every then return end
    local own = ns.CollectOwnChanges() > ownAtCV
    local heard = not reannounced and learned > learnedAtCV
    if (own or heard) and sendCV() then
        if heard then reannounced = true end
        lastCV, ownAtCV, learnedAtCV = now(), ns.CollectOwnChanges(), learned
    end
end

---------------------------------------------------------------------------
-- Pulling: CQ, CI, CR and the CK blob
---------------------------------------------------------------------------
local nextKind, nextCR, startNext

local function wantsOf(kinds)
    local ix, out = indexNow(), {}
    for _, kind in ipairs(KINDS) do
        local t, m = kinds[kind], ix.kinds[kind]
        if t and t.n > 0 and (t.h ~= m.hash or t.n ~= m.n) then out[#out + 1] = kind end
    end
    return out
end

local function heldBy(kinds)
    local n = 0
    for _, kind in ipairs(KINDS) do n = n + (kinds[kind] and kinds[kind].n or 0) end
    return n
end

local function evictPeer()
    local worst, worstUseless, worstN
    for i, p in ipairs(peers) do
        local useless, n = #wantsOf(p.kinds) == 0, heldBy(p.kinds)
        if not worst or (useless and not worstUseless) or (useless == worstUseless and n < worstN) then
            worst, worstUseless, worstN = i, useless, n
        end
    end
    table.remove(peers, worst)
end

local function queuePeer(name, kinds, at, nb, retry)
    local low = name:lower()
    for i, p in ipairs(peers) do
        if p.low == low then table.remove(peers, i) break end
    end
    peers[#peers + 1] = { name = name, low = low, kinds = kinds, at = at or now(), nb = nb or now(), retry = retry }
    while #peers > L.peersMax do evictPeer() end
end

local function stopPull(again)
    if pull and again then queuePeer(pull.name, pull.kinds, pull.at, now(), pull.retry) end
    pull = nil
end

startNext = function()
    if pull or not canTalk() then return end
    local t, ready = now(), {}
    for i = #peers, 1, -1 do
        local p = peers[i]
        if t - p.at > L.peerKeep then
            table.remove(peers, i)
        elseif p.nb <= t then
            ready[#ready + 1] = i
        end
    end
    while #ready > 0 do
        local pick = math.random(#ready)
        local i = ready[pick]
        local p = table.remove(peers, i)
        table.remove(ready, pick)
        for j, x in ipairs(ready) do if x > i then ready[j] = x - 1 end end
        local wants = wantsOf(p.kinds)
        if #wants > 0 then
            pull = { name = p.name, low = p.low, kinds = p.kinds, at = p.at, retry = p.retry or 0, missed = 0, wants = wants, wi = 0 }
            stats.pulls = stats.pulls + 1
            return nextKind()
        end
    end
end

nextKind = function()
    pull.wi = pull.wi + 1
    local kind = pull.wants[pull.wi]
    if not kind then
        -- answers that did not come (a busy sender, a lost blob): the sender is asked again later,
        -- twice at most for one announcement
        if pull.missed > 0 and pull.retry < L.retries then
            queuePeer(pull.name, pull.kinds, now(), now() + 60 + math.random() * L.pullJitter, pull.retry + 1)
        end
        pull = nil
        return startNext()
    end
    pull.kind, pull.stage, pull.parts, pull.n, pull.got, pull.deadline = kind, "CI", {}, nil, 0, now() + L.ciWait
    if not send("CQ", { kind }, "WHISPER", pull.name) then pull = nil end
end

local function hourCount()
    local t, keep = now(), {}
    for _, at in ipairs(crTimes) do
        if t - at < 3600 then keep[#keep + 1] = at end
    end
    crTimes = keep
    return #keep
end

nextCR = function()
    if #pull.crs == 0 then return nextKind() end
    if hourCount() >= L.crPerHour then
        debugLine("Anfragen der Stunde erreicht.")
        return stopPull(true)
    end
    local buckets = indexNow().kinds[pull.kind].buckets
    local fields, bs, len = {}, {}, 0
    while #pull.crs > 0 and #fields < 2 * L.crBuckets do
        local b = pull.crs[1]
        local bk = buckets[b]
        local field = "*"
        if bk and #bk.ids > 0 and #bk.ids <= L.knownMax then
            local list = {}
            for i, id in ipairs(bk.ids) do list[i] = known4(id, bk.dig[id]) end
            field = table.concat(list, ",")
        end
        local add = 3 + #field + 2
        if #fields > 0 and len + add > L.crChars then break end
        table.remove(pull.crs, 1)
        fields[#fields + 1], fields[#fields + 2] = ("%s%02x"):format(pull.kind, b), field
        bs[b] = true
        len = len + add
    end
    local first = tonumber(fields[1]:sub(2), 16)
    if not send("CR", fields, "WHISPER", pull.name) then return stopPull(false) end
    crTimes[#crTimes + 1] = now()
    local akey = fields[1] .. "|" .. pull.low
    asked[akey] = { at = now(), kind = pull.kind, b = first, bs = bs }
    pull.stage, pull.akey, pull.deadline = "CK", akey, now() + L.crWait
end

local function parseKinds(text)
    local kinds = {}
    for e in (text .. ","):gmatch("([^,]*),") do
        local k, h, n = e:match("^([qsw]):(%x+):(%d+)$")
        if k then kinds[k] = { h = h:lower(), n = tonumber(n) } end
    end
    return kinds
end

ns.CommOn("CV", function(sender, f, chan)
    if chan ~= "GUILD" then return end
    if tonumber(f[1]) ~= ns.COLLECT_PROTO then
        stats.other = stats.other + 1
        return
    end
    if not AmisiaDB or not ns.Get("collect.share") then return end
    local kinds = parseKinds(f[3])
    local name = ns.TrustName(sender)
    if not name then
        stats.refused = stats.refused + 1
        return
    end
    ns.TrustWait(name, "member", function(ok)
        if not ok then
            stats.refused = stats.refused + 1
            return
        end
        if pull and pull.low == name:lower() then return end
        queuePeer(name, kinds, now(), now() + math.random() * L.pullJitter)
    end)
end)

ns.CommOn("CI", function(sender, f, chan)
    if chan ~= "WHISPER" or not pull or pull.stage ~= "CI" then return end
    local name = ns.TrustName(sender)
    if not name or name:lower() ~= pull.low or f[1] ~= pull.kind then return end
    local i, n = tonumber(f[2]), tonumber(f[3])
    if pull.n and pull.n ~= n then
        stats.bad = stats.bad + 1
        pull = nil
        return startNext()
    end
    pull.n = n
    if not pull.parts[i] then
        pull.parts[i] = f[4]
        pull.got = pull.got + 1
    end
    if pull.got < n then return end
    local mine, crs = indexNow().kinds[pull.kind].buckets, {}
    for p = 1, n do
        if pull.parts[p] ~= "-" then
            for e in (pull.parts[p] .. ","):gmatch("([^,]*),") do
                local b, h, cnt = e:match("^(%x%x):(%x+):(%d+)$")
                b = tonumber(b, 16)
                local m = b and mine[b]
                if b and (not m or m.hash ~= h:lower()) then crs[#crs + 1] = b end
            end
        end
    end
    for j = #crs, 2, -1 do
        local k = math.random(j)
        crs[j], crs[k] = crs[k], crs[j]
    end
    pull.crs, pull.stage = crs, "CR"
    nextCR()
end)

ns.CommOn("CW", function(sender, f, chan)
    if chan ~= "WHISPER" or not pull then return end
    local name = ns.TrustName(sender)
    if not name or name:lower() ~= pull.low then return end
    stats.busy = stats.busy + 1
    if pull.akey then asked[pull.akey] = nil end
    local wait = math.max(30, math.min(tonumber(f[1]) or L.busyWait, 3600))
    queuePeer(pull.name, pull.kinds, now(), now() + wait + math.random() * L.pullJitter)
    pull = nil
    startNext()
end)

-- A blob checked whole: { v = 1, k = kind, r = { id, record, id, record, ... } }, every record valid
-- in its canonical form and of an asked bucket, 60 at most. Returns the list
-- { { kind, id, record } } or nil.
local function checkBlob(tbl, ask)
    if type(tbl) ~= "table" or tbl.v ~= 1 or tbl.k ~= ask.kind then return nil end
    local r = tbl.r
    if r == nil then return {} end
    if type(r) ~= "table" then return nil end
    local n = #r
    if n % 2 ~= 0 or n > 2 * L.blobRecords then return nil end
    local size = 0
    for _ in pairs(r) do size = size + 1 end
    if size ~= n then return nil end
    local out, seen = {}, {}
    for i = 1, n, 2 do
        local id, s = r[i], r[i + 1]
        if type(id) ~= "number" or id ~= math.floor(id) or id < 1 or id > 9999999 or not ask.bs[id % L.buckets] or seen[id] then return nil end
        if not ns.CollectParse(ask.kind, s) then return nil end
        seen[id] = true
        out[#out + 1] = { ask.kind, id, s }
    end
    return out
end

ns.CommOnBlob("CK", function(sender, tbl, chan, key)
    if chan ~= "WHISPER" then
        stats.bad = stats.bad + 1
        return
    end
    local name = ns.TrustName(sender)
    local low = name and name:lower()
    local ask
    for akey, a in pairs(asked) do
        if low and akey:sub(-#low - 1) == "|" .. low and blobKey(a.kind, a.b) == key then
            ask = a
            ask.akey = akey
            break
        end
    end
    if not ask or now() - ask.at > L.askKeep then
        stats.unasked = stats.unasked + 1
        debugLine("Quellen-Daten ohne Anfrage verworfen.")
        return
    end
    local list = checkBlob(tbl, ask)
    if not list then
        stats.bad = stats.bad + 1
        debugLine("Ungültige Quellen-Daten verworfen.")
        asked[ask.akey] = nil
        if pull and pull.akey == ask.akey then
            pull.missed = pull.missed + 1
            nextCR()
        end
        return
    end
    stats.blobs = stats.blobs + 1
    local c = ns.CollectDB()
    local take = {}
    for _, e in ipairs(list) do
        if c and not c[e[1]][e[2]] then
            if (senderNew[low] or 0) >= L.senderMax then
                stats.capped = stats.capped + 1
            else
                senderNew[low] = (senderNew[low] or 0) + 1
                take[#take + 1] = e
            end
        else
            take[#take + 1] = e
        end
    end
    stats.records = stats.records + #take
    local n = ns.CollectPutAll(take)
    stats.new, stats.merged = stats.new + n.new, stats.merged + n.merged
    learned = learned + n.new + n.merged
    asked[ask.akey] = nil
    if pull and pull.stage == "CK" and pull.akey == ask.akey then nextCR() end
end)

---------------------------------------------------------------------------
-- Answering: CQ with the buckets of a kind, CR with a blob, CW when busy
---------------------------------------------------------------------------
local function fromMember(sender, chan, fn)
    if chan ~= "WHISPER" or not AmisiaDB or not ns.Get("collect.share") then return end
    local name = ns.TrustName(sender)
    if not name then
        stats.refused = stats.refused + 1
        return
    end
    ns.TrustWait(name, "member", function(ok)
        if not ok then
            stats.refused = stats.refused + 1
            return
        end
        if canTalk() then fn(name) end
    end)
end

local function busyFor(low)
    local t, active = now(), {}
    for x, a in pairs(askers) do
        if a.at and t - a.at < L.activeKeep then active[x] = true end
    end
    for _, s in ipairs(serve) do active[s.low] = true end
    if active[low] then return false end
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n >= L.servePeers
end

local function shareLeft(low) return askerOf(low).bytes < L.sessionBytes / L.askerShare end
local function sendCW(name, low) send("CW", { tostring(L.busyWait) }, "WHISPER", name, nil, low) end

ns.CommOn("CQ", function(sender, f, chan)
    fromMember(sender, chan, function(name)
        local low = name:lower()
        if not shareLeft(low) then return end
        if busyFor(low) then return sendCW(name, low) end
        askerOf(low).at = now()
        local kind = f[1]
        local buckets = indexNow().kinds[kind].buckets
        local parts, cur = {}, {}
        for b = 0, L.buckets - 1 do
            local bk = buckets[b]
            if bk then
                if #cur >= L.ciEntries then
                    parts[#parts + 1] = table.concat(cur, ",")
                    cur = {}
                end
                cur[#cur + 1] = ("%02x:%s:%d"):format(b, bk.hash, #bk.ids)
            end
        end
        if #cur > 0 then parts[#parts + 1] = table.concat(cur, ",") end
        if #parts == 0 then parts[1] = "-" end
        for i = 1, #parts do
            if not send("CI", { kind, tostring(i), tostring(#parts), parts[i] }, "WHISPER", name, nil, low) then break end
        end
    end)
end)

ns.CommOn("CR", function(sender, f, chan)
    fromMember(sender, chan, function(name)
        local low = name:lower()
        if not shareLeft(low) then return end
        local kind, b = f[1]:sub(1, 1), tonumber(f[1]:sub(2), 16)
        local buckets = indexNow().kinds[kind].buckets
        local ids = {}
        for i = 1, #f - 1, 2 do
            local bk = buckets[tonumber(f[i]:sub(2), 16)]
            local known = {}
            if f[i + 1] ~= "*" then
                for e in (f[i + 1] .. ","):gmatch("([^,]*),") do known[e:lower()] = true end
            end
            for _, id in ipairs(bk and bk.ids or {}) do
                if not known[known4(id, bk.dig[id])] then ids[#ids + 1] = id end
            end
        end
        -- an asker has one request open at a time: a new one replaces what still waits for it
        for i = #serve, 1, -1 do
            if serve[i].low == low then table.remove(serve, i) end
        end
        if busyFor(low) or #serve >= L.serveMax then return sendCW(name, low) end
        askerOf(low).at = now()
        serve[#serve + 1] = { name = name, low = low, kind = kind, b = b, ids = ids, at = now() }
    end)
end)

local function wire(kind, ids)
    local c = ns.CollectDB()
    local t = { v = 1, k = kind, r = {} }
    for _, id in ipairs(ids) do
        local s = c and c[kind][id]
        if s then
            t.r[#t.r + 1] = id
            t.r[#t.r + 1] = s
        end
    end
    if #t.r == 0 then t.r = nil end
    return t
end

-- The longest front of ids that packs into one blob (20 parts, 60 records).
local function fit(kind, ids)
    local n = math.min(#ids, L.blobRecords)
    for _ = 1, 8 do
        local list = {}
        for i = 1, n do list[i] = ids[i] end
        local tbl = wire(kind, list)
        local packed = ns.CommPack(tbl)
        if not packed then return nil end
        local parts = math.ceil(#packed / 200)
        if parts <= L.blobParts then return tbl, packed end
        if n <= 1 then return nil end
        n = math.max(1, math.min(n - 1, math.floor(n * L.blobParts / parts * 0.95)))
    end
    return nil
end

local function partsRecent()
    local t, keep, n = now(), {}, 0
    for _, p in ipairs(partsLog) do
        if t - p[1] < L.partsWindow then
            keep[#keep + 1] = p
            n = n + p[2]
        end
    end
    partsLog = keep
    return n
end

local function nextServe()
    local t, best = now(), nil
    for i = #serve, 1, -1 do
        if t - serve[i].at > L.serveKeep then table.remove(serve, i) end
    end
    for i, s in ipairs(serve) do
        local last = askerOf(s.low).served or -math.huge
        if not best or last < best.last then best = { i = i, last = last } end
    end
    return best and best.i
end

-- One blob of a waiting request when the gaps allow it; what does not fit is left for a later round
-- (the bucket still differs then).
local function serveOne()
    if #serve == 0 or not canTalk() then return end
    local t = now()
    if lastBlob and t - lastBlob < L.serveGap then return end
    local i = nextServe()
    if not i then return end
    local s = serve[i]
    local tbl, packed = fit(s.kind, s.ids)
    if not tbl then
        table.remove(serve, i)
        return
    end
    local parts = math.ceil(#packed / 200)
    if partsRecent() + parts > L.partsMax then return end
    local estimate = #packed + parts * PART_OVERHEAD
    if not afford(estimate, s.low) then
        debugLine("Sendegrenze erreicht.")
        table.remove(serve, i)
        return
    end
    local ok, n, bytes = ns.CommSendBlob("CK", blobKey(s.kind, s.b), tbl, "WHISPER", s.name, { low = true, when = canTalk })
    table.remove(serve, i)
    if not ok then return end
    charge(bytes or estimate, s.low)
    stats.served = stats.served + 1
    lastBlob = t
    local a = askerOf(s.low)
    a.served, a.at = t, t
    partsLog[#partsLog + 1] = { t, n or parts }
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------
local function tick()
    if not AmisiaDB then return end
    local t = now()
    if pull and not canTalk() then
        stopPull(true)
    elseif pull and t > pull.deadline then
        if pull.stage == "CK" then
            if pull.akey then asked[pull.akey] = nil end
            pull.missed = pull.missed + 1
            nextCR()
        else
            pull = nil
        end
    end
    if not pull then startNext() end
    announce()
    serveOne()
    for k, a in pairs(asked) do
        if t - a.at > L.askKeep then asked[k] = nil end
    end
end

C_Timer.NewTicker(L.tick, function()
    local ok, err = pcall(tick)
    if not ok then report(err) end
end)

function ns.CollectSyncStats()
    local out = {}
    for k, v in pairs(stats) do out[k] = v end
    out.crHour = hourCount()
    return out
end

-- Opens a request for buckets of a kind at a sender as a pull would (tests and the self-test).
function ns.CollectSyncOpenAsk(name, kind, buckets)
    local bs = {}
    for _, b in ipairs(buckets) do bs[b] = true end
    local akey = ("%s%02x|%s"):format(kind, buckets[1], name:lower())
    asked[akey] = { at = now(), kind = kind, b = buckets[1], bs = bs }
end

function ns.CollectSyncState()
    return { pulling = pull and pull.name or nil, waiting = #peers, serving = #serve }
end
