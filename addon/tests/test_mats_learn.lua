--[[preload
-- a guild bank with one tab: material 61001 x 9 and some other item
STUB.gbank = { { [1] = { 61001, 9 }, [2] = { 999, 1 } } }
GetNumGuildBankTabs = function() return #STUB.gbank end
GetGuildBankTabInfo = function(tab) return "Tab " .. tab, 0, true end
QueryGuildBankTab = function() end
GetCurrentGuildBankTab = function() return 1 end
GetGuildBankItemLink = function(tab, slot)
    local e = STUB.gbank[tab] and STUB.gbank[tab][slot]
    return e and ("|cffffffff|Hitem:%d::::::::60:::::|h[x]|h|r"):format(e[1])
end
GetGuildBankItemInfo = function(tab, slot)
    local e = STUB.gbank[tab] and STUB.gbank[tab][slot]
    return 134, e and e[2] or 0
end
]]
-- Amisia learns its raid materials on its own (Nachtrag "automatische Materialliste"): trade goods
-- (or reagents) of the set quality that drop or are looted or handed out in a raid recording go
-- into AmisiaDB.mats; ns.MATS and ns.MAT_ORDER follow that list in the order first seen.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function allMessages() return table.concat(STUB.messages, "\n") end
-- An item the fake client knows with its item class (7 trade goods, 5 reagent) and subclass.
local function tradeGood(id, name, q, class, sub)
    local link = STUB.item(id, name, q)
    STUB.items[id].classID, STUB.items[id].subclassID = class or 7, sub or 10
    return link
end
local function loot(who, link) STUB.fire("CHAT_MSG_LOOT", ("%s receives loot: %s."):format(who, link)) end
local function open(src, links)
    STUB.loot = {}
    for i, l in ipairs(links) do STUB.loot[i] = { link = l, name = "x", src = src } end
    STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED")
end

---------------------------------------------------------------------------
-- settings and the empty start
---------------------------------------------------------------------------
local learn, quality = NS.SettingItem("mats.learn"), NS.SettingItem("mats.quality")
assert(learn and learn.type == "toggle" and learn.default == true and learn.section.officer, "mats.learn")
assert(quality and quality.type == "choice" and quality.default == 2, "mats.quality: green and better by default")
assert(type(AmisiaDB.mats) == "table" and next(AmisiaDB.mats) == nil, "an empty list on a fresh install")
assert(not NS.HasMats() and #NS.MAT_ORDER == 0 and next(NS.GEMS) == nil, "nothing tracked, no gem group")
assert(NS.MAT_CAP == 40, "forty materials at most")

---------------------------------------------------------------------------
-- outside a raid recording nothing is learned
---------------------------------------------------------------------------
local core = tradeGood(61001, "Feuerkern", 3)
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" } }
STUB.instance = { name = "Orgrimmar", type = "none", id = 1 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(not NS.Active(), "no recording in a city")
loot("Fraktur", core)
open("Creature-0-1-1-1-3000-1", { core })
assert(next(AmisiaDB.mats) == nil, "no recording, nothing learned")

---------------------------------------------------------------------------
-- in a raid: a looted trade good is learned and recorded as material loot
---------------------------------------------------------------------------
STUB.instance = { name = "Geschmolzener Kern", type = "raid", id = 409 }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
local s = assert(NS.Active(), "recording in the raid")
STUB.now = STUB.now + 10
loot("Fraktur", core)
local e = AmisiaDB.mats[61001]
assert(e and e.name == "Feuerkern" and e.q == 3 and e.first == STUB.now, "learned with name, quality and time")
assert(NS.MATS[61001] == "Feuerkern" and NS.MAT_ORDER[1] == 61001 and NS.HasMats(), "tracked")
assert(#s.loot == 1 and s.loot[1].item == 61001 and s.loot[1].name == "Fraktur", "recorded as material loot")
assert(#s.items == 0, "not recorded as a blue item as well")

-- what does not count: armor, too low a quality, a disenchanting result, an ignored id
local helm = STUB.item(61002, "Grüner Helm", 2)
local cloth = tradeGood(61003, "Runenstoff", 1)
local dust = tradeGood(61004, "Traumstaub", 2, 7, 12)
local nexus = tradeGood(20725, "Nexuskristall", 3)
for _, l in ipairs({ helm, cloth, dust, nexus }) do loot("Fraktur", l) end
assert(not AmisiaDB.mats[61002], "armor is no material")
assert(not AmisiaDB.mats[61003], "below the quality setting")
assert(not AmisiaDB.mats[61004], "enchanting goods come from disenchanting")
assert(not AmisiaDB.mats[20725], "an ignored id stays out")
assert(#NS.MAT_ORDER == 1)

-- a reagent counts too; the order is first seen
STUB.now = STUB.now + 10
local lava = tradeGood(61005, "Lavakern", 3, 5, 0)
loot("Vuloo", lava)
assert(AmisiaDB.mats[61005] and NS.MAT_ORDER[2] == 61005, "a reagent is learned, second")

-- a loot window: a drop teaches the material, and a material is no drop line
STUB.now = STUB.now + 10
local ore = tradeGood(61006, "Elementiumerz", 2)
open("Creature-0-1-1-1-11583-1", { ore })
assert(AmisiaDB.mats[61006] and NS.MAT_ORDER[3] == 61006, "seen dropping")
assert(NS.DropCount(s) == 0, "a material is no drop")
-- a container opened from the bags is no drop
open("Item-0-1-1-1", { tradeGood(61007, "Truhenstoff", 2) })
assert(not AmisiaDB.mats[61007], "a bag container teaches nothing")

-- secret values of a boss fight are skipped, never read
local secretLine = ("%s receives loot: %s."):format("Fraktur", tradeGood(61008, "Geheimstoff", 3))
STUB.secret[secretLine] = true
STUB.fire("CHAT_MSG_LOOT", secretLine)
assert(not AmisiaDB.mats[61008], "a secret loot line is skipped")
local secretLink = tradeGood(61009, "Geheimerz", 3)
STUB.secret[secretLink] = true
open("Creature-0-1-1-1-11583-2", { secretLink })
assert(not AmisiaDB.mats[61009], "a secret loot slot is skipped")

-- a hand-out in the recording teaches the material as well
STUB.now = STUB.now + 10
tradeGood(61010, "Rechtschaffene Kugel", 2)
assert(NS.AddAward("Fraktur", 61010, "-", "Golemagg"))
assert(AmisiaDB.mats[61010] and NS.MAT_ORDER[4] == 61010, "an award teaches it")

---------------------------------------------------------------------------
-- export: L lines and names for the site
---------------------------------------------------------------------------
local txt = NS.ExportText({ s })
assert(has(txt, "\nL Fraktur 61001 1\n"), txt)
assert(has(txt, "\nN 61001 3 Feuerkern\n"), "the material is named for the site: " .. txt)
assert(has(txt, "\nN 61005 3 Lavakern\n"), txt)

---------------------------------------------------------------------------
-- guild bank: the learned materials are counted; one learned later has no B line until counted
---------------------------------------------------------------------------
STUB.fire("GUILDBANKFRAME_OPENED"); STUB.tick(1)
STUB.fire("GUILDBANKFRAME_CLOSED")
assert(AmisiaDB.bank and AmisiaDB.bank.counts[61001] == 9 and AmisiaDB.bank.counts[61005] == 0, "counted")
assert(has(allMessages(), "Gildenbank gezählt: "), allMessages())
txt = NS.ExportText({})
assert(has(txt, "\nB 61001 9\n") and has(txt, "\nB 61005 0\n"), txt)
assert(has(txt, "\nN 61001 3 Feuerkern\n"), "the bank lines are named too: " .. txt)
STUB.now = STUB.now + 10
loot("Fraktur", tradeGood(61011, "Spätstoff", 2))
assert(NS.MATS[61011], "learned after the count")
txt = NS.ExportText({})
assert(not has(txt, "\nB 61011 "), "not counted yet, so no B line: " .. txt)

---------------------------------------------------------------------------
-- /amisia mats: list, take out, put back, add by hand; only officers change the list
---------------------------------------------------------------------------
STUB.officer = true
STUB.messages = {}
SlashCmdList.AMISIA("mats")
assert(has(allMessages(), "Feuerkern") and has(allMessages(), "Lavakern"), allMessages())
SlashCmdList.AMISIA("mats weg " .. lava)
assert(not NS.MATS[61005] and AmisiaDB.mats[61005] and AmisiaDB.mats[61005].hide, "taken out and remembered")
assert(NS.MAT_ORDER[2] ~= 61005, "out of the order")
loot("Fraktur", lava)
assert(not NS.MATS[61005], "a removed material is not learned again")
SlashCmdList.AMISIA("mats add " .. lava)
assert(NS.MATS[61005] and not AmisiaDB.mats[61005].hide and NS.MAT_ORDER[2] == 61005, "back at its place")
-- by hand: any item, also one that is no trade good
STUB.now = STUB.now + 10
SlashCmdList.AMISIA("mats add " .. helm)
assert(NS.MATS[61002] and AmisiaDB.mats[61002].manual, "added by hand")
assert(NS.MAT_ORDER[#NS.MAT_ORDER] == 61002, "at the end")
SlashCmdList.AMISIA("mats weg 61002")
assert(not NS.MATS[61002], "an item id works too")
-- raiders change nothing
STUB.officer = false
SlashCmdList.AMISIA("mats weg " .. core)
assert(NS.MATS[61001], "a raider cannot take a material out")
assert(has(STUB.messages[#STUB.messages], "Offizier"), STUB.messages[#STUB.messages])
STUB.officer = true

---------------------------------------------------------------------------
-- the quality setting and the switch
---------------------------------------------------------------------------
assert(NS.Set("mats.quality", 3))
loot("Fraktur", tradeGood(61012, "Grünstoff", 2))
assert(not AmisiaDB.mats[61012], "green is below blue")
assert(NS.Set("mats.quality", 2))
assert(NS.Set("mats.learn", false))
loot("Fraktur", tradeGood(61013, "Ausstoff", 3))
assert(not AmisiaDB.mats[61013], "learning switched off")
assert(NS.Set("mats.learn", true))

---------------------------------------------------------------------------
-- the summary lines stay short with many materials: only counted ones, at most a few
---------------------------------------------------------------------------
assert(#NS.MAT_ORDER > 3)
assert(NS.MatSummary({ [61001] = 4 }) == "Feuerkern 4", NS.MatSummary({ [61001] = 4 }))
assert(NS.MatLine({ [61001] = 4 }) == "Feuerkern 4", NS.MatLine({ [61001] = 4 }))
assert(NS.MatLine({}) == "", "nothing counted, nothing shown")
local many = { [61001] = 1, [61005] = 2, [61006] = 3, [61010] = 4, [61011] = 5 }
assert(NS.MatLine(many) == "Feuerkern 1, Lavakern 2, Elementiumerz 3, und 2 weitere", NS.MatLine(many))

---------------------------------------------------------------------------
-- the guild bank page: the list without a count, take out per row, add by link
---------------------------------------------------------------------------
local panel = assert(NS.Panel("bank"), "bank panel")
local frame = panel.create(CreateFrame("Frame", nil, UIParent))
panel.refresh(frame)
assert(#frame.list.items == #NS.MAT_ORDER, "one row per material")
local late
for _, r in ipairs(frame.list.rows) do if r.item and r.item.id == 61011 then late = r end end
assert(late and late.count.text == "-", "a material not counted yet shows a dash")
local saved = AmisiaDB.bank
AmisiaDB.bank = nil
panel.refresh(frame)
assert(#frame.list.items == #NS.MAT_ORDER, "the list shows before the first count")
assert(has(frame.state.text, "Noch nicht gezählt"), tostring(frame.state.text))
AmisiaDB.bank = saved
panel.refresh(frame)
local row = frame.list.rows[1]
assert(row.item and row.item.id == 61001 and row.remove, "the first row and its button")
row.remove:Click()
assert(not NS.MATS[61001] and AmisiaDB.mats[61001].hide, "taken out from the page")
frame.add.box:SetFocus()
ChatFrameUtil.InsertLink(core)
assert(frame.add.box:GetText() == core, "a shift-clicked link lands in the box")
frame.add.button:Click()
assert(NS.MATS[61001] and NS.MAT_ORDER[1] == 61001, "added back from the page")
assert(frame.add.box:GetText() == "", "the box is emptied")
frame.add.box:ClearFocus()

---------------------------------------------------------------------------
-- the cap: forty materials, then nothing new, with one note
---------------------------------------------------------------------------
STUB.messages = {}
for i = 1, 45 do
    STUB.now = STUB.now + 1
    loot("Fraktur", tradeGood(62000 + i, "Stoff " .. i, 2))
end
assert(#NS.MAT_ORDER == 40, "full at forty: " .. #NS.MAT_ORDER)
assert(not AmisiaDB.mats[62045], "the forty-first is not learned")
local full = 0
for _, m in ipairs(STUB.messages) do if has(m, "Materialliste ist voll") then full = full + 1 end end
assert(full == 1, "one note that the list is full: " .. allMessages())
SlashCmdList.AMISIA("mats add " .. tradeGood(63000, "Noch einer", 3))
assert(not NS.MATS[63000] and has(STUB.messages[#STUB.messages], "voll"), "a hand add is refused when full")

---------------------------------------------------------------------------
-- a broken saved list is cleaned on load, and loading twice changes nothing
---------------------------------------------------------------------------
local order = {}
for i, id in ipairs(NS.MAT_ORDER) do order[i] = id end
AmisiaDB.mats.x = 1
AmisiaDB.mats[5] = "kaputt"
AmisiaDB.mats[6] = { q = 2 }
NS.MatsLoaded(AmisiaDB)
NS.MatsLoaded(AmisiaDB)
assert(AmisiaDB.mats.x == nil and AmisiaDB.mats[5] == nil and AmisiaDB.mats[6] == nil, "junk removed")
assert(#NS.MAT_ORDER == #order, "same list")
for i, id in ipairs(order) do assert(NS.MAT_ORDER[i] == id, "same order") end
