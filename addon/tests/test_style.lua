-- The look of Forever's own windows: the stub knows the client's templates and atlases, and every
-- widget inherits the template the client draws it with.

-- every frame and region made from here on, with its parent: the head checks of the side windows
-- look at what a window holds directly
local made = {}
do
    local create = CreateFrame
    _G.CreateFrame = function(kind, name, parent, template)
        local f = create(kind, name, parent, template)
        made[#made + 1] = f
        local fs, tx = f.CreateFontString, f.CreateTexture
        f.CreateFontString = function(self, ...) local r = fs(self, ...); made[#made + 1] = r; return r end
        f.CreateTexture = function(self, ...) local r = tx(self, ...); made[#made + 1] = r; return r end
        return f
    end
end

---------------------------------------------------------------------------
-- the stub: templates, atlases, check buttons, scroll bars
---------------------------------------------------------------------------
local root = CreateFrame("Frame", nil, UIParent)
root:SetSize(300, 200)

-- an unknown template fails as in the client, a missing one too
assert(not pcall(CreateFrame, "Frame", nil, root, "NoSuchTemplate"), "an unknown template fails")
STUB.missingTemplates.SharedButtonSmallTemplate = true
assert(not pcall(CreateFrame, "Button", nil, root, "SharedButtonSmallTemplate"), "a missing template fails")
STUB.missingTemplates.SharedButtonSmallTemplate = nil
local rb = CreateFrame("Button", nil, root, "SharedButtonSmallTemplate")
assert(rb.inherits.SharedButtonSmallTemplate and rb.template == "SharedButtonSmallTemplate")
assert(rb.Left and rb.Right and rb.Center and rb.Text, "the three slices and the text")
assert(rb.scripts.OnEnable and rb.scripts.OnMouseDown and rb.scripts.OnSizeChanged, "the template's own scripts")
-- several templates at once, split at the commas
local hdr = CreateFrame("Button", nil, root, "ListHeaderVisualTemplate, ListHeaderCodeTemplate")
assert(hdr.inherits.ListHeaderVisualTemplate and hdr.inherits.ListHeaderCodeTemplate)
assert(hdr.ButtonText and hdr.CollapseButton and hdr.CollapseButton.Icon)
local clicks = 0
hdr:SetClickHandler(function(self, button) clicks = clicks + 1 end)
hdr:Click(); assert(clicks == 1, "the click handler runs")
hdr:SetHeaderText("Raid"); assert(hdr.ButtonText:GetText() == "Raid")
hdr:SetTitleColor(false, NORMAL_FONT_COLOR); assert(hdr.titleColors[false] == NORMAL_FONT_COLOR)
hdr:UpdateCollapsedState(true); assert(hdr.collapsed == true)
-- the portrait frame
local win = CreateFrame("Frame", "AmisiaStubWindow", UIParent, "PortraitFrameTemplate")
assert(win.NineSlice and win.Bg and win.TopTileStreaks and win.PortraitContainer.portrait and win.TitleContainer.TitleText and win.CloseButton)
assert(win.NineSlice:GetFrameLevel() == 500 and win.TitleContainer:GetFrameLevel() == 510 and win.CloseButton:GetFrameLevel() == 510)
assert(AmisiaStubWindowCloseButton == win.CloseButton, "named children get global names")
win:SetPortraitToAsset("x"); assert(win.portraitAsset == "x")
win:SetTitle("Titel"); assert(win:GetTitleText():GetText() == "Titel")
win:SetBorder("ButtonFrameTemplateNoPortrait"); assert(win.border == "ButtonFrameTemplateNoPortrait")
win:SetPortraitShown(false); assert(not win.PortraitContainer.portrait:IsShown())
-- the client's close button hides through HideUIPanel, which is blocked in combat
win:Show(); win.CloseButton:Click(); assert(not win:IsShown(), "the close button hides")
win:Show(); STUB.combat = true
assert(not pcall(win.CloseButton.Click, win.CloseButton), "HideUIPanel is blocked in combat")
STUB.combat = false
-- check buttons toggle themselves before OnClick
assert(not pcall(CreateFrame, "Button", nil, root, "MinimalCheckboxTemplate"), "the check box needs a CheckButton")
local cb = CreateFrame("CheckButton", nil, root, "MinimalCheckboxTemplate")
local seenChecked
cb:SetScript("OnClick", function(self) seenChecked = self:GetChecked() end)
cb:Click(); assert(seenChecked == true and cb:GetChecked() == true, "toggled before OnClick")
cb:SetChecked(nil); assert(cb:GetChecked() == false)
-- the addon's toggle: 18 x 18, its state textures pinned to the button (they come in atlas size)
local tg = NS.W.Toggle(root)
assert(tg._w == 18 and tg._h == 18)
for _, key in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "DisabledCheckedTexture" }) do
    local t = tg[key]
    assert(t and t.points.TOPLEFT and t.points.TOPLEFT.rel == tg and t.points.BOTTOMRIGHT and t.points.BOTTOMRIGHT.rel == tg,
        key .. " fills the button")
end
-- edit boxes
local sb = CreateFrame("EditBox", nil, root, "SearchBoxTemplate")
assert(sb.Left and sb.Middle and sb.Right and sb.Instructions and sb.searchIcon and sb.clearButton)
assert(sb.Instructions:GetText() == SEARCH and SEARCH == "Suchen")
-- the addon's search box: the cap moves in by 5, the magnifier with it
local asb = NS.W.SearchBox(root, 150)
assert(asb.Left.points.LEFT.x == 0 and asb.searchIcon.points.LEFT.x == 6 and asb.searchIcon.points.LEFT.y == -1,
    "the magnifier sits inside the field")
local ib = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
assert(ib.Left and ib.Middle and ib.Right and ib.Left.points.LEFT.x == -5, "the left edge sits 5 px outside")
-- the minimal scroll bar
local bar = CreateFrame("EventFrame", nil, root, "MinimalScrollBar")
assert(bar:GetWidth() == 8, "8 px wide")
local got
bar:RegisterCallback(BaseScrollBoxEvents.OnScroll, function(owner, pct) got = pct end, root)
bar:SetHideIfUnscrollable(true)
bar:SetVisibleExtentPercentage(0.5); bar:SetPanExtentPercentage(0.25)
assert(bar:IsShown() and bar.visible == 0.5 and bar.pan == 0.25)
STUB.scrollBar(bar, 1); assert(got == 1 and bar.scroll == 1)
bar:ScrollStepInDirection(-1); assert(got == 0.75)
bar:SetVisibleExtentPercentage(1); assert(not bar:IsShown(), "hidden while all fits")
-- ScrollUtil ties a scroll frame to a bar
local sf = CreateFrame("ScrollFrame", nil, root)
ScrollUtil.InitScrollFrameWithScrollBar(sf, bar)
assert(STUB.scrollPairs[#STUB.scrollPairs][1] == sf and STUB.scrollPairs[#STUB.scrollPairs][2] == bar)
assert(sf.scripts.OnMouseWheel, "the wheel goes through the bar")
-- the side tab
local tab = CreateFrame("Frame", nil, root, "LargeSideTabButtonTemplate")
assert(tab.Icon and tab.SelectedTexture and tab:GetWidth() == 43 and tab:GetHeight() == 50)
local tabbed
tab:SetCustomOnMouseUpHandler(function(self, button, upInside) tabbed = button == "LeftButton" and upInside end)
STUB.clickTab(tab); assert(tabbed == true)
tab:SetChecked(true); assert(tab.checked == true)
local tip = CreateFrame("Frame", nil, root, "TooltipBackdropTemplate")
assert(tip.NineSlice)
-- atlases: known ones answer their size, a missing one answers nothing and does not draw
assert(C_Texture.GetAtlasInfo("Professions_Recipe_Active").width > 0)
assert(C_Texture.GetAtlasInfo("no-such-atlas") == nil)
STUB.missingAtlases["common-insideframe"] = true
assert(C_Texture.GetAtlasInfo("common-insideframe") == nil)
local tx = root:CreateTexture()
assert(tx:SetAtlas("common-insideframe") == false and tx.atlas == nil, "a missing atlas draws nothing")
STUB.missingAtlases["common-insideframe"] = nil
assert(tx:SetAtlas("common-insideframe") == true and tx.atlas == "common-insideframe")
assert(STUB.atlasCalls["common-insideframe"] >= 2, "every SetAtlas is counted")
local r, g, b = NORMAL_FONT_COLOR:GetRGB()
assert(r == 1 and g > 0.8 and b == 0)

---------------------------------------------------------------------------
-- layout: inside the root, template widths
---------------------------------------------------------------------------
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(root, 300, 200)
local bar2 = CreateFrame("EventFrame", nil, root, "MinimalScrollBar")
bar2:SetPoint("TOPLEFT", 288, -10)
bar2:SetPoint("BOTTOMLEFT", 288, 10)
local l, r2 = L.span(bar2)
assert(l == 288 and r2 == 296, "the width of the template: " .. l .. ".." .. r2)
L.inside("bar", bar2)
bar2:SetPoint("TOPLEFT", 296, -10)
bar2:SetPoint("BOTTOMLEFT", 296, 10)
assert(not pcall(L.inside, "bar", bar2), "a bar past the edge is outside")

---------------------------------------------------------------------------
-- widgets: each one inherits the client's template
---------------------------------------------------------------------------
local W = NS.W
local page = CreateFrame("Frame", nil, UIParent)
page:SetSize(602, 478)

-- the red button: SharedButtonSmallTemplate, 22 high, 20 on request; the template's scripts stay
local clicked = 0
local btn = W.Button(page, "Los", 110, function() clicked = clicked + 1 end)
assert(btn.inherits.SharedButtonSmallTemplate and btn._w == 110 and btn._h == 22 and btn:GetText() == "Los")
btn:Click(); assert(clicked == 1)
btn:Disable(); btn:Enable(); btn:GetScript("OnMouseDown")(btn); btn:GetScript("OnSizeChanged")(btn)
assert(btn.tplRuns.OnDisable == 1 and btn.tplRuns.OnEnable == 1 and btn.tplRuns.OnMouseDown == 1 and btn.tplRuns.OnSizeChanged == 1,
    "the template's own scripts are kept")
local small = W.Button(page, "Vergeben", 64, nil, { height = 20 })
assert(small._h == 20 and small._w == 64)
-- a missing template: the client's old panel button
STUB.missingTemplates.SharedButtonSmallTemplate = true
local old = W.Button(page, "Alt", 80, function() clicked = clicked + 1 end)
STUB.missingTemplates.SharedButtonSmallTemplate = nil
assert(old.inherits.UIPanelButtonTemplate and old:GetText() == "Alt" and old._h == 22)
old:Click(); assert(clicked == 2)

-- the check box falls back to its own box
STUB.missingTemplates.MinimalCheckboxTemplate = true
local seen
local tog = W.Toggle(page, function(v) seen = v end)
STUB.missingTemplates.MinimalCheckboxTemplate = nil
assert(tog.inherits == nil and tog._w == 18)
tog:Click(); assert(seen == true and tog:GetChecked() and tog.checked == true, "the old box turns itself once")
tog:Click(); assert(seen == false and not tog:GetChecked())

-- edit boxes: the input box template, the border inside the field, the text indented
for _, e in ipairs({ W.LineEdit(page, 150), W.TimeBox(page, 60) }) do
    assert(e.inherits.InputBoxTemplate, "an input box")
    assert(e.Left.points.LEFT.x == 0, "the left edge inside the field")
    assert(e.insets and e.insets[1] == 6 and e.insets[2] == 4, "the text indented")
    assert(e.scripts.OnEditFocusGained and not (e.tplRuns or {}).OnEditFocusGained, "the template's own")
    e:SetFocus(); e:ClearFocus()
    assert(not (e.tplRuns or {}).OnEditFocusGained and not (e.tplRuns or {}).OnEditFocusLost, "the addon's focus scripts replace the template's")
end
local tb = W.TimeBox(page, 60)
tb:SetText("19:30"); tb:SetFocus(); assert(tb.scripts.OnEscapePressed)
tb.scripts.OnEscapePressed(tb); assert(not tb:HasFocus())

-- the search box: the client's search box, the same commits as a line edit
local got, commits = nil, 0
local sbox = W.SearchBox(page, 172, function(text) got = text; commits = commits + 1 end, "Name oder Item")
assert(sbox.inherits.SearchBoxTemplate and sbox._w == 172)
assert(sbox.Instructions:GetText() == "Name oder Item" and sbox.Left.points.LEFT.x == 0)
sbox:SetFocus(); sbox:SetText("Brust"); sbox.scripts.OnTextChanged(sbox, true)
assert(not sbox.Instructions:IsShown() and sbox.clearButton:IsShown(), "the template still runs")
sbox.scripts.OnEnterPressed(sbox)
assert(got == "Brust" and commits == 1 and not sbox:HasFocus(), "Enter commits once and leaves")
sbox:SetFocus(); sbox:SetText("Quatsch"); sbox.scripts.OnEscapePressed(sbox)
assert(sbox:GetText() == "Brust" and commits == 1 and not sbox:HasFocus(), "Escape restores without a commit")
sbox:SetFocus(); sbox:SetText("Helm"); sbox:ClearFocus()
assert(got == "Helm" and commits == 2, "leaving commits")
sbox.clearButton:Click()
assert(sbox:GetText() == "" and got == "" and commits == 3, "the clear button empties and commits")
sbox:SetFocus(); sbox:SetText("Ring"); sbox.clearButton:Click()
assert(got == "" and commits == 4 and not sbox:HasFocus(), "in the box: once, through the lost focus")
local plain = W.SearchBox(page, 100)
assert(plain.Instructions:GetText() == "Suchen", "the client's word for search")
STUB.missingTemplates.SearchBoxTemplate = true
local fb = W.SearchBox(page, 100, function(text) got = text end, "Name oder Item")
STUB.missingTemplates.SearchBoxTemplate = nil
assert(fb.inherits.InputBoxTemplate and fb.Instructions:GetText() == "Name oder Item", "a line edit with the hint")
fb:SetFocus(); fb:SetText("x"); fb.scripts.OnEnterPressed(fb); assert(got == "x")

-- the inset: Forever's inside frame, no ground of its own; a ground on request
local inset = W.Inset(page)
assert(inset.border.atlas == "common-insideframe" and inset.border.points.TOPLEFT and inset.border.points.BOTTOMRIGHT)
assert(inset.ground == nil)
inset.fill("Professions-background-summarylist"); assert(inset.ground.atlas == "Professions-background-summarylist")
local tinted = W.Inset(page); tinted.fill(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.16)
assert(tinted.ground.color[4] == 0.16)
STUB.missingAtlases["common-insideframe"] = true
local flatInset = W.Inset(page)
STUB.missingAtlases["common-insideframe"] = nil
assert(flatInset.edges and #flatInset.edges == 4, "without the atlas a thin frame of its own")

-- the selection bar: the recipe list's glow, a gold area without the atlas
local row = CreateFrame("Button", nil, page)
local sel = W.SelectBar(row)
assert(sel.atlas == "Professions_Recipe_Active" and not sel:IsShown() and sel.points.TOPLEFT and sel.points.BOTTOMRIGHT)
STUB.missingAtlases.Professions_Recipe_Active = true
local sel2 = W.SelectBar(row)
STUB.missingAtlases.Professions_Recipe_Active = nil
assert(sel2.atlas == nil and sel2.color and sel2.color[1] == W.GOLD[1] and sel2.color[4] > 0, "a gold area stays visible")
sel2:Show(); assert(sel2:IsShown())

-- the section header: the client's list header, 25 high, gold, collapsible on request
local toggled
local hdr2 = W.SectionHeader(page, "Ausrüstung", true, function(collapsed) toggled = collapsed end)
assert(hdr2.inherits.ListHeaderVisualTemplate and hdr2.inherits.ListHeaderCodeTemplate and hdr2._h == 25)
assert(hdr2.ButtonText:GetText() == "Ausrüstung" and hdr2.titleColors[false] == NORMAL_FONT_COLOR)
assert(hdr2.CollapseButton:IsShown() and hdr2.customClickHandler and hdr2.tplRuns == nil, "a click handler, not OnClick")
hdr2:Click(); assert(toggled == true and hdr2.collapsed == true, "a click collapses")
hdr2:Click(); assert(toggled == false and hdr2.collapsed == false)
hdr2:SetCollapsed(true); assert(hdr2.CollapseButton.collapsed == true)
local fixed = W.SectionHeader(page, "Oberfläche", false)
assert(not fixed.CollapseButton:IsShown(), "no minus without collapsing")
fixed:Click(); assert(not fixed.collapsed)
-- a plain bar takes no mouse: no hover, no call into the shared tooltip
assert(fixed.mouseEnabled == false, "a non-collapsible bar ignores the mouse")
fixed.scripts.OnEnter(fixed); fixed.scripts.OnLeave(fixed)
assert(fixed.tplRuns == nil or (not fixed.tplRuns.OnEnter and not fixed.tplRuns.OnLeave), "the template's hover scripts are gone")
assert(hdr2.mouseEnabled ~= false and hdr2.scripts.OnEnter, "a collapsible bar keeps its hover")
STUB.missingTemplates.ListHeaderVisualTemplate = true
local hdr3 = W.SectionHeader(page, "Gilde", true, function(c) toggled = c end)
STUB.missingTemplates.ListHeaderVisualTemplate = nil
assert(hdr3.inherits == nil and hdr3._h == 25 and hdr3.ButtonText:GetText() == "Gilde")
hdr3:Click(); assert(toggled == true and hdr3.collapsed == true)

-- a scroll frame gets the minimal bar 4 px to its right; without ScrollUtil the wheel stays
local sf = CreateFrame("ScrollFrame", nil, page)
sf:SetPoint("TOPLEFT", 10, -10)
sf:SetPoint("BOTTOMRIGHT", -26, 10)
local sbar = W.Scroll(sf, page)
assert(sbar and sbar.inherits.MinimalScrollBar and sf.bar == sbar and sbar.hideIfUnscrollable)
local PL = dofile(ADDON_DIR .. "/../tests/layout.lua")(page, 602, 478)
local sl, sr = PL.span(sbar)
assert(sl == 602 - 26 + 4 and sr == sl + 8, "4 px to the right, 8 wide: " .. sl .. ".." .. sr)
PL.inside("scroll bar", sbar)
local keep = ScrollUtil.InitScrollFrameWithScrollBar
ScrollUtil.InitScrollFrameWithScrollBar = nil
local sf2 = CreateFrame("ScrollFrame", nil, page)
assert(W.Scroll(sf2, page) == nil and sf2.scripts.OnMouseWheel, "only the wheel")
sf2.vrange = 100
sf2.scripts.OnMouseWheel(sf2, -1); assert(sf2:GetVerticalScroll() > 0)
sf2.scripts.OnMouseWheel(sf2, 5); assert(sf2:GetVerticalScroll() == 0)
ScrollUtil.InitScrollFrameWithScrollBar = keep

-- a list with the bar: outside the list on the right, hidden while all fits
local list = W.List(page, 12, 20, function(r) r.text = W.Text(r) end, function(r, item) r.text:SetText(item) end)
list:SetPoint("TOPLEFT", 0, 0)
list:SetPoint("TOPRIGHT", -12, 0)
local bar = list.bar
assert(bar and bar.inherits.MinimalScrollBar, "the list's bar")
assert(bar.points.TOPLEFT.rel == list and bar.points.TOPLEFT.relPoint == "TOPRIGHT" and bar.points.TOPLEFT.x == 4)
assert(bar.points.BOTTOMLEFT.rel == list and bar.points.BOTTOMLEFT.relPoint == "BOTTOMRIGHT" and bar.points.BOTTOMLEFT.x == 4)
PL.row("list", list, bar)
PL.inside("list bar", bar)
local items = {}
for i = 1, 30 do items[i] = "Eintrag " .. i end
list:SetItems(items)
assert(math.abs(bar.visible - 12 / 30) < 1e-9 and bar:IsShown(), "visible 12 of 30")
assert(math.abs(bar.pan - 1 / 18) < 1e-9 and bar.scroll == 0)
list.scripts.OnMouseWheel(list, -1)
assert(list.offset == 1 and math.abs(bar.scroll - 1 / 18) < 1e-9 and list.rows[1].text:GetText() == "Eintrag 2", "the wheel moves the bar")
STUB.scrollBar(bar, 1)
assert(list.offset == 18 and list.rows[1].text:GetText() == "Eintrag 19" and list.rows[12].text:GetText() == "Eintrag 30", "the bar shows the end")
STUB.scrollBar(bar, 0.5)
assert(list.offset == 9, "rounded: " .. list.offset)
-- one wheel notch is one row over the list and over its bar alike (the controller's scalar is 2.0)
STUB.scrollBar(bar, 0)
assert(list.offset == 0)
bar.scripts.OnMouseWheel(bar, -1)
assert(list.offset == 1, "the bar's wheel steps one row, not two: " .. list.offset)
list.scripts.OnMouseWheel(list, -1)
assert(list.offset == 2, "the list's wheel steps one row")
bar.scripts.OnMouseWheel(bar, 1)
assert(list.offset == 1, "and back one row")
list:SetItems({ "a", "b", "c", "d", "e" })
assert(not bar:IsShown() and list.offset == 0 and list.rows[1].text:GetText() == "a", "all fits: no bar")
list:SetItems({})
assert(not bar:IsShown())
local still = W.List(page, 3, 20, function() end, function() end, { bar = false })
assert(still.bar == nil, "no bar for a list that never scrolls")
-- the hover on rows falls back to a light area without the atlas
STUB.missingAtlases.Professions_Recipe_Hover = true
local flatList = W.List(page, 2, 20, function() end, function() end)
STUB.missingAtlases.Professions_Recipe_Hover = nil
assert(flatList.rows[1].hover.atlas == nil and flatList.rows[1].hover.color[4] == 0.08)

-- the chip without its atlas: the flat look of before
STUB.missingAtlases["common-dropdown-b-button"] = true
local flatChip = W.Chip(page, "MS", 30)
STUB.missingAtlases["common-dropdown-b-button"] = nil
assert(flatChip.edges and flatChip.bg.color and flatChip.bg.atlas == nil)
flatChip:SetOn(false); assert(flatChip.bg.color[4] == 0.04)

---------------------------------------------------------------------------
-- the window factory
---------------------------------------------------------------------------
assert(W.TITLE_H == 24)
local shownCount, vis = 0, 0
local win2 = W.Window("AmisiaStyleWindow", 806, 560, { portrait = "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia",
    title = "Amisia", strata = "FULLSCREEN", background = "Profession-Background-Overview",
    onShow = function() shownCount = shownCount + 1 end, onVisibility = function() vis = vis + 1 end })
assert(win2 == AmisiaStyleWindow and win2.inherits.PortraitFrameTemplate and win2._w == 806 and win2._h == 560)
assert(win2.portraitAsset == "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia" and win2.border == nil)
assert(win2:GetTitleText():GetText() == "Amisia" and win2.strata == "FULLSCREEN")
assert(win2.Bg.atlas == "Profession-Background-Overview" and not win2.TopTileStreaks:IsShown(), "Forever's profession ground")
assert(win2.toplevel and not win2:IsShown())
local found
for _, n in ipairs(UISpecialFrames) do if n == "AmisiaStyleWindow" then found = true end end
assert(found, "Escape closes it")
assert(win2.scripts.OnDragStart and win2.scripts.OnDragStop)
local v0 = vis
win2:Show(); assert(shownCount == 1 and vis == v0 + 1)
-- the close button hides directly, in combat too
STUB.combat = true
win2.CloseButton:Click()
STUB.combat = false
assert(not win2:IsShown() and vis == v0 + 2, "closed in combat")
-- a dialog: no portrait, the border without one, the title in the middle
local dlg = W.Window("AmisiaStyleDialog", 380, 248, { title = "Vergabe", strata = "FULLSCREEN_DIALOG" })
assert(dlg.border == "ButtonFrameTemplateNoPortrait" and not dlg.PortraitContainer.portrait:IsShown())
assert(dlg.TitleContainer.points.TOPLEFT.x == 0 and dlg.TitleContainer.points.TOPRIGHT.x == 0, "the title over the whole bar")
assert(dlg.Bg.atlas == nil and dlg.TopTileStreaks:IsShown(), "the template's rock ground stays")
-- a missing atlas keeps the rock
STUB.missingAtlases["Profession-Background-Overview"] = true
local rock = W.Window("AmisiaStyleRock", 300, 200, { background = "Profession-Background-Overview" })
STUB.missingAtlases["Profession-Background-Overview"] = nil
assert(rock.Bg.atlas == nil and rock.Bg.texture == "Interface\\FrameGeneral\\UI-Background-Rock")
-- without the template: the flat window of before, with the same fields
STUB.missingTemplates.PortraitFrameTemplate = true
local flat = W.Window("AmisiaStyleFlat", 360, 300, { title = "Amisia Rolls", portrait = "x" })
STUB.missingTemplates.PortraitFrameTemplate = nil
assert(flat == AmisiaStyleFlat and flat.inherits == nil and flat.edges, "a flat window")
assert(flat:GetTitleText():GetText() == "Amisia Rolls" and flat.TitleContainer.TitleText == flat:GetTitleText())
flat:SetTitle("Neu"); assert(flat:GetTitleText():GetText() == "Neu")
flat:SetPortraitToAsset("y")
flat:Show(); STUB.combat = true; flat.CloseButton:Click(); STUB.combat = false
assert(not flat:IsShown(), "the close button works in combat")

-- the picker's panel opens above a dialog's frame (level 500) and title (510)
local inner = CreateFrame("Frame", nil, dlg)
local pk = W.Picker(inner, 150, function() end)
pk:SetValues({ { value = 1, text = "Eins" } })
dlg:Show()
pk:Click()
assert(AmisiaPicker:IsShown() and AmisiaPicker:GetFrameLevel() > dlg.TitleContainer:GetFrameLevel()
    and AmisiaPicker:GetFrameLevel() > dlg.NineSlice:GetFrameLevel(), "above the frame: " .. AmisiaPicker:GetFrameLevel())
assert(AmisiaPicker:GetFrameLevel() <= 9000)
assert(AmisiaPicker.filter.inherits.SearchBoxTemplate and AmisiaPicker.filter.Instructions:GetText() == "Suchen", "the filter is a search box")
assert(AmisiaPicker.bg.atlas == "common-dropdown-bg" and AmisiaPicker.edges == nil)
assert(AmisiaPicker.list.points.TOPRIGHT.x == -18 and AmisiaPicker.list.bar, "the rows end before the bar")
local PP = dofile(ADDON_DIR .. "/../tests/layout.lua")(AmisiaPicker, AmisiaPicker:GetWidth(), AmisiaPicker:GetHeight())
PP.row("picker list", AmisiaPicker.list, AmisiaPicker.list.bar)
PP.inside("picker bar", AmisiaPicker.list.bar)
pk:Click()
-- the menu as well, when its owner sits in a window of its strata
local mo = W.Button(CreateFrame("Frame", nil, dlg), "Menü", 60)
W.Menu(mo, { { "Eins", function() end } })
assert(AmisiaMenu:GetFrameLevel() > 510, "the menu above the dialog's frame: " .. AmisiaMenu:GetFrameLevel())
AmisiaMenu:Hide()

---------------------------------------------------------------------------
-- the main window: Forever's frame, the status bar, the page list, the side tabs
---------------------------------------------------------------------------
STUB.officer = true
NS.ShowPage("overview")
local MF = AmisiaFrame
assert(MF and MF:IsShown() and MF.inherits.PortraitFrameTemplate and MF._w == 806 and MF._h == 560)
assert(MF.strata == "FULLSCREEN")
assert(MF.portraitAsset == "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia", "the Amisia portrait")
local mtitle = MF:GetTitleText():GetText()
assert(mtitle:sub(1, 7) == "Amisia " and mtitle:find(NS.VERSION, 1, true), mtitle)
assert(MF.Bg.atlas == "Profession-Background-Overview" and not MF.TopTileStreaks:IsShown())
local ML = dofile(ADDON_DIR .. "/../tests/layout.lua")(MF, 806, 560)
-- the head: the status bar right of the portrait, below the title bar, the button beside it
local status, pause = MF.statusBar, MF.pauseBtn
assert(status._w == 453 and status._h == 18 and status.points.TOPLEFT.x == 66 and status.points.TOPLEFT.y == -28)
assert(status.bg.atlas == "Professions-skillbar-bg" and status.frame.atlas == "Professions-skillbar-frame")
assert(status.frame._w == 451 and status.frame._h == 29 and status.frame.points.TOPLEFT)
ML.row("head", status, pause)
local sl = ML.span(status)
local st = ML.vspan(status)
assert(sl >= 58 and st <= -W.TITLE_H, "right of the portrait and below the title bar")
assert(pause._w == 110 and pause._h == 22 and pause.points.TOPRIGHT.x == -10 and pause.points.TOPRIGHT.y == -26)
assert(pause.inherits.SharedButtonSmallTemplate and pause:GetText() == "Pausieren")
assert(MF.statusText._w == 433 and MF.statusText.points.CENTER and MF.statusText.points.CENTER.y == -3)
NS.SetEnabled(false); assert(pause:GetText() == "Fortsetzen" and MF.statusText:GetText():find("pausiert", 1, true))
pause:Click(); assert(NS.IsEnabled() and pause:GetText() == "Pausieren")
-- the page list and the content field side by side, the page area exactly 602 x 478 at (191, -69)
local listIn, contentIn = MF.listInset, MF.contentInset
assert(listIn.border.atlas == "common-insideframe" and listIn.ground.atlas == "Professions-background-summarylist")
assert(contentIn.border.atlas == "common-insideframe")
ML.row("columns", listIn, contentIn)
local ll, lr = ML.span(listIn)
local lt, lb = ML.vspan(listIn)
assert(ll == 6 and lr == 182 and lt == -62 and lb == -554, ("the list 176 x 492: %d..%d, %d..%d"):format(ll, lr, lt, lb))
local il, ir = ML.span(contentIn)
local it, ib = ML.vspan(contentIn)
assert(il == 184 and ir == 800 and it == -62 and ib == -554, ("the field 616 x 492: %d..%d, %d..%d"):format(il, ir, it, ib))
local cl, cr = ML.span(MF.content)
local ct, cb = ML.vspan(MF.content)
assert(cl == 191 and ct == -69 and cr - cl == 602 and ct - cb == 478, ("the page area: %d, %d, %d x %d"):format(cl, ct, cr - cl, ct - cb))
ML.inside("content", MF.content)

-- the sections and their order for a raider, an officer, an expert
local function navShown()
    local out = {}
    for _, e in ipairs(MF.navOrder) do
        out[#out + 1] = e.header and ("#" .. e.header.group) or e.button.key
    end
    return table.concat(out, " ")
end
NS.Set("ui.view", "raider")
NS.Refresh()
assert(navShown() == "#raid overview raidlog awards softres #gear gear map #amisia settings about", navShown())
NS.Set("ui.view", "officer")
NS.Refresh()
assert(navShown() == "#raid overview raids raidlog rolls awards softres #gear gear map #guild export bank #amisia settings about", navShown())
NS.Set("ui.expert", true)
NS.Refresh()
assert(navShown() == "#raid overview raids raidlog rolls awards softres #gear gear map #guild export bank tools #amisia settings about", navShown())
-- the labels of the sections
local labels = {}
for _, e in ipairs(MF.navOrder) do if e.header then labels[#labels + 1] = e.header.ButtonText:GetText() end end
assert(table.concat(labels, ",") == "Raid,Ausrüstung,Gilde,Amisia", table.concat(labels, ","))
-- 4 bars and 13 rows fit the list: headers 25 high, rows 22, 4 px after each section
local NL = dofile(ADDON_DIR .. "/../tests/layout.lua")(MF.nav, 164, 480)
local parts = {}
for _, e in ipairs(MF.navOrder) do
    local fr = e.header or e.button
    parts[#parts + 1] = fr
    NL.inside("nav part", fr)
    if e.header then assert(fr._h == 25) else assert(fr._h == 22 and fr.points.TOPLEFT.x == 8, "rows 22 high, 8 indented") end
end
NL.column("nav", unpack(parts))
local _, lastB = NL.vspan(parts[#parts])
assert(lastB == -(4 * 25 + 13 * 22 + 3 * 4), "packed without gaps but the 4 px after a section: " .. lastB)
-- a row: the icon at x 4, the white name from x 26, 130 wide; the chosen row glows
local ovRow
for _, e in ipairs(MF.navOrder) do if e.button and e.button.key == "overview" then ovRow = e.button end end
assert(ovRow.icon._w == 16 and ovRow.icon.points.LEFT.x == 4)
assert(ovRow.label._w == 130 and ovRow.label.points.LEFT.x == 26)
assert(ovRow.sel.atlas == "Professions_Recipe_Active" and ovRow.sel:IsShown(), "the shown page glows")
assert(ovRow.hover.atlas == "Professions_Recipe_Hover" and ovRow.hover.alpha == 0.5)
-- a click on a row shows its page
local raidsRow
for _, e in ipairs(MF.navOrder) do if e.button and e.button.key == "raids" then raidsRow = e.button end end
raidsRow:Click(); assert(NS.CurrentPage() == "raids" and raidsRow.sel:IsShown() and not ovRow.sel:IsShown())
-- collapsing a section: a click on its bar, the state is kept, the shown page stays open
local raidHdr
for _, e in ipairs(MF.navOrder) do if e.header and e.header.group == "raid" then raidHdr = e.header end end
raidHdr:Click()
assert(AmisiaDB.settings.window.collapsed.raid == true, "the state is saved")
assert(NS.CurrentPage() == "raids", "the shown page stays")
assert(navShown() == "#raid #gear gear map #guild export bank tools #amisia settings about", navShown())
raidHdr = nil
for _, e in ipairs(MF.navOrder) do if e.header and e.header.group == "raid" then raidHdr = e.header end end
assert(raidHdr.collapsed == true, "the bar shows the plus")
-- the collapsed section holding the open page names it in grey; cleared when expanded or elsewhere
do
    local label = raidHdr.ButtonText:GetText()
    assert(label:find("^Raid") and label:find("\194\183", 1, true) and label:find(NS.Panel("raids").label, 1, true)
        and label:find("|cff8f86a3", 1, true), "the collapsed bar names the open page: " .. label)
    NS.ShowPage("settings")
    for _, e in ipairs(MF.navOrder) do if e.header and e.header.group == "raid" then raidHdr = e.header end end
    assert(not raidHdr.ButtonText:GetText():find("\194\183", 1, true), "no marker when the open page is elsewhere")
    NS.ShowPage("raids")
    for _, e in ipairs(MF.navOrder) do if e.header and e.header.group == "raid" then raidHdr = e.header end end
    assert(raidHdr.ButtonText:GetText():find("\194\183", 1, true))
end
-- kept over a refresh and a new build of the list
NS.Refresh(); assert(navShown():sub(1, 12) == "#raid #gear ", navShown())
raidHdr:Click()
assert(not AmisiaDB.settings.window.collapsed.raid and navShown():sub(1, 15) == "#raid overview ", navShown())
for _, e in ipairs(MF.navOrder) do if e.header and e.header.group == "raid" then raidHdr = e.header end end
assert(raidHdr.ButtonText:GetText() == "Raid", "expanded: the plain name, " .. tostring(raidHdr.ButtonText:GetText()))
NS.Reset("ui.expert")
NS.Reset("ui.view")

-- the side tabs: the gear table, the rolls, the soft-reserve import, right outside the frame
local tabs = MF.sideTabs
assert(tabs.gear and tabs.rolls and tabs.softres)
for _, k in ipairs({ "gear", "rolls", "softres" }) do
    assert(tabs[k].inherits.LargeSideTabButtonTemplate and tabs[k].fillToInterior == true, k)
end
assert(tabs.gear.tooltipText == "Ausrüstungstabelle" and tabs.rolls.tooltipText == "Rolls"
    and tabs.softres.tooltipText == "Soft-Reserve-Import")
assert(tabs.gear.Icon.texture == "Interface\\Icons\\INV_Chest_Chain_05"
    and tabs.rolls.Icon.texture == "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
    and tabs.softres.Icon.texture == "Interface\\Icons\\INV_Scroll_03")
NS.Set("ui.view", "officer")
local function tabsShown()
    local out = {}
    for _, k in ipairs({ "gear", "rolls", "softres" }) do if tabs[k]:IsShown() then out[#out + 1] = k end end
    return table.concat(out, " ")
end
assert(tabsShown() == "gear rolls softres", tabsShown())
-- one under the other, the first at the frame's top right, outside the frame
local p1 = tabs.gear.points.TOPLEFT
assert(p1.rel == MF and p1.relPoint == "TOPRIGHT" and p1.x == 0 and p1.y == -60, "the first at the top right")
local p2 = tabs.rolls.points.TOPLEFT
assert(p2.rel == tabs.gear and p2.relPoint == "BOTTOMLEFT" and p2.y == -2)
assert(MF.clampInsets and MF.clampInsets[2] == tabs.gear:GetWidth(), "the tabs stay on the screen")
-- a raider sees the gear tab only; without gear data a raider sees none, an officer two without gaps
NS.Set("ui.view", "raider")
assert(tabsShown() == "gear", tabsShown())
local keepGear = NS.GEAR
NS.GEAR = nil
NS.UpdateSideTabs()
assert(tabsShown() == "", tabsShown())
assert(MF.clampInsets[2] == 0, "no tab shown: no inset on the right")
NS.Set("ui.view", "officer")
assert(MF.clampInsets[2] == tabs.rolls:GetWidth(), "tabs shown again: the inset is back")
assert(tabsShown() == "rolls softres", tabsShown())
assert(tabs.rolls.points.TOPLEFT.rel == MF and tabs.rolls.points.TOPLEFT.y == -60, "no gap for the hidden tab")
assert(tabs.softres.points.TOPLEFT.rel == tabs.rolls)
NS.GEAR = keepGear
NS.UpdateSideTabs()
-- a click opens and closes the window, the tab of an open window is marked
assert(not tabs.rolls.checked)
STUB.clickTab(tabs.rolls)
assert(AmisiaRollFrame and AmisiaRollFrame:IsShown() and tabs.rolls.checked == true, "open and marked")
STUB.clickTab(tabs.rolls)
assert(not AmisiaRollFrame:IsShown() and tabs.rolls.checked == false, "closed and unmarked")
STUB.clickTab(tabs.softres)
assert(AmisiaSoftResFrame:IsShown() and tabs.softres.checked == true)
-- the marking follows the window when it is closed elsewhere
AmisiaSoftResFrame:Hide(); assert(tabs.softres.checked == false, "unmarked on hide")
AmisiaSoftResFrame:Show(); assert(tabs.softres.checked == true, "marked on show")
AmisiaSoftResFrame:Hide()
STUB.clickTab(tabs.gear)
assert(AmisiaGearFrame:IsShown() and tabs.gear.checked == true)
STUB.clickTab(tabs.gear)
assert(not AmisiaGearFrame:IsShown() and not tabs.gear.checked)
-- only the left button
tabs.rolls.scripts.OnMouseUp(tabs.rolls, "RightButton", true)
assert(not AmisiaRollFrame:IsShown())
NS.Reset("ui.view")

-- the close button hides the main window in combat, without HideUIPanel
MF:Show()
STUB.combat = true
MF.CloseButton:Click()
STUB.combat = false
assert(not MF:IsShown(), "closed in combat")

---------------------------------------------------------------------------
-- the side windows: the client's frame, the gear table with the portrait, the dialogs without
---------------------------------------------------------------------------
-- nothing a window holds directly starts in its title bar (above W.TITLE_H), but the template's
-- own parts (title, close button, frame, ground, portrait)
local function headClear(label, win, w, h)
    local WL = dofile(ADDON_DIR .. "/../tests/layout.lua")(win, w, h)
    local own = { [win.TitleContainer] = true, [win.CloseButton] = true, [win.NineSlice or 0] = true,
                  [win.Bg or 0] = true, [win.TopTileStreaks or 0] = true, [win.PortraitContainer or 0] = true }
    local n = 0
    for _, m in ipairs(made) do
        if m.parent == win and not own[m] and m.points and next(m.points) then
            n = n + 1
            local t = WL.vspan(m)
            assert(t <= -W.TITLE_H, ("%s: '%s' starts in the title bar at %d"):format(label, tostring(m.text ~= "" and m.text or m.name), t))
        end
    end
    assert(n > 3, label .. ": the window's parts were seen")
    return WL
end
local function special(name)
    for _, n in ipairs(UISpecialFrames) do if n == name then return true end end
    return false
end
local function closesInCombat(label, win)
    win:Show()
    STUB.combat = true
    win.CloseButton:Click()
    STUB.combat = false
    assert(not win:IsShown(), label .. " closes in combat")
end
local function dialogFrame(label, win, title)
    assert(win.inherits.PortraitFrameTemplate and win.border == "ButtonFrameTemplateNoPortrait", label .. ": the frame without a portrait")
    assert(not win.PortraitContainer.portrait:IsShown() and win.portraitAsset == nil, label .. ": no portrait")
    assert(win.TitleContainer.points.TOPLEFT.x == 0 and win.TitleContainer.points.TOPRIGHT.x == 0, label .. ": the title over the whole bar")
    assert(win:GetTitleText():GetText() == title, label .. ": " .. tostring(win:GetTitleText():GetText()))
    assert(win.strata == "FULLSCREEN_DIALOG", label .. " keeps its strata")
end
STUB.officer = true
NS.Set("ui.view", "officer")

-- the gear table: portrait, the profession ground, the class row right of the portrait
if not AmisiaGearFrame or not AmisiaGearFrame:IsShown() then NS.ToggleGearFrame() end
local GF = AmisiaGearFrame
assert(GF:IsShown() and GF.inherits.PortraitFrameTemplate and GF._w == 820 and GF._h == 640 and GF.strata == "FULLSCREEN")
assert(GF.portraitAsset == "Interface\\AddOns\\Amisia\\Media\\Icons\\Amisia" and GF.border == nil, "the Amisia portrait")
assert(GF.Bg.atlas == "Profession-Background-Overview" and not GF.TopTileStreaks:IsShown())
assert(GF:GetTitleText():GetText():find("^Ausrüstung |c"), "the class in the title: " .. GF:GetTitleText():GetText())
assert(special("AmisiaGearFrame"), "Escape closes the gear table")
local GL = headClear("gear table", GF, 820, 640)
local classes = {}
for _, token in ipairs(NS.GEAR_WEIGHTS.order) do classes[#classes + 1] = GF.classButtons[token] end
assert(#classes == 9 and classes[1].points.TOPLEFT.x == 64 and classes[1].points.TOPLEFT.y == -42, "the class row from x 64")
local cl1 = GL.span(classes[1])
assert(cl1 >= 58, "right of the portrait: " .. cl1)
local _, clr = GL.span(classes[9])
-- 9 steps of 36 from 64 reach 388; the last button is 30 wide and ends 6 px before that
assert(clr == 382, "8 x 36 + 30 from 64: " .. clr)
for _, b in ipairs(classes) do assert(b.edges and #b.edges == 4, "class buttons keep their class-coloured frame") end
-- every class: the class row and its spec chips side by side, inside the frame's border
local keepClass = AmisiaDB.settings.gear.class
for _, token in ipairs(NS.GEAR_WEIGHTS.order) do
    AmisiaDB.settings.gear.class = token
    NS.GearRefresh(true)
    local parts = {}
    for _, b in ipairs(classes) do parts[#parts + 1] = b end
    for _, b in ipairs(GF.specButtons) do if b:IsShown() then parts[#parts + 1] = b end end
    GL.row("class and spec row " .. token, unpack(parts))
    local _, sr = GL.span(parts[#parts])
    assert(sr <= 806, token .. ": the spec chips end inside the frame: " .. sr)
end
AmisiaDB.settings.gear.class = keepClass
NS.GearRefresh(true)
local row2 = { GF.kindButton, GF.factionButton }
for _, b in ipairs(GF.filterButtons) do row2[#row2 + 1] = b end
GL.row("gear second row", unpack(row2))
for _, b in ipairs(row2) do assert(b.bg.atlas and b.bg.atlas:find("^common%-dropdown%-b%-button"), "the shared chips") end
AmisiaDB.settings.gear.view = "list"
NS.GearRefresh(true)
GL.row("gear third row", GF.viewButtons.overview, GF.viewButtons.list, GF.prevCol, GF.colLabel, GF.nextCol, GF.mine)
assert(GF.listRows[1].sel.atlas == "Professions_Recipe_Active", "the chosen slot glows like a recipe")
assert(GF.altPanel.border and GF.altPanel.border.atlas == "common-insideframe", "the alternatives in Forever's inset")
GL.row("gear list and alternatives", GF.listRows[1], GF.altPanel)
GL.inside("gear alternatives", GF.altPanel)
GL.column("gear list view", GF.viewButtons.overview, GF.listRows[1], GF.listRows[17], GF.statusText)
AmisiaDB.settings.gear.view = "overview"
NS.GearRefresh(true)
assert(GF.colHeads[1].mark.atlas == "Professions_Recipe_Active", "the own level range glows")
GL.column("gear overview", GF.viewButtons.overview, GF.colHeads[1], GF.statusText)
-- the own copies of the widgets are gone
do
    local fh2 = assert(io.open(ADDON_DIR .. "/GearFrame.lua", "rb"))
    local gsrc = fh2:read("*a")
    fh2:close()
    for _, fn in ipairs({ "text", "flat", "border", "setBorderColor", "chip" }) do
        assert(not gsrc:find("local function " .. fn .. "%("), "no own copy of " .. fn)
    end
    assert(not gsrc:find("UIPanelCloseButton", 1, true), "the frame's own close button")
end
assert(MF.sideTabs.gear.checked == true, "the gear tab is marked while the table shows")
closesInCombat("the gear table", GF)
assert(MF.sideTabs.gear.checked == false, "the gear tab follows the hide")

-- the roll window: a dialog, the time beside the item under the bar, red buttons
NS.ToggleRollFrame()
local RF = AmisiaRollFrame
assert(RF:IsShown())
dialogFrame("roll window", RF, "Amisia Rolls")
assert(RF._w == 360 and not special("AmisiaRollFrame"), "Escape leaves the roll window open, as before")
local RL = headClear("roll window", RF, 360, RF._h)
assert(RF.header._w == 220 and RF.header.points.TOPLEFT.x == 12 and RF.header.points.TOPLEFT.y == -30)
assert(RF.timer.points.TOPRIGHT.x == -12 and RF.timer.points.TOPRIGHT.y == -28 and RF.timer._w == 110)
RL.row("roll head", RF.header, RF.timer)
local rr1 = RF.rows[1]
assert(rr1.award.inherits.SharedButtonSmallTemplate and rr1.award._w == 64 and rr1.award._h == 18 and rr1.award:GetText() == "Vergeben")
RL.row("roll row", rr1.name, rr1.kind, rr1.value, rr1.hand, rr1.why, rr1.award)
assert(RF.addBtn.inherits.SharedButtonSmallTemplate and RF.addBtn._h == 20 and RF.addBtn:GetText() == "Eintragen")
RL.row("roll entry", RF.namePick, RF.valueEdit, RF.msChip, RF.osChip, RF.addBtn)
for _, b in ipairs({ RF.stopBtn, RF.againBtn, RF.resultBtn }) do assert(b.inherits.SharedButtonSmallTemplate and b._h == 22) end
RL.row("roll buttons", RF.stopBtn, RF.againBtn, RF.resultBtn)
RL.column("roll window", RF.header, rr1, RF.addBtn, RF.note, RF.stopBtn)
assert(MF.sideTabs.rolls.checked == true, "the rolls tab is marked while the window shows")
closesInCombat("the roll window", RF)
assert(MF.sideTabs.rolls.checked == false, "the rolls tab follows the hide")

-- the award dialog: a dialog, everything under the bar as before
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local AD = NS.ShowAwardDialog(STUB.item(32235, "Cursed Vision of Sargeras", 4), NS.Active() or NS.Sessions()[#NS.Sessions()])
assert(AD and AD == AmisiaAwardDialog and AD:IsShown(), "the award dialog opens")
dialogFrame("award dialog", AD, "Vergabe")
assert(AD._w == 380 and AD._h == 248 and special("AmisiaAwardDialog"))
headClear("award dialog", AD, 380, 248)
-- its winner picker opens above the dialog's frame and title
AD.winner:SetValues({ { value = "Fraktur", text = "Fraktur" } })
AD.winner:Click()
assert(AmisiaPicker:IsShown() and AmisiaPicker:GetFrameLevel() > AD.TitleContainer:GetFrameLevel(), "the picker above the dialog")
AD.winner:Click()
closesInCombat("the award dialog", AD)

-- the soft-reserve import: a dialog, the shared edit area, red buttons
NS.ToggleSoftResFrame()
local SF = AmisiaSoftResFrame
assert(SF:IsShown())
dialogFrame("soft-reserve import", SF, "Soft-Reserves")
assert(SF._w == 440 and SF._h == 380 and special("AmisiaSoftResFrame"))
local SL = headClear("soft-reserve import", SF, 440, 380)
assert(SF.box.border and SF.box.border.atlas == "common-insideframe" and SF.box.ground.color[4] == 0.35, "an edit area: inset, dark ground")
assert(SF.editBox == SF.box.box and SF.box.scroll.inherits == nil, "the edit area's own box, no old scroll template")
assert(SF.box.bar and SF.box.bar.inherits.MinimalScrollBar, "the thin bar")
assert(_G.AmisiaSoftResScroll == nil, "the global scroll name is gone")
local bl, bt = SF.box.points.TOPLEFT.x, SF.box.points.TOPLEFT.y
assert(bl == 12 and bt == -50 and SF.box.points.BOTTOMRIGHT.x == -12, "the same place as before")
SL.inside("soft-reserve box", SF.box)
SL.inside("soft-reserve bar", SF.box.bar)
for _, b in ipairs({ SF.applyBtn, SF.clearBtn }) do assert(b.inherits.SharedButtonSmallTemplate and b._h == 22) end
SL.row("soft-reserve buttons", SF.applyBtn, SF.clearBtn)
SL.column("soft-reserve import", SF.dateText, SF.box, SF.previewText, SF.resultText, SF.applyBtn)
-- typing still schedules the preview
SF.editBox:SetText("Vuloo 32235")
SF.editBox.scripts.OnTextChanged(SF.editBox, true)
STUB.tick(1)
assert(SF.previewText:GetText():find("Vorschau", 1, true), "the preview follows the text: " .. tostring(SF.previewText:GetText()))
SF.editBox:SetText("")
assert(MF.sideTabs.softres.checked == true, "the soft-reserve tab is marked while the import shows")
closesInCombat("the soft-reserve import", SF)
assert(MF.sideTabs.softres.checked == false, "the soft-reserve tab follows the hide")

-- the upgrade toast: without the template the flat ground of before
STUB.missingTemplates.TooltipBackdropTemplate = true
NS.BisToast(32235, "wish", STUB.items[32235].link, "Test")
STUB.missingTemplates.TooltipBackdropTemplate = nil
local toast = AmisiaBisToast
assert(toast and toast:IsShown() and toast.inherits == nil and toast.NineSlice == nil, "a flat toast")
assert(toast._w == 320 and toast._h == 58 and toast.strata == "FULLSCREEN_DIALOG")
assert(toast.title:GetText() == "Wunsch droppt!" and toast.source:GetText() == "Test")
toast.scripts.OnClick(toast, "RightButton")
NS.Reset("ui.view")

-- the new texts are Latin-1
local MainFrameFile = ADDON_DIR .. "/MainFrame.lua"
for _, file in ipairs({ MainFrameFile, ADDON_DIR .. "/GearFrame.lua", ADDON_DIR .. "/RollFrame.lua", ADDON_DIR .. "/AwardDialog.lua",
                        ADDON_DIR .. "/SoftRes.lua", ADDON_DIR .. "/Bis.lua", ADDON_DIR .. "/Pages/Settings.lua",
                        ADDON_DIR .. "/Pages/Gear.lua", ADDON_DIR .. "/Pages/Map.lua", ADDON_DIR .. "/Pages/Bank.lua",
                        ADDON_DIR .. "/Pages/About.lua", ADDON_DIR .. "/Pages/Export.lua", ADDON_DIR .. "/Pages/Tools.lua" }) do
    local fh2 = assert(io.open(file, "rb"))
    local s = fh2:read("*a")
    fh2:close()
    for lead in s:gmatch("[\192-\255]") do assert(lead:byte() <= 195, "beyond Latin-1 in " .. file) end
end
local rfh = assert(io.open(ADDON_DIR .. "/Registry.lua", "rb"))
local rsrc = rfh:read("*a")
rfh:close()
for lead in rsrc:gmatch("[\192-\255]") do assert(lead:byte() <= 195, "beyond Latin-1 in Registry.lua") end
assert(NS.PANEL_GROUPS[2].label == "Ausrüstung")
-- every page names its section
for _, p in ipairs(NS.panels) do
    assert(p.group == "raid" or p.group == "gear" or p.group == "guild" or p.group == "amisia", "a group for " .. p.key)
end

---------------------------------------------------------------------------
-- every atlas Amisia sets is one of the design's
---------------------------------------------------------------------------
local ALLOWED = {
    ["Profession-Background-Overview"] = true, ["Professions-background-summarylist"] = true,
    ["Professions_Recipe_Active"] = true, ["Professions_Recipe_Hover"] = true, ["common-insideframe"] = true,
    ["Professions-skillbar-bg"] = true, ["Professions-skillbar-frame"] = true, ["common-dropdown-bg"] = true,
    -- the input border of InputBoxTemplate, drawn by the stepper's and the picker's fields
    ["common-search-border-left"] = true, ["common-search-border-middle"] = true, ["common-search-border-right"] = true,
}
for _, base in ipairs({ "common-dropdown-a-button", "common-dropdown-b-button" }) do
    ALLOWED[base] = true
    for _, s in ipairs({ "hover", "pressed", "pressedhover", "open", "disabled" }) do
        ALLOWED[base .. "-" .. s] = true
        if base == "common-dropdown-a-button" then ALLOWED[base .. "-" .. s .. "-shadowless"] = true end
    end
end
ALLOWED["common-dropdown-a-button-shadowless"] = true
for name in pairs(STUB.atlasCalls) do
    assert(ALLOWED[name], "an atlas outside the design: " .. name)
end

---------------------------------------------------------------------------
-- new texts are Latin-1
---------------------------------------------------------------------------
local fh = assert(io.open(ADDON_DIR .. "/Widgets.lua", "rb"))
local src = fh:read("*a")
fh:close()
for lead in src:gmatch("[\192-\255]") do assert(lead:byte() <= 195, "beyond Latin-1 in Widgets.lua") end
