-- The page "raidjournal" (Raids, group Welt) shows the gear page's spec picker and item texts, so a
-- spec chosen there (BIS_CHANGED) and item names arriving later (GET_ITEM_INFO_RECEIVED while a
-- name was missing) and item stats arriving (Gear.OnData) redraw it, as on the pages gear and dungeons.
STUB.class, STUB.level = "WARRIOR", 60
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.ShowPage("raidjournal")
assert(NS.CurrentPage() == "raidjournal", "the page")
local refreshes = 0
local realRefresh = NS.Refresh
NS.Refresh = function(...) refreshes = refreshes + 1; return realRefresh(...) end

-- the spec picker
NS.BisSetSpec("tank")
assert(refreshes > 0, "a spec chosen on the page redraws it")

-- an item name the client did not have: once it arrives, the page is drawn again
local K = NS.GearPageKit
K.namesFresh()
K.itemText(987654)   -- unknown to the client: "Item 987654", marked missing
assert(K.nameMissing(), "a name is missing")
refreshes = 0
STUB.fire("GET_ITEM_INFO_RECEIVED", 987654, true)
STUB.tick(1)
assert(refreshes > 0, "the arrived name redraws the page")

-- item stats that arrive later (behind the page's own requests: answers and timeouts both notify)
refreshes = 0
local ID = 987655
assert(NS.Gear.Stats(ID) == nil, "requested")
STUB.item(ID, "Spaeter Helm", 2)
STUB.items[ID].equipLoc, STUB.items[ID].classID = "INVTYPE_HEAD", 4
STUB.items[ID].stats = { ITEM_MOD_STRENGTH_SHORT = 5 }
STUB.tick(14)
NS.Refresh = realRefresh
assert(refreshes > 0, "arrived item data redraws the page")
