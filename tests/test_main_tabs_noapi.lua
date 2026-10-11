--[[preload
STUB.missingTemplates.PanelTabButtonTemplate = true
PanelTemplates_SelectTab, PanelTemplates_DeselectTab, PanelTemplates_TabResize = nil, nil, nil
]]
-- A client without the panel tab template: the main window still has its tabs (flat, same places
-- and sizes), they switch and show which one is chosen.
NS.ShowPage("overview")
local F = AmisiaFrame
local raid, gear = F.tabs.raid, F.tabs.gear
assert(raid.flat and gear.flat and raid:IsShown(), "flat tabs")
assert(raid.points.TOPLEFT.rel == F and raid.points.TOPLEFT.relPoint == "BOTTOMLEFT")
assert(gear.points.TOPLEFT.rel == raid and raid._w >= 70 and raid._w >= raid.Text:GetStringWidth() + 20)
assert(raid.selected and not raid:IsEnabled() and gear:IsEnabled())
gear:Click()
assert(NS.CurrentPage() == "gear" and gear.selected and not raid.selected and raid:IsEnabled())
print("main tabs without the template ok")
