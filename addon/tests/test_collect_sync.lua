--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- The source exchange (CollectSync.lua over Comm.lua): Vulo Sturmwind, Fraktur and Kim Eisherz are
-- guild members, Pug reaches the guild channel but no roster names him. Each member announces its
-- collector records (CV); the others pull what they miss (CQ, CI, CR, CK blob). Different records of
-- the same quest merge to the same result everywhere; only missing records travel; Pug is ignored;
-- forged, malformed and unasked blobs are refused whole; another collect protocol is passed over and
-- an unknown message kind does not stop a client; nothing goes in an instance, in combat or in the
-- lockdown; the session's bytes hold.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"
local MEMBERS = { VULO, FRAK, KIM }
local ME = { [VULO] = "a0000001", [FRAK] = "b0000002", [KIM] = "c0000003", [PUG] = "d0000004" }
local KINDS = { CV = true, CQ = true, CI = true, CR = true, CW = true }
local function isCK(m) return m.prefix == "AmisiaD" and m.text:match("^1BL\tCK\t") ~= nil end
local function collectMsg(m) return KINDS[m.kind] or isCK(m) end

local function setup(name)
    C(name, ([[STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
-- records: list of { kind, id, record }
local function put(name, list)
    return C(name, [[local n = 0
        for _, e in ipairs({ ]] .. list .. [[ }) do
            assert(NS.CollectPut(e[1], e[2], e[3], "own"), "valid " .. e[3])
            n = n + 1
        end
        return n]])
end
-- the whole table as one sorted text (kind:id=record without the day)
local function dump(name)
    return C(name, [[local out = {}
        for _, k in ipairs({ "q", "s", "w" }) do
            for id, s in pairs(AmisiaDB.collect[k]) do out[#out + 1] = k .. ":" .. id .. "=" .. s:gsub("^%d+;", "") end
        end
        table.sort(out)
        return table.concat(out, "\n")]])
end
local function count(name) return C(name, "local c = NS.CollectCounts(); return c.q + c.s + c.w") end
local function stat(name, field) return C(name, ("NS.CollectSyncStats().%s"):format(field)) end
local function login(name) C(name, "STUB.fire('PLAYER_LOGIN')") end
local function clear(name) C(name, "AmisiaDB.collect = nil; NS.CollectMigrate(AmisiaDB)") end
local function sentBy(name, from)
    return BUS.count(function(m) return m.sender == name and m.t >= (from or 0) and collectMsg(m) end)
end
local function bytesBy(name, from)
    local n = 0
    for _, m in ipairs(BUS.sent) do
        if m.sender == name and m.t >= from and collectMsg(m) then n = n + #m.prefix + #m.text end
    end
    return n
end

BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
BUS.guild = { VULO, FRAK, KIM, PUG }
for _, name in ipairs(CLIENTS) do setup(name) end
assert(C(VULO, "NS.CollectSyncCanTalk()") == true)
assert(C(VULO, "NS.COLLECT_PROTO") == 2)

---------------------------------------------------------------------------
-- three members with overlapping records converge; Pug is ignored
---------------------------------------------------------------------------
local D = C(VULO, "NS.DropsToday()")
put(VULO, ([[{ "q", 2001, "%d;0;3344;1411:5234:4011;0;;280604;;0;30;H;0;Sturmrufer;Die Waffen des Sturms" },
    { "q", 2002, "%d;0;3344;1411:5234:4011;0;;;;34;30;H;2001;Sturmrufer;Weiter" },
    { "s", 904, "%d;0;1411:2500:7500;6001:1520::6@Orgrimmar;Grimm" },
    { "w", 299, "%d;0;r;1411:2500:7500;0;7001:1;Wolf" }]]):format(D, D, D, D))
put(FRAK, ([[{ "q", 2001, "%d;0;3344;1411:5234:4011;4455;1411:1000:2000;280604;5001;34;28;A;0;Sturmrufer;Die Waffen des Sturms" },
    { "q", 2065, "%d;0;100;1411:1:1;0;;;;0;10;A;0;Gryan;Die Defias" },
    { "w", 299, "%d;0;;1411:2600:7500;0;7001:2,7004:1;" }]]):format(D - 3, D - 1, D))
-- many quests at Kim's, spread over the buckets
local many = {}
for i = 1, 60 do many[#many + 1] = ([[{ "q", %d, "%d;0;%d;1440:%d:%d;0;;%d;;0;20;H;0;Geber;Quest %d" }]]):format(3000 + i, D, 5000 + i, i, i, 200000 + i, i) end
put(KIM, table.concat(many, ","))
put(PUG, ([[{ "q", 9999, "%d;0;1;;0;;;;0;1;H;0;;Pugs Quest" }]]):format(D))
local want = {}
for _, name in ipairs(CLIENTS) do login(name) end
BUS.tick(89)
assert(BUS.count({ kind = "CV" }) == 0, "no announcement in the first 90 s")
BUS.tick(2400)
-- quest 2001 and the wolf 299 were seen by Vulo and by Fraktur with different values: each keeps
-- its own (heard data never replaces an own value), so those two records differ between them;
-- everything else is the same everywhere
local function shared(name) return (dump(name):gsub("q:2001=[^\n]*\n?", ""):gsub("w:299=[^\n]*\n?", "")) end
local base = shared(VULO)
for _, name in ipairs(MEMBERS) do
    assert(shared(name) == base, name .. " differs:\n" .. shared(name) .. "\n---\n" .. base)
    assert(count(name) == 65, name .. ": " .. count(name))
end
-- the merged quest at Kim (heard only): rewards and choices, both factions, the turn-in NPC, the lowest level
local q = C(KIM, "NS.CollectQuest(2001)")
assert(q.ender == 4455 and q.fac == "AH" and q.minlvl == 28 and q.qlevel == 34 and q.choices[1] == 5001, "merged")
-- at Vulo his own faction and level stay; what he did not see comes from Fraktur
q = C(VULO, "NS.CollectQuest(2001)")
assert(q.fac == "H" and q.minlvl == 30 and q.ender == 4455 and q.qlevel == 34 and q.choices[1] == 5001, "own values stay at Vulo")
q = C(FRAK, "NS.CollectQuest(2001)")
assert(q.fac == "A" and q.minlvl == 28, "and at Fraktur")
local w = C(KIM, "NS.CollectWorld(299)")
assert(w.items[7001] == 2 and w.items[7004] == 1 and w.class == "r" and w.name == "Wolf")
w = C(VULO, "NS.CollectWorld(299)")
assert(w.items[7001] == 1 and not w.items[7004] and w.pos == "1411:2500:7500", "Vulo's own loot list stays his")
-- nothing from or to Pug
for _, name in ipairs(MEMBERS) do assert(C(name, "AmisiaDB.collect.q[9999] == nil"), "Pug's record at " .. name) end
assert(C(PUG, "AmisiaDB.collect.q[2001] == nil"), "Pug got nothing")
assert(BUS.count(function(m) return collectMsg(m) and m.target == PUG end) == 0, "no answer to Pug")
for _, name in ipairs(MEMBERS) do assert(stat(name, "refused") >= 1, "Pug refused at " .. name) end
-- blobs within 20 parts, whispered
for _, m in ipairs(BUS.sent) do
    if isCK(m) then
        local n = tonumber(m.text:match("^1BL\tCK\t[^\t]+\t%d+\t%d+\t(%d+)\t"))
        assert(n <= 20 and m.target ~= nil and m.chan == "WHISPER")
    end
end
-- no player name in any collect message
for _, m in ipairs(BUS.sent) do
    if KINDS[m.kind] then
        for _, who in ipairs({ "Vulo", "Fraktur", "Kim" }) do assert(not m.text:find(who, 1, true), "a name in " .. m.text) end
    end
end

---------------------------------------------------------------------------
-- a new own record: only it travels; the same record on a later day starts nothing
---------------------------------------------------------------------------
local before = { [FRAK] = stat(FRAK, "records"), [KIM] = stat(KIM, "records") }
local t1 = C(VULO, "STUB.clock")
C(VULO, [[STUB.place.map = 1411; STUB.map.pos = { x = 0.3, y = 0.3 }
    STUB.npc, STUB.npcGUID = "Mok", "Creature-0-1-1-1-777-1"
    _G.GetQuestID = function() return 4242 end
    _G.GetTitleText = function() return "Neue Quest" end
    STUB.level, STUB.faction = 31, "Horde"
    STUB.fire("QUEST_DETAIL")]])
assert(C(VULO, "AmisiaDB.collect.q[4242] ~= nil"), "observed")
BUS.tick(2000)
assert(BUS.count({ kind = "CV", sender = VULO, from = t1 }) == 1, "announced again after a new own record")
for _, name in ipairs({ FRAK, KIM }) do
    assert(C(name, "AmisiaDB.collect.q[4242] ~= nil"), name .. " has the new quest")
    assert(stat(name, "records") - before[name] == 1, name .. " got only the missing record: " .. (stat(name, "records") - before[name]))
end
assert(BUS.count(function(m) return m.kind == "CR" and m.t >= t1 and m.text:find("\t%x%x%x%x") end) >= 1, "requests list the known records")
-- a later day changes no checksum
local hash = C(KIM, "AmisiaDB.collect.q[3001]")
C(KIM, ("AmisiaDB.collect.q[3001] = (AmisiaDB.collect.q[3001]:gsub('^%%d+', '%d')); NS.CollectMigrate(AmisiaDB)"):format(D + 1))
assert(C(KIM, "AmisiaDB.collect.q[3001]") ~= hash)
local t2 = C(KIM, "STUB.clock")
BUS.tick(2000)
assert(BUS.count(function(m) return m.t >= t2 and (m.kind == "CQ" or m.kind == "CR") end) == 0, "nothing to pull")

---------------------------------------------------------------------------
-- forged, malformed and unasked data
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
put(VULO, ([[{ "q", 64, "%d;0;1;;0;;;;0;1;H;0;;Eins" }]]):format(D))
-- Fraktur asks, Vulo's answers are lost: the request is made through the protocol
BUS.drop(function(m) return m.sender == VULO and isCK(m) end)
login(VULO); login(FRAK)
BUS.tick(400)
assert(BUS.count({ kind = "CR", sender = FRAK, target = VULO }) >= 1, "Fraktur asked")
assert(C(FRAK, "AmisiaDB.collect.q[64] == nil"))
BUS.drop(nil)
-- each forged blob below answers an open request for bucket 0 of the quests (key 0000-00-00:101)
local function forge(tbl, open, from)
    if open ~= false then C(FRAK, "NS.CollectSyncOpenAsk('Vulo Sturmwind', 'q', { 0 })") end
    local bad0, un0 = stat(FRAK, "bad"), stat(FRAK, "unasked")
    C(from or VULO, ("assert(NS.CommSendBlob('CK', '0000-00-00:101', %s, 'WHISPER', 'Fraktur', {}))"):format(tbl))
    BUS.tick(10)
    return stat(FRAK, "bad") - bad0, stat(FRAK, "unasked") - un0
end
local GOOD = ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Eins" } }]]):format(D)
-- Kim was never asked by Fraktur: her blob is unasked
local bad, unasked = forge(GOOD, false, KIM)
assert(bad == 0 and unasked == 1 and C(FRAK, "AmisiaDB.collect.q[64] == nil"), "unasked data is dropped")
local forged = {
    ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;X;0;;Eins" } }]]):format(D),        -- a bad faction
    ([[{ v = 2, k = "q", r = { 65, "%d;0;1;;0;;;;0;1;H;0;;Eins" } }]]):format(D),        -- another bucket
    ([[{ v = 2, k = "s", r = { 64, "%d;0;;;Eins" } }]]):format(D),                       -- another kind
    ([[{ v = 1, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Eins" } }]]):format(D),        -- another version
    ([[{ v = 2, k = "q", r = { 64, "%d;1;1;;0;;;;0;1;H;0;;Eins" } }]]):format(D),        -- an own mask
    ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Eins" } }]]):format(D + 2),    -- the day after tomorrow
    ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Eins" }, x = 1 }]]):format(D),  -- a field of no blob
    ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Ei|cffffns" } }]]):format(D),  -- a bar in a text
    ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Eins", 128, "kaputt" } }]]):format(D),   -- one bad among good
    ([[{ v = 2, k = "q", r = { 64 } }]]),                                               -- odd list
    ([[{ v = 2, k = "q", r = { "64", "x" } }]]),                                        -- a text id
    ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Eins", 64, "%d;0;1;;0;;;;0;1;H;0;;Eins" } }]]):format(D, D), -- twice
    ([[{ v = 2, k = "q", r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Eins", n = 1 } }]]):format(D),  -- extra keys
}
for i, tbl in ipairs(forged) do
    local b = forge(tbl)
    assert(b == 1, "refused as bad: " .. i)
    assert(C(FRAK, "AmisiaDB.collect.q[64] == nil and AmisiaDB.collect.q[65] == nil"), "nothing taken from forged blob " .. i)
end
-- a request takes its one answer: the good blob is taken, the same again is unasked
assert(forge(GOOD) == 0 and C(FRAK, "AmisiaDB.collect.q[64] ~= nil"), "the asked blob is taken")
local b2, u2 = forge(GOOD, false)
assert(b2 == 0 and u2 == 1, "a second answer is unasked")
-- malformed control messages: dropped by Comm, nothing breaks
local bad0 = C(FRAK, "NS.CommStats().bad")
C(VULO, [[NS.CommSend("CV", { "1", "x", "q:zz:1" }, "GUILD")
    NS.CommSend("CR", { "q99", "*" }, "WHISPER", "Fraktur")
    NS.CommSend("CI", { "q", "1", "1", "zz:abcd:1" }, "WHISPER", "Fraktur")
    NS.CommSend("CQ", { "x" }, "WHISPER", "Fraktur")]])
BUS.tick(10)
assert(C(FRAK, "NS.CommStats().bad") - bad0 == 4, "four malformed messages counted")
-- Pug's blobs are dropped unread, even for an asked bucket
C(FRAK, "AmisiaDB.collect.q[64] = nil; NS.CollectMigrate(AmisiaDB); NS.CollectSyncOpenAsk('Pug', 'q', { 0 })")
C(PUG, ([[NS.CommSendBlob("CK", "0000-00-00:101", { v = 2, k = "q", b = 0, r = { 64, "%d;0;1;;0;;;;0;1;H;0;;Pug" } }, "WHISPER", "Fraktur", {})]]):format(D))
BUS.tick(10)
assert(C(FRAK, "AmisiaDB.collect.q[64] == nil"), "nothing from Pug")
-- a saved record that broke at the sender cannot reach the others: it is left out of the blob
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
put(VULO, ([[{ "q", 64, "%d;0;1;;0;;;;0;1;H;0;;Eins" }]]):format(D))
C(VULO, ("AmisiaDB.collect.q[128] = %q; NS.CollectPut('q', 192, '%d;0;1;;0;;;;0;1;H;0;;Drei', 'own')"):format("kaputt;;", D))
local fbad = stat(FRAK, "bad")
login(VULO); login(FRAK)
BUS.tick(600)
assert(stat(FRAK, "bad") == fbad and C(FRAK, "AmisiaDB.collect.q[128] == nil"), "the broken record stays behind")
assert(C(FRAK, "AmisiaDB.collect.q[64] ~= nil and AmisiaDB.collect.q[192] ~= nil"), "the good ones travel")

---------------------------------------------------------------------------
-- another collect protocol is passed over; an unknown kind stops nothing
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
local t3 = C(VULO, "STUB.clock")
C(FRAK, "NS.CommSend('CV', { '3', '5', 'q:abcd:5,s:0000:0,w:0000:0', 'more' }, 'GUILD')")
BUS.tick(120)
assert(BUS.count({ kind = "CQ", from = t3 }) == 0, "a newer collect protocol is not pulled from")
assert(stat(VULO, "other") == 1)
C(FRAK, "NS.CommSend('CV', { '1', '5', 'q:abcd:5,s:0000:0,w:0000:0' }, 'GUILD')")
BUS.tick(120)
assert(BUS.count({ kind = "CQ", from = t3 }) == 0 and stat(VULO, "other") == 2, "an older collect protocol is passed over too")
-- a later client's unknown message kind: counted as bad, the sender still heard afterwards
C(FRAK, "NS.CommSend('ZX', { 'neu' }, 'GUILD')")
BUS.tick(5)
put(FRAK, ([[{ "q", 7, "%d;0;1;;0;;;;0;1;H;0;;Sieben" }]]):format(D))
login(FRAK); login(VULO)
BUS.tick(600)
assert(C(VULO, "AmisiaDB.collect.q[7] ~= nil"), "pulled from Fraktur after its unknown message")

---------------------------------------------------------------------------
-- nothing in an instance, in combat, in the lockdown; the switch
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
put(VULO, ([[{ "q", 11, "%d;0;1;;0;;;;0;1;H;0;;Elf" }]]):format(D))
put(KIM, ([[{ "q", 12, "%d;0;1;;0;;;;0;1;H;0;;Zwoelf" }]]):format(D))
C(KIM, [[STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }]])
assert(C(KIM, "NS.CollectSyncCanTalk()") == false)
local t4 = C(KIM, "STUB.clock")
for _, name in ipairs(CLIENTS) do login(name) end
BUS.tick(400)
assert(sentBy(KIM, t4) == 0, "nothing from an instance")
assert(C(KIM, "AmisiaDB.collect.q[11] == nil"), "no pulling in an instance")
C(KIM, [[STUB.instance = { name = "Durotar", type = "none", id = 0 }; STUB.combat = true]])
assert(C(KIM, "NS.CollectSyncCanTalk()") == false)
BUS.tick(60)
assert(sentBy(KIM, t4) == 0, "nothing in combat")
C(KIM, "STUB.combat = false")
BUS.tick(600)
assert(C(KIM, "AmisiaDB.collect.q[11] ~= nil") and C(VULO, "AmisiaDB.collect.q[12] ~= nil"), "after leaving")
BUS.reload(FRAK); setup(FRAK); clear(FRAK)
put(FRAK, ([[{ "q", 13, "%d;0;1;;0;;;;0;1;H;0;;Dreizehn" }]]):format(D))
BUS.lock(true)
assert(C(FRAK, "NS.CollectSyncCanTalk()") == false)
local t5 = C(FRAK, "STUB.clock")
login(FRAK)
BUS.tick(400)
assert(BUS.count(function(m) return collectMsg(m) and m.t >= t5 end) == 0, "nothing in the lockdown")
BUS.lock(false)
BUS.tick(600)
assert(C(VULO, "AmisiaDB.collect.q[13] ~= nil"), "after the lockdown")
C(VULO, "NS.Set('collect.share', false)")
assert(C(VULO, "NS.CollectSyncCanTalk()") == false)
C(VULO, "NS.Set('collect.share', true)")

---------------------------------------------------------------------------
-- the bytes of a session
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
put(VULO, table.concat(many, ","))
C(VULO, "NS.COLLECTSYNC_LIMITS.sessionBytes = 3000")
local t6 = C(VULO, "STUB.clock")
login(VULO); login(KIM)
BUS.tick(1500)
assert(bytesBy(VULO, t6) <= 3000, "the session cap: " .. bytesBy(VULO, t6))
assert(count(KIM) < 60, "the cap stopped the answers: " .. count(KIM))
BUS.reload(VULO); setup(VULO)
assert(C(VULO, "NS.COLLECTSYNC_LIMITS.sessionBytes") == 49152 and C(VULO, "NS.COLLECTSYNC_LIMITS.blobParts") == 20)
