-- The build's data (BisData.lua, tools/build_bis.py) in the addon: ns.BIS loads with its parts; the
-- dungeon facts name their bosses by NPC id (AllTheThings) with the English name; a kill of a
-- known boss (Faldrim Anvilmar in Hall of Thanes, NPC 261306) is recorded from its loot window
-- although the window holds no rare item and no kill event came (Drops.lua isBoss), and the
-- planner puts that NPC on the item data's boss of the same name (Dungeons.lua).
local Gear = NS.Gear
local function find(list, key) for _, e in ipairs(list) do if e.key == key then return e end end end

local B = NS.BIS
assert(type(B) == "table" and B.gamedata and B.built, "BisData.lua loads")
assert(type(B.SC) == "table" and type(B.SET) == "table" and type(B.RP) == "table" and type(B.DG) == "table"
    and type(B.O) == "table" and type(B.EF) == "table", "every part")
assert(B.EF.V == 1 and B.EF.D == 3 and B.EF.W == 20 and B.EF.P == 25)
assert(NS.Dungeons.Facts() == B.DG, "the planner takes the build's facts")
local thanes = find(B.DG, "thanes")
assert(thanes and thanes.min == 13 and thanes.max == 18 and thanes.kind == "party", "the hand facts carry over")
local FALDRIM = 261306
local hasId = false
for _, b in ipairs(thanes.bosses) do if b == FALDRIM then hasId = true end end
assert(hasId and thanes.bossNames[FALDRIM] == "Faldrim Anvilmar", "the boss by NPC id with its name")
-- every key of the hand facts is there
for _, e in ipairs(NS.DUNGEON_FACTS.list) do assert(find(B.DG, e.key), "facts key " .. e.key) end
-- computed stats are only for items without a scan
for id in pairs(B.SC) do assert(not (NS.GEAR.ST and NS.GEAR.ST[id]), "a scanned item has no SC: " .. id) end

---------------------------------------------------------------------------
-- a kill of a known boss: no rare item, no kill event, still a record
---------------------------------------------------------------------------
local d = AmisiaDB.drops
STUB.instance = { name = "Halle der Thane", type = "party", id = 3065, diff = 1 }
local GUID = "Creature-0-3110-3065-47-" .. FALDRIM .. "-00002E7CF2"
local green = STUB.item(219004, "Grüner Ring", 2)
STUB.target, STUB.targetGUID = "Faldrim Ambossmahl", GUID
STUB.loot = { { link = green, name = "Grüner Ring", src = GUID } }
STUB.fire("LOOT_OPENED")
local h = NS.DropsKillID(GUID)
assert(d.k[h] and d.k[h].npc == FALDRIM and d.k[h].it[219004] == 1, "the known boss's kill is recorded")
-- a trash mob of the same dungeon with the same loot is not
local TRASH = "Creature-0-3110-3065-47-261399-00002E7CF3"
STUB.target, STUB.targetGUID = "Ein Zwerg", TRASH
STUB.loot = { { link = green, name = "Grüner Ring", src = TRASH } }
STUB.fire("LOOT_OPENED")
assert(not d.k[NS.DropsKillID(TRASH)], "trash stays out")

---------------------------------------------------------------------------
-- the planner: the record's NPC is the item data's Faldrim Anvilmar
---------------------------------------------------------------------------
STUB.class, STUB.level, STUB.faction = "WARRIOR", 16, "Alliance"
NS.BisSetSpec("dps")
-- one of Faldrim's items on the wishlist, so the planner lists the boss whatever it is worth
local src
for n, rec in ipairs(NS.GEAR.S) do
    if rec[1] == "D" and rec[3] == "Faldrim Anvilmar" then src = n break end
end
assert(src, "the item data knows Faldrim Anvilmar")
local wish
for id, row in pairs(NS.GEAR.I) do
    for i = Gear.FIRST_SOURCE, #row do
        if row[i] == src and Gear.Usable("WARRIOR", row, 60) and (not wish or id < wish) then wish = id end
    end
end
assert(wish, "a warrior can wear one of Faldrim's items")
STUB.level = 60
assert(NS.WishAdd(wish))
local e = find(NS.DungeonList(), "thanes")
assert(e, "Hall of Thanes in the list")
local named = 0
for _, b in ipairs(e.bosses) do
    if b.name == "Faldrim Anvilmar" then
        assert(b.npc == FALDRIM, "the item data's boss has the NPC id")
        named = named + 1
    end
    assert(b.npc ~= FALDRIM or b.name == "Faldrim Anvilmar", "no second boss for the NPC: " .. tostring(b.name))
end
assert(named == 1, "Faldrim Anvilmar once, with his NPC id")
NS.WishRemove(wish)
STUB.instance = { name = "Dun Morogh", type = "none", id = 0 }
