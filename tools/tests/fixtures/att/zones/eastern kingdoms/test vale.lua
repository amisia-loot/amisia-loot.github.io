---------------------------------------------------
-- hand-made test fixture, not real data: a zone --
-- the way the Forever files write one           --
---------------------------------------------------
maproot(MAP.EASTERN_KINGDOMS, MAP.TEST_HILLS, {
	["groups"] = {
		n(QUESTS, {
			q(71001, {	-- Boar Trouble
				["qg"] = 81001,	-- Farmer Fixture <Farmer>
				["coord"] = { 40.0, 60.0, MAP.TEST_HILLS },
				["races"] = { HUMAN, DWARF },
				["classes"] = { WARRIOR, PALADIN },
				["lvl"] = 6,
				["groups"] = {
					objective(1, {	-- 0/8 Boar Hide
						["provider"] = { "i", 61008 },	-- Boar Hide
					}),
					i(61001),	-- Boar Hide Belt
					i(61002, {	-- Satchel
						["groups"] = { i(61003) },	-- Satchel Ring
					}),
				},
			}),
			q(71002, {	-- Later Quest (After Cataclysm)
				["timeline"] = { ADDED_4_0_3 },
				["qg"] = 81001,	-- Farmer Fixture
				["lvl"] = 6,
				["groups"] = { i(61009) },	-- Later Ring
			}),
			-- #if SEASON_OF_DISCOVERY
			q(71003, {	-- Season Quest
				["lvl"] = 6,
				["groups"] = { i(61010) },	-- Season Ring
			}),
			-- #else
			q(71004, {	-- Forever Quest
				["timeline"] = { TIMELINE.ADDED_1_60_1 },
				["providers"] = { { "o", 91001 } },	-- Odd Crate
				["coords"] = { { 10.0, 10.0, MAP.TEST_HILLS }, { 20.0, 20.0, TEST_CITY } },
				["lvl"] = 7,
			}),
			-- #endif
		}),
		n(RARES, {
			n(81002, {	-- Old Tusk
				["coords"] = { { 30.0, 30.0, MAP.TEST_HILLS }, { 31.0, 31.0, MAP.TEST_HILLS } },
				["groups"] = { i(61004) },	-- Tusk Necklace
			}),
		}),
		n(VENDORS, {
			n(81003, {	-- Smith Fixture <Armorer>
				["coord"] = { 50.0, 40.0, MAP.TEST_HILLS },
				["races"] = HORDE_ONLY,
				["groups"] = { i(61005, { ["isLimited"] = true }) },	-- Iron Helm
			}),
		}),
		n(ZONE_DROPS, {
			i(61006, {	-- Gnoll Axe
				["crs"] = {
					81004,	-- Gnoll Brute
				},
			}),
			i(61007),	-- Random Cloak
		}),
	},
});
