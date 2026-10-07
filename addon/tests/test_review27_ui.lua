--[[preload
AmisiaDB = { settings = { quests = { enabled = true, search = "Echo", zone = 1429, mine = false,
    show = { open = true, active = true, locked = true, done = false }, expanded = { [21] = true } } } }
]]
-- Review 27, pages: the quest page's state lives in settings.questsPage, apart from the switch
-- quests.enabled (moved once from settings.quests); the quest page writes no global _; the talent
-- arrows are pooled per tree (a class switch makes no new textures); the quest XP of the log is
-- kept only while collect.quests is on. Every check runs, the failures are listed together.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

local failures = {}
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
end

STUB.class, STUB.level, STUB.faction = "WARRIOR", 12, "Alliance"
_G.UnitRace = function() return "Mensch", "Human", 1 end
STUB.maps[1429] = { name = "Wald von Elwynn", mapType = 3 }
NS.QUEST_DATA = { built = "2026-10-07", source = "test", count = 3, Z = {}, N = { [197] = "Marshal McBride;1429:4810:4180" },
    Q = {
        [7] = "1429;Kobold Camp Cleanup;0;A;0;0;0;197;;O;;;;",
        [15] = "1429;Investigate Echo Ridge;0;A;0;0;0;197;;O;7;;;",
        [21] = "1429;Skirmish at Echo Ridge;5;A;0;0;0;197;;O;15;;5001;",
    },
}
NS.Quests._reset()

check("the page state moves out of the switch's section", function()
    local s = AmisiaDB.settings
    NS.ShowPage("quests")   -- (the command without a word would clear the search)
    local f = assert(NS.QuestPageFrame())
    NS.Refresh()
    local p = s.questsPage
    assert(type(p) == "table" and p.search == "Echo" and p.zone == 1429 and p.mine == false and p.show.locked
        and p.expanded[21], "moved")
    assert(s.quests.enabled == true and s.quests.search == nil and s.quests.show == nil and s.quests.expanded == nil,
        "the switch's section keeps the switch only")
    assert(f.search:GetText() == "Echo", tostring(f.search:GetText()))
    NS.Dispatch("quests Kobold")
    assert(p.search == "Kobold" and s.quests.search == nil, "the command writes the page state")
    NS.Set("quests.enabled", false)
    NS.Set("quests.enabled", true)
    assert(s.questsPage.search == "Kobold", "the switch leaves the page state alone")
end)

check("8 no global _", function()
    rawset(_G, "_", nil)
    STUB.item(5001, "Echohelm", 2)
    AmisiaDB.settings.questsPage.search = ""
    AmisiaDB.settings.questsPage.expanded[21] = true
    NS.Dispatch("quests")
    NS.Refresh()
    local f = NS.QuestPageFrame()
    local seen = false
    for _, r in ipairs(f.list.rows) do
        if r:IsShown() and has(r.title:GetText(), "Echohelm") then seen = true end
    end
    assert(seen, "the reward row was drawn")
    assert(rawget(_G, "_") == nil, "global _ written: " .. tostring(rawget(_G, "_")))
end)

check("9 talent arrows pooled", function()
    NS.ShowTalents()
    local f = NS.TalentsPageFrame()
    local n = 0
    for t = 1, 3 do
        local tree = f.trees[t]
        local orig = tree.CreateTexture
        tree.CreateTexture = function(...) n = n + 1 return orig(...) end
    end
    for _ = 1, 10 do
        for _, cls in ipairs({ "MAGE", "WARLOCK" }) do
            NS.Talents.State().class = cls; f.plan = nil; NS.Refresh()
        end
    end
    assert(n <= 30, "textures made by 20 class switches: " .. n)
    -- the arrows shown are the current class's, each with its line
    local shown = 0
    for _, a in pairs(f.arrows) do
        assert(a.line:IsShown(), "a pooled arrow shows its line")
        shown = shown + 1
    end
    assert(shown > 0, "the warlock has arrows")
end)

check("QuestXP keeps nothing with collect.quests off", function()
    STUB.questsActive[4242] = true
    _G.GetQuestLogRewardXP = function(id) return id == 4242 and 650 or 0 end
    NS.Set("collect.quests", false)
    local xp, how = NS.QuestXP.For(4242)
    assert(xp == 650 and how == "log", "the log's value is still shown")
    assert(NS.QuestXP.Get(4242) == nil, "but not kept")
    NS.Set("collect.quests", true)
    NS.QuestXP.For(4242)
    assert(NS.QuestXP.Get(4242) == 650, "kept with the switch on")
end)

if #failures > 0 then error(table.concat(failures, " || "), 0) end
