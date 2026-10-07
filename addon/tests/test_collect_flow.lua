--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Throughput of the source exchange (review 26): Vulo Sturmwind holds 1200 own quests, Fraktur and
-- Kim Eisherz pull. Every request gets an answer, a blob or a CW (busy: when to come back); nothing
-- is dropped silently, so an asker never waits out its timeout for a sender that will not answer.
-- A cut blob is followed at once by the rest; an asker's share of the sender's bytes is used up
-- in whole (the last blob sized to what is left), then a long CW sends the asker away.
--
-- Limits since 2026-10-07 (CollectSync.lua). The stub's CompressString does not compress, so a blob here holds about 17 typical quest records
-- in its 20 parts; deflate in the client packs several times as many. The numbers printed are the
-- stub's.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 2 } })
BUS.guild = { VULO, FRAK, KIM }
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.instance = { name = "Durotar", type = "none", id = 0 }
        STUB.combat = false
        AmisiaDB.drops.me = "%d0000001"
        STUB.fire("GUILD_ROSTER_UPDATE")]]):format(i))
end
local function fill(name, base, count)
    C(name, "local N, BASE = " .. (count or 1200) .. ", " .. (base or 30000) .. [[ local D = NS.DropsToday()
    for i = 1, N do
      assert(NS.CollectPut("q", BASE + i, ("%d;0;%d;1440:%d:%d;%d;1440:4512:3321;%d,%d;%d,%d,%d;%d;%d;H;%d;Questgeber Name %d;Eine typische Quest mit Titel %d"):format(
            D, 3000 + i, 1000 + i % 9000, 2000 + i % 7000, 4000 + i, 200000 + i, 200001 + i, 210000 + i, 210001 + i, 210002 + i, 20 + i % 40, 18 + i % 40, i, i, i), "own"))
    end]])
end
local function isCK(m) return m.prefix == "AmisiaD" and m.text:match("^%dBL\tCK\t") ~= nil end
local function qn(name) return C(name, "NS.CollectCounts().q") end
local L = C(VULO, "NS.COLLECTSYNC_LIMITS")
local function reset()
    for _, name in ipairs(CLIENTS) do
        BUS.reload(name)
        C(name, [[STUB.instance = { name = "Durotar", type = "none", id = 0 }; STUB.combat = false; STUB.fire("GUILD_ROSTER_UPDATE")]])
        C(name, "AmisiaDB.collect = nil; NS.CollectMigrate(AmisiaDB); NS.Set('collect.share', true)")
    end
end
local SHARE = L.sessionBytes / L.askerShare

-- every request (CQ, CR) of an asker to Vulo is answered by Vulo within the asker's wait
local function answered(asker, from)
    local open = {}
    for _, m in ipairs(BUS.sent) do
        if m.t >= from and m.sender == asker and m.target == VULO and (m.kind == "CR" or m.kind == "CQ") then
            open[#open + 1] = m
        end
    end
    for _, q in ipairs(open) do
        local wait = q.kind == "CR" and L.crWait or L.ciWait
        local ok = false
        for _, m in ipairs(BUS.sent) do
            if m.sender == VULO and m.target == asker and m.t >= q.t - 0.5 and m.t <= q.t + wait
                and (m.kind == "CW" or (q.kind == "CR" and isCK(m)) or (q.kind == "CQ" and m.kind == "CI")) then
                ok = true
                break
            end
        end
        assert(ok, ("%s's %s at %.1f got no answer: %s"):format(asker, q.kind, q.t, q.text))
    end
    return #open
end
-- bytes Vulo sent to target as answers (CW left out: it may go beyond the caps, within a small
-- reserve; CQ and CR left out: Vulo's own requests when it pulls from the asker in turn)
local ANSWER = { CI = true, BL = true }
local function bytesTo(target, from)
    local n = 0
    for _, m in ipairs(BUS.sent) do
        if m.sender == VULO and m.target == target and m.t >= from and ANSWER[m.kind] then n = n + #m.prefix + #m.text end
    end
    return n
end

---------------------------------------------------------------------------
-- one asker: the share in full, then a long CW and silence
---------------------------------------------------------------------------
fill(VULO)
C(KIM, "NS.Set('collect.share', false)")
local t0 = C(VULO, "STUB.clock")
C(VULO, "STUB.fire('PLAYER_LOGIN')"); C(FRAK, "STUB.fire('PLAYER_LOGIN')")
local marks = {}
for step = 1, 12 do
    BUS.tick(300)
    marks[step] = qn(FRAK)
end
print(("one asker, records at Fraktur every 5 minutes: %s"):format(table.concat(marks, " ")))
print(("Vulo sent Fraktur %d bytes (share %d), %d blob parts, %d CW; Fraktur sent %d CR"):format(bytesTo(FRAK, t0), SHARE,
    BUS.count(function(m) return isCK(m) and m.target == FRAK end), BUS.count({ kind = "CW", target = FRAK }),
    BUS.count({ kind = "CR", sender = FRAK })))
answered(FRAK, t0)
assert(C(FRAK, "NS.CollectSyncStats().missed") == 0, "no blob missed")
-- the share is used up (the last blob sized to what is left) and not overrun by more than a part
assert(bytesTo(FRAK, t0) <= SHARE + 250, "within the share: " .. bytesTo(FRAK, t0))
assert(bytesTo(FRAK, t0) >= SHARE - 500, "the share used up (within two parts): " .. bytesTo(FRAK, t0))
-- the share (96 KB) pays for the bucket lists too (about 740 bytes per CQ): about 350 records here
-- (before 2026-10-07: 16 KB, about 55), paced by the parts window (120 in 10 minutes)
assert(marks[2] >= 90, "a first lot within 10 minutes: " .. marks[2])
assert(marks[8] >= 330, "the share arrives within 40 minutes: " .. marks[8])
assert(marks[12] == marks[8], "then nothing more this session")
-- the share is spent: Vulo says so with a long wait, and Fraktur does not ask again within it
local cw = 0
for _, m in ipairs(BUS.sent) do
    if m.kind == "CW" and m.target == FRAK then cw = math.max(cw, tonumber(m.text:match("^%dCW\t(%d+)"))) end
end
assert(cw >= 1800, "a long CW once the share is spent: " .. cw)
local lastCW = 0
for _, m in ipairs(BUS.sent) do if m.kind == "CW" and m.target == FRAK then lastCW = m.t end end
assert(BUS.count(function(m) return m.sender == FRAK and m.target == VULO and (m.kind == "CQ" or m.kind == "CR") and m.t > lastCW and m.t < lastCW + 1800 end) == 0,
    "no request after the long CW")

---------------------------------------------------------------------------
-- two askers at once: the parts window is shared; the one who has to wait is told how long
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do
    BUS.reload(name)
    C(name, [[STUB.instance = { name = "Durotar", type = "none", id = 0 }; STUB.combat = false; STUB.fire("GUILD_ROSTER_UPDATE")]])
    C(name, "AmisiaDB.collect = nil; NS.CollectMigrate(AmisiaDB); NS.Set('collect.share', true)")
end
fill(VULO)
local t1 = C(VULO, "STUB.clock")
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end
local m2 = {}
for step = 1, 12 do
    BUS.tick(300)
    m2[step] = qn(FRAK) .. "/" .. qn(KIM)
end
print(("two askers, records at Fraktur/Kim every 5 minutes: %s"):format(table.concat(m2, " ")))
print(("Vulo sent %d bytes in all (session cap %d)"):format(bytesTo(FRAK, t1) + bytesTo(KIM, t1), L.sessionBytes))
answered(FRAK, t1)
answered(KIM, t1)
for _, name in ipairs({ FRAK, KIM }) do
    assert(C(name, "NS.CollectSyncStats().missed") == 0, name .. " missed no blob")
    -- the parts window is shared: about 300 each in an hour
    assert(qn(name) >= 280, name .. " got its part: " .. qn(name))
end
assert(BUS.count(function(m) return m.kind == "CW" and m.sender == VULO and m.t >= t1 end) >= 1, "someone was told to wait")

---------------------------------------------------------------------------
-- lost blobs: after two missed answers the asker stops and waits before it asks again
---------------------------------------------------------------------------
for _, name in ipairs(CLIENTS) do
    BUS.reload(name)
    C(name, [[STUB.instance = { name = "Durotar", type = "none", id = 0 }; STUB.combat = false; STUB.fire("GUILD_ROSTER_UPDATE")]])
    C(name, "AmisiaDB.collect = nil; NS.CollectMigrate(AmisiaDB)")
end
C(KIM, "NS.Set('collect.share', false)")
fill(VULO)
BUS.drop(function(m) return isCK(m) and m.sender == VULO end)
local t2 = C(VULO, "STUB.clock")
for _, name in ipairs({ VULO, FRAK }) do C(name, "STUB.fire('PLAYER_LOGIN')") end
BUS.tick(900)
local crs = {}
for _, m in ipairs(BUS.sent) do
    if m.kind == "CR" and m.sender == FRAK and m.t >= t2 then crs[#crs + 1] = m.t end
end
assert(#crs == 2 and C(FRAK, "NS.CollectSyncStats().missed") == 2, "two requests, both missed: " .. #crs)
assert(C(FRAK, "NS.CollectSyncState().pulling") == nil, "the pull stopped")
BUS.drop(nil)
BUS.tick(900)
local again
for _, m in ipairs(BUS.sent) do
    if m.kind == "CQ" and m.sender == FRAK and m.t > crs[2] then again = again or m.t end
end
assert(again and again - (crs[2] + L.crWait) >= L.missWait, "asked again only after the wait")
assert(qn(FRAK) > 0, "and then got records")

---------------------------------------------------------------------------
-- a new member and two senders: records per hour (the goal of 2026-10-07: a few hundred in an
-- evening from two or three senders). Vulo and Kim hold 600 quests each (different ones); they
-- pull from each other as well, so each sender's window is shared by two askers.
---------------------------------------------------------------------------
reset()
fill(VULO, 30000, 600)
fill(KIM, 40000, 600)
for _, name in ipairs(CLIENTS) do C(name, "STUB.fire('PLAYER_LOGIN')") end
local m3 = {}
for step = 1, 12 do
    BUS.tick(300)
    m3[step] = qn(FRAK)
end
print(("two senders, records at the new member Fraktur every 5 minutes: %s"):format(table.concat(m3, " ")))
assert(C(FRAK, "NS.CollectSyncStats().missed") == 0, "no blob missed")
assert(m3[12] >= 450, "a new member gets several hundred records in an hour from two senders: " .. m3[12])
