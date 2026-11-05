-- The professions page's filters in German (the body: tests/prof_filters_body.lua).
PROF_FILTER_TEXTS = {
    knownAll = "Bekannt: Alle", sourceAll = "Quelle: Alle", sourceFavor = "Quelle: Händlergunst",
    knownEntries = "Alle,Bekannt,Unbekannt",
    count5of5 = "5 von 5 Rezepten", count2of5 = "2 von 5 Rezepten", count0of5 = "0 von 5 Rezepten",
    guild0 = "Gilde (0)", guild2 = "Gilde (2)", guildNobody = "Noch teilt niemand aus der Gilde Rezepte.",
    withoutGuild = 'Ohne "Gilde": 0 Rezepte', withoutSource = 'Ohne "Quelle: Händlergunst": 0 Rezepte',
    withoutKnown = 'Ohne "Bekannt": 0 Rezepte', withoutSource1 = 'Ohne "Quelle: Händlergunst": 1 Rezept',
    withoutGuild0 = 'Ohne "Gilde": 0 Rezepte', withoutSearch = 'Ohne "Suche: kupfer": 0 Rezepte',
}
dofile(ADDON_DIR .. "/../tests/prof_filters_body.lua")
