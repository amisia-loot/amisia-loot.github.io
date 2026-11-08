-- The journal's detail parts (F-146 steps 4 and 5, D-72): the tabs under the image (Übersicht,
-- Karte, Quests, Wunschliste, Zugang only with a key; the last one kept), the run in the bosses'
-- header line ("1/4", the bar, "Lauf zurücksetzen"), a killed boss's tick and its menu, the
-- Wunschliste (wished and recommended items by boss), the instance map (the client's art of each
-- floor, the floors' arrows, zoom, "no map") and the keys (have or not, the steps; a click sets the
-- waypoint).
local R = NS.Runs
local fact
for _, e in ipairs(NS.DUNGEON_FACTS.list) do if e.key == "thanes" then fact = e end end
local keep = { enc = fact.enc, maps = fact.maps, keys = fact.keys }
fact.enc = { 3001, 3002, 3003, 3004 }
fact.maps = nil
fact.keys = nil
STUB.instance = { name = "", type = "none", id = 0 }
STUB.fire("PLAYER_ENTERING_WORLD")
NS.ShowDungeon("thanes")
local B = NS.PageFrame("dungeons")
assert(B and B.chosen == "thanes" and B.art:IsShown(), "the thanes' detail")

-- the tabs: Übersicht first and chosen, Zugang hidden without a key
local tabs = {}
for _, k in ipairs(B.partKeys) do tabs[#tabs + 1] = k .. (B.parts[k]:IsShown() and "" or "-") end
assert(table.concat(tabs, " ") == "bosses map quests wish access-", table.concat(tabs, " "))
assert(B.parts.bosses.on and B.parts.bosses:GetText() == "Übersicht" and B.header.ButtonText:GetText() == "Bosse")
assert(B.detail:IsShown() and not B.mapView:IsShown() and not B.accessView:IsShown())
-- no run here: no "1/4", no reset
assert(not B.runBar:IsShown() and not B.resetRun:IsShown(), "no run outside")

-- in the thanes, a kill: "1/4" with the bar, the boss ticked and grey
STUB.instance = { name = "Hall of Thanes", type = "party", id = 3065 }
STUB.fire("PLAYER_ENTERING_WORLD")
STUB.fire("ENCOUNTER_END", 3001, "Faldrim Anvilmar", 1, 5, 1)
NS.Refresh()
assert(B.runBar:IsShown() and B.runBar.text:GetText() == "1/4" and B.resetRun:IsShown(), "the run")
assert(B.runBar.fill._w == math.floor(NS.Theme.DPART.RUN.BAR_W / 4 + 0.5), "a quarter of the bar: " .. tostring(B.runBar.fill._w))
local function bossRow(name)
    for _, r in ipairs(B.detail.rows) do
        if r.item and r.item.kind == "boss" and r.item.text == name then return r end
    end
end
local faldrim = bossRow("Faldrim Anvilmar")
assert(faldrim and faldrim.item.killed and faldrim.name:GetText():find("ReadyCheck-Ready", 1, true), "ticked")
-- the right-click menu marks another boss by hand, and back
local plunder = bossRow("Plunder")
assert(plunder and not plunder.item.killed)
local menu
local keepMenu = NS.W.Menu
NS.W.Menu = function(_, entries) menu = entries end
plunder.scripts.OnClick(plunder, "RightButton")
NS.W.Menu = keepMenu
assert(menu and menu[1][1] == "Als getötet markieren", "the menu")
menu[1][2]()
assert(R.Killed("thanes", 3) and B.runBar.text:GetText() == "2/4", "marked by hand")
-- "Lauf zurücksetzen" forgets the kills: inside, a fresh run "0/4"
B.resetRun:Click()
assert(select(2, R.Of("thanes")) == 0 and B.runBar:IsShown() and B.runBar.text:GetText() == "0/4", "the run reset")

-- Wunschliste: only bosses with a wished or recommended item, unfolded, those items only
B.parts.wish:Click()
assert(AmisiaDB.settings.bis.dpart == "wish" and B.parts.wish.on and B.header.ButtonText:GetText() == "Wunschliste")
assert(not B.runBar:IsShown() and not B.foldAll:IsShown(), "no run and no fold in the wish list")
local heads, items = 0, 0
for _, it in ipairs(B.detail.items) do
    if it.kind == "boss" then
        heads = heads + 1
        assert(it.open and #it.items > 0, "a boss with wishes, unfolded")
    else
        items = items + 1
        assert(it.wished or it.rec, "only wished or recommended items")
    end
end
assert(heads == 0 or items >= heads)

-- Karte: without floors "no map"
B.parts.map:Click()
assert(B.mapView:IsShown() and not B.detail:IsShown() and B.mapView.none:IsShown(), "no map without floors")
-- with two floors whose art the client has: the tiles, the floor row, the arrows
fact.maps = { 9001, 9002 }
local M = C_Map
local keepM = { M.GetMapArtLayers, M.GetMapArtLayerTextures, M.GetMapInfo, M.GetPlayerMapPosition }
M.GetMapArtLayers = function(id)
    if id == 9001 or id == 9002 then return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
end
M.GetMapArtLayerTextures = function(id)
    if id == 9001 then local t = {} for i = 1, 12 do t[i] = 100 + i end return t end
    if id == 9002 then return { 201, 202 } end
end
M.GetMapInfo = function(id) return { name = id == 9001 and "Upper Hall" or "Lower Hall" } end
M.GetPlayerMapPosition = function(id)
    if id == 9001 then return { GetXY = function() return 0.5, 0.25 end } end
end
NS.Refresh()
local v = B.mapView
assert(not v.none:IsShown() and v.uiMap == 9001 and v.prev:IsShown() and v.next:IsShown(), "the first floor")
local shownTiles = 0
for _, t in ipairs(v.tiles) do if t:IsShown() then shownTiles = shownTiles + 1 end end
assert(shownTiles == 12 and v.tiles[1].texture == 101, "its twelve tiles")
assert(v.label:GetText():find("Upper Hall", 1, true) and v.label:GetText():find("Ebene 1 von 2", 1, true), v.label:GetText())
assert(v.pin:IsShown(), "the player on this floor")
-- the tiles in four columns, at the scale that fits the room
local s = v.scale
assert(s and s > 0 and v.tiles[5].points.TOPLEFT.y == -256 * s and v.tiles[2].points.TOPLEFT.x == 256 * s, "a grid of tiles")
-- the wheel zooms, never past ZOOM_MAX nor under 1
for _ = 1, 20 do v.clip.scripts.OnMouseWheel(v.clip, 1) end
assert(v.zoom == NS.Theme.DPART.MAP.ZOOM_MAX, "zoomed in to the most: " .. v.zoom)
for _ = 1, 20 do v.clip.scripts.OnMouseWheel(v.clip, -1) end
assert(v.zoom == 1, "zoomed out")
-- the next floor
v.next:Click()
assert(v.uiMap == 9002 and v.label:GetText():find("Ebene 2 von 2", 1, true) and not v.pin:IsShown(), "the second floor")
shownTiles = 0
for _, t in ipairs(v.tiles) do if t:IsShown() then shownTiles = shownTiles + 1 end end
assert(shownTiles == 2, "its tiles only")
M.GetMapArtLayers, M.GetMapArtLayerTextures, M.GetMapInfo, M.GetPlayerMapPosition = keepM[1], keepM[2], keepM[3], keepM[4]

-- Zugang: a key shows its tab; the key with its state and its steps
fact.keys = { { item = 7146, need = "required", why = "door", quests = { 1, 2 } } }
NS.Refresh()
assert(B.parts.access:IsShown(), "the tab with a key")
B.parts.access:Click()
local A = B.accessView
assert(A:IsShown() and #A.items == 3 and A.items[1].kind == "key" and A.items[2].kind == "step", "the key and two steps")
local r1 = A.rows[1]
assert(r1.state:GetText():find("fehlt", 1, true), "no key yet: " .. tostring(r1.state:GetText()))
assert(r1.name:GetText():find("öffnet die Instanz", 1, true) and r1.name:GetText():find("nötig", 1, true), r1.name:GetText())
local said
local keepWay = NS.DungeonQuestWaypoint
NS.DungeonQuestWaypoint = function(qid, open, what) said = { qid, open, what } return true end
A.rows[2]:Click()
NS.DungeonQuestWaypoint = keepWay
assert(said and said[1] == 1 and said[2] == true and said[3] == "accept", "the step's waypoint")
-- the card shows the key, grey while it is missing (when the client knows its icon)
if C_Item.GetItemIconByID and C_Item.GetItemIconByID(7146) then
    B.back:Click()
    local card = B.grid:CardOf("thanes")
    assert(card.badge:IsShown() and card.badge.text:GetText():find(":110:110:110|t", 1, true), tostring(card.badge.text:GetText()))
    NS.ShowDungeon("thanes")
end
-- the key in the bags: green
local keepCount = C_Item.GetItemCount
C_Item.GetItemCount = function(id) return id == 7146 and 1 or 0 end
NS.Refresh()
assert(A.rows[1].state:GetText():find("vorhanden", 1, true), "the key is there")
C_Item.GetItemCount = keepCount
-- the part is kept; a dungeon without keys falls back to Übersicht
assert(AmisiaDB.settings.bis.dpart == "access")
fact.keys = nil
NS.Refresh()
assert(B.parts.bosses.on and not B.parts.access:IsShown() and B.detail:IsShown(), "back to Übersicht")

-- the raids page has the same tabs, without Quests
NS.ShowRaid("onyxia")
local P = NS.PageFrame("raidjournal")
assert(P.parts.bosses and P.parts.map and P.parts.wish and P.parts.access and P.parts.quests == nil, "the raids' tabs")
P.parts.map:Click()
assert(P.mapView:IsShown() and not P.detail:IsShown() and AmisiaDB.settings.bis.rpart == "map")
P.parts.bosses:Click()

fact.enc, fact.maps, fact.keys = keep.enc, keep.maps, keep.keys
print("journal parts ok")
