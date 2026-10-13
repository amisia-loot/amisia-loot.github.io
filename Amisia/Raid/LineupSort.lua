-- Amisia lineup, part D (F-084, D-41): "Gruppen sortieren" moves every raider of the night's lineup
-- into the group of the planner with SetRaidSubgroup, or, when that group is full, swaps him with a
-- listed raider who belongs elsewhere (SwapRaidSubgroup). One step at a time, the next only when
-- the client reports the roster again (or after STEP_WAIT), at most MAX_STEPS per click. Raiders who
-- are not on the list stay where they are. Only in a raid, as leader or assistant, out of combat and
-- the lockdown; a fight stops it and the page offers "Sortieren fortsetzen". lineup.autoSort (on)
-- sorts QUIET seconds after a planned player joined, but only on the client that clicked "Alle
-- einladen" tonight (two officers do not sort against each other).
-- Automatic assistant (lineup.autoAssist, off; user 2026-10-12): as raid leader Amisia promotes
-- every raider whose guild rank is an officer rank by the roster (never what a message says) once
-- per raid, out of combat and the lockdown.
local ADDON, ns = ...
local L = ns.L

local MAX_STEPS = 60
local STEP_WAIT = 3        -- seconds a step waits for the roster before it looks again
local MAX_STALLS = 2       -- the same step this often without a change: the client does not sort
local QUIET = 2            -- auto sort: seconds without a join before it starts
local GROUP_SIZE = 5

local SO = {}
ns.LineupSortState = SO

local sort                 -- { night, steps, token, sig, stalls, quiet, moved }
local paused               -- the night whose sort a fight stopped ("Sortieren fortsetzen")

local function IV() return ns.LineupInv end

-- The raid as it is: { { i = raid index, name, sub = group, rank = 0/1/2 } }; secret names skipped.
local function rosterRows()
    local out = {}
    local n = tonumber(ns.Plain(GetNumGroupMembers())) or 0
    for i = 1, n do
        local name, rank, sub = GetRaidRosterInfo(i)
        name, rank, sub = ns.FullName(ns.Plain(name)), tonumber(ns.Plain(rank)), tonumber(ns.Plain(sub))
        if name and sub then out[#out + 1] = { i = i, name = name, sub = sub, rank = rank or 0 } end
    end
    return out
end
SO.Rows = rosterRows

-- The rows with their target group from the night's planner (nil: not on the list or not placed),
-- and the names in the raid that are not on the list.
function ns.LineupSortPlan(night)
    local n = ns.LineupNight(night or ns.LineupTonight(), false)
    local rows = rosterRows()
    local names = {}
    for _, r in ipairs(rows) do names[#names + 1] = r.name end
    local unlisted = {}
    for _, r in ipairs(rows) do
        local hit
        for _, e in ipairs(n and n.list or {}) do
            if ns.SameNameIn(e.n, r.name, names) then hit = e break end
        end
        if hit and hit.g and not hit.a and not hit.b and not hit.v then
            r.target = hit.g
        elseif not hit then
            unlisted[#unlisted + 1] = r.name
        end
    end
    return rows, unlisted
end

-- The next step: "set", row, group (a place is free) or "swap", row, other (the target is full; the
-- other is a listed raider who belongs elsewhere, best one who belongs where the row is now). nil
-- when nothing is left to do; the third value then counts the rows that cannot be moved (their
-- group is full of raiders who belong there or are not on the list).
function SO.Next(rows)
    local count = {}
    for g = 1, 8 do count[g] = 0 end
    for _, r in ipairs(rows) do count[r.sub] = (count[r.sub] or 0) + 1 end
    local stuck = 0
    for _, r in ipairs(rows) do
        if r.target and r.target ~= r.sub then
            if (count[r.target] or 0) < GROUP_SIZE then return "set", r, r.target end
            local best
            for _, x in ipairs(rows) do
                if x.sub == r.target and x.target and x.target ~= r.target then
                    if x.target == r.sub then best = x break end
                    best = best or x
                end
            end
            if best then return "swap", r, best end
            stuck = stuck + 1
        end
    end
    return nil, nil, stuck
end

-- How many listed raiders are not in their group yet.
function ns.LineupSortWrong(night)
    local rows = ns.LineupSortPlan(night)
    local c = 0
    for _, r in ipairs(rows) do
        if r.target and r.target ~= r.sub then c = c + 1 end
    end
    return c
end

function ns.LineupSortPaused(night) return paused ~= nil and paused == (night or ns.LineupTonight()) end
function ns.LineupSorting() return sort ~= nil and not sort.quiet end

local function changed() ns.Fire("LINEUP_INVITE") end

local stepNow

local function schedule(s)
    local token = (sort.token or 0) + 1
    sort.token = token
    C_Timer.After(s, function()
        if sort and sort.token == token then stepNow() end
    end)
end

local function done(text, keepPaused)
    local s = sort
    sort = nil
    if not keepPaused then paused = nil end
    if text and s and (not s.quiet or keepPaused or s.failed) then ns.msg(text) end
    changed()
end

stepNow = function()
    if not sort then return end
    local why, text = ns.LineupLeadBlocked(true)
    if why == "combat" or why == "lock" then
        paused = sort.night
        return done(L["Sortieren nach dem Kampf fortsetzen."], true)
    elseif why then
        sort.failed = true
        return done(L["Sortieren angehalten: %s."]:format(text))
    end
    local rows = ns.LineupSortPlan(sort.night)
    local act, a, b = SO.Next(rows)
    if not act then
        local stuck = b   -- with no step, the third value of SO.Next
        local line = L["Gruppen sortiert: %d Schritte."]:format(sort.steps)
        if stuck and stuck > 0 then line = line .. " " .. L["%d nicht verschoben (Zielgruppe voll)."]:format(stuck) end
        return done(line)
    end
    if sort.steps >= MAX_STEPS then
        sort.failed = true
        return done(L["Sortieren: %d Schritte erreicht, für den Rest bitte nochmal klicken."]:format(MAX_STEPS))
    end
    local sig = act .. ":" .. a.name .. ":" .. (act == "set" and tostring(b) or b.name)
    if sig == sort.sig then
        sort.stalls = sort.stalls + 1
        if sort.stalls >= MAX_STALLS then
            sort.failed = true
            return done(L["Sortieren angehalten: das Spiel hat %s nicht verschoben."]:format(a.name))
        end
    else
        sort.sig, sort.stalls = sig, 0
    end
    local ok
    if act == "set" then
        ok = type(SetRaidSubgroup) == "function" and pcall(SetRaidSubgroup, a.i, b)
    else
        ok = type(SwapRaidSubgroup) == "function" and pcall(SwapRaidSubgroup, a.i, b.i)
    end
    if not ok then
        sort.failed = true
        return done(L["Sortieren angehalten: das Spiel hat %s nicht verschoben."]:format(a.name))
    end
    sort.steps = sort.steps + 1
    sort.waiting = true
    schedule(STEP_WAIT)
end

-- "Gruppen sortieren" (and "Sortieren fortsetzen") for night (tonight). quiet: the automatic sort
-- (no chat line unless it fails). Returns true, or nil and the reason.
function ns.LineupSort(night, quiet)
    night = night or ns.LineupTonight()
    local _, text = ns.LineupLeadBlocked(true)
    if text then return nil, text end
    if sort then
        if not quiet then sort.quiet = false end
        return nil, L["Sortieren läuft schon"]
    end
    local act, _, stuck = SO.Next((ns.LineupSortPlan(night)))
    if not act then
        paused = nil
        changed()
        if stuck and stuck > 0 then return nil, L["%d nicht verschoben (Zielgruppe voll)."]:format(stuck) end
        return nil, L["Alle stehen schon in ihrer Gruppe"]
    end
    paused = nil
    sort = { night = night, steps = 0, stalls = 0, quiet = quiet }
    schedule(0)
    changed()
    return true
end

-- The client reported the roster: a sort that waits for it takes its next step.
ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    if sort and sort.waiting then
        sort.waiting = false
        schedule(0.2)
    end
end)

-- A fight stops a running sort at once ("fortsetzen" after it).
ns.OnEvent("PLAYER_REGEN_DISABLED", function()
    if sort then
        paused = sort.night
        done(L["Sortieren nach dem Kampf fortsetzen."], true)
    end
end)

-- The automatic sort: QUIET seconds after the last planned player joined.
local autoToken = 0
ns.Listen("LINEUP_JOINED", function(night)
    if not ns.Get("lineup.autoSort") or not ns.LineupInviteStarted(night) then return end
    autoToken = autoToken + 1
    local token = autoToken
    C_Timer.After(QUIET, function()
        if token ~= autoToken or sort or not IV().HomeRaid() then return end
        if ns.LineupLeadBlocked(true) then return end
        ns.LineupSort(night, true)
    end)
end)

---------------------------------------------------------------------------
-- The automatic assistant for officers
---------------------------------------------------------------------------
local promoted = {}        -- [lower name] = true: promoted (or found promoted) in this raid
local assistToken = 0

local function promote(name)
    local api = _G.C_PartyInfo
    local fn = type(api) == "table" and api.PromoteToAssistant
    if type(fn) == "function" then return pcall(fn, name, true) end
    if type(_G.PromoteToAssistant) == "function" then return pcall(_G.PromoteToAssistant, name) end
    return false
end

-- Promotes the officers of the raid who are no assistant yet: only the raid leader, with the
-- setting, out of combat and the lockdown; once per raider and raid.
function SO.Assist()
    if not IV().HomeRaid() then
        promoted = {}
        return
    end
    if not ns.Get("lineup.autoAssist") or not ns.LineupAllowed() then return end
    if not UnitIsGroupLeader("player") or IV().Fight() then return end
    local me = ns.UnitFullName("player")
    for _, r in ipairs(rosterRows()) do
        local low = r.name:lower()
        if not promoted[low] and not ns.SameName(r.name, me) then
            if r.rank >= 1 then
                promoted[low] = true
            elseif ns.IsVerifiedOfficer(r.name) == true then
                promoted[low] = true
                if promote(r.name) then ns.msg(L["Assistent: %s (Offiziersrang)."]:format(r.name)) end
            end
        end
    end
end

local function assistLater()
    assistToken = assistToken + 1
    local token = assistToken
    C_Timer.After(QUIET, function()
        if token == assistToken then SO.Assist() end
    end)
end
ns.OnEvent("GROUP_ROSTER_UPDATE", assistLater)
-- after a fight or the lockdown the waiting ones get their turn
ns.OnEvent("PLAYER_REGEN_ENABLED", assistLater)
ns.OnEvent("ADDON_RESTRICTION_STATE_CHANGED", assistLater)

SO._reset = function()
    sort, paused, promoted = nil, nil, {}
end
