-- Review 2026-10-12 (pages): a list scrolled down starts at its top again when the page shows another
-- list in it (another soft-reserve view, another raid on the awards page), as the professions, the
-- scrolls and the gear pages already do.
STUB.instance = { name = "Dalaran", type = "none", id = 0 }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }

-- soft-reserves: 30 items, the items view scrolled, then the raider view
local lines = {}
for i = 1, 30 do lines[#lines + 1] = ("Raider%s %d"):format(string.char(96 + (i % 26) + 1) .. string.char(97 + math.floor(i / 26)), 40000 + i) end
NS.SetSoftRes(table.concat(lines, "\n"))
NS.ShowPage("softres")
local f = NS.SoftResPageFrame()
assert(#f.list.items == 30, "30 items: " .. #f.list.items)
f.list:GetScript("OnMouseWheel")(f.list, -10)
assert(f.list.offset == 10, "scrolled: " .. f.list.offset)
f.views.raider:Click()
assert(f.views.raider.on and #f.list.items >= 30, "the raider view")
assert(f.list.offset == 0, "another view starts at its top: " .. f.list.offset)
-- a refresh of the same view keeps the place
f.list:GetScript("OnMouseWheel")(f.list, -5)
NS.Refresh()
assert(f.list.offset == 5, "the same view keeps its place: " .. f.list.offset)

-- awards: two raids of 20 awards each, the first scrolled, then the other raid
STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "a recording runs")
local old = { id = "20260901200000-564", date = "2026-09-01", zone = "Der Schwarze Tempel", instanceID = 564,
              start = 1700000000, last = 1700003600, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {} }
table.insert(AmisiaDB.sessions, 1, old)
for i = 1, 20 do
    NS.AddAwardTo(old, { name = "Fraktur", item = 40000 + i, kind = "OS", src = "Illidan", t = 1700000000 + i })
    NS.AddAwardTo(s, { name = "Vuloo", item = 40000 + i, kind = "OS", src = "Illidan" })
end
NS.ShowPage("awards")
local O = NS.AwardsPageFrame().officer
assert(O.raid:GetValue() == s.id and #O.list.items == 20, "the recording's 20 awards")
O.list:GetScript("OnMouseWheel")(O.list, -6)
assert(O.list.offset == 6, "scrolled: " .. O.list.offset)
O.raid.onPick(old.id)
assert(O.raid:GetValue() == old.id and #O.list.items == 20, "the older raid")
assert(O.list.offset == 0, "another raid starts at its top: " .. O.list.offset)
O.list:GetScript("OnMouseWheel")(O.list, -3)
NS.Refresh()
assert(O.list.offset == 3, "the same raid keeps its place: " .. O.list.offset)

-- the raiders' "Alle Vergaben": the same for its raid choice
s.sync = { keeper = "Fraktur", at = time(), rev = 1 }
old.sync = { keeper = "Fraktur", at = 1700003600, rev = 1 }
NS.Set("ui.view", "raider")
NS.Refresh()
local R = NS.AwardsPageFrame().raider
R.allChip:Click()
local A = R.all
assert(A:IsShown() and A.raid:GetValue() == s.id and #A.list.items == 20, "the raiders' list of the recording")
A.list:GetScript("OnMouseWheel")(A.list, -7)
assert(A.list.offset == 7, "scrolled: " .. A.list.offset)
A.raid.onPick(old.id)
assert(A.raid:GetValue() == old.id and A.list.offset == 0, "another raid starts at its top: " .. A.list.offset)
NS.Reset("ui.view")
