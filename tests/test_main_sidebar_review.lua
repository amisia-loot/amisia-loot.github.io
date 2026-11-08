-- Review of the main window's side bar (D-68, D-70, before it the tabs of D-45): (1) a hit of the search
-- brings the side bar back with the hit's page in view; (2) a redirect to the overview (a view switch,
-- a page no longer shown, a command for a hidden page) does not overwrite the remembered page of a
-- group: only pages the player chose are remembered; (3) the dragged height: the page area, the side
-- bar and the pages' lists follow, it is remembered, clamped to the screen and reset with the position.
STUB.officer = false
NS.Set("ui.view", "officer")
NS.ShowPage("awards")
local F = AmisiaFrame
local W = AmisiaDB.settings.window
local T, M = NS.Theme, NS.Theme.MAIN
assert(W.pages.raid == "awards")
local function type_(text) F.search:SetText(text) F.search.scripts.OnTextChanged(F.search, true) end
local function row(kind, key)
    for _, e in ipairs(F.navOrder) do
        if e.entry.kind == kind and e.entry.key == key then return e end
    end
end

-- (1) searching, then a hit in another group
type_("dungeons")
assert(F.results:IsShown() and not F.nav:IsShown(), "the results replace the side bar")
local hit
for i = 1, F.results.rowCount do
    local r = F.results.rows[i]
    if r.item and r.item.text == "Dungeons" then hit = r end
end
assert(hit, "the page is found")
hit:Click()
assert(F.search:GetText() == "" and F.nav:IsShown() and not F.results:IsShown(), "the side bar is back")
assert(NS.CurrentPage() == "dungeons" and row("page", "dungeons").entry.on, "the hit's page is chosen and in view")

-- (2) the officer opens Export (group Raid since the raid-night order), then switches to the raider
-- view: the page falls back
NS.ShowPage("awards")
NS.ShowPage("export")
assert(W.pages.raid == "export" and row("page", "export").entry.on)
NS.Set("ui.view", "raider"); STUB.tick(0)
assert(NS.CurrentPage() == "overview" and row("page", "overview").entry.on, "the page fell back to the overview")
assert(W.pages.raid == "export", "the raid group keeps the page the player chose: " .. tostring(W.pages.raid))
-- a command for a page the raider does not see: the overview, nothing remembered
NS.ShowPage("stats")
assert(W.pages.raid == "stats")
NS.ShowPage("raids")
assert(NS.CurrentPage() == "overview" and W.pages.raid == "stats", tostring(W.pages.raid))
-- the raid group opens the remembered page again
NS.ShowTab("char")
NS.ShowTab("raid")
assert(NS.CurrentPage() == "stats", NS.CurrentPage())
NS.ShowPage("overview")
assert(W.pages.raid == "overview")

-- (3) the height: a list that fills its page (Quests) grows with it
NS.ShowPage("quests")
local list = NS.PageFrame("quests").list
assert(list, "the quests page has a list that fills it")
local before, navRows = list.rowCount, F.nav.rowCount
assert(F:GetHeight() == M.H and T.PAGE_H == 478 and F.grip and F.grip:IsShown())
F.applyHeight(M.H + 105)
F.heightDone()
assert(F:GetHeight() == M.H + 105 and T.PAGE_H == 478 + 105, "the page area follows: " .. T.PAGE_H)
assert(W.h == M.H + 105, "remembered: " .. tostring(W.h))
assert(F.nav.rowCount == navRows + 5, "the side bar shows 5 more rows: " .. F.nav.rowCount)
assert(list.rowCount == before + math.floor(105 / (list.rows[1]:GetHeight() + 1)), "the list grows: " .. before .. " -> " .. list.rowCount)
-- never past H_MAX nor the screen
F.applyHeight(5000)
assert(F:GetHeight() == M.H_MAX, F:GetHeight())
UIParent:SetHeight(700)   -- a small screen
F.applyHeight(M.H_MAX)
assert(F:GetHeight() == 700, "never taller than the screen: " .. F:GetHeight())
UIParent:SetHeight(1080)
-- smaller again: the list shrinks back (rows kept, hidden)
F.applyHeight(M.H)
F.heightDone()
assert(list.rowCount == before and W.h == nil, "back at the window's own height nothing is remembered")
-- a detail beside a fill list keeps the list's height (Berufe: built tall, then the window smaller)
F.applyHeight(M.H + 120)
F.heightDone()
NS.ShowPage("professions")
local prof = NS.PageFrame("professions")
assert(prof.detail:GetHeight() == prof.list:GetHeight(), "as high as the list when built")
F.applyHeight(M.H)
F.heightDone()
assert(prof.detail:GetHeight() == prof.list:GetHeight() and prof.list:GetHeight() < (M.H + 120 - 82),
    "the detail shrinks with its list: " .. prof.detail:GetHeight() .. " / " .. prof.list:GetHeight())
-- the window hidden mid-drag (Escape): the drag ends there and the height is kept
local g = F.grip
g.scripts.OnMouseDown(g, "LeftButton")
assert(g.scripts.OnUpdate, "dragging")
F:Hide()
g.scripts.OnHide(g)
assert(not g.scripts.OnUpdate, "the drag ended with the window")
NS.ToggleMain()
-- the reset of the positions also resets the height
F.applyHeight(M.H + 50)
F.heightDone()
NS.ResetPositions()
assert(F:GetHeight() == M.H and W.h == nil and T.PAGE_H == 478)
-- a side window closed while the search shows its results: the side bar is right when it comes back
NS.Set("ui.view", "officer")
NS.ShowPage("rolls")
local function winRow(key)
    for _, e in ipairs(F.navOrder) do if e.entry.kind == "win" and e.entry.key == key then return e end end
end
winRow("rolls").button:Click()
assert(AmisiaRollFrame:IsShown() and winRow("rolls").entry.on)
type_("ro")
AmisiaRollFrame:Hide()
NS.ClearSearch()
assert(not winRow("rolls").entry.on, "the roll window's row is off again")
print("main side bar review ok")
