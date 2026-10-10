-- /amisia selbsttest kalender: the probe of the checks 17 to 20 (raid lineup spec, part G) with a
-- stubbed C_Calendar. It reads the guild events, opens the first raid guild event, reads the invite
-- list, opens it again from a timer and reports a blocked action; it skips 18 and 19 while the
-- calendar window is open, copes with a missing C_Calendar or missing functions and never calls a
-- write function; nothing goes to chat or other players.
local ST = NS.SelfTest
local CT = ST.Calendar
assert(CT and CT.Start, "the calendar probe loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

local DAY = 86400
local function at(days, hour, minute)
    local t = os.date("*t", STUB.now + days * DAY)
    return t.year, t.month, t.day, hour, minute
end
local function guildEvent(title, days, eventType, calendarType, status)
    local y, m, d, h, mi = at(days, 20, 0)
    return { eventID = days, year = y, month = m, monthDay = d, weekday = 1, hour = h, minute = mi, eventType = eventType,
             title = title, calendarType = calendarType, texture = 0, inviteStatus = status, clubID = 1 }
end

-- The stub calendar: calls lists every call; a write function raises (and is counted) when called.
local W = {}
local function makeCalendar(opts)
    opts = opts or {}
    local cal = { calls = {}, writes = 0, loaded = opts.loaded or false, inSlash = false }
    local events = opts.events or {
        guildEvent("Gildentreffen", 2, 3, "GUILD_ANNOUNCEMENT", 0),
        guildEvent("Molten Core", 1, 0, "GUILD_EVENT", 3),
        guildEvent("Onyxia", 10, 0, "GUILD_EVENT", 7),
    }
    local invites = opts.invites or {
        { name = "Vulo Hunt", classFilename = "HUNTER", level = 60, inviteStatus = 3, modStatus = "CREATOR", type = 1, notes = "" },
        { name = "Vulo Pala", classFilename = "PALADIN", level = 60, inviteStatus = 8, modStatus = "", type = 1, notes = "komme 20:15" },
    }
    local function log(name) cal.calls[#cal.calls + 1] = name end
    local C = {}
    C.OpenCalendar = function()
        log("OpenCalendar")
        if opts.silent then return end
        C_Timer.After(0.5, function()
            cal.loaded = true
            STUB.fire("CALENDAR_UPDATE_GUILD_EVENTS")
        end)
    end
    C.GetNumGuildEvents = function() log("GetNumGuildEvents") return cal.loaded and #events or 0 end
    C.GetGuildEventInfo = function(i) log("GetGuildEventInfo") return cal.loaded and events[i] or nil end
    C.GetGuildEventSelectionInfo = function(i)
        log("GetGuildEventSelectionInfo")
        -- the game's own field name (offsetMonth), not the documented one
        return { offsetMonth = 0, monthDay = events[i].monthDay, eventIndex = 1 }
    end
    C.OpenEvent = function(offset, day, index)
        log("OpenEvent")
        cal.opened = { offset, day, index }
        if opts.blockTimer and not cal.inSlash then
            STUB.fire("ADDON_ACTION_BLOCKED", "Amisia", "C_Calendar.OpenEvent()")
            STUB.fire("ADDON_ACTION_BLOCKED", "AnderesAddon", "C_Calendar.OpenEvent()")
            return false
        end
        cal.open = true
        STUB.fire("CALENDAR_OPEN_EVENT", "GUILD_EVENT")
        C_Timer.After(0.3, function() STUB.fire("CALENDAR_UPDATE_INVITE_LIST", true) end)
        return true
    end
    C.GetEventInfo = function()
        log("GetEventInfo")
        return { title = "Molten Core", description = "", eventType = 0, repeatOption = 0, maxSize = 40, calendarType = "GUILD_EVENT",
                 inviteType = 1, time = { year = 2026, month = 10, monthDay = 11, weekday = 1, hour = 20, minute = 0 } }
    end
    C.GetNumInvites = function() log("GetNumInvites") return cal.open and #invites or 0 end
    C.EventGetInvite = function(i) log("EventGetInvite") return invites[i] end
    C.EventGetInviteResponseTime = function(i)
        log("EventGetInviteResponseTime")
        return { year = 2026, month = 10, monthDay = 10, weekday = 7, hour = 18, minute = 42 }
    end
    C.CloseEvent = function() log("CloseEvent") cal.open = false; cal.closed = (cal.closed or 0) + 1 end
    for _, name in ipairs(CT.WRITE) do
        C[name] = function() cal.writes = cal.writes + 1; W[#W + 1] = name; error("write called: " .. name) end
    end
    for _, name in ipairs(opts.remove or {}) do C[name] = nil end
    _G.C_Calendar = C
    -- the slash command is a key press; a timer is not
    cal.dispatch = function(text)
        cal.inSlash = true
        NS.Dispatch(text)
        cal.inSlash = false
    end
    return cal
end

local function report() return ST.Frame().area.box:GetText() end
local function lastMsg() return STUB.messages[#STUB.messages] end

-- 1. the list loads after OpenCalendar: 17 waits for the event, 18 and 19 run from callbacks
local cal = makeCalendar()
cal.dispatch("selbsttest kalender")
assert(has(lastMsg(), "Kalender-Prüfung läuft"), "started: " .. tostring(lastMsg()))
STUB.tick(20)
local text = report()
assert(ST.Frame():IsShown(), "the report window shows")
assert(has(text, "Amisia-Kalender-Prüfung " .. NS.VERSION .. " | Client "), text)
for _, title in ipairs({ "Kalender: Funktionen", "17 Termine lesen", "18 Teilnehmerliste ohne Kalenderfenster", "19 Ohne Tastendruck",
                         "20 Name und Zeit" }) do
    assert(has(text, "== " .. title .. " =="), "section " .. title .. "\n" .. text)
end
assert(has(text, "OK     Lesefunktionen: alle 10 vorhanden"), text)
assert(has(text, "WERT   Schreibfunktionen (für 23 bis 25, nicht aufgerufen): da: ContextMenuSelectEvent, ContextMenuEventSignUp, "
    .. "ContextMenuInviteTentative, EventSignUp, EventTentative, EventDecline, RemoveEvent; fehlen: keine"), text)
assert(has(text, "WERT   Kalenderfenster: nicht geladen"), text)
assert(has(text, "OK     Antwort auf OpenCalendar: CALENDAR_UPDATE_GUILD_EVENTS"), text)
assert(has(text, "OK     GetNumGuildEvents: 3"), text)
local y, m, d = at(1, 20, 0)
assert(has(text, ('GetGuildEventInfo(2): "Molten Core", %04d-%02d-%02d 20:00, Art 0 Raid, "GUILD_EVENT", dein Status 3 Confirmed (bestätigt)'):format(y, m, d)), text)
assert(has(text, 'GetGuildEventInfo(1): "Gildentreffen", ') and has(text, 'Art 3 Meeting, "GUILD_ANNOUNCEMENT", dein Status 0 Invited (eingeladen)'), text)
assert(has(text, 'dein Status 7 NotSignedup (ohne Antwort)'), text)
y, m, d = at(10, 20, 0)
assert(text:find(("WERT   Am weitesten voraus: %04d%%-%02d%%-%02d 20:00 %%(in 10[.,]%%d Tagen%%)"):format(y, m, d)), text)
-- 18: the raid guild event (number 2, not the announcement), opened with offsetMonth
local s18 = text:match("== 18 Teilnehmerliste ohne Kalenderfenster ==\n(.-)\n\n")
assert(s18, text)
assert(has(s18, 'WERT   Ereignis: Nummer 2: "Molten Core"'), s18)
assert(has(s18, "Aufruf: nach dem Laden der Liste (kein Tastendruck"), s18)
assert(has(s18, "OK     GetGuildEventSelectionInfo(2): offsetMonths nil, offsetMonth 0, monthDay "), s18)
assert(s18:find("OK     OpenEvent%(0, %d+, 1%): true"), s18)
assert(has(s18, "OK     Antwort: CALENDAR_OPEN_EVENT, CALENDAR_UPDATE_INVITE_LIST"), s18)
assert(has(s18, 'OK     GetEventInfo: "Molten Core", "GUILD_EVENT", Einladungsart 1 Signup, Art 0 Raid, 2026-10-11 20:00; Titel wie das Gildenereignis: ja'), s18)
assert(has(s18, "OK     GetNumInvites: 2"), s18)
assert(has(s18, 'WERT   EventGetInvite(1): "Vulo Hunt", "HUNTER", Stufe 60, Status 3 Confirmed (bestätigt), modStatus "CREATOR", Art 1 Signup, Notiz nein'), s18)
assert(has(s18, 'WERT   EventGetInvite(2): "Vulo Pala", "PALADIN", Stufe 60, Status 8 Tentative (vorläufig), modStatus "", Art 1 Signup, Notiz ja'), s18)
assert(has(s18, "OK     Blockiert: nichts"), s18)
assert(has(s18, "OK     CloseEvent: geschlossen"), s18)
local s19 = text:match("== 19 Ohne Tastendruck ==\n(.-)\n\n")
assert(s19 and has(s19, "Aufruf: aus einem C_Timer.After (kein Tastendruck)") and has(s19, "OK     OpenEvent(") and has(s19, "OK     GetNumInvites: 2")
    and has(s19, "OK     Blockiert: nichts") and has(s19, "OK     CloseEvent: geschlossen"), tostring(s19))
assert(has(text, 'OK     Namen mit Nachname: 2 mit Leerzeichen, 0 ohne, 0 geheim; zum Beispiel "Vulo Hunt"'), text)
assert(has(text, "OK     EventGetInviteResponseTime(1): 2026-10-10 18:42"), text)
assert(has(text, "Ergebnis: ") and not has(text, "Probleme:"), text)
assert(cal.closed == 2 and not cal.open, "both opens closed")
assert(cal.writes == 0, "no write function called")
assert(has(lastMsg(), "Kalender-Prüfung: 3 Gildenereignisse, Teilnehmerliste gelesen (2), ohne Tastendruck geht, 0 Problem(e)."), lastMsg())
assert(#STUB.chat == 0 and #STUB.addonTries == 0, "nothing sent")

-- 2. the list is loaded already: the open of 18 runs inside the key press; "Erneut prüfen" runs it again
local before = #cal.calls
cal.dispatch("selftest calendar")
local opensInSlash = 0
for i = before + 1, #cal.calls do if cal.calls[i] == "OpenEvent" then opensInSlash = opensInSlash + 1 end end
assert(opensInSlash == 1, "the open of 18 is part of the command")
STUB.tick(20)
text = report()
assert(has(text, "OK     Antwort auf OpenCalendar: Liste schon geladen (3 vor dem Aufruf)"), text)
assert(has(text, "Aufruf: aus dem Tastendruck (Befehl)"), text)
ST.Frame().again:Click()
STUB.tick(20)
assert(has(report(), "Liste schon geladen"), "again runs the calendar probe")
assert(cal.writes == 0)

-- a second start while one runs says so
cal.dispatch("selbsttest kalender")
local n = #STUB.messages
cal.dispatch("selbsttest kalender")
assert(has(STUB.messages[#STUB.messages], "Kalender-Prüfung läuft schon."), STUB.messages[#STUB.messages])
assert(#STUB.messages == n + 1)
STUB.tick(20)

-- 3. the calendar window is open: 18 and 19 are skipped, nothing is opened
cal = makeCalendar({ loaded = true })
_G.CalendarFrame = CreateFrame("Frame", "CalendarFrame")
CalendarFrame:Show()
cal.dispatch("selbsttest kalender")
STUB.tick(20)
text = report()
assert(has(text, "WERT   Kalenderfenster: offen"), text)
assert(has(text, "Kalenderfenster: offen: 18 und 19 übersprungen"), text)
for _, c in ipairs(cal.calls) do assert(c ~= "OpenEvent", "nothing opened while the window is open") end
assert(has(text, "nicht geprüft (keine Teilnehmerliste gelesen)"), text)
assert(has(lastMsg(), "Teilnehmerliste übersprungen (Kalenderfenster offen), ohne Tastendruck nicht geprüft"), lastMsg())
CalendarFrame:Hide()

-- 4. the client blocks the open from the timer: 19 says so, the other addon's block does not count
cal = makeCalendar({ loaded = true, blockTimer = true })
cal.dispatch("selbsttest kalender")
STUB.tick(20)
text = report()
s19 = text:match("== 19 Ohne Tastendruck ==\n(.-)\n\n")
assert(s19 and has(s19, "FEHLT  OpenEvent(") and has(s19, "FEHLER Blockiert: ADDON_ACTION_BLOCKED C_Calendar.OpenEvent()"), tostring(s19))
assert(not has(s19, "AnderesAddon"), "another addon's block is not Amisia's")
assert(has(text, "Probleme:") and has(text, "[19 Ohne Tastendruck] FEHLER Blockiert"), text)
assert(has(text, "OK     Blockiert: nichts"), "18 from the key press was not blocked")
assert(has(lastMsg(), "ohne Tastendruck blockiert"), lastMsg())
assert(cal.writes == 0)

-- 5. no answer to OpenCalendar: 17 waits CT.WAIT seconds and reports it
cal = makeCalendar({ silent = true })
cal.dispatch("selbsttest kalender")
STUB.tick(CT.WAIT - 1)
assert(not has(report(), "kein CALENDAR_UPDATE_EVENT_LIST"), "still waiting")
STUB.tick(20)
text = report()
assert(has(text, "WERT   Antwort auf OpenCalendar: kein CALENDAR_UPDATE_EVENT_LIST / _GUILD_EVENTS nach 5 s"), text)
assert(has(text, "WERT   GetNumGuildEvents: 0") and has(text, "WERT   Am weitesten voraus: kein Termin"), text)
assert(has(text, "kein Gildenereignis der Art Schlachtzug"), text)
assert(has(lastMsg(), "Kalender-Prüfung: 0 Gildenereignisse, Teilnehmerliste übersprungen (kein Schlachtzug-Ereignis)"), lastMsg())

-- 6. functions missing: read functions FEHLT by name, write functions only listed, nothing raises
cal = makeCalendar({ loaded = true, remove = { "EventGetInviteResponseTime", "RemoveEvent", "EventDecline" } })
cal.dispatch("selbsttest kalender")
STUB.tick(20)
text = report()
assert(has(text, "FEHLT  Lesefunktionen: 1 von 10 fehlen: C_Calendar.EventGetInviteResponseTime"), text)
assert(has(text, "fehlen: EventDecline, RemoveEvent"), text)
assert(has(text, "FEHLT  EventGetInviteResponseTime(1): C_Calendar.EventGetInviteResponseTime fehlt"), text)
assert(not text:find("\nFEHLER "), "no error:\n" .. text)

cal = makeCalendar({ loaded = true, remove = { "OpenEvent" } })
cal.dispatch("selbsttest kalender")
STUB.tick(20)
text = report()
assert(has(text, "FEHLT  OpenEvent: C_Calendar.OpenEvent fehlt"), text)
assert(has(text, "nicht geprüft (OpenEvent ließ sich in 18 nicht aufrufen)"), text)
assert(not text:find("\nFEHLER "), "no error:\n" .. text)

-- a secret name (chat lockdown) is counted, not compared
local secretName = "Vulo Geheim"
STUB.secret[secretName] = true
cal = makeCalendar({ loaded = true, invites = { { name = secretName, level = 60, inviteStatus = 6, type = 1, notes = "" } } })
cal.dispatch("selbsttest kalender")
STUB.tick(20)
text = report()
assert(has(text, "WERT   Namen: 1 geheim") and has(text, "EventGetInvite(1): <geheim>, nil, Stufe 60, Status 6 Signedup (angemeldet)"), text)
STUB.secret[secretName] = nil

-- 7. a client without C_Calendar: one FEHLT line, done at once
_G.C_Calendar = nil
NS.Dispatch("selbsttest kalender")
text = report()
assert(has(text, "FEHLT  C_Calendar: fehlt"), text)
assert(not has(text, "== 17"), "nothing more")
assert(has(lastMsg(), "Kalender-Prüfung: ? Gildenereignisse"), lastMsg())

-- the plain self-test still works and its "Erneut prüfen" runs the plain test
NS.Dispatch("selbsttest")
assert(has(report(), "Amisia-Selbsttest " .. NS.VERSION))
ST.Frame().again:Click()
assert(has(report(), "Amisia-Selbsttest " .. NS.VERSION))
assert(#W == 0, "no write function was ever called")
assert(#STUB.chat == 0 and #STUB.addonTries == 0, "nothing sent")
