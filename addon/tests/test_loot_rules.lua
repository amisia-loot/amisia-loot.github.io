-- Loot rules (Raid/LootRules.lua, D-37): matching by quality, material list, item list and item ->
-- player, the first rule wins; the safety exclusions (soft-reserve in the raid, loot prio, guild
-- wish, upgrade answer, roll round, legendary, points raid for player rules); pause; dry run gives
-- nothing; only the master looter under master loot; a missing candidate; the lockdown queue and
-- retry; one hand-out per slot; awards with the note "Regel"; one raid chat line only from the loot
-- lead; the automatic and the one-click mode.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local function ruleLines()
    local out = {}
    for _, c in ipairs(STUB.chat) do if has(c.text, "Amisia-Regeln") then out[#out + 1] = c end end
    return out
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Banki", class = "MAGE" }, { name = "Zaubi", class = "MAGE" } }
STUB.playerRaidIndex = 1
STUB.guild = { { name = "Vuloo", rank = 1 }, { name = "Fraktur", rank = 3 }, { name = "Banki", rank = 4 }, { name = "Zaubi", rank = 4 } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording runs")
STUB.lootMethod, STUB.mlRaidID = 2, 1
assert(NS.SelfIsOfficer(), "the player has an officer rank")

-- every hand-out is noted (the Awards.lua hook stays under it)
local gives = {}
local hooked = GiveMasterLoot
GiveMasterLoot = function(slot, i) gives[#gives + 1] = { slot = slot, i = i }; return hooked(slot, i) end

local GREEN = STUB.item(70001, "Grüner Gürtel", 2)
local BLUE = STUB.item(70002, "Blauer Ring", 3)
local BLUE_SR = STUB.item(70003, "Blaues Amulett", 3)
local BLUE_WISH = STUB.item(70004, "Blauer Umhang", 3)
local BLUE_PRIO = STUB.item(70005, "Blaue Stiefel", 3)
local BLUE_NEED = STUB.item(70006, "Blaue Hose", 3)
local EPIC = STUB.item(70007, "Episches Schwert", 4)
local QUEST = STUB.item(70008, "Kopf des Bosses", 4)
local LEGEND = STUB.item(70009, "Legendäre Klinge", 5)
local MAT = STUB.item(61001, "Feuerkern", 3)
local GREY = STUB.item(70010, "Grauer Schrott", 0)
NS.MATS[61001], NS.MAT_ORDER[1] = "Feuerkern", 61001

local n = 0
local function corpse(links)
    n = n + 1
    STUB.loot = {}
    for i, l in ipairs(links) do STUB.loot[i] = { link = l, name = "x", src = "Creature-0-1-1-1-2291" .. n .. "-1" } end
end
local function open() STUB.fire("LOOT_CLOSED"); STUB.chat, STUB.messages, gives = {}, {}, {}; STUB.fire("LOOT_OPENED", false) end
local function clear(slot) STUB.fire("LOOT_SLOT_CLEARED", slot) end

---------------------------------------------------------------------------
-- a fresh install has no rules and does nothing
---------------------------------------------------------------------------
assert(#NS.LootRules().list == 0, "no rules by default")
assert(NS.Get("lootrules.mode") == "auto" and NS.Get("lootrules.paused") == false and NS.Get("lootrules.chat") == true)
corpse({ GREEN, BLUE, MAT })
open(); STUB.tick(3)
assert(#gives == 0 and not said("Lootregeln aktiv"), "no rules, nothing given, nothing said")

---------------------------------------------------------------------------
-- the rules
---------------------------------------------------------------------------
local r1 = assert(NS.AddLootRule({ k = "m", to = "bank" }))
local r2 = assert(NS.AddLootRule({ k = "q", q = 3, to = "de" }))
local r3 = assert(NS.AddLootRule({ k = "p", items = EPIC, to = "Fraktur" }))
local r4 = assert(NS.AddLootRule({ k = "i", items = "70010 " .. QUEST, to = "bank" }))
assert(r1.by == "Vuloo" and r4.items[1] == 70010 and r4.items[2] == 70008, "the list takes links and ids")
assert(NS.LootRuleLabel(r2) == "Qualität bis Selten -> Entzaubern", NS.LootRuleLabel(r2))
assert(NS.LootRuleLabel(r3) == "Episches Schwert -> Fraktur", NS.LootRuleLabel(r3))
-- the names of the bank and the disenchanter are missing: the rule says so
assert(has(NS.LootRuleProblem(r2), "Entzauberer fehlt"), tostring(NS.LootRuleProblem(r2)))
assert(has(NS.LootRuleProblem(r1), "Bank-Charakter fehlt"))
assert(NS.LootRuleProblem(r3) == nil, "a player rule needs no setting")
NS.Set("awards.bankName", "Banki"); NS.Set("awards.deName", "Zaubi")
assert(NS.LootRuleProblem(r2) == nil)
-- bad rules are refused
assert(NS.AddLootRule({ k = "p", items = "70007 70002", to = "Fraktur" }) == nil, "a player rule is for one item")
assert(NS.AddLootRule({ k = "p", items = "70007", to = "bank" }) == nil, "a player rule names a player")
assert(NS.AddLootRule({ k = "q", q = 4, to = "de" }) == nil, "no whole epic quality")
assert(NS.AddLootRule({ k = "q", q = 3, to = "Fraktur" }) == nil, "a quality goes only to the bank or the disenchanter")
assert(NS.AddLootRule({ k = "i", items = "", to = "bank" }) == nil)
assert(NS.AddLootRule({ k = "x", to = "bank" }) == nil)
assert(#NS.LootRules().list == 4)
-- moving: the first fitting rule wins (the material is blue: rule 1 before rule 2)
assert(NS.MoveLootRule(r2.id, -1) == true and NS.LootRules().list[1].id == r2.id)
assert(NS.MoveLootRule(r2.id, -1) == false, "already first")
NS.MoveLootRule(r1.id, -1)
assert(NS.LootRules().list[1].id == r1.id)

---------------------------------------------------------------------------
-- matching through the plan
---------------------------------------------------------------------------
STUB.lootThreshold = 1
corpse({ GREEN, BLUE, MAT, EPIC, GREY, QUEST, LEGEND })
STUB.fire("LOOT_CLOSED"); STUB.messages = {}; STUB.fire("LOOT_OPENED", false)
assert(said("Lootregeln aktiv: 4 (Pause: /amisia regeln pause)"), "told once at the first loot of the raid")
local plan = NS.LootRulesPlan()
local by = {}
for _, e in ipairs(plan) do by[e.id] = e end
assert(by[70001].rule.id == r2.id and by[70001].name == "Zaubi", "green -> disenchant")
assert(by[70002].rule.id == r2.id, "blue -> disenchant")
assert(by[61001].rule.id == r1.id and by[61001].name == "Banki", "the material: first rule wins")
assert(by[70007].rule.id == r3.id and by[70007].name == "Fraktur", "item -> player")
assert(by[70008].rule.id == r4.id, "item list")
assert(by[70010] == nil, "below the loot threshold: anyone loots it")
assert(by[70009].name == nil and by[70009].why == "legendär", "never a legendary item")
STUB.fire("LOOT_CLOSED")
STUB.lootThreshold = nil

---------------------------------------------------------------------------
-- automatic: one second after the corpse opens
---------------------------------------------------------------------------
corpse({ GREEN, MAT, EPIC })
open()
assert(not said("Lootregeln aktiv"), "told only once per raid")
assert(#gives == 0, "nothing before the second")
STUB.tick(1.1)
assert(#gives == 3, "three hand-outs: " .. #gives)
assert(gives[1].slot == 1 and gives[1].i == 4 and gives[2].slot == 2 and gives[2].i == 3 and gives[3].slot == 3 and gives[3].i == 2)
-- the same slot is never given twice in one loot window, not even on a click
NS.LootRulesRun(true)
assert(#gives == 3, "no second hand-out of a slot")
clear(1); clear(2); clear(3)
local function award(item)
    for _, a in ipairs(s.awards) do if a.item == item then return a end end
end
local a1, a2, a3 = award(70001), award(61001), award(70007)
assert(a1 and a1.to == "de" and a1.name == "Zaubi" and has(a1.note, "Regel: Qualität bis Selten"), "disenchant award with the note")
assert(a2 and a2.to == "bank" and has(a2.note, "Regel: Raidmaterialien"), tostring(a2 and a2.note))
assert(a3 and a3.to == "player" and a3.name == "Fraktur" and a3.kind == "-" and has(a3.note, "Regel:"), "player award")
local lines = ruleLines()
assert(#lines == 1 and lines[1].chan == "RAID", "one raid chat line")
assert(has(lines[1].text, "Amisia-Regeln: " .. GREEN .. " zum Entzaubern (Zaubi), " .. MAT .. " an die Bank (Banki), " .. EPIC .. " an Fraktur."), lines[1].text)
-- the bar shows what was given, without a button
local bar = NS.LootRulesBar()
assert(bar and bar:IsShown() and has(bar.text:GetText(), "Verteilt: 1 an die Bank, 1 zum Entzaubern, 1 an Fraktur"), bar and bar.text:GetText())
assert(not bar.give:IsShown(), "no button in automatic mode")
-- the same corpse again (an item that could not leave stays in it): the rules do not run twice
STUB.fire("LOOT_CLOSED"); STUB.chat, gives = {}, {}
STUB.loot = { STUB.loot[2] }
STUB.fire("LOOT_OPENED", false); STUB.tick(2)
assert(#gives == 0 and #ruleLines() == 0, "once per corpse")
assert(not said("Lootregeln aktiv"), "told only once")
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- safety: reserved, loot prio, guild wish, upgrade answer, roll round
---------------------------------------------------------------------------
NS.SetSoftRes("Fraktur 70003\nGustav 70002\n")
NS.SetLootPrio("#AMISIA-LC 1 forever 2026-10-07\nC 70005 1788000000 p:Fraktur,o\n#END")
assert(NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-09\nW 70004 3 Fraktur\n#END"))
assert(#NS.WishersOf(70004, true) == 1, "Fraktur wishes the cloak")
local needOf = NS.NeedOf
NS.NeedOf = function(id)
    if id == 70006 then return { up = { { name = "Fraktur", gain = 5, pct = 3 } }, wish = {}, none = 0, missing = 0, at = time() } end
    return needOf(id)
end
corpse({ BLUE, BLUE_SR, BLUE_WISH, BLUE_PRIO, BLUE_NEED })
open(); STUB.tick(1.5)
assert(#gives == 1 and gives[1].slot == 1, "only the blue ring (reserved by someone outside the raid) goes: " .. #gives)
plan = NS.LootRulesPlan()
assert(plan[2].why == "reserviert" and plan[3].why == "Gildenwunsch" and plan[4].why == "Loot-Prio" and plan[5].why == "Upgrade oder Wunsch gemeldet",
    table.concat({ tostring(plan[2].why), tostring(plan[3].why), tostring(plan[4].why), tostring(plan[5].why) }, "/"))
NS.NeedOf = needOf
-- a roll round on an item: no rule touches it
local BLUE2 = STUB.item(70011, "Blaue Handschuhe", 3)
NS.StartRoll(BLUE2, 5)
corpse({ BLUE2 })
open(); STUB.tick(1.5)
assert(#gives == 0 and NS.LootRulesPlan()[1].why == "Roll-Runde", "roll round")
NS.StopRoll()
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- dry run: says, gives nothing (also without master loot)
---------------------------------------------------------------------------
local BLUE3 = STUB.item(70012, "Blauer Dolch", 3)
local EPIC2 = STUB.item(70013, "Epischer Helm", 4)
corpse({ BLUE3, BLUE_SR, EPIC2 })
STUB.lootMethod = 0
open(); STUB.tick(2)
assert(#gives == 0, "no master loot, no rule")
local out = NS.LootRulesProbe("")
assert(#gives == 0, "the dry run gives nothing")
assert(has(out[2], "Regel 2 (Qualität bis Selten -> Entzaubern) gibt es zum Entzaubern (Zaubi)"), out[2])
assert(has(out[3], "reserviert"), out[3])
assert(has(out[4], "keine Regel"), out[4])
assert(has(out[5], "Kein Master Loot"), tostring(out[5]))
assert(said("Probe der Lootregeln"), "in the own chat")
assert(#ruleLines() == 0, "nothing in the raid chat")
-- one item by its link
out = NS.LootRulesProbe(EPIC)
assert(has(out[2], "an Fraktur"), out[2])
STUB.fire("LOOT_CLOSED")
out = NS.LootRulesProbe("")
assert(#out == 0 and said("Kein Lootfenster offen"), "no loot window, no item")
STUB.lootMethod = 2

---------------------------------------------------------------------------
-- not the master looter, not in the officer view, paused
---------------------------------------------------------------------------
corpse({ BLUE3 })
STUB.mlRaidID = 2
open(); STUB.tick(2)
assert(#gives == 0, "another master looter: nothing")
STUB.mlRaidID = 1
NS.Set("ui.view", "raider")
open(); STUB.tick(2)
assert(#gives == 0, "raider view: nothing")
NS.Set("ui.view", "auto")
NS.Dispatch("regeln pause")
assert(NS.Get("lootrules.paused") == true and said("pausiert"))
open(); STUB.tick(2)
assert(#gives == 0 and not (NS.LootRulesBar() and NS.LootRulesBar():IsShown()), "paused: no bar, nothing given")
NS.Dispatch("regeln weiter")
assert(NS.Get("lootrules.paused") == false)
open(); STUB.tick(1.5)
assert(#gives == 1, "running again")
clear(1)

---------------------------------------------------------------------------
-- a target that is no candidate: the item stays, the chat says why
---------------------------------------------------------------------------
local BLUE4 = STUB.item(70014, "Blauer Stab", 3)
local GMC = GetMasterLootCandidate
GetMasterLootCandidate = function(slot, i) if i == 4 then return nil end return GMC(slot, i) end
corpse({ BLUE4 })
open(); STUB.tick(1.5)
assert(#gives == 0 and said("Zaubi ist kein Kandidat für " .. BLUE4 .. ". Das Item bleibt liegen."), "no candidate")
assert(#ruleLines() == 0, "no chat line for nothing given")
GetMasterLootCandidate = GMC
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- the lockdown: the run waits and comes after ADDON_RESTRICTION_STATE_CHANGED
---------------------------------------------------------------------------
local BLUE5 = STUB.item(70015, "Blaue Robe", 3)
corpse({ BLUE5 })
STUB.restricted = true
open(); STUB.tick(1.5)
assert(#gives == 0 and said("warten bis nach dem Kampf"), "held in the lockdown")
STUB.tick(5)
assert(#gives == 0, "still held")
STUB.restricted = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
STUB.tick(0.2)
assert(#gives == 1, "given after the lockdown")
clear(1)
-- in combat as well; closing the window drops the held run
local BLUE6 = STUB.item(70016, "Blaue Kappe", 3)
corpse({ BLUE6 })
STUB.combat = true
open(); STUB.tick(1.5)
assert(#gives == 0)
STUB.fire("LOOT_CLOSED")
STUB.combat = false
STUB.fire("PLAYER_REGEN_ENABLED"); STUB.tick(0.2)
assert(#gives == 0, "the window closed: nothing")
open(); STUB.tick(1.5)
assert(#gives == 1, "the next open after the fight gives it")
clear(1)

---------------------------------------------------------------------------
-- the chat line: only from the loot lead, and switchable
---------------------------------------------------------------------------
local isLead = NS.IsLootLead
NS.IsLootLead = function() return false end
local BLUE7 = STUB.item(70017, "Blaue Schulter", 3)
corpse({ BLUE7 })
open(); STUB.tick(1.5)
assert(#gives == 1 and #ruleLines() == 0, "not the loot lead: no chat line")
clear(1)
NS.IsLootLead = isLead
NS.Set("lootrules.chat", false)
local BLUE8 = STUB.item(70018, "Blaue Armschienen", 3)
corpse({ BLUE8 })
open(); STUB.tick(1.5)
assert(#gives == 1 and #ruleLines() == 0, "chat line off")
clear(1)
NS.Set("lootrules.chat", true)

---------------------------------------------------------------------------
-- a points raid: player rules rest, bank and disenchant go on
---------------------------------------------------------------------------
s.points = { sys = "dkp", cfg = {}, charges = {} }
local EPIC3 = STUB.item(70019, "Epischer Schild", 4)
NS.AddLootRule({ k = "p", items = EPIC3, to = "Fraktur" })
local BLUE9 = STUB.item(70020, "Blaue Gamaschen", 3)
corpse({ EPIC3, BLUE9 })
open(); STUB.tick(1.5)
assert(#gives == 1 and gives[1].slot == 2, "only the disenchant item in a points raid")
assert(has(NS.LootRulesPlan()[1].why, "Punkte-Raid"))
clear(2)
s.points = nil
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- one click: the bar with the button; nothing by itself
---------------------------------------------------------------------------
NS.Set("lootrules.mode", "click")
local BLUE10 = STUB.item(70021, "Blauer Gürtel", 3)
local MAT2 = STUB.item(61002, "Runenstoff", 2)
NS.MATS[61002] = "Runenstoff"
corpse({ BLUE10, MAT2 })
open(); STUB.tick(3)
assert(#gives == 0, "one click: nothing by itself")
bar = NS.LootRulesBar()
assert(bar:IsShown() and bar.text:GetText() == "2 Items nach Regeln verteilen" and bar.give:IsShown(), bar.text:GetText())
assert(bar.mode:GetText() == "1 an die Bank, 1 zum Entzaubern", bar.mode:GetText())
bar.give:Click()
assert(#gives == 2 and #ruleLines() == 1, "the click hands out")
clear(1); clear(2)
assert(has(award(70021).note, "Regel:") and has(award(61002).note, "Regel:"))
assert(not bar:IsShown(), "nothing left: the bar goes")
-- a second click finds nothing
NS.LootRulesRun(true)
assert(#gives == 2 and said("nichts zu verteilen"))
STUB.fire("LOOT_CLOSED")
-- the safety rules hold on a click as well
corpse({ BLUE_SR })
open()
assert(not (NS.LootRulesBar() and NS.LootRulesBar():IsShown()), "reserved only: no bar")
NS.LootRulesRun(true)
assert(#gives == 0, "a click does not touch a reserved item")
STUB.fire("LOOT_CLOSED")
NS.Set("lootrules.mode", "auto")

---------------------------------------------------------------------------
-- an item from a bag is no corpse; the saved rules are checked on load
---------------------------------------------------------------------------
corpse({ BLUE10 })
STUB.fire("LOOT_CLOSED"); gives = {}
STUB.fire("LOOT_OPENED", false, true); STUB.tick(2)
assert(#gives == 0, "loot from an item: nothing " .. #gives .. " " .. tostring(gives[1] and gives[1].slot))
STUB.fire("LOOT_CLOSED")

local root = { lootRules = { rev = 5, list = {
    { id = "ab12", k = "q", q = 3, to = "de" },
    { id = "ab12", k = "m", to = "bank" },            -- the same id twice
    { id = "zz", k = "m", to = "bank" },              -- no hex id
    { id = "cd34", k = "q", q = 5, to = "de" },       -- legendary quality
    { id = "ef56", k = "p", items = { 1, 2 }, to = "Anna" },
    { id = "ef57", k = "p", items = { 1 }, to = "de" },
    { id = "ef58", k = "i", items = { "x" }, to = "bank" },
    { id = "ef59", k = "p", items = { 7 }, to = "Anna Berg" },
}, offer = { from = "x|y", rev = 1 } } }
NS.LootRulesLoaded(root)
assert(#root.lootRules.list == 2 and root.lootRules.list[1].id == "ab12" and root.lootRules.list[2].to == "Anna Berg", #root.lootRules.list)
assert(root.lootRules.offer == nil, "a bad offer falls away")
NS.LootRulesLoaded(root)
assert(#root.lootRules.list == 2, "twice without change")
NS.LootRulesLoaded(AmisiaDB)

print("loot rules ok")
