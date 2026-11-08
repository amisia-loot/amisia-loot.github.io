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
assert(NS.Get("toast.show") == true, "on by default")

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
NS.Set("toast.quality", "3")
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
assert(#NS.LootToastLines() == 0, "below the quality")
NS.Reset("toast.quality")
-- switched off: nothing
NS.Set("toast.show", false)
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
assert(#NS.LootToastLines() == 0, "off")
NS.Reset("toast.show")
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
NS.Set("toast.money", false)
STUB.fire("CHAT_MSG_MONEY", "You loot 5 Copper")
assert(#NS.LootToastLines() == 2, "no line without money, for a sale or with money off")
NS.Reset("toast.money")
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
NS.Set("toast.size", 24)
local big = NS.LootToastLines()[1].frame
assert(big.size == 24 and big.icon._w == 24 + LT.ICON_PAD and big._h == 24 + LT.LINE_PAD, "the size follows the setting")
NS.Set("toast.size", 99)
assert(NS.LootToastLines()[1].frame.size <= LT.SIZE_MAX, "never past the most")
NS.Reset("toast.size")
clear()
-- the settings' example: an item and money
NS.SettingItem("toast.test").run()
local ex = NS.LootToastLines()
assert(#ex == 2 and ex[1].text:find(NS.L["Leinenstoff"] .. " x3", 1, true) and ex[2].text:find("UI-GoldIcon", 1, true))
clear()

-- the section "Item-Anzeige" (F-158, D-89): its own settings, everything applies at once
local sec
for _, s in ipairs(NS.schema) do if s.key == "toast" then sec = s end end
assert(sec and sec.group == "amisia", "its own section")
assert(NS.SettingItem("ui.lootToast") == nil, "no longer under Oberfläche")
-- the font, outline and shadow
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
local l = NS.LootToastLines()[1].frame
NS.Set("toast.font", "morpheus")
local file, sz, flags = l.text:GetFont()
assert(file == LT.FONTS.morpheus and sz == LT.SIZE, "the font: " .. tostring(file))
NS.Set("toast.outline", "THICKOUTLINE")
file, sz, flags = l.text:GetFont()
assert(flags == "THICKOUTLINE", "the outline: " .. tostring(flags))
NS.Set("toast.outline", "none")
assert(select(3, l.text:GetFont()) == "", "no outline")
NS.Set("toast.shadow", false)
assert(l.text.shadowX == 0 or (l.text.GetShadowOffset and l.text:GetShadowOffset() == 0), "no shadow")
NS.Reset("toast.font"); NS.Reset("toast.outline"); NS.Reset("toast.shadow")
-- no icon: the text at the line's left edge
NS.Set("toast.icon", false)
assert(not l.icon:IsShown(), "no icon")
NS.Reset("toast.icon")
assert(l.icon:IsShown(), "the icon again")
-- the opacity
NS.Set("toast.alpha", 50)
AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
assert(l:GetAlpha() <= 0.5, "half transparent: " .. tostring(l:GetAlpha()))
NS.Reset("toast.alpha")
clear()
-- the lines at once
NS.Set("toast.lines", 2)
for _ = 1, 4 do STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link)) end
assert(#NS.LootToastLines() == 2, "two at once")
NS.Reset("toast.lines")
clear()
-- the time shown: 6 s, the line still there after the default 3 s
NS.Set("toast.duration", 6)
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
STUB.tick(LT.SHOW + 0.5)
AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
assert(#NS.LootToastLines() == 1, "longer than the default")
STUB.tick(3)
AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
assert(#NS.LootToastLines() == 0, "gone after 6 s")
NS.Reset("toast.duration")
-- the motion: down sinks, still stays
local function yAfter(motion)
    NS.Set("toast.motion", motion)
    STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
    STUB.tick(1)
    AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
    local y = NS.LootToastLines()[1].frame.points.TOPLEFT.y
    clear()
    return y
end
assert(yAfter("up") > 0 and yAfter("down") < 0 and yAfter("still") == 0, "up, down, still")
NS.Reset("toast.motion")
-- new lines on top
NS.Set("toast.order", "up")
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_PUSHED_SELF_MULTIPLE:format(link, 3))
local two = NS.LootToastLines()
assert(two[2].frame.points.TOPLEFT.y > two[1].frame.points.TOPLEFT.y, "the newest above")
NS.Reset("toast.order")
clear()
-- the alignment: right moves a line to the right
NS.Set("toast.align", "right")
STUB.fire("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link))
assert(NS.LootToastLines()[1].frame.points.TOPLEFT.x > 0, "right aligned")
NS.Reset("toast.align")
clear()

-- moving: the button unlocks it with the frame and example lines that stay; a drag saves the place,
-- "Fertig" fixes it, the lines run out; "Position zurücksetzen" and the window reset bring it back
NS.SettingItem("toast.move").run()
assert(NS.LootToastUnlocked() and AmisiaLootToast.box:IsShown() and AmisiaLootToast.mouseEnabled, "unlocked")
assert(#NS.LootToastLines() == 2, "example lines")
STUB.tick(LT.SHOW + 5)
AmisiaLootToast.scripts.OnUpdate(AmisiaLootToast, 0.1)
assert(#NS.LootToastLines() == 2, "they stay while moving")
AmisiaLootToast:ClearAllPoints()
AmisiaLootToast:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 200, -150)
AmisiaLootToast.scripts.OnDragStop(AmisiaLootToast)
local pt = AmisiaDB.settings.toast.point
assert(pt and pt[1] == "TOPLEFT" and pt[2] == 200 and pt[3] == -150, "the place saved")
AmisiaLootToast.box.done:Click()
assert(not NS.LootToastUnlocked() and not AmisiaLootToast.box:IsShown() and not AmisiaLootToast.mouseEnabled, "Fertig")
clear()
NS.SettingItem("toast.resetPos").run()
assert(AmisiaDB.settings.toast.point == nil and AmisiaLootToast.points.CENTER and AmisiaLootToast.points.CENTER.x == LT.X, "back")
AmisiaDB.settings.toast.point = { "TOP", 0, -50 }
NS.ResetPositions()
assert(AmisiaDB.settings.toast.point == nil, "the window reset brings it back too")
print("loot toast ok")
