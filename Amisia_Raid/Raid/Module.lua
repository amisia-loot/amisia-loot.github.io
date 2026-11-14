-- The raid module (F-202, D-130): the addon Amisia_Raid, its first file. It runs at once, not in ns.Load
-- (tools/tests/test_load_order.py): it points this addon's namespace at the core's (_G.AmisiaCore, made by
-- the core's Locales/Locale.lua), so ns.X reads and writes the core's table in every file of the module,
-- queues the module's bodies after the core's (they run once the core has AmisiaDB, D-128) and marks the
-- module loaded, so the core and the gear module may use raid code (ns.HasModule("raid")). Without the
-- core (the client loads no module without it) the module's bodies never run.
local ADDON, ns = ...
local core = _G.AmisiaCore
if type(core) ~= "table" or type(core.LoadPart) ~= "function" then
    ns.Load = function() end
    return
end
if core ~= ns then
    setmetatable(ns, { __index = core, __newindex = core })
    rawset(ns, "Load", function(fn) core.LoadPart("raid", fn) end)
end
core.MODULES.raid = true
