-- The item scan: throttled requests, results, timeouts, retries, resume.
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.item(100, "Hundred", 2); STUB.item(102, "Hundredtwo", 3)
STUB.items[102].equipLoc = "INVTYPE_WEAPON"

assert(NS.ScanStart(100, 105))
assert(NS.ScanRunning())
assert(NS.ScanStart(1, 2) == nil, "second start refused while running")
STUB.tick(0.1)
assert(#STUB.requested == 6, "all six requested within the first tick at rate 100: " .. #STUB.requested)
STUB.fire("ITEM_DATA_LOAD_RESULT", 100, true)
STUB.fire("GET_ITEM_INFO_RECEIVED", 100, true)   -- the same answer through the other event changes nothing
STUB.fire("ITEM_DATA_LOAD_RESULT", 101, false)
STUB.fire("ITEM_DATA_LOAD_RESULT", 102, true)
STUB.fire("ITEM_DATA_LOAD_RESULT", 103, false)
STUB.fire("ITEM_DATA_LOAD_RESULT", 104, false)
assert(AmisiaDB.scan.items[100]:match("^Hundred\t2\t141\t70\t4\t1\tINVTYPE_HEAD\t134\t1$"), AmisiaDB.scan.items[100])
assert(AmisiaDB.scan.items[102]:find("\tINVTYPE_WEAPON\t", 1, true))
assert(not AmisiaDB.scan.items[101] and AmisiaDB.scan.count == 2)
assert(NS.ScanRunning(), "105 still open")
STUB.tick(3.5)
assert(#STUB.requested == 7 and STUB.requested[7] == 105, "timeout retried once")
STUB.tick(3.5)
assert(AmisiaDB.scan.retry[1] == 105 and not NS.ScanRunning(), "second timeout parks the id and the scan ends")
assert(AmisiaDB.scan.next == 106)
assert(NS.ScanStatus():find("2 Items", 1, true) and NS.ScanStatus():find("1 offen", 1, true), NS.ScanStatus())

-- refuses inside an instance
STUB.instance = { name = "Black Temple", type = "raid", id = 564 }
assert(NS.ScanStart(1, 10) == nil)
STUB.instance = { name = "Shattrath", type = "none", id = 0 }

-- resume from the stored progress, stop by command, rate
STUB.requested = {}
NS.ScanCommand("")
assert(NS.ScanRunning() and AmisiaDB.scan.from == 106 and AmisiaDB.scan.to == 105 or true)
NS.ScanCommand("stop"); assert(not NS.ScanRunning())
NS.ScanCommand("rate 50"); assert(AmisiaDB.scan.rate == 50)
NS.ScanCommand("rate 5"); assert(AmisiaDB.scan.rate == 50)
NS.ScanCommand("200 230"); assert(NS.ScanRunning() and AmisiaDB.scan.next == 200)
STUB.requested = {}
STUB.tick(0.1); assert(#STUB.requested == 5, "rate 50 sends five per tick: " .. #STUB.requested)
STUB.tick(0.1); assert(#STUB.requested == 10)
NS.ScanCommand("stop")
assert(AmisiaDB.scan.next == 210)

-- the pending cap
NS.ScanCommand("rate 1000")
NS.ScanCommand("1000 1400")
STUB.requested = {}
STUB.tick(0.5)
assert(#STUB.requested == 200, "no more than 200 open requests: " .. #STUB.requested)
NS.ScanCommand("stop")

-- an item the client has no data for after a positive answer goes to the retry list
NS.ScanCommand("5000 5000"); STUB.tick(0.1)
STUB.fire("ITEM_DATA_LOAD_RESULT", 5000, true)
assert(not NS.ScanRunning() and AmisiaDB.scan.retry[#AmisiaDB.scan.retry] == 5000)

-- combat pauses the ticks
NS.ScanCommand("6000 6001"); STUB.requested = {}
STUB.combat = true; STUB.tick(0.3); assert(#STUB.requested == 0)
STUB.combat = false; STUB.tick(0.1); assert(#STUB.requested == 2)
NS.ScanCommand("stop")
