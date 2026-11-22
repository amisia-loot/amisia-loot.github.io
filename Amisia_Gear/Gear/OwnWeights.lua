-- Own weights (F-230, D-161, spec docs/specs/2026-11-22-eigene-gewichte.md): per class and spec any number of
-- named sets (at most 20), one of them chosen, for every character of the class on the account
-- (AmisiaDB.weights = { [class] = { [specKey] = { pick = name, sets = { [name] = { [key] = weight per point } } } } },
-- the keys Gear.OWN_KEYS). The weighting "Eigene" (bis.kind) scores with the chosen set: Gear.Weights converts
-- it (Gear.PointWeights), linear, without the upgrade model, the hit cap still counts. A set comes from typing,
-- from a pasted text (OW.Parse: "Name=Zahl" lists, or the bracketed weights line simulations and guides offer for
-- copying), from a template of the simulation (GEAR_WEIGHTS.SIM, "<Name> (Sim)") or from Amisia's own numbers.
-- Pasted text is untrusted (D-26): at most 4000 characters read, 40 values, numbers only as digits with one
-- decimal mark, -10 .. 100, names without colour codes and control characters, 32 characters; nothing runs.
-- Nothing is sent: a set is shared by copying its line (OW.Export).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local Gear = ns.Gear

local OW = {}
ns.OwnWeights = OW

local MAX_TEXT, MAX_VALUES, MIN, MAX, MAX_SETS, MAX_NAME = 4000, 40, -10, 100, 20, 32
OW.MAX_TEXT, OW.MAX_VALUES, OW.MIN, OW.MAX, OW.MAX_SETS, OW.MAX_NAME = MAX_TEXT, MAX_VALUES, MIN, MAX, MAX_SETS, MAX_NAME
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true,
    WARLOCK = true, DRUID = true }
-- the class in the copied line (English, as the line is read elsewhere)
local CLASS_WORD = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }

---------------------------------------------------------------------------
-- Names and numbers
---------------------------------------------------------------------------

-- The first n characters of a UTF-8 text.
local function cutChars(s, n)
    local out, count = {}, 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > n then break end
        out[count] = ch
    end
    return table.concat(out)
end

-- A set's name from any text: no colour codes, textures, links or other escape sequences, no control
-- characters, no quotes (the copied line keeps the name in them), spaces folded, at most 32 characters; nil
-- when nothing is left.
function OW.CleanName(s, n)
    if type(s) ~= "string" then return nil end
    s = s:sub(1, 400)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|", "")
    s = s:gsub("%c", " "):gsub("\"", ""):gsub("%s+", " ")
    s = s:match("^%s*(.-)%s*$")
    s = cutChars(s, n or MAX_NAME):match("^(.-)%s*$")
    return s ~= "" and s or nil
end

local function round4(v) return math.floor(v * 10000 + 0.5) / 10000 end

-- A weight per point as kept: a finite number from -10 to 100, rounded to 4 decimals; nil otherwise.
function OW.CleanValue(v)
    v = tonumber(v)
    if not v or v ~= v or v < MIN or v > MAX then return nil end
    return round4(v)
end

-- A number as the fields show it: up to 4 decimals, "0,24" in German.
function OW.NumText(v)
    if type(v) ~= "number" then return "" end
    local s = ("%.4f"):format(v):gsub("0+$", ""):gsub("%.$", "")
    if s == "-0" then s = "0" end
    if ns.GERMAN then s = s:gsub("%.", ",") end
    return s
end

-- A typed number: digits with at most one decimal mark (comma or point), an optional sign; "" is 0. Returns
-- the number (nil for empty) or false, the reason.
function OW.ReadNumber(text)
    text = tostring(text or ""):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    if not (text:match("^[%+%-]?%d+$") or text:match("^[%+%-]?%d*[%.,]%d+$")) then
        return false, L["Nur Ziffern mit höchstens einem Komma."]
    end
    local v = tonumber((text:gsub(",", ".")))
    if not v or v < MIN or v > MAX then return false, L["Erlaubt sind -10 bis 100."] end
    return round4(v)
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------

local function cleanSet(set)
    if type(set) ~= "table" then return nil end
    local out, n = {}, 0
    for _, k in ipairs(Gear.OWN_KEYS) do
        local v = OW.CleanValue(set[k])
        if v and v ~= 0 and n < MAX_VALUES then
            out[k] = v
            n = n + 1
        end
    end
    return out
end

local function byName(a, b)
    local la, lb = a:lower(), b:lower()
    if la ~= lb then return la < lb end
    return a < b
end

-- Called with the saved data (and whenever the table is read first): the shape of AmisiaDB.weights, checked
-- entries (known classes, spec keys of letters, names as OW.CleanName leaves them, at most 20 sets, known keys
-- with numbers from -10 to 100), a pick that names a set; empty parts fall away. Running it twice changes
-- nothing.
function OW.Migrate(root)
    local t = root.weights
    if type(t) ~= "table" then
        root.weights = nil
        return nil
    end
    for class, specs in pairs(t) do
        if not CLASSES[class] or type(specs) ~= "table" then
            t[class] = nil
        else
            for spec, e in pairs(specs) do
                if type(spec) ~= "string" or not spec:match("^[%w_]+$") or #spec > 16 or type(e) ~= "table" then
                    specs[spec] = nil
                else
                    local names = {}
                    if type(e.sets) == "table" then
                        for name in pairs(e.sets) do
                            if type(name) == "string" and OW.CleanName(name) == name then names[#names + 1] = name end
                        end
                    end
                    table.sort(names, byName)
                    local sets = {}
                    for i = 1, math.min(#names, MAX_SETS) do sets[names[i]] = cleanSet(e.sets[names[i]]) end
                    local pick = type(e.pick) == "string" and sets[e.pick] and e.pick or nil
                    for k in pairs(e) do e[k] = nil end
                    if next(sets) then
                        e.sets, e.pick = sets, pick
                    else
                        specs[spec] = nil
                    end
                end
            end
            if not next(specs) then t[class] = nil end
        end
    end
    if not next(t) then root.weights = nil end
    return root.weights
end

local migrated
local function db(make)
    if not AmisiaDB then return nil end
    if migrated ~= AmisiaDB then
        migrated = AmisiaDB
        OW.Migrate(AmisiaDB)
    end
    if make and type(AmisiaDB.weights) ~= "table" then AmisiaDB.weights = {} end
    return AmisiaDB.weights
end

local function entry(class, spec, make)
    local t = db(make)
    if not t or not class or not spec then return nil end
    local c = t[class]
    if not c then
        if not make then return nil end
        c = {}
        t[class] = c
    end
    local e = c[spec]
    if not e then
        if not make then return nil end
        e = { sets = {} }
        c[spec] = e
    end
    return e
end

-- An entry left empty goes, and with it an empty class.
local function tidy(class, spec)
    local t = db()
    local c = t and t[class]
    if c and c[spec] and not next(c[spec].sets) then c[spec] = nil end
    if c and not next(c) then t[class] = nil end
    if t and not next(t) then AmisiaDB.weights = nil end
end

-- The chosen set of a spec (Gear.OwnPick, Gear.Weights with "Eigene"): name, set; nil without one.
Gear.OwnSource = function(class, spec)
    local e = entry(class, spec)
    local set = e and e.pick and e.sets[e.pick]
    if set then return e.pick, set end
    return nil
end

-- Every change: the scores again (Gear's memo), the results (BIS_CHANGED), the open windows.
local function changed()
    Gear.OwnChanged()
    ns.Fire("BIS_CHANGED", "weights")
    if ns.GearRefresh then pcall(ns.GearRefresh, true) end
end
OW.Changed = changed

-- The names of a spec's sets, sorted; the chosen one; a set; how many.
function OW.Names(class, spec)
    local e = entry(class, spec)
    local out = {}
    if e then for name in pairs(e.sets) do out[#out + 1] = name end end
    table.sort(out, byName)
    return out
end
function OW.Pick(class, spec)
    local e = entry(class, spec)
    return e and e.pick or nil
end
function OW.Get(class, spec, name)
    local e = entry(class, spec)
    return e and name and e.sets[name] or nil
end
function OW.Count(class, spec) return #OW.Names(class, spec) end

-- Whether every weight of a set is 0 (or the set is empty).
function OW.AllZero(set)
    if type(set) ~= "table" then return true end
    for _, v in pairs(set) do
        if type(v) == "number" and v ~= 0 then return false end
    end
    return true
end

-- A name not yet taken: base, else "base 2", "base 3", ...
function OW.FreeName(class, spec, base)
    base = OW.CleanName(base) or L["Neuer Satz"]
    if not OW.Get(class, spec, base) then return base end
    for i = 2, MAX_SETS + 1 do
        local suffix = " " .. i
        local name = (OW.CleanName(base, MAX_NAME - #suffix) or "") .. suffix
        if not OW.Get(class, spec, name) then return name end
    end
    return nil
end

-- The weighting "Eigene" for the own character, when the set belongs to its spec.
local function own(class, spec)
    local o = ns.BisOpts and ns.BisOpts()
    return o and o.class == class and o.spec == spec
end

-- Saves a set (a new one, or replace = true: one of that name replaced). pick: it becomes the chosen set and
-- the own weighting "Eigene". Returns the name, or nil and the reason.
function OW.Save(class, spec, name, values, opts)
    opts = opts or {}
    name = OW.CleanName(name)
    if not (class and spec) then return nil, L["Keine Spezialisierung."] end
    if not name then return nil, L["Der Satz braucht einen Namen."] end
    local e = entry(class, spec, true)
    if e.sets[name] and not opts.replace then return nil, L["Einen Satz \"%s\" gibt es schon."]:format(name) end
    if not e.sets[name] and OW.Count(class, spec) >= MAX_SETS then
        tidy(class, spec)
        return nil, L["Höchstens %d Sätze je Spezialisierung."]:format(MAX_SETS)
    end
    e.sets[name] = cleanSet(values) or {}
    if opts.pick then
        e.pick = name
        if own(class, spec) and ns.Get("bis.kind") ~= "Eigene" then ns.Set("bis.kind", "Eigene") end   -- l10n-ok: setting key
    end
    changed()
    return name
end

-- Makes a set the chosen one, and "Eigene" the own weighting.
function OW.Choose(class, spec, name)
    local e = entry(class, spec)
    if not (e and e.sets[name]) then return false end
    e.pick = name
    if own(class, spec) and ns.Get("bis.kind") ~= "Eigene" then ns.Set("bis.kind", "Eigene") end   -- l10n-ok: setting key
    changed()
    return true
end

-- Renames a set (the choice follows). Returns the new name, or nil and the reason.
function OW.Rename(class, spec, old, new)
    local e = entry(class, spec)
    if not (e and e.sets[old]) then return nil, L["Diesen Satz gibt es nicht mehr."] end
    new = OW.CleanName(new)
    if not new then return nil, L["Der Satz braucht einen Namen."] end
    if new == old then return new end
    if e.sets[new] then return nil, L["Einen Satz \"%s\" gibt es schon."]:format(new) end
    e.sets[new], e.sets[old] = e.sets[old], nil
    if e.pick == old then e.pick = new end
    changed()
    return new
end

-- Deletes a set. The chosen one gone: no choice; the own weighting "Eigene" falls back to Speedrun with a chat line.
function OW.Delete(class, spec, name)
    local e = entry(class, spec)
    if not (e and e.sets[name]) then return false end
    e.sets[name] = nil
    local wasPick = e.pick == name
    if wasPick then e.pick = nil end
    tidy(class, spec)
    if wasPick and own(class, spec) and ns.Get("bis.kind") == "Eigene" then   -- l10n-ok: setting key
        ns.Set("bis.kind", "Speedrun")   -- l10n-ok: setting key
        ns.msg(L["Der gewählte Satz \"%s\" ist gelöscht: die Gewichtung steht wieder auf Speedrun."]:format(name))
    end
    changed()
    return true
end

-- One weight of a set (nil or 0: the field is empty). Returns true, or false and the reason.
function OW.SetValue(class, spec, name, key, v)
    local set = OW.Get(class, spec, name)
    if not set then return false, L["Diesen Satz gibt es nicht mehr."] end
    if not Gear.OWN_KEY[key] then return false, "?" end
    if v ~= nil then
        v = OW.CleanValue(v)
        if not v then return false, L["Erlaubt sind -10 bis 100."] end
    end
    if v == 0 then v = nil end
    if set[key] == v then return true end
    set[key] = v
    changed()
    return true
end

-- The templates of a class (GEAR_WEIGHTS.SIM: { { name, spec = specKey or nil, w = { [key] = per point } } });
-- nil when the data has none (an older data file).
function OW.Templates(class)
    local G = ns.GEAR_WEIGHTS
    local sim = type(G) == "table" and type(G.SIM) == "table" and G.SIM[class]
    return type(sim) == "table" and #sim > 0 and sim or nil
end

-- The name a template's set gets: "<Name> (Sim)".
function OW.TemplateName(tpl) return OW.CleanName(L["%s (Sim)"]:format(L[tpl.name])) end

-- A template as an own set ("<Name> (Sim)", replaced when there), chosen; the template stays as it is.
function OW.FromTemplate(class, spec, tpl)
    if type(tpl) ~= "table" or type(tpl.w) ~= "table" then return nil, "?" end
    return OW.Save(class, spec, OW.TemplateName(tpl), tpl.w, { replace = true, pick = true })
end

-- Amisia's weights of a weighting (not "Eigene": then Speedrun) at a level, per point, into a set.
function OW.FromAmisia(class, spec, name, kind, level)
    if kind == "Eigene" or not kind then kind = "Speedrun" end   -- l10n-ok: setting key
    local w = Gear.Weights(class, spec, kind, level)
    if not w then return nil, L["Keine Gewichtung."] end
    return OW.Save(class, spec, name, Gear.ToPoints(w, level), { replace = true })
end

---------------------------------------------------------------------------
-- Pasting and copying
---------------------------------------------------------------------------

-- The names a pasted list may use, folded (lower case, without spaces, dashes, dots, brackets): German and
-- English as the game names the stats, and the short English names of the common weights line.
local ALIAS = {}
local function norm(s) return (tostring(s):lower():gsub("[%s%-_%.%(%):/'%[%]]", "")) end
local function alias(key, list)
    for _, n in ipairs(list) do ALIAS[norm(n)] = key end
end
alias("STR", { "Strength", "Str", "Stärke", "Staerke" })   -- l10n-ok: paste names
alias("AGI", { "Agility", "Agi", "Beweglichkeit" })   -- l10n-ok: paste names
alias("STA", { "Stamina", "Sta", "Ausdauer" })   -- l10n-ok: paste names
alias("INT", { "Intellect", "Int", "Intelligenz" })   -- l10n-ok: paste names
alias("SPI", { "Spirit", "Spi", "Willenskraft" })   -- l10n-ok: paste names
alias("SP", { "SpellDamage", "Spell Damage", "SpellPower", "Spell Power", "SpellDmg", "SP", "Zaubermacht", "Zauberschaden",   -- l10n-ok: paste names
    "Bonus Damage", "Damage and Healing" })
alias("HEAL", { "Healing", "HealingPower", "Healing Power", "Bonus Healing", "Heal", "Heilung", "Heilkraft" })   -- l10n-ok: paste names
alias("SP_ARCANE", { "ArcaneSpellDamage", "ArcaneDamage", "Arcane Damage", "Arcane Spell Damage", "Arkanschaden", "Schaden Arkan" })   -- l10n-ok: paste names
alias("SP_FIRE", { "FireSpellDamage", "FireDamage", "Fire Damage", "Fire Spell Damage", "Feuerschaden", "Schaden Feuer" })   -- l10n-ok: paste names
alias("SP_FROST", { "FrostSpellDamage", "FrostDamage", "Frost Damage", "Frost Spell Damage", "Frostschaden", "Schaden Frost" })   -- l10n-ok: paste names
alias("SP_HOLY", { "HolySpellDamage", "HolyDamage", "Holy Damage", "Holy Spell Damage", "Heiligschaden", "Schaden Heilig" })   -- l10n-ok: paste names
alias("SP_NATURE", { "NatureSpellDamage", "NatureDamage", "Nature Damage", "Nature Spell Damage", "Naturschaden", "Schaden Natur" })   -- l10n-ok: paste names
alias("SP_SHADOW", { "ShadowSpellDamage", "ShadowDamage", "Shadow Damage", "Shadow Spell Damage", "Schattenschaden", "Schaden Schatten" })   -- l10n-ok: paste names
alias("MP5", { "Mp5", "Mana per 5", "Mana per 5 sec", "Mana per 5 seconds", "Mana Regen", "Mana alle 5 Sek", "Mana alle 5 Sekunden" })   -- l10n-ok: paste names
alias("HP5", { "Hp5", "Health per 5", "Health per 5 sec", "Gesundheit alle 5 Sek", "Gesundheit alle 5 Sekunden" })   -- l10n-ok: paste names
alias("AP", { "Ap", "AttackPower", "Attack Power", "Angriffskraft" })   -- l10n-ok: paste names
alias("RAP", { "Rap", "RangedAttackPower", "Ranged Attack Power", "Distanzangriffskraft" })   -- l10n-ok: paste names
alias("HIT", { "HitRating", "Hit Rating", "Hit", "SpellHitRating", "Spell Hit Rating", "Trefferwertung", "Treffer",   -- l10n-ok: paste names
    "Zaubertrefferwertung" })   -- l10n-ok: paste names
alias("CRIT", { "CritRating", "Crit Rating", "Crit", "Critical Strike Rating", "SpellCritRating", "Spell Crit Rating",   -- l10n-ok: paste names
    "Spell Critical Strike Rating", "kritische Trefferwertung", "Kritwertung", "Zauberkritwertung" })   -- l10n-ok: paste names
alias("HASTE", { "HasteRating", "Haste Rating", "Haste", "SpellHasteRating", "Spell Haste Rating", "Tempowertung", "Tempo",   -- l10n-ok: paste names
    "Zaubertempowertung" })   -- l10n-ok: paste names
alias("EXP", { "ExpertiseRating", "Expertise Rating", "Expertise", "Waffenkundewertung", "Waffenkunde" })   -- l10n-ok: paste names
alias("DEF", { "DefenseRating", "Defense Rating", "Defense", "Defence", "Verteidigungswertung", "Verteidigung" })   -- l10n-ok: paste names
alias("DODGE", { "DodgeRating", "Dodge Rating", "Dodge", "Ausweichwertung", "Ausweichen" })   -- l10n-ok: paste names
alias("PARRY", { "ParryRating", "Parry Rating", "Parry", "Parierwertung", "Parieren" })   -- l10n-ok: paste names
alias("BLOCK", { "BlockRating", "Block Rating", "Blockwertung" })   -- l10n-ok: paste names
alias("BLOCKVAL", { "BlockValue", "Block Value", "Blockwert" })   -- l10n-ok: paste names
alias("ARMOR", { "Armor", "Armour", "Rüstung", "Ruestung" })   -- l10n-ok: paste names
alias("SPEN", { "SpellPenetration", "Spell Penetration", "SpellPen", "Zauberdurchschlag" })   -- l10n-ok: paste names
alias("RES", { "ResilienceRating", "Resilience Rating", "Resilience", "Abhärtungswertung", "Abhärtung" })   -- l10n-ok: paste names
alias("DPS", { "Dps", "MeleeDps", "Melee Dps", "MainHandDps", "Weapon Dps", "Damage Per Second", "Waffenschaden pro Sekunde", "Waffen-DPS" })   -- l10n-ok: paste names
alias("RDPS", { "RangedDps", "Ranged Dps", "Distanz-DPS", "Distanzwaffe: Schaden pro Sekunde" })   -- l10n-ok: paste names
-- the names of the head of the weights line that are no weight
local META = { [norm("Class")] = true, [norm("Spec")] = true, [norm("Klasse")] = true }   -- l10n-ok: paste names

-- The key of a pasted name, or nil.
function OW.KeyOf(name) return ALIAS[norm(name or "")] end

-- Reads a pasted text, untrusted (D-26): the first 4000 characters, two forms:
--   1. Name=Zahl, separated by commas, semicolons or lines (Intelligenz=0,24, Spell Power=1, HitRating=1.14);
--   2. that list in brackets with a head, as simulations and guides offer it for copying:
--      ( Word: v1: "Name": Class=Priest, Intellect=0.24, ... ); the name in quotes is the set's name.
-- Comma and point both are a decimal mark (no thousands). Returns { name (form 2, cleaned, or nil), values =
-- { [key] = number }, known = { key, ... } in the text's order, unknown = { name, ... }, bad = { text, ... },
-- cut = the text was longer } or nil and the reason (nothing recognised, more than 40 values). Nothing runs.
function OW.Parse(text)
    if type(text) ~= "string" then return nil, L["Nichts eingefügt."] end
    local cut = #text > MAX_TEXT
    text = text:sub(1, MAX_TEXT)
    local res = { values = {}, known = {}, unknown = {}, bad = {}, cut = cut or nil }
    local head, body = text:match("^%s*%(%s*[^:()\"]-:%s*v%d+%s*:%s*\"([^\"]*)\"%s*:(.*)$")
    if head then
        res.name = OW.CleanName(head)
        body = body:gsub("%)%s*$", "")
    else
        body = text
    end
    local pos, pairsSeen = 1, 0
    while true do
        local s, e, rawName = body:find("([^=,;\r\n]*)=", pos)
        if not s then break end
        local _, ve, num = body:find("^%s*([%+%-]?%d*[%.,]?%d*)", e + 1)
        local after = ve + 1
        -- a mark right after the digits ("a=1,b=2") separates
        if num:find("[%.,]$") then
            num = num:sub(1, -2)
            after = after - 1
        end
        local junk = body:match("^[^,;\r\n]*", after) or ""
        pos = after + #junk
        if pos <= e then pos = e + 1 end
        local name = rawName:match("^%s*(.-)%s*$")
        local shown = OW.CleanName(name, 24) or "?"
        if not META[norm(name)] then
            pairsSeen = pairsSeen + 1
            if pairsSeen > MAX_VALUES then return nil, L["Zu viele Werte: höchstens %d."]:format(MAX_VALUES) end
            local key = ALIAS[norm(name)]
            local ok = num:match("^[%+%-]?%d+$") or num:match("^[%+%-]?%d*[%.,]%d+$")
            local v = ok and junk:match("^%s*$") and tonumber((num:gsub(",", "."))) or nil
            if not key then
                res.unknown[#res.unknown + 1] = shown
            elseif not v then
                res.bad[#res.bad + 1] = L["%s: keine Zahl"]:format(shown)
            elseif v < MIN or v > MAX then
                res.bad[#res.bad + 1] = L["%s: %s liegt nicht zwischen -10 und 100"]:format(shown, num)
            else
                if res.values[key] == nil then res.known[#res.known + 1] = key end
                res.values[key] = round4(v)
            end
        end
    end
    if pairsSeen == 0 then return nil, L["Keine Werte erkannt. Erwartet: Name=Zahl, getrennt durch Komma, Semikolon oder Zeilen."] end
    return res
end

-- A number in the copied line: a point, up to 4 decimals.
local function lineNum(v)
    local s = ("%.4f"):format(v):gsub("0+$", ""):gsub("%.$", "")
    return s
end
-- the short English names of the copied line (form 2), as OW.Parse reads them back
local LINE_NAME = { STR = "Strength", AGI = "Agility", STA = "Stamina", INT = "Intellect", SPI = "Spirit",
    SP = "SpellDamage", HEAL = "Healing", SP_ARCANE = "ArcaneSpellDamage", SP_FIRE = "FireSpellDamage",
    SP_FROST = "FrostSpellDamage", SP_HOLY = "HolySpellDamage", SP_NATURE = "NatureSpellDamage",
    SP_SHADOW = "ShadowSpellDamage", MP5 = "Mp5", HP5 = "Hp5", AP = "Ap", RAP = "Rap", HIT = "HitRating",
    CRIT = "CritRating", HASTE = "HasteRating", EXP = "ExpertiseRating", DEF = "DefenseRating", DODGE = "DodgeRating",
    PARRY = "ParryRating", BLOCK = "BlockRating", BLOCKVAL = "BlockValue", ARMOR = "Armor", SPEN = "SpellPenetration",
    RES = "ResilienceRating", DPS = "MeleeDps", RDPS = "RangedDps" }
OW.LINE_NAME = LINE_NAME

-- A set as the bracketed line (form 2), to copy and share: ( Amisia: v1: "Name": Class=Priest, Intellect=0.24, ... ).
function OW.Export(class, name, set)
    local parts = { "Class=" .. (CLASS_WORD[class] or tostring(class)) }
    for _, k in ipairs(Gear.OWN_KEYS) do
        local v = type(set) == "table" and set[k]
        if type(v) == "number" and v ~= 0 then parts[#parts + 1] = LINE_NAME[k] .. "=" .. lineNum(v) end
    end
    return ("( Amisia: v1: \"%s\": %s )"):format(OW.CleanName(name) or "?", table.concat(parts, ", "))
end

-- The weights of a set as "Label Zahl" texts, the largest first ("Warum diese Gewichte").
function ns.OwnWeightParts(set)
    local order, list = {}, {}
    for i, k in ipairs(Gear.OWN_KEYS) do
        order[k] = i
        local v = type(set) == "table" and set[k]
        if type(v) == "number" and v ~= 0 then list[#list + 1] = { k = k, v = v } end
    end
    table.sort(list, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return order[a.k] < order[b.k]
    end)
    local out = {}
    for i, p in ipairs(list) do out[i] = ("%s %s"):format(Gear.OWN_LABELS[p.k], OW.NumText(p.v)) end
    return out
end

-- The name of a pasted set and whether it replaces one: the name of the line (form 2), else "Eingefügt",
-- "Eingefügt 2", ... (a list without a name never replaces a set).
function OW.PasteName(class, spec, res)
    if res and res.name then return res.name, OW.Get(class, spec, res.name) ~= nil end
    return OW.FreeName(class, spec, L["Eingefügt"]), false
end
end)
