-- Amisia best items for the own character: the three best options per slot from
-- the loaded data set (Gear.lua scores them with Amisia's own weights), held against what the
-- character wears, carries and keeps in the bank; exclusions by item, boss and place; what a place
-- still offers. Everything per character in AmisiaDB.bis. Nothing here reads combat data: only the
-- item stats the client shows in every tooltip, the own bags, bank, talents and professions.
local ADDON, ns = ...
local Gear = ns.Gear

local function itemInfo(x)
    local f = C_Item and C_Item.GetItemInfo
    if f then return f(x) end
    return nil
end
local function itemInstant(x)
    local f = C_Item and C_Item.GetItemInfoInstant
    if f then return f(x) end
    return nil
end

local MAX_WISH, NOTE_MAX = 50, 40
ns.BIS_MAX_WISH = MAX_WISH
-- Weapon plans: auto (the larger sum of a two-hander and main hand plus off hand), only a
-- two-hander, two weapons, weapon and shield (or a held item).
ns.BIS_PLANS = { auto = "automatisch", ["2H"] = "Zweihand", DW = "zwei Waffen", SHIELD = "Waffe und Schild" }
ns.BIS_PLAN_ORDER = { "auto", "2H", "DW", "SHIELD" }

local stamp = 0          -- bumped by everything that changes a result; part of every cache key
local function bump() stamp = stamp + 1 end
ns.BisBump = bump
-- The state counter: a page keeps what it showed until this changes.
function ns.BisStamp() return stamp end

---------------------------------------------------------------------------
-- Saved data and its move
---------------------------------------------------------------------------

local function numKey(k)
    local n = tonumber(k)
    if n and n > 0 and n % 1 == 0 then return n end
    return nil
end
local function strKey(k) return (type(k) == "string" and k ~= "") and k or nil end
local function trueVal(v) return v and true or nil end

-- Fixes a table in place: keys through keyOf, values through valOf; nil from either drops the entry.
local function fixSet(t, keyOf, valOf)
    if type(t) ~= "table" then return {} end
    local moves = {}
    for k, v in pairs(t) do
        local nk, nv = keyOf(k), valOf(v)
        if nk == nil or nv == nil then
            moves[#moves + 1] = { k }
        elseif nk ~= k or nv ~= v then
            moves[#moves + 1] = { k, nk, nv }
        end
    end
    for _, m in ipairs(moves) do
        t[m[1]] = nil
        if m[2] ~= nil then t[m[2]] = m[3] end
    end
    return t
end

local function cleanWish(e)
    if type(e) ~= "table" then return nil end
    e.t = tonumber(e.t) or 0
    e.prio = math.max(1, math.min(3, math.floor(tonumber(e.prio) or 2)))
    -- ns.CleanNote (Awards.lua): no bars or line breaks, cut without splitting a character
    e.note = ns.CleanNote(e.note, NOTE_MAX) or ""
    return e
end

local function cleanChar(c)
    c.wish = fixSet(c.wish, numKey, cleanWish)
    -- more than 50: the oldest go
    local list = {}
    for id in pairs(c.wish) do list[#list + 1] = id end
    if #list > MAX_WISH then
        table.sort(list, function(a, b)
            local ta, tb = c.wish[a].t, c.wish[b].t
            if ta ~= tb then return ta > tb end
            return a < b
        end)
        for i = MAX_WISH + 1, #list do c.wish[list[i]] = nil end
    end
    local ex = type(c.ex) == "table" and c.ex or {}
    ex.item = fixSet(ex.item, numKey, trueVal)
    ex.boss = fixSet(ex.boss, strKey, trueVal)
    ex.place = fixSet(ex.place, strKey, trueVal)
    c.ex = ex
    c.bag = fixSet(c.bag, numKey, tonumber)
    c.bank = fixSet(c.bank, numKey, tonumber)
    c.bankAt = tonumber(c.bankAt)
    if c.spec ~= nil and type(c.spec) ~= "string" then c.spec = nil end
    if c.class ~= nil and type(c.class) ~= "string" then c.class = nil end
    -- the weapon plan: auto | 2H | DW | SHIELD
    if c.plan ~= nil and not ns.BIS_PLANS[c.plan] then c.plan = "auto" end
end

-- Settings of the TBC data that WoW Forever has no use for: the content phase, and the source
-- switches for heroic dungeons (H) and reputation (F).
local function dropTbcSettings(root)
    local s = type(root.settings) == "table" and root.settings
    local bis = s and type(s.bis) == "table" and s.bis
    if not bis then return end
    bis.phase = nil
    if type(bis.sources) == "table" then
        bis.sources.H = nil
        bis.sources.F = nil
    end
end

-- Called on ADDON_LOADED (and whenever the table is missing): the shape of AmisiaDB.bis, checked
-- entries, wishes capped at 50; the guild wishes without numeric keys fall away, and so does a
-- guild list for another game. Running it twice changes nothing.
function ns.BisMigrate(root)
    dropTbcSettings(root)
    local b = type(root.bis) == "table" and root.bis or {}
    root.bis = b
    b.v = 1
    b.chars = type(b.chars) == "table" and b.chars or {}
    local drop = {}
    for k, c in pairs(b.chars) do
        if type(k) ~= "string" or type(c) ~= "table" then drop[#drop + 1] = k else cleanChar(c) end
    end
    for _, k in ipairs(drop) do b.chars[k] = nil end
    if b.guild ~= nil then
        if type(b.guild) ~= "table" or b.guild.game ~= "forever" then
            b.guild = nil
        else
            b.guild.list = fixSet(b.guild.list, numKey, function(v) return type(v) == "table" and v or nil end)
        end
    end
    bump()
    return b
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.BisMigrate(AmisiaDB) end
end)

local function db()
    if not AmisiaDB then return nil end
    local b = AmisiaDB.bis
    if type(b) ~= "table" or type(b.chars) ~= "table" then b = ns.BisMigrate(AmisiaDB) end
    return b
end

local function hasSpec(class, key)
    for _, sp in ipairs(Gear.Specs(class)) do
        if sp.key == key then return true end
    end
    return false
end

-- The entry of the logged-in character, made on first use; its spec starts as the Forever planner's
-- choice for the class, when there is one.
function ns.BisChar()
    local b = db()
    if not b then return nil end
    local key = ns.UnitFullName("player") or "?"
    local c = b.chars[key]
    if not c then
        local _, class = UnitClass("player")
        c = { class = class, wish = {}, ex = { item = {}, boss = {}, place = {} }, bag = {}, bank = {} }
        local g = AmisiaDB.settings and AmisiaDB.settings.gear
        local planned = class and type(g) == "table" and type(g.specs) == "table" and g.specs[class] or nil
        if type(planned) == "string" and (not Gear.Available() or hasSpec(class, planned)) then c.spec = planned end
        b.chars[key] = c
    end
    return c
end

---------------------------------------------------------------------------
-- Spec: chosen, else guessed from the talent trees
---------------------------------------------------------------------------

-- Talent tree -> spec keys of the weights, the first that exists wins (a discipline priest falls
-- back to holy where the weights have no discipline; demonology plays like destruction here).
local TREE = {
    WARRIOR = { { "dps" }, { "dps" }, { "tank" } },
    PALADIN = { { "holy" }, { "tank" }, { "ret" } },
    HUNTER = { { "dps" }, { "dps" }, { "dps" } },
    ROGUE = { { "dps" }, { "dps" }, { "dps" } },
    PRIEST = { { "disc", "holy" }, { "holy" }, { "shadow" } },
    SHAMAN = { { "ele" }, { "enh" }, { "resto" } },
    MAGE = { { "arcane" }, { "fire" }, { "frost" } },
    WARLOCK = { { "affli" }, { "destro", "affli" }, { "destro" } },
    DRUID = { { "balance" }, { "feral" }, { "resto" } },
}
ns.BIS_TREE = TREE

-- Points spent in a talent tree: C_SpecializationInfo.GetSpecializationInfo (7th return), else the
-- compatibility GetTalentTabInfo (5th); nil when the client tells nothing.
local function treePoints(i)
    local info = _G.C_SpecializationInfo
    local fn = type(info) == "table" and info.GetSpecializationInfo
    if type(fn) == "function" then
        local ok, _, _, _, _, _, _, pts = pcall(fn, i)
        pts = ok and ns.Plain(pts) or nil
        if type(pts) == "number" then return pts end
    end
    if type(_G.GetTalentTabInfo) == "function" then
        local ok, _, _, _, _, pts = pcall(_G.GetTalentTabInfo, i)
        pts = ok and ns.Plain(pts) or nil
        if type(pts) == "number" then return pts end
    end
    return nil
end

local guess, guessClass   -- cached guess (false: none), for the class it was made for
local function guessSpec(class)
    local best, bestPts = nil, 0
    for i, keys in ipairs(TREE[class] or {}) do
        local pts = treePoints(i)
        if pts and pts > bestPts then
            for _, key in ipairs(keys) do
                if hasSpec(class, key) then best, bestPts = key, pts break end
            end
        end
    end
    if best then return best end
    local first = Gear.Specs(class)[1]
    return first and first.key or false
end

-- The spec in use and whether it is guessed.
function ns.BisSpec()
    local _, class = UnitClass("player")
    local c = ns.BisChar()
    if c and c.spec and hasSpec(class, c.spec) then return c.spec, false end
    if guess == nil or guessClass ~= class then guess, guessClass = guessSpec(class), class end
    return guess or nil, true
end

-- Chooses a spec (nil: guess again).
function ns.BisSetSpec(key)
    local c = ns.BisChar()
    if not c then return end
    c.spec = key
    guess = nil
    ns.Fire("BIS_CHANGED")
end

-- The weapon plan of the own character (ns.BIS_PLANS); true, or nil and the reason.
function ns.BisSetPlan(plan)
    local c = ns.BisChar()
    if not c then return nil, "Amisia ist noch nicht geladen." end
    if not ns.BIS_PLANS[plan] then return nil, "Waffenplan: auto, 2H, DW oder SHIELD." end
    c.plan = plan
    ns.Fire("BIS_CHANGED")
    return true
end

---------------------------------------------------------------------------
-- Own professions
---------------------------------------------------------------------------

local PROF_BY_NAME, PROF_ID = Gear.PROF_BY_NAME, Gear.PROF_ID
local PROF_BY_ID = {}
for k, v in pairs(PROF_ID) do PROF_BY_ID[v] = k end

local skills   -- cached { tailoring = 375, [197] = 375 }, false when the client cannot tell
local function addSkill(out, key, rank)
    rank = tonumber(rank) or 0
    if not key then return end
    out[key] = math.max(out[key] or 0, rank)
    out[PROF_ID[key]] = out[key]
end

-- The own professions with skill, or nil when the client offers no skill list (the chip "nur
-- meine" then has no use). C_SkillInfo gives a table per line (SkillLineAttributes).
function ns.BisSkills()
    if skills ~= nil then return skills or nil end
    local out, readable = {}, false
    local info = _G.C_SkillInfo
    if type(info) == "table" and type(info.GetNumSkillLines) == "function" and type(info.GetSkillLineInfo) == "function" then
        readable = true
        local ok, n = pcall(info.GetNumSkillLines)
        for i = 1, (ok and tonumber(n)) or 0 do
            local ok2, s = pcall(info.GetSkillLineInfo, i)
            if ok2 and type(s) == "table" and not s.isHeader then
                addSkill(out, PROF_BY_ID[s.skillID] or (type(s.name) == "string" and PROF_BY_NAME[s.name:lower()]), s.rank)
            end
        end
    end
    skills = readable and out or false
    return skills or nil
end

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------

-- The source switches of the page (window state settings.bis.sources): everything but the auction
-- house and PvP vendors.
local function sourceState()
    local s = AmisiaDB and AmisiaDB.settings
    if not s then return { X = true, D = true, V = true, C = true, W = true, Q = true } end
    s.bis = type(s.bis) == "table" and s.bis or {}
    if type(s.bis.sources) ~= "table" then
        s.bis.sources = { X = true, D = true, V = true, C = true, W = true, Q = true, A = false, P = false }
    end
    return s.bis.sources
end

-- The scoring switches every option set carries: random suffixes, set plan, effort tie, BiS picks.
local function scoringOpts(o)
    o.suffix = ns.Get("bis.suffix") or "best"
    o.picks = ns.Get("bis.picks") ~= false
    o.sets = ns.Get("bis.sets") ~= false
    o.tie = tonumber(ns.Get("bis.effortTie")) or 3
    return o
end

-- The options of the own character: class, spec (guessed), weighting kind, faction (A/H), level up
-- to the data's cap, source switches, professions ("all"/"mine") with the own skills, the
-- exclusions, the weapon plan, the scoring switches and (bis.hitCap) the hit still useful per row.
function ns.BisOpts()
    local c = ns.BisChar()
    local _, class = UnitClass("player")
    local spec, guessed = ns.BisSpec()
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    local o = {
        class = class, spec = spec, guessed = guessed, kind = ns.Get("gear.kind") or "Speedrun",
        faction = fac == "Horde" and "H" or fac == "Alliance" and "A" or nil,
        level = math.max(1, math.min(tonumber(UnitLevel("player")) or 1, Gear.Cap())),
        sources = sourceState(),
        prof = ns.Get("bis.prof") or "all", skills = ns.BisSkills(),
        exclude = c and c.ex or nil,
        plan = c and c.plan or "auto",
    }
    scoringOpts(o)
    o.cap = ns.BisHitCaps and ns.BisHitCaps(o) or nil
    return o
end

-- The same calculation for any class, spec and level (the simulation and the planner table):
-- no ownership, no exclusions, both factions unless opts.faction, the own source switches unless
-- opts.sources. Returns Gear.Best's result.
function ns.BisFor(class, spec, level, opts)
    opts = opts or {}
    local o = {
        class = class, spec = spec or (Gear.Specs(class)[1] or {}).key, kind = opts.kind or ns.Get("gear.kind") or "Speedrun",
        faction = opts.faction, level = math.max(1, math.min(tonumber(level) or 1, Gear.Cap())),
        sources = opts.sources or sourceState(), prof = "all", plan = opts.plan or "auto", exclude = opts.exclude,
    }
    scoringOpts(o)
    if opts.tie ~= nil then o.tie = opts.tie end
    if opts.picks ~= nil then o.picks = opts.picks end
    return Gear.Best(o)
end

local function sortedKeys(t, onlyTrue)
    local out = {}
    if type(t) ~= "table" then return "" end
    for k, v in pairs(t) do
        if not onlyTrue or v then out[#out + 1] = tostring(k) .. (onlyTrue and "" or ("=" .. tostring(v))) end
    end
    table.sort(out)
    return table.concat(out, ",")
end

local function capKey(cap)
    if type(cap) ~= "table" then return "" end
    local out = {}
    for row, c in pairs(cap) do
        out[#out + 1] = ("%s:%s:%s"):format(row, tostring(c.HIT and math.floor(c.HIT * 100 + 0.5)),
            tostring(c.SHIT and math.floor(c.SHIT * 100 + 0.5)))
    end
    table.sort(out)
    return table.concat(out, ",")
end

-- Everything a result depends on, as one string.
local function optsKey(o)
    local ex = o.exclude or {}
    return table.concat({ tostring(ns.GEAR), tostring(ns.BIS), stamp, tostring(o.class), tostring(o.spec), tostring(o.level),
        tostring(o.kind), tostring(o.faction), tostring(o.prof), sortedKeys(o.sources, true), sortedKeys(o.skills),
        sortedKeys(ex.item, true), sortedKeys(ex.boss, true), sortedKeys(ex.place, true), tostring(o.plan),
        tostring(o.suffix), tostring(o.sets), tostring(o.tie), tostring(o.picks), capKey(o.cap) }, "|")
end

---------------------------------------------------------------------------
-- Ownership: worn (live), bags (scanned after bag changes), bank (while open, else the client's count)
---------------------------------------------------------------------------

local wornCache   -- { links = { [inv] = link }, ids = { [id] = inv } }, nil = read again
local function worn()
    if wornCache then return wornCache end
    local w = { links = {}, ids = {} }
    if GetInventoryItemLink then
        for _, sl in ipairs(Gear.SLOTS) do
            local link = ns.Plain(GetInventoryItemLink("player", sl.inv))
            if type(link) == "string" then
                w.links[sl.inv] = link
                local id = ns.ItemID(link)
                if id then w.ids[id] = sl.inv end
            end
        end
    end
    wornCache = w
    return w
end

local ownListeners = {}
-- fn() runs after the own items changed (worn, bags, bank).
function ns.BisOnOwned(fn) ownListeners[#ownListeners + 1] = fn end
local function ownedChanged()
    bump()
    for _, fn in ipairs(ownListeners) do
        local ok, err = pcall(fn)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end
end

-- "worn", "bag", "bank" or nil.
function ns.BisOwned(item)
    local id = tonumber(item) or ns.ItemID(item)
    if not id then return nil end
    if worn().ids[id] then return "worn" end
    local c = ns.BisChar()
    if c and c.bag[id] then return "bag" end
    if c and c.bank[id] then return "bank" end
    -- without a bank visit: the client's count with the bank against the one without
    local count = C_Item and C_Item.GetItemCount
    if type(count) == "function" then
        local ok, inBags = pcall(count, id)
        local ok2, all = pcall(count, id, true)
        inBags, all = ok and ns.Plain(inBags), ok2 and ns.Plain(all)
        if type(all) == "number" and type(inBags) == "number" and all > inBags then return "bank" end
    end
    return nil
end

-- Kept are items of the data, wishes and anything wearable; no materials, no quest items.
local function keepId(id, c)
    if Gear.Item(id) or (c and c.wish[id]) then return true end
    local _, _, _, loc, _, classID = itemInstant(id)
    if type(loc) ~= "string" or loc == "" or not (classID == 2 or classID == 4) then return false end
    return Gear.GROUP[(loc:gsub("^INVTYPE_", ""))] ~= nil
end

local function readContainers(bags, c)
    local C = _G.C_Container
    local numSlots = type(C) == "table" and C.GetContainerNumSlots
    local itemID = type(C) == "table" and C.GetContainerItemID
    if type(numSlots) ~= "function" or type(itemID) ~= "function" then return nil end
    local out = {}
    for _, bag in ipairs(bags) do
        for slot = 1, tonumber(numSlots(bag)) or 0 do
            local id = itemID(bag, slot)
            if type(id) == "number" and keepId(id, c) then out[id] = true end
        end
    end
    return out
end

-- Stores the ids seen now (time of the sighting); what is gone falls away. True when the set changed.
local function applySeen(seen, set)
    local t, changed = time(), false
    for id in pairs(seen) do
        if not set[id] then seen[id] = nil; changed = true end
    end
    for id in pairs(set) do
        if not seen[id] then changed = true end
        seen[id] = t
    end
    return changed
end

local function bagList()
    local out = {}
    for b = 0, tonumber(_G.NUM_BAG_SLOTS) or 4 do out[#out + 1] = b end
    return out
end

local bagPending = false
local function scanBags()
    bagPending = false
    local c = ns.BisChar()
    local set = c and readContainers(bagList(), c)
    if set and applySeen(c.bag, set) then ownedChanged() end
end
ns.BisScanBags = scanBags

-- Bag events come in bursts: one scan a second at most.
local function scheduleBags()
    if bagPending then return end
    bagPending = true
    C_Timer.After(1, scanBags)
end

-- The bank's containers: the purchased tabs of the character bank (C_Bank; there is no bank -1).
function ns.BankTabs()
    local B = _G.C_Bank
    local kind = Enum and Enum.BankType and Enum.BankType.Character
    if type(B) ~= "table" or type(B.FetchPurchasedBankTabIDs) ~= "function" or kind == nil then return nil end
    local ok, tabs = pcall(B.FetchPurchasedBankTabIDs, kind)
    if not ok or type(tabs) ~= "table" then return nil end
    local out = {}
    for _, id in ipairs(tabs) do out[#out + 1] = id end
    return out
end

local bankOpen, bankPending = false, false
local function scanBank()
    bankPending = false
    if not bankOpen then return end
    local c = ns.BisChar()
    local list = c and ns.BankTabs()
    local set = list and readContainers(list, c)
    if not set then return end
    c.bankAt = time()
    if applySeen(c.bank, set) then ownedChanged() end
end
local function scheduleBank()
    if bankPending or not bankOpen then return end
    bankPending = true
    C_Timer.After(0.2, scanBank)
end

ns.OnEvent("BANKFRAME_OPENED", function() bankOpen = true; scanBank() end)
ns.OnEvent("BANKFRAME_CLOSED", function() bankOpen = false end)
ns.OnEvent("PLAYERBANKSLOTS_CHANGED", scheduleBank)
ns.OnEvent("BAG_UPDATE_DELAYED", function()
    scheduleBags()
    -- Forever's bank tabs are bags: their changes come as bag updates
    if bankOpen then scheduleBank() end
end)
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", function()
    wornCache = nil
    ownedChanged()
end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    wornCache, bankOpen = nil, false
    bump()
    scheduleBags()
end)

---------------------------------------------------------------------------
-- Scoring one item against what is worn
---------------------------------------------------------------------------

local SLOT_OF = { HEAD = "HEAD", NECK = "NECK", SHOULDER = "SHOULDER", BACK = "BACK", CHEST = "CHEST", WRIST = "WRIST",
    HANDS = "HANDS", WAIST = "WAIST", LEGS = "LEGS", FEET = "FEET", FINGER = "FINGER1", TRINKET = "TRINKET1",
    ["2H"] = "MAINHAND", ["1H"] = "MAINHAND", MH = "MAINHAND", OHW = "OFFHAND", SHIELD = "OFFHAND", HELD = "OFFHAND",
    RANGED = "RANGED" }
local KIND_OF = { ["2H"] = "2H", ["1H"] = "MH", MH = "MH", OHW = "OH", RANGED = "RANGED" }
local SLOT_NAME = {}
local SLOT_INV = {}
for _, sl in ipairs(Gear.SLOTS) do SLOT_NAME[sl.key], SLOT_INV[sl.key] = sl.name, sl.inv end
ns.BIS_SLOT_NAME = SLOT_NAME

local function linkGroup(link)
    local _, _, _, loc = itemInstant(link)
    return type(loc) == "string" and Gear.GROUP[(loc:gsub("^INVTYPE_", ""))] or nil
end

-- Scores of what is worn, per slot, for one weighting: kept until the gear or the weighting changes.
local ctxCache, ctxKey
local function context(o)
    local key = table.concat({ tostring(ns.GEAR), stamp, tostring(o.class), tostring(o.spec), tostring(o.kind), tostring(o.level),
        capKey(o.cap) }, "|")
    if ctxKey == key then return ctxCache end
    local w = worn()
    local ctx, partial = { slot = {} }, false
    for _, sl in ipairs(Gear.SLOTS) do
        local link = w.links[sl.inv]
        local v = 0
        if link then
            v = Gear.ScoreLink(link, sl.key, o)
            if not v then v, partial = 0, true end
        end
        ctx.slot[sl.key] = v
    end
    local s = ctx.slot
    ctx.ring = math.min(s.FINGER1, s.FINGER2)
    ctx.trinket = math.min(s.TRINKET1, s.TRINKET2)
    ctx.twoWorn = w.links[16] and linkGroup(w.links[16]) == "2H" or false
    if not partial then ctxCache, ctxKey = ctx, key end
    return ctx
end

-- The hit cap: hit rating counts up to this much hit in percent against a target two levels
-- higher (Classic's 6 % for weapons and spells, to be confirmed in game).
local HIT_CAP, SPELL_HIT_CAP = 6, 6
local CR_HIT_MELEE, CR_HIT_SPELL = 6, 8
ns.BIS_HIT_CAP = HIT_CAP

local function plainNumber(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, ...)
    v = ok and tonumber(ns.Plain(v)) or nil
    return v
end

-- The own hit in percent from the character sheet: melee/ranged and spell; nil where the client
-- has no API for it.
function ns.BisOwnHit()
    local melee = plainNumber(GetCombatRatingBonus, CR_HIT_MELEE)
    local spell = plainNumber(GetCombatRatingBonus, CR_HIT_SPELL)
    if melee then melee = melee + (plainNumber(GetHitModifier) or 0) end
    if spell then spell = spell + (plainNumber(GetSpellHitModifier) or 0) end
    return melee, spell
end

local capCache, capKeyOf
-- The hit still useful per row (bis.hitCap): the cap minus the own hit without the item worn in
-- that row, { [row] = { HIT = %, SHIT = % } }; nil when the switch is off or the client cannot say
-- (hit then counts without a cap).
function ns.BisHitCaps(o)
    if not ns.Get("bis.hitCap") then return nil end
    local melee, spell = ns.BisOwnHit()
    if not melee and not spell then return nil end
    local w = worn()
    local key = table.concat({ tostring(w), tostring(o.level), tostring(melee), tostring(spell) }, "|")
    if capKeyOf == key then return capCache end
    local caps = {}
    for _, sl in ipairs(Gear.SLOTS) do
        local link = w.links[sl.inv]
        local s = link and Gear.ReadStats(link) or {}
        -- worn hit converted as Gear.lua's terms do: generic hit at the melee rate for the melee
        -- side and at the spell rate for the spell side
        local m = ((s.HIT or 0) + (s.MHIT or 0)) * Gear.RatingPerPoint("HIT", o.level)
        local sp = ((s.HIT or 0) + (s.SHIT or 0)) * Gear.RatingPerPoint("SHIT", o.level)
        caps[sl.key] = { HIT = melee and math.max(0, HIT_CAP - (melee - m)) or nil,
            SHIT = spell and math.max(0, SPELL_HIT_CAP - (spell - sp)) or nil }
    end
    capCache, capKeyOf = caps, key
    return caps
end

-- The worn scores per slot for the options, as a copy: { slot = { [slotKey] = score }, two = a
-- two-hander is worn }. The dungeon chain equips items on it virtually.
function ns.BisWornScores(o)
    local ctx = context(o or ns.BisOpts())
    local slot = {}
    for k, v in pairs(ctx.slot) do slot[k] = v end
    return { slot = slot, two = ctx.twoWorn }
end

local function minGain() return tonumber(ns.Get("bis.minGain")) or 2 end

-- Whether a gain is worth calling an upgrade: more than a point and more than bis.minGain percent.
function ns.BisIsUpgrade(gain, mine)
    if type(gain) ~= "number" then return false end
    return gain > math.max(1, math.abs(mine or 0) * minGain() / 100)
end

-- The weaker of two rows (the first on a tie).
local function weakerOf(ctx, a, b)
    return (ctx.slot[a] or 0) <= (ctx.slot[b] or 0) and a or b
end

-- gain, mine, switch, against for an item of a group scored score, in the row slotKey; against
-- lists the rows compared with (the weaker ring or trinket, both hands for a two-hander).
local function gainFor(slotKey, group, id, score, ctx)
    local mine, against
    if slotKey == "FINGER1" or slotKey == "FINGER2" then
        mine, against = ctx.ring, { weakerOf(ctx, "FINGER1", "FINGER2") }
    elseif slotKey == "TRINKET1" or slotKey == "TRINKET2" then
        mine, against = ctx.trinket, { weakerOf(ctx, "TRINKET1", "TRINKET2") }
    elseif slotKey == "MAINHAND" then
        if group == "2H" then
            mine, against = ctx.slot.MAINHAND + ctx.slot.OFFHAND, { "MAINHAND", "OFFHAND" }
        elseif ctx.twoWorn then
            return nil, ctx.slot.MAINHAND, true, { "MAINHAND" }
        else
            mine, against = ctx.slot.MAINHAND, { "MAINHAND" }
        end
    elseif slotKey == "OFFHAND" then
        if ctx.twoWorn then return nil, ctx.slot.MAINHAND, true, { "MAINHAND" } end
        mine, against = ctx.slot.OFFHAND, { "OFFHAND" }
    else
        mine, against = ctx.slot[slotKey] or 0, { slotKey }
    end
    if id and worn().ids[id] then return 0, mine, false, against end
    return score - mine, mine, false, against
end

local function rowType(id)
    local row = Gear.Item(id)
    if row and row[1] ~= "" then return row[1], row[2], row[3], row end
    local _, _, _, loc, _, classID, sub = itemInstant(id)
    if type(loc) ~= "string" or loc == "" then return nil end
    return (loc:gsub("^INVTYPE_", "")), classID, sub, row
end

-- The slot group of an item ("HEAD", "FINGER", "2H", "1H", "SHIELD", ...), or nil when it is no gear.
function ns.BisGroup(id)
    local loc = rowType(id)
    return loc and Gear.GROUP[loc] or nil
end

-- BiS picks for the own character (Gear.PicksFor with the options' plan and exclusions; none with
-- o.picks == false): the pick an item is in its rows (slotKey, and the second ring or trinket row),
-- and whether a pick other than the item is worn in a row it is compared against. A pick is the
-- slot's target: the pick itself counts as an upgrade until it is worn, and while a pick is worn
-- nothing else is an upgrade for that row (gain at most 0).
local SECOND_ROW = { FINGER1 = "FINGER2", TRINKET1 = "TRINKET2" }

-- The line of a pick for explanations and tooltips: "BiS-Empfehlung: <note> (<source>)".
function ns.BisPickText(p)
    if type(p) ~= "table" then return nil end
    local note = type(p.note) == "string" and p.note ~= "" and (": " .. p.note) or ""
    local src = type(p.src) == "string" and p.src ~= "" and (" (" .. p.src .. ")") or ""
    return "BiS-Empfehlung" .. note .. src
end
local function pickState(o, id, slotKey, against)
    if o.picks == false or not o.class then return nil, false end
    local picks = Gear.PicksFor(o.class, o.spec, o.level, o.plan, o.exclude)
    if not next(picks) then return nil, false end
    local pick
    for _, key in ipairs({ slotKey, SECOND_ROW[slotKey] }) do
        if picks[key] and picks[key].item == id then pick = picks[key] end
    end
    local wornIds = worn().ids
    local pickWorn = false
    for _, key in ipairs(against or {}) do
        local p = picks[key]
        if p and p.item ~= id and wornIds[p.item] then pickWorn = true end
    end
    return pick, pickWorn
end

-- Everything about one item for the own character: { id, s, w, kind, group, slotKey, score, gain,
-- mine, switch, pick, pickWorn } or { reason, code }.
local function evaluate(item, o)
    if not Gear.Available() then return { reason = "Für diesen Client gibt es keine Ausrüstungsdaten.", code = "nodata" } end
    local id = tonumber(item) or ns.ItemID(item)
    if not id then return { reason = "Kein Item.", code = "noitem" } end
    o = o or ns.BisOpts()
    local loc, classID, sub, row = rowType(id)
    local group = loc and Gear.GROUP[loc]
    if not group or not (classID == 2 or classID == 4) then return { id = id, reason = "Keine Ausrüstung.", code = "notgear" } end
    local cannot = { id = id, reason = "Das kann dein Charakter nicht tragen.", code = "class" }
    if not o.class or not Gear.Usable(o.class, { loc, classID, sub or 0 }, o.level, o.spec) then return cannot end
    if row and (row[8] or 0) > 0 and not Gear.HasClassBit(row[8], o.class) then return cannot end
    local s
    if type(item) == "string" and item:find("item:", 1, true) then s = Gear.ReadStats(item) end
    if not s then
        local failed
        s, failed = Gear.Stats(id)
        if not s then return { id = id, reason = "Werte fehlen noch.", code = failed and "nostats" or "loading" } end
    end
    if s.CLASSES and not s.CLASSES[o.class] then return cannot end
    local w = Gear.Weights(o.class, o.spec, o.kind, o.level)
    if not w then return { id = id, reason = "Keine Gewichtung.", code = "noweights" } end
    local kind = KIND_OF[group]
    local slotKey = SLOT_OF[group]
    local cap = o.cap and o.cap[Gear.CAP_ROW[group] or slotKey]
    local score = Gear.Score(s, w, o.level, kind, o.class, cap)
    local gain, mine, switch, against = gainFor(slotKey, group, id, score, context(o))
    local pick, pickWorn = pickState(o, id, slotKey, against)
    return { id = id, s = s, w = w, kind = kind, group = group, slotKey = slotKey, score = score, gain = gain, mine = mine,
        switch = switch, row = row, against = against, cap = cap, pick = pick, pickWorn = pickWorn }
end

-- What an item (id or link; a link counts its random suffix) brings the own character:
-- gain, slotKey, mine, score; or nil, reason (German), code ("switch" with the slot as 4th value,
-- "nodata", "noitem", "notgear", "class", "loading", "nostats", "noweights").
function ns.BisGain(item, opts)
    local ev = evaluate(item, opts)
    if ev.reason then return nil, ev.reason, ev.code end
    if ev.switch then return nil, "Waffenwechsel", "switch", ev.slotKey end
    if ev.pickWorn then return math.min(ev.gain, 0), ev.slotKey, ev.mine, ev.score end
    return ev.gain, ev.slotKey, ev.mine, ev.score
end

-- The level an item needs when it is above the own one (C_Item.GetItemInfo, fifth value), else nil.
local function laterLevel(item)
    local info = C_Item and C_Item.GetItemInfo
    if type(info) ~= "function" then return nil end
    local ok, _, _, _, _, minLevel = pcall(info, item)
    minLevel = ok and tonumber(ns.Plain(minLevel)) or nil
    local level = tonumber(ns.Plain(UnitLevel("player")))
    if minLevel and level and minLevel > level then return minLevel end
    return nil
end

-- The one comparison with the worn gear every display uses (tooltip, roll frames, quest rewards,
-- the roll window, the answers to "Wer braucht das?"): { gain, pct, mine, score, slotKey, up,
-- against = { worn links }, weaker, later } or nil, reason (German), code as ns.BisGain ("switch"
-- with the slot as 4th value). pct is the gain in percent of the worn score, nil for an empty slot;
-- weaker says a ring or trinket is compared with the weaker of the two worn; later is the level the
-- item needs when it is above the own (then it is no upgrade yet); pick is the BiS pick when the item
-- is one (then it is an upgrade until worn), pickWorn says a pick is worn in the compared row (then
-- nothing else is an upgrade there).
function ns.UpgradeOf(item, opts)
    local o = opts or ns.BisOpts()
    local ev = evaluate(item, o)
    if ev.reason then return nil, ev.reason, ev.code end
    if ev.switch then return nil, "Waffenwechsel", "switch", ev.slotKey end
    local mine = ev.mine or 0
    local u = { gain = ev.gain, mine = mine, score = ev.score, slotKey = ev.slotKey, against = {},
        weaker = (ev.group == "FINGER" or ev.group == "TRINKET") or nil }
    if mine > 0 then u.pct = math.floor(ev.gain / mine * 100 + 0.5) end
    local w = worn()
    for _, key in ipairs(ev.against or {}) do
        local link = w.links[SLOT_INV[key]]
        if link then u.against[#u.against + 1] = link end
    end
    u.later = laterLevel(type(item) == "string" and item or ev.id)
    u.pick, u.pickWorn = ev.pick, ev.pickWorn or nil
    if ev.pickWorn then
        u.up = false
    else
        u.up = (not u.later and not w.ids[ev.id] and (ev.pick ~= nil or ns.BisIsUpgrade(ev.gain, mine))) and true or false
    end
    return u
end

-- The short text of a comparison for an item mark: "+12%", "neu" (an empty slot), "ab 62" (a level
-- above the own) or "-8%"; nil when there is nothing to say.
function ns.UpgradeShort(u)
    if type(u) ~= "table" or type(u.gain) ~= "number" then return nil end
    if u.later then return u.gain > 0 and ("ab %d"):format(u.later) or nil end
    if u.pct then return ("%+d%%"):format(u.pct) end
    if u.up then return "neu" end
    return nil
end

-- The score of an item explained as German lines: what it scores against what is worn, then every
-- part ("30 Stärke x 2,0 = 60").
function ns.BisExplain(item, opts)
    local o = opts or ns.BisOpts()
    local ev = evaluate(item, o)
    if ev.reason then return { ev.reason } end
    local sp = Gear.SpecInfo(o.class, o.spec)
    local who = (sp and sp.name or tostring(o.spec)) .. (o.guessed and " (geraten)" or "")
    local lines = {}
    if ev.switch then
        lines[1] = ("%s · %s: Wertung %s, Waffenwechsel gegen die Zweihandwaffe (%s)"):format(who, SLOT_NAME[ev.slotKey],
            Gear.Num(ev.score), Gear.Num(ev.mine or 0))
    else
        lines[1] = ("%s · %s: Wertung %s, angelegt %s, %s"):format(who, SLOT_NAME[ev.slotKey], Gear.Num(ev.score),
            Gear.Num(ev.mine or 0), Gear.UnitText(ev.gain, ev.w))
    end
    for _, p in ipairs(Gear.ScoreParts(ev.s, ev.w, o.level, ev.kind, o.class, ev.cap)) do
        lines[#lines + 1] = Gear.PartText(p)
    end
    if ev.s.SC then lines[#lines + 1] = "Werte berechnet (noch nicht gescannt)" end
    if ev.pick then lines[#lines + 1] = ns.BisPickText(ev.pick) end
    if (ev.s.HIT or ev.s.MHIT or ev.s.SHIT) and not ev.cap then lines[#lines + 1] = "Trefferwertung zählt ohne Obergrenze" end
    return lines
end

-- The parts of a score by key (the stats of an item for the options), and the evaluation. item is
-- an id, a link or an option of ns.BisTargets / Gear.Best ({ id = ..., suffix = ..., setb = ... }
-- or { id, score, suffix = ..., setb = ... }): an option counts the random suffix and the share of
-- the set bonus its ranking counted.
local function partsOf(item, o)
    local opt = type(item) == "table" and item or nil
    local ev = evaluate(opt and (opt.id or opt[1]) or item, o)
    if ev.reason then return nil, ev end
    if opt and (opt.suffix or opt.setb) then
        local s = ev.s
        local variants = opt.suffix and Gear.SuffixStats(ev.id)
        if variants and variants[opt.suffix] then s = variants[opt.suffix] end
        if opt.setb then
            local c = {}
            for k, v in pairs(s) do c[k] = v end
            c.SETB = opt.setb
            s = c
        end
        ev.s = s
        ev.score = Gear.Score(s, ev.w, o.level, ev.kind, o.class, ev.cap)
    end
    local by = {}
    for _, p in ipairs(Gear.ScoreParts(ev.s, ev.w, o.level, ev.kind, o.class, ev.cap)) do
        if not p.over then by[p.key] = p end
    end
    return by, ev
end

-- a against b (ids, links or options of ns.BisTargets, see partsOf): { lines = { "+24 Stärke
-- (+48)", ... } largest first, diff = score of a minus b, text = "Option 1 liegt 21 vorn, vor allem
-- durch Stärke." } or nil, reason. names (optional): { "Option 1", "Option 2" } for the sentence.
function ns.BisCompare(a, b, opts, names)
    local o = opts or ns.BisOpts()
    local pa, ea = partsOf(a, o)
    if not pa then return nil, ea.reason end
    local pb, eb = partsOf(b, o)
    if not pb then return nil, eb.reason end
    local rows = {}
    local keys = {}
    for k in pairs(pa) do keys[k] = true end
    for k in pairs(pb) do keys[k] = true end
    for k in pairs(keys) do
        local x, y = pa[k], pb[k]
        local dp = (x and x.points or 0) - (y and y.points or 0)
        if math.abs(dp) >= 0.5 then
            local p = x or y
            local amount
            if k == "SPEED" then
                amount = ("%s s"):format(Gear.Num(((x and x.value) or 0) - ((y and y.value) or 0), 1))
            elseif p.amount and p.amount:find("%%") then
                -- a rating part: its percent is points / weight
                local function pct(q) return (q and q.weight ~= 0) and q.points / q.weight or 0 end
                local d = pct(x) - pct(y)
                amount = ("%s%s %%"):format(d >= 0 and "+" or "", Gear.Num(d, 1))
            else
                local d = ((x and x.value) or 0) - ((y and y.value) or 0)
                amount = ("%s%s"):format(d >= 0 and "+" or "", Gear.Num(d))
            end
            rows[#rows + 1] = { key = k, points = dp, text = ("%s %s (%+d)"):format(amount, p.label, math.floor(dp + 0.5)) }
        end
    end
    table.sort(rows, function(r1, r2)
        if math.abs(r1.points) ~= math.abs(r2.points) then return math.abs(r1.points) > math.abs(r2.points) end
        return r1.key < r2.key
    end)
    local lines = {}
    for _, r in ipairs(rows) do lines[#lines + 1] = r.text end
    local diff = ea.score - eb.score
    local na, nb = (names and names[1]) or "Das erste", (names and names[2]) or "das zweite"
    local lead = rows[1]
    for _, r in ipairs(rows) do
        if (diff >= 0) == (r.points >= 0) then lead = r break end
    end
    local text
    if math.abs(diff) < 0.5 then
        text = ("%s und %s liegen gleichauf."):format(na, nb)
    elseif diff > 0 then
        text = ("%s liegt %d vorn%s."):format(na, math.floor(diff + 0.5),
            lead and (", vor allem durch " .. ((pa[lead.key] or pb[lead.key]).label)) or "")
    else
        text = ("%s liegt %d vorn%s."):format(nb:gsub("^%l", string.upper), math.floor(-diff + 0.5),
            lead and (", vor allem durch " .. ((pb[lead.key] or pa[lead.key]).label)) or "")
    end
    return { lines = lines, diff = diff, text = text }
end

-- Why the weights are as they are: the spec's reason, its unit and the reference character of the
-- bracket ("Bezug Level 30: 410 Angriffskraft, 22 Waffen-DPS, 14 % Krit").
local REF_LABEL = { AP = "Angriffskraft", wDPS = "Waffen-DPS", crit = "% Krit", SP = "Zauberschaden", HEAL = "Heilung",
    mana = "Mana", HP = "Gesundheit", armor = "Rüstung", avoid = "% Vermeidung", spell = "Grundschaden des Bezugszaubers" }
local REF_ORDER = { "AP", "SP", "HEAL", "HP", "wDPS", "crit", "mana", "armor", "avoid", "spell" }
function ns.BisWhy(o)
    o = o or ns.BisOpts()
    local sp = Gear.SpecInfo(o.class, o.spec)
    if not sp then return {} end
    local lines = {}
    if sp.why then lines[#lines + 1] = sp.why end
    local w = Gear.Weights(o.class, o.spec, o.kind, o.level)
    local unit = Gear.Unit(w)
    if unit then lines[#lines + 1] = ("Ein Punkt Wertung ist so viel wert wie 1 %s."):format(Gear.UNIT_LABELS[unit]) end
    local brackets = ns.GEAR_WEIGHTS and ns.GEAR_WEIGHTS.brackets or {}
    local idx
    for i, upper in ipairs(brackets) do
        if o.level <= upper then idx = i break end
    end
    local ref = type(sp.ref) == "table" and sp.ref[idx or #brackets]
    if type(ref) == "table" then
        local parts = {}
        for _, k in ipairs(REF_ORDER) do
            local v = tonumber(ref[k])
            if v then parts[#parts + 1] = ("%s %s"):format(Gear.Num(v), REF_LABEL[k]) end
        end
        lines[#lines + 1] = ("Bezug Level %d: %s"):format(brackets[idx or #brackets] or o.level, table.concat(parts, ", "))
    end
    return lines
end

---------------------------------------------------------------------------
-- Targets: the best three per slot
---------------------------------------------------------------------------

local function emptyResult()
    local r = { plan = "1H", missing = 0, total = 0, upgrades = 0, mine = {}, state = {} }
    for _, sl in ipairs(Gear.SLOTS) do r[sl.key] = {} end
    return r
end

local function wishOf(c, id) return c and c.wish[id] ~= nil or false end

local targetKey, targetRes
local targetOwnStamp   -- the stamp at which targetRes was made with the own options, else nil
-- Per slot up to three options { id, score, gain, mine, owned, wished, worn, upgrade, switch },
-- best first; r.state[slot] "done" (option 1 worn), "bag"/"bank" (option 1 owned, not worn),
-- "switch", "upgrade", "none" or nil (no option); r.mine[slot] the worn score; r.upgrades; the
-- weapon plan as Gear.Best has it. Kept until anything it depends on changes.
function ns.BisTargets(opts)
    if not Gear.Available() then return emptyResult() end
    local o = opts or ns.BisOpts()
    if not o.class then return emptyResult() end
    local key = optsKey(o)
    if key == targetKey then
        if not opts then targetOwnStamp = stamp end
        return targetRes
    end
    local best = Gear.Best(o)
    local r = emptyResult()
    r.plan, r.missing, r.total = best.plan, best.missing, best.total
    r.twoHandScore, r.oneHandScore = best.twoHandScore, best.oneHandScore
    r.dwScore, r.shieldScore, r.planWanted, r.sets = best.dwScore, best.shieldScore, best.planWanted, best.sets
    local ctx = context(o)
    local c = ns.BisChar()
    for _, sl in ipairs(Gear.SLOTS) do
        local list, out = best[sl.key] or {}, r[sl.key]
        for i = 1, math.min(3, #list) do
            local id, score = list[i][1], list[i][2]
            local row = Gear.Item(id)
            local group = row and Gear.GROUP[row[1]]
            local gain, mine, switch = gainFor(sl.key, group, id, score, ctx)
            local owned = ns.BisOwned(id)
            local src = list[i]
            out[i] = { id = id, score = score, gain = gain, mine = mine, owned = owned, worn = owned == "worn",
                wished = wishOf(c, id), switch = switch or nil,
                upgrade = (not switch and owned ~= "worn" and (src.pick ~= nil or ns.BisIsUpgrade(gain, mine))) or false,
                sc = src.sc, suffix = src.suffix, easier = src.easier, set = src.set, setb = src.setb,
                effort = src.effort, pick = src.pick }
        end
        -- a BiS pick worn in the row: it is the target, nothing else is an upgrade there
        if out[1] and out[1].pick and out[1].worn then
            for i = 2, #out do out[i].upgrade = false end
        end
        r.mine[sl.key] = ctx.slot[sl.key]
        local first = out[1]
        local state
        if first then
            if first.worn then state = "done"
            elseif first.switch then state = "switch"
            elseif first.owned then state = first.owned
            elseif first.upgrade then state = "upgrade"
            else state = "none" end
            if first.upgrade then r.upgrades = r.upgrades + 1 end
        end
        r.state[sl.key] = state
    end
    targetKey, targetRes = key, r
    targetOwnStamp = (not opts) and stamp or nil
    return r
end

-- The targets of the own character when they are at hand for the current state, else nil; never
-- computes them.
function ns.BisTargetsCached()
    if targetOwnStamp ~= nil and targetOwnStamp == stamp then return targetRes end
    return nil
end

---------------------------------------------------------------------------
-- Exclusions
---------------------------------------------------------------------------

-- kind "item" (id or link), "boss" (name as in the source) or "place" ("I:<instance>", "Z:<map>",
-- "N:<name>"). on false lifts it. true or nil, reason.
function ns.BisExclude(kind, key, on)
    local c = ns.BisChar()
    if not c then return nil, "Amisia ist noch nicht geladen." end
    if on == nil then on = true end
    local set
    if kind == "item" then
        key = tonumber(key) or ns.ItemID(key)
        if not key then return nil, "Kein Item." end
        set = c.ex.item
    elseif kind == "boss" then
        if type(key) ~= "string" or key == "" then return nil, "Kein Boss." end
        set = c.ex.boss
    elseif kind == "place" then
        if type(key) ~= "string" or not key:find("^[IZN]:.") then return nil, "Kein Ort." end
        set = c.ex.place
    else
        return nil, "Unbekannte Art."
    end
    set[key] = on and true or nil
    ns.Fire("BIS_CHANGED")
    return true
end

-- Lifts every exclusion; returns how many there were.
function ns.BisClearExcludes()
    local c = ns.BisChar()
    if not c then return 0 end
    local n = 0
    for _, set in pairs(c.ex) do
        for k in pairs(set) do set[k] = nil; n = n + 1 end
    end
    ns.Fire("BIS_CHANGED")
    return n
end

-- How many exclusions there are.
function ns.BisExcludeCount()
    local c = ns.BisChar()
    local n = 0
    for _, set in pairs(c and c.ex or {}) do
        for _ in pairs(set) do n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Here: what a place still offers
---------------------------------------------------------------------------

-- The player's place: in an instance its id and name; outside the map and its parents up to the
-- continent.
local function currentPlace()
    local name, itype, diff, _, _, _, _, instID = GetInstanceInfo()
    name, itype, diff, instID = ns.Plain(name), ns.Plain(itype), ns.Plain(diff), ns.Plain(instID)
    if type(itype) == "string" and itype ~= "none" and type(instID) == "number" and instID > 0 then
        local keys = { ["I:" .. instID] = true }
        if type(name) == "string" and name ~= "" then keys["N:" .. name] = true end
        return { key = "I:" .. instID, keys = keys, text = type(name) == "string" and name or nil }
    end
    local map = C_Map and C_Map.GetBestMapForUnit and ns.Plain(C_Map.GetBestMapForUnit("player"))
    local keys, first, text = {}, nil, nil
    for _ = 1, 10 do
        if type(map) ~= "number" or map <= 0 then break end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        if type(info) ~= "table" or (tonumber(info.mapType) or 3) <= 2 then break end
        keys["Z:" .. map] = true
        if not first then first, text = map, info.name end
        map = info.parentMapID
    end
    if not first then return nil end
    return { key = "Z:" .. first, keys = keys, text = text }
end
-- The player's place as "Hier" finds it ({ key, keys, text }), or nil; nothing is listed.
ns.BisCurrentPlace = currentPlace

local placesCache, placesFor
-- The raids and dungeons of the data for the place picker: { { key, text, raid } }, raids first.
function ns.BisPlaces()
    local d = ns.GEAR
    if not d then return {} end
    if placesFor == d and placesCache then return placesCache end
    local seen, out = {}, {}
    for _, rec in ipairs(d.S) do
        if rec[1] == "X" or rec[1] == "D" then
            local base = Gear.PlaceOf(rec)
            if base then
                if not seen[base] then
                    seen[base] = true
                    out[#out + 1] = { key = base, text = Gear.PlaceName(rec) or base, raid = rec[1] == "X" }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.raid ~= b.raid then return a.raid end
        if a.text ~= b.text then return a.text < b.text end
        return a.key < b.key
    end)
    placesCache, placesFor = out, d
    return out
end

local function placeFor(key)
    local text
    for _, p in ipairs(ns.BisPlaces()) do
        if p.key == key then text = p.text end
    end
    return { key = key, keys = { [key] = true }, text = text }
end

local hereKey, herePlace, hereList
-- place, list: the place (current, or placeKey from the picker) and its items that are upgrades or
-- wishes for the options, { id, rec, score, gain, mine, owned, wished, upgrade, switch }, by gain
-- with owned items at the bottom. place.loading counts items still waiting for their stats.
function ns.BisHere(placeKey, opts)
    local place = placeKey and placeFor(placeKey) or currentPlace()
    if not place or not Gear.Available() then return place, {} end
    local o = opts or ns.BisOpts()
    if not o.class then return place, {} end
    local key = optsKey(o) .. "|" .. place.key
    if key == hereKey then return herePlace, hereList end
    local d = ns.GEAR
    -- the sources at this place first, then the items that have one
    local at = {}
    for n, rec in ipairs(d.S) do
        local p = Gear.PlaceOf(rec)
        if p and place.keys[p] then at[n] = rec end
    end
    local c = ns.BisChar()
    local exItem = o.exclude and o.exclude.item or {}
    local list, loading = {}, 0
    if next(at) then
        for id, row in pairs(d.I) do
            local hit
            for i = Gear.FIRST_SOURCE, #row do
                local rec = at[row[i]]
                if rec and Gear.SourceOk(rec, o, row) then hit = rec break end
            end
            if hit and not exItem[id] then
                if (row[4] or 0) <= o.level then
                    local ev = evaluate(id, o)
                    if ev.code == "loading" then loading = loading + 1 end
                    if not ev.reason then
                        local wished = wishOf(c, id)
                        local up = not ev.switch and ns.BisIsUpgrade(ev.gain, ev.mine)
                        if up or wished then
                            list[#list + 1] = { id = id, rec = hit, slotKey = ev.slotKey, score = ev.score, gain = ev.gain, mine = ev.mine,
                                owned = ns.BisOwned(id), wished = wished, upgrade = up or false, switch = ev.switch or nil }
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        local oa, ob = a.owned and 1 or 0, b.owned and 1 or 0
        if oa ~= ob then return oa < ob end
        local ga, gb = a.gain or -1e9, b.gain or -1e9
        if ga ~= gb then return ga > gb end
        return a.id < b.id
    end)
    place.loading = loading
    hereKey, herePlace, hereList = key, place, list
    return place, list
end

---------------------------------------------------------------------------
-- What changes a result
---------------------------------------------------------------------------

local function talentsChanged() guess = nil; bump() end
ns.OnEvent("CHARACTER_POINTS_CHANGED", talentsChanged)
ns.OnEvent("PLAYER_TALENT_UPDATE", talentsChanged)
ns.OnEvent("ACTIVE_TALENT_GROUP_CHANGED", talentsChanged)
ns.OnEvent("PLAYER_LEVEL_UP", bump)
ns.OnEvent("SKILL_LINES_CHANGED", function() skills = nil; bump() end)
ns.Listen("SETTING", bump)
ns.Listen("BIS_CHANGED", function() guess = nil; bump() end)
Gear.OnData(bump)

---------------------------------------------------------------------------
-- Tooltip line
---------------------------------------------------------------------------

local TIP_GREEN = { 0.31, 0.82, 0.42 }
local TIP_GREY = { 0.56, 0.53, 0.64 }
local TIP_ORANGE = { 1, 0.6, 0.2 }
local TIP_PARTS = 4             -- explanation lines on Shift
local TIP_CACHE_MAX = 200       -- links kept per state
local WARM_GAP = 2              -- seconds between two deferred target computations

-- The rows an item of a group competes for in the targets.
local RANK_SLOTS = { FINGER = { "FINGER1", "FINGER2" }, TRINKET = { "TRINKET1", "TRINKET2" },
    ["2H"] = { "MAINHAND" }, ["1H"] = { "MAINHAND", "OFFHAND" }, MH = { "MAINHAND" }, OHW = { "OFFHAND" },
    SHIELD = { "OFFHAND" }, HELD = { "OFFHAND" } }

-- The targets are never computed inside a hover: when they are missing, once after it (at most
-- every WARM_GAP seconds), so the next hover has them.
local warmPending, warmAt = false, nil
local function warmTargets()
    if warmPending then return end
    warmPending = true
    local t = GetTime and GetTime() or 0
    local wait = warmAt and math.max(0, WARM_GAP - (t - warmAt)) or 0
    C_Timer.After(wait, function()
        warmPending = false
        warmAt = GetTime and GetTime() or 0
        if ns.BisTargetsCached() then return end
        local ok, err = pcall(ns.BisTargets)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end)
end

-- Rank (1-3) and row of an item among the cached targets.
local function targetRank(res, id, group)
    for _, slotKey in ipairs(RANK_SLOTS[group] or { SLOT_OF[group] }) do
        for i, e in ipairs(res[slotKey] or {}) do
            if e.id == id then return i, slotKey end
        end
    end
    return nil
end

-- The line (and on Shift the explanation) for one link: { { text, color }, ... }, plus whether it
-- was made without the targets and whether it may be kept (not while stats are still loading).
-- "statt Helm B", "statt Ring (schwächerer Ring)", "statt Axt + Schild": what an item is compared with.
local function againstText(u)
    local names = {}
    for _, link in ipairs(u.against) do
        names[#names + 1] = link:match("|h%[(.-)%]|h") or ns.ItemName(ns.ItemID(link))
    end
    if #names == 0 then return nil end
    local text = "statt " .. table.concat(names, " + ")
    if u.weaker then
        text = text .. (u.slotKey == "FINGER1" and " (schwächerer Ring)" or " (schwächerer Schmuck)")
    end
    return text
end

local function tipLines(link, id, shift)
    local u, _, code = ns.UpgradeOf(link)
    if not u then
        if code == "switch" then return { { "Waffenwechsel für dich", TIP_GREY } }, false, true end
        return {}, false, code ~= "loading"
    end
    local gain, slotKey, mine = u.gain, u.slotKey, u.mine
    local compare = ns.Get("bis.compare") ~= false
    local c = ns.BisChar()
    local isWorn = worn().ids[id] ~= nil
    -- a BiS pick is the slot's target: an upgrade until worn; while one is worn nothing else is
    local up = not isWorn and not u.pickWorn and (u.pick ~= nil or ns.BisIsUpgrade(gain, mine))
    local text, color, noTargets = nil, TIP_GREY, false
    local vs = up               -- the worn item goes under an upgrade or a "Kein Upgrade" line
    local points = math.floor(gain + 0.5)
    local slotName = SLOT_NAME[slotKey] or ""
    if up and compare then
        local head = u.later and ("Upgrade für dich ab Stufe %d"):format(u.later) or "Upgrade für dich"
        if u.pct then
            text = ("%s: %+d %% (%+d, %s)"):format(head, u.pct, points, slotName)
        else
            text = ("%s: %+d (%s, Platz leer)"):format(head, points, slotName)
        end
        color = u.later and TIP_ORANGE or TIP_GREEN
    elseif up then
        text, color = ("Upgrade für dich: %+d (%s)"):format(points, slotName), TIP_GREEN
    else
        local res = ns.BisTargetsCached()
        local rank, rankSlot
        if res then
            local loc = rowType(id)
            rank, rankSlot = targetRank(res, id, loc and Gear.GROUP[loc])
        else
            noTargets = true
            warmTargets()
        end
        if rank then
            text = (isWorn and "angelegt, " or "") .. ("Option %d für %s"):format(rank, SLOT_NAME[rankSlot] or "")
        elseif not isWorn and ns.Get("bis.tooltipNone") then
            vs = true
            if compare and u.pct then
                text = ("Kein Upgrade für dich (%+d, %+d %%)"):format(points, u.pct)
            else
                text = ("Kein Upgrade für dich (%+d)"):format(points)
            end
        end
    end
    if not text and u.pick then text, color = ("BiS-Empfehlung für dich (%s)"):format(slotName), TIP_GREEN end
    if not text then return {}, noTargets, true end
    if c and c.wish[id] then text = text .. " · auf deiner Wunschliste" end
    local out = { { text, color } }
    if u.pick then out[#out + 1] = { ns.BisPickText(u.pick), TIP_GREEN } end
    local against = compare and vs and againstText(u)
    if against then out[#out + 1] = { against, TIP_GREY } end
    if shift then
        local ex = ns.BisExplain(link)
        -- the first line is the head (spec, slot, scores); the parts follow, biggest first
        for i = 2, math.min(#ex, TIP_PARTS + 1) do out[#out + 1] = { ex[i], TIP_GREY } end
    end
    return out, noTargets, true
end

-- Lines per link and Shift state, kept until anything changes (the stamp); an entry made without
-- the targets is made again once they are there.
local tipCache, tipCacheStamp, tipCacheN = {}, nil, 0
local placeOnly = {}            -- the place line alone (upgrade line off), per text

-- On Shift the place of the item (Map.lua's "Fundort" line, cached there per item and state), or
-- nil; an error goes to the error handler and leaves the other lines.
local function placeLine(id, shift)
    if not shift or not ns.MapTooltipLine then return nil end
    local ok, line = pcall(ns.MapTooltipLine, id)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(line) end
        return nil
    end
    return line
end

function ns.BisTooltipLines(link)
    if not Gear.Available() then return nil end
    local id = ns.ItemID(link)
    if not id then return nil end
    local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
    local place = placeLine(id, shift)
    if tipCacheStamp ~= stamp or tipCacheN >= TIP_CACHE_MAX then
        tipCache, tipCacheStamp, tipCacheN, placeOnly = {}, stamp, 0, {}
    end
    if not ns.Get("bis.tooltip") then
        if not place then return nil end
        local only = placeOnly[place]
        if not only then
            only = { { place, TIP_GREY } }
            placeOnly[place] = only
        end
        return only
    end
    local key = shift and (link .. "|S") or link
    local e = tipCache[key]
    if e and e.noTargets and ns.BisTargetsCached() then e = nil end
    if not e then
        local lines, noTargets, keep = tipLines(link, id, shift)
        e = { lines = lines, noTargets = noTargets }
        if keep then
            tipCache[key] = e
            tipCacheN = tipCacheN + 1
        end
    end
    if not place then return e.lines end
    -- the place goes under the lines, kept with them until it changes
    if e.place ~= place then
        local full = {}
        for i, l in ipairs(e.lines) do full[i] = l end
        full[#full + 1] = { place, TIP_GREY }
        e.place, e.full = place, full
    end
    return e.full
end

ns.OnItemTooltip("bis", function(tip, link)
    local lines = ns.BisTooltipLines(link)
    if not lines or #lines == 0 then return false end
    for _, l in ipairs(lines) do tip:AddLine(l[1], l[2][1], l[2][2], l[2][3]) end
    return true
end)

---------------------------------------------------------------------------
-- Wishlist
---------------------------------------------------------------------------

local PRIO_TEXT = { [3] = "hoch", [2] = "mittel", [1] = "niedrig" }
ns.BIS_PRIO_TEXT = PRIO_TEXT

local function clampPrio(p)
    p = math.floor(tonumber(p) or 2)
    return math.max(1, math.min(3, p))
end

local function itemName(id, link)
    local name = itemInfo(id)
    if type(name) == "string" and name ~= "" then return name end
    name = type(link) == "string" and link:match("|h%[(.-)%]|h")
    return name or ("Item " .. id)
end

-- Whether the own class can wear an item, by its type alone (at the data's level cap, so plate
-- for a level 30 warrior counts). Unknown to the client: no item.
local function wearable(id)
    local _, _, _, instLoc = itemInstant(id)
    if instLoc == nil and not Gear.Item(id) then return nil, "Kein Item." end
    local loc, classID, sub, row = rowType(id)
    local group = loc and Gear.GROUP[loc]
    local _, class = UnitClass("player")
    local cannot = "Das kann dein Charakter nicht tragen."
    if not group or not (classID == 2 or classID == 4) then return nil, cannot end
    if class and not Gear.Usable(class, { loc, classID, sub or 0 }, Gear.Cap(), (ns.BisSpec())) then return nil, cannot end
    if class and row and (row[8] or 0) > 0 and not Gear.HasClassBit(row[8], class) then return nil, cannot end
    return true
end

-- Adds a wish (id or link) or changes its priority (3 high, 2 medium, 1 low) and note.
-- Returns the entry, or nil and the reason.
function ns.WishAdd(item, prio, note)
    local c = ns.BisChar()
    if not c then return nil, "Amisia ist noch nicht geladen." end
    local id = tonumber(item) or ns.ItemID(item)
    if not id or id <= 0 or id % 1 ~= 0 then return nil, "Kein Item." end
    local e = c.wish[id]
    if not e then
        local ok, why = wearable(id)
        if not ok then return nil, why end
        local n = 0
        for _ in pairs(c.wish) do n = n + 1 end
        if n >= MAX_WISH then return nil, ("Die Wunschliste ist voll (%d)."):format(MAX_WISH) end
        e = { t = time(), prio = clampPrio(prio), note = ns.CleanNote(note, NOTE_MAX) or "" }
        c.wish[id] = e
    else
        if prio ~= nil then e.prio = clampPrio(prio) end
        if note ~= nil then e.note = ns.CleanNote(note, NOTE_MAX) or "" end
    end
    ns.Fire("BIS_CHANGED")
    return e
end

function ns.WishRemove(item)
    local c = ns.BisChar()
    local id = tonumber(item) or ns.ItemID(item)
    if not c or not id or not c.wish[id] then return nil end
    c.wish[id] = nil
    ns.Fire("BIS_CHANGED")
    return true
end

function ns.WishSetPrio(item, prio)
    local c = ns.BisChar()
    local id = tonumber(item) or ns.ItemID(item)
    local e = c and id and c.wish[id]
    if not e then return nil end
    e.prio = clampPrio(prio)
    ns.Fire("BIS_CHANGED")
    return e
end

-- The wishes { id, e, owned, slot (German), src (best source, short), name, excluded }, by priority,
-- then name.
function ns.Wishes()
    local c = ns.BisChar()
    local out = {}
    if not c then return out end
    local o = Gear.Available() and ns.BisOpts() or nil
    for id, e in pairs(c.wish) do
        local loc = rowType(id)
        local group = loc and Gear.GROUP[loc]
        local slotKey = group and SLOT_OF[group]
        local src
        if o then
            local rec = Gear.Sources(id, o)[1] or Gear.Sources(id)[1]
            src = rec and Gear.SourceText(rec, true) or nil
        end
        out[#out + 1] = { id = id, e = e, owned = ns.BisOwned(id), slot = slotKey and SLOT_NAME[slotKey] or nil, slotKey = slotKey,
            src = src, name = itemName(id), excluded = c.ex.item[id] or nil }
    end
    table.sort(out, function(a, b)
        if a.e.prio ~= b.e.prio then return a.e.prio > b.e.prio end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

-- The wishes as text for the website's wishlist tab: "#AMISIA 2 <name>", one WL line per wish
-- (priority down, then item id; the note is the last field and may hold spaces), "#END". Not part of
-- the raid export.
function ns.WishExportText()
    local c = ns.BisChar()
    local name = ns.ExportName(ns.UnitFullName("player") or "?")
    local lines = { "#AMISIA 2 " .. name }
    local ids = {}
    for id in pairs(c and c.wish or {}) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local pa, pb = c.wish[a].prio or 2, c.wish[b].prio or 2
        if pa ~= pb then return pa > pb end
        return a < b
    end)
    for _, id in ipairs(ids) do
        local e = c.wish[id]
        -- WL <itemID> <prio 1-3> <epoch> <name> [<note>]
        local note = tostring(e.note or ""):gsub("|", ""):gsub("%c", " "):match("^%s*(.-)%s*$")
        lines[#lines + 1] = ("WL %d %d %d %s%s"):format(id, clampPrio(e.prio), tonumber(e.t) or 0, name, note ~= "" and (" " .. note) or "")
    end
    lines[#lines + 1] = "#END"
    return table.concat(lines, "\n")
end

-- Self clean-up (bis.wishAutoRemove): a wish that is worn, in the bags or in the bank goes.
local function cleanWishes()
    if not ns.Get("bis.wishAutoRemove") then return end
    local c = ns.BisChar()
    if not c or not next(c.wish) then return end
    local gone = {}
    for id in pairs(c.wish) do
        if ns.BisOwned(id) then gone[#gone + 1] = id end
    end
    if #gone == 0 then return end
    table.sort(gone)
    for _, id in ipairs(gone) do
        c.wish[id] = nil
        ns.msg(("%s von deiner Wunschliste genommen, du hast das Item."):format(itemName(id)))
    end
    ns.Fire("BIS_CHANGED")
end
ns.BisOnOwned(cleanWishes)

-- The own loot line ("You receive loot: ...") takes a wish off at once and reads the bags.
ns.OnEvent("CHAT_MSG_LOOT", function(text)
    text = ns.Plain(text)
    if type(text) ~= "string" then return end
    local who, id = ns.ParseLoot(text)
    if not who or not ns.SameName(who, ns.UnitFullName("player")) then return end
    local c = ns.BisChar()
    if c and c.wish[id] and ns.Get("bis.wishAutoRemove") then
        c.wish[id] = nil
        ns.msg(("%s von deiner Wunschliste genommen, du hast das Item."):format(itemName(id)))
        ns.Fire("BIS_CHANGED")
    end
    -- gear read at once; herbs and ore wait for the next bag update
    if c and keepId(id, c) then scanBags() end
end)

---------------------------------------------------------------------------
-- Toast: a wish or an upgrade drops
---------------------------------------------------------------------------

local TOAST_SECONDS, TOAST_MAX, TOAST_AGAIN = 8, 3, 120
local TOAST_Y = -60
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80" }
local GOLD = { 0.89, 0.72, 0.34 }
local toastFrame, current
local waiting = {}        -- toasts after the shown one, oldest first
local lastToast = {}      -- item id -> time of its last toast
local token = 0

local showNext

local function closeToast()
    token = token + 1
    current = nil
    if toastFrame then
        toastFrame.id, toastFrame.link, toastFrame.slotKey, toastFrame.hover = nil, nil, nil, false
        toastFrame:Hide()
    end
    showNext()
end

local function buildToast()
    -- the client's tooltip ground and border (TooltipBackdropTemplate); the flat ground with a gold
    -- frame of before when the template is missing or lacks its NineSlice. Made without a name so a
    -- rejected try leaves no frame under it; the name is set after the probe.
    local ok, f = pcall(CreateFrame, "Button", nil, UIParent, "TooltipBackdropTemplate")
    if ok and f and not f.NineSlice then
        f:Hide()
        f:ClearAllPoints()
        ok = false
    end
    if ok and f then
        _G.AmisiaBisToast = f
    else
        f = CreateFrame("Button", "AmisiaBisToast", UIParent)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.055, 0.04, 0.08, 0.94)
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
                             { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
            local t = f:CreateTexture(nil, "BORDER")
            t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.7)
            t:SetPoint(e[1]); t:SetPoint(e[2])
            if e[3] then t:SetWidth(e[3]) end
            if e[4] then t:SetHeight(e[4]) end
        end
    end
    f:SetSize(320, 58)
    -- high up, 60-118 px below the top: clear of the award dialog and the roll window (from about
    -- 124 px down on the smallest screen) and above the client's error line (122 px down)
    f:SetPoint("TOP", UIParent, "TOP", 0, TOAST_Y)
    -- above the main window and the roll windows; only the mouse, never the keyboard
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(36, 36)
    f.icon:SetPoint("LEFT", 11, 0)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local function line(template, y)
        local fs = f:CreateFontString(nil, "OVERLAY", template)
        fs:SetPoint("TOPLEFT", 56, y)
        fs:SetWidth(256)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    f.title = line("GameFontNormal", -7)
    f.item = line("GameFontHighlightSmall", -24)
    f.source = line("GameFontDisableSmall", -39)
    f:SetScript("OnEnter", function(self)
        self.hover = true
        if self.link and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function(self)
        self.hover = false
        if GameTooltip then GameTooltip:Hide() end
    end)
    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then closeToast() return end
        if self.link and IsShiftKeyDown and IsShiftKeyDown() then
            -- into the open chat box, else a chat box opened with it (a modified click only
            -- inserts into one that is open)
            local util = type(ChatFrameUtil) == "table" and ChatFrameUtil or {}
            local insert = util.InsertLink
            if not (type(insert) == "function" and insert(self.link)) then
                local open = util.OpenChat
                if type(open) == "function" then open(self.link) end
            end
            return
        end
        local slotKey = self.slotKey
        closeToast()
        if ns.ShowGear then ns.ShowGear("goals", slotKey) end
    end)
    f:Hide()
    return f
end

local function expire(my)
    if my ~= token or not toastFrame then return end
    if toastFrame.hover or toastFrame:IsMouseOver() then
        C_Timer.After(1, function() expire(my) end)
        return
    end
    closeToast()
end

local function show(entry)
    toastFrame = toastFrame or buildToast()
    local f = toastFrame
    token = token + 1
    current = entry
    f.id, f.link, f.slotKey, f.hover = entry.id, entry.link, entry.slotKey, false
    local _, link, q, _, _, _, _, _, _, icon = itemInfo(entry.id)
    if not icon then icon = select(5, itemInstant(entry.id)) end
    q = q or ns.LinkQuality(entry.link) or 4
    f.icon:SetTexture(icon or 134400)
    if entry.why == "wish" then
        f.title:SetText("Wunsch droppt!")
        f.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        f.title:SetText("Upgrade für dich")
        f.title:SetTextColor(0.31, 0.82, 0.42)
    end
    local extra = ""
    if entry.gain and entry.slotKey and entry.pct and ns.Get("bis.compare") ~= false then
        extra = (" %+d %% (%+d, %s)"):format(entry.pct, math.floor(entry.gain + 0.5), SLOT_NAME[entry.slotKey] or "")
    elseif entry.gain and entry.slotKey then
        extra = (" %+d (%s)"):format(math.floor(entry.gain + 0.5), SLOT_NAME[entry.slotKey] or "")
    end
    f.item:SetText(("|c%s%s|r%s"):format(QUALITY[q] or QUALITY[4], itemName(entry.id, entry.link or link), extra))
    f.source:SetText(entry.src or "")
    f:Show()
    if entry.why == "wish" and ns.Get("bis.toastSound") and type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        pcall(PlaySound, SOUNDKIT.RAID_WARNING)
    end
    local my = token
    C_Timer.After(TOAST_SECONDS, function() expire(my) end)
end

showNext = function()
    if current then return end
    local entry = table.remove(waiting, 1)
    if entry then show(entry) end
end

-- Shows a toast for an item: why "wish" or "upgrade", the link (for the name and the shift-click)
-- and where it was seen. One at a time; at most three at once, the oldest waiting one goes.
function ns.BisToast(id, why, link, src)
    id = tonumber(id) or ns.ItemID(id)
    if not id then return end
    local entry = { id = id, why = why, link = link, src = src }
    local u = ns.UpgradeOf(link or id)
    entry.slotKey = u and SLOT_NAME[u.slotKey] and u.slotKey or nil
    entry.gain = u and u.gain or nil
    entry.pct = u and u.pct or nil
    if not entry.slotKey then
        local loc = rowType(id)
        local group = loc and Gear.GROUP[loc]
        entry.slotKey = group and SLOT_OF[group] or nil
    end
    waiting[#waiting + 1] = entry
    while (current and 1 or 0) + #waiting > TOAST_MAX do table.remove(waiting, 1) end
    showNext()
end

-- Test and page hook: the shown toast's item and the waiting ones.
function ns.BisToastState()
    local q = {}
    for i, e in ipairs(waiting) do q[i] = e.id end
    return { shown = current and current.id or nil, queue = q, frame = toastFrame }
end

local function inPvP()
    local kind
    if type(IsInInstance) == "function" then
        local _, t = IsInInstance()
        kind = ns.Plain(t)
    else
        local _, t = GetInstanceInfo()
        kind = ns.Plain(t)
    end
    return kind == "pvp" or kind == "arena"
end

-- One item seen dropping: a toast when it is a wish, else when it is an upgrade (bis.toastUpgrade);
-- never for an owned item, never twice in two minutes, never in battlegrounds and arenas.
local function consider(link, src)
    link = ns.Plain(link)
    local id = ns.ItemID(link)
    if not id then return end
    local t = time()
    if lastToast[id] and t - lastToast[id] < TOAST_AGAIN then return end
    if ns.BisOwned(id) then return end
    local c = ns.BisChar()
    local why
    if c and c.wish[id] then
        why = "wish"
    elseif ns.Get("bis.toastUpgrade") and Gear.Available() then
        local u = ns.UpgradeOf(link)
        if u and u.up then why = "upgrade" end
    end
    if not why then return end
    lastToast[id] = t
    ns.BisToast(id, why, link, src)
end

-- Every trigger runs protected: an error goes to the error handler, never into the client's event.
local function guarded(fn)
    return function(...)
        if not ns.Get("bis.toast") or inPvP() then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(err) end
        end
    end
end

local function plainString(v)
    v = ns.Plain(v)
    return (type(v) == "string" and v ~= "") and v or nil
end

ns.OnEvent("LOOT_OPENED", guarded(function()
    for slot = 1, (GetNumLootItems and ns.Plain(GetNumLootItems()) or 0) do
        local link = GetLootSlotLink and plainString(GetLootSlotLink(slot))
        if link then
            local src
            if type(ns.LootSourceName) == "function" then
                local ok, name = pcall(ns.LootSourceName, slot)
                src = ok and plainString(name) or nil
            end
            consider(link, (src and src ~= "?") and src or "Lootfenster")
        end
    end
end))

ns.OnEvent("START_LOOT_ROLL", guarded(function(rollID)
    rollID = ns.Plain(rollID)
    if type(rollID) ~= "number" or type(_G.GetLootRollItemLink) ~= "function" then return end
    local ok, link = pcall(_G.GetLootRollItemLink, rollID)
    if ok then consider(plainString(link), "Würfeln") end
end))

-- item links in a chat line: coloured links, as the client sends them
local function eachLink(text, fn)
    for link in text:gmatch("|c%x%x%x%x%x%x%x%x|Hitem:.-|h|r") do fn(link) end
end

-- The loot lead's announcement: a numbered item line in the raid chat ("1. [Item] SR: ..."), or a
-- raid warning with an item link (a roll start). Secret text (a boss fight on Forever) is skipped.
local function onRaidChat(text)
    if ns.ChatLocked() then return end
    text = plainString(text)
    if not text or not text:find("^%d+%. |c") then return end
    eachLink(text, function(link) consider(link, "Ansage") end)
end
ns.OnEvent("CHAT_MSG_RAID", guarded(onRaidChat))
ns.OnEvent("CHAT_MSG_RAID_LEADER", guarded(onRaidChat))
ns.OnEvent("CHAT_MSG_RAID_WARNING", guarded(function(text)
    if ns.ChatLocked() then return end
    text = plainString(text)
    if text then eachLink(text, function(link) consider(link, "Ansage") end) end
end))

---------------------------------------------------------------------------
-- Page, settings, commands
---------------------------------------------------------------------------

local VIEW_OF = { goals = "goals", ziele = "goals", here = "here", hier = "here", wish = "wish", wunsch = "wish",
    wunschliste = "wish", guild = "guild", gilde = "guild", dungeons = "dungeons", dungeon = "dungeons", sim = "sim",
    simulation = "sim" }

-- Opens the gear page in a view ("goals", "here", "dungeons", "wish", "guild" or the German words)
-- with a slot chosen. The page reads settings.bis.view, settings.bis.slot and settings.bis.place; "here" starts
-- at the player's own place again.
function ns.ShowGear(view, slotKey)
    local s = AmisiaDB and AmisiaDB.settings
    if s then
        s.bis = type(s.bis) == "table" and s.bis or {}
        local v = VIEW_OF[tostring(view or ""):lower()]
        s.bis.view = v or s.bis.view or "goals"
        if v == "here" then s.bis.place = nil end
        if slotKey then s.bis.slot = slotKey end
    end
    if ns.ShowPage then ns.ShowPage("gear") end
end

-- /amisia bis item <link>: the explanation in the own chat, with the client's raw stats.
function ns.BisItemReport(arg)
    arg = tostring(arg or "")
    local id = ns.ItemID(arg) or tonumber(arg)
    if not id then
        ns.msg("Aufruf: /amisia bis item <Item-Link>")
        return
    end
    if not Gear.Available() then
        ns.msg("Für diesen Client gibt es keine Ausrüstungsdaten.")
        return
    end
    local item = arg:find("item:", 1, true) and arg or id
    for _, line in ipairs(ns.BisExplain(item)) do ns.msg(line) end
    -- what the client itself answered, so a stat name Amisia does not know shows up
    local raw = C_Item.GetItemStats(type(item) == "string" and item or ("item:" .. id))
    if type(raw) == "table" then
        local parts = {}
        for k, v in pairs(raw) do parts[#parts + 1] = (Gear.STAT[k] and "" or "|cffe0a344?|r") .. k .. "=" .. tostring(v) end
        table.sort(parts)
        ns.msg("Client: " .. table.concat(parts, " "))
    end
end

ns.RegisterSettings{ key = "bis", label = "Ausrüstung und Wünsche", order = 45, available = function() return Gear.Available() end, items = {
    { key = "bis.tooltip", type = "toggle", label = "Tooltip-Zeile \"Upgrade für dich\"", default = true },
    { key = "bis.compare", type = "toggle", label = "Mit angelegter Ausrüstung vergleichen (Prozent)", default = true,
      tip = "Prozent und verglichenes Item im Tooltip, Markierung an Würfelfenstern und Questbelohnungen, Upgrade-Spalte im Roll-Fenster." },
    { key = "bis.tooltipNone", type = "toggle", label = "Auch \"Kein Upgrade\" im Tooltip zeigen", default = false },
    { key = "bis.minGain", type = "slider", label = "Upgrade erst ab (Prozent mehr Wertung)", default = 2, min = 0, max = 10, step = 1,
      expert = true },
    { key = "bis.toast", type = "toggle", label = "Hinweis, wenn ein Wunsch droppt", default = true,
      tip = "Aus dem Lootfenster, beim Würfeln und aus der Loot-Ansage im Schlachtzugschat." },
    { key = "bis.toastUpgrade", type = "toggle", label = "Hinweis auch für andere Upgrades", default = true },
    { key = "bis.toastSound", type = "toggle", label = "Ton beim Wunsch-Hinweis", default = true },
    { key = "bis.wishAutoRemove", type = "toggle", label = "Erhaltene Wünsche von der Liste nehmen", default = true },
    { key = "bis.suffix", type = "choice", label = "Zufallsboni", default = "best",
      values = { { "best", "bester gesehener" }, { "base", "nur Grundwerte" } },
      tip = "Items mit Zufallsbonus (\"...des Adlers\") zählen mit dem besten Bonus, den Amisia an ihnen gesehen hat." },
    { key = "bis.sets", type = "toggle", label = "Setboni werten", default = true },
    { key = "bis.picks", type = "toggle", label = "BiS-Empfehlungen zeigen", default = true,
      tip = "Von Hand gepflegte beste Items, die die Wertung allein verfehlt (Procs, Effekte), stehen in ihrem Slot zuerst." },
    { key = "bis.hitCap", type = "toggle", label = "Trefferwertung nur bis zur Grenze", default = true,
      tip = "Trefferwertung über 6 % zählt nicht, gerechnet mit deinem Trefferwert aus dem Charakterfenster." },
    { key = "bis.effortTie", type = "slider", label = "Gleichstand für Aufwand (Prozent)", default = 3, min = 0, max = 10, step = 1,
      expert = true, tip = "Liegen Optionen so nah an der besten, kommt die leichter zu bekommende zuerst." },
    { key = "bis.prof", type = "choice", label = "Hergestellte Items", default = "all",
      values = { { "all", "alle" }, { "mine", "nur meine Berufe" } } },
    { key = "bis.guildTooltip", type = "toggle", label = "Gildenwünsche im Tooltip", default = true, officer = true },
    { key = "bis.guildLootMark", type = "toggle", label = "W-Markierung im Lootfenster und an den Würfelfenstern", default = true,
      officer = true },
    { key = "bis.guildAward", type = "toggle", label = "Wünschende zuerst im Vergabe-Dialog", default = true, officer = true },
}}

-- The item at the start of a command (a link, else an item id) and the rest.
local function splitItem(rest)
    local s, e = rest:find("|c%x%x%x%x%x%x%x%x|Hitem:.-|h|r")
    if not s then s, e = rest:find("|Hitem:.-|h.-|h") end
    if s then return rest:sub(s, e), rest:sub(e + 1):match("^%s*(.-)%s*$") end
    local id, more = rest:match("^(%d+)%s*(.-)%s*$")
    if id then return tonumber(id), more end
    return nil, rest
end

local PRIO_WORD = { hoch = 3, high = 3, mittel = 2, medium = 2, niedrig = 1, low = 1, ["3"] = 3, ["2"] = 2, ["1"] = 1 }

ns.RegisterSlash("wunsch", { aliases = { "wish" }, args = "[<Link> [hoch|mittel|niedrig] [Notiz] | weg <Link>]",
    desc = "Wunschliste: Item merken, ändern oder entfernen",
    run = function(rest)
        rest = rest or ""
        if rest == "" then
            ns.ShowGear("wish")
            return
        end
        local word, after = rest:match("^(%S+)%s*(.*)$")
        word = word and word:lower()
        if word == "weg" or word == "remove" then
            local item = splitItem(after)
            local id = tonumber(item) or ns.ItemID(item)
            if id and ns.WishRemove(id) then
                ns.msg(("%s von deiner Wunschliste entfernt."):format(type(item) == "string" and item or itemName(id)))
            else
                ns.msg("Das steht nicht auf deiner Wunschliste.")
            end
            return
        end
        local item, more = splitItem(rest)
        if not item then
            ns.msg("Aufruf: /amisia wunsch <Item-Link> [hoch|mittel|niedrig] [Notiz]")
            return
        end
        local prio
        local first, tail = more:match("^(%S+)%s*(.-)$")
        if first and PRIO_WORD[first:lower()] then prio, more = PRIO_WORD[first:lower()], tail end
        local e, why = ns.WishAdd(item, prio, more ~= "" and more or nil)
        if not e then
            ns.msg(why)
            return
        end
        local id = tonumber(item) or ns.ItemID(item)
        ns.msg(("%s auf deiner Wunschliste (%s%s)."):format(type(item) == "string" and item or itemName(id), PRIO_TEXT[e.prio],
            e.note ~= "" and (", " .. e.note) or ""))
    end })

local PLAN_WORD = { auto = "auto", ["2h"] = "2H", zweihand = "2H", dw = "DW", zwei = "DW", schild = "SHIELD",
    shield = "SHIELD" }

-- /amisia bis vergleich <Link> <Link>: the two items against each other in the own chat.
function ns.BisCompareReport(arg)
    local a, rest = splitItem(tostring(arg or ""))
    local b = rest and splitItem(rest)
    if not a or not b then
        ns.msg("Aufruf: /amisia bis vergleich <Item-Link> <Item-Link>")
        return
    end
    if not Gear.Available() then
        ns.msg("Für diesen Client gibt es keine Ausrüstungsdaten.")
        return
    end
    local cmp, why = ns.BisCompare(a, b, nil, { "Das erste", "das zweite" })
    if not cmp then
        ns.msg(why)
        return
    end
    ns.msg(cmp.text)
    for i = 1, math.min(6, #cmp.lines) do ns.msg("  " .. cmp.lines[i]) end
end

-- /amisia bis gewichte: the weights of the own spec at the own level with their reason.
function ns.BisWeightsReport()
    if not Gear.Available() then
        ns.msg("Für diesen Client gibt es keine Ausrüstungsdaten.")
        return
    end
    local o = ns.BisOpts()
    local w = Gear.Weights(o.class, o.spec, o.kind, o.level)
    if not w then
        ns.msg("Keine Gewichtung.")
        return
    end
    for _, line in ipairs(ns.BisWhy(o)) do ns.msg(line) end
    local parts = {}
    for k, v in pairs(w) do
        if type(v) == "number" and v ~= 0 and not k:find("^SPDREF_") and k ~= "OHDPS" then
            parts[#parts + 1] = { k = k, v = v }
        end
    end
    table.sort(parts, function(x, y)
        if x.v ~= y.v then return x.v > y.v end
        return x.k < y.k
    end)
    local out = {}
    for _, p in ipairs(parts) do
        out[#out + 1] = ("%s %s"):format(Gear.STAT_LABELS[p.k] or p.k, Gear.Num(p.v, p.v < 1 and 2 or 1))
    end
    ns.msg(("Gewichte (%s, Level %d): %s"):format(o.kind, o.level, table.concat(out, ", ")))
    local melee, spell = ns.BisOwnHit()
    if melee or spell then
        ns.msg(("Treffer laut Charakterfenster: %s %% (Waffen), %s %% (Zauber), Grenze %d %%"):format(
            melee and Gear.Num(melee, 1) or "?", spell and Gear.Num(spell, 1) or "?", ns.BIS_HIT_CAP))
    else
        ns.msg("Trefferwertung zählt ohne Obergrenze (der Client nennt den eigenen Trefferwert nicht).")
    end
end

ns.RegisterSlash("bis", { aliases = { "ziele", "ausruestung" },
    args = "[hier | item <Link> | aus <Link> | zurueck | vergleich <Link> <Link> | gewichte | plan <auto|2h|dw|schild> | sim]",
    desc = "beste Ausrüstung für deinen Charakter",
    run = function(rest)
        local sub, arg = rest:match("^(%S+)%s*(.*)$")
        sub = sub and sub:lower()
        if sub == "item" then ns.BisItemReport(arg) return end
        if not Gear.Available() then
            ns.msg("Für diesen Client gibt es keine Ausrüstungsdaten.")
            return
        end
        if not sub then
            ns.ShowGear("goals")
        elseif sub == "hier" or sub == "here" then
            ns.ShowGear("here")
        elseif sub == "aus" then
            local ok, why = ns.BisExclude("item", arg)
            if ok then
                ns.msg(("%s ausgeschlossen. /amisia bis zurueck hebt alle Ausschlüsse auf."):format(ns.ItemID(arg) and arg or ("Item " .. arg)))
            else
                ns.msg(why)
            end
        elseif sub == "zurueck" or sub == "reset" then
            local n = ns.BisClearExcludes()
            ns.msg(n == 1 and "1 Ausschluss aufgehoben." or ("%d Ausschlüsse aufgehoben."):format(n))
        elseif sub == "vergleich" or sub == "compare" then
            ns.BisCompareReport(arg)
        elseif sub == "gewichte" or sub == "weights" then
            ns.BisWeightsReport()
        elseif sub == "plan" then
            local want = PLAN_WORD[(arg or ""):lower()]
            if not want then
                ns.msg("Aufruf: /amisia bis plan auto|2h|dw|schild")
                return
            end
            local ok, why = ns.BisSetPlan(want)
            ns.msg(ok and ("Waffenplan: %s."):format(ns.BIS_PLANS[want]) or why)
        elseif sub == "sim" or sub == "simulation" then
            ns.ShowGear("sim")
        else
            ns.msg("Aufruf: /amisia bis [hier | item <Link> | aus <Link> | zurueck | vergleich <Link> <Link> | gewichte | plan <auto|2h|dw|schild> | sim]")
        end
    end })
