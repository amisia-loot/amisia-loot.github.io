-- The catalog of the window "Ausrüstungsziele" (F-123, spec docs/specs/2026-10-17-ziele-katalog.md):
-- the item sets of ns.BIS.SET by where their pieces come from (raid, dungeon, PvP vendor, crafting,
-- the rest of the world), each with its level, how many pieces the own character has and what each
-- piece brings; and the search over every item of the gear data by name and required level, the
-- best for the own character first. Names come from the client: an item without one is asked for
-- (through Gear.Stats) and found once it arrives. Nothing is saved here; the window keeps its choice
-- in settings.goalWindow.
local ADDON, ns = ...
local L = ns.L
local Gear = ns.Gear

local C = {}
ns.Catalog = C

C.MAX = 200          -- search hits at most
local ASK_MAX = 150  -- names asked for per search at most (the loader works them off by and by)

-- the categories in their order; a set goes to the first one any of its pieces' sources names
C.CATS = {
    { key = "raid", label = L["Raid-Sets"], icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black" },
    { key = "dungeon", label = L["Dungeon-Sets"], icon = "Interface\\Icons\\INV_Misc_Key_13" },
    { key = "pvp", label = L["PvP-Sets"], icon = "Interface\\Icons\\INV_BannerPVP_02" },
    { key = "craft", label = L["Handwerks-Sets"], icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { key = "world", label = L["Welt-Sets"], icon = "Interface\\Icons\\INV_Misc_Map_01" },
}
local CAT_OK, CAT_RANK = {}, {}
for i, c in ipairs(C.CATS) do CAT_OK[c.key], CAT_RANK[c.key] = true, i end
local CAT_OF_KIND = { X = "raid", D = "dungeon", P = "pvp", C = "craft", Q = "world", V = "world", R = "world", W = "world", A = "world" }

function C.ValidCat(key) return CAT_OK[key] == true end

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
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    all, allKey = out, key
    return out
end

-- How many sets a category holds in the level range (lo..hi; a set of unknown level always counts).
function C.Count(cat, lo, hi)
    local n = 0
    for _, s in ipairs(sets()) do
        if s.cat == cat and (s.level == 0 or (s.level >= lo and s.level <= hi)) then n = n + 1 end
    end
    return n
end

-- The sets of a category in the level range: { { id, name, cat, items, level, have, total } }.
function C.Sets(cat, lo, hi)
    local out = {}
    for _, s in ipairs(sets()) do
        if s.cat == cat and (s.level == 0 or (s.level >= lo and s.level <= hi)) then
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
    for _, s in ipairs(sets()) do
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
    for i, id in ipairs(s.items) do out[i] = entry(id, o) end
    return out
end

local function itemName(id)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local ok, name = pcall(C_Item.GetItemInfo, id)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- The items of the gear data whose name holds text (umlauts and case do not matter) and whose
-- required level is in lo..hi, the best gain for the own character first (no gain last, then by
-- name): list (C.MAX at most), how many matched, how many names are still missing (asked for).
function C.Search(text, lo, hi, o)
    local q = ns.Fold(text or "")
    q = q:gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" or not ns.HasData("GEAR") then return {}, 0, 0 end
    local d = ns.Data("GEAR")
    o = o or ns.BisOpts()
    local found, missing, asked = {}, 0, 0
    for id, row in pairs(d.I or {}) do
        local lv = tonumber(row[4]) or 0
        if lv >= lo and lv <= hi then
            local name = itemName(id)
            if name then
                if ns.Fold(name):find(q, 1, true) then found[#found + 1] = { id = id, name = name } end
            else
                missing = missing + 1
                -- the loader asks the client; the name arrives with GET_ITEM_INFO_RECEIVED
                if asked < ASK_MAX then
                    asked = asked + 1
                    Gear.Stats(id)
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
    return out, n, missing
end

-- Test hook: forget the set list.
function C._reset() all, allKey = nil, nil end
