-- The gear module "Ausrüstung & Dungeons" (F-202, D-130): the addon Amisia_Gear (WoW Forever only), its
-- first file. It runs at once, not in ns.Load (tools/tests/test_load_order.py): it points this addon's
-- namespace at the core's (_G.AmisiaCore, made by the core's Locales/Locale.lua), so ns.X reads and
-- writes the core's table in every file of the module, the generated Data/* included, queues the
-- module's bodies after the core's and the raid module's (they run once the core has AmisiaDB, D-128)
-- and marks the module loaded, so the core and the raid module may use its code (ns.HasModule("gear")).
-- Without the core (the client loads no module without it) the module's bodies never run.
local ADDON, ns = ...
local core = _G.AmisiaCore
if type(core) ~= "table" or type(core.LoadPart) ~= "function" then
    ns.Load = function() end
    ns.LazyData = function() end
    return
end
if core ~= ns then
    setmetatable(ns, { __index = core, __newindex = core })
    rawset(ns, "Load", function(fn) core.LoadPart("gear", fn) end)
end
core.MODULES.gear = true
