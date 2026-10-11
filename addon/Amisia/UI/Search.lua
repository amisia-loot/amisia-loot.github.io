-- The main window's search (D-45): what the search box over the page list finds, grouped "Seiten",
-- "Einstellungen", "Items", "Spieler". UI/MainFrame.lua shows the hits in place of the page list and
-- runs a hit's action on a click. Kept fast: nothing at all under T.MAIN.SEARCH_MIN characters,
-- items only once the gear data is built or from 3 characters on (only then may the gear data be
-- built), the indexes of items and players built once and kept for a while, at most RES_MAX hits per
-- group. Item names come only from what the client already holds (AmisiaDB.itemNames and cached
-- items): the search never asks the server for an item. Players only in the officer view (D-36: the
-- numbers per player are the officers').
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme
local M = T.MAIN

local Search = {}
ns.SearchIndex = Search

Search.ITEM_MIN = 3        -- characters before the gear data may be built for the item names
Search.KEEP = 60           -- seconds an index is kept before it is built again
local SETTINGS_ICON = "Interface\\Icons\\Trade_Engineering"

local function hit(text, q)
    return type(text) == "string" and text:lower():find(q, 1, true) ~= nil
end

local function now() return GetTime and GetTime() or 0 end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
local items, itemsAt, itemsGear   -- { { id, name, low, q } }, when built, the gear table it read

local function itemInfo(id)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local ok, name, link, q = pcall(C_Item.GetItemInfo, id)
    if ok then return name, link, q end
    return nil
end

-- The item names the client holds: those Amisia saw (loot, awards, soft-reserves) and, when allowed,
-- the gear data's items the client has cached (no server question).
local function itemIndex(withGear)
    local gear = withGear and ns.Data and ns.HasData("GEAR") and ns.Data("GEAR") or rawget(ns, "GEAR")
    if items and itemsGear == gear and now() - itemsAt < Search.KEEP then return items end
    local out, seen = {}, {}
    local known = AmisiaDB and AmisiaDB.itemNames or {}
    for id, e in pairs(known) do
        local name = type(e) == "table" and e.n
        if type(id) == "number" and type(name) == "string" and name ~= "" and name ~= ("Item " .. id) then
            seen[id] = true
            out[#out + 1] = { id = id, name = name, low = name:lower(), q = tonumber(e.q) }
        end
    end
    local cached = C_Item and C_Item.IsItemDataCachedByID
    if type(gear) == "table" and type(gear.I) == "table" and cached then
        for id in pairs(gear.I) do
            if type(id) == "number" and not seen[id] and cached(id) then
                local name, _, q = itemInfo(id)
                if type(name) == "string" and name ~= "" then
                    seen[id] = true
                    out[#out + 1] = { id = id, name = name, low = name:lower(), q = q }
                end
            end
        end
    end
    items, itemsAt, itemsGear = out, now(), gear
    return out
end

-- The item's link into the chat line (the open one, else the chat opens with it).
local function linkToChat(id)
    local _, link = itemInfo(id)
    if not link then return end
    local CU = _G.ChatFrameUtil
    if CU and CU.InsertLink and CU.InsertLink(link) then return end
    if CU and CU.OpenChat then CU.OpenChat(link) end
end

local function itemHits(q)
    local gearBuilt = rawget(ns, "GEAR") ~= nil
    if not gearBuilt and #q < Search.ITEM_MIN then return {} end
    local found = {}
    for _, e in ipairs(itemIndex(#q >= Search.ITEM_MIN)) do
        if e.low:find(q, 1, true) then found[#found + 1] = e end
    end
    table.sort(found, function(a, b)
        local sa, sb = a.low:sub(1, #q) == q, b.low:sub(1, #q) == q
        if sa ~= sb then return sa end
        return a.low < b.low
    end)
    local out = {}
    for i = 1, math.min(#found, M.RES_MAX) do
        local e = found[i]
        local color = e.q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.q]
        out[i] = { text = e.name, label = color and color.hex and (color.hex .. e.name .. "|r") or e.name, item = e.id,
            icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id) or nil,
            run = function() linkToChat(e.id) end }
    end
    return out
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local players, playersAt   -- { { name, low, class } }

local function playerIndex()
    if players and now() - playersAt < Search.KEEP then return players end
    local out, byLow = {}, {}
    local function add(name, class)
        if type(name) ~= "string" or name == "" or name == "-" then return end
        local low = name:lower()
        local e = byLow[low]
        if not e then
            e = { name = name, low = low }
            byLow[low] = e
            out[#out + 1] = e
        end
        if type(class) == "string" and class ~= "" then e.class = e.class or class end
    end
    for _, s in ipairs(ns.Sessions and ns.Sessions() or {}) do
        for name, m in pairs(type(s.members) == "table" and s.members or {}) do add(name, type(m) == "table" and m.class) end
        for _, a in ipairs(type(s.awards) == "table" and s.awards or {}) do
            if a.to == nil or a.to == "player" then add(a.name) end
        end
    end
    local lineup = AmisiaDB and AmisiaDB.lineup
    for _, n in pairs(type(lineup) == "table" and type(lineup.nights) == "table" and lineup.nights or {}) do
        for _, e in ipairs(type(n) == "table" and type(n.list) == "table" and n.list or {}) do add(e.n, e.c) end
    end
    players, playersAt = out, now()
    return out
end

local function playerHits(q)
    if not ns.IsOfficerView() then return {} end
    local found = {}
    for _, e in ipairs(playerIndex()) do
        if e.low:find(q, 1, true) then found[#found + 1] = e end
    end
    table.sort(found, function(a, b) return a.low < b.low end)
    local out = {}
    for i = 1, math.min(#found, M.RES_MAX) do
        local e = found[i]
        local c = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
        out[i] = { text = e.name, label = c and c.colorStr and ("|c%s%s|r"):format(c.colorStr, e.name) or e.name,
            atlas = e.class and ("groupfinder-icon-class-" .. e.class:lower()) or nil,
            icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", tip = L["Öffnet die Statistik dieses Spielers."],
            run = function() if ns.ShowStats then ns.ShowStats("players", e.name) end end }
    end
    return out
end

---------------------------------------------------------------------------
-- Pages and settings
---------------------------------------------------------------------------
local function pageHits(q)
    local out = {}
    for _, p in ipairs(ns.panels) do
        if #out >= M.RES_MAX then break end
        if ns.Visible(p) and hit(p.label, q) then
            out[#out + 1] = { text = p.label, icon = p.icon, run = function() ns.ShowPage(p.key) end }
        end
    end
    return out
end

local function settingHits(q)
    local out = {}
    for _, section in ipairs(ns.schema) do
        if ns.Visible(section) then
            for _, it in ipairs(section.items) do
                if #out >= M.RES_MAX then return out end
                if it.key and it.label and it.type ~= "desc" and ns.Visible(it) and ns.SettingHits(it, q) then
                    out[#out + 1] = { text = it.label, icon = SETTINGS_ICON, tip = section.label .. (it.tip and ("\n" .. it.tip) or ""),
                        run = function() if ns.ShowSettings then ns.ShowSettings(it.label) end end }
                end
            end
        end
    end
    return out
end

-- The hits of text: { { key, label, hits = { { text, label, icon or atlas, tip, item, run } } } },
-- the groups without a hit left out; nothing under SEARCH_MIN characters.
function ns.Search(text)
    local q = (tostring(text or ""):match("^%s*(.-)%s*$") or ""):lower()
    if #q < M.SEARCH_MIN then return {} end
    local groups = {
        { key = "pages", label = L["Seiten"], find = pageHits },
        { key = "settings", label = L["Einstellungen"], find = settingHits },
        { key = "items", label = "Items", find = itemHits },
        { key = "players", label = L["Spieler##Suche"], find = playerHits },
    }
    local out = {}
    for _, g in ipairs(groups) do
        -- a broken group must not stop the typing: its error goes to the client's handler
        local ok, hits = pcall(g.find, q)
        if not ok then
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(hits) end
        elseif #hits > 0 then
            out[#out + 1] = { key = g.key, label = g.label, hits = hits }
        end
    end
    return out
end

-- for the tests: forget the indexes
function Search._reset() items, itemsAt, itemsGear, players, playersAt = nil, nil, nil, nil, nil end

ns.Listen("DATA_CHANGED", function() players = nil end)
