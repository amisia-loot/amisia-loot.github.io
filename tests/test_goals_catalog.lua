-- The catalog of the window "Ausrüstungsziele" (F-123): the third switch "Katalog" in the place of
-- the list and the slot panel; the item sets by where their pieces come from (raid, dungeon, PvP,
-- crafting, world) with counts, a set opened with its pieces, "Set anprobieren" and a click on an
-- item tried on the model, "Anprobe leeren"; the search over every item by name and level range,
-- the best for the own character first, "Meine Stufe" and "Alle"; the menu's "Als meine Wahl"; the
-- choice kept in settings.goalWindow, the search text not.
local Gear = NS.Gear
local G = NS.Theme.GOALS
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

---------------------------------------------------------------------------
-- the window: the switch, the categories, a set
---------------------------------------------------------------------------
local win = NS.ShowGoalsFrame()
local d, C = win.doll, win.catalog
assert(d.catalog and d.catalog.label:GetText() == "Katalog" and not C:IsShown())
d.catalog:Click()
assert(NS.GoalsFrameState().mode == "catalog" and C:IsShown() and not win.list:IsShown() and not win.side:IsShown()
    and not win.progress:IsShown(), "the catalog in the place of the list and the panel")
assert(d.catalog.on and not d.goals.on and not d.worn.on)
assert(C.lo.current == 1 and C.hi.current == 60 and C.mine.on and C.all.on, "1 to the own level (60)")
assert(C.cats.dungeon.count:GetText() == "1" and C.cats.pvp.count:GetText() == "0" and C.cats.raid.count:GetText() == "0")
local items = C.list.items
assert(#items == 1 and items[1].set and items[1].set.name == "Pestset" and not items[1].open, "dungeon sets first")
local r = C.list.rows[1]
assert(has(plain(r.name:GetText()), "Pestset") and plain(r.slot:GetText()) == "0/2" and r.level:GetText() == "58")
assert(not C.tryAll:IsEnabled(), "no set open")
r:Click()
items = C.list.items
assert(#items == 3 and items[1].open and items[2].id == 402 and items[3].id == 403, "the open set's pieces")
assert(NS.GoalsFrameState().set == 1 and C.tryAll:IsEnabled())
local r2 = C.list.rows[2]
assert(has(plain(r2.name:GetText()), "Helm der Pest") and r2.slot:GetText() ~= "" and has(plain(r2.gain:GetText()), "+"))
-- the set's tooltip with its bonus
local lines = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(self, text, ...) lines[#lines + 1] = text; return addLine(self, text, ...) end
r:GetScript("OnEnter")(r)
GameTooltip.AddLine = addLine
assert(has(table.concat(lines, "|"), "0 von 2 Teilen") and has(table.concat(lines, "|"), "(2) Stärke +10"), table.concat(lines, "|"))

-- try on: the set, then clear
local m = d.model
C.tryAll:Click()
local tried = table.concat(m.tried, " ")
assert(has(tried, "item:402") and has(tried, "item:403") and has(d.dressed, "+402"), "the set tried on: " .. tried)
assert(C.clear:IsEnabled())
C.clear:Click()
assert(not has(d.dressed, "+402") and not C.clear:IsEnabled())
-- a click on a piece tries it on
r2:Click()
assert(has(d.dressed, "+402"))
C.clear:Click()

-- the menu: as the own pick
local entries
local menu = NS.W.Menu
NS.W.Menu = function(_, e) entries = e end
r2:GetScript("OnClick")(r2, "RightButton")
NS.W.Menu = menu
assert(entries and entries[1][1] == "Als meine Wahl", "the own pick first")
entries[1][2]()
assert(NS.BisPick("HEAD") == 402, "the pick taken")
NS.BisSetPick("HEAD", nil)

-- another category; an empty one says so
C.cats.craft:Click()
assert(NS.GoalsFrameState().cat == "craft" and NS.GoalsFrameState().set == nil and C.list.items[1].set.name == "Teufelssaurier")
C.cats.pvp:Click()
assert(C.list.items[1].note and has(C.list.items[1].note, "Keine Sets"))

---------------------------------------------------------------------------
-- the search and the level range
---------------------------------------------------------------------------
C.search:SetText("helm")
C.search:GetScript("OnEnterPressed")(C.search)
items = C.list.items
assert(#items == 3 and items[1].id == 401 and has(C.hint:GetText(), "3 Treffer auf Stufe 1-60"), C.hint:GetText())
assert(not C.cats.pvp.art or not C.cats.pvp.art.sel:IsShown(), "no category chosen while searching")
C.lo.plus:Click()
for _ = 1, 30 do C.lo.plus:Click() end
assert(NS.GoalsFrameState().lo == 32 and #C.list.items == 2, "from level 32: " .. tostring(NS.GoalsFrameState().lo))
assert(not C.all.on)
C.all:Click()
assert(NS.GoalsFrameState().lo == 1 and NS.GoalsFrameState().hi == 60 and #C.list.items == 3)
C.search:SetText("gibtsnicht")
C.search:GetScript("OnEnterPressed")(C.search)
assert(C.list.items[1].note == "Kein Item gefunden.")
-- at level 20 "Meine Stufe" is 1-20
STUB.level = 20
STUB.fire("PLAYER_LEVEL_UP")
C.mine:Click()
assert(NS.GoalsFrameState().hi == 20 and C.mine.on and not C.all.on)
STUB.level = 60
STUB.fire("PLAYER_LEVEL_UP")

-- an empty box: the sets again
C.search:SetText("")
C.search:GetScript("OnEnterPressed")(C.search)
assert(C.list.items[1].note or C.list.items[1].set, "the sets of the category")
-- the switch back: the list again
d.goals:Click()
assert(not C:IsShown() and win.list:IsShown() and win.side:IsShown())
-- a bad saved choice falls back
local st = NS.GoalsFrameState()
st.cat, st.lo, st.hi = "mounts", 50, 10
d.catalog:Click()
assert(st.cat == nil and st.lo == nil and C.lo.current == 1, "a bad choice: dungeon sets, 1 to the own level")
assert(C.list.items[1].set and C.list.items[1].set.name == "Pestset")
assert(C.hi.current == 60)
print("test_goals_catalog ok")
