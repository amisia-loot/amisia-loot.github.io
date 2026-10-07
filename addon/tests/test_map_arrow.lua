--[[preload
C_Map.SetUserWaypoint = nil
C_Map.ClearUserWaypoint = nil
C_Map.GetUserWaypoint = nil
C_Map.HasUserWaypoint = nil
C_Map.CanSetUserWaypointOnMap = nil
C_Map.GetUserWaypointPositionForMap = nil
C_Map.GetUserWaypointHyperlink = nil
UiMapPoint = nil
C_SuperTrack = nil
]]
-- Amisia's own arrow on a client without the user waypoint functions (the preload takes them away;
-- Map.ClientWaypoints checks their types): shown with a target, outside instances and while the
-- position is readable; turned by the player's facing, or the direction in words where the client
-- cannot turn it; the distance; another continent; the tick at most ten times a second; arriving;
-- the setting map.arrow; the menu, the tooltip, dragging and the saved position; the target after
-- /reload; Latin-1 only. The arrow next to a refused waypoint is in test_map_waypoint.lua.
local Map = NS.Map
assert(not Map.ClientWaypoints(), "no user waypoint functions")
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end

STUB.instance = { type = "none" }
STUB.item(100, "Lederhose der Wildnis", 2)
NS.GEAR = { game = "forever", cap = 60, built = "t-arrow", Z = {}, S = {
    { "V", "Gorn One Eye", 1411, nil, "Armorer" },
}, I = {
    [100] = { "LEGS", 4, 2, 10, 2, 1, 20, 0, 0, 0, 1 },
} }
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = { ["V:Gorn One Eye"] = "1411:4720:3310" } }
STUB.maps[1411] = { name = "Durotar", world = { 1, 0, 0, 1000, 1000 } }
STUB.maps[1429] = { name = "Wald von Elwynn", world = { 0, 0, 0, 1000, 1000 } }
STUB.place.map = 1411
STUB.map.pos = { x = 0.1, y = 0.1 }
STUB.facing = 0
Map._reset()

-- no target, no arrow (and no tick)
assert(_G.AmisiaArrow == nil or not AmisiaArrow:IsShown(), "no arrow without a target")

assert(NS.MapSetTarget(100))
local t = NS.MapTarget()
assert(t and t.ours == false, "no waypoint functions: Amisia's own target")
local a = _G.AmisiaArrow
assert(a and a:IsShown(), "the arrow shows with a target")
assert(a.icon and a.icon.texture == "Interface\\AddOns\\Amisia\\Media\\Icons\\arrow", tostring(a.icon and a.icon.texture))
assert(a.strata == "MEDIUM" and a._w == 96 and a._h == 84, "96 x 84, MEDIUM")
local p = a.points and a.points.TOP
assert(p and p.y == -120 and p.x == 0, "top middle at y -120 to start")
assert(a.label:GetText() == "Gorn One Eye", a.label:GetText())

-- the first tick: distance and turn (east 372, south 231 yards: bearing about 121.8 degrees)
local bearing = math.atan2(372, -231)
a.scripts.OnUpdate(a, 0.1)
assert(a.dist:GetText() == "438 m", tostring(a.dist:GetText()))
assert(a.icon:IsShown() and near(a.icon.rotation, -bearing), "turned towards the target: " .. tostring(a.icon.rotation))
STUB.facing = 1
a.scripts.OnUpdate(a, 0.1)
assert(near(a.icon.rotation, -(bearing + 1)), "facing taken off")

-- at most ten times a second
STUB.map.pos = { x = 0.2, y = 0.1 }
a.scripts.OnUpdate(a, 0.05)
assert(a.dist:GetText() == "438 m", "not yet")
a.scripts.OnUpdate(a, 0.05)
assert(a.dist:GetText() ~= "438 m", "after 0.1 s")

-- where the client cannot turn it: the direction in words after the map's north
STUB.map.pos = { x = 0.1, y = 0.1 }
local facing = _G.GetPlayerFacing
_G.GetPlayerFacing = nil
a.scripts.OnUpdate(a, 0.1)
assert(not a.icon:IsShown() and a.dist:GetText() == "438 m Südost", tostring(a.dist:GetText()))
_G.GetPlayerFacing = facing
STUB.facing = nil
a.scripts.OnUpdate(a, 0.1)
assert(not a.icon:IsShown() and a.dist:GetText() == "438 m Südost", "facing unknown: words")
STUB.facing = 0
local turn = a.icon.SetRotation
a.icon.SetRotation = nil
a.scripts.OnUpdate(a, 0.1)
assert(not a.icon:IsShown() and a.dist:GetText() == "438 m Südost", "a texture without SetRotation: words")
a.icon.SetRotation = turn
a.scripts.OnUpdate(a, 0.1)
assert(a.icon:IsShown() and a.dist:GetText() == "438 m", "turning again")
-- the eight directions
local words = {}
for _, pos in ipairs({ { 0.472, 0.9 }, { 0.1, 0.7 }, { 0.1, 0.331 }, { 0.1, 0.1 }, { 0.472, 0.1 }, { 0.9, 0.1 }, { 0.9, 0.331 }, { 0.9, 0.7 } }) do
    STUB.map.pos = { x = pos[1], y = pos[2] }
    words[#words + 1] = Map.DirectionWord(Map.Bearing(t))
end
assert(table.concat(words, ",") == "Nord,Nordost,Ost,Südost,Süd,Südwest,West,Nordwest", table.concat(words, ","))
STUB.map.pos = { x = 0.1, y = 0.1 }

-- another continent: no arrow texture, a grey line
STUB.place.map = 1429
a.scripts.OnUpdate(a, 0.1)
assert(a:IsShown() and not a.icon:IsShown() and a.dist:GetText() == "Anderer Kontinent", tostring(a.dist:GetText()))
STUB.place.map = 1411

-- in an instance: no arrow; outside again it comes back
STUB.instance = { type = "party" }
STUB.fire("PLAYER_ENTERING_WORLD", false, false)
assert(not a:IsShown(), "no arrow in an instance")
STUB.instance = { type = "none" }
STUB.fire("PLAYER_ENTERING_WORLD", false, false)
assert(a:IsShown(), "back outside")
-- no readable position: hidden, the target stays
STUB.map.pos = nil
local unitPos = _G.UnitPosition
_G.UnitPosition = nil
a.scripts.OnUpdate(a, 0.1)
assert(not a:IsShown() and NS.MapTarget(), "no position: arrow off, target kept")
_G.UnitPosition = unitPos
STUB.map.pos = { x = 0.1, y = 0.1 }
STUB.fire("ZONE_CHANGED_NEW_AREA")
assert(a:IsShown())

-- the setting: off, on, auto (without the client's waypoint: on)
NS.Set("map.arrow", "off")
assert(not a:IsShown(), "off")
NS.Set("map.arrow", "on")
assert(a:IsShown(), "on")
NS.Set("map.arrow", "auto")
assert(a:IsShown(), "auto shows it where the client has no own guide")

-- the tooltip: source and item
local lines = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
a.scripts.OnEnter(a)
GameTooltip.AddLine = addLine
local tip = table.concat(lines, "|")
assert(has(tip, "Gorn One Eye") and has(tip, "Lederhose der Wildnis") and has(tip, "Durotar 47, 33"), tip)

-- the menu: clear, show on the world map, hide the arrow
a.scripts.OnClick(a, "RightButton")
local menu = _G.AmisiaMenu
assert(menu and menu:IsShown() and menu.owner == a, "right click opens the menu")
local labels = {}
for i, b in ipairs(menu.buttons) do
    if b:IsShown() then labels[#labels + 1] = b.label:GetText() end
end
assert(table.concat(labels, ",") == "Ziel löschen,Auf der Weltkarte zeigen,Pfeil ausblenden", table.concat(labels, ","))
WorldMapFrame:Hide()
menu.buttons[2]:Click()
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1411, "the world map on the target's zone")
WorldMapFrame:Hide()
a.scripts.OnClick(a, "RightButton")
menu.buttons[3]:Click()
assert(NS.Get("map.arrow") == "off" and not a:IsShown(), "arrow hidden by the menu")
NS.Dispatch("karte pfeil")
assert(NS.Get("map.arrow") == "auto" and a:IsShown(), "and back by the command")
a.scripts.OnClick(a, "RightButton")
menu.buttons[1]:Click()
assert(NS.MapTarget() == nil and not a:IsShown(), "target cleared by the menu")
a.scripts.OnClick(a, "LeftButton")

-- dragging: the position is kept in the settings and can be reset
assert(NS.MapSetTarget(100))
a.scripts.OnDragStart(a)
a._point, a._x, a._y = "CENTER", 210, -55
a.scripts.OnDragStop(a)
local pos = AmisiaDB.settings.map.arrowPos
assert(type(pos) == "table" and pos[1] == "CENTER" and pos[3] == 210 and pos[4] == -55, "position saved")
NS.SettingItem("map.resetArrow").run()
assert(AmisiaDB.settings.map.arrowPos == nil and a.points.TOP and a.points.TOP.y == -120, "reset to the start")

-- arriving: the line, the target goes (map.autoClear); without it "Angekommen" in green
STUB.map.pos = { x = 0.472, y = 0.341 }
a.scripts.OnUpdate(a, 0.1)
assert(has(lastMsg(), "Ziel erreicht (Gorn One Eye)."), lastMsg())
assert(NS.MapTarget() == nil and not a:IsShown(), "cleared on arrival")
NS.Set("map.autoClear", false)
STUB.map.pos = { x = 0.1, y = 0.1 }
assert(NS.MapSetTarget(100))
STUB.map.pos = { x = 0.472, y = 0.341 }
a.scripts.OnUpdate(a, 0.1)
assert(NS.MapTarget() and a:IsShown() and a.dist:GetText() == "Angekommen", tostring(a.dist:GetText()))
NS.Set("map.autoClear", true)
NS.MapClearTarget()
STUB.map.pos = { x = 0.1, y = 0.1 }

-- after /reload the target and the arrow come back
assert(NS.MapSetTarget(100))
local fh = assert(io.open(ADDON_DIR .. "/Gear/Map.lua", "rb"))
local src = fh:read("*a")
fh:close()
assert(loadstring(src, "@Map.lua"))("Amisia", NS)
STUB.fire("ADDON_LOADED", "Amisia")
STUB.fire("PLAYER_ENTERING_WORLD", false, true)
assert(NS.MapTarget() and _G.AmisiaArrow:IsShown(), "target and arrow after /reload")
a = _G.AmisiaArrow
a.scripts.OnUpdate(a, 0.1)
assert(a.dist:GetText() == "438 m")

-- Latin-1 only, no arrow characters in the texts
for _, m in ipairs(STUB.messages) do
    for c in m:gmatch("[\196-\255][\128-\191]") do error("character above Latin-1 in chat: " .. m) end
end
for c in src:gmatch("[\196-\255][\128-\191]") do error("Map.lua: character above Latin-1: " .. c) end
assert(not src:find("->\"", 1, true) and not src:find("<-", 1, true), "no arrows made of characters")
