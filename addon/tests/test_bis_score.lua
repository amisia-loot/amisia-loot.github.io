-- Scoring on the one data set: the level cap of the loaded data, ratings up to level 60, sockets,
-- resilience and penetration, the off-hand weight, score parts and the unit text, the source
-- kinds with their filters (kind, faction, class), places and exclusions, the ranking, dual wield,
-- and the planner window with and without data.
local Gear = NS.Gear
local function near(a, b, eps) return math.abs(a - b) < (eps or 1e-6) end

---------------------------------------------------------------------------
-- the cap comes from the loaded data set; no game switch any more
NS.GEAR = { built = "t", S = {}, I = {} }
assert(Gear.Cap() == 60, "generated Forever data without a cap field")
NS.GEAR.cap = 60
assert(Gear.Cap() == 60)
assert(Gear.Game == nil and Gear.PlannerAvailable == nil and Gear.PhaseOf == nil and Gear.FillRow == nil
    and Gear.TooltipStats == nil and Gear.ReadWearProf == nil, "the TBC helpers are gone")
NS.GEAR = nil
assert(not Gear.Available() and Gear.Cap() == 60, "no data")

---------------------------------------------------------------------------
-- ratings: the curve up to 60; a higher level counts as 60
assert(near(Gear.RatingPerPoint("HIT", 60) * 10, 1) and near(Gear.RatingPerPoint("HIT", 34) * 10, 2), "the curve")
assert(near(Gear.RatingPerPoint("CRIT", 60) * 14, 1))
assert(near(Gear.RatingPerPoint("HIT", 10), Gear.RatingPerPoint("HIT", 1)), "flat below 10")
assert(near(Gear.RatingPerPoint("HIT", 70), Gear.RatingPerPoint("HIT", 60)), "no curve above 60")

-- hit and crit rating work for weapons and spells
local wHit = { HIT = 10, SHIT = 5, CRIT = 20, SCRIT = 7 }
assert(near(Gear.Score({ HIT = 10 }, wHit, 60), 15), "hit works for weapons and spells")
assert(near(Gear.Score({ CRIT = 14 }, wHit, 60), 27), "crit too")
assert(near(Gear.Score({ SHIT = 8 }, wHit, 60), 5) and near(Gear.Score({ SCRIT = 14 }, wHit, 60), 7), "spell ratings for spells")

---------------------------------------------------------------------------
-- new stat keys: sockets, meta socket, resilience, spell penetration
local STATS = {}
C_Item.GetItemStats = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    return id and STATS[id]
end
STATS[7001] = { EMPTY_SOCKET_RED = 1, EMPTY_SOCKET_BLUE = 1, EMPTY_SOCKET_META = 1, ITEM_MOD_RESILIENCE_RATING_SHORT = 20,
    ITEM_MOD_SPELL_PENETRATION_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 30 }
STATS[7002] = { EMPTY_SOCKET_YELLOW = 2, ITEM_MOD_RESILIENCE_RATING = 5, ITEM_MOD_SPELL_PENETRATION = 3,
    ITEM_MOD_HASTE_SPELL_RATING_SHORT = 10 }
local s = Gear.ReadStats(7001)
assert(s.SOCK == 2 and s.META == 1 and s.RES == 20 and s.SPEN == 10 and s.STA == 30, "sockets, resilience, penetration")
s = Gear.ReadStats(7002)
assert(s.SOCK == 2 and s.RES == 5 and s.SPEN == 3 and s.SHASTE == 10 and not s.HASTE, "long spellings and spell haste")
assert(Gear.ReadStats(7199) == nil, "an item the client has not loaded: no stats")
assert(near(Gear.Score({ SOCK = 2, META = 1 }, { GEM = 16, META = 30 }, 60), 62), "a gem per socket, the meta gem")
assert(near(Gear.Score({ RES = 20, SPEN = 10 }, { STA = 1 }, 60), 0), "PvE weights ignore resilience and penetration")
assert(near(Gear.Score({ RES = 20 }, { RES = 1 }, 60), 20))

-- the off-hand weapon damage factor is a weight now
assert(near(Gear.Score({ DPS = 20 }, { DPS = 14 }, 60, "OH"), 70), "default 0.25")
assert(near(Gear.Score({ DPS = 20 }, { DPS = 14, OHDPS = 0.5 }, 60, "OH"), 140), "two-hand fighters at 0.5")
assert(near(Gear.Score({ DPS = 20 }, { DPS = 14, OHDPS = 0.5 }, 60, "MH"), 280), "the main hand stays whole")

---------------------------------------------------------------------------
-- score parts add up to the score
local stat = { STR = 30, AGI = 12, STA = 40, INT = 5, SPI = 3, MP5 = 4, HP5 = 2, AP = 40, RAP = 10, ARMOR = 900, BLOCKVAL = 20,
    FAP = 100, SPP = 10, SPD = 8, HEAL = 15, SP_SHADOW = 6, HIT = 20, MHIT = 5, SHIT = 12, CRIT = 22, MCRIT = 3, SCRIT = 11,
    HASTE = 15, EXP = 8, DEF = 12, DODGE = 10, PARRY = 9, BLOCK = 7, SOCK = 2, META = 1, RES = 4, DPS = 50, SPEED = 3.6 }
local w = { STR = 2, AGI = 1, STA = 0.05, INT = 0.3, SPI = 0.1, MP5 = 1, HP5 = 0.5, AP = 1, RAP = 0.4, ARMOR = 0.01, BLOCKVAL = 0.5,
    SP = 0.2, HEAL = 0.1, SP_SHADOW = 0.3, HIT = 24, SHIT = 3, CRIT = 29, SCRIT = 2, HASTE = 19, EXP = 25, DEF = 1, DODGE = 4,
    PARRY = 3, BLOCK = 2, GEM = 16, META = 30, DPS = 14, SPD_2H = 5, unit = "AP" }
for _, case in ipairs({ { 60, "2H", "DRUID" }, { 60, nil, "WARRIOR" }, { 60, "OH", "ROGUE" }, { 34, "RANGED", "HUNTER" } }) do
    local level, kind, class = case[1], case[2], case[3]
    local parts = Gear.ScoreParts(stat, w, level, kind, class)
    local sum = 0
    for i, p in ipairs(parts) do
        sum = sum + p.points
        assert(p.points ~= 0, "no part without points: " .. p.key)
        assert(type(p.label) == "string" and p.label ~= "" and p.amount ~= nil and p.weight ~= nil, "a part has label, amount, weight")
        if i > 1 then assert(parts[i - 1].points >= p.points, "parts by points, largest first") end
    end
    assert(near(sum, Gear.Score(stat, w, level, kind, class), 0.01), ("parts add up at %d: %.4f"):format(level, sum))
end
local parts = Gear.ScoreParts(stat, w, 60, "2H", "WARRIOR")
local byKey = {}
for _, p in ipairs(parts) do byKey[p.key] = p end
assert(byKey.STR.label == "Stärke" and byKey.STR.amount == "30" and byKey.STR.weight == 2 and near(byKey.STR.points, 60))
assert(Gear.PartText(byKey.STR) == "30 Stärke x 2,0 = 60", Gear.PartText(byKey.STR))
assert(byKey.HIT.label == "Trefferwertung" and byKey.HIT.amount == "2,0 % (20)", "rating as percent with the rating: " .. byKey.HIT.amount)
assert(near(byKey.HIT.points, 54, 1e-4), "hit for weapons and spells: " .. byKey.HIT.points)
assert(byKey.SOCK.label == "Sockel" and byKey.META.label == "Meta-Sockel")
assert(byKey.DPS.label == "Waffenschaden pro Sekunde" and byKey.CRIT.label == "kritische Trefferwertung")
assert(not byKey.RES and not byKey.FAP, "nothing for zero weights or a non-druid's feral attack power")
assert(Gear.ScoreParts(stat, w, 60, "2H", "DRUID")[1] and (function()
    for _, p in ipairs(Gear.ScoreParts(stat, w, 60, "2H", "DRUID")) do
        if p.key == "FAP" then return p.label == "Angriffskraft (Gestalt)" end
    end
end)(), "a druid's feral attack power")

-- the unit: what one point of score is worth
assert(Gear.Unit({ AP = 1, unit = "AP" }) == "AP")
assert(Gear.UnitText(14, { AP = 1, unit = "AP" }) == "+14 Punkte, so viel wie 14 Angriffskraft", Gear.UnitText(14, { AP = 1, unit = "AP" }))
assert(Gear.UnitText(18, { SP = 1, unit = "SP" }) == "+18 Punkte, so viel wie 18 Zauberschaden")
assert(Gear.UnitText(9, { HEAL = 1, unit = "HEAL" }) == "+9 Punkte, so viel wie 9 Heilung")
assert(Gear.UnitText(5, { STA = 1, DEF = 2, unit = "STA" }) == "+5 Punkte, so viel wie 5 Ausdauer")
assert(Gear.Unit({ AP = 1, STR = 2 }) == "AP", "Forever weights: attack power weighs 1")
assert(Gear.UnitText(14, { SP = 0.9, INT = 1.1 }) == "+14 Punkte", "no weight of 1, no unit")
assert(Gear.UnitText(-3, { AP = 1 }) == "-3 Punkte, so viel wie -3 Angriffskraft")

---------------------------------------------------------------------------
-- a Forever world: raids, a dungeon, quests of both factions and one for warriors, a vendor, a PvP
-- vendor, crafting, a world drop and the auction house
STUB.areas = { [2717] = "Geschmolzener Kern", [2017] = "Stratholme" }
STUB.maps[1453] = { name = "Sturmwind", parent = 1415, mapType = 3 }
local WARRIOR_BIT = Gear.CLASS_BIT.WARRIOR
NS.GEAR = {
    game = "forever", cap = 60, built = "forever-test",
    S = {
        { "X", "Molten Core", "Ragnaros", 409, 2717, 0, 0 },                 -- 1
        { "X", "Blackwing Lair", "Nefarian", 469, 2677, 0, 0 },              -- 2
        { "D", "Stratholme", "Baron Totenschwur", nil, 329, 2017 },          -- 3
        { "Q", "Hordeauftrag", 58, 55, "H", 1637, 0, 0 },                    -- 4
        { "Q", "Allianzauftrag", 58, 55, "A", 1453, 0, 0 },                  -- 5
        { "V", "Händlerin", 1453, "", "Rüstungen" },                         -- 6
        { "P", "Feldmarschall", 1453, "A", "Rang 12" },                      -- 7
        { "C", "tailoring", 300 },                                           -- 8
        { "W", nil, 50, 60, 0 },                                             -- 9
        { "A" },                                                             -- 10
        { "Q", "Kriegerprüfung", 60, 58, "", 1453, 0, WARRIOR_BIT },         -- 11
    },
    Z = {},
    I = {
        [6001] = { "HEAD", 4, 4, 60, 4, 1, 66, 0, 0, 0, 1 },
        [6002] = { "HEAD", 4, 4, 60, 4, 1, 76, 0, 0, 0, 2 },
        [6009] = { "HEAD", 4, 4, 58, 3, 1, 62, 0, 0, 0, 1, 3 },
        [6003] = { "CHEST", 4, 4, 58, 3, 1, 62, 0, 0, 0, 3 },
        [6004] = { "CHEST", 4, 4, 60, 3, 1, 63, 0, 0, 0, 11 },
        [6005] = { "FINGER", 4, 0, 55, 3, 1, 60, 0, 0, 0, 5 },
        [6006] = { "FINGER", 4, 0, 55, 3, 1, 60, 0, 0, 0, 4 },
        [6007] = { "NECK", 4, 0, 50, 3, 2, 55, 0, 0, 0, 6 },
        [6008] = { "LEGS", 4, 4, 60, 4, 1, 78, 0, 0, 0, 7 },
        [6010] = { "SHOULDER", 4, 4, 52, 3, 2, 57, 0, 0, 0, 10 },
        [6011] = { "WAIST", 4, 4, 50, 3, 1, 55, 0, 0, 0, 8 },
        [6012] = { "WEAPON", 2, 0, 60, 4, 1, 70, 0, 0, 0, 1 },
        [6013] = { "WEAPONMAINHAND", 2, 4, 60, 4, 1, 70, 0, 0, 0, 1 },
        [6014] = { "LEGS", 4, 4, 55, 3, 2, 58, Gear.CLASS_BIT.PALADIN, 0, 0, 9 },
    },
}
NS.GEAR_WEIGHTS = {
    brackets = { 60 }, order = { "WARRIOR", "PALADIN", "SHAMAN" },
    specs = {
        WARRIOR = { { key = "dps", name = "Waffen/Furor", role = "dps", all = { STR = 2, STA = 0.05, DPS = 14, OHDPS = 0.5, unit = "AP" } } },
        PALADIN = { { key = "ret", name = "Vergeltung", role = "dps", all = { STR = 2.2, DPS = 14, unit = "AP" } } },
        SHAMAN = { { key = "enh", name = "Verstärkung", role = "dps", all = { STR = 2, DPS = 14, OHDPS = 0.5, unit = "AP" } },
                   { key = "ele", name = "Elementar", role = "dps", all = { SP = 1, unit = "SP" } } },
    },
}
assert(Gear.Available() and Gear.Cap() == 60)
STATS = {
    [6001] = { ITEM_MOD_STRENGTH_SHORT = 30 }, [6002] = { ITEM_MOD_STRENGTH_SHORT = 40 }, [6009] = { ITEM_MOD_STRENGTH_SHORT = 28 },
    [6003] = { ITEM_MOD_STRENGTH_SHORT = 35 }, [6004] = { ITEM_MOD_STRENGTH_SHORT = 38 }, [6008] = { ITEM_MOD_STRENGTH_SHORT = 50 },
    [6005] = { ITEM_MOD_STRENGTH_SHORT = 15 }, [6006] = { ITEM_MOD_STRENGTH_SHORT = 18 }, [6007] = { ITEM_MOD_STRENGTH_SHORT = 20 },
    [6010] = { ITEM_MOD_STRENGTH_SHORT = 33 }, [6011] = { ITEM_MOD_STRENGTH_SHORT = 12 },
    [6012] = { ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 80 },
    [6013] = { ITEM_MOD_STRENGTH_SHORT = 6, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 81 },
    [6014] = { ITEM_MOD_STRENGTH_SHORT = 45 },
}
C_Item.IsItemDataCachedByID = function(id) return STATS[id] ~= nil end
Gear._reset()

-- source kinds: order, filter keys, text, places
local S = NS.GEAR.S
assert(Gear.KIND_ORDER.X < Gear.KIND_ORDER.Q and Gear.KIND_ORDER.Q < Gear.KIND_ORDER.D and Gear.KIND_ORDER.V < Gear.KIND_ORDER.R)
assert(Gear.KIND_ORDER.W < Gear.KIND_ORDER.A and Gear.KIND_ORDER.A < Gear.KIND_ORDER.P)
assert(Gear.FilterKey(S[1]) == "X" and Gear.FilterKey(S[3]) == "D" and Gear.FilterKey(S[4]) == "Q" and Gear.FilterKey(S[6]) == "V")
assert(Gear.FilterKey(S[7]) == "P" and Gear.FilterKey(S[8]) == "C" and Gear.FilterKey(S[9]) == "W" and Gear.FilterKey(S[10]) == "A")
assert(Gear.FilterKey({ "R", "Rare", 60, 1 }) == "W" and Gear.FilterKey({ "D", "Deadmines", "VanCleef" }) == "D")
assert(Gear.SourceText(S[1]) == "Geschmolzener Kern: Ragnaros", "the client's area name: " .. Gear.SourceText(S[1]))
assert(Gear.SourceText(S[2]) == "Blackwing Lair: Nefarian", "the source's own name without the client's")
assert(Gear.SourceText(S[3]) == "Stratholme: Baron Totenschwur", Gear.SourceText(S[3]))
assert(Gear.SourceText({ "D", "Deadmines", "VanCleef", "20%" }) == "Deadmines: VanCleef 20%", "old dungeon records")
assert(Gear.SourceText(S[6]) == "Händler: Händlerin, Sturmwind", Gear.SourceText(S[6]))
assert(Gear.SourceText(S[7]):find("^PvP%-Händler: Feldmarschall, Sturmwind"), Gear.SourceText(S[7]))
assert(Gear.SourceText(S[8]) == "Schneiderei (300)", Gear.SourceText(S[8]))
assert(Gear.SourceText(S[9]) == "Weltdrop (Gegner 50-60)" and Gear.SourceText(S[10]) == "Im Auktionshaus gesehen")
assert(Gear.SourceText(S[5]):find("^Quest: ") and Gear.SourceText(S[5]):find("(58)", 1, true), Gear.SourceText(S[5]))
assert(Gear.PlaceOf(S[1]) == "I:409" and Gear.PlaceOf(S[3]) == "I:329" and Gear.PlaceOf(S[6]) == "Z:1453")
assert(Gear.PlaceOf({ "Q", "Q", 20, 18, "A", 1429, 1, 0 }) == "Z:1429" and Gear.PlaceOf({ "R", "Rare", 60, 1412 }) == "Z:1412")
assert(Gear.PlaceOf({ "W", "Wolf", 1, 2, 1429 }) == "Z:1429" and Gear.PlaceOf(S[9]) == nil)
assert(Gear.PlaceOf({ "D", "Deadmines", "VanCleef" }) == "N:Deadmines", "a dungeon without instance id by its name")
assert(Gear.PlaceOf(S[8]) == nil and Gear.PlaceOf(S[10]) == nil)
assert(Gear.Sources(6009, nil)[1][1] == "X", "a raid source first")

local ALL = { X = true, Q = true, D = true, V = true, C = true, W = true }
local function best(o)
    o.class = o.class or "WARRIOR"
    o.spec = o.spec or "dps"
    o.level = o.level or 60
    o.sources = o.sources or ALL
    return Gear.Best(o)
end
local r = best({ faction = "A" })
assert(r.HEAD[1][1] == 6002 and r.HEAD[2][1] == 6001 and r.HEAD[3][1] == 6009, "raid helms by score")
assert(r.CHEST[1][1] == 6004 and r.CHEST[2][1] == 6003, "the warriors' quest chest for a warrior")
assert(r.FINGER1[1][1] == 6005 and not r.FINGER2[1], "the horde quest ring stays out for the alliance")
assert(r.NECK[1][1] == 6007 and r.WAIST[1][1] == 6011, "vendor and crafting")
assert(not r.LEGS[1] and not r.SHOULDER[1], "PvP vendor and auction house start off; the paladin legs are no warrior's")
r = best({ faction = "H" })
assert(r.FINGER1[1][1] == 6006 and not r.FINGER2[1], "the horde ring, the alliance one stays out")
r = best({ class = "PALADIN", spec = "ret" })
assert(r.CHEST[1][1] == 6003 and not r.CHEST[2], "a warriors' quest is no paladin's")
r = best({ class = "PALADIN", spec = "ret", level = 55, sources = { W = true } })
assert(r.LEGS[1] and r.LEGS[1][1] == 6014, "a paladin's world drop by class mask")

-- the switches: raids, PvP vendors, the auction house
r = best({ sources = { Q = true, D = true, V = true, C = true, W = true } })
assert(r.HEAD[1][1] == 6009 and #r.HEAD == 1, "without raids only the helm with a dungeon source")
r = best({ faction = "A", sources = { X = true, P = true, A = true } })
assert(r.LEGS[1][1] == 6008 and r.SHOULDER[1][1] == 6010, "PvP and the auction house switched on")
r = best({ faction = "H", sources = { P = true } })
assert(not r.LEGS[1], "the alliance PvP vendor is no horde one")

-- exclusions: an item, a boss, a place; an item with another source stays
r = best({ exclude = { item = { [6002] = true } } })
assert(r.HEAD[1][1] == 6001, "the next helm moves up")
r = best({ exclude = { boss = { ["Ragnaros"] = true } } })
assert(r.HEAD[1][1] == 6002 and r.HEAD[2][1] == 6009 and #r.HEAD == 2, "the boss's own helm goes, the one with a dungeon source stays")
r = best({ exclude = { place = { ["I:409"] = true } } })
assert(r.HEAD[1][1] == 6002 and r.HEAD[2][1] == 6009 and #r.HEAD == 2, "Molten Core excluded")
assert(not Gear.SourceOk(S[1], { sources = ALL, exclude = { place = { ["I:409"] = true } } }))
assert(Gear.SourceOk(S[1], { sources = ALL, exclude = { place = {}, boss = {}, item = {} } }))
assert(not Gear.SourceOk(S[11], { sources = ALL, class = "MAGE" }) and Gear.SourceOk(S[11], { sources = ALL, class = "WARRIOR" }),
    "a class quest only for its class")

-- dual wield: warriors from 20; a shaman never, whatever the spec
r = best({})
assert(r.plan == "1H" and r.MAINHAND[1] and r.OFFHAND[1] and r.OFFHAND[1].weapon, "two one-handers for a warrior")
r = best({ class = "SHAMAN", spec = "enh" })
for _, e in ipairs(r.OFFHAND) do assert(not e.weapon, "no off-hand weapon for a shaman") end
assert(Gear.CanDualWield("WARRIOR", 60) and not Gear.CanDualWield("SHAMAN", 60, "enh") and not Gear.CanDualWield("SHAMAN", 60, "ele"))

-- the planner window and its settings come with the data
_G.UnitClass = function() return "Krieger", "WARRIOR" end
_G.UnitLevel = function() return 60 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetInventoryItemLink = function() return nil end
local section = NS.SettingItem("gear.kind").section
assert(NS.Visible(section), "the planner's settings with data")
NS.ToggleGearFrame()
assert(AmisiaGearFrame and AmisiaGearFrame:IsShown(), "the planner window")
NS.ToggleGearFrame()
assert(not AmisiaGearFrame:IsShown())
local saved = NS.GEAR
NS.GEAR = nil
STUB.messages = {}
NS.ToggleGearFrame()
assert(not AmisiaGearFrame:IsShown(), "no window without data")
assert(STUB.messages[#STUB.messages] == "|cffe2b857Amisia:|r Die Ausrüstungstabelle ist nicht verfügbar.", STUB.messages[#STUB.messages])
assert(not NS.Visible(section), "the planner's settings hide without data")
NS.GEAR = saved
