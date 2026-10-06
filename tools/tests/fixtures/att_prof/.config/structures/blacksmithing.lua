-------------------
-- BLACKSMITHING --  (hand-made test fixture, not real data)
-------------------
BLACKSMITHING_RECIPES = {
	APPRENTICE = {
		r(2018, {	-- Blacksmithing (Apprentice)
			["lvl"] = 5,
			["rank"] = 1,
		}),
		n(ARMOR, {
			r(1252229, {["timeline"] = {TIMELINE.ADDED_1_60_1}}),	-- Gemmed Copper Boots
			r(5555, {["timeline"] = {TIMELINE.REMOVED_1_60_1}}),	-- Removed Thing
		}),
		filter(MISC, {
			r(1230171, {["timeline"] = {TIMELINE.ADDED_1_60_1}}),	-- Sharpening Wheel
		}),
	},
	EXPERT = {
		r(3538, {	-- Blacksmithing (Expert)
			["lvl"] = 20,
			["rank"] = 3,
		}),
		n(WEAPONS, {
			r(3491),	-- Big Bronze Knife
		}),
	},
	WEAPONSMITHING = {
		r(9787),	-- Weaponsmith
		r(10011),	-- Blight
	},
	MERCHANTS_FAVOR_RECIPES_ALLIANCE = bubbleDownClassicRep(AZEROTH_COMMERCE_AUTHORITY, {
		{	-- Neutral
			i(271622, {	-- Blacksmithing Certification
				cost = {{ "c", MERCHANTS_FAVOR, 1000 }},
			}),
		}, {	-- Friendly
			i(251358, {	-- Plans: Acolyte's Boots (RECIPE!)
				cost = {{ "c", MERCHANTS_FAVOR, 30 }},
			}),
		},
	}),
	MERCHANTS_FAVOR_RECIPES_HORDE = bubbleDownClassicRep(DUROTAR_SUPPLY_AND_LOGISTICS, {
		{	-- Neutral
			i(271622, {	-- Blacksmithing Certification
				cost = {{ "c", MERCHANTS_FAVOR, 1000 }},
			}),
		}, {	-- Honored
			i(251358, {	-- Plans: Acolyte's Boots (RECIPE!)
				cost = {{ "c", MERCHANTS_FAVOR, 35 }},
			}),
		},
	}),
};
