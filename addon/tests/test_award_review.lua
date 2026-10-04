-- Review fixes of the award book: the undo label names the step undo really takes back, and a
-- bank or disenchant award may lose its receiver.
STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.item(32837, "Warglaive of Azzinoth", 5)

local function raid(id)
    return { id = id, date = "2026-09-01", zone = "BT", instanceID = 564, start = 1, last = 1,
             members = { Fraktur = { class = "SHAMAN", first = 1, last = 1 } },
             loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
end

---------------------------------------------------------------------------
-- a step whose raid was deleted: the label skips it like undo does
---------------------------------------------------------------------------
local r1, r2 = raid("20260901200000-564"), raid("20260902200000-564")
AmisiaDB.sessions = { r1, r2 }
local a1 = assert(NS.AddAwardTo(r1, { name = "Fraktur", item = 32235, kind = "MS", t = 100 }))
assert(NS.AddAwardTo(r2, { name = "Fraktur", item = 32837, kind = "MS", t = 200 }))
assert(NS.UndoLabel():find("Warglaive", 1, true), NS.UndoLabel())
NS.DeleteSessions({ [r2.id] = true })
local label = NS.UndoLabel()
assert(label and label:find("Cursed Vision", 1, true), "the label names the step undo takes back: " .. tostring(label))
local done = NS.UndoAward()
assert(done == label, "undo does what the label said: " .. tostring(done))
assert(select(3, NS.FindAward(r1, a1.id)) == true, "the add in the living raid is undone")
assert(NS.UndoLabel() == nil and NS.UndoAward() == nil, "nothing left")

-- a step whose award is gone already (an edit of a deleted award) is skipped the same way
local a2 = assert(NS.AddAwardTo(r1, { name = "Fraktur", item = 32837, kind = "MS", t = 300 }))
NS.EditAward(r1, a2.id, { kind = "OS" })
NS.RestoreAward(r1, a1.id)
local a1b = select(1, NS.FindAward(r1, a1.id))
assert(a1b and not select(3, NS.FindAward(r1, a1.id)))
assert(NS.UndoLabel():find("Wiederherstellen", 1, true), NS.UndoLabel())
assert(NS.UndoAward():find("Wiederherstellen", 1, true))
assert(NS.UndoLabel():find("Ändern von Warglaive", 1, true), NS.UndoLabel())

---------------------------------------------------------------------------
-- a bank or disenchant award without a receiver
---------------------------------------------------------------------------
local b = assert(NS.AddAwardTo(r1, { item = 32235, to = "bank", t = 400 }))
assert(b.name == "-")
local ok, why = NS.EditAward(r1, b.id, { name = "Vulobank" })
assert(ok == b and b.name == "Vulobank", tostring(why))
ok, why = NS.EditAward(r1, b.id, { name = "" })
assert(ok == b and b.name == "-", "an empty name on a bank award means no receiver: " .. tostring(why))
local d = assert(NS.AddAwardTo(r1, { name = "Fraktur", item = 32837, kind = "MS", t = 500 }))
ok, why = NS.EditAward(r1, d.id, { to = "de", name = "" })
assert(ok == d and d.to == "de" and d.name == "-" and d.kind == "-", tostring(why))
-- a player award still needs a name, also when it comes back from the bank without one
ok, why = NS.EditAward(r1, a2.id, { name = "" })
assert(ok == nil and why == "Name oder Item fehlt." and a2.name == "Fraktur")
ok, why = NS.EditAward(r1, d.id, { to = "player" })
assert(ok == nil and why == "Name oder Item fehlt." and d.to == "de" and d.name == "-", "no player named -")
ok = NS.EditAward(r1, d.id, { to = "player", name = "Fraktur", kind = "OS" })
assert(ok == d and d.to == "player" and d.name == "Fraktur" and d.kind == "OS")
