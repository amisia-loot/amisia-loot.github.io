--[[preload
STUB.toc = 16001
_G.GetItemInfo = nil
_G.GetItemInfoInstant = nil
-- the Forever pin mixin: right clicks pass through to the map unless a pin says otherwise, and a
-- click goes through the map's global handlers to OnMouseClickAction
MapCanvasPinMixin.ShouldMouseButtonBePassthrough = function(self, button) return button == "RightButton" end
MapCanvasPinMixin.CheckMouseButtonPassthrough = function(self, ...)
    -- the client's frames have SetPassThroughButtons (restricted in combat); the stub's do not, so a
    -- pin that runs this base version fails the test
    self:SetPassThroughButtons()
    self.passthrough = {}
    for i = 1, select("#", ...) do
        local b = select(i, ...)
        if self:ShouldMouseButtonBePassthrough(b) then self.passthrough[b] = true end
    end
end
MapCanvasPinMixin.OnClick = function(self, ...)
    STUB.globalClickHandlers = (STUB.globalClickHandlers or 0) + 1
    if self.OnMouseClickAction then self:OnMouseClickAction(...) end
end
]]
-- Pins on Forever's world map: the base OnClick stays (the map's own click handlers run first), the
-- click arrives through OnMouseClickAction, right clicks reach the pin for its menu, a click sets
-- the client's waypoint and shift puts the waypoint link into the chat. No GetItemInfo globals.
local Map = NS.Map
local TEMPLATE = "AmisiaMapPinTemplate"
assert(NS.IsForever() and GetItemInfo == nil)
local fh = assert(io.open(ADDON_DIR .. "/MapPin.xml", "rb"))
local xml = fh:read("*a")
fh:close()
STUB.pinTemplates[TEMPLATE] = xml:match('mixin="([^"]+)"')

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

assert(AmisiaMapPinMixin.OnClick == nil, "the mixin keeps the base OnClick until it is filled")
STUB.fire("PLAYER_LOGIN")
assert(Map.PinProvider() and WorldMapFrame.dataProviders[Map.PinProvider()], "added")
assert(AmisiaMapPinMixin.OnClick == MapCanvasPinMixin.OnClick, "the base OnClick with the map's handlers")
assert(AmisiaMapPinMixin.OnMouseClickAction, "the click arrives here")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1411)
local pins = STUB.mapPins(TEMPLATE)
assert(#pins == 1, "one pin: " .. #pins)
local p = pins[1]
assert(p.icon.texture == 4242, "the icon through C_Item")
assert(p.passthrough == nil and AmisiaMapPinMixin.CheckMouseButtonPassthrough ~= MapCanvasPinMixin.CheckMouseButtonPassthrough,
    "no passthrough check: right clicks stay on the pin, the restricted SetPassThroughButtons is never called")
assert(AmisiaMapPinMixin.ShouldMouseButtonBePassthrough(p, "RightButton") == false)

local handlers = STUB.globalClickHandlers or 0
p:OnClick("LeftButton")
assert(STUB.globalClickHandlers == handlers + 1, "the map's handlers ran")
local t = NS.MapTarget()
assert(t and t.ours and STUB.waypoint.point and STUB.waypoint.point.uiMapID == 1411, "the client's waypoint")
NS.MapClearTarget()
STUB.shift = true
p:OnClick("LeftButton")
STUB.shift = false
assert(type(STUB.inserted) == "string" and STUB.inserted:find("|Hworldmap:1411:4720:3310|h", 1, true), tostring(STUB.inserted))
NS.MapClearTarget()
STUB.tick(0.6)
p = STUB.mapPins(TEMPLATE)[1]
p:OnClick("RightButton")
assert(_G.AmisiaMenu and AmisiaMenu:IsShown() and AmisiaMenu.owner == p, "the menu")
