-- Inviting the lineup (Raid/LineupInvite.lua, F-084, D-41): "Alle einladen" from a timer, one every
-- 0.5 s; alone the first four, the raid after the first join, then the rest; every status from the
-- client's system messages (its templates, the German ones of client 70338) and the roster: im Raid,
-- abgelehnt, schon in Gruppe, unbekannt, keine Antwort after 90 s, offline (not invited), unclear names
-- not invited; "Nochmal einladen" per click, three invites per name and night; the whisper with its
-- fixed text (off by default, once per name); guests only with the setting; never in combat, the
-- lockdown or without the lead; a fight stops a run; a secret system message is skipped; ERR_GROUP_FULL
-- puts the newest invite back; a /reload rebuilds the statuses from the roster.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local IV = NS.LineupInv

_G.ERR_INVITE_PLAYER_S = "Ihr habt %s eingeladen, sich Eurer Gruppe anzuschließen."
_G.ERR_DECLINE_GROUP_S = "%s lehnt Eure Einladung in die Gruppe ab."
_G.ERR_ALREADY_IN_GROUP_S = "%s gehört bereits zu einer Gruppe."
_G.ERR_BAD_PLAYER_NAME_S = "Spieler '%s' ist nicht auffindbar."
_G.ERR_GROUP_FULL = "Eure Gruppe ist voll."
_G.ERR_JOINED_GROUP_S = "%s schließt sich der Gruppe an."
_G.ERR_RAID_MEMBER_ADDED_S = "%s hat sich der Schlachtgruppe angeschlossen."

STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Carl Eiche", rank = 3, class = "WARRIOR" },
    { name = "Dora Licht", rank = 3, class = "PALADIN" },
    { name = "Emil Pfeil", rank = 3, class = "HUNTER" },
    { name = "Fritz Frost", rank = 3, class = "MAGE" },
    { name = "Gerd Glut", rank = 3, class = "WARLOCK" },
    { name = "Hanna Hain", rank = 3, class = "DRUID" },
    { name = "Kim Sturmwind", rank = 3, class = "ROGUE", online = false },
}
STUB.friends = { { name = "Gustav Gast", className = "Krieger", online = true } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")

-- the group: alone (empty roster), a party, a raid; the player is in the roster once grouped
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
alone()

local night = NS.SetLineupText(table.concat({
    "Bob Eisherz Tank", "Carl Eiche Tank", "Anna Bergmann Heiler", "Dora Licht Heiler", "Emil Pfeil Fernkampf",
    "Fritz Frost Fernkampf", "Gerd Glut Fernkampf", "Hanna Hain Heiler", "Kim Sturmwind Nahkampf",
    "Gustav Gast Nahkampf", "Vuloo Heiler", "Niemand Nirgends Nahkampf",
}, "\n"))
NS.LineupAutoAssign(night)
local function state(name) return NS.LineupInviteStates(night)[name:lower()] end

---------------------------------------------------------------------------
-- who may, when: the officer view, no fight, no lockdown, the lead
---------------------------------------------------------------------------
NS.Set("ui.view", "raider")
local n, why = NS.LineupInviteAll(night)
assert(n == nil and why == "Nur für Offiziere", tostring(why))
NS.Set("ui.view", "officer")
STUB.combat = true
n, why = NS.LineupInviteAll(night)
assert(n == nil and why == "Nicht im Kampf", tostring(why))
STUB.combat = false
STUB.chatLock = true
n, why = NS.LineupInviteAll(night)
assert(n == nil and why == "Nicht im Bosskampf", tostring(why))
STUB.chatLock = false
STUB.restricted = true
assert(select(2, NS.LineupInviteAll(night)) == "Nicht im Bosskampf", "the encounter restriction")
STUB.restricted = false
STUB.instance = { name = "Alteractal", type = "pvp", id = 30 }
assert(select(2, NS.LineupInviteAll(night)) == "Nicht im Schlachtfeld")
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
-- in a group without the lead: no
STUB.roster = { { name = "Vuloo", rank = 0 }, { name = "Zora Fremd", rank = 2 } }
STUB.leader = false
assert(select(2, NS.LineupInviteAll(night)) == "Nur als Leiter oder Assistent")
-- an assistant of a raid may; an assistant does not exist in a party
GRP.raid, STUB.assist = true, true
assert(NS.LineupLeadBlocked() == nil, "a raid assistant may")
GRP.raid = false
assert(NS.LineupLeadBlocked() == "lead", "a party member who is no leader may not")
alone()
STUB.tick(1)
assert(#INV == 0, "nothing was invited")

---------------------------------------------------------------------------
-- "Alle einladen": the first four alone, the raid after the first join, then the rest
---------------------------------------------------------------------------
local c = NS.LineupInviteCounts(night)
assert(c.todo == 8, "eight placed, online, clear guild members (not me, Kim offline, the guest and the unknown out): " .. c.todo)
assert(state("Kim Sturmwind").st == "O", "offline: not invited")
assert(state("Niemand Nirgends").st == "U", "an unclear name is not invited")
assert(state("Vuloo").st == "R", "the officer himself")
STUB.messages = {}
n = NS.LineupInviteAll(night)
assert(n == 8, n)
STUB.tick(3)
assert(#INV == 4, "alone: four invites first, got " .. #INV)
for i = 2, #INV do assert(INV[i].t - INV[i - 1].t >= 0.5 - 1e-6, "one invite every 0.5 s") end
STUB.tick(5)
assert(#INV == 4, "the party is full of invites: it waits")
for i = 1, 4 do assert(state(INV[i].name).st == "I", "eingeladen") end
sys("ERR_INVITE_PLAYER_S", INV[1].name)
assert(state(INV[1].name).st == "I")
-- the first joins: the group becomes a raid, then the rest
join(INV[1].name)
assert(state(INV[1].name).st == "R", "im Raid")
STUB.tick(0.2)
assert(CONV == 1, "converted after the first join")
STUB.tick(6)
assert(GRP.raid and #INV == 8, "the rest after the raid: " .. #INV)
for i = 2, #INV do assert(INV[i].t - INV[i - 1].t >= 0.5 - 1e-6, "one invite every 0.5 s") end
assert(said("Einladen: 8 eingeladen."), STUB.messages[#STUB.messages])
assert(not NS.LineupInviteRunning())

-- the answers
sys("ERR_DECLINE_GROUP_S", INV[2].name)
sys("ERR_ALREADY_IN_GROUP_S", INV[3].name)
sys("ERR_BAD_PLAYER_NAME_S", INV[4].name)
join(INV[5].name)
-- the first name alone in a message counts when only one tracked name carries it
join(INV[6].name:match("^(%S+)"))
assert(state(INV[2].name).st == "D", "abgelehnt")
assert(state(INV[3].name).st == "G", "schon in Gruppe")
assert(state(INV[4].name).st == "U", "unbekannt")
assert(state(INV[5].name).st == "R", "im Raid")
assert(state(INV[6].name).st == "R", "im Raid by the first name")
-- a secret message is skipped
local secret = ERR_DECLINE_GROUP_S:format(INV[7].name)
STUB.secret[secret] = true
STUB.fire("CHAT_MSG_SYSTEM", secret)
assert(state(INV[7].name).st == "I", "a secret message changes nothing")
STUB.secret[secret] = nil
-- in the lockdown the roster's names are secret: the statuses stay as they are
local keep = STUB.roster
STUB.chatLock, STUB.roster = true, {}
STUB.fire("GROUP_ROSTER_UPDATE")
assert(state(INV[1].name).st == "R", "no roster reading in the lockdown")
STUB.chatLock, STUB.roster = false, keep
STUB.fire("GROUP_ROSTER_UPDATE")
-- no answer in 90 s
STUB.tick(91)
assert(state(INV[7].name).st == "N" and state(INV[8].name).st == "N", "keine Antwort")
c = NS.LineupInviteCounts(night)
assert(c.again == 4 and c.todo == 0, ("again %d todo %d"):format(c.again, c.todo))

---------------------------------------------------------------------------
-- "Nochmal einladen": per click, three invites per name and night
---------------------------------------------------------------------------
local before = #INV
n = NS.LineupInvite(night, "again")
assert(n == 4, n)
STUB.tick(3)
assert(#INV == before + 4, "four again")
assert(state(INV[2].name).tries == 2)
-- nothing repeats by itself: declined again, they stay declined
for i = before + 1, #INV do sys("ERR_DECLINE_GROUP_S", INV[i].name) end
STUB.tick(200)
assert(#INV == before + 4, "no invite without a click")
assert(NS.LineupInvite(night, "again") == 4)
STUB.tick(3)
for i = before + 5, #INV do sys("ERR_DECLINE_GROUP_S", INV[i].name) end
assert(state(INV[2].name).tries == 3)
n, why = NS.LineupInvite(night, "again")
assert(n == nil and why == "Niemand einzuladen", "three invites per name and night: " .. tostring(why))
n, why = NS.LineupInviteOne(night, INV[2].name)
assert(n == nil and has(why, "Höchstens 3 Einladungen"), tostring(why))
assert(#INV == before + 8)

---------------------------------------------------------------------------
-- a /reload: the statuses come back from the roster
---------------------------------------------------------------------------
IV._reset()
assert(state(INV[1].name).st == "R" and state(INV[5].name).st == "R", "in the raid")
assert(state(INV[2].name).st == "P" and state(INV[2].name).tries == 0, "geplant again (the count is in memory only)")

---------------------------------------------------------------------------
-- a fight stops a run; ERR_GROUP_FULL; the whisper; guests
---------------------------------------------------------------------------
IV._reset()
alone()
INV = {}
NS.LineupInviteAll(night)
STUB.tick(0.6)
assert(#INV == 2, #INV)
STUB.messages = {}
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
assert(said("Einladen angehalten: Nicht im Kampf."), STUB.messages[1])
STUB.tick(5)
assert(#INV == 2, "no invite in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(1)
assert(#INV == 2, "no invite after the fight without a click")
-- the server: the group is full: the newest invite goes back to geplant, not counted
NS.LineupInviteAll(night)
STUB.tick(0.1)
local last = INV[#INV].name
STUB.fire("CHAT_MSG_SYSTEM", ERR_GROUP_FULL)
assert(state(last).st == "P" and state(last).tries == 0, "back to geplant")
STUB.tick(5)

-- the whisper: off by default; on: the fixed text once per name and night
IV._reset()
alone()
STUB.chat = {}
NS.LineupInviteOne(night, "Anna Bergmann")
STUB.tick(1)
assert(#STUB.chat == 0, "no whisper by default")
NS.Set("lineup.whisper", true)
IV._reset()
NS.LineupInviteOne(night, "Anna Bergmann")
STUB.tick(1)
local g
for _, e in ipairs(NS.LineupNight(night).list) do if e.n == "Anna Bergmann" then g = e.g end end
assert(#STUB.chat == 1 and STUB.chat[1].chan == "WHISPER" and STUB.chat[1].target == "Anna Bergmann", "one whisper")
assert(STUB.chat[1].text == ("Amisia: Einladung zum Raid (Gruppe %d). Bitte annehmen."):format(g), STUB.chat[1].text)
sys("ERR_DECLINE_GROUP_S", "Anna Bergmann")
NS.LineupInviteOne(night, "Anna Bergmann")
STUB.tick(1)
assert(#STUB.chat == 1, "the whisper once per name and night")
NS.Set("lineup.whisper", false)

-- guests: not placed and not invited without the setting; with it, placed and invited
IV._reset()
alone()
INV = {}
local gi
for i, e in ipairs(NS.LineupNight(night).list) do if e.n == "Gustav Gast" then gi = i end end
assert(NS.LineupNight(night).list[gi].x == "g" and not NS.LineupNight(night).list[gi].g, "the guest waits")
assert(not NS.LineupMove(night, gi, 2), "a guest is not placed without the setting")
NS.Set("lineup.guests", true)
assert(NS.LineupMove(night, gi, 2) or NS.LineupMove(night, gi, 3) or NS.LineupMove(night, gi, 4))
NS.Set("lineup.guests", false)
assert(NS.LineupInviteOne(night, "Gustav Gast") == nil, "the guest stays out without the setting")
NS.LineupInviteAll(night)
STUB.tick(3)
for _, x in ipairs(INV) do assert(x.name ~= "Gustav Gast", "no guest without the setting") end
-- (the run above waits for a join with four invites out: a new one starts after a reset)
IV._reset()
alone()
NS.Set("lineup.guests", true)
assert(NS.LineupInviteOne(night, "Gustav Gast") == 1)
STUB.tick(5)
assert(INV[#INV].name == "Gustav Gast", "the guest with the setting")
NS.Set("lineup.guests", false)

---------------------------------------------------------------------------
-- the page: the invite view, the reason on the button
---------------------------------------------------------------------------
IV._reset()
alone()
NS.ShowLineup("invite", night)
local f = NS.LineupPageFrame()
assert(f.inv:IsShown() and f.inviteAll:IsShown() and f.again:IsShown() and not f.sortBtn:IsShown())
assert(has(f.inviteAll:GetText(), "Alle einladen ("), f.inviteAll:GetText())
assert(has(f.calLine:GetText(), "noch einzuladen"), f.calLine:GetText())
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
STUB.tick(0.1)
assert(f.inviteAll:GetText() == "Nicht im Kampf" and not f.inviteAll:IsEnabled(), f.inviteAll:GetText())
local before2 = #INV
f.inviteAll:Click()
assert(#INV == before2, "nothing happens in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(0.1)
assert(f.inviteAll:IsEnabled(), "after the fight")
local row
for _, r in ipairs(f.invRows.rows) do
    if r:IsShown() and r.item and r.item.e and r.item.e.n == "Kim Sturmwind" then row = r end
end
assert(row and has(row.st:GetText(), "offline") and not row.chip:IsShown(), "offline: no chip")
NS.ShowLineup("planner", night)
assert(f.sortBtn:IsShown() and not f.inviteAll:IsShown())
assert(not f.sortBtn:IsEnabled() and has(f.calLine:GetText(), "Sortieren: Nur im Raid"), "sorting needs a raid: " .. f.calLine:GetText())
NS.ShowLineup("match", night)
