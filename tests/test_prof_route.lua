-- The profession route (Gear/ProfRoute.lua, F-137) on the route fixture: every rank in exactly one
-- step, trainer steps at the limits, the cheaper recipe, the tie rules, the intermediate (bolt), the
-- switch "auch Händler" with its recipe-buy step (never the other faction's or a drop recipe), the
-- current step moving with the rank and the done ones kept, the shopping list with the own bags,
-- the bank and the alts (AmisiaDB.prof.bags, checked on load), nothing in combat; and the page.
local R, Pr = NS.ProfRoute, NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/route_fixture.lua")
local none = function() return false end

-- every rank from start to top - 1 in exactly one recipe or gap step, in order
local function covers(route)
    local at = route.start
    for _, s in ipairs(route.steps) do
        if s.kind == "recipe" or s.kind == "gap" then
            assert(s.from == at, ("step %d-%d starts at %d"):format(s.from, s.to, at))
            assert(s.to > s.from, "a step covers a rank at least")
            at = s.to
        end
    end
    assert(at == route.top, ("the steps end at %d, the top is %d"):format(at, route.top))
end
local function steps(route, kind)
    local out = {}
    for _, s in ipairs(route.steps) do if s.kind == kind then out[#out + 1] = s end end
    return out
end
local function recipeAt(route, rank)
    for _, s in ipairs(route.steps) do
        if s.kind == "recipe" and s.from <= rank and rank < s.to then return s end
    end
end

assert(R.Has(197) and not R.Has(182) and not R.Has(186), "tailoring has a route, herbalism and mining not")
assert(R.Chance({ yellow = 20, grey = 60 }, 10) == 1 and R.Chance({ yellow = 20, grey = 60 }, 40) == 0.5
    and R.Chance({ yellow = 20, grey = 60 }, 60) == 0, "orange 1, then (grey - rank) / (grey - yellow), grey 0")

-- not learned: a preview from 1 with the apprentice first, trainer steps at 75, 150 and 225
local route = R.Compute(197, { known = none })
covers(route)
assert(not route.learned and route.start == 1 and route.top == 300, "the top from the trainer tiers")
local tr = steps(route, "trainer")
assert(#tr == 4 and tr[1].at == 1 and tr[1].cap == 75 and tr[2].at == 75 and tr[2].cap == 150 and tr[3].at == 150
    and tr[4].at == 225 and tr[4].cap == 300, "trainer steps at the limits")
assert(tr[2].cost == 500 and tr[2].name == "Geselle", "the trainer's cost and tier from T")
-- a trainer visit ends a step: no recipe step reaches over a limit
for _, s in ipairs(steps(route, "recipe")) do
    for _, c in ipairs({ 75, 150, 225 }) do assert(not (s.from < c and s.to > c), "a step over a limit") end
end

-- the intermediate: the shirt with the bolt before it (both give points) beats the bolt alone
local first = recipeAt(route, 1)
assert(first.recipe.spell == 2393 and first.pre and first.pre.spell == 2963, "shirt with the bolt as an earlier step")
assert(first.preCrafts > 0 and first.reagents[2589] and first.reagents[2320] and not first.reagents[2996],
    "the base reagents: linen and thread, not the bolt")
assert(first.crafts < first.points, "the bolt's points count: fewer shirts than points")
-- the cheaper recipe: one linen (3914) beats the shirt (two linen and thread) once it can be learned
local mid = recipeAt(route, 50)
assert(mid.recipe.spell == 3914 and mid.learnCost == 100 and not mid.known, "the cheaper trainer recipe, with its learning cost")
-- the tie: 3914 and 3915 cost the same; the known one wins
local r2 = R.Compute(197, { known = function(r) return r.spell == 3915 end })
assert(recipeAt(r2, 50).recipe.spell == 3915 and recipeAt(r2, 50).learnCost == 0, "a known recipe first")
-- the next tie: 2 thread (3916, one reagent) beats 1 thread and 1 dye (3917, two)
assert(recipeAt(route, 100).recipe.spell == 3916, "fewer distinct reagents")
local r3 = R.Compute(197, { known = function(r) return r.spell == 3917 end })
assert(recipeAt(r3, 100).recipe.spell == 3917, "known before fewer reagents")
-- the cost: vendor prices only, the linen counts as a material without a price
assert(route.unknown and route.total > 0 and mid.unpriced > 0, "linen has no price")

-- trainer only: no vendor recipe, no drop recipe, no Horde vendor's recipe
for _, s in ipairs(steps(route, "recipe")) do
    assert(s.recipe.spell ~= 3923 and s.recipe.spell ~= 3924 and s.recipe.spell ~= 3925, "trainer only: " .. s.recipe.spell)
end
assert(#steps(route, "buy") == 0)
-- also vendors: the vendor recipe with a buy step right before it, its price in the total
local rv = R.Compute(197, { rank = 1, max = 75, vendor = true, known = none })
covers(rv)
local buy = steps(rv, "buy")
assert(#buy == 1 and buy[1].item == 9001 and buy[1].price == 5000 and buy[1].vendors[1].id == 80100, "one recipe to buy")
for i, s in ipairs(rv.steps) do
    if s.kind == "buy" then assert(rv.steps[i + 1].kind == "recipe" and rv.steps[i + 1].recipe.spell == 3923, "buy, then craft") end
    if s.kind == "recipe" then assert(s.recipe.spell ~= 3924 and s.recipe.spell ~= 3925, "never drop or the other faction") end
end
assert(rv.total > route.total - 10, "the recipe's price counts")
-- a known drop recipe is used
local rd = R.Compute(197, { rank = 1, max = 75, known = function(r) return r.spell == 3924 end })
assert(recipeAt(rd, 280) and recipeAt(rd, 280).recipe.spell == 3924 or recipeAt(rd, 1).recipe.spell == 3924, "a known recipe of any source")

-- an own limit above the trainer tiers is one more step and the top
local r4 = R.Compute(197, { rank = 290, max = 300, known = none })
covers(r4)
assert(r4.top == 300 and #steps(r4, "trainer") == 0)
local r5 = R.Compute(197, { rank = 300, max = 350, known = none })
covers(r5)
assert(r5.top == 350, "Forever's ranks past 300")
-- without trainer data (T, L): the classic limits up to the highest tier of the recipes, no costs
local keepT, keepL = NS.PROFESSIONS.T, NS.PROFESSIONS.L
NS.PROFESSIONS.T, NS.PROFESSIONS.L = nil, nil
local r6 = R.Compute(197, { known = none })
covers(r6)
local tr6 = steps(r6, "trainer")
assert(r6.top == 300 and #tr6 == 4 and tr6[2].cap == 150 and tr6[2].cost == nil, "no cost without T")
assert(recipeAt(r6, 50).learnCost == 0, "no learning cost without L")
assert(not R.Compute(197, { rank = 40, known = none }).maxKnown and R.Compute(197, { rank = 40, max = 75, known = none }).maxKnown)
NS.PROFESSIONS.T, NS.PROFESSIONS.L = keepT, keepL
-- no recipe gives points: an honest gap (or one of recipes that hardly give points) up to the top
local g5 = steps(r5, "gap")
assert(#g5 > 0 and g5[#g5].to == 350 and (g5[#g5].why == "none" or g5[#g5].why == "low") or recipeAt(r5, 345),
    "a gap or a recipe")

-- the page's route: the own rank from the book, the steps done kept, the current one moving
local book = { rank = 40, max = 75 }
GetProfessions = function() return 1 end
GetProfessionInfo = function() return "Schneiderei", 136249, book.rank, book.max, 2, 0, 197 end
R._reset()
local g1 = R.Get(197, false)
assert(g1.start == 40 and R.Current(g1) == 1 and not g1.steps[1].done, "from the own rank")
book.rank = 46
local g2 = R.Get(197, false)
assert(g2 ~= g1 and g2.steps[1].done and g2.steps[1].to <= 46, "the step behind the rank is done")
local cur = R.Current(g2)
assert(cur > 1 and not g2.steps[cur].done and g2.steps[cur].from == 46, "the current step moved")
assert(R.Get(197, false) == g2, "no new computation without a change")
-- in combat: the last route, nothing computed
book.rank = 47
STUB.combat = true
local g3, stale = R.Get(197, false)
assert(g3 == g2 and stale == true, "combat keeps the last route")
STUB.combat = false
local g4, stale2 = R.Get(197, false)
assert(g4 ~= g2 and not stale2 and g4.start == 47)

-- the bags: own counts, the bank part kept while the bank is closed, realm, faction and the list of
-- reagents kept; the alts of the same realm and faction
local me = NS.UnitFullName("player")
local realm = "Forever"
GetRealmName = function() return realm end   -- the realm the client names (Forever's names carry none)
STUB.bags[0] = { 2589, 2589, 2589, 2320 }
STUB.bank[2589] = 5
assert(R.SaveBags(), "saved")
local mine = AmisiaDB.prof.bags[me]
assert(mine.items[2589] == 8 and mine.bank[2589] == 5 and mine.items[2320] == 1, "bags and bank")
assert(mine.realm == realm and mine.faction == "A", "realm and faction of the entry")
local listed = {}
for _, item in ipairs(mine.track) do listed[item] = true end
assert(listed[2589] and listed[2320] and listed[2324] and not listed[2447], "the tailoring reagents, not alchemy's")
STUB.bank[2589] = nil   -- the client forgot the bank: the last bank count stays
R.SaveBags()
assert(AmisiaDB.prof.bags[me].items[2589] == 8, "the bank part kept")
-- Forever's names carry no realm, surnames may have a dash: realm and faction come from the entry
AmisiaDB.prof.bags["Twink Grau-Bart"] = { day = 1, realm = realm, faction = "A", items = { [2589] = 30, [2320] = 2 } }
AmisiaDB.prof.bags["Fremd Anderswo"] = { day = 1, realm = "Anderswo", faction = "A", items = { [2589] = 99 } }
AmisiaDB.prof.bags["Horde Twink"] = { day = 1, realm = realm, faction = "H", items = { [2589] = 77 } }
AmisiaDB.prof.bags["Alt Ohnerealm"] = { day = 1, items = { [2589] = 55 } }
assert(R.Twinks(2589) == 30 and R.Twinks(2320) == 2,
    "only the other characters of the same realm and faction; an old entry without realm waits for its next login")
assert(R.Have(2589) == 8, "the bags and the last bank count")
AmisiaDB.prof.bags["Horde Twink"], AmisiaDB.prof.bags["Alt Ohnerealm"], AmisiaDB.prof.bags["Fremd Anderswo"] = nil, nil, nil

-- the shopping list of the open steps
local shop = R.Shopping(g4)
local byItem = {}
for _, e in ipairs(shop) do byItem[e.item] = e end
local linen, thread = byItem[2589], byItem[2320]
assert(linen and linen.need > 30 and linen.have == 8 and linen.twinks == 30 and linen.missing == linen.need - 38 and not linen.enough,
    "have, alts, missing")
assert(linen.kind == "farm" and not linen.price, "linen: farm or auction house")
assert(thread and thread.kind == "vendor" and thread.price == 10, "thread: vendor with its price")
-- enough in the bags: the row is green (enough)
STUB.bags[1] = {}
for i = 1, thread.need do STUB.bags[1][i] = 2320 end
local again = {}
for _, e in ipairs(R.Shopping(g4)) do again[e.item] = e end
assert(again[2320].enough and again[2320].missing == 0, "enough")
assert(R.Source(2770, 197) == "mine" and R.Source(2840, 197) == "smelt", "ore and bars from mining")
assert(R.Source(2996, 197) == "craft" and select(2, R.Source(2996, 197)) == 197, "the bolt: made by the own profession")

-- checked on load: bad entries dropped
AmisiaDB.prof.bags["Bad|cff"] = { day = 1, items = {} }
AmisiaDB.prof.bags["Neg Twink"] = { day = -3, realm = "Bad|realm", faction = "X", track = { 2589, 2589, -1, "x", 2320 },
    items = { [2589] = -1, [0] = 2, [2320] = 1.5, [2324] = 4 }, junk = 1 }
AmisiaDB.prof.bags[5] = { items = {} }
NS.ProfBagsLoaded(AmisiaDB)
local b = AmisiaDB.prof.bags
local neg = b["Neg Twink"]
assert(b["Bad|cff"] == nil and b[5] == nil and neg.day == 0 and neg.junk == nil)
assert(neg.items[2324] == 4 and neg.items[2589] == nil and neg.items[2320] == nil)
assert(neg.realm == nil and neg.faction == nil and #neg.track == 2 and neg.track[1] == 2589 and neg.track[2] == 2320,
    "realm with a code and a wrong faction dropped; the list without doubles and junk")
assert(b["Twink Grau-Bart"].realm == realm and b["Twink Grau-Bart"].faction == "A", "a good entry keeps realm and faction")
AmisiaDB.prof.bags = "x"
NS.ProfBagsLoaded(AmisiaDB)
assert(AmisiaDB.prof.bags == nil, "no table: dropped")
AmisiaDB.prof.bags = { ["Twink Grau-Bart"] = { day = 1, realm = realm, faction = "A", items = { [2589] = 30 } } }

-- the page: the switch, the route view, the current step marked, a click on a step opens the recipe
NS.ShowProfessions("schneiderei")
local f = NS.PageFrame("professions")
assert(f and not f.routeView:IsShown() and f.list:IsShown(), "recipes first")
f.modeRoute:Click()
assert(AmisiaDB.settings.professions.mode == "route" and f.routeView:IsShown() and not f.list:IsShown(), "the route view")
assert(has(f.routeHead:GetText(), "Rang 47 bis 300") and has(f.routeHead:GetText(), "Schritte"), f.routeHead:GetText())
assert(has(f.routeNote:GetText(), "Berufsfenster einmal öffnen") and has(f.routeNote:GetText(), "nach einem Schätzwert"), f.routeNote:GetText())
local rows = f.steps.rows
local curRow
for _, r in ipairs(rows) do if r:IsShown() and r.sel:IsShown() then curRow = r end end
assert(curRow and not curRow.item.done, "the current step is marked")
local doneRow
for _, r in ipairs(rows) do if r:IsShown() and r.item and r.item.done then doneRow = r end end
assert(doneRow and doneRow.tick:IsShown() and doneRow.line2:GetText() == "", "done: ticked and short")
assert(has(curRow.line1:GetText(), "x ") and has(curRow.line2:GetText(), "etwa"), curRow.line1:GetText())
-- the tooltip names the colour ranges and why
local tip, realAdd, realSet = {}, GameTooltip.AddLine, GameTooltip.SetText
GameTooltip.AddLine = function(_, t) tip[#tip + 1] = t end
GameTooltip.SetText = function(_, t) tip[#tip + 1] = t end
curRow:GetScript("OnEnter")(curRow)
GameTooltip.AddLine, GameTooltip.SetText = realAdd, realSet
local tipText = table.concat(tip, "\n")
assert(has(tipText, "orange bis") and has(tipText, "grün bis") and has(tipText, "Gewählt:") and has(tipText, "bei Rang"), tipText)
-- trainer only / also vendors
f.vendorV:Click()
assert(AmisiaDB.settings.professions.routeVendor == true and f.vendorV.on and not f.vendorT.on)
local hasBuy = false
for _, s in ipairs(f.route.steps) do if s.kind == "buy" then hasBuy = true end end
assert(hasBuy, "the vendor recipe with its buy step")
f.vendorT:Click()
assert(AmisiaDB.settings.professions.routeVendor == nil)
-- the shopping list: green when enough, a click on a vendor material sets the waypoint
f.tabShop:Click()
assert(f.shopView:IsShown() and not f.stepsView:IsShown())
local threadRow, linenRow
for _, r in ipairs(f.shop.rows) do
    if r:IsShown() and r.item and r.item.item == 2320 then threadRow = r end
    if r:IsShown() and r.item and r.item.item == 2589 then linenRow = r end
end
assert(threadRow and has(threadRow.name:GetText(), "|cff40bf40") and threadRow.src:GetText() == "Händler", "green, from the vendor")
assert(linenRow and linenRow.twinks:GetText() == "30" and linenRow.src:GetText() == "farmen oder Auktionshaus")
threadRow:Click()
local target = NS.MapTarget and NS.MapTarget()
assert(target and ((target.map == 1429 and math.abs(target.x - 0.125) < 1e-6) or (target.map == 1453 and math.abs(target.x - 0.5) < 1e-6)),
    "a vendor of the thread with a place")
-- a click on a recipe step opens the recipe in the recipe view
f.tabSteps:Click()
for _, r in ipairs(f.steps.rows) do
    if r:IsShown() and r.item and r.item.kind == "recipe" and not r.item.done then
        local spell = r.item.recipe.spell
        r:Click()
        assert(AmisiaDB.settings.professions.mode == nil and f.list:IsShown(), "back to the recipes")
        assert(f.selected and f.selected.recipe.spell == spell, "the recipe chosen")
        break
    end
end
-- camp and favor have no route: the chip is off and greyed
AmisiaDB.settings.professions.mode = "route"
NS.ShowProfessions("lager")
assert(not f.routeView:IsShown() and not f.modeRoute:IsEnabled(), "no route for the camp")
