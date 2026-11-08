-- Review of the dungeon planner view (2.3): another dungeon's bosses start at the top of the boss
-- list, an NPC the planner does not count yet says so on its row, the overview card's dungeon line
-- stays within two lines.
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
NS.GEAR = { built = "test-dungeons-review-ui", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "20%" },              -- 1
    { "D", "Hall of Thanes", "Magmatus", nil },                        -- 2
    { "D", "Hall of Thanes", "Plunder", nil },                         -- 3
    { "D", "Ruins of Lordaeron", "The Baron", nil },                   -- 4
    { "D", "Ruins of Lordaeron", "Witherfang", nil },                  -- 5
} }
local function gear(id, name, loc, strength, level, sources)
    STUB.item(id, name, 3)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_" .. loc, 4, 2, level
    it.stats = { ITEM_MOD_STRENGTH_SHORT = strength }
    if sources then
        local row = { loc, 4, 2, level, 3, 1, 20, 0, 0, 0 }
        for _, n in ipairs(sources) do row[#row + 1] = n end
        NS.GEAR.I[id] = row
    end
end
gear(501, "Ambosshelm", "HEAD", 30, 16, { 1 })
gear(502, "Magmabrust", "CHEST", 30, 17, { 2 })
gear(503, "Magmabeine", "LEGS", 30, 18, { 2 })
gear(504, "Plünderstiefel", "FEET", 30, 16, { 3 })
gear(505, "Plünderhandschuhe", "HAND", 30, 16, { 3 })
gear(506, "Plündergürtel", "WAIST", 30, 16, { 3 })
gear(509, "Baronsschultern", "SHOULDER", 10, 17, { 4 })
gear(510, "Baronsring", "FINGER", 10, 17, { 4 })
gear(511, "Baronshals", "NECK", 10, 17, { 4 })
gear(512, "Fangarmschienen", "WRIST", 10, 17, { 5 })
gear(513, "Fangschwert", "2HWEAPON", 10, 17, { 5 })
gear(531, "Ghulumhang", "CLOAK", 40, 16)
NS.Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")

NS.ShowPage("dungeons")
local D = NS.PageFrame("dungeons")
assert(NS.DungeonNext().key == "thanes" and D.chosen == "thanes")
-- the bosses on the left (F-154): one row here, so the thanes and the ruins scroll
local BL = D.bossView.list
BL:Fit(1)
assert(#BL.items > BL.rowCount, "the thanes need the scroll bar: " .. #BL.items)

-- scrolled down in the thanes, then the ruins: their first boss on top
local wheel = BL:GetScript("OnMouseWheel")
for _ = 1, 20 do wheel(BL, -1) end
assert(BL.offset == #BL.items - BL.rowCount and BL.offset > 0, "scrolled down")
-- a card of the start view (F-143); from the detail view through its link back
local rows = setmetatable({}, { __index = function(_, key)
    return { Click = function()
        if D.back:IsShown() then D.back:Click() end
        D.table:RowOf(key):Click()
    end }
end })
rows.lordaeron:Click()
assert(D.chosen == "lordaeron")
assert(#BL.items > BL.rowCount, "the ruins scroll too: " .. #BL.items)
assert(BL.offset == 0, "the other dungeon starts at the top: offset " .. BL.offset)
assert(BL.rows[1].item and BL.rows[1].item.n == 1, "its first boss is shown")
-- a refresh of the same dungeon keeps the place
rows.thanes:Click()
wheel(BL, -1)
assert(BL.offset == 1)
NS.Refresh()
assert(BL.offset == 1, "the same dungeon keeps its scroll position")

-- an NPC only the guild's records know: listed with its kills, not counted
local today = NS.DropsToday()
NS.DropsLearnNames({ [7777] = "Lordaeron Ghoul" }, { [3001] = { "party", "Ruins of Lordaeron" } })
assert(NS.DropsMerge({ h = "0e000001", npc = 7777, inst = 3001, diff = 1, day = today, o = "aaaaaaaa", src = "G", it = { [531] = 1 } }) == "new")
rows.lordaeron:Click()
for _ = 1, 20 do wheel(BL, -1) end
local ghoulRow
for _, dr in ipairs(BL.rows) do
    if dr.item and dr.item.text == "Lordaeron Ghoul" then ghoulRow = dr end
end
assert(ghoulRow, "the ghoul is listed")
assert(plain(ghoulRow.sub:GetText()) == "1 Kill, zählt ab 3", ghoulRow.sub:GetText())
-- the item of an unknown chance says so (the Baron's shoulders)
NS.W.FitLists()
for _ = 1, 20 do wheel(BL, 1) end
for _, dr in ipairs(BL.rows) do
    if dr.item and dr.item.text == "The Baron" then dr:Click() end
end
local seen509
for _, dr in ipairs(D.bossView.loot.rows) do
    if dr.item and dr.item.id == 509 then
        seen509 = true
        assert(plain(dr.rate:GetText()) == "Chance unbekannt", dr.rate:GetText())
    end
end
assert(seen509, "the shoulders in the Baron's loot")
NS.W.FitLists()

-- the overview card: at most two lines above the button
local card
for _, c in ipairs(NS.cards) do if c.key == "gear" then card = c end end
local c = NS.W.Card(UIParent, 296, 112)
card.fill(c)
assert(plain(c.line2:GetText()):find("Nächster Dungeon: ", 1, true), c.line2:GetText())
assert(c.line2.maxLines == 2, "the card's line is clamped to two lines: " .. tostring(c.line2.maxLines))
