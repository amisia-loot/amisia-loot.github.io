-- hand-made test fixture, not real data
root(ROOTS.Craftables, sharedData({ timeline = { TIMELINE.ADDED_1_60_1 } }, {
	prof(TAILORING, {
		i(61017),	-- Woven Robe
	}),
	prof(MINING, {
		spell(2575, {	-- Mining
			groups = appendAllGroups(
				sharedData({ requireSkill = MINING }, {
					o(71001, {	-- Test Vein
						maps = { MAP.TEST_HILLS },
						groups = { i(61018) },	-- Test Ore (under its node)
					}),
				}),
				{
					i(61019, {	-- Test Gem
						maps_disp = { MAP.TEST_CITY },
						providers = { { "o", 71001 } },	-- Test Vein
					}),
				}
			),
		}),
	}),
	prof(HERBALISM, {
		i(61020),	-- Test Herb (no zones)
	}),
}));
