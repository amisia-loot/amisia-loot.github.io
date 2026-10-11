-- Performance of the best-item targets and the dungeon planner with the real GearData.lua and the
-- real dungeon facts: a full recompute (the targets of the own character and every dungeon of the
-- list) stays under the design's 50 ms, measured as Lua time with four times that as the limit so
-- slow machines have room; the first call, which builds the index place -> items once, too. The
-- cached path (nothing changed) costs next to nothing. Every dungeon's info works on the real data.
local LIMIT = 0.2          -- 4 x 50 ms
local CACHED = 0.001       -- per call, with nothing changed
assert(NS.Gear.Available() and NS.DUNGEON_FACTS, "the real data")
local n = 0
for _ in pairs(NS.GEAR.I) do n = n + 1 end
assert(n > 3000, "the real item data: " .. n)

STUB.class, STUB.faction = "WARRIOR", "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }

local function timed(fn)
    local t0 = os.clock()
    local a, b = fn()
    return os.clock() - t0, a, b
end

STUB.level = 16
local first = timed(function() return NS.DungeonList() end)
assert(first < LIMIT, ("the first call with the index: %.1f ms"):format(first * 1000))

for _, class in ipairs({ "WARRIOR", "MAGE", "PRIEST", "HUNTER" }) do
    STUB.class = class
    for _, level in ipairs({ 16, 30, 45, 60 }) do
        STUB.level = level
        STUB.fire("PLAYER_LEVEL_UP")
        NS.BisBump()
        local full, list = timed(function()
            NS.BisTargets()
            return NS.DungeonList()
        end)
        assert(#list > 0, "dungeons at " .. level)
        assert(full < LIMIT, ("%s %d: full recompute %.1f ms"):format(class, level, full * 1000))
        local nextE = NS.DungeonNext()
        local reps = 200
        local cached = timed(function()
            for _ = 1, reps do NS.DungeonList(); NS.DungeonNext() end
        end) / reps
        assert(cached < CACHED, ("%s %d: cached %.3f ms"):format(class, level, cached * 1000))
        assert(NS.DungeonNext() == nextE, "the same answer from the cache")
    end
end

-- every dungeon of the facts answers out of reach too
STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_LEVEL_UP")
for _, e in ipairs(NS.DUNGEON_FACTS.list) do
    local spent, info = timed(function() return NS.DungeonInfo(e.key) end)
    assert(info and info.key == e.key, e.key)
    assert(spent < LIMIT, e.key)
end
