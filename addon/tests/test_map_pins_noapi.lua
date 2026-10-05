--[[preload
MapCanvasDataProviderMixin = nil
]]
-- A client without the map canvas's data provider mixin: no pins and no error; the places of a map
-- (for the page) still work.
local Map = NS.Map
STUB.class, STUB.level = "WARRIOR", 70
STUB.item(100, "Lederhose der Wildnis", 2)
NS.GEAR = { game = "tbc", cap = 70, built = "t-noapi", Z = {}, S = { { "V", "Gorn One Eye", 1411, "", "Armorer" } },
    I = { [100] = { "LEGS", 4, 2, 70, 2, 1, 100, 0, 0, 0, 1 } } }
NS.MAP = { game = "tbc", built = "2026-10-05", G = {}, P = { ["V:Gorn One Eye"] = "1411:4720:3310" } }
STUB.maps[1411] = { name = "Durotar", mapType = 3 }
Map._reset()
NS.BisChar().wish[100] = { t = 1, prio = 2, note = "" }
STUB.fire("PLAYER_LOGIN")
assert(Map.PinProvider() == nil and next(WorldMapFrame.dataProviders) == nil, "no provider")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1411)
NS.Fire("BIS_CHANGED")
STUB.tick(1)
assert(#STUB.mapPins("AmisiaMapPinTemplate") == 0, "no pins")
assert(#Map.PinPlaces(1411) == 1, "the places still known")
-- a world map without AddDataProvider: the same
WorldMapFrame.AddDataProvider = nil
_G.MapCanvasDataProviderMixin = {}
STUB.fire("ADDON_LOADED", "Blizzard_WorldMap")
assert(Map.PinProvider() == nil)
