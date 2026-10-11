-- An id twice in the retry list (two scans over the same range park it twice) or in a list scan
-- is asked once: the open count must reach zero, else the scan and its 0.1 s ticker never end.
STUB.instance = { name = "Shattrath", type = "none", id = 0 }

AmisiaDB.scan = { retry = { 7, 7, 8 } }
assert(NS.ScanRetry())
STUB.requested = {}
STUB.tick(0.5)
assert(#STUB.requested == 2, "each id asked once: " .. #STUB.requested)
STUB.fire("ITEM_DATA_LOAD_RESULT", 7, false)
STUB.fire("ITEM_DATA_LOAD_RESULT", 8, false)
assert(not NS.ScanRunning(), "the retry ends when every id answered")

-- the same through a list with a repeated id (and through the timeouts)
assert(NS.ScanList({ 9, 9 }, "Test"))
STUB.requested = {}
STUB.tick(0.1)
assert(#STUB.requested == 1, "asked once: " .. #STUB.requested)
STUB.tick(25)
assert(not NS.ScanRunning(), "the list scan ends after the timeouts")
local n = 0
for _, id in ipairs(AmisiaDB.scan.retry) do if id == 9 then n = n + 1 end end
assert(n == 1, "parked once: " .. n)
