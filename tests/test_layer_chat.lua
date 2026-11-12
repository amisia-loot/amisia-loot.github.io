-- The plain chat convention of other layer addons (F-185 part 6, D-117): a short guild line or whisper
-- of a guild member such as "inv layer" is a layer request (the rule SW.IsRequestLine); it gets the same
-- question or automatic invite as an Amisia request, with the same limits, only from the guild, the
-- automatic invite only when the roster names the own zone; a YI and a chat line of one member make one
-- question; "Im Gildenchat fragen" opens the chat box with the setting's text; afterwards only a guild
-- member's invite is accepted; public channels are never read.
local SW, LY = NS.LayerChange, NS.Layer
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

-- the rule
for _, line in ipairs({ "inv layer", "Inv Layer", "layer inv pls", "layer 1,3", "layer", "  LAYER 2  ", "inv layer 1,3",
    "layer bitte", "einladen layer", "layer pls", "invite layer!" }) do
    assert(SW.IsRequestLine(line), "a request: " .. line)
end
for _, line in ipairs({ "which layer?", "inv layer?", "welcher layer bist du inv", "wer hat layer inv", "what layer inv",
    "[XYZ] inv layer", "inv", "layering inv", "players inv", "inv layer bitte, ich muss noch schnell zum Questgeber in Goldhain",
    "layer ist voll", "", "inv |cff00ff00layer|r" }) do
    assert(not SW.IsRequestLine(line), "no request: " .. line)
end
assert(not SW.IsRequestLine(nil) and not SW.IsRequestLine(12))
local secretLine = "inv layer"
STUB.secret[secretLine] = true
assert(not SW.IsRequestLine(secretLine), "a secret line is skipped")
STUB.secret[secretLine] = nil

-- the world: Elwynn, a guild with zones
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
STUB.place.map = 1429
_G.GetRealZoneText = function() return "Wald von Elwynn" end
STUB.guild = { { name = "Vuloo", rank = 2 }, { name = "Anna Bergmann", rank = 3, zone = "Wald von Elwynn" },
    { name = "Kai Lindner", rank = 3, zone = "Dun Morogh" }, { name = "Bob Ohnezone", rank = 3, zone = "" },
    { name = "Eva Zweite", rank = 3, zone = "Wald von Elwynn" } }
STUB.roster = {}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(15)
local INVITED, ACCEPTED, OPENED = {}, 0, {}
C_PartyInfo.InviteUnit = function(n) INVITED[#INVITED + 1] = n end
_G.AcceptGroup = function() ACCEPTED = ACCEPTED + 1 end
_G.StaticPopup_Hide = function() end
_G.ChatFrame_OpenChat = function(text) OPENED[#OPENED + 1] = text end
local function confirmShown() return AmisiaConfirmFrame ~= nil and AmisiaConfirmFrame:IsShown() end
local function closeConfirm() if confirmShown() then AmisiaConfirmFrame:Hide() end end

-- a guild line of a member in the own zone: the question (no auto invite by default)
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Anna Bergmann")
STUB.tick(1)
assert(confirmShown() and AmisiaConfirmFrame.text:GetText() == "Anna Bergmann bittet im Chat um einen Layer-Wechsel. Einladen?")
AmisiaConfirmFrame.ok:Click()
assert(INVITED[1] == "Anna Bergmann", "invited after the question")
-- the same member again within a minute: no invite (quiet: another addon may have invited already)
local before = #STUB.messages
STUB.tick(11)
STUB.fire("CHAT_MSG_WHISPER", "layer 2", "Anna Bergmann")
STUB.tick(1)
AmisiaConfirmFrame.ok:Click()
assert(#INVITED == 1 and #STUB.messages == before, "the minute limit, no line")

-- auto invite: only when the roster names the own zone
NS.Set("layer.autoInvite", true)
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Eva Zweite")
STUB.tick(1)
assert(INVITED[2] == "Eva Zweite" and not confirmShown(), "same zone: invited at once")
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Kai Lindner")
STUB.tick(1)
assert(#INVITED == 2 and not confirmShown(), "another zone: nothing")
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Bob Ohnezone")
STUB.tick(1)
assert(#INVITED == 2 and confirmShown() and has(AmisiaConfirmFrame.text:GetText(), "Bob Ohnezone"), "zone unknown: only the question")
closeConfirm()
-- a stranger, the own line, a public channel, a say: nothing
STUB.fire("CHAT_MSG_WHISPER", "inv layer", "Udo Fremd")
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Vuloo")
STUB.fire("CHAT_MSG_CHANNEL", "inv layer", "Eva Zweite", "", "1. layer", "", "", 0, 1, "layer")
STUB.fire("CHAT_MSG_SAY", "inv layer", "Anna Bergmann")
STUB.tick(61)
assert(#INVITED == 2 and not confirmShown(), "strangers, the own line, channels and say are not read")
-- the setting off
NS.Set("layer.chat", false)
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Eva Zweite")
STUB.tick(1)
assert(#INVITED == 2, "off")
NS.Set("layer.chat", true)
-- in an instance or a full group nothing
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Eva Zweite")
STUB.tick(1)
STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }
assert(#INVITED == 2, "not in an instance")

-- one question for a YI and a chat line of the same member: an Amisia request first
NS.Set("layer.autoInvite", false)
STUB.targetGUID = "Creature-0-5250-0-3999-1-0A1"; STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = "Creature-0-5250-0-3999-2-0A2"; STUB.fire("PLAYER_TARGET_CHANGED")
assert(LY.Current() == 3999)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1YQ\t1429\t4012\tbeef", "GUILD", "Eva Zweite")
STUB.tick(3)
STUB.fire("CHAT_MSG_ADDON", "Amisia", "1YI\tbeef\t1429\t3999", "WHISPER", "Eva Zweite")
STUB.tick(1)
assert(confirmShown() and has(AmisiaConfirmFrame.text:GetText(), "Eva Zweite möchte auf deinen Layer wechseln"))
closeConfirm()
STUB.fire("CHAT_MSG_GUILD", "inv layer", "Eva Zweite")
STUB.tick(1)
assert(not confirmShown(), "the chat line right after the YI makes no second question")

-- the asker: "Im Gildenchat fragen" opens the chat box with the setting's text
NS.Set("layer.chatText", "layer inv bitte")
assert(SW.AskChat() == true and OPENED[1] == "/g layer inv bitte", tostring(OPENED[1]))
assert(NS.Get("layer.chatText") == "layer inv bitte")
NS.Set("layer.chatText", "eine viel zu lange Zeile für den Gildenchat, die keiner liest")
assert(NS.Get("layer.chatText") == "layer inv bitte", "too long is refused")
-- a stranger's invite stays untouched; a guild member's is accepted
STUB.fire("PARTY_INVITE_REQUEST", "Udo Fremd")
STUB.tick(1)
assert(ACCEPTED == 0, "not a guild member")
STUB.fire("PARTY_INVITE_REQUEST", "Kai Lindner")
STUB.tick(1)
assert(ACCEPTED == 1, "a guild member after the chat request")
-- the swap: the group of two, any other layer than before is the change
STUB.party = true
STUB.roster = { { name = "Vuloo" }, { name = "Kai Lindner" } }
STUB.fire("GROUP_ROSTER_UPDATE")
assert(SW.State().swap and SW.State().swap.host == "Kai Lindner")
STUB.targetGUID = "Creature-0-5250-0-7777-3-0B1"; STUB.fire("PLAYER_TARGET_CHANGED")
STUB.targetGUID = "Creature-0-5250-0-7777-4-0B2"; STUB.fire("PLAYER_TARGET_CHANGED")
assert(SW.State().swap.changed and SW.State().swap.target == 7777, "changed")
STUB.party, STUB.roster = nil, {}
STUB.fire("GROUP_ROSTER_UPDATE")
-- without the chat request (over a minute ago) an invite is the game's
STUB.tick(61)
STUB.fire("PARTY_INVITE_REQUEST", "Anna Bergmann")
STUB.tick(1)
assert(ACCEPTED == 1, "no request: untouched")
-- the client without the chat box: a reason
_G.ChatFrame_OpenChat = nil
local ok, why = SW.AskChat()
assert(not ok and has(why, "Chatzeile"), tostring(why))

-- a chat request while the own layer was unknown: nothing to compare with, so the window says that
-- instead of "Kein Wechsel"
SW._reset({ pending = { name = "Kai Lindner", map = 1429, at = GetTime(), invited = GetTime(), chat = true } })
STUB.party = true
STUB.roster = { { name = "Vuloo" }, { name = "Kai Lindner" } }
STUB.fire("GROUP_ROSTER_UPDATE")
assert(SW.State().swap and not SW.State().swap.from and not SW.State().swap.target)
STUB.tick(61)
assert(SW.State().swap.unknown and not SW.State().swap.failed and not SW.State().swap.changed)
local unknownText, leaveLink = NS.LayerWindow.StatusText(SW.State())
assert(has(unknownText, "vor der Anfrage unbekannt") and leaveLink == true, tostring(unknownText))
STUB.party, STUB.roster = nil, {}
STUB.fire("GROUP_ROSTER_UPDATE")
