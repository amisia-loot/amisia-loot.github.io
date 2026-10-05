-- The arrows: every dropdown button and arrow button is the client's dropdown button
-- (atlas common-dropdown-a-button and its states, Blizzard_Menu's WowStyle1 dropdown), no text
-- glyph is left as an arrow, and the picker still fits its field.
local W = NS.W
local A = "common-dropdown-a-button"
local root = CreateFrame("Frame", nil, UIParent)
root:SetSize(200, 40)

---------------------------------------------------------------------------
-- the picker's button
---------------------------------------------------------------------------
local p = W.Picker(root, 150, function() end)
p:SetPoint("TOPLEFT", 10, -10)
p:SetValues({ { value = "a", text = "Anton" }, { value = "b", text = "Berta" } })
p:SetValue("a")
local b = p.arrow
assert(b.kind == "Button" and b.arrow, "the arrow is a button with a texture")
assert(b:GetText() == "" and b.arrow.texture == nil, "no glyph, no file texture")
local function atlas() return b.arrow:GetAtlas() end
assert(atlas() == A, "normal: " .. tostring(atlas()))
assert(b._w == 22 and b._h == 22, "a 22 px square")
-- the states, as GetWowStyle1ArrowButtonState picks them
b:GetScript("OnEnter")(b); assert(atlas() == A .. "-hover", atlas())
b:GetScript("OnMouseDown")(b); assert(atlas() == A .. "-pressedhover", atlas())
b:GetScript("OnMouseUp")(b); assert(atlas() == A .. "-hover", atlas())
b:GetScript("OnLeave")(b); assert(atlas() == A, atlas())
b:GetScript("OnMouseDown")(b); assert(atlas() == A .. "-pressed", atlas())
b:GetScript("OnMouseUp")(b)
-- hovering the field lights the button too
p:GetScript("OnEnter")(p); assert(atlas() == A .. "-hover", "field hover: " .. atlas())
p:GetScript("OnLeave")(p); assert(atlas() == A, atlas())
-- a click on the button opens the panel like a click on the field: the open state
b:Click()
assert(AmisiaPicker:IsShown() and AmisiaPicker.owner == p, "the button opens the panel")
assert(atlas() == A .. "-open", "open: " .. atlas())
p:Click()
assert(not AmisiaPicker:IsShown() and atlas() == A, "closed again: " .. atlas())
-- another picker takes the panel: the first one's button closes
local p2 = W.Picker(root, 150, function() end)
p2:SetValues({ { value = "x", text = "X" } })
p:Click(); assert(atlas() == A .. "-open")
p2:Click()
assert(AmisiaPicker.owner == p2 and atlas() == A and p2.arrow.arrow:GetAtlas() == A .. "-open", "the panel moved")
AmisiaPicker:Hide()
assert(p2.arrow.arrow:GetAtlas() == A)
-- disabled with the field
p:Disable(); assert(not b:IsEnabled() and atlas() == A .. "-disabled", atlas())
p:Enable(); assert(b:IsEnabled() and atlas() == A, atlas())
-- layout: the text ends before the button, the button sits on the field's right end
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(root, 200, 40)
L.row("picker", p.label, b)
local pl, pr = L.span(p)
local bl, br = L.span(b)
assert(br == pr + 1 and bl == pr - 21, "the button at the right end: " .. bl .. ".." .. br)
local t, bt = L.vspan(b)
local pt, pb = L.vspan(p)
assert(t == pt + 1 and bt == pb - 1, "one pixel over the 20 px field at top and bottom")
-- the field has the client's input border, like every edit box, inside the field's bounds
assert(p.Left.atlas == "common-search-border-left" and p.Middle.atlas == "common-search-border-middle"
    and p.Right.atlas == "common-search-border-right", "the input border")
assert(p.edges == nil, "no flat frame any more")
local fl = L.span(p.Left)
local _, fr = L.span(p.Right)
assert(fl == pl and fr == pr, "the border stays inside the field: " .. fl .. ".." .. fr)

---------------------------------------------------------------------------
-- a turned arrow: without the drop shadow, turned left and right
---------------------------------------------------------------------------
local left = W.ArrowButton(root, "left", 22)
local right = W.ArrowButton(root, "right", 22)
assert(left.arrow:GetAtlas() == A .. "-shadowless" and right.arrow:GetAtlas() == A .. "-shadowless")
assert(math.abs(left.arrow.rotation + math.pi / 2) < 1e-9 and math.abs(right.arrow.rotation - math.pi / 2) < 1e-9)
left:GetScript("OnEnter")(left); assert(left.arrow:GetAtlas() == A .. "-hover-shadowless")
left:GetScript("OnMouseDown")(left); assert(left.arrow:GetAtlas() == A .. "-pressedhover-shadowless")
left:Disable(); assert(left.arrow:GetAtlas() == A .. "-disabled-shadowless")
local down = W.ArrowButton(root)
assert(down.arrow:GetAtlas() == A and down.arrow.rotation == nil, "down needs no turn")

---------------------------------------------------------------------------
-- the gear window's column steps
---------------------------------------------------------------------------
_G.UnitClass = function() return "Krieger", "WARRIOR" end
_G.UnitLevel = function() return 24 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
NS.ToggleGearFrame()
local F = AmisiaGearFrame
AmisiaDB.settings.gear.view = "list"
AmisiaDB.settings.gear.col = 1
NS.GearRefresh(true)
assert(F.prevCol.arrow and F.nextCol.arrow, "arrow buttons")
assert(F.prevCol:GetText() == "" and F.nextCol:GetText() == "" and not F.prevCol.label, "no < > glyphs")
assert(F.prevCol:IsShown() and not F.prevCol:IsEnabled() and F.prevCol.arrow:GetAtlas() == A .. "-disabled-shadowless",
    "the first column: back is off")
assert(F.nextCol:IsEnabled() and F.nextCol.arrow:GetAtlas() == A .. "-shadowless")
assert(F.prevCol.arrow.rotation < 0 and F.nextCol.arrow.rotation > 0, "left and right")
F.nextCol:Click()
assert(AmisiaDB.settings.gear.col == 2 and F.prevCol:IsEnabled() and F.prevCol.arrow:GetAtlas() == A .. "-shadowless")
AmisiaDB.settings.gear.col = #NS.Gear.COLUMNS
NS.GearRefresh(true)
assert(not F.nextCol:IsEnabled(), "the last column: forward is off")
F:Hide()

---------------------------------------------------------------------------
-- no text glyph is left as an arrow in the addon's source
---------------------------------------------------------------------------
local files = {}
for line in io.lines(ADDON_DIR .. "/Amisia.toc") do
    line = line:gsub("%s*%[[^%]]*%]", ""):gsub("\\", "/"):match("^%s*(.-)%s*$")
    if line ~= "" and not line:find("^#") and line:find("%.lua$") then files[#files + 1] = line end
end
assert(#files > 20, "the TOC lists the files")
for _, name in ipairs(files) do
    local fh = assert(io.open(ADDON_DIR .. "/" .. name, "rb"))
    local src = fh:read("*a")
    fh:close()
    local n = 0
    for line in src:gmatch("[^\n]+") do
        n = n + 1
        if not line:find("^%s*%-%-") then
            for _, pat in ipairs({ ':SetText%("[v%^<>]"%)', 'hip%([^,]+, "[v%^<>]+"', '[Bb]utton%([^,]+, "[v%^<>]+"' }) do
                assert(not line:find(pat), ("%s:%d keeps a text arrow: %s"):format(name, n, line))
            end
        end
    end
end
