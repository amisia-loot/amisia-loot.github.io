-- The other layer addon (F-220, D-145, ns.LayerForeign): the most widely used layer addon asks and answers by
-- hidden whispers on its own prefix, in plain text. Amisia speaks that format (read from its messages, no code
-- of it taken), so that "Layer wechseln" reaches its helpers and "Helfen" invites its users. Its name stands in
-- exactly one line, the prefix below (D-05); everywhere else it is "the other layer addon".
-- Off with layer.foreign, and whenever that addon itself is loaded (it asks and answers then; two answers and
-- two invites would follow): LF.Active.
-- Asker: SW._sendZone (Gear/LayerChange.lua) hands every /who name that is not a known Amisia user to LF.Ask:
-- the ask "inv layer <LS <zone map> not <own wire id> <x>,<y>>" ("want <id>" for a row's layer, more "not"
-- for "Nur neue Layer"; the position in percent of the zone map, one decimal), one per name and search, at
-- most BURST whispers a second (ns.CommSendPlain, Core/Comm.lua; result 3 waits for the next second, 4 ends
-- the asks for the session). Answers: "heard <asker>|<wire id or ->|<zone or ->|<h or ->" (only with the own
-- name, from a name asked) and "same" go to SW._foreignAnswer (counted like ZA); a "heard" with "h" but no
-- layer gets the ask without a layer once, REASK_WAIT seconds later.
-- Host: an ask whispered on the prefix (strictly checked: at most MAX_TEXT characters, the zone first, only
-- "want"/"not" with wire ids, the position last and 0-100) from the own zone map gets "heard" (once per asker in
-- HEARD_GAP, HEARD_MAX a minute in all; "h" when Amisia would invite), "same" when the own layer is the one the
-- asker leaves; with "Helfen" the invite through SW.Offer (Amisia's limits: six in ten minutes, one per player a
-- minute, never in an instance, not in the group finder, layer.combatPause, alone or only own guests, the world
-- restart, layer.skipNear). Guests are never taken out by themselves ("Helfen" off and the kick do it).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local LY, SW = ns.Layer, ns.LayerChange

local LF = {}
ns.LayerForeign = LF

local OTHER_PREFIX = "LayerSwap"
LF.PREFIX = OTHER_PREFIX
LF.BURST, LF.ROUND = 8, 1   -- whispers per ROUND seconds at most
LF.TICK = 0.25
LF.TTL = 45                 -- seconds an ask may wait in the queue
LF.MAX_QUEUE = 100
LF.MAX_TEXT = 120           -- characters of a received line at most
LF.HEARD_GAP = 10           -- seconds between two answers to one asker
LF.HEARD_WINDOW, LF.HEARD_MAX = 60, 20
LF.REASK_WAIT = 3           -- seconds before the ask without a layer to a helper that named none
LF.LEAVES_KEEP = 30         -- seconds the layers an asker leaves count for its ask without a layer
LF.MAX_NOTS = 7             -- "not" ids in one ask (the own and six seen ones)
local MAX_ZONE = 999999

local queue = {}            -- { target, text, sent, at }
local sentTimes = {}        -- the times of this ROUND's whispers
local ticker
local refused               -- the client refused whispers on the prefix (result 4): no more this session
local stats = { sent = 0, throttled = 0, failed = 0, dropped = 0, asked = 0, answers = 0, heard = 0, same = 0, invites = 0, bad = 0 }
local heardAt, heardTimes = {}, {}   -- host: [lower asker] = time of the last answer; the answers of a minute
local leaves = {}           -- host: [lower asker] = { nots, at } the layers its last ask left
local search                -- asker: { z, text, plain, reasked = { [lower name] = true } }

local function now() return GetTime() end

-- Whether the other layer addon itself is loaded.
local function otherLoaded()
    local api = rawget(_G, "C_AddOns")
    local f = type(api) == "table" and api.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f, OTHER_PREFIX)
    return ok and ns.Plain(v) and true or false
end
LF.OtherLoaded = otherLoaded

local registered, regResult = ns.CommPlainPrefix(OTHER_PREFIX)

-- Whether Amisia speaks the other layer addon's format now: layer.foreign on, the prefix registered, the client
-- did not refuse it, that addon not loaded itself.
function LF.Active()
    return ns.Get("layer.foreign") ~= false and registered and not refused and ns.CommAvailable() and not otherLoaded()
end

-- For /amisia selbsttest layer: the prefix, the switch, this session's counts.
function LF.Status()
    return { registered = registered, result = regResult, other = otherLoaded(), on = ns.Get("layer.foreign") ~= false,
        refused = refused and true or false, active = LF.Active() and true or false, stats = stats, queued = #queue }
end

-- The name the sender has here (the own realm's ending dropped) and the name the other addon writes into
-- "heard" (everything before the first "-").
local function nameOf(raw)
    raw = ns.Plain(raw)
    if type(raw) ~= "string" or raw == "" or #raw > 64 then return nil end
    return ns.StripOwnRealm(raw) or ns.FullName(raw)
end

---------------------------------------------------------------------------
-- The format
---------------------------------------------------------------------------
-- The ask: zone map, opts.want (a wire id) or opts.nots (wire ids), opts.x, opts.y (percent, both or none).
function LF.AskText(zoneMap, opts)
    opts = opts or {}
    local parts = { "inv layer <LS", tostring(zoneMap) }
    if opts.want then
        parts[#parts + 1] = "want " .. opts.want
    else
        for i, id in ipairs(opts.nots or {}) do
            if i > LF.MAX_NOTS then break end
            parts[#parts + 1] = "not " .. id
        end
    end
    if opts.x and opts.y then parts[#parts + 1] = ("%.1f,%.1f"):format(opts.x, opts.y) end
    return table.concat(parts, " ") .. ">"
end

-- An ask read strictly: { zone, want = { uid, zuid }, nots = { { uid, zuid } }, x, y } or nil. A position out of
-- 0-100 counts as none (as the other addon reads it); every other deviation drops the line.
function LF.ParseAsk(text)
    text = ns.Plain(text)
    if type(text) ~= "string" or #text > LF.MAX_TEXT or text:find("%c") then return nil end
    local body = text:match("^inv layer <LS ([^<>]*)>$")
    if not body then return nil end
    local words = {}
    for w in body:gmatch("%S+") do
        words[#words + 1] = w
        if #words > 2 * LF.MAX_NOTS + 3 then return nil end
    end
    local zone = words[1] and words[1]:match("^%d+$") and tonumber(words[1])
    if not zone or zone <= 0 or zone > MAX_ZONE then return nil end
    local ask = { zone = zone, nots = {} }
    local last = #words
    local px, py = (words[last] or ""):match("^(%d+%.?%d*),(%d+%.?%d*)$")
    if last > 1 and px then
        px, py = tonumber(px), tonumber(py)
        if px and py and px <= 100 and py <= 100 then ask.x, ask.y = px, py end
        last = last - 1
    end
    local i = 2
    while i <= last do
        local w = words[i]
        local uid, zuid = LY.ParseWire(words[i + 1])
        if (w ~= "want" and w ~= "not") or not uid then return nil end
        if w == "want" then
            if ask.want then return nil end
            ask.want = { uid, zuid }
        else
            if #ask.nots >= LF.MAX_NOTS + 1 then return nil end
            ask.nots[#ask.nots + 1] = { uid, zuid }
        end
        i = i + 2
    end
    if ask.want and #ask.nots > 0 then return nil end
    return ask
end

-- An answer read strictly: { kind = "same" } or { kind = "heard", name, uid, zuid, zone, helps }, else nil.
function LF.ParseReply(text)
    text = ns.Plain(text)
    if type(text) ~= "string" or #text > LF.MAX_TEXT or text:find("%c") then return nil end
    if text == "same" then return { kind = "same" } end
    local who, layer, zone, flag = text:match("^heard ([^|]+)|([^|]*)|([^|]*)|([^|]*)$")
    if not who or #who > 48 or (flag ~= "h" and flag ~= "-") then return nil end
    local r = { kind = "heard", name = who, helps = flag == "h" }
    if layer ~= "-" then
        r.uid, r.zuid = LY.ParseWire(layer)
        if not r.uid then return nil end
    end
    if zone ~= "-" then
        r.zone = zone:match("^%d+$") and tonumber(zone)
        if not r.zone or r.zone <= 0 or r.zone > MAX_ZONE then return nil end
    end
    return r
end

---------------------------------------------------------------------------
-- Sending: BURST whispers a ROUND at most
---------------------------------------------------------------------------
local function pump()
    local t = now()
    local keep = {}
    for _, e in ipairs(queue) do
        if t - e.at <= LF.TTL then keep[#keep + 1] = e else stats.dropped = stats.dropped + 1 end
    end
    queue = keep
    local recent = {}
    for _, at in ipairs(sentTimes) do if t - at < LF.ROUND then recent[#recent + 1] = at end end
    sentTimes = recent
    while #queue > 0 and #sentTimes < LF.BURST do
        if refused then
            stats.dropped = stats.dropped + #queue
            queue = {}
            break
        end
        local e = queue[1]
        local result = ns.CommSendPlain(OTHER_PREFIX, e.text, e.target)
        if result == 0 then
            table.remove(queue, 1)
            sentTimes[#sentTimes + 1] = t
            stats.sent = stats.sent + 1
            if e.sent then
                local ok, err = pcall(e.sent)
                if not ok then ns.ReportError(err) end
            end
        elseif result == 3 or result == 8 or result == 11 then
            -- throttled or the lockdown: the next round tries again
            stats.throttled = stats.throttled + 1
            break
        else
            if result == 4 then refused = true end
            table.remove(queue, 1)
            stats.failed = stats.failed + 1
        end
    end
    if #queue == 0 and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function whisper(target, text, sent)
    if #queue >= LF.MAX_QUEUE then
        stats.dropped = stats.dropped + 1
        return false
    end
    queue[#queue + 1] = { target = target, text = text, sent = sent, at = now() }
    if not ticker then ticker = C_Timer.NewTicker(LF.TICK, function() pump() end) end
    pump()
    return true
end

---------------------------------------------------------------------------
-- Asking (part 1)
---------------------------------------------------------------------------
-- The own position on the zone map in percent, nil when the client tells none.
local function ownPercent(map)
    local api = rawget(_G, "C_Map")
    if type(api) ~= "table" or type(api.GetPlayerMapPosition) ~= "function" then return nil end
    local ok, pos = pcall(api.GetPlayerMapPosition, map, "player")
    if not ok or type(pos) ~= "table" then return nil end
    local x, y = tonumber(ns.Plain(pos.x)), tonumber(ns.Plain(pos.y))
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then return nil end
    return x * 100, y * 100
end

-- The ask of the open search (built once per search): "want" for a row's layer, else "not" the own layer and,
-- with "Nur neue Layer", the layers seen within the hour.
local function searchText(z, r, target, recent)
    local x, y = ownPercent(r.map)
    local opts = { x = x, y = y }
    if target then
        local _, zuid = LY.ParseWire(LY.CurrentWire())
        opts.want = LY.Wire(r.map, target) or LY.WireText(target, zuid or 0)
    else
        local own = LY.Wire(r.map, r.uid)
        opts.nots = { own }
        for uid in pairs(recent or {}) do
            local wire = uid ~= r.uid and LY.Wire(r.map, uid)
            if wire and #opts.nots < LF.MAX_NOTS then opts.nots[#opts.nots + 1] = wire end
        end
        if not own then opts.nots = {} end
    end
    return { z = z, text = LF.AskText(r.map, opts), plain = LF.AskText(r.map, { x = x, y = y }), want = target ~= nil, reasked = {} }
end

-- The ask to name for the open search z of Gear/LayerChange.lua; sent() once it went. false when it cannot go.
function LF.Ask(z, name, sent)
    if not LF.Active() then return false end
    local zz, r, target, recent = SW._search()
    if not zz or zz ~= z then return false end
    if not search or search.z ~= z then search = searchText(z, r, target, recent) end
    return whisper(name, search.text, function()
        stats.asked = stats.asked + 1
        sent()
    end)
end

-- A helper that names no layer but would invite: the ask without a layer, once per search (never for "want").
local function reask(name, target)
    local s = search
    if not s or s.want or s.reasked[name:lower()] then return end
    s.reasked[name:lower()] = true
    C_Timer.After(LF.REASK_WAIT, function()
        local z = SW._search()
        if search ~= s or z ~= s.z or SW.SwapStep() == "busy" or not LF.Active() then return end
        whisper(target, s.plain)
    end)
end

local function onAnswer(r, sender, name)
    local z, req = SW._search()
    if not z then return end
    if r.kind == "heard" then
        if not ns.SameName(r.name, ns.UnitFullName("player")) then return end
        -- a player of another zone cannot bring the own one anywhere
        if r.zone and r.zone ~= req.map then r.uid, r.helps = nil, false end
    end
    if not SW._foreignAnswer(name, r.uid, r.zuid, r.helps, r.kind == "same") then return end
    stats.answers = stats.answers + 1
    if r.kind == "heard" and r.helps and not r.uid then reask(name, sender) end
end

---------------------------------------------------------------------------
-- Helping (part 2)
---------------------------------------------------------------------------
-- Yards between the own place and x, y (percent) of map, nil when unknown.
function LF.Distance(map, x, y)
    local api = rawget(_G, "C_Map")
    local vec = rawget(_G, "CreateVector2D")
    if type(api) ~= "table" or type(api.GetWorldPosFromMapPos) ~= "function" or type(vec) ~= "function" then return nil end
    local px, py = ownPercent(map)
    if not px then return nil end
    local function world(a, b)
        local ok, cont, pos = pcall(api.GetWorldPosFromMapPos, map, vec(a / 100, b / 100))
        if not ok or type(pos) ~= "table" then return nil end
        local wx, wy = tonumber(ns.Plain(pos.x)), tonumber(ns.Plain(pos.y))
        if not wx or not wy then return nil end
        return ns.Plain(cont), wx, wy
    end
    local c1, x1, y1 = world(px, py)
    local c2, x2, y2 = world(x, y)
    if not x1 or not x2 or c1 ~= c2 then return nil end
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

-- Whether Amisia would invite this ask now (the "h" of "heard"): helping, the limits, the layer rules.
function LF.WillInvite(ask, low, mine)
    if not mine or not SW.Hosting() or not SW.CanHelp() or not ns.Get("layer.answer") or SW.Asking() then return false end
    if LY.InInstance() or not SW.CanInvite() or SW.InviteBreak() > 0 then return false end
    if ask.want then
        if ask.want[1] ~= mine then return false end
    else
        local nots = ask.nots
        -- an ask without a layer right after one with: the layers it left still count (the other addon does the same)
        local l = leaves[low]
        if #nots == 0 and l and now() - l.at <= LF.LEAVES_KEEP then nots = l.nots end
        for _, n in ipairs(nots) do
            if n[1] == mine then return false end
        end
    end
    if ns.Get("layer.skipNear") then
        if not ask.x then return false end
        local d = LF.Distance(ask.zone, ask.x, ask.y)
        if not d or d < (tonumber(ns.Get("layer.skipNearYards")) or 150) then return false end
    end
    return true
end

local function onAsk(text, sender, name)
    local ask = LF.ParseAsk(text)
    if not ask then
        stats.bad = stats.bad + 1
        return
    end
    if LY.InInstance() then return end
    local myMap = LY.Map()
    if not myMap or ask.zone ~= myMap then return end
    local t, low = now(), name:lower()
    if heardAt[low] and t - heardAt[low] < LF.HEARD_GAP then return end
    local keep = {}
    for _, at in ipairs(heardTimes) do if t - at < LF.HEARD_WINDOW then keep[#keep + 1] = at end end
    heardTimes = keep
    if #heardTimes >= LF.HEARD_MAX then return end
    heardTimes[#heardTimes + 1] = t
    for k, at in pairs(heardAt) do
        if t - at >= LF.HEARD_GAP then heardAt[k] = nil end
    end
    heardAt[low] = t
    for k, l in pairs(leaves) do
        if t - l.at > LF.LEAVES_KEEP then leaves[k] = nil end
    end
    if #ask.nots > 0 then leaves[low] = { nots = ask.nots, at = t } end
    stats.heard = stats.heard + 1
    local mine, map = LY.Current()
    if mine and (map ~= myMap or not LY.Fresh()) then mine = nil end
    local helps = LF.WillInvite(ask, low, mine)
    local short = sender:match("^([^%-]+)") or sender
    whisper(sender, ("heard %s|%s|%d|%s"):format(short, mine and LY.Wire(map, mine) or "-", myMap, helps and "h" or "-"))
    local on = ask.nots[1] and mine and ask.nots[1][1] == mine
    if on and SW.Hosting() and SW.CanHelp() then
        stats.same = stats.same + 1
        whisper(sender, "same")
    end
    if helps then
        stats.invites = stats.invites + 1
        SW.Offer(name, L["%s möchte über das andere Layer-Addon auf deinen Layer wechseln (%s). Einladen?"]:format(name, LY.Name(map, mine)),
            true, true)
    end
end

-- A whisper on the other layer addon's prefix: asks to the host, answers to the asker; nothing else.
function LF.Receive(text, chan, sender)
    text, chan, sender = ns.Plain(text), ns.Plain(chan), ns.Plain(sender)
    if chan ~= "WHISPER" or type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    if ns.Get("layer.foreign") == false or not registered or otherLoaded() then return end
    local name = nameOf(sender)
    if not name or ns.SameName(name, ns.UnitFullName("player")) then return end
    if text:sub(1, 10) == "inv layer " then return onAsk(text, sender, name) end
    local r = LF.ParseReply(text)
    if r then return onAnswer(r, sender, name) end
    stats.bad = stats.bad + 1
end

ns.OnEvent("CHAT_MSG_ADDON", function(prefix, text, chan, sender)
    if ns.Plain(prefix) ~= OTHER_PREFIX then return end
    LF.Receive(text, chan, sender)
end)

-- for the tests
function LF._reset()
    queue, sentTimes, refused, search = {}, {}, nil, nil
    heardAt, heardTimes, leaves = {}, {}, {}
    for k in pairs(stats) do stats[k] = 0 end
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end
end)
