-- /amisia selbsttest daten (Core/SelfTestData.lua, D-104) with a stubbed client: NPC names by id through
-- C_TooltipInfo and the own tooltip (at once, late, never), ten in a row, quests by id with the answer
-- event, the quest tooltip, the model frame, the other sources; the verdicts in the report and in
-- AmisiaDB.probe; secret values; no start in combat or a lockdown; nothing sent.
local ST = NS.SelfTest
local DT = ST.Data
local SB = NS.ScanById
assert(DT and DT.Start, "the data probe loads")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function report() return ST.Frame().area.box:GetText() end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

STUB.instance = { name = "Elwynn", type = "none", id = 0 }
-- a trainer this client opened: a seen NPC
AmisiaDB.trainers = { [5511] = { t = 100, n = "Therum Deepforge", p = "1453:5000:5000", s = {} } }

-- the client: per NPC a name after "after" asks of each route (nil: never)
local W
local function client(opts)
    opts = opts or {}
    W = { count = {}, after = opts.after or function() return 0 end, secret = opts.secret, quests = opts.quests or {}, asked = {}, sent = 0 }
    C_TooltipInfo.GetHyperlink = function(link)
        local id = tonumber(link:match("^unit:Creature%-0%-0%-0%-0%-(%d+)%-"))
        if id then
            W.count[id] = (W.count[id] or 0) + 1
            local after = W.after(id)
            if after == nil or W.count[id] <= after then return { lines = {} } end
            local name = "Name " .. id
            if W.secret then STUB.secret[name] = true end
            return { lines = { { leftText = name }, { leftText = "Stufe 30" } } }
        end
        local qid = tonumber(link:match("^quest:(%d+)$"))
        local q = qid and W.quests[qid]
        if q then return { lines = { { leftText = q.title }, { leftText = "Bringt 8 Zähne." }, { leftText = "Stufe 25" } } } end
        return { lines = {} }
    end
    C_QuestLog.HaveQuestData = function(id) return false end
    C_QuestLog.RequestLoadQuestByID = function(id)
        W.asked[#W.asked + 1] = id
        C_Timer.After(0.5, function() STUB.fire("QUEST_DATA_LOAD_RESULT", id, W.quests[id] ~= nil) end)
    end
    C_QuestLog.GetTitleForQuestID = function(id) return W.quests[id] and W.quests[id].title or nil end
    C_QuestLog.GetQuestDifficultyLevel = function(id) return W.quests[id] and 25 or 0 end
    C_QuestLog.GetQuestTagInfo = function(id) return W.quests[id] and { tagID = 81, tagName = "Dungeon" } or nil end
end

-- model frames with SetCreature: a model only for creatures the client has seen
local realCreate = _G.CreateFrame
local models = {}
_G.CreateFrame = function(kind, ...)
    local f = realCreate(kind, ...)
    if kind == "PlayerModel" then
        models[#models + 1] = f
        f.SetCreature = function(self, id) self.creature = id end
        f.GetModelFileID = function(self) return self.creature == 5511 and 123456 or nil end
        f.GetDisplayInfo = function(self) return self.creature == 5511 and 777 or 0 end
    end
    return f
end

-- quests: the data's dungeon quests known, the Drowned City's too
local dq = NS.Data("DUNGEON_QUESTS")
local qids = {}
for qid in pairs(dq.Q) do qids[#qids + 1] = qid end
table.sort(qids)
local quests = { [qids[1]] = { title = "Die erste" }, [qids[2]] = { title = "Die zweite" }, [95775] = { title = "Die Ertrunkene Stadt" } }

-- 1) everything answers: old NPCs at once, the new ones on the second ask (after 1 s)
local NEW = { [258905] = true, [258924] = true, [260042] = true }
client({ after = function(id) return NEW[id] and 1 or 0 end, quests = quests })
local sent = #(STUB.sent or {})
DT.Start()
assert(has(lastMsg(), "Datenprüfung läuft"), lastMsg())
assert(#W.asked >= 4, "quests requested: " .. #W.asked)
STUB.tick(6)
local text = report()
assert(has(text, "Amisia-Datenprüfung"), text:sub(1, 200))
assert(has(text, "5511 gesehen (C_TooltipInfo): sofort"), text)
assert(has(text, "258905 neu in Forever (C_TooltipInfo): nach 1 s"), text)
assert(has(text, "\"Name 5511\" | \"Stufe 30\""), "the first lines are in the report")
assert(has(text, "Die Ertrunkene Stadt"), "the Forever quest")
assert(has(text, "QUEST_DATA_LOAD_RESULT true nach 0.5 s"), text)
assert(has(text, "9999990 gibt es nicht"))
assert(has(text, "SetCreature(5511) gesehen") and has(text, "GetModelFileID 123456"), text)
assert(has(text, "NPC per Nummer: geht (sofort) (Weg: C_TooltipInfo)"), text)
assert(has(text, "Neue Forever-NPCs per Nummer: geht (nach einer Wartezeit)"), text)
assert(has(text, "Quest per Nummer: geht (sofort)"))
assert(has(text, "Quest-Tooltip (Ziele): geht (sofort)"))
assert(has(text, "Modell per Nummer: nur gesehene"), text)
assert(has(text, "10 hintereinander: 10 sofort mit Namen"), text)
local p = AmisiaDB.probe
assert(p and p.npc == "ok" and p.npcNew == "retry" and p.quest == "ok" and p.questTip == "ok" and p.route == "info", "verdicts saved")
assert(p.model == "retry" and p.burst == 0 and p.build == "1.60.1.70205" and p.src == "probe")
assert(SB.Verdict("npc") == "ok")
assert(has(lastMsg(), "Datenprüfung: NPC per Nummer geht (sofort)"), lastMsg())
assert(#(STUB.sent or {}) == sent, "nothing sent")
-- the probe never touched GameTooltip
assert(not GameTooltip.shownLink)

-- 2) nothing answers: the verdict "geht nicht" for NPCs, quests and the tooltip
STUB.messages = {}
client({ after = function() return nil end, quests = {} })
DT.Start()
STUB.tick(6)
text = report()
assert(has(text, "NPC per Nummer: geht nicht"), text)
assert(has(text, "Quest per Nummer: geht nicht"))
assert(AmisiaDB.probe.npc == "none" and AmisiaDB.probe.quest == "none")
-- the NPC scan reads the verdict and ends with one line
local ok, why = NS.NpcScan.Start()
assert(not ok and why == "Der Client nennt keine NPC-Namen per Nummer: NPC-Scan beendet.")

-- 3) secret names count as none and show as <geheim>
client({ secret = true, quests = quests })
DT.Start()
STUB.tick(6)
text = report()
assert(has(text, "<geheim>") and has(text, "NPC per Nummer: geht nicht"), text)
STUB.secret = {}

-- 4) in combat and in an encounter lockdown it does not start; a fight during the run aborts it unsaved
STUB.messages = {}
AmisiaDB.probe = nil
STUB.combat = true
DT.Start()
assert(has(lastMsg(), "Die Datenprüfung läuft nicht im Kampf"), lastMsg())
STUB.combat = false
client({ quests = quests })
DT.Start()
STUB.tick(1.5)
STUB.combat = true
STUB.tick(5)
STUB.combat = false
assert(has(report(), "Abgebrochen"), report())
assert(AmisiaDB.probe == nil, "an aborted run saves nothing")
assert(has(lastMsg(), "Datenprüfung abgebrochen"), lastMsg())

-- 5) the slash word, English too, and a second start while one runs
STUB.messages = {}
SlashCmdList.AMISIA("selbsttest daten")
SlashCmdList.AMISIA("selftest data")
assert(has(lastMsg(), "Datenprüfung läuft schon"), lastMsg())
STUB.tick(6)

-- 5b) quest rewards by id: the quest log's reward functions answer for any quest id (global and C_ forms)
local knownQ, knownItem
for _, qid in ipairs(qids) do
    local row = dq.Q[qid]
    if qid ~= qids[1] and qid ~= qids[2] and type(row[12]) == "table" and #row[12] > 0 then knownQ, knownItem = qid, row[12][1] break end
end
assert(knownQ, "the data has a dungeon quest with a known reward")
local rewardsOf
local function rewardClient(byId)
    -- byId false: the client ignores the quest id and always answers for the same quest
    rewardsOf = function(qid)
        if not byId then qid = knownQ end
        if qid == knownQ then return { items = { { knownItem, 1 } }, choices = { 4711, 4712 }, money = 120, xp = 450 } end
        if qid == 95775 then return { items = { { 5000, 2 } }, choices = {}, money = 0, xp = 1200 } end
        return { items = {}, choices = {}, money = 0, xp = 0 }
    end
    _G.GetNumQuestLogRewards = function(qid) return #rewardsOf(qid).items end
    _G.GetQuestLogRewardInfo = function(i, qid)
        local it = rewardsOf(qid).items[i]
        if it then return "Item " .. it[1], 133000, it[2], 2, true, it[1] end
    end
    _G.GetNumQuestLogChoices = function(qid, withCurrencies) return #rewardsOf(qid).choices end
    _G.GetQuestLogChoiceInfo = function(i, qid)
        local id = rewardsOf(qid).choices[i]
        if id then return "Wahl " .. id, 133001, 1, 3, true end   -- no item id: the link gives it
    end
    local link = _G.GetQuestLogItemLink
    _G.GetQuestLogItemLink = function(kind, i, qid)
        if kind == "choice" and rewardsOf(qid).choices[i] then return ("|cff1eff00|Hitem:%d::::::::30:::::|h[Wahl]|h|r"):format(rewardsOf(qid).choices[i]) end
        return link(kind, i)
    end
    _G.GetQuestLogRewardMoney = function(qid) return rewardsOf(qid).money end
    _G.GetQuestLogRewardXP = nil
    C_QuestLog.GetQuestLogRewardXP = function(qid) return rewardsOf(qid).xp end   -- only the C_ form
end
local quests2 = { [qids[1]] = { title = "Die erste" }, [qids[2]] = { title = "Die zweite" }, [95775] = { title = "Die Ertrunkene Stadt" },
    [knownQ] = { title = "Mit Belohnung" } }
client({ quests = quests2 })
-- the tooltip data lines carry a type and ids
C_TooltipInfo.GetHyperlink = function(link)
    local qid = tonumber(link:match("^quest:(%d+)$"))
    if qid and quests2[qid] then
        local out = {}
        for i = 1, 14 do out[i] = { leftText = "Zeile " .. i, type = i == 14 and 10 or 0, id = i == 14 and 5000 or nil } end
        out[1].leftText = quests2[qid].title
        return { type = 7, id = qid, lines = out }
    end
    return { lines = {} }
end
rewardClient(true)
STUB.messages = {}
DT.Start()
STUB.tick(6)
text = report()
assert(has(text, "== Questbelohnungen per Nummer =="), text)
assert(has(text, "GetNumQuestLogRewards: global"), "presence per form")
assert(has(text, "GetQuestLogRewardXP: C_QuestLog"), "only the C_ form")
assert(has(text, "GetQuestRewardSpells: fehlt"), text)
assert(has(text, knownQ .. " mit bekannter Belohnung: Belohnungen 1"), text)
assert(has(text, knownQ .. " Belohnung 1: Info: \"Item " .. knownItem .. "\""), text)
assert(has(text, knownQ .. " Auswahl 2: Info:") and has(text, "Item 4712"), "the choice's id from its link")
assert(has(text, "Geld 120; EP 450"), text)
assert(has(text, knownQ .. " laut unseren Daten: " .. knownItem), text)
assert(has(text, knownQ .. " Zeile 14 (C_TooltipInfo): Zeile 14"), "every tooltip line, not only four")
assert(has(text, knownQ .. " Zeilendaten 14: id=5000, type=10"), text)
assert(has(text, "Questbelohnungen per Nummer: geht (Funktion GetQuestLogRewardInfo)"), text)
assert(has(text, "Quest-EP per Nummer: geht (sofort)"), text)
assert(AmisiaDB.probe.questReward == "ok" and AmisiaDB.probe.questXP == "ok")
assert(has(lastMsg(), "Questbelohnungen geht (sofort)"), lastMsg())

-- the client ignores the quest id: the same answer for every quest is no answer
rewardClient(false)
DT.Start()
STUB.tick(6)
assert(has(report(), "Questbelohnungen per Nummer: geht nicht"), report())
assert(AmisiaDB.probe.questReward == "none")

-- no reward functions at all: reported missing, the verdict "geht nicht"
for _, name in ipairs({ "GetNumQuestLogRewards", "GetQuestLogRewardInfo", "GetNumQuestLogChoices", "GetQuestLogChoiceInfo", "GetQuestLogRewardMoney" }) do _G[name] = nil end
C_QuestLog.GetQuestLogRewardXP = nil
DT.Start()
STUB.tick(6)
text = report()
assert(has(text, "GetNumQuestLogRewards: fehlt") and has(text, "Questbelohnungen per Nummer: geht nicht"), text)
assert(has(text, "Quest-EP per Nummer: geht nicht"), text)
assert(AmisiaDB.probe.questReward == "none" and AmisiaDB.probe.questXP == "none")

-- 6) a client without C_TooltipInfo and without the quest functions: the probe still reports
C_TooltipInfo.GetHyperlink = nil
C_QuestLog.RequestLoadQuestByID = nil
DT.Start()
STUB.tick(6)
text = report()
assert(has(text, "nicht vorhanden"), text)
assert(has(text, "fehlt: C_QuestLog.RequestLoadQuestByID"), text)
_G.CreateFrame = realCreate
print("data probe: NPCs at once, late, never, secret; quests; models; verdicts saved; combat; no client functions")
