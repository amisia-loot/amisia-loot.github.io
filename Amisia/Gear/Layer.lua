-- The world layer (F-185, D-117, spec docs/specs/2026-11-12-layer.md, ns.Layer): a zone exists several
-- times; a creature's GUID ("Creature-0-<server>-<instance>-<zoneUID>-<npc>-<spawn>", also "Vehicle-")
-- tells by its zoneUID which copy the player stands in. Read from the target, the mouseover and the
-- name plates (PLAYER_TARGET_CHANGED, UPDATE_MOUSEOVER_UNIT 0.25 s apart, NAME_PLATE_UNIT_ADDED 0.1 s
-- apart; a few string operations per event, nothing per frame), never in an instance, a boss fight or
-- the chat lockdown, never from anything a player controls (UnitPlayerControlled, UnitIsOtherPlayersPet,
-- UnitIsPlayer), a secret value skipped. Per zone map (the player's map lifted to its zone, as the map
-- page does it): a zoneUID becomes the current layer once it was seen on two different creatures
-- (spawn) within CAND_WINDOW, or on one when it is already known for the map (an own one or one the
-- guild reported, Gear/LayerChange.lua): a creature over the zone border carries its neighbour's id. A
-- zone change and entering or leaving an instance make the layer unknown until creatures are read
-- again. Kept in memory only (a server restart hands out new ids); entries not seen for LIFE seconds
-- fall out. Names "Layer A", "Layer B" ...: the known ids of a map in ascending order, so guild members
-- who know the same ids say the same letter (a letter can shift when a lower id becomes known).
-- Fires LAYER ("current" when the current layer changes, "list" when a map's list does). Sends nothing.
-- Other layer addons run beside it untouched: no prefix, no hidden message, no frame of theirs; their plain
-- chat convention ("inv layer") is understood by Gear/LayerChange.lua (D-117).
local ADDON, ns = ...
local L = ns.L

local LY = {}
ns.Layer = LY

LY.CAND_WINDOW = 120    -- seconds in which two creatures of a new id must be seen
LY.LIFE = 6 * 3600      -- seconds an id lives without being seen again
LY.FRESH = 300          -- seconds a current layer counts as fresh (the guild answers only then)
LY.GAP = { mouseover = 0.25, plate = 0.1 }   -- throttle per source
local MAX_ZONE_UID = 4294967295
local MAX_CAND = 20     -- candidate spawns kept per id
local SWEEP_GAP = 60
local ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local maps = {}         -- [map] = { layers = { [uid] = { first, last, own, heard } }, cand = { [uid] = { [spawn] = t } } }
local cur               -- { map, uid, at = the last time a creature of uid was read }
local zoneMap           -- the player's zone map (cached until a zone event), false: none
local lastAt = {}       -- source -> time of its last read
local sweptAt = 0

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
-- A creature's GUID split: kind ("Creature" or "Vehicle"), zoneUID (a number above 0), npc id, spawn
-- (its hex text); nil for anything else (players, pets, objects, a secret or broken value).
function LY.Parse(guid)
    guid = ns.Plain(guid)
    if type(guid) ~= "string" or #guid > 80 then return nil end
    local kind, zone, npc, spawn = guid:match("^(%a+)%-%d+%-%d+%-%d+%-(%d+)%-(%d+)%-(%x+)$")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    zone = tonumber(zone)
    if not zone or zone <= 0 or zone > MAX_ZONE_UID then return nil end
    return kind, zone, tonumber(npc), spawn
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

local function setCurrent(map, uid, t)
    if cur and cur.map == map and cur.uid == uid then
        cur.at = t
        return
    end
    cur = { map = map, uid = uid, at = t }
    ns.Fire("LAYER", "current")
end

-- A creature of map with zoneUID uid and spawn was read at t.
local function note(map, uid, spawn, t)
    sweep()
    local m = mapState(map)
    local e = m.layers[uid]
    if not e then
        local c = m.cand[uid] or {}
        m.cand[uid] = c
        if not c[spawn] then
            local n = 0
            for s, at in pairs(c) do
                if t - at > LY.CAND_WINDOW then c[s] = nil else n = n + 1 end
            end
            if n >= MAX_CAND then return end
        end
        c[spawn] = t
        local n = 0
        for _ in pairs(c) do n = n + 1 end
        if n < 2 then return end
        m.cand[uid] = nil
        e = { first = t, last = t, own = true }
        m.layers[uid] = e
        ns.Fire("LAYER", "list")
    end
    e.last = math.max(e.last, t)
    if not e.own then
        e.own = true
        ns.Fire("LAYER", "list")
    end
    setCurrent(map, uid, t)
end

-- Reads unit (target, mouseover, a name plate's unit); source "target", "mouseover" or "plate" (the
-- throttle). Returns the zoneUID read, or nil.
function LY.ReadUnit(unit, source)
    local t = now()
    local gap = LY.GAP[source]
    if gap then
        if lastAt[source] and t - lastAt[source] < gap then return nil end
        lastAt[source] = t
    end
    if type(unit) ~= "string" or blocked() then return nil end
    local guid = call(rawget(_G, "UnitGUID"), unit)
    local _, uid, _, spawn = LY.Parse(guid)
    if not uid then return nil end
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
    note(map, uid, spawn, t)
    return uid
end

-- A layer of map the guild reported (an answer to "Gilde fragen"): known from now on, so one own
-- creature makes it current; its letter counts for everyone who knows the same ids.
function LY.Heard(map, uid)
    map, uid = tonumber(map), tonumber(uid)
    if not map or not uid or uid <= 0 or uid > MAX_ZONE_UID then return end
    local t = now()
    local m = mapState(map)
    local e = m.layers[uid]
    if not e then
        e = { first = t, last = t, heard = true }
        m.layers[uid] = e
        m.cand[uid] = nil
        ns.Fire("LAYER", "list")
    else
        e.heard = true
        e.last = math.max(e.last, t)
    end
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

-- Whether the current layer was read within limit seconds (default FRESH).
function LY.Fresh(limit)
    local uid, _, _, age = LY.Current()
    return uid ~= nil and age <= (limit or LY.FRESH)
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
            local kind, uid, npc = LY.Parse(guid)
            if kind then
                return "OK", L["%s: %s, Zonen-Kennung %d, NPC %d, Zone %s"]:format(unit, kind, uid, npc or 0, tostring(LY.Map() or "-"))
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

-- A new zone or world: the zone map is read again and the current layer is unknown.
local function zoneChanged()
    zoneMap = nil
    if cur then
        cur = nil
        ns.Fire("LAYER", "current")
    end
end
ns.OnEvent("ZONE_CHANGED_NEW_AREA", zoneChanged)
ns.OnEvent("PLAYER_ENTERING_WORLD", zoneChanged)
-- inside a zone only the sub zone changes: its zone map stays, the cache is read again
ns.OnEvent("ZONE_CHANGED", function() zoneMap = nil end)
ns.OnEvent("ZONE_CHANGED_INDOORS", function() zoneMap = nil end)

ns.RegisterSettings{ key = "layer", label = L["Layer"], order = 62, group = "guild", forever = true, items = {
    { key = "layer.chip", type = "toggle", label = L["Layer-Chip zeigen"], default = false,
      tip = L["Ein kleiner Kasten mit deinem Layer (\"Layer B\") bleibt auf dem Bildschirm; ziehen verschiebt ihn, ein Klick öffnet das Fenster Layer. Nicht in Instanzen."] },
    { key = "layer.answer", type = "toggle", label = L["Layer-Anfragen der Gilde beantworten"], default = true,
      tip = L["Fragt ein Gildenmitglied mit Amisia nach einem anderen Layer und bist du in derselben Zone auf einem anderen, sagt dein Amisia ihm leise deinen Layer. Nichts geht in den Chat."] },
    { key = "layer.chat", type = "toggle", label = L["Auch auf Chat-Anfragen aus der Gilde reagieren"], default = true,
      tip = L["Schreibt ein Gildenmitglied eine kurze Bitte wie \"inv layer\" in den Gildenchat oder flüstert sie dir (so fragen andere Layer-Addons), behandelt Amisia sie wie eine Bitte aus Amisia: dieselbe Frage oder Einladung, dieselben Grenzen. Nur wenn die Gildenliste dieselbe Zone nennt, lädt Amisia ohne Frage ein. Öffentliche Kanäle liest Amisia nie."] },
    { key = "layer.chatText", type = "text", label = L["Text für \"Im Gildenchat fragen\""], default = "inv layer",
      validate = function(v) return ns.LayerChange and ns.LayerChange.ChatText(v) or nil end,
      invalid = L["Eine Zeile, höchstens 40 Zeichen."],
      tip = L["Diese Zeile öffnet \"Im Gildenchat fragen\" im Chat, du schickst sie mit Enter ab. Stell sie auf das, worauf die Layer-Addons deiner Gilde hören."] },
    { key = "layer.autoInvite", type = "toggle", label = L["Ohne Frage einladen"], default = false,
      tip = L["Bittet dich ein Gildenmitglied, das du beantwortet hast, um eine Einladung auf deinen Layer, lädt Amisia es sofort ein. Aus: Amisia fragt dich erst. Nie in Instanzen, höchstens sechs Einladungen in zehn Minuten."] },
    { key = "layer.autoAccept", type = "toggle", label = L["Einladung des Gefragten annehmen"], default = true,
      tip = L["Hast du ein Gildenmitglied um eine Einladung auf seinen Layer gebeten, nimmt Amisia genau seine Einladung an (eine Minute lang); nach \"Im Gildenchat fragen\" die Einladung eines Gildenmitglieds. Jede andere Einladung fragt das Spiel wie immer."] },
    { key = "layer.autoLeave", type = "toggle", label = L["Gruppe nach dem Wechsel verlassen"], default = false,
      tip = L["Ist der Wechsel gelungen, verlässt Amisia die Zweiergruppe mit dem Einladenden nach den eingestellten Sekunden. Nie eine Gruppe, in der du vorher warst oder in der mehr sind."] },
    { key = "layer.leaveSeconds", type = "slider", label = L["Verlassen nach Sekunden"], default = 30, min = 5, max = 120,
      tip = L["So lange nach dem gelungenen Wechsel wartet Amisia, bevor es die Zweiergruppe verlässt."] },
}}

-- for the tests
function LY._reset()
    maps, cur, zoneMap, lastAt, sweptAt = {}, nil, nil, {}, 0
end
