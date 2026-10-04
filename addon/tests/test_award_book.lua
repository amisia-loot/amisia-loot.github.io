-- The award book: stable ids, awards into old raids, editing, tombstones, undo, name fixes and
-- master loot to the bank character.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local fired = 0
NS.Listen("DATA_CHANGED", function() fired = fired + 1 end)

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(type(s.gone) == "table", "a new raid carries its tombstone list")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)

---------------------------------------------------------------------------
-- ids: 12 hex characters, unique in the raid even when the random part repeats, never changed
---------------------------------------------------------------------------
STUB.randomQueue = { 7, 7, 9 }
local a1 = NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Stormrage" })
local a2 = NS.AddAwardTo(s, { name = "Vuloo", item = 32235, kind = "OS", src = "Illidan Stormrage" })
assert(a1 and a2 and s.awards[1] == a1 and s.awards[2] == a2)
assert(a1.id:match("^%x%x%x%x%x%x%x%x%x%x%x%x$"), "12 hex characters: " .. tostring(a1.id))
assert(a1.id == ("%08x%04x"):format(a1.t, 7), a1.id)
assert(a2.id == ("%08x%04x"):format(a2.t, 9), "a taken id is rolled again: " .. a2.id)
assert(a1.to == "player" and a1.kind == "MS" and a1.src == "Illidan Stormrage" and a1.manual == nil)
assert(fired == 2, "every change fires DATA_CHANGED")
assert(NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "SR", src = "?", manual = true }).manual == true)
NS.UndoAward()
assert(#s.awards == 2 and #s.gone == 1, "undo of an add leaves a tombstone")
-- the compatible entry point still works and goes through the book (a second later)
STUB.tick(1)
local a3 = NS.AddAward("Fraktur", 32837, "bogus", "Illidan Stormrage")
assert(a3.t > a1.t)
assert(a3 and a3.id and a3.to == "player" and a3.kind == "-" and s.awards[3] == a3)
assert(s.members.Fraktur, "a group member is noted as present")
assert(#NS.FindAward(s, a1.id).id == 12 and select(2, NS.FindAward(s, a1.id)) == 1 and not select(3, NS.FindAward(s, a1.id)))
assert(NS.FindAward(s, "nope") == nil)
assert(NS.AwardCount(s) == 3, "tombstones are not counted")

---------------------------------------------------------------------------
-- an old raid: no s.last, no invented attendance
---------------------------------------------------------------------------
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Der Schwarze Tempel", instanceID = 564,
              start = 1700000000, last = 1700003600, members = { Vuloo = { class = "PRIEST", first = 1700000000, last = 1700003600 } },
              loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, old)
local before = #STUB.messages
local o1 = NS.AddAwardTo(old, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Stormrage", manual = true })
assert(o1 and old.awards[1] == o1 and old.last == 1700003600, "s.last untouched")
assert(not old.members.Fraktur, "a name outside the old raid's members is not added")
assert(#STUB.messages == before, "no group hint for an old raid")
local o2 = NS.AddAwardTo(old, { name = "Vuloo", item = 32837, kind = "OS", src = "?" })
assert(old.members.Vuloo and old.members.Vuloo.last >= o2.t, "a member of that raid is noted")
assert(NS.Active() == s, "the active recording is unchanged")
-- refusals
local ok, why = NS.AddAwardTo(nil, { name = "Fraktur", item = 32235 })
assert(ok == nil and why:find("Keine Aufnahme", 1, true), tostring(why))
ok, why = NS.AddAwardTo(old, { name = "", item = 32235 })
assert(ok == nil and why == "Name oder Item fehlt.")
ok, why = NS.AddAwardTo(old, { name = "Fraktur" })
assert(ok == nil and why == "Name oder Item fehlt.")
-- bank and disenchant entries: kind "-", receiver "-" when none is given
local b = NS.AddAwardTo(old, { name = nil, item = 32235, kind = "MS", src = "?", to = "bank" })
assert(b and b.to == "bank" and b.name == "-" and b.kind == "-")
local d = NS.AddAwardTo(old, { name = "Vuloo", item = 32235, kind = "MS", src = "?", to = "de" })
assert(d and d.to == "de" and d.name == "Vuloo" and d.kind == "-")
assert(NS.AddAwardTo(old, { name = "Vuloo", item = 1, to = "elsewhere" }).to == "player", "unknown target means player")
-- notes are cleaned on entry
local n = NS.AddAwardTo(old, { name = "Vuloo", item = 1, note = " Tausch |mit|\nVuloo " })
assert(n.note == "Tausch mit Vuloo", "no bars, no line breaks, trimmed: " .. tostring(n.note))
assert(NS.AddAwardTo(old, { name = "Vuloo", item = 1, note = "   " }).note == nil, "an empty note is no note")

---------------------------------------------------------------------------
-- editing
---------------------------------------------------------------------------
local t0 = STUB.now
STUB.tick(10)
fired = 0
local e = NS.EditAward(s, a1.id, { name = "Frakture" })
assert(e == a1 and a1.name == "Frakture" and a1.orig == "Fraktur" and a1.edited == STUB.now and a1.edited > t0, "name change sets orig and edited")
assert(a1.id == ("%08x%04x"):format(a1.t, 7), "the id never changes")
assert(fired == 1)
assert(not s.members.Frakture, "a typo does not invent a raider")
NS.EditAward(s, a1.id, { name = "Vuloo" })
assert(a1.name == "Vuloo" and a1.orig == "Fraktur", "orig is set only once")
assert(NS.EditAward(s, a1.id, { name = "" }) == nil, "an empty name is refused")
assert(a1.name == "Vuloo")
assert(NS.EditAward(s, a1.id, { kind = "OS" }).kind == "OS")
assert(NS.EditAward(s, a1.id, { kind = "bogus" }).kind == "OS", "an unknown kind changes nothing")
NS.EditAward(s, a1.id, { note = "Tausch | mit\nVuloo" })
assert(a1.note == "Tausch  mit Vuloo", "bar and line break removed: " .. tostring(a1.note))
NS.EditAward(s, a1.id, { note = ("x"):rep(70) })
assert(#a1.note == 60, "cut to 60 characters")
NS.EditAward(s, a1.id, { note = ("x"):rep(59) .. "ü" .. "y" })
assert(#a1.note == 59 and a1.note:sub(-1) == "x", "a cut never splits a character: " .. #a1.note)
NS.EditAward(s, a1.id, { note = "" })
assert(a1.note == nil, "an empty note is removed")
NS.EditAward(s, a1.id, { to = "bank" })
assert(a1.to == "bank" and a1.kind == "-" and a1.name == "Vuloo", "bank keeps the receiver, kind becomes -")
NS.EditAward(s, a1.id, { kind = "MS" })
assert(a1.kind == "-", "a bank award has no kind")
NS.EditAward(s, a1.id, { to = "player", kind = "MS" })
assert(a1.to == "player" and a1.kind == "MS")
NS.EditAward(s, a1.id, { to = "de" })
assert(a1.to == "de" and a1.kind == "-")
assert(NS.EditAward(s, a1.id, { to = "somewhere" }).to == "de", "unknown target changes nothing")
ok, why = NS.EditAward(s, "000000000000", { kind = "OS" })
assert(ok == nil and why == "Vergabe nicht mehr vorhanden.", tostring(why))
-- a change without a difference leaves no mark
local edited = a1.edited
STUB.tick(5)
assert(NS.EditAward(s, a1.id, { to = "de", name = "Vuloo" }) == a1 and a1.edited == edited, "no change, no edited stamp")

---------------------------------------------------------------------------
-- delete and restore
---------------------------------------------------------------------------
local gone = NS.DeleteAward(s, a2.id)
assert(gone == a2 and #s.awards == 2 and s.gone[#s.gone] == a2 and a2.deleted == STUB.now, "moved to the tombstones")
local fa, fi, inGone = NS.FindAward(s, a2.id)
assert(fa == a2 and fi == #s.gone and inGone == true)
ok, why = NS.DeleteAward(s, a2.id)
assert(ok == nil and why == "Vergabe nicht mehr vorhanden.", "a tombstone cannot be deleted again")
ok, why = NS.EditAward(s, a2.id, { kind = "MS" })
assert(ok == nil and why == "Vergabe nicht mehr vorhanden.", "a tombstone cannot be edited")
assert(NS.AwardCount(s) == 2)
-- restore puts it back between a1 (same t) and a3 (later)
local back = NS.RestoreAward(s, a2.id)
assert(back == a2 and a2.deleted == nil and #s.gone == 1, "back from the tombstones")
assert(s.awards[1] == a1 and s.awards[2] == a2 and s.awards[3] == a3, "sorted back in by time")
assert(NS.RestoreAward(s, a2.id) == nil, "a living award is not restored")
assert(NS.RestoreAward(s, "000000000000") == nil)

---------------------------------------------------------------------------
-- undo: add, edit, delete, and the 20 step limit
---------------------------------------------------------------------------
assert(NS.UndoLabel() and NS.UndoLabel():find("Wiederherstellen", 1, true), tostring(NS.UndoLabel()))
local label = NS.UndoAward()
assert(label and label:find("Wiederherstellen von Cursed Vision of Sargeras an Vuloo", 1, true), tostring(label))
assert(#s.awards == 2 and s.gone[#s.gone] == a2, "undoing a restore deletes again")
assert(NS.UndoLabel():find("Löschen von Cursed Vision of Sargeras an Vuloo", 1, true), NS.UndoLabel())
NS.UndoAward()
assert(s.awards[2] == a2 and a2.deleted == nil, "undoing a delete restores")
-- the stack now holds the edits of a1; undoing one puts the old fields back with a fresh edited stamp
assert(a1.to == "de")
STUB.tick(5)
assert(NS.UndoLabel():find("Ändern von Cursed Vision of Sargeras an Vuloo", 1, true), NS.UndoLabel())
NS.UndoAward()
assert(a1.to == "player" and a1.kind == "MS" and a1.edited == STUB.now, "old fields back, edited is now")
-- undo everything that is left: the first edit undone removes orig again
while NS.UndoAward() do end
assert(a1.name == "Fraktur" and a1.orig == nil and a1.edited == STUB.now, "the first edit undone: no orig, still stamped")
assert(NS.UndoLabel() == nil and NS.UndoAward() == nil, "empty stack")
assert(select(3, NS.FindAward(s, a3.id)) == true, "the add of a3 undone: a tombstone")
assert(#old.awards == 0 and #old.gone == 7, "the old raid's additions were undone too")
assert(NS.FindAward(s, a1.id) == a1 and not select(3, NS.FindAward(s, a1.id)), "the oldest steps had left the stack: a1 stays")
-- a step whose raid was deleted is skipped
local temp = { id = "20260902200000-564", date = "2026-09-02", zone = "Hyjal", instanceID = 534, start = 1, last = 1,
               members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, temp)
NS.AddAwardTo(temp, { name = "Vuloo", item = 32235, kind = "MS", src = "?" })
NS.EditAward(s, a1.id, { kind = "OS" })
NS.DeleteSessions({ [temp.id] = true })
NS.UndoAward()
assert(a1.kind == "MS", "the edit on the living raid is undone")
assert(NS.UndoAward() == nil, "the step of the deleted raid is skipped")
-- 20 steps: the 21st pushes the oldest out
for i = 1, 25 do NS.EditAward(s, a1.id, { note = "n" .. i }) end
local steps = 0
while NS.UndoAward() do steps = steps + 1 end
assert(steps == 20, "20 steps: " .. steps)
assert(a1.note == "n5", "the oldest five steps fell off the stack: " .. tostring(a1.note))

---------------------------------------------------------------------------
-- /amisia unaward goes through the book and is undoable
---------------------------------------------------------------------------
local live = #s.awards
NS.AwardCommand("Fraktur " .. link .. " os")
local manual = s.awards[#s.awards]
assert(#s.awards == live + 1 and manual.kind == "OS" and manual.id and manual.to == "player" and manual.manual == true)
NS.AwardCommand("unaward")
assert(#s.awards == live and s.gone[#s.gone] == manual and manual.deleted, "unaward leaves a tombstone")
assert(lastMsg():find("Vergabe entfernt", 1, true), lastMsg())
assert(NS.UndoAward():find("Löschen", 1, true))
assert(s.awards[#s.awards] == manual and manual.deleted == nil, "unaward undone")
NS.DeleteAward(s, manual.id)
while #s.awards > 0 do NS.AwardCommand("unaward") end
assert(#s.gone >= 4, "every award of the recording is a tombstone now")
NS.AwardCommand("unaward")
assert(lastMsg():find("Keine Vergabe", 1, true), lastMsg())
assert(NS.RemoveLastAward() == nil)

---------------------------------------------------------------------------
-- name suggestions and renaming
---------------------------------------------------------------------------
local f = { id = "20260903200000-564", date = "2026-09-03", zone = "Schwarzer Tempel", instanceID = 564, start = 1, last = 1,
            members = { ["Vulo Sturmwind"] = { class = "MAGE", first = 1, last = 1 }, ["Vulo Stein"] = { class = "WARRIOR", first = 1, last = 1 },
                        ["Fraktur Stein"] = { class = "SHAMAN", first = 1, last = 1 }, ["Vuloo Nacht"] = { class = "PRIEST", first = 1, last = 1 } },
            loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, f)
local sug = NS.NameSuggestions(f, "Vulo")
assert(#sug == 2 and sug[1] == "Vulo Stein" and sug[2] == "Vulo Sturmwind", table.concat(sug, ","))
assert(#NS.NameSuggestions(f, "vulo sturm") == 2, "the same first name is enough")
assert(#NS.NameSuggestions(f, "Vulo Sturmwind") == 0, "a known name needs no suggestion")
assert(#NS.NameSuggestions(f, "Niemand") == 0)
local x1 = NS.AddAwardTo(f, { name = "Vulo", item = 32235, kind = "MS", src = "?" })
local x2 = NS.AddAwardTo(f, { name = "Vulo", item = 32837, kind = "OS", src = "?" })
local x3 = NS.AddAwardTo(f, { name = "Fraktur Stein", item = 32837, kind = "MS", src = "?" })
STUB.tick(3)
assert(NS.RenameAwards(f, "Vulo", "Vulo Sturmwind") == 2)
assert(x1.name == "Vulo Sturmwind" and x2.name == "Vulo Sturmwind" and x1.orig == "Vulo" and x2.orig == "Vulo", "both renamed, orig kept")
assert(x1.edited == STUB.now and x3.name == "Fraktur Stein" and x3.edited == nil, "the other award is untouched")
assert(NS.RenameAwards(f, "Vulo", "Vulo Sturmwind") == 0, "nothing left to rename")
assert(NS.UndoLabel():find("Umbenennen von Vulo", 1, true), NS.UndoLabel())
NS.UndoAward()
assert(x1.name == "Vulo" and x2.name == "Vulo" and x1.orig == nil, "one undo step for the whole rename")
assert(#NS.NameSuggestions(f, "Vulo") == 2, "suggestions again after the undo")

---------------------------------------------------------------------------
-- master loot to the bank or disenchant character
---------------------------------------------------------------------------
assert(NS.IsSpecialName("Vulobank") == nil, "no bank character set")
assert(NS.Set("awards.bankName", "Vulobank") and NS.Get("awards.bankName") == "Vulobank")
assert(NS.Set("awards.deName", " Vuloo ") and NS.Get("awards.deName") == "Vuloo", "names are tidied")
assert(not NS.Set("awards.bankName", "Vulo1"), "digits refused")
assert(not NS.Set("awards.bankName", "Vulo von Bank"), "two spaces refused")
assert(NS.Set("awards.bankName", "") and NS.Get("awards.bankName") == "")
assert(NS.IsSpecialName("Vulobank") == nil)
NS.Set("awards.bankName", "Vulobank")
assert(NS.IsSpecialName("Vulobank") == "bank" and NS.IsSpecialName("vulobank-Realm") == "bank" and NS.IsSpecialName("Vuloo") == "de")
assert(NS.IsSpecialName("Fraktur") == nil)
STUB.roster[3] = { name = "Vulobank", class = "WARRIOR" }
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras", src = "Creature-0-1-1-1-22917-1" } }
STUB.target, STUB.targetGUID = "Illidan Stormrage", "Creature-0-1-1-1-22917-1"
STUB.fire("LOOT_OPENED")
NS.RollKind = function() return "MS" end
GiveMasterLoot(1, 3)
STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Vulobank", link))
local bank = s.awards[#s.awards]
assert(bank and bank.to == "bank" and bank.name == "Vulobank" and bank.kind == "-" and bank.src == "Illidan Stormrage", "master loot to the bank character")
assert(lastMsg():find("Bank", 1, true), lastMsg())
GiveMasterLoot(1, 1)
STUB.fire("LOOT_SLOT_CLEARED", 1)
local de = s.awards[#s.awards]
assert(de.to == "de" and de.name == "Vuloo" and de.kind == "-", "master loot to the disenchanter")
GiveMasterLoot(1, 2)
STUB.fire("LOOT_SLOT_CLEARED", 1)
assert(s.awards[#s.awards].to == "player" and s.awards[#s.awards].kind == "MS", "anyone else is a player")
NS.RollKind = nil

---------------------------------------------------------------------------
-- the settings section and its text rows
---------------------------------------------------------------------------
local sec
for _, x in ipairs(NS.schema) do if x.key == "awards" then sec = x end end
assert(sec and sec.order == 25 and sec.officer and sec.label == "Vergaben")
assert(NS.SettingItem("awards.bankName").type == "text" and NS.SettingItem("awards.deName").type == "text")
assert(NS.Get("awards.plusScope") == "raid" and NS.Get("awards.plusOrder") == false and NS.Get("awards.modClick") == true)
assert(NS.Set("awards.plusScope", "week") and not NS.Set("awards.plusScope", "month"))
NS.ShowPage("settings"); NS.Refresh()
assert(NS.SettingsRows()["awards.bankName"] and NS.SettingsRows()["awards.bankName"]:IsShown(), "the text row is placed without a control")
