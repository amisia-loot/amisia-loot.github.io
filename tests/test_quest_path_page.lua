-- The quest path on the page Dungeons (F-135, UI/Pages/Dungeons.lua): one row per dungeon quest with
-- "Weg 1/3" and the dungeon mark for a start inside; a click opens the quest path in place of the
-- list in the quest journal (F-138, "< Zurück zu den Dungeons"): the dungeon's quests on the left, the
-- chosen one on the right (title, level, state, progress, reward tiles, the next step and "Nächsten
-- Schritt auf der Karte"), a card per step (state, "Schritt 2 von 3", Annehmen
-- and Abgeben with "Karte" where a place is known, Voraussetzung, Ziel, the marks), the next step
-- highlighted, done steps faded; the row's tooltip names the progress and the next step; another
-- dungeon or a /reload shows the list again (nothing saved).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local realQuests = NS.DUNGEON_QUESTS

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 500, 530 } },
    Q = {
        [500] = { "Final Quest", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", { 501 }, { 502, 503 }, "deadmines", { 9910 }, nil,
                  nil, nil, nil, 0, 0, "Gryan", "1436:5630:4760", "Kill Van Cleef." },
        [501] = { "Root", 10, 12, "A", 0, "O", "Root Giver", "1436:1000:1000", nil, nil, nil },
        [502] = { "Choice A", 12, 14, "A", 0, "O", "Choice Giver", "1436:2000:3000", nil, nil, nil },
        [503] = { "Choice B", 12, 14, "A", 0, "O", "Other Giver", nil, nil, nil, nil },
        [504] = { "A Hint", 10, 10, "", 0, "O", "Herald", "1436:6000:6000", nil, nil, nil, nil, { 500 }, true },
        [530] = { "Inside Job", 15, 18, "", 0, "I", "Inside Giver", nil, nil, nil, "deadmines" },
    },
}
STUB.item(9910, "Defiashelm", 3)
local it = STUB.items[9910]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_HEAD", 4, 2, 15
it.stats = { ITEM_MOD_STRENGTH_SHORT = 20 }
NS.GEAR = { built = "test-path-page", Z = {}, I = {}, S = {} }
NS.Gear._reset()
STUB.questsDone[501] = true
NS.BisBump()

AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
AmisiaDB.settings.bis.dpart = "quests"
NS.ShowDungeon("deadmines")
local B = NS.PageFrame("dungeons")
assert(B.parts.quests.on and B.header.ButtonText:GetText() == "Quests", B.header.ButtonText:GetText())

---------------------------------------------------------------------------
-- the list: one row per quest, the progress, the dungeon mark
---------------------------------------------------------------------------
local rows = {}
for _, r in ipairs(B.detail.rows) do if r.item then rows[r.item.qid] = r end end
local kinds = {}
for _, e in ipairs(B.detail.items) do kinds[#kinds + 1] = e.kind end
assert(table.concat(kinds, ",") == "quest,quest", "one row per quest: " .. table.concat(kinds, ","))
assert(plain(rows[500].way:GetText()) == "Weg 1/3", plain(rows[500].way:GetText()))
assert(rows[530].way:GetText() == "", "no pre-quests: no progress")
assert(has(rows[530].rate:GetText(), "|A:Dungeon:") and has(plain(rows[530].rate:GetText()), "im Dungeon"), rows[530].rate:GetText())
-- the tooltip: progress, next step, rewards, the click
local tipLines, addLine0 = {}, GameTooltip.AddLine
GameTooltip.AddLine = function(_, t) tipLines[#tipLines + 1] = t end
rows[500].scripts.OnEnter(rows[500])
GameTooltip.AddLine = addLine0
local tip = table.concat(tipLines, "\n")
assert(has(tip, "Weg: 1 von 3 Schritten erledigt") and has(tip, "Nächster Schritt: 2. Choice A bei Choice Giver, Westfall 20, 30"), tip)
assert(has(tip, "Belohnung: ") and has(tip, "Defiashelm") and has(tip, "Klick: der Questweg mit allen Schritten"), tip)
rows[500].scripts.OnLeave(rows[500])

---------------------------------------------------------------------------
-- the quest path
---------------------------------------------------------------------------
WorldMapFrame:Hide()
NS.MapClearTarget()
rows[500]:Click()
local V = B.pathView
assert(V:IsShown() and not B.grid:IsShown() and not B.back:IsShown() and not B.art:IsShown() and not B.detail:IsShown() and not B.parts.quests:IsShown())
assert(not B.next:IsShown() and not B.why:IsShown(), "the journal covers all under the head row")
assert(NS.MapTarget() == nil, "opening the path sets no target")
assert(V.back:GetText() == "< Zurück zu den Dungeons" and V.map:GetText() == "Nächsten Schritt auf der Karte")
-- the journal (F-138): the dungeon's image, its quests on the left with the chosen one marked
assert(V.art:IsShown() and V.art.title:GetText() == "The Deadmines" and has(V.art.info:GetText(), "Quests: 2, offen: 2"), V.art.info:GetText())
local jrows = {}
for _, r in ipairs(V.list.rows) do if r:IsShown() and r.item and r.item.qid then jrows[r.item.qid] = r end end
assert(jrows[500] and jrows[530], "both quests in the journal's list")
assert(jrows[500].sel:IsShown() and not jrows[530].sel:IsShown(), "the chosen quest is marked")
assert(jrows[500].title:GetText() == "Final Quest" and has(plain(jrows[500].sub:GetText()), "Weg 1/3"), plain(jrows[500].sub:GetText()))
assert(has(jrows[530].sub:GetText(), "|A:Dungeon:"), "a start inside: the dungeon mark")
assert(V.title:GetText() == "Final Quest", V.title:GetText())
assert(V.info:GetText() == "Stufe 18 (ab 14) · noch nicht annehmbar · Weg 1/3", V.info:GetText())
assert(V.rewardLabel:IsShown() and V.rewards[1]:IsShown() and has(V.rewards[1].text:GetText(), "Defiashelm"), "the reward tile")
assert(V.rewards[1].icon.texture ~= nil, "the reward's icon")
assert(has(V.pathLabel:GetText(), "Weg: 1 von 3 Schritten erledigt"), V.pathLabel:GetText())
assert(plain(V.nextLine:GetText()) == "Nächster Schritt: 2. Choice A bei Choice Giver, Westfall 20, 30", plain(V.nextLine:GetText()))
-- the cards: 501 (done), 502 (next, one of two), 504 (a breadcrumb), 500
local c1, c2, c3, c4 = V.cards[1], V.cards[2], V.cards[3], V.cards[4]
assert(c1:IsShown() and c4:IsShown() and not (V.cards[5] and V.cards[5]:IsShown()), "four cards")
assert(plain(c1.title:GetText()) == "1. Root" and c1.step:GetText() == "Schritt 1 von 3" and c1:GetAlpha() < 1, "done: faded")
assert(not c1.lines[1].value:IsShown() and c1:GetHeight() < c2:GetHeight(), "done: folded to its head")
assert(has(c1.icon.texture or "", "ReadyCheck-Ready"), tostring(c1.icon.texture))
assert(c2.glow:IsShown() and not c1.glow:IsShown() and not c4.glow:IsShown(), "the next step is highlighted")
assert(c2.lines[1].label:GetText() == "Annehmen:" and c2.lines[1].value:GetText() == "bei Choice Giver, Westfall 20, 30" and c2.lines[1].btn:IsShown())
assert(c2.lines[2].label:GetText() == "Abgeben:" and c2.lines[2].value:GetText() == "noch unbekannt" and not c2.lines[2].btn:IsShown())
assert(c2.lines[3].label:GetText() == "Voraussetzung:" and c2.lines[3].value:GetText() == "ab Stufe 12 · empfohlen 14 · nur Allianz")
assert(has(plain(c2.lines[4].value:GetText()), "eine davon reicht · auch möglich: Choice B"), plain(c2.lines[4].value:GetText()))
assert(c3.step:GetText() == "optional" and has(plain(c3.lines[3].value:GetText() .. c3.lines[4].value:GetText()), "optional: nur Hinweis auf die nächste Quest"))
assert(c4.step:GetText() == "Schritt 3 von 3" and c4.lines[2].value:GetText() == "bei Gryan, Westfall 56, 48" and c4.lines[2].btn:IsShown())
local goal
for _, ln in ipairs(c4.lines) do if ln.label:GetText() == "Ziel:" and ln.label:IsShown() then goal = ln.value:GetText() end end
assert(goal == "Kill Van Cleef.", tostring(goal))
assert(c1.after:IsShown() and c1.after:GetText() == "danach" and not c4.after:IsShown(), "danach between the cards")
-- "Karte" on a step: the turn-in of the quest; the next step on the map
c4.lines[2].btn:Click()
assert(NS.MapTarget().label == "Abgabe Gryan" and WorldMapFrame:IsShown(), NS.MapTarget().label)
WorldMapFrame:Hide()
V.map:Click()
assert(NS.MapTarget().label == "Questgeber Choice Giver" and WorldMapFrame:IsShown(), NS.MapTarget().label)
WorldMapFrame:Hide()
NS.MapClearTarget()
assert(has(B.hint:GetText(), "Karte: Weltkarte und Wegpunkt"), B.hint:GetText())
-- the path is not saved: nothing in the settings names it
for k, v in pairs(AmisiaDB.settings.bis) do assert(not has(tostring(k), "path") and v ~= 500, "saved: " .. tostring(k)) end

-- a quest inside: the dungeon mark and "im Dungeon"; "Karte" leads to the entrance. A click in the
-- journal's list shows it on the right, the list stays.
jrows[530]:Click()
assert(V:IsShown() and V.title:GetText() == "Inside Job", V.title:GetText())
for _, r in ipairs(V.list.rows) do
    if r.item and r.item.qid == 530 then assert(r.sel:IsShown(), "the clicked quest is marked") end
    if r.item and r.item.qid == 500 then assert(not r.sel:IsShown(), "the other one no longer") end
end
assert(V:IsShown() and V.cards[1]:IsShown() and not V.cards[2]:IsShown())
assert(has(V.cards[1].lines[1].value:GetText(), "|A:Dungeon:") and plain(V.cards[1].lines[1].value:GetText()) == " im Dungeon, bei Inside Giver", V.cards[1].lines[1].value:GetText())
assert(V.cards[1].lines[1].btn:IsShown(), "inside: the map button goes to the entrance")
V.cards[1].lines[1].btn:Click()
assert(has(NS.MapTarget().label, "(Eingang)"), NS.MapTarget().label)
WorldMapFrame:Hide()
NS.MapClearTarget()
assert(not V.rewardLabel:IsShown())

-- back; another dungeon closes the path; the layout of the view
B:OpenPath({ qid = 500, q = { title = "Final Quest" } })
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(B, 602, 478)
Lay.row("path head", V.back, V.map)
V.back:Click()
assert(not V:IsShown() and B.detail:IsShown() and not B.grid:IsShown() and B.back:IsShown() and B.art:IsShown(), "back to the detail view")
B:OpenPath({ qid = 500, q = { title = "Final Quest" } })
assert(V:IsShown())
AmisiaDB.settings.bis.dungeon = "thanes"
NS.Refresh()
assert(not V:IsShown() and B.detail:IsShown() and B.header.ButtonText:GetText() == "Quests", "another dungeon shows its detail")
-- ns.ShowDungeonQuest opens a path directly
assert(NS.ShowDungeonQuest("deadmines", 500) ~= nil)
assert(V:IsShown() and V.title:GetText() == "Final Quest")
B.parts.bosses:Click()
assert(not V:IsShown(), "the bosses part closes the path")

-- the command names each quest's next step
STUB.messages = {}
NS.Dispatch("dungeon quests deadmines")
local said = table.concat(STUB.messages, "\n")
assert(has(said, "Final Quest · Level 18 (ab 14) · Weg 1/3") and has(said, "  Nächster Schritt: 2. Choice A bei Choice Giver, Westfall 20, 30"), said)

STUB.questsDone[501] = nil
NS.DUNGEON_QUESTS = realQuests
NS.BisBump()
AmisiaDB.settings.bis.dpart = "bosses"
print("quest path page: rows, path view, cards, map buttons")
