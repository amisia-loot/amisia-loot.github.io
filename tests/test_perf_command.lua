-- /amisia leistung (Core/PerfReport.lua, F-184, D-116): start and stop by command, the report in the
-- chat, "bericht", a measurement of N minutes that stops itself, the cap of 60 minutes, the logout,
-- the saved run's shape and its caps (5 runs, 60 rows, the worst-case size), no player names in what is
-- saved, the wrapped call sites still doing their work, the self-test's line.
local P, R = NS.Perf, NS.PerfReport
STUB.fire("PLAYER_LOGIN")
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.instance = { name = "Durotar", type = "none", id = 0 }

local function said(pattern)
    for _, m in ipairs(STUB.messages) do if m:find(pattern) then return m end end
end
local function clearChat() STUB.messages = {} end

-- start and stop by command: one quiet line at the start, the report at the stop
clearChat()
NS.Dispatch("leistung")
assert(P.Running(), "the first call starts a measurement")
assert(#STUB.messages == 1 and said("Messung läuft %(höchstens 60 min%)"), "one line at the start")
local work = P.Wrap("OnUpdate Test", function() STUB.ms = STUB.ms + 7 end)
for _ = 1, 3 do work() end
local frame = P.Frame()
for _ = 1, 4 do frame.scripts.OnUpdate(frame, 0.25) end
STUB.combat = true
frame.scripts.OnUpdate(frame, 0.5)
STUB.combat = false
STUB.tick(30)
assert(#STUB.messages == 1, "no chat lines while it runs")
NS.Dispatch("leistung")
assert(not P.Running(), "the second call stops it")
local run = AmisiaDB.perf.runs[1]
assert(run.kind == "hand" and run.stop == "hand" and run.dur == 30 and run.fr == 5 and run.cb == 0.5, "duration, frames, combat")
assert(run.where == "none" and run.g == "forever" and run.v == NS.VERSION and run.b == "1.60.1.70205", "where, game, version, build")
assert(run.ms == 21 and run.sp == 3 and run.n > 3 and run.rows[1].l == "OnUpdate Test" and run.rows[1].n == 3 and run.rows[1].max == 7, "the rows")
assert(said("^|cffe2b857Amisia:|r Leistung %(von Hand, ") and said("30 s gemessen, 5 Frames, 0 fps, 1 s im Kampf, außerhalb von Instanzen; von Hand beendet%."),
    "the report's first line")
assert(said("Amisia: 0,70 ms je Sekunde, 4,200 ms je Frame %(25,2 %% von 16,7 ms, einem Frame bei 60 fps%); %d+ Aufrufe, 3 über 5 ms%."), "Amisia's time")
assert(said("%d%. Ticker Chat ·") or said("%d%. Ticker MapPlaces ·"), "the tickers are measured too")
assert(said("Speicher: Amisia %? %-> %?, alle Addons [%d,]+ MB %-> [%d,]+ MB; Müll von Amisia [%d,]+ KB je Sekunde%."), "the memory line")
assert(said("Laden: Dateien [%d,]+ ms, ADDON_LOADED [%d,]+ ms, PLAYER_LOGIN [%d,]+ ms, PLAYER_ENTERING_WORLD [%d,]+ ms, andere Ereignisse [%d,]+ ms%."), "the load line")
assert(said("Gebaute Daten: keine%.") or said("Gebaute Daten: "), "the data line")
assert(said("Die %d+ teuersten Stellen, eigene Zeit %(Aufrufe · ms gesamt · ms je Aufruf · längster Aufruf in ms · über 5 ms%):"), "the head of the rows")
assert(said(" 1%. OnUpdate Test · 3 · 21 · 7,000 · 7,00 · 3$"), "the row: calls, ms, per call, longest, spikes")
local reportLines = #STUB.messages - 1

-- "bericht" shows the last run again
clearChat()
NS.Dispatch("leistung bericht")
assert(#STUB.messages == reportLines and said("1%. OnUpdate Test"), "the same report again")
clearChat()
NS.Dispatch("leistung aus")
assert(said("Es läuft keine Messung%."), "off without a measurement")

-- a number: that many minutes, then it stops by itself with the report
clearChat()
NS.Dispatch("leistung 2")
assert(P.Running() and said("Messung läuft 2 min%."), "two minutes")
NS.Dispatch("leistung an")
assert(said("Die Messung läuft schon%."), "a second start is refused")
STUB.tick(119)
assert(P.Running(), "still running before two minutes")
STUB.tick(1)
assert(not P.Running() and AmisiaDB.perf.runs[1].stop == "time" and said("nach der gewählten Zeit beendet"), "stopped after two minutes, with the report")
NS.Dispatch("leistung 500")
assert(said("Messung läuft 60 min%."), "at most 60 minutes")
NS.Dispatch("leistung aus")

-- the cap: without minutes it stops after 60 minutes
NS.Dispatch("leistung an")
STUB.tick(3599)
assert(P.Running())
STUB.tick(1)
assert(not P.Running() and AmisiaDB.perf.runs[1].stop == "cap" and AmisiaDB.perf.runs[1].dur == 3600, "the cap ends it")

-- the logout saves the running measurement without a report; an old timer stops no later one
NS.Dispatch("leistung 1")
clearChat()
STUB.fire("PLAYER_LOGOUT")
assert(not P.Running() and AmisiaDB.perf.runs[1].stop == "logout" and #STUB.messages == 0, "saved at the logout, silently")
NS.Dispatch("leistung")
STUB.tick(60)
assert(P.Running(), "the timer of the run before does not stop this one")
NS.Dispatch("leistung")

-- where: an instance met during the run
NS.Dispatch("leistung")
STUB.instance = { name = "Ragefire Chasm", type = "party", id = 389 }
STUB.fire("PLAYER_ENTERING_WORLD")
clearChat()
NS.Dispatch("leistung")
assert(AmisiaDB.perf.runs[1].where == "none,party" and said("teils in einer Instanz"), "the instance types met")
STUB.instance = { name = "Durotar", type = "none", id = 0 }

-- usage
clearChat()
NS.Dispatch("leistung quatsch")
assert(said("Aufruf: /amisia leistung %[an|aus|bericht|login|<Minuten>%]"), "the usage line")

-- the caps: 5 runs, 60 rows, labels of 60 bytes
assert(#AmisiaDB.perf.runs == 5, "five runs kept")
NS.Dispatch("leistung")
for n = 1, 70 do
    P.Wrap(("Ticker " .. string.rep("x", 70) .. "%02d"):format(n), function() STUB.ms = STUB.ms + n / 10 end)()
end
NS.Dispatch("leistung")
run = AmisiaDB.perf.runs[1]
assert(#run.rows == 60 and run.n == 70 and #run.rows[1].l == 60, "60 rows of 60 bytes, the totals over all 70")
assert(run.rows[1].ms >= run.rows[60].ms, "the costliest first")

-- the worst case: 5 full runs
for _ = 1, 5 do table.insert(AmisiaDB.perf.runs, 1, run) end
NS.PerfLoaded(AmisiaDB)
assert(#AmisiaDB.perf.runs == 5 and AmisiaDB.perf.arm == nil, "a load keeps 5 runs")
local size = #STUB.dump(AmisiaDB.perf)
assert(size < 60000, "the saved runs stay small: " .. size .. " bytes")
print(("worst case AmisiaDB.perf: %d bytes"):format(size))

-- "bericht" of a saved run with odd fields (a file from elsewhere) does not break
AmisiaDB.perf.runs[1] = { at = 5, kind = 3, dur = "x", fr = {}, mem = 3, data = { "z", { k = {} } }, rows = { { l = {}, n = "x" }, "y" } }
clearChat()
NS.Dispatch("leistung bericht")
assert(said("1%. table: ") and said("Leistung %(3, "), "odd fields are shown as they are")

-- a broken saved table is replaced, a run without its time dropped, too many rows cut
AmisiaDB.perf = { v = 1, runs = { "x", { at = 5, rows = "y" }, { rows = {} } }, arm = "ja" }
NS.PerfLoaded(AmisiaDB)
assert(#AmisiaDB.perf.runs == 1 and type(AmisiaDB.perf.runs[1].rows) == "table" and not P.Running(), "the shape is checked")
AmisiaDB.perf = "kaputt"
NS.PerfLoaded(AmisiaDB)
assert(AmisiaDB.perf.v == 1 and #AmisiaDB.perf.runs == 0)
clearChat()
NS.Dispatch("leistung bericht")
assert(said("Noch keine Messung gespeichert"), "nothing saved yet")

-- no names of players, characters or realms in what is saved
STUB.roster = { { name = STUB.player, class = "PRIEST" }, { name = "Kimara", class = "MAGE" } }
NS.Dispatch("leistung")
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.fire("CHAT_MSG_WHISPER", "hallo", "Kimara-Realm")
NS.Fire("DATA_CHANGED")
STUB.tick(5)
NS.Dispatch("leistung")
local text = STUB.dump(AmisiaDB.perf)
assert(not text:find(STUB.player, 1, true) and not text:find("Kimara", 1, true) and not text:find("Realm", 1, true), "no names saved")
assert(#AmisiaDB.perf.runs[1].rows > 0, "the handlers of the events were measured")

-- a wrapped call site still does its work: the loot toast's OnUpdate, a ticker, a tooltip part
NS.Dispatch("leistung")
NS.Set("toast.show", true)
assert(NS.LootToast(2589, 1, STUB.link(2589, "Linen Cloth", 1)), "the loot toast shows a line")
local holder = _G.AmisiaLootToast
holder.scripts.OnUpdate(holder, 0.1)
STUB.tick(5)
holder.scripts.OnUpdate(holder, 5)
assert(#NS.LootToastLines() == 0 and holder.scripts.OnUpdate == nil, "the toast's lines fade and its OnUpdate ends")
NS.Dispatch("leistung")
local names = {}
for _, r in ipairs(AmisiaDB.perf.runs[1].rows) do names[r.l] = true end
assert(names["OnUpdate LootToast"], "the toast's OnUpdate was measured")

-- the self-test names the clock
local selftest = NS.SelfTest.Run().text
assert(selftest:find("Zeitmessung", 1, true) and selftest:find("debugprofilestop, mit debugstack", 1, true), "the self-test's line")
