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

---------------------------------------------------------------------------
-- The lines of 1.7: EK per boss attempt after the AD lines, EP right after a kill with names, BN
-- per bench entry. A raid without kills and bench exports what 1.6 wrote, fingerprint included.
---------------------------------------------------------------------------
local plain16 = { id = "20260902200000-564", date = "2026-09-02", zone = "Der Schwarze Tempel", instanceID = 564,
                  start = 1, last = 1, members = { Vuloo = { class = "PRIEST", first = 100, last = 100 } },
                  loot = {}, items = {}, drops = {}, awards = {} }
local block16 = "S 20260902200000-564 2026-09-02 564 Der Schwarze Tempel\nM Vuloo PRIEST 100 0\nE"
assert(NS.SessionHash(plain16) == NS.Checksum(block16), "a raid of 1.6 without the new fields")
local text16 = NS.ExportText({ plain16 })
plain16.kills, plain16.bench, plain16.outside = {}, {}, {}
assert(NS.ExportText({ plain16 }) == text16, "empty kills and bench write nothing new")
assert(NS.SessionHash(plain16) == NS.Checksum(block16), "and keep the fingerprint of 1.6")
assert(text16:find("\n" .. block16:gsub("%-", "%%-") .. "\n"), text16)

local r17 = { id = "20260903200000-564", date = "2026-09-03", zone = "Der Schwarze Tempel", instanceID = 564,
              start = 1, last = 1,
              members = { Vuloo = { class = "PRIEST", first = 100, last = 3000 },
                          ["Vulo Sturmwind"] = { class = "MAGE", first = 100, last = 3000 } },
              loot = {}, items = {}, drops = {}, awards = {},
              gone = { { id = "0000aaaa0001", item = 32235, t = 500, deleted = 600 } },
              kills = {
                  { enc = 602, name = "Supremus", start = 1300, t = 1421, ok = false, size = 25, diff = 4, src = "enc", n = 2 },
                  { enc = 601, name = "Hochkriegsfürst Naj'entus", start = 1000, t = 1192, ok = true, size = 25, diff = 4,
                    src = "enc", who = { "Vuloo", "Vulo Sturmwind" }, n = 2 },
                  { enc = 0, name = "Mutter Shahraz", start = 2000, t = 2000, ok = true, size = 0, diff = 0, src = "loot",
                    who = { "Vuloo" }, n = 1 },
                  { enc = 603, name = "Schattenmond", start = 2500, t = 2600, ok = true, size = 25, diff = 4, src = "kill",
                    wait = true, n = 2 },
                  { enc = 0, name = "Teron Blutschatten", start = 3000, t = 3000, ok = true, size = 0, diff = 0, src = "hand",
                    who = {}, n = 0 },
              },
              bench = { Bob = { t = 900, class = "MAGE", self = true, note = "ab 21 Uhr" },
                        ["Kim Eisherz"] = { t = 950, class = "", by = "Vuloo" } },
              outside = { Bob = 2900 } }
out = lines(NS.ExportText({ r17 }))
local iS = find(out, "S 20260903200000-564 ")
local block = {}
for i = iS, #out do block[#block + 1] = out[i]; if out[i] == "E" then break end end
local want = {
    "S 20260903200000-564 2026-09-03 564 Der Schwarze Tempel",
    "M Vulo_Sturmwind MAGE 100 0",
    "M Vuloo PRIEST 100 0",
    "AD 0000aaaa0001 32235 500 600",
    "EK 601 1000 1192 K 25 4 E Hochkriegsfürst Naj'entus",
    "EP 601 1192 Vulo_Sturmwind Vuloo",
    "EK 602 1300 1421 W 25 4 E Supremus",
    "EK 0 2000 2000 K 0 0 L Mutter Shahraz",
    "EP 0 2000 Vuloo",
    "EK 603 2500 2600 K 25 4 B Schattenmond",
    "EK 0 3000 3000 K 0 0 H Teron Blutschatten",
    "BN Bob MAGE 900 S - ab 21 Uhr",
    "BN Kim_Eisherz UNKNOWN 950 O Vuloo",
    "E",
}
assert(table.concat(block, "\n") == table.concat(want, "\n"), "the block of 1.7:\n" .. table.concat(block, "\n"))
assert(not table.concat(out, "\n"):find("2900"), "the group outside stays out of the export")

-- the legacy form writes none of the new lines
local legacy17 = NS.SessionHash(r17, true)
local keepK, keepB = r17.kills, r17.bench
r17.kills, r17.bench = {}, {}
assert(NS.SessionHash(r17, true) == legacy17, "the 1.4 form ignores kills and bench")
r17.kills, r17.bench = keepK, keepB

-- the fingerprint moves with a new kill, a deleted kill, a bench change and names read after a fight
local hk = NS.SessionHash(r17)
local last17 = r17.last
local added = NS.AddKill(r17, { name = "Illidan Sturmgrimm", t = 4000 })
assert(added and r17.last == last17)
local hk2 = NS.SessionHash(r17)
assert(hk2 ~= hk, "a new kill changes the fingerprint")
assert(NS.DeleteKill(r17, added) and NS.SessionHash(r17) == hk, "deleting it restores it")
assert(NS.BenchAdd(r17, "Fred"))
local hb = NS.SessionHash(r17)
assert(hb ~= hk, "a bench entry changes the fingerprint")
r17.bench.Bob.note = "ab 22 Uhr"
assert(NS.SessionHash(r17) ~= hb, "a bench note changes the fingerprint")
r17.bench.Bob.note = "ab 21 Uhr"
assert(NS.BenchRemove(r17, "Fred") and NS.SessionHash(r17) == hk, "removing it restores it")
local waiting = r17.kills[4]
assert(waiting.name == "Schattenmond" and waiting.wait)
waiting.who = { "Vuloo" }
assert(NS.SessionHash(r17) == hk, "names still waiting write no EP")
waiting.wait = nil
assert(NS.SessionHash(r17) ~= hk, "the EP once the names are read")
assert(find(lines(NS.ExportText({ r17 })), "EP 603 2600 Vuloo"))
