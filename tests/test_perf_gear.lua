-- The performance fixes of the gear and collector code keep every answer: a hover over an item that
-- is no gear builds no gear data (D-28) and still shows the place line on Shift; Gear.Best is kept
-- across ownership changes (bags, equipment, weapon skill-ups) and made again after talents,
-- settings, BiS changes, new stats or suffixes, with the same targets as a fresh calculation; a
-- weapon skill-up fires no PROF_CHANGED and no new quest state, a profession skill-up and a new
-- recipe do; the targets are not warmed in combat, after it they are; ns.LinkSuffix gives what the
-- field-by-field reading gave; DropsMigrate keeps an item table within the caps; a bag link noted
-- again is skipped, a note with a source still counts.
STUB.class, STUB.level, STUB.faction = "WARRIOR", 60, "Alliance"
STUB.talents = { 31, 20, 0 }
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(5)

---------------------------------------------------------------------------
-- No gear: nothing built, the place line on Shift as before
---------------------------------------------------------------------------
local tip = CreateFrame("GameTooltip", "PerfGearTip")
tip.AddLine = function() end
local ore = STUB.item(2772, "Eisenerz", 1)
STUB.items[2772].equipLoc, STUB.items[2772].classID = "", 7
STUB.showTooltip(tip, ore)
assert(NS.DataBuilt().GEAR == nil and NS.DataBuilt().GEAR_WEIGHTS == nil, "a hover over ore builds no gear data")
local lines = NS.BisTooltipLines(ore)
assert(type(lines) == "table" and #lines == 0, "no line for ore")
local mapLine = NS.MapTooltipLine
NS.MapTooltipLine = function(id) return id == 2772 and "Fundort: Testmine" or nil end
STUB.shift = true
lines = NS.BisTooltipLines(ore)
assert(#lines == 1 and lines[1][1] == "Fundort: Testmine", "the place line on Shift")
STUB.shift = false
NS.MapTooltipLine = mapLine
assert(NS.DataBuilt().GEAR == nil, "still nothing built")

---------------------------------------------------------------------------
-- Gear.Best kept across ownership changes, made again when a score input changes
---------------------------------------------------------------------------
local G = NS.Data("GEAR")
local Gear = NS.Gear
local ids = {}
for id, row in pairs(G.I) do
    if (row[1] == "HEAD" or row[1] == "CHEST" or row[1] == "LEGS") and (row[4] or 0) <= 60 then ids[#ids + 1] = id end
end
table.sort(ids)
assert(#ids > 20, "gear rows")
for i = 1, 20 do
    local id = ids[i]
    local row = G.I[id]
    STUB.item(id, "Gear " .. id, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. row[1], row[2], row[3], row[4]
    it.stats = { ITEM_MOD_STRENGTH_SHORT = 10 + i, ITEM_MOD_STAMINA_SHORT = 8 }
end
STUB.worn[1] = STUB.items[ids[1]].link

local function ser(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return type(v) == "number" and ("%.6f"):format(v) or tostring(v) end
    if depth > 4 then return "{...}" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1) end
    return "{" .. table.concat(out, ",") .. "}"
end

local calls = 0
local realBest = Gear.Best
Gear.Best = function(o) calls = calls + 1; return realBest(o) end
-- settle: every item loaded or given up, answers final
for _ = 1, 3 do
    NS.BisTargets()
    STUB.tick(20)
    NS.BisBump()
end
NS.BisTargets()
local function fresh()
    local kept = ser(NS.BisTargets())
    NS.BisBump()
    local again = ser(NS.BisTargets())
    return kept, again
end
local function step(label, change, wantBest)
    local stamp, before = NS.BisStamp(), calls
    change()
    local r = NS.BisTargets()
    assert(NS.BisStamp() ~= stamp or label == "weapon skill", label .. ": a new state")
    assert((calls - before == 1) == wantBest, ("%s: Gear.Best %d times"):format(label, calls - before))
    local kept, again = fresh()
    assert(kept == again, label .. ": the same targets as a fresh calculation")
    return r
end

STUB.skills = { { name = "Waffenfertigkeiten", header = true }, { name = "Schwerter", rank = 200, id = 43 },
    { name = "Schneiderei", rank = 150, id = 197 } }
STUB.fire("SKILL_LINES_CHANGED")
NS.BisTargets()

step("bags", function()
    STUB.bags[0] = { STUB.items[ids[2]].link, STUB.items[ids[3]].link }
    STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
end, false)
step("equipment", function()
    STUB.worn[1] = STUB.items[ids[4]].link
    STUB.fire("PLAYER_EQUIPMENT_CHANGED", 1); STUB.tick(0.1)
end, false)
-- a weapon skill-up: no new state at all
local stamp, before = NS.BisStamp(), calls
STUB.skills[2].rank = 201
STUB.fire("SKILL_LINES_CHANGED")
NS.BisTargets()
assert(NS.BisStamp() == stamp and calls == before, "a weapon skill-up changes nothing")
step("profession skill", function()
    STUB.skills[3].rank = 160
    STUB.fire("SKILL_LINES_CHANGED")
end, true)
step("talents", function()
    STUB.talents = { 0, 31, 20 }
    STUB.fire("CHARACTER_POINTS_CHANGED")
end, true)
step("setting", function() NS.Set("bis.sets", false) end, true)
step("setting back", function() NS.Set("bis.sets", true) end, true)
step("BiS change", function() NS.BisSetPlan("2H") end, true)
step("suffix noted", function()
    Gear.SuffixNoted(ids[5])
    STUB.fire("BAG_UPDATE_DELAYED"); STUB.bags[0] = { STUB.items[ids[6]].link }; STUB.tick(1.1)
end, true)
step("stats arrived", function()
    -- an item asked for now (a tooltip): its answer raises Gear.OnData
    Gear.Stats(99001)
    STUB.item(99001, "Neu", 3)
    STUB.items[99001].equipLoc, STUB.items[99001].classID, STUB.items[99001].stats = "INVTYPE_HEAD", 4, { ITEM_MOD_STRENGTH_SHORT = 4 }
    STUB.tick(5)
end, true)
step("bags again", function()
    STUB.bags[0] = {}
    STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1.1)
end, false)
Gear.Best = realBest

---------------------------------------------------------------------------
-- Not warmed in combat, after it
---------------------------------------------------------------------------
NS.Set("bis.tooltipNone", false)
STUB.combat = true
NS.BisBump()
assert(NS.BisTargetsCached() == nil)
NS.BisTooltipLines(STUB.worn[1])
STUB.tick(5)
assert(NS.BisTargetsCached() == nil, "no targets computed in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(5)
assert(NS.BisTargetsCached() ~= nil, "computed after the combat")

---------------------------------------------------------------------------
-- Skill lines: PROF_CHANGED and the quest state only on a real change
---------------------------------------------------------------------------
local prof, quests = 0, 0
NS.Listen("PROF_CHANGED", function() prof = prof + 1 end)
NS.Listen("QUESTS_CHANGED", function() quests = quests + 1 end)
local book = { rank = 45 }
GetProfessions = function() return 1 end
GetProfessionInfo = function(i)
    if i == 1 then return "Schmiedekunst", 136241, book.rank, 150, 3, 0, 164 end
end
STUB.fire("SKILL_LINES_CHANGED")
assert(prof == 1, "the first skill list is news")
prof, quests = 0, 0
STUB.skills[2].rank = 202
STUB.fire("SKILL_LINES_CHANGED")
assert(prof == 0 and quests == 0, "a weapon skill-up: no PROF_CHANGED, no new quest state")
book.rank = 46
STUB.fire("SKILL_LINES_CHANGED")
assert(prof == 1, "a profession skill-up fires")
STUB.skills[#STUB.skills + 1] = { name = "Kochkunst", rank = 1, id = 185 }
STUB.fire("SKILL_LINES_CHANGED")
assert(quests == 1, "a new skill line: a new quest state")
assert(NS.QuestOpts().skills[43] == 202, "the ranks stay current")

-- the profession window: a list update without news fires nothing, a new recipe does
local T = { recipes = { 2663, 3321 }, learned = { [2663] = true }, rank = 46 }
C_TradeSkillUI = {
    IsTradeSkillLinked = function() return false end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
    GetBaseProfessionInfo = function() return { professionID = 164, skillLevel = T.rank, maxSkillLevel = 150 } end,
    GetAllRecipeIDs = function() return T.recipes end,
    GetRecipeInfo = function(id) return { recipeID = id, learned = T.learned[id] == true } end,
}
prof = 0
STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
assert(prof == 1, "the first read")
STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
assert(prof == 1, "the same list again: nothing")
T.learned[3321] = true
STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
assert(prof == 2 and NS.Prof.Known(3321, 164), "a new recipe fires")
T.rank = 47
STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
assert(prof == 3, "a skill-up in the window fires")

---------------------------------------------------------------------------
-- ns.LinkSuffix: the same as reading field by field
---------------------------------------------------------------------------
local function oldSuffix(link)
    if type(link) ~= "string" then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local i = 0
    for field in (body .. ":"):gmatch("([^:]*):") do
        i = i + 1
        if i == 7 then
            local v = tonumber(field)
            return (v and v ~= 0) and v or nil
        end
    end
    return nil
end
local samples = { "|cff1eff00|Hitem:7001:0:0:0:0:0:-71:12345:60|h[Stiefel des Adlers]|h|r", "item:7001:0:0:0:0:0:15:0",
    "item:7001::::::::60", "item:7001", "item:7001::::::-1234:", "item:-5:1:2:3:4:5:6", "item::::::::",
    "|Hitem:1:2|h[x item:1:2:3:4:5:6:7]|h", "item:item:1:2:3:4:5:6:7", "item:1:2:3:4:5:6:--7", "item:1:2:3:4:5:6:7x",
    "|cffa335ee|Hitem:19019:2564:0:0:0:0:0:0:60:0:0:0:0|h[Donnerzorn]|h|r", "", "no link" }
math.randomseed(7)
local alpha = { "0", "1", "7", "-", ":", ":", ":", "x", "|", "item:", "-71", "12345", "" }
for _ = 1, 3000 do
    local parts = {}
    for k = 1, math.random(0, 20) do parts[k] = alpha[math.random(#alpha)] end
    samples[#samples + 1] = table.concat(parts)
end
for _, s in ipairs(samples) do
    assert(NS.LinkSuffix(s) == oldSuffix(s), "LinkSuffix " .. s)
end
assert(NS.LinkSuffix(nil) == nil)

---------------------------------------------------------------------------
-- DropsMigrate keeps an item table within the caps, caps one over them
---------------------------------------------------------------------------
local d = NS.DropsDB()
local today = NS.DropsToday()
local small = { [17001] = 1, [17002] = 3 }
local big = {}
for i = 1, 20 do big[17100 + i] = 30 end
d.k["0000aaaa"] = { npc = 11500, inst = 409, diff = 9, day = today, o = d.me, src = "G", it = small }
d.k["0000bbbb"] = { npc = 11501, inst = 409, diff = 9, day = today, o = d.me, src = "G", it = big }
NS.DropsMigrate(AmisiaDB)
assert(d.k["0000aaaa"].it == small and small[17002] == 3, "within the caps: the same table")
local capped = d.k["0000bbbb"].it
assert(capped ~= big, "over the caps: a new table")
local n = 0
for id, c in pairs(capped) do n = n + 1; assert(c == 20 and id <= 17116) end
assert(n == 16, "the 16 lowest ids, counts to 20")

---------------------------------------------------------------------------
-- The collector: a complete link noted again is skipped, a source still counts
---------------------------------------------------------------------------
NS.Set("tools.collect", true)
local herb = STUB.item(2447, "Friedensblume", 1)
STUB.items[2447].equipLoc, STUB.items[2447].classID = "", 7
assert(NS.NoteItem(herb) == true and NS.NoteItem(herb) == true, "stored, then known")
NS.NoteItem(herb, "Haendler: Testa [123] @Elwynn")
local src = AmisiaDB.scan.sources and AmisiaDB.scan.sources[2447]
assert(src and src[1] == "Haendler: Testa [123] @Elwynn", "a note with a source counts")
print("perf gear: no gear data for ore, Best kept across ownership, skill lines, suffix, drops, collector")
