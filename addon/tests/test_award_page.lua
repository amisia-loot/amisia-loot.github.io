-- The awards page: officer and raider view, raid choice, search, editing with undo, the name hint,
-- and the overview card.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 5)

-- an older raid with Forever names, for the name hint
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Der Schwarze Tempel", instanceID = 564,
              start = 1700000000, last = 1700003600,
              members = { ["Vulo Sturmwind"] = { class = "WARRIOR", first = 1700000000, last = 1700003600 },
                          ["Fraktur Stein"] = { class = "SHAMAN", first = 1700000000, last = 1700003600 } },
              loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, old)
local o1 = NS.AddAwardTo(old, { name = "Vulo", item = 32235, kind = "MS", src = "Illidan Stormrage", t = 1700001000 })
local o2 = NS.AddAwardTo(old, { name = "Vulo", item = 32837, kind = "OS", src = "Mother Shahraz", t = 1700002000 })
local o3 = NS.AddAwardTo(old, { name = "Fraktur Stein", item = 32837, kind = "MS", src = "Illidan Stormrage", t = 1700002500 })

local a1 = NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Stormrage" })
STUB.tick(60)
local a2 = NS.AddAwardTo(s, { name = "Vuloo", item = 32837, kind = "OS", src = "Illidan Stormrage", note = "Tausch mit Fraktur" })
STUB.tick(60)
local a3 = NS.AddAwardTo(s, { name = "Vulobank", item = 32837, kind = "MS", src = "Mother Shahraz", to = "bank" })
local a4 = NS.AddAwardTo(s, { name = nil, item = 32235, src = "Mother Shahraz", to = "de" })
local a5 = NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "MS", src = "Illidan Stormrage", manual = true })

---------------------------------------------------------------------------
-- registration: page for everyone, command, quick menu entry
---------------------------------------------------------------------------
local panel = NS.Panel("awards")
assert(panel and panel.label == "Vergaben" and panel.order == 35 and not panel.officer, "the page is registered for everyone")
local entries = ""
for _, e in ipairs(NS.MinimapMenuEntries()) do entries = entries .. e[1] .. "|" end
assert(entries:find("Vergaben", 1, true), entries)
NS.Set("ui.view", "raider")
entries = ""
for _, e in ipairs(NS.MinimapMenuEntries()) do entries = entries .. e[1] .. "|" end
assert(not entries:find("Vergaben", 1, true), "raiders have no quick menu entry")
NS.Reset("ui.view")

NS.Dispatch("vergaben")
assert(NS.CurrentPage() == "awards", "the command opens the page")
NS.ShowPage("overview")
NS.Dispatch("awards")
assert(NS.CurrentPage() == "awards", "the alias too")

---------------------------------------------------------------------------
-- officer view: the running recording is chosen, the list and the head line
---------------------------------------------------------------------------
local f = NS.AwardsPageFrame()
assert(f and f.officer:IsShown() and not f.raider:IsShown(), "officer view")
local O = f.officer
assert(O.raid:GetValue() == s.id, "the running recording is chosen first")
local values = O.raid.values
assert(values[1].value == s.id and values[2].value == old.id and values[#values].value == "all" and values[#values].text == "Alle Raids",
    "recording first, then the saved raids, 'Alle Raids' last")
assert(values[2].text:find("01.09.", 1, true) and values[2].text:find("Schwarze Tempel", 1, true), values[2].text)
local rows = O.list.rows
assert(rows[1].item.a == a1 and rows[5].item.a == a5 and not rows[6]:IsShown(), "five living awards of the recording")
assert(rows[1].time:GetText() == date("%H:%M", a1.t), rows[1].time:GetText())
assert(rows[1].name:GetText():find("Fraktur", 1, true) and rows[1].name:GetText():find("ff0070de", 1, true), "class colour from the members")
assert(rows[1].kind:GetText() == "MS" and rows[1].plus:GetText() == "2", "plus-one of the winner on MS awards: " .. tostring(rows[1].plus:GetText()))
assert(rows[2].plus:GetText() == "" and rows[3].plus:GetText() == "", "no plus-one on OS or bank")
assert(rows[1].itemText:GetText():find("Cursed Vision", 1, true) and rows[1].itemText:GetText():find("a335ee", 1, true), "item in its quality colour")
assert(rows[3].name:GetText():find("Bank (Vulobank)", 1, true) and rows[3].name:GetText():find("8f86a3", 1, true), rows[3].name:GetText())
assert(rows[4].name:GetText():find("Entzaubern", 1, true) and not rows[4].name:GetText():find("(", 1, true), rows[4].name:GetText())
assert(rows[3].kind:GetText() == "-" and rows[1].src:GetText() == "Illidan Stormrage")
assert(not rows[1].name:GetText():find("?", 1, true), "a member carries no question mark")
local head = O.head:GetText()
assert(head:find("5 Vergaben", 1, true) and head:find("1 Bank", 1, true) and head:find("1 Entzaubern", 1, true) and head:find("nicht exportiert", 1, true), head)
assert(not O.edit:IsShown(), "nothing chosen, nothing to edit")

-- shift-click puts the item link into the chat
STUB.shift = true
rows[1]:Click()
STUB.shift = false
assert(STUB.inserted == link, "the item link went to the chat: " .. tostring(STUB.inserted))
assert(not O.edit:IsShown(), "a shift-click chooses nothing")

---------------------------------------------------------------------------
-- raid choice, "Alle Raids" and the search
---------------------------------------------------------------------------
O.raid.onPick(old.id)
assert(rows[1].item.a == o1 and rows[3].item.a == o3 and not rows[4]:IsShown(), "the old raid's awards")
assert(rows[1].name:GetText():find("?", 1, true), "a name outside the members carries a question mark")
assert(rows[1].name:GetText():find("c79c6e", 1, true), "the class colour still comes from the matching member")
assert(O.head:GetText():find("3 Vergaben", 1, true) and not O.head:GetText():find("Bank", 1, true), O.head:GetText())
O.raid.onPick("all")
assert(rows[1].item.a == a1 and rows[6].item.a == o1 and rows[8].item.a == o3, "all raids, the newest first")
assert(rows[6].time:GetText() == date("%d.%m.", o1.t), "the date instead of the time: " .. rows[6].time:GetText())
assert(O.head:GetText():find("8 Vergaben", 1, true) and O.head:GetText():find("2 Raids", 1, true), O.head:GetText())
O.search:SetFocus(); O.search:SetText("shahraz"); O.search.scripts.OnEnterPressed(O.search)
assert(rows[1].item.a == a3 and rows[2].item.a == a4 and rows[3].item.a == o2 and not rows[4]:IsShown(), "the search matches the source")
O.search:SetFocus(); O.search:SetText("Tausch"); O.search.scripts.OnEnterPressed(O.search)
assert(rows[1].item.a == a2 and not rows[2]:IsShown(), "the search matches the note")
O.search:SetFocus(); O.search:SetText("warglaive"); O.search.scripts.OnEnterPressed(O.search)
assert(rows[1].item.a == a2 and rows[2].item.a == a3 and rows[3].item.a == a5 and rows[4].item.a == o2 and rows[5].item.a == o3, "the item name")
O.search:SetFocus(); O.search:SetText("vulo"); O.search.scripts.OnEnterPressed(O.search)
assert(rows[1].item.a == a2 and rows[2].item.a == a3 and rows[3].item.a == o1 and rows[4].item.a == o2 and not rows[5]:IsShown(), "the winner, bank receiver included")
-- the client runs OnTextChanged on every change; the stub's SetText does not, so the test does
O.search.scripts.OnTextChanged(O.search, false)
assert(O.search:GetText() == "vulo" and not O.search.Instructions:IsShown(), "the placeholder hides behind a query")
O.search:SetFocus(); O.search:SetText(""); O.search.scripts.OnEnterPressed(O.search)
assert(rows[8]:IsShown())
O.search.scripts.OnTextChanged(O.search, false)
assert(O.search.Instructions:IsShown(), "an empty search shows the placeholder again")

---------------------------------------------------------------------------
-- editing works at once, undo puts it back
---------------------------------------------------------------------------
O.raid.onPick(s.id)
rows[2]:Click()
assert(O.edit:IsShown() and O.edit.title:GetText():find("Warglaive", 1, true) and O.edit.title:GetText():find("Illidan", 1, true), "the chosen award")
assert(O.edit.winner:GetValue() == "Vuloo" and O.edit.kinds.OS.on and not O.edit.kinds.MS.on)
assert(O.edit.note:GetText() == "Tausch mit Fraktur")
assert(O.edit.status:GetText():find("Notiz 18/60", 1, true), O.edit.status:GetText())
assert(not O.edit.hint:IsShown(), "a member needs no name hint")
assert(rows[2].sel:IsShown() and not rows[1].sel:IsShown(), "the chosen row is marked")
O.edit.kinds.MS:Click()
assert(a2.kind == "MS" and O.edit.kinds.MS.on and not O.edit.kinds.OS.on and rows[2].kind:GetText() == "MS", "the kind changes at once")
O.edit.note:SetFocus(); O.edit.note:SetText("Neu"); O.edit.note.scripts.OnEnterPressed(O.edit.note)
assert(a2.note == "Neu" and O.edit.note:GetText() == "Neu")
assert(O.edit.status:GetText():find("geändert " .. date("%H:%M", a2.edited), 1, true), O.edit.status:GetText())
-- the winner picker takes a member or a free name
local names = {}
for _, v in ipairs(O.edit.winner.values) do names[#names + 1] = v.value end
assert(table.concat(names, ",") == "Fraktur,Vuloo", table.concat(names, ","))
assert(O.edit.winner.freeText == "Anderer Name")
O.edit.winner.onPick("Fraktur")
assert(a2.name == "Fraktur" and a2.orig == "Vuloo" and O.edit.winner:GetValue() == "Fraktur")
assert(O.edit.status:GetText():find("zuerst an Vuloo", 1, true), O.edit.status:GetText())
O.edit.winner.onPick("Vuloo")
-- bank and back to a player
assert(O.edit.bank:GetText() == "Bank" and O.edit.de:GetText() == "Entzaubern")
O.edit.bank:Click()
assert(a2.to == "bank" and a2.kind == "-" and a2.name == "Vuloo", "bank keeps the receiver")
assert(O.edit.bank:GetText() == "An Spieler" and O.edit.de:GetText() == "Entzaubern", "the button of the current target offers the way back")
assert(rows[2].name:GetText():find("Bank (Vuloo)", 1, true))
O.edit.de:Click()
assert(a2.to == "de" and O.edit.de:GetText() == "An Spieler" and O.edit.bank:GetText() == "Bank")
O.edit.de:Click()
assert(AmisiaPicker and AmisiaPicker:IsShown() and AmisiaPicker.owner == O.edit.winner, "An Spieler opens the winner picker")
AmisiaPicker.list.rows[2]:Click()
assert(a2.to == "player" and a2.name == "Vuloo" and not AmisiaPicker:IsShown(), "picked back to a player")
O.edit.kinds.OS:Click()
assert(a2.kind == "OS")
-- the manual award says so
rows[5]:Click()
assert(O.edit.status:GetText():find("von Hand eingetragen", 1, true), O.edit.status:GetText())
-- delete: the award leaves the list, the panel closes, undo brings it back
rows[2]:Click()
local n = #s.awards
O.edit.del:Click()
assert(#s.awards == n - 1 and a2.deleted and not O.edit:IsShown(), "deleted at once")
assert(rows[2].item.a == a3, "the list moved up")
assert(O.undo:IsEnabled())
O.undo:Click()
assert(a2.deleted == nil and s.awards[2] == a2 and rows[2].item.a == a2, "undo restores")
assert(lastMsg():find("Rückgängig", 1, true), lastMsg())
for _ = 1, 8 do assert(NS.UndoAward(), "eight edits to take back") end
assert(a2.kind == "OS" and a2.note == "Tausch mit Fraktur" and a2.name == "Vuloo" and a2.orig == nil, "every edit undone")

---------------------------------------------------------------------------
-- the name hint shows only for a name outside the members
---------------------------------------------------------------------------
O.raid.onPick(old.id)
rows[3]:Click()
assert(not O.edit.hint:IsShown(), "Fraktur Stein is a member")
rows[1]:Click()
assert(O.edit.hint:IsShown() and O.edit.hint:GetText():find("\"Vulo\"", 1, true) and O.edit.hint:GetText():find("nicht in der Anwesenheit", 1, true), O.edit.hint:GetText())
local chips = O.edit.chips
assert(chips[1]:IsShown() and chips[1].label:GetText() == "Vulo Sturmwind", chips[1].label:GetText())
assert(chips[2]:IsShown() and chips[2].label:GetText() == "alle 2", tostring(chips[2].label:GetText()))
assert(not chips[3]:IsShown())
chips[1]:Click()
assert(o1.name == "Vulo Sturmwind" and o2.name == "Vulo", "the first chip changes this award only")
assert(not O.edit.hint:IsShown(), "the hint is gone")
NS.UndoAward()
rows[1]:Click()
chips[2]:Click()
assert(o1.name == "Vulo Sturmwind" and o2.name == "Vulo Sturmwind", "'alle' renames every award of that name")
assert(NS.UndoLabel():find("Umbenennen", 1, true), "one undo step")
NS.UndoAward()
assert(o1.name == "Vulo" and o2.name == "Vulo")
-- a name with no suggestion still gets the hint, without chips
local o4 = NS.AddAwardTo(old, { name = "Niemand", item = 32235, kind = "MS", src = "?" })
rows[4]:Click()
assert(O.edit.hint:IsShown() and not chips[1]:IsShown(), "no chips without a suggestion")
NS.DeleteAward(old, o4.id)
assert(not O.edit:IsShown(), "the chosen award vanished with its deletion")

-- the undo button carries the label as tooltip
NS.EditAward(old, o1.id, { kind = "OS" })
NS.Refresh()
assert(O.undo:IsEnabled())
O.undo.scripts.OnEnter(O.undo)
O.undo.scripts.OnLeave(O.undo)
NS.UndoAward()

-- "Hinzufügen" opens the award dialog for the chosen raid, without an item
local opened
local dialog = NS.ShowAwardDialog
NS.ShowAwardDialog = function(item, raid) opened = { item = item, raid = raid } end
O.add:Click()
assert(opened and opened.item == nil and opened.raid == old, "the chosen raid")
O.raid.onPick("all")
O.add:Click()
assert(opened.raid == s, "'Alle Raids': the running recording")
NS.ShowAwardDialog = dialog
O.raid.onPick(s.id)

---------------------------------------------------------------------------
-- raider view: own items only, read-only
---------------------------------------------------------------------------
s.items[#s.items + 1] = { name = "Vuloo", item = 32235, count = 1, t = STUB.now }
s.items[#s.items + 1] = { name = "Fraktur", item = 32837, count = 1, t = STUB.now }
old.items[#old.items + 1] = { name = "Vuloo Nacht", item = 32837, count = 1, t = 1700001000 }
NS.Set("ui.view", "raider")
NS.ShowPage("overview")
NS.ShowPage("awards")
assert(NS.CurrentPage() == "awards", "raiders see the page")
assert(f.raider:IsShown() and not f.officer:IsShown())
local R = f.raider
assert(R.title:GetText() == "Deine Items")
local rr = R.list.rows
assert(rr[1].item.item == 32235 and rr[1].item.s == s and rr[1].kind:GetText() == "", "own loot of the recording, no award of my own")
assert(rr[2].item.item == 32837 and rr[2].item.s == s and rr[2].kind:GetText() == "OS", "my own award, counted once with the loot line")
assert(rr[3].item.item == 32837 and rr[3].item.s == old and not rr[4]:IsShown(), "the old raid by first name")
assert(rr[1].date:GetText():match("^%d%d%.%d%d%.$"), rr[1].date:GetText())
assert(rr[3].zone:GetText() == "Der Schwarze Tempel")
assert(R.text:GetText():find("Amisia-Loot-Seite", 1, true))

---------------------------------------------------------------------------
-- the card: bank and disenchant counted, the button opens the page on the newest raid
---------------------------------------------------------------------------
local spec
for _, c in ipairs(NS.cards) do if c.key == "awards" then spec = c end end
assert(spec and spec.order == 40)
local card = NS.W.Card(UIParent, 296, 112)
card:SetAction(nil)
spec.fill(card)
assert(card.title:GetText() == "Deine Items letzte Nacht" and card.line1:GetText():find("2 Items", 1, true), card.line1:GetText())
assert(card.button:IsShown() and card.button:GetText() == "Öffnen")
NS.Reset("ui.view")
card:SetAction(nil)
spec.fill(card)
assert(card.title:GetText() == "Vergaben letzte Nacht")
assert(card.line1:GetText():find("5 Items am " .. s.date, 1, true), card.line1:GetText())
assert(card.line2:GetText():find("1 Bank", 1, true) and card.line2:GetText():find("1 Entzaubern", 1, true) and card.line2:GetText():find("noch nicht exportiert", 1, true), card.line2:GetText())
NS.ShowPage("overview")
O.raid.onPick(old.id)
card.button:Click()
assert(NS.CurrentPage() == "awards" and O.raid:GetValue() == s.id, "the newest raid is chosen")
-- exported and without bank: the second line drops those parts
NS.MarkExported({ s })
NS.DeleteAward(s, a3.id); NS.DeleteAward(s, a4.id)
NS.MarkExported({ s })
spec.fill(card)
assert(card.line1:GetText():find("3 Items", 1, true) and card.line2:GetText() == "", card.line2:GetText())
NS.UndoAward(); NS.UndoAward()
-- Raids page details: bank, disenchant, notes, no tombstones
NS.ShowPage("raids")
local detail = NS.RaidDetailText(s)
assert(detail:find("Cursed Vision of Sargeras an Fraktur (MS)", 1, true), detail)
assert(detail:find("Warglaive of Azzinoth an Vuloo (OS) (Tausch mit Fraktur)", 1, true), detail)
assert(detail:find("Warglaive of Azzinoth: Bank (Vulobank)", 1, true), detail)
assert(detail:find("Cursed Vision of Sargeras: entzaubert", 1, true) and not detail:find("entzaubert (", 1, true), detail)
NS.DeleteAward(s, a1.id)
assert(not NS.RaidDetailText(s):find("Cursed Vision of Sargeras an Fraktur (MS)", 1, true), "a tombstone is not shown")
