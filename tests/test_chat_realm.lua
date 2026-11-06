--[[preload
C_Club = nil
]]
-- Senders with the own realm's ending ("Name-Realm", as modern clients write the chat sender and
-- the classic guild roster): the !-commands get the group or guild spelling as who (the answer
-- still goes to the raw sender), the own echo is skipped, the classic roster stores the name without
-- the ending, the loot boss is found in a five-man party, and the raider sees the head button
-- "Einstellungen" to the sections Wer braucht das? and Loot-Prio.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
-- the classic roster (no C_Club, the preload) writes the own realm behind every name
STUB.guild = { { name = "Vuloo-Realm", rank = 1 }, { name = "Fraktur-Realm", rank = 3 }, { name = "Gast-Realm", rank = 3 },
               { name = "Fremd-Anderswo", rank = 3 } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

---------------------------------------------------------------------------
-- Trust.lua: the classic roster's names without the own realm
---------------------------------------------------------------------------
local m = NS.GuildMember("Gast")
assert(m and m.name == "Gast", "stored without the own realm: " .. tostring(m and m.name))
assert(NS.TrustName("Gast-Realm") == "Gast", tostring(NS.TrustName("Gast-Realm")))
assert(NS.GuildMember("Fremd-Anderswo") and NS.GuildMember("Fremd") == nil, "another realm keeps its ending")

---------------------------------------------------------------------------
-- Chat.lua: who for the handlers, the own echo skipped
---------------------------------------------------------------------------
local calls = {}
NS.RegisterChatCommand("realmtest", function(sender, rest, chan, who)
    calls[#calls + 1] = { sender = sender, rest = rest, chan = chan, who = who }
end)
STUB.fire("CHAT_MSG_WHISPER", "!realmtest eins", "Fraktur-Realm")
assert(#calls == 1 and calls[1].sender == "Fraktur-Realm" and calls[1].who == "Fraktur" and calls[1].rest == "eins",
    calls[1] and tostring(calls[1].who) or "no call")
STUB.fire("CHAT_MSG_RAID", "!realmtest", "Fraktur")
assert(#calls == 2 and calls[2].who == "Fraktur")
-- a stranger of the own realm: the ending away; of another realm: as it came
STUB.fire("CHAT_MSG_WHISPER", "!realmtest", "Niemand-Realm")
assert(calls[3].who == "Niemand", tostring(calls[3].who))
STUB.fire("CHAT_MSG_WHISPER", "!realmtest", "Niemand-Anderswo")
assert(calls[4].who == "Niemand-Anderswo", tostring(calls[4].who))
-- the own line with the realm ending is no command
STUB.fire("CHAT_MSG_RAID", "!realmtest", "Vuloo-Realm")
STUB.fire("CHAT_MSG_RAID", "!realmtest", "Vuloo")
assert(#calls == 4, "the own echo is skipped: " .. #calls)

---------------------------------------------------------------------------
-- !bench from "Gast-Realm": the entry is for Gast, the answer goes to Gast-Realm
---------------------------------------------------------------------------
STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.IsLootLead(), "the player leads the loot")
STUB.chat = {}
STUB.fire("CHAT_MSG_WHISPER", "!bench", "Gast-Realm")
local s = NS.BenchTarget()
assert(NS.IsBenched(s, "Gast") and not NS.IsBenched(s, "Gast-Realm"), "benched under the guild name")
local reply = STUB.chat[#STUB.chat]
assert(reply and reply.chan == "WHISPER" and reply.target == "Gast-Realm" and has(reply.text, "Ersatzbank"),
    reply and reply.text or "no answer")
-- Fraktur-Realm is in the raid: matched to the roster
STUB.tick(20); STUB.chat = {}
STUB.fire("CHAT_MSG_WHISPER", "!bench", "Fraktur-Realm")
reply = STUB.chat[#STUB.chat]
assert(reply and reply.target == "Fraktur-Realm" and has(reply.text, "schon im Raid"), reply and reply.text or "no answer")

-- !sr from "Fraktur-Realm": the soft-reserves of Fraktur, whispered to Fraktur-Realm
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
NS.SetSoftRes("Fraktur 32235\n")
STUB.tick(20); STUB.chat = {}
STUB.fire("CHAT_MSG_WHISPER", "!sr", "Fraktur-Realm")
reply = STUB.chat[#STUB.chat]
assert(reply and reply.target == "Fraktur-Realm" and has(reply.text, link), reply and reply.text or "no answer")

---------------------------------------------------------------------------
-- Need.lua: the leader of a five-man party (no raid units there)
---------------------------------------------------------------------------
local inRaid, unitName, isLeader = IsInRaid, UnitName, UnitIsGroupLeader
IsInRaid = function() return false end
UnitName = function(u)
    if u == "party1" then return "Fraktur" end
    if u == "player" then return "Vuloo" end
    if type(u) == "string" and u:match("^party%d$") then return nil end
    return unitName(u)
end
UnitIsGroupLeader = function(u)
    if type(u) == "string" and u:match("^raid") then error("no raid unit in a party: " .. u) end
    return u == "party1"
end
assert(NS.IsLootBossName("Fraktur") == true, "the party leader")
assert(NS.IsLootBossName("Vuloo") == false and NS.IsLootBossName("Niemand") == false)
UnitIsGroupLeader = function(u) return u == "player" end
assert(NS.IsLootBossName("Vuloo") == true and NS.IsLootBossName("Fraktur") == false)
IsInRaid, UnitName, UnitIsGroupLeader = inRaid, unitName, isLeader
-- in a raid the raid units again
STUB.roster[2].leader = true
assert(NS.IsLootBossName("Fraktur") == true)
STUB.roster[2].leader = nil

---------------------------------------------------------------------------
-- Settings: the raider reaches Wer braucht das? and Loot-Prio from the pages they use
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
local function sections(page)
    local out = {}
    for _, sec in ipairs(NS.SettingsSectionsOf(page)) do out[sec.key] = true end
    return out
end
local awards = sections("awards")
assert(awards.need and awards.prio, "the awards page leads to need and prio")
assert(sections("gear").prio, "the gear table leads to prio")
assert(sections("rolls").need and sections("rolls").prio, "the rolls page keeps both")
for _, page in ipairs({ "awards", "gear", "rolls" }) do assert(NS.Panel(page), "page " .. page) end
