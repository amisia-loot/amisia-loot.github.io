-- "Gilde einladen" (Raid/LineupInvite.lua, UI/Pages/Lineup.lua, F-163, D-93): the guild down to a rank
-- (rank order, 1 the guild master; lineup.inviteRank, the page's picker), online, not in the group,
-- not the player; after a question with the number; through the run of "Alle einladen" (one every
-- 0.5 s, the raid after the first join, three invites per name and night, never in combat, only with
-- the lead, only tonight); also on a night without a lineup, whose view "Einladen" now shows the
-- guild's invites with their status; a lineup player keeps his row and group; the raider view sees
-- nothing.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local IV = NS.LineupInv

_G.ERR_DECLINE_GROUP_S = "%s lehnt Eure Einladung in die Gruppe ab."
_G.ERR_JOINED_GROUP_S = "%s schließt sich der Gruppe an."
_G.ERR_RAID_MEMBER_ADDED_S = "%s hat sich der Schlachtgruppe angeschlossen."

STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Gerda Gross", rank = 1, class = "WARRIOR" },
    { name = "Olaf Offizier", rank = 2, class = "PALADIN" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Carl Eiche", rank = 3, class = "WARRIOR" },
    { name = "Dora Licht", rank = 3, class = "PALADIN" },
    { name = "Emil Pfeil", rank = 3, class = "HUNTER" },
    { name = "Kim Sturmwind", rank = 3, class = "ROGUE", online = false },
    { name = "Rudi Rekrut", rank = 5, class = "MAGE" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

-- the group: alone, a party, a raid (as in test_lineup_invite.lua)
local GRP = { raid = false }
_G.IsInRaid = function(cat)
    if cat == LE_PARTY_CATEGORY_INSTANCE then return false end
    return GRP.raid and #STUB.roster > 0
end
_G.IsInGroup = function(cat)
    if cat == LE_PARTY_CATEGORY_INSTANCE then return false end
    return #STUB.roster > 0
end
_G.GetRaidRosterInfo = function(i)
    local m = STUB.roster[i]
    if not m then return nil end
    return m.name, m.rank or 0, m.sub or 1, 60, m.class, m.class, "Shattrath", m.online ~= false
end
_G.UnitIsGroupLeader = function() return STUB.leader end
_G.UnitIsGroupAssistant = function() return STUB.assist == true end
local INV, CONV = {}, 0
C_PartyInfo.InviteUnit = function(name) INV[#INV + 1] = { name = name, t = STUB.clock } end
C_PartyInfo.ConvertToRaid = function()
    CONV = CONV + 1
    C_Timer.After(0.3, function()
        GRP.raid = true
        STUB.fire("GROUP_ROSTER_UPDATE")
    end)
end
local function sys(tpl, name) STUB.fire("CHAT_MSG_SYSTEM", _G[tpl]:format(name)) end
local function join(name)
    if #STUB.roster == 0 then STUB.roster[1] = { name = "Vuloo", class = "PRIEST", rank = 2 } end
    STUB.roster[#STUB.roster + 1] = { name = name, class = "WARRIOR", sub = math.floor(#STUB.roster / 5) + 1 }
    sys(GRP.raid and "ERR_RAID_MEMBER_ADDED_S" or "ERR_JOINED_GROUP_S", name)
    STUB.fire("GROUP_ROSTER_UPDATE")
end
local function alone()
    STUB.roster, GRP.raid, STUB.leader, STUB.assist = {}, false, true, false
    STUB.fire("GROUP_ROSTER_UPDATE")
end
local function names(list)
    local out = {}
    for i, it in ipairs(list) do out[i] = it.n or it.name end
    return table.concat(out, ",")
end
alone()

-- the raider view: nothing
NS.Set("ui.view", "raider")
local count, why = NS.LineupInviteGuild(nil, 3)
assert(not count and why == "Nur für Offiziere", tostring(why))
NS.Set("ui.view", "officer")

---------------------------------------------------------------------------
-- who: rank 3 and higher, online, not the player, not in the group
---------------------------------------------------------------------------
assert(NS.Get("lineup.inviteRank") == 10, "the default: every rank")
local t = NS.LineupGuildTargets(nil, 3)
assert(names(t) == "Anna Bergmann,Bob Eisherz,Carl Eiche,Dora Licht,Emil Pfeil,Gerda Gross,Olaf Offizier", names(t))
t = NS.LineupGuildTargets(nil, 2)
assert(names(t) == "Gerda Gross,Olaf Offizier", "rank 2 and higher: " .. names(t))
assert(#NS.LineupGuildTargets() == 8, "the setting (every rank): with the recruit")
assert(NS.LineupRankText(2) == "Offizier" and NS.LineupRankText(10) == "Rekrut (alle Ränge)" and NS.LineupRankText(5) == "Rekrut (alle Ränge)",
    NS.LineupRankText(10))
-- no guild, no roster
STUB.inGuild = false
count, why = NS.LineupGuildTargets(nil, 3)
assert(not count and why == "Du bist in keiner Gilde.", tostring(why))
STUB.inGuild = nil
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

---------------------------------------------------------------------------
-- the page on a night without a lineup: the view "Einladen", the picker, the link, the question
---------------------------------------------------------------------------
NS.ShowLineup("invite")
local f = NS.PageFrame("lineup")
assert(NS.CurrentPage() == "lineup" and f.inv:IsShown(), "the view on a night without a list")
assert(f.guildInv:IsShown() and f.guildInv:IsEnabled() and f.guildRank:IsShown(), "link and picker")
assert(not f.inviteAll:IsShown() and not f.again:IsShown(), "no lineup: no \"Alle einladen\"")
assert(f.empty:IsShown() and has(f.empty.title:GetText(), "Niemand eingeladen"), "nobody yet")
assert(has(f.calLine:GetText(), "Ohne Aufstellung"), f.calLine:GetText())
assert(#f.guildRank.values == 5 and f.guildRank.values[3].text == "bis Veteran", tostring(f.guildRank.values[3] and f.guildRank.values[3].text))
assert(f.guildRank:GetValue() == 5, "the setting 10 shows the lowest rank")
-- the picker sets the setting
f.guildRank.onPick(3)
assert(NS.Get("lineup.inviteRank") == 3 and f.guildRank:GetValue() == 3)
-- the question names the number; Abbrechen invites nobody
f.guildInv:Click()
local ask = _G.AmisiaConfirmFrame
assert(ask and ask:IsShown() and has(ask.text:GetText(), "7 Gildenmitglieder bis Rang Veteran einladen?"), ask.text:GetText())
ask.cancel:Click()
STUB.tick(2)
assert(#INV == 0, "cancelled")
-- Einladen: the party fills up to five (the player and four), then the raid after the first join
STUB.messages = {}
f.guildInv:Click()
ask.ok:Click()
assert(said("Gilde einladen: 7 Spieler, einer alle 0,5 Sekunden."), STUB.messages[1])
STUB.tick(0.1)
assert(#INV == 1, "the first at once")
STUB.tick(3)
assert(#INV == 4, "alone: four invites wait, the party is full: " .. #INV)
for i = 2, #INV do assert(INV[i].t - INV[i - 1].t >= 0.5 - 1e-6, "one every 0.5 s") end
-- the rows: invited, by the guild, no group
NS.Refresh()
local function rowOf(name)
    for _, r in ipairs(f.invRows.rows) do
        if r:IsShown() and r.item and ((r.item.extra and r.item.extra.n == name) or r.item.name == name) then return r end
    end
end
local r = rowOf("Anna Bergmann")
assert(r and has(r.st:GetText(), "eingeladen") and has(r.act:GetText(), "über Gilde einladen") and r.tries:GetText() == "1/3",
    r and r.st:GetText())
assert(not f.empty:IsShown(), "rows now")
assert(not f.guildInv:IsEnabled(), "off while the run invites")
-- the first joins: the raid, then the rest
join(INV[1].name)
STUB.tick(2)
assert(CONV == 1 and GRP.raid, "the party became a raid")
STUB.tick(3)
assert(#INV == 7, "the rest after the raid: " .. #INV)
NS.Refresh()
r = rowOf(INV[1].name)
assert(r and has(r.st:GetText(), "im Raid") and has(r.act:GetText(), "über Gilde einladen"), r and r.st:GetText())
-- a decline: the row says so; a second click invites the declined again, the joined and invited not
sys("ERR_DECLINE_GROUP_S", "Bob Eisherz")
NS.Refresh()
r = rowOf("Bob Eisherz")
assert(r and has(r.st:GetText(), "abgelehnt"), r and r.st:GetText())
STUB.tick(3)
t = NS.LineupGuildTargets(nil, 3)
assert(names(t) == "Bob Eisherz", "only the declined: " .. names(t))
-- three invites per name and night
for _ = 1, 2 do
    INV = {}
    assert(NS.LineupInviteGuild(nil, 3) == 1)
    STUB.tick(1)
    assert(#INV == 1 and INV[1].name == "Bob Eisherz")
    sys("ERR_DECLINE_GROUP_S", "Bob Eisherz")
    STUB.tick(1)
end
count, why = NS.LineupInviteGuild(nil, 3)
assert(not count and why == "Niemand einzuladen", "three tries used: " .. tostring(why))
NS.Refresh()
assert(rowOf("Bob Eisherz").tries:GetText() == "3/3")


---------------------------------------------------------------------------
-- never in combat, without the lead, on another night
---------------------------------------------------------------------------
IV._reset()
alone()
INV = {}
STUB.combat = true
count, why = NS.LineupInviteGuild(nil, 3)
assert(not count and why == "Nicht im Kampf", tostring(why))
NS.Refresh()
assert(not f.guildInv:IsEnabled(), "off in combat")
STUB.combat = false
STUB.roster = { { name = "Vuloo" }, { name = "Fremd Leiter" } }
STUB.leader = false
count, why = NS.LineupInviteGuild(nil, 3)
assert(not count and why == "Nur als Leiter oder Assistent", tostring(why))
alone()
count, why = NS.LineupInviteGuild("2026-12-31", 3)
assert(not count and why == "Nur für heute Abend", tostring(why))
-- a fight stops the run
assert(NS.LineupInviteGuild(nil, 3) == 7)
STUB.tick(0.6)
STUB.fire("PLAYER_REGEN_DISABLED")
local n = #INV
STUB.tick(3)
assert(#INV == n and n <= 2, "the fight stopped it: " .. #INV)
STUB.fire("PLAYER_REGEN_ENABLED")

---------------------------------------------------------------------------
-- with a lineup: a placed player keeps his row and group, the others are the guild's rows
---------------------------------------------------------------------------
IV._reset()
alone()
INV = {}
NS.Set("lineup.whisper", true)
local night = NS.SetLineupText("Anna Bergmann Heiler\nBob Eisherz Tank")
NS.LineupAutoAssign(night)
STUB.chat = {}
assert(NS.LineupInviteGuild(night, 2) == 2, "rank 2: two")
STUB.tick(2)
NS.ShowLineup("invite", night)
NS.Refresh()
assert(f.inviteAll:IsShown() and f.guildInv:IsShown(), "both with a lineup")
r = rowOf("Gerda Gross")
assert(r and has(r.act:GetText(), "über Gilde einladen"))
assert(NS.LineupInviteGuild(night, 3) == 5, "then rank 3: the party takes two more (the lineup's Anna and Bob first by name)")
STUB.tick(2)
assert(#INV == 4)
local states = NS.LineupInviteStates(night)
assert(states["anna bergmann"].by == nil and states["gerda gross"].by == "guild", "a placed player is no guild row")
-- the whisper names the lineup's group for a placed player only
local whispers = {}
for _, c in ipairs(STUB.chat) do if c.chan == "WHISPER" then whispers[c.target] = c.text end end
assert(whispers["Anna Bergmann"] and has(whispers["Anna Bergmann"], "(Gruppe 1)") and not whispers["Gerda Gross"], tostring(whispers["Anna Bergmann"]))
NS.Set("lineup.whisper", false)
-- a whisper invite of somebody not on the lineup shows the same way, "auf Flüstern" (by "inv")
IV._reset()
alone()
NS.Set("lineup.inv", true)
STUB.fire("CHAT_MSG_WHISPER", "inv", "Rudi Rekrut")
STUB.tick(1)
NS.Refresh()
r = rowOf("Rudi Rekrut")
assert(r and has(r.act:GetText(), "auf Flüstern") and has(r.st:GetText(), "eingeladen"), r and r.act:GetText())
NS.Set("lineup.inv", false)
-- /reload: the states are gone (memory only), the guild invite starts over
IV._reset()
assert(#NS.LineupInviteExtra(night) == 0)
print("lineup guild invite ok")
