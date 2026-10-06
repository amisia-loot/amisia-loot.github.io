-- The dungeon guide (Dungeons.lua): the ranking by value, the chain (equip the best dungeon's
-- upgrades virtually and rank again: its first step is the next dungeon, a dungeon whose upgrades
-- the chain already covers falls out, rings go against the weaker one), and the quest list per
-- dungeon from DungeonQuestData.lua and the item data (pre-quests from the root, one-of chains,
-- faction, start inside/outside/item, done and in the log, rewards with the upgrade mark, the quest
-- giver's waypoint, the fallback texts) and the commands.
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
        [99001] = { "Grudge of the Thanes", 14, 18, "A", 0, "O", "Thane Giver", "1436:5633:4752", { 99002 }, { 99003, 99004 }, "thanes" },
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

assert(g(521) > 0 and g(520) > 0, "both rings beat the rusty one")

---------------------------------------------------------------------------
-- the ranking
---------------------------------------------------------------------------
local list = NS.DungeonList()
local thanes, ruins, dm = find(list, "thanes"), find(list, "lordaeron"), find(list, "deadmines")
assert(thanes and ruins and dm and dm.fit == "fit", "three dungeons fit at 16")
-- the quests of the quest data count for the thanes' value: the gloves (99001) and the boots (99005)
assert(near(thanes.once, g(530) + g(532)), "the best reward of each open quest: " .. tostring(thanes.once))
assert(thanes.questUps == 2)
local rank = NS.DungeonRanking()
assert(rank[1] == thanes and rank[2] == ruins and rank[3] == dm, "by value")
assert(rank[1] == (NS.DungeonNext()), "the ranking's first is the next dungeon")
for i = 2, #rank do assert(rank[i - 1].value >= rank[i].value) end

---------------------------------------------------------------------------
-- the chain
---------------------------------------------------------------------------
local chain, why = NS.DungeonChain()
assert(chain[1].entry == thanes and near(chain[1].value, thanes.value), "step one is the next dungeon")
assert(chain[2].entry == dm, "after the thanes' helm and ring the ruins bring nothing: " .. tostring(chain[2] and chain[2].entry.key))
assert(near(chain[2].value, dm.value), "the mines' cloak is untouched by the thanes")
assert(#chain == 2 and why == "Danach hat kein Dungeon mehr Upgrades für dich.", tostring(why))
local equipped = {}
for _, id in ipairs(chain[1].items) do equipped[id] = true end
assert(equipped[501] and equipped[521] and equipped[530] and equipped[532] and not equipped[531], "helm, ring (one per boss), both quest rewards")
-- the ring: against the weaker of the two; a wrong slot would leave the baron's ring an upgrade
assert(NS.DungeonChain(nil, 1)[2] == nil, "steps limit the chain")
assert(NS.DungeonChain() == chain, "kept while nothing changes")

-- the virtual gear in detail
local v = NS.Dungeons.Virtual(NS.BisOpts())
assert(near(v.FINGER1, NS.BisWornScores(NS.BisOpts()).slot.FINGER1))
local s521 = g(521) + math.min(v.FINGER1, v.FINGER2)
assert(near(NS.Dungeons.VGain(v, "FINGER1", "FINGER", s521), g(521)), "the same gain as the planner before anything is equipped")
NS.Dungeons.VEquip(v, "FINGER1", "FINGER", s521)
assert(near(math.max(v.FINGER1, v.FINGER2), s521) and near(math.min(v.FINGER1, v.FINGER2), NS.BisWornScores(NS.BisOpts()).slot.FINGER1),
    "the weaker ring goes")
v.MAINHAND, v.OFFHAND, v.two = 10, 4, false
assert(near(NS.Dungeons.VGain(v, "MAINHAND", "2H", 20), 6), "a two-hander against main and off hand")
NS.Dungeons.VEquip(v, "MAINHAND", "2H", 20)
assert(v.two and NS.Dungeons.VGain(v, "OFFHAND", "SHIELD", 30) == nil and NS.Dungeons.VGain(v, "MAINHAND", "1H", 30) == nil,
    "with a two-hander one-handers are a weapon switch")

---------------------------------------------------------------------------
-- the quest list
---------------------------------------------------------------------------
STUB.questsActive[99005] = true
NS.BisBump()
local qs, status = NS.DungeonQuests("thanes")
assert(status == "ok" and #qs == 2, tostring(status) .. " " .. #qs)
local grudge, halls = byQid(qs, 99001), byQid(qs, 99005)
assert(grudge.title == "Grudge of the Thanes" and grudge.minLevel == 14 and grudge.level == 18 and grudge.start == "O")
assert(grudge.giver == "Thane Giver" and not grudge.done and not grudge.active)
assert(halls.active and halls.start == "I", "in the log, starts inside")
-- the chain from the root: the root, then the one-of choice of the own faction
assert(#grudge.chain == 2 and grudge.chain[1].qid == 99002 and grudge.chain[2].qid == 99004, "root first, no Horde detour")
assert(grudge.chain[2].one, "one of several")
-- rewards: the gloves an upgrade, the weak belt not
local r1, r2 = grudge.rewards[1], grudge.rewards[2]
assert(r1.id == 530 and r1.upgrade and near(r1.gain, g(530)), "the upgrade first")
assert(r2.id == 531 and not r2.upgrade, "the weak belt is listed without the mark")
assert(grudge.best.id == 530)
-- a done root: the one-of choice prefers a done quest
STUB.questsDone[99002], STUB.questsDone[99003] = true, true
STUB.fire("QUEST_TURNED_IN", 99002)
qs = NS.DungeonQuests("thanes")
grudge = byQid(qs, 99001)
assert(grudge.chain[1].done and grudge.chain[2].qid == 99004, "the Horde detour stays out even when flagged done")
STUB.questsDone[99001] = true
STUB.fire("QUEST_TURNED_IN", 99001)
qs = NS.DungeonQuests("thanes")
assert(qs[#qs].qid == 99001 and qs[#qs].done, "a done quest goes to the end")
assert(near(find(NS.DungeonList(), "thanes").once, g(532)), "a done quest no longer counts")
STUB.questsDone[99001], STUB.questsDone[99002], STUB.questsDone[99003] = nil, nil, nil
STUB.fire("QUEST_TURNED_IN", 99001)

-- the mines: started by an item; the ruins: no quest data; no data file at all
local mq, ms = NS.DungeonQuests("deadmines")
assert(ms == "ok" and mq[1].start == "X" and mq[1].giver == nil, tostring(ms) .. " " .. #mq .. " " .. tostring(mq[1] and mq[1].start))
assert(mq[1].rewards[1] and mq[1].rewards[1].id == 534 and mq[1].rewards[1].upgrade, "a reward only the quest data knows")
local rq, rs = NS.DungeonQuests("lordaeron")
assert(#rq == 0 and rs == "missing")
assert(NS.Dungeons.QuestStatusText(rs) == "Questdaten fehlen noch.")

---------------------------------------------------------------------------
-- the quest giver's waypoint
---------------------------------------------------------------------------
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
assert(NS.DungeonQuestWaypoint(99001), "the giver's point")
assert(STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1436 and NS.MapTarget().label == "Questgeber Thane Giver",
    NS.MapTarget() and NS.MapTarget().label)
assert(near(NS.MapTarget().x, 0.5633))
assert(NS.DungeonQuestWaypoint(99005) and NS.MapTarget().label == "Hall of Thanes (Eingang)", NS.MapTarget().label)
local ok, reason = NS.DungeonQuestWaypoint(99010)
assert(not ok and reason == "Diese Quest startet durch ein Item.", tostring(reason))
ok, reason = NS.DungeonQuestWaypoint(99003)
assert(not ok and reason == "Für diese Quest kennt Amisia keinen Startort.", tostring(reason))
NS.MapClearTarget()

---------------------------------------------------------------------------
-- the page: the sort chips, the chain on top, the quests part with its waypoint
---------------------------------------------------------------------------
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
NS.ShowGear("dungeons")
local f = NS.GearPageFrame()
local B = f.dungeons
B.sorts.value:Click()
assert(B.sorts.value.on and not B.sorts.level.on and AmisiaDB.settings.bis.dsort == "value")
assert(plain(B.list.rows[1].name:GetText()) == "1. Hall of Thanes" and plain(B.list.rows[2].name:GetText()) == "2. Ruins of Lordaeron",
    plain(B.list.rows[1].name:GetText()))
B.sorts.chain:Click()
assert(B.next:GetText() == "Kette: 1. Hall of Thanes · 2. The Deadmines", B.next:GetText())
assert(plain(B.list.rows[2].name:GetText()) == "2. The Deadmines", plain(B.list.rows[2].name:GetText()))
assert(B.list.rows[2].value:GetText() == tostring(math.floor(chain[2].value + 0.5)), "the chain's value")
assert(plain(B.list.rows[3].name:GetText()) == "Ruins of Lordaeron", "the rest without a place")
B.list.rows[1]:Click()
B.parts.quests:Click()
assert(B.header.ButtonText:GetText() == "Hall of Thanes · Quests")
local qrow
for _, r in ipairs(B.detail.rows) do if r.item and r.item.kind == "quest" and r.item.qid == 99001 then qrow = r end end
assert(qrow and plain(qrow.slot:GetText()) == "18 (ab 14)" and has(plain(qrow.rate:GetText()), "Thane Giver, Westfall 56, 48"),
    qrow and plain(qrow.rate:GetText()))
qrow:Click()
assert(NS.MapTarget() and NS.MapTarget().label == "Questgeber Thane Giver", "a click on a quest: its giver")
NS.MapClearTarget()
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
Lay.row("sorts", B.next, B.sorts.level, B.sorts.value, B.sorts.chain)
Lay.row("parts", B.header, B.parts.bosses, B.parts.quests, B.way)
B.sorts.level:Click()
B.parts.bosses:Click()

---------------------------------------------------------------------------
-- the commands
---------------------------------------------------------------------------
STUB.messages = {}
NS.Dispatch("dungeon kette")
local said = table.concat(STUB.messages, "\n")
assert(has(said, "Kette: 1. Hall of Thanes") and has(said, "2. The Deadmines"), said)
STUB.messages = {}
NS.Dispatch("dungeon quests thanes")
said = table.concat(STUB.messages, "\n")
assert(has(said, "Grudge of the Thanes") and has(said, "Vorquest") and has(said, "Root Quest"), said)
STUB.messages = {}
NS.Dispatch("dungeon quests lordaeron")
assert(has(table.concat(STUB.messages, "\n"), "Questdaten fehlen noch."), table.concat(STUB.messages, "\n"))
local lines = table.concat(NS.SlashHelpLines(false), "\n")
assert(has(lines, "/amisia dungeon [naechster|kette|quests <Dungeon>]"), lines)

---------------------------------------------------------------------------
-- without the quest data file: the item data's dungeon quests stay, the status says so
---------------------------------------------------------------------------
NS.DUNGEON_QUESTS = nil
NS.BisBump()
local nq, ns2 = NS.DungeonQuests("thanes")
assert(ns2 == "nodata" and #nq == 0, tostring(ns2))
assert(NS.Dungeons.QuestStatusText("nodata") == "Questdaten fehlen noch.")
NS.DUNGEON_QUESTS = realQuests
