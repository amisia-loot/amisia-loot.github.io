-- The profession route after the F-137 review, on a small hand-made data set (not real data): one
-- cost measure in copper with an estimate for materials without a vendor price (sell price times
-- EST_FACTOR, at least EST_MIN, own crafts by their reagents) and a penalty per craft, so a cheap
-- vendor recipe going green loses against an orange one with farmed cloth; no cooldown recipe, no
-- specialisation recipe, no recipe without a source where the trainer's list is known (but in a
-- skill line without one); learn ranks never before yellow; a level cap ends the route, poisons have
-- no trainer steps, a rank above the top is the top; the intermediate's recipe bought too; shared
-- reagents keep their price for the other faction (no place), recipe items do not; the ticks stay
-- across the switch.
local R, Pr = NS.ProfRoute, NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
STUB.faction = "Alliance"
local none = function() return false end
C_Spell = { GetSpellName = function(id) return "Rezept " .. id end, GetSpellDescription = function() return "" end }
NS.PROFESSIONS = {
    built = "2026-11-06", client = "1.60.1.1", source = "abc",
    P = { { 197, "tailoring" }, { 185, "cooking" }, { 129, "firstaid" }, { 40, "poisons" }, { 186, "mining" } },
    R = {
        [197] = {
            "5001:6001:1:1:10:100:A",     -- green for long: 1 thread (vendor 10c)
            "5002:6002:1:1:60:80:A",      -- orange to 60: 1 linen (no vendor, sells for 10c: 40c)
            "5003:6003:1:1:1:300:A",      -- a cooldown recipe, known and free: never a step
            "5004:6004:1:1:1:300:S",      -- a specialisation's recipe: never planned unless known
            "5005:6005:1:1:1:300:",       -- no source where the trainer's list is known: never planned
            "5006:6006:1:1:150:200:T2",   -- a trainer recipe of tier 2: learnable from yellow (150)
            "5007:6007:1:1:210:260:T3",   -- needs the intermediate 6008 ...
            "5008:6008:1:1:210:260:I7008", -- ... made by a vendor recipe (Alliance vendor)
            "5009:6009:1:1:90:130:T2",    -- a cheap trainer recipe while yellow
        },
        [185] = { "5101:6101:1:1:30:70:", "5102:6102:1:1:60:100:A" },   -- no trainer list: no source = trainer
        [129] = { "5201:6201:1:1:30:60:A", "5202:6202:1:1:80:150:T0" }, -- first aid: Wool Bandage learnable at 80
        [40] = { "5301:6301:1:1:100:200:", "5302:6302:1:1:200:300:" },
        [186] = { "5401:6401:1:1:1:50:" },
    },
    I = { [7008] = "5008:0:0:0:V90001" },
    G = { [5001] = "2320:1", [5002] = "2589:1", [5003] = "2320:1", [5004] = "2320:1", [5005] = "2320:1",
        [5006] = "2589:2", [5007] = "6008:1,2320:1", [5008] = "2589:1", [5009] = "2320:2", [5101] = "8001:1",
        [5102] = "8001:2", [5201] = "2589:1", [5202] = "2592:1", [5301] = "8101:1", [5302] = "8101:2", [5401] = "8201:1" },
    N = { [90001] = "Allianzhändler|1429:4000:4000|A", [90002] = "Hordehändler|1411:5000:5000|H" },
    Q = {},
    V = { [2320] = "10:90001", [7008] = "2000:90001", [8101] = "15:90002", [8001] = "8:", [9100] = "500:90002" },
    S = { [2589] = 10, [2592] = 33, [8201] = 1 },
    CD = { [5003] = 1 },
}
NS.Prof._reset()
R._reset()
local function recipeAt(route, rank)
    for _, s in ipairs(route.steps) do
        if s.kind == "recipe" and s.from <= rank and rank < s.to then return s end
    end
end
local function steps(route, kind)
    local out = {}
    for _, s in ipairs(route.steps) do if s.kind == kind then out[#out + 1] = s end end
    return out
end
local function covers(route)
    local at = route.start
    for _, s in ipairs(route.steps) do
        if s.kind == "recipe" or s.kind == "gap" then
            assert(s.from == at, ("step %d-%d starts at %d"):format(s.from, s.to, at))
            at = s.to
        end
    end
    assert(at == route.top, ("the steps end at %d, the top is %d"):format(at, route.top))
end

-- prices: a shared reagent of the other faction's vendor keeps its price (no vendor to go to), an
-- empty list too; a recipe item of the other faction's vendor has none
local p, v = R.Price(8101)
assert(p == 15 and #v == 0, "a Horde vendor's reagent: priced, no vendor for the Alliance")
assert(R.Price(8001) == 8, "an empty vendor list: priced")
assert(R.RecipePrice(9100) == nil and R.Price(9100) == 500, "a recipe item of the Horde vendor: none for the Alliance")
assert(R.RecipePrice(7008) == 2000, "the own faction's recipe item")
assert(R.Source(8101, 40) == "vendorx" and R.Source(2320, 197) == "vendor", "no place: Händler (Ort unbekannt)")

-- the worth: vendor price, sell price times the factor (at least the floor), own crafts, nothing
assert(R.Worth(2320, 197) == 10, "a vendor price")
assert(R.Worth(2589, 197) == 10 * R.EST_FACTOR, "linen: its sell price times the factor")
assert(R.Worth(8201, 186) == R.EST_MIN, "a sell price of 1 copper: the floor")
assert(R.Worth(6008, 197) == 10 * R.EST_FACTOR, "what the profession makes: its reagents")
assert(R.Worth(424242, 197) == R.EST_NONE, "no price at all")

-- the cost measure: the cheap green recipe (vendor thread) while it is cheaper per point, the orange
-- one with estimated linen once the green one's chance falls
local route = R.Compute(197, { known = none })
covers(route)
assert(recipeAt(route, 40).recipe.spell == 5001, "40: thread, (10 + 30) / 0.67 beats (40 + 30) / 1")
assert(recipeAt(route, 55).recipe.spell == 5002, "55: the orange linen recipe beats the half-green thread one")
local s55 = recipeAt(route, 55)
assert(s55.cost == 0 and s55.unpriced > 0 and s55.worth > 0, "linen: weighed by the estimate, never in the cost")
-- green close to grey is no step: a gap says why
local gapLow
for _, s in ipairs(steps(route, "gap")) do if s.why == "low" then gapLow = s end end
assert(gapLow, "only recipes that hardly give points: a gap")
-- never the cooldown, the specialisation or the sourceless recipe, even known (the cooldown one)
local known5003 = R.Compute(197, { known = function(r) return r.spell == 5003 end })
for _, rt in ipairs({ route, known5003 }) do
    for _, s in ipairs(steps(rt, "recipe")) do
        assert(s.recipe.spell ~= 5003 and s.recipe.spell ~= 5004 and s.recipe.spell ~= 5005, "never " .. s.recipe.spell)
    end
end
local known5004 = R.Compute(197, { known = function(r) return r.spell == 5004 end })
assert(recipeAt(known5004, 100).recipe.spell == 5004, "a known specialisation recipe is used")
assert(Pr.PresumedTrainer(Pr.Recipe(5101)) and not Pr.PresumedTrainer(Pr.Recipe(5005)),
    "no source: a trainer recipe only where the data has no trainer list")
local cook = R.Compute(185, { known = none })
assert(recipeAt(cook, 35) and recipeAt(cook, 35).recipe.spell == 5101, "cooking: the sourceless recipe is the trainer's")

-- learn ranks: never before yellow, not below the tier's floor; the page's colour agrees
assert(Pr.LearnRank(Pr.Recipe(5202)) == 80, "first aid: Wool Bandage from 80")
assert(Pr.LearnRank(Pr.Recipe(5006)) == 150 and Pr.LearnRank(Pr.Recipe(5001)) == 1)
assert(Pr.Difficulty(Pr.Recipe(5202), 60, false) == "red" and Pr.Difficulty(Pr.Recipe(5202), 80, false) == "yellow",
    "unknown: red before the learn rank")
local fa = R.Compute(129, { known = none })
for _, s in ipairs(steps(fa, "recipe")) do
    if s.recipe.spell == 5202 then assert(s.from >= 80 and s.colorFrom ~= "red", "Wool Bandage not before 80") end
end

-- an own limit that is no trainer limit: the level's; the route ends there, no trainer step
local lc = R.Compute(197, { rank = 90, max = 100, known = none })
covers(lc)
assert(lc.levelCap == 100 and lc.top == 100 and #steps(lc, "trainer") == 0, "Höchstwert für deine Stufe")
local tc = R.Compute(197, { rank = 140, max = 150, known = none })
assert(not tc.levelCap and tc.top == 225 and #steps(tc, "trainer") > 0, "a trainer limit goes on with the trainer (tiers up to T3 here)")
-- poisons: no trainer tiers at all
local po = R.Compute(40, { known = none })
covers(po)
assert(#steps(po, "trainer") == 0 and po.top == 300, "poisons: no trainer steps")
local po2 = R.Compute(40, { rank = 120, max = 150, known = none })
assert(#steps(po2, "trainer") == 0 and po2.top == 150 and po2.levelCap == 150, "poisons: the level's maximum")
-- a rank above every known limit: the top is the rank, nothing to plan, a clear note
local ot = R.Compute(197, { rank = 310, known = none })
assert(ot.top == 310 and ot.overTop and #steps(ot, "recipe") == 0 and #steps(ot, "gap") == 0, "no 310 to 300")

-- the intermediate's vendor recipe: bought too, with its price
local iv = R.Compute(197, { rank = 210, max = 300, vendor = true, known = none })
covers(iv)
local buyPre
for i, s in ipairs(iv.steps) do
    if s.kind == "buy" and s.item == 7008 then
        buyPre = s
        local nxt = iv.steps[i + 1]
        assert(nxt.kind == "recipe" and nxt.recipe.spell == 5007 and nxt.pre and nxt.pre.spell == 5008 and not nxt.preKnown,
            "buy the intermediate's recipe, then craft both")
    end
end
assert(buyPre and buyPre.price == 2000 and iv.total >= 2000, "its price in the total")

-- the page: the notes for a level cap and above the top; the gap's text
local book = { rank = 90, max = 100 }
GetProfessions = function() return 1 end
GetProfessionInfo = function() return "Schneiderei", 136249, book.rank, book.max, 2, 0, 197 end
AmisiaDB.settings.professions = { mode = "route" }
NS.ShowProfessions("schneiderei")
local f = NS.PageFrame("professions")
assert(has(f.routeNote:GetText(), "Höchstwert für deine Stufe: 100"), f.routeNote:GetText())
book.rank, book.max = 310, 0
NS.Refresh()
assert(has(f.routeNote:GetText(), "Rang 310 liegt über dem bekannten Höchstrang"), f.routeNote:GetText())
-- the ticks stay when the switch changes: the steps behind the rank are done either way
book.rank, book.max = 1, 75
R._reset()
local g1 = R.Get(197, false)
book.rank = recipeAt(g1, 1).to
local g2 = R.Get(197, true)
assert(g2.steps[1].done, "done steps kept across the switch")
