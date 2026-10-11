-- Review of part H3 and the write probe (2026-10-11): the calendar write of a click and the write
-- probe never write for the wrong event or at the wrong moment.
--   1. a calendar probe holds the calendar: the click's write waits (no menu sign-up behind its back)
--   2. the client's calendar window opened, or another event came open, while the event opened:
--      nothing is called (click and probe)
--   3. the day event at the event's place is another event (its eventID): nothing is written
--   4. the client does not say who created the event (modStatus unreadable): nothing is written
--   5. an own status the groups do not know: not "the same", the hint
--   6. the probe never takes an event with a normal invite (its RemoveEvent drops the invitation)
--   7. the probe keeps writes for the restore
--   8. a long probe run is not started twice
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
end
_G.ToggleCalendar = function() end
_G.CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Hide()

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = { { name = "Vulo Hunt", rank = 2, class = "HUNTER" }, { name = "Vulo Pala", rank = 3, class = "PALADIN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

local cal, F, T1
local function calendar(opts)
    opts = opts or {}
    opts.writable = true
    opts.events = opts.events or { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 7, inviteType = 1 } }
    cal = STUB.calendar(opts)
    NS._signup.reset()
    NS.SignupLoadTerms(); STUB.tick(1)
    F = NS.ShowSignup()
    for _, t in ipairs(NS.SignupTerms()) do
        if t.title == (opts.pick or "test123") and (not opts.pickId or t.id == opts.pickId) then
            NS.ShowSignup(t.night)
            T1 = t
        end
    end
    STUB.tick(12)
    return cal
end
local function click(button)
    STUB.messages = {}
    STUB.inClick = true
    button:Click()
    STUB.inClick = false
end
local function rec() return AmisiaDB.signup.chars["Vulo Pala"][T1.night] end

-- 1. the probe holds the calendar: no menu sign-up, the reason "busy"
calendar()
NS.Cal.Hold(true)
click(F.yes)
STUB.tick(10)
assert(#cal.log == 0, "no write while a probe holds the calendar")
assert(rec().k == "err" and said("Der Kalender ist gerade beschäftigt."), table.concat(STUB.messages, "\n"))
NS.Cal.Hold(false)

-- 2a. signed up; Vorläufig opens the event and the player opens the calendar window meanwhile
calendar({ events = { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 6, inviteType = 1 } },
           onOpen = function() CalendarFrame:Show() end })
click(F.maybe)
STUB.tick(10)
CalendarFrame:Hide()
assert(#cal.log == 0, "nothing called with the calendar window open: " .. tostring(cal.log[1] and cal.log[1].name))
assert(rec().k == "err" and said("Das Kalenderfenster des Spiels ist offen."), table.concat(STUB.messages, "\n"))
assert(cal.events[1].inviteStatus == 6, "still signed up")

-- 2b. another event with the same title and start (a normal invite) comes open: nothing called
calendar({ events = { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 6, inviteType = 1 },
                      { title = "test123", days = 1, id = 14, modStatus = "", inviteStatus = 1, inviteType = 0 } },
           pickId = "12", onOpen = function(c) c.open = c.events[2] end })
click(F.no)
STUB.tick(10)
assert(#cal.log == 0, "nothing called on another event: " .. tostring(cal.log[1] and cal.log[1].name))
assert(cal.events[2].inviteStatus == 1 and cal.events[1].inviteStatus == 6, "neither event changed")
assert(rec().k == "err" and said("Der Kalender hat das Ereignis nicht geöffnet."), table.concat(STUB.messages, "\n"))

-- 3. the place the client names holds another event (a stale day list): nothing written
calendar({ events = { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 7, inviteType = 1 },
                      { title = "Andere", days = 2, id = 15, modStatus = "", inviteStatus = 7, inviteType = 1 } } })
local sel = C_Calendar.GetGuildEventSelectionInfo
C_Calendar.GetGuildEventSelectionInfo = function(i)
    local s = sel(i)
    if s and i == 1 then s.eventIndex = 2 end
    return s
end
click(F.yes)
STUB.tick(10)
assert(#cal.log == 0 and cal.events[2].inviteStatus == 7, "the other event untouched")
assert(rec().k == "err" and said("Das Ereignis steht nicht mehr im Kalender."), table.concat(STUB.messages, "\n"))

-- 4. the player's own event, but the client hides modStatus: never RemoveEvent
STUB.secret["CREATOR"] = true
calendar({ events = { { title = "test123", days = 1, id = 12, modStatus = "CREATOR", inviteStatus = 6, inviteType = 1 } } })
click(F.no)
STUB.tick(10)
assert(#cal.log == 0, "no write when the creator is unknown")
assert(rec().k == "err" and said("Der Kalender sagt nicht, wer das Ereignis angelegt hat."), table.concat(STUB.messages, "\n"))
STUB.secret["CREATOR"] = nil

-- 5. an own status the groups do not know: no "ok", the hint
calendar({ events = { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 9, inviteType = 1 } } })
click(F.yes)
STUB.tick(10)
assert(#cal.log == 0 and rec().k == "err", "unknown status is not the same")
assert(said("Der Kalender nennt deinen Stand bei diesem Ereignis nicht.") and F.calHint:IsShown(), table.concat(STUB.messages, "\n"))

---------------------------------------------------------------------------
-- The write probe
---------------------------------------------------------------------------
local WP = NS.SelfTest.CalendarWrite
local function confirmFrame() return _G.AmisiaConfirmFrame end
local function probe(opts)
    opts = opts or {}
    cal = STUB.calendar({ writable = true, silent = opts.silent, onOpen = opts.onOpen, events = opts.events or {
        { title = "test123", days = 2, id = 12, modStatus = "", inviteStatus = opts.status or 7, inviteType = 1 },
    } })
    STUB.messages = {}
    NS.Dispatch("selbsttest kalender schreiben")
    STUB.tick(1)
    return cal
end

-- 6. only a normal invite of someone else: no question, nothing written
probe({ events = { { title = "Einladung", days = 2, id = 13, modStatus = "", inviteStatus = 1, inviteType = 0 } } })
assert(said("braucht ein Gildenereignis mit Anmeldung"), table.concat(STUB.messages, "\n"))
assert(not (confirmFrame() and confirmFrame():IsShown()) and cal.writes == 0, "no question for a normal invite")

-- 2c. the probe: the calendar window opens while it opens the event: nothing is called then
-- (the opens: the read after 23a, the write of 25a, its read, the write of 23b: the window opens then)
local shownAt, opens = nil, 0
probe({ onOpen = function()
    opens = opens + 1
    if opens == 4 then
        CalendarFrame:Show()
        shownAt = #cal.log
    end
end })
confirmFrame().ok:Click()
STUB.tick(240)
CalendarFrame:Hide()
assert(shownAt and #cal.log == shownAt, "no write after the window opened: " .. tostring(shownAt) .. " " .. #cal.log)

-- 7. a long run: the restore keeps its writes
probe()
STUB.inClick = true
confirmFrame().ok:Click()
STUB.inClick = false
local P = WP._run()
assert(P and cal.events[1].inviteStatus == 6, "signed up in the click")
P.steps = P.steps + 20
STUB.tick(240)
assert(WP.lastRun == P and P.restored and cal.events[1].inviteStatus == 7, "restored: " .. WP.last.text)
assert(has(WP.last.text, "zu viele Schritte"), WP.last.text)

-- 8. a slow client (no answer to OpenEvent): a second start while the first still runs is refused
WP.WAIT = 10
probe({ silent = true })
confirmFrame().ok:Click()
local first = WP._run()
STUB.tick(190)
assert(first and not first.finished, "still running after 190 s")
STUB.messages = {}
NS.Dispatch("selbsttest kalender schreiben")
STUB.tick(1)
assert(said("Kalender-Schreibprüfung läuft schon."), table.concat(STUB.messages, "\n"))
STUB.tick(600)
assert(first.finished and cal.open == nil, "the run ends")
WP.WAIT = 5
print("calendar write review ok")
