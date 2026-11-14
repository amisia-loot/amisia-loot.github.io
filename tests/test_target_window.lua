-- The target window on Forever (F-203, review): the client's waypoint events come inside the call
-- (USER_WAYPOINT_UPDATED is synchronous), so arriving or clearing in a fight, a target where the player
-- stands and a pin reached in a fight must each give one line and leave no pin behind; compact cuts the
-- distance to the card. (test_map_waypoint.lua loads Map.lua a second time for its /reload; this file
-- does not, so one copy of the module runs.)
local Map = NS.Map
assert(Map.ClientWaypoints(), "the client has the user waypoint")
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

STUB.instance = { type = "none" }
STUB.item(100, "Lederhose der Wildnis", 2)
NS.GEAR = { game = "forever", cap = 60, built = "t-tw", Z = {}, S = {
    { "V", "Gorn One Eye", 1411, nil, "Armorer" },
}, I = {
    [100] = { "LEGS", 4, 2, 10, 2, 1, 20, 0, 0, 0, 1 },
} }
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = { ["V:Gorn One Eye"] = "1411:4720:3310" } }
STUB.maps[1411] = { name = "Durotar", world = { 1, 0, 0, 1000, 1000 } }
STUB.place.map = 1411
STUB.map.pos = { x = 0.1, y = 0.1 }
STUB.facing = 0
Map._reset()
local wp = STUB.waypoint
NS.Set("map.arrow", "on")
assert(NS.Get("map.autoClear"), "autoClear on by default")

-- review of F-203: arriving at Amisia's own target in a fight: one line, the window goes (its waypoint,
-- left until after the fight, is no "Kartenmarkierung")
STUB.map.pos = { x = 0.1, y = 0.1 }
assert(NS.MapSetTarget(100) and NS.MapTarget().ours)
STUB.combat = true
local n = #STUB.messages
STUB.map.pos = { x = 0.472, y = 0.341 }
AmisiaArrow.scripts.OnUpdate(AmisiaArrow, 0.1)
assert(#STUB.messages == n + 1 and has(lastMsg(), "Ziel erreicht (Gorn One Eye)."), tostring(#STUB.messages - n))
assert(NS.MapTarget() == nil and not AmisiaArrow:IsShown(), "the window went with the target")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
assert(wp.point == nil, "its waypoint after the fight")
-- the X in a fight on Amisia's own target: the window goes at once
STUB.map.pos = { x = 0.1, y = 0.1 }
assert(NS.MapSetTarget(100))
STUB.combat = true
AmisiaArrow.close:Click()
assert(NS.MapTarget() == nil and not AmisiaArrow:IsShown(), "X in a fight")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
-- a target where the player stands: one line, not three
STUB.map.pos = { x = 0.472, y = 0.335 }
n = #STUB.messages
assert(NS.MapSetTarget(100))
AmisiaArrow.scripts.OnUpdate(AmisiaArrow, 0.1)
assert(#STUB.messages - n <= 2 and not lastMsg():find("Kartenmarkierung", 1, true), table.concat(STUB.messages, " || ", n + 1))
NS.MapClearTarget()
-- arriving at the client's pin in a fight: the pin goes after the fight
STUB.map.pos = { x = 0.1, y = 0.1 }
STUB.combat = true
C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1411, 0.1, 0.105))
AmisiaArrow.scripts.OnUpdate(AmisiaArrow, 0.1)
assert(wp.point ~= nil, "not in the fight")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
assert(wp.point == nil, "the arrived pin went after the fight")
-- compact: the distance is cut to the card
NS.Set("map.compact", true)
C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1411, 0.3, 0.3))
assert(AmisiaArrow._w == 190 and AmisiaArrow.dist._w == 190 - 10 - 64 - 10 - 10, tostring(AmisiaArrow.dist._w))
NS.Set("map.compact", false)
assert(AmisiaArrow.dist._w == 250 - 10 - 64 - 10 - 10, "detailed: the room right of the compass")
C_Map.ClearUserWaypoint()
print("target window ok")
