-- hand-made test fixture, not real data: the pre-quests live in a zone
local X = NEUTRAL * 2;
root(ROOTS.Zones, m(MAP.TEST_HILLS, {
	n(QUESTS, {
		q(70010, {	-- Root Quest
			qg = 80010,	-- Root Giver
			coord = { 60.0, 40.0, MAP.TEST_HILLS },
			lvl = 8,
		}),
		q(70011, {	-- Detour A
			qg = 80011,	-- Detour Giver
			coord = { 61.0, 41.0, MAP.TEST_HILLS },
			races = HORDE_ONLY,
			lvl = 8,
			sourceQuest = 70001,	-- First Grudge (a loop)
		}),
		q(70012, {	-- Detour B
			lvl = 8,
		}),
		q(70001, {	-- First Grudge
			qg = 80001,	-- Giver One
			coord = { 32.45, 44.8, MAP.TEST_CITY },
			lvl = 10,
		}),
		q(70013, {	-- Go to the Halls
			isBreadcrumb = true,
			races = HORDE_ONLY,
			lvl = 10,
		}),
		q(70500, {	-- Unrelated Zone Quest
			lvl = 5,
		}),
	}),
}));
