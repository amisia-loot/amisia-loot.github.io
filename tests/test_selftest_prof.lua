-- /amisia selbsttest, section "Berufe": the functions of the professions page, the own professions
-- (one the data lacks is a problem), a recipe's reagents without the window, the client's recipe
-- name and camp description, the Merchant's Favor, and the saved state with IsPlayerSpell's answer.
local ST = NS.SelfTest
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
dofile(ADDON_DIR .. "/../tests/prof_fixture.lua")

local function section(text)
    return text:match("== Berufe ==\n(.-)\n\n") or text:match("== Berufe ==\n(.*)$")
end

-- without the functions: they are named, nothing raises
local R = ST.Run()
local s = section(R.text)
assert(has(s, "FEHLT  Funktionen: ") and has(s, "C_TradeSkillUI.GetRecipeSchematic"), s)
assert(has(s, "Gespeicherter Stand: keiner"), s)

GetProfessions = function() return 1, 2 end
GetProfessionInfo = function(i)
    if i == 1 then return "Schmiedekunst", 1, 45, 150, 3, 0, 164 end
    return "Juwelierskunst", 1, 5, 75, 3, 0, 755
end
C_Spell.GetSpellDescription = function(id) return id == 1307392 and "Errichtet ein Schleifrad." or "" end
SPELL_NAMES = { [2663] = "Kupferarmschienen" }
C_Spell.GetSpellName = function(id) return SPELL_NAMES[id] end
C_CurrencyInfo = { GetCurrencyInfo = function(id) return id == 3402 and { name = "Händlergunst", quantity = 75 } or nil end }
IsPlayerSpell = function(id) return id == 2663 end
C_TradeSkillUI = {
    IsTradeSkillLinked = function() return false end, IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return false end,
    GetBaseProfessionInfo = function() return { professionID = 164, skillLevel = 45, maxSkillLevel = 150 } end,
    GetAllRecipeIDs = function() return { 2663 } end,
    GetRecipeInfo = function(id) return { recipeID = id, learned = true } end,
    GetRecipeSchematic = function(id)
        return { name = "Kupferarmschienen", reagentSlotSchematics = { { reagents = { { itemID = 2840 } }, quantityRequired = 2 } } }
    end,
}
STUB.fire("TRADE_SKILL_SHOW"); STUB.tick(1)
R = ST.Run()
s = section(R.text)
assert(has(s, "OK     Funktionen: alle 11 vorhanden"), s)
assert(has(s, "GetAllRecipeIDs da, GetFilteredRecipeIDs fehlt, IsPlayerSpell da"), s)
assert(has(s, 'FEHLT  Eigene Berufe: "Schmiedekunst" (164) 45/150, "Juwelierskunst" (755) 5/75; nicht in den Daten: 755'), s)
assert(has(s, 'OK     Reagenzien ohne Fenster: "Kupferarmschienen": 2x 2840'), s)
assert(has(s, 'OK     Rezeptname: "Kupferarmschienen"'), s)
assert(has(s, 'OK     Lagerbeschreibung: "Errichtet ein Schleifrad."'), s)
assert(has(s, 'OK     Händlergunst: "Händlergunst": 75'), s)
assert(has(s, "Schmiedekunst: Rang 45, 1 bekannt; IsPlayerSpell(2663) = true"), s)
assert(has(s, "WERT   Daten: 3 Berufe, Client"), s)

-- the camp description not loaded yet (the first ask after the login): a value, not a problem, and
-- the client is asked to load it
local realDesc = C_Spell.GetSpellDescription
C_Spell.GetSpellDescription = function() return "" end
C_Spell.IsSpellDataCached = function() return false end
local askedLoad = {}
C_Spell.RequestLoadSpellData = function(id) askedLoad[#askedLoad + 1] = id end
s = section(ST.Run().text)
assert(has(s, "WERT   Lagerbeschreibung: noch nicht geladen") and askedLoad[1] == 1307392, s)
-- loaded and still empty: missing
C_Spell.IsSpellDataCached = function() return true end
s = section(ST.Run().text)
assert(has(s, "FEHLT  Lagerbeschreibung"), s)
C_Spell.GetSpellDescription, C_Spell.IsSpellDataCached, C_Spell.RequestLoadSpellData = realDesc, nil, nil
