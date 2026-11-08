-- The bosses fold (F-144, D-69 step 4): in the detail views of Dungeons (part Bosse) and Raids each
-- boss is a head row with the quest log's plus or minus; folded, its item rows are left out and a
-- strip of at most six icons (the rows' order, a frame in the item's quality colour, "+N" for the
-- rest) stands at the row's right end; an icon shows its item's tooltip and does what a click on the
-- item's row does. A new dungeon unfolds the bosses with an upgrade, "Alle aufklappen"/"Alle zuklappen"
-- in the header line (only in Bosse), the fold per page and dungeon in memory, kept across the window's
-- height; a boss without items has no sign and no strip.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local T = NS.Theme
local BH = T.DBOSS

NS.BIS = nil
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
NS.GEAR = { built = "test-boss-fold", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },              -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },                        -- 2
    { "D", "Hall of Thanes", "Plunder", nil },                         -- 3
    { "D", "Ruins of Lordaeron", "The Baron", nil },                   -- 4
    { "D", "Ruins of Lordaeron", "Witherfang", nil },                  -- 5
} }
local function gear(id, name, loc, strength, level, sources, quality)
    STUB.item(id, name, quality or 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    if sources then
        local row = { loc, 4, 2, level, quality or 3, 1, 20, 0, 0, 0 }
        for _, n in ipairs(sources) do row[#row + 1] = n end
        NS.GEAR.I[id] = row
    end
end
-- Faldrim and Plunder have an upgrade; Magmatus only eight wished helms worse than the worn one
-- (listed, no upgrade), in three qualities; the Baron an upgrade, Witherfang a wished helm only
gear(501, "Ambosshelm", "HEAD", 30, 16, { 1 })
for i = 0, 7 do gear(520 + i, "Magmahelm " .. i, "HEAD", 1 + i, 16, { 2 }, 2 + (i % 3)) end
gear(504, "Plünderstiefel", "FEET", 30, 16, { 3 })
gear(509, "Baronsschultern", "SHOULDER", 10, 17, { 4 })
gear(512, "Fanghelm", "HEAD", 2, 16, { 5 })
gear(510, "Alter Helm", "HEAD", 10, 10)
STUB.worn[1] = STUB.items[510].link
NS.Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
for i = 0, 7 do assert(NS.WishAdd(520 + i)) end
assert(NS.WishAdd(512))

NS.ShowDungeon("thanes")
local D = NS.PageFrame("dungeons")
assert(D.detail:IsShown() and D.chosen == "thanes", "the thanes' detail")
D.detail:Fit(30)

local function heads(P)
    local out = {}
    for _, e in ipairs(P.detail.items) do if e.kind == "boss" then out[e.text] = e end end
    return out
end
local function rowOf(P, pred)
    for _, r in ipairs(P.detail.rows) do if r:IsShown() and r.item and pred(r.item) then return r end end
end
local function headRow(P, name) return rowOf(P, function(e) return e.kind == "boss" and e.text == name end) end
local function itemRows(P)
    local n = 0
    for _, e in ipairs(P.detail.items) do if e.kind == "item" then n = n + 1 end end
    return n
end
local function shownIcons(r)
    local n = 0
    for _, b in ipairs(r.strip) do if b:IsShown() then n = n + 1 end end
    return n
end
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"

---------------------------------------------------------------------------
-- the default: the bosses with an upgrade unfolded, the others folded with their strip
---------------------------------------------------------------------------
local h = heads(D)
assert(h["Faldrim Anvilmar"].open and h["Plunder"].open and not h["Magmatus"].open, "upgrade bosses open, Magmatus folded")
local kinds = {}
for _, e in ipairs(D.detail.items) do kinds[#kinds + 1] = e.kind == "boss" and e.text or tostring(e.id) end
kinds = table.concat(kinds, ",")
assert(kinds == "Faldrim Anvilmar,501,Magmatus,Plunder,504", kinds)
local fr, mr = headRow(D, "Faldrim Anvilmar"), headRow(D, "Magmatus")
assert(fr.sign:IsShown() and fr.sign.texture == MINUS and shownIcons(fr) == 0 and not fr.more:IsShown(), "open: minus, no strip")
assert(mr.sign:IsShown() and mr.sign.texture == PLUS, "folded: plus")
-- the strip: six icons in the rows' order, "+2", the quality's colour on the frame
assert(shownIcons(mr) == BH.MAX_ICONS and mr.more:IsShown() and plain(mr.more:GetText()) == "+2", plain(mr.more:GetText()))
local mh = h["Magmatus"]
assert(#mh.items == 8, "eight items of Magmatus")
local Q = T.QUALITY_RGB
for j = 1, BH.MAX_ICONS do
    local b = mr.strip[j]
    assert(b.row == mh.items[j], "icon " .. j .. " is the item of row " .. j)
    local q = STUB.items[b.row.id].quality or NS.GEAR.I[b.row.id][5]
    assert(b.quality == q, "the item's quality: " .. tostring(b.quality) .. " ~= " .. tostring(q))
    local c = b.edges[1].color
    assert(c[1] == Q[q][1] and c[2] == Q[q][2] and c[3] == Q[q][3], "the frame in the quality's colour")
end
-- the icons sit at the row's right end, left of "+N", inside the row and right of the gain text
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(D, T.PAGE_W, T.PAGE_H)
local cells = { mr.sign, mr.name, mr.rate }
for j = 1, BH.MAX_ICONS do cells[#cells + 1] = mr.strip[j] end
cells[#cells + 1] = mr.more
Lay.row("folded boss row", unpack(cells))
local _, right = Lay.span(mr.more)
local _, rowRight = Lay.span(mr)
assert(right <= rowRight, "the strip inside the row: " .. right .. " > " .. rowRight)

-- an icon's tooltip is its item's, with the hint; the boss shows in the image meanwhile
local tipped, lines = nil, {}
local setHyper, setByID, addLine = GameTooltip.SetHyperlink, GameTooltip.SetItemByID, GameTooltip.AddLine
GameTooltip.SetHyperlink = function(_, link) tipped = link end
GameTooltip.SetItemByID = function(_, id) tipped = id end
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
local icon = mr.strip[2]
icon.scripts.OnEnter(icon)
assert(tipped == STUB.items[icon.row.id].link or tipped == icon.row.id, "the item's tooltip: " .. tostring(tipped))
assert(has(table.concat(lines, "|"), "Strg-Klick"), table.concat(lines, "|"))
icon.scripts.OnLeave(icon)
GameTooltip.SetHyperlink, GameTooltip.SetItemByID, GameTooltip.AddLine = setHyper, setByID, addLine

-- a click on an icon is a click on its row: Ctrl the dressing room, Shift the chat, right the menu
local ctrl, dressed = false, nil
local ctrl0, dress0 = _G.IsControlKeyDown, _G.DressUpLink
_G.IsControlKeyDown = function() return ctrl end
_G.DressUpLink = function(link) dressed = link; return true end
ctrl = true
icon.scripts.OnClick(icon, "LeftButton")
assert(dressed == STUB.items[icon.row.id].link, "Ctrl-click on the icon: the dressing room")
ctrl, dressed = false, nil
local menu1 = NS.W.Menu
icon.scripts.OnClick(icon, "RightButton")   -- (checked below; here only that it does not fold)
NS.W.Menu = menu1
assert(dressed == nil and not heads(D)["Magmatus"].open, "Ctrl alone dresses, the right button folds nothing")
local menu0, menuOwner = NS.W.Menu, nil
NS.W.Menu = function(owner) menuOwner = owner end
icon.scripts.OnClick(icon, "RightButton")
assert(menuOwner == icon, "the right button: the item's menu")
NS.W.Menu = menu0
_G.IsControlKeyDown, _G.DressUpLink = ctrl0, dress0
assert(not heads(D)["Magmatus"].open, "a modified or right click on an icon does not unfold")
-- a plain click on an icon unfolds its boss, as a click on the head; folded again by the head
icon.scripts.OnClick(icon, "LeftButton")
assert(heads(D)["Magmatus"].open and dressed == nil, "a plain click on an icon unfolds its boss")
headRow(D, "Magmatus"):Click()
assert(not heads(D)["Magmatus"].open, "folded again")
mr = headRow(D, "Magmatus")

---------------------------------------------------------------------------
-- a click on the head folds and unfolds
---------------------------------------------------------------------------
mr:Click()
assert(heads(D)["Magmatus"].open and itemRows(D) == 10, "Magmatus unfolded: " .. itemRows(D))
mr = headRow(D, "Magmatus")
assert(mr.sign.texture == MINUS and shownIcons(mr) == 0 and not mr.more:IsShown(), "unfolded: no strip")
-- its rows follow in the strip's order
local order = {}
for _, e in ipairs(D.detail.items) do order[#order + 1] = e end
for i, e in ipairs(order) do
    if e.kind == "boss" and e.text == "Magmatus" then
        for j = 1, 8 do assert(order[i + j] == mh.items[j], "row " .. j .. " under Magmatus") end
    end
end
headRow(D, "Faldrim Anvilmar"):Click()
assert(not heads(D)["Faldrim Anvilmar"].open and itemRows(D) == 9, "Faldrim folded")
local fr2 = headRow(D, "Faldrim Anvilmar")
assert(shownIcons(fr2) == 1 and not fr2.more:IsShown(), "one icon, no +N")
fr2:Click()
assert(heads(D)["Faldrim Anvilmar"].open, "unfolded again")
-- the boss model follows the hovered head as before
local setNpc, shownNpc = D.art.SetModelNpc, nil
D.art.SetModelNpc = function(_, npc) shownNpc = npc or "default" end
local fr3 = headRow(D, "Faldrim Anvilmar")
fr3.scripts.OnEnter(fr3)
assert(shownNpc ~= nil, "the hovered boss in the image")
D.art.SetModelNpc = setNpc

---------------------------------------------------------------------------
-- "Alle aufklappen" / "Alle zuklappen"
---------------------------------------------------------------------------
assert(D.foldAll:IsShown() and D.foldAll:GetText() == "Alle zuklappen", "all open: " .. tostring(D.foldAll:GetText()))
D.foldAll:Click()
assert(itemRows(D) == 0 and D.foldAll:GetText() == "Alle aufklappen", "all folded")
for _, e in pairs(heads(D)) do assert(not e.open) end
headRow(D, "Plunder"):Click()
assert(D.foldAll:GetText() == "Alle aufklappen", "one open: still Alle aufklappen")
D.foldAll:Click()
assert(itemRows(D) == 10 and D.foldAll:GetText() == "Alle zuklappen", "all open again")
-- the header line holds header, tabs, the link and the waypoint without overlap
Lay.row("bosses tabs", D.parts.bosses, D.parts.map, D.parts.quests, D.parts.wish, D.way)
Lay.row("bosses header line", D.header, D.foldAll)

-- folding shrinks the list: the offset clamps
D.detail:Fit(5)
local wheel = D.detail:GetScript("OnMouseWheel")
for _ = 1, 20 do wheel(D.detail, -1) end
assert(D.detail.offset == #D.detail.items - 5 and D.detail.offset > 0, "scrolled down")
D.foldAll:Click()
assert(#D.detail.items == 3 and D.detail.offset == 0, "the folded list from the top: " .. D.detail.offset)
D.foldAll:Click()
D.detail:Fit(30)

---------------------------------------------------------------------------
-- the fold per dungeon, kept across a refresh and the window's height
---------------------------------------------------------------------------
headRow(D, "Plunder"):Click()
assert(not heads(D)["Plunder"].open)
NS.ShowDungeon("lordaeron")
assert(D.chosen == "lordaeron")
h = heads(D)
assert(h["The Baron"].open and not h["Witherfang"].open, "the ruins start with their own default")
NS.ShowDungeon("thanes")
h = heads(D)
assert(h["Magmatus"].open and h["Faldrim Anvilmar"].open and not h["Plunder"].open, "the thanes keep their fold")
NS.Refresh()
assert(not heads(D)["Plunder"].open, "a refresh keeps it")
local F = AmisiaFrame
NS.W.FitLists()
local rowsBefore = D.detail.rowCount
local BOSS_ROW_H = 24 -- a row of the boss list (ROW_H in UI/Pages/Dungeons.lua)
F.applyHeight(F:GetHeight() + 3 * BOSS_ROW_H)
F.heightDone()
assert(D.detail.rowCount > rowsBefore, "the list grew with the window")
assert(not heads(D)["Plunder"].open and heads(D)["Magmatus"].open and itemRows(D) == 9, "the fold kept across the height")
local pr = headRow(D, "Plunder")
assert(pr and pr.sign.texture == PLUS and shownIcons(pr) == 1, "Plunder still folded on the redrawn rows")
F.applyHeight(T.MAIN.H)
F.heightDone()
assert(not heads(D)["Plunder"].open, "and back")

---------------------------------------------------------------------------
-- the link only in the part Bosse; not in the quests nor the journal
---------------------------------------------------------------------------
D.parts.quests:Click()
assert(not D.foldAll:IsShown(), "no fold link in Quests")
Lay.row("quests tabs", D.parts.bosses, D.parts.map, D.parts.quests, D.parts.wish, D.way)
D.parts.bosses:Click()
assert(D.foldAll:IsShown(), "back in Bosse")
D.plan:Click()
assert(D.pathView:IsShown() and not D.foldAll:IsShown(), "no fold link in the journal")
D.pathView.back:Click()
assert(D.foldAll:IsShown() and not D.pathView:IsShown(), "back from the journal")
D.back:Click()
assert(not D.foldAll:IsShown(), "no fold link on the cards")

---------------------------------------------------------------------------
-- a boss without items: no sign, no strip, a click does nothing
---------------------------------------------------------------------------
local J = NS.DungeonJournalKit
NS.ShowDungeon("thanes")
local fake = { key = "fake", name = "Fake", bosses = { { name = "Leer", items = {}, perRun = 0 }, { name = "Voll", perRun = 0,
    items = { { id = 501, gain = 5, slotKey = "head", upgrade = true } } },
    -- a gain without the row's "Upgrade" mark (under the threshold, a wish): folded
    { name = "Wunsch", perRun = 0, items = { { id = 502, gain = 0.5, slotKey = "neck" } } } } }
J.showBosses(D, fake)
local lr = headRow(D, "Leer")
assert(lr and not lr.sign:IsShown() and shownIcons(lr) == 0 and not lr.more:IsShown(), "no sign, no strip")
lr:Click()
assert(not heads(D)["Leer"].open, "nothing to unfold")
assert(heads(D)["Voll"].open and not heads(D)["Wunsch"].open, "open: the one with an upgrade; folded: a gain without the mark")
NS.Refresh()

---------------------------------------------------------------------------
-- Raids: the same fold
---------------------------------------------------------------------------
STUB.item(530, "Onyxias Zahn", 4)
local it = STUB.items[530]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_NECK", 4, 0, 60
it.stats = { ITEM_MOD_STRENGTH_SHORT = 30 }
STUB.level = 60
STUB.fire("PLAYER_LEVEL_UP")
NS.DropsLearnNames({ [10184] = "Onyxia" }, { [249] = { "raid", "Onyxias Hort" } })
assert(NS.DropsMerge({ h = "0e000001", npc = 10184, inst = 249, diff = 9, day = NS.DropsToday(), o = "aaaaaaaa", src = "G", it = { [530] = 1 } }) == "new")
NS.ShowRaid("onyxia")
local P = NS.PageFrame("raidjournal")
assert(P.detail:IsShown() and P.chosen == "onyxia")
local oh = heads(P)["Onyxia"]
assert(oh and oh.open and itemRows(P) == 1, "Onyxia's upgrade: unfolded")
assert(P.foldAll:IsShown() and P.foldAll:GetText() == "Alle zuklappen")
local LP = dofile(ADDON_DIR .. "/../tests/layout.lua")(P, T.PAGE_W, T.PAGE_H)
LP.row("raid header line", P.header, P.foldAll)
LP.row("raid tabs", P.parts.bosses, P.parts.map, P.parts.wish, P.way)
local orow = headRow(P, "Onyxia")
assert(orow.sign.texture == MINUS)
orow:Click()
orow = headRow(P, "Onyxia")
assert(not heads(P)["Onyxia"].open and itemRows(P) == 0 and shownIcons(orow) == 1 and orow.strip[1].row.id == 530, "folded with its icon")
assert(P.foldAll:GetText() == "Alle aufklappen")
P.foldAll:Click()
assert(heads(P)["Onyxia"].open and itemRows(P) == 1, "Alle aufklappen on Raids")
-- the page Raids has its own fold: the thanes on Dungeons keep theirs
NS.ShowDungeon("thanes")
assert(not heads(D)["Plunder"].open)
-- a raid without loot: no link
NS.ShowRaid("barrow")
assert(#P.detail.items == 0 and not P.foldAll:IsShown(), "no link without bosses")
P.back:Click()
assert(not P.foldAll:IsShown(), "no link on the raids' cards")

print("boss fold: default, strip, icons, head click, all, per dungeon, height, parts, raids")
