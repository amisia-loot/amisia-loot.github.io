-- The main window's side bar (D-68, D-70, specs 2026-11-07-seitenleiste and -hauptfenster-journal): a
-- head with the logo, the version and the view; the page groups (Raid, Charakter, Welt, Gilde, Amisia)
-- as gold headings, only those with a visible page or side window, all open with their pages and
-- side windows as rows with their symbols; no tabs under the window, no side tabs; the last group and the last page per group are remembered in settings.window
-- (tab, pages) and the window opens there after a /reload; the old groups "gear", "calendar" and "pvp"
-- move to the new ones once; ns.ShowPage and the commands scroll the page into view.

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

-- the whole side bar (scrolled out rows too): a heading as "#key", a page or window by its key
local function navAll()
    local out = {}
    for _, e in ipairs(F.nav.items) do out[#out + 1] = (e.kind == "cat" and "#" or "") .. e.key end
    return table.concat(out, " ")
end
local function row(kind, key)
    for _, e in ipairs(F.navOrder) do
        if e.entry.kind == kind and e.entry.key == key then return e end
    end
end
local M = NS.Theme.MAIN
-- the head: the logo, the name, the version and the view
assert(F.navHead and F.navHead.logo and F.navHead.name:GetText() == "Amisia", "the head with the logo")
assert(F.navHead.view:GetText():find(NS.VERSION, 1, true) and F.navHead.view:GetText():find("Raider", 1, true), F.navHead.view:GetText())
-- the raider view: every group a heading with all its pages, none folded
assert(navAll():match("^#raid overview softres awards raidlog stats #char gear gear goals talents talents professions #world dungeons raidjournal quests map #guild .* #amisia "), navAll())
assert(NS.CurrentPage() == "map", NS.CurrentPage())
-- the open page is scrolled into view and chosen; its heading is no bar and never chosen
local page = row("page", "map")
assert(page and page.entry.on and page.button.subArt.sel:IsShown(), "the open page is in view and chosen")
local head = row("cat", "world")
assert(head and not head.button.subArt.normal:IsShown() and not head.button.sign:IsShown() and not head.button.subArt.sel:IsShown(),
    "a heading has no bar, no sign and no glow")
assert(head.button.label:GetText() == "WELT" and head.button.rule:IsShown(), "in capitals, with the gold line over it")
-- the first heading has no line over it
F.nav.offset = 0
NS.Refresh()
assert(row("cat", "raid").button.rule:IsShown() == false, "no line over the first heading")
-- a page: its symbol and its name from NAV_SUB_X; a side window: its symbol and the maximize sign
local ov = row("page", "overview").button
assert(ov.symbol:IsShown() and ov.symbol.texture == NS.Theme.NAV_ICONS.overview.file, "the overview's symbol")
assert(ov.label.points.LEFT.x == M.NAV_SUB_X and row("cat", "raid").button.label.points.LEFT.x == M.NAV_LABEL_X)
-- a click on a heading does nothing
local before = NS.CurrentPage()
row("cat", "raid").button:Click()
assert(NS.CurrentPage() == before, "a heading is no button")
-- a click on a page opens it
row("page", "awards").button:Click()
assert(NS.CurrentPage() == "awards" and W.tab == "raid" and W.pages.raid == "awards", NS.CurrentPage())
-- Charakter: the side windows right under their pages
NS.ShowPage("gear")
local win = row("win", "talents")
assert(win and win.button.sign:IsShown() and win.button.symbol:IsShown() and not win.entry.on, "the talent window's row with its symbol and sign")
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

-- closing and opening keeps the page; ShowPage and the commands scroll to it
F:Hide()
NS.ToggleMain()
assert(NS.CurrentPage() == "overview" and F:IsShown())
NS.Dispatch("einstellungen")
-- under "Einstellungen" its tabs and the chosen tab's sections (D-49): the first is Raid, Aufnahme
assert(NS.CurrentPage() == "settings" and navAll():match("#amisia settings raid record "), navAll())
-- all of it in the side bar's entries (what does not fit is scrolled to, test_style)
local all = {}
for _, e in ipairs(F.nav.items) do all[#all + 1] = e.key end
all = table.concat(all, " ")
assert(all:find(" char world guild amisia about feedback$"), all)
assert(row("page", "settings"), "scrolled to show the open page")
assert(W.tab == "amisia" and W.pages.amisia == "settings")
NS.Dispatch("kalender")   -- the raid calendar window (not in a guild here: a message), the page stays
assert(NS.CurrentPage() == "settings")
NS.ShowCalendar()
assert(NS.CurrentPage() == "calendar" and row("page", "calendar").entry.on, navAll())
NS.ShowGear("goals")
assert(NS.CurrentPage() == "gear" and row("page", "gear").entry.on)

-- the view decides the groups: the officer view adds the officer pages and windows
NS.Set("ui.view", "officer")
NS.ShowTab("guild")
assert(navAll():match("#guild members calendar bank duels #amisia"), navAll())
-- the raid group in the order of a raid night (Export next to the archive), the officer windows
-- under their pages
NS.ShowTab("raid")
-- (Aufstellung and Raid-Check after Übersicht need the guild rights the test lacks)
assert(navAll():match("^#raid overview softres softres rolls rolls awards raidlog points stats raids export #char "), navAll())
assert(row("win", "rolls") and row("win", "softres"), "the roll window and the soft-reserve import")
NS.ShowTab("guild")
local bank, exp, members, cal, duels = NS.Panel("bank"), NS.Panel("export"), NS.Panel("members"), NS.Panel("calendar"), NS.Panel("duels")
local keep = { bank.available, members.available, cal.available, duels.available }
for _, p in ipairs({ bank, members, cal, duels }) do p.available = function() return false end end
NS.Set("ui.view", "raider"); STUB.tick(0)      -- the guild group has no page left: gone, the page falls back
assert(not navAll():find("#guild", 1, true) and navAll():match("^#raid overview softres awards raidlog stats #char "), navAll())
assert(NS.CurrentPage() == "overview", "the open page fell back: " .. NS.CurrentPage())
bank.available, members.available, cal.available, duels.available = keep[1], keep[2], keep[3], keep[4]
NS.Refresh()
assert(navAll():find("#guild", 1, true), "the guild group is back")
assert(exp.officer, "export stays an officer page")

-- review (D-70): a symbol the client lacks leaves the row without one (no stale symbol of a pooled
-- row); a file symbol after an atlas gets its full texture again
local nav = F.nav
local probe = nav.rows[1]
local icons = NS.Theme.NAV_ICONS
local keepIcon = icons.overview
NS.ShowPage("overview")
nav.offset = 0
icons.overview = { atlas = "no-such-atlas" }
NS.Refresh()
assert(row("page", "overview") and not row("page", "overview").button.symbol:IsShown(), "no symbol without its atlas")
icons.overview = { file = "Interface\\Nowhere\\Missing" }
local keepFind = GetFileIDFromPath
GetFileIDFromPath = function(path) if path:find("Nowhere", 1, true) then return nil end return 1 end
NS.Refresh()
assert(not row("page", "overview").button.symbol:IsShown(), "no symbol without its file")
GetFileIDFromPath = keepFind
icons.overview = keepIcon
NS.Refresh()
local sym = row("page", "overview").button.symbol
assert(sym:IsShown() and sym.texture == keepIcon.file, "the file symbol again")
-- a view switch drops rows above the open page: it is scrolled into view again
NS.Set("ui.view", "officer")
NS.ShowPage("stats")
nav.offset = 0
NS.Refresh()
local at
for i, e in ipairs(nav.items) do if e.kind == "page" and e.key == "stats" then at = i end end
nav.offset = at - 3
NS.Refresh()
assert(row("page", "stats"), "stats in view")
NS.Set("ui.view", "raider"); STUB.tick(0)
assert(row("page", "stats") and row("page", "stats").entry.on, "still in view after the officer rows above it went")
assert(probe)

-- the rows: the auction house's 21, 21 of them at the window's own height under the head
assert(F.nav.rowCount == 21 and F:GetHeight() == NS.Theme.MAIN.H, F.nav.rowCount)
print("main side bar ok")
