-- The player tooltip's lines (F-169, D-99): a row of profession icons for a player whose professions
-- Amisia knows (the own characters, the guild's crafters of the recipe exchange, the guild notes;
-- ui.unitProfs) and the line "Gearscore 374 · Itemstufe 33" (ui.unitGear). The item level is the
-- average over the 17 gear slots without shirt and tabard (an empty slot counts 0, a two-hander
-- also for the empty off hand), for the own character the client's own number; the gear score is
-- Amisia's own: the sum over the worn items of item level times the slot's weight (UI.WEIGHT),
-- rounded. The own character at once; another player from a cache in memory (by GUID, UI.CACHE_MAX
-- players, UI.FRESH seconds) or, with ui.unitInspect, by inspecting the player under the mouse
-- through the shared helper Core/Inspect.lua; the line comes when the answer is there (nothing
-- while waiting). Items the client does not hold yet are asked for and counted when they arrive
-- (the value is provisional until then). Sends nothing, saves nothing.
local ADDON, ns = ...
local L = ns.L
local T = ns.Theme
local S = T.UNITINFO

local UI = {}
ns.UnitInfo = UI

UI.CACHE_MAX = 200    -- players kept
UI.FRESH = 600        -- seconds a value counts as fresh
UI.PROV_FRESH = 30    -- seconds a provisional value (items missing) counts as fresh
UI.RETRY = 30         -- seconds before the same player is inspected again after a request
UI.LATE_WAIT = 10     -- seconds Amisia waits for missing items after an answer
UI.LATE_TRIES = 5     -- reads of the missing items at most

-- The gear slots (inventory slots without shirt 4 and tabard 19) and their weights: the game's item
-- budget shares per slot (head, chest, legs 1; shoulder, waist, feet, hands 0.75; neck, wrist,
-- finger, back 0.5625; trinkets 0.75 as tools/build_bis.py groups them (BUDGET_SLOT: the shoulder's
-- column); ranged and relic 0.3164); weapons as slots of their own: main hand and off hand 1 each, a
-- two-hander 2 (UI.WEIGHT_2H).
UI.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
UI.WEIGHT = { [1] = 1, [2] = 0.5625, [3] = 0.75, [5] = 1, [6] = 0.75, [7] = 1, [8] = 0.75, [9] = 0.5625, [10] = 0.75,
    [11] = 0.5625, [12] = 0.5625, [13] = 0.75, [14] = 0.75, [15] = 0.5625, [16] = 1, [17] = 1, [18] = 0.3164 }
UI.WEIGHT_2H = 2

-- The professions in their fixed order: the main ones, then the secondary ones (Prof.SECONDARY).
UI.PROF_ORDER = { "alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring", "herbalism",
    "mining", "skinning", "cooking", "firstaid", "fishing", "poisons" }

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h, i
end

local function itemFn(name) return (C_Item and C_Item[name]) or _G[name] end

---------------------------------------------------------------------------
-- Gear score and item level
---------------------------------------------------------------------------
-- The score of items ({ [slot] = { ilvl, q (quality), two (a two-hander) } }): { gs, ilvl, q (the
-- average quality, rounded), n (items counted) }; nil without any item.
function UI.Score(items)
    local gs, sum, qs, qn, n = 0, 0, 0, 0, 0
    local mh = items[16]
    for _, slot in ipairs(UI.SLOTS) do
        local it = items[slot]
        if it then
            local w = (slot == 16 and it.two) and UI.WEIGHT_2H or UI.WEIGHT[slot]
            gs, sum, n = gs + it.ilvl * w, sum + it.ilvl, n + 1
            if it.q then qs, qn = qs + it.q, qn + 1 end
        end
    end
    if n == 0 then return nil end
    if mh and mh.two and not items[17] then sum = sum + mh.ilvl end
    return { gs = math.floor(gs + 0.5), ilvl = math.floor(sum / #UI.SLOTS), q = qn > 0 and math.floor(qs / qn + 0.5) or nil, n = n }
end

-- Asks the client for an item it does not hold yet.
local function load(id)
    id = tonumber(id)
    local fn = C_Item and C_Item.RequestLoadItemDataByID
    if id and type(fn) == "function" then pcall(fn, id) end
end

-- Item level, quality and whether it is a two-hander, of a link; nil while the client lacks the item.
local function itemOf(link)
    local name, _, q, base, _, _, _, _, loc = call(itemFn("GetItemInfo"), link)
    if not ns.Plain(name) then return nil end
    local lvl = tonumber(ns.Plain((call(itemFn("GetDetailedItemLevelInfo"), link)))) or tonumber(ns.Plain(base))
    if not lvl then return nil end
    return lvl, tonumber(ns.Plain(q)), ns.Plain(loc) == "INVTYPE_2HWEAPON"
end

-- The worn items of unit: items, the number of slots whose item the client does not hold yet.
function UI.ReadGear(unit)
    local items, missing = {}, 0
    for _, slot in ipairs(UI.SLOTS) do
        local link = ns.Plain(call(_G.GetInventoryItemLink, unit, slot))
        local id = ns.Plain(call(_G.GetInventoryItemID, unit, slot))
        if type(link) == "string" then
            local lvl, q, two = itemOf(link)
            if lvl then
                items[slot] = { ilvl = lvl, q = q, two = two }
            else
                missing = missing + 1
                load(id or link:match("item:(%d+)"))
            end
        elseif id then
            missing = missing + 1
            load(id)
        end
    end
    return items, missing
end

-- The own character: the score of the worn items, the client's item level (equipped) when it has one.
function UI.Own()
    local e = UI.Score((UI.ReadGear("player")))
    if not e then return nil end
    local avg, equipped = call(_G.GetAverageItemLevel)
    local lvl = tonumber(ns.Plain(equipped)) or tonumber(ns.Plain(avg))
    if lvl and lvl > 0 then e.ilvl = math.floor(lvl) end
    return e
end

-- "Gearscore 374 · Itemstufe 33": the words grey (the line's colour), the gear score in the average
-- quality's colour (gold without one), the item level white.
function UI.Text(e)
    local hex = e.q and T.QUALITY_HEX[e.q] or S.SCORE
    return L["Gearscore %s · Itemstufe %s"]:format(("|c%s%d|r"):format(hex, e.gs), ("|c%s%d|r"):format(S.ILVL, e.ilvl))
end

---------------------------------------------------------------------------
-- Other players: the cache and the inspect
---------------------------------------------------------------------------
local cache, cacheN = {}, 0   -- guid -> { gs, ilvl, q, n, prov (items missing), at }
local tried = {}              -- guid -> GetTime() of the last request
local late                    -- { guid, unit, untilAt, tries } an answer with items still missing
local retryOn

local function put(guid, e, prov)
    e.prov, e.at = prov or nil, GetTime()
    if not cache[guid] then cacheN = cacheN + 1 end
    cache[guid] = e
    while cacheN > UI.CACHE_MAX do
        local oldest, at
        for g, c in pairs(cache) do
            if not at or c.at < at then oldest, at = g, c.at end
        end
        cache[oldest], cacheN = nil, cacheN - 1
    end
end

-- The fresh value of a player (nil: none, or too old).
function UI.Cached(guid)
    local e = cache[guid]
    if not e then return nil end
    if GetTime() - e.at > (e.prov and UI.PROV_FRESH or UI.FRESH) then return nil end
    return e
end

-- Forgets every player (tests, a reload of the settings).
function UI.Reset()
    cache, cacheN, tried, late = {}, 0, {}, nil
end

-- A unit of guid now: hint when it still is that player, else the mouseover, target or focus.
local function unitOf(guid, hint)
    for _, u in ipairs({ hint, "mouseover", "target", "focus" }) do
        if type(u) == "string" and ns.Plain(UnitGUID(u)) == guid then return u end
    end
    return nil
end

-- The GUID of the player GameTooltip shows, and its unit.
local function shown()
    local tip = GameTooltip
    if not tip or not tip:IsShown() or type(tip.GetUnit) ~= "function" then return nil end
    local _, unit = tip:GetUnit()
    unit = ns.Plain(unit)
    if type(unit) ~= "string" then return nil end
    return ns.Plain(UnitGUID(unit)), unit
end

-- The tooltip again when it still shows guid (the client builds it anew: no line twice).
local function refresh(guid)
    local g, unit = shown()
    if not g or g ~= guid then return end
    local tip = GameTooltip
    if type(tip.RefreshData) == "function" then
        pcall(tip.RefreshData, tip)
    elseif type(tip.SetUnit) == "function" then
        pcall(tip.SetUnit, tip, unit)
    end
end

local function endLate()
    late = nil
    if not ns.Inspect.Pending() then ns.Inspect.Clear() end
end

-- Reads guid's gear from unit into the cache; true while items are still missing.
local function readInto(guid, unit)
    local items, missing = UI.ReadGear(unit)
    local e = UI.Score(items)
    if e then put(guid, e, missing > 0) end
    if e or missing == 0 then refresh(guid) end
    return missing > 0
end

-- The answer of Amisia's request: the gear read; with items missing the inspect is kept (true) and
-- read again when the client has them.
local function onGear(guid, unit)
    unit = unitOf(guid, unit)
    if not unit or not readInto(guid, unit) then return false end
    late = { guid = guid, unit = unit, untilAt = GetTime() + UI.LATE_WAIT, tries = 0 }
    C_Timer.After(UI.LATE_WAIT + 0.1, function()
        if late and late.guid == guid and GetTime() >= late.untilAt then endLate() end
    end)
    return true
end

local lateDue = false
local function onItemData()
    if not late or lateDue then return end
    lateDue = true
    C_Timer.After(0.3, function()
        lateDue = false
        local l = late
        if not l then return end
        l.tries = l.tries + 1
        local unit = GetTime() <= l.untilAt and unitOf(l.guid, l.unit)
        if not unit or not readInto(l.guid, unit) or l.tries >= UI.LATE_TRIES then endLate() end
    end)
end
ns.OnEvent("GET_ITEM_INFO_RECEIVED", onItemData)
ns.OnEvent("ITEM_DATA_LOAD_RESULT", onItemData)

-- Asks the client to inspect the player under the mouse (ui.unitInspect): once per UI.RETRY, through
-- the shared helper; while it is busy again as soon as it may, as long as the tooltip shows him.
local function ask(unit, guid)
    if not ns.Get("ui.unitInspect") then return end
    local t = tried[guid]
    if t and GetTime() - t < UI.RETRY then return end
    local ok, why = ns.Inspect.Request(unit, guid, onGear, { unitinfo = true })
    if ok then
        tried[guid] = GetTime()
    elseif why == "busy" and not retryOn then
        retryOn = true
        C_Timer.After(ns.Inspect.Wait() + 0.05, function()
            retryOn = false
            local g, u = shown()
            if g == guid and not UI.Cached(guid) then ask(u, guid) end
        end)
    end
end

-- The line of a player unit: own at once, others from the cache (asking for an inspect without).
function UI.GearEntry(unit)
    if unit == "player" or (type(UnitIsUnit) == "function" and ns.Plain(UnitIsUnit(unit, "player"))) then
        return UI.Own()
    end
    local guid = ns.Plain(UnitGUID(unit))
    if type(guid) ~= "string" then return nil end
    local e = UI.Cached(guid)
    if not e then ask(unit, guid) end
    return e
end

---------------------------------------------------------------------------
-- Professions
---------------------------------------------------------------------------
local ownList, ownAt
local function ownProfessions()
    if not ownAt or GetTime() - ownAt > 10 then
        ownList, ownAt = ns.Prof.Own and ns.Prof.Own() or {}, GetTime()
    end
    return ownList
end

local rosterOf, byName      -- the guild roster the index was built from, lower name -> member
local function member(low)
    local roster = ns.GuildRoster and ns.GuildRoster()
    if not roster then return nil end
    if roster ~= rosterOf then
        rosterOf, byName = roster, {}
        for _, m in ipairs(roster) do
            if type(m.name) == "string" then byName[m.name:lower()] = m end
        end
    end
    return byName[low]
end

local function ownChar(name)
    local p = AmisiaDB and AmisiaDB.prof
    local chars = type(p) == "table" and type(p.chars) == "table" and p.chars or nil
    if not chars then return nil end
    if type(chars[name]) == "table" then return chars[name] end
    local low = name:lower()
    for n, c in pairs(chars) do
        if type(n) == "string" and n:lower() == low and type(c) == "table" then return c end
    end
    return nil
end

-- The profession keys Amisia knows of a player (full name), in UI.PROF_ORDER; nil without any.
function UI.Professions(name)
    local Pr = ns.Prof
    if type(name) ~= "string" or not Pr or type(Pr.SKILL_LINES) ~= "table" then return nil end
    local skills = {}
    local me = ns.UnitFullName("player")
    if me and ns.SameName(name, me) then
        for _, p in ipairs(ownProfessions()) do skills[p.skill] = true end
    end
    for skill, s in pairs(ownChar(name) or {}) do
        if type(skill) == "number" and type(s) == "table" then skills[skill] = true end
    end
    local low = name:lower()
    local map = ns.Crafters and ns.Crafters.Professions and ns.Crafters.Professions()
    for _, p in ipairs(type(map) == "table" and map[low] or {}) do skills[p.skill] = true end
    local m = Pr.FromNote and member(low)
    if m then
        for _, text in ipairs({ m.note or "", m.officerNote or "" }) do
            for _, n in ipairs(Pr.FromNote(text)) do skills[n.skill] = true end
        end
    end
    local out = {}
    for _, key in ipairs(UI.PROF_ORDER) do
        if skills[Pr.SKILL_LINES[key]] and Pr.ICONS[key] then out[#out + 1] = key end
    end
    return #out > 0 and out or nil
end

-- The icons in a row ("|T...:14:14|t ..."), nil without any.
function UI.ProfIcons(name)
    local keys = UI.Professions(name)
    if not keys then return nil end
    local parts = {}
    for i, key in ipairs(keys) do parts[i] = ("|T%s:%d:%d|t"):format(ns.Prof.ICONS[key], S.ICON, S.ICON) end
    return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- The tooltip
---------------------------------------------------------------------------
local function onUnitTooltip(tip)
    if tip ~= GameTooltip or type(tip.GetUnit) ~= "function" then return end
    local gearOn, profsOn = ns.Get("ui.unitGear"), ns.FOREVER and ns.Get("ui.unitProfs")
    if not gearOn and not profsOn then return end
    local _, unit = tip:GetUnit()
    unit = ns.Plain(unit)
    if type(unit) ~= "string" or type(UnitIsPlayer) ~= "function" or not ns.Plain(UnitIsPlayer(unit)) then return end
    local w = S.WORDS
    if profsOn then
        local n, s = UnitName(unit)
        local icons = UI.ProfIcons(ns.FullName(ns.Plain(n), ns.Plain(s)))
        if icons then tip:AddLine(icons, w[1], w[2], w[3]) end
    end
    if gearOn then
        local e = UI.GearEntry(unit)
        if e then tip:AddLine(UI.Text(e), w[1], w[2], w[3]) end
    end
end
UI.OnUnitTooltip = onUnitTooltip

local function safe(tip)
    local ok, err = pcall(onUnitTooltip, tip)
    if not ok then geterrorhandler()(err) end
end

if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, safe)
elseif GameTooltip and type(GameTooltip.HookScript) == "function" and type(GameTooltip.HasScript) == "function"
    and GameTooltip:HasScript("OnTooltipSetUnit") then
    -- a client without the data processor: the tooltip's own script
    GameTooltip:HookScript("OnTooltipSetUnit", safe)
end
