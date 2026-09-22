-- Latecomers: whoever is first seen after the raid start time set in the settings is marked,
-- the mark travels in the M line of the export, and a recording that itself starts late marks nobody.
local function dayAt(hour, min)
    local d = date("*t", STUB.now)
    return time({ year = d.year, month = d.month, day = d.day, hour = hour, min = min, sec = 0 })
end

-- the raid starts at 19:50, one raider joins at 20:07
STUB.now = dayAt(19, 50)
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s and s.lateAt == dayAt(20, 0), "cutoff is the raid start of that night")
assert(NS.LateCount(s) == 0, "nobody is late before the cutoff")

STUB.now = dayAt(20, 7)
STUB.roster[3] = { name = "Spaetling", class = "MAGE" }
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)
assert(s.members.Spaetling, "the latecomer is in the roster")
assert(s.members.Spaetling.late, "joined after 20:00, so late")
assert(not s.members.Fraktur.late, "was there before 20:00, so punctual")
assert(NS.LateCount(s) == 1, "one latecomer")

local txt = NS.ExportText({ s })
assert(txt:find("\nM Spaetling MAGE %d+ 1\n"), txt)
assert(txt:find("\nM Fraktur SHAMAN %d+ 0\n"), txt)

-- someone who steps out and comes back keeps the punctual mark
STUB.now = dayAt(20, 20)
STUB.roster[2].online = false
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)
STUB.now = dayAt(20, 30)
STUB.roster[2].online = true
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)
assert(not s.members.Fraktur.late, "a short disconnect is no delay")

-- a recording that only starts at 21:00 marks nobody who is already there
NS.DeleteSessions({ [s.id] = true })
STUB.instance = { name = "Sunwell Plateau", type = "raid", id = 580 }
STUB.now = dayAt(21, 0)
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local late = NS.Active()
assert(late and late ~= s, "a second session")
assert(NS.LateCount(late) == 0, "the group that was there at the first scan is punctual")
STUB.now = dayAt(21, 10)
STUB.roster[4] = { name = "Nachzuegler", class = "ROGUE" }
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)
assert(late.members.Nachzuegler.late, "whoever joins after the first scan is still late")

-- the setting can be switched off and set to another time
assert(NS.SetLateTime("aus"), "off is accepted")
assert(NS.LateTime() == nil, "no raid start while off")
assert(NS.SetLateTime("19:30"), "a time is accepted")
assert(NS.LateTime() == "19:30", "the raid start is kept")
assert(not NS.SetLateTime("25:00"), "an impossible time is refused")
