-- Finding one's way in the main window: the search keeps its scroll place on a data refresh and
-- resets it only for a new text; its tooltip and the "Noch 1 Zeichen" line; keywords find pages and
-- settings sections ("dkp" the page Punkte); the group "Befehle" puts a command into the chat line;
-- the pause button's tooltip; the portrait opens the overview; the side windows' rows in the side bar
-- say what the windows are for (D-68); the minimap's quick menu built from the side bar's groups; the
-- overview cards' one verb "Öffnen".
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function group(groups, key)
    for _, g in ipairs(groups) do if g.key == key then return g end end
end
local function texts(g)
    local out = {}
    for _, h in ipairs(g and g.hits or {}) do out[#out + 1] = h.text end
    return table.concat(out, ",")
end
-- what GameTooltip shows (the stub's AddLine does nothing)
local tip = {}
GameTooltip.AddLine = function(_, text) tip[#tip + 1] = tostring(text) end
GameTooltip.SetText = function(_, text) tip = { tostring(text) } end
local origOwner = GameTooltip.SetOwner
GameTooltip.SetOwner = function(self, ...) tip = {}; if origOwner then return origOwner(self, ...) end end
local function tipText() return table.concat(tip, "\n") end

STUB.officer = true
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SearchIndex._reset()

---------------------------------------------------------------------------
-- keywords: "dkp" finds the page Punkte and its settings section, English words too
---------------------------------------------------------------------------
local g = NS.Search("dkp")
assert(has(texts(group(g, "pages")), "Punkte"), "dkp finds the page Punkte: " .. texts(group(g, "pages")))
assert(has(texts(group(g, "settings")), "Punkte (DKP/EPGP)"), texts(group(g, "settings")))
assert(has(texts(group(NS.Search("waypoint"), "pages")), "Karte"), "an English keyword")
assert(has(texts(group(NS.Search("würfeln"), "pages")), "Rolls"), "a German keyword with an umlaut")
assert(has(texts(group(NS.Search("roster"), "pages")), "Mitglieder"), texts(group(NS.Search("roster"), "pages")))
assert(has(texts(group(NS.Search("skillung"), "pages")), "Talente"))
-- a name hit comes before a keyword hit
local pages = group(NS.Search("ausrüstung"), "pages").hits
-- (the planner's name holds the word too, D-77: both names before any keyword hit)
assert(pages[1].text == "Ausrüstungsplaner" and pages[2].text == "Ausrüstung", pages[1].text .. " " .. tostring(pages[2] and pages[2].text))
-- keywords keep the view: the officers' page Rolls is not found by a raider
NS.Set("ui.view", "raider")
assert(not has(texts(group(NS.Search("würfeln"), "pages")), "Rolls"), "no officer page for a raider")
NS.Set("ui.view", "officer")

---------------------------------------------------------------------------
-- commands: from three characters, a click puts "/amisia <word> " into the chat line
---------------------------------------------------------------------------
assert(group(NS.Search("mi"), "commands") == nil, "commands from three characters")
local cmd = group(NS.Search("minimap"), "commands")
assert(cmd and cmd.label == "Befehle" and cmd.hits[1].text == "/amisia minimap", texts(cmd))
assert(has(cmd.hits[1].tip, "Minimap-Button"), tostring(cmd.hits[1].tip))
local opened
_G.ChatFrameUtil.OpenChat = function(text) opened = text end
cmd.hits[1].run()
assert(opened == "/amisia minimap ", tostring(opened))
-- an officers' command stays hidden in the raider view
local officerCmd
for _, def in ipairs(NS.slash) do if def.officer then officerCmd = def break end end
if officerCmd then
    NS.Set("ui.view", "raider")
    local c = group(NS.Search(officerCmd.word), "commands")
    assert(not has(texts(c), "/amisia " .. officerCmd.word), "no officer command for a raider: " .. officerCmd.word)
    NS.Set("ui.view", "officer")
end

---------------------------------------------------------------------------
-- the window: scroll place, tooltip, the line under SEARCH_MIN
---------------------------------------------------------------------------
NS.ShowPage("overview")
local F = AmisiaFrame
local box = F.search
local function type_(text)
    box:SetText(text)
    box.scripts.OnTextChanged(box, true)
end
type_("e")
-- (D-70: the line in place of the side bar, which fills its room)
assert(not F.nav:IsShown() and not F.results:IsShown() and F.searchHint:IsShown() and F.searchHint:GetText() == "Noch 1 Zeichen für die Suche",
    tostring(F.searchHint:GetText()))
type_("")
assert(not F.searchHint:IsShown(), "no line for an empty box")
type_("ei")
assert(not F.searchHint:IsShown() and F.results:IsShown(), "the results from two characters")
-- many hits: scrolled down, a data change keeps the place
type_("e")
type_("er")
local n = #F.results.items
assert(n > F.results.rowCount, "more hits than rows: " .. n)
F.results.scripts.OnMouseWheel(F.results, -1)
assert(F.results.offset == 1, F.results.offset)
NS.Refresh()
assert(F.results.offset == 1, "a refresh keeps the scroll place: " .. F.results.offset)
NS.Fire("DATA_CHANGED"); STUB.tick(1)
assert(F.results.offset == 1, "a data change keeps the scroll place: " .. F.results.offset)
-- a new text starts at the top
type_("ers")
assert(F.results.offset == 0, "a new text starts at the top: " .. F.results.offset)
type_("")
-- the tooltip names what it searches and from how many characters
box.scripts.OnEnter(box)
assert(has(tipText(), "Suche") and has(tipText(), "Seiten") and has(tipText(), "Rezepte") and has(tipText(), "Befehle")
    and has(tipText(), "Ab 2 Zeichen") and has(tipText(), "Ab 3 Zeichen"), tipText())
-- two characters without a hit: the hint names the three-character groups
type_("qx")
assert(F.noHits:IsShown() and has(F.noHits:GetText(), "ab 3 Zeichen"), F.noHits:GetText())
type_("")

---------------------------------------------------------------------------
-- the status line's tooltip and its menu (recording and view, D-67)
---------------------------------------------------------------------------
F.statusBar.scripts.OnEnter(F.statusBar)
assert(has(tipText(), "Raid-Aufnahme") and has(tipText(), "Aufnahme an") and has(tipText(), "Klick: pausieren"), tipText())
local menu = F.headMenu()
assert(menu[1][1] == "Aufnahme pausieren" and has(menu[1].tip, "fortsetzt"), menu[1][1])
menu[1][2]()
assert(not NS.IsEnabled() and F.headMenu()[1][1] == "Aufnahme fortsetzen", "paused from the menu")
F.statusBar.scripts.OnEnter(F.statusBar)
assert(has(tipText(), "pausiert"), tipText())
F.headMenu()[1][2]()
assert(NS.IsEnabled(), "resumed from the menu")

---------------------------------------------------------------------------
-- the portrait opens the overview from any group
---------------------------------------------------------------------------
local function navRow(kind, key)
    for _, e in ipairs(F.navOrder) do
        if e.entry.kind == kind and e.entry.key == key then return e end
    end
end
NS.ShowPage("talents")
assert(NS.CurrentPage() == "talents")
assert(F.homeBtn, "the portrait takes clicks")
F.homeBtn:Click()
assert(NS.CurrentPage() == "overview" and navRow("page", "overview").entry.on, NS.CurrentPage())
F.homeBtn.scripts.OnEnter(F.homeBtn)
assert(has(tipText(), "Übersicht"), tipText())

---------------------------------------------------------------------------
-- the side windows' rows: name and what the window is for
---------------------------------------------------------------------------
local wins = {}
for _, tab in ipairs({ "raid", "gear", "talents" }) do
NS.ShowTab(tab)
local count = #F.nav.items
for i = 1, count do
    -- each side window's row scrolled into the side bar of its tab (D-73)
    local want = F.nav.items[i]
    F.nav.offset = i - 1
    NS.UpdateSideTabs()
    local e
    for _, o in ipairs(F.navOrder) do if o.entry.kind == want.kind and o.entry.key == want.key then e = o end end
    if e and e.entry.kind == "win" then
        local b = e.button
        b.scripts.OnEnter(b)
        -- the tooltip names the window in full (the row may carry a shorter name: "Importieren" under
        -- "Soft-Reserves")
        assert(#tip >= 2 and tip[1] == e.entry.def.label and e.entry.label == b.label:GetText() and #tip[2] > 10, e.entry.key .. ": " .. tipText())
        wins[#wins + 1] = e.entry.key
    end
end
end
assert(table.concat(wins, " ") == "softres rolls talents", "every side window has its row: " .. table.concat(wins, " "))

---------------------------------------------------------------------------
-- the quick menu: one entry per tab, then settings and the recording switch
---------------------------------------------------------------------------
local top = NS.MinimapMenuEntries()
local groups, rest = {}, {}
for _, e in ipairs(top) do
    if e.sub then groups[#groups + 1] = e.sub else rest[#rest + 1] = e[1] end
end
local shownGroups = {}
for _, b in ipairs(F.tabOrder) do shownGroups[#shownGroups + 1] = b.key end
assert(table.concat(groups, " ") == table.concat(shownGroups, " "), table.concat(groups, " ") .. " / " .. table.concat(shownGroups, " "))
-- on Forever the window "Layer" stands in the first level (F-185), then the raid note (F-196)
local wantRest = (NS.LayerWindow and "Layer|" or "") .. (NS.TargetWindow and "Zielfenster|" or "") .. "Raid-Notiz|Einstellungen|Aufnahme pausieren"
assert(table.concat(rest, "|") == wantRest, table.concat(rest, "|"))
local function sub(key)
    local out = {}
    for _, e in ipairs(NS.MinimapMenuEntries(key)) do out[#out + 1] = e[1] end
    return table.concat(out, "|")
end
-- every visible page is in its group's menu (Aufstellung too, once the officer rank allows the page)
for _, p in ipairs(NS.panels) do
    if NS.Visible(p) then
        assert(has("|" .. sub(NS.PanelGroup(p)) .. "|", "|" .. p.label .. "|"), "the quick menu reaches " .. p.key)
    end
end
for _, key in ipairs({ "Kalender", "Berufe", "Quests", "Talente", "Dungeons" }) do
    local found = false
    for _, t in ipairs(groups) do if has(sub(t), key) then found = true end end
    assert(found, "the quick menu reaches " .. key)
end
-- "Zurück" and a group entry open the menu again, with the other entries
NS.W.Menu(UIParent, top)
local clicked = false
for i, e in ipairs(top) do if e.sub == "gear" then AmisiaMenu.buttons[i]:Click(); clicked = true end end
assert(clicked, "the tab Ausrüstung in the menu")
local gearMenu = NS.MinimapMenuEntries("gear")
assert(AmisiaMenu:IsShown() and AmisiaMenu.buttons[1].label:GetText() == gearMenu[1][1], "the group's pages")
AmisiaMenu.buttons[#gearMenu]:Click()
assert(AmisiaMenu:IsShown() and AmisiaMenu.buttons[1].label:GetText() == top[1][1], "back to the groups")
AmisiaMenu:Hide()
assert(has(sub("gear"), "Ausrüstungstabelle") and has(sub("gear"), "|Zurück"), sub("gear"))
-- a page entry opens the page; "Zurück" and a group entry open the menu again
for _, e in ipairs(NS.MinimapMenuEntries("prof")) do if e[1] == "Berufe" then e[2]() end end
assert(NS.CurrentPage() == "professions", NS.CurrentPage())
NS.Set("ui.view", "raider")
assert(not has(sub("raid"), "Rolls") and not has(sub("raid"), "Aufstellung"), "raiders see no officer pages: " .. sub("raid"))
NS.Set("ui.view", "officer")

---------------------------------------------------------------------------
-- the overview cards: navigation buttons say "Öffnen"
---------------------------------------------------------------------------
NS.ShowPage("overview")
local ov = NS.PageFrame("overview")
-- the cards of Gear.lua and SoftRes.lua (the others' files keep their own words for now)
local seen = {}
for _, c in ipairs(ov.cards) do
    local title = c.title:GetText()
    if c:IsShown() and (title == "Deine Ausrüstung" or title == "Soft-Reserves") and c.button:IsShown() then
        seen[#seen + 1] = title
        local word = c.button:GetText()
        assert(word == "Öffnen" or word == "Importieren" or word == "Prüfen", title .. ": " .. tostring(word))
    end
end
assert(#seen >= 1, "a card checked")
print("nav find ok")
