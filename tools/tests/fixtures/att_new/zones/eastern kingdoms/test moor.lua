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
		}),
	},
});
