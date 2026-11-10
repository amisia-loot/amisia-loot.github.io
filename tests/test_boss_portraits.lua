-- Every boss its portrait (F-170, D-100): the NPC of a boss name (Dungeons.lua D.BossNpc) from the facts'
-- order (DungeonData.lua npcs), else the build's bossNames (BisData.lua), else the id in an item-data name
-- "NPC 4442"; the part Übersicht lists every boss of the game's order (D.JournalBosses), a given boss at
-- its place by name or NPC; each dungeon of a map of several (the halves of Blackrock Spire, the Scarlet
-- Monastery's four wings, D-106) has only its own bosses; the real data: the Scarlet Monastery's wings,
-- Blackrock Spire and the Drowned City have their bosses and NPCs.
local Dn = NS.Dungeons
assert(type(NS.BIS) == "table" and type(NS.BIS.DG) == "table", "the build's data")

---------------------------------------------------------------------------
-- D.BossNpc
---------------------------------------------------------------------------
assert(Dn.BossNpc("smcath", "High Inquisitor Whitemane") == 3977, "the Cathedral's order (its wing of ATT)")
assert(Dn.BossNpc("smcath", "high inquisitor whitemane") == 3977, "names compare without case")
assert(Dn.BossNpc("smcath", "Scarlet Commander Mograine") == 3976, "no encounter: the build's bossNames")
assert(Dn.BossNpc("smgy", "Ironspine") == 6489, "a rare of the Graveyard (the build's bossNames)")
assert(Dn.BossNpc("drowned", "Zul'Alai") == 258905 and Dn.BossNpc("drowned", "Min'loth the Serpent") == 260243)
assert(Dn.BossNpc("bfd", "Geilhast") == 6243, "the client's spelling of Gelihast (boss_alias)")
assert(Dn.BossNpc("thanes", "Infurnus") == 261316 and Dn.BossNpc("thanes", "Magmatus") == 261316,
    "the client's name by the order, the item data's by the build's bossNames")
assert(Dn.BossNpc("ulda", "The Lost Dwarves") == 6906, "a group: Baelog stands for it")
assert(Dn.BossNpc("brd", "Ring of Law") == 10096, "an encounter by its first creature")
assert(Dn.BossNpc("rfk", "NPC 4442") == 4442, "the id of a nameless NPC of the item data")
assert(Dn.BossNpc("scholo", "Lady Illucia Barov") == nil, "no source names her")
assert(Dn.BossNpc("nowhere", "Zul'Alai") == nil and Dn.BossNpc("smgy", nil) == nil)

---------------------------------------------------------------------------
-- D.JournalBosses
---------------------------------------------------------------------------
local function names(list)
    local out = {}
    for _, b in ipairs(list) do out[#out + 1] = b.name end
    return table.concat(out, ",")
end
local function find(list, name) for _, b in ipairs(list) do if b.name == name then return b end end end
-- the Drowned City without loot for the character: its six bosses in the game's order (DungeonEncounter, D-101),
-- each with its NPC
local dr = Dn.JournalBosses("drowned", {})
assert(names(dr) == "Zul'Alai,Var'Taka,Captain Dreadrise,Deathless Guardians,Primeval Elemental,Min'loth the Serpent", names(dr))
for _, b in ipairs(dr) do assert(type(b.npc) == "number" and b.npc > 0 and b.b.npc == b.npc and #b.b.items == 0, b.name) end
-- a given boss at its place by name, another by its NPC, an unknown one after the order
local given = { { name = "Captain Dreadrise", npc = 260042, items = { {} } }, { name = "Odd One", items = {} },
    { name = "Serpent of the Depths", npc = 260243, items = {} } }
dr = Dn.JournalBosses("drowned", given)
assert(names(dr) == "Zul'Alai,Var'Taka,Captain Dreadrise,Deathless Guardians,Primeval Elemental,Serpent of the Depths,Odd One",
    names(dr))
assert(find(dr, "Captain Dreadrise").b == given[1], "the given boss itself")
-- Blackrock Spire: each half only its own bosses (D-106: each its own order)
local lower, upper = Dn.JournalBosses("lbrs", {}), Dn.JournalBosses("ubrs", {})
assert(find(lower, "Highlord Omokk") and not find(lower, "General Drakkisath"), names(lower))
assert(find(upper, "General Drakkisath") and not find(upper, "Highlord Omokk"), names(upper))
assert(#lower == #Dn.BossOrder("lbrs") and #upper == #Dn.BossOrder("ubrs"), "every boss in one half")
assert(#Dn.BossOrder("lbrs") == 9 and #Dn.BossOrder("ubrs") == 5, "9 below, 5 above")
-- the Scarlet Monastery: four wings, each its own bosses in the game's order, every boss with its NPC
local wings = { smgy = "Interrogator Vishas,Bloodmage Thalnos", smlib = "Houndmaster Loksey,Arcanist Doan",
    smarm = "Herod", smcath = "High Inquisitor Fairbanks,High Inquisitor Whitemane" }
for key, order in pairs(wings) do
    local list = Dn.JournalBosses(key, {})
    assert(names(list) == order, key .. ": " .. names(list))
    for _, b in ipairs(list) do assert(b.npc, key .. ": " .. b.name) end
end
assert(not Dn.BossOrder("sm"), "the old key is gone")
-- known loot of a boss without loot for the character
assert(Dn.KnownLoot("drowned", "Zul'Alai") > 0 and Dn.KnownLoot("drowned", "Deathless Guardians") == 0)
assert(find(Dn.JournalBosses("drowned", {}), "Zul'Alai").b.known > 0)
-- an unknown dungeon: the given bosses as they are
assert(names(Dn.JournalBosses("fake", { { name = "B" }, { name = "A" } })) == "B,A")

print("boss portraits: BossNpc, order, alias, group, nameless, JournalBosses, halves, known loot")
