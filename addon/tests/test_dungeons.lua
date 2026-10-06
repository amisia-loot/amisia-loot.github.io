-- The dungeon planner (Dungeons.lua): the facts (DungeonData.lua, or ns.BIS.DG once the build writes
-- it), the value per dungeon for the own character (upgrades from the bosses' drops with their
-- chance, open dungeon quests of the own faction), the level fit, the next dungeon and its reason,
-- no hit, raids from level 60 with rates only from observations, rates with and without the guild's
-- kills (the boss found by its name or by the instance its records share with the items), owned
-- and wished items, exclusions, the cache, the entrance waypoint and the command.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function find(list, key) for _, e in ipairs(list) do if e.key == key then return e end end end
local function boss(e, name) for _, b in ipairs(e and e.bosses or {}) do if b.name == name then return b end end end
local function item(b, id) for _, it in ipairs(b and b.items or {}) do if it.id == id then return it end end end
local function quest(e, title) for _, q in ipairs(e and e.quests or {}) do if q.title == title then return q end end end

assert(NS.DUNGEON_FACTS and #NS.DUNGEON_FACTS.list > 20, "the hand facts load")
local D = NS.Dungeons
assert(D and D.Facts() == NS.DUNGEON_FACTS.list, "without the build's DG the hand facts")

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
STUB.questsDone[96397] = true

---------------------------------------------------------------------------
-- a small data set around Hall of Thanes
---------------------------------------------------------------------------
NS.GEAR = { built = "test-dungeons", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },                                  -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },                                            -- 2
    { "Q", "An Ancient Grudge", 18, 15, "A", 1437, 96395, 0, "Hall of Thanes" },           -- 3
    { "Q", "Horde Task", 18, 15, "H", 1437, 96396, 0, "Hall of Thanes" },                  -- 4
    { "Q", "Done Already", 18, 15, nil, 1437, 96397, 0, "Hall of Thanes" },                -- 5
    { "D", "Ruins of Lordaeron", "The Baron", nil },                                       -- 6
    { "D", "The Deadmines", "Cookie", nil },                                               -- 7
    { "D", "Excavation Site: Wetlands", "Saltspine", nil },                                -- 8
    { "V", "Händler", 1437, nil, "Rüstungen" },                                             -- 9
} }
local function gear(id, name, loc, strength, level, sources, q)
    STUB.item(id, name, q or 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, loc == "FINGER" and 0 or 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    if sources then
        local row = { loc, 4, loc == "FINGER" and 0 or 2, level, q or 3, 1, 20, 0, 0, 0 }
        for _, n in ipairs(sources) do row[#row + 1] = n end
        NS.GEAR.I[id] = row
    end
end
gear(501, "Ambosshelm", "HEAD", 20, 16, { 1 })
gear(508, "Schwacher Helm", "HEAD", 5, 15, { 1 })
gear(502, "Magmabrust", "CHEST", 10, 17, { 2 })
gear(503, "Magmabeine", "LEGS", 8, 18, { 2 })
gear(504, "Ferne Stiefel", "FEET", 30, 19, { 2 })
gear(505, "Grollhandschuhe", "HAND", 12, 15, { 3, 9 })
gear(506, "Hordenarmschienen", "WRIST", 50, 15, { 4 })
gear(507, "Alter Gürtel", "WAIST", 9, 15, { 5 })
gear(509, "Baronsschultern", "SHOULDER", 10, 17, { 6 })
gear(511, "Kekshut", "HEAD", 25, 20, { 7 })
gear(512, "Salzgurt", "WAIST", 15, 28, { 8 })
gear(510, "Alter Helm", "HEAD", 10, 10)
-- seen by the guild only, not in the data
gear(530, "Thanenring", "FINGER", 6, 16)
gear(531, "Fremder Umhang", "CLOAK", 7, 16)
gear(520, "Onyxiahelm", "HEAD", 40, 60, nil, 4)
STUB.worn[1] = STUB.items[510].link
Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local function g(id) return (NS.BisGain(id)) end

---------------------------------------------------------------------------
-- the list at level 16
---------------------------------------------------------------------------
local list = NS.DungeonList()
local thanes, ruins = find(list, "thanes"), find(list, "lordaeron")
assert(thanes and ruins, "the two new dungeons of the level")
assert(thanes.name == "Hall of Thanes" and thanes.min == 13 and thanes.max == 18 and thanes.kind == "party" and not thanes.est)
assert(thanes.fit == "fit" and ruins.fit == "fit", thanes.fit .. "/" .. ruins.fit)
assert(thanes.upgrades == 3, "the helm, the chest and the legs; the boots wait for level 19: " .. thanes.upgrades)
local faldrim, magmatus = boss(thanes, "Faldrim Anvilmar"), boss(thanes, "Magmatus")
assert(faldrim and magmatus, "the bosses of the sources")
assert(near(item(faldrim, 501).p, 0.2) and item(faldrim, 501).upgrade, "the source's chance")
assert(item(faldrim, 508) == nil, "no upgrade, not listed")
assert(near(item(magmatus, 502).p, 1 / 3), "one of the boss's three known rare items: " .. tostring(item(magmatus, 502).p))
assert(item(magmatus, 504) == nil, "required level 19 is beyond the window")
local perRun = g(501) * 0.2 + (g(502) + g(503)) / 3
assert(near(thanes.perRun, perRun), thanes.perRun .. " ~= " .. perRun)
assert(near(magmatus.perRun, (g(502) + g(503)) / 3) and near(faldrim.perRun, g(501) * 0.2))
-- the dungeon's quests: open ones of the own faction count, a done one is listed as done
local grudge, done = quest(thanes, "An Ancient Grudge"), quest(thanes, "Done Already")
assert(grudge and grudge.qid == 96395 and not grudge.done and grudge.best.id == 505 and near(grudge.best.gain, g(505)))
assert(done and done.done, "the done quest is listed as done")
assert(quest(thanes, "Horde Task") == nil, "no quest of the other faction")
assert(near(thanes.once, g(505)), "once: the best reward of every open quest")
assert(near(thanes.value, thanes.once + 2 * thanes.perRun), "value: the quests and two runs")
assert(ruins.upgrades == 1 and near(ruins.perRun, g(509)), "the baron's only known item")
-- fits of the other entries
local exc, dm = find(list, "excavation"), find(list, "deadmines")
assert(exc.fit == "high" and exc.value == nil, "26-31 is too high, not computed")
assert(dm.est and dm.min == 20 and dm.max == 20 and dm.fit == "high", "the range from its items' levels")
assert(find(list, "drowned").fit == "high", "a dungeon without items keeps its fact range")
assert(find(list, "rfd") == nil, "a dungeon without a range and without items is left out")
assert(find(list, "onyxia") == nil and find(list, "barrow") == nil, "no raid below 60")
-- sorted by level
local last = 0
for _, e in ipairs(list) do
    assert(e.min >= last, "by level: " .. e.key)
    last = e.min
end

---------------------------------------------------------------------------
-- the next dungeon
---------------------------------------------------------------------------
local nextE, why = NS.DungeonNext()
assert(thanes.value > ruins.value, "the data makes the thanes worth more")
assert(nextE == thanes, "the highest value of the fitting ones")
assert(why == "Hall of Thanes: 3 Upgrades, 1 Quest mit Upgrade, Schwerpunkt Magmatus", why)
assert(nextE.why == "3 Upgrades, 1 Quest mit Upgrade, Schwerpunkt Magmatus", nextE.why)

-- fits at other levels
local function fitAt(level, key)
    STUB.level = level
    STUB.fire("PLAYER_LEVEL_UP")
    local e = find(NS.DungeonList(), key)
    return e and e.fit
end
assert(fitAt(12, "thanes") == "soon" and fitAt(12, "lordaeron") == "high")
assert(fitAt(14, "lordaeron") == "soon" and fitAt(10, "thanes") == "high")
assert(fitAt(20, "thanes") == "easy" and fitAt(20, "lordaeron") == "fit")
local at20 = NS.DungeonNext()
assert(at20 and at20.fit == "fit" and at20.key ~= "thanes", "an easy dungeon is no recommendation")

---------------------------------------------------------------------------
-- no hit, raids from 60
---------------------------------------------------------------------------
STUB.level = 60
STUB.fire("PLAYER_LEVEL_UP")
local none, text = NS.DungeonNext()
assert(none == nil and text == "Für dein Level hat kein Dungeon noch Upgrades für dich.", tostring(text))
list = NS.DungeonList()
local ony = find(list, "onyxia")
assert(ony and ony.kind == "raid" and ony.size == 40 and find(list, "barrow") and find(list, "hyjal"), "the raids at 60")
assert(ony.fit == "later" and ony.min == 60, "the raids open on the 9th of December")
assert(#ony.bosses == 0 and ony.perRun == 0, "no rate without an observation")
-- an observed kill: the boss appears with its item and the rate of the guild's kills
local today = NS.DropsToday()
NS.DropsLearnNames({ [10184] = "Onyxia" }, { [249] = { "raid", "Onyxias Hort" } })
assert(NS.DropsMerge({ h = "0e000001", npc = 10184, inst = 249, diff = 9, day = today, o = "aaaaaaaa", src = "G", it = { [520] = 1 } }) == "new")
ony = NS.DungeonInfo("onyxia")
local onyBoss = boss(ony, "Onyxia")
assert(onyBoss and onyBoss.npc == 10184 and item(onyBoss, 520), "the boss and its item from the record")
assert(near(item(onyBoss, 520).p, (NS.DropRate(10184, 520))) and has(item(onyBoss, 520).rate, "gesehen 1-mal in 1 Kills"),
    item(onyBoss, 520).rate)
assert(boss(NS.DungeonInfo("barrow"), "Onyxia") == nil, "a record goes to its own raid only")

---------------------------------------------------------------------------
-- the guild's kills at Hall of Thanes (instance 2834, its client name says nothing)
---------------------------------------------------------------------------
STUB.level = 16
STUB.fire("PLAYER_LEVEL_UP")
NS.DropsLearnNames({ [9001] = "Faldrim Anvilmar", [9002] = "Unbekannter Boss" }, { [2834] = { "party", "Halle der Thane" } })
local function kill(h, npc, items)
    assert(NS.DropsMerge({ h = h, npc = npc, inst = 2834, diff = 1, day = today, o = "aaaaaaaa", src = "G", it = items }) == "new")
end
kill("0f000001", 9001, { [501] = 1, [530] = 1 })
kill("0f000002", 9001, { [501] = 1 })
kill("0f000003", 9001, {})
kill("0f000004", 9001, {})
kill("0f000005", 9002, { [531] = 1 })
thanes = find(NS.DungeonList(), "thanes")
faldrim = boss(thanes, "Faldrim Anvilmar")
assert(faldrim.npc == 9001, "the boss by its name")
assert(near(item(faldrim, 501).p, (2 + 3 * 0.2) / (4 + 3)), "two of four kills with the source's chance: " .. item(faldrim, 501).p)
assert(item(faldrim, 501).rate == NS.DropRateText(9001, 501, 0.2) and item(faldrim, 501).K == 4 and item(faldrim, 501).n == 2)
-- expected chance without a source chance: one of the boss's three known rare items (501, 508, 530)
assert(item(faldrim, 530) and near(item(faldrim, 530).p, (NS.DropRate(9001, 530, 1 / 3))), "an item only the guild saw")
local other = boss(thanes, "Unbekannter Boss")
assert(other and other.npc == 9002 and item(other, 531), "a boss of the same instance, found through the shared items")
assert(boss(ruins, "Unbekannter Boss") == nil)

---------------------------------------------------------------------------
-- owned, wished, excluded
---------------------------------------------------------------------------
local before = thanes.upgrades
STUB.bags[0] = { 502 }
NS.BisScanBags()
thanes = find(NS.DungeonList(), "thanes")
local chest = item(boss(thanes, "Magmatus"), 502)
assert(chest and chest.owned == "bag" and not chest.upgrade and thanes.upgrades == before - 1, "an owned upgrade is listed, not counted")
STUB.bags[0] = nil
NS.BisScanBags()
assert(NS.WishAdd(508))
thanes = find(NS.DungeonList(), "thanes")
local weak = item(boss(thanes, "Faldrim Anvilmar"), 508)
assert(weak and weak.wished and not weak.upgrade and thanes.upgrades == before, "a wish is listed, not counted")
NS.WishRemove(508)
assert(NS.BisExclude("boss", "Magmatus"))
thanes = find(NS.DungeonList(), "thanes")
assert(item(boss(thanes, "Magmatus"), 502) == nil and item(boss(thanes, "Magmatus"), 503) == nil, "an excluded boss's items go")
NS.BisClearExcludes()
assert(NS.BisExclude("item", 501))
assert(item(boss(find(NS.DungeonList(), "thanes"), "Faldrim Anvilmar"), 501) == nil, "an excluded item goes")
NS.BisClearExcludes()

---------------------------------------------------------------------------
-- the cache, the info of a dungeon out of reach
---------------------------------------------------------------------------
local a = NS.DungeonList()
assert(NS.DungeonList() == a and NS.DungeonNext() == NS.DungeonNext(), "kept while nothing changes")
NS.BisBump()
assert(NS.DungeonList() ~= a, "made again after a change")
local info = NS.DungeonInfo("excavation")
assert(info and info.fit == "high" and info.value ~= nil, "computed out of reach")
assert(item(boss(info, "Saltspine"), 512), "with the items up to its upper end")
assert(NS.DungeonInfo("nosuch") == nil)

---------------------------------------------------------------------------
-- the build's facts win
---------------------------------------------------------------------------
NS.BIS = { DG = { { key = "thanes", name = "Hall of Thanes", kind = "party", min = 13, max = 18, inst = 2834, bosses = { 9001 } } } }
list = NS.DungeonList()
assert(#list == 1 and list[1].key == "thanes" and boss(list[1], "Faldrim Anvilmar").npc == 9001, "DG from the build")
NS.BIS = nil
assert(#NS.DungeonList() > 1, "the hand facts again")

---------------------------------------------------------------------------
-- the entrance
---------------------------------------------------------------------------
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
local ok, reason = NS.DungeonWaypoint("thanes")
assert(not ok and reason == "Für diesen Dungeon kennt Amisia keinen Eingang.", tostring(reason))
assert(NS.DungeonEntrance("thanes") == nil and NS.DungeonEntrance("deadmines"))
assert(NS.DungeonWaypoint("deadmines"), "the entrance of the map data")
assert(STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1436 and NS.MapTarget().label == "The Deadmines (Eingang)",
    NS.MapTarget() and NS.MapTarget().label)
NS.MapClearTarget()

---------------------------------------------------------------------------
-- the command
---------------------------------------------------------------------------
STUB.messages = {}
NS.Dispatch("dungeon naechster")
local said = table.concat(STUB.messages, "\n")
assert(has(said, "Nächster Dungeon (13-18): Hall of Thanes: ") and has(said, " Upgrades, 1 Quest mit Upgrade, Schwerpunkt "), said)
NS.Dispatch("dungeons")
assert(NS.CurrentPage() == "gear" and AmisiaDB.settings.bis.view == "dungeons", "the view of the gear page")
local lines = table.concat(NS.SlashHelpLines(false), "\n")
assert(has(lines, "/amisia dungeon [naechster]"), lines)

---------------------------------------------------------------------------
-- the trash group of a dungeon is never its focus
---------------------------------------------------------------------------
local S2, I2 = {}, {}
for i, rec in ipairs(NS.GEAR.S) do S2[i] = rec end
for id, row in pairs(NS.GEAR.I) do I2[id] = row end
S2[#S2 + 1] = { "D", "Ruins of Lordaeron", "Trash", "90%" }
NS.GEAR = { built = "test-dungeons-trash", Z = {}, I = I2, S = S2 }
gear(540, "Trashbrust", "CHEST", 40, 16, { #S2 })
Gear._reset()
NS.BisBump()
ruins = find(NS.DungeonList(), "lordaeron")
assert(boss(ruins, "Trash") and boss(ruins, "Trash").perRun > boss(ruins, "The Baron").perRun, "the trash brings more per run")
local nr, wr = NS.DungeonNext()
assert(nr == ruins, "the trash chest makes the ruins the next dungeon")
assert(has(wr, "Schwerpunkt The Baron") and not has(wr, "Trash"), wr)

---------------------------------------------------------------------------
-- without facts
---------------------------------------------------------------------------
local facts = NS.DUNGEON_FACTS
NS.DUNGEON_FACTS = nil
assert(#NS.DungeonList() == 0)
local n, w = NS.DungeonNext()
assert(n == nil and w == "Keine Dungeon-Daten.", tostring(w))
STUB.messages = {}
NS.Dispatch("dungeon naechster")
assert(STUB.messages[#STUB.messages]:find("Keine Dungeon-Daten.", 1, true))
NS.DUNGEON_FACTS = facts
assert(#NS.DungeonList() > 0)
