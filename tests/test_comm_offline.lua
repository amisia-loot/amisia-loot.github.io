-- Whispers to a player who just went offline (2.94.1, Core/Comm.lua): the server's "ist jetzt offline" line
-- drops the whispers to that name still waiting in the queue and keeps new ones back for two minutes (a message
-- from the name ends that); the server's "kein Spieler ... online" line for a name Amisia whispered within a
-- minute stays out of the chat, another name's stays.
STUB.guild = { { name = "Vuloo", rank = 1 }, { name = "Abunazir Jr", rank = 2 }, { name = "Kim Eisherz", rank = 4 } }
_G.ERR_FRIEND_OFFLINE_S = "%s ist jetzt offline."
_G.ERR_CHAT_PLAYER_NOT_FOUND_S = "Momentan ist kein Spieler mit dem Namen '%s' online."
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.tick(30)
STUB.addon, STUB.addonTries = {}, {}

local function sentTo(name)
    local n = 0
    for _, m in ipairs(STUB.addon) do if m.chan == "WHISPER" and m.target == name then n = n + 1 end end
    return n
end

-- one whisper goes, then twenty more wait behind the throttle
assert(NS.CommSend("YA", { "beef", 1429, 3999 }, "WHISPER", "Abunazir Jr") == true)
STUB.tick(1)
assert(sentTo("Abunazir Jr") == 1, "the first whisper went")
for i = 1, 20 do NS.CommSend("ZA", { ("%04x"):format(i), 1429, 0, "0" }, "WHISPER", "Abunazir Jr") end
local before = NS.CommQueueSize()
assert(before > 0, "some wait in the queue")
-- the player goes offline: the waiting whispers go, a new one is refused
STUB.fire("CHAT_MSG_SYSTEM", "|Hplayer:Abunazir Jr|h[Abunazir Jr]|h ist jetzt offline.")
assert(NS.CommQueueSize() < before, "the waiting whispers to the name are dropped")
local ok, why = NS.CommSend("YA", { "beef", 1429, 3999 }, "WHISPER", "Abunazir Jr")
assert(not ok and why:find("offline", 1, true), tostring(why))
STUB.tick(30)
local after = sentTo("Abunazir Jr")
assert(after <= 11, "nothing more went to the name: " .. after)
-- whispers to others still go
assert(NS.CommSend("YA", { "beef", 1429, 3999 }, "WHISPER", "Kim Eisherz") == true)

-- the server's line for the name Amisia whispered: out of the chat; another name's stays
assert(NS.CommOfflineLine("Momentan ist kein Spieler mit dem Namen 'Abunazir Jr' online.") == true)
assert(NS.CommOfflineLine("Momentan ist kein Spieler mit dem Namen 'Otto Anders' online.") == false)
assert(NS.CommOfflineLine("Abunazir Jr ist jetzt offline.") == false, "the offline line itself stays")
assert(NS.CommOfflineLine(nil) == false)
STUB.tick(61)
assert(NS.CommOfflineLine("Momentan ist kein Spieler mit dem Namen 'Abunazir Jr' online.") == false, "a minute later it is not ours")

-- a message from the name: it is back
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1VQ", "GUILD", "Abunazir Jr", "", 0, 0, "", 0)
assert(NS.CommSend("YA", { "beef", 1429, 3999 }, "WHISPER", "Abunazir Jr") == true, "back online: whispers go again")
-- two minutes after the offline line it would go anyway
STUB.fire("CHAT_MSG_SYSTEM", "Abunazir Jr ist jetzt offline.")
assert(not NS.CommSend("YA", { "beef", 1429, 3999 }, "WHISPER", "Abunazir Jr"))
STUB.tick(121)
assert(NS.CommSend("YA", { "beef", 1429, 3999 }, "WHISPER", "Abunazir Jr") == true, "after two minutes")
print("comm offline ok")
