-- The main window's search, checked 2026-11-28 (user: "die suchleiste ganz genau checken das man alles easy
-- findet"): case and umlauts do not matter ("ausrustung" finds "Ausrüstung"), professions by name ("schmied"
-- opens Schmiedekunst), bosses by name with their dungeon (a click opens the dungeon at the boss), dungeon
-- quests by title (a click opens the quest's path), the new page keywords ("lfg", "vorlagen", "version"), and
-- Enter in the box runs the first hit.
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

-- umlauts: typed with or without them
local norm = NS.SearchIndex.Norm
assert(norm("Ausrüstung") == "ausrustung" and norm("ÜBER") == "uber" and norm("Straße") == "strasse", norm("ÜBER"))
for _, q in ipairs({ "ausrustung", "ausrüstung", "AUSRÜSTUNG" }) do
    assert(find(group(NS.Search(q), "pages"), "Ausrüstung"), "the page Ausrüstung by " .. q)
end
assert(find(group(NS.Search("ubersicht"), "pages"), "Übersicht"), "Übersicht without the umlaut")

-- professions: from three characters, a click opens it on the page Berufe
assert(group(NS.Search("sc"), "professions") == nil, "two characters: no professions")
local g = group(NS.Search("schmied"), "professions")
assert(g and find(g, "Schmiedekunst"), "Schmiedekunst")
assert(has(find(g, "Schmiedekunst").tip, "Berufe"))
AmisiaDB.settings.professions = { view = 171, sel = {} }
find(g, "Schmiedekunst").run()
assert(NS.CurrentPage() == "professions" and AmisiaDB.settings.professions.view == 164, "opens the profession")

-- keywords of the pages added 2026-11-28
assert(find(group(NS.Search("lfg"), "pages"), "Aufrufe"), "lfg: Aufrufe")
assert(find(group(NS.Search("vorlagen"), "pages"), "Ausrüstungsplaner") or not NS.Visible(NS.Panel("planner")), "vorlagen: the planner")
assert(find(group(NS.Search("version"), "pages"), "Amisia-Versionen"), "version: Amisia-Versionen")

local dpanel = NS.Panel("dungeons")
if NS.Visible(dpanel) then
    -- bosses: the facts' English names, each with its dungeon; a click opens it at the boss
    g = group(NS.Search("vancleef"), "bosses")
    local b = find(g, "Edwin VanCleef")
    assert(b and has(b.tip, "Boss in"), "Edwin VanCleef with its dungeon")
    b.run()
    assert(NS.CurrentPage() == "dungeons" and AmisiaDB.settings.bis.dungeon == "deadmines" and AmisiaDB.settings.bis.dpart == "bosses",
        "opens the Deadmines at the bosses")
    -- quests: by title, from three characters; a click opens the quest's path
    assert(group(NS.Search("de"), "quests") == nil, "two characters: no quests")
    g = group(NS.Search("defias brother"), "quests")
    local q = g and g.hits[1]
    assert(q and has(q.text, "Defias Brotherhood"), q and q.text)
    q.run()
    assert(NS.CurrentPage() == "dungeons" and AmisiaDB.settings.bis.dungeon == "deadmines" and AmisiaDB.settings.bis.dpart == "quests",
        "opens the quest's dungeon at its quests")
else
    assert(group(NS.Search("vancleef"), "bosses") == nil and group(NS.Search("defias"), "quests") == nil, "no hits without the page")
end

-- Enter runs the first hit and empties the box
NS.ShowPage("overview")
local F = AmisiaFrame
F.search:SetText("duelle")
F.search:GetScript("OnEnterPressed")(F.search)
assert(NS.CurrentPage() == "duels" and F.search:GetText() == "", "Enter opens the first hit: " .. tostring(NS.CurrentPage()))
-- nothing found: Enter only leaves the box
F.search:SetText("zzqqxx")
F.search:GetScript("OnEnterPressed")(F.search)
assert(NS.CurrentPage() == "duels" and F.search:GetText() == "zzqqxx", "no hit: nothing runs")
print("search find ok")
