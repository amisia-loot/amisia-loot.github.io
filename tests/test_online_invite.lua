-- "[Einladen]" behind "ist jetzt online" (F-197, Raid/OnlineInvite.lua): the line gets the link, a click
-- invites; not for oneself, someone in the group, a group this client may not invite to, a secret line,
-- another system line or with the switch off.
local OI = NS.OnlineInvite
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

_G.ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h ist jetzt online."
local function line(name) return ("|Hplayer:%s|h[%s]|h ist jetzt online."):format(name, name) end

-- the name of the line; another line names nobody
assert(OI.NameOf(line("Illnath Pala")) == "Illnath Pala")
assert(OI.NameOf("|Hplayer:Detlef Bugati:12|h[Detlef Bugati]|h ist jetzt online.") == "Detlef Bugati", "fields after the name")
assert(OI.NameOf("Channel gewechselt: [1. Allgemein]") == nil)
assert(OI.NameOf(line("Kim") .. " extra") == nil, "only the whole line")
-- an English client, a positional format
_G.ERR_FRIEND_ONLINE_SS = "|Hplayer:%1$s|h[%2$s]|h has come online."
assert(OI.NameOf("|Hplayer:Kim|h[Kim]|h has come online.") == "Kim", "positional")
_G.ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h ist jetzt online."

-- the filter adds the link (alone, out of a group)
STUB.roster = {}
local blocked, text, a, b = OI.Filter(nil, "CHAT_MSG_SYSTEM", line("Illnath Pala"), "x", 7)
assert(blocked == false and a == "x" and b == 7, "the other arguments pass")
assert(has(text, "|Haddon:Amisia:inv:Illnath Pala|h[Einladen]|h"), text)
-- not for oneself
local me = NS.UnitFullName("player")
local _, own = OI.Filter(nil, "CHAT_MSG_SYSTEM", line(me))
assert(own == line(me), "not for oneself")
-- a secret line stays as it is
local secret = setmetatable({}, {})
_G.issecretvalue = function(v) return v == secret end
local _, s = OI.Filter(nil, "CHAT_MSG_SYSTEM", secret)
assert(s == secret, "a secret line untouched")
_G.issecretvalue = nil
-- the switch off
NS.Set("invites.onlineLink", false)
local _, off = OI.Filter(nil, "CHAT_MSG_SYSTEM", line("Illnath Pala"))
assert(off == line("Illnath Pala"), "off")
NS.Reset("invites.onlineLink")

-- in a group without the right to invite: no link; as leader: link, but not for a member
STUB.roster = { { name = me, class = "PRIEST" }, { name = "Kim Eisherz", class = "PRIEST" } }
STUB.leader = false
local _, noRight = OI.Filter(nil, "CHAT_MSG_SYSTEM", line("Illnath Pala"))
assert(noRight == line("Illnath Pala") and not OI.CanInvite(), "no right, no link")
STUB.leader = true
local _, lead = OI.Filter(nil, "CHAT_MSG_SYSTEM", line("Illnath Pala"))
assert(has(lead, "[Einladen]"), "the leader gets it")
local _, member = OI.Filter(nil, "CHAT_MSG_SYSTEM", line("Kim Eisherz"))
assert(member == line("Kim Eisherz"), "already in the group")

-- the name in its class colour: a guild member by the roster, a friend by the friend list
local group = STUB.roster
STUB.guild = { { name = "Sickofme Nevermore", class = "SHAMAN", online = true, rank = 3 } }
STUB.friends = { { name = "Anna Bergmann", className = "Priester" } }
_G.LOCALIZED_CLASS_NAMES_MALE = _G.LOCALIZED_CLASS_NAMES_MALE or { PRIEST = "Priester" }
_G.LOCALIZED_CLASS_NAMES_MALE.PRIEST = _G.LOCALIZED_CLASS_NAMES_MALE.PRIEST or "Priester"
if NS.GuildRosterChanged then NS.GuildRosterChanged() end
STUB.fire("GUILD_ROSTER_UPDATE")
assert(OI.ClassOf("Sickofme Nevermore") == "SHAMAN", tostring(OI.ClassOf("Sickofme Nevermore")))
local _, coloured = OI.Filter(nil, "CHAT_MSG_SYSTEM", line("Sickofme Nevermore"))
local hex = RAID_CLASS_COLORS.SHAMAN.colorStr
assert(has(coloured, "|h[|c" .. hex .. "Sickofme Nevermore|r]|h ist jetzt online."), coloured)
assert(has(coloured, "[Einladen]"), "the link too")
assert(OI.ClassOf("Anna Bergmann") == "PRIEST", "a friend")
assert(OI.Colour(line("Niemand Hier"), "Niemand Hier") == line("Niemand Hier"), "no class: as it is")
NS.Set("invites.onlineClass", false)
local _, plain = OI.Filter(nil, "CHAT_MSG_SYSTEM", line("Sickofme Nevermore"))
assert(not has(plain, "|c" .. hex), "switch off: no colour")
NS.Reset("invites.onlineClass")
STUB.guild, STUB.friends, STUB.roster = {}, {}, group

-- a click invites
local invited
_G.C_PartyInfo = _G.C_PartyInfo or {}
local orig = C_PartyInfo.InviteUnit
C_PartyInfo.InviteUnit = function(n) invited = n end
OI.OnLink(nil, "addon:Amisia:inv:Illnath Pala", "[Einladen]")
assert(invited == "Illnath Pala", tostring(invited))
invited = nil
OI.OnLink(nil, "addon:Other:inv:Illnath Pala")
OI.OnLink(nil, "player:Illnath Pala")
assert(invited == nil, "other links are not ours")
OI.OnLink(nil, "addon:Amisia:inv:Kim Eisherz")
assert(invited == nil, "a member is not invited again")
STUB.leader = false
OI.OnLink(nil, "addon:Amisia:inv:Illnath Pala")
assert(invited == nil, "no right: no invite")
C_PartyInfo.InviteUnit = orig
STUB.roster = {}
print("online invite ok")
