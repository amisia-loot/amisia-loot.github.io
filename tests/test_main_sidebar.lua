-- The main window as a hub (D-73, spec 2026-11-08-hub-reiter; before it D-68/D-70): the head with the
-- logo, the name, the search box and the square buttons; the tabs (Ausrüstung, Dungeons & Raids,
-- Berufe, Talente, Raid, Gilde, the gear) under it, only those with a visible page or side window; the
-- side bar shows the open tab's symbol and name and its pages and side windows as rows with their
-- symbols; the last tab and the last page per tab are remembered in settings.window (tab, pages) and
-- the window opens there after a /reload; old groups move to the new tabs once; the footer shows the
-- view and the version.

-- a /reload: the saved window state of before 2.62.0, the window not built yet
AmisiaDB.settings.window = { tab = "gear", pages = { gear = "map", raid = "awards", calendar = "calendar", pvp = "duels" },
    collapsed = { raid = true }, point = "CENTER", x = 0, y = 0, h = 9999 }
STUB.officer = false
NS.ToggleMain()
local F = AmisiaFrame
local W = AmisiaDB.settings.window
assert(F and F:IsShown(), "the window opens")
assert(NS.CurrentPage() == "map", "the last page of the last group: " .. tostring(NS.CurrentPage()))
assert(W.tab == "dungeons", "the old tab became the tab of its page: " .. tostring(W.tab))
assert(W.pages.dungeons == "map" and W.pages.raid == "awards" and W.pages.guild == "calendar" and W.pages.gear == nil
    and W.pages.pvp == nil, "the pages moved to their tabs")
assert(W.collapsed == nil and W.h == nil, "the collapsed sections and a height out of range are gone")
assert(F.sideTabs == nil, "no side tabs beside the window")

-- the open tab's side bar (scrolled out rows too) by key
local function navAll()
    local out = {}
    for _, e in ipairs(F.nav.items) do out[#out + 1] = e.key end
    return table.concat(out, " ")
end
local function tabsShown()
    local out = {}
    for _, b in ipairs(F.tabOrder) do out[#out + 1] = b.key end
    return table.concat(out, " ")
end
local function row(kind, key)
    for _, e in ipairs(F.navOrder) do
        if e.entry.kind == kind and e.entry.key == key then return e end
    end
end
local M, T = NS.Theme.MAIN, NS.Theme
-- the head: the logo, the name, the line, the search box and the three buttons
assert(F.head and F.head.logo and F.head.name:GetText() == "Amisia" and F.head.sub:GetText() ~= "", "the head with the logo")
assert(F.head.close and F.head.min and F.head.feedback and F.search, "the buttons and the search box in the head")
assert(F.viewText:GetText():find(NS.VERSION, 1, true) and F.viewText:GetText():find("Raider", 1, true), F.viewText:GetText())
-- the tabs in their order, the gear at the right end; the open one chosen
assert(tabsShown() == "gear dungeons prof talents raid guild amisia", tabsShown())
assert(F.tabs.dungeons.on and F.tabs.dungeons.line:IsShown() and not F.tabs.raid.on and not F.tabs.raid.line:IsShown(), "the open tab")
assert(F.tabs.amisia.points.TOPRIGHT and F.tabs.gear.points.TOPLEFT.x == M.TAB_X, "the gear tab at the right end")
assert(F.tabs.dungeons.label:GetText() == "Dungeons & Raids" and F.tabs.dungeons.icon:IsShown(), "a tab's symbol and name")
-- the side bar: the open tab's symbol and name, its pages only
assert(F.navHead.name:GetText() == "Dungeons & Raids" and F.navHead.icon:IsShown(), "the side bar's head")
assert(navAll() == "dungeons raidjournal quests map", navAll())
-- the open page is chosen: lighter with the gold bar
local page = row("page", "map")
assert(page and page.entry.on and page.button.sel:IsShown() and page.button.bar:IsShown(), "the open page is chosen")
assert(not row("page", "quests").button.bar:IsShown(), "the others are not")
-- a page: its symbol and its name from NAV_SUB_X
local q = row("page", "quests").button
assert(q.symbol:IsShown() and q.symbol.texture == T.NAV_ICONS.quests.file, "the page's symbol")
assert(q.label.points.LEFT.x == M.NAV_SUB_X)
-- the page head: the page's symbol before its name
assert(F.pageIcon:IsShown() and F.pageTitle:GetText() == NS.Panel("map").label, "the page head")
-- a click on a page opens it
row("page", "quests").button:Click()
assert(NS.CurrentPage() == "quests" and W.tab == "dungeons" and W.pages.dungeons == "quests", NS.CurrentPage())
-- a click on a tab opens its last page
F.tabs.raid:Click()
assert(NS.CurrentPage() == "awards" and W.tab == "raid", NS.CurrentPage())
assert(navAll() == "overview softres awards raidlog stats", navAll())
F.tabs.dungeons:Click()
assert(NS.CurrentPage() == "quests", "the tab remembers its page: " .. NS.CurrentPage())
-- Ausrüstung and Talente: the side windows right under their pages
NS.ShowPage("gear")
assert(navAll() == "planner gear", navAll())
NS.ShowTab("talents")
-- the page and the window, then the page's marks: classes, plans, actions (D-76)
assert(NS.CurrentPage() == "talents" and navAll():match("^talents talents class:") and navAll():find(" slot:1 slot:2 ", 1, true), navAll())
local win = row("win", "talents")
assert(win and win.button.sign:IsShown() and win.button.symbol:IsShown() and not win.entry.on, "the talent window's row with its symbol and sign")
win.button:Click()
assert(AmisiaTalentFrame and AmisiaTalentFrame:IsShown() and NS.CurrentPage() == "talents", "the window opens, the page stays")
assert(row("win", "talents").entry.on, "its row shows it open")
row("win", "talents").button:Click()
assert(not AmisiaTalentFrame:IsShown() and not row("win", "talents").entry.on, "a second click closes it")
-- closed with its own X: the row follows
row("win", "talents").button:Click()
AmisiaTalentFrame:Hide()
assert(not row("win", "talents").entry.on, "the row follows the window's X")
NS.ShowTab("prof")
assert(NS.CurrentPage() == "professions" and navAll():match("^professions"), navAll())

-- a remembered page that is no longer shown (an officer page in the raider view): the tab's first
W.pages.raid = "raids"
NS.ShowTab("raid")
assert(NS.CurrentPage() == "overview", "the first page when the last one is hidden: " .. NS.CurrentPage())

-- closing and opening keeps the page; the commands open their tab
F:Hide()
NS.ToggleMain()
assert(NS.CurrentPage() == "overview" and F:IsShown())
NS.Dispatch("einstellungen")
-- under "Einstellungen" its tabs and the chosen tab's sections (D-49)
assert(NS.CurrentPage() == "settings" and F.tabs.amisia.on and navAll():match("^settings "), navAll())
assert(navAll():find(" about feedback$"), navAll())
assert(W.tab == "amisia" and W.pages.amisia == "settings")
NS.Dispatch("kalender")   -- the raid calendar window (not in a guild here: a message), the page stays
assert(NS.CurrentPage() == "settings")
NS.ShowCalendar()
assert(NS.CurrentPage() == "calendar" and F.tabs.guild.on and row("page", "calendar").entry.on, navAll())
NS.ShowGear("goals")
assert(NS.CurrentPage() == "gear" and row("page", "gear").entry.on)
-- the feedback button of the head
F.head.feedback:Click()
assert(NS.CurrentPage() == "feedback" and F.tabs.amisia.on)

-- the view decides the tabs: the officer view adds the officer pages and windows (only an officer
-- has it, D-87: the officer note right without a guild rank)
STUB.officer = true
NS.Set("ui.view", "officer")
NS.ShowTab("guild")
assert(navAll():match("^members calendar bank duels"), navAll())
-- the window "Layer" at the end of the guild tab (F-185, Forever), lit while it is open
assert(not NS.LayerWindow or navAll():match(" layer$"), navAll())
if NS.LayerWindow then
    local was = STUB.instance
    STUB.instance = { name = "Elwynn Forest", type = "none", id = 0 }   -- the window is not there in an instance
    row("win", "layer").button:Click()
    assert(AmisiaLayerFrame:IsShown() and row("win", "layer").entry.on, "the row opens the window")
    NS.LayerWindow.Hide()
    assert(not row("win", "layer").entry.on, "and goes dark again")
    STUB.instance = was
end
-- the raid tab in the order of a raid night (Export next to the archive), the officer windows under
-- their pages (Aufstellung and Raid-Check need the guild rights the test lacks)
NS.ShowTab("raid")
assert(navAll() == "overview softres softres rolls rolls awards raidlog points stats raids export", navAll())
assert(row("win", "rolls") and row("win", "softres"), "the roll window and the soft-reserve import")
NS.ShowTab("guild")
local bank, exp, members, cal, duels = NS.Panel("bank"), NS.Panel("export"), NS.Panel("members"), NS.Panel("calendar"), NS.Panel("duels")
local keep = { bank.available, members.available, cal.available, duels.available }
for _, p in ipairs({ bank, members, cal, duels }) do p.available = function() return false end end
NS.Set("ui.view", "raider"); STUB.tick(0)      -- the guild tab has no page left: gone, the page falls back
assert(tabsShown() == "gear dungeons prof talents raid amisia", tabsShown())
assert(NS.CurrentPage() == "overview" and F.tabs.raid.on, "the open page fell back: " .. NS.CurrentPage())
bank.available, members.available, cal.available, duels.available = keep[1], keep[2], keep[3], keep[4]
NS.Refresh()
assert(tabsShown():find("guild", 1, true), "the guild tab is back")
assert(exp.officer, "export stays an officer page")

-- a symbol the client lacks leaves the row without one (no stale symbol of a pooled row); a file
-- symbol after an atlas gets its full texture again
local icons = T.NAV_ICONS
local keepIcon = icons.overview
NS.ShowPage("overview")
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

-- the rows: NAV_ROW_H high, as many as fit the side bar at the window's own height
assert(F.nav.rowCount == math.floor(M.NAV_LIST_H / M.NAV_ROW_H) and F:GetHeight() == M.H, F.nav.rowCount)
-- the minimize button folds the window to the bar
F.head.min:Click()
assert(not F:IsShown() and F.mini:IsShown(), "minimized")
F.Restore()
assert(F:IsShown() and not F.mini:IsShown(), "back")
-- the close button
F.head.close:Click()
assert(not F:IsShown(), "closed")
NS.ToggleMain()
-- a page's marks (D-74, D-75): under the tab's pages, each may carry its symbol, be chosen and start a
-- block with the gold line over it; a click runs the page's jump
local jumped
NS.RegisterPanel{ key = "tpmarks", label = "Marken", order = 5, group = "raid",
    create = function(p) return CreateFrame("Frame", nil, p) end,
    jumps = function() return { { key = "a", label = "Eins", icon = { file = "Interface\\Icons\\X" } , on = true },
        { key = "b", label = "Zwei", count = 3 }, { key = "c", label = "Drei", rule = true, tip = "Mehr" } } end,
    jump = function(_, key) jumped = key end }
NS.ShowPage("tpmarks")
local ma, mb, mc = row("jump", "a"), row("jump", "b"), row("jump", "c")
assert(ma and mb and mc, "the marks under the pages")
assert(ma.button.symbol:IsShown() and ma.button.label.points.LEFT.x == M.NAV_SUB_X and ma.button.bar:IsShown(), "symbol, indent, chosen")
assert(ma.button.rule:IsShown() and not mb.button.rule:IsShown() and mc.button.rule:IsShown(), "the lines over the blocks")
assert(not mb.button.symbol:IsShown() and mb.button.label.points.LEFT.x == M.NAV_LABEL_X and mb.button.count:GetText() == "3")
mb.button:Click()
assert(jumped == "b", "the page's jump")
print("main hub ok")
