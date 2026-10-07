-- The page "Talente" (Pages/Talents.lua): three trees side by side with their names and points,
-- a button per talent on its row and column with rank and state, the row locks, the arrows of the
-- prerequisites, left/right/shift clicks, the reset per tree and of everything, the level and the
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
for _, a in ipairs({ "talents-node-square-yellow", "talents-node-square-green", "talents-node-square-gray",
                     "talents-arrow-head-yellow", "talents-arrow-head-gray", "talent-background-mage", "talent-background-warrior" }) do
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
assert(has(f.trees[1].name:GetText(), "Arcane") and f.trees[1].pts:GetText() == "0")
assert(f.bg:GetAtlas() == "talent-background-mage", "the client's class background")
local b = f.buttons
local count = 0
for _ in pairs(b) do count = count + 1 end
assert(count == 7, "one button per talent: " .. count)
local L = f.layoutInfo
assert(b[102].points.TOPLEFT.x == L.left + 1 * L.pitchX + L.pad and b[103].points.TOPLEFT.y == -(L.top + 1 * L.pitchY), "row and column")
assert(b[301].points.TOPLEFT.y == -(L.top + 6 * L.pitchY), "row 7")
-- state: free talents green, locked ones grey and desaturated, rank text
assert(b[101].rank:GetText() == "0/2" and b[101].state == "free" and not b[101].icon.desaturated)
assert(b[103].state == "locked" and b[103].icon.desaturated, "row 2 is locked")
assert(b[101].border:GetAtlas() == "UI-HUD-ActionBar-IconFrame" and b[101].border.vertexColor[2] == 1 and b[101].border.vertexColor[1] < 0.5, "green frame")
assert(b[103].border.vertexColor[1] == 0.55 and b[103].border.vertexColor[2] == 0.55, "grey frame")
-- the row lock beside row 2 of the first tree
assert(f.trees[1].rowLabels[2]:GetText() == "5" and f.trees[1].rowLabels[2]:IsShown() and not f.trees[1].rowLabels[1]:IsShown())
-- the arrows: 102 -> 103 down, 103 -> 105 to the right
local down, right = f.arrows["102>103"], f.arrows["103>105"]
assert(down and right, "an arrow per prerequisite")
assert(down.dir == "down" and right.dir == "right")
assert(down.head:GetAtlas() == "talents-arrow-head-gray" and down.head.rotation == 0)
assert(math.abs(right.head.rotation - math.pi / 2) < 1e-6)

---------------------------------------------------------------------------
-- clicks
---------------------------------------------------------------------------
b[101]:GetScript("OnClick")(b[101], "LeftButton")
assert(b[101].rank:GetText() == "1/2" and b[101].state == "partial" and f.trees[1].pts:GetText() == "1")
assert(has(f.total:GetText(), "1 / 51"))
b[101]:GetScript("OnClick")(b[101], "RightButton")
assert(b[101].rank:GetText() == "0/2")
_G.IsShiftKeyDown = function() return true end
b[102]:GetScript("OnClick")(b[102], "LeftButton")
_G.IsShiftKeyDown = function() return false end
assert(b[102].rank:GetText() == "5/5" and b[102].state == "maxed" and b[102].border.vertexColor[1] == 1 and b[102].border.vertexColor[2] == 0.82, "gold frame")
assert(b[103].state == "free" and down.head:GetAtlas() == "talents-arrow-head-yellow", "unlocked, the arrow lights up")
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
assert(f.trees[1].pts:GetText() == "0" and T.Spent(f.plan) == 0)
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
-- without the client's art: plain borders, nothing breaks
STUB.missingAtlases["talents-node-square-green"] = true
STUB.missingAtlases["UI-HUD-ActionBar-IconFrame"] = true
STUB.missingAtlases["talent-background-mage"] = true
NS.Refresh()
assert(f.buttons[201].border:GetAtlas() == nil and f.buttons[201].border.color ~= nil, "a coloured frame instead")
print("test_talents_page ok")

-- the button: a 36 px icon with the action bar's rounded mask and its thin rounded frame, tinted
-- green (can be raised), gold (full) or grey (locked)
STUB.missingAtlases["talents-node-square-green"] = nil
STUB.missingAtlases["UI-HUD-ActionBar-IconFrame"] = nil
STUB.missingAtlases["talent-background-mage"] = nil
NS.Refresh()
do
    local any
    for _, bt in pairs(NS.TalentsPageFrame().buttons) do any = bt break end
    assert(any and any._w == 36 and any._h == 36, "36 px button")
    assert(any.border._w == 40 and any.border.atlas == "UI-HUD-ActionBar-IconFrame", "the thin rounded frame")
    assert(any.mask and any.mask.atlas == "UI-HUD-ActionBar-IconFrame-Mask", "rounded icon")
end
