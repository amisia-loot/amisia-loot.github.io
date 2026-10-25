--[[game era]]
-- The raid part alone on Classic Era (with SoD and Hardcore, D-57): loads, the raid tabs only and inside
-- the window, the settings open; tests/test_tbc_raid.lua goes through the rest on TBC.
local T = NS.Theme
assert(NS.GAME == "era" and not NS.FOREVER, tostring(NS.GAME))
assert(NS.Gear == nil and NS.Panel("export") == nil and NS.Panel("duels") == nil)
STUB.officer = true
NS.ToggleMain()
local F = AmisiaFrame
assert(table.concat(F.tabOrder, " ") == "raid guild calendar amisia", table.concat(F.tabOrder, " "))
local x = T.MAIN.BTAB_X
for i, key in ipairs(F.tabOrder) do x = x + F.tabs[key]:GetWidth() + (i > 1 and T.MAIN.BTAB_GAP or 0) end
assert(x <= T.MAIN.W, "the tabs inside the window: " .. x)
NS.Dispatch("einstellungen")
assert(NS.CurrentPage() == "settings")
NS.ShowPage("rolls")
NS.ShowPage("softres")
print("era raid ok")
