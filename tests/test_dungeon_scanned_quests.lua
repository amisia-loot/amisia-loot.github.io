-- Dungeon quests only the quest scan's text placed (F-177, D-109; field 24 of DungeonQuestData.lua):
-- no giver, no place, no English name, sometimes no faction. The dungeon's quest list shows them to
-- both factions where the faction is unknown and only to their own where the text named one; the title
-- is the client's, else the scan's in the client's language (German client), else "Quest <id>" (never
-- the German title on an English client); the start is "unknown" and the path says Amisia learns it;
-- no waypoint, no map step; the XP the scan saw stands in as an estimate where nothing own is known;
-- the dungeon bar lists them; the quest path card and the row's tooltip mark them.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local L = NS.L
local Dn = NS.Dungeons
local realQuests = NS.DUNGEON_QUESTS

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 500, 95262, 95309, 95454 } },
    Q = {
        [500] = { "Final Quest", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", nil, nil, "deadmines" },
        -- the scan's quests: level, no giver, no place; one without a faction, one Horde, one Alliance
        [95262] = { "Quest 95262", 0, 17, "", 0, "", nil, nil, nil, nil, "deadmines", nil, nil, nil, nil, nil, 0, 0, nil, nil,
                    "Begebt Euch in die Todesminen.", nil, 6050, true },
        [95309] = { "Quest 95309", 0, 17, "H", 0, "", nil, nil, nil, nil, "deadmines", nil, nil, nil, nil, nil, 0, 0, nil, nil,
                    nil, nil, nil, true },
        [95454] = { "Quest 95454", 0, 17, "A", 0, "", nil, nil, nil, nil, "deadmines", nil, nil, nil, nil, nil, 0, 0, nil, nil,
                    nil, nil, nil, true },
    },
}
STUB.scanNames = { L = { deDE = { Q = { [95262] = "Das geheime Gefängnis", [95454] = "Die Ehre" }, N = {} } } }
NS.GEAR = { built = "test-scanned", Z = {}, I = {}, S = {} }
NS.Gear._reset()
NS.BisBump()

local function questOf(qid)
    for _, q in ipairs((NS.DungeonQuests("deadmines"))) do if q.qid == qid then return q end end
end

---------------------------------------------------------------------------
-- the list: faction, title, start, level, XP
---------------------------------------------------------------------------
local q, h, a = questOf(95262), questOf(95309), questOf(95454)
assert(q and a, "the scan's quests are in the dungeon's list")
assert(h == nil, "a Horde quest stays out for an Alliance character")
assert(q.scanned and q.giver == nil and q.points == nil and q.start == "")
if NS.GERMAN then
    assert(q.title == "Das geheime Gefängnis", q.title)
else
    assert(q.title == "Quest 95262", "an English client never shows the German title: " .. q.title)
end
-- the client's own title goes first where it has the quest loaded
local getTitle = C_QuestLog.GetTitleForQuestID
C_QuestLog.GetTitleForQuestID = function(id) if id == 95454 then return "The Honour" end end
NS.BisBump()
assert(questOf(95454).title == "The Honour", questOf(95454).title)
C_QuestLog.GetTitleForQuestID = getTitle
NS.BisBump()
q = questOf(95262)
assert(Dn.QuestStartText(q) == "", "no start known: no start text")
assert(Dn.QuestLevelText(q) == "17", Dn.QuestLevelText(q))
assert(Dn.QuestNeeds(q) == L["empfohlen %d"]:format(17), tostring(Dn.QuestNeeds(q)))
assert(Dn.QuestNeeds(questOf(95454)) == L["empfohlen %d"]:format(17) .. " · " .. L["nur Allianz"], "the faction the text named")
assert(Dn.QuestState(q) == "open", "no minimum level known: not locked")
local v, how = Dn.QuestXP(q)
assert(v == 6050 and how == "scan", tostring(v) .. " " .. tostring(how))
assert(Dn.XPText(v, how) == "~6050", Dn.XPText(v, how))
local sum = Dn.XPSum({ q })
assert(sum.total == 6050 and sum.est and sum.missing == 0)
-- what the client saw itself goes first
NS.QuestXP.Record(95262, 5000, 16)
v, how = Dn.QuestXP(q)
assert(v == 5000 and how == "seen", tostring(v) .. " " .. tostring(how))
AmisiaDB.questxp[95262] = nil
assert(Dn.QuestXP(questOf(95454)) == nil, "no XP anywhere: none")

---------------------------------------------------------------------------
-- the quest path, the waypoint, the map steps, the dungeon bar
---------------------------------------------------------------------------
local p = NS.DungeonQuestPath("deadmines", 95262)
assert(p and #p.steps == 1 and p.steps[1].scanned, "one step, marked as the scan's")
local s = p.steps[1]
assert(s.accept.kind == "unknown" and s.accept.point == nil and s.accept.text == L["Ort unbekannt; Amisia lernt ihn, sobald du die Quest siehst"], s.accept.text)
assert(s.turnIn.known == false and s.turnIn.point == nil)
assert(s.objective == "Begebt Euch in die Todesminen.")
assert(Dn.QuestStepTarget(s) == nil, "no place for the next step")
local ok, why = NS.DungeonQuestWaypoint(95262, true, "accept", "deadmines")
assert(ok == nil and type(why) == "string", "no waypoint without a place")
ok, why = NS.DungeonQuestWaypoint(95262, true, "turnin", "deadmines")
assert(ok == nil and type(why) == "string")
ok = NS.DungeonQuestWaypoint(95262, true)
assert(ok == nil, "no goal either")
NS.Set("map.pinsQuests", true)
for _, place in ipairs(NS.DungeonQuestSteps()) do
    assert(place.qid ~= 95262 and place.qid ~= 95454, "a quest without a place gives no map step")
end
assert(type(Dn.QuestWorth(q, p)) == "table", "the run planner's worth")
local qs = NS.DungeonBar.Quests("deadmines")
local inBar = {}
for _, e in ipairs(qs) do inBar[e.q.qid] = e.state end
assert(inBar[95262] == "open" and inBar[95454] == "open" and inBar[95309] == nil, "the dungeon bar lists the scan's quests")

-- once this client saw the giver itself (the collector), the mark goes and the start is known
local ownStart = NS.CollectQuestOwnStart
NS.CollectQuestOwnStart = function(id) if id == 95262 then return "Sully", "1436:1000:2000" end return ownStart(id) end
NS.BisBump()
local seenQ = questOf(95262)
assert(seenQ.giver == "Sully" and seenQ.scanned == nil and seenQ.start == "O", tostring(seenQ.scanned))
assert(has(Dn.QuestStartText(seenQ), "Sully"), Dn.QuestStartText(seenQ))
NS.CollectQuestOwnStart = ownStart
NS.BisBump()
assert(questOf(95262).scanned, "and back without the observation")

---------------------------------------------------------------------------
-- the page: the row's tooltip and the quest path card
---------------------------------------------------------------------------
AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
AmisiaDB.settings.bis.dpart = "quests"
NS.ShowDungeon("deadmines")
local B = NS.PageFrame("dungeons")
local rows = {}
for _, r in ipairs(B.detail.rows) do if r.item and r.item.qid then rows[r.item.qid] = r end end
assert(rows[95262] and rows[95454] and not rows[95309], "rows for the quests of the own faction")
local tipLines, addLine0, addDouble0 = {}, GameTooltip.AddLine, GameTooltip.AddDoubleLine
GameTooltip.AddLine = function(_, t) tipLines[#tipLines + 1] = t end
GameTooltip.AddDoubleLine = function(_, l, r) tipLines[#tipLines + 1] = tostring(l) .. " | " .. tostring(r) end
rows[95262].scripts.OnEnter(rows[95262])
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine0, addDouble0
local tip = table.concat(tipLines, "\n")
assert(not has(tip, L["Start: %s"]:format("")), "no empty start line: " .. tip)
assert(has(tip, L["Nur aus dem Quest-Scan: Questgeber und Ort noch unbekannt"]), tip)
assert(has(tip, "~6050") and has(tip, L["aus dem Quest-Scan, geschätzt"]), tip)
rows[95262].scripts.OnLeave(rows[95262])
rows[95262]:Click()
local V = B.pathView
assert(V:IsShown() and V.cards[1]:IsShown())
local c = V.cards[1]
local texts = {}
for _, ln in ipairs(c.lines) do if ln.value:IsShown() then texts[#texts + 1] = plain(ln.value:GetText()) end end
local all = table.concat(texts, "\n")
assert(has(all, L["Ort unbekannt; Amisia lernt ihn, sobald du die Quest siehst"]) and has(all, L["noch unbekannt"]), all)
assert(has(all, L["nur aus dem Quest-Scan"]), all)
assert(not c.lines[1].btn:IsShown(), "no map button without a place")
V.back:Click()

NS.DUNGEON_QUESTS = realQuests
NS.BisBump()
print("test_dungeon_scanned_quests ok")
