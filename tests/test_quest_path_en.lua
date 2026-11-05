--[[locale enUS]]
-- The quest path (F-135) on an English client: the list's "path" column, the view's buttons, labels,
-- marks and the next step, the command, all from Locales/enUS_gear.lua.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local realQuests = NS.DUNGEON_QUESTS

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
NS.Map._reset()
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 500 } },
    Q = {
        [500] = { "Final Quest", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", { 501 }, { 502, 503, 504 }, "deadmines", nil, nil,
                  nil, nil, nil, 0, 0, nil, nil, "Kill Van Cleef." },
        [501] = { "Root", 10, 12, "A", 0, "O", "Root Giver", "1436:1000:1000", nil, nil, nil },
        [502] = { "Choice A", 12, 14, "A", 0, "O", "Choice Giver", "1436:2000:3000", nil, nil, nil },
        [503] = { "Choice B", 12, 14, "A", 0, "O", "Other Giver", nil, nil, nil, nil },
        [504] = { "A Hint", 10, 10, "", 0, "O", "Herald", "1436:6000:6000", nil, nil, nil, nil, nil, true },
    },
}
NS.GEAR = { built = "test-path-en", Z = {}, I = {}, S = {} }
NS.Gear._reset()
STUB.questsDone[501] = true
NS.BisBump()
AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
AmisiaDB.settings.bis.dpart = "quests"
NS.ShowDungeon("deadmines")
local B = NS.DungeonsPageFrame()
local row
for _, r in ipairs(B.detail.rows) do if r.item and r.item.qid == 500 then row = r end end
assert(plain(row.way:GetText()) == "Path 1/3", plain(row.way:GetText()))
row:Click()
local V = B.pathView
assert(V.back:GetText() == "< Back to the quests" and V.map:GetText() == "Next step on the map", V.back:GetText())
assert(has(V.info:GetText(), "Dungeon quest · The Deadmines · level ") and has(V.info:GetText(), " · Path: 1 of 3 steps done"), V.info:GetText())
assert(plain(V.nextLine:GetText()) == "Next step: 2. Choice A at Choice Giver, Westfall 20, 30", plain(V.nextLine:GetText()))
local c2, c3, c4 = V.cards[2], V.cards[3], V.cards[4]
assert(c2.lines[1].label:GetText() == "Accept:" and c2.lines[2].label:GetText() == "Hand in:" and c2.lines[2].value:GetText() == "not known yet")
assert(c2.lines[3].label:GetText() == "Requires:" and c2.step:GetText() == "Step 2 of 3", c2.step:GetText())
assert(has(plain(c2.lines[4].value:GetText()), "one of them is enough · also possible: Choice B"), c2.lines[4].value:GetText())
assert(c3.step:GetText() == "optional")
assert(c2.after:GetText() == "then")
local goal
for _, ln in ipairs(c4.lines) do if ln.label:GetText() == "Objective:" and ln.label:IsShown() then goal = ln.value:GetText() end end
assert(goal == "Kill Van Cleef.", tostring(goal))
STUB.messages = {}
NS.Dispatch("dungeon quests deadmines")
local said = table.concat(STUB.messages, "\n")
assert(has(said, "  Next step: 2. Choice A at Choice Giver, Westfall 20, 30") and has(said, " · path 1/3"), said)

STUB.questsDone[501] = nil
NS.DUNGEON_QUESTS = realQuests
NS.BisBump()
