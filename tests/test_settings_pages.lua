-- The settings by tabs (spec 2026-10-13-dungeons-einstellungen, part B, D-49): every section has its
-- tab and pages that exist; the page list shows the tabs and the chosen tab's sections under
-- "Einstellungen"; the head button "Einstellungen" of a page opens its sections with "Zurück zu
-- <Seite>"; "Zurücksetzen" sets the shown sections to their defaults after asking, "Alle Einstellungen
-- zurücksetzen" every section; the raider view hides the officers' sections.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
NS.Set("ui.expert", true)

local GROUPS = {}
for _, g in ipairs(NS.PANEL_GROUPS) do GROUPS[g.key] = true end
for _, sec in ipairs(NS.schema) do
    assert(GROUPS[sec.group], "the tab of " .. sec.key .. ": " .. tostring(sec.group))
    for _, p in ipairs(sec.pages or {}) do assert(NS.Panel(p), sec.key .. " names a page that does not exist: " .. p) end
end

NS.ToggleMain()
local F = AmisiaFrame
local function navShown()
    local out = {}
    for _, e in ipairs(F.navOrder) do out[#out + 1] = (e.entry.kind == "section" and "-" or "") .. e.button.key end
    return table.concat(out, " ")
end

-- the head button: shown on a page with settings, its tooltip names them
NS.ShowPage("map")
assert(F.settingsBtn:IsShown(), "the map page has settings")
local tip, addLine = {}, GameTooltip.AddLine
GameTooltip.AddLine = function(self, t) tip[#tip + 1] = t end
F.settingsBtn:GetScript("OnEnter")(F.settingsBtn)
GameTooltip.AddLine = addLine
assert(tip[1] == "Einstellungen: Karte und Wegpunkt", tostring(tip[1]))
NS.ShowPage("talents")
assert(not F.settingsBtn:IsShown(), "the talents page has none")
NS.ShowPage("rolls")
F.settingsBtn:Click()
assert(NS.CurrentPage() == "settings" and not F.settingsBtn:IsShown())
local page = NS.SettingsPageFrame()
local chosen, set = NS.SettingsChosen()
assert(chosen == nil and set.rolls and set.need and set.loot and set.lootrules and set.prio and set.rollwin, "the sections of Rolls")
assert(page.back:IsShown() and page.back:GetText() == "Zurück zu Rolls", tostring(page.back:GetText()))
assert(NS.SettingsRows()["rolls.seconds"]:IsShown() and NS.SettingsRows()["need.share"]:IsShown())
assert(has(navShown(), "-rolls -rollwin -need -loot -lootrules -prio"), navShown())
page.back:Click()
assert(NS.CurrentPage() == "rolls", "back to the page")
-- coming back to the settings shows the chosen section again, not the page's
NS.ShowSettingsSection("map")
assert(NS.SettingsChosen() == "map" and not page.back:IsShown())
assert(AmisiaDB.settings.window.section == "map", "remembered")

-- the page list under "Einstellungen": the tabs, the chosen one open
local nav = navShown()
assert(has(nav, "settings raid gear -bis -wishes -drops -map -quests -collect -crafters guild calendar amisia about"), nav)
for _, e in ipairs(F.navOrder) do
    if e.entry.kind == "group" and e.entry.key == "guild" then e.button:Click() break end
end
assert(NS.SettingsChosen() == "bank", "a tab opens its first section: " .. tostring(NS.SettingsChosen()))
for _, e in ipairs(F.navOrder) do
    if e.entry.kind == "section" and e.entry.key == "mats" then e.button:Click() break end
end
assert(NS.SettingsChosen() == "mats")

-- folding, as the auction house's categories: the open tab folds and unfolds, "Einstellungen" folds
-- the tabs; the section stays shown; another section unfolds everything again
local function navRow(kind, key)
    for _, e in ipairs(F.navOrder) do
        if e.entry.kind == kind and e.button.key == key then return e.button end
    end
end
navRow("group", "guild"):Click()
assert(NS.SettingsChosen() == "mats", "folding keeps the section")
assert(has(navShown(), "settings raid gear guild calendar") and not has(navShown(), "-mats"), "the tab folded: " .. navShown())
navRow("group", "guild"):Click()
assert(has(navShown(), "guild -bank") and has(navShown(), "-mats"), "unfolded: " .. navShown())
navRow("group", "guild"):Click()
navRow("group", "gear"):Click()
assert(NS.SettingsChosen() == "bis" and has(navShown(), "gear -bis") and not has(navShown(), "-mats"), "another tab opens: " .. navShown())
navRow("page", "settings"):Click()
assert(NS.SettingsChosen() == "bis" and not navRow("group", "raid") and not navRow("section", "bis"), "the tabs folded: " .. navShown())
navRow("page", "settings"):Click()
assert(navRow("group", "raid") and navRow("section", "bis"), "the tabs unfolded: " .. navShown())
navRow("page", "settings"):Click()
NS.ShowSettingsSection("mats")
assert(navRow("group", "raid") and navRow("section", "mats"), "another section unfolds: " .. navShown())

-- "Zurücksetzen": grey while nothing is changed, then the shown section after asking
NS.ShowSettingsSection("map")
assert(not page.reset:IsEnabled(), "nothing to reset")
NS.Set("map.pins", false)
NS.Set("map.pinScale", 150)
NS.Set("rolls.seconds", 30); STUB.tick(0)
assert(page.reset:IsEnabled())
for _, e in ipairs(F.navOrder) do
    if e.entry.key == "map" then assert(has(e.button.label:GetText(), "dot"), "the changed mark") end
end
page.reset:Click()
local Q = AmisiaConfirmFrame
assert(Q and Q:IsShown(), "asks first")
Q.ok:Click()
assert(NS.Get("map.pins") == true and NS.Get("map.pinScale") == 100, "the section is on its defaults")
assert(NS.Get("rolls.seconds") == 30, "another section stays")

-- "Alle Einstellungen zurücksetzen"
NS.Set("map.pins", false)
STUB.messages = {}
NS.SettingItem("ui.resetAll").run()
AmisiaConfirmFrame.ok:Click()
assert(NS.Get("rolls.seconds") == 20 and NS.Get("map.pins") == true and NS.Get("ui.expert") == false, "every section")
assert(has(STUB.messages[#STUB.messages], "auf den Standard gesetzt"), STUB.messages[#STUB.messages])

-- a hidden setting neither marks nor resets its section: the expert item of "Aufnahme"
NS.Set("ui.expert", false)
NS.Set("record.resumeHours", 5)
local recordSec
for _, sec in ipairs(NS.schema) do if sec.key == "record" then recordSec = sec end end
assert(not NS.SectionChanged(recordSec), "only an expert item changed: no mark")
assert(NS.ResetSections({ recordSec }) == 0 and NS.Get("record.resumeHours") == 5, "and not reset")
assert(NS.ResetSections({ recordSec }, true) == 1 and NS.Get("record.resumeHours") == 2, "all: reset")
-- the raider view: no officers' section, no tab without one
NS.Set("ui.view", "raider")
for _, g in ipairs(NS.SettingsGroups()) do
    for _, sec in ipairs(g.sections) do assert(not sec.officer, "officers' section for a raider: " .. sec.key) end
end
NS.ShowPage("overview")
assert(F.settingsBtn:IsShown(), "the overview has the roll window's and the recording's settings")
F.settingsBtn:Click()
local _, raiderSet = NS.SettingsChosen()
assert(raiderSet.record and raiderSet.rollwin and not raiderSet.rolls)
