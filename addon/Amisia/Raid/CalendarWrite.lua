-- Amisia calendar writing (part H3 of the spec docs/specs/2026-10-10-raid-aufstellung.md, D-42): the
-- player signs up, tentative or off in the game calendar with the same click that signs up in Amisia.
-- Only the own character (the client's functions know no other), only a guild event with sign-up
-- (inviteType Signup), never for an event the player created, never in combat, never while the
-- client's calendar window is shown, never from a message (the login's re-send and the answers to
-- AQ never come here), never retried from a timer. The calls are the client's own (its calendar
-- window, Blizzard_Calendar.lua 2909-3070: on a sign-up event "Anmelden" EventSignUp, "Vorläufig"
-- EventTentative, both only while not signed up, "Entfernen" RemoveEvent; the right-click menu
-- ContextMenuSelectEvent + ContextMenuEventSignUp):
--   Anmelden   not signed up: ContextMenuSelectEvent + ContextMenuEventSignUp, inside the click;
--              tentative: RemoveEvent, then EventSignUp (the event opened first)
--   Vorläufig  not signed up: EventTentative; signed up: RemoveEvent, then EventTentative
--   Abmelden   signed up or tentative: RemoveEvent
-- Afterwards the own status is read again (the day event, else the opened event); a call the client
-- blocked (ADDON_ACTION_BLOCKED/FORBIDDEN for Amisia), CALENDAR_UPDATE_ERROR or a status that did not
-- change ends with "err" and its reason, and the window asks the player to sign up in the calendar.
-- The calendar probe /amisia selbsttest kalender schreiben (Core/SelfTestCalendarWrite.lua) tries
-- every one of these calls on its own and reports which work; CW.PLAN is the place to change them.
local ADDON, ns = ...
local L, N_ = ns.L, ns.N_

local CW = {}
ns.CalWrite = CW

CW.CHECK_AFTER = 2       -- seconds after the calls (or the first calendar event) before the status is read
CW.WAIT = 8              -- seconds until the status must have changed
local plain = ns.Plain

-- the status groups of the calendar module (Enum.CalendarStatus)
CW.IN, CW.TENT, CW.OUT = ns.Cal.IN, ns.Cal.TENT, ns.Cal.OUT
local WANT = { A = CW.IN, V = CW.TENT, X = CW.OUT }

-- What a click needs, by the wanted status and the group of the status now: a list of steps (each
-- the name of a client function; "menu" = ContextMenuSelectEvent + ContextMenuEventSignUp inside the
-- click), nil when nothing is to do.
CW.PLAN = {
    A = { OUT = { "menu" }, TENT = { "RemoveEvent", "EventSignUp" } },
    V = { OUT = { "EventTentative" }, IN = { "RemoveEvent", "EventTentative" } },
    X = { IN = { "RemoveEvent" }, TENT = { "RemoveEvent" } },
}
-- the client functions a plan may call (and the reads it needs)
CW.FUNCS = { "GetDayEvent", "ContextMenuSelectEvent", "ContextMenuEventSignUp", "EventSignUp", "EventTentative", "RemoveEvent" }

local function api(name)
    local C = _G.C_Calendar
    local f = type(C) == "table" and C[name]
    return type(f) == "function" and f or nil
end

local function call(name, ...)
    local f = api(name)
    if not f then return nil end
    local ok, a = pcall(f, ...)
    if not ok then return nil end
    return a
end

function CW.Group(status)
    if CW.IN[status] then return "IN" end
    if CW.TENT[status] then return "TENT" end
    if CW.OUT[status] then return "OUT" end
    return nil
end

-- The steps for wanting status (A/V/X) from the calendar status now; nil: nothing to do.
function CW.Plan(want, status)
    local p = CW.PLAN[want]
    local g = CW.Group(status)
    return p and g and p[g] or nil
end

-- Whether the client has every function of the writes.
function CW.Available()
    if not ns.Cal.CanReadInvites() then return false end
    for _, n in ipairs(CW.FUNCS) do
        if not api(n) then return false end
    end
    return true
end

-- The event as it stands now (ns.Cal.Target: its day event, own status, sign-up type, creator).
CW.Target = ns.Cal.Target

---------------------------------------------------------------------------
-- Watching the client while a write runs
---------------------------------------------------------------------------
local BLOCK = { ADDON_ACTION_BLOCKED = true, ADDON_ACTION_FORBIDDEN = true }
local ERRORS = { CALENDAR_UPDATE_ERROR = true, CALENDAR_UPDATE_ERROR_WITH_COUNT = true, CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME = true }
local CHANGES = { CALENDAR_UPDATE_EVENT_LIST = true, CALENDAR_UPDATE_GUILD_EVENTS = true, CALENDAR_UPDATE_EVENT = true,
                  CALENDAR_UPDATE_INVITE_LIST = true }
CW.WATCH = {}
for _, t in ipairs({ BLOCK, ERRORS, CHANGES }) do
    for e in pairs(t) do CW.WATCH[#CW.WATCH + 1] = e end
end
table.sort(CW.WATCH)

local watcher, job

local function onEvent(_, event, ...)
    local j = job
    if not j then return end
    if BLOCK[event] then
        local who, what = ...
        if plain(who) == ADDON then j.blocked = j.blocked or tostring(plain(what) or "?") end
    elseif ERRORS[event] then
        j.error = j.error or tostring(plain((...)) or event)
    elseif CHANGES[event] and j.onChange then
        j.onChange()
    end
end

local function listen(on)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", onEvent)
    end
    for _, e in ipairs(CW.WATCH) do
        if on then pcall(watcher.RegisterEvent, watcher, e) else pcall(watcher.UnregisterEvent, watcher, e) end
    end
end

-- Runs the steps; true, or false and the error of the client's function.
local function runSteps(t, steps)
    for _, s in ipairs(steps) do
        local ok, err
        if s == "menu" then
            ok, err = pcall(C_Calendar.ContextMenuSelectEvent, t.offset, t.day, t.index)
            if ok then ok, err = pcall(C_Calendar.ContextMenuEventSignUp) end
        else
            ok, err = pcall(C_Calendar[s])
        end
        if not ok then return false, tostring(err) end
    end
    return true
end

---------------------------------------------------------------------------
-- The write of a click
---------------------------------------------------------------------------
-- The reasons (chat and the hint's tooltip).
local WHY = {
    off = N_("Einstellung \"Auch im Spielkalender eintragen\" ist aus."),
    nofunc = N_("Der Spielkalender bietet die nötigen Funktionen nicht."),
    combat = N_("Im Kampf trägt Amisia nicht in den Kalender ein."),
    window = N_("Das Kalenderfenster des Spiels ist offen."),
    busy = N_("Der Kalender ist gerade beschäftigt."),
    gone = N_("Das Ereignis steht nicht mehr im Kalender."),
    nosignup = N_("Das Ereignis ist kein Gildenereignis mit Anmeldung."),
    blocked = N_("Das Spiel hat den Eintrag blockiert."),
    error = N_("Der Kalender meldet einen Fehler."),
    unchanged = N_("Der Kalender zeigt keinen neuen Stand."),
    open = N_("Der Kalender hat das Ereignis nicht geöffnet."),
    failed = N_("Der Aufruf im Kalender ging schief."),
    status = N_("Der Kalender nennt deinen Stand bei diesem Ereignis nicht."),
    unknown = N_("Der Kalender sagt nicht, wer das Ereignis angelegt hat."),
}
-- what a refusal inside the open event (Write's use) turns into
local OPEN_WHY = { combat = "combat", window = "window", other = "open" }
function CW.Why(why) return L[WHY[why] or WHY.failed] end

function CW.Busy() return job ~= nil end

local function finish(j, ok, why)
    if j.done then return end
    j.done = true
    if job == j then
        job = nil
        listen(false)
    end
    j.fn(ok, why, j.detail)
end

local verify

-- One check at a time: the next in d seconds unless one waits already.
local function schedule(j, d)
    if j.done or j.pending then return end
    j.pending = true
    C_Timer.After(d, function()
        j.pending = false
        verify(j)
    end)
end

-- Reads the own status after the calls: the day event, every CW.CHECK_AFTER seconds; at CW.WAIT the
-- event opened once more for the last word (its own status).
verify = function(j)
    if j.done then return end
    if j.blocked then return finish(j, false, "blocked") end
    if j.error then
        j.detail = j.error
        return finish(j, false, "error")
    end
    local t = CW.Target(j.ev)
    if t and WANT[j.want][t.status] then return finish(j, true) end
    if GetTime() - j.at < CW.WAIT then return schedule(j, CW.CHECK_AFTER) end
    -- the last word: the opened event's own status
    ns.Cal.Open(j.ev, function()
        local info = call("GetEventInfo")
        return type(info) == "table" and plain(info.inviteStatus) or nil
    end, function(status, why)
        if j.done then return end
        if j.blocked then return finish(j, false, "blocked") end
        if type(status) == "number" and WANT[j.want][status] then return finish(j, true) end
        finish(j, false, status == nil and why == "window" and "window" or "unchanged")
    end)
end

-- The player's click: want (A/V/X) for term (an entry of ns.SignupTerms()). fn(ok, why) when it is
-- done (ok true: the calendar shows it, or there was nothing to do; why "creator" when the player
-- created the event: nothing written). Returns false and why when nothing could start (fn is called
-- too), true when it runs.
function CW.Write(term, want, fn)
    local function no(why)
        fn(false, why)
        return false, why
    end
    if not WANT[want] then return no("failed") end
    if not CW.Available() then return no("nofunc") end
    if InCombatLockdown() then return no("combat") end
    if job or ns.Cal.Busy() then return no("busy") end
    if ns.Cal.WindowShown() then return no("window") end
    local t, why = CW.Target(term)
    if not t then return no(why) end
    if not t.signup then return no("nosignup") end
    if t.creator then
        fn(true, "creator")
        return true, "creator"
    end
    -- the creator's remove may delete the event for everyone: unknown counts as no
    if t.creator == nil then return no("unknown") end
    -- an own status the groups do not know: nothing to plan, and not "the same"
    if not CW.Group(t.status) then return no("status") end
    local steps = CW.Plan(want, t.status)
    if not steps then
        fn(true, "same")
        return true, "same"
    end
    local j = { ev = t.ev, want = want, fn = fn, at = GetTime() }
    job = j
    listen(true)
    -- a change in the calendar: the status is read a moment later
    j.onChange = function() if j.called then schedule(j, CW.CHECK_AFTER) end end
    local function after(ok, err)
        j.called = true
        if not ok then
            j.detail = err
            return finish(j, false, j.blocked and "blocked" or OPEN_WHY[err] or "failed")
        end
        if j.blocked then return finish(j, false, "blocked") end
        schedule(j, CW.CHECK_AFTER)
    end
    if steps[1] == "menu" then
        -- inside the click: the client's right-click menu
        local ok, err = runSteps(t, steps)
        after(ok, err)
        return true
    end
    -- the event opened first: the client's buttons act on the open event
    ns.Cal.Open(t.ev, function()
        -- a fight that began while the client opened it, the client's calendar window opened
        -- meanwhile, or another event open (the player's click, another addon): nothing is called
        if InCombatLockdown() then return { false, "combat" } end
        if ns.Cal.WindowShown() then return { false, "window" } end
        if not ns.Cal.OpenIsSignup(t.ev) then return { false, "other" } end
        return { runSteps(t, steps) }
    end, function(res, whyOpen)
        if j.done then return end
        if not res then return finish(j, false, whyOpen == "window" and "window" or "open") end
        after(res[1], res[2])
    end)
    return true
end

-- for the tests
CW._reset = function() job = nil if watcher then listen(false) end end
