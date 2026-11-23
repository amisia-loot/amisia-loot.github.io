-- The guild's professions (F-233, spec docs/specs/2026-11-23-gilde-berufe-uebersicht.md, D-162): the counts per
-- profession from the recipe exchange and the guild notes (Crafters.GuildProfs), the guild's lines on the
-- cards of "Alle Berufe" and their click, the dropdown Gilde (has/none), the reverse index material -> recipes
-- with "Aus Material" (text and shift-clicked link), the tooltip line on materials, the recipe wish (the bell,
-- one chat line, at most 10 an hour, an own character's recipe goes silently, the cap, the load check, the
-- block "Gesucht"), the migration of the old chip and /amisia berufe gilde.
local Pr, Cr = NS.Prof, NS.Crafters
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
-- reagents for the reverse index: copper bars in the bracers and the vest, linen in the vest and the potion
NS.PROFESSIONS.G = { [2663] = "2840:2", [3321] = "2840:4,2589:1", [2330] = "2589:2" }
-- sixty recipes nobody knows (for the cap and the chat's limit)
for i = 1, 60 do table.insert(NS.PROFESSIONS.R[171], ("%d:0:0:1:10:20:"):format(50000 + i)) end
Pr._reset()
STUB.item(2840, "Kupferbarren", 1)
STUB.item(2589, "Leinenstoff", 1)
STUB.item(2853, "Kupferarmschienen", 1)
STUB.player = "Vulo Sturmwind"
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.guild = { { name = "Vulo Sturmwind", rank = 1 }, { name = "Anna Amboss", rank = 3 },
    { name = "Bob Hammer", rank = 3, note = "Alchimie 300" }, { name = "Carla Kurz", rank = 3, note = "Schmied 120 / Bergbau" } }
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(11)
GetProfessions = function() return 1 end
GetProfessionInfo = function(i) if i == 1 then return "Schmiedekunst", 136241, 45, 150, 3, 0, 164 end end
local D = NS.DropsToday()
AmisiaDB.prof = { chars = { ["Vulo Sturmwind"] = { [164] = { rank = 45, max = 150, day = D, known = { [2663] = true } } } } }
AmisiaDB.crafters = { v = 1, src = {}, c = {
    ["Anna Amboss"] = { via = "Anna Amboss", self = true, seen = D - 4, p = { [164] = { r = 300, m = 300, l = "2663,3321" } } },
    -- heard, but no longer in the guild: counts nowhere
    ["Dora Weg"] = { via = "Dora Weg", self = true, seen = D, p = { [164] = { r = 300, m = 300, l = "1301421" } } },
} }
Cr.Changed()
NS.Data("PROFESSIONS")

---------------------------------------------------------------------------
-- The counts per profession
---------------------------------------------------------------------------
assert(Pr.TopRank() == 60, "the highest learn rank of the data")
local gp, others = Cr.GuildProfs()
local bs = gp[164]
-- Vulo (own, 45) and Anna (300) from the exchange, Carla from her note (120); Dora left the guild
assert(bs.members == 3 and bs.amisia == 2 and bs.note == 1, ("%d %d %d"):format(bs.members, bs.amisia, bs.note))
assert(bs.top == 2 and bs.best == 300 and bs.oldest == 4, ("%d %d"):format(bs.top, bs.best))
assert(gp[171].members == 1 and gp[171].note == 1 and gp[171].amisia == 0 and gp[171].top == 1, "Bob's note")
assert(gp[186].members == 1 and gp[186].note == 1 and gp[186].best == 0, "Carla's mining, without a rank")
assert(others == true, "Anna shares recipes")
assert(select(1, Cr.GuildProfs()) == gp, "kept while nothing changes")

-- the filter: someone knows it (Vulo and Anna: the bracers, the vest), nobody does (Dora does not count: she
-- left the guild, as in "Hergestellt von")
assert(#Pr.List(164, { guild = "has" }) == #Pr.List(164, { guild = true }))
local hasN, noneN = #Pr.List(164, { guild = "has" }), #Pr.List(164, { guild = "none" })
assert(hasN == 2 and noneN == 3, hasN)
assert(not Cr.Has(1301421), "Dora's recipe")
for _, e in ipairs(Pr.List(164, { guild = "none" })) do assert(not Cr.Has(e.recipe.spell), "nobody knows it") end

---------------------------------------------------------------------------
-- The cards of "Alle Berufe"
---------------------------------------------------------------------------
NS.Dispatch("berufe gilde")
local f = NS.PageFrame("professions")
local ov = f.ovView
assert(NS.CurrentPage() == "professions" and ov:IsShown(), "the overview")
local card
for _, c in ipairs(ov.cards) do
    if c:IsShown() and c.entry and c.entry.guild and c.entry.name == "Schmiedekunst" then card = c end
end
assert(card and card.gbtn:IsShown() and card:GetHeight() == NS.Theme.PROFPAGE.CARD_GUILD_H, "the card with the guild's lines")
local l1, l2 = card.glines[1]:GetText(), card.glines[2]:GetText()
assert(l1 == "Gilde: 3 (2 mit Amisia), 2 auf 60" or l1 == "Gilde: 3 (2) · 2 auf 60", l1)
assert(l2 == ("Rezepte in der Gilde: %d von 5"):format(hasN) or l2 == ("Rezepte: %d/5"):format(hasN), l2)
local tips, keepAdd = {}, GameTooltip.AddLine
GameTooltip.AddLine = function(_, t) tips[#tips + 1] = t end
card.gbtn.scripts.OnEnter(card.gbtn)
GameTooltip.AddLine = keepAdd
local tip = table.concat(tips, "\n")
assert(has(tip, "Gilde: 3 (2 mit Amisia), 2 auf 60") and has(tip, ("Rezepte in der Gilde: %d von 5"):format(hasN)), tip)
assert(has(tip, "Rezepte von 2 Mitgliedern mit Amisia; 1 weitere laut Gildennotiz (ohne Rezepte)"), tip)
assert(has(tip, "Älteste verwendete Liste: vor 4 Tagen") and has(tip, "Klick: die Rezepte, die niemand aus der Gilde kann."), tip)
-- the guild's part of the card: the profession with "Gilde: Kann niemand", its count as on the card
card.gbtn:Click()
local s = AmisiaDB.settings.professions
assert(s.view == 164 and s.guildFilter == "none" and #f.list.items == noneN, #f.list.items)
assert(f.counts:GetText() == ("%d von 5 Rezepten"):format(noneN), f.counts:GetText())
assert(f.guild.label:GetText() == ("Gilde: Kann niemand (%d)"):format(noneN), f.guild.label:GetText())
assert(f.filterBtn.dot:IsShown(), "a filter is on")
f.guild.onPick("all")
assert(s.guildFilter == nil and #f.list.items == 5)

-- nobody but the own characters shares: "Rezepte: nur deine eigenen", the tooltips say what "Kann niemand" means
local anna = AmisiaDB.crafters.c["Anna Amboss"]
AmisiaDB.crafters.c["Anna Amboss"] = nil
Cr.Changed()
NS.ShowProfessions("übersicht")
for _, c in ipairs(ov.cards) do
    if c:IsShown() and c.entry and c.entry.name == "Schmiedekunst" and c.entry.guild then card = c end
end
assert(card.glines[2]:GetText() == "Rezepte: nur deine eigenen", card.glines[2]:GetText())
tips = {}
GameTooltip.AddLine = function(_, t) tips[#tips + 1] = t end
card.gbtn.scripts.OnEnter(card.gbtn)
GameTooltip.AddLine = keepAdd
assert(has(table.concat(tips, "\n"), "\"Kann niemand\" heißt hier niemand mit Amisia"), table.concat(tips, "\n"))
AmisiaDB.crafters.c["Anna Amboss"] = anna
Cr.Changed()
-- without a guild: the cards as before
STUB.inGuild = false
NS.ShowProfessions("übersicht")
for _, c in ipairs(ov.cards) do
    assert(not (c:IsShown() and c.gbtn:IsShown()), "no guild lines")
    if c:IsShown() and not c.entry.wide then assert(c:GetHeight() == NS.Theme.PROFPAGE.CARD_H) end
end
STUB.inGuild = nil

---------------------------------------------------------------------------
-- The reverse index and "Aus Material"
---------------------------------------------------------------------------
local used = Pr.UsedIn(2840)
assert(#used == 2 and used[1].recipe.spell == 2663 and used[1].n == 2 and used[2].recipe.spell == 3321 and used[2].n == 4)
assert(#Pr.UsedIn(2589) == 2 and #Pr.UsedIn(4242) == 0 and #Pr.UsedIn(nil) == 0)
assert(table.concat(Pr.Materials("kupfer"), ",") == "2840" and table.concat(Pr.Materials(" LEINEN "), ",") == "2589")
assert(#Pr.Materials("k") == 0 and #Pr.Materials(nil) == 0, "two letters at least")
assert(table.concat(Pr.Materials(STUB.items[2589].link), ",") == "2589", "a link names its item")
local ml = Pr.MaterialList({ 2840, 2589 })
assert(#ml == 3 and ml[1].recipe.spell == 2330 and ml[2].recipe.spell == 2663 and ml[3].recipe.spell == 3321,
    "alchemy first (the data's order), each recipe once")
assert(#ml[3].mats == 2 and ml[1].mats[1][1] == 2589 and ml[1].mats[1][2] == 2, "the materials and amounts")

NS.ShowProfessions("schmied")
assert(f.findRec:IsShown() and f.findMat:IsShown() and f.findRec.on and not f.findMat.on, "the switch")
f.findMat:Click()
assert(s.find == "mat" and f.findMat.on and not f.filterBtn:IsShown(), "material mode, no filters")
assert(#f.list.items == 0 and f.empty:IsShown() and has(f.empty.text:GetText(), "Tippe den Namen eines Materials"), "what to type")
f.search:SetText("kupferbarren")
f.search.scripts.OnEnterPressed(f.search)
assert(s.matSearch == "kupferbarren" and s.search == nil, "its own text")
assert(#f.list.items == 2 and f.title:GetText() == "Aus Material", f.title:GetText())
assert(f.counts:GetText() == "2 Rezepte", f.counts:GetText())
local row = f.list.rows[2]
assert(row.sub:IsShown() and has(row.sub:GetText(), "Schmiedekunst") and has(row.sub:GetText(), "Anna Amboss (300)"), row.sub:GetText())
assert(has(row.mark:GetText(), "4x"), row.mark:GetText())
assert(f.list.rows[1].dotMe:IsShown(), "the own bracers: the yellow dot")
row:Click()
assert(f.rd.entry.recipe.spell == 3321 and f.rd.sub:GetText():find("Schmiedekunst"), "the details as usual")
-- nothing needs it
f.search:SetText("zzz")
f.search.scripts.OnEnterPressed(f.search)
assert(#f.list.items == 0 and has(f.empty.text:GetText(), "Kein Rezept braucht \"zzz\"."), f.empty.text:GetText())
-- a shift-clicked item while the search has the focus
f.search:SetFocus()
ChatFrameUtil.InsertLink(STUB.items[2589].link)
assert(s.matSearch == STUB.items[2589].link and #f.list.items == 2, #f.list.items)
assert(has(f.rank:GetText(), "Leinenstoff"), f.rank:GetText())
ChatFrameUtil.InsertLink(STUB.items[2853].link)
assert(#f.list.items == 0 and has(f.empty.text:GetText(), "Kein Rezept braucht Kupferarmschienen."), f.empty.text:GetText())
f.search:ClearFocus()
f.findRec:Click()
assert(s.find == nil and #f.list.items == 5 and f.filterBtn:IsShown(), "back to the recipes")

-- the tooltip line on materials (prof.reagentTooltip, off by default)
assert(NS.Get("prof.reagentTooltip") == false and NS.Get("prof.watchChat") == true, "the defaults")
assert(Pr.ReagentLine(2840) == "Material für 2 Rezepte (Gilde kann 2)", Pr.ReagentLine(2840))
assert(Pr.ReagentLine(4242) == nil)
STUB.inGuild = false
assert(Pr.ReagentLine(2589) == "Material für 2 Rezepte", Pr.ReagentLine(2589))
STUB.inGuild = nil
NS.PROFESSIONS.G[9999] = "4243:1"
Pr._reset()
assert(Pr.ReagentLine(4243) == "Material für 1 Rezept (Gilde kann 0)", Pr.ReagentLine(4243))

---------------------------------------------------------------------------
-- The recipe wish
---------------------------------------------------------------------------
STUB.messages = {}
local function said(part)
    local n = 0
    for _, m in ipairs(STUB.messages) do if has(m, part) then n = n + 1 end end
    return n
end
NS.ShowRecipe(164, 1301421)
local d = f.rd
assert(d.entry.recipe.spell == 1301421 and d.bell:IsShown(), "the bell: nobody of the guild knows it")
d.bell:Click()
assert(Pr.IsWatched(1301421) and AmisiaDB.prof.watch[1301421].at > 0, "wished")
assert(said("Gemerkt") == 1)
NS.ShowRecipe(164, 3321)
assert(not d.bell:IsShown(), "Anna knows the vest: no bell")
NS.ShowRecipe(164, 2663)
assert(not d.bell:IsShown(), "the own bracers: no bell")
-- the block "Gesucht" under the favourites
s.mode = "fav"
NS.ShowProfessions("schmied")
assert(f.list.items[1].head == "Gesucht" and f.list.items[2].wish and f.list.items[2].recipe.spell == 1301421, "the block")
assert(f.list.rows[2].sub:GetText():find("noch niemand"), f.list.rows[2].sub:GetText())
assert(f.counts:GetText() == "0 Favoriten · 1 gesucht", f.counts:GetText())
assert(f.selected == f.list.items[2], "the head is never chosen")
f.list.rows[1]:Click()
assert(f.selected == f.list.items[2], "a click on the head does nothing")

-- Anna learns it: her list arrives, the chat says it once, the block names her
anna.p[164].l = "2663,3321,1301421"
Cr.Changed()
STUB.tick(2)
assert(said("Anna Amboss kann jetzt") == 1, table.concat(STUB.messages, "\n"))
assert(AmisiaDB.prof.watch[1301421].hit == "Anna Amboss" and AmisiaDB.prof.watch[1301421].hitAt > 0)
Cr.Changed()
STUB.tick(2)
assert(said("kann jetzt") == 1, "once")
NS.Refresh()
assert(has(f.list.rows[2].sub:GetText(), "kann jetzt: Anna Amboss"), f.list.rows[2].sub:GetText())
-- a fulfilled wish stays until taken out: the bell takes it out
f.list.rows[2]:Click()
assert(d.bell:IsShown() and d.bell.icon.alpha ~= NS.Theme.PROFPAGE.STAR_OFF, "the bell is on")
d.bell:Click()
assert(not Pr.IsWatched(1301421), "taken out")

-- an own character learns a wished recipe: it goes silently
assert(Pr.SetWatch(9999, true))
AmisiaDB.prof.chars["Vulo Sturmwind"][164].known[9999] = true
Cr.Changed()
STUB.tick(2)
assert(not Pr.IsWatched(9999) and said("kann jetzt") == 1, "silently")
-- a spell the data does not know is no wish
assert(not Pr.SetWatch(123456, true) and not Pr.IsWatched(123456))

-- at most 10 chat lines an hour; the hits are kept all the same
for i = 1, 12 do Pr.SetWatch(50000 + i, true) end
local spells = {}
for i = 1, 12 do spells[#spells + 1] = tostring(50000 + i) end
AmisiaDB.crafters.c["Bob Hammer"] = { via = "Bob Hammer", self = true, seen = D, p = { [171] = { r = 50, m = 75, l = table.concat(spells, ",") } } }
Cr.Changed()
STUB.tick(2)
-- (Anna's line of before counts within the hour)
assert(said("kann jetzt") == 10 and said("Bob Hammer kann jetzt") == 9, said("kann jetzt"))
for i = 1, 12 do assert(AmisiaDB.prof.watch[50000 + i].hit == "Bob Hammer") end
-- the chat line can be switched off
NS.Set("prof.watchChat", false)
STUB.clock = (STUB.clock or 0) + 3700
AmisiaDB.crafters.c["Bob Hammer"].p[171].l = table.concat(spells, ",") .. ",50013"
Pr.SetWatch(50013, true)
Cr.Changed()
STUB.tick(2)
assert(AmisiaDB.prof.watch[50013].hit == "Bob Hammer" and said("kann jetzt") == 10, "no line")
NS.Set("prof.watchChat", true)

-- at most 50 wishes
for i = 14, 60 do Pr.SetWatch(50000 + i, true) end
assert(NS.Count(AmisiaDB.prof.watch) == 50 and not Pr.IsWatched(50060), NS.Count(AmisiaDB.prof.watch))
-- the load check
local root = { prof = { watch = { [1] = { at = 5 }, x = { at = 1 }, [2] = { at = -1 }, [3] = { at = 7, hit = "A|cffBob" },
    [4] = { at = 9, hit = "Ben", hitAt = 10 }, [5] = "x" } } }
NS.ProfWatchLoaded(root)
local w = root.prof.watch
assert(w[1] and w[3] and w[4] and not w.x and not w[2] and not w[5] and w[3].hit == nil and w[4].hit == "Ben" and w[4].hitAt == 10)
root = { prof = { watch = "x" } }
NS.ProfWatchLoaded(root)
assert(root.prof.watch == nil)
root = { prof = { watch = {} } }
for i = 1, 70 do root.prof.watch[i] = { at = i } end
NS.ProfWatchLoaded(root)
assert(NS.Count(root.prof.watch) == 50 and root.prof.watch[70] and not root.prof.watch[20], "the newest 50")

---------------------------------------------------------------------------
-- The old chip "Gilde" (migration step 8)
---------------------------------------------------------------------------
local db = { settings = { professions = { guild = true } } }
NS.MIGRATIONS[8](db)
assert(db.settings.professions.guildFilter == "has" and db.settings.professions.guild == nil)
NS.MIGRATIONS[8](db)
assert(db.settings.professions.guildFilter == "has", "twice without change")
db = { settings = { professions = { guild = false } } }
NS.MIGRATIONS[8](db)
assert(db.settings.professions.guildFilter == nil and db.settings.professions.guild == nil)
NS.MIGRATIONS[8]({})
