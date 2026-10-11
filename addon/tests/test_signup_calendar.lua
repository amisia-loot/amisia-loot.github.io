-- Part H3: the click on Anmelden / Vorläufig / Abmelden (and /amisia anmelden, /amisia abmelden) also
-- writes into the game calendar on a guild event with sign-up, with the client's own calls: not
-- signed up -> the menu's sign-up inside the click; Vorläufig -> EventTentative (signed up: first
-- RemoveEvent); Abmelden -> RemoveEvent. The status is read again; blocked, an error or no change
-- turn to "Bitte auch im Kalender eintragen." with the reason, said once. Never in combat, never with
-- signup.calendar off, never for the player's own event or one without sign-up, never while the
-- calendar window is open, never from the re-send or an AQ answer.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
end
_G.ToggleCalendar = function() end

STUB.player, STUB.class, STUB.officer = "Vulo Pala", "PALADIN", false
STUB.guild = { { name = "Vulo Hunt", rank = 2, class = "HUNTER" }, { name = "Vulo Pala", rank = 3, class = "PALADIN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

local cal
local function calendar(opts)
    opts = opts or {}
    opts.writable = true
    opts.events = opts.events or {
        { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 7, inviteType = 1 },
        { title = "Eigenes", days = 2, id = 11, modStatus = "CREATOR", inviteStatus = 3, inviteType = 1 },
        { title = "Einladung", days = 3, id = 13, modStatus = "", inviteStatus = 0, inviteType = 0 },
    }
    cal = STUB.calendar(opts)
    NS.SignupLoadTerms(); STUB.tick(1)
    return cal
end
calendar()
local F = NS.ShowSignup()
local function pickDate(title)
    for _, t in ipairs(NS.SignupTerms()) do
        if t.title == title then NS.ShowSignup(t.night) return t end
    end
end
local T1 = pickDate("test123")
local function click(button)
    STUB.messages = {}
    STUB.inClick = true
    button:Click()
    STUB.inClick = false
end
local function names(from)
    local out = {}
    for i = from or 1, #cal.log do out[#out + 1] = cal.log[i].name end
    return table.concat(out, " ")
end
local function rec() return AmisiaDB.signup.chars["Vulo Pala"][T1.night] end
local function own() return cal.events[1].inviteStatus end

-- Anmelden, not signed up: the menu's sign-up inside the click
click(F.yes)
assert(names() == "ContextMenuSelectEvent ContextMenuEventSignUp" and cal.log[2].inClick, names())
assert(F.calHint:IsShown() and has(F.calHint:GetText(), "Wird im Spielkalender eingetragen"), "while it runs")
STUB.tick(5)
assert(own() == 6 and rec().k == "ok", "signed up in the calendar")
assert(said("Raid-Anmeldung: ") and said("Spielkalender: angemeldet."), table.concat(STUB.messages, "\n"))
assert(not F.calHint:IsShown() and not F.calBtn:IsShown(), "no hint when it worked")
assert(cal.open == nil, "nothing left open")

-- Vorläufig while signed up: the event opened, RemoveEvent, then EventTentative (the client's rule)
STUB.tick(12)
local n = #cal.log
click(F.maybe)
STUB.tick(5)
assert(names(n + 1) == "RemoveEvent EventTentative", names(n + 1))
assert(own() == 8 and rec().k == "ok" and said("Spielkalender: vorläufig."))
-- Anmelden from tentative: RemoveEvent, then EventSignUp
STUB.tick(12)
n = #cal.log
click(F.yes)
STUB.tick(5)
assert(names(n + 1) == "RemoveEvent EventSignUp" and own() == 6, names(n + 1))
-- another role, same status: nothing to write, no calendar line
STUB.tick(12)
n = #cal.log
F.roles[1]:Click()
click(F.yes)
STUB.tick(5)
assert(#cal.log == n and rec().k == "ok" and not said("Spielkalender"), "same status: no write")
-- Abmelden: RemoveEvent
STUB.tick(12)
n = #cal.log
click(F.no)
STUB.tick(5)
assert(names(n + 1) == "RemoveEvent" and own() == 7 and said("Spielkalender: entfernt."))
-- the command writes too: /amisia anmelden h
STUB.tick(12)
n = #cal.log
STUB.messages = {}
NS.Dispatch("anmelden h")
STUB.tick(5)
assert(names(n + 1) == "ContextMenuSelectEvent ContextMenuEventSignUp" and own() == 6, names(n + 1))

-- repeats never write: the re-send after the login and the answer to an officer's AQ
n = #cal.log
NS._signup.reset()
NS.SignupLoadTerms(); STUB.tick(1)
NS.SignupResend()
STUB.tick(30)
assert(#cal.log == n, "the re-send writes nothing")

-- blocked: the reason once, the hint with "Kalender öffnen"
calendar({ block = { EventTentative = true }, events = { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 7, inviteType = 1 } } })
T1 = pickDate("test123")
STUB.tick(12)
click(F.maybe)
STUB.tick(10)
assert(rec().k == "err" and said("Spielkalender: nicht eingetragen (Das Spiel hat den Eintrag blockiert.) Bitte auch im Kalender eintragen."),
    table.concat(STUB.messages, "\n"))
assert(F.calHint:IsShown() and has(F.calHint:GetText(), "Bitte auch im Kalender eintragen.") and F.calBtn:IsShown())
local tip = {}
GameTooltip.AddLine = function(_, text) tip[#tip + 1] = text end
F.calBtn:GetScript("OnEnter")(F.calBtn)
assert(has(table.concat(tip, "\n"), "Das Spiel hat den Eintrag blockiert."), "the reason in the tooltip")
local count = 0
for _, m in ipairs(STUB.messages) do if has(m, "Spielkalender: nicht eingetragen") then count = count + 1 end end
assert(count == 1, "said once")
-- no retry from a timer
n = #cal.log
STUB.tick(60)
assert(#cal.log == n, "never retried")

-- no change after the call: "Der Kalender zeigt keinen neuen Stand."
calendar({ ignore = { ContextMenuEventSignUp = true }, events = { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 7, inviteType = 1 } } })
T1 = pickDate("test123")
STUB.tick(12)
click(F.yes)
STUB.tick(20)
assert(rec().k == "err" and said("Der Kalender zeigt keinen neuen Stand."), table.concat(STUB.messages, "\n"))
-- a calendar error
calendar({ fail = { ContextMenuEventSignUp = true }, events = { { title = "test123", days = 1, id = 12, modStatus = "", inviteStatus = 7, inviteType = 1 } } })
T1 = pickDate("test123")
STUB.tick(12)
click(F.yes)
STUB.tick(10)
assert(rec().k == "err" and said("Der Kalender meldet einen Fehler."), table.concat(STUB.messages, "\n"))

-- in combat: nothing written
calendar()
T1 = pickDate("test123")
STUB.tick(12)
STUB.combat = true
n = #cal.log
click(F.yes)
STUB.tick(5)
assert(#cal.log == n and rec().k == "err" and said("Im Kampf trägt Amisia nicht in den Kalender ein."))
STUB.combat = false
-- the client's calendar window open: nothing written
_G.CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
STUB.tick(12)
click(F.no)
STUB.tick(5)
assert(#cal.log == n and said("Das Kalenderfenster des Spiels ist offen."))
CalendarFrame:Hide()
-- signup.calendar off: nothing written, the hint, no calendar line
NS.Set("signup.calendar", false)
STUB.tick(12)
click(F.yes)
STUB.tick(5)
assert(#cal.log == n and rec().k == "off" and not said("Spielkalender"), "setting off")
assert(F.calHint:IsShown() and has(F.calHint:GetText(), "Bitte auch im Kalender eintragen."))
NS.Set("signup.calendar", true)
-- the player's own event: nothing written, said once
local own2 = pickDate("Eigenes")
STUB.tick(12)
click(F.yes)
STUB.tick(5)
assert(#cal.log == n and said("Spielkalender: du hast das Ereignis angelegt"), table.concat(STUB.messages, "\n"))
assert(AmisiaDB.signup.chars["Vulo Pala"][own2.night].k == "ok" and cal.events[2].inviteStatus == 3)
-- an event without sign-up: nothing written, the hint
local inv = pickDate("Einladung")
STUB.tick(12)
click(F.yes)
STUB.tick(5)
assert(#cal.log == n and said("Das Ereignis ist kein Gildenereignis mit Anmeldung."))
assert(AmisiaDB.signup.chars["Vulo Pala"][inv.night].k == "err")
-- never another player's: the calls take no name; every write was for the own event 12
for _, w in ipairs(cal.log) do assert(w.name == "ContextMenuSelectEvent" or w.event == 12, w.name) end
print("signup calendar ok")
