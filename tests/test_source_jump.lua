-- A jump from a source symbol (F-157): D.SourceKey maps a gear source to its dungeon or raid,
-- ns.ShowDungeonItem opens its Übersicht at the boss that drops the item with its loot row marked
-- (until another boss or instance), a raid on the page Raids; Pr.RecipeForItem finds the recipe of
-- a crafted item.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local T = NS.Theme
local BV = T.DBOSS

NS.BIS = nil
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
NS.GEAR = { built = "test-boss-view", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },              -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },                        -- 2
    { "D", "Hall of Thanes", "Plunder", nil },                         -- 3
    { "D", "Ruins of Lordaeron", "The Baron", nil },                   -- 4
    { "D", "Ruins of Lordaeron", "Witherfang", nil },                  -- 5
} }
local function gear(id, name, loc, strength, level, sources, quality)
    STUB.item(id, name, quality or 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    if sources then
        local row = { loc, 4, 2, level, quality or 3, 1, 20, 0, 0, 0 }
        for _, n in ipairs(sources) do row[#row + 1] = n end
        NS.GEAR.I[id] = row
    end
end
-- Faldrim and Plunder have an upgrade; Magmatus only eight wished helms worse than the worn one
-- (listed, no upgrade), in three qualities; the Baron an upgrade, Witherfang a wished helm only
gear(501, "Ambosshelm", "HEAD", 30, 16, { 1 })
for i = 0, 7 do gear(520 + i, "Magmahelm " .. i, "HEAD", 1 + i, 16, { 2 }, 2 + (i % 3)) end
gear(504, "Plünderstiefel", "FEET", 30, 16, { 3 })
gear(509, "Baronsschultern", "SHOULDER", 10, 17, { 4 })
gear(512, "Fanghelm", "HEAD", 2, 16, { 5 })
gear(510, "Alter Helm", "HEAD", 10, 10)
STUB.worn[1] = STUB.items[510].link
NS.Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
for i = 0, 7 do assert(NS.WishAdd(520 + i)) end
assert(NS.WishAdd(512))

-- the key of a source record: by its name (the facts' "Hall of Thanes" is "thanes")
local Dg = NS.Dungeons
assert(Dg.SourceKey(NS.GEAR.S[2]) == "thanes", "D record -> thanes: " .. tostring(Dg.SourceKey(NS.GEAR.S[2])))
assert(Dg.SourceKey(NS.GEAR.S[4]) == "lordaeron", "D record -> lordaeron")
assert(Dg.SourceKey({ "D", "Nirgendwo", "Niemand" }) == nil, "unknown place")
assert(Dg.SourceKey({ "C", "tailoring", 100 }) == nil and Dg.SourceKey(nil) == nil, "not a dungeon")

local function chosen(P)
    for _, h in ipairs(P.bossView.list.items) do if h.on then return h end end
end
local function marked(P)
    local out = {}
    for _, r in ipairs(P.bossView.loot.rows) do
        if r:IsShown() and r.sel:IsShown() then out[#out + 1] = r.item.id end
    end
    return table.concat(out, ",")
end

-- the page shows the quests part: an item jump opens the Übersicht at the boss that drops it
NS.Set("bis.dpart", "quests")
NS.ShowDungeon("lordaeron")
assert(NS.ShowDungeonItem("thanes", 527), "the window shows")
local D = NS.PageFrame("dungeons")
assert(NS.CurrentPage() == "dungeons" and D.chosen == "thanes", "the thanes' detail")
assert(D.bossView:IsShown(), "the part Übersicht")
assert(chosen(D).text == "Magmatus", "the boss that drops it, not the first with an upgrade: " .. tostring(chosen(D) and chosen(D).text))
assert(marked(D) == "527", "only its loot row marked: " .. marked(D))
-- a refresh keeps it
NS.Refresh()
assert(chosen(D).text == "Magmatus" and marked(D) == "527", "kept across a refresh")
-- another boss ends the mark
for _, r in ipairs(D.bossView.list.rows) do
    if r:IsShown() and r.item and r.item.text == "Faldrim Anvilmar" then r:Click("LeftButton") end
end
assert(chosen(D).text == "Faldrim Anvilmar" and marked(D) == "", "a chosen boss ends the mark")
-- the next jump to an item of the first boss
assert(NS.ShowDungeonItem("thanes", 504))
assert(chosen(D).text == "Plunder" and marked(D) == "504", "Plunder's boots")
-- another dungeon ends it too
NS.ShowDungeon("lordaeron")
assert(marked(D) == "", "another dungeon: no mark")
-- an item no boss drops: the dungeon with its usual boss
assert(NS.ShowDungeonItem("thanes", 999999))
assert(D.chosen == "thanes" and chosen(D) ~= nil and marked(D) == "", "unknown item: the dungeon only")
assert(not NS.ShowDungeonItem(nil, 504), "no key")

-- a raid opens on the page Raids at its part Übersicht
NS.DropsLearnNames({ [10184] = "Onyxia" }, { [249] = { "raid", "Onyxias Hort" } })
NS.Set("bis.rpart", "map")
NS.ShowDungeonItem("onyxia", 123)
local P = NS.PageFrame("raidjournal")
assert(NS.CurrentPage() == "raidjournal" and P.chosen == "onyxia" and NS.Get("bis.rpart") == "bosses", "the raid's Übersicht")

-- the recipe of a crafted item
local Pr = NS.Prof
local skill = Pr.Skills()[1]
local r1 = skill and Pr.Recipes(skill)[1]
assert(r1 and r1.item > 0, "the test data has recipes")
do
    local r, s = Pr.RecipeForItem(r1.item, Pr.Key(skill))
    assert(r and r.item == r1.item and s == skill, "the recipe that makes it")
    assert(Pr.RecipeForItem(r1.item, "nichts") == nil, "another profession: none")
end
assert(Pr.RecipeForItem(nil) == nil and Pr.RecipeForItem(1) == nil, "no recipe")
print("source jump: key, boss chosen, row marked, refresh, other boss, other dungeon, unknown item, raid, recipe")
