-- Existing behaviour: a session starts in a raid instance, records the roster and epic loot.
assert(AmisiaDB and AmisiaDB.sessions, "DB initialised")
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "session started in a raid instance")
assert(s.members.Fraktur, "roster recorded")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format("Fraktur", link))
assert(#s.items == 1 and s.items[1].name == "Fraktur", "epic loot recorded")
local txt = NS.ExportText({ s })
assert(txt:find("\nI Fraktur 32235 1\n", 1, true), txt)
