-------------
-- ALCHEMY --  (hand-made test fixture, not real data)
-------------
ALCHEMY_RECIPES = {
	APPRENTICE = {
		r(2259,	{	-- Alchemy (Apprentice)
			["lvl"] = 5,
			["rank"] = 1,
		}),
		filter(CONSUMABLES, {
			r(2330),	-- Minor Healing Potion
		}),
	};
	MERCHANTS_FAVOR_RECIPES_ALLIANCE = bubbleDownClassicRep(AZEROTH_COMMERCE_AUTHORITY, {
		{	-- Neutral
			i(250388, {	-- Recipe: Elixir of Lesser Intellect (RECIPE!)
				cost = {{ "c", MERCHANTS_FAVOR, 45}},
			}),
		},
	}),
	-- #if NOT ANYCLASSIC
	MERCHANTS_FAVOR_RECIPES_HORDE = bubbleDownClassicRep(DUROTAR_SUPPLY_AND_LOGISTICS, {
		{	-- Neutral
			i(250999, {	-- a branch the Forever build does not see
				cost = {{ "c", MERCHANTS_FAVOR, 1}},
			}),
		},
	}),
	-- #endif
};
