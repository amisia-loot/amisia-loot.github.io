-- Loot rules after the review (D-37): a target name that fits two candidates gives nothing; a
-- reservation or guild wish by a first name shared in the raid (or while a member's name is secret)
-- keeps the item from the rules; a hand-out whose slot never clears is told and stays off the raid
-- chat line and the bar; the loot announcement leaves out what an item or player rule hands out by
-- itself, and a quality rule leaves what the announcement names.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local function chatHas(part)
    for _, c in ipairs(STUB.chat) do if has(c.text, part) then return true end end
    return false
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" },
                { name = "Banki", class = "MAGE" }, { name = "Zaubi", class = "MAGE" },
                { name = "Mira Sturmwind", class = "MAGE" }, { name = "Mira Eisherz", class = "ROGUE" } }
STUB.playerRaidIndex = 1
STUB.guild = { { name = "Vuloo", rank = 1 }, { name = "Fraktur", rank = 3 }, { name = "Banki", rank = 4 },
               { name = "Zaubi", rank = 4 }, { name = "Mira Sturmwind", rank = 4 }, { name = "Mira Eisherz", rank = 4 } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "recording runs")
STUB.lootMethod, STUB.mlRaidID = 2, 1
NS.Set("awards.bankName", "Banki"); NS.Set("awards.deName", "Zaubi")

local gives = {}
local hooked = GiveMasterLoot
GiveMasterLoot = function(slot, i) gives[#gives + 1] = { slot = slot, i = i }; return hooked(slot, i) end

local n = 0
local function corpse(links)
    n = n + 1
    STUB.loot = {}
    for i, l in ipairs(links) do STUB.loot[i] = { link = l, name = "x", src = "Creature-0-1-1-1-3391" .. n .. "-1" } end
end
local function open() STUB.fire("LOOT_CLOSED"); STUB.chat, STUB.messages, gives = {}, {}, {}; STUB.fire("LOOT_OPENED", false) end
local function clear(slot) STUB.fire("LOOT_SLOT_CLEARED", slot) end
local function award(item)
    for _, a in ipairs(s.awards) do if a.item == item then return a end end
end

local BLUE = STUB.item(71001, "Blauer Reif", 3)
local EPIC = STUB.item(71002, "Episches Horn", 4)
assert(NS.AddLootRule({ k = "q", q = 3, to = "de" }))
assert(NS.AddLootRule({ k = "p", items = EPIC, to = "Mira" }))

---------------------------------------------------------------------------
-- a target name that fits two candidates: nothing is given
---------------------------------------------------------------------------
corpse({ EPIC })
open(); STUB.tick(1.5)
assert(#gives == 0, "\"Mira\" is two raiders: no hand-out")
assert(said("Mira ist unter den Kandidaten für " .. EPIC .. " nicht eindeutig"), "the master looter is told")
assert(NS.LootRulesPlan()[1].why == "Name nicht eindeutig", tostring(NS.LootRulesPlan()[1].why))
-- candidates without surnames: two "Mira" fit "Mira Sturmwind" as well
local GMC = GetMasterLootCandidate
GetMasterLootCandidate = function(slot, i)
    local c = GMC(slot, i)
    return c and c:match("^(%S+)") or c
end
NS.LootRules().list[2].to = "Mira Sturmwind"
NS.lootRulesDone = NS.lootRulesDone or {}
for k in pairs(NS.lootRulesDone) do NS.lootRulesDone[k] = nil end
corpse({ EPIC })
open(); STUB.tick(1.5)
assert(#gives == 0, "two candidates named Mira: no hand-out")
GetMasterLootCandidate = GMC
-- one exact candidate: given to that one
corpse({ EPIC })
open(); STUB.tick(1.5)
assert(#gives == 1 and gives[1].i == 5, "Mira Sturmwind is candidate 5")
clear(1)
assert(award(71002) and award(71002).name == "Mira Sturmwind")
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- a reservation or wish by a first name two raiders share: the rules leave the item
---------------------------------------------------------------------------
local BLUE_SR = STUB.item(71003, "Blaues Siegel", 3)
local BLUE_WISH = STUB.item(71004, "Blaue Feder", 3)
NS.SetSoftRes("Mira 71003\n")
assert(NS.SetGuildWishes("#AMISIA-WL 1 forever 2026-10-09\nW 71004 3 Mira\n#END"))
corpse({ BLUE_SR, BLUE_WISH, BLUE })
open(); STUB.tick(1.5)
local plan = NS.LootRulesPlan()
assert(plan[1].why == "reserviert", tostring(plan[1].why))
assert(plan[2].why == "Gildenwunsch", tostring(plan[2].why))
assert(#gives == 1 and gives[1].slot == 3, "only the free blue item goes")
clear(3)
STUB.fire("LOOT_CLOSED")
-- a member's name is secret: a reservation by someone not readable in the raid holds as well
NS.SetSoftRes("Gustav 71005\n")
local BLUE_X = STUB.item(71005, "Blauer Knopf", 3)
STUB.secret["Zaubi"] = true
corpse({ BLUE_X })
STUB.fire("LOOT_CLOSED"); gives = {}
STUB.fire("LOOT_OPENED", false)
assert(NS.LootRulesPlan()[1].why == "reserviert", "a hidden name may be Gustav")
STUB.secret["Zaubi"] = nil
STUB.fire("LOOT_CLOSED")
NS.ClearSoftRes()

---------------------------------------------------------------------------
-- a hand-out whose slot never clears (bags full): told, no chat line, no award, not on the bar
---------------------------------------------------------------------------
local BLUE2 = STUB.item(71006, "Blauer Kragen", 3)
local BLUE3 = STUB.item(71007, "Blaue Spange", 3)
corpse({ BLUE2, BLUE3 })
open(); STUB.tick(1.1)
assert(#gives == 2, "two hand-outs")
assert(not chatHas("Amisia-Regeln"), "the chat line waits for the slots")
clear(1)
assert(not chatHas("Amisia-Regeln"), "one slot still open")
STUB.tick(3.5)
assert(said(BLUE3 .. " an Zaubi ist nicht bestätigt"), "the second is told")
assert(chatHas("Amisia-Regeln: " .. BLUE2 .. " zum Entzaubern (Zaubi).") and not chatHas(BLUE3), "the line names only what arrived")
assert(award(71006) and not award(71007), "no award for the hand-out that did not arrive")
local bar = NS.LootRulesBar()
assert(bar and has(bar.text:GetText(), "Verteilt: 1 zum Entzaubern"), bar and bar.text:GetText())
assert(NS.LootRulesPlan()[2].why == "nicht bestätigt", tostring(NS.LootRulesPlan()[2].why))
NS.LootRulesRun(true)
assert(#gives == 2, "no second try in this window")
STUB.fire("LOOT_CLOSED")

---------------------------------------------------------------------------
-- the loot announcement and the rules
---------------------------------------------------------------------------
local asked = {}
local needAsk = NS.NeedAsk
NS.NeedAsk = function(ids) for _, id in ipairs(ids) do asked[#asked + 1] = id end end
local EPIC2 = STUB.item(71008, "Epischer Kelch", 4)
local EPIC3 = STUB.item(71009, "Epische Krone", 4)
assert(NS.AddLootRule({ k = "p", items = EPIC2, to = "Fraktur" }))
corpse({ EPIC2, EPIC3 })
open()
assert(chatHas(EPIC3) and not chatHas(EPIC2), "the announcement leaves out what a player rule hands out")
assert(#asked == 1 and asked[1] == 71009, "and does not ask for it")
STUB.tick(1.5)
assert(#gives == 1 and gives[1].slot == 1, "the rule gives it")
clear(1)
assert(chatHas("Amisia-Regeln: " .. EPIC2 .. " an Fraktur."))
STUB.fire("LOOT_CLOSED")
-- one click: the officer decides after the answers, so the announcement names it
NS.Set("lootrules.mode", "click")
asked = {}
corpse({ EPIC2 })
open()
assert(chatHas(EPIC2) and #asked == 1, "one-click mode: announced and asked")
NS.Set("lootrules.mode", "auto")
STUB.fire("LOOT_CLOSED")
-- paused: announced
NS.Set("lootrules.paused", true)
corpse({ EPIC2 })
open()
assert(chatHas(EPIC2), "paused: announced")
NS.Set("lootrules.paused", false)
STUB.fire("LOOT_CLOSED")
-- announcing from rare on: a quality rule leaves the rare items the announcement names
NS.Set("loot.quality", 3)
local BLUE4 = STUB.item(71010, "Blauer Kelch", 3)
asked = {}
corpse({ BLUE4 })
open()
assert(chatHas(BLUE4) and #asked == 1, "the rare item is announced and asked")
STUB.tick(3)
assert(#gives == 0, "the quality rule leaves it")
assert(NS.LootRulesPlan()[1].why == "angesagt", tostring(NS.LootRulesPlan()[1].why))
local out = NS.LootRulesProbe("")
assert(has(out[2], "bleibt liegen, angesagt (Regel 1)"), out[2])
NS.Set("loot.quality", 4)
NS.NeedAsk = needAsk
STUB.fire("LOOT_CLOSED")

print("loot rules review ok")
