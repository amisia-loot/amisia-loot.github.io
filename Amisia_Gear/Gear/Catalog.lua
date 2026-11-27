-- The catalog (F-123, spec docs/specs/2026-10-17-ziele-katalog.md; the planner's set marks and search, D-80):
-- the item sets of ns.BIS.SET by where their pieces come from (raid, dungeon, PvP vendor, crafting,
-- the rest of the world), each with its level, how many pieces the own character has and what each
-- piece brings; and the search over every item of the gear data by name and required level, the
-- best for the own character first. Names come from the client: an item without one is asked for
-- (through Gear.Stats) and found once it arrives. Nothing is saved here; the planner keeps its choice
-- in memory (D-80). The level sets are no item sets: per range of ten levels the best item of
-- every slot for the own spec at the range's top (the simulation's calculation, ns.BisFor).
local ADDON, ns = ...
ns.Load(function()
local L = ns.L
local Gear = ns.Gear

local C = {}
ns.Catalog = C

C.MAX = 200          -- search hits at most
local ASK_MAX = 60   -- names asked of the server per search at most (each id once a session)

-- the categories in their order; a set goes to the first one any of its pieces' sources names
C.CATS = {
    -- not sets either: the best item per slot for each range of C.BRACKETS (ids minus LEVEL_BASE - i)
    { key = "level", label = L["Stufen-Sets"], icon = "Interface\\Icons\\INV_Chest_Chain_05" },
    { key = "raid", label = L["Raid-Sets"], icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black" },
    { key = "dungeon", label = L["Dungeon-Sets"], icon = "Interface\\Icons\\INV_Misc_Key_13" },
    { key = "pvp", label = L["PvP-Sets"], icon = "Interface\\Icons\\INV_BannerPVP_02" },
    { key = "craft", label = L["Handwerks-Sets"], icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { key = "world", label = L["Welt-Sets"], icon = "Interface\\Icons\\INV_Misc_Map_01" },
    -- not sets: the items of one faction's reputation as one group each (id: minus the faction id)
    { key = "rep", label = L["Ruf"], icon = "Interface\\Icons\\INV_Scroll_03" },
}
local CAT_OK, CAT_RANK = {}, {}
for i, c in ipairs(C.CATS) do CAT_OK[c.key], CAT_RANK[c.key] = true, i end
local CAT_OF_KIND = { X = "raid", D = "dungeon", P = "pvp", C = "craft", Q = "world", V = "world", R = "world", W = "world", A = "world" }

function C.ValidCat(key) return CAT_OK[key] == true end

-- the level ranges of the level sets; a set holds what is best at the range's top level
C.BRACKETS = { { 1, 19 }, { 20, 29 }, { 30, 39 }, { 40, 49 }, { 50, 59 }, { 60, 60 } }
local LEVEL_BASE = 1000000

local function setTable()
    local B = ns.BIS
    return type(B) == "table" and type(B.SET) == "table" and B.SET or nil
end

local function levelOf(id)
    local row = Gear.Item(id)
    return row and tonumber(row[4]) or 0
end

-- Every set once per set table and gear data: { id, name, cat, items, level }, by level then name.
local all, allKey
local function sets()
    local S = setTable()
    local key = tostring(S) .. "|" .. tostring(ns.HasData("GEAR") and ns.Data("GEAR"))
    if all and allKey == key then return all end
    local out = {}
    for sid, set in pairs(S or {}) do
        if type(set) == "table" and type(set.items) == "table" and #set.items > 0 then
            local cat, level = nil, 0
            for _, id in ipairs(set.items) do
                level = math.max(level, levelOf(id))
                for _, rec in ipairs(Gear.Sources(id)) do
                    local c = CAT_OF_KIND[rec[1]]
                    if c and (not cat or CAT_RANK[c] < CAT_RANK[cat]) then cat = c end
                end
            end
            out[#out + 1] = { id = sid, name = type(set.name) == "string" and set.name or ("Set " .. sid), cat = cat or "world",
                items = set.items, level = level }
        end
    end
    -- the reputation items (the client's ItemSparse, F-124): one group per faction
    local d = ns.HasData("GEAR") and ns.Data("GEAR")
    local byFac = {}
    for id in pairs(d and type(d.RP) == "table" and d.RP or {}) do
        local fac = Gear.ItemRep(id)
        if fac then
            local g = byFac[fac]
            if not g then
                local _, name = ns.PlayStyle.Standing(fac)
                g = { id = -fac, name = name or L["Fraktion %d"]:format(fac), cat = "rep", items = {}, level = 0, rep = fac }
                byFac[fac] = g
                out[#out + 1] = g
            end
            g.items[#g.items + 1] = id
            -- shown from its first item on (a set from its last)
            local lv = levelOf(id)
            if lv > 0 and (g.level == 0 or lv < g.level) then g.level = lv end
        end
    end
    for _, g in pairs(byFac) do
        table.sort(g.items, function(a, b)
            local la, lb = levelOf(a), levelOf(b)
            if la ~= lb then return la < lb end
            return a < b
        end)
    end
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    all, allKey = out, key
    return out
end

-- The level ranges the data reaches that touch lo..hi, as { i, from, to }.
local function brackets(lo, hi)
    local out, cap = {}, Gear.Cap()
    for i, b in ipairs(C.BRACKETS) do
        local from, to = b[1], math.min(b[2], cap)
        if from <= cap and from <= hi and to >= lo then out[#out + 1] = { i = i, from = from, to = to } end
    end
    return out
end

-- The level sets of the own options (class, spec, faction, sources, weapon plan, exclusions, play
-- style): { id, name, cat = "level", items, slots, level, from, to } per range, the slots in the
-- planner's order (the off hand only with a one-hand plan). Kept until the scores (not what is owned)
-- or the options change.
local levelAll, levelKey
local function levelSets()
    local o = ns.BisOpts()
    if not o.class or not Gear.Available() then return {} end
    local key = table.concat({ tostring(ns.Data("GEAR")), tostring(ns.BIS), ns.BisScoreStamp(), Gear.StatsWaits(), o.class,
        tostring(o.spec), tostring(o.kind), tostring(o.faction), tostring(o.plan), tostring(o.prof),
        ns.PlayStyle.Key(o.style) }, "|")
    if levelAll and levelKey == key then return levelAll end
    local out = {}
    for _, b in ipairs(brackets(1, Gear.Cap())) do
        -- the play style (F-124) as the own options have it, at the range's top level
        local style = o.style and ns.PlayStyle.Context({ level = b.to, skills = o.skills }) or nil
        local res = ns.BisFor(o.class, o.spec, b.to, { faction = o.faction, sources = o.sources, plan = o.plan,
            exclude = o.exclude, style = style })
        local set = { id = -(LEVEL_BASE + b.i), cat = "level", items = {}, slots = {}, level = b.to, from = b.from, to = b.to,
            name = b.from == b.to and L["Auf Stufe %d"]:format(b.to) or L["Stufe %d bis %d"]:format(b.from, b.to) }
        for _, sl in ipairs(Gear.SLOTS) do
            local first = res[sl.key] and res[sl.key][1]
            if first then
                set.items[#set.items + 1] = first[1]
                set.slots[#set.slots + 1] = sl.key
            end
        end
        out[#out + 1] = set
    end
    levelAll, levelKey = out, key
    return out
end

-- How many sets a category holds in the level range (lo..hi; a set of unknown level always counts).
function C.Count(cat, lo, hi)
    if cat == "level" then return #brackets(lo, hi) end
    local n = 0
    for _, s in ipairs(sets()) do
        if s.cat == cat and (s.level == 0 or (s.level >= lo and s.level <= hi)) then n = n + 1 end
    end
    return n
end

-- The sets of a category in the level range: { { id, name, cat, items, level, have, total } }.
function C.Sets(cat, lo, hi)
    local out = {}
    local list = cat == "level" and levelSets() or sets()
    for _, s in ipairs(list) do
        local shown
        if cat == "level" then
            shown = s.from <= hi and s.to >= lo
        else
            shown = s.cat == cat and (s.level == 0 or (s.level >= lo and s.level <= hi))
        end
        if shown then
            local have = 0
            for _, id in ipairs(s.items) do
                if ns.BisOwned(id) then have = have + 1 end
            end
            out[#out + 1] = setmetatable({ have = have, total = #s.items }, { __index = s })
        end
    end
    return out
end

-- One set by id, or nil.
function C.Set(sid)
    for _, s in ipairs(type(sid) == "number" and sid <= -LEVEL_BASE and levelSets() or sets()) do
        if s.id == sid then return s end
    end
    return nil
end

-- What an item brings the own character: { id, level, slotKey, gain, mine, owned, upgrade, why }.
local function entry(id, o)
    local gain, slotKey, mine = ns.BisGain(id, o)
    local owned = ns.BisOwned(id)
    local e = { id = id, level = levelOf(id), owned = owned }
    if type(gain) == "number" then
        e.gain, e.slotKey, e.mine = gain, slotKey, mine
        e.upgrade = owned ~= "worn" and ns.BisIsUpgrade(gain, mine) or false
    else
        e.why = slotKey
    end
    return e
end

-- The pieces of a set with what each brings, in the set's order.
function C.Pieces(sid, o)
    local s = C.Set(sid)
    if not s then return {} end
    o = o or ns.BisOpts()
    local out = {}
    for i, id in ipairs(s.items) do
        out[i] = entry(id, o)
        -- a level set names each piece's slot, also one the own character cannot wear yet
        if s.slots then out[i].slotKey = out[i].slotKey or s.slots[i] end
    end
    return out
end

local function itemName(id)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local ok, name = pcall(C_Item.GetItemInfo, id)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- The search's names, kept for the session: each item's name is read from the client once and folded once
-- (umlauts, case); an item the client does not hold yet is asked of the server once and taken when its
-- GET_ITEM_INFO_RECEIVED comes. Before (2.102.2) every key stroke read and folded all ~25000 names again and
-- asked 150 more, whose answers started the next full search: the game nearly stood still.
local names, folded = {}, {}   -- item id -> name / folded name
local missing = {}             -- item id -> "wait" (asked, answer pending) or "ask" (still to ask)
local namesVersion = 0         -- bumped by every name that arrives (a kept result is stale then)
-- dataN: the gear data's names (N: as the German client showed them to the scan), used on a German client
-- for an item the client does not hold yet, so the search finds it at once (before, only names the client
-- happened to have in memory were found)
local function nameOf(id, dataN)
    local f = folded[id]
    if f then return f end
    -- known missing (asked, or still to ask): no client call again; the answer comes by the event
    if missing[id] then return nil end
    local name = itemName(id) or (dataN and dataN[id])
    if type(name) == "string" and name ~= "" then
        missing[id], names[id], folded[id] = nil, name, ns.Fold(name)
        return folded[id]
    end
    missing[id] = "ask"
    return nil
end
ns.OnEvent("GET_ITEM_INFO_RECEIVED", function(id)
    id = tonumber(ns.Plain(id))
    if not id or not missing[id] then return end
    local name = itemName(id)
    if name then
        missing[id], names[id], folded[id] = nil, name, ns.Fold(name)
        namesVersion = namesVersion + 1
    end
end)
local function askName(id)
    missing[id] = "wait"
    local fn = C_Item and C_Item.RequestLoadItemDataByID
    if type(fn) == "function" then pcall(fn, id) end
end
-- Whether names asked for are still on their way (the planner refreshes a search while they come).
function C.NamesPending()
    for _, v in pairs(missing) do if v == "wait" then return true end end
    return false
end
local kept   -- the last search: { key, out, n, missing }

-- The items of the gear data whose name holds text (umlauts and case do not matter) and whose
-- required level is in lo..hi, the best gain for the own character first (no gain last, then by
-- name): list (C.MAX at most), how many matched, how many names are still missing (asked for).
function C.Search(text, lo, hi, o)
    local q = ns.Fold(text or "")
    q = q:gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" or not ns.HasData("GEAR") then return {}, 0, 0 end
    local d = ns.Data("GEAR")
    o = o or ns.BisOpts()
    -- the same search with no new name since: the kept result (a refresh of the page reads it again)
    local key = table.concat({ q, lo, hi, namesVersion, tostring(ns.BisStamp and ns.BisStamp() or "") }, "\1")
    if kept and kept.key == key then return kept.out, kept.n, kept.missing end
    local found, nMissing, asked = {}, 0, 0
    local dataN = type(GetLocale) == "function" and GetLocale() == "deDE" and type(d.N) == "table" and d.N or nil
    for id, row in pairs(d.I or {}) do
        local lv = tonumber(row[4]) or 0
        if lv >= lo and lv <= hi then
            local f = nameOf(id, dataN)
            if f then
                if f:find(q, 1, true) then found[#found + 1] = { id = id, name = names[id] } end
            else
                nMissing = nMissing + 1
                if missing[id] == "ask" and asked < ASK_MAX then
                    asked = asked + 1
                    askName(id)
                end
            end
        end
    end
    local out = {}
    for i, f in ipairs(found) do
        local e = entry(f.id, o)
        e.name = f.name
        out[i] = e
    end
    table.sort(out, function(a, b)
        local ga, gb = a.gain, b.gain
        if (ga ~= nil) ~= (gb ~= nil) then return ga ~= nil end
        if ga and gb and ga ~= gb then return ga > gb end
        return a.name < b.name
    end)
    local n = #out
    for i = C.MAX + 1, n do out[i] = nil end
    kept = { key = key, out = out, n = n, missing = nMissing }
    return out, n, nMissing
end

-- The gear data's items by folded name, built once per data and arrived name (namesVersion) for a pasted list
-- (F-239); names the client lacks are asked for, ASK_MAX per build.
local nameIndex, indexKey
local function byName()
    local d = ns.Data("GEAR")
    local key = tostring(d) .. ":" .. namesVersion
    if nameIndex and indexKey == key then return nameIndex end
    local dataN = type(GetLocale) == "function" and GetLocale() == "deDE" and type(d.N) == "table" and d.N or nil
    local idx, asked = {}, 0
    for id in pairs(d.I or {}) do
        local f = nameOf(id, dataN)
        if f then
            local t = idx[f]
            if not t then
                t = {}
                idx[f] = t
            end
            t[#t + 1] = id
        elseif missing[id] == "ask" and asked < ASK_MAX then
            asked = asked + 1
            askName(id)
        end
    end
    for _, t in pairs(idx) do table.sort(t) end
    nameIndex, indexKey = idx, key
    return idx
end

-- The items of the gear data whose whole name is text (umlauts and case do not matter), for a pasted list
-- (F-239): their ids, and whether asked names are still on their way (C.NamesPending).
function C.FindName(text)
    local q = ns.Fold(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" or not ns.HasData("GEAR") then return {}, false end
    local out = {}
    for i, id in ipairs(byName()[q] or {}) do out[i] = id end
    return out, C.NamesPending()
end

-- Test hook: forget the set list.
function C._reset()
    all, allKey, levelAll, levelKey = nil, nil, nil, nil
    names, folded, missing, kept, namesVersion = {}, {}, {}, nil, 0
    nameIndex, indexKey = nil, nil
end
end)
