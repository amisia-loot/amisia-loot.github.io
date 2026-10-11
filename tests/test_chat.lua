-- Chat queue: throttling, the chat lockdown, ttl, keys, the limit, long lines, ns.ChatLines and
-- incoming !-commands.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
local function texts()
    local out = {}
    for i, c in ipairs(STUB.chat) do out[i] = c.text end
    return out
end

-- immediate send while the bucket holds enough
assert(NS.ChatLocked() == false)
assert(NS.Say("hallo", "RAID") == "sent")
assert(STUB.chat[1].text == "hallo" and STUB.chat[1].chan == "RAID")
assert(NS.Say("psst", "WHISPER", "Fraktur-Realm") == "sent")
assert(STUB.chat[2].chan == "WHISPER" and STUB.chat[2].target == "Fraktur-Realm", "whisper goes to the raw target")
assert(NS.Say("", "RAID") == nil and NS.Say(nil, "RAID") == nil, "nothing to say")
assert(NS.Say("x", "WHISPER") == nil, "a whisper needs a target")
assert(NS.ChatQueueSize() == 0)

-- throttling: 2000 bytes at once, 800 bytes per second after that
STUB.tick(5); STUB.chat = {}
local line = string.rep("a", 240)
local got = {}
for i = 1, 10 do got[i] = NS.Say(line .. i, "RAID") end
assert(got[8] == "sent" and got[9] == "queued" and got[10] == "queued", tostring(got[8]) .. tostring(got[9]))
assert(#STUB.chat == 8 and NS.ChatQueueSize() == 2, #STUB.chat)
STUB.tick(0.25)
assert(#STUB.chat == 9 and STUB.chat[9].text == line .. 9, "refilled bucket sends the next line in order")
STUB.tick(0.5)
assert(#STUB.chat == 10 and NS.ChatQueueSize() == 0)
-- a new line waits behind a queued one instead of jumping it
STUB.tick(5); STUB.chat = {}
for i = 1, 9 do NS.Say(line .. i, "RAID") end
assert(NS.Say("kurz", "RAID") == "queued", "order kept while lines wait")
STUB.tick(2)
assert(STUB.chat[#STUB.chat].text == "kurz" and NS.ChatQueueSize() == 0)

-- the lockdown holds everything; the event releases it
STUB.tick(5); STUB.chat = {}
STUB.chatLock = true
assert(NS.ChatLocked() == true)
assert(NS.Say("im Kampf", "RAID") == "queued")
STUB.tick(3)
assert(#STUB.chat == 0 and NS.ChatQueueSize() == 1, "nothing goes out during the lockdown")
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
STUB.tick(0)
assert(#STUB.chat == 1 and STUB.chat[1].text == "im Kampf", "released by the event")
-- without the event the next check (every 2 s) releases it
STUB.chatLock = true
NS.Say("ohne Ereignis", "RAID")
STUB.tick(1)
STUB.chatLock = false
STUB.tick(2.25)
assert(#STUB.chat == 2 and STUB.chat[2].text == "ohne Ereignis", "released by the poll")
assert(NS.ChatQueueSize() == 0)

-- ttl: the countdown expires, the loot line waits
STUB.chat = {}
STUB.chatLock = true
NS.Say("3 Sekunden.", "RAID", nil, { ttl = 3 })
NS.Say("Ansage", "RAID")
STUB.tick(5)
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0); STUB.tick(0)
assert(#STUB.chat == 1 and STUB.chat[1].text == "Ansage", table.concat(texts(), "|"))

-- the same key replaces the waiting line
STUB.chat = {}
STUB.chatLock = true
NS.Say("alt", "RAID", nil, { key = "k" })
assert(NS.Say("neu", "RAID", nil, { key = "k" }) == "queued")
assert(NS.ChatQueueSize() == 1)
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0); STUB.tick(0)
assert(#STUB.chat == 1 and STUB.chat[1].text == "neu")

-- at most 40 waiting lines, one message per minute about the rest
STUB.chat = {}; STUB.messages = {}
STUB.chatLock = true
for i = 1, 40 do assert(NS.Say("z" .. i, "RAID") == "queued") end
local ok, why = NS.Say("z41", "RAID")
assert(ok == nil and why, "the 41st line is refused")
NS.Say("z42", "RAID")
local full = 0
for _, m in ipairs(STUB.messages) do if m:find("Chat-Warteschlange voll", 1, true) then full = full + 1 end end
assert(full == 1, "reported once: " .. full)
assert(NS.ChatQueueSize() == 40)
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0); STUB.tick(0)
assert(#STUB.chat == 40 and STUB.chat[40].text == "z40" and NS.ChatQueueSize() == 0)

-- a line over 255 bytes is cut at the last space, never inside a link
STUB.tick(5); STUB.chat = {}
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local long = string.rep("wort ", 46) .. link .. " ende"
assert(#long > 255)
NS.Say(long, "RAID")
local sent = STUB.chat[1].text
assert(#sent <= 255, #sent)
assert(not sent:find("|H", 1, true) and not sent:find("|c", 1, true), "the link is left out whole: " .. sent)
assert(sent:sub(-4) == "wort", sent:sub(-10))
local front = link .. " " .. string.rep("wort ", 60)
NS.Say(front, "RAID")
sent = STUB.chat[2].text
assert(#sent <= 255 and sent:sub(1, #link) == link, "a link at the front stays whole")
assert(not sent:find(" $"), "no trailing space")

-- ns.ChatLines: whole parts, at most 250 bytes a line, the head only on the first line
local parts = {}
for i = 1, 60 do parts[i] = ("Name%04d"):format(i) end
local lines = NS.ChatLines("Ohne Reserve: ", parts)
assert(#lines > 1)
assert(lines[1]:sub(1, 14) == "Ohne Reserve: ")
local joined = {}
for i, l in ipairs(lines) do
    assert(#l <= 250, #l)
    if i > 1 then assert(not l:find("Ohne Reserve", 1, true)) end
    for p in l:gsub("^Ohne Reserve: ", ""):gmatch("[^,%s]+") do joined[#joined + 1] = p end
end
assert(#joined == 60 and joined[60] == "Name0060", #joined)
local links = {}
for i = 1, 6 do links[i] = link end
for _, l in ipairs(NS.ChatLines("Items: ", links, " ")) do
    local _, n1 = l:gsub("|Hitem:", "")
    local _, n2 = l:gsub("|h|r", "")
    assert(n1 == n2, "links stay whole")
end
assert(#NS.ChatLines("Kopf", {}) == 1 and NS.ChatLines("Kopf", {})[1] == "Kopf")

-- channels: raid warning without rights becomes raid, raid without raid party, alone nothing
STUB.chat = {}
STUB.leader = false
NS.Say("w", "RAID_WARNING")
assert(STUB.chat[1].chan == "RAID")
STUB.leader = true
NS.Say("w", "RAID_WARNING")
assert(STUB.chat[2].chan == "RAID_WARNING")
local isRaid = IsInRaid
IsInRaid = function() return false end
NS.Say("p", "RAID")
assert(STUB.chat[3].chan == "PARTY")
IsInRaid = isRaid
local roster = STUB.roster
STUB.roster = {}
assert(NS.Say("allein", "RAID") == nil and #STUB.chat == 3)
assert(NS.Say("allein", "WHISPER", "Fraktur") == "sent", "a whisper needs no group")
STUB.roster = roster

-- ns.Announce goes through the queue and waits in the lockdown
STUB.chat = {}
STUB.chatLock = true
NS.Announce("Roll auf etwas")
assert(#STUB.chat == 0 and NS.ChatQueueSize() == 1)
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0); STUB.tick(0)
assert(#STUB.chat == 1 and STUB.chat[1].chan == "RAID_WARNING")
NS.Announce("kurz", 3)
assert(STUB.chat[2].text == "kurz")

-- a send error drops the line and reports once a minute
STUB.messages = {}
STUB.sendError = "blocked"
assert(NS.Say("kaputt", "RAID") == nil)
NS.Say("kaputt2", "RAID")
STUB.sendError = nil
local errs = 0
for _, m in ipairs(STUB.messages) do if m:find("konnte nicht gesendet werden", 1, true) then errs = errs + 1 end end
assert(errs == 1, "send error reported once: " .. errs)
assert(NS.ChatQueueSize() == 0)

-- without the lockdown query nothing is locked
local info = C_ChatInfo
C_ChatInfo = nil
assert(NS.ChatLocked() == false)
C_ChatInfo = {}
assert(NS.ChatLocked() == false)
C_ChatInfo = info

-- incoming !-commands
local calls = {}
NS.RegisterChatCommand("sr", function(sender, rest, chan) calls[#calls + 1] = { sender = sender, rest = rest, chan = chan } end)
STUB.fire("CHAT_MSG_WHISPER", "!SR  Fluchsicht ", "Fraktur-Realm")
assert(#calls == 1 and calls[1].sender == "Fraktur-Realm" and calls[1].rest == "Fluchsicht" and calls[1].chan == "WHISPER",
    calls[1] and (calls[1].rest .. "/" .. calls[1].chan) or "no call")
STUB.fire("CHAT_MSG_RAID", "!sr", "Chorf")
assert(#calls == 2 and calls[2].rest == "" and calls[2].chan == "RAID")
STUB.fire("CHAT_MSG_RAID_LEADER", "!Sr", "Chorf")
STUB.fire("CHAT_MSG_PARTY", "!sr", "Chorf")
STUB.fire("CHAT_MSG_PARTY_LEADER", "!sr", "Chorf")
assert(#calls == 5 and calls[3].chan == "RAID" and calls[4].chan == "PARTY")
STUB.fire("CHAT_MSG_RAID", "sr bitte", "Chorf")
STUB.fire("CHAT_MSG_RAID", "!unbekannt", "Chorf")
STUB.fire("CHAT_MSG_RAID", "!sr", "Vuloo")
assert(#calls == 5, "no !, unknown word and own lines are ignored")
STUB.secret["Chorf"] = true
STUB.fire("CHAT_MSG_RAID", "!sr", "Chorf")
STUB.secret["Chorf"] = nil
local secretText = "!sr geheim"
STUB.secret[secretText] = true
STUB.fire("CHAT_MSG_WHISPER", secretText, "Fraktur")
STUB.secret[secretText] = nil
assert(#calls == 5, "a secret sender or text is skipped")
-- a broken handler does not stop the event
NS.RegisterChatCommand("kaputt", function() error("boom") end)
local errh = geterrorhandler
local caught
geterrorhandler = function() return function(e) caught = e end end
STUB.fire("CHAT_MSG_WHISPER", "!kaputt", "Fraktur")
geterrorhandler = errh
assert(caught and tostring(caught):find("boom", 1, true))
