-- Review 27, the dungeon planner: the quests that exclude a quest (DungeonQuestData.lua's 13th field,
-- ATT's altQuests) are no "one of these first" pre-quests; one of them done, the quest is no longer
-- possible: marked, out of the value, the open XP and the givers on the map.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function find(list, key) for _, e in ipairs(list) do if e.key == key then return e end end end
local function byQid(list, qid) for _, q in ipairs(list or {}) do if q.qid == qid then return q end end end

assert(NS.DUNGEON_QUESTS and NS.DUNGEON_QUESTS.D.deadmines, "the generated quest data loads")
local realQuests = NS.DUNGEON_QUESTS

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }

---------------------------------------------------------------------------
-- three dungeons: the thanes and the ruins both bring a helm and a ring, the mines a cloak
---------------------------------------------------------------------------
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { thanes = { 99001, 99005 }, deadmines = { 99010 } },
    Q = {
        [99001] = { "Grudge of the Thanes", 14, 18, "A", 0, "O", "Thane Giver", "1436:5633:4752", { 99002 }, { 99003, 99004 }, "thanes",
            nil, { 99006 } },
        [99006] = { "Peace with the Thanes", 14, 18, "A", 0, "O", "Thane Giver", "1436:5633:4752", nil, nil, nil, nil, { 99001 } },
        [99002] = { "Root Quest", 10, 12, "A", 0, "O", "Root Giver", "1436:1000:1000", nil, nil, nil },
        [99003] = { "Horde Detour", 10, 12, "H", 0, "O", "Horde Giver", "1454:5000:5000", nil, nil, nil },
        [99004] = { "Alliance Detour", 10, 12, "A", 0, "O", "Detour Giver", "1436:2000:2000", nil, { 99002 }, nil },
        [99005] = { "Inside the Halls", 15, 17, "", 0, "I", "Halls Giver", "1436:4250:7170", nil, nil, "thanes" },
        [99010] = { "Found Note", 15, 19, "", 0, "X", nil, nil, nil, nil, "deadmines", { 534 } },
    },
}

NS.GEAR = { built = "test-guide", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "50%" },          -- 1
    { "D", "Ruins of Lordaeron", "The Baron", "50%" },             -- 2
    { "D", "The Deadmines", "Cookie", "50%" },                     -- 3
    { "Q", "Grudge of the Thanes", 18, 14, "A", 1436, 99001, 0 },   -- 4 (a quest of the item data without its dungeon)
    { "Q", "Inside the Halls", 17, 15, nil, 1436, 99005, 0 },       -- 5
    { "D", "Hall of Thanes", "Magmatus", "50%" },                  -- 6
} }
local function gear(id, name, loc, strength, level, sources)
    STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, loc == "FINGER" and 0 or 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    if sources then
        local row = { loc, 4, loc == "FINGER" and 0 or 2, level, 3, 1, 20, 0, 0, 0 }
        for _, n in ipairs(sources) do row[#row + 1] = n end
        NS.GEAR.I[id] = row
    end
end
gear(501, "Thanenhelm", "HEAD", 30, 16, { 1 })
gear(521, "Thanenring", "FINGER", 6, 16, { 6 })
gear(509, "Baronshelm", "HEAD", 28, 16, { 2 })
gear(520, "Baronsring", "FINGER", 4, 16, { 2 })
gear(511, "Keksumhang", "CLOAK", 8, 16, { 3 })
gear(530, "Grollhandschuhe", "HAND", 12, 15, { 4 })
gear(531, "Schwacher Gürtel", "WAIST", 1, 15, { 4 })
gear(532, "Hallenstiefel", "FEET", 9, 15, { 5 })
gear(510, "Alter Helm", "HEAD", 10, 10)
gear(512, "Alter Ring", "FINGER", 5, 10)
gear(513, "Rostring", "FINGER", 2, 10)
gear(514, "Alter Gürtel", "WAIST", 5, 10)
gear(534, "Notizschultern", "SHOULDER", 7, 15)   -- only the quest data names it
STUB.worn[1] = STUB.items[510].link
STUB.worn[11] = STUB.items[512].link
STUB.worn[12] = STUB.items[513].link
STUB.worn[6] = STUB.items[514].link
Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local function g(id) return (NS.BisGain(id)) end


local qs = NS.DungeonQuests("thanes")
local grudge = byQid(qs, 99001)
assert(grudge and not grudge.gone and not grudge.done, "open while the other way is not taken")
assert(#grudge.chain == 2 and grudge.chain[1].qid == 99002 and grudge.chain[2].qid == 99004, "the one-of list stays as it was")
local thanes = find(NS.DungeonList(), "thanes")
assert(thanes.questUps == 2, "both quests count: " .. thanes.questUps)

STUB.questsDone[99006] = true
STUB.fire("QUEST_TURNED_IN", 99006)
qs = NS.DungeonQuests("thanes")
grudge = byQid(qs, 99001)
assert(grudge.gone and not grudge.done, "the other way is done: no longer possible")
assert(qs[#qs] == grudge, "listed last, after the open ones")
thanes = find(NS.DungeonList(), "thanes")
assert(thanes.questUps == 1 and near(thanes.once, g(532)), "its reward no longer counts: " .. thanes.questUps)
local sum = NS.Dungeons.XPSum(qs)
local open = 0
for _, q in ipairs(qs) do if not q.gone and not q.done then open = open + 1 end end
assert(sum.missing + (sum.total > 0 and 1 or 0) <= open, "the gone quest adds no open XP")
STUB.messages = {}
NS.Dispatch("dungeon quests thanes")
local said = table.concat(STUB.messages, "\n")
assert(has(said, "[nicht mehr möglich] Grudge of the Thanes"), said)
print("review 27 dungeons: exclusions")
