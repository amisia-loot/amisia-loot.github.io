--[[preload
STUB.missingAtlases["auctionhouse-nav-button"] = true
STUB.missingAtlases["auctionhouse-nav-button-secondary"] = true
]]
-- A client without the auction house's category bars (a patch renamed them): the side bar draws its
-- own rows (D-73) and needs none; the search results show a group as a section bar and a hit as a
-- plain list row.
local W = NS.W
assert(W.NavBar(CreateFrame("Button"), false) == nil and W.NavBar(CreateFrame("Button"), true) == nil, "no bars without the art")
NS.ShowPage("overview")
local F = AmisiaFrame
local ov
for _, e in ipairs(F.navOrder) do
    if e.button.key == "overview" then ov = e.button end
end
assert(ov and ov.subArt == nil and ov.sel:IsShown() and ov.bar:IsShown(), "the chosen row without the bars")
local r1, r2 = F.nav.rows[1], F.nav.rows[2]
assert(ov.label.font == "GameFontNormal" and ov._h == NS.Theme.MAIN.NAV_ROW_H - 1
    and r1.points.TOPLEFT.y - r2.points.TOPLEFT.y == NS.Theme.MAIN.NAV_ROW_H, "the gold name: " .. tostring(ov._h))
-- the search results
local box = F.search
box:SetText("experten")
box.scripts.OnTextChanged(box, true)
local head, hit = F.results.rows[1], F.results.rows[2]
assert(head.headArt == nil and head.bar:IsShown() and head.bar.ButtonText:GetText():find("Einstellungen", 1, true), "a group as a section bar")
assert(not hit.bar:IsShown() and hit.bg:IsShown() and hit.label:GetText() == "Expertenmodus" and hit.icon == nil, "a hit as a plain row")
print("nav bars without the atlas ok")
