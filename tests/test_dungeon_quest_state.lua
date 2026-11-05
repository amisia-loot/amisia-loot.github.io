-- Dungeon quest marks and where a click leads (F-134): Dungeons.QuestState (done, gone, ready, active,
-- locked by level or an open pre-quest, open) and its marks in the client's quest icons; a dungeon
-- quest in the log that is not complete leads to the dungeon's entrance, a complete one or one not
-- taken to its giver; "complete" from C_QuestLog.IsComplete, else the quest log's isComplete; with
-- open the world map shows the place.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local Dn = NS.Dungeons

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Westfall", type = "none", id = 0 }

---------------------------------------------------------------------------
-- the state
---------------------------------------------------------------------------
assert(Dn.QuestState({ qid = 1, done = true }) == "done")
assert(Dn.QuestState({ qid = 1, gone = true }) == "gone")
assert(Dn.QuestState({ qid = 1, minLevel = 20 }) == "locked", "the own level is too low")
assert(Dn.QuestState({ qid = 1, minLevel = 10, chain = { { done = true }, { done = false } } }) == "locked", "a pre-quest open")
assert(Dn.QuestState({ qid = 1, minLevel = 10, chain = { { done = true } } }) == "open")
assert(Dn.QuestState(nil) == "open")
STUB.questsActive[2] = true
assert(Dn.QuestState({ qid = 2, active = true }) == "active", "in the log, the client knows no IsComplete here")
STUB.questsReady = { [2] = true }
C_QuestLog.IsComplete = function(id) return STUB.questsReady[id] == true end
assert(Dn.QuestState({ qid = 2, active = true }) == "ready", "C_QuestLog.IsComplete")
-- without C_QuestLog.IsComplete: the quest log's isComplete (6th value)
C_QuestLog.IsComplete = nil
_G.GetQuestLogIndexByID = function(id) return id == 2 and 4 or 0 end
_G.GetQuestLogTitle = function(i) if i == 4 then return "T", 16, 0, false, false, 1, 0, 2 end end
assert(Dn.QuestState({ qid = 2, active = true }) == "ready", "the quest log's isComplete")
_G.GetQuestLogTitle = function(i) if i == 4 then return "T", 16, 0, false, false, nil, 0, 2 end end
assert(Dn.QuestState({ qid = 2, active = true }) == "active")
C_QuestLog.IsComplete = function(id) return STUB.questsReady[id] == true end

-- the marks: yellow "!" and "?", grey ones tinted, tick and cross
assert(has(Dn.QuestStateIcon("open"), "AvailableQuestIcon:14:14|t"))
assert(has(Dn.QuestStateIcon("locked"), "AvailableQuestIcon") and has(Dn.QuestStateIcon("locked"), ":110:110:110|t"))
assert(has(Dn.QuestStateIcon("ready"), "ActiveQuestIcon:14:14|t"))
assert(has(Dn.QuestStateIcon("active"), "ActiveQuestIcon") and has(Dn.QuestStateIcon("active"), ":110:110:110|t"))
assert(has(Dn.QuestStateIcon("done"), "ReadyCheck-Ready") and has(Dn.QuestStateIcon("gone"), "ReadyCheck-NotReady"))
assert(Dn.QuestStateIcon("nonsense") == "")

---------------------------------------------------------------------------
-- where a click leads
---------------------------------------------------------------------------
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 99030 } },
    Q = {
        [99030] = { "Outside Start", 15, 19, "", 0, "O", "Out Giver", "1436:3000:4000", nil, nil, "deadmines" },
        [99031] = { "A Pre-quest", 10, 12, "", 0, "O", "Pre Giver", "1436:1000:1000", nil, nil, nil },
    },
}
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
local entrance = NS.DungeonEntrance("deadmines")
assert(entrance, "the mines have an entrance in the map data")
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- not taken: the giver, the world map on its zone
WorldMapFrame:Hide()
assert(NS.DungeonQuestWaypoint(99030, true))
assert(NS.MapTarget().label == "Questgeber Out Giver" and near(NS.MapTarget().x, 0.3), NS.MapTarget().label)
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1436, "the map opens")
WorldMapFrame:Hide()
-- in the log, not complete: the entrance (its map key, so the pin gets the dungeon mark)
STUB.questsActive[99030] = true
assert(NS.DungeonQuestWaypoint(99030, true))
local t = NS.MapTarget()
assert(t.label == "The Deadmines (Eingang)" and t.map == entrance.map and near(t.x, entrance.x) and near(t.y, entrance.y), t.label)
assert(type(t.key) == "string" and (t.key:sub(1, 2) == "I:" or t.key:sub(1, 2) == "N:"), tostring(t.key))
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == entrance.map, "the map opens on the entrance")
WorldMapFrame:Hide()
-- complete: back to the giver
STUB.questsReady[99030] = true
assert(NS.DungeonQuestWaypoint(99030))
assert(NS.MapTarget().label == "Questgeber Out Giver", NS.MapTarget().label)
assert(not WorldMapFrame:IsShown(), "without open the map stays shut")
-- a pre-quest in the log has no dungeon: its giver
STUB.questsActive[99031] = true
assert(NS.DungeonQuestWaypoint(99031, true) and NS.MapTarget().label == "Questgeber Pre Giver", NS.MapTarget().label)
WorldMapFrame:Hide()
-- in combat the map stays shut, the waypoint is set
STUB.inCombat = true
local old = _G.InCombatLockdown
_G.InCombatLockdown = function() return true end
assert(NS.DungeonQuestWaypoint(99031, true))
assert(not WorldMapFrame:IsShown(), "no map in combat")
_G.InCombatLockdown = old
STUB.inCombat = nil
NS.MapClearTarget()
print("dungeon quest state ok")
