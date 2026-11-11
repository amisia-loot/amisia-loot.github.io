-- Run times (Gear/RunTimes.lua, Gear/RunTimer.lua, the part Zeiten; F-166, D-96): the clock starts with
-- the first fight of a fresh run inside the instance (entering alone starts nothing, a run with a kill
-- or a clock before neither), each boss of the list stores its split, the last boss of the game's order
-- finishes it; best total and the fastest segment per boss only from finished runs; a reset, 30 minutes
-- outside or `/amisia zeiten stop` end it "nicht beendet"; the history cap; the cleanup on load; the
-- window's lines and colours, the settings, the slash command, the chat line; the part Zeiten.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local RT, R = NS.RunTimes, NS.Runs
_G.INSTANCE_RESET_SUCCESS = "%s has been reset."
local ME = NS.UnitFullName("player")
-- the Hall of Thanes: four bosses, the last Durgen Dirgehammer
local THANES = { name = "Halle der Thane", type = "party", id = 3065 }
local E1, E2, E3, E4 = 3493, 3495, 3494, 3496
local OUT = { name = "", type = "none", id = 0 }
local function enter(i)
    STUB.instance = i
    STUB.fire("PLAYER_LEAVING_WORLD")
    STUB.fire("PLAYER_ENTERING_WORLD")
end
local function kill(enc) STUB.fire("ENCOUNTER_END", enc, "Boss", 1, 5, 1) end
local function fight() STUB.fire("PLAYER_REGEN_DISABLED"); STUB.fire("PLAYER_REGEN_ENABLED") end
local function resetInside() STUB.fire("CHAT_MSG_SYSTEM", "Halle der Thane has been reset.") end
local function times() return RT.Of("thanes") end

assert(NS.Get("runtimes.window") == true and NS.Get("runtimes.raids") == true, "the defaults")
assert(RT.Fmt(59) == "0:59" and RT.Fmt(754) == "12:34" and RT.Fmt(3725) == "1:02:05", "the format")
assert(RT.Diff(-12) == "-0:12" and RT.Diff(7) == "+0:07" and RT.Diff(0) == "0:00", "the difference")

---------------------------------------------------------------------------
-- entering alone starts nothing; the first fight starts the clock and opens the window
---------------------------------------------------------------------------
STUB.roster = {}
enter(THANES)
STUB.tick(300)   -- waiting at the entrance
assert(RT.Live() == nil, "entering starts no clock")
local W = _G.AmisiaRunTimer
assert(W and not W:IsShown(), "the window is built inside, not shown")
fight()
local l = RT.Live()
assert(l and l.k == "thanes" and l.nm == "Halle der Thane" and l.n == 1, "the clock runs")
assert(W:IsShown() and W.TitleContainer.TitleText:GetText() == "Halle der Thane", "the window opened")
assert(W.sub:GetText() == "Noch keine Bestzeit", W.sub:GetText())
STUB.tick(60)
kill(E1)
STUB.fire("BOSS_KILL", E1)
assert(RT.Live().s[E1] == 60, "the first split")
-- another fight, a kill twice, a foreign encounter: nothing new
local at = RT.Live().at
STUB.tick(30); fight()
assert(RT.Live().at == at, "the clock does not restart")
kill(99999)
assert(NS.Count(RT.Live().s) == 1, "only the list's bosses")
STUB.tick(90)
kill(E2)
assert(RT.Live().s[E2] == 180)
-- the bosses as portraits (F-180): in colour once killed, the split in the tooltip
local rows = W.bosses
assert(#rows == 4 and rows[1]:IsShown() and not rows[1].dim and rows[1].tip[1] == "Faldrim Anvilmar"
    and has(rows[1].tip[2], "Zwischenzeit 1:00") and #rows[1].tip == 2, "the first boss")
assert(rows[3].dim and has(rows[3].tip[1], "Plunder") and has(rows[3].tip[2], "Noch nicht getötet") and #rows[3].tip == 2,
    "an open boss without a best")
-- the live total from GetTime (the window's OnUpdate)
STUB.tick(1)
W.scripts.OnUpdate(W, 1)
assert(W.total:GetText() == "3:01", W.total:GetText())
-- the last boss of the game's order ends it (Plunder skipped)
STUB.tick(59)
kill(E4)
assert(RT.Live() == nil, "finished")
assert(said("Halle der Thane in 4:00 (erste gemessene Zeit)."), STUB.messages[#STUB.messages])
local t = times()
assert(t.best and t.best.t == 240 and t.best.d and t.best.c == ME and t.best.n == 1, "the best run")
assert(t.seg[E1].t == 60 and t.seg[E2].t == 120 and t.seg[E4].t == 60 and t.seg[E3] == nil, "the fastest segments")
assert(#t.runs == 1 and t.runs[1].d, "in the history")
assert(W:IsShown() and has(W.result:GetText(), "Erste gemessene Zeit") and W.sub:GetText() == "Bestzeit 4:00", W.sub:GetText())
assert(rows[3].dim and has(rows[3].tip[2], "Übersprungen") and not rows[4].dim, "Plunder skipped, the last one killed")

---------------------------------------------------------------------------
-- a reset before the end: "nicht beendet", never a best; the window closes
---------------------------------------------------------------------------
resetInside()
fight()
assert(RT.Live(), "a fresh run's clock")
STUB.tick(50)
kill(E1)
assert(has(rows[1].tip[3], NS.Theme.GREEN) and has(rows[1].tip[3], "-0:10 zum besten Lauf"), "faster: green " .. tostring(rows[1].tip[3]))
-- the next boss shows the best run's split as the target, in grey
assert(rows[2].dim and has(rows[2].tip[3], NS.Theme.GREY) and has(rows[2].tip[3], "Ziel: 3:00 (bester Lauf)"), tostring(rows[2].tip[3]))
assert(#rows[3].tip == 2, "only the next one has a target; Plunder has no split in the best run")
resetInside()
assert(RT.Live() == nil and #times().runs == 2 and not times().runs[1].d and times().runs[1].t == 50, "unfinished")
assert(times().best.t == 240, "no best from it")
assert(not W:IsShown(), "the window closed")

---------------------------------------------------------------------------
-- a faster finished run: a new best, better segments; a slower one: red
---------------------------------------------------------------------------
STUB.messages = {}
fight(); STUB.tick(70); kill(E1); STUB.tick(80); kill(E2)
assert(has(rows[1].tip[3], NS.Theme.RED) and has(rows[1].tip[3], "+0:10"), "slower is red")
assert(has(rows[2].tip[3], NS.Theme.GREEN) and has(rows[2].tip[3], "-0:30"), "faster is green")
STUB.tick(50); kill(E4)
assert(said("Halle der Thane in 3:20 (Bestzeit 4:00, -0:40)."), STUB.messages[#STUB.messages])
t = times()
assert(t.best.t == 200 and t.seg[E1].t == 60 and t.seg[E2].t == 80 and t.seg[E4].t == 50, "new best and segments")
assert(has(W.result:GetText(), "Neue Bestzeit! -0:40") and W.sub:GetText() == "Bestzeit vorher 4:00", W.result:GetText())
resetInside()
STUB.messages = {}
fight(); STUB.tick(300); kill(E4)
assert(said("Halle der Thane in 5:00 (Bestzeit 3:20, +1:40)."), STUB.messages[#STUB.messages])
assert(has(W.result:GetText(), NS.Theme.RED) and has(W.result:GetText(), "+1:40 zur Bestzeit"), W.result:GetText())
assert(times().best.t == 200, "the best stays")

---------------------------------------------------------------------------
-- no clock for a run with a kill; `/amisia zeiten stop`; one clock per run
---------------------------------------------------------------------------
resetInside()
R.Mark("thanes", 1, true)
fight()
assert(RT.Live() == nil, "a boss already died in this run")
resetInside()
fight()
STUB.messages = {}
NS.Dispatch("zeiten stop")
assert(said("Uhr angehalten") and RT.Live() == nil and not times().runs[1].d, "stopped")
fight()
assert(RT.Live() == nil, "no second clock in the same run")
NS.Dispatch("zeiten stop")
assert(said("Es läuft keine Uhr."))

---------------------------------------------------------------------------
-- outside: the clock runs on (wall time), 30 minutes outside end it
---------------------------------------------------------------------------
STUB.tick(5)
resetInside()
fight(); STUB.tick(40); kill(E1)
enter(OUT)
assert(RT.Live() and W:IsShown(), "a ghost outside keeps the clock and the window " .. tostring(RT.Live()) .. tostring(W:IsShown()))
STUB.tick(10 * 60)
enter(THANES)
STUB.tick(20); kill(E2)
assert(RT.Live().s[E2] == 40 + 600 + 20, "outside counts: " .. tostring(RT.Live().s[E2]))
enter(OUT)
STUB.tick(31 * 60)
STUB.fire("ZONE_CHANGED_NEW_AREA")
assert(RT.Live() == nil and not times().runs[1].d and times().runs[1].t == 660, "left for good")
assert(not W:IsShown())

---------------------------------------------------------------------------
-- settings: no window in a dungeon; /amisia zeiten opens it; raids
---------------------------------------------------------------------------
NS.Set("runtimes.window", false)
enter(THANES)
resetInside()
fight()
assert(RT.Live() and not W:IsShown(), "measured without the window")
NS.Dispatch("zeiten")
assert(W:IsShown() and NS.RunTimer.Shown() == "thanes", "the slash command opens it")
RT.Stop()
NS.Set("runtimes.window", true)
NS.Set("runtimes.raids", false)
W:Hide()
enter({ name = "Onyxias Hort", type = "raid", id = 249 })
fight()
assert(RT.Live() and RT.Live().k == "onyxia" and not W:IsShown(), "no window in a raid")
kill(1084)
assert(RT.Of("onyxia").best and RT.Of("onyxia").best.t == 0, "one boss: finished at once")
NS.Set("runtimes.raids", true)

---------------------------------------------------------------------------
-- the history cap: 20 per instance
---------------------------------------------------------------------------
enter(THANES)
for _ = 1, 25 do
    resetInside()
    fight(); STUB.tick(100); kill(E4)
end
assert(#times().runs == 20, "20 runs kept: " .. #times().runs)
assert(times().runs[1].at > times().runs[20].at, "newest first")

---------------------------------------------------------------------------
-- the part Zeiten of the page Dungeons, "Zeiten löschen"
---------------------------------------------------------------------------
enter(OUT)
NS.ShowDungeon("thanes", "times")
local B = NS.PageFrame("dungeons")
assert(B.parts.times:IsShown() and B.parts.times.on and B.timesView:IsShown() and B.header.ButtonText:GetText() == "Zeiten", "the part")
local items = B.timesView.items
assert(items[1].kind == "head" and items[1].cells[1] == "Bester Lauf" and items[2].cells[2] == "1:40", "the best run first")
assert(items[3].cells[1] == "Bestzeit je Boss" and items[4].cells[1] == "1. Faldrim Anvilmar" and items[4].cells[3] == "1:00", "the bosses")
local runsHead
for i, it in ipairs(items) do if it.cells[1] == "Letzte Läufe" then runsHead = i end end
assert(runsHead and #items - runsHead == 20 and items[runsHead + 1].cells[3] == "1 Spieler", "the runs")
assert(B.clearTimes:IsShown(), "the delete link")
B.clearTimes:Click()
AmisiaConfirmFrame.ok:Click()
assert(times() == nil and B.timesView.empty:IsShown() and not B.clearTimes:IsShown(), "deleted")
-- a raid's part on the page Raids
NS.ShowDungeon("onyxia", "times")
local RB = NS.PageFrame("raidjournal")
assert(RB.timesView:IsShown() and RB.timesView.items[2].cells[2] == "0:00", "the raid's times")
-- the settings' button deletes every instance's
NS.SettingItem("runtimes.clear").run()
AmisiaConfirmFrame.ok:Click()
assert(next(AmisiaDB.runTimes.inst) == nil, "all deleted")
STUB.messages = {}
NS.Dispatch("zeiten")
assert(said("Noch keine Zeiten."), "nothing to show outside")
NS.Dispatch("zeiten foo")
assert(said("Aufruf: /amisia zeiten [stop]"))

---------------------------------------------------------------------------
-- the cleanup on load
---------------------------------------------------------------------------
local junkRuns = {}
for i = 1, 30 do junkRuns[i] = { at = 1789000000 + i, t = 100 + i, s = { [E1] = 10, bad = 3 }, n = 5, c = "Vuloo" } end
junkRuns[31] = { at = "x", t = 1, c = "Vuloo" }
junkRuns[32] = { at = 1789000000, t = 5, c = "Bad|cffname" }
local inst = { thanes = { nm = "Halle der Thane", best = { at = 1789000000, t = 99, s = {}, n = 1, c = "Vuloo" }, -- not finished: no best
    seg = { [E1] = { t = 5, at = 1789000000, c = "Vuloo" }, [0] = { t = 1, at = 1, c = "x" } }, runs = junkRuns },
    ["bad key"] = { runs = { { at = 1789000000, t = 1, c = "Vuloo", d = true } } }, empty = { runs = {} } }
for i = 1, 70 do inst["k" .. i] = { runs = { { at = 1789001000 + i, t = 10, c = "Vuloo", d = true } } } end
AmisiaDB.runTimes = { v = 1, inst = inst, live = { Vuloo = { k = "thanes", i = 3065, at = 1789000000, r = 1789000000, s = { [E1] = 3 } },
    Bad = { k = "thanes" }, ["x|y"] = { k = "thanes", i = 1, at = 1, r = 1 } }, last = { Vuloo = { r = 1789000000, i = 3065 }, Bad = "no", Old = 1789000000 } }
RT.Loaded()
local c = AmisiaDB.runTimes
assert(NS.Count(c.inst) == 60 and c.inst.thanes == nil and c.inst.k70 and not c.inst.k1, "60 latest instances")
AmisiaDB.runTimes.inst = { thanes = inst.thanes, ["bad key"] = inst["bad key"], empty = inst.empty }
RT.Loaded()
c = AmisiaDB.runTimes
local th = c.inst.thanes
assert(th and th.best == nil and #th.runs == 20 and th.runs[1].at == 1789000030 and th.runs[1].s.bad == nil, "the runs checked, 20 newest")
assert(th.seg[E1] and th.seg[0] == nil and c.inst["bad key"] == nil and c.inst.empty == nil, "keys and segments checked")
assert(c.live.Vuloo and c.live.Vuloo.s[E1] == 3 and c.live.Bad == nil and c.live["x|y"] == nil, "the clocks checked")
assert(c.last.Vuloo.r == 1789000000 and c.last.Vuloo.i == 3065 and c.last.Bad == nil and c.last.Old == nil, "the last runs checked")
local before = STUB.dump(AmisiaDB.runTimes)
RT.Loaded()
assert(STUB.dump(AmisiaDB.runTimes) == before, "a second load changes nothing")
AmisiaDB.runTimes = "junk"
RT.Loaded()
assert(type(AmisiaDB.runTimes.inst) == "table" and next(AmisiaDB.runTimes.inst) == nil, "junk replaced")

print("run times ok")
