-- F-173 (D-105): the quest items to clear away (Gear/QuestItems.lua, Gear/QuestItemsWindow.lua). Every
-- group: sure by the bag slot's start quest, by the client table's start quest (the data's S) and by an own
-- link (the turn-in dialog, the log's item objectives), likely by the data alone (an O link of the data file
-- too: the author's account, not this one), the other faction's quest not concerning the character,
-- unclear (no quest, a quest not in the log, a repeatable one, before the client answered), needed (in the
-- log, a start quest not done) and never listed (armour, a key, the bank); several stacks, charges, an item
-- gone meanwhile, a quest completed while the window is open, combat, the lockdown; "Behalten" and undo; the
-- question and its click, the checks before a delete with a stubbed cursor and bags (combat, cursor busy,
-- a bank or mailbox open, the wrong item on the cursor, no longer sure), the bag update that confirms it or
-- not, the client's refusal for the session, "Ohne Nachfrage löschen", "Nächsten sicheren löschen", the
-- tooltip line and its switch, the count on the page Quests, the command, the saved key's cleanup.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function saidCount(part)
    local n = 0
    for _, m in ipairs(STUB.messages) do if has(m, part) then n = n + 1 end end
    return n
end
local function plain(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local QI, QW = NS.QuestItems, NS.QuestItemsWindow
assert(QI and QW, "the module and its window load")

STUB.class, STUB.level, STUB.faction = "WARRIOR", 30, "Alliance"
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

---------------------------------------------------------------------------
-- the client: quest items in the bags, their quest marks, the cursor, deleting
---------------------------------------------------------------------------
local function questItem(id, name, class)
    STUB.item(id, name, 1)
    STUB.items[id].classID = class or 12
    STUB.items[id].equipLoc = ""
end
-- quest-class items
questItem(7001, "Altes Siegel")        -- the bag slot's mark: starts 501 (done)
questItem(7002, "Verwitterte Karte")   -- the data's S: starts 502 (done)
questItem(7003, "Krokodilträne")       -- own link from the turn-in dialog: 503 (done)
questItem(7004, "Eberhauer")           -- own link 504 (done) and the data's D 505 (not done, not in the log)
questItem(7005, "Gnollpfote")          -- the data's D 506 (done)
questItem(7006, "Hordenbanner")        -- the data's D 507 (Horde only) and 508 (done)
questItem(7007, "Schlammprobe")        -- the data's D 509 (not in the log)
questItem(7008, "Seltsamer Stein")     -- no quest known
questItem(7009, "Spinnenseide")        -- the data's D 510, in the log
questItem(7010, "Dunkle Rune")         -- the bag slot's mark: starts 511 (not done)
questItem(7011, "Erntemarke")          -- own link 512: repeatable by the data, the client's flag says done
questItem(7012, "Autorenfund")         -- the data file's O 513 (done): the author's account, not this one
questItem(7013, "Möwenei")             -- the log's item objective of 514 (done later)
questItem(7014, "Ladung")              -- charges: the client's count -3; own link 501 (done)
questItem(7020, "Schild der Pflicht", 4)   -- armour the data links: never listed
questItem(7021, "Kerkerschlüssel", 13)     -- a key with the quest mark: never listed
questItem(7022, "Seltsames Gebräu", 0)     -- a consumable with the quest mark, starts 501 (done): sure
questItem(7030, "Bankstein")               -- in the bank only

STUB.bags = {
    [0] = { 7001, 7002, 7003, 7004, 7005, 7006, 7007, 7008 },
    [1] = { 7009, 7010, 7011, 7012, 7013, 7014, 7020, 7021, 7022, 7003 },
    [5] = { 7030 },   -- a bank bag: never read
}
STUB.bagInfo = { [0] = { [3] = { count = 4 } }, [1] = { [6] = { count = -3 }, [10] = { count = 2 } } }
local MARK = { [0] = { [1] = { isQuestItem = true, questID = 501 } },
               [1] = { [2] = { isQuestItem = true, questID = 511 }, [8] = { isQuestItem = true },
                       [9] = { isQuestItem = true, questID = 501 } } }
C_Container.GetContainerItemQuestInfo = function(bag, slot)
    local m = MARK[bag] and MARK[bag][slot]
    return m or { isQuestItem = false }
end
_G.GetCursorInfo = function()
    local c = STUB.cursor
    if not c then return nil end
    return "item", C_Container.GetContainerItemID(c.bag, c.slot)
end
local DEL = { calls = 0 }
_G.DeleteCursorItem = function()
    DEL.calls = DEL.calls + 1
    if DEL.hook then return DEL.hook() end
    local c = STUB.cursor
    if c then STUB.bags[c.bag][c.slot] = false end
    STUB.cursor = nil
end
STUB.questsDone = { [501] = true, [502] = true, [503] = true, [504] = true, [506] = true, [508] = true, [512] = true, [513] = true }
STUB.questsActive = { [510] = true }
local TITLES = { [501] = "Das alte Siegel", [503] = "Tränen des Krokodils", [509] = "Schlamm im Tal" }
C_QuestLog.GetTitleForQuestID = function(q) return TITLES[q] end
-- the data: the quest items' file and the quests' records (507 Horde only, 512 repeatable)
NS.QUEST_ITEMS = { built = "2026-11-10", count = 9, I = {
    [7002] = "S502", [7004] = "D505", [7005] = "D506", [7006] = "D507,D508", [7007] = "D509", [7009] = "D510",
    [7011] = "D512", [7012] = "O513", [7020] = "D506", [7021] = "D506" } }
local function rec(name, fac, flags) return ("1426;%s;1;%s;0;0;0;0;;O;;;;%s"):format(name, fac or "", flags or "") end
NS.QUEST_DATA = { built = "x", count = 6, Z = {}, N = {}, Q = {
    [505] = rec("Eberjagd"), [506] = rec("Gnolle vertreiben"), [507] = rec("Für die Horde", "H"),
    [508] = rec("Banner holen"), [509] = rec("Schlamm im Tal"), [512] = rec("Erntefest", "", "R") } }
NS.Quests._reset()

-- the own links of the turn-in dialog: QUEST_PROGRESS of 503 asks for 7003 and Runecloth (no quest item)
questItem(7040, "Runenstoff", 7)
_G.GetQuestID = function() return 503 end
_G.GetNumQuestItems = function() return 2 end
STUB.questItems.required = { STUB.items[7003].link, STUB.items[7040].link }
STUB.fire("QUEST_PROGRESS")
assert(AmisiaDB.questItems.links[7003] == "503", "the turn-in's quest item: " .. tostring(AmisiaDB.questItems.links[7003]))
assert(AmisiaDB.questItems.links[7040] == nil, "a trade good asked at a turn-in is no quest item")
QI.Learn(7004, 504)
QI.Learn(7011, 512)
QI.Learn(7014, 501)
assert(not QI.Learn(7004, 504), "a link once")

---------------------------------------------------------------------------
-- before the client answered: nothing sure, nothing done
---------------------------------------------------------------------------
assert(not QI.Ready())
local s = QI.Scan()
assert(#s.safe == 0 and #s.likely == 0, "nothing sure before the client's answer")
local g, reason = QI.Classify({ id = 7003 })
assert(g == "unclear" and reason == "wait", g .. " " .. tostring(reason))
QW.Show()
assert(has(_G.AmisiaQuestItems.status:GetText(), "Warte, bis das Spiel"), _G.AmisiaQuestItems.status:GetText())
assert(not _G.AmisiaQuestItems.next:IsShown(), "no button before the answer")
QW.Hide()

-- the quest log: the item objective "Möwenei: 0/6" of 514 matches the bag item of that name
C_QuestLog.GetNumQuestLogEntries = function() return 2 end
C_QuestLog.GetInfo = function(i)
    if i == 1 then return { isHeader = true, title = "Tal" } end
    return { questID = 514, isHeader = false }
end
C_QuestLog.GetQuestObjectives = function(q)
    if q ~= 514 then return {} end
    return { { type = "monster", text = "Möwe getötet: 0/2" }, { type = "item", text = "Möwenei: 0/6" },
             { type = "item", text = "0/1 Unbekanntes Ding" } }
end
STUB.fire("QUEST_LOG_UPDATE")
assert(QI.Ready(), "the client answered")
STUB.tick(3)
assert(AmisiaDB.questItems.links[7013] == "514", "the log's item objective, by name: " .. tostring(AmisiaDB.questItems.links[7013]))
assert(QI.ObjectiveName("Lurker Venom: 1/1 (Complete)") == "lurker venom" and QI.ObjectiveName("0/8 Boar Hide") == "boar hide")

---------------------------------------------------------------------------
-- the groups
---------------------------------------------------------------------------
local function groupOf(id)
    local gg, rr, qq = QI.Classify({ id = id, start = (id == 7001 and 501) or (id == 7010 and 511) or (id == 7022 and 501) or nil })
    return gg, rr, qq
end
local function expect(id, group, why)
    local gg, rr = groupOf(id)
    assert(gg == group and (not why or rr == why), ("%d: %s %s, wanted %s %s"):format(id, tostring(gg), tostring(rr), group, tostring(why)))
end
expect(7001, "safe", "start")     -- the bag slot's start quest, done
expect(7002, "safe", "start")     -- the client table's start quest, done
expect(7003, "safe", "seen")      -- seen at the turn-in, done
expect(7004, "unclear", "away")   -- seen and done, but the data's other quest is open
expect(7005, "likely", "data")    -- the data alone, done
expect(7006, "likely", "data")    -- the other faction's quest does not concern him
expect(7007, "unclear", "away")
expect(7008, "unclear", "none")
expect(7009, "needed", "log")
expect(7010, "needed", "startopen")
expect(7011, "unclear", "away")   -- repeatable: never done, though the flag says so
expect(7012, "likely", "data")    -- the data file's O counts as data, never as sure
expect(7013, "unclear", "away")   -- 514 not done yet (and in no log: the stub's log is only read for objectives)

s = QI.Scan()
local function ids(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.id end
    return table.concat(out, ",")
end
assert(ids(s.safe) == "7001,7002,7003,7014,7022", "sure: " .. ids(s.safe))
assert(ids(s.likely) == "7005,7006,7012", "likely: " .. ids(s.likely))
assert(ids(s.unclear) == "7004,7007,7008,7011,7013", "unclear: " .. ids(s.unclear))
assert(s.needed == 2, "needed: " .. s.needed)
for _, e in ipairs(s.safe) do
    assert(e.id ~= 7020 and e.id ~= 7021 and e.id ~= 7030, "never armour, a key or the bank")
    if e.id == 7003 then assert(e.count == 6 and #e.stacks == 2, "two stacks: " .. e.count) end
    if e.id == 7014 then assert(e.count == 3, "charges count as their number: " .. e.count) end
end
assert(QI.SafeCount() == 5)
assert(has(QI.ReasonText("start", 501), "startet die Quest Das alte Siegel (abgeschlossen)"))
assert(has(QI.ReasonText("seen", 503), "war Ziel der Quest Tränen des Krokodils (abgeschlossen), von Amisia gesehen"))
assert(has(QI.ReasonText("data", 506), "laut Daten für Gnolle vertreiben (abgeschlossen)"), "the data's name without the client's")
assert(has(QI.ReasonText("away", 509), "Quest Schlamm im Tal nicht im Log"))
assert(has(QI.ReasonText("none"), "keine Quest bekannt"))
assert(QI.QuestName(99999) == "Quest 99999")

-- a quest completed while the window is open: 514 done -> the egg is sure (seen in the log)
QW.Show()
local F = _G.AmisiaQuestItems
local function rowTexts()
    local out = {}
    for _, x in ipairs(QW.rows) do
        if x.kind == "head" then out[#out + 1] = "#" .. x.group .. x.n else out[#out + 1] = x.e.id end
    end
    return table.concat(out, " ")
end
assert(rowTexts() == "#safe5 7001 7002 7003 7014 7022 #likely3 7005 7006 7012 #unclear5 7004 7007 7008 7011 7013", rowTexts())
STUB.questsDone[514] = true
STUB.fire("QUEST_TURNED_IN", 514)
STUB.tick(1.1)
assert(has(rowTexts(), "#safe6") and has(rowTexts(), "7013"), "the turn-in moved it: " .. rowTexts())
assert(plain(F.status:GetText()) == "6 sicher · 3 wahrscheinlich · 4 unklar · 2 noch gebraucht", F.status:GetText())
assert(F.next:IsShown() and F.next:GetText() == "Nächsten sicheren löschen (6)", F.next:GetText())
-- the rows: a head in gold, an item with its count and reason, "Löschen" only in "sicher"
local shown = {}
for _, r in ipairs(F.list.rows) do if r:IsShown() then shown[#shown + 1] = r end end
assert(has(shown[1].head:GetText(), "Sicher überflüssig (6)"), shown[1].head:GetText())
local row3 = shown[4]   -- 7003
assert(row3.item.e.id == 7003 and has(row3.name:GetText(), "Krokodilträne") and has(row3.name:GetText(), "x6"), row3.name:GetText())
assert(has(row3.sub:GetText(), "von Amisia gesehen") and has(row3.sub:GetText(), "2 Stapel"), row3.sub:GetText())
assert(row3.del:IsShown(), "Löschen on a sure row")
for _, r in ipairs(shown) do
    if r.item.kind == "item" and r.item.group ~= "safe" then assert(not r.del:IsShown(), "no Löschen outside sicher") end
end
-- the tooltip of a row: the bag slot's
STUB.tooltipLines = nil
row3:GetScript("OnEnter")(row3)
assert(GameTooltip:IsShown())
row3:GetScript("OnLeave")(row3)

---------------------------------------------------------------------------
-- "Behalten" and undo (right click), saved per account
---------------------------------------------------------------------------
local row1 = shown[2]
assert(row1.item.e.id == 7001)
row1:GetScript("OnClick")(row1, "RightButton")
local menu = _G.AmisiaMenu
assert(menu and menu:IsShown() and menu.buttons[1].label:GetText() == "Behalten", "the menu")
menu.buttons[1]:Click()
assert(AmisiaDB.questItems.keep[7001] == true and QI.Classify({ id = 7001, start = 501 }) == "keep")
assert(has(rowTexts(), "#keep1 7001") and has(rowTexts(), "#safe5"), rowTexts())
assert(QI.SafeCount() == 5, "a kept item is not offered")
QI.SetKeep(7001, false)
assert(AmisiaDB.questItems.keep[7001] == nil and has(rowTexts(), "#safe6"), "undone: " .. rowTexts())

---------------------------------------------------------------------------
-- deleting: the question, its click, the bag update
---------------------------------------------------------------------------
local ask = _G.AmisiaConfirmFrame
local before = #STUB.messages
row3.del:Click()
ask = _G.AmisiaConfirmFrame
assert(ask and ask:IsShown(), "a question first")
local q = ask.text:GetText()
assert(has(q, "Krokodilträne x4 löschen?") and has(q, "(1 von 2 Stapeln)") and has(q, "von Amisia gesehen")
    and has(q, "lassen sich nicht zurückholen"), q)
assert(DEL.calls == 0, "nothing deleted before the click")
ask.cancel:Click()
assert(DEL.calls == 0 and STUB.bags[0][3] == 7003, "Abbrechen deletes nothing")
row3.del:Click()
_G.AmisiaConfirmFrame.ok:Click()
assert(DEL.calls == 1 and STUB.bags[0][3] == false and STUB.bags[1][10] == 7003, "one stack, the first")
assert(STUB.cursor == nil, "the cursor is empty")
assert(QI.pending and QI.pending.id == 7003 and QI.pending.count == 4)
assert(has(rowTexts(), "7003"), "the row stays until the bag update")
for _, r in ipairs(F.list.rows) do
    if r:IsShown() and r.item.kind == "item" and r.item.e.id == 7003 then
        assert(has(r.sub:GetText(), "wird gelöscht"), r.sub:GetText())
        assert(not r.del:IsShown())
    end
end
-- another delete waits for the bag
assert(not QI.Delete(7001) and said("Amisia wartet noch auf die Tasche."))
STUB.fire("BAG_UPDATE_DELAYED")
assert(QI.pending == nil and said("Gelöscht: Krokodilträne x4."), STUB.messages[#STUB.messages])
assert(has(rowTexts(), "7003"), "the second stack stays: " .. rowTexts())
assert(#STUB.messages > before)

-- the client did not delete it (the cursor emptied, the slot still full): said after the wait
DEL.hook = function() STUB.cursor = nil end
assert(QI.Delete(7003))
STUB.fire("BAG_UPDATE_DELAYED")
assert(QI.pending ~= nil, "still waiting: the slot holds the stack")
STUB.tick(QI.VERIFY + 0.1)
assert(QI.pending == nil and said("Krokodilträne liegt noch in der Tasche: das Spiel hat ihn nicht gelöscht."), STUB.messages[#STUB.messages])
DEL.hook = nil

---------------------------------------------------------------------------
-- the checks before a delete
---------------------------------------------------------------------------
local calls0 = DEL.calls
STUB.combat = true
assert(not QI.Delete(7001) and said("Im Kampf löscht Amisia nichts."))
STUB.fire("PLAYER_REGEN_DISABLED")
assert(has(F.empty:GetText(), "Im Kampf nicht verfügbar.") and F.empty:IsShown() and not F.list:IsShown(), "the window in combat")
assert(QI.TooltipLine(7001) == nil, "no tooltip line in combat (values may be secret)")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
assert(F.list:IsShown() and not F.empty:IsShown())
-- the encounter lockdown counts as combat
STUB.chatLock = true
assert(QI.Scan() == nil and not QI.Delete(7001))
STUB.chatLock = false
-- the cursor holds something
STUB.cursor = { bag = 0, slot = 5 }
assert(not QI.Delete(7001) and said("Du hältst etwas mit der Maus"))
STUB.cursor = nil
-- the bank or the mailbox open
for _, name in ipairs({ "BankFrame", "MailFrame" }) do
    local w = CreateFrame("Frame", name, UIParent)
    w:Show()
    local n = saidCount("Erst Bank, Briefkasten")
    assert(not QI.Delete(7001) and saidCount("Erst Bank, Briefkasten") == n + 1, name)
    w:Hide()
end
-- the item left the bags meanwhile
local keepSlot = STUB.bags[1][9]
STUB.bags[1][9] = false
assert(not QI.Delete(7022) and said("Der Gegenstand liegt nicht mehr in den Taschen."))
STUB.bags[1][9] = keepSlot
-- no longer sure: its quest went into the log
STUB.questsActive[502] = true
assert(not QI.Delete(7002) and said("Verwitterte Karte ist nicht mehr sicher überflüssig: nichts gelöscht."))
STUB.questsActive[502] = nil
-- the cursor holds another item after the pick-up: cleared, nothing deleted
local pickup = C_Container.PickupContainerItem
C_Container.PickupContainerItem = function() STUB.cursor = { bag = 0, slot = 8 } end
assert(not QI.Delete(7002) and said("Unerwartet: die Maus hält nicht Verwitterte Karte. Nichts gelöscht."))
assert(STUB.cursor == nil and STUB.bags[0][8] == 7008, "cleared, the other item untouched")
C_Container.PickupContainerItem = pickup
assert(DEL.calls == calls0, "none of these deleted anything")
-- an item of another group is never deleted
assert(not QI.Delete(7005) and not QI.AskDelete(7008))
assert(DEL.calls == calls0)

---------------------------------------------------------------------------
-- without the question; the next sure one
---------------------------------------------------------------------------
NS.Set("quests.itemNoAsk", true)
STUB.fire("BAG_UPDATE_DELAYED")
assert(QI.NextSafe() == 7001)
F.next:Click()
assert(not (_G.AmisiaConfirmFrame and _G.AmisiaConfirmFrame:IsShown()), "no question with the setting")
assert(STUB.bags[0][1] == false and DEL.calls == calls0 + 1, "the first sure one went")
STUB.fire("BAG_UPDATE_DELAYED")
assert(said("Gelöscht: Altes Siegel x1."))
NS.Set("quests.itemNoAsk", false)
assert(QI.NextSafe() == 7002)
F.next:Click()
assert(_G.AmisiaConfirmFrame:IsShown() and has(_G.AmisiaConfirmFrame.text:GetText(), "Verwitterte Karte"), "the next one asks again")
_G.AmisiaConfirmFrame.cancel:Click()

---------------------------------------------------------------------------
-- the client refuses: no more deleting this session, said once
---------------------------------------------------------------------------
DEL.hook = function()
    STUB.fire("ADDON_ACTION_BLOCKED", "AnderesAddon", "DeleteCursorItem()")
    assert(not QI.Refused(), "another addon's refusal does not count")
    STUB.fire("ADDON_ACTION_FORBIDDEN", "Amisia", "DeleteCursorItem()")
end
assert(not QI.Delete(7002))
assert(QI.Refused() and not QI.CanDeleteAtAll() and STUB.cursor == nil and STUB.bags[0][2] == 7002)
assert(saidCount("Das Spiel lässt Addons keine Gegenstände löschen: zieh den Gegenstand selbst aus der Tasche und lass ihn fallen.") == 1)
assert(not F.next:IsShown(), "the button goes")
for _, r in ipairs(F.list.rows) do if r:IsShown() then assert(not r.del:IsShown(), "and every Löschen") end end
assert(not QI.AskDelete(7002))
assert(saidCount("Das Spiel lässt Addons keine Gegenstände löschen") == 2, "a click says why")
DEL.hook = nil

---------------------------------------------------------------------------
-- the tooltip line and its switch; the count on the page Quests; the command; the place
---------------------------------------------------------------------------
STUB.bags[0][1] = 7001
local line = QI.TooltipLine(7002)
assert(has(line, "Quest: Quest 502 (abgeschlossen)") and has(line, "wird nicht mehr gebraucht"), line)
line = QI.TooltipLine(7005)
assert(has(line, "Gnolle vertreiben (abgeschlossen)") and has(line, "wahrscheinlich nicht mehr gebraucht"), line)
line = QI.TooltipLine(7009)
assert(has(line, "(im Log)") and not has(line, "gebraucht"), line)
line = QI.TooltipLine(7007)
assert(has(line, "Schlamm im Tal (nicht im Log)"), line)
assert(QI.TooltipLine(7008) == nil, "no quest known: no line")
assert(QI.TooltipLine(7020) == nil, "armour: no line")
NS.Set("quests.itemTooltip", false)
assert(QI.TooltipLine(7002) == nil, "switched off")
NS.Set("quests.itemTooltip", true)

NS.Dispatch("quests")
NS.Refresh()
local clean = assert(NS.PageFrame("quests")).clean
assert(clean, "the page Quests has the link")
assert(clean:GetText() == ("Aufräumen (%d)"):format(QI.SafeCount()), clean:GetText())
QW.Hide()
clean:Click()
assert(QW.Shown(), "the link opens the window")

QW.Hide()
NS.Dispatch("questitems")
assert(QW.Shown(), "/amisia questitems")
NS.Dispatch("questgegenstaende")
assert(not QW.Shown(), "a second command closes it")
QW.Show()
F:ClearAllPoints()
F:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
F.scripts.OnDragStop(F)
assert(AmisiaDB.settings.questItemsWindow.point == "TOPLEFT", "the place kept")
NS.ResetPositions()
assert(AmisiaDB.settings.questItemsWindow.point == nil, "reset with the other windows")

---------------------------------------------------------------------------
-- the saved key's cleanup
---------------------------------------------------------------------------
local root = { questItems = { v = 1, links = { [1] = "5,5,3", [2] = "x", ["a"] = "1", [3] = "1,,2", [4] = "0",
    [5] = "1,2,3,4,5,6,7,8,9,10" }, keep = { [1] = true, [2] = "yes", [-1] = true } } }
QI.Loaded(root)
local d = root.questItems
assert(d.links[1] == "3,5" and d.links[2] == nil and d.links.a == nil and d.links[3] == nil and d.links[4] == nil, "cleaned")
assert(d.links[5] == "1,2,3,4,5,6,7,8", "eight quests at most")
assert(d.keep[1] == true and d.keep[2] == nil and d.keep[-1] == nil)
root = { questItems = "broken" }
QI.Loaded(root)
assert(type(root.questItems.links) == "table" and type(root.questItems.keep) == "table" and root.questItems.v == 1)
root = { questItems = { links = {} } }
for i = 1, QI.MAX_LINKS + 5 do root.questItems.links[i] = "1" end
QI.Loaded(root)
local n = 0
for _ in pairs(root.questItems.links) do n = n + 1 end
assert(n == QI.MAX_LINKS and root.questItems.links[1] == nil and root.questItems.links[QI.MAX_LINKS + 5] == "1", "the highest ids kept")
QI.Loaded(AmisiaDB)
assert(AmisiaDB.questItems.links[7003] == "503", "a second run changes nothing")

print("quest items: groups, own links, keep, delete with question and checks, refusal, tooltip, count, command, cleanup")
