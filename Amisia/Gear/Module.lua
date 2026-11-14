-- The gear module "Ausrüstung & Dungeons" (F-202, D-130; Amisia_Gear once it is an addon of its own,
-- WoW Forever only): its first file. It marks the module loaded, so the core and the raid module may
-- use its code (ns.HasModule("gear")).
local ADDON, ns = ...
ns.Load(function()
ns.MODULES.gear = true
end)
