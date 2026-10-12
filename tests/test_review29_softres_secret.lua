-- Review 2026-10-12 (SoftRes): the loot window's marks never read a secret item link of the Forever
-- client (a loot window in a boss fight); the item simply gets no mark then.
local link = STUB.item(32235, "Verfluchte Vision", 4)
NS.SetSoftRes("Chorf " .. link)
assert(#NS.ReservedBy(32235) == 1)
STUB.loot = { { link = link, name = "Verfluchte Vision" } }
local box = LootFrame.ScrollBox
local b1 = box.frames[1]
box:ShowFrom(1)
NS.MarkSoftResLoot()
assert(NS.SoftResMarkShown(b1) == true, "a plain link of a reserved item is marked")

-- the same slot with a secret link: ns.ItemID never sees it, the mark goes
STUB.secret[link] = true
local read = 0
local itemID = NS.ItemID
NS.ItemID = function(v)
    if STUB.secret[v] then read = read + 1 end
    return itemID(v)
end
box:ShowFrom(1)
NS.MarkSoftResLoot()
NS.ItemID = itemID
assert(read == 0, "a secret loot link is never read: " .. read)
assert(NS.SoftResMarkShown(b1) == false, "no mark from a secret link")
STUB.secret[link] = nil
STUB.loot = {}
