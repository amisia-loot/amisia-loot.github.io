--[[locale enUS]]
-- The professions page's filters on an English client (the body: tests/prof_filters_body.lua), all
-- texts from Locales/enUS_forever.lua.
PROF_FILTER_TEXTS = {
    knownAll = "Known: All", sourceAll = "Source: All", sourceFavor = "Source: Merchant's Favor",
    knownEntries = "All,Known,Unknown",
    count5of5 = "5 of 5 recipes", count2of5 = "2 of 5 recipes", count0of5 = "0 of 5 recipes",
    count3of5 = "3 of 5 recipes",
    guildAll = "Guild: All", guildHas0 = "Someone can (0)", guildNone5 = "Nobody can (5)", guildHas2 = "Someone can (2)",
    guildNone3 = "Nobody can (3)", guildHasField = "Guild: Someone can (2)", guildHas0Field = "Guild: Someone can (0)",
    guildNobody = "Nobody in the guild shares recipes yet.",
    allOff = 'Only without all filters: 5 recipes', withoutGuild = 'Without "Guild: Someone can": 0 recipes', withoutSource = 'Without "Source: Merchant\'s Favor": 0 recipes',
    withoutKnown = 'Without "Known": 0 recipes', withoutSource1 = 'Without "Source: Merchant\'s Favor": 1 recipe',
    withoutGuild0 = 'Without "Guild: Someone can": 0 recipes', withoutSearch = 'Without "Search: kupfer": 0 recipes',
}
dofile(ADDON_DIR .. "/../tests/prof_filters_body.lua")
