-- Review 2026-10-12 (roll frame, award dialog): the slot links of the open loot window go through
-- ns.Plain before ns.ItemID, as every other loot reader does; a secret link (a loot window in a boss
-- fight on Forever) counts as no item of the window.
local function modClick(link, alt, shift)
    STUB.alt, STUB.shift = alt and true or false, shift and true or false
    HandleModifiedItemClick(link)
    STUB.alt, STUB.shift = false, false
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active(), "a recording runs")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
-- the same item, another string: only the loot window's copy is secret
local lootLink = (link:gsub("item:32235", "item:32235:0"))
assert(lootLink ~= link and NS.ItemID(lootLink) == 32235)
STUB.loot = { { link = lootLink, name = "Cursed Vision of Sargeras" } }
STUB.fire("LOOT_OPENED")
assert(NS.InLootWindow(32235) == true, "a plain slot link is found")

STUB.secret[lootLink] = true
local read = 0
local itemID = NS.ItemID
NS.ItemID = function(v)
    if STUB.secret[v] then read = read + 1 end
    return itemID(v)
end
assert(NS.InLootWindow(32235) == false, "a secret slot link is no item of the window")
NS.AwardFromRoll("Fraktur", 32235, link)
modClick(link, true, true)
local D = AmisiaAwardDialog
assert(D and D:IsShown(), "the dialog opens")
NS.ItemID = itemID
assert(read == 0, "no secret slot link is read: " .. read)
assert(D.give:GetText() == "Eintragen", "without a readable slot the dialog enters the award directly: " .. tostring(D.give:GetText()))
D:Hide()
STUB.secret[lootLink] = nil
STUB.fire("LOOT_CLOSED")
STUB.loot = {}
