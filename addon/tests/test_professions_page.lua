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

-- the command opens the page on the profession
NS.Dispatch("berufe schmied")
assert(NS.CurrentPage() == "professions", tostring(NS.CurrentPage()))
local f = NS.ProfessionsPageFrame()
assert(f.prof.label:GetText() == "Schmiedekunst (45/150)", f.prof.label:GetText())
local values = {}
for _, v in ipairs(f.prof.values) do values[#values + 1] = tostring(v.value) end
assert(table.concat(values, ",") == "164,185,171,camp,favor", table.concat(values, ","))
assert(has(f.rank:GetText(), "Dein Rang: 45 / 150"), f.rank:GetText())
assert(#f.list.items == 5 and has(f.counts:GetText(), "Berufsfenster öffnen"), f.counts:GetText())

-- the profession window is read: known recipes are marked, the status line no longer asks
STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
NS.Refresh()
local rows = f.list.rows
assert(has(rows[1].name:GetText(), "Kupferarmschienen") and has(rows[1].name:GetText(), "(bekannt)"), rows[1].name:GetText())
assert(has(rows[1].name:GetText(), "|c" .. Pr.COLORS.green), "green at rank 45 (20/40/60)")
assert(has(rows[2].name:GetText(), "|c" .. Pr.COLORS.yellow) and not has(rows[2].name:GetText(), "bekannt"), rows[2].name:GetText())
assert(has(rows[4].name:GetText(), "|c" .. Pr.COLORS.red), "unknown and above the own rank")
assert(rows[2].rank:GetText():find("10"), "the learn rank")
assert(not has(f.counts:GetText(), "Berufsfenster"), f.counts:GetText())

-- the detail of the first row is shown; a click chooses another
assert(f.selected and f.selected.recipe.spell == 2663, "the first row is chosen")
rows[2]:Click()
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
f.known:Click()                      -- Alle -> Bekannt
assert(#f.list.items == 2 and AmisiaDB.settings.professions.known == "known", #f.list.items)
f.known:Click()                      -- Bekannt -> Unbekannt
assert(#f.list.items == 3)
f.known:Click()                      -- back to all
f.learn:Click()
assert(#f.list.items == 2 and f.learn.on, "unknown and learnable at 45: the vest and the recipe without data")
f.learn:Click()
f.source:Click()                     -- Lehrer
assert(AmisiaDB.settings.professions.source == "T" and #f.list.items == 3, #f.list.items)
f.source:Click()                     -- Händler
assert(#f.list.items == 1 and f.list.items[1].recipe.spell == 3321)
for _ = 1, 4 do f.source:Click() end -- back to all
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
    L.column(view .. " page", f.prof, f.known, f.list, f.hint, f.data)
    for _, fs in ipairs({ f.counts, f.hint, f.data, f.rank }) do L.fits(fs) end
end
NS.Reset("ui.view")
