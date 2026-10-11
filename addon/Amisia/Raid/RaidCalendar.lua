-- Amisia raid calendar (part I of the spec docs/specs/2026-10-10-raid-aufstellung.md, D-43): who
-- comes to a coming date, for everyone in the guild (user decision 2026-10-11: the game calendar
-- shows the participants anyway, and the notes go to the whole guild already). The participants of a
-- date come from two sources:
--   K  the invite list of the date's guild event in the game calendar (ns.Cal.Read: never while the
--      client's calendar window shows another event, always CloseEvent, not in combat);
--   A  the sign-ups from Amisia: the AN messages this client received (ns.SignupSeen, kept by every
--      client since part I) and the characters of this account (ns.SignupState, no message needed).
-- One row per name; the valid status and the role follow the officer's lineup rules
-- (ns.LineupResolve: the newest statement of the player, Amisia within 2 minutes of the calendar
-- counts, a calendar status seen first is older than any click; the role from Amisia, the last
-- lineup, else the class, guessed "?"). Nothing here writes into the calendar; AQ stays the
-- officers' (no new message kind). UI/RaidCalendar.lua shows it.
local ADDON, ns = ...
local L, N_ = ns.L, ns.N_

local RC = {}
ns.RaidCal = RC

RC.RELOAD_GAP = 5     -- a date is read again at most this often while the window is open
RC.POLL = 30          -- and every this many seconds (the client does not tell every change)
RC.BUSY_RETRY = 2     -- the calendar is read by the lineup or the probe: again after this many seconds
RC.BUSY_SHOW = 8      -- busy this long without a break: the window says so instead of "wird gelesen"

-- The groups of the window, top to bottom, by the valid status (Lineup's codes).
RC.GROUPS = {
    { key = "in", label = N_("Angemeldet / Bestätigt"), codes = { A = true, B = true } },
    { key = "maybe", label = N_("Vorläufig"), codes = { V = true } },
    { key = "bench", label = N_("Ersatz"), codes = { E = true } },
    { key = "out", label = N_("Abgemeldet"), codes = { X = true } },
    { key = "none", label = N_("Ohne Antwort"), codes = { I = true, O = true, G = true } },
}
local ROLE_ORDER = { T = 1, H = 2, M = 3, R = 4 }

-- What the calendar said per event (memory only): [night "#" id] = { id, read = epoch of the last
-- read, why = reason of the last failed read, invites, seen = { [lower name] = { code, t } } }; and
-- per night the state of its event read last. A night can have two dates (a meeting before the raid):
-- the raid calendar window reads the night's first, the calendar page the chosen one, and each must
-- show its own event's list, not the one the other read last (2.27.0 review).
local state, latest = {}, {}

local function eventKey(night, ev)
    return tostring(night) .. "#" .. tostring(ev.id or ("@" .. tostring(ev.at)))
end

local function stateOf(ev)
    local k = eventKey(ev.night, ev)
    local s = state[k]
    if not s then
        s = { id = ev.id, seen = {} }
        state[k] = s
    end
    latest[ev.night] = s
    return s
end

-- The calendar state of the event ev of night (an entry of ns.Cal.Events()), else of the night's
-- event read last (nil: never read).
function RC.State(night, ev)
    if ev then return state[eventKey(night, ev)] end
    return latest[night]
end

-- Reads the invite list of ev (an entry of ns.Cal.Events()) and keeps it for its night. A status seen
-- first counts as older than any Amisia click (t 0); a changed one with the time Amisia saw the
-- change (as the lineup does; the client gives no response time, check 20). fn(ok, why) when given.
function RC.Read(ev, fn)
    ns.Cal.Read(ev, function(invites, why)
        local s = stateOf(ev)
        if invites then
            local now = math.floor(time())
            local seen = {}
            for _, inv in ipairs(invites) do
                local low = inv.name:lower()
                local code = inv.code or "O"
                local old = s.seen[low]
                if not old then
                    seen[low] = { code = code, t = 0 }
                elseif old.code ~= code then
                    seen[low] = { code = code, t = now }
                else
                    seen[low] = old
                end
            end
            s.seen, s.invites, s.read, s.why = seen, invites, now, nil
        else
            s.why = why
        end
        ns.Fire("RAIDCAL")
        if fn then fn(invites ~= nil, why) end
    end)
end

-- The participants of night: { { n, c (class token), lvl, f ("K", "A", "KA"), st (valid status), r,
-- q (role guessed), w (note), as (Amisia status) } }, by group order, role and name. With ev the
-- calendar's list of that event (none while it was not read), else of the night's event read last.
function RC.List(night, ev)
    local byLow, list = {}, {}
    local function get(name)
        local low = name:lower()
        local e = byLow[low]
        if not e then
            e = { n = name }
            byLow[low] = e
            list[#list + 1] = e
        end
        return e
    end
    local s = RC.State(night, ev)
    for _, inv in ipairs(s and s.invites or {}) do
        local e = get(inv.name)
        local seen = s.seen[inv.name:lower()]
        e.kc = true
        e.c = e.c or inv.class
        e.lvl = inv.level
        e.ks, e.kt = seen and seen.code or inv.code or "O", seen and seen.t or 0
    end
    local now = math.floor(time())
    -- an Amisia sign-up: the newest click by the sender's clock wins (one name, two sources)
    local function amisia(name, rec)
        local e = get(name)
        if e.au and rec.t <= e.au then return end
        e.a2 = true
        e.as, e.ag, e.au, e.ar = rec.s, math.min(rec.t, now), rec.t, rec.r
        e.w = rec.w
        e.c = e.c or rec.c
    end
    for name, rec in pairs(ns.SignupSeen and ns.SignupSeen(night) or {}) do amisia(name, rec) end
    local own = ns.SignupState and ns.SignupState()
    for name, map in pairs(own and own.chars or {}) do
        if map[night] then amisia(name, map[night]) end
    end
    -- the level and class of names the calendar did not name: from the guild roster
    local roster = {}
    for _, m in ipairs(ns.GuildRoster and ns.GuildRoster() or {}) do
        if type(m.name) == "string" then roster[m.name:lower()] = m end
    end
    for _, e in ipairs(list) do
        e.f = (e.kc and "K" or "") .. (e.a2 and "A" or "")
        local m = roster[e.n:lower()]
        if m then
            e.lvl = e.lvl or tonumber(m.level)
            e.c = e.c or (ns.LINEUP_CLASSES[m.class] and m.class or nil)
        end
        ns.LineupResolve(e, night)
    end
    local groupOf = {}
    for i, g in ipairs(RC.GROUPS) do
        for code in pairs(g.codes) do groupOf[code] = i end
    end
    for _, e in ipairs(list) do e.group = groupOf[e.st or "O"] or #RC.GROUPS end
    table.sort(list, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        local ra, rb = ROLE_ORDER[a.r or ""] or 9, ROLE_ORDER[b.r or ""] or 9
        if ra ~= rb then return ra < rb end
        return a.n < b.n
    end)
    return list
end

-- The rows of the window: a head per group with its count ({ head = label, count, key }), then its
-- names ({ e = entry, key }); empty groups are left out. And the roles of those signed up or
-- confirmed ({ T, H, M, R }, guessed roles count), the number of names and the count per group
-- ({ in, maybe, bench, out, none }).
function RC.Rows(night, ev)
    local list = RC.List(night, ev)
    local rows, roles, groups = {}, { T = 0, H = 0, M = 0, R = 0 }, {}
    for gi, g in ipairs(RC.GROUPS) do
        local members = {}
        for _, e in ipairs(list) do
            if e.group == gi then members[#members + 1] = e end
        end
        groups[g.key] = #members
        if #members > 0 then
            rows[#rows + 1] = { head = L[g.label], count = #members, key = g.key }
            for _, e in ipairs(members) do
                rows[#rows + 1] = { e = e, key = g.key }
                if g.key == "in" and e.r then roles[e.r] = roles[e.r] + 1 end
            end
        end
    end
    return rows, roles, #list, groups
end

-- for the tests
RC._reset = function() state, latest = {}, {} end
