-- The own echo of a "!word" line is exactly the own full name: a guildmate with the same first name
-- but no surname is answered, not ignored as this client's own line (audit 2026-11-07).
STUB.player = "Vulo Sturmwind"
local calls = {}
NS.RegisterChatCommand("sr", function(sender) calls[#calls + 1] = sender end)
STUB.fire("CHAT_MSG_WHISPER", "!sr", "Vulo")
assert(#calls == 1 and calls[1] == "Vulo", "the other Vulo is heard")
STUB.fire("CHAT_MSG_RAID", "!sr", "Vulo Eisherz")
assert(#calls == 2, "another surname is another character")
-- the own lines stay ignored, with and without the own realm's ending
STUB.fire("CHAT_MSG_RAID", "!sr", "Vulo Sturmwind")
STUB.fire("CHAT_MSG_RAID", "!sr", "vulo sturmwind-Realm")
assert(#calls == 2, "own lines are ignored")
