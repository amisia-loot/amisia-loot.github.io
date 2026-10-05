-- Soft-reserve parsing, storage, tooltip line and loot marks.
local csv = 'Item,ItemId,From,Name,Class,Spec,Note,Plus,Date\n'
    .. '"Cursed Vision of Sargeras",32235,Illidan,Fraktur,Shaman,Enhancement,,0,2026-09-19\n'
    .. '"Cursed Vision of Sargeras",32235,Illidan,fraktur,Shaman,,,0,2026-09-19\n'
    .. '"Blade, sharp",32837,Illidan,Chorf,Warrior,,"note, with comma",0,x\n'
    .. 'Broken,,Illidan,Nobody,Warrior,,,0,x\n'
local byItem, n, bad = NS.ParseSoftRes(csv)
assert(n == 2, "count " .. n)
assert(#bad == 1 and bad[1]:find("Broken", 1, true), "row without item id reported")
assert(#byItem[32235] == 1 and byItem[32235][1] == "Fraktur", "duplicate merged, capitalised")
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
byItem, n, bad = NS.ParseSoftRes("Chorf " .. link .. "\nVuloo: 32837\nFraktur; 32235\nNobody\nAnna\t32837\n")
assert(n == 4 and #bad == 1 and bad[1] == "Nobody", "plain lines: " .. n .. " " .. #bad)
assert(#byItem[32235] == 2 and byItem[32235][1] == "Chorf" and byItem[32235][2] == "Fraktur", "sorted")
assert(byItem[32837][2] == "Vuloo" and byItem[32837][1] == "Anna")
assert(NS.ParseSoftRes("") and select(2, NS.ParseSoftRes("")) == 0)
-- two numbers on a line are no name with one item
byItem, n, bad = NS.ParseSoftRes("Amy 32235 32236\nBob: 30000, 30001\nAmy Smith 32235\n")
assert(n == 1 and #bad == 2 and byItem[32235][1] == "Amy Smith", "junk names: " .. n .. " " .. #bad)

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
STUB.showTooltip(GameTooltip)
assert(lines[1] and lines[1]:find("Reserviert: Chorf", 1, true), lines[1] or "no line")
GameTooltip.GetItem = function() return "Other", STUB.item(1, "Other", 4) end
STUB.showTooltip(GameTooltip)
assert(#lines == 1, "no line for an unreserved item")

-- loot marks on the elements of the scrolling loot window, on their item icon
STUB.loot = { { link = link, name = "Cursed Vision of Sargeras" }, { link = STUB.item(2, "Plain", 4), name = "Plain" },
    { link = link, name = "Cursed Vision of Sargeras" } }
local box = LootFrame.ScrollBox
local b1, b2 = box.frames[1], box.frames[2]
box:ShowFrom(1)
STUB.fire("LOOT_OPENED"); STUB.tick(0)
NS.MarkSoftResLoot()
assert(NS.SoftResMarkShown(b1) == true and NS.SoftResMarkShown(b2) == false, "only the reserved item is marked")
assert(NS.SoftResMark(b1).parent == b1.Item, "on the element's item icon")
box:ShowFrom(2)   -- scrolled: the second element shows slot 3, the first slot 2
assert(NS.SoftResMarkShown(b1) == false and NS.SoftResMarkShown(b2) == true, "the marks follow the scrolling")
box:ShowFrom(1)
NS.ClearSoftRes()
NS.MarkSoftResLoot()
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

-- tooltip in a group: only reservers from the group, the count, "du" for oneself, the rest counted
NS.SetSoftRes("Fraktur 32235\nVuloo 32235\nVuloo 32235\nAnna 32235\nBob 32235\n")
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur Berg", class = "SHAMAN" } }
lines = {}
GameTooltip.GetItem = function() return "Cursed Vision of Sargeras", link end
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
STUB.showTooltip(GameTooltip)
assert(lines[1] == "Reserviert: Fraktur, du x2 (+2 außerhalb)", tostring(lines[1]))
-- a second call for the same build adds nothing
STUB.showTooltip(GameTooltip)
assert(#lines == 1, "one line per tooltip build: " .. #lines)
-- a cleared tooltip gets it again
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
STUB.showTooltip(GameTooltip)
assert(#lines == 2)
-- the setting off: everyone
assert(NS.Set("softres.tooltipGroup", false))
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
STUB.showTooltip(GameTooltip)
assert(lines[3] == "Reserviert: Anna, Bob, Fraktur, du x2", tostring(lines[3]))
NS.Reset("softres.tooltipGroup")
-- alone: everyone
STUB.roster = {}
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
STUB.showTooltip(GameTooltip)
assert(lines[4] == "Reserviert: Anna, Bob, Fraktur, du x2", tostring(lines[4]))
-- in a group without any reserver from it
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Chorf", class = "WARRIOR" } }
NS.SetSoftRes("Anna 32235\nBob 32235\n")
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
STUB.showTooltip(GameTooltip)
assert(lines[5] and lines[5]:find("+2 außerhalb", 1, true), tostring(lines[5]))
-- an error in the body goes to the error handler and breaks nothing
GameTooltip.AddLine = function() error("kaputt") end
local errh, caught = geterrorhandler, nil
geterrorhandler = function() return function(e) caught = e end end
GameTooltip.scripts.OnTooltipCleared(GameTooltip)
local ok = pcall(STUB.showTooltip, GameTooltip)
geterrorhandler = errh
assert(ok, "the hook does not raise")
assert(caught and tostring(caught):find("kaputt", 1, true), tostring(caught))
