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
