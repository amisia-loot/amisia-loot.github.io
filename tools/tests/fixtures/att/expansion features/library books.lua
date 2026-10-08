-- hand-made test fixture in the builder language of the Forever data (not real data)
local BOOKS_HEADER = createHeader({
	readable = "Library Books",
	icon = 133739,
	text = { en = "Library Books" },
});
root(ROOTS.ExpansionFeatures, {
	n(BOOKS_HEADER, {	-- Library Books
		aqd = {
			qg = 81501,	-- Fixture Librarian <Librarian>
			coord = { 49.0, 86.4, TEST_CITY },
		},
		hqd = {
			qg = 81502,	-- Other Librarian <Librarian>
			coord = { 73.6, 33.0, TEST_HILLS },
		},
		timeline = { TIMELINE.ADDED_1_60_1 },
		groups = {
			q(78501, {	-- A Dusty Tome
				["provider"] = { "i", 69501 },	-- A Dusty Tome
				["maps"] = { TEST_HILLS },
				["groups"] = {
					i(69500),	-- Fixture Charm
				},
			}),
			q(78502, {	-- An Alliance Tome
				["provider"] = { "i", 69502 },	-- An Alliance Tome
				["maps"] = { TEST_CITY, 1426 },
				["races"] = ALLIANCE_ONLY,
				["groups"] = {
					i(69500),	-- Fixture Charm
				},
			}),
			q(78503, {	-- Friend of the Fixture
				["sourceQuests"] = { 78501, 78502 },
				["sourceQuestNumRequired"] = 2,
				["lvl"] = 20,
				["groups"] = {
					i(69503),	-- Fixture Pendant
				},
			}),
		},
	}),
});
