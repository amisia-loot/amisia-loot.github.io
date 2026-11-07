--[[game era]]
-- The raid part alone on Classic Era (with SoD and Hardcore, D-57): loads, the side bar shows the raid
-- groups only (D-68), their names fit their bars, the settings open; tests/test_tbc_raid.lua goes
-- through the rest on TBC.
local T = NS.Theme
assert(NS.GAME == "era" and not NS.FOREVER, tostring(NS.GAME))
assert(NS.Gear == nil and NS.Panel("export") == nil and NS.Panel("duels") == nil)
STUB.officer = true
NS.ToggleMain()
local F = AmisiaFrame
-- the side bar (D-68): a bar per group with a visible page; nothing under or beside the window
local function groupBars()
    local out = {}
    for _, e in ipairs(F.nav.items) do
        if e.kind == "cat" then out[#out + 1] = e.key end
    end
    return table.concat(out, " ")
end
-- the group bars (in place of the tabs under the window) inside the side bar, their names fit
local function barsFit()
    assert(F.nav:GetWidth() <= T.MAIN.NAV_W, "the side bar inside its inset: " .. F.nav:GetWidth())
    for _, e in ipairs(F.navOrder) do
        local b = e.button
        assert(b:IsShown(), e.entry.key)
        assert(e.entry.kind ~= "cat" or b.label:GetStringWidth() <= b.label:GetWidth() + 0.5,
            "the group's name fits its bar: " .. e.entry.key .. " " .. b.label:GetStringWidth() .. " > " .. b.label:GetWidth())
    end
end
assert(F.tabs == nil and F.sideTabs == nil and F.tabOrder == nil, "no tabs under or beside the window")
assert(groupBars() == "raid guild amisia", groupBars())
for _, key in ipairs({ "raid", "guild", "amisia" }) do
    NS.ShowTab(key)
    barsFit()
end
NS.Dispatch("einstellungen")
assert(NS.CurrentPage() == "settings")
NS.ShowPage("rolls")
NS.ShowPage("softres")
print("era raid ok")
