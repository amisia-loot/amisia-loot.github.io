-- Amisia chat: one queue for everything Amisia writes into the chat. Lines go out at once while
-- the byte bucket holds enough and the chat is open; otherwise they wait. During the chat lockdown
-- of a boss fight (Forever) nothing is sent at all, since the client gives no sign whether a line
-- got through; the queue is released when the restriction ends. Incoming "!word" commands from
-- raiders without the addon are dispatched to registered handlers.
local ADDON, ns = ...

local BURST = 2000        -- bytes that may go out at once
local REFILL = 800        -- bytes per second after that
local MAX_QUEUE = 40      -- waiting lines; more are refused
local MAX_BYTES = 255     -- the client's limit for one chat line
local LINE_BYTES = 250    -- what ns.ChatLines puts on one line
local TICK = 0.25         -- queue ticker while lines wait
local LOCK_POLL = 2       -- seconds between lockdown checks while held, in case the event is missing
local DEFAULT_TTL = 600

local queue = {}          -- { text, chan, target, expires, key }
local tokens, refilledAt = BURST, nil
local ticker
local held, lockCheckedAt = false, 0
local warnedFull, warnedError = nil, nil

local function now() return GetTime() end

local function refill()
    local t = now()
    if refilledAt then
        tokens = math.min(BURST, tokens + (t - refilledAt) * REFILL)
    end
    refilledAt = t
end

-- Whether the client holds addon chat messages back (boss fight on Forever). Without the query
-- (older client) nothing is locked.
function ns.ChatLocked()
    local info = _G.C_ChatInfo
    local fn = type(info) == "table" and info.InChatMessagingLockdown
    if type(fn) ~= "function" then return false end
    local ok, locked = pcall(fn)
    return (ok and locked) and true or false
end

function ns.ChatQueueSize() return #queue end

-- One own chat message at most once a minute per kind.
local function warnOnce(kind, text)
    local t = time()
    if kind == "full" then
        if warnedFull and t - warnedFull < 60 then return end
        warnedFull = t
    else
        if warnedError and t - warnedError < 60 then return end
        warnedError = t
    end
    ns.msg(text)
end

-- The channel a line can really go to: raid warning needs leader or assistant, raid needs a raid,
-- party needs a group. nil when there is nobody to talk to.
local function resolveChannel(chan)
    if chan == "WHISPER" then return chan end
    if chan == "RAID_WARNING" and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then chan = "RAID" end
    if (chan == "RAID" or chan == "RAID_WARNING") and not IsInRaid() then chan = "PARTY" end
    if not IsInGroup() then return nil end
    return chan
end

-- Byte ranges of the links in a text, so a cut never lands inside one.
local function linkRanges(text)
    local out, pos = {}, 1
    while true do
        local s = text:find("|H", pos, true)
        if not s then break end
        -- a colour code right before the link belongs to it
        local cs = s
        if s >= 11 and text:sub(s - 10, s - 9) == "|c" then cs = s - 10 end
        local close = text:find("|h", s + 2, true)
        local e = close and text:find("|h", close + 2, true)
        if not e then
            out[#out + 1] = { cs, #text }
            break
        end
        e = e + 1
        if text:sub(e + 1, e + 2) == "|r" then e = e + 2 end
        out[#out + 1] = { cs, e }
        pos = e + 1
    end
    return out
end

-- Cuts a line over 255 bytes at the last space that lies outside every link.
local function fit(text)
    if #text <= MAX_BYTES then return text end
    local ranges = linkRanges(text)
    local function inLink(i)
        for _, r in ipairs(ranges) do
            if i >= r[1] and i <= r[2] then return r end
        end
        return nil
    end
    local cut
    for i = MAX_BYTES + 1, 2, -1 do
        if text:sub(i, i) == " " and not inLink(i) then cut = i - 1 break end
    end
    if not cut then
        -- no space: cut at the limit, or before a link the limit falls into
        local r = inLink(MAX_BYTES + 1)
        cut = r and (r[1] - 1) or MAX_BYTES
    end
    local out = text:sub(1, cut):gsub("%s+$", "")
    return out
end

local function send(e)
    local chan = resolveChannel(e.chan)
    if not chan then return false end
    -- C_ChatInfo.SendChatMessage (the global is only a deprecated alias the client may lack)
    local info = _G.C_ChatInfo
    local fn = type(info) == "table" and info.SendChatMessage
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, e.text, chan, nil, chan == "WHISPER" and e.target or nil)
    if not ok then
        warnOnce("error", "Chat-Zeile konnte nicht gesendet werden.")
        return false
    end
    tokens = tokens - #e.text
    return true
end

local pump

local function startTicker()
    if ticker then return end
    ticker = C_Timer.NewTicker(TICK, function() pump(false) end)
end

local function stopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
end

-- Sends what the bucket allows. force: check the lockdown now (event), not only every 2 s.
pump = function(force)
    local t = now()
    -- expired lines fall out first (a countdown is worthless after the fight)
    local keep = {}
    for _, e in ipairs(queue) do
        if e.expires > t then keep[#keep + 1] = e end
    end
    queue = keep
    if held and not force and t - lockCheckedAt < LOCK_POLL then return end
    lockCheckedAt = t
    held = ns.ChatLocked()
    if not held then
        refill()
        while queue[1] and tokens >= #queue[1].text do
            send(table.remove(queue, 1))
        end
    end
    if #queue == 0 then stopTicker() end
end

-- Says a line in chan ("RAID", "RAID_WARNING", "PARTY", "WHISPER" with target). opts.ttl: seconds
-- a waiting line stays valid (default 600); opts.key: a waiting line with the same key is replaced.
-- Returns "sent", "queued", or nil and the reason.
function ns.Say(text, chan, target, opts)
    if type(text) ~= "string" or text == "" then return nil, "Kein Text." end
    if chan == "WHISPER" and (type(target) ~= "string" or target == "") then return nil, "Kein Empfänger." end
    if not resolveChannel(chan) then return nil, "Keine Gruppe." end
    opts = opts or {}
    local e = { text = fit(text), chan = chan, target = target, key = opts.key,
                expires = now() + (tonumber(opts.ttl) or DEFAULT_TTL) }
    if #queue == 0 then
        lockCheckedAt = now()
        held = ns.ChatLocked()
        if not held then
            refill()
            if tokens >= #e.text then
                if send(e) then return "sent" end
                return nil, "Senden fehlgeschlagen."
            end
        end
    end
    if e.key then
        for i, q in ipairs(queue) do
            if q.key == e.key then
                queue[i] = e
                startTicker()
                return "queued"
            end
        end
    end
    if #queue >= MAX_QUEUE then
        warnOnce("full", "Chat-Warteschlange voll, Zeilen verworfen.")
        return nil, "Warteschlange voll."
    end
    queue[#queue + 1] = e
    startTicker()
    return "queued"
end

-- Splits parts onto lines of at most 250 bytes: head starts the first line, parts are joined with
-- sep (default ", ") and never split, so a link stays whole.
function ns.ChatLines(head, parts, sep)
    head, sep = head or "", sep or ", "
    local lines, cur, fresh = {}, head, true
    for _, p in ipairs(parts or {}) do
        p = tostring(p)
        local add = fresh and p or (sep .. p)
        if not fresh and #cur + #add > LINE_BYTES then
            lines[#lines + 1] = cur
            cur, add = "", p
        end
        cur = cur .. add
        fresh = false
    end
    lines[#lines + 1] = cur
    return lines
end

-- The restriction changed: read the state after the dispatch (it is not final during it).
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    C_Timer.After(0, function()
        if #queue > 0 then pump(true) else held = ns.ChatLocked() end
    end)
end)

---------------------------------------------------------------------------
-- Incoming "!word" commands
---------------------------------------------------------------------------
local commands = {}   -- lower-case word -> fn(sender, rest, chan)

-- fn gets the sender as the client gives it (answer to that, not to a rebuilt name), the rest of
-- the line and "WHISPER", "RAID", "PARTY" or "GUILD".
function ns.RegisterChatCommand(word, fn)
    commands[word:lower()] = fn
end

local function onCommand(chan, text, sender)
    -- a secret text or sender (lockdown) is skipped; it cannot be answered later either
    text, sender = ns.Plain(text), ns.Plain(sender)
    if type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    local word, rest = text:match("^!(%a+)%s*(.-)%s*$")
    if not word then return end
    local fn = commands[word:lower()]
    if not fn then return end
    if ns.SameName(sender, ns.UnitFullName("player")) then return end
    local ok, err = pcall(fn, sender, rest, chan)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

for event, chan in pairs({ CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
                           CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY", CHAT_MSG_GUILD = "GUILD" }) do
    ns.OnEvent(event, function(text, sender) onCommand(chan, text, sender) end)
end

---------------------------------------------------------------------------
-- Answer limits for "!word" commands
---------------------------------------------------------------------------
local GATE_GAP = 15       -- seconds between two answers to one sender
local GATE_PER_MIN = 20   -- answers a minute per command word
local gates = {}          -- word -> { last = { key -> GetTime() }, times = { GetTime() }, warned }

-- Whether an answer to key (a sender) for word may go out now: one per key every 15 s, 20 a minute
-- per word, otherwise quiet; the first refusal by the minute limit notes it once a minute in the
-- own chat. A true answer counts as sent.
function ns.ReplyGate(word, key)
    word = tostring(word or "?")
    key = tostring(key or ""):lower()
    local g = gates[word]
    if not g then
        g = { last = {}, times = {} }
        gates[word] = g
    end
    local t = GetTime()
    if g.last[key] and t - g.last[key] < GATE_GAP then return false end
    local keep = {}
    for _, at in ipairs(g.times) do
        if t - at < 60 then keep[#keep + 1] = at end
    end
    g.times = keep
    if #keep >= GATE_PER_MIN then
        if not g.warned or t - g.warned >= 60 then
            g.warned = t
            ns.msg(("Viele !%s-Anfragen: weitere bleiben bis zu einer Minute unbeantwortet."):format(word))
        end
        return false
    end
    -- senders whose gap is over are forgotten
    for k, at in pairs(g.last) do
        if t - at >= GATE_GAP then g.last[k] = nil end
    end
    g.last[key] = t
    keep[#keep + 1] = t
    return true
end
