-- The collector keeps the random suffixes it sees on links (scan.suffix): the suffix id of a link,
-- the item's stats with it (scored keys only), nothing for a link without one, the caps; the
-- planner reads them through Gear.SuffixStats.
assert(NS.LinkSuffix("|cff1eff00|Hitem:7001:0:0:0:0:0:-71:12345:60|h[Stiefel des Adlers]|h|r") == -71)
assert(NS.LinkSuffix("item:7001:0:0:0:0:0:15:0") == 15)
assert(NS.LinkSuffix("item:7001::::::::60") == nil and NS.LinkSuffix("item:7001") == nil and NS.LinkSuffix(nil) == nil)

STUB.item(7001, "Stiefel", 2)
local link = "|cff1eff00|Hitem:7001:0:0:0:0:0:-71:12345:60|h[Stiefel des Adlers]|h|r"
STUB.items[7001].stats = { ITEM_MOD_AGILITY_SHORT = 7, ITEM_MOD_STAMINA_SHORT = 6, ITEM_MOD_FIRE_RESISTANCE_SHORT = 5 }
NS.NoteItem(link)
local seen = AmisiaDB.scan.suffix and AmisiaDB.scan.suffix[7001]
assert(seen and seen[-71] == "AGILITY=7;STAMINA=6", "the stats with the suffix, scored keys only: " .. tostring(seen and seen[-71]))
-- a plain link adds nothing
STUB.item(7002, "Schlicht", 2)
NS.NoteItem(STUB.items[7002].link)
assert(AmisiaDB.scan.suffix[7002] == nil)
-- the planner sees it
local v = NS.Gear.SuffixStats(7001)
assert(v and v[-71] and v[-71].AGI == 7 and v[-71].STA == 6, "Gear.SuffixStats reads the own collector")
-- at most twelve suffixes per item
for i = 1, 20 do NS.NoteItem(("item:7001:0:0:0:0:0:%d:0"):format(i)) end
local n = 0
for _ in pairs(AmisiaDB.scan.suffix[7001]) do n = n + 1 end
assert(n == 12, "capped at twelve: " .. n)
-- off with the collector
NS.Set("tools.collect", false)
NS.NoteItem("item:7003:0:0:0:0:0:-5:0")
assert(AmisiaDB.scan.suffix[7003] == nil)
NS.Reset("tools.collect")
