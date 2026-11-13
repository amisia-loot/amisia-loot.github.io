-- F-161 (D-91): the lineup without a sign-up list. The logic (Raid/Lineup.lua): a player by hand
-- (ns.LineupAdd), the groups of the raid (ns.LineupFromRaid), the templates (save, load, delete, 12
-- at most, cleaned on load), clear, the block with groups (ns.LineupExport and back through
-- ns.SetLineupText). The page: the planner on an empty night with the player list, a click on a
-- name and then on a place, the view "Vorlagen", the menu "Mehr", the block to copy.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function said(part)
    for _, m in ipairs(STUB.messages) do if has(m, part) then return m end end
    return nil
end
local function byName(list)
    local out = {}
    for i, e in ipairs(list) do out[e.n] = e; e._i = i end
    return out
end

STUB.instance = { name = "Shattrath", type = "none", id = 0 }
STUB.officer = true
STUB.guild = {
    { name = "Vuloo", rank = 2, class = "PRIEST" },
    { name = "Anna Bergmann", rank = 3, class = "PRIEST" },
    { name = "Bob Eisherz", rank = 3, class = "WARRIOR" },
    { name = "Cora Wind-Tal", rank = 3, class = "MAGE" },
    { name = "Dino Fels", rank = 3, class = "ROGUE" },
    { name = "Kim Sturmwind", rank = 3, class = "ROGUE", online = false },
}
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.Set("ui.view", "officer")
NS.Set("lineup.size", 10)
local tonight = NS.LineupTonight()

---------------------------------------------------------------------------
-- a player by hand
---------------------------------------------------------------------------
assert(NS.LineupNight(tonight, false) == nil, "nothing yet")
local i = NS.LineupAdd(tonight, "bob eisherz")
local n = NS.LineupNight(tonight, false)
assert(i == 1 and n.list[1].n == "Bob Eisherz" and n.list[1].c == "WARRIOR" and n.list[1].r == "M" and n.list[1].q
    and not n.list[1].g and not n.list[1].x, "the roster's spelling and class, a guessed role, not placed")
assert(NS.LineupAdd(tonight, "Bob Eisherz") == 1 and #n.list == 1, "the same name: the entry that is there")
local j = NS.LineupAdd(tonight, "Niemand Nirgends")
assert(j == 2 and n.list[2].x == "u", "a name nobody knows: unknown")
local bad, why = NS.LineupAdd(tonight, "Bob2")
assert(bad == nil and why == "Name fehlt.", tostring(why))
-- a name the officer removed comes back by hand
NS.LineupRemove(tonight, 2)
assert(n.gone and n.gone["niemand nirgends"])
NS.LineupAdd(tonight, "Niemand Nirgends")
assert(not (n.gone and n.gone["niemand nirgends"]), "no longer remembered as removed")
NS.LineupRemove(tonight, 2)
assert(NS.LineupMove(tonight, 1, 2))

---------------------------------------------------------------------------
-- templates
---------------------------------------------------------------------------
NS.LineupAdd(tonight, "Anna Bergmann")
NS.LineupAdd(tonight, "Cora Wind-Tal")
NS.LineupAdd(tonight, "Dino Fels")
local p = byName(n.list)
NS.LineupMove(tonight, p["Anna Bergmann"]._i, 1)
NS.LineupSetRole(tonight, p["Anna Bergmann"]._i, "H")
NS.LineupMove(tonight, p["Cora Wind-Tal"]._i, "bench")
NS.LineupHold(tonight, p["Bob Eisherz"]._i, true)
local none, whyNone = NS.LineupSaveSet(tonight, "   ")
assert(none == nil and whyNone == "Die Vorlage braucht einen Namen.")
assert(NS.LineupSaveSet("2026-01-01", "Leer") == nil, "an empty night saves nothing")
assert(NS.LineupSaveSet(tonight, " Stamm ") == 4)
local sets = NS.LineupSets()
assert(#sets == 1 and sets[1].name == "Stamm" and sets[1].count == 4 and sets[1].size == 10, "one template")
assert(NS.LineupSaveSet(tonight, "stamm") == 4 and #NS.LineupSets() == 1, "the same name replaces")
-- nothing of the night's statements in it
for _, e in ipairs(AmisiaDB.lineup.sets[1].list) do
    for k in pairs(e) do assert(("nrcgbkq"):find(k, 1, true), "field " .. k) end
end

-- into an empty night: the same places
local other = "2026-12-01"
local placed, added, over, absent = NS.LineupLoadSet("STAMM", other)
assert(placed == 2 and added == 4 and over == 0 and absent == 0, ("%s %s %s %s"):format(tostring(placed), tostring(added), tostring(over), tostring(absent)))
local o = byName(NS.LineupNight(other).list)
assert(o["Bob Eisherz"].g == 2 and o["Bob Eisherz"].k and o["Anna Bergmann"].g == 1 and o["Anna Bergmann"].r == "H"
    and o["Cora Wind-Tal"].b and not o["Dino Fels"].g and not o["Dino Fels"].b, "group, hold, role, bench, not placed")
assert(NS.LineupNight(other).size == 10)

-- into a night with a list: who is not in the template loses the group, a signed-off player stays
-- out, the night's statements stay
local third = "2026-12-02"
NS.SetLineupText("Tanks\nKim Sturmwind\nHeiler\nAnna Bergmann\nAbgemeldet\nDino Fels", third)
local t = NS.LineupNight(third)
local tp = byName(t.list)
NS.LineupMove(third, tp["Kim Sturmwind"]._i, 1)
NS.LineupMove(third, tp["Anna Bergmann"]._i, 2)
placed, added, over, absent = NS.LineupLoadSet("Stamm", third)
tp = byName(t.list)
assert(placed == 2 and added == 2 and absent == 1, ("%d %d %d"):format(placed, added, absent))
assert(not tp["Kim Sturmwind"].g and tp["Kim Sturmwind"].r == "T", "not in the template: out of the group, the list's role stays")
assert(tp["Anna Bergmann"].g == 1 and tp["Anna Bergmann"].d == "A" and tp["Anna Bergmann"].f == "L", "placed, the list's statement stays")
assert(tp["Dino Fels"].a and not tp["Dino Fels"].g, "signed off: stays out")
local gone, whyGone = NS.LineupLoadSet("Fehlt", third)
assert(gone == nil and whyGone == "Diese Vorlage gibt es nicht mehr.")

-- twelve at most; delete
for k = 2, NS.LINEUP_MAX_SETS do assert(NS.LineupSaveSet(tonight, "Vorlage " .. string.char(64 + k))) end
local full, whyFull = NS.LineupSaveSet(tonight, "Eine zu viel")
assert(full == nil and has(whyFull, "Höchstens 12 Vorlagen"), tostring(whyFull))
assert(NS.LineupSaveSet(tonight, "Stamm") == 4, "replacing still goes")
assert(NS.LineupDeleteSet("vorlage b") and #NS.LineupSets() == NS.LINEUP_MAX_SETS - 1 and not NS.LineupDeleteSet("vorlage b"))

-- cleaned on load: bad sets and fields go, the nights stay
AmisiaDB.lineup.sets = {
    { name = "Gut", at = 5, size = 20, list = { { n = "Bob Eisherz", g = 3, st = "A", w = "Notiz" }, { n = "Bob Eisherz", g = 1 }, { n = "X1" }, "quatsch" } },
    { name = "gut", list = { { n = "Anna Bergmann" } } },
    { name = "|cffff0000Rot|r", size = 7, list = {} },
    { name = "", list = {} }, "quatsch", { name = "Ohne Liste" },
}
NS.LineupLoaded(AmisiaDB)
local S = AmisiaDB.lineup.sets
assert(#S == 2 and S[1].name == "Gut" and #S[1].list == 1 and S[1].list[1].g == 3 and S[1].list[1].st == nil and S[1].size == 20, "the first of a name, clean entries")
assert(S[2].name == "Rot" and S[2].size == 40 and #S[2].list == 0, "colour codes gone, a wrong size is 40")
assert(NS.LineupNight(tonight, false) ~= nil, "the nights stay")
AmisiaDB.lineup.sets = "quatsch"
NS.LineupLoaded(AmisiaDB)
assert(AmisiaDB.lineup.sets == nil and #NS.LineupSets() == 0)

---------------------------------------------------------------------------
-- clear, and the block with its groups
---------------------------------------------------------------------------
n = NS.LineupNight(tonight)
local text = NS.LineupExport(tonight)
assert(has(text, "#AMISIA-RAID 1 forever " .. tonight) and has(text, "\nS Anna_Bergmann H PRIEST - 1\n")
    and has(text, "\nS Bob_Eisherz - WARRIOR - 2\n") and has(text, "\nS Cora_Wind-Tal - MAGE B -\n")
    and has(text, "\nS Dino_Fels - ROGUE - -\n") and text:sub(-4) == "#END", text)
assert(NS.LineupExport("2026-01-01") == nil, "an empty night has no block")
assert(NS.LineupClear(tonight) == 3, "two placed and one on the bench")
for _, e in ipairs(n.list) do assert(not e.g and not e.b and not e.k) end
assert(NS.LineupClear(tonight) == 0)
-- the block back in: the groups again (the date of the block is the night)
n.list = {}
local key, line = NS.SetLineupText(text)
assert(key == tonight and has(line, "4 Anmeldungen"), tostring(line))
p = byName(NS.LineupNight(tonight).list)
assert(p["Anna Bergmann"].g == 1 and p["Bob Eisherz"].g == 2 and p["Cora Wind-Tal"].b and not p["Dino Fels"].g, "the groups of the block")
-- a block that names six in a group or a group past the size: the surplus is not placed; a group
-- past the size makes the night bigger
local lines = { "#AMISIA-RAID 1 forever 2026-12-05 Probe" }
for _, name in ipairs({ "Aa Eins", "Bb Zwei", "Cc Drei", "Dd Vier", "Ee Fuenf", "Ff Sechs" }) do
    lines[#lines + 1] = ("S %s M WARRIOR - 1"):format((name:gsub(" ", "_")))
end
lines[#lines + 1] = "S Gg_Sieben M WARRIOR - 4"
lines[#lines + 1] = "S Hh_Acht M WARRIOR - 9"
lines[#lines + 1] = "S Ii_Neun M WARRIOR B 2"
lines[#lines + 1] = "#END"
NS.Set("lineup.guests", true)
key = NS.SetLineupText(table.concat(lines, "\n"))
local big = NS.LineupNight("2026-12-05")
local bp = byName(big.list)
assert(key == "2026-12-05" and #big.list == 8, "the line with group 9 is no line of the block: " .. #big.list)
assert(big.size == 20 and bp["Gg Sieben"].g == 4, "group 4 needs a raid of 20")
assert(bp["Ee Fuenf"].g == 1 and not bp["Ff Sechs"].g, "the sixth of group 1 is not placed")
assert(bp["Ii Neun"].b and not bp["Ii Neun"].g, "the bench goes before a group")

---------------------------------------------------------------------------
-- the groups of the raid
---------------------------------------------------------------------------
local none2, whyRaid = NS.LineupFromRaid(tonight)
assert(none2 == nil and whyRaid == "Nur im Raid.")
STUB.roster = {
    { name = "Vuloo", class = "PRIEST", sub = 1 },
    { name = "Bob Eisherz", class = "WARRIOR", sub = 3 },
    { name = "Anna Bergmann", class = "PRIEST", sub = 3 },
    { name = "Fremder Gast", class = "MAGE", sub = 1 },
}
_G.GetRaidRosterInfo = function(idx)
    local m = STUB.roster[idx]
    if not m then return nil end
    return m.name, 0, m.sub, 60, m.class, m.class, "Shattrath", true
end
assert(#NS.LineupRaidRows() == 4 and NS.LineupRaidRows()[2].sub == 3)
-- Dino signed off for tonight but is not in the raid; Anna signed off and is in it
n = NS.LineupNight(tonight)
p = byName(n.list)
p["Anna Bergmann"].a, p["Anna Bergmann"].g = true, nil
NS.Set("lineup.guests", false)
placed, added, over, absent = NS.LineupFromRaid(tonight)
p = byName(n.list)
assert(placed == 4 and added == 2 and absent == 0, ("%d %d %d"):format(placed, added, absent))
assert(p["Vuloo"].g == 1 and p["Bob Eisherz"].g == 3 and p["Fremder Gast"].g == 1 and p["Fremder Gast"].x == "g", "everyone where he stands, a guest too")
assert(p["Anna Bergmann"].g == 3 and p["Anna Bergmann"].k and not p["Anna Bergmann"].a, "signed off but there: held in her group")
assert(not p["Dino Fels"].g and p["Cora Wind-Tal"].b, "not in the raid: no group; the bench stays")
assert(n.size == 20, "group 3 needs a raid of 20")
STUB.roster = {}

---------------------------------------------------------------------------
-- the page
---------------------------------------------------------------------------
NS.Set("lineup.size", 10)
local empty = "2026-12-08"
NS.ShowLineup("match", empty)
local f = NS.PageFrame("lineup")
assert(f.empty:IsShown() and has(f.empty.text:GetText() or "", "Planer"), "the empty state names the planner")
-- the planner of a night without a list: two groups, the player list in the place of the two lists
f.views.planner:Click()
assert(f.plan:IsShown() and not f.empty:IsShown() and f.gridList:IsShown() and not f.openList:IsShown(), "the planner with the player list")
assert(f.plan.groups[2]:IsShown() and not f.plan.groups[3]:IsShown(), "the groups of the raid size")
local function cell(name)
    for _, row in ipairs(f.gridList.rows) do
        if row:IsShown() then
            for _, b in ipairs(row.cells) do
                if b:IsShown() and b.p and b.p.name == name then return b end
            end
        end
    end
end
assert(cell("Anna Bergmann") and cell("Bob Eisherz") and not cell("Kim Sturmwind"), "the guild, online only")
f.plan.online:Click()
assert(cell("Kim Sturmwind") and has(cell("Kim Sturmwind").name:GetText(), "|cff"), "everyone; offline grey")
f.plan.online:Click()
-- the class and the search
f.plan.classPick.onPick("WARRIOR")
assert(cell("Bob Eisherz") and not cell("Anna Bergmann"), "warriors only")
f.plan.classPick.onPick("all")
f.plan.search:SetText("wind"); f.plan.search:GetScript("OnEnterPressed")(f.plan.search)
assert(cell("Cora Wind-Tal") and not cell("Bob Eisherz"), "the search")
f.plan.search:SetText(""); f.plan.search:GetScript("OnEnterPressed")(f.plan.search)
-- F-194: "nach Klasse" groups the names by class (by the class's name), by name within a class
local function shown()
    local out = {}
    for _, row in ipairs(f.gridList.rows) do
        if row:IsShown() then
            for _, b in ipairs(row.cells) do
                if b:IsShown() and b.p then out[#out + 1] = b.p end
            end
        end
    end
    return out
end
local function cname(token)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    return NS.Fold(type(names) == "table" and names[token] or token)
end
local byName0 = shown()
for k = 2, #byName0 do assert(NS.Fold(byName0[k - 1].name) < NS.Fold(byName0[k].name), "by name without the check") end
assert(not f.plan.byClass.on, "the check starts off")
f.plan.byClass:Click()
assert(f.plan.byClass.on, "the check is on")
local grouped = shown()
assert(#grouped == #byName0 and #grouped >= 4, "the same players")
for k = 2, #grouped do
    local a, b = grouped[k - 1], grouped[k]
    local ca, cb = cname(a.class), cname(b.class)
    assert(ca < cb or (ca == cb and NS.Fold(a.name) < NS.Fold(b.name)), "by class, then name: " .. a.name .. " / " .. b.name)
end
f.plan.byClass:Click()
assert(shown()[1].name == byName0[1].name, "off: by name again")
-- a click chooses the name (nothing saved yet), the click on a place puts it there
cell("Bob Eisherz"):Click()
assert(cell("Bob Eisherz").sel:IsShown() and NS.LineupNight(empty, false) == nil, "chosen, not on the list yet")
f.plan.groups[2].slots[1]:Click()
local en = NS.LineupNight(empty, false)
assert(en and #en.list == 1 and en.list[1].n == "Bob Eisherz" and en.list[1].g == 2, "on the list, in group 2")
assert(cell("Bob Eisherz").info:GetText() == "2" and not cell("Bob Eisherz").sel:IsShown(), "grey with its group")
assert(f.plan.groups[2].slots[1].entry == 1)
-- another name onto the taken place: the two swap, Bob is no longer placed
cell("Anna Bergmann"):Click()
f.plan.groups[2].slots[1]:Click()
p = byName(en.list)
assert(p["Anna Bergmann"].g == 2 and not p["Bob Eisherz"].g and cell("Bob Eisherz").info:GetText() ~= "2", "swapped")
-- a name of the list in the player list: a click chooses it as in the planner
cell("Bob Eisherz"):Click()
f.plan.groups[1].slots[1]:Click()
assert(byName(en.list)["Bob Eisherz"].g == 1)
-- the same click again lets a chosen name go
cell("Dino Fels"):Click()
cell("Dino Fels"):Click()
assert(not cell("Dino Fels").sel:IsShown() and #en.list == 2)
-- "Spieler" off: the two lists again
assert(f.gridBtn:IsShown() and f.gridBtn:IsEnabled() and f.gridBtn.on)
f.gridBtn:Click()
assert(f.openList:IsShown() and not f.gridList:IsShown() and has(f.openHead:GetText(), "Nicht eingeteilt (0)"))
f.gridBtn:Click()
assert(f.gridList:IsShown())
-- the raid as the source
f.plan.srcRaid:Click()
assert(f.plan.gridEmpty:IsShown() and has(f.plan.gridEmpty:GetText(), "Du bist in keinem Raid."))
f.plan.srcGuild:Click()
f.gridBtn:Click()

-- the view "Vorlagen": empty, save, the row, load into another night
f.setsBtn:Click()
assert(f.empty:IsShown() and has(f.empty.title:GetText(), "Noch keine Vorlagen") and f.setName:IsShown() and not f.setLoad:IsEnabled())
STUB.messages = {}
f.setName:SetText("Zehner")
f.setSave:Click()
assert(said("Vorlage Zehner gespeichert: 2 Spieler."), STUB.messages[1])
assert(f.sets:IsShown() and f.setRows.rows[1].name:GetText() == "Zehner" and f.setRows.rows[1].count:GetText() == "2"
    and f.setRows.rows[1].sel:IsShown() and f.setLoad:IsEnabled(), "the row, chosen")
NS.ShowLineup("sets", "2026-12-09")
STUB.messages = {}
f.setLoad:Click()
assert(said("Vorlage Zehner: 2 eingeteilt, 2 neu in der Liste."), STUB.messages[1])
assert(f.plan:IsShown() and byName(NS.LineupNight("2026-12-09").list)["Anna Bergmann"].g == 2, "loaded, the planner")
-- loading over groups asks first
f.setsBtn:Click()
f.setLoad:Click()
local ask = _G.AmisiaConfirmFrame
assert(ask and ask:IsShown(), "a question before the groups are replaced")
ask.ok:Click()
assert(f.plan:IsShown())
-- delete, with a question
f.setsBtn:Click()
f.setDelete:Click()
assert(ask:IsShown() and #NS.LineupSets() == 1)
ask.ok:Click()
assert(#NS.LineupSets() == 0 and f.empty:IsShown())
f.setsBtn:Click()
assert(f.plan:IsShown(), "back")

-- "Mehr": the raid's groups grey outside a raid, clear with a question, the block to copy
local function menuEntry(part)
    for _, b in ipairs(AmisiaMenu.buttons) do
        if b:IsShown() and has(b.label:GetText(), part) then return b end
    end
end
f.moreBtn:Click()
assert(AmisiaMenu:IsShown() and menuEntry("Aus dem Raid übernehmen"):GetScript("OnClick") == nil, "grey outside a raid")
menuEntry("Als Text exportieren"):Click()
assert(f.export:IsShown() and has(f.export.box:GetText(), "#AMISIA-RAID 1 forever 2026-12-09")
    and has(f.export.box:GetText(), "S Anna_Bergmann") and f.cancel:IsShown() and not f.plan:IsShown(), "the block")
f.cancel:Click()
NS.ShowLineup("planner")
f.moreBtn:Click()
menuEntry("Gruppen leeren"):Click()
assert(ask:IsShown())
STUB.messages = {}
ask.ok:Click()
assert(said("Gruppen geleert: 2 Spieler"), STUB.messages[1])
assert(NS.LineupCounts("2026-12-09").placed == 0)
-- in a raid: the groups of the raid
STUB.roster = { { name = "Vuloo", class = "PRIEST", sub = 2 }, { name = "Bob Eisherz", class = "WARRIOR", sub = 1 } }
f.moreBtn:Click()
if AmisiaMenu:IsShown() == false then f.moreBtn:Click() end
STUB.messages = {}
menuEntry("Aus dem Raid übernehmen"):Click()
assert(said("Aus dem Raid: 2 eingeteilt, 1 neu in der Liste."), STUB.messages[1])
p = byName(NS.LineupNight("2026-12-09").list)
assert(p["Vuloo"].g == 2 and p["Bob Eisherz"].g == 1 and not p["Anna Bergmann"].g)
f.gridBtn:Click()
f.plan.srcRaid:Click()
assert(cell("Vuloo") and cell("Vuloo").info:GetText() == "2" and not cell("Anna Bergmann"), "the raid as the source")
STUB.roster = {}
print("lineup sets ok")
