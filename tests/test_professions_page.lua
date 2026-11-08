-- The professions page: opened by the command with a profession prefix, the own professions first
-- in the picker, the rows in the difficulty colours with the upgrade mark of wearable results, the
-- detail field (steps, reagents with the own count, sources, recipe item with its requirements, the
-- crafting order note), the filters, the waypoint of a source, the camp and Merchant's Favor views,
-- and the layout at 602 x 478 for officers and raiders.
local Pr = NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.class, STUB.level = "WARRIOR", 30
GetProfessions = function() return 1, nil, nil, nil, 3 end
GetProfessionInfo = function(i)
    if i == 1 then return "Schmiedekunst", 136241, 45, 150, 3, 0, 164 end
    if i == 3 then return "Kochkunst", 133971, 10, 75, 2, 0, 185 end
end
C_TradeSkillUI = {
    IsTradeSkillLinked = function() return false end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
    GetBaseProfessionInfo = function() return { professionID = 164, skillLevel = 45, maxSkillLevel = 150 } end,
    GetAllRecipeIDs = function() return { 2663, 3321, 1252229 } end,
    GetRecipeInfo = function(id) return { recipeID = id, learned = id ~= 3321 } end,
    GetRecipeSchematic = function() return nil end,
}
C_CurrencyInfo = { GetCurrencyInfo = function() return { name = "Händlergunst", quantity = 120 } end }
STUB.item(2840, "Kupferbarren", 1)
STUB.item(3471, "Kupferkettenweste", 2)
STUB.items[3471].equipLoc = "INVTYPE_CHEST"
STUB.item(3609, "Pläne: Kupferkettenweste", 2)
STUB.item(279988, "Amboss", 1)
STUB.item(279944, "Schleifrad", 1)
STUB.bags[0] = { STUB.items[2840].link }

-- the overview (F-151, D-78): the page opens on it; its sections as cards, the side bar's marks
local function mark(key)
    for _, e in ipairs(AmisiaFrame and AmisiaFrame.navOrder or {}) do
        if e.entry.kind == "jump" and e.entry.key == key then return e end
    end
end
-- the first open of a session shows the overview, a saved profession view stays saved (D-78)
AmisiaDB.settings.professions = { view = 164 }
NS.ShowPage("professions")
local f = NS.PageFrame("professions")
local ov = f.ovView
assert(AmisiaDB.settings.professions.view == 164, "the saved view stays")
assert(ov:IsShown() and not f.list:IsShown() and not f.tabAll:IsShown() and not f.rd:IsShown(), "the overview alone")
assert(has(ov.intro:GetText(), "Wähle einen Beruf"), ov.intro:GetText())
local function secTitles()
    local out = {}
    for _, s in ipairs(ov.secs) do out[#out + 1] = s.title .. "=" .. #s.cards end
    return table.concat(out, ",")
end
-- own: blacksmithing and cooking (in the data); all: the data's three; more: camp and favor
assert(secTitles() == "Deine Berufe=2,Alle Berufe=3,Weiteres=2,Nächste Lehrer=0", secTitles())
-- the nearest trainers: the own faction's or a neutral one (the Horde's alchemist is left out), cooking
-- has none; a cell: icon, name, "Name, Zone", the map button sets the waypoint
local tl = ov.trainers
assert(tl:IsShown() and #tl.items == 1 and #tl.items[1] == 2, "one row of two cells")
local cell = tl.rows[1].cells[1]
assert(cell:IsShown() and cell.name:GetText() == "Alchimie" and cell.who:GetText() == "Lilyssia, Wald von Elwynn", cell.who:GetText())
assert(tl.rows[1].cells[2].who:GetText() == "Brikk, Wald von Elwynn" and not tl.rows[1].cells[3]:IsShown(), "neutral, no third")
cell.go:Click()
assert(NS.MapTarget() and NS.MapTarget().map == 1429 and math.abs(NS.MapTarget().x - 0.418) < 1e-6, "the waypoint")
NS.MapClearTarget()
assert(NS.Prof.NearestTrainer(185) == nil and #NS.Prof.Trainers(171) == 1, "none for cooking, one for alchemy")
local c1 = ov.cards[1]
assert(c1:IsShown() and c1.name:GetText() == "Schmiedekunst" and c1.sub:GetText() == "Rang 45/150", c1.sub:GetText())
assert(c1.icon.texture == "Interface\\Icons\\Trade_BlackSmithing", tostring(c1.icon.texture))
assert(ov.cards[3].name:GetText() == "Alchimie" and ov.cards[3].sub:GetText() == "2 Rezepte", ov.cards[3].sub:GetText())
assert(ov.cards[6].name:GetText() == "Lager" and ov.cards[7].sub:GetText() == "Du hast 120 Gunst · wie du sie bekommst",
    ov.cards[7].sub:GetText())
-- 4 cards a row at 602 px, the wide ones 2; every text fits its card
local P = NS.Theme.PROFPAGE
assert(c1:GetWidth() == math.floor((590 - 3 * P.CARD_GAP) / 4) and ov.cards[6]:GetWidth() > c1:GetWidth() * 1.4,
    c1:GetWidth() .. " / " .. ov.cards[6]:GetWidth())
for i = 1, 7 do
    local c = ov.cards[i]
    assert(c.name:GetStringWidth() <= c.name:GetWidth() and c.sub:GetStringWidth() <= c.sub:GetWidth(), c.name:GetText())
end
assert(ov.cards[2].points.TOPLEFT.y == c1.points.TOPLEFT.y and ov.cards[2].points.TOPLEFT.x > c1.points.TOPLEFT.x, "side by side")
assert(ov.child:GetHeight() > 0, "the scroll child holds the sections")
-- the marks: Übersicht (chosen), the professions with their icons from the gold line on, then Lager
-- and Händlergunst with the own favor
local mo, mb, mc, mf = mark("overview"), mark(164), mark("camp"), mark("favor")
assert(mo and mb and mc and mf and mark(171) and mark(185), "the marks")
assert(mo.entry.on and not mb.entry.on and mark(171).entry.first and not mb.entry.first and mc.entry.first and not mf.entry.first,
    "chosen and blocks")
assert(mb.entry.label == "Schmiedekunst" and mb.entry.icon.file == "Interface\\Icons\\Trade_BlackSmithing", mb.entry.label)
assert(mf.entry.count == 120 and mf.entry.label == "Händlergunst", tostring(mf.entry.count))
-- a click on a mark shows that view, the mark follows
mc.button:Click()
assert(AmisiaDB.settings.professions.view == "camp" and not ov:IsShown() and f.list:IsShown() and #f.list.items == 3, "the camp")
assert(mark("camp").entry.on and not mark("overview").entry.on, "the camp mark is chosen")
mark("overview").button:Click()
assert(ov:IsShown() and AmisiaDB.settings.professions.view == "overview", "back on the overview")
-- a click on a card opens the profession's recipe list (the route switch goes back to recipes)
AmisiaDB.settings.professions.mode = "route"
ov.cards[3]:Click()
assert(AmisiaDB.settings.professions.view == 171 and AmisiaDB.settings.professions.mode == "recipes", "alchemy's recipes")
assert(not ov:IsShown() and f.list:IsShown() and f.tabAll.on and mark(171).entry.on, "the recipe list")
mark("overview").button:Click()
ov.cards[7]:Click()
assert(AmisiaDB.settings.professions.view == "favor" and #f.list.items == 1, "the favor card")
-- a wider window: wider cards, at most CARD_COLS_MAX a row
mark("overview").button:Click()
local narrow = ov.cards[1]:GetWidth()
NS.Theme.PAGE_W_NOW = 1000
NS.W.FitWidths()
assert(ov.child:GetWidth() == 1000 - NS.Theme.SCROLL_ROOM and ov.cards[1]:GetWidth() == math.floor((988 - 5 * P.CARD_GAP) / 6),
    ov.cards[1]:GetWidth())
assert(ov.cards[1]:GetWidth() > narrow)
NS.Theme.PAGE_W_NOW = 602
NS.W.FitWidths()

-- the command opens the page on the profession: the tabs, the head band (icon, title, skill, legend,
-- the hint to open the window), the search with the filter menu (D-82)
NS.Dispatch("berufe schmied")
assert(NS.CurrentPage() == "professions", tostring(NS.CurrentPage()))
local f = NS.PageFrame("professions")
assert(f.tabAll.on and not f.tabFav.on and not f.tabFavor.on and not f.tabQueue.on and not f.tabRoute.on, "Alle Rezepte")
assert(f.title:GetText() == "Schmiedekunst - Alle Rezepte", f.title:GetText())
assert(f.rank:GetText() == "Dein Skill: 45/150 · 5 Rezepte", f.rank:GetText())
assert(f.note:GetText() == "Öffne einmal dein Schmiedekunst-Fenster, um bekannte Rezepte zu markieren.", f.note:GetText())
assert(f.legend:IsShown() and f.headIcon.icon.texture == "Interface\\Icons\\Trade_BlackSmithing", "legend and icon")
assert(#f.list.items == 5 and f.counts:GetText() == "5 von 5 Rezepten", f.counts:GetText())
assert(has(f.hint:GetText(), "Berufsfenster einmal öffnen"), f.hint:GetText())
assert(f.filterBtn:IsShown() and not f.filters:IsShown(), "the filter menu closed")
f.filterBtn:Click()
assert(f.filters:IsShown() and f.known:GetParent() == f.filters, "the filters in the menu")
f.filterBtn:Click()
assert(not f.filters:IsShown())

-- the profession window is read: known recipes are marked, the status line no longer asks
STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
NS.Refresh()
local rows = f.list.rows
assert(has(rows[1].name:GetText(), "Kupferarmschienen") and has(rows[1].name:GetText(), "(bekannt)"), rows[1].name:GetText())
assert(has(rows[1].name:GetText(), "|c" .. Pr.COLORS.green), "green at rank 45 (20/40/60)")
assert(has(rows[4].name:GetText(), "|c" .. Pr.COLORS.yellow) and not has(rows[4].name:GetText(), "bekannt"), rows[4].name:GetText())
assert(has(rows[5].name:GetText(), "|c" .. Pr.COLORS.red), "unknown and above the own rank")
assert(rows[4].rank:GetText():find("10"), "the learn rank")
-- the row's parts: the difficulty bar, the icon in its ring, the dot "kann ich", the source tag
assert(rows[1].bar.color and math.abs(rows[1].bar.color[1] - 0x40 / 255) < 1e-6, "the green bar")
assert(rows[1].dotMe:IsShown() and not rows[4].dotMe:IsShown() and not rows[1].dotGuild:IsShown(), "the dots")
assert(rows[4].iconFrame.icon.texture ~= nil and has(rows[3].mark:GetText(), "Lehrer"), rows[3].mark:GetText())
assert(f.rank:GetText() == "Dein Skill: 45/150 · 5 Rezepte, 2 bekannt" and f.note:GetText() == "", f.rank:GetText())
-- sorted by the learn rank, then by when it turns yellow (the data had 3321 second)
local order = {}
for i, it in ipairs(f.list.items) do order[i] = it.recipe.spell end
assert(table.concat(order, ",") == "2663,9999,1252229,3321,1301421", table.concat(order, ","))
assert(not has(f.hint:GetText(), "Berufsfenster"), f.hint:GetText())
-- the overview counts what the window showed as known
NS.ShowProfessions("übersicht")
-- (narrow cards: the short form, the whole line in the tooltip)
assert(f.ovView:IsShown() and f.ovView.cards[1].sub:GetText() == "45/150 · 2 bekannt", f.ovView.cards[1].sub:GetText())
assert(f.ovView.cards[4].sub:GetText() == "2/5 bekannt", f.ovView.cards[4].sub:GetText())
local tipLines, keepAdd = {}, GameTooltip.AddLine
GameTooltip.AddLine = function(_, t) tipLines[#tipLines + 1] = t end
f.ovView.cards[4].scripts.OnEnter(f.ovView.cards[4])
GameTooltip.AddLine = keepAdd
assert(tipLines[2] == "5 Rezepte · 2 bekannt", tostring(tipLines[2]))
NS.ShowProfessions("schmied")

-- the detail of the first row is shown; a click chooses another
assert(f.selected and f.selected.recipe.spell == 2663, "the first row is chosen")
assert(f.rd:IsShown(), "a recipe in the boxes")
rows[4]:Click()
assert(f.selected.recipe.spell == 3321 and AmisiaDB.settings.professions.sel["164"] == 3321, "chosen and kept")
local rd = f.rd
assert(has(rd.title:GetText(), "Kupferkettenweste"), rd.title:GetText())
assert(has(rd.sub:GetText(), "Schmiedekunst"), rd.sub:GetText())
local body = rd.info:GetText()
assert(has(body, "Skill: lernbar ab "), body)
assert(has(body, "Dein Rang 45: "), body)
assert(has(body, "Nicht bekannt (lernbar ab 10)"), body)
assert(has(body, "Gelernt bei:") and has(body, "Händler: Suppla Smith, Wald von Elwynn 13, 33"), body)
assert(has(body, "Rezept: ") and has(body, "Pläne: Kupferkettenweste") and has(body, "(Rang 10)"), body)
assert(has(body, "Handwerksauftrag für dieses Item möglich"), body)
assert(rd.reag.note:IsShown() and has(rd.reag.note:GetText(), "Reagenzien: noch unbekannt"), "the client does not answer")
assert(rd.go:IsShown(), "a source with a place")
rd.go:Click()
assert(NS.MapTarget() and NS.MapTarget().map == 1429, "the waypoint of the source")
NS.MapClearTarget()
-- reagents with the own count (bags and bank), green when enough
rows[1]:Click()
local rr = rd.reag.rows[1]
assert(rr:IsShown() and has(rr.name:GetText(), "Kupferbarren") and has(rr.have:GetText(), "1 / 2") and has(rr.have:GetText(), NS.Theme.RED),
    rr.have:GetText())
assert(not rd.reag.note:IsShown() and has(rd.info:GetText(), "Mit dem Beruf gelernt"), rd.info:GetText())
assert(not rd.go:IsShown(), "no place to go")
assert(has(rd.who:GetText(), "Vuloo (45)") and not rd.ask:IsShown(), "the own character, nobody to ask")

-- the star: a favourite of this character, the tab Favoriten lists it (all professions)
assert(rd.star.icon.alpha == NS.Theme.PROFPAGE.STAR_OFF, "off")
rd.star:Click()
assert(Pr.IsFav(2663) and rd.star.icon.alpha == 1, "on")
local who = NS.UnitFullName("player")
assert(AmisiaDB.prof.lists[who].fav[2663] == true, "saved per character")
f.tabFav:Click()
assert(f.tabFav.on and AmisiaDB.settings.professions.mode == "fav" and #f.list.items == 1 and f.title:GetText() == "Favoriten",
    f.title:GetText())
assert(not f.search:IsShown() and f.counts:GetText() == "1 Favoriten" and f.rd:IsShown(), f.counts:GetText())
rd.star:Click()
assert(#f.list.items == 0 and f.empty:IsShown(), "the empty favourites")

-- the crafting list: "+ Liste" with the count, the summed reagents with have/need and the source
f.tabAll:Click()
f.list.rows[1]:Click()
rd.count.plus:Click()
rd.count.plus:Click()
rd.add:Click()
assert(AmisiaDB.prof.lists[who].queue[1][1] == 2663 and AmisiaDB.prof.lists[who].queue[1][2] == 3, "3 crafts queued")
rd.add:Click()
assert(AmisiaDB.prof.lists[who].queue[1][2] == 6, "the same entry grows")
f.tabQueue:Click()
assert(f.tabQueue.on and f.queueView:IsShown() and not f.list:IsShown() and not f.rd:IsShown(), "the crafting list")
assert(#f.qlist.items == 1 and f.qlist.rows[1].n:GetText() == "6x" and f.title:GetText() == "Herstellliste", f.qlist.rows[1].n:GetText())
assert(#f.qneed.items == 1 and f.qneed.items[1].item == 2840 and f.qneed.items[1].need == 12, "12 copper bars")
assert(has(f.qneed.rows[1].have:GetText(), "1 / 12"), f.qneed.rows[1].have:GetText())
assert(f.counts:GetText() == "1 Rezepte, 6 Herstellungen" and f.clearQueue:IsShown(), f.counts:GetText())
f.qlist.rows[1].del:Click()
assert(#f.qlist.items == 0 and f.qempty:IsShown() and #f.qneed.items == 0, "removed")
f.tabAll:Click()

-- filters
-- the two dropdowns name their filter; a pick goes through the picker's onPick
assert(f.known.arrow and f.known.label:GetText() == "Bekannt: Alle", f.known.label:GetText())
assert(f.source.arrow and f.source.label:GetText() == "Quelle: Alle", f.source.label:GetText())
f.known.onPick("known")
assert(#f.list.items == 2 and AmisiaDB.settings.professions.known == "known", #f.list.items)
assert(f.known.label:GetText() == "Bekannt: Bekannt" and f.counts:GetText() == "2 von 5 Rezepten", f.counts:GetText())
assert(f.filterBtn.dot:IsShown(), "the funnel shows a filter is on")
f.known.onPick("unknown")
assert(#f.list.items == 3)
f.known.onPick("all")
assert(not f.filterBtn.dot:IsShown())
f.learn:Click()
assert(#f.list.items == 2 and f.learn.on, "unknown and learnable at 45: the vest and the recipe without data")
f.learn:Click()
f.source.onPick("T")
-- trainer: with the profession and the trainer list (T1); the recipe without a source is none where the
-- data has a trainer list (F-137 review, Prof.PresumedTrainer)
assert(AmisiaDB.settings.professions.source == "T" and #f.list.items == 2, #f.list.items)
f.source.onPick("V")
assert(#f.list.items == 1 and f.list.items[1].recipe.spell == 3321)
assert(f.source.label:GetText() == "Quelle: Händler", f.source.label:GetText())
f.source.onPick("all")
assert(AmisiaDB.settings.professions.source == "all" and #f.list.items == 5)
f.search:SetText("weste")
f.search.scripts.OnEnterPressed(f.search)
assert(#f.list.items == 1 and AmisiaDB.settings.professions.search == "weste", #f.list.items)
f.search:SetText("")
f.search.scripts.OnEnterPressed(f.search)
assert(#f.list.items == 5)

-- another profession through its mark in the side bar
mark(171).button:Click()
assert(f.title:GetText() == "Alchimie - Alle Rezepte" and #f.list.items == 2 and has(f.rank:GetText(), "Nicht erlernt"), f.rank:GetText())

-- the camp view
NS.Dispatch("berufe lager")
assert(f.title:GetText() == "Lager" and #f.list.items == 3 and not f.legend:IsShown(), f.title:GetText())
assert(not f.known:IsShown() and not f.search:IsShown() and not f.filterBtn:IsShown(), "the recipe filters hide")
assert(f.rd:IsShown(), "the camp object in the boxes too")
assert(not f.tabAll.on and not f.tabFavor.on, "no tab for the camp")
assert(has(rows[1].mark:GetText(), "3 Pl."), "a campfire's places")
local d = f.rd
-- the description is not loaded yet on the first ask: a placeholder, the client is asked to load
-- the spell (once), and SPELL_DATA_LOAD_RESULT fills the text in
local loaded, asked, realDesc = false, {}, C_Spell.GetSpellDescription
C_Spell.GetSpellDescription = function(id) if id == 1307175 and not loaded then return "" end return realDesc(id) end
C_Spell.IsSpellDataCached = function(id) return id ~= 1307175 or loaded end
C_Spell.RequestLoadSpellData = function(id) asked[#asked + 1] = id end
rows[3]:Click()
body = d.info:GetText()
assert(has(body, "Beschreibung lädt") and #asked == 1 and asked[1] == 1307175, body)
NS.Refresh()
assert(#asked == 1, "asked once: " .. #asked)
loaded = true
STUB.fire("SPELL_DATA_LOAD_RESULT", 1307175, true)
STUB.tick(1)
body = d.info:GetText()
assert(has(body, "Stellt einen Amboss auf."), "the client's description once loaded: " .. body)
C_Spell.GetSpellDescription, C_Spell.IsSpellDataCached, C_Spell.RequestLoadSpellData = realDesc, nil, nil
assert(has(body, "Ersetzt Schleifrad und behält dessen Wirkung."), body)
assert(has(body, "ab Rang 140 (dein Rang 45)"), body)
-- without its recipe in the data: Details alone, no star, no "+ Liste", no reagents, no guild
assert(has(d.sub:GetText(), "Lager") and not d.star:IsShown() and not d.add:IsShown() and not d.reag:IsShown()
    and not d.guild:IsShown(), d.sub:GetText())
-- with its recipe: the steps and the source under the camp lines, the reagents, the star, "+ Liste"
rows[1]:Click()
body = d.info:GetText()
assert(d.star:IsShown() and d.add:IsShown() and d.reag:IsShown() and d.guild:IsShown(), "the camp recipe's boxes")
assert(has(body, "Lagerfeuer mit 3 Plätzen") and has(body, "Gelernt bei:"), body)
assert(has(f.counts:GetText(), "3 Lagerobjekte") and has(f.hint:GetText(), "Lagerfeuer"), f.counts:GetText())

-- the Merchant's Favor view: its tab, the recipe in the boxes
f.tabFavor:Click()
assert(f.tabFavor.on and f.title:GetText() == "Händlergunst" and #f.list.items == 1, #f.list.items)
assert(AmisiaDB.settings.professions.view == "favor" and AmisiaDB.settings.professions.skill == 171, "the profession kept")
assert(has(f.counts:GetText(), "Händlergunst: 120") and has(f.counts:GetText(), "1 Zertifizierungen"), f.counts:GetText())
assert(has(f.hint:GetText(), "Händler: Hilda"), f.hint:GetText())
assert(has(rows[1].rank:GetText(), "45"), "the price")
assert(f.rd:IsShown() and d.star:IsShown() and d.reag:IsShown(), "the favor recipe in the boxes")
body = d.info:GetText()
assert(has(body, "Händlergunst: 45 Gunst, Neutral (Allianz)"), body)
f.tabAll:Click()
assert(AmisiaDB.settings.professions.view == 171 and f.tabAll.on, "back to the profession")

-- layout, officer and raider
NS.ShowProfessions("schmied")
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowProfessions()
    NS.Refresh()
    L.row(view .. " tabs", f.tabAll, f.tabFav, f.tabFavor, f.tabQueue, f.tabRoute)
    L.row(view .. " search", f.search, f.filterBtn, f.counts)
    L.row(view .. " body", f.list, f.rd)
    L.row(view .. " row", rows[1].iconFrame, rows[1].name, rows[1].mark, rows[1].rank)
    L.inside(view .. " detail", f.rd)
    L.column(view .. " page", f.tabAll, f.headBlock, f.search, f.list)
    assert(f.hint.isHelp and f.data.isHelp)
    L.fits(f.counts)
    for _, fs in ipairs({ f.rank, f.title }) do
        local l, r = L.span(fs)
        assert(fs:GetStringWidth() <= r - l, fs:GetText())
    end
end
NS.Reset("ui.view")
