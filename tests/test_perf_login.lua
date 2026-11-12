--[[clients Vulo]]
-- /amisia leistung login (Core/PerfReport.lua, F-184, D-116): armed, kept across the /reload in
-- AmisiaDB.perf, started at ADDON_LOADED before the other handlers, 60 s long, then the report;
-- armed only once. A measurement running at the /reload is saved by PLAYER_LOGOUT first.
local V = "Vulo"
C(V, [[STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD")]])
C(V, [[NS.Dispatch("leistung login")]])
assert(C(V, "AmisiaDB.perf.arm") == true and not C(V, "NS.Perf.Running()"), "armed, nothing measured yet")
assert(C(V, [[STUB.messages[#STUB.messages]:find("Die nächste Anmeldung oder /reload wird 60 s lang gemessen", 1, true) ~= nil]]))

-- the /reload: PLAYER_LOGOUT, a fresh runtime with the saved table
C(V, [[STUB.fire("PLAYER_LOGOUT")]])
BUS.reload(V)
assert(C(V, "NS.Perf.Running()") == true, "the measurement runs from ADDON_LOADED on")
assert(C(V, "AmisiaDB.perf.arm") == nil, "armed once only")
assert(C(V, [[STUB.messages[#STUB.messages]:find("Der Login wird 60 s lang gemessen", 1, true) ~= nil]]))
C(V, [[STUB.fire("PLAYER_LOGIN"); STUB.fire("PLAYER_ENTERING_WORLD")]])
BUS.tick(59)
assert(C(V, "NS.Perf.Running()") == true)
BUS.tick(1)
assert(C(V, "NS.Perf.Running()") == false, "it stops itself after 60 s")
local run = C(V, "AmisiaDB.perf.runs[1]")
assert(run.kind == "login" and run.stop == "time" and run.dur == 60, "a login run of 60 s")
local labels = {}
for _, r in ipairs(run.rows) do labels[r.l] = r end
assert(labels["Core ADDON_LOADED"], "the core's part of ADDON_LOADED is in the login run")
-- the stub's clock stands still: every row has 0 ms and the 60 kept are the most called; the
-- login's handlers were measured all the same
assert(run.n > #run.rows and #run.rows == 60, "more calls than rows")
assert(C(V, [[(function() for l in pairs(NS.Perf.BootRows()) do if l:match("^Event PLAYER_LOGIN ") then return true end end end)()]]),
    "the PLAYER_LOGIN handlers were timed")
assert(C(V, [[(function() for _, m in ipairs(STUB.messages) do if m:find("Leistung (Login, ", 1, true) then return true end end end)()]]),
    "the report is in the chat")

-- a measurement running at a /reload is saved before the file is written
C(V, [[NS.Dispatch("leistung")]])
C(V, [[STUB.fire("PLAYER_LOGOUT")]])
BUS.reload(V)
assert(C(V, "AmisiaDB.perf.runs[1].stop") == "logout" and C(V, "#AmisiaDB.perf.runs") == 2, "the running one was saved")
assert(C(V, "NS.Perf.Running()") == false, "no measurement after a plain /reload")
