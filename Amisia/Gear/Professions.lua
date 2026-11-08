-- Amisia professions: the recipes of ProfessionData.lua (tools/build_professions.py) read for the
-- professions page. Names come from the client (German), the data holds numbers only. What the own
-- character knows is read while its profession window is open (C_TradeSkillUI) and kept per
-- character; the reagents come from the data when the build had the client table, else from the
-- client (C_TradeSkillUI.GetRecipeSchematic). Recipe sources: the data's, plus the vendors and
-- drops the source collector saw itself or heard of (Collector.lua).
--
-- AmisiaDB.prof = { chars = { [name] = { [skillLine] = { rank, max, day, known = { [spell] = true } } } } }
local ADDON, ns = ...
local L = ns.L

local Pr = {}
ns.Prof = Pr

local KNOWN_CAP = 1200  -- recipes kept per profession and character at most

-- The profession keys of the data, named in the client's language.
Pr.NAMES = {
    alchemy = L["Alchimie"], blacksmithing = L["Schmiedekunst"], enchanting = L["Verzauberkunst"], engineering = L["Ingenieurskunst"],
    leatherworking = L["Lederverarbeitung"], tailoring = L["Schneiderei"], cooking = L["Kochkunst"], firstaid = L["Erste Hilfe"],
    fishing = L["Angeln"], herbalism = L["Kräuterkunde"], mining = L["Bergbau"], skinning = L["Kürschnerei"], poisons = L["Gifte"],
}
-- Their icons (the client's), and the secondary professions (the others are main professions).
Pr.ICONS = {
    alchemy = "Interface\\Icons\\Trade_Alchemy", blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
    enchanting = "Interface\\Icons\\Trade_Engraving", engineering = "Interface\\Icons\\Trade_Engineering",
    leatherworking = "Interface\\Icons\\INV_Misc_ArmorKit_17", tailoring = "Interface\\Icons\\Trade_Tailoring",
    cooking = "Interface\\Icons\\INV_Misc_Food_15", firstaid = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    fishing = "Interface\\Icons\\Trade_Fishing", herbalism = "Interface\\Icons\\Trade_Herbalism",
    mining = "Interface\\Icons\\Trade_Mining", skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    poisons = "Interface\\Icons\\Trade_BrewPoison",
}
Pr.ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"
Pr.SECONDARY = { cooking = 1, firstaid = 2, fishing = 3, poisons = 4 }
Pr.TIERS ={ [0] = L["Lehrer"], L["Lehrer (Lehrling)"], L["Lehrer (Geselle)"], L["Lehrer (Experte)"], L["Lehrer (Fachmann)"] }
Pr.STANDING = { L["Hasserfüllt"], L["Feindselig"], L["Unfreundlich"], "Neutral", L["Freundlich"], L["Wohlwollend"], L["Respektvoll"],
    L["Ehrfürchtig"] }
Pr.FACTION_NAME = { A = L["Allianz"], H = "Horde" }
-- the difficulty colours of the client's recipe list
Pr.COLORS = { orange = "ffff8040", yellow = "ffffff00", green = "ff40bf40", grey = "ff808080", red = "ffff2020", none = "ffffffff" }

local function data() return ns.Data("PROFESSIONS") end
function Pr.Available()
    -- the generator's count, while the table waits (opening the window builds nothing)
    local n = ns.DataSize("PROFESSIONS")
    if n then return n > 0 end
    local d = data()
    return type(d) == "table" and type(d.P) == "table" and d.P[1] ~= nil
end

local function num(s) return tonumber(s) or 0 end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h, i, j, k
end

---------------------------------------------------------------------------
-- Reading the data
---------------------------------------------------------------------------
local cache = { data = nil, recipes = {}, bySpell = nil, items = {}, camp = nil }
local function fresh()
    if cache.data ~= data() then
        cache = { data = data(), recipes = {}, bySpell = nil, items = {}, camp = nil }
    end
end
function Pr._reset() cache = { data = nil, recipes = {}, bySpell = nil, items = {}, camp = nil } end

-- The key of a skill line ("blacksmithing"), or nil.
function Pr.Key(skill)
    local d = data()
    for _, p in ipairs(d and d.P or {}) do
        if p[1] == skill then return p[2] end
    end
    return nil
end
function Pr.Name(skill) return Pr.NAMES[Pr.Key(skill) or ""] or L["Beruf %s"]:format(tostring(skill)) end

-- The skill lines of the data in its order.
function Pr.Skills()
    local out = {}
    for _, p in ipairs(data() and data().P or {}) do out[#out + 1] = p[1] end
    return out
end

---------------------------------------------------------------------------
-- Professions written in a guild note ("Alchi 300 / Kräuter", "BS 225, Mining")
---------------------------------------------------------------------------
-- The client's skill lines (the same in every Classic client and in the data).
local NOTE_SKILL = { alchemy = 171, blacksmithing = 164, enchanting = 333, engineering = 202, leatherworking = 165,
    tailoring = 197, cooking = 185, firstaid = 129, fishing = 356, herbalism = 182, mining = 186, skinning = 393,
    poisons = 40 }
-- A word that starts with one of these stems names the profession (German and English, common short forms).
local NOTE_STEMS = {
    { "alch", "alchemy" }, { "schmied", "blacksmithing" }, { "blacksmith", "blacksmithing" },
    { "verzaub", "enchanting" }, { "enchant", "enchanting" }, { "ingenieur", "engineering" }, { "ingi", "engineering" },
    { "engineer", "engineering" }, { "leder", "leatherworking" }, { "leather", "leatherworking" },
    { "schneider", "tailoring" }, { "tailor", "tailoring" }, { "koch", "cooking" }, { "cook", "cooking" },
    { "erstehilfe", "firstaid" }, { "firstaid", "firstaid" }, { "angel", "fishing" }, { "fish", "fishing" },
    { "kräuter", "herbalism" }, { "kraeuter", "herbalism" }, { "krauter", "herbalism" }, { "kraut", "herbalism" }, -- l10n-ok: words read from notes
    { "herb", "herbalism" }, { "bergbau", "mining" }, { "mining", "mining" }, { "miner", "mining" },
    { "kürsch", "skinning" }, { "kuersch", "skinning" }, { "kursch", "skinning" }, { "skinn", "skinning" }, -- l10n-ok: words read from notes
    { "gift", "poisons" }, { "poison", "poisons" },
}
-- Short forms that only count as the whole word.
local NOTE_WORDS = { bs = "blacksmithing", vz = "enchanting", vzk = "enchanting", ench = "enchanting",
    eng = "engineering", ing = "engineering", inge = "engineering", lw = "leatherworking", lv = "leatherworking",
    schnei = "tailoring", eh = "firstaid", bb = "mining", skin = "skinning" }
-- Armour and weapon smiths name blacksmithing in the middle of the word.
local NOTE_INSIDE = { { "schmied", "blacksmithing" } }

local function noteKey(word)
    local k = NOTE_WORDS[word]
    if k then return k end
    for _, s in ipairs(NOTE_STEMS) do
        if word:sub(1, #s[1]) == s[1] then return s[2] end
    end
    for _, s in ipairs(NOTE_INSIDE) do
        if word:find(s[1], 1, true) then return s[2] end
    end
    return nil
end

-- The professions a note names, in the note's order: { { skill = skill line, rank = the number right
-- after it (1..450) or nil } }; each skill once; {} when there is none. Words are runs of letters
-- (bytes over 127 count as letters, so umlauts stay inside a word); "Erste Hilfe" and "First Aid"
-- are read as one word. The answer is kept per note text (the members page reads every note on each
-- refresh): callers only read it, never change it.
local noteMemo, noteMemoN = {}, 0
local NOTE_MEMO_MAX = 2000

function Pr.FromNote(text)
    if type(text) ~= "string" or text == "" then return {} end
    local memo = noteMemo[text]
    if memo then return memo end
    local out, seen = {}, {}
    if noteMemoN >= NOTE_MEMO_MAX then
        noteMemo, noteMemoN = {}, 0
    end
    noteMemo[text], noteMemoN = out, noteMemoN + 1
    text = ns.Fold((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    local tokens = {}
    for word, digits in text:gmatch("([%a\128-\255]*)(%d*)") do
        if word ~= "" then tokens[#tokens + 1] = word end
        if digits ~= "" then tokens[#tokens + 1] = tonumber(digits) end
    end
    local i = 1
    while i <= #tokens do
        local t, k = tokens[i], nil
        if type(t) == "string" then
            local nxt = tokens[i + 1]
            if (t == "erste" and nxt == "hilfe") or (t == "first" and nxt == "aid") then -- l10n-ok: words read from notes
                k, i = "firstaid", i + 1
            else
                k = noteKey(t)
            end
        end
        if k then
            local n = tokens[i + 1]
            local rank = type(n) == "number" and n >= 1 and n <= 450 and n or nil
            local skill = NOTE_SKILL[k]
            if not seen[skill] then
                seen[skill] = true
                out[#out + 1] = { skill = skill, rank = rank }
            end
            if rank then i = i + 1 end
        end
        i = i + 1
    end
    return out
end

local function parse(line, skill)
    local spell, item, count, learn, yellow, grey, src = line:match("^(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(.*)$")
    if not spell then return nil end
    local r = { spell = num(spell), item = num(item), count = num(count), learn = num(learn), yellow = num(yellow),
        grey = num(grey), skill = skill, src = {}, items = {}, trainers = {} }
    r.green = math.floor((r.yellow + r.grey) / 2)
    for tok in src:gmatch("[^,]+") do
        local recipeItem = tok:match("^I(%d+)$")
        local trainer = tok:match("^N(%d+)$")
        if recipeItem then r.items[#r.items + 1] = num(recipeItem)
        elseif trainer then r.trainers[#r.trainers + 1] = num(trainer)
        else r.src[#r.src + 1] = tok end
    end
    return r
end

-- The recipes of a skill line, parsed once (the data's order: by difficulty).
function Pr.Recipes(skill)
    fresh()
    local list = cache.recipes[skill]
    if list then return list end
    list = {}
    local d = data()
    for _, line in ipairs(d and d.R and d.R[skill] or {}) do
        local r = parse(line, skill)
        if r then list[#list + 1] = r end
    end
    cache.recipes[skill] = list
    return list
end

function Pr.Recipe(spell)
    fresh()
    if not cache.bySpell then
        cache.bySpell = {}
        for _, skill in ipairs(Pr.Skills()) do
            for _, r in ipairs(Pr.Recipes(skill)) do cache.bySpell[r.spell] = cache.bySpell[r.spell] or r end
        end
    end
    return cache.bySpell[tonumber(spell)]
end

-- A recipe item: { id, spell, rank, faction, standing, sources = { "V123", "F45@4A", ... } } or nil.
function Pr.RecipeItem(id)
    fresh()
    id = tonumber(id)
    if cache.items[id] ~= nil then return cache.items[id] or nil end
    local d = data()
    local line = d and d.I and d.I[id]
    local out = false
    if type(line) == "string" then
        local spell, rank, faction, standing, src = line:match("^(%d+):(%d+):(%d+):(%d+):(.*)$")
        if spell then
            out = { id = id, spell = num(spell), rank = num(rank), faction = num(faction), standing = num(standing), sources = {} }
            for tok in src:gmatch("[^,]+") do out.sources[#out.sources + 1] = tok end
        end
    end
    cache.items[id] = out
    return out or nil
end

-- An NPC of the data: name (English), point { map, x, y } (0-1) or zone uiMapID, faction.
function Pr.Npc(id)
    local d = data()
    local s = d and d.N and d.N[tonumber(id)]
    if type(s) ~= "string" then return nil end
    local name, where, fac = s:match("^([^|]*)|([^|]*)|(.*)$")
    if not name then return nil end
    local m, x, y = where:match("^(%d+):(%d+):(%d+)$")
    local out = { id = tonumber(id), name = name ~= "" and name or nil, faction = fac }
    if m then
        out.point = { map = num(m), x = num(x) / 10000, y = num(y) / 10000 }
        out.zone = out.point.map
    elseif where ~= "" then
        out.zone = num(where)
    end
    return out
end

---------------------------------------------------------------------------
-- Names from the client
---------------------------------------------------------------------------
function Pr.SpellName(spell)
    local name
    if C_Spell and C_Spell.GetSpellName then name = call(C_Spell.GetSpellName, spell) end
    if not name and GetSpellInfo then name = call(GetSpellInfo, spell) end
    name = ns.Plain(name)
    return type(name) == "string" and name ~= "" and name or nil
end

-- A spell's data (its description above all) comes back empty until the client has loaded it; the
-- first ask after the login often finds it not loaded. spell -> "asked" (load requested, waiting
-- for SPELL_DATA_LOAD_RESULT) or "done" (the result came: never asked again, so an empty text
-- cannot loop).
local spellLoad = {}

-- Whether the client still has to load the spell's data: asks it to (once) and returns true while
-- the load is pending; false when the data is there, was loaded once already, or the client has no
-- way to load it.
function Pr.LoadSpell(spell)
    spell = tonumber(spell)
    local api = _G.C_Spell
    if not spell or type(api) ~= "table" or type(api.RequestLoadSpellData) ~= "function" then return false end
    local state = spellLoad[spell]
    if state == "done" then return false end
    if type(api.IsSpellDataCached) == "function" and ns.Plain(call(api.IsSpellDataCached, spell)) == true then
        if state then spellLoad[spell] = "done" end
        return false
    end
    if state == "asked" then return true end
    spellLoad[spell] = "asked"
    call(api.RequestLoadSpellData, spell)
    return true
end

ns.OnEvent("SPELL_DATA_LOAD_RESULT", function(spell)
    spell = tonumber(ns.Plain(spell))
    if spell and spellLoad[spell] == "asked" then
        spellLoad[spell] = "done"
        ns.Fire("PROF_SPELL_LOADED", spell)
    end
end)

-- The client's description of a spell; nil and true while the client still loads it (or may: a
-- client without RequestLoadSpellData fills it in on its own), nil and false when it has none.
function Pr.SpellDescription(spell)
    local text
    if C_Spell and C_Spell.GetSpellDescription then text = call(C_Spell.GetSpellDescription, spell) end
    if not text and GetSpellDescription then text = call(GetSpellDescription, spell) end
    text = ns.Plain(text)
    if type(text) == "string" and text ~= "" then return text, false end
    local api = _G.C_Spell
    if type(api) ~= "table" or type(api.RequestLoadSpellData) ~= "function" then return nil, true end
    return nil, Pr.LoadSpell(spell)
end

-- Name, quality and link of an item, when the client has it.
function Pr.ItemInfo(id)
    local f = C_Item and C_Item.GetItemInfo
    if not f then return nil end
    local name, link, q = call(f, id)
    return ns.Plain(name), ns.Plain(q), ns.Plain(link)
end

function Pr.ZoneName(map)
    if type(map) ~= "number" or map <= 0 then return nil end
    local info = C_Map and C_Map.GetMapInfo and call(C_Map.GetMapInfo, map)
    return type(info) == "table" and type(info.name) == "string" and info.name or nil
end

-- The name a recipe shows: the client's spell name, else the made item's, else its number.
function Pr.RecipeName(r)
    return Pr.SpellName(r.spell) or (r.item > 0 and (Pr.ItemInfo(r.item))) or L["Rezept %s"]:format(r.spell)
end

---------------------------------------------------------------------------
-- The own professions and what the character knows
---------------------------------------------------------------------------
local function charKey() return ns.UnitFullName and ns.UnitFullName("player") or "?" end

local function store(create)
    if not AmisiaDB then return nil end
    local p = AmisiaDB.prof
    if type(p) ~= "table" or type(p.chars) ~= "table" then
        if not create then return nil end
        p = { chars = {} }
        AmisiaDB.prof = p
    end
    local key = charKey()
    local c = p.chars[key]
    if type(c) ~= "table" then
        if not create then return nil end
        c = {}
        p.chars[key] = c
    end
    return c
end

-- The own professions from the spell book: { { skill, rank, max, name } } in the client's order.
function Pr.Own()
    local out, seen = {}, {}
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        -- prim1, prim2 and up to five secondary ones (Camelot: cooking, first aid, fishing, poisons, ...)
        local list = { call(GetProfessions) }
        for i = 1, 7 do
            local idx = list[i]
            if type(idx) == "number" then
                local name, _, rank, max, _, _, skill = call(GetProfessionInfo, idx)
                skill = tonumber(ns.Plain(skill))
                if skill and not seen[skill] then
                    seen[skill] = true
                    out[#out + 1] = { skill = skill, rank = tonumber(ns.Plain(rank)) or 0, max = tonumber(ns.Plain(max)) or 0,
                        name = ns.Plain(name) }
                end
            end
        end
    end
    -- a profession seen in its window but missing from the book (a client without the book
    -- functions): from the saved state
    local c = store(false)
    if c then
        local extra = {}
        for skill, s in pairs(c) do
            if type(skill) == "number" and type(s) == "table" and not seen[skill] then extra[#extra + 1] = skill end
        end
        table.sort(extra)
        for _, skill in ipairs(extra) do
            out[#out + 1] = { skill = skill, rank = c[skill].rank or 0, max = c[skill].max or 0, saved = true }
        end
    end
    return out
end

-- The own rank in a skill line, or nil.
function Pr.Rank(skill)
    for _, p in ipairs(Pr.Own()) do
        if p.skill == skill then return p.rank, p.max end
    end
    return nil
end

-- Whether the character knows a recipe: true, false, or nil when its profession window was never
-- read (nothing to say).
function Pr.Known(spell, skill)
    local c = store(false)
    local s = c and c[skill]
    if type(s) ~= "table" or type(s.known) ~= "table" then return nil end
    return s.known[spell] == true
end

function Pr.HasSnapshot(skill)
    local c = store(false)
    return c ~= nil and type(c[skill]) == "table" and type(c[skill].known) == "table"
end

-- Reads the open profession window when it shows the own profession.
local function tradeSkillOwn()
    local T = C_TradeSkillUI
    if type(T) ~= "table" then return false end
    for _, f in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        if call(T[f]) then return false end
    end
    return true
end

function Pr.ReadTradeSkill()
    local T = C_TradeSkillUI
    if type(T) ~= "table" or not AmisiaDB or not tradeSkillOwn() then return false end
    local info = call(T.GetBaseProfessionInfo)
    local skill = type(info) == "table" and tonumber(ns.Plain(info.professionID)) or nil
    if not skill or not Pr.Key(skill) then return false end
    -- every recipe where the client tells them all; else the list the window shows, which follows its
    -- search and filters: what it shows joins what was known, nothing goes
    local ids = call(T.GetAllRecipeIDs)
    local full = type(ids) == "table"
    if not full then ids = call(T.GetFilteredRecipeIDs) end
    if type(ids) ~= "table" then return false end
    local old = store(false)
    old = old and type(old[skill]) == "table" and type(old[skill].known) == "table" and old[skill].known or nil
    local known, n = {}, 0
    for _, id in ipairs(ids) do
        local r = call(T.GetRecipeInfo, id)
        if type(r) == "table" and ns.Plain(r.learned) == true and n < KNOWN_CAP then
            local spell = tonumber(ns.Plain(r.recipeID)) or id
            if not known[spell] then
                known[spell] = true
                n = n + 1
            end
        end
    end
    if n == 0 and #ids > 0 and (full or not old) then return false end   -- the list is not filled yet
    if not full and old then
        for spell in pairs(old) do
            if not known[spell] and n < KNOWN_CAP then
                known[spell] = true
                n = n + 1
            end
        end
    end
    local c = store(true)
    local prev = c[skill]
    local rank, max = tonumber(ns.Plain(info.skillLevel)) or 0, tonumber(ns.Plain(info.maxSkillLevel)) or 0
    c[skill] = { rank = rank, max = max, day = ns.DropsToday and ns.DropsToday() or 0, known = known }
    -- the window updates its list often: news only when rank, cap or the known recipes changed
    local same = type(prev) == "table" and prev.rank == rank and prev.max == max and type(prev.known) == "table"
    if same then
        local m = 0
        for spell in pairs(prev.known) do
            if not known[spell] then same = false break end
            m = m + 1
        end
        same = same and m == n
    end
    if not same then ns.Fire("PROF_CHANGED", skill) end
    return true
end

local function onLearned(id)
    id = tonumber(ns.Plain(id))
    local r = id and Pr.Recipe(id)
    if not r then return end
    local c = store(false)
    local s = c and c[r.skill]
    if type(s) == "table" and type(s.known) == "table" then
        s.known[id] = true
        ns.Fire("PROF_CHANGED", r.skill)
    end
end

local pending = false
local function later()
    if pending then return end
    pending = true
    local run = function()
        pending = false
        Pr.ReadTradeSkill()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, run) else run() end
end
ns.OnEvent("TRADE_SKILL_SHOW", later)
ns.OnEvent("TRADE_SKILL_LIST_UPDATE", later)
ns.OnEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", later)
ns.OnEvent("NEW_RECIPE_LEARNED", onLearned)
-- every skill-up (weapon skills too) fires this: news only when the own professions changed
local ownSig
local function ownSignature()
    local parts = {}
    for _, p in ipairs(Pr.Own()) do parts[#parts + 1] = ("%d:%d:%d"):format(p.skill, p.rank, p.max) end
    return table.concat(parts, ",")
end
ns.OnEvent("SKILL_LINES_CHANGED", function()
    local sig = ownSignature()
    if sig == ownSig then return end
    ownSig = sig
    ns.Fire("PROF_CHANGED")
end)

---------------------------------------------------------------------------
-- Difficulty
---------------------------------------------------------------------------
-- The colour of a recipe at a rank, as the client's list shows it: "orange", "yellow", "green",
-- "grey"; "red" when it is not known and needs a higher rank to learn; "none" without data.
-- The rank from which a recipe can be learned: the data's when above 1 (a recipe item's requirement,
-- the client's minimum); 1 for a recipe learned with the profession; else (the client tables say 1
-- for the trainer recipes) the yellow rank, never earlier than the game allows: the recipe items of
-- the data are learnable at or before yellow, often 15-40 ranks before, so the trainer's real rank
-- is not known and later is the safe side (F-137 review). Not below what the tier's trainer asks
-- (Journeyman 50, Expert 125, Artisan 200).
local TIER_FLOOR = { [2] = 50, [3] = 125, [4] = 200 }

-- The own newest reading of a recipe at a trainer (ProfTrainers.lua, F-155), or nil.
function Pr.TrainerOffer(spell)
    return ns.ProfTrainers and ns.ProfTrainers.Of(spell) or nil
end

-- Whether a trainer is known to teach a recipe: the data's trainers (N, read in the game and built
-- in) or an own reading.
function Pr.HasTrainer(r) return #r.trainers > 0 or Pr.TrainerOffer(r.spell) ~= nil end

-- Whether the learn rank is the game's own (an own reading, a trainer of the data, a recipe item's
-- requirement, learned with the profession), not the estimate of Pr.LearnRank ("?" on the page).
function Pr.LearnExact(r)
    if r.learn > 1 or #r.items > 0 or Pr.HasTrainer(r) then return true end
    for _, tok in ipairs(r.src) do if tok == "A" then return true end end
    return false
end

-- Where a recipe's learn rank comes from a trainer: "own" (an own reading), "data" (the data's
-- trainers), else nil.
function Pr.LearnFromTrainer(r)
    if Pr.TrainerOffer(r.spell) then return "own" end
    if #r.trainers > 0 then return "data" end
    return nil
end

function Pr.LearnRank(r)
    local offer = Pr.TrainerOffer(r.spell)
    if offer then return math.max(1, offer.rank) end
    if r.learn > 1 or #r.trainers > 0 then return math.max(1, r.learn) end
    local tier
    for _, tok in ipairs(r.src) do
        if tok == "A" then return 1 end
        local t = tonumber(tok:match("^T(%d)$"))
        if t then tier = tier and math.min(tier, t) or t end
    end
    return math.max(1, r.yellow, tier and TIER_FLOOR[tier] or 0)
end

function Pr.Difficulty(r, rank, known)
    if not rank then return "none" end
    if not known and rank < Pr.LearnRank(r) then return "red" end
    if r.grey <= 0 then return "none" end
    if rank < r.yellow then return "orange" end
    if rank < r.green then return "yellow" end
    if rank < r.grey then return "green" end
    return "grey"
end

-- Whether the own rank allows learning it.
function Pr.Learnable(r, rank) return rank ~= nil and rank >= Pr.LearnRank(r) end

---------------------------------------------------------------------------
-- Reagents
---------------------------------------------------------------------------
local reagentCache = {}

-- The reagents of a recipe: { { item, n } }, and where they come from ("data", "client"); nil when
-- neither knows them.
function Pr.Reagents(spell)
    local d = data()
    local s = d and d.G and d.G[spell]
    if type(s) == "string" then
        local out = {}
        for item, n in s:gmatch("(%d+):(%d+)") do out[#out + 1] = { num(item), num(n) } end
        return out, "data"
    end
    local hit = reagentCache[spell]
    if hit then return hit, "client" end
    local T = C_TradeSkillUI
    local sch = type(T) == "table" and call(T.GetRecipeSchematic, spell, false) or nil
    if type(sch) ~= "table" or type(sch.reagentSlotSchematics) ~= "table" then return nil end
    local out = {}
    for _, slot in ipairs(sch.reagentSlotSchematics) do
        local first = type(slot) == "table" and type(slot.reagents) == "table" and slot.reagents[1]
        local item = type(first) == "table" and tonumber(ns.Plain(first.itemID))
        local n = type(slot) == "table" and tonumber(ns.Plain(slot.quantityRequired))
        local basic = slot.required ~= false
        if item and n and n > 0 and basic then out[#out + 1] = { item, n } end
    end
    if #out == 0 then return nil end
    reagentCache[spell] = out
    return out, "client"
end

function Pr.Count(item)
    local f = C_Item and C_Item.GetItemCount
    return tonumber(f and call(f, item, true)) or 0
end

---------------------------------------------------------------------------
-- Sources
---------------------------------------------------------------------------
-- Item -> what the source collector saw: { vendors = { { npc, name, pos, price, rep, own, ownPos } },
-- drops = { { npc, name, pos, own, ownPos } } }, rebuilt when the collector changes. ownPos: the place
-- was seen by this client itself (only such a place becomes a waypoint).
local obsIndex, obsGen
function Pr.Observed(item)
    local gen = ns.CollectGen and ns.CollectGen() or 0
    local c = AmisiaDB and AmisiaDB.collect
    if not obsIndex or obsGen ~= gen or obsIndex._c ~= c then
        obsIndex, obsGen = { _c = c }, gen
        if type(c) == "table" then
            for npc, s in pairs(type(c.s) == "table" and c.s or {}) do
                local r = ns.CollectParse and ns.CollectParse("s", s)
                if r then
                    for id, it in pairs(r.items) do
                        local e = obsIndex[id] or { vendors = {}, drops = {} }
                        obsIndex[id] = e
                        e.vendors[#e.vendors + 1] = { npc = npc, name = r.name, pos = r.pos, price = it.price, rep = it.rep,
                            own = r.own ~= 0, ownPos = ns.CollectOwn and ns.CollectOwn("s", r, "pos") or false }
                    end
                end
            end
            for npc, s in pairs(type(c.w) == "table" and c.w or {}) do
                local r = ns.CollectParse and ns.CollectParse("w", s)
                if r then
                    for id in pairs(r.items) do
                        local e = obsIndex[id] or { vendors = {}, drops = {} }
                        obsIndex[id] = e
                        e.drops[#e.drops + 1] = { npc = npc, name = r.name, pos = r.pos, own = r.own ~= 0,
                            ownPos = ns.CollectOwn and ns.CollectOwn("w", r, "pos") or false }
                    end
                end
            end
        end
    end
    return obsIndex[tonumber(item)]
end

local function money(copper)
    copper = tonumber(copper) or 0
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return ("%dg %ds"):format(g, s) end
    if s > 0 then return ("%ds %dc"):format(s, c) end
    return ("%dc"):format(c)
end
-- the short money text of the page ("14g 30s", "30s 5c", "5c"); the route's costs too
Pr.Money = money

local function where(npc)
    if not npc then return nil end
    local zone = npc.zone and Pr.ZoneName(npc.zone)
    if npc.point then
        return ("%s %d, %d"):format(zone or "?", math.floor(npc.point.x * 100 + 0.5), math.floor(npc.point.y * 100 + 0.5))
    end
    return zone
end

local function posText(pos)
    local m, x, y = tostring(pos or ""):match("^(%d+):(%d+):(%d+)$")
    if m then
        return ("%s %d, %d"):format(Pr.ZoneName(num(m)) or "?", math.floor(num(x) / 100 + 0.5), math.floor(num(y) / 100 + 0.5)),
            { map = num(m), x = num(x) / 10000, y = num(y) / 10000 }
    end
    local z = tonumber(pos)
    return z and Pr.ZoneName(z) or nil, nil
end

-- The sources of a recipe as lines: { kind = "A"|"T"|"V"|"F"|"D"|"Z"|"W"|"Q"|"?", text, point,
-- own }. kind order: with the profession, trainer, recipe items (favor, vendor, quest, drop), what
-- the collector saw.
function Pr.Sources(r)
    local out = {}
    local function add(kind, text, point, extra)
        local e = { kind = kind, text = text, point = point }
        if extra then for k, v in pairs(extra) do e[k] = v end end
        out[#out + 1] = e
    end
    for _, tok in ipairs(r.src) do
        if tok == "A" then add("A", L["Mit dem Beruf gelernt"])
        elseif tok == "S" then add("T", L["Lehrer der Spezialisierung (nur mit ihr)"])
        else
            local tier = tok:match("^T(%d)$")
            if tier then add("T", Pr.TIERS[num(tier)] or Pr.TIERS[0]) end
        end
    end
    -- the trainers read in the game: the own newest reading, then the data's (F-155)
    local offer = Pr.TrainerOffer(r.spell)
    local shownNpc
    if offer then
        local pt, point = posText(offer.pos)
        local name = offer.name or Pr.Npc(offer.npc) and Pr.Npc(offer.npc).name or ("NPC " .. offer.npc)
        add("T", L["Lehrer: %s%s (ab %d, %s)"]:format(name, pt and (", " .. pt) or "", math.max(1, offer.rank), money(offer.cost)),
            point, { npc = offer.npc, observed = true, own = true })
        shownNpc = offer.npc
    end
    for _, id in ipairs(r.trainers) do
        if id ~= shownNpc then
            local npc = Pr.Npc(id)
            local w = where(npc)
            add("T", L["Lehrer: %s%s"]:format(npc and npc.name or ("NPC " .. id), w and (", " .. w) or ""), npc and npc.point, { npc = id })
        end
    end
    local myFaction = ns.OwnFaction()
    for _, itemId in ipairs(r.items) do
        local ri = Pr.RecipeItem(itemId)
        local listed = {}
        for _, tok in ipairs(ri and ri.sources or {}) do
            local k, rest = tok:sub(1, 1), tok:sub(2)
            if k == "F" then
                local price, standing, fac = rest:match("^(%d+)@(%d)([AH])$")
                if price and (not myFaction or fac == myFaction) then
                    add("F", L["Händlergunst: %s Gunst, %s (%s)"]:format(price, Pr.STANDING[num(standing)] or "?",
                        Pr.FACTION_NAME[fac] or fac), nil, { price = num(price), standing = num(standing), item = itemId })
                end
            elseif k == "V" or k == "D" then
                local npc = Pr.Npc(rest)
                listed[num(rest)] = true
                local label = k == "V" and L["Händler"] or "Drop"
                local w = where(npc)
                add(k, ("%s: %s%s"):format(label, npc and npc.name or ("NPC " .. rest), w and (", " .. w) or ""),
                    npc and npc.point, { npc = num(rest), item = itemId })
            elseif k == "Q" then
                local d = data()
                local name = d and d.Q and d.Q[num(rest)]
                add("Q", ("Quest: %s"):format(name ~= nil and name ~= "" and name or ("Quest " .. rest)), nil, { quest = num(rest), item = itemId })
            elseif k == "Z" then
                add("Z", L["Zonendrop: %s"]:format(Pr.ZoneName(num(rest)) or ("Zone " .. rest)), nil, { item = itemId })
            elseif k == "W" then
                add("W", L["Weltdrop"], nil, { item = itemId })
            end
        end
        local obs = Pr.Observed(itemId)
        for _, v in ipairs(obs and obs.vendors or {}) do
            if not listed[v.npc] then
                local pt, point = posText(v.pos)
                if not v.ownPos then point = nil end   -- a place heard from the guild is shown, never a waypoint
                add("V", L["Händler: %s%s, %s%s"]:format(v.name ~= "" and v.name or ("NPC " .. v.npc), pt and (", " .. pt) or "",
                    money(v.price), v.own and L[" (selbst gesehen)"] or L[" (von der Gilde)"]), point,
                    { npc = v.npc, observed = true, own = v.own, item = itemId })
            end
        end
        for _, v in ipairs(obs and obs.drops or {}) do
            if not listed[v.npc] then
                local pt, point = posText(v.pos)
                if not v.ownPos then point = nil end
                add("D", ("Drop: %s%s%s"):format(v.name ~= "" and v.name or ("NPC " .. v.npc), pt and (", " .. pt) or "",
                    v.own and L[" (selbst gesehen)"] or L[" (von der Gilde)"]), point, { npc = v.npc, observed = true, own = v.own, item = itemId })
            end
        end
        if ri and (ri.rank or 0) > 0 then
            -- the item's own requirement, as a note of the item source
            out.rank = math.max(out.rank or 0, ri.rank)
        end
        if ri and ri.faction > 0 then out.rep = { faction = ri.faction, standing = ri.standing } end
    end
    if #out == 0 then
        add("?", Pr.PresumedTrainer(r) and L["Quelle unbekannt (vermutlich Lehrer)"]
            or L["Quelle unbekannt (Quest, Ruf, Instanz oder neu)"])
    end
    return out
end

-- Whether a recipe without any source is a trainer recipe all the same: only in a skill line whose
-- data has no trainer list at all (cooking, poisons, the smelting of mining; their trainers teach
-- every recipe that is neither learned with the profession nor taught by a recipe item). Where the
-- data lists the trainer's recipes (T, S), a recipe outside the list comes from a quest, a
-- reputation, an instance or is new to Forever (F-137 review).
local trainerLists
function Pr.PresumedTrainer(r)
    if #r.src > 0 or #r.items > 0 or Pr.HasTrainer(r) then return false end
    fresh()
    if not trainerLists or trainerLists.data ~= data() then trainerLists = { data = data() } end
    local has = trainerLists[r.skill]
    if has == nil then
        has = false
        for _, x in ipairs(Pr.Recipes(r.skill)) do
            for _, tok in ipairs(x.src) do
                if tok == "S" or tok:match("^T%d$") then has = true end
            end
            if has then break end
        end
        trainerLists[r.skill] = has
    end
    return not has
end

-- The source kinds of a recipe for the filter: set of "T" (trainer, with the profession too), "V",
-- "F", "D" (drops of all kinds), "Q".
function Pr.SourceKinds(r)
    local set = {}
    for _, tok in ipairs(r.src) do
        if tok == "A" or tok == "S" or tok:match("^T") then set.T = true end
    end
    for _, itemId in ipairs(r.items) do
        local ri = Pr.RecipeItem(itemId)
        for _, tok in ipairs(ri and ri.sources or {}) do
            local k = tok:sub(1, 1)
            if k == "Z" or k == "W" then k = "D" end
            set[k] = true
        end
        local obs = Pr.Observed(itemId)
        if obs and #obs.vendors > 0 then set.V = true end
        if obs and #obs.drops > 0 then set.D = true end
    end
    if Pr.PresumedTrainer(r) or Pr.HasTrainer(r) then set.T = true end
    return set
end

---------------------------------------------------------------------------
-- The list the page shows
---------------------------------------------------------------------------
local lower = ns.Fold

-- The recipes of a skill line after the filters: opts.search (part of the recipe or item name, any
-- case), opts.known ("known", "unknown"), opts.learnable (the own rank reaches the learn rank),
-- opts.source ("T", "V", "F", "D", "Q"), opts.guild (someone of the guild knows it, Crafters.lua).
-- Each entry is the recipe with name, known, color; sorted by the learn rank.
function Pr.List(skill, opts)
    opts = opts or {}
    local rank = Pr.Rank(skill)
    local search = opts.search and opts.search ~= "" and lower(opts.search) or nil
    local out = {}
    for _, r in ipairs(Pr.Recipes(skill)) do
        local known = Pr.Known(r.spell, skill)
        local ok = true
        if opts.known == "known" and known ~= true then ok = false end
        if opts.known == "unknown" and known == true then ok = false end
        if ok and opts.learnable and (known == true or not Pr.Learnable(r, rank)) then ok = false end
        if ok and opts.source and not Pr.SourceKinds(r)[opts.source] then ok = false end
        if ok and opts.guild and not (ns.Crafters and ns.Crafters.Has(r.spell)) then ok = false end
        local name = Pr.RecipeName(r)
        if ok and search then
            local itemName = r.item > 0 and Pr.ItemInfo(r.item) or nil
            ok = lower(name):find(search, 1, true) ~= nil or lower(itemName):find(search, 1, true) ~= nil
        end
        if ok then
            out[#out + 1] = { recipe = r, name = name, known = known, color = Pr.Difficulty(r, rank, known) }
        end
    end
    -- by the skill needed to learn it (the number the list shows), then by when it turns yellow,
    -- then by name (the user, 2026-10-11: the data's order put a few recipes out of line)
    table.sort(out, function(a, b)
        local ra, rb = a.recipe, b.recipe
        if ra.learn ~= rb.learn then return ra.learn < rb.learn end
        if ra.yellow ~= rb.yellow then return ra.yellow < rb.yellow end
        if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
        return ra.spell < rb.spell
    end)
    return out
end

-- The skill lines in the order the picker shows: the own professions first (book order), then
-- the secondary ones, then the rest in the data's order.
function Pr.Ordered()
    local out, seen = {}, {}
    for _, p in ipairs(Pr.Own()) do
        if Pr.Key(p.skill) and not seen[p.skill] then
            seen[p.skill] = true
            out[#out + 1] = p.skill
        end
    end
    for _, skill in ipairs(Pr.Skills()) do
        if not seen[skill] then
            seen[skill] = true
            out[#out + 1] = skill
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Camp objects and Merchant's Favor
---------------------------------------------------------------------------
-- { { item, skill, rank, use, recipe, slots, over } } in the data's order.
function Pr.Camp()
    fresh()
    if cache.camp then return cache.camp end
    local out = {}
    local d = data()
    for _, line in ipairs(d and d.CAMP or {}) do
        local f = {}
        for v in line:gmatch("[^:]+") do f[#f + 1] = num(v) end
        if #f == 7 then
            out[#out + 1] = { item = f[1], skill = f[2], rank = f[3], use = f[4], recipe = f[5], slots = f[6], over = f[7] }
        end
    end
    cache.camp = out
    return out
end

-- The Merchant's Favor: { currency, amount, name, vendors = { npc... } of the own faction (both
-- without one), cert = { [skill] = item }, writs = { [skill] = count }, recipes = { { recipe, price,
-- standing } } of the own faction }.
function Pr.Favor()
    local d = data()
    local F = d and d.FAVOR
    if type(F) ~= "table" then return nil end
    local fac = ns.OwnFaction()
    local out = { currency = F.currency, cert = F.cert or {}, writs = {}, recipes = {}, vendors = {} }
    for _, k in ipairs(fac and { fac } or { "A", "H" }) do
        for _, npc in ipairs(F.vendor and F.vendor[k] or {}) do out.vendors[#out.vendors + 1] = npc end
    end
    local C = C_CurrencyInfo
    local info = type(C) == "table" and call(C.GetCurrencyInfo, F.currency) or nil
    if type(info) == "table" then
        out.name = ns.Plain(info.name)
        out.amount = tonumber(ns.Plain(info.quantity))
    end
    local writ = F.writ or {}
    for _, skill in ipairs(Pr.Skills()) do
        for _, r in ipairs(Pr.Recipes(skill)) do
            if r.item > 0 and writ[r.item] then out.writs[skill] = (out.writs[skill] or 0) + 1 end
            for _, itemId in ipairs(r.items) do
                local ri = Pr.RecipeItem(itemId)
                for _, tok in ipairs(ri and ri.sources or {}) do
                    local price, standing, f = tok:match("^F(%d+)@(%d)([AH])$")
                    if price and (not fac or f == fac) then
                        out.recipes[#out.recipes + 1] = { recipe = r, item = itemId, price = num(price), standing = num(standing), faction = f }
                    end
                end
            end
        end
    end
    table.sort(out.recipes, function(a, b)
        if a.recipe.skill ~= b.recipe.skill then return a.recipe.skill < b.recipe.skill end
        if a.standing ~= b.standing then return a.standing < b.standing end
        if a.price ~= b.price then return a.price < b.price end
        return a.recipe.spell < b.recipe.spell
    end)
    return out
end

-- The own Merchant's Favor (the client's currency of the data): amount, name; nil without the data
-- or the currency (cheap: no recipe walk, for the side bar's count).
function Pr.FavorAmount()
    local d = data()
    local F = d and d.FAVOR
    local C = C_CurrencyInfo
    if type(F) ~= "table" or type(C) ~= "table" then return nil end
    local info = call(C.GetCurrencyInfo, F.currency)
    if type(info) ~= "table" then return nil end
    return tonumber(ns.Plain(info.quantity)), ns.Plain(info.name)
end

-- How many recipes of a skill line the own character knows, or nil while its profession window was
-- never read.
function Pr.KnownCount(skill)
    if not Pr.HasSnapshot(skill) then return nil end
    local n = 0
    for _, r in ipairs(Pr.Recipes(skill)) do
        if Pr.Known(r.spell, skill) then n = n + 1 end
    end
    return n
end

-- The trainers of a skill line with a place (data TR, each an NPC of N) the own faction may use: its
-- own and the neutral ones, those in the own capitals first, then the rest of the own faction, then
-- the neutral ones (by id within each). Without a known faction all of them.
local CAPITALS = { A = { [1453] = true, [1455] = true, [1457] = true }, H = { [1454] = true, [1456] = true, [1458] = true } }
function Pr.Trainers(skill)
    local d = data()
    local ids = d and d.TR and d.TR[skill]
    if type(ids) ~= "table" then return {} end
    local fac = ns.OwnFaction()
    local out = {}
    for _, id in ipairs(ids) do
        local n = Pr.Npc(id)
        local side = n and n.faction ~= "" and n.faction or nil
        if n and n.point and (not fac or not side or side == fac) then
            n.order = (side and CAPITALS[side][n.point.map]) and 1 or side and 2 or 3
            out[#out + 1] = n
        end
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    return out
end

-- The trainer of a skill line nearest to the player (ns.MapNearest: same continent), else the first
-- of Pr.Trainers (the own capital's); nil without one.
function Pr.NearestTrainer(skill)
    local list = Pr.Trainers(skill)
    if #list == 0 then return nil end
    local points, owner = {}, {}
    for _, n in ipairs(list) do
        points[#points + 1] = n.point
        owner[n.point] = n
    end
    local p = ns.MapNearest and ns.MapNearest(points) or nil
    return p and owner[p] or list[1]
end

---------------------------------------------------------------------------
-- Favourites and the crafting list of the own character (D-82):
-- AmisiaDB.prof.lists = { [character] = { fav = { [spell] = true }, queue = { { spell, n } } } }
---------------------------------------------------------------------------
local FAV_CAP, QUEUE_CAP, QUEUE_N = 500, 50, 999
local function lists(create)
    if not AmisiaDB then return nil end
    local p = AmisiaDB.prof
    if type(p) ~= "table" then
        if not create then return nil end
        p = { chars = {} }
        AmisiaDB.prof = p
    end
    if type(p.lists) ~= "table" then
        if not create then return nil end
        p.lists = {}
    end
    local key = charKey()
    local l = p.lists[key]
    if type(l) ~= "table" then
        if not create then return nil end
        l = {}
        p.lists[key] = l
    end
    if create then
        l.fav = type(l.fav) == "table" and l.fav or {}
        l.queue = type(l.queue) == "table" and l.queue or {}
    end
    return l
end

function Pr.IsFav(spell)
    local l = lists(false)
    return l ~= nil and type(l.fav) == "table" and l.fav[tonumber(spell)] == true
end

-- Turns a recipe's star on or off; false when the list is full.
function Pr.SetFav(spell, on)
    spell = tonumber(spell)
    if not spell then return false end
    local l = lists(true)
    if on and not l.fav[spell] and ns.Count(l.fav) >= FAV_CAP then return false end
    l.fav[spell] = on and true or nil
    ns.Fire("PROF_LISTS_CHANGED")
    return true
end

-- The favourite recipes the data knows, by profession (data order) and name.
function Pr.Favs()
    local l = lists(false)
    local out = {}
    for spell in pairs(l and type(l.fav) == "table" and l.fav or {}) do
        local r = type(spell) == "number" and Pr.Recipe(spell)
        if r then out[#out + 1] = r end
    end
    local order = {}
    for i, skill in ipairs(Pr.Skills()) do order[skill] = i end
    table.sort(out, function(a, b)
        if a.skill ~= b.skill then return (order[a.skill] or 99) < (order[b.skill] or 99) end
        local na, nb = Pr.RecipeName(a), Pr.RecipeName(b)
        if na ~= nb then return na < nb end
        return a.spell < b.spell
    end)
    return out
end

-- The crafting list: { { recipe, n crafts } } in the order added (recipes the data no longer knows left out).
function Pr.Queue()
    local l = lists(false)
    local out = {}
    for _, e in ipairs(l and type(l.queue) == "table" and l.queue or {}) do
        local r = type(e) == "table" and Pr.Recipe(tonumber(e[1]) or 0)
        local n = type(e) == "table" and tonumber(e[2])
        if r and n and n > 0 then out[#out + 1] = { recipe = r, n = n } end
    end
    return out
end

-- Adds n crafts of a recipe (to its entry when it is there already); false when the list is full.
function Pr.QueueAdd(spell, n)
    spell, n = tonumber(spell), math.floor(tonumber(n) or 1)
    if not spell or n < 1 then return false end
    local l = lists(true)
    for _, e in ipairs(l.queue) do
        if type(e) == "table" and e[1] == spell then
            e[2] = math.min(QUEUE_N, (tonumber(e[2]) or 0) + n)
            ns.Fire("PROF_LISTS_CHANGED")
            return true
        end
    end
    if #l.queue >= QUEUE_CAP then return false end
    l.queue[#l.queue + 1] = { spell, math.min(QUEUE_N, n) }
    ns.Fire("PROF_LISTS_CHANGED")
    return true
end

-- Removes a recipe from the crafting list (all of it), or everything without a spell.
function Pr.QueueRemove(spell)
    local l = lists(false)
    if not l or type(l.queue) ~= "table" then return end
    if spell == nil then
        l.queue = {}
    else
        for i = #l.queue, 1, -1 do
            if type(l.queue[i]) == "table" and l.queue[i][1] == tonumber(spell) then table.remove(l.queue, i) end
        end
    end
    ns.Fire("PROF_LISTS_CHANGED")
end

-- The reagents of the crafting list summed: { [item] = count } and whether a recipe's reagents are
-- unknown (the client did not answer).
function Pr.QueueNeeds()
    local need, unknown = {}, false
    for _, e in ipairs(Pr.Queue()) do
        local list = Pr.Reagents(e.recipe.spell)
        if not list then unknown = true end
        for _, g in ipairs(list or {}) do need[g[1]] = (need[g[1]] or 0) + g[2] * e.n end
    end
    return need, unknown
end

-- Whether a writ (crafting order) exists for the item a recipe makes.
function Pr.HasWrit(r)
    local d = data()
    return r.item > 0 and d and d.FAVOR and d.FAVOR.writ and d.FAVOR.writ[r.item] ~= nil or false
end
