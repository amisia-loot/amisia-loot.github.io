-- The part Übersicht (F-154, D-85): in the detail views of Dungeons and Raids the bosses stand on the
-- left as rows with their portrait (the boss's model on a black disc in a gold ring, the client's skull
-- without a model), "n. Name" and a grey line (items, upgrades); the chosen boss on the right: a head
-- with its portrait, name and "Boss n von m", its loot under it with the item's icon in its quality's
-- ring, the name, slot and gain, the drop rate and the wish star. A new dungeon chooses the first boss
-- with an upgrade; the choice per page and dungeon in memory, kept across a refresh and the window's
-- height. Quests and Wunschliste stay lists.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local T = NS.Theme
local BV = T.DBOSS

NS.BIS = nil
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
NS.GEAR = { built = "test-boss-view", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },              -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },                        -- 2
    { "D", "Hall of Thanes", "Plunder", nil },                         -- 3
    { "D", "Ruins of Lordaeron", "The Baron", nil },                   -- 4
    { "D", "Ruins of Lordaeron", "Witherfang", nil },                  -- 5
    { "D", "Hall of Thanes", "Durgen Dirgehammer", nil },              -- 6
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
-- Durgen: one helm worse than the worn one, not wished (no loot for the character, F-170)
gear(513, "Dirgehelm", "HEAD", 1, 16, { 6 })
STUB.worn[1] = STUB.items[510].link
NS.Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
for i = 0, 7 do assert(NS.WishAdd(520 + i)) end
assert(NS.WishAdd(512))

-- the build's NPC of Magmatus (BisData.lua bossNames): the client's "Infurnus" of the game's order is
-- him (the same NPC in the facts' npcs, F-170)
NS.BIS = { DG = {} }
for _, e in ipairs(NS.DUNGEON_FACTS.list) do
    local c = {}
    for k, v in pairs(e) do c[k] = v end
    if e.key == "thanes" then c.bossNames = { [261316] = "Magmatus" } end
    NS.BIS.DG[#NS.BIS.DG + 1] = c
end
NS.ShowDungeon("thanes")
local D = NS.PageFrame("dungeons")
assert(D.chosen == "thanes", "the thanes' detail")
local V = D.bossView
assert(V:IsShown() and not D.detail:IsShown(), "Übersicht: the boss view, not the list")

local function heads(P)
    local out = {}
    for _, h in ipairs(P.bossView.list.items) do out[h.text] = h end
    return out
end
local function chosen(P)
    for _, h in ipairs(P.bossView.list.items) do if h.on then return h end end
end
local function bossRow(P, name)
    for _, r in ipairs(P.bossView.list.rows) do
        if r:IsShown() and r.item and r.item.text == name then return r end
    end
end
local function lootIds(P)
    local out = {}
    for _, e in ipairs(P.bossView.loot.items) do out[#out + 1] = tostring(e.id) end
    return table.concat(out, ",")
end

---------------------------------------------------------------------------
-- the bosses in the game's order, the first with an upgrade chosen; every boss of the order, also
-- those without loot for the character (F-170): Magmatus at Infurnus' place by his NPC
---------------------------------------------------------------------------
local order = {}
for _, h in ipairs(V.list.items) do order[#order + 1] = h.n .. "." .. h.text end
order = table.concat(order, ",")
assert(order == "1.Faldrim Anvilmar,2.Magmatus,3.Plunder,4.Durgen Dirgehammer", order)
local dr = bossRow(D, "Durgen Dirgehammer")
assert(plain(dr.sub:GetText()) == "1 Item · nichts für dich", plain(dr.sub:GetText()))
assert(chosen(D).text == "Faldrim Anvilmar" and lootIds(D) == "501", "Faldrim chosen: " .. lootIds(D))
local fr = bossRow(D, "Faldrim Anvilmar")
assert(fr.sel:IsShown() and not bossRow(D, "Magmatus").sel:IsShown(), "the chosen row lit")
assert(has(plain(fr.name:GetText()), "1. Faldrim Anvilmar"), plain(fr.name:GetText()))
assert(plain(fr.sub:GetText()) == "1 Item · 1 Upgrade", plain(fr.sub:GetText()))
assert(plain(bossRow(D, "Magmatus").sub:GetText()) == "8 Items", plain(bossRow(D, "Magmatus").sub:GetText()))
-- the portrait: the gold ring over the disc; without a model the client's skull
assert(fr.port.ring.texture == BV.RING and fr.port.disc.texture == NS.W.DISC, "ring and disc")
assert(fr.port.ring.vertexColor[1] == NS.W.GOLD[1], "a gold ring")
assert(fr.port.skull:IsShown() and not fr.port.model:IsShown(), "no model in the stub: the skull")
-- the head: the chosen boss's name and its place
assert(plain(V.head.name:GetText()) == "Faldrim Anvilmar", plain(V.head.name:GetText()))
assert(has(plain(V.head.sub:GetText()), "Boss 1 von 4"), plain(V.head.sub:GetText()))
assert(not V.none:IsShown(), "loot known")

---------------------------------------------------------------------------
-- a model where the client has one
---------------------------------------------------------------------------
local p = fr.port
local m = p.model
m.SetCreature = function(self, id) self.creature = id end
m.SetPortraitZoom = function(self, z) self.zoom = z end
D.bossView.list.items[1].b.npc = 4711
D.bossView.list:Redraw()
assert(m.creature == 4711 and m.zoom == BV.ZOOM and m:IsShown() and not p.skull:IsShown(), "the boss's model, zoomed")
D.bossView.list.items[1].b.npc = nil
D.bossView.list:Redraw()
assert(m.creature == 261306 and m:IsShown(), "without its own the NPC of the facts' order (F-170)")
D.bossView.list.items[1].npc = nil
D.bossView.list:Redraw()
assert(not m:IsShown() and p.skull:IsShown(), "back to the skull")
D.bossView.list.items[1].npc = 261306
-- a boss of the order without loot rows has its portrait too
local dp = bossRow(D, "Durgen Dirgehammer").port
dp.model.SetCreature = function(self, id) self.creature = id end
D.bossView.list:Redraw()
assert(dp.model.creature == 261319 and dp.model:IsShown(), "Durgen's NPC from the facts' order")
dp.model.SetCreature = nil
m.SetCreature, m.SetPortraitZoom = nil, nil

---------------------------------------------------------------------------
-- a click chooses a boss: its loot on the right with icons, qualities, rates and stars
---------------------------------------------------------------------------
local mr = bossRow(D, "Magmatus")
mr:Click()
assert(chosen(D).text == "Magmatus" and #V.loot.items == 8, "Magmatus' eight helms")
assert(has(plain(V.head.sub:GetText()), "Boss 2 von 4"))
-- Durgen chosen: no loot rows, the text says the loot is not for the character
bossRow(D, "Durgen Dirgehammer"):Click()
assert(#V.loot.items == 0 and V.none:IsShown() and plain(V.none:GetText()) == "Von diesem Boss kennt Amisia keine Beute für dich.",
    plain(V.none:GetText()))
bossRow(D, "Magmatus"):Click()
V.loot:Fit(8)
local Q = T.QUALITY_RGB
for j, r in ipairs(V.loot.rows) do
    if r:IsShown() then
        local id = r.item.id
        assert(r.icon.texture ~= nil, "an icon")
        local q = STUB.items[id].quality
        local c = r.frame.ringColor
        assert(c and c[1] == Q[q][1] and c[2] == Q[q][2] and c[3] == Q[q][3], "the ring in the quality's colour " .. j)
        assert(has(plain(r.name:GetText()), "Magmahelm"), plain(r.name:GetText()))
        assert(has(plain(r.sub:GetText()), NS.BIS_SLOT_NAME.HEAD or "Kopf"), plain(r.sub:GetText()))
        assert(r.star.on, "the star of a wished item: " .. id)
        assert(not has(r.name:GetText(), "|T"), "no wish mark in the name: the star shows it")
    end
end
-- the star toggles the wish (Faldrim's helm, an upgrade: listed either way)
bossRow(D, "Faldrim Anvilmar"):Click()
assert(not V.loot.rows[1].star.on, "not wished")
V.loot.rows[1].star:Click()
NS.Refresh()
assert(V.loot.rows[1].item.id == 501 and V.loot.rows[1].star.on, "wished")
V.loot.rows[1].star:Click()
NS.Refresh()
assert(not V.loot.rows[1].star.on, "taken off the wish list")
bossRow(D, "Magmatus"):Click()
-- a loot row's tooltip is its item's, Ctrl-click the dressing room, the right button the menu
local tipped, lines = nil, {}
local setHyper, setByID, addLine = GameTooltip.SetHyperlink, GameTooltip.SetItemByID, GameTooltip.AddLine
GameTooltip.SetHyperlink = function(_, link) tipped = link end
GameTooltip.SetItemByID = function(_, id) tipped = id end
GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
local lr = V.loot.rows[2]
lr.scripts.OnEnter(lr)
assert(tipped == STUB.items[lr.item.id].link or tipped == lr.item.id, "the item's tooltip: " .. tostring(tipped))
assert(has(table.concat(lines, "|"), "Strg-Klick"), table.concat(lines, "|"))
GameTooltip.SetHyperlink, GameTooltip.SetItemByID, GameTooltip.AddLine = setHyper, setByID, addLine
local ctrl0, dress0, dressed = _G.IsControlKeyDown, _G.DressUpLink, nil
_G.IsControlKeyDown = function() return true end
_G.DressUpLink = function(link) dressed = link; return true end
lr.scripts.OnClick(lr, "LeftButton")
assert(dressed == STUB.items[lr.item.id].link, "Ctrl-click: the dressing room")
_G.IsControlKeyDown, _G.DressUpLink = ctrl0, dress0
local menu0, menuOwner = NS.W.Menu, nil
NS.W.Menu = function(owner) menuOwner = owner end
lr.scripts.OnClick(lr, "RightButton")
assert(menuOwner == lr, "the right button: the item's menu")
-- the right button on a boss: its kill menu, the choice stays
menuOwner = nil
local pr = bossRow(D, "Plunder")
pr.scripts.OnClick(pr, "RightButton")
NS.W.Menu = menu0
assert(chosen(D).text == "Magmatus", "a right click chooses nothing")
-- the hovered boss shows in the image
local setNpc, shownNpc = D.art.SetModelNpc, nil
D.art.SetModelNpc = function(_, npc) shownNpc = npc or "default" end
pr.scripts.OnEnter(pr)
assert(shownNpc ~= nil, "the hovered boss in the image")
pr.scripts.OnLeave(pr)
D.art.SetModelNpc = setNpc

---------------------------------------------------------------------------
-- layout at the main window's size: the two columns side by side, inside the page
---------------------------------------------------------------------------
NS.W.FitLists()   -- (the loot list was fitted to eight rows above)
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(D, T.PAGE_W, T.PAGE_H)
Lay.row("boss view", V.list, V.head)
Lay.row("boss view loot", V.list, V.loot)
Lay.column("boss view right", V.head, V.loot)
Lay.inside("boss list bar", V.list.bar)
Lay.inside("loot bar", V.loot.bar)
Lay.row("boss row", bossRow(D, "Magmatus").port, bossRow(D, "Magmatus").name)
Lay.row("loot row", V.loot.rows[1].frame, V.loot.rows[1].name, V.loot.rows[1].rate, V.loot.rows[1].star)
Lay.row("head", V.head.port, V.head.name)
Lay.row("bosses tabs", D.parts.bosses, D.parts.map, D.parts.quests, D.parts.wish, D.way)
Lay.column("detail body", D.spec, D.art, D.header, V)

---------------------------------------------------------------------------
-- the choice per dungeon, kept across a refresh and the window's height
---------------------------------------------------------------------------
NS.ShowDungeon("lordaeron")
assert(D.chosen == "lordaeron" and chosen(D).text == "The Baron", "the ruins start with their own default")
NS.ShowDungeon("thanes")
assert(chosen(D).text == "Magmatus", "the thanes keep their choice")
NS.Refresh()
assert(chosen(D).text == "Magmatus", "a refresh keeps it")
local F = AmisiaFrame
NS.W.FitLists()
local rowsBefore, lootBefore = V.list.rowCount, V.loot.rowCount
F.applyHeight(F:GetHeight() + 3 * BV.ROW_H)
F.heightDone()
assert(V.list.rowCount > rowsBefore and V.loot.rowCount > lootBefore, "both lists grew with the window")
assert(chosen(D).text == "Magmatus", "the choice kept across the height")
F.applyHeight(T.MAIN.H)
F.heightDone()

---------------------------------------------------------------------------
-- the other parts: Quests and Wunschliste are lists, no boss view
---------------------------------------------------------------------------
D.parts.quests:Click()
assert(D.detail:IsShown() and not V:IsShown(), "Quests: the list")
D.parts.wish:Click()
assert(D.detail:IsShown() and not V:IsShown(), "Wunschliste: the list")
local wishHead
for _, e in ipairs(D.detail.items) do if e.kind == "boss" and e.text == "Magmatus" then wishHead = e end end
assert(wishHead and #wishHead.items == 8, "the wished helms under Magmatus")
D.parts.bosses:Click()
assert(V:IsShown() and not D.detail:IsShown(), "back in Übersicht")
D.plan:Click()
assert(D.pathView:IsShown() and not V:IsShown(), "no boss view in the journal")
D.pathView.back:Click()
assert(V:IsShown(), "back from the journal")
D.back:Click()
assert(not V:IsShown(), "no boss view on the table")

---------------------------------------------------------------------------
-- a boss without loot, an instance without bosses
---------------------------------------------------------------------------
local J = NS.DungeonJournalKit
NS.ShowDungeon("thanes")
local fake = { key = "fake", name = "Fake", bosses = { { name = "Leer", items = {}, perRun = 0 }, { name = "Voll", perRun = 0,
    items = { { id = 501, gain = 5, slotKey = "HEAD", upgrade = true } } } } }
J.showBosses(D, fake)
assert(chosen(D).text == "Voll", "the one with an upgrade")
bossRow(D, "Leer"):Click()
assert(chosen(D).text == "Leer" and #V.loot.items == 0 and V.none:IsShown(), "no loot: the empty text")
assert(plain(bossRow(D, "Leer").sub:GetText()) == "keine Beute bekannt", plain(bossRow(D, "Leer").sub:GetText()))
J.showBosses(D, { key = "empty", name = "Empty", bosses = {} })
assert(#V.list.items == 0 and has(plain(V.head.sub:GetText()), "keine Bosse") and not V.none:IsShown(), "no bosses")
NS.Refresh()

---------------------------------------------------------------------------
-- Raids: the same view
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
assert(P.bossView:IsShown() and not P.detail:IsShown() and P.chosen == "onyxia", "the raid's boss view")
assert(chosen(P).text == "Onyxia" and lootIds(P) == "530", "Onyxia and her tooth")
local LP = dofile(ADDON_DIR .. "/../tests/layout.lua")(P, T.PAGE_W, T.PAGE_H)
LP.row("raid boss view", P.bossView.list, P.bossView.head)
LP.row("raid tabs", P.parts.bosses, P.parts.map, P.parts.wish, P.way)
-- the page Raids has its own choice: the thanes on Dungeons keep theirs
NS.ShowDungeon("thanes")
assert(chosen(D).text == "Magmatus")
NS.ShowRaid("barrow")
assert(#P.bossView.list.items == 0, "no bosses known yet")
P.back:Click()
assert(not P.bossView:IsShown(), "no boss view on the raids' table")

NS.BIS = nil
print("boss view: order, all bosses, default, portrait, model, loot, star, clicks, layout, per dungeon, parts, empty, raids")
