-- The scoring core of 2.4 (Gear.lua, Bis.lua) on the build's own weights: parts sum to the score
-- (weapon speed above the reference, the set bonus, hit over the cap); the set plan (a bonus from
-- its threshold, an unscored bonus, the switch); the best seen random suffix against the base
-- stats; the weapon plans 2H, DW and SHIELD; the hit cap with and without the client's API; the
-- effort tie; stats computed by the build for unscanned items; ns.BisCompare and ns.BisWhy; the
-- generated weights' shape.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function sum(parts) local n = 0; for _, p in ipairs(parts) do n = n + p.points end; return n end

---------------------------------------------------------------------------
-- the generated weights
---------------------------------------------------------------------------
local G = NS.GEAR_WEIGHTS
assert(G.ratings and G.ratings.CRIT and G.built, "ratings and the build date")
local war = Gear.SpecInfo("WARRIOR", "dps")
assert(war.unit == "AP" and has(war.why, "Krieger") and #war.ref == 12)
local w60 = Gear.Weights("WARRIOR", "dps", "Speedrun", 60)
assert(w60.AP == 1 and w60.STR == 2 and w60.DPS == 14 and w60.SPDREF_2H, "the unit, strength, weapon damage, the speed reference")
local h60 = Gear.Weights("WARRIOR", "dps", "Hardcore", 60)
assert(h60.STA > w60.STA and (h60.ARMOR or 0) > (w60.ARMOR or 0), "Hardcore weighs survival more")
assert(Gear.Weights("WARRIOR", "dps", "Speedrun", 12) == war.Speedrun[2], "12 brackets: 10-14 is the second")
for _, cls in ipairs(G.order) do
    for _, sp in ipairs(Gear.Specs(cls)) do
        for i = 1, 12 do
            local w = sp.Speedrun[i]
            assert(w[sp.unit] == 1, cls .. " " .. sp.key .. ": the unit weighs 1")
            for k, v in pairs(w) do assert(v >= 0, cls .. " " .. sp.key .. " " .. k .. " is negative") end
        end
    end
end
-- the rating curve comes from the weights file
assert(near(Gear.RatingPerPoint("CRIT", 60) * G.ratings.CRIT, 1))

---------------------------------------------------------------------------
-- parts: weapon speed above the reference, the set bonus, the cap
---------------------------------------------------------------------------
local w = { AP = 1, STR = 2, DPS = 14, SPD_2H = 50, SPDREF_2H = 3.3, HIT = 15, CRIT = 12 }
local s = { STR = 10, DPS = 40, SPEED = 3.8, HIT = 20, SETB = 7 }
local score = Gear.Score(s, w, 60, "2H", "WARRIOR")
assert(near(score, 20 + 560 + 0.5 * 50 + 2 * 15 + 7), "speed counts above 3.3: " .. score)
local parts = Gear.ScoreParts(s, w, 60, "2H", "WARRIOR")
assert(near(sum(parts), score), "the parts sum to the score")
local texts = {}
for _, p in ipairs(parts) do texts[#texts + 1] = Gear.PartText(p) end
local joined = table.concat(texts, "\n")
assert(has(joined, "Waffentempo 3,8 s: +25") and has(joined, "Setbonus: +7"), joined)
-- hit over the cap counts 0 and shows apart
local capped = Gear.Score(s, w, 60, "2H", "WARRIOR", { HIT = 0.5 })
assert(near(capped, score - 1.5 * 15), "only 0,5 % of the 2 % hit count: " .. capped)
parts = Gear.ScoreParts(s, w, 60, "2H", "WARRIOR", { HIT = 0.5 })
assert(near(sum(parts), capped))
local over
for _, p in ipairs(parts) do if p.over then over = p end end
assert(over and over.points == 0 and has(Gear.PartText(over), "1,5 % Trefferwertung über der Grenze: 0"), "the part over the cap")
assert(near(Gear.Score(s, w, 60, "2H", "WARRIOR", { HIT = 0 }), score - 2 * 15), "no room: hit counts nothing")
assert(near(Gear.Score(s, w, 60, "2H", "WARRIOR", { SHIT = 0 }), score), "the spell room never limits a melee class's hit")

---------------------------------------------------------------------------
-- a small data set: sets, suffixes, plans, effort, computed stats
---------------------------------------------------------------------------
local REAL_GEAR, REAL_W, REAL_BIS = NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS
STUB.class, STUB.level, STUB.faction = "WARRIOR", 30, "Alliance"
NS.GEAR = { built = "test-weights", Z = {},
    S = {
        { "V", "Händler", 1429, "" },                       -- 1  effort 1
        { "D", "Verlies", "Boss", "5%" },                   -- 2  effort min(30, 3 / 0.05) = 30
        { "Q", "Eine Quest", 30, 25, "", 1429, 77, 0 },     -- 3  effort 2
    },
    I = {
        [101] = { "HEAD", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },          -- single best head
        [102] = { "HEAD", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },          -- set head
        [103] = { "LEGS", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },          -- single best legs
        [104] = { "LEGS", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },          -- set legs
        [105] = { "CHEST", 4, 3, 1, 3, 1, 30, 0, 0, 0, 2 },         -- chest from a dungeon, 1 point better
        [106] = { "CHEST", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },         -- chest from a vendor
        [107] = { "FEET", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },          -- random suffix boots
        [108] = { "FEET", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
        [109] = { "HAND", 4, 3, 1, 3, 1, 30, 0, 0, 0, 3 },         -- computed stats only
        [110] = { "2HWEAPON", 2, 1, 1, 3, 1, 30, 0, 3.6, 0, 1 },
        [111] = { "WEAPON", 2, 0, 1, 3, 1, 30, 0, 2.6, 0, 1 },
        [112] = { "WEAPON", 2, 0, 1, 3, 1, 30, 0, 2.4, 0, 1 },
        [113] = { "SHIELD", 4, 6, 1, 3, 1, 30, 0, 0, 0, 1 },
    },
    ST = {
        [101] = "STRENGTH=30", [102] = "STRENGTH=26", [103] = "STRENGTH=40", [104] = "STRENGTH=37",
        [105] = "STRENGTH=50", [106] = "STRENGTH=49.5", [107] = "STRENGTH=10", [108] = "STRENGTH=12",
        [110] = "DAMAGE_PER_SECOND=40;STRENGTH=10", [111] = "DAMAGE_PER_SECOND=20;STRENGTH=5",
        [112] = "DAMAGE_PER_SECOND=19;STRENGTH=4", [113] = "STRENGTH=8;RESISTANCE0_NAME=500",
    },
}
NS.GEAR_WEIGHTS = { brackets = { 60 }, order = { "WARRIOR" }, ratings = G.ratings,
    specs = { WARRIOR = { { key = "dps", name = "Waffen/Furor", role = "dps", unit = "AP", why = "Test.",
        all = { AP = 1, STR = 2, DPS = 14, OHDPS = 0.4, ARMOR = 0.01, HIT = 15 } } } } }
NS.BIS = {
    SC = { [109] = "STRENGTH=20;STAMINA=5" },
    SET = { [7] = { name = "Testrüstung", items = { 102, 104 }, b = { { 2, "STRENGTH=10" } } } },
    RP = { [107] = { [-71] = "STRENGTH=10;AGILITY=0;STAMINA=0", [-72] = "STRENGTH=16" } },
    EF = { V = 1, C = 2, A = 2, Q = 2, D = 3, R = 8, W = 20, P = 25, X = 6, DMAX = 30 },
}
C_Item.IsItemDataCachedByID = function() return false end
Gear._reset()
NS.BisSetSpec("dps")
local o = NS.BisOpts()
assert(o.plan == "auto" and o.suffix == "best" and o.sets == true and o.tie == 3, "the defaults")

local res = Gear.Best(o)
-- set: head -8 and legs -6 against singles, +20 bonus at two pieces: the set wins by 6
assert(res.HEAD[1][1] == 102 and res.LEGS[1][1] == 104, "the set takes head and legs")
local set = res.HEAD[1].set
assert(set and set.name == "Testrüstung" and set.have == 2 and set.total == 2 and near(set.bonus, 20), "the set mark")
assert(res.sets and #res.sets == 1)
o.sets = false
res = Gear.Best(o)
assert(res.HEAD[1][1] == 101 and not res.HEAD[1].set, "without the switch the single items")
o.sets = true
-- an unscored bonus never makes a set plan
NS.BIS.SET = { [7] = { name = "Testrüstung", items = { 102, 104 }, b = { { 2, "" } } } }
res = Gear.Best(o)
assert(res.HEAD[1][1] == 101, "a bonus without a simple effect counts 0")
NS.BIS.SET = { [7] = { name = "Testrüstung", items = { 102, 104 }, b = { { 2, "STRENGTH=10" } } } }

-- random suffix: the best seen one, or the base stats
res = Gear.Best(o)
local boots = res.FEET[1]
assert(boots[1] == 107 and boots.suffix == -72 and near(boots[2], 32), "the best seen suffix (16 strength)")
o.suffix = "base"
res = Gear.Best(o)
assert(res.FEET[1][1] == 108 and not res.FEET[1].suffix, "base stats only")
o.suffix = "best"
-- the own collector's suffixes count too
AmisiaDB.scan = AmisiaDB.scan or {}
AmisiaDB.scan.suffix = { [108] = { [-80] = "STRENGTH=20" } }
res = Gear.Best(o)
assert(res.FEET[1][1] == 108 and res.FEET[1].suffix == -80, "a suffix the own collector saw")
AmisiaDB.scan.suffix = nil

-- effort: the vendor chest is within 3 % of the dungeon chest and comes first, marked
res = Gear.Best(o)
assert(res.CHEST[1][1] == 106 and res.CHEST[1].easier and res.CHEST[2][1] == 105, "easier to get first")
assert(near(res.CHEST[1][2], 99) and near(res.CHEST[2][2], 100), "scores unchanged")
assert(res.CHEST[1].effort == 1 and res.CHEST[2].effort == 30)
o.tie = 0
res = Gear.Best(o)
assert(res.CHEST[1][1] == 105 and not res.CHEST[1].easier, "tie 0: score only")
o.tie = 3

-- computed stats: hands only from the build, marked
res = Gear.Best(o)
assert(res.HANDS[1][1] == 109 and res.HANDS[1].sc, "computed stats count and are marked")

-- weapon plans
res = Gear.Best(o)
assert(res.plan == "2H" and res.MAINHAND[1][1] == 110, "auto: the two-hander (40 dps + speed)")
assert(res.twoHandScore and res.oneHandScore and res.dwScore and res.shieldScore, "every plan has its sum")
o.plan = "SHIELD"
res = Gear.Best(o)
assert(res.plan == "1H" and res.MAINHAND[1][1] == 111 and res.OFFHAND[1][1] == 113 and #res.OFFHAND == 1, "weapon and shield")
o.plan = "DW"
res = Gear.Best(o)
assert(res.plan == "1H" and res.OFFHAND[1][1] == 112 and res.OFFHAND[1].weapon, "two weapons: the second one-hander off hand")
o.plan = "2H"
res = Gear.Best(o)
assert(res.plan == "2H" and res.planWanted == "2H")
STUB.level = 15
o = NS.BisOpts()
o.plan = "DW"
res = Gear.Best(o)
assert(res.planWanted == "auto", "a warrior below 20 cannot dual wield: the plan falls back")
STUB.level = 30
-- the plan is the character's
assert(NS.BisSetPlan("SHIELD") and NS.BisOpts().plan == "SHIELD")
assert(NS.BisTargets().OFFHAND[1].id == 113)
assert(not NS.BisSetPlan("x"))
NS.BisSetPlan("auto")

---------------------------------------------------------------------------
-- the hit cap through the client's character sheet
---------------------------------------------------------------------------
NS.GEAR.I[120] = { "WAIST", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 }
NS.GEAR.ST[120] = "HIT_RATING=30"
Gear._reset()
assert(NS.BisOpts().cap == nil, "no API: no cap")
local explain = table.concat(NS.BisExplain(120), "\n")
assert(has(explain, "Trefferwertung zählt ohne Obergrenze"), explain)
GetCombatRatingBonus = function(cr) return cr == 6 and 5 or 0 end
GetHitModifier = function() return 0 end
local caps = NS.BisOpts().cap
assert(caps and near(caps.WAIST.HIT, 1), "6 % cap, 5 % worn: 1 % room")
local u = NS.UpgradeOf(120)
local per = Gear.RatingPerPoint("HIT", 30)
assert(u and near(u.score, 1 * 15), "only the room counts: " .. tostring(u and u.score) .. " (" .. 30 * per .. " % on the item)")
explain = table.concat(NS.BisExplain(120), "\n")
assert(not has(explain, "ohne Obergrenze") and has(explain, "über der Grenze: 0"), explain)
NS.Set("bis.hitCap", false)
assert(NS.BisOpts().cap == nil, "the switch")
NS.Reset("bis.hitCap")
GetCombatRatingBonus, GetHitModifier = nil, nil

---------------------------------------------------------------------------
-- compare, why
---------------------------------------------------------------------------
local cmp = NS.BisCompare(103, 104, nil, { "Option 1", "Option 2" })
assert(cmp and near(cmp.diff, 6) and cmp.text == "Option 1 liegt 6 vorn, vor allem durch Stärke.", cmp and cmp.text)
assert(cmp.lines[1] == "+3 Stärke (+6)", cmp.lines[1])
cmp = NS.BisCompare(104, 103, nil, { "Option 1", "Option 2" })
assert(cmp.text == "Option 2 liegt 6 vorn, vor allem durch Stärke.", cmp.text)
assert(NS.BisCompare(103, 103).text:find("gleichauf"))
assert(select(2, NS.BisCompare(103, 999999)) ~= nil, "a reason when one side is no gear")
NS.GEAR_WEIGHTS = REAL_W
local why = NS.BisWhy({ class = "WARRIOR", spec = "dps", kind = "Speedrun", level = 30 })
assert(has(why[1], "Krieger") and has(why[2], "1 Angriffskraft") and has(why[3], "Bezug Level 34") and has(why[3], "Angriffskraft"),
    table.concat(why, " | "))
STUB.messages = {}
NS.BisWeightsReport()
local said = table.concat(STUB.messages, "\n")
assert(has(said, "Gewichte (") and has(said, "Stärke") and has(said, "ohne Obergrenze"), said)

NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS = REAL_GEAR, REAL_W, REAL_BIS
Gear._reset()
