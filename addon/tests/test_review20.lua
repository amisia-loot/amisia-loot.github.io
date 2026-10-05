-- Review of 2.0: the collector reads the bank tabs of the character bank, the guild bank list grows
-- with a material list filled at runtime, and the dead place and kind leftovers are gone.

-- 1. BANKFRAME_OPENED: the purchased bank tabs, not the old bags -1 and 5..11
local tabItem = STUB.item(7001, "Tab Thing", 3)
local reagent = STUB.item(7002, "Reagent Bag Thing", 3)
local oldBag = STUB.item(7003, "Old Bag Thing", 3)
STUB.bankTabs = { 12, 13 }
STUB.bags[12] = { tabItem }
STUB.bags[-1] = { reagent }   -- the keyring on Forever
STUB.bags[5] = { reagent }    -- the reagent bag on Forever
STUB.bags[8] = { oldBag }
STUB.fire("BANKFRAME_OPENED")
assert(AmisiaDB.scan.items[7001], "an item in a purchased bank tab is noted")
assert(not AmisiaDB.scan.items[7002], "the keyring and the reagent bag are not bank tabs")
assert(not AmisiaDB.scan.items[7003], "the old bank bag range is not read")
STUB.bankTabs = {}

-- 2. the guild bank list shows every row of a material list that was filled after the page was made
local panel = assert(NS.Panel("bank"), "bank panel")
local frame = panel.create(CreateFrame("Frame", nil, UIParent))
AmisiaDB.bank = { at = 1789400000, counts = {}, tabs = 1, filled = 1, total = 1, by = "Vuloo" }
for i = 1, 30 do
    NS.MATS[9000 + i], NS.MAT_ORDER[i] = "Stoff " .. i, 9000 + i
    AmisiaDB.bank.counts[9000 + i] = i
end
panel.refresh(frame)
local shown = 0
for _, r in ipairs(frame.list.rows) do if r.shown and r.item then shown = shown + 1 end end
-- (2.1: the list keeps 18 rows on the page; the wheel brings every material into view)
assert(#frame.list.items == 30 and #frame.list.rows == 18 and shown == 18, "18 rows of 30 materials: " .. #frame.list.rows)
for _ = 1, 20 do frame.list.scripts.OnMouseWheel(frame.list, -1) end
assert(frame.list.rows[18].item and frame.list.rows[18].item.id == 9030, "the last material is reachable")
for i = 1, 30 do NS.MATS[9000 + i], NS.MAT_ORDER[i] = nil, nil end
AmisiaDB.bank = nil

-- 3. no heroic suffix is stripped from a place any more: the place comes through as the data wrote it
local src = io.open(ADDON_DIR .. "/Map.lua", "r"):read("*a")
assert(not src:find('"/H$"', 1, true), "the heroic suffix strip is gone")
local pages = io.open(ADDON_DIR .. "/Pages/Map.lua", "r"):read("*a")
assert(not pages:find("Rüstmeister", 1, true), "the quartermaster kind is gone")
