-- The generated Forever data (GearData.lua, GearWeights.lua) as the only data set: it loads, every
-- row names its equip location (the addon fills no blank rows any more), every source is of a known
-- kind with a text, and the old dungeon records are found by their name.
local Gear = NS.Gear
assert(Gear.Available() and Gear.Cap() == 60, "the Forever set with level cap 60")
assert(NS.GEAR.game == nil or NS.GEAR.game == "forever", "no field or forever: " .. tostring(NS.GEAR.game))
assert(not NS.GEAR.I[28770], "no TBC rows")
assert(#NS.GEAR_WEIGHTS.brackets == #Gear.COLUMNS, "the Forever weights with one bracket per planner column")
for i, c in ipairs(Gear.COLUMNS) do assert(NS.GEAR_WEIGHTS.brackets[i] == c[2], "bracket " .. i .. " ends at " .. c[2]) end

-- every row: a known equip location (no "" to fill from the client), numbers in the fixed fields,
-- field 10 a skill line or 0 (never the { skill line, rank } form), known sources with a text
local d = NS.GEAR
local n, kinds = 0, {}
for id, row in pairs(d.I) do
    n = n + 1
    assert(type(id) == "number" and type(row[1]) == "string" and row[1] ~= "", "equip location of " .. tostring(id))
    assert(Gear.GROUP[row[1]], "known equip location " .. row[1] .. " on " .. id)
    for i = 2, 10 do assert(type(row[i]) == "number", "field " .. i .. " of " .. id) end
    assert(#row >= Gear.FIRST_SOURCE, "every item has a source: " .. id)
    for i = Gear.FIRST_SOURCE, #row do
        local rec = d.S[row[i]]
        assert(rec and Gear.KIND_ORDER[rec[1]], "source " .. row[i] .. " of " .. id)
        kinds[rec[1]] = true
        assert(type(Gear.SourceText(rec)) == "string")
    end
end
assert(n > 1000, "thousands of items: " .. n)
for _, k in ipairs({ "Q", "D", "V", "C", "W" }) do assert(kinds[k], "source kind " .. k) end
assert(not kinds.F, "no reputation sources in Forever data")

-- GearData.lua built before the instance ids holds a zone in a dungeon record's fifth field; until
-- it is rebuilt on the PC such records are found by their dungeon name, not as an instance
if not NS.GEAR.game then
    local seen = 0
    for _, rec in ipairs(NS.GEAR.S) do
        if rec[1] == "D" and rec[5] then
            seen = seen + 1
            assert(Gear.PlaceOf(rec) == "N:" .. rec[2], "old record by name: " .. tostring(Gear.PlaceOf(rec)))
        end
    end
    assert(seen > 0, "the old data has such records")
end

-- a best list comes out of it once the client describes the items
Gear._reset()
local o = { class = "WARRIOR", spec = "dps", kind = "Speedrun", level = 60,
    sources = { X = true, Q = true, D = true, V = true, C = true, W = true } }
local r = Gear.Best(o)
assert(r.total > 0 and r.missing > 0, "the rows wait for the client")
