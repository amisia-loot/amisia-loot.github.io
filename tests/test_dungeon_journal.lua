-- The dungeon view's journal parts: the header image from the client's own loading screens
-- (DungeonArt.lua, the fallbacks, the crop that keeps the picture's proportions) with the boss
-- model, the quest XP (QuestXP.lua: what the quest window, the turn-in and the quest log say, kept
-- per quest at the highest value; the classic level scaling; the sums per dungeon inside and
-- outside), all quest givers of a dungeon marked on the world map (pins with the client's quest
-- icon, one per giver, cleared again, gone once done) and the dressing room on Ctrl-click.
local Gear, Map = NS.Gear, NS.Map
local Dn, QX = NS.Dungeons, NS.QuestXP
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function near(a, b, eps) return type(a) == "number" and math.abs(a - b) < (eps or 1e-6) end
local function byQid(list, qid) for _, q in ipairs(list or {}) do if q.qid == qid then return q end end end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- the client's model frame: SetCreature shows an NPC's creature (the stub frame has none)
do
    local create = CreateFrame
    _G.CreateFrame = function(kind, ...)
        local f = create(kind, ...)
        if kind == "PlayerModel" then
            f.SetCreature = function(self, id) self.creature = id end
            f.SetPortraitZoom = function(self, z) self.zoom = z end
        end
        return f
    end
end

---------------------------------------------------------------------------
-- the art data and the crop
---------------------------------------------------------------------------
local A = NS.DUNGEON_ART
assert(A and A.D and A.D.deadmines, "the generated art data loads")
local fid, kind = Dn.Art("deadmines")
assert(fid == 131833 and kind == "n", "the client's own Deadmines screen")
fid, kind = Dn.Art("thanes")
assert(fid == A.D.thanes[1] and kind == "w", "Forever's own wide screen")
assert(Dn.Art("drowned") == A.party[1], "a dungeon the client has no screen for: the general dungeon screen")
assert(Dn.Art("barrow") == A.raid[1], "a raid without its own: the general raid screen")
assert(Dn.Art("no-such-dungeon") == A.party[1])
local saved = NS.DUNGEON_ART
NS.DUNGEON_ART = nil
assert(Dn.Art("deadmines") == nil, "no art data: no image")
NS.DUNGEON_ART = saved

-- the crop: the middle of the picture at the banner's proportions (a 4:3 picture shown from a square
-- texture, a wide one of 2992 x 1684)
for _, k in ipairs({ "n", "w" }) do
    local l, r, t, b = Dn.ArtCoords(k, 600, 48)
    local aspect = k == "n" and 4 / 3 or 2992 / 1684
    assert(l >= 0 and r <= 1 and t >= 0 and b <= 1 and l < r and t < b, k)
    assert(near(aspect * (r - l) / (b - t), 600 / 48, 1e-3), "the proportions are kept: " .. k)
    assert(t > 0.25 and b < 0.8, "inside the picture, away from the frame and the empty bands: " .. k)
end
-- a tall banner never leaves the picture: the width is cut instead
local l, r, t, b = Dn.ArtCoords("w", 100, 100)
assert(t >= 0.16 and b <= 0.84 and r - l < 1 and near((2992 / 1684) * (r - l) / (b - t), 1, 1e-3), "a square crop")

-- the boss model's boss: the hovered one, else the one with the biggest gain per run, else the
-- first with an NPC id; none without NPC ids
local e = { bosses = { { name = "Ohne" }, { name = "Klein", npc = 5, perRun = 3 }, { name = "Groß", npc = 7, perRun = 9 } } }
assert(Dn.ModelNpc(e) == 7)
assert(Dn.ModelNpc(e, e.bosses[2]) == 5, "the hovered boss")
assert(Dn.ModelNpc(e, e.bosses[1]) == 7, "a hovered boss without an NPC id: the default")
assert(Dn.ModelNpc({ bosses = { { name = "A", npc = 4, perRun = 0 }, { name = "B", npc = 6, perRun = 0 } } }) == 4, "the first")
assert(Dn.ModelNpc({ bosses = { { name = "A" } } }) == nil and Dn.ModelNpc(nil) == nil)

---------------------------------------------------------------------------
-- quest XP: the level scaling
---------------------------------------------------------------------------
assert(QX.Factor(10, 10) == 1 and QX.Factor(15, 10) == 1 and QX.Factor(5, 10) == 1, "full up to five levels above")
assert(near(QX.Factor(16, 10), 0.8) and near(QX.Factor(19, 10), 0.2) and near(QX.Factor(20, 10), 0.1) and near(QX.Factor(40, 10), 0.1))
assert(QX.Round(87) == 85 and QX.Round(333) == 330 and QX.Round(777) == 775 and QX.Round(1234) == 1250, "the classic rounding")

---------------------------------------------------------------------------
-- quest XP: what the client says, kept per quest
---------------------------------------------------------------------------
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
local qid, rewardXP, logXP = nil, 0, {}
_G.GetQuestID = function() return qid end
_G.GetRewardXP = function() return rewardXP end
_G.GetQuestLogRewardXP = function(id) return logXP[id] or 0 end
qid, rewardXP = 99001, 1150
STUB.fire("QUEST_DETAIL")
assert(AmisiaDB.questxp and AmisiaDB.questxp[99001][1] == 1150 and AmisiaDB.questxp[99001][2] == 16, "the offer's XP at level 16")
STUB.level, rewardXP = 22, 460
STUB.fire("QUEST_COMPLETE")
assert(AmisiaDB.questxp[99001][1] == 1150 and AmisiaDB.questxp[99001][2] == 16, "a lower value at a higher level does not replace it")
STUB.level = 16
STUB.fire("QUEST_TURNED_IN", 99005, 900, 120)
assert(AmisiaDB.questxp[99005][1] == 900, "the turn-in's XP")
STUB.fire("QUEST_TURNED_IN", 99006, 0, 120)
assert(AmisiaDB.questxp[99006] == nil, "no XP (the level cap): nothing kept")
local value, how, seen = QX.For(99001, 18, 16)
assert(value == 1150 and how == "seen", "seen at the same level")
value, how = QX.For(99001, 18, 24)
assert(value == 925 and how == "scaled", "six levels above: 80 %, rounded: " .. tostring(value))
value, how = QX.For(99001, 18, 20)
assert(value == 1150 and how == "seen", "full XP both times")
value, how, seen = QX.For(99005, 0, 20)
assert(value == 900 and how == "other" and seen == 16, "no quest level: the value as seen, with its level")
assert(QX.For(99999, 20, 16) == nil, "never seen")
-- seen above the full range: the base is worked back
AmisiaDB.questxp[99007] = { 400, 26 }   -- quest level 20: 80 %
value, how = QX.For(99007, 20, 18)
assert(value == 500 and how == "scaled", tostring(value))
-- in the log: what the quest log says now, and it is kept
STUB.questsActive[99008] = true
logXP[99008] = 640
value, how = QX.For(99008, 0, 16)
assert(value == 640 and how == "log" and AmisiaDB.questxp[99008][1] == 640)
STUB.questsActive[99008] = nil
-- the recorder follows the collector's quest switch
NS.Set("collect.quests", false)
qid, rewardXP = 99009, 300
STUB.fire("QUEST_DETAIL")
assert(AmisiaDB.questxp[99009] == nil, "off: nothing recorded")
NS.Set("collect.quests", true)
-- broken saved data is dropped on load
AmisiaDB.questxp = { [1] = { "x", 2 }, [2] = { 50, 10 }, foo = { 1, 1 }, [3] = "bad" }
QX.Migrate(AmisiaDB)
assert(AmisiaDB.questxp[2] and AmisiaDB.questxp[1] == nil and AmisiaDB.questxp.foo == nil and AmisiaDB.questxp[3] == nil)
AmisiaDB.questxp = {}
-- texts
assert(Dn.XPText(950, "log") == "950" and Dn.XPText(1150, "seen") == "1150" and Dn.XPText(925, "scaled") == "~925")
assert(Dn.XPText(900, "other", 16) == "900 (Lvl 16)" and Dn.XPText(nil) == "")

---------------------------------------------------------------------------
-- a dungeon with quests (as in test_dungeon_guide.lua)
---------------------------------------------------------------------------
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { thanes = { 99001, 99005, 99011 }, deadmines = { 99010 } },
    Q = {
        [99001] = { "Grudge of the Thanes", 14, 18, "A", 0, "O", "Thane Giver", "1436:5633:4752", { 99002 }, nil, "thanes" },
        [99002] = { "Root Quest", 10, 12, "A", 0, "O", "Root Giver", "1436:1000:1000", nil, nil, nil },
        [99005] = { "Inside the Halls", 15, 17, "", 0, "I", "Halls Giver", "1436:4250:7170", nil, nil, "thanes" },
        [99011] = { "Second Grudge", 14, 18, "A", 0, "O", "Thane Giver", "1436:5633:4752", nil, nil, "thanes" },
        [99010] = { "Found Note", 15, 19, "", 0, "X", nil, nil, nil, nil, "deadmines", { 534 } },
    },
}
NS.GEAR = { built = "test-journal", Z = {}, I = {}, S = {
    { "D", "Hall of Thanes", "Faldrim Anvilmar", "50%" },          -- 1
    { "D", "The Deadmines", "Cookie", "50%" },                     -- 2
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
gear(501, "Thanenhelm", "HEAD", 30, 16, { 1 })
gear(511, "Keksumhang", "CLOAK", 8, 16, { 2 })
gear(510, "Alter Helm", "HEAD", 10, 10)
STUB.worn[1] = STUB.items[510].link
Gear._reset()
STUB.fire("PLAYER_EQUIPMENT_CHANGED")
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
Map._reset()
NS.BisBump()

AmisiaDB.questxp = { [99001] = { 1150, 16 }, [99005] = { 900, 16 } }
local qs = NS.DungeonQuests("thanes")
assert(#qs == 3, #qs)
local grudge, halls, second = byQid(qs, 99001), byQid(qs, 99005), byQid(qs, 99011)
value, how = Dn.QuestXP(grudge)
assert(value == 1150 and how == "seen", tostring(value) .. " " .. tostring(how))
assert(Dn.QuestXP(second) == nil, "not seen yet")
local sum = Dn.XPSum(qs)
assert(sum.total == 2050 and sum.outside == 1150 and sum.inside == 900 and sum.missing == 1 and not sum.est, "the open quests' XP")
assert(Dn.XPSumText(sum) == "Quest-EP offen: 2050 (draußen 1150, im Dungeon 900), 1 Quest ohne Wert", Dn.XPSumText(sum))
STUB.questsDone[99005] = true
STUB.fire("QUEST_TURNED_IN", 99005, 900, 0)
sum = Dn.XPSum(NS.DungeonQuests("thanes"))
assert(sum.total == 1150 and sum.inside == 0, "a done quest no longer counts")
STUB.questsDone[99005] = nil
STUB.fire("QUEST_TURNED_IN", 99005, 0, 0)
STUB.level = 24
NS.BisBump()
sum = Dn.XPSum(NS.DungeonQuests("thanes"))
assert(sum.est and sum.outside == 925, "scaled values make the sum an estimate: " .. tostring(sum.outside))
assert(has(Dn.XPSumText(sum), "~"), Dn.XPSumText(sum))
assert(Dn.XPSumText({ total = 0, inside = 0, outside = 0, missing = 0 }) == "", "no open quests: no line")
STUB.level = 16
NS.BisBump()

---------------------------------------------------------------------------
-- all quest givers on the map
---------------------------------------------------------------------------
STUB.pinTemplates.AmisiaMapPinTemplate = "AmisiaMapPinMixin"
STUB.place.map = 1436
STUB.fire("PLAYER_LOGIN")
local n = NS.DungeonMarkQuests("thanes")
assert(n == 3 and AmisiaDB.map.quests == "thanes", "three givers: the root's, the thane's (two quests), the hall's: " .. tostring(n))
assert(NS.DungeonMarked() == "thanes")
local places = NS.DungeonMarkPlaces()
local byGiver = {}
for _, p in ipairs(places) do byGiver[p.giver] = p end
assert(byGiver["Root Giver"] and has(byGiver["Root Giver"].quests[1], "Root Quest"), "a chain starts at its first open pre-quest")
assert(byGiver["Thane Giver"] and #byGiver["Thane Giver"].quests == 1, "the grudge's chain starts elsewhere; the second grudge here")
assert(byGiver["Halls Giver"] and byGiver["Halls Giver"].inside, "a giver inside: its point inside (no entrance known)")
local pinList = Map.PinPlaces(1436)
local marks = {}
for _, p in ipairs(pinList) do if p.mark then marks[#marks + 1] = p end end
assert(#marks == 3, "a pin per giver: " .. #marks)
WorldMapFrame:Show()
WorldMapFrame:SetMapID(1436)
Map.PinProvider():RefreshAllData()
local markPin
for _, p in ipairs(STUB.mapPins("AmisiaMapPinTemplate")) do
    if p.entry and p.entry.mark and p.entry.giver == "Root Giver" then markPin = p end
end
assert(markPin and markPin.icon.atlas == "QuestNormal", "the client's quest icon")
local tipLines = {}
local addLine, addDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
GameTooltip.AddLine = function(self, t) tipLines[#tipLines + 1] = plain(t) end
GameTooltip.AddDoubleLine = function(self, a, b) tipLines[#tipLines + 1] = plain(a) .. " | " .. plain(b) end
markPin:OnMouseEnter()
GameTooltip.AddLine, GameTooltip.AddDoubleLine = addLine, addDouble
local tip = table.concat(tipLines, "\n")
assert(tipLines[1] == "Questgeber Root Giver" and has(tip, "Westfall 10, 10") and has(tip, "Root Quest") and has(tip, "Grudge of the Thanes"),
    tip)
markPin:OnMouseLeave()
-- the menu: set the target, remove the marks
local entries = Map.PlaceMenu(markPin.entry)
assert(entries[1][1] == "Ziel setzen" and entries[#entries][1] == "Markierung der Questgeber entfernen", entries[#entries][1])
entries[1][2]()
assert(NS.MapTarget() and NS.MapTarget().label == "Questgeber Root Giver", NS.MapTarget() and NS.MapTarget().label)
NS.MapClearTarget()
-- a pooled pin taken by an item again shows the item's icon
NS.DungeonClearMarks()
assert(AmisiaDB.map.quests == nil and NS.DungeonMarked() == nil and #NS.DungeonMarkPlaces() == 0)
for _, p in ipairs(Map.PinPlaces(1436)) do assert(not p.mark, "cleared") end
-- marks follow the quests: a turned-in quest's giver goes
NS.DungeonMarkQuests("thanes")
STUB.questsDone[99011], STUB.questsDone[99001] = true, true
STUB.fire("QUEST_TURNED_IN", 99011, 0, 0)
local still = {}
for _, p in ipairs(Map.PinPlaces(1436)) do if p.mark then still[p.giver] = true end end
assert(not still["Thane Giver"] and not still["Root Giver"] and still["Halls Giver"], "done quests' givers go")
STUB.questsDone[99011], STUB.questsDone[99001] = nil, nil
STUB.fire("QUEST_TURNED_IN", 99011, 0, 0)
-- no givers with a place: nothing marked, why
local ok, why = NS.DungeonMarkQuests("deadmines")
assert(not ok and why == "Für diesen Dungeon kennt Amisia keine Questgeber mit Ort.", tostring(why))
assert(NS.DungeonMarked() == "thanes", "the old marks stay")
NS.DungeonClearMarks()
-- a saved key of an unknown dungeon is no mark
AmisiaDB.map.quests = "gone"
assert(NS.DungeonMarked() == nil and #NS.DungeonMarkPlaces() == 0)
AmisiaDB.map.quests = nil
WorldMapFrame:Hide()

---------------------------------------------------------------------------
-- the page: the banner, the XP column and line, the mark button, Ctrl-click
---------------------------------------------------------------------------
NS.ShowGear("dungeons")
local f = NS.GearPageFrame()
local B = f.dungeons
for _, row in ipairs(B.list.rows) do if row.item and row.item.key == "thanes" then row:Click() end end
assert(B.chosen == "thanes")
assert(B.art and B.art:IsShown() and B.art.tex.texture == A.D.thanes[1], "the thanes' screen")
assert(B.art.tex.texCoord and #B.art.tex.texCoord == 4, "cropped")
assert(B.art.title:GetText() == "Hall of Thanes", B.art.title:GetText())
assert(has(B.art.info:GetText(), "13-18"), B.art.info:GetText())
-- the build's facts (ns.BIS.DG) name the bosses by NPC id: the one with the gain shows
assert(B.art.model:IsShown() and B.art.model.creature == 261306, "Faldrim, the boss with the helm: " .. tostring(B.art.model.creature))
B.art:SetModelNpc(nil)
assert(not B.art.model:IsShown(), "no NPC id: no model")
B.art:SetModelNpc(261319)
assert(B.art.model:IsShown() and B.art.model.creature == 261319)
-- without the client's model functions nothing shows
local setCreature = B.art.model.SetCreature
B.art.model.SetCreature = nil
B.art:SetModelNpc(261306)
assert(not B.art.model:IsShown())
B.art.model.SetCreature = setCreature
-- hovering a boss row shows that boss, leaving it the default again
NS.Refresh()
local bossRow
for _, row in ipairs(B.detail.rows) do if row.item and row.item.kind == "boss" and row.item.b.npc == 261306 then bossRow = row end end
assert(bossRow, "a boss row with its NPC id")
B.art:SetModelNpc(261319)
bossRow.scripts.OnEnter(bossRow)
assert(B.art.model.creature == 261306, "the hovered boss")
B.art:SetModelNpc(261319)
bossRow.scripts.OnLeave(bossRow)
assert(B.art.model.creature == 261306, "back to the default")
-- the quests part: the XP column and the sum line
B.parts.quests:Click()
local qrow
for _, row in ipairs(B.detail.rows) do if row.item and row.item.qid == 99001 then qrow = row end end
assert(qrow and plain(qrow.xp:GetText()) == "1150", qrow and qrow.xp:GetText())
assert(has(B.hint:GetText(), "Quest-EP offen: 2050"), B.hint:GetText())
-- the mark button
assert(B.mark:GetText() == "Alle auf Karte" and B.mark.enabled ~= false)
B.mark:Click()
assert(NS.DungeonMarked() == "thanes" and B.mark:GetText() == "Karte leeren", B.mark:GetText())
B.mark:Click()
assert(NS.DungeonMarked() == nil and B.mark:GetText() == "Alle auf Karte")
-- Ctrl-click: the dressing room; Shift-click: the chat
B.parts.bosses:Click()
local irow
for _, row in ipairs(B.detail.rows) do if row.item and row.item.id == 501 then irow = row end end
assert(irow, "the helm's row")
local ctrl, dressed = false, nil
_G.IsControlKeyDown = function() return ctrl end
_G.IsModifiedClick = function(what) return (what == "DRESSUP" and ctrl) or (what == "CHATLINK" and IsShiftKeyDown()) end
_G.DressUpLink = function(link) dressed = link; return true end
ctrl = true
irow:Click()
assert(dressed == STUB.items[501].link, "the dressing room gets the link")
ctrl, dressed = false, nil
irow:Click()
assert(dressed == nil, "a plain click opens nothing")
-- the client's own handler takes the click where it shows the item itself
local handled
local oldHandle = HandleModifiedItemClick
_G.HandleModifiedItemClick = function(link) handled = link; return true end
ctrl = true
irow:Click()
assert(handled == STUB.items[501].link and dressed == nil, "the client's handler first")
_G.HandleModifiedItemClick = oldHandle
ctrl = false
assert(has(B.hint:GetText(), "Strg-Klick"), B.hint:GetText())
-- the layout at the main window's size
local Lay = dofile(ADDON_DIR .. "/../tests/layout.lua")(f, 602, 478)
Lay.row("parts", B.header, B.parts.bosses, B.parts.quests, B.way)
