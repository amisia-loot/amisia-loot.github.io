-- Review of 1.9: the fallback position (UnitPosition returns positionX, positionY), the world map
-- keeps the main window open one strata below the map instead of covering it, the map button's tooltip, click and menu
-- on a Hier row name the same place, item names that arrive late fill the map page, another zone
-- starts at the top of the list, the empty text with both switches off, a hint when the arrow is
-- hidden by its menu, and a degenerate map rectangle projects nothing on the continent.
local Gear, Map = NS.Gear, NS.Map
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end

AmisiaDB.settings.gear = { specs = { WARRIOR = "dps" } }
STUB.class, STUB.level, STUB.faction = "WARRIOR", 60, "Alliance"
STUB.instance = { type = "none" }
STUB.maps[1411] = { name = "Durotar", parent = 1414, mapType = 3, world = { 1, 0, 0, 1000, 1000 } }
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3, world = { 0, 0, 0, 1000, 1000 } }
STUB.maps[1428] = { name = "Brennende Steppe", parent = 1415, mapType = 3, world = { 0, 3000, 0, 1000, 1000 } }
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
    I[id] = { loc, 4, 4, 60, 4, 1, 60, 0, 0, 0 }
    for _, n in ipairs(sources) do I[id][#I[id] + 1] = n end
end
local S = {
    { "V", "Gorn One Eye", 1411, "", "Armorer" },     -- 1
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 2 (entrance in the Burning Steppes)
}
gear(201, "Helm Gorn", "HEAD", 40, { 1 })
gear(209, "Ring Doppel", "HEAD", 90, { 2, 1 })
STUB.areas[2717] = "Geschmolzener Kern"
NS.GEAR = { game = "forever", cap = 60, built = "t-r19", S = S, I = I, Z = {} }
Gear._reset()
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = {
    ["V:Gorn One Eye"] = "1411:4720:3310",
    ["I:409"] = "1428:4670:7020",
} }
Map._reset()
local me = NS.BisChar()
NS.Fire("BIS_CHANGED"); STUB.tick(2)

---------------------------------------------------------------------------
-- 1. UnitPosition: positionX, positionY (not y, x)
---------------------------------------------------------------------------
do
    local target = { map = 1411, x = 0.472, y = 0.331 }
    STUB.map.pos = nil
    local real = _G.UnitPosition
    _G.UnitPosition = function() return 472, 331, 0, 1 end
    local d = Map.Distance(target)
    _G.UnitPosition = real
    STUB.map.pos = { x = 0.1, y = 0.1 }
    assert(d and d < 1, "standing on the target by UnitPosition: " .. tostring(d))
end

---------------------------------------------------------------------------
-- 2. the world map opens over the main window, which stays open
---------------------------------------------------------------------------
NS.Dispatch("karte")
local f = NS.MapPageFrame()
assert(AmisiaFrame:IsShown(), "the window shows the map page")
WorldMapFrame:Hide()
assert(NS.MapShowOnWorldMap({ map = 1411, x = 0.5, y = 0.5 }))
assert(WorldMapFrame:IsShown() and AmisiaFrame:IsShown(), "the map opens, the window stays open")
assert(AmisiaFrame:GetFrameStrata() ~= "FULLSCREEN", "the window lies under the map: " .. AmisiaFrame:GetFrameStrata())
WorldMapFrame:Hide()
assert(AmisiaFrame:GetFrameStrata() == "FULLSCREEN", "back on top once the map closes")
NS.ShowMap()
assert(AmisiaFrame:IsShown())
f.open:Click()
assert(WorldMapFrame:IsShown() and AmisiaFrame:IsShown(), "the button on the page too")
WorldMapFrame:Hide()
NS.ShowMap()

---------------------------------------------------------------------------
-- 3. Hier rows: tooltip, click and menu name the row's own place
---------------------------------------------------------------------------
do
    local key
    for _, p in ipairs(NS.BisPlaces()) do if has(p.text, "Geschmolzener Kern") then key = p.key end end
    assert(key, "the place Geschmolzener Kern")
    AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
    NS.ShowGear("here")
    AmisiaDB.settings.bis.place = key
    NS.Refresh()
    local Hh = NS.GearPageFrame().here
    local row
    for _, r in ipairs(Hh.list.rows) do
        if r:IsShown() and r.item and r.item.id == 209 then row = r end
    end
    assert(row and row.map:IsShown() and row.map.key == key, "the Ring row has its place's key")
    local lines = {}
    local addLine = GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
    row.map.scripts.OnEnter(row.map)
    GameTooltip.AddLine = addLine
    local tip = table.concat(lines, "|")
    assert(has(tip, "Geschmolzener Kern") and not has(tip, "Gorn"), "tooltip: this row's place: " .. tip)
    row.map.scripts.OnClick(row.map)
    assert(NS.MapTarget() and NS.MapTarget().key == key, "click: this place")
    NS.MapClearTarget()
    row.scripts.OnClick(row, "RightButton")
    local function menuClick(label)
        for _, b in ipairs(AmisiaMenu.buttons) do
            if b:IsShown() and b.label:GetText() == label then b:Click() return end
        end
        error("no menu entry " .. label)
    end
    menuClick("Wegpunkt setzen")
    assert(NS.MapTarget() and NS.MapTarget().key == key, "menu: this place, not the nearest: " .. tostring(NS.MapTarget() and NS.MapTarget().key))
    NS.MapClearTarget()
    row.scripts.OnClick(row, "RightButton")
    WorldMapFrame:Hide()
    menuClick("Auf der Karte zeigen")
    assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1428, "menu: the map of this place: " .. tostring(WorldMapFrame:GetMapID()))
    WorldMapFrame:Hide()
    AmisiaDB.settings.bis.place = nil
    NS.ShowMap()
end

---------------------------------------------------------------------------
-- 4. item names that arrive late fill the page
---------------------------------------------------------------------------
STUB.items[209].name = nil
NS.Fire("BIS_CHANGED"); STUB.tick(2); NS.Refresh()
assert(has(f.list.rows[1].items:GetText(), "Item 209"), f.list.rows[1].items:GetText())
STUB.items[209].name = "Ring Doppel"
STUB.fire("GET_ITEM_INFO_RECEIVED", 209, true); STUB.tick(3)
assert(has(f.list.rows[1].items:GetText(), "Ring Doppel"), "the name filled in: " .. f.list.rows[1].items:GetText())

---------------------------------------------------------------------------
-- 5. another zone starts at the top
---------------------------------------------------------------------------
do
    local P = NS.MAP.P
    for i = 1, 20 do
        local id = 300 + i
        S[#S + 1] = { "V", "Vendor" .. i, 1411, "", "" }
        P["V:Vendor" .. i] = ("1411:%d:5000"):format(100 + i * 300)
        gear(id, "Item" .. i, "HEAD", 1 + i, { #S })
        me.wish[id] = { t = 1, prio = 2, note = "" }
    end
    -- as many places in Elwynn, so the old offset would still be valid there
    for i = 1, 20 do
        local id = 500 + i
        S[#S + 1] = { "V", "Elwynn" .. i, 1429, "", "" }
        P["V:Elwynn" .. i] = ("1429:%d:4000"):format(100 + i * 300)
        gear(id, "Elwynn Item" .. i, "HEAD", 100 + i, { #S })
        me.wish[id] = { t = 1, prio = 2, note = "" }
    end
    Gear._reset(); Map._reset(); NS.Fire("BIS_CHANGED"); STUB.tick(2); NS.Refresh()
    f.list.scripts.OnMouseWheel(f.list, -10)
    assert(f.list.offset > 0 and #f.list.items > 12, "scrolled down in Durotar")
    f.zone.onPick(1429); NS.Refresh()
    assert(f.list.offset == 0 and f.list.rows[1]:IsShown() and f.list.rows[1].item.key:find("V:Elwynn", 1, true) == 1, "Elwynn at the top: " .. f.list.offset)
    f.zone.onPick("here"); NS.Refresh()
    f.list.scripts.OnMouseWheel(f.list, -10)
    assert(f.list.offset > 0)
    f.zone.onPick(1429); NS.Refresh()
    assert(f.list.offset == 0)
    f.zone.onPick("here"); NS.Refresh()
end

---------------------------------------------------------------------------
-- 6. both switches off
---------------------------------------------------------------------------
f.targets:Click(); f.wishes:Click()
assert(f.empty:IsShown() and f.empty:GetText() == "Ziele und Wünsche sind ausgeblendet. Oben einschalten.", f.empty:GetText())
f.targets:Click()
assert(not has(f.empty:GetText(), "ausgeblendet") or not f.empty:IsShown(), "one switch on: no such text")
f.wishes:Click()
assert(NS.Get("map.pinsTargets") and NS.Get("map.pinsWishes"))

---------------------------------------------------------------------------
-- the arrow menu says how to get the arrow back
---------------------------------------------------------------------------
NS.Set("map.arrow", "on")
assert(NS.MapSetPoint({ map = 1411, x = 0.5, y = 0.5 }, "Test", "V:Gorn One Eye", 201))
local a = _G.AmisiaArrow
assert(a, "the arrow")
a.scripts.OnClick(a, "RightButton")
for _, b in ipairs(AmisiaMenu.buttons) do
    if b:IsShown() and b.label:GetText() == "Pfeil ausblenden" then b:Click() break end
end
assert(NS.Get("map.arrow") == "off", "hidden")
assert(has(lastMsg(), "Pfeil aus. Wieder an: /amisia karte pfeil oder in den Einstellungen."), lastMsg())
NS.MapClearTarget()

---------------------------------------------------------------------------
-- a map rectangle that is not a rectangle projects nothing
---------------------------------------------------------------------------
-- (the client's rectangles are kept per session: one continent for each case)
for id, rect in pairs({ [1801] = { 0.7, 0.5, 0.4, 0.6 }, [1802] = { 0.5, 0.7, 0.6, 0.4 }, [1803] = { 0.5, 0.7, 0.4, 0.6 } }) do
    STUB.maps[id] = { name = "Kontinent " .. id, parent = 947, mapType = 2 }
    STUB.map.rects["1411>" .. id] = rect
end
assert(#Map.PinPlaces(1801) == 0, "no pin from a rectangle with right before left")
assert(#Map.PinPlaces(1802) == 0, "no pin from an upside-down one")
assert(#Map.PinPlaces(1803) > 0, "a proper rectangle still projects")
