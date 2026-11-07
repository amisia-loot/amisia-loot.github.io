--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- The raid sync (Raid/Sync.lua onSO, review 2026-11-07): the older public part of the old keeper
-- that waits for its officer part does not make Fraktur drop the officer part of the new keeper,
-- whose revision is lower in a higher term; the new keeper's state is taken as soon as its public
-- part arrives.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function hex(t) return (t:gsub(".", function(c) return ("%02x"):format(c:byte()) end)) end
local function isSP(m) return m.kind == "BL" and m.text:find("^1BL\tSP\t") ~= nil end
local function isSO(m) return m.kind == "BL" and m.text:find("^1BL\tSO\t") ~= nil end

BUS.setRaid({ VULO, FRAK, KIM })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 2 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = true
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")
        local recv = BUS_RECV
        BUS_RECV = function(...) if MUTE then return end return recv(...) end]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true)
local r0 = S(VULO, "s.sync.rev")
assert(S(KIM, "s.sync.rev") == r0)

-- Kim misses everything from here; Fraktur gets two revisions whole, the third without its officer part
C(KIM, "MUTE = true")
S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30001, kind = 'MS', src = 'Ragnaros', t = time() })")
BUS.tick(8)
S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30002, kind = 'MS', src = 'Ragnaros', t = time() })")
BUS.tick(8)
BUS.drop(function(m) return isSO(m) and m.target == FRAK end)
S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30003, kind = 'MS', src = 'Ragnaros', t = time() })")
BUS.tick(6)
local r3 = S(VULO, "s.sync.rev")
assert(S(FRAK, "s.sync.rev") == r3 - 1, "Fraktur waits for the officer part of the newest revision")

-- Vulo leaves, Kim gets the master loot. Fraktur's answers to Kim's gathering and his own asks get
-- lost, so Kim stays at his old revision; Kim's public part to the raid is held back
local held = {}
BUS.drop(function(m)
    if m.sender == FRAK and (m.target == KIM or m.kind == "RQ") then return true end
    if m.sender == KIM and isSP(m) then held[#held + 1] = m return true end
    return false
end)
C(KIM, "MUTE = false")
BUS.setRaid({ FRAK, KIM })
for i, name in ipairs({ FRAK, KIM }) do
    C(name, ([[STUB.playerRaidIndex, STUB.lootMethod, STUB.mlRaidID = %d, 2, 2
        STUB.fire("GROUP_ROSTER_UPDATE"); STUB.fire("PARTY_LOOT_METHOD_CHANGED")]]):format(i))
end
BUS.tick(15)
assert(C(KIM, "NS.SyncIsKeeper()") == true and C(FRAK, "NS.SyncKeeperName()") == KIM, "Kim keeps the raid")
local ke, kr = S(KIM, "s.sync.term"), S(KIM, "s.sync.rev")
assert(kr < r3 and ke > S(FRAK, "s.sync.term or 0"), "Kim: a higher term, a lower revision: " .. kr .. " " .. r3)
assert(#held >= 1 and BUS.count(function(m) return isSO(m) and m.sender == KIM and m.target == FRAK and not m.dropped end) >= 1,
    "Kim's officer part reached Fraktur, his public part not")
assert(S(FRAK, "s.sync.rev") ~= kr)
-- the public part arrives: taken at once with the officer part that came first
local raidSP = {}
for _, m in ipairs(held) do if m.chan == "RAID" then raidSP[#raidSP + 1] = m end end
for _, m in ipairs(raidSP) do
    C(FRAK, ("BUS_RECV(%q, %q, %q, %q, %q)"):format(hex(m.prefix), hex(m.text), hex(m.chan), hex(m.sender), hex(m.target or "")))
end
BUS.tick(2)
assert(S(FRAK, "s.sync.term") == ke and S(FRAK, "s.sync.rev") == kr,
    "the new keeper's state is taken: " .. tostring(S(FRAK, "s.sync.term")) .. "/" .. tostring(S(FRAK, "s.sync.rev")))
BUS.drop(nil)
