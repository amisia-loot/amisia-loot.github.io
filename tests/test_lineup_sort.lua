-- Sorting the raid into the planned groups (Raid/LineupSort.lua, F-084, D-41) and the automatic
-- assistant for officers: only in a raid as leader or assistant, out of combat; a free place takes a
-- SetRaidSubgroup, a full group a swap with a listed raider who belongs elsewhere; raiders not on the
-- list stay; one step per roster update; a fight stops it and "Sortieren fortsetzen" goes on; a client
-- that does not move stops it; the automatic sort only after this client's "Alle einladen"; the
-- assistant only for officers of the own guild by the roster, once per raid, only as leader, not in
-- combat.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local SO = NS.LineupSortState

_G.ERR_JOINED_GROUP_S = "%s schließt sich der Gruppe an."
_G.ERR_RAID_MEMBER_ADDED_S = "%s hat sich der Schlachtgruppe angeschlossen."
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Olga Offizier", rank = 2, class = "MAGE" },
}
local planned = { "Anna Eins", "Bert Zwei", "Cora Drei", "Dino Vier", "Eva Fuenf", "Finn Sechs", "Zeno Sieben", "Wim Acht" }
for _, n in ipairs(planned) do STUB.guild[#STUB.guild + 1] = { name = n, rank = 3, class = "WARRIOR" } end
STUB.guild[#STUB.guild + 1] = { name = "Xaver Gast", rank = 4, class = "ROGUE" }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")

local GRP = { raid = true, ignore = false }
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
    return m.name, m.rank or 0, m.sub or 1, 60, "WARRIOR", "WARRIOR", "Shattrath", true
end
_G.UnitIsGroupLeader = function() return STUB.leader end
_G.UnitIsGroupAssistant = function() return STUB.assist == true end
local SET, SWAP = {}, {}
_G.SetRaidSubgroup = function(i, g)
    SET[#SET + 1] = { i, g }
    if GRP.ignore then return end
    C_Timer.After(0.2, function()
        STUB.roster[i].sub = g
        STUB.fire("GROUP_ROSTER_UPDATE")
    end)
end
_G.SwapRaidSubgroup = function(i, j)
    SWAP[#SWAP + 1] = { i, j }
    C_Timer.After(0.2, function()
        STUB.roster[i].sub, STUB.roster[j].sub = STUB.roster[j].sub, STUB.roster[i].sub
        STUB.fire("GROUP_ROSTER_UPDATE")
    end)
end
local PROMOTED = {}
C_PartyInfo.PromoteToAssistant = function(name, exact)
    assert(exact == true, "the exact name")
    PROMOTED[#PROMOTED + 1] = name
end
C_PartyInfo.InviteUnit = function() end

-- the lineup: groups set by the planner
local lines = {}
for _, n in ipairs(planned) do lines[#lines + 1] = n .. " Nahkampf" end
lines[#lines + 1] = "Vuloo Heiler"
local night = NS.SetLineupText(table.concat(lines, "\n"))
local PLAN = { ["Vuloo"] = 1, ["Anna Eins"] = 2, ["Bert Zwei"] = 2, ["Cora Drei"] = 1, ["Dino Vier"] = 1,
               ["Eva Fuenf"] = 1, ["Finn Sechs"] = 2, ["Zeno Sieben"] = 1, ["Wim Acht"] = 3 }
for _, e in ipairs(NS.LineupNight(night).list) do e.g = PLAN[e.n] end

local function raid(list)
    STUB.roster = {}
    for _, x in ipairs(list) do STUB.roster[#STUB.roster + 1] = { name = x[1], sub = x[2], rank = x[3] } end
    STUB.fire("GROUP_ROSTER_UPDATE")
end
local function subOf(name)
    for _, m in ipairs(STUB.roster) do if m.name == name then return m.sub end end
end
STUB.leader = true

---------------------------------------------------------------------------
-- who may
---------------------------------------------------------------------------
GRP.raid = false
raid({ { "Vuloo", 1, 2 }, { "Anna Eins", 1 } })
local ok, why = NS.LineupSort(night)
assert(ok == nil and why == "Nur im Raid", tostring(why))
GRP.raid = true
STUB.leader = false
ok, why = NS.LineupSort(night)
assert(ok == nil and why == "Nur als Leiter oder Assistent", tostring(why))
STUB.assist = true
assert(NS.LineupLeadBlocked(true) == nil, "an assistant may sort")
STUB.assist, STUB.leader = false, true
STUB.combat = true
assert(select(2, NS.LineupSort(night)) == "Nicht im Kampf")
STUB.combat = false
assert(#SET == 0 and #SWAP == 0)

---------------------------------------------------------------------------
-- sorting: free places first, a full group by a swap; the unlisted stay
---------------------------------------------------------------------------
-- group 1 full (Vuloo, Anna, Bert, Cora, Xaver unlisted), group 2: Dino, Eva, Finn, Zeno, Gisela unlisted
raid({ { "Vuloo", 1, 2 }, { "Anna Eins", 1 }, { "Bert Zwei", 1 }, { "Cora Drei", 1 }, { "Xaver Gast", 1 },
       { "Dino Vier", 2 }, { "Eva Fuenf", 2 }, { "Finn Sechs", 2 }, { "Zeno Sieben", 2 }, { "Gisela Fremd", 2 } })
local rows, unlisted = NS.LineupSortPlan(night)
assert(#unlisted == 2, "two raiders not on the list")
assert(NS.LineupSortWrong(night) == 5, NS.LineupSortWrong(night))
STUB.messages = {}
assert(NS.LineupSort(night) == true)
STUB.tick(20)
for name, g in pairs(PLAN) do
    if subOf(name) then
        if name == "Cora Drei" or name == "Vuloo" then
            assert(subOf(name) == g, name)
        end
    end
end
assert(subOf("Anna Eins") == 2 and subOf("Bert Zwei") == 2 and subOf("Finn Sechs") == 2, "group 2 as planned")
assert(subOf("Dino Vier") == 1 and subOf("Eva Fuenf") == 1, "group 1 as planned")
assert(subOf("Xaver Gast") == 1 and subOf("Gisela Fremd") == 2, "the unlisted stay where they are")
assert(#SWAP >= 2, "full groups: swaps")
-- Zeno belongs in group 1, which holds Vuloo, Cora, Dino, Eva and Xaver (unlisted): no place, no swap
assert(subOf("Zeno Sieben") == 2, "Zeno cannot move")
assert(said("Gruppen sortiert:") and said("1 nicht verschoben (Zielgruppe voll)."), STUB.messages[#STUB.messages])
-- once sorted: nothing to do
ok, why = NS.LineupSort(night)
assert(ok == nil and why == "1 nicht verschoben (Zielgruppe voll).", "Zeno is still wrong, but nothing can move: " .. tostring(why))
STUB.tick(5)

---------------------------------------------------------------------------
-- a fight stops it; "Sortieren fortsetzen"
---------------------------------------------------------------------------
raid({ { "Vuloo", 1, 2 }, { "Anna Eins", 1 }, { "Bert Zwei", 1 }, { "Cora Drei", 3 }, { "Dino Vier", 3 } })
SET = {}
STUB.messages = {}
assert(NS.LineupSort(night) == true)
STUB.tick(0.05)
assert(#SET == 1, "the first step")
STUB.combat = true
STUB.fire("PLAYER_REGEN_DISABLED")
assert(said("Sortieren nach dem Kampf fortsetzen."))
assert(NS.LineupSortPaused(night))
STUB.tick(10)
assert(#SET == 1, "nothing in combat")
NS.ShowLineup("planner", night)
local f = NS.LineupPageFrame()
assert(not f.sortBtn:IsEnabled(), "the button waits for the end of the fight")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(0.1)
NS.Refresh()
assert(f.sortBtn:GetText() == "Sortieren fortsetzen" and f.sortBtn:IsEnabled(), f.sortBtn:GetText())
f.sortBtn:Click()
STUB.tick(20)
assert(subOf("Anna Eins") == 2 and subOf("Bert Zwei") == 2 and subOf("Cora Drei") == 1 and subOf("Dino Vier") == 1)
assert(not NS.LineupSortPaused(night))
assert(f.sortBtn:GetText() == "Gruppen sortieren")

-- a client that does not move: the sort stops
raid({ { "Vuloo", 1, 2 }, { "Anna Eins", 1 } })
GRP.ignore = true
STUB.messages = {}
SET = {}
NS.LineupSort(night)
STUB.tick(20)
assert(said("Sortieren angehalten: das Spiel hat Anna Eins nicht verschoben."), STUB.messages[1])
assert(#SET <= 3, "a few tries, then it stops")
GRP.ignore = false

---------------------------------------------------------------------------
-- the automatic sort: only after this client's "Alle einladen", with the setting
---------------------------------------------------------------------------
raid({ { "Vuloo", 1, 2 }, { "Anna Eins", 1 } })
SET = {}
-- a join without "Alle einladen": no sort
STUB.roster[#STUB.roster + 1] = { name = "Wim Acht", sub = 1 }
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
assert(#SET == 0, "no automatic sort without the own invite run")
raid({ { "Vuloo", 1, 2 }, { "Anna Eins", 1 } })
assert(NS.LineupInviteAll(night), "the invite run starts")
STUB.tick(10)
STUB.roster[#STUB.roster + 1] = { name = "Wim Acht", sub = 1 }
STUB.fire("CHAT_MSG_SYSTEM", ERR_RAID_MEMBER_ADDED_S:format("Wim Acht"))
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(1)
assert(#SET == 0, "two seconds of quiet first")
STUB.tick(10)
assert(subOf("Wim Acht") == 3 and subOf("Anna Eins") == 2, "sorted by itself")
-- the setting off: no more
NS.Set("lineup.autoSort", false)
STUB.roster[2].sub = 1
STUB.roster[#STUB.roster + 1] = { name = "Bert Zwei", sub = 1 }
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(10)
assert(subOf("Anna Eins") == 1 and subOf("Bert Zwei") == 1, "no automatic sort with the setting off")
NS.Set("lineup.autoSort", true)
-- the invite view open (review 2026-10-13): its refresh reads the roster between the join and the
-- roster event; the join still counts and sorts
raid({ { "Vuloo", 1, 2 }, { "Anna Eins", 2 } })
STUB.tick(5)
NS.ShowLineup("invite", night)
STUB.roster[#STUB.roster + 1] = { name = "Cora Drei", sub = 3 }
STUB.fire("CHAT_MSG_SYSTEM", ERR_RAID_MEMBER_ADDED_S:format("Cora Drei"))
NS.Refresh()
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(10)
assert(subOf("Cora Drei") == 1, "a join the open invite view saw first still sorts: " .. tostring(subOf("Cora Drei")))

---------------------------------------------------------------------------
-- the automatic assistant
---------------------------------------------------------------------------
SO._reset()
raid({ { "Vuloo", 1, 2 }, { "Olga Offizier", 1 }, { "Anna Eins", 1 }, { "Fremdi Fern", 1 } })
STUB.tick(5)
assert(#PROMOTED == 0, "off by default")
NS.Set("lineup.autoAssist", true)
-- not the leader: nothing
STUB.leader = false
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
assert(#PROMOTED == 0, "only as the raid leader")
STUB.leader = true
-- in combat: it waits
STUB.combat = true
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
assert(#PROMOTED == 0, "not in combat")
STUB.combat = false
STUB.messages = {}
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(5)
assert(#PROMOTED == 1 and PROMOTED[1] == "Olga Offizier", "the officer only: " .. table.concat(PROMOTED, ","))
assert(said("Assistent: Olga Offizier (Offiziersrang)."))
-- once per raid
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
assert(#PROMOTED == 1, "once")
-- the lockdown: nothing
SO._reset()
STUB.chatLock = true
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
assert(#PROMOTED == 1, "not in the lockdown")
STUB.chatLock = false
-- a new raid: again
GRP.raid = false
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
GRP.raid = true
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
assert(#PROMOTED == 2, "a new raid, once more")
-- an officer view without the rank: nothing
SO._reset()
NS.Set("ui.view", "raider")
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(5)
assert(#PROMOTED == 2, "only the officer view")
NS.Set("ui.view", "officer")
-- a first name is no proof (review 2026-10-13): the guild's officer "Ida" has no surname; "Ida Fremd"
-- in the raid is somebody else and stays without assistant; "Olga" in the raid (no surname) neither
STUB.guild[#STUB.guild + 1] = { name = "Ida", rank = 2, class = "MAGE" }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
SO._reset()
PROMOTED = {}
raid({ { "Vuloo", 1, 2 }, { "Ida Fremd", 1 }, { "Olga", 1 } })
STUB.tick(5)
assert(#PROMOTED == 0, "a first name alone promotes nobody: " .. table.concat(PROMOTED, ","))
raid({ { "Vuloo", 1, 2 }, { "Ida", 1 }, { "olga offizier", 1 } })
STUB.tick(5)
table.sort(PROMOTED)
assert(#PROMOTED == 2 and PROMOTED[1] == "Ida" and PROMOTED[2] == "olga offizier", table.concat(PROMOTED, ","))
NS.Set("lineup.autoAssist", false)
