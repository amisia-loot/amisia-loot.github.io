-- The loot toast (F-152, D-79): the own loot line ("You receive loot: ...") and a pushed item (a quest
-- reward: "You receive item: ...") show "+Name xN" with the item's icon in its quality's colour (also
-- for Forever's named colour form |cnIQ2:); another player's loot, a lower quality than the setting
-- and the switched off toast show nothing, nor an item pushed while a vendor, the mail or a trade is
-- open; money looted or a quest's money shows "+1g 2s 3c" with the coins in their colours; the font size follows the setting; the lines stack, rise, fade and go after SHOW
-- seconds; at most MAX at once.
local LT = NS.Theme.LOOTTOAST
STUB.item(4711, "Rute von Helcular", 2)
local link = "|cff1eff00|Hitem:4711::::::::30:::::::|h[Rute von Helcular]|h|r"
local me = UnitName("player")
assert(NS.Get("ui.lootToast") == true, "on by default")

-- looted: one line
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
local shown = NS.LootToastLines()
local green = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[2] and ITEM_QUALITY_COLORS[2].hex or "|cff1eff00"
assert(#shown == 1 and shown[1].id == 4711 and shown[1].text == green .. "+Rute von Helcular|r", tostring(shown[1] and shown[1].text))
assert(shown[1].frame.size == LT.SIZE and shown[1].frame.icon._w == LT.SIZE + LT.ICON_PAD, "the default size")
assert(AmisiaLootToast and AmisiaLootToast:IsShown() and AmisiaLootToast.strata == "HIGH", "the holder over the world")
assert(shown[1].frame.icon.texture ~= nil, "with its icon")
-- a quest's reward, three of them: the second line under the first
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_PUSHED_SELF_MULTIPLE:format(link, 3))
shown = NS.LootToastLines()
assert(#shown == 2 and shown[2].text:find("+Rute von Helcular x3", 1, true), tostring(shown[2] and shown[2].text))
assert(shown[2].frame.points.TOPLEFT.y < shown[1].frame.points.TOPLEFT.y, "stacked under it")
-- someone else's loot: nothing
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM:format("Andere", link))
assert(#NS.LootToastLines() == 2, "not for others")
-- the lines go after SHOW seconds
STUB.tick(LT.SHOW + 0.1)
AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
assert(#NS.LootToastLines() == 0 and AmisiaLootToast.scripts.OnUpdate == nil, "gone, the driver stops")
-- the quality: green under "Rar (blau)" shows nothing
NS.Set("ui.lootToastQuality", "3")
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
assert(#NS.LootToastLines() == 0, "below the quality")
NS.Reset("ui.lootToastQuality")
-- switched off: nothing
NS.Set("ui.lootToast", false)
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
assert(#NS.LootToastLines() == 0, "off")
NS.Reset("ui.lootToast")
-- at most MAX at once, the oldest goes
for _ = 1, LT.MAX + 2 do STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link)) end
assert(#NS.LootToastLines() == LT.MAX, "at most " .. LT.MAX)
local function clear()
    STUB.tick(LT.SHOW + 0.1)
    AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
    assert(#NS.LootToastLines() == 0)
end
clear()
-- Forever's link with the named colour (|cnIQ2:) and an item the client has no quality for: the link's colour
STUB.item(4712, "Grüner Ring", nil); STUB.items[4712].quality = nil
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format("|cnIQ2:|Hitem:4712::::::::30:::::::|h[Grüner Ring]|h|r"))
assert(NS.LootToastLines()[1].text == "|cnIQ2:+Grüner Ring|r", tostring(NS.LootToastLines()[1].text))
clear()
-- money: looted ("You loot 1 Gold, 2 Silver, 3 Copper") and a quest's reward; nothing else
_G.GOLD_AMOUNT, _G.SILVER_AMOUNT, _G.COPPER_AMOUNT = "%d Gold", "%d Silver", "%d Copper"
assert(NS.LootToastCopperOf("You loot 1 Gold, 2 Silver, 3 Copper") == 10203 and NS.LootToastCopperOf("You loot 51 Copper") == 51)
STUB.fire("CHAT_MSG_MONEY", "You loot 1 Gold, 2 Silver, 3 Copper")
local m = NS.LootToastLines()
assert(#m == 1 and m[1].text:find("|cffffd7001|r", 1, true) and m[1].text:find("|cffc7c7cf2|r", 1, true)
    and m[1].text:find("|cffeda55f3|r", 1, true) and m[1].text:find("UI-GoldIcon", 1, true), tostring(m[1] and m[1].text))
STUB.fire("QUEST_TURNED_IN", 123, 450, 251)
m = NS.LootToastLines()
assert(#m == 2 and m[2].text:find("|cffc7c7cf2|r", 1, true) and m[2].text:find("|cffeda55f51|r", 1, true), tostring(m[2] and m[2].text))
-- a quest without money, the purse growing by a sale (no loot line): nothing
STUB.fire("QUEST_TURNED_IN", 124, 450, 0)
STUB.fire("PLAYER_MONEY")
NS.Set("ui.lootToastMoney", false)
STUB.fire("CHAT_MSG_MONEY", "You loot 5 Copper")
assert(#NS.LootToastLines() == 2, "no line without money, for a sale or with money off")
NS.Reset("ui.lootToastMoney")
clear()
-- a purchase: "You receive item" while the vendor is open shows nothing; looted at the same time does
STUB.fire("MERCHANT_SHOW")
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_PUSHED_SELF:format(link))
assert(#NS.LootToastLines() == 0, "no line for a purchase")
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
assert(#NS.LootToastLines() == 1, "looted still shows")
STUB.fire("MERCHANT_CLOSED")
-- the mail and a trade as well
STUB.fire("MAIL_SHOW")
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_PUSHED_SELF:format(link))
STUB.fire("MAIL_CLOSED")
assert(#NS.LootToastLines() == 1, "no line from the mail")
-- after the windows closed a pushed item (a quest's reward) shows again
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_PUSHED_SELF:format(link))
assert(#NS.LootToastLines() == 2, "a quest's reward")
clear()
-- the font size: new lines and those shown take it
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
NS.Set("ui.lootToastSize", 24)
local big = NS.LootToastLines()[1].frame
assert(big.size == 24 and big.icon._w == 24 + LT.ICON_PAD and big._h == 24 + LT.LINE_PAD, "the size follows the setting")
NS.Set("ui.lootToastSize", 99)
assert(NS.LootToastLines()[1].frame.size <= LT.SIZE_MAX, "never past the most")
NS.Reset("ui.lootToastSize")
clear()
-- the settings' example: an item and money
NS.SettingItem("ui.lootToastTest").run()
local ex = NS.LootToastLines()
assert(#ex == 2 and ex[1].text:find(NS.L["Leinenstoff"] .. " x3", 1, true) and ex[2].text:find("UI-GoldIcon", 1, true))
print("loot toast ok")
