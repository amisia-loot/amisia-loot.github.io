-- Review of 1.8 (scoring, data, core): gear that needs a profession to be worn, one haste for
-- weapons and spells, the German "Alchimie", and extra event handlers that keep running when one
-- of them fails.
local failed = {}
local function check(label, fn)
    local ok, err = pcall(fn)
    if not ok then failed[#failed + 1] = label .. ": " .. tostring(err) end
end
local function near(a, b, eps) return math.abs(a - b) < (eps or 1e-6) end
local Gear = NS.Gear
local REAL = NS.GEAR
local REAL_WEIGHTS = NS.GEAR_WEIGHTS

---------------------------------------------------------------------------
-- 1. items that need a profession to be worn (field 10: the skill line, any rank)
---------------------------------------------------------------------------
check("1 data", function()
    assert(Gear.WearProf({ "HEAD", 4, 1, 0, 0, 0, 0, 0, 0, 202 }) == 202, "a row names the skill line alone")
    assert(select(2, Gear.WearProf({ "HEAD", 4, 1, 0, 0, 0, 0, 0, 0, 202 })) == 0, "any rank")
    assert(Gear.WearProf({ "HEAD", 4, 1, 0, 0, 0, 0, 0, 0, 0 }) == nil)
    assert(Gear.WearProf({ "HEAD", 4, 1, 0, 0, 0, 0, 0, 0, { 202, 350 } }) == nil, "no table form any more")
end)

-- engineering goggles and a plain helm: without engineering only the helm; with engineering both
local function mk(id, name, int, sp)
    STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.bind, it.minLevel = "INVTYPE_HEAD", 4, 1, 1, 60
    it.stats = { ITEM_MOD_INTELLECT_SHORT = int, ITEM_MOD_SPELL_POWER_SHORT = sp }
end
check("1 targets", function()
    STUB.class, STUB.level = "MAGE", 60
    mk(900002, "Ingenieursbrille", 30, 60)
    mk(900001, "Raidhelm", 10, 20)
    local S = { { "Q", "Eine Quest", 60, 60, "", 1429, 1, 0 } }
    NS.GEAR = { built = "r18-1", S = S, Z = {}, I = {
        [900002] = { "HEAD", 4, 1, 60, 4, 1, 60, 0, 0, 202, 1 },
        [900001] = { "HEAD", 4, 1, 60, 4, 1, 60, 0, 0, 0, 1 } } }
    Gear._reset()
    STUB.skills = { { name = "Berufe", header = true }, { name = "Schneiderei", rank = 300, id = 197 } }
    STUB.fire("SKILL_LINES_CHANGED")
    local head = NS.BisTargets().HEAD
    assert(#head == 1 and head[1].id == 900001, "no goggles without engineering: " .. tostring(head[1] and head[1].id))
    STUB.skills = { { name = "Ingenieurskunst", rank = 1, id = 202 } }
    STUB.fire("SKILL_LINES_CHANGED")
    head = NS.BisTargets().HEAD
    assert(head[1] and head[1].id == 900002, "an engineer wears them")
    STUB.skills = nil
    STUB.fire("SKILL_LINES_CHANGED")
end)
NS.GEAR = REAL
Gear._reset()

---------------------------------------------------------------------------
-- 2. spell haste reads as its own stat and counts as haste: one haste for weapons and spells
---------------------------------------------------------------------------
check("2 spell haste", function()
    assert(Gear.STAT.ITEM_MOD_HASTE_SPELL_RATING_SHORT == "SHASTE" and Gear.STAT.ITEM_MOD_HASTE_SPELL_RATING == "SHASTE")
    assert(Gear.STAT.ITEM_MOD_HASTE_MELEE_RATING_SHORT == "HASTE" and Gear.STAT.ITEM_MOD_HASTE_RATING_SHORT == "HASTE")
    local w = { HASTE = 4, SCRIT = 6 }
    assert(near(Gear.Score({ SHASTE = 10 }, w, 60), Gear.Score({ HASTE = 10 }, w, 60)), "one haste")
    assert(near(Gear.Score({ SHASTE = 10 }, { SCRIT = 10 }, 60), Gear.Score({ HASTE = 10 }, { SCRIT = 10 }, 60)))
end)

---------------------------------------------------------------------------
-- 3. hit and crit work for spells at every level; levels above 60 count as 60
---------------------------------------------------------------------------
check("3 hit for spells", function()
    local caster = { SHIT = 10, SCRIT = 6 }
    assert(Gear.Score({ HIT = 10 }, caster, 58) > 0, "hit rating works for spells")
    assert(Gear.Score({ CRIT = 14 }, caster, 58) > 0, "and crit rating")
    assert(near(Gear.Score({ HIT = 10 }, caster, 70), Gear.Score({ HIT = 10 }, caster, 60)), "no curve above 60")
    assert(near(Gear.RatingPerPoint("HIT", 70), Gear.RatingPerPoint("HIT", 60)))
end)

---------------------------------------------------------------------------
-- 4. German profession names
---------------------------------------------------------------------------
check("4 Alchimie", function()
    assert(Gear.PROFESSIONS.alchemy == "Alchimie", Gear.PROFESSIONS.alchemy)
    STUB.skills = { { name = "Berufe", header = true }, { name = "Alchimie", rank = 375 }, { name = "Juwelierskunst", rank = 360 },
        { name = "Ingenieurskunst", rank = 350 }, { name = "Lederverarbeitung", rank = 300 }, { name = "Schmiedekunst", rank = 200 },
        { name = "Verzauberkunst", rank = 100 }, { name = "Schneiderei", rank = 50 } }
    STUB.fire("SKILL_LINES_CHANGED")
    local s = NS.BisSkills()
    assert(s.alchemy == 375 and s[171] == 375, "Alchimie: " .. tostring(s.alchemy))
    assert(s.jewelcrafting == 360 and s.engineering == 350 and s.leatherworking == 300 and s.blacksmithing == 200
        and s.enchanting == 100 and s.tailoring == 50, "every German name")
    assert(Gear.SourceOk({ "C", "alchemy", 375 }, { sources = { C = true }, prof = "mine", skills = s }, { "", 0, 0, 0, 0, 1 }),
        "a bind on pickup alchemy item counts with Alchimie 375")
    STUB.skills = nil
    STUB.fire("SKILL_LINES_CHANGED")
end)

---------------------------------------------------------------------------
-- 7. one failing extra event handler does not stop the others
---------------------------------------------------------------------------
check("7 handlers", function()
    local ran, reported = {}, {}
    NS.OnEvent("AMISIA_TEST_EVENT", function(a) ran[#ran + 1] = "first " .. tostring(a) end)
    NS.OnEvent("AMISIA_TEST_EVENT", function() error("boom") end)
    NS.OnEvent("AMISIA_TEST_EVENT", function(a) ran[#ran + 1] = "third " .. tostring(a) end)
    local frame
    for f in pairs(STUB.frames) do
        if f.scripts.OnEvent and f.events.AMISIA_TEST_EVENT then frame = f end
    end
    assert(frame, "the core's event frame")
    local saved = _G.geterrorhandler
    _G.geterrorhandler = function() return function(e) reported[#reported + 1] = tostring(e) end end
    local ok, err = pcall(frame.scripts.OnEvent, frame, "AMISIA_TEST_EVENT", 7)
    _G.geterrorhandler = saved
    assert(ok, "the event frame survives: " .. tostring(err))
    assert(table.concat(ran, ",") == "first 7,third 7", "every handler ran: " .. table.concat(ran, ","))
    assert(#reported == 1 and reported[1]:find("boom", 1, true), "the error is reported: " .. table.concat(reported, ";"))
end)

NS.GEAR, NS.GEAR_WEIGHTS = REAL, REAL_WEIGHTS
if #failed > 0 then error(#failed .. " failed:\n" .. table.concat(failed, "\n"), 0) end
