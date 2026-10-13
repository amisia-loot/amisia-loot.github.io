-- The saved data's version (AmisiaDB.schema, Core/Migrate.lua, D-48): a new file gets the newest,
-- an older one runs the missing steps once and in order before the settings are checked, a failing
-- step stops the chain and is tried again, a file of a newer Amisia stays untouched and is named
-- once in the chat; ns.MigrateMoveSetting moves a stored setting.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local N = #NS.MIGRATIONS
assert(N >= 1)
assert(AmisiaDB.schema == N, "a new file is at the newest step: " .. tostring(AmisiaDB.schema))

local core
for f in pairs(STUB.frames) do
    if f.events.PLAYER_ENTERING_WORLD and f.events.CHAT_MSG_LOOT then core = f end
end
local function load()
    core:RegisterEvent("ADDON_LOADED")
    STUB.fire("ADDON_LOADED", "Amisia")
end

-- an old file runs the missing steps in order, once
local ran = {}
NS.MIGRATIONS[N + 1] = function(db) ran[#ran + 1] = "a"; db.settings.sync = db.settings.sync or {} end
NS.MIGRATIONS[N + 2] = function(db) ran[#ran + 1] = "b"; NS.MigrateMoveSetting(db, "sync.shareUpgrades", "rolls.altClick") end
AmisiaDB.settings.sync = { shareUpgrades = false }
AmisiaDB.settings.rolls = nil
load()
assert(table.concat(ran) == "ab" and AmisiaDB.schema == N + 2, table.concat(ran))
assert(AmisiaDB.settings.sync.shareUpgrades == nil, "moved away")
assert(AmisiaDB.settings.rolls.altClick == false, "moved before the settings check, and the check keeps it")
load()
assert(table.concat(ran) == "ab", "a second load changes nothing")

-- the new place keeps what it has
AmisiaDB.settings.sync.shareUpgrades = true
AmisiaDB.settings.rolls.altClick = false
NS.MigrateMoveSetting(AmisiaDB, "sync.shareUpgrades", "rolls.altClick")
assert(AmisiaDB.settings.rolls.altClick == false and AmisiaDB.settings.sync.shareUpgrades == nil)
NS.MigrateMoveSetting(AmisiaDB, "nichts.da", "rolls.altClick")

-- a failing step stops the chain at the step before and runs again on the next load
local tries = 0
NS.MIGRATIONS[N + 3] = function() tries = tries + 1; if tries == 1 then error("kaputt") end end
NS.MIGRATIONS[N + 4] = function() ran[#ran + 1] = "d" end
local errors, handler = {}, _G.geterrorhandler
_G.geterrorhandler = function() return function(e) errors[#errors + 1] = e end end
load()
_G.geterrorhandler = handler
assert(AmisiaDB.schema == N + 2 and table.concat(ran) == "ab", "stopped before the failing step")
assert(#errors == 1 and has(tostring(errors[1]), "kaputt"), "reported")
load()
assert(AmisiaDB.schema == N + 4 and table.concat(ran) == "abd", "tried again, then the rest")

-- a newer file: nothing runs, one line in the chat at login
for i = N + 1, N + 4 do NS.MIGRATIONS[i] = nil end
AmisiaDB.schema = N + 7
STUB.messages = {}
load()
assert(AmisiaDB.schema == N + 7, "left as it is")
STUB.fire("PLAYER_LOGIN")
local said
for _, m in ipairs(STUB.messages) do if has(m, "neueren Amisia-Version") then said = m end end
assert(said and has(said, ("Stand %d"):format(N + 7)), tostring(said))
