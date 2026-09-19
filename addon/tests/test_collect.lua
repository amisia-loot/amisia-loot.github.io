-- The item collector: bags, merchants, quests, auction house, loot, tooltips, chat links.
STUB.instance = { name = "Shattrath", type = "none", id = 0 }
local a = STUB.item(100, "Bag Thing", 2)
local b = STUB.item(101, "Vendor Thing", 1)
local c = STUB.item(102, "Quest Thing", 3)
local d = STUB.item(103, "Auction Thing", 4)
local e = STUB.item(104, "Drop Thing", 3)

-- bags and equipment
STUB.bags = { [0] = { a } }
_G.C_Container = { GetContainerNumSlots = function(bag) return STUB.bags[bag] and #STUB.bags[bag] or 0 end,
                   GetContainerItemLink = function(bag, slot) return STUB.bags[bag] and STUB.bags[bag][slot] end }
_G.GetInventoryItemLink = function(_, slot) return slot == 1 and STUB.item(105, "Helm", 4) or nil end
-- the collector registered BAG_UPDATE_DELAYED before C_Container existed in the stub: it looks the API up at load,
-- so re-run the module's lookup through PLAYER_ENTERING_WORLD which scans both
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(3)
assert(AmisiaDB.scan.items[105], "equipment noted")

-- merchant
_G.GetMerchantNumItems = function() return 1 end
_G.GetMerchantItemLink = function(i) return b end
STUB.target = "Griselda"
STUB.fire("MERCHANT_SHOW")
assert(AmisiaDB.scan.items[101] and AmisiaDB.scan.sources[101][1] == "Haendler: Griselda", "merchant noted with source")

-- quest
_G.GetTitleText = function() return "Die Fackel" end
_G.GetNumQuestRewards = function() return 1 end
_G.GetNumQuestChoices = function() return 0 end
_G.GetQuestItemLink = function(kind, i) return kind == "reward" and c or nil end
STUB.fire("QUEST_COMPLETE")
assert(AmisiaDB.scan.sources[102][1] == "Quest: Die Fackel")

-- auction house, retail style
_G.C_AuctionHouse = { GetBrowseResults = function() return { { itemKey = { itemID = 103 } } } end }
STUB.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
assert(AmisiaDB.scan.items[103] and AmisiaDB.scan.sources[103][1] == "Auktionshaus")
STUB.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 103)
assert(#AmisiaDB.scan.sources[103] == 1, "same source once")

-- loot window
STUB.loot = { { link = e, name = "Drop Thing" } }
STUB.target = "Wolf"
STUB.fire("LOOT_OPENED")
assert(AmisiaDB.scan.sources[104][1] == "Drop: Wolf")

-- tooltip and chat link
local f = STUB.item(106, "Linked", 4)
GameTooltip.GetItem = function() return "Linked", f end
GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
assert(AmisiaDB.scan.items[106])
STUB.fire("CHAT_MSG_GUILD", "schaut mal " .. STUB.item(107, "Chatted", 4))
assert(AmisiaDB.scan.items[107])

-- an item the client has not cached yet is requested and stored when it arrives
STUB.requested = {}
STUB.fire("CHAT_MSG_GUILD", "|cffa335ee|Hitem:108::::::::70:::::|h[Unknown]|h|r")
assert(not AmisiaDB.scan.items[108] and STUB.requested[1] == 108, "requested")
STUB.item(108, "Now Known", 4)
STUB.fire("ITEM_DATA_LOAD_RESULT", 108, true)
assert(AmisiaDB.scan.items[108], "stored on arrival")

-- counts and the switch
assert(NS.CollectCount() == 4, "four items with sources: " .. NS.CollectCount())
assert(NS.ScanStatus():find("Quellen gesammelt", 1, true) or NS.ScanStatus():find("gesammelt", 1, true), NS.ScanStatus())
AmisiaDB.settings.collect = false
STUB.fire("CHAT_MSG_GUILD", STUB.item(109, "Off", 4))
assert(not AmisiaDB.scan.items[109], "collector off")
