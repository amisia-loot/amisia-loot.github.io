--[[preload
STUB.missingAtlases["auctionhouse-nav-button"] = true
STUB.missingAtlases["auctionhouse-nav-button-secondary-highlight"] = true
]]
-- A client without the auction house's category bars (a patch renamed them): the page list keeps the
-- look of before (the recipe list's glow on the chosen row and its hover), the gold name, no icon;
-- the search results show a group as a section bar and a hit as a plain list row.
local W = NS.W
assert(W.NavBar(CreateFrame("Button"), false) == nil and W.NavBar(CreateFrame("Button"), true) == nil, "no bars without the art")
NS.ShowPage("overview")
local F = AmisiaFrame
local ov
for _, e in ipairs(F.navOrder) do
    if e.button.key == "overview" then ov = e.button end
end
assert(ov and ov.art == nil and ov.icon == nil, "the row without the bar, no icon")
assert(ov.sel.atlas == "Professions_Recipe_Active" and ov.sel:IsShown(), "the chosen row glows")
assert(ov.hover.atlas == "Professions_Recipe_Hover" and ov.hover.layer == "HIGHLIGHT")
assert(ov.label.font == "GameFontNormal" and ov._h == 21, "the gold name, 21 high")
-- the search results
local box = F.search
box:SetText("experten")
box.scripts.OnTextChanged(box, true)
local head, hit = F.results.rows[1], F.results.rows[2]
assert(head.headArt == nil and head.bar:IsShown() and head.bar.ButtonText:GetText():find("Einstellungen", 1, true), "a group as a section bar")
assert(not hit.bar:IsShown() and hit.bg:IsShown() and hit.label:GetText() == "Expertenmodus" and hit.icon == nil, "a hit as a plain row")
print("nav bars without the atlas ok")
