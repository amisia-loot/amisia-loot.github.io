-- The loot toast (F-152, D-79): the own loot line ("You receive loot: ...") and a pushed item (a quest
-- reward: "You receive item: ...") show "+Name xN" with the item's icon in its quality's colour; another
-- player's loot, a lower quality than the setting and the switched off toast show nothing; the lines
-- stack, rise, fade and go after SHOW seconds; at most MAX at once.
local LT = NS.Theme.LOOTTOAST
STUB.item(4711, "Rute von Helcular", 2)
local link = "|cff1eff00|Hitem:4711::::::::30:::::::|h[Rute von Helcular]|h|r"
local me = UnitName("player")
assert(NS.Get("ui.lootToast") == true, "on by default")

-- looted: one line
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
local shown = NS.LootToastLines()
assert(#shown == 1 and shown[1].id == 4711 and shown[1].text == "|cff1eff00+Rute von Helcular|r", tostring(shown[1] and shown[1].text))
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
-- the settings' example
STUB.tick(LT.SHOW + 0.1)
AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
NS.SettingItem("ui.lootToastTest").run()
assert(#NS.LootToastLines() == 1 and NS.LootToastLines()[1].text:find(NS.L["Leinenstoff"] .. " x3", 1, true))
print("loot toast ok")
