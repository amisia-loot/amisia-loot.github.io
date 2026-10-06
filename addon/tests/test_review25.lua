-- Review 25 (2.5): computed stats stay for an item the client never describes; generic hit rating
-- splits into a melee part (melee room) and a spell part (spell room, spell rate), so the cap
-- limits casters; ns.BisCompare and the page's comparison count the random suffix the ranking
-- chose; the set plan puts the set bonus on the moved pieces (ranking, gain and comparison agree);
-- the parsed random suffixes are kept per item; an archived trash NPC in the drop base stock is no
-- boss. Every check runs, the failures are listed together.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local REAL_GEAR, REAL_W, REAL_BIS = NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS
local G = REAL_W

-- the small data set of test_bis_weights.lua
local function fixture()
    STUB.class, STUB.level, STUB.faction = "WARRIOR", 30, "Alliance"
    NS.GEAR = { built = "test-review25", Z = {},
        S = {
            { "V", "Händler", 1429, "" },
            { "D", "Verlies", "Boss", "5%" },
            { "Q", "Eine Quest", 30, 25, "", 1429, 77, 0 },
        },
        I = {
            [101] = { "HEAD", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
            [102] = { "HEAD", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
            [103] = { "LEGS", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
            [104] = { "LEGS", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
            [107] = { "FEET", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
            [108] = { "FEET", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 },
            [109] = { "HAND", 4, 3, 1, 3, 1, 30, 0, 0, 0, 3 },
        },
        ST = {
            [101] = "STRENGTH=30", [102] = "STRENGTH=26", [103] = "STRENGTH=40", [104] = "STRENGTH=37",
            [107] = "STRENGTH=10", [108] = "STRENGTH=12",
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
    AmisiaDB.scan = AmisiaDB.scan or {}
    AmisiaDB.scan.suffix = nil
    Gear._reset()
    NS.BisBump()
    NS.BisSetSpec("dps")
end
local function restore()
    NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS = REAL_GEAR, REAL_W, REAL_BIS
    Gear._reset()
    NS.BisBump()
end

local failures = {}
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
    restore()
end

---------------------------------------------------------------------------
-- 1. an item the client never describes keeps its computed stats
---------------------------------------------------------------------------
check("1 computed stats after a failed load", function()
    fixture()
    local o = NS.BisOpts()
    local r = Gear.Best(o)
    assert(r.HANDS[1] and r.HANDS[1][1] == 109 and r.HANDS[1].sc, "before: the computed hands")
    STUB.tick(0.3); STUB.fire("ITEM_DATA_LOAD_RESULT", 109, false); STUB.tick(30)
    NS.BisBump()
    r = Gear.Best(o)
    assert(r.HANDS[1] and r.HANDS[1][1] == 109 and r.HANDS[1].sc, "after the failed load the computed stats still count")
    local s, failed = Gear.Stats(109)
    assert(s and s.SC and s.STR == 20 and failed == true, "Gear.Stats: the computed stats and the failed mark")
    local u = NS.UpgradeOf(109)
    assert(u and near(u.score, 40 + 0), "the tooltip scores the computed stats: " .. tostring(u and u.score))
    -- an item without computed stats is still skipped, not waited for
    NS.GEAR.I[130] = { "WAIST", 4, 3, 1, 3, 1, 30, 0, 0, 0, 1 }
    Gear.Stats(130)
    STUB.tick(0.3); STUB.fire("ITEM_DATA_LOAD_RESULT", 130, false); STUB.tick(30)
    local s2, failed2 = Gear.Stats(130)
    assert(s2 == nil and failed2 == true, "nothing computed: nil, failed")
end)

---------------------------------------------------------------------------
-- 2. the hit cap limits casters: generic hit has a melee and a spell part
---------------------------------------------------------------------------
check("2 hit cap for casters", function()
    local wm = Gear.Weights("MAGE", Gear.Specs("MAGE")[1].key, "Speedrun", 60)
    assert(not wm.HIT and wm.SHIT and wm.SHIT > 0, "a mage weighs spell hit only")
    local spell = 20 * Gear.RatingPerPoint("SHIT", 60)
    assert(near(Gear.Score({ HIT = 20 }, wm, 60, nil, "MAGE"), spell * wm.SHIT),
        "uncapped: generic hit at the spell rate: " .. Gear.Score({ HIT = 20 }, wm, 60, nil, "MAGE"))
    local capped = Gear.Score({ HIT = 20 }, wm, 60, nil, "MAGE", { HIT = 6, SHIT = 0 })
    assert(near(capped, 0), "no spell room: a mage's generic hit counts nothing: " .. capped)
    capped = Gear.Score({ HIT = 20 }, wm, 60, nil, "MAGE", { HIT = 0, SHIT = 1 })
    assert(near(capped, 1 * wm.SHIT), "one percent of spell room: " .. capped)
    local parts = Gear.ScoreParts({ HIT = 20 }, wm, 60, nil, "MAGE", { HIT = 6, SHIT = 0 })
    local n, over = 0, nil
    for _, p in ipairs(parts) do n = n + p.points; if p.over then over = p end end
    assert(near(n, 0) and over and has(Gear.PartText(over), "über der Grenze: 0"), "the parts show the spell part over the cap")
    -- a melee class: the spell room never limits its hit
    local mw = { AP = 1, HIT = 15 }
    local melee = 20 * Gear.RatingPerPoint("HIT", 60)
    assert(near(Gear.Score({ HIT = 20 }, mw, 60, nil, "WARRIOR", { HIT = 6, SHIT = 0 }), melee * 15), "melee room only")
    assert(near(Gear.Score({ HIT = 20 }, mw, 60, nil, "WARRIOR", { HIT = 0.5, SHIT = 6 }), 0.5 * 15), "melee room 0,5 %")
    -- both weights: each part under its own room
    local hw = { AP = 1, HIT = 15, SHIT = 10 }
    assert(near(Gear.Score({ HIT = 20 }, hw, 60, nil, "PALADIN", { HIT = 0.5, SHIT = 0 }), 0.5 * 15), "hybrid: melee part only")
    assert(near(Gear.Score({ HIT = 20 }, hw, 60, nil, "PALADIN"), melee * 15 + spell * 10), "hybrid uncapped")
end)

---------------------------------------------------------------------------
-- 3. the comparison counts the random suffix the ranking chose
---------------------------------------------------------------------------
check("3 compare with the chosen suffix", function()
    fixture()
    local o = NS.BisOpts()
    local T = NS.BisTargets()
    assert(T.FEET[1].id == 107 and T.FEET[1].suffix == -72 and near(T.FEET[1].score, 32), "boots with their best suffix first")
    assert(T.FEET[2].id == 108 and near(T.FEET[2].score, 24))
    local cmp = NS.BisCompare(T.FEET[1], T.FEET[2], o, { "Option 1", "Option 2" })
    assert(cmp and near(cmp.diff, 8) and cmp.text == "Option 1 liegt 8 vorn, vor allem durch Stärke.", cmp and cmp.text)
    assert(cmp.lines[1] == "+4 Stärke (+8)", cmp.lines[1])
    -- ids still compare base stats
    cmp = NS.BisCompare(107, 108, o, { "Option 1", "Option 2" })
    assert(near(cmp.diff, -4), "ids: base stats")
    -- the page's hover says the same
    STUB.instance = { name = "Elwynn", type = "none", id = 0 }
    NS.ShowGear("goals", "FEET")
    local f = NS.GearPageFrame()
    local joined = plain(table.concat(f.goals.explainHit.lines or {}, "\n"))
    assert(has(joined, "Option 1 liegt 8 vorn"), joined)
end)

---------------------------------------------------------------------------
-- 4. the set bonus sits on the set's pieces: ranking, gain and comparison agree
---------------------------------------------------------------------------
check("4 set bonus on the pieces", function()
    fixture()
    local o = NS.BisOpts()
    -- head 101 = 60 against set head 102 = 52 (loss 8); legs 103 = 80 against 104 = 74 (loss 6);
    -- bonus 20 at two pieces: net 6, each piece its loss plus half the net
    local res = Gear.Best(o)
    local head, legs = res.HEAD[1], res.LEGS[1]
    assert(head[1] == 102 and legs[1] == 104, "the set takes head and legs")
    assert(near(head.setb, 11) and near(legs.setb, 9), "the shares: " .. tostring(head.setb) .. " " .. tostring(legs.setb))
    assert(near(head[2], 63) and near(legs[2], 83), "scores with the share: " .. head[2] .. " " .. legs[2])
    assert(head[2] > res.HEAD[2][2] and legs[2] > res.LEGS[2][2], "a set piece scores above the single it displaced")
    local T = NS.BisTargets()
    assert(near(T.HEAD[1].score, 63) and near(T.HEAD[1].setb, 11), "targets carry the share")
    assert(near(T.HEAD[1].gain, 63), "the gain counts the share (nothing worn): " .. tostring(T.HEAD[1].gain))
    local cmp = NS.BisCompare(T.HEAD[1], T.HEAD[2], o, { "Option 1", "Option 2" })
    assert(cmp and near(cmp.diff, 3) and has(cmp.text, "Option 1 liegt 3 vorn"), cmp and cmp.text)
    local joined = table.concat(cmp.lines, "\n")
    assert(has(joined, "Setbonus (+11)"), joined)
    -- without the set plan nothing carries a share
    o.sets = false
    res = Gear.Best(o)
    assert(res.HEAD[1][1] == 101 and not res.HEAD[1].setb and near(res.HEAD[1][2], 60))
end)

---------------------------------------------------------------------------
-- 5. parsed random suffixes are kept per item
---------------------------------------------------------------------------
check("5 suffix cache", function()
    fixture()
    local a = Gear.SuffixStats(107)
    assert(a and a[-72] and a[-72].STR == 16)
    assert(Gear.SuffixStats(107) == a, "the second call answers from the cache")
    -- the own collector notes a new suffix: the item is read again
    C_Item.GetItemStats = function() return { ITEM_MOD_STRENGTH_SHORT = 30 } end
    NS.NoteSuffix(107, "item:107:0:0:0:0:0:-90:0")
    local b = Gear.SuffixStats(107)
    assert(b ~= a and b[-90] and b[-90].STR == 30, "the noted suffix counts")
    -- new build data: read again
    NS.BIS = { SC = NS.BIS.SC, SET = NS.BIS.SET, EF = NS.BIS.EF, RP = { [107] = { [-71] = "STRENGTH=40" } } }
    local c = Gear.SuffixStats(107)
    assert(c ~= b and c[-71].STR == 40, "a new ns.BIS")
    -- a replaced own table: read again
    AmisiaDB.scan.suffix = { [108] = { [-80] = "STRENGTH=20" } }
    assert(Gear.SuffixStats(108) and Gear.SuffixStats(108)[-80].STR == 20)
    -- the guard: a second Best parses no suffix again
    local ids = {}
    for id in pairs(REAL_GEAR.I) do ids[#ids + 1] = id end
    table.sort(ids)
    NS.GEAR, NS.GEAR_WEIGHTS, NS.BIS = REAL_GEAR, REAL_W, REAL_BIS
    Gear._reset()
    AmisiaDB.scan.suffix = {}
    for i = 1, math.min(1500, #ids) do
        local t = {}
        for sfx = 1, 12 do t[sfx] = ("STRENGTH=%d;STAMINA=%d;AGILITY=%d"):format(sfx, sfx + 1, 12 - sfx) end
        AmisiaDB.scan.suffix[ids[i]] = t
    end
    STUB.class, STUB.faction, STUB.level = "WARRIOR", "Alliance", 40
    NS.BisFor("WARRIOR", "dps", 40, {})
    local gm, calls = string.gmatch, 0
    local sc, scores = Gear.Score, 0
    string.gmatch = function(...) calls = calls + 1; return gm(...) end
    Gear.Score = function(...) scores = scores + 1; return sc(...) end
    local t0 = os.clock()
    NS.BisFor("WARRIOR", "dps", 40, {})
    local ms = (os.clock() - t0) * 1000
    string.gmatch, Gear.Score = gm, sc
    assert(calls < 50, "the second planner run parsed " .. calls .. " texts")
    assert(scores < 500, "the second planner run scored " .. scores .. " stat tables again")
    assert(ms < 60, ("the second planner run took %.0f ms"):format(ms))
    AmisiaDB.scan.suffix = nil
end)

---------------------------------------------------------------------------
-- 6. the drop base stock: an archived trash NPC is no boss
---------------------------------------------------------------------------
check("6 bosses from the base stock", function()
    NS.BIS = { O = { [5001] = { k = 1, it = { [2000] = 1 } }, [5002] = { k = 6, it = {} }, [5003] = { k = 1, it = {} } },
        DG = { { key = "x", kind = "party", name = "X", bosses = { 5003, 5004 } } }, OT = 3, OI = {} }
    assert(NS.DropsIsBoss, "the boss test is reachable")
    assert(not NS.DropsIsBoss(5001), "trash archived once is no boss")
    assert(NS.DropsIsBoss(5002), "an NPC with enough archived kills")
    assert(NS.DropsIsBoss(5003) and NS.DropsIsBoss(5004), "the dungeon facts' bosses")
    assert(not NS.DropsIsBoss(nil) and not NS.DropsIsBoss(9999))
end)

if #failures > 0 then error(table.concat(failures, " || "), 0) end
