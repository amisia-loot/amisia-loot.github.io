--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- Keeper terms of the raid sync (Sync.lua, review of 2.1): every snapshot carries (term, rev); a
-- new keeper gathers newer states first; followers never take an older snapshot and tell the
-- sender; a former keeper's changes the new keeper lacks go to him as wishes. Vulo Sturmwind is
-- master looter and officer, Fraktur an officer with "loot lead: me", Kim Eisherz a raider.
-- Scenarios: a keeper cut off from the raid comes back (with and without a /reload), two keepers
-- at once (split brain) and a keeper whose last changes never left his client before he handed over.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local ALL = { VULO, FRAK, KIM }

local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
-- id -> { name, kind, note, gone } of every award and tombstone of a client
local function book(name)
    return S(name, [[local out = {}
        for _, a in ipairs(s.awards) do out[a.id] = { name = a.name, kind = a.kind, note = a.note, gone = false } end
        for _, a in ipairs(s.gone) do out[a.id] = { name = a.name, kind = a.kind, note = a.note, gone = true } end
        return out]])
end
local function size(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local function add(name, who, item)
    return S(name, ("NS.AddAwardTo(s, { name = %q, item = %d, kind = 'OS', src = 'Ragnaros', t = time() }).id"):format(who, item))
end
local function setMaster(i)
    for _, name in ipairs(CLIENTS) do
        C(name, ([[STUB.lootMethod = %d; STUB.mlRaidID = %s; STUB.fire("PARTY_LOOT_METHOD_CHANGED")]]):format(i and 2 or 0, tostring(i)))
    end
end
-- every client holds the same raid: the same awards and tombstones, the same revision and checksum
local function same(why)
    local want = book(VULO)
    for _, name in ipairs({ FRAK, KIM }) do
        local got = book(name)
        assert(size(got) == size(want), ("%s: %d entries, Vulo %d (%s)"):format(name, size(got), size(want), why))
        for id, a in pairs(want) do
            local g = got[id]
            assert(g and g.gone == a.gone and g.name == a.name and g.kind == a.kind, ("%s: %s differs (%s)"):format(name, id, why))
            if name ~= KIM then assert(g.note == a.note, ("%s: note of %s (%s)"):format(name, id, why)) end
        end
    end
    local rev, hash = S(VULO, "s.sync.rev"), S(VULO, "s.sync.hash")
    for _, name in ipairs({ FRAK, KIM }) do
        assert(S(name, "s.sync.rev") == rev and S(name, "s.sync.hash") == hash, ("%s: state %s/%s, Vulo %s/%s (%s)"):format(name,
            tostring(S(name, "s.sync.rev")), tostring(S(name, "s.sync.hash")), rev, hash, why))
    end
end
-- Vulo loses the connection: the others see him leave the group (and the master loot with him),
-- he hears nothing and nothing of his arrives
local function cut()
    BUS.drop(function(m) return m.sender == VULO or m.target == VULO or m.chan == "GUILD" end)
    BUS.raid = { FRAK, KIM }
    for _, name in ipairs({ FRAK, KIM }) do
        C(name, [[for i = #STUB.roster, 1, -1 do if STUB.roster[i].name == "Vulo Sturmwind" then table.remove(STUB.roster, i) end end
            for i, m in ipairs(STUB.roster) do if m.name == STUB.player then STUB.playerRaidIndex = i end end
            STUB.lootMethod = 0
            STUB.fire("GROUP_ROSTER_UPDATE"); STUB.fire("PARTY_LOOT_METHOD_CHANGED")]])
    end
end
-- Vulo is back in every group; master: he is master looter again (else nobody is)
local function heal(master)
    BUS.drop(nil)
    BUS.raid = { VULO, FRAK, KIM }
    for _, name in ipairs({ FRAK, KIM }) do
        C(name, [[table.insert(STUB.roster, 1, { name = "Vulo Sturmwind", class = "PRIEST" })
            for i, m in ipairs(STUB.roster) do if m.name == STUB.player then STUB.playerRaidIndex = i end end
            STUB.fire("GROUP_ROSTER_UPDATE")]])
    end
    setMaster(master and 1 or nil)
end

BUS.setRaid(ALL)
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.item(32235, "Fluchsicht des Sargeras", 4)
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true)
local a1, a2, a3 = add(VULO, FRAK, 32235), add(VULO, KIM, 30000), add(VULO, KIM, 30001)
C(FRAK, "NS.Set('loot.lead', 'me')")
BUS.tick(10)
same("start")
local e0 = S(VULO, "s.sync.term")
assert(type(e0) == "number" and e0 >= 1, "the keeper's term: " .. tostring(e0))
assert(S(KIM, "s.sync.term") == e0, "the term goes with the snapshot")

---------------------------------------------------------------------------
-- 1. the keeper is cut off, Fraktur keeps the raid meanwhile; Vulo comes back as master looter
-- with an older state: he gathers the newer one first and loses nothing of either side
---------------------------------------------------------------------------
cut()
BUS.tick(20)
assert(C(FRAK, "NS.SyncIsKeeper()") == true and C(KIM, "NS.SyncKeeperName()") == FRAK, "Fraktur keeps the raid meanwhile")
local eF = S(FRAK, "s.sync.term")
assert(eF > e0, "a new keeper starts a new term")
S(FRAK, "NS.DeleteAward(s, '" .. a1 .. "')")
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { kind = 'MS', note = 'Frak' })")
-- Vulo, cut off, works on: an award and a deletion only he knows
local aV = add(VULO, FRAK, 30002)
S(VULO, "NS.DeleteAward(s, '" .. a3 .. "')")
BUS.tick(10)
assert(book(KIM)[a1].gone and book(KIM)[a2].kind == "MS", "Kim follows Fraktur")
assert(S(VULO, "s.sync.rev") < S(FRAK, "s.sync.rev") or S(VULO, "s.sync.term") < S(FRAK, "s.sync.term"))
heal(true)
BUS.tick(5)
-- Vulo keeps working: his snapshot is older than what the others hold
local aW = add(VULO, KIM, 30003)
BUS.tick(40)
for _, name in ipairs(ALL) do
    assert(C(name, "NS.SyncKeeperName()") == VULO, name .. ": Vulo keeps the raid again")
    local b = book(name)
    assert(b[a1] and b[a1].gone, name .. ": Fraktur's deletion holds")
    assert(b[a2] and not b[a2].gone and b[a2].kind == "MS", name .. ": Fraktur's change holds")
    if name ~= KIM then assert(b[a2].note == "Frak", name .. ": Fraktur's note holds") end
    assert(b[a3] and b[a3].gone, name .. ": Vulo's deletion while cut off holds")
    assert(b[aV] and not b[aV].gone and b[aW] and not b[aW].gone, name .. ": Vulo's awards hold")
end
same("after the stale keeper came back")
local e1 = S(VULO, "s.sync.term")
assert(e1 > eF, "Vulo carries on in a term above Fraktur's")
assert(BUS.count({ kind = "NW" }) >= 1, "a follower told the stale keeper")
assert(BUS.count(function(m) return m.kind == "RQ" and m.sender == VULO and m.chan == "RAID" and m.text:find("\tG$") end) >= 1,
    "the stale keeper gathered in the raid")

---------------------------------------------------------------------------
-- 2. the same with a /reload of the cut-off keeper: he gathers at login
---------------------------------------------------------------------------
BUS.tick(30)
cut()
BUS.tick(20)
assert(C(FRAK, "NS.SyncIsKeeper()") == true)
S(FRAK, "NS.EditAward(s, '" .. a2 .. "', { note = 'Frak 2' })")
S(FRAK, "NS.DeleteAward(s, '" .. aW .. "')")
local aX = add(VULO, FRAK, 30004)
BUS.tick(10)
BUS.reload(VULO)
heal(true)
C(VULO, 'STUB.item(32235, "Fluchsicht des Sargeras", 4); STUB.fire("PLAYER_LOGIN"); STUB.fire("GROUP_ROSTER_UPDATE")')
BUS.tick(40)
for _, name in ipairs(ALL) do
    assert(C(name, "NS.SyncKeeperName()") == VULO, name .. ": Vulo keeps the raid after the reload")
    local b = book(name)
    if name ~= KIM then assert(b[a2].note == "Frak 2", name .. ": Fraktur's note holds over the reload") end
    assert(b[aW] and b[aW].gone, name .. ": Fraktur's deletion holds over the reload")
    assert(b[aX] and not b[aX].gone, name .. ": Vulo's award from before the reload holds")
end
same("after the reload")
assert(S(VULO, "s.sync.term") > e1)

---------------------------------------------------------------------------
-- 3. two keepers at once (split brain): both lead the loot, both keep the raid on their side; when
-- they meet, the name decides (no master looter, no leader): Fraktur. Vulo's changes reach him as
-- wishes, edits and deletions too; the same field changed on both sides is a conflict at Vulo.
---------------------------------------------------------------------------
BUS.tick(30)
C(VULO, "NS.Set('loot.lead', 'me')")
local b1, b2, b3, b4 = add(VULO, KIM, 30011), add(VULO, KIM, 30012), add(VULO, KIM, 30013), add(VULO, KIM, 30014)
BUS.tick(10)
same("before the split")
cut()
BUS.tick(20)
assert(C(FRAK, "NS.SyncIsKeeper()") == true and C(VULO, "NS.SyncIsKeeper()") == true, "two keepers")
S(VULO, "NS.EditAward(s, '" .. b1 .. "', { note = 'von Vulo' })")
S(VULO, "NS.DeleteAward(s, '" .. b2 .. "')")
S(VULO, "NS.EditAward(s, '" .. b4 .. "', { name = 'Kim Eisherz', kind = 'SR' })")
local b5 = add(VULO, FRAK, 30015)
S(FRAK, "NS.EditAward(s, '" .. b1 .. "', { kind = 'MS' })")
S(FRAK, "NS.DeleteAward(s, '" .. b3 .. "')")
S(FRAK, "NS.EditAward(s, '" .. b4 .. "', { kind = 'MS' })")
local b6 = add(FRAK, VULO, 30016)
BUS.tick(10)
heal(false)
BUS.tick(5)
local b7 = add(FRAK, KIM, 30017)
BUS.tick(60)
for _, name in ipairs(ALL) do
    assert(C(name, "NS.SyncKeeperName()") == FRAK, name .. ": the name decides")
    local b = book(name)
    assert(not b[b1].gone and b[b1].kind == "MS", name .. ": Fraktur's change of b1")
    if name ~= KIM then assert(b[b1].note == "von Vulo", name .. ": Vulo's note on b1 came as a wish") end
    assert(b[b2].gone, name .. ": Vulo's deletion came as a wish")
    assert(b[b3].gone, name .. ": Fraktur's deletion holds")
    assert(not b[b4].gone and b[b4].kind == "MS", name .. ": the keeper's side of the conflict holds")
    assert(b[b5] and not b[b5].gone and b[b6] and not b[b6].gone and b[b7] and not b[b7].gone, name .. ": both sides' awards")
end
same("after the split brain")
local conflicts = S(VULO, "s.sync.conflicts or {}")
assert(#conflicts == 1 and conflicts[1].id == b4 and conflicts[1].mine.kind == "SR" and conflicts[1].by == FRAK,
    "the conflict on b4 shows at Vulo")
assert(S(VULO, "#(s.sync.pending or {})") == 0 and S(VULO, "#(s.sync.mine or {})") == 0, "nothing waits at Vulo")

---------------------------------------------------------------------------
-- 4. a keeper whose last changes never left his client hands over: the new keeper cannot gather
-- them, so they go to him as wishes once his snapshot arrives (an edit and a deletion)
---------------------------------------------------------------------------
C(VULO, "NS.Reset('loot.lead')")
C(FRAK, "NS.Reset('loot.lead')")
setMaster(1)
BUS.tick(30)
assert(C(FRAK, "NS.SyncKeeperName()") == VULO and C(VULO, "NS.SyncIsKeeper()") == true)
local c1, c2 = add(VULO, FRAK, 30021), add(VULO, KIM, 30022)
BUS.tick(10)
same("before the hand-over")
BUS.drop(function(m) return m.sender == VULO and m.kind == "BL" end)
S(VULO, "NS.EditAward(s, '" .. c1 .. "', { note = 'Vulo zuletzt' })")
S(VULO, "NS.DeleteAward(s, '" .. c2 .. "')")
BUS.tick(5)
setMaster(2)
BUS.tick(15)
assert(C(FRAK, "NS.SyncIsKeeper()") == true, "Fraktur keeps the raid now")
BUS.drop(nil)
BUS.tick(70)
for _, name in ipairs(ALL) do
    local b = book(name)
    if name ~= KIM then assert(b[c1].note == "Vulo zuletzt", name .. ": the old keeper's last edit holds") end
    assert(b[c2].gone, name .. ": the old keeper's last deletion holds")
end
same("after the hand-over")
assert(S(VULO, "#(s.sync.pending or {})") == 0 and S(VULO, "#(s.sync.conflicts or {})") == 1, "no new conflict")

-- the snapshot checks term and lineage like everything else
local why = S(FRAK, "local sp, so = NS.SyncBuild(s); sp.e = -1; return select(2, NS.SyncCheck(sp, so, s))")
assert(why == "Kopf", tostring(why))
why = S(FRAK, "local sp, so = NS.SyncBuild(s); so.l = { { 1, 'Bo|r', 3 } }; return select(2, NS.SyncCheck(sp, so, s))")
assert(why == "Offiziersteil", tostring(why))
assert(S(FRAK, "local sp, so = NS.SyncBuild(s); return (NS.SyncCheck(sp, so, s))") == true)
