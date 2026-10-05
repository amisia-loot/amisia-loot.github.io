-- Scoring for both clients: the game and level cap of the loaded data, ratings above level 60,
-- sockets, resilience and penetration, the off-hand weight, score parts and the unit text, the
-- tooltip reader, rows filled from the client, the new source kinds with their filters, places
-- and exclusions, and the planner staying a Forever thing.
local Gear = NS.Gear
local function near(a, b, eps) return math.abs(a - b) < (eps or 1e-6) end

---------------------------------------------------------------------------
-- game and cap come from the loaded data set
NS.GEAR = { built = "t", S = {}, I = {} }
assert(Gear.Game() == "forever" and Gear.Cap() == 60, "generated Forever data without a game field")
NS.GEAR.game, NS.GEAR.cap = "tbc", 70
assert(Gear.Game() == "tbc" and Gear.Cap() == 70)
NS.GEAR = nil
assert(Gear.Game() == nil and not Gear.PlannerAvailable(), "no data, no game")

---------------------------------------------------------------------------
-- ratings: Forever stays on its curve up to 60, TBC goes on with 82 / (262 - 3L)
assert(near(Gear.RatingPerPoint("HIT", 60) * 10, 1) and near(Gear.RatingPerPoint("HIT", 34) * 10, 2), "Forever unchanged")
assert(near(Gear.RatingPerPoint("CRIT", 60) * 14, 1))
local function per(kind, level) return 1 / Gear.RatingPerPoint(kind, level) end
assert(near(per("HIT", 70), 15.77, 0.005), "15.77 hit rating at 70: " .. per("HIT", 70))
assert(near(per("SHIT", 70), 12.62, 0.005), "12.62 spell hit")
assert(near(per("CRIT", 70), 22.08, 0.005), "22.08 crit")
assert(near(per("HASTE", 70), 15.77, 0.005) and near(per("EXP", 70), 15.77, 0.005))
assert(near(per("EXP", 70) / 4, 3.94, 0.005), "3.94 expertise rating per point")
assert(near(per("DODGE", 70), 18.92, 0.005) and near(per("PARRY", 70), 23.65, 0.005) and near(per("BLOCK", 70), 7.88, 0.005))
assert(near(per("DEF", 70), 2.37, 0.006), "2.37 defence rating per point")
assert(near(per("HIT", 65), 10 * 82 / 67), "the curve between 60 and 70")

-- TBC splits weapon and spell ratings; Forever's count for both
local wHit = { HIT = 10, SHIT = 5, CRIT = 20, SCRIT = 7 }
assert(near(Gear.Score({ HIT = 10 }, wHit, 60), 15), "Forever hit works for weapons and spells")
assert(near(Gear.Score({ HIT = 15.769230769 }, wHit, 70), 10, 1e-4), "TBC hit rating is physical only")
assert(near(Gear.Score({ SHIT = 12.615384615 }, wHit, 70), 5, 1e-4), "TBC spell hit")
assert(near(Gear.Score({ CRIT = 22.076923077 }, wHit, 70), 20, 1e-4), "TBC crit rating is physical only")
assert(near(Gear.Score({ SCRIT = 22.076923077 }, wHit, 70), 7, 1e-4), "TBC spell crit")

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
assert(near(Gear.Score({ SOCK = 2, META = 1 }, { GEM = 16, META = 30 }, 70), 62), "a gem per socket, the meta gem")
assert(near(Gear.Score({ RES = 20, SPEN = 10 }, { STA = 1 }, 70), 0), "PvE weights ignore resilience and penetration")
assert(near(Gear.Score({ RES = 20 }, { RES = 1 }, 70), 20))

-- the off-hand weapon damage factor is a weight now
assert(near(Gear.Score({ DPS = 20 }, { DPS = 14 }, 60, "OH"), 70), "default 0.25")
assert(near(Gear.Score({ DPS = 20 }, { DPS = 14, OHDPS = 0.5 }, 70, "OH"), 140), "two-hand fighters at 0.5")
assert(near(Gear.Score({ DPS = 20 }, { DPS = 14, OHDPS = 0.5 }, 70, "MH"), 280), "the main hand stays whole")

---------------------------------------------------------------------------
-- score parts add up to the score
local stat = { STR = 30, AGI = 12, STA = 40, INT = 5, SPI = 3, MP5 = 4, HP5 = 2, AP = 40, RAP = 10, ARMOR = 900, BLOCKVAL = 20,
    FAP = 100, SPP = 10, SPD = 8, HEAL = 15, SP_SHADOW = 6, HIT = 31.538461538, MHIT = 5, SHIT = 12, CRIT = 22, MCRIT = 3, SCRIT = 11,
    HASTE = 15, EXP = 8, DEF = 12, DODGE = 10, PARRY = 9, BLOCK = 7, SOCK = 2, META = 1, RES = 4, DPS = 50, SPEED = 3.6 }
local w = { STR = 2, AGI = 1, STA = 0.05, INT = 0.3, SPI = 0.1, MP5 = 1, HP5 = 0.5, AP = 1, RAP = 0.4, ARMOR = 0.01, BLOCKVAL = 0.5,
    SP = 0.2, HEAL = 0.1, SP_SHADOW = 0.3, HIT = 24, SHIT = 3, CRIT = 29, SCRIT = 2, HASTE = 19, EXP = 25, DEF = 1, DODGE = 4,
    PARRY = 3, BLOCK = 2, GEM = 16, META = 30, DPS = 14, SPD_2H = 5, unit = "AP" }
for _, case in ipairs({ { 70, "2H", "DRUID" }, { 70, nil, "WARRIOR" }, { 60, "OH", "ROGUE" }, { 34, "RANGED", "HUNTER" } }) do
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
local parts = Gear.ScoreParts(stat, w, 70, "2H", "WARRIOR")
local byKey = {}
for _, p in ipairs(parts) do byKey[p.key] = p end
assert(byKey.STR.label == "Stärke" and byKey.STR.amount == "30" and byKey.STR.weight == 2 and near(byKey.STR.points, 60))
assert(Gear.PartText(byKey.STR) == "30 Stärke x 2,0 = 60", Gear.PartText(byKey.STR))
assert(byKey.HIT.label == "Trefferwertung" and byKey.HIT.amount == "2,0 % (32)", "rating as percent with the rating: " .. byKey.HIT.amount)
assert(near(byKey.HIT.points, 48, 1e-4))
assert(byKey.SOCK.label == "Sockel" and byKey.META.label == "Meta-Sockel")
assert(byKey.DPS.label == "Waffenschaden pro Sekunde" and byKey.CRIT.label == "kritische Trefferwertung")
assert(not byKey.RES and not byKey.FAP, "nothing for zero weights or a non-druid's feral attack power")
assert(Gear.ScoreParts(stat, w, 70, "2H", "DRUID")[1] and (function()
    for _, p in ipairs(Gear.ScoreParts(stat, w, 70, "2H", "DRUID")) do
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
-- the tooltip reader, for a client without GetItemStats
local savedC, savedG = C_Item.GetItemStats, _G.GetItemStats
C_Item.GetItemStats, _G.GetItemStats = nil, nil
local TIP = {}
local realCreate = CreateFrame
_G.CreateFrame = function(kind, name, parent, template)
    local f = realCreate(kind, name, parent, template)
    if name == "AmisiaScanTip" then
        f.template = template
        f.n = 0
        f.SetHyperlink = function(self, link)
            local id = tonumber(tostring(link):match("item:(%d+)"))
            local lines = TIP[id] or {}
            self.n = #lines
            for i, l in ipairs(lines) do
                _G["AmisiaScanTipTextLeft" .. i] = { GetText = function() return l[1] end }
                _G["AmisiaScanTipTextRight" .. i] = { GetText = function() return l[2] end }
            end
        end
        f.ClearLines = function(self) self.n = 0 end
        f.NumLines = function(self) return self.n end
    end
    return f
end

-- German client strings
_G.ITEM_SPELL_TRIGGER_ONEQUIP = "Anlegen:"
_G.ITEM_MOD_STRENGTH = "%c%s Stärke"
_G.ITEM_MOD_STAMINA = "%c%s Ausdauer"
_G.ITEM_MOD_INTELLECT = "%c%s Intelligenz"
_G.ITEM_MOD_HIT_RATING = "Erhöht Eure Trefferwertung um %s."
_G.ITEM_MOD_SPELL_DAMAGE_DONE = "Erhöht durch Zauber und magische Effekte zugefügten Schaden um bis zu %s."
_G.ITEM_MOD_RESILIENCE_RATING = "Erhöht Eure Abhärtungswertung um %s."
_G.EMPTY_SOCKET_RED = "Roter Sockel"
_G.EMPTY_SOCKET_BLUE = "Blauer Sockel"
_G.EMPTY_SOCKET_META = "Metasockel"
_G.ARMOR_TEMPLATE = "%s Rüstung"
_G.DPS_TEMPLATE = "(%.1f Schaden pro Sekunde)"
_G.ITEM_SOCKET_BONUS = "Sockelbonus: %s"
TIP[7100] = {
    { "Helm der Probe" }, { "Kopf", "Platte" }, { "980 Rüstung" }, { "+25 Stärke" }, { "+18 Ausdauer" }, { "-4 Intelligenz" },
    { "Roter Sockel" }, { "Roter Sockel" }, { "Metasockel" }, { "Sockelbonus: +4 Stärke" },
    { "Anlegen: Erhöht Eure Trefferwertung um 12." }, { "Anlegen: Erhöht Eure Abhärtungswertung um 7." },
    { "Anlegen: Erhöht durch Zauber und magische Effekte zugefügten Schaden um bis zu 9." },
}
TIP[7101] = { { "Klinge" }, { "Waffenhand", "Schwert" }, { "120 - 230 Schaden", "Tempo 2,60" }, { "(67,3 Schaden pro Sekunde)" }, { "+10 Stärke" } }
Gear._reset()
s = Gear.ReadStats(7100)
assert(s, "the tooltip reader answers")
assert(AmisiaScanTip and AmisiaScanTip.template == "GameTooltipTemplate", "a hidden tooltip of the client's template")
assert(s.STR == 25 and s.STA == 18 and s.INT == -4, "signed stats, the socket bonus left out: " .. tostring(s.STR))
assert(s.ARMOR == 980 and s.SOCK == 2 and s.META == 1 and s.HIT == 12 and s.RES == 7 and s.SPD == 9, "equip lines, sockets, armour")
s = Gear.ReadStats(7101)
assert(near(s.DPS, 67.3) and s.SPEED == 2.6 and s.STR == 10, "damage per second with a decimal comma and the speed")
assert(Gear.ReadStats(7199) == nil, "an item the client has not loaded: no lines, no stats")

-- English client strings
_G.ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:"
_G.ITEM_MOD_STRENGTH = "%c%s Strength"
_G.ITEM_MOD_STAMINA = "%c%s Stamina"
_G.ITEM_MOD_INTELLECT = "%c%s Intellect"
_G.ITEM_MOD_HIT_RATING = "Improves hit rating by %s."
_G.ITEM_MOD_SPELL_DAMAGE_DONE = "Increases damage done by magical spells and effects by up to %s."
_G.ITEM_MOD_RESILIENCE_RATING = "Improves your resilience rating by %s."
_G.EMPTY_SOCKET_RED = "Red Socket"
_G.EMPTY_SOCKET_BLUE = "Blue Socket"
_G.EMPTY_SOCKET_META = "Meta Socket"
_G.ARMOR_TEMPLATE = "%s Armor"
_G.DPS_TEMPLATE = "(%.1f damage per second)"
_G.ITEM_SOCKET_BONUS = "Socket Bonus: %s"
TIP[7102] = {
    { "Helm of Trial" }, { "Head", "Plate" }, { "980 Armor" }, { "+25 Strength" }, { "+18 Stamina" },
    { "Red Socket" }, { "Blue Socket" }, { "Meta Socket" }, { "Socket Bonus: +4 Strength" },
    { "Equip: Improves hit rating by 12." }, { "Equip: Improves your resilience rating by 7." },
}
TIP[7103] = { { "Blade" }, { "Main Hand", "Sword" }, { "120 - 230 Damage", "Speed 2.60" }, { "(67.3 damage per second)" } }
Gear._reset()
s = Gear.ReadStats(7102)
assert(s.STR == 25 and s.STA == 18 and s.ARMOR == 980 and s.SOCK == 2 and s.META == 1 and s.HIT == 12 and s.RES == 7, "English lines")
s = Gear.ReadStats(7103)
assert(near(s.DPS, 67.3) and s.SPEED == 2.6)
_G.CreateFrame = realCreate
C_Item.GetItemStats, _G.GetItemStats = savedC, savedG

---------------------------------------------------------------------------
-- a TBC world: raids with phases and a token, heroic and normal dungeons, reputation, badges
STUB.areas = { [3714] = "Die Zerschmetterten Hallen", [3457] = "Karazhan" }
STUB.factions = { [935] = "Die Sha'tar" }
NS.GEAR = {
    game = "tbc", cap = 70, built = "tbc-test",
    S = {
        { "X", "Karazhan", "Prince Malchezaar", 532, 3457, 1, 0 },                      -- 1
        { "X", "Serpentshrine Cavern", "Lady Vashj", 548, 3607, 2, 0 },                 -- 2
        { "D", "The Shattered Halls", "Warchief Kargath Bladefist", nil, 540, 3714, 1 },  -- 3 heroic
        { "D", "The Shattered Halls", "Warchief Kargath Bladefist", nil, 540, 3714, 0 },  -- 4 normal
        { "F", "The Sha'tar", 7, 935, "" },                                              -- 5
        { "F", "Thrallmar", 6, 947, "H" },                                               -- 6
        { "V", "G'eras", 111, "", "Badge of Justice", 4 },                               -- 7
        { "X", "Magtheridon's Lair", "Magtheridon", 544, 3836, 1, 29753 },               -- 8 token
        { "C", "tailoring", 375 },                                                       -- 9
        { "W", nil, 70, 73, 0 },                                                         -- 10
        { "D", "Magisters' Terrace", "Kael'thas Sunstrider", nil, 585, 4131, 1, 5 },      -- 11 heroic, phase 5
    },
    Z = {},
    I = {
        [6001] = { "HEAD", 4, 4, 70, 4, 1, 115, 0, 0, 0, 1 },
        [6002] = { "HEAD", 4, 4, 70, 4, 1, 128, 0, 0, 0, 2 },
        [6003] = { "CHEST", 4, 4, 70, 3, 1, 110, 0, 0, 0, 3 },
        [6004] = { "CHEST", 4, 4, 70, 3, 1, 100, 0, 0, 0, 4 },
        [6005] = { "FINGER", 4, 0, 70, 4, 1, 110, 0, 0, 0, 5 },
        [6006] = { "FINGER", 4, 0, 70, 3, 1, 105, 0, 0, 0, 6 },
        [6007] = { "NECK", 4, 0, 70, 4, 1, 128, 0, 0, 0, 7 },
        [6008] = { "CHEST", 4, 4, 70, 4, 1, 120, 1, 0, 0, 8 },
        [6009] = { "HEAD", 4, 4, 70, 4, 1, 112, 0, 0, 0, 1, 4 },
        [6010] = { "", 0, 0, 0, 0, 0, 0, 0, 0, 0, 10 },
        [6011] = { "", 0, 0, 0, 0, 0, 0, 0, 0, 0, 10 },
        [6012] = { "WEAPON", 2, 0, 70, 4, 1, 120, 0, 0, 0, 1 },
        [6013] = { "WEAPONMAINHAND", 2, 4, 70, 4, 1, 120, 0, 0, 0, 1 },
        [6014] = { "LEGS", 4, 4, 70, 4, 1, 115, 0, 0, 0, 11 },
    },
}
NS.GEAR_WEIGHTS = {
    brackets = { 70 }, order = { "WARRIOR", "PALADIN", "SHAMAN" },
    specs = {
        WARRIOR = { { key = "dps", name = "Waffen/Furor", role = "dps", all = { STR = 2, STA = 0.05, DPS = 14, OHDPS = 0.5, unit = "AP" } } },
        PALADIN = { { key = "ret", name = "Vergeltung", role = "dps", all = { STR = 2.2, DPS = 14, unit = "AP" } } },
        SHAMAN = { { key = "enh", name = "Verstärkung", role = "dps", all = { STR = 2, DPS = 14, OHDPS = 0.5, unit = "AP" } },
                   { key = "ele", name = "Elementar", role = "dps", all = { SP = 1, unit = "SP" } } },
    },
}
assert(Gear.Available() and Gear.Game() == "tbc" and not Gear.PlannerAvailable(), "the planner is Forever only")
STATS = {
    [6001] = { ITEM_MOD_STRENGTH_SHORT = 30 }, [6002] = { ITEM_MOD_STRENGTH_SHORT = 40 }, [6009] = { ITEM_MOD_STRENGTH_SHORT = 28 },
    [6003] = { ITEM_MOD_STRENGTH_SHORT = 35 }, [6004] = { ITEM_MOD_STRENGTH_SHORT = 20 }, [6008] = { ITEM_MOD_STRENGTH_SHORT = 50 },
    [6005] = { ITEM_MOD_STRENGTH_SHORT = 15 }, [6006] = { ITEM_MOD_STRENGTH_SHORT = 18 }, [6007] = { ITEM_MOD_STRENGTH_SHORT = 20 },
    [6010] = { ITEM_MOD_STRENGTH_SHORT = 33 }, [6011] = { ITEM_MOD_STRENGTH_SHORT = 99 },
    [6012] = { ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 80 },
    [6013] = { ITEM_MOD_STRENGTH_SHORT = 6, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 81 },
    [6014] = { ITEM_MOD_STRENGTH_SHORT = 45 },
}
C_Item.IsItemDataCachedByID = function(id) return STATS[id] ~= nil end
Gear._reset()

-- rows without item type are filled from the client; what cannot be worn is marked once
STUB.items[6010] = { name = "Weltschwert", link = STUB.link(6010, "Weltschwert", 4), quality = 4, equipLoc = "INVTYPE_SHOULDER",
    classID = 4, subclassID = 4, minLevel = 68, ilvl = 113, bind = 2 }
STUB.items[6011] = { name = "Edelstein", link = STUB.link(6011, "Edelstein", 3), quality = 3, equipLoc = "", classID = 3, subclassID = 0 }
local instant = C_Item.GetItemInfoInstant
local asked = 0
C_Item.GetItemInfoInstant = function(x) asked = asked + 1; return instant(x) end
local row = Gear.FillRow(6010)
assert(row[1] == "SHOULDER" and row[2] == 4 and row[3] == 4, "equip location and type from the client")
assert(row[4] == 68 and row[5] == 4 and row[6] == 2 and row[7] == 113, "level, quality, bind and item level once loaded")
row = Gear.FillRow(6011)
assert(not Gear.Usable("WARRIOR", row, 70), "a gem cannot be worn")
local before = asked
Gear.FillRow(6011); Gear.FillRow(6010)
assert(asked == before, "checked once, never again")
C_Item.GetItemInfoInstant = instant

-- source kinds: order, filter keys, text, places
local S = NS.GEAR.S
assert(Gear.KIND_ORDER.X < Gear.KIND_ORDER.Q and Gear.KIND_ORDER.V < Gear.KIND_ORDER.F and Gear.KIND_ORDER.F < Gear.KIND_ORDER.R)
assert(Gear.FilterKey(S[1]) == "X" and Gear.FilterKey(S[3]) == "H" and Gear.FilterKey(S[4]) == "D" and Gear.FilterKey(S[5]) == "F")
assert(Gear.FilterKey({ "R", "Rare", 60, 1 }) == "W" and Gear.FilterKey({ "D", "Deadmines", "VanCleef" }) == "D")
assert(Gear.SourceText(S[1]) == "Karazhan: Prince Malchezaar", Gear.SourceText(S[1]))
assert(Gear.SourceText(S[8]) == "Magtheridon's Lair: Magtheridon (Token)", Gear.SourceText(S[8]))
assert(Gear.SourceText(S[3]) == "Die Zerschmetterten Hallen (heroisch): Warchief Kargath Bladefist", Gear.SourceText(S[3]))
assert(Gear.SourceText(S[4]) == "Die Zerschmetterten Hallen: Warchief Kargath Bladefist", "the client's area name")
assert(Gear.SourceText(S[5]) == "Ruf: Die Sha'tar, respektvoll", Gear.SourceText(S[5]))
assert(Gear.SourceText(S[6]):find("^Ruf: Thrallmar, wohlwollend"), "the source's name without the client's")
assert(Gear.SourceText({ "D", "Deadmines", "VanCleef", "20%" }) == "Deadmines: VanCleef 20%", "old dungeon records")
assert(Gear.PlaceOf(S[1]) == "I:532" and Gear.PlaceOf(S[3]) == "I:540" and Gear.PlaceOf(S[7]) == "Z:111")
assert(Gear.PlaceOf({ "Q", "Q", 20, 18, "A", 1429, 1, 0 }) == "Z:1429" and Gear.PlaceOf({ "R", "Rare", 60, 1412 }) == "Z:1412")
assert(Gear.PlaceOf({ "W", "Wolf", 1, 2, 1429 }) == "Z:1429" and Gear.PlaceOf({ "W", nil, 70, 73, 0 }) == nil)
assert(Gear.PlaceOf({ "D", "Deadmines", "VanCleef" }) == "N:Deadmines", "a dungeon without instance id by its name")
assert(Gear.PlaceOf(S[9]) == nil and Gear.PlaceOf(S[5]) == nil)
assert(Gear.Sources(6009, nil)[1][1] == "X", "a raid source first")

local ALL = { X = true, H = true, D = true, F = true, V = true, C = true, W = true }
local function best(o)
    o.class = o.class or "WARRIOR"
    o.spec = o.spec or "dps"
    o.level = o.level or 70
    o.sources = o.sources or ALL
    return Gear.Best(o)
end
local r = best({ faction = "A" })
assert(r.HEAD[1][1] == 6002 and r.HEAD[2][1] == 6001 and r.HEAD[3][1] == 6009, "raid helms by score")
assert(r.CHEST[1][1] == 6008, "the token's set piece for its class")
assert(r.FINGER1[1][1] == 6005 and not r.FINGER2[1], "the horde reputation ring stays out for the alliance")
r = best({ faction = "H" })
assert(r.FINGER1[1][1] == 6006 and r.FINGER2[1][1] == 6005)
r = best({ class = "PALADIN", spec = "ret" })
assert(r.CHEST[1][1] == 6003, "a warrior's set piece is no paladin's")

-- phase: 0 all, otherwise up to that phase
r = best({ phase = 1 })
assert(r.HEAD[1][1] == 6001 and not r.NECK[1], "phase 2 raid and phase 4 badge gear wait")
r = best({ phase = 4 })
assert(r.HEAD[1][1] == 6002 and r.NECK[1][1] == 6007 and not r.LEGS[1], "the phase 5 heroic waits for phase 5")
r = best({ phase = 5 })
assert(r.LEGS[1][1] == 6014)

-- heroic dungeons have their own switch
r = best({ sources = { X = true, D = true, F = true, V = true } })
assert(r.CHEST[1][1] == 6008 and r.CHEST[2][1] == 6004, "heroic-only chest gone: " .. tostring(r.CHEST[2] and r.CHEST[2][1]))

-- exclusions: an item, a boss, a place; an item with another source stays
r = best({ exclude = { item = { [6002] = true } } })
assert(r.HEAD[1][1] == 6001, "the next helm moves up")
r = best({ exclude = { boss = { ["Prince Malchezaar"] = true } } })
assert(r.HEAD[1][1] == 6002 and r.HEAD[2][1] == 6009 and #r.HEAD == 2, "the boss's own helm goes, the one with a dungeon source stays")
r = best({ exclude = { place = { ["I:532"] = true } } })
assert(r.HEAD[1][1] == 6002 and r.HEAD[2][1] == 6009 and #r.HEAD == 2, "Karazhan excluded")
assert(not Gear.SourceOk(S[1], { sources = ALL, exclude = { place = { ["I:532"] = true } } }))
assert(Gear.SourceOk(S[1], { sources = ALL, exclude = { place = {}, boss = {}, item = {} } }))
assert(not Gear.SourceOk(S[7], { sources = ALL, phase = 3 }) and Gear.SourceOk(S[7], { sources = ALL, phase = 0 }))

r = best({})
assert(r.SHOULDER[1][1] == 6010, "filled rows take part")

-- dual wield: an enhancement shaman in TBC, nobody else new
r = best({ class = "SHAMAN", spec = "enh" })
assert(r.plan == "1H" and r.MAINHAND[1] and r.OFFHAND[1] and r.OFFHAND[1].weapon, "two one-handers for enhancement")
r = best({ class = "SHAMAN", spec = "ele" })
for _, e in ipairs(r.OFFHAND) do assert(not e.weapon, "no off-hand weapon for elemental") end
assert(Gear.CanDualWield("SHAMAN", 70, "enh") and not Gear.CanDualWield("SHAMAN", 70, "ele"))

-- the planner window and its settings stay Forever things
_G.UnitClass = function() return "Krieger", "WARRIOR" end
_G.UnitLevel = function() return 70 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetInventoryItemLink = function() return nil end
STUB.messages = {}
NS.ToggleGearFrame()
assert(not (AmisiaGearFrame and AmisiaGearFrame:IsShown()), "no planner window on TBC data")
assert(STUB.messages[#STUB.messages]:find("nur in WoW Forever", 1, true), STUB.messages[#STUB.messages])
assert(NS.CurrentPage() == "gear", "the gear page instead")
local section = NS.SettingItem("gear.kind").section
assert(not NS.Visible(section), "the planner's settings hide on TBC")

-- Forever data keeps the planner
NS.GEAR.game, NS.GEAR.cap = nil, nil
assert(Gear.PlannerAvailable() and NS.Visible(section))
