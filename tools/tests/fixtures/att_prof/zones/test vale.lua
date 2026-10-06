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
	n(VENDORS, {
		n(80100, {	-- Suppla Smith <Blacksmithing Supplies>
			coord = { 12.5, 33.0, MAP.TEST_VALE },
			groups = {
				i(3609),	-- Plans: Copper Chain Vest
				i(2901),	-- Mining Pick (no recipe)
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
