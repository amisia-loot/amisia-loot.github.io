--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- The drop exchange (DropSync.lua over Comm.lua) between clients: Vulo Sturmwind, Fraktur and Kim
-- Eisherz are guild members, Pug reaches the guild channel but no roster names him. After the login
-- each member announces its records (DV); the others pull what they miss (DQ, DI, DR, DK blob).
-- Overlapping records converge and a kill counts once; only missing records travel; Pug is
-- ignored; forged, malformed and unasked blobs are refused whole; the caps hold (20 parts per blob,
-- one open request, the bytes of a session); nothing goes in an instance, in combat, in the
-- lockdown or while a raid is synced; the raid sync's data goes before the drop exchange.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"
local MEMBERS = { VULO, FRAK, KIM }
local ME = { [VULO] = "a0000001", [FRAK] = "b0000002", [KIM] = "c0000003", [PUG] = "d0000004" }
local DROP_KINDS = { DV = true, DQ = true, DI = true, DR = true }

local function isDK(m) return m.prefix == "AmisiaD" and m.text:match("^1BL\tDK\t") ~= nil end
local function dropMsg(m) return DROP_KINDS[m.kind] or isDK(m) end

-- a client outside any instance, with its fixed client id
local function setup(name)
    C(name, ([[STUB.instance = { name = "Sturmwind", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = %q
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(ME[name]))
end
-- records given as Lua source: { id, npc, inst, days ago, items }
local function add(name, list)
    return C(name, [[local today, n = NS.DropsToday(), 0
        for _, x in ipairs({ ]] .. list .. [[ }) do
            local r = { h = x[1], npc = x[2], inst = x[3], diff = 1, day = today - x[4], o = AmisiaDB.drops.me, src = "G", it = x[5] or {} }
            -- as recorded by this client itself
            if NS.DropsMerge(r) == "new" then n = n + 1; AmisiaDB.drops.k[r.h].mine = true end
        end
        return n]])
end
local function ids(name)
    return C(name, [[local out = {}
        for id in pairs(AmisiaDB.drops.k) do out[#out + 1] = id end
        table.sort(out)
        return table.concat(out, ",")]])
end
local function kills(name) return C(name, "NS.DropsStatus().kills") end
local function stat(name, field) return C(name, ("NS.DropSyncStats().%s"):format(field)) end
local function login(name) C(name, "STUB.fire('PLAYER_LOGIN')") end
local function clear(name) C(name, "AmisiaDB.drops.k = {}; NS.DropsPrune()") end
local function sentBy(name, from, f)
    return BUS.count(function(m) return m.sender == name and m.t >= (from or 0) and dropMsg(m) and (not f or f(m)) end)
end
local function bytesBy(name, from)
    local n = 0
    for _, m in ipairs(BUS.sent) do
        if m.sender == name and m.t >= from and dropMsg(m) then n = n + #m.prefix + #m.text end
    end
    return n
end
-- the parts of every DK set sent: { [sender .. seq] = { n, first, last, target } }
local function dkSets(from)
    local sets = {}
    for _, m in ipairs(BUS.sent) do
        if isDK(m) and m.t >= (from or 0) then
            local seq, n = m.text:match("^1BL\tDK\t[^\t]+\t(%d+)\t%d+\t(%d+)\t")
            local id = m.sender .. ":" .. seq
            local s = sets[id] or { n = tonumber(n), first = m.t, target = m.target, sender = m.sender, parts = 0 }
            s.parts, s.last = s.parts + 1, m.t
            sets[id] = s
        end
    end
    return sets
end

---------------------------------------------------------------------------
-- the guild: three members; Pug sends to the guild channel without being in any roster
---------------------------------------------------------------------------
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
BUS.guild = { VULO, FRAK, KIM, PUG }
for _, name in ipairs(CLIENTS) do setup(name) end
assert(C(VULO, "NS.IsVerifiedMember('Fraktur')") == true and C(VULO, "NS.IsVerifiedMember('Pug')") == false)
assert(C(VULO, "NS.DropSyncCanTalk()") == true, "outside instances the exchange may talk")
-- protocol 2: the checksums cover the items, requests group buckets, busy senders answer DW
assert(C(VULO, "NS.DROP_PROTO") == 2, "the drop protocol")

---------------------------------------------------------------------------
-- three clients with overlapping records converge; a kill counts once
---------------------------------------------------------------------------
assert(add(VULO, [[{ "11111111", 213450, 2834, 0, { [219004] = 1 } }, { "22222222", 213451, 2834, 1 },
    { "55555555", 11502, 409, 2, { [219005] = 1 } }, { "66666666", 11501, 409, 2 }]]) == 4)
assert(add(FRAK, [[{ "33333333", 213460, 2834, 0 }, { "55555555", 11502, 409, 2, { [219005] = 1, [219006] = 2 } }]]) == 2)
assert(add(KIM, [[{ "44444444", 213450, 2834, 9, { [219004] = 2 } }, { "77777777", 11502, 409, 15 }, { "88888888", 213470, 2834, 22 }]]) == 3)
assert(add(PUG, [[{ "99999999", 213450, 2834, 0, { [219004] = 1 } }]]) == 1)
for _, name in ipairs(CLIENTS) do login(name) end
BUS.tick(59)
assert(BUS.count({ kind = "DV" }) == 0, "no announcement in the first minute")
BUS.tick(1140)
local ALL = "11111111,22222222,33333333,44444444,55555555,66666666,77777777,88888888"
for _, name in ipairs(MEMBERS) do
    assert(ids(name) == ALL, name .. ": " .. ids(name))
    assert(kills(name) == 8, "the shared kill counts once")
end
for _, name in ipairs(CLIENTS) do
    assert(BUS.count({ kind = "DV", sender = name, chan = "GUILD" }) == 1, "one announcement after the login: " .. name)
end
-- the announcement: drop protocol, records, newest day, four weeks
local dv
for _, m in ipairs(BUS.sent) do if m.kind == "DV" and m.sender == KIM then dv = m.text end end
local today = C(KIM, "NS.DropsToday()")
local w1, w2, w3 = dv:match("^1DV\t2\t3\t" .. (today - 9) .. "\t0:0000:0,1:(%x%x%x%x):1,2:(%x%x%x%x):1,3:(%x%x%x%x):1$")
assert(w1 and w1 ~= w2 and w2 ~= w3, "DV fields: " .. dv)
-- a record that came from one client is the same everywhere
local k4 = C(KIM, "AmisiaDB.drops.k['44444444']")
for _, name in ipairs({ VULO, FRAK }) do
    local r = C(name, "AmisiaDB.drops.k['44444444']")
    assert(r.npc == k4.npc and r.day == k4.day and r.o == ME[KIM] and r.it[219004] == 2 and r.mine == nil, name)
end
assert(C(KIM, "AmisiaDB.drops.k['44444444'].mine") == true, "the own record stays the own")
-- the origins are counted, never a name
local peers = C(VULO, "AmisiaDB.drops.peers")
assert(peers[ME[KIM]] and peers[ME[FRAK]] and not peers[KIM] and not peers[FRAK])
assert(C(VULO, "AmisiaDB.drops.heard") ~= nil, "the last exchange")
-- Pug is ignored: nobody pulls from him or answers him
assert(ids(PUG) == "99999999", "Pug got nothing: " .. ids(PUG))
for _, name in ipairs(MEMBERS) do assert(not ids(name):find("99999999"), "nothing from Pug at " .. name) end
assert(BUS.count(function(m) return dropMsg(m) and m.target == PUG end) == 0, "no answer to Pug")
assert(BUS.count({ kind = "DQ", sender = PUG }) >= 1, "Pug did ask")
-- every DK set within 20 parts, all of them whispered
for _, s in pairs(dkSets(0)) do assert(s.n <= 20 and s.parts == s.n and s.target ~= nil, "a whole set of at most 20 parts") end

---------------------------------------------------------------------------
-- a new own kill: only the missing record travels
---------------------------------------------------------------------------
local before = { [FRAK] = stat(FRAK, "records"), [KIM] = stat(KIM, "records") }
local t1 = C(VULO, "STUB.clock")
C(VULO, [[STUB.instance = { name = "Halle der Thane", type = "party", id = 2834, diff = 1 }
    local cloak = STUB.item(219005, "Umhang", 3)
    STUB.loot = { { link = cloak, name = "Umhang", src = "Creature-0-3110-2834-47-213480-0000000001" } }
    STUB.fire("LOOT_OPENED")
    STUB.instance = { name = "Sturmwind", type = "none", id = 0 }]])
local newId = C(VULO, "NS.DropsKillID('Creature-0-3110-2834-47-213480-0000000001')")
assert(C(VULO, ("AmisiaDB.drops.k[%q] ~= nil"):format(newId)), "the own kill")
BUS.tick(600)
assert(BUS.count({ kind = "DV", sender = VULO, from = t1 }) == 0, "at most one announcement in 30 minutes")
BUS.tick(1500)
assert(BUS.count({ kind = "DV", sender = VULO, from = t1 }) == 1, "announced again after a new own record")
for _, name in ipairs({ FRAK, KIM }) do
    assert(C(name, ("AmisiaDB.drops.k[%q] ~= nil"):format(newId)), name .. " has the new kill")
    assert(stat(name, "records") - before[name] == 1, name .. " received only the missing record: " .. (stat(name, "records") - before[name]))
end
-- the request named what the asker had, so the answer left those out
local listed = 0
for _, m in ipairs(BUS.sent) do
    if m.kind == "DR" and m.t >= t1 and m.text:find("11111111", 1, true) then listed = listed + 1 end
end
assert(listed >= 1, "the request lists the known ids")
-- no announcement without a new own record
local t2 = C(VULO, "STUB.clock")
BUS.tick(1900)
assert(BUS.count({ kind = "DV", from = t2 }) == 0, "nothing new, no announcement")

---------------------------------------------------------------------------
-- caps: 20 parts per blob (a bigger bucket goes in several), one open request, a blob per 30 s
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
C(VULO, [[local today = NS.DropsToday()
    for i = 1, 24 do
        NS.DropsMerge({ h = ("e%07x"):format(i), npc = 213450, inst = 2834, diff = 1, day = today - 3, o = AmisiaDB.drops.me, src = "G",
                        it = { [219004] = 1, [219005] = 2, [219006 + i] = 1, [220000 + i] = 3 } })
    end]])
assert(kills(VULO) == 24)
local t3 = C(VULO, "STUB.clock")
for _, name in ipairs(CLIENTS) do login(name) end
BUS.tick(1000)
assert(kills(FRAK) == 24 and kills(KIM) == 24, "everything arrived: " .. kills(FRAK) .. " " .. kills(KIM))
local sets, fromVulo = dkSets(t3), {}
for _, s in pairs(sets) do
    assert(s.n <= 20, "at most 20 parts: " .. s.n)
    if s.sender == VULO then fromVulo[#fromVulo + 1] = s end
end
assert(#fromVulo >= 3, "a big bucket goes in several blobs: " .. #fromVulo)
table.sort(fromVulo, function(a, b) return a.first < b.first end)
for i = 2, #fromVulo do
    assert(fromVulo[i].first - fromVulo[i - 1].first >= 29.9, "one blob per 30 s")
end
-- 40 parts in any 10 minutes at most
for i = 1, #fromVulo do
    local parts = 0
    for j = i, #fromVulo do
        if fromVulo[j].first - fromVulo[i].first < 600 then parts = parts + fromVulo[j].n end
    end
    assert(parts <= 40, "40 parts per 10 minutes: " .. parts)
end
-- one open request per client: a new DR only after the answer to the last one or its time ran out
for _, name in ipairs({ FRAK, KIM }) do
    local last
    for _, m in ipairs(BUS.sent) do
        if m.t >= t3 and m.sender == name and m.kind == "DR" then
            if last then
                local answered = BUS.count(function(x) return isDK(x) and x.target == name and x.t >= last and x.t <= m.t end) > 0
                assert(answered or m.t - last >= 90, name .. ": a second request while one is open")
            end
            last = m.t
        end
    end
end
-- 30 requests per hour at most (a stats counter of the last hour)
assert(C(FRAK, "NS.DropSyncStats().drHour") <= 30)

---------------------------------------------------------------------------
-- the bytes of a session
---------------------------------------------------------------------------
BUS.reload(VULO); setup(VULO)
BUS.reload(KIM); setup(KIM); clear(KIM)
C(VULO, "NS.DROPSYNC_LIMITS.sessionBytes = 2500")
local t4 = C(VULO, "STUB.clock")
login(VULO); login(KIM)
BUS.tick(1200)
assert(bytesBy(VULO, t4) <= 2500, "the session cap: " .. bytesBy(VULO, t4))
assert(C(VULO, "NS.DropSyncStats().bytes") <= 2500)
assert(kills(KIM) < 24, "the cap stopped the answers: " .. kills(KIM))
-- the real cap is 60 KB
BUS.reload(VULO); setup(VULO)
assert(C(VULO, "NS.DROPSYNC_LIMITS.sessionBytes") == 61440 and C(VULO, "NS.DROPSYNC_LIMITS.blobParts") == 20)

---------------------------------------------------------------------------
-- nothing in an instance, in combat, in the lockdown or while a raid is synced
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
add(VULO, [[{ "f0000001", 213450, 2834, 0 }]])
add(KIM, [[{ "f0000002", 213450, 2834, 1 }]])
C(KIM, [[STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }]])
assert(C(KIM, "NS.DropSyncCanTalk()") == false)
local t5 = C(KIM, "STUB.clock")
for _, name in ipairs(CLIENTS) do login(name) end
BUS.tick(400)
assert(sentBy(KIM, t5) == 0, "nothing from a raid instance")
assert(ids(KIM) == "f0000002", "no pulling in an instance")
assert(ids(FRAK) == "f0000001", "Vulo's kill reached Fraktur")
-- combat holds too; leaving both lets the first announcement go
C(KIM, [[STUB.instance = { name = "Sturmwind", type = "none", id = 0 }; STUB.combat = true]])
assert(C(KIM, "NS.DropSyncCanTalk()") == false)
BUS.tick(60)
assert(sentBy(KIM, t5) == 0, "nothing in combat")
C(KIM, "STUB.combat = false")
BUS.tick(400)
assert(BUS.count({ kind = "DV", sender = KIM, from = t5 }) == 1, "the announcement after leaving")
assert(ids(VULO) == "f0000001,f0000002" and ids(FRAK) == "f0000001,f0000002")
assert(ids(KIM) == "f0000001,f0000002", ids(KIM))
-- the lockdown: nothing at all while it holds
BUS.reload(FRAK); setup(FRAK); clear(FRAK)
add(FRAK, [[{ "f0000003", 213451, 2834, 0 }]])
BUS.lock(true)
assert(C(FRAK, "NS.DropSyncCanTalk()") == false)
local t6 = C(FRAK, "STUB.clock")
login(FRAK)
BUS.tick(400)
assert(BUS.count(function(m) return dropMsg(m) and m.t >= t6 end) == 0, "nothing in the lockdown")
BUS.lock(false)
BUS.tick(400)
assert(ids(VULO) == "f0000001,f0000002,f0000003", "after the lockdown: " .. ids(VULO))
-- a running raid recording with sync: no exchange
C(VULO, [[REAL_ACTIVE = NS.Active; NS.Active = function() return { date = "2026-09-10", instanceID = 409 } end]])
assert(C(VULO, "NS.DropSyncCanTalk()") == false, "a raid is synced")
C(VULO, "NS.Set('sync.enabled', false)")
assert(C(VULO, "NS.DropSyncCanTalk()") == true, "a recording without sync does not hold it")
C(VULO, "NS.Set('sync.enabled', true); NS.Active = REAL_ACTIVE")
-- the switch
C(VULO, "NS.Set('drops.share', false)")
assert(C(VULO, "NS.DropSyncCanTalk()") == false)
C(VULO, "NS.Set('drops.share', true)")

---------------------------------------------------------------------------
-- forged, malformed and unasked blobs are refused whole
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do BUS.reload(name); setup(name); clear(name) end
add(VULO, [[{ "f1000001", 213450, 2834, 1, { [219004] = 1 } }]])
local KEY = C(VULO, "NS.DropsDate(NS.DropsToday() - 1) .. ':2834'")
local DAY = C(VULO, "NS.DropsToday() - 1")
-- Fraktur asks, but Vulo's answer is lost
BUS.drop(function(m) return m.sender == VULO and isDK(m) end)
login(VULO); login(FRAK)
BUS.tick(300)
assert(BUS.count({ kind = "DR", sender = FRAK, target = VULO }) >= 1, "Fraktur asked for the bucket")
assert(kills(FRAK) == 0)
BUS.drop(nil)
local function forge(tbl, key)
    local bad0 = stat(FRAK, "bad")
    C(VULO, ("assert(NS.CommSendBlob('DK', %q, %s, 'WHISPER', 'Fraktur', {}))"):format(key or KEY, tbl))
    BUS.tick(10)
    return stat(FRAK, "bad") - bad0
end
local good = ("{ %q, 213450, 2834, 1, %d, %q, 0, { 219004, 1 }, 'G' }"):format("f1000001", DAY, ME[VULO])
local function blob(rows, extra) return "{ v = 1, r = { " .. rows .. " }" .. (extra or "") .. " }" end
local forged = {
    blob(("{ 'f1000002', 213450, 2834, 1, %d, %q, 0, {}, 'G' }"):format(DAY - 1, ME[VULO])),          -- another day than the key
    blob(("{ 'f1000002', 213450, 409, 1, %d, %q, 0, {}, 'G' }"):format(DAY, ME[VULO])),               -- another instance
    blob(("{ 'xyz', 213450, 2834, 1, %d, %q, 0, {}, 'G' }"):format(DAY, ME[VULO])),                   -- a bad id
    blob(("{ 'f1000002', 213450, 2834, 1, %d, 'Vuloo', 0, {}, 'G' }"):format(DAY)),                   -- a name as origin
    blob(("{ 'f1000002', 213450, 2834, 1, %d, %q, 0, { 1, 201 }, 'G' }"):format(DAY, ME[VULO])),      -- too many of one item
    blob(("{ 'f1000002', 0, 2834, 1, %d, %q, 0, {}, 'G' }"):format(DAY, ME[VULO])),                   -- a corpse without NPC
    blob(("{ 'f1000002', 213450, 2834, 1, %d, %q, 0, {}, 'X' }"):format(DAY, ME[VULO])),              -- a bad source
    blob(good .. ", " .. ("{ 'f1000002', 213450, 2834, 1, %d, %q, 0, { 0, 1 }, 'G' }"):format(DAY, ME[VULO])),   -- one bad among good
    blob(good, ", n = { [213450] = 'Faldrim|cff0000' }"),                                             -- a bar in a name
    blob(good, ", z = { [2834] = { 'pvp', 'Halle' } }"),                                              -- a bad kind
    "{ v = 2, r = { " .. good .. " } }",                                                              -- another version
    "{ v = 1, r = {} }",                                                                              -- empty
}
-- thirty-one items in one record
local many = {}
for i = 1, 31 do many[#many + 1] = (219000 + i) .. ", 1" end
forged[#forged + 1] = blob(("{ 'f1000002', 213450, 2834, 1, %d, %q, 0, { %s }, 'G' }"):format(DAY, ME[VULO], table.concat(many, ", ")))
for i, tbl in ipairs(forged) do
    assert(forge(tbl) == 1, "refused: " .. i)
    assert(kills(FRAK) == 0, "nothing taken from forged blob " .. i)
end
-- a well-formed blob for the asked bucket is taken, with its names
assert(forge(blob(good, ", n = { [213450] = 'Faldrim Ambossmahl' }, z = { [2834] = { 'party', 'Halle der Thane' } }")) == 0)
assert(ids(FRAK) == "f1000001" and C(FRAK, "AmisiaDB.drops.npc[213450]") == "Faldrim Ambossmahl")
assert(C(FRAK, "AmisiaDB.drops.inst[2834][2]") == "Halle der Thane")
-- a name heard never overwrites a known one
assert(forge(blob(good, ", n = { [213450] = 'Anderer Name' }")) == 0)
assert(C(FRAK, "AmisiaDB.drops.npc[213450]") == "Faldrim Ambossmahl")
-- a bucket nobody asked for is not taken (no pushing)
local other = ("{ 'f1000009', 213450, 2834, 1, %d, %q, 0, {}, 'G' }"):format(DAY - 2, ME[VULO])
local unasked0 = stat(FRAK, "unasked")
C(VULO, ("assert(NS.CommSendBlob('DK', %q, %s, 'WHISPER', 'Fraktur', {}))"):format(C(VULO, "NS.DropsDate(NS.DropsToday() - 3) .. ':2834'"), blob(other)))
BUS.tick(10)
assert(stat(FRAK, "unasked") == unasked0 + 1 and ids(FRAK) == "f1000001", "unasked data is dropped")
-- the same from Pug, even for the asked bucket: his parts are dropped unread
C(PUG, ("NS.CommSendBlob('DK', %q, %s, 'WHISPER', 'Fraktur', {})"):format(KEY,
    blob(("{ 'f1000003', 213450, 2834, 1, %d, %q, 0, {}, 'G' }"):format(DAY, ME[PUG]))))
BUS.tick(10)
assert(ids(FRAK) == "f1000001", "nothing from Pug")
-- Pug's requests get no answer
local t7 = C(PUG, "STUB.clock")
C(PUG, "NS.CommSend('DQ', { '0' }, 'WHISPER', 'Vulo Sturmwind')")
C(PUG, ("NS.CommSend('DR', { %q, '*' }, 'WHISPER', 'Vulo Sturmwind')"):format(KEY))
BUS.tick(120)
assert(BUS.count(function(m) return m.t >= t7 and m.target == PUG end) == 0, "no answer to Pug")
-- malformed control messages are dropped by the layer
C(FRAK, "STATS0 = NS.CommStats().bad")
for _, text in ipairs({ "1DV\t1\t5\t3\t9:abcd:1", "1DQ\t7", "1DI\t0\t2\t1\t1:2834:abcd:1", "1DR\tnokey\t*", "1DR\t2026-09-09:2834\txyz" }) do
    C(FRAK, ("STUB.fire('CHAT_MSG_ADDON', 'Amisia', %q, 'WHISPER', 'Vulo Sturmwind', 'Fraktur', 0, 0, '', 0)"):format(text))
end
assert(C(FRAK, "NS.CommStats().bad - STATS0") == 5)
-- a DK blob of more than 20 parts is refused by the layer on both ends
assert(C(VULO, [[local t = { v = 1, r = {} }
    for i = 1, 300 do t.r[i] = { ("%08x"):format(i), 213450, 2834, 1, 1, "a0000001", 0, { 219004, 1, 219005, 2 }, "G" } end
    return NS.CommSendBlob("DK", "2026-09-09:2834", t, "WHISPER", "Fraktur", {})]]) == nil)
C(FRAK, "STATS0 = NS.CommStats().bad")
C(FRAK, [[STUB.fire('CHAT_MSG_ADDON', 'AmisiaD', '1BL\tDK\t2026-09-09:2834\t5\t1\t21\tQUJD', 'WHISPER', 'Vulo Sturmwind', 'Fraktur', 0, 0, '', 0)]])
assert(C(FRAK, "NS.CommStats().bad - STATS0") == 1, "21 parts")

---------------------------------------------------------------------------
-- the raid sync's data goes first; low entries wait and fall after 120 s
---------------------------------------------------------------------------
C(VULO, [[DK_BLOB = { v = 1, r = {} }
    for i = 1, 8 do DK_BLOB.r[i] = { ("%08x"):format(i), 213450, 2834, 1, 1, "a0000001", 0, { 219004, 1 }, "G" } end
    SP_BLOB = { k = "2026-09-10:409", a = {} }
    for i = 1, 30 do SP_BLOB.a[i] = { ("%012x"):format(i), "Spieler " .. i, 30000 + i, "MS" } end]])
-- the raid sync is busy when the drop blob is queued: its parts wait for all of the raid's
local function order(from)
    local lastRaid, firstLow, firstRaid, lowBetween = 0, math.huge, math.huge, 0
    for _, m in ipairs(BUS.sent) do
        if m.sender == VULO and m.t >= from and not isDK(m) and (m.prefix == "AmisiaD" or m.kind == "HI") then
            lastRaid, firstRaid = math.max(lastRaid, m.t), math.min(firstRaid, m.t)
        end
    end
    for _, m in ipairs(BUS.sent) do
        if m.sender == VULO and m.t >= from and isDK(m) then
            firstLow = math.min(firstLow, m.t)
            if m.t > firstRaid and m.t < lastRaid then lowBetween = lowBetween + 1 end
        end
    end
    return lastRaid, firstLow, lowBetween
end
local t8 = C(VULO, "STUB.clock")
C(VULO, [[assert(NS.CommSendBlob("SP", "2026-09-10:409", SP_BLOB, "WHISPER", "Fraktur", {}))
    assert(NS.CommSendBlob("DK", "2026-09-09:2834", DK_BLOB, "WHISPER", "Fraktur", { low = true }))
    assert(NS.CommSend("HI", { "2.3.0", "1", "-", "-" }, "WHISPER", "Fraktur"))]])
BUS.tick(60)
local lastRaid, firstLow = order(t8)
assert(lastRaid > 0 and firstLow < math.huge, "both went")
assert(lastRaid <= firstLow, "the raid data and the control message first: " .. lastRaid .. " " .. firstLow)
-- a drop blob already going when raid data comes: its waiting parts step back
local t8b = C(VULO, "STUB.clock")
C(VULO, [[assert(NS.CommSendBlob("DK", "2026-09-09:2834", DK_BLOB, "WHISPER", "Fraktur", { low = true }))
    assert(NS.CommSendBlob("SP", "2026-09-10:409", SP_BLOB, "WHISPER", "Fraktur", {}))]])
BUS.tick(60)
local lastRaid2, _, between = order(t8b)
assert(lastRaid2 > 0 and between == 0, "no drop part while raid data waits: " .. between)
assert(BUS.count(function(m) return m.sender == VULO and m.t > lastRaid2 and isDK(m) end) >= 1, "the rest of the drop blob after it")
-- a low entry that may not go falls after its 120 s
assert(C(VULO, [[return NS.CommSend("DV", { "1", "1", "1", "0:abcd:1" }, "GUILD", nil, { low = true, when = function() return false end })]]) == true)
local t9 = C(VULO, "STUB.clock")
BUS.tick(121)
assert(C(VULO, "NS.CommQueueSize()") == 0 and BUS.count({ kind = "DV", sender = VULO, from = t9 }) == 0)
