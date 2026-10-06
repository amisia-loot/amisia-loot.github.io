-- hand-made test fixture, not real data: an old zone listing an NPC the Forever files know too
root(ROOTS.Zones, m(MAP.TEST_HILLS, {
	n(VENDORS, {
		n(81003, {	-- Smith Fixture
			["coord"] = { 90.0, 90.0, MAP.TEST_HILLS },
			["groups"] = { i(61014) },	-- Old Stock Boots
		}),
	}),
}));
