-- The run planner of the dungeon journal (F-139, Gear/Dungeons.lua and UI/Pages/Dungeons.lua): the
-- grey level of a quest, a quest's worth ("Muss", "Lohnt", "Kann weg", "Später"), the bosses in the
-- game's order (DungeonData.lua) with the quests there, the stops before the run by zone (the own zone
-- first) and the route button that walks them, the turn-ins after the run, the run's XP in the image,
-- the level window, "statt <worn item>" and "beste Wahl" on the reward tiles, and the done steps at
-- the path's start folded to one line.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local realQuests = NS.DUNGEON_QUESTS
local Dn = NS.Dungeons

---------------------------------------------------------------------------
-- the grey level (the game's zero difference)
---------------------------------------------------------------------------
-- grey once the own level is more than the zero difference of the own level above the quest
-- grey once the own level is more than its green range above the quest (the creatures' grey level)
assert(Dn.GreyAt(18) == 25, tostring(Dn.GreyAt(18)))   -- 25 - 18 = 7 > 4 + 2; at 24: 6, not more
assert(Dn.GreyAt(5) == 11, tostring(Dn.GreyAt(5)))     -- 11 - 5 = 6 > 4 + 1
assert(Dn.GreyAt(55) == 64, tostring(Dn.GreyAt(55)))   -- 64 - 55 = 9 > 8
assert(Dn.GreyAt(42) == 53, tostring(Dn.GreyAt(42)))   -- 53 - 42 = 11 > floor(53 / 5); at 52: 10, not more
-- the client's own green range counts for the own level
STUB.level = 25
_G.GetQuestGreenRange = function() return 7 end
assert(Dn.GreyAt(18) == 26, "at 25 the client says 7: not grey yet")
_G.GetQuestGreenRange = nil
STUB.level = nil
-- a boss in objective text: whole words, or a long name without spaces; no short name inside a word
assert(Dn.NamesBoss("Bring the head of Edwin van Cleef.", "Edwin VanCleef"))
assert(Dn.NamesBoss("Kill Plunder and his crew.", "Plunder") and not Dn.NamesBoss("Return the plundered gold.", "Plunder"))
assert(not Dn.NamesBoss("Collect a skull.", "Skul") and not Dn.NamesBoss(nil, "Sneed"))
assert(Dn.GreyAt(0) == nil and Dn.GreyAt(nil) == nil)

---------------------------------------------------------------------------
-- the data: a chain with two done steps, a quest started by VanCleef's loot, one in Stormwind, one too high
---------------------------------------------------------------------------
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.xp = { 1000, 10000 }
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.maps[1453] = { name = "Sturmwind", mapType = 3 }
STUB.place.map = 1453
NS.Map._reset()
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 600, 610, 620, 630 } },
    Q = {
        [600] = { "Brotherhood", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", { 602 }, nil, "deadmines", { 9920, 9921 }, nil,
                  nil, nil, nil, 0, 0, "Gryan", "1436:5630:4760", "Bring the head of Edwin van Cleef." },
        [601] = { "Root", 10, 12, "A", 0, "O", "Root Giver", "1436:1000:1000" },
        [602] = { "Middle", 12, 14, "A", 0, "O", "Middle Giver", "1436:2000:2000", { 601 } },
        [610] = { "Unsent Letter", 16, 22, "A", 0, "X", nil, nil, nil, nil, "deadmines", nil, nil, nil,
                  { { 9930, "Edwin VanCleef", 291, "deadmines" } }, nil, 0, 0, "Baros", "1453:3000:3000" },
        [620] = { "Underground", 15, 20, "A", 0, "O", "Shoni", "1453:6280:3480", nil, nil, "deadmines", nil, nil,
                  nil, nil, nil, 0, 0, "Shoni", "1453:6280:3480", "Collect 12 gnoam sprockets." },
        [630] = { "Too High", 30, 32, "A", 0, "O", "Far Giver", "1436:4000:4000", nil, nil, "deadmines" },
    },
}
STUB.item(9920, "Westfall Vest", 2)
local it = STUB.items[9920]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_CHEST", 4, 2, 14
it.stats = { ITEM_MOD_STRENGTH_SHORT = 12 }
STUB.item(9921, "Westfall Cloak", 2)
it = STUB.items[9921]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_CLOAK", 4, 1, 14
it.stats = { ITEM_MOD_STRENGTH_SHORT = 3 }
STUB.worn[5] = STUB.item(9940, "Old Shirt", 1)
STUB.items[9940].equipLoc, STUB.items[9940].classID = "INVTYPE_CHEST", 4
NS.GEAR = { built = "test-run-plan", Z = {}, I = {}, S = {} }
NS.Gear._reset()
STUB.questsDone[601], STUB.questsDone[602] = true, true
AmisiaDB.questxp = { [600] = { 2000, 16 }, [620] = { 300, 16 } }
NS.BisBump()

---------------------------------------------------------------------------
-- worth and plan (the data side)
---------------------------------------------------------------------------
local list = NS.DungeonQuests("deadmines")
local byId = {}
for _, q in ipairs(list) do byId[q.qid] = q end
assert(byId[600] and byId[610] and byId[620] and byId[630], "four quests")
local function pathOf(q) return Dn.QuestPath(q, "deadmines") end
local w600 = Dn.QuestWorth(byId[600], pathOf(byId[600]))
assert(w600 and math.floor(w600.pct + 0.5) == 20 and w600.steps == 1 and w600.zones == 1, "20 % of a level, one step, Westfall")
assert(byId[600].best and w600.verdict == "must", tostring(w600.verdict) .. " " .. tostring(w600.score))
local w620 = Dn.QuestWorth(byId[620], pathOf(byId[620]))
assert(w620.verdict == "skip" and w620.score < Dn.WORTH.WORTH, tostring(w620.verdict) .. " " .. tostring(w620.score))
assert(Dn.QuestWorth(byId[630], pathOf(byId[630])).verdict == "later")
assert(Dn.QuestWorth(byId[610], pathOf(byId[610])).verdict == "unknown", "no XP known, no upgrade")
local lw = Dn.LevelWindow(byId[600])
assert(lw.min == 14 and lw.level == 18 and lw.grey == 25 and lw.my == 16)

local rows = {}
for _, q in ipairs(list) do rows[#rows + 1] = { q = q, path = pathOf(q) } end
local plan = Dn.RunPlan("deadmines", rows, NS.DungeonInfo("deadmines"))
assert(plan.open == 4, plan.open)
-- before: the own zone (Stormwind) first, then Westfall; VanCleef's letter is no stop (it drops inside)
assert(#plan.before == 2 and plan.before[1].zone == "Sturmwind" and plan.before[2].zone == "Westfall", plan.before[1].zone)
assert(#plan.route == 2 and plan.route[1].title == "Underground" and plan.route[1].no == 1 and plan.route[2].title == "Brotherhood")
assert(#plan.later == 1 and plan.later[1].title == "Too High" and plan.later[1].level == 30)
-- in the dungeon: the bosses in the game's order, VanCleef last with the goal and the start
local names = {}
for _, t in ipairs(plan.bosses) do names[#names + 1] = t.name end
assert(names[1] == "Rhahk'Zor" and names[#names] == "Edwin VanCleef", table.concat(names, ", "))
local van = plan.bosses[#plan.bosses]
assert(van.goals[1] == "Brotherhood" and van.starts[1] == "Unsent Letter", "goal by name without spaces, start by its loot")
assert(#plan.other == 1 and plan.other[1] == "Underground", "an objective no boss names: " .. table.concat(plan.other, ","))
-- after: the turn-ins (Baros in Stormwind, Gryan in Westfall, Shoni in Stormwind)
local after = 0
for _, g in ipairs(plan.after) do after = after + #g.stops end
assert(after == 3 and plan.after[1].zone == "Sturmwind" and #plan.after[1].stops == 2, plan.after[1].zone)
assert(plan.xp.total == 2300 and plan.xp.missing == 1, "the level-locked quest counts for nothing: " .. plan.xp.missing)
-- a step several quests share is one stop; a boss names each quest once
local twice = {}
for _, r in ipairs(rows) do twice[#twice + 1] = r; twice[#twice + 1] = r end
local p2 = Dn.RunPlan("deadmines", twice, NS.DungeonInfo("deadmines"))
assert(p2.open == 8 and #p2.route == 2, "no stop twice: " .. #p2.route)
local v2 = p2.bosses[#p2.bosses]
assert(#v2.goals == 1 and #v2.starts == 1 and #p2.other == 1, "each title once")
-- the boss track: the entry's bosses in the game's order, no "Trash", the order's names only without any
local track = Dn.BossTrack("deadmines", { bosses = {
    { name = "Trash", items = { { upgrade = true } } },
    { name = "Edwin VanCleef", items = { { upgrade = true }, { upgrade = false } } },
    { name = "Somebody New", items = {} },
    { name = "Rhahk'Zor", items = {} },
} })
local tn = {}
for _, t in ipairs(track) do tn[#tn + 1] = t.name end
assert(table.concat(tn, ",") == "Rhahk'Zor,Edwin VanCleef,Somebody New" and track[2].ups == 1, table.concat(tn, ","))

---------------------------------------------------------------------------
-- the page: the journal's first row, the run planner, the route
---------------------------------------------------------------------------
AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
AmisiaDB.settings.bis.dpart = "bosses"
NS.ShowDungeon("deadmines")
local B = NS.DungeonsPageFrame()
assert(B.plan:GetText() == "Lauf planen")
B.plan:Click()
local V = B.pathView
assert(V:IsShown() and not B.list:IsShown(), "the run planner from the bosses part")
assert(V.title:GetText() == "Dein Lauf" and V.info:GetText() == "4 offene Quests · 2 Halte vor dem Lauf", V.info:GetText())
local first = V.list.rows[1]
assert(first.item.kind == "run" and first.sel:IsShown() and plain(first.title:GetText()) == "Dein Lauf", "the first row")
assert(first.sub:GetText() == "4 offen · 2 Halte", first.sub:GetText())
-- the image: the run's XP and the bar, the tooltip
assert(has(V.art.run:GetText(), "Lauf: mind. +2300 EP"), V.art.run:GetText())
assert(V.art.bar:IsShown() and math.abs(V.art.bar.cur:GetWidth() - 20) < 0.5 and math.abs(V.art.bar.gain:GetWidth() - 46) < 0.5,
    V.art.bar.cur:GetWidth() .. " " .. V.art.bar.gain:GetWidth())
local tip, addLine0 = {}, GameTooltip.AddLine
GameTooltip.AddLine = function(_, t) tip[#tip + 1] = t end
V.art.hot.scripts.OnEnter(V.art.hot)
GameTooltip.AddLine = addLine0
tip = table.concat(tip, "\n")
assert(has(tip, "Jetzt: Stufe 16, 10 %") and has(tip, "Nach dem Lauf: Stufe 16, 33 %") and has(tip, "zählen nicht: 1"), tip .. "#" .. #tip)
-- the body: the sections, the stops with "Karte", the boss track
local texts, buttons = {}, 0
for _, ln in ipairs(V.runLines) do
    if ln.fs:IsShown() then texts[#texts + 1] = plain(ln.fs:GetText()) end
    if ln.btn:IsShown() then buttons = buttons + 1 end
end
local body = table.concat(texts, "\n")
assert(has(body, "1. Underground: annehmen bei Shoni, Sturmwind 62.8, 34.8") or has(body, "1. Underground: annehmen bei Shoni"), body)
assert(has(body, "2. Brotherhood: annehmen bei Gryan"), body)
assert(has(body, "ab Stufe 30: Too High"), body)
assert(has(body, "Edwin VanCleef\nZiel: Brotherhood\nstartet: Unsent Letter"), body)
assert(has(body, "Sonst im Dungeon: Underground"), body)
assert(has(body, "abgeben bei Baros"), body)
assert(buttons == 5, "a map button per stop before and after: " .. buttons)
local labels = {}
for _, fs in ipairs(V.runLabels) do if fs:IsShown() then labels[#labels + 1] = plain(fs:GetText()) end end
assert(table.concat(labels, "|") == "Vor dem Lauf|Im Dungeon|Nach dem Lauf abgeben", table.concat(labels, "|"))
assert(not V.nextBox:IsShown() and not V.pathLabel:IsShown(), "no quest parts in the run planner")
-- the route: stop 1, then 2, then 1 again
WorldMapFrame:Hide()
NS.MapClearTarget()
assert(V.map:GetText() == "Route: Halt 1/2 auf der Karte", V.map:GetText())
V.map:Click()
assert(has(NS.MapTarget().label, "Shoni") and V.map:GetText() == "Route: Halt 2/2 auf der Karte", NS.MapTarget().label)
V.map:Click()
assert(has(NS.MapTarget().label, "Gryan") and V.map:GetText() == "Route: Halt 1/2 auf der Karte", NS.MapTarget().label)
WorldMapFrame:Hide()
NS.MapClearTarget()
assert(has(B.hint:GetText(), "die Bosse in der Reihenfolge des Spiels"), B.hint:GetText())

---------------------------------------------------------------------------
-- the quest rows: worth word and bar; the quest view: level window, rewards, the folded done steps
---------------------------------------------------------------------------
local jrows = {}
for _, r in ipairs(V.list.rows) do if r:IsShown() and r.item and r.item.qid then jrows[r.item.qid] = r end end
assert(plain(jrows[600].gain:GetText()) == "Muss" and jrows[600].worth:IsShown(), plain(jrows[600].gain:GetText()))
assert(plain(jrows[620].gain:GetText()) == "Kann weg" and jrows[620].worth:GetWidth() < jrows[600].worth:GetWidth())
assert(plain(jrows[630].gain:GetText()) == "Später" and plain(jrows[610].gain:GetText()) == "?")
assert(has(plain(jrows[600].sub:GetText()), "+"), "the upgrade's gain moved into the second line")
tip = {}
GameTooltip.AddLine = function(_, t) tip[#tip + 1] = t end
local addDouble0 = GameTooltip.AddDoubleLine
GameTooltip.AddDoubleLine = function(_, a, b) tip[#tip + 1] = tostring(a) .. " = " .. plain(b) end
jrows[600].scripts.OnEnter(jrows[600])
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine0, addDouble0
tip = table.concat(tip, "\n")
assert(has(tip, "Lohn: 20 % einer Stufe + ein Upgrade = Muss") and has(tip, "Aufwand: 1 offene Schritte, 1 Zonen draußen"), tip)
jrows[600]:Click()
assert(V.title:GetText() == "Brotherhood" and V.path ~= nil and V.plan == nil, tostring(V.title:GetText()) .. " " .. tostring(V.path) .. " " .. tostring(V.plan))
assert(V.map:GetText() == "Nächsten Schritt auf der Karte", "the button is the path's again")
for _, ln in ipairs(V.runLines) do assert(not ln.fs:IsShown(), "the run planner's lines are gone") end
assert(V.lvl:IsShown() and plain(V.lvl.text:GetText()) == "ab 14 · grau ab 25 (noch 9)", plain(V.lvl.text:GetText()))
assert(V.lvl.segs[1]:IsShown() and V.lvl.segs[2]:IsShown() and V.lvl.segs[3]:IsShown(), "too low, can be taken, grey")
-- the rewards: the best of several, what it replaces
local sub = plain(V.rewards[1].sub:GetText())
assert(has(sub, "beste Wahl") and has(sub, "statt Old Shirt") and has(plain(V.rewards[1].text:GetText()), "Westfall Vest"), sub)
assert(not has(plain(V.rewards[2].sub:GetText()), "beste Wahl"), "only the best")
assert(has(plain(V.rewards[2].sub:GetText()), "Platz leer") and not has(plain(V.rewards[2].sub:GetText()), "statt"), plain(V.rewards[2].sub:GetText()))
-- the two done steps at the start: one line; a click shows them, another folds them again
assert(V.doneLine:IsShown() and plain(V.doneLine.text:GetText()) == "Schritte 1-2 erledigt · Klick: zeigen", plain(V.doneLine.text:GetText()))
assert(not V.cards[1]:IsShown() and not V.cards[2]:IsShown() and V.cards[3]:IsShown(), "the done cards folded")
V.doneLine:Click()
assert(V.cards[1]:IsShown() and V.cards[2]:IsShown() and has(plain(V.doneLine.text:GetText()), "einklappen"))
V.doneLine:Click()
assert(not V.cards[1]:IsShown())
-- back to the run row: the quest parts go
first = V.list.rows[1]
first:Click()
assert(V.plan ~= nil and not V.lvl:IsShown() and not V.doneLine:IsShown() and not V.rewards[1]:IsShown())

-- the layout of the journal head with the route button
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(B, 602, 478)
Lay.row("run head", V.back, V.map)
V.back:Click()
assert(not V:IsShown() and B.list:IsShown() and not B.parts.quests.on, "back to the bosses part it came from")

-- at the level cap only the upgrades count
STUB.level, STUB.xp = 60, { 0, 0 }
NS.BisBump()
NS.ShowDungeonQuest("deadmines", "run")
assert(V:IsShown() and not V.art.bar:IsShown(), "no XP bar at the cap")

STUB.questsDone[601], STUB.questsDone[602] = nil, nil
STUB.worn[5] = nil
STUB.xp, STUB.level = nil, 16
AmisiaDB.questxp = {}
NS.DUNGEON_QUESTS = realQuests
NS.BisBump()
AmisiaDB.settings.bis.dpart = "bosses"
print("run planner: worth, grey level, bosses in order, stops by zone, route, run sum, level window, rewards, folded steps")
