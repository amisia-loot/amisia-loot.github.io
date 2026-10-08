-- The map page on WoW Forever: without the GetItemInfo globals; a quest with its giver; "Weg" sets
-- the client's waypoint; a waypoint the player set himself is named in the target line; the quick
-- menu keeps the page and the table together; the layout at 602 x 478 for officers and raiders.
local Gear, Map = NS.Gear, NS.Map
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
assert(NS.MAP and NS.MAP.game == "forever" and GetItemInfo == nil and Map.ClientWaypoints(), "Forever without the item globals")
STUB.class, STUB.level, STUB.faction = "WARRIOR", 60, "Alliance"
STUB.instance = { type = "none" }
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3, world = { 0, 0, 0, 1000, 1000 } }
STUB.maps[1415] = { name = "Östliche Königreiche", parent = 946, mapType = 2 }
STUB.place.map = 1429
STUB.map.pos = { x = 0.5, y = 0.5 }
local function gear(id, name, loc, str, sources)
    STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.stats, it.minLevel = "INVTYPE_" .. loc, 4, 4, { ITEM_MOD_STRENGTH_SHORT = str }, 55
    NS.GEAR.I[id] = { loc, 4, 4, 55, 3, 1, 60, 0, 0, 0 }
    for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
end
NS.GEAR = { game = "forever", cap = 60, built = "t-map-page-fe", Z = { [1429] = "Wald von Elwynn" }, I = {}, S = {
    { "Q", "Die Eberjagd", 58, 55, "", 1429, 183, 0 },          -- 1
    { "V", "Tharynn", 1429, "", "Rüstungen" },                 -- 2
} }
Gear._reset()
gear(401, "Eberhelm", "HEAD", 20, { 1 })
gear(403, "Händlerbrust", "CHEST", 12, { 2 })
NS.MAP = { game = "forever", built = "2026-10-05", G = { ["Q:183"] = "Marshal McBride" }, P = {
    ["Q:183"] = "1429:4230:6510",
    ["V:Tharynn"] = "1429:4100:6600",
} }
Map._reset()
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

NS.ShowMap()
assert(NS.CurrentPage() == "map")
local f = NS.MapPageFrame()
local rows = f.list.rows
assert(f.zone.label:GetText() == "Hier: Wald von Elwynn" and #f.list.items == 2, f.zone.label:GetText())
local quest
for _, r in ipairs(rows) do if r.item and r.item.key == "Q:183" then quest = r end end
assert(quest and quest.kind:GetText() == "Quest", "the quest row")
assert(has(quest.src:GetText(), "Die Eberjagd") and has(quest.src:GetText(), "(Marshal McBride)"), quest.src:GetText())
assert(has(quest.items:GetText(), "Eberhelm"), quest.items:GetText())

-- Weg: the client's waypoint
quest.go:Click()
local t = NS.MapTarget()
assert(t and t.ours and STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1429, "the client's waypoint")
assert(has(f.target:GetText(), "Ziel: Marshal McBride, Wald von Elwynn 42, 65"), f.target:GetText())
f.clear:Click()
assert(NS.MapTarget() == nil and STUB.waypoint.point == nil, "cleared, and the own waypoint with it")

-- a waypoint of the player's own: named, and "Weg" replaces it
C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(1429, 0.2, 0.2))
NS.Refresh()
assert(has(f.target:GetText(), "Dein eigener Wegpunkt ist gesetzt; Weg ersetzt ihn."), f.target:GetText())
quest.go:Click()
assert(NS.MapTarget() and NS.MapTarget().ours and math.abs(STUB.waypoint.point.position.x - 0.423) < 1e-6, "replaced")
NS.MapClearTarget()

-- the quick menu: the page and the table stay together, the map after them
local labels = {}
for _, e in ipairs(NS.MinimapMenuEntries()) do labels[#labels + 1] = e[1] end
labels = table.concat(labels, "|")
assert(has(labels, "Ausrüstung|Ausrüstungstabelle|Karte|"), labels)

-- the Fundort line with the giver
STUB.shift = true
local lines = NS.BisTooltipLines(STUB.items[401].link) or {}
STUB.shift = false
assert(lines[#lines] and lines[#lines][1] == "Fundort: Marshal McBride, Wald von Elwynn 42, 65", tostring(lines[#lines] and lines[#lines][1]))

-- layout, officer and raider
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
assert(NS.MapSetTarget(401))
AmisiaDB.map.hidden["V:Tharynn"] = true
NS.Fire("MAP_TARGET")
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowMap()
    NS.Refresh()
    L.row(view .. " head", f.zone, f.targets, f.wishes, f.open)
    L.row(view .. " target", f.target, f.clear)
    L.row(view .. " columns", f.head.kind, f.head.src, f.head.where, f.head.items, f.head.go)
    L.row(view .. " row", rows[1].kind, rows[1].src, rows[1].where, rows[1].items, rows[1].go, f.list.bar)
    L.row(view .. " list", f.list, f.list.bar)
    L.inside(view .. " list bar", f.list.bar)
    L.column(view .. " page", f.zone, f.counts, f.target, f.head.kind, f.list, f.showHidden, f.hint, f.data)
    for _, fs in ipairs({ f.target, f.counts, f.hint, f.data, rows[1].where }) do L.fits(fs) end
    local gp = NS.GearPageFrame and NS.GearPageFrame()
    NS.ShowGear("goals", "HEAD")
    gp = NS.GearPageFrame()
    local G2 = dofile(ADDON_DIR .. "/../tests/layout.lua")(gp, 602, 478)
    local O = gp.goals.opts
    assert(O[1].map:IsShown(), "the map button on Forever")
    G2.row(view .. " option", O[1].rank, O[1].name, O[1].map, O[1].src, O[1].gain, O[1].wish, O[1].ex)
end
NS.Reset("ui.view")
NS.MapClearTarget()
