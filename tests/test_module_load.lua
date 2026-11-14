-- The core and its modules load as three addons (F-202, D-128, D-130): one namespace through the
-- modules' Module.lua, the bodies after the ADDON_LOADED of the core and of every module that will load
-- (core, raid, gear), PLAYER_LOGIN when something still waits, a module the client loads late, a module
-- without the core. tests/run.py loaded the real addon as the client does (a namespace per folder, one
-- ADDON_LOADED per addon); the small worlds below load Locales/Locale.lua and the Module.lua files again,
-- each with a core namespace of its own.
local function same(a, b) return table.concat(a, ",") == table.concat(b, ",") end

---------------------------------------------------------------------------
-- the real load: one namespace, every module there
---------------------------------------------------------------------------
assert(_G.AmisiaCore == NS, "the core offers its namespace")
assert(NS.ADDON == "Amisia" and NS.HasModule("raid") and NS.HasModule("gear"), "both modules loaded")
assert(type(NS.AddAward) == "function" and type(NS.Gear) == "table" and type(NS.SessionHash) == "function",
    "what the modules' files define stands in the core's namespace")
assert(NS.OwnAddon("Amisia") and NS.OwnAddon("Amisia_Raid") and NS.OwnAddon("Amisia_Gear"), "Amisia's addons")
assert(not NS.OwnAddon("Blizzard_Calendar") and not NS.OwnAddon(nil), "not Amisia's")
assert(same(NS.OwnAddons(), { "Amisia", "Amisia_Raid", "Amisia_Gear" }), table.concat(NS.OwnAddons(), ","))
assert(NS.HasData("GEAR") and NS.HasData("QUEST_DATA"), "the gear module's Data/* registered in the core")

-- a module's ADDON_LOADED handler added after the core started gets the core's event once (ns.LateLoaded)
local late = {}
NS.OnEvent("ADDON_LOADED", function(name) late[#late + 1] = name end)
NS.LateLoaded()
NS.LateLoaded()
assert(same(late, { "Amisia" }), table.concat(late, ","))
-- the bodies ran at PLAYER_LOGIN: the handlers get it once, the client's delivery after it is dropped
local logins = 0
NS.OnEvent("PLAYER_LOGIN", function() logins = logins + 1 end)
NS.LoginLoaded()
STUB.fire("PLAYER_LOGIN")
assert(logins == 1, "PLAYER_LOGIN once: " .. logins)
STUB.tick(0.2)
STUB.fire("PLAYER_LOGIN")
assert(logins == 2, "a later PLAYER_LOGIN comes through: " .. logins)

---------------------------------------------------------------------------
-- small worlds: a core of their own (Locales/Locale.lua again) with module files
---------------------------------------------------------------------------
local real = _G.AmisiaCore
local function world()
    local C, log = {}, {}
    assert(loadfile(ADDON_FILE("Locales/Locale.lua")))("Amisia", C)
    assert(_G.AmisiaCore == C)
    C.CoreLoaded = function() log[#log + 1] = "loaded" end
    C.LoginLoaded = function() log[#log + 1] = "login" end
    C.LateLoaded = function() log[#log + 1] = "late" end
    return C, log
end
local function module(file, addon)
    local ns = {}
    assert(loadfile(ADDON_FILE(file)))(addon, ns)
    return ns
end

-- 1. both modules on: the core waits for both; the bodies run core, raid, gear (in whatever order they came)
STUB.addons.Amisia_Raid, STUB.addons.Amisia_Gear = { loadable = true }, { loadable = true }
local C, log = world()
C.Load(function() log[#log + 1] = "core" end)
STUB.fire("ADDON_LOADED", "Amisia")
local R = module("Raid/Module.lua", "Amisia_Raid")
local G = module("Gear/Module.lua", "Amisia_Gear")
G.Load(function() log[#log + 1] = "gear" end)
R.Load(function() log[#log + 1] = "raid" end)
assert(#log == 0, "nothing runs before the modules came")
STUB.fire("ADDON_LOADED", "Amisia_Raid")
assert(#log == 0, "the gear module still comes")
STUB.fire("ADDON_LOADED", "Amisia_Gear")
assert(same(log, { "core", "raid", "gear", "loaded" }), table.concat(log, ","))
-- one namespace: a module writes and reads the core's table, its Load stays its own
R.Shared = 5
assert(C.Shared == 5 and G.Shared == 5 and rawget(R, "Shared") == nil, "writes reach the core")
C.FromCore = "x"
assert(R.FromCore == "x" and G.FromCore == "x", "reads reach the core")
assert(C.MODULES.raid and C.MODULES.gear and C.HasModule == nil, "the marks (ns.HasModule comes with Registry.lua)")
assert(rawget(R, "Load") ~= C.Load and rawget(G, "Load") ~= C.Load, "a module queues its bodies as its part")
-- after the start a body runs at once
G.Load(function() log[#log + 1] = "now" end)
assert(log[#log] == "now")

-- 2. the gear module switched off for this character: the core waits for the raid module only
STUB.addons.Amisia_Gear = { loadable = true, enabled = false }
C, log = world()
C.Load(function() log[#log + 1] = "core" end)
STUB.fire("ADDON_LOADED", "Amisia")
R = module("Raid/Module.lua", "Amisia_Raid")
R.Load(function() log[#log + 1] = "raid" end)
STUB.fire("ADDON_LOADED", "Amisia_Raid")
assert(same(log, { "core", "raid", "loaded" }), table.concat(log, ","))
assert(C.MODULES.gear == nil, "no gear module")

-- 3. no module installed: the core starts at its own ADDON_LOADED
STUB.addons.Amisia_Raid, STUB.addons.Amisia_Gear = nil, nil
C, log = world()
C.Load(function() log[#log + 1] = "core" end)
STUB.fire("ADDON_LOADED", "Amisia")
assert(same(log, { "core", "loaded" }), table.concat(log, ","))
-- 4. ... and one loads after all: its bodies run at once, its handlers get the core's event late
R = module("Raid/Module.lua", "Amisia_Raid")
R.Load(function() log[#log + 1] = "raid" end)
STUB.fire("ADDON_LOADED", "Amisia_Raid")
assert(same(log, { "core", "loaded", "raid", "late" }), table.concat(log, ","))

-- 5. a module the client named never comes: PLAYER_LOGIN runs the bodies and hands the login on
STUB.addons.Amisia_Raid = { loadable = true }
C, log = world()
C.Load(function() log[#log + 1] = "core" end)
STUB.fire("ADDON_LOADED", "Amisia")
assert(#log == 0, "waits for the raid module")
STUB.fire("PLAYER_LOGIN")
assert(same(log, { "core", "loaded", "login" }), table.concat(log, ","))

-- 6. the gear module off Forever: not waited for, even when the client calls it loadable (D-57)
STUB.addons.Amisia_Raid, STUB.addons.Amisia_Gear = { loadable = true }, { loadable = true }
local keepCamelot = WOW_PROJECT_CAMELOT
WOW_PROJECT_CAMELOT = nil
C, log = world()
C.Load(function() log[#log + 1] = "core" end)
STUB.fire("ADDON_LOADED", "Amisia")
STUB.fire("ADDON_LOADED", "Amisia_Raid")
WOW_PROJECT_CAMELOT = keepCamelot
assert(same(log, { "core", "loaded" }), table.concat(log, ","))

-- 7. a client without C_AddOns and without the old globals: no module is waited for
local keep = C_AddOns
C_AddOns = nil
C, log = world()
STUB.fire("ADDON_LOADED", "Amisia")
C_AddOns = keep
assert(same(log, { "loaded" }), table.concat(log, ","))

-- 8. a module without the core (the client loads none, but a broken install): nothing runs, no error
_G.AmisiaCore = nil
local lone = module("Gear/Module.lua", "Amisia_Gear")
local ran = false
lone.Load(function() ran = true end)
lone.LazyData("X", "return {}", 0)
assert(not ran and getmetatable(lone) == nil, "nothing of the module runs")

_G.AmisiaCore = real
print("module load ok")
