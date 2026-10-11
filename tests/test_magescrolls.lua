-- Mage scrolls (Gear/MageScrolls.lua, UI/Pages/MageScrolls.lua): the Comprehension rank from the
-- client, the colour of each scroll's tier, counts in the bags, the library books and their quest
-- flags, sources with a waypoint only for an own position, the page for mages (others through
-- /amisia schriftrollen), its three views and the detail.
local MS = NS.MageScrolls
assert(MS, "the module loads")
local function has(s, part) return type(s) == "string" and s:find(part, 1, true) ~= nil end

-- the shipped data loads and has the Forever scrolls
assert(NS.HasData("MAGESCROLLS") and (NS.DataSize("MAGESCROLLS") or 0) > 0, "data registered with its count")
local real = NS.Data("MAGESCROLLS")
assert(real.skill == 3012 and #real.scrolls >= 4 and #real.tiers >= 2, "the real data")

-- a fixture in its place (the shape of tools/build_magescrolls.py)
NS.MAGESCROLLS = {
    build = "1.60.1.99999", built = "2026-10-07", att = "abc", skill = 3012,
    charm = 69500, conjure = 8200, boost = 9011, boostSpell = 8011, bundle = 9030,
    tiers = { { 1, 15, 30, 8101 }, { 15, 50, 75, 8102 }, { 50, 100, 200, 8103 } },
    scrolls = {
        { 61015, 1, 1, 10, 1, "Scroll: AAA" },
        { 9002, 1, 1, 10, 0, "Scroll: BBB" },
        { 9003, 15, 2, 20, 1, "Scroll: CCC" },
        { 9004, 50, 3, 30, 0, "Scroll: DDD" },
    },
    results = {
        { 9024, 12, 15, 0, "Scroll of No Spell", "" },
        { 9020, 16, 25, 8020, "Scroll of Imbue Test", "Imbue a staff with magic for 60 min." },
    },
    abilities = { { 8103, "Study", "Perform spell research, resulting in a bundle of scrolls. Requires a suitable library." } },
    books = {
        { 78501, 69501, "", { 1426 }, "A Dusty Tome", 1 },
        { 78502, 69502, "A", { 1455, 1426 }, "An Alliance Tome", 1 },
        { 78504, 69504, "H", { 1426 }, "A Horde Tome", 1 },
    },
    friends = { { 78503, 2, 20, "Friend of the Fixture", { 69503 } } },
    librarians = { { 81501, "A", 1453, 4900, 8640, "Fixture Librarian" }, { 81502, "H", 1458, 7360, 3300, "Other Librarian" } },
}
STUB.maps[1453] = { name = "Sturmwind" }
STUB.maps[1426] = { name = "Dun Morogh" }
STUB.maps[1455] = { name = "Eisenschmiede" }
STUB.item(61015, "Schriftrolle: AAA", 1)
STUB.item(9003, "Schriftrolle: CCC", 1)
STUB.item(9020, "Schriftrolle der Testverzauberung", 2)
STUB.item(69500, "Verständnistalisman", 1)
STUB.item(69501, "Ein staubiger Wälzer", 1)

---------------------------------------------------------------------------
-- rank, colours, counts
---------------------------------------------------------------------------
STUB.class = "MAGE"
assert(MS.Rank() == nil, "no skill line, no rank")
STUB.skills = { { name = "Sekundäre Fertigkeiten", header = true }, { name = "Arkanes Verständnis", id = 3012, rank = 20, max = 75 } }
local rank, max = MS.Rank()
assert(rank == 20 and max == 75, "the rank from C_SkillInfo")
local s = MS.Scrolls()
assert(#s == 4 and s[1].item == 61015 and s[1].tier == 1 and s[1].world and s[3].rank == 15, "the scrolls")
assert(MS.Color(s[1], 20) == "yellow", "tier 1 at 20: yellow (15 to 22)")
assert(MS.Color(s[1], 23) == "green" and MS.Color(s[1], 30) == "grey" and MS.Color(s[1], 10) == "orange", "the steps of tier 1")
assert(MS.Color(s[3], 20) == "orange" and MS.Color(s[4], 20) == "red", "tier 2 orange, tier 3 too high")
assert(MS.Color(s[1], nil) == "none", "without a rank")
STUB.bags[0] = { 61015, 61015, 9020 }
assert(MS.Count(61015) == 2 and MS.Count(9003) == 0, "counts in the bags")

---------------------------------------------------------------------------
-- library books, the own faction, quest flags
---------------------------------------------------------------------------
STUB.faction = "Alliance"
local books = MS.Books()
assert(#books == 2 and books[1].quest == 78501 and books[2].quest == 78502, "no Horde book for the Alliance")
assert(books[1].done == false, "not turned in")
STUB.questsDone[78501] = true
MS._resetQuests()
books = MS.Books()
assert(books[1].done == true and books[2].done == false, "turned in: " .. tostring(books[1].done))
local lib = MS.Librarian()
assert(lib and lib.name == "Fixture Librarian" and lib.point.map == 1453 and math.abs(lib.point.x - 0.49) < 1e-6, "the own librarian")
local f1 = MS.Friends()[1]
assert(f1.need == 2 and f1.have == 1 and f1.done == false, "one of two books")

---------------------------------------------------------------------------
-- sources: data, Study, what the collector saw (waypoint only for an own position)
---------------------------------------------------------------------------
local origObserved = NS.Prof.Observed
NS.Prof.Observed = function(item)
    if item == 61015 then
        return { vendors = {}, drops = {
            { npc = 1, name = "Kobold", pos = "1426:5000:5000", own = true, ownPos = true },
            { npc = 2, name = "Gnoll", pos = "1426:2000:3000", own = false, ownPos = false } } }
    end
end
local src = MS.Sources(s[1])
local texts = {}
for _, e in ipairs(src) do texts[#texts + 1] = e.text end
local all = table.concat(texts, "\n")
assert(has(all, "Weltdrop") and has(all, "Studieren") and has(all, "Kobold") and has(all, "Gnoll"), all)
local kobold, gnoll
for _, e in ipairs(src) do
    if has(e.text, "Kobold") then kobold = e end
    if has(e.text, "Gnoll") then gnoll = e end
end
assert(kobold.point and kobold.point.map == 1426 and math.abs(kobold.point.x - 0.5) < 1e-6, "own position: a waypoint")
assert(gnoll.point == nil and has(gnoll.text, "von der Gilde"), "heard: shown, no waypoint")
local s2 = MS.Sources(s[2])
for _, e in ipairs(s2) do assert(not has(e.text, "Weltdrop"), "not a world drop in the data") end
NS.Prof.Observed = origObserved

-- known spells: IsPlayerSpell where the client has it
_G.IsPlayerSpell = function(id) return id == 8200 end
assert(MS.Known(8200) == true and MS.Known(8103) == false, "known from the client")
_G.IsPlayerSpell = nil
assert(MS.Known(8200) == nil, "without the function: unknown")
_G.IsPlayerSpell = function(id) return id == 8200 end

---------------------------------------------------------------------------
-- the page: mages see it, others open it with the command
---------------------------------------------------------------------------
local panel = NS.Panel("scrolls")
assert(panel and panel.group == "gear" and panel.label == "Schriftrollen", "registered under Ausrüstung")
assert(NS.Visible(panel), "a mage sees it")
STUB.class = "WARRIOR"
assert(not NS.Visible(panel), "a warrior does not")
NS.Dispatch("schriftrollen")
assert(NS.CurrentPage() == "scrolls" and NS.Visible(panel), "/amisia schriftrollen opens it for anyone")
STUB.class = "MAGE"
local f = NS.MageScrollsPageFrame()
assert(f and f.list and f.detail, "the page frame")
assert(has(f.rank:GetText(), "20") and has(f.rank:GetText(), "75"), f.rank:GetText())

local function rows()
    local out = {}
    for _, r in ipairs(f.list.rows) do if r:IsShown() then out[#out + 1] = r end end
    return out
end
-- scrolls view: a header per tier, the scrolls in the colour of their tier
local shown = rows()
assert(#shown == 7, "3 tier heads and 4 scrolls: " .. #shown)
assert(has(shown[1].name:GetText(), "Stufe 1") and has(shown[1].name:GetText(), "ab Rang 1"), shown[1].name:GetText())
assert(has(shown[2].name:GetText(), "Schriftrolle: AAA") and has(shown[2].name:GetText(), "ffffff00"), "yellow: " .. shown[2].name:GetText())
assert(has(shown[2].mark:GetText(), "2"), "two in the bags: " .. shown[2].mark:GetText())
assert(has(shown[3].name:GetText(), "Scroll: BBB"), "the data's name while the client has none")
assert(has(shown[7].name:GetText(), "ffff2020"), "tier 3 red")
-- detail of a scroll
shown[2]:Click()
local body = f.detail.body.fs:GetText()
assert(has(body, "Arkanes Verständnis 1") and has(body, "gelb ab 15") and has(body, "grau ab 30"), body)
assert(has(body, "Im Inventar: 2") and has(body, "Weltdrop"), body)
assert(has(f.detail.title:GetText(), "Schriftrolle: AAA"), f.detail.title:GetText())

-- results view
f.view:Click()
assert(f.view.current == "results", "view Ergebnisse")
shown = rows()
assert(#shown == 2 and has(shown[2].name:GetText(), "Schriftrolle der Testverzauberung"), "the results")
assert(has(shown[2].rank:GetText(), "16"), "required level")
shown[2]:Click()
body = f.detail.body.fs:GetText()
assert(has(body, "Stufe 16") and has(body, "Im Inventar: 1"), body)

-- library view: helpers, books (done marked), the friend quest, the librarian's waypoint
f.view:Click()
assert(f.view.current == "library", "view Bibliothek")
shown = rows()
local texts2 = {}
for _, r in ipairs(shown) do texts2[#texts2 + 1] = r.name:GetText() end
local listText = table.concat(texts2, "\n")
assert(has(listText, "Ein staubiger Wälzer") and has(listText, "An Alliance Tome") and not has(listText, "A Horde Tome"), listText)
assert(has(listText, "Friend of the Fixture") and has(listText, "Verständnistalisman"), listText)
local bookRow
for _, r in ipairs(shown) do if has(r.name:GetText(), "Ein staubiger Wälzer") then bookRow = r end end
assert(has(bookRow.mark:GetText(), "abgegeben"), "done mark: " .. bookRow.mark:GetText())
bookRow:Click()
body = f.detail.body.fs:GetText()
assert(has(body, "Fixture Librarian") and has(body, "Sturmwind") and has(body, "Dun Morogh"), body)
assert(f.detail.go:IsEnabled(), "the librarian is a waypoint")
f.detail.go:Click()
local m = AmisiaDB.map and AmisiaDB.map.target
assert(m and m.map == 1453, "waypoint set")
-- the charm: conjure spell known
for _, r in ipairs(rows()) do if has(r.name:GetText(), "Verständnistalisman") then r:Click() end end
body = f.detail.body.fs:GetText()
assert(has(body, "Im Inventar: 0") and has(body, "bekannt"), body)

-- layout at the main window's size
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
Lay.row("head", f.view, f.counts, f.rank)
Lay.row("body", f.list, f.detail)
Lay.column("parts", f.view, f.list, f.hint, f.data)
Lay.inside("way", f.detail.go)
Lay.fits(f.rank)

-- no data: the page is gone
NS.MAGESCROLLS = { skill = 0, tiers = {}, scrolls = {}, results = {}, abilities = {}, books = {}, friends = {}, librarians = {} }
assert(not MS.Available(), "without scrolls no page")
print("mage scrolls ok")
