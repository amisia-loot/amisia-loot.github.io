-- Part H3 on the safe side (2026-10-11, after the review): Anmelden and Vorläufig write only from
-- "not signed up" (7) like the client's own buttons, and between signed up (6) and tentative (8); a
-- status an officer set (0, 2, 3, 4, 5) stays and the chat says so once; Abmelden from confirmed or
-- standby is RemoveEvent ("Entfernen", which the client offers there). No write for an event of a past
-- calendar day, also in the raid night's 00:00-06:00. The write probe does not start from a status an
-- officer set (0, 3, 4, 5).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
end
local function count(part)
    local n = 0
    for _, m in ipairs(STUB.messages) do if has(m, part) then n = n + 1 end end
    return n
end
_G.ToggleCalendar = function() end

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = { { name = "Vulo Hunt", rank = 2, class = "HUNTER" }, { name = "Vulo Pala", rank = 3, class = "PALADIN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

local cal, F, T1
local function calendar(status, at)
    cal = STUB.calendar({ writable = true, events = { { title = "test123", days = 1, at = at, id = 12, modStatus = "", inviteStatus = status, inviteType = 1 } } })
    NS._signup.reset()
    NS.SignupLoadTerms(); STUB.tick(1)
    F = NS.ShowSignup()
    T1 = NS.SignupTerms()[1]
    assert(T1, "the date is listed")
    NS.ShowSignup(T1.night)
    STUB.tick(12)
end
local function click(button)
    STUB.messages = {}
    STUB.inClick = true
    button:Click()
    STUB.inClick = false
    STUB.tick(10)
end
local function rec() return AmisiaDB.signup.chars["Vulo Pala"][T1.night] end

-- 1. an officer's status: Anmelden and Vorläufig write nothing, the status stays, said once
for _, st in ipairs({ 0, 2, 3, 4, 5 }) do
    for _, b in ipairs({ "yes", "maybe" }) do
        calendar(st)
        click(F[b])
        assert(#cal.log == 0 and cal.events[1].inviteStatus == st, ("status %d, %s: nothing written (%s)"):format(st, b, tostring(cal.log[1] and cal.log[1].name)))
        assert(count("Spielkalender: ein Offizier hat deinen Stand gesetzt (") == 1, table.concat(STUB.messages, "\n"))
        assert(rec().k == "ok" and not F.calHint:IsShown(), "no hint: the officer's status stays")
    end
end
assert(said("Spielkalender: ein Offizier hat deinen Stand gesetzt (Ersatz), dort bleibt er."), table.concat(STUB.messages, "\n"))
-- Abmelden from confirmed or standby: RemoveEvent (the client offers "Entfernen" there)
for _, st in ipairs({ 3, 5 }) do
    calendar(st)
    click(F.no)
    assert(cal.log[1] and cal.log[1].name == "RemoveEvent" and cal.events[1].inviteStatus == 7, "Abmelden from " .. st)
end
-- the client's own transitions still write: 7 -> signed up, 6 -> tentative, 8 -> signed up
calendar(7)
click(F.yes)
assert(cal.events[1].inviteStatus == 6 and rec().k == "ok")
click(F.maybe)
assert(cal.events[1].inviteStatus == 8 and rec().k == "ok")
STUB.tick(12)
click(F.yes)
assert(cal.events[1].inviteStatus == 6 and rec().k == "ok")

-- 2. an event of yesterday 21:00, after midnight (still tonight's raid night): nothing written
local now = os.date("*t", STUB.now)
assert(now.hour < 6, "the stub's clock is in the night (00:00-06:00)")
local yesterday = os.time({ year = now.year, month = now.month, day = now.day, hour = 0 }) - 3 * 3600
for _, b in ipairs({ "yes", "no" }) do
    calendar(b == "yes" and 7 or 6, yesterday)
    click(F[b])
    assert(#cal.log == 0, "no write on a past day: " .. tostring(cal.log[1] and cal.log[1].name))
    assert(said("Spielkalender: der Termin liegt an einem vergangenen Tag, dort ändert sich nichts mehr."), table.concat(STUB.messages, "\n"))
end

-- 3. the write probe does not start from a status an officer set
local function confirmFrame() return _G.AmisiaConfirmFrame end
for _, st in ipairs({ 0, 3, 4, 5 }) do
    cal = STUB.calendar({ writable = true, events = { { title = "test123", days = 2, id = 12, modStatus = "", inviteStatus = st, inviteType = 1 } } })
    STUB.messages = {}
    NS.Dispatch("selbsttest kalender schreiben")
    STUB.tick(1)
    assert(said("von einem Offizier gesetzt") and said("noch nicht angemeldet bist (7 NotSignedup)"), table.concat(STUB.messages, "\n"))
    assert(not (confirmFrame() and confirmFrame():IsShown()) and cal.writes == 0, "no question from status " .. st)
end
-- the status changed to an officer's while the question was open: Ausführen writes nothing
cal = STUB.calendar({ writable = true, events = { { title = "test123", days = 2, id = 12, modStatus = "", inviteStatus = 7, inviteType = 1 } } })
STUB.messages = {}
NS.Dispatch("selbsttest kalender schreiben")
STUB.tick(1)
assert(confirmFrame():IsShown())
cal.events[1].inviteStatus = 3
confirmFrame().ok:Click()
STUB.tick(30)
assert(cal.writes == 0 and said("von einem Offizier gesetzt"), "no write after the status changed")
print("calendar write officer ok")
