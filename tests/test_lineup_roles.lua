-- F-165 (D-95): the view "Rollen" of the lineup (Raid/LineupRoles.lua). The lists cleaned (on input
-- and on load), names matched against the raid, only as raid leader in an own raid and out of
-- combat, only adding (nobody demoted, nothing cleared), the first listed master looter in the raid
-- with the threshold (not set again when he has it; the old clients' "master"), a refused main tank
-- call (ADDON_ACTION_FORBIDDEN / _BLOCKED) remembered for the session and said once, the automatic
-- run once per name and raid, the view with its fields, "Aus dem Planer" and the button's reasons.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function saidCount(part)
    local n = 0
    for _, m in ipairs(STUB.messages) do if has(m, part) then n = n + 1 end end
    return n
end
local RO = NS.LineupRoles
local REFUSED_T = "Haupttanks: Das Spiel lässt Addons das nicht setzen. Setze sie im Raidfenster von Hand."

STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Cora Wind-Tal", rank = 3, class = "MAGE" },
    { name = "Dino Fels", rank = 3, class = "WARRIOR" },
    { name = "Eva Neu", rank = 3, class = "PALADIN" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")

-- the client: the roster with the main tank role (10th value) and the loot master flag (11th)
_G.GetRaidRosterInfo = function(i)
    local m = STUB.roster[i]
    if not m then return nil end
    return m.name, m.rank or 0, m.sub or 1, 60, "WARRIOR", "WARRIOR", "Shattrath", true, false, m.role, m.ml
end
local CALLS = {}
local function calls(kind)
    local out = {}
    for _, c in ipairs(CALLS) do if c[1] == kind then out[#out + 1] = c end end
    return out
end
local TANK = {}            -- [raid index] = true: a main tank
C_PartyInfo.PromoteToAssistant = function(name, exact)
    assert(exact == true, "the exact name")
    CALLS[#CALLS + 1] = { "assist", name }
end
_G.GetPartyAssignment = function(kind, unit)
    assert(kind == "MAINTANK")
    return TANK[tonumber(unit:match("^raid(%d+)$"))] == true
end
local FORBID = false
_G.SetPartyAssignment = function(kind, unit)
    assert(kind == "MAINTANK")
    if FORBID == "now" then
        STUB.fire("ADDON_ACTION_FORBIDDEN", "Amisia", "SetPartyAssignment()")
        return
    elseif FORBID then
        return
    end
    CALLS[#CALLS + 1] = { "tank", unit }
    TANK[tonumber(unit:match("^raid(%d+)$"))] = true
end
local THRESHOLD = 2
_G.SetLootMethod = function(method, name)
    CALLS[#CALLS + 1] = { "ml", method, name }
end
_G.GetLootThreshold = function() return THRESHOLD end
_G.SetLootThreshold = function(q)
    CALLS[#CALLS + 1] = { "q", q }
    THRESHOLD = q
end
-- only adding: none of these may ever be called
_G.ClearPartyAssignment = function() error("ClearPartyAssignment called") end
_G.DemoteAssistant = function() error("DemoteAssistant called") end
C_PartyInfo.DemoteAssistant = function() error("DemoteAssistant called") end

local function raid(list)
    STUB.roster = {}
    for _, x in ipairs(list) do STUB.roster[#STUB.roster + 1] = { name = x[1], rank = x[2], role = x[3], ml = x[4] } end
    STUB.fire("GROUP_ROSTER_UPDATE")
end
local function indexOf(name)
    for i, m in ipairs(STUB.roster) do if m.name == name then return i end end
end
STUB.leader = true

---------------------------------------------------------------------------
-- the lists: cleaned on input
---------------------------------------------------------------------------
local list, dropped = RO.Parse(" Anna Bergmann,, bob eisherz , Bob Eisherz, X2, Cora Wind-Tal ")
assert(#list == 3 and list[1] == "Anna Bergmann" and list[2] == "bob eisherz" and list[3] == "Cora Wind-Tal", table.concat(list, "|"))
assert(dropped == 2, "a double and a name with a digit: " .. dropped)
local many = {}
for i = 1, 12 do many[i] = "Name " .. string.char(64 + i) end
list, dropped = RO.Parse(table.concat(many, ", "))
assert(#list == 10 and dropped == 2, "10 at most")
assert(RO.Get().q == 4 and RO.Get().tanks.on and RO.Get().assist.on and RO.Get().ml.on and not RO.Get().auto, "the defaults")
assert(AmisiaDB.lineup == nil or AmisiaDB.lineup.roles == nil, "nothing saved by reading")

-- and on load
AmisiaDB.lineup = { v = 1, nights = {}, roles = { tanks = { on = false, list = { "Bob Eisherz", "bob eisherz", 5, "X1", "Dino Fels" } },
    assist = "kaputt", ml = { list = { "Cora Wind-Tal" } }, q = 9, auto = "ja" } }
NS.LineupLoaded(AmisiaDB)
local r = AmisiaDB.lineup.roles
assert(r.tanks.on == false and #r.tanks.list == 2 and r.tanks.list[2] == "Dino Fels", "the tank list cleaned")
assert(r.assist.on == true and #r.assist.list == 0, "a broken list: empty, on")
assert(r.ml.on == true and r.ml.list[1] == "Cora Wind-Tal" and r.q == 4 and r.auto == false, "threshold and auto cleaned")
AmisiaDB.lineup.roles = "kaputt"
NS.LineupLoaded(AmisiaDB)
assert(AmisiaDB.lineup.roles == nil, "not a table: gone")

---------------------------------------------------------------------------
-- who may
---------------------------------------------------------------------------
RO.SetList("assist", "Anna Bergmann, Bob Eisherz, Kim Sturmwind")
RO.SetList("tanks", "Dino Fels, Cora")
RO.SetList("ml", "Kim Sturmwind, Cora Wind-Tal, Anna Bergmann")
assert(AmisiaDB.lineup.roles.assist.list[3] == "Kim Sturmwind", "saved")
local ok, why = NS.LineupRolesSet()
assert(not ok and why == "Nur im Raid", tostring(why))
raid({ { "Vuloo", 2 }, { "Anna Bergmann", 0 }, { "Bob Eisherz", 1 }, { "Cora Wind-Tal", 0 }, { "Dino Fels", 0 } })
STUB.tick(5)
assert(#CALLS == 0, "the automatic run is off by default")
STUB.leader = false
ok, why = NS.LineupRolesSet()
assert(not ok and why == "Nur als Raidleiter", tostring(why))
STUB.leader = true
STUB.combat = true
ok, why = NS.LineupRolesSet()
assert(not ok and why == "Nicht im Kampf", tostring(why))
STUB.combat = false
STUB.instanceGroup = true
ok, why = NS.LineupRolesSet()
assert(not ok and why == "Nur im Raid", "an instance group is not the own raid: " .. tostring(why))
STUB.instanceGroup = false
NS.Set("ui.view", "raider")
ok, why = NS.LineupRolesSet()
assert(not ok and why == "Nur für Offiziere", tostring(why))
NS.Set("ui.view", "officer")
assert(#CALLS == 0, "nothing called while blocked")

---------------------------------------------------------------------------
-- the run: only adding, the first master looter in the raid, the threshold
---------------------------------------------------------------------------
TANK[indexOf("Cora Wind-Tal")] = true
STUB.messages = {}
assert(NS.LineupRolesSet())
local a = calls("assist")
assert(#a == 1 and a[1][2] == "Anna Bergmann", "Anna promoted, Bob is one already")
local t = calls("tank")
assert(#t == 1 and t[1][2] == "raid" .. indexOf("Dino Fels"), "Dino set, Cora (first name alone) is one already")
local m = calls("ml")
assert(#m == 1 and m[1][2] == "master" and m[1][3] == "Cora Wind-Tal", "the first of the list in the raid")
local q = calls("q")
assert(#q == 1 and q[1][2] == 4, "epic by default")
assert(said("Rollen: Assistenten: 1 befördert, 1 schon Assistent, 1 nicht im Raid · Haupttanks: 1 gesetzt, 1 schon Haupttank · Plündermeister: Cora Wind-Tal, ab Episch (lila)."),
    tostring(STUB.messages[#STUB.messages]))

-- the master looter has it: not set again (the enum of new clients), the threshold only when it differs
CALLS = {}
STUB.roster[indexOf("Anna Bergmann")].rank = 1
STUB.lootMethod, STUB.mlRaidID = Enum.LootMethod.Masterlooter, indexOf("Cora Wind-Tal")
STUB.messages = {}
assert(NS.LineupRolesSet())
assert(#calls("ml") == 0 and #calls("q") == 0 and #calls("assist") == 0 and #calls("tank") == 0, "nothing again")
assert(said("Plündermeister: Cora Wind-Tal ist es schon, ab Episch (lila)"), tostring(STUB.messages[1]))
RO.SetQuality(3)
assert(RO.Get().q == 3)
NS.LineupRolesSet()
q = calls("q")
assert(#calls("ml") == 0 and #q == 1 and q[1][2] == 3, "only the threshold")
-- an old client: no C_PartyInfo.GetLootMethod, the word "master" and the raid index
CALLS = {}
local getLM = C_PartyInfo.GetLootMethod
C_PartyInfo.GetLootMethod = nil
_G.GetLootMethod = function() return "master", nil, indexOf("Cora Wind-Tal") end
NS.LineupRolesSet()
assert(#calls("ml") == 0, "the word master counts too")
-- another master looter: the wanted one gets it (adding: the method is set, nobody is taken off a list)
_G.GetLootMethod = function() return "master", nil, indexOf("Bob Eisherz") end
NS.LineupRolesSet()
m = calls("ml")
assert(#m == 1 and m[1][3] == "Cora Wind-Tal", "set to the wanted one")
_G.GetLootMethod = nil
C_PartyInfo.GetLootMethod = getLM
-- the new clients' call with the enum
CALLS = {}
STUB.lootMethod = 0
C_PartyInfo.SetLootMethod = function(method, name) CALLS[#CALLS + 1] = { "ml", method, name } end
NS.LineupRolesSet()
m = calls("ml")
assert(#m == 1 and m[1][2] == Enum.LootMethod.Masterlooter and m[1][3] == "Cora Wind-Tal", "C_PartyInfo.SetLootMethod with the enum")
C_PartyInfo.SetLootMethod = nil
-- nobody of the list in the raid
RO.SetList("ml", "Kim Sturmwind")
STUB.messages = {}
CALLS = {}
NS.LineupRolesSet()
assert(#calls("ml") == 0 and said("Plündermeister: niemand der Liste im Raid"), tostring(STUB.messages[1]))
-- a list switched off is left alone
RO.SetOn("ml", false)
RO.SetOn("assist", false)
STUB.messages = {}
NS.LineupRolesSet()
assert(not said("Plündermeister") and not said("Assistenten"), tostring(STUB.messages[1]))
RO.SetOn("tanks", false)
ok, why = NS.LineupRolesSet()
assert(not ok and why == "Keine Namen in den eingeschalteten Listen.", tostring(why))
RO.SetOn("tanks", true)
RO.SetOn("assist", true)
RO.SetOn("ml", true)
RO.SetList("ml", "Kim Sturmwind, Cora Wind-Tal, Anna Bergmann")
-- the client lacks the main tank function
local spa = _G.SetPartyAssignment
_G.SetPartyAssignment = nil
TANK = {}
STUB.messages = {}
NS.LineupRolesSet()
assert(said("Haupttanks: 2 nicht") == nil and said("das Spiel hat die Funktion nicht"), tostring(STUB.messages[1]))
_G.SetPartyAssignment = spa

---------------------------------------------------------------------------
-- the client refuses the main tanks
---------------------------------------------------------------------------
-- at once, during the call
FORBID = "now"
TANK = {}
CALLS = {}
STUB.messages = {}
NS.LineupRolesSet()
assert(RO.Refused("tanks"), "remembered")
assert(saidCount(REFUSED_T) == 1, "said once: " .. table.concat(STUB.messages, " / "))
assert(not said("Haupttanks: 1 gesetzt") and not said("vom Spiel abgelehnt"), "no count for a refused block")
assert(RO.Status("tanks") == REFUSED_T, "the view's grey line")
-- not tried again, not said again
FORBID = false
NS.LineupRolesSet()
assert(#calls("tank") == 0 and saidCount(REFUSED_T) == 1, "stopped for the session")
-- another addon's refusal counts for nothing
RO._reset()
STUB.fire("ADDON_ACTION_FORBIDDEN", "AnderesAddon", "SetPartyAssignment()")
assert(not RO.Refused("tanks"))
-- late, without the function's name, right after the tank step
FORBID = true
STUB.messages = {}
NS.LineupRolesSet()
STUB.tick(1)
STUB.fire("ADDON_ACTION_BLOCKED", "Amisia", nil)
assert(RO.Refused("tanks") and saidCount(REFUSED_T) == 1, "a late refusal after the tank step")
-- long after a step: no block to blame
RO._reset()
STUB.tick(10)
STUB.fire("ADDON_ACTION_BLOCKED", "Amisia", nil)
assert(not RO.Refused("tanks") and not RO.Refused("assist") and not RO.Refused("ml"), "nothing to blame")
FORBID = false

---------------------------------------------------------------------------
-- the automatic run: once per name and raid, quietly
---------------------------------------------------------------------------
RO._reset()
TANK = {}
RO.SetList("assist", "Anna Bergmann, Eva Neu")
RO.SetList("tanks", "Dino Fels")
RO.SetList("ml", "Cora Wind-Tal")
STUB.lootMethod, STUB.mlRaidID = Enum.LootMethod.Masterlooter, nil
raid({ { "Vuloo", 2 }, { "Anna Bergmann", 1 }, { "Bob Eisherz", 1 }, { "Cora Wind-Tal", 0, nil, true }, { "Dino Fels", 0, "MAINTANK" } })
_G.GetPartyAssignment = nil   -- the roster's role tells it
THRESHOLD = 4
RO.SetQuality(4)
RO.SetAuto(true)
CALLS = {}
STUB.messages = {}
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(1)
assert(#CALLS == 0, "2 seconds of quiet first")
STUB.tick(3)
assert(#CALLS == 0, "all have their roles: nothing called")
assert(#STUB.messages == 0, "and nothing said: " .. table.concat(STUB.messages, " / "))
-- Eva joins
STUB.roster[#STUB.roster + 1] = { name = "Eva Neu", rank = 0 }
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(3)
a = calls("assist")
assert(#a == 1 and a[1][2] == "Eva Neu", "the newcomer promoted")
assert(said("Rollen: Assistenten: 1 befördert."), table.concat(STUB.messages, " / "))
-- once per name and raid
STUB.roster[#STUB.roster].rank = 0
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(3)
assert(#calls("assist") == 1, "once")
-- a newcomer in combat waits for its end
STUB.combat = true
STUB.roster[#STUB.roster + 1] = { name = "Zora Spaet", rank = 0 }
RO.SetList("tanks", "Dino Fels, Zora Spaet")
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(3)
assert(#calls("tank") == 0, "not in combat")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED")
STUB.tick(3)
t = calls("tank")
assert(#t == 1 and t[1][2] == "raid" .. indexOf("Zora Spaet"), "after the fight")
-- the switch off: nothing
RO.SetAuto(false)
STUB.roster[#STUB.roster + 1] = { name = "Kim Sturmwind", rank = 0 }
RO.SetList("assist", "Kim Sturmwind")
STUB.fire("GROUP_ROSTER_UPDATE")
STUB.tick(3)
assert(#calls("assist") == 1, "off")
-- a new raid: again for everyone
RO.SetAuto(true)
raid({})
STUB.tick(3)
raid({ { "Vuloo", 2 }, { "Kim Sturmwind", 0 } })
STUB.tick(3)
a = calls("assist")
assert(#a == 2 and a[2][2] == "Kim Sturmwind", "a new raid")
RO.SetAuto(false)

---------------------------------------------------------------------------
-- the view
---------------------------------------------------------------------------
_G.GetPartyAssignment = function(kind, unit) return TANK[tonumber(unit:match("^raid(%d+)$"))] == true end
raid({ { "Vuloo", 2 }, { "Anna Bergmann", 0 }, { "Bob Eisherz", 1 }, { "Cora Wind-Tal", 0 }, { "Dino Fels", 0 } })
TANK = {}
STUB.tick(3)
NS.ShowLineup("roles")
local f = NS.PageFrame("lineup")
assert(f.roles:IsShown() and f.rolesLink:GetText() == "Zurück" and not f.views.match:IsShown(), "the view, opened from the head row")
assert(not f.cancel:IsShown(), "no Abbrechen beside the red button")
assert(f.rolesBtn:IsShown() and f.rolesBtn:IsEnabled() and f.rolesBtn:GetText() == "Rollen jetzt setzen", f.rolesBtn:GetText())
local B = f.roles.blocks
assert(B.assist.edit:GetText() == "Kim Sturmwind", B.assist.edit:GetText())
-- typing a list
B.assist.edit:SetText("anna bergmann, Anna Bergmann, Bob Eisherz")
B.assist.edit:GetScript("OnEnterPressed")(B.assist.edit)
assert(RO.Get().assist.list[1] == "anna bergmann" and #RO.Get().assist.list == 2, "saved from the field")
assert(said("Assistenten: 2 Namen, 1 weggelassen"), tostring(STUB.messages[#STUB.messages]))
assert(B.assist.edit:GetText() == "anna bergmann, Bob Eisherz", B.assist.edit:GetText())
assert(has(B.assist.status:GetText(), "2 Namen, 2 im Raid, 1 haben es schon."), B.assist.status:GetText())
-- the switch
B.ml.on:Click()
assert(RO.Get().ml.on == false and has(B.ml.status:GetText(), "Aus: wird nicht gesetzt."), B.ml.status:GetText())
B.ml.on:Click()
assert(RO.Get().ml.on and has(B.ml.status:GetText(), "Bekommt es: Cora Wind-Tal, ab Episch (lila)."), B.ml.status:GetText())
-- the threshold
B.ml.quality:SetValue(2)
assert(B.ml.quality:GetValue() == 2)
-- the automatic switch
f.roles.auto:Click()
assert(RO.Get().auto == true)
f.roles.auto:Click()
assert(RO.Get().auto == false)
-- "Aus dem Planer": tonight's tanks in a group, in group order
local night = NS.SetLineupText(table.concat({ "Dino Fels Tank", "Bob Eisherz Tank", "Cora Wind-Tal Tank", "Anna Bergmann Heiler" }, "\n"))
for _, e in ipairs(NS.LineupNight(night).list) do
    if e.n == "Dino Fels" then e.g = 2 elseif e.n == "Bob Eisherz" then e.g = 1 elseif e.n == "Anna Bergmann" then e.g = 1 end
end
NS.ShowLineup("roles", night)
STUB.messages = {}
B.tanks.planner:Click()
assert(RO.ListText("tanks") == "Bob Eisherz, Dino Fels", "group order, Cora without a group: " .. RO.ListText("tanks"))
assert(B.tanks.edit:GetText() == "Bob Eisherz, Dino Fels")
assert(said("Haupttanks aus dem Planer: Bob Eisherz, Dino Fels."))
NS.ShowLineup("roles", "2026-12-24")
B.tanks.planner:Click()
assert(said("Im Planer steht kein Tank in einer Gruppe."))
assert(RO.ListText("tanks") == "Bob Eisherz, Dino Fels", "kept")
NS.ShowLineup("roles", NS.LineupTonight())
-- the button sets
CALLS = {}
f.rolesBtn:Click()
assert(#calls("tank") == 2, "both tanks")
-- the reasons on the button
STUB.combat = true
NS.Refresh()
assert(f.rolesBtn:GetText() == "Nicht im Kampf" and not f.rolesBtn:IsEnabled(), f.rolesBtn:GetText())
STUB.combat = false
STUB.leader = false
NS.Refresh()
assert(f.rolesBtn:GetText() == "Nur als Raidleiter" and not f.rolesBtn:IsEnabled(), f.rolesBtn:GetText())
assert(has(f.calLine:GetText(), "Rollen: Nur als Raidleiter"), f.calLine:GetText())
STUB.leader = true
raid({})
NS.Refresh()
assert(f.rolesBtn:GetText() == "Nur im Raid" and not f.rolesBtn:IsEnabled(), f.rolesBtn:GetText())
assert(has(B.tanks.status:GetText(), "2 Namen; im Raid setzt Amisia sie."), B.tanks.status:GetText())
-- the refused block shows its line
RO._reset()
raid({ { "Vuloo", 2 }, { "Dino Fels", 0 } })
FORBID = "now"
TANK = {}
NS.ShowLineup("roles")
f.rolesBtn:Click()
assert(has(B.tanks.status:GetText(), REFUSED_T), B.tanks.status:GetText())
FORBID = false
-- "Zurück" leaves it
f.rolesLink:Click()
assert(not f.roles:IsShown() and not f.rolesBtn:IsShown() and f.views.match:IsShown() and f.rolesLink:GetText() == "Rollen")
print("lineup roles ok")
