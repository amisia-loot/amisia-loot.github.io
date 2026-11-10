-- Every boss its portrait (F-170, D-100): the NPC of a boss name (Dungeons.lua D.BossNpc) from the facts'
-- order (DungeonData.lua npcs), else the build's bossNames (BisData.lua), else the id in an item-data name
-- "NPC 4442"; the part Übersicht lists every boss of the game's order (D.JournalBosses), a given boss at
-- its place by name or NPC, the other half's bosses of Blackrock Spire left out; the real data: the
-- Scarlet Monastery, Blackrock Spire and the Drowned City have their bosses and NPCs.
local Dn = NS.Dungeons
assert(type(NS.BIS) == "table" and type(NS.BIS.DG) == "table", "the build's data")

---------------------------------------------------------------------------
-- D.BossNpc
---------------------------------------------------------------------------
assert(Dn.BossNpc("sm", "High Inquisitor Whitemane") == 3977, "the Scarlet Monastery's order (wings of ATT)")
assert(Dn.BossNpc("sm", "high inquisitor whitemane") == 3977, "names compare without case")
assert(Dn.BossNpc("drowned", "Zul'Alai") == 258905 and Dn.BossNpc("drowned", "Min'loth the Serpent") == 260243)
assert(Dn.BossNpc("bfd", "Geilhast") == 6243, "the client's spelling of Gelihast (boss_alias)")
assert(Dn.BossNpc("thanes", "Infurnus") == 261316 and Dn.BossNpc("thanes", "Magmatus") == 261316,
    "the client's name by the order, the item data's by the build's bossNames")
assert(Dn.BossNpc("ulda", "The Lost Dwarves") == 6906, "a group: Baelog stands for it")
assert(Dn.BossNpc("brd", "Ring of Law") == 10096, "an encounter by its first creature")
assert(Dn.BossNpc("rfk", "NPC 4442") == 4442, "the id of a nameless NPC of the item data")
assert(Dn.BossNpc("scholo", "Lady Illucia Barov") == nil, "no source names her")
assert(Dn.BossNpc("nowhere", "Zul'Alai") == nil and Dn.BossNpc("sm", nil) == nil)

---------------------------------------------------------------------------
-- D.JournalBosses
---------------------------------------------------------------------------
local function names(list)
    local out = {}
    for _, b in ipairs(list) do out[#out + 1] = b.name end
    return table.concat(out, ",")
end
local function find(list, name) for _, b in ipairs(list) do if b.name == name then return b end end end
-- the Drowned City without loot for the character: its six bosses in the order, each with its NPC
local dr = Dn.JournalBosses("drowned", {})
assert(names(dr) == "Zul'Alai,Var'Taka,Deathless Guardians,Captain Dreadrise,Primeval Elemental,Min'loth the Serpent", names(dr))
for _, b in ipairs(dr) do assert(type(b.npc) == "number" and b.npc > 0 and b.b.npc == b.npc and #b.b.items == 0, b.name) end
-- a given boss at its place by name, another by its NPC, an unknown one after the order
local given = { { name = "Captain Dreadrise", npc = 260042, items = { {} } }, { name = "Odd One", items = {} },
    { name = "Serpent of the Depths", npc = 260243, items = {} } }
dr = Dn.JournalBosses("drowned", given)
assert(names(dr) == "Zul'Alai,Var'Taka,Deathless Guardians,Captain Dreadrise,Primeval Elemental,Serpent of the Depths,Odd One",
    names(dr))
assert(find(dr, "Captain Dreadrise").b == given[1], "the given boss itself")
-- Blackrock Spire: each half only its own bosses of the shared order
local lower, upper = Dn.JournalBosses("lbrs", {}), Dn.JournalBosses("ubrs", {})
assert(find(lower, "Highlord Omokk") and not find(lower, "General Drakkisath"), names(lower))
assert(find(upper, "General Drakkisath") and not find(upper, "Highlord Omokk"), names(upper))
assert(#lower + #upper == #Dn.BossOrder("lbrs"), "every boss in one half")
-- the Scarlet Monastery: every boss with its NPC
for _, b in ipairs(Dn.JournalBosses("sm", {})) do assert(b.npc, "sm: " .. b.name) end
-- known loot of a boss without loot for the character
assert(Dn.KnownLoot("drowned", "Zul'Alai") > 0 and Dn.KnownLoot("drowned", "Deathless Guardians") == 0)
assert(find(Dn.JournalBosses("drowned", {}), "Zul'Alai").b.known > 0)
-- an unknown dungeon: the given bosses as they are
assert(names(Dn.JournalBosses("fake", { { name = "B" }, { name = "A" } })) == "B,A")

print("boss portraits: BossNpc, order, alias, group, nameless, JournalBosses, halves, known loot")
