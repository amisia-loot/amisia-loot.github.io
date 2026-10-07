-----------------------------------------------------
--   hand-made test fixture, not real data          --
-----------------------------------------------------
root(ROOTS.Instances, {
	inst(9001, {	-- Test Halls
		["zone-text-areaID"] = 99001,
		["mapID"] = MAP.TEST_HALLS,
		["coord"] = { 50.0, 50.0, MAP.TEST_CITY },
		["timeline"] = { TIMELINE.ADDED_1_60_1 },
		["lvl"] = 13,
		["groups"] = {
			n(QUESTS, {
				q(70001, {	-- First Grudge -- Might not exist //someone
					qg = 80001,	-- Giver One <The Title>
					coord = { 32.45, 44.8, MAP.TEST_CITY },
					races = ALLIANCE_ONLY,
					lvl = 10,
					sourceQuests = {
						70010,	-- Root Quest
						79999,	-- Unknown Quest
					},
					altQuests = { 70011, 70012 },
					groups = {
						objective(1, {	-- 0/1 Boss slain
							provider = { "n", 80100 },	-- Boss
						}),
						i(60001),	-- Cloak
						i(60002, {	-- Trousers
							timeline = { TIMELINE.ADDED_1_60_1 },
						}),
					},
				}),
				q(70002, {	-- Inside Job
					["qg"] = 80002,	-- Inner Giver
					["coord"] = { 10.0, 20.0, MAP.TEST_HALLS },
					["races"] = HORDE_ONLY,
					["lvl"] = 12,
					["sourceQuest"] = 70013,	-- Go to the Halls (a breadcrumb)
				}),
				q(70003, {	-- Found Note
					qs = 60100,	-- A Note (QS!)
					lvl = 9,
					groups = { applyclassicphase(PHASE_ONE + 1, i(60003)) },	-- Ring
				}),
				q(70004, {	-- Unknown Start
					qg = 80004,	-- Lost Giver
					lvl = 11,
					sourceQuests = {
						70010,	-- Root Quest
						70012,	-- Detour B
					},
					sourceQuestNumRequired = 1,
				}),
			}),
			e(3001, {	-- Boss
				creatureID = 80100,	-- Boss
				groups = { i(60200) },	-- Boss Loot
			}),
		},
	}),
});
