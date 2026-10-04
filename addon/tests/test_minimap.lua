-- The minimap button: built at login, clicks, dragging around the edge, hiding, compartment entry.
_G.Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap.GetWidth = function() return 140 end
Minimap.GetCenter = function() return 1000, 600 end
Minimap.GetEffectiveScale = function() return 1 end
STUB.cursor = { 1000, 700 }
_G.GetCursorPosition = function() return STUB.cursor[1], STUB.cursor[2] end

STUB.fire("PLAYER_LOGIN")
local b = AmisiaMinimapButton
assert(b and b:IsShown(), "button built and shown")
assert(AmisiaDB.settings.minimap.angle == 200, "default place")

-- left click opens the main window, right click the quick menu
local origMain = NS.ToggleMain
local opened
NS.ToggleMain = function() opened = "main" end
b.scripts.OnClick(b, "LeftButton"); assert(opened == "main")
Amisia_OnAddonCompartmentClick("Amisia", "LeftButton"); assert(opened == "main", "the compartment entry clicks the same")
NS.ToggleMain = origMain
b.scripts.OnClick(b, "RightButton"); assert(AmisiaMenu and AmisiaMenu:IsShown(), "right click opens the menu")
local labels = {}
for _, e in ipairs(NS.MinimapMenuEntries()) do labels[#labels + 1] = e[1] end
local all = table.concat(labels, "|")
assert(all:find("Einstellungen", 1, true) and all:find("Soft-Reserves", 1, true) and all:find("Export", 1, true), all)
NS.Set("ui.view", "raider")
all = ""
for _, e in ipairs(NS.MinimapMenuEntries()) do all = all .. e[1] .. "|" end
assert(not all:find("Export", 1, true), "raiders see no officer entries")
NS.Reset("ui.view")
Amisia_OnAddonCompartmentEnter("Amisia", b)
Amisia_OnAddonCompartmentLeave("Amisia", b)
b.scripts.OnEnter(b); b.scripts.OnLeave(b)

-- dragging: the cursor straight above the minimap's centre puts the button at 90 degrees
b.scripts.OnDragStart(b)
assert(b.scripts.OnUpdate, "follows the cursor while dragging")
b.scripts.OnUpdate(b)
assert(math.abs(AmisiaDB.settings.minimap.angle - 90) < 1e-6, AmisiaDB.settings.minimap.angle)
b.scripts.OnDragStop(b)
assert(not b.scripts.OnUpdate)

-- hide and show by command; the choice is kept
SlashCmdList.AMISIA("minimap")
assert(not b:IsShown() and NS.Get("ui.minimap") == false)
SlashCmdList.AMISIA("minimap")
assert(b:IsShown() and NS.Get("ui.minimap") == true)
