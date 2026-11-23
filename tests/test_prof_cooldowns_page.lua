-- The tab Abklingzeiten on the professions page (F-232, UI/Pages/Professions.lua): /amisia abklingzeiten opens it
-- after Route; "Deine Charaktere" with each own line, then per cooldown the guild's members (ready first); a
-- click on a guild member opens the members page's menu; an own row has none; the tab switches back.
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")
STUB.player = "Vulo Sturmwind"
STUB.instance = { name = "Durotar", type = "none", id = 0 }
STUB.guild = { { name = "Vulo Sturmwind", rank = 1, online = true }, { name = "Anna Amboss", rank = 3, online = true, class = "MAGE" },
    { name = "Bob Hammer", rank = 3, online = false } }
STUB.fire("GUILD_ROSTER_UPDATE")
NS.PROF_COOLDOWNS = { [3321] = "310:47", [2330] = "0:95" }
local now = time()
AmisiaDB.prof = AmisiaDB.prof or {}
AmisiaDB.prof.cd = { ["Vulo Sturmwind"] = { faction = "A", [3321] = now + 3600 * 14 + 20 * 60, [2330] = now - 5 } }
AmisiaDB.prof.cdHeard = {
    ["Bob Hammer"] = { by = "Bob Hammer", at = now, [3321] = now - 10 },
    ["Anna Amboss"] = { by = "Anna Amboss", at = now, [3321] = now + 7200 },
}

NS.Dispatch("abklingzeiten")
local f = NS.PageFrame("professions")
assert(f and f:IsShown(), "the page opened")
assert(f.cdView:IsShown() and f.tabCd.on and not f.tabRoute.on, "the tab Abklingzeiten")
assert(not f.list:IsShown() and not f.headBlock:IsShown(), "nothing of a profession's view")
local items = f.cdList.items
local function text(e) return e.head or e.note or (e.name .. "|" .. e.label) end
local got = {}
for i, e in ipairs(items) do got[i] = text(e) end
local want = { "Deine Charaktere", "Vulo Sturmwind|Schwacher Heiltrank", "Vulo Sturmwind|Transmutation",
    "Gilde: Transmutation", "Bob Hammer|Transmutation", "Anna Amboss|Transmutation" }
assert(table.concat(got, ", ") == table.concat(want, ", "), table.concat(got, ", "))
local rows = f.cdList.rows
assert(has(rows[2].state:GetText(), "bereit") and has(rows[3].state:GetText(), "in 14 Std. 20 Min."), rows[3].state:GetText())
assert(has(rows[2].name:GetText(), "(du)"))
assert(has(rows[5].state:GetText(), "bereit") and has(rows[5].name:GetText(), "(offline)"), "Bob ready first, though offline")
assert(has(rows[6].state:GetText(), "in 2 Std."))
-- a click on a guild member: the menu with Flüstern; an own row: nothing
local opened = 0
local menu = NS.W.Menu
NS.W.Menu = function(owner, entries) opened = opened + 1; assert(entries[1][1] == "Flüstern") end
rows[6]:Click()
assert(opened == 1, "Anna's menu")
rows[2]:Click()
rows[1]:Click()
assert(opened == 1, "no menu on an own row or a head")
NS.W.Menu = menu
-- another tab leaves it
f.tabAll:Click()
assert(not f.cdView:IsShown() and not f.tabCd.on)
-- nothing known: the notes
AmisiaDB.prof.cd, AmisiaDB.prof.cdHeard = nil, nil
NS.ShowProfessions("abklingzeiten")
got = {}
for i, e in ipairs(f.cdList.items) do got[i] = text(e) end
assert(#got == 4 and got[1] == "Deine Charaktere" and has(got[2], "Noch keine") and got[3] == "Gilde"
    and has(got[4], "Noch hat niemand"), table.concat(got, ", "))
