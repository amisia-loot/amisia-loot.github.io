-- /amisia selbsttest kalender schreiben (en selftest calendar write): the in-game checks 23 to 25 of
-- the raid lineup spec (part H3) done by the addon itself. It WRITES into the calendar: on the first
-- guild event the player did not create (modStatus ~= "CREATOR", a sign-up event first) it signs up,
-- goes tentative, removes the sign-up and declines with every way the client offers (the right-click
-- menu ContextMenuSelectEvent + ContextMenuEventSignUp / ContextMenuInviteTentative, and after
-- OpenEvent EventSignUp, EventTentative, EventDecline, RemoveEvent), reads the own status after each
-- (the event opened once more: GetEventInfo().inviteStatus, and the day event), watches
-- ADDON_ACTION_BLOCKED/FORBIDDEN and CALENDAR_UPDATE_ERROR, and at the end puts the old status back
-- as well as it can. Nothing happens before the chat warning and the player's "Ausführen" in the
-- question window; the first write (the menu's sign-up) runs inside that click, the others wait for
-- the client's answers (timers), and the report says whether a write from a timer was blocked.
-- Never for an event the player created, never in combat, never while the client's calendar window
-- is shown. The report goes into the self-test window.
local ADDON, ns = ...
local L = ns.L

local ST = ns.SelfTest
local K = ST.Kit
local add, show, fn, cut = K.add, K.show, K.fn, K.cut
local Cal = ns.Cal
local plain = ns.Plain

local WP = {}
ST.CalendarWrite = WP

WP.WAIT = 5          -- seconds to wait for each answer of the client (the open, a change after a write)
WP.SETTLE = 1        -- seconds after a write's first calendar event before the status is read
local MAX_STEPS = 24 -- writes of one run (the tests, the steps between them, the restore)
local STALE = 180    -- a run older than this counts as gone

-- The statuses (Enum.CalendarStatus) a test starts from or expects: NS not signed up (NotSignedup,
-- Invited), IN signed up, TENT tentative, DECL declined.
local IS = {
    NS = { [7] = true, [0] = true },
    IN = Cal.IN,
    TENT = Cal.TENT,
    DECL = { [2] = true },
    OUT = Cal.OUT,
}
-- The tests in their order: key, label, from, how (menu: inside the click when it is the first step,
-- the right-click menu's functions; open: the event opened first), the client function, expected.
WP.TESTS = {
    { key = "23a", from = "NS", how = "menu", call = "ContextMenuEventSignUp", expect = "IN" },
    { key = "25a", from = "IN", how = "open", call = "RemoveEvent", expect = "OUT" },
    { key = "23b", from = "NS", how = "open", call = "EventSignUp", expect = "IN" },
    { key = "24a", from = "IN", how = "open", call = "EventTentative", expect = "TENT" },
    { key = "25b", from = "IN", how = "open", call = "EventDecline", expect = "DECL" },
    { key = "24b", from = "NS", how = "open", call = "EventTentative", expect = "TENT" },
    { key = "25c", from = "TENT", how = "open", call = "RemoveEvent", expect = "OUT" },
    { key = "24c", from = "NS", how = "menu", call = "ContextMenuInviteTentative", expect = "TENT" },
}
local LABEL = {
    ["23a"] = L["23 Anmelden über das Kontextmenü (ContextMenuSelectEvent + ContextMenuEventSignUp)"],
    ["25a"] = L["25 Entfernen (RemoveEvent nach OpenEvent)"],
    ["23b"] = L["23 Anmelden (EventSignUp nach OpenEvent)"],
    ["24a"] = L["24 Vorläufig, wenn angemeldet (EventTentative ohne Entfernen)"],
    ["25b"] = L["25 Absagen (EventDecline; das Kalenderfenster zeigt es bei Anmelde-Ereignissen nicht)"],
    ["24b"] = L["24 Vorläufig (EventTentative nach OpenEvent)"],
    ["25c"] = L["25 Entfernen aus Vorläufig (RemoveEvent)"],
    ["24c"] = L["24 Vorläufig über das Kontextmenü (ContextMenuInviteTentative)"],
}
-- the steps that bring the status to a test's start (the client window's own calls)
local TO = { NS = "RemoveEvent", IN = "EventSignUp", TENT = "EventTentative" }

local function statusText(v)
    local s = type(v) == "number" and Cal.STATUS[v]
    return s and ("%d %s"):format(v, s[1]) or show(v)
end

---------------------------------------------------------------------------
-- One run at a time, its own event frame only while it runs
---------------------------------------------------------------------------
local run
local watcher
local OPEN_EVENTS = { CALENDAR_OPEN_EVENT = true }
local CHANGE_EVENTS = { CALENDAR_UPDATE_EVENT_LIST = true, CALENDAR_UPDATE_GUILD_EVENTS = true, CALENDAR_UPDATE_EVENT = true,
                        CALENDAR_UPDATE_INVITE_LIST = true }
local ERROR_EVENTS = { CALENDAR_UPDATE_ERROR = true, CALENDAR_UPDATE_ERROR_WITH_COUNT = true, CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME = true }

local function onEvent(_, event, ...)
    local P = run
    if not P then return end
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local who, what = ...
        if plain(who) == ADDON then
            P.blocked[#P.blocked + 1] = { event = event, what = tostring(plain(what) or "?"), phase = P.phase }
        end
        return
    end
    if ERROR_EVENTS[event] then
        P.errors[#P.errors + 1] = { event = event, what = tostring(plain((...)) or "?"), phase = P.phase }
    end
    if CHANGE_EVENTS[event] then
        if P.changeWatch then P.changeWatch() end
        if P.onChange then P.onChange() end
    end
    if P.waiter then P.waiter(event) end
end

local function listen(on)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", onEvent)
    end
    local all = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
    for _, t in ipairs({ OPEN_EVENTS, CHANGE_EVENTS, ERROR_EVENTS }) do
        for e in pairs(t) do all[#all + 1] = e end
    end
    for _, e in ipairs(all) do
        if on then pcall(watcher.RegisterEvent, watcher, e) else pcall(watcher.UnregisterEvent, watcher, e) end
    end
end

local finishRun

local function safe(P, f)
    return function(...)
        local ok, err = pcall(f, ...)
        if not ok then
            add(P.R, "FEHLER", L["Ablauf"], cut(tostring(err)))
            finishRun(P, true)
        end
    end
end

-- Waits for one of set (a table of events) for at most WP.WAIT seconds; then nextStep(event or nil)
-- on the next frame. Set up before the call it waits for (the client may answer at once). Returns a
-- function that cancels the wait.
local function waitFor(P, set, nextStep)
    local finished = false
    local token = {}
    local function done(event)
        if finished then return end
        finished = true
        if P.waitToken == token then P.waiter = nil end
        C_Timer.After(0, safe(P, function() nextStep(event) end))
    end
    P.waitToken = token
    P.waiter = function(event) if set[event] then done(event) end end
    C_Timer.After(WP.WAIT, function() done(nil) end)
    return function()
        finished = true
        if P.waitToken == token then P.waiter = nil end
    end
end

local function phaseLines(list, phase)
    local out = {}
    for _, b in ipairs(list) do
        if b.phase == phase then out[#out + 1] = ("%s %s"):format(b.event, b.what) end
    end
    return out
end

-- The event's position now (by its id): offset, day, index; the day event's own status.
local function where(P)
    local t = Cal.Target(P.ev)
    if not t then return nil end
    P.pos = t
    return t
end

-- Opens the event (the calendar window must stay closed), then after(ok) with it open.
local function openEvent(P, after)
    local t = where(P)
    if not t then return after(false, L["Ereignis nicht mehr im Kalender"]) end
    if Cal.WindowShown() then return after(false, L["Kalenderfenster offen"]) end
    local cancel = waitFor(P, OPEN_EVENTS, function(event)
        if not event then return after(false, L["keine Antwort auf OpenEvent"]) end
        after(true)
    end)
    local ok, opened = pcall(C_Calendar.OpenEvent, t.offset, t.day, t.index)
    if not ok or opened == false then
        cancel()
        return after(false, ok and L["OpenEvent gab false"] or cut(tostring(opened)))
    end
    P.open = true
end

local function closeEvent(P)
    if P.open then
        pcall(C_Calendar.CloseEvent)
        P.open = false
    end
end

-- The own status: the event opened once more (GetEventInfo().inviteStatus) and the day event.
local function readStatus(P, after)
    openEvent(P, function(ok, why)
        local opened
        if ok then
            local info = select(2, pcall(C_Calendar.GetEventInfo))
            opened = type(info) == "table" and plain(info.inviteStatus) or nil
        end
        closeEvent(P)
        local t = where(P)
        after(opened, t and t.status, why)
    end)
end

-- One write: call (a client function) the way how says; then wait for the calendar's change, read the
-- status and report the line. after(statusNow).
local function write(P, label, how, callName, expect, fromKey, after)
    P.steps = P.steps + 1
    P.phase = label
    local before = P.cur
    -- the calendar's change after the write: listened for from before the call
    local changed = false
    local function report(okCall, err)
        local function done()
            readStatus(P, function(opened, dayStatus, why)
                local now = opened
                if type(now) ~= "number" then now = dayStatus end
                P.cur = type(now) == "number" and now or P.cur
                local blocked = phaseLines(P.blocked, label)
                local errors = phaseLines(P.errors, label)
                local met = expect and type(now) == "number" and IS[expect][now]
                local level = (#blocked > 0 or not okCall) and "FEHLER" or (met and "OK" or "WERT")
                local text = L["%s; vorher %s, nachher %s (geöffnet %s, Tag %s)"]:format(
                    fromKey and L["aus dem Klick"] or L["aus einem Timer"], statusText(before), statusText(now),
                    statusText(opened), statusText(dayStatus))
                if not okCall then text = text .. "; " .. L["Fehler: %s"]:format(cut(tostring(err))) end
                if #blocked > 0 then text = text .. "; " .. L["blockiert: %s"]:format(table.concat(blocked, ", ")) end
                if #errors > 0 then text = text .. "; " .. L["Kalenderfehler: %s"]:format(table.concat(errors, ", ")) end
                if why and type(opened) ~= "number" then text = text .. "; " .. why end
                add(P.R, level, label, text)
                if not fromKey and #blocked > 0 then P.timerBlocked = true end
                if not fromKey and okCall and #blocked == 0 then P.timerOk = true end
                after(now, met and okCall and #blocked == 0)
            end)
        end
        if not okCall then return done() end
        if changed then return C_Timer.After(WP.SETTLE, safe(P, done)) end
        local mine
        mine = function()
            if P.onChange == mine then P.onChange = nil end
            C_Timer.After(WP.SETTLE, safe(P, done))
        end
        P.onChange = mine
        -- no change within WP.WAIT: read anyway (only while this write still waits)
        C_Timer.After(WP.WAIT, safe(P, function()
            if P.onChange == mine then
                P.onChange = nil
                done()
            end
        end))
    end
    P.onChange = nil
    P.changeWatch = function() changed = true end
    if how == "menu" then
        local t = where(P)
        if not t then return report(false, L["Ereignis nicht mehr im Kalender"]) end
        local ok, err = pcall(C_Calendar.ContextMenuSelectEvent, t.offset, t.day, t.index)
        if ok then ok, err = pcall(C_Calendar[callName]) end
        return report(ok, err)
    end
    openEvent(P, function(opened, why)
        if not opened then
            closeEvent(P)
            return report(false, why)
        end
        if InCombatLockdown() then
            closeEvent(P)
            return report(false, L["im Kampf"])
        end
        local ok, err = pcall(C_Calendar[callName])
        closeEvent(P)
        report(ok, err)
    end)
end

---------------------------------------------------------------------------
-- The run: the tests in order, the steps between them, the restore
---------------------------------------------------------------------------
local function stop(P)
    if InCombatLockdown() then return L["Kampf"] end
    if Cal.WindowShown() then return L["Kalenderfenster geöffnet"] end
    if P.steps >= MAX_STEPS then return L["zu viele Schritte"] end
    return nil
end

local nextTest

local function restore(P)
    K.section(P.R, L["Alter Stand"])
    local want
    if IS.NS[P.s0] then want = "NS" elseif IS.TENT[P.s0] then want = "TENT" elseif IS.DECL[P.s0] then want = "DECL"
    elseif IS.IN[P.s0] then want = "IN" else want = "NS" end
    local function check()
        local ok = IS[want][P.cur] and true or false
        P.restored = ok
        local note = (P.s0 == 3 or P.s0 == 5) and (" " .. L["(Bestätigt und Ersatz setzt nur der Ersteller; wiederhergestellt als angemeldet.)"]) or ""
        add(P.R, ok and "OK" or "FEHLER", L["Wiederhergestellt"], L["vorher %s, jetzt %s"]:format(statusText(P.s0), statusText(P.cur)) .. note)
        finishRun(P)
    end
    local function step(i)
        if IS[want][P.cur] then return check() end
        local why = stop(P)
        if why or i > 3 then
            if why then add(P.R, "FEHLER", L["Abgebrochen"], why) end
            return check()
        end
        -- out first, then into the wanted state
        local name
        if want == "NS" or not IS.NS[P.cur] then
            name = "RemoveEvent"
        elseif want == "DECL" then
            name = "EventDecline"
        else
            name = TO[want]
        end
        write(P, L["Wiederherstellen: %s"]:format(name), "open", name, nil, false, function() step(i + 1) end)
    end
    step(1)
end

-- the next test that has not run: run it when the status fits, else one step towards its start
nextTest = function(P)
    local why = stop(P)
    if why then
        add(P.R, "FEHLER", L["Abgebrochen"], why)
        return restore(P)
    end
    local test
    for _, t in ipairs(WP.TESTS) do
        if not P.done[t.key] then test = t break end
    end
    if not test then return restore(P) end
    if not IS[test.from][P.cur] then
        if (P.tried[test.key] or 0) >= 2 then
            P.done[test.key] = "skip"
            add(P.R, "WERT", LABEL[test.key], L["nicht geprüft: Ausgangsstand %s nicht erreicht (jetzt %s)"]:format(test.from, statusText(P.cur)))
            return nextTest(P)
        end
        P.tried[test.key] = (P.tried[test.key] or 0) + 1
        local name = IS.NS[P.cur] and TO[test.from] or "RemoveEvent"
        return write(P, L["Schritt: %s"]:format(name), "open", name, nil, false, function() nextTest(P) end)
    end
    P.done[test.key] = true
    write(P, LABEL[test.key], test.how, test.call, test.expect, false, function(_, ok)
        P.results[test.key] = ok
        nextTest(P)
    end)
end

local function yesNo(v) return v and L["geht"] or L["geht nicht"] end

local function summary(P)
    local r = P.results
    local menu = r["23a"]
    return L["Kalender-Schreibprüfung: Anmelden (Menü) %s, Anmelden (EventSignUp) %s, Vorläufig %s, Entfernen %s, Absagen %s; aus einem Timer %s; alter Stand %s. Bericht im Fenster."]:format(
        yesNo(menu), yesNo(r["23b"]), yesNo(r["24b"] or r["24a"]), yesNo(r["25a"] or r["25c"]), yesNo(r["25b"]),
        P.timerBlocked and L["blockiert"] or (P.timerOk and L["nicht blockiert"] or L["nicht geprüft"]),
        P.restored and L["wiederhergestellt"] or L["NICHT wiederhergestellt"])
end

finishRun = function(P, failed)
    if P.finished then return end
    P.finished = true
    P.waiter = nil
    closeEvent(P)
    listen(false)
    Cal.Hold(false)
    if run == P then run = nil end
    if failed and P.restored == nil then
        add(P.R, "FEHLER", L["Wiederhergestellt"], L["unbekannt: bitte im Kalender nachsehen (vorher %s)"]:format(statusText(P.s0)))
    end
    local R = K.finish(P.R, L["Amisia-Kalender-Schreibprüfung %s | Client %s | %s"])
    WP.last = R
    WP.lastRun = P
    ST.ShowText(R.text, function() WP.Start() end)
    ns.msg(summary(P))
end

-- "Ausführen": the run, from the click. The first write (the menu's sign-up, when not signed up)
-- happens inside it.
local function execute(P)
    if InCombatLockdown() then return ns.msg(Cal.Why("combat")) end
    if Cal.WindowShown() then return ns.msg(L["Kalenderfenster schließen, dann noch einmal."]) end
    if Cal.Busy() or (ns.CalWrite and ns.CalWrite.Busy()) then return ns.msg(Cal.Why("busy")) end
    local t = where(P)
    if not t then return ns.msg(Cal.Why("gone")) end
    run = P
    P.at = GetTime()
    listen(true)
    Cal.Hold(true)
    P.s0, P.cur = t.status, t.status
    K.section(P.R, L["Ereignis"])
    add(P.R, "WERT", L["Ereignis"], L["%s, %s; Einladungsart %s, modStatus %s, dein Status %s"]:format(show(P.ev.title), ns.FmtDayTime(P.ev.at),
        show(t.inviteType), show(t.modStatus), statusText(t.status)))
    K.section(P.R, L["23 bis 25 Schreiben"])
    -- 23a inside the click when not signed up; otherwise later, from a timer
    if IS.NS[P.cur] then
        P.done["23a"] = true
        return write(P, LABEL["23a"], "menu", "ContextMenuEventSignUp", "IN", true, function(_, ok)
            P.results["23a"] = ok
            nextTest(P)
        end)
    end
    add(P.R, "WERT", LABEL["23a"], L["nicht im Klick: du warst schon angemeldet (%s); kommt nach dem Entfernen aus einem Timer"]:format(statusText(P.cur)))
    nextTest(P)
end

---------------------------------------------------------------------------
-- The start (the slash command): the checks, the warning, the question
---------------------------------------------------------------------------
-- The first guild event the player did not create, a sign-up event first; nil when there is none.
local function pick(list)
    local any
    for _, ev in ipairs(list or {}) do
        local t = Cal.Target(ev)
        if t and not t.creator then
            if t.signup then return ev, t end
            any = any or ev
        end
    end
    if any then return any, Cal.Target(any) end
    return nil
end

function WP.Start()
    if run and not run.finished and GetTime() - (run.at or 0) < STALE then
        ns.msg(L["Kalender-Schreibprüfung läuft schon."])
        return
    end
    if type(_G.C_Calendar) ~= "table" then
        ns.msg(Cal.Why("off"))
        return
    end
    local lack = {}
    for _, name in ipairs({ "OpenCalendar", "GetNumGuildEvents", "GetGuildEventInfo", "GetGuildEventSelectionInfo", "GetDayEvent", "OpenEvent",
                            "GetEventInfo", "CloseEvent", "ContextMenuSelectEvent", "ContextMenuEventSignUp", "ContextMenuInviteTentative",
                            "EventSignUp", "EventTentative", "EventDecline", "RemoveEvent" }) do
        if not fn("C_Calendar." .. name) then lack[#lack + 1] = name end
    end
    if #lack > 0 then
        ns.msg(L["Kalender-Schreibprüfung: es fehlen %s."]:format(table.concat(lack, ", ")))
        return
    end
    if InCombatLockdown() then return ns.msg(Cal.Why("combat")) end
    if Cal.WindowShown() then return ns.msg(L["Kalenderfenster schließen, dann noch einmal."]) end
    Cal.Load(function(list)
        local ev, t = pick(list)
        if not ev then
            ns.msg(L["Kalender-Schreibprüfung: braucht ein Gildenereignis der nächsten 14 Tage, das ein anderer Charakter angelegt hat (bei deinem eigenen bist du der Ersteller)."])
            return
        end
        local P = { R = K.newReport(), blocked = {}, errors = {}, done = {}, tried = {}, results = {}, steps = 0, ev = ev, pos = t }
        local warning = L["Kalender-Schreibprüfung: schreibt in den Kalender: meldet dich beim gewählten Ereignis an, vorläufig, entfernt dich und stellt danach deinen alten Stand wieder her. Ereignis: %s, %s (dein Status %s)."]:format(
            ev.title, ns.FmtDayTime(ev.at), statusText(t and t.status))
        ns.msg(warning)
        ns.W.Confirm(L["Kalender-Schreibprüfung"], warning, L["Ausführen"], function() execute(P) end, function()
            ns.msg(L["Kalender-Schreibprüfung abgebrochen: nichts geschrieben."])
        end)
    end)
end

-- for the tests
WP._run = function() return run end
