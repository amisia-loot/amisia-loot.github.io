-- Review 2026-10-12 (SoftRes): a name fix of the loaded list ("Bob" -> "Bob Stein") renames it
-- everywhere: the reservations and also the code's note, class and softres +1 of that name.
local fh = assert(io.open(ADDON_DIR .. "/../tests/fixtures/softres_sample.txt", "rb"))
local SAMPLE = fh:read("*a"):gsub("%s+$", "")
fh:close()
STUB.item(17076, "Bonereaver's Edge", 4)
NS.Set("ui.view", "officer")
local count, _, err = NS.SetSoftRes(SAMPLE)
assert(not err and count == 3, tostring(err))
local sr = AmisiaDB.softres
assert(sr.notes.Bob == "Tank" and sr.plus.Bob == 1, "the sample's note and softres +1 of Bob")
local before = NS.SoftResTooltipText(17076)
assert(before:find("Tank", 1, true) and before:find("softres +1: 1", 1, true), before)

assert(NS.RenameReserve("Bob", "Bob Stein", false) == 1)
assert(NS.ReservedBy(17076)[1] == "Bob Stein", "the reservation goes to the new name")
local after = NS.SoftResTooltipText(17076)
assert(after:find("Bob Stein", 1, true), after)
assert(after:find("Tank", 1, true) and after:find("softres +1: 1", 1, true), "the note and the softres +1 follow the name: " .. after)
assert(sr.notes.Bob == nil and sr.plus.Bob == nil, "nothing stays under the old name")
assert(sr.notes["Bob Stein"] == "Tank" and sr.plus["Bob Stein"] == 1)
assert(sr.classes["Bob Stein"] == "Warrior" and sr.classes.Bob == nil, "the class follows the name too")
NS.Reset("ui.view")
