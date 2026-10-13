-- Invite on whisper "inv" (Raid/LineupInvite.lua, F-084, D-41, user 2026-10-12): off by default;
-- on, an officer who leads (or is alone) invites a guild member who whispers exactly "inv" or
-- "invite" (any case) while a recording runs or tonight has a lineup; a non-member is refused with a
-- line in the own chat, a guest of the lineup only with "Gäste einladen"; one per sender in 30 s and
-- ten a minute; nothing in combat, the lockdown, without the lead, in the raider view or for a secret
-- whisper; the three invites per name and night count here too; nothing goes to the chat of others.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local IV = NS.LineupInv

_G.ERR_DECLINE_GROUP_S = "%s lehnt Eure Einladung in die Gruppe ab."
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
}
for i = 1, 12 do STUB.guild[#STUB.guild + 1] = { name = "Rekrut Nummer" .. ("abcdefghijkl"):sub(i, i), rank = 4, class = "MAGE" } end
STUB.friends = { { name = "Gustav Gast", className = "Krieger", online = true } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
STUB.roster, STUB.leader = {}, true
_G.UnitIsGroupLeader = function() return STUB.leader end
local INV = {}
C_PartyInfo.InviteUnit = function(name) INV[#INV + 1] = name end
local function whisper(text, from)
    STUB.fire("CHAT_MSG_WHISPER", text, from)
    STUB.tick(1)
end

-- off by default
whisper("inv", "Anna Bergmann")
assert(#INV == 0, "the setting is off")
NS.Set("lineup.inv", true)
-- no recording, no lineup tonight: nothing
whisper("inv", "Anna Bergmann")
assert(#INV == 0, "no night is on")
local night = NS.SetLineupText("Bob Eisherz Tank\nGustav Gast Nahkampf")
assert(night == NS.LineupTonight())

-- a guild member: invited, one line in the own chat, nothing to others
STUB.chat, STUB.messages = {}, {}
whisper("inv", "Anna Bergmann")
assert(#INV == 1 and INV[1] == "Anna Bergmann", "invited")
assert(said("Einladen auf Flüstern: Anna Bergmann wird eingeladen."), STUB.messages[1])
assert(#STUB.chat == 0, "no chat line to anybody")
-- the whole text only, any case; the own realm's ending
whisper("  INVITE ", "Bob Eisherz-Realm")
assert(#INV == 2 and INV[2] == "Bob Eisherz", tostring(INV[2]))
IV._reset()
whisper("inv pls", "Anna Bergmann")
whisper("!inv", "Anna Bergmann")
whisper("kannst du mich inv", "Anna Bergmann")
assert(#INV == 2, "only the exact word")

-- not in the guild: refused, in the own chat only
STUB.messages = {}
whisper("inv", "Zora Fremd")
assert(#INV == 2)
assert(said("Einladen auf Flüstern: Zora Fremd ist nicht in der Gilde, nicht eingeladen."), STUB.messages[1])
-- another realm is no guild member
whisper("inv", "Anna Bergmann-Fremdrealm")
assert(#INV == 2, "another realm's Anna is not ours")
-- a guest of the lineup: only with "Gäste einladen"
whisper("inv", "Gustav Gast")
assert(#INV == 2, "a guest without the setting")
IV._reset()
NS.Set("lineup.guests", true)
whisper("inv", "Gustav Gast")
assert(#INV == 3 and INV[3] == "Gustav Gast", "a guest of the lineup with the setting")
NS.Set("lineup.guests", false)

-- one per sender in 30 s
IV._reset()
whisper("inv", "Anna Bergmann")
STUB.fire("CHAT_MSG_SYSTEM", ERR_DECLINE_GROUP_S:format("Anna Bergmann"))
whisper("inv", "Anna Bergmann")
assert(#INV == 4, "the second within 30 s is ignored")
STUB.tick(30)
whisper("inv", "Anna Bergmann")
assert(#INV == 5, "after 30 s again")
-- three invites per name and night, the whisper counts
STUB.fire("CHAT_MSG_SYSTEM", ERR_DECLINE_GROUP_S:format("Anna Bergmann"))
STUB.tick(31)
whisper("inv", "Anna Bergmann")
assert(#INV == 6)
STUB.fire("CHAT_MSG_SYSTEM", ERR_DECLINE_GROUP_S:format("Anna Bergmann"))
STUB.tick(31)
STUB.messages = {}
whisper("inv", "Anna Bergmann")
assert(#INV == 6 and said("Anna Bergmann hat schon 3 Einladungen heute."), STUB.messages[1])

-- ten a minute in all
IV._reset()
INV = {}
for i = 1, 12 do whisper("inv", "Rekrut Nummer" .. ("abcdefghijkl"):sub(i, i)) end
assert(#INV <= 10, "ten a minute at most: " .. #INV)

-- nothing in combat, the lockdown, a secret whisper, without the lead, in the raider view
IV._reset()
STUB.tick(61)
INV = {}
STUB.combat = true
whisper("inv", "Bob Eisherz")
STUB.combat = false
STUB.chatLock = true
whisper("inv", "Bob Eisherz")
STUB.chatLock = false
STUB.secret["inv"] = true
whisper("inv", "Bob Eisherz")
STUB.secret["inv"] = nil
STUB.roster = { { name = "Vuloo" }, { name = "Zora Fremd" } }
STUB.leader = false
whisper("inv", "Bob Eisherz")
STUB.roster, STUB.leader = {}, true
NS.Set("ui.view", "raider")
whisper("inv", "Bob Eisherz")
NS.Set("ui.view", "officer")
assert(#INV == 0, "none of these invites")
-- and now it goes
whisper("inv", "Bob Eisherz")
assert(#INV == 1, "then it goes")

-- a first name is no proof (review 2026-10-13): the guild has "Ida" without surname, the raid an
-- "Ida Gruen"; "Ida Fremd" whispers: the group makes the first name unclear, so the guild's first-name
-- match must not let the stranger in; the guild's "Ida" herself still is
STUB.guild[#STUB.guild + 1] = { name = "Ida", rank = 3, class = "MAGE" }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(61)
IV._reset()
INV = {}
STUB.roster = { { name = "Vuloo" }, { name = "Ida Gruen" } }
STUB.messages = {}
whisper("inv", "Ida Fremd")
assert(#INV == 0, "the stranger is not invited: " .. tostring(INV[1]))
assert(said("Ida Fremd ist nicht in der Gilde"), STUB.messages[1])
STUB.roster = {}
whisper("inv", "Ida")
assert(#INV == 1 and INV[1] == "Ida", tostring(INV[1]))

-- strangers never use up the shared limit (review 2026-10-13): twelve strangers, then a member is
-- still invited; a stranger gets at most one line in the own chat per five minutes
IV._reset()
STUB.tick(61)
INV = {}
STUB.messages = {}
for i = 1, 12 do whisper("inv", "Fremder Nummer" .. ("abcdefghijkl"):sub(i, i)) end
whisper("inv", "Anna Bergmann")
assert(#INV == 1 and INV[1] == "Anna Bergmann", "the member after twelve strangers: " .. #INV)
STUB.messages = {}
STUB.tick(31)
whisper("inv", "Fremder Nummera")
STUB.tick(31)
whisper("inv", "Fremder Nummera")
assert(#STUB.messages == 0, "no second line for the same stranger: " .. tostring(STUB.messages[1]))
STUB.tick(300)
whisper("inv", "Fremder Nummera")
assert(said("Fremder Nummera ist nicht in der Gilde"), "after five minutes one line again")

-- a whisper never makes a raid (review 2026-10-13): a full party (no raid) sends nothing and says
-- so once; not in a party instance (a 5-player dungeon) either
local realRaid, realGroup = _G.IsInRaid, _G.IsInGroup
_G.IsInRaid = function() return false end
_G.IsInGroup = function(cat) return cat ~= LE_PARTY_CATEGORY_INSTANCE and #STUB.roster > 0 end
local CONV = 0
local realConv = C_PartyInfo.ConvertToRaid
C_PartyInfo.ConvertToRaid = function() CONV = CONV + 1 end
IV._reset()
STUB.tick(61)
INV = {}
STUB.roster = { { name = "Vuloo" }, { name = "Rekrut Nummera" }, { name = "Rekrut Nummerb" }, { name = "Rekrut Nummerc" },
                { name = "Rekrut Nummerd" } }
STUB.messages = {}
whisper("inv", "Bob Eisherz")
STUB.tick(3)
assert(#INV == 0 and CONV == 0, "a full party: no invite, no raid: " .. #INV .. " " .. CONV)
assert(said("Einladen auf Flüstern: Gruppe voll, erst in einen Raid umwandeln."), STUB.messages[1])
-- four in the party, three whisper at once: one is invited, nothing converts
STUB.roster[5] = nil
whisper("inv", "Bob Eisherz")
whisper("inv", "Anna Bergmann")
whisper("inv", "Rekrut Nummere")
STUB.tick(3)
assert(#INV == 1 and CONV == 0, "one place, one invite, no raid: " .. #INV .. " " .. CONV)
-- a 5-player dungeon: nothing
IV._reset()
INV = {}
STUB.roster = { { name = "Vuloo" } }
STUB.instance = { name = "Todesminen", type = "party", id = 36 }
whisper("inv", "Bob Eisherz")
STUB.tick(3)
assert(#INV == 0, "not in a party instance")
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
_G.IsInRaid, _G.IsInGroup, C_PartyInfo.ConvertToRaid = realRaid, realGroup, realConv
STUB.roster = {}
NS.Set("lineup.inv", false)
