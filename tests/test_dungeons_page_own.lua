-- The dungeons page of its own (F-102, spec docs/specs/2026-10-13-dungeons-einstellungen.md, part A):
-- registered in the tab Ausrüstung right after the gear page, the gear page without its chip
-- "Dungeons", /amisia dungeon and /amisia journal open the page, a saved view "dungeons" of the gear
-- page opens it on "Ziele", the spec picked on the dungeons page is the gear page's.
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
NS.GEAR = { built = "test-dungeons-page-own", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },
} }
STUB.item(501, "Ambosshelm", 3)
local it = STUB.items[501]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_HEAD", 4, 2, 16
it.stats = { ITEM_MOD_STRENGTH_SHORT = 20 }
NS.GEAR.I[501] = { "HEAD", 4, 2, 16, 3, 1, 20, 0, 0, 0, 1 }
NS.Gear._reset()
assert(NS.Gear.Available(), "gear data")

-- the page: in the tab Ausrüstung, right after the gear page, before the map
local p = NS.Panel("dungeons")
assert(p and p.label == "Dungeons" and NS.PanelGroup(p) == "gear", "registered in the tab Ausrüstung")
local after = {}
for _, q in ipairs(NS.panels) do
    if NS.PanelGroup(q) == "gear" and q.order then after[#after + 1] = q end
end
table.sort(after, function(a, b) return a.order < b.order end)
assert(after[1].key == "gear" and after[2].key == "dungeons", "right after the gear page: " .. after[2].key)
assert(p.available(), "shown with gear data")

-- the gear page has no chip "Dungeons" any more
NS.ShowGear("goals")
local f = NS.GearPageFrame()
assert(NS.CurrentPage() == "gear" and f.views.dungeons == nil and f.dungeons == nil and f.bodies.dungeons == nil, "no dungeons view")
for _, chip in ipairs(f.headRow) do
    assert(plain(chip.label and chip.label:GetText() or "") ~= "Dungeons", "no dungeons chip in the head row")
end

-- the commands open the page
NS.Dispatch("dungeon")
assert(NS.CurrentPage() == "dungeons", "/amisia dungeon: " .. tostring(NS.CurrentPage()))
NS.ShowGear("goals")
NS.Dispatch("journal")
assert(NS.CurrentPage() == "dungeons", "/amisia journal: " .. tostring(NS.CurrentPage()))
local D = NS.DungeonsPageFrame()
assert(D and D:IsShown() and D.list and D.detail and D.art, "the planner on the page")
-- and the old entry point
NS.ShowGear("goals")
NS.ShowGear("dungeons")
assert(NS.CurrentPage() == "dungeons" and AmisiaDB.settings.bis.view == "goals", "ShowGear(\"dungeons\") opens the page")

-- a saved view "dungeons" (before the page of its own): the gear page opens on "Ziele"
AmisiaDB.settings.bis.view = "dungeons"
NS.ShowPage("gear")
assert(NS.CurrentPage() == "gear" and f.goals:IsShown() and f.views.goals.on, "the goals instead")

-- the spec: picked on the dungeons page, the same on the gear page
NS.ShowPage("dungeons")
D.spec.onPick("tank")
assert(NS.BisSpec() == "tank" and plain(D.spec.label:GetText()) == "Schutz", D.spec.label:GetText())
NS.ShowPage("gear")
assert(plain(f.spec.label:GetText()) == "Schutz", "the gear page's spec: " .. f.spec.label:GetText())
-- and back: the guess, on both
f.spec.onPick("")
NS.ShowPage("dungeons")
assert(select(2, NS.BisSpec()) == true and plain(D.spec.label:GetText()) == plain(f.spec.label:GetText()), D.spec.label:GetText())
print("dungeons page of its own ok")
