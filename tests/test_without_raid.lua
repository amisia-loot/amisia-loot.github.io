--[[without raid]]
-- F-202 (D-130): Amisia without the raid module (Amisia_Raid switched off or not installed): every page,
-- page state and side window of the core and the gear module opens without a Lua error, and nothing of
-- the raid is registered (tests/module_scene.lua).
dofile(ADDON_DIR .. "/../tests/module_scene.lua")("raid")
