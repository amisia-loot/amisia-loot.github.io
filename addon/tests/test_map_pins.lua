-- Pins on the world map (MapPins.lua, MapPin.xml): the template and the TOC, the data provider
-- added once at login, pins only for the shown zone, the continent with its zone rectangles and
-- only with map.pinsContinent, one pin per spot with a count, at most 60 with wishes first, the
-- switches for targets, wishes and all pins, owned items and hidden places left out, the target's
-- own pin where the client's waypoint fails (Durotar takes no waypoint here), the tooltip, a click
-- sets the target, shift inserts the place, the right-click menu, refreshes only on a change while
-- the map shows (throttled), errors to the error handler.
local Gear, Map = NS.Gear, NS.Map
local TEMPLATE = "AmisiaMapPinTemplate"
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function readFile(name)
    local fh = assert(io.open(ADDON_DIR .. "/" .. name, "rb"))
    local src = fh:read("*a")
    fh:close()
    return src
end

---------------------------------------------------------------------------
-- the template and the TOC
---------------------------------------------------------------------------
local xml = readFile("MapPin.xml")
local tag = xml:match("<Frame%s[^>]*>")
assert(tag, "one frame template")
assert(tag:find('name="' .. TEMPLATE .. '"', 1, true) and tag:find('virtual="true"', 1, true), tag)
assert(tag:find('mixin="AmisiaMapPinMixin"', 1, true) and tag:find('enableMouse="true"', 1, true), tag)
assert(not tag:find("inherits", 1, true), "no inherited template: neither client has a pin template to inherit")
assert(xml:find('<Size x="20" y="20"/>', 1, true), "20 x 20")
assert(not xml:find("<Script", 1, true) and not xml:find("<Scripts", 1, true), "no scripts: the canvas sets them")
for c in xml:gmatch("<!%-%-(.-)%-%->") do assert(not c:find("--", 1, true), "no double hyphen in an XML comment") end
STUB.pinTemplates[TEMPLATE] = tag:match('mixin="([^"]+)"')
local toc = readFile("Amisia.toc")
local iPins, iXml, iWish = toc:find("\nMapPins.lua", 1, true), toc:find("\nMapPin.xml", 1, true), toc:find("\nGuildWishes.lua", 1, true)
assert(iPins and iXml and iWish and iWish < iPins and iPins < iXml, "MapPins.lua, then MapPin.xml, after GuildWishes.lua")
assert(type(AmisiaMapPinMixin) == "table" and AmisiaMapPinMixin.OnAcquired, "the mixin is a global for the XML")

---------------------------------------------------------------------------
-- data: a warrior at 60, vendors in Durotar and Elwynn; Durotar takes no client waypoint
---------------------------------------------------------------------------
AmisiaDB.settings.gear = { specs = { WARRIOR = "dps" } }
STUB.class, STUB.level, STUB.faction = "WARRIOR", 60, "Alliance"
STUB.waypoint.blocked[1411] = true
STUB.instance = { type = "none" }
STUB.maps[1411] = { name = "Durotar", parent = 1414, mapType = 3, world = { 1, 0, 0, 1000, 1000 } }
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3, world = { 0, 0, 0, 1000, 1000 } }
STUB.maps[1414] = { name = "Kalimdor", parent = 947, mapType = 2 }
STUB.maps[947] = { name = "Azeroth", mapType = 1 }
STUB.map.rects["1411>1414"] = { 0.5, 0.7, 0.4, 0.6 }
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
    { "V", "Many Spots", 1411, "", "" },              -- 4
    { "C", "tailoring", 300 },                        -- 5
}
gear(201, "Helm Gorn", "HEAD", 40, { 1 })
gear(202, "Brust Gorn", "CHEST", 30, { 1 })
gear(203, "Hose Zwei", "LEGS", 20, { 2 })
gear(204, "Stiefel Elwynn", "FEET", 10, { 3 })
gear(205, "Handschuhe Wunsch", "HAND", 15, { 2 })
gear(206, "Schultern Schneider", "SHOULDER", 25, { 5 })
gear(207, "Gürtel Viele", "WAIST", 12, { 4 })
NS.GEAR = { game = "forever", cap = 60, built = "t-pins", S = S, I = I, Z = {} }
Gear._reset()
local many = {}
for i = 1, 70 do many[i] = ("1411:%d:%d"):format(100 + (i % 10) * 900, 100 + math.floor(i / 10) * 1200) end
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = {
    ["V:Gorn One Eye"] = "1411:4720:3310",
    ["V:Second Vendor"] = "1411:6000:7000 1429:1000:1000",
    ["V:Elwynn Guy"] = "1429:4000:4000",
} }
Map._reset()
local me = NS.BisChar()
me.wish[205] = { t = 1, prio = 3, note = "" }
NS.Fire("BIS_CHANGED")
local r = NS.BisTargets()
assert(r.HEAD[1] and r.HEAD[1].id == 201 and r.HEAD[1].upgrade, "a head upgrade from Gorn")

---------------------------------------------------------------------------
-- the provider: added once at login
---------------------------------------------------------------------------
local function providers()
    local n, p = 0, nil
    for dp in pairs(WorldMapFrame.dataProviders) do n, p = n + 1, dp end
    return n, p
end
assert(providers() == 0, "nothing before login")
STUB.fire("PLAYER_LOGIN")
STUB.fire("ADDON_LOADED", "Blizzard_WorldMap")
STUB.fire("PLAYER_LOGIN")
local n, provider = providers()
assert(n == 1 and provider == Map.PinProvider(), "one provider, added once")
assert(provider.RefreshAllData and provider.RemoveAllData and provider:GetMap() == WorldMapFrame)

---------------------------------------------------------------------------
-- the places of a map
---------------------------------------------------------------------------
local function byKey(list)
    local out = {}
    for _, e in ipairs(list) do out[e.key .. (e.target and "*" or "")] = e end
    return out
end
local function pins() return STUB.mapPins(TEMPLATE) end
local function pinOf(key)
    for _, p in ipairs(pins()) do if p.entry and p.entry.key == key then return p end end
end

local list = Map.PinPlaces(1411)
local k = byKey(list)
assert(#list == 2 and k["V:Gorn One Eye"] and k["V:Second Vendor"], "two spots in Durotar")
local gorn = k["V:Gorn One Eye"]
assert(#gorn.items == 2 and near(gorn.x, 0.472) and near(gorn.y, 0.331), "helm and chest at one spot")
assert(gorn.point.map == 1411 and gorn.rec[2] == "Gorn One Eye")
local second = k["V:Second Vendor"]
assert(second.items[1].id == 205 and second.items[1].wish and second.items[2].id == 203, "the wish first, then the upgrade")
assert(list[1] == second, "a pin with a wish before upgrades")
assert(Map.PinPlaces(1411) == list, "kept while nothing changed")
k = byKey(Map.PinPlaces(1429))
assert(k["V:Elwynn Guy"] and k["V:Second Vendor"] and not k["V:Gorn One Eye"], "Elwynn: its own spots")
assert(#Map.PinPlaces(947) == 0, "no pins on the world map of all continents")

-- the continent: zones by their rectangle, 70 % size; only with map.pinsContinent
local cont = byKey(Map.PinPlaces(1414))
assert(cont["V:Gorn One Eye"] and near(cont["V:Gorn One Eye"].x, 0.5 + 0.472 * 0.2) and near(cont["V:Gorn One Eye"].y, 0.4 + 0.331 * 0.2))
assert(cont["V:Gorn One Eye"].continent and not cont["V:Elwynn Guy"], "Elwynn has no rectangle on Kalimdor")
NS.Set("map.pinsContinent", false)
assert(#Map.PinPlaces(1414) == 0, "switched off")
NS.Set("map.pinsContinent", true)

-- switches: targets, wishes
NS.Set("map.pinsTargets", false)
k = byKey(Map.PinPlaces(1411))
assert(not k["V:Gorn One Eye"] and k["V:Second Vendor"] and #k["V:Second Vendor"].items == 1, "only the wish")
NS.Set("map.pinsTargets", true)
NS.Set("map.pinsWishes", false)
k = byKey(Map.PinPlaces(1411))
assert(k["V:Second Vendor"] and k["V:Second Vendor"].items[1].id == 203 and #k["V:Second Vendor"].items == 2,
    "the gloves stay as the hands' upgrade, no longer as a wish")
assert(not k["V:Second Vendor"].items[1].wish and not k["V:Second Vendor"].items[2].wish)
NS.Set("map.pinsWishes", true)

-- owned items are left out
STUB.worn[1] = LINKS[201]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.tick(1)
k = byKey(Map.PinPlaces(1411))
assert(#k["V:Gorn One Eye"].items == 1 and k["V:Gorn One Eye"].items[1].id == 202, "the worn helm is gone")
STUB.worn[1] = nil
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.tick(1)

-- hidden places are left out
AmisiaDB.map.hidden["V:Gorn One Eye"] = true
NS.Fire("MAP_TARGET")
assert(not byKey(Map.PinPlaces(1411))["V:Gorn One Eye"], "hidden")
AmisiaDB.map.hidden["V:Gorn One Eye"] = nil
NS.Fire("MAP_TARGET")

-- at most 60, wishes first
NS.MAP.P["V:Many Spots"] = table.concat(many, " ")
Map._reset()
NS.Fire("BIS_CHANGED")
list = Map.PinPlaces(1411)
k = byKey(list)
assert(#list == 60 and k["V:Second Vendor"] and list[1].key == "V:Second Vendor", "60, the wish kept: " .. #list)
-- the target's spot stays even past the limit
assert(NS.MapSetPoint({ map = 1411, x = 0.01, y = 0.85 }, "Viele", "V:Many Spots", 207))
list = Map.PinPlaces(1411)
assert(#list == 61 and list[61].target and list[61].key == "V:Many Spots" and list[61].items[1].id == 207, "61 with the target")
NS.MapClearTarget()
NS.MAP.P["V:Many Spots"] = nil
Map._reset()
NS.Fire("BIS_CHANGED")

---------------------------------------------------------------------------
-- pins on the shown map
---------------------------------------------------------------------------
WorldMapFrame:Hide()
WorldMapFrame.mapID = nil
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1411)
assert(#pins() == 2, "two pins in Durotar: " .. #pins())
local p = pinOf("V:Gorn One Eye")
assert(p and near(p.normalizedX, 0.472) and near(p.normalizedY, 0.331), "placed")
assert(p.icon.texture == 1201 and p.count:GetText() == "2" and p.count:IsShown(), "the best item's icon and the count")
assert(p.pinFrameLevelType == "PIN_FRAME_LEVEL_AREA_POI" and not p.ring:IsShown(), "a normal pin")
assert(p.scaleFactor == 1 and near(p.startScale, 1) and near(p.endScale, 1.6), "scaling 1 to 1.6")
local q = pinOf("V:Second Vendor")
assert(q.icon.texture == 1205 and q.count:IsShown() and q.count:GetText() == "2", "the wish's icon first")
NS.Set("map.pinScale", 150)
STUB.tick(0.6)
p = pinOf("V:Gorn One Eye")
assert(near(p.startScale, 1.5) and near(p.endScale, 2.4), "map.pinScale")
NS.Set("map.pinScale", 100)
STUB.tick(0.6)
WorldMapFrame:SetMapID(1414)
p = pinOf("V:Gorn One Eye")
assert(p and near(p.startScale, 0.7), "70 % on the continent")
WorldMapFrame:SetMapID(1429)
assert(pinOf("V:Elwynn Guy") and not pinOf("V:Gorn One Eye"), "a new map, new pins")
assert(not pinOf("V:Elwynn Guy").count:IsShown(), "no count for a single item")
WorldMapFrame:SetMapID(1411)

-- refreshes: only on a change, only while the map shows, at most every 0.5 s
local before = Map.PinRefreshes()
NS.Fire("BIS_CHANGED")
NS.Fire("BIS_CHANGED")
assert(Map.PinRefreshes() == before, "not at once")
STUB.tick(0.6)
assert(Map.PinRefreshes() == before + 1, "once after the throttle")
STUB.tick(5)
assert(Map.PinRefreshes() == before + 1, "nothing per frame or per second")
NS.Fire("SETTING", "record.enabled", true)
STUB.tick(0.6)
assert(Map.PinRefreshes() == before + 1, "other settings do not count")
WorldMapFrame:Hide()
NS.Fire("BIS_CHANGED")
STUB.tick(0.6)
assert(Map.PinRefreshes() == before + 1, "not while the map is closed")
WorldMapFrame:Show()
assert(Map.PinRefreshes() == before + 2 and #pins() == 2, "opening the map refreshes")

-- all pins off; the target keeps its own pin
NS.Set("map.pins", false)
STUB.tick(0.6)
assert(#pins() == 0, "map.pins off")
NS.Set("map.pins", true)
STUB.tick(0.6)
assert(#pins() == 2)

---------------------------------------------------------------------------
-- the target
---------------------------------------------------------------------------
assert(Map.ClientWaypoints(), "the client has the waypoint functions")
assert(NS.MapSetTarget(201))
assert(NS.MapTarget().ours == false and STUB.waypoint.point == nil, "Durotar refuses the waypoint: Amisia's own target")
STUB.tick(0.6)
assert(#pins() == 2, "the target's place is the same pin")
p = pinOf("V:Gorn One Eye")
assert(p.entry.target and p.ring:IsShown() and p.ring.texture == "Interface\\AddOns\\Amisia\\Media\\Icons\\dot", "highlighted")
assert(p.pinFrameLevelType == "PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST", "above the others")
-- a target that is no pin of its own (another item's place) gets an extra pin
assert(NS.MapSetPoint({ map = 1411, x = 0.3, y = 0.8 }, "Irgendwo", nil, 204))
STUB.tick(0.6)
assert(#pins() == 3, "an extra pin for the target")
local tp
for _, x in ipairs(pins()) do if x.entry.target then tp = x end end
assert(tp and near(tp.normalizedX, 0.3) and near(tp.normalizedY, 0.8) and tp.icon.texture == 1204 and tp.ring:IsShown())
NS.Set("map.pins", false)
STUB.tick(0.6)
assert(#pins() == 1 and pins()[1].entry.target, "map.pins off leaves the target's pin")
NS.Set("map.pins", true)
NS.MapClearTarget()
STUB.tick(0.6)
assert(#pins() == 2)

---------------------------------------------------------------------------
-- tooltip, click, shift-click, menu
---------------------------------------------------------------------------
local lines = {}
local addLine, addDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
GameTooltip.AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. " = " .. b end
p = pinOf("V:Gorn One Eye")
p:OnMouseEnter()
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine, addDouble
local tip = table.concat(lines, "|")
assert(lines[1] == "Händler: Gorn One Eye", tostring(lines[1]))
assert(has(tip, "Durotar 47, 33") and has(tip, "Helm Gorn|r = +80 (Kopf)") and has(tip, "Brust Gorn|r = +60 (Brust)"), tip)
assert(has(lines[#lines], "Klick: Ziel setzen. Rechtsklick: mehr."), tostring(lines[#lines]))
lines = {}
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
GameTooltip.AddDoubleLine = function(_, a, b) lines[#lines + 1] = a .. " = " .. b end
pinOf("V:Second Vendor"):OnMouseEnter()
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine, addDouble
assert(has(table.concat(lines, "|"), "Handschuhe Wunsch|r = Wunsch (hoch)"), table.concat(lines, "|"))
p:OnMouseLeave()

-- a click sets the target on this spot
p:OnClick("LeftButton")
local t = NS.MapTarget()
assert(t and t.key == "V:Gorn One Eye" and near(t.x, 0.472) and t.item == 201 and t.label == "Gorn One Eye", "click: target")
NS.MapClearTarget()
STUB.tick(0.6)
-- shift: the place as text into the chat input
STUB.shift = true
pinOf("V:Gorn One Eye"):OnClick("LeftButton")
STUB.shift = false
assert(STUB.inserted == "Gorn One Eye Durotar 47, 33", tostring(STUB.inserted))
NS.MapClearTarget()
STUB.tick(0.6)

-- the menu
p = pinOf("V:Gorn One Eye")
p:OnClick("RightButton")
local menu = _G.AmisiaMenu
assert(menu and menu:IsShown() and menu.owner == p, "right click: the menu")
local labels = {}
for _, b in ipairs(menu.buttons) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
assert(table.concat(labels, ",") == "Ziel setzen,Item auf der Seite zeigen,Diesen Ort ausblenden,Alle Pins aus", table.concat(labels, ","))
menu.buttons[1]:Click()
assert(NS.MapTarget() and NS.MapTarget().key == "V:Gorn One Eye", "menu: target")
NS.MapClearTarget()
STUB.tick(0.6)
pinOf("V:Gorn One Eye"):OnClick("RightButton")
menu.buttons[2]:Click()
assert(AmisiaDB.settings.bis.view == "goals" and AmisiaDB.settings.bis.slot == "HEAD", "the item on the gear page")
pinOf("V:Second Vendor"):OnClick("RightButton")
menu.buttons[2]:Click()
assert(AmisiaDB.settings.bis.view == "wish", "a wish opens the wishlist")
pinOf("V:Gorn One Eye"):OnClick("RightButton")
menu.buttons[3]:Click()
assert(AmisiaDB.map.hidden["V:Gorn One Eye"] == true, "hidden")
STUB.tick(0.6)
assert(not pinOf("V:Gorn One Eye") and #pins() == 1, "gone from the map")
NS.SettingItem("map.resetHidden").run()
STUB.tick(0.6)
assert(pinOf("V:Gorn One Eye"), "shown again")
pinOf("V:Gorn One Eye"):OnClick("RightButton")
menu.buttons[4]:Click()
assert(NS.Get("map.pins") == false)
STUB.tick(0.6)
assert(#pins() == 0)
NS.Set("map.pins", true)
STUB.tick(0.6)

---------------------------------------------------------------------------
-- an error while building goes to the error handler, the map stays clean
---------------------------------------------------------------------------
local caught
local handler = geterrorhandler
_G.geterrorhandler = function() return function(e) caught = e end end
local places = NS.MapItemPlaces
NS.MapItemPlaces = function() error("broken places") end
NS.Fire("BIS_CHANGED")
STUB.tick(0.6)
assert(caught and has(tostring(caught), "broken places"), "reported: " .. tostring(caught))
assert(#pins() == 0, "no half pins")
NS.MapItemPlaces = places
_G.geterrorhandler = handler
NS.Fire("BIS_CHANGED")
STUB.tick(0.6)
assert(#pins() == 2, "back after the fix")

-- nothing outside the own pins: the provider writes no field into the map
for key in pairs(WorldMapFrame) do
    assert(not tostring(key):find("Amisia", 1, true), "no Amisia field on the world map: " .. tostring(key))
end

-- Latin-1 only
local src = readFile("MapPins.lua")
for c in src:gmatch("[\196-\255][\128-\191]") do error("MapPins.lua: character above Latin-1: " .. c) end
for _, m in ipairs(STUB.messages) do
    for c in m:gmatch("[\196-\255][\128-\191]") do error("character above Latin-1 in chat: " .. m) end
end
