--[[preload
-- the classic loot window (Classic Era, TBC Anniversary): LootButton1..4, paged, set up by
-- LootFrame_UpdateButton as the client's Classic/LootFrame.lua does; no scroll box
LOOTFRAME_NUMBUTTONS = 4
LootFrame = { page = 1, numLootItems = 0 }
for i = 1, 4 do CreateFrame("Button", "LootButton" .. i, nil) end
function LootFrame_UpdateButton(index)
    local per = LOOTFRAME_NUMBUTTONS
    if LootFrame.numLootItems > per then per = per - 1 end
    local button = _G["LootButton" .. index]
    local slot = per * (LootFrame.page - 1) + index
    if slot <= LootFrame.numLootItems and index <= per then
        button.slot = slot
        button:Show()
    else
        button:Hide()
    end
end
function LootFrame_Update()
    for i = 1, LOOTFRAME_NUMBUTTONS do LootFrame_UpdateButton(i) end
end
]]
--[[game era]]
-- Soft-reserve marks in the classic loot window (Raid/SoftRes.lua, audit 2026-11-07): the marks
-- came only through the scroll box of the Forever client; Era and TBC page their LootButtons.
assert(NS.GAME == "era", tostring(NS.GAME))
local res = STUB.item(32235, "Verfluchte Vision", 4)
local other = STUB.item(32236, "Anderes Ding", 4)
NS.SetSoftRes("Chorf " .. res)
assert(#NS.ReservedBy(32235) == 1)
-- six items: three per page (the fourth button makes room for the arrows); the reserved one in slot 5
STUB.loot = {}
for i = 1, 6 do STUB.loot[i] = { link = i == 5 and res or other, name = "x" } end
LootFrame.numLootItems = 6
LootFrame.page = 1
LootFrame_Update()
for i = 1, 4 do assert(not NS.SoftResMarkShown(_G["LootButton" .. i]), "page 1 has no reserved item: " .. i) end
LootFrame.page = 2
LootFrame_Update()
assert(NS.SoftResMarkShown(LootButton2) == true, "slot 5 is the second button of page 2")
assert(NS.SoftResMark(LootButton2):GetText() == "SR")
assert(not NS.SoftResMarkShown(LootButton1) and not NS.SoftResMarkShown(LootButton3))
-- back to page 1: the button shows another item, its mark goes
LootFrame.page = 1
LootFrame_Update()
assert(NS.SoftResMarkShown(LootButton2) == false, "the mark follows the slot")
-- the event path marks too (LOOT_SLOT_CLEARED, LOOT_OPENED)
LootFrame.page = 2
NS.MarkSoftResLoot()
assert(NS.SoftResMarkShown(LootButton2) == true, "ns.MarkSoftResLoot marks the classic buttons")
-- the setting off: no mark
NS.Set("softres.lootMark", false)
LootFrame_Update()
assert(NS.SoftResMarkShown(LootButton2) == false, "off with the setting")
STUB.loot = {}
