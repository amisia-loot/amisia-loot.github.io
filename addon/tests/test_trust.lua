-- Trust (Trust.lua): the guild roster through C_Club, officer ranks from the rank permissions with
-- their fallback and the setting, ns.TrustName, waiting while the roster is empty, the lockdown.
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Kim Eisherz", class = "WARRIOR" },
                { name = "Vulo Sturmwind", class = "PRIEST" }, { name = "Vulo Eisherz", class = "SHAMAN" } }
STUB.officer = false
local GUILD = {
    { name = "Anna Weide", rank = 1 }, { name = "Vuloo", rank = 2 }, { name = "Fraktur", rank = 2 },
    { name = "Kim Eisherz", rank = 4 }, { name = "Vulo Sturmwind", rank = 2, online = false }, { name = "Lia Sturm-Wind", rank = 5 },
}

---------------------------------------------------------------------------
-- an empty roster: nothing is known, the roster is asked for, data waits up to 60 s
---------------------------------------------------------------------------
assert(#STUB.guild == 0)
local asked = STUB.guildRequests
assert(NS.IsVerifiedOfficer("Fraktur") == nil, "empty roster: unknown")
local m, why = NS.GuildMember("Fraktur")
assert(m == nil and why == "unknown")
assert(NS.IsVerifiedMember("Fraktur") == nil)
assert(STUB.guildRequests > asked, "the roster is asked for")
local verdicts = {}
NS.TrustWait("Fraktur", "officer", function(ok) verdicts.fraktur = ok end)
NS.TrustWait("Kim Eisherz", "member", function(ok) verdicts.kim = ok end)
assert(verdicts.fraktur == nil and verdicts.kim == nil, "waiting")
STUB.tick(20)
assert(verdicts.fraktur == nil, "still waiting")
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
STUB.guild = GUILD
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(2)
assert(verdicts.fraktur == true and verdicts.kim == true, "checked once the roster is there")
-- a wait that never gets a roster ends after 60 s with no
STUB.guild = {}
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
assert(NS.IsVerifiedOfficer("Fraktur") == nil, "empty again")
local late
NS.TrustWait("Fraktur", "officer", function(ok) late = ok end)
STUB.tick(59)
assert(late == nil)
STUB.tick(2)
assert(late == false, "dropped after 60 s")
-- at most 20 wait at once; more are dropped at once
local count, refused = 0, 0
for i = 1, 21 do NS.TrustWait("Fraktur", "officer", function(ok) if ok == false then refused = refused + 1 end end) end
assert(refused == 1, "the 21st is dropped: " .. refused)
STUB.tick(61)
assert(refused == 21)

---------------------------------------------------------------------------
-- the roster through C_Club
---------------------------------------------------------------------------
STUB.guild = GUILD
STUB.fire("CLUB_MEMBERS_UPDATED", 77)
STUB.tick(11)
local calls = STUB.clubCalls
m = NS.GuildMember("Kim Eisherz")
assert(m and m.name == "Kim Eisherz" and m.rank == 4 and m.guid == "Player-1-1004" and m.online == true, "a member with rank and guid")
assert(STUB.clubCalls > 0, "read through C_Club")
assert(NS.GuildMember("vulo sturmwind").online == false, "offline, any case")
m, why = NS.GuildMember("Pug Fremd")
assert(m == nil and why == nil, "not in the guild")
assert(NS.GuildMember("Kim").name == "Kim Eisherz", "first name alone when it is unique in the guild")
assert(NS.IsVerifiedMember("Kim Eisherz") == true and NS.IsVerifiedMember("Pug Fremd") == false)

---------------------------------------------------------------------------
-- officer ranks: the rank permission 22
---------------------------------------------------------------------------
assert(NS.IsOfficerRank(1) and NS.IsOfficerRank(2) and not NS.IsOfficerRank(3) and not NS.IsOfficerRank(4))
assert(NS.IsVerifiedOfficer("Fraktur") == true)
assert(NS.IsVerifiedOfficer("Kim Eisherz") == false)
assert(NS.IsVerifiedOfficer("Pug Fremd") == false, "outside the guild")
assert(NS.SelfIsOfficer() == true, "Vuloo has rank 2")
local list, source = NS.RankList()
assert(source == "Rangrechte" and #list == 5, tostring(source))
assert(list[1].rank == 1 and list[1].name == "Gildenmeister" and list[1].officer == true and list[1].members == 1)
assert(list[2].officer == true and list[2].members == 3)
assert(list[4].officer == false and list[4].members == 1 and list[3].members == 0)
-- implausible flags (the guild master without the officer flag): the fallback
STUB.rankFlags = { [2] = { [22] = true } }
assert(NS.IsOfficerRank(1) and NS.IsOfficerRank(2) and not NS.IsOfficerRank(3), "not an officer: ranks 1 and 2")
assert(select(2, NS.RankList()) == "Rückfall")
STUB.rankFlags = {}
STUB.officer = true
GUILD[2].rank = 3
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
assert(NS.GuildMember("Vuloo").rank == 3)
assert(NS.IsOfficerRank(3) and not NS.IsOfficerRank(4), "an officer: ranks 1 up to the own rank")
STUB.officer = false
assert(NS.IsOfficerRank(2) and not NS.IsOfficerRank(3), "back to 1 and 2")
-- the flags cannot be read at all
local flagsFn = C_GuildInfo.GuildControlGetRankFlags
C_GuildInfo.GuildControlGetRankFlags = nil
assert(NS.IsOfficerRank(2) and not NS.IsOfficerRank(3))
C_GuildInfo.GuildControlGetRankFlags = function() return nil end
assert(NS.IsOfficerRank(2) and not NS.IsOfficerRank(3))
C_GuildInfo.GuildControlGetRankFlags = function() error("nope") end
assert(NS.IsOfficerRank(2) and not NS.IsOfficerRank(3))
C_GuildInfo.GuildControlGetRankFlags = flagsFn
-- the setting: exactly ranks 1 to N
STUB.rankFlags = { [1] = { [22] = true }, [2] = { [22] = true } }
assert(NS.Set("sync.officerRanks", 4) == true)
assert(NS.IsOfficerRank(4) and not NS.IsOfficerRank(5) and NS.IsVerifiedOfficer("Kim Eisherz") == true)
assert(select(2, NS.RankList()) == "Einstellung")
assert(NS.Set("sync.officerRanks", 1) == true)
assert(NS.IsOfficerRank(1) and not NS.IsOfficerRank(2))
assert(NS.Set("sync.officerRanks", 11) == false, "1 to 10 only")
NS.Set("sync.officerRanks", "auto")
GUILD[2].rank = 2
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
assert(NS.IsVerifiedOfficer("Fraktur") == true)

---------------------------------------------------------------------------
-- a forced officer view makes nobody an officer
---------------------------------------------------------------------------
GUILD[2].rank = 4
STUB.fire("CLUB_MEMBER_UPDATED", 77, 1002)
STUB.tick(11)
NS.Set("ui.view", "officer")
assert(NS.IsOfficerView() == true and NS.SelfIsOfficer() == false, "the own rank decides")
NS.Set("ui.view", "auto")
GUILD[2].rank = 2
STUB.fire("CLUB_MEMBER_UPDATED", 77, 1002)
-- the roster is rebuilt at most every 10 s
STUB.tick(1)
assert(NS.SelfIsOfficer() == false, "not rebuilt within 10 s")
STUB.tick(10)
assert(NS.SelfIsOfficer() == true)

---------------------------------------------------------------------------
-- the lockdown: no C_Club query, nothing verified
---------------------------------------------------------------------------
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
STUB.chatLock = true
calls = STUB.clubCalls
assert(NS.IsVerifiedOfficer("Fraktur") == nil, "unknown in the lockdown")
assert(select(2, NS.GuildMember("Fraktur")) == "unknown")
local inLock
NS.TrustWait("Fraktur", "officer", function(ok) inLock = ok end)
STUB.tick(5)
assert(STUB.clubCalls == calls, "no C_Club query in the lockdown")
assert(inLock == nil)
STUB.chatLock = false
STUB.tick(2)
assert(inLock == true, "checked after the lockdown")

---------------------------------------------------------------------------
-- ns.TrustName: group or guild name of a raw sender
---------------------------------------------------------------------------
assert(NS.TrustName("Kim Eisherz") == "Kim Eisherz")
assert(NS.TrustName("kim eisherz") == "Kim Eisherz")
assert(NS.TrustName("Kim Eisherz-Realm") == "Kim Eisherz", "a realm ending")
assert(NS.TrustName("Kim") == "Kim Eisherz", "the first name alone, unique in the group")
assert(NS.TrustName("Vulo") == nil, "two Vulo in the group: no one")
assert(NS.TrustName("Vulo Sturmwind") == "Vulo Sturmwind")
assert(NS.TrustName("Anna Weide") == "Anna Weide", "a guild member outside the group")
assert(NS.TrustName("Anna") == "Anna Weide")
assert(NS.TrustName("Lia Sturm-Wind") == "Lia Sturm-Wind", "a dash in the surname")
assert(NS.TrustName("Lia Sturm-Wind-Realm") == "Lia Sturm-Wind")
-- only the own realm's ending is cut off: a player of another realm is not the guild member
assert(NS.TrustName("Kim Eisherz-Anderswo") == nil and NS.TrustName("Anna Weide-Anderswo") == nil, "another realm")
STUB.realm = "Anderswo"
assert(NS.TrustName("Kim Eisherz-Anderswo") == "Kim Eisherz" and NS.TrustName("Kim Eisherz-Realm") == nil, "the own realm decides")
STUB.realm = nil
assert(NS.TrustName("Pug Fremd") == nil and NS.TrustName("Pug Fremd-Realm") == nil, "unknown")
assert(NS.TrustName("") == nil and NS.TrustName(nil) == nil and NS.TrustName(42) == nil)
STUB.secret["Fraktur"] = true
assert(NS.TrustName("Fraktur") == nil, "a secret value is unknown")
STUB.secret["Fraktur"] = nil
assert(NS.InMyGroup("Kim") == true and NS.InMyGroup("Anna Weide") == false and NS.InMyGroup("Vulo") == false)
-- through the index of the roster: any case, the own realm's ending, the first name
assert(NS.TrustName("anna weide-realm") == "Anna Weide" and NS.TrustName("ANNA") == "Anna Weide", "any case, realm")
assert(NS.TrustName("lia sturm-wind-Realm") == "Lia Sturm-Wind")
assert(NS.GuildMember("anna weide").name == "Anna Weide" and NS.GuildMember("anna").name == "Anna Weide", "a member in any case")
assert(NS.GuildMember("Anna Fremd") == nil, "a first name with another surname is no one")

---------------------------------------------------------------------------
-- a big guild: the roster is indexed once per build, not per sender
---------------------------------------------------------------------------
local big = {}
for _, m in ipairs(GUILD) do big[#big + 1] = m end
for i = 1, 500 do big[#big + 1] = { name = "Mitglied" .. string.char(97 + i % 26) .. i .. " Weit", rank = 4 } end
-- the same first name in the guild (Anna) and twice the same spelling in two cases
big[#big + 1] = { name = "Anna Fluss", rank = 4 }
big[#big + 1] = { name = "Kim eisherz", rank = 5 }
STUB.guild = big
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
assert(NS.GuildMember("mitgliedv489 weit").name == "Mitgliedv489 Weit", "a member far down the list")
assert(NS.TrustName("Mitgliedv489 Weit-Realm") == "Mitgliedv489 Weit")
assert(NS.GuildMember("Anna") == nil and NS.TrustName("Anna") == nil, "two Annas in the guild: no one")
assert(NS.GuildMember("Kim Eisherz").rank == 4, "the first of two spellings")
assert(NS.GuildMember("Kim") == nil, "Kim twice in the roster")
assert(NS.TrustName("Kim") == "Kim Eisherz", "one spelling in group and guild: one name")
local fullName, calls = NS.FullName, 0
NS.FullName = function(...) calls = calls + 1; return fullName(...) end
for _ = 1, 10 do
    NS.TrustName("Mitgliedv489 Weit")
    NS.GuildMember("Mitgliedv489 Weit")
end
NS.FullName = fullName
assert(calls < 200, "no pass over the guild per lookup: " .. calls)
STUB.guild = GUILD
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)

---------------------------------------------------------------------------
-- /amisia sync raenge
---------------------------------------------------------------------------
STUB.messages = {}
NS.Dispatch("sync raenge")
local out = table.concat(STUB.messages, "\n")
assert(out:find("Gildenränge (Quelle: Rangrechte):", 1, true), out)
assert(out:find("Rang 1 · Gildenmeister · 1 Mitglied · Offiziersrang", 1, true), out)
assert(out:find("Rang 2 · Offizier · 3 Mitglieder · Offiziersrang", 1, true), out)
assert(out:find("Rang 3 · Veteran · 0 Mitglieder · kein Offiziersrang", 1, true), out)
for ch in out:gmatch("[\194-\244][\128-\191]*") do assert(ch:byte(1) <= 195, "Latin-1 only") end
STUB.chatLock = true
STUB.messages = {}
NS.Dispatch("sync raenge")
assert(table.concat(STUB.messages, "\n"):find("Die Gildenliste ist gerade nicht lesbar", 1, true), "in the lockdown")
STUB.chatLock = false

---------------------------------------------------------------------------
-- outside a guild
---------------------------------------------------------------------------
STUB.inGuild = false
STUB.fire("PLAYER_GUILD_UPDATE")
STUB.tick(11)
m, why = NS.GuildMember("Fraktur")
assert(m == nil and why == nil and NS.IsVerifiedOfficer("Fraktur") == false and NS.SelfIsOfficer() == false)
assert(NS.TrustName("Anna Weide") == nil and NS.TrustName("Kim Eisherz") == "Kim Eisherz", "only the group is left")
STUB.messages = {}
NS.Dispatch("sync raenge")
assert(table.concat(STUB.messages, "\n"):find("Du bist in keiner Gilde.", 1, true))

-- all texts of the file are Latin-1
local src = assert(io.open(ADDON_DIR .. "/Core/Trust.lua", "rb")):read("*a")
for ch in src:gmatch("[\194-\244][\128-\191]*") do assert(ch:byte(1) <= 195, "a character beyond Latin-1 in Trust.lua") end
