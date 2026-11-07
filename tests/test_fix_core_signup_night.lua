-- The sign-up window opened at a date before the dates are read (after a /reload): once they come
-- the window shows that date, not the next one (audit 2026-11-07).
STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = { { name = "Vulo Pala", rank = 3, class = "PALADIN" } }
STUB.calendar({ silent = true, events = { { title = "Molten Core", days = 1, eventType = 0, id = 12 }, { title = "Onyxia", days = 3, eventType = 0, id = 14 } } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
local terms = NS.SignupTerms()
assert(terms and #terms == 2)
local ony = terms[2].night
assert(NS.SignupNextTerm().night ~= ony, "Onyxia is not the next date")
-- the dates forgotten, as after a /reload
NS._signup.reset()
assert(NS.SignupTerms() == nil)
local F = NS.ShowSignup(ony)
STUB.tick(1)
assert(NS.SignupTerms(), "the dates were read")
assert(F.pick:GetValue() == ony, "the window keeps the date it was opened at: " .. tostring(F.pick:GetValue()))
