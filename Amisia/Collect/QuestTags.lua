-- Amisia quest types: which quests the game calls group, dungeon, raid or PvP quests, as this client
-- sees them in its quest log. Neither the open quest data nor the client tables say so; the play style
-- "Solo machbar" (Gear/PlayStyle.lua, F-124) needs it. Read from the quest log (the tag of a quest,
-- C_QuestLog.GetQuestTagInfo / GetQuestTagInfo, and its suggested group size) when it changes.
--
-- AmisiaDB.questtags = { v = 1, list = { [questID] = code } }, code G group or elite, D dungeon, R raid,
-- P PvP. Own data only; nothing of it is sent. tools/build_gear.py joins it into
-- tools/quest_tag_archive.json and writes the types into the gear data (QT), so the file may forget.
-- Recorded only while the quests are recorded (the switch collect.quests).
local ADDON, ns = ...

local QT = {}
ns.QuestTags = QT

local MAX_ID, MAX_TAGS = 9999999, 3000
local CODES = { G = true, D = true, R = true, P = true }
-- the game's quest tag ids: 1 group, 41 PvP, 62 raid, 81 dungeon, 88/89 raid (10/25)
local TAG_CODE = { [1] = "G", [41] = "P", [62] = "R", [81] = "D", [88] = "R", [89] = "R" }
QT.TAG_CODE = TAG_CODE

local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- Called on ADDON_LOADED: AmisiaDB.questtags with valid entries only, the newest MAX_TAGS ids kept
-- (the highest: newer quests have higher ids).
function QT.Loaded(root)
    local q = type(root.questtags) == "table" and root.questtags or {}
    local list = type(q.list) == "table" and q.list or {}
    local ids = {}
    for k, v in pairs(list) do
        if int(k, 1, MAX_ID) and CODES[v] then ids[#ids + 1] = k else list[k] = nil end
    end
    if #ids > MAX_TAGS then
        table.sort(ids)
        for i = 1, #ids - MAX_TAGS do list[ids[i]] = nil end
    end
    root.questtags = { v = 1, list = list }
    return root.questtags
end

local function db()
    if not AmisiaDB then return nil end
    if type(AmisiaDB.questtags) ~= "table" or type(AmisiaDB.questtags.list) ~= "table" then QT.Loaded(AmisiaDB) end
    return AmisiaDB.questtags.list
end

-- The learned type of a quest, or nil.
function QT.Get(qid)
    local t = AmisiaDB and type(AmisiaDB.questtags) == "table" and type(AmisiaDB.questtags.list) == "table"
        and AmisiaDB.questtags.list or nil
    return t and t[qid] or nil
end

-- The type of a quest from its tag id and its suggested group size (2 or more: a group quest).
function QT.Code(tagID, group)
    local c = TAG_CODE[tonumber(tagID) or -1]
    if c then return c end
    if (tonumber(group) or 0) >= 2 then return "G" end
    return nil
end

-- Keeps a quest's type. true on a change.
function QT.Record(qid, code)
    if not int(qid, 1, MAX_ID) or not CODES[code] then return false end
    local t = db()
    if not t or t[qid] == code then return false end
    t[qid] = code
    return true
end

local function tagOf(qid)
    local Q = _G.C_QuestLog
    if type(Q) == "table" and type(Q.GetQuestTagInfo) == "function" then
        local ok, info = pcall(Q.GetQuestTagInfo, qid)
        if ok and type(info) == "table" then return tonumber(ns.Plain(info.tagID)) end
    end
    if type(_G.GetQuestTagInfo) == "function" then
        local ok, tag = pcall(_G.GetQuestTagInfo, qid)
        if ok then return tonumber(ns.Plain(tag)) end
    end
    return nil
end

-- The quests of the log: { { questID, suggested group } }.
local function logQuests()
    local out = {}
    local Q = _G.C_QuestLog
    if type(Q) == "table" and type(Q.GetNumQuestLogEntries) == "function" and type(Q.GetInfo) == "function" then
        local ok, n = pcall(Q.GetNumQuestLogEntries)
        for i = 1, (ok and tonumber(ns.Plain(n))) or 0 do
            local ok2, info = pcall(Q.GetInfo, i)
            if ok2 and type(info) == "table" and not ns.Plain(info.isHeader) then
                out[#out + 1] = { tonumber(ns.Plain(info.questID)), tonumber(ns.Plain(info.suggestedGroup)) }
            end
        end
        return out
    end
    if type(_G.GetNumQuestLogEntries) == "function" and type(_G.GetQuestLogTitle) == "function" then
        local ok, n = pcall(_G.GetNumQuestLogEntries)
        for i = 1, (ok and tonumber(ns.Plain(n))) or 0 do
            local ok2, _, _, group, isHeader, _, _, _, qid = pcall(_G.GetQuestLogTitle, i)
            if ok2 and not ns.Plain(isHeader) then out[#out + 1] = { tonumber(ns.Plain(qid)), tonumber(ns.Plain(group)) } end
        end
    end
    return out
end

local function recording() return AmisiaDB ~= nil and ns.Get("collect.quests") end

-- Reads the quest log once; returns how many types were new.
function QT.Scan()
    if not recording() then return 0 end
    local n = 0
    for _, q in ipairs(logQuests()) do
        local qid = q[1]
        if int(qid, 1, MAX_ID) then
            local code = QT.Code(tagOf(qid), q[2])
            if code and QT.Record(qid, code) then n = n + 1 end
        end
    end
    if n > 0 and ns.PlayStyle then ns.PlayStyle.QuestTagLearned() end
    return n
end

local pending = false
local function soon()
    if pending then return end
    pending = true
    local function go()
        pending = false
        local ok, err = pcall(QT.Scan)
        if not ok then report(err) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(3, go) else go() end
end
ns.OnEvent("QUEST_ACCEPTED", soon)
ns.OnEvent("QUEST_LOG_UPDATE", soon)
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then QT.Loaded(AmisiaDB) end
end)
