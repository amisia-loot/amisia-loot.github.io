--[[preload
-- TBC Anniversary and Classic Era: no C_ChatInfo.SendChatMessage, only the global
C_ChatInfo.SendChatMessage = nil
SendChatMessage = function(text, chan, lang, target)
    STUB.chat[#STUB.chat + 1] = { text = text, chan = chan, target = target, global = true }
end
]]
--[[game tbc]]
-- The chat queue on TBC Anniversary (D-57): without C_ChatInfo.SendChatMessage the client's global
-- sends the lines (raid announcements and whispers), nothing is dropped.
assert(NS.GAME == "tbc", tostring(NS.GAME))
assert(C_ChatInfo.SendChatMessage == nil, "the stub lacks the C_ChatInfo function")
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.chat = {}
assert(NS.Say("hallo", "RAID") == "sent")
assert(#STUB.chat == 1 and STUB.chat[1].global and STUB.chat[1].text == "hallo" and STUB.chat[1].chan == "RAID",
    "sent through the global")
assert(NS.Say("psst", "WHISPER", "Fraktur-Realm") == "sent")
assert(STUB.chat[2].global and STUB.chat[2].chan == "WHISPER" and STUB.chat[2].target == "Fraktur-Realm")
-- an announcement of the loot lead reaches the raid too
NS.Announce("Ansage")
assert(#STUB.chat == 3 and STUB.chat[3].text == "Ansage" and STUB.chat[3].global, tostring(STUB.chat[3] and STUB.chat[3].text))
-- a queued line goes out through the global once the lockdown ends
STUB.chatLock = true
assert(NS.Say("später", "RAID") == "queued")
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
STUB.tick(0)
assert(#STUB.chat == 4 and STUB.chat[4].text == "später" and STUB.chat[4].global)
assert(NS.ChatQueueSize() == 0)
