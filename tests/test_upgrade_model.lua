-- The exact upgrade for the spec (Gear/Model.lua, F-115, D-54): the character sheet read out of combat
-- and held in a fight, the tooltip line with the spec and the whole output's percent, Shift with the
-- parts, the slot percent, the other specs and the values that move, hit over the cap worth nothing,
-- a talent's percent on an attribute, the fallback without a sheet, a set bonus broken by a swap,
-- secret values never break, the threshold bis.minTotal.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.class, STUB.level = "SHAMAN", 30

-- the sheet: a level 30 shaman, a few values the tests change
local SHEET = { stat = { { 40, 60 }, { 30, 40 }, { 45, 70 }, { 40, 60 }, { 45, 60 } }, ap = 300, crit = 6, hit = 2,
    spell = 20, mana = 1200, hp = 1500, armor = 900 }
local function sheetOn()
    -- stat, effectiveStat, posBuff, negBuff: everything over the naked value is in posBuff
    _G.UnitStat = function(_, i) local s = SHEET.stat[i]; return s[2], s[2], s[2] - s[1], 0 end
    _G.UnitAttackPower = function() return SHEET.ap, 0, 0 end
    _G.UnitRangedAttackPower = function() return 50, 0, 0 end
    _G.GetCritChance = function() return SHEET.crit end
    _G.GetRangedCritChance = function() return SHEET.crit end
    _G.GetSpellCritChance = function() return 4 end
    _G.GetCombatRatingBonus = function(r) if r == 6 or r == 8 then return SHEET.hit end return 0 end
    _G.GetHitModifier = function() return 0 end
    _G.GetSpellHitModifier = function() return 0 end
    _G.GetSpellBonusDamage = function() return SHEET.spell end
    _G.GetSpellBonusHealing = function() return 30 end
    _G.UnitPowerMax = function() return SHEET.mana end
    _G.UnitHealthMax = function() return SHEET.hp end
    _G.UnitArmor = function() return SHEET.armor, SHEET.armor, SHEET.armor, 0, 0 end
    _G.GetDodgeChance = function() return 4 end
    _G.GetParryChance = function() return 5 end
    _G.GetBlockChance = function() return 0 end
end
sheetOn()

local LINKS = {}
local function gear(id, name, loc, stats, o)
    o = o or {}
    LINKS[id] = STUB.item(id, name, o.q or 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, o.classID or 4, o.sub or 1
    it.stats, it.minLevel, it.bind = stats, o.minLevel or 25, 1
    return LINKS[id]
end
NS.GEAR = { game = "forever", cap = 60, built = "test-model", I = {}, Z = {}, S = {} }
Gear._reset()
gear(401, "Dunkler Lederumhang", "CLOAK", { RESISTANCE0_NAME = 21 })
gear(402, "Felle des Irdenen Rings", "CLOAK", { RESISTANCE0_NAME = 25, ITEM_MOD_STRENGTH_SHORT = 5,
    ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_SPIRIT_SHORT = 5 })
gear(403, "Trefferumhang", "CLOAK", { RESISTANCE0_NAME = 21, ITEM_MOD_HIT_RATING_SHORT = 20 })
gear(404, "Dickerer Umhang", "CLOAK", { RESISTANCE0_NAME = 120 })

STUB.worn[15] = LINKS[401]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 15)
STUB.tick(1)
assert(NS.Model.Available(), "the model is there")
NS.BisSetSpec("enh")

---------------------------------------------------------------------------
-- the sheet and the line
---------------------------------------------------------------------------
local p = NS.Model.Params("SHAMAN", "enh")
assert(p and p.model == "phys", "enhancement runs the physical model")
local st, approx = NS.Model.OwnState("SHAMAN", "enh", p)
assert(st and not approx, "read from the sheet")
assert(st.ap == 300 and st.crit == 6 and st.hit == 2 and st.mana == 1200, "the sheet's values: " .. st.ap)
-- intellect 60 on base 40 plus no gear: a talent's percent shows as the ratio, capped at 1.2
assert(st.mult.INT == 1.2 and st.mult.STR == 1.2, "ratio capped: " .. tostring(st.mult.INT))
SHEET.stat[4] = { 40, 44 }
STUB.fire("CHARACTER_POINTS_CHANGED")
STUB.tick(1)
st = NS.Model.OwnState("SHAMAN", "enh", p)
assert(st.mult.INT == 1.1, "intellect +10 %: " .. tostring(st.mult.INT))
SHEET.stat[4] = { 40, 40.4 }
STUB.fire("CHARACTER_POINTS_CHANGED")
STUB.tick(1)
st = NS.Model.OwnState("SHAMAN", "enh", p)
assert(st.mult.INT == 1, "under 2 % counts as none: " .. tostring(st.mult.INT))
-- the other attributes: plain
for i = 1, 5 do SHEET.stat[i] = { SHEET.stat[i][1], SHEET.stat[i][1] } end
STUB.fire("CHARACTER_POINTS_CHANGED")
STUB.tick(1)

local u = assert(NS.UpgradeOf(LINKS[402]), "the cloak")
assert(u.up and u.total and u.total > 0 and u.total < 20, "a small number for the whole output: " .. tostring(u.total))
assert(u.pct and u.pct > 100, "while the slot's score more than doubles: " .. tostring(u.pct))
assert(u.role == "dps" and u.spec == "enh" and not u.guessed and not u.approx, "spec, role, from the sheet")

-- the tooltip line
local tip = CreateFrame("GameTooltip", "ModelTooltip")
local lines = {}
tip.AddLine = function(_, t) lines[#lines + 1] = t end
local function show(link)
    wipe(lines)
    if tip.scripts.OnTooltipCleared then tip.scripts.OnTooltipCleared(tip) end
    tip.shownLink = link
    for _, h in ipairs(STUB.tdp) do h.fn(tip) end
    return table.concat(lines, " / ")
end
local text = show(LINKS[402])
local want = ("Upgrade für dich (Verstärkung): +%s %% Schaden (Rücken)"):format(NS.Num(u.total, 1))
assert(lines[1] == want, "the line: " .. text .. " | want " .. want)
assert(has(lines[2], "statt Dunkler Lederumhang"), "the worn one: " .. text)

-- Shift: parts, slot percent, the other specs, the values that move
STUB.shift = true
text = show(LINKS[402])
assert(has(text, "Schaden +") and has(text, "Überleben +"), "the parts: " .. text)
assert(has(text, ("Slot: +%d %%"):format(u.pct)), "the slot percent: " .. text)
assert(has(text, "Andere Spezialisierungen: Elementar ") and has(text, "Wiederherstellung "), "the other specs: " .. text)
assert(has(text, "Angriffskraft: 300 -> 310"), "attack power moves by two per strength: " .. text)
assert(not has(text, "Ungefähr"), "not approximate: " .. text)
assert(NS.Set("bis.otherSpecs", false))
text = show(LINKS[402])
assert(not has(text, "Andere Spezialisierungen"), "the switch: " .. text)
NS.Reset("bis.otherSpecs")
STUB.shift = false

-- "Warum?" (the hover of the goals' explanation, /amisia bis warum): the whole change and the values
local ex = table.concat(NS.BisExplainModel(LINKS[402]), " / ")
assert(has(ex, "Gesamt: +") and has(ex, "(deine Werte vom Charakterbogen)") and has(ex, "Angriffskraft: 300 -> 310"), ex)

---------------------------------------------------------------------------
-- hit over the cap is worth nothing; under it, it is
---------------------------------------------------------------------------
u = NS.UpgradeOf(LINKS[403])
assert(u.total > 0.3 and u.up, "hit under the cap: " .. u.total)
SHEET.hit = 12
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 15)
STUB.tick(1)
u = NS.UpgradeOf(LINKS[403])
assert(math.abs(u.total) < 0.05 and not u.up, "hit over the cap: " .. u.total)
SHEET.hit = 2
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 15)
STUB.tick(1)

---------------------------------------------------------------------------
-- the threshold
---------------------------------------------------------------------------
u = NS.UpgradeOf(LINKS[404])
assert(u.total > 0 and u.total < 0.3 and not u.up, "99 armour more is under 0.3 %: " .. u.total)
assert(NS.Set("bis.minTotal", 0))
u = NS.UpgradeOf(LINKS[404])
assert(u.total > 0.05 and u.up, "at 0 any gain from 0,05 % counts: " .. u.total)
NS.Reset("bis.minTotal")
assert(NS.SettingItem("bis.minTotal").default == 0.3, "default 0.3")

---------------------------------------------------------------------------
-- a fight holds the sheet; secret values never break
---------------------------------------------------------------------------
local before = NS.UpgradeOf(LINKS[402]).total
STUB.combat = true
SHEET.ap = 900
STUB.fire("PLAYER_REGEN_DISABLED")
u = NS.UpgradeOf(LINKS[402])
assert(math.abs(u.total - before) < 1e-9 and not u.approx, "the sheet from before the fight: " .. u.total)
STUB.combat = false
SHEET.ap = 300

_G.UnitStat = function() error("Werte geheim") end
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 15)
STUB.tick(1)
u = NS.UpgradeOf(LINKS[402])
assert(u and u.approx and u.total, "no sheet: base values and gear, marked approximate")
text = show(LINKS[402])
assert(has(lines[1], "(ungefähr)"), "the line says so: " .. text)
sheetOn()
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 15)
STUB.tick(1)
assert(not NS.UpgradeOf(LINKS[402]).approx, "read again")

---------------------------------------------------------------------------
-- a set bonus the swap breaks
---------------------------------------------------------------------------
gear(410, "Set Kopf", "HEAD", { ITEM_MOD_STRENGTH_SHORT = 5 })
gear(411, "Set Rücken", "CLOAK", { ITEM_MOD_STRENGTH_SHORT = 5 })
NS.BIS.SET = NS.BIS.SET or {}
NS.BIS.SET[900] = { name = "Testset", items = { 410, 411 }, b = { { 2, "STRENGTH=30" } } }
local plain = NS.UpgradeOf(LINKS[402]).total
STUB.worn[1], STUB.worn[15] = LINKS[410], LINKS[411]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 15)
STUB.tick(1)
u = NS.UpgradeOf(LINKS[402])
assert(u.total < plain - 0.5, "taking off the second piece loses the bonus: " .. u.total .. " vs " .. plain)

print("upgrade model ok")
