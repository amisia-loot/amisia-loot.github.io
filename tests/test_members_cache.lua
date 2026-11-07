-- The page Mitglieder (F-104, F-133) keeps its rows while what they come from stays: a search, a
-- filter or a sort only filters them again; a new roster, a crafters change, a new version seen, an
-- alt list change or new data build them again. Prof.FromNote keeps its answer per note text.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local Pr, Cr = NS.Prof, NS.Crafters
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")

-- Prof.FromNote: the same answer for the same note, a different note its own
local a = Pr.FromNote("Alchi 300 / Kräuter")
assert(a == Pr.FromNote("Alchi 300 / Kräuter"), "the same note: the kept answer")
assert(#a == 2 and a[1].skill == 171 and a[1].rank == 300 and a[2].skill == 182 and a[2].rank == nil, "read once")
local b = Pr.FromNote("BS 225, Mining")
assert(b ~= a and b[1].skill == 164 and b[1].rank == 225 and b[2].skill == 186, "another note")
assert(#Pr.FromNote("") == 0 and #Pr.FromNote(nil) == 0, "nothing")
for i = 1, 2100 do Pr.FromNote("Notiz " .. i) end
local a2 = Pr.FromNote("Alchi 300 / Kräuter")
assert(#a2 == 2 and a2[1].rank == 300, "after the memo was emptied the note reads the same")

STUB.player = "Vuloo"
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 60, zone = "Sturmwind" },
    { name = "Anna Amboss", class = "WARRIOR", rank = 3, level = 58, zone = "Eisenschmiede", note = "Schmiedin 225" },
    { name = "Bob", class = "MAGE", rank = 4, level = 60, zone = "Tanaris", note = "Alchi 300" },
    { name = "Carla", class = "PRIEST", rank = 3, level = 42, online = false, last = { 0, 0, 2, 19 } },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

local seen, rev = {}, 0
NS.VersionSeen = function() return seen end
NS.VersionSeenRev = function() return rev end

NS.ShowPage("members")
local f = assert(NS.PageFrame("members"))
assert(#f.list.items == 4, #f.list.items)
local first = f.list.items[1]
local function row(name)
    for _, e in ipairs(f.list.items) do if e.name == name then return e end end
end
local bob = row("Bob")
assert(bob.profs and bob.profs[1].skill == 171 and bob.profs[1].note, "Bob's note names alchemy")

-- the search, a filter and a sort keep the rows
f.search:SetText("bob")
f.search.scripts.OnEnterPressed(f.search)
assert(#f.list.items == 1 and f.list.items[1] == bob, "the search filters the same rows")
f.search:SetText("")
f.search.scripts.OnEnterPressed(f.search)
AmisiaDB.settings.window.members.sort = "level"
NS.Refresh()
assert(row("Bob") == bob, "a sort keeps the rows")
AmisiaDB.settings.window.members.sort = nil
AmisiaDB.settings.window.members.class = "MAGE"
NS.Refresh()
assert(#f.list.items == 1 and f.list.items[1] == bob, "a class filter keeps the rows")
AmisiaDB.settings.window.members.class = "all"
NS.Refresh()
assert(f.list.items[1] == first, "the same rows")

-- a new version seen: built again, with it
seen = { { name = "Bob", v = "2.56.0" } }
rev = rev + 1
NS.Refresh()
assert(row("Bob") ~= bob and row("Bob").version == "2.56.0" and row("Bob").amisia, "a new version builds again")
bob = row("Bob")

-- the crafters change: built again
Cr.Changed()
NS.Refresh()
assert(row("Bob") ~= bob, "a crafters change builds again")
bob = row("Bob")

-- the alt list changes: built again
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-06\nA Bob Anna_Amboss\n#END"))
NS.Refresh()
assert(row("Bob") ~= bob, "an alt list change builds again")
bob = row("Bob")

-- a new roster (rebuilt after its 10 s): built again, a new note read
STUB.guild[3].note = "BS 225, Mining"
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.Refresh()
local nb = row("Bob")
assert(nb ~= bob and nb.profs[1].skill == 164 and nb.profs[2].skill == 186, "a new roster builds again with the new note")
assert(has(f.data:GetText(), "4 Mitglieder"), tostring(f.data:GetText()))
