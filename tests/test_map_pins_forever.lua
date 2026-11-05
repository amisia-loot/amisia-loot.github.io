-- Pins on Forever's world map: Amisia's own buttons on its own layer, nothing of the map canvas (no
-- pin mixin, no passthrough buttons, no mouse propagation: the client restricts both in combat).
-- Right clicks stay on the pin for its menu, a click sets the client's waypoint and shift puts the
-- waypoint link into the chat. No GetItemInfo globals.
local Map = NS.Map
assert(NS.MAP and NS.MAP.game == "forever" and GetItemInfo == nil, "the Forever data, no GetItemInfo global")

STUB.class, STUB.level, STUB.faction = "WARRIOR", 60, "Alliance"
STUB.instance = { type = "none" }
STUB.item(100, "Lederhose der Wildnis", 2)
STUB.items[100].icon = 4242
NS.GEAR = { game = "forever", cap = 60, built = "t-pins-fe", Z = {}, S = {
    { "V", "Gorn One Eye", 1411, nil, "Armorer" },
}, I = {
    [100] = { "LEGS", 4, 2, 10, 2, 1, 20, 0, 0, 0, 1 },
} }
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = { ["V:Gorn One Eye"] = "1411:4720:3310" } }
STUB.maps[1411] = { name = "Durotar", mapType = 3, world = { 1, 0, 0, 1000, 1000 } }
STUB.place.map = 1411
STUB.map.pos = { x = 0.1, y = 0.1 }
Map._reset()
NS.BisChar().wish[100] = { t = 1, prio = 3, note = "" }
NS.Fire("BIS_CHANGED")

-- the buttons the addon makes keep the clicks they register for
local create = CreateFrame
CreateFrame = function(kind, ...)
    local f = create(kind, ...)
    if kind == "Button" then f.RegisterForClicks = function(self, ...) self.clicks = table.concat({ ... }, ",") end end
    return f
end
STUB.fire("PLAYER_LOGIN")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1411)
STUB.tick(0)
local pins = Map.ShownPins("item")
assert(#pins == 1, "one pin: " .. #pins)
local p = pins[1]
assert(p.icon.texture == 4242, "the icon through C_Item")
assert(p._kind == "Button" and p.SetPassThroughButtons == nil and p.SetPropagateMouseClicks == nil, "a plain button of Amisia's")
assert(p.scripts.OnClick and p.scripts.OnEnter and p.scripts.OnLeave, "its own scripts")
assert(p.clicks == "LeftButtonUp,RightButtonUp", "right clicks stay on the pin: " .. tostring(p.clicks))
CreateFrame = create

p.scripts.OnClick(p, "LeftButton", false)
local t = NS.MapTarget()
assert(t and t.ours and STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1411, "the client's waypoint")
NS.MapClearTarget()
STUB.shift = true
p.scripts.OnClick(p, "LeftButton", false)
STUB.shift = false
assert(type(STUB.inserted) == "string" and STUB.inserted:find("|Hworldmap:1411:4720:3310|h", 1, true), tostring(STUB.inserted))
NS.MapClearTarget()
STUB.tick(0.6)
p = Map.ShownPins("item")[1]
p.scripts.OnClick(p, "RightButton", false)
assert(_G.AmisiaMenu and AmisiaMenu:IsShown() and AmisiaMenu.owner == p, "the menu")
