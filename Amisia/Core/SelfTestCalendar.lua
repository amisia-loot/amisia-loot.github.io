-- /amisia selbsttest kalender: the in-game checks 17 to 20 of the raid lineup spec (2026-10-10,
-- part G) done by the addon itself. It reads the guild events of the game calendar (17), opens the
-- first raid event without the calendar window and reads its invite list (18), opens it once more
-- from a timer, without a key press, and watches whether the client blocks Amisia (19), and looks at
-- the names and the response time of the invites (20). The report goes into the self-test window.
-- Read-only: it never signs up, creates, changes or removes anything in the calendar; the write
-- functions the later checks 23 to 25 need are only looked up, never called. Every call is
-- protected; a missing function is FEHLT, never an error.
local ADDON, ns = ...
local L = ns.L

local ST = ns.SelfTest
local K = ST.Kit
local add, check, show, fn, call, isSecret, cut = K.add, K.check, K.show, K.fn, K.call, K.isSecret, K.cut
local FEHLT = K.FEHLT

local CT = {}
ST.Calendar = CT

CT.WAIT = 5          -- seconds to wait for each answer of the client
CT.DELAY = 1         -- seconds before the open of check 19 (from a timer, no key press)
local MAX_EVENTS = 20
local MAX_INVITES = 10
local STALE = 60     -- a probe older than this counts as gone (a new one may start)
local DAY = 86400

-- What the probe reads.
CT.READ = {
    "C_Calendar.OpenCalendar", "C_Calendar.GetNumGuildEvents", "C_Calendar.GetGuildEventInfo",
    "C_Calendar.GetGuildEventSelectionInfo", "C_Calendar.OpenEvent", "C_Calendar.GetEventInfo", "C_Calendar.GetNumInvites",
    "C_Calendar.EventGetInvite", "C_Calendar.EventGetInviteResponseTime", "C_Calendar.CloseEvent",
}
-- What the checks 23 to 25 will need: looked up, never called.
CT.WRITE = {
    "ContextMenuSelectEvent", "ContextMenuEventSignUp", "ContextMenuInviteTentative", "EventSignUp", "EventTentative",
    "EventDecline", "RemoveEvent",
}
local LIST_EVENTS = { "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_UPDATE_GUILD_EVENTS" }
local OPEN_EVENTS = { "CALENDAR_OPEN_EVENT", "CALENDAR_UPDATE_INVITE_LIST" }
local BLOCK_EVENTS = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }

-- the status and type tables, the time stamp, the window check, the month offset and the choice of
-- the event are the calendar module's (Raid/Calendar.lua), shared with the raid lineup and sign-up
local Cal = ns.Cal
local EVENT_TYPES, INVITE_TYPES = Cal.EVENT_TYPES, Cal.INVITE_TYPES

local function enumText(v, names)
    if isSecret(v) then return L["<geheim>"] end
    local name = type(v) == "number" and names[v]
    return name and ("%d %s"):format(v, name) or show(v)
end

local function statusText(v)
    if isSecret(v) then return L["<geheim>"] end
    local s = type(v) == "number" and Cal.STATUS[v]
    return s and ("%d %s (%s)"):format(v, s[1], L[s[3]]) or show(v)
end

local function plain(v) return not isSecret(v) and v or nil end

local stamp = Cal.Stamp
local calendarWindow = Cal.WindowShown

---------------------------------------------------------------------------
-- The probe: one at a time, its own event frame only while it runs
---------------------------------------------------------------------------
local run
local watcher

local function onEvent(_, event, ...)
    local P = run
    if not P then return end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local who, what = ...
        if not isSecret(who) and who == ADDON then
            P.blocked[#P.blocked + 1] = { event = event, what = isSecret(what) and L["<geheim>"] or tostring(what), phase = P.phase }
        end
        return
    end
    if P.waiter then P.waiter(event) end
end

local function listen(on)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", onEvent)
    end
    for _, list in ipairs({ LIST_EVENTS, OPEN_EVENTS, BLOCK_EVENTS }) do
        for _, e in ipairs(list) do
            -- pcall: a client without the event must not stop the probe
            if on then pcall(watcher.RegisterEvent, watcher, e) else pcall(watcher.UnregisterEvent, watcher, e) end
        end
    end
end

local finishProbe

-- f protected: an error ends the probe with a FEHLER line instead of leaving it hanging.
local function safe(P, f)
    return function(...)
        local ok, err = pcall(f, ...)
        if not ok then
            add(P.R, "FEHLER", L["Ablauf"], cut(tostring(err)))
            finishProbe(P)
        end
    end
end

-- Runs action (which returns true when there is something to wait for), then waits for the events
-- in want ("any": the first of them, else all) for at most CT.WAIT seconds; then nextStep(gotAll,
-- got) on the next frame (got: event -> true). Events that come during the action count (the
-- client fires some synchronously).
local function step(P, want, mode, action, nextStep)
    local need, got, finished = {}, {}, false
    for _, e in ipairs(want) do need[e] = true end
    local function done(complete)
        if finished then return end
        finished = true
        P.waiter = nil
        C_Timer.After(0, safe(P, function() nextStep(complete, got) end))
    end
    P.waiter = function(event)
        if not need[event] then return end
        need[event], got[event] = nil, true
        if mode == "any" or next(need) == nil then done(true) end
    end
    local waitFor = action()
    if not waitFor then return done(false) end
    if not finished then C_Timer.After(CT.WAIT, function() done(false) end) end
end

local function gotText(got, want)
    local parts = {}
    for _, e in ipairs(want) do
        if got[e] then parts[#parts + 1] = e end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

local function blockedLines(P, phase)
    local list = {}
    for _, b in ipairs(P.blocked) do
        if b.phase == phase then list[#list + 1] = ("%s %s"):format(b.event, b.what) end
    end
    return list
end

---------------------------------------------------------------------------
-- 17: the guild events
---------------------------------------------------------------------------
local check18

local function readList(P, cached, complete, got)
    local R = P.R
    if cached then
        add(R, "OK", L["Antwort auf OpenCalendar"], L["Liste schon geladen (%d vor dem Aufruf)"]:format(cached))
    elseif complete then
        add(R, "OK", L["Antwort auf OpenCalendar"], gotText(got, LIST_EVENTS))
    else
        add(R, "WERT", L["Antwort auf OpenCalendar"], L["kein CALENDAR_UPDATE_EVENT_LIST / _GUILD_EVENTS nach %d s"]:format(CT.WAIT))
    end
    local n = 0
    check(R, "GetNumGuildEvents", function()
        local v = call("C_Calendar.GetNumGuildEvents")
        n = not isSecret(v) and tonumber(v) or 0
        return n > 0 and "OK" or "WERT", show(v)
    end)
    P.count = n
    P.events = {}
    local far, farText, now = nil, nil, time()
    for i = 1, math.min(n, MAX_EVENTS) do
        check(R, ("GetGuildEventInfo(%d)"):format(i), function()
            local e = call("C_Calendar.GetGuildEventInfo", i)
            if type(e) ~= "table" then return "WERT", show(e) end
            P.events[#P.events + 1] = { index = i, info = e }
            local when, t = stamp(e)
            if t then
                local ok, at = pcall(time, t)
                if ok and type(at) == "number" and (not far or at > far) then far, farText = at, when end
            end
            return "WERT", L["%s, %s, Art %s, %s, dein Status %s"]:format(show(e.title), when or L["Zeit unbekannt"],
                enumText(e.eventType, EVENT_TYPES), show(e.calendarType), statusText(e.inviteStatus))
        end)
    end
    if n > MAX_EVENTS then add(R, "WERT", L["Weitere"], L["%d weitere nicht gezeigt"]:format(n - MAX_EVENTS)) end
    if far then
        add(R, "WERT", L["Am weitesten voraus"], L["%s (in %.1f Tagen)"]:format(farText, (far - now) / DAY))
    else
        add(R, "WERT", L["Am weitesten voraus"], L["kein Termin"])
    end
    check18(P)
end

---------------------------------------------------------------------------
-- 18 and 19: open the event, read its invite list, close it
---------------------------------------------------------------------------
-- Opens the event P.target; fromKey says whether this runs inside the key press of the command.
-- Reports the open, the answer, what the client blocked; read(R) adds the lines of what it read;
-- then CloseEvent and after(opened, called) (called: OpenEvent could be called at all).
local function openTarget(P, fromKey, read, after)
    local R, i = P.R, P.target.index
    add(R, "WERT", L["Aufruf"], fromKey and L["aus dem Tastendruck (Befehl)"]
        or (P.phase == "19" and L["aus einem C_Timer.After (kein Tastendruck)"]
            or L["nach dem Laden der Liste (kein Tastendruck; für einen Aufruf aus dem Tastendruck den Befehl noch einmal eingeben)"]))
    local sel
    check(R, ("GetGuildEventSelectionInfo(%d)"):format(i), function()
        local s = call("C_Calendar.GetGuildEventSelectionInfo", i)
        if type(s) ~= "table" then return FEHLT, show(s) end
        sel = s
        return "OK", ("offsetMonths %s, offsetMonth %s, monthDay %s, eventIndex %s"):format(show(s.offsetMonths), show(s.offsetMonth),
            show(s.monthDay), show(s.eventIndex))
    end)
    if not sel then return after(false, false) end
    local offset = Cal.Offset(sel)
    local okCall, result
    step(P, OPEN_EVENTS, "all", function()
        okCall, result = pcall(call, "C_Calendar.OpenEvent", offset, sel.monthDay, sel.eventIndex)
        if okCall then P.open = true end
        return okCall
    end, function(complete, got)
        if not okCall then
            if type(result) == "table" and result.missing then
                add(R, FEHLT, "OpenEvent", L["%s fehlt"]:format(result.missing))
            else
                add(R, "FEHLER", "OpenEvent", cut(tostring(result)))
            end
        else
            add(R, result == true and "OK" or FEHLT, ("OpenEvent(%s, %s, %s)"):format(show(offset), show(sel.monthDay), show(sel.eventIndex)), show(result))
            local seen = gotText(got, OPEN_EVENTS)
            if complete then
                add(R, "OK", L["Antwort"], seen)
            else
                add(R, seen and "WERT" or FEHLT, L["Antwort"], L["nach %d s: %s"]:format(CT.WAIT, seen or L["nichts"]))
            end
            read(R)
        end
        local blocked = blockedLines(P, P.phase)
        P.wasBlocked = P.wasBlocked or (#blocked > 0)
        if #blocked > 0 then
            add(R, "FEHLER", L["Blockiert"], table.concat(blocked, "; "))
        else
            add(R, "OK", L["Blockiert"], L["nichts (ADDON_ACTION_BLOCKED / _FORBIDDEN für Amisia)"])
        end
        if P.open then
            check(R, "CloseEvent", function()
                call("C_Calendar.CloseEvent")
                P.open = false
                return "OK", L["geschlossen"]
            end)
        end
        after(okCall and result == true, okCall)
    end)
end

-- The event's head and up to MAX_INVITES invites; the names and the response time for check 20.
local function readEvent(P)
    return function(R)
        check(R, "GetEventInfo", function()
            local e = call("C_Calendar.GetEventInfo")
            if type(e) ~= "table" then return FEHLT, show(e) end
            local title = P.target.info.title
            local same = not isSecret(e.title) and not isSecret(title) and e.title == title
            return same and "OK" or "WERT", L["%s, %s, Einladungsart %s, Art %s, %s; Titel wie das Gildenereignis: %s"]:format(show(e.title),
                show(e.calendarType), enumText(e.inviteType, INVITE_TYPES), enumText(e.eventType, EVENT_TYPES),
                stamp(e.time) or show(e.time), same and L["ja"] or L["nein"])
        end)
        local n = 0
        check(R, "GetNumInvites", function()
            local v = call("C_Calendar.GetNumInvites")
            n = not isSecret(v) and tonumber(v) or 0
            return n > 0 and "OK" or "WERT", show(v)
        end)
        P.invites = n
        P.names = {}
        for i = 1, math.min(n, MAX_INVITES) do
            check(R, ("EventGetInvite(%d)"):format(i), function()
                local v = call("C_Calendar.EventGetInvite", i)
                if type(v) ~= "table" then return "WERT", show(v) end
                P.names[#P.names + 1] = v.name
                local notes = plain(v.notes)
                return "WERT", L["%s, %s, Stufe %s, Status %s, modStatus %s, Art %s, Notiz %s"]:format(show(v.name), show(v.classFilename),
                    show(v.level), statusText(v.inviteStatus), show(v.modStatus), enumText(v.type, INVITE_TYPES),
                    type(notes) == "string" and notes ~= "" and L["ja"] or L["nein"])
            end)
        end
        if n > MAX_INVITES then add(R, "WERT", L["Weitere"], L["%d weitere nicht gezeigt"]:format(n - MAX_INVITES)) end
        -- check 20 needs the open event: the response time is read now, written later
        if n > 0 then
            local ok, t = pcall(call, "C_Calendar.EventGetInviteResponseTime", 1)
            P.response = { ok = ok, value = t }
        end
    end
end

local function check19(P)
    local R = P.R
    K.section(R, L["19 Ohne Tastendruck"])
    P.phase = "19"
    add(R, "WERT", L["Warten"], L["%d s, dann dasselbe Öffnen aus einem C_Timer.After"]:format(CT.DELAY))
    C_Timer.After(CT.DELAY, safe(P, function()
        openTarget(P, false, function(R2)
            check(R2, "GetNumInvites", function()
                local v = call("C_Calendar.GetNumInvites")
                P.invites19 = not isSecret(v) and tonumber(v) or 0
                return P.invites19 > 0 and "OK" or "WERT", show(v)
            end)
        end, function(ok)
            P.result19 = ok and not P.blocked19() and "ok" or "bad"
            finishProbe(P)
        end)
    end))
end

check18 = function(P)
    local R = P.R
    K.section(R, L["18 Teilnehmerliste ohne Kalenderfenster"])
    P.phase = "18"
    -- a raid-type guild event first; else any guild event (the client asks for a raid instance with
    -- the type "Schlachtzug", which Forever may not offer before its raids open: 2026-10-10)
    P.target = Cal.PickTarget(P.events)
    if not P.target then
        add(R, "WERT", L["Ereignis"], L["kein Gildenereignis (GUILD_EVENT): eins anlegen und neu prüfen"])
        P.skipped = L["kein Gildenereignis"]
        return finishProbe(P)
    end
    add(R, "WERT", L["Ereignis"], L["Nummer %d: %s"]:format(P.target.index, show(P.target.info.title)))
    if calendarWindow() then
        add(R, "WERT", L["Kalenderfenster"], L["offen: 18 und 19 übersprungen (es reagiert auf jedes Öffnen). Fenster schließen und neu prüfen."])
        P.skipped = L["Kalenderfenster offen"]
        return finishProbe(P)
    end
    openTarget(P, P.fromKey, readEvent(P), function(ok, called)
        P.result18 = ok and P.invites and P.invites > 0 and "ok" or (ok and "empty" or "bad")
        if called then return check19(P) end
        K.section(R, L["19 Ohne Tastendruck"])
        add(R, "WERT", L["Aufruf"], L["nicht geprüft (OpenEvent ließ sich in 18 nicht aufrufen)"])
        finishProbe(P)
    end)
end

---------------------------------------------------------------------------
-- 20 and the end
---------------------------------------------------------------------------
local function section20(P)
    local R = P.R
    K.section(R, L["20 Name und Zeit"])
    if not P.names then
        add(R, "WERT", L["Namen"], L["nicht geprüft (keine Teilnehmerliste gelesen)"])
        return
    end
    local with, without, secret, sample = 0, 0, 0, nil
    for _, name in ipairs(P.names) do
        if isSecret(name) then
            secret = secret + 1
        elseif type(name) == "string" then
            if name:find(" ", 1, true) then with = with + 1 else without = without + 1 end
            sample = sample or name
        end
    end
    if with + without == 0 then
        add(R, "WERT", L["Namen"], secret > 0 and L["%d geheim"]:format(secret) or L["keine Namen"])
    else
        add(R, without == 0 and "OK" or "WERT", L["Namen mit Nachname"], L["%d mit Leerzeichen, %d ohne, %d geheim; zum Beispiel %s"]:format(
            with, without, secret, show(sample)))
    end
    local r = P.response
    if not r then
        add(R, "WERT", "EventGetInviteResponseTime(1)", L["nicht geprüft (keine Teilnehmer)"])
    elseif not r.ok then
        if type(r.value) == "table" and r.value.missing then
            add(R, FEHLT, "EventGetInviteResponseTime(1)", L["%s fehlt"]:format(r.value.missing))
        else
            add(R, "FEHLER", "EventGetInviteResponseTime(1)", cut(tostring(r.value)))
        end
    else
        local text = stamp(r.value)
        add(R, text and "OK" or "WERT", "EventGetInviteResponseTime(1)", text or show(r.value))
    end
end

local function summary(P)
    local list
    if P.skipped then
        list = L["übersprungen (%s)"]:format(P.skipped)
    elseif P.result18 == "ok" then
        list = L["gelesen (%d)"]:format(P.invites or 0)
    elseif P.result18 == "empty" then
        list = L["leer"]
    else
        list = L["nicht gelesen"]
    end
    local timer
    if P.result19 == "ok" then
        timer = L["geht"]
    elseif P.wasBlocked then
        timer = L["blockiert"]
    elseif P.result19 then
        timer = L["geht nicht"]
    else
        timer = L["nicht geprüft"]
    end
    return L["Kalender-Prüfung: %s Gildenereignisse, Teilnehmerliste %s, ohne Tastendruck %s, %d Problem(e). Bericht im Fenster."]:format(
        P.count and tostring(P.count) or "?", list, timer, #P.R.problems)
end

finishProbe = function(P)
    if P.finished then return end
    P.finished = true
    P.waiter = nil
    -- never leave an event open
    if P.open and fn("C_Calendar.CloseEvent") then pcall(C_Calendar.CloseEvent) end
    if P.started then pcall(section20, P) end
    listen(false)
    Cal.Hold(false)
    if run == P then run = nil end
    local R = K.finish(P.R, L["Amisia-Kalender-Prüfung %s | Client %s | %s"])
    CT.last = R
    ST.ShowText(R.text, function() CT.Start() end)
    ns.msg(summary(P))
end

---------------------------------------------------------------------------
-- The start (the slash command)
---------------------------------------------------------------------------
function CT.Start()
    if run and not run.finished and GetTime() - run.at < STALE then
        ns.msg(L["Kalender-Prüfung läuft schon."])
        return
    end
    -- the lineup reads an event right now: its open would take the probe's answer (and close it)
    if Cal.Busy() then
        ns.msg(Cal.Why("busy"))
        return
    end
    local P = { R = K.newReport(), blocked = {}, at = GetTime(), phase = "17" }
    P.blocked19 = function() return #blockedLines(P, "19") > 0 end
    run = P
    local R = P.R
    K.section(R, L["Kalender: Funktionen"])
    if type(_G.C_Calendar) ~= "table" then
        add(R, FEHLT, "C_Calendar", L["fehlt"])
        return finishProbe(P)
    end
    local lack = {}
    for _, path in ipairs(CT.READ) do
        if not fn(path) then lack[#lack + 1] = path end
    end
    if #lack == 0 then
        add(R, "OK", L["Lesefunktionen"], L["alle %d vorhanden"]:format(#CT.READ))
    else
        add(R, FEHLT, L["Lesefunktionen"], L["%d von %d fehlen: %s"]:format(#lack, #CT.READ, table.concat(lack, ", ")))
    end
    local have, miss = {}, {}
    for _, name in ipairs(CT.WRITE) do
        if fn("C_Calendar." .. name) then have[#have + 1] = name else miss[#miss + 1] = name end
    end
    add(R, "WERT", L["Schreibfunktionen (für 23 bis 25, nicht aufgerufen)"], L["da: %s; fehlen: %s"]:format(
        #have > 0 and table.concat(have, ", ") or L["keine"], #miss > 0 and table.concat(miss, ", ") or L["keine"]))
    local window = calendarWindow()
    add(R, "WERT", L["Kalenderfenster"], window == nil and L["nicht geladen"] or (window and L["offen"] or L["zu"]))
    P.started = true
    listen(true)
    -- the lineup and the sign-up open nothing while the probe has the calendar
    Cal.Hold(true)
    ns.msg(L["Kalender-Prüfung läuft (bis etwa %d s) ..."]:format(3 * CT.WAIT + CT.DELAY))
    K.section(R, L["17 Termine lesen"])
    if not fn("C_Calendar.OpenCalendar") then
        add(R, FEHLT, "OpenCalendar", L["%s fehlt"]:format("C_Calendar.OpenCalendar"))
        return readList(P, nil, false, {})
    end
    local okBefore, before = pcall(call, "C_Calendar.GetNumGuildEvents")
    before = okBefore and not isSecret(before) and tonumber(before) or 0
    if before > 0 then
        -- the list is loaded already: everything up to the open of 18 runs inside the key press
        local ok, err = pcall(C_Calendar.OpenCalendar)
        if not ok then add(R, "FEHLER", "OpenCalendar", cut(tostring(err))) end
        P.fromKey = true
        return safe(P, readList)(P, before)
    end
    step(P, LIST_EVENTS, "any", function()
        local ok, err = pcall(C_Calendar.OpenCalendar)
        if not ok then add(R, "FEHLER", "OpenCalendar", cut(tostring(err))) end
        return ok
    end, function(complete, got) readList(P, nil, complete, got) end)
end
