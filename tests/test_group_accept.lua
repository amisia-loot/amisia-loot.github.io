-- Accepting group invites (Raid/GroupAccept.lua, F-163, D-93): off by default; on, an invite from a
-- guild member (the roster's spelling, the own realm's ending dropped) or a friend is accepted
-- (AcceptGroup), the client's window "PARTY_INVITE" closed, one line in the own chat; anyone else, a
-- first name alone, another realm's namesake, a secret sender: nothing; the roster not read yet: the
-- answer waits for it; the event twice: one accept; the section is everyone's (raider view too).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local GA = NS.GroupAccept

STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 4, class = "WARRIOR", online = false },
}
STUB.friends = { { name = "Fritz Freund", className = "Magier", online = true }, { name = "Anna Bergmann", className = "Priester", online = true } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

local ACC, HIDDEN = 0, {}
_G.AcceptGroup = function() ACC = ACC + 1 end
_G.StaticPopup_Hide = function(which) HIDDEN[#HIDDEN + 1] = which end
local function invite(name)
    GA._reset()
    STUB.messages = {}
    STUB.fire("PARTY_INVITE_REQUEST", name, false, false, false, true)
    STUB.tick(1)
end

-- a raider sees the section in the raid tab
NS.Set("ui.view", "raider")
local sec
for _, g in ipairs(NS.SettingsGroups()) do
    for _, s in ipairs(g.sections) do if s.key == "invites" then sec = { group = g.key, s = s } end end
end
assert(sec and sec.group == "raid", "the section in the tab Raid, also for raiders")

-- off by default
assert(NS.Get("invites.accept") == false)
invite("Anna Bergmann")
assert(ACC == 0 and #STUB.messages == 0, "off: the client asks")
NS.Set("invites.accept", true)

-- a guild member (also on the friend list: "Gilde"); the own realm's ending
invite("Anna Bergmann")
assert(ACC == 1 and HIDDEN[1] == "PARTY_INVITE" and #HIDDEN == 2, "accepted, the window closed now and next frame")
assert(has(STUB.messages[1], "Einladung von Anna Bergmann angenommen (Gilde)."), STUB.messages[1])
invite("Bob Eisherz-Realm")
assert(ACC == 2 and has(STUB.messages[1], "Bob Eisherz angenommen (Gilde)"), "an offline member by the roster: " .. tostring(STUB.messages[1]))
-- a friend outside the guild
invite("Fritz Freund")
assert(ACC == 3 and has(STUB.messages[1], "Einladung von Fritz Freund angenommen (Freund)."), STUB.messages[1])

-- nobody else: a stranger, a first name alone, another realm's namesake, a secret or empty sender
for _, who in ipairs({ "Zora Fremd", "Anna", "Anna Bergmann-Fremdrealm", "" }) do
    invite(who)
    assert(ACC == 3, "not accepted: " .. who)
end
STUB.secret["Anna Bergmann"] = true
invite("Anna Bergmann")
STUB.secret["Anna Bergmann"] = nil
assert(ACC == 3 and #STUB.messages == 0, "a secret sender: nothing")

-- the client fires the event twice: one accept
GA._reset()
STUB.fire("PARTY_INVITE_REQUEST", "Fritz Freund")
STUB.fire("PARTY_INVITE_REQUEST", "Fritz Freund")
assert(ACC == 4, "once")

-- already in a group: nothing
STUB.roster = { { name = "Vuloo" }, { name = "Fritz Freund" } }
invite("Anna Bergmann")
assert(ACC == 4, "in a group")
STUB.roster = {}

-- no AcceptGroup in the client: nothing, no line
_G.AcceptGroup = nil
invite("Anna Bergmann")
assert(#STUB.messages == 0, "without the client's function: no line")
_G.AcceptGroup = function() ACC = ACC + 1 end

-- out of the guild: friends still count, the former guild does not
STUB.inGuild = false
invite("Anna Bergmann")
assert(ACC == 5 and has(STUB.messages[1], "(Freund)"), "a friend: " .. tostring(STUB.messages[1]))
STUB.friends = {}
invite("Bob Eisherz")
assert(ACC == 5, "no guild: no guild member")
STUB.inGuild = nil

-- the roster not read yet: the answer waits for it (ns.TrustWait), then the member is accepted
local keep = STUB.guild
STUB.guild = {}
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
invite("Anna Bergmann")
assert(ACC == 5, "waits for the roster")
STUB.guild = keep
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
assert(ACC == 6, "accepted once the roster is there")
print("group accept ok")
