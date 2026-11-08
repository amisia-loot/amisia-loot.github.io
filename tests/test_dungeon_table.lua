-- The start views as tables and the detail views of the pages Dungeons and Raids (F-148, D-74):
-- the first open of a session shows the table (column heads, a group row per level range, a row per
-- dungeon: picture, name, a line under it, level, territory, zone, keys, quests, the map button; dim
-- rows, the brighter frame of the chosen one); a click opens the detail view (the link back before the
-- spec, the image right under the head row, the bosses right under the image); the link back shows
-- the table; ns.ShowDungeon and ns.ShowRaid open the detail; leaving the page keeps the view; the
-- table fills more rows when the main window gets taller and its name column grows with the width.
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function has(t, s) return tostring(t or ""):find(s, 1, true) ~= nil end
local T = NS.Theme
local C, G = T.DTABLE, T.LAYOUT

NS.BIS = nil
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
NS.GEAR = { built = "test-dungeon-cards", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },     -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },               -- 2
    { "D", "The Deadmines", "Cookie", nil },                  -- 3
} }
local function gear(id, name, loc, strength, level, sources)
    STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    local row = { loc, 4, 2, level, 3, 1, 20, 0, 0, 0 }
    for _, n in ipairs(sources) do row[#row + 1] = n end
    NS.GEAR.I[id] = row
end
gear(501, "Ambosshelm", "HEAD", 20, 16, { 1 })
gear(502, "Magmabrust", "CHEST", 10, 17, { 2 })
gear(511, "Kekshut", "HEAD", 25, 18, { 3 })
NS.Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")

---------------------------------------------------------------------------
-- Dungeons: the start view on the first open
---------------------------------------------------------------------------
NS.ShowPage("dungeons")
local B = NS.PageFrame("dungeons")
local nextE = NS.DungeonNext()
assert(nextE and nextE.key == "thanes", "the thanes recommended")
assert(B.table:IsShown() and B.table.head:IsShown() and B.next:IsShown() and B.sorts.level:IsShown(), "the table, the recommendation and the order tabs")
assert(not B.back:IsShown() and not B.art:IsShown() and not B.header:IsShown() and not B.bossView:IsShown(), "no detail parts")
assert(B.table.layoutRole == "list" and B.table.bar and B.table.head.layoutRole == "colhead", "a list of the scaffold under its column heads")
assert(B.table.head.points.TOPLEFT.y == B.top and B.table.points.TOPLEFT.y == B.top - G.COLHEAD_H, "the heads right under the recommendation")

-- every dungeon a row, a group row before each level range
local all = NS.DungeonList()
assert(#B.table.entries == #all and #all > 6, "every dungeon a row: " .. #all)
local groupRows, dungeonRows, last = 0, 0, -1
for _, it in ipairs(B.table.items) do
    if it.group then
        groupRows = groupRows + 1
        local lo = tonumber(it.group:match("^L(%d+)$"))
        assert(lo and lo > last, "the ranges in order: " .. it.group)
        last = lo
    else
        dungeonRows = dungeonRows + 1
        assert(it.min and math.floor(it.min / 10) * 10 == last, "under its range: " .. it.key)
    end
end
assert(dungeonRows == #all and groupRows == #B.table.groups and groupRows >= 2, "rows " .. dungeonRows .. ", groups " .. groupRows)
local heads = {}
for _, k in ipairs({ "name", "level", "side", "zone", "keys", "quests", "act" }) do heads[#heads + 1] = B.table.heads[k] and plain(B.table.heads[k].label:GetText()) or "?" end
assert(table.concat(heads, "|") == "Dungeon|Stufe|Gebiet|Zone|Schlüssel|Quests|Aktionen", table.concat(heads, "|"))

-- a row: the picture, the name in gold, the line under it, the cells in the column heads' places
local thanes = B.table:RowOf("thanes")
assert(thanes and thanes.item.key == "thanes" and thanes._h == C.ROW_H - 1, "the thanes' row")
assert(plain(thanes.name:GetText()) == "Hall of Thanes" and thanes.name.font == T.FONT.title, "the name")
assert(thanes.name.textColor[1] == NS.W.GOLD[1] and thanes.art.desaturated == false, "gold, not dim")
assert(thanes.art._w == C.ART_W and thanes.art._h == C.ART_H and thanes.name.points.LEFT.x == C.NAME_X, "the picture, the name right of it")
assert(plain(thanes.cells.level:GetText()) == "13-18", thanes.cells.level:GetText())
assert(thanes.sub.font == T.FONT.hint and has(plain(thanes.sub:GetText()), "Empfohlen")
    and plain(thanes.sub:GetText()):find("%d+ Upgrades · %+%d+ je Lauf · Wert %d+$"), plain(thanes.sub:GetText()))
assert(thanes.artFrame.edges[1].color[4] == 0.95, "the chosen one: the brighter frame")
for _, k in ipairs({ "level", "zone", "keys", "quests" }) do
    assert(thanes.cells[k].points.LEFT.x == B.table.heads[k].points.LEFT.x, "the cell under its head: " .. k)
end
assert(not thanes.cells.act:IsEnabled(), "no entrance known: no waypoint")
local dead = B.table:RowOf("deadmines")
assert(dead and dead.artFrame.edges[1].color[4] == C.EDGE and not has(dead.sub:GetText(), "Empfohlen"), "the others: a faint frame")
-- a dim row: too high for the level (Blackfathom Deeps at the client's level 22)
local bfd = B.table:RowOf("bfd")
assert(bfd and bfd.art.desaturated == true and bfd.name.textColor[1] < 0.6, "too high: dim")
assert(not has(bfd.sub:GetText(), "Upgrades"), "no values without items")
-- the window dragged wide (D-71): the name column grows, the others keep their width at the right
local F = AmisiaFrame
local nameW = thanes.name._w
F.applySize(NS.Theme.MAIN.W_MAX, F:GetHeight())
F.heightDone()
thanes = B.table:RowOf("thanes")
assert(thanes.name._w == nameW + (T.PAGE_W_NOW - T.PAGE_W), "the name takes the room: " .. thanes.name._w)
F.applySize(NS.Theme.MAIN.W, F:GetHeight())
F.heightDone()
assert(B.table:RowOf("thanes").name._w == nameW and T.PAGE_W_NOW == T.PAGE_W, "back")
B.table.offset = 0
B.table:Redraw()
-- the tooltip reads the row's entry
thanes = B.table:RowOf("thanes")
thanes:GetScript("OnEnter")(thanes)
thanes:GetScript("OnLeave")(thanes)

---------------------------------------------------------------------------
-- a click opens the detail view; the link back the start
---------------------------------------------------------------------------
B.table:RowOf("deadmines"):Click()
assert(AmisiaDB.settings.bis.dungeon == "deadmines", "the click chooses")
assert(B.back:IsShown() and B.art:IsShown() and B.header:IsShown() and B.bossView:IsShown(), "the detail view")
assert(not B.table:IsShown() and not B.table.head:IsShown() and not B.next:IsShown() and not B.why:IsShown() and not B.sorts.level:IsShown(), "no start parts")
assert(B.back:GetText() == "< Alle Dungeons" and B.back.isLink, "the quiet link back")
assert(B.art.title:GetText() == "The Deadmines" and B.header.ButtonText:GetText() == "Bosse")
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(B, T.PAGE_W, T.PAGE_H)
Lay.row("head row", B.back, B.spec)
local artTop = -(G.ROW_H + G.GAP)
assert(B.art.points.TOPLEFT.y == artTop, "the image right under the head row")
local _, artBottom = Lay.vspan(B.art)
-- the tabs right under the image (D-72), the header a row lower
local tabTop = Lay.vspan(B.parts.bosses)
assert(tabTop >= artBottom - G.GAP - G.ROW_H and tabTop <= artBottom - G.GAP, "the tabs right under the image: " .. tabTop)
local headTop = Lay.vspan(B.header)
assert(headTop == artBottom - G.GAP - G.ROW_H - G.GAP, "the header under the tabs")
local listTop = Lay.vspan(B.bossView.list)
local BOSS_ROW_H = T.DBOSS.ROW_H -- a row of the boss list (F-154)
assert(listTop == artTop - NS.DungeonJournalKit.ART_H - G.GAP - G.ROW_H - G.GAP - T.HEADER_H - G.GAP, "the bosses right under the header: " .. listTop)
assert(B.bossView.list.rowCount >= math.floor((T.PAGE_H + listTop) / BOSS_ROW_H) - 1, "the bosses fill the page: " .. B.bossView.list.rowCount)
Lay.column("detail", B.spec, B.art, B.header, B.bossView)
-- leaving the page keeps the view
NS.ShowPage("overview")
NS.ShowPage("dungeons")
assert(B.bossView:IsShown() and not B.table:IsShown(), "the view stays while the session lasts")
-- the link back: the table, the chosen one in view with its frame
B.back:Click()
assert(B.table:IsShown() and not B.bossView:IsShown() and not B.art:IsShown() and not B.back:IsShown() and B.sorts.chain:IsShown())
assert(B.table:RowOf("deadmines").artFrame.edges[1].color[4] == 0.95 and B.table:RowOf("thanes").artFrame.edges[1].color[4] < 0.9, "the chosen row")
Lay.row("start head row", B.spec, B.sorts.level, B.sorts.value, B.sorts.chain)
-- ns.ShowDungeon opens the detail of that dungeon
NS.ShowPage("overview")
assert(NS.ShowDungeon("thanes") ~= nil)
assert(NS.CurrentPage() == "dungeons" and B.bossView:IsShown() and B.art.title:GetText() == "Hall of Thanes", "ShowDungeon: the detail")
-- the journal covers the detail; its own link back returns to the detail
B.plan:Click()
assert(B.pathView:IsShown() and not B.bossView:IsShown() and not B.back:IsShown() and not B.table:IsShown(), "the journal")
for _, f in ipairs(B.planParts) do assert(not f:IsShown(), "a part under the journal") end
-- the spec at the head row's start again: the hidden link leaves no gap
assert(B.spec.points.LEFT and B.spec.points.LEFT.x == 0, "the spec at the start in the journal: " .. tostring(B.spec.points.LEFT and B.spec.points.LEFT.x))
B.pathView.back:Click()
assert(not B.pathView:IsShown() and B.bossView:IsShown() and B.back:IsShown(), "back to the detail")
assert(B.spec.points.LEFT.x > 0, "after the link again in the detail")
-- the hint by the view
assert(B.hint:GetText():find("Strg-Klick", 1, true), "the detail's hint")
B.back:Click()
assert(B.hint:GetText():find("Klick auf eine Zeile", 1, true), B.hint:GetText())

---------------------------------------------------------------------------
-- the table follows the main window's height
---------------------------------------------------------------------------
local before = B.table.rowCount
assert(before == math.floor((T.PAGE_H + B.top - G.COLHEAD_H - B:Bottom()) / C.ROW_H), "the table fills the page: " .. before)
F.applyHeight(F:GetHeight() + 2 * C.ROW_H)
F.heightDone()
assert(B.table.rowCount == before + 2, "two more rows: " .. before .. " -> " .. B.table.rowCount)
F.applyHeight(T.MAIN.H)
F.heightDone()
assert(B.table.rowCount == before, "back again")

---------------------------------------------------------------------------
-- Raids: the same two views with their own columns
---------------------------------------------------------------------------
NS.ShowPage("raidjournal")
local P = NS.PageFrame("raidjournal")
assert(P.table:IsShown() and not P.bossView:IsShown() and not P.back:IsShown() and not P.art:IsShown(), "the raids' table first")
local ony = P.table:RowOf("onyxia")
assert(ony and plain(ony.name:GetText()) == "Onyxia's Lair" and plain(ony.cells.size:GetText()) == "40", plain(ony.cells.size:GetText()))
assert(ony.name.textColor[1] < 0.6, "out of reach at 16: dim")
ony:Click()
assert(P.bossView:IsShown() and P.back:IsShown() and P.art:IsShown() and not P.table:IsShown() and not P.next:IsShown(), "the raid's detail")
assert(P.back:GetText() == "< Alle Raids" and AmisiaDB.settings.bis.raid == "onyxia")
local LP = dofile(ADDON_DIR .. "/../tests/layout.lua")(P, T.PAGE_W, T.PAGE_H)
LP.row("raid head row", P.back, P.spec)
assert(P.art.points.TOPLEFT.y == artTop and LP.vspan(P.bossView.list) == listTop, "the same places as on Dungeons")
P.back:Click()
assert(P.table:IsShown() and not P.bossView:IsShown() and P.table:RowOf("onyxia").artFrame.edges[1].color[4] == 0.95)
NS.ShowPage("overview")
assert(NS.ShowRaid("hyjal") ~= nil and P.bossView:IsShown() and P.header.ButtonText:GetText() == "Bosse", "ShowRaid: the detail")
-- a raid's entrance on the map goes through ns.ShowDungeon
P.back:Click()
assert(NS.ShowDungeon("onyxia") ~= nil and NS.CurrentPage() == "raidjournal" and P.bossView:IsShown(), "ShowDungeon of a raid: its detail")
print("dungeon table: start view, rows, detail view, back link, ShowDungeon/ShowRaid, raids, the window's size")
