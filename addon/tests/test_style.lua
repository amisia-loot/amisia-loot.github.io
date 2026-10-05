-- The look of Forever's own windows: the stub knows the client's templates and atlases, and every
-- widget inherits the template the client draws it with.

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
-- edit boxes
local sb = CreateFrame("EditBox", nil, root, "SearchBoxTemplate")
assert(sb.Left and sb.Middle and sb.Right and sb.Instructions and sb.searchIcon and sb.clearButton)
assert(sb.Instructions:GetText() == SEARCH and SEARCH == "Suchen")
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
