-- The catalog (F-123; since 2.65.0 the set marks and the search of the page Ausrüstungsplaner, D-80):
-- the item sets by where their pieces come from (raid, dungeon, PvP, crafting, world) with counts, a
-- set opened with its pieces, a piece's click as the own pick; the level sets; the search over every
-- item by name and level range, the best for the own character first.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-catalog", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
    { "D", "Stratholme", "Baron Totenschwur", nil, 329, 2017 },   -- 2
    { "C", "leatherworking", 300 },                                -- 3
} }
STUB.areas[2717], STUB.areas[2017] = "Geschmolzener Kern", "Stratholme"
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, strength, level, sources)
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, 4
    it.stats, it.minLevel = { ITEM_MOD_STRENGTH_SHORT = strength }, level
    NS.GEAR.I[id] = { loc, 4, 4, level, 4, 1, 60, 0, 0, 0 }
    for _, n in ipairs(sources or {}) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
end
gear(401, "Helm des Kerns", "HEAD", 40, 60, { 1 })
gear(402, "Helm der Pest", "HEAD", 30, 58, { 2 })
gear(403, "Brust der Pest", "CHEST", 35, 58, { 2 })
gear(404, "Teufelssaurier-Stulpen", "HAND", 20, 53, { 3 })
gear(405, "Teufelssaurier-Gamaschen", "LEGS", 25, 53, { 3 })
gear(406, "Anfängerhelm", "HEAD", 5, 10, { 2 })
NS.BIS = { SET = {
    [1] = { name = "Pestset", items = { 402, 403 }, b = { { 2, "STRENGTH=10" } } },
    [2] = { name = "Teufelssaurier", items = { 404, 405 }, b = { { 2, "" } } },
} }
NS.Catalog._reset()
STUB.worn[1] = nil
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
assert(Gear.Available())

---------------------------------------------------------------------------
-- the logic: categories, sets, pieces, search
---------------------------------------------------------------------------
local Cat = NS.Catalog
assert(Cat.Count("dungeon", 1, 60) == 1 and Cat.Count("craft", 1, 60) == 1 and Cat.Count("raid", 1, 60) == 0)
assert(Cat.Count("dungeon", 1, 57) == 0, "the set's level is its highest piece's")
local sets = Cat.Sets("craft", 1, 60)
assert(#sets == 1 and sets[1].name == "Teufelssaurier" and sets[1].total == 2 and sets[1].have == 0 and sets[1].level == 53)
local pieces = Cat.Pieces(1)
assert(#pieces == 2 and pieces[1].id == 402 and pieces[1].slotKey == "HEAD" and pieces[1].gain > 0 and pieces[1].upgrade)
local hits, n = Cat.Search("helm", 1, 60)
assert(n == 3 and hits[1].id == 401 and hits[2].id == 402 and hits[3].id == 406, "by gain: " .. n)
hits, n = Cat.Search("HELM", 20, 60)
assert(n == 2, "the level range")
assert(select(2, Cat.Search("  ", 1, 60)) == 0, "no text: nothing")
-- the level sets: per range of ten levels the best per slot at the range's top, for the own spec
assert(Cat.ValidCat("level") and Cat.CATS[1].key == "level", "the level sets first")
assert(Cat.Count("level", 1, 60) == 6 and Cat.Count("level", 1, 7) == 1 and Cat.Count("level", 25, 45) == 3)
local lv = Cat.Sets("level", 1, 60)
assert(#lv == 6 and lv[1].name == "Stufe 1 bis 19" and lv[6].name == "Auf Stufe 60" and lv[6].level == 60)
local function slotOf(set, slot)
    for i, k in ipairs(set.slots) do if k == slot then return set.items[i] end end
end
assert(#lv[1].items == 0 and lv[1].total == 0, "the fixture's plate: a warrior wears it from 40 on")
assert(slotOf(lv[4], "HEAD") == 406 and not slotOf(lv[4], "CHEST"), "at 49 only what a level 49 can wear")
assert(slotOf(lv[5], "HEAD") == 402 and slotOf(lv[5], "CHEST") == 403 and slotOf(lv[5], "HANDS") == 404, "at 59")
assert(slotOf(lv[6], "HEAD") == 401 and slotOf(lv[6], "LEGS") == 405, "at 60")
assert(lv[6].total == #lv[6].items and lv[6].have == 0)
assert(Cat.Set(lv[6].id) and Cat.Set(lv[6].id).name == "Auf Stufe 60", "a level set by its id")
local lp = Cat.Pieces(lv[6].id)
assert(#lp == #lv[6].items and lp[1].slotKey and lp[1].gain, "the pieces with slot and gain")

---------------------------------------------------------------------------
-- on the page Ausrüstungsplaner (D-80; until 2.64.0 the window's switch "Katalog"): a set category of
-- the side bar shows its sets, a set its pieces, a piece's click is the own pick; the search
---------------------------------------------------------------------------
NS.ShowPlanner("sets", "dungeon")
local f = NS.PageFrame("planner")
local items = f.list.items
assert(#items == 1 and items[1].set and items[1].set.name == "Pestset", "the dungeon sets")
f.list.rows[1]:Click()
items = f.list.items
assert(#items == 3 and items[1].open and items[2].id == 402 and items[3].id == 403, "the open set's pieces")
local lines = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(self, text, ...) lines[#lines + 1] = text; return addLine(self, text, ...) end
f.list.rows[1]:GetScript("OnEnter")(f.list.rows[1])
GameTooltip.AddLine = addLine
assert(has(table.concat(lines, "|"), "0 von 2 Teilen") and has(table.concat(lines, "|"), "(2) Stärke +10"), table.concat(lines, "|"))
f.list.rows[2]:Click()
assert(NS.BisPick("HEAD") == 402, "a piece is the own pick")
NS.BisSetPick("HEAD", nil)
NS.ShowPlanner("sets", "pvp")
assert(f.list.items[1].note and has(f.list.items[1].note, "Keine Sets"))
NS.ShowPlanner("search", "helm")
items = f.list.items
assert(#items == 3 and items[1].id == 401 and has(f.title:GetText(), "3 Treffer"), f.title:GetText())
NS.ShowPlanner("search", "gibtsnicht")
assert(f.list.items[1].note == "Kein Item gefunden.")
print("test_goals_catalog ok")
