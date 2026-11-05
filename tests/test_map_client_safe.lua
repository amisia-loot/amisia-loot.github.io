-- Amisia leaves the client's waypoint, super tracking and world map alone where a call would taint the
-- objective tracker's next update while auras are secret (D-62): in an instance, in combat and in the
-- lockdown no waypoint is set or cleared and the map stays shut; Amisia's own target still changes,
-- and a waypoint it could not clear goes once that is safe again (leaving the instance, combat's end,
-- the lockdown's end), unless a new target of Amisia's stands there.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local Map = NS.Map
local W = STUB.waypoint

STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.instance = { name = "Westfall", type = "none", id = 0 }
NS.Map._reset()
assert(Map.ClientSafe(), "outside, out of combat")

-- outside: the waypoint and the guide
assert(NS.MapSetPoint({ map = 1436, x = 0.4, y = 0.5 }, "Draußen", "Q:1"))
assert(W.point and W.superTracked and NS.MapTarget().ours, "the client's waypoint outside")

-- in an instance: a new target is Amisia's alone, the old waypoint stays until the instance is left
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
assert(not Map.ClientSafe(), "an instance")
local sets, clears = W.sets, W.clears
assert(NS.MapSetPoint({ map = 1436, x = 0.6, y = 0.7 }, "Drinnen", "Q:2"))
assert(W.sets == sets and W.clears == clears, "no waypoint call in the instance")
assert(NS.MapTarget().label == "Drinnen" and not NS.MapTarget().ours, "the target is Amisia's own")
STUB.messages = {}
WorldMapFrame:Hide()
assert(NS.MapShowOnWorldMap({ map = 1436, x = 0.6, y = 0.7 }) == false and not WorldMapFrame:IsShown(), "no map in an instance")
assert(has(table.concat(STUB.messages, "\n"), "In Instanzen öffnet Amisia die Weltkarte nicht."), table.concat(STUB.messages, "\n"))
assert(NS.MapClearTarget())
assert(W.clears == clears and W.point, "the old waypoint waits")
-- leaving: it goes now
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(W.point == nil and W.clears == clears + 1, "cleared after the instance")

-- arriving at a dungeon entrance and stepping in: the clear waits for the way out
assert(NS.MapSetPoint({ map = 1436, x = 0.4, y = 0.5 }, "Eingang", "I:36"))
assert(W.point and NS.MapTarget().ours)
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
clears = W.clears
NS.MapClearTarget()
assert(W.clears == clears, "nothing inside")
-- a new target set outside before the pending clear ran keeps its waypoint
STUB.instance = { name = "Westfall", type = "none", id = 0 }
assert(NS.MapSetPoint({ map = 1436, x = 0.4, y = 0.5 }, "Wieder dort", "I:36"))
STUB.fire("PLAYER_ENTERING_WORLD")
assert(W.point and NS.MapTarget() and NS.MapTarget().ours, "the new target's waypoint stays")

-- combat: nothing; combat's end clears what waited
STUB.combat = true
assert(not Map.ClientSafe())
clears = W.clears
NS.MapClearTarget()
assert(W.clears == clears and W.point, "not in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
assert(W.point == nil and W.clears == clears + 1, "after combat")

-- the lockdown (boss fight): the same, its end clears
assert(NS.MapSetPoint({ map = 1436, x = 0.2, y = 0.2 }, "Boss", "Q:3"))
STUB.lockdown = true
local oldLocked = NS.ChatLocked
NS.ChatLocked = function() return true end
assert(not Map.ClientSafe())
clears = W.clears
NS.MapClearTarget()
assert(W.clears == clears and W.point, "not in the lockdown")
NS.ChatLocked = oldLocked
STUB.lockdown = nil
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
assert(W.point == nil and W.clears == clears + 1, "after the lockdown")

-- a dungeon quest clicked inside: Amisia's target, no map, no waypoint
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
sets = W.sets
WorldMapFrame:Hide()
NS.MapSetPoint({ map = 1436, x = 0.3, y = 0.3 }, "Questgeber", "Q:4")
assert(W.sets == sets and not WorldMapFrame:IsShown())
NS.MapClearTarget()
STUB.instance = { name = "Westfall", type = "none", id = 0 }
print("map client safe ok")
