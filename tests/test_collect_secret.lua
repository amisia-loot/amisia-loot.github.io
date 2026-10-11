-- The item collector in a boss fight on the Forever client: chat text, unit names and GUIDs can be
-- secret there. A secret value is skipped, never searched, compared or written into a source note.
STUB.instance = { name = "Sturmwind", type = "none", id = 0 }

-- a secret raid chat line with an item link: nothing taken from it
local line = "Hier " .. STUB.item(301, "Secret Link", 4)
STUB.secret[line] = true
STUB.fire("CHAT_MSG_RAID", line)
assert(not AmisiaDB.scan or not AmisiaDB.scan.items or not AmisiaDB.scan.items[301], "secret chat text is not read")
STUB.secret[line] = nil
STUB.fire("CHAT_MSG_RAID", line)
assert(AmisiaDB.scan.items[301], "the same line in plain text is read")

-- a loot window from an object (no NPC id) while the target's name is secret: no name in a note
-- (the old code wrote the target's secret name into the saved source note)
local link = STUB.item(302, "Boss Drop", 4)
STUB.instance = { name = "Die Todesminen", type = "party", id = 36 }
STUB.loot = { { link = link, name = "Boss Drop", src = "GameObject-0-3110-36-47-1777-00002E7CF2" } }
STUB.targetGUID = "Creature-0-3110-36-47-639-00002E7CF3"
STUB.target = "Geheimer Boss"
STUB.secret[STUB.targetGUID] = true
STUB.secret[STUB.target] = true
STUB.fire("LOOT_OPENED")
assert(AmisiaDB.scan.items[302], "the item itself is kept")
for _, n in ipairs(AmisiaDB.scan.sources and AmisiaDB.scan.sources[302] or {}) do
    assert(not n:find("Geheimer", 1, true), n)
end

-- a merchant whose name is secret: "?" in its place
STUB.instance = { name = "Sturmwind", type = "none", id = 0 }
STUB.npc = "Geheimer Haendler"
STUB.secret[STUB.npc] = true
STUB.target = nil
_G.GetMerchantNumItems = function() return 1 end
_G.GetMerchantItemLink = function() return STUB.item(303, "Sold", 2) end
STUB.fire("MERCHANT_SHOW")
note = AmisiaDB.scan.sources[303] and AmisiaDB.scan.sources[303][1]
assert(note and note:find("^Haendler: %?") and not note:find("Geheimer", 1, true), tostring(note))
