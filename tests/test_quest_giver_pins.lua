-- Dungeon quest givers on the world map (F-179, Gear/QuestGiverPins.lua): one pin per giver and place
-- for the dungeon and raid quests the own character can take now or within two levels; never a done
-- quest, one in the log, one grey for the own level, one of the other faction, one held back by a pre-quest or more than two
-- levels, one that starts inside the dungeon or by an item, a scan-only quest without a giver; zone
-- maps only; the tooltip's lines ("[D15] <title>", the dungeon, "ab 18", the cap "... und N weitere");
-- a click opens the first quest's dungeon by level at its quest (a raid's part Zugang), shift sets the
-- target, the menu; offset from the point; the setting; redraws after accepting a quest and a level-up.
local Map, G = NS.Map, NS.QuestGivers
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function click(p, button) p.scripts.OnClick(p, button, false) end
local function enter(p) p.scripts.OnEnter(p) end
assert(G and Map.RedrawSoon, "the module and the layer's redraw")
assert(NS.Get("map.questGivers") == true, "on by default")

---------------------------------------------------------------------------
-- data: a level 16 Alliance warrior in Westfall
---------------------------------------------------------------------------
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { type = "none", name = "Westfall", id = 0 }
STUB.maps[1436] = { name = "Westfall", parent = 1415, mapType = 3 }
STUB.maps[1415] = { name = "Östliche Königreiche", parent = 947, mapType = 2 }
STUB.maps[947] = { name = "Azeroth", mapType = 1 }
STUB.map.rects["1436>1415"] = { 0.4, 0.5, 0.6, 0.8 }
local GRYAN, RAIDER, MANY = "1436:5600:4700", "1436:3000:3000", "1436:7000:7000"
local function q(name, min, level, side, start, giver, points, dkey, extra)
    local r = { name, min, level, side, 0, start, giver, points, nil, nil, dkey }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end
local Q = {
    -- the giver with two quests of two dungeons: the lower one (Ragefire) first
    [99101] = q("Mines Job", 14, 18, "", "O", "Gryan Stoutmantle", GRYAN, "deadmines"),
    [99102] = q("Fire Job", 10, 15, "", "O", "Gryan Stoutmantle", GRYAN, "rfc"),
    -- the same giver, none of these gets a line
    [99103] = q("Horde Job", 10, 16, "H", "O", "Gryan Stoutmantle", GRYAN, "deadmines"),
    [99104] = q("Done Job", 10, 16, "", "O", "Gryan Stoutmantle", GRYAN, "deadmines"),
    [99105] = q("Log Job", 10, 16, "", "O", "Gryan Stoutmantle", GRYAN, "deadmines"),
    [99106] = q("Soon Job", 18, 20, "", "O", "Gryan Stoutmantle", GRYAN, "deadmines"),
    [99107] = q("Late Job", 19, 22, "", "O", "Gryan Stoutmantle", GRYAN, "deadmines"),
    [99108] = q("Pre Job", 10, 16, "", "O", "Gryan Stoutmantle", GRYAN, "deadmines", { [9] = { 99199 } }),
    [99109] = q("Scanned Job", 10, 16, "", "", nil, nil, "deadmines", { [24] = true }),
    [99110] = q("Inside Job", 10, 16, "", "I", "Inside Guy", GRYAN, "deadmines"),
    [99111] = q("Item Job", 10, 16, "", "X", nil, GRYAN, "deadmines", { [15] = { { 5000 } } }),
    [99112] = q("Grey Job", 1, 5, "", "O", "Gryan Stoutmantle", GRYAN, "deadmines"),
    [99199] = q("The Pre-quest", 10, 12, "", "O", "Pre Giver", "1436:1000:1000", nil),
    -- a raid quest at a giver of its own
    [99120] = q("Raid Job", 15, 60, "", "O", "Raid Giver", RAIDER, "onyxia"),
}
local many = {}
for i = 1, 7 do
    Q[99130 + i] = q("Many " .. i, 10, 15 + i, "", "O", "Many Quests", MANY, "deadmines")
    many[#many + 1] = 99130 + i
end
local dm = { 99101, 99103, 99104, 99105, 99106, 99107, 99108, 99109, 99110, 99111, 99112 }
for _, id in ipairs(many) do dm[#dm + 1] = id end
NS.DUNGEON_QUESTS = { built = "test", source = "test", D = { deadmines = dm, rfc = { 99102 }, onyxia = { 99120 } }, Q = Q }
STUB.questsDone[99104] = true
STUB.questsActive[99105] = true
NS.Map._reset()
G._reset()

---------------------------------------------------------------------------
-- which quests: the states
---------------------------------------------------------------------------
local o = { level = 16, faction = "A", class = "WARRIOR" }
assert(G.PinState(99101, o) == "open" and G.PinState(99102, o) == "open")
assert(G.PinState(99103, o) == nil, "the other faction")
assert(G.PinState(99104, o) == nil, "done")
assert(G.PinState(99105, o) == nil, "in the log")
assert(G.PinState(99106, o) == "soon", "two levels ahead: shown")
assert(G.PinState(99107, o) == nil, "three levels ahead: not yet")
assert(G.PinState(99108, o) == nil, "a pre-quest open: never early")
assert(G.PinState(99112, o) == "open", "a grey quest can be taken, but gets no line (below)")

local givers = G.Givers()
local byName = {}
for _, e in ipairs(givers) do byName[e.giver] = e end
assert(#givers == 3 and byName["Gryan Stoutmantle"] and byName["Raid Giver"] and byName["Many Quests"], #givers .. " givers")
assert(not byName["Inside Guy"], "a quest that starts inside the dungeon gets no pin")
local gryan = byName["Gryan Stoutmantle"]
local ids = {}
for _, x in ipairs(gryan.quests) do ids[#ids + 1] = x.qid end
assert(table.concat(ids, ",") == "99102,99101,99106", "by level, the right ones: " .. table.concat(ids, ","))
assert(gryan.quests[1].dkey == "rfc" and gryan.quests[2].dkey == "deadmines" and not gryan.soon and not gryan.raid)
assert(gryan.key == "Q:99102" and near(gryan.point.x, 0.56) and near(gryan.point.y, 0.47))
assert(byName["Raid Giver"].raid and byName["Raid Giver"].quests[1].raid)
assert(G.Tag(gryan.quests[1]) == "[D15]" and G.Tag(byName["Raid Giver"].quests[1]) == "[R60]")
assert(G.Tag({ raid = false }) == "[D?]", "unknown level")

-- the pins of a map: zone maps only, nothing on the continent
local list = G.Pins(1436)
assert(#list == 3 and list[1].giver == "Gryan Stoutmantle" and list[1].dx > 0 and list[1].dy > 0, #list)
assert(near(list[1].x, 0.56) and near(list[1].y, 0.47) and not list[1].continent)
assert(#G.Pins(1415) == 0, "nothing on the continent")
assert(#G.Pins(947) == 0, "nothing on the map of the world")
assert(G.Pins(1436) == list, "kept")

---------------------------------------------------------------------------
-- the tooltip's lines
---------------------------------------------------------------------------
local lines = G.QuestLines(gryan)
assert(#lines == 3, #lines)
assert(lines[1][1] == "[D15] Fire Job" and has(lines[1][2], "Ragefire"), lines[1][1] .. " | " .. tostring(lines[1][2]))
assert(lines[2][1] == "[D18] Mines Job" and has(lines[2][2], "Deadmines"), lines[2][1])
assert(lines[3][1] == "[D20] Soon Job" and has(lines[3][2], "ab 18"), tostring(lines[3][2]))
assert(type(lines[1][3]) == "table" and lines[1][3][1] == 1 and lines[1][3][2] == 1, "level 15 at 16: yellow")
assert(G.LevelColor(22)[2] == 0.13, "six above: red")
assert(G.LevelColor(19)[2] == 0.5, "three above: orange")
assert(G.LevelColor(12)[1] == 0.25, "four below: green")
assert(G.LevelColor(5)[1] == 0.5, "far below: grey")
_G.GetQuestDifficultyColor = function() return { r = 0.1, g = 0.2, b = 0.3 } end
assert(G.LevelColor(15)[3] == 0.3, "the client's colour where it has one")
_G.GetQuestDifficultyColor = nil
local cap = G.QuestLines(byName["Many Quests"])
assert(#cap == 6 and cap[1][1] == "[D16] Many 1" and cap[6][1] == "... und 2 weitere" and cap[6][3] == nil, cap[6][1])

---------------------------------------------------------------------------
-- on the world map
---------------------------------------------------------------------------
STUB.fire("PLAYER_LOGIN")
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1436)
STUB.tick(0)
local function pinOf(name)
    for _, p in ipairs(Map.ShownPins("giver")) do
        if p.entry and p.entry.giver == name then return p end
    end
end
assert(#Map.ShownPins("giver") == 3, "three giver pins: " .. #Map.ShownPins("giver"))
local pin = pinOf("Gryan Stoutmantle")
assert(pin:GetParent() == Map.PinLayer() and pin.kind == "giver" and pin:IsShown(), "Amisia's own button on its layer")
assert(pin.icon.texture == "Interface\\GossipFrame\\AvailableQuestIcon" and pin._w == 16, "the quest giver's mark, small")
-- the badge: the quest log's dungeon or raid mark, the map legend's where the client lacks it, none
-- without either
assert(pin.badge:IsShown() and pin.badge.atlas == "questlog-questtypeicon-dungeon", tostring(pin.badge.atlas))
assert(pinOf("Raid Giver").badge.atlas == "questlog-questtypeicon-raid")
STUB.missingAtlases["questlog-questtypeicon-dungeon"] = true
assert(G.BadgeAtlas(false) == "Dungeon" and G.BadgeAtlas(true) == "questlog-questtypeicon-raid")
STUB.missingAtlases.Dungeon = true
assert(G.BadgeAtlas(false) == nil, "neither: no badge, the plain mark")
STUB.missingAtlases.Dungeon, STUB.missingAtlases["questlog-questtypeicon-dungeon"] = nil, nil

-- up and right of the giver's point
local a, s = pin.points.CENTER, pin:GetScale()
local w, h = STUB.mapCanvas:GetWidth(), STUB.mapCanvas:GetHeight()
assert(near(a.x, 0.56 * w / s + 9) and near(a.y, -0.47 * h / s + 9), "offset from the point")

-- the tooltip as the client shows it
local tip = {}
local addLine, addDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
GameTooltip.AddLine = function(_, text) tip[#tip + 1] = text end
GameTooltip.AddDoubleLine = function(_, l, r) tip[#tip + 1] = l .. " || " .. r end
enter(pin)
local text = table.concat(tip, "\n")
assert(tip[1] == "Gryan Stoutmantle" and has(tip[2], "Westfall 56, 47"), text)
assert(has(text, "[D15] Fire Job || ") and has(text, "[D18] Mines Job") and has(text, "[D20] Soon Job"), text)
assert(not has(text, "Horde Job") and not has(text, "Done Job") and not has(text, "Log Job") and not has(text, "Late Job")
    and not has(text, "Pre Job") and not has(text, "Scanned Job") and not has(text, "Item Job") and not has(text, "Grey Job"), text)
assert(has(text, "Klick: Ragefire Chasm in Amisia öffnen") or has(text, "in Amisia öffnen. Shift-Klick: Ziel setzen."), text)
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine, addDouble

-- a click: the first quest by level, its dungeon's quests; the world map stays in front
click(pin, "LeftButton")
assert(AmisiaDB.settings.bis.dungeon == "rfc" and AmisiaDB.settings.bis.dpart == "quests", tostring(AmisiaDB.settings.bis.dungeon))
assert(NS.CurrentPage() == "dungeons" and AmisiaFrame:IsShown() and WorldMapFrame:IsShown(), "the page Dungeons under the map")
assert(AmisiaFrame:GetFrameStrata() ~= "FULLSCREEN", "the window under the map (F-011)")
-- a raid quest: the page Raids, part Zugang
click(pinOf("Raid Giver"), "LeftButton")
assert(AmisiaDB.settings.bis.raid == "onyxia" and AmisiaDB.settings.bis.rpart == "access" and NS.CurrentPage() == "raidjournal")
-- shift: the target to the giver
STUB.shift = true
click(pin, "LeftButton")
STUB.shift = false
local t = NS.MapTarget()
assert(t and t.key == "Q:99102" and near(t.x, 0.56) and t.label == "Questgeber Gryan Stoutmantle", t and t.label)
NS.MapClearTarget()
STUB.tick(0.6)
-- the menu: one entry per dungeon, the target, off
pin = pinOf("Gryan Stoutmantle")
click(pin, "RightButton")
local labels = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
assert(#labels == 4 and has(labels[1], "In Amisia öffnen: Ragefire") and has(labels[2], "In Amisia öffnen: The Deadmines")
    and labels[3] == "Ziel setzen" and labels[4] == "Dungeonquest-Geber ausblenden", table.concat(labels, ","))
AmisiaMenu.buttons[4]:Click()
assert(NS.Get("map.questGivers") == false, "off from the menu")
STUB.tick(0.6)
assert(#Map.ShownPins("giver") == 0 and #G.Pins(1436) == 0, "switched off: gone")
NS.Set("map.questGivers", true)
STUB.tick(0.6)
assert(#Map.ShownPins("giver") == 3)

---------------------------------------------------------------------------
-- a change redraws: a quest accepted, a level-up
---------------------------------------------------------------------------
STUB.questsActive[99102] = true
STUB.fire("QUEST_ACCEPTED", 99102)
STUB.tick(0.6)
local e = pinOf("Gryan Stoutmantle").entry
assert(#e.quests == 2 and e.quests[1].qid == 99101, "the quest in the log is gone from the pin")
STUB.level = 17
STUB.fire("PLAYER_LEVEL_UP", 17)
STUB.tick(0.6)
e = pinOf("Gryan Stoutmantle").entry
ids = {}
for _, x in ipairs(e.quests) do ids[#ids + 1] = x.qid .. ":" .. x.state end
assert(table.concat(ids, ",") == "99101:open,99106:soon,99107:soon", table.concat(ids, ","))
-- every quest of a giver only "soon": the grey "!"
STUB.questsActive[99101] = true
STUB.fire("QUEST_ACCEPTED", 99101)
STUB.tick(0.6)
pin = pinOf("Gryan Stoutmantle")
assert(pin.entry.soon and pin.icon.vertexColor and pin.icon.vertexColor[1] < 1, "grey while not yet open")
STUB.questsActive[99101], STUB.questsActive[99102] = nil, nil
STUB.level = 16
WorldMapFrame:Hide()
print("quest giver pins ok")
