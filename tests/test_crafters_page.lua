-- Guild crafters on the professions page (Crafters.lua, UI/Pages/Professions.lua): "Hergestellt von"
-- in the detail with online crafters first, the filter "Gilde" (only what someone of the guild knows),
-- the button that asks a crafter by whisper (online first, never an own character), and the page
-- follows a change of the crafters.
local Cr = NS.Crafters
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.guild = { { name = "Vulo Sturmwind", rank = 1 }, { name = "Anna Amboss", rank = 3, online = false },
    { name = "Bob Hammer", rank = 3 } }
STUB.fire("GUILD_ROSTER_UPDATE")
GetProfessions = function() return 1 end
GetProfessionInfo = function(i) if i == 1 then return "Schmiedekunst", 136241, 45, 150, 3, 0, 164 end end
STUB.item(2853, "Kupferarmschienen", 1)
local D = NS.DropsToday()
AmisiaDB.prof = { chars = { ["Vulo Sturmwind"] = { [164] = { rank = 45, max = 150, day = D, known = { [2663] = true } } } } }
local ix = Cr._index(164)
AmisiaDB.crafters = { v = 1, src = {}, c = {
    ["Anna Amboss"] = { via = "Anna Amboss", self = true, seen = D, p = { [164] = { r = 300, m = 300, h = ix.hash,
        b = Cr._toBits(ix, { [2663] = true, [3321] = true }) } } },
} }
Cr.Changed()

NS.Dispatch("berufe schmied")
local f = NS.PageFrame("professions")
local d = f.rd
assert(#f.list.items == 5)
-- Kupferarmschienen: Anna (offline, 300) after Vulo himself (online, 45); the offline ones only counted
-- until "Offline zeigen" (D-82)
f.list.rows[1]:Click()
assert(d.who:GetText() == NS.Theme.GREEN .. "Vulo Sturmwind (45)|r\n" .. NS.Theme.GREY .. "1 offline|r", d.who:GetText())
assert(not d.offline:GetChecked() and f.list.rows[1].dotGuild:IsShown(), "Anna's green dot")
d.offline:Click()
assert(AmisiaDB.settings.professions.offline == true and d.offline:GetChecked(), "kept")
local body = d.who:GetText()
assert(has(body, NS.Theme.GREEN .. "Vulo Sturmwind (45)|r, Anna Amboss (300)"), body)
assert(has(d.sub:GetText(), "In der Gilde bekannt"), d.sub:GetText())
assert(d.ask:IsShown(), "Anna can be asked")
local said
ChatFrameUtil.SendTellWithMessage = function(name, text) said = { name, text } end
d.ask:Click()
assert(said and said[1] == "Anna Amboss" and has(said[2], "[Kupferarmschienen]"), said and said[2])
-- the vest only Anna knows (fourth by learn rank); a recipe nobody knows says so and cannot be asked
f.list.rows[4]:Click()
assert(has(d.who:GetText(), "Anna Amboss (300)"), d.who:GetText())
f.list.rows[3]:Click()
assert(has(d.who:GetText(), "Hergestellt von: niemand aus der Gilde bekannt") and not d.ask:IsShown())
assert(not f.list.rows[3].dotGuild:IsShown(), "no green dot")

-- only what the guild knows
assert(f.guild.label:GetText() == "Gilde (2)" and f.guild:IsEnabled() and not f.guild.dim, f.guild.label:GetText())
f.guild:Click()
assert(AmisiaDB.settings.professions.guild == true and f.guild.on and #f.list.items == 2, #f.list.items)
f.known.onPick("unknown")            -- unknown to me, known in the guild: the vest
assert(#f.list.items == 1 and f.list.items[1].recipe.spell == 3321, #f.list.items)
f.known.onPick("all")
f.guild:Click()
assert(not AmisiaDB.settings.professions.guild and #f.list.items == 5)

-- Bob shares what he knows: the page follows
AmisiaDB.crafters.c["Bob Hammer"] = { via = "Bob Hammer", self = true, seen = D, p = { [164] = { r = 120, m = 150, h = ix.hash,
    b = Cr._toBits(ix, { [1252229] = true }) } } }
Cr.Changed()
STUB.tick(1)
f.list.rows[3]:Click()
assert(has(d.who:GetText(), NS.Theme.GREEN .. "Bob Hammer (120)|r"), d.who:GetText())
assert(d.ask:IsShown())
-- the camp view has no crafters and no ask
NS.Dispatch("berufe lager")
assert(not f.detail.ask:IsEnabled() and not f.guild:IsShown() and not d:IsShown())
