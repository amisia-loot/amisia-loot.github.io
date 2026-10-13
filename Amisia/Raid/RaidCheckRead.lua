-- The readers of the raid check (F-098, spec docs/specs/2026-10-12-raid-check.md) and of the group
-- probe /amisia selbsttest gruppe (Core/SelfTestGroup.lua): one place that reads the buffs of a unit,
-- the durability, item level and enchant of the own worn items, the free talent points and the
-- saved instances. They read only; a secret value is skipped (never compared, D-20). A client
-- function that is missing raises { missing = path } (the probe shows it as FEHLT, the raid check
-- calls them protected).
local ADDON, ns = ...
local L = ns.L

local RR = {}
ns.RaidRead = RR

RR.MAX_AURAS = 40
RR.ENCHANT_LINE = 15      -- Enum.TooltipDataLineType.ItemEnchantmentPermanent in 1.60.1
-- worn slots without durability or enchant interest are left out (shirt 4, tabard 19)
local FALLBACK_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

function RR.isSecret(v)
    local f = _G.issecretvalue
    if type(f) ~= "function" then return false end
    local ok, s = pcall(f, v)
    return ok and s and true or false
end
local isSecret = RR.isSecret

local function lookup(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return type(v) == "function" and v or nil
end
RR.fn = lookup

-- Calls the client function at path; raises { missing = path } when the client lacks it.
local function call(path, ...)
    local f = lookup(path)
    if not f then error({ missing = path }) end
    return f(...)
end
RR.call = call

-- The worn slots in the gear planner's order with their names: { { inv, name } }.
function RR.Slots()
    local list = {}
    local G = ns.Gear
    if G and type(G.SLOTS) == "table" then
        for _, s in ipairs(G.SLOTS) do list[#list + 1] = { inv = s.inv, name = s.name } end
    else
        for _, inv in ipairs(FALLBACK_SLOTS) do list[#list + 1] = { inv = inv, name = L["Platz %d"]:format(inv) } end
    end
    return list
end

-- The helpful auras of unit: { n, secret, all = { aura or the secret value } }. An aura counts as
-- secret when the client marks it, its spell id or it is no table.
function RR.Auras(unit)
    local out = { n = 0, secret = 0, all = {} }
    for i = 1, RR.MAX_AURAS do
        local a = call("C_UnitAuras.GetAuraDataByIndex", unit, i, "HELPFUL")
        -- a secret answer is never compared (not even with nil)
        local secret = isSecret(a)
        if not secret and a == nil then break end
        out.n = out.n + 1
        if secret or type(a) ~= "table" or isSecret(a.spellId) then out.secret = out.secret + 1 end
        out.all[#out.all + 1] = a
    end
    return out
end

-- A readable aura's spell id, duration and seconds left (nil for a secret or broken one).
function RR.AuraInfo(a)
    if isSecret(a) or type(a) ~= "table" or isSecret(a.spellId) or type(a.spellId) ~= "number" then return nil end
    local dur, exp = a.duration, a.expirationTime
    dur = (not isSecret(dur) and type(dur) == "number") and dur or nil
    local left
    if not isSecret(exp) and type(exp) == "number" and exp > 0 then left = exp - GetTime() end
    local name = not isSecret(a.name) and type(a.name) == "string" and a.name or nil
    return a.spellId, dur, left, name
end

-- The durability of a worn slot: cur, max, percent; "secret"; or nil (the item has none).
function RR.Durability(inv)
    local cur, max = call("GetInventoryItemDurability", inv)
    if isSecret(cur) or isSecret(max) then return "secret" end
    if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    return cur, max, math.floor(cur / max * 100 + 0.5)
end

-- GetAverageItemLevel as the client gives it: average, equipped, PvP.
function RR.ItemLevel()
    return call("GetAverageItemLevel")
end

-- The tooltip line type of a permanent enchant on this client.
function RR.EnchantLineType()
    local enum = _G.Enum and Enum.TooltipDataLineType
    local v = type(enum) == "table" and enum.ItemEnchantmentPermanent
    return type(v) == "number" and v or RR.ENCHANT_LINE
end

-- The enchant of a worn item: { id = the enchant id in the link (0: none), lines = the tooltip lines
-- of the enchant type, text = the first one's text, kinds = { [line type] = count }, read = the
-- tooltip data had lines, secret = the tooltip data is secret }. withTooltip false: the link only.
function RR.Enchant(inv, link, withTooltip)
    local out = { id = tonumber(type(link) == "string" and link:match("item:%-?%d+:(%-?%d*)") or "") or 0, lines = 0, kinds = {} }
    if withTooltip == false or not lookup("C_TooltipInfo.GetInventoryItem") then return out end
    local data = call("C_TooltipInfo.GetInventoryItem", "player", inv)
    if isSecret(data) then
        out.secret = true
        return out
    end
    local lines = type(data) == "table" and type(data.lines) == "table" and data.lines or {}
    out.read = #lines > 0
    local wanted = RR.EnchantLineType()
    for _, line in ipairs(lines) do
        local kind = type(line) == "table" and line.type
        if not isSecret(kind) and type(kind) == "number" then
            out.kinds[kind] = (out.kinds[kind] or 0) + 1
            if kind == wanted then
                out.lines = out.lines + 1
                if not out.text and not isSecret(line.leftText) then out.text = line.leftText end
            end
        end
    end
    return out
end

-- The free talent points: free (a number) and the info of ns.Talents.Live; nil and a reason.
function RR.FreePoints()
    local T = ns.Talents
    if not T or not T.Available or not T.Available() then return nil, "nodata" end
    local plan, info = T.Live()
    if not plan then return nil, info end
    if type(info.free) == "number" then return info.free, info end
    return nil, info
end

-- The number of saved instances (0 for a secret answer).
function RR.SavedCount()
    local v = call("GetNumSavedInstances")
    return not isSecret(v) and tonumber(v) or 0, v
end

-- One saved instance by index: { name, id, reset, difficulty, locked, extended, isRaid, maxPlayers,
-- diffName, encounters, progress, mapID } as the client gives them (secret values stay as they are).
function RR.Saved(i)
    local name, id, reset, difficulty, locked, extended, _, isRaid, maxPlayers, diffName, encounters, progress, _, mapID = call("GetSavedInstanceInfo", i)
    return { name = name, id = id, reset = reset, difficulty = difficulty, locked = locked, extended = extended, isRaid = isRaid,
             maxPlayers = maxPlayers, diffName = diffName, encounters = encounters, progress = progress, mapID = mapID }
end
