-- Review of the main window's tabs (2.27.0, D-45): (1) a click on a tab while the search shows its
-- results clears the search and brings that tab's page list back (the open tab too: it stays
-- clickable while the results show); (2) a redirect to the overview (a view switch, a page no longer
-- shown, a command for a hidden page) does not overwrite the remembered page of a tab: only pages
-- the player chose are remembered.
STUB.officer = false
NS.Set("ui.view", "officer")
NS.ShowPage("awards")
local F = AmisiaFrame
local W = AmisiaDB.settings.window
assert(W.pages.raid == "awards")
local function type_(text) F.search:SetText(text) F.search.scripts.OnTextChanged(F.search, true) end

-- (1) searching, then a click on another tab
type_("ra")
assert(F.results:IsShown() and not F.nav:IsShown(), "the results replace the page list")
F.tabs.gear:Click()
assert(F.search:GetText() == "", "the search is cleared")
assert(F.nav:IsShown() and not F.results:IsShown(), "the page list is back")
assert(NS.CurrentPage() == "gear" and F.tabs.gear.selected)
-- the open tab while searching: clickable, the click brings its list back
type_("ra")
assert(F.results:IsShown() and F.tabs.gear:IsEnabled(), "the open tab stays clickable while searching")
F.tabs.gear:Click()
assert(F.search:GetText() == "" and F.nav:IsShown() and not F.results:IsShown() and NS.CurrentPage() == "gear")
assert(not F.tabs.gear:IsEnabled(), "not searching: the open tab is not clickable again")

-- (2) the officer opens Export (guild tab), then switches to the raider view: the page falls back
NS.ShowPage("awards")
NS.ShowPage("export")
assert(W.pages.guild == "export" and W.pages.raid == "awards")
NS.Set("ui.view", "raider"); STUB.tick(0)
assert(NS.CurrentPage() == "overview" and F.tabs.raid.selected, "the page fell back to the overview")
assert(W.pages.raid == "awards", "the raid tab keeps the page the player chose: " .. tostring(W.pages.raid))
assert(W.pages.guild == "export")
-- a command for a page the raider does not see: the overview, nothing remembered
NS.ShowPage("stats")
assert(W.pages.raid == "stats")
NS.ShowPage("raids")
assert(NS.CurrentPage() == "overview" and W.pages.raid == "stats", tostring(W.pages.raid))
-- the raid tab opens the remembered page again
NS.ShowTab("gear")
NS.ShowTab("raid")
assert(NS.CurrentPage() == "stats", NS.CurrentPage())
-- a page chosen by the player is remembered as before
NS.ShowPage("overview")
assert(W.pages.raid == "overview")
print("main tabs review ok")
