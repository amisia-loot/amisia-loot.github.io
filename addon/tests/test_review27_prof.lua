-- Review 27, professions and searches: a client without GetAllRecipeIDs reads the filtered list
-- (the window's search) into the known recipes without losing the others; Camelot's GetProfessions
-- returns seven values (the own professions and the self-test read them all); the page puts the
-- saved search back into its box; the searches fold the German capitals (Ä, Ö, Ü) like lower().
-- Every check runs, the failures are listed together.
local Pr = NS.Prof
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")

local failures = {}
local function check(name, fn)
    local ok, err = pcall(fn)
    if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
end

local function window(recipes, learned)
    local T = { recipes = recipes, learned = learned }
    C_TradeSkillUI = {
        IsTradeSkillLinked = function() return false end, IsTradeSkillGuild = function() return false end,
        IsNPCCrafting = function() return false end,
        GetBaseProfessionInfo = function() return { professionID = 164, skillLevel = 45, maxSkillLevel = 150 } end,
        GetFilteredRecipeIDs = function() return T.recipes end,
        GetRecipeInfo = function(id) return { recipeID = id, learned = T.learned[id] == true } end,
        GetRecipeSchematic = function() return nil end,
    }
    return T
end

check("5 a search in the window keeps the known recipes", function()
    local T = window({ 2663, 3321, 1252229 }, { [2663] = true, [1252229] = true })
    STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
    assert(Pr.Known(1252229, 164) == true and Pr.Known(2663, 164) == true, "read once")
    T.recipes = { 2663 }   -- the user typed a search into the profession window
    STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
    assert(Pr.Known(1252229, 164) == true, "still known after the search")
    assert(Pr.Known(2663, 164) == true and Pr.Known(3321, 164) == false)
    T.recipes = { 3321 }   -- a search that shows only an unknown recipe
    STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
    assert(Pr.Known(1252229, 164) == true and Pr.Known(2663, 164) == true, "an unknown-only list wipes nothing")
    T.learned[3321] = true
    STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
    assert(Pr.Known(3321, 164) == true, "a newly learned one joins")
end)

check("5 the full list replaces", function()
    window({}, {})
    C_TradeSkillUI.GetAllRecipeIDs = function() return { 2663, 3321 } end
    C_TradeSkillUI.GetRecipeInfo = function(id) return { recipeID = id, learned = id == 3321 } end
    STUB.fire("TRADE_SKILL_LIST_UPDATE"); STUB.tick(1)
    assert(Pr.Known(3321, 164) == true and Pr.Known(2663, 164) == false and Pr.Known(1252229, 164) == false,
        "with every recipe the window's word is final")
end)

check("6 seven values of GetProfessions", function()
    -- Camelot: prim1, prim2, sec1..sec5 (Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua)
    GetProfessions = function() return 1, 2, 3, 4, 5, 6, 7 end
    local SK = { 164, 186, 129, 356, 185, 40, 633 }
    GetProfessionInfo = function(i) return "P" .. i, 0, 10, 300, 0, 0, SK[i] end
    local out = {}
    for _, p in ipairs(Pr.Own()) do if not p.saved then out[#out + 1] = p.skill end end
    assert(table.concat(out, ",") == "164,186,129,356,185,40,633", table.concat(out, ","))
    local R = NS.SelfTest.Run()
    local line = R.text:match("Eigene Berufe: ([^\n]*)") or ""
    assert(has(line, "\"P6\" (40)") and has(line, "\"P7\" (633)"), line)
end)

check("7 the saved search comes back into the box", function()
    GetProfessions = function() return 1 end
    GetProfessionInfo = function() return "Schmiedekunst", 136241, 45, 150, 3, 0, 164 end
    AmisiaDB.settings.professions = { search = "kupferarm", view = 164 }   -- what a /reload brings back
    NS.Dispatch("berufe schmied")
    local f = NS.ProfessionsPageFrame()
    NS.Refresh()
    assert(f.search:GetText() == "kupferarm", "box: [" .. tostring(f.search:GetText()) .. "]")
    assert(#f.list.items == 1, "the list follows the same search: " .. #f.list.items)
end)

check("German capitals in the searches", function()
    assert(NS.Fold("ÄRGER über Öl und ÜBEL") == "ärger über öl und übel", NS.Fold("ÄRGER über Öl und ÜBEL"))
    C_Spell.GetSpellName = function(id) return id == 2663 and "Überzogene Kupferarmschienen" or nil end
    Pr._reset()
    local n = #Pr.List(164, { search = "überzogene" })
    assert(n == 1, "lower case finds the capital: " .. n)
    n = #Pr.List(164, { search = "ÜBERZOGENE" })
    assert(n == 1, "and the other way: " .. n)
    NS.QUEST_DATA = { built = "x", source = "x", count = 1, Z = {}, N = {}, Q = { [1] = "0;Ärger im Wald;1;;0;0;0;0;;;;;;" } }
    NS.Quests._reset()
    local rows = NS.QuestList({ show = { open = true, active = true, locked = true, done = true }, search = "ärger" })
    local q = 0
    for _, r in ipairs(rows) do if r.kind == "quest" then q = q + 1 end end
    assert(q == 1, "quest search folds too: " .. q)
end)

if #failures > 0 then error(table.concat(failures, " || "), 0) end
