--[[without gear]]
-- F-202 (D-130; F-228, D-158): Amisia without the module "Ausrüstung" (Amisia_Gear switched off or not
-- installed): every page, page state and side window of the core and the other modules opens without a Lua
-- error, and nothing of the gear module is registered (tests/module_scene.lua).
-- the dungeon facts, encounters and the drop stock (ns.BIS) are the core's (F-228): Dungeons & Raids keeps its
-- bosses without the module; upgrades and the need answer are the module's
assert(type(NS.BIS) == "table" and type(NS.BIS.DG) == "table", "ns.BIS without the gear module")
assert(NS.ItemOpts().class and NS.ItemOpts().sources.D, "the options without the gear module")
assert(NS.BisGain == nil and NS.Dungeons.Gain(1) == nil, "no gains")
dofile(ADDON_DIR .. "/../tests/module_scene.lua")("gear")
