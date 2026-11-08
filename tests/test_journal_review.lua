-- Review of the journal (D-72): a raid's run lasts while its raid ID does (not 30 minutes); a dungeon
-- asked for (ShowDungeon, ShowRaid) wins over the jump to the instance stood in; the raids' start
-- shows no tab of the detail; "Lauf planen" works on every tab; a key's later steps are locked while
-- an earlier one is open; the floors learned inside (Forever's tables list none), kept and checked.
local R = NS.Runs
local clock = 2000000
local keepTime = time
time = function() return clock end
local function factOf(key)
    for _, e in ipairs(NS.DUNGEON_FACTS.list) do if e.key == key then return e end end
end
local ony, thanes = factOf("onyxia"), factOf("thanes")
local keep = { oenc = ony.enc, tenc = thanes.enc, tkeys = thanes.keys, tmaps = thanes.maps }
ony.enc = { 1084 }
thanes.enc = { 3001, 3002, 3003, 3004 }

-- a raid: the kill stays after an hour outside while the raid ID holds; after it ran out a fresh run
local me = NS.UnitFullName("player")
local keepID = NS.RaidIDOf
local lockUntil = clock + 3 * 86400
NS.RaidIDOf = function(name, inst)
    if name == me and inst == ony.inst and clock < lockUntil then return "locked", { m = inst, r = lockUntil } end
    return "free"
end
STUB.instance = { name = "Onyxia's Lair", type = "raid", id = ony.inst }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
assert(select(2, R.Of("onyxia")) == 1)
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
clock = clock + 3600
STUB.instance = { name = "Onyxia's Lair", type = "raid", id = ony.inst }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(select(2, R.Of("onyxia")) == 1, "an hour later: the raid ID keeps the kill")
assert(NS.BisChar().run.reset == lockUntil)
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
clock = lockUntil + 60
STUB.instance = { name = "Onyxia's Lair", type = "raid", id = ony.inst }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(select(2, R.Of("onyxia")) == 0, "the raid ID ran out: a fresh run")
NS.RaidIDOf = keepID

-- standing in the thanes, a dungeon asked for wins over the jump
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("PLAYER_ENTERING_WORLD")
NS.ShowDungeon("rfc")
local B = NS.PageFrame("dungeons")
assert(B.chosen == "rfc" and B.art:IsShown(), "the asked one: " .. tostring(B.chosen))
NS.Refresh()
assert(B.chosen == "rfc", "and it stays")
-- "Lauf planen" opens the planner from the tab Karte too
B.parts.map:Click()
B.plan:Click()
assert(B.pathView:IsShown() and B.pathFor and B.pathFor.key == "run", "the run planner from Karte")
B.pathFor = nil
B.parts.bosses:Click()

-- the raids: the start shows none of the detail's tabs, also with a key
ony.keys = { { item = 16309, need = "required", why = "attune" } }
NS.ShowRaid("onyxia")
local P = NS.PageFrame("raidjournal")
assert(P.parts.access:IsShown(), "Zugang in the detail")
P.back:Click()
for k, tab in pairs(P.parts) do assert(not tab:IsShown(), "no tab on the start: " .. k) end
assert(P.table:IsShown())
ony.keys = nil

-- a key's steps: a later one is locked while an earlier one is open
local D = NS.Dungeons
local keepNode = D.QuestNode
D.QuestNode = function(qid) return { qid = qid, title = "Q" .. qid, done = qid == 1, minLevel = 1, chain = {} } end
thanes.keys = { { item = 7146, need = "optional", why = "part", quests = { 1, 2, 3 } } }
NS.ShowDungeon("thanes")
B.parts.access:Click()
local A = B.accessView
assert(A.items[2].state == "done" and A.items[3].state == "open" and A.items[4].state == "locked",
    A.items[2].state .. " " .. A.items[3].state .. " " .. A.items[4].state)
D.QuestNode = keepNode
thanes.keys = nil
B.parts.bosses:Click()

-- the floors: learned inside from the client's map and its group, kept, checked on load
local M = C_Map
local keepM = { M.GetBestMapForUnit, M.GetMapGroupID, M.GetMapGroupMembersInfo }
M.GetBestMapForUnit = function() return 8002 end
M.GetMapGroupID = function(id) return id == 8002 and 77 or nil end
M.GetMapGroupMembersInfo = function(g)
    if g == 77 then return { { mapID = 8002, relativeHeightIndex = 1 }, { mapID = 8001, relativeHeightIndex = 2 } } end
end
thanes.maps = nil
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("PLAYER_ENTERING_WORLD")
local floors = R.Floors(3065)
assert(floors and floors[1] == 8001 and floors[2] == 8002, "the top floor first: " .. table.concat(floors or {}, ","))
assert(#NS.JournalParts.Floors("thanes") == 2, "the map part takes the learned floors")
AmisiaDB.floors[3065] = { 8001, "x" }
AmisiaDB.floors.bad = { 1 }
R.Migrate(AmisiaDB)
assert(AmisiaDB.floors[3065] == nil and AmisiaDB.floors.bad == nil, "bad floors dropped on load")
M.GetBestMapForUnit, M.GetMapGroupID, M.GetMapGroupMembersInfo = keepM[1], keepM[2], keepM[3]
-- nothing learned: the map says how to learn it
NS.ShowDungeon("thanes")
B.parts.map:Click()
assert(B.mapView.none:IsShown() and B.mapView.none:GetText():find("Betritt sie einmal", 1, true), B.mapView.none:GetText())
B.parts.bosses:Click()

ony.enc, thanes.enc, thanes.keys, thanes.maps = keep.oenc, keep.tenc, keep.tkeys, keep.tmaps
time = keepTime
print("journal review ok")
