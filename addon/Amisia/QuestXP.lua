-- Amisia quest XP: what a quest is worth in experience, as this client saw it. No client table
-- names a quest's XP (QuestXP has the XP per quest level and difficulty step, the step of a quest
-- comes from the server) and the open quest data has none, so the client's own answers are kept:
-- the quest window (GetRewardXP on QUEST_DETAIL and QUEST_COMPLETE), the turn-in (QUEST_TURNED_IN
-- carries the XP) and the quest log (GetQuestLogRewardXP for a quest in it).
--
-- AmisiaDB.questxp = { [questID] = { xp, player level } }: the highest value seen and the level it
-- was seen at (a quest pays less to a player far above it, so the highest is the nearest to its
-- full value). Own data only; nothing of it is sent to the guild. Zero (the level cap) is not kept.
--
-- The level scaling is the classic client's: full XP up to five levels above the quest, then 20 %
-- less per level, 10 % from ten levels above, rounded to 5, 10, 25 or 50. Whether Forever does
-- exactly this is not checked: a scaled value is an estimate.
local ADDON, ns = ...

local QX = {}
ns.QuestXP = QX

local MAX_ID = 9999999

local function int(v, lo, hi) return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi end
local function report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) end
end

-- The share of a quest's full XP a player of level p gets for a quest of level q (0.1 - 1).
function QX.Factor(p, q)
    local f = 2 * (q - p) + 20
    if f > 10 then f = 10 elseif f < 1 then f = 1 end
    return f / 10
end

-- The classic client's rounding of a scaled quest XP.
function QX.Round(xp)
    xp = math.floor(xp + 0.5)
    if xp <= 100 then return 5 * math.floor((xp + 2) / 5) end
    if xp <= 500 then return 10 * math.floor((xp + 5) / 10) end
    if xp <= 1000 then return 25 * math.floor((xp + 12) / 25) end
    return 50 * math.floor((xp + 25) / 50)
end

-- Called on ADDON_LOADED: AmisiaDB.questxp with valid entries only.
function QX.Migrate(root)
    local t = type(root.questxp) == "table" and root.questxp or {}
    local drop = {}
    for k, v in pairs(t) do
        if not int(k, 1, MAX_ID) or type(v) ~= "table" or not int(v[1], 1, 10000000) or not int(v[2], 1, 99) then
            drop[#drop + 1] = k
        end
    end
    for _, k in ipairs(drop) do t[k] = nil end
    root.questxp = t
    return t
end

local function db()
    if not AmisiaDB then return nil end
    if type(AmisiaDB.questxp) ~= "table" then QX.Migrate(AmisiaDB) end
    return AmisiaDB.questxp
end

local function playerLevel()
    local lv = tonumber(ns.Plain((UnitLevel("player"))))
    return int(lv, 1, 99) and lv or nil
end

-- Keeps xp seen at a player level for a quest when it is more than what is kept. true on a change.
function QX.Record(qid, xp, level)
    qid, xp = tonumber(ns.Plain(qid)), tonumber(ns.Plain(xp))
    level = level or playerLevel()
    if not int(qid, 1, MAX_ID) or not xp or xp <= 0 or not int(level, 1, 99) then return false end
    xp = math.floor(xp + 0.5)
    local t = db()
    if not t then return false end
    local cur = t[qid]
    if cur and cur[1] >= xp then return false end
    t[qid] = { xp, level }
    ns.Fire("QUESTXP_CHANGED", qid)
    return true
end

-- What is kept for a quest: xp, the level it was seen at; nil when nothing.
function QX.Get(qid)
    local t = db()
    local v = t and t[tonumber(qid)]
    if not v then return nil end
    return v[1], v[2]
end

local function onQuestLog(qid)
    local Q = _G.C_QuestLog
    local f = type(Q) == "table" and Q.IsOnQuest
    if type(f) ~= "function" then return false end
    local ok, on = pcall(f, qid)
    return ok and ns.Plain(on) == true
end

-- The quest log's XP of a quest in it (at the player's level now), else nil.
local function logXP(qid)
    if type(_G.GetQuestLogRewardXP) ~= "function" or not onQuestLog(qid) then return nil end
    local ok, xp = pcall(_G.GetQuestLogRewardXP, qid)
    xp = ok and tonumber(ns.Plain(xp)) or nil
    if xp and xp > 0 then return math.floor(xp + 0.5) end
    return nil
end

-- A quest's XP for a player of level p (default the own level), with q its quest level (0 or nil
-- unknown): value, how, seenLevel. how: "log" (the quest log says so now), "seen" (seen at this
-- value for this level), "scaled" (worked out from another level by the quest level: an estimate),
-- "other" (seen at another level, the quest level is unknown: the value as seen). nil when never seen.
function QX.For(qid, q, p)
    qid = tonumber(qid)
    if not qid then return nil end
    local me = playerLevel()
    p = p or me
    if p == me then
        local xp = logXP(qid)
        if xp then
            QX.Record(qid, xp, me)
            return xp, "log", me
        end
    end
    local xp, seen = QX.Get(qid)
    if not xp then return nil end
    if not p or seen == p then return xp, "seen", seen end
    if not q or q <= 0 then return xp, "other", seen end
    local fSeen, fNow = QX.Factor(seen, q), QX.Factor(p, q)
    if fSeen == fNow then return xp, "seen", seen end
    local base = fSeen >= 1 and xp or xp / fSeen
    local v = fNow >= 1 and math.floor(base + 0.5) or QX.Round(base * fNow)
    return v, "scaled", seen
end

---------------------------------------------------------------------------
-- The recorder
---------------------------------------------------------------------------
local function recording() return AmisiaDB ~= nil and ns.Get("collect.quests") end

-- The quest window: the quest shown and its XP for the player now.
local function onWindow()
    if not recording() or type(GetQuestID) ~= "function" or type(_G.GetRewardXP) ~= "function" then return end
    QX.Record(GetQuestID(), _G.GetRewardXP())
end

local function onTurnedIn(qid, xp)
    if not recording() then return end
    QX.Record(qid, xp)
end

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then report(err) end
    end
end
ns.OnEvent("QUEST_DETAIL", safe(onWindow))
ns.OnEvent("QUEST_COMPLETE", safe(onWindow))
ns.OnEvent("QUEST_TURNED_IN", safe(onTurnedIn))
ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then QX.Migrate(AmisiaDB) end
end)
