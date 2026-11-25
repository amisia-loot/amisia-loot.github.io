-- The page Amisia-Versionen (tab Gilde, F-237, D-170): the own row and every hello seen with version, modules,
-- language, view, where and when; the guild members without a hello greyed ("nichts gehört", "kein Amisia?" only
-- for online members after a guild question had its answers), the online ones first; the summary; the newer
-- version; the filters Alle, Online, Veraltet, Ohne Amisia; the sortable heads; the row tooltips; the links
-- "Raid fragen" and "Gilde fragen" with their locks; the raid members without an answer; the rows built again only
-- when the data changes; no guild; "Über und Befehle" with its count and the link "Alle Versionen"; the gear.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local T = NS.Theme

STUB.player = "Vuloo"
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2 },
    { name = "Fraktur", class = "SHAMAN", rank = 1 },
    { name = "Chorf", class = "WARRIOR", rank = 3 },
    { name = "Anna Bergmann", class = "PRIEST", rank = 4 },
    { name = "Moe", class = "MAGE", rank = 4, online = false, last = { 0, 0, 3, 0 } },
    { name = "Lia", class = "DRUID", rank = 4 },
    { name = "Kimtaro", class = "ROGUE", rank = 4, online = false, last = { 0, 0, 1, 2 } },
}
_G.UnitClass = function() return "Priester", "PRIEST" end
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
local own = NS.VERSION
assert(NS.CompareVersion(own, "2.105.0") > 0, "the test needs a version above 2.105.0")
local function hello(from, v, flags, mods, lang)
    STUB.fire("CHAT_MSG_ADDON", "Amisia", ("1HI\t%s\t1\t%s\t-\t%s\t%s"):format(v, flags, mods, lang), "GUILD", from, "", 0, 0, "", 0)
end
hello("Fraktur", own, "O", "rgdt", "deDE")
hello("Chorf", "2.105.0", "-", "rg", "enUS")
hello("Anna Bergmann", own, "-", "rgdt", "frFR")
-- a hello of before F-228 (2.104.0): "g" stood for every module
hello("Moe", "2.100.0", "-", "rg", "deDE")
STUB.tick(1)
assert(NS.VersionLang("Anna Bergmann") == "frFR")

---------------------------------------------------------------------------
-- the page: tab Gilde, everyone, every client; the gear opens "Sync und Version"
---------------------------------------------------------------------------
local panel = assert(NS.Panel("versions"))
assert(panel.group == "guild" and not panel.officer and not panel.expert and not panel.forever and not panel.available)
NS.Set("ui.view", "raider")
assert(NS.Visible(panel), "raiders see it")
local secs = {}
for _, s in ipairs(NS.SettingsSectionsOf("versions")) do secs[s.key] = true end
assert(secs.sync, "the gear opens Sync und Version")

NS.ShowPage("versions")
assert(NS.CurrentPage() == "versions")
local f = assert(NS.PageFrame("versions"))
local function names()
    local out = {}
    for i, r in ipairs(f.list.items) do out[i] = r.name end
    return table.concat(out, ",")
end
local function row(name)
    for i, r in ipairs(f.list.items) do
        if r.name == name then return r, f.list.rows[i] end
    end
end
-- every one with Amisia first, then the members without a hello: the online ones first
local items = f.list.items
assert(#items == 7, names())
for i = 1, 5 do assert(items[i].v, "Amisia first: " .. names()) end
assert(items[6].name == "Lia" and items[7].name == "Kimtaro", names())
assert(f.summary:GetText() == ("5 mit Amisia · 3× %s · 1× 2.105.0 · 1× 2.100.0 · 2 veraltet"):format(own), f.summary:GetText())
assert(not f.newer:IsShown(), "no newer version")
assert(has(f.data:GetText(), "vergisst ein Hallo nach 30 Tagen"), f.data:GetText())

-- a row: the online mark, the name in class colour, version, modules, language, view, where, last
local _, fr = row("Fraktur")
assert(fr.dot:IsShown() and fr.dot.texture == T.VERSIONS.ONLINE_ICON, "online: the mark")
assert(has(fr.name:GetText(), "Fraktur") and has(fr.name:GetText(), "|c"), fr.name:GetText())
assert(fr.ver:GetText() == own, fr.ver:GetText())
assert(fr.mods[1]:IsShown() and fr.mods[2]:IsShown() and fr.mods[3]:IsShown(), "three modules")
assert(fr.mods[1].texture == T.TAB_ICONS.gear.file and fr.mods[3].texture == T.TAB_ICONS.talents.file)
assert(fr.lang:GetText() == "Deutsch" and fr.view:GetText() == "Offizier" and fr.where:GetText() == "Gilde")
assert(fr.last:GetText():match("^%d%d:%d%d$"), "seen today: the time " .. fr.last:GetText())
local _, ch = row("Chorf")
assert(has(ch.ver:GetText(), "2.105.0") and has(ch.ver:GetText(), T.ORANGE), "older: orange " .. ch.ver:GetText())
assert(ch.mods[1]:IsShown() and not ch.mods[2]:IsShown(), "only Ausrüstung")
assert(ch.lang:GetText() == "Englisch" and ch.view:GetText() == "Raider")
local _, an = row("Anna Bergmann")
assert(an.lang:GetText() == "Französisch")
local _, mo = row("Moe")
assert(not mo.dot:IsShown(), "offline: no mark")
assert(mo.mods[3]:IsShown(), "before 2.104.0 a g is every module")
local _, me = row("Vuloo")
assert(me.ver:GetText() == own and me.dot:IsShown())
-- the members without a hello: grey, "nichts gehört" (nobody asked yet)
local lia, li = row("Lia")
assert(li.dot:IsShown() and has(li.name:GetText(), T.GREY) and has(li.ver:GetText(), "-"))
assert(has(li.last:GetText(), "nichts gehört"), li.last:GetText())
local _, ki = row("Kimtaro")
assert(not ki.dot:IsShown() and has(ki.last:GetText(), "nichts gehört"))
for _, t in ipairs(li.mods) do assert(not t:IsShown(), "no modules without Amisia") end

-- the tooltips
local function tipOf(name)
    local out = {}
    for _, l in ipairs(NS.VersionsTooltipLines((row(name)))) do out[#out + 1] = l[1] end
    return table.concat(out, "\n")
end
local tip = tipOf("Fraktur")
assert(has(tip, "Version " .. own) and has(tip, "Module: Ausrüstung, Dungeons & Raids, Talente"), tip)
assert(has(tip, "Spielsprache: Deutsch") and has(tip, "Ansicht: Offizier") and has(tip, "Gesehen in der Gilde"), tip)
assert(has(tip, "Zuletzt gesehen: "), tip)
assert(has(tipOf("Chorf"), "Älter als die neueste gesehene Version.") and has(tipOf("Chorf"), "Module: Ausrüstung\n"), tipOf("Chorf"))
assert(has(tipOf("Vuloo"), "Das bist du."))
assert(has(tipOf("Lia"), "nichts gehört") and has(tipOf("Lia"), "in 30 Tagen kein Hallo") and has(tipOf("Lia"), "online"), tipOf("Lia"))
-- the row's tooltip in the game
local lines, addLine = {}, GameTooltip.AddLine
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
fr.scripts.OnEnter(fr)
GameTooltip.AddLine = addLine
assert(has(lines[1], "Fraktur") and lines[2] == "Version " .. own, tostring(lines[2]))

---------------------------------------------------------------------------
-- the filters
---------------------------------------------------------------------------
assert(f.tabs.all.on and not f.tabs.old.on and not f.tabs.old.dim and not f.tabs.none.dim)
f.tabs.online:Click()
assert(#f.list.items == 5 and row("Lia") and not row("Moe") and not row("Kimtaro"), names())
f.tabs.old:Click()
assert(#f.list.items == 2 and row("Chorf") and row("Moe"), names())
f.tabs.none:Click()
assert(names() == "Lia,Kimtaro", names())
f.tabs.all:Click()
assert(#f.list.items == 7)

---------------------------------------------------------------------------
-- the sort: a click on a head, a second turns it round; rows without the value stay last
---------------------------------------------------------------------------
f.heads.ver:Click()
local it = f.list.items
assert(it[1].v == own and it[4].v == "2.105.0" and it[5].v == "2.100.0" and it[6].none and it[7].none, names())
f.heads.ver:Click()
it = f.list.items
assert(it[1].v == "2.100.0" and it[2].v == "2.105.0" and it[6].none and it[7].none, names())
f.heads.name:Click()
assert(names() == "Anna Bergmann,Chorf,Fraktur,Kimtaro,Lia,Moe,Vuloo", names())
f.heads.name:Click()
assert(names() == "Vuloo,Moe,Lia,Kimtaro,Fraktur,Chorf,Anna Bergmann", names())
f.heads.lang:Click()
it = f.list.items
assert(it[1].word == "Deutsch" and it[#it].none, names())
NS.VersionsPageState("all", false)
NS.Refresh()
assert(f.list.items[6].name == "Lia", "back to the order of the rows")

---------------------------------------------------------------------------
-- the rows are built again only when the data changes
---------------------------------------------------------------------------
local rows1 = NS.VersionsPageRows()
NS.Refresh()
assert(NS.VersionsPageRows() == rows1, "the same rows: nothing changed")
hello("Lia", own, "-", "r", "deDE")
STUB.tick(1.2)
assert(NS.VersionsPageRows() ~= rows1, "a new hello: built again")
assert(row("Lia").v == own and #f.list.items == 7, "Lia has Amisia now: " .. names())
local _, li2 = row("Lia")
assert(not li2.mods[1]:IsShown(), "Amisia without a module")
assert(has(f.summary:GetText(), "6 mit Amisia"), f.summary:GetText())

---------------------------------------------------------------------------
-- "Gilde fragen": the link locks; after the answers an online member without one is "kein Amisia?"
---------------------------------------------------------------------------
STUB.guild[#STUB.guild + 1] = { name = "Ole", class = "HUNTER", rank = 4 }
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11.5)
assert(row("Ole") and has(select(2, row("Ole")).last:GetText(), "nichts gehört"), names())
assert(f.askGuild:IsEnabled() and f.askGuild.tip == nil)
assert(not f.askRaid:IsEnabled() and f.askRaid.tip == "Nur in einer Raidgruppe.")
f.askGuild:Click()
assert(not f.askGuild:IsEnabled() and f.askGuild.tip == "Wieder in 5 Minuten.", tostring(f.askGuild.tip))
assert(has(select(2, row("Ole")).last:GetText(), "nichts gehört"), "the answers are not in yet")
STUB.tick(17)
assert(NS.VersionAnswered("guild") == true)
local ole, ol = row("Ole")
assert(ole.verdict and has(ol.last:GetText(), "kein Amisia?"), ol.last:GetText())
assert(has(tipOf("Ole"), "wohl kein Amisia"), tipOf("Ole"))
local _, ki2 = row("Kimtaro")
assert(has(ki2.last:GetText(), "nichts gehört"), "offline: still nothing heard")
-- the version check off: both links locked
NS.Set("sync.versionCheck", false)
NS.Refresh()
assert(not f.askGuild:IsEnabled() and f.askGuild.tip == "Versionsprüfung ist ausgeschaltet.")
NS.Reset("sync.versionCheck")

---------------------------------------------------------------------------
-- a newer version: the line under the summary
---------------------------------------------------------------------------
hello("Fraktur", "9.0.1", "O", "rgdt", "deDE")
STUB.tick(1.2)
assert(f.newer:IsShown() and has(f.newer:GetText(), "Es gibt eine neuere Version: 9.0.1 (gesehen bei Fraktur)."), f.newer:GetText())
local _, me2 = row("Vuloo")
assert(has(me2.ver:GetText(), T.ORANGE), "the own version is old now")

---------------------------------------------------------------------------
-- the raid: "Raid fragen", 10 s later the members without an answer
---------------------------------------------------------------------------
STUB.roster = { { name = "Vuloo", class = "PRIEST" }, { name = "Fraktur", class = "SHAMAN" }, { name = "Pug", class = "WARRIOR" } }
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(6)
assert(f.askRaid:IsEnabled(), "in a raid")
f.askRaid:Click()
STUB.tick(10.5)
local pug, pr = row("Pug")
assert(pug and pug.missing and pug.where == "raid" and has(pr.last:GetText(), "kein Amisia?") and pr.where:GetText():find("Raid", 1, true), names())
assert(has(tipOf("Pug"), "Raid fragen"), tipOf("Pug"))
f.tabs.none:Click()
assert(row("Pug") and row("Kimtaro") and not row("Fraktur"), names())
f.tabs.all:Click()
STUB.roster = {}
STUB.fire("GROUP_ROSTER_UPDATE"); STUB.tick(2)

---------------------------------------------------------------------------
-- "Über und Befehle": the count and the link to the page
---------------------------------------------------------------------------
NS.ShowPage("about")
local ab = NS.PageFrame("about")
assert(ab.seen:GetText() == "5 mit Amisia gesehen", ab.seen:GetText())
assert(ab.versions:GetText() == "Alle Versionen")
assert(ab.cmdTitle:GetText() == "Befehle" and has(ab.text.fs:GetText(), "/amisia version"))
assert(ab.newer:IsShown(), "the newer version stays on the about page")
ab.versions:Click()
assert(NS.CurrentPage() == "versions", "the link opens the page")

---------------------------------------------------------------------------
-- no guild: the own row, no members without a hello, "Gilde fragen" locked
---------------------------------------------------------------------------
STUB.inGuild = false
STUB.fire("PLAYER_GUILD_UPDATE"); STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11.5)
NS.Refresh()
for _, r in ipairs(f.list.items) do assert(not r.none, "no guild: no members without a hello " .. r.name) end
assert(not f.askGuild:IsEnabled() and f.askGuild.tip == "Nur in einer Gilde.")
assert(row("Vuloo"), "the own row")
