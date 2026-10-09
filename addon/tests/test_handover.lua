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
