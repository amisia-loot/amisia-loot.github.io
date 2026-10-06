-- Review of the dungeon planner (2.3): the expected chance of an item whose source names none is a
-- conservative share of a typical loot table and reads "Chance unbekannt"; an NPC the guild's records
-- know only from a few kills is listed but not counted; NPCs of an instance that hosts several
-- dungeons (Blackrock Spire) go to the dungeon whose data lists them, else nowhere; names learned
-- without a change of the records still reach the planner.
local Gear = NS.Gear
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function find(list, key) for _, e in ipairs(list) do if e.key == key then return e end end end
local function boss(e, name) for _, b in ipairs(e and e.bosses or {}) do if b.name == name then return b end end end
local function bossNpc(e, npc) for _, b in ipairs(e and e.bosses or {}) do if b.npc == npc then return b end end end
local function item(b, id) for _, it in ipairs(b and b.items or {}) do if it.id == id then return it end end end

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }

NS.GEAR = { built = "test-dungeons-review", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },              -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },                        -- 2
    { "D", "Ruins of Lordaeron", "The Baron", nil },                   -- 3
    { "D", "Lower Blackrock Spire", "Highlord Omokk", nil },           -- 4
    { "D", "Upper Blackrock Spire", "General Drakkisath", nil },       -- 5
    { "D", "Blackrock Spire", "War Master Voone", nil },               -- 6
} }
local function gear(id, name, loc, strength, level, sources, q)
    STUB.item(id, name, q or 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    if sources then
        local row = { loc, 4, 2, level, q or 3, 1, 20, 0, 0, 0 }
        for _, n in ipairs(sources) do row[#row + 1] = n end
        NS.GEAR.I[id] = row
    end
end
gear(501, "Ambosshelm", "HEAD", 20, 16, { 1 })
gear(502, "Magmabrust", "CHEST", 10, 17, { 2 })
gear(503, "Magmabeine", "LEGS", 8, 18, { 2 })
gear(504, "Magmastiefel", "FEET", 8, 18, { 2 })
gear(509, "Baronsschultern", "SHOULDER", 10, 17, { 3 })
gear(531, "Fremder Umhang", "CLOAK", 40, 16)
gear(532, "Ghulhandschuhe", "HAND", 40, 16)
gear(601, "Omokks Gürtel", "WAIST", 30, 55, { 4 })
gear(602, "Drakkisaths Brust", "CHEST", 60, 58, { 5 })
gear(603, "Voones Stiefel", "FEET", 30, 55, { 6 })
gear(604, "Spinnenumhang", "CLOAK", 30, 55)
Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local g = function(id) return (NS.BisGain(id)) end
local today = NS.DropsToday()
local seq = 0
local function kill(npc, inst, items)
    seq = seq + 1
    assert(NS.DropsMerge({ h = ("0d%06x"):format(seq), npc = npc, inst = inst, diff = 1, day = today, o = "aaaaaaaa", src = "G", it = items }) == "new")
end

---------------------------------------------------------------------------
-- 1. the expected chance without a source chance
---------------------------------------------------------------------------
local list = NS.DungeonList()
local thanes, ruins = find(list, "thanes"), find(list, "lordaeron")
-- the source's own chance stays as it is
local helm = item(boss(thanes, "Faldrim Anvilmar"), 501)
assert(near(helm.p, 0.2) and helm.rate == "Chance 20 %", tostring(helm.rate))
-- the baron's only known rare item: one of a typical table of six rare items, not every kill
local shoulders = item(boss(ruins, "The Baron"), 509)
assert(shoulders.p and shoulders.p <= 1 / 6 + 1e-9, "no 100 % for the only known item: " .. tostring(shoulders.p))
assert(shoulders.rate == "Chance unbekannt", "no made-up percent: " .. tostring(shoulders.rate))
assert(near(ruins.perRun, g(509) / 6), "the value takes the conservative share: " .. ruins.perRun)
-- three known rare items of a boss still count as one of six
local chest = item(boss(thanes, "Magmatus"), 502)
assert(near(chest.p, 1 / 6) and chest.rate == "Chance unbekannt", tostring(chest.p))
for _, f in ipairs(NS.DUNGEON_FACTS.list) do
    local e = NS.DungeonInfo(f.key)
    for _, b in ipairs(e and e.bosses or {}) do
        for _, it in ipairs(b.items) do
            assert(not it.p or it.p <= 0.5 or (it.rec and it.rec[4]), "never above one half without a source chance: " .. it.id)
        end
    end
end

---------------------------------------------------------------------------
-- 1b. an NPC known only from the guild's records counts from three kills
---------------------------------------------------------------------------
local nextBefore, whyBefore = NS.DungeonNext()
local upsBefore, runBefore = ruins.upgrades, ruins.perRun
NS.DropsLearnNames({ [7777] = "Lordaeron Ghoul" }, { [3001] = { "party", "Ruins of Lordaeron" } })
kill(7777, 3001, { [531] = 1 })
ruins = find(NS.DungeonList(), "lordaeron")
local ghoul = boss(ruins, "Lordaeron Ghoul")
assert(ghoul and item(ghoul, 531), "the NPC and its item are shown")
assert(ghoul.tentative and ghoul.kills == 1, "marked as not counted yet")
assert(ghoul.perRun == 0 and ruins.upgrades == upsBefore and near(ruins.perRun, runBefore),
    "one kill of a trash mob does not count: " .. ruins.upgrades .. " " .. ruins.perRun)
local nextAfter, whyAfter = NS.DungeonNext()
assert(nextAfter == nil and nextBefore == nil or (nextAfter.key == nextBefore.key and whyAfter == whyBefore),
    "the recommendation does not move: " .. tostring(whyAfter))
kill(7777, 3001, {})
assert(boss(find(NS.DungeonList(), "lordaeron"), "Lordaeron Ghoul").tentative, "two kills: still not counted")
kill(7777, 3001, { [531] = 1 })
ruins = find(NS.DungeonList(), "lordaeron")
ghoul = boss(ruins, "Lordaeron Ghoul")
assert(not ghoul.tentative and ghoul.perRun > 0 and ruins.upgrades == upsBefore + 1, "from three kills it counts")
-- a boss of the item data counts from its first kill
kill(7778, 3001, { [532] = 1 })
NS.DropsLearnNames({ [7778] = "The Baron" })
kill(7778, 3001, {})
local baron = boss(find(NS.DungeonList(), "lordaeron"), "The Baron")
assert(baron and baron.npc == 7778 and not baron.tentative and item(baron, 532) and item(baron, 532).p, "a known boss counts")

---------------------------------------------------------------------------
-- (B) names learned without a change of the records
---------------------------------------------------------------------------
kill(9300, 2834, { [501] = 1 })               -- an NPC whose items say Hall of Thanes
kill(9301, 2834, { [532] = 1 })               -- a nameless NPC of the same instance
thanes = NS.DungeonInfo("thanes")
assert(bossNpc(thanes, 9301) and bossNpc(thanes, 9301).name == "Boss 9301", "nameless first")
local gen = 0
NS.Listen("DROPS_CHANGED", function() gen = gen + 1 end)
NS.DropsLearnNames({ [9301] = "Magmatus" })
thanes = NS.DungeonInfo("thanes")
local magmatus = boss(thanes, "Magmatus")
assert(magmatus and magmatus.npc == 9301 and item(magmatus, 532), "the learned name joins the NPC to its boss")
assert(boss(thanes, "Boss 9301") == nil, "no stale nameless boss (" .. gen .. " change events)")
assert(boss(find(NS.DungeonList(), "thanes"), "Boss 9301") == nil, "the list too")
-- an instance whose name comes later
kill(9302, 3100, { [531] = 1 })
assert(bossNpc(NS.DungeonInfo("thanes"), 9302) == nil, "an unknown instance stays apart")
NS.DropsLearnNames({ [9302] = "Plunder" }, { [3100] = { "party", "Hall of Thanes" } })
assert(boss(NS.DungeonInfo("thanes"), "Plunder") and boss(NS.DungeonInfo("thanes"), "Plunder").npc == 9302,
    "the instance's learned name places the NPC")

---------------------------------------------------------------------------
-- 2. one instance, two dungeons: Blackrock Spire
---------------------------------------------------------------------------
STUB.level = 60
STUB.fire("PLAYER_LEVEL_UP")
NS.DropsLearnNames({ [10363] = "General Drakkisath", [9101] = "Highlord Omokk", [9102] = "Spire Spider" },
    { [229] = { "party", "Blackrock Spire" } })
for _ = 1, 3 do kill(10363, 229, { [602] = 1 }) end
kill(9101, 229, { [601] = 1 })
kill(9103, 229, { [603] = 1 })                -- nameless, with War Master Voone's boots
for _ = 1, 3 do kill(9102, 229, { [604] = 1 }) end -- neither half lists it
local lbrs, ubrs = NS.DungeonInfo("lbrs"), NS.DungeonInfo("ubrs")
assert(bossNpc(ubrs, 10363) and bossNpc(ubrs, 10363).name == "General Drakkisath", "Drakkisath stands in the upper spire")
assert(bossNpc(lbrs, 10363) == nil and boss(lbrs, "General Drakkisath") == nil, "not in the lower spire")
assert(bossNpc(lbrs, 9101) and bossNpc(lbrs, 9101).name == "Highlord Omokk" and bossNpc(ubrs, 9101) == nil, "Omokk below")
assert(bossNpc(lbrs, 9103) and bossNpc(ubrs, 9103) == nil, "by the half whose items it dropped")
assert(bossNpc(lbrs, 9102) == nil and bossNpc(ubrs, 9102) == nil, "an NPC of neither half stays unassigned")

-- the same for any instance the facts give several dungeons
NS.BIS = { DG = {
    { key = "wa", name = "Wing A", kind = "party", min = 30, max = 40, inst = 500, bosses = { "Alpha" } },
    { key = "wb", name = "Wing B", kind = "party", min = 30, max = 40, inst = 500, bosses = { "Beta" } },
} }
NS.DropsLearnNames({ [9401] = "Beta", [9402] = "Gamma" })
kill(9401, 500, { [531] = 1 })
kill(9402, 500, { [532] = 1 })
local wa, wb = NS.DungeonInfo("wa"), NS.DungeonInfo("wb")
assert(bossNpc(wb, 9401) and bossNpc(wa, 9401) == nil, "Beta goes to the wing that lists it")
assert(bossNpc(wa, 9402) == nil and bossNpc(wb, 9402) == nil, "Gamma to neither")
NS.BIS = nil
