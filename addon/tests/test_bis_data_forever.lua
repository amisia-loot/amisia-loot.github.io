--[[preload
STUB.toc = 16001
]]
-- On the Forever client the guard of BisDataTBC.lua and BisWeightsTBC.lua skips them, so the
-- Forever set stays (even if the TOC load condition let them through).
local Gear = NS.Gear
assert(NS.IsForever(), "the preload makes this the Forever client")
assert(Gear.Available() and Gear.Game() == "forever" and Gear.Cap() == 60, "the Forever set: " .. tostring(Gear.Game()))
assert(NS.GEAR.game ~= "tbc" and not NS.GEAR.I[28770], "no TBC rows")
assert(#NS.GEAR_WEIGHTS.brackets == 6, "the Forever weights with their level brackets")
assert(Gear.PlannerAvailable())

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

-- loading the TBC files again by hand on Forever changes nothing
for _, name in ipairs({ "BisDataTBC.lua", "BisWeightsTBC.lua" }) do
    local fh = assert(io.open(ADDON_DIR .. "/" .. name, "r"))
    local src = fh:read("*a")
    fh:close()
    assert(loadstring(src, "@" .. name))("Amisia", NS)
end
assert(Gear.Game() == "forever" and #NS.GEAR_WEIGHTS.brackets == 6, "the guard returned before touching anything")
