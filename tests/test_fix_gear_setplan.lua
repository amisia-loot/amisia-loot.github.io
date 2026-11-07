-- The set plan (Gear.lua setPlan) takes a set once: a set of four reachable pieces with a bonus at
-- two pieces only is chosen with two pieces in the first pass; the second pass must not take the two
-- pieces left and count the same two-piece bonus a second time.
local Gear = NS.Gear
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

STUB.class, STUB.level, STUB.faction = "WARRIOR", 30, "Alliance"
NS.GEAR = { built = "test-fix-setplan", Z = {},
    S = { { "V", "Händler", 1429, "" } },
    I = {
        [201] = { "HEAD", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },   -- single heads, legs, chest, feet
        [202] = { "LEGS", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
        [203] = { "CHEST", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
        [204] = { "FEET", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
        [211] = { "HEAD", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },   -- the set's four pieces
        [212] = { "LEGS", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
        [213] = { "CHEST", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
        [214] = { "FEET", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
    },
    ST = {
        [201] = "STRENGTH=30", [202] = "STRENGTH=30", [203] = "STRENGTH=30", [204] = "STRENGTH=30",
        [211] = "STRENGTH=28", [212] = "STRENGTH=28", [213] = "STRENGTH=28", [214] = "STRENGTH=28",
    },
}
NS.GEAR_WEIGHTS = { brackets = { 60 }, order = { "WARRIOR" }, ratings = NS.GEAR_WEIGHTS.ratings,
    specs = { WARRIOR = { { key = "dps", name = "Waffen/Furor", role = "dps", unit = "AP", why = "Test.",
        all = { AP = 1, STR = 2 } } } } }
-- each piece loses 4 points against the single item; the bonus at two pieces is worth 20
NS.BIS = { SET = { [9] = { name = "Viererset", items = { 211, 212, 213, 214 }, b = { { 2, "STRENGTH=10" } } } },
    EF = { V = 1, C = 2, A = 2, Q = 2, D = 3, R = 8, W = 20, P = 25, X = 6, DMAX = 30 } }
C_Item.IsItemDataCachedByID = function() return false end
Gear._reset()
NS.BisSetSpec("dps")
local res = Gear.Best(NS.BisOpts())

assert(res.sets and #res.sets == 1, "the set once: " .. tostring(res.sets and #res.sets))
local info = res.sets[1]
assert(info.name == "Viererset" and info.have == 2 and near(info.bonus, 20), "two pieces for the two-piece bonus")
local pieces = 0
for _, slot in ipairs({ "HEAD", "LEGS", "CHEST", "FEET" }) do
    local e = res[slot][1]
    if e.set then pieces = pieces + 1 end
end
assert(pieces == 2, "two slots take the set, the others keep their single item: " .. pieces)
