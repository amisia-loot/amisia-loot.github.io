-- /amisia leistung, the timing (Core/Perf.lua, F-184, D-116): the wrapper while no measurement runs
-- (same returns, errors pass through, nothing allocated), while one runs (calls, own time, longest
-- call, spikes, garbage), nested calls counted once (own time), pcall'd handlers, the labels of the
-- event bus and of ns.Fire (event and File:line of the registration), the login's steps (always,
-- until the first PLAYER_ENTERING_WORLD) and a client without debugstack.
local P = NS.Perf
assert(P and P.clockName == "debugprofilestop", "the stub has the profiling clock")

-- the login's steps: the bus times its handlers until the first PLAYER_ENTERING_WORLD
assert(P.boot, "the login's steps are timed after ADDON_LOADED")
local function bootLabel(pattern)
    for label in pairs(P.BootRows()) do if label:match(pattern) then return label end end
end
assert(bootLabel("^Core ADDON_LOADED$"), "the core's own part of ADDON_LOADED is a step")
STUB.fire("PLAYER_LOGIN")
STUB.fire("PLAYER_ENTERING_WORLD")
assert(not P.boot, "the first PLAYER_ENTERING_WORLD ends the login's steps")
assert(bootLabel("^Event PLAYER_LOGIN %u%a+/[%w_]+:%d+$"), "a PLAYER_LOGIN handler is a step, with File:line")
local count = 0
for _ in pairs(P.BootRows()) do count = count + 1 end
STUB.fire("BAG_UPDATE", 0)
local after = 0
for _ in pairs(P.BootRows()) do after = after + 1 end
assert(after == count, "after the login nothing is timed without a measurement")
assert(type(P.loadMs) == "number", "the files' load time is known")

-- off: the wrapped function returns what fn returns, passes its arguments and its errors
local function three(a, b, ...) return a, b, select("#", ...), ... end
local w = P.Wrap("Test three", three)
local r1, r2, r3, r4, r5 = w(1, nil, "x", nil)
assert(r1 == 1 and r2 == nil and r3 == 2 and r4 == "x" and r5 == nil, "returns and nils pass through")
local boom = P.Wrap("Test boom", function() error("kaputt", 0) end)
local ok, err = pcall(boom)
assert(not ok and err == "kaputt", "the error passes through unchanged")
local tbl = {}
local ok2, err2 = pcall(P.Wrap("Test table error", function() error(tbl) end))
assert(not ok2 and err2 == tbl, "an error value that is no string is the same value")

-- off: nothing is allocated per call
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for i = 1, 20000 do w(i, i) end
local grown = collectgarbage("count") - before
collectgarbage("restart")
assert(grown < 1, "20000 calls while off allocate nothing (" .. grown .. " KB)")

-- on: calls, own time, longest, spikes; nested calls count once
local inner = P.Wrap("Test inner", function(ms) STUB.ms = STUB.ms + ms end)
local outer = P.Wrap("Test outer", function()
    STUB.ms = STUB.ms + 2
    inner(3)
    STUB.ms = STUB.ms + 1
    return "done"
end)
assert(P.Start(), "a measurement starts")
assert(select(1, P.Start()) == false and select(2, P.Start()) == "running", "a second start is refused")
assert(outer() == "done")
inner(6)
local res = P.Stop()
assert(res and not P.Running() and P.Stop() == nil, "stopped once")
local o, i = res.rows["Test outer"], res.rows["Test inner"]
assert(o.n == 1 and o.ms == 3 and o.inc == 6, "the outer call's own time leaves out the inner one")
assert(i.n == 2 and i.ms == 9 and i.max == 6 and i.sp == 1, "the inner calls: two, 9 ms, longest 6, one over 5 ms")
assert(o.sp == 0, "3 ms is no spike")
assert(res.rows["Test three"] == nil, "a label without calls has no row")
inner(1)
assert(P.BootRows()["Test inner"] == nil, "after the stop nothing is counted")

-- an error inside a measured call: the time is lost, the next frame starts the nesting anew
assert(P.Start())
pcall(P.Wrap("Test fails", function() STUB.ms = STUB.ms + 4; error("x") end))
local frame = P.Frame()
frame.scripts.OnUpdate(frame, 0.016)
inner(2)
res = P.Stop()
assert(res.rows["Test fails"] == nil and res.rows["Test inner"].ms == 2, "after a failed call the next one counts in full")
assert(res.frames == 1, "the frames are counted")
assert(frame.scripts.OnUpdate == nil, "the frame counter stops with the measurement")

-- garbage of a measured call
assert(P.Start())
local keep = {}
P.Wrap("Test garbage", function() for n = 1, 2000 do keep[n] = { n } end end)()
res = P.Stop()
assert(res.rows["Test garbage"].kb > 10, "a call that makes tables shows its garbage")

-- ns.PCall for the bus: what pcall returns, timed
assert(P.Start())
local okP, a, b = P.PCall("Test pcall", function(x) STUB.ms = STUB.ms + 1; return x, "y" end, "x")
local okE, e = P.PCall("Test pcall", function() error("nein", 0) end)
res = P.Stop()
assert(okP and a == "x" and b == "y" and not okE and e == "nein", "PCall returns what pcall returns")
assert(res.rows["Test pcall"].n == 2 and res.rows["Test pcall"].ms == 1, "both calls counted, the failed one too")

-- the event bus and ns.Fire label every handler with its event and where it was registered
assert(NS.PerfReport.Start("hand", 600, "time"))
local seen = {}
NS.OnEvent("BAG_UPDATE", function(bag) seen[#seen + 1] = bag; STUB.ms = STUB.ms + 2 end)
NS.Listen("TEST_PERF", function(v) seen[#seen + 1] = v end)
STUB.fire("BAG_UPDATE", 3)
NS.Fire("TEST_PERF", "z")
STUB.fire("ZONE_CHANGED_NEW_AREA")
STUB.fire("PLAYER_LOGOUT")   -- the measurement's own handler saves and stops it (PerfReport)
assert(seen[#seen - 1] == 3 and seen[#seen] == "z", "the handlers still get their arguments")
local run = AmisiaDB.perf.runs[1]
assert(run and run.stop == "logout", "the logout ended the measurement")
local labels = {}
for _, row in ipairs(run.rows) do labels[row.l] = row end
local bag
for l, row in pairs(labels) do if l:match("^Event BAG_UPDATE ") and row.ms == 2 then bag = l end end
assert(bag, "the test's BAG_UPDATE handler has its own row")
local fired
for l in pairs(labels) do if l:match("^Fire TEST_PERF ") then fired = l end end
assert(fired, "the ns.Fire handler has its own row")
local zone
for l in pairs(labels) do if l:match("^Event ZONE_CHANGED_NEW_AREA Core/PerfReport:%d+$") then zone = l end end
assert(zone, "an addon handler names its file and line")
assert(labels["Core ZONE_CHANGED_NEW_AREA"], "the core's own part of an event has its row")

-- an error in a bus handler still reaches the error handler, and the others still run
local reported = {}
local oldReport = NS.ReportError
NS.ReportError = function(m) reported[#reported + 1] = m end
assert(P.Start())
local ran = false
NS.OnEvent("BAG_UPDATE_DELAYED", function() error("Handler kaputt", 0) end)
NS.OnEvent("BAG_UPDATE_DELAYED", function() ran = true end)
STUB.fire("BAG_UPDATE_DELAYED")
P.Stop()
NS.ReportError = oldReport
assert(ran and reported[1] == "Handler kaputt", "a failing handler is reported, the next one runs")

-- P.Where without debugstack: registration still works, the label says "?"
local saved = _G.debugstack
_G.debugstack = nil
assert(P.Where(1) == nil)
NS.OnEvent("BAG_UPDATE_COOLDOWN", function() end)
_G.debugstack = function() error("no stack") end
assert(P.Where(1) == nil, "a failing debugstack gives no place")
NS.OnEvent("BAG_UPDATE_COOLDOWN", function() end)
_G.debugstack = saved
assert(P.HandlerLabel("Event", "X", nil) == "Event X ?")
assert(P.Label("Refresh ", "gear") == "Refresh gear" and P.Label("Refresh ", "gear") == P.Label("Refresh ", "gear"))
