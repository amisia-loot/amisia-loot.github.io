--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]
-- The raid sync (Raid/Sync.lua onSO, audit 2026-11-07): an officer part of an older revision that
-- arrives late does not push out the newer public part waiting for its officer part; that one is
-- asked for and the newer state is taken.
local VULO, FRAK, KIM = "Vulo Sturmwind", "Fraktur", "Kim Eisherz"
local function S(name, code)
    local expr = loadstring("return " .. code) ~= nil
    return C(name, "local s = NS.Active(); " .. (expr and "return " or "") .. code)
end

BUS.setRaid({ VULO, FRAK, KIM })
BUS.setGuild({ { name = VULO, rank = 1 }, { name = FRAK, rank = 2 }, { name = KIM, rank = 4 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.officer = STUB.player == "Vulo Sturmwind" or STUB.player == "Fraktur"
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("PLAYER_LOGIN")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C(VULO, "NS.SyncIsKeeper()") == true)

-- revision 1 whole at Fraktur; its officer part kept for a late replay
S(VULO, "NS.AddAwardTo(s, { name = 'Kim Eisherz', item = 32235, kind = 'MS', src = 'Ragnaros', note = 'eins', t = time() })")
BUS.tick(8)
local r1 = S(VULO, "s.sync.rev")
assert(S(FRAK, "s.sync.rev") == r1)
-- the keeper's officer part of revision 1, kept to go out late (a slow whisper queue)
S(VULO, "local _, so = NS.SyncBuild(s); OLD_SO = so")

-- revision 2: its officer part is lost; the one of revision 1 arrives late instead
BUS.drop(function(m) return m.kind == "BL" and m.target == FRAK and m.text:find("^1BL\tSO\t") ~= nil end)
S(VULO, "NS.AddAwardTo(s, { name = 'Fraktur', item = 30000, kind = 'MS', src = 'Ragnaros', note = 'zwei', t = time() })")
BUS.tick(8)
BUS.drop(nil)
local r2 = S(VULO, "s.sync.rev")
assert(r2 > r1 and S(FRAK, "s.sync.rev") == r1, "Fraktur waits for the officer part of revision 2")
assert(S(VULO, "OLD_SO.r") == r1)
S(VULO, "NS.CommSendBlob('SO', NS.RaidKey(s), OLD_SO, 'WHISPER', 'Fraktur', { key = 'late' })")
BUS.tick(30)
assert(S(FRAK, "s.sync.rev") == r2, "the newer state is asked for and taken: " .. tostring(S(FRAK, "s.sync.rev")) .. " " .. r2)
