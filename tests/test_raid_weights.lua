-- The weighting "Raid" (F-225, D-150, spec docs/specs/2026-11-18-wertung-raid.md): a set of its own
-- only at the level cap and never for a healer (elsewhere it reads Speedrun), the hit caps of a raid
-- boss, the upgrade model against one, "Warum diese Gewichte", the setting's third value, the switch
-- of the gear window round all three, and the link that offers "Raid" once a session to a character
-- at the cap still on Speedrun.
local Gear, Model = NS.Gear, NS.Model
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

---------------------------------------------------------------------------
-- the data: constants, one set per spec for the last bracket
---------------------------------------------------------------------------
local r = Gear.RaidModel()
assert(r and r.level == 60 and r.levels == 3 and r.meleeMiss == 9 and r.dwMiss == 28 and r.spellMiss == 16
    and r.targetDodge == 6.5 and r.scarce == 0.1, "the raid's constants")
local n, healers = 0, 0
for _, cls in ipairs(NS.GEAR_WEIGHTS.order) do
    for _, sp in ipairs(Gear.Specs(cls)) do
        n = n + 1
        if sp.model == "heal" then
            healers = healers + 1
            assert(sp.Raid == nil, cls .. " " .. sp.key .. ": a healer keeps its weights")
            assert(Gear.Weights(cls, sp.key, "Raid", 60) == sp.Speedrun[12] and not Gear.RaidOn(cls, sp.key, "Raid", 60))
        else
            local w = Gear.Weights(cls, sp.key, "Raid", 60)
            assert(w == sp.Raid[12] and w ~= sp.Speedrun[12] and w[sp.unit] == 1, cls .. " " .. sp.key .. ": its raid set")
            for k, v in pairs(w) do assert(v >= 0, cls .. " " .. sp.key .. " " .. k .. " is negative") end
            assert(type(sp.rref) == "table" and Gear.RaidOn(cls, sp.key, "Raid", 60))
        end
        -- below the cap Raid reads Speedrun, bracket for bracket
        for _, lvl in ipairs({ 5, 12, 30, 59 }) do
            assert(Gear.Weights(cls, sp.key, "Raid", lvl) == Gear.Weights(cls, sp.key, "Speedrun", lvl), cls .. " " .. sp.key .. " " .. lvl)
            assert(not Gear.RaidOn(cls, sp.key, "Raid", lvl))
        end
        assert(not Gear.RaidOn(cls, sp.key, "Speedrun", 60) and not Gear.RaidOn(cls, sp.key, "Hardcore", 60))
    end
end
assert(n == 22 and healers == 4, n .. " specs, " .. healers .. " healers")

-- a shadow priest: mana counts far less, haste more, the wand nothing
local s60, r60 = Gear.Weights("PRIEST", "shadow", "Speedrun", 60), Gear.Weights("PRIEST", "shadow", "Raid", 60)
assert(r60.INT < 0.5 * s60.INT and r60.SPI < 0.5 * s60.SPI and r60.HASTE > s60.HASTE and r60.RDPS == nil and s60.RDPS,
    ("INT %s -> %s"):format(s60.INT, r60.INT))

---------------------------------------------------------------------------
-- the hit caps: a raid boss lets 9 % of the swings and 16 % of the spells miss
---------------------------------------------------------------------------
local function caps(spec, kind, level, class) return NS.BisHitCap({ class = class or "PRIEST", spec = spec, kind = kind, level = level }) end
local m, s = caps("shadow", "Raid", 60)
assert(m == 9 and s == 16, m .. " " .. s)
m, s = caps("shadow", "Speedrun", 60)
assert(m == 6 and s == 6)
m, s = caps("shadow", "Raid", 59)
assert(m == 6 and s == 6, "below the cap: as Speedrun")
m, s = caps("holy", "Raid", 60)
assert(m == 6 and s == 6, "a healer: as Speedrun")

STUB.class, STUB.level = "PRIEST", 60
AmisiaDB.settings.gear = { specs = { PRIEST = "shadow" } }
NS.BisSetSpec("shadow")
GetCombatRatingBonus = function(cr) return cr == 8 and 7 or 0 end
GetSpellHitModifier = function() return 0 end
NS.Set("bis.kind", "Speedrun")
local o = NS.BisOpts()
assert(o.spec == "shadow" and o.kind == "Speedrun" and near(o.cap.WAIST.SHIT, 0), "7 % spell hit: nothing left under 6 %")
NS.Set("bis.kind", "Raid")
o = NS.BisOpts()
assert(o.kind == "Raid" and near(o.cap.WAIST.SHIT, 9), "under a raid's 16 %: 9 % left, " .. tostring(o.cap.WAIST.SHIT))
STUB.level = 40
assert(near(NS.BisOpts().cap.WAIST.SHIT, 0), "at 40 Raid is Speedrun: 6 %")
STUB.level = 60
GetCombatRatingBonus, GetSpellHitModifier = nil, nil

---------------------------------------------------------------------------
-- the upgrade model against a raid boss
---------------------------------------------------------------------------
local p = Model.Params("PRIEST", "shadow")
local st = Model.FromRef("PRIEST", p, Model.Ref("PRIEST", 60, {}, "auto"))
st.shit = 6
local function main(kind, stats, place, state)
    return Model.Change("PRIEST", p, kind, state or st, {}, { { stats, place } }).main
end
assert(near(main("Speedrun", { SHIT = 8 }), 0) and main("Raid", { SHIT = 8 }) > 0.5, "spell hit past 6 % counts in a raid")
assert(main("Raid", { INT = 30 }) < 0.5 * main("Speedrun", { INT = 30 }), "mana hardly short")
assert(main("Speedrun", { DPS = 40 }, "RANGED") > 0 and near(main("Raid", { DPS = 40 }, "RANGED"), 0), "no wand in a raid")
-- the raid's numbers do not stay behind for the next call
assert(near(main("Speedrun", { SHIT = 8 }), 0), "Speedrun after Raid is Speedrun")
-- below the cap Raid is Speedrun
local st30 = Model.FromRef("PRIEST", p, Model.Ref("PRIEST", 30, {}, "auto"))
assert(near(main("Raid", { INT = 30, SHIT = 30, DPS = 20 }, "RANGED", st30), main("Speedrun", { INT = 30, SHIT = 30, DPS = 20 }, "RANGED", st30)))
-- a healer's change is the same
local hp = Model.Params("PRIEST", "holy")
local hst = Model.FromRef("PRIEST", hp, Model.Ref("PRIEST", 60, {}, "auto"))
local function heal(kind) return Model.Change("PRIEST", hp, kind, hst, {}, { { { INT = 30, STA = 20, SPI = 15 } } }).total end
assert(near(heal("Raid"), heal("Speedrun")), "a healer: Raid is Speedrun")
-- a warrior with 8 % hit still misses a boss
local wp = Model.Params("WARRIOR", "dps")
local wst = Model.FromRef("WARRIOR", wp, Model.Ref("WARRIOR", 60, {}, "2H"))
wst.hit, wst.dw = 8, false
local function hit(kind) return Model.Change("WARRIOR", wp, kind, wst, {}, { { { MHIT = 10 } } }).main end
assert(near(hit("Speedrun"), 0) and hit("Raid") > 0, "a boss lets 9 % miss")

---------------------------------------------------------------------------
-- "Warum diese Gewichte"
---------------------------------------------------------------------------
local function why(spec, kind, level, class)
    return table.concat(NS.BisWhy({ class = class or "PRIEST", spec = spec, kind = kind, level = level }), " | ")
end
local w = why("shadow", "Raid", 60)
assert(has(w, "Raid: Ziel Stufe 63, Zaubertreffer zählt bis 16 %, Mana kaum knapp, kein Zauberstab.") and has(w, "in Forever noch nicht gemessen")
    and has(w, "Bezug Level 60"), w)
assert(has(w, ("%s Zauberschaden"):format(Gear.Num(Gear.SpecInfo("PRIEST", "shadow").rref.SP))), "the raid's reference character: " .. w)
assert(has(why("dps", "Raid", 60, "WARRIOR"), "Raid: Ziel Stufe 63, Treffer zählt bis 9 %."))
assert(has(why("tank", "Raid", 60, "WARRIOR"), "Raid: Ziel Stufe 63."), why("tank", "Raid", 60, "WARRIOR"))
assert(has(why("holy", "Raid", 60), "Raid: Heiler rechnen wie auf Speedrun."), why("holy", "Raid", 60))
assert(has(why("shadow", "Raid", 40), "Raid gilt ab Stufe 60, bis dahin Speedrun."), why("shadow", "Raid", 40))
assert(not has(why("shadow", "Speedrun", 60), "Raid"), "nothing of it on Speedrun")

---------------------------------------------------------------------------
-- the setting's third value; the gear window's switch round all three; the link once a session
---------------------------------------------------------------------------
local row = NS.SettingItem("bis.kind")
assert(row and #row.values == 3 and row.values[3][1] == "Raid" and has(row.tip, "Raid rechnet einen Bosskampf"), "the choice has Raid")
assert(has(NS.SettingItem("bis.hitCap").tip, "Gewichtung Raid auf Stufe 60: 9 % für Waffen, 16 % für Zauber"))

NS.Set("bis.kind", "Speedrun")
if not AmisiaGearFrame or not AmisiaGearFrame:IsShown() then NS.ToggleGearFrame() end
local GF = AmisiaGearFrame
NS._gearFrame.resetRaidHint()
NS.GearRefresh(true)
assert(GF.raidHint:IsShown() and GF.raidHint.label:GetText() == "Für Raids: Gewichtung Raid", "level 60 on Speedrun: the link")
local seen = {}
for _ = 1, 3 do
    GF.kindButton:Click()
    seen[#seen + 1] = NS.Get("bis.kind")
    assert(GF.kindButton.label:GetText() == "Gewichtung: " .. NS.Get("bis.kind"))
end
assert(table.concat(seen, ",") == "Hardcore,Raid,Speedrun", table.concat(seen, ","))
-- a click on the link chooses Raid; with Raid chosen there is no link
GF.raidHint:Click()
assert(NS.Get("bis.kind") == "Raid" and not GF.raidHint:IsShown())
-- back on Speedrun it is there again, until the window was closed with it once
NS.Set("bis.kind", "Speedrun")
NS.GearRefresh(true)
assert(GF.raidHint:IsShown())
NS.ToggleGearFrame()
NS.ToggleGearFrame()
NS.GearRefresh(true)
assert(not GF.raidHint:IsShown(), "once a session")
-- below the raid's level: never
NS._gearFrame.resetRaidHint()
STUB.level = 59
NS.GearRefresh(true)
assert(not GF.raidHint:IsShown(), "a level 59 character is not offered it")
STUB.level = 60
NS.ToggleGearFrame()
NS.Reset("bis.kind")
print("raid weights: one set at the cap, healers and lower levels as Speedrun, hit caps, model, why, setting, switch, link")
