-- Review 27: pre-quests "any one of" (ATT's sourceQuestNumRequired, the flag N<n>), pre-quests of
-- another faction, race or class and breadcrumbs no longer lock a quest; a breadcrumb whose
-- follow-up is taken or done is locked; a quest is no pre-quest of itself. Every check runs, the
-- failures are listed together.
local function kinds(info)
    local out = {}
    for _, r in ipairs(info.reasons) do out[#out + 1] = r.kind end
    return table.concat(out, ",")
end
local function text(info) return info.reasons[1] and info.reasons[1].text or "" end
local REAL_QUESTS = NS.QUEST_DATA

local failures = {}
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
    STUB.questsDone, STUB.questsActive = {}, {}
    STUB.level, STUB.faction, STUB.class = 60, "Alliance", "WARRIOR"
    _G.UnitRace = function() return "Mensch", "Human", 1 end
    NS.QUEST_DATA = REAL_QUESTS
    NS.Quests._reset()
end

local function alliance(level)
    STUB.level, STUB.faction, STUB.class = level, "Alliance", "WARRIOR"
    _G.UnitRace = function() return "Mensch", "Human", 1 end
    NS.Quests._reset()
end

---------------------------------------------------------------------------
-- the shipped data
---------------------------------------------------------------------------
check("1 shipped: one of two faction welcomes", function()
    alliance(10)
    STUB.questsDone[93461] = true
    local s = NS.QuestState(93319)
    assert(s and s.status == "open", "Pilfered Windstones: " .. tostring(s and s.status) .. " " .. (s and text(s) or ""))
    STUB.questsDone[93461] = nil
    NS.Quests._reset()
    s = NS.QuestState(93319)
    assert(s.status == "locked" and kinds(s) == "pre", "without the Alliance welcome it stays locked: " .. kinds(s))
end)

check("1 shipped: a breadcrumb is no pre-quest", function()
    alliance(20)
    local s = NS.QuestState(5)
    assert(s.status == "open", "Jitters' Growling Gut without Raven Hill: " .. text(s))
end)

check("1 shipped: another race's variant is no pre-quest", function()
    STUB.faction, STUB.class, STUB.level = "Horde", "SHAMAN", 20
    _G.UnitRace = function() return "Orc", "Orc", 2 end
    STUB.questsDone[1528] = true
    NS.Quests._reset()
    local s = NS.QuestState(1530)
    assert(s.status == "open", "Call of Water (2/9) for an orc: " .. text(s))
end)

check("2 shipped: the breadcrumb after its follow-up", function()
    alliance(25)
    STUB.questsDone[5] = true
    NS.Quests._reset()
    local s = NS.QuestState(163)
    assert(s.status == "locked" and kinds(s) == "follow", "Raven Hill after Jitters' Growling Gut: " .. s.status .. " " .. kinds(s))
end)

check("3 shipped: no quest waits for itself", function()
    STUB.faction, STUB.level = "Horde", 60
    _G.UnitRace = function() return "Orc", "Orc", 2 end
    NS.Quests._reset()
    for _, q in ipairs({ 4112, 3522 }) do
        local s = NS.QuestState(q)
        local rec = NS.Quests.Record(q)
        for _, p in ipairs(rec.pre or {}) do assert(p ~= q, q .. " lists itself") end
        for _, r in ipairs(s.reasons) do
            assert(not (r.kind == "pre" and r.text:find(NS.Quests.Title(q), 1, true)), q .. " waits for itself: " .. r.text)
        end
    end
end)

---------------------------------------------------------------------------
-- a small data set
---------------------------------------------------------------------------
local FIXTURE = { built = "2026-10-07", source = "test", count = 16, Z = { [1429] = "Elwynn Forest" }, N = {},
    Q = {
        [10] = "1429;Horde Welcome;1;H;0;0;0;0;;O;;;;",
        [11] = "1429;Alliance Welcome;1;A;0;0;0;0;;O;;;;",
        [12] = "1429;Either Welcome;1;;0;0;0;0;;O;10,11;;;N1",
        [13] = "1429;After Both Welcomes;1;;0;0;0;0;;O;10,11;;;",
        [20] = "1429;Go See Bob;1;A;0;0;0;0;;O;;;;B",
        [21] = "1429;Bob's Task;1;A;0;0;0;0;;O;20;;;",
        [30] = "1429;Self Pre;1;A;0;0;0;0;;O;30;;;",
        [40] = "1429;Pick One A;1;;0;0;0;0;;O;;;;",
        [41] = "1429;Pick One B;1;;0;0;0;0;;O;;;;",
        [42] = "1429;After One;1;;0;0;0;0;;O;40,41;;;N1",
        [50] = "1429;Gnome Pre;1;A;0;64;0;0;;O;;;;",
        [51] = "1429;Human Pre;1;A;0;1;0;0;;O;;;;",
        [52] = "1429;After the Race Pre;1;A;0;0;0;0;;O;50,51;;;",
        [60] = "1429;Mage Pre;1;;128;0;0;0;;O;;;;",
        [61] = "1429;Warrior Pre;1;;1;0;0;0;;O;;;;",
        [62] = "1429;After the Class Pre;1;;0;0;0;0;;O;60,61;;;",
    },
}
local function fixture()
    alliance(10)
    NS.QUEST_DATA = FIXTURE
    NS.Quests._reset()
end
local function st(q) return NS.QuestState(q) end
local function done(q)
    STUB.questsDone[q] = true
    STUB.fire("QUEST_TURNED_IN", q)
end

check("1 any one of the pre-quests", function()
    fixture()
    assert(st(42).status == "locked" and text(st(42)) == "Vorquest fehlt: Pick One A (oder 1 weitere)", text(st(42)))
    done(41)
    assert(st(42).status == "open", "one of the two is enough: " .. text(st(42)))
    assert(NS.Quests.Record(42).need == 1, "the record says how many")
end)

check("1 any one of: the other faction's member does not count", function()
    fixture()
    assert(st(12).status == "locked" and text(st(12)) == "Vorquest fehlt: Alliance Welcome", text(st(12)))
    done(11)
    assert(st(12).status == "open", text(st(12)))
end)

check("1 all of: another faction's, race's or class's pre-quest falls away", function()
    fixture()
    assert(text(st(13)) == "Vorquest fehlt: Alliance Welcome", "the Horde welcome is not asked for: " .. text(st(13)))
    assert(text(st(52)) == "Vorquest fehlt: Human Pre", text(st(52)))
    assert(text(st(62)) == "Vorquest fehlt: Warrior Pre", text(st(62)))
    done(11); done(51); done(61)
    assert(st(13).status == "open" and st(52).status == "open" and st(62).status == "open",
        text(st(13)) .. "/" .. text(st(52)) .. "/" .. text(st(62)))
end)

check("1 a breadcrumb is no pre-quest", function()
    fixture()
    assert(st(21).status == "open", "Bob's Task without the breadcrumb: " .. text(st(21)))
end)

check("2 the breadcrumb after its follow-up", function()
    fixture()
    assert(st(20).status == "open")
    STUB.questsActive[21] = true
    STUB.fire("QUEST_ACCEPTED", 21)
    assert(st(20).status == "locked" and kinds(st(20)) == "follow"
        and text(st(20)) == "Folgequest schon angenommen: Bob's Task", text(st(20)))
    STUB.questsActive[21] = nil
    done(21)
    assert(st(20).status == "locked" and text(st(20)) == "Folgequest schon erledigt: Bob's Task", text(st(20)))
    done(20)
    assert(st(20).status == "done", "done stays done")
end)

check("3 a quest is no pre-quest of itself", function()
    fixture()
    assert(st(30).status == "open", text(st(30)))
    assert(#NS.Quests.Next(30) == 0, "nor its own follow-up")
    assert(NS.QuestChain(30) == nil, "no chain of one")
end)

if #failures > 0 then error(table.concat(failures, " || "), 0) end
