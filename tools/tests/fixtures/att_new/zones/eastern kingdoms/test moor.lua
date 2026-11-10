---------------------------------------------------
-- hand-made test fixture, not real data: zones  --
-- the way the Forever files write them           --
---------------------------------------------------
maproot(MAP.EASTERN_KINGDOMS, MAP.TEST_MOOR, {
	icon = 236734,
	groups = {
		n(QUESTS, {
			q(73003, {	-- Go to the Keep
				qg = 83002,	-- Sir Moorhelm
				isBreadcrumb = true,
				races = ALLIANCE_ONLY,
				lvl = 36,
			}),
		}),
		n(83002, {	-- Sir Moorhelm <Order of the Moor>
			coord = { 40.5, 60.25, MAP.TEST_MOOR },
			races = ALLIANCE_ONLY,
		}),
	},
});
-- a zone root that names its map once
maproot(MAP.TEST_ISLE, {
	groups = {
		n(QUESTS, {
			q(73101, {	-- Isle Errand
				qg = 83101,	-- Isle Keeper
				coord = { 12.0, 34.0, MAP.TEST_ISLE },
				races = { SKYBORNE_HORDE },
				lvl = 5,
			}),
			q(73102, {	-- Isle Supplies
				qg = 83101,	-- Isle Keeper
				provider = { "i", 63101 },	-- Isle Writ
				qis = { 63102, 63103 },	-- Empty Crate, Tally Sheet (PQI!)
				lvl = 6,
				groups = {
					objective(1, {	-- 0/6 Driftwood
						providers = {
							{ "i", 63104 },	-- Driftwood
							{ "o", 93101 },
						},
					}),
					{
						objective(2, {	-- 0/1 Gull Egg
							provider = { "i", 63105 },	-- Gull Egg
						}),
					},
					objective(3, {	-- 0/4 Isle Crab slain
						provider = { "n", 83102 },	-- Isle Crab
					}),
					i(63106),	-- Isle Boots
					q(73103, {	-- Isle Follow-up
						qg = 83101,	-- Isle Keeper
						lvl = 7,
						groups = {
							objective(1, {	-- 0/1 Sealed Letter
								provider = { "i", 63107 },	-- Sealed Letter
							}),
						},
					}),
				},
			}),
		}),
	},
});
