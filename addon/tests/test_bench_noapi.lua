--[[preload
GetGuildRosterInfo = nil
GetNumGuildMembers = nil
C_GuildInfo.GuildRoster = nil
C_FriendList = nil
]]
-- A client without the guild roster functions and the friend list: suggestions only from the group
-- outside, !bench takes anyone with a note, and nothing errors.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Bob", class = "MAGE", zone = "Shattrath" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s and s.outside.Bob)
local sug = NS.BenchSuggestions(s)
assert(#sug == 1 and sug[1].value == "Bob" and sug[1].text == "Bob (in der Gruppe, draußen)", #sug)
assert(NS.RequestGuildRoster() == false, "nothing to request")
STUB.tick(20)
STUB.fire("CHAT_MSG_WHISPER", "!bench", "Bob")
assert(s.bench.Bob and s.bench.Bob.self and s.bench.Bob.note == "Gilde nicht geprüft" and s.bench.Bob.class == "MAGE")
assert(STUB.chat[#STUB.chat].target == "Bob")
