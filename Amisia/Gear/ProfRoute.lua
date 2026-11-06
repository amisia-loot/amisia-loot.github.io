-- Amisia profession route (F-137, spec docs/specs/2026-11-06-berufsroute.md): the cheapest way from
-- the own rank to the top of a crafting profession, step by step, with the trainer visits, the
-- recipes to buy (switch "auch Händler") and a shopping list of the materials; and the reagents in
-- the bags and banks of the own characters for its column "Twinks".
--
-- The route goes rank by rank: at each rank the allowed recipe with the smallest expected cost per
-- skill point (reagent cost / chance; chance orange 1, yellow and green (grey - rank) / (grey -
-- yellow), grey 0), equal recipes in a row merged into one step; ties: a known recipe first, then
-- fewer distinct reagents. Reagents without a vendor price (PROFESSIONS.V) have no cost: the route
-- compares the number of such pieces per point first, then the gold. Allowed: known recipes, the
-- recipes learned with the profession, trainer recipes up to the current trainer limit and, with
-- the switch, recipes whose recipe item a vendor of the own faction sells (no reputation). An
-- intermediate made by the same profession (a bolt of cloth) is crafted in the step too and its
-- points count. Pure local: nothing is sent; computed at most once per rank change, never in
-- combat or the lockdown (the page asks only while it shows the route).
--
-- AmisiaDB.prof.bags = { [character] = { day, items = { [item] = bags + bank }, bank = { [item] =
-- the bank part, last seen } } }: the own characters' profession reagents, saved on logout, at the
-- bank and throttled on BAG_UPDATE_DELAYED. Nothing is sent.
local ADDON, ns = ...
local L = ns.L
local Pr = ns.Prof

local R = {}
ns.ProfRoute = R

-- the professions with a route (skill lines): the crafting ones, cooking, first aid and poisons
R.SKILLS = { [171] = true, [164] = true, [333] = true, [202] = true, [165] = true, [197] = true, [185] = true,
    [129] = true, [40] = true }
-- the trainer limits when the data has none (T); a higher own maximum adds a step
R.DEFAULT_CAPS = { 75, 150, 225, 300 }
R.TIER_NAMES = { L["Lehrling"], L["Geselle"], L["Experte"], L["Fachmann"] }
local ENCHANTING, MINING = 333, 186
local BAGS_CHARS, BAGS_ITEMS = 40, 1500     -- characters and items kept in AmisiaDB.prof.bags at most
local EPS = 1e-9

local function data() return ns.Data("PROFESSIONS") end
local function num(s) return tonumber(s) or 0 end
local function plainCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return ns.Plain(a), ns.Plain(b)
end

local function myFaction()
    local f = UnitFactionGroup and ns.Plain((UnitFactionGroup("player"))) or nil
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end

function R.Has(skill) return R.SKILLS[tonumber(skill) or 0] == true and Pr.Key(skill) ~= nil end

---------------------------------------------------------------------------
-- Vendor prices, learning costs, trainer limits
---------------------------------------------------------------------------
local priceCache = { data = nil, items = {} }
local function freshPrices()
    if priceCache.data ~= data() then priceCache = { data = data(), items = {} } end
end

-- The vendor price of one item in copper and its vendors of the own faction (or neutral) as NPCs of
-- the data ({ id, name, point, zone, faction }); nil when no vendor sells it (or only the other
-- faction's).
function R.Price(item)
    item = tonumber(item)
    if not item then return nil end
    freshPrices()
    local hit = priceCache.items[item]
    if hit ~= nil then
        if not hit then return nil end
        return hit.price, hit.vendors
    end
    local d = data()
    local s = d and d.V and d.V[item]
    local out = false
    if type(s) == "string" then
        local price, list = s:match("^(%d+):?(.*)$")
        if price then
            local fac, vendors, any = myFaction(), {}, false
            for id in list:gmatch("%d+") do
                any = true
                local npc = Pr.Npc(id)
                if npc and (npc.faction == "" or npc.faction == nil or not fac or npc.faction == fac) then vendors[#vendors + 1] = npc end
            end
            -- a price without a vendor list counts; a list of the other faction's vendors only does not
            if not any or #vendors > 0 then out = { price = num(price), vendors = vendors } end
        end
    end
    priceCache.items[item] = out
    if not out then return nil end
    return out.price, out.vendors
end

-- What the trainer asks for a recipe (copper), or nil when the data does not say.
function R.LearnCost(spell)
    local d = data()
    local c = d and d.L and d.L[tonumber(spell)]
    return tonumber(c)
end

-- The trainer limits of a skill line: { { cap, cost } } ascending (cost nil: unknown) and the top
-- rank. From the data (T) when it has them, else 75/150/225/300 up to the highest trainer tier of
-- the recipes; the own maximum (the profession window's or the spell book's) is the current limit
-- and, above the last one, one more (Forever's ranks go past 300 for some professions). Trainer
-- costs only from T (cost nil: unknown).
function R.Caps(skill, max)
    local d = data()
    local caps = {}
    for _, s in ipairs(d and d.T and d.T[skill] or {}) do
        local tier, cap, cost = tostring(s):match("^(%d+):(%d+):(%d+)$")
        if tier then caps[#caps + 1] = { tier = num(tier), cap = num(cap), cost = num(cost) } end
    end
    table.sort(caps, function(a, b) return a.cap < b.cap end)
    if #caps == 0 then
        -- the client's trainer tiers (rank spells) are not in the data: the classic limits, as many
        -- as the highest trainer tier of the recipes (all four without trainer tokens)
        local n = 0
        for _, r in ipairs(Pr.Recipes(skill)) do
            for _, tok in ipairs(r.src) do
                local t = tonumber(tok:match("^T(%d)$"))
                if t and t > n then n = t end
            end
        end
        if n == 0 then n = #R.DEFAULT_CAPS end
        for i = 1, math.min(n, #R.DEFAULT_CAPS) do caps[i] = { tier = i, cap = R.DEFAULT_CAPS[i] } end
    end
    max = tonumber(max) or 0
    if max > caps[#caps].cap then caps[#caps + 1] = { tier = #caps + 1, cap = max } end
    return caps, caps[#caps].cap
end

---------------------------------------------------------------------------
-- Recipes
---------------------------------------------------------------------------
-- The chance of a skill point at a rank: orange 1, yellow and green (grey - rank) / (grey - yellow),
-- grey 0.
function R.Chance(r, rank)
    if r.grey <= 0 or rank >= r.grey then return 0 end
    if rank < r.yellow then return 1 end
    local span = r.grey - r.yellow
    if span <= 0 then return 0 end
    return (r.grey - rank) / span
end

-- The trainer tier a recipe needs (0: learned with the profession or no tier), or nil when no
-- trainer teaches it.
local function trainerTier(r)
    local tier
    for _, tok in ipairs(r.src) do
        if tok == "A" then return 0 end
        local t = tok:match("^T(%d)$")
        if t then
            t = num(t)
            tier = tier and math.min(tier, t) or t
        end
    end
    -- no source at all: a trainer recipe, as the page counts it (Pr.SourceKinds, "vermutlich Lehrer")
    if not tier and #r.src == 0 and #r.items == 0 then return 0 end
    return tier
end

local function isAuto(r)
    for _, tok in ipairs(r.src) do if tok == "A" then return true end end
    return false
end

-- The rank from which a trainer recipe can be learned. The client tables say 1 for most of them;
-- then the orange band before yellow (half the yellow-to-grey width, 5 at least), not below what
-- the tier's trainer asks (the limit before it less 25).
local function learnRank(r, tier, caps)
    if r.learn > 1 then return r.learn end
    if isAuto(r) then return 1 end
    local est = r.yellow - math.max(5, math.floor((r.grey - r.yellow) / 2 + 0.5))
    if tier and tier >= 2 and caps[tier - 1] then est = math.max(est, caps[tier - 1].cap - 25) end
    return math.max(1, est)
end

-- A recipe a vendor of the own faction sells as a recipe item without a reputation: { item, price,
-- vendors, rank }, or nil.
local function vendorRecipe(r)
    for _, id in ipairs(r.items) do
        local ri = Pr.RecipeItem(id)
        if ri and (ri.faction or 0) == 0 then
            local price, vendors = R.Price(id)
            if price then return { item = id, price = price, vendors = vendors or {}, rank = ri.rank or 0 } end
        end
    end
    return nil
end

-- Prepares the recipes of a skill line for the route: each with its reagents (parts: item, n, price
-- or nil), whether it is known, the tier it needs, the rank it can be learned from, what learning
-- or buying costs once. Recipes nobody can plan (drops, favor, reputation, the other faction) and
-- recipes without reagent data are left out (the second value counts the latter by rank).
local function prepare(skill, o, caps)
    local list, noReagents = {}, {}
    for _, r in ipairs(Pr.Recipes(skill)) do
        local known = o.known(r) or isAuto(r)
        local tier = trainerTier(r)
        local buy = (not known and tier == nil and o.vendor) and vendorRecipe(r) or nil
        if known or tier or buy then
            local reagents = Pr.Reagents(r.spell)
            if not reagents or #reagents == 0 then
                noReagents[#noReagents + 1] = r
            else
                local e = { r = r, known = known, tier = (not known) and tier or nil, buy = buy, parts = {},
                    learn = known and 1 or math.max(learnRank(r, tier, caps), buy and buy.rank or 0),
                    learnCost = (not known and tier and R.LearnCost(r.spell)) or 0 }
                e.oneTime = e.learnCost + (buy and buy.price or 0)
                for _, g in ipairs(reagents) do
                    e.parts[#e.parts + 1] = { item = g[1], n = g[2], price = (R.Price(g[1])) }
                end
                list[#list + 1] = e
            end
        end
    end
    -- who of them makes a reagent (the intermediates): known ones first
    local makers = {}
    for _, e in ipairs(list) do
        if e.r.item > 0 then
            local m = makers[e.r.item] or {}
            makers[e.r.item] = m
            if e.known then table.insert(m, 1, e) else m[#m + 1] = e end
        end
    end
    for _, e in ipairs(list) do
        for _, p in ipairs(e.parts) do
            local m = makers[p.item]
            if m then
                local own = {}
                for _, x in ipairs(m) do if x ~= e then own[#own + 1] = x end end
                if #own > 0 then p.makers = own end
            end
        end
    end
    return list, noReagents
end

---------------------------------------------------------------------------
-- The route
---------------------------------------------------------------------------
-- The cost of one craft of e at a rank: points expected, pieces without a price, copper, the
-- intermediate used ({ e, k = crafts per main craft }) and the base reagents per craft.
local function usable(e, rank, tier)
    return rank >= e.learn and (not e.tier or e.tier <= tier)
end

local function evaluate(e, rank, tier, paid)
    local r = e.r
    local ch = R.Chance(r, rank)
    if ch <= 0 or not usable(e, rank, tier) then return nil end
    local pts, unpriced, priced, pre = ch, 0, 0, nil
    local once = paid[e] and 0 or e.oneTime
    for _, p in ipairs(e.parts) do
        local maker
        -- one intermediate per recipe: the first reagent without a price the profession makes here
        if not pre and not p.price then
            for _, m in ipairs(p.makers or {}) do
                if usable(m, rank, tier) then
                    maker = m
                    break
                end
            end
        end
        if maker then
            local k = p.n / math.max(1, maker.r.count)
            pts = pts + k * R.Chance(maker.r, rank)
            for _, q in ipairs(maker.parts) do
                if q.price then priced = priced + k * q.n * q.price else unpriced = unpriced + k * q.n end
            end
            if not paid[maker] then once = once + maker.oneTime end
            pre = { e = maker, k = k, part = p }
        elseif p.price then
            priced = priced + p.n * p.price
        else
            unpriced = unpriced + p.n
        end
    end
    -- a one-time cost (learning, buying) spread over the ranks the recipe still gives sure points
    local span = math.max(1, r.green - rank)
    return { e = e, pts = pts, up = unpriced / pts, pp = (priced + once / span) / pts, unpriced = unpriced,
        priced = priced, pre = pre, known = e.known, distinct = #e.parts, spell = r.spell }
end

local function better(a, b, prev)
    if math.abs(a.up - b.up) > EPS then return a.up < b.up end
    if math.abs(a.pp - b.pp) > 1e-6 then return a.pp < b.pp end
    if a.known ~= b.known then return a.known end
    if a.distinct ~= b.distinct then return a.distinct < b.distinct end
    if prev and (a.e == prev) ~= (b.e == prev) then return a.e == prev end
    return a.spell < b.spell
end

-- The base reagents of one craft (main plus intermediate), as { [item] = n }.
local function baseReagents(v)
    local out, pre = {}, v.pre
    for _, p in ipairs(v.e.parts) do
        if pre and p == pre.part then
            for _, q in ipairs(pre.e.parts) do out[q.item] = (out[q.item] or 0) + pre.k * q.n end
        else
            out[p.item] = (out[p.item] or 0) + p.n
        end
    end
    return out
end

-- The route of a skill line. o: rank (nil: not learned, a preview from 1), max (the own limit, nil
-- unknown), vendor (also vendor recipes), known (function(recipe) -> true when the character knows
-- it; default Pr.Known). Returns { skill, start, top, learned, steps = { ... }, total (copper of the
-- priced part), unknown (a step uses materials without a price), recipes (steps of kind recipe),
-- maxKnown (the own limit was given; else the classic limit over the rank is assumed) }.
-- Steps: { kind = "trainer", at, tier, name, cap, cost } | { kind = "buy", at, recipe, item, price,
-- vendors } | { kind = "recipe", from, to, recipe, entry, pre (recipe), crafts, preCrafts, points,
-- cost, unpriced, reagents = { [item] = n }, colorFrom, colorTo, learnCost, chosenAt } | { kind =
-- "gap", from, to, why = "none"/"noreagents" }. Every rank from start to top - 1 lies in exactly one
-- recipe or gap step (from <= rank < to).
function R.Compute(skill, o)
    o = o or {}
    local knownFn = o.known or function(r) return Pr.Known(r.spell, skill) == true end
    local learned = o.rank ~= nil
    local start = math.max(1, tonumber(o.rank) or 1)
    local caps, top = R.Caps(skill, o.max)
    local list, noReagents = prepare(skill, { known = knownFn, vendor = o.vendor }, caps)
    local out = { skill = skill, start = start, top = top, learned = learned, steps = {}, total = 0, unknown = false,
        recipes = 0, maxKnown = (tonumber(o.max) or 0) > 0 }
    local steps = out.steps

    local tier, cap, cur = 0, start, nil
    if learned then
        local m = tonumber(o.max) or 0
        tier = #caps
        for i, c in ipairs(caps) do
            if (m > 0 and c.cap >= m) or (m <= 0 and c.cap >= start) then
                tier = i
                break
            end
        end
        cap = m > 0 and m or caps[tier].cap
    end
    local function trainer(at)
        local nextTier
        for i, c in ipairs(caps) do
            if c.cap > cap then
                nextTier = i
                break
            end
        end
        if not nextTier then return false end
        tier, cap = nextTier, caps[nextTier].cap
        local c = caps[nextTier]
        steps[#steps + 1] = { kind = "trainer", at = at, tier = nextTier, name = R.TIER_NAMES[nextTier], cap = c.cap, cost = c.cost }
        if c.cost then out.total = out.total + c.cost end
        cur = nil   -- the trainer visit ends the step before it
        return true
    end
    if not learned then
        cap = 0
        trainer(1)
    end

    -- the ranks recipes without reagent data would cover (for the gap's reason)
    local function hasNoReagents(rank)
        for _, r in ipairs(noReagents) do
            if R.Chance(r, rank) > 0 and rank >= (r.learn > 1 and r.learn or 1) then return true end
        end
        return false
    end

    local paid = {}
    local rank = start
    while rank < top do
        if rank >= cap and not trainer(rank) then break end
        local best
        for _, e in ipairs(list) do
            if rank < e.r.grey then
                local v = evaluate(e, rank, tier, paid)
                if v and (not best or better(v, best, cur and cur.entry)) then best = v end
            end
        end
        if not best then
            local why = hasNoReagents(rank) and "noreagents" or "none"
            if cur and cur.kind == "gap" and cur.why == why then
                cur.to = rank + 1
            else
                cur = { kind = "gap", from = rank, to = rank + 1, why = why }
                steps[#steps + 1] = cur
            end
        else
            local e = best.e
            local preE = best.pre and best.pre.e or nil
            if not (cur and cur.kind == "recipe" and cur.entry == e and cur.preEntry == preE) then
                if e.buy and not paid[e] then
                    steps[#steps + 1] = { kind = "buy", at = rank, recipe = e.r, item = e.buy.item, price = e.buy.price,
                        vendors = e.buy.vendors }
                    out.total = out.total + e.buy.price
                end
                cur = { kind = "recipe", from = rank, to = rank, recipe = e.r, entry = e, pre = preE and preE.r or nil,
                    preEntry = preE, crafts = 0, preCrafts = 0, cost = 0, unpriced = 0, reagents = {}, learnCost = 0,
                    chosenAt = rank, known = e.known }
                if not paid[e] and e.learnCost > 0 then
                    cur.learnCost = e.learnCost
                    cur.cost = cur.cost + e.learnCost
                end
                if preE and not paid[preE] and preE.learnCost > 0 then
                    cur.learnCost = cur.learnCost + preE.learnCost
                    cur.cost = cur.cost + preE.learnCost
                end
                paid[e] = true
                if preE then paid[preE] = true end
                steps[#steps + 1] = cur
                out.recipes = out.recipes + 1
            end
            local units = 1 / best.pts
            cur.to = rank + 1
            cur.crafts = cur.crafts + units
            cur.preCrafts = cur.preCrafts + (best.pre and best.pre.k * units or 0)
            cur.cost = cur.cost + best.priced * units
            cur.unpriced = cur.unpriced + best.unpriced * units
            for item, n in pairs(baseReagents(best)) do cur.reagents[item] = (cur.reagents[item] or 0) + n * units end
        end
        rank = rank + 1
    end
    for _, s in ipairs(steps) do
        if s.kind == "recipe" then
            s.points = s.to - s.from
            s.colorFrom = Pr.Difficulty(s.recipe, s.from, true)
            s.colorTo = Pr.Difficulty(s.recipe, s.to - 1, true)
            out.total = out.total + s.cost
            if s.unpriced > EPS then out.unknown = true end
        end
    end
    out.total = math.floor(out.total + 0.5)
    return out
end

---------------------------------------------------------------------------
-- The page's route: cached per rank, the steps already done kept
---------------------------------------------------------------------------
local routes = {}   -- skill -> { key, route }

local function blocked()
    if InCombatLockdown and ns.Plain(InCombatLockdown()) == true then return true end
    return ns.ChatLocked and ns.ChatLocked() and true or false
end
R._blocked = blocked

local function knownSig(skill)
    local c = AmisiaDB and AmisiaDB.prof and AmisiaDB.prof.chars
    c = type(c) == "table" and c[ns.UnitFullName and ns.UnitFullName("player") or "?"]
    local s = type(c) == "table" and c[skill]
    local n = 0
    if type(s) == "table" and type(s.known) == "table" then for _ in pairs(s.known) do n = n + 1 end end
    return n
end

-- Steps of the route before that are behind the new rank: done.
local function carryDone(old, rank, newCap)
    local out = {}
    for _, s in ipairs(old and old.steps or {}) do
        local done = s.done
        if s.kind == "recipe" or s.kind == "gap" then
            done = done or s.to <= rank
        elseif s.kind == "trainer" then
            done = done or s.at < rank or (s.at == rank and newCap >= s.cap)
        elseif s.kind == "buy" then
            done = done or s.at < rank
        end
        if done then
            s.done = true
            out[#out + 1] = s
        end
    end
    return out
end

-- The route the page shows for a skill line: the own rank and limit, the switch "auch Händler".
-- Computed again only when one of them, the known recipes or the data changed; never in combat or
-- the lockdown (then the last route, and true as the second value). nil without a route.
function R.Get(skill, vendor)
    if not R.Has(skill) then return nil end
    local rank, max = Pr.Rank(skill)
    local key = table.concat({ tostring(rank), tostring(max), vendor and "v" or "t", knownSig(skill),
        tostring(data()) }, "|")
    local st = routes[skill]
    if st and st.key == key then return st.route, false end
    if blocked() then return st and st.route or nil, true end
    local route = R.Compute(skill, { rank = rank, max = max, vendor = vendor })
    local cap = (rank and max) or 0
    local done = (st and st.route and st.vendor == (vendor and true or false)) and carryDone(st.route, route.start, cap) or {}
    if #done > 0 then
        local all = {}
        for _, s in ipairs(done) do all[#all + 1] = s end
        for _, s in ipairs(route.steps) do all[#all + 1] = s end
        route.steps = all
    end
    routes[skill] = { key = key, route = route, vendor = vendor and true or false }
    return route, false
end

function R._reset() routes = {} end

-- The index of the step to do now: the first one not done.
function R.Current(route)
    for i, s in ipairs(route and route.steps or {}) do
        if not s.done then return i end
    end
    return nil
end

---------------------------------------------------------------------------
-- Where a material comes from
---------------------------------------------------------------------------
local srcIndex   -- { data, made = { [item] = skill }, used = { [item] = { [skill] = true } } }
local function sources()
    if srcIndex and srcIndex.data == data() then return srcIndex end
    srcIndex = { data = data(), made = {}, used = {} }
    local d = data()
    for _, skill in ipairs(Pr.Skills()) do
        for _, r in ipairs(Pr.Recipes(skill)) do
            if r.item > 0 and not srcIndex.made[r.item] then srcIndex.made[r.item] = skill end
            local g = d and d.G and d.G[r.spell]
            if type(g) == "string" then
                for item in g:gmatch("(%d+):%d+") do
                    item = num(item)
                    local u = srcIndex.used[item] or {}
                    srcIndex.used[item] = u
                    u[skill] = true
                end
            end
        end
    end
    return srcIndex
end

-- The source of a material for the shopping list: kind ("vendor", "smelt", "mine", "craft",
-- "disenchant", "farm") and, for "craft", the skill line that makes it.
function R.Source(item, skill)
    if R.Price(item) then return "vendor" end
    local s = sources()
    local maker = s.made[item]
    if maker == MINING then return "smelt" end
    if maker and maker ~= skill then return "craft", maker end
    local used = s.used[item] or {}
    if used[MINING] then return "mine" end
    if skill == ENCHANTING then
        local other = false
        for k in pairs(used) do if k ~= ENCHANTING then other = true end end
        if not other then return "disenchant" end
    end
    return "farm"
end

---------------------------------------------------------------------------
-- The bags of the own characters (AmisiaDB.prof.bags)
---------------------------------------------------------------------------
local function charKey() return ns.UnitFullName and ns.UnitFullName("player") or "?" end
local function realmOf(name) return tostring(name):match("%-(.+)$") or "" end

local function bagsRoot(create)
    if not AmisiaDB then return nil end
    local p = AmisiaDB.prof
    if type(p) ~= "table" then
        if not create then return nil end
        p = { chars = {} }
        AmisiaDB.prof = p
    end
    if type(p.bags) ~= "table" then
        if not create then return nil end
        p.bags = {}
    end
    return p.bags
end

local function posInt(v, max) return type(v) == "number" and v > 0 and v == math.floor(v) and (not max or v <= max) end

local function cleanCounts(t)
    local out, n = {}, 0
    if type(t) ~= "table" then return out end
    for item, c in pairs(t) do
        if posInt(item) and posInt(c, 100000) and n < BAGS_ITEMS then
            out[item] = c
            n = n + 1
        end
    end
    return out
end

-- Called on ADDON_LOADED: AmisiaDB.prof.bags checked (names without codes, day, counts positive
-- whole numbers; the newest BAGS_CHARS characters), other fields dropped.
function ns.ProfBagsLoaded(root)
    local p = type(root) == "table" and root.prof
    if type(p) ~= "table" or p.bags == nil then return end
    if type(p.bags) ~= "table" then
        p.bags = nil
        return
    end
    local list = {}
    for name, e in pairs(p.bags) do
        if type(name) == "string" and name ~= "" and #name <= 80 and not name:find("|", 1, true) and type(e) == "table" then
            list[#list + 1] = { name = name, e = { day = type(e.day) == "number" and e.day >= 0 and math.floor(e.day) or 0,
                items = cleanCounts(e.items), bank = cleanCounts(e.bank) } }
        end
    end
    table.sort(list, function(a, b)
        if a.e.day ~= b.e.day then return a.e.day > b.e.day end
        return a.name < b.name
    end)
    local out = {}
    for i = 1, math.min(#list, BAGS_CHARS) do out[list[i].name] = list[i].e end
    p.bags = out
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == ADDON and AmisiaDB then ns.ProfBagsLoaded(AmisiaDB) end
end)

-- The reagents worth counting: those of the own professions with a route (data reagents).
local trackCache
local function tracked()
    local skills = {}
    for _, p in ipairs(Pr.Own()) do
        if R.SKILLS[p.skill] then skills[#skills + 1] = p.skill end
    end
    table.sort(skills)
    local sig = table.concat(skills, ",") .. "|" .. tostring(data())
    if trackCache and trackCache.sig == sig then return trackCache.items end
    local items, d = {}, data()
    for _, skill in ipairs(skills) do
        for _, r in ipairs(Pr.Recipes(skill)) do
            local g = d and d.G and d.G[r.spell]
            if type(g) == "string" then
                for item in g:gmatch("(%d+):%d+") do items[num(item)] = true end
            end
        end
    end
    trackCache = { sig = sig, items = items }
    return items
end

local bankOpen = false

-- Counts this character's profession reagents into AmisiaDB.prof.bags: the bags always, the bank
-- part while the bank is open or the client tells it (else the last one seen stays).
function R.SaveBags()
    if not AmisiaDB or not Pr.Available() then return false end
    local items = tracked()
    if next(items) == nil then return false end
    local f = C_Item and C_Item.GetItemCount
    if type(f) ~= "function" then return false end
    local root = bagsRoot(true)
    local key = charKey()
    local old = type(root[key]) == "table" and root[key] or {}
    local bank = type(old.bank) == "table" and old.bank or {}
    local counts, n = {}, 0
    for item in pairs(items) do
        local bags = tonumber((plainCall(f, item, false))) or 0
        local all = tonumber((plainCall(f, item, true))) or bags
        local part = math.max(0, all - bags)
        if bankOpen or part > 0 then bank[item] = part > 0 and part or nil end
        local total = bags + (bank[item] or 0)
        if total > 0 and n < BAGS_ITEMS then
            counts[item] = total
            n = n + 1
        end
    end
    root[key] = { day = ns.DropsToday and ns.DropsToday() or 0, items = counts, bank = bank }
    return true
end

-- How many of an item the other own characters of the realm hold (bags and bank, as last seen).
function R.Twinks(item)
    local root = bagsRoot(false)
    if not root then return 0 end
    local me = charKey()
    local realm = realmOf(me)
    local n = 0
    for name, e in pairs(root) do
        if name ~= me and realmOf(name) == realm and type(e) == "table" and type(e.items) == "table" then
            n = n + (tonumber(e.items[item]) or 0)
        end
    end
    return n
end

-- How many this character has: the client's count with the bank, or the bags and the last bank count.
function R.Have(item)
    local have = Pr.Count(item)
    local f = C_Item and C_Item.GetItemCount
    local root = bagsRoot(false)
    local own = root and root[charKey()]
    local bank = type(own) == "table" and type(own.bank) == "table" and own.bank[item] or 0
    if bank > 0 and type(f) == "function" then
        local bags = tonumber((plainCall(f, item, false))) or 0
        have = math.max(have, bags + bank)
    end
    return have
end

local saveDue = false
local function saveSoon()
    if saveDue then return end
    saveDue = true
    local run = function()
        saveDue = false
        if InCombatLockdown and ns.Plain(InCombatLockdown()) == true then return end
        R.SaveBags()
    end
    if C_Timer and C_Timer.After then C_Timer.After(5, run) else run() end
end
ns.OnEvent("BAG_UPDATE_DELAYED", saveSoon)
ns.OnEvent("PLAYER_LOGOUT", function() R.SaveBags() end)
ns.OnEvent("BANKFRAME_OPENED", function()
    bankOpen = true
    R.SaveBags()
end)
ns.OnEvent("BANKFRAME_CLOSED", function()
    R.SaveBags()
    bankOpen = false
end)
-- Forever's interaction manager: the banker
local function banker(kind)
    local E = Enum and Enum.PlayerInteractionType
    return E and E.Banker ~= nil and ns.Plain(kind) == E.Banker
end
ns.OnEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
    if banker(kind) then
        bankOpen = true
        R.SaveBags()
    end
end)
ns.OnEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
    if banker(kind) then
        R.SaveBags()
        bankOpen = false
    end
end)

---------------------------------------------------------------------------
-- The shopping list
---------------------------------------------------------------------------
-- The materials of the steps not done: { { item, need, have, twinks, missing, price, kind, from
-- (skill line of "craft"), vendors, enough } } by need, the vendor ones first among equals.
function R.Shopping(route)
    local need = {}
    for _, s in ipairs(route and route.steps or {}) do
        if s.kind == "recipe" and not s.done then
            for item, n in pairs(s.reagents) do need[item] = (need[item] or 0) + n end
        end
    end
    local out = {}
    for item, n in pairs(need) do
        local count = math.ceil(n - 1e-6)
        if count > 0 then
            local have, twinks = R.Have(item), R.Twinks(item)
            local price, vendors = R.Price(item)
            local kind, from = R.Source(item, route.skill)
            out[#out + 1] = { item = item, need = count, have = have, twinks = twinks,
                missing = math.max(0, count - have - twinks), price = price, vendors = vendors, kind = kind, from = from,
                enough = have >= count }
        end
    end
    table.sort(out, function(a, b)
        if a.need ~= b.need then return a.need > b.need end
        return a.item < b.item
    end)
    return out
end
