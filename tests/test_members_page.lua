-- The page Mitglieder (tab Gilde, F-104): every guild member with class icon, name, level, class,
-- rank, zone and last online; online first; the professions from the recipe exchange (heard and own)
-- with skill and tooltip; the class and profession dropdowns, "nur online", the name search; sorting
-- by the column heads; the footer counts; the row tooltip (notes, officer note only when the client
-- shows it, main and alts); the menu (whisper "/w Name ", invite); the lockdown keeps the last rows;
-- no guild; the filters stay in settings.window.members; the roster's new fields from both readers.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local Cr = NS.Crafters
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")

STUB.player = "Vuloo"
STUB.officer = true
local D = NS.DropsToday()
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 60, zone = "Sturmwind" },
    { name = "Anna Amboss", class = "WARRIOR", rank = 3, level = 58, zone = "Eisenschmiede", note = "Schmiedin",
      onote = "Kasse" },
    { name = "Bob", class = "MAGE", rank = 4, level = 60, zone = "Tanaris" },
    { name = "Carla", class = "PRIEST", rank = 3, level = 42, online = false, last = { 0, 0, 2, 19 } },
    { name = "Dora", class = "ROGUE", rank = 5, level = 12, online = false, last = { 0, 0, 0, 5 } },
    { name = "Emil", class = "HUNTER", rank = 3, level = 60, zone = "Feralas" },
    { name = "Fynn", class = "DRUID", rank = 3, level = 33, online = false, last = { 1, 2, 0, 0 } },
    { name = "Gerd", class = "SHAMAN", rank = 4, level = 60, zone = "Silithus" },
    { name = "Hanna", class = "WARLOCK", rank = 3, level = 55, zone = "Winterquell" },
    { name = "Ida", class = "PALADIN", rank = 3, level = 60, online = false, last = { 0, 3, 4, 0 } },
    { name = "Jan", class = "PRIEST", rank = 1, level = 60, zone = "Orgrimmar" },
    { name = "Kai", class = "MAGE", rank = 4, level = 21, online = false },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
-- a twink (Bob is Anna's) and Anna's professions from the exchange, Vuloo's own
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-06\nA Bob Anna_Amboss\n#END"))
AmisiaDB.prof = { chars = { ["Vuloo"] = { [171] = { rank = 120, max = 150, day = D, known = { [2330] = true } },
    [185] = { rank = 40, max = 75, day = D - 1, known = { [1229737] = true } } } } }
local ix = Cr._index(164)
AmisiaDB.crafters = { v = 1, src = {}, c = {
    ["Anna Amboss"] = { via = "Anna Amboss", self = true, seen = D - 3, p = { [164] = { r = 225, m = 300, h = ix.hash,
        b = Cr._toBits(ix, { [2663] = true, [3321] = true }) }, [185] = { r = 10, m = 75, l = "1229737" } } },
} }
Cr.Changed()

---------------------------------------------------------------------------
-- the roster's new fields (C_Club)
---------------------------------------------------------------------------
local roster = NS.GuildRoster()
local function member(name)
    for _, m in ipairs(roster) do if m.name == name then return m end end
end
local anna = member("Anna Amboss")
assert(anna.zone == "Eisenschmiede" and anna.note == "Schmiedin" and anna.rankName == "Veteran" and anna.officerNote == "Kasse",
    "zone, note, rank name, officer note from C_Club")
local carla = member("Carla")
assert(carla.last and carla.last.d == 2 and carla.last.h == 19 and carla.last.y == 0, "last online from C_Club")
assert(member("Bob").last == nil, "online: no last")
assert(member("Bob").rank == 4 and member("Bob").online == true and member("Bob").class == "MAGE", "the old fields stay")

---------------------------------------------------------------------------
-- the page: everyone, tab Gilde
---------------------------------------------------------------------------
local panel = assert(NS.Panel("members"))
assert(panel.group == "guild" and not panel.officer and not panel.expert, "for every view, in the tab Gilde")
NS.Set("ui.view", "raider")
assert(NS.Visible(panel), "raiders see it")
NS.Set("ui.view", "officer")

NS.ShowPage("members")
local f = assert(NS.MembersPageFrame())
local items = f.list.items
assert(#items == 12, #items)
-- online first, then by name
local order = {}
for i, e in ipairs(items) do order[i] = e.name end
assert(table.concat(order, ",") == "Anna Amboss,Bob,Emil,Gerd,Hanna,Jan,Vuloo,Carla,Dora,Fynn,Ida,Kai", table.concat(order, ","))
assert(has(f.data:GetText(), "12 Mitglieder, 7 online, 2 mit Amisia"), f.data:GetText())

-- a row: class icon, name in class colour, level class rank, zone, online; the boxes
local r1 = f.list.rows[1]
assert(r1.classIcon:IsShown() and r1.classIcon.texture == NS.Theme.MEMBERS.CLASS_TEXTURE, "the round class icon")
assert(has(r1.name:GetText(), "Anna Amboss") and has(r1.name:GetText(), "|c"), r1.name:GetText())
assert(has(r1.info:GetText(), "58 Krieger · Veteran") and not has(r1.info:GetText(), "Stufe"), r1.info:GetText())
assert(r1.zone:GetText() == "Eisenschmiede" and has(r1.last:GetText(), "online") and has(r1.last:GetText(), NS.Theme.GREEN))
-- Anna: smithing in the upper line, cooking in the lower
local b1, b4 = r1.boxes[1], r1.boxes[NS.Theme.MEMBERS.MAIN_BOXES + 1]
assert(b1:IsShown() and b1.num:GetText() == "225" and b1.label:GetText() == "Schmiedekunst", b1.label:GetText())
assert(not r1.boxes[2]:IsShown(), "one main profession")
assert(b4:IsShown() and b4.label:GetText() == "Kochkunst" and b4.num:GetText() == "10", "cooking below")
assert(NS.MembersProfText(b1.prof) == "Schmiedekunst 225/300, 2 Rezepte, Stand vor 3 Tagen", NS.MembersProfText(b1.prof))
assert(NS.MembersProfText(b4.prof) == "Kochkunst 10/75, 1 Rezept, Stand vor 3 Tagen", NS.MembersProfText(b4.prof))
-- the own character: alchemy and cooking, read today and yesterday
local own = f.list.rows[7]
assert(own.item.name == "Vuloo" and own.boxes[1].label:GetText() == "Alchimie" and own.boxes[1].num:GetText() == "120")
assert(NS.MembersProfText(own.boxes[1].prof) == "Alchimie 120/150, 1 Rezept, Stand heute", NS.MembersProfText(own.boxes[1].prof))
assert(NS.MembersProfText(own.boxes[NS.Theme.MEMBERS.MAIN_BOXES + 1].prof) == "Kochkunst 40/75, 1 Rezept, Stand vor 1 Tag")
-- a member without Amisia: no boxes
for _, b in ipairs(f.list.rows[2].boxes) do assert(not b:IsShown(), "Bob shares nothing") end
-- offline: grey zone placeholder, "zuletzt vor ..."
local carlaRow = f.list.rows[8]
assert(has(carlaRow.last:GetText(), "zuletzt vor 2 Tagen") and not has(carlaRow.last:GetText(), "Stunden"), "the row: the largest unit: " .. carlaRow.last:GetText())
assert(has(f.list.rows[9].last:GetText(), "zuletzt vor 5 Stunden"), f.list.rows[9].last:GetText())
-- the rows below the nine shown: the wheel scrolls
f.list.scripts.OnMouseWheel(f.list, -1)
assert(f.list.rows[9].item.name == "Fynn" and has(f.list.rows[9].last:GetText(), "zuletzt vor 1 Jahr"),
    f.list.rows[9].last:GetText())
f.list.scripts.OnMouseWheel(f.list, 1)
-- Kai: offline, the client did not say since when
assert(has(f.list.items[12].name, "Kai") and f.list.items[12].away > 1e8, "unknown last online sorts last")

---------------------------------------------------------------------------
-- tooltips
---------------------------------------------------------------------------
local function lines(e)
    local out = {}
    for _, l in ipairs(NS.MembersTooltipLines(e)) do out[#out + 1] = l[1] end
    return table.concat(out, "\n")
end
local tip = lines(items[1])
assert(has(tip, "Notiz: Schmiedin") and has(tip, "Offiziersnotiz: Kasse") and has(tip, "Twinks: Bob") and has(tip, "Veteran"), tip)
assert(has(lines(items[2]), "Main: Anna Amboss"), lines(items[2]))
assert(has(lines(items[8]), "zuletzt vor 2 Tagen 19 Stunden"), lines(items[8]))
assert(not has(lines(items[7]), "Klick:"), "the own row has no menu")
-- the officer note only when the client shows it
STUB.officerNotes = false
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.Refresh()
assert(f.list.items[1].officerNote == nil and not has(lines(f.list.items[1]), "Offiziersnotiz"), "no officer note for a raider")
STUB.officerNotes = nil

---------------------------------------------------------------------------
-- the row menu: whisper, invite
---------------------------------------------------------------------------
local opened, invited
_G.ChatFrame_OpenChat = function(text) opened = text end
C_PartyInfo.InviteUnit = function(name) invited = name end
local entries = NS.MembersMenuEntries(f.list.items[3])     -- Emil, online
assert(#entries == 2 and entries[1][1] == "Flüstern" and entries[2][1] == "Einladen")
entries[1][2]()
assert(opened == "/w Emil ", tostring(opened))
entries[2][2]()
assert(invited == "Emil", tostring(invited))
assert(#NS.MembersMenuEntries(f.list.items[9]) == 1, "offline: whisper only")
assert(#NS.MembersMenuEntries(f.list.items[7]) == 0, "the own character: no menu")
-- a click on a row opens the menu under it
f.list.rows[3]:Click()
assert(AmisiaMenu and AmisiaMenu:IsShown() and AmisiaMenu.buttons[1].label:GetText() == "Flüstern", "the menu")
AmisiaMenu.buttons[1]:Click()
assert(opened == "/w Emil " and not AmisiaMenu:IsShown())
-- a name with a space: the whisper itself
local told
_G.ChatFrame_SendTell = function(name) told = name end
opened = nil
NS.MembersMenuEntries(f.list.items[1])[1][2]()
assert(told == "Anna Amboss" and opened == nil, "a name with a space whispers the whole name")

---------------------------------------------------------------------------
-- filters, sorting, the footer
---------------------------------------------------------------------------
local W = AmisiaDB.settings.window
f.class.onPick("PRIEST")
assert(W.members.class == "PRIEST" and #f.list.items == 3, #f.list.items)
assert(has(f.data:GetText(), "3 von 12 Mitgliedern, 2 online, 1 mit Amisia"), f.data:GetText())
f.online:Click()
assert(W.members.online == true and #f.list.items == 2, "nur online")
f.class.onPick("all")
assert(#f.list.items == 7 and has(f.data:GetText(), "7 von 12 Mitgliedern, 7 online"), f.data:GetText())
f.online:Click()
assert(not W.members.online and #f.list.items == 12)
-- the profession dropdown: every profession of the data, then only who has it
local values = {}
for _, v in ipairs(f.prof.values) do values[#values + 1] = v.text end
assert(table.concat(values, ",") == "Alle Berufe,Alchimie,Schmiedekunst,Kochkunst", table.concat(values, ","))
f.prof.onPick(185)
assert(#f.list.items == 2 and W.members.prof == 185, "cooking: Anna and Vuloo")
f.prof.onPick(171)
assert(#f.list.items == 1 and f.list.items[1].name == "Vuloo")
f.prof.onPick("all")
-- the search
f.search:SetText("an")
f.search.scripts.OnEnterPressed(f.search)
local names = {}
for i, e in ipairs(f.list.items) do names[i] = e.name end
assert(table.concat(names, ",") == "Anna Amboss,Hanna,Jan", table.concat(names, ","))
f.search:SetText("zzz")
f.search.scripts.OnEnterPressed(f.search)
assert(#f.list.items == 0 and f.empty:IsShown() and has(f.empty.text:GetText(), "Kein Mitglied passt"), "nothing found")
f.search:SetText("")
f.search.scripts.OnEnterPressed(f.search)
assert(#f.list.items == 12 and not f.empty:IsShown())
-- sorting by the heads: level (high first), again (low first), zone, last online, name, professions
f.heads.level:Click()
assert(W.members.sort == "level" and W.members.desc and f.list.items[1].level == 60 and f.list.items[12].level == 12)
f.heads.level:Click()
assert(not W.members.desc and f.list.items[1].name == "Dora", f.list.items[1].name)
f.heads.zone:Click()
assert(f.list.items[1].zone == "Eisenschmiede" and f.list.items[12].zone == "Winterquell", tostring(f.list.items[12].zone))
f.heads.last:Click()
assert(f.list.items[1].online and f.list.items[8].name == "Dora" and f.list.items[9].name == "Carla"
    and f.list.items[10].name == "Ida" and f.list.items[11].name == "Fynn" and f.list.items[12].name == "Kai", f.list.items[8].name)
f.heads.prof:Click()
assert(f.list.items[1].name == "Anna Amboss" and f.list.items[2].name == "Vuloo", f.list.items[1].name)
f.heads.name:Click()
assert(f.list.items[1].name == "Anna Amboss" and f.list.items[12].name == "Vuloo" and not W.members.desc)
-- the filters stay after a reload of the page state
f.class.onPick("MAGE")
assert(AmisiaDB.settings.window.members.class == "MAGE")
f.class.onPick("all")
W.members.sort = nil
NS.Refresh()

---------------------------------------------------------------------------
-- updates: a member comes online (after the roster's 10 s), only while the page is shown
---------------------------------------------------------------------------
STUB.guild[4].online, STUB.guild[4].zone = true, "Darnassus"
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(12)
local carlaNow
for _, e in ipairs(f.list.items) do if e.name == "Carla" then carlaNow = e end end
assert(carlaNow.online and carlaNow.zone == "Darnassus" and f.list.items[3].name == "Carla", "Carla online, among the online")
assert(has(f.data:GetText(), "8 online"), f.data:GetText())
-- a new crafter heard: the page follows
AmisiaDB.crafters.c["Emil"] = { via = "Emil", self = true, seen = D, p = { [171] = { r = 300, m = 300, l = "2330,1234001" } } }
Cr.Changed()
STUB.tick(1)
assert(has(f.data:GetText(), "3 mit Amisia"), f.data:GetText())

---------------------------------------------------------------------------
-- the lockdown keeps the last rows
---------------------------------------------------------------------------
STUB.chatLock = true
STUB.guild[5].online = true
STUB.fire("GUILD_ROSTER_UPDATE")
STUB.tick(12)
NS.Refresh()
assert(#f.list.items == 12 and has(f.data:GetText(), "8 online") and has(f.data:GetText(), "Stand vor der Kampfsperre"), f.data:GetText())
STUB.chatLock = false
STUB.fire("ADDON_RESTRICTION_STATE_CHANGED")
STUB.tick(12)
NS.Refresh()
assert(has(f.data:GetText(), "9 online") and not has(f.data:GetText(), "Kampfsperre"), f.data:GetText())

---------------------------------------------------------------------------
-- the classic roster functions (no C_Club): the same fields
---------------------------------------------------------------------------
local club = C_Club
C_Club = nil
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(12)
roster = NS.GuildRoster()
assert(member("Anna Amboss").zone == "Eisenschmiede" and member("Anna Amboss").rankName == "Veteran"
    and member("Anna Amboss").note == "Schmiedin" and member("Anna Amboss").officerNote == "Kasse", "classic roster fields")
assert(member("Fynn").last and member("Fynn").last.y == 1 and member("Fynn").last.mo == 2, "GetGuildRosterLastOnline")
STUB.officerNotes = false
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(12)
roster = NS.GuildRoster()
assert(member("Anna Amboss").officerNote == nil, "no officer note when the client does not show it")
STUB.officerNotes = nil
C_Club = club

---------------------------------------------------------------------------
-- layout
---------------------------------------------------------------------------
do
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
    L.row("head row", f.class, f.prof, f.online, f.onlineLabel, f.search)
    L.inside("members list", f.list)
end

---------------------------------------------------------------------------
-- review: a saved class or profession the guild no longer has goes back to "all"; under an hour
-- "gerade offline"; a bar in a rank name stays text; Cr.Own's empty list is one table (its caches hold)
---------------------------------------------------------------------------
do
    AmisiaDB.settings.window.members.class = "NOSUCHCLASS"
    AmisiaDB.settings.window.members.prof = 99999
    NS.Refresh()
    assert(AmisiaDB.settings.window.members.class == "all" and AmisiaDB.settings.window.members.prof == "all", "back to all")
    assert(#f.list.items > 0, "the list is not empty")
    local saved = AmisiaDB.prof
    AmisiaDB.prof = nil
    assert(Cr.Own() == Cr.Own(), "the same empty list")
    AmisiaDB.prof = saved
    local row = { name = "Lia", class = "MAGE", level = 60, rankName = "|TInterface\\Icons\\X:0|t Boss", online = false,
        last = { y = 0, mo = 0, d = 0, h = 0 } }
    assert(has(NS.MembersInfoText(row), "||T"), "the rank as text: " .. NS.MembersInfoText(row))
    assert(has(NS.MembersLastText(row), "gerade offline"), NS.MembersLastText(row))
end

---------------------------------------------------------------------------
-- not in a guild
---------------------------------------------------------------------------
STUB.inGuild = false
STUB.fire("PLAYER_GUILD_UPDATE"); STUB.tick(12)
NS.Refresh()
assert(#f.list.items == 0 and f.empty:IsShown() and f.empty.text:GetText() == "Du bist in keiner Gilde.", f.empty.text:GetText())
assert(f.data:GetText() == "")
STUB.inGuild = nil
print("members page ok")
