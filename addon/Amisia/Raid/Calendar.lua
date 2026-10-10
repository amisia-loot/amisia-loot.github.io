-- Amisia calendar reading (D-42, spec 2026-10-10 parts G and H): the guild events of the game
-- calendar and the invite list of one of them, read only. Shared by the raid lineup (part G: the
-- officer reads the sign-ups of an event), the raid sign-up (part H: the raider sees the coming
-- dates) and the calendar probe (/amisia selbsttest kalender), so all three read alike: every guild
-- event (GUILD_EVENT) counts, the raid type first (Forever offers the type "Schlachtzug" only with a
-- raid instance); GetGuildEventSelectionInfo's offsetMonths (the client's own code reads
-- offsetMonth); an event is never opened while the client's calendar window is shown (it shows every
-- opened event); the invite list is read after CALENDAR_OPEN_EVENT (CALENDAR_UPDATE_INVITE_LIST
-- counts too, the client 70338 sends only the first) and the event is closed after every read.
-- Nothing here signs up, invites, creates, changes or removes anything in the calendar.
local ADDON, ns = ...
local L, N_ = ns.L, ns.N_

local Cal = {}
ns.Cal = Cal

Cal.DAYS = 14             -- the dates shown: tonight's raid night up to 14 days ahead
Cal.WAIT = 10             -- seconds to wait for the client's answer
Cal.MAX_INVITES = 80      -- invites read of one event (the lineup's 80 names)
Cal.TITLE_MAX = 40
Cal.QUIET = 3             -- seconds after an own read in which calendar events are no change
local DAY = 86400

-- Enum.CalendarStatus: the client's name, Amisia's code (the lineup's st) and the probe's word
Cal.STATUS = {
    [0] = { "Invited", "I", N_("eingeladen") }, [1] = { "Available", "A", N_("angemeldet") },
    [2] = { "Declined", "X", N_("abgesagt") }, [3] = { "Confirmed", "B", N_("bestätigt") },
    [4] = { "Out", "X", N_("abgesagt") }, [5] = { "Standby", "E", N_("Ersatz") },
    [6] = { "Signedup", "A", N_("angemeldet") }, [7] = { "NotSignedup", "O", N_("ohne Antwort") },
    [8] = { "Tentative", "V", N_("vorläufig") },
}
-- Enum.CalendarEventType and Enum.CalendarInviteType (client names)
Cal.EVENT_TYPES = { [0] = "Raid", [1] = "Dungeon", [2] = "PvP", [3] = "Meeting", [4] = "Other", [5] = "HeroicDeprecated" }
Cal.INVITE_TYPES = { [0] = "Normal", [1] = "Signup" }
-- the event types as the page shows them
Cal.TYPE_WORD = { [0] = N_("Schlachtzug"), [1] = N_("Dungeon"), [2] = N_("PvP"), [3] = N_("Treffen"), [4] = N_("Sonstiges") }
local WEEKDAY = { N_("So##Tag"), N_("Mo##Tag"), N_("Di##Tag"), N_("Mi##Tag"), N_("Do##Tag"), N_("Fr##Tag"), N_("Sa##Tag") }

local plain = ns.Plain

local function api(name)
    local C = _G.C_Calendar
    local f = type(C) == "table" and C[name]
    return type(f) == "function" and f or nil
end
Cal.Api = api

-- Whether the guild events can be read (the sign-up's dates).
function Cal.Available()
    return api("OpenCalendar") ~= nil and api("GetNumGuildEvents") ~= nil and api("GetGuildEventInfo") ~= nil
end

-- Whether an event's invite list can be read too (the lineup).
function Cal.CanReadInvites()
    if not Cal.Available() then return false end
    for _, n in ipairs({ "GetGuildEventSelectionInfo", "OpenEvent", "GetNumInvites", "EventGetInvite", "CloseEvent" }) do
        if not api(n) then return false end
    end
    return true
end

-- The client's calendar window: true shown, false hidden, nil not loaded.
function Cal.WindowShown()
    local f = _G.CalendarFrame
    if type(f) ~= "table" or type(f.IsShown) ~= "function" then return nil end
    local ok, on = pcall(f.IsShown, f)
    return ok and on and true or false
end

-- "2026-10-11 20:00" and { year, month, day, hour, min } of a table with year, month, monthDay,
-- hour, minute; nil when one is not a plain number.
function Cal.Stamp(t)
    if type(t) ~= "table" then return nil end
    local y, m, d, h, mi = plain(t.year), plain(t.month), plain(t.monthDay), plain(t.hour), plain(t.minute)
    for _, v in ipairs({ y, m, d, h, mi }) do if type(v) ~= "number" then return nil end end
    return ("%04d-%02d-%02d %02d:%02d"):format(y, m, d, h, mi), { year = y, month = m, day = d, hour = h, min = mi }
end

-- The epoch of such a table (local time), or nil.
function Cal.Epoch(t)
    local _, tbl = Cal.Stamp(t)
    if not tbl then return nil end
    local ok, at = pcall(time, tbl)
    return ok and type(at) == "number" and at or nil
end

-- The month offset of GetGuildEventSelectionInfo: offsetMonths (2026-10-10 in game), else the name
-- the client's own code reads.
function Cal.Offset(sel)
    return plain(sel.offsetMonths) or plain(sel.offsetMonth) or 0
end

local function isGuildEvent(info)
    local ct = type(info) == "table" and plain(info.calendarType)
    return ct == "GUILD_EVENT"
end
Cal.IsGuildEvent = isGuildEvent

-- The event to take from a list of { info = GetGuildEventInfo } in its order: the first guild
-- event of the raid type, else the first guild event; nil when there is none.
function Cal.PickTarget(list)
    local any
    for _, ev in ipairs(list or {}) do
        local e = ev.info
        if isGuildEvent(e) then
            if plain(e.eventType) == 0 then return ev end
            any = any or ev
        end
    end
    return any
end

-- "Fr 20:00" (the weekday short in the client's language).
function Cal.When(at)
    if type(at) ~= "number" then return "?" end
    local d = date("*t", at)
    return ("%s %s"):format(L[WEEKDAY[d.wday]], date("%H:%M", at))
end

-- A text of the calendar (title, note) for display: codes and bars away, cut to max bytes.
function Cal.Clean(text, max)
    text = plain(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("[%c|]", " ")
    return ns.CleanNote and ns.CleanNote(text, max or Cal.TITLE_MAX) or text:sub(1, max or Cal.TITLE_MAX)
end

local function call(name, ...)
    local f = api(name)
    if not f then return nil end
    local ok, a = pcall(f, ...)
    if not ok then return nil end
    return a
end

-- The guild events loaded now, from tonight's raid night up to Cal.DAYS days ahead, by time:
-- { { index, id (digits), title, at, type, raid, own = status code or nil } }. The client lists
-- what OpenCalendar loaded; nothing is asked for here.
function Cal.Events()
    local out = {}
    local n = tonumber(plain(call("GetNumGuildEvents"))) or 0
    local now = time()
    local first = ns.NightOf and ns.NightOf(now) or date("%Y-%m-%d", now)
    local last = now + Cal.DAYS * DAY
    for i = 1, math.min(n, 100) do
        local e = call("GetGuildEventInfo", i)
        if isGuildEvent(e) then
            local at = Cal.Epoch(e)
            local night = at and (ns.NightOf and ns.NightOf(at) or date("%Y-%m-%d", at))
            if at and night >= first and at <= last then
                local id = plain(e.eventID)
                local typ = plain(e.eventType)
                local st = plain(e.inviteStatus)
                out[#out + 1] = { index = i, id = type(id) == "number" and ("%.0f"):format(id) or nil, at = at, night = night,
                    title = Cal.Clean(e.title) or "?", type = type(typ) == "number" and typ or nil, raid = typ == 0,
                    own = type(st) == "number" and Cal.STATUS[st] and Cal.STATUS[st][2] or nil, info = e }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.index < b.index
    end)
    return out
end

-- The event to preselect in a list of Cal.Events(): the next of the raid type, else the next.
function Cal.Next(list)
    return Cal.PickTarget(list)
end

---------------------------------------------------------------------------
-- Waiting for the client: one wait at a time
---------------------------------------------------------------------------
local held              -- the calendar probe runs (Cal.Hold)
local waiter            -- { want = { event = true }, done = fn(gotEvent) }
local busy = false      -- an own open is running
local quietUntil = 0    -- calendar events until then come from the own read

-- The page listens to Cal changes through ns.Listen("CALENDAR_CHANGED").
local CHANGE = { CALENDAR_UPDATE_EVENT_LIST = true, CALENDAR_UPDATE_GUILD_EVENTS = true, CALENDAR_UPDATE_INVITE_LIST = true,
                 CALENDAR_UPDATE_EVENT = true, CALENDAR_NEW_EVENT = true, CALENDAR_EVENT_ALARM = false }

local function onEvent(event, ...)
    if waiter and waiter.want[event] then
        local w = waiter
        waiter = nil
        w.done(event, ...)
        return
    end
    if CHANGE[event] and not busy and not held and GetTime() >= quietUntil then ns.Fire("CALENDAR_CHANGED", event) end
end
for _, e in ipairs({ "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_UPDATE_GUILD_EVENTS", "CALENDAR_OPEN_EVENT",
                     "CALENDAR_UPDATE_INVITE_LIST", "CALENDAR_UPDATE_EVENT", "CALENDAR_NEW_EVENT" }) do
    ns.OnEvent(e, function(...) onEvent(e, ...) end)
end

-- Waits for one of the events in want (a list) for at most Cal.WAIT seconds; then fn(event or nil).
local function wait(want, fn)
    local set, token = {}, {}
    for _, e in ipairs(want) do set[e] = true end
    local finished = false
    local function done(event)
        if finished then return end
        finished = true
        if waiter and waiter.token == token then waiter = nil end
        -- on the next frame: the client fills its lists after the event's handlers
        C_Timer.After(0, function() fn(event) end)
    end
    waiter = { want = set, done = done, token = token }
    C_Timer.After(Cal.WAIT, function() done(nil) end)
    -- cancels the wait without calling fn
    return function()
        finished = true
        if waiter and waiter.token == token then waiter = nil end
    end
end

function Cal.Busy() return busy end

-- The calendar probe (/amisia selbsttest kalender) opens events itself: while it runs, nothing
-- here opens one and no change is reported.
function Cal.Hold(on) held = on and true or false end

-- Loads the guild events (OpenCalendar) and calls fn(list) with Cal.Events(), or fn(nil, why):
-- "off" (no calendar). A list that is loaded already comes at once (OpenCalendar still asks the
-- client for the newest state; a change comes as CALENDAR_CHANGED).
function Cal.Load(fn)
    if not Cal.Available() then return fn(nil, "off") end
    local before = tonumber(plain(call("GetNumGuildEvents"))) or 0
    if before > 0 then
        pcall(C_Calendar.OpenCalendar)
        return fn(Cal.Events())
    end
    if waiter then return fn(Cal.Events()) end
    wait({ "CALENDAR_UPDATE_GUILD_EVENTS", "CALENDAR_UPDATE_EVENT_LIST" }, function() fn(Cal.Events()) end)
    pcall(C_Calendar.OpenCalendar)
end

-- The invites of the event the client has open now: { { name, class, level, code, status, note } }
-- (at most Cal.MAX_INVITES; secret and empty names left out) and the count the client named.
function Cal.ReadOpen()
    local out = {}
    local n = tonumber(plain(call("GetNumInvites"))) or 0
    for i = 1, math.min(n, Cal.MAX_INVITES) do
        local v = call("EventGetInvite", i)
        local name = type(v) == "table" and ns.FullName(plain(v.name)) or nil
        if name then
            local st = plain(v.inviteStatus)
            local class = plain(v.classFilename)
            out[#out + 1] = { name = name, class = type(class) == "string" and class or nil, level = tonumber(plain(v.level)),
                status = type(st) == "number" and st or nil, code = type(st) == "number" and Cal.STATUS[st] and Cal.STATUS[st][2] or nil,
                note = Cal.Clean(v.notes) }
        end
    end
    return out, n
end

-- Whether the open event (the calendar window's) is ev: same title and start.
local function openIs(ev)
    if not api("IsEventOpen") or call("IsEventOpen") ~= true then return false end
    local info = call("GetEventInfo")
    if type(info) ~= "table" then return false end
    return Cal.Clean(info.title) == ev.title and Cal.Epoch(info.time) == ev.at
end

local function close()
    pcall(C_Calendar.CloseEvent)
end

-- Reads the invite list of ev (an entry of Cal.Events()): fn(invites, n) or fn(nil, why) with why
-- "off" (no calendar or a function missing), "busy", "combat", "window" (the calendar window shows
-- another event), "gone" (the event is not in the calendar any more), "open" (OpenEvent refused),
-- "timeout" (no answer within Cal.WAIT). With the window showing exactly ev, it reads what the
-- window has open and leaves it open; else it opens ev itself and always closes it again.
function Cal.Read(ev, fn)
    if not Cal.CanReadInvites() then return fn(nil, "off") end
    if busy or waiter or held then return fn(nil, "busy") end
    if InCombatLockdown() then return fn(nil, "combat") end
    if Cal.WindowShown() then
        if openIs(ev) then return fn(Cal.ReadOpen()) end
        return fn(nil, "window")
    end
    -- the index may have moved since the list was read: find the event by its id (else its time)
    local now
    for _, e in ipairs(Cal.Events()) do
        if (ev.id and e.id == ev.id) or (not ev.id and e.at == ev.at and e.title == ev.title) then now = e break end
    end
    if not now then return fn(nil, "gone") end
    local sel = call("GetGuildEventSelectionInfo", now.index)
    if type(sel) ~= "table" then return fn(nil, "gone") end
    busy = true
    local function finish(list, n)
        close()
        busy = false
        quietUntil = GetTime() + Cal.QUIET
        fn(list, n)
    end
    local cancel = wait({ "CALENDAR_OPEN_EVENT", "CALENDAR_UPDATE_INVITE_LIST" }, function(event)
        if not event then return finish(nil, "timeout") end
        finish(Cal.ReadOpen())
    end)
    local ok, opened = pcall(C_Calendar.OpenEvent, Cal.Offset(sel), plain(sel.monthDay), plain(sel.eventIndex))
    if not ok or opened == false then
        cancel()
        close()
        busy = false
        quietUntil = GetTime() + Cal.QUIET
        return fn(nil, "open")
    end
end

-- The chat text of a reason of Cal.Read / Cal.Load.
local WHY = {
    off = N_("Kalender nicht verfügbar."),
    busy = N_("Der Kalender wird gerade gelesen."),
    combat = N_("Im Kampf liest Amisia den Kalender nicht. Nach dem Kampf noch einmal."),
    window = N_("Kalenderfenster schließen, dann Übernehmen."),
    gone = N_("Ereignis nicht mehr im Kalender."),
    open = N_("Der Kalender hat das Ereignis nicht geöffnet. Gleich noch einmal."),
    timeout = N_("Kalender antwortet nicht, gleich nochmal."),
}
function Cal.Why(why) return L[WHY[why] or WHY.off] end

-- for the tests
Cal._reset = function() waiter, busy, quietUntil, held = nil, false, 0, false end
