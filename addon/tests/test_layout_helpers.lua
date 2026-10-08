-- The layout helpers of Widgets.lua (W.Row, W.Column, W.Grid, W.FitChip) and the design tokens
-- (ns.Theme): positions as the pages placed them by hand before.
local W, T = NS.W, NS.Theme
assert(T and T.CHIP_GAP == 4 and T.CHIP_PAD == 8 and T.HEADER_H == 25 and T.PAGE_W == 602, "the tokens are there")
assert(W.GOLD == T.GOLD and W.TITLE_H == T.TITLE_H, "the old names point at the tokens")

local page = CreateFrame("Frame", nil, UIParent)
page:SetSize(602, 478)
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(page, 602, 478)
local function box(w, h) local f = CreateFrame("Frame", nil, page); f:SetSize(w, h or 20); return f end

-- a row from the left: own widths, the row's gap, an entry's own gap and offset
local a, b, c = box(50), box(46), box(74)
local right = W.Row(page, { a, { b, gap = 10 }, { c, y = -5 } }, 4, 6, -27)
assert(right == 6 + 50 + 10 + 46 + 4 + 74, "the row's end: " .. right)
assert(a.points.TOPLEFT.x == 6 and a.points.TOPLEFT.y == -27)
assert(b.points.TOPLEFT.x == 66 and c.points.TOPLEFT.x == 116 and c.points.TOPLEFT.y == -5)
L.row("row", a, b, c)

-- hidden items are passed over only when asked
a:Show(); c:Show(); b:Hide()
W.Row(page, { a, b, c }, 4, 0, 0, { shown = true })
assert(c.points.TOPLEFT.x == 54, "c moves up to a: " .. c.points.TOPLEFT.x)
W.Row(page, { a, b, c }, 4, 0, 0)
assert(c.points.TOPLEFT.x == 104, "without the option the place stays")

-- a row from the right edge, listed left to right; the gap of an entry stays between the same two
local p1, p2, p3 = box(54), box(54), box(120)
W.Row(page, { p1, p2, { p3, gap = 6 } }, 4, 0, -251, { right = true })
assert(p3.points.TOPRIGHT.x == 0 and p2.points.TOPRIGHT.x == -126 and p1.points.TOPRIGHT.x == -184,
    ("right row: %s %s %s"):format(p1.points.TOPRIGHT.x, p2.points.TOPRIGHT.x, p3.points.TOPRIGHT.x))
L.row("right row", p1, p2, p3)

-- a column: heights, gaps, an entry spanning the width
local h1, r1, r2, h2 = box(560, 25), box(560, 26), box(560, 26), box(560, 25)
local bottom = W.Column(page, { { h1, right = 0 }, r1, r2, { h2, gap = 12, right = 0 } }, 0, 0, 0)
assert(h1.points.TOPRIGHT and h1.points.TOPRIGHT.x == 0 and not r1.points.TOPRIGHT, "only the headers span")
assert(r1.points.TOPLEFT.y == -25 and r2.points.TOPLEFT.y == -51 and h2.points.TOPLEFT.y == -89, "column offsets")
assert(bottom == -114, "the column's end: " .. bottom)
L.column("column", h1, r1, r2, h2)

-- a grid of cards
local cards = {}
for i = 1, 5 do cards[i] = box(295, 112) end
local gb = W.Grid(page, cards, 2, 12, 12, 0, 0)
assert(cards[2].points.TOPLEFT.x == 307 and cards[3].points.TOPLEFT.y == -124 and cards[5].points.TOPLEFT.y == -248)
assert(gb == -360, "the grid's end: " .. gb)
L.row("grid row", cards[1], cards[2])
L.column("grid column", cards[1], cards[3], cards[5])

-- a chip sized to its text: text + 2 x the padding, at least min, at most max
local chip = W.Chip(page, "Weltdrops", 40)
local tw = chip.label:GetStringWidth()
assert(W.FitChip(chip) == tw + 2 * T.CHIP_PAD and chip._w == tw + 16, "text and padding")
assert(W.FitChip(chip, 200) == 200, "the minimum")
assert(W.FitChip(chip, nil, 30) == 30, "the maximum")
local btn = W.Button(page, "Vergeben", 20)
assert(W.FitChip(btn) == btn.Text:GetStringWidth() + 16, "a red button by its own text")
-- the page scaffold: bands from the top, items centred on them, lines, columns, list, footer
local G = T.LAYOUT
local p = W.Page(UIParent)
p:SetSize(602, 478)
assert(p.layoutRole == "page")
local top = p:Bands({ "row", "line", { "line", lines = 2 } })
assert(top == -(22 + 4 + 16 + 4 + 32 + 4), "the content starts under the bands: " .. top)
assert(p.bands[1].points.TOPLEFT.y == 0 and p.bands[2].points.TOPLEFT.y == -26 and p.bands[3].points.TOPLEFT.y == -46)
assert(p.bands[1].layoutRole == "headband" and p.bands[2].layoutRole == "band")
local PL = dofile(ADDON_DIR .. "/../tests/layout.lua")(p, 602, 478)
local pick, c1, c2, txt = W.Picker(p, 150), W.Chip(p, "Eins", 50), W.Chip(p, "Zwei", 50), W.Text(p, T.FONT.hint)
local b1, b2 = W.Button(p, "Hinzufügen", 100), W.Button(p, "Löschen", 80)
p:Place(1, { pick, c1, c2, { txt, fill = true } }, { b1, b2 })
assert(pick.points.LEFT.x == 0 and pick.points.LEFT.rel == p.bands[1] and pick.points.LEFT.y == 0, "centred on the band")
assert(c1.points.LEFT.x == 150 + G.ITEM_GAP and c2.points.LEFT.x == 150 + G.ITEM_GAP + 50 + T.CHIP_GAP, "chips 4 apart, else 6")
assert(b2.points.RIGHT.x == 0 and b1.points.RIGHT.x == -(80 + G.ITEM_GAP), "the buttons up to the right edge")
local tl = c2.points.LEFT.x + 50 + G.ITEM_GAP
assert(txt.points.LEFT.x == tl and txt._w == 602 - tl - (180 + G.ITEM_GAP + G.ITEM_GAP), "the text fills the room: " .. txt._w)
assert(pick.layoutRole == "head" and b2.layoutBand == p.bands[1])
PL.row("head row", pick, c1, c2, txt, b1, b2)
local line = p:Line(2)
assert(line.font == T.FONT.hint and line.points.LEFT.x == G.TEXT_X and line.points.RIGHT.x == -G.TEXT_X and line.layoutRole == "line")
local two = p:Line(3)
assert(two.wordWrap and two.maxLines == 2 and two.points.TOPLEFT and two.points.BOTTOMRIGHT, "a line of two")
local cols = { { "name", 6, 120, "Name" }, { "n", 130, 40, "Anzahl", justify = "RIGHT" } }
local hf, heads = p:Columns(cols)
assert(hf.layoutRole == "colhead" and hf._h == G.COLHEAD_H and hf.points.TOPLEFT.y == top and hf.points.TOPRIGHT.x == -T.SCROLL_ROOM)
assert(heads.name:GetText() == "Name" and heads.name.font == T.FONT.head and heads.n.justifyH == "RIGHT")
local list = p:List(5, 20, function(r) W.Cells(r, cols) end, function(r, e) r.name:SetText(e) end)
assert(list.points.TOPLEFT.y == top - G.COLHEAD_H and list.rows[1].n.justifyH == "RIGHT" and list.rows[1].name.font == T.FONT.text)
p:Footer({ "hint", "data" })
assert(p.footH == 2 * G.LINE_H and p.hint.layoutRole == "foot" and p.data.points.BOTTOMLEFT.y == 0 and p.hint.points.BOTTOMLEFT.y == G.LINE_H)
assert(p:Bottom() == 2 * G.LINE_H + G.GAP)
local go = W.Button(p, "Weg", 60)
p:BottomRow(nil, { go })
assert(p.bottomRow.points.BOTTOMLEFT.y == 2 * G.LINE_H + G.GAP and go.points.RIGHT.rel == p.bottomRow)
assert(p:Bottom() == 2 * G.LINE_H + G.GAP + G.ROW_H + G.GAP, "the content ends above the bottom row")
local e = p:Empty(300)
assert(e.points.TOP.rel == list and e.points.TOP.y == -G.EMPTY_Y and e.layoutRole == "empty")
e:Set("Nichts da", "Noch nichts.")
assert(e:GetText() == "Noch nichts." and e.title:GetText() == "Nichts da")
local d = p:Detail({ top = -40, height = 200, sub = true })
assert(d.points.TOPLEFT.x == G.SPLIT_X and d.title and d.sub and d.body and d.layoutRole == "detail")
local v = W.Page(p, { view = true })
assert(v.isView and v.points.TOPLEFT.y == top and v.layoutRole == "view")
v:Bands({ "row" })
assert(v.bands[1].layoutRole == "band", "a view's first band is not the head row")
print("layout helpers: rows, right rows, columns, grids, chips by their text, the page scaffold")
