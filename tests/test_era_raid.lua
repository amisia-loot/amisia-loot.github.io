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
-- the tabs (D-73): one per group with a visible page; the side bar's rows fit it
local function groupBars()
    local out = {}
    for _, b in ipairs(F.tabOrder) do out[#out + 1] = b.key end
    return table.concat(out, " ")
end
local function barsFit()
    assert(F.nav:GetWidth() <= T.MAIN.NAV_W, "the side bar inside its field: " .. F.nav:GetWidth())
    for _, e in ipairs(F.navOrder) do assert(e.button:IsShown(), e.entry.key) end
    for _, b in ipairs(F.tabOrder) do
        local at = b.points.TOPLEFT
        assert(not at or at.x + b:GetWidth() <= F:GetWidth() - T.MAIN.GEAR_W, "the tab inside the window: " .. b.key)
    end
end
assert(F.sideTabs == nil, "no tabs beside the window")
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
