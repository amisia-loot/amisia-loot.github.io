-- The export reminder (record.exportWarn, 2.34.0): at the end of a recording the officer view says how
-- many raids the site has not got yet; nothing when all are exported, in the raider view or with the
-- setting off; raids kept over "Raids aufbewahren" are named too.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function stop()
    NS.Set("record.enabled", false); STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(1)
    NS.Set("record.enabled", true)
end
STUB.roster = { { name = "Leiter Eins", class = "PRIEST" }, { name = "Fraktur Stein", class = "SHAMAN" } }
NS.Set("ui.view", "officer")
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active(), "a recording runs")
STUB.messages = {}
stop()
assert(said("1 Raid ist noch nicht auf der Website."), table.concat(STUB.messages, "\n"))

-- exported: nothing
NS.MarkExported(NS.PendingExport())
STUB.instance = { name = "Onyxias Hort", type = "raid", id = 249, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.MarkExported(NS.PendingExport())
STUB.messages = {}
stop()
assert(not said("auf der Website"), "everything exported: " .. table.concat(STUB.messages, "\n"))

-- two raids not exported, then the raider view and the setting off
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.messages = {}
stop()
STUB.instance = { name = "Pechschwingenhort", type = "raid", id = 469, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.messages = {}
stop()
assert(said("2 Raids sind noch nicht auf der Website."), table.concat(STUB.messages, "\n"))
NS.Set("ui.view", "raider")
STUB.instance = { name = "Zul'Gurub", type = "raid", id = 309, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.messages = {}
stop()
assert(not said("auf der Website"), "not in the raider view")
NS.Set("ui.view", "officer")
NS.Set("record.exportWarn", false)
STUB.instance = { name = "Ahn'Qiraj", type = "raid", id = 509, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.messages = {}
stop()
assert(not said("auf der Website"), "not with the setting off")
NS.Set("record.exportWarn", true)

-- kept over the limit: named when a new raid starts
NS.Set("record.keepSessions", 10)
local DB, old = AmisiaDB, time() - 40 * 86400
for i = 1, 12 do
    table.insert(DB.sessions, 1, { id = ("2026080%02d-1"):format(i), start = old + i, last = old + i, date = "2026-08-01", zone = "Alt",
        instanceID = 1, members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} })
end
STUB.messages = {}
STUB.instance = { name = "Naxxramas", type = "raid", id = 533, diff = 9 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local m = said("bleiben, weil die Website sie noch nicht hat")
assert(m and has(m, "(10)"), table.concat(STUB.messages, "\n"))
