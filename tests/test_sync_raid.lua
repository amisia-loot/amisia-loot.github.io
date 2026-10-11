--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz Pug]]
-- The raid sync (Sync.lua) between clients: Vulo Sturmwind is master looter and officer and keeps
-- the running raid, Fraktur is an officer, Kim Eisherz a raider, Pug a guest outside the guild.
-- The keeper sends the whole raid as one snapshot (public part to the raid, officer part by
-- whisper), the others follow; keeper choice and change, the lockdown, lost parts, re-requests,
-- invalid and forged snapshots, and the export of a synced raid.
local VULO, FRAK, KIM, PUG = "Vulo Sturmwind", "Fraktur", "Kim Eisherz", "Pug"

-- code with the running raid as s; an expression gives its value back
local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function count(name, text)
    return C(name, ("local n = 0; for _, m in ipairs(STUB.messages) do if m:find(%q, 1, true) then n = n + 1 end end; return n"):format(text))
end
-- the awards of a client: id -> { name, item, kind, to, note, orig, manual, v, edited }
local function awards(name)
    return S(name, [[local out = {}
        for _, a in ipairs(s.awards) do out[a.id] = { name = a.name, item = a.item, kind = a.kind, to = a.to, note = a.note,
            orig = a.orig, manual = a.manual, v = a.v, edited = a.edited, t = a.t } end
        return out]])
end
local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
-- a change at the keeper and its snapshot (3 s later) through the throttled queue
local function settle() BUS.tick(8) end
-- the A, AS, AX and AD lines of the export of the running raid
local function awardLines(name)
    return S(name, [[local out = {}
        for line in (NS.ExportText({ s }) .. "\n"):gmatch("([^\n]*)\n") do
            local head = line:match("^(%u+) ")
            if head == "A" or head == "AS" or head == "AX" or head == "AD" or head == "BN" then out[#out + 1] = line end
        end
        return table.concat(out, "\n")]])
end
-- each client sees raid member i as leader (STUB.leader for the own raid unit)
local function setLeader(i)
    for _, name in ipairs(CLIENTS) do
        C(name, ([[for j, m in ipairs(STUB.roster) do m.leader = (j == %d) end
            STUB.leader = STUB.playerRaidIndex == %d
            STUB.fire("PARTY_LEADER_CHANGED")]]):format(i, i))
    end
end
local function setMaster(i)
    for _, name in ipairs(CLIENTS) do
        C(name, ([[STUB.lootMethod = %d; STUB.mlRaidID = %s; STUB.fire("PARTY_LOOT_METHOD_CHANGED")]]):format(i and 2 or 0, tostring(i)))
    end
end

---------------------------------------------------------------------------
-- the raid: everyone records the same night and instance
---------------------------------------------------------------------------
BUS.setRaid({ VULO, FRAK, KIM, PUG })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        if STUB.player == "Pug" then STUB.inGuild = false end
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
local KEY = S(VULO, "NS.RaidKey(s)")
assert(KEY and KEY:match("^%d%d%d%d%-%d%d%-%d%d:564$"), tostring(KEY))
assert(S(VULO, "s.date .. ':' .. s.instanceID") == KEY)
for _, name in ipairs({ FRAK, KIM, PUG }) do assert(S(name, "NS.RaidKey(s)") == KEY, name) end
-- the keeper: the master looter with officer rank, the same on every client of the guild
assert(C(VULO, "NS.SyncIsKeeper()") == true)
for _, name in ipairs({ VULO, FRAK, KIM }) do assert(C(name, "NS.SyncKeeperName()") == VULO, name) end
assert(C(FRAK, "NS.SyncIsKeeper()") == false and C(KIM, "NS.SyncIsKeeper()") == false)
assert(C(PUG, "NS.SyncKeeperName()") == nil, "Pug cannot check anyone")
assert(BUS.count({ kind = "ST", sender = VULO, chan = "RAID" }) >= 1)
assert(BUS.count({ kind = "ST", sender = FRAK }) == 0 and BUS.count({ kind = "ST", sender = KIM }) == 0, "only the lead claims")
-- the first snapshot of an empty raid reached everyone
local rev0 = S(VULO, "s.sync.rev")
assert(rev0 >= 1, "the first snapshot has a revision")
assert(S(FRAK, "s.sync and s.sync.rev") == rev0 and S(KIM, "s.sync and s.sync.rev") == rev0)
assert(S(FRAK, "s.sync.keeper") == VULO and S(FRAK, "s.sync.hash") == S(VULO, "s.sync.hash"))
assert(S(VULO, "s.sync.hash") == S(VULO, "NS.SyncHash(s)"))
assert(S(PUG, "s.sync") == nil, "the guest takes nothing")

---------------------------------------------------------------------------
-- a new award at the keeper: Fraktur gets it with the note, Kim without, the same hash
---------------------------------------------------------------------------
local frakLast, frakMembers = S(FRAK, "s.last"), S(FRAK, "s.members")
local kimLast = S(KIM, "s.last")
local a1 = S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 32235, kind = 'MS', src = 'Ragnaros', note = 'Tausch mit Vuloo', t = time() }).id")
assert(S(VULO, "s.sync.rev") == rev0 + 1, "the revision rises with the change")
assert(S(VULO, "s.awards[1].v") == 1, "the keeper counts the award's revision")
local sentBefore = BUS.count({ prefix = "AmisiaD", sender = VULO })
BUS.tick(2.5)
assert(BUS.count({ prefix = "AmisiaD", sender = VULO }) == sentBefore, "the snapshot waits 3 s")
BUS.tick(2)
assert(BUS.count({ prefix = "AmisiaD", sender = VULO }) > sentBefore, "then it goes")
local fa, ka = awards(FRAK), awards(KIM)
assert(fa[a1] and fa[a1].name == "Fraktur" and fa[a1].item == 32235 and fa[a1].kind == "MS" and fa[a1].note == "Tausch mit Vuloo", "Fraktur with the note")
assert(ka[a1] and ka[a1].name == "Fraktur" and ka[a1].note == nil and ka[a1].v == 1, "Kim without the note")
assert(fa[a1].t == S(VULO, "math.floor(s.awards[1].t)"), "the time stays the keeper's (in whole seconds)")
assert(S(FRAK, "s.sync.rev") == rev0 + 1 and S(KIM, "s.sync.rev") == rev0 + 1)
assert(S(FRAK, "s.sync.hash") == S(VULO, "s.sync.hash") and S(KIM, "s.sync.hash") == S(VULO, "s.sync.hash"), "one checksum")
assert(S(FRAK, "NS.SyncHash(s)") == S(VULO, "s.sync.hash"), "Fraktur's own state gives the keeper's checksum")
assert(S(FRAK, "s.last") == frakLast and S(KIM, "s.last") == kimLast, "s.last stays")
local m2 = S(FRAK, "s.members")
assert(size(m2) == size(frakMembers), "s.members stays")
for k, v in pairs(frakMembers) do assert(m2[k] and m2[k].first == v.first, k) end
-- the plus-one of the keeper goes along
assert(S(KIM, "s.sync.plus.n['Fraktur']") == 1 and S(KIM, "s.sync.plus.s") == S(VULO, "NS.PlusScope()"))
-- the raider never gets the officer part
assert(BUS.count({ kind = "BL", target = KIM }) == BUS.count(function(m) return m.kind == "BL" and m.target == KIM and m.text:find("\tSP\t", 1, true) end))
assert(BUS.count(function(m) return m.kind == "BL" and m.text:find("^1BL\tSO\t") and m.target ~= FRAK end) == 0, "SO only to Fraktur")
assert(BUS.count(function(m) return m.kind == "BL" and m.text:find("^1BL\tSO\t") and m.chan ~= "WHISPER" end) == 0)

---------------------------------------------------------------------------
-- several changes in a row make one snapshot (3 s after the last, at most 10 s after the first)
---------------------------------------------------------------------------
local function spSets(from)
    local seqs, n = {}, 0
    for _, m in ipairs(BUS.sent) do
        local seq = m.kind == "BL" and m.sender == VULO and m.chan == "RAID" and m.t >= from and m.text:match("^1BL\tSP\t[^\t]+\t(%d+)\t")
        if seq and not seqs[seq] then seqs[seq] = true; n = n + 1 end
    end
    return n
end
local t1 = C(VULO, "STUB.clock")
local a2 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 30000, kind = 'OS', src = 'Ragnaros', t = time() }).id")
for _ = 1, 4 do
    BUS.tick(2)
    S(VULO, "NS.EditAward(s, '" .. a2 .. "', { note = 'Runde ' .. STUB.clock })")
end
assert(spSets(t1) == 0, "pushed on while changes come")
BUS.tick(2.5)
assert(spSets(t1) == 1, "at most 10 s after the first change")
settle()
assert(spSets(t1) == 1, "one snapshot for all")
assert(awards(KIM)[a2].kind == "OS" and awards(FRAK)[a2].note:find("^Runde"))

---------------------------------------------------------------------------
-- delete, restore, rename and undo at the keeper reach everyone
---------------------------------------------------------------------------
S(VULO, "NS.DeleteAward(s, '" .. a2 .. "')")
settle()
assert(awards(KIM)[a2] == nil and S(KIM, "s.gone[1] and s.gone[1].id") == a2, "a tombstone at Kim")
assert(awards(FRAK)[a2] == nil and S(FRAK, "s.gone[1].id") == a2 and S(FRAK, "s.gone[1].deleted") == S(VULO, "math.floor(s.gone[1].deleted)"))
S(VULO, "NS.RestoreAward(s, '" .. a2 .. "')")
settle()
assert(awards(KIM)[a2] and S(KIM, "#s.gone") == 0)
assert(S(VULO, "NS.RenameAwards(s, 'Fraktur', 'Fraktur Sturm')") == 1)
settle()
local fr = awards(FRAK)[a1]
assert(fr.name == "Fraktur Sturm" and fr.orig == "Fraktur", "the first winner goes to officers")
assert(awards(KIM)[a1].name == "Fraktur Sturm" and awards(KIM)[a1].orig == nil)
local revBefore = S(VULO, "s.sync.rev")
assert(C(VULO, "NS.UndoAward()"):find("Umbenennen", 1, true))
assert(S(VULO, "s.sync.rev") > revBefore, "an undo is a change")
settle()
assert(awards(FRAK)[a1].name == "Fraktur" and awards(KIM)[a1].name == "Fraktur")
assert(S(VULO, "s.awards[1].v") >= 3, "every change of the award counts: " .. S(VULO, "s.awards[1].v"))
assert(awards(KIM)[a1].v == S(VULO, "s.awards[1].v"))

---------------------------------------------------------------------------
-- the bench and the kills only to officers; own kills stay, missing ones are added
---------------------------------------------------------------------------
S(FRAK, "NS.AddKill(s, { name = 'Lucifron', enc = 663, t = time() - 100, start = time() - 200 })")
S(VULO, "NS.AddKill(s, { name = 'Lucifron', enc = 663, t = time() - 60, start = time() - 200 })")
S(VULO, "NS.AddKill(s, { name = 'Ragnaros', enc = 672, t = time() - 30, start = time() - 300 })")
S(VULO, "NS.BenchAdd(s, 'Bob', { note = 'ab 21 Uhr', class = 'MAGE' })")
settle()
local kills = S(FRAK, "local out = {}; for i, k in ipairs(s.kills) do out[i] = k.name .. ':' .. k.src end; return out")
assert(#kills == 2 and kills[1] == "Lucifron:hand" and kills[2] == "Ragnaros:hand", table.concat(kills, ","))
assert(S(FRAK, "#s.kills[2].who") == 0, "kills come without who was there")
assert(S(FRAK, "s.bench.Bob and s.bench.Bob.note") == "ab 21 Uhr" and S(FRAK, "s.bench.Bob.by") == VULO and S(FRAK, "s.bench.Bob.class") == "MAGE")
assert(S(KIM, "#s.kills") == 0 and S(KIM, "next(s.bench)") == nil, "the raider gets neither")
-- an own kill is never deleted, an own kill the keeper has is not doubled
S(FRAK, "NS.AddKill(s, { name = 'Garr', enc = 666, t = time() - 10 })")
S(VULO, "NS.BenchRemove(s, 'Bob')")
settle()
assert(S(FRAK, "#s.kills") == 3 and S(FRAK, "next(s.bench)") == nil, "Garr stays, Bob goes")

---------------------------------------------------------------------------
-- the export of the synced raid: the same award, tombstone and bench lines as the keeper
---------------------------------------------------------------------------
S(VULO, "NS.DeleteAward(s, '" .. a2 .. "')")
S(VULO, "NS.BenchAdd(s, 'Bob', { note = 'ab 21 Uhr', class = 'MAGE' })")
settle()
local lines = awardLines(VULO)
assert(lines:find("AD " .. a2, 1, true) and lines:find("AX " .. a1, 1, true) and lines:find("BN Bob MAGE", 1, true), lines)
assert(awardLines(FRAK) == lines, "Fraktur exports what the keeper exports:\n" .. awardLines(FRAK) .. "\n--\n" .. lines)
-- a snapshot that changes nothing leaves an exported raid exported
S(FRAK, "NS.MarkExported({ s })")
local hash = S(FRAK, "NS.SessionHash(s)")
assert(S(FRAK, "NS.ExportState(s)") == "done")
S(FRAK, "s.sync.hash = '0123456789abcdef'")
BUS.tick(301)
assert(S(FRAK, "s.sync.hash") == S(VULO, "s.sync.hash"), "the mismatching checksum was asked for again")
assert(BUS.count({ kind = "RQ", sender = FRAK, target = VULO }) >= 1)
assert(S(FRAK, "NS.SessionHash(s)") == hash and S(FRAK, "NS.ExportState(s)") == "done", "still exported")
-- the keeper's own sync fields are not in the export either
S(VULO, "NS.MarkExported({ s })")
local vhash = S(VULO, "NS.SessionHash(s)")
local oldV = S(VULO, "s.awards[1].v")
S(VULO, "s.awards[1].v = 99; s.sync.rev = s.sync.rev + 1")
assert(S(VULO, "NS.SessionHash(s)") == vhash and S(VULO, "NS.ExportState(s)") == "done")
S(VULO, "s.awards[1].v = " .. oldV .. "; s.sync.rev = s.sync.rev - 1")

---------------------------------------------------------------------------
-- the lockdown: three changes in a boss fight, after it exactly one snapshot
---------------------------------------------------------------------------
BUS.lock(true)
local tl = C(VULO, "STUB.clock")
local a3 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 30001, kind = 'MS', src = 'Golemagg', t = time() }).id")
BUS.tick(5)
S(VULO, "NS.EditAward(s, '" .. a3 .. "', { kind = 'SR' })")
BUS.tick(5)
S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30002, kind = 'MS', src = 'Golemagg', t = time() })")
BUS.tick(20)
assert(BUS.count({ prefix = "AmisiaD", sender = VULO, from = tl }) == 0, "nothing in the lockdown")
assert(C(VULO, "NS.CommQueueSize()") >= 1)
local tu = C(VULO, "STUB.clock")
BUS.lock(false)
BUS.tick(10)
assert(spSets(tu) == 1, "the newest snapshot only: " .. spSets(tu))
local parts, seqOf = 0, nil
for _, m in ipairs(BUS.sent) do
    if m.kind == "BL" and m.sender == VULO and m.chan == "RAID" and m.t >= tu then
        local seq, n = m.text:match("^1BL\tSP\t[^\t]+\t(%d+)\t%d+\t(%d+)\t")
        if seq then parts = parts + 1; seqOf = n end
    end
end
assert(parts == tonumber(seqOf), "every part once: " .. parts .. "/" .. tostring(seqOf))
assert(awards(KIM)[a3].kind == "SR" and size(awards(KIM)) == 3 and size(awards(FRAK)) == 3)
assert(S(KIM, "s.sync.rev") == S(VULO, "s.sync.rev"))

---------------------------------------------------------------------------
-- a lost part: the set expires after 30 s, the follower asks once and is equal again
---------------------------------------------------------------------------
local dropped = false
BUS.drop(function(m)
    if m.sender ~= VULO or m.chan ~= "RAID" then return false end
    if m.kind == "ST" then return true end
    if m.kind == "BL" and not dropped and m.text:find("^1BL\tSP\t[^\t]+\t%d+\t1\t") then dropped = true return true end
    return false
end)
S(VULO, "NS.EditAward(s, '" .. a3 .. "', { kind = 'MS' })")
BUS.tick(5)
BUS.drop(nil)
assert(dropped and awards(KIM)[a3].kind == "SR", "the part is gone")
local rq = BUS.count({ kind = "RQ", sender = KIM })
BUS.tick(27)
assert(BUS.count({ kind = "RQ", sender = KIM }) == rq, "waits for the set")
BUS.tick(10)
assert(BUS.count({ kind = "RQ", sender = KIM }) == rq + 1, "asks once when the set expired")
assert(awards(KIM)[a3].kind == "MS" and awards(FRAK)[a3].kind == "MS", "equal again")
assert(BUS.count({ kind = "BL", target = KIM }) >= 1, "the answer comes by whisper")

---------------------------------------------------------------------------
-- many requests: at most 6 answers a minute, more get one snapshot into the raid
---------------------------------------------------------------------------
BUS.tick(61)
for _, name in ipairs({ "Anna Weide", "Bob Bauer", "Cara Cort", "Dirk Dorn", "Ella Elm", "Finn Fels", "Gia Grau" }) do
    C(VULO, ([[table.insert(STUB.roster, { name = %q, class = "MAGE" })
        table.insert(STUB.guild, { name = %q, rank = 4, class = "MAGE" })]]):format(name, name))
end
C(VULO, "STUB.fire('GUILD_ROSTER_UPDATE')")
BUS.tick(11)
local tr = C(VULO, "STUB.clock")
for _, name in ipairs({ "Anna Weide", "Bob Bauer", "Cara Cort", "Dirk Dorn", "Ella Elm", "Finn Fels", "Gia Grau" }) do
    C(VULO, ("STUB.fire('CHAT_MSG_ADDON', 'Amisia', '1RQ\\t%s\\t0\\tP', 'WHISPER', %q, 'Vulo Sturmwind', 0, 0, '', 0)"):format(KEY, name))
end
BUS.tick(25)
local whispered = {}
for _, m in ipairs(BUS.sent) do
    if m.sender == VULO and m.t >= tr and m.kind == "BL" and m.chan == "WHISPER" then whispered[m.target] = true end
end
assert(size(whispered) == 6, "six answers: " .. size(whispered))
assert(spSets(tr) == 1, "the seventh gets the snapshot in the raid")
C(VULO, "for i = #STUB.roster, 5, -1 do table.remove(STUB.roster, i) end; for i = #STUB.guild, 4, -1 do table.remove(STUB.guild, i) end; STUB.fire('GUILD_ROSTER_UPDATE')")
BUS.tick(11)

---------------------------------------------------------------------------
-- invalid snapshots change nothing and are not asked for again
---------------------------------------------------------------------------
local kimBefore, frakBefore = awards(KIM), awards(FRAK)
local kimRev = S(KIM, "s.sync.rev")
local function forge(code)
    S(VULO, [[local sp, so = NS.SyncBuild(s)
        sp.r = sp.r + 50
        ]] .. code .. [[
        sp.h = NS.SyncHashOf(sp, so)
        NS.CommSendBlob("SP", sp.k, sp, "RAID", nil, { key = "X" .. STUB.clock })
        NS.CommSendBlob("SO", sp.k, so, "WHISPER", "Fraktur", { key = "Y" .. STUB.clock })
        NS.CommSend("ST", { NS.RaidKey(s), tostring(sp.r), sp.h, "K" }, "RAID")]])
    BUS.tick(25)
end
local rqKim, rqFrak = BUS.count({ kind = "RQ", sender = KIM }), BUS.count({ kind = "RQ", sender = FRAK })
forge("sp.a[1][2] = 'Bo|cffff0000b'")
forge("for i = 1, 401 do sp.a[i] = { ('%012x'):format(i), 'Spieler', 30000, 0, 'MS', 'Boss', 'player', 0, 0 } end")
forge("sp.a[2][1] = sp.a[1][1]")
forge("sp.a[1][4] = sp.a[1][4] + 5 * 86400")
forge("sp.a[1][5] = 'XX'")
assert(S(KIM, "s.sync.rev") == kimRev and S(FRAK, "s.sync.rev") == kimRev, "nothing applied")
local ka2, fa2 = awards(KIM), awards(FRAK)
for id, a in pairs(kimBefore) do assert(ka2[id] and ka2[id].name == a.name and ka2[id].kind == a.kind, id) end
for id, a in pairs(frakBefore) do assert(fa2[id] and fa2[id].name == a.name and fa2[id].note == a.note, id) end
assert(size(ka2) == size(kimBefore) and size(fa2) == size(frakBefore))
assert(BUS.count({ kind = "RQ", sender = KIM }) == rqKim and BUS.count({ kind = "RQ", sender = FRAK }) == rqFrak, "not asked again")
-- a snapshot for another raid key: ignored
S(VULO, [[local sp = NS.SyncBuild(s); sp.k = "2020-01-01:409"; sp.r = sp.r + 60
    NS.CommSendBlob("SP", sp.k, sp, "RAID", nil, { key = "Z" })]])
BUS.tick(5)
assert(S(KIM, "s.sync.rev") == kimRev)
-- a checksum that does not fit the data: Fraktur (who can check it) refuses
S(VULO, [[local sp, so = NS.SyncBuild(s); sp.r = sp.r + 50; sp.h = "ffffffffffffffff"
    NS.CommSendBlob("SP", sp.k, sp, "WHISPER", "Fraktur", { key = "W1" })
    NS.CommSendBlob("SO", sp.k, so, "WHISPER", "Fraktur", { key = "W2" })]])
BUS.tick(5)
assert(S(FRAK, "s.sync.rev") == kimRev)
-- the officer part is checked as strictly
local why = S(VULO, [=[local sp, so = NS.SyncBuild(s)
    local id = sp.a[1][1]
    so.n[id] = { "Notiz|r", "", 0 }
    sp.h = NS.SyncHashOf(sp, so)
    return select(2, NS.SyncCheck(sp, so, s))]=])
assert(type(why) == "string", "a bar in a note")
assert(S(VULO, "local sp, so = NS.SyncBuild(s); return (NS.SyncCheck(sp, so, s))") == true, "the keeper's own snapshot passes")
why = S(VULO, [[local sp, so = NS.SyncBuild(s)
    so.b["Bob|r"] = { time(), "MAGE", 0, "-", "" }
    sp.h = NS.SyncHashOf(sp, so)
    return select(2, NS.SyncCheck(sp, so, s))]])
assert(type(why) == "string", "a bar in a bench name")

---------------------------------------------------------------------------
-- forged snapshots from a raider, a guest or an officer that is not the keeper are ignored
---------------------------------------------------------------------------
local function forgeFrom(who)
    S(who, [[local sp = { k = NS.RaidKey(s), r = 900000, h = "0123456789abcdef", by = STUB.player, d = s.date, i = s.instanceID,
            z = s.zone, t0 = s.start, a = { { "aaaaaaaaaaaa", "Dieb", 32235, 0, "MS", "Boss", "player", 0, 0 } }, g = {},
            p = { s = "raid", n = {} } }
        NS.CommSend("ST", { sp.k, "900000", sp.h, "K" }, "RAID")
        NS.CommSendBlob("SP", sp.k, sp, "RAID")]])
    BUS.tick(25)
end
forgeFrom(KIM)
forgeFrom(PUG)
forgeFrom(FRAK)
for _, name in ipairs({ VULO, FRAK, KIM }) do
    assert(awards(name)["aaaaaaaaaaaa"] == nil, name .. " took a forged award")
end
assert(S(KIM, "s.sync.rev") == kimRev and C(KIM, "NS.SyncKeeperName()") == VULO, "Kim's claim counts for nothing")
assert(C(VULO, "NS.SyncIsKeeper()") == true)

---------------------------------------------------------------------------
-- Kim without a snapshot after a /reload asks the keeper and gets it by whisper
---------------------------------------------------------------------------
S(KIM, "s.sync = nil; for i = #s.awards, 1, -1 do table.remove(s.awards, i) end")
BUS.reload(KIM)
assert(S(KIM, "s") == nil, "no recording right after the reload")
C(KIM, "STUB.fire('PLAYER_ENTERING_WORLD')")
local tk = C(KIM, "STUB.clock")
BUS.tick(15)
assert(S(KIM, "s.sync and s.sync.rev") == S(VULO, "s.sync.rev"), "Kim follows again")
assert(size(awards(KIM)) == 3 and S(KIM, "#s.gone") == 1)
assert(BUS.count({ kind = "RQ", sender = KIM, from = tk }) == 1 and BUS.count({ kind = "BL", target = KIM, from = tk }) >= 1)

---------------------------------------------------------------------------
-- quiet changes (applied for someone else) neither count nor land on the undo stack
---------------------------------------------------------------------------
local label = C(VULO, "NS.UndoLabel()")
local qrev = S(VULO, "s.sync.rev")
S(VULO, "NS.AwardsQuiet(function() NS.AddAwardTo(s, { name = 'Pug', item = 30009, kind = 'OS', src = 'Boss', t = time() }) end)")
assert(S(VULO, "s.sync.rev") == qrev and C(VULO, "NS.UndoLabel()") == label)
assert(S(VULO, "s.awards[#s.awards].v") == nil)
S(VULO, "NS.DeleteAward(s, s.awards[#s.awards].id)")
settle()

---------------------------------------------------------------------------
-- keeper choice: master looter before leader before the name; a keeper change carries on the
-- revision and loses nothing
---------------------------------------------------------------------------
-- Fraktur claims too (loot lead by setting, raid leader): the master looter stays keeper
setLeader(2)
C(FRAK, "NS.Set('loot.lead', 'me')")
BUS.tick(6)
assert(BUS.count({ kind = "ST", sender = FRAK }) >= 1, "Fraktur claims")
for _, name in ipairs({ VULO, FRAK, KIM }) do assert(C(name, "NS.SyncKeeperName()") == VULO, name) end
-- the master loot goes to Fraktur: Vulo hands over, Fraktur asks Vulo first and carries on
local vrev = S(VULO, "s.sync.rev")
local tc = C(VULO, "STUB.clock")
C(FRAK, "NS.Reset('loot.lead')")
setMaster(2)
BUS.tick(15)
for _, name in ipairs({ VULO, FRAK, KIM }) do assert(C(name, "NS.SyncKeeperName()") == FRAK, name) end
assert(C(FRAK, "NS.SyncIsKeeper()") == true and C(VULO, "NS.SyncIsKeeper()") == false)
assert(count(VULO, "Fraktur hält jetzt den Raid-Stand (Plündermeister). Deine Änderungen gehen an ihn.") == 1)
assert(BUS.count({ kind = "RQ", sender = FRAK, target = VULO, from = tc }) == 1, "the new keeper asks the old one")
local frev0 = S(FRAK, "s.sync.rev")
assert(frev0 > vrev and S(KIM, "s.sync.rev") == frev0, "the revision carries on above everything seen")
assert(S(KIM, "s.sync.keeper") == FRAK and size(awards(KIM)) == 3 and size(awards(FRAK)) == 3)
assert(S(VULO, "s.sync.rev") == frev0 and S(VULO, "s.sync.keeper") == FRAK, "the old keeper follows")
-- the new keeper's change reaches the old one with the note
local a5 = S(FRAK, "NS.AddAwardTo(s, { name = 'Vulo Sturmwind', item = 30005, kind = 'MS', src = 'Majordomo', note = 'Bank leer', t = time() }).id")
settle()
assert(awards(VULO)[a5] and awards(VULO)[a5].note == "Bank leer" and awards(KIM)[a5].note == nil)
-- group loot, both loot leads by setting: the raid leader before the name
setMaster(nil)
C(VULO, "NS.Set('loot.lead', 'me')")
C(FRAK, "NS.Set('loot.lead', 'me')")
setLeader(1)
BUS.tick(15)
for _, name in ipairs({ VULO, FRAK, KIM }) do assert(C(name, "NS.SyncKeeperName()") == VULO, "the leader: " .. name) end
-- nobody leads: the name decides (Fraktur before Vulo Sturmwind)
setLeader(0)
BUS.tick(15)
for _, name in ipairs({ VULO, FRAK, KIM }) do assert(C(name, "NS.SyncKeeperName()") == FRAK, "by name: " .. name) end
assert(size(awards(KIM)) == 4 and size(awards(VULO)) == 4 and size(awards(FRAK)) == 4, "nothing lost over four keeper changes")
assert(S(KIM, "s.sync.hash") == S(FRAK, "s.sync.hash") and S(VULO, "s.sync.hash") == S(FRAK, "s.sync.hash"))

---------------------------------------------------------------------------
-- sync off: no claim, nothing taken
---------------------------------------------------------------------------
C(FRAK, "NS.Set('sync.enabled', false)")
BUS.tick(15)
assert(C(FRAK, "NS.SyncIsKeeper()") == false)
for _, name in ipairs({ VULO, KIM }) do assert(C(name, "NS.SyncKeeperName()") == VULO, "Vulo again: " .. name) end
local frev = S(FRAK, "s.sync.rev")
S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 30006, kind = 'MS', src = 'Ragnaros', t = time() })")
BUS.tick(25)
assert(S(FRAK, "s.sync.rev") == frev, "Fraktur takes nothing while sync is off")
assert(S(KIM, "s.sync.rev") == S(VULO, "s.sync.rev"))
C(FRAK, "NS.Reset('loot.lead')")
C(FRAK, "NS.Reset('sync.enabled')")

---------------------------------------------------------------------------
-- the end of the recording sends a last snapshot when something changed since
---------------------------------------------------------------------------
BUS.tick(30)
local te = C(VULO, "STUB.clock")
S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 30007, kind = 'OS', src = 'Ragnaros', t = time() })")
C(VULO, "NS.SetEnabled(false)")
BUS.tick(1)
assert(spSets(te) == 1, "the last snapshot goes at once")
assert(S(VULO, "s") == nil)
C(VULO, "NS.SetEnabled(true)")

---------------------------------------------------------------------------
-- the move on load: s.sync and a.v are checked
---------------------------------------------------------------------------
C(KIM, [[local s = AmisiaDB.sessions[#AmisiaDB.sessions]
    local now = time()
    s.sync.pending = { { opid = "a1b2c3d4e5f6", op = {}, base = 1, t = now - 100, tries = 0 },
                       { opid = "a1b2c3d4e5f7", op = {}, base = 1, t = now - 90000, tries = 0 }, "kaputt" }
    s.sync.conflicts = { { opid = "a1b2c3d4e5f6", id = "x", op = "edit", at = now } }
    s.awards[1].v = -3
    s.awards[2].v = "drei"
    table.insert(AmisiaDB.sessions, 1, { id = "alt", date = "2020-01-01", instanceID = 409, zone = "Alt", start = 1, last = 1,
        members = {}, loot = {}, awards = {}, gone = {}, sync = { key = "kaputt" } })
    table.insert(AmisiaDB.sessions, 1, { id = "alt2", date = "2020-01-01", instanceID = 409, zone = "Alt", start = 1, last = 1,
        members = {}, loot = {}, awards = {}, gone = {}, sync = { key = "2020-01-01:409", conflicts = { { opid = "x" } } } })]])
BUS.reload(KIM)
local moved = C(KIM, [[local s = AmisiaDB.sessions[#AmisiaDB.sessions]
    return { pending = #s.sync.pending, conflicts = #s.sync.conflicts, v1 = s.awards[1].v, v2 = s.awards[2].v,
             bad = AmisiaDB.sessions[2].sync, oldConflicts = #AmisiaDB.sessions[1].sync.conflicts, key = s.sync.key }]])
assert(moved.pending == 1 and moved.conflicts == 1 and moved.v1 == nil and moved.v2 == nil and moved.bad == nil, "cleaned")
assert(moved.oldConflicts == 0 and moved.key == KEY, "conflicts of an earlier night fall away")
BUS.reload(KIM)
assert(C(KIM, "#AmisiaDB.sessions[#AmisiaDB.sessions].sync.pending") == 1, "loading twice changes nothing")

for _, file in ipairs({ "Raid/Sync.lua" }) do
    local src = assert(io.open(ADDON_DIR .. "/" .. file, "rb")):read("*a")
    for c in src:gmatch("[\196-\255][\128-\191]") do error(file .. ": character above Latin-1: " .. c) end
end
