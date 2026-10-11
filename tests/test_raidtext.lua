-- The Discord text of a raid: head with the weekday and raidlog.discordHead, bosses with wipes,
-- fight length, "ca." for loot window kills and "kein Kill", loot per boss through ns.KillFor,
-- bank and disenchant, "Geplündert" without hand-outs, late and bench, Markdown escapes, parts of
-- at most 1900 characters, the discord* switches, /amisia discord, Latin-1 only.
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end
local function T(h, m) return os.time({ year = 2026, month = 10, day = 2, hour = h, min = m, sec = 0 }) end
local function chars(text) local n = 0; for _ in text:gmatch("[^\128-\191]") do n = n + 1 end return n end
local function lineIndex(text, line)
    local i = 0
    for l in (text .. "\n"):gmatch("(.-)\n") do
        i = i + 1
        if l == line then return i end
    end
    return nil
end
local function lines(text)
    local out = {}
    for l in (text .. "\n"):gmatch("(.-)\n") do out[#out + 1] = l end
    return out
end

STUB.item(30001, "Zahn des Naj'entus", 4)
STUB.item(30002, "Halskette der Tiefe", 4)
STUB.item(30003, "Klinge des Supremus", 4)
STUB.item(30004, "Schulterpolster der ewigen Gnade", 4)
STUB.item(30005, "Kriegsklinge von Azzinoth", 5)
STUB.item(30006, "Umhang der Hochgeborenen", 4)
STUB.item(30007, "Ring des Zorns", 4)
STUB.item(30008, "Robe des Rates", 4)
STUB.item(30009, "Halskette der Verführung", 4)
STUB.item(30010, "Stiefel der Wache", 4)

local function raid(id)
    local s = { id = id or "20261002200000-564", date = "2026-10-02", zone = "Schwarzer Tempel", instanceID = 564,
        start = T(20, 0), firstScan = T(20, 2), last = T(23, 10), lateAt = T(20, 5),
        members = {}, loot = {}, items = {}, drops = {}, awards = {}, gone = {}, kills = {}, bench = {}, outside = {} }
    table.insert(AmisiaDB.sessions, s)
    return s
end

local s = raid()
s.members = {
    Fraktur = { class = "SHAMAN", first = T(20, 2), last = T(23, 10) },
    ["Vulo Sturmwind"] = { class = "WARRIOR", first = T(20, 2), last = T(23, 10) },
    Chorf = { class = "WARRIOR", first = T(20, 12), last = T(23, 10), late = true },
    Anna = { class = "PRIEST", first = T(20, 31), last = T(23, 10), late = true },
    Kim = { class = "MAGE", first = T(21, 40), last = T(23, 10), bench = true },
}
s.bench = {
    Bob = { t = T(19, 50), class = "MAGE", self = true, note = "ab 21 Uhr" },
    Fred = { t = T(19, 52), class = "", by = "Vuloo" },
    Kim = { t = T(19, 55), class = "MAGE", by = "Vuloo" },
}
s.kills = {
    { enc = 601, name = "Hochkriegsfürst Naj'entus", start = T(20, 14) - 192, t = T(20, 14), ok = true, size = 25, diff = 4, src = "enc", who = { "Fraktur" }, n = 1 },
    { enc = 602, name = "Supremus", start = T(20, 28), t = T(20, 30), ok = false, size = 25, diff = 4, src = "enc", n = 3 },
    { enc = 602, name = "Supremus", start = T(20, 33), t = T(20, 35), ok = false, size = 25, diff = 4, src = "enc", n = 3 },
    { enc = 602, name = "Supremus", start = T(20, 41) - 245, t = T(20, 41), ok = true, size = 25, diff = 4, src = "enc", who = {}, n = 3 },
    { enc = 0, name = "Mutter Shahraz", start = T(21, 30), t = T(21, 30), ok = true, size = 0, diff = 0, src = "loot", who = {}, n = 0 },
    { enc = 0, name = "Der Illidari-Rat", start = T(21, 50), t = T(21, 50), ok = true, size = 0, diff = 0, src = "hand", who = {}, n = 0 },
    { enc = 609, name = "Illidan Sturmgrimm", start = T(22, 35), t = T(22, 40), ok = false, size = 25, diff = 4, src = "enc", n = 5 },
    { enc = 609, name = "Illidan Sturmgrimm", start = T(22, 45), t = T(22, 50), ok = false, size = 25, diff = 4, src = "enc", n = 5 },
    { enc = 609, name = "Illidan Sturmgrimm", start = T(22, 55), t = T(23, 0), ok = false, size = 25, diff = 4, src = "enc", n = 5 },
}
s.drops = { ["Creature-0-1-1-1-22949-1"] = { src = "Gathios der Zerschmetterer", t = T(21, 52), items = { [30008] = 1 } } }
NS.AddAwardTo(s, { name = "Fraktur", item = 30001, kind = "MS", src = "Hochkriegsfürst Naj'entus", t = T(20, 16) })
NS.AddAwardTo(s, { name = "Vulo Sturmwind", item = 30002, kind = "SR", src = "Hochkriegsfürst Naj'entus", t = T(20, 17) })
NS.AddAwardTo(s, { name = "Anna", item = 30003, kind = "OS", src = "Supremus", t = T(20, 43), note = "Tausch mit Bob" })
NS.AddAwardTo(s, { name = "Chorf", item = 30004, kind = "MS", src = "?", t = T(21, 0) })
NS.AddAwardTo(s, { name = "Kim", item = 30009, kind = "-", src = "Mutter Shahraz", t = T(21, 32) })
NS.AddAwardTo(s, { name = "Fraktur", item = 30008, kind = "MS", src = "Gathios der Zerschmetterer", t = T(21, 53) })
NS.AddAwardTo(s, { name = "Anna", item = 30010, kind = "MS", src = "Wächter der Illidari", t = T(22, 0) })
NS.AddAwardTo(s, { name = "Vulobank", item = 30005, src = "Illidan Sturmgrimm", t = T(22, 1), to = "bank" })
NS.AddAwardTo(s, { item = 30006, src = "Supremus", t = T(20, 44), to = "de" })
NS.AddAwardTo(s, { item = 30007, src = "?", t = T(21, 1), to = "de" })
local gone = NS.AddAwardTo(s, { name = "Anna", item = 30007, kind = "MS", src = "Supremus", t = T(20, 45) })
NS.DeleteAward(s, gone.id)

---------------------------------------------------------------------------
-- the whole text
---------------------------------------------------------------------------
local parts, total = NS.RaidSummary(s)
assert(#parts == 1, #parts)
local text = parts[1]
assert(total == chars(text), ("total %s, text %d"):format(tostring(total), chars(text)))
local L = lines(text)
assert(L[1] == "**Schwarzer Tempel** · Freitag, 02.10.2026 · 20:02 bis 23:10", L[1])
assert(L[2] == "Bosse: 4 · Wipes: 5 · Raider: 5 · zu spät: 2 · Ersatzbank: 3", L[2])
local expect = {
    "**Bosse**",
    "20:14 Hochkriegsfürst Naj'entus (Kampf 3:12)",
    "20:41 Supremus (2 Wipes, Kampf 4:05)",
    "ca. 21:30 Mutter Shahraz (aus dem Lootfenster)",
    "21:50 Der Illidari-Rat",
    "23:00 Illidan Sturmgrimm (3 Wipes, kein Kill)",
    "",
    "**Loot**",
    "__Hochkriegsfürst Naj'entus__ 20:14",
    "- Zahn des Naj'entus: Fraktur (MS)",
    "- Halskette der Tiefe: Vulo Sturmwind (SR)",
    "__Supremus__ 20:41",
    "- Klinge des Supremus: Anna (OS) · Tausch mit Bob",
    "__Mutter Shahraz__ ca. 21:30",
    "- Halskette der Verführung: Kim",
    "__Der Illidari-Rat__ 21:50",
    "- Robe des Rates: Fraktur (MS)",
    "__Wächter der Illidari__",
    "- Stiefel der Wache: Anna (MS)",
    "__Ohne Boss__",
    "- Schulterpolster der ewigen Gnade: Chorf (MS)",
    "Bank: Kriegsklinge von Azzinoth",
    "Entzaubert: Umhang der Hochgeborenen, Ring des Zorns",
    "",
    "**Zu spät:** Chorf (20:12), Anna (20:31)",
    "**Ersatzbank:** Bob (ab 21 Uhr), Fred, Kim (eingewechselt 21:40)",
}
assert(L[3] == "", "a blank line after the head")
for i, want in ipairs(expect) do
    assert(L[3 + i] == want, ("line %d: '%s', expected '%s'\n%s"):format(3 + i, tostring(L[3 + i]), want, text))
end
assert(#L == 3 + #expect, "nothing after the bench:\n" .. text)
assert(not has(text, "|c") and not has(text, "|H"), "no colour codes, no links")
assert(not has(text, "Dabei"), "names only with raidlog.discordNames")
for c in text:gmatch("[\196-\255][\128-\191]") do error("character above Latin-1 in the text: " .. c) end

---------------------------------------------------------------------------
-- settings: the section raidlog gets the Discord items, officers only
---------------------------------------------------------------------------
for _, key in ipairs({ "raidlog.discordWipes", "raidlog.discordLoot", "raidlog.discordNames", "raidlog.discordHead" }) do
    local it = NS.SettingItem(key)
    assert(it and it.officer and it.section.key == "raidlog", key)
end
assert(NS.SettingItem("raidlog.discordWipes").default == true and NS.SettingItem("raidlog.discordLoot").default == true)
assert(NS.SettingItem("raidlog.discordNames").default == false and NS.SettingItem("raidlog.discordHead").default == "")
assert(NS.SettingItem("raidlog.discordWipes").label == "Wipes im Discord-Text")
assert(NS.SettingItem("raidlog.discordHead").type == "text" and NS.SettingItem("raidlog.discordHead").label == "Erste Zeile im Discord-Text")
assert(NS.Set("raidlog.discordHead", "Amisia | Raid\nbericht <@&123>"))
assert(NS.Get("raidlog.discordHead") == "Amisia  Raid bericht <@&123>", NS.Get("raidlog.discordHead"))
assert(NS.Set("raidlog.discordHead", ("x"):rep(100)) and #NS.Get("raidlog.discordHead") == 80, "at most 80 characters")
assert(NS.Set("raidlog.discordHead", "") and NS.Get("raidlog.discordHead") == "", "empty switches it off")

-- the head line first
NS.Set("raidlog.discordHead", "Raid-Bericht <@&123>")
text = NS.RaidSummary(s)[1]
L = lines(text)
assert(L[1] == "Raid-Bericht <@&123>" and L[2] == "**Schwarzer Tempel** · Freitag, 02.10.2026 · 20:02 bis 23:10", text)
NS.Reset("raidlog.discordHead")

-- without wipes
NS.Set("raidlog.discordWipes", false)
text = NS.RaidSummary(s)[1]
assert(lines(text)[2] == "Bosse: 4 · Raider: 5 · zu spät: 2 · Ersatzbank: 3", lines(text)[2])
assert(lineIndex(text, "20:41 Supremus (Kampf 4:05)") and not has(text, "Wipe") and not has(text, "kein Kill"), text)
NS.Reset("raidlog.discordWipes")

-- without loot
NS.Set("raidlog.discordLoot", false)
text = NS.RaidSummary(s)[1]
assert(not has(text, "**Loot**") and not has(text, "Bank:") and not has(text, "Zahn"), text)
assert(has(text, "**Bosse**") and has(text, "**Zu spät:**"), text)
NS.Reset("raidlog.discordLoot")

-- every name
NS.Set("raidlog.discordNames", true)
text = NS.RaidSummary(s)[1]
assert(lineIndex(text, "**Dabei:** Anna, Chorf, Fraktur, Kim, Vulo Sturmwind"), text)
NS.Reset("raidlog.discordNames")

---------------------------------------------------------------------------
-- group loot: no hand-outs, the looted items instead
---------------------------------------------------------------------------
local g = raid("20261002200000-565")
g.members = { Fraktur = { class = "SHAMAN", first = T(20, 2), last = T(23, 10) } }
g.items = { { name = "Fraktur", item = 30001, count = 2, t = T(20, 15) }, { name = "Fraktur", item = 30003, count = 1, t = T(20, 50) } }
text = NS.RaidSummary(g)[1]
assert(lineIndex(text, "**Geplündert**") and lineIndex(text, "- Zahn des Naj'entus: Fraktur x2")
    and lineIndex(text, "- Klinge des Supremus: Fraktur"), text)
assert(lineIndex(text, "**Geplündert**") < lineIndex(text, "- Zahn des Naj'entus: Fraktur x2"))
assert(not has(text, "**Loot**") and not has(text, "Keine Bosse"), text)
assert(lines(text)[2] == "Bosse: 0 · Raider: 1", lines(text)[2])

-- a raid without anything: the head and one line
local e = raid("20261002200000-566")
e.firstScan = nil
parts = NS.RaidSummary(e)
assert(#parts == 1 and lines(parts[1])[1] == "**Schwarzer Tempel** · Freitag, 02.10.2026 · 20:00 bis 23:10", parts[1])
assert(lineIndex(parts[1], "Keine Bosse, kein Loot."), parts[1])
assert(not has(parts[1], "zu spät") and not has(parts[1], "Ersatzbank"), "zero counts stay out: " .. parts[1])

---------------------------------------------------------------------------
-- Markdown escapes
---------------------------------------------------------------------------
assert(NS.DiscordEscape("a\\b*c_d~e`f|g>h#i[j]k") == "a\\\\b\\*c\\_d\\~e\\`f\\|g\\>h\\#i\\[j\\]k", NS.DiscordEscape("a\\b*c_d~e`f|g>h#i[j]k"))
assert(NS.DiscordEscape("Naj'entus - (1)") == "Naj'entus - (1)", "other characters stay")
STUB.item(30011, "Klinge *Sturm* ~x~", 4)
local x = raid("20261002200000-567")
x.zone = "Zone_X"
x.members = { Under_Score = { class = "MAGE", first = T(20, 2), last = T(23, 10) } }
x.bench = { ["Star*Name"] = { t = T(19, 0), class = "", by = "Vuloo", note = "erst_ab #9" } }
NS.AddAwardTo(x, { name = "Under_Score", item = 30011, kind = "MS", src = "Boss_Eins", t = T(20, 30) })
text = NS.RaidSummary(x)[1]
assert(lines(text)[1] == "**Zone\\_X** · Freitag, 02.10.2026 · 20:02 bis 23:10", lines(text)[1])
assert(lineIndex(text, "__Boss\\_Eins__"), text)
assert(lineIndex(text, "- Klinge \\*Sturm\\* \\~x\\~: Under\\_Score (MS)"), text)
assert(lineIndex(text, "**Ersatzbank:** Star\\*Name (erst\\_ab \\#9)"), text)

---------------------------------------------------------------------------
-- parts of at most 1900 characters
---------------------------------------------------------------------------
-- a long loot section: split at line ends, every part from the second with its own head
local big = raid("20261002200000-568")
big.members = { Fraktur = { class = "SHAMAN", first = T(20, 2), last = T(23, 10) } }
for i = 1, 90 do
    local id = 31000 + i
    STUB.item(id, ("Langer Gegenstand der Prüfung Nummer %d"):format(i), 4)
    NS.AddAwardTo(big, { name = "Fraktur", item = id, kind = "MS", src = "Supremus", t = T(20, 30) + i })
end
parts, total = NS.RaidSummary(big)
assert(#parts >= 3, "split into parts: " .. #parts)
local sum = 0
for i, p in ipairs(parts) do
    assert(chars(p) <= 1900, ("part %d has %d characters"):format(i, chars(p)))
    if i > 1 then assert(lines(p)[1] == ("**Schwarzer Tempel, 02.10. (Teil %d)**"):format(i), lines(p)[1]) end
    assert(p:sub(-1) ~= "\n" and p:sub(1, 1) ~= "\n", "no blank line at the edges of a part")
    sum = sum + chars(p)
end
assert(total > 1900 and total < sum, ("total %d of the text, parts %d"):format(total, sum))
for i = 1, 90 do
    local want = ("- Langer Gegenstand der Prüfung Nummer %d: Fraktur (MS)"):format(i)
    local found = 0
    for _, p in ipairs(parts) do if lineIndex(p, want) then found = found + 1 end end
    assert(found == 1, want .. " in one part")
end

-- a section that does not fit any more starts the next part whole
local mid = raid("20261002200000-569")
mid.members = {}
for i = 1, 30 do
    local name = ("Spieler%s"):format(string.char(64 + math.ceil(i / 26), 96 + ((i - 1) % 26) + 1))
    mid.members[name] = { class = "MAGE", first = T(20, 10) + i * 60, last = T(23, 10), late = true }
end
for i = 1, 25 do
    NS.AddAwardTo(mid, { name = "Fraktur", item = 31000 + i, kind = "MS", src = "Supremus", t = T(20, 30) + i })
end
parts = NS.RaidSummary(mid)
assert(#parts == 2, #parts)
assert(not has(parts[1], "**Zu spät:**"), "the late section moves whole")
assert(lines(parts[2])[1] == "**Schwarzer Tempel, 02.10. (Teil 2)**" and has(lines(parts[2])[2], "**Zu spät:**"), parts[2])
assert(lineIndex(parts[1], "- Langer Gegenstand der Prüfung Nummer 25: Fraktur (MS)"), "the loot stays in part 1")

---------------------------------------------------------------------------
-- /amisia discord
---------------------------------------------------------------------------
local help = table.concat(NS.SlashHelpLines(true), "\n")
assert(has(help, "/amisia discord"), help)
assert(not has(table.concat(NS.SlashHelpLines(false), "\n"), "/amisia discord"), "for officers")
local msgs = #STUB.messages
NS.Set("ui.view", "raider")
NS.Dispatch("discord")
assert(has(STUB.messages[#STUB.messages], "Offiziersansicht"), tostring(STUB.messages[#STUB.messages]))
NS.Reset("ui.view")
if NS.ShowRaidLog then
    NS.Dispatch("discord")
    assert(NS.CurrentPage() == "raidlog", "the page, view Discord")
else
    msgs = #STUB.messages
    NS.Dispatch("discord")
    assert(#STUB.messages > msgs and has(table.concat(STUB.messages, "\n", msgs + 1), "Discord-Text"), "a note in the chat")
end

---------------------------------------------------------------------------
-- Latin-1 only in the file
---------------------------------------------------------------------------
local src = assert(io.open(ADDON_DIR .. "/Raid/RaidText.lua", "rb")):read("*a")
for c in src:gmatch("[\196-\255][\128-\191]") do error("RaidText.lua: character above Latin-1: " .. c) end
