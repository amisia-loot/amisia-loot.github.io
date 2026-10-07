-- The world quest tracker (Quests.lua): the generated data (QuestData.lua) parsed on demand; per
-- quest done, in the log, open or locked with its reasons (faction, race, class, level, pre-quest,
-- profession, an alternative already done), the chain with its progress, rewards with the upgrade
-- mark, the list by zone (sub zones under their zone) with search and filters, the giver's waypoint
-- (the data, else the collector's own observation; heard ones never), the command and the switch.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function kinds(info)
    local out = {}
    for _, r in ipairs(info.reasons) do out[#out + 1] = r.kind end
    return table.concat(out, ",")
end

assert(NS.QUEST_DATA and NS.QUEST_DATA.count > 1000, "the generated data loads")
do
    -- the shipped data parses whole; time and memory of the first list for a level 30 character
    STUB.level = 30
    collectgarbage("collect")
    local kb0, t0 = collectgarbage("count"), os.clock()
    local idx = assert(NS.QuestIndex())
    local t1 = os.clock()
    local rows, counts = NS.QuestList({ show = { open = true, active = true, locked = true, done = true } })
    local t2 = os.clock()
    collectgarbage("collect")
    local kb1 = collectgarbage("count")
    assert(idx.count == NS.QUEST_DATA.count and NS.Quests.Record(176).name == 'Wanted: "Hogger"', "Hogger")
    assert(counts.total > 1000 and #rows > counts.total, "every quest for an Alliance warrior in a row")
    print(("quests: %d parsed in %.3f s, first list (%d rows) %.3f s, %d KB held"):format(idx.count, t1 - t0, #rows,
        t2 - t1, math.floor(kb1 - kb0)))
    assert(t2 - t0 < 2, "parsing and the first list stay fast")
end

STUB.class, STUB.level, STUB.faction = "WARRIOR", 12, "Alliance"
_G.UnitRace = function() return "Mensch", "Human", 1 end
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
STUB.maps[425] = { name = "Nordhain", parent = 1429, mapType = 5 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.maps[1413] = { name = "Brachland", mapType = 3 }

NS.QUEST_DATA = { built = "2026-10-06", source = "test", count = 17,
    Z = { [1429] = "Elwynn Forest", [1436] = "Westfall", [9999] = "Nowhere Land" },
    N = { [197] = "Marshal McBride;425:4810:4180", [234] = "Gryan Stoutmantle;1436:5630:4760",
          [500] = "Horde Guy;1413:1000:1000", [501] = "Lost Giver;" },
    Q = {
        [7] = "425;Kobold Camp Cleanup;0;A;0;0;0;197;;O;;;;",
        [15] = "425;Investigate Echo Ridge;0;A;0;0;0;197;;O;7;;;",
        [21] = "425;Skirmish at Echo Ridge;5;A;0;0;0;197;;O;15;;5001,5002;",
        [54] = "1429;Report to Goldshire;5;A;0;0;0;197;;O;21;;;B",
        [100] = "1436;Westfall Stew;14;A;0;0;0;234;;O;;;;",
        [200] = "1413;Horde Thing;1;H;0;0;0;500;;O;;;;",
        [300] = "1429;Mage Only;1;;128;0;0;0;1429:5000:5000;O;;;;",
        [301] = "1429;Gnome Only;1;A;0;64;0;0;;;;;;",
        [400] = "1429;Alchemy Quest;10;;0;0;171;197;;O;;;;R",
        [500] = "1429;Fight Them;5;;0;0;0;197;;O;;501;;",
        [501] = "1429;Sneak Past;5;;0;0;0;197;;O;;500;;",
        [502] = "1429;After the Choice;5;;0;0;0;197;;O;501;;;",
        [600] = "1436;Found a Note;8;;0;0;0;0;;X;;;;C",
        [700] = "9999;Seen Only;1;;0;0;0;501;;;;;;",
        [701] = "9999;Heard Only;1;;0;0;0;501;;;;;;",
        [800] = "0;Nowhere Quest;1;;0;0;0;0;;;;;;",
        [900] = "1429;Broken;x;;;;",
    },
}
NS.Quests._reset()
local idx = assert(NS.QuestIndex())
assert(idx.count == 16 and idx.byId[900] == nil, "a broken record falls away: " .. tostring(idx.count))
local r = NS.Quests.Record(21)
assert(r.name == "Skirmish at Echo Ridge" and r.min == 5 and r.fac == "A" and r.giver == 197 and r.start == "O")
assert(r.pre[1] == 15 and r.rewards[1] == 5001 and r.rewards[2] == 5002 and not r.alt)
assert(NS.Quests.Record(54).breadcrumb and NS.Quests.Record(400).repeatable and NS.Quests.Record(600).classic)
assert(NS.Quests.Next(7)[1] == 15 and NS.Quests.Next(15)[1] == 21 and #NS.Quests.Next(21) == 1, "the follow-ups")

---------------------------------------------------------------------------
-- status and reasons
---------------------------------------------------------------------------
local function st(qid) return NS.QuestState(qid) end
assert(st(7).status == "open" and #st(7).reasons == 0, "no limits")
assert(st(15).status == "locked" and kinds(st(15)) == "pre" and st(15).reasons[1].text == "Vorquest fehlt: Kobold Camp Cleanup",
    tostring(st(15).reasons[1] and st(15).reasons[1].text))
assert(st(100).status == "locked" and kinds(st(100)) == "level" and st(100).reasons[1].text == "ab Level 14")
assert(st(200).status == "locked" and kinds(st(200)) == "faction" and st(200).reasons[1].text == "nur Horde" and st(200).foreign)
assert(kinds(st(300)) == "class" and st(300).reasons[1].text == "nur Magier" and st(300).foreign)
assert(kinds(st(301)) == "race" and st(301).reasons[1].text == "nur Gnom" and st(301).foreign)
-- the profession: unknown while the client tells no skills, then checked
local skillInfo = _G.C_SkillInfo
_G.C_SkillInfo = nil
STUB.fire("SKILL_LINES_CHANGED")
assert(st(400).status == "open" and has(st(400).note, "Alchimie"), "the client tells no skills: a note, no lock")
_G.C_SkillInfo = skillInfo
STUB.skills = { { name = "Schmiedekunst", rank = 50, id = 164 } }
STUB.fire("SKILL_LINES_CHANGED")
assert(st(400).status == "locked" and kinds(st(400)) == "skill" and st(400).reasons[1].text == "Beruf fehlt: Alchimie",
    tostring(st(400).reasons[1] and st(400).reasons[1].text))
-- by its German name where the line has no id
STUB.skills = { { name = "Alchimie", rank = 20 } }
STUB.fire("SKILL_LINES_CHANGED")
assert(st(400).status == "open")
STUB.fire("QUEST_TURNED_IN", 400)
assert(st(400).status == "open", "a repeatable quest stays open after the turn-in")

-- done and in the log
STUB.questsDone[7] = true
STUB.fire("QUEST_TURNED_IN", 7)
assert(st(7).status == "done" and st(15).status == "open", "the pre-quest done: the next one opens")
STUB.questsActive[15] = true
STUB.fire("QUEST_ACCEPTED", 15)
assert(st(15).status == "active")
-- the bulk list of done quests counts too
_G.C_QuestLog.GetAllCompletedQuestIDs = function()
    local out = {}
    for id in pairs(STUB.questsDone) do out[#out + 1] = id end
    return out
end
_G.C_QuestLog.IsQuestFlaggedCompleted = function() error("not asked while the bulk list is there") end
STUB.questsDone[100] = true
STUB.fire("QUEST_TURNED_IN", 100)
assert(st(100).status == "done" and st(7).status == "done")
_G.C_QuestLog.IsQuestFlaggedCompleted = function(id) return STUB.questsDone[id] == true end

-- an alternative done: this one is gone; its follow-up counts it as done
assert(st(500).status == "open" and st(502).status == "locked")
STUB.questsDone[501] = true
STUB.fire("QUEST_TURNED_IN", 501)
assert(st(500).status == "locked" and kinds(st(500)) == "alt" and st(500).reasons[1].text == "Alternative erledigt: Sneak Past")
assert(st(502).status == "open")

-- the level
STUB.level = 4
NS.Quests._reset()
assert(kinds(st(21)) == "pre,level", kinds(st(21)))
STUB.level = 12
NS.Quests._reset()

---------------------------------------------------------------------------
-- chains
---------------------------------------------------------------------------
local c = NS.QuestChain(21)
assert(#c.ids == 4 and c.ids[1] == 7 and c.ids[2] == 15 and c.ids[3] == 21 and c.ids[4] == 54, "root first, the follow-up last")
assert(c.pos == 3 and c.done == 1 and c.total == 4 and NS.Quests.ChainText(c) == "1/4", NS.Quests.ChainText(c))
assert(NS.QuestChain(100) == nil, "a single quest is no chain")
assert(NS.QuestChain(502).total == 2, "the done alternative leads to its follow-up; the other one stays out")

---------------------------------------------------------------------------
-- rewards with the upgrade mark
---------------------------------------------------------------------------
NS.GEAR = { game = "forever", cap = 60, built = "test-quests", I = {}, Z = {}, S = {} }
NS.Gear._reset()
local function gear(id, name, loc, strength, minLevel)
    local link = STUB.item(id, name, 2)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, 3, minLevel or 5
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    return link
end
local worn = gear(4999, "Alter Helm", "HEAD", 5)
gear(5001, "Echohelm", "HEAD", 20)
gear(5002, "Echogürtel", "WAIST", 0)
STUB.worn[1] = worn
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
local rw = NS.QuestRewards(21)
assert(#rw.list == 2 and rw.list[1].id == 5001 and rw.list[1].up and rw.best == rw.list[1], "the upgrade first")
assert(rw.list[1].mark == "+300%", tostring(rw.list[1].mark))
assert(not rw.list[2].up)

---------------------------------------------------------------------------
-- the list: zones, search, filters
---------------------------------------------------------------------------
local function quests(rows)
    local out = {}
    for _, row in ipairs(rows) do if row.kind == "quest" then out[#out + 1] = row.qid end end
    table.sort(out)
    return table.concat(out, ",")
end
local function zones(rows)
    local out = {}
    for _, row in ipairs(rows) do if row.kind == "zone" then out[#out + 1] = row.name .. ":" .. row.n end end
    return table.concat(out, ",")
end
local all = { show = { open = true, active = true, locked = true, done = true } }
local rows, counts = NS.QuestList(all)
-- for me: the Horde, mage and gnome quests stay out
assert(quests(rows) == "7,15,21,54,100,400,500,501,502,600,700,701,800", quests(rows))
assert(zones(rows) == "Nowhere Land:2,Wald von Elwynn:8,Westfall:2,Ohne Zone:1", zones(rows))
assert(counts.done == 3 and counts.active == 1 and counts.total == 13, counts.done .. " " .. counts.active .. " " .. counts.total)
-- inside a zone: in the log first, then open, locked, done; by level
local order = {}
for _, row in ipairs(rows) do if row.kind == "quest" and row.zone == 1429 then order[#order + 1] = row.qid end end
assert(table.concat(order, ",") == "15,502,400,500,54,21,7,501", table.concat(order, ","))
rows = NS.QuestList({ show = { open = true, active = true, locked = true, done = true }, mine = false })
assert(has(quests(rows), "200") and has(quests(rows), "300") and has(quests(rows), "301"), "everything with mine off")
-- the default chips: open and in the log
rows = NS.QuestList({ show = { open = true, active = true } })
assert(quests(rows) == "15,400,502,600,700,701,800", quests(rows))
-- one zone; a sub zone counts as its zone
rows = NS.QuestList({ show = all.show, zone = 1429 })
assert(zones(rows) == "Wald von Elwynn:8" and quests(rows) == "7,15,21,54,400,500,501,502", zones(rows))
-- search: title, giver, zone
assert(quests(NS.QuestList({ show = all.show, search = "echo" })) == "15,21")
assert(quests(NS.QuestList({ show = all.show, search = "gryan" })) == "100")
assert(quests(NS.QuestList({ show = all.show, search = "westfall" })) == "100,600")
-- chains only, upgrades only
assert(quests(NS.QuestList({ show = all.show, chains = true })) == "7,15,21,54,501,502", quests(NS.QuestList({ show = all.show, chains = true })))
assert(quests(NS.QuestList({ show = all.show, upgrades = true })) == "21")
-- a collapsed zone keeps its head row only
rows = NS.QuestList({ show = all.show, collapsed = { [1429] = true } })
assert(has(zones(rows), "Wald von Elwynn:8") and not has(quests(rows), "21"))
assert(NS.QuestList(all) == NS.QuestList(all), "kept while nothing changes")

---------------------------------------------------------------------------
-- where a quest starts and the waypoint
---------------------------------------------------------------------------
assert(NS.QuestStartText(21) == "Marshal McBride, Nordhain 48, 42", NS.QuestStartText(21))
assert(NS.QuestWaypoint(21) and NS.MapTarget().label == "Questgeber Marshal McBride" and near(NS.MapTarget().x, 0.481)
    and NS.MapTarget().map == 425, NS.MapTarget().label)
assert(NS.QuestWaypoint(300) and NS.MapTarget().label == "Mage Only" and NS.MapTarget().map == 1429, "the quest's own point, no giver")
local ok, why = NS.QuestWaypoint(600)
assert(not ok and why == "Diese Quest startet durch ein Item." and NS.QuestStartText(600) == "durch ein Item")
ok, why = NS.QuestWaypoint(700)
assert(not ok and why == "Für diese Quest kennt Amisia keinen Startort.")
-- the collector: its own observation stands in, a heard one never
local D0 = NS.DropsToday()
assert(NS.CollectPut("q", 700, D0 .. ";0;555;1436:3000:4000;0;;;;0;1;A;0;Gesehener Geber;Seen Only", "own") == "new")
assert(NS.CollectPut("q", 701, D0 .. ";0;556;1436:1200:3400;0;;;;0;1;A;0;Gehoerter Geber;Heard Only", "heard") == "new")
assert(NS.QuestWaypoint(700) and NS.MapTarget().label == "Questgeber Lost Giver" and near(NS.MapTarget().x, 0.3), NS.MapTarget().label)
assert(NS.QuestStartText(700) == "Lost Giver, Westfall 30, 40", NS.QuestStartText(700))
ok, why = NS.QuestWaypoint(701)
assert(not ok and why == "Für diese Quest kennt Amisia keinen Startort.", "heard data sets no waypoint")
assert(NS.QuestStartText(701) == "Lost Giver (Ort unbekannt)", NS.QuestStartText(701))
NS.MapClearTarget()

---------------------------------------------------------------------------
-- the command and the switch
---------------------------------------------------------------------------
STUB.chat = {}
NS.Dispatch("quests Echo")
assert(NS.CurrentPage() == "quests" and AmisiaDB.settings.questsPage.search == "Echo", "the command opens the page with the search")
NS.Dispatch("quests")
assert(AmisiaDB.settings.questsPage.search == "", "without a word the search is cleared")
NS.Set("quests.enabled", false)
assert(NS.QuestIndex() == nil and select(2, NS.QuestIndex()) == "off")
assert(not NS.Visible(NS.Panel("quests")), "no page while the switch is off")
NS.Dispatch("quests")
NS.Set("quests.enabled", true)
assert(NS.QuestIndex(), "back on in the same session while the data is still loaded")
-- a disabled switch at login lets the data go
NS.Set("quests.enabled", false)
NS.Quests.OnLoaded("Amisia")   -- the handler of the next login (ADDON_LOADED comes once per runtime)
assert(NS.QUEST_DATA == nil, "the strings can be collected")
NS.Set("quests.enabled", true)
local _, reason = NS.QuestIndex()
assert(reason == "reload", tostring(reason))
print("quests: status, chains, rewards, list, waypoint, command and switch")
