-- The world layer (F-185, D-117, spec docs/specs/2026-11-12-layer.md, ns.Layer): a zone exists several
-- times; a creature's GUID ("Creature-0-<server>-<instance>-<zoneUID>-<npc>-<spawn>", also "Vehicle-")
-- tells by its zoneUID which copy the player stands in. Read from the target, the mouseover and the
-- name plates (PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT 0.25 s apart, NAME_PLATE_UNIT_ADDED 0.1 s
-- apart; a few string operations per event, nothing per frame), never in an instance, a boss fight or
-- the chat lockdown, never from anything a player controls (UnitPlayerControlled, UnitIsOtherPlayersPet,
-- UnitIsPlayer), a secret value skipped. Per zone map (the player's map lifted to its zone, as the map
-- page does it): an id is listed as seen once it was read on two different creatures (spawn) within
-- CAND_WINDOW; which one is current, the votes decide (F-221, below): a creature over the zone border
-- carries its neighbour's id. A
-- zone change and entering or leaving an instance make the layer unknown until creatures are read
-- again. Kept in memory only (a server restart hands out new ids); entries not seen for LIFE seconds
-- fall out. Names "Layer A", "Layer B" ...: the known ids of a map in ascending order, so guild members
-- who know the same ids say the same letter (a letter can shift when a lower id becomes known).
-- Fires LAYER ("current" when the current layer changes, "list" when a map's list does). Sends nothing.
-- Other layer addons run beside it untouched: no frame of theirs; their plain chat convention ("inv layer")
-- is understood by Gear/LayerChange.lua (D-117), the hidden whispers of the most widely used one by
-- Gear/LayerForeign.lua (F-220, D-145).
-- F-220 (D-145, changes D-117 in one point): the layer is the GUID's server part (its third field), as the
-- other layer addon counts it on Forever: "6843-8" and "6843-3" are one layer, the zoneUID changes with a
-- world restart. Every id of this file (uid) is that server part; the zoneUID last read with it is kept
-- (zuid) for the wire id "<server>-<zoneUID>" (LY.Wire). The world restart (SHARD_TRANSFER_IMMINENT with
-- GetEvictionTimeRemaining): LY.Refresh() counts down, then "gleich" for REFRESH_SOON seconds;
-- SHARD_TRANSFER (the move itself) makes the layer unknown until a creature is read again,
-- SHARD_TRANSFER_CANCELLED reads the time again or clears it.
-- F-221 (D-146), read as the other layer addon reads it: the current layer is the one the last VOTES readings
-- agree on (each creature votes once until the next zone or move): 2 of them while it is unknown, 3 to leave a
-- known one, so a stray creature over the border flips nothing. It stays known until a zone change, a move
-- (SHARD_TRANSFER) or entering the world (no time limit any more: LY.Known). The creatures in view at
-- SHARD_TRANSFER are the old layer's and count STALE_FOR seconds not. LY.Scan reads the 40 name plates, the
-- target and the mouseover; LY.Rescan does it unless a zone border was crossed within BORDER_QUIET seconds
-- (a creature carried over it is the zone left behind), by itself RESCAN seconds after entering the world and
-- after a move. LY.onRead (one function, Gear/LayerChange.lua) hears every reading. The layers of a zone seen
-- within SEEN_KEEP seconds stay through /reload (AmisiaDB.layerSeen, written at PLAYER_LOGOUT).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L

local LY = {}
ns.Layer = LY

LY.CAND_WINDOW = 120    -- seconds in which two creatures of a new id must be seen
LY.LIFE = 6 * 3600      -- seconds an id lives without being seen again
LY.VOTES = 5            -- F-221: the readings that vote for the current layer
LY.STALE_FOR = 10       -- seconds the creatures in view at SHARD_TRANSFER do not count
LY.BORDER_QUIET = 15    -- seconds after a zone border without a rescan
LY.RESCAN = { 2, 5, 12 }   -- seconds after entering the world and after a move: a rescan
LY.SEEN_KEEP = 3600     -- seconds a layer stays in AmisiaDB.layerSeen
local SEEN_MAPS, SEEN_LAYERS = 40, 20   -- AmisiaDB.layerSeen: zones and layers per zone at most
local PLATES = 40
LY.GAP = { mouseover = 0.25, plate = 0.1 }   -- throttle per source
local MAX_ZONE_UID = 4294967295
local MAX_CAND = 20     -- candidate spawns kept per id
local SWEEP_GAP = 60
local ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

LY.REFRESH_SOON = 120   -- seconds "Neustart gleich" shows after the countdown reached 0

local maps = {}         -- [map] = { layers = { [uid] = { first, last, own, heard, zuid } }, cand = { [uid] = { [spawn] = t } } }
local cur               -- { map, uid, zuid, at = the last time a creature of uid was read }
local evictAt           -- the time the announced world restart comes (GetEvictionTimeRemaining), nil: none
local zoneMap           -- the player's zone map (cached until a zone event), false: none
local lastAt = {}       -- source -> time of its last read
local sweptAt = 0
local votes = {}        -- F-221: the last VOTES readings (server parts), newest last
local voted = {}        -- [guid] = true: the creatures that voted since the last zone change or move
local stale             -- { untilAt, guid = { [guid] = true } }: the creatures in view at SHARD_TRANSFER
local borderAt          -- the time of the last zone border (ZONE_CHANGED_NEW_AREA)
-- for /amisia selbsttest layer (Core/SelfTestLayer.lua), this session only: how many units each source
-- read (read) and how many gave a zoneUID (ok), secret GUIDs, and the current layer's changes
-- ({ at, map, uid, grouped } and { at, zone = true } for a zone change between two of them), newest last
local MAX_HISTORY = 30
local stats = { read = {}, ok = {}, secret = 0 }
local history = {}

local function now() return GetTime() end

local function call(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, a = pcall(f, ...)
    if not ok then return nil end
    return ns.Plain(a)
end

local function inInstance()
    local f = rawget(_G, "IsInInstance")
    if type(f) ~= "function" then return false end
    local ok, inside = pcall(f)
    return ok and ns.Plain(inside) == true
end
LY.InInstance = inInstance

-- Nothing is read inside an instance, in a boss fight (restriction 1) or the chat lockdown.
local function blocked()
    return inInstance() or ns.AddOnRestricted(1) or ns.ChatLocked()
end

---------------------------------------------------------------------------
-- The GUID
---------------------------------------------------------------------------
-- A creature's GUID split: kind ("Creature" or "Vehicle"), the server part (the layer, a number above 0),
-- npc id, spawn (its hex text) and the zoneUID (a number above 0); nil for anything else (players, pets,
-- objects, a secret or broken value).
function LY.Parse(guid)
    guid = ns.Plain(guid)
    if type(guid) ~= "string" or #guid > 80 then return nil end
    local kind, server, zone, npc, spawn = guid:match("^(%a+)%-%d+%-(%d+)%-%d+%-(%d+)%-(%d+)%-(%x+)$")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    server, zone = tonumber(server), tonumber(zone)
    if not server or server <= 0 or server > MAX_ZONE_UID or not zone or zone <= 0 or zone > MAX_ZONE_UID then return nil end
    return kind, server, tonumber(npc), spawn, zone
end

-- The wire id of the other layer addon, "<server>-<zoneUID>" (D-145).
function LY.WireText(uid, zuid)
    uid, zuid = tonumber(uid), tonumber(zuid)
    if not uid or not zuid then return nil end
    return ("%d-%d"):format(uid, zuid)
end

-- A wire id split: server part (the layer) and zoneUID; nil for anything else.
function LY.ParseWire(text)
    text = ns.Plain(text)
    if type(text) ~= "string" or #text > 21 then return nil end
    local a, b = text:match("^(%d+)%-(%d+)$")
    a, b = tonumber(a), tonumber(b)
    if not a or not b or a <= 0 or a > MAX_ZONE_UID or b > MAX_ZONE_UID then return nil end
    return a, b
end

---------------------------------------------------------------------------
-- The zone map
---------------------------------------------------------------------------
-- The player's map lifted to its zone (a sub zone, a micro map: its parent), nil in an instance or
-- when the client tells nothing.
local function readZoneMap()
    if inInstance() then return nil end
    local api = rawget(_G, "C_Map")
    if type(api) ~= "table" then return nil end
    local map = tonumber(call(api.GetBestMapForUnit, "player"))
    for _ = 1, 10 do
        if not map or map <= 0 then return nil end
        local ok, info = pcall(api.GetMapInfo or error, map)
        if not ok or type(info) ~= "table" then return map end
        local kind = tonumber(ns.Plain(info.mapType)) or ZONE
        if kind <= ZONE then return map end
        map = tonumber(ns.Plain(info.parentMapID))
    end
    return nil
end

function LY.Map()
    if zoneMap == nil then zoneMap = readZoneMap() or false end
    return zoneMap or nil
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local function mapState(map)
    local m = maps[map]
    if not m then
        m = { layers = {}, cand = {} }
        maps[map] = m
    end
    return m
end

-- Drops what was not seen for LIFE seconds (once a minute at most unless forced).
local function sweep(force)
    local t = now()
    if not force and t - sweptAt < SWEEP_GAP then return end
    sweptAt = t
    local gone = false
    for map, m in pairs(maps) do
        for uid, e in pairs(m.layers) do
            if t - e.last > LY.LIFE then
                m.layers[uid] = nil
                gone = true
                if cur and cur.map == map and cur.uid == uid then cur = nil end
            end
        end
        for uid, c in pairs(m.cand) do
            for s, at in pairs(c) do
                if t - at > LY.CAND_WINDOW then c[s] = nil end
            end
            if next(c) == nil then m.cand[uid] = nil end
        end
        if next(m.layers) == nil and next(m.cand) == nil then maps[map] = nil end
    end
    if gone then ns.Fire("LAYER", "list") end
end

local function remember(e)
    history[#history + 1] = e
    if #history > MAX_HISTORY then table.remove(history, 1) end
end

local function grouped()
    local f = rawget(_G, "IsInGroup")
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f)
    return ok and ns.Plain(v) == true
end

local function setCurrent(map, uid, t, zuid)
    if cur and cur.map == map and cur.uid == uid then
        cur.at = t
        cur.zuid = zuid or cur.zuid
        return
    end
    cur = { map = map, uid = uid, zuid = zuid, at = t }
    remember({ at = t, map = map, uid = uid, grouped = grouped() })
    ns.Fire("LAYER", "current")
end

-- A creature of map with server part uid, spawn and zoneUID zuid (GUID guid) was read at t. The list: an id is
-- seen by the own client after two spawns within CAND_WINDOW (or once it is the current one). The current one:
-- the votes (see the head).
local function note(map, uid, spawn, t, zuid, guid)
    sweep()
    local m = mapState(map)
    local e = m.layers[uid]
    if not (e and e.own) then
        local c = m.cand[uid] or {}
        m.cand[uid] = c
        local room = true
        if not c[spawn] then
            local n = 0
            for s, at in pairs(c) do
                if t - at > LY.CAND_WINDOW then c[s] = nil else n = n + 1 end
            end
            room = n < MAX_CAND
        end
        if room then
            c[spawn] = t
            local n = 0
            for _ in pairs(c) do n = n + 1 end
            if n >= 2 then
                m.cand[uid] = nil
                if not e then
                    e = { first = t, last = t }
                    m.layers[uid] = e
                end
                e.own = true
                ns.Fire("LAYER", "list")
            end
        end
    end
    if e then
        e.last = math.max(e.last, t)
        e.zuid = zuid or e.zuid
    end
    local mine = cur and cur.map == map
    if mine and cur.uid == uid then
        cur.at = t
        cur.zuid = zuid or cur.zuid
    end
    if voted[guid] then return end
    voted[guid] = true
    votes[#votes + 1] = uid
    if #votes > LY.VOTES then table.remove(votes, 1) end
    if mine and cur.uid == uid then return end
    local n = 0
    for _, v in ipairs(votes) do if v == uid then n = n + 1 end end
    if n < (mine and 3 or 2) then return end
    if not e then
        e = { first = t, last = t, zuid = zuid }
        m.layers[uid] = e
    end
    m.cand[uid] = nil
    if not e.own then
        e.own = true
        ns.Fire("LAYER", "list")
    end
    setCurrent(map, uid, t, zuid)
end

-- One reading of unit (nothing checked but the unit itself): the server part, or nil.
local function readOne(unit, key, t)
    stats.read[key] = (stats.read[key] or 0) + 1
    local okG, guid = pcall(rawget(_G, "UnitGUID") or error, unit)
    if not okG then return nil end
    if guid ~= nil and ns.Plain(guid) == nil then stats.secret = stats.secret + 1 end
    local _, uid, _, spawn, zuid = LY.Parse(guid)
    if not uid then return nil end
    -- F-221: a creature of the layer just left, still in view
    if stale and t < stale.untilAt and stale.guid[guid] then return nil end
    -- anything a player controls (a guardian carries a creature GUID too)
    for _, name in ipairs({ "UnitPlayerControlled", "UnitIsOtherPlayersPet", "UnitIsPlayer" }) do
        local f = rawget(_G, name)
        if type(f) == "function" then
            local ok, v = pcall(f, unit)
            -- an error or a secret answer counts as controlled: nothing is read
            if not ok or (v ~= nil and ns.Plain(v) == nil) or v then return nil end
        end
    end
    local map = LY.Map()
    if not map then return nil end
    note(map, uid, spawn, t, zuid, guid)
    stats.ok[key] = (stats.ok[key] or 0) + 1
    if LY.onRead then
        local ok, err = pcall(LY.onRead, uid, map, guid, t)
        if not ok then ns.ReportError(err) end
    end
    return uid
end

-- Reads unit (target, mouseover, a name plate's unit); source "target", "mouseover" or "plate" (the
-- throttle). Returns the server part read (the layer), or nil.
function LY.ReadUnit(unit, source)
    local t = now()
    local gap = LY.GAP[source]
    if gap then
        if lastAt[source] and t - lastAt[source] < gap then return nil end
        lastAt[source] = t
    end
    if type(unit) ~= "string" or blocked() then return nil end
    return readOne(unit, source or "other", t)
end

-- F-221: reads the units in view now: the 40 name plates, the target, the mouseover (unthrottled). Returns how
-- many gave a layer.
function LY.Scan()
    if blocked() then return 0 end
    local t, n = now(), 0
    for i = 1, PLATES do
        if readOne("nameplate" .. i, "scan", t) then n = n + 1 end
    end
    if readOne("target", "scan", t) then n = n + 1 end
    if readOne("mouseover", "scan", t) then n = n + 1 end
    return n
end

-- The scan, but never within BORDER_QUIET seconds of a zone border. Returns whether it ran.
function LY.Rescan()
    if borderAt and now() - borderAt < LY.BORDER_QUIET then return false end
    LY.Scan()
    return true
end

local function rescanSoon()
    for _, s in ipairs(LY.RESCAN) do C_Timer.After(s, function() LY.Rescan() end) end
end

-- This session's reads and the current layer's changes, for the self-test (see the tables above).
function LY.Stats() return stats, history end

-- A layer of map the guild reported (an answer to "Gilde fragen") or a player of the zone named (zuid: the
-- zoneUID of its wire id, F-220): listed from now on (the votes still decide the current one, F-221); its
-- letter counts for everyone who knows the same ids.
function LY.Heard(map, uid, zuid)
    map, uid = tonumber(map), tonumber(uid)
    if not map or not uid or uid <= 0 or uid > MAX_ZONE_UID then return end
    local t = now()
    local m = mapState(map)
    local e = m.layers[uid]
    if not e then
        e = { first = t, last = t, heard = true, zuid = tonumber(zuid) }
        m.layers[uid] = e
        m.cand[uid] = nil
        ns.Fire("LAYER", "list")
    else
        e.heard = true
        e.last = math.max(e.last, t)
        e.zuid = e.zuid or tonumber(zuid)
    end
end

-- The wire id of layer uid on map ("6843-8"), nil while its zoneUID is unknown (D-145).
function LY.Wire(map, uid)
    local m = maps[tonumber(map) or 0]
    local e = m and m.layers[tonumber(uid) or 0]
    if cur and cur.map == tonumber(map) and cur.uid == tonumber(uid) and cur.zuid then return LY.WireText(cur.uid, cur.zuid) end
    return e and LY.WireText(uid, e.zuid) or nil
end

-- The wire id of the current layer, nil when unknown.
function LY.CurrentWire()
    local uid, map = LY.Current()
    if not uid then return nil end
    return LY.Wire(map, uid)
end

---------------------------------------------------------------------------
-- Reading the state
---------------------------------------------------------------------------
-- The ids of map in ascending order.
local function sortedIds(map)
    local m = maps[map]
    local ids = {}
    if not m then return ids end
    for uid in pairs(m.layers) do ids[#ids + 1] = uid end
    table.sort(ids)
    return ids
end

-- The letter of uid on map ("A" ...; past Z its number), nil when unknown there.
function LY.Letter(map, uid)
    for i, id in ipairs(sortedIds(map)) do
        if id == uid then return i <= #LETTERS and LETTERS:sub(i, i) or tostring(i) end
    end
    return nil
end

-- "Layer B", or "Layer ?" when unknown.
function LY.Name(map, uid)
    return L["Layer %s"]:format(LY.Letter(map, uid) or "?")
end

-- The current layer of the player's zone: uid, map, its name, seconds since a creature of it was
-- read; nil when unknown (another zone, an instance, nothing read yet).
function LY.Current()
    sweep()
    local map = LY.Map()
    if not cur or not map or cur.map ~= map then return nil end
    return cur.uid, cur.map, LY.Name(cur.map, cur.uid), now() - cur.at
end

-- Whether the current layer is known (F-221: until a zone change, a move or entering the world).
function LY.Known()
    return LY.Current() ~= nil
end

-- The layers of map (default the player's zone), by letter: { { uid, letter, name, first, last, age,
-- own, heard, current } }.
function LY.List(map)
    sweep()
    map = map or LY.Map()
    local out = {}
    if not map or not maps[map] then return out end
    local t = now()
    local m = maps[map]
    for i, uid in ipairs(sortedIds(map)) do
        local e = m.layers[uid]
        local letter = i <= #LETTERS and LETTERS:sub(i, i) or tostring(i)
        out[#out + 1] = { uid = uid, letter = letter, name = L["Layer %s"]:format(letter), first = e.first, last = e.last,
            age = t - e.last, own = e.own and true or false, heard = e.heard and true or false,
            current = cur ~= nil and cur.map == map and cur.uid == uid }
    end
    return out
end

-- Whether the own client read uid on map itself (not only heard of it).
function LY.Seen(map, uid)
    local m = maps[tonumber(map) or 0]
    local e = m and m.layers[tonumber(uid) or 0]
    return e ~= nil and e.own == true
end

-- An age as "gerade eben", "vor 3 Min.", "vor 2 Std.".
function LY.Age(secs)
    secs = math.max(0, tonumber(secs) or 0)
    if secs < 60 then return L["gerade eben"] end
    if secs < 7200 then return L["vor %d Min."]:format(math.floor(secs / 60)) end
    return L["vor %d Std."]:format(math.floor(secs / 3600))
end

-- The minimap tooltip's line, or nil outside the world.
function LY.TooltipLine()
    if inInstance() then return nil end
    local _, _, name = LY.Current()
    return L["Layer: %s"]:format(name or L["unbekannt"])
end

-- For /amisia selbsttest gruppe: whether the GUID of the target (else the mouseover) reads and splits.
-- Returns status ("OK", "WERT") and a text.
function LY.Probe()
    for _, unit in ipairs({ "target", "mouseover" }) do
        local ok, guid = pcall(rawget(_G, "UnitGUID") or error, unit)
        if ok and guid ~= nil then
            if ns.Plain(guid) == nil then return "WERT", L["%s: GUID geheim"]:format(unit) end
            local kind, uid, npc, _, zuid = LY.Parse(guid)
            if kind then
                return "OK", L["%s: %s, Server-Teil %d (der Layer), Zonen-Kennung %d, NPC %d, Zone %s"]:format(unit, kind, uid, zuid,
                    npc or 0, tostring(LY.Map() or "-"))
            end
            local head = type(guid) == "string" and guid:match("^(%a+)") or "?"
            return "WERT", L["%s: nicht zerlegbar (%s)"]:format(unit, head)
        end
    end
    return "WERT", L["kein Ziel: einen NPC in der Welt ins Ziel nehmen und neu prüfen"]
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.OnEvent("PLAYER_TARGET_CHANGED", function() LY.ReadUnit("target", "target") end)
ns.OnEvent("UPDATE_MOUSEOVER_UNIT", function() LY.ReadUnit("mouseover", "mouseover") end)
ns.OnEvent("NAME_PLATE_UNIT_ADDED", function(unit) LY.ReadUnit(unit, "plate") end)

-- A new zone or world: the zone map is read again and the current layer is unknown; the votes start anew.
local function zoneChanged()
    zoneMap = nil
    votes, voted = {}, {}
    if #history > 0 and not history[#history].zone then remember({ at = now(), zone = true }) end
    if cur then
        cur = nil
        ns.Fire("LAYER", "current")
    end
end
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function()
    borderAt = now()
    zoneChanged()
end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    zoneChanged()
    rescanSoon()
end)
-- inside a zone only the sub zone changes: its zone map stays, the cache is read again
ns.OnEvent("ZONE_CHANGED", function() zoneMap = nil end)
ns.OnEvent("ZONE_CHANGED_INDOORS", function() zoneMap = nil end)

---------------------------------------------------------------------------
-- The world restart (F-220): the game announces it, counts down, moves everyone
---------------------------------------------------------------------------
-- The seconds the client says are left, nil when it has no such function or says nothing.
local function evictionLeft()
    local f = rawget(_G, "GetEvictionTimeRemaining")
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f)
    v = ok and tonumber(ns.Plain(v)) or nil
    if not v or v <= 0 or v > 86400 then return nil end
    return v
end

local function readEviction()
    local left = evictionLeft()
    evictAt = left and now() + left or nil
    ns.Fire("LAYER", "refresh")
end

-- The world restart: seconds left (0 while "gleich", REFRESH_SOON seconds after the countdown ended), nil
-- when none is announced.
function LY.Refresh()
    if not evictAt then return nil end
    local left = evictAt - now()
    if left > 0 then return left end
    if left > -LY.REFRESH_SOON then return 0 end
    evictAt = nil
    return nil
end

-- "Neustart in 4:12", "Neustart gleich", nil.
function LY.RefreshText()
    local left = LY.Refresh()
    if not left then return nil end
    if left <= 0 then return L["Neustart gleich"] end
    local secs = math.ceil(left)
    return L["Neustart in %s"]:format(("%d:%02d"):format(math.floor(secs / 60), secs % 60))
end

ns.OnEvent("SHARD_TRANSFER_IMMINENT", readEviction)
ns.OnEvent("SHARD_TRANSFER_CANCELLED", readEviction)
-- the move itself: the layer is unknown until a creature is read again (Gear/LayerChange.lua counts it as
-- the change of an own swap)
ns.OnEvent("SHARD_TRANSFER", function()
    evictAt = nil
    -- F-221: the creatures in view (and every one that voted) are the old layer's for STALE_FOR seconds
    local guids = {}
    for g in pairs(voted) do guids[g] = true end
    local get = rawget(_G, "UnitGUID")
    local function add(unit)
        local ok, g = pcall(get or error, unit)
        g = ok and ns.Plain(g) or nil
        if type(g) == "string" then guids[g] = true end
    end
    for i = 1, PLATES do add("nameplate" .. i) end
    add("target")
    add("mouseover")
    stale = { untilAt = now() + LY.STALE_FOR, guid = guids }
    votes, voted = {}, {}
    rescanSoon()
    if cur then
        cur = nil
        ns.Fire("LAYER", "current")
    end
    ns.Fire("LAYER", "transfer")
end)

---------------------------------------------------------------------------
-- The layers seen, through /reload (F-221): AmisiaDB.layerSeen = { [map] = { [uid] = { f, l, z, o, h } } }
-- (epochs of the first and last sighting, the zoneUID, own and heard as 1), SEEN_KEEP seconds
---------------------------------------------------------------------------
-- The saved list kept clean (on load): numbers only, recent, SEEN_MAPS zones and SEEN_LAYERS layers at most.
function LY.LoadedSeen(DB)
    local db = DB and DB.layerSeen
    if db == nil then return end
    if type(db) ~= "table" then DB.layerSeen = nil return end
    local cut, maps_ = time() - LY.SEEN_KEEP, 0
    for map, list in pairs(db) do
        local keep = type(map) == "number" and map > 0 and map <= 999999 and type(list) == "table" and maps_ < SEEN_MAPS
        local n = 0
        if keep then
            for uid, e in pairs(list) do
                if type(uid) ~= "number" or uid <= 0 or uid > MAX_ZONE_UID or type(e) ~= "table" or type(e.l) ~= "number"
                    or e.l < cut or e.l > time() + 60 or n >= SEEN_LAYERS then
                    list[uid] = nil
                else
                    n = n + 1
                    e.f = type(e.f) == "number" and math.min(e.f, e.l) or e.l
                    e.z = type(e.z) == "number" and e.z > 0 and e.z <= MAX_ZONE_UID and e.z or nil
                    e.o = e.o == 1 and 1 or nil
                    e.h = e.h == 1 and 1 or nil
                end
            end
        end
        if not keep or n == 0 then db[map] = nil else maps_ = maps_ + 1 end
    end
end

-- The saved list into the memory (once, while nothing was read).
local function restoreSeen(DB)
    local db = DB and DB.layerSeen
    if type(db) ~= "table" or next(maps) ~= nil then return end
    local t, epoch = now(), time()
    for map, list in pairs(db) do
        local m = mapState(map)
        for uid, e in pairs(list) do
            m.layers[uid] = { first = t - (epoch - e.f), last = t - (epoch - e.l), zuid = e.z, own = e.o == 1 or nil,
                heard = e.h == 1 or nil }
        end
    end
end

-- The memory into the saved list (at PLAYER_LOGOUT, also before a /reload).
function LY.SaveSeen()
    if type(AmisiaDB) ~= "table" then return end
    local t, epoch = now(), time()
    local out, n = {}, 0
    for map, m in pairs(maps) do
        local list, k = {}, 0
        for uid, e in pairs(m.layers) do
            if t - e.last <= LY.SEEN_KEEP and k < SEEN_LAYERS then
                k = k + 1
                list[uid] = { f = math.floor(epoch - (t - e.first)), l = math.floor(epoch - (t - e.last)), z = e.zuid,
                    o = e.own and 1 or nil, h = e.heard and 1 or nil }
            end
        end
        if k > 0 and n < SEEN_MAPS then
            n = n + 1
            out[map] = list
        end
    end
    AmisiaDB.layerSeen = n > 0 and out or nil
end
ns.OnEvent("PLAYER_LOGOUT", function() LY.SaveSeen() end)

local function loadSeen()
    if type(AmisiaDB) ~= "table" then return end
    LY.LoadedSeen(AmisiaDB)
    restoreSeen(AmisiaDB)
end
loadSeen()
ns.OnEvent("ADDON_LOADED", function(name) if name == ns.ADDON then loadSeen() end end)
LY._loadSeen = loadSeen   -- for the tests: a /reload

ns.RegisterSettings{ key = "layer", label = L["Layer"], order = 62, group = "guild", forever = true, items = {
    { key = "layer.chip", type = "toggle", label = L["Layer-Chip zeigen"], default = false,
      tip = L["Ein kleiner Kasten mit deinem Layer (\"Layer B\") bleibt auf dem Bildschirm; ziehen verschiebt ihn, ein Klick öffnet das Fenster Layer. Nicht in Instanzen."] },
    { key = "layer.answer", type = "toggle", label = L["Layer-Anfragen der Gilde beantworten"], default = true,
      tip = L["Fragt ein Gildenmitglied mit Amisia nach einem anderen Layer und bist du in derselben Zone auf einem anderen, sagt dein Amisia ihm leise deinen Layer. Nichts geht in den Chat."] },
    { key = "layer.chat", type = "toggle", label = L["Auch auf Chat-Anfragen aus der Gilde reagieren"], default = true,
      tip = L["Schreibt ein Gildenmitglied eine kurze Bitte wie \"inv layer\" in den Gildenchat oder flüstert sie dir (so fragen andere Layer-Addons), behandelt Amisia sie wie eine Bitte aus Amisia: dieselbe Frage oder Einladung, dieselben Grenzen. Nur wenn die Gildenliste dieselbe Zone nennt, lädt Amisia ohne Frage ein. Öffentliche Kanäle liest Amisia nur mit \"Auch Spielern außerhalb der Gilde helfen\"."] },
    { key = "layer.others", type = "toggle", label = L["Auch Spielern außerhalb der Gilde helfen"], default = false,
      tip = L["Flüstert dir irgendein Spieler eine kurze Bitte wie \"inv layer\" oder schreibt sie in einen Kanal, in dem du bist (so fragen Spieler mit und ohne Layer-Addon), fragt Amisia dich, ob du ihn einladen willst. Dieselben Grenzen wie in der Gilde: nie in Instanzen, höchstens sechs Einladungen in zehn Minuten, höchstens eine Frage alle fünf Sekunden."] },
    { key = "layer.othersAuto", type = "toggle", label = L["Fremde ohne Frage einladen"], default = false,
      tip = L["Mit \"Auch Spielern außerhalb der Gilde helfen\": bittet ein Fremder im Kanal deiner Zone (Allgemein), lädt Amisia ihn sofort ein. Bitten per Flüstern und in anderen Kanälen fragen dich weiter, weil die Zone des Spielers unbekannt ist."] },
    { key = "layer.chatText", type = "text", label = L["Text für \"Im Gildenchat fragen\""], default = "inv layer",
      validate = function(v) return ns.LayerChange and ns.LayerChange.ChatText(v) or nil end,
      invalid = L["Eine Zeile, höchstens 40 Zeichen."],
      tip = L["Diese Zeile öffnen \"Im Gildenchat fragen\" und \"Im Kanal fragen\" im Chat, du schickst sie mit Enter ab. Stell sie auf das, worauf die Layer-Addons der anderen hören."] },
    { key = "layer.channel", type = "slider", label = L["Kanal für \"Im Kanal fragen\""], default = 1, min = 1, max = 10,
      tip = L["Die Nummer des Chatkanals, in den \"Im Kanal fragen\" deine Bitte schreibt. 1 ist meist Allgemein, der Kanal deiner Zone."] },
    { key = "layer.autoInvite", type = "toggle", label = L["Ohne Frage einladen"], default = true,
      tip = L["Bittet dich ein Spieler mit Amisia, den du beantwortet hast (aus der Gilde oder der Zone), um eine Einladung auf deinen Layer, lädt Amisia ihn sofort ein. Aus: Amisia fragt dich erst. Nie in Instanzen, höchstens sechs Einladungen in zehn Minuten."] },
    { key = "layer.autoAccept", type = "toggle", label = L["Einladung des Gefragten annehmen"], default = true,
      tip = L["Hast du ein Gildenmitglied um eine Einladung auf seinen Layer gebeten, nimmt Amisia genau seine Einladung an (eine Minute lang); nach \"Im Gildenchat fragen\" die Einladung eines Gildenmitglieds, nach \"Im Kanal fragen\" die nächste Einladung, egal von wem. Jede andere Einladung fragt das Spiel wie immer."] },
    { key = "layer.autoLeave", type = "toggle", label = L["Gruppe nach dem Wechsel verlassen"], default = true,
      tip = L["Ist der Wechsel gelungen, verlässt Amisia die Gruppe des Helfers nach den eingestellten Sekunden, wenn er auf deine Frage geantwortet hat; hat er dich nicht bewegt, frühestens nach 15 Sekunden. Nie eine Gruppe, in der du vorher warst, und keinen Schlachtzug."] },
    { key = "layer.leaveSeconds", type = "slider", label = L["Verlassen nach Sekunden"], default = 4, min = 3, max = 120,
      tip = L["So lange nach dem gelungenen Wechsel wartet Amisia, bevor es die Zweiergruppe verlässt."] },
    { key = "layer.onlyNew", type = "toggle", label = L["Nur neue Layer"], default = false,
      tip = L["\"Layer wechseln\" nimmt nur Antworten von Layern, die in der letzten Stunde in dieser Zone niemand gesehen hat."] },
    { key = "layer.combatPause", type = "toggle", label = L["Helfen im Kampf pausieren"], default = false,
      tip = L["Im Kampf beantwortet Amisia keine Layer-Fragen und lädt niemanden ein; danach geht es weiter."] },
    -- F-220 (D-145)
    { key = "layer.foreign", type = "toggle", label = L["Mit dem anderen Layer-Addon zusammenarbeiten"], default = true,
      tip = L["\"Layer wechseln\" fragt die Spieler der Zone auch so, wie das meistgenutzte Layer-Addon fragt, und Helfen antwortet und lädt dessen Nutzer ein. Aus: nur Amisias eigene Fragen. Ist das andere Addon selbst geladen, überlässt Amisia ihm diesen Teil."] },
    { key = "layer.guildLast", type = "toggle", label = L["Gilde zuletzt fragen"], default = true,
      tip = L["Gildenmitglieder aus der Wer-Liste fragt \"Layer wechseln\" auf die Art des anderen Layer-Addons erst nach den anderen Spielern, wenn bis dahin niemand eingeladen hat und kein Helfer von einem anderen Layer geantwortet hat; stehen nur Gildenmitglieder in der Liste, sofort. Aus: Gildenmitglieder bekommen diese Frage gar nicht. Amisia-Nutzer der Gilde fragt Amisia immer gleich."] },
    { key = "layer.skipNear", type = "toggle", label = L["Fragende in der Nähe überspringen"], default = false,
      tip = L["Helfen lädt niemanden ein, der näher als die eingestellten Meter bei dir steht (er wäre wohl auf deinem Layer). Nennt eine Bitte keine Position, lädt Amisia dann nicht ein."] },
    { key = "layer.skipNearYards", type = "slider", label = L["Nähe in Metern"], default = 150, min = 50, max = 200, step = 10,
      tip = L["So nah muss ein Fragender stehen, damit \"Fragende in der Nähe überspringen\" ihn auslässt."] },
    -- F-221: the bar of its own, from the start
    { key = "layer.bar", type = "toggle", label = L["Leiste zeigen"], default = true,
      tip = L["Eine kleine Leiste mit deinem Layer und darunter dem Stand (Helfen, Frage, Neustart) bleibt auf dem Bildschirm, auch ohne das Fenster. Klick: das Fenster Layer. Rechtsklick auf das Symbol: die Layer der Zone. Rechtsklick sonst: ausblenden."] },
    { key = "layer.barOneLine", type = "toggle", label = L["Leiste in einer Zeile"], default = false,
      tip = L["Die Leiste Layer zeigt Layer und Stand nebeneinander, flacher."] },
    { key = "layer.barShade", type = "slider", label = L["Leiste abdunkeln (Prozent)"], default = 55, min = 0, max = 100, step = 5,
      tip = L["Wie dunkel der Hintergrund der Leiste Layer ist; 0 ist durchsichtig."] },
}}

-- for the tests
function LY._reset()
    maps, cur, zoneMap, lastAt, sweptAt, evictAt = {}, nil, nil, {}, 0, nil
    votes, voted, stale, borderAt = {}, {}, nil, nil
    stats, history = { read = {}, ok = {}, secret = 0 }, {}
end
end)
