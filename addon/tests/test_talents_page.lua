-- The page "Talente" (Pages/Talents.lua), the classic three-tree look: three trees side by side
-- with their names and points centred in the head (no icon, no row locks), a square button per
-- talent on its row and column with its frame, glow, rank plate and state, the lines and arrows of
-- the prerequisites, left/right/shift clicks, the reset per tree (its X, a right click on the head)
-- and of everything, the level and the
-- Talented perk, the class choice with a plan per class, the live talents ("Eigene laden"), the
-- code box (copy and import), the tooltip, the command, the client's art, and the layout at the
-- main window's size (602 x 478).
local T = NS.Talents
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
STUB.class, STUB.level = "MAGE", 30

-- the tooltip's lines
local lines = {}
GameTooltip.AddLine = function(_, text, r, g, b) lines[#lines + 1] = { text = text, r = r, g = g, b = b } end
GameTooltip.AddDoubleLine = function(_, a, b2) lines[#lines + 1] = { text = tostring(a) .. " " .. tostring(b2) } end
local function tipText()
    local out = {}
    for _, l in ipairs(lines) do out[#out + 1] = tostring(l.text) end
    return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- the page opens on the own class, level 60, no Talented ranks
---------------------------------------------------------------------------
assert(NS.Panel("talents") and NS.Panel("talents").group == "gear", "registered in the gear section")
NS.ShowTalents()
assert(NS.CurrentPage() == "talents")
local f = NS.TalentsPageFrame()
assert(f and f:IsShown())
assert(f.class:GetValue() == "MAGE" and f.class.values[1].value == "MAGE" and f.class.values[2].value == "WARRIOR",
    "own class first")
assert(f.level.current == 60 and f.talented.current == 0)
assert(has(f.total:GetText(), "0 / 51"), f.total:GetText())

-- three trees with name and points, a button per talent at its place
assert(#f.trees == 3)
assert(has(f.trees[1].name:GetText(), "Arcane") and f.trees[1].pts:GetText() == "0 Punkte", f.trees[1].pts:GetText())
-- the head: the name centred at the top in the large gold font, the points centred under it; no
-- icon, no dark bar, the reset X only while the mouse is on the head
do
    local tr = f.trees[1]
    assert(tr.name.justifyH == "CENTER" and tr.name.points.TOP and tr.name.points.TOP.relPoint == "TOP" and tr.name.points.TOP.x == 0,
        "the name centred")
    assert(tr.name.font == NS.Theme.TALENT.NAME_FONT and tr.pts.font == NS.Theme.TALENT.PTS_FONT, "large gold name, small white points")
    assert(tr.pts.justifyH == "CENTER" and tr.pts.points.TOP.rel == tr.name and tr.pts.points.TOP.x == 0, "the points under the name")
    assert(tr.icon == nil and tr.rowLabels == nil, "no tree icon, no row locks")
    assert(not tr.reset:IsShown(), "the X waits for the mouse")
    tr.head:GetScript("OnEnter")(tr.head)
    assert(tr.reset:IsShown(), "hovering the head shows the X")
    tr.head:GetScript("OnLeave")(tr.head)
    assert(not tr.reset:IsShown(), "leaving hides it again")
end
assert(f.bg:GetAtlas() == "talent-background-mage", "the client's class background")
local b = f.buttons
local count = 0
for _ in pairs(b) do count = count + 1 end
assert(count == 7, "one button per talent: " .. count)
local L = f.layoutInfo
assert(b[102].points.TOPLEFT.x == L.left + 1 * L.pitch and b[103].points.TOPLEFT.y == -(L.top + 1 * L.pitch), "row and column")
assert(b[301].points.TOPLEFT.y == -(L.top + 6 * L.pitch), "row 7")
-- the grid is centred in the tree, the 4 columns fill it evenly
local TT = NS.Theme.TALENT
assert(L.left * 2 + 3 * L.pitch + TT.ICON + 2 * TT.FRAME <= TT.TREE_W and L.left >= 4, "centred: " .. L.left)
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
assert(has(f.total:GetText(), "1 / 51"))
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
f.plan = fresh
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
f.plan = assert(T.Decode("AT1.MAGE.0511.."))
f.level.minus:Click()
assert(f.level.current == 59 and AmisiaDB.talents.level == 59)
AmisiaDB.talents.level = 12
NS.Refresh()
assert(has(f.total:GetText(), "7 / 3"), "more spent than the level gives: " .. f.total:GetText())
assert(has(f.total:GetText(), "Stufe 16"), "the level the plan needs: " .. f.total:GetText())
b[201]:GetScript("OnClick")(b[201], "LeftButton")
assert(b[201].rank:GetText() == "0/5" and has(f.msg:GetText(), "Keine Punkte"), "no point left")
f.talented.plus:Click()
assert(AmisiaDB.talents.talented == 1 and has(f.total:GetText(), "/ 4"), f.total:GetText())
AmisiaDB.talents.level, AmisiaDB.talents.talented = nil, nil
NS.Refresh()

---------------------------------------------------------------------------
-- resets
---------------------------------------------------------------------------
f.trees[1].reset:Click()
assert(f.trees[1].pts:GetText() == "0 Punkte" and T.Spent(f.plan) == 0)
-- a right click on the head resets the tree too
f.plan.ranks[101] = 2
NS.Refresh()
assert(f.trees[1].pts:GetText() == "2 Punkte")
f.trees[1].head:GetScript("OnMouseUp")(f.trees[1].head, "LeftButton")
assert(T.Spent(f.plan, 1) == 2, "a left click leaves it")
f.trees[1].head:GetScript("OnMouseUp")(f.trees[1].head, "RightButton")
assert(T.Spent(f.plan, 1) == 0 and f.trees[1].pts:GetText() == "0 Punkte", "right click: tree reset")
f.plan.ranks[201] = 2
NS.Refresh()
f.resetAll:Click()
assert(T.Spent(f.plan) == 0 and AmisiaDB.talents.plans.MAGE == nil)

---------------------------------------------------------------------------
-- another class keeps its own plan
---------------------------------------------------------------------------
b[201]:GetScript("OnClick")(b[201], "LeftButton")
f.class.onPick("WARRIOR")
assert(f.class:GetValue() == "WARRIOR" and AmisiaDB.talents.class == "WARRIOR")
assert(f.buttons[401] and not f.buttons[101], "the warrior's tree")
assert(f.bg:GetAtlas() == "talent-background-warrior")
assert(not f.live:IsEnabled(), "only the own class has live talents")
f.buttons[401]:GetScript("OnClick")(f.buttons[401], "LeftButton")
f.class.onPick("MAGE")
assert(f.buttons[201].rank:GetText() == "1/5" and AmisiaDB.talents.plans.WARRIOR == "AT1.WARRIOR.1..")

---------------------------------------------------------------------------
-- the code box: paste and Enter imports; a bad code changes nothing
---------------------------------------------------------------------------
f.code:SetText("schau: AT1.WARRIOR.3.. ")
f.code:GetScript("OnEnterPressed")(f.code)
assert(f.class:GetValue() == "WARRIOR" and f.buttons[401].rank:GetText() == "3/3" and has(f.msg:GetText(), "übernommen"))
f.code:SetText("AT1.WARRIOR.9..")
f.code:GetScript("OnEnterPressed")(f.code)
assert(f.buttons[401].rank:GetText() == "3/3" and has(f.msg:GetText(), "Rang") and f.code:GetText() == "AT1.WARRIOR.3..",
    "the error, the plan unchanged, the box shows the plan again")
-- the command
NS.Dispatch("talente AT1.MAGE.2")
assert(NS.CurrentPage() == "talents" and f.class:GetValue() == "MAGE" and f.buttons[101].rank:GetText() == "2/2")

---------------------------------------------------------------------------
-- the own talents from the client
---------------------------------------------------------------------------
_G.C_ClassTalents = { GetActiveConfigID = function() return 5 end }
_G.C_Traits = {
    GetNodeInfo = function(_, id) return { ranksPurchased = ({ [102] = 5, [103] = 1 })[id] or 0 } end,
    GetTreeCurrencyInfo = function() return { { quantity = 15, spent = 6 } } end,
}
NS.Refresh()
assert(f.live:IsEnabled() and has(f.liveText:GetText(), "Im Spiel: 6/0/0") and has(f.liveText:GetText(), "6 von 21"), f.liveText:GetText())
lines = {}
b = f.buttons
b[103]:GetScript("OnEnter")(b[103])
assert(has(tipText(), "Im Spiel: Rang 1"), "the live rank where it differs")
f.live:Click()
assert(f.code:GetText() == "AT1.MAGE.051.." and has(f.msg:GetText(), "aus dem Spiel"))
-- a fresh character opens with its live talents when it has no plan
AmisiaDB.talents.plans.MAGE = nil
NS.ShowTalents()
f.class.onPick("WARRIOR")
f.class.onPick("MAGE")
assert(f.code:GetText() == "AT1.MAGE.051..", "no plan: the live talents")

---------------------------------------------------------------------------
-- layout at the main window's size
---------------------------------------------------------------------------
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
Lay.row("head", f.class, f.levelLabel, f.level, f.talentedLabel, f.talented, f.total)
Lay.row("trees", f.trees[1], f.trees[2], f.trees[3])
Lay.column("parts", f.class, f.trees[1], f.msg, f.live)
Lay.row("foot", f.live, f.resetAll, f.codeLabel, f.code)
for id, btn in pairs(f.buttons) do Lay.inside("talent " .. id, btn) end
-- the rank plates stay inside their tree, the glow too
for _, btn in pairs(f.buttons) do
    local p = btn.points.TOPLEFT
    assert(p.x - #TT.GLOW >= 0 and p.x + TT.ICON + 2 * TT.FRAME + TT.PLATE_X <= TT.TREE_W, "inside the tree across")
    assert(-p.y + TT.ICON + 2 * TT.FRAME - TT.PLATE_Y <= TT.TREE_H, "inside the tree down")
end
-- without the client's art: no arrow heads, the lines and frames stay, nothing breaks
STUB.missingAtlases["talents-arrow-head-yellow"] = true
STUB.missingAtlases["talents-arrow-head-gray"] = true
STUB.missingAtlases["talent-background-mage"] = true
NS.Refresh()
for _, a in pairs(f.arrows) do assert(a.line:IsShown() and not a.head:IsShown(), "a line without its head") end
STUB.missingAtlases["talents-arrow-head-yellow"] = nil
STUB.missingAtlases["talents-arrow-head-gray"] = nil
STUB.missingAtlases["talent-background-mage"] = nil
NS.Refresh()

-- the button: a 36 px icon in a thin square frame (no rounded mask, no node atlas)
do
    local any
    for _, bt in pairs(NS.TalentsPageFrame().buttons) do any = bt break end
    assert(any and any._w == 38 and any._h == 38, "36 px icon + 1 px frame")
    assert(any.icon.points.TOPLEFT.x == 1 and any.icon.points.BOTTOMRIGHT.x == -1, "the icon inside the frame")
    assert(any.mask == nil and any.border == nil, "square: no mask, no node atlas")
    for _, e in ipairs(any.frame) do assert(e.atlas == nil and e.color, "a drawn frame") end
end
print("test_talents_page ok")
