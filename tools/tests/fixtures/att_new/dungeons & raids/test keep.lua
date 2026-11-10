-----------------------------------------------------
--   hand-made test fixture, not real data          --
--   the dungeon form since November 2026            --
-----------------------------------------------------
local INNER_WARD = createHeader({
	readable = "Inner Ward",
	icon = 236718,
	text = {
		en = [[~DUNGEON_FLOOR_TESTKEEP1]],
	},
});
instanceroot(9201, {	-- Test Keep
	lore = "A keep for the tests.",
	zoneTextAreaID = 99201,	-- Test Keep
	mapID = MAP.TEST_KEEP,
	coord = { 61.5, 22.5, MAP.TEST_MOOR },
	lvl = 40,
	groups = {
		n(QUESTS, {
			q(73001, {	-- Keep Note
				qs = 63001,	-- Torn Keep Note (QS!)
				races = ALLIANCE_ONLY,
				lvl = 38,
			}),
			q(73002, {	-- Paladin Duty
				qg = 83002,	-- Sir Moorhelm <Order of the Moor>
				sourceQuest = 73003,	-- Go to the Keep
				races = ALLIANCE_PALADINS,
				classes = { PALADIN },
				requireSkill = ARMORSMITH,
				lvl = 40,
			}),
			q(73004, {	-- Odd Altar
				provider = { "o", 93001 },	-- Odd Altar
				lvl = 39,
			}),
			q(73005, {	-- Inner Plea
				qg = 83003,	-- Keep Prisoner
				races = HORDE_SHAMANS,
				lvl = 40,
			}),
			q(73006, {	-- Handed Out
				qi = 63005,	-- Handout (PQI!)
				lvl = 40,
			}),
		}),
		n(ZONE_DROPS, {
			i(63001, {	-- Torn Keep Note (QS!)
				cr = 83001,	-- Keep Thug
			}),
		}),
		n(INNER_WARD, {
			n(83003, {	-- Keep Prisoner
				description = "Chained in the inner ward.",
			}),
			e(3201, {	-- Warden Grim
				creatureID = 83010,	-- Warden Grim
				groups = { i(63010) },	-- Warden's Key
			}),
			e(3202, {	-- Twin Guards
				crs = {
					83011,	-- Twin Guard
					83012,	-- Twin Guard
				},
			}),
		}),
		n(83013, {	-- Kirtonos the Tester
		}),
	},
});
