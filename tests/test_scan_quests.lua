-- The quest scan by id (Collect/ScanQuests.lua, D-104): batches at the rate, the answer event, the
-- timeout and the second ask, placeholder titles, the type of Collect/QuestTags.lua, resume, pause,
-- the stop after 50 unanswered ids, combat and instances, the status line and the tools page.
local SB, QS = NS.ScanById, NS.QuestScan
assert(SB and QS, "the quest scan loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

STUB.instance = { name = "Elwynn", type = "none", id = 0 }

-- the list: quests 1-30 and 101-130 (60 ids)
local function lists(q) rawset(NS, "SCAN_LISTS", { Q = q or "1.u,1z.u", NA = "", NB = {} }); SB.Reset() end
lists()
assert(#SB.List("Q") == 60 and SB.List("Q")[31] == 101, "the list expands its ranges")

-- the client: titles for the known quests, an answer per request after 0.3 s
local W = {}
local function client(opts)
    opts = opts or {}
    W = { asked = {}, known = opts.known or {}, silent = opts.silent, placeholder = opts.placeholder or {} }
    C_QuestLog.HaveQuestData = function(id) return W.loaded and W.loaded[id] or false end
    C_QuestLog.RequestLoadQuestByID = function(id)
        W.asked[#W.asked + 1] = id
        if W.silent then return end
        C_Timer.After(0.3, function() STUB.fire("QUEST_DATA_LOAD_RESULT", id, W.known[id] ~= nil or W.placeholder[id] ~= nil) end)
    end
    C_QuestLog.GetTitleForQuestID = function(id)
        if W.placeholder[id] then return W.placeholder[id] end
        return W.known[id] and W.known[id].title or nil
    end
    C_QuestLog.GetQuestDifficultyLevel = function(id) return W.known[id] and W.known[id].level or 0 end
    C_QuestLog.GetQuestTagInfo = function(id) return W.known[id] and W.known[id].tag and { tagID = W.known[id].tag } or nil end
    C_QuestLog.GetSuggestedGroupSize = function(id) return W.known[id] and W.known[id].group or 0 end
end

local known = {}
for i = 1, 30 do known[i] = { title = "Quest " .. i, level = 10 + i } end
known[5] = { title = "Die Verteidigung", level = 22, tag = 81 }   -- dungeon
known[6] = { title = "Gemeinsam", level = 30, group = 3 }         -- group (suggested 3)
for i = 101, 130 do known[i] = { title = "Spät " .. i, level = 50 } end
client({ known = known })

-- start: the rate of the setting (20 per second: two per tick)
assert(NS.Get("tools.questRate") == 20)
assert(QS.Start())
assert(QS.Running() and SB.Busy() == "quests")
assert(QS.Start() == nil, "a second start is refused")
assert(has(lastMsg(), "Quest-Scan gestartet: 60 von 60"), lastMsg())
STUB.tick(0.1)
assert(#W.asked == 2, "two per tick at 20 per second: " .. #W.asked)
STUB.tick(0.4)
local q = AmisiaDB.scan.quests
assert(q.loc == "deDE")
assert(q.list[1] == "Quest 1\t11" and q.list[2] == "Quest 2\t12", tostring(q.list[1]))
STUB.tick(1)
assert(q.list[5] == "Die Verteidigung\t22\t0\tD", q.list[5])
assert(q.list[6] == "Gemeinsam\t30\t0\tG\t3", q.list[6])

-- pause and resume: next stays where it was, nothing is asked twice
QS.Command("stop")
assert(not QS.Running() and not SB.Busy())
local at = q.next
local n = #W.asked
STUB.tick(1)
assert(#W.asked == n, "nothing asked while paused")
assert(has(QS.Status(), "angehalten"), QS.Status())
QS.Command("")
assert(QS.Running() and q.next == at)
STUB.tick(10)
assert(not QS.Running(), "done")
assert(q.done and q.n == 60 and q.next == 61, q.n)
assert(has(QS.Status(), "fertig: 60 Quests"), QS.Status())

-- placeholder titles and a missing quest: asked again after the timeout, then remembered as without answer
AmisiaDB.scan.quests = nil
lists("1.3")   -- 1, 2, 3
client({ known = { [1] = { title = "Eins", level = 5 } }, placeholder = { [2] = "<Platzhalter>" } })
W.known[3] = nil
assert(QS.Start())
STUB.tick(0.5)
q = AmisiaDB.scan.quests
assert(q.list[1] == "Eins\t5" and not q.list[2] and not q.list[3])
assert(q.none == "3", "a quest the server denies: " .. q.none)
STUB.tick(QS.TIMEOUT + 0.2)
assert(#W.asked == 3 + 1, "the placeholder is asked a second time: " .. #W.asked)
STUB.tick(QS.TIMEOUT + 0.5)
assert(not q.list[2] and q.none == "2-3" or q.none == "3,2", q.none)
assert(not QS.Running())

-- the client never answers: after the first 50 ids one line, and the next start asks them again
AmisiaDB.scan.quests = nil
lists("1.1o")   -- 1-60
client({ silent = true })
assert(QS.Start())
for _ = 1, 30 do STUB.tick(1) end
assert(not QS.Running(), "ended")
assert(has(lastMsg(), "Der Client beantwortet Quest-Abfragen nicht: Quest-Scan beendet."), lastMsg())
q = AmisiaDB.scan.quests
assert(q.next == 1 and q.none == "", "the run does not count: " .. q.next .. " " .. q.none)
assert(not SB.Busy())

-- timeouts slow the scan down
client({ silent = true })
assert(QS.Start())
STUB.tick(0.1)
local before = #W.asked
-- answer some so the 50-stop does not end it
W.silent = false
W.known = { [1] = { title = "Eins", level = 1 } }
STUB.fire("QUEST_DATA_LOAD_RESULT", 1, true)
W.silent = true
for _ = 1, 9 do STUB.tick(1) end
assert(#W.asked > before)
QS.Stop()

-- combat waits, an instance pauses
AmisiaDB.scan.quests = nil
lists("1.u")
client({ known = known })
assert(QS.Start())
STUB.combat = true
n = #W.asked
STUB.tick(1)
assert(#W.asked == n and QS.Running(), "waits in combat")
STUB.combat = false
STUB.tick(0.2)
assert(#W.asked > n)
STUB.instance = { name = "Deadmines", type = "party", id = 36 }
STUB.tick(0.2)
assert(not QS.Running() and has(lastMsg(), "pausiert in der Instanz"), lastMsg())
assert(QS.Start() == nil, "no start in an instance")
STUB.instance = { name = "Elwynn", type = "none", id = 0 }

-- a scan waits for the other: the item scan blocks the quest scan
assert(NS.ScanStart(1, 5))
local ok, why = QS.Start()
assert(not ok and has(why, "Erst den laufenden Scan anhalten"), why)
NS.ScanCommand("stop")
assert(not NS.ScanRunning())

-- another language while lines of the first wait: refused
AmisiaDB.scan.quests = { loc = "enUS", next = 3, list = { [1] = "One\t1" } }
ok, why = QS.Start()
assert(not ok and has(why, "1 Quests in enUS"), why)
AmisiaDB.scan.quests = nil

-- a client without the functions
local req = C_QuestLog.RequestLoadQuestByID
C_QuestLog.RequestLoadQuestByID = nil
ok, why = QS.Start()
assert(not ok and has(why, "keine Quests nachladen"), why)
C_QuestLog.RequestLoadQuestByID = req

-- the objectives only where the probe found the quest tooltip readable
AmisiaDB.scan.quests = nil
lists("1.1")
client({ known = { [1] = { title = "Eins", level = 5 } } })
C_TooltipInfo.GetHyperlink = function(link)
    if link == "quest:1" then return { lines = { { leftText = "Eins" }, { leftText = "Töte 10 Kobolde." } } } end
end
SB.SaveProbe({ questTip = "ok", quest = "ok" })
assert(SB.Verdict("questTip") == "ok")
assert(QS.Start())
STUB.tick(1)
assert(AmisiaDB.scan.quests.list[1] == "Eins\t5\t0\t\t0\tTöte 10 Kobolde.", AmisiaDB.scan.quests.list[1])
AmisiaDB.probe = nil

-- rewards by id (layout 2): only where the probe found them; an older scan's lines are asked again
AmisiaDB.scan.quests = { loc = "deDE", next = 4, n = 1, list = { [1] = "Alt\t5" } }   -- a scan of 2.74.0 (no v)
lists("1.3")
client({ known = { [1] = { title = "Eins", level = 5 }, [2] = { title = "Zwei", level = 7 }, [3] = { title = "Drei", level = 9 } } })
local RW = { [1] = { items = { { 2001, 1 }, { 2002, 5 } }, choices = { 3001, 3002 }, money = 150, xp = 400 },
             [2] = { items = {}, choices = { 3003 }, money = 0, xp = 0 }, [3] = { items = {}, choices = {}, money = 0, xp = 90 } }
_G.GetNumQuestLogRewards = function(qid) return #(RW[qid] or { items = {} }).items end
_G.GetQuestLogRewardInfo = function(i, qid) local it = RW[qid].items[i]; return "x", 1, it[2], 2, true, it[1] end
_G.GetNumQuestLogChoices = function(qid, cur) assert(cur == false, "choices without currencies"); return #(RW[qid] or { choices = {} }).choices end
_G.GetQuestLogChoiceInfo = function(i, qid) local id = RW[qid].choices[i]; return "x", 1, 1, 2, true, id end
_G.GetQuestLogRewardMoney = function(qid) return RW[qid] and RW[qid].money or 0 end
C_QuestLog.GetQuestLogRewardXP = function(qid) return RW[qid] and RW[qid].xp or 0 end
-- without a verdict: the scan stays as it was, the old lines stay
assert(QS.Start())
assert(not (QS.Parts()), "no rewards without the probe")
QS.Stop()
assert(AmisiaDB.scan.quests.list[1] == "Alt\t5" and AmisiaDB.scan.quests.v == nil, "nothing asked again without rewards")
SB.SaveProbe({ quest = "ok", questReward = "ok", questXP = "ok" })
AmisiaDB.questxp = { [3] = { 120, 20 } }   -- a quest seen already keeps its XP
STUB.level = 30
assert(QS.Start())
q = AmisiaDB.scan.quests
assert(q.v == 2 and q.next <= 2 and q.list[1] == nil, "layout 2: the older lines are asked again")
STUB.tick(2)
assert(q.list[1] == "Eins\t5\t0\t\t0\t\t2001,2002*5\t3001,3002\t150\t400", q.list[1])
assert(q.list[2] == "Zwei\t7\t0\t\t0\t\t\t3003", q.list[2])
assert(q.list[3] == "Drei\t9\t0\t\t0\t\t\t\t\t90", q.list[3])
assert(AmisiaDB.questxp[1][1] == 400 and AmisiaDB.questxp[3][1] == 120, "XP fills only gaps")
assert(not AmisiaDB.questxp[2], "no XP: nothing kept")
assert(AmisiaDB.questxp[1][2] == 30, "kept at the level it was seen at")
STUB.level = nil
assert(QS.WithoutRewards(q.list[1]) == "Eins\t5", QS.WithoutRewards(q.list[1]))
-- the client ignores the quest id: five quests in a row with the same items stop the rewards of the run
AmisiaDB.scan.quests = nil
lists("1.8")
local k8 = {}
for i = 1, 8 do k8[i] = { title = "Q" .. i, level = 10 } end
client({ known = k8 })
for i = 1, 8 do RW[i] = { items = { { 2001, 1 } }, choices = {}, money = 0, xp = 0 } end
assert(QS.Start())
STUB.tick(3)
q = AmisiaDB.scan.quests
for i = 1, 8 do assert(not q.list[i]:find("2001", 1, true), "no reward kept: " .. q.list[i]) end
assert(has(table.concat(STUB.messages, "\n"), "dieselbe Belohnung"), "said once")
-- a client without the reward functions reads no rewards even with the verdict
for _, name in ipairs({ "GetNumQuestLogRewards", "GetQuestLogRewardInfo", "GetNumQuestLogChoices", "GetQuestLogChoiceInfo", "GetQuestLogRewardMoney" }) do _G[name] = nil end
C_QuestLog.GetQuestLogRewardXP = nil
AmisiaDB.scan.quests = nil
lists("1.1")
client({ known = { [1] = { title = "Eins", level = 5 } } })
assert(QS.Start())
STUB.tick(1)
assert(AmisiaDB.scan.quests.list[1] == "Eins\t5", AmisiaDB.scan.quests.list[1])
AmisiaDB.probe = nil

-- the slash command and the stop of every scan
AmisiaDB.scan.quests = nil
lists("1.u")
client({ known = known })
NS.ScanCommand("quests")
assert(QS.Running())
NS.ScanCommand("stop")
assert(not QS.Running())

-- the tools page shows the progress line
NS.Set("ui.expert", true)
NS.ShowPage("tools")
assert(NS.CurrentPage() == "tools")
local f = NS.PageFrame("tools")
assert(has(f.state:GetText(), "Quest-Scan fertig: 30 Quests") or has(f.state:GetText(), "Quest-Scan angehalten"), f.state:GetText())
assert(has(f.state:GetText(), "NPC-Scan: noch nicht gelaufen"), f.state:GetText())
-- the links of the head row start the scans
local labels = {}
for _, b in ipairs(f.buttons) do labels[#labels + 1] = b:GetText() end
assert(table.concat(labels, ","):find("Quest-Scan,NPC-Scan,Anhalten", 1, true), table.concat(labels, ","))
f.buttons[4]:Click()
assert(QS.Running(), "the link Quest-Scan starts it")
f.buttons[6]:Click()
assert(not QS.Running(), "Anhalten stops it")
NS.Reset("ui.expert")
print("quest scan: batches, answers, placeholders, timeouts, resume, pause, the 50-stop, combat, instance")
