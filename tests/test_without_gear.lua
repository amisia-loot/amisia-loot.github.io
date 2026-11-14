--[[without gear]]
-- F-202 (D-130): Amisia without the module "Ausrüstung & Dungeons" (Amisia_Gear switched off or not
-- installed): every page, page state and side window of the core and the raid module opens without a Lua
-- error, and nothing of the gear module is registered (tests/module_scene.lua).
dofile(ADDON_DIR .. "/../tests/module_scene.lua")("gear")
