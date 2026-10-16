-- Places on the world map (F-105, Gear/MapPlaces.lua): the entrances of the facts by their map keys
-- (one pin for a key two dungeons share), flight masters and docks of the data, the faction filter,
-- the cap with entrances before docks before flight masters, the three switches, the client's own
-- entrances or flight points leave that kind out, the tooltip ("Schiff nach Beutebucht", level,
-- size, "öffnet am"), a click opens the dungeon on the page Dungeons, shift sets the target, the
-- menu's three off entries, the combat hint; the learned entrances (AmisiaDB.entrances): the last
-- place outdoors before the loading screen, not after a summon or too old, at most 60, checked.
local Map = NS.Map
local TEMPLATE = "AmisiaMapPlaceTemplate"
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return math.abs(a - b) < 1e-6 end

---------------------------------------------------------------------------
-- the template
---------------------------------------------------------------------------
local fh = assert(io.open(ADDON_DIR .. "/Gear/MapPin.xml", "rb"))
local xml = fh:read("*a")
fh:close()
local tag = xml:match('<Frame%s[^>]*name="' .. TEMPLATE .. '"[^>]*>')
assert(tag and tag:find('mixin="AmisiaMapPlaceMixin"', 1, true) and tag:find('virtual="true"', 1, true), "the place template")
assert(STUB.pinTemplates[TEMPLATE] == "AmisiaMapPlaceMixin" and type(AmisiaMapPlaceMixin) == "table")
STUB.pinTemplates["AmisiaMapPinTemplate"] = "AmisiaMapPinMixin"

---------------------------------------------------------------------------
-- data: the Barrens with two entrances, Ratchet's ship, flight masters of both factions
---------------------------------------------------------------------------
STUB.class, STUB.level, STUB.faction = "WARRIOR", 20, "Horde"
STUB.instance = { type = "none", name = "Kalimdor", id = 1 }
STUB.maps[1413] = { name = "Brachland", parent = 1414, mapType = 3 }
STUB.maps[1434] = { name = "Schlingendorntal", parent = 1415, mapType = 3 }
STUB.maps[1414] = { name = "Kalimdor", parent = 947, mapType = 2 }
STUB.maps[1415] = { name = "Östliche Königreiche", parent = 947, mapType = 2 }
STUB.maps[947] = { name = "Azeroth", mapType = 1 }
STUB.map.rects["1413>1414"] = { 0.5, 0.7, 0.4, 0.6 }
STUB.areas[35], STUB.areas[392] = "Beutebucht", "Ratschet"
NS.MAP = { game = "forever", built = "t-places", G = {}, P = {
    ["I:43"] = "1413:4769:3498",
    ["I:47"] = "1413:4227:8987",
    ["I:229"] = "1434:4000:5000",
    ["I:249"] = "1413:9000:9000",
    ["N:Hall of Thanes"] = "1413:1000:1000",
}, E = { ["I:43"] = "c", ["N:Hall of Thanes"] = "o" }, F = {
    { 1413, 5150, 3030, "H", "Devrak" },
    { 1413, 6310, 3720, "N", "Bragok" },
    { 1413, 2000, 2000, "A", "Allianzflieger" },
}, T = {
    { 1413, 6370, 3860, "S", "N", { { 35, "Booty Bay" } } },
    { 1413, 6000, 6000, "S", "A", { { 513, "Theramore Isle" } } },
    { 1434, 3140, 2990, "Z", "H", { { 1637, "Orgrimmar" }, { 1497, "Undercity" } } },
} }
Map._reset()
Map._resetPlaces()

local P = Map.Places()
local byKey = {}
for _, e in ipairs(P.entrances) do byKey[e.key] = e end
assert(byKey["I:43"] and byKey["I:43"].facts[1].key == "wc" and not byKey["I:43"].raid and byKey["I:43"].how == "c", "Wailing Caverns")
assert(#byKey["I:229"].facts == 2 and byKey["I:229"].facts[1].key == "lbrs" and byKey["I:229"].facts[2].key == "ubrs",
    "one entrance for both Blackrock Spires")
assert(byKey["I:249"].raid and byKey["I:249"].facts[1].key == "onyxia", "a raid")
assert(byKey["N:Hall of Thanes"] and byKey["N:Hall of Thanes"].how == "o", "a dungeon the facts know by name, approximate")
assert(#P.flights == 3 and #P.docks == 3)
assert(Map.Places() == P, "built once")

-- the faction filter
assert(Map.SideOk("N", "H") and Map.SideOk("H", "H") and not Map.SideOk("A", "H") and Map.SideOk("A", nil))

local function kinds(list)
    local out = {}
    for _, e in ipairs(list) do
        local name = e.kind == "entrance" and e.place.key or e.kind == "flight" and e.place.name or (e.place.to[1].name)
        out[#out + 1] = e.kind .. ":" .. name
    end
    return table.concat(out, ",")
end
local list = Map.PlacePins(1413)
assert(kinds(list) == "entrance:I:43,entrance:N:Hall of Thanes,entrance:I:47,entrance:I:249,dock:Booty Bay,flight:Devrak,flight:Bragok",
    kinds(list))
assert(near(list[1].x, 0.4769) and near(list[1].y, 0.3498) and not list[1].continent)
STUB.faction = "Alliance"
list = Map.PlacePins(1413)
assert(has(kinds(list), "dock:Theramore Isle") and has(kinds(list), "flight:Allianzflieger") and not has(kinds(list), "Devrak"),
    "the Alliance sees its own: " .. kinds(list))
STUB.faction = "Horde"
assert(#Map.PlacePins(1434) == 2, "Stranglethorn: the spire's entrance and the zeppelin tower")
-- the continent: through the zone's rectangle
local cont = Map.PlacePins(1414)
assert(#cont == 7 and cont[1].continent and near(cont[1].x, 0.5 + 0.4769 * 0.2), "Kalimdor")
NS.Set("map.pinsContinent", false)
assert(#Map.PlacePins(1414) == 0)
NS.Set("map.pinsContinent", true)
assert(#Map.PlacePins(947) == 0, "nothing on the world map of all continents")

-- the switches
NS.Set("map.flights", false)
assert(not has(kinds(Map.PlacePins(1413)), "flight:"), "flight masters off")
assert(has(kinds(Map.PlacePins(1413)), "entrance:I:43"), "the entrances stay")
NS.Set("map.flights", true)
NS.Set("map.entrances", false)
assert(not has(kinds(Map.PlacePins(1413)), "entrance:"))
NS.Set("map.entrances", true)
NS.Set("map.transports", false)
assert(not has(kinds(Map.PlacePins(1413)), "dock:"))
NS.Set("map.transports", true)

-- the cap: 60, entrances before docks before flight masters
for i = 1, 70 do NS.MAP.F[#NS.MAP.F + 1] = { 1413, 100 + i * 100, 9500, "H", "Flieger " .. i } end
Map._resetPlaces()
list = Map.PlacePins(1413)
assert(#list == 60 and list[1].kind == "entrance" and list[5].kind == "dock" and list[6].kind == "flight" and list[60].kind == "flight",
    "60 at most: " .. #list)
for i = #NS.MAP.F, 4, -1 do NS.MAP.F[i] = nil end
Map._resetPlaces()

-- the client's own entrances or flight points on a map: that kind is left out
_G.C_TaxiMap = { GetTaxiNodesForMap = function(id) return id == 1413 and { { name = "Crossroads" } } or {} end }
Map._resetPlaces()
assert(has(kinds(Map.PlacePins(1413)), "flight:"), "the function alone: the client's map shows no flight points without its provider")
_G.FlightPointDataProviderMixin = { RefreshAllData = function() end }
local clientProvider = CreateFromMixins(_G.FlightPointDataProviderMixin)
WorldMapFrame.dataProviders[clientProvider] = true
Map._resetPlaces()
assert(not has(kinds(Map.PlacePins(1413)), "flight:") and has(kinds(Map.PlacePins(1413)), "entrance:"), "no doubled flight points")
local shows, count, provider = Map.ClientPlaces("flight", 1413)
assert(shows and count == 1 and provider and select(2, Map.ClientPlaces("entrance", 1413)) == nil)
WorldMapFrame.dataProviders[clientProvider] = nil
_G.C_TaxiMap, _G.FlightPointDataProviderMixin = nil, nil
Map._resetPlaces()

---------------------------------------------------------------------------
-- pins on the shown map
---------------------------------------------------------------------------
STUB.fire("PLAYER_LOGIN")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1413)
local pins = STUB.mapPins(TEMPLATE)
assert(#pins == 7, "seven place pins: " .. #pins)
local function pinOf(kind, name)
    for _, p in ipairs(STUB.mapPins(TEMPLATE)) do
        local e = p.entry
        if e and e.kind == kind and (e.kind == "entrance" and e.place.key == name or e.place.name == name
            or e.kind == "dock" and e.place.to[1].name == name) then return p end
    end
end
local wc = pinOf("entrance", "I:43")
assert(wc and near(wc.normalizedX, 0.4769) and wc.icon.atlas == "Dungeon", "the dungeon mark")
assert(pinOf("entrance", "I:249").icon.atlas == "Raid", "the raid mark")
assert(pinOf("flight", "Devrak").icon.texture == "Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
NS.Set("map.flights", false)
STUB.tick(0.6)
assert(not pinOf("flight", "Devrak") and pinOf("entrance", "I:43"), "switched off: gone from the map")
NS.Set("map.flights", true)
STUB.tick(0.6)
assert(pinOf("flight", "Devrak"))

-- tooltips
local lines = {}
local addLine = GameTooltip.AddLine
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
pinOf("dock", "Booty Bay"):OnMouseEnter()
assert(lines[1] == "Schiff nach Beutebucht" and has(table.concat(lines, "|"), "beide Fraktionen"), table.concat(lines, "|"))
lines = {}
pinOf("entrance", "I:249"):OnMouseEnter()
local tip = table.concat(lines, "|")
assert(has(tip, "Onyxia's Lair") and has(tip, "Raid · ") and has(tip, "40 Spieler") and has(tip, "öffnet am 09.12."), tip)
assert(has(tip, "Brachland 90, 90") and has(tip, "Klick: in Amisia öffnen. Shift-Klick: Ziel setzen."), tip)
lines = {}
pinOf("entrance", "N:Hall of Thanes"):OnMouseEnter()
assert(has(table.concat(lines, "|"), "Ort ungefähr") and has(table.concat(lines, "|"), "5 Spieler"), table.concat(lines, "|"))
lines = {}
pinOf("flight", "Bragok"):OnMouseEnter()
assert(lines[1] == "Bragok" and lines[2] == "Flugmeister · beide Fraktionen", table.concat(lines, "|"))
GameTooltip.AddLine = addLine

-- a click opens the dungeon on the page Dungeons; the world map stays in front
wc = pinOf("entrance", "I:43")
wc:OnClick("LeftButton")
assert(AmisiaDB.settings.bis.dungeon == "wc" and AmisiaFrame:IsShown(), "the page Dungeons with Wailing Caverns")
assert(WorldMapFrame:IsShown(), "the world map stays open")
assert(AmisiaFrame:GetFrameStrata() ~= "FULLSCREEN", "the window under the map (F-011)")
-- a raid below the level cap: chosen all the same
pinOf("entrance", "I:249"):OnClick("LeftButton")
assert(AmisiaDB.settings.bis.dungeon == "onyxia")
-- shift: the target to this entrance
STUB.shift = true
pinOf("entrance", "I:43"):OnClick("LeftButton")
STUB.shift = false
local t = NS.MapTarget()
assert(t and t.key == "I:43" and near(t.x, 0.4769) and has(t.label, "(Eingang)"), "shift: the target")
NS.MapClearTarget()
-- a flight master: the target
pinOf("flight", "Devrak"):OnClick("LeftButton")
assert(NS.MapTarget() and NS.MapTarget().label == "Devrak")
NS.MapClearTarget()
STUB.tick(0.6)

-- in combat, when the window does not come up: a line in the chat
local show = NS.ShowDungeon
NS.ShowDungeon = function() return false end
STUB.combat = true
local before = #STUB.messages
assert(Map.OpenDungeon("wc") == false)
assert(#STUB.messages == before + 1 and has(STUB.messages[#STUB.messages], "Im Kampf öffnet Amisia das Fenster nicht"))
STUB.combat = false
NS.ShowDungeon = show

-- the menu: open, target, the three off entries
WorldMapFrame:SetMapID(1434)
pinOf("entrance", "I:229"):OnClick("RightButton")
local labels = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
assert(table.concat(labels, ",") == "In Amisia öffnen: Lower Blackrock Spire,In Amisia öffnen: Upper Blackrock Spire,Ziel setzen,"
    .. "Eingänge ausblenden,Flugmeister ausblenden,Zeppeline und Schiffe ausblenden", table.concat(labels, ","))
AmisiaMenu:Hide()
WorldMapFrame:SetMapID(1413)
pinOf("dock", "Booty Bay"):OnClick("RightButton")
AmisiaMenu.buttons[4]:Click()
assert(NS.Get("map.transports") == false, "off from the menu")
STUB.tick(0.6)
assert(not pinOf("dock", "Booty Bay"))
NS.Set("map.transports", true)
STUB.tick(0.6)

---------------------------------------------------------------------------
-- learned entrances
---------------------------------------------------------------------------
assert(type(AmisiaDB.entrances) == "table" and AmisiaDB.entrances.v == 1 and next(AmisiaDB.entrances.list) == nil)
STUB.place.map = 1413
STUB.map.pos = { x = 0.4612, y = 0.3567 }
assert(Map.SamplePlace().x == 4612)
STUB.tick(5)
STUB.instance = { type = "party", name = "Die Höhlen des Wehklagens", id = 43 }
STUB.map.pos = nil
STUB.fire("PLAYER_ENTERING_WORLD")
local r = AmisiaDB.entrances.list[43]
assert(r and r.m == 1413 and r.x == 4612 and r.y == 3567 and r.k == "party" and r.n == "Die Höhlen des Wehklagens" and r.t > 0, "learned")
-- too old: nothing
STUB.instance = { type = "none", id = 1 }
STUB.map.pos = { x = 0.1, y = 0.1 }
Map.SamplePlace()
STUB.map.pos = nil   -- no place for the ticker (a loading screen that takes long)
STUB.tick(25)
STUB.instance = { type = "party", name = "Kral", id = 47 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(AmisiaDB.entrances.list[47] == nil, "the last place was too old")
-- a summon in between: nothing
STUB.instance = { type = "none", id = 1 }
Map.SamplePlace()
STUB.fire("CONFIRM_SUMMON")
STUB.instance = { type = "party", name = "Kral", id = 47 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(AmisiaDB.entrances.list[47] == nil, "summoned: no entrance")
STUB.tick(130)
-- a battleground is no dungeon
STUB.instance = { type = "none", id = 1 }
Map.SamplePlace()
STUB.instance = { type = "pvp", name = "Warsong", id = 489 }
STUB.fire("PLAYER_ENTERING_WORLD")
assert(AmisiaDB.entrances.list[489] == nil)
STUB.instance = { type = "none", id = 1 }

-- the check on load: bad entries dropped, codes out of the name, 60 at most (the newest)
local list2 = { [5] = { m = 1, x = 10001, y = 1, t = 5 }, ["x"] = { m = 1, x = 1, y = 1, t = 5 },
    [6] = { m = 1, x = 1, y = 1, t = 5, n = "|cffff0000Böse|r", k = "pvp" } }
for i = 1, 70 do list2[1000 + i] = { m = 1413, x = i, y = i, t = 100 + i } end
AmisiaDB.entrances = { v = 1, list = list2, junk = true }
NS.EntrancesLoaded(AmisiaDB)
local n = 0
for _ in pairs(AmisiaDB.entrances.list) do n = n + 1 end
assert(n == 60 and AmisiaDB.entrances.list[1070] and not AmisiaDB.entrances.list[1010] and AmisiaDB.entrances.list[1011], "the 60 newest")
assert(AmisiaDB.entrances.list[5] == nil and AmisiaDB.entrances.list.x == nil and AmisiaDB.entrances.junk == nil)
local once = NS.EntrancesLoaded(AmisiaDB)
local m = 0
for _ in pairs(once.list) do m = m + 1 end
assert(m == 60, "twice changes nothing")
AmisiaDB.entrances = { list = { [6] = { m = 1, x = 1, y = 1, t = 5, n = "|cffff0000Böse|r", k = "pvp" } } }
NS.EntrancesLoaded(AmisiaDB)
assert(AmisiaDB.entrances.list[6].n == "Böse" and AmisiaDB.entrances.list[6].k == nil, AmisiaDB.entrances.list[6].n)
AmisiaDB.entrances = "kaputt"
NS.EntrancesLoaded(AmisiaDB)
assert(type(AmisiaDB.entrances.list) == "table")
