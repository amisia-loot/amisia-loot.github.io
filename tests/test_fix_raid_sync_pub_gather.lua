--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- The raid sync (Raid/Sync.lua answerGather, review 2026-11-07): an officer whose state holds only
-- the public part (taken in the raider view) still hands it to a new keeper that is behind. Vulo
-- keeps the raid; Fraktur misses three changes; Kim (officer rank) takes them in the raider view
-- and turns to the officer view without asking again; Vulo leaves, Fraktur becomes keeper and
-- gathers: Kim's newer state wins, nothing of Vulo's work is lost.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end
local function ids(name)
    return S(name, "local out = {} for _, a in ipairs(s.awards) do out[a.id] = true end return out")
end

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
C(KIM, "NS.Set('ui.view', 'raider')")
local a0 = S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 32235, kind = 'MS', src = 'Ragnaros', t = time() }).id")
BUS.tick(8)
local n0 = S(VULO, "s.sync.rev")
assert(S(FRAK, "s.sync.rev") == n0 and S(KIM, "s.sync.rev") == n0)

-- three changes Fraktur misses; Kim takes them without the officer part
C(FRAK, "MUTE = true")
local a1 = S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30001, kind = 'MS', src = 'Ragnaros', t = time() }).id")
BUS.tick(8)
local a2 = S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30002, kind = 'OS', src = 'Ragnaros', t = time() }).id")
BUS.tick(8)
S(VULO, ("NS.DeleteAward(s, %q)"):format(a0))
BUS.tick(8)
local n3 = S(VULO, "s.sync.rev")
assert(n3 >= n0 + 3 and S(KIM, "s.sync.rev") == n3 and S(KIM, "s.sync.pub") == true, "Kim holds the newest public state")
assert(S(FRAK, "s.sync.rev") == n0, "Fraktur is behind")
-- Kim turns to the officer view, his own ask gets lost (as when the guild roster comes late)
BUS.drop(function(m) return m.kind == "RQ" and m.sender == KIM end)
C(KIM, "NS.Set('ui.view', 'officer')")
BUS.tick(5)
BUS.drop(nil)
assert(S(KIM, "s.sync.pub") == true)

-- Vulo leaves; the master loot goes to Fraktur, who gathers before he sends
C(FRAK, "MUTE = false")
BUS.setRaid({ FRAK, KIM })
for i, name in ipairs({ FRAK, KIM }) do
    C(name, ([[STUB.playerRaidIndex, STUB.lootMethod, STUB.mlRaidID = %d, 2, 1
        STUB.fire("GROUP_ROSTER_UPDATE"); STUB.fire("PARTY_LOOT_METHOD_CHANGED")]]):format(i))
end
BUS.tick(40)
assert(C(FRAK, "NS.SyncIsKeeper()") == true, "Fraktur keeps the raid")
local f, k = ids(FRAK), ids(KIM)
assert(f[a1] and f[a2] and not f[a0], "the new keeper took Kim's newer state")
assert(k[a1] and k[a2] and not k[a0], "Kim keeps Vulo's changes, the deleted award stays deleted")
assert(S(FRAK, "s.sync.rev") > n3, "the revision carries on above Kim's")
