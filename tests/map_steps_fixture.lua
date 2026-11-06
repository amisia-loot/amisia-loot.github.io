-- The small world of the map page's quest step tests (dofile from a test; returns the table of the
-- quests in the log that are complete): a level 16 warrior in Westfall, a vendor with an NPC id, a
-- crafted bracer (the professions fixture's recipe), boots from the auction house, the Deadmines
-- quest's reward; the quest data of the Deadmines with pre-quests in Westfall and Stormwind. Not real data.
local Gear, Map = NS.Gear, NS.Map
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
AmisiaDB.settings.gear = { specs = { WARRIOR = "dps" } }
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { type = "none" }
STUB.maps[1415] = { name = "Östliche Königreiche", parent = 947, mapType = 2 }
STUB.maps[947] = { name = "Azeroth", mapType = 1 }
STUB.maps[1436] = { name = "Westfall", parent = 1415, mapType = 3, world = { 0, 0, 0, 1000, 1000 } }
STUB.maps[1453] = { name = "Sturmwind", parent = 1415, mapType = 3, world = { 0, 2000, 0, 1000, 1000 } }
STUB.maps[1429] = { name = "Wald von Elwynn", parent = 1415, mapType = 3, world = { 0, 1000, 0, 1000, 1000 } }
STUB.place.map = 1436
STUB.map.pos = { x = 0.2, y = 0.2 }
local ready = {}
C_QuestLog.IsComplete = function(id) return ready[id] == true end

-- the gear: a vendor's helm (an NPC id: German name from the collector), a crafted bracer (the
-- fixture's recipe "Kupferarmschienen" makes item 2853), boots only in the auction house; the
-- Deadmines quest's reward
local function gear(id, name, loc, str, sources)
    STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.stats, it.minLevel = "INVTYPE_" .. loc, 4, 3, { ITEM_MOD_STRENGTH_SHORT = str }, 10
    NS.GEAR.I[id] = { loc, 4, 3, 10, 3, 1, 20, 0, 0, 0 }
    for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
end
NS.GEAR = { game = "forever", cap = 60, built = "t-map-steps", Z = {}, I = {}, S = {
    { "V", "Quartermaster Lewis", 1436, "", "", 0, 491 },        -- 1: a vendor with an NPC id
    { "C", "blacksmithing", 20 },                                 -- 2
    { "A", "B" },                                                 -- 3: the auction house
    { "Q", "Final Quest", 18, 14, "A", 1436, 500, 0 },            -- 4: the Deadmines quest
} }
Gear._reset()
gear(801, "Westfall-Helm", "HEAD", 30, { 1 })
gear(2853, "Kupferarmschienen", "WRIST", 25, { 2 })
gear(803, "Auktionsstiefel", "FEET", 20, { 3 })
gear(804, "Van-Cleef-Gurt", "WAIST", 22, { 4 })
NS.MAP = { game = "forever", built = "2026-11-05", G = {}, P = {
    ["U:491"] = "1436:5700:4700",
} }
Map._reset()
-- the quest data: the Deadmines quest 500 needs 501 (Westfall) and 502 (Stormwind); 510 another
-- Deadmines quest with 501 as its first step too; 520 starts at a level out of reach
NS.DUNGEON_QUESTS = { built = "test", source = "test", D = { deadmines = { 500, 510, 520 } }, Q = {
    [500] = { "Final Quest", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", { 502 }, nil, "deadmines", nil, nil,
              nil, nil, nil, 0, 0, "Gryan", "1436:5630:4760" },
    [502] = { "Middle", 10, 12, "A", 0, "O", "Mid Giver", "1453:2000:3000", { 501 }, nil, nil, nil, nil,
              nil, nil, nil, 0, 0, "Mid Ender", "1453:2500:3500" },
    [501] = { "Root", 10, 12, "A", 0, "O", "Root Giver", "1436:1000:1000", nil, nil, nil },
    [510] = { "Second Final", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", { 501 }, nil, "deadmines" },
    [520] = { "Too High", 40, 45, "", 0, "O", "High Giver", "1436:9000:9000", nil, nil, "deadmines" },
} }
NS.BisBump()
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
return ready
