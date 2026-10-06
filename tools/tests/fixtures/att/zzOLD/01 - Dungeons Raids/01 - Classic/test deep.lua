-- hand-made test fixture, not real data: a Classic dungeon not yet moved into the Forever folders
root(ROOTS.Instances, expansion(EXPANSION.CLASSIC, {
	inst(9003, {	-- Test Deep
		["zone-text-areaID"] = 99003,
		["mapID"] = MAP.TEST_DEEP,
		["coord"] = { 70.0, 20.0, MAP.TEST_HILLS },
		["groups"] = {
			n(QUESTS, {
				q(70001, {	-- First Grudge (an old copy: the Forever record stays)
					["lvl"] = 1,
				}),
			}),
			n(ZONE_DROPS, {
				i(61011, { ["crs"] = { 81005 } }),	-- Trash Gloves
			}),
			n(81006, {	-- Deep Boss
				i(61012),	-- Boss Boots
			}),
			e(4001, {	-- Encounter Boss
				["creatureID"] = 81007,
				["groups"] = { i(61013) },	-- Encounter Sword
			}),
		},
	}),
}));
