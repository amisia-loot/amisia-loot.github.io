-- /amisia speicher: memory before and after a full collection, the data built so far, the saved
-- scan still waiting for the trim; nothing in combat; a client without the memory API.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

-- without the client's memory API: only the data lines
UpdateAddOnMemoryUsage, GetAddOnMemoryUsage = nil, nil
local lines = NS.MemoryReport()
assert(has(lines[1], "Der Client nennt den Speicher der Addons nicht."), lines[1])

-- with it: 2048 KB before, 1024 KB after the collection -> 1 MB garbage
local calls, value = 0, 2048
UpdateAddOnMemoryUsage = function() calls = calls + 1 end
GetAddOnMemoryUsage = function(name) assert(name == "Amisia", name); local v = value; value = 1024; return v end
NS.Data("MAGESCROLLS")
AmisiaDB.scan = { items = { [1] = "a", [2] = "b" }, sources = { x = 1 } }
lines = NS.MemoryReport()
assert(calls == 2, "measured twice: " .. calls)
assert(has(lines[1], "Speicher: 2.0 MB, davon Müll 1.0 MB, echte Daten 1.0 MB."), lines[1])
local text = table.concat(lines, "\n")
assert(has(text, "Geladene Daten: ") and has(text, "MAGESCROLLS"), text)
assert(has(text, "Noch nicht geladen: ") and has(text, "GEAR"), text)
assert(has(text, "Gespeicherter Scan: 2 Items, 1 Quellen"), text)

-- the command prints the lines
STUB.messages = {}
value = 2048
SlashCmdList.AMISIA("speicher")
assert(has(table.concat(STUB.messages, "\n"), "Speicher: 2.0 MB"), table.concat(STUB.messages, "\n"))

-- not in combat
STUB.combat = true
calls = 0
lines = NS.MemoryReport()
assert(#lines == 1 and has(lines[1], "Nicht im Kampf") and calls == 0, lines[1])
STUB.combat = false
