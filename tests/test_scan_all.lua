-- "Alles Fehlende scannen" (F-188, D-120, Collect/ScanAll.lua): the queue over the gear scan, the quest
-- scan, phase A of the NPC scan and the items without an answer at the end; finished scans skipped (by
-- their stamp: client build and the lists' build), a pause in an instance and the resume outside by
-- itself, combat and the lockdown, a stop by hand ends it, nothing open, the plan line and the next step
-- of the tools page, the new-build line (once a session, expert mode only, switchable), /reload.
local SB, QS, NP, SA = NS.ScanById, NS.QuestScan, NS.NpcScan, NS.ScanAll
assert(SA, "the queue loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function msgsHave(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local function clearMsgs() for i = #STUB.messages, 1, -1 do STUB.messages[i] = nil end end

local OUT = { name = "Elwynn", type = "none", id = 0 }
local DUNGEON = { name = "Deadmines", type = "party", id = 36 }
STUB.instance = OUT

-- the client build is 1.60.1.70205 (the stub); the lists come from the same build
local function lists(client)
    rawset(NS, "SCAN_LISTS", { client = client, Q = "1.9", NA = "a,a,a", NB = { { 1000, 1009 } } })
    SB.Reset()
end
lists("1.60.1.70205")
assert(SB.Build() == "1.60.1.70205" and SB.Stamp() == "1.60.1.70205/1.60.1.70205", SB.Stamp())
assert(SB.BuildNumber("1.60.1.70938") == 70938 and SB.BuildNumber(nil) == nil)

-- the gear planner's list: five items, one of them the client never names (it goes to the retries)
NS.GearScanIDs = function() return { 500, 501, 502, 503, 504 } end
for id = 500, 503 do STUB.item(id, "Item " .. id, 3) end
local function answerItems()
    for id = 500, 504 do STUB.fire("ITEM_DATA_LOAD_RESULT", id, true) end
end

-- the quests 1-10 answer after 0.3 s
local qAsked = 0
C_QuestLog.HaveQuestData = function() return false end
C_QuestLog.RequestLoadQuestByID = function(id)
    qAsked = qAsked + 1
    C_Timer.After(0.3, function() STUB.fire("QUEST_DATA_LOAD_RESULT", id, true) end)
end
C_QuestLog.GetTitleForQuestID = function(id) return "Quest " .. id end
C_QuestLog.GetQuestDifficultyLevel = function() return 10 end
C_QuestLog.GetSuggestedGroupSize = function() return 0 end

-- the NPCs 10, 20, 30 have names; the probe's verdict is there
C_TooltipInfo.GetHyperlink = function(link)
    local id = tonumber(link:match("^unit:Creature%-0%-0%-0%-0%-(%d+)%-0000000000$"))
    if id and id <= 30 then return { lines = { { leftText = "Npc " .. id }, { leftText = "Stufe 60" } } } end
    return { lines = {} }
end
SB.SaveProbe({ npc = "ok" })

NS.Set("tools.scanRate", 10)
NS.Set("tools.questRate", 20)

---------------------------------------------------------------------------
-- nothing ran: all three open, in order; the plan line says so
---------------------------------------------------------------------------
local open = SA.Open()
assert(table.concat(open, ",") == "gear,quests,npcs", table.concat(open, ","))
assert(SA.PlanText() == "Noch offen: Ausrüstung, Quests, NPCs.", SA.PlanText())
assert(not SA.Active() and SA.NextStep() == nil)

-- the order: gear first, the plan names what comes after
NS.ScanCommand("all")
assert(SA.Active() and NS.ScanRunning(), "the gear scan runs first")
assert(msgsHave("Alles Fehlende scannen: Ausrüstung, Quests, NPCs, nacheinander."), STUB.messages[#STUB.messages])
assert(SA.PlanText() == "Alles Fehlende: Ausrüstung läuft, danach Quests, NPCs.", SA.PlanText())
assert(SA.Start() == nil, "a second start is refused")

-- the gear list through: stamped; item 504 had no answer: it waits for the retries at the end
STUB.tick(1)
answerItems()
assert(not NS.ScanRunning(), "the gear list is through")
assert(AmisiaDB.scan.gear == SB.Stamp(), tostring(AmisiaDB.scan.gear))
assert(#AmisiaDB.scan.retry == 1 and AmisiaDB.scan.retry[1] == 504)
assert(SA.PlanText() == "Alles Fehlende: Quests wartet, danach NPCs, Offene Items.", SA.PlanText())
assert(SA.NextStep() == "Alles Fehlende geht gleich von selbst weiter.", tostring(SA.NextStep()))
STUB.tick(1.1)
assert(QS.Running(), "the quests next, by themselves")
assert(SA.PlanText() == "Alles Fehlende: Quests läuft, danach NPCs, Offene Items.", SA.PlanText())

---------------------------------------------------------------------------
-- an instance stops the quest scan; the queue waits and goes on outside, a few seconds later
---------------------------------------------------------------------------
STUB.tick(0.2)
STUB.instance = DUNGEON
STUB.tick(0.2)
assert(not QS.Running() and SA.Active(), "paused by the instance, the queue stays on")
assert(SA.NextStep() == "Alles Fehlende geht außerhalb der Instanz von selbst weiter.", tostring(SA.NextStep()))
assert(SA.PlanText() == "Alles Fehlende: Quests wartet, danach NPCs, Offene Items.", SA.PlanText())
-- inside nothing starts, whatever fires
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(10)
assert(not QS.Running(), "never inside an instance")
-- out: a few seconds after the zone change it goes on where it was
STUB.instance = OUT
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(SA.DELAY - 1)
assert(not QS.Running(), "not at once")
STUB.tick(1.1)
assert(QS.Running(), "goes on by itself outside")
local q = AmisiaDB.scan.quests
assert(q.next > 1, "resumed, not from the start")

---------------------------------------------------------------------------
-- combat when the next step wants to start: it waits for the end of the fight
---------------------------------------------------------------------------
for _ = 1, 50 do
    if not QS.Running() then break end
    STUB.tick(0.1)
end
assert(q.done and q.stamp == SB.Stamp(), "the quests through and stamped")
STUB.combat = true
STUB.tick(1.1)
assert(not NP.Running(), "no start in combat")
assert(SA.NextStep() == "Alles Fehlende geht nach dem Kampf von selbst weiter.", tostring(SA.NextStep()))
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(SA.DELAY + 0.1)
assert(NP.Running() == "A", "phase A after the fight: " .. tostring(NP.Running()))
assert(SA.PlanText() == "Alles Fehlende: NPCs läuft, danach Offene Items.", SA.PlanText())

-- phase A through (never phase B), then the retries at the end, then the queue is done
STUB.tick(3)
assert(not NP.Running() and AmisiaDB.scan.npcs.doneA and not AmisiaDB.scan.npcs.doneB, "phase A only")
assert(AmisiaDB.scan.npcs.stamp == SB.Stamp())
STUB.tick(1.1)
assert(NS.ScanRunning(), "the retries at the end")
assert(SA.PlanText() == "Alles Fehlende: Offene Items läuft, danach ist alles gescannt.", SA.PlanText())
STUB.tick(0.2)
STUB.fire("ITEM_DATA_LOAD_RESULT", 504, true)
assert(not NS.ScanRunning())
STUB.tick(1.1)
assert(not SA.Active(), "done")
assert(msgsHave("Alles Fehlende scannen: fertig."))

---------------------------------------------------------------------------
-- nothing open: the plan says so, a start is refused; the next step back to the session's entries
---------------------------------------------------------------------------
AmisiaDB.scan.retry = {}
assert(#SA.Open() == 0, table.concat(SA.Open(), ","))
assert(SA.PlanText() == "Nichts offen.")
local ok, why = SA.Start()
assert(not ok and why == "Nichts offen.")

-- a finished scan is skipped: only the quests open (as after a release with new lists of quests)
AmisiaDB.scan.quests.done = nil
AmisiaDB.scan.quests.next = 4
assert(table.concat(SA.Open(), ",") == "quests")

---------------------------------------------------------------------------
-- a stop by hand ends the queue: nothing goes on by itself afterwards
---------------------------------------------------------------------------
assert(SA.Start() and QS.Running())
NS.ScanCommand("stop")
assert(not QS.Running() and not SA.Active(), "the stop ends the queue")
assert(msgsHave("Alles Fehlende scannen: angehalten."))
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(SA.DELAY + 1)
assert(not QS.Running(), "nothing restarts against the player's will")
-- also the stop of the scan alone (its row's "Anhalten")
assert(SA.Start() and QS.Running())
QS.Stop()
assert(not SA.Active())
-- and while the queue waits in an instance (no scan runs): /amisia scan stop ends it too
STUB.instance = DUNGEON
assert(SA.Start() and SA.Active() and not QS.Running(), "a start inside waits")
assert(SA.NextStep() == "Alles Fehlende geht außerhalb der Instanz von selbst weiter.")
NS.ScanCommand("all stop")
assert(not SA.Active())
STUB.instance = OUT
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(SA.DELAY + 1)
assert(not QS.Running())

-- a scan started by hand: the queue does not start beside it
assert(QS.Start())
ok, why = SA.Start()
assert(not ok and has(why, "Erst den laufenden Scan anhalten"), tostring(why))
QS.Stop()

-- the lockdown of an encounter: the queue waits, ENCOUNTER_END brings it on
STUB.restricted = true
assert(SA.Start() and not QS.Running(), "no start in the lockdown")
assert(SA.NextStep() == "Alles Fehlende geht nach der Kampfsperre von selbst weiter.", tostring(SA.NextStep()))
STUB.restricted = false
STUB.fire("ENCOUNTER_END")
STUB.tick(SA.DELAY + 0.1)
assert(QS.Running(), "after the lockdown")
NS.ScanCommand("stop")
assert(not SA.Active())

---------------------------------------------------------------------------
-- a new client build: the stamps of the old one make every scan open again; the quests ask the whole
-- list again, phase A too; phase B stays done
---------------------------------------------------------------------------
STUB.tick(5)
AmisiaDB.scan.quests.done, AmisiaDB.scan.quests.next = time(), 11
local old = "1.60.1.70100/1.60.1.70100"
AmisiaDB.scan.gear, AmisiaDB.scan.quests.stamp, AmisiaDB.scan.npcs.stamp = old, old, old
AmisiaDB.scan.npcs.doneB = time()
assert(table.concat(SA.Open(), ",") == "gear,quests,npcs", table.concat(SA.Open(), ","))
assert(QS.StartOpen() and AmisiaDB.scan.quests.next <= 3, "the quests from the start: " .. AmisiaDB.scan.quests.next)
QS.Stop()
STUB.tick(1)
assert(NP.StartOpen() and NP.Running() == "A", "phase A again")
NP.Stop()
assert(AmisiaDB.scan.npcs.doneB, "phase B stays done")

---------------------------------------------------------------------------
-- the new-build line: the client newer than the lists, the scans last finished under another build;
-- once a session, expert mode only, switchable; nothing starts
---------------------------------------------------------------------------
lists("1.60.1.70100")
AmisiaDB.scan.gear = "1.60.1.70100/1.60.1.70100"
assert(SA.NewBuild())
clearMsgs()
assert(not SA.Notice(), "no expert mode: no line")
assert(#STUB.messages == 0)
NS.Set("ui.expert", true)
NS.Set("tools.scanNotice", false)
assert(not SA.Notice(), "switched off")
NS.Set("tools.scanNotice", true)
assert(SA.Notice())
assert(msgsHave("Neuer Spiel-Build: es gibt Neues zu scannen (Gilde > Werkzeuge, \"Alles Fehlende scannen\")."), STUB.messages[1])
assert(not SA.Notice(), "once a session")
assert(not SA.Active() and not QS.Running() and not NS.ScanRunning(), "nothing starts by itself")
-- the lists as new as the client, or no finished scan under another build: no line
lists("1.60.1.70205")
assert(not SA.NewBuild())
lists("1.60.1.70100")
AmisiaDB.scan.gear, AmisiaDB.scan.quests.stamp, AmisiaDB.scan.npcs.stamp = nil, nil, nil
assert(not SA.NewBuild(), "never finished: nothing new to say")

-- scans finished before the stamps came count as this build's (adopted at login)
AmisiaDB.scan.done, AmisiaDB.scan.quests.done = time(), time()
SA.Adopt()
assert(AmisiaDB.scan.gear == SB.Stamp() and AmisiaDB.scan.quests.stamp == SB.Stamp())
lists("1.60.1.70205")

---------------------------------------------------------------------------
-- /reload: the queue lives for the session only; the page offers what is still open
---------------------------------------------------------------------------
AmisiaDB.scan.gear = SB.Stamp()
AmisiaDB.scan.quests.done, AmisiaDB.scan.quests.stamp, AmisiaDB.scan.quests.next = nil, nil, 4
assert(SA.Start() and QS.Running())
local saved = false
for k in pairs(AmisiaDB.scan) do if k == "all" or k == "queue" then saved = true end end
assert(not saved and AmisiaDB.scanAll == nil, "nothing of the queue is saved")
QS.Stop()
assert(SA.PlanText() == "Noch offen: Quests, NPCs.", SA.PlanText())

NS.Reset("ui.expert")
print("scan all: order, skip finished, retries last, instance pause and resume, combat, stop by hand, nothing open, new build line, reload")
