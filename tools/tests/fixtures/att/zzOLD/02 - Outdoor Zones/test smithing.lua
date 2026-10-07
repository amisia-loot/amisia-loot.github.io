-- hand-made test fixture, not real data: a Classic profession quest
root(ROOTS.Professions, prof(BLACKSMITHING, {
	q(72100, {	-- The Old Anvil
		["qg"] = 82100,	-- Smith of Old
		["coord"] = { 70.0, 30.0, MAP.TEST_CITY },
		["requireSkill"] = BLACKSMITHING,
		["lvl"] = 20,
	}),
}));
