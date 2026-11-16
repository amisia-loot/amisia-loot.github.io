-- Amisia calendar edit and delete (F-222, D-147, spec docs/specs/2026-11-16-kalender-bearbeiten-loeschen.md):
-- the player changes or deletes an event of the game calendar from the calendar page, as far as the
-- game lets him (C_Calendar.ContextMenuEventCanEdit / ContextMenuEventCanRemove, the questions of the
-- client's right-click menu; Amisia gives nobody a right of its own). The calls are the client's own
-- (Blizzard_Calendar.lua: CalendarFrame_OpenEvent, CalendarCreateEventFrame in mode "edit",
-- CalendarCreateEventCreateButton_OnClick, CalendarDayContextMenu_DeleteEvent and its popup):
--   edit    OpenEvent (read), then inside the click on "Speichern" the changed fields (EventSetTitle,
--           EventSetDescription, EventSetTime, EventSetType, EventSetTextureID after the type) and
--           UpdateEvent, which needs a hardware event like AddEvent
--   delete  inside the click on the question's "Löschen": ContextMenuSelectEvent, ContextMenuEventRemove
-- One session at a time: CE.Begin finds the event by its eventID in the client's day list (setting the
-- event's month first when it is not the set one or a neighbour, and the month set before back at the
-- end), asks the game for the right and, for an edit, opens the event and holds it open while the form
-- shows (ns.Cal.Hold: no own read opens another one meanwhile). CE.Save and CE.Remove write, CE.Cancel
-- ends without a change. Never in combat, never while the client's calendar window is shown, never while
-- an answer is pending, never from a timer or a message, never retried. Day and kind of an event are
-- never changed, nothing is copied, nobody invited (D-147).
local ADDON, ns = ...
ns.Load(function()
local L, N_ = ns.L, ns.N_

local CE = {}
ns.CalEdit = CE

CE.WAIT = 10            -- seconds for the client's answer
CE.SETTLE = 0.3         -- seconds after the client's answer in which its error still counts
CE.WATCH_EVERY = 0.5    -- seconds between two looks at the client's calendar window while a session runs

local plain = ns.Plain
local Cal = ns.Cal
local api, call = Cal.api, Cal.call
local CC = function() return ns.CalCreate end

CE.FUNCS = { "GetMonthInfo", "GetNumDayEvents", "GetDayEvent", "SetAbsMonth", "CloseEvent" }
CE.FUNCS_EDIT = { "ContextMenuEventCanEdit", "OpenEvent", "GetEventInfo", "EventCanEdit", "EventSetTitle",
                  "EventSetDescription", "EventSetTime", "EventSetType", "EventSetTextureID", "UpdateEvent" }
CE.FUNCS_REMOVE = { "ContextMenuEventCanRemove", "ContextMenuSelectEvent", "ContextMenuEventRemove" }

local function has(list)
    for _, n in ipairs(list) do
        if not api(n) then return false end
    end
    return true
end
-- Whether the client has every function of an edit ("edit") or a delete ("remove").
function CE.Available(what)
    return has(CE.FUNCS) and has(what == "remove" and CE.FUNCS_REMOVE or CE.FUNCS_EDIT)
end

---------------------------------------------------------------------------
-- Finding an event of the sheet in the client's day list
---------------------------------------------------------------------------
-- The month the client's calendar has set: its index y * 12 + m - 1, y, m; nil when not known.
local function setMonth()
    local info = call("GetMonthInfo", 0)
    local y, m = type(info) == "table" and plain(info.year), type(info) == "table" and plain(info.month)
    if type(y) ~= "number" or type(m) ~= "number" then return nil end
    return y * 12 + (m - 1), y, m
end

-- Whether item (an event of the sheet: a sign-up date or one of ns.Cal.ReadMonth) is an event of the
-- game calendar that can be changed at all: no call of the guild, a kind the sheet shows.
function CE.IsEvent(item)
    if type(item) ~= "table" or item.call or type(item.at) ~= "number" then return false end
    return Cal.MONTH_KINDS[item.kind or "GUILD_EVENT"] == true
end

-- The months from the set one to item's (nil: the client names no month).
local function offsetOf(item)
    local cur = setMonth()
    if not cur then return nil end
    local t = date("*t", item.at)
    return t.year * 12 + (t.month - 1) - cur
end

-- item in the client's list of its day at the month offset: its index and the day event; nil when it
-- is not there. Found by its eventID, an item without one by its start and title.
local function locate(item, offset)
    local t = date("*t", item.at)
    local n = tonumber(plain(call("GetNumDayEvents", offset, t.day))) or 0
    for i = 1, math.min(n, Cal.DAY_MAX) do
        local e = call("GetDayEvent", offset, t.day, i)
        if type(e) == "table" then
            local id = plain(e.eventID)
            if item.id then
                if type(id) == "number" and ("%.0f"):format(id) == item.id then return i, e, t.day end
            elseif Cal.Epoch(e.startTime) == item.at and Cal.Clean(e.title) == item.title then
                return i, e, t.day
            end
        end
    end
    return nil
end

-- What the game lets the player do with item: { edit, remove } (booleans). Asked of the game when the
-- event's month is the set one or a neighbour; for a month further away (the client has not loaded
-- it) the links show for the player's own events and the game is asked once CE.Begin has set the month.
-- An event whose start has passed is never offered for an edit.
function CE.Rights(item)
    local out = { edit = false, remove = false }
    if not CE.IsEvent(item) then return out end
    local off = offsetOf(item)
    if not off then return out end
    local edit, remove
    if off >= -1 and off <= 1 then
        local index, _, day = locate(item, off)
        if not index then return out end
        edit = CE.Available("edit") and plain(call("ContextMenuEventCanEdit", off, day, index)) == true
        remove = CE.Available("remove") and plain(call("ContextMenuEventCanRemove", off, day, index)) == true
    else
        edit = CE.Available("edit") and item.creator == true
        remove = CE.Available("remove") and item.creator == true
    end
    local skew = CC() and CC().Skew() or 0
    out.edit = edit and item.at > time() + skew or false
    out.remove = remove or false
    return out
end

---------------------------------------------------------------------------
-- Reasons
---------------------------------------------------------------------------
local WHY = {
    right = N_("Das Spiel erlaubt dir das bei diesem Termin nicht."),
    gone = N_("Ereignis nicht mehr im Kalender."),
    open = N_("Der Kalender hat das Ereignis nicht geöffnet. Gleich noch einmal."),
    read = N_("Der Termin lässt sich gerade nicht lesen. Gleich noch einmal."),
    closed = N_("Der Termin wurde im Spiel geschlossen. Bitte noch einmal."),
    same = N_("Nichts geändert."),
    past = N_("Der Termin ist schon vorbei."),
    refused = N_("Das Spiel lässt Amisia keine Termine ändern oder löschen."),
    blocked = N_("Das Spiel hat den Aufruf blockiert."),
    timeout = N_("Der Kalender hat nicht geantwortet. Schau im Spielkalender nach, wie der Termin steht."),
    month = N_("Der Kalender hat den Monat des Termins nicht geladen. Gleich noch einmal."),
}
-- The text of a reason (the entry's reasons for what both share: combat, window, busy, pending, time ...).
function CE.Why(why)
    if WHY[why] then return L[WHY[why]] end
    return CC().Why(why)
end

---------------------------------------------------------------------------
-- The session and the client's events
---------------------------------------------------------------------------
local BLOCK = { ADDON_ACTION_BLOCKED = true, ADDON_ACTION_FORBIDDEN = true }
local ERRORS = { CALENDAR_UPDATE_ERROR = true, CALENDAR_UPDATE_ERROR_WITH_COUNT = true, CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME = true }
local ANSWER = { CALENDAR_UPDATE_EVENT = true, CALENDAR_UPDATE_EVENT_LIST = true, CALENDAR_ACTION_PENDING = true }
CE.WATCH = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "CALENDAR_UPDATE_ERROR", "CALENDAR_UPDATE_ERROR_WITH_COUNT",
             "CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME", "CALENDAR_OPEN_EVENT", "CALENDAR_CLOSE_EVENT", "CALENDAR_UPDATE_EVENT",
             "CALENDAR_UPDATE_EVENT_LIST", "CALENDAR_ACTION_PENDING", "PLAYER_REGEN_DISABLED" }

local watcher
local session           -- { item, what, stage ("find", "month", "opening", "open", "ready"), offset, day, index, back, info, job }
local refused           -- the game refused a write for Amisia: no more tries until /reload

-- The text of a client error (a global string's name, as the client's popup shows it).
local function errorText(name, extra)
    name = plain(name)
    local text = type(name) == "string" and _G[name]
    if type(text) == "string" and text ~= "" then
        if extra ~= nil and text:find("%%") then
            local ok, s = pcall(string.format, text, plain(extra))
            if ok then text = s end
        end
        return Cal.Clean(text, 200)
    end
    return type(name) == "string" and Cal.Clean(name, 200) or nil
end

local onEvent

local function listen(on)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", function(_, event, ...) onEvent(event, ...) end)
    end
    for _, e in ipairs(CE.WATCH) do
        if on then pcall(watcher.RegisterEvent, watcher, e) else pcall(watcher.UnregisterEvent, watcher, e) end
    end
end

-- Ends the session s: the event Amisia opened is closed again and the month set before comes back,
-- both unless the client's calendar window shows now (the event and the month are its own then).
local function release(s)
    if session ~= s then return end
    session = nil
    listen(false)
    local window = Cal.WindowShown()
    if s.opened and not window then pcall(C_Calendar.CloseEvent) end
    if s.back and not window then pcall(C_Calendar.SetAbsMonth, s.back.m, s.back.y) end
    Cal.Hold(false)
    ns.Fire("CALENDAR_CHANGED", "CALENDAR_UPDATE_EVENT_LIST")
end

-- Ends the session without a write and tells the page why (ns.Listen("CALEDIT_ENDED")); a waiting
-- CE.Begin gets its fn(false, why).
local function abort(s, why)
    if session ~= s then return end
    local fn = (s.stage ~= "open" and s.stage ~= "ready") and s.fn or nil
    release(s)
    if fn then fn(false, why) end
    ns.Fire("CALEDIT_ENDED", why)
end

function CE.Session() return session end
function CE.Busy() return session ~= nil end
function CE.Refused() return refused end

-- Ends the session without a change (the form's "Abbrechen", another day, another page, the question's
-- "Abbrechen").
-- A write still running is not stopped (the game has it); its answer then always ends the session.
-- An event the client is still opening is closed once it came open (its answer would open it with
-- nobody left to close it).
function CE.Cancel()
    local s = session
    if not s then return end
    if s.job or s.stage == "opening" then
        s.cancelled = true
        return
    end
    release(s)
end

-- Why no edit or delete can start now (nil: it can).
function CE.Blocker()
    if not CE.Available("edit") and not CE.Available("remove") then return "nofunc" end
    if refused then return "refused" end
    if InCombatLockdown() then return "combat" end
    if Cal.WindowShown() then return "window" end
    if api("IsActionPending") and plain(call("IsActionPending")) == true then return "pending" end
    if session or Cal.Busy() or (ns.CalWrite and ns.CalWrite.Busy()) or (CC() and CC().Busy()) then return "busy" end
    return nil
end

-- The values of the event the client has open now, for the form: { title, desc, time (minutes),
-- type, tex (EventSetTextureID's index or nil), kind (calendarType), at }; nil when one cannot be read.
local function readOpen()
    local info = call("GetEventInfo")
    if type(info) ~= "table" then return nil end
    local title, at = plain(info.title), Cal.Epoch(info.time)
    local typ = plain(info.eventType)
    if type(title) ~= "string" or not at or type(typ) ~= "number" then return nil end
    local t = date("*t", at)
    local desc, tex = plain(info.description), plain(info.textureIndex)
    return { title = title, desc = type(desc) == "string" and desc or "", time = t.hour * 60 + t.min, type = typ,
             tex = type(tex) == "number" and tex >= 1 and tex or nil, kind = plain(info.calendarType), at = at }
end

-- Whether the event the client has open is still the session's: open, editable, on the same day, on
-- the day Amisia opened it at (C_Calendar.GetEventIndex where the client answers it). Another event
-- coming open or this one closing ends the session before (CALENDAR_OPEN_EVENT, CALENDAR_CLOSE_EVENT).
local function stillOpen(s)
    if api("IsEventOpen") and plain(call("IsEventOpen")) == false then return false end
    if plain(call("EventCanEdit")) ~= true then return false end
    local info = call("GetEventInfo")
    local at = type(info) == "table" and Cal.Epoch(info.time)
    if not at or date("%Y-%m-%d", at) ~= date("%Y-%m-%d", s.item.at) then return false end
    local idx = api("GetEventIndex") and call("GetEventIndex")
    if type(idx) == "table" then
        -- not its index: another event made on that day meanwhile moves it
        local off, day = plain(idx.offsetMonths), plain(idx.monthDay)
        if type(day) == "number" and day ~= s.day then return false end
        if type(off) == "number" and off ~= s.offset then return false end
    end
    return true
end

-- Ends a write: ok, or why with the client's detail. A refusal of the game itself turns Amisia's
-- edit and delete off until /reload. An edit the game answered with an error keeps the form's event
-- open for another try; everything else ends the session.
local function finishJob(s, ok, why, detail)
    local j = s.job
    if not j or j.done then return end
    j.done = true
    s.job = nil
    if why == "blocked" then
        local text = tostring(detail)
        if detail == true or text:find("Calendar") or text:find("UpdateEvent") or text:find("EventRemove") then refused = detail end
    end
    local keep = not ok and why == "error" and s.what == "edit" and session == s and not s.cancelled and stillOpen(s)
    if not keep then release(s) end
    j.fn(ok, why, detail)
end

-- Whether the wanted change shows. A delete: the event gone from its day, looked up only while the
-- month the place was counted from is still the set one (the client's calendar window sets its own).
-- An edit: the client done with the action it took (seen pending, or its own event updated), so a
-- calendar event of someone else is no answer.
local function answered(s)
    if s.what == "remove" then
        if setMonth() ~= s.monthSet then return false end
        return locate(s.item, s.offset) == nil
    end
    local j = s.job
    if api("IsActionPending") and plain(call("IsActionPending")) == true then
        if j then j.sawPending = true end
        return false
    end
    return j ~= nil and (j.sawPending or j.gotUpdate) or false
end

onEvent = function(event, ...)
    local s = session
    if not s then return end
    local j = s.job
    if BLOCK[event] then
        local who, what = ...
        if j and ns.OwnAddon(plain(who)) then j.blocked = j.blocked or tostring(plain(what) or "?") end
    elseif ERRORS[event] then
        if j then
            j.error = j.error or errorText(...) or event
            if j.called then finishJob(s, false, "error", j.error) end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if not j then abort(s, "combat") end
    elseif event == "CALENDAR_OPEN_EVENT" then
        if s.stage == "opening" then
            if s.onOpen then s.onOpen() end
        elseif s.stage == "open" and not j then
            -- another event came open (the client's window, another addon): it is not Amisia's to close
            s.opened = false
            abort(s, "closed")
        end
    elseif event == "CALENDAR_CLOSE_EVENT" then
        if s.stage == "open" and not j then
            s.opened = false
            abort(s, "closed")
        end
    elseif ANSWER[event] then
        if s.stage == "month" and event == "CALENDAR_UPDATE_EVENT_LIST" then
            if s.onMonth then s.onMonth() end
        elseif j and j.called and event == "CALENDAR_ACTION_PENDING" and plain((...)) == true then
            j.sawPending = true
        elseif j and j.called and not j.settling then
            if event == "CALENDAR_UPDATE_EVENT" then j.gotUpdate = true end
            -- on the next frames: the client fills its lists after the event, and its error still counts
            j.settling = true
            C_Timer.After(CE.SETTLE, function()
                j.settling = nil
                if j.done or session ~= s then return end
                if j.blocked then return finishJob(s, false, "blocked", j.blocked) end
                if answered(s) then finishJob(s, true) end
            end)
        end
    end
end

-- The client's calendar window opening ends a session that waits for the player (the window shows its
-- own month and every opened event): looked at while one runs.
local function watchWindow(s)
    C_Timer.After(CE.WATCH_EVERY, function()
        if session ~= s then return end
        if not s.job and Cal.WindowShown() then return abort(s, "window") end
        watchWindow(s)
    end)
end

---------------------------------------------------------------------------
-- Begin: find the event, ask the game, open it for an edit
---------------------------------------------------------------------------
-- Starts an edit ("edit") or a delete ("remove") of item. Returns false and why when nothing started;
-- else true, and fn(ok, why, info) follows: for an edit once the client has the event open (info: its
-- values, readOpen), for a delete once the event is found and the game allows it (then the page asks
-- the player). A session that started stays until CE.Save / CE.Remove answered or CE.Cancel.
function CE.Begin(item, what, fn)
    if what ~= "edit" and what ~= "remove" then return false, "failed" end
    if not CE.IsEvent(item) then return false, "gone" end
    if not CE.Available(what) then return false, "nofunc" end
    local b = CE.Blocker()
    if b then return false, b end
    if what == "edit" and item.at <= time() + (CC() and CC().Skew() or 0) then return false, "past" end
    local off = offsetOf(item)
    if not off then return false, "month" end
    local s = { item = item, what = what, fn = fn, stage = "find" }
    session = s
    Cal.Hold(true)
    listen(true)
    watchWindow(s)

    local function found(offset)
        if session ~= s then return end
        local index, _, day = locate(item, offset)
        if not index then return abort(s, "gone") end
        s.offset, s.day, s.index, s.monthSet = offset, day, index, (setMonth())
        local can = plain(call(what == "edit" and "ContextMenuEventCanEdit" or "ContextMenuEventCanRemove", offset, day, index))
        if can ~= true then return abort(s, "right") end
        if what == "remove" then
            s.stage = "ready"
            return fn(true)
        end
        s.stage = "opening"
        local finished = false
        local function opened(event)
            if finished or session ~= s then return end
            finished = true
            s.onOpen = nil
            -- cancelled while the client was opening it: closed now, nobody told
            if s.cancelled then return release(s) end
            if not event then return abort(s, "open") end
            -- on the next frame: the client fills the event after its handlers
            C_Timer.After(0, function()
                if session ~= s then return end
                if s.cancelled then return release(s) end
                local info = readOpen()
                if not info then return abort(s, "read") end
                if info.at ~= item.at or (item.title and Cal.Clean(info.title) ~= item.title) then
                    -- another event came open instead: not Amisia's to close
                    s.opened = false
                    return abort(s, "closed")
                end
                if plain(call("EventCanEdit")) ~= true then return abort(s, "right") end
                s.info = info
                s.stage = "open"
                fn(true, nil, info)
            end)
        end
        s.onOpen = function() opened(true) end
        C_Timer.After(CE.WAIT, function() opened(nil) end)
        s.opened = true
        local ok, res = pcall(C_Calendar.OpenEvent, offset, day, index)
        if not ok or res == false then
            finished = true
            return abort(s, "open")
        end
    end

    if off >= -1 and off <= 1 then
        found(off)
        return true
    end
    -- a month the client has not loaded: set it, read it after the client's answer, set back at the end
    local _, cy, cm = setMonth()
    local t = date("*t", item.at)
    s.back = { m = cm, y = cy }
    s.stage = "month"
    local finished = false
    local function loaded()
        if finished or session ~= s then return end
        finished = true
        s.onMonth = nil
        C_Timer.After(0, function()
            if session ~= s then return end
            local now = setMonth()
            if now ~= t.year * 12 + (t.month - 1) then return abort(s, "window") end
            found(0)
        end)
    end
    -- a list event of something else may come before the month's: only one that shows the event counts
    -- before the wait is over
    s.onMonth = function()
        if setMonth() == t.year * 12 + (t.month - 1) and locate(item, 0) then loaded() end
    end
    C_Timer.After(Cal.MONTH_WAIT, loaded)
    if not pcall(C_Calendar.SetAbsMonth, t.month, t.year) then
        finished = true
        abort(s, "month")
    end
    return true
end

---------------------------------------------------------------------------
-- Save and Remove: the writes, each inside the player's click
---------------------------------------------------------------------------
-- Why a write cannot run now (nil: it can), for a session in stage.
local function writeBlocker(s, stage)
    if not s or s.stage ~= stage then return "closed" end
    if s.job then return "pending" end
    if refused then return "refused" end
    if InCombatLockdown() then return "combat" end
    if Cal.WindowShown() then return "window" end
    if api("IsActionPending") and plain(call("IsActionPending")) == true then return "pending" end
    return nil
end

-- What of form { type, tex, time (minutes), title, desc } differs from the open event's values:
-- { title, desc, time, type, tex } (the cleaned new values), or nil when nothing does. form.cleanTitle
-- and form.cleanDesc are filled.
function CE.Changes(form)
    local s = session
    local info = s and s.info
    if not info then return nil end
    local C = CC()
    form.cleanTitle = C.Clean(form.title, C.TITLE_CHARS)
    form.cleanDesc = C.Clean(form.desc, C.DESC_CHARS) or ""
    local out, any = {}, false
    -- the boxes show the cleaned values: only a real change counts
    if form.cleanTitle and form.cleanTitle ~= info.title and form.cleanTitle ~= C.Clean(info.title, C.TITLE_CHARS) then
        out.title, any = form.cleanTitle, true
    end
    if form.cleanDesc ~= info.desc and form.cleanDesc ~= (C.Clean(info.desc, C.DESC_CHARS) or "") then out.desc, any = form.cleanDesc, true end
    if form.time ~= info.time then out.time, any = form.time, true end
    if form.type ~= info.type then out.type, any = form.type, true end
    local withTex = form.type == 0 or form.type == 1
    if withTex and form.tex ~= nil and (out.type ~= nil or form.tex ~= info.tex) then out.tex, any = form.tex, true end
    return any and out or nil
end

-- Checks the form of an edit: nil when it may be saved, else why.
function CE.Check(form)
    local s = session
    local b = writeBlocker(s, "open")
    if b then return b end
    if s.what ~= "edit" then return "closed" end
    if not ns.Int(form.type, 0, 4) then return "type" end
    -- an instance is needed for a new type; an event whose instance the game does not name keeps it
    if (form.type == 0 or form.type == 1) and not ns.Int(form.tex, 1) and (form.type ~= s.info.type or form.tex ~= nil) then return "instance" end
    if not ns.Int(form.time, 0, 23 * 60 + 59) then return "time" end
    local d = date("*t", s.item.at)
    local at = time({ year = d.year, month = d.month, day = d.day, hour = math.floor(form.time / 60), min = form.time % 60 })
    if at <= time() + CC().Skew() then return "passed" end
    form.at = at
    local changes = CE.Changes(form)
    if not form.cleanTitle then return "title" end
    if not changes then return "same" end
    form.changes = changes
    return nil
end

-- The player's click on "Speichern": the changed fields and UpdateEvent, all inside this click.
-- Returns false and why when nothing was called (fn is not called then); else true, and fn(ok, why,
-- detail) follows with the client's answer or after CE.WAIT.
function CE.Save(form, fn)
    local why = CE.Check(form)
    if why then return false, why end
    local s = session
    if not stillOpen(s) then
        s.opened = false
        abort(s, "closed")
        return false, "closed"
    end
    local c = form.changes
    local list = {}
    if c.title then list[#list + 1] = { "EventSetTitle", c.title } end
    if c.desc then list[#list + 1] = { "EventSetDescription", c.desc } end
    if c.time then list[#list + 1] = { "EventSetTime", math.floor(c.time / 60), c.time % 60 } end
    if c.type then list[#list + 1] = { "EventSetType", c.type } end
    if c.tex then list[#list + 1] = { "EventSetTextureID", c.tex } end
    local j = { fn = fn, at = GetTime() }
    s.job = j
    for _, x in ipairs(list) do
        local ok, err = pcall(C_Calendar[x[1]], unpack(x, 2))
        if not ok then
            j.called = true
            finishJob(s, false, "failed", tostring(err))
            return true
        end
    end
    if j.blocked or j.error then
        j.called = true
        finishJob(s, false, j.blocked and "blocked" or "error", j.blocked or j.error)
        return true
    end
    -- the client's own button is on only while the event's settings differ
    if api("EventHaveSettingsChanged") and plain(call("EventHaveSettingsChanged")) == false then
        j.called = true
        finishJob(s, false, "same")
        return true
    end
    j.called = true
    local ok, err = pcall(C_Calendar.UpdateEvent)
    if not ok then
        finishJob(s, false, "failed", tostring(err))
        return true
    end
    if j.blocked then finishJob(s, false, "blocked", j.blocked) return true end
    if j.error then finishJob(s, false, "error", j.error) return true end
    if api("IsActionPending") and plain(call("IsActionPending")) == true then j.sawPending = true end
    C_Timer.After(CE.WAIT, function()
        if j.done then return end
        if j.blocked then return finishJob(s, false, "blocked", j.blocked) end
        finishJob(s, false, "timeout")
    end)
    return true
end

-- The player's click on the question's "Löschen": the event at the place found is the session's still
-- (its eventID), the game still allows it, then the client's two calls inside this click. Returns
-- false and why when nothing was called; else true, and fn(ok, why, detail) follows.
function CE.Remove(fn)
    local s = session
    local why = writeBlocker(s, "ready")
    if why then
        if s and s.stage == "ready" and not s.job then abort(s, why) end
        return false, why
    end
    if s.what ~= "remove" then return false, "closed" end
    local index = locate(s.item, s.offset)
    if index ~= s.index then
        abort(s, "gone")
        return false, "gone"
    end
    if plain(call("ContextMenuEventCanRemove", s.offset, s.day, s.index)) ~= true then
        abort(s, "right")
        return false, "right"
    end
    local j = { fn = fn, at = GetTime() }
    s.job = j
    for _, x in ipairs({ { "ContextMenuSelectEvent", s.offset, s.day, s.index }, { "ContextMenuEventRemove" } }) do
        if x[1] == "ContextMenuEventRemove" then j.called = true end
        local ok, err = pcall(C_Calendar[x[1]], unpack(x, 2))
        if not ok then
            j.called = true
            finishJob(s, false, "failed", tostring(err))
            return true
        end
        if j.blocked then finishJob(s, false, "blocked", j.blocked) return true end
        if j.error then finishJob(s, false, "error", j.error) return true end
    end
    C_Timer.After(CE.WAIT, function()
        if j.done then return end
        if j.blocked then return finishJob(s, false, "blocked", j.blocked) end
        -- the list's event may have got lost: the event gone is the answer
        if session == s and answered(s) then return finishJob(s, true) end
        finishJob(s, false, "timeout")
    end)
    return true
end

-- "Fr 21.11. 19:30 Molten Core" of an event (the chat lines and the question).
function CE.Label(at, title)
    return ("%s %s %s"):format(ns.RaidCalView and ns.RaidCalView.DayText(at) or date("%d.%m.", at), date("%H:%M", at), title or "")
end

-- for the tests
CE._reset = function()
    if session then
        local s = session
        s.job = nil
        release(s)
    end
    refused = nil
end
end)
