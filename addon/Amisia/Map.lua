-- Amisia map: where the sources of an item stand (quest givers, vendors, quartermasters, rare and
-- named mobs, raid and dungeon entrances), from the generated MapData.lua / MapDataTBC.lua, and one
-- target at a time. On a client with the user waypoint (Forever) the target becomes the client's
-- waypoint with its guide arrow; elsewhere Amisia shows it itself. Only fixed places from the data
-- are shown; nothing here reads other units or works inside instances.
local ADDON, ns = ...
local Gear = ns.Gear

local Map = {}
ns.Map = Map

local ARRIVE = 15          -- yards: closer than this counts as arrived
local SAME = 0.001         -- a waypoint within this (map fraction) is the one Amisia set

---------------------------------------------------------------------------
-- Saved state and its move
---------------------------------------------------------------------------

local function inRange(v) return type(v) == "number" and v >= 0 and v <= 1 end

-- Called on ADDON_LOADED (and whenever the table is missing): AmisiaDB.map with v, a checked target
-- and the hidden places (string keys set to true only). Running it twice changes nothing.
function ns.MapMigrate(root)
    local m = type(root.map) == "table" and root.map or {}
    root.map = m
    m.v = 1
    local t = m.target
    if t ~= nil and not (type(t) == "table" and type(t.map) == "number" and t.map > 0 and inRange(t.x) and inRange(t.y)) then
        m.target = nil
    end
    local hidden = type(m.hidden) == "table" and m.hidden or {}
    local drop = {}
    for k, v in pairs(hidden) do
        if type(k) ~= "string" or v ~= true then drop[#drop + 1] = k end
    end
    for _, k in ipairs(drop) do hidden[k] = nil end
    m.hidden = hidden
    if m.arrowBefore ~= nil and m.arrowBefore ~= "auto" and m.arrowBefore ~= "on" then m.arrowBefore = nil end
    return m
end

local function db()
    if not AmisiaDB then return nil end
    local m = AmisiaDB.map
    if type(m) ~= "table" or type(m.hidden) ~= "table" then m = ns.MapMigrate(AmisiaDB) end
    return m
end

---------------------------------------------------------------------------
-- Keys and points
---------------------------------------------------------------------------

local function posNum(v) return type(v) == "number" and v > 0 end

-- The stable key of a source record (tools/build_map.py's key_of does the same): Q:<quest id>,
-- U:<NPC id> where the record carries one, else V:/R:/W:<name>, I:<instance id> or N:<dungeon> for
-- raids, dungeons and dungeon trash, F:<faction id>; nil for sources without a place.
function ns.MapKeyOf(rec)
    if type(rec) ~= "table" then return nil end
    local k = rec[1]
    if k == "Q" then
        return posNum(rec[7]) and ("Q:" .. rec[7]) or nil
    elseif k == "V" or k == "P" then
        if posNum(rec[7]) then return "U:" .. rec[7] end
        return type(rec[2]) == "string" and ("V:" .. rec[2]) or nil
    elseif k == "R" then
        if posNum(rec[5]) then return "U:" .. rec[5] end
        return type(rec[2]) == "string" and ("R:" .. rec[2]) or nil
    elseif k == "W" then
        local name = rec[2]
        if type(name) ~= "string" then return nil end
        local dungeon = name:match("^Trash %((.+)%)$")
        if dungeon then return "N:" .. dungeon end
        if posNum(rec[6]) then return "U:" .. rec[6] end
        return (type(rec[5]) == "number" and rec[5] ~= 0) and ("W:" .. name) or nil
    elseif k == "X" or k == "D" then
        local place = Gear.PlaceOf(rec)
        return place and (place:gsub("/H$", "")) or nil
    elseif k == "F" then
        return posNum(rec[4]) and ("F:" .. rec[4]) or nil
    end
    return nil
end

local parsed = {}        -- key -> list of points, parsed once
local unknownMaps = {}   -- uiMapIDs the client does not know, noted once per session

local function knownMap(id)
    if unknownMaps[id] then return false end
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, id)
        if not (ok and info) then
            unknownMaps[id] = true
            return false
        end
    end
    return true
end

-- The points of a key: { { map = uiMapID, x = 0-1, y = 0-1 }, ... }; broken parts and maps the client
-- does not know are skipped. Empty when the key has no place.
function ns.MapPoints(key)
    local list = parsed[key]
    if list then return list end
    list = {}
    local text = ns.MAP and ns.MAP.P and ns.MAP.P[key]
    if type(text) == "string" then
        for part in text:gmatch("%S+") do
            local m, x, y = part:match("^(%d+):(%d+):(%d+)$")
            m, x, y = tonumber(m), tonumber(x), tonumber(y)
            if m and x and y and m > 0 and x <= 10000 and y <= 10000 and knownMap(m) then
                list[#list + 1] = { map = m, x = x / 10000, y = y / 10000 }
            end
        end
    end
    parsed[key] = list
    return list
end
Map.Points = ns.MapPoints

-- uiMapIDs of the data the client did not know this session.
function Map.UnknownMaps() return unknownMaps end

-- Who stands at a key (quest giver, quartermaster), English, or nil.
function Map.Giver(key)
    return ns.MAP and ns.MAP.G and ns.MAP.G[key] or nil
end

-- Test hook: forget the parsed points (after the data changed).
function Map._reset()
    parsed, unknownMaps = {}, {}
end

---------------------------------------------------------------------------
-- The places of an item
---------------------------------------------------------------------------

local function isWish(id)
    local c = ns.BisChar and ns.BisChar()
    return c and type(c.wish) == "table" and c.wish[id] ~= nil or false
end

local function placesOf(list)
    local out, seen = {}, {}
    for _, rec in ipairs(list) do
        local key = ns.MapKeyOf(rec)
        if key and not seen[key] then
            seen[key] = true
            local points = ns.MapPoints(key)
            if #points > 0 then
                out[#out + 1] = { key = key, rec = rec, points = points, giver = Map.Giver(key) }
            end
        end
    end
    return out
end

-- The sources of an item that have a place: { { key, rec, points, giver }, ... } in the order of
-- Gear.Sources, one entry per key. Without opts the gear page's own filters (ns.BisOpts); a wish
-- whose sources the filters all leave out takes every source.
function ns.MapItemPlaces(id, opts)
    id = tonumber(id)
    if not id or not ns.MAP or not Gear.Available() or not Gear.Item(id) then return {} end
    if opts then return placesOf(Gear.Sources(id, opts)) end
    local out = placesOf(Gear.Sources(id, ns.BisOpts()))
    if #out == 0 and isWish(id) then out = placesOf(Gear.Sources(id)) end
    return out
end

---------------------------------------------------------------------------
-- Where the player is
---------------------------------------------------------------------------

local function inInstance()
    if not IsInInstance then return false end
    local inside = ns.Plain(IsInInstance())
    return inside and true or false
end

local function worldOf(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if not ok or not pos then return nil end
    cont = ns.Plain(cont)
    local wx, wy = ns.Plain(pos.x), ns.Plain(pos.y)
    if type(cont) ~= "number" or type(wx) ~= "number" or type(wy) ~= "number" then return nil end
    return cont, wx, wy
end

-- The player's place: uiMapID, x, y (0-1) and the world position (continent, x, y in yards); nil
-- inside an instance or when the client tells nothing (secret values count as unknown).
function Map.PlayerPosition()
    if inInstance() or not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = ns.Plain(C_Map.GetBestMapForUnit("player"))
    if type(map) ~= "number" then return nil end
    local x, y
    if C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(map, "player")
        if pos then x, y = ns.Plain(pos.x), ns.Plain(pos.y) end
    end
    if type(x) == "number" and type(y) == "number" then
        local cont, wx, wy = worldOf(map, x, y)
        return { map = map, x = x, y = y, cont = cont, wx = wx, wy = wy }
    end
    -- the client's world position as a fallback for the distance (UnitPosition: y, x, z, instance)
    if UnitPosition then
        local wy, wx, _, cont = UnitPosition("player")
        wy, wx, cont = ns.Plain(wy), ns.Plain(wx), ns.Plain(cont)
        if type(wx) == "number" and type(wy) == "number" and type(cont) == "number" then
            return { map = map, cont = cont, wx = wx, wy = wy }
        end
    end
    return nil
end

-- Yards from the player to a point, or nil (other continent, no position). me: Map.PlayerPosition().
function Map.Distance(point, me)
    me = me or Map.PlayerPosition()
    if not me or not me.wx or not point then return nil end
    local cont, wx, wy = worldOf(point.map, point.x, point.y)
    if not cont or cont ~= me.cont then return nil end
    return math.sqrt((wx - me.wx) ^ 2 + (wy - me.wy) ^ 2)
end

-- The point nearest to the player (same continent) and its distance in yards; without a position
-- or on another continent the first point and nil.
function ns.MapNearest(points)
    if type(points) ~= "table" or #points == 0 then return nil end
    local me = Map.PlayerPosition()
    local best, bestD
    if me then
        for _, p in ipairs(points) do
            local d = Map.Distance(p, me)
            if d and (not bestD or d < bestD) then best, bestD = p, d end
        end
    end
    if best then return best, bestD end
    return points[1], nil
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

local function isEntrance(key) return type(key) == "string" and (key:sub(1, 2) == "I:" or key:sub(1, 2) == "N:") end

-- The name a place shows: the quest giver or quest, the vendor or mob, the quartermaster, the raid
-- or dungeon (client name by area id).
local function placeName(place)
    local rec, key = place.rec, place.key
    if isEntrance(key) then
        if rec and (rec[1] == "X" or rec[1] == "D") then return Gear.PlaceName(rec) or key:sub(3) end
        return key:sub(3)
    end
    if place.giver then return place.giver end
    if rec and type(rec[2]) == "string" then return rec[2] end
    return key
end

local function zoneName(map)
    return Gear.ZoneName(map) or ("Zone " .. tostring(map))
end

-- "47, 33"
function Map.Coords(point)
    return ("%d, %d"):format(math.floor(point.x * 100 + 0.5), math.floor(point.y * 100 + 0.5))
end

-- "Gorn One Eye, Durotar 47, 33" or "Karazhan (Eingang Gebirgspass der Totenwinde 47, 70)".
local function whereText(name, point, entrance)
    if entrance then return ("%s (Eingang %s %s)"):format(name, zoneName(point.map), Map.Coords(point)) end
    return ("%s, %s %s"):format(name, zoneName(point.map), Map.Coords(point))
end

-- The short label of a target.
local function labelOf(place)
    local name = placeName(place)
    if isEntrance(place.key) then return name .. " (Eingang)" end
    return name
end

---------------------------------------------------------------------------
-- The client's user waypoint (Forever)
---------------------------------------------------------------------------

-- Whether the client has the user waypoint with its guide arrow; decided at run time.
function Map.ClientWaypoints()
    return C_Map ~= nil and type(C_Map.SetUserWaypoint) == "function" and type(C_Map.ClearUserWaypoint) == "function"
        and type(C_Map.GetUserWaypoint) == "function" and type(UiMapPoint) == "table"
        and type(UiMapPoint.CreateFromCoordinates) == "function" and type(C_SuperTrack) == "table"
        and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function"
end

local busy = false   -- Amisia is setting or clearing the waypoint itself

-- Where the client's waypoint stands on a map: x, y, or nil when there is none or it is elsewhere.
local function waypointOn(map)
    if not Map.ClientWaypoints() then return nil end
    if C_Map.GetUserWaypointPositionForMap then
        local ok, pos = pcall(C_Map.GetUserWaypointPositionForMap, map)
        if ok and pos then
            local x, y = ns.Plain(pos.x), ns.Plain(pos.y)
            if type(x) == "number" and type(y) == "number" then return x, y end
        end
    end
    -- without a position for this map: the waypoint itself, when it was set on this map
    local ok, point = pcall(C_Map.GetUserWaypoint)
    if not ok or type(point) ~= "table" or not point.position then return nil end
    if ns.Plain(point.uiMapID) ~= map then return nil end
    local x, y = ns.Plain(point.position.x), ns.Plain(point.position.y)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y
end

local function hasWaypoint()
    if not Map.ClientWaypoints() then return false end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    return ok and point ~= nil
end

-- Whether the client's waypoint stands where the target is.
local function waypointAt(t)
    local x, y = waypointOn(t.map)
    return x ~= nil and math.abs(x - t.x) <= SAME and math.abs(y - t.y) <= SAME
end

local function setWaypoint(map, x, y)
    if not Map.ClientWaypoints() then return false end
    if C_Map.CanSetUserWaypointOnMap then
        local ok, can = pcall(C_Map.CanSetUserWaypointOnMap, map)
        if not ok or not can then return false end
    end
    busy = true
    local ok, set = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(map, x, y))
    if ok and set then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
    busy = false
    return ok and set and true or false
end

local function clearWaypoint()
    busy = true
    pcall(C_Map.ClearUserWaypoint)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, false) end
    busy = false
end

-- Removes the client's waypoint only when Amisia set it and it still stands there.
local function clearOwn(t)
    if t and t.ours and Map.ClientWaypoints() and waypointAt(t) then clearWaypoint() end
end

---------------------------------------------------------------------------
-- The target
---------------------------------------------------------------------------

local NO_DATA = "Keine Kartendaten für diesen Client."
local NO_PLACE = "Für dieses Item kennt Amisia keinen Ort."
local NO_ZONE = "Diese Zone kennt der Client nicht."

function ns.MapTarget()
    local m = db()
    return m and m.target or nil
end

local function itemText(id)
    return id and ns.ItemName and ns.ItemName(id) or nil
end

-- Sets the target to a point: { map, x, y }, a label, optionally the source key and the item.
-- Returns true, or nil and the reason.
function ns.MapSetPoint(point, label, key, id)
    local m = db()
    if not m then return nil, "Amisia ist noch nicht geladen." end
    if type(point) ~= "table" or type(point.map) ~= "number" or not inRange(point.x) or not inRange(point.y) then
        return nil, NO_ZONE
    end
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, point.map)
        if not (ok and info) then return nil, NO_ZONE end
    end
    local old = m.target
    local t = { map = point.map, x = point.x, y = point.y, key = key, item = tonumber(id), label = label or "?",
        at = time and time() or 0, ours = false }
    m.target = t
    if setWaypoint(t.map, t.x, t.y) then
        t.ours = true
    else
        -- no waypoint here: an old one of ours must not keep pointing elsewhere
        clearOwn(old)
    end
    ns.Fire("MAP_TARGET")
    local item = itemText(t.item)
    ns.msg(("Ziel %s%s."):format(whereText(t.label, t), item and (" (" .. item .. ")") or ""))
    return true
end

-- Sets the target to the nearest place of an item (or of the chosen source key).
function ns.MapSetTarget(id, key)
    if not ns.MAP then return nil, NO_DATA end
    id = tonumber(id)
    local places = id and ns.MapItemPlaces(id) or {}
    if key then
        local only = {}
        for _, p in ipairs(places) do
            if p.key == key then only[#only + 1] = p end
        end
        places = only
    end
    if #places == 0 then return nil, NO_PLACE end
    local all, owner = {}, {}
    for _, p in ipairs(places) do
        for _, pt in ipairs(p.points) do
            all[#all + 1] = pt
            owner[pt] = p
        end
    end
    local point = ns.MapNearest(all)
    local place = owner[point]
    return ns.MapSetPoint(point, labelOf(place), place.key, id)
end

-- Clears the target; the client's waypoint only when Amisia set it and it still stands there.
function ns.MapClearTarget()
    local m = db()
    local t = m and m.target
    if not t then return false end
    m.target = nil
    clearOwn(t)
    ns.Fire("MAP_TARGET")
    return true
end

-- Arrived (closer than 15 yards): a line in the chat once, and with map.autoClear the target goes.
-- Called by the waypoint event and by the arrow's tick. Returns true when arrived.
function ns.MapCheckArrival()
    local t = ns.MapTarget()
    if not t then return false end
    local d = Map.Distance(t)
    if not d or d >= ARRIVE then return false end
    if not t.arrived then
        t.arrived = true
        ns.msg(("Ziel erreicht (%s)."):format(t.label or "?"))
    end
    if ns.Get("map.autoClear") then ns.MapClearTarget() end
    return true
end

-- The client's waypoint changed. Arrived: as above. Otherwise, when Amisia's waypoint is gone or
-- stands elsewhere (the player set or removed one), Amisia's target goes quietly and the
-- waypoint is left as it is.
local function onWaypointUpdated()
    if busy then return end
    local t = ns.MapTarget()
    if not t or not t.ours then return end
    if waypointAt(t) then return end
    t.ours = false
    if ns.MapCheckArrival() then return end
    if t.arrived then return end
    local m = db()
    if m and m.target == t then
        m.target = nil
        ns.Fire("MAP_TARGET")
    end
end
ns.OnEvent("USER_WAYPOINT_UPDATED", onWaypointUpdated)

-- After /reload or login: a waypoint of ours that still stands stays ours, a missing one is set
-- again; a foreign one is left alone (the target then stands on its own).
local restored = false
local function restore()
    if restored then return end
    restored = true
    local t = ns.MapTarget()
    if not t or not Map.ClientWaypoints() then
        if t then t.ours = false end
        return
    end
    if waypointAt(t) then
        t.ours = true
    elseif not hasWaypoint() then
        t.ours = setWaypoint(t.map, t.x, t.y)
    else
        t.ours = false
    end
end
ns.OnEvent("PLAYER_ENTERING_WORLD", restore)

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.MapMigrate(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- The world map
---------------------------------------------------------------------------

-- Opens the world map on the point's zone (not in combat). Returns true when it did.
function ns.MapShowOnWorldMap(point)
    if type(point) ~= "table" or type(point.map) ~= "number" then return false end
    if InCombatLockdown and InCombatLockdown() then
        ns.msg("Im Kampf öffnet Amisia die Weltkarte nicht.")
        return false
    end
    local frame = _G.WorldMapFrame
    if not frame then return false end
    if not frame:IsShown() then
        if OpenWorldMap then
            OpenWorldMap(point.map)
        elseif ToggleWorldMap then
            ToggleWorldMap()
        end
    end
    if frame.SetMapID then frame:SetMapID(point.map) end
    return frame:IsShown() and true or false
end

---------------------------------------------------------------------------
-- Tooltip line
---------------------------------------------------------------------------

-- "Fundort: Gorn One Eye, Durotar 47, 33" for an item with a place (the nearest), with map.tooltip.
function ns.MapTooltipLine(id)
    if not ns.MAP or not ns.Get("map.tooltip") then return nil end
    local places = ns.MapItemPlaces(id)
    if #places == 0 then return nil end
    local all, owner = {}, {}
    for _, p in ipairs(places) do
        for _, pt in ipairs(p.points) do
            all[#all + 1] = pt
            owner[pt] = p
        end
    end
    local point = ns.MapNearest(all)
    local place = owner[point]
    return "Fundort: " .. whereText(placeName(place), point, isEntrance(place.key))
end

---------------------------------------------------------------------------
-- Settings and commands
---------------------------------------------------------------------------

ns.RegisterSettings{ key = "map", label = "Karte und Wegpunkt", order = 47, available = function() return ns.MAP ~= nil end, items = {
    { key = "map.pins", type = "toggle", label = "Orte auf der Weltkarte zeigen", default = true,
      tip = "Pins für Upgrades und Wünsche, mit Item-Symbol." },
    { key = "map.pinsTargets", type = "toggle", label = "Pins für Upgrades aus Ziele", default = true },
    { key = "map.pinsWishes", type = "toggle", label = "Pins für Wünsche", default = true },
    { key = "map.pinsContinent", type = "toggle", label = "Pins auch auf der Kontinentkarte", default = true },
    { key = "map.pinScale", type = "slider", label = "Pin-Größe (%)", default = 100, min = 60, max = 160, step = 10, expert = true },
    { key = "map.arrow", type = "choice", label = "Pfeil zum Ziel", default = "auto",
      values = { { "auto", "Automatisch" }, { "on", "Immer" }, { "off", "Aus" } },
      tip = "Automatisch: nur wo der Client keinen eigenen Wegweiser hat (TBC)." },
    { key = "map.autoClear", type = "toggle", label = "Ziel beim Ankommen löschen", default = true },
    { key = "map.tooltip", type = "toggle", label = "Fundort im Tooltip (mit Shift)", default = true },
    { key = "map.resetHidden", type = "button", label = "Ausgeblendete Orte wieder zeigen",
      run = function()
          local m = db()
          if m then wipe(m.hidden) end
          ns.Fire("MAP_TARGET")
      end },
    { key = "map.resetArrow", type = "button", label = "Pfeilposition zurücksetzen", expert = true,
      run = function()
          local s = AmisiaDB and AmisiaDB.settings
          if s and type(s.map) == "table" then s.map.arrowPos = nil end
          if ns.MapResetArrow then ns.MapResetArrow() end
      end },
}}

-- The item of a command: a link, else a bare item id.
local function itemOf(rest)
    local id = ns.ItemID(rest)
    if id then return id end
    return tonumber(rest:match("^%s*(%d+)%s*$"))
end

local function statusLine()
    local t = ns.MapTarget()
    if not t then return "Kein Ziel gesetzt. /amisia karte <Item-Link> setzt eins." end
    return ("Ziel: %s, %s %s."):format(t.label or "?", zoneName(t.map), Map.Coords(t))
end

ns.RegisterSlash("karte", { aliases = { "map" }, args = "[<Link> | aus | pins | pfeil]",
    desc = "Karte: Ziel zur Quelle eines Items, Pins und Pfeil",
    run = function(rest)
        rest = (rest or ""):match("^%s*(.-)%s*$")
        local word = rest:lower()
        if not ns.MAP then
            ns.msg(NO_DATA)
            return
        end
        if word == "" then
            if ns.ShowMap then ns.ShowMap() else ns.msg(statusLine()) end
        elseif word == "aus" or word == "clear" then
            if ns.MapClearTarget() then ns.msg("Ziel gelöscht.") else ns.msg("Kein Ziel gesetzt.") end
        elseif word == "pins" then
            local on = not ns.Get("map.pins")
            ns.Set("map.pins", on)
            ns.msg(on and "Pins auf der Weltkarte an." or "Pins auf der Weltkarte aus.")
        elseif word == "pfeil" or word == "arrow" then
            local m = db()
            local now = ns.Get("map.arrow")
            if now == "off" then
                ns.Set("map.arrow", m and m.arrowBefore or "auto")
                ns.msg("Pfeil zum Ziel an.")
            else
                if m then m.arrowBefore = now end
                ns.Set("map.arrow", "off")
                ns.msg("Pfeil zum Ziel aus.")
            end
        else
            local id = itemOf(rest)
            if not id then
                ns.msg("Aufruf: /amisia karte [<Item-Link> | aus | pins | pfeil]")
                return
            end
            local ok, why = ns.MapSetTarget(id)
            if not ok then ns.msg(why) end
        end
    end })
