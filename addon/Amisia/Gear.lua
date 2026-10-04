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
-- Questie class bits, used by class quests and the item rows' class masks
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
    ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_MELEE_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "FAP",
    RESISTANCE0_NAME = "ARMOR", ITEM_MOD_EXTRA_ARMOR_SHORT = "ARMOR",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEF", ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY", ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK", ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCKVAL",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
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

-- Rating needed for 1 % (1 skill point for defence) at level 60. Forever uses TBC-style ratings:
-- Lionheart Helm's Classic 2 % crit became 28 crit rating. Below 60 a point of rating is worth
-- more, on TBC's curve.
local RATING_60 = { HIT = 10, SHIT = 8, CRIT = 14, HASTE = 10, EXP = 10, DODGE = 12, PARRY = 15, BLOCK = 5, DEF = 1.5 }

local function ratingPerPoint(kind, level)
    local scale = level <= 10 and (2 / 52) or ((math.min(level, 60) - 8) / 52)
    return 1 / (RATING_60[kind] * scale)
end
Gear.RatingPerPoint = ratingPerPoint

-- The client's stats of an item, turned into scoring keys, plus the weapon speed and the classes the
-- item is limited to (both only appear in the tooltip).
function Gear.ReadStats(item)
    local getStats = C_Item and C_Item.GetItemStats or _G.GetItemStats
    if not getStats then return nil end
    local link = type(item) == "number" and ("item:" .. item) or item
    local raw = getStats(link)
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

-- Score of a stat table for one weight set at one level. kind is the weapon's place: "2H", "MH",
-- "OH" or "RANGED"; nil for everything else.
function Gear.Score(s, w, level, kind, class)
    local function W(k) return w[k] or 0 end
    local score = 0
    score = score + (s.STR or 0) * W("STR") + (s.AGI or 0) * W("AGI") + (s.STA or 0) * W("STA")
        + (s.INT or 0) * W("INT") + (s.SPI or 0) * W("SPI") + (s.HP5 or 0) * W("HP5") + (s.MP5 or 0) * W("MP5")
        + (s.AP or 0) * W("AP") + (s.RAP or 0) * W("RAP") + (s.ARMOR or 0) * W("ARMOR") + (s.BLOCKVAL or 0) * W("BLOCKVAL")
    if class == "DRUID" then score = score + (s.FAP or 0) * W("AP") end
    -- spell power works for damage and healing; the older stats for one of them
    score = score + (s.SPP or 0) * (W("SP") + W("HEAL")) + (s.SPD or 0) * W("SP") + (s.HEAL or 0) * W("HEAL")
    for _, school in ipairs({ "SP_ARCANE", "SP_FIRE", "SP_NATURE", "SP_FROST", "SP_SHADOW", "SP_HOLY" }) do
        if s[school] then score = score + s[school] * W(school) end
    end
    -- ratings in percent at this level; Forever's hit and crit work for weapons and spells alike
    local hitW, critW = W("HIT") + W("SHIT"), W("CRIT") + W("SCRIT")
    local function pct(k, kind2) return (s[k] or 0) * ratingPerPoint(kind2, level) end
    score = score + pct("HIT", "HIT") * hitW + pct("MHIT", "HIT") * W("HIT") + pct("SHIT", "SHIT") * W("SHIT")
    score = score + pct("CRIT", "CRIT") * critW + pct("MCRIT", "CRIT") * W("CRIT") + pct("SCRIT", "CRIT") * W("SCRIT")
    score = score + pct("HASTE", "HASTE") * (w.HASTE or 0.8 * critW)
    score = score + pct("EXP", "EXP") * (w.EXP or 0.8 * W("HIT"))
    score = score + pct("DODGE", "DODGE") * W("DODGE") + pct("PARRY", "PARRY") * W("PARRY") + pct("BLOCK", "BLOCK") * W("BLOCK")
    score = score + pct("DEF", "DEF") * W("DEF")
    if s.DPS and kind then
        if kind == "RANGED" then
            score = score + s.DPS * W("RDPS") + (s.SPEED or 0) * W("SPD_RANGED")
        else
            -- an off-hand weapon hits for half its damage, and wielding two adds a miss chance to
            -- both hands (about a fifth); both land on the off hand, so main hands stay comparable
            score = score + s.DPS * W("DPS") * (kind == "OH" and 0.25 or 1) + (s.SPEED or 0) * W("SPD_" .. kind)
        end
    end
    return score
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

local function data() return ns.GEAR end
function Gear.Available() return ns.GEAR ~= nil and ns.GEAR_WEIGHTS ~= nil end

-- The item's row: equip location, class, subclass, level, quality, bind, item level, class mask
-- (0 = every class), weapon speed, profession needed to wear it (skill line, 0 none), sources...
function Gear.Item(id)
    local d = data()
    return d and d.I[id]
end

-- Whether a class can wear the item at a level, by item type alone.
function Gear.Usable(class, row, level)
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
        if loc == "WEAPONOFFHAND" then return DUAL_WIELD[class] ~= nil and level >= DUAL_WIELD[class] end
        return true
    end
    return false
end

function Gear.CanDualWield(class, level)
    return DUAL_WIELD[class] ~= nil and level >= DUAL_WIELD[class]
end

-- The source record by number: kind first, then fields as described in GearData.lua.
function Gear.Source(n)
    local d = data()
    return d and d.S[n]
end

-- Order sources are listed in: what every character can count on first.
local KIND_ORDER = { Q = 1, D = 2, C = 3, V = 4, R = 5, W = 6, A = 7, P = 8 }
Gear.KIND_ORDER = KIND_ORDER
-- Filter group per source kind: rare mobs and world drops share one switch.
Gear.FILTER_OF = { Q = "Q", D = "D", C = "C", V = "V", R = "W", W = "W", A = "A", P = "P" }

local function sourceFaction(rec)
    local k = rec[1]
    if k == "Q" then return rec[5] end
    if k == "V" or k == "P" then return rec[4] end
    return nil
end

-- Whether one source passes the filters: kind switched on, faction and class fit.
function Gear.SourceOk(rec, opts)
    if not rec then return false end
    if not opts.sources[Gear.FILTER_OF[rec[1]] or rec[1]] then return false end
    local fac = sourceFaction(rec)
    if fac and opts.faction and fac ~= opts.faction then return false end
    if rec[1] == "Q" and (rec[8] or 0) > 0 and opts.class and not Gear.HasClassBit(rec[8], opts.class) then
        return false
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
        if not opts or Gear.SourceOk(rec, opts) then out[#out + 1] = rec end
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
local CACHE_VERSION = "v2"
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
    local getInfo = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
    return getInfo and getInfo(id) ~= nil
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
-- item the server never described, which is skipped rather than waited for.
function Gear.Stats(id)
    local s = stats[id]
    if s ~= nil then return s or nil, s == false end
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
    return nil
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
    wipe(stats); wipe(pending); wipe(queue); wipe(queued)
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

local function scoreOf(id, s, w, level, place, class)
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

-- Best items per slot for one level range.
-- opts: class, spec, kind ("Speedrun"/"Hardcore"), faction ("Alliance"/"Horde" short A/H or nil),
-- sources (set of filter keys), level (upper end of the range).
-- Returns { [slotKey] = { {id, score}, ... best first }, plan = "2H" or "1H", missing = n, total = n }.
function Gear.Best(opts)
    local d = data()
    local res = { plan = "1H", missing = 0, total = 0 }
    for _, sl in ipairs(Gear.SLOTS) do res[sl.key] = {} end
    if not d then return res end
    local level, class = opts.level, opts.class
    local w = Gear.Weights(class, opts.spec, opts.kind, level)
    if not w then return res end
    local dual = Gear.CanDualWield(class, level)
    local lists = { ["2H"] = {}, MH = {}, OH = {}, FINGER = {}, TRINKET = {} }
    local key = class .. "/" .. tostring(opts.spec) .. "/" .. tostring(opts.kind)
    if key ~= memoKey then memo, memoKey = {}, key end
    local function score(id, st, place) return scoreOf(id, st, w, level, place, class) end

    for id, row in pairs(d.I) do
        if (row[4] or 0) <= level and Gear.Usable(class, row, level) then
            local ok = false
            for i = Gear.FIRST_SOURCE, #row do
                if Gear.SourceOk(d.S[row[i]], opts) then ok = true break end
            end
            if ok and (row[8] or 0) > 0 and not Gear.HasClassBit(row[8], class) then ok = false end
            -- engineering goggles and the like only with their switch
            if ok and (row[10] or 0) > 0 and not opts.sources.B then ok = false end
            if ok then
                res.total = res.total + 1
                local s, failed = Gear.Stats(id)
                if not s then
                    if not failed then res.missing = res.missing + 1 end
                elseif not (s.CLASSES and not s.CLASSES[class]) then
                    local group = GROUP[row[1]]
                    if group == "1H" or group == "MH" then
                        lists.MH[#lists.MH + 1] = { id, score(id, s, "MH") }
                        if group == "1H" and dual then
                            lists.OH[#lists.OH + 1] = { id, score(id, s, "OH"), weapon = true }
                        end
                    elseif group == "OHW" then
                        lists.OH[#lists.OH + 1] = { id, score(id, s, "OH"), weapon = true }
                    elseif group == "SHIELD" or group == "HELD" then
                        lists.OH[#lists.OH + 1] = { id, score(id, s, nil) }
                    elseif group == "2H" then
                        lists["2H"][#lists["2H"] + 1] = { id, score(id, s, "2H") }
                    elseif group == "RANGED" then
                        res.RANGED[#res.RANGED + 1] = { id, score(id, s, "RANGED") }
                    elseif group == "FINGER" or group == "TRINKET" then
                        lists[group][#lists[group] + 1] = { id, score(id, s, nil) }
                    elseif res[group] then
                        res[group][#res[group] + 1] = { id, score(id, s, nil) }
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

    -- two rings and two trinkets: the same list, the second row starts after the first pick
    for _, pair in ipairs({ { "FINGER", "FINGER1", "FINGER2" }, { "TRINKET", "TRINKET1", "TRINKET2" } }) do
        local list = lists[pair[1]]
        res[pair[2]] = list
        local second = {}
        for i = 2, #list do second[#second + 1] = list[i] end
        res[pair[3]] = second
    end

    -- weapons: a two-hander against the best main hand plus the best off hand
    local best2H = lists["2H"][1]
    local bestMH = lists.MH[1]
    local bestOH
    for _, e in ipairs(lists.OH) do
        if not bestMH or e[1] ~= bestMH[1] then bestOH = e break end
    end
    local oneHand = (bestMH and bestMH[2] or 0) + (bestOH and bestOH[2] or 0)
    res.twoHandScore, res.oneHandScore = best2H and best2H[2] or nil, (bestMH or bestOH) and oneHand or nil
    if best2H and best2H[2] >= oneHand then
        res.plan = "2H"
        res.MAINHAND = lists["2H"]
        res.OFFHAND = {}
        res.altMainhand = lists.MH
    else
        res.plan = "1H"
        res.MAINHAND = lists.MH
        local oh = {}
        for _, e in ipairs(lists.OH) do
            if not bestMH or e[1] ~= bestMH[1] then oh[#oh + 1] = e end
        end
        res.OFFHAND = oh
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
    local getInstant = C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
    local loc = getInstant and select(4, getInstant(link)) or nil
    local group = loc and GROUP[(loc:gsub("^INVTYPE_", ""))]
    if slotKey == "MAINHAND" then kind = group == "2H" and "2H" or "MH"
    elseif slotKey == "OFFHAND" then kind = (group == "1H" or group == "OHW") and "OH" or nil
    elseif slotKey == "RANGED" then kind = "RANGED" end
    return Gear.Score(s, w, opts.level, kind, opts.class)
end

---------------------------------------------------------------------------
-- Source text
---------------------------------------------------------------------------

Gear.PROFESSIONS = {
    blacksmithing = "Schmiedekunst", leatherworking = "Lederverarbeitung", tailoring = "Schneiderei",
    engineering = "Ingenieurskunst", alchemy = "Alchemie", enchanting = "Verzauberkunst", cooking = "Kochkunst",
    firstaid = "Erste Hilfe", jewelcrafting = "Juwelierskunst",
}
Gear.KIND_NAMES = { Q = "Quest", D = "Dungeon", C = "Beruf", V = "Händler", R = "Rar", W = "Weltdrop", A = "Auktionshaus", P = "PvP-Händler" }

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
    elseif k == "D" then
        local chance = rec[4] and (" " .. rec[4]) or ""
        if rec[3] == "Trash" then return ("%s: Trash%s"):format(rec[2], chance) end
        return ("%s: %s%s"):format(rec[2], rec[3] or "?", chance)
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
