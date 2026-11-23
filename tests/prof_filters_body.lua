-- The professions page's filters (shared by test_professions_filters.lua and its English twin; the
-- caller sets PROF_FILTER_TEXTS, the texts of its locale): the two dropdowns that name their filter
-- in the field, the dropdown Gilde with its counts (F-233; the tooltip says why it finds nothing), the count
-- "N von M Rezepten", the empty state that names what each filter holds back, and "Filter
-- zurücksetzen".
local X = assert(PROF_FILTER_TEXTS, "the caller's texts")
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.class, STUB.level = "WARRIOR", 30
GetProfessions = function() return 1, nil, nil, nil, nil end
GetProfessionInfo = function(i)
    if i == 1 then return "Schmiedekunst", 136241, 45, 150, 3, 0, 164 end
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
STUB.item(3471, "Kupferkettenweste", 2)
STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)

-- nobody of the guild shares a recipe yet
local Cr = NS.Crafters
local realHas = Cr.Has
local shared = {}
Cr.Has = function(spell) return shared[spell] == true end

NS.ShowProfessions("blacksmithing")   -- the key: the same in both locales
local f = NS.PageFrame("professions")
NS.Refresh()

-- 1. the dropdowns: the client's dropdown arrow, the field names the filter and the entry
assert(f.known.arrow and f.source.arrow, "dropdowns, not chips")
assert(not f.known.UpdateChip and not f.source.UpdateChip, "no on/off chip look")
assert(f.known.label:GetText() == X.knownAll, f.known.label:GetText())
assert(f.source.label:GetText() == X.sourceAll, f.source.label:GetText())
f.source.onPick("F")
assert(f.source.label:GetText() == X.sourceFavor, f.source.label:GetText())
f.source.onPick("all")
-- the picker's entries name the values alone
local texts = {}
for _, e in ipairs(f.known.values) do texts[#texts + 1] = e.text end
assert(table.concat(texts, ",") == X.knownEntries, table.concat(texts, ","))

-- 4. "N von M Rezepten"
assert(f.counts:GetText() == X.count5of5, f.counts:GetText())
f.known.onPick("known")
assert(f.counts:GetText() == X.count2of5, f.counts:GetText())
f.known.onPick("all")

-- 3. Gilde: a dropdown like Bekannt (F-233); while nobody shares, "Kann jemand (0)" and the tooltip says why
assert(f.guild.arrow and f.guild.label:GetText() == X.guildAll, f.guild.label:GetText())
assert(f.guild.values[2].text == X.guildHas0 and f.guild.values[3].text == X.guildNone5, f.guild.values[3].text)
local lines = {}
local realAdd = GameTooltip.AddLine
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
local function tip(frame)
    lines = {}
    frame.scripts.OnEnter(frame)
    return table.concat(lines, "\n")
end
assert(has(tip(f.guild), X.guildNobody), tip(f.guild))
-- someone shares two recipes: the counts, "Kann jemand" and "Kann niemand" (the counts match the list)
shared[2663], shared[1252229] = true, true
NS.Refresh()
assert(f.guild.values[2].text == X.guildHas2 and f.guild.values[3].text == X.guildNone3, f.guild.values[2].text)
assert(not has(tip(f.guild), X.guildNobody), "the usual tooltip")
f.guild.onPick("has")
assert(AmisiaDB.settings.professions.guildFilter == "has" and #f.list.items == 2, #f.list.items)
assert(f.counts:GetText() == X.count2of5 and f.guild.label:GetText() == X.guildHasField, f.guild.label:GetText())
f.guild.onPick("none")
assert(AmisiaDB.settings.professions.guildFilter == "none" and #f.list.items == 3, #f.list.items)
for _, e in ipairs(f.list.items) do assert(not shared[e.recipe.spell], "nobody knows it") end
assert(f.counts:GetText() == X.count3of5, f.counts:GetText())
f.guild.onPick("has")
-- "Kann jemand" with nobody sharing: nothing, the filter stays
shared = {}
NS.Refresh()
assert(f.guild.label:GetText() == X.guildHas0Field and #f.list.items == 0, f.guild.label:GetText())

-- 2. the empty state names the filters that are on and what each removal gives back
f.known.onPick("known")
f.source.onPick("F")
assert(#f.list.items == 0 and f.empty:IsShown(), "three filters leave nothing")
local help = f.empty:GetText()
-- no single filter brings anything back: no "0" lines, only what all filters off would show
assert(not has(help, X.withoutGuild) and not has(help, X.withoutSource) and not has(help, X.withoutKnown), help)
assert(has(help, X.allOff), help)
assert(f.reset:IsShown(), "the reset button")
assert(f.counts:GetText() == X.count0of5, f.counts:GetText())
-- with a shared recipe the counts differ per filter
shared[2663] = true
NS.Refresh()
help = f.empty:GetText()
assert(has(help, X.withoutSource1), help)
assert(not has(help, X.withoutGuild0) and not has(help, X.allOff), "only the filters that give something back: " .. help)
-- a search counts as a filter too
f.search:SetText("kupfer")
f.search.scripts.OnEnterPressed(f.search)
assert(not has(f.empty:GetText(), X.withoutSearch) and has(f.empty:GetText(), X.withoutSource1), f.empty:GetText())
-- the button resets known, source, learnable, guild and the search, the list comes back
f.learn:Click()
f.reset:Click()
local s = AmisiaDB.settings.professions
assert(not s.known and not s.source and not s.learnable and not s.guildFilter and not s.search, "all filters off")
assert(#f.list.items == 5 and not f.empty:IsShown() and not f.reset:IsShown(), #f.list.items)
assert(f.search:GetText() == "" and f.known.label:GetText() == X.knownAll and f.source.label:GetText() == X.sourceAll)
assert(f.guild.label:GetText() == X.guildAll and not f.learn.on, "the dropdown at Alle, the chip off")

-- the layout holds with the counts and the reset button
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
-- (the filters in the menu under the search, D-82; in two rows since the dropdown Gilde, F-233)
Lay.row("filters", f.known, f.source)
Lay.row("filters 2", f.guild, f.learn)
Lay.row("search", f.search, f.filterBtn, f.counts)
Lay.fits(f.counts)
-- each dropdown is as wide as its widest entry needs: every entry fits the field
for _, p in ipairs({ f.known, f.source }) do
    local l, r = Lay.span(p.label)
    for _, e in ipairs(p.values) do
        p:SetValue(e.value)
        assert(p.label:GetStringWidth() <= r - l, ("'%s' fits %d px"):format(p.label:GetText(), r - l))
    end
    p:SetValue("all")
end
do
    local l, r = Lay.span(f.guild.label)
    for _, e in ipairs(f.guild.values) do
        f.guild:SetValue(e.value)
        assert(f.guild.label:GetStringWidth() <= r - l, ("'%s' fits"):format(f.guild.label:GetText()))
    end
    f.guild:SetValue("all")
end
f.known.onPick("known"); f.source.onPick("F"); f.guild.onPick("has")
assert(f.reset:IsShown())
Lay.inside("reset", f.reset)
Lay.column("empty", f.empty.title, f.empty.text, f.reset)
f.reset:Click()

GameTooltip.AddLine = realAdd
Cr.Has = realHas
