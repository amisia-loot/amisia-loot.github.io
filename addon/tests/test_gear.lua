--[[preload
STUB.toc = 16001
]]
-- The gear planner: generated data, rating conversion, scoring, who may wear what, weapon plans,
-- filters, loading item data and the window. It is a Forever thing, so this runs as the Forever
-- client (on TBC the TBC data set loads instead).
local Gear = NS.Gear
assert(Gear and Gear.Available(), "GearData.lua and GearWeights.lua load")

-- the generated data hangs together
local real = NS.GEAR
local n = 0
for id, row in pairs(real.I) do
    n = n + 1
    assert(Gear.GROUP[row[1]], "known equip location " .. tostring(row[1]) .. " on " .. id)
    assert(#row >= Gear.FIRST_SOURCE, "every item has a source: " .. id)
    assert(type(row[8]) == "number" and type(row[9]) == "number" and type(row[10]) == "number", "class mask, speed, profession on " .. id)
    for i = Gear.FIRST_SOURCE, #row do assert(real.S[row[i]], "source " .. row[i] .. " of " .. id .. " exists") end
end
assert(n > 1000, "thousands of items: " .. n)
for _, token in ipairs(NS.GEAR_WEIGHTS.order) do
    local specs = Gear.Specs(token)
    assert(#specs >= 1, token .. " has specs")
    for _, sp in ipairs(specs) do
        assert(sp.all or (#sp.Speedrun == 6 and #sp.Hardcore == 6), token .. " " .. sp.key .. " has six brackets")
        for _, lvl in ipairs({ 1, 9, 10, 35, 60 }) do
            assert(Gear.Weights(token, sp.key, "Speedrun", lvl), "weights for " .. token .. " " .. sp.key .. " at " .. lvl)
        end
    end
end

-- ratings: 10 hit rating is 1 % at 60, twice as much at 34
local function near(a, b) return math.abs(a - b) < 1e-6 end
assert(near(Gear.RatingPerPoint("HIT", 60) * 10, 1))
assert(near(Gear.RatingPerPoint("HIT", 34) * 10, 2))
assert(near(Gear.RatingPerPoint("CRIT", 60) * 14, 1))

-- scoring
local w = { STR = 2, STA = 1, CRIT = 10, SCRIT = 0, DPS = 14, SPD_2H = 50, SPD_MH = 20, ARMOR = 0.05, HIT = 5, SHIT = 3 }
assert(near(Gear.Score({ STR = 10, STA = 5 }, w, 60), 25))
assert(near(Gear.Score({ CRIT = 14 }, w, 60), 10), "1 % crit")
assert(near(Gear.Score({ HIT = 10 }, w, 60), 8), "Forever hit counts for weapons and spells")
assert(near(Gear.Score({ DPS = 20, SPEED = 3.5 }, w, 60, "2H"), 280 + 175))
assert(near(Gear.Score({ DPS = 20, SPEED = 3.5 }, w, 60), 0), "weapon damage only counts in a weapon place")
assert(near(Gear.Score({ DPS = 20 }, w, 60, "OH"), 70), "an off-hand weapon: half damage, dual-wield misses")
assert(near(Gear.Score({ PARRY = 15 }, { PARRY = 10 }, 60), 10), "15 parry rating is 1 % at 60")
assert(near(Gear.Score({ SHIT = 8 }, { SHIT = 10 }, 60), 10), "8 spell hit rating is 1 % at 60")
assert(near(Gear.Score({ SPP = 10 }, { SP = 1, HEAL = 2 }, 60), 30), "spell power heals and hurts")
assert(near(Gear.Score({ SPD = 10, HEAL = 10 }, { SP = 1, HEAL = 2 }, 60), 30))
assert(near(Gear.Score({ FAP = 100 }, { AP = 1 }, 60, nil, "DRUID"), 100) and Gear.Score({ FAP = 100 }, { AP = 1 }, 60, nil, "ROGUE") == 0)

-- who may wear what
local function row(loc, classID, sub) return { loc, classID, sub, 1, 2, 1, 10, 0, 0, 0, 1 } end
assert(Gear.Usable("WARRIOR", row("CHEST", 4, 4), 40) and not Gear.Usable("WARRIOR", row("CHEST", 4, 4), 39), "plate from 40")
assert(not Gear.Usable("PRIEST", row("CHEST", 4, 2), 60), "priests wear cloth")
assert(Gear.Usable("HUNTER", row("LEGS", 4, 3), 40) and not Gear.Usable("HUNTER", row("LEGS", 4, 3), 30))
assert(Gear.Usable("MAGE", row("CLOAK", 4, 1), 5) and Gear.Usable("ROGUE", row("FINGER", 4, 0), 5))
assert(Gear.Usable("DRUID", row("RELIC", 4, 8), 20) and not Gear.Usable("SHAMAN", row("RELIC", 4, 8), 20))
assert(Gear.Usable("ROGUE", row("WEAPONOFFHAND", 2, 15), 10) and not Gear.Usable("ROGUE", row("WEAPONOFFHAND", 2, 15), 9))
assert(not Gear.Usable("MAGE", row("2HWEAPON", 2, 8), 30) and Gear.Usable("MAGE", row("2HWEAPON", 2, 10), 30))
assert(not Gear.Usable("PALADIN", row("SHIELD", 4, 6), 1) == false)

-- a small world to pick from
NS.GEAR = {
    built = "test",
    S = {
        { "Q", "Helm Quest", 20, 18, "A", nil, 1, 0 },    -- 1 alliance quest
        { "Q", "Horde Helm Quest", 20, 18, "H", nil, 2, 0 }, -- 2 horde quest
        { "D", "Deadmines", "VanCleef", "20%" },             -- 3
        { "C", "blacksmithing", 150 },                       -- 4
        { "A" },                                             -- 5
        { "Q", "Mage Quest", 20, 18, nil, nil, 3, 128 },     -- 6 mages only
        { "P", "Officer", nil, "A" },                        -- 7
    },
    Z = {},
    I = {
        [1001] = { "HEAD", 4, 3, 20, 2, 1, 25, 0, 0, 0, 1 },          -- mail helm, alliance quest
        [1004] = { "HEAD", 4, 4, 20, 4, 1, 25, 0, 0, 0, 1 },          -- plate helm, too early before 40
        [1002] = { "HEAD", 4, 3, 20, 3, 1, 25, 0, 0, 0, 2 },          -- mail helm, horde quest
        [1003] = { "HEAD", 4, 3, 30, 3, 1, 35, 0, 0, 0, 3 },          -- level 30 helm
        [1010] = { "2HWEAPON", 2, 8, 20, 3, 1, 25, 0, 3.5, 0, 3 },      -- two-hand sword
        [1011] = { "WEAPON", 2, 7, 20, 3, 1, 25, 0, 2.4, 0, 4 },        -- one-hand sword
        [1012] = { "SHIELD", 4, 6, 20, 2, 1, 25, 0, 0, 0, 4 },        -- shield
        [1020] = { "FINGER", 4, 0, 10, 2, 2, 15, 0, 0, 0, 5 },        -- rings
        [1021] = { "FINGER", 4, 0, 10, 2, 2, 15, 0, 0, 0, 3 },
        [1022] = { "FINGER", 4, 0, 10, 2, 2, 15, 0, 0, 0, 3 },
        [1030] = { "CHEST", 4, 1, 15, 2, 1, 20, 0, 0, 0, 6 },         -- mage quest robe
        [1031] = { "CHEST", 4, 3, 15, 2, 1, 20, 2, 0, 0, 4 },         -- paladins only (class mask)
        [1040] = { "LEGS", 4, 3, 15, 4, 1, 60, 0, 0, 0, 7 },          -- pvp
    },
}
local STATS = {
    [1001] = { ITEM_MOD_STRENGTH_SHORT = 8, RESISTANCE0_NAME = 300 },
    [1002] = { ITEM_MOD_STRENGTH_SHORT = 12, RESISTANCE0_NAME = 200 },
    [1003] = { ITEM_MOD_STRENGTH_SHORT = 30 },
    [1004] = { ITEM_MOD_STRENGTH_SHORT = 90 },
    [1010] = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 20 },
    [1011] = { ITEM_MOD_STRENGTH_SHORT = 4, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 },
    [1012] = { ITEM_MOD_STAMINA_SHORT = 3, RESISTANCE0_NAME = 600 },
    [1020] = { ITEM_MOD_STRENGTH_SHORT = 5 },
    [1021] = { ITEM_MOD_STRENGTH_SHORT = 7 },
    [1022] = { ITEM_MOD_STRENGTH_SHORT = 2 },
    [1030] = { ITEM_MOD_INTELLECT_SHORT = 9 },
    [1031] = { ITEM_MOD_STRENGTH_SHORT = 50 },
    [1040] = { ITEM_MOD_STRENGTH_SHORT = 99 },
}
local CACHED = {}
for id in pairs(STATS) do CACHED[id] = true end
C_Item.GetItemStats = function(link)
    local id = tonumber(tostring(link):match("item:(%d+)"))
    return id and CACHED[id] and STATS[id] or nil
end
C_Item.IsItemDataCachedByID = function(id) return CACHED[id] == true end
_G.ITEM_CLASSES_ALLOWED = "Klassen: %s"
_G.C_TooltipInfo = {
    GetItemByID = function(id)
        if id == 1010 then return { lines = { { leftText = "Zweihand" }, { leftText = "30 - 50 Schaden", rightText = "Tempo 3,50" } } } end
        if id == 1011 then return { lines = { { leftText = "13 - 26 Schaden", rightText = "Tempo 2,40" } } } end
        if id == 2000 then return { lines = { { leftText = "13 - 26 Schaden", rightText = "Tempo 2,40" }, { leftText = "Klassen: |cfff48cbaPaladin|r, Krieger" } } } end
        return { lines = {} }
    end,
}
Gear._reset()

local s = Gear.ReadStats(1010)
assert(s.STR == 10 and s.DPS == 20 and s.SPEED == 3.5, "speed from the data row")
-- an item outside the data (an equipped one, say) takes speed and classes from the tooltip
STATS[2000] = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 }
CACHED[2000] = true
s = Gear.ReadStats(2000)
assert(s.SPEED == 2.4, "German decimal comma")
assert(s.CLASSES.PALADIN and s.CLASSES.WARRIOR and not s.CLASSES.MAGE, "coloured class names")
-- a client that answers without _SHORT
STATS[2001] = { ITEM_MOD_HIT_RATING = 10, ITEM_MOD_SPELL_POWER = 7, ITEM_MOD_STRENGTH_SHORT = 1 }
CACHED[2001] = true
s = Gear.ReadStats(2001)
assert(s.HIT == 10 and s.SPP == 7 and s.STR == 1, "both spellings of stat names")

local all = { Q = true, D = true, C = true, V = true, W = true, A = true, P = false }
local function best(o)
    o.spec = o.spec or "dps"
    o.kind = o.kind or "Speedrun"
    o.sources = o.sources or all
    return Gear.Best(o)
end

local r = best({ class = "WARRIOR", level = 24, faction = "A" })
assert(r.HEAD[1][1] == 1001, "plate waits for 40, the horde helm is filtered: " .. tostring(r.HEAD[1] and r.HEAD[1][1]))
assert(#r.HEAD == 1, "the level 30 helm waits for its level")
r = best({ class = "WARRIOR", level = 24, faction = "H" })
assert(r.HEAD[1][1] == 1002)
r = best({ class = "WARRIOR", level = 24, faction = nil })
assert(r.HEAD[1][1] == 1002 and r.HEAD[2][1] == 1001, "both factions, stronger first")
r = best({ class = "WARRIOR", level = 34, faction = "A" })
assert(r.HEAD[1][1] == 1003)

-- rings: two different ones, the best first
r = best({ class = "WARRIOR", level = 24 })
assert(r.FINGER1[1][1] == 1021 and r.FINGER2[1][1] == 1020, "two rings")
-- the auction house switch hides the ring only seen there
r = best({ class = "WARRIOR", level = 24, sources = { Q = true, D = true, C = true, V = true, W = true, A = false } })
assert(r.FINGER1[1][1] == 1021 and r.FINGER2[1][1] == 1022)

-- weapons: a warrior's dps weights take the slow two-hander over sword and shield
r = best({ class = "WARRIOR", level = 24 })
assert(r.plan == "2H" and r.MAINHAND[1][1] == 1010 and #r.OFFHAND == 0, "two-hander: " .. r.plan)
-- a protection warrior's weights love the shield's armour
r = best({ class = "WARRIOR", spec = "tank", level = 24 })
assert(r.plan == "1H" and r.MAINHAND[1][1] == 1011 and r.OFFHAND[1][1] == 1012, "sword and board: " .. r.plan)

-- class quests and class-limited items
r = best({ class = "MAGE", level = 24, spec = "frost" })
assert(r.CHEST[1] and r.CHEST[1][1] == 1030, "the mage quest robe")
r = best({ class = "PRIEST", level = 24, spec = "shadow" })
assert(not r.CHEST[1], "a priest does not get the mage quest")
r = best({ class = "WARRIOR", level = 24 })
for _, e in ipairs(r.CHEST) do assert(e[1] ~= 1031, "the paladin-only chest stays out") end
r = best({ class = "PALADIN", spec = "ret", level = 24 })
assert(r.CHEST[1][1] == 1031)

-- PvP rank gear only with its switch
r = best({ class = "WARRIOR", level = 24 })
assert(not r.LEGS[1])
r = best({ class = "WARRIOR", level = 24, sources = { Q = true, P = true } })
assert(r.LEGS[1][1] == 1040)

-- loading: an unknown item is requested, counted as missing, and scored once it arrives
STATS[1050] = { ITEM_MOD_STRENGTH_SHORT = 40 }
NS.GEAR.I[1050] = { "HEAD", 4, 1, 20, 2, 1, 25, 0, 0, 0, 3 }
STUB.requested = {}
r = best({ class = "WARRIOR", level = 24 })
assert(r.missing == 1 and r.HEAD[1][1] ~= 1050)
STUB.tick(0.1)
assert(STUB.requested[1] == 1050, "requested from the server")
CACHED[1050] = true
STUB.fire("ITEM_DATA_LOAD_RESULT", 1050, true)
r = best({ class = "WARRIOR", level = 24 })
assert(r.missing == 0 and r.HEAD[1][1] == 1050)
assert(AmisiaDB.gear.stats[1050] == "STR=40", "kept for the next session: " .. tostring(AmisiaDB.gear.stats[1050]))
STATS[1052] = { ITEM_MOD_MANA_REGENERATION_SHORT = 6, ITEM_MOD_HEALTH_REGEN_SHORT = 4, ITEM_MOD_STAMINA_SHORT = 3 }
CACHED[1052] = true
NS.GEAR.I[1052] = { "HEAD", 4, 1, 20, 2, 1, 25, 0, 0, 0, 3 }
assert(Gear.Stats(1052).MP5 == 6)
-- a new session reads the kept stats without asking the server
Gear._reset()
CACHED[1050] = nil
STUB.requested = {}
r = best({ class = "WARRIOR", level = 24 })
assert(r.HEAD[1][1] == 1050 and #STUB.requested == 0)
CACHED[1052] = nil
local kept = Gear.Stats(1052)
assert(kept and kept.MP5 == 6 and kept.HP5 == 4 and kept.STA == 3, "HP5 and MP5 survive the saved cache")
-- an item the server never answers stops being asked after two tries
NS.GEAR.I[1051] = { "HEAD", 4, 1, 20, 2, 1, 25, 0, 0, 0, 3 }
best({ class = "WARRIOR", level = 24 })
for _ = 1, 200 do STUB.tick(0.1) end
assert(Gear.Loading() == 0, "loader gives up")
r = best({ class = "WARRIOR", level = 24 })
assert(r.missing == 0)

-- source text
assert(Gear.SourceText(NS.GEAR.S[1]):find("Quest: Helm Quest (20)", 1, true))
assert(Gear.SourceText(NS.GEAR.S[3]) == "Deadmines: VanCleef 20%")
assert(Gear.SourceText(NS.GEAR.S[4]) == "Schmiedekunst (150)")
assert(Gear.SourceText({ "W", nil, 20, 30 }) == "Weltdrop (Gegner 20-30)")

-- the window opens, switches views and classes without errors
_G.UnitClass = function() return "Krieger", "WARRIOR" end
_G.UnitLevel = function() return 24 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetInventoryItemLink = function(_, slot) if slot == 1 then return STUB.link(1001, "Helm", 2) end end
_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
STUB.item(1001, "Helm", 2)
NS.ToggleGearFrame()
assert(AmisiaGearFrame and AmisiaGearFrame:IsShown())
assert(AmisiaDB.settings.gear.class == "WARRIOR" and AmisiaDB.settings.gear.col == 4, "starts on the player's class and range")
AmisiaDB.settings.gear.view = "list"
NS.GearRefresh(true)
AmisiaDB.settings.gear.class = "MAGE"
NS.GearRefresh(true)
AmisiaDB.settings.gear.view = "overview"
NS.GearRefresh(true)
SlashCmdList.AMISIA("gear")
assert(not AmisiaGearFrame:IsShown(), "the slash command toggles it")
SlashCmdList.AMISIA("gear item item:1010")
assert(STUB.messages[#STUB.messages]:find("Wertung", 1, true), STUB.messages[#STUB.messages])
assert(STUB.messages[#STUB.messages - 1]:find("Client: ITEM_MOD_DAMAGE_PER_SECOND_SHORT=20", 1, true), STUB.messages[#STUB.messages - 1])

-- stats the item scan saw are used without asking the client
Gear._reset()
NS.GEAR.I[3000] = { "2HWEAPON", 2, 8, 20, 3, 1, 25, 0, 3.6, 0, 3 }
NS.GEAR.ST = { [3000] = "STRENGTH=12;DAMAGE_PER_SECOND_SHORT=21.5;HIT_RATING=10" }
STUB.requested = {}
local scanned = Gear.Stats(3000)
assert(scanned and scanned.STR == 12 and scanned.DPS == 21.5 and scanned.HIT == 10 and scanned.SPEED == 3.6, "scanned stats with speed")
STUB.tick(0.2)
assert(#STUB.requested == 0, "no request for a scanned item")
NS.GEAR.ST = nil

-- the player's own column plans for the player's level, not the column's upper end
_G.UnitClass = function() return "Krieger", "WARRIOR" end
_G.UnitLevel = function() return 13 end
assert(Gear.ColumnLevel(Gear.ColumnOf(13), "WARRIOR") == 13, "own column capped at own level")
assert(Gear.ColumnLevel(Gear.ColumnOf(13), "MAGE") == 14, "another class keeps the upper end")
assert(Gear.ColumnLevel(Gear.ColumnOf(20), "WARRIOR") == 24, "other columns keep the upper end")
_G.UnitLevel = function() return 14 end
assert(Gear.ColumnLevel(Gear.ColumnOf(14), "WARRIOR") == 14)
