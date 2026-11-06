-- The quest path of a dungeon quest (F-135, Gear/Dungeons.lua): the steps from the first pre-quest
-- to the quest (root first), each with its state, where it is taken (giver, start item with where it
-- drops, object, "im Dungeon"), where it is handed in (or "noch unbekannt"), what it needs (level,
-- faction, class, race, profession) and its objective; a "one of" group (one is enough, the others
-- folded, "nicht mehr nötig" once one is done), breadcrumbs (optional, not counted), quests no
-- longer possible with the quest that closed them, loops and at most 15 steps; the progress and the
-- next step with its map target; the collector's own observations before the data; the waypoints
-- of a step (D-62: no client waypoint or map in an instance); an old data file without the new fields.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local Dn = NS.Dungeons
local realQuests = NS.DUNGEON_QUESTS

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.maps[1453] = { name = "Sturmwind", mapType = 3 }
NS.Map._reset()

-- the quest data: fields 1-13 as before, 14-22 new (breadcrumb, start items, start object, races,
-- profession, turn-in NPC, turn-in points, objective, spots)
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 500, 520, 530 }, thanes = { 600, 700 } },
    Q = {
        -- the Deadmines quest 500 needs 501 (all of) and one of 502/503; the breadcrumb 504 leads to it (its 13th field)
        [500] = { "Final Quest", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", { 501 }, { 502, 503 }, "deadmines", nil, nil,
                  nil, nil, nil, 0, 0, "Gryan", "1436:5630:4760", "Kill Van Cleef." },
        [501] = { "Root", 10, 12, "A", 0, "O", "Root Giver", "1436:1000:1000", nil, nil, nil, nil, nil,
                  nil, nil, nil, 0, 0, nil, nil, nil },
        [502] = { "Choice A", 12, 14, "A", 1, "O", "Choice Giver", "1453:2000:3000", { 501 }, nil, nil, nil, nil },
        [503] = { "Choice B", 12, 14, "A", 0, "O", "Other Giver", "1453:4000:5000", nil, nil, nil, nil, { 505 } },
        [504] = { "A Hint", 10, 10, "", 0, "O", "Herald", "1453:6000:6000", nil, nil, nil, nil, { 500 }, true },
        [505] = { "Rival", 12, 14, "A", 0, "O", "Rival Giver", "1453:1000:1000", nil, nil, nil, nil, nil },
        -- started by an item that drops in the Deadmines; a profession and a race
        [520] = { "Strange Letter", 15, 19, "", 0, "X", nil, nil, nil, nil, "deadmines", nil, nil,
                  nil, { { 9901, "Cookie", nil, "deadmines" } }, nil, 8, 171, nil, nil, nil,
                  -- where in the dungeon the item can lie (hand-kept hints, D-65): German, English; a broken pair drops
                  { { "Hinter dem Schiff", "Behind the ship" }, { "", "" }, "x", { "Im Keller", "In the cellar" } } },
        -- starts inside the dungeon, at an object outside before it
        [530] = { "Inside Job", 15, 18, "", 0, "I", "Inside Giver", nil, { 531 }, nil, "deadmines" },
        [531] = { "Wanted Poster", 14, 16, "", 0, "O", nil, "1436:5000:5000", nil, nil, nil, nil, nil,
                  nil, nil, "Wanted: Defias", 0, 0, nil, nil, nil },
        -- a loop (601 needs 602, 602 needs 601) and a long chain (700 needs 701 .. 720)
        [600] = { "Loop End", 14, 18, "", 0, "O", "G", "1436:1:1", { 601 }, nil, "thanes" },
        [601] = { "Loop A", 10, 10, "", 0, "O", "G", "1436:1:1", { 602 }, nil, nil },
        [602] = { "Loop B", 10, 10, "", 0, "O", "G", "1436:1:1", { 601 }, nil, nil },
        [700] = { "Long Way", 14, 18, "", 0, "O", "G", "1436:1:1", { 701 }, nil, "thanes" },
    },
}
for i = 701, 720 do
    NS.DUNGEON_QUESTS.Q[i] = { "Long " .. i, 1, 1, "", 0, "O", "G", "1436:1:1", i < 720 and { i + 1 } or nil, nil, nil }
end
STUB.item(9901, "Seltsamer Brief", 1)
NS.GEAR = { built = "test-path", Z = {}, I = {}, S = {} }
NS.Gear._reset()
NS.BisBump()

local function questOf(dkey, qid)
    for _, q in ipairs((NS.DungeonQuests(dkey))) do if q.qid == qid then return q end end
end
local function path(dkey, qid) return NS.DungeonQuestPath(dkey, qid) end
local function titles(p)
    local out = {}
    for _, s in ipairs(p.steps) do out[#out + 1] = s.node.qid end
    return table.concat(out, ",")
end

---------------------------------------------------------------------------
-- the steps, the one-of group, the breadcrumb, the progress
---------------------------------------------------------------------------
local p = path("deadmines", 500)
assert(p, "the path of a dungeon quest")
-- 501 (all of), then of 502/503 the first possible one (502), then the breadcrumb, then the quest
assert(titles(p) == "501,502,504,500", titles(p))
local s1, s2, s3, s4 = p.steps[1], p.steps[2], p.steps[3], p.steps[4]
assert(s1.reqNo == 1 and s2.reqNo == 2 and s3.reqNo == nil and s4.reqNo == 3, "the breadcrumb is not counted")
assert(p.total == 3 and p.done == 0 and p.next == s1, "nothing done: the root is next")
assert(s3.breadcrumb and s3.optional and not s2.breadcrumb)
assert(s2.one and s2.others[1] == "Choice B" and not s2.oneDone, "one of two: the other one listed")
assert(s1.state == "open" and s2.state == "locked" and s4.state == "locked", s1.state .. " " .. s2.state .. " " .. s4.state)
assert(Dn.QuestPathShort(p) == "0/3")
-- accept and turn-in, what it needs, the objective
assert(s1.accept.kind == "npc" and s1.accept.text == "bei Root Giver, Westfall 10, 10" and near(s1.accept.point.x, 0.1), s1.accept.text)
assert(s1.turnIn.text == "noch unbekannt" and not s1.turnIn.known and not s1.turnIn.point)
assert(s4.turnIn.text == "bei Gryan, Westfall 56, 48" and s4.turnIn.point, s4.turnIn.text)
assert(s4.objective == "Kill Van Cleef.")
assert(s2.needs == "ab Stufe 12 · empfohlen 14 · nur Allianz · nur Krieger", tostring(s2.needs))
assert(s3.needs == "ab Stufe 10", tostring(s3.needs))
assert(Dn.QuestPathNextText(p) == "1. Root bei Root Giver, Westfall 10, 10", Dn.QuestPathNextText(p))
-- the root done: the choice is next; then the choice done: the other one is no longer needed
STUB.questsDone[501] = true
STUB.fire("QUEST_TURNED_IN", 501)
p = path("deadmines", 500)
assert(p.done == 1 and p.next.node.qid == 502 and p.steps[2].state == "open", "the choice is next")
STUB.questsDone[503] = true
STUB.fire("QUEST_TURNED_IN", 503)
p = path("deadmines", 500)
assert(titles(p) == "501,503,504,500", "a done quest of the group is the chosen one: " .. titles(p))
assert(p.steps[2].oneDone and p.steps[2].others[1] == "Choice A" and p.done == 2 and p.next.node.qid == 500, "nicht mehr nötig")
assert(p.steps[4].state == "open", "the breadcrumb does not hold the quest back")
-- the quest in the log, then ready: the next step is to hand it in
STUB.questsActive[500] = true
STUB.fire("QUEST_ACCEPTED", 500)
p = path("deadmines", 500)
assert(Dn.QuestPathNextText(p) == "3. Final Quest: im Log, Ziel noch offen", Dn.QuestPathNextText(p))
STUB.questsReady = { [500] = true }
C_QuestLog.IsComplete = function(id) return STUB.questsReady[id] == true end
STUB.fire("QUEST_ACCEPTED", 500)
p = path("deadmines", 500)
assert(Dn.QuestPathNextText(p) == "3. Final Quest abgeben bei Gryan, Westfall 56, 48", Dn.QuestPathNextText(p))
local tp, tl = Dn.QuestStepTarget(p.next)
assert(tp and near(tp.x, 0.563) and tl == "Abgabe Gryan", tostring(tl))
STUB.questsDone[500], STUB.questsActive[500] = true, nil
STUB.fire("QUEST_TURNED_IN", 500)
p = path("deadmines", 500)
assert(p.next == nil and p.done == 3 and Dn.QuestPathNextText(p) == "Alle Schritte erledigt.")
for _, id in ipairs({ 500, 501, 503 }) do STUB.questsDone[id] = nil end
STUB.questsReady = {}
STUB.fire("QUEST_TURNED_IN", 501)

-- a quest no longer possible: the quest that closed it
STUB.questsDone[505] = true
STUB.fire("QUEST_TURNED_IN", 505)
local q503 = NS.DungeonQuestPath("deadmines", 500).steps[2]
assert(q503.node.qid == 502, "the closed quest is not the chosen one")
STUB.questsDone[502] = nil
-- 503 itself as the only possibility: its step says why it is gone
NS.DUNGEON_QUESTS.Q[500][10] = { 503 }
NS.BisBump()
p = path("deadmines", 500)
assert(p.steps[2].node.qid == 503 and p.steps[2].gone and p.steps[2].goneBy == "Rival" and p.steps[2].state == "gone", "gone, because Rival is done")
assert(p.next == p.steps[1], "the root is still the next step")
NS.DUNGEON_QUESTS.Q[500][10] = { 502, 503 }
STUB.questsDone[505] = nil
STUB.fire("QUEST_TURNED_IN", 505)

---------------------------------------------------------------------------
-- start item, object, inside; race and profession
---------------------------------------------------------------------------
p = path("deadmines", 520)
local a = p.steps[1].accept
assert(#p.steps == 1 and Dn.QuestPathShort(p) == "", "no pre-quests: no progress shown")
assert(a.kind == "item" and a.text == "Gegenstand Seltsamer Brief aufheben oder benutzen, fällt von Cookie in The Deadmines", a.text)
assert(p.steps[1].needs == "ab Stufe 15 · empfohlen 19 · nur Nachtelf · Beruf Alchimie", tostring(p.steps[1].needs))
local sp = p.steps[1].spots
assert(sp and #sp == 2 and sp[1] == "Hinter dem Schiff" and sp[2] == "Im Keller", "the spots in German, broken ones out")
assert(path("deadmines", 500).steps[4].spots == nil, "no spots without hints")
p = path("deadmines", 530)
assert(titles(p) == "531,530")
assert(p.steps[1].accept.kind == "object" and p.steps[1].accept.text == "an einem Objekt: Wanted: Defias, Westfall 50, 50", p.steps[1].accept.text)
assert(p.steps[2].accept.kind == "inside" and p.steps[2].accept.text == "im Dungeon, bei Inside Giver", p.steps[2].accept.text)
assert(Dn.QuestStartText(questOf("deadmines", 530)) == "im Dungeon")

---------------------------------------------------------------------------
-- a loop ends, at most 15 steps
---------------------------------------------------------------------------
p = path("thanes", 600)
assert(titles(p) == "602,601,600", "the loop ends: " .. titles(p))
p = path("thanes", 700)
assert(#p.steps == 15 and p.cut == 6 and p.steps[15].node.qid == 700 and p.steps[1].node.qid == 714, #p.steps .. " " .. p.cut)
assert(p.total == 15)

---------------------------------------------------------------------------
-- what this client saw itself goes first: the giver, the turn-in NPC, the objective
---------------------------------------------------------------------------
local D0 = NS.DropsToday()
assert(NS.CollectPut("q", 501, D0 .. ";0;77;1436:2000:2500;88;1453:3000:3500;;;0;10;A;0;Wurzelgeber;Abgeberin;Bringt fünf Wurzeln.;Wurzel", "own") == "new")
p = path("deadmines", 500)
s1 = p.steps[1]
assert(s1.accept.text == "bei Wurzelgeber, Westfall 20, 25", s1.accept.text)
assert(s1.turnIn.text == "bei Abgeberin, Sturmwind 30, 35" and s1.turnIn.point, s1.turnIn.text)
assert(s1.objective == "Bringt fünf Wurzeln.")
-- heard from the guild: never (the exchange does not even carry the two texts)
assert(NS.CollectPut("q", 502, D0 .. ";0;0;;0;;;;0;0;;0;;Gehoert;Gehoertes Ziel;Choice A", "heard") == "new")
p = path("deadmines", 500)
assert(p.steps[2].objective == nil and p.steps[2].turnIn.text == "noch unbekannt", "heard texts are not shown")

---------------------------------------------------------------------------
-- the waypoints of a step: accept and turn-in; the next step; D-62 in an instance
---------------------------------------------------------------------------
NS.MapClearTarget()
WorldMapFrame:Hide()
assert(NS.DungeonQuestWaypoint(501, true, "turnin"))
assert(NS.MapTarget().label == "Abgabe Abgeberin" and NS.MapTarget().map == 1453 and WorldMapFrame:IsShown(), NS.MapTarget().label)
WorldMapFrame:Hide()
assert(NS.DungeonQuestWaypoint(504, false, "accept", "deadmines") and NS.MapTarget().label == "Questgeber Herald")
local ok, why = NS.DungeonQuestWaypoint(502, true, "turnin")
assert(not ok and why == "Für diese Quest kennt Amisia keinen Abgabeort.", tostring(why))
assert(NS.DungeonPathWaypoint(path("deadmines", 500)) and NS.MapTarget().label == "Questgeber Wurzelgeber", NS.MapTarget().label)
WorldMapFrame:Hide()
-- in an instance: Amisia's own target only, no client waypoint, no world map
NS.MapClearTarget()
STUB.waypoint = {}
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.inInstance = true
local isIn = _G.IsInInstance
_G.IsInInstance = function() return true, "party" end
assert(NS.DungeonQuestWaypoint(501, true, "accept"))
assert(NS.MapTarget().label == "Questgeber Wurzelgeber" and not STUB.waypoint.point and not WorldMapFrame:IsShown(), "D-62")
_G.IsInInstance = isIn
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.inInstance = nil
NS.MapClearTarget()

---------------------------------------------------------------------------
-- rows as the generated data writes them (trailing nils dropped, [17] and [18] always numbers)
---------------------------------------------------------------------------
STUB.maps[1457] = { name = "Darnassus", mapType = 3 }
STUB.maps[1456] = { name = "Donnerfels", mapType = 3 }
NS.Map._reset()
NS.DUNGEON_QUESTS = {
    built = "real", source = "real",
    D = { gnomer = { 2945, 2947 }, wc = { 1490 }, bfd = { 1200 } },
    Q = {
        [968] = { "The Powers Below", 10, 0, "A", 0, "X", nil, nil, nil, nil, nil, nil, nil, nil, { { 5352, "Twilight Thug", 1439, nil } }, nil, 0, 0 },
        [2945] = { "Grime-Encrusted Ring", 24, 0, "", 0, "X", nil, nil, nil, nil, "gnomer", { 9362 }, nil, nil, { { 9326, "Dark Iron Agent", 226, "gnomer" } }, nil, 0, 0 },
        [1198] = { "In Search of Thaelrid", 18, 0, "", 0, "O", "Dawnwatcher Shaedlass", "1457:5540:2500", nil, nil, "bfd", nil, { 1200 }, true, nil, nil, 0, 0 },
        [1200] = { "Blackfathom Villainy", 18, 0, "", 0, "I", "Argent Guard Thaelrid", nil, nil, nil, "bfd", nil, nil, nil, nil, nil, 0, 0 },
        [1489] = { "Hamuul Runetotem", 10, 0, "H", 0, "O", "Naralex", "1456:5000:5000", nil, nil, nil, nil, nil, nil, nil, nil, 0, 0 },
        [1490] = { "Nara Wildmane", 10, 16, "H", 0, "O", "Erzdruide Hamuul Runetotem", "1456:7836:2856 1456:7470:3020", { 1489 }, nil, "wc", nil, nil, nil, nil, nil, 0, 0, "Nara Wildmane", "1456:7589:3116" },
        [2947] = { "Return of the Ring", 28, 0, "A", 0, "", nil, nil, { 2945 }, nil, "gnomer", { 9362 }, nil, nil, nil, "The Sparklematic 5200", 0, 0 },
    },
}
STUB.item(9326, "Schmieriger Ring", 1)
NS.BisBump()
p = path("gnomer", 2947)
assert(titles(p) == "2945,2947", titles(p))
assert(p.steps[1].accept.kind == "item" and has(p.steps[1].accept.text, "Schmieriger Ring") and has(p.steps[1].accept.text, "fällt von Dark Iron Agent in "),
    p.steps[1].accept.text)
assert(p.steps[2].accept.kind == "object" and p.steps[2].accept.text == "an einem Objekt: The Sparklematic 5200", p.steps[2].accept.text)
-- the breadcrumb 1198 leads to 1200 (its 13th field): an optional step before it, not counted
p = path("bfd", 1200)
assert(titles(p) == "1198,1200" and p.total == 1 and p.steps[1].breadcrumb and p.steps[1].reqNo == nil, titles(p))
assert(Dn.QuestPathShort(p) == "", "only a breadcrumb before it: no progress")
assert(p.steps[2].accept.kind == "inside")
-- once 1200 is done the breadcrumb is gone and falls out of the path
STUB.questsDone[1200] = true
STUB.fire("QUEST_TURNED_IN", 1200)
assert(titles(path("bfd", 1200)) == "1200", "a breadcrumb that leads nowhere any more")
STUB.questsDone[1200] = nil
STUB.fire("QUEST_TURNED_IN", 1200)
-- a Horde quest with its turn-in from the data, for a Horde character
STUB.faction = "Horde"
NS.BisBump()
p = path("wc", 1490)
assert(titles(p) == "1489,1490" and p.steps[2].turnIn.text == "bei Nara Wildmane, Donnerfels 76, 31", p.steps[2].turnIn.text)
STUB.faction = "Alliance"
NS.BisBump()

---------------------------------------------------------------------------
-- an old data file: thirteen fields, nothing of the new ones
---------------------------------------------------------------------------
NS.DUNGEON_QUESTS = {
    built = "old", source = "old",
    D = { deadmines = { 800 } },
    Q = {
        [800] = { "Old Quest", 14, 18, "A", 0, "O", "Old Giver", "1436:3000:3000", { 801 }, nil, "deadmines", nil, nil },
        [801] = { "Old Root", 10, 12, "A", 0, "X", nil, nil, nil, nil, nil, nil, nil },
    },
}
NS.BisBump()
p = path("deadmines", 800)
assert(titles(p) == "801,800" and p.total == 2)
assert(p.steps[1].accept.kind == "item" and p.steps[1].accept.text == "durch einen Gegenstand", p.steps[1].accept.text)
assert(p.steps[2].turnIn.text == "noch unbekannt" and p.steps[2].objective == nil and not p.steps[2].breadcrumb)
assert(p.steps[2].needs == "ab Stufe 14 · empfohlen 18 · nur Allianz")

NS.DUNGEON_QUESTS = realQuests
NS.BisBump()

-- the generated data: every dungeon's quests with their paths, fast enough for a page refresh
local t0, nq, longest = os.clock(), 0, 0
for key in pairs(realQuests.D) do
    for _, q in ipairs((NS.DungeonQuests(key))) do
        local qp = Dn.QuestPath(q, key)
        nq, longest = nq + 1, math.max(longest, #qp.steps)
        assert(#qp.steps <= 15 and qp.done <= qp.total)
    end
end
local spent = os.clock() - t0
print(("quest path: %d quests of the generated data, the longest path %d steps, %.3f s"):format(nq, longest, spent))
assert(spent < 2, "all paths in under two seconds: " .. spent)
print("quest path: steps, one-of groups, breadcrumbs, own observations, waypoints")
