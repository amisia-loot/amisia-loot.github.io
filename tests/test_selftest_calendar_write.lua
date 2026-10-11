-- /amisia selbsttest kalender schreiben: the write probe of the checks 23 to 25 (part H3) with a
-- stubbed calendar that writes like the client (sign-up event: the menu's sign-up and EventSignUp only
-- while not signed up, EventTentative only then, RemoveEvent back to "not signed up"). Nothing is
-- written before the chat warning and the click on "Ausführen"; "Abbrechen" writes nothing; an
-- event the player created is never used; the first write runs inside the click; every test is
-- reported with the status before and after; a blocked write from a timer is reported; the old
-- status is put back.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
end
local WP = NS.SelfTest.CalendarWrite
assert(WP and WP.Start, "the write probe loads")

STUB.player, STUB.class = "Vulo Pala", "PALADIN"
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

local function calendar(opts)
    opts = opts or {}
    local cal = STUB.calendar({ writable = true, block = opts.block, switch = opts.switch, events = opts.events or {
        { title = "Eigenes", days = 1, id = 11, modStatus = "CREATOR", inviteStatus = 3, inviteType = 1 },
        { title = "test123", days = 2, id = 12, modStatus = "", inviteStatus = opts.status or 7, inviteType = 1 },
    } })
    return cal
end
local function confirmFrame() return _G.AmisiaConfirmFrame end
local function run(cal)
    STUB.messages = {}
    NS.Dispatch("selbsttest kalender schreiben")
    STUB.tick(1)
    return cal
end

-- the warning and the question; nothing written before the click; "Abbrechen" writes nothing
local cal = run(calendar())
assert(said("schreibt in den Kalender: meldet dich beim gewählten Ereignis an, vorläufig, entfernt dich und stellt danach deinen alten Stand wieder her"), STUB.messages[1])
assert(said("test123"), "the event not created by the player")
local C = confirmFrame()
assert(C and C:IsShown() and C.ok:GetText() == "Ausführen" and C.cancel:GetText() == "Abbrechen")
assert(has(C.text:GetText(), "schreibt in den Kalender"))
STUB.tick(30)
assert(cal.writes == 0 and #cal.log == 0, "nothing before the click")
C.cancel:Click()
assert(not C:IsShown() and said("abgebrochen: nichts geschrieben"))
STUB.tick(30)
assert(cal.writes == 0, "nothing after Abbrechen")

-- "Ausführen": the menu's sign-up inside the click, then the others from timers, the old status back
cal = run(calendar())
STUB.inClick = true
confirmFrame().ok:Click()
STUB.inClick = false
assert(cal.log[2] and cal.log[2].name == "ContextMenuEventSignUp" and cal.log[2].inClick, "the first write inside the click")
for _, w in ipairs(cal.log) do assert(w.event ~= 11, "never the own event") end
STUB.tick(240)
local R = WP.last
assert(R and has(R.text, "Amisia-Kalender-Schreibprüfung"), "the report")
local text = R.text
for _, part in ipairs({ "23 Anmelden über das Kontextmenü", "25 Entfernen (RemoveEvent nach OpenEvent)", "23 Anmelden (EventSignUp",
                        "24 Vorläufig, wenn angemeldet", "25 Absagen", "24 Vorläufig (EventTentative", "25 Entfernen aus Vorläufig",
                        "24 Vorläufig über das Kontextmenü", "Wiederhergestellt" }) do
    assert(has(text, part), part .. "\n" .. text)
end
assert(has(text, "aus dem Klick; vorher 7 NotSignedup, nachher 6 Signedup"), text)
assert(has(text, "vorher 7 NotSignedup, jetzt 7 NotSignedup"), "restored")
local P = WP.lastRun
assert(P.results["23a"] and P.results["23b"] and P.results["24b"] and P.results["25a"] and P.results["25c"], "these work")
assert(not P.results["24a"] and not P.results["25b"] and not P.results["24c"], "the client's rules: no switch, no decline, no menu tentative")
assert(P.restored and cal.events[2].inviteStatus == 7 and cal.events[1].inviteStatus == 3, "old status back, own event untouched")
assert(said("Kalender-Schreibprüfung: Anmelden (Menü) geht") and said("aus einem Timer nicht blockiert") and said("alter Stand wiederhergestellt"), STUB.messages[#STUB.messages])
assert(cal.open == nil, "no event left open")

-- signed up before: 23a not in the click; restored to signed up
cal = run(calendar({ status = 6 }))
confirmFrame().ok:Click()
STUB.tick(240)
assert(has(WP.last.text, "nicht im Klick: du warst schon angemeldet"), WP.last.text)
assert(WP.lastRun.restored and cal.events[2].inviteStatus == 6, "back to signed up")

-- a write from a timer is blocked: reported
cal = run(calendar({ block = { EventSignUp = true } }))
confirmFrame().ok:Click()
STUB.tick(240)
assert(has(WP.last.text, "blockiert: ADDON_ACTION_BLOCKED C_Calendar.EventSignUp()"), WP.last.text)
assert(said("aus einem Timer blockiert"), STUB.messages[#STUB.messages])

-- only own events: no question, nothing written
cal = run(calendar({ events = { { title = "Eigenes", days = 1, id = 11, modStatus = "CREATOR", inviteStatus = 3, inviteType = 1 } } }))
assert(said("braucht ein Gildenereignis mit Anmeldung der nächsten 14 Tage, das ein anderer Charakter angelegt hat"), STUB.messages[1])
assert(not confirmFrame():IsShown() and cal.writes == 0)
-- in combat or with the calendar window open: nothing
STUB.combat = true
cal = run(calendar())
assert(not confirmFrame():IsShown() and cal.writes == 0, "combat")
STUB.combat = false
_G.CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
cal = run(calendar())
assert(said("Kalenderfenster schließen, dann noch einmal.") and cal.writes == 0)
CalendarFrame:Hide()
-- the question open, then combat: Ausführen writes nothing
cal = run(calendar())
STUB.combat = true
confirmFrame().ok:Click()
STUB.tick(30)
assert(cal.writes == 0, "no write in combat")
STUB.combat = false
print("selftest calendar write ok")
