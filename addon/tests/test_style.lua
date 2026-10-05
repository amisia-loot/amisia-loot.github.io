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
