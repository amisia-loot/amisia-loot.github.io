-- The map page (Pages/Map.lua) on small Forever data: the panel and /amisia karte; the zone picker with
-- "Hier" (sub zones, instances) and the zones with a count; the list sorted by distance, the hidden
-- places grey at the bottom; "Weg", a click, shift-click and the menu; the target line with "Ziel
-- löschen" and its tick; the empty states; the switches shared with the pins; a refresh rebuilds
-- nothing while nothing changed and changes rebuild at most once a second. The gear page's map
-- buttons and menu entries (Ziele, Hier, Wunschliste) only with a place; the "Fundort" line on
-- Shift with map.tooltip and its cheap hover; the quick menu; the layout at 602 x 478 for officers
-- and raiders; no panel without map data; Latin-1 only.
local Gear, Map = NS.Gear, NS.Map
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

---------------------------------------------------------------------------
-- data: a warrior at 60, vendors in Durotar and Elwynn (as in the pins test)
---------------------------------------------------------------------------
AmisiaDB.settings.gear = { specs = { WARRIOR = "dps" } }
STUB.class, STUB.level, STUB.faction = "WARRIOR", 60, "Alliance"
STUB.instance = { type = "none" }
STUB.maps[1411] = { name = "Durotar", parent = 1414, mapType = 3, world = { 1, 0, 0, 1000, 1000 } }
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3, world = { 0, 0, 0, 1000, 1000 } }
STUB.maps[1440] = { name = "Eschental", parent = 1414, mapType = 3, world = { 1, 2000, 0, 1000, 1000 } }
STUB.maps[1428] = { name = "Brennende Steppe", parent = 1415, mapType = 3, world = { 0, 3000, 0, 1000, 1000 } }
STUB.maps[1500] = { name = "Klingenhügel", parent = 1411, mapType = 5 }
STUB.maps[1414] = { name = "Kalimdor", parent = 947, mapType = 2 }
STUB.maps[947] = { name = "Azeroth", mapType = 1 }
STUB.place.map = 1411
STUB.map.pos = { x = 0.1, y = 0.1 }
local I, LINKS = {}, {}
local function gear(id, name, loc, str, sources)
    LINKS[id] = STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.icon = "INVTYPE_" .. loc, 4, 4, 1000 + id
    it.stats, it.bind, it.minLevel = { ITEM_MOD_STRENGTH_SHORT = str }, 1, 60
    I[id] = { loc, 4, 4, 60, 4, 1, 70, 0, 0, 0 }
    for _, n in ipairs(sources) do I[id][#I[id] + 1] = n end
end
local S = {
    { "V", "Gorn One Eye", 1411, "", "Armorer" },     -- 1
    { "V", "Second Vendor", 1411, "", "" },           -- 2
    { "V", "Elwynn Guy", 1429, "", "" },              -- 3
    { "V", "Many Spots", 1411, "", "" },              -- 4 (no place in the map data)
    { "C", "tailoring", 300 },                        -- 5
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 0, 0 },   -- 6 (entrance in the Burning Steppes)
}
gear(201, "Helm Gorn", "HEAD", 40, { 1 })
gear(202, "Brust Gorn", "CHEST", 30, { 1 })
gear(203, "Hose Zwei", "LEGS", 20, { 2 })
gear(204, "Stiefel Elwynn", "FEET", 10, { 3 })
gear(205, "Handschuhe Wunsch", "HAND", 15, { 2 })
gear(206, "Schultern Schneider", "SHOULDER", 25, { 5 })
gear(207, "Gürtel Viele", "WAIST", 12, { 4 })
gear(208, "Armschienen Kern", "WRIST", 30, { 6 })
STUB.areas[2717] = "Geschmolzener Kern"
NS.GEAR = { game = "forever", cap = 60, built = "t-page", S = S, I = I, Z = {} }
Gear._reset()
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = {
    ["V:Gorn One Eye"] = "1411:4720:3310",
    ["V:Second Vendor"] = "1411:6000:7000 1429:1000:1000",
    ["V:Elwynn Guy"] = "1429:4000:4000",
    ["I:409"] = "1428:4670:7020",
} }
Map._reset()
local me = NS.BisChar()
me.wish[205] = { t = 1, prio = 3, note = "" }
NS.Fire("BIS_CHANGED")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)

---------------------------------------------------------------------------
-- the panel and the command
---------------------------------------------------------------------------
local panel = NS.Panel("map")
assert(panel and panel.label == "Karte" and panel.order == 55 and panel.icon == "Interface\\Icons\\INV_Misc_Map_01", "the panel")
assert(NS.Visible(panel), "available with gear and map data")
local saved = NS.MAP
NS.MAP = nil
assert(not NS.Visible(panel), "no map data, no page")
NS.MAP = saved
NS.Dispatch("karte")
assert(NS.CurrentPage() == "map", "/amisia karte opens the page")
local f = NS.MapPageFrame()
assert(f and f:IsShown(), "the page frame")

---------------------------------------------------------------------------
-- the picker: "Hier" first, then the zones with places, by name, with a count
---------------------------------------------------------------------------
local function values()
    local out = {}
    for _, v in ipairs(f.zone.values) do out[#out + 1] = tostring(v.value) .. "=" .. v.text end
    return table.concat(out, "|")
end
assert(values() == "here=Hier: Durotar|1428=Brennende Steppe (1)|1411=Durotar (2)|1429=Wald von Elwynn (2)", values())
assert(f.zone.label:GetText() == "Hier: Durotar", f.zone.label:GetText())

---------------------------------------------------------------------------
-- the list: Durotar, sorted by distance from the player (0.1, 0.1)
---------------------------------------------------------------------------
local rows = f.list.rows
assert(#f.list.items == 2, "two places in Durotar: " .. #f.list.items)
assert(rows[1].item.key == "V:Gorn One Eye" and rows[2].item.key == "V:Second Vendor", "the nearer first")
assert(rows[1].kind:GetText() == "Händler" and rows[1].src:GetText() == "Gorn One Eye", rows[1].src:GetText())
assert(rows[1].where:GetText() == "47, 33 · 438 m", rows[1].where:GetText())
assert(has(rows[1].items:GetText(), "Helm Gorn") and has(rows[1].items:GetText(), "+1"), rows[1].items:GetText())
assert(has(rows[2].items:GetText(), "Handschuhe Wunsch") and has(rows[2].items:GetText(), "UI-RaidTargetingIcon_1"),
    "the wish first, with its star: " .. rows[2].items:GetText())
assert(rows[1].go:GetText() == "Weg")
local counts = f.counts:GetText()
assert(has(counts, "2 Orte · 4 Items") and has(counts, "2 Items ohne Ort") and has(counts, "Berufe"), counts)
assert(f.target:GetText() == "Kein Ziel gesetzt." and not f.clear:IsShown(), f.target:GetText())
assert(has(f.hint:GetText(), "Klick auf eine Zeile: Ziel setzen. Shift-Klick: auf der Weltkarte zeigen."), f.hint:GetText())
assert(has(f.data:GetText(), "Kartendaten vom 05.10.2026") and has(f.data:GetText(), "englisch"), f.data:GetText())
assert(not f.showHidden:IsShown(), "nothing hidden")

-- a sub zone counts as its zone
STUB.place.map = 1500
NS.Refresh()
assert(f.zone.label:GetText() == "Hier: Durotar" and #f.list.items == 2, "Klingenhügel is in Durotar")
STUB.place.map = 1411
NS.Refresh()

---------------------------------------------------------------------------
-- a refresh rebuilds nothing while nothing changed
---------------------------------------------------------------------------
local placesCalls = 0
local realPlaces = NS.MapItemPlaces
NS.MapItemPlaces = function(...) placesCalls = placesCalls + 1; return realPlaces(...) end
local builds = Map.PageBuilds()
NS.Refresh(); NS.Refresh(); NS.Refresh()
assert(Map.PageBuilds() == builds and placesCalls == 0, ("no rebuild: %d builds, %d place lookups"):format(Map.PageBuilds() - builds, placesCalls))

---------------------------------------------------------------------------
-- Weg, a click, the target line, Ziel löschen
---------------------------------------------------------------------------
rows[2].go:Click()
local t = NS.MapTarget()
assert(t and t.key == "V:Second Vendor" and near(t.x, 0.6) and near(t.y, 0.7) and t.item == 205, "Weg: the target")
assert(f.target:GetText() == "Ziel: Second Vendor, Durotar 60, 70 · 781 m", f.target:GetText())
assert(f.clear:IsShown(), "the clear button with a target")
assert(rows[2].item.target and not rows[1].item.target, "the target's row")
assert(Map.PageBuilds() == builds, "a new target rebuilds no index")
-- the tick: the distance follows the player, only every half second
STUB.map.pos = { x = 0.6, y = 0.6 }
f.scripts.OnUpdate(f, 0.2)
assert(has(f.target:GetText(), "781 m"), "not yet")
f.scripts.OnUpdate(f, 0.4)
assert(f.target:GetText() == "Ziel: Second Vendor, Durotar 60, 70 · 100 m", f.target:GetText())
STUB.map.pos = { x = 0.1, y = 0.1 }
f.clear:Click()
assert(NS.MapTarget() == nil and f.target:GetText() == "Kein Ziel gesetzt." and not f.clear:IsShown(), "cleared")
-- a click on the row sets the target too
rows[1].scripts.OnClick(rows[1], "LeftButton")
assert(NS.MapTarget() and NS.MapTarget().key == "V:Gorn One Eye" and NS.MapTarget().item == 201, "row click: the target")
assert(has(lastMsg(), "Ziel Gorn One Eye, Durotar 47, 33 (Helm Gorn)."), lastMsg())
NS.MapClearTarget()
-- shift: the world map on the place's zone
WorldMapFrame:Hide()
STUB.shift = true
rows[2].scripts.OnClick(rows[2], "LeftButton")
STUB.shift = false
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1411 and NS.MapTarget() == nil, "shift: the world map, no target")
WorldMapFrame:Hide()
-- the world map took the main window out of the way: open the page again
NS.ShowMap()
assert(placesCalls == 0, "no place lookups for clicks on the list: " .. placesCalls)
NS.MapItemPlaces = realPlaces

-- the row tooltip shows every item, like the pin
local lines = {}
local addLine, addDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
GameTooltip.AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. " = " .. b end
rows[1].scripts.OnEnter(rows[1])
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine, addDouble
local tip = table.concat(lines, "|")
assert(lines[1] == "Händler: Gorn One Eye" and has(tip, "Helm Gorn|r = +80 (Kopf)") and has(tip, "Brust Gorn|r = +60 (Brust)"), tip)
assert(has(lines[#lines], "Shift-Klick"), tostring(lines[#lines]))

---------------------------------------------------------------------------
-- the menu: as on the pin; hiding moves the place to the bottom, grey, and back
---------------------------------------------------------------------------
local function menuLabels()
    local out = {}
    for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then out[#out + 1] = b.label:GetText() end end
    return table.concat(out, ",")
end
local function menuClick(label)
    for _, b in ipairs(AmisiaMenu.buttons) do
        if b:IsShown() and b.label:GetText() == label then b:Click() return end
    end
    error("no menu entry " .. label .. ": " .. menuLabels())
end
rows[1].scripts.OnClick(rows[1], "RightButton")
assert(AmisiaMenu:IsShown() and menuLabels() == "Ziel setzen,Item auf der Seite zeigen,Diesen Ort ausblenden,Alle Pins aus", menuLabels())
menuClick("Diesen Ort ausblenden")
NS.Refresh()
assert(AmisiaDB.map.hidden["V:Gorn One Eye"] and rows[2].item.key == "V:Gorn One Eye" and rows[2].item.hidden, "hidden: at the bottom")
assert(f.showHidden:IsShown() and f.showHidden:GetText() == "Ausgeblendete zeigen (1)", f.showHidden:GetText())
rows[2].scripts.OnClick(rows[2], "RightButton")
assert(has(menuLabels(), "Wieder einblenden") and not has(menuLabels(), "Diesen Ort ausblenden"), menuLabels())
menuClick("Wieder einblenden")
NS.Refresh()
assert(not AmisiaDB.map.hidden["V:Gorn One Eye"] and rows[1].item.key == "V:Gorn One Eye" and not f.showHidden:IsShown(), "shown again")
AmisiaDB.map.hidden["V:Gorn One Eye"], AmisiaDB.map.hidden["V:Second Vendor"] = true, true
NS.Fire("MAP_TARGET")
NS.Refresh()
assert(f.showHidden:GetText() == "Ausgeblendete zeigen (2)")
f.showHidden:Click()
assert(next(AmisiaDB.map.hidden) == nil and not f.showHidden:IsShown(), "the button shows them all again")
rows[1].scripts.OnClick(rows[1], "RightButton")
menuClick("Item auf der Seite zeigen")
assert(NS.CurrentPage() == "gear" and AmisiaDB.settings.bis.view == "goals" and AmisiaDB.settings.bis.slot == "HEAD", "the item on the gear page")
NS.ShowMap()
assert(NS.CurrentPage() == "map")

---------------------------------------------------------------------------
-- another zone from the picker: no distance there, the wish first
---------------------------------------------------------------------------
f.zone:SetValue(1429); f.zone.onPick(1429)
assert(AmisiaDB.settings.map.zone == 1429 and f.zone.label:GetText() == "Wald von Elwynn (2)", f.zone.label:GetText())
assert(#f.list.items == 2 and rows[1].item.key == "V:Second Vendor" and rows[2].item.key == "V:Elwynn Guy", "by the best item")
assert(rows[1].where:GetText() == "10, 10" and rows[2].where:GetText() == "40, 40", rows[1].where:GetText())
f.open:Click()
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1429, "Weltkarte öffnen: the chosen zone")
WorldMapFrame:Hide()
NS.ShowMap("hier")
assert(AmisiaDB.settings.map.zone == nil and f.zone.label:GetText() == "Hier: Durotar", "ShowMap(\"hier\") picks the own zone again")
NS.ShowMap(1429)
assert(AmisiaDB.settings.map.zone == 1429 and #f.list.items == 2, "ShowMap(zone)")
f.zone:SetValue("here"); f.zone.onPick("here")
assert(AmisiaDB.settings.map.zone == nil)

---------------------------------------------------------------------------
-- the switches shared with the pins
---------------------------------------------------------------------------
assert(f.targets.on and f.wishes.on and f.targets.label:GetText() == "Ziele" and f.wishes.label:GetText() == "Wünsche")
f.targets:Click()
assert(NS.Get("map.pinsTargets") == false and not f.targets.on, "the chip writes map.pinsTargets")
assert(#f.list.items == 1 and rows[1].item.key == "V:Second Vendor" and #rows[1].item.items == 1, "only the wish")
f.wishes:Click()
assert(NS.Get("map.pinsWishes") == false and #f.list.items == 0)
assert(f.empty:IsShown() and f.empty:GetText() == "Ziele und Wünsche sind ausgeblendet. Oben einschalten.", f.empty:GetText())
f.targets:Click(); f.wishes:Click()
assert(NS.Get("map.pinsTargets") and NS.Get("map.pinsWishes") and #f.list.items == 2 and not f.empty:IsShown())

---------------------------------------------------------------------------
-- empty zone, instances, changes
---------------------------------------------------------------------------
STUB.place.map = 1440
STUB.fire("ZONE_CHANGED_NEW_AREA")
STUB.tick(1.1)
assert(f.zone.label:GetText() == "Hier: Eschental" and #f.list.items == 0, "a new zone follows the player: " .. f.zone.label:GetText())
assert(f.empty:IsShown() and f.empty:GetText() == "In dieser Zone liegt nichts aus deinen Zielen und Wünschen.", f.empty:GetText())
STUB.place.map = 1411
STUB.instance = { type = "raid", id = 409, name = "Geschmolzener Kern" }
NS.Refresh()
assert(f.zone.label:GetText() == "Hier: Brennende Steppe", "in an instance: the zone of its entrance: " .. f.zone.label:GetText())
STUB.instance = { type = "party", id = 999, name = "Unbekannt" }
NS.Refresh()
assert(f.zone.label:GetText() == "Hier: in einer Instanz" and #f.list.items == 0, f.zone.label:GetText())
STUB.instance = { type = "none" }
NS.Refresh()
assert(#f.list.items == 2)

-- changes rebuild once, at most once a second, only while the page shows
builds = Map.PageBuilds()
NS.Fire("BIS_CHANGED"); NS.Fire("BIS_CHANGED"); NS.Fire("BIS_CHANGED")
STUB.tick(1.1)
assert(Map.PageBuilds() == builds + 1, "one rebuild for three changes: " .. (Map.PageBuilds() - builds))
NS.ShowPage("overview")
NS.Fire("BIS_CHANGED")
STUB.tick(1.1)
assert(Map.PageBuilds() == builds + 1, "nothing while another page shows")
NS.ShowMap()
assert(Map.PageBuilds() == builds + 2, "built again when shown")

---------------------------------------------------------------------------
-- the gear page: map buttons and menu entries only with a place
---------------------------------------------------------------------------
NS.ShowGear("goals", "HEAD")
local gp = NS.GearPageFrame()
local O = gp.goals.opts
assert(O[1].opt and O[1].opt.id == 201 and O[1].map:IsShown(), "the head option has a place")
assert(O[1].map.icon.texture == "Interface\\Icons\\INV_Misc_Map_01" and O[1].map._w == 16 and O[1].map._h == 16, "16 px, the map icon")
O[1].map:Click()
assert(NS.MapTarget() and NS.MapTarget().key == "V:Gorn One Eye" and NS.MapTarget().item == 201, "the map button sets the target")
NS.MapClearTarget()
STUB.shift = true
O[1].map:Click()
STUB.shift = false
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1411 and NS.MapTarget() == nil, "shift: the world map")
WorldMapFrame:Hide()
lines = {}
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
O[1].map.scripts.OnEnter(O[1].map)
GameTooltip.AddLine = addLine
assert(lines[1] == "Wegpunkt zur Quelle" and has(table.concat(lines, "|"), "Fundort: Gorn One Eye, Durotar 47, 33"), table.concat(lines, "|"))
local function optMenu(i)
    O[i].scripts.OnClick(O[i], "RightButton")
    return menuLabels()
end
assert(optMenu(1) == "Item ausschließen,Ort ausschließen,Auf die Wunschliste,Wegpunkt setzen,Auf der Karte zeigen,Link in den Chat", menuLabels())
menuClick("Wegpunkt setzen")
assert(NS.MapTarget() and NS.MapTarget().key == "V:Gorn One Eye", "menu: the target")
NS.MapClearTarget()
optMenu(1)
menuClick("Auf der Karte zeigen")
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1411, "menu: the world map")
WorldMapFrame:Hide()
-- a crafted item has no place: no button, no entries
NS.ShowGear("goals", "SHOULDER")
assert(O[1].opt and O[1].opt.id == 206 and not O[1].map:IsShown(), "crafting: no button")
assert(not has(optMenu(1), "Wegpunkt setzen") and not has(menuLabels(), "Auf der Karte zeigen"), menuLabels())
AmisiaMenu:Hide()

-- Hier: the button in the boss column, not inside an instance; right click opens the menu
NS.ShowGear("here")
local Hh = gp.here
local hr = Hh.list.rows
assert(#Hh.list.items >= 3, "Durotar's vendors: " .. #Hh.list.items)
local seen = {}
for i, r in ipairs(hr) do
    if r.item then
        seen[r.item.id] = r.map:IsShown()
        if r.item.id == 207 then assert(not r.map:IsShown(), "no place for Many Spots") end
    end
end
assert(seen[201] and seen[203], "the vendors with a place have the button")
local hrow
for _, r in ipairs(hr) do if r.item and r.item.id == 201 then hrow = r end end
hrow.map:Click()
assert(NS.MapTarget() and NS.MapTarget().key == "V:Gorn One Eye", "Hier: the target")
NS.MapClearTarget()
hrow.scripts.OnClick(hrow, "RightButton")
assert(has(menuLabels(), "Wegpunkt setzen") and has(menuLabels(), "Auf der Karte zeigen"), "Hier: the menu " .. menuLabels())
AmisiaMenu:Hide()
STUB.instance = { type = "raid", id = 409, name = "Geschmolzener Kern" }
NS.ShowGear("here")
assert(Hh.list.items[1] and Hh.list.items[1].id == 208 and hr[1].item, "Molten Core's bracers inside")
for _, r in ipairs(hr) do if r.item then assert(not r.map:IsShown(), "no map button inside an instance") end end
STUB.instance = { type = "none" }
NS.ShowGear("here")
assert(not hr[1].item or hr[1].item.id ~= 208)

-- Wunschliste: the button before the source; only with a place
assert(NS.WishAdd(206))
NS.ShowGear("wish")
local V = gp.wish
local wrow, crow
for _, r in ipairs(V.list.rows) do
    if r.item and r.item.id == 205 then wrow = r end
    if r.item and r.item.id == 206 then crow = r end
end
assert(wrow and wrow.map:IsShown() and crow and not crow.map:IsShown(), "the wish with a place has the button, the crafted one not")
wrow.map:Click()
assert(NS.MapTarget() and NS.MapTarget().key == "V:Second Vendor" and NS.MapTarget().item == 205, "Wunschliste: the target")
NS.MapClearTarget()
wrow.scripts.OnClick(wrow, "RightButton")
assert(has(menuLabels(), "Von der Wunschliste nehmen") and has(menuLabels(), "Wegpunkt setzen"), "Wunschliste: the menu " .. menuLabels())
AmisiaMenu:Hide()
crow.scripts.OnClick(crow, "RightButton")
assert(not has(menuLabels(), "Wegpunkt setzen"), menuLabels())
AmisiaMenu:Hide()
NS.WishRemove(206)

-- the gear page's refresh looks the places up once per change
placesCalls = 0
NS.MapItemPlaces = function(...) placesCalls = placesCalls + 1; return realPlaces(...) end
NS.ShowGear("goals", "HEAD"); NS.Refresh()
NS.ShowGear("here"); NS.Refresh()
NS.ShowGear("wish"); NS.Refresh()
local first = placesCalls
NS.ShowGear("goals", "HEAD"); NS.Refresh()
NS.ShowGear("here"); NS.Refresh()
NS.ShowGear("wish"); NS.Refresh()
assert(placesCalls == first, ("no place lookups on a second round: %d"):format(placesCalls - first))
NS.MapItemPlaces = realPlaces

---------------------------------------------------------------------------
-- the "Fundort" line on Shift, with map.tooltip; the hover stays cheap
---------------------------------------------------------------------------
STUB.tick(2)
local function tipTexts(link)
    local out = {}
    for _, l in ipairs(NS.BisTooltipLines(link) or {}) do out[#out + 1] = l[1] end
    return out
end
local tl = tipTexts(LINKS[201])
for _, x in ipairs(tl) do assert(not has(x, "Fundort"), "no place without Shift") end
STUB.shift = true
tl = tipTexts(LINKS[201])
assert(tl[1] == "Upgrade für dich: +80 (Kopf)" and tl[#tl] == "Fundort: Gorn One Eye, Durotar 47, 33", table.concat(tl, " / "))
local full = NS.BisTooltipLines(LINKS[201])
assert(full[#full][2][1] < 0.7, "grey")
tl = tipTexts(LINKS[206])
for _, x in ipairs(tl) do assert(not has(x, "Fundort"), "crafting has no place") end
-- the nearest of several places: Second Vendor in Durotar, from Elwynn the one there
tl = tipTexts(LINKS[203])
assert(tl[#tl] == "Fundort: Second Vendor, Durotar 60, 70", tl[#tl])
STUB.place.map = 1429
STUB.map.pos = { x = 0.1, y = 0.2 }
tl = tipTexts(LINKS[203])
assert(tl[#tl] == "Fundort: Second Vendor, Wald von Elwynn 10, 10", "the nearest follows the player: " .. tl[#tl])
STUB.place.map = 1411
STUB.map.pos = { x = 0.1, y = 0.1 }
NS.Set("map.tooltip", false)
tl = tipTexts(LINKS[201])
for _, x in ipairs(tl) do assert(not has(x, "Fundort"), "map.tooltip off") end
NS.Set("map.tooltip", true)
-- the upgrade line switched off: the place alone
NS.Set("bis.tooltip", false)
tl = tipTexts(LINKS[201])
assert(#tl == 1 and tl[1] == "Fundort: Gorn One Eye, Durotar 47, 33", table.concat(tl, " / "))
NS.Reset("bis.tooltip")
-- the hover: after the first one nothing is computed again
tipTexts(LINKS[201]); tipTexts(LINKS[203])
local optsCalls, srcCalls, worldCalls = 0, 0, 0
local realOpts, realSources, realWorld = NS.BisOpts, Gear.Sources, C_Map.GetWorldPosFromMapPos
NS.BisOpts = function(...) optsCalls = optsCalls + 1; return realOpts(...) end
Gear.Sources = function(...) srcCalls = srcCalls + 1; return realSources(...) end
C_Map.GetWorldPosFromMapPos = function(...) worldCalls = worldCalls + 1; return realWorld(...) end
for _ = 1, 100 do tipTexts(LINKS[201]); tipTexts(LINKS[203]) end
NS.BisOpts, Gear.Sources, C_Map.GetWorldPosFromMapPos = realOpts, realSources, realWorld
assert(optsCalls == 0 and srcCalls == 0 and worldCalls == 0,
    ("200 hovers with Shift: %d options, %d source lists, %d world positions"):format(optsCalls, srcCalls, worldCalls))
STUB.shift = false

---------------------------------------------------------------------------
-- the quick menu
---------------------------------------------------------------------------
local function quick()
    local out = {}
    for _, e in ipairs(NS.MinimapMenuEntries()) do out[#out + 1] = e[1] end
    return table.concat(out, "|")
end
assert(has(quick(), "Ausrüstung|Ausrüstungstabelle|Karte|"), quick())
for _, e in ipairs(NS.MinimapMenuEntries()) do if e[1] == "Karte" then e[2]() end end
assert(NS.CurrentPage() == "map", "the quick menu opens the page")
NS.Set("ui.view", "raider")
assert(has(quick(), "Ausrüstung|Ausrüstungstabelle|Karte|"), "raiders too: " .. quick())
NS.Reset("ui.view")
NS.MAP = nil
assert(not has(quick(), "Karte"), "no map data, no entry")
NS.MAP = saved

---------------------------------------------------------------------------
-- layout at the main window's size (content 602 x 478), officer and raider
---------------------------------------------------------------------------
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
AmisiaDB.map.hidden["V:Elwynn Guy"] = true
NS.Fire("MAP_TARGET")
assert(NS.MapSetTarget(201))
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowMap()
    NS.Refresh()
    assert(f.clear:IsShown() and f.showHidden:IsShown(), "every part shows")
    L.row(view .. " head", f.zone, f.targets, f.wishes, f.open)
    L.row(view .. " target", f.target, f.clear)
    L.row(view .. " columns", f.head.kind, f.head.src, f.head.where, f.head.items, f.head.go)
    L.row(view .. " row", rows[1].kind, rows[1].src, rows[1].where, rows[1].items, rows[1].go)
    -- the list ends 12 px before the edge; the button and the "Weg" head end before its bar
    L.row(view .. " list", f.list, f.list.bar)
    L.inside(view .. " list bar", f.list.bar)
    local _, lr = L.span(f.list)
    local _, gor = L.span(rows[1].go)
    local _, ghr = L.span(f.head.go)
    assert(lr == 590 and gor <= 590 and ghr <= 590, ("the list 590, the button %d, the head %d"):format(gor, ghr))
    L.column(view .. " page", f.zone, f.counts, f.target, f.head.kind, f.list, f.hint, f.data, f.showHidden)
    L.column(view .. " target", f.counts, f.clear, f.head.kind)
    for _, fs in ipairs({ f.target, f.counts, f.hint, f.data, rows[1].where, rows[1].kind, f.head.go }) do L.fits(fs) end
    assert(f.showHidden._w == 170 and f.open._w == 130 and f.clear._w == 110 and f.zone._w == 240, "the widths of the design")
    -- the gear page with the map buttons
    NS.ShowGear("goals", "HEAD")
    local G2 = dofile(ADDON_DIR .. "/../tests/layout.lua")(gp, 602, 478)
    G2.row(view .. " option", O[1].rank, O[1].name, O[1].map, O[1].src, O[1].gain, O[1].wish, O[1].ex)
    NS.ShowGear("here")
    G2.row(view .. " here row", hr[1].map, hr[1].boss, hr[1].name, hr[1].slot, hr[1].gain, hr[1].wishBtn, Hh.list.bar)
    NS.ShowGear("wish")
    local wr = V.list.rows
    G2.row(view .. " wish row", wr[1].name, wr[1].slot, wr[1].map, wr[1].src, wr[1].prio, wr[1].state, wr[1].del, V.list.bar)
    G2.inside(view .. " wish bar", V.list.bar)
end
NS.Reset("ui.view")
NS.MapClearTarget()
AmisiaDB.map.hidden["V:Elwynn Guy"] = nil

---------------------------------------------------------------------------
-- Latin-1 only, in the files and in the chat
---------------------------------------------------------------------------
for _, name in ipairs({ "Pages/Map.lua", "Pages/Gear.lua", "Map.lua", "MapPins.lua", "Bis.lua", "Minimap.lua" }) do
    local fh = assert(io.open(ADDON_DIR .. "/" .. name, "rb"))
    local src = fh:read("*a")
    fh:close()
    for c in src:gmatch("[\196-\255][\128-\191]") do error(name .. ": character above Latin-1: " .. c) end
end
for _, m in ipairs(STUB.messages) do
    for c in m:gmatch("[\196-\255][\128-\191]") do error("character above Latin-1 in chat: " .. m) end
end
