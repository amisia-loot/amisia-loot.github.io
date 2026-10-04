-- The award dialog: Alt+Shift-click opens it with the round's winner, Alt alone still rolls; hand-out
-- through master loot or a direct entry; bank and disenchant both ways; secret names stay out.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function roll(name, v, lo, hi) STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format(name, v, lo, hi)) end
local function modClick(link, alt, shift)
    STUB.alt, STUB.shift = alt and true or false, shift and true or false
    HandleModifiedItemClick(link)
    STUB.alt, STUB.shift = false, false
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 5)
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" } }
STUB.target, STUB.targetGUID = "Illidan Stormrage", "Creature-0-1-1-1-22917-1"
STUB.fire("LOOT_OPENED")
assert(s.drops["Creature-0-1-1-1-22917-1"].src == "Illidan Stormrage")

---------------------------------------------------------------------------
-- Alt alone rolls, Alt+Shift opens the dialog with the round's winner and does not roll
---------------------------------------------------------------------------
modClick(link, true, false)
local r = NS.CurrentRoll()
assert(r and r.item == 32235, "Alt-click still starts a round")
assert(AmisiaAwardDialog == nil or not AmisiaAwardDialog:IsShown(), "Alt alone opens no dialog")
roll("Fraktur", 87, 1, 100); roll("Vuloo", 95, 1, 99)
NS.StopRoll()
assert(r.winner == "Fraktur")
NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "MS", src = "?" })
local rounds = #NS.RollHistory()
modClick(link, true, true)
assert(#NS.RollHistory() == rounds and NS.CurrentRoll() == r, "Alt+Shift starts no round")
local D = AmisiaAwardDialog
assert(D and D:IsShown(), "Alt+Shift opens the dialog")
assert(D.itemText:GetText():find("Cursed Vision", 1, true) and not D.itemEdit:IsShown(), "the item is shown, no entry box")
assert(D.raidText:GetText():find("Black Temple", 1, true), D.raidText:GetText())
assert(D.winner:GetValue() == "Fraktur" and D.kinds.MS.on and not D.kinds.OS.on, "the winner of the round and his kind")
assert(D.roll:GetText():find("Fraktur 87 (MS)", 1, true) and D.roll:GetText():find("+1: 1", 1, true), D.roll:GetText())
assert(D.give:GetText() == "Vergeben" and D.give:IsEnabled(), "master loot is possible: Vergeben")
local names = {}
for _, v in ipairs(D.winner.values) do names[#names + 1] = v.value end
assert(table.concat(names, ",") == "Chorf,Fraktur,Vuloo", table.concat(names, ","))
assert(D.winner.freeText == "Anderer Name")

-- the kind and the note travel with the hand-out
D.kinds.OS:Click()
assert(D.kinds.OS.on and not D.kinds.MS.on)
D.note:SetFocus(); D.note:SetText("Tausch mit Vuloo"); D.note.scripts.OnEnterPressed(D.note)
STUB.given = nil
D.give:Click()
assert(STUB.given and STUB.given.slot == 1 and STUB.given.i == 2, "GiveMasterLoot with the winner's candidate index")
assert(not D:IsShown(), "the dialog closes")
local p = NS.PendingAward(1)
assert(p and p.kind == "OS" and p.note == "Tausch mit Vuloo", "kind and note wait with the hand-out")
assert(#s.awards == 1, "nothing written before the client confirms")
STUB.fire("LOOT_SLOT_CLEARED", 1)
local a = s.awards[#s.awards]
assert(#s.awards == 2 and a.name == "Fraktur" and a.kind == "OS" and a.note == "Tausch mit Vuloo" and a.to == "player" and a.manual == nil, "confirmed with the dialog's kind and note")
assert(a.src == "Illidan Stormrage")

-- without a winner nothing is given
STUB.loot = { { link = link2, name = "Warglaive of Azzinoth", src = "Creature-0-1-1-1-22917-1" } }
NS.ShowAwardDialog(link2)
assert(D:IsShown() and D.winner:GetValue() == nil and not D.give:IsEnabled(), "no round for this item: no winner, Vergeben locked")
assert(D.roll:GetText():find("Kein Roll", 1, true), D.roll:GetText())
STUB.given = nil
D.give:Click()
assert(STUB.given == nil and D:IsShown(), "nothing happens without a winner")
D.winner.onPick("Chorf")
assert(D.give:IsEnabled())
D.cancel:Click()
assert(not D:IsShown() and STUB.given == nil and #s.awards == 2, "Abbrechen gives nothing")

---------------------------------------------------------------------------
-- without a loot window the entry is direct and manual
---------------------------------------------------------------------------
STUB.fire("LOOT_CLOSED")
NS.ShowAwardDialog(link2, s)
assert(D.give:GetText() == "Eintragen", "no loot window: Eintragen")
assert(D.hint:GetText():find("eingetragen", 1, true), D.hint:GetText())
D.winner.onPick("Vuloo")
D.kinds.SR:Click()
D.note:SetFocus(); D.note:SetText("aus den Taschen"); D.note.scripts.OnEnterPressed(D.note)
STUB.given = nil
D.give:Click()
local m = s.awards[#s.awards]
assert(STUB.given == nil and #s.awards == 3 and m.name == "Vuloo" and m.item == 32837 and m.kind == "SR" and m.manual == true and m.note == "aus den Taschen", "written directly")
assert(m.src == "Illidan Stormrage", "the source comes from the recorded drop: " .. tostring(m.src))
assert(lastMsg():find("Vergabe gespeichert", 1, true), lastMsg())
assert(not D:IsShown())

-- a free name and an old raid
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Der Schwarze Tempel", instanceID = 564,
              start = 1700000000, last = 1700003600, members = { ["Vulo Sturmwind"] = { class = "WARRIOR", first = 1, last = 1 } },
              loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, old)
NS.ShowAwardDialog(32235, old)
assert(D.raidText:GetText():find("01.09.", 1, true) and D.raidText:GetText():find("Schwarze Tempel", 1, true), D.raidText:GetText())
assert(D.itemText:GetText():find("Cursed Vision", 1, true), "an item id is enough")
names = {}
for _, v in ipairs(D.winner.values) do names[#names + 1] = v.value end
assert(table.concat(names, ",") == "Vulo Sturmwind", "an old raid lists its members only: " .. table.concat(names, ","))
assert(D.winner:GetValue() == "Fraktur" and D.kinds.MS.on, "the recent round for this item fills the winner in, whatever the raid")
D.winner.onPick("Neuling", true)
D.kinds["-"]:Click()
D.give:Click()
assert(#old.awards == 1 and old.awards[1].name == "Neuling" and old.awards[1].manual == true and old.awards[1].kind == "-", "a free name into the old raid")
assert(old.last == 1700003600 and not old.members.Neuling)

---------------------------------------------------------------------------
-- bank and disenchant: through master loot with a candidate, else a direct entry with a hint
---------------------------------------------------------------------------
NS.Set("awards.bankName", "Vulobank")
NS.Set("awards.deName", "Chorf")
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" } }
STUB.fire("LOOT_OPENED")
NS.ShowAwardDialog(link)
assert(D.give:GetText() == "Vergeben")
STUB.given = nil
local n0 = #s.awards
D.bank:Click()
assert(STUB.given == nil and not D:IsShown(), "the bank character is no candidate: nothing given")
assert(#s.awards == n0 + 1 and s.awards[n0 + 1].to == "bank" and s.awards[n0 + 1].name == "-" and s.awards[n0 + 1].manual == true, "entered directly instead")
assert(lastMsg():find("Lootfenster", 1, true), lastMsg())
STUB.roster[4] = { name = "Vulobank", class = "WARRIOR" }
NS.ShowAwardDialog(link)
D.bank:Click()
assert(STUB.given and STUB.given.i == 4, "master loot to the bank character")
assert(not D:IsShown())
STUB.fire("LOOT_SLOT_CLEARED", 1)
local b = s.awards[#s.awards]
assert(b.to == "bank" and b.name == "Vulobank" and b.kind == "-", "confirmed as a bank award")
-- disenchant with a note through master loot
NS.ShowAwardDialog(link)
D.note:SetFocus(); D.note:SetText("Splitter für die Bank"); D.note.scripts.OnEnterPressed(D.note)
STUB.given = nil
D.de:Click()
assert(STUB.given and STUB.given.i == 3, "master loot to the disenchanter")
STUB.fire("LOOT_SLOT_CLEARED", 1)
local d = s.awards[#s.awards]
assert(d.to == "de" and d.name == "Chorf" and d.note == "Splitter für die Bank", tostring(d.note))
-- without a loot window: a direct entry, the receiver "-", and the hint about the bags
STUB.fire("LOOT_CLOSED")
NS.ShowAwardDialog(link, s)
local n = #s.awards
D.bank:Click()
assert(#s.awards == n + 1 and s.awards[n + 1].to == "bank" and s.awards[n + 1].name == "-" and s.awards[n + 1].manual == true, "entered as bank")
assert(lastMsg():find("Taschen", 1, true), lastMsg())
assert(not D:IsShown())
-- with the loot window open but no bank character set: the hint names the loot window
NS.Set("awards.bankName", "")
STUB.fire("LOOT_OPENED")
NS.ShowAwardDialog(link)
STUB.given = nil
D.de:Click()
assert(STUB.given and STUB.given.i == 3 and #s.awards == n + 1, "the disenchanter is set and a candidate: master loot, nothing written yet")
STUB.fire("LOOT_SLOT_CLEARED", 1)
assert(#s.awards == n + 2 and s.awards[n + 2].to == "de" and s.awards[n + 2].name == "Chorf")
NS.Set("awards.deName", "")
NS.ShowAwardDialog(link)
D.de:Click()
assert(#s.awards == n + 3 and s.awards[n + 3].to == "de" and s.awards[n + 3].name == "-", "no disenchanter set: a direct entry")
assert(lastMsg():find("Lootfenster", 1, true), lastMsg())
STUB.roster[4] = nil

---------------------------------------------------------------------------
-- secret names (a boss fight on the Forever client) stay out of the list
---------------------------------------------------------------------------
STUB.secret["Chorf"] = true
NS.ShowAwardDialog(link)
names = {}
for _, v in ipairs(D.winner.values) do names[#names + 1] = v.value end
assert(table.concat(names, ",") == "Fraktur,Vuloo", "the secret name is skipped: " .. table.concat(names, ","))
STUB.secret["Chorf"] = nil
D.cancel:Click()

---------------------------------------------------------------------------
-- a dialog without an item takes a link from the chat insertion or an id
---------------------------------------------------------------------------
NS.ShowAwardDialog(nil, s)
assert(D:IsShown() and D.itemEdit:IsShown() and not D.give:IsEnabled(), "no item yet: the entry box shows, nothing to give")
ChatEdit_InsertLink(link2)
assert(not D.itemEdit:IsShown() and D.itemText:GetText():find("Warglaive", 1, true), "a shift-clicked link fills the item")
D.cancel:Click()
NS.ShowAwardDialog(nil, s)
D.itemEdit:SetFocus(); D.itemEdit:SetText("32235"); D.itemEdit.scripts.OnEnterPressed(D.itemEdit)
assert(D.itemText:GetText():find("Cursed Vision", 1, true), "an id fills the item")
D.cancel:Click()
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- the command: without an item the dialog, bank and de as receivers
---------------------------------------------------------------------------
NS.Dispatch("award")
assert(D:IsShown() and D.itemEdit:IsShown(), "/amisia award opens the dialog without an item")
D.cancel:Click()
n = #s.awards
NS.Dispatch("award bank " .. link)
assert(#s.awards == n + 1 and s.awards[n + 1].to == "bank" and s.awards[n + 1].name == "-" and s.awards[n + 1].manual == true, "bank by command")
NS.Dispatch("award de 32235")
assert(#s.awards == n + 2 and s.awards[n + 2].to == "de" and s.awards[n + 2].kind == "-", "de by command")
assert(lastMsg():find("Entzaubern", 1, true), lastMsg())
NS.Dispatch("award Fraktur 32235 ms")
assert(s.awards[n + 3].to == "player" and s.awards[n + 3].kind == "MS", "a player as before")

---------------------------------------------------------------------------
-- the raider view and the switched-off setting open nothing
---------------------------------------------------------------------------
STUB.fire("LOOT_OPENED")
NS.Set("ui.view", "raider")
modClick(link, true, true)
assert(not D:IsShown(), "raiders open no dialog")
NS.Reset("ui.view")
NS.Set("awards.modClick", false)
modClick(link, true, true)
assert(not D:IsShown(), "switched off: no dialog")
NS.Reset("awards.modClick")
modClick(link, true, true)
assert(D:IsShown())
D.scripts.OnHide(D)
D:Hide()
STUB.fire("LOOT_CLOSED")
-- the dialog is a dialog: above the main window, and Escape closes it
assert(D.strata == "FULLSCREEN_DIALOG", tostring(D.strata))
local special = false
for _, name in ipairs(UISpecialFrames) do if name == "AmisiaAwardDialog" then special = true end end
assert(special, "Escape closes the dialog")
