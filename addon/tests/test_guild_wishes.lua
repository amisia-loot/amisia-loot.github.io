-- Guild wishes from the website (GuildWishes.lua): the parser (head, wrong game, empty, unknown
-- lines, names with "_", pasted escape codes, limits), storing, ns.WishersOf with the group through
-- ns.SameNameIn (a first name alone only when it is clear), the tooltip line for officers with
-- "(+n außerhalb)" through the shared hook, the "W" mark in the loot window and on the roll frames
-- next to "SR", wishers first in the award dialog without changing the roll order, the switches,
-- the age, the import window and /amisia wuensche.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
STUB.class, STUB.level = "WARRIOR", 70
assert(NS.Set("bis.tooltip", false))   -- the own upgrade line stays out of these tooltips

local link = STUB.item(28830, "Drachenwirbeltrophäe", 4)
local link2 = STUB.item(31000, "Zweites Item", 4)
local plain = STUB.item(31001, "Ohne Wunsch", 4)

---------------------------------------------------------------------------
-- the parser
---------------------------------------------------------------------------
local TEXT = table.concat({
    "",
    "#AMISIA-WL 1 tbc 2026-10-05",
    "W 28830 3 Anna nur MS",
    "W 28830 2 Bob",
    "W 28830 1 Vulo_Sturmwind",
    "W 28830 1 Anna doppelt",
    "W 31000 2 Vulo",
    "W 31001 2 Cara |cffff0000rot|r und |Hitem:1|h[x]|h",
    "kaputt",
    "W abc 2 Xaver",
    "W 99999999999 2 Xaver",
    "W 31001 2 " .. ("A"):rep(60),
    "W 31001 2 Ba|d",
    "#END",
    "W 1 2 Danach",
}, "\r\n")
local res, why = NS.ParseGuildWishes(TEXT)
assert(res, tostring(why))
assert(res.game == "tbc" and res.date == "2026-10-05", "head read")
assert(res.n == 6 and res.skipped == 4, ("six wishes, four lines skipped: %s %s"):format(tostring(res.n), tostring(res.skipped)))
local l = res.list[28830]
assert(l and #l == 3, "three wishers, the double counts once")
assert(l[1].name == "Anna" and l[1].prio == 3 and l[1].note == "nur MS", "the higher priority of a double stays")
assert(l[3].name == "Vulo Sturmwind", "an underscore is a space: " .. tostring(l[3].name))
local cara = res.list[31001]
assert(cara and #cara == 2, "Cara and Bad")
for _, e in ipairs(cara) do
    assert(not has(e.name, "|") and not has(e.note or "", "|"), "no escape codes from a paste: " .. e.name .. " / " .. tostring(e.note))
    assert(#(e.note or "") <= 40, "a note holds 40 bytes")
end
assert(res.list[1] == nil, "nothing after #END")

local function reason(text)
    local r, w = NS.ParseGuildWishes(text)
    assert(r == nil, "refused")
    return w
end
assert(reason("hallo\nW 1 2 Anna") == "Das ist keine Wunschliste der Amisia-Seite.")
assert(reason("#AMISIA 2 Vuloo\nWL 1 2 3 Vuloo\n#END") == "Das ist keine Wunschliste der Amisia-Seite.", "the own export is no guild list")
assert(reason("#AMISIA-WL 1 forever 2026-10-05\nW 1 2 Anna\n#END") == "Diese Wunschliste ist für WoW Forever, du bist in TBC Anniversary.")
assert(reason("#AMISIA-WL 1 tbc 2026-10-05\nkaputt\n#END") == "Die Liste ist leer.")
assert(reason("") == "Das ist keine Wunschliste der Amisia-Seite.")
assert(reason(nil) == "Das ist keine Wunschliste der Amisia-Seite.")
-- at most 2000 lines are read
local many = { "#AMISIA-WL 1 tbc 2026-10-05" }
for i = 1, 2100 do many[#many + 1] = ("W %d 2 Anna"):format(40000 + i) end
many[#many + 1] = "#END"
local big = NS.ParseGuildWishes(table.concat(many, "\n"))
assert(big and big.n == 1999 and big.skipped >= 101, ("2000 lines: %s %s"):format(tostring(big and big.n), tostring(big and big.skipped)))
-- one endless line is cut, not read
local long = NS.ParseGuildWishes("#AMISIA-WL 1 tbc 2026-10-05\nW 28830 2 Anna " .. ("x"):rep(100000) .. "\n#END")
assert(long and long.n == 1 and #long.list[28830][1].note <= 40, "an endless note is cut")

---------------------------------------------------------------------------
-- storing
---------------------------------------------------------------------------
local stored, w2 = NS.SetGuildWishes(TEXT)
assert(stored and stored.n == 6, tostring(w2))
local g = AmisiaDB.bis.guild
assert(g and g.game == "tbc" and g.date == "2026-10-05" and g.at == STUB.now and g.by == "Vuloo" and g.n == 6, "stored with who and when")
assert(g.list[28830] and #g.list[28830] == 3)
assert(not NS.SetGuildWishes("hallo") and AmisiaDB.bis.guild == g, "a bad paste keeps the old list")
NS.BisMigrate(AmisiaDB)
assert(AmisiaDB.bis.guild.list[28830] and #AmisiaDB.bis.guild.list[28830] == 3, "the move keeps the list")
local info = NS.GuildWishesInfo()
assert(info and info.n == 6 and info.date == "2026-10-05" and info.game == "tbc", "info")

---------------------------------------------------------------------------
-- wishers, with the group
---------------------------------------------------------------------------
local function names(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.name .. (e.inGroup and "+" or "") end
    return table.concat(out, ",")
end
assert(names(NS.WishersOf(28830)) == "Anna,Bob,Vulo Sturmwind", "alone: by priority: " .. names(NS.WishersOf(28830)))
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Anna", class = "PRIEST" }, { name = "Vulo Sturmwind", class = "SHAMAN" },
    { name = "Vulo Eisherz", class = "SHAMAN" }, { name = "Chorf", class = "WARRIOR" } }
assert(names(NS.WishersOf(28830)) == "Anna+,Bob,Vulo Sturmwind+", "in the group marked: " .. names(NS.WishersOf(28830)))
assert(names(NS.WishersOf(28830, true)) == "Anna+,Vulo Sturmwind+", "only the group")
assert(#NS.WishersOf(31000, true) == 0, "a first name alone is no one when two carry it")
STUB.roster[4] = nil
assert(names(NS.WishersOf(31000, true)) == "Vulo+", "and someone when it is clear")
STUB.roster[4] = { name = "Vulo Eisherz", class = "SHAMAN" }
assert(#NS.WishersOf(31001) == 2 and #NS.WishersOf(12345) == 0 and #NS.WishersOf(nil) == 0)

---------------------------------------------------------------------------
-- the tooltip line (officers), through the shared hook
---------------------------------------------------------------------------
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
local shown = link
GameTooltip.GetItem = function() return "x", shown end
local function hover(l, again)
    shown = l
    if not again then
        wipe(lines)
        if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
    end
    GameTooltip.scripts.OnTooltipSetItem(GameTooltip)
end
hover(link)
assert(#lines == 1 and lines[1] == "Gewünscht: Anna (hoch), Vulo Sturmwind (niedrig) (+1 außerhalb)", tostring(lines[1]))
hover(link, true)
assert(#lines == 1, "one line per tooltip build")
hover(plain)
assert(#lines == 1 and lines[1] == "Gewünscht: niemand aus der Gruppe (+2 außerhalb)", "only who is around: " .. tostring(lines[1]))
STUB.roster = {}
hover(link)
assert(lines[1] == "Gewünscht: Anna (hoch), Bob, Vulo Sturmwind (niedrig)", "alone everyone: " .. tostring(lines[1]))
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Chorf", class = "WARRIOR" } }
hover(link)
assert(lines[1] == "Gewünscht: niemand aus der Gruppe (+3 außerhalb)", tostring(lines[1]))
-- with a soft reserve both lines
NS.SetSoftRes("Chorf 28830")
hover(link)
assert(#lines == 2 and has(lines[1], "Reserviert: Chorf") and has(lines[2], "Gewünscht:"), table.concat(lines, " / "))
hover(link2)
assert(#lines == 1 and lines[1] == "Gewünscht: niemand aus der Gruppe (+1 außerhalb)", "a first name of nobody in the group: " .. table.concat(lines, " / "))
assert(NS.Set("bis.guildTooltip", false))
hover(link)
assert(#lines == 1 and has(lines[1], "Reserviert"), "switched off")
NS.Reset("bis.guildTooltip")
assert(NS.Set("ui.view", "raider"))
hover(link)
assert(#lines == 1, "raiders do not see it")
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- the W mark: loot window and roll frames, next to SR
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Anna", class = "PRIEST" }, { name = "Chorf", class = "WARRIOR" } }
STUB.loot = { { link = link, name = "Trophäe" }, { link = plain, name = "Ohne" } }
local b1 = CreateFrame("Button", "LootButton1"); b1.slot = 1; b1:Show()
local b2 = CreateFrame("Button", "LootButton2"); b2.slot = 2; b2:Show()
STUB.fire("LOOT_OPENED"); STUB.tick(0)
assert(NS.GuildWishMarkShown(b1) and not NS.GuildWishMarkShown(b2), "W only where someone in the group wishes")
assert(NS.SoftResMarkShown(b1), "SR stays")
local m = NS.GuildWishMark(b1)
assert(m and m:GetText() == "W" and m.points.TOPRIGHT, "W at the top right, SR keeps the top left")
assert(NS.Set("bis.guildLootMark", false))
NS.MarkGuildWishLoot()
assert(not NS.GuildWishMarkShown(b1), "switched off")
NS.Reset("bis.guildLootMark")
NS.MarkGuildWishLoot()
assert(NS.GuildWishMarkShown(b1))
assert(NS.Set("ui.view", "raider"))
NS.MarkGuildWishLoot()
assert(not NS.GuildWishMarkShown(b1), "raiders see no W")
NS.Reset("ui.view")

local frame = GroupLootFrame1
STUB.rolls[41], STUB.rolls[42] = link, plain
frame.rollID = 41; frame:Show()
assert(NS.GuildWishRollMarkText(frame) == "W" and NS.RollMarkText(frame) == "SR", "W next to SR on the roll frame")
frame:Hide(); frame.rollID = 42; frame:Show()
assert(NS.GuildWishRollMarkText(frame) == nil, "the mark goes with the reused frame")
assert(NS.Set("bis.guildLootMark", false))
frame:Hide(); frame.rollID = 41; frame:Show()
assert(NS.GuildWishRollMarkText(frame) == nil, "switched off")
NS.Reset("bis.guildLootMark")
local getLink = _G.GetLootRollItemLink
_G.GetLootRollItemLink = nil
frame:Hide(); frame:Show()
assert(NS.GuildWishRollMarkText(frame) == nil, "no link, no mark, no error")
_G.GetLootRollItemLink = getLink

---------------------------------------------------------------------------
-- the award dialog: wishers first, the rolls as before
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo", class = "WARRIOR" }, { name = "Chorf", class = "WARRIOR" }, { name = "Bob", class = "MAGE" },
    { name = "Anna", class = "PRIEST" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active(), "a recording")
local D = NS.ShowAwardDialog(link)
local vals, texts = {}, {}
for i, v in ipairs(D.winner.values) do vals[i], texts[i] = v.value, v.text end
assert(table.concat(vals, ",") == "Anna,Bob,Chorf,Vuloo", "wishers first by priority: " .. table.concat(vals, ","))
assert(texts[1] == "Anna (Wunsch hoch)" and texts[2] == "Bob (Wunsch mittel)" and texts[3] == "Chorf", table.concat(texts, ","))
D:Hide()
assert(NS.Set("bis.guildAward", false))
D = NS.ShowAwardDialog(link)
vals = {}
for i, v in ipairs(D.winner.values) do vals[i] = v.text end
assert(table.concat(vals, ",") == "Anna,Bob,Chorf,Vuloo", "switched off: alphabetical, plain names")
D:Hide()
NS.Reset("bis.guildAward")
D = NS.ShowAwardDialog(plain)
vals = {}
for i, v in ipairs(D.winner.values) do vals[i] = v.text end
assert(table.concat(vals, ",") == "Anna,Bob,Chorf,Vuloo", "nobody in the group wishes it: as before")
D:Hide()
-- the roll order is not touched by wishes
assert(NS.StartRoll(link, 10))
local round = NS.CurrentRoll()
STUB.fire("CHAT_MSG_SYSTEM", RANDOM_ROLL_RESULT:format("Bob", 90, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", RANDOM_ROLL_RESULT:format("Anna", 40, 1, 100))
STUB.tick(10)
assert(round.winner == "Bob", "wishes change no roll: " .. tostring(round.winner))
NS.ClearSoftRes()

---------------------------------------------------------------------------
-- age, clearing, the import window and the command
---------------------------------------------------------------------------
assert(NS.GuildWishesAgeText() == nil and NS.GuildWishesInfo().age <= 14, "young lists need no hint")
local old = os.date("%Y-%m-%d", STUB.now - 16 * 86400 - 12 * 3600)   -- the age counts from noon of the date
assert(NS.SetGuildWishes("#AMISIA-WL 1 tbc " .. old .. "\nW 28830 3 Anna\n#END"))
assert(NS.GuildWishesInfo().age == 16 and NS.GuildWishesAgeText() == "Die Wunschliste ist 16 Tage alt.", tostring(NS.GuildWishesAgeText()))

assert(NS.Set("ui.view", "raider"))
NS.Dispatch("wuensche")
assert(has(lastMsg(), "Offiziersansicht"), "officers only: " .. lastMsg())
assert(not (AmisiaGuildWishFrame and AmisiaGuildWishFrame:IsShown()), "no window for raiders")
NS.Reset("ui.view")
NS.Dispatch("wuensche")
local F = AmisiaGuildWishFrame
assert(F and F:IsShown() and F.strata == "FULLSCREEN_DIALOG", "the import window above the main window")
F.editBox:SetText(TEXT)
F.editBox.scripts.OnTextChanged(F.editBox)
STUB.tick(0.5)
assert(F.previewText:GetText() == "Vorschau: 6 Wünsche zu 3 Items, 4 Zeilen nicht erkannt", tostring(F.previewText:GetText()))
F.editBox:SetText("#AMISIA-WL 1 forever 2026-10-05\nW 1 2 Anna\n#END")
F.editBox.scripts.OnTextChanged(F.editBox)
STUB.tick(0.5)
assert(F.previewText:GetText() == "Diese Wunschliste ist für WoW Forever, du bist in TBC Anniversary.", tostring(F.previewText:GetText()))
F.editBox:SetText(TEXT)
F.applyBtn:Click()
assert(AmisiaDB.bis.guild.n == 6 and AmisiaDB.bis.guild.date == "2026-10-05", "imported")
assert(has(F.resultText:GetText(), "6 Wünsche übernommen"), tostring(F.resultText:GetText()))
F.clearBtn:Click()
assert(STUB.popup and STUB.popup.which == "AMISIA_GUILDWISH_CLEAR", "asks first")
STUB.acceptPopup()
assert(AmisiaDB.bis.guild == nil and NS.GuildWishesInfo() == nil, "cleared")
assert(#NS.WishersOf(28830) == 0, "no list, no wishers")
hover(link)
assert(#lines == 0, "no list, no line")
NS.MarkGuildWishLoot()
assert(not NS.GuildWishMarkShown(b1), "no list, no mark")

-- every text Latin-1 only
for _, t in ipairs({ TEXT, F.previewText:GetText() or "", F.resultText:GetText() or "" }) do
    for c in t:gmatch("[\194-\244][\128-\191]*") do
        local b1c, b2c = c:byte(1, 2)
        assert(b1c <= 195, "beyond Latin-1: " .. c)
    end
end
