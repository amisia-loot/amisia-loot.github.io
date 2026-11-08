-- The page "Ausrüstungsplaner" (UI/Pages/Planner.lua, F-149, D-77): first in the tab Ausrüstung; the
-- doll of the goals window's builder in the page's sizes (8 slots left with shirt and tabard, 8 right,
-- the weapons under the model), the slots' quality frames and the green frame of a worn target, the
-- enchant squares (an icon for the enchantment on it, "+" where one fits, the menu, none where nothing
-- fits); the list: the chosen slot's suggestions with level and source, gain, source symbol and star;
-- a click makes a row the own pick (again: lifts it), the star toggles the wish; the wish list tab; the
-- search; the level range (boxes, Meine Stufe, Alle above the own level); the side bar's set marks
-- with their counts, a mark shows that category's sets, a set opens its pieces, back to the
-- suggestions; Zurücksetzen asks first; the warning while an own pick is not used; 602 x 478. Since D-80
-- also the goals window's parts: the tab Ziele, "Deine Wahl", a link or id in the search box, Optionen,
-- Ziele | Angelegt, the score, every way to the window opening the page, no window rows, the migration.
local Gear = NS.Gear
local PL = NS.Theme.PLANNER
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
-- the lines a tooltip got (the stub keeps none)
local function tipOf(fn)
    local out, keep = {}, GameTooltip.AddLine
    GameTooltip.AddLine = function(_, t) out[#out + 1] = tostring(t) end
    fn()
    GameTooltip.AddLine = keep
    return table.concat(out, "\n")
end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level = "WARRIOR", 58
STUB.fire("PLAYER_ENTERING_WORLD"); STUB.tick(2)
NS.GEAR = { game = "forever", cap = 60, built = "test-planner", I = {}, Z = {}, S = {
    { "X", "Geschmolzener Kern", "Ragnaros", 409, 2717, 1, 0 },   -- 1
    { "D", "Stratholme", "Baron Totenschwur", nil, 329, 2017 },   -- 2
    { "C", "leatherworking", 300 },                                -- 3
    { "Q", "Endlich frei", 30, 25, "", 1429, 0, 0 },               -- 4
} }
STUB.areas[2717], STUB.areas[2017] = "Geschmolzener Kern", "Stratholme"
Gear._reset()
local LINKS = {}
local function gear(id, name, loc, strength, level, sources, quality)
    LINKS[id] = STUB.item(id, name, quality or 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID = "INVTYPE_" .. loc, 4, 4
    it.stats, it.minLevel = { ITEM_MOD_STRENGTH_SHORT = strength }, level
    if sources then
        NS.GEAR.I[id] = { loc, 4, 4, level, quality or 4, 1, 60, 0, 0, 0 }
        for _, n in ipairs(sources) do NS.GEAR.I[id][#NS.GEAR.I[id] + 1] = n end
    end
end
gear(401, "Helm des Kerns", "HEAD", 40, 60, { 1 })
gear(402, "Helm der Pest", "HEAD", 30, 58, { 2 }, 3)
gear(403, "Brust der Pest", "CHEST", 35, 58, { 2 })
gear(404, "Teufelssaurier-Stulpen", "HAND", 20, 53, { 3 })
gear(405, "Teufelssaurier-Gamaschen", "LEGS", 25, 53, { 3 })
gear(406, "Anfängerhelm", "HEAD", 5, 10, { 2 }, 2)
gear(407, "Armschiene", "WRIST", 5, 40, { 2 })
gear(410, "Alter Helm", "HEAD", 2, 1)
gear(408, "Queststiefel", "FEET", 10, 25, { 4 })
NS.BIS = { SET = {
    [1] = { name = "Pestset", items = { 402, 403 }, b = { { 2, "STRENGTH=10" } } },
    [2] = { name = "Teufelssaurier", items = { 404, 405 }, b = { { 2, "" } } },
} }
NS.Catalog._reset()
-- the enchantments: intellect on the chest now, strength for chest and wrist
NS.ENCHANT = { build = "test", built = "test", E = {
    [24] = "INTELLECT=2|0|0|Intellect +2", [41] = "STRENGTH=5|0|0|Strength +5", [60] = "STRENGTH=9|0|0|Strength +9",
}, S = { "r:100:24:333:1:4:CHEST,ROBE:", "r:101:41:333:150:4:CHEST,ROBE:", "r:103:60:333:150:4:WRIST:" } }
STUB.worn[1] = LINKS[410]
STUB.worn[5] = "|cffa335ee|Hitem:403:24::::::::58:::::|h[Brust der Pest]|h|r"
STUB.worn[9] = LINKS[407]
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
assert(Gear.Available())
NS.BisSetSpec("dps")

---------------------------------------------------------------------------
-- the tab Ausrüstung: the planner first, then the gear page and its windows
---------------------------------------------------------------------------
NS.ShowTab("gear")
assert(NS.CurrentPage() == "planner", "the tab opens the planner first: " .. tostring(NS.CurrentPage()))
local F = AmisiaFrame
local function navKeys(kind)
    local out = {}
    for _, e in ipairs(F.navOrder) do
        if not kind or e.entry.kind == kind then out[#out + 1] = e.entry.key end
    end
    return table.concat(out, " ")
end
-- no side windows in the tab any more (D-80): the goals are the planner, the table opens from the page Ausrüstung
assert(navKeys("page") .. " | " .. navKeys("win") == "planner gear | ", navKeys())
-- the marks: the set categories, Ruf in a block of its own, counts on the level range (1 to 58)
assert(navKeys("jump") == "raid dungeon pvp craft world rep", navKeys("jump"))
local function mark(key)
    for _, e in ipairs(F.navOrder) do if e.entry.kind == "jump" and e.entry.key == key then return e end end
end
assert(mark("raid").button.rule:IsShown() and mark("rep").button.rule:IsShown() and not mark("dungeon").button.rule:IsShown(), "two blocks")
assert(mark("dungeon").button.count:GetText() == "1" and mark("craft").button.count:GetText() == "1", "the counts")
assert(mark("dungeon").button.symbol:IsShown() and mark("dungeon").entry.icon.atlas == "Dungeon", "the client's mark")
for _, key in ipairs(PL.MARKS) do
    local def = PL.MARK_ICONS[key]
    assert(def.atlas or not def.file:lower():find("^interface\\icons\\"), "no item icon for the mark " .. key)
end

local f = NS.PageFrame("planner")
local d = f.doll
local P = PL.DOLL

---------------------------------------------------------------------------
-- the doll: 19 slots (17 and the shirt and the tabard), the model between, the weapons under it
---------------------------------------------------------------------------
local n = 0
for _ in pairs(d.slots) do n = n + 1 end
assert(n == 19, "19 slots: " .. n)
assert(#P.LEFT == 8 and #P.RIGHT == 8 and P.LEFT[6] == "SHIRT" and P.LEFT[7] == "TABARD", "8 and 8 as on the character frame")
assert(d.slots.HEAD.points.TOPLEFT.x == 0 and d.slots.HEAD.points.TOPLEFT.y == 0, "the left column from the top")
-- the panel: 40 % of the page (240 of 602), the doll as wide as the panel less its pads
local LW = math.max(PL.LEFT_MIN, math.min(PL.LEFT_MAX, math.floor(NS.Theme.PAGE_W * PL.LEFT_RATIO)))
assert(LW == 240 and f.panel:GetWidth() == LW and d.dollW == LW - 2 * PL.PAD, "the split at 602: " .. LW)
assert(d.slots.HANDS.points.TOPLEFT.x == d.dollW - P.SLOT, "the right column")
assert(d.slots.HEAD:GetWidth() == P.SLOT and P.SLOT == 38, "slots 38 px")
assert(d.slots.MAINHAND.points.TOPLEFT.y == -(P.MODEL_H + P.WEAPON_GAP), "the weapons under the model")
assert(d.model and d.model.unit == "player" and d.model.undressed, "the model wears the targets")
assert(d.parent == f.panel or d:GetParent() == f.panel, "the doll on the dark panel")
assert(d.points.TOPLEFT.x == PL.PAD and d.points.TOPLEFT.y == -PL.DOLL_Y)
-- the chosen slot: the first with an upgrade (the head), gold; the target's icon in its quality's frame
assert(d.slots.HEAD.item and d.slots.HEAD.item.id == 402, "the head's target: " .. tostring(d.slots.HEAD.item and d.slots.HEAD.item.id))
local function edge(b) return b.ringColor end
-- the slot's thin rounded ring (Amisia's own art) and the rounded icon
assert(d.slots.HEAD.ring.texture:find("slot_ring", 1, true) and d.slots.HEAD.edges == nil, "the rounded ring, no square edges")
local GOLD, DONE = NS.Theme.GOLD, PL.STATE_COLOR.done
assert(edge(d.slots.HEAD)[1] == GOLD[1] and edge(d.slots.HEAD)[2] == GOLD[2], "the chosen slot gold")
assert(d.slots.CHEST.item.id == 403 and edge(d.slots.CHEST)[1] == DONE[1] and edge(d.slots.CHEST)[2] == DONE[2],
    "the worn target in a green frame")
-- the shirt: what is worn (nothing here), the slot's art, no square, not chosen by a click
assert(not d.slots.SHIRT.item and d.slots.SHIRT.art:IsShown() and d.slots.SHIRT.ench == nil, "the shirt: empty, no enchant square")
d.slots.SHIRT:Click()
assert(AmisiaDB.settings.bis.planSlot == nil, "the shirt is not chosen")

---------------------------------------------------------------------------
-- the enchant squares: the one on the chest, "+" on the wrist, none on the head (nothing fits)
---------------------------------------------------------------------------
local chestQ, wristQ, headQ = d.slots.CHEST.ench, d.slots.WRIST.ench, d.slots.HEAD.ench
assert(chestQ:IsShown() and chestQ.icon:IsShown() and not chestQ.plus:IsShown(), "the chest's enchantment as an icon")
assert(wristQ:IsShown() and not wristQ.icon:IsShown() and wristQ.plus:IsShown() and wristQ.plus:GetText() == "+", "a + on the wrist")
assert(not headQ:IsShown(), "nothing fits the helm: no square")
assert(chestQ.points.TOPLEFT.rel == d.slots.CHEST and chestQ.points.TOPLEFT.x == PL.ENCH_GAP, "beside its slot, towards the model")
local mhQ = d.slots.MAINHAND.ench
assert(mhQ.points.BOTTOM and mhQ.points.BOTTOM.rel == d.slots.MAINHAND and mhQ.points.BOTTOM.y == PL.ENCH_GAP, "a weapon's square above it")
local handsQ = d.slots.HANDS.ench
assert(handsQ.points.TOPRIGHT.rel == d.slots.HANDS and handsQ.points.TOPRIGHT.x == -PL.ENCH_GAP, "the right column's square left of it")
-- the menu: what fits, the best first
wristQ:Click()
assert(AmisiaMenu:IsShown(), "the menu of the square")
local labels = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then labels[#labels + 1] = b.label:GetText() end end
assert(has(labels[1], "Strength +9"), "the wrist's enchantment: " .. tostring(labels[1]))
AmisiaMenu:Hide()
local tip = tipOf(function() chestQ.scripts.OnEnter(chestQ) end)
assert(has(tip, "Intellect +2") and has(tip, "Strength +5"), "the tooltip names the one on it and the better one: " .. tip)

---------------------------------------------------------------------------
-- the head row: name, level, the spec picker in the panel; the tabs, the search
---------------------------------------------------------------------------
assert(has(plain(f.who:GetText()), "Stufe 58"), plain(f.who:GetText()))
assert(f.spec:GetWidth() == PL.SPEC_W and f.spec.points.LEFT.rel == f.who, "the spec picker after the name")
assert(f.tabSuggest.on and not f.tabWish.on and not f.warn:IsShown(), "Vorschläge chosen, no warning")
assert(f.title:GetText() == "Kopf", "the chosen slot's name: " .. tostring(f.title:GetText()))

---------------------------------------------------------------------------
-- the list: the head's suggestions on 1 to 58
---------------------------------------------------------------------------
local function ids()
    local out = {}
    for _, e in ipairs(f.list.items) do
        out[#out + 1] = tostring(e.id or (e.set and ("set" .. e.set.id)) or (e.pickRow and "pick") or (e.header and e.header.key)
            or (e.goal and e.key) or "note")
    end
    return table.concat(out, ",")
end
-- the shown row of an item
local function rowOf(id)
    for _, r in ipairs(f.list.rows) do if r:IsShown() and r.item and r.item.id == id then return r end end
end
-- Vorschläge: "Deine Wahl" first, then the ranking
assert(ids() == "pick,402,406", "the head's ranking at 58: " .. ids())
assert(has(plain(f.list.rows[1].name:GetText()), "Keine eigene Wahl") and not f.list.rows[1].del:IsShown(), "no own pick yet")
assert(f.lo:GetText() == "1" and f.hi:GetText() == "58" and f.mine.on and not f.all.on, "Meine Stufe")
local row = rowOf(402)
assert(has(plain(row.name:GetText()), "Helm der Pest"), "the name")
assert(has(row.name:GetText(), "ff0070dd"), "in its quality's colour")
assert(has(plain(row.sub:GetText()), "Stufe 58") and (has(row.sub:GetText(), "Stratholme") or has(row.sub:GetText(), "Baron")),
    "level and source: " .. plain(row.sub:GetText()))
assert(has(plain(row.gain:GetText()), "%"), "the gain in percent: " .. plain(row.gain:GetText()))
assert(row.src:IsShown() and row.src.atlas == "Dungeon", "the source's symbol: the dungeon mark")
assert(row.star:IsShown() and not row.star.on, "the star grey")
assert(row:GetHeight() == PL.ROW_H - 1 and row.frame._w == PL.ROW_ICON, "rows " .. PL.ROW_H .. " high, the icon " .. PL.ROW_ICON)
-- the list fills the right half down to the page's bottom
local x0 = LW + PL.GAP
assert(f.list.points.TOPLEFT.x == x0 and f.list:GetWidth() == NS.Theme.PAGE_W - x0 - NS.Theme.SCROLL_ROOM, "the right half")
assert(f.list.rowCount == math.floor((NS.Theme.PAGE_H - 52) / PL.ROW_H), "rows to the bottom: " .. f.list.rowCount)

---------------------------------------------------------------------------
-- a click: the own pick of the slot, shown on the doll; again: lifted
---------------------------------------------------------------------------
rowOf(406):Click()
assert(NS.BisPick("HEAD") == 406, "the beginner's helm is the own pick")
assert(d.slots.HEAD.item.id == 406, "and on the doll")
assert(rowOf(406).sel:IsShown() and has(rowOf(406).name:GetText(), "auctionhouse-icon-favorite"), "marked with the star")
assert(f.reset:IsEnabled(), "Zurücksetzen while a pick is there")
-- "Deine Wahl": the pick, overtaken by the better helm: Übernehmen; the red X lifts it
local pr = f.list.rows[1]
assert(has(plain(pr.name:GetText()), "Deine Wahl: Anfängerhelm") and pr.del:IsShown(), plain(pr.name:GetText()))
if pr.take:IsShown() then
    assert(has(plain(pr.sub:GetText()), "Überholt"), plain(pr.sub:GetText()))
    pr.take:Click()
    assert(NS.BisPick("HEAD") == 402, "Übernehmen takes the better one")
    NS.BisSetPick("HEAD", 406)
end
f.list.rows[1].del:Click()
assert(NS.BisPick("HEAD") == nil, "the red X lifts it")
rowOf(406):Click()
rowOf(406):Click()
assert(NS.BisPick("HEAD") == nil and d.slots.HEAD.item.id == 402, "a second click lifts it")
assert(not f.reset:IsEnabled(), "nothing to reset")

---------------------------------------------------------------------------
-- the star: on the wish list and off again; the wish list tab
---------------------------------------------------------------------------
rowOf(402).star:Click()
assert(NS.BisChar().wish[402], "the star puts it on the wish list")
assert(rowOf(402).star.on, "the star gold")
f.tabWish:Click()
assert(f.tabWish.on and not f.tabSuggest.on and ids() == "402", "the wish list: " .. ids())
assert(has(f.title:GetText(), "Wunschliste (1)"), f.title:GetText())
assert(has(plain(f.list.rows[1].sub:GetText()), "Kopf"), "the wish's slot in its line")
f.list.rows[1].star:Click()
assert(not NS.BisChar().wish[402] and ids() == "note", "off the list: " .. ids())
assert(has(plain(f.list.rows[1].name:GetText()), "Noch keine Wünsche"), "the empty list says so")
f.tabSuggest:Click()
assert(ids() == "pick,402,406")

---------------------------------------------------------------------------
-- a slot click: its suggestions
---------------------------------------------------------------------------
d.slots.CHEST:Click()
assert(AmisiaDB.settings.bis.planSlot == "CHEST" and f.title:GetText() == "Brust" and ids() == "pick,403", ids())
assert(edge(d.slots.CHEST)[1] == GOLD[1], "the chosen slot gold, over the green")
local rare = NS.Theme.QUALITY_RGB[3]
assert(edge(d.slots.HEAD)[1] == rare[1] and edge(d.slots.HEAD)[3] == rare[3], "the head's target in its quality's frame (rare)")
d.slots.HEAD:Click()

---------------------------------------------------------------------------
-- the level range: the boxes, Alle (above the own level: the calculation at 60), Meine Stufe
---------------------------------------------------------------------------
f.lo:SetText("20")
f.lo:GetScript("OnEnterPressed")(f.lo)
assert(AmisiaDB.settings.bis.planLo == 20 and ids() == "pick,402", "from 20: " .. ids())
f.all:Click()
assert(f.all.on and f.hi:GetText() == "60" and ids() == "pick,401,402,406", "every level: " .. ids())
assert(rowOf(401).src.atlas == "Raid", "the raid's mark")
f.mine:Click()
assert(AmisiaDB.settings.bis.planLo == nil and ids() == "pick,402,406", "back to 1 to the own level")

---------------------------------------------------------------------------
-- the search over every item
---------------------------------------------------------------------------
f.search:SetText("teufel")
f.search:GetScript("OnEnterPressed")(f.search)
assert(ids() == "405,404" or ids() == "404,405", "the hits: " .. ids())
assert(has(f.title:GetText(), "2 Treffer") and not f.tabSuggest.on, f.title:GetText())
-- a hit's click is the own pick of its own slot
f.list.rows[1]:Click()
assert(NS.BisPick(f.list.items[1].slotKey) == f.list.items[1].id, "the hit is the own pick of its slot")
NS.BisSetPick(f.list.items[1].slotKey, nil)
-- an item link or id: that item, a click makes it the own pick (the field "Item-Link oder ID")
f.search:SetText(LINKS[406])
f.search:GetScript("OnEnterPressed")(f.search)
assert(ids() == "406" and f.title:GetText() == "Item-Link oder ID", ids())
f.list.rows[1]:Click()
assert(NS.BisPick("HEAD") == 406 and ids() == "pick,402,406", "taken; the box is free again: " .. ids())
NS.BisSetPick("HEAD", nil)
f.search:SetText(" 406 ")
f.search:GetScript("OnEnterPressed")(f.search)
assert(ids() == "406", "a number")
-- a link Shift-clicked while the box has the focus goes into it
f.search:SetFocus()
f.takeLink(LINKS[402])
assert(ids() == "402", "a shift-clicked link: " .. ids())
f.search:ClearFocus()
f.search:SetText("")
f.search:GetScript("OnEnterPressed")(f.search)
assert(ids() == "pick,402,406", "the search cleared: " .. ids())

---------------------------------------------------------------------------
-- a set mark: the sets of the category, a set's pieces, back
---------------------------------------------------------------------------
mark("dungeon").button:Click()
assert(mark("dungeon").entry.on and f.title:GetText() == "Dungeon-Sets" and ids() == "set1", ids())
assert(not f.tabSuggest.on and not f.tabWish.on, "neither tab while the sets show")
f.list.rows[1]:Click()
assert(ids() == "set1,402,403", "the set's pieces: " .. ids())
assert(has(plain(f.list.rows[1].sub:GetText()), "1 von 2 Teilen"), plain(f.list.rows[1].sub:GetText()))
f.list.rows[3]:Click()
assert(NS.BisPick("CHEST") == 403, "a piece is the own pick of its slot")
NS.BisSetPick("CHEST", nil)
f.tabSuggest:Click()
assert(f.tabSuggest.on and not mark("dungeon").entry.on and ids() == "pick,402,406", "the tab Vorschläge leads back")

---------------------------------------------------------------------------
-- the lines of the photo: a drop "Stufe 58 · Stratholme - Baron", crafted "Lederverarbeitung 300" with
-- the profession's icon, a quest reward with "!" and "Quest: <title>" without the level, nothing
-- worn: "neu"
---------------------------------------------------------------------------
assert(has(plain(rowOf(402).sub:GetText()), "Stufe 58 · Stratholme - Baron Totenschwur"), plain(rowOf(402).sub:GetText()))
d.slots.LEGS:Click()
assert(ids() == "pick,405", ids())
assert(has(plain(rowOf(405).sub:GetText()), "Stufe 53 · Lederverarbeitung 300"), plain(rowOf(405).sub:GetText()))
assert(rowOf(405).src.texture == NS.Prof.ICONS.leatherworking, "the profession's icon: " .. tostring(rowOf(405).src.texture))
assert(plain(rowOf(405).gain:GetText()) == "neu", "nothing worn: " .. plain(rowOf(405).gain:GetText()))
d.slots.FEET:Click()
assert(ids() == "pick,408", ids())
assert(has(rowOf(408).name:GetText(), "!") and plain(rowOf(408).sub:GetText()) == "Quest: Endlich frei", plain(rowOf(408).sub:GetText()))
-- the menu "Optionen": the weapon plan, the gear page's source switches, the play style; its tooltip why
local otip = tipOf(function() f.optLink.scripts.OnEnter(f.optLink) end)
assert(has(otip, "Waffen:") and has(otip, "Warum diese Gewichte") and has(otip, "Spielstil"), otip)
f.optLink:Click()
local entries = {}
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() then entries[#entries + 1] = plain(b.label:GetText()) end end
assert(table.concat(entries, "|"):find("Quests", 1, true), table.concat(entries, "|"))
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() and plain(b.label:GetText()):find("Quests") then b:Click() break end end
assert(NS.BisOpts().sources.Q == false or not NS.BisOpts().sources.Q, "quests off")
assert(ids() == "pick,note", "no quest reward without quests: " .. ids())
f.optLink:Click()
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() and plain(b.label:GetText()):find("Quests") then b:Click() break end end
assert(NS.BisOpts().sources.Q and ids() == "pick,408", "back on")
-- the weapon plan from the menu
f.optLink:Click()
for _, b in ipairs(AmisiaMenu.buttons) do if b:IsShown() and plain(b.label:GetText()):find("Zweihand") then b:Click() break end end
assert(NS.BisOpts().plan == "2H", "the weapon plan: " .. tostring(NS.BisOpts().plan))
NS.BisSetPlan("auto")
d.slots.HEAD:Click()

---------------------------------------------------------------------------
-- the tab Ziele (the goals window's list, D-80): "N/17 Ziele" over its bar, the filters, the slots
-- by section; a click shows the slot's suggestions
---------------------------------------------------------------------------
f.tabGoals:Click()
assert(f.tabGoals.on and AmisiaDB.settings.bis.planTab == "goals" and f.prog:IsShown() and not f.lo:IsShown(), "the tab Ziele")
local p = NS.BisProgress()
assert(f.prog.text:GetText() == ("%d/17 Ziele"):format(p.done), f.prog.text:GetText())
assert(#f.prog.parts == 17, "17 parts")
assert(ids():find("^armor,HEAD,") and ids():find(",jewel,") and ids():find(",weapon,"), ids())
assert(has(plain(f.list.rows[1].sub:GetText()), "von 9 hast du"), plain(f.list.rows[1].sub:GetText()))
local function goalRow(key)
    for _, r in ipairs(f.list.rows) do if r:IsShown() and r.item and r.item.goal and r.item.key == key then return r end end
end
assert(has(plain(goalRow("HEAD").name:GetText()), "Helm der Pest") and has(plain(goalRow("HEAD").sub:GetText()), "Kopf"), "the head's target")
assert(goalRow("HEAD").sel:IsShown(), "the chosen slot lit")
-- the filters: Zu holen, Tasche, Ohne Verz.
assert(has(plain(f.ftodo.label:GetText()), "Zu holen " .. p.todo), plain(f.ftodo.label:GetText()))
f.ftodo:Click()
assert(AmisiaDB.settings.bis.planFilter == "todo" and f.ftodo.on and not ids():find("CHEST"), "the worn chest is not to get: " .. ids())
f.fall:Click()
assert(AmisiaDB.settings.bis.planFilter == nil and ids():find("CHEST"))
goalRow("CHEST"):Click()
assert(f.tabSuggest.on and AmisiaDB.settings.bis.planSlot == "CHEST" and ids() == "pick,403", "a slot's click: its suggestions " .. ids())
d.slots.HEAD:Click()

---------------------------------------------------------------------------
-- under the model: Ziele | Angelegt, the score with its tooltip
---------------------------------------------------------------------------
assert(f.showGoals.on and not f.showWorn.on and d.model.undressed, "the targets on the model")
f.showWorn:Click()
assert(AmisiaDB.settings.bis.planWorn and f.showWorn.on and not d.model.undressed and d.slots.HEAD.item.link == LINKS[410], "what is worn")
f.showGoals:Click()
assert(not AmisiaDB.settings.bis.planWorn and d.slots.HEAD.item.id == 402, "the targets again")
assert(has(plain(f.score.text:GetText()), "Wertung "), plain(f.score.text:GetText()))
local stip = tipOf(function() f.score.scripts.OnEnter(f.score) end)
assert(has(stip, "jetzt ") and has(stip, "Bestes auf Stufe 58") and has(stip, "Wertänderungen"), stip)

---------------------------------------------------------------------------
-- every way to the goals window opens the planner
---------------------------------------------------------------------------
assert(NS.ShowGoalsFrame == nil and NS.ToggleGoalsFrame == nil and _G.AmisiaGoalsFrame == nil, "no goals window any more")
NS.ShowPage("gear")
NS.Dispatch("bis gross")
assert(NS.CurrentPage() == "planner" and f.tabGoals.on, "/amisia bis gross")
NS.ShowGear("goals")
NS.PageFrame("gear").goals.big:Click()
assert(NS.CurrentPage() == "planner" and f.tabGoals.on, "the gear page's button")
assert(AmisiaDB.settings.goalWindow == nil and NS.SettingItem("ui.goalScale") == nil, "the window's settings are gone")
-- an older file: the migration drops the window's place, choices and scale (step 3)
AmisiaDB.settings.goalWindow = { point = "CENTER", mode = "worn" }
AmisiaDB.settings.ui = AmisiaDB.settings.ui or {}
AmisiaDB.settings.ui.goalScale = 120
NS.MIGRATIONS[3](AmisiaDB)
assert(AmisiaDB.settings.goalWindow == nil and AmisiaDB.settings.ui.goalScale == nil, "migrated quietly")
f.tabSuggest:Click()

---------------------------------------------------------------------------
-- Zurücksetzen asks first
---------------------------------------------------------------------------
NS.BisSetPick("HEAD", 406)
NS.BisSetPick("CHEST", 403)
f.reset:Click()
local ask = _G.AmisiaConfirmFrame
assert(ask and ask:IsShown() and NS.BisPick("HEAD") == 406, "a question first")
ask.ok:Click()
assert(NS.BisPick("HEAD") == nil and NS.BisPick("CHEST") == nil, "every own pick of the spec gone")

---------------------------------------------------------------------------
-- the warning: an own pick the character cannot use
---------------------------------------------------------------------------
NS.BisChar().pick = { dps = { HEAD = 404 } }   -- gloves in the head slot: kept, not used
NS.Fire("BIS_CHANGED", "pick")
assert(f.warn:IsShown(), "the warning while an own pick is not used")
assert(has(tipOf(function() f.warn.scripts.OnEnter(f.warn) end), "Kopf: Das kann dein Charakter nicht tragen."), "it names the slot")
NS.BisChar().pick = nil
NS.Fire("BIS_CHANGED", "pick")
assert(not f.warn:IsShown(), "gone again")

---------------------------------------------------------------------------
-- the page: 602 x 478, the head row at the top, nothing past the right edge
---------------------------------------------------------------------------
assert(f.bands[1]:GetHeight() == NS.Theme.LAYOUT.ROW_H and f.headLeft:GetWidth() == LW)
-- the window dragged wider (D-71): the panel, the doll and the list follow
NS.Theme.PAGE_W_NOW = 1000
NS.W.FitWidths()
local wide = math.floor(1000 * PL.LEFT_RATIO)
assert(wide > LW)
assert(f.panel:GetWidth() == wide and d.dollW == wide - 2 * PL.PAD and d.slots.HANDS.points.TOPLEFT.x == d.dollW - P.SLOT, "wider")
assert(f.list.points.TOPLEFT.x == wide + PL.GAP and f.list:GetWidth() == 1000 - wide - PL.GAP - NS.Theme.SCROLL_ROOM, "the list follows")
NS.Theme.PAGE_W_NOW = NS.Theme.PAGE_W
NS.W.FitWidths()
assert(f.panel:GetWidth() == LW)
assert(PL.DOLL_Y + P.MODEL_H + P.WEAPON_GAP + P.SLOT + PL.SWITCH_GAP + NS.Theme.CHIP_H <= NS.Theme.PAGE_H - PL.PAD - NS.Theme.BUTTON_H,
    "doll and switch above Zurücksetzen")
-- NS.ShowPlanner opens a view
NS.ShowPlanner("wish")
assert(NS.CurrentPage() == "planner" and f.tabWish.on)
NS.ShowPlanner("sets", "craft")
assert(f.title:GetText() == "Handwerks-Sets" and ids() == "set2", ids())
NS.ShowPlanner("suggest", nil, "CHEST")
assert(f.title:GetText() == "Brust" and ids() == "pick,403")
NS.ShowPlanner("goals")
assert(f.tabGoals.on)
print("gear planner ok")
