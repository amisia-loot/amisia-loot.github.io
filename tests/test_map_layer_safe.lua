-- Amisia stays out of the world map's secure code (the game's "tainted by 'Amisia'" errors after the
-- map's data provider refresh, 2026-11-05): no addon file adds a data provider, takes or releases a
-- pin of the canvas, refreshes the map's providers, writes into WorldMapFrame, its scroll container
-- or canvas or a client mixin, or replaces a script of the map. In the stub such a write or call from
-- an addon file raises (wow_stub.lua); this test checks the guard itself, the source of every addon
-- file, and a whole round of pins on the map with nothing written.
local Map = NS.Map

-- the guard: a write or call from an addon file raises, the same from a test does not
local function asAddon(code) return assert(loadstring(code, "@Gear/Fake.lua")) end
assert(not pcall(asAddon("WorldMapFrame.amisia = 1")), "a write into the map from an addon file raises")
assert(not pcall(asAddon("WorldMapFrame.ScrollContainer.Child.amisia = 1")), "the canvas too")
assert(not pcall(asAddon("WorldMapFrame:AddDataProvider(CreateFromMixins(MapCanvasDataProviderMixin))")), "a data provider")
assert(not pcall(asAddon("WorldMapFrame:AcquirePin('X')")), "a pin of the canvas")
assert(not pcall(asAddon("WorldMapFrame:RefreshAllDataProviders()")), "the map's refresh")
assert(#STUB.mapWrites == 2, "the two writes refused: " .. table.concat(STUB.mapWrites, ", "))
STUB.mapWrites = {}
assert(pcall(asAddon("hooksecurefunc(WorldMapFrame, 'GetMapID', function() end)")), "a secure hook is allowed")
assert(not pcall(asAddon("OpenWorldMap(1411)")), "the client's Lua function that opens the map (D-64)")
assert(not pcall(asAddon("ToggleWorldMap()")), "the one that toggles it")
assert(not pcall(asAddon("WorldMapFrame:SetMapID(1411)")), "the map's SetMapID")
WorldMapFrame:Hide()
local opens = STUB.mapOpens
assert(pcall(asAddon("C_Map.OpenWorldMap(1411)")) and STUB.mapOpens == opens + 1, "C_Map.OpenWorldMap is allowed")
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == 1411, "the client's handler opens the map on it")
WorldMapFrame:Hide()
WorldMapFrame.testField = true
assert(getmetatable(WorldMapFrame).real.testField == true, "a test writes freely")
WorldMapFrame.testField = nil

-- the source of every addon file
local function read(name)
    local fh = assert(io.open(ADDON_DIR .. "/" .. name, "rb"))
    local src = fh:read("*a")
    fh:close()
    return src
end
local files = {}
for line in read("Amisia.toc"):gmatch("[^\r\n]+") do
    local name = line:gsub("%s*%[[^%]]*%]", ""):gsub("\\", "/")
    if name ~= "" and not name:find("^#") then files[#files + 1] = name end
end
assert(#files > 50, "the TOC's files")
local FORBIDDEN = {
    { "AddDataProvider", "adds a data provider to the map" },
    { "RemoveDataProvider", "removes a data provider" },
    { "AcquirePin", "takes a pin of the canvas" },
    { "RemoveAllPinsByTemplate", "releases pins of the canvas" },
    { "RefreshAllDataProviders", "refreshes the map's providers" },
    { "WorldMapFrame%.[%w_%.]+%s*=[^=]", "writes into the world map" },
    { "ScrollContainer%.[%w_%.]+%s*=[^=]", "writes into the map's scroll container" },
    { "WorldMapFrame:SetScript", "replaces a script of the map" },
    { "%f[%w_][A-Z][%w_]*Mixin%.[%w_]+%s*=[^=]", "writes into a client mixin" },
    { "CreateFromMixins%(MapCanvas", "builds on the canvas's mixins" },
    { "[^%.]OpenWorldMap%s*%(", "opens the map with the client's Lua function (only C_Map.OpenWorldMap, D-64)" },
    { "ToggleWorldMap%s*%(", "toggles the map with the client's Lua function (D-64)" },
    { ":SetMapID%s*%(", "sets the map's map (D-64)" },
}
for _, name in ipairs(files) do
    if name:find("%.lua$") and not name:find("^Data/") then
        local src = read(name)
        for _, f in ipairs(FORBIDDEN) do
            local at = src:find(f[1])
            assert(not at, ("%s %s (%s)"):format(name, f[2], src:sub(at or 1, (at or 1) + 60)))
        end
    end
end

-- a whole round: pins on the map, maps changed, zoomed, a setting, a click, the map closed
STUB.class, STUB.level, STUB.faction = "WARRIOR", 20, "Horde"
STUB.instance = { type = "none", name = "Kalimdor", id = 1 }
STUB.maps[1413] = { name = "Brachland", parent = 1414, mapType = 3 }
STUB.maps[1414] = { name = "Kalimdor", parent = 947, mapType = 2 }
STUB.map.rects["1413>1414"] = { 0.5, 0.7, 0.4, 0.6 }
NS.MAP = { game = "forever", built = "t-safe", G = {}, P = { ["I:43"] = "1413:4769:3498" },
    F = { { 1413, 5150, 3030, "H", "Devrak" } }, T = {} }
Map._reset()
Map._resetPlaces()
STUB.fire("PLAYER_LOGIN")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1413)
STUB.tick(0)
local pins = Map.ShownPins("place")
assert(#pins == 2, "two place pins: " .. #pins)
WorldMapFrame:SetMapID(1414)
STUB.tick(0)
assert(#Map.ShownPins("place") == 2 and Map.ShownPins("place")[1]:GetScale() < 1, "on the continent, smaller")
STUB.mapCanvas:SetScale(3)
STUB.tick(0)
NS.Set("map.flights", false)
STUB.tick(0.6)
assert(#Map.ShownPins("place") == 1, "flight masters off")
local p = Map.ShownPins("place")[1]
STUB.shift = true
p.scripts.OnClick(p, "LeftButton", false)
STUB.shift = false
assert(NS.MapTarget() and NS.MapTarget().key == "I:43", "shift-click: the target")
STUB.tick(0.6)
-- closed: no frame runs, nothing is redrawn
local redraws = Map.PinRefreshes()
WorldMapFrame:Hide()
NS.MapClearTarget()
NS.Set("map.flights", true)
STUB.tick(2)
assert(Map.PinRefreshes() == redraws, "no work while the map is closed")
STUB.mapCanvas:SetScale(1)

assert(#STUB.mapWrites == 0, "nothing written into the map: " .. table.concat(STUB.mapWrites, ", "))
assert(next(WorldMapFrame.dataProviders) == nil, "no data provider")
for name, copy in pairs(STUB.mixinCopy) do
    for k, v in pairs(_G[name]) do assert(copy[k] == v, name .. "." .. tostring(k) .. " changed") end
    for k in pairs(copy) do assert(_G[name][k] ~= nil, name .. "." .. tostring(k) .. " removed") end
end
