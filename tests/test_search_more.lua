-- The main window's search, the groups added 2026-10-17 (user: "die Suche für allgemein und z. B.
-- Rezepte checken, dass alles gefunden werden kann"): a settings section by its own name or by its
-- tab's ("Allgemein"), a click opens the section; recipes by the client's spell name from three
-- characters on, a click opens the page Berufe at the recipe (its profession, the name in the search,
-- the filters off, the recipe chosen); dungeons and raids by name, a click opens the page Dungeons.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function group(groups, key)
    for _, g in ipairs(groups) do if g.key == key then return g end end
end
local function find(g, text)
    for _, h in ipairs(g and g.hits or {}) do if h.text == text then return h end end
end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.officer = true
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.SearchIndex._reset()

-- the tab "Allgemein": its sections (Oberfläche, Werkzeuge, ...) even though no setting is called so
local g = group(NS.Search("allgemein"), "settings")
assert(g and find(g, NS.L["Oberfläche"]), "a section of the tab Allgemein")
local ui = find(g, NS.L["Oberfläche"])
assert(has(ui.tip, "Allgemein"), ui.tip)
ui.run()
assert(NS.CurrentPage() == "settings" and AmisiaDB.settings.window.section == "ui", "opens the section")
-- a section by its own name
g = group(NS.Search("duelle"), "settings")
assert(g and find(g, "Duelle"), "the section Duelle")
assert(find(group(NS.Search("duelle"), "pages"), "Duelle"), "and the page")

-- recipes: not under three characters, then by the client's name
assert(group(NS.Search("ku"), "recipes") == nil, "two characters: no recipes")
g = group(NS.Search("kupfer"), "recipes")
assert(g and #g.hits == 3, g and #g.hits)
assert(g.hits[1].text == "Kupferarmschienen" and g.hits[2].text == "Kupferkettenweste", "the start of the name first, then the name")
local hit = find(g, "Kupferkettenweste")
assert(has(hit.tip, "Schmiedekunst") and has(hit.tip, "10"), hit.tip)
AmisiaDB.settings.professions = { view = 171, known = "known", learnable = true, sel = {} }
hit.run()
local st = AmisiaDB.settings.professions
assert(NS.CurrentPage() == "professions" and st.view == 164 and st.search == "Kupferkettenweste" and st.known == nil
    and st.learnable == nil and st.sel["164"] == 3321, "the recipe on the page Berufe")
local pf = NS.ProfessionsPageFrame()
assert(pf.selected and pf.selected.recipe and pf.selected.recipe.spell == 3321, "the recipe chosen")
-- "heiltrank" finds the alchemy recipe
assert(find(group(NS.Search("heiltrank"), "recipes"), "Schwacher Heiltrank"), "an alchemy recipe")

-- dungeons, when the page shows
local dpanel = NS.Panel("dungeons")
if NS.Visible(dpanel) then
    local facts = NS.Dungeons.Facts()
    local e = facts[1]
    local name = NS.Dungeons.Name(e)
    g = group(NS.Search(name:sub(1, 6)), "dungeons")
    assert(g and find(g, name), "a dungeon by name: " .. name)
    find(g, name).run()
    assert(NS.CurrentPage() == "dungeons" and AmisiaDB.settings.bis.dungeon == e.key, "opens it")
else
    assert(group(NS.Search("höhlen"), "dungeons") == nil, "no dungeon hits without the page")
end
print("search more ok")
