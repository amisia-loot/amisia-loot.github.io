-- "Neu in Amisia" (UI/WhatsNew.lua, F-236, D-168): a first install shows nothing and learns the version; after an
-- update the news of the versions since the one seen show once, newest first, after entering the world, not in
-- combat or a boss fight (they wait for its end); seenVersion is set then; ui.whatsNew off: nothing, marked seen;
-- an install from before the key shows the running version's news; bad saved values are dropped; the About page's
-- link "Neuigkeiten" and /amisia neu open it any time; the shipped data loads.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local WN = NS._whatsNew
local function win() return WN.frame() end
local function shown() return win() ~= nil and win():IsShown() end
local function text() return win().text.fs:GetText() end
local function enter()
    if win() then win():Hide() end
    WN.reset()
    STUB.fire("PLAYER_ENTERING_WORLD")
    STUB.tick(7)
end

---------------------------------------------------------------------------
-- the shipped data loads; the test's run is a first install: nothing shown, the version learned
---------------------------------------------------------------------------
local shipped = NS.Data("WHATSNEW")
assert(type(shipped) == "table" and type(shipped.versions) == "table" and #shipped.versions >= 1, "Data/WhatsNew.lua")
for _, e in ipairs(shipped.versions) do
    assert(e[1]:match("^%d+%.%d+%.%d+$") and #e[2] >= 1, "a version with its items")
    for _, it in ipairs(e[2]) do assert(it[1]:match("^F%-%d+$") and it[2] ~= "" and it[3] ~= "") end
end
assert(NS.NEW_INSTALL == true and AmisiaDB.seenVersion == NS.VERSION, "a first install learns the version")
enter()
assert(not shown(), "a first install shows nothing")

---------------------------------------------------------------------------
-- an update: the news since the version seen, newest first
---------------------------------------------------------------------------
NS.VERSION = "2.110.0"
NS.WHATSNEW = { version = "2.110.0", versions = {
    { "2.111.0", { { "F-999", "Zukunft", "Future" } } },
    { "2.110.0", { { "F-236", "Was ist neu nach einem Update", "What's new after an update" },
                   { "F-235", "Lauf-Gewinne", "Run gains" } } },
    { "2.109.0", { { "F-234", "Alles mit Klicks", "Everything by clicks" } } },
    { "2.108.0", { { "F-200", "Einstellungen", "Settings" } } },
} }
local root = { seenVersion = "2.108.0" }
NS.WhatsNewLoaded(root)
assert(WN.since() == "2.108.0")
local items = NS.WhatsNewItems("2.108.0")
assert(#items == 2 and items[1].v == "2.110.0" and items[2].v == "2.109.0", "after the seen one, up to the running one")
assert(items[1].list[1] == "Was ist neu nach einem Update" and items[1].list[2] == "Lauf-Gewinne")
assert(#NS.WhatsNewItems(nil) == 3 and #NS.WhatsNewItems(false) == 1, "all; the running version's only")

-- in combat: it waits, nothing marked
STUB.combat = true
enter()
assert(not shown() and WN.waiting() and root.seenVersion == "2.108.0", "waits for the end of combat")
STUB.combat = false
STUB.encounter = true
STUB.fire("PLAYER_REGEN_ENABLED")
assert(not shown() and WN.waiting(), "a boss fight still runs")
STUB.encounter = false
STUB.fire("ENCOUNTER_END")
assert(shown() and not WN.waiting(), "shown once both are over")
assert(win():GetTitleText():GetText() == "Neu in Amisia 2.110.0", win():GetTitleText():GetText())
local t = text()
assert(has(t, "Version 2.110.0") and has(t, "· Was ist neu nach einem Update") and has(t, "Version 2.109.0"), t)
assert(t:find("2.110.0", 1, true) < t:find("2.109.0", 1, true), "newest first")
assert(not has(t, "Zukunft") and not has(t, "Einstellungen"), "neither newer nor seen versions")
assert(root.seenVersion == "2.110.0", "marked seen")
assert(win().close:GetText() == "Schließen" and win().settings.label:GetText() == "Einstellungen")
win().close:Click()
assert(not shown())

-- the next login: nothing
NS.WhatsNewLoaded(root)
enter()
assert(not shown() and WN.since() == nil, "once")

-- one version: no version heading
root.seenVersion = "2.109.0"
NS.WhatsNewLoaded(root)
enter()
assert(shown() and not has(text(), "Version 2.110.0") and has(text(), "· Lauf-Gewinne"), text())

---------------------------------------------------------------------------
-- switched off: nothing shown, marked seen
---------------------------------------------------------------------------
NS.Set("ui.whatsNew", false)
root.seenVersion = "2.108.0"
NS.WhatsNewLoaded(root)
enter()
assert(not shown() and root.seenVersion == "2.110.0", "off: marked seen")
NS.Set("ui.whatsNew", true)

---------------------------------------------------------------------------
-- an install from before the key: the running version's news; bad saved values dropped
---------------------------------------------------------------------------
NS.NEW_INSTALL = false
root = { seenVersion = "zwei" }
NS.WhatsNewLoaded(root)
assert(root.seenVersion == nil and WN.since() == false, "dropped; the running version's news")
enter()
assert(shown() and has(text(), "Was ist neu") and not has(text(), "Alles mit Klicks"), text())
assert(root.seenVersion == "2.110.0")
-- no news for the versions in between: nothing, marked seen
root.seenVersion = "2.109.5"
NS.WhatsNewLoaded(root)
NS.WHATSNEW = { version = "2.110.0", versions = { { "2.109.0", { { "F-234", "Alt", "Old" } } } } }
enter()
assert(not shown() and root.seenVersion == "2.110.0", "nothing new: marked seen")
-- a newer seen version (a downgrade): nothing, kept
root.seenVersion = "2.111.0"
NS.WhatsNewLoaded(root)
assert(WN.since() == nil and root.seenVersion == "2.111.0")

---------------------------------------------------------------------------
-- any time: the About page's link and /amisia neu (en news) show every version in the file
---------------------------------------------------------------------------
NS.WHATSNEW = { version = "2.110.0", versions = {
    { "2.110.0", { { "F-236", "Was ist neu nach einem Update", "What's new after an update" } } },
    { "2.109.0", { { "F-234", "Alles mit Klicks", "Everything by clicks" } } },
} }
NS.ShowPage("about")
local about = NS.PageFrame("about")
assert(about.news.label:GetText() == "Neuigkeiten", about.news.label:GetText())
about.news:Click()
assert(shown() and has(text(), "Alles mit Klicks") and has(text(), "Version 2.109.0"), "the About page's link")
win():Hide()
NS.Dispatch("neu")
assert(shown(), "/amisia neu")
win():Hide()
NS.Dispatch("news")
assert(shown(), "/amisia news")
win():Hide()
-- no data: a quiet line
NS.WHATSNEW = { version = "2.110.0", versions = {} }
NS.Dispatch("neu")
assert(shown() and has(text(), "Keine Neuigkeiten gespeichert."), text())
win():Hide()

---------------------------------------------------------------------------
-- the setting stands in Oberfläche
---------------------------------------------------------------------------
local found
for _, sec in ipairs(NS.schema) do
    for _, it in ipairs(sec.items) do if it.key == "ui.whatsNew" then found = sec.key end end
end
assert(found == "ui" and NS.Get("ui.whatsNew") == true)
