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
assert(ov:IsShown() and not f.list:IsShown() and not f.prof:IsShown() and not f.detail:IsShown(), "the overview alone")
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
assert(not ov:IsShown() and f.list:IsShown() and f.prof:IsShown() and mark(171).entry.on, "the recipe list")
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

-- the command opens the page on the profession
NS.Dispatch("berufe schmied")
assert(NS.CurrentPage() == "professions", tostring(NS.CurrentPage()))
local f = NS.PageFrame("professions")
assert(f.prof.label:GetText() == "Schmiedekunst (45/150)", f.prof.label:GetText())
local values = {}
for _, v in ipairs(f.prof.values) do values[#values + 1] = tostring(v.value) end
assert(table.concat(values, ",") == "164,185,171,camp,favor", table.concat(values, ","))
assert(has(f.rank:GetText(), "Dein Rang: 45 / 150"), f.rank:GetText())
assert(#f.list.items == 5 and f.counts:GetText() == "5 von 5 Rezepten", f.counts:GetText())
assert(has(f.hint:GetText(), "Berufsfenster einmal öffnen"), f.hint:GetText())

-- the profession window is read: known recipes are marked, the status line no longer asks
STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
NS.Refresh()
local rows = f.list.rows
assert(has(rows[1].name:GetText(), "Kupferarmschienen") and has(rows[1].name:GetText(), "(bekannt)"), rows[1].name:GetText())
assert(has(rows[1].name:GetText(), "|c" .. Pr.COLORS.green), "green at rank 45 (20/40/60)")
assert(has(rows[4].name:GetText(), "|c" .. Pr.COLORS.yellow) and not has(rows[4].name:GetText(), "bekannt"), rows[4].name:GetText())
assert(has(rows[5].name:GetText(), "|c" .. Pr.COLORS.red), "unknown and above the own rank")
assert(rows[4].rank:GetText():find("10"), "the learn rank")
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
rows[4]:Click()
assert(f.selected.recipe.spell == 3321 and AmisiaDB.settings.professions.sel["164"] == 3321, "chosen and kept")
local d = f.detail
assert(has(d.title:GetText(), "Kupferkettenweste"), d.title:GetText())
local body = d.body.fs:GetText()
assert(has(body, "Schmiedekunst · Fertigkeit"), body)
assert(has(body, "Dein Rang 45: "), body)
assert(has(body, "Nicht bekannt (lernbar ab 10)"), body)
assert(has(body, "Reagenzien: noch unbekannt"), "the client does not answer")
assert(has(body, "Händler: Suppla Smith, Wald von Elwynn 13, 33"), body)
assert(has(body, "Rezept: ") and has(body, "Pläne: Kupferkettenweste") and has(body, "(Rang 10)"), body)
assert(has(body, "Handwerksauftrag für dieses Item möglich"), body)
assert(d.go:IsEnabled(), "a source with a place")
d.go:Click()
assert(NS.MapTarget() and NS.MapTarget().map == 1429, "the waypoint of the source")
NS.MapClearTarget()
-- reagents with the own count
rows[1]:Click()
body = d.body.fs:GetText()
assert(has(body, "2x ") and has(body, "Kupferbarren") and has(body, "(1)"), body)
assert(has(body, "Mit dem Beruf gelernt"), body)
assert(not d.go:IsEnabled(), "no place to go")

-- filters
-- the two dropdowns name their filter; a pick goes through the picker's onPick
assert(f.known.arrow and f.known.label:GetText() == "Bekannt: Alle", f.known.label:GetText())
assert(f.source.arrow and f.source.label:GetText() == "Quelle: Alle", f.source.label:GetText())
f.known.onPick("known")
assert(#f.list.items == 2 and AmisiaDB.settings.professions.known == "known", #f.list.items)
assert(f.known.label:GetText() == "Bekannt: Bekannt" and f.counts:GetText() == "2 von 5 Rezepten", f.counts:GetText())
f.known.onPick("unknown")
assert(#f.list.items == 3)
f.known.onPick("all")
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

-- another profession through the picker
f.prof.onPick(171)
assert(f.prof.label:GetText() == "Alchimie" and #f.list.items == 2 and has(f.rank:GetText(), "nicht erlernt"), f.rank:GetText())

-- the camp view
NS.Dispatch("berufe lager")
assert(f.prof.label:GetText() == "Lager (Camping)" and #f.list.items == 3, f.prof.label:GetText())
assert(not f.known:IsShown() and not f.search:IsShown(), "the recipe filters hide")
assert(has(rows[1].mark:GetText(), "3 Pl."), "a campfire's places")
-- the description is not loaded yet on the first ask: a placeholder, the client is asked to load
-- the spell (once), and SPELL_DATA_LOAD_RESULT fills the text in
local loaded, asked, realDesc = false, {}, C_Spell.GetSpellDescription
C_Spell.GetSpellDescription = function(id) if id == 1307175 and not loaded then return "" end return realDesc(id) end
C_Spell.IsSpellDataCached = function(id) return id ~= 1307175 or loaded end
C_Spell.RequestLoadSpellData = function(id) asked[#asked + 1] = id end
rows[3]:Click()
body = d.body.fs:GetText()
assert(has(body, "Beschreibung lädt") and #asked == 1 and asked[1] == 1307175, body)
NS.Refresh()
assert(#asked == 1, "asked once: " .. #asked)
loaded = true
STUB.fire("SPELL_DATA_LOAD_RESULT", 1307175, true)
STUB.tick(1)
body = d.body.fs:GetText()
assert(has(body, "Stellt einen Amboss auf."), "the client's description once loaded: " .. body)
C_Spell.GetSpellDescription, C_Spell.IsSpellDataCached, C_Spell.RequestLoadSpellData = realDesc, nil, nil
assert(has(body, "Ersetzt Schleifrad und behält dessen Wirkung."), body)
assert(has(body, "ab Rang 140 (dein Rang 45)"), body)
assert(has(f.counts:GetText(), "3 Lagerobjekte") and has(f.hint:GetText(), "Lagerfeuer"), f.counts:GetText())

-- the Merchant's Favor view
NS.ShowProfessions("gunst")
assert(f.prof.label:GetText() == "Händlergunst" and #f.list.items == 1, #f.list.items)
assert(has(f.counts:GetText(), "Händlergunst: 120") and has(f.counts:GetText(), "1 Zertifizierungen"), f.counts:GetText())
assert(has(f.hint:GetText(), "Händler: Hilda"), f.hint:GetText())
assert(has(rows[1].rank:GetText(), "45"), "the price")
body = d.body.fs:GetText()
assert(has(body, "Händlergunst: 45 Gunst, Neutral (Allianz)"), body)

-- layout, officer and raider
NS.ShowProfessions("schmied")
local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
for _, view in ipairs({ "officer", "raider" }) do
    NS.Set("ui.view", view)
    NS.ShowProfessions()
    NS.Refresh()
    L.row(view .. " head", f.prof, f.search, f.rank)
    L.row(view .. " filters", f.known, f.source, f.learn, f.guild, f.counts)
    L.row(view .. " buttons", f.detail.ask, f.detail.go)
    L.row(view .. " body", f.list, f.list.bar, f.detail)
    L.row(view .. " row", rows[1].name, rows[1].mark, rows[1].rank)
    L.inside(view .. " detail", f.detail)
    L.column(view .. " page", f.prof, f.known, f.list)
    assert(f.hint.isHelp and f.data.isHelp)
    for _, fs in ipairs({ f.counts, f.rank }) do L.fits(fs) end
end
NS.Reset("ui.view")
