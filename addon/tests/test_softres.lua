-- Soft-reserve parsing, storage, tooltip line and loot marks.
local csv = 'Item,ItemId,From,Name,Class,Spec,Note,Plus,Date\n'
    .. '"Cursed Vision of Sargeras",32235,Illidan,Fraktur,Shaman,Enhancement,,0,2026-09-19\n'
    .. '"Cursed Vision of Sargeras",32235,Illidan,fraktur-Thunderstrike,Shaman,,,0,2026-09-19\n'
    .. '"Blade, sharp",32837,Illidan,Chorf,Warrior,,"note, with comma",0,x\n'
    .. 'Broken,,Illidan,Nobody,Warrior,,,0,x\n'
local byItem, n, bad = NS.ParseSoftRes(csv)
assert(n == 2, "count " .. n)
assert(#bad == 1 and bad[1]:find("Broken", 1, true), "row without item id reported")
assert(#byItem[32235] == 1 and byItem[32235][1] == "Fraktur", "realm stripped, duplicate merged, capitalised")
assert(byItem[32837][1] == "Chorf")

-- header with a space in "Item ID"
byItem, n = NS.ParseSoftRes([[Item;Item ID;Name
X;32235;Vuloo
]])
assert(n == 1 and byItem[32235][1] == "Vuloo", "spaced header")

-- semicolon CSV
byItem, n = NS.ParseSoftRes("ID;Item;ItemId;Name\n1;X;32235;Vuloo\n")
assert(n == 1 and byItem[32235][1] == "Vuloo")

-- plain lines
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
byItem, n, bad = NS.ParseSoftRes("Chorf " .. link .. "\nVuloo: 32837\nFraktur; 32235\nNobody\nAnna-Realm\t32837\n")
assert(n == 4 and #bad == 1 and bad[1] == "Nobody", "plain lines: " .. n .. " " .. #bad)
assert(#byItem[32235] == 2 and byItem[32235][1] == "Chorf" and byItem[32235][2] == "Fraktur", "sorted")
assert(byItem[32837][2] == "Vuloo" and byItem[32837][1] == "Anna")
assert(NS.ParseSoftRes("") and select(2, NS.ParseSoftRes("")) == 0)

-- storage
local count, badLines = NS.SetSoftRes("Chorf " .. link)
assert(count == 1 and #badLines == 0)
assert(NS.ReservedBy(32235)[1] == "Chorf" and #NS.ReservedBy(1) == 0 and #NS.ReservedBy("32235") == 1)
assert(AmisiaDB.softres.date == date("%Y-%m-%d"))
local d, c = NS.SoftResInfo(); assert(d == date("%Y-%m-%d") and c == 1)

-- tooltip line
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
GameTooltip.GetItem = function() return "Cursed Vision of Sargeras", link end
GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
assert(lines[1] and lines[1]:find("Reserviert: Chorf", 1, true), lines[1] or "no line")
GameTooltip.GetItem = function() return "Other", STUB.item(1, "Other", 4) end
GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
assert(#lines == 1, "no line for an unreserved item")

-- loot marks on the classic loot buttons
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras" }, { link = STUB.item(2, "Plain", 4), name = "Plain" } }
local b1 = CreateFrame("Button", "LootButton1"); b1.slot = 1; b1:Show()
local b2 = CreateFrame("Button", "LootButton2"); b2.slot = 2; b2:Show()
STUB.fire("LOOT_OPENED"); STUB.tick(0)
NS.MarkLootButtons()
assert(NS.SoftResMarkShown(b1) == true and NS.SoftResMarkShown(b2) == false, "only the reserved item is marked")
NS.ClearSoftRes()
NS.MarkLootButtons()
assert(NS.SoftResMarkShown(b1) == false and #NS.ReservedBy(32235) == 0)

-- window
NS.ToggleSoftResFrame()
assert(NS.SoftResFrame:IsShown())
NS.SoftResFrame.editBox:SetText("Chorf " .. link .. "\nJunk")
NS.SoftResFrame.applyBtn:Click()
assert(NS.SoftResFrame.resultText:GetText():find("1 Reservierungen", 1, true) and NS.SoftResFrame.resultText:GetText():find("1 Zeilen", 1, true), NS.SoftResFrame.resultText:GetText())
assert(#NS.ReservedBy(32235) == 1)
NS.SoftResFrame.clearBtn:Click()
assert(#NS.ReservedBy(32235) == 0)
