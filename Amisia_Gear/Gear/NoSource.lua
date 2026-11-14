-- Amisia gear without a known source (F-175, D-107): the scanned gear no source names
-- (Data/GearNoSource.lua, lazy GEAR_NOSRC, built by tools/build_gear.py from the item scan) for the
-- planner's suggestions. The planner asks for the items of a slot that pass the list's filters (level
-- range, the class, armour and weapon type, the class mask, the own exclusions, the weapon plan, and a
-- play style: an unknown source passes no switch but "Jetzt holbar" with its reputation) and shows
-- them only with the setting bis.noSource ("+ N weitere ohne bekannte Quelle"). The file is built the
-- first time the planner asks; once built, Gear.Item, Gear.ScannedStats, Gear.ScanName and
-- Gear.ScanIcon find its rows too (nothing else builds it). An item that gets a source later is a
-- normal entry of the gear data: the build never puts an id into both files. Nothing is sent.
local ADDON, ns = ...
ns.Load(function()
local Gear = ns.Gear

local NSR = {}
ns.GearNoSource = NSR

local NORM = { FINGER2 = "FINGER1", TRINKET2 = "TRINKET1" }

-- The built data, or nil (no file, not built yet with build false, or of another build than the gear
-- data: both files come from one run of the build and carry its stamp).
function NSR.Data(build)
    local d
    if build then
        d = ns.HasData("GEAR_NOSRC") and ns.Data("GEAR_NOSRC") or nil
    else
        d = ns.DataLoaded("GEAR_NOSRC") and ns.Data("GEAR_NOSRC") or nil
    end
    local g = type(d) == "table" and ns.HasData("GEAR") and ns.Data("GEAR") or nil
    return g and g.built == d.built and d or nil
end

-- Whether the planner shows them (the setting, default off).
function NSR.On() return ns.Get("bis.noSource") == true end   -- l10n-ok: setting key

function NSR.SetOn(on)
    ns.Set("bis.noSource", on and true or false)   -- l10n-ok: setting key
    if ns.Refresh then ns.Refresh() end
end

-- The row of a source-less item while the data is built, else nil (Gear.Item's fallback).
function NSR.Row(id)
    local d = NSR.Data(false)
    return d and type(d.I) == "table" and d.I[id] or nil
end

-- Whether an item has no source in the gear data (no row, or a row without sources): its wish and its
-- row say "Quelle unbekannt".
function NSR.Unknown(id)
    local row = Gear.Item(id)
    return row == nil or #row < Gear.FIRST_SOURCE
end

-- The groups of a slot of the planner: MAINHAND two-handers with the weapon plan "2H" (chosen, or the
-- targets' result), else one-handers and main hands; OFFHAND the off hands the plan allows (no
-- one-hander: its gain is the main hand's).
local function groupsOf(slot, res, o)
    local two = o.plan == "2H" or (res and res.plan == "2H")
    if slot == "MAINHAND" then
        if two then return { ["2H"] = true } end
        return { ["1H"] = true, MH = true }
    elseif slot == "OFFHAND" then
        if two then return {} end
        if o.plan == "DW" then return { OHW = true } end
        if o.plan == "SHIELD" then return { SHIELD = true, HELD = true } end
        return { OHW = true, SHIELD = true, HELD = true }
    end
    return nil
end

-- Whether the play style lets an item of unknown source in: no switch but "Jetzt holbar", which asks
-- for the item's reputation.
local function styleOk(id, st)
    if not st then return true end
    for k in pairs(st.on or {}) do
        if k ~= "now" then return false end
    end
    return ns.PlayStyle.ItemOk(id, st) and true or false
end

-- Whether a row passes the list's filters for slot (lo to hi; usable at the level the list counts with).
local function passes(id, row, o, slot, groups, lo, hi, level)
    local lv = math.max(1, tonumber(row[4]) or 0)
    if lv < lo or lv > hi then return false end
    local group = Gear.GROUP[row[1]]
    if not group then return false end
    if groups then
        if not groups[group] then return false end
    elseif Gear.CAP_ROW[group] ~= (NORM[slot] or slot) then
        return false
    end
    if not o.class or not Gear.Usable(o.class, row, level, o.spec) then return false end
    if (row[8] or 0) > 0 and not Gear.HasClassBit(row[8], o.class) then return false end
    local ex = o.exclude and o.exclude.item
    if ex and ex[id] then return false end
    return styleOk(id, o.style)
end

-- The items of a slot that pass the filters, best gain first: { { id, slotKey, level, owned, gain,
-- mine, upgrade, noSource = true } }; an item that scores nothing for the spec, or whose stats or gain
-- are not known, is none. key: the caller's cache key (the targets and the range); kept until it changes.
local memo = {}
function NSR.For(slot, o, res, lo, hi, key)
    local d = NSR.Data(true)
    if not d or type(d.I) ~= "table" then return {} end
    key = table.concat({ tostring(key), slot, lo, hi, tostring(ns.BisScoreStamp and ns.BisScoreStamp()) }, "|")
    if memo.key == key then return memo.rows end
    local rows = {}
    local groups = groupsOf(slot, res, o)
    local level = math.max(o.level or 1, hi)
    local g = ns.Data("GEAR")
    local sourced = g and g.I or {}
    for id, row in pairs(d.I) do
        -- an item of the gear data is a normal entry (the build never writes one into both files)
        if not sourced[id] and passes(id, row, o, slot, groups, lo, hi, level) then
            local gain, _, mine, score = ns.BisGain(id, o)
            if type(gain) == "number" and type(score) == "number" and score > 0 then
                local owned = ns.BisOwned(id)
                rows[#rows + 1] = { id = id, slotKey = slot, level = math.max(1, tonumber(row[4]) or 0), owned = owned,
                    gain = gain, mine = mine, noSource = true,
                    upgrade = owned ~= "worn" and ns.BisIsUpgrade(gain, mine) or false }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        return a.id < b.id
    end)
    memo.key, memo.rows = key, rows
    return rows
end

-- The sourced rows and the source-less ones as one list by gain: each list keeps its own order, a
-- source-less row goes before the first sourced row with less gain.
function NSR.Merge(sourced, extra)
    local out, i, j = {}, 1, 1
    while i <= #sourced or j <= #extra do
        local a, b = sourced[i], extra[j]
        if b and (not a or (b.gain or -math.huge) > (a.gain or -math.huge)) then
            out[#out + 1] = b
            j = j + 1
        else
            out[#out + 1] = a
            i = i + 1
        end
    end
    return out
end

function NSR.Reset() memo = {} end
end)
