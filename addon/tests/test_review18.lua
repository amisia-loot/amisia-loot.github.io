-- Review of 1.8 (scoring, data, core): crafted gear that needs a profession to be worn, spell haste
-- apart from physical haste on TBC, TBC rules below level 61 too, the German "Alchimie", and
-- extra event handlers that keep running when one of them fails.
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
-- 1. items that need a profession to be worn
---------------------------------------------------------------------------
check("1 data", function()
    assert(REAL and REAL.game == "tbc", "the TBC data is loaded")
    local need = function(id) return table.concat({ Gear.WearProf(REAL.I[id]) }, ",") end
    assert(need(32494) == "202,350", "Destruction Holo-gogs need engineering 350: " .. need(32494))
    assert(need(34356) == "202,375", "Surestrike Goggles v3.0: " .. need(34356))
    assert(need(35749) == "171,375", "an alchemist stone needs alchemy: " .. need(35749))
    assert(need(31080) == "171,325", "the Mercurial Stone: " .. need(31080))
    assert(Gear.WearProf(REAL.I[23824]) == nil, "rocket boots are worn by anyone")
    assert(Gear.WearProf({ "HEAD", 4, 1, 0, 0, 0, 0, 0, 0, 202 }) == 202, "a Forever row names the skill line alone")
    assert(Gear.WearProf({ "HEAD", 4, 1, 0, 0, 0, 0, 0, 0, 0 }) == nil)
end)

-- the generated goggles and a plain helm: without engineering only the helm; with too little skill
-- neither goggles; at 350 both
local function mk(id, name, int, sp)
    STUB.item(id, name, 4)
    local it = STUB.items[id]
    it.equipLoc, it.classID, it.subclassID, it.bind, it.minLevel = "INVTYPE_HEAD", 4, 1, 1, 70
    it.stats = { ITEM_MOD_INTELLECT_SHORT = int, ITEM_MOD_SPELL_POWER_SHORT = sp }
end
check("1 targets", function()
    STUB.class, STUB.level = "MAGE", 70
    mk(32494, "Destruction Holo-gogs", 30, 60)
    mk(900001, "Raid helm", 10, 20)
    NS.GEAR = { game = "tbc", cap = 70, built = "r18-1", S = REAL.S, I = { [32494] = REAL.I[32494], [900001] = { "", 0, 0, 0, 0, 0, 0, 0, 0, 0, 66 } }, Z = {} }
    Gear._reset()
    STUB.skills = { { name = "Berufe", header = true }, { name = "Schneiderei", rank = 375 } }
    STUB.fire("SKILL_LINES_CHANGED")
    local head = NS.BisTargets().HEAD
    assert(#head == 1 and head[1].id == 900001, "no goggles without engineering: " .. tostring(head[1] and head[1].id))
    STUB.skills = { { name = "Ingenieurskunst", rank = 340 } }
    STUB.fire("SKILL_LINES_CHANGED")
    head = NS.BisTargets().HEAD
    assert(#head == 1 and head[1].id == 900001, "engineering 340 is not enough for 350")
    STUB.skills = { { name = "Ingenieurskunst", rank = 350 } }
    STUB.fire("SKILL_LINES_CHANGED")
    head = NS.BisTargets().HEAD
    assert(head[1] and head[1].id == 32494, "an engineer at 350 wears them")
end)

-- the client's requirement line fills field 10 of a crafted row the data left at 0
check("1 tooltip", function()
    _G.ITEM_MIN_SKILL = "Benötigt %s (%d)"
    _G.ITEM_REQ_SKILL = "Benötigt %s"
    local r = Gear.ReadWearProf({ { leftText = "Hirnschalenbrille" }, { leftText = "|cffff2020Benötigt Ingenieurskunst (375)|r" } })
    assert(r and r[1] == 202 and r[2] == 375, "German line with rank")
    r = Gear.ReadWearProf({ { leftText = "Benötigt Alchimie" } })
    assert(r and r[1] == 171 and r[2] == 0, "a line without rank")
    assert(Gear.ReadWearProf({ { leftText = "Benötigt Stufe 70" } }) == nil, "a level line is no profession")
    _G.ITEM_MIN_SKILL, _G.ITEM_REQ_SKILL = "Requires %s (%d)", "Requires %s"
    r = Gear.ReadWearProf({ { leftText = "Requires Engineering (350)" } })
    assert(r and r[1] == 202 and r[2] == 350, "English")

    _G.ITEM_MIN_SKILL = "Benötigt %s (%d)"
    local TIP = { [900010] = { { leftText = "Brille" }, { leftText = "Benötigt Ingenieurskunst (350)" } },
        [900011] = { { leftText = "Helm" }, { leftText = "Benötigt Ingenieurskunst (350)" } } }
    local asked = {}
    _G.C_TooltipInfo = { GetItemByID = function(id) asked[#asked + 1] = id; return TIP[id] and { lines = TIP[id] } end }
    mk(900010, "Brille", 30, 60)
    mk(900011, "Helm", 30, 60)
    local craft = #REAL.S + 1
    local S = {}
    for i, rec in ipairs(REAL.S) do S[i] = rec end
    S[craft] = { "C", "engineering", 350 }
    NS.GEAR = { game = "tbc", cap = 70, built = "r18-2", S = S, Z = {}, I = {
        [900010] = { "", 0, 0, 0, 0, 0, 0, 0, 0, 0, craft },
        [900011] = { "", 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 } } }
    Gear._reset()
    local row = Gear.FillRow(900010)
    assert(row[1] == "HEAD", "the row is filled")
    assert(type(row[10]) == "table" and row[10][1] == 202 and row[10][2] == 350, "the requirement from the tooltip: " .. tostring(row[10]))
    row = Gear.FillRow(900011)
    assert(row[10] == 0, "a dropped item is not read for a profession")
    assert(#asked == 1 and asked[1] == 900010, "only crafted rows ask the tooltip")
    STUB.skills = { { name = "Schneiderei", rank = 375 } }
    STUB.fire("SKILL_LINES_CHANGED")
    local head = NS.BisTargets().HEAD
    assert(#head == 1 and head[1].id == 900011, "the filled row keeps non-engineers away")
    _G.C_TooltipInfo = nil
    STUB.skills = nil
    STUB.fire("SKILL_LINES_CHANGED")
end)
NS.GEAR = REAL
Gear._reset()

---------------------------------------------------------------------------
-- 2. spell haste is its own stat on TBC; Forever keeps one haste
---------------------------------------------------------------------------
check("2 spell haste", function()
    assert(Gear.STAT.ITEM_MOD_HASTE_SPELL_RATING_SHORT == "SHASTE" and Gear.STAT.ITEM_MOD_HASTE_SPELL_RATING == "SHASTE")
    assert(Gear.STAT.ITEM_MOD_HASTE_MELEE_RATING_SHORT == "HASTE" and Gear.STAT.ITEM_MOD_HASTE_RATING_SHORT == "HASTE")
    local W = NS.GEAR_WEIGHTS.specs
    local rogue, mage, priest = W.ROGUE[1].all, W.MAGE[2].all, W.PRIEST[1].all
    assert(near(Gear.Score({ SHASTE = 20 }, rogue, 70), 0), "spell haste is nothing to a rogue")
    assert(Gear.Score({ HASTE = 20 }, rogue, 70) > 0, "physical haste is")
    assert(near(Gear.Score({ HASTE = 20 }, mage, 70), 0), "physical haste is nothing to a mage")
    assert(near(Gear.Score({ SHASTE = 15.769230769 }, mage, 70), 13, 1e-4), "one percent of spell haste at the mage's weight")
    assert(Gear.Score({ SHASTE = 20 }, priest, 70) > 0, "healers value spell haste")
    for cls, specs in pairs(W) do
        for _, sp in ipairs(specs) do
            local caster = sp.all.unit == "SP" or sp.all.unit == "HEAL"
            assert(not (caster and sp.all.HASTE), cls .. " " .. sp.key .. ": a caster weighs spell haste")
        end
    end
    local parts = Gear.ScoreParts({ SHASTE = 20 }, mage, 70)
    assert(parts[1] and parts[1].label == "Zaubertempowertung", "its own label")
    -- Forever: hit, crit and haste work for spells and weapons, spell haste counts as haste
    NS.GEAR = { built = "f", S = {}, I = {} }
    local w = { HASTE = 4, SCRIT = 6 }
    assert(near(Gear.Score({ SHASTE = 10 }, w, 60), Gear.Score({ HASTE = 10 }, w, 60)), "Forever: one haste")
    assert(near(Gear.Score({ SHASTE = 10 }, { SCRIT = 10 }, 60), Gear.Score({ HASTE = 10 }, { SCRIT = 10 }, 60)))
    NS.GEAR = REAL
end)

---------------------------------------------------------------------------
-- 3. TBC rules come from the game, not from the level
---------------------------------------------------------------------------
check("3 TBC below 61", function()
    local mage = NS.GEAR_WEIGHTS.specs.MAGE[2].all
    assert(Gear.Game() == "tbc")
    assert(near(Gear.Score({ HIT = 10 }, mage, 58), 0), "plain hit rating is physical on TBC at 58 too")
    assert(near(Gear.Score({ CRIT = 14 }, mage, 58), 0), "and plain crit rating")
    assert(Gear.Score({ SHIT = 10 }, mage, 58) > 0 and Gear.Score({ SCRIT = 14 }, mage, 58) > 0, "spell ratings count")
    NS.GEAR = { built = "f", S = {}, I = {} }
    assert(Gear.Score({ HIT = 10 }, mage, 58) > 0, "Forever's hit works for spells")
    NS.GEAR = nil
    assert(near(Gear.Score({ HIT = 10 }, mage, 70), 0), "above 60 is TBC even without data")
    NS.GEAR = REAL
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
