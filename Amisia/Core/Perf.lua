-- Amisia's measurement of its own CPU time (F-184, D-116, spec docs/specs/2026-11-12-leistung-messen.md).
-- Loaded right after the registry, before every file it measures; the command, the report and the
-- saved runs live in Core/PerfReport.lua (the last file of the TOC).
--
-- ns.Perf.Wrap(label, fn) gives a function that, while no measurement runs, checks one upvalue and
-- tail-calls fn; while one runs it times the call. Every number of a label is its own time ("self
-- time"): what a wrapped call inside it took counts for that call's label, not twice. So the labels
-- add up to Amisia's measured time. A call over SPIKE milliseconds of its own time is a spike.
-- Errors pass through unchanged (no pcall); the time of a call that failed is lost, and the
-- bookkeeping of nested calls starts again at the next frame.
--
-- Always on (without a measurement): the time from the top of the first TOC file to the end of the
-- last (Locales/Locale.lua stamps ns.PERF_T0) and the time of the bus handlers (ns.OnEvent, ns.Fire)
-- until the first PLAYER_ENTERING_WORLD after loading ("boot"): two clock reads per handler.
local _, ns = ...
ns.Load(function()

-- the clock in milliseconds: debugprofilestop, else GetTimePreciseSec, else none (no measurement)
local profile = type(debugprofilestop) == "function" and debugprofilestop or nil
local precise = not profile and type(GetTimePreciseSec) == "function" and GetTimePreciseSec or nil
local clock = profile or (precise and function() return precise() * 1000 end) or nil
local gc = collectgarbage

local SPIKE = 5   -- ms of a call's own time that make it a spike

local P = {
    SPIKE = SPIKE,
    on = false,                   -- a measurement runs (the bus and ns.Fire read it)
    boot = clock ~= nil,          -- the login's bus handlers are timed until the first PLAYER_ENTERING_WORLD
    clockName = profile and "debugprofilestop" or precise and "GetTimePreciseSec" or nil,
}
ns.Perf = P

local on = false        -- the same as P.on, an upvalue for the wrappers
local rows              -- label -> { n, ms, inc, max, sp, kb } of the running measurement
local bootRows = {}     -- the same for the login steps
local child, childKB = 0, 0   -- own time and memory of the measured calls inside the current one

local function add(t, label, selfMs, incMs, kb)
    local r = t[label]
    if not r then
        r = { n = 0, ms = 0, inc = 0, max = 0, sp = 0, kb = 0 }
        t[label] = r
    end
    r.n = r.n + 1
    r.ms = r.ms + selfMs
    r.inc = r.inc + incMs
    r.kb = r.kb + kb
    if selfMs > r.max then r.max = selfMs end
    if selfMs > SPIKE then r.sp = r.sp + 1 end
end

-- Begins a measured stretch: its start, its memory and the nested counters of the stretch around it.
local function begin()
    local savedMs, savedKB = child, childKB
    child, childKB = 0, 0
    local kb0 = gc("count")
    return clock(), kb0, savedMs, savedKB
end

-- Ends it under label: its own time is what the measured calls inside did not take.
local function finish(label, t0, kb0, savedMs, savedKB)
    local dt = clock() - t0
    local dkb = gc("count") - kb0
    -- another addon's debugprofilestart sets the clock back; a collection inside frees memory
    if dt < 0 then dt = 0 end
    if dkb < 0 then dkb = 0 end
    local selfMs, selfKB = dt - child, dkb - childKB
    if selfMs < 0 then selfMs = 0 end
    if selfKB < 0 then selfKB = 0 end
    child, childKB = savedMs + dt, savedKB + dkb
    if on and rows then add(rows, label, selfMs, dt, selfKB) end
    if P.boot then add(bootRows, label, selfMs, dt, selfKB) end
end

local function finishWith(label, t0, kb0, savedMs, savedKB, ...)
    finish(label, t0, kb0, savedMs, savedKB)
    return ...
end

-- For a stretch that is no function call of its own (the core's own branch of the event frame, a
-- data build): local a, b, c, d = P.Begin() ... P.End(label, a, b, c, d). Only while P.on or P.boot.
P.Begin = begin
P.End = finish

-- fn wrapped: untouched while no measurement runs; returns and errors pass through. Without a clock
-- fn itself comes back.
function P.Wrap(label, fn)
    if not clock then return fn end
    return function(...)
        if not on then return fn(...) end
        local t0, kb0, savedMs, savedKB = begin()
        return finishWith(label, t0, kb0, savedMs, savedKB, fn(...))
    end
end

-- pcall(fn, ...) timed under label (the bus and ns.Fire, which run their handlers protected anyway):
-- returns what pcall returns. Only while P.on or P.boot.
function P.PCall(label, fn, ...)
    local t0, kb0, savedMs, savedKB = begin()
    return finishWith(label, t0, kb0, savedMs, savedKB, pcall(fn, ...))
end

-- prefix .. key, made once (a measurement makes no new strings for its labels).
local labels = {}
function P.Label(prefix, key)
    local t = labels[prefix]
    if not t then
        t = {}
        labels[prefix] = t
    end
    local s = t[key]
    if not s then
        s = prefix .. tostring(key)
        t[key] = s
    end
    return s
end

-- "Raid/Rolls:123": where the Lua function level steps up from the caller of Where stands (1: the
-- caller itself, 2: its caller), from debugstack; nil without it. The stack's frames without a file of
-- Amisia's (C functions such as pcall, tail calls) and those of this file are skipped, so the count
-- does not depend on how the client numbers its levels. Only at registration, never per call.
function P.Where(level)
    if type(debugstack) ~= "function" then return nil end
    local ok, s = pcall(debugstack, 1, 8, 0)
    if not ok or type(s) ~= "string" then return nil end
    local n = 0
    for text in s:gmatch("[^\n]+") do
        local file, line = text:match("AddOns[/\\]Amisia[/\\](.-)%.lua\"?%]?:(%d+)")
        if not file then file, line = text:match("([%w_]+[/\\][%w_/\\]+)%.lua\"?%]?:(%d+)") end
        if file then
            file = file:gsub("\\", "/")
            if file ~= "Core/Perf" then
                n = n + 1
                if n == (level or 1) then return file .. ":" .. line end
            end
        end
    end
    return nil
end

-- The label of a handler: "Event PLAYER_LOGIN Raid/Rolls:12" (kind "Event" or "Fire").
function P.HandlerLabel(kind, name, where)
    return ("%s %s %s"):format(kind, tostring(name), where or "?")
end

---------------------------------------------------------------------------
-- The running measurement
---------------------------------------------------------------------------
local frame
local frames, frameMs, combat = 0, 0, 0

local function onFrame(_, elapsed)
    -- no Amisia code is running between two frames: a failed call left nothing open
    child, childKB = 0, 0
    elapsed = elapsed or 0
    frames = frames + 1
    frameMs = frameMs + elapsed
    if InCombatLockdown and InCombatLockdown() then combat = combat + elapsed end
end

-- Starts a measurement; false and "running" or "noclock" when it cannot.
function P.Start()
    if on then return false, "running" end
    if not clock then return false, "noclock" end
    rows = {}
    frames, frameMs, combat = 0, 0, 0
    child, childKB = 0, 0
    if not frame then frame = CreateFrame("Frame") end
    frame:SetScript("OnUpdate", onFrame)
    on, P.on = true, true
    return true
end

-- Ends it: { rows = { [label] = row }, frames, combat } or nil when none ran.
function P.Stop()
    if not on then return nil end
    on, P.on = false, false
    if frame then frame:SetScript("OnUpdate", nil) end
    local out = { rows = rows, frames = frames, combat = combat }
    rows = nil
    return out
end

function P.Running() return on end
-- the frame that counts frames (tests run its OnUpdate)
function P.Frame() return frame end

-- The login's steps are done: the first PLAYER_ENTERING_WORLD after loading has been handled.
function P.BootDone()
    P.boot = false
end
function P.BootRows() return bootRows end

-- Milliseconds since the first TOC file started (nil without a clock or the stamp).
function P.Since()
    if not clock or type(ns.PERF_T0) ~= "number" then return nil end
    return clock() - ns.PERF_T0
end

P.Clock = clock
end)
