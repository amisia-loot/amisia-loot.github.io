-- Export marks: without a selection only sessions that are new or changed since their last export
-- are exported, and a fresh guild bank count travels once.
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(NS.ExportState(s) == "new" and NS.ExportedAt(s) == nil)
assert(#NS.PendingExport() == 1)

NS.ShowExport(false)
assert(lastMsg():find("Export: 1 neue oder geänderte Raid", 1, true), lastMsg())
assert(NS.ExportState(s) == "done" and NS.ExportedAt(s))
assert(#NS.PendingExport() == 0)

-- roster snapshots alone change nothing the export would carry
STUB.tick(61)
assert(NS.ExportState(s) == "done", "a snapshot without news keeps it exported")

NS.ShowExport(false)
assert(lastMsg():find("Nichts Neues", 1, true), lastMsg())

-- new loot makes it changed, and the next export carries it again
local mark = STUB.item(32897, "Mal der Illidari", 4)
STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur", mark))
assert(NS.ExportState(s) == "changed")
NS.ShowExport(false)
assert(lastMsg():find("Export: 1 neue", 1, true) and NS.ExportState(s) == "done")

-- an older session that was never exported comes along, the exported one stays out
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Der Schwarze Tempel", instanceID = 564,
              start = 1, last = 1, members = { Vuloo = { class = "PRIEST", first = 1, last = 1 } },
              loot = {}, items = {}, drops = {}, awards = {} }
table.insert(AmisiaDB.sessions, 1, old)
local pend = NS.PendingExport()
assert(#pend == 1 and pend[1] == old)
local txt = NS.ExportText(pend)
assert(txt:find("\nS 20260901200000%-564 ") and not txt:find("\nS " .. s.id:gsub("%-", "%%-") .. " "), txt)

-- /amisia export (newest session) marks what it showed as exported too
NS.ShowExport(true)
assert(NS.ExportState(s) == "done" and NS.ExportState(old) == "new")
NS.ShowExport(false)
assert(NS.ExportState(old) == "done")

-- a fresh bank count alone is still exported, once
AmisiaDB.bank = { at = time(), by = "Vuloo", counts = { [32897] = 3 }, tabs = 2, filled = 2, total = 2 }
assert(NS.BankPending())
NS.ShowExport(false)
assert(lastMsg():find("Export: 0 neue oder geänderte Raid(s) und die Gildenbank", 1, true), lastMsg())
assert(not NS.BankPending())
NS.ShowExport(false)
assert(lastMsg():find("Nichts Neues", 1, true), lastMsg())

-- the fingerprint changes with any exported detail, here the late mark
local h = NS.SessionHash(s)
s.members.Fraktur.late = true
assert(NS.SessionHash(s) ~= h and NS.ExportState(s) == "changed")

---------------------------------------------------------------------------
-- The lines of 1.5: A stays byte for byte as in 1.4, AX follows every A and AS, AS replaces A for
-- the bank and disenchanting, AD marks a tombstone, their items are named, and the fingerprint
-- moves with a note, a deletion and an undo.
---------------------------------------------------------------------------
STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)
STUB.item(32838, "Warglaive of Azzinoth", 5)
local plain = NS.AddAwardTo(s, { name = "Fraktur", item = 32235, kind = "MS", src = "Illidan Sturmgrimm", t = 1757444400 })
local noted = NS.AddAwardTo(s, { name = "Vulo Sturmwind", item = 32837, kind = "OS", src = "Illidan Sturmgrimm", t = 1757444460, note = "Tausch mit Vuloo" })
local bank = NS.AddAwardTo(s, { name = "Vulo Bank", item = 32838, kind = "MS", src = "Illidan Sturmgrimm", t = 1757444520, to = "bank" })
local de = NS.AddAwardTo(s, { item = 32897, src = "Mutter Shahraz", t = 1757444580, to = "de" })
assert(plain and noted and bank and de)
local function lines(text)
    local out = {}
    for l in (text .. "\n"):gmatch("(.-)\n") do out[#out + 1] = l end
    return out
end
local function find(list, prefix)
    for i, l in ipairs(list) do if l:sub(1, #prefix) == prefix then return i, l end end
end

local out = lines(NS.ExportText({ s }))
local iA, lA = find(out, "A Fraktur ")
assert(lA == "A Fraktur 32235 1757444400 MS Illidan Sturmgrimm", "the A line of 1.4: " .. tostring(lA))
assert(out[iA + 1] == ("AX %s 0 -"):format(plain.id), "AX right after the A line, nothing edited, no note: " .. tostring(out[iA + 1]))
local iN, lN = find(out, "A Vulo_Sturmwind ")
assert(lN == "A Vulo_Sturmwind 32837 1757444460 OS Illidan Sturmgrimm", tostring(lN))
assert(out[iN + 1] == ("AX %s 0 - Tausch mit Vuloo"):format(noted.id), "the note is the last field: " .. tostring(out[iN + 1]))
local iB, lB = find(out, "AS ")
assert(lB == ("AS %s 32838 1757444520 BANK Vulo_Bank Illidan Sturmgrimm"):format(bank.id), "a bank award is an AS line: " .. tostring(lB))
assert(out[iB + 1] == ("AX %s 0 -"):format(bank.id), "AX after the AS line too")
local _, lD = find(out, ("AS %s "):format(de.id))
assert(lD == ("AS %s 32897 1757444580 DE - Mutter Shahraz"):format(de.id), "disenchant without a receiver: " .. tostring(lD))
for _, l in ipairs(out) do
    assert(not l:find("^A %-? ") and not l:find("^A Vulo_Bank"), "bank and disenchant are no A lines: " .. l)
    assert(not l:find("^AD "), "no tombstone yet: " .. l)
end
assert(find(out, "N 32838 5 ") and find(out, "N 32897 "), "AS items are named")

-- the fingerprint moves with a note, an edit, a deletion and the undo of it
local h0 = NS.SessionHash(s)
NS.EditAward(s, plain.id, { note = "Zweitwahl" })
local h1 = NS.SessionHash(s)
assert(h1 ~= h0, "a note changes the fingerprint")
assert(NS.ExportState(s) == "changed")
STUB.tick(1)
NS.EditAward(s, plain.id, { name = "Frakture" })
out = lines(NS.ExportText({ s }))
local iE, lE = find(out, "A Frakture ")
assert(lE == "A Frakture 32235 1757444400 MS Illidan Sturmgrimm", tostring(lE))
assert(out[iE + 1] == ("AX %s %d Fraktur Zweitwahl"):format(plain.id, plain.edited), "edited time, first winner and note: " .. tostring(out[iE + 1]))
local h2 = NS.SessionHash(s)
assert(h2 ~= h1, "an edit changes the fingerprint")
NS.DeleteAward(s, noted.id)
local h3 = NS.SessionHash(s)
assert(h3 ~= h2, "a deletion changes the fingerprint")
out = lines(NS.ExportText({ s }))
assert(not find(out, "A Vulo_Sturmwind "), "a deleted award has no A line")
local _, lG = find(out, "AD ")
assert(lG == ("AD %s 32837 1757444460 %d"):format(noted.id, noted.deleted), "the tombstone line: " .. tostring(lG))
assert(find(out, "N 32837 5 "), "a tombstone's item is named")
assert(find(out, "E") , "the block still ends")
local iAD = find(out, "AD ")
assert(out[iAD + 1] == "E", "tombstones come last in the block")
NS.UndoAward()
assert(NS.SessionHash(s) == h2, "undoing the deletion restores the fingerprint")
assert(not find(lines(NS.ExportText({ s })), "AD "), "no tombstone after the undo")
-- the legacy form knows none of it
local legacy = NS.SessionHash(s, true)
NS.EditAward(s, plain.id, { note = "anders" })
assert(NS.SessionHash(s, true) == legacy, "the 1.4 form ignores notes")
assert(NS.SessionHash(s) ~= h2)
