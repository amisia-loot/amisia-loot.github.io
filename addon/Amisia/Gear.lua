-- Amisia gear planner: the best item per slot a class can get by a given level, from quests,
-- dungeons, crafting, vendors, rare mobs, world drops and the auction house. GearData.lua lists the
-- items and where they come from (tools/build_gear.py), GearWeights.lua the stat weights per class,
-- spec and level. The stats themselves come from the client, because Forever changed many items.
local ADDON, ns = ...

local Gear = {}
ns.Gear = Gear

-- Level ranges of the overview. An item counts for a range when its level is at most the upper end,
-- and it is scored with the weights of the bracket that upper end lies in.
Gear.COLUMNS = {
    { 1, 9 }, { 10, 14 }, { 15, 19 }, { 20, 24 }, { 25, 29 }, { 30, 34 },
    { 35, 39 }, { 40, 44 }, { 45, 49 }, { 50, 54 }, { 55, 59 }, { 60, 60 },
}

-- Rows of the table. inv is the inventory slot of the equipped item.
Gear.SLOTS = {
    { key = "HEAD", name = "Kopf", inv = 1 },
    { key = "NECK", name = "Hals", inv = 2 },
    { key = "SHOULDER", name = "Schultern", inv = 3 },
    { key = "BACK", name = "Rücken", inv = 15 },
    { key = "CHEST", name = "Brust", inv = 5 },
    { key = "WRIST", name = "Handgelenke", inv = 9 },
    { key = "HANDS", name = "Hände", inv = 10 },
    { key = "WAIST", name = "Taille", inv = 6 },
    { key = "LEGS", name = "Beine", inv = 7 },
    { key = "FEET", name = "Füße", inv = 8 },
    { key = "FINGER1", name = "Finger", inv = 11 },
    { key = "FINGER2", name = "Finger", inv = 12 },
    { key = "TRINKET1", name = "Schmuck", inv = 13 },
    { key = "TRINKET2", name = "Schmuck", inv = 14 },
    { key = "MAINHAND", name = "Waffenhand", inv = 16 },
    { key = "OFFHAND", name = "Schildhand", inv = 17 },
    { key = "RANGED", name = "Distanz", inv = 18 },
}

-- equip location (without INVTYPE_) -> the group of rows it competes for
local GROUP = {
    HEAD = "HEAD", NECK = "NECK", SHOULDER = "SHOULDER", CLOAK = "BACK", CHEST = "CHEST", ROBE = "CHEST",
    WRIST = "WRIST", HAND = "HANDS", WAIST = "WAIST", LEGS = "LEGS", FEET = "FEET", FINGER = "FINGER",
    TRINKET = "TRINKET", ["2HWEAPON"] = "2H", WEAPON = "1H", WEAPONMAINHAND = "MH", WEAPONOFFHAND = "OHW",
    SHIELD = "SHIELD", HOLDABLE = "HELD", RANGED = "RANGED", RANGEDRIGHT = "RANGED", THROWN = "RANGED",
    RELIC = "RANGED",
}
Gear.GROUP = GROUP

-- Who may wear what, from which level (Classic rules: mail for hunters and shamans and plate for
-- warriors and paladins from 40, dual wield for rogues from 10, for warriors and hunters from 20).
-- Armour subclasses: 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield, 7 libram, 8 idol, 9 totem.
local ARMOR = {
    WARRIOR = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    PALADIN = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1, [7] = 1 },
    HUNTER = { [1] = 1, [2] = 1, [3] = 40 },
    ROGUE = { [1] = 1, [2] = 1 },
    PRIEST = { [1] = 1 },
    SHAMAN = { [1] = 1, [2] = 1, [3] = 40, [6] = 1, [9] = 1 },
    MAGE = { [1] = 1 },
    WARLOCK = { [1] = 1 },
    DRUID = { [1] = 1, [2] = 1, [8] = 1 },
}
-- Weapon subclasses: 0 axe, 1 two-hand axe, 2 bow, 3 gun, 4 mace, 5 two-hand mace, 6 polearm, 7 sword,
-- 8 two-hand sword, 10 staff, 13 fist weapon, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local WEAPON = {
    WARRIOR = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    PALADIN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1 },
    HUNTER = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [6] = 1, [7] = 1, [8] = 1, [10] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    ROGUE = { [2] = 1, [3] = 1, [4] = 1, [7] = 1, [13] = 1, [15] = 1, [16] = 1, [18] = 1 },
    PRIEST = { [4] = 1, [10] = 1, [15] = 1, [19] = 1 },
    SHAMAN = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [10] = 1, [13] = 1, [15] = 1 },
    MAGE = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
    WARLOCK = { [7] = 1, [10] = 1, [15] = 1, [19] = 1 },
    DRUID = { [4] = 1, [5] = 1, [10] = 1, [13] = 1, [15] = 1 },
}
local DUAL_WIELD = { ROGUE = 10, WARRIOR = 20, HUNTER = 20 }
local RELIC = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" }
-- Index of the first source number in an item row.
Gear.FIRST_SOURCE = 11
-- Class bits (1 << (classID - 1)), used by class quests and the item rows' class masks
local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
Gear.CLASS_BIT = CLASS_BIT

Gear.CLASS_NAMES = {
    WARRIOR = "Krieger", PALADIN = "Paladin", HUNTER = "Jäger", ROGUE = "Schurke", PRIEST = "Priester",
    SHAMAN = "Schamane", MAGE = "Magier", WARLOCK = "Hexenmeister", DRUID = "Druide",
}

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------

-- C_Item.GetItemStats keys -> scoring keys
local STAT = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_STAMINA_SHORT = "STA",
    ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_SPIRIT_SHORT = "SPI",
    ITEM_MOD_HEALTH_REGEN_SHORT = "HP5", ITEM_MOD_HEALTH_REGENERATION_SHORT = "HP5",
    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_SPELL_POWER_SHORT = "SPP", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SPD", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "HEAL",
    ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "SP_ARCANE", ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "SP_FIRE",
    ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "SP_NATURE", ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "SP_FROST",
    ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "SP_SHADOW", ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "SP_HOLY",
    ITEM_MOD_HIT_RATING_SHORT = "HIT", ITEM_MOD_HIT_MELEE_RATING_SHORT = "MHIT", ITEM_MOD_HIT_RANGED_RATING_SHORT = "MHIT",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "SHIT",
    ITEM_MOD_CRIT_RATING_SHORT = "CRIT", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "MCRIT", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "MCRIT",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "SCRIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE", ITEM_MOD_EXPERTISE_RATING_SHORT = "EXP",
    ITEM_MOD_HASTE_MELEE_RATING_SHORT = "HASTE", ITEM_MOD_HASTE_RANGED_RATING_SHORT = "HASTE",
    ITEM_MOD_HASTE_SPELL_RATING_SHORT = "SHASTE",
    ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_MELEE_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "FAP",
    RESISTANCE0_NAME = "ARMOR", ITEM_MOD_EXTRA_ARMOR_SHORT = "ARMOR",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVAL",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    ITEM_MOD_RESILIENCE_RATING_SHORT = "RES", ITEM_MOD_SPELL_PENETRATION_SHORT = "SPEN",
    EMPTY_SOCKET_RED = "SOCK", EMPTY_SOCKET_YELLOW = "SOCK", EMPTY_SOCKET_BLUE = "SOCK", EMPTY_SOCKET_META = "META",
}
-- Some clients answer GetItemStats without "_SHORT" for ratings and spell power (Classic engines
-- do), so both spellings map to the same key.
do
    local long = {}
    for k, v in pairs(STAT) do
        local plain = k:match("^(.-)_SHORT$")
        if plain then long[plain] = v end
    end
    for k, v in pairs(long) do STAT[k] = STAT[k] or v end
end
Gear.STAT = STAT

-- Rating needed for 1 % (1 skill point for defence) at level 60. Forever's ratings come from TBC:
-- Lionheart Helm's Classic 2 % crit became 28 crit rating. Below 60 a point of rating is worth
-- more, on TBC's curve (level - 8) / 52; Forever ends at 60, so higher levels count as 60.
-- GearWeights.lua carries the values the build used (corrected by in-game measurements once
-- known); these are the defaults without it.
local RATING_60 = { HIT = 10, SHIT = 8, CRIT = 14, HASTE = 10, EXP = 10, DODGE = 12, PARRY = 15, BLOCK = 5, DEF = 1.5 }

local function rating60(kind)
    local r = ns.GEAR_WEIGHTS and ns.GEAR_WEIGHTS.ratings
    return (r and tonumber(r[kind])) or RATING_60[kind]
end

local function ratingPerPoint(kind, level)
    local scale
    if level <= 10 then scale = 2 / 52
    else scale = (math.min(level, 60) - 8) / 52 end
    return 1 / (rating60(kind) * scale)
end
Gear.RatingPerPoint = ratingPerPoint

-- The client's stats of an item (C_Item.GetItemStats), turned into scoring keys, plus the weapon
-- speed and the classes the item is limited to (both only appear in the tooltip).
function Gear.ReadStats(item)
    local link = type(item) == "number" and ("item:" .. item) or item
    local raw = C_Item.GetItemStats(link)
    if not raw then return nil end
    local s = {}
    for k, v in pairs(raw) do
        local key = STAT[k]
        if key and type(v) == "number" and v ~= 0 then s[key] = (s[key] or 0) + v end
    end
    local id = type(item) == "number" and item or ns.ItemID(item)
    local row = id and Gear.Item(id)
    if row then
        -- the generated data knows class limits and weapon speed, which saves a tooltip per item
        if (row[9] or 0) > 0 and s.DPS then s.SPEED = row[9] end
        return s
    end
    local tip = id and C_TooltipInfo and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(id)
    if tip and tip.lines then
        local classesPrefix = ITEM_CLASSES_ALLOWED and ITEM_CLASSES_ALLOWED:match("^(.-)%%s")
        for _, line in ipairs(tip.lines) do
            local right = line.rightText
            if s.DPS and not s.SPEED and type(right) == "string" then
                local num = right:match("(%d+[%.,]%d+)")
                if num then s.SPEED = tonumber((num:gsub(",", "."))) end
            end
            local left = line.leftText
            if classesPrefix and classesPrefix ~= "" and type(left) == "string" and left:sub(1, #classesPrefix) == classesPrefix then
                -- the class names may come coloured
                local names = left:sub(#classesPrefix + 1):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                s.CLASSES = Gear.ParseClasses(names)
            end
        end
    end
    return s
end

-- Stats the item scan saw, as GearData.lua keeps them: "STRENGTH=5;RESISTANCE0_NAME=40" (the client's
-- keys without ITEM_MOD_ and _SHORT; STAT knows the long spelling too).
function Gear.ScannedStats(id)
    local d = ns.GEAR
    local text = d and d.ST and d.ST[id]
    if not text then return nil end
    local s = {}
    for k, v in text:gmatch("([%w_]+)=([^;]+)") do
        local key = STAT["ITEM_MOD_" .. k] or STAT[k]
        v = tonumber(v)
        if key and v and v ~= 0 then s[key] = (s[key] or 0) + v end
    end
    local row = Gear.Item(id)
    if row and (row[9] or 0) > 0 and s.DPS then s.SPEED = row[9] end
    return s
end

-- "Krieger, Paladin" -> { WARRIOR = true, PALADIN = true } with the client's own class names.
local classByName
function Gear.ParseClasses(text)
    if not classByName then
        classByName = {}
        for token, name in pairs(Gear.CLASS_NAMES) do classByName[name] = token end
        for _, list in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE or {}, _G.LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for token, name in pairs(list) do classByName[name] = token end
        end
    end
    local out = {}
    for name in tostring(text):gmatch("[^,]+") do
        name = name:match("^%s*(.-)%s*$")
        if classByName[name] then out[classByName[name]] = true end
    end
    return next(out) and out or nil
end

-- German names of the scored stats, for the explanation of a score.
Gear.STAT_LABELS = {
    STR = "Stärke", AGI = "Beweglichkeit", STA = "Ausdauer", INT = "Intelligenz", SPI = "Willenskraft",
    AP = "Angriffskraft", RAP = "Distanzangriffskraft", FAP = "Angriffskraft (Gestalt)", SPD = "Zauberschaden",
    HEAL = "Heilung", SPP = "Zaubermacht", SP_ARCANE = "Schaden (Arkan)", SP_FIRE = "Schaden (Feuer)",
    SP_NATURE = "Schaden (Natur)", SP_FROST = "Schaden (Frost)", SP_SHADOW = "Schaden (Schatten)", SP_HOLY = "Schaden (Heilig)",
    HIT = "Trefferwertung", HITSP = "Trefferwertung (Zauber)", MHIT = "Trefferwertung", SHIT = "Zaubertrefferwertung", CRIT = "kritische Trefferwertung",
    MCRIT = "kritische Trefferwertung", SCRIT = "Zauberkritwertung", HASTE = "Tempowertung", SHASTE = "Zaubertempowertung", EXP = "Waffenkundewertung",
    DEF = "Verteidigungswertung", DODGE = "Ausweichwertung", PARRY = "Parierwertung", BLOCK = "Blockwertung",
    BLOCKVAL = "Blockwert", ARMOR = "Rüstung", MP5 = "Mana alle 5 Sek.", HP5 = "Gesundheit alle 5 Sek.",
    DPS = "Waffenschaden pro Sekunde", SPEED = "Waffentempo", SOCK = "Sockel", META = "Meta-Sockel",
    RES = "Abhärtungswertung", SPEN = "Zauberdurchschlag", SETB = "Setbonus",
}

-- A number the German way: whole numbers plain, otherwise one decimal with a comma.
local function deNum(x, decimals)
    if not decimals and math.abs(x - math.floor(x + 0.5)) < 0.05 then return tostring(math.floor(x + 0.5)) end
    return (("%." .. (decimals or 1) .. "f"):format(x):gsub("%.", ","))
end
Gear.Num = deNum

-- Every term of a score: add(key, value, weight, rating kind or nil). The score is their sum, so
-- Gear.Score and Gear.ScoreParts can never disagree. tools/build_bis.py has the same function
-- (terms/score); tools/tests/test_score_parity.py holds the two equal.
local function terms(s, w, level, kind, class, add)
    local function W(k) return w[k] or 0 end
    for _, k in ipairs({ "STR", "AGI", "STA", "INT", "SPI", "HP5", "MP5", "AP", "RAP", "ARMOR", "BLOCKVAL" }) do
        add(k, s[k], W(k))
    end
    if class == "DRUID" then add("FAP", s.FAP, W("AP")) end
    -- spell power works for damage and healing; the older stats for one of them
    add("SPP", s.SPP, W("SP") + W("HEAL"))
    add("SPD", s.SPD, W("SP"))
    add("HEAL", s.HEAL, W("HEAL"))
    for _, school in ipairs({ "SP_ARCANE", "SP_FIRE", "SP_NATURE", "SP_FROST", "SP_SHADOW", "SP_HOLY" }) do
        add(school, s[school], W(school))
    end
    -- ratings in percent at this level. Forever's hit, crit and haste work for weapons and spells
    -- alike; the melee and spell kinds count for their own side only. Generic hit is two parts:
    -- the melee part (melee rate, melee room) and the spell part HITSP (spell rate, spell room), so
    -- the hit cap limits a caster's generic hit as much as its spell hit.
    local critW = W("CRIT") + W("SCRIT")
    add("HIT", s.HIT, W("HIT"), "HIT")
    add("HITSP", s.HIT, W("SHIT"), "SHIT")
    add("MHIT", s.MHIT, W("HIT"), "HIT")
    add("SHIT", s.SHIT, W("SHIT"), "SHIT")
    add("CRIT", s.CRIT, critW, "CRIT")
    add("MCRIT", s.MCRIT, W("CRIT"), "CRIT")
    add("SCRIT", s.SCRIT, W("SCRIT"), "CRIT")
    -- without a haste weight four fifths of the crit weight
    local hasteW = w.HASTE or 0.8 * critW
    add("HASTE", s.HASTE, hasteW, "HASTE")
    add("SHASTE", s.SHASTE, hasteW, "HASTE")
    add("EXP", s.EXP, w.EXP or 0.8 * W("HIT"), "EXP")
    add("DODGE", s.DODGE, W("DODGE"), "DODGE")
    add("PARRY", s.PARRY, W("PARRY"), "PARRY")
    add("BLOCK", s.BLOCK, W("BLOCK"), "BLOCK")
    add("DEF", s.DEF, W("DEF"), "DEF")
    -- a gem per socket (a rare gem of the main stat), the meta gem; the socket bonus is not counted
    add("SOCK", s.SOCK, W("GEM"))
    add("META", s.META, W("META"))
    add("RES", s.RES, W("RES"))
    add("SPEN", s.SPEN, W("SPEN"))
    if s.DPS and kind then
        local spd
        if kind == "RANGED" then
            add("DPS", s.DPS, W("RDPS"))
            spd = "SPD_RANGED"
        else
            -- an off-hand weapon hits for half its damage, and wielding two adds a miss chance to
            -- both hands (about a fifth); both land on the off hand, so main hands stay comparable.
            -- OHDPS is that factor (0.25 unless the weights say otherwise).
            add("DPS", s.DPS, W("DPS") * (kind == "OH" and (w.OHDPS or 0.25) or 1))
            spd = "SPD_" .. kind
        end
        -- weapon speed counts in seconds above the slot's reference speed (SPDREF_*)
        if s.SPEED then add("SPEED", s.SPEED - (w["SPDREF_" .. kind] or 0), W(spd)) end
    end
    -- a set's bonus, which the set plan puts on the piece that completes a threshold
    if s.SETB then add("SETB", s.SETB, 1) end
end

-- How much of a rating term counts under the hit cap: cap = { HIT = the melee and ranged hit
-- still useful in percent, SHIT = the spell hit } (nil or a missing side: everything counts). The
-- melee terms (HIT, MHIT) take the melee room, the spell terms (SHIT, HITSP) the spell room.
local function capped(key, converted, cap)
    if not cap then return converted end
    local room
    if key == "HIT" or key == "MHIT" then room = cap.HIT
    elseif key == "SHIT" or key == "HITSP" then room = cap.SHIT end
    if room == nil then return converted end
    return math.max(0, math.min(converted, room))
end
Gear.Capped = capped

-- Score of a stat table for one weight set at one level. kind is the weapon's place: "2H", "MH",
-- "OH" or "RANGED"; nil for everything else. cap (optional): the hit still useful, see capped().
function Gear.Score(s, w, level, kind, class, cap)
    local score = 0
    terms(s, w, level, kind, class, function(key, value, weight, rating)
        if value and value ~= 0 and weight ~= 0 then
            if rating then
                score = score + capped(key, value * ratingPerPoint(rating, level), cap) * weight
            else
                score = score + value * weight
            end
        end
    end)
    return score
end

-- The same score in parts: { { key, label, amount (text), value, weight, points }, ... } with the
-- largest part first and parts without points left out. Ratings show as percent with the rating
-- in brackets ("1,2 % (26)"), defence as skill points; weight is then per percent or point. Hit
-- over the cap is a part of its own with 0 points (over = true), so the parts still sum up.
function Gear.ScoreParts(s, w, level, kind, class, cap)
    local parts = {}
    terms(s, w, level, kind, class, function(key, value, weight, rating)
        if not value or value == 0 or weight == 0 then return end
        local amount, converted = deNum(value), value
        local label = Gear.STAT_LABELS[key] or key
        if rating then
            converted = value * ratingPerPoint(rating, level)
            local counted = capped(key, converted, cap)
            if counted < converted - 1e-9 then
                parts[#parts + 1] = { key = key .. "_OVER", label = label .. " über der Grenze", over = true,
                    amount = ("%s %%"):format(deNum(converted - counted, 1)), value = converted - counted, weight = 0,
                    points = 0 }
                converted = counted
                if converted <= 0 then return end
            end
            if rating == "DEF" then
                amount = ("%s Punkte (%d)"):format(deNum(converted, 1), math.floor(value + 0.5))
            else
                amount = ("%s %% (%d)"):format(deNum(converted, 1), math.floor(value + 0.5))
            end
        elseif key == "SPEED" then
            amount = ("%s s"):format(deNum(s.SPEED, 1))
        end
        parts[#parts + 1] = { key = key, label = label, amount = amount, value = value,
            weight = weight, points = converted * weight }
    end)
    table.sort(parts, function(a, b)
        if a.points ~= b.points then return a.points > b.points end
        return a.key < b.key
    end)
    return parts
end

-- One part as text: "30 Stärke x 2,0 = 60", "Waffentempo 3,6 s: +12", "Setbonus: +18",
-- "0,8 % Trefferwertung über der Grenze: 0".
function Gear.PartText(p)
    if p.over then return ("%s %s: 0"):format(p.amount, p.label) end
    if p.key == "SPEED" then return ("%s %s: %+d"):format(p.label, p.amount, math.floor(p.points + 0.5)) end
    if p.key == "SETB" then return ("%s: %+d"):format(p.label, math.floor(p.points + 0.5)) end
    local wt = p.weight == math.floor(p.weight) and deNum(p.weight, 1)
        or (("%.2f"):format(p.weight):gsub("0$", ""):gsub("%.", ","))
    return ("%s %s x %s = %s"):format(p.amount, p.label, wt, deNum(p.points))
end

-- What one point of score is worth: the weights' unit when it weighs 1, else the first of attack
-- power, spell damage, healing and stamina that does; nil when none fits.
local UNIT_LABELS = { AP = "Angriffskraft", SP = "Zauberschaden", HEAL = "Heilung", STA = "Ausdauer" }
Gear.UNIT_LABELS = UNIT_LABELS
function Gear.Unit(w)
    if not w then return nil end
    if w.unit and UNIT_LABELS[w.unit] and w[w.unit] == 1 then return w.unit end
    for _, k in ipairs({ "AP", "SP", "HEAL", "STA" }) do
        if w[k] == 1 then return k end
    end
    return nil
end

-- "+14 Punkte, so viel wie 14 Angriffskraft", or "+14 Punkte" without a unit.
function Gear.UnitText(points, w)
    local n = math.floor(points + 0.5)
    local unit = Gear.Unit(w)
    if unit then return ("%+d Punkte, so viel wie %d %s"):format(n, n, UNIT_LABELS[unit]) end
    return ("%+d Punkte"):format(n)
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

local function data() return ns.GEAR end
function Gear.Available() return ns.GEAR ~= nil and ns.GEAR_WEIGHTS ~= nil end

-- The level cap of the loaded data set.
function Gear.Cap()
    local d = data()
    return d and d.cap or 60
end

-- The item's row: equip location, class, subclass, level, quality, bind, item level, class mask
-- (0 = every class), weapon speed, profession needed to wear it (Gear.WearProf), sources...
-- A BiS pick GearData.lua does not list has its row in ns.BIS.PI (no sources, plus name).
function Gear.Item(id)
    local d = data()
    local row = d and d.I[id]
    if row then return row end
    local B = ns.BIS
    return d and type(B) == "table" and type(B.PI) == "table" and B.PI[id] or nil
end

-- Whether a class (and spec) can wear the item at a level, by item type alone.
function Gear.Usable(class, row, level, spec)
    local loc, classID, sub = row[1], row[2], row[3]
    local group = GROUP[loc]
    if not group then return false end
    if loc == "RELIC" then return RELIC[sub] == class end
    if classID == 4 then
        if sub == 0 or loc == "CLOAK" or loc == "HOLDABLE" then return true end
        local from = ARMOR[class] and ARMOR[class][sub]
        return from ~= nil and level >= from
    elseif classID == 2 then
        if not (WEAPON[class] and WEAPON[class][sub]) then return false end
        if loc == "WEAPONOFFHAND" then return Gear.CanDualWield(class, level, spec) end
        return true
    end
    return false
end

-- Whether a class dual wields at a level (spec is kept for the callers; no Forever spec adds it).
function Gear.CanDualWield(class, level, spec)
    return DUAL_WIELD[class] ~= nil and level >= DUAL_WIELD[class]
end

-- Professions by the client's skill names (German and English, lower case; Juwelenschleifen is an
-- older German name of jewelcrafting) and their skill line ids,
-- as the Forever client and the data's "profession needed to wear it" field give them.
Gear.PROF_BY_NAME = {
    schneiderei = "tailoring", tailoring = "tailoring", lederverarbeitung = "leatherworking", leatherworking = "leatherworking",
    schmiedekunst = "blacksmithing", blacksmithing = "blacksmithing", ingenieurskunst = "engineering", engineering = "engineering",
    juwelierskunst = "jewelcrafting", juwelenschleifen = "jewelcrafting", jewelcrafting = "jewelcrafting",
    alchimie = "alchemy", alchemy = "alchemy", verzauberkunst = "enchanting", enchanting = "enchanting",
}
Gear.PROF_ID = { tailoring = 197, leatherworking = 165, blacksmithing = 164, engineering = 202, jewelcrafting = 755,
    alchemy = 171, enchanting = 333 }

-- The profession an item needs to be worn: skill line and rank (always 0, any rank), or nil.
-- Field 10 of a row is 0 or the skill line.
function Gear.WearProf(row)
    local p = row and row[10]
    if type(p) == "number" and p > 0 then return p, 0 end
    return nil
end

-- The source record by number: kind first, then fields as described in GearData.lua.
function Gear.Source(n)
    local d = data()
    return d and d.S[n]
end

-- Order sources are listed in: a raid where it is one, then what every character can count on.
local KIND_ORDER = { X = 0, Q = 1, D = 2, C = 3, V = 4, R = 5, W = 6, A = 7, P = 8 }
Gear.KIND_ORDER = KIND_ORDER
-- Filter group per source kind: rare mobs and world drops share one switch (Gear.FilterKey).
Gear.FILTER_OF = { X = "X", Q = "Q", D = "D", C = "C", V = "V", R = "W", W = "W", A = "A", P = "P" }

-- The filter switch a source belongs to.
function Gear.FilterKey(rec)
    local k = rec[1]
    return Gear.FILTER_OF[k] or k
end

local function sourceFaction(rec)
    local k = rec[1]
    local f
    if k == "Q" then f = rec[5]
    elseif k == "V" or k == "P" then f = rec[4] end
    if f == "" then return nil end
    return f
end

-- The place a source is at, for "here" and for excluding a place: "I:<instance id>" for raids and
-- dungeons ("N:<name>" for dungeon records without one), "Z:<zone>" for quests, vendors, rare
-- mobs and world drops with a zone; nil for crafting and the auction house.
function Gear.PlaceOf(rec)
    local k, z = rec[1], nil
    if k == "X" or k == "D" then
        local inst = k == "X" and rec[4] or rec[5]
        -- Forever data built before the game field held a zone there, no instance id
        local d = data()
        if k == "D" and d and not d.game then inst = nil end
        if type(inst) == "number" and inst > 0 then return "I:" .. inst end
        return rec[2] and ("N:" .. rec[2]) or nil
    elseif k == "Q" then z = rec[6]
    elseif k == "V" or k == "P" then z = rec[3]
    elseif k == "R" then z = rec[4]
    elseif k == "W" then z = rec[5] end
    if type(z) == "number" and z ~= 0 then return "Z:" .. z end
    return nil
end

-- Whether one source passes the filters: kind switched on, faction and class fit, and neither its
-- boss nor its place is excluded
-- (opts.exclude = { boss = { [name] = true }, place = { [Gear.PlaceOf key] = true } }). With
-- opts.prof "mine" and the own professions in opts.skills ({ tailoring = 375, ... }), a crafted
-- item that binds on pickup (row given) counts only with that profession and skill.
function Gear.SourceOk(rec, opts, row)
    if not rec then return false end
    if not opts.sources[Gear.FilterKey(rec)] then return false end
    if rec[1] == "C" and row and row[6] == 1 and opts.prof == "mine" and type(opts.skills) == "table" then
        if (opts.skills[rec[2]] or 0) < (rec[3] or 0) then return false end
    end
    local fac = sourceFaction(rec)
    if fac and opts.faction and fac ~= opts.faction then return false end
    if rec[1] == "Q" and (rec[8] or 0) > 0 and opts.class and not Gear.HasClassBit(rec[8], opts.class) then
        return false
    end
    local ex = opts.exclude
    if ex then
        if ex.boss and (rec[1] == "X" or rec[1] == "D") and rec[3] and ex.boss[rec[3]] then return false end
        if ex.place and next(ex.place) then
            local place = Gear.PlaceOf(rec)
            if place and ex.place[place] then return false end
        end
    end
    return true
end

-- Whether a class bit mask includes a class.
function Gear.HasClassBit(mask, class)
    local b = CLASS_BIT[class]
    if not b then return false end
    if bit and bit.band then return bit.band(mask, b) ~= 0 end
    return math.floor(mask / b) % 2 == 1
end

-- The sources of an item that pass the filters, best first.
function Gear.Sources(id, opts)
    local row = Gear.Item(id)
    local out = {}
    if not row then return out end
    for i = Gear.FIRST_SOURCE, #row do
        local rec = Gear.Source(row[i])
        if not opts or Gear.SourceOk(rec, opts, row) then out[#out + 1] = rec end
    end
    table.sort(out, function(a, b)
        local ka, kb = KIND_ORDER[a[1]] or 9, KIND_ORDER[b[1]] or 9
        if ka ~= kb then return ka < kb end
        return tostring(a[2] or "") < tostring(b[2] or "")
    end)
    return out
end

---------------------------------------------------------------------------
-- Loading item data
---------------------------------------------------------------------------

local stats = {}      -- id -> stat table, or false when the client has no data for it
local memo, memoKey = {}, nil   -- id -> scores of the class, spec and weighting in memoKey
local pending = {}    -- id -> { at = time requested, tries = n }
local queue = {}      -- ids still to request
local queued = {}
local ticker
local clock = 0
local REQUESTS_PER_TICK, MAX_PENDING, TIMEOUT, MAX_TRIES = 15, 100, 6, 2
local CACHE_VERSION = "v3"
local arrived = false   -- an answer came by event since the last tick
local listeners = {}

local function now() return GetTime and GetTime() or clock end

local function cacheDB()
    if not AmisiaDB then return nil end
    local d = data()
    local build = (GetBuildInfo and select(2, GetBuildInfo())) or "?"
    -- bump CACHE_VERSION when what is stored per item changes
    local key = CACHE_VERSION .. "/" .. (d and d.built or "?") .. "/" .. tostring(build)
    AmisiaDB.gear = AmisiaDB.gear or {}
    local g = AmisiaDB.gear
    if g.key ~= key then
        g.key, g.stats = key, {}
    end
    g.stats = g.stats or {}
    return g
end

-- Stats are kept between sessions as "KEY=value;..." so a reopened window has them at once.
local function encode(s)
    local parts = {}
    for k, v in pairs(s) do
        if k == "CLASSES" then
            local names = {}
            for token in pairs(v) do names[#names + 1] = token end
            table.sort(names)
            parts[#parts + 1] = "CLASSES=" .. table.concat(names, ",")
        else
            parts[#parts + 1] = k .. "=" .. tostring(v)
        end
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function decode(str)
    local s = {}
    for k, v in tostring(str):gmatch("([%w_]+)=([^;]*)") do
        if k == "CLASSES" then
            s.CLASSES = {}
            for token in v:gmatch("[^,]+") do s.CLASSES[token] = true end
        else
            s[k] = tonumber(v)
        end
    end
    return s
end

local function notify()
    for _, fn in ipairs(listeners) do fn() end
end

function Gear.OnData(fn) listeners[#listeners + 1] = fn end

local function finishItem(id, s)
    stats[id] = s or false
    memo[id] = nil
    if s then
        local g = cacheDB()
        if g then g.stats[id] = encode(s) end
    end
end

local function cached(id)
    if C_Item and C_Item.IsItemDataCachedByID then return C_Item.IsItemDataCachedByID(id) end
    return C_Item.GetItemInfo(id) ~= nil
end

local function tick()
    if not GetTime then clock = clock + 0.1 end
    local t = now()
    local changed = arrived
    arrived = false
    -- answers that arrived without an event, and timeouts
    for id, p in pairs(pending) do
        if cached(id) then
            pending[id] = nil
            finishItem(id, Gear.ReadStats(id))
            changed = true
        elseif t - p.at > TIMEOUT then
            if p.tries < MAX_TRIES then
                p.at, p.tries = t, p.tries + 1
                C_Item.RequestLoadItemDataByID(id)
            else
                pending[id] = nil
                finishItem(id, nil)
                changed = true
            end
        end
    end
    local n, open = 0, 0
    for _ in pairs(pending) do open = open + 1 end
    while #queue > 0 and n < REQUESTS_PER_TICK and open < MAX_PENDING do
        local id = table.remove(queue)
        queued[id] = nil
        if stats[id] == nil and not pending[id] then
            if cached(id) then
                finishItem(id, Gear.ReadStats(id))
                changed = true
            else
                pending[id] = { at = t, tries = 1 }
                C_Item.RequestLoadItemDataByID(id)
                open = open + 1
                n = n + 1
            end
        end
    end
    if changed then notify() end
    if #queue == 0 and not next(pending) and ticker then
        ticker:Cancel()
        ticker = nil
        notify()
    end
end

local function onLoaded(id, success)
    id = tonumber(id)
    if not id or not pending[id] then return end
    pending[id] = nil
    finishItem(id, success ~= false and Gear.ReadStats(id) or nil)
    arrived = true
end
ns.OnEvent("ITEM_DATA_LOAD_RESULT", onLoaded)

-- Stats of an item, or nil while unknown (it is then requested). The second value is true for an
-- item the server never described, which is skipped rather than waited for; the stats the build
-- computed for it (Gear.ComputedStats) still count then.
function Gear.Stats(id)
    local s = stats[id]
    if s == false then return Gear.ComputedStats(id), true end
    if s ~= nil then return s end
    local g = cacheDB()
    if g and g.stats[id] then
        s = decode(g.stats[id])
        stats[id] = s
        return s
    end
    -- what the item scan saw needs no request at all
    s = Gear.ScannedStats(id)
    if s then
        stats[id] = s
        return s
    end
    if not pending[id] and cached(id) then
        finishItem(id, Gear.ReadStats(id))
        return stats[id] or nil
    end
    if not queued[id] and not pending[id] then
        queued[id] = true
        queue[#queue + 1] = id
    end
    if not ticker and C_Timer and C_Timer.NewTicker and C_Item and C_Item.RequestLoadItemDataByID then
        ticker = C_Timer.NewTicker(0.1, tick)
    end
    -- meanwhile the stats the build computed from the client tables, if any (marked SC); the
    -- client's answer replaces them when it comes
    return Gear.ComputedStats(id)
end

-- Stats tools/build_bis.py computed for an item no scan has seen (ns.BIS.SC), marked SC = true;
-- nil without. Weapons and trinkets have none (their damage and equip effects are not in the
-- tables the build reads).
local computedCache, computedFor = {}, nil
function Gear.ComputedStats(id)
    local B = ns.BIS
    local text = type(B) == "table" and type(B.SC) == "table" and B.SC[id]
    if not text then return nil end
    if computedFor ~= B then computedCache, computedFor = {}, B end
    local s = computedCache[id]
    if s then return s end
    s = { SC = true }
    for k, v in tostring(text):gmatch("([%w_]+)=([^;]+)") do
        local key = STAT["ITEM_MOD_" .. k] or STAT[k]
        v = tonumber(v)
        if key and v and v ~= 0 then s[key] = (s[key] or 0) + v end
    end
    computedCache[id] = s
    return s
end

-- The random suffixes seen on an item: { [suffix id] = stat table } from the build (ns.BIS.RP,
-- the guild's collectors) and the own collector (AmisiaDB.scan.suffix); nil when none was seen.
-- Each table holds the item's full stats with that suffix, as C_Item.GetItemStats gave them.
-- Parsed once per item and kept while the build's and the collector's tables of the item stay the
-- same tables; the collector calls Gear.SuffixNoted when it adds a suffix to the item.
local suffixCache = {}   -- id -> { rp = table, own = table, out = result or false }
function Gear.SuffixNoted(id) suffixCache[id] = nil end
function Gear.SuffixStats(id)
    local B = ns.BIS
    local rp = type(B) == "table" and type(B.RP) == "table" and B.RP[id]
    local own = AmisiaDB and type(AmisiaDB.scan) == "table" and type(AmisiaDB.scan.suffix) == "table" and AmisiaDB.scan.suffix[id]
    -- the planner asks for every item: most have none, and that answer costs nothing
    if type(rp) ~= "table" and type(own) ~= "table" then return nil end
    rp = type(rp) == "table" and rp or nil
    own = type(own) == "table" and own or nil
    local c = suffixCache[id]
    if c and c.rp == rp and c.own == own then return c.out or nil end
    local out
    local function addText(suffix, text)
        if type(text) ~= "string" then return end
        local s = {}
        for k, v in text:gmatch("([%w_]+)=([^;]+)") do
            local key = STAT["ITEM_MOD_" .. k] or STAT[k]
            v = tonumber(v)
            if key and v and v ~= 0 then s[key] = (s[key] or 0) + v end
        end
        if next(s) then
            local row = Gear.Item(id)
            if row and (row[9] or 0) > 0 and s.DPS then s.SPEED = row[9] end
            out = out or {}
            out[suffix] = s
        end
    end
    if rp then for suffix, text in pairs(rp) do addText(suffix, text) end end
    if own then for suffix, text in pairs(own) do addText(suffix, text) end end
    suffixCache[id] = { rp = rp, own = own, out = out or false }
    return out
end

-- How many requested items are still on their way.
function Gear.Loading()
    local n = #queue
    for _ in pairs(pending) do n = n + 1 end
    return n
end

-- Test hook: run the loader once without waiting for the ticker.
Gear._tick = tick
function Gear._reset()
    wipe(stats); wipe(pending); wipe(queue); wipe(queued); wipe(suffixCache)
    arrived = false
    memo, memoKey = {}, nil
    if ticker then ticker:Cancel(); ticker = nil end
end

---------------------------------------------------------------------------
-- Picking the best items
---------------------------------------------------------------------------

function Gear.Specs(class)
    local w = ns.GEAR_WEIGHTS
    return w and w.specs[class] or {}
end

function Gear.SpecInfo(class, specKey)
    for _, sp in ipairs(Gear.Specs(class)) do
        if sp.key == specKey then return sp end
    end
    return Gear.Specs(class)[1]
end

-- The weight set of a spec for a level.
function Gear.Weights(class, specKey, kind, level)
    local sp = Gear.SpecInfo(class, specKey)
    if not sp then return nil end
    if sp.all then return sp.all end
    local sets = sp[kind] or sp.Speedrun
    local brackets = ns.GEAR_WEIGHTS.brackets
    for i, upper in ipairs(brackets) do
        if level <= upper then return sets[i] end
    end
    return sets[#sets]
end

-- Scores are kept per class, spec and weighting (memo, declared with the loader), so a redraw only
-- scores items that are new to it.
local PLACE_SLOT = { MH = 1, OH = 2, ["2H"] = 3, RANGED = 4 }
-- slot group -> the row whose worn item a hit cap is reckoned against
local CAP_ROW = { HEAD = "HEAD", NECK = "NECK", SHOULDER = "SHOULDER", BACK = "BACK", CHEST = "CHEST", WRIST = "WRIST",
    HANDS = "HANDS", WAIST = "WAIST", LEGS = "LEGS", FEET = "FEET", FINGER = "FINGER1", TRINKET = "TRINKET1",
    ["2H"] = "MAINHAND", ["1H"] = "MAINHAND", MH = "MAINHAND", OHW = "OFFHAND", SHIELD = "OFFHAND", HELD = "OFFHAND",
    RANGED = "RANGED" }
Gear.CAP_ROW = CAP_ROW

local function hasHit(s) return s.HIT or s.MHIT or s.SHIT end

local function scoreOf(id, s, w, level, place, class, cap)
    -- an item with hit rating under a cap depends on what is worn: never kept
    if cap and hasHit(s) then return Gear.Score(s, w, level, place, class, cap) end
    local byId = memo[id]
    if not byId then byId = {}; memo[id] = byId end
    local k = level * 5 + (place and PLACE_SLOT[place] or 0)
    local v = byId[k]
    if not v then
        v = Gear.Score(s, w, level, place, class)
        byId[k] = v
    end
    return v
end

-- The effort of getting an item from its sources that pass the filters (the cheapest one), in
-- ns.BIS.EF's unit (about one dungeon run = 3); nil without data.
local KIND_EFFORT = { V = "V", C = "C", A = "A", Q = "Q", D = "D", R = "R", W = "W", P = "P", X = "X" }
local function sourceEffort(rec, ef)
    local k = rec[1]
    if k == "D" then
        local v, p = rec[4], nil
        if type(v) == "number" then p = v > 1 and v / 100 or v
        elseif type(v) == "string" then
            local n = tonumber((v:gsub(",", ".")):match("%d+%.?%d*"))
            p = n and n / 100
        end
        p = (p and p > 0) and p or 0.15
        return math.min(ef.DMAX or 30, (ef.D or 3) / p)
    end
    local key = KIND_EFFORT[k]
    return key and ef[key] or nil
end
Gear.SourceEffort = sourceEffort

-- Orders the options within tie percent of the best by effort (cheapest first), the score
-- deciding among equal efforts; an option moved ahead of a better one is marked easier. Scores
-- are never changed.
local function effortOrder(list, tie)
    if not tie or tie <= 0 or #list < 2 then return end
    local top = list[1][2]
    local floor = top - math.abs(top) * tie / 100
    local n = 0
    for i, e in ipairs(list) do
        if e[2] >= floor then n = i else break end
    end
    if n < 2 then return end
    local head = {}
    for i = 1, n do head[i] = list[i] end
    table.sort(head, function(a, b)
        local ea, eb = a.effort or 99, b.effort or 99
        if ea ~= eb then return ea < eb end
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    for i = 1, n do
        local e = head[i]
        list[i] = e
        -- ahead of a better option
        for j = i + 1, n do
            if head[j][2] > e[2] then e.easier = true break end
        end
    end
end

-- The bonus of a set as a stat table per threshold: { [threshold] = stats or false (not scored) }.
local setBonusCache, setBonusFor = {}, nil
local function setBonuses(sid, set)
    local S = type(ns.BIS) == "table" and ns.BIS.SET or nil
    if setBonusFor ~= S then setBonusCache, setBonusFor = {}, S end
    local b = setBonusCache[sid]
    if b then return b end
    b = {}
    for _, pair in ipairs(type(set.b) == "table" and set.b or {}) do
        local thr, text = tonumber(pair[1]), pair[2]
        if thr then
            local s = false
            if type(text) == "string" and text ~= "" then
                s = {}
                for k, v in text:gmatch("([%w_]+)=([^;]+)") do
                    local key = STAT["ITEM_MOD_" .. k] or STAT[k]
                    v = tonumber(v)
                    if key and v and v ~= 0 then s[key] = (s[key] or 0) + v end
                end
            end
            b[thr] = s
        end
    end
    setBonusCache[sid] = b
    return b
end

-- item -> set id, for the sets of ns.BIS.SET.
local setOfItem, setOfFor = {}, nil
function Gear.SetOf(id)
    local B = ns.BIS
    local S = type(B) == "table" and type(B.SET) == "table" and B.SET or nil
    if setOfFor ~= S then
        setOfItem, setOfFor = {}, S
        for sid, set in pairs(S or {}) do
            for _, item in ipairs(type(set.items) == "table" and set.items or {}) do setOfItem[item] = sid end
        end
    end
    return setOfItem[id]
end

local SET_SLOTS = { "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET" }

-- The set plan: for up to two sets with at least two reachable pieces, k pieces of the set plus
-- the best single items elsewhere against the single picks; a set that wins takes its slots, its
-- pieces carry set = { id, name, have, total, bonus } and a share of the bonus (setb, added to
-- their score): each piece its loss against the single best of its slot plus an equal part of
-- the net gain, so the shares sum to the bonus and every piece scores above the single item it
-- displaced. ns.BisCompare counts the share as the part SETB. Linear per set (pieces sorted by
-- their loss).
local function setPlan(res, w, level, class)
    local B = ns.BIS
    local S = type(B) == "table" and type(B.SET) == "table" and B.SET or nil
    if not S then return end
    local used = {}
    for _ = 1, 2 do
        local bestSet
        for sid, set in pairs(S) do
            local bon = setBonuses(sid, set)
            local scored = false
            for _, s in pairs(bon) do if s then scored = true break end end
            if scored then
                -- per free slot the best piece of the set among the options and its loss
                local pieces = {}
                for _, slot in ipairs(SET_SLOTS) do
                    if not used[slot] then
                        local list = res[slot]
                        for i, e in ipairs(list) do
                            if Gear.SetOf(e[1]) == sid then
                                pieces[#pieces + 1] = { slot = slot, i = i, loss = list[1][2] - e[2] }
                                break
                            end
                        end
                    end
                end
                if #pieces >= 2 then
                    table.sort(pieces, function(a, b)
                        if a.loss ~= b.loss then return a.loss < b.loss end
                        return a.slot < b.slot
                    end)
                    local loss, bonus = 0, 0
                    for k = 1, #pieces do
                        loss = loss + pieces[k].loss
                        local s = bon[k]
                        if s then bonus = bonus + Gear.Score(s, w, level, nil, class) end
                        if bon[k] ~= nil and bonus - loss > 0 and (not bestSet or bonus - loss > bestSet.net) then
                            bestSet = { sid = sid, set = set, k = k, net = bonus - loss, bonus = bonus, pieces = pieces }
                        end
                    end
                end
            end
        end
        if not bestSet then return end
        local info = { id = bestSet.sid, name = bestSet.set.name, have = bestSet.k, total = #bestSet.set.items,
            bonus = bestSet.bonus }
        local extra = bestSet.net / bestSet.k
        for k = 1, bestSet.k do
            local p = bestSet.pieces[k]
            local list = res[p.slot]
            local e = table.remove(list, p.i)
            e.set = info
            e.setb = p.loss + extra
            e[2] = e[2] + e.setb
            table.insert(list, 1, e)
            used[p.slot] = true
        end
        res.sets = res.sets or {}
        res.sets[#res.sets + 1] = info
    end
end
Gear.SetPlan = setPlan

-- BiS picks (ns.BIS.PICK, from tools/bis_picks.json): hand-kept items the scoring alone misses
-- (procs, equip effects), each { class, spec, from, to, slot, item, note, src }. The picks of a
-- class, spec and level as { [slotKey] = pick }, for a weapon plan: a two-hand pick in the
-- MAINHAND row only with the plan "auto" or "2H" (it then drops main and off hand picks), a
-- one-hand or off-hand pick only without "2H", an off-hand weapon only without "SHIELD" and a
-- shield or held item only without "DW". Items the class cannot wear at the level and excluded
-- items (exclude.item) are left out; the source filters do not apply (a pick's source may be unknown).
function Gear.PicksFor(class, spec, level, plan, exclude)
    local B = ns.BIS
    local list = type(B) == "table" and type(B.PICK) == "table" and B.PICK or nil
    local out = {}
    if not list or not class then return out end
    plan = plan or "auto"
    local exItem = type(exclude) == "table" and exclude.item or nil
    local two = false
    for _, p in ipairs(list) do
        if type(p) == "table" and p.class == class and p.spec == spec and type(p.from) == "number" and type(p.to) == "number"
            and level >= p.from and level <= p.to and type(p.slot) == "string" and not (exItem and exItem[p.item]) then
            local row = Gear.Item(p.item)
            local group = row and GROUP[row[1]]
            local ok = row and Gear.Usable(class, row, level, spec)
                and not ((row[8] or 0) > 0 and not Gear.HasClassBit(row[8], class))
            if ok and (p.slot == "MAINHAND" or p.slot == "OFFHAND") then
                if group == "2H" then
                    ok = p.slot == "MAINHAND" and (plan == "auto" or plan == "2H")
                    two = two or ok
                elseif plan == "2H" then
                    ok = false
                elseif p.slot == "OFFHAND" then
                    local weapon = group == "1H" or group == "OHW"
                    ok = not ((plan == "SHIELD" and weapon) or (plan == "DW" and not weapon))
                end
            end
            if ok and not out[p.slot] then out[p.slot] = p end
        end
    end
    if two then
        out.OFFHAND = nil
        local mh = out.MAINHAND
        if mh and GROUP[Gear.Item(mh.item)[1]] ~= "2H" then out.MAINHAND = nil end
    end
    return out
end

-- Best items per slot for one level range.
-- opts: class, spec, kind ("Speedrun"/"Hardcore"), faction ("Alliance"/"Horde" short A/H or nil),
-- sources (set of filter keys), level (upper end of the range); optional
-- exclude ({ item = {[id] = true}, boss = {[name] = true}, place = {[Gear.PlaceOf key] = true} }),
-- plan ("auto", "2H", "DW", "SHIELD"; auto picks the larger sum), suffix ("best": an item's best
-- seen random suffix counts, "base": base stats only), sets (false: no set plan), tie (percent
-- within which effort orders the options), cap ({ [row] = { HIT = %, SHIT = % } }: hit still
-- useful per row), picks (false: no BiS picks; else Gear.PicksFor's picks go first in their rows,
-- marked pick = the pick, scored as any option; a two-hand pick makes the plan "auto" two-hand, a
-- main or off-hand pick one-hand).
-- Returns { [slotKey] = { {id, score, effort, suffix, sc, easier, set, pick}, ... best first }, plan =
-- "2H" or "1H", twoHandScore, oneHandScore, dwScore, shieldScore, sets, missing = n, total = n }.
function Gear.Best(opts)
    local d = data()
    local res = { plan = "1H", missing = 0, total = 0 }
    for _, sl in ipairs(Gear.SLOTS) do res[sl.key] = {} end
    if not d then return res end
    local level, class = opts.level, opts.class
    local w = Gear.Weights(class, opts.spec, opts.kind, level)
    if not w then return res end
    local dual = Gear.CanDualWield(class, level, opts.spec)
    local lists = { ["2H"] = {}, MH = {}, OH = {}, FINGER = {}, TRINKET = {} }
    local key = class .. "/" .. tostring(opts.spec) .. "/" .. tostring(opts.kind)
    if key ~= memoKey then memo, memoKey = {}, key end
    local caps = opts.cap
    local useSuffix = opts.suffix ~= "base"
    local B = ns.BIS
    local ef = type(B) == "table" and type(B.EF) == "table" and B.EF or nil
    local function score(id, st, place, group)
        local cap = caps and caps[CAP_ROW[group] or ""]
        local v = scoreOf(id, st, w, level, place, class, cap)
        local suffix
        local variants = useSuffix and Gear.SuffixStats(id)
        if variants then
            -- the best variant (ties: the lowest suffix id), kept with the scores unless a hit cap
            -- makes it depend on what is worn; a new variants table (Gear.SuffixStats) is a new entry
            local byId, k, best = nil, nil, nil
            local keep = not cap
            if cap then
                keep = true
                for _, vs in pairs(variants) do if hasHit(vs) then keep = false break end end
            end
            if keep then
                byId = memo[id]
                if not byId then byId = {}; memo[id] = byId end
                k = -1 - (level * 5 + (place and PLACE_SLOT[place] or 0))
                best = byId[k]
                if best and best.variants ~= variants then best = nil end
            end
            if not best then
                best = { variants = variants }
                for sfx, vs in pairs(variants) do
                    local x = Gear.Score(vs, w, level, place, class, cap)
                    if not best.v or x > best.v or (x == best.v and sfx < best.sfx) then best.v, best.sfx = x, sfx end
                end
                if keep then byId[k] = best end
            end
            if best.v and best.v > v then v, suffix = best.v, best.sfx end
        end
        local e = { id, v, suffix = suffix, sc = st.SC or nil }
        return e
    end
    local exItem = opts.exclude and opts.exclude.item

    for id, row in pairs(d.I) do
        if not (exItem and exItem[id]) and (row[4] or 0) <= level and Gear.Usable(class, row, level, opts.spec) then
            local ok, effort = false, nil
            for i = Gear.FIRST_SOURCE, #row do
                local rec = d.S[row[i]]
                if Gear.SourceOk(rec, opts, row) then
                    ok = true
                    if not ef then break end
                    local x = sourceEffort(rec, ef)
                    if x and (not effort or x < effort) then effort = x end
                end
            end
            if ok and (row[8] or 0) > 0 and not Gear.HasClassBit(row[8], class) then ok = false end
            -- engineering goggles and the like only with their switch, or with the profession
            -- itself when the own skill lines are known (opts.skills by skill line id)
            if ok and not opts.sources.B then
                local line, rank = Gear.WearProf(row)
                local have = line and opts.skills and opts.skills[line]
                if line and not (have and have >= rank) then ok = false end
            end
            if ok then
                res.total = res.total + 1
                local s, failed = Gear.Stats(id)
                if not s then
                    if not failed then res.missing = res.missing + 1 end
                elseif not (s.CLASSES and not s.CLASSES[class]) then
                    local group = GROUP[row[1]]
                    local function put(list, e)
                        e.effort = effort
                        list[#list + 1] = e
                    end
                    if group == "1H" or group == "MH" then
                        put(lists.MH, score(id, s, "MH", group))
                        if group == "1H" and dual then
                            local e = score(id, s, "OH", "OHW")
                            e.weapon = true
                            put(lists.OH, e)
                        end
                    elseif group == "OHW" then
                        local e = score(id, s, "OH", group)
                        e.weapon = true
                        put(lists.OH, e)
                    elseif group == "SHIELD" or group == "HELD" then
                        put(lists.OH, score(id, s, nil, group))
                    elseif group == "2H" then
                        put(lists["2H"], score(id, s, "2H", group))
                    elseif group == "RANGED" then
                        put(res.RANGED, score(id, s, "RANGED", group))
                    elseif group == "FINGER" or group == "TRINKET" then
                        put(lists[group], score(id, s, nil, group))
                    elseif res[group] then
                        put(res[group], score(id, s, nil, group))
                    end
                end
            end
        end
    end

    -- an armour piece or trinket that scores nothing for this spec is no recommendation
    for _, key in ipairs({ "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET" }) do
        local kept = {}
        for _, e in ipairs(res[key]) do if e[2] > 0 then kept[#kept + 1] = e end end
        res[key] = kept
    end
    for _, key in ipairs({ "FINGER", "TRINKET" }) do
        local kept = {}
        for _, e in ipairs(lists[key]) do if e[2] > 0 then kept[#kept + 1] = e end end
        lists[key] = kept
    end

    local function sort(list)
        table.sort(list, function(a, b)
            if a[2] ~= b[2] then return a[2] > b[2] end
            return a[1] < b[1]
        end)
        return list
    end
    for _, sl in ipairs(Gear.SLOTS) do sort(res[sl.key]) end
    for _, list in pairs(lists) do sort(list) end

    -- the set plan works on the best-first lists, before effort reorders a tie
    if opts.sets ~= false then setPlan(res, w, level, class) end
    local tie = tonumber(opts.tie)
    for _, sl in ipairs(Gear.SLOTS) do
        local first = res[sl.key][1]
        if not (first and first.set) then effortOrder(res[sl.key], tie) end
    end
    for _, list in pairs(lists) do effortOrder(list, tie) end

    -- BiS picks: first in their rows (after the set plan and the effort order, which they override)
    local picks = opts.picks ~= false and Gear.PicksFor(class, opts.spec, level, opts.plan, opts.exclude) or {}
    local function front(list, p, place, group)
        for i = #list, 1, -1 do
            if list[i][1] == p.item then table.remove(list, i) end
        end
        local s = Gear.Stats(p.item) or {}
        local e = score(p.item, s, place, group)
        e.pick = p
        if group == "1H" or group == "OHW" then e.weapon = true end
        table.insert(list, 1, e)
    end
    local PICK_LIST = { FINGER1 = lists.FINGER, TRINKET1 = lists.TRINKET }
    local mainPick, offPick
    for slotKey, p in pairs(picks) do
        local row = Gear.Item(p.item)
        local group = GROUP[row[1]]
        if slotKey == "MAINHAND" then
            mainPick = group
            if group == "2H" then front(lists["2H"], p, "2H", group) else front(lists.MH, p, "MH", group) end
        elseif slotKey == "OFFHAND" then
            offPick = true
            front(lists.OH, p, (group == "1H" or group == "OHW") and "OH" or nil, group)
        elseif PICK_LIST[slotKey] then
            front(PICK_LIST[slotKey], p, nil, group)
        elseif slotKey ~= "FINGER2" and slotKey ~= "TRINKET2" and res[slotKey] then
            front(res[slotKey], p, slotKey == "RANGED" and "RANGED" or nil, group)
        end
    end

    -- two rings and two trinkets: the same list, the second row starts after the first pick
    for _, pair in ipairs({ { "FINGER", "FINGER1", "FINGER2" }, { "TRINKET", "TRINKET1", "TRINKET2" } }) do
        local list = lists[pair[1]]
        res[pair[2]] = list
        local second = {}
        for i = 2, #list do second[#second + 1] = list[i] end
        res[pair[3]] = second
        local p = picks[pair[3]]
        if p and not (list[1] and list[1][1] == p.item) then
            front(second, p, nil, GROUP[Gear.Item(p.item)[1]])
        end
    end

    -- weapons: a two-hander against the best main hand plus the best off hand; the plan says which
    -- off hands count (DW: weapons, SHIELD: shields and held items) or forces the two-hander
    local plan = opts.plan or "auto"
    if plan == "DW" and not dual then plan = "auto" end
    local function offList(want)
        local out = {}
        local bestMH = lists.MH[1]
        for _, e in ipairs(lists.OH) do
            if (not bestMH or e[1] ~= bestMH[1]) and (want == nil or (want == "DW") == (e.weapon == true)) then
                out[#out + 1] = e
            end
        end
        return out
    end
    local function sum(oh)
        local bestMH = lists.MH[1]
        if not bestMH and not oh[1] then return nil end
        return (bestMH and bestMH[2] or 0) + (oh[1] and oh[1][2] or 0)
    end
    local best2H = lists["2H"][1]
    local ohAll = offList(nil)
    local oneHand = sum(ohAll)
    res.twoHandScore, res.oneHandScore = best2H and best2H[2] or nil, oneHand
    if dual then res.dwScore = sum(offList("DW")) end
    res.shieldScore = sum(offList("SHIELD"))
    local use2H
    if plan == "2H" then use2H = best2H ~= nil
    elseif plan == "DW" or plan == "SHIELD" then use2H = false
    elseif mainPick == "2H" then use2H = true
    elseif mainPick or offPick then use2H = false
    else use2H = best2H ~= nil and best2H[2] >= (oneHand or 0) end
    res.planWanted = plan
    if use2H then
        res.plan = "2H"
        res.MAINHAND = lists["2H"]
        res.OFFHAND = {}
        res.altMainhand = lists.MH
    else
        res.plan = "1H"
        res.MAINHAND = lists.MH
        res.OFFHAND = (plan == "DW" or plan == "SHIELD") and offList(plan) or ohAll
        res.altMainhand = lists["2H"]
    end
    return res
end

-- Score of an equipped item (or any link) the same way, for the upgrade mark.
function Gear.ScoreLink(link, slotKey, opts)
    if not link then return nil end
    local s = Gear.ReadStats(link)
    if not s then return nil end
    local w = Gear.Weights(opts.class, opts.spec, opts.kind, opts.level)
    if not w then return nil end
    local kind
    local loc = select(4, C_Item.GetItemInfoInstant(link))
    local group = loc and GROUP[(loc:gsub("^INVTYPE_", ""))]
    if slotKey == "MAINHAND" then kind = group == "2H" and "2H" or "MH"
    elseif slotKey == "OFFHAND" then kind = (group == "1H" or group == "OHW") and "OH" or nil
    elseif slotKey == "RANGED" then kind = "RANGED" end
    return Gear.Score(s, w, opts.level, kind, opts.class, opts.cap and opts.cap[slotKey])
end

---------------------------------------------------------------------------
-- Source text
---------------------------------------------------------------------------

Gear.PROFESSIONS = {
    blacksmithing = "Schmiedekunst", leatherworking = "Lederverarbeitung", tailoring = "Schneiderei",
    engineering = "Ingenieurskunst", alchemy = "Alchimie", enchanting = "Verzauberkunst", cooking = "Kochkunst",
    firstaid = "Erste Hilfe", jewelcrafting = "Juwelierskunst",
}
Gear.KIND_NAMES = { X = "Raid", Q = "Quest", D = "Dungeon", C = "Beruf", V = "Händler", R = "Rar", W = "Weltdrop",
    A = "Auktionshaus", P = "PvP-Händler" }

-- The raid's or dungeon's name as the client gives it (C_Map.GetAreaInfo of its area id, localised),
-- else the source's own name.
function Gear.PlaceName(rec)
    local area = rec[1] == "X" and rec[5] or rec[1] == "D" and rec[6] or nil
    if type(area) == "number" and area > 0 and C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(area)
        if type(name) == "string" and name ~= "" then return name end
    end
    return rec[2]
end

function Gear.ZoneName(z)
    if not z then return nil end
    if z > 0 and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(z)
        if info and info.name and info.name ~= "" then return info.name end
    end
    local d = data()
    local name = d and d.Z[z]
    return name ~= "" and name or nil
end

local function questTitle(rec)
    local qid = rec[7]
    if qid and qid > 0 and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(qid)
        if title and title ~= "" then return title end
    end
    return rec[2]
end

local FACTION_TAG = { A = " |cff4a8fe0[A]|r", H = " |cffd04040[H]|r" }

-- One line describing a source; short drops the zone.
function Gear.SourceText(rec, short)
    local k = rec[1]
    if k == "Q" then
        local where = rec[9] or (not short and Gear.ZoneName(rec[6])) or nil
        local lvl = (rec[3] or 0) > 0 and (" (%d)"):format(rec[3]) or ""
        return ("Quest: %s%s%s%s"):format(questTitle(rec), lvl, where and (", " .. where) or "", FACTION_TAG[rec[5]] or "")
    elseif k == "X" then
        return ("%s: %s%s"):format(Gear.PlaceName(rec) or "?", rec[3] or "?", (rec[7] or 0) > 0 and " (Token)" or "")
    elseif k == "D" then
        local chance = rec[4] and (" " .. rec[4]) or ""
        local name = Gear.PlaceName(rec) or "?"
        if rec[3] == "Trash" then return ("%s: Trash%s"):format(name, chance) end
        return ("%s: %s%s"):format(name, rec[3] or "?", chance)
    elseif k == "C" then
        return ("%s (%d)"):format(Gear.PROFESSIONS[rec[2]] or tostring(rec[2]), rec[3] or 0)
    elseif k == "V" or k == "P" then
        local zone = not short and Gear.ZoneName(rec[3]) or nil
        local label = k == "P" and "PvP-Händler" or "Händler"
        return ("%s: %s%s%s"):format(label, rec[2], zone and (", " .. zone) or "", FACTION_TAG[rec[4]] or "")
    elseif k == "R" then
        local zone = not short and Gear.ZoneName(rec[4]) or nil
        return ("Rar: %s%s%s"):format(rec[2] or "?", (rec[3] or 0) > 0 and (" (%d)"):format(rec[3]) or "", zone and (", " .. zone) or "")
    elseif k == "W" then
        if rec[2] then
            local zone = not short and Gear.ZoneName(rec[5]) or nil
            return ("Drop: %s%s"):format(rec[2], zone and (", " .. zone) or "")
        end
        if (rec[3] or 0) > 0 then return ("Weltdrop (Gegner %d-%d)"):format(rec[3], rec[4] or rec[3]) end
        return "Weltdrop"
    elseif k == "A" then
        return "Im Auktionshaus gesehen"
    end
    return tostring(k)
end
