-- The trade helper (Handover.lua, D-39): an awarded item in the own bags appears in "Noch zu
-- übergeben", one without an award or awarded to oneself does not; the time from the tooltip line
-- (German and English, minutes and hours); warnings at 30 and 10 minutes once each, with sound;
-- the helper window only for the winner and only with his items; a click inserts (nothing in combat,
-- nothing while the cursor holds something); a completed trade marks the award handed over, a
-- cancelled one does not; a copy moved between bags stays the same entry (GUID); a copy that runs
-- out leaves the list; secret values (partner name, tooltip text, the message) do not error.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return true end end
    return false
end
local function count(part)
    local n = 0
    for _, m in ipairs(STUB.messages) do if has(m, part) then n = n + 1 end end
    return n
end

STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Anna Bergmann", class = "PRIEST" },
                { name = "Fraktur", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = NS.Active()
assert(s, "a recording")
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(30000, "Brustplatte", 4)
local link3 = STUB.item(32837, "Warglaive of Azzinoth", 5)
_G.TradeFrame = CreateFrame("Frame", "TradeFrame", UIParent)

local function bags() STUB.fire("BAG_UPDATE_DELAYED"); STUB.tick(1) end
local function list() return NS.HandoverList() end
local function helper() return AmisiaTradeHelper end
local function helperShown() return helper() ~= nil and helper():IsShown() end
local function openTrade(name)
    STUB.npc = name
    STUB.tradeSlots = {}
    STUB.fire("TRADE_SHOW")
end
local function closeTrade(how)
    -- how: "done" removes the traded copies from the bags, "cancel" puts them back
    if how == "done" then
        for _, t in pairs(STUB.tradeSlots) do
            STUB.bags[t.bag][t.slot] = false
            if STUB.bagInfo[t.bag] then STUB.bagInfo[t.bag][t.slot] = nil end
        end
    end
    STUB.tradeSlots = {}
    STUB.fire("TRADE_CLOSED")
    STUB.fire("BAG_UPDATE_DELAYED")
    STUB.tick(2)
end

---------------------------------------------------------------------------
-- the settings, the command with nothing open
---------------------------------------------------------------------------
assert(NS.SettingItem("trade.enabled").default == true and NS.SettingItem("trade.warn").default == "both")
assert(NS.SettingItem("trade.sound").default == true)
assert(NS.Visible(NS.SettingItem("trade.enabled").section), "the section is everyone's")
NS.Dispatch("uebergabe")
assert(said("Nichts zu übergeben."), "nothing open")
STUB.messages = {}
NS.Dispatch("handover")
assert(said("Nichts zu übergeben."), "the English word")

---------------------------------------------------------------------------
-- the duration of the tooltip line, German and English
---------------------------------------------------------------------------
local P = NS.HandoverParseDuration
assert(P("1 Std. 59 Min.") == 7140, P("1 Std. 59 Min."))
assert(P("59 Min.") == 3540 and P("2 Std.") == 7200 and P("30 Sek.") == 30)
assert(P("1 Stunde 5 Minuten") == 3900)
assert(P("1 hour 59 minutes") == 7140 and P("1 hr 12 mins") == 4320 and P("45 min") == 2700)
assert(P("2 hours") == 7200 and P("30 sec") == 30 and P("1:12") == 4320)
assert(P("bald") == nil and P(nil) == nil)
local L1 = NS.HandoverParseLine
assert(L1(BIND_TRADE_TIME_REMAINING:format("1 Std. 12 Min.")) == 4320, "the German line")
assert(L1("|cffffffff" .. BIND_TRADE_TIME_REMAINING:format("25 Min.") .. "|r") == 1500, "colour codes")
local de = BIND_TRADE_TIME_REMAINING
_G.BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to loot this item for the next %s."
assert(L1(BIND_TRADE_TIME_REMAINING:format("1 hour 12 min")) == 4320, "the English line")
assert(L1(BIND_TRADE_TIME_REMAINING:format("9 min")) == 540)
_G.BIND_TRADE_TIME_REMAINING = de
-- a text the template does not fit: the numbers of the whole line
assert(L1("Handelbar noch 40 Min.") == 2400)

---------------------------------------------------------------------------
-- an awarded item in the bags appears, one not awarded does not, nor one awarded to oneself
---------------------------------------------------------------------------
local a1 = NS.AddAwardTo(s, { name = "Anna Bergmann", item = 32235, kind = "MS", src = "Illidan Stormrage" })
STUB.tick(5)
local mine = NS.AddAwardTo(s, { name = "Vuloo", item = 32837, kind = "OS", src = "Illidan Stormrage" })
STUB.bags[0] = { link, link2, link3 }
STUB.bagInfo[0] = { [1] = { guid = "Item-1-AAA", trade = "1 Std. 12 Min." },
                    [2] = { guid = "Item-1-BBB", trade = "1 Std. 50 Min." },
                    [3] = { guid = "Item-1-CCC", trade = "1 Std. 55 Min." } }
STUB.messages = {}
bags()
local l = list()
assert(#l == 1, "only the item awarded to someone else: " .. #l)
assert(l[1].a == a1 and l[1].to == "Anna Bergmann" and l[1].copy.guid == "Item-1-AAA")
assert(NS.HandoverLeftText(l[1]) == "noch 1:12 h", NS.HandoverLeftText(l[1]))
assert(#STUB.messages == 0, "no warning with 72 minutes left")
NS.Dispatch("uebergabe")
assert(said("Noch zu übergeben: 1") and said("an Anna Bergmann, noch 1:12 h"), "the command lists it")
assert(NS.CurrentPage() == "awards" and NS.AwardsPageFrame().handover:IsShown(), "and opens the list on the page")
local H = NS.AwardsPageFrame().handover
assert(H.list.rows[1]:IsShown() and has(H.list.rows[1].to:GetText(), "Anna Bergmann") and has(H.list.rows[1].left:GetText(), "1:12 h"))
H.back:Click()
assert(not NS.AwardsPageFrame().handover:IsShown() and NS.AwardsPageFrame().officer:IsShown(), "put away")
assert(has(NS.AwardsPageFrame().officer.head:GetText(), "1 zu übergeben"), NS.AwardsPageFrame().officer.head:GetText())

-- master loot straight to the receiver (a loot line): that copy never was in these bags
local a2 = NS.AddAwardTo(s, { name = "Fraktur", item = 30000, kind = "MS", src = "Illidan Stormrage" })
s.items[#s.items + 1] = { name = "Fraktur", item = 30000, count = 1, t = a2.t }
bags()
assert(#list() == 1, "Fraktur got his by master loot")
s.items[#s.items] = nil
bags()
assert(#list() == 2 and list()[2].a == a2, "without the loot line it waits in the bags too")
NS.DeleteAward(s, a2.id)
bags()
assert(#list() == 1, "a deleted award leaves")

---------------------------------------------------------------------------
-- warnings at 30 and 10 minutes, once each, with sound
---------------------------------------------------------------------------
STUB.sounds = {}
STUB.messages = {}
STUB.bagInfo[0][1].trade = "31 Min."
bags()
assert(#STUB.messages == 0, "31 minutes: no warning yet")
STUB.bagInfo[0][1].trade = "29 Min."
bags()
assert(count("Noch 29 Minuten: ") == 1 and said("an Anna Bergmann übergeben."), table.concat(STUB.messages, "\n"))
assert(#STUB.sounds == 1, "with sound")
STUB.tick(31); bags()
assert(count("Minuten: ") == 1, "once")
STUB.bagInfo[0][1].trade = "9 Min."
bags()
assert(count("Noch 9 Minuten: ") == 1 and #STUB.sounds == 2, "the second warning")
STUB.tick(31); bags()
assert(count("Minuten: ") == 2, "each once")
assert(has(NS.HandoverLeftText(list()[1]), "noch 9 min"))

-- only at 10 minutes; off; no sound
local a3 = NS.AddAwardTo(s, { name = "Chorf", item = 30000, kind = "OS", src = "Illidan Stormrage" })
NS.Set("trade.warn", "ten")
NS.Set("trade.sound", false)
STUB.bagInfo[0][2].trade = "20 Min."
STUB.messages = {}
bags()
assert(#list() == 2 and #STUB.messages == 0, "only at 10 minutes")
STUB.bagInfo[0][2].trade = "8 Min."
bags()
assert(count("Noch 8 Minuten: ") == 1 and #STUB.sounds == 2, "the 10 minute one, silent")
NS.Set("trade.warn", "both")
NS.Set("trade.sound", true)

---------------------------------------------------------------------------
-- the trade window: only for the winner, only with his items
---------------------------------------------------------------------------
STUB.bagInfo[0][1].trade = "1 Std. 2 Min."
STUB.bagInfo[0][2].trade = "1 Std. 40 Min."
bags()
openTrade("Fraktur")
assert(not helperShown(), "no items for Fraktur")
closeTrade("cancel")
openTrade("Anna Bergmann")
assert(helperShown(), "Anna gets the helper")
assert(helper().button:GetText() == "Amisia: 1 Item einlegen", helper().button:GetText())
assert(has(helper().text:GetText(), "Für Anna Bergmann") and has(helper().by:GetText(), "laut Vergabe von Vuloo"))
-- nothing in combat
STUB.combat = true
helper().button:Click()
assert(STUB.tradeSlots[1] == nil and STUB.cursor == nil and said("Im Kampf legt Amisia nichts ein"), "nothing in combat")
STUB.combat = false
-- nothing while the cursor holds something
STUB.cursor = { bag = 0, slot = 3 }
helper().button:Click()
assert(STUB.tradeSlots[1] == nil and said("Du hältst etwas mit der Maus"), "nothing with the cursor full")
STUB.cursor = nil
-- the click inserts
helper().button:Click()
assert(STUB.tradeSlots[1] and STUB.tradeSlots[1].bag == 0 and STUB.tradeSlots[1].slot == 1, "Anna's copy in slot 1")
assert(STUB.tradeSlots[2] == nil and STUB.cursor == nil, "only hers")
assert(said("1 Item eingelegt."), "told")
STUB.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
assert(helper().button:GetText() == "Amisia: alles eingelegt" and not helper().button:IsEnabled())

-- a cancelled trade changes nothing
STUB.fire("UI_INFO_MESSAGE", 61, ERR_TRADE_CANCELLED)
closeTrade("cancel")
assert(not helperShown(), "the helper goes with the trade window")
assert(#list() == 2 and not NS.HandedOver(s, a1), "a cancelled trade does not mark")
assert(not said("Übergeben:"))

-- a first name alone finds her while only one raider carries it; the trade completes
openTrade("Anna")
assert(helperShown() and helper().button:GetText() == "Amisia: 1 Item einlegen")
helper().button:Click()
STUB.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
STUB.gameMessages[60] = "ERR_TRADE_COMPLETE"
STUB.fire("UI_INFO_MESSAGE", 60, ERR_TRADE_COMPLETE)
closeTrade("done")
assert(said("Übergeben: ") and said(" an Anna."), table.concat(STUB.messages, "\n"))
assert(NS.HandedOver(s, a1), "marked")
local key = NS.RaidKey(s) .. "/" .. a1.id
assert(AmisiaDB.handover[key] and AmisiaDB.handover[key].to == "Anna" and AmisiaDB.handover[key].g == "Item-1-AAA")
assert(#list() == 1 and list()[1].a == a3, "Anna's entry left the list")
-- the awards page marks it
NS.ShowPage("awards")
assert(NS.AwardsPageFrame().handover:IsShown(), "a new entry (Chorf's) brings the list back")
NS.AwardsPageFrame().handover.back:Click()
local O = NS.AwardsPageFrame().officer
assert(O:IsShown())
local marked = false
for _, r in ipairs(O.list.rows) do
    if r.item and r.item.a == a1 and has(r.name:GetText(), "übergeben") then marked = true end
end
assert(marked, "the award reads übergeben")

---------------------------------------------------------------------------
-- a copy moved between bags keeps its entry (GUID); the click takes it from its new place
---------------------------------------------------------------------------
STUB.messages = {}
STUB.bags[1] = { link3, link3, false }
STUB.bagInfo[1] = { [1] = { guid = "Item-1-X1", trade = "1 Std. 59 Min." }, [2] = { guid = "Item-1-X2", trade = "1 Std. 59 Min." } }
STUB.bags[0][2] = false
STUB.bags[1][3] = link2
STUB.bagInfo[1][3] = { guid = "Item-1-BBB", trade = "7 Min." }
STUB.bagInfo[0][2] = nil
bags()
l = list()
assert(#l == 1 and l[1].a == a3 and l[1].copy.guid == "Item-1-BBB" and l[1].copy.bag == 1 and l[1].copy.slot == 3, "moved, same copy")
assert(count("Minuten: ") == 0, "no second warning after the move")
openTrade("Chorf")
helper().button:Click()
assert(STUB.tradeSlots[1] and STUB.tradeSlots[1].bag == 1 and STUB.tradeSlots[1].slot == 3, "inserted from its new place")
-- the completion message is secret (and its type unknown): the bags decide
STUB.gameMessages[60] = nil
STUB.secret[ERR_TRADE_COMPLETE] = true
STUB.fire("UI_INFO_MESSAGE", 60, ERR_TRADE_COMPLETE)
STUB.secret[ERR_TRADE_COMPLETE] = nil
STUB.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
closeTrade("done")
assert(NS.HandedOver(s, a3) and said("Übergeben: ") and said(" an Chorf."), "marked from the bags")
assert(#list() == 0)

---------------------------------------------------------------------------
-- the item goes to someone else: a hint, no mark
---------------------------------------------------------------------------
local a4 = NS.AddAwardTo(s, { name = "Fraktur", item = 32837, kind = "MS", src = "Illidan Stormrage" })
bags()
assert(#list() == 1 and list()[1].a == a4, "one of the two Warglaives is Fraktur's (the other is mine)")
openTrade("Chorf")
assert(not helperShown())
-- Fraktur's copy dragged in by hand
assert(list()[1].copy.bag == 0 and list()[1].copy.slot == 3)
STUB.cursor = { bag = 0, slot = 3 }
ClickTradeButton(1)
STUB.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
STUB.messages = {}
closeTrade("done")
assert(said("ging an Chorf, vergeben ist es an Fraktur"), table.concat(STUB.messages, "\n"))
assert(not NS.HandedOver(s, a4), "no mark for the wrong receiver")
-- (another Warglaive in the bags would now count as Fraktur's: Amisia cannot tell the copies apart)
assert(#list() == 1 and list()[1].a == a4 and list()[1].copy.bag == 1, "the next free copy")
STUB.bags[1][1], STUB.bags[1][2] = false, false
bags()
assert(#list() == 0)

---------------------------------------------------------------------------
-- a copy that runs out leaves the list; without a GUID the place counts; unknown time
---------------------------------------------------------------------------
local a5 = NS.AddAwardTo(s, { name = "Fraktur", item = 30000, kind = "OS", src = "Illidan Stormrage" })
STUB.bags[2] = { link2 }
STUB.bagInfo[2] = { [1] = { trade = "3 Min." } }
STUB.messages = {}
bags()
l = list()
assert(#l == 1 and l[1].a == a5 and l[1].copy.guid == nil, "followed without a GUID")
assert(count("Noch 3 Minuten: ") == 1)
-- the line goes (the copy is bound now)
STUB.bagInfo[2][1].trade = nil
bags()
assert(#list() == 0 and said("Nicht mehr handelbar: "), "ran out")
STUB.messages = {}
bags()
assert(not said("Nicht mehr handelbar"), "told once")
-- run out by the clock: 0 minutes left
local a6 = NS.AddAwardTo(s, { name = "Chorf", item = 30000, kind = "OS", src = "Illidan Stormrage" })
STUB.bags[3] = { link2 }
STUB.bagInfo[3] = { [1] = { guid = "Item-1-ZZZ", trade = "1 Min." } }
bags()
assert(#list() == 1 and list()[1].a == a6)
-- a tooltip that cannot be read once (no data) is no "run out": the entry stays and comes back
local realTip = C_TooltipInfo.GetBagItem
C_TooltipInfo.GetBagItem = function() return nil end
STUB.messages = {}
bags()
assert(not said("Nicht mehr handelbar"), "one bad read does not run the copy out")
C_TooltipInfo.GetBagItem = realTip
bags()
assert(#list() == 1 and list()[1].a == a6, "listed again once the tooltip reads")
STUB.messages = {}
STUB.bagInfo[3][1].trade = "0 Min."
bags()
assert(#list() == 0 and said("Nicht mehr handelbar: ") and not NS.HandedOver(s, a6))

-- a copy without the line that is not bound (no trade time known): listed, no warnings
local a7 = NS.AddAwardTo(s, { name = "Anna Bergmann", item = 30000, kind = "OS", src = "Illidan Stormrage" })
STUB.bags[4] = { link2 }
STUB.bagInfo[4] = { [1] = { guid = "Item-1-BOE", bound = false } }
STUB.messages = {}
bags()
l = list()
assert(#l == 1 and l[1].a == a7 and NS.HandoverLeftText(l[1]) == "Handelszeit unbekannt", "time unknown")
assert(#STUB.messages == 0, "no warnings without the time")

---------------------------------------------------------------------------
-- secret values do not error
---------------------------------------------------------------------------
STUB.bagInfo[4][1].trade = "5 Min."
STUB.secret["5 Min."] = true
bags()
assert(#list() == 1 and NS.HandoverLeftText(list()[1]) == "Handelszeit unbekannt" and #STUB.messages == 0, "a secret line: unknown")
STUB.secret["5 Min."] = nil
STUB.secret["Item-1-BOE"] = true
bags()
assert(#list() == 1 and list()[1].copy.guid == nil, "a secret GUID: followed by its place")
STUB.secret["Item-1-BOE"] = nil
STUB.secret["Anna Bergmann"] = true
openTrade("Anna Bergmann")
assert(not helperShown(), "a secret partner: no helper")
STUB.fire("UI_INFO_MESSAGE", 60, "Anna Bergmann")
closeTrade("cancel")
STUB.secret["Anna Bergmann"] = nil

---------------------------------------------------------------------------
-- off: nothing; the saved marks are cleaned on load
---------------------------------------------------------------------------
NS.Set("trade.enabled", false)
bags()
assert(#list() == 0)
NS.Dispatch("uebergabe")
assert(said("Der Handel-Helfer ist aus"))
NS.Set("trade.enabled", true)
local root = { handover = {
    ["2026-10-08:409/0123456789ab"] = { t = STUB.now - 3600, to = "Anna", g = "Item-1-AAA" },
    ["2026-10-01:409/0123456789ab"] = { t = STUB.now - 4 * 86400, to = "Anna" },
    ["kaputt"] = { t = STUB.now },
    ["2026-10-08:409/ffffffffffff"] = "x",
} }
NS.HandoverLoaded(root)
local n = 0
for _ in pairs(root.handover) do n = n + 1 end
assert(n == 1 and root.handover["2026-10-08:409/0123456789ab"].to == "Anna", "old and malformed marks dropped")
NS.HandoverLoaded(root)
assert(root.handover["2026-10-08:409/0123456789ab"], "twice without change")

---------------------------------------------------------------------------
-- review 2026-10-09: the click with two items, a pick-up that fails, a stack, another copy
---------------------------------------------------------------------------
local function emptyBags()
    for b = 0, 4 do STUB.bags[b] = {}; STUB.bagInfo[b] = {} end
    bags()
end
emptyBags()
assert(#list() == 0)
local i1 = STUB.item(40001, "Gürtel der Probe", 4)
local i2 = STUB.item(40002, "Helm der Probe", 4)
local i3 = STUB.item(40003, "Ring der Probe", 4)
local i4 = STUB.item(40004, "Splitter der Probe", 4)
local b1 = NS.AddAwardTo(s, { name = "Anna Bergmann", item = 40001, kind = "MS", src = "Illidan Stormrage" })
local b2 = NS.AddAwardTo(s, { name = "Anna Bergmann", item = 40002, kind = "MS", src = "Illidan Stormrage" })
STUB.bags[0] = { i1, i2 }
STUB.bagInfo[0] = { [1] = { guid = "Item-9-G1", trade = "1 Std. 30 Min." }, [2] = { guid = "Item-9-H1", trade = "1 Std. 40 Min." } }
bags()
assert(#list() == 2)

-- the trade slots answer only after the server (TRADE_PLAYER_ITEM_CHANGED): the second item must not
-- go into the slot the first just took
openTrade("Anna Bergmann")
assert(helper().button:GetText() == "Amisia: 2 Items einlegen", helper().button:GetText())
local realLink = _G.GetTradePlayerItemLink
_G.GetTradePlayerItemLink = function() return nil end
STUB.clicks, STUB.messages = {}, {}
helper().button:Click()
_G.GetTradePlayerItemLink = realLink
assert(STUB.tradeSlots[1] and STUB.tradeSlots[2] and STUB.cursor == nil, "both items in their own slots: " .. table.concat(STUB.clicks, ","))
assert(STUB.clicks[1] == 1 and STUB.clicks[2] == 2, table.concat(STUB.clicks, ","))
assert(said("2 Items eingelegt."))
STUB.fire("TRADE_PLAYER_ITEM_CHANGED", 2)
closeTrade("cancel")
assert(#list() == 2)

-- a pick-up the client refuses (the slot is locked): not counted as put in
openTrade("Anna Bergmann")
local realPickup = C_Container.PickupContainerItem
C_Container.PickupContainerItem = function() end
STUB.messages = {}
helper().button:Click()
C_Container.PickupContainerItem = realPickup
assert(STUB.tradeSlots[1] == nil and not said("eingelegt."), table.concat(STUB.messages, "\n"))
assert(helper().button:GetText() == "Amisia: 2 Items einlegen", "still to put in: " .. helper().button:GetText())
closeTrade("cancel")

-- a copy in a stack: only one of the stack goes into the trade; the trade that took it marks it
emptyBags()
NS.DeleteAward(s, b1.id); NS.DeleteAward(s, b2.id)
local b4 = NS.AddAwardTo(s, { name = "Chorf", item = 40004, kind = "OS", src = "Illidan Stormrage" })
STUB.bags[0] = { i4 }
STUB.bagInfo[0] = { [1] = { guid = "Item-9-ST", bound = false, count = 3 } }
bags()
assert(#list() == 1 and list()[1].a == b4)
openTrade("Chorf")
helper().button:Click()
assert(STUB.tradeSlots[1] and STUB.tradeSlots[1].count == 1, "one of the stack of 3, not all")
STUB.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
STUB.messages = {}
STUB.bagInfo[0][1].count = 2
STUB.tradeSlots = {}
STUB.fire("TRADE_CLOSED")
STUB.fire("BAG_UPDATE_DELAYED")
STUB.tick(2)
assert(NS.HandedOver(s, b4) and said(" an Chorf."), "the stack shrank by the traded one: " .. table.concat(STUB.messages, "\n"))
emptyBags()

-- two copies of one item for Anna and Fraktur; the copy Amisia meant for Fraktur goes to Anna by
-- hand: Anna has hers, Fraktur keeps the other copy
local c1 = NS.AddAwardTo(s, { name = "Anna Bergmann", item = 40003, kind = "MS", src = "Illidan Stormrage" })
STUB.tick(5)
local c2 = NS.AddAwardTo(s, { name = "Fraktur", item = 40003, kind = "MS", src = "Illidan Stormrage" })
STUB.bags[0] = { i3, i3 }
STUB.bagInfo[0] = { [1] = { guid = "Item-9-R1", trade = "1 Std. 10 Min." }, [2] = { guid = "Item-9-R2", trade = "1 Std. 20 Min." } }
bags()
l = list()
assert(#l == 2 and l[1].a == c1 and l[1].copy.guid == "Item-9-R1" and l[2].copy.guid == "Item-9-R2")
openTrade("Anna Bergmann")
STUB.cursor = { bag = 0, slot = 2 }
ClickTradeButton(1)
STUB.fire("TRADE_PLAYER_ITEM_CHANGED", 1)
STUB.messages = {}
closeTrade("done")
assert(NS.HandedOver(s, c1) and not NS.HandedOver(s, c2), "Anna's award is done: " .. table.concat(STUB.messages, "\n"))
assert(said("Übergeben: ") and not said("vergeben ist es an"), table.concat(STUB.messages, "\n"))
l = list()
assert(#l == 1 and l[1].a == c2 and l[1].copy.guid == "Item-9-R1", "Fraktur keeps the copy still here")
