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

-- left click opens the main window, right click the gear planner (data is loaded in tests)
local opened
local origToggle, origGear = NS.Toggle, NS.ToggleGearFrame
NS.Toggle = function() opened = "main" end
NS.ToggleGearFrame = function() opened = "gear" end
b.scripts.OnClick(b, "LeftButton"); assert(opened == "main")
b.scripts.OnClick(b, "RightButton"); assert(opened == "gear")
Amisia_OnAddonCompartmentClick("Amisia", "LeftButton"); assert(opened == "main", "the compartment entry clicks the same")
Amisia_OnAddonCompartmentEnter("Amisia", b)
Amisia_OnAddonCompartmentLeave("Amisia", b)
b.scripts.OnEnter(b); b.scripts.OnLeave(b)
NS.Toggle, NS.ToggleGearFrame = origToggle, origGear

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
