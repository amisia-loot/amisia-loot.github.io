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
Pr.TIERS = { [0] = L["Lehrer"], L["Lehrer (Lehrling)"], L["Lehrer (Geselle)"], L["Lehrer (Experte)"], L["Lehrer (Fachmann)"] }
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

local function parse(line, skill)
    local spell, item, count, learn, yellow, grey, src = line:match("^(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(.*)$")
    if not spell then return nil end
    local r = { spell = num(spell), item = num(item), count = num(count), learn = num(learn), yellow = num(yellow),
        grey = num(grey), skill = skill, src = {}, items = {} }
    r.green = math.floor((r.yellow + r.grey) / 2)
    for tok in src:gmatch("[^,]+") do
        local recipeItem = tok:match("^I(%d+)$")
        if recipeItem then r.items[#r.items + 1] = num(recipeItem) else r.src[#r.src + 1] = tok end
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

function Pr.SpellDescription(spell)
    local text
    if C_Spell and C_Spell.GetSpellDescription then text = call(C_Spell.GetSpellDescription, spell) end
    if not text and GetSpellDescription then text = call(GetSpellDescription, spell) end
    text = ns.Plain(text)
    return type(text) == "string" and text ~= "" and text or nil
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
    c[skill] = { rank = tonumber(ns.Plain(info.skillLevel)) or 0, max = tonumber(ns.Plain(info.maxSkillLevel)) or 0,
        day = ns.DropsToday and ns.DropsToday() or 0, known = known }
    ns.Fire("PROF_CHANGED", skill)
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
ns.OnEvent("SKILL_LINES_CHANGED", function() ns.Fire("PROF_CHANGED") end)

---------------------------------------------------------------------------
-- Difficulty
---------------------------------------------------------------------------
-- The colour of a recipe at a rank, as the client's list shows it: "orange", "yellow", "green",
-- "grey"; "red" when it is not known and needs a higher rank to learn; "none" without data.
function Pr.Difficulty(r, rank, known)
    if not rank then return "none" end
    if not known and r.learn > 1 and rank < r.learn then return "red" end
    if r.grey <= 0 then return "none" end
    if rank < r.yellow then return "orange" end
    if rank < r.green then return "yellow" end
    if rank < r.grey then return "green" end
    return "grey"
end

-- Whether the own rank allows learning it.
function Pr.Learnable(r, rank) return rank ~= nil and rank >= r.learn end

---------------------------------------------------------------------------
-- Reagents
---------------------------------------------------------------------------
local reagentCache = {}
function Pr._resetReagents() reagentCache = {} end

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
-- Item -> what the source collector saw: { vendors = { { npc, name, pos, price, rep, own } },
-- drops = { { npc, name, pos, own } } }, rebuilt when the collector changes.
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
                            own = r.own ~= 0 }
                    end
                end
            end
            for npc, s in pairs(type(c.w) == "table" and c.w or {}) do
                local r = ns.CollectParse and ns.CollectParse("w", s)
                if r then
                    for id in pairs(r.items) do
                        local e = obsIndex[id] or { vendors = {}, drops = {} }
                        obsIndex[id] = e
                        e.drops[#e.drops + 1] = { npc = npc, name = r.name, pos = r.pos, own = r.own ~= 0 }
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
        else
            local tier = tok:match("^T(%d)$")
            if tier then add("T", Pr.TIERS[num(tier)] or Pr.TIERS[0]) end
        end
    end
    local myFaction = UnitFactionGroup and ns.Plain((UnitFactionGroup("player"))) or nil
    myFaction = myFaction == "Alliance" and "A" or myFaction == "Horde" and "H" or nil
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
                add("V", L["Händler: %s%s, %s%s"]:format(v.name ~= "" and v.name or ("NPC " .. v.npc), pt and (", " .. pt) or "",
                    money(v.price), v.own and L[" (selbst gesehen)"] or L[" (von der Gilde)"]), point,
                    { npc = v.npc, observed = true, own = v.own, item = itemId })
            end
        end
        for _, v in ipairs(obs and obs.drops or {}) do
            if not listed[v.npc] then
                local pt, point = posText(v.pos)
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
    if #out == 0 then add("?", L["Quelle unbekannt (vermutlich Lehrer)"]) end
    return out
end

-- The source kinds of a recipe for the filter: set of "T" (trainer, with the profession too), "V",
-- "F", "D" (drops of all kinds), "Q".
function Pr.SourceKinds(r)
    local set = {}
    for _, tok in ipairs(r.src) do
        if tok == "A" or tok:match("^T") then set.T = true end
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
    if #r.src == 0 and #r.items == 0 then set.T = true end
    return set
end

---------------------------------------------------------------------------
-- The list the page shows
---------------------------------------------------------------------------
local lower = ns.Fold

-- The recipes of a skill line after the filters: opts.search (part of the recipe or item name, any
-- case), opts.known ("known", "unknown"), opts.learnable (the own rank reaches the learn rank),
-- opts.source ("T", "V", "F", "D", "Q"). Each entry is the recipe with name, known, color.
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
        local name = Pr.RecipeName(r)
        if ok and search then
            local itemName = r.item > 0 and Pr.ItemInfo(r.item) or nil
            ok = lower(name):find(search, 1, true) ~= nil or lower(itemName):find(search, 1, true) ~= nil
        end
        if ok then
            out[#out + 1] = { recipe = r, name = name, known = known, color = Pr.Difficulty(r, rank, known) }
        end
    end
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
    local fac = UnitFactionGroup and ns.Plain((UnitFactionGroup("player"))) or nil
    fac = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
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

-- Whether a writ (crafting order) exists for the item a recipe makes.
function Pr.HasWrit(r)
    local d = data()
    return r.item > 0 and d and d.FAVOR and d.FAVOR.writ and d.FAVOR.writ[r.item] ~= nil or false
end
