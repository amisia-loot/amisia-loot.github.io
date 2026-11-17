-- Amisia calendar entry (F-217, D-142, spec docs/specs/2026-11-15-kalender-termin-anlegen.md): the
-- player's own click on "Anlegen" on the calendar page makes a guild event (with sign-up) or, with the
-- game's right (CanEditGuildEvent), a guild announcement in the game calendar. The game hands it to
-- the whole guild; Amisia reads it back like any other event. The calls are the client's own (its
-- create frame, Blizzard_Calendar.lua: CalendarDayContextMenu_CreateGuildEvent, CalendarCreateEventFrame_Update,
-- CalendarCreateEvent_SetSelectedIndex, CalendarCreateEventCreateButton_OnClick):
--   CreateGuildSignUpEvent / CreateGuildAnnouncementEvent, EventSetDate, EventSetTitle,
--   EventSetDescription, EventSetTime, EventSetType, EventSetTextureID (after the type), AddEvent
-- all inside the click: AddEvent needs a hardware event. Never in combat, never while the client's
-- calendar window is shown or an own read holds an event open (the new event replaces the open one),
-- never while an answer is pending, never from a timer or a message, never retried. No invites
-- (D-142); edit and delete are Raid/CalendarEdit.lua (F-222, D-147). The answer: CALENDAR_NEW_EVENT (made), CALENDAR_UPDATE_ERROR* (its
-- text), ADDON_ACTION_BLOCKED/FORBIDDEN for Amisia (the game refuses: the button stays off until
-- /reload), else none within CC.WAIT seconds.
local ADDON, ns = ...
ns.Load(function()
local L, N_ = ns.L, ns.N_

local CC = {}
ns.CalCreate = CC

CC.WAIT = 10            -- seconds for the client's answer
CC.TITLE_CHARS = 31     -- the client's title box (letters="31")
CC.DESC_CHARS = 255     -- the client's description box (maxLetters 255)
CC.KINDS = { "signup", "announce" }
CC.TYPES = { 0, 1, 2, 3, 4 }   -- Enum.CalendarEventType without HeroicDeprecated
CC.STEP = 15            -- the time arrows step this many minutes
CC.DEFAULT_TIME = 20 * 60

local plain = ns.Plain
local api, call = ns.Cal.api, ns.Cal.call

CC.FUNCS = { "CreateGuildSignUpEvent", "EventSetDate", "EventSetTitle", "EventSetDescription", "EventSetTime",
             "EventSetType", "EventSetTextureID", "EventGetTextures", "AddEvent", "CloseEvent" }

-- Whether the client has every function of the entry.
function CC.Available()
    for _, n in ipairs(CC.FUNCS) do
        if not api(n) then return false end
    end
    return true
end

-- Whether the player may make a guild announcement (the client's own test).
function CC.CanAnnounce()
    if not api("CreateGuildAnnouncementEvent") or type(CanEditGuildEvent) ~= "function" then return false end
    local ok, can = pcall(CanEditGuildEvent)
    return ok and plain(can) == true
end

-- A text cut to max characters (UTF-8), codes, bars and control characters away.
function CC.Clean(text, max)
    if type(text) ~= "string" then return nil end
    text = ns.StripCodes(text):gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    local out, n = {}, 0
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > max then break end
        out[n] = ch
    end
    text = table.concat(out):match("^(.-)%s*$")
    return text ~= "" and text or nil
end

-- The instances of a type (0 raid, 1 dungeon) the client offers: { { index (EventSetTextureID),
-- title } } in the client's order, one per name (the first difficulty, as the client's picker
-- starts with); {} for the other types or without the function.
local texCache = {}
function CC.Textures(typ)
    if typ ~= 0 and typ ~= 1 then return {} end
    if texCache[typ] then return texCache[typ] end
    local list = call("EventGetTextures", typ)
    local out, seen = {}, {}
    for i, t in ipairs(type(list) == "table" and list or {}) do
        local title = type(t) == "table" and ns.Cal.Clean(t.title, 60)
        if title and not seen[title] then
            seen[title] = true
            out[#out + 1] = { index = i, title = title }
        end
    end
    -- an empty answer (the calendar not loaded yet) is asked again next time
    if #out > 0 then texCache[typ] = out end
    return out
end

-- The instance at index of a type's list (EventGetTextures, what GetEventInfo's textureIndex counts in):
-- its title and the index CC.Textures lists that title under (the picker's value); nil when unknown.
function CC.TextureAt(typ, index)
    if (typ ~= 0 and typ ~= 1) or type(index) ~= "number" then return nil end
    local list = call("EventGetTextures", typ)
    local t = type(list) == "table" and list[index]
    local title = type(t) == "table" and ns.Cal.Clean(t.title, 60)
    if not title then return nil end
    for _, x in ipairs(CC.Textures(typ)) do
        if x.title == title then return title, x.index end
    end
    return title, index
end

-- The calendar day today (the client's calendar time, else the own clock) as noon of that day, and
-- the last day an event may be made on (C_Calendar.GetMaxCreateDate) as noon; nil when not known.
local function noonOf(t)
    if type(t) ~= "table" then return nil end
    local y, m, d = plain(t.year), plain(t.month), plain(t.monthDay)
    if type(y) ~= "number" or type(m) ~= "number" or type(d) ~= "number" then return nil end
    return time({ year = y, month = m, day = d, hour = 12 })
end
function CC.Today()
    local C = _G.C_DateAndTime
    local f = type(C) == "table" and C.GetCurrentCalendarTime
    local at = type(f) == "function" and select(2, pcall(f))
    local d = date("*t")
    return noonOf(type(at) == "table" and at) or time({ year = d.year, month = d.month, day = d.day, hour = 12 })
end
-- The realm's calendar clock minus the PC's (seconds, in quarter hours): the calendar's times are the
-- realm's, read with the PC's time(); 0 when the client does not say.
function CC.Skew()
    local C = _G.C_DateAndTime
    local f = type(C) == "table" and C.GetCurrentCalendarTime
    if type(f) ~= "function" then return 0 end
    local ok, t = pcall(f)
    local at = ok and ns.Cal.Epoch(type(t) == "table" and t or nil)
    if not at then return 0 end
    return math.floor((at - time()) / 900 + 0.5) * 900
end

function CC.MaxDay()
    return noonOf(call("GetMaxCreateDate"))
end

---------------------------------------------------------------------------
-- The form
---------------------------------------------------------------------------
-- The last form used (AmisiaDB.calForm: kind, type, tex (an instance's title), h, m), else the defaults.
function CC.Form()
    local f = AmisiaDB and AmisiaDB.calForm or {}
    return { kind = f.kind or "signup", type = f.type or 0, tex = f.tex,
             time = (f.h and f.m) and f.h * 60 + f.m or CC.DEFAULT_TIME }
end

local function remember(form)
    if not AmisiaDB then return end
    AmisiaDB.calForm = { v = 1, kind = form.kind, type = form.type, tex = form.texTitle,
                         h = math.floor(form.time / 60), m = form.time % 60 }
end

-- Checks AmisiaDB.calForm on load: a bad field drops it.
function CC.Loaded(DB)
    local f = DB.calForm
    if f == nil then return end
    local ok = type(f) == "table" and (f.kind == "signup" or f.kind == "announce") and ns.Int(f.type, 0, 4)
        and ns.Int(f.h, 0, 23) and ns.Int(f.m, 0, 59)
        and (f.tex == nil or (type(f.tex) == "string" and f.tex ~= "" and #f.tex <= 120 and not f.tex:find("[%c|]")))
    if not ok then
        DB.calForm = nil
        return
    end
    DB.calForm = { v = 1, kind = f.kind, type = f.type, tex = f.tex, h = f.h, m = f.m }
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ns.ADDON and AmisiaDB then CC.Loaded(AmisiaDB) end
end)

---------------------------------------------------------------------------
-- Watching the client while an entry runs
---------------------------------------------------------------------------
local BLOCK = { ADDON_ACTION_BLOCKED = true, ADDON_ACTION_FORBIDDEN = true }
local ERRORS = { CALENDAR_UPDATE_ERROR = true, CALENDAR_UPDATE_ERROR_WITH_COUNT = true, CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME = true }
CC.WATCH = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "CALENDAR_NEW_EVENT", "CALENDAR_UPDATE_ERROR",
             "CALENDAR_UPDATE_ERROR_WITH_COUNT", "CALENDAR_UPDATE_ERROR_WITH_PLAYER_NAME" }

local watcher, job
local refused           -- the game refused AddEvent for Amisia: no more tries until /reload

local finish

-- The text of a client error (a global string's name, as the client's popup shows it).
local function errorText(name, extra)
    name = plain(name)
    local text = type(name) == "string" and _G[name]
    if type(text) == "string" and text ~= "" then
        if extra ~= nil and text:find("%%") then
            local ok, s = pcall(string.format, text, plain(extra))
            if ok then text = s end
        end
        return ns.Cal.Clean(text, 200)
    end
    return type(name) == "string" and ns.Cal.Clean(name, 200) or nil
end

local function onEvent(_, event, ...)
    local j = job
    if not j then return end
    if BLOCK[event] then
        local who, what = ...
        if ns.OwnAddon(plain(who)) then j.blocked = j.blocked or tostring(plain(what) or "?") end
    elseif ERRORS[event] then
        j.error = j.error or errorText(...) or event
        if j.called then finish(j, false, "error") end
    elseif event == "CALENDAR_NEW_EVENT" then
        local isCopy = ...
        if plain(isCopy) ~= true and j.called then finish(j, true) end
    end
end

local function listen(on)
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", onEvent)
    end
    for _, e in ipairs(CC.WATCH) do
        if on then pcall(watcher.RegisterEvent, watcher, e) else pcall(watcher.UnregisterEvent, watcher, e) end
    end
end

finish = function(j, ok, why)
    if j.done then return end
    j.done = true
    if job == j then
        job = nil
        listen(false)
    end
    -- the game refused the entry itself (not another Amisia call blocked meanwhile): no more tries
    if why == "blocked" and (j.blocked == true or tostring(j.blocked):find("Calendar") or tostring(j.blocked):find("AddEvent")) then
        refused = j.blocked
    end
    -- the draft is the client's open event: closed again (the client's create frame closes on its
    -- answer too), unless the client's calendar window shows it now
    if not ns.Cal.WindowShown() then pcall(C_Calendar.CloseEvent) end
    ns.Cal.Hold(false)
    ns.Fire("CALENDAR_CHANGED", "CALENDAR_UPDATE_EVENT_LIST")
    j.fn(ok, why, j.error or j.blocked)
end

function CC.Busy() return job ~= nil end
function CC.Refused() return refused end

---------------------------------------------------------------------------
-- Why not, and the entry of a click
---------------------------------------------------------------------------
local WHY = {
    guild = N_("Nur in einer Gilde."),
    nofunc = N_("Der Spielkalender bietet die nötigen Funktionen nicht."),
    combat = N_("Nicht im Kampf."),
    window = N_("Erst den Spielkalender schließen."),
    busy = N_("Der Kalender ist gerade beschäftigt. Gleich noch einmal."),
    pending = N_("Der Kalender wartet noch auf eine Antwort."),
    refused = N_("Das Spiel lässt Amisia keine Termine anlegen. Lege ihn bitte im Spielkalender an."),
    blocked = N_("Das Spiel hat das Anlegen blockiert. Lege den Termin bitte im Spielkalender an."),
    announce = N_("Gildenankündigungen darf nur anlegen, wem es der Gildenrang erlaubt."),
    past = N_("Der Tag liegt in der Vergangenheit."),
    late = N_("So weit voraus nimmt der Spielkalender keinen Termin."),
    passed = N_("Die Uhrzeit ist heute schon vorbei."),
    time = N_("Die Uhrzeit fehlt oder ist falsch (z. B. 20:30)."),
    title = N_("Der Titel fehlt."),
    instance = N_("Bitte eine Instanz wählen."),
    type = N_("Unbekannter Typ."),
    invalid = N_("Der Spielkalender nimmt den Termin so nicht an."),
    error = N_("Der Kalender meldet einen Fehler."),
    timeout = N_("Der Kalender hat nicht geantwortet. Schau im Spielkalender nach, ob der Termin steht."),
    failed = N_("Der Aufruf im Kalender ging schief."),
}
function CC.Why(why) return L[WHY[why] or WHY.failed] end

-- Why the button "Anlegen" cannot work now (nil: it can), without the form's own fields.
function CC.Blocker()
    if not IsInGuild() then return "guild" end
    if not CC.Available() then return "nofunc" end
    if refused then return "refused" end
    if InCombatLockdown() then return "combat" end
    if ns.Cal.WindowShown() then return "window" end
    if job then return "pending" end
    if api("IsActionPending") and plain(call("IsActionPending")) == true then return "pending" end
    if ns.Cal.Busy() or (ns.CalWrite and ns.CalWrite.Busy()) then return "busy" end
    return nil
end

-- Checks a form { kind, type, tex (index), texTitle, day (noon epoch), time (minutes), title, desc }:
-- nil when it may be made, else why; the cleaned title and description fill form.cleanTitle/cleanDesc.
function CC.Check(form)
    local b = CC.Blocker()
    if b then return b end
    if form.kind ~= "signup" and form.kind ~= "announce" then return "type" end
    if form.kind == "announce" and not CC.CanAnnounce() then return "announce" end
    if not ns.Int(form.type, 0, 4) then return "type" end
    if (form.type == 0 or form.type == 1) and not ns.Int(form.tex, 1) then return "instance" end
    if not ns.Int(form.time, 0, 23 * 60 + 59) then return "time" end
    if type(form.day) ~= "number" then return "past" end
    local today = CC.Today()
    if form.day < today - 3600 then return "past" end
    local max = CC.MaxDay()
    if max and form.day > max + 3600 then return "late" end
    local d = date("*t", form.day)
    local at = time({ year = d.year, month = d.month, day = d.day, hour = math.floor(form.time / 60), min = form.time % 60 })
    -- both clocks the realm's: the calendar's time and now
    if at <= time() + CC.Skew() then return "passed" end
    form.at = at
    form.cleanTitle = CC.Clean(form.title, CC.TITLE_CHARS)
    if not form.cleanTitle then return "title" end
    form.cleanDesc = CC.Clean(form.desc, CC.DESC_CHARS) or ""
    return nil
end

-- The client's calls of an entry, in its order (the type before its texture).
local function calls(form)
    local d = date("*t", form.day)
    local list = {
        { form.kind == "announce" and "CreateGuildAnnouncementEvent" or "CreateGuildSignUpEvent" },
        { "EventSetDate", d.month, d.day, d.year },
        { "EventSetTitle", form.cleanTitle },
        { "EventSetDescription", form.cleanDesc },
        { "EventSetTime", math.floor(form.time / 60), form.time % 60 },
        { "EventSetType", form.type },
    }
    if form.type == 0 or form.type == 1 then list[#list + 1] = { "EventSetTextureID", form.tex } end
    return list
end

-- The player's click on "Anlegen": makes form in the game calendar. fn(ok, why, detail) when the client
-- answered (ok true: CALENDAR_NEW_EVENT) or CC.WAIT passed. Returns false and why when nothing was
-- called (fn is not called then), true when it runs.
function CC.Create(form, fn)
    local why = CC.Check(form)
    if why then return false, why end
    local list = calls(form)
    local j = { fn = fn, at = GetTime(), form = form }
    job = j
    -- no own read may open another event while the draft is open
    ns.Cal.Hold(true)
    listen(true)
    for _, c in ipairs(list) do
        local ok, err = pcall(C_Calendar[c[1]], unpack(c, 2))
        if not ok then
            j.error = tostring(err)
            j.called = true
            finish(j, false, "failed")
            return true
        end
    end
    if j.blocked or j.error then
        j.called = true
        finish(j, false, j.blocked and "blocked" or "error")
        return true
    end
    -- the client's own create button is on only while CanAddEvent says so
    if api("CanAddEvent") and plain(call("CanAddEvent")) == false then
        j.called = true
        finish(j, false, "invalid")
        return true
    end
    pcall(remember, form)
    j.called = true
    local ok, err = pcall(C_Calendar.AddEvent)
    if not ok then
        j.error = tostring(err)
        finish(j, false, "failed")
        return true
    end
    if j.blocked then
        finish(j, false, "blocked")
        return true
    end
    if j.error then
        finish(j, false, "error")
        return true
    end
    C_Timer.After(CC.WAIT, function()
        if j.done then return end
        if j.blocked then return finish(j, false, "blocked") end
        finish(j, false, "timeout")
    end)
    return true
end

---------------------------------------------------------------------------
-- The text for Discord (part C): title, Discord timestamps (every reader sees his own time zone),
-- type and kind, the description; Markdown and "@" escaped (ns.DiscordEscape)
---------------------------------------------------------------------------
local KIND_WORD = { GUILD_EVENT = N_("Gildenereignis"), GUILD_ANNOUNCEMENT = N_("Gildenankündigung"), PLAYER = N_("Eigener Termin") }
CC.KIND_WORD = KIND_WORD

function CC.DiscordText(item, desc)
    if type(item) ~= "table" or type(item.at) ~= "number" then return "" end
    local esc = ns.DiscordEscape or function(x) return x end
    -- Discord wants the real moment: the realm's calendar time back to the PC's clock
    local at = ("%.0f"):format(item.at - CC.Skew())
    local lines = { ("**%s**"):format(esc(item.title or "?")), ("<t:%s:F> (<t:%s:R>)"):format(at, at) }
    local parts = {}
    local typ = item.type and ns.Cal.TYPE_WORD[item.type]
    if typ then parts[#parts + 1] = L[typ] end
    if item.kind and KIND_WORD[item.kind] then parts[#parts + 1] = L[KIND_WORD[item.kind]] end
    if #parts > 0 then lines[#lines + 1] = table.concat(parts, " · ") end
    desc = CC.Clean(desc, CC.DESC_CHARS)
    if desc then lines[#lines + 1] = esc(desc) end
    if item.kind ~= "GUILD_ANNOUNCEMENT" and item.kind ~= "PLAYER" then
        lines[#lines + 1] = L["Anmelden: im Spielkalender oder in Amisia"]
    end
    return table.concat(lines, "\n")
end

-- for the tests
CC._reset = function()
    job, refused = nil, nil
    texCache = {}
    if watcher then listen(false) end
end
end)
