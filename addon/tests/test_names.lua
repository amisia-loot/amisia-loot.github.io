-- Names: Forever "First Surname", Anniversary "Name-Realm", the same name compared everywhere,
-- and the export writing "_" for the space.
assert(NS.FullName, "Names.lua loaded")

STUB.toc = 20506
assert(NS.FullName("Fraktur-Thunderstrike") == "Fraktur", "Anniversary drops the realm")
assert(NS.FullName("  Vuloo ") == "Vuloo")
assert(NS.FullName("") == nil and NS.FullName(nil) == nil)
assert(NS.FullName("Vulo", "Thunderstrike") == "Vulo", "the second UnitName value is a realm there")

STUB.toc = 16001
assert(NS.IsForever())
assert(NS.FullName("Vulo", "Sturmwind") == "Vulo Sturmwind", "Forever adds the surname")
assert(NS.FullName("Vulo  Stein-Herz") == "Vulo Stein-Herz", "dashes belong to the surname there")
assert(NS.FullName("Vulo Sturmwind", "Sturmwind") == "Vulo Sturmwind", "no surname twice")
STUB.toc = 20506

assert(NS.SameName("Vulo Sturmwind", "vulo sturmwind"))
assert(NS.SameName("Vulo", "Vulo Sturmwind"), "a side without surname matches on the first name")
assert(not NS.SameName("Vulo Sturmwind", "Vulo Eisenfaust"))
assert(not NS.SameName("Vulo", "Vuloo"))

assert(NS.ExportName("Vulo Sturmwind") == "Vulo_Sturmwind" and NS.ExportName("Fraktur") == "Fraktur")

-- a raid with a surname goes through recording and export
STUB.roster = { { name = "Vulo Sturmwind", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.player = "Vulo Sturmwind"
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s.members["Vulo Sturmwind"], "recorded under the full name")
local txt = NS.ExportText({ s })
assert(txt:match("^#AMISIA 2 Vulo_Sturmwind\n"), txt:sub(1, 40))
assert(txt:find("\nM Vulo_Sturmwind PRIEST ", 1, true), txt)

-- soft-reserve lines with a surname
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local byItem, count, bad = NS.ParseSoftRes("vulo sturmwind " .. link .. "\nFraktur 32235")
assert(count == 2 and #bad == 0, table.concat(bad, "|"))
assert(byItem[32235][1] == "Fraktur" and byItem[32235][2] == "Vulo sturmwind", table.concat(byItem[32235], ","))

-- /amisia namen prints what the client gives
STUB.messages = {}
SlashCmdList.AMISIA("namen")
assert(table.concat(STUB.messages, "\n"):find("Vulo Sturmwind", 1, true))
