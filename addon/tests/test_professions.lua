-- Professions (Professions.lua): the data read, the difficulty colours of the client's recipe list,
-- the own professions first, what the character knows from its open profession window (not from a
-- linked or guild one), reagents from the data or the client, sources with Merchant's Favor of the
-- own faction and the collector's own and heard vendors, the list filters, camp objects and the
-- Merchant's Favor overview.
local Pr = NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
Pr._reset()
assert(Pr.Available(), "the data is there")

-- reading
local bs = Pr.Recipes(164)
assert(#bs == 5 and bs[1].spell == 2663 and bs[1].green == 40 and bs[1].src[1] == "A", "parsed in the data's order")
assert(bs[2].items[1] == 3609 and #bs[2].src == 0 and bs[2].learn == 10, "a recipe item is no source token")
assert(Pr.Recipe(1234001).skill == 171 and Pr.Recipe(1234001).count == 1 and Pr.Recipe(2330).count == 3)
assert(Pr.RecipeItem(276928).faction == 2758 and Pr.RecipeItem(276928).standing == 5 and Pr.RecipeItem(1) == nil)
local n = Pr.Npc(80100)
assert(n.name == "Suppla Smith" and n.point.map == 1429 and math.abs(n.point.x - 0.125) < 1e-9 and n.zone == 1429)
assert(Pr.Npc(80400).point == nil and Pr.Npc(80400).zone == 1429)
assert(Pr.Name(164) == "Schmiedekunst" and Pr.Name(185) == "Kochkunst" and Pr.RecipeName(bs[5]) == "Rezept 9999")

-- the difficulty of the client's list: orange below yellow, yellow below green, green below grey
local cb = bs[1]
assert(Pr.Difficulty(cb, 10) == "orange" and Pr.Difficulty(cb, 20) == "yellow" and Pr.Difficulty(cb, 39) == "yellow")
assert(Pr.Difficulty(cb, 40) == "green" and Pr.Difficulty(cb, 59) == "green" and Pr.Difficulty(cb, 60) == "grey")
local cloudy = Pr.Recipe(1301421)
assert(Pr.Difficulty(cloudy, 30) == "red" and Pr.Difficulty(cloudy, 30, true) == "orange", "red only while not known")
assert(Pr.Difficulty(cb, nil) == "none" and not Pr.Learnable(cloudy, 59) and Pr.Learnable(cloudy, 60))

-- the own professions: the book's order first, the rest after
GetProfessions = function() return 1, nil, nil, nil, 3 end
GetProfessionInfo = function(i)
    if i == 1 then return "Schmiedekunst", 136241, 45, 150, 3, 0, 164 end
    if i == 3 then return "Kochkunst", 133971, 10, 75, 2, 0, 185 end
end
local own = Pr.Own()
assert(#own == 2 and own[1].skill == 164 and own[1].rank == 45 and own[2].skill == 185, "the book")
local order = Pr.Ordered()
assert(order[1] == 164 and order[2] == 185 and order[3] == 171, table.concat(order, ","))
assert(Pr.Rank(164) == 45 and Pr.Rank(171) == nil)

-- known: nothing to say before the window was read
assert(Pr.Known(2663, 164) == nil and not Pr.HasSnapshot(164))
local T = { linked = false, recipes = { 2663, 3321, 1252229 }, learned = { [2663] = true, [1252229] = true }, base = 164 }
C_TradeSkillUI = {
    IsTradeSkillLinked = function() return T.linked end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
    GetBaseProfessionInfo = function() return { professionID = T.base, skillLevel = 45, maxSkillLevel = 150 } end,
    GetAllRecipeIDs = function() return T.recipes end,
    GetRecipeInfo = function(id) return { recipeID = id, learned = T.learned[id] == true } end,
    GetRecipeSchematic = function(id)
        if id ~= 3321 then return nil end
        return { recipeID = id, reagentSlotSchematics = {
            { reagents = { { itemID = 2840 } }, quantityRequired = 4, required = true },
            { reagents = { { itemID = 2880 } }, quantityRequired = 1, required = true },
            { reagents = { { itemID = 9999 } }, quantityRequired = 1, required = false },
        } }
    end,
}
STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
assert(Pr.Known(2663, 164) == true and Pr.Known(3321, 164) == false and Pr.HasSnapshot(164), "read from the window")
local saved = AmisiaDB.prof.chars[NS.UnitFullName("player")][164]
assert(saved.rank == 45 and saved.max == 150 and saved.known[1252229], "kept per character")
-- a linked window (another player's) changes nothing
T.linked, T.learned = true, {}
STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
assert(Pr.Known(2663, 164) == true, "a linked window is not the own")
T.linked = false
-- a recipe learned now
STUB.fire("NEW_RECIPE_LEARNED", 3321)
assert(Pr.Known(3321, 164) == true, "learned")
-- a list without data yet (all unlearned while loading) keeps the state
T.recipes = { 2663, 3321 }
STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
assert(Pr.Known(2663, 164) == true, "an empty answer does not wipe the state")
T.learned = { [2663] = true, [1252229] = true }
T.recipes = { 2663, 3321, 1252229 }
STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
assert(Pr.Known(3321, 164) == false, "the window's word counts again")

-- reagents: the data's table, else the client's schematic (the optional slot left out), else nothing
local r1, from1 = Pr.Reagents(2663)
assert(from1 == "data" and r1[1][1] == 2840 and r1[1][2] == 2)
local r2, from2 = Pr.Reagents(3321)
assert(from2 == "client" and #r2 == 2 and r2[1][2] == 4 and r2[2][1] == 2880, "from the client")
assert(Pr.Reagents(1252229) == nil, "nobody knows")

-- sources: the vendor of the data with its place
local src = Pr.Sources(Pr.Recipe(3321))
assert(#src == 1 and src[1].kind == "V" and src[1].point.map == 1429, "the vendor")
assert(has(src[1].text, "Händler: Suppla Smith, Wald von Elwynn 13, 33"), src[1].text)
-- Merchant's Favor of the own faction only, then the drop
src = Pr.Sources(Pr.Recipe(1234001))
assert(#src == 2 and src[1].kind == "F" and has(src[1].text, "Händlergunst: 45 Gunst, Neutral (Allianz)"), src[1].text)
assert(src[2].kind == "D" and has(src[2].text, "Drop: Vale Ooze, Wald von Elwynn"), src[2].text)
assert(Pr.Sources(Pr.Recipe(1252229))[1].text == "Lehrer (Lehrling)")
assert(Pr.Sources(Pr.Recipe(9999))[1].kind == "?", "no source known")
-- what the collector saw: an own vendor and a heard drop, each once beside the data's
local TODAY = NS.DropsToday()
assert(NS.CollectPut("s", 80500, ("%d;0;1429:4000:5000;3609:500::;Ada Amboss"):format(TODAY), "own"))
assert(NS.CollectPut("s", 80100, ("%d;0;1429:1250:3300;3609:450::;Suppla Smith"):format(TODAY), "own"))
assert(NS.CollectPut("w", 80600, ("%d;0;n;1429:2000:2000;0;276928:1;Golem Junior"):format(TODAY), "heard"))
src = Pr.Sources(Pr.Recipe(3321))
assert(#src == 2 and src[2].observed and src[2].own, "the own vendor joins; the data's vendor stays once")
assert(has(src[2].text, "Händler: Ada Amboss, Wald von Elwynn 40, 50, 5s 0c (selbst gesehen)"), src[2].text)
assert(src[2].point and src[2].point.map == 1429, "an own place is a waypoint")
src = Pr.Sources(cloudy)
assert(#src == 2 and has(src[2].text, "Drop: Golem Junior") and has(src[2].text, "(von der Gilde)"), src[2] and src[2].text)
assert(src[2].point == nil, "a place only heard from the guild is no waypoint")

-- the list: search, known, learnable, source
local function spells(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.recipe.spell end
    return table.concat(out, ",")
end
assert(spells(Pr.List(164, { search = "KUPFER" })) == "2663,3321,1252229", spells(Pr.List(164, { search = "KUPFER" })))
assert(spells(Pr.List(164, { known = "known" })) == "2663,1252229")
assert(spells(Pr.List(164, { known = "unknown" })) == "3321,1301421,9999")
assert(spells(Pr.List(164, { learnable = true })) == "3321,9999", "unknown and the rank allows it")
assert(spells(Pr.List(164, { source = "V" })) == "3321")
assert(spells(Pr.List(164, { source = "D" })) == "1301421", "the collector's drop counts too")
assert(spells(Pr.List(164, { source = "T" })) == "2663,1252229,9999", "with the profession, the trainer, or nothing known")
assert(spells(Pr.List(171, { source = "F" })) == "1234001")
local first = Pr.List(164)[1]
assert(first.name == "Kupferarmschienen" and first.known == true and first.color == "green", first.color)
-- an item name searches too
STUB.item(276992, "Wolkenkettenhemd", 3)
assert(spells(Pr.List(164, { search = "wolkenk" })) == "1301421")

-- camp objects
local camp = Pr.Camp()
assert(#camp == 3 and camp[1].slots == 3 and camp[3].over == 279944 and camp[3].recipe == 1263041)

-- Merchant's Favor: the own faction's vendors and recipes, the currency, the writs
C_CurrencyInfo = { GetCurrencyInfo = function(id) if id == 3402 then return { name = "Händlergunst", quantity = 120 } end end }
local fav = Pr.Favor()
assert(fav.amount == 120 and fav.name == "Händlergunst" and #fav.vendors == 1 and fav.vendors[1] == 80201)
assert(#fav.recipes == 1 and fav.recipes[1].price == 45 and fav.recipes[1].faction == "A")
assert(fav.writs[164] == 1 and fav.cert[164] == 271622 and Pr.HasWrit(Pr.Recipe(3321)) and not Pr.HasWrit(cb))
STUB.faction = "Horde"
fav = Pr.Favor()
assert(fav.vendors[1] == 80200 and fav.recipes[1].price == 50, "the other faction's")
STUB.faction = "Alliance"
