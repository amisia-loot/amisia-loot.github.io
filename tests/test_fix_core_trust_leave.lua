-- Leaving the guild: the former guild's roster answers no trust question any more, also within the
-- 10 s before the roster is built again (audit 2026-11-07).
STUB.rankFlags = { [1] = { [22] = true } }
STUB.guild = { { name = "Anna Weide", rank = 1 }, { name = "Fraktur", rank = 2 } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
assert(NS.IsVerifiedMember("Fraktur") == true)
assert(NS.IsVerifiedOfficer("Anna Weide") == true)
assert(NS.TrustName("Fraktur") == "Fraktur")
-- the guild is left; the client still lists the old members for a moment
STUB.inGuild = false
STUB.fire("PLAYER_GUILD_UPDATE")
STUB.tick(1)
assert(NS.IsVerifiedMember("Fraktur") == false, "no member outside the guild")
assert(NS.IsVerifiedOfficer("Anna Weide") == false, "no officer outside the guild")
assert(NS.GuildMember("Fraktur") == nil)
assert(NS.TrustName("Fraktur") == nil, "a former guildmate is no known name")
-- joining again: the roster is built anew
STUB.inGuild = true
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
assert(NS.IsVerifiedMember("Fraktur") == true, "back in the guild")
