--[[without talents]]
-- F-228 (D-158): Amisia without the module "Talente" (Amisia_Talents switched off or not installed): every page,
-- page state and side window of the core and the other modules opens without a Lua error, and nothing of
-- the module is registered (tests/module_scene.lua).
dofile(ADDON_DIR .. "/../tests/module_scene.lua")("talents")
print("without talents ok")
