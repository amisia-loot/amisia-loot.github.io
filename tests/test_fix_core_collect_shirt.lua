-- An armour piece without stats (a shirt, a tabard) is complete once the client gave its (empty)
-- stats table: every bag update does not store its line again. Gear whose stats the client has not
-- given yet is still stored again (audit 2026-11-07).
local calls = 0
-- Scan.lua keeps GetItemInfo in a local; GetItemStats it reads on each store
local stats = C_Item.GetItemStats
C_Item.GetItemStats = function(...) calls = calls + 1; return stats(...) end

STUB.item(8001, "Hemd", 1)
STUB.items[8001].stats = {}
assert(NS.NoteItem(8001) == true)
assert(AmisiaDB.scan.items[8001], "the shirt is stored")
local after = calls
assert(NS.NoteItem(8001) == true)
assert(NS.NoteItem(STUB.items[8001].link) == true)
assert(calls == after, "the complete shirt is not stored again: " .. (calls - after))

-- a helm whose stats have not come yet is stored again, and complete once they came
STUB.item(8002, "Helm", 2)
STUB.items[8002].stats = nil
assert(NS.NoteItem(8002) == true)
after = calls
NS.NoteItem(8002)
assert(calls > after, "gear without its stats is stored again")
STUB.items[8002].stats = { ITEM_MOD_STAMINA_SHORT = 5 }
NS.NoteItem(8002)
assert(AmisiaDB.scan.items[8002]:find("STAMINA_SHORT=5", 1, true), "the stats came")
after = calls
NS.NoteItem(8002)
assert(calls == after, "complete with its stats")
