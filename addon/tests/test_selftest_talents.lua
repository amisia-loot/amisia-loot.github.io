-- /amisia selbsttest, section "Talente": the shipped data, the active configuration, the own tree
-- against the data, the nodes the client knows, the points, and whether another class's texts and
-- tree names come from the client. Without the talent API it only says so (WERT), never FEHLT.
local ST = NS.SelfTest
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function section(text)
    return text:match("== Talente ==\n(.-)\n\n") or text:match("== Talente ==\n(.*)$")
end

STUB.class = "MAGE"
local R = ST.Run()
local s = section(R.text)
assert(s, "the section is there")
assert(has(s, "WERT   Talentdaten: Build ") and has(s, "9 Klassen"), "the shipped data: " .. s)
assert(has(s, "Aktive Konfiguration: C_ClassTalents.GetActiveConfigID fehlt"), s)
assert(not has(s, "FEHLT") and not has(s, "FEHLER"), "optional: no problem without the API")

local mage = NS.Talents.Class("MAGE")
local warrior = NS.Talents.Class("WARRIOR")
_G.C_ClassTalents = { GetActiveConfigID = function() return 42 end }
_G.C_Traits = {
    GetConfigInfo = function(c) return { ID = c, treeIDs = { mage.tree } } end,
    GetNodeInfo = function(_, id) return { ID = id, maxRanks = mage.byId[id] and mage.byId[id][8], ranksPurchased = 0 } end,
    GetTreeCurrencyInfo = function() return { { quantity = 21, spent = 0, maxQuantity = 51 } } end,
    GetTraitDescription = function(entry) return entry == warrior.order[1][1][2] and "Verringert die Kosten." or nil end,
    GetGroupDisplayInfoByTreeID = function(tree)
        if tree ~= warrior.tree then return {} end
        return { { displayName = "Waffen" }, { displayName = "Furor" }, { displayName = "Schutz" } }
    end,
}
_G.C_Spell = { GetSpellName = function() return "Verbesserter Heldenhafter Stoß" end }
R = ST.Run()
s = section(R.text)
assert(has(s, "WERT   Aktive Konfiguration: 42"), s)
assert(has(s, "OK     Talentbaum: Client " .. mage.tree), s)
assert(s:find("OK     Knoten im Client: (%d+) von %1 bekannt, 0 mit anderem Höchstrang"), s)
assert(has(s, "Talentpunkte: frei 21, ausgegeben 0, höchstens 51"), s)
assert(has(s, "OK     Text fremde Klasse: WARRIOR") and has(s, "Verringert die Kosten."), s)
assert(has(s, 'OK     Baumnamen fremde Klasse: "Waffen", "Furor", "Schutz"'), s)
assert(has(s, "Spell-Name: \"Verbesserter Heldenhafter Stoß\""), s)
-- a node the client does not know
_G.C_Traits.GetNodeInfo = function(_, id) if id == mage.order[1][1][1] then return nil end return { ID = id } end
s = section(ST.Run().text)
assert(s:find("WERT   Knoten im Client: (%d+) von (%d+) bekannt") and not s:find("OK     Knoten"), s)
print("test_selftest_talents ok")
