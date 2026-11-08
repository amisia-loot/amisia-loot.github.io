-- The page "Talente" (Pages/Talents.lua), the classic three-tree look: three trees side by side
-- with their names and points centred in the head (no icon, no row locks), a square button per
-- talent on its row and column with its frame, glow, rank plate and state, the lines and arrows of
-- the prerequisites, left/right/shift clicks, the reset per tree (its X, a right click on the head)
-- and of everything, the level and the
-- Talented perk, the class choice with a plan per class, the live talents ("Eigene laden"), the
-- code box (copy and import), the tooltip, the command, the client's art, and the layout at the
-- main window's size (602 x 478) and wider/taller.
-- D-76: the classes (with their crests), the two plans and the actions are the side bar's marks; the
-- line "Stufe · Verfügbar · Verteilt · Übrig" over the trees; each tree in its gold-brown frame on
-- its part of the class art; the short click hint at the bottom right.
local T = NS.Talents
local TT = NS.Theme.TALENT
local PP = TT.PAGE
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

local LEVELS = {}
for l = 10, 60 do LEVELS[#LEVELS + 1] = l end
NS.TALENTS = { build = "test", max = 51, levels = LEVELS, talented = { 9, 8, 7, 6, 5 }, classes = {
    MAGE = { id = 8, tree = 1112, spec = 1482,
        trees = { { 11, "Arcane", 1 }, { 12, "Fire", 2 }, { 13, "Frost", 3 } },
        gates = { [21] = { 101, 102 } },
        nodes = {
            { 101, 1001, 5001, 11, 1, 0, 0, 2, 0, 0, "Arcane Subtlety", "Reduces resistance by {1}.", { { "5", "10" } } },
            { 102, 1002, 5002, 12, 1, 0, 1, 5, 0, 0, "Arcane Focus", "Hit +{1}%.", { { "2", "4", "6", "8", "10" } } },
            { 103, 1003, 5003, 13, 1, 1, 1, 1, { 21, 5 }, { 102 }, "Arcane Concentration", "Clearcasting." },
            { 104, 1004, 5004, 14, 1, 1, 3, 1, { 21, 5 }, 0, "Arcane Mind", "Mind." },
            { 105, 1005, 5005, 15, 1, 1, 2, 1, { 21, 5 }, { 103 }, "Arcane Shift", "Shift." },
            { 201, 2001, 6001, 21, 2, 0, 0, 5, 0, 0, "Improved Fireball", "Cast -{1} sec.", { { "0.1", "0.2", "0.3", "0.4", "0.5" } } },
            { 301, 3001, 7001, 31, 3, 6, 3, 3, 0, 0, "Frostbite", "Freeze {1}%.", { { "5", "10", "15" } } },
        } },
    WARRIOR = { id = 1, tree = 1117, spec = 1491,
        trees = { { 41, "Arms", 4 }, { 42, "Fury", 5 }, { 43, "Protection", 6 } }, gates = {},
        nodes = { { 401, 4001, 8001, 41, 1, 0, 0, 3, 0, 0, "Improved Heroic Strike", "Cost -{1}.", { { "1", "2", "3" } } } } },
} }
T._reset()
for _, a in ipairs({ "talents-arrow-head-yellow", "talents-arrow-head-gray", "talent-background-mage", "talent-background-warrior" }) do
    STUB.atlases[a] = { 40, 40 }
end
-- the class art as wide as the client's (the whole talent window)
STUB.atlases["talent-background-mage"] = { 1612, 750 }
STUB.atlases["talent-background-warrior"] = { 1612, 750 }
STUB.class, STUB.level = "MAGE", 30

-- the tooltip's lines
local lines = {}
GameTooltip.AddLine = function(_, text, r, g, b) lines[#lines + 1] = { text = text, r = r, g = g, b = b } end
GameTooltip.AddDoubleLine = function(_, a, b2) lines[#lines + 1] = { text = tostring(a) .. " " .. tostring(b2) } end
-- the side bar's mark rows of the open page, by key
local MF
local function mark(key)
    MF = MF or AmisiaFrame
    for _, e in ipairs(MF.navOrder) do
        if e.entry.kind == "jump" and e.entry.key == key and e.button:IsShown() then return e end
    end
end
local function marksShown()
    local out = {}
    for _, e in ipairs(AmisiaFrame.navOrder) do
        if e.entry.kind == "jump" and e.button:IsShown() then out[#out + 1] = e.entry.key end
    end
    return table.concat(out, " ")
end
local function pick(cls) mark("class:" .. cls).button:Click() end
local function shownClass() return NS.TalentsPlan().class end
local function tipText()
    local out = {}
    for _, l in ipairs(lines) do out[#out + 1] = tostring(l.text) end
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- the page opens on the own class, level 60, no Talented ranks
---------------------------------------------------------------------------
assert(NS.Panel("talents") and NS.Panel("talents").group == "talents", "registered in the tab Talente")
NS.ShowTalents()
assert(NS.CurrentPage() == "talents")
local f = NS.PageFrame("talents")
assert(f and f:IsShown())
assert(shownClass() == "MAGE", "the own class")
assert(f.class == nil and f.slots == nil and f.live == nil and f.resetAll == nil and f.bigBtn == nil,
    "no class picker, plan tabs or buttons on the page: they are the side bar's marks")
assert(f.level.current == 60 and f.talented.current == 0)
-- the line over the trees: four parts spread over the width, centred
local function stats()
    return (f.statLevel:GetText() or "") .. " | " .. (f.statFree:GetText() or "") .. " | " .. (f.statSpent:GetText() or "")
        .. " | " .. (f.statLeft:GetText() or "")
end
local function plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
assert(plain(stats()) == "Stufe: 60 | Verfügbar: 51 | Verteilt: 0 | Übrig: 51", plain(stats()))
for i, fs in ipairs(f.stats) do
    assert(fs.justifyH == "CENTER" and fs.font == TT.STAT_FONT and fs._w == math.floor(602 / 4), "a quarter each")
    assert(fs.points.LEFT.rel == f.bands[1] and fs.points.LEFT.x == math.floor((i - 1) * 602 / 4), "spread over the width")
end
assert(f.hint:GetText() == "Linksklick + · Rechtsklick -" and f.hint.layoutBand == f.bottomRow and f.hint.points.RIGHT,
    "the click hint at the bottom right")

-- the side bar: the classes with their crests (the shown one chosen), the two plans, the actions
assert(marksShown() == "class:MAGE class:WARRIOR slot:1 slot:2 live reset import export", marksShown())
do
    local m = mark("class:MAGE")
    assert(m.entry.label == "Magier" or m.entry.label == T.ClassName("MAGE"), tostring(m.entry.label))
    assert(m.entry.on and m.button.bar:IsShown() and m.button.rule:IsShown(), "the shown class chosen, the first block")
    assert(m.button.symbol:IsShown() and m.button.symbol.texture == NS.Theme.CLASS_ICON.TEXTURE, "the class crest")
    local tc = m.button.symbol.texCoord
    local want = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.MAGE) or NS.Theme.CLASS_ICON.COORDS.MAGE
    assert(tc and tc[1] == want[1] and tc[4] == want[4], "the mage's part of the circles")
    assert(not mark("class:WARRIOR").entry.on and not mark("class:WARRIOR").button.rule:IsShown())
    local s1, s2 = mark("slot:1"), mark("slot:2")
    assert(s1.entry.label == "Plan 1: Primär" and s2.entry.label == "Plan 2: Sekundär", s1.entry.label)
    assert(s1.entry.on and not s2.entry.on and s1.button.rule:IsShown() and not s2.button.rule:IsShown(), "plans: own block")
    assert(mark("live").button.rule:IsShown() and not mark("reset").button.rule:IsShown(), "the actions: own block")
    for _, k in ipairs({ "live", "reset", "import", "export" }) do
        local e = mark(k)
        assert(e.entry.icon == TT.MARKS[k] and e.entry.tip, k .. ": a client mark and a tooltip")
        assert(not tostring(e.entry.icon.file or ""):find("Interface\\Icons\\", 1, true), k .. ": no spell or item icon")
    end
    assert(mark("reset").entry.label == "Plan leeren" and mark("import").entry.label == "Build importieren"
        and mark("export").entry.label == "Build exportieren" and mark("live").entry.label == "Eigene laden")
end

-- three trees with name and points, a button per talent at its place
assert(#f.trees == 3)
assert(has(f.trees[1].name:GetText(), "Arcane") and f.trees[1].pts:GetText() == "0 Punkte", f.trees[1].pts:GetText())
-- the head: the name centred at the top in the large gold font, the points centred under it; no
-- icon, no dark bar, the reset X only while the mouse is on the head
do
    local tr = f.trees[1]
    assert(tr.name.justifyH == "CENTER" and tr.name.points.TOP and tr.name.points.TOP.relPoint == "TOP" and tr.name.points.TOP.x == 0,
        "the name centred")
    assert(tr.name.font == PP.NAME_FONT and tr.pts.font == PP.PTS_FONT, "large gold name, small white points")
    assert(tr.pts.justifyH == "CENTER" and tr.pts.points.TOP.rel == tr.name and tr.pts.points.TOP.x == 0, "the points under the name")
    assert(tr.icon == nil and tr.rowLabels == nil, "no tree icon, no row locks")
    assert(not tr.reset:IsShown(), "the X waits for the mouse")
    tr.head:GetScript("OnEnter")(tr.head)
    assert(tr.reset:IsShown(), "hovering the head shows the X")
    tr.head:GetScript("OnLeave")(tr.head)
    assert(not tr.reset:IsShown(), "leaving hides it again")
end
-- each tree: its gold-brown frame, a dark ground, its part of the client's class art
for t, tr in ipairs(f.trees) do
    assert(tr.bg:GetAtlas() == "talent-background-mage" and tr.bg:IsShown() and tr.bg.alpha == TT.BG_ALPHA, "the class art")
    local tc = tr.bg.texCoord
    assert(tc and tc[1] >= (t - 1) / 3 - 1e-9 and tc[2] <= t / 3 + 1e-9 and tc[1] < tc[2], "its third of the art: " .. t)
    assert(tc[3] == 0 and tc[4] == 1, "the full height")
    assert(#tr.edges == 4 and tr.edges[1].color[1] == TT.TREE_EDGE[1] and tr.edges[1].color[2] == TT.TREE_EDGE[2], "the gold-brown frame")
    assert(tr.ground.color[4] == TT.TREE_GROUND[4], "the dark ground")
end
-- the cut keeps the tree's shape: width / height of the cut part = the tree's
do
    local tc, tr = f.trees[2].bg.texCoord, f.trees[2]
    local cw, ch = (tc[2] - tc[1]) * 1612, (tc[4] - tc[3]) * 750
    assert(math.abs(cw / ch - tr._w / tr._h) < 0.01, "cut to the tree's shape")
end
local b = f.buttons
local count = 0
for _ in pairs(b) do count = count + 1 end
assert(count == 7, "one button per talent: " .. count)
local L = f.layoutInfo
assert(b[102].points.TOPLEFT.x == L.left + 1 * L.pitch and b[103].points.TOPLEFT.y == -(L.top + 1 * L.pitch), "row and column")
assert(b[301].points.TOPLEFT.y == -(L.top + 6 * L.pitch), "row 7")
-- the grid is centred in the tree, the 4 columns fill it evenly
assert(L.left * 2 + 3 * L.pitch + PP.ICON + 2 * TT.FRAME <= PP.TREE_W and L.left >= 4, "centred: " .. L.left)
-- states: reachable with 0 points in colour, normal frame, white rank; unreachable desaturated,
-- dimmed, grey-brown frame, grey rank; no glow; the rank on its dark plate
local function frameIs(btn, c)
    for _, e in ipairs(btn.frame) do
        if e.color[1] ~= c[1] or e.color[2] ~= c[2] or e.color[3] ~= c[3] then return false end
    end
    return #btn.frame == 4
end
local function glowShown(btn)
    for _, t in ipairs(btn.glow) do if not t:IsShown() then return false end end
    return #btn.glow == 12
end
local function glowHidden(btn)
    for _, t in ipairs(btn.glow) do if t:IsShown() then return false end end
    return true
end
assert(b[101].rank:GetText() == "0/2" and b[101].state == "free" and not b[101].icon.desaturated)
assert(b[101].icon.vertexColor[1] == 1 and frameIs(b[101], TT.FRAME_COLOR.free) and glowHidden(b[101]), "reachable: colour, normal frame")
assert(b[101].rank.textColor[1] == 1 and b[101].rank.textColor[2] == 1 and b[101].rank.textColor[3] == 1, "white rank")
assert(b[103].state == "locked" and b[103].icon.desaturated and b[103].icon.vertexColor[1] == TT.DIM, "row 2 is locked: desaturated, dimmed")
assert(frameIs(b[103], TT.FRAME_COLOR.locked) and b[103].rank.textColor[1] == 0.5, "grey-brown frame, grey rank")
assert(b[101].plate.color[1] == 0 and b[101].plate.color[4] == TT.PLATE_ALPHA and b[101].rank.points.CENTER.rel == b[101].plate,
    "the rank on a dark plate")
assert(b[101].plate.points.BOTTOMRIGHT.x > 0 and b[101].plate.points.BOTTOMRIGHT.y < 0, "over the icon's lower right edge")
assert(b[101].icon.texCoord[1] == TT.CROP and b[101].icon.texCoord[2] == 1 - TT.CROP, "the icon cropped")
-- the arrows: 102 -> 103 down, 103 -> 105 to the right
local down, right = f.arrows["102>103"], f.arrows["103>105"]
assert(down and right, "an arrow per prerequisite")
assert(down.dir == "down" and right.dir == "right")
assert(down.head:GetAtlas() == "talents-arrow-head-gray" and down.head.rotation == 0)
assert(not down.met and down.line.color[1] < 0.5, "unmet: a dark line")
-- the line joins the right buttons: from 102's bottom to the head before 103's top; behind them
assert(down.line.points.TOP.rel == b[102] and down.line.points.TOP.relPoint == "BOTTOM", "from the prerequisite")
assert(down.line.points.BOTTOM.rel == b[103] and down.line.points.BOTTOM.relPoint == "TOP", "to the talent")
assert(right.line.points.LEFT.rel == b[103] and right.line.points.RIGHT.rel == b[105], "103 -> 105")
assert(down.line.layer == "ARTWORK", "behind the buttons")
assert(math.abs(right.head.rotation - math.pi / 2) < 1e-6)

---------------------------------------------------------------------------
-- clicks
---------------------------------------------------------------------------
b[101]:GetScript("OnClick")(b[101], "LeftButton")
assert(b[101].rank:GetText() == "1/2" and b[101].state == "partial" and f.trees[1].pts:GetText() == "1 Punkt")
assert(b[101].rank.textColor[1] < 0.5 and b[101].rank.textColor[2] == 1 and frameIs(b[101], TT.FRAME_COLOR.partial) and glowHidden(b[101]),
    "partly learned: green rank, green frame, no glow")
assert(plain(f.statSpent:GetText()) == "Verteilt: 1" and plain(f.statLeft:GetText()) == "Übrig: 50", stats())
b[101]:GetScript("OnClick")(b[101], "RightButton")
assert(b[101].rank:GetText() == "0/2")
_G.IsShiftKeyDown = function() return true end
b[102]:GetScript("OnClick")(b[102], "LeftButton")
_G.IsShiftKeyDown = function() return false end
assert(b[102].rank:GetText() == "5/5" and b[102].state == "maxed" and frameIs(b[102], { 1, 0.82, 0 }), "gold frame")
assert(glowShown(b[102]) and b[102].glow[1].color[1] == 1 and b[102].glow[1].color[2] == 0.82, "maxed: the gold glow shows")
assert(b[102].rank.textColor[1] == 1 and b[102].rank.textColor[2] == 0.82, "gold rank")
assert(b[103].state == "free" and down.head:GetAtlas() == "talents-arrow-head-yellow", "unlocked, the arrow lights up")
assert(down.met and down.line.color[1] == 1 and down.line.color[2] == 0.82, "a met prerequisite: a gold line")
b[103]:GetScript("OnClick")(b[103], "LeftButton")
b[105]:GetScript("OnClick")(b[105], "LeftButton")
assert(b[105].rank:GetText() == "1/1")
-- a right-click that would break something does nothing
b[103]:GetScript("OnClick")(b[103], "RightButton")
assert(b[103].rank:GetText() == "1/1" and has(f.msg:GetText(), "Arcane Shift"), "why it stays: " .. tostring(f.msg:GetText()))
assert(AmisiaDB.talents.plans.MAGE == "AT1.MAGE.0511..", "saved as code: " .. tostring(AmisiaDB.talents.plans.MAGE))
assert(f.code:GetText() == "AT1.MAGE.0511..", "the code box shows the plan")

---------------------------------------------------------------------------
-- the tooltip
---------------------------------------------------------------------------
lines = {}
b[101]:GetScript("OnEnter")(b[101])
local tip = tipText()
assert(has(tip, "Arcane Subtlety") and has(tip, "Rang 0/2") and has(tip, "Reduces resistance by 5.") and not has(tip, "Nächster Rang"), tip)
b[101]:GetScript("OnClick")(b[101], "LeftButton")
lines = {}
b[101]:GetScript("OnEnter")(b[101])
tip = tipText()
assert(has(tip, "Rang 1/2") and has(tip, "by 5.") and has(tip, "Nächster Rang:") and has(tip, "by 10."), tip)
-- a locked one names what is missing, in red
local fresh = T.NewPlan("MAGE")
NS.TalentsSetPlan(fresh)
NS.Refresh()
lines = {}
b[103]:GetScript("OnEnter")(b[103])
tip = tipText()
assert(has(tip, "Benötigt 5 Punkte in Arcane"), tip)
local red
for _, l in ipairs(lines) do if has(l.text, "Benötigt") then red = l end end
assert(red and red.r == 1 and red.g < 0.2, "the requirement in red")
b[103]:GetScript("OnLeave")(b[103])

---------------------------------------------------------------------------
-- level and Talented: fewer points, adding stops
---------------------------------------------------------------------------
NS.TalentsSetPlan(assert(T.Decode("AT1.MAGE.0511..")))
f.level.minus:Click()
assert(f.level.current == 59 and AmisiaDB.talents.level == 59)
AmisiaDB.talents.level = 12
NS.Refresh()
assert(plain(f.statSpent:GetText()) == "Verteilt: 7" and plain(f.statLeft:GetText()) == "Übrig: -4"
    and plain(f.statFree:GetText()) == "Verfügbar: 3", "more spent than the level gives: " .. stats())
assert(has(f.statSpent:GetText(), "|cffff4040") and has(f.statLeft:GetText(), "|cffff4040"), "in red")
assert(plain(f.statLevel:GetText()) == "Stufe: 12 (ab 16)", "the level the plan needs: " .. stats())
b[201]:GetScript("OnClick")(b[201], "LeftButton")
assert(b[201].rank:GetText() == "0/5" and has(f.msg:GetText(), "Keine Punkte"), "no point left")
f.talented.plus:Click()
assert(AmisiaDB.talents.talented == 1 and plain(f.statFree:GetText()) == "Verfügbar: 4", stats())
AmisiaDB.talents.level, AmisiaDB.talents.talented = nil, nil
NS.Refresh()

---------------------------------------------------------------------------
-- resets
---------------------------------------------------------------------------
f.trees[1].reset:Click()
assert(f.trees[1].pts:GetText() == "0 Punkte" and T.Spent(NS.TalentsPlan()) == 0)
-- a right click on the head resets the tree too
NS.TalentsPlan().ranks[101] = 2
NS.Refresh()
assert(f.trees[1].pts:GetText() == "2 Punkte")
f.trees[1].head:GetScript("OnMouseUp")(f.trees[1].head, "LeftButton")
assert(T.Spent(NS.TalentsPlan(), 1) == 2, "a left click leaves it")
f.trees[1].head:GetScript("OnMouseUp")(f.trees[1].head, "RightButton")
assert(T.Spent(NS.TalentsPlan(), 1) == 0 and f.trees[1].pts:GetText() == "0 Punkte", "right click: tree reset")
NS.TalentsPlan().ranks[201] = 2
NS.Refresh()
mark("reset").button:Click()
assert(T.Spent(NS.TalentsPlan()) == 0 and AmisiaDB.talents.plans.MAGE == nil, "the mark resets the plan")

---------------------------------------------------------------------------
-- another class keeps its own plan
---------------------------------------------------------------------------
b[201]:GetScript("OnClick")(b[201], "LeftButton")
pick("WARRIOR")
assert(shownClass() == "WARRIOR" and AmisiaDB.talents.class == "WARRIOR")
assert(mark("class:WARRIOR").entry.on and not mark("class:MAGE").entry.on, "the side bar follows")
assert(f.buttons[401] and not f.buttons[101], "the warrior's tree")
for _, tr in ipairs(f.trees) do assert(tr.bg:GetAtlas() == "talent-background-warrior") end
assert(not mark("live") and marksShown():find("slot:2 reset import export", 1, true), "only the own class has live talents")
f.buttons[401]:GetScript("OnClick")(f.buttons[401], "LeftButton")
pick("MAGE")
assert(f.buttons[201].rank:GetText() == "1/5" and AmisiaDB.talents.plans.WARRIOR == "AT1.WARRIOR.1..")

---------------------------------------------------------------------------
-- two plans per class: the chip switches Primär / Sekundär, each keeps its own
---------------------------------------------------------------------------
assert(mark("slot:1").entry.on and not mark("slot:2").entry.on)
mark("slot:2").button:Click()
assert(mark("slot:2").entry.on and not mark("slot:1").entry.on and T.Slot() == 2 and has(f.msg:GetText(), "Sekundär"))
assert(T.Spent(NS.TalentsPlan()) == 0 and f.buttons[201].rank:GetText() == "0/5", "the second plan starts empty")
f.buttons[101]:GetScript("OnClick")(f.buttons[101], "LeftButton")
mark("slot:1").button:Click()
assert(T.Slot() == 1 and f.buttons[201].rank:GetText() == "1/5" and f.buttons[101].rank:GetText() == "0/2", "back: the first plan")
assert(AmisiaDB.talents.plans2.MAGE ~= nil and AmisiaDB.talents.plans.MAGE ~= AmisiaDB.talents.plans2.MAGE, "both saved")
mark("slot:2").button:Click()
assert(f.buttons[101].rank:GetText() == "1/2", "the second plan kept")
mark("slot:1").button:Click()

---------------------------------------------------------------------------
-- the code box: paste and Enter imports; a bad code changes nothing
---------------------------------------------------------------------------
f.code:SetText("schau: AT1.WARRIOR.3.. ")
f.code:GetScript("OnEnterPressed")(f.code)
assert(shownClass() == "WARRIOR" and f.buttons[401].rank:GetText() == "3/3" and has(f.msg:GetText(), "übernommen"))
f.code:SetText("AT1.WARRIOR.9..")
f.code:GetScript("OnEnterPressed")(f.code)
assert(f.buttons[401].rank:GetText() == "3/3" and has(f.msg:GetText(), "Rang") and f.code:GetText() == "AT1.WARRIOR.3..",
    "the error, the plan unchanged, the box shows the plan again")
-- the command
NS.Dispatch("talente AT1.MAGE.2")
assert(NS.CurrentPage() == "talents" and shownClass() == "MAGE" and f.buttons[101].rank:GetText() == "2/2")
-- the import mark: the box emptied and focused, a paste and Enter takes it; leaving it empty brings
-- the plan's code back without an error
mark("import").button:Click()
assert(f.code:GetText() == "" and f.code:HasFocus() and has(f.msg:GetText(), "einfügen"), tostring(f.msg:GetText()))
f.code:ClearFocus()
assert(f.code:GetText() == T.Encode(NS.TalentsPlan()) and f.code:GetText() ~= "" and not has(f.msg:GetText(), "Kein"), "nothing pasted: the code again, " .. tostring(f.code:GetText()))
mark("import").button:Click()
f.code:SetText("AT1.WARRIOR.2..")
f.code:GetScript("OnEnterPressed")(f.code)
assert(shownClass() == "WARRIOR" and f.buttons[401].rank:GetText() == "2/3", "imported")
pick("MAGE")
-- the export mark: the plan's code in the box, focused and marked for Ctrl+C
f.code:SetText("x")
mark("export").button:Click()
assert(f.code:GetText() == T.Encode(NS.TalentsPlan()) and f.code:HasFocus() and has(f.msg:GetText(), "Strg+C"), tostring(f.msg:GetText()))
f.code:ClearFocus()

---------------------------------------------------------------------------
-- the own talents from the client
---------------------------------------------------------------------------
_G.C_ClassTalents = { GetActiveConfigID = function() return 5 end }
_G.C_Traits = {
    GetNodeInfo = function(_, id) return { ranksPurchased = ({ [102] = 5, [103] = 1 })[id] or 0 } end,
    GetTreeCurrencyInfo = function() return { { quantity = 15, spent = 6 } } end,
}
NS.Refresh()
assert(mark("live") and has(f.liveText:GetText(), "Im Spiel: 6/0/0") and has(f.liveText:GetText(), "6 von 21"), f.liveText:GetText())
lines = {}
b = f.buttons
b[103]:GetScript("OnEnter")(b[103])
assert(has(tipText(), "Im Spiel: Rang 1"), "the live rank where it differs")
mark("live").button:Click()
assert(f.code:GetText() == "AT1.MAGE.051.." and has(f.msg:GetText(), "aus dem Spiel"))
-- a fresh character opens with its live talents when it has no plan
AmisiaDB.talents.plans.MAGE = nil
NS.ShowTalents()
pick("WARRIOR")
pick("MAGE")
assert(f.code:GetText() == "AT1.MAGE.051..", "no plan: the live talents")

---------------------------------------------------------------------------
-- layout at the main window's size
---------------------------------------------------------------------------
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
Lay.row("head", f.statLevel, f.statFree, f.statSpent, f.statLeft)
Lay.row("trees", f.trees[1], f.trees[2], f.trees[3])
Lay.column("parts", f.statLevel, f.trees[1], f.msg, f.level)
Lay.row("foot", f.levelLabel, f.level, f.talentedLabel, f.talented, f.codeLabel, f.code, f.hint)
Lay.row("under the trees", f.msg, f.liveText)
assert(select(2, Lay.span(f.hint)) <= 602 - NS.Theme.LAYOUT.TEXT_X, "the hint at the right end")
Lay.fits(f.hint)
for _, fs in ipairs(f.stats) do Lay.fits(fs) end
for id, btn in pairs(f.buttons) do Lay.inside("talent " .. id, btn) end
-- the rank plates stay inside their tree, the glow too
-- and keep at least MARGIN (8 px) from the tree's edges: the outer buttons no longer touch the borders
for _, btn in pairs(f.buttons) do
    local p = btn.points.TOPLEFT
    local size = PP.ICON + 2 * TT.FRAME
    local out = math.max(#TT.GLOW, PP.PLATE_X)
    assert(p.x - #TT.GLOW >= PP.MARGIN and p.x + size + out <= PP.TREE_W - PP.MARGIN, "clear of the tree's sides: " .. p.x)
    assert(-p.y + size - PP.PLATE_Y <= PP.TREE_H - PP.MARGIN, "inside the tree down")
end
assert(PP.MARGIN >= 8 and 3 * PP.TREE_W + 2 * PP.TREE_GAP == 602, "the page: three trees fill its 602 px")
-- without the client's art: no arrow heads, the lines and frames stay, nothing breaks
STUB.missingAtlases["talents-arrow-head-yellow"] = true
STUB.missingAtlases["talents-arrow-head-gray"] = true
STUB.missingAtlases["talent-background-mage"] = true
pick("WARRIOR")
pick("MAGE")
for _, a in pairs(f.arrows) do assert(a.line:IsShown() and not a.head:IsShown(), "a line without its head") end
for _, tr in ipairs(f.trees) do assert(not tr.bg:IsShown() and tr.ground:IsShown() ~= false, "without the art: the dark ground") end
STUB.missingAtlases["talents-arrow-head-yellow"] = nil
STUB.missingAtlases["talents-arrow-head-gray"] = nil
STUB.missingAtlases["talent-background-mage"] = nil
pick("WARRIOR")
pick("MAGE")
assert(f.trees[1].bg:IsShown() and f.trees[1].bg:GetAtlas() == "talent-background-mage", "the art again")

-- a wider and taller main window (D-71): the trees share the width, grow down; the grid stays centred
do
    local keepW, keepH = NS.Theme.PAGE_W_NOW, NS.Theme.PAGE_H
    NS.Theme.PAGE_W_NOW, NS.Theme.PAGE_H = 902, 578
    NS.W.FitWidths()
    NS.Refresh()
    local tw = math.floor((902 - 2 * PP.TREE_GAP) / 3)
    assert(f.trees[1]._w == tw and f.trees[1]._h == PP.TREE_H + 100, "wider and taller trees: " .. f.trees[1]._w)
    assert(f.trees[3].points.TOPLEFT.x == 2 * (tw + PP.TREE_GAP), "side by side")
    local G = f.layoutInfo
    assert(G.left == math.floor((tw - (3 * PP.PITCH + PP.ICON + 2 * TT.FRAME)) / 2), "the grid centred again")
    assert(f.buttons[102].points.TOPLEFT.x == G.left + PP.PITCH, "the buttons placed again")
    assert(f.stats[4].points.LEFT.x == math.floor(3 * 902 / 4), "the line spread over the new width")
    assert(f.code._w > 200, "the code box takes the room")
    local Lay2 = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 902, 578)
    Lay2.row("trees", f.trees[1], f.trees[2], f.trees[3])
    Lay2.column("parts", f.statLevel, f.trees[1], f.msg, f.level)
    Lay2.row("foot", f.levelLabel, f.level, f.talentedLabel, f.talented, f.codeLabel, f.code, f.hint)
    NS.Theme.PAGE_W_NOW, NS.Theme.PAGE_H = keepW, keepH
    NS.W.FitWidths()
    NS.Refresh()
    assert(f.trees[1]._w == PP.TREE_W and f.trees[1]._h == PP.TREE_H, "back to the window's own size")
end

-- the button: a 36 px icon in a thin square frame (no rounded mask, no node atlas)
do
    local any
    for _, bt in pairs(NS.PageFrame("talents").buttons) do any = bt break end
    assert(any and any._w == 36 and any._h == 36, "34 px icon + 1 px frame")
    assert(any.icon.points.TOPLEFT.x == 1 and any.icon.points.BOTTOMRIGHT.x == -1, "the icon inside the frame")
    assert(any.mask == nil and any.border == nil, "square: no mask, no node atlas")
    for _, e in ipairs(any.frame) do assert(e.atlas == nil and e.color, "a drawn frame") end
end
print("test_talents_page ok")
