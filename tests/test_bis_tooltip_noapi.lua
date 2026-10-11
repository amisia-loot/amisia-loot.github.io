--[[preload
-- a client without the tooltip data processor
TooltipDataProcessor = nil
]]
-- Without TooltipDataProcessor Amisia adds no tooltip lines and raises no error: no post call,
-- no item script hook as a second path, and building an item tooltip changes nothing.
assert(TooltipDataProcessor == nil, "the preload took the processor away")
assert(#STUB.tdp == 0, "nothing registered")
assert(GameTooltip.scripts.OnTooltipSetItem == nil and ItemRefTooltip.scripts.OnTooltipSetItem == nil, "no item script hook")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
NS.SetSoftRes("Vuloo " .. link)
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
assert(pcall(STUB.showTooltip, GameTooltip, link), "a tooltip build raises nothing")
assert(#lines == 0, "no lines")
