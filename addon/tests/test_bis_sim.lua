-- ns.BisFor (Bis.lua): the best items for any class, spec and level without ownership or gains (the
-- simulation view and the planner table use it); computed stats count only for items no scan saw.
local Gear = NS.Gear
STUB.class, STUB.level, STUB.faction = "WARRIOR", 60, "Alliance"

-- a priest at 30 on the real data, while the player is a warrior at 60
local res = NS.BisFor("PRIEST", "holy", 30)
assert(res and res.total > 0, "a result for another class")
for _, sl in ipairs(Gear.SLOTS) do
    for _, e in ipairs(res[sl.key]) do
        local row = Gear.Item(e[1])
        assert(row and (row[4] or 0) <= 30, "nothing above level 30: " .. e[1])
        assert(Gear.Usable("PRIEST", row, 30), "a priest can wear " .. e[1])
        assert(e.gain == nil and e.owned == nil, "no ownership or gain in a simulation")
    end
end
-- the same as Gear.Best with the same options
local o = { class = "PRIEST", spec = "holy", kind = "Speedrun", level = 30, sources = NS.BisOpts().sources, prof = "all",
    plan = "auto", suffix = "best", sets = true, tie = 3 }
local direct = Gear.Best(o)
for _, sl in ipairs(Gear.SLOTS) do
    assert((res[sl.key][1] and res[sl.key][1][1]) == (direct[sl.key][1] and direct[sl.key][1][1]), sl.key)
end
-- the level is clamped, the spec defaults to the class's first
assert(NS.BisFor("MAGE", nil, 99).total > 0 and NS.BisFor("MAGE", nil, 0).total >= 0)
-- the plan reaches it
local shield = NS.BisFor("WARRIOR", "tank", 60, { plan = "SHIELD" })
assert(shield.plan == "1H" and shield.planWanted == "SHIELD")
for _, e in ipairs(shield.OFFHAND) do assert(not e.weapon, "only shields and held items") end

-- the planner table goes through ns.BisFor
local calls = 0
local real = NS.BisFor
NS.BisFor = function(...) calls = calls + 1; return real(...) end
NS.ToggleGearFrame()
local f = _G.AmisiaGearFrame
assert(f and f:IsShown(), "the table window")
assert(calls >= 1, "the table computes through ns.BisFor")
NS.ToggleGearFrame()
NS.BisFor = real

-- computed stats only without a scan
local REAL_BIS, REAL_GEAR = NS.BIS, NS.GEAR
local scanned
for id in pairs(NS.GEAR.ST or {}) do scanned = id break end
NS.BIS = { SC = { [scanned] = "STRENGTH=999", [424242] = "STRENGTH=7" }, EF = REAL_BIS.EF }
Gear._reset()
local s = Gear.Stats(scanned)
assert(s and not s.SC and (s.STR or 0) ~= 999, "the scan wins over a computed value")
assert(Gear.ComputedStats(424242).STR == 7 and Gear.ComputedStats(424242).SC)
NS.BIS = REAL_BIS
Gear._reset()
