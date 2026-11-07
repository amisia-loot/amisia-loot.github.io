-- The lineup (Raid/Lineup.lua, audit 2026-11-07): two sign-ups that match the same character make
-- one row; a night older than the 8 kept is refused instead of taken and trimmed at once.
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")

-- one character, two spellings (the full name and the unique first name)
local night = NS.SetLineupText("Anna Bergmann\nAnna Heiler\nBob Eisherz Tank", "2026-11-20")
assert(night == "2026-11-20", tostring(night))
local rows, anna = 0, nil
for _, e in ipairs(NS.LineupNight(night).list) do
    if e.n == "Anna Bergmann" then rows, anna = rows + 1, e end
end
assert(rows == 1, "one row per character: " .. rows)
assert(anna.r == "H", "the role of the second sign-up fills the first's gap: " .. tostring(anna.r))
assert(#NS.LineupNight(night).list == 2, "two rows: " .. #NS.LineupNight(night).list)

-- eight newer nights kept: an older one is refused, nothing trimmed
for d = 21, 28 do assert(NS.SetLineupText("Bob Eisherz Tank", ("2026-11-%02d"):format(d))) end
assert(#NS.LineupNights() == 8, "8 nights: " .. #NS.LineupNights())
local ok, why = NS.SetLineupText("Bob Eisherz Tank", "2026-11-10")
assert(ok == nil and type(why) == "string" and why:find("8", 1, true), "the old night is refused: " .. tostring(why))
assert(NS.LineupNight("2026-11-10", false) == nil and #NS.LineupNights() == 8, "nothing changed")
local n, why2 = NS.LineupNight("2026-11-10", true)
assert(n == nil and why2 == why, "LineupNight(create) says why")
ok, why = NS.LineupCopy("2026-11-28", "2026-11-11")
assert(ok == nil and why, "the copy into an old night is refused: " .. tostring(why))
ok, why = NS.LineupCalendar({ night = "2026-11-12", at = 1, title = "Raid" }, {})
assert(ok == nil and why, "the calendar into an old night is refused")
-- a newer night still pushes the oldest out
assert(NS.SetLineupText("Bob Eisherz Tank", "2026-11-29") == "2026-11-29")
assert(#NS.LineupNights() == 8 and NS.LineupNight("2026-11-21", false) == nil, "the oldest goes")
