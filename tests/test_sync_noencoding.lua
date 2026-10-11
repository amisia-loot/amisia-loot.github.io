--[[clients Vulo_Sturmwind Fraktur]]
--[[preload
STUB.noEncoding = true
]]
-- Clients without C_EncodingUtil: no raid sync (no claim, no data), the version check still works.
BUS.setRaid({ "Vulo Sturmwind", "Fraktur" })
BUS.setGuild({ { name = "Vulo Sturmwind", rank = 1 }, { name = "Fraktur", rank = 2 } })
for i, name in ipairs(CLIENTS) do
    C(name, ([[STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
        STUB.leader = false
        STUB.lootMethod, STUB.mlRaidID, STUB.playerRaidIndex = 2, 1, %d
        STUB.fire("GUILD_ROSTER_UPDATE")
        STUB.fire("GROUP_ROSTER_UPDATE")]]):format(i))
end
BUS.tick(30)
assert(C("Vulo Sturmwind", "NS.CommPacking()") == false and C("Vulo Sturmwind", "NS.Active() ~= nil") == true)
assert(C("Vulo Sturmwind", "NS.IsLootLead()") == true)
assert(C("Vulo Sturmwind", "NS.SyncIsKeeper()") == false and C("Fraktur", "NS.SyncKeeperName()") == nil)
C("Vulo Sturmwind", "NS.AddAwardTo(NS.Active(), { name = 'Fraktur', item = 32235, kind = 'MS', src = 'Ragnaros', t = time() })")
BUS.tick(15)
assert(BUS.count({ kind = "ST" }) == 0 and BUS.count({ prefix = "AmisiaD" }) == 0, "no sync messages")
assert(C("Fraktur", "#NS.Active().awards") == 0)
assert(C("Vulo Sturmwind", "NS.Active().sync") == nil)
-- the version check goes on
assert(BUS.count({ kind = "HI", chan = "RAID" }) == 2)
assert(C("Vulo Sturmwind", "NS.VersionSeen()[1].name") == "Fraktur")
