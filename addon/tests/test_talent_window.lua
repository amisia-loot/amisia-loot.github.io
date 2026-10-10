-- The window "Talentrechner" (AmisiaTalentFrame, Pages/Talents.lua): one builder makes the page's
-- view and the window's (profiles TALENT.PAGE and TALENT.BIG), both show the one plan; the window's
-- red button on the page, the side tab, /amisia talente gross; its scale (setting ui.talentScale,
-- Ctrl + mouse wheel, bounds), its position (saved, reset with "Fensterposition zurücksetzen"),
-- Escape; the margins of the outer buttons in both profiles.
local T = NS.Talents
local TT = NS.Theme.TALENT
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

local LEVELS = {}
for l = 10, 60 do LEVELS[#LEVELS + 1] = l end
NS.TALENTS = { build = "test", max = 51, levels = LEVELS, talented = { 9, 8, 7, 6, 5 }, classes = {
    MAGE = { id = 8, tree = 1112, spec = 1482,
        trees = { { 11, "Arcane", 1 }, { 12, "Fire", 2 }, { 13, "Frost", 3 } },
        gates = { [21] = { 101, 102 } },
        nodes = {
            { 101, 1001, 5001, 11, 1, 0, 0, 2, 0, 0, "Arcane Subtlety", "Reduces resistance by {1}.", { { "5", "10" } } },
            { 102, 1002, 5002, 12, 1, 0, 1, 5, 0, 0, "Arcane Focus", "Hit +{1}%.", { { "2", "4", "6", "8", "10" } } },
            { 103, 1003, 5003, 13, 1, 1, 1, 1, { 21, 5 }, { 102 }, "Arcane Concentration", "Clearcasting." },
            { 104, 1004, 5004, 14, 1, 1, 3, 1, { 21, 5 }, 0, "Arcane Mind", "Mind." },
            { 201, 2001, 6001, 21, 2, 0, 0, 5, 0, 0, "Improved Fireball", "Cast -{1} sec.", { { "0.1", "0.2", "0.3", "0.4", "0.5" } } },
            { 301, 3001, 7001, 31, 3, 6, 3, 3, 0, 0, "Frostbite", "Freeze {1}%.", { { "5", "10", "15" } } },
        } },
    WARRIOR = { id = 1, tree = 1117, spec = 1491,
        trees = { { 41, "Arms", 4 }, { 42, "Fury", 5 }, { 43, "Protection", 6 } }, gates = {},
        nodes = { { 401, 4001, 8001, 41, 1, 0, 0, 3, 0, 0, "Improved Heroic Strike", "Cost -{1}.", { { "1", "2", "3" } } } } },
} }
T._reset()
for _, a in ipairs({ "talents-arrow-head-yellow", "talents-arrow-head-gray", "talent-background-mage", "talent-background-warrior" }) do
    STUB.atlases[a] = { 40, 40 }
end
STUB.class, STUB.level = "MAGE", 30

---------------------------------------------------------------------------
-- the margins of both profiles: the outer buttons (frame, glow, rank plate) clear of the tree's edges
---------------------------------------------------------------------------
local function margins(P)
    local size = P.ICON + 2 * TT.FRAME
    local left = math.floor((P.TREE_W - (3 * P.PITCH + size)) / 2)
    local out = math.max(#TT.GLOW, P.PLATE_X)
    local l = left - #TT.GLOW
    local r = P.TREE_W - (left + 3 * P.PITCH + size) - out
    local bottom = P.TREE_H - (P.GRID_TOP + 6 * P.PITCH + size - P.PLATE_Y)
    return l, r, bottom
end
for name, P in pairs({ PAGE = TT.PAGE, BIG = TT.BIG }) do
    local l, r, bottom = margins(P)
    assert(l >= P.MARGIN and r >= P.MARGIN and bottom >= P.MARGIN, ("%s: %d / %d / %d"):format(name, l, r, bottom))
    assert(P.PITCH - P.ICON - 2 * TT.FRAME >= P.ARROW, name .. ": the arrow head fits the gap between two buttons")
end
assert(TT.PAGE.MARGIN >= 8 and TT.BIG.MARGIN >= 14, "8 px on the page, 14 px in the window")
assert(3 * TT.PAGE.TREE_W + 2 * TT.PAGE.TREE_GAP == NS.Theme.PAGE_W, "the page's trees fill its width")
assert(TT.BIG.ICON >= 44 and TT.BIG.TREE_W >= 270 and TT.BIG.ICON > TT.PAGE.ICON, "bigger icons in the window")

---------------------------------------------------------------------------
-- the page has the red button; it opens and closes the window
---------------------------------------------------------------------------
NS.ShowTalents()
local page = NS.TalentsPageFrame()
assert(page and page:IsShown() and page.bigBtn and page.bigBtn.vis ~= false, "the button on the page")
assert(page.bigBtn:GetText() == "Großes Fenster", tostring(page.bigBtn:GetText()))
assert(page.bigBtn.layoutBand == page.bottomRow, "in the bottom row")
assert(page.bigBtn.points.RIGHT and page.bigBtn.points.RIGHT.x == 0, "at its right end")
assert(_G.AmisiaTalentFrame == nil, "nothing built before it is opened")
page.bigBtn:Click()
local win = assert(_G.AmisiaTalentFrame, "the window")
assert(win:IsShown())
local big = win.view
assert(big and big ~= page and big.P == TT.BIG and page.P == TT.PAGE, "one builder, two profiles")
assert(win:GetTitleText():GetText() == "Talentrechner")
assert(win.strata == "FULLSCREEN", "the main window's strata: it stays with the world map")
assert(win.inherits and win.inherits.PortraitFrameTemplate, "W.Window: the client's frame")
local VW = 3 * TT.BIG.TREE_W + 2 * TT.BIG.TREE_GAP
assert(win:GetWidth() == VW + 2 * NS.Theme.WINDOW_PAD, "three big trees and the side padding: " .. win:GetWidth())
assert(win.body.points.TOPLEFT.x == NS.Theme.WINDOW_PAD and -win.body.points.TOPLEFT.y >= NS.Theme.TITLE_H, "under the title bar")
-- the same parts in the window, bigger
for _, k in ipairs({ "class", "level", "talented", "total", "live", "resetAll", "code", "msg", "liveText" }) do
    assert(big[k], "the window has " .. k)
end
assert(big.bigBtn == nil and big.hint and has(big.hint:GetText(), "Linksklick"), "no button to itself; the click hint as footer")
assert(#big.trees == 3 and big.trees[1]._w == TT.BIG.TREE_W and big.trees[1]._h == TT.BIG.TREE_H)
local bb, pb = big.buttons[101], page.buttons[101]
assert(bb and pb and bb ~= pb, "a button per view")
assert(bb._w == TT.BIG.ICON + 2 and pb._w == TT.PAGE.ICON + 2, "44 px and 34 px icons")
assert(bb.plate._w == TT.BIG.PLATE_W and bb.rank.font == TT.BIG.RANK_FONT, "the big rank plate")
assert(big.trees[1].pts.font == TT.BIG.PTS_FONT)
-- the buttons and their plates inside the trees, clear of the edges
for view, P in pairs({ [page] = TT.PAGE, [big] = TT.BIG }) do
    for id, b in pairs(view.buttons) do
        local p = b.points.TOPLEFT
        assert(p.x - #TT.GLOW >= P.MARGIN, id .. " left")
        assert(p.x + b._w + math.max(#TT.GLOW, P.PLATE_X) <= P.TREE_W - P.MARGIN, id .. " right")
    end
end
-- the side tab of the main window is marked while the window shows
local MF = AmisiaFrame
local tab = MF.sideTabs.talents
assert(tab and tab:IsShown() and tab.checked == true, "the tab shows and is marked")
assert(tab.tooltipText == "Talentrechner" and tab.Icon.texture == "Interface\\Icons\\Ability_Marksmanship")
assert(tab.points.TOPLEFT.rel == MF.sideTabs.gear, "under the gear table's tab")
win:Hide()
assert(tab.checked == false, "the tab follows the hide")
STUB.clickTab(tab)
assert(win:IsShown() and tab.checked == true, "a click on the tab opens it")
STUB.clickTab(tab)
assert(not win:IsShown() and tab.checked == false, "and closes it")
-- Escape closes it
local special = false
for _, n in ipairs(UISpecialFrames) do if n == "AmisiaTalentFrame" then special = true end end
assert(special, "Escape closes the window")

---------------------------------------------------------------------------
-- one plan: a click in the window changes the page, a click on the page the window
---------------------------------------------------------------------------
NS.ShowTalentFrame()
assert(win:IsShown())
big.buttons[101]:GetScript("OnClick")(big.buttons[101], "LeftButton")
assert(big.buttons[101].rank:GetText() == "1/2", "the window counts")
assert(page.buttons[101].rank:GetText() == "1/2" and page.trees[1].pts:GetText() == "1 Punkt", "the page follows")
assert(T.Rank(NS.TalentsPlan(), 101) == 1 and AmisiaDB.talents.plans.MAGE ~= nil, "one plan, saved")
page.buttons[201]:GetScript("OnClick")(page.buttons[201], "LeftButton")
assert(big.buttons[201].rank:GetText() == "1/5" and big.trees[2].pts:GetText() == "1 Punkt", "the window follows the page")
assert(big.code:GetText() == page.code:GetText() and has(big.total:GetText(), "2 / 51"), big.total:GetText())
-- a refusal shows in both
page.buttons[103]:GetScript("OnClick")(page.buttons[103], "LeftButton")
assert(page.msg:GetText() ~= "" and big.msg:GetText() == page.msg:GetText(), "the message in both")
-- the class in one, the class in the other
big.class.onPick("WARRIOR")
assert(page.class:GetValue() == "WARRIOR" and page.buttons[401] and big.buttons[401], "the warrior in both")
page.class.onPick("MAGE")
assert(big.class:GetValue() == "MAGE" and big.buttons[101].rank:GetText() == "1/2", "back to the mage's plan in both")
-- the reset of a tree in the window
big.trees[1].reset:Click()
assert(page.buttons[101].rank:GetText() == "0/2" and T.Spent(NS.TalentsPlan(), 1) == 0)
-- a code in the window's box
big.code:SetText("AT1.MAGE.2")
big.code:GetScript("OnEnterPressed")(big.code)
assert(page.buttons[101].rank:GetText() == "2/2" and has(big.msg:GetText(), "übernommen"), tostring(big.msg:GetText()))
-- the level in the window
big.level.minus:Click()
assert(AmisiaDB.talents.level == 59 and page.level.current == 59, "the level in both")
AmisiaDB.talents.level = nil
NS.Refresh()

---------------------------------------------------------------------------
-- the scale: the setting, live; Ctrl + mouse wheel within 70..150, saved
---------------------------------------------------------------------------
local it = NS.SettingItem("ui.talentScale")
assert(it and it.section.key == "ui" and it.type == "slider" and it.min == 70 and it.max == 150 and it.step == 5
    and it.default == 100, "the setting under Oberfläche")
assert(it.label == "Größe des Talentfensters (%)")
assert(win:GetScale() == 1)
NS.Set("ui.talentScale", 120)
assert(math.abs(win:GetScale() - 1.2) < 1e-9, "applied live")
local wheel = win:GetScript("OnMouseWheel")
assert(wheel, "the window takes the mouse wheel")
wheel(win, 1)
assert(NS.Get("ui.talentScale") == 120, "without Ctrl the wheel changes nothing")
_G.IsControlKeyDown = function() return true end
wheel(win, 1)
assert(NS.Get("ui.talentScale") == 125 and AmisiaDB.settings.ui.talentScale == 125 and math.abs(win:GetScale() - 1.25) < 1e-9,
    "Ctrl + wheel up: 5 % more, saved")
wheel(win, -1); wheel(win, -1)
assert(NS.Get("ui.talentScale") == 115)
for _ = 1, 30 do wheel(win, 1) end
assert(NS.Get("ui.talentScale") == 150, "not over 150")
for _ = 1, 30 do wheel(win, -1) end
assert(NS.Get("ui.talentScale") == 70 and math.abs(win:GetScale() - 0.7) < 1e-9, "not under 70")
_G.IsControlKeyDown = function() return false end
NS.Reset("ui.talentScale")
assert(win:GetScale() == 1, "the default again")

---------------------------------------------------------------------------
-- the position: saved after a drag, reset with the others
---------------------------------------------------------------------------
assert(win.points.CENTER, "the centre at first")
win._point, win._x, win._y = "TOPLEFT", 120.4, -80.6
win:GetScript("OnDragStop")(win)
local st = AmisiaDB.settings.talentWindow
assert(st and st.point == "TOPLEFT" and st.x == 120 and st.y == -81, "saved")
win._point = nil
NS.ResetPositions()
assert(st.point == nil and st.x == nil and win.points.CENTER and not win.points.TOPLEFT, "reset with the main window's position")

---------------------------------------------------------------------------
-- the command: /amisia talente gross (en: talents big); a code still goes to the page
---------------------------------------------------------------------------
win:Hide()
NS.Dispatch("talente gross")
assert(win:IsShown(), "/amisia talente gross")
win:Hide()
NS.Dispatch("talents big")
assert(win:IsShown(), "/amisia talents big")
NS.Dispatch("talente groß")
assert(win:IsShown(), "groß with the sharp s")
win:Hide()
NS.Dispatch("talente AT1.MAGE.1")
assert(NS.CurrentPage() == "talents" and not win:IsShown() and page.buttons[101].rank:GetText() == "1/2", "a code: the page")
local found
for _, line in ipairs(NS.SlashHelpLines(false)) do if has(line, "talente [Code|gross]") then found = line end end
assert(found and has(found, "gross: großes Fenster"), tostring(found))

-- without talent data: a message, no window, no tab
local keep = NS.TALENTS
win:Hide()
NS.TALENTS = { classes = {} }
T._reset()
local said
local msg = NS.msg
NS.msg = function(t) said = t end
NS.Dispatch("talente gross")
NS.msg = msg
assert(not win:IsShown() and has(said, "nicht verfügbar"), tostring(said))
NS.UpdateSideTabs()
assert(not tab:IsShown(), "no tab without data")
NS.TALENTS = keep
T._reset()
print("test_talent_window ok")
