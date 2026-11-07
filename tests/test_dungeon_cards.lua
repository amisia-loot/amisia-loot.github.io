-- The start views with cards and the detail views of the pages Dungeons and Raids (F-143, D-69):
-- the first open of a session shows the cards (3 per list row, image, name, two lines, the tag of
-- the recommended one, dim cards, the brighter frame of the chosen one); a click opens the detail
-- view (the link back before the spec, the image right under the head row, the bosses right under
-- the image); the link back shows the cards; ns.ShowDungeon and ns.ShowRaid open the detail; leaving
-- the page keeps the view; the grid fills more rows when the main window gets taller.
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local T = NS.Theme
local C, G = T.DCARD, T.LAYOUT

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
assert(B.grid:IsShown() and B.next:IsShown() and B.sorts.level:IsShown(), "the cards, the recommendation and the order tabs")
assert(not B.back:IsShown() and not B.art:IsShown() and not B.header:IsShown() and not B.detail:IsShown(), "no detail parts")
assert(B.grid.layoutRole == "list" and B.grid.bar, "the grid is a list of the scaffold")

-- three cards per list row, the row's own shade and hover hidden
local all = NS.DungeonList()
assert(#B.grid.entries == #all and #all > 6, "every dungeon a card: " .. #all)
local r1 = B.grid.rows[1]
assert(#r1.item == 3 and #r1.cards == 3 and not r1.bg:IsShown() and r1.hover:GetAlpha() == 0, "one row, three cards")
assert(#B.grid.items == math.ceil(#all / 3), "the rows: " .. #B.grid.items)
for i, c in ipairs(r1.cards) do
    local x = c.points.TOPLEFT.x
    assert(x == (i - 1) * (C.W + C.GAP) and c._w == C.W and c._h == C.H, "card " .. i .. " at " .. x)
end
assert(3 * C.W + 2 * C.GAP == T.PAGE_W - T.SCROLL_ROOM, "three cards fill the list's width")
assert(B.grid.points.TOPLEFT.y == B.top, "the grid right under the recommendation")

-- a card: name in gold over the image, level · fit, the values, the tag, the frame
local thanes = B.grid:CardOf("thanes")
assert(thanes and thanes.item.key == "thanes", "the thanes' card")
assert(plain(thanes.name:GetText()) == "Hall of Thanes" and thanes.name.font == T.FONT.title, "the name")
assert(thanes.name.textColor[1] == NS.W.GOLD[1] and not thanes.dim and thanes.tex.desaturated == false, "gold, not dim")
assert(thanes.name.points.BOTTOMLEFT.rel == thanes.tex, "the name on the image's lower left")
assert(thanes.tex._h == C.ART_H and thanes.shade.points.TOPLEFT.rel == thanes.tex, "the image, darkened")
assert(plain(thanes.line1:GetText()) == "13-18 · passt" and thanes.line1:GetText():find("|cff4fd06apasst", 1, true), thanes.line1:GetText())
assert(thanes.line2.font == T.FONT.hint and plain(thanes.line2:GetText()):find("^%d+ Upgrades · %+%d+ je Lauf · Wert %d+$"),
    plain(thanes.line2:GetText()))
assert(thanes.tag:IsShown() and thanes.tag.text:GetText() == "Empfohlen", "the recommended one is tagged")
assert(thanes.chosen and thanes.edges[1].color[4] == C.CHOSEN, "the chosen one: the brighter frame")
assert(thanes.glow.layer == "HIGHLIGHT" and thanes.glow.color[4] == C.GLOW, "the hover glow")
local dead = B.grid:CardOf("deadmines")
assert(dead and not dead.chosen and not dead.tag:IsShown() and dead.edges[1].color[4] == C.EDGE, "the others: a faint frame")
-- a dim card: too high for the level (Blackfathom Deeps at the client's level 22)
local bfd = B.grid:CardOf("bfd")
assert(bfd and bfd.dim and bfd.tex.desaturated == true and bfd.name.textColor[1] == C.DIM[1], "too high: dim")
assert(bfd.line2:GetText() == "", "no values without items")
-- the last row holds the rest; scrolled to the end, its empty places show no card
local rest = (#all - 1) % 3 + 1
assert(#B.grid.items[#B.grid.items] == rest, "the last row: " .. rest)
B.grid.offset = math.max(0, #B.grid.items - B.grid.rowCount)
B.grid:Redraw()
local lastRow = B.grid.rows[#B.grid.items - B.grid.offset]
for i, c in ipairs(lastRow.cards) do assert(c:IsShown() == (i <= rest), "the last row's card " .. i) end
B.grid.offset = 0
B.grid:Redraw()
-- the tooltip reads the card's entry
thanes = B.grid:CardOf("thanes")
thanes:GetScript("OnEnter")(thanes)
thanes:GetScript("OnLeave")(thanes)

---------------------------------------------------------------------------
-- a click opens the detail view; the link back the start
---------------------------------------------------------------------------
B.grid:CardOf("deadmines"):Click()
assert(AmisiaDB.settings.bis.dungeon == "deadmines", "the click chooses")
assert(B.back:IsShown() and B.art:IsShown() and B.header:IsShown() and B.detail:IsShown(), "the detail view")
assert(not B.grid:IsShown() and not B.next:IsShown() and not B.why:IsShown() and not B.sorts.level:IsShown(), "no start parts")
assert(B.back:GetText() == "< Alle Dungeons" and B.back.isLink, "the quiet link back")
assert(B.art.title:GetText() == "The Deadmines" and B.header.ButtonText:GetText() == "The Deadmines · Bosse")
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(B, T.PAGE_W, T.PAGE_H)
Lay.row("head row", B.back, B.spec)
local artTop = -(G.ROW_H + G.GAP)
assert(B.art.points.TOPLEFT.y == artTop, "the image right under the head row")
local _, artBottom = Lay.vspan(B.art)
local headTop = Lay.vspan(B.header)
assert(headTop == artBottom - G.GAP, "the header right under the image")
local listTop = Lay.vspan(B.detail)
local BOSS_ROW_H = 24 -- a row of the boss list (ROW_H in UI/Pages/Dungeons.lua)
assert(listTop == artTop - NS.DungeonJournalKit.ART_H - G.GAP - T.HEADER_H - G.GAP, "the bosses right under the header: " .. listTop)
assert(B.detail.rowCount >= math.floor((T.PAGE_H + listTop) / BOSS_ROW_H) - 1, "the bosses fill the page: " .. B.detail.rowCount)
Lay.column("detail", B.spec, B.art, B.header, B.detail)
-- leaving the page keeps the view
NS.ShowPage("overview")
NS.ShowPage("dungeons")
assert(B.detail:IsShown() and not B.grid:IsShown(), "the view stays while the session lasts")
-- the link back: the cards, the chosen one in view with its frame
B.back:Click()
assert(B.grid:IsShown() and not B.detail:IsShown() and not B.art:IsShown() and not B.back:IsShown() and B.sorts.chain:IsShown())
assert(B.grid:CardOf("deadmines").chosen and not B.grid:CardOf("thanes").chosen, "the chosen card")
Lay.row("start head row", B.spec, B.sorts.level, B.sorts.value, B.sorts.chain)
-- ns.ShowDungeon opens the detail of that dungeon
NS.ShowPage("overview")
assert(NS.ShowDungeon("thanes") ~= nil)
assert(NS.CurrentPage() == "dungeons" and B.detail:IsShown() and B.art.title:GetText() == "Hall of Thanes", "ShowDungeon: the detail")
-- the journal covers the detail; its own link back returns to the detail
B.plan:Click()
assert(B.pathView:IsShown() and not B.detail:IsShown() and not B.back:IsShown() and not B.grid:IsShown(), "the journal")
for _, f in ipairs(B.planParts) do assert(not f:IsShown(), "a part under the journal") end
-- the spec at the head row's start again: the hidden link leaves no gap
assert(B.spec.points.LEFT and B.spec.points.LEFT.x == 0, "the spec at the start in the journal: " .. tostring(B.spec.points.LEFT and B.spec.points.LEFT.x))
B.pathView.back:Click()
assert(not B.pathView:IsShown() and B.detail:IsShown() and B.back:IsShown(), "back to the detail")
assert(B.spec.points.LEFT.x > 0, "after the link again in the detail")
-- the hint by the view
assert(B.hint:GetText():find("Strg-Klick", 1, true), "the detail's hint")
B.back:Click()
assert(B.hint:GetText():find("Klick auf eine Kachel", 1, true), B.hint:GetText())

---------------------------------------------------------------------------
-- the grid follows the main window's height
---------------------------------------------------------------------------
local F = AmisiaFrame
local before = B.grid.rowCount
assert(before == math.floor((T.PAGE_H + B.top - B:Bottom()) / (C.H + C.GAP)), "the grid fills the page: " .. before)
F.applyHeight(F:GetHeight() + 2 * (C.H + C.GAP))
F.heightDone()
assert(B.grid.rowCount == before + 2, "two more rows of cards: " .. before .. " -> " .. B.grid.rowCount)
F.applyHeight(T.MAIN.H)
F.heightDone()
assert(B.grid.rowCount == before, "back again")

---------------------------------------------------------------------------
-- Raids: the same two views with their own cards
---------------------------------------------------------------------------
NS.ShowPage("raidjournal")
local P = NS.PageFrame("raidjournal")
assert(P.grid:IsShown() and not P.detail:IsShown() and not P.back:IsShown() and not P.art:IsShown(), "the raids' cards first")
local ony = P.grid:CardOf("onyxia")
assert(ony and plain(ony.name:GetText()) == "Onyxia's Lair" and plain(ony.line1:GetText()):find("^Raid 40 · "), plain(ony.line1:GetText()))
assert(ony.dim, "out of reach at 16: dim")
ony:Click()
assert(P.detail:IsShown() and P.back:IsShown() and P.art:IsShown() and not P.grid:IsShown() and not P.next:IsShown(), "the raid's detail")
assert(P.back:GetText() == "< Alle Raids" and AmisiaDB.settings.bis.raid == "onyxia")
local LP = dofile(ADDON_DIR .. "/../tests/layout.lua")(P, T.PAGE_W, T.PAGE_H)
LP.row("raid head row", P.back, P.spec)
assert(P.art.points.TOPLEFT.y == artTop and LP.vspan(P.detail) == listTop, "the same places as on Dungeons")
P.back:Click()
assert(P.grid:IsShown() and not P.detail:IsShown() and P.grid:CardOf("onyxia").chosen)
NS.ShowPage("overview")
assert(NS.ShowRaid("hyjal") ~= nil and P.detail:IsShown() and P.header.ButtonText:GetText() == "Hyjal Summit · Bosse", "ShowRaid: the detail")
-- a raid's entrance on the map goes through ns.ShowDungeon
P.back:Click()
assert(NS.ShowDungeon("onyxia") ~= nil and NS.CurrentPage() == "raidjournal" and P.detail:IsShown(), "ShowDungeon of a raid: its detail")
print("dungeon cards: start view, cards, detail view, back link, ShowDungeon/ShowRaid, raids, the window's height")
