-- The raid module (F-202, D-130; Amisia_Raid once it is an addon of its own): its first file. It marks
-- the module loaded, so the core and the gear module may use raid code (ns.HasModule("raid")).
local ADDON, ns = ...
ns.Load(function()
ns.MODULES.raid = true
end)
