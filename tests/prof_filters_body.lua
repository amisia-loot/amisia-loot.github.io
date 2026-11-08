-- The professions page's filters (shared by test_professions_filters.lua and its English twin; the
-- caller sets PROF_FILTER_TEXTS, the texts of its locale): the two dropdowns that name their filter
-- in the field, the chip Gilde with its count (greyed at 0, the tooltip that says why), the count
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

-- 3. Gilde (0): greyed and off it can't be turned on; the tooltip says why
assert(f.guild.label:GetText() == X.guild0, f.guild.label:GetText())
assert(f.guild.dim and not f.guild:IsEnabled(), "greyed while nobody shares")
local lines = {}
local realAdd = GameTooltip.AddLine
GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
local function tip(frame)
    lines = {}
    frame.scripts.OnEnter(frame)
    return table.concat(lines, "\n")
end
assert(has(tip(f.guild), X.guildNobody), tip(f.guild))
-- someone shares two recipes: the count, the chip works
shared[2663], shared[1252229] = true, true
NS.Refresh()
assert(f.guild.label:GetText() == X.guild2 and f.guild:IsEnabled() and not f.guild.dim, f.guild.label:GetText())
assert(not has(tip(f.guild), X.guildNobody), "the usual tooltip")
f.guild:Click()
assert(AmisiaDB.settings.professions.guild and #f.list.items == 2, #f.list.items)
assert(f.counts:GetText() == X.count2of5, f.counts:GetText())
-- on with nobody sharing: greyed, still clickable to turn it off
shared = {}
NS.Refresh()
assert(f.guild.label:GetText() == X.guild0 and f.guild.dim and f.guild:IsEnabled() and f.guild.on, "on, greyed, clickable")
assert(#f.list.items == 0)

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
assert(not s.known and not s.source and not s.learnable and not s.guild and not s.search, "all filters off")
assert(#f.list.items == 5 and not f.empty:IsShown() and not f.reset:IsShown(), #f.list.items)
assert(f.search:GetText() == "" and f.known.label:GetText() == X.knownAll and f.source.label:GetText() == X.sourceAll)
assert(not f.guild.on and not f.learn.on, "the chips off")

-- the layout holds with the counts and the reset button
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
Lay.row("filters", f.known, f.source, f.learn, f.guild, f.counts)
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
assert(f.guild.label:GetStringWidth() + 2 * NS.Theme.CHIP_PAD <= f.guild:GetWidth(), "the guild chip fits its count")
f.known.onPick("known"); f.source.onPick("F"); f.guild:Click()
assert(f.reset:IsShown())
Lay.inside("reset", f.reset)
Lay.column("empty", f.empty.title, f.empty.text, f.reset)
f.reset:Click()

GameTooltip.AddLine = realAdd
Cr.Has = realHas
