-- The main window's side bar (D-68, spec docs/specs/2026-11-07-seitenleiste.md): the page groups as
-- the auction house's category bars (Raid, Charakter, Welt, Gilde, Amisia), only those with a visible
-- page or side window, one unfolded at a time with its pages and side windows; no tabs under the
-- window, no side tabs; the last group and the last page per group are remembered in settings.window
-- (tab, pages) and the window opens there after a /reload; the old groups "gear", "calendar" and "pvp"
-- move to the new ones once; ns.ShowPage and the commands unfold the page's group.

-- a /reload: the saved window state of before 2.62.0, the window not built yet
AmisiaDB.settings.window = { tab = "gear", pages = { gear = "map", raid = "awards", calendar = "calendar", pvp = "duels" },
    collapsed = { raid = true }, point = "CENTER", x = 0, y = 0, h = 9999 }
STUB.officer = false
NS.ToggleMain()
local F = AmisiaFrame
local W = AmisiaDB.settings.window
assert(F and F:IsShown(), "the window opens")
assert(NS.CurrentPage() == "map", "the last page of the last group: " .. tostring(NS.CurrentPage()))
assert(W.tab == "world", "the old tab became the group of its page: " .. tostring(W.tab))
assert(W.pages.world == "map" and W.pages.raid == "awards" and W.pages.guild == "calendar" and W.pages.gear == nil
    and W.pages.pvp == nil, "the pages moved to their groups")
assert(W.collapsed == nil and W.h == nil, "the collapsed sections and a height out of range are gone")
assert(F.tabs == nil and F.sideTabs == nil, "no tabs under or beside the window")

local function navShown()
    local out = {}
    for _, e in ipairs(F.navOrder) do
        out[#out + 1] = (e.entry.kind == "cat" and (e.entry.open and "-" or "+") or "") .. e.button.key
    end
    return table.concat(out, " ")
end
local function row(kind, key)
    for _, e in ipairs(F.navOrder) do
        if e.entry.kind == kind and e.entry.key == key then return e end
    end
end
-- the raider view: the groups, the open one with its pages; Welt has no side window
assert(navShown() == "+raid +char -world dungeons raidjournal quests map +guild +amisia", navShown())
assert(row("page", "map").entry.on and not row("cat", "world").entry.on, "the page is chosen, its open group not")
-- the bars: a group on the category bar, its pages on the sub-category bar, indented
local cat, page = row("cat", "world").button, row("page", "map").button
assert(cat.art.normal:IsShown() and not cat.subArt.normal:IsShown() and cat.sign:IsShown(), "a group: the category bar and its sign")
assert(page.subArt.normal:IsShown() and not page.art.normal:IsShown() and not page.sign:IsShown(), "a page: the sub-category bar")
assert(page.label.points.LEFT.x == NS.Theme.MAIN.NAV_SUB_X and cat.label.points.LEFT.x == NS.Theme.MAIN.NAV_LABEL_X)

-- a click on a folded group: the open one folds, the new one opens its last page
row("cat", "raid").button:Click()
assert(NS.CurrentPage() == "awards" and W.tab == "raid", NS.CurrentPage())
assert(navShown():match("^%-raid overview .* awards .*%+char %+world %+guild %+amisia$"), navShown())
-- a click on the open group folds it; the page stays and its group keeps the glow
row("cat", "raid").button:Click()
assert(NS.CurrentPage() == "awards" and navShown() == "+raid +char +world +guild +amisia", navShown())
assert(row("cat", "raid").entry.on, "the folded group of the open page glows")
-- Charakter: its pages and the side windows right under their pages
row("cat", "char").button:Click()
assert(NS.CurrentPage() == "gear", NS.CurrentPage())
assert(navShown() == "+raid -char gear gear goals talents talents professions +world +guild +amisia", navShown())
local win = row("win", "talents")
assert(win and win.button.sign:IsShown() and not win.entry.on, "the talent window's row with its sign")
win.button:Click()
assert(AmisiaTalentFrame and AmisiaTalentFrame:IsShown() and NS.CurrentPage() == "gear", "the window opens, the page stays")
assert(row("win", "talents").entry.on, "its row shows it open")
row("win", "talents").button:Click()
assert(not AmisiaTalentFrame:IsShown() and not row("win", "talents").entry.on, "a second click closes it")
-- closed with its own X: the row follows
row("win", "talents").button:Click()
AmisiaTalentFrame:Hide()
assert(not row("win", "talents").entry.on, "the row follows the window's X")

-- a remembered page that is no longer shown (an officer page in the raider view): the group's first
W.pages.raid = "raids"
NS.ShowTab("raid")
assert(NS.CurrentPage() == "overview", "the first page when the last one is hidden: " .. NS.CurrentPage())

-- closing and opening keeps the page; ShowPage and the commands unfold the group
F:Hide()
NS.ToggleMain()
assert(NS.CurrentPage() == "overview" and F:IsShown())
NS.Dispatch("einstellungen")
-- under "Einstellungen" its tabs and the chosen tab's sections (D-49): the first is Raid, Aufnahme
assert(NS.CurrentPage() == "settings" and navShown():match("%-amisia settings raid record "), navShown())
-- more than fit: the side bar scrolls, the rest is under it
local all = {}
for _, e in ipairs(F.nav.items) do all[#all + 1] = e.key end
all = table.concat(all, " ")
assert(#F.nav.items > F.nav.rowCount and all:find(" char world guild amisia about feedback$"), all)
assert(F.nav.items[F.nav.offset + 1].kind == "cat", "scrolled to show the group's bar over the open page")
assert(W.tab == "amisia" and W.pages.amisia == "settings")
NS.Dispatch("kalender")   -- the raid calendar window (not in a guild here: a message), the page stays
assert(NS.CurrentPage() == "settings")
NS.ShowCalendar()
assert(NS.CurrentPage() == "calendar" and row("cat", "guild").entry.open and row("page", "calendar").entry.on, navShown())
NS.ShowGear("goals")
assert(NS.CurrentPage() == "gear" and row("cat", "char").entry.open)

-- the view decides the groups: the officer view adds the officer pages and windows
NS.Set("ui.view", "officer")
NS.ShowTab("guild")
assert(navShown() == "+raid +char +world -guild members calendar bank duels +amisia", navShown())
-- the raid group in the order of a raid night (Export next to the archive), the officer windows
-- under their pages
NS.ShowTab("raid")
-- (Aufstellung and Raid-Check after Übersicht need the guild rights the test lacks)
assert(navShown() == "-raid overview softres softres rolls rolls awards raidlog points stats raids export +char +world +guild +amisia", navShown())
assert(row("win", "rolls") and row("win", "softres"), "the roll window and the soft-reserve import")
NS.ShowTab("guild")
local bank, exp, members, cal, duels = NS.Panel("bank"), NS.Panel("export"), NS.Panel("members"), NS.Panel("calendar"), NS.Panel("duels")
local keep = { bank.available, members.available, cal.available, duels.available }
for _, p in ipairs({ bank, members, cal, duels }) do p.available = function() return false end end
NS.Set("ui.view", "raider"); STUB.tick(0)      -- the guild group has no page left: gone, the page falls back
assert(not row("cat", "guild") and navShown() == "-raid overview softres awards raidlog stats +char +world +amisia", navShown())
assert(NS.CurrentPage() == "overview", "the open page fell back: " .. NS.CurrentPage())
bank.available, members.available, cal.available, duels.available = keep[1], keep[2], keep[3], keep[4]
NS.Refresh()
assert(row("cat", "guild"), "the guild group is back")
assert(exp.officer, "export stays an officer page")

-- the rows: the auction house's 21, 21 of them at the window's own height
assert(F.nav.rowCount == 21 and F:GetHeight() == 560, F.nav.rowCount)
print("main side bar ok")
