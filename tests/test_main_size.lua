-- The main window's width and the minimize bar (D-71, spec docs/specs/2026-11-07-hauptfenster-journal.md
-- step 2): the grip drags the width too (W_MIN to W_MAX, never wider than the screen), the page area
-- follows (T.PAGE_W_NOW), the pages' bands are placed again, the size is remembered and reset with the
-- position; the minimize button folds the window to a small bar at its top right corner, a click on
-- the bar opens it there again, /amisia too, the bar's X closes it.
STUB.officer = false
NS.ShowPage("overview")
local F = AmisiaFrame
local W = AmisiaDB.settings.window
local T, M = NS.Theme, NS.Theme.MAIN
assert(F:GetWidth() == M.W and T.PAGE_W_NOW == T.PAGE_W, "the window's own width")

-- the grip drags both: right and down make it wider and taller, the top left stays
local g = F.grip
F._left, F._top = 100, 900
STUB.cursorX, STUB.cursorY = 500, 300
g.scripts.OnMouseDown(g, "LeftButton")
assert(F.points.TOPLEFT and F.points.TOPLEFT.x == 100 and F.points.TOPLEFT.y == 900, "anchored at its top left")
STUB.cursorX, STUB.cursorY = 700, 250
g.scripts.OnUpdate(g)
assert(F:GetWidth() == M.W + 200 and F:GetHeight() == M.H + 50, F:GetWidth() .. " x " .. F:GetHeight())
g.scripts.OnMouseUp(g, "LeftButton")
assert(not g.scripts.OnUpdate, "the drag ended")
assert(W.w == M.W + 200 and W.h == M.H + 50, "remembered: " .. tostring(W.w) .. " x " .. tostring(W.h))
assert(T.PAGE_W_NOW == T.PAGE_W + 200 and T.PAGE_H == 478 + 50, "the page area follows")
-- a band of a page is placed again: its filling item takes the new room (a page of its own width
-- does not follow)
local Wd = NS.W
local page = Wd.Page(F.content)
page:SetAllPoints(F.content)
page:Bands({ "row" })
local box = CreateFrame("Frame", nil, page)
box:SetSize(50, 20)
local btn = CreateFrame("Frame", nil, page)
btn:SetSize(80, 20)
page:Place(1, { { box, fill = true } }, { btn })
local own = Wd.Page(F.content, { width = 300 })
own:Bands({ "row" })
local box2 = CreateFrame("Frame", nil, own)
own:Place(1, { { box2, fill = true } }, {})
local before, before2 = box:GetWidth(), box2:GetWidth()
F.applySize(M.W + 300, M.H + 50)
F.heightDone()
assert(box:GetWidth() == before + 100, "the filling item grows with the page: " .. before .. " -> " .. box:GetWidth())
assert(box2:GetWidth() == before2, "a page of its own width keeps it")
F.applySize(M.W + 200, M.H + 50)
F.heightDone()
assert(box:GetWidth() == before, "and shrinks back: " .. box:GetWidth())
-- the status line is as wide as the window
assert(F.statusBar.points.TOPRIGHT, "the status line stretches")

-- never past W_MAX nor the screen; never under W_MIN
F.applySize(5000, M.H)
assert(F:GetWidth() == M.W_MAX, F:GetWidth())
UIParent:SetWidth(1000)
F.applySize(M.W_MAX, M.H)
assert(F:GetWidth() == 1000, "never wider than the screen: " .. F:GetWidth())
UIParent:SetWidth(1920)
F.applySize(100, M.H)
assert(F:GetWidth() == M.W_MIN, F:GetWidth())
F.heightDone()
assert(W.w == nil and W.h == nil, "the window's own size is not remembered")

-- the reset of the positions resets the width too
F.applySize(M.W + 300, M.H + 100)
F.heightDone()
assert(W.w == M.W + 300)
NS.ResetPositions()
assert(F:GetWidth() == M.W and F:GetHeight() == M.H and W.w == nil and T.PAGE_W_NOW == T.PAGE_W)

-- minimize: the client's red "-" left of the close button
local b = F.minBtn
assert(b and b.inherits.UIPanelHideButtonNoScripts and b.points.TOPRIGHT.rel == F.CloseButton, "left of the close button")
assert(b._w == M.MIN_SIZE and b._h == M.MIN_SIZE)
assert(F.border == "PortraitFrameTemplateMinimizable" or F.SetBorder == nil, "the corner art for two buttons: " .. tostring(F.border))
NS.ShowPage("awards")
F._right, F._top = 1500, 950
-- a drag of the grip ends with it
g.scripts.OnMouseDown(g, "LeftButton")
b:Click()
local bar = F.mini
assert(not F:IsShown() and bar:IsShown(), "the window folds to the bar")
g.scripts.OnHide(g)   -- the client hides the grip with its window (the stub does not)
assert(not g.scripts.OnUpdate, "the drag ended with the window")
assert(bar._w == M.MINI.W and bar._h == M.MINI.H and bar.inherits.TooltipBackdropTemplate, "the bar in the tooltip's frame")
assert(bar.points.TOPRIGHT.x == 1500 and bar.points.TOPRIGHT.y == 950, "at the window's top right corner")
assert(bar.name:GetText() == "Amisia" and bar.page:GetText() == "Vergaben", tostring(bar.page:GetText()))
-- a drag moves it; a click the old client may send at the drag's end does not open the window, and
-- the next real click is not swallowed (the client sends none after a drag; every press clears it)
bar.scripts.OnMouseDown(bar, "LeftButton")
bar.scripts.OnDragStart(bar)
bar.scripts.OnDragStop(bar)
bar:Click()
assert(bar:IsShown() and not F:IsShown(), "a drag is no click")
bar.scripts.OnDragStart(bar)
bar.scripts.OnDragStop(bar)
bar.scripts.OnMouseDown(bar, "LeftButton")
-- a click opens the window there again, on the same page
bar._right, bar._top = 1200, 800
bar:Click()
assert(F:IsShown() and not bar:IsShown() and NS.CurrentPage() == "awards", "the window again")
assert(F.points.TOPRIGHT and F.points.TOPRIGHT.x == 1200 and F.points.TOPRIGHT.y == 800, "where the bar was")
assert(W.point == "TOPRIGHT", "and remembered there")
-- /amisia while the bar shows: the window, the bar goes
b:Click()
assert(bar:IsShown())
NS.ToggleMain()
assert(F:IsShown() and not bar:IsShown(), "/amisia opens the window")
-- the bar's X closes it
b:Click()
bar.close:Click()
assert(not bar:IsShown() and not F:IsShown(), "closed")
NS.ToggleMain()
assert(F:IsShown())
print("main size ok")
