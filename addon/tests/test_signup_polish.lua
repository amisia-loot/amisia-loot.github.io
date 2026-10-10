-- The raid sign-up's polish (2.25.0): the card's button says "Ändern" when the player already has a
-- sign-up for the date the card shows first (else "Anmelden"), and the window "Raid-Anmeldung" is
-- compact: under the note hint only what is shown follows (the other characters, the calendar
-- hint), Theme.SIGNUP.GAP apart, and the window ends right under its button row.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local S, T = NS.Theme.SIGNUP, NS.Theme

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = { { name = "Vulo Hunt", rank = 2, class = "HUNTER" }, { name = "Vulo Pala", rank = 3, class = "PALADIN" } }
STUB.calendar({ events = { { title = "Molten Core", days = 1, eventType = 0, id = 12 }, { title = "Onyxia", days = 3, eventType = 0, id = 14 } } })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SignupLoadTerms(); STUB.tick(1)
local terms = NS.SignupTerms()
assert(terms and #terms == 2)

local function card()
    for _, c in ipairs(NS.OverviewPageFrame().cards) do
        if c:IsShown() and c.title:GetText() == NS.L["Raid-Anmeldung"] then return c end
    end
end
NS.ShowPage("overview")
assert(card().button:GetText() == "Anmelden", "no sign-up yet: Anmelden")

-- the window opened from the card, nothing shown under the note hint
card().button:Click()
local F = NS._signupUI.frame()
assert(F:IsShown() and F.pick:GetValue() == terms[1].night, "the card opens the window at its first date")
-- the y offset (down from the window's top) of a frame placed with TOPLEFT/TOPRIGHT on the window
local function top(f)
    local _, _, _, _, y = f:GetPoint(1)
    return -y
end
local function bottomRowTop() return F:GetHeight() - S.BOTTOM - T.BUTTON_H end
local hintEnd = S.HINT_Y + S.LINE_H
-- part H3 off for this test: the calendar hint shows only after a click (step 4); here it may show
if F.calHint:IsShown() then
    assert(top(F.calHint) == hintEnd + S.GAP, "the calendar hint right under the note hint: " .. top(F.calHint))
    assert(bottomRowTop() == top(F.calHint) + T.BUTTON_H + S.GAP, "the buttons right under the calendar hint")
else
    assert(bottomRowTop() == hintEnd + S.GAP, "the buttons right under the note hint: " .. bottomRowTop())
    assert(F:GetHeight() == S.H, "the smallest window: " .. F:GetHeight())
end
assert(not F.alts:IsShown(), "no other characters: no empty band")
assert(bottomRowTop() - hintEnd <= S.GAP + T.BUTTON_H + S.GAP, "no gap of 50 px any more")

-- signed up: the card says "Ändern", and opens the window at that date
F.yes:Click()
NS.Refresh()
assert(card().button:GetText() == "Ändern", "signed up: Ändern")
F:Hide()
card().button:Click()
assert(F:IsShown() and F.pick:GetValue() == terms[1].night)

-- another character of the account with a sign-up: one line under the note hint, then the rest
AmisiaDB.signup.chars["Vulo Hunt"] = { [terms[1].night] = { s = "A", r = "T", t = time() } }
NS.ShowSignup(terms[1].night)
assert(F.alts:IsShown() and has(F.alts:GetText(), "Vulo Hunt: "), F.alts:GetText())
assert(top(F.alts) == hintEnd + S.LINE_GAP, "the other characters right under the note hint")
local altsEnd = top(F.alts) + F.alts:GetHeight()
if F.calHint:IsShown() then
    assert(top(F.calHint) == altsEnd + S.GAP)
    assert(bottomRowTop() == top(F.calHint) + T.BUTTON_H + S.GAP)
else
    assert(bottomRowTop() == altsEnd + S.GAP)
end

-- the second date without a sign-up: the card's first date counts, not the window's
F:Hide()
AmisiaDB.signup.chars["Vulo Pala"] = { [terms[2].night] = { s = "A", r = "H", t = time() } }
NS.Refresh()
assert(card().button:GetText() == "Anmelden", "no sign-up for the first date: Anmelden")
print("signup polish ok")
