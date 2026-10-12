-- Three small actions (2.27.4): "Punkte entfernen" on the points page's paste view and
-- /amisia punkte löschen (officers only, after the question, then a chat line); the loot prio
-- dialog's "Leeren" in one click (the same empty edit as "Leeren" + "Speichern": exported and shared
-- alike) and /amisia prio <Item-Link> löschen; "Im Kalender zeigen" in the raid calendar window
-- (the main window's calendar page at the chosen date).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
STUB.now = 1791400000

---------------------------------------------------------------------------
-- Punkte entfernen
---------------------------------------------------------------------------
local SITE = "#AMISIA-PTS 1 forever 2026-10-08 dkp 1791300000\nCFG raid=0 boss=0 time=0 bench=0 pub=1\nP Vuloo 120\nP Fraktur 80\n#END"
NS.Set("ui.view", "officer")
NS.ShowPoints("list")
local f = NS.PointsPageFrame()
assert(not f.clear:IsShown(), "not in the list view")
NS.ShowPoints("paste")
assert(f.clear:IsShown() and f.clear:GetText() == "Punkte entfernen", "the officer's button in the paste view")
assert(not f.clear:IsEnabled(), "nothing stored: disabled")
assert(NS.SetPointsSite(SITE))
NS.Refresh()
assert(f.clear:IsEnabled(), "a standing stored: enabled")
-- a correction the site does not have yet: the question counts it
assert(NS.PointsAdjust("Fraktur", -5, "zu spät"))
do
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    Lay.row("points paste row", f.import, f.clear)
end
-- the click asks first; Abbrechen keeps everything
f.clear:Click()
local Q = AmisiaConfirmFrame
assert(Q and Q:IsShown() and Q:GetTitleText():GetText() == "Punktestand entfernen?", "the question")
assert(has(Q.text:GetText(), "Die Website behält ihren Stand") and has(Q.text:GetText(), "Korrekturen, die noch nicht auf der Website sind: 1"),
    Q.text:GetText())
assert(Q.ok:GetText() == "Entfernen")
assert(NS.PointsInfo() ~= nil, "nothing gone before the answer")
Q.cancel:Click()
assert(not Q:IsShown() and NS.PointsInfo() ~= nil and NS.PointsStored(), "Abbrechen keeps the standing")
-- Entfernen removes it, the chat says so
STUB.messages = {}
f.clear:Click()
Q.ok:Click()
assert(NS.PointsInfo() == nil and not NS.PointsStored() and AmisiaDB.points == nil, "removed")
assert(has(lastMsg(), "Punktestand entfernt"), lastMsg())
assert(not f.clear:IsEnabled(), "nothing left: disabled again")
-- the command: the same question
assert(NS.SetPointsSite(SITE))
STUB.messages = {}
NS.Dispatch("punkte löschen")
assert(Q:IsShown() and NS.PointsInfo() ~= nil, "/amisia punkte löschen asks")
assert(not has(Q.text:GetText(), "noch nicht auf der Website"), "no corrections waiting: not mentioned")
Q.ok:Click()
assert(NS.PointsInfo() == nil and has(lastMsg(), "Punktestand entfernt"), lastMsg())
NS.Dispatch("punkte löschen")
assert(not Q:IsShown() and has(lastMsg(), "Kein Punktestand gespeichert"), lastMsg())
-- officers only: a raider gets no button, the command refuses
assert(NS.SetPointsSite(SITE))
NS.Set("ui.view", "raider")
NS.ShowPoints("paste")
assert(not f.clear:IsShown(), "no button for raiders")
STUB.messages = {}
NS.Dispatch("points clear")
assert(not Q:IsShown() and NS.PointsInfo() ~= nil and has(lastMsg(), "nur Offiziere"), lastMsg())
NS.Set("ui.view", "officer")
NS.ClearPoints()

---------------------------------------------------------------------------
-- Loot-Prio: "Leeren" in one click
---------------------------------------------------------------------------
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 4)
assert(NS.EditLootPrio(link, "Anna (Tank), Krieger", "alt"))
local fired = 0
NS.Listen("LOOT_PRIO", function() fired = fired + 1 end)
local D = NS.ShowPrioDialog(link)
assert(D:IsShown() and D.order:GetText() ~= "")
assert(has(D.hint:GetText(), "\"Leeren\" löscht die Prio sofort"), D.hint:GetText())
STUB.messages = {}
STUB.now = STUB.now + 60
D.clear:Click()
assert(not D:IsShown(), "closed at once")
assert(NS.LootPrioOf(32235) == nil, "the prio is gone")
assert(has(lastMsg(), "Loot-Prio von") and has(lastMsg(), "geleert"), lastMsg())
assert(fired == 1, "the change goes out like any edit (LOOT_PRIO)")
-- the same edit as "Leeren" + "Speichern" of before: an empty edit, exported as an LC line
local e = AmisiaDB.prio.edits[32235]
assert(e and #e.prio == 0 and e.note == "", "an empty edit")
local lc
for _, l in ipairs(NS.LootPrioExportLines()) do if l:find("^LC 32235 ") then lc = l end end
assert(lc and lc:find(" %-$"), "exported as cleared: " .. tostring(lc))
do
    -- compared with the old way: empty fields and Speichern
    assert(NS.EditLootPrio(link2, "Anna", ""))
    local D2 = NS.ShowPrioDialog(link2)
    D2.order:SetText(""); D2.note:SetText("")
    D2.save:Click()
    local old = AmisiaDB.prio.edits[32837]
    assert(#old.prio == #e.prio and old.note == e.note, "identical to Leeren + Speichern")
end
-- the command: /amisia prio <Item-Link> löschen
assert(NS.EditLootPrio(link, "Anna", "x"))
STUB.messages = {}
NS.Dispatch("prio " .. link .. " löschen")
assert(NS.LootPrioOf(32235) == nil and has(lastMsg(), "geleert"), lastMsg())
assert(NS.LootPrioInfo() and NS.LootPrioInfo().edits == 2, "only that item; the list stays")
-- raiders: refused
assert(NS.EditLootPrio(link, "Anna", "x"))
NS.Set("ui.view", "raider")
STUB.messages = {}
NS.Dispatch("prio " .. link .. " löschen")
assert(NS.LootPrioOf(32235, true) ~= nil and has(lastMsg(), "nur Offiziere"), lastMsg())
NS.Set("ui.view", "officer")
-- the dialog's layout: the three buttons in one row, inside the dialog
do
    D = NS.ShowPrioDialog(link)
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(D, D:GetWidth(), D:GetHeight())
    Lay.row("prio dialog buttons", D.save, D.clear)
    D:Hide()
end

---------------------------------------------------------------------------
-- Im Kalender zeigen
---------------------------------------------------------------------------
STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
NS.Set("ui.view", "raider")
STUB.guild = {
    { name = "Vulo Hunt", rank = 2, class = "HUNTER", level = 60 },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 58 },
}
STUB.calendar({ events = {
    { title = "Molten Core", days = 1, eventType = 0, id = 12, inviteStatus = 7 },
    { title = "Onyxia", days = 3, eventType = 0, id = 14, inviteStatus = 7 },
}, invites = { [12] = { { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 3 } } } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
local terms = NS.SignupTerms()
local N2 = terms[2].night
NS.ShowPage("overview")
NS.ShowRaidCalendar(N2)
STUB.tick(1)
local F = NS._raidCalUI.frame()
assert(F.page:IsShown() and F.page:GetText() == "Im Kalender zeigen", "the button for everyone with a date")
assert(not F.lineup:IsShown(), "a raider: no lineup button")
do
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(F, NS.Theme.RAIDCAL.W, NS.Theme.RAIDCAL.H)
    Lay.row("raid calendar bottom", F.status, F.page, F.signup)
end
F.page:Click()
assert(not F:IsShown(), "the window closes")
assert(NS.CurrentPage() == "calendar", "the main window's calendar page: " .. tostring(NS.CurrentPage()))
local P = NS.CalendarPageFrame()
local cell
for _, c in ipairs(P.cells) do if c.info.key == N2 then cell = c end end
assert(cell and cell.sel:IsShown(), "the date's day is chosen")
local y, m = N2:match("^(%d+)%-(%d+)")
local MONTHS = { "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember" }
assert(P.title:GetText() == MONTHS[tonumber(m)] .. " " .. y, "its month: " .. P.title:GetText())
assert(has(P.terms[1].text:GetText(), "Onyxia"), "its date on the right: " .. tostring(P.terms[1].text:GetText()))
-- an officer: all three buttons fit the row
STUB.player, STUB.class, STUB.officer = "Vulo Hunt", "HUNTER", true
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.Set("ui.view", "officer")
NS.ShowRaidCalendar(N2)
STUB.tick(1)
assert(F.page:IsShown() and F.lineup:IsShown() and F.signup:IsShown())
do
    local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(F, NS.Theme.RAIDCAL.W, NS.Theme.RAIDCAL.H)
    Lay.row("raid calendar bottom officer", F.status, F.page, F.lineup, F.signup)
end
print("quick actions ok")
