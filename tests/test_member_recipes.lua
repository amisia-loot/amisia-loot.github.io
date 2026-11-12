-- A member's recipes (F-182, D-114): Crafters.KnownOf reads what one crafter shares for one profession
-- (a bitset, a list, an own character, an unknown name, a bitset of another recipe index); the Berufe
-- page's member mode shows only those recipes (head "Schmiedekunst - Rezepte von Name" with the
-- member's skill, the chip "Von: Name", the counts, the other filters on top, the empty state's
-- reason), ends by its chip, "Filter zurücksetzen", another profession or tab; it follows a change of
-- the crafters; a click on a profession box of the page Mitglieder opens it (a guild note's box and a
-- right click keep the row's menu).
local Cr = NS.Crafters
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.guild = { { name = "Vulo Sturmwind", rank = 1 }, { name = "Anna Amboss", rank = 3 },
    { name = "Bob Hammer", rank = 3, note = "Alchimie 300" }, { name = "Carla Fremd", rank = 3 } }
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
GetProfessions = function() return 1 end
GetProfessionInfo = function(i) if i == 1 then return "Schmiedekunst", 136241, 45, 150, 3, 0, 164 end end
local D = NS.DropsToday()
-- the own character knows the bracers; its alt (same guild) alchemy
AmisiaDB.prof = { chars = {
    ["Vulo Sturmwind"] = { [164] = { rank = 45, max = 150, day = D, known = { [2663] = true } } },
    ["Vulo Zwei"] = { [171] = { rank = 80, max = 150, day = D, known = { [2330] = true, [1234001] = false } } } },
    guild = { ["Vulo Zwei"] = "Amisia" } }
local ix = Cr._index(164)
AmisiaDB.crafters = { v = 1, src = { ["carla fremd"] = { d = "abcdef12", f = "B" } }, c = {
    ["Anna Amboss"] = { via = "Anna Amboss", self = true, seen = D, p = { [164] = { r = 300, m = 300, h = ix.hash,
        b = Cr._toBits(ix, { [2663] = true, [3321] = true, [1301421] = true }) } } },
    -- a list with a spell the own data lacks
    ["Bob Hammer"] = { via = "Bob Hammer", self = true, seen = D - 2, p = { [164] = { r = 120, m = 150, l = "3321,1252229,77777" } } },
    -- a bitset of another recipe index
    ["Carla Fremd"] = { via = "Carla Fremd", self = true, seen = D, p = { [164] = { r = 100, m = 150, h = "deadbeef", b = "07" } } },
} }
Cr.Changed()

---------------------------------------------------------------------------
-- The reader
---------------------------------------------------------------------------
local set, n, why = Cr.KnownOf("anna amboss", 164)
assert(set and n == 3 and why == nil and set[2663] and set[3321] and set[1301421] and not set[1252229], "Anna's bitset, any case")
assert(Cr.KnownOf("Anna Amboss", 164) == set, "kept per gen")
set, n = Cr.KnownOf("Bob Hammer", 164)
assert(n == 3 and set[3321] and set[1252229] and set[77777], "Bob's list")
set, n, why = Cr.KnownOf("VULO STURMWIND", "164")
assert(n == 1 and set[2663] and why == nil, "the own character")
set, n = Cr.KnownOf("Vulo Zwei", 171)
assert(n == 1 and set[2330] and not set[1234001], "the own alt, only true entries")
set, n, why = Cr.KnownOf("Niemand", 164)
assert(set == nil and n == 0 and why == "unknown", "an unknown name")
set, n, why = Cr.KnownOf("Anna Amboss", 171)
assert(set == nil and why == "none", "a profession not shared")
assert(select(3, Cr.KnownOf("Vulo Sturmwind", 171)) == "none", "an own character without that profession")
set, n, why = Cr.KnownOf("Carla Fremd", 164)
assert(set == nil and why == "foreign", "another recipe index")
local src = AmisiaDB.crafters.src["carla fremd"]
assert(src.d == nil and src.f == "L", "Carla is asked for lists next time")
assert(select(3, Cr.KnownOf(nil, 164)) == "unknown" and select(3, Cr.KnownOf("Anna Amboss", nil)) == "unknown")
local before = Cr.KnownOf("Anna Amboss", 164)
Cr.Changed()
assert(Cr.KnownOf("Anna Amboss", 164) ~= before, "built again after a change")

-- Prof.List's option of: only these recipes, the other filters on top
assert(#NS.Prof.List(164, { of = { [3321] = true, [2663] = true } }) == 2)
assert(#NS.Prof.List(164, { of = { [3321] = true, [2663] = true }, known = "unknown" }) == 1)
assert(#NS.Prof.List(164, { of = {} }) == 0 and #NS.Prof.List(164, {}) == 5)

---------------------------------------------------------------------------
-- The page's member mode
---------------------------------------------------------------------------
NS.ShowMemberRecipes("Anna Amboss", 164)
assert(NS.CurrentPage() == "professions")
local f = NS.PageFrame("professions")
local p = AmisiaDB.settings.professions
assert(p.view == 164 and p.mode == "recipes" and p.member == nil, "the view; the member is not saved")
assert(#f.list.items == 3, #f.list.items)
assert(f.title:GetText() == "Schmiedekunst - Rezepte von Anna Amboss", f.title:GetText())
assert(f.rank:GetText() == "Skill: 300/300 · 3 Rezepte · Stand heute", f.rank:GetText())
assert(has(f.note:GetText(), "deinen eigenen Stand"), f.note:GetText())
assert(f.counts:GetText() == "3 von 3 Rezepten", f.counts:GetText())
assert(f.memberChip:IsShown() and f.memberChip.on and f.memberChip.label:GetText() == "Von: Anna Amboss", "the chip")
assert(f.back:IsShown() and f.back.label:GetText() == "Zurück zu Mitglieder", "the link back")
assert(not f.tabAll.on and not f.filterBtn.dot:IsShown(), "no tab on, the menu's dot off")
assert(has(f.hint:GetText(), "Die Rezepte, die Anna Amboss mit der Gilde teilt."), f.hint:GetText())
-- the own known mark stays the player's: the bracers are his
assert(f.list.items[1].recipe.spell == 2663 and f.list.items[1].known == true)
-- the search and the filters on top
f.search:SetText("weste")
f.search.scripts.OnEnterPressed(f.search)
assert(#f.list.items == 1 and f.list.items[1].recipe.spell == 3321, #f.list.items)
assert(f.counts:GetText() == "1 von 3 Rezepten", f.counts:GetText())
f.search:SetText("")
f.search.scripts.OnEnterPressed(f.search)
f.known.onPick("unknown")
assert(#f.list.items == 2 and f.memberChip:IsShown() and f.filterBtn.dot:IsShown(), "Bekannt on top")
f.known.onPick("all")
-- the empty state names the member's filter too: Favor alone empties Anna's list
f.source.onPick("F")
assert(#f.list.items == 0 and f.empty:IsShown() and f.reset:IsShown())
local help = f.empty.text:GetText()
assert(has(help, "Ohne \"Quelle: Händlergunst\": 3 Rezepte") and not has(help, "Von:"), (help:gsub("\n", " / ")))
f.source.onPick("all")
-- Bob's two recipes and "Bekannt": the player knows neither, without Bob's filter one shows
NS.ShowMemberRecipes("Bob Hammer", 164)
f.known.onPick("known")
help = f.empty.text:GetText()
assert(#f.list.items == 0 and has(help, "Ohne \"Von: Bob Hammer\": 1 Rezept") and has(help, "Ohne \"Bekannt\": 2 Rezepte"),
    (help:gsub("\n", " / ")))
-- "Filter zurücksetzen" ends it
f.reset:Click()
assert(#f.list.items == 5 and not f.memberChip:IsShown() and not f.back:IsShown() and p.source == nil)
assert(f.title:GetText() == "Schmiedekunst - Alle Rezepte" and f.tabAll.on, f.title:GetText())

-- the chip ends it
NS.ShowMemberRecipes("Bob Hammer", 164)
assert(#f.list.items == 2 and f.counts:GetText() == "2 von 2 Rezepten", f.counts:GetText())
assert(f.rank:GetText() == "Skill: 120/150 · 3 Rezepte · Stand vor 2 Tagen", f.rank:GetText())
f.memberChip:Click()
assert(#f.list.items == 5 and not f.memberChip:IsShown())

-- another profession, a tab, the side bar end it
NS.ShowMemberRecipes("Anna Amboss", 164)
NS.Dispatch("berufe alchimie")
assert(p.view == 171 and not f.memberChip:IsShown())
NS.Dispatch("berufe schmied")
assert(#f.list.items == 5 and not f.memberChip:IsShown(), "not back by itself")
NS.ShowMemberRecipes("Anna Amboss", 164)
f.tabAll:Click()
assert(#f.list.items == 5 and not f.memberChip:IsShown() and f.tabAll.on, "Alle Rezepte")
NS.ShowMemberRecipes("Anna Amboss", 164)
f.tabFav:Click()
f.tabAll:Click()
assert(#f.list.items == 5 and not f.memberChip:IsShown(), "Favoriten and back")

-- the list follows the crafters
NS.ShowMemberRecipes("Anna Amboss", 164)
AmisiaDB.crafters.c["Anna Amboss"].p[164].b = Cr._toBits(ix, { [2663] = true, [3321] = true, [1301421] = true, [1252229] = true })
Cr.Changed()
STUB.tick(1)
assert(#f.list.items == 4 and f.counts:GetText() == "4 von 4 Rezepten", f.counts:GetText())

-- another recipe index: the reason, not an empty list without one
NS.ShowMemberRecipes("Carla Fremd", 164)
assert(#f.list.items == 0 and f.empty:IsShown(), "nothing to show")
assert(has(f.empty.text:GetText(), "wird beim nächsten Austausch neu geholt"), f.empty.text:GetText())
assert(has(f.note:GetText(), "passt nicht zu deinen Berufsdaten"), f.note:GetText())
assert(f.reset:IsShown(), "the way back to all recipes")

-- the link back
NS.ShowMemberRecipes("Anna Amboss", 164)
f.back:Click()
assert(NS.CurrentPage() == "members")

---------------------------------------------------------------------------
-- The members page: a click on a profession box
---------------------------------------------------------------------------
local mf = NS.PageFrame("members")
local function rowOf(name)
    for _, r in ipairs(mf.list.rows) do if r.item and r.item.name == name then return r end end
end
local function boxOf(row, label)
    for _, b in ipairs(row.boxes) do if b:IsShown() and b.label:GetText() == label then return b end end
end
local anna = assert(rowOf("Anna Amboss"))
local box = assert(boxOf(anna, "Schmiedekunst"))
local lines = NS.MembersBoxClickLines(box.prof, anna.item)
assert(#lines == 2 and lines[1] == "Klick: Rezepte ansehen" and lines[2] == "Rechtsklick: Flüstern oder Einladen", lines[1])
box.scripts.OnEnter(box)
box:Click()
assert(NS.CurrentPage() == "professions" and f.memberChip:IsShown() and #f.list.items == 4, "Anna's recipes")
assert(f.title:GetText() == "Schmiedekunst - Rezepte von Anna Amboss", f.title:GetText())
-- a right click: the row's menu
NS.ShowPage("members")
anna = rowOf("Anna Amboss")
box = boxOf(anna, "Schmiedekunst")
box.scripts.OnClick(box, "RightButton")
assert(NS.CurrentPage() == "members" and AmisiaMenu and AmisiaMenu:IsShown(), "the menu")
AmisiaMenu:Hide()
-- a guild note's box: the menu, and the tooltip says so
local bob = assert(rowOf("Bob Hammer"))
local note = assert(boxOf(bob, "Alchimie"))
assert(note.prof.note)
lines = NS.MembersBoxClickLines(note.prof, bob.item)
assert(#lines == 1 and lines[1] == "Klick: Flüstern oder Einladen", lines[1])
note:Click()
assert(NS.CurrentPage() == "members" and AmisiaMenu:IsShown(), "the note's box keeps the menu")
AmisiaMenu:Hide()
-- the own character: its recipes, no menu line
local own = assert(rowOf("Vulo Sturmwind"))
local ownBox = assert(boxOf(own, "Schmiedekunst"))
lines = NS.MembersBoxClickLines(ownBox.prof, own.item)
assert(#lines == 1 and lines[1] == "Klick: Rezepte ansehen", lines[1])
ownBox:Click()
assert(NS.CurrentPage() == "professions" and f.title:GetText() == "Schmiedekunst - Rezepte von Vulo Sturmwind", f.title:GetText())
assert(#f.list.items == 1 and f.rank:GetText() == "Skill: 45/150 · 1 Rezept · Stand heute", f.rank:GetText())
