-- A world map without the canvas Amisia's layer hangs on (no ScrollContainer.Child): no pins and no
-- error; the places of a map (for the page) still work.
local Map = NS.Map
STUB.class, STUB.level = "WARRIOR", 60
STUB.item(100, "Lederhose der Wildnis", 2)
NS.GEAR = { game = "forever", cap = 60, built = "t-noapi", Z = {}, S = { { "V", "Gorn One Eye", 1411, "", "Armorer" } },
    I = { [100] = { "LEGS", 4, 2, 60, 2, 1, 60, 0, 0, 0, 1 } } }
NS.MAP = { game = "forever", built = "2026-10-05", G = {}, P = { ["V:Gorn One Eye"] = "1411:4720:3310" } }
STUB.maps[1411] = { name = "Durotar", mapType = 3 }
Map._reset()
NS.BisChar().wish[100] = { t = 1, prio = 2, note = "" }
local scroll = WorldMapFrame.ScrollContainer
WorldMapFrame.ScrollContainer = nil
STUB.fire("PLAYER_LOGIN")
assert(Map.PinLayer() == nil, "no layer")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1411)
NS.Fire("BIS_CHANGED")
STUB.tick(1)
assert(#Map.ShownPins("item") == 0 and #Map.ShownPins("place") == 0, "no pins")
assert(#Map.PinPlaces(1411) == 1, "the places still known")
-- the map comes later (load on demand): the layer then
WorldMapFrame.ScrollContainer = scroll
STUB.fire("PLAYER_ENTERING_WORLD")
assert(Map.PinLayer() and Map.PinLayer():GetParent() == STUB.mapCanvas, "made once the canvas is there")
STUB.tick(0)
assert(#Map.ShownPins("item") == 1, "then the pin")
WorldMapFrame:Hide()
