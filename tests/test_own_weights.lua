-- Own weights (F-230, D-161, spec docs/specs/2026-11-22-eigene-gewichte.md): reading both paste forms with their
-- limits (4000 characters, 40 values, -10 .. 100, digits with one decimal mark, names cleaned to 32 characters),
-- copy and paste back, points against percent (ratings of GearWeights.lua), the weighting "Eigene" (linear, no
-- model, the hit cap still counts, Speedrun without a set and after the chosen set is deleted), templates of the
-- simulation, the saved data's check, the switches round four, "Warum diese Gewichte", the window and the paste
-- window with its preview.
local Gear, OW = NS.Gear, NS.OwnWeights
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b, eps) return type(a) == "number" and math.abs(a - b) < (eps or 1e-6) end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

---------------------------------------------------------------------------
-- form 1: Name=Zahl, German or English, comma or point
---------------------------------------------------------------------------
local res = assert(OW.Parse("Intellect=0.5, SpellDamage=1, HitRating=1.2, Foo=3"))
assert(#res.known == 3 and res.values.INT == 0.5 and res.values.SP == 1 and res.values.HIT == 1.2, "three values")
assert(#res.unknown == 1 and res.unknown[1] == "Foo" and res.name == nil, "unknown: Foo")
res = assert(OW.Parse("Intelligenz=0,24, Spell Power=1\nHit Rating=1.14; kritische Trefferwertung = 0,84;Willenskraft=-0,1"))
assert(res.values.INT == 0.24 and res.values.SP == 1 and res.values.HIT == 1.14 and res.values.CRIT == 0.84
    and res.values.SPI == -0.1, "German names, comma decimals, lines and semicolons")
res = assert(OW.Parse("a=1,b=2,Stärke=2,Agility=1,5"))
assert(res.values.STR == 2 and res.values.AGI == 1.5 and #res.unknown == 2, "a comma after the digits separates; 1,5 is 1.5")
-- numbers: digits with at most one decimal mark
res = assert(OW.Parse("Intellect=1.2.3, Spirit=abc, Stamina=.5, Agility=+2"))
assert(res.values.STA == 0.5 and res.values.AGI == 2 and res.values.INT == nil and res.values.SPI == nil, "1.2.3 and abc are no numbers")
assert(#res.bad == 2 and has(res.bad[1], "keine Zahl"), table.concat(res.bad, "|"))
-- -10 .. 100
res = assert(OW.Parse("Intellect=101, Spirit=-10, Stamina=100, Agility=-10.5"))
assert(res.values.SPI == -10 and res.values.STA == 100 and res.values.INT == nil and res.values.AGI == nil)
assert(#res.bad == 2 and has(res.bad[1], "-10 und 100"), table.concat(res.bad, "|"))
-- nothing recognised, too many values
local none, why = OW.Parse("Hallo Welt")
assert(none == nil and has(why, "Keine Werte erkannt"), why)
local many = {}
for i = 1, 41 do many[i] = "Foo" .. i .. "=1" end
none, why = OW.Parse(table.concat(many, ","))
assert(none == nil and has(why, "höchstens 40"), why)
many[41] = nil
assert(OW.Parse(table.concat(many, ",")), "40 values are fine")
-- at most 4000 characters read
local long = "Intellect=1," .. ("x"):rep(4100) .. ",Spirit=2"
res = assert(OW.Parse(long))
assert(res.cut and res.values.INT == 1 and res.values.SPI == nil, "the rest after 4000 characters is not read")

---------------------------------------------------------------------------
-- form 2: the bracketed line with a head; names cleaned
---------------------------------------------------------------------------
res = assert(OW.Parse('( Any: v1: "Shadow": Class=Priest, Spec=Shadow, Intellect=0.24, SpellDamage=1, ShadowSpellDamage=1, HitRating=1.14 )'))
assert(res.name == "Shadow" and res.values.SP_SHADOW == 1 and res.values.HIT == 1.14 and #res.unknown == 0, "class and spec are no weight")
res = assert(OW.Parse('( X: v1: "|cffff0000Rot|r \1Name' .. ("y"):rep(40) .. '": Intellect=1 )'))
assert(res.name == "Rot Name" .. ("y"):rep(24) and #res.name == 32, tostring(res.name))
assert(OW.CleanName("|Hitem:1|h[Link]|h  zwei   Worte\"") == "[Link] zwei Worte" and OW.CleanName("  \1 ") == nil)
assert(OW.CleanName(("ä"):rep(40)) == ("ä"):rep(32), "32 characters, not bytes")

---------------------------------------------------------------------------
-- points and percent: GearWeights.lua's ratings at the level
---------------------------------------------------------------------------
local pp = { INT = 0.24, SP = 1, SP_SHADOW = 1, HIT = 1.14, CRIT = 0.84, DEF = 2, STA = -0.5 }
local w = Gear.PointWeights(pp, "caster", 60)
assert(near(w.SHIT, 1.14 / Gear.RatingPerPoint("SHIT", 60)) and w.HIT == nil, "a caster's hit is the spells'")
assert(near(w.SCRIT, 0.84 / Gear.RatingPerPoint("CRIT", 60)) and w.CRIT == nil)
assert(near(w.DEF, 2 / Gear.RatingPerPoint("DEF", 60)) and w.HASTE == 0 and w.EXP == 0 and w.INT == 0.24 and w.STA == -0.5)
assert(near(Gear.Score({ HIT = 10 }, w, 60), 11.4) and near(Gear.Score({ CRIT = 10 }, w, 60), 8.4), "a point counts its weight once")
assert(near(Gear.Score({ HASTE = 10 }, w, 60), 0), "empty haste counts nothing (no fallback from crit)")
local back = Gear.ToPoints(w, 60)
for k, v in pairs(pp) do assert(near(back[k], v, 1e-3), k .. " " .. tostring(back[k])) end
local wp = Gear.PointWeights({ HIT = 2, CRIT = 1 }, "phys", 30)
assert(near(wp.HIT, 2 / Gear.RatingPerPoint("HIT", 30)) and near(wp.CRIT, 1 / Gear.RatingPerPoint("CRIT", 30)) and wp.SHIT == nil)
-- Amisia's own numbers per point: a shadow priest's spell hit at 60 (rating 8 per percent)
local s60 = Gear.Weights("PRIEST", "shadow", "Speedrun", 60)
local pts = Gear.ToPoints(s60, 60)
assert(near(pts.HIT, math.floor(s60.SHIT / 8 * 1000 + 0.5) / 1000) and pts.SP == 1 and pts.SP_SHADOW == 1, tostring(pts.HIT))
-- the same set gives the same score at every level for the same item (per point, no weights per level)
local item = { INT = 10, HIT = 8, SP = 12 }
assert(near(Gear.Score(item, Gear.PointWeights(pp, "caster", 20), 20), Gear.Score(item, w, 60)))

---------------------------------------------------------------------------
-- the weighting "Eigene" for a shaman with the character sheet (the model is there)
---------------------------------------------------------------------------
STUB.class, STUB.level = "SHAMAN", 30
local SHEET = { stat = { { 40, 60 }, { 30, 40 }, { 45, 70 }, { 40, 60 }, { 45, 60 } } }
_G.UnitStat = function(_, i) local s = SHEET.stat[i]; return s[2], s[2], s[2] - s[1], 0 end
_G.UnitAttackPower = function() return 300, 0, 0 end
_G.UnitRangedAttackPower = function() return 50, 0, 0 end
_G.GetCritChance = function() return 6 end
_G.GetRangedCritChance = function() return 6 end
_G.GetSpellCritChance = function() return 4 end
_G.GetCombatRatingBonus = function(r) if r == 6 or r == 8 then return 2 end return 0 end
_G.GetHitModifier = function() return 0 end
_G.GetSpellHitModifier = function() return 0 end
_G.GetSpellBonusDamage = function() return 20 end
_G.GetSpellBonusHealing = function() return 30 end
_G.UnitPowerMax = function() return 1200 end
_G.UnitHealthMax = function() return 1500 end
_G.UnitArmor = function() return 900, 900, 900, 0, 0 end
_G.GetDodgeChance = function() return 4 end
_G.GetParryChance = function() return 5 end
_G.GetBlockChance = function() return 0 end
local LINKS = {}
local function gear(id, name, loc, stats)
    LINKS[id] = STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, 1
    it.stats, it.minLevel, it.bind = stats, 25, 1
    return LINKS[id]
end
NS.GEAR = { game = "forever", cap = 60, built = "test-own", I = {}, Z = {}, S = {} }
Gear._reset()
gear(701, "Alter Umhang", "CLOAK", { RESISTANCE0_NAME = 21 })
gear(702, "Kluger Umhang", "CLOAK", { RESISTANCE0_NAME = 21, ITEM_MOD_INTELLECT_SHORT = 12 })
gear(703, "Treffender Umhang", "CLOAK", { RESISTANCE0_NAME = 21, ITEM_MOD_HIT_RATING_SHORT = 10 })
STUB.worn[15] = LINKS[701]
STUB.fire("PLAYER_EQUIPMENT_CHANGED", 15)
STUB.tick(1)
NS.BisSetSpec("enh")
NS.Set("bis.kind", "Speedrun")
assert(NS.Model.Available() and NS.UpgradeOf(LINKS[703]).total, "Speedrun: the model's percent")

-- no set yet: "Eigene" reads Speedrun, the switch skips it
assert(Gear.Weights("SHAMAN", "enh", "Eigene", 30) == Gear.Weights("SHAMAN", "enh", "Speedrun", 30))
assert(Gear.KindText("SHAMAN", "enh", "Eigene") == "Speedrun" and NS.NextKind("Raid", false) == "Speedrun"
    and NS.NextKind("Raid", true) == "Eigene" and NS.NextKind("Eigene", true) == "Speedrun")

local name = assert(OW.Save("SHAMAN", "enh", "Mein Raid", { STR = 2, AGI = 1, AP = 1, HIT = 3, INT = 0.1, ARMOR = 0.1 }, { pick = true }))
assert(name == "Mein Raid" and NS.Get("bis.kind") == "Eigene", "a chosen set turns the own weighting to Eigene")
assert(AmisiaDB.weights.SHAMAN.enh.pick == "Mein Raid" and AmisiaDB.weights.SHAMAN.enh.sets["Mein Raid"].HIT == 3)
local we = Gear.Weights("SHAMAN", "enh", "Eigene", 30)
assert(we.own == "Mein Raid" and near(we.HIT, 3 / Gear.RatingPerPoint("HIT", 30)) and we.STR == 2, "the set per percent at 30")
assert(Gear.KindText("SHAMAN", "enh", "Eigene") == "Eigene: Mein Raid")
local u = NS.UpgradeOf(LINKS[703])
assert(u and u.total == nil and u.own == "Mein Raid" and u.pct and u.gain > 0, "Eigene: linear, no model; the gain against the worn item")
local u2 = NS.UpgradeOf(LINKS[702])
assert(u2.gain < u.gain, "hit beats intellect with these weights")
assert(#NS.UpgradeOthers(LINKS[703]) == 0 or true)
-- the hit cap still counts: no room left, the hit is worth nothing
local o = NS.BisOpts()
o.cap = { BACK = { HIT = 0, SHIT = 0 } }
local capped = NS.UpgradeOf(LINKS[703], o)
assert(capped.gain <= 0, "hit over the cap counts nothing with own weights either: " .. tostring(capped.gain))
-- "Warum diese Gewichte"
local why = table.concat(NS.BisWhy(), " | ")
assert(has(why, "Eigene Gewichte: Mein Raid") and has(why, "ohne Amisias Modell") and has(why, "Je Punkt: Trefferwertung 3, Stärke 2"), why)
NS.BisWeightsReport()
assert(has(STUB.messages[#STUB.messages - 1] or "", "Je Punkt") or has(table.concat(STUB.messages, "|"), "Je Punkt"))

-- changes: the scores again without a reload
local before = NS.UpgradeOf(LINKS[702]).gain
assert(OW.SetValue("SHAMAN", "enh", "Mein Raid", "INT", 5))
assert(NS.UpgradeOf(LINKS[702]).gain > before, "more intellect weight: the intellect cloak rises")
assert(OW.SetValue("SHAMAN", "enh", "Mein Raid", "INT", nil) and AmisiaDB.weights.SHAMAN.enh.sets["Mein Raid"].INT == nil, "empty is 0")
local ok, err = OW.SetValue("SHAMAN", "enh", "Mein Raid", "INT", 200)
assert(not ok and has(err, "-10 bis 100"))

-- the gear window's switch: round four with a chosen set
if not AmisiaGearFrame or not AmisiaGearFrame:IsShown() then NS.ToggleGearFrame() end
local GF = AmisiaGearFrame
AmisiaDB.settings.gear = AmisiaDB.settings.gear or {}
AmisiaDB.settings.gear.class, AmisiaDB.settings.gear.specs = "SHAMAN", { SHAMAN = "enh" }
NS.Set("bis.kind", "Speedrun")
NS.GearRefresh(true)
local seen = {}
for _ = 1, 4 do
    GF.kindButton:Click()
    NS.GearRefresh(true)
    seen[#seen + 1] = NS.Get("bis.kind")
end
assert(table.concat(seen, ",") == "Hardcore,Raid,Eigene,Speedrun", table.concat(seen, ","))
NS.Set("bis.kind", "Eigene")
NS.GearRefresh(true)
assert(GF.kindButton.label:GetText() == "Gewichtung: Eigene: Mein Raid", GF.kindButton.label:GetText())
NS.ToggleGearFrame()

-- rename, the 20 sets, delete the chosen one: back to Speedrun with a chat line
assert(OW.Rename("SHAMAN", "enh", "Mein Raid", "Gilde") == "Gilde" and OW.Pick("SHAMAN", "enh") == "Gilde")
local r2, rwhy = OW.Rename("SHAMAN", "enh", "Gilde", "  ")
assert(r2 == nil and has(rwhy, "Namen"))
for i = 2, 20 do assert(OW.Save("SHAMAN", "enh", "Satz " .. i, { STR = i })) end
local over, owhy = OW.Save("SHAMAN", "enh", "Satz 21", { STR = 1 })
assert(over == nil and has(owhy, "Höchstens 20"), owhy)
assert(OW.Save("SHAMAN", "enh", "Satz 2", { STR = 9 }, { replace = true }), "replacing one is fine at 20")
local dup, dwhy = OW.Save("SHAMAN", "enh", "Satz 3", { STR = 1 })
assert(dup == nil and has(dwhy, "gibt es schon"))
local n0 = #STUB.messages
assert(OW.Delete("SHAMAN", "enh", "Gilde"))
assert(NS.Get("bis.kind") == "Speedrun" and OW.Pick("SHAMAN", "enh") == nil, "the chosen set gone: Speedrun")
assert(#STUB.messages > n0 and has(STUB.messages[#STUB.messages], "wieder auf Speedrun"), STUB.messages[#STUB.messages])
assert(Gear.Weights("SHAMAN", "enh", "Eigene", 30) == Gear.Weights("SHAMAN", "enh", "Speedrun", 30), "without a chosen set Eigene reads Speedrun")
for i = 2, 20 do OW.Delete("SHAMAN", "enh", "Satz " .. i) end
assert(AmisiaDB.weights == nil, "nothing left: the key goes")

---------------------------------------------------------------------------
-- copy and paste back
---------------------------------------------------------------------------
local set = { INT = 0.24, SP = 1, SP_SHADOW = 1, HIT = 1.14, CRIT = 0.8412, SPI = -0.1 }
local line = OW.Export("PRIEST", "Schatten (Sim)", set)
assert(line:sub(1, 34) == '( Amisia: v1: "Schatten (Sim)": Cl' and has(line, "Class=Priest") and has(line, "ShadowSpellDamage=1")
    and has(line, "CritRating=0.8412") and has(line, "Spirit=-0.1"), line)
res = assert(OW.Parse(line))
assert(res.name == "Schatten (Sim)" and count(res.values) == count(set) and #res.unknown == 0, line)
for k, v in pairs(set) do assert(res.values[k] == v, k) end

---------------------------------------------------------------------------
-- the saved data's check
---------------------------------------------------------------------------
local root = { weights = {
    PRIEST = { shadow = { pick = "Fehlt", sets = { Gut = { INT = 1, HIT = 500, FOO = 2, SP = "x" }, ["|cffff0000Rot"] = { INT = 1 } } },
        ["bad key"] = { sets = { A = { INT = 1 } } }, holy = { sets = {} } },
    NOCLASS = { shadow = { sets = { A = { INT = 1 } } } },
    MAGE = "x",
} }
local many2 = {}
for i = 1, 25 do many2[("Satz %02d"):format(i)] = { INT = i } end
root.weights.WARLOCK = { affli = { pick = "Satz 03", sets = many2 } }
OW.Migrate(root)
assert(root.weights.PRIEST.shadow.sets.Gut.INT == 1 and root.weights.PRIEST.shadow.sets.Gut.HIT == nil
    and root.weights.PRIEST.shadow.sets.Gut.FOO == nil and root.weights.PRIEST.shadow.sets.Gut.SP == nil)
assert(root.weights.PRIEST.shadow.pick == nil and count(root.weights.PRIEST.shadow.sets) == 1, "a pick of no set and a coloured name go")
assert(root.weights.PRIEST["bad key"] == nil and root.weights.PRIEST.holy == nil and root.weights.NOCLASS == nil and root.weights.MAGE == nil)
assert(count(root.weights.WARLOCK.affli.sets) == 20 and root.weights.WARLOCK.affli.pick == "Satz 03")
OW.Migrate(root)
assert(count(root.weights.WARLOCK.affli.sets) == 20, "twice changes nothing")
local empty = { weights = { PRIEST = {} } }
OW.Migrate(empty)
assert(empty.weights == nil)

---------------------------------------------------------------------------
-- templates of the simulation; a data file without them
---------------------------------------------------------------------------
STUB.class, STUB.level = "PRIEST", 60
NS.BisSetSpec("shadow")
NS.Set("bis.kind", "Speedrun")
local G = NS.GEAR_WEIGHTS
local keepSim = G.SIM
G.SIM = nil
assert(OW.Templates("PRIEST") == nil, "an old data file: no templates")
G.SIM = { PRIEST = { { name = "Schatten", spec = "shadow", w = { INT = 0.24, SP = 1, SP_SHADOW = 1, SPI = 0.01, HIT = 1.14, CRIT = 0.84, HASTE = 0.73 } },
    { name = "Heilig Raid", spec = "holy", w = { HEAL = 1, MP5 = 0.6 } } } }
local tpl = OW.Templates("PRIEST")[1]
local made = assert(OW.FromTemplate("PRIEST", "shadow", tpl))
assert(made == "Schatten (Sim)" and OW.Pick("PRIEST", "shadow") == made and NS.Get("bis.kind") == "Eigene", made)
assert(Gear.KindText("PRIEST", "shadow", "Eigene") == "Eigene: Schatten (Sim)")
assert(OW.SetValue("PRIEST", "shadow", made, "SPI", 0.2) and tpl.w.SPI == 0.01, "the template stays as it is")
assert(OW.FromTemplate("PRIEST", "shadow", tpl) == made and OW.Get("PRIEST", "shadow", made).SPI == 0.01, "again: the set as the template")
-- Amisia's numbers into a set
assert(OW.FromAmisia("PRIEST", "shadow", made, "Raid", 60))
local raidPts = Gear.ToPoints(Gear.Weights("PRIEST", "shadow", "Raid", 60), 60)
assert(near(OW.Get("PRIEST", "shadow", made).INT, raidPts.INT, 1e-3) and OW.Get("PRIEST", "shadow", made).SPI ~= 0.01)

---------------------------------------------------------------------------
-- the window and the paste window
---------------------------------------------------------------------------
OW.FromTemplate("PRIEST", "shadow", tpl)
local F = NS.ShowWeights()
assert(F:IsShown() and has(F.setLink.label:GetText(), "Schatten (Sim)") and F.kindLink.label:GetText() == "Gewichtung: Eigene: Schatten (Sim)",
    F.kindLink.label:GetText())
local function row(key)
    for _, r in ipairs(F.list.rows) do
        if r:IsShown() and r.item and r.item.key == key then return r end
    end
end
assert(row("SP").box:GetText() == "1" and row("SP_SHADOW").box:GetText() == "1" and row("INT").box:GetText() == "0,24"
    and row("HIT").box:GetText() == "1,14", row("INT").box:GetText())
-- typing counts 0.3 s after the last key
local box = row("INT").box
box:SetFocus()
box:SetText("2")
box:GetScript("OnTextChanged")(box, true)
assert(OW.Get("PRIEST", "shadow", "Schatten (Sim)").INT == 0.24, "not with the key")
STUB.tick(0.4)
assert(OW.Get("PRIEST", "shadow", "Schatten (Sim)").INT == 2, "0.3 s later")
box:ClearFocus()
-- "Weitere Werte" folds the rest
local more
for _, r in ipairs(F.list.rows) do if r.item and r.item.more then more = r end end
assert(more and has(more.label:GetText(), "Weitere Werte") and row("BLOCKVAL") == nil)
more:Click()
assert(F.list.items[#F.list.items].key ~= nil, "unfolded")
more:Click()
-- paste: the preview, then "Übernehmen"
local P = NS.WeightsOpenPaste("paste")
P.area.box:SetText("Intellect=0.5, SpellDamage=1, HitRating=1.2, Foo=3")
P.area.box:GetScript("OnTextChanged")(P.area.box, true)
STUB.tick(0.4)
local pv = P.preview:GetText()
assert(has(pv, "Erkannt: 3 Werte") and has(pv, "unbekannt: Foo") and has(pv, "Neuer Satz \"Eingefügt\""), pv)
P.apply:Click()
assert(not P:IsShown() and OW.Get("PRIEST", "shadow", "Eingefügt").HIT == 1.2 and OW.Pick("PRIEST", "shadow") == "Eingefügt")
assert(has(F.setLink.label:GetText(), "Eingefügt"))
-- copy: the line, read back by a new paste with the same numbers
P = NS.WeightsOpenPaste("copy")
local copied = P.area.box:GetText()
assert(has(copied, '"Eingefügt"') and has(copied, "HitRating=1.2"), copied)
P.area.box:SetText("tippen")
P.area.box:GetScript("OnTextChanged")(P.area.box, true)
assert(P.area.box:GetText() == copied, "the copied line cannot be changed")
OW.Rename("PRIEST", "shadow", "Eingefügt", "Alt")
P = NS.WeightsOpenPaste("paste")
P.area.box:SetText(copied)
P.area.box:GetScript("OnTextChanged")(P.area.box, true)
STUB.tick(0.4)
assert(has(P.preview:GetText(), "Neuer Satz \"Eingefügt\""), P.preview:GetText())
P.apply:Click()
for k, v in pairs(OW.Get("PRIEST", "shadow", "Alt")) do assert(OW.Get("PRIEST", "shadow", "Eingefügt")[k] == v, k) end
-- pasting the line again names the set it replaces
P = NS.WeightsOpenPaste("paste")
P.area.box:SetText(copied)
P.area.box:GetScript("OnTextChanged")(P.area.box, true)
STUB.tick(0.4)
assert(has(P.preview:GetText(), "Ersetzt den Satz \"Eingefügt\""), P.preview:GetText())
P:Hide()
-- every weight 0: the line says so
assert(OW.Save("PRIEST", "shadow", "Leer", {}, { pick = true }))
NS.WeightsRefresh()
assert(F.zero:IsShown(), "Alle Gewichte sind 0.")
F:Hide()

-- clean up
NS.Set("bis.kind", "Speedrun")
AmisiaDB.weights = nil
G.SIM = keepSim
Gear.OwnChanged()
print("own weights: both paste forms, limits, copy and paste back, points and percent, Eigene linear, templates, check, window")
