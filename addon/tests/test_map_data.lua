-- Map.lua's data side: the generated map data (MapData.lua), one key per source (ns.MapKeyOf),
-- points parsed once (broken parts and maps the client does not know skipped), the places of an
-- item with the page's filters and the wish fallback, the nearest point, the "Fundort" line, the
-- settings section and the move of AmisiaDB.map.
local Gear, Map = NS.Gear, NS.Map
assert(Map and NS.MapKeyOf and NS.MapPoints and NS.MapItemPlaces and NS.MapNearest and NS.MapMigrate, "Map.lua loaded")
local function near(a, b) return math.abs(a - b) < 1e-9 end

-- the generated data: MapData.lua (the TOC's load condition is its only lock), every point well
-- formed, most sources of the gear data found
assert(NS.MAP and NS.MAP.game == "forever", "MapData.lua loads: " .. tostring(NS.MAP and NS.MAP.game))
local n = 0
for key, text in pairs(NS.MAP.P) do
    n = n + 1
    assert(key:match("^[QVRWUIN]:.+$"), "key " .. key)
    for part in text:gmatch("%S+") do
        local m, x, y = part:match("^(%d+):(%d+):(%d+)$")
        assert(m and tonumber(x) <= 10000 and tonumber(y) <= 10000, key .. ": " .. part)
    end
end
assert(n > 300, "the Forever places: " .. n)
local found, total = 0, 0
for _, rec in ipairs(NS.GEAR.S) do
    local k = NS.MapKeyOf(rec)
    if k then
        total = total + 1
        if NS.MAP.P[k] then found = found + 1 end
    end
end
-- 85 %: the open data has no measured entrance for the new Forever dungeons yet (Hall of Thanes,
-- Ruins of Lordaeron: only the middle of their zone, which build_map.py does not take)
assert(total > 100 and found / total > 0.85, ("sources with a place: %d of %d"):format(found, total))
assert(NS.MAP.P["N:The Deadmines"], "the dungeon entrances")
local givers = 0
for key in pairs(NS.MAP.G) do
    assert(key:sub(1, 2) == "Q:" and NS.MAP.P[key], "a giver only for a quest with a place: " .. key)
    givers = givers + 1
end
assert(givers > 100, "quest givers: " .. givers)

-- the file again by hand: no guard, it loads into any namespace
local function readFile(name)
    local fh = assert(io.open(ADDON_DIR .. "/" .. name, "rb"))
    local src = fh:read("*a")
    fh:close()
    return src
end
local src = readFile("MapData.lua")
assert(not src:find("IsForever", 1, true) and not src:find("then return end", 1, true), "no guard line")
local fns = {}
assert(loadstring(src, "@MapData.lua"))("Amisia", fns)
assert(fns.MAP and fns.MAP.game == "forever" and fns.MAP.P["N:The Deadmines"], "the data with its dungeon entrances")

---------------------------------------------------------------------------
-- keys per source kind
---------------------------------------------------------------------------
local K = NS.MapKeyOf
local gear = NS.GEAR
NS.GEAR = { game = "forever", S = {}, I = {}, Z = {} }   -- data with instance ids in dungeon records
assert(K({ "Q", "x", 1, 1, "A", 1429, 7, 0 }) == "Q:7")
assert(K({ "Q", "x", 1, 1, nil, nil, nil, 0, "Dungeon" }) == nil, "a quest without id has no place")
assert(K({ "V", "Gorn One Eye", 1448 }) == "V:Gorn One Eye")
assert(K({ "V", "Gorn One Eye", 1448, "H", "Armorer", nil, 101 }) == "U:101", "the NPC id wins")
assert(K({ "P", "Gorn One Eye", 1448, "H", "Armorer", nil, 101 }) == "U:101")
assert(K({ "P", "Sergeant", 1453 }) == "V:Sergeant", "PvP vendors share the vendor key")
assert(K({ "V", "Händlerin", 1453, "", "Rüstungen", 4 }) == "V:Händlerin", "the phase field is no NPC id")
assert(K({ "R", "Muad", 10, 1420 }) == "R:Muad" and K({ "R", "Muad", 10, 1420, 103 }) == "U:103")
assert(K({ "W", "Trash (The Deadmines)", 18, 19 }) == "N:The Deadmines", "trash: the dungeon's entrance")
assert(K({ "W", "Twin", 10, 10, 1411 }) == "W:Twin" and K({ "W", "Twin", 10, 10, nil, 111 }) == "U:111")
assert(K({ "W", "Twin", 10, 10 }) == nil, "a named mob without zone")
assert(K({ "W", nil, 50, 60, 0 }) == nil, "a world drop")
assert(K({ "X", "Molten Core", "Ragnaros", 409, 2717, 0, 0 }) == "I:409")
assert(K({ "D", "The Deadmines", "Cookie", nil, 36, 1581 }) == "I:36")
assert(K({ "D", "Deadmines", "Cookie", nil, 0, 0 }) == "N:Deadmines", "no instance id: by name")
assert(K({ "F", "Thrallmar", 5, 947, "H" }) == nil, "no reputation sources: no key")
assert(K({ "C", "tailoring", 50 }) == nil and K({ "A" }) == nil and K(nil) == nil)
-- data built before the game field holds a zone in a dungeon record: by name
NS.GEAR = { S = {}, I = {}, Z = {} }
assert(K({ "D", "Deadmines", "Cookie", nil, 291 }) == "N:Deadmines")
NS.GEAR = gear

---------------------------------------------------------------------------
-- points: parsed once, broken parts and unknown maps skipped
---------------------------------------------------------------------------
STUB.maps[1453] = { name = "Sturmwind" }
STUB.maps[1454] = { name = "Nirgendwo" }
NS.MAP = { game = "forever", built = "2026-10-05", G = {},
    P = { ["V:A"] = "1453:5097:4170 junk 1453:x:1 1454:10000:0 99999:5000:5000 1453:20000:5", ["V:B"] = "" } }
Map._reset()
local pts = NS.MapPoints("V:A")
assert(#pts == 2, "two good points: " .. #pts)
assert(pts[1].map == 1453 and near(pts[1].x, 0.5097) and near(pts[1].y, 0.417) and pts[2].map == 1454 and pts[2].x == 1 and pts[2].y == 0)
assert(NS.MapPoints("V:A") == pts, "parsed once and kept")
assert(#NS.MapPoints("V:B") == 0 and #NS.MapPoints("Q:1") == 0)
assert(Map.UnknownMaps()[99999], "the unknown map is noted for the session")

---------------------------------------------------------------------------
-- the places of an item: the page's filters, the faction, the wish fallback
---------------------------------------------------------------------------
STUB.maps[1440] = { name = "Eschental" }
STUB.maps[1428] = { name = "Brennende Steppe" }
STUB.areas[2717] = "Geschmolzener Kern"
NS.GEAR = { game = "forever", cap = 60, built = "t-map", Z = {}, S = {
    { "V", "Alpha", 1453, "A", "Vendor" },
    { "V", "Horde Guy", 1453, "H", "Vendor" },
    { "Q", "Hordeauftrag", 58, 55, "H", 1440, 77, 0 },
    { "X", "Molten Core", "Ragnaros", 409, 2717, 0, 0 },
    { "C", "tailoring", 300 },
    { "W", nil, 50, 60, 0 },
    { "V", "Alpha", 1453, "A", "Other title" },
}, I = {
    [100] = { "HEAD", 4, 4, 60, 4, 1, 70, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7 },
    [101] = { "HEAD", 4, 4, 60, 4, 1, 70, 0, 0, 0, 2 },
    [102] = { "HEAD", 4, 4, 60, 4, 1, 70, 0, 0, 0, 5, 6 },
} }
NS.MAP = { game = "forever", built = "2026-10-05",
    P = { ["V:Alpha"] = "1453:5000:5000", ["V:Horde Guy"] = "1453:6000:6000", ["Q:77"] = "1440:5490:3780",
          ["I:409"] = "1428:4670:7020 1428:4690:7470" },
    G = { ["Q:77"] = "Kommandant Grimm" } }
Map._reset()
local all = { X = true, D = true, V = true, C = true, W = true, Q = true }
local function keys(list)
    local out = {}
    for i, p in ipairs(list) do out[i] = p.key end
    return table.concat(out, ",")
end
local places = NS.MapItemPlaces(100, { sources = all, faction = "A" })
assert(keys(places) == "I:409,V:Alpha", "raid first, the Alliance vendor once, no Horde: " .. keys(places))
assert(places[1].rec[1] == "X" and #places[1].points == 2 and places[2].rec[2] == "Alpha")
places = NS.MapItemPlaces(100, { sources = all, faction = "H" })
assert(keys(places) == "I:409,Q:77,V:Horde Guy", keys(places))
assert(places[2].giver == "Kommandant Grimm" and places[3].giver == nil)
assert(keys(NS.MapItemPlaces(100, { sources = { V = true, Q = true }, faction = "H" })) == "Q:77,V:Horde Guy", "raids switched off")
assert(#NS.MapItemPlaces(102, { sources = all }) == 0, "crafting and world drops have no place")
assert(#NS.MapItemPlaces(999) == 0, "an unknown item")
-- without opts: the page's own (Alliance here); a wish without a fitting source takes all sources
STUB.faction = "Alliance"
assert(keys(NS.MapItemPlaces(100)) == "I:409,V:Alpha")
assert(#NS.MapItemPlaces(101) == 0, "only a Horde vendor")
NS.BisChar().wish[101] = { t = 1, prio = 2, note = "" }
assert(keys(NS.MapItemPlaces(101)) == "V:Horde Guy", "a wish takes every source")
NS.BisChar().wish[101] = nil

---------------------------------------------------------------------------
-- the nearest point
---------------------------------------------------------------------------
STUB.instance = { type = "none" }
STUB.place.map = 1453
STUB.maps[1453].world = { 0, 0, 0, 1000, 1000 }
STUB.maps[1440].world = { 1, -5000, 0, 4000, 4000 }
STUB.maps[1428].world = { 0, -5000, 0, 4000, 4000 }
STUB.map.pos = { x = 0.5, y = 0.5 }
local a, b, c = { map = 1453, x = 0.6, y = 0.5 }, { map = 1428, x = 0.5, y = 0.5 }, { map = 1440, x = 0.5, y = 0.5 }
local p, d = NS.MapNearest({ b, a, c })
assert(p == a and near(d, 100), "the nearest in the same zone: " .. tostring(d))
p, d = NS.MapNearest({ c, b })
assert(p == b and math.abs(d - math.sqrt(3500 ^ 2 + 1500 ^ 2)) < 1e-6, "the own continent before another")
p, d = NS.MapNearest({ c })
assert(p == c and d == nil, "another continent: the first, no distance")
STUB.map.pos = nil
p, d = NS.MapNearest({ b, a })
assert(p == b and d == nil, "no position: the first")
STUB.map.pos = { x = 0.5, y = 0.5 }
STUB.instance = { type = "party" }
p, d = NS.MapNearest({ b, a })
assert(p == b and d == nil, "in an instance Amisia reads no position")
STUB.instance = { type = "none" }
STUB.secret[1453] = true
p, d = NS.MapNearest({ b, a })
assert(p == b and d == nil, "a secret map id counts as unknown")
STUB.secret[1453] = nil
assert(NS.MapNearest({}) == nil)

---------------------------------------------------------------------------
-- the "Fundort" line
---------------------------------------------------------------------------
STUB.faction = "Alliance"
local line = NS.MapTooltipLine(100)
assert(line == "Fundort: Alpha, Sturmwind 50, 50", tostring(line))
STUB.faction = "Horde"
STUB.place.map = 1428
STUB.map.pos = { x = 0.46, y = 0.7 }
line = NS.MapTooltipLine(100)
assert(line == "Fundort: Geschmolzener Kern (Eingang Brennende Steppe 47, 70)", tostring(line))
STUB.place.map = 1440
STUB.map.pos = { x = 0.5, y = 0.4 }
STUB.maps[1440].world = { 0, 0, 0, 1000, 1000 }
line = NS.MapTooltipLine(100)
assert(line == "Fundort: Kommandant Grimm, Eschental 55, 38", tostring(line))
assert(NS.MapTooltipLine(102) == nil and NS.MapTooltipLine(999) == nil)
NS.Set("map.tooltip", false)
assert(NS.MapTooltipLine(100) == nil, "switched off")
NS.Set("map.tooltip", true)
local saved = NS.MAP
NS.MAP = nil
assert(NS.MapTooltipLine(100) == nil, "no data, no line")
NS.MAP = saved
STUB.faction = "Alliance"

---------------------------------------------------------------------------
-- settings: the section and its defaults
---------------------------------------------------------------------------
local defaults = { ["map.pins"] = true, ["map.pinsTargets"] = true, ["map.pinsWishes"] = true, ["map.pinsContinent"] = true,
    ["map.pinScale"] = 100, ["map.arrow"] = "auto", ["map.autoClear"] = true, ["map.tooltip"] = true }
for path, v in pairs(defaults) do
    assert(NS.SettingItem(path), "setting " .. path)
    assert(NS.Get(path) == v, path .. " defaults to " .. tostring(v))
end
assert(NS.SettingItem("map.pinScale").expert and NS.SettingItem("map.resetArrow").expert)
assert(NS.SettingItem("map.resetHidden").type == "button")
assert(NS.SettingItem("map.arrow").tip == "Automatisch: nur wenn der Client den Wegpunkt nicht setzen kann.", NS.SettingItem("map.arrow").tip)
local section
for _, s in ipairs(NS.schema) do if s.key == "map" then section = s end end
assert(section and section.label == "Karte und Wegpunkt" and section.order == 47)
assert(section.available())
NS.MAP = nil
assert(not section.available(), "no data, no section")
NS.MAP = saved
assert(NS.Set("map.arrow", "on") and not NS.Set("map.arrow", "sideways"))
NS.Set("map.arrow", "auto")
AmisiaDB.map.hidden["V:Alpha"] = true
NS.SettingItem("map.resetHidden").run()
assert(next(AmisiaDB.map.hidden) == nil, "hidden places shown again")

---------------------------------------------------------------------------
-- the move of AmisiaDB.map
---------------------------------------------------------------------------
local function dump(t)
    if type(t) ~= "table" then return tostring(t) end
    local ks = {}
    for k in pairs(t) do ks[#ks + 1] = k end
    table.sort(ks, function(x, y) return tostring(x) < tostring(y) end)
    local out = {}
    for _, k in ipairs(ks) do out[#out + 1] = tostring(k) .. "=" .. dump(t[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
AmisiaDB.map = nil
NS.MapMigrate(AmisiaDB)
assert(AmisiaDB.map.v == 1 and next(AmisiaDB.map.hidden) == nil and AmisiaDB.map.target == nil)
AmisiaDB.map = { v = 1, target = { map = 0, x = 0.5, y = 0.5 },
    hidden = { ["V:A"] = true, [5] = true, ["V:B"] = "yes", ["V:C"] = false } }
NS.MapMigrate(AmisiaDB)
assert(AmisiaDB.map.target == nil, "a target without a map falls away")
assert(dump(AmisiaDB.map.hidden) == "{V:A=true}", dump(AmisiaDB.map.hidden))
AmisiaDB.map = { target = { map = 1453, x = 0.5, y = 1.2 } }
NS.MapMigrate(AmisiaDB)
assert(AmisiaDB.map.target == nil and AmisiaDB.map.v == 1, "y out of range")
AmisiaDB.map = { target = { map = "1453", x = 0.5, y = 0.5 } }
NS.MapMigrate(AmisiaDB)
assert(AmisiaDB.map.target == nil, "a map id must be a number")
local good = { map = 1453, x = 0.5, y = 0.25, key = "V:Alpha", item = 100, label = "Alpha", at = 1, ours = true }
AmisiaDB.map = { v = 1, target = good, hidden = { ["W:Wolf"] = true } }
NS.MapMigrate(AmisiaDB)
local once = dump(AmisiaDB.map)
NS.MapMigrate(AmisiaDB)
assert(dump(AmisiaDB.map) == once and AmisiaDB.map.target == good and AmisiaDB.map.hidden["W:Wolf"], "twice changes nothing, data stays")
AmisiaDB.map = "junk"
assert(NS.MapTarget() == nil and type(AmisiaDB.map) == "table" and AmisiaDB.map.v == 1, "fixed on first use")

-- a client without the waypoint functions: the target is Amisia's own
STUB.instance = { type = "none" }
STUB.place.map = 1453
STUB.map.pos = { x = 0.1, y = 0.1 }
local set = C_Map.SetUserWaypoint
C_Map.SetUserWaypoint = nil
assert(not Map.ClientWaypoints())
assert(NS.MapSetTarget(100))
local t = NS.MapTarget()
assert(t and t.key == "V:Alpha" and t.ours == false and STUB.waypoint.point == nil, "no client waypoint, the target stands")
C_Map.SetUserWaypoint = set
assert(Map.ClientWaypoints())
NS.MapClearTarget()
assert(NS.MapTarget() == nil)
