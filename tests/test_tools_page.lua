-- The scan rows of the tools page (F-186, D-118): one row per task (Ausrüstung, Quests, NPCs, Sammler)
-- with its state in plain words, the bar while the total is known, percent and time left, only the
-- actions of the state, one scan at a time, the line "Nächster Schritt" by its priorities, and no tool
-- or file name or id number in any text of the page.
local SB, QS, NP = NS.ScanById, NS.QuestScan, NS.NpcScan
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

STUB.instance = { name = "Elwynn", type = "none", id = 0 }
-- the lists of the scans by id: quests 1-30, NPCs 10, 20, ..., 100 and the ranges 1000-1019, 2000-2009
rawset(NS, "SCAN_LISTS", { Q = "1.u", NA = "a,a,a,a,a,a,a,a,a,a", NB = { { 1000, 1019 }, { 2000, 2009 } } })
SB.Reset()

NS.Set("ui.expert", true)
NS.ShowPage("tools")
assert(NS.CurrentPage() == "tools")
local f = NS.PageFrame("tools")
local R = f.rowByKey
assert(R.gear and R.quests and R.npcs and R.collect and #f.rows == 4, "four rows")
assert(R.gear.name:GetText() == "Ausrüstung" and R.quests.name:GetText() == "Quests" and R.npcs.name:GetText() == "NPCs"
    and R.collect.name:GetText() == "Sammler")

-- the links a row shows now, in order
local ORDER = { "resume", "start", "retry", "stop", "toggle" }
local function shown(r)
    local out = {}
    for _, act in ipairs(ORDER) do
        if r.acts[act]:IsShown() then out[#out + 1] = r.acts[act]:GetText() end
    end
    return table.concat(out, ",")
end
-- every text of the scan part: no tool or file name, no "ID", no long number (D-118)
local function texts()
    local out = { f.next:GetText() or "" }
    for _, r in ipairs(f.rows) do
        out[#out + 1] = r.name:GetText() or ""
        out[#out + 1] = r.state:GetText() or ""
        for _, act in ipairs(ORDER) do out[#out + 1] = r.acts[act]:GetText() or "" end
    end
    return table.concat(out, " | ")
end
local function clean()
    local t = texts()
    assert(not t:find("%.py") and not t:find("%.lua") and not has(t, "tools/") and not has(t, "Data/"), "no file names: " .. t)
    assert(not t:find("%f[%w]IDs?%f[%W]") and not t:find("%d%d%d%d%d"), "no ids: " .. t)
    assert(not has(t, "Phase "), "plain words, no phases: " .. t)
end
local function refresh() NS.Refresh() end
-- every row in one line inside the page, its state text not cut
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
local function laidOut(what)
    for _, r in ipairs(f.rows) do
        local parts = { r.name, r.state }
        if r.bar:IsShown() then parts[#parts + 1] = r.bar end
        for _, act in ipairs(ORDER) do
            if r.acts[act]:IsShown() then parts[#parts + 1] = r.acts[act] end
        end
        Lay.row(what .. " " .. r.key, unpack(parts))
        Lay.fits(r.state)
    end
end
-- the page's own update while a scan runs (once a second, OnUpdate)
local function pageTick(seconds) f.ticker:GetScript("OnUpdate")(f.ticker, seconds or 1) end

---------------------------------------------------------------------------
-- nothing ran: every row says so, no bar, starts only; the collector is on with nothing waiting;
-- items without an answer from an earlier run: the retry link and the next step
---------------------------------------------------------------------------
refresh()
for _, key in ipairs({ "gear", "quests", "npcs" }) do
    assert(R[key].state:GetText() == "Noch nicht gelaufen.", key .. ": " .. R[key].state:GetText())
    assert(not R[key].bar:IsShown(), key)
    assert(shown(R[key]) == "Starten", key .. ": " .. shown(R[key]))
end
assert(R.collect.state:GetText() == "An: alles übernommen.", R.collect.state:GetText())
assert(shown(R.collect) == "Ausschalten", shown(R.collect))
assert(not f.next:IsShown() and f.next:GetText() == "", "nothing to do: the line says nothing")
clean()
laidOut("idle")

NS.ScanDB().retry = { 5, 6 }
refresh()
assert(shown(R.gear) == "Starten,Offene wiederholen (2)", shown(R.gear))
assert(f.next:IsShown() and has(f.next:GetText(), "Nächster Schritt:") and has(f.next:GetText(), "2 Items ohne Antwort: Offene wiederholen."), f.next:GetText())
AmisiaDB.scan.retry = {}

---------------------------------------------------------------------------
-- running: percent and time left of the range at its rate, the bar, Anhalten only on its row; the
-- other rows' starts greyed with the reason (one scan at a time)
---------------------------------------------------------------------------
NS.Set("tools.scanRate", 10)
for id = 1000, 1099 do STUB.item(id, "Item " .. id, 2) end
assert(NS.ScanStart(1000, 1099))
STUB.tick(1)
refresh()
assert(R.gear.state:GetText() == "Läuft: 10 %, etwa 9 s übrig", R.gear.state:GetText())
assert(R.gear.bar:IsShown() and math.abs(R.gear.bar.value - 0.1) < 0.001, tostring(R.gear.bar.value))
assert(shown(R.gear) == "Anhalten", shown(R.gear))
assert(shown(R.quests) == "Starten" and not R.quests.acts.start:IsEnabled() and R.quests.acts.start.blockedBy == "gear",
    "another scan runs: the quest start greyed")
assert(not R.npcs.acts.start:IsEnabled() and R.collect.acts.toggle:IsEnabled())
assert(not f.next:IsShown(), "nothing to do while a scan runs")
laidOut("running")
-- the greyed start says why under the mouse
R.quests.acts.start:GetScript("OnEnter")(R.quests.acts.start)
assert(GameTooltip:IsShown() and has(GameTooltip:GetText() or (GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()), "Es läuft schon ein Scan"))
R.quests.acts.start:GetScript("OnLeave")(R.quests.acts.start)
-- the scans by id refuse while the item scan runs, and the item scan while one of them runs
assert(QS.Start() == nil and NP.Start() == nil)
clean()

-- the page follows the scan once a second without a full refresh: texts and the bar only
STUB.tick(1)
local before = R.gear.state:GetText()
pageTick(0.5)
assert(R.gear.state:GetText() == before, "not before a second")
pageTick(0.5)
assert(R.gear.state:GetText() == "Läuft: 20 %, etwa 8 s übrig", R.gear.state:GetText())
assert(math.abs(R.gear.bar.value - 0.2) < 0.001)

---------------------------------------------------------------------------
-- paused: Angehalten with percent and time, Fortsetzen and Starten; new entries of this session wait
-- for the logout
---------------------------------------------------------------------------
for id = 1000, 1019 do STUB.fire("ITEM_DATA_LOAD_RESULT", id, true) end
R.gear.acts.stop:Click()
assert(not NS.ScanRunning())
assert(R.gear.state:GetText() == "Angehalten: 20 %, noch etwa 8 s", R.gear.state:GetText())
assert(R.gear.bar:IsShown() and shown(R.gear) == "Fortsetzen,Starten", shown(R.gear))
assert(R.quests.acts.start:IsEnabled(), "nothing runs: the other starts again")
assert(NS.ScanAddedCount() == 20, "twenty new lines this session: " .. NS.ScanAddedCount())
assert(has(f.next:GetText(), "20 neue Einträge seit dem Einloggen: ausloggen oder /reload, damit sie gespeichert werden."), f.next:GetText())
clean()
-- the widest row: paused with every link and a long time left
AmisiaDB.scan.retry = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
local savedTo = AmisiaDB.scan.to
AmisiaDB.scan.to = 2000000
refresh()
assert(shown(R.gear) == "Fortsetzen,Starten,Offene wiederholen (12)", shown(R.gear))
laidOut("paused")
AmisiaDB.scan.retry, AmisiaDB.scan.to = {}, savedTo
refresh()

-- Fortsetzen goes on where it was; the rest answered, the range is through: finished, items waiting
R.gear.acts.resume:Click()
assert(NS.ScanRunning() and AmisiaDB.scan.next >= 1020 and AmisiaDB.scan.from == 1000, "resumed from where it was")
STUB.tick(9)
for id = 1020, 1099 do STUB.fire("ITEM_DATA_LOAD_RESULT", id, true) end
STUB.tick(0.2)
assert(not NS.ScanRunning(), "through")
refresh()
assert(R.gear.state:GetText() == "Fertig: 100 neue Items warten auf die Übernahme.", R.gear.state:GetText())
assert(not R.gear.bar:IsShown() and shown(R.gear) == "Starten", shown(R.gear))

-- taken over (the trim of D-34 left nothing): "Fertig: alles übernommen."
AmisiaDB.scan.items, AmisiaDB.scan.count = {}, 0
refresh()
assert(R.gear.state:GetText() == "Fertig: alles übernommen.", R.gear.state:GetText())

-- a list run (the gear list): its own total, honest to the ids it asks
assert(NS.ScanList({ 1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009 }, "Test"))
STUB.tick(0.5)
for id = 1000, 1004 do STUB.fire("ITEM_DATA_LOAD_RESULT", id, true) end
refresh()
assert(R.gear.state:GetText() == "Läuft: 50 %, etwa 1 s übrig", R.gear.state:GetText())
R.gear.acts.stop:Click()
refresh()
assert(not R.gear.bar:IsShown() and shown(R.gear) == "Starten", "a stopped list run cannot resume: " .. shown(R.gear))

---------------------------------------------------------------------------
-- the scans by id: finished with names waiting, finished and taken over (the trim emptied the file:
-- "0 Namen gespeichert" before F-186), paused with percent
---------------------------------------------------------------------------
AmisiaDB.scan.npcs = { v = 2, loc = "deDE", a = 11, b = 2010, doneA = 1, doneB = 2, at = 2, n = 3,
    list = { [10] = "A", [20] = "B", [30] = "C" }, empty = "" }
AmisiaDB.scan.quests = { loc = "deDE", next = 31, done = 5, at = 5, n = 0, list = {}, none = "" }
refresh()
assert(R.npcs.state:GetText() == "Fertig: 3 neue Namen warten auf die Übernahme.", R.npcs.state:GetText())
assert(shown(R.npcs) == "", "a finished NPC scan offers no start: " .. shown(R.npcs))
assert(R.quests.state:GetText() == "Fertig: alles übernommen.", R.quests.state:GetText())
assert(shown(R.quests) == "Starten")
AmisiaDB.scan.npcs.list, AmisiaDB.scan.npcs.n = {}, 0
refresh()
assert(R.npcs.state:GetText() == "Fertig: alles übernommen.", R.npcs.state:GetText())

-- phase A paused at 40 %: plain words, the time at the setting's rate; phase B not begun: its estimate
AmisiaDB.scan.npcs = { v = 2, loc = "deDE", a = 5, at = 2, n = 4, list = { [10] = "A", [20] = "B", [30] = "C", [40] = "D" }, empty = "" }
refresh()
assert(R.npcs.state:GetText() == "Angehalten: 40 %, noch etwa 1 s", R.npcs.state:GetText())
assert(R.npcs.bar:IsShown() and shown(R.npcs) == "Fortsetzen", shown(R.npcs))
AmisiaDB.scan.npcs.a, AmisiaDB.scan.npcs.doneA = 11, 3
refresh()
assert(R.npcs.state:GetText() == "Bekannte NPCs fertig; die Suche nach neuen dauert etwa 12 s.", R.npcs.state:GetText())
assert(not R.npcs.bar:IsShown() and shown(R.npcs) == "Fortsetzen")
AmisiaDB.scan.npcs.b = 1010
refresh()
assert(R.npcs.state:GetText() == "Suche nach neuen NPCs angehalten: 33 %, noch etwa 8 s", R.npcs.state:GetText())
clean()
laidOut("npc search paused")

-- the quest scan paused in an instance: the next step says what to do, before anything else
AmisiaDB.scan.quests = nil
local known = {}
C_QuestLog.HaveQuestData = function() return false end
C_QuestLog.RequestLoadQuestByID = function(id) known[#known + 1] = id end
C_QuestLog.GetTitleForQuestID = function() return nil end
R.quests.acts.start:Click()
assert(QS.Running(), "the row's start starts the quest scan")
assert(shown(R.quests) == "Anhalten")
STUB.instance = { name = "Deadmines", type = "party", id = 36 }
STUB.tick(0.2)
assert(not QS.Running(), "paused by the instance")
refresh()
assert(has(f.next:GetText(), "Ein Scan hielt in der Instanz an: außerhalb von Instanzen in seiner Zeile fortsetzen."), f.next:GetText())
assert(has(R.quests.state:GetText(), "Angehalten: "), R.quests.state:GetText())
STUB.instance = { name = "Elwynn", type = "none", id = 0 }
refresh()
assert(has(f.next:GetText(), "Ein Scan hielt in der Instanz an: in seiner Zeile fortsetzen."), f.next:GetText())
R.quests.acts.resume:Click()
assert(QS.Running())
refresh()
assert(not f.next:IsShown(), "running again")
R.quests.acts.stop:Click()
refresh()
assert(has(f.next:GetText(), "105 neue Einträge"), "stopped by hand: the session's entries next: " .. f.next:GetText())
clean()

---------------------------------------------------------------------------
-- the collector: on and off by its link (the setting stays the truth), its count
---------------------------------------------------------------------------
NS.NoteItem(1000, "Auktionshaus")
refresh()
assert(R.collect.state:GetText() == "An: 1 Items mit Quelle warten auf die Übernahme.", R.collect.state:GetText())
R.collect.acts.toggle:Click()
assert(NS.Get("tools.collect") == false)
assert(R.collect.state:GetText() == "Aus: 1 Items mit Quelle warten auf die Übernahme." and shown(R.collect) == "Einschalten", shown(R.collect))
AmisiaDB.scan.sources, AmisiaDB.scan.sourceCount = {}, 0
refresh()
assert(R.collect.state:GetText() == "Aus.", R.collect.state:GetText())
R.collect.acts.toggle:Click()
assert(NS.Get("tools.collect") == true and R.collect.state:GetText() == "An: alles übernommen.")
clean()

-- the slash commands do what the rows do
NS.ScanCommand("quests")
assert(QS.Running())
refresh()
assert(shown(R.quests) == "Anhalten" and not R.gear.acts.start:IsEnabled())
NS.ScanCommand("stop")
assert(not QS.Running())

NS.Reset("ui.expert")
print("tools page: rows, states, percent and time, one scan at a time, next step, plain words")
