--[[clients Vulo_Sturmwind Fraktur]]
-- Provenance of the collector's records (review 26): what a client saw itself stays its own; heard
-- data (an exchange blob) only fills fields the own observation left empty and never replaces an
-- own value; a later own observation replaces heard values; a sender's merges count against its
-- cap; a record from the future is refused. Fraktur plays a guild member who sends poisoned records
-- (smallest ids and texts, maximum day) to an open request of Vulo's.
local VULO, FRAK = "Vulo Sturmwind", "Fraktur"
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 } })
BUS.guild = { VULO, FRAK }
for _, name in ipairs(CLIENTS) do
    C(name, [[STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        STUB.fire("GUILD_ROSTER_UPDATE")]])
end
local D = C(VULO, "NS.DropsToday()")

-- Vulo meets quest 64 himself: giver 3344 at 1411:52.34:40.11, rewards 280604 and 280605
C(VULO, [[STUB.place.map = 1411; STUB.map.pos = { x = 0.5234, y = 0.4011 }
    STUB.level, STUB.faction = 18, "Horde"
    STUB.npc, STUB.npcGUID = "Sturmrufer", "Creature-0-1-1-1-3344-1"
    STUB.questItems = { reward = { STUB.item(280604, "Wut", 3), STUB.item(280605, "Zorn", 3) }, choice = {} }
    _G.GetNumQuestRewards = function() return #STUB.questItems.reward end
    _G.GetNumQuestChoices = function() return #STUB.questItems.choice end
    _G.GetQuestID = function() return QID or 64 end
    _G.GetTitleText = function() return TITLE or "Echt" end
    STUB.fire("QUEST_DETAIL")]])
local own = C(VULO, "AmisiaDB.collect.q[64]")
assert(own, "observed")

-- a poisoned record of the same quest, as a blob for an open request of bucket 0 (key ...:101)
local POISON = { day = 99999, own = 0, giver = -9999999, gpos = "1", ender = -9999999, epos = "1",
                 rewards = { 1, 2, 3, 4, 5, 6, 7, 8 }, choices = { 1 }, qlevel = 99, minlvl = 1, fac = "AH", pre = 1,
                 gname = "!", title = "!" }
local function blob(id, rec, key, bucket)
    C(VULO, ("NS.CollectSyncOpenAsk('Fraktur', 'q', { %d })"):format(bucket or 0))
    local s = C(FRAK, "NS.CollectFormat('q', " .. rec .. ")")
    C(FRAK, ("assert(NS.CommSendBlob('CK', %q, { v = NS.COLLECT_BLOB_V or 1, k = 'q', r = { %d, %q } }, 'WHISPER', 'Vulo Sturmwind', {}))")
        :format(key or "0000-00-00:101", id, s))
    BUS.tick(10)
end
local function rec(t)
    local parts = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            parts[#parts + 1] = k .. " = { " .. table.concat(v, ", ") .. " }"
        elseif type(v) == "string" then
            parts[#parts + 1] = ("%s = %q"):format(k, v)
        else
            parts[#parts + 1] = k .. " = " .. tostring(v)
        end
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end
local function q(id) return C(VULO, ("NS.CollectQuest(%d)"):format(id)) end
local function stat(name, f) return C(name, ("NS.CollectSyncStats().%s"):format(f)) end

---------------------------------------------------------------------------
-- a record from the future is refused (blob and put)
---------------------------------------------------------------------------
local bad0 = stat(VULO, "bad")
blob(64, rec(POISON))
assert(stat(VULO, "bad") == bad0 + 1, "a blob with a record from the future is refused whole")
assert(C(VULO, "AmisiaDB.collect.q[64]") == own, "nothing taken from it")
assert(C(VULO, ("NS.CollectPut('q', 64, NS.CollectFormat('q', %s))"):format(rec(POISON))) == nil, "put refuses a future day")
POISON.day = D + 2
assert(C(VULO, ("NS.CollectPut('q', 64, NS.CollectFormat('q', %s))"):format(rec(POISON))) == nil, "two days ahead: refused")
POISON.day = D + 1   -- a clock a day ahead is still taken

---------------------------------------------------------------------------
-- the sender's cap counts merges too
---------------------------------------------------------------------------
C(VULO, "NS.COLLECTSYNC_LIMITS.senderMax = 0")
blob(64, rec(POISON))
assert(C(VULO, "AmisiaDB.collect.q[64]") == own, "a merge over the sender's cap is not taken")
assert(stat(VULO, "capped") == 1, "counted as capped")
C(VULO, "NS.COLLECTSYNC_LIMITS.senderMax = 1500")

---------------------------------------------------------------------------
-- heard data fills only what the own observation left empty
---------------------------------------------------------------------------
blob(64, rec(POISON))
local r = q(64)
assert(r.giver == 3344 and r.gname == "Sturmrufer" and r.title == "Echt" and r.gpos == "1411:5234:4011", "own values stay")
assert(table.concat(r.rewards, ",") == "280604,280605", "own rewards stay: " .. table.concat(r.rewards, ","))
assert(r.minlvl == 18 and r.fac == "H", "own level and faction stay")
assert(r.ender == -9999999 and r.choices[1] == 1 and r.pre == 1 and r.qlevel == 99, "empty fields filled from heard data")
assert(C(VULO, "NS.CollectOwn('q', NS.CollectQuest(64), 'title')") == true, "the title is own")
assert(C(VULO, "NS.CollectOwn('q', NS.CollectQuest(64), 'ender')") == false, "the turn-in NPC is heard")
local d = C(VULO, "AmisiaDB.collect.q[64]")
-- the same heard record again changes nothing
blob(64, rec(POISON))
assert(C(VULO, "AmisiaDB.collect.q[64]") == d, "idempotent")
-- Vulo hands the quest in himself: his turn-in NPC replaces the heard one
C(VULO, [[STUB.npc, STUB.npcGUID = "Grisgrind", "Creature-0-1-1-1-4455-1"
    STUB.map.pos = { x = 0.1, y = 0.2 }
    STUB.fire("QUEST_PROGRESS")]])
r = q(64)
assert(r.ender == 4455 and r.epos == "1411:1000:2000", "own observation overrides heard: " .. r.ender)
assert(C(VULO, "NS.CollectOwn('q', NS.CollectQuest(64), 'ender')") == true)

---------------------------------------------------------------------------
-- a quest only heard of, then seen: the own observation replaces the heard values
---------------------------------------------------------------------------
blob(65, rec(POISON), "0000-00-00:102", 1)
r = q(65)
assert(r and r.title == "!" and r.giver == -9999999, "a heard record is kept")
assert(C(VULO, "NS.CollectOwn('q', NS.CollectQuest(65), 'title')") == false)
C(VULO, [[QID, TITLE = 65, "Echte Quest"
    STUB.npc, STUB.npcGUID = "Sturmrufer", "Creature-0-1-1-1-3344-1"
    STUB.fire("QUEST_DETAIL")]])
r = q(65)
assert(r.title == "Echte Quest" and r.giver == 3344 and r.gname == "Sturmrufer", "seen: own replaces heard")
assert(table.concat(r.rewards, ",") == "280604,280605", "own rewards replace the heard list")
-- heard data after that cannot evict the own rewards
blob(65, rec(POISON), "0000-00-00:102", 1)
assert(table.concat(q(65).rewards, ",") == "280604,280605", "heard rewards never evict own ones")

---------------------------------------------------------------------------
-- the join: any order, twice the same as once; own beats heard in either order
---------------------------------------------------------------------------
C(VULO, [[local M, F = NS.CollectMergeRecords, NS.CollectFormat
    local own = F("q", { day = 5, own = 4095, giver = 10, gpos = "1:1:1", ender = 20, epos = "1:2:2", rewards = { 7 }, choices = { 8 },
        qlevel = 20, minlvl = 18, fac = "H", pre = 3, gname = "G", title = "Own" })
    local h1 = F("q", { day = 6, own = 0, giver = 1, gpos = "", ender = 0, epos = "", rewards = { 1, 2 }, choices = {}, qlevel = 0,
        minlvl = 0, fac = "A", pre = 0, gname = "", title = "A" })
    local h2 = F("q", { day = 4, own = 0, giver = 2, gpos = "9", ender = 5, epos = "", rewards = { 3 }, choices = {}, qlevel = 30,
        minlvl = 2, fac = "", pre = 0, gname = "Z", title = "B" })
    assert(M("q", h1, h2) == M("q", h2, h1), "heard: commutative")
    assert(M("q", M("q", h1, h2), own) == M("q", h1, M("q", h2, own)), "associative")
    assert(M("q", h1, h1) == h1 and M("q", own, own) == own, "idempotent")
    local r = NS.CollectParse("q", M("q", h1, own))
    assert(M("q", own, h1) == M("q", h1, own))
    assert(r.title == "Own" and r.giver == 10 and r.rewards[1] == 7 and #r.rewards == 1 and r.fac == "H" and r.day == 6, "own wins")]])
print("collect trust: own values survive poisoned blobs; heard fills only empty fields")
