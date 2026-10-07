-- The target and the client's user waypoint on Forever: setting puts the waypoint and the guide
-- arrow there (ours); a waypoint the player sets himself drops Amisia's target quietly; a foreign
-- waypoint is only replaced when the player picks an Amisia target; clearing removes only the own
-- waypoint; a map without waypoints or a refusing client falls back to Amisia's own target;
-- arriving within 15 yards; the target after /reload; the commands; Latin-1 only.
local Map = NS.Map
assert(Map.ClientWaypoints(), "the client has the user waypoint")
assert(NS.MAP and NS.MAP.game == "forever", "MapData.lua loads")
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

STUB.instance = { type = "none" }
local link = STUB.item(100, "Lederhose der Wildnis", 2)
STUB.item(101, "Nadel", 2)
NS.GEAR = { game = "forever", cap = 60, built = "t-wp", Z = {}, S = {
    { "V", "Gorn One Eye", 1411, nil, "Armorer" },
    { "V", "Far Guy", 1429 },
    { "C", "tailoring", 50 },
}, I = {
    [100] = { "LEGS", 4, 2, 10, 2, 1, 20, 0, 0, 0, 1, 2 },
    [101] = { "LEGS", 4, 2, 10, 2, 1, 20, 0, 0, 0, 3 },
} }
NS.MAP = { game = "forever", built = "2026-10-05", G = {},
    P = { ["V:Gorn One Eye"] = "1411:4720:3310", ["V:Far Guy"] = "1429:4000:4000" } }
STUB.maps[1411] = { name = "Durotar", world = { 1, 0, 0, 1000, 1000 } }
STUB.maps[1429] = { name = "Wald von Elwynn", world = { 0, 0, 0, 1000, 1000 } }
STUB.place.map = 1411
STUB.map.pos = { x = 0.1, y = 0.1 }
Map._reset()
local fired = 0
NS.Listen("MAP_TARGET", function() fired = fired + 1 end)
local wp = STUB.waypoint

-- setting: the waypoint, the guide arrow, ours, the chat line
local ok, why = NS.MapSetTarget(100)
assert(ok, tostring(why))
local t = NS.MapTarget()
assert(t and t.key == "V:Gorn One Eye" and t.map == 1411 and near(t.x, 0.472) and near(t.y, 0.331), "the nearest source")
assert(t.ours == true and t.item == 100 and t.label == "Gorn One Eye" and type(t.at) == "number")
assert(wp.point and wp.point.uiMapID == 1411 and near(wp.point.position.x, 0.472) and near(wp.point.position.y, 0.331))
assert(wp.superTracked, "the guide arrow points there")
assert(fired >= 1, "MAP_TARGET")
assert(has(lastMsg(), "Ziel Gorn One Eye, Durotar 47, 33 (Lederhose der Wildnis)."), lastMsg())
assert(AmisiaDB.map.target == t, "kept in the saved variables")

-- the player sets a waypoint of his own: Amisia's target goes quietly, his waypoint stays
local msgs, clears = #STUB.messages, wp.clears
C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1411, 0.2, 0.2))
assert(NS.MapTarget() == nil, "the foreign waypoint dropped the target")
assert(wp.point and near(wp.point.position.x, 0.2) and wp.clears == clears, "his waypoint untouched")
assert(#STUB.messages == msgs, "quietly")

-- picking an Amisia target replaces his waypoint
assert(NS.MapSetTarget(100))
assert(near(wp.point.position.x, 0.472) and NS.MapTarget().ours)

-- clearing removes the own waypoint
clears = wp.clears
assert(NS.MapClearTarget())
assert(NS.MapTarget() == nil and wp.point == nil and wp.clears == clears + 1)
assert(not NS.MapClearTarget(), "nothing left to clear")

-- clearing with a foreign waypoint in place (no event seen yet) leaves it alone
assert(NS.MapSetTarget(100))
wp.point = { uiMapID = 1429, position = CreateVector2D(0.3, 0.3) }
clears = wp.clears
NS.MapClearTarget()
assert(NS.MapTarget() == nil and wp.point and wp.point.uiMapID == 1429 and wp.clears == clears, "only our own is cleared")

-- the player removes the waypoint far from it: the target goes quietly
assert(NS.MapSetTarget(100))
msgs = #STUB.messages
C_Map.ClearUserWaypoint()
assert(NS.MapTarget() == nil and #STUB.messages == msgs)

-- a chosen source; a map without waypoints: Amisia's own target, the old waypoint of ours removed
assert(NS.MapSetTarget(100, "V:Far Guy"))
assert(NS.MapTarget().key == "V:Far Guy" and wp.point.uiMapID == 1429)
wp.blocked[1411] = true
local sets = wp.sets
assert(NS.MapSetTarget(100, "V:Gorn One Eye"))
t = NS.MapTarget()
assert(t.key == "V:Gorn One Eye" and t.ours == false and wp.sets == sets, "no waypoint on that map")
assert(wp.point == nil, "our old waypoint went")
wp.blocked[1411] = nil
assert(select(2, NS.MapSetTarget(100, "V:Nobody")) == "Für dieses Item kennt Amisia keinen Ort.")

-- a client that refuses or throws: the same fallback, no error
local realSet = C_Map.SetUserWaypoint
C_Map.SetUserWaypoint = function() error("protected") end
assert(NS.MapSetTarget(100))
assert(NS.MapTarget().ours == false)
C_Map.SetUserWaypoint = function() return false end
assert(NS.MapSetTarget(100) and NS.MapTarget().ours == false)
C_Map.SetUserWaypoint = realSet
NS.MapClearTarget()

-- reasons
assert(select(2, NS.MapSetTarget(101)) == "Für dieses Item kennt Amisia keinen Ort.")
assert(select(2, NS.MapSetPoint({ map = 9999, x = 0.5, y = 0.5 }, "X")) == "Diese Zone kennt der Client nicht.")
local data = NS.MAP
NS.MAP = nil
assert(select(2, NS.MapSetTarget(100)) == "Keine Kartendaten für diesen Client.")
NS.MAP = data

-- arriving: the client clears its waypoint within reach, Amisia follows with a line
assert(NS.MapSetTarget(100))
STUB.map.pos = { x = 0.472, y = 0.341 }      -- 10 yards on a 1000-yard map
C_Map.ClearUserWaypoint()
assert(has(lastMsg(), "Ziel erreicht (Gorn One Eye)."), lastMsg())
assert(NS.MapTarget() == nil, "cleared on arrival")
-- without map.autoClear the target stays (the client's waypoint is gone, so it is no longer ours)
NS.Set("map.autoClear", false)
STUB.map.pos = { x = 0.1, y = 0.1 }
assert(NS.MapSetTarget(100))
STUB.map.pos = { x = 0.48, y = 0.331 }       -- 8 yards
C_Map.ClearUserWaypoint()
assert(has(lastMsg(), "Ziel erreicht (Gorn One Eye)."))
t = NS.MapTarget()
assert(t and t.ours == false, "kept without autoClear")
msgs = #STUB.messages
assert(NS.MapCheckArrival() and #STUB.messages == msgs, "said once")
NS.Set("map.autoClear", true)
NS.MapClearTarget()
STUB.map.pos = { x = 0.1, y = 0.1 }
assert(NS.MapSetTarget(100))
assert(not NS.MapCheckArrival(), "far away")
STUB.map.pos = { x = 0.472, y = 0.335 }
assert(NS.MapCheckArrival() and NS.MapTarget() == nil, "the own check, as the arrow's tick calls it")
assert(STUB.waypoint.point == nil, "the own waypoint cleared on arrival")

-- after /reload: the target stays; a standing waypoint stays ours, a missing one is set again,
-- a foreign one is left alone
local function reload()
    local fh = assert(io.open(ADDON_DIR .. "/Gear/Map.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    assert(loadstring(src, "@Map.lua"))("Amisia", NS)
    STUB.fire("ADDON_LOADED", "Amisia")
    STUB.fire("PLAYER_ENTERING_WORLD", true, false)
end
STUB.map.pos = { x = 0.1, y = 0.1 }
assert(NS.MapSetTarget(100))
sets = wp.sets
reload()
t = NS.MapTarget()
assert(t and t.key == "V:Gorn One Eye" and t.ours and wp.sets == sets, "standing waypoint kept")
wp.point = nil
reload()
assert(NS.MapTarget() and NS.MapTarget().ours and wp.sets == sets + 1 and near(wp.point.position.x, 0.472), "set again")
wp.point = { uiMapID = 1429, position = CreateVector2D(0.3, 0.3) }
sets = wp.sets
reload()
t = NS.MapTarget()
assert(t and t.ours == false and wp.sets == sets and wp.point.uiMapID == 1429, "a foreign waypoint is left alone")
wp.point = nil
NS.MapClearTarget()

-- showing on the world map; not in combat
WorldMapFrame:Hide()
assert(NS.MapShowOnWorldMap({ map = 1429, x = 0.4, y = 0.4 }))
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1429)
WorldMapFrame:Hide()
STUB.combat = true
assert(not NS.MapShowOnWorldMap({ map = 1429, x = 0.4, y = 0.4 }))
assert(not WorldMapFrame:IsShown() and has(lastMsg(), "Im Kampf öffnet Amisia die Weltkarte nicht."))
STUB.combat = false

-- commands
NS.Dispatch("karte " .. link)
assert(NS.MapTarget() and NS.MapTarget().item == 100, "karte <link>")
NS.Dispatch("karte aus")
assert(NS.MapTarget() == nil and has(lastMsg(), "Ziel gelöscht."))
NS.Dispatch("map 100")
assert(NS.MapTarget() and NS.MapTarget().item == 100, "the alias and a bare item id")
NS.Dispatch("karte clear")
assert(NS.MapTarget() == nil)
NS.Dispatch("karte 101")
assert(has(lastMsg(), "Für dieses Item kennt Amisia keinen Ort."))
NS.Dispatch("karte pins")
assert(NS.Get("map.pins") == false and has(lastMsg(), "Pins auf der Weltkarte aus."))
NS.Dispatch("karte pins")
assert(NS.Get("map.pins") == true and has(lastMsg(), "Pins auf der Weltkarte an."))
NS.Dispatch("karte pfeil")
assert(NS.Get("map.arrow") == "off" and has(lastMsg(), "Pfeil zum Ziel aus."))
NS.Dispatch("karte pfeil")
assert(NS.Get("map.arrow") == "auto" and has(lastMsg(), "Pfeil zum Ziel an."))
NS.Set("map.arrow", "on")
NS.Dispatch("karte pfeil")
assert(NS.Get("map.arrow") == "off")
NS.Dispatch("karte pfeil")
assert(NS.Get("map.arrow") == "on", "back to what it was")
NS.Dispatch("karte")
NS.MAP = nil
NS.Dispatch("karte 100")
assert(has(lastMsg(), "Keine Kartendaten für diesen Client."))
NS.MAP = data

-- the arrow on Forever: "auto" leaves it to the client's guide while the waypoint is ours; a map
-- without waypoints gets Amisia's arrow; "on" shows it next to the client's guide; "off" never
STUB.map.pos = { x = 0.1, y = 0.1 }
STUB.facing = 0
NS.Set("map.arrow", "auto")
assert(NS.MapSetTarget(100))
assert(NS.MapTarget().ours and (_G.AmisiaArrow == nil or not AmisiaArrow:IsShown()), "auto: the client's guide only")
NS.Set("map.arrow", "on")
assert(_G.AmisiaArrow and AmisiaArrow:IsShown(), "on: Amisia's arrow too")
AmisiaArrow.scripts.OnUpdate(AmisiaArrow, 0.1)
assert(AmisiaArrow.dist:GetText() == "438 m" and AmisiaArrow.icon:IsShown(), tostring(AmisiaArrow.dist:GetText()))
NS.Set("map.arrow", "auto")
assert(not AmisiaArrow:IsShown())
wp.blocked[1411] = true
assert(NS.MapSetTarget(100))
assert(NS.MapTarget().ours == false and AmisiaArrow:IsShown(), "a map without waypoints: the arrow")
NS.Set("map.arrow", "off")
assert(not AmisiaArrow:IsShown(), "off")
NS.Set("map.arrow", "auto")
wp.blocked[1411] = nil
NS.MapClearTarget()
assert(not AmisiaArrow:IsShown(), "no target, no arrow")

-- every line Amisia wrote, and the file, stay within Latin-1
for _, m in ipairs(STUB.messages) do
    for c in m:gmatch("[\196-\255][\128-\191]") do error("character above Latin-1 in chat: " .. m) end
end
local fh = assert(io.open(ADDON_DIR .. "/Gear/Map.lua", "rb"))
local src = fh:read("*a")
fh:close()
for c in src:gmatch("[\196-\255][\128-\191]") do error("Map.lua: character above Latin-1: " .. c) end
