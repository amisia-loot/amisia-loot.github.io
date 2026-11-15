-- The guild characters on the members page (F-210, D-135): the guild notes as a source (positive and
-- negative cases, Forever surnames, a first name only when unique), the order of the sources (website >
-- Amisia > note), the own account, alts indented under their main with the item level beside the name,
-- filters and sorting by groups, the tooltip with source and age; the fields of AC and its byte limit;
-- the load-time cleaning of AmisiaDB.account and AmisiaDB.guildChars; the button "Amisia" at the
-- game's guild window (Forever: CommunitiesFrame when Blizzard_Communities loads; TBC/Era: GuildFrame).
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local M = NS.Theme.MEMBERS

STUB.player = "Vuloo"
STUB.class, STUB.level = "PRIEST", 30
_G.GetAverageItemLevel = function() return 31.9, 31.2 end
STUB.guild = {
    { name = "Vuloo", class = "PRIEST", rank = 2, level = 30, zone = "Sturmwind" },
    { name = "Vulo Vultrox", class = "WARRIOR", rank = 2, level = 60, online = false, last = { 0, 0, 1, 0 } },
    { name = "Vulo Zweitname", class = "MAGE", rank = 4, level = 20, online = false, last = { 0, 0, 3, 0 } },
    { name = "Anna Amboss", class = "WARRIOR", rank = 3, level = 58, zone = "Eisenschmiede" },
    { name = "Bob", class = "MAGE", rank = 4, level = 60, zone = "Tanaris", note = "Twink von Anna" },
    { name = "Carla", class = "PRIEST", rank = 3, level = 42, online = false, last = { 0, 0, 2, 0 }, note = "Bester Heiler" },
    { name = "Dora", class = "ROGUE", rank = 5, level = 12, online = false, last = { 0, 0, 0, 5 }, note = "Twink von Vulo" },
    { name = "Emil", class = "HUNTER", rank = 3, level = 60, zone = "Feralas", onote = "Main: Carla" },
    { name = "Fynn", class = "DRUID", rank = 3, level = 33, zone = "Feralas", note = "Ehemals Zorro" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
local roster = assert(NS.GuildRoster())
local function member(name)
    for _, m in ipairs(roster) do if m.name == name then return m end end
end

---------------------------------------------------------------------------
-- the notes
---------------------------------------------------------------------------
local function noteOf(text, who)
    local m = { name = who or "Fynn", note = text }
    return NS.GuildCharsNoteMain(roster, m)
end
assert(noteOf("Twink von Anna") == "Anna Amboss", "a unique first name")
assert(noteOf("Anna Amboss") == "Anna Amboss", "only the full name")
assert(noteOf("anna amboss") == "Anna Amboss", "any case")
assert(noteOf("Bob Twink") == "Bob" and noteOf("bob twink") == "Bob", "X Twink")
assert(noteOf("Twink: Carla") == "Carla" and noteOf("Main: Carla") == "Carla" and noteOf("main:Carla") == "Carla")
assert(noteOf("alt of Anna Amboss") == "Anna Amboss" and noteOf("Carla's alt") == "Carla" and noteOf("ALT OF Bob") == "Bob")
assert(noteOf("Twink von Vulo Vultrox.") == "Vulo Vultrox", "a surname, a full stop at the end")
assert(noteOf("Bester Heiler") == nil, "no member's name")
assert(noteOf("Twink von Vulo") == nil, "a first name two members carry")
assert(noteOf("Vulo") == nil, "a first name two members carry, alone")
assert(noteOf("Twink") == nil and noteOf("") == nil and noteOf("Main:") == nil, "no name")
assert(noteOf("Bobby") == nil and noteOf("Twink von Bo") == nil, "a part of a name")
assert(noteOf("Twink von Fynn", "Fynn") == nil, "not the member itself")
assert(NS.GuildCharsNoteMain(roster, { name = "Fynn", officerNote = "Twink von Emil" }) == "Emil", "the officer note")
assert(NS.GuildCharsNoteMain(roster, { name = "Fynn", note = "Ehemals Zorro", officerNote = "Bob" }) == "Bob", "the officer note after the public one")

---------------------------------------------------------------------------
-- the sources: website > Amisia > note; the own account
---------------------------------------------------------------------------
local view = NS.GuildCharsView()
assert(view["bob"].main == "Anna Amboss" and view["bob"].src == "note", "Bob from his note")
assert(view["emil"].main == "Carla" and view["emil"].src == "note", "Emil from the officer note")
assert(view["carla"].main == nil and view["dora"].main == nil, "no match: no main")
-- another character's AC over the note
AmisiaDB.guildChars.list["Bob"] = { main = "Emil", il = 52, at = time() - 3 * 86400, by = "Emil" }
NS.GuildCharsLoaded(AmisiaDB)
view = NS.GuildCharsView()
assert(view["bob"].main == "Carla" and view["bob"].src == "amisia", "Amisia over the note; a main of a main: the top one")
assert(view["bob"].il == 52 and view["bob"].ilAt == time() - 3 * 86400)
-- the website over both
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-11-15\nA Bob Anna_Amboss\n#END"))
view = NS.GuildCharsView()
assert(view["bob"].main == "Anna Amboss" and view["bob"].src == "site" and view["bob"].il == 52, "the website first")
-- ns.MainOf stays with the website's list alone
assert(NS.MainOf("Emil") == "Emil" and NS.AltMain("Emil") == nil, "the notes change nothing for points and loot")
-- the own account: Vuloo is level 30, Vulo Vultrox 60 in the same guild (its main), one in another guild
AmisiaDB.account.chars["Vulo Vultrox"] = { class = "WARRIOR", level = 60, il = 61, guild = "Amisia", at = time() - 86400 }
AmisiaDB.account.chars["Vulo Fremd"] = { class = "MAGE", level = 60, il = 70, guild = "Anders", at = time() }
NS.GuildCharsReadOwn()
view = NS.GuildCharsView()
assert(view["vuloo"].main == "Vulo Vultrox" and view["vuloo"].src == "amisia" and view["vuloo"].il == 31, "the own account")
assert(view["vulo vultrox"].main == nil and view["vulo vultrox"].il == 61)
assert(NS.MainOf("Vuloo") == "Vuloo", "ns.MainOf unchanged")

---------------------------------------------------------------------------
-- AC's fields and its byte limit
---------------------------------------------------------------------------
local f = NS.GuildCharsFields()
assert(table.concat(f, "\t") == "Vulo Vultrox\tVulo Vultrox:61\tVuloo:31", table.concat(f, "\t"))
do
    local saved = AmisiaDB.account.chars
    local chars = {}
    for k, v in pairs(saved) do chars[k] = v end
    local letters = "abcdefghijklmn"
    for i = 1, 14 do
        local name = "Langername" .. letters:sub(i, i) .. " Sehrlangernachname" .. letters:sub(i, i) .. "abcdefghijklm"
        chars[name] = { class = "MAGE", level = 30 + i, il = 20 + i, guild = "Amisia", at = time() - i }
        if i % 3 == 0 then chars[name].il = nil end
    end
    AmisiaDB.account.chars = chars
    f = NS.GuildCharsFields()
    local text = "1AC\t" .. table.concat(f, "\t")
    assert(#text <= 250 and #f <= 11 and #f >= 4, "fits the message: " .. #text .. " bytes, " .. #f .. " fields")
    assert(f[1] == "Vulo Vultrox" and f[2] == "Vulo Vultrox:61", "the main first")
    assert(has(f[3], "Langernamen Sehrlangernachnamen") and has(f[4], "Langernamem "), "then by level: " .. f[3] .. " / " .. f[4])
    -- a character without item level: "-"
    local dash = false
    for i = 2, #f do if f[i]:match(":%-$") then dash = true end end
    assert(dash, "no item level: -")
    -- every field passes the receiver's check: the message goes out
    assert(NS.CommSend("AC", f, "GUILD") == true)
    AmisiaDB.account.chars = saved
end

---------------------------------------------------------------------------
-- the members page: alts under their main, the item level beside the name
---------------------------------------------------------------------------
AmisiaDB.guildChars.list["Emil"] = { il = 47, at = time() }
NS.GuildCharsLoaded(AmisiaDB)
NS.ShowPage("members")
local page = assert(NS.PageFrame("members"))
local function names()
    local out = {}
    for i, e in ipairs(page.list.items) do out[i] = (e.depth == 1 and ">" or "") .. e.name end
    return table.concat(out, ",")
end
-- online first, then by name; Bob under Anna (website), Emil under Carla (note) though offline, Vuloo
-- under Vulo Vultrox (the own account)
assert(names() == "Anna Amboss,>Bob,Fynn,Carla,>Emil,Dora,Vulo Vultrox,>Vuloo,Vulo Zweitname", names())
local rows = page.list.rows
local anna, bob = rows[1], rows[2]
assert(bob.item.name == "Bob" and bob.classIcon.points.LEFT.x == M.ICON_X + M.INDENT, "the alt's icon one step right")
assert(bob.name.points.TOPLEFT.x == M.NAME_X + M.INDENT and bob.info.points.TOPLEFT.x == M.NAME_X + M.INDENT, "and its name")
assert(anna.classIcon.points.LEFT.x == M.ICON_X and anna.name.points.TOPLEFT.x == M.NAME_X, "the main where it was")
assert(has(bob.il:GetText(), "52") and anna.il:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") == "-",
    "the item level in its own column, a dash without")
assert(bob.il.points.TOPLEFT.x == M.IL_X and anna.il.points.TOPLEFT.x == M.IL_X, "the column does not move with the indent")
assert(has(rows[5].il:GetText(), "47"), "the inspected one: " .. tostring(rows[5].il:GetText()))
-- a scrolled row is filled anew: the indent follows the item
page.list.scripts.OnMouseWheel(page.list, -1)
for _, r in ipairs(page.list.rows) do
    if r:IsShown() and r.item then
        local want = r.item.depth == 1 and M.ICON_X + M.INDENT or M.ICON_X
        assert(r.classIcon.points.LEFT.x == want, "indent after scrolling: " .. r.item.name)
    end
end
page.list.scripts.OnMouseWheel(page.list, 1)

-- the tooltip: main and source, alts and source, the item level and its age
local function lines(e)
    local out = {}
    for _, l in ipairs(NS.MembersTooltipLines(e)) do out[#out + 1] = l[1] end
    return table.concat(out, "\n")
end
local function item(name)
    for _, e in ipairs(page.list.items) do if e.name == name then return e end end
end
local t = lines(item("Bob"))
assert(has(t, "Main: Anna Amboss") and has(t, "Quelle: Website") and has(t, "iLvl 52 (vor 3 Tagen)"), t)
t = lines(item("Anna Amboss"))
assert(has(t, "Twinks: Bob") and has(t, "Quelle: Website") and not has(t, "iLvl"), t)
t = lines(item("Emil"))
assert(has(t, "Main: Carla") and has(t, "Quelle: Notiz") and has(t, "iLvl 47 (heute)"), t)
t = lines(item("Vuloo"))
assert(has(t, "Main: Vulo Vultrox") and has(t, "Quelle: Amisia") and has(t, "iLvl 31 (heute)"), t)
t = lines(item("Vulo Vultrox"))
assert(has(t, "Twinks: Vuloo") and has(t, "Quelle: Amisia") and has(t, "iLvl 61 (vor 1 Tag)"), t)

-- filters: an alt stays under its main only when the main is shown too
page.class.onPick("MAGE")
assert(names() == "Bob,Vulo Zweitname", "Bob without Anna: a row of its own: " .. names())
assert(page.list.items[1].depth == 0 and page.list.rows[1].classIcon.points.LEFT.x == M.ICON_X)
page.class.onPick("all")
page.online:Click()
assert(names() == "Anna Amboss,>Bob,Emil,Fynn,Vuloo", "Emil and Vuloo online without their mains: " .. names())
page.online:Click()
-- sorting by a column: the groups by their main, the alts under it by name
page.heads.level:Click()
assert(names() == "Vulo Vultrox,>Vuloo,Anna Amboss,>Bob,Carla,>Emil,Fynn,Vulo Zweitname,Dora", names())
page.heads.name:Click()
assert(names() == "Anna Amboss,>Bob,Carla,>Emil,Dora,Fynn,Vulo Vultrox,>Vuloo,Vulo Zweitname", names())
-- the item level column sorts too, the highest first
assert(page.heads.ilvl and page.heads.ilvl.label:GetText() == "iLvl", "a head for the item level column")
page.heads.ilvl:Click()
assert(AmisiaDB.settings.window.members.sort == "ilvl" and AmisiaDB.settings.window.members.desc, "sorted by item level")
do
    local prev
    for _, e in ipairs(page.list.items) do
        if e.depth == 0 then
            assert(not prev or (e.il or 0) <= prev, "mains by item level, highest first: " .. names())
            prev = e.il or 0
        end
    end
end
AmisiaDB.settings.window.members.sort = nil
-- a main that left the guild: its alt stands alone, "Twink von X" in the tooltip
assert(NS.SetAlts("#AMISIA-ALTS 1 forever 2026-11-15\nA Bob Anna_Amboss\nA Fynn Gone_Away\n#END"))
NS.Refresh()
t = lines(item("Fynn"))
assert(item("Fynn").depth == 0 and has(t, "Twink von Gone Away") and has(t, "Quelle: Website"), t)
-- an AC heard while the page is open refreshes it
AmisiaDB.guildChars.list["Dora"] = { main = "Carla", il = 20, at = time(), by = "Dora", self = true }
NS.GuildCharsInspected("Dora", 21)
STUB.tick(1)
assert(has(names(), "Carla,>Dora,>Emil"), names())

-- layout: the head row and the list stay inside the page
do
    local L = dofile(ADDON_DIR .. "/../tests/layout.lua")(page, 602, 478)
    L.inside("members list", page.list)
end

---------------------------------------------------------------------------
-- the load-time cleaning of both keys
---------------------------------------------------------------------------
do
    local old = time() - 61 * 86400
    AmisiaDB.account = { v = 7, chars = {
        ["Gut Name"] = { class = "MAGE", level = 60, il = 50, guild = "Amisia", at = time() },
        ["Kaputt1"] = { class = "MAGE", level = 60, at = time() },
        ["Ohne Zeit"] = { class = "MAGE", level = 60 },
        ["Werte Falsch"] = { class = "mage", level = 300, il = 1000, guild = "A|cff", at = time() },
        [5] = { at = time() },
        ["Kein Table"] = "x",
    } }
    for i = 1, 60 do AmisiaDB.account.chars["Viele " .. string.char(97 + i % 26, 97 + math.floor(i / 26))] = { at = time() - 1000 - i } end
    AmisiaDB.guildChars = { list = {
        ["Gut Name"] = { main = "Anna Amboss", il = 50, at = time(), by = "Anna Amboss", self = true },
        ["Zu Alt"] = { main = "Anna Amboss", at = old },
        ["Nichts Drin"] = { at = time() },
        ["Main Kaputt"] = { main = "Anna9", il = 40, at = time(), by = 7 },
        ["Il Kaputt"] = { main = "Anna Amboss", il = 12.5, at = time(), self = 1 },
        ["Mit:Doppel"] = { main = "Anna Amboss", at = time() },
    } }
    NS.GuildCharsLoaded(AmisiaDB)
    local a, g = AmisiaDB.account, AmisiaDB.guildChars
    assert(a.v == 1 and a.chars["Gut Name"].il == 50 and a.chars["Gut Name"].guild == "Amisia")
    assert(a.chars["Kaputt1"] == nil and a.chars["Ohne Zeit"] == nil and a.chars[5] == nil and a.chars["Kein Table"] == nil)
    local w = a.chars["Werte Falsch"]
    assert(w and w.class == nil and w.level == nil and w.il == nil and w.guild == nil, "bad values dropped, the entry stays")
    local n = 0
    for _ in pairs(a.chars) do n = n + 1 end
    assert(n == 50, "at most 50 characters: " .. n)
    assert(g.v == 1 and g.list["Gut Name"].self == true and g.list["Gut Name"].main == "Anna Amboss")
    assert(g.list["Zu Alt"] == nil, "older than 60 days")
    assert(g.list["Nichts Drin"] == nil and g.list["Mit:Doppel"] == nil)
    assert(g.list["Main Kaputt"].main == nil and g.list["Main Kaputt"].il == 40 and g.list["Main Kaputt"].by == nil)
    assert(g.list["Il Kaputt"].il == nil and g.list["Il Kaputt"].main == "Anna Amboss" and g.list["Il Kaputt"].self == nil)
    -- twice: no change
    local before = NS.Count and NS.Count(g.list)
    NS.GuildCharsLoaded(AmisiaDB)
    assert(not before or NS.Count(g.list) == before)
    -- 1000 entries at most, the newest stay
    for i = 1, 1100 do
        local nm = "Spieler " .. string.char(97 + i % 26) .. string.char(97 + math.floor(i / 26) % 26) .. string.char(97 + math.floor(i / 676) % 26)
        g.list[nm] = { il = 30, at = time() - i }
    end
    NS.GuildCharsLoaded(AmisiaDB)
    n = 0
    for _ in pairs(g.list) do n = n + 1 end
    assert(n == 1000, "at most 1000: " .. n)
    -- broken tables: made anew
    AmisiaDB.account, AmisiaDB.guildChars = "x", { list = 5 }
    NS.GuildCharsLoaded(AmisiaDB)
    assert(type(AmisiaDB.account.chars) == "table" and type(AmisiaDB.guildChars.list) == "table")
end

---------------------------------------------------------------------------
-- after equipment changes: at most every 10 s
---------------------------------------------------------------------------
_G.GetAverageItemLevel = function() return 35, 35 end
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.tick(0.1)
assert(AmisiaDB.account.chars["Vuloo"].il == 35, "read at once")
_G.GetAverageItemLevel = function() return 36, 36 end
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.tick(5)
assert(AmisiaDB.account.chars["Vuloo"].il == 35, "not within 10 s")
STUB.tick(5.1)
assert(AmisiaDB.account.chars["Vuloo"].il == 36, "after 10 s")

---------------------------------------------------------------------------
-- the button at the game's guild window
---------------------------------------------------------------------------
assert(NS.GuildButtons.CommunitiesFrame == nil, "no button before the window is there")
_G.CommunitiesFrame = CreateFrame("Frame", "CommunitiesFrame", UIParent)
STUB.fire("ADDON_LOADED", "Blizzard_Communities")
local btn = assert(NS.GuildButtons.CommunitiesFrame, "made when Blizzard_Communities loads")
assert(btn:GetParent() == CommunitiesFrame, "a child of the guild window")
local p = btn.points.TOPRIGHT
assert(p and p.rel == CommunitiesFrame and p.relPoint == "BOTTOMRIGHT", "under its bottom right corner")
assert(btn:GetText() == "Amisia", btn:GetText())
STUB.fire("ADDON_LOADED", "SomethingElse")
assert(NS.GuildButtons.CommunitiesFrame == btn, "once")
NS.ShowPage("overview")
btn:Click()
assert(NS.CurrentPage() == "members", "a click opens the members page: " .. tostring(NS.CurrentPage()))
-- the classic guild frame of the friends window: right of the last tab
_G.FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame.numTabs = 4
for i = 1, 4 do CreateFrame("Button", "FriendsFrameTab" .. i, FriendsFrame) end
_G.GuildFrame = CreateFrame("Frame", "GuildFrame", FriendsFrame)
NS.GuildButtonCheck()
local gb = assert(NS.GuildButtons.GuildFrame)
assert(gb:GetParent() == GuildFrame and gb.points.LEFT and gb.points.LEFT.rel == FriendsFrameTab4, "beside the last tab")
print("guild chars page ok")
