-- The lineup (Raid/Lineup.lua, D-41): the three kinds of text (the block, "Name Rolle" lines, a
-- sign-up bot's text with headings, emoji, numbering and times), the match statuses (found, likely,
-- ambiguous first names, typos, unknown, guests, remembered fixes), the role from the list, the last
-- lineup or the class, "Automatisch einteilen" (tanks from group 1, a healer per group, melee with a
-- shaman or warrior, ranged together, overflow to the bench, held players stay), swap and move,
-- saving per night and the cleanup on load, the guest setting, the bench through ns.BenchAdd, and
-- that a raider gets nothing.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local LU = NS._lineup
local function byName(list)
    local out = {}
    for i, e in ipairs(list) do out[e.n] = e; e._i = i end
    return out
end

STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Vulo Hunt", rank = 3, class = "HUNTER" },
    { name = "Vulo Pala", rank = 3, class = "PALADIN", level = 52 },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Kim Sturmwind", rank = 3, class = "ROGUE", online = false },
    { name = "Kleinfrak", rank = 4, class = "MAGE" },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
assert(NS.LineupAllowed(), "an officer by rank in the officer view")

---------------------------------------------------------------------------
-- small parts: one letter off, the folding
---------------------------------------------------------------------------
assert(LU.oneOff("anna", "anan") and LU.oneOff("anna", "ana") and LU.oneOff("anna", "annna") and LU.oneOff("anna", "anne"))
assert(not LU.oneOff("anna", "anna") and not LU.oneOff("anna", "bob") and not LU.oneOff("anna", "bnnb"))
assert(LU.norm("Jäger") == LU.norm("JAEGER") and LU.norm("Müller") == LU.norm("mueller"), "umlauts do not count")

---------------------------------------------------------------------------
-- parsing: plain lines in German and English, odd spacing, numbering
---------------------------------------------------------------------------
local res = NS.ParseLineup("Vulo Hunt Tank\n  vulo pala   heiler \nBob, Nahkampf\n3) Anna Bergmann Healer\nKim - Rogue\n\n")
assert(res and #res.list == 5, res and #res.list)
local p = byName(res.list)
assert(p["Vulo Hunt"].r == "T" and p["vulo pala"].r == "H" and p["Bob"].r == "M" and p["Anna Bergmann"].r == "H")
assert(p["Kim"].c == "ROGUE" and p["Kim"].r == nil, "a class word sets the class")
assert(p["vulo pala"].n1 == "vulo" and p["vulo pala"].c1 == "PALADIN", "a class word as surname is kept both ways")
-- doubles count once, the first line wins; empty text is refused
res = NS.ParseLineup("Anna Tank\nanna heiler")
assert(#res.list == 1 and res.list[1].r == "T")
local none, why = NS.ParseLineup("\n  \n---\n")
assert(none == nil and why == "Kein Name erkannt.", tostring(why))
-- digits and bars never make a name; a sentence is no sign-up
res = NS.ParseLineup("|cffff0000Gast2|r Tank\nIch komme heute später rein\nAnna Tank")
assert(#res.list == 1 and res.list[1].n == "Anna", "only Anna: " .. tostring(res.list[1].n))

-- a sign-up bot's text: headings with counts, bold, emoji codes, numbers, times, absent, bench
local bot = table.concat({
    "**Molten Core** - Donnerstag 20:00",
    "Leader: Vuloo",
    "Tanks (2)",
    "1. <:Warrior:123456789> **Bob Eisherz** 19:40",
    "2. :Paladin: Vulo Pala `12`",
    "",
    "__**Healers**__ (2)",
    "3) \240\159\146\154 Anna Bergmann",
    "4) :Priest: Vuloo (ab 21 Uhr)",
    "Melee:",
    "- Kim Sturmwind",
    "Ranged - 1",
    "\226\128\162 Kleinfrak <t:1789000000:R>",
    "Bench",
    "5. Vulo Hunt",
    "Abgemeldet (1)",
    "Niemand Nirgends",
    "Tentative: Gustav",
}, "\n")
res = NS.ParseLineup(bot)
p = byName(res.list)
assert(#res.list == 9, #res.list)
assert(not p["Molten Core"] and not p["Leader"] and not p["Donnerstag"], "headings and notes of the bot are no names")
assert(p["Bob Eisherz"].r == "T" and p["Bob Eisherz"].c == "WARRIOR", "emoji class and heading role")
assert(p["Vulo Pala"].r == "T" and p["Vulo Pala"].c == "PALADIN")
assert(p["Anna Bergmann"].r == "H" and p["Vuloo"].r == "H" and p["Vuloo"].c == "PRIEST", "a note in brackets falls away")
assert(p["Kim Sturmwind"].r == "M" and p["Kleinfrak"].r == "R")
assert(p["Vulo Hunt"].b and not p["Vulo Hunt"].a, "bench heading")
assert(p["Niemand Nirgends"].a, "absent heading")
assert(p["Gustav"].m, "tentative inline heading")
-- English headings: Tanks, Healers, Bench (the acceptance check)
res = NS.ParseLineup("Tanks\nVulo Hunt\nHealers\nAnna Bergmann\nBench\nBob Eisherz")
p = byName(res.list)
assert(p["Vulo Hunt"].r == "T" and p["Anna Bergmann"].r == "H" and p["Bob Eisherz"].b)
-- inline heading list
res = NS.ParseLineup("Tanks: Bob Eisherz, Vulo Hunt\nHeiler: Anna Bergmann")
p = byName(res.list)
assert(p["Bob Eisherz"].r == "T" and p["Vulo Hunt"].r == "T" and p["Anna Bergmann"].r == "H")

-- the text of the feature's check (FEATURES F-083)
res = NS.ParseLineup("Tanks\nAnna Tankfrau\nHealers\nBert Heilmann\nBench\nCarl Bankmann")
p = byName(res.list)
assert(p["Anna Tankfrau"].r == "T" and p["Bert Heilmann"].r == "H" and p["Carl Bankmann"].b)

-- the block
res = NS.ParseLineup("#AMISIA-RAID 1 forever 2026-10-15 Geschmolzener Kern\nS Vulo_Hunt T HUNTER -\nS Anna_Bergmann H - B\nS Bob M WARRIOR ?\nS Gast2 T - -\nS Kim X - -\n#END")
assert(res and res.block and res.date == "2026-10-15" and res.title == "Geschmolzener Kern")
p = byName(res.list)
assert(#res.list == 3 and res.skipped == 2, "bad lines skipped")
assert(p["Vulo Hunt"].r == "T" and p["Vulo Hunt"].c == "HUNTER" and p["Anna Bergmann"].b and p["Bob"].m)
none, why = NS.ParseLineup("#AMISIA-RAID 1 tbc 2026-10-15\nS Bob M - -\n#END")
assert(none == nil and has(why, "tbc"), tostring(why))
-- the block also comes through the shared site paste
assert(NS.SiteBlocks("x\n#AMISIA-RAID 1 forever 2026-10-15\nS Bob M - -\n#END").raid, "SiteBlocks knows the block")

-- 80 sign-ups at most, more are counted
local many = {}
for i = 1, 85 do many[i] = "Name" .. string.char(64 + math.floor(i / 26) + 1) .. string.char(97 + i % 26) .. string.char(97 + math.floor(i / 3) % 26) .. " Tank" end
res = NS.ParseLineup(table.concat(many, "\n"))
assert(#res.list == 80 and res.over == 5, #res.list .. " " .. tostring(res.over))

---------------------------------------------------------------------------
-- matching: found, likely, ambiguous first names, typos, unknown, guests, fixes
---------------------------------------------------------------------------
STUB.roster = { { name = "Fremdling Weit", class = "MAGE" } }   -- in the group, not in the guild
local tonight = NS.LineupTonight()
-- an earlier night: "Kleinfrak Magier" is the name alone with the class word (it gives the role)
NS.SetLineupText("Kleinfrak Magier Fernkampf\nAnna Bergmann Heiler", "2026-10-01")
local other = byName(NS.LineupNight("2026-10-01").list)
assert(other["Kleinfrak"] and other["Kleinfrak"].x == nil and other["Kleinfrak"].r == "R" and not other["Kleinfrak"].q,
    "class word after a unique name")
STUB.messages = {}
local key, line = NS.SetLineupText("Vulo Hunt Tank\nvulo pala heiler\nNiemand Nirgends Nahkampf\nVulo\nAnna\nBob Eisherx\nFremdling Weit\nKleinfrak")
assert(key == tonight and has(line, "Aufstellung: 8 Anmeldungen, 3 gefunden, 2 vermutlich, 1 nicht eindeutig, 1 unbekannt, 1 Gäste."), line)
local n = NS.LineupNight(tonight)
p = byName(n.list)
assert(p["Vulo Hunt"].x == nil and p["Vulo Pala"].x == nil and p["Vulo Pala"].s == nil, "found, case and umlauts aside")
assert(p["Niemand Nirgends"].x == "u", "unknown")
assert(p["Vulo"].x == "a" and #p["Vulo"].o == 2 and p["Vulo"].o[1] == "Vulo Hunt", "two members are called Vulo")
assert(p["Anna Bergmann"].x == "l" and p["Anna Bergmann"].s == "Anna", "a unique first name is likely")
assert(p["Bob Eisherz"].x == "l" and p["Bob Eisherz"].s == "Bob Eisherx", "one letter off is likely")
assert(p["Fremdling Weit"].x == "g", "in the group, not in the guild: guest")
assert(p["Kleinfrak"].x == nil and p["Kleinfrak"].c == "MAGE")
-- a surname that is a class word: "Vulo Pala" stays one name
assert(p["Vulo Pala"].c == "PALADIN" and p["Vulo Pala"].r == "H")

-- roles: from the list, else the last lineup, else guessed from the class (grey "?")
assert(p["Kleinfrak"].r == "R" and not p["Kleinfrak"].q, "the earlier night's role, not a guess")
assert(p["Fremdling Weit"].r == "R" and p["Fremdling Weit"].q, "a mage guest: ranged, guessed from the group's class")
assert(p["Anna Bergmann"].r == "H" and not p["Anna Bergmann"].q, "Anna was a healer on 2026-10-01")
assert(p["Bob Eisherz"].r == "M" and p["Bob Eisherz"].q, "warrior: melee, guessed")

-- confirm a likely one, choose an ambiguous one, type an unknown one (remembered)
assert(NS.LineupConfirm(tonight, p["Anna Bergmann"]._i))
assert(n.list[p["Anna Bergmann"]._i].x == nil and AmisiaDB.srAliases["anna"] == "Anna Bergmann", "confirmed and remembered")
assert(NS.LineupConfirm(tonight, p["Vulo"]._i, "Vuloo"))
assert(n.list[p["Vulo"]._i].n == "Vuloo" and n.list[p["Vulo"]._i].x == nil and AmisiaDB.srAliases["vulo"] == nil,
    "a choice between first names is not remembered")
local ok, err = NS.LineupConfirm(tonight, p["Niemand Nirgends"]._i, "Vulo Hunt")
assert(ok == nil and err == "Vulo Hunt steht schon in der Liste.", tostring(err))
assert(NS.LineupConfirm(tonight, p["Niemand Nirgends"]._i, "Kim Sturmwind"))
assert(n.list[p["Niemand Nirgends"]._i].n == "Kim Sturmwind" and AmisiaDB.srAliases["niemand nirgends"] == "Kim Sturmwind")
-- next week the fix holds by itself
NS.SetLineupText("Niemand Nirgends Nahkampf", "2026-10-02")
assert(NS.LineupNight("2026-10-02").list[1].n == "Kim Sturmwind" and NS.LineupNight("2026-10-02").list[1].x == nil)

-- the guild roster cannot be read: the chat says so
local guild = STUB.guild
STUB.guild = {}
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
key, line = NS.SetLineupText("Anna Tank", "2026-10-03")
assert(has(line, "Gildenliste noch nicht geladen, gleich nochmal."), line)
-- without the roster every name is unknown, but the planner still places them (by the list's roles)
key = NS.SetLineupText("Anna Tank\nNiemand Nirgends Heiler\nBob Fernkampf", "2026-10-03")
NS.LineupAutoAssign("2026-10-03")
local unk = NS.LineupNight("2026-10-03").list
for _, e in ipairs(unk) do assert(e.x == "u" and e.g, e.n) end
assert(unk[1].g == 1 and unk[2].g == 1 and unk[3].g == 2, "tank and healer in group 1, the ranged in the next")
STUB.guild = guild
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)

---------------------------------------------------------------------------
-- alt online: Kim is offline, her alt Kleinfrak online (the site's alt list)
---------------------------------------------------------------------------
NS.SetAlts("#AMISIA-ALTS 1 forever 2026-10-01\nA Kleinfrak Kim_Sturmwind\n#END")
local people = NS.LineupPeople()
local kim = { n = "Kim Sturmwind" }
assert(NS.LineupAltOnline(kim, people, {}) == "Kleinfrak", "one alt online")
assert(NS.LineupAltOnline(kim, people, { { n = "Kleinfrak" } }) == nil, "not when the alt signed up himself")
assert(NS.LineupAltOnline({ n = "Anna Bergmann" }, people, {}) == nil, "online herself")

---------------------------------------------------------------------------
-- Automatisch einteilen: 40 sign-ups, 8 healers
---------------------------------------------------------------------------
local CL = { "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "SHAMAN", "DRUID", "PALADIN" }
local function nameOf(i) return "Raider" .. string.char(96 + math.floor((i - 1) / 26) + 1) .. string.char(96 + (i - 1) % 26 + 1) end
local big = {}
STUB.guild = { { name = "Vuloo", rank = 2, class = "PRIEST" } }
local lines = {}
-- 3 tanks (warriors), 8 healers (2 shamans, 3 priests, 2 druids, 1 paladin), 15 melee (rogues,
-- warriors, 2 shamans), 14 ranged (hunters, mages, warlocks)
local plan = {}
for i = 1, 3 do plan[#plan + 1] = { "WARRIOR", "Tank" } end
for _, c in ipairs({ "SHAMAN", "SHAMAN", "PRIEST", "PRIEST", "PRIEST", "DRUID", "DRUID", "PALADIN" }) do plan[#plan + 1] = { c, "Heiler" } end
for i = 1, 15 do plan[#plan + 1] = { i <= 9 and "ROGUE" or (i <= 13 and "WARRIOR" or "SHAMAN"), "Nahkampf" } end
for i = 1, 14 do plan[#plan + 1] = { ({ "HUNTER", "MAGE", "WARLOCK" })[i % 3 + 1], "Fernkampf" } end
for i, x in ipairs(plan) do
    big[i] = { name = nameOf(i), class = x[1], role = x[2] }
    STUB.guild[#STUB.guild + 1] = { name = nameOf(i), rank = 3, class = x[1] }
    lines[i] = nameOf(i) .. " " .. x[2]
end
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
local night = "2026-10-20"
NS.SetLineupText(table.concat(lines, "\n"), night)
NS.Set("lineup.size", 40)
local placed, over = NS.LineupAutoAssign(night)
assert(placed == 40 and over == 0, placed .. " " .. over)
local c = NS.LineupCounts(night)
assert(c.T == 3 and c.H == 8 and c.M == 15 and c.R == 14 and c.bench == 0 and #c.noHealer == 0, "the counts")
n = NS.LineupNight(night)
local G = {}
for g = 1, 8 do G[g] = { n = 0, T = 0, H = 0, M = 0, R = 0, cls = {} } end
for _, e in ipairs(n.list) do
    local b = G[e.g]
    b.n, b[e.r] = b.n + 1, b[e.r] + 1
    b.cls[e.c] = (b.cls[e.c] or 0) + 1
end
for g = 1, 8 do
    assert(G[g].n == 5 and G[g].H >= 1, "group " .. g .. " has five and a healer")
end
assert(G[1].T == 1 and G[2].T == 1 and G[3].T == 1, "tanks from group 1")
for g = 1, 8 do
    if G[g].M > 0 then
        assert((G[g].cls.WARRIOR or 0) + (G[g].cls.SHAMAN or 0) > 0, "a warrior or shaman in melee group " .. g)
    end
end
-- ranged together: the ranged groups hold no melee
local rangedGroups = 0
for g = 1, 8 do
    if G[g].R >= 3 then
        rangedGroups = rangedGroups + 1
        assert(G[g].M == 0 and G[g].T == 0, "a ranged group without melee: " .. g)
    end
end
assert(rangedGroups >= 3, rangedGroups)
-- the shamans heal the melee groups, the priests and druids the others
for _, e in ipairs(n.list) do
    if e.r == "H" and e.c == "SHAMAN" then assert(G[e.g].M > 0 or G[e.g].T > 0, "shaman healer with the melee") end
end

-- hold: a held player stays where he is when assigning again; swap; a full group refuses
local mage
for i, e in ipairs(n.list) do if e.c == "MAGE" then mage = i break end end
local was = n.list[mage].g
local target = was == 1 and 2 or 1
local other
for i, e in ipairs(n.list) do if e.g == target then other = i break end end
assert(NS.LineupSwap(night, mage, other))
assert(n.list[mage].g == target and n.list[other].g == was, "swapped")
local okMove, full = NS.LineupMove(night, mage, was)
assert(okMove == nil and full == ("Gruppe %d ist voll."):format(was), tostring(full))
assert(NS.LineupHold(night, mage, true))
NS.LineupAutoAssign(night)
assert(n.list[mage].g == target and n.list[mage].k, "held stays in place")
assert(#NS.LineupCounts(night).noHealer == 0)

-- overflow: 45 sign-ups for 40 places: tanks and healers first, then the list's order; the rest
-- on the bench as overflow
local extra = {}
for i = 41, 45 do
    STUB.guild[#STUB.guild + 1] = { name = nameOf(i), rank = 3, class = "MAGE" }
    extra[#extra + 1] = nameOf(i) .. " Fernkampf"
end
-- a late healer at the end of the list still gets in
STUB.guild[#STUB.guild + 1] = { name = "Spaetheiler", rank = 3, class = "PRIEST" }
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
-- one healer less in the list (seven before the extra ranged), the eighth healer signs up last
local fewer = {}
for i, ln in ipairs(lines) do if i ~= 6 then fewer[#fewer + 1] = ln end end
NS.SetLineupText(table.concat(fewer, "\n") .. "\n" .. table.concat(extra, "\n") .. "\nSpaetheiler Heiler", night)
NS.LineupHold(night, mage, false)
placed, over = NS.LineupAutoAssign(night)
assert(placed == 40 and over == 5, placed .. " " .. over)
p = byName(NS.LineupNight(night).list)
assert(p["Spaetheiler"].g, "healers before the list's order")
assert(p[nameOf(45)].v and not p[nameOf(45)].g, "the last of the list is overflow")
assert(NS.LineupCounts(night).bench == 5 and #NS.LineupCounts(night).noHealer == 0)

-- raid size 20: four groups, tanks and healers first
NS.Set("lineup.size", 20)
placed, over = NS.LineupAutoAssign(night)
assert(placed == 20 and over == 25, placed .. " " .. over)
for _, e in ipairs(NS.LineupNight(night).list) do assert(not e.g or e.g <= 4) end
assert(#NS.LineupCounts(night).noHealer == 0)
NS.Set("lineup.size", 40)

---------------------------------------------------------------------------
-- guests: listed as "Gast", placed only with the setting
---------------------------------------------------------------------------
STUB.roster = { { name = "Fremdling Weit", class = "MAGE" } }
NS.SetLineupText("Fremdling Weit Fernkampf\nVuloo Heiler", "2026-10-21")
local gn = NS.LineupNight("2026-10-21")
assert(gn.list[1].x == "g")
NS.LineupAutoAssign("2026-10-21")
assert(gn.list[1].g == nil and gn.list[2].g, "a guest is not placed without the setting")
local okG, whyG = NS.LineupMove("2026-10-21", 1, 3)
assert(okG == nil and whyG == "Gäste nur mit der Einstellung \"Gäste einladen\".", tostring(whyG))
NS.Set("lineup.guests", true)
NS.LineupAutoAssign("2026-10-21")
assert(gn.list[1].g, "placed with the setting")
NS.Set("lineup.guests", false)
STUB.roster = {}

---------------------------------------------------------------------------
-- saving per night: survives a reload (the cleanup changes nothing good), 8 nights, bad fields
---------------------------------------------------------------------------
local before = NS.LineupNight(night)
local copy = {}
for i, e in ipairs(before.list) do copy[i] = { n = e.n, g = e.g, k = e.k, r = e.r } end
NS.LineupLoaded(AmisiaDB)
NS.LineupLoaded(AmisiaDB)
local after = NS.LineupNight(night)
for i, e in ipairs(after.list) do
    assert(e.n == copy[i].n and e.g == copy[i].g and e.r == copy[i].r, "kept by the cleanup: " .. e.n)
end
local root = { lineup = { v = 1, nights = {
    ["2026-09-01"] = { size = 99, list = { { n = "Gast2" }, { n = "Anna", r = "X", g = 12, b = "ja", c = "PIRATE" }, { n = "anna" },
                                            { n = "Bob", a = true, g = 3 }, "kaputt" } },
    ["kaputt"] = { list = {} },
} } }
for d = 2, 10 do root.lineup.nights[("2026-09-%02d"):format(d)] = { list = { { n = "Bob" } } } end
NS.LineupLoaded(root)
local nightsLeft = 0
for _ in pairs(root.lineup.nights) do nightsLeft = nightsLeft + 1 end
assert(nightsLeft == 8 and root.lineup.nights["2026-09-10"] and not root.lineup.nights["2026-09-01"], "8 newest nights")
root = { lineup = { v = 1, nights = { ["2026-09-01"] = { size = 99, list = { { n = "Gast2" }, { n = "Anna", r = "X", g = 12, b = "ja", c = "PIRATE" },
    { n = "anna" }, { n = "Bob", a = true, g = 3 }, "kaputt" } } } } }
NS.LineupLoaded(root)
local l = root.lineup.nights["2026-09-01"]
assert(l.size == 40 and #l.list == 2, #l.list)
assert(l.list[1].n == "Anna" and l.list[1].r == nil and l.list[1].g == nil and l.list[1].b == nil and l.list[1].c == nil, "fields checked")
assert(l.list[2].n == "Bob" and l.list[2].a and l.list[2].g == nil, "the absent are not placed")
root = { lineup = "kaputt" }
NS.LineupLoaded(root)
assert(root.lineup == nil)

---------------------------------------------------------------------------
-- Teil E: bench and overflow who are online go on tonight's bench through ns.BenchAdd
---------------------------------------------------------------------------
STUB.guild = guild
table.insert(STUB.guild, { name = "Ersatzmann", rank = 3, class = "WARLOCK" })
table.insert(STUB.guild, { name = "Schlafmuetze", rank = 3, class = "MAGE", online = false })
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.SetLineupText("Vulo Hunt Tank\nAnna Bergmann Heiler\nErsatz\nErsatzmann\nSchlafmuetze\nAbgemeldet\nBob Eisherz")
local added, left = NS.LineupBench(tonight)
assert(added and #added == 1 and added[1] == "Ersatzmann" and left == 1, "the offline one stays off")
local s = NS.BenchTarget()
local e = NS.IsBenched(s, "Ersatzmann")
assert(e and e.note == "Aufstellung" and e.by == "Vuloo" and e.class == "WARLOCK", "with the note")
assert(not NS.IsBenched(s, "Bob Eisherz"), "the absent never")
assert(has(NS.LineupBenchMessage(added, left), "Ersatzbank: Ersatzmann (Notiz \"Aufstellung\")."))
local noBench, whyB = NS.LineupBench("2026-10-01")
assert(noBench == nil and whyB == "Die Ersatzbank gilt nur für heute.")
-- without a guild roster oneself still counts as online and goes on the bench
STUB.guild = {}
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.SetLineupText("Ersatz\nVuloo")
assert(NS.LineupNight().list[1].x == nil, "oneself is found without the guild")
added = NS.LineupBench(tonight)
assert(added and added[1] == "Vuloo", "oneself on the bench")
NS.BenchRemove(NS.BenchTarget(), "Vuloo")
STUB.guild = guild
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
NS.SetLineupText("Vulo Hunt Tank\nAnna Bergmann Heiler\nErsatz\nErsatzmann\nSchlafmuetze\nAbgemeldet\nBob Eisherz")
-- automatic: off by default; on, the first recording of the night takes the bench
assert(NS.Get("lineup.autoBench") == false)
NS.BenchRemove(NS.BenchTarget(), "Ersatzmann")
NS.Set("lineup.autoBench", true)
NS.Fire("RECORDING", { members = {}, date = tonight })
assert(NS.IsBenched(NS.BenchTarget(), "Ersatzmann"), "benched when the recording runs")
NS.Set("lineup.autoBench", false)

---------------------------------------------------------------------------
-- copy an earlier night; remove
---------------------------------------------------------------------------
local copied = NS.LineupCopy("2026-10-01", "2026-10-05")
assert(copied == 2 and #NS.LineupNight("2026-10-05").list == 2)
local again, whyC = NS.LineupCopy("2026-10-01", "2026-10-05")
assert(again == nil and whyC == "Diese Nacht hat schon eine Aufstellung.")
assert(NS.LineupRemove("2026-10-05", 1) and #NS.LineupNight("2026-10-05").list == 1)

---------------------------------------------------------------------------
-- settings and the command; a raider gets nothing
---------------------------------------------------------------------------
for _, k in ipairs({ "lineup.size", "lineup.guests", "lineup.autoBench" }) do
    local it = NS.SettingItem(k)
    assert(it and it.section.key == "lineup" and it.section.officer, k)
end
assert(NS.SettingItem("lineup.size").default == 40 and NS.SettingItem("lineup.guests").default == false)
NS.Set("ui.view", "raider")
assert(not NS.LineupAllowed() and not NS.Visible(NS.Panel("lineup")) and not NS.Visible(NS.SettingItem("lineup.size").section))
STUB.messages = {}
NS.Dispatch("aufstellung")
assert(said("Die Aufstellung ist nur für Offiziere."), "the raider's answer")
-- the officer view alone is not enough without the officer rank
NS.Set("ui.view", "officer")
for _, m in ipairs(STUB.guild) do if m.name == "Vuloo" then m.rank = 4 end end
STUB.officer = false
STUB.rankFlags[2] = { [22] = true }
STUB.rankFlags[1] = { [22] = true }
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
assert(not NS.LineupAllowed(), "no officer rank, no lineup")
for _, m in ipairs(STUB.guild) do if m.name == "Vuloo" then m.rank = 2 end end
STUB.fire("GUILD_ROSTER_UPDATE"); STUB.tick(11)
assert(NS.LineupAllowed())
NS.Dispatch("lineup")
assert(NS.CurrentPage() == "lineup", "the English word opens the page")
