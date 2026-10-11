--[[preload
C_Club = nil
]]
-- Without C_Club the guild roster comes from GetGuildRosterInfo (rank = rank index + 1).
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.guild = { { name = "Anna Weide", rank = 1 }, { name = "Vuloo", rank = 2 }, { name = "Fraktur", rank = 3, online = false },
               { name = "Kim Eisherz", rank = 4 } }
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true }, [3] = { [22] = true } }
local m = NS.GuildMember("Fraktur")
assert(m and m.name == "Fraktur" and m.rank == 3 and m.online == false, "rank index 2 is rank 3")
assert(NS.IsVerifiedOfficer("Fraktur") == true and NS.IsVerifiedOfficer("Kim Eisherz") == false)
assert(NS.SelfIsOfficer() == true)
assert(NS.TrustName("Anna Weide") == "Anna Weide")
-- without either roster nobody is verified
GetGuildRosterInfo = nil
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
assert(NS.IsVerifiedOfficer("Fraktur") == nil and NS.TrustName("Anna Weide") == nil)
