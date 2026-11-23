-- The professions page's filters in German (the body: tests/prof_filters_body.lua).
PROF_FILTER_TEXTS = {
    knownAll = "Bekannt: Alle", sourceAll = "Quelle: Alle", sourceFavor = "Quelle: Händlergunst",
    knownEntries = "Alle,Bekannt,Unbekannt",
    count5of5 = "5 von 5 Rezepten", count2of5 = "2 von 5 Rezepten", count0of5 = "0 von 5 Rezepten",
    count3of5 = "3 von 5 Rezepten",
    guildAll = "Gilde: Alle", guildHas0 = "Kann jemand (0)", guildNone5 = "Kann niemand (5)", guildHas2 = "Kann jemand (2)",
    guildNone3 = "Kann niemand (3)", guildHasField = "Gilde: Kann jemand (2)", guildHas0Field = "Gilde: Kann jemand (0)",
    guildNobody = "Noch teilt niemand aus der Gilde Rezepte.",
    allOff = 'Erst ohne alle Filter: 5 Rezepte', withoutGuild = 'Ohne "Gilde: Kann jemand": 0 Rezepte', withoutSource = 'Ohne "Quelle: Händlergunst": 0 Rezepte',
    withoutKnown = 'Ohne "Bekannt": 0 Rezepte', withoutSource1 = 'Ohne "Quelle: Händlergunst": 1 Rezept',
    withoutGuild0 = 'Ohne "Gilde: Kann jemand": 0 Rezepte', withoutSearch = 'Ohne "Suche: kupfer": 0 Rezepte',
}
dofile(ADDON_DIR .. "/../tests/prof_filters_body.lua")
