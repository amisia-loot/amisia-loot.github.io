-- Amisia map: where the sources of an item stand (quest givers, vendors, rare and named mobs, raid
-- and dungeon entrances), from the generated MapData.lua, and one target at a time. The target
-- becomes the client's user waypoint with its guide arrow; where the client cannot set it (a map
-- without waypoints, a refusal, a client without the waypoint functions) Amisia shows it itself.
-- Only fixed places from the data are shown; nothing here reads other units or works inside
-- instances.
local ADDON, ns = ...
local Gear = ns.Gear
local L, N_ = ns.L, ns.N_

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
-- raids, dungeons and dungeon trash; nil for sources without a place.
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
        return place
    end
    return nil
end

local parsed = {}        -- key -> list of points, parsed once
local unknownMaps = {}   -- uiMapIDs the client does not know, noted once per session
local placeCache = {}    -- item id -> { gen, wish, map, gear, list }: ns.MapItemPlaces with the page's filters
local whereCache = {}    -- item id (or "id|key") -> { list, m, cx, cy, text, line }: the nearest place as text

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
-- Points of a text "uiMapID:x:y ..." (x, y in hundredths of a percent) as { { map, x, y } }; broken
-- parts and maps the client does not know are skipped. Other generated data (the dungeon quests)
-- writes its points the same way.
function Map.ParsePoints(text)
    local list = {}
    if type(text) == "string" then
        for part in text:gmatch("%S+") do
            local m, x, y = part:match("^(%d+):(%d+):(%d+)$")
            m, x, y = tonumber(m), tonumber(x), tonumber(y)
            if m and x and y and m > 0 and x <= 10000 and y <= 10000 and knownMap(m) then
                list[#list + 1] = { map = m, x = x / 10000, y = y / 10000 }
            end
        end
    end
    return list
end

function ns.MapPoints(key)
    local list = parsed[key]
    if list then return list end
    local map = ns.Data("MAP")
    list = Map.ParsePoints(map and map.P and map.P[key])
    parsed[key] = list
    return list
end
Map.Points = ns.MapPoints

-- uiMapIDs of the data the client did not know this session.
function Map.UnknownMaps() return unknownMaps end

-- Who stands at a key (the quest giver), English, or nil.
function Map.Giver(key)
    local map = ns.Data("MAP")
    return map and map.G and map.G[key] or nil
end

-- Test hook: forget the parsed points (after the data changed).
function Map._reset()
    parsed, unknownMaps, placeCache, whereCache = {}, {}, {}, {}
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

-- The gear page's options (ns.BisOpts), made once per state of Bis.lua (its stamp) and of what the
-- stamp does not follow (faction, level, class), and a number that changes with them. The caches
-- of the places and their texts go with every new set of options.
local opts, optsGen, optsStamp, optsFac, optsLevel, optsClass = nil, 0, nil, nil, nil, nil
function Map.PageOpts()
    local st = ns.BisStamp()
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    local level = UnitLevel and UnitLevel("player")
    local _, class = UnitClass("player")
    if not opts or st ~= optsStamp or fac ~= optsFac or level ~= optsLevel or class ~= optsClass then
        opts, optsStamp, optsFac, optsLevel, optsClass = ns.BisOpts(), st, fac, level, class
        optsGen = optsGen + 1
        placeCache, whereCache = {}, {}
    end
    return opts, optsGen
end

-- The sources of an item that have a place: { { key, rec, points, giver }, ... } in the order of
-- Gear.Sources, one entry per key. Without opts the gear page's own filters (ns.BisOpts); a wish
-- whose sources the filters all leave out takes every source. Without opts the list is kept until
-- the options, the wish or the data change: callers must not change it.
function ns.MapItemPlaces(id, o)
    id = tonumber(id)
    if not id or not ns.HasData("MAP") or not Gear.Available() or not Gear.Item(id) then return {} end
    if o then return placesOf(Gear.Sources(id, o)) end
    local page, gen = Map.PageOpts()
    local wish = isWish(id)
    local e = placeCache[id]
    if e and e.gen == gen and e.wish == wish and e.map == ns.Data("MAP") and e.gear == ns.Data("GEAR") then return e.list end
    local out = placesOf(Gear.Sources(id, page))
    if #out == 0 and wish then out = placesOf(Gear.Sources(id)) end
    placeCache[id] = { gen = gen, wish = wish, map = ns.Data("MAP"), gear = ns.Data("GEAR"), list = out }
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
    -- the client's world position as a fallback for the distance (UnitPosition: positionX,
    -- positionY, positionZ, instance: the same axes as the world position of a map point)
    if UnitPosition then
        local wx, wy, _, cont = UnitPosition("player")
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

-- The nearest point of a list of places (only key's, when given): point, its place, yards (or nil).
local function nearestOf(places, key)
    local all, owner = {}, {}
    for _, p in ipairs(places) do
        if not key or p.key == key then
            for _, pt in ipairs(p.points) do
                all[#all + 1] = pt
                owner[pt] = p
            end
        end
    end
    local point, d = ns.MapNearest(all)
    if not point then return nil end
    return point, owner[point], d
end

-- The nearest place of an item (with the page's filters; only the source key's, when given):
-- point, place, yards; nil without a place.
function Map.ItemNearest(id, key)
    return nearestOf(ns.MapItemPlaces(id), key)
end

-- The player's map and the cell of 2 % he stands in, for caches that follow him; nil inside an
-- instance or without a map (the cell is -1, -1 without a position on it).
local function playerCell()
    if inInstance() or not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = ns.Plain(C_Map.GetBestMapForUnit("player"))
    if type(map) ~= "number" then return nil end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos then x, y = ns.Plain(pos.x), ns.Plain(pos.y) end
    if type(x) ~= "number" or type(y) ~= "number" then return map, -1, -1 end
    return map, math.floor(x * 50), math.floor(y * 50)
end
Map.PlayerCell = playerCell

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------

local function isEntrance(key) return type(key) == "string" and (key:sub(1, 2) == "I:" or key:sub(1, 2) == "N:") end

-- The name a place shows: the quest giver or quest, the vendor or mob, the raid or dungeon (client
-- name by area id).
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
    if entrance then return (L["%s (Eingang %s %s)"]):format(name, zoneName(point.map), Map.Coords(point)) end
    return ("%s, %s %s"):format(name, zoneName(point.map), Map.Coords(point))
end

-- The short label of a target.
local function labelOf(place)
    local name = placeName(place)
    if isEntrance(place.key) then return L["%s (Eingang)"]:format(name) end
    return name
end

-- For the pins and the page: the name and the label of a place { key, rec, giver }, a zone's name.
Map.PlaceName, Map.LabelOf, Map.ZoneName = placeName, labelOf, zoneName

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

local NO_DATA = L["Keine Kartendaten für diesen Client."]
local NO_PLACE = L["Für dieses Item kennt Amisia keinen Ort."]
local NO_ZONE = L["Diese Zone kennt der Client nicht."]

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
    if not m then return nil, L["Amisia ist noch nicht geladen."] end
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
    ns.msg((L["Ziel %s%s."]):format(whereText(t.label, t), item and (" (" .. item .. ")") or ""))
    return true
end

-- Sets the target to the nearest place of an item (or of the chosen source key).
function ns.MapSetTarget(id, key)
    if not ns.HasData("MAP") then return nil, NO_DATA end
    id = tonumber(id)
    local point, place = nearestOf(id and ns.MapItemPlaces(id) or {}, key)
    if not point then return nil, NO_PLACE end
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
        ns.msg((L["Ziel erreicht (%s)."]):format(t.label or "?"))
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
        ns.msg(L["Im Kampf öffnet Amisia die Weltkarte nicht."])
        return false
    end
    local frame = _G.WorldMapFrame
    if not frame then return false end
    -- the main window is fullscreen and toplevel: the map would open underneath it
    local main = _G.AmisiaFrame
    if main and main.IsShown and main:IsShown() then main:Hide() end
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
-- Direction
---------------------------------------------------------------------------

-- The world directions of a map's east and south (unit vectors), measured once per map: the world
-- position of two nearby map points tells them whatever the client's axes are.
local axes = {}
local function axesOf(map)
    local a = axes[map]
    if a ~= nil then return a or nil end
    local c0, x0, y0 = worldOf(map, 0.5, 0.5)
    local c1, x1, y1 = worldOf(map, 0.6, 0.5)
    local c2, x2, y2 = worldOf(map, 0.5, 0.6)
    a = false
    if c0 and c1 and c2 then
        local ex, ey, sx, sy = x1 - x0, y1 - y0, x2 - x0, y2 - y0
        local el, sl = math.sqrt(ex * ex + ey * ey), math.sqrt(sx * sx + sy * sy)
        if el > 0 and sl > 0 then a = { ex / el, ey / el, sx / sl, sy / sl } end
    end
    axes[map] = a
    return a or nil
end

-- The bearing from the player to a point in radians, clockwise from the map's north; nil without a
-- position or on another continent. me: Map.PlayerPosition().
function Map.Bearing(point, me)
    me = me or Map.PlayerPosition()
    if not me or not me.wx or not point then return nil end
    local cont, wx, wy = worldOf(point.map, point.x, point.y)
    if not cont or cont ~= me.cont then return nil end
    local a = axesOf(me.map)
    if not a then return nil end
    local dx, dy = wx - me.wx, wy - me.wy
    local east = dx * a[1] + dy * a[2]
    local south = dx * a[3] + dy * a[4]
    if east == 0 and south == 0 then return 0 end
    return math.atan2(east, -south) % (2 * math.pi)
end

local WORDS = { N_("Nord"), N_("Nordost"), N_("Ost"), N_("Südost"), N_("Süd"), N_("Südwest"), N_("West"), N_("Nordwest") }
-- One of eight directions for a bearing (radians clockwise from north).
function Map.DirectionWord(bearing)
    if type(bearing) ~= "number" then return nil end
    local i = math.floor(((bearing % (2 * math.pi)) / (math.pi / 4)) + 0.5) % 8
    return L[WORDS[i + 1]]
end

---------------------------------------------------------------------------
-- The arrow (AmisiaArrow): Amisia's own pointer to the target where the client's guide cannot carry it
---------------------------------------------------------------------------

local ARROW_TEX = "Interface\\AddOns\\Amisia\\Media\\Icons\\arrow"
local TICK = 0.1                  -- seconds between two updates of the arrow
local arrow                       -- the frame, made the first time it is needed

-- Whether the arrow should show: map.arrow "on", or "auto" while the client's own guide does not
-- carry the target (its waypoint could not be set); only with a target,
-- outside instances and with a readable position. Returns the position (Map.PlayerPosition) or nil.
local function arrowWanted()
    local t = ns.MapTarget()
    if not t then return nil end
    local mode = ns.Get("map.arrow")
    if mode == "off" or (mode ~= "on" and t.ours) then return nil end
    return Map.PlayerPosition()
end

local function arrowPlace(f)
    f:ClearAllPoints()
    local s = AmisiaDB and AmisiaDB.settings
    local pos = s and type(s.map) == "table" and s.map.arrowPos
    if type(pos) == "table" and type(pos[1]) == "string" and type(pos[3]) == "number" and type(pos[4]) == "number" then
        f:SetPoint(pos[1], UIParent, type(pos[2]) == "string" and pos[2] or pos[1], pos[3], pos[4])
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
end

-- Whether the client can turn the arrow: GetPlayerFacing gives a number and the texture turns.
local function facing(icon)
    if not (GetPlayerFacing and icon.SetRotation) then return nil end
    local ok, f = pcall(GetPlayerFacing)
    f = ok and ns.Plain(f) or nil
    return type(f) == "number" and f or nil
end

local function arrowUpdate(f)
    local t = ns.MapTarget()
    local me = arrowWanted()
    if not t or not me then
        f:Hide()
        return
    end
    local d = Map.Distance(t, me)
    f.label:SetText(t.label or "?")
    if not d then
        f.icon:Hide()
        f.dist:SetText(L["Anderer Kontinent"])
        f.dist:SetTextColor(0.6, 0.6, 0.6)
        return
    end
    if d < ARRIVE then
        ns.MapCheckArrival()
        if ns.MapTarget() ~= t then return end      -- cleared: MAP_TARGET hid the arrow
        f.icon:Hide()
        f.dist:SetText(L["Angekommen"])
        f.dist:SetTextColor(0.3, 0.9, 0.3)
        return
    end
    local text = (L["%d m"]):format(math.floor(d + 0.5))
    local bearing = Map.Bearing(t, me)
    local face = facing(f.icon)
    if bearing and face then
        f.icon:SetRotation(-(bearing + face))
        f.icon:Show()
    else
        f.icon:Hide()
        local word = Map.DirectionWord(bearing)
        if word then text = text .. " " .. word end
    end
    f.dist:SetText(text)
    f.dist:SetTextColor(1, 0.82, 0)
end

local function arrowMenu(f)
    ns.W.Menu(f, {
        { L["Ziel löschen"], function() ns.MapClearTarget() end },
        { L["Auf der Weltkarte zeigen"], function()
            local t = ns.MapTarget()
            if t then ns.MapShowOnWorldMap(t) end
        end },
        { L["Pfeil ausblenden"], function()
            local m = db()
            local now = ns.Get("map.arrow")
            if m and now ~= "off" then m.arrowBefore = now end
            ns.Set("map.arrow", "off")
            ns.msg(L["Pfeil aus. Wieder an: /amisia karte pfeil oder in den Einstellungen."])
        end },
    })
end

local function arrowTooltip(f)
    local t = ns.MapTarget()
    if not t then return end
    GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(t.label or "?", 1, 0.82, 0)
    local item = itemText(t.item)
    if item then GameTooltip:AddLine(item, 1, 1, 1) end
    GameTooltip:AddLine(("%s %s"):format(zoneName(t.map), Map.Coords(t)), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L["Ziehen: verschieben. Rechtsklick: mehr."], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function makeArrow()
    local f = CreateFrame("Button", "AmisiaArrow", UIParent)
    f:SetSize(96, 84)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:RegisterForClicks("RightButtonUp")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(56, 56)
    f.icon:SetPoint("TOP", 0, 0)
    f.icon:SetTexture(ARROW_TEX)
    f.icon:SetVertexColor(ns.W.GOLD[1], ns.W.GOLD[2], ns.W.GOLD[3])
    f.label = ns.W.Text(f, "GameFontHighlightSmall", 90)
    f.label:SetPoint("TOP", f.icon, "BOTTOM", 0, -1)
    f.label:SetJustifyH("CENTER")
    f.dist = ns.W.Text(f, "GameFontNormalSmall", 96)
    f.dist:SetPoint("TOP", f.label, "BOTTOM", 0, -1)
    f.dist:SetJustifyH("CENTER")
    f.wait = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.wait = self.wait + (elapsed or 0)
        if self.wait < TICK - 1e-9 then return end
        self.wait = 0
        arrowUpdate(self)
    end)
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        local s = AmisiaDB and AmisiaDB.settings
        if s and point then
            s.map = type(s.map) == "table" and s.map or {}
            s.map.arrowPos = { point, relPoint or point, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
        end
    end)
    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then arrowMenu(self) end
    end)
    f:SetScript("OnEnter", arrowTooltip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    arrowPlace(f)
    return f
end

-- Shows or hides the arrow for the current target and setting; the tick runs only while it shows.
function Map.UpdateArrow()
    if not arrowWanted() then
        if arrow then arrow:Hide() end
        return
    end
    arrow = arrow or makeArrow()
    arrow.wait = 0
    arrowUpdate(arrow)
    if ns.MapTarget() and arrowWanted() then arrow:Show() end
end

-- The arrow frame, if made (for the settings and the tests).
function Map.Arrow() return arrow end

-- Puts the arrow back to its start (the saved position is gone already).
function ns.MapResetArrow()
    if arrow then arrowPlace(arrow) end
end

ns.Listen("MAP_TARGET", Map.UpdateArrow)
ns.Listen("SETTING", function(path)
    if path == "map.arrow" or path == nil then Map.UpdateArrow() end
end)
ns.OnEvent("PLAYER_ENTERING_WORLD", Map.UpdateArrow)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", Map.UpdateArrow)
ns.OnEvent("ZONE_CHANGED", Map.UpdateArrow)

---------------------------------------------------------------------------
-- Tooltip line
---------------------------------------------------------------------------

-- The nearest place of an item as text, kept per item until its places change or, for an item with
-- more than one point, the player moves to another 2 % cell (the hover path reads only the cell).
local function whereEntry(id, key)
    local places = ns.MapItemPlaces(id)
    if #places == 0 then return nil end
    local m, cx, cy
    if #places > 1 or #places[1].points > 1 then m, cx, cy = playerCell() end
    -- a source key narrows it to that place; kept apart from the item's nearest
    local ck = key and (tostring(id) .. "|" .. key) or id
    local e = whereCache[ck]
    if e and e.list == places and e.m == m and e.cx == cx and e.cy == cy then return e end
    local point, place = nearestOf(places, key)
    if not point and key then return whereEntry(id) end
    if not point then return nil end
    local text = whereText(placeName(place), point, isEntrance(place.key))
    e = { list = places, m = m, cx = cx, cy = cy, text = text, line = L["Fundort: %s"]:format(text) }
    whereCache[ck] = e
    return e
end

-- "Gorn One Eye, Durotar 47, 33" (the nearest place of an item, of the source key's when given), or nil.
function Map.Where(id, key)
    id = tonumber(id)
    local e = id and ns.Data("MAP") and whereEntry(id, key)
    return e and e.text or nil
end

-- "Fundort: Gorn One Eye, Durotar 47, 33" for an item with a place (the nearest), with map.tooltip.
function ns.MapTooltipLine(id)
    id = tonumber(id)
    if not id or not ns.HasData("MAP") or not ns.Get("map.tooltip") then return nil end
    local e = whereEntry(id)
    return e and e.line or nil
end

---------------------------------------------------------------------------
-- Settings and commands
---------------------------------------------------------------------------

ns.RegisterSettings{ key = "map", label = L["Karte und Wegpunkt"], order = 47, available = function() return ns.HasData("MAP") end, items = {
    { key = "map.pins", type = "toggle", label = L["Orte auf der Weltkarte zeigen"], default = true,
      tip = L["Pins für Upgrades und Wünsche, mit Item-Symbol."] },
    { key = "map.pinsTargets", type = "toggle", label = L["Pins für Upgrades aus Ziele"], default = true },
    { key = "map.pinsWishes", type = "toggle", label = L["Pins für Wünsche"], default = true },
    { key = "map.pinsContinent", type = "toggle", label = L["Pins auch auf der Kontinentkarte"], default = true },
    { key = "map.pinScale", type = "slider", label = L["Pin-Größe (%)"], default = 100, min = 60, max = 160, step = 10, expert = true },
    { key = "map.arrow", type = "choice", label = L["Pfeil zum Ziel"], default = "auto",
      values = { { "auto", L["Automatisch"] }, { "on", L["Immer"] }, { "off", L["Aus"] } },
      tip = L["Automatisch: nur wenn der Client den Wegpunkt nicht setzen kann."] },
    { key = "map.autoClear", type = "toggle", label = L["Ziel beim Ankommen löschen"], default = true },
    { key = "map.tooltip", type = "toggle", label = L["Fundort im Tooltip (mit Shift)"], default = true },
    { key = "map.resetHidden", type = "button", label = L["Ausgeblendete Orte wieder zeigen"],
      run = function()
          local m = db()
          if m then wipe(m.hidden) end
          ns.Fire("MAP_TARGET")
      end },
    { key = "map.resetArrow", type = "button", label = L["Pfeilposition zurücksetzen"], expert = true,
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
    if not t then return L["Kein Ziel gesetzt. /amisia karte <Item-Link> setzt eins."] end
    return (L["Ziel: %s, %s %s."]):format(t.label or "?", zoneName(t.map), Map.Coords(t))
end

ns.RegisterSlash("karte", { en = "map", args = L["[<Link> | aus | pins | pfeil]"],
    desc = L["Karte: Ziel zur Quelle eines Items, Pins und Pfeil"],
    run = function(rest)
        rest = (rest or ""):match("^%s*(.-)%s*$")
        local word = rest:lower()
        if not ns.HasData("MAP") then
            ns.msg(NO_DATA)
            return
        end
        if word == "" then
            if ns.ShowMap then ns.ShowMap() else ns.msg(statusLine()) end
        elseif word == "aus" or word == "off" or word == "clear" then
            if ns.MapClearTarget() then ns.msg(L["Ziel gelöscht."]) else ns.msg(L["Kein Ziel gesetzt."]) end
        elseif word == "pins" then
            local on = not ns.Get("map.pins")
            ns.Set("map.pins", on)
            ns.msg(on and L["Pins auf der Weltkarte an."] or L["Pins auf der Weltkarte aus."])
        elseif word == "pfeil" or word == "arrow" then
            local m = db()
            local now = ns.Get("map.arrow")
            if now == "off" then
                ns.Set("map.arrow", m and m.arrowBefore or "auto")
                ns.msg(L["Pfeil zum Ziel an."])
            else
                if m then m.arrowBefore = now end
                ns.Set("map.arrow", "off")
                ns.msg(L["Pfeil zum Ziel aus."])
            end
        else
            local id = itemOf(rest)
            if not id then
                ns.msg(L["Aufruf: /amisia karte [<Item-Link> | aus | pins | pfeil]"])
                return
            end
            local ok, why = ns.MapSetTarget(id)
            if not ok then ns.msg(why) end
        end
    end })
