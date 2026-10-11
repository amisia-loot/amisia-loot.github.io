-- Loot council notes and priority lists (LootPrio.lua): the website's "#AMISIA-LC" block (head,
-- wrong game, broken lines, escape codes, the prio token), storing it with the wishes and alts in
-- one paste, the in-game edit (free text: players with a role, classes with a spec, "offen") and its
-- "LC" export line, the newest entry winning per item, the line and the marks in the roll window,
-- the award dialog, the loot announcement (setting), the tooltip and /amisia prio.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function lastMsg() return STUB.messages[#STUB.messages] or "" end
assert(NS.Set("bis.tooltip", false))
assert(NS.Set("drops.tooltip", false))

-- the site's times below lie in late October 2026: the clock stands after them (a time more than a
-- day ahead is refused)
STUB.now = 1791400000
local link = STUB.item(32235, "Cursed Vision of Sargeras", 4)
local link2 = STUB.item(32837, "Warglaive of Azzinoth", 4)
local plain = STUB.item(30000, "Ohne Prio", 4)

---------------------------------------------------------------------------
-- the prio token
---------------------------------------------------------------------------
local e = NS.ParsePrioToken("p:Anna:Tank,c:WARRIOR:Furor,o,p:Vulo_Sturmwind")
assert(e and #e == 4, "four entries")
assert(e[1].k == "p" and e[1].name == "Anna" and e[1].label == "Tank")
assert(e[2].k == "c" and e[2].class == "WARRIOR" and e[2].label == "Furor")
assert(e[3].k == "o")
assert(e[4].k == "p" and e[4].name == "Vulo Sturmwind" and e[4].label == nil, "an underscore is a space")
assert(NS.PrioTokenOf(e) == "p:Anna:Tank,c:WARRIOR:Furor,o,p:Vulo_Sturmwind", "back to the token")
assert(#NS.ParsePrioToken("-") == 0 and NS.PrioTokenOf({}) == "-", "an empty list")
assert(NS.ParsePrioToken("p:Anna,c:NOCLASS") == nil, "an unknown class refuses the token")
assert(NS.ParsePrioToken("p:X1") == nil, "a digit in a name")
assert(NS.ParsePrioToken("q:Anna") == nil and NS.ParsePrioToken("") == nil and NS.ParsePrioToken(nil) == nil)
assert(NS.ParsePrioToken(("o,"):rep(12) .. "o") == nil, "at most ten entries")
do
    local future = ("#AMISIA-LC 1 forever 2026-10-07\nC 32235 %d p:Anna\nC 32837 1788000000 p:Anna\n#END"):format(math.floor(time()) + 3 * 86400)
    local res = NS.ParseLootPrio(future)
    assert(res and res.list[32235] == nil and res.list[32837] and res.skipped == 1, "a time three days ahead is skipped")
end
assert(NS.ParsePrioToken("p:Anna:" .. ("x"):rep(30)) == nil, "a label of at most 16 bytes")
assert(NS.LootPrioText(e) == "1. Anna (Tank), 2. Krieger Furor, 3. offen, 4. Vulo Sturmwind", NS.LootPrioText(e))

---------------------------------------------------------------------------
-- the website's block
---------------------------------------------------------------------------
local TEXT = table.concat({
    "",
    "#AMISIA-LC 1 forever 2026-10-07",
    "C 32235 1791300000 p:Anna:Tank,c:WARRIOR:Furor,o Erst Tanks, dann DPS",
    "C 32837 1791300100 p:Vulo_Sturmwind",
    "C 30001 1791300200 - nur eine Notiz",
    "C 30002 1791300300 p:Anna |cffff0000rot|r",
    "C 30003 1791300300 -",            -- neither prio nor note: a cleared item
    "C abc 1 p:Anna",
    "C 30004 x p:Anna",
    "C 30005 1 c:NOCLASS",
    "kaputt",
    "#END",
    "C 30006 1 p:Danach",
}, "\r\n")
local res, why = NS.ParseLootPrio(TEXT)
assert(res, tostring(why))
assert(res.game == "forever" and res.date == "2026-10-07")
assert(res.n == 5 and res.skipped == 4, ("five items, four skipped: %s %s"):format(tostring(res.n), tostring(res.skipped)))
assert(res.list[32235].note == "Erst Tanks, dann DPS" and #res.list[32235].prio == 3 and res.list[32235].at == 1791300000)
assert(res.list[30001].note == "nur eine Notiz" and #res.list[30001].prio == 0)
assert(res.list[30002].note == "rot", "no escape codes: " .. tostring(res.list[30002].note))
assert(res.list[30003] and #res.list[30003].prio == 0 and res.list[30003].note == "", "a cleared item is kept as such")

local function reason(text)
    local r, w = NS.ParseLootPrio(text)
    assert(r == nil, "refused")
    return w
end
assert(reason("hallo") == "Das ist keine Prioliste der Amisia-Seite.")
assert(reason("#AMISIA-LC 1 tbc 2026-10-07\nC 1 1 o\n#END") == "Diese Prioliste ist für TBC Anniversary, du bist in WoW Forever.")
assert(reason("#AMISIA-LC 2 forever 2026-10-07\nC 1 1 o\n#END") == "Das ist keine Prioliste der Amisia-Seite.")
assert(reason("#AMISIA-LC 1 forever 2026-10-07\n#END") == "Die Prioliste ist leer.")

---------------------------------------------------------------------------
-- one paste: wishes, alts and the prio list
---------------------------------------------------------------------------
local fired = 0
NS.Listen("LOOT_PRIO", function() fired = fired + 1 end)
local WL = "#AMISIA-WL 1 forever 2026-10-07\nW 32235 3 Anna\n#END"
local ALTS = "#AMISIA-ALTS 1 forever 2026-10-07\nA Bob Anna\n#END"
local b = NS.SiteBlocks(WL .. "\n" .. ALTS .. "\n" .. TEXT)
assert(b.wl and b.alts and b.lc and has(b.lc, "C 32837"), "three blocks cut out")
local text, ok = NS.ImportSiteText(WL .. "\n" .. ALTS .. "\n" .. TEXT)
assert(ok and has(text, "1 Wunsch") and has(text, "1 Twink") and has(text, "5 Items mit Prio"), text)
assert(fired == 1 and AmisiaDB.prio.site.n == 5)
-- the prio list alone
text, ok = NS.ImportSiteText(TEXT)
assert(ok and text == "5 Items mit Prio übernommen, 4 Zeilen nicht erkannt.", text)
local info = NS.LootPrioInfo()
assert(info.date == "2026-10-07" and info.n == 5 and info.edits == 0)

---------------------------------------------------------------------------
-- lookups: the newest entry per item wins
---------------------------------------------------------------------------
local p = NS.LootPrioOf(link)
assert(p and p.src == "site" and #p.prio == 3 and p.note == "Erst Tanks, dann DPS")
assert(NS.LootPrioOf(32837).prio[1].name == "Vulo Sturmwind")
assert(NS.LootPrioOf(plain) == nil and NS.LootPrioOf(30003) == nil, "nothing, and a cleared item is nothing")
assert(NS.LootPrioOf(30001).note == "nur eine Notiz", "a note alone counts")
-- the rank of a roller: a player by name, a class by class
assert(NS.LootPrioRank(32235, "Anna", "PRIEST") == 1)
local rank, how = NS.LootPrioRank(32235, "Chorf", "WARRIOR")
assert(rank == 2 and how == "class", "a warrior is second by class")
assert(NS.LootPrioRank(32235, "Bob", "MAGE") == nil, "open counts for nobody by name")
assert(NS.LootPrioRank(32837, "Vulo", "MAGE") == 1, "a first name alone while it is clear")

---------------------------------------------------------------------------
-- editing in game: free text, stored locally, exported as LC lines
---------------------------------------------------------------------------
local pf = NS.ParsePrioFree("Anna (Tank), Krieger Furor, offen")
assert(pf and NS.PrioTokenOf(pf) == "p:Anna:Tank,c:WARRIOR:Furor,o", NS.PrioTokenOf(pf or {}))
pf = NS.ParsePrioFree("Vulo Sturmwind (Heal);  warrior, Magier Feuer, open")
assert(pf and NS.PrioTokenOf(pf) == "p:Vulo_Sturmwind:Heal,c:WARRIOR,c:MAGE:Feuer,o", NS.PrioTokenOf(pf or {}))
local bad, badWhy = NS.ParsePrioFree("Anna, X1")
assert(bad == nil and badWhy == "Nicht erkannt: X1", tostring(badWhy))
assert(#NS.ParsePrioFree("") == 0, "an empty order is allowed (a note alone)")

STUB.now = 1791400000
local entry, ewhy = NS.EditLootPrio(link, "Chorf (Tank), Anna", "Neu verteilt")
assert(entry, tostring(ewhy))
p = NS.LootPrioOf(32235)
assert(p.src == "edit" and p.prio[1].name == "Chorf" and p.note == "Neu verteilt" and p.at == 1791400000, "the newer edit wins")
assert(NS.LootPrioInfo().edits == 1)
assert(NS.EditLootPrio(link, "Anna, X1", "") == nil, "a broken order is refused")
assert(NS.LootPrioOf(32235).prio[1].name == "Chorf", "and the old one stays")
-- clearing an item: an empty edit, exported too
assert(NS.ClearLootPrioItem(32837))
assert(NS.LootPrioOf(32837) == nil and NS.LootPrioInfo().edits == 2)

-- the export carries the edits as LC lines (outside any raid block), the rest as before
local exp = NS.ExportText({})
local lc = {}
for line in (exp .. "\n"):gmatch("([^\n]*)\n") do if line:match("^LC ") then lc[#lc + 1] = line end end
table.sort(lc)
assert(#lc == 2, exp)
assert(lc[1]:match("^LC 32235 1791400000 %S+ p:Chorf:Tank,p:Anna Neu verteilt$"), lc[1])
assert(lc[2]:match("^LC 32837 1791400000 %S+ %-$"), lc[2])
assert(has(exp, "#AMISIA 2 ") and exp:match("#END$"))
assert(NS.LootPrioPending() == 2)

-- a newer site list that has the edits drops them (the site took them over)
local NEWER = "#AMISIA-LC 1 forever 2026-10-08\nC 32235 1791400000 p:Chorf:Tank,p:Anna Neu verteilt\nC 32837 1791300100 p:Vulo_Sturmwind\n#END"
assert(NS.SetLootPrio(NEWER))
assert(NS.LootPrioInfo().edits == 1, "the edit of 32235 is on the site now, the clearing of 32837 is newer and stays")
assert(NS.LootPrioOf(32837) == nil, "still cleared")
assert(NS.LootPrioPending() == 1)

---------------------------------------------------------------------------
-- the tooltip (officers; raiders only with a list from the officers)
---------------------------------------------------------------------------
local lines = {}
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
local shown = link
GameTooltip.GetItem = function() return "x", shown end
local function hover(l)
    shown = l
    wipe(lines)
    if GameTooltip.scripts.OnTooltipCleared then GameTooltip.scripts.OnTooltipCleared(GameTooltip) end
    STUB.showTooltip(GameTooltip)
end
NS.ClearGuildWishes()
hover(link)
assert(#lines == 2 and lines[1] == "Prio: 1. Chorf (Tank), 2. Anna" and lines[2] == "Notiz: Neu verteilt", table.concat(lines, " / "))
hover(plain)
assert(#lines == 0)
assert(NS.Set("prio.tooltip", false))
hover(link)
assert(#lines == 0, "switched off")
NS.Reset("prio.tooltip")
assert(NS.Set("ui.view", "raider"))
hover(link)
assert(#lines == 0, "a raider's own pasted list stays the officers'")
NS.Reset("ui.view")

---------------------------------------------------------------------------
-- the roll window: the line under the item, the marks in the rows, the edit dialog
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Chorf", class = "WARRIOR" }, { name = "Anna", class = "PRIEST" },
    { name = "Bob", class = "MAGE" } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
assert(NS.Active(), "a recording")
STUB.loot = { { link = link, name = "x" }, { link = plain, name = "y" } }
STUB.fire("LOOT_OPENED")
assert(NS.StartRoll(link, 20))
NS.ShowRollFrame()
local F = NS.RollFrame
assert(F.prioLine:IsShown() and has(F.prioLine:GetText(), "Prio: 1. Chorf (Tank), 2. Anna · Neu verteilt"), F.prioLine:GetText())
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Bob", 90, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Anna", 50, 1, 100))
STUB.fire("CHAT_MSG_SYSTEM", (RANDOM_ROLL_RESULT):format("Chorf", 10, 1, 100))
local marks = {}
for i = 1, 3 do marks[F.rows[i].who] = F.rows[i].prio:GetText() end
assert(has(marks.Chorf, "P1") and has(marks.Anna, "P2") and marks.Bob == "", ("%s %s %s"):format(marks.Chorf, marks.Anna, marks.Bob))
assert(F.rows[1].who == "Bob", "the prio changes no roll order")
-- the tooltip of the line shows everything
F.prioHit:GetScript("OnEnter")(F.prioHit)
NS.StopRoll()
-- an item without prio: no line, no marks
assert(NS.StartRoll(plain, 20))
assert(not F.prioLine:IsShown() and F.prioBtn:IsShown(), "no line; officers still get the button")
NS.StopRoll()
-- the edit dialog from the roll window's button
assert(NS.StartRoll(link, 20))
F.prioBtn:Click()
local D = NS.PrioDialog
assert(D and D:IsShown() and D.order:GetText() == "Chorf (Tank), Anna" and D.note:GetText() == "Neu verteilt", D.order:GetText())
D.order:SetText("Anna (Tank), Krieger, offen")
D.note:SetText("getauscht")
STUB.now = 1791500000
D.save:Click()
assert(not D:IsShown(), "saved and closed")
assert(NS.LootPrioOf(32235).prio[1].name == "Anna" and NS.LootPrioOf(32235).note == "getauscht")
assert(has(F.prioLine:GetText(), "1. Anna (Tank), 2. Krieger, 3. offen"), "the window follows: " .. F.prioLine:GetText())
-- a broken order keeps the dialog open with the reason
F.prioBtn:Click()
D.order:SetText("Anna, 9")
D.save:Click()
assert(D:IsShown() and has(D.hint:GetText(), "Nicht erkannt: 9"), D.hint:GetText())
D.cancel:Click()
assert(not D:IsShown())
-- raiders get no button
assert(NS.Set("ui.view", "raider"))
NS.ShowRollFrame()
assert(not F.prioBtn:IsShown())
NS.Reset("ui.view")
NS.StopRoll()

---------------------------------------------------------------------------
-- the award dialog: prio players first, the line under the roll
---------------------------------------------------------------------------
local AD = NS.ShowAwardDialog(link)
local vals, texts = {}, {}
for i, v in ipairs(AD.winner.values) do vals[i], texts[i] = v.value, v.text end
assert(vals[1] == "Anna" and texts[1] == "Anna (Prio 1)", table.concat(texts, ","))
assert(has(AD.prio:GetText(), "Prio: 1. Anna (Tank), 2. Krieger, 3. offen"), AD.prio:GetText())
AD:Hide()
AD = NS.ShowAwardDialog(plain)
assert(AD.prio:GetText() == "")
AD:Hide()

---------------------------------------------------------------------------
-- the loot announcement: the prio behind each item, only with loot.prio
---------------------------------------------------------------------------
STUB.leader = true
assert(NS.Set("loot.lead", "me"))
STUB.target, STUB.targetGUID = "Boss", "Creature-0-1-1-1-1-1"
STUB.loot = { { link = link, name = "x", src = "Creature-0-1-1-1-1-1" }, { link = plain, name = "y", src = "Creature-0-1-1-1-1-1" } }
STUB.tick(10); STUB.chat = {}
STUB.fire("LOOT_CLOSED"); STUB.fire("LOOT_OPENED", false)
assert(#STUB.chat == 3 and not has(STUB.chat[2].text, "Prio"), "off by default: " .. (STUB.chat[2] and STUB.chat[2].text or "-"))
assert(NS.Set("loot.prio", true))
STUB.tick(10); STUB.chat = {}
NS.Dispatch("ansage")
assert(#STUB.chat == 3, #STUB.chat)
assert(STUB.chat[2].text == "1. " .. link .. " frei · Prio: Anna (Tank), Krieger, offen", STUB.chat[2].text)
assert(STUB.chat[3].text == "2. " .. plain .. " frei", STUB.chat[3].text)
NS.Reset("loot.prio")
NS.Reset("loot.lead")

---------------------------------------------------------------------------
-- the roll frames of group loot: "P" for everyone with a list, "P1" when the own name stands first
---------------------------------------------------------------------------
local frame = GroupLootFrame1
STUB.rolls[51], STUB.rolls[52] = link, plain
frame.rollID = 51; frame:Show()
assert(NS.LootPrioRollMarkText(frame) == "P", tostring(NS.LootPrioRollMarkText(frame)))
frame:Hide(); frame.rollID = 52; frame:Show()
assert(NS.LootPrioRollMarkText(frame) == nil, "the mark goes with the reused frame")
assert(NS.EditLootPrio(link, "Vuloo, Anna", ""))
frame:Hide(); frame.rollID = 51; frame:Show()
assert(NS.LootPrioRollMarkText(frame) == "P1", "the own rank")

---------------------------------------------------------------------------
-- the command
---------------------------------------------------------------------------
STUB.messages = {}
SlashCmdList.AMISIA("prio")
assert(has(lastMsg(), "Prioliste vom 2026-10-08"), lastMsg())
SlashCmdList.AMISIA("prio " .. link)
assert(NS.PrioDialog:IsShown() and NS.PrioDialog.order:GetText() == "Vuloo, Anna")
NS.PrioDialog:Hide()
-- a long valid list (ten full names with roles) survives the dialog: shown whole, saved whole
do
    local names = { "Annabelle Sturmwind", "Brunhilde Eisherz", "Cassandra Dornfeld", "Dietlinde Morgentau", "Eleonora Feuerkind",
        "Friederike Nachtlied", "Gwendolyn Rabenfels", "Hildegard Wolkenbruch", "Isabella Steinbrecher", "Josefine Sonnenwind" }
    local parts = {}
    for i, n in ipairs(names) do parts[i] = "p:" .. n:gsub(" ", "_") .. ":Heiler-Schamane" end
    local long = NS.LootPrioFreeText(NS.ParsePrioToken(table.concat(parts, ",")))
    assert(#long > 300, #long)
    assert(NS.EditLootPrio(link, long, ""))
    SlashCmdList.AMISIA("prio " .. link)
    local D = NS.PrioDialog
    assert(D.order:GetText() == long, "shown whole: " .. #D.order:GetText() .. " of " .. #long)
    D.save:Click()
    local p = NS.LootPrioOf(32235).prio
    assert(#p == 10 and p[10].name == "Josefine Sonnenwind" and p[10].label == "Heiler-Schamane", "saved whole")
    assert(NS.EditLootPrio(link, "Vuloo, Anna", ""))
end
assert(NS.Set("ui.view", "raider"))
STUB.messages = {}
SlashCmdList.AMISIA("prio " .. link)
assert(not NS.PrioDialog:IsShown() and has(lastMsg(), "nur Offiziere"), lastMsg())
NS.Reset("ui.view")
-- clearing everything
NS.ClearLootPrio()
assert(NS.LootPrioInfo() == nil and NS.LootPrioOf(32235) == nil and NS.LootPrioPending() == 0)
