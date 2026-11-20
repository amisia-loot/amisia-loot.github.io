-- Professions: a recipe a quest teaches itself (F-051, R's token Q<quest>): Orcish War Leggings from
-- "The Old Ways" with the quest's learn rank 210, its level, faction, giver and his place; the name in
-- the client's language (the client, the quest scan) before the data's English one; the quests of the
-- own faction (the others only when none is left), at most three lines; the filter "Quest"; a phantom
-- recipe item is gone, so no "Rezept: Item" line; an older file's Q (the name alone) still reads.
local Pr = NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.maps[1454] = { name = "Orgrimmar", parent = 1414, mapType = 3 }
local D = NS.PROFESSIONS
table.insert(D.R[164], "9957:7929:1:210:225:245:Q2756")
table.insert(D.R[164], "1230171:279944:1:1:20:20:Q96044,Q97900,Q97915,Q97916,Q97938")
D.N[7792] = "Aturk the Anvil|1454:8060:2320|H"
D.N[265813] = "Eric Brighthammer|1429:4670:5390|A"
D.Q = {
    [2756] = "The Old Ways|40|H|7792|1454:8060:2320",
    [96044] = "Camping 101: Blacksmithing|4|A|265813|1429:4670:5390",
    [97900] = "Camping 101: Blacksmithing|4|H|0|1429:5200:4740",
    [97915] = "Camping 101: Blacksmithing|4|A|0|",
    [97916] = "Camping 101: Blacksmithing|4||0|",
    [97938] = "Camping 101: Blacksmithing|4|A|0|",
    [70900] = "The Anvil Plan",
}
Pr._reset()

-- reading: the quest is no recipe item and no plain source token
local r = Pr.Recipe(9957)
assert(r and r.quests[1] == 2756 and #r.items == 0 and #r.src == 0, "Q<quest> parsed into r.quests")
assert(r.learn == 210 and Pr.LearnRank(r) == 210 and Pr.LearnExact(r), "the quest's learn rank 210, exact")
assert(not Pr.PresumedTrainer(r), "a quest recipe is no presumed trainer recipe")
local kinds = Pr.SourceKinds(r)
assert(kinds.Q and not kinds.T and not kinds.V, "the filter kind Quest")
local q = Pr.Quest(2756)
assert(q.name == "The Old Ways" and q.level == 40 and q.faction == "H" and q.giver == 7792 and q.point.map == 1454)
local old = Pr.Quest(70900)
assert(old.name == "The Anvil Plan" and old.level == 0 and old.faction == "" and old.giver == nil, "the name alone")
assert(Pr.Quest(1) == nil and Pr.QuestName(1) == "Quest 1")

-- the source line: name, level, faction, giver and his place; the waypoint on the giver
local src = Pr.Sources(r)
assert(#src == 1 and src[1].kind == "Q" and src[1].quest == 2756, "one quest line")
local t = src[1].text
assert(has(t, "Quest: The Old Ways") and has(t, "Stufe 40") and has(t, "Horde"), t)
assert(has(t, "Aturk the Anvil") and has(t, "Orgrimmar 81, 23"), t)
assert(not has(t, "Quelle unbekannt") and not has(t, "Rezept"), t)
assert(src[1].point.map == 1454 and math.abs(src[1].point.x - 0.806) < 1e-9 and math.abs(src[1].point.y - 0.232) < 1e-9)

-- the client's title (German) wins, then the quest scan's
C_QuestLog = { GetTitleForQuestID = function(id) if id == 2756 then return "Die alten Wege" end end }
assert(Pr.QuestName(2756) == "Die alten Wege" and has(Pr.Sources(r)[1].text, "Quest: Die alten Wege"))
C_QuestLog = nil
STUB.scanNames = { L = { [NS.ScanById.Locale()] = { Q = { [2756] = "Die alten Wege (Scan)" }, N = { [7792] = "Aturk der Amboss" } } } }
local scanned = Pr.Sources(r)[1].text
assert(has(scanned, "Die alten Wege (Scan)") and has(scanned, "Aturk der Amboss"), scanned)
STUB.scanNames = nil

-- the own faction's quests (and those of both), at most three lines; the other faction's only when
-- no quest is left (an Alliance character still sees the Horde quest of the leggings)
local camp = Pr.Sources(Pr.Recipe(1230171))
assert(#camp == 4, #camp)
assert(camp[1].quest == 96044 and has(camp[1].text, "Eric Brighthammer") and has(camp[1].text, "Allianz"), camp[1].text)
assert(camp[2].quest == 97915 and camp[3].quest == 97916 and not has(camp[3].text, "Allianz"), "both factions: no faction word")
assert(camp[4].more and has(camp[4].text, "1 weitere Quests"), camp[4].text)
for _, s in ipairs(camp) do assert(s.quest ~= 97900, "the Horde quest stays out") end
assert(camp[2].point == nil, "no giver, no place: no waypoint")

-- the list's filter "Quest"
local found = false
for _, e in ipairs(Pr.List(164, { source = "Q" })) do if e.recipe and e.recipe.spell == 9957 then found = true end end
assert(found, "Orcish War Leggings under the filter Quest")
