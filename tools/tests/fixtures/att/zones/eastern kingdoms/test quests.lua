-----------------------------------------------------------
-- hand-made test fixture, not real data: class, race and --
-- profession quests the quest build reads               --
-----------------------------------------------------------
root(ROOTS.Character, {
	m(MAP.TEST_HILLS, {
		n(QUESTS, {
			q(72001, {	-- Taming the Fixture
				["qg"] = 82001,	-- Hunter Trainer <Hunter Trainer>
				["coord"] = { 50.0, 50.0, MAP.TEST_HILLS },
				["classes"] = { HUNTER },
				["races"] = { NIGHTELF },
				["lvl"] = 10,
			}),
			q(72002, {	-- Taming the Fixture (2/2)
				["qg"] = 82001,	-- Hunter Trainer
				["sourceQuest"] = 72001,	-- Taming the Fixture
				["classes"] = { HUNTER },
				["races"] = { NIGHTELF },
				["lvl"] = 10,
				["groups"] = {
					i(61090),	-- Taming Gloves
					i(61098),	-- Taming Rod (no gear)
				},
			}),
			q(72003, {	-- Mixing Trouble
				["qg"] = 82002,	-- Alchemist Fixture
				["coord"] = { 55.5, 44.4, MAP.TEST_CITY },
				["requireSkill"] = ALCHEMY,
				["races"] = ALLIANCE_ONLY,
				["lvl"] = 15,
			}),
			q(72004, {	-- Go See the Captain
				["qg"] = 82002,	-- Alchemist Fixture
				["isBreadcrumb"] = true,
				["repeatable"] = true,
				["races"] = { HUMAN, DWARF, NIGHTELF, GNOME },
			}),
			q(72005, {	-- Fight Them
				["altQuests"] = { 72006 },	-- Sneak Past Them
				["qg"] = 82003,	-- Choice Giver
				["coord"] = { 12.0, 34.0, MAP.TEST_HILLS },
				["requireSkill"] = 164,
			}),
			q(72006, {	-- Sneak Past Them
				["altQuests"] = { 72005 },	-- Fight Them
				["qg"] = 82003,	-- Choice Giver
			}),
			q(72007, {	-- After the Choice
				["sourceQuests"] = {
					72005,	-- Fight Them
					72006,	-- Sneak Past Them
				},
				["sourceQuestNumRequired"] = 1,
				["qg"] = 82003,	-- Choice Giver
			}),
		}),
	}),
});
