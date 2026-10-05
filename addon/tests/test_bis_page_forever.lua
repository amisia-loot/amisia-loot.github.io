-- The gear page on WoW Forever (Pages/Gear.lua): the Forever source chips without a phase, the
-- button for the level-range table, the targets and the explanation from the Forever data, "Hier"
-- in a zone, the overview card, the quick menu with the page and the table, the planner's
-- upgrades from the targets and the check mark on owned items in its cells, and the layout at the
-- main window's size in both views.
local Gear = NS.Gear
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
assert(Gear.Available() and Gear.Game == nil and Gear.PlannerAvailable == nil, "the one data set, no game switch")
STUB.class, STUB.level = "WARRIOR", 60
STUB.instance = { name = "Elwynn", type = "none", id = 0 }
STUB.place.map = 1429
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3 }
STUB.maps[1415] = { name = "Östliche Königreiche", parent = 946, mapType = 2 }
STUB.roster = {}

-- a small Forever data set (no game field, as GearData.lua): a quest in Elwynn, a dungeon boss
NS.GEAR = { built = "test-page-forever", Z = { [1429] = "Wald von Elwynn" }, I = {}, S = {
    { "Q", "Die Eberjagd", 58, 55, "", 1429, 183, 0 },          -- 1
    { "D", "Stratholme", "Baron Totenschwur", nil, 2017 },     -- 2
    { "V", "Tharynn", 1429, "", "Rüstungen" },                 -- 3
} }
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, stats, sources)
    LINKS[id] = STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.stats, it.minLevel = "INVTYPE_" .. loc, 4, 4, stats, 55
    if sources then
        NS.GEAR.I[id] = { loc, 4, 4, 55, 3, 1, 141, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
end
gear(401, "Eberhelm", "HEAD", { ITEM_MOD_STRENGTH_SHORT = 20 }, { 1 })
gear(402, "Baronshelm", "HEAD", { ITEM_MOD_STRENGTH_SHORT = 30 }, { 2 })
gear(403, "Händlerbrust", "CHEST", { ITEM_MOD_STRENGTH_SHORT = 12 }, { 3 })
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

NS.ShowPage("gear")
local f = NS.GearPageFrame()
assert(NS.CurrentPage() == "gear" and f:IsShown())
assert(f.open:IsShown(), "the table button on Forever")
for _, k in ipairs({ "Q", "D", "C", "V", "W", "A", "P" }) do assert(f.src[k]:IsShown(), "Forever chip " .. k) end
assert(not f.src.X:IsShown(), "no raid chip while the data has no raid")
assert(f.src.H == nil and f.src.F == nil, "no chips for heroic dungeons or reputation")
assert(f.phase == nil and f.phaseText == nil, "no phase picker")
assert(not f.src.A.on and not f.src.P.on and f.src.Q.on, "auction house and PvP start off")
assert(has(f.counts:GetText(), "Level 60") and has(f.counts:GetText(), "2 Upgrades"), f.counts:GetText())
local G = f.goals
assert(has(G.list.rows[1].best:GetText(), "Baronshelm") and G.list.rows[1].src:GetText() == "Stratholme: Baron Totenschwur",
    G.list.rows[1].src:GetText())
assert(G.title:GetText() == "Kopf · Bestes für Waffen/Furor (geraten)", G.title:GetText())
assert(has(G.explain:GetText(), "+60 Punkte") and has(G.explain:GetText(), "30 Stärke x 2,0 = 60"), G.explain:GetText())
assert(not has(G.explain:GetText(), "Obergrenze"), "no hit note on Forever")
-- the table button opens the level-range planner
f.open:Click()
assert(AmisiaGearFrame and AmisiaGearFrame:IsShown(), "Tabelle öffnen")

-- the planner: the upgrades from the targets, owned items with a check in the cells
local list = NS.GearMyUpgrades()
assert(#list == 2 and list[1].id == 402 and list[1].slot.key == "HEAD" and math.floor(list[1].gain + 0.5) == 60, "best first")
STUB.bags[0] = { 402 }
NS.BisScanBags()
NS.GearRefresh(true)
local cells = NS._gearFrame.cells()
local col = Gear.ColumnOf(60)
assert(cells[1][col].id == 402 and cells[1][col].own:IsShown(), "the owned helm has the check")
assert(cells[5][col].id == 403 and not cells[5][col].own:IsShown(), "the chest is not owned")
STUB.bags[0] = nil
NS.BisScanBags()
NS.GearRefresh(true)
assert(not cells[1][col].own:IsShown(), "gone again")
AmisiaGearFrame:Hide()

-- here: the zone and its parents; the vendor is in Elwynn, the quest too
f.views.here:Click()
local Hh = f.here
assert(Hh.pick.label:GetText() == "Hier: Wald von Elwynn", Hh.pick.label:GetText())
assert(#Hh.list.items == 2 and has(Hh.list.rows[1].name:GetText(), "Eberhelm") and has(Hh.list.rows[2].name:GetText(), "Händlerbrust"),
    "the quest helm (+40) before the vendor's chest (+24): " .. #Hh.list.items)
assert(Hh.list.rows[1].boss:GetText() == "Quest: Die Eberjagd (58)", Hh.list.rows[1].boss:GetText())
f.views.goals:Click()

-- the card and the quick menu
local card
for _, c in ipairs(NS.cards) do if c.key == "gear" then card = c end end
local c = NS.W.Card(UIParent, 296, 112)
card.fill(c)
assert(has(c.line1:GetText(), "Level 60 · 2 Upgrades · 0 Wünsche"), c.line1:GetText())
assert(has(c.line2:GetText(), "Bestes: ") and has(c.line2:GetText(), "Baronshelm") and has(c.line2:GetText(), "(+60)"), c.line2:GetText())
local labels = {}
for _, e in ipairs(NS.MinimapMenuEntries()) do labels[#labels + 1] = e[1] end
labels = table.concat(labels, "|")
assert(has(labels, "Ausrüstung|Ausrüstungstabelle|"), "page first, then the table: " .. labels)
for _, e in ipairs(NS.MinimapMenuEntries()) do if e[1] == "Ausrüstungstabelle" then e[2]() end end
assert(AmisiaGearFrame:IsShown(), "the table from the quick menu")
AmisiaGearFrame:Hide()

-- layout at the main window's size, officer and raider view
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
local row = Lay.row
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowGear("goals")
    row(view .. " head", f.spec, f.views.goals, f.views.here, f.views.wish, f.views.guild, f.open)
    row(view .. " sources", f.src.Q, f.src.D, f.src.C, f.src.V, f.src.W, f.src.A, f.src.P)
    -- the goals end 12 px before the edge, their bar inside the page
    local gl = f.goals.list
    row(view .. " goal list", gl, gl.bar)
    Lay.inside(view .. " goal list bar", gl.bar)
    local _, gr = Lay.span(gl.rows[1].gain)
    assert(gr <= 590, "the gain ends in the row: " .. gr)
    assert(f.views.guild:IsShown() == (view == "officer"), "the guild view for officers only, without a list")
end
NS.Reset("ui.view")
assert(plain(f.views.goals.label:GetText()) == "Ziele")
