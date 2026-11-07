-- The reward tiles of a dungeon quest (Pages/Dungeons.lua fillRewards): a reward that is no upgrade
-- says nothing about the worn item; it never reads "Platz leer" while that slot is filled. An upgrade
-- still names what it replaces.
local function has(t, part) return type(t) == "string" and t:find(part, 1, true) ~= nil end
local function plain(t) return (tostring(t or ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
STUB.xp = { 1000, 10000 }
STUB.instance = { name = "Westfall", type = "none", id = 0 }
STUB.maps[1436] = { name = "Westfall", mapType = 3 }
STUB.place.map = 1436
NS.Map._reset()
NS.DUNGEON_QUESTS = {
    built = "test", source = "test",
    D = { deadmines = { 600 } },
    Q = {
        [600] = { "Brotherhood", 14, 18, "A", 0, "O", "Gryan", "1436:5630:4760", nil, nil, "deadmines", { 9920, 9921 }, nil,
                  nil, nil, nil, 0, 0, "Gryan", "1436:5630:4760", "Bring the head of Edwin van Cleef." },
    },
}
-- a weak chest against a strong worn one (no upgrade), a cloak for the empty back (an upgrade)
STUB.item(9920, "Westfall Vest", 2)
local it = STUB.items[9920]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_CHEST", 4, 2, 14
it.stats = { ITEM_MOD_STRENGTH_SHORT = 2 }
STUB.item(9921, "Westfall Cloak", 2)
it = STUB.items[9921]
it.equipLoc, it.classID, it.subclassID, it.minLevel = "INVTYPE_CLOAK", 4, 1, 14
it.stats = { ITEM_MOD_STRENGTH_SHORT = 3 }
STUB.worn[5] = STUB.item(9940, "Strong Shirt", 3)
STUB.items[9940].equipLoc, STUB.items[9940].classID, STUB.items[9940].subclassID = "INVTYPE_CHEST", 4, 2
STUB.items[9940].stats = { ITEM_MOD_STRENGTH_SHORT = 40 }
NS.GEAR = { built = "test-fix-rewards", Z = {}, I = {}, S = {} }
NS.Gear._reset()
NS.BisBump()

AmisiaDB.settings.bis = AmisiaDB.settings.bis or {}
AmisiaDB.settings.bis.dpart = "bosses"
NS.ShowDungeon("deadmines")
local B = NS.DungeonsPageFrame()
B.plan:Click()
local V = B.pathView
local row
for _, r in ipairs(V.list.rows) do if r:IsShown() and r.item and r.item.qid == 600 then row = r end end
assert(row, "the quest row")
row:Click()
local subs = {}
for i = 1, 2 do
    local b = V.rewards[i]
    assert(b and b:IsShown(), "two reward tiles")
    subs[b.id] = plain(b.sub:GetText())
end
assert(subs[9920] and not has(subs[9920], "Platz leer") and not has(subs[9920], "statt"),
    "no upgrade: nothing about the worn chest: " .. tostring(subs[9920]))
assert(has(subs[9921], "Platz leer"), "the upgrade for the empty back: " .. tostring(subs[9921]))
