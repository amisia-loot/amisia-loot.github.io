-- hand-made test fixture, not real data: recipe sources in a zone
root(ROOTS.Zones, m(MAP.TEST_VALE, {
	n(QUESTS, {
		q(70900, {	-- The Anvil Plan
			qg = 80900,	-- Plan Giver
			coord = { 40.0, 50.0, MAP.TEST_VALE },
			lvl = 20,
			groups = {
				i(273086),	-- Blueprint: Anvil
			},
		}),
	}),
	n(PROFESSIONS, {
		prof(ALCHEMY, {
			n(80800, {	-- Lilyssia <Alchemy Trainer>
				coord = { 41.8, 67.0, MAP.TEST_VALE },
				races = ALLIANCE_ONLY,
			}),
			n(80801, {	-- Yelmak <Alchemy Trainer>
				coord = { 42.0, 68.0, MAP.TEST_VALE },
				races = HORDE_ONLY,
			}),
			n(80802, {	-- Nowhere <Alchemy Trainer> (no place: left out)
				races = HORDE_ONLY,
			}),
		}),
		prof(BLACKSMITHING, {
			n(80803, {	-- Brikk <Blacksmithing Trainer>
				coord = { 20.0, 20.0, MAP.TEST_VALE },
			}),
		}),
	}),
	n(VENDORS, {
		n(80100, {	-- Suppla Smith <Blacksmithing Supplies>
			coord = { 12.5, 33.0, MAP.TEST_VALE },
			groups = {
				i(3609),	-- Plans: Copper Chain Vest
				i(2901),	-- Mining Pick (no recipe)
				i(2880),	-- Weak Flux (a reagent)
			},
		}),
		n(80600, {	-- Tamar <Trade Supplies>
			coord = { 60.0, 40.0, MAP.TEST_VALE },
			races = { ORC, TROLL },
			groups = {
				i(2901),	-- Mining Pick (its other goods only the collector saw)
			},
		}),
		n(80700, {	-- Barterer <Quartermaster>
			coord = { 61.0, 41.0, MAP.TEST_VALE },
			groups = {
				i(2880, {	-- Weak Flux, for copper bars: no gold price
					cost = { { "i", 2840, 2 } },
				}),
			},
		}),
		n(80200, {	-- Gor'mak <Blacksmith>
			coord = { 49.8, 29.6, MAP.TEST_VALE },
			["timeline"] = { TIMELINE.ADDED_1_60_1 },
			["groups"] = BLACKSMITHING_RECIPES.MERCHANTS_FAVOR_RECIPES_HORDE,
		}),
		n(80201, {	-- Hilda <Blacksmith>
			coord = { 50.0, 30.0, MAP.TEST_VALE },
			["timeline"] = { TIMELINE.ADDED_1_60_1 },
			["groups"] = BLACKSMITHING_RECIPES.MERCHANTS_FAVOR_RECIPES_ALLIANCE,
		}),
	}),
	n(80300, {	-- Skyforged Golem
		coord = { 70.0, 70.0, MAP.TEST_VALE },
		groups = {
			i(276928),	-- Plans: Cloudy Skyforged Chainmail
		},
	}),
	n(ZONE_DROPS, {
		i(250388, {	-- Recipe: Elixir of Lesser Intellect
			crs = {
				80400,	-- Vale Ooze
			},
		}),
	}),
}));
