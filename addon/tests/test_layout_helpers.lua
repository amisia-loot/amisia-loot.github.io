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
print("layout helpers: rows, right rows, columns, grids, chips by their text")
