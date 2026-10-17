-- The tabs under the main window (D-45, spec docs/specs/2026-10-11-fenster-reiter-kalender.md): one
-- per page group (Raid, Ausrüstung, Gilde, Kalender, Amisia), only those with a visible page; the page
-- list shows the open tab's pages; the last tab and the last page per tab are remembered in
-- settings.window (tab, pages) and the window opens there after a /reload; ns.ShowPage and the
-- commands that open a page switch the tab; the old collapsed sections are dropped.

-- a /reload: the saved window state of before, the window not built yet
AmisiaDB.settings.window = { tab = "gear", pages = { gear = "map", raid = "awards" }, collapsed = { raid = true }, point = "CENTER", x = 0, y = 0 }
STUB.officer = false
NS.ToggleMain()
local F = AmisiaFrame
assert(F and F:IsShown(), "the window opens")
assert(NS.CurrentPage() == "map", "the last page of the last tab: " .. tostring(NS.CurrentPage()))
assert(AmisiaDB.settings.window.collapsed == nil, "the collapsed sections are gone")
assert(F.tabs.gear.selected and not F.tabs.raid.selected, "its tab is selected")
local function navShown()
    local out = {}
    for _, e in ipairs(F.navOrder) do out[#out + 1] = e.button.key end
    return table.concat(out, " ")
end
assert(navShown() == "gear dungeons raidjournal map quests professions talents", navShown())
-- the raid tab opens its own last page
F.tabs.raid:Click()
assert(NS.CurrentPage() == "awards" and F.tabs.raid.selected and not F.tabs.gear.selected, NS.CurrentPage())
-- a remembered page that is no longer shown (an officer page in the raider view): the tab's first
AmisiaDB.settings.window.pages.raid = "raids"
NS.ShowTab("gear")
NS.ShowTab("raid")
assert(NS.CurrentPage() == "overview", "the first page when the last one is hidden: " .. NS.CurrentPage())

-- closing and opening keeps the page; ShowPage and the commands switch the tab
F:Hide()
NS.ToggleMain()
assert(NS.CurrentPage() == "overview" and F:IsShown())
NS.Dispatch("einstellungen")
-- under "Einstellungen" its tabs and the chosen tab's sections (D-49): the first is Raid, Aufnahme
assert(NS.CurrentPage() == "settings" and F.tabs.amisia.selected and navShown():match("^settings raid record ")
    and navShown():find(" gear calendar pvp amisia about$"), navShown())
assert(AmisiaDB.settings.window.tab == "amisia" and AmisiaDB.settings.window.pages.amisia == "settings")
NS.Dispatch("kalender")   -- the raid calendar window (not in a guild here: a message), the page stays
assert(NS.CurrentPage() == "settings")
NS.ShowCalendar()
assert(NS.CurrentPage() == "calendar" and F.tabs.calendar.selected and navShown() == "calendar", navShown())
NS.ShowGear("goals")
assert(NS.CurrentPage() == "gear" and F.tabs.gear.selected)

-- the view decides the tabs: the officer view adds the officer pages, never a tab without a page
NS.Set("ui.view", "officer")
NS.ShowTab("guild")
assert(navShown() == "export members bank", navShown())
local bank, exp, members = NS.Panel("bank"), NS.Panel("export"), NS.Panel("members")
local keepBank, keepMembers = bank.available, members.available
bank.available, members.available = function() return false end, function() return false end
NS.Set("ui.view", "raider"); STUB.tick(0)      -- the guild tab has no page left for a raider: gone, the page falls back
assert(not F.tabs.guild:IsShown() and table.concat(F.tabOrder, " ") == "raid gear calendar pvp amisia", table.concat(F.tabOrder, " "))
assert(NS.CurrentPage() == "overview", "the open page fell back: " .. NS.CurrentPage())
bank.available, members.available = keepBank, keepMembers
NS.Refresh()
assert(F.tabs.guild:IsShown() and table.concat(F.tabOrder, " ") == "raid gear guild calendar pvp amisia")
assert(exp.officer, "export stays an officer page")

-- the list's rows: normal height (the auction house's 21) with the few pages of a tab
assert(F.navRowH == 21)
print("main tabs ok")
