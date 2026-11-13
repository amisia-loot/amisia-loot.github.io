-- The layer change beyond the guild (F-191, D-124): with layer.others (off by default) a request line
-- whispered by anyone or written into a chat channel gets the question "... (nicht in der Gilde) ...",
-- one for strangers in five seconds; with layer.othersAuto the invite goes at once, but only for a line
-- in a channel of the own zone; a guild member's line in a channel is handled as in the guild chat; the
-- own line, a secret line, an instance and the guild chat of a non-member give nothing. "Im Kanal fragen"
-- opens the chat box with "/<channel> <text>" and then anyone's invite is the swap; after "Im
-- Gildenchat fragen" a stranger's still is not. The trace counts calls, blocks, joins and request lines.
local SW, LY, LW = NS.LayerChange, NS.Layer, NS.LayerWindow
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
STUB.place.map = 1429
_G.GetRealZoneText = function() return "Wald von Elwynn" end
STUB.guild = { { name = "Vuloo", rank = 2 }, { name = "Anna Bergmann", rank = 3, zone = "Wald von Elwynn" },
    { name = "Kai Lindner", rank = 3, zone = "Dun Morogh" } }
STUB.roster = {}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(15)
local INVITED, ACCEPTED, LEFT, OPENED = {}, 0, 0, {}
C_PartyInfo.InviteUnit = function(n) INVITED[#INVITED + 1] = n end
C_PartyInfo.LeaveParty = function() LEFT = LEFT + 1 end
_G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
_G.StaticPopup_Hide = function() end
_G.ChatFrame_OpenChat = function(text) OPENED[#OPENED + 1] = text end
local CHANNELS = { [1] = "Allgemein - Wald von Elwynn", [4] = "layer" }
_G.GetChannelName = function(n) if CHANNELS[n] then return n, CHANNELS[n] end return 0, nil end
local function confirmShown() return AmisiaConfirmFrame ~= nil and AmisiaConfirmFrame:IsShown() end
local function closeConfirm() if confirmShown() then AmisiaConfirmFrame:Hide() end end
local function channel(text, sender, zoneChan, index, base)
    STUB.fire("CHAT_MSG_CHANNEL", text, sender, "", index .. ". " .. base, "", "", zoneChan, index, base)
    STUB.tick(1)
end
local function whisper(text, sender)
    STUB.fire("CHAT_MSG_WHISPER", text, sender)
    STUB.tick(1)
end

-- the default: off, strangers and channels give nothing, no line is counted
assert(NS.Get("layer.others") == false and NS.Get("layer.othersAuto") == false and NS.Get("layer.channel") == 1)
whisper("inv layer", "Udo Fremd")
channel("inv layer", "Udo Fremd", 1, 1, "Allgemein")
assert(not confirmShown() and #INVITED == 0, "off: nothing")
-- the whisper was looked at for the guild (layer.chat), the channel line not at all
assert(SW.Trace().lines.WHISPER == 1 and SW.Trace().lines.Allgemein == nil, "off: no channel line is looked at")

-- on: a stranger's whisper asks, the click invites
NS.Set("layer.others", true)
whisper("inv layer", "Udo Fremd")
assert(confirmShown() and AmisiaConfirmFrame.text:GetText() == "Udo Fremd (nicht in der Gilde) bittet im Chat um einen Layer-Wechsel. Einladen?",
    confirmShown() and AmisiaConfirmFrame.text:GetText() or "no question")
AmisiaConfirmFrame.ok:Click()
assert(INVITED[1] == "Udo Fremd" and SW.Trace().invite.tried == 1)
-- a second stranger within five seconds: nothing; after them: the question
whisper("layer", "Ina Zweite")
assert(not confirmShown(), "one stranger in five seconds")
STUB.tick(5)
channel("inv layer", "Ina Zweite", 0, 4, "layer")
assert(confirmShown() and has(AmisiaConfirmFrame.text:GetText(), "Ina Zweite (nicht in der Gilde)"), "a custom channel: the question")
closeConfirm()
assert(SW.Trace().lines.WHISPER == 3 and SW.Trace().lines.layer == 1, "the request lines are counted per place")

-- without a question: only in a channel of the own zone
NS.Set("layer.othersAuto", true)
STUB.tick(6)
channel("inv layer", "Olaf Dritter", 0, 4, "layer")
assert(#INVITED == 1 and confirmShown(), "a custom channel: zone unknown, the question")
closeConfirm()
STUB.tick(6)
whisper("inv layer", "Pia Vierte")
assert(#INVITED == 1 and confirmShown(), "a whisper: zone unknown, the question")
closeConfirm()
STUB.tick(6)
channel("inv layer", "Rolf Fuenfter", 1, 1, "Allgemein")
assert(INVITED[2] == "Rolf Fuenfter" and not confirmShown(), "the zone's channel: invited at once")
-- the guild's own setting does not invite strangers
NS.Set("layer.othersAuto", false)
NS.Set("layer.autoInvite", true)
STUB.tick(6)
channel("inv layer", "Susi Sechste", 1, 1, "Allgemein")
assert(#INVITED == 2 and confirmShown(), "layer.autoInvite is the guild's")
closeConfirm()

-- a guild member in a channel: as in the guild chat (the roster's zone decides, the guild's setting)
STUB.tick(6)
channel("inv layer", "Anna Bergmann", 1, 1, "Allgemein")
assert(INVITED[3] == "Anna Bergmann", "a member in the own zone: invited with layer.autoInvite")
channel("inv layer", "Kai Lindner", 0, 4, "layer")
assert(#INVITED == 3 and not confirmShown(), "a member in another zone: nothing")
NS.Set("layer.autoInvite", false)

-- nothing: the own line, a secret line, a question, the guild chat of a name the guild does not know,
-- an instance, the same stranger twice within the minute (quiet)
STUB.tick(6)
channel("inv layer", "Vuloo", 1, 1, "Allgemein")
local secretLine = "layer inv"
STUB.secret[secretLine] = true
channel(secretLine, "Tom Siebter", 1, 1, "Allgemein")
STUB.secret[secretLine] = nil
channel("which layer?", "Tom Siebter", 1, 1, "Allgemein")
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Tom Siebter"); STUB.tick(1)
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
channel("inv layer", "Tom Siebter", 1, 1, "Allgemein")
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
assert(not confirmShown() and #INVITED == 3, "nothing of these")
STUB.tick(11)
NS.Set("layer.othersAuto", true)
local before = #STUB.messages
channel("inv layer", "Rolf Fuenfter", 1, 1, "Allgemein")
assert(#INVITED == 3 and #STUB.messages == before, "the same player within a minute: no invite, no line")
NS.Set("layer.othersAuto", false)

-- the client blocks an invite: the trace says so
C_PartyInfo.InviteUnit = function() STUB.fire("ADDON_ACTION_FORBIDDEN", "Amisia", "C_PartyInfo.InviteUnit()") end
STUB.tick(61)
whisper("inv layer", "Udo Fremd")
AmisiaConfirmFrame.ok:Click()
local tr = SW.Trace()
assert(tr.invite.blocked == 1 and tr.invite.what == "C_PartyInfo.InviteUnit()", "blocked: " .. tostring(tr.invite.blocked))
STUB.fire("ADDON_ACTION_FORBIDDEN", "Amisia", "Irgendwas()")
STUB.fire("ADDON_ACTION_BLOCKED", "AnderesAddon", "C_PartyInfo.InviteUnit()")
assert(tr.invite.blocked == 1, "a block without a call of ours, or of another addon, is not counted")
C_PartyInfo.InviteUnit = function(n) INVITED[#INVITED + 1] = n end

-- the asker: "Im Kanal fragen" opens the channel of the setting with the text
SW._reset()
-- the own layer is known before the request, so the change can be seen
STUB.targetGUID = "Creature-0-5250-0-3999-1-0A1"; STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = "Creature-0-5250-0-3999-2-0A2"; STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 3999)
assert(SW.AskChannel() == true and OPENED[1] == "/1 inv layer", tostring(OPENED[1]))
local st = SW.State()
assert(st.chat and st.chatAll, "asked in the channel")
assert(LW.StatusText(st) == "Im Kanal gefragt: eine Minute lang nimmt Amisia die nächste Einladung an.")
-- anyone's invite is the swap now
STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd"); STUB.tick(1)
assert(ACCEPTED == 1 and SW.State().pending.name == "Udo Fremd", "a stranger's invite after the channel request")
STUB.party = true
STUB.roster = { { name = "Vuloo" }, { name = "Udo Fremd" } }
STUB.fire("GROUP_ROSTER_UPDATE")
assert(SW.State().swap and SW.State().swap.host == "Udo Fremd" and SW.Trace().accept.joined == 1)
STUB.targetGUID = "Creature-0-5250-0-7777-3-0B1"; STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = "Creature-0-5250-0-7777-4-0B2"; STUB.fire("PLAYER_TARGET_CHANGED")
assert(SW.State().swap.changed and SW.Trace().changed == 1, "changed")
assert(SW.Leave() == true and LEFT == 1)
STUB.party, STUB.roster = nil, {}
STUB.fire("GROUP_ROSTER_UPDATE")
assert(SW.Trace().leave.tried == 1 and SW.Trace().leave.left == 1 and SW.State().swap == nil)

-- another channel of the settings; a channel the player is not in: the reason
NS.Set("layer.channel", 4)
NS.Set("layer.chatText", "layer bitte")
assert(SW.AskChannel() == true and OPENED[2] == "/4 layer bitte", tostring(OPENED[2]))
NS.Set("layer.channel", 7)
local ok, why = SW.AskChannel()
assert(not ok and has(why, "keinem Kanal 7"), tostring(why))
-- not in a group, not in an instance
NS.Set("layer.channel", 1)
STUB.party, STUB.roster = true, { { name = "Vuloo" }, { name = "Anna Bergmann" } }
ok, why = SW.AskChannel()
assert(not ok and has(why, "Gruppe verlassen"), tostring(why))
STUB.party, STUB.roster = nil, {}
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
ok, why = SW.AskChannel()
assert(not ok and has(why, "Instanz"), tostring(why))
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }

-- after "Im Gildenchat fragen" a stranger's invite stays the game's
SW._reset()
STUB.fire("GROUP_ROSTER_UPDATE")
assert(SW.AskChat() == true and not SW.State().chatAll)
local accepted = ACCEPTED
STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd"); STUB.tick(1)
assert(ACCEPTED == accepted, "the guild chat request takes only a member's invite")

-- review fixes (D-124): a declined invite does not block the next request; a second player's invite takes
-- the place of the first; nothing is accepted inside an instance; who is asking does not host; with
-- layer.chat off a guild member's whisper is anyone's whisper (the question, never the automatic invite)
SW._reset()
NS.Set("layer.autoAccept", false)
assert(SW.AskChannel() == true)
STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd"); STUB.tick(1)
assert(SW.State().pending and SW.State().pending.name == "Udo Fremd", "the invite is noted, not taken")
NS.Set("layer.autoAccept", true)
accepted = ACCEPTED
STUB.fire("PARTY_INVITE_REQUEST", "Ina Zweite"); STUB.tick(1)
assert(ACCEPTED == accepted + 1 and SW.State().pending.name == "Ina Zweite", "the second player's invite is taken")
STUB.tick(120)
assert(SW.AskChannel() == true and SW.State().pending == nil, "a new request starts clean")
STUB.fire("PARTY_INVITE_REQUEST", "Olaf Dritter"); STUB.tick(1)
assert(ACCEPTED == accepted + 2, "accepted after an older, unanswered request")
-- inside an instance nothing is accepted, though the request is still open
SW._reset()
assert(SW.AskChannel() == true)
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
accepted = ACCEPTED
STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd"); STUB.tick(1)
assert(ACCEPTED == accepted, "never accepted in an instance")
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
-- who is asking does not host: two askers in the zone's channel do not invite each other
SW._reset()
NS.Set("layer.others", true)
NS.Set("layer.othersAuto", true)
local invitedBefore = #INVITED
assert(SW.AskChannel() == true)
channel("inv layer", "Zoe Achte", 1, 1, "Allgemein")
assert(#INVITED == invitedBefore and not confirmShown(), "asking: no invite, no question")
STUB.tick(61)
channel("inv layer", "Zoe Achte", 1, 1, "Allgemein")
assert(INVITED[#INVITED] == "Zoe Achte" and #INVITED == invitedBefore + 1, "a minute later the request is over")
NS.Set("layer.othersAuto", false)
-- layer.chat off, layer.others on: a member's whisper asks, the guild's automatic invite does not go
NS.Set("layer.chat", false)
NS.Set("layer.autoInvite", true)
invitedBefore = #INVITED
STUB.tick(61)
whisper("inv layer", "Anna Bergmann")
assert(#INVITED == invitedBefore and confirmShown() and has(AmisiaConfirmFrame.text:GetText(), "Anna Bergmann bittet im Chat"),
    "a member's whisper with layer.chat off: only the question")
closeConfirm()
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Anna Bergmann"); STUB.tick(11)
assert(#INVITED == invitedBefore and not confirmShown(), "the guild chat stays off")
NS.Set("layer.chat", true)
NS.Set("layer.autoInvite", false)

-- without a guild the window points at the channel, and a stranger's whisper still asks (no roster to wait for)
SW._reset()
STUB.inGuild = false
assert(not NS.InGuild())
assert(LW.StatusText(SW.State()) == "Frag im Kanal: wer dich einlädt, bringt dich auf seinen Layer.", LW.StatusText(SW.State()))
ok, why = SW.AskChat()
assert(not ok and has(why, "keiner Gilde"))
assert(SW.AskChannel() == true, "the channel needs no guild")
NS.Set("layer.others", true)
STUB.tick(61)
whisper("inv layer", "Udo Fremd")
assert(confirmShown() and has(AmisiaConfirmFrame.text:GetText(), "Udo Fremd (nicht in der Gilde)"), "without a guild")
closeConfirm()
print("layer others: whisper, channels, zone channel, limits, trace, channel request, no guild")
