-- The talent calculator's rules (Talents.lua): points per level and with the Talented perk, the
-- row locks from the counting groups, prerequisites (one full source of the sufficient ones, every
-- required one), ranks, taking points back only when nothing else breaks, resets, the share code
-- (round trip, every way a code can be wrong, multi-pass rebuild), the live talents from the client
-- (C_ClassTalents/C_Traits) and the client's own texts with the data as fallback.
local T = NS.Talents
assert(T, "Talents.lua loads")
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end

local LEVELS = {}
for l = 10, 60 do LEVELS[#LEVELS + 1] = l end
NS.TALENTS = { build = "test", max = 51, levels = LEVELS, talented = { 9, 8, 7, 6, 5 }, classes = {
    MAGE = { id = 8, tree = 1112, spec = 1482,
        trees = { { 11, "Arcane", 1 }, { 12, "Fire", 2 }, { 13, "Frost", 3 } },
        gates = { [21] = { 101, 102 }, [22] = { 101, 102, 103 }, [23] = { 201, 202 } },
        nodes = {
            { 101, 1001, 5001, 11, 1, 0, 0, 2, 0, 0, "Arcane Subtlety", "Reduces resistance by {1}.", { { "5", "10" } } },
            { 102, 1002, 5002, 12, 1, 0, 1, 5, 0, 0, "Arcane Focus", "Hit +{1}%.", { { "2", "4", "6", "8", "10" } } },
            { 103, 1003, 5003, 13, 1, 1, 1, 5, { 21, 5 }, 0, "Arcane Concentration", "Chance {1}%, {2} mana.",
              { { "2", "4", "6", "8", "10" }, { "1", "2", "3", "4", "5" } } },
            { 104, 1004, 5004, 14, 1, 2, 1, 1, { 22, 10 }, { 103 }, "Presence of Mind", "Instant." },
            { 105, 1005, 5005, 15, 1, 2, 2, 1, { 22, 10 }, { -104 }, "Arcane Power", "Power." },
            { 201, 2001, 6001, 21, 2, 0, 0, 5, 0, 0, "Improved Fireball", "Cast -{1} sec.", { { "0.1", "0.2", "0.3", "0.4", "0.5" } } },
            { 202, 2002, 6002, 22, 2, 0, 1, 5, 0, 0, "Impact", "Stun {1}%.", { { "2", "4", "6", "8", "10" } } },
            { 203, 2003, 6003, 23, 2, 1, 1, 1, { 23, 5 }, { 201, 202 }, "Pyroblast", "Boom." },
            { 301, 3001, 7001, 31, 3, 0, 0, 3, 0, 0, "Frostbite", "Freeze {1}%.", { { "5", "10", "15" } } },
        } },
    WARRIOR = { id = 1, tree = 1117, spec = 1491,
        trees = { { 41, "Arms", 4 }, { 42, "Fury", 5 }, { 43, "Protection", 6 } }, gates = {},
        nodes = {
            { 401, 4001, 8001, 41, 1, 0, 0, 3, 0, 0, "Improved Heroic Strike", "Cost -{1}.", { { "1", "2", "3" } } },
            { 402, 4002, 8002, 42, 2, 0, 0, 5, 0, 0, "Booming Voice", "Area +{1}%.", { { "10", "20", "30", "40", "50" } } },
            { 403, 4003, 8003, 43, 3, 0, 0, 5, 0, 0, "Shield Specialization", "Block +{1}%.", { { "1", "2", "3", "4", "5" } } },
        } },
} }
T._reset()
assert(T.Available(), "data loaded")

---------------------------------------------------------------------------
-- points per level and the Talented perk (earlier points, never more than the maximum)
assert(T.Max() == 51)
assert(T.PointsAt(9, 0) == 0 and T.PointsAt(10, 0) == 1 and T.PointsAt(30, 0) == 21 and T.PointsAt(60, 0) == 51)
assert(T.PointsAt(5, 5) == 1 and T.PointsAt(9, 5) == 5 and T.PointsAt(9, 1) == 1 and T.PointsAt(10, 5) == 6)
assert(T.PointsAt(55, 5) == 51 and T.PointsAt(60, 5) == 51, "Talented never gives more than 51")
assert(T.LevelFor(0, 0) == 1 and T.LevelFor(1, 0) == 10 and T.LevelFor(51, 0) == 60 and T.LevelFor(51, 5) == 55)
assert(T.LevelFor(52, 0) == nil, "more than the maximum: no level")

-- class order: the player's own first, then by class id
STUB.class = "WARRIOR"
assert(T.Classes()[1] == "WARRIOR" and T.Classes()[2] == "MAGE")
STUB.class = "MAGE"
assert(T.Classes()[1] == "MAGE")

---------------------------------------------------------------------------
-- spending: ranks, row locks, prerequisites, points
local p = T.NewPlan("MAGE")
assert(T.Spent(p) == 0 and T.Rank(p, 101) == 0)
local ok, why = T.CanAdd(p, 103, 51)
assert(not ok and has(why, "5 Punkte in Arcane"), "row 2 needs 5 points above: " .. tostring(why))
assert(T.Add(p, 101, 51) and T.Add(p, 101, 51) and T.Rank(p, 101) == 2)
ok, why = T.CanAdd(p, 101, 51)
assert(not ok and has(why, "Höchster Rang"), tostring(why))
for _ = 1, 3 do assert(T.Add(p, 102, 51)) end
assert(T.Spent(p) == 5 and T.Spent(p, 1) == 5 and T.Spent(p, 2) == 0)
assert(T.CanAdd(p, 103, 51), "5 points in the rows above unlock row 2")
ok, why = T.CanAdd(p, 103, 5)
assert(not ok and has(why, "Keine Punkte"), "no points left at 5: " .. tostring(why))
assert(T.Add(p, 103, 51))
ok, why = T.CanAdd(p, 104, 51)
assert(not ok and has(why, "10 Punkte"), "row 3 needs 10: " .. tostring(why))
for _ = 1, 2 do assert(T.Add(p, 102, 51)) end
ok, why = T.CanAdd(p, 104, 51)
assert(not ok and has(why, "10 Punkte"), "8 of 10: " .. tostring(why))
for _ = 1, 2 do assert(T.Add(p, 103, 51)) end
ok, why = T.CanAdd(p, 104, 51)
assert(not ok and has(why, "Arcane Concentration") and has(why, "5/5"), "the prerequisite must be full: " .. tostring(why))
for _ = 1, 2 do assert(T.Add(p, 103, 51)) end
assert(T.Add(p, 104, 51), "full prerequisite and 10 points: free")
-- a required prerequisite (negative id) needs that node full
local q = T.NewPlan("MAGE")
q.ranks = { [101] = 2, [102] = 5, [103] = 5 }
assert(not T.CanAdd(q, 105, 51) and T.Add(q, 104, 51) and T.Add(q, 105, 51), "105 requires 104")
-- sufficient prerequisites: one full source is enough
local f = T.NewPlan("MAGE")
for _ = 1, 5 do T.Add(f, 202, 51) end
assert(T.CanAdd(f, 203, 51), "Impact full is enough for Pyroblast")
f.ranks[202] = 4; f.ranks[201] = 1
ok, why = T.CanAdd(f, 203, 51)
assert(not ok and has(why, "Improved Fireball") and has(why, "oder") and has(why, "Impact"), tostring(why))

---------------------------------------------------------------------------
-- taking points back: only when every spent point stays valid
assert(T.Spent(p) == 13 and T.Rank(p, 104) == 1)
ok, why = T.CanRemove(p, 103)
assert(not ok and has(why, "Presence of Mind"), "the full prerequisite cannot shrink: " .. tostring(why))
assert(T.CanRemove(p, 101), "12 points above row 3 stay 11")
local g = T.NewPlan("MAGE")
g.ranks = { [101] = 2, [102] = 3, [103] = 1 }
ok, why = T.CanRemove(g, 101)
assert(not ok and has(why, "Arcane Concentration"), "the row lock below would break: " .. tostring(why))
assert(T.Remove(p, 104) and T.Rank(p, 104) == 0)
assert(T.Remove(p, 103), "now it can")
assert(not T.CanRemove(p, 301), "nothing to take back")
-- shift: as many as possible
local s = T.NewPlan("MAGE")
assert(T.AddAll(s, 102, 51) == 5 and T.Rank(s, 102) == 5)
assert(T.AddAll(s, 101, 6) == 1, "only the free points")
assert(T.RemoveAll(s, 102) == 5 and T.Rank(s, 102) == 0)
-- resets
T.ResetTree(p, 1)
assert(T.Spent(p) == 0)
p.ranks[201] = 3; p.ranks[101] = 1
T.Reset(p)
assert(T.Spent(p) == 0 and next(p.ranks) == nil)

---------------------------------------------------------------------------
-- the share code
local c = T.NewPlan("MAGE")
c.ranks = { [101] = 2, [102] = 3, [103] = 1, [201] = 5, [202] = 0, [203] = 0, [301] = 2 }
assert(T.Encode(c) == "AT1.MAGE.231.5.2", T.Encode(c))
assert(T.Encode(T.NewPlan("WARRIOR")) == "AT1.WARRIOR...", T.Encode(T.NewPlan("WARRIOR")))
local back, err = T.Decode("  AT1.MAGE.231.5.2 ")
assert(back and back.class == "MAGE" and back.ranks[101] == 2 and back.ranks[102] == 3 and back.ranks[103] == 1
    and back.ranks[201] == 5 and back.ranks[301] == 2 and T.Spent(back) == 13, tostring(err))
-- in a row of chat text, too
assert(T.Decode("Mein Build: AT1.MAGE.231.5.2 viel Spaß"), "a code inside a chat line")
-- multi-pass: a prerequisite in the same row and later in the order
local mp = T.NewPlan("MAGE")
mp.ranks = { [101] = 2, [102] = 5, [103] = 5, [104] = 1, [105] = 1, [202] = 5, [203] = 1 }
local code = T.Encode(mp)
local again = assert(T.Decode(code))
assert(T.Encode(again) == code and T.Spent(again) == 20)
for _, bad in ipairs({
    { "", "Kein" }, { "AT2.MAGE.1..", "Kein" }, { "AT1.PIRATE.1..", "Klasse" }, { "AT1.MAGE.3..", "Rang" },
    { "AT1.MAGE.000001..", "lang" }, { "AT1.MAGE.0010..", "Voraussetzung" }, { "AT1.MAGE.x..", "Kein" },
}) do
    local plan, e = T.Decode(bad[1])
    assert(plan == nil and has(e, bad[2]), ("%q: %s"):format(bad[1], tostring(e)))
end
-- more points than the game gives
local big = { "AT1.WARRIOR.3.5.5" }
assert(T.Decode(big[1]), "13 points are fine")

---------------------------------------------------------------------------
-- texts: the client's own (German) first, the data as fallback
assert(T.NodeName(T.Node("MAGE", 103)) == "Arcane Concentration", "no client function: data")
assert(T.NodeText(T.Node("MAGE", 103), 2) == "Chance 4%, 2 mana.", T.NodeText(T.Node("MAGE", 103), 2))
assert(T.NodeText(T.Node("MAGE", 103), 0) == "Chance 2%, 1 mana.", "rank 0 shows rank 1")
assert(T.NodeText(T.Node("MAGE", 104), 1) == "Instant.")
assert(T.TreeName("MAGE", 2) == "Fire" and T.ClassName("MAGE") ~= nil)
_G.C_Spell = { GetSpellName = function(id) return id == 5003 and "Arkane Konzentration" or nil end,
               GetSpellTexture = function(id) return 999 end }
_G.C_Traits = {
    GetTraitDescription = function(entry, rank) return entry == 1003 and ("Chance %d%% (Rang %d)."):format(rank * 2, rank) or nil end,
    GetGroupDisplayInfoByTreeID = function(tree)
        if tree ~= 1112 then return {} end
        return { { groupID = 11, treeID = 1112, displayName = "Arkan" }, { groupID = 12, treeID = 1112, displayName = "Feuer" } }
    end,
}
T._reset()
assert(T.NodeName(T.Node("MAGE", 103)) == "Arkane Konzentration")
assert(T.NodeName(T.Node("MAGE", 104)) == "Presence of Mind", "no client name: data")
assert(T.NodeText(T.Node("MAGE", 103), 3) == "Chance 6% (Rang 3).")
assert(T.NodeText(T.Node("MAGE", 102), 2) == "Hit +4%.", "no client text: data")
assert(T.TreeName("MAGE", 1) == "Arkan" and T.TreeName("MAGE", 3) == "Frost", "the client's tree names, data for the rest")
-- a client function that errors or answers a secret value changes nothing
_G.C_Traits.GetTraitDescription = function() error("boom") end
assert(T.NodeText(T.Node("MAGE", 103), 1) == "Chance 2%, 1 mana.")

---------------------------------------------------------------------------
-- the player's own talents, live
STUB.class = "MAGE"
local live, why2 = T.Live()
assert(live == nil and has(why2, "nicht"), "no talent API: " .. tostring(why2))
local RANKS = { [101] = 2, [102] = 3, [103] = 1, [201] = 4 }
_G.C_Traits.GetNodeInfo = function(config, id)
    assert(config == 77)
    if id == 301 then return nil end
    return { ID = id, ranksPurchased = RANKS[id] or 0, activeRank = (RANKS[id] or 0) + (id == 102 and 1 or 0) }
end
_G.C_ClassTalents = { GetActiveConfigID = function() return nil end }
live, why2 = T.Live()
assert(live == nil and has(why2, "Talentkonfiguration"), tostring(why2))
_G.C_ClassTalents.GetActiveConfigID = function() return 77 end
_G.C_Traits.GetTreeCurrencyInfo = function(config, tree, excludeStaged)
    assert(config == 77 and tree == 1112 and excludeStaged == false)
    return { { traitCurrencyID = 3820, quantity = 3, spent = 10, maxQuantity = 51 } }
end
local info
live, info = T.Live()
assert(live and live.class == "MAGE" and live.ranks[101] == 2 and live.ranks[102] == 3 and live.ranks[201] == 4,
    "ranksPurchased, not granted ranks")
assert(T.Spent(live) == 10 and info.spent == 10 and info.free == 3 and info.total == 13 and info.config == 77)
assert(info.missing == 1, "a node the client does not know is counted")
-- the live plan is always the player's own class
STUB.class = "WARRIOR"
assert(T.Live().class == "WARRIOR")
STUB.class = "MAGE"

-- the saved state: plans per class as codes
local st = T.State()
assert(st.level == nil and type(st.plans) == "table")
T.SavePlan(c)
assert(AmisiaDB.talents.plans.MAGE == "AT1.MAGE.231.5.2")
local loaded = T.LoadPlan("MAGE")
assert(loaded.ranks[201] == 5 and T.Encode(loaded) == "AT1.MAGE.231.5.2")
assert(T.LoadPlan("WARRIOR") and T.Spent(T.LoadPlan("WARRIOR")) == 0, "no plan: empty")
AmisiaDB.talents.plans.WARRIOR = "kaputt"
assert(T.Spent(T.LoadPlan("WARRIOR")) == 0, "a broken saved code: empty")
print("test_talents ok")
