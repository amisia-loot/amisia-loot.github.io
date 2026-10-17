# Entscheidungen

Die Entscheidungen des Nutzers (und die Regeln, die aus seinen Antworten folgen), gesammelt aus den
Erinnerungen und den Entwürfen unter `docs/superpowers/specs`. Jede steht mit Datum, Grund, Folge
und wie sie gehalten wird. Wer eine Entscheidung ändert, ändert diesen Eintrag im selben Commit
(neues Datum, alter Stand in einem Satz unter "Folge"). Technische Verträge (Nachrichten, Zeilen,
gespeicherte Schlüssel) stehen in [ARCHITECTURE.md](ARCHITECTURE.md).

`tools/tests/test_contracts.py` prüft, dass jeder Eintrag Datum, Entscheidung, Grund, Folge und
"Durchgesetzt durch" (oder "Nicht maschinell geprüft") hat und dass jeder hier genannte Test
existiert.

## D-01 Nur WoW Forever; TBC lebt nur als Archiv der Seite

**Datum:** 2026-10-05
**Entscheidung:** Das Addon zielt nur auf WoW Forever (TOC `## Interface: 16001`). TBC Anniversary
und alle anderen Versionen (Era, Hardcore, SoD, MoP) sind entfernt. Die Seite zeigt nur Forever im
Spielwähler; der TBC-Ledger der Gilde bleibt als schreibgeschütztes Archiv lesbar.
**Grund:** Die Gilde zieht nach Forever (Start 2026-11-04); zwei Clients verdoppelten Arbeit und
Review-Funde.
**Folge:** Nie wieder TBC-/Fremdversions-Code oder -Daten; beim Anfassen geteilten Codes TBC-Zweige
löschen statt halten. Generierte Daten tragen `[AllowLoadGameType camelot]`. `Amisia-Website/data/tbc.js` und Co.
sind nur noch Archiv (kein Neubau).
**Durchgesetzt durch:** `tests/test_forever_only.lua`, `tools/tests/test_data_files.py::test_data_holds_forever_and_the_tbc_archive_only`,
`tools/tests/test_site_archive.py`, `tools/tests/test_contracts.py::test_toc_is_forever_only`,
`tools/tests/test_contracts.py::test_no_tbc_client_left_in_the_addon`.

## D-02 Keine Links auf Fan- und Datenseiten; Wowhead-Itemlinks sind in Ordnung

**Datum:** 2026-10-05
**Entscheidung:** Keine Links auf foreverchanges.pro oder ähnliche Daten-/BiS-Fanseiten, weder im
Addon (auch nicht als kopierbarer Text) noch auf der Website. Wowhead-Itemlinks auf der Seite sind
erlaubt ("auf wowhead führen ist ok").
**Grund:** "ich will keine links"; die Bedingungen dieser Seiten verbieten das Kopieren ihrer
Sammlungen. Amisia baut eigene Daten und Ansichten.
**Folge:** Nie "Mehr Infos"-Links oder Link-outs als Feature vorschlagen. Einzelne Nachschläge von
Hand zur Prüfung sind erlaubt, Übernahme von Daten oder BiS-Listen nicht.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_no_links_to_fan_sites` (erlaubte Hosts:
Wowhead/zamimg und die eigenen Dienste der Seite; in `Amisia/LICENSES/` dazu fsf.org und gnu.org, weil
der GPL-Text unverändert mitgeht), `tools/tests/test_site_wowhead.py`.

## D-03 Nie per Skript von wago.tools, Wowhead oder foreverchanges laden

**Datum:** 2026-10-07
**Entscheidung:** Client-Tabellen kommen nur aus dem eigenen Export des Nutzers
(`tools/export_db2.ps1` auf dem PC, über Syncthing nach `~/addons/_wago`). Kein Skript und kein
Agent lädt von wago.tools, Wowhead oder foreverchanges. Fehlt eine Tabelle: in die Listen von
`tools/export_db2.ps1` eintragen und den Nutzer bitten, es laufen zu lassen.
**Grund:** robots.txt von wago.tools verbietet Bots, Wowhead sperrt Agenten; dem Nutzer wurde
zugesagt, das einzuhalten. Subagenten haben es zweimal (2026-10-06/07) trotzdem getan.
**Folge:** Jeder Subagenten-Auftrag sagt es ausdrücklich. Bekannte Altlasten, die noch Wowhead
abfragen: die Icon-Suche in
`tools/build_scan.py` (seit 2026-10-08 auf Wunsch des Nutzers standardmäßig aus, nur noch mit `--wowhead`); sie ist im Test als Ausnahme benannt und
wird nicht erweitert. wowsrc.com ist eine vom Nutzer akzeptierte Eingabe (D-04), keine dieser Ausnahmen. Das frühere Skript fill_quality (Qualitäten des TBC-Archivs per Wowhead) ist seit 2026-10-08 gelöscht: Forever hat die Qualität aus Scan und `ItemSparse`, das Archiv ist fertig.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_no_tool_fetches_from_the_forbidden_sites`.

## D-04 Lizenzen der Datenquellen

**Datum:** 2026-10-15 (zuerst 2026-10-06)
**Entscheidung:** AllTheThings (MIT) ist freigegeben, mit dem Lizenztext in
`Amisia/LICENSES/AllTheThings-MIT.txt` (in einer Lizenzdatei, nicht in der UI). QuestieDB hat
keine Lizenz und ist entfernt. wowsrc.com, OneForAll und AtlasLoot bleiben Eingaben der Builds
("Ja können wir alles nutzen"; die Lizenzen hat der Nutzer entschieden, nicht geprüft).
Daten, die andere Repos von Wowhead/foreverchanges kopiert haben, sind nicht nutzbar, auch wenn das
Repo MIT ist. Ausnahme seit 2026-10-15: OneForAll 5.x (GPL-3.0-or-later, Lizenztext in
`Amisia/LICENSES/OneForAll-GPL-3.0.txt`) ist ausdrücklich freigegeben ("Nutz OneForAll 5.6.0 als
Quelle"), obwohl seine Quellenliste Wowhead und foreverchanges nennt; genommen werden nur Items mit
Forever-ID (ab 200000) oder einer ID, die der Client kennt (`ItemSparse`, Scan).
Seit 2026-10-16 auch die Orte der Karte (F-105): Flugmeister, Zeppeline und Schiffe aus
`Data/MapLandmarks.lua` und die Eingänge aus `DungeonData.lua`, obwohl OneForAll sie aus QuestieDB
Forever bzw. foreverchanges hat ("OneForAll als Quelle passt").
**Grund:** Lizenztreue; OneForAll füllt Boss-, Trash- und Questbeute der Forever-Dungeons, die
AllTheThings noch nicht hat.
**Folge:** Neue Daten nur aus diesen Quellen; jede generierte Datei nennt im Kopf Generator und
Quellen, jede mit AllTheThings- oder OneForAll-Daten steht in deren Lizenzdatei. Bis 2026-10-15 las
`build_gear.py` OneForAll nur auf dem PC und ohne Filter (das Format vor 5.0); die Classic-Beute
seiner Tabellen bleibt jetzt draußen. Fremde Addons sonst nie nennen (D-05).
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_every_generated_file_names_its_generator_and_sources`,
`tools/tests/test_contracts.py::test_no_questie_data_left`, `tools/tests/test_build_quests.py::test_the_licence_names_every_file_from_allthethings`,
`tools/tests/test_build_gear.py::test_oneforall_keeps_forever_ids_and_what_the_client_knows`.

## D-05 Keine anderen Addons nennen

**Datum:** 2026-10-04
**Entscheidung:** Andere Addons werden in ausgelieferten Texten, Chat, Kommentaren, erzeugten
Dateien und Commits nicht genannt (in Entwürfen heißen sie "andere Loot-/Raid-Addons"). Ausnahme:
eine Datenquelle, deren Lizenz die Nennung verlangt (D-04). Die Notizen zur Konkurrenz liegen außerhalb
des Repos (`~/addons/_research`).
**Grund:** Wunsch des Nutzers seit der Konkurrenzrecherche.
**Folge:** Gargul-Importe der Seite heißen dort weiter so (die Seite liest deren Export); im Addon
nirgends, mit einer Ausnahme:
**Ausnahme (2026-10-11, Spec `docs/specs/2026-10-11-softres-gargul.md`, Frage 1, Vorschlag übernommen):**
"Gargul" und "softres.it" dürfen genau dort stehen, wo der Nutzer sie zum Verstehen braucht: in der
Vorschau und den Meldungen des Soft-Reserve-Imports ("Gargul-Code erkannt: ...", der Fehlertext mit
softres.it's Knopf "Gargul"), in der Markierung des Würfel-Fensters ("Runde von X (Gargul)"), im Hinweis
des Roll-Fensters der Lootleitung ("Gargul-Runde: Gargul sagt den Gewinner an.") und in Kommentaren.
Die Chatmuster (`Raid/RollWatch.lua`) nennen kein Addon. Einstellungen heißen weiter "andere
Loot-Addons". Kein anderes Addon wird genannt.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_other_addons_are_not_named_in_the_addon`
(Liste bekannter Addon-Namen; die Ausnahme `NAMED_HERE` erlaubt "gargul" nur in acht Dateien und dort
nur in Kommentaren und Texten von `L[...]`),
`tools/tests/test_contracts.py::test_the_named_exception_stays_narrow` (Commits nicht maschinell geprüft).

## D-06 Aussehen: klassischer Forever-Stil

**Datum:** 2026-10-06
**Entscheidung:** Fenster wie Forevers Berufsfenster (PortraitFrameTemplate, Porträt oben links,
goldener Titel, rotes Schließen-X), rote Knöpfe (`SharedButtonSmallTemplate`), auch jeder Chip (an:
wie er ist + Goldtext, aus: abgedunkelt + grauer Text). Dropdown- und Pfeilknöpfe aus dem Atlas
`common-dropdown-a-button`. Keine Chips mit dem Filterknopf-Atlas `common-dropdown-b-button` (der
eingebrannte Pfeil sah falsch aus; graue Flachboxen waren "graue kacke"). Zurücksetzen mit
`auctionhouse-ui-filter-redx`. Kein dunkler Balken im Kopf. Talentrechner seit 2026-10-10 (2.19.0)
wie das klassische Talentfenster des Spiels: Baumkopf mittig (Name groß in Gold, "N Punkte" klein,
kein Symbol, keine Stufenspalte), eckige Symbole mit dünnem gezeichnetem eckigem Rahmen
(grau-braun gesperrt, gold-braun erreichbar, grün angefangen, hellgold voll mit weichem Leuchten),
Rang auf dunklem Schild unten rechts, gerade Linien mit den Pfeilspitzen `talents-arrow-head-*`; Maße
und Farben in `ns.Theme.TALENT`. Das ersetzt den runden Rand der Aktionsleiste
(`UI-HUD-ActionBar-IconFrame` mit Maske, 2026-10-07) und die dicken `talents-node-square-*`-Atlanten.
Seit 2026-10-10 (2.20.0) zeichnet ein Baukasten die Talente in zwei Größen: auf der Seite 34-px-Symbole
mit mindestens 8 px zum Rand des Baums (`TALENT.PAGE`), im eigenen Fenster "Talentrechner" 44-px-Symbole
mit mindestens 14 px (`TALENT.BIG`); beide zeigen denselben Plan. Das Fenster skaliert für sich
(Einstellung "Größe des Talentfensters (%)", 70 bis 150, Strg + Mausrad) statt die Seite zu vergrößern.
Seit 2026-10-12 (2.29.0) sieht die Seitenliste links im Hauptfenster aus wie die Kategorienliste des
Auktionshauses: jede Seite ein dunkler Balken mit dünnem Bronzerand (`auctionhouse-nav-button`), der
Name golden (`GameFontNormal`, unter der Maus weiß), die gewählte Seite mit dem hellen Goldrand
(`-select`, additiv), Leuchten unter der Maus (`-highlight`), 21 px hoch ohne Abstand wie im Spiel,
keine Symbole (die Seiten behalten ihre Symbole für andere Stellen). In den Suchergebnissen ist eine
Gruppe ein solcher Balken, ein Treffer der eingerückte Unterbalken (`auctionhouse-nav-button-secondary*`),
ebenfalls ohne Symbol. Die Vorlage `AuctionCategoryButtonTemplate` selbst wird nicht geerbt (sie liegt
im Auktionshaus-Addon, das erst am Auktionshaus lädt); `W.NavBar` baut ihre Atlanten und Maße nach
(`ns.Theme.NAVBAR`). Fehlt ein Atlas, bleibt das Aussehen von vorher (Leuchten der Rezeptliste).
**Grund:** Bildschirmfotos und Wünsche des Nutzers 2026-10-05/06/07; für die Talente das Foto des
klassischen Talentfensters 2026-10-10 ("können wir talente auch so machen") und das Foto von 2.19.0
("können wir das fenster wo die talente sind größer machen oder besser skalieren").
Für die Seitenliste zwei Bildschirmfotos des Nutzers am 2026-10-12 (die Liste und die Kategorienliste
des Auktionshauses: "so soll es aussehen").
**Folge:** Client-Vorlagen und -Atlanten vor eigenen flachen Frames; ein neuer Atlas kommt nur in
`ns.Theme.ATLASES`, wenn er zum Stil passt. Kein `UIDropDownMenu`/`EasyMenu`/`MenuUtil`, keine
Blizzard-Einstellungskategorie, keine fremden Bibliotheken.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_the_forever_look`,
`tools/tests/test_contracts.py::test_no_foreign_libraries_menus_or_combat_log`, die Layoutregeln
(`tools/ui_layout.py`, Atlasliste), `tests/test_style.lua` und für die Talente
`tests/test_talents_page.lua` und `tests/test_talent_window.lua` (Abstände beider Größen), für die
Seitenliste `tests/test_style.lua`, `tests/test_search.lua` und `tests/test_nav_bars_noatlas.lua`.

## D-07 Nur Zeichen, die die Spielschrift hat

**Datum:** 2026-09-14
**Entscheidung:** UI- und Chattexte nutzen nur Zeichen der Spielschrift: Latin-1 mit ä ö ü ß und
"·"; kein Gedankenstrich, keine Auslassungspunkte, keine Pfeile oder Punkte (U+2013, U+2014,
U+2026, Pfeile, U+2022, U+25CF). Symbole sind Texturen.
**Grund:** Die Schrift hat diese Glyphen nicht, sie erscheinen als Kästchen.
**Folge:** Pfeile und Punkte als TGA (`tools/make_icons.py`).
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_no_characters_the_game_font_lacks`.

## D-08 Deutsch und Englisch, die Client-Sprache entscheidet

**Datum:** 2026-10-06
**Entscheidung:** deDE-Clients sehen Deutsch, alle anderen Englisch. Deutsch ist Quelltext und
Schlüssel (`L["..."]`), Englisch steht in `Amisia/Locales/enUS_*.lua`.
Maschinenformate (Export, Nachrichten, gespeicherte Schlüssel) übersetzt man nie.
**Grund:** Wahl des Nutzers aus dem Dungeon-Journal-Vergleich; umgesetzt in 2.9.0.
**Folge:** Neuer Text deutsch in `L[...]` plus englischer Eintrag im passenden Teil; Code-Kommentare
englisch; Texte der Website englisch.
**Durchgesetzt durch:** `tools/l10n.py` (in `build.py check`), `tools/tests/test_l10n.py::test_the_addon_is_translated`,
`tests/test_locale_en.lua`, die englischen Addon-Tests (`run.py --locale enUS`).

## D-09 BiS-Picks heißen "BiS-Empfehlung", nicht Gildenempfehlung

**Datum:** 2026-10-06
**Entscheidung:** Von Hand gesetzte BiS-Picks (`tools/bis_picks.json` -> `ns.BIS.PICK`) tragen das
Abzeichen "BiS-Empfehlung" (Schalter `bis.picks`). Sie sind keine Sache der Gilde und heißen nie
"Gilden-Empfehlung".
**Grund:** Ausdrücklicher Einwand des Nutzers.
**Folge:** Neue Picks aus dem Chat: Eintrag in `tools/bis_picks.json`, `tools/build_bis.py`, Tests,
Release.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_bis_picks_are_a_bis_recommendation_not_a_guild_one`,
`tools/tests/test_build_bis.py::test_the_committed_picks_are_valid`.

## D-10 Rage of the Storm bleibt Pick für 30-34

**Datum:** 2026-10-07
**Entscheidung:** Der Pick 280604 Rage of the Storm (Schamane, Verstärkung, Haupthand) gilt für
Stufe 30 bis 34 und wird nicht auf 36-40 verschoben.
**Grund:** Antwort des Nutzers auf die Frage nach der Questreihe (Luft-Totem-Quest, RFK).
**Folge:** Nur der Nutzer verschiebt ihn.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_rage_of_the_storm_stays_at_30_to_34`.

## D-11 Eigene BiS-Wertung, keine fremden Listen

**Datum:** 2026-10-05
**Entscheidung:** "BiS" ist das Ergebnis von Amisias eigener Wertung über eigene Tabellen. Keine
BiS-Listen oder Loot-Tabellen von Websites; die CC-BY-NC-SA-Gewichte eines Leveling-Guides sind durch
eigene, aus Spielmechanik und Client-Tabellen hergeleitete Gewichte ersetzt. Gewertet wird nur, was
jeder Tooltip zeigt; keine Kampfdaten, nichts im Bosskampf. Dropraten sind gezählte Beobachtungen
der Gilde mit Anzahl der Kills.
**Grund:** Bedingungen der Seiten, Erklärbarkeit, Forevers Linie "anzeigen ja, Verstecktes errechnen
nein".
**Folge:** Python (`tools/build_bis.py`) und Lua (`Gear.lua`) rechnen dieselbe Formel.
**Durchgesetzt durch:** `tools/tests/test_score_parity.py`, `tools/tests/test_build_bis.py`,
`tools/tests/test_contracts.py::test_no_foreign_libraries_menus_or_combat_log` (kein Kampflog).

## D-12 Eigene Daten vor gehörten

**Datum:** 2026-10-06
**Entscheidung:** Im Sammler schlägt ein eigener Wert je Feld immer einen von der Gilde gehörten;
gehörte Daten füllen nur Lücken. Die Builds nehmen eigene Werte oder gehörte, auf die sich mindestens
zwei Konten einigen. Drop-, Quellen- und Rezeptaustausch: nur Gildenmitglieder, leise, gedeckelt,
beide Seiten ziehen, niemand ist maßgeblich; Daten werden vereinigt, nie überschrieben.
**Grund:** Ein gehörter, falscher Satz verdrängte sonst echte Beobachtungen.
**Folge:** Jeder empfangene Satz wird geprüft wie ein gespeicherter.
**Durchgesetzt durch:** `tests/test_collector.lua`, `tests/test_collect_trust.lua`,
`tools/tests/test_collect_records.py::test_the_build_trusts_own_values_and_heard_ones_two_accounts_agree_on`.

## D-13 Wegpunkte und Pins nur aus eigenen (oder bestätigten) Daten

**Datum:** 2026-10-07
**Entscheidung:** Questgeber-Wegpunkte und -Pins kommen aus den Daten oder aus dem, was dieser
Client selbst gesehen hat; nur Gehörtes setzt keinen Wegpunkt.
**Grund:** Wunsch des Nutzers.
**Folge:** Gilt für Quests, Dungeons und Berufe.
**Durchgesetzt durch:** `tests/test_quests.lua`, `tests/test_dungeon_guide.lua`, `tests/test_professions.lua`.

## D-14 Ein laufender Raid behält sein Punktesystem

**Datum:** 2026-10-08
**Entscheidung:** Wird das Lootsystem (Würfeln, DKP, EPGP) umgestellt, behält der laufende Raid das
System, mit dem er begann; erst der nächste Raid nimmt das neue. Würfel-Raids bekommen keine Punkte
nachträglich.
**Grund:** Vom Nutzer bestätigt.
**Folge:** Die Seite ist die Wahrheit der Stände; das Addon liefert nur Neues (PS/PE/PA/PX).
**Durchgesetzt durch:** `tests/test_points_rounds.lua`, `tests/test_points.lua`, `tools/tests/test_points_site.py`.

## D-15 Nur fertige Versionen erreichen das Spiel

**Datum:** 2026-10-04
**Entscheidung:** Syncthing sendet `~/addons/_release/Amisia`, nicht die Arbeitskopie. Nur ein
committeter Stand kommt mit `tools/release_addon.sh` (über `python3 tools/build.py release`) dorthin.
**Grund:** Halbfertiges soll nie im Spiel landen; der Nutzer arbeitet weiter, während der PC aus ist.
**Folge:** Im Spiel `/reload` nach einem Release; neue Dateien oder Texturen brauchen einen
Neustart. Ingame-Tests macht der Nutzer.
**Durchgesetzt durch:** `tools/release_addon.sh` (verweigert ungesicherte Änderungen),
`tools/tests/test_build_tool.py::test_release_refuses`, `tools/tests/test_build_tool.py::test_release_never_bumps_on_a_failed_check`.

## D-16 Die Version steht nur in der TOC

**Datum:** 2026-10-07
**Entscheidung:** `## Version:` in `Amisia/Amisia.toc` ist die einzige Stelle; Core liest sie
beim Laden. Releases nur über `python3 tools/build.py release X.Y.Z`.
**Grund:** Zwei Stellen liefen auseinander.
**Folge:** Keine Versions-Literale im Lua.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_the_version_stands_only_in_the_toc`,
`tools/tests/test_build_tool.py::test_the_repo_toc_has_the_version_and_matches_the_folder`, `tests/test_version_toc.lua`.

## D-17 Exportregel: Bestehendes bleibt Byte für Byte

**Datum:** 2026-10-05
**Entscheidung:** Bestehende Exportzeilen und Felder ändern sich nie; Neues kommt als neue
Zeilenart mit zwei Buchstaben; der Kopf bleibt `#AMISIA 2`. Freitext steht immer als letztes Feld.
Neue Texte (Drops, Wunschliste) sind eigene Texte, nicht Teil des Raid-Exports, damit
`ns.SessionHash` alter Raids gleich bleibt.
**Grund:** Ältere Seiten überspringen unbekannte Zeilen; Exportmarken bleiben gültig.
**Folge:** Addon-Schreiber und Site-Parser ändern sich im selben Commit; jede Zeile hat ihre Zeile in
ARCHITECTURE.md.
**Durchgesetzt durch:** `tools/tests/test_export_format.py::test_every_line_the_addon_writes_is_read`,
`tools/tests/test_contracts.py::test_every_export_line_has_its_row`, `tools/tests/test_contracts.py::test_the_site_reads_what_the_table_says`.

## D-18 Sync: ein Hüter, ganze Abbilder, Vertrauen nur über die Gildenliste

**Datum:** 2026-10-05
**Entscheidung:** Den laufenden Raid hält ein Client, der Hüter (Lootleitung mit Offiziersrang); er
sendet nach jeder Änderung das ganze Abbild mit Stand und Prüfsumme. Andere Offiziere schicken
Änderungswünsche. Vertraut wird nur dem Absender, den der Server setzt, und seinem Rang laut
Gildenliste (Rangrecht "Offiziersrang", Flag 22); Daten von Gildenfremden werden ignoriert, auch
Versionsmeldungen. Offiziersnotizen gehen nur per Flüstern an geprüfte Offiziere. Nur der laufende
Raid wird abgeglichen, Schlüssel `Datum:Instanz`.
**Grund:** Schrittweiser Abgleich zwischen Offizieren ist in anderen Addons auseinandergelaufen.
**Folge:** Was eine Nachricht über ihren Absender sagt, dient nur der Anzeige.
**Durchgesetzt durch:** `tests/test_sync_raid.lua`, `tests/test_sync_terms.lua`, `tests/test_sync_ops.lua`,
`tests/test_trust.lua`, `tools/tests/test_contracts.py::test_every_message_kind_has_its_row_and_no_row_is_left_over`.

## D-19 Nachrichten: zwei Präfixe, nichts in Sperre und Schlachtfeld, kein Dauerfunk

**Datum:** 2026-10-05
**Entscheidung:** Genau zwei Präfixe (`Amisia`, `AmisiaD`), Drosselung pro Präfix selbst
eingehalten, kein Präfixwechsel zum Umgehen. Kanäle nur RAID (eigene Raidgruppe), GUILD, WHISPER;
nie INSTANCE_CHAT. In der Kampfsperre, in Schlachtfeldern und Arenen wird nichts gesendet. In die
Gilde geht eine Versionsmeldung pro Sitzung; Fragen nur auf Knopfdruck (5 Minuten Abstand).
Packen nur mit `C_EncodingUtil` des Clients.
**Grund:** Forevers Sperren und Drosselung; keine fremden Bibliotheken.
**Folge:** Jede neue Nachricht läuft durch `Core/Comm.lua` und bekommt eine Zeile in ARCHITECTURE.md.
**Durchgesetzt durch:** `tests/test_comm.lua`, `tests/test_comm_bus.lua`,
`tools/tests/test_contracts.py::test_two_prefixes_and_one_sender`, `tools/tests/test_contracts.py::test_the_gap_of_every_kind_is_the_documented_one`.

## D-20 Kein Kampflog, keine Kampfdaten

**Datum:** 2026-10-05
**Entscheidung:** Amisia nutzt kein `COMBAT_LOG_EVENT_UNFILTERED`, keine Monster-Rufe, kein
`UNIT_DIED`; Kills kommen aus `ENCOUNTER_START/END`, `BOSS_KILL` und als Rückfall aus dem Lootfenster.
Geheime Werte (Forever) werden über `ns.Plain` erkannt und übersprungen, nie verglichen.
**Grund:** Forever gibt Addons kein Kampflog; Blizzards Linie.
**Folge:** Namen beim Kill werden nach der Sperre gelesen.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_no_foreign_libraries_menus_or_combat_log`, `tests/test_raidlog.lua`.

## D-21 Würfelbereiche und Rangfolge

**Datum:** 2026-09-19
**Entscheidung:** Mainspec `/roll` 1-100, Offspec `/roll 99` 1-99; andere Bereiche gelten nicht,
werden aber gezeigt. Reihenfolge: Reservierung (SR), dann MS, dann OS, dann der Wurf; mit Plus-Eins
weniger MS-Gewinne zuerst unter den MS-Würfen.
**Grund:** Wahl des Nutzers; der Bereich in der Systemmeldung macht jeden Wurf eindeutig.
**Folge:** Gildenwünsche und Loot-Prio ändern die Würfelordnung nicht.
**Durchgesetzt durch:** `tests/test_rolls.lua`, `tests/test_plusone.lua`, `tests/test_guild_wishes.lua`.

## D-22 Plus-Eins zählt nur Mainspec-Gewinne

**Datum:** 2026-10-05
**Entscheidung:** Plus-Eins zählt nur lebende MS-Vergaben an Spieler; SR, OS, Bank und Entzaubern
zählen nicht (SR-Gewinne als +1: bewusst nein). Twinks zählen für ihren Main.
**Grund:** Entscheidung im Vergabe-Baustein (Assistent, vom Nutzer nicht widersprochen).
**Folge:** Das "+1" eines softres.it-Codes (2026-10-11, D-44) ist nur ein Hinweis im Tooltip und
ändert Amisias Zählung nie.
**Durchgesetzt durch:** `tests/test_plusone.lua`, `tests/test_alts.lua`, `tests/test_softres_code.lua`.

## D-23 Zu spät: nur der erste Raid der Nacht zählt; Raidnacht beginnt um 06:00

**Datum:** 2026-09-24
**Entscheidung:** Ein Start vor 06:00 zählt zur Nacht davor. Verspätungen zählen nur im ersten Raid
einer Nacht (Hyjal zuerst, BT danach). Nur die erste Sichtung zählt; wer von der Ersatzbank kommt
(Offizierseintrag oder `!bench` vor der Grenze), ist nie zu spät.
**Grund:** Regel des Nutzers.
**Folge:** Addon und Seite setzen dieselbe Regel um.
**Durchgesetzt durch:** `tests/test_late.lua`, `tests/test_bench.lua`, `tools/tests/test_late_rule.py`.

## D-24 Materialien: gelernt, Maximum statt Summe

**Datum:** 2026-10-05
**Entscheidung:** Die Liste der Gildenmaterialien wird gelernt (alle Handelswaren der Qualitätsstufe,
die in Raids droppen), nicht im Code benannt; Offiziere nehmen Einträge heraus oder fügen hinzu.
Auf der Seite zählt pro Nacht, Raider und Item das Größere aus Vergabe und Addon-Loot, nie die Summe.
Eine Bankzählung schreibt nie Bestandskorrekturen.
**Grund:** Wunsch des Nutzers ("alle Materialien, die in Raids droppen"); Doppelzählung vermeiden.
**Folge:** Materialien gehen nach Hausregel an die Gildenbank und werden nie angesagt.
**Durchgesetzt durch:** `tests/test_mats_learn.lua`, `tests/test_mats_migrate.lua`, `tools/tests/test_site_mats.py`.

## D-25 Keine Spielernamen in Drop-Daten

**Datum:** 2026-10-05
**Entscheidung:** Ein Drop-Satz trägt eine Kennung aus der Leichen-GUID und eine zufällige
Client-Kennung, keinen Spielernamen; Exportzeilen und Seitendaten ebenso.
**Grund:** Datensparsamkeit beim Gildenaustausch.
**Folge:** Der gleiche Kill zählt einmal, egal wie viele ihn sehen.
**Durchgesetzt durch:** `tests/test_drops.lua`, `tools/tests/test_drop_import.py`.

## D-26 Gewünschtes ändert keine Vergaberegel; Loot-Prio und Wünsche kommen von der Seite

**Datum:** 2026-10-05
**Entscheidung:** Gildenwünsche, Loot-Prio und "Wer braucht das?" zeigen Hinweise (Tooltip, "W",
"P1", Reihenfolge im Vergabe-Dialog), ändern aber nie die Würfelordnung. Die Website ist die Quelle
für Wünsche, Twinks, Loot-Prio und Punkte; das Addon bekommt sie als Einfügeblock und schickt eigene
Änderungen als Exportzeilen zurück. "Wer braucht das?" geht nie in den Raidchat.
**Grund:** Offiziere entscheiden; die Seite ist der gemeinsame Ort.
**Folge:** Eingefügter Text ist unvertraut und wird Feld für Feld geprüft.
**Durchgesetzt durch:** `tests/test_guild_wishes.lua`, `tests/test_loot_prio.lua`, `tests/test_need.lua`,
`tools/tests/test_contracts.py::test_paste_in_blocks`.

## D-27 Eine Lootleitung pro Raid, Antworten per Flüstern

**Datum:** 2026-10-05
**Entscheidung:** Genau ein Client sagt Loot an und beantwortet `!sr`/`!bench`: der Plündermeister,
sonst der Schlachtzugsleiter, in Offiziersansicht (`loot.lead = "me"` übernimmt, wenn der Leiter
Amisia nicht hat). Antworten immer per Flüstern an den rohen Absender. Ansagen nur im Schlachtzug,
einmal pro Leiche; Chat nur über `ns.Say`, in der Sperre wird gewartet.
**Grund:** Zwei Offiziere mit Amisia sollen nicht doppelt posten.
**Folge:** Der Nutzer erwartet Master Loot (eine Tausch-Warteschlange ist nicht gewünscht). Ausnahme (2026-10-09, Spec `docs/specs/2026-10-08-loot-abend.md`): ein Handel-Helfer für vergebene Items, die doch in einer Tasche liegen, als Liste mit Knopf, keine Warteschlange für jeden Loot (gebaut als D-39).
**Durchgesetzt durch:** `tests/test_lootannounce.lua`, `tests/test_srchat.lua`, `tests/test_chat.lua`.

## D-28 Daten werden erst bei Bedarf gebaut

**Datum:** 2026-10-07
**Entscheidung:** Große generierte Tabellen liegen beim Login nur als Text vor (`ns.LazyData`) und
werden beim ersten `ns.Data(...)` gebaut; Verfügbarkeitsprüfungen nur über `ns.HasData`/`ns.DataSize`.
**Grund:** Kurzer Login, wenig Speicher für Spieler, die die Seiten nie öffnen.
**Folge:** Neue große Daten über `tools/lua_data.py` `lazy()`; seit 2026-10-08 ohne überflüssige
Leerzeichen (`lua_data.compact`, Zeilen bleiben) und auch die Gewichte (`GEAR_WEIGHTS`).
**Durchgesetzt durch:** `tests/test_lazy_data.lua`, `tools/tests/test_lua_data.py`.

## D-29 Wertung der Ersatzbank und Discord-Text

**Datum:** 2026-10-05
**Entscheidung:** Das Addon exportiert, wer auf der Ersatzbank stand; wie das zählt, entscheidet die
Website (`state.benchMode`, Standard: anwesend). Der Discord-Text entsteht nur im Addon und nur für
Offiziere.
**Grund:** Nur der Plündermeister hat alle Vergaben; die Seite bekommt keinen deutschen Text.
**Folge:** -
**Nicht maschinell geprüft**

## D-30 Der Twin wird nicht mehr gepflegt

**Datum:** 2026-10-06
**Entscheidung:** Die claude.ai-Artefaktkopie der Seite ("Twin") wird nicht mehr gepflegt; die Seite
auf GitHub Pages ist die einzige. Das Artefakt bleibt unangetastet stehen.
**Grund:** "mach was du für richtig hältst".
**Folge:** Keine Twin-Schritte bei Releases; Build-Skript, Stempel und Hook sind entfernt.
**Nicht maschinell geprüft**

## D-31 Arbeitsweise der Agenten

**Datum:** 2026-10-07
**Entscheidung:** Subagenten nur als `opus-medium` (Entwürfe, Umsetzung über mehrere Dateien,
Reviews, Korrekturen) oder `sonnet-medium` (einfache Aufgaben); nie Fable. Lange Aufträge sagen:
"alles selbst, keine Sub-Agenten/Helfer/Workflows". Jeder Auftrag nennt D-03.
**Grund:** Wunsch des Nutzers; verschachtelte Agenten starben mit ihrem Auftraggeber (verlorene
Arbeit, halbe Worktrees).
**Folge:** Commits enden mit `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
**Nicht maschinell geprüft**

## D-32 Gruppen- und Gildentests erst nach dem Start

**Datum:** 2026-10-07
**Entscheidung:** Sync, Master Loot, Würfe, Drop-Austausch, Sammler-Austausch und die Kampfsperre im
Bosskampf werden mit der Gruppe/Gilde erst nach dem Start von WoW Forever (2026-11-04) geprüft; bis
dahin nur Solo-Prüfungen (`/amisia selbsttest`).
**Grund:** Vorher keine Gruppe.
**Folge:** Alles Gruppenbezogene bleibt bis dahin nur im Test-Stub belegt (`tests/run.py`
Mehr-Client-Tests).
**Nicht maschinell geprüft**

## D-33 Die Seite: Sicherheit und Datenschutz

**Datum:** 2026-09-16
**Entscheidung:** E-Mail-Adressen sieht nur der Besitzer, nie ein E-Mail-Rückfall für Anzeigenamen.
Im `onAuthStateChange`-Callback nie auf Supabase warten. `refreshRole` setzt die Rolle erst nach der
Antwort zurück. Wer online ist, läuft über die Tabelle `presence` (Herzschlag), nicht über
Realtime-Presence. Mitgliederdaten stehen nicht im Ledger-JSON.
**Grund:** Datenschutz; Deadlocks und verlorene Speicherungen in der Praxis.
**Folge:** Nach jeder Änderung an `Amisia-Website/data/*.js` `BUILD_ID` in `Amisia-Website/index.html` erhöhen.
**Nachtrag 2026-10-17 (Sicherheitsprüfung):** Wer Besitzer oder Editor ist, entscheidet nur, was ein Konto
nicht selbst ändern kann: die bestätigte E-Mail und die Discord-Identität (Benutzername, Kennung), nie
`user_metadata` (jeder kann sie mit `auth.updateUser` umschreiben) und nie der Discord-Anzeigename
(Migration `20261017_identities_from_providers.sql`). Jeder Wert aus dem Ledger, der in ein HTML-Attribut
kommt, geht durch `esc()`.
**Durchgesetzt durch:** `tools/tests/test_data_files.py::test_build_id_is_new_since_1_9` (BUILD_ID),
`tools/tests/test_site_escape.py` (Attribute); die Identitätsregel ist nicht maschinell geprüft.

## D-34 Scan-Daten leben auf dem N100, das Addon räumt Ausgewertetes weg

**Datum:** 2026-10-08
**Entscheidung:** Was `/amisia scan` und der Item-Sammler liefern (`AmisiaDB.scan`: Itemzeilen,
Quellennotizen, Suffixe), wird auf dem N100 für immer in `tools/scan_archive.json` (im Repo)
gesammelt; jeder Build liest Archiv und SavedVariables zusammen. Das Addon bekommt mit
`Data/ScanDone.lua` eine Markierung dessen, was das Archiv beim Build hatte, und entfernt genau das
einige Sekunden nach dem Login in kleinen Schritten aus `scan.items`, `scan.sources` und
`scan.retry` (dazu IDs, die die Client-Tabelle ItemSparse nicht kennt). Schalter
`tools.scanAutotrim` (Standard an; im Abschnitt Werkzeuge, wo die Scan-Rate steht),
`/amisia scan aufräumen` (en `cleanup`) sofort. Nie wird entfernt, was die Markierung nicht abdeckt:
eine seit dem Build geänderte Zeile (anderer Hash) bleibt; Fortschritt (`next`, `from`, `to`) und
Suffixe (liest Gear.lua im Spiel) bleiben.
**Grund:** Die SavedVariables waren am 2026-10-07 2,3 MB groß und kosteten bei jedem Login etwa
7 MB Lua-Speicher, fast alles Scan-Daten, die das Addon im Spiel nicht braucht.
**Folge:** Das Archiv ist die einzige Kopie getrimmter Daten: committen und pushen. Ein Build ohne
Archiv (`--scan-archive ""`) sieht nach dem Trimmen weniger. Builds geben Items in ID-Reihenfolge
aus, damit getrimmte und volle Datei dieselben Daten bauen.
**Durchgesetzt durch:** `tools/tests/test_scan_archive.py::test_a_build_after_the_trim_gives_the_same_data`,
`tools/tests/test_scan_archive.py::test_absorb_loses_nothing_and_the_file_wins`,
`tools/tests/test_scan_archive.py::test_the_committed_marker_is_current`, `tests/test_scan_trim.lua`.

## D-35 Features mit Status und Prüfungen, Specs vor größeren Features, Fehler aus dem Spiel

**Datum:** 2026-10-08
**Entscheidung:** `docs/FEATURES.md` führt jedes sichtbare Feature von Addon und Seite mit fester
Kennung (F-001 ...), Version, Status (`geplant`, `gebaut`, `im Spiel geprüft (Datum)`, `im Raid bewährt
(Datum)`), Bedarf an Gruppe/Gilde/Raid und ein bis fünf Prüfungen "Wenn ..., dann ...".
`python3 tools/build.py testlist` macht daraus die Testliste für den Nutzer, `build.py release`
zeigt am Ende die Prüfungen der neuen Version (und warnt, wenn kein Eintrag sie trägt),
`build.py tested F-xxx [--raid]` trägt ein Ergebnis mit dem heutigen Datum ein. Größere Features
(neue Nachricht, neuer gespeicherter Schlüssel, neue Exportzeile oder Seite, alles, was andere
Spieler betrifft) bekommen vorher eine kurze Spec in `docs/specs` nach `docs/specs/TEMPLATE.md`;
gebaut wird erst nach "passt". Die Lua-Fehler, die der Fehlerfänger im Spiel sammelt
(`~/addons/_SavedVariables/!BugGrabber.lua`), liest `build.py errors`; `check` und `release`
nennen Amisias Fehler, ohne zu scheitern.
**Grund:** Vom Nutzer gewünscht (2026-10-08, angelehnt an einen spezifikationsgetriebenen
Arbeitsablauf): sich Konzepte und Ideen besser merken, damit beim Ändern nichts kaputt geht; klar
sehen, was gebaut, was im Spiel geprüft und was erst nach dem Start prüfbar ist.
**Folge:** Ein Release ohne FEATURES-Eintrag seiner Version ist erlaubt, aber `release` sagt es.
Nach jedem Release die Testliste an den Nutzer weitergeben. Nur als geprüft eintragen, was der Nutzer
im Spiel bestätigt hat (mit Notiz als Beleg). Eine fehlende Fehlerdatei ist kein Fehler.
**Durchgesetzt durch:** `tools/tests/test_features.py::test_the_real_file_parses_and_every_entry_is_complete`,
`tools/tests/test_features.py::test_versions_are_real_versions`, `tools/tests/test_features.py::test_tested_rewrites_only_the_status_of_the_named_entry`,
`tools/tests/test_contracts.py::test_every_spec_has_the_template_headings`, `tools/tests/test_game_errors.py::test_a_malformed_file_never_crashes`.

## D-36 Vergabe-Verlauf: wer ein Item bekam, sehen alle; Zahlen pro Spieler nur Offiziere

**Datum:** 2026-10-08
**Entscheidung:** Der Tooltip eines Items nennt, wer es in aufgezeichneten Raids bekommen hat
("Vergeben: Fraktur (MS), 09.09.", höchstens drei, neueste zuerst, dann "+N weitere"; Bank und
Entzaubern als solche, ein Twink mit seinem Main, gelöschte und zurückgenommene Vergaben nie), für
jeden, der die Vergaben in seinen Raids hat; Schalter `awards.tooltip` (Standard an) im Abschnitt
Vergaben, der dafür auch Raidern gezeigt wird. Was ein Spieler insgesamt bekam (letzte 4 Wochen wie
die Statistik, MS/OS/SR, letztes Item), zeigt das Roll-Fenster im Tooltip der Zeile, nur in der
Offiziersansicht. Notizen der Vergaben stehen nie im Tooltip.
**Grund:** Wer ein Item bekam, sagt die Lootleitung im Raidchat an, und Raider sehen auf der Seite
Vergaben ohnehin alle Vergaben ihres Raids ("Alle Vergaben"). Die Regel der Statistik ("Die Zahlen
anderer Spieler sehen nur Offiziere") gilt für Zahlen pro Spieler, also für das Roll-Fenster.
Vom Nutzer gewünscht (2026-10-08); die Sichtbarkeit hat der umsetzende Agent nach diesen beiden
Regeln entschieden.
**Folge:** Ein Raider sieht nur, was seine Raids enthalten (über den Abgleich der Lootleitung); ein
Offizier alle Raids, die er aufgezeichnet hat.
**Durchgesetzt durch:** `tests/test_award_history.lua`.

## D-37 Lootregeln: nur der Plündermeister, nie Reserviertes, Priorisiertes oder Gewünschtes; fremde Regeln erst nach Übernehmen

**Datum:** 2026-10-09
**Entscheidung:** Offiziere legen in Einstellungen, Lootregeln eine geordnete Liste von Regeln an
(Qualität bis Ungewöhnlich/Selten, Raidmaterialien oder eine Itemliste an Bank oder Entzauberer; ein
einzelnes, benanntes Item an einen Spieler); die erste passende gilt. Ohne Regeln (frische
Installation) passiert nichts. Modus "Automatisch" (Standard, eine Sekunde nach dem Öffnen der Leiche)
oder "Ein Klick" (Leiste am Lootfenster mit "Verteilen"), Schalter "Pause", `/amisia regeln probe`
sagt nur im eigenen Chat, was passieren würde, und gibt nichts aus. Regeln wirken nur auf dem Client
des Plündermeisters, nur unter Master Loot, im Raid, mit Offiziersrang, Offiziersansicht und
laufender Aufnahme, nie in Kampf oder Kampfsperre (der Lauf wartet auf
`ADDON_RESTRICTION_STATE_CHANGED`). Keine Regel fasst ein Item an, das jemand im Raid reserviert hat,
das eine Loot-Prio hat, auf der Gildenwunschliste eines Raiders steht, eine Upgrade- oder
Wunsch-Antwort bekam, eine Roll- oder Punkterunde hat oder legendär ist; Spieler-Regeln ruhen in
einem DKP-/EPGP-Raid. Reserviert oder wünscht ein Name, den mehrere Raider tragen könnten (nur
Vorname), oder ist ein Name im Raid verborgen, gilt das Item als reserviert bzw. gewünscht. Ist das
Ziel kein Kandidat oder passt es auf mehrere Kandidaten, bleibt das Item liegen und der Chat sagt es
(dieselbe Regel, `ns.LootCandidate` in Awards.lua, gilt seit 2026-10-09 auch für den Vergabe-Dialog
und den Knopf "Vergeben" des Roll-Fensters; der Vergabe-Dialog trägt bei mehrdeutigem Namen auch
nichts von Hand ein, der Plündermeister gibt über das Menü des Spiels, dessen Vergabe Amisia
aufzeichnet: sonst entstünden zwei Vergaben).
Die Loot-Ansage lässt im Modus Automatisch die Items weg, die eine Item- oder Spieler-Regel selbst
verteilt (keine Ansage, keine "Wer braucht das?"-Frage für ein Item, das eine Sekunde später weg
ist); eine Qualitätsregel fasst kein Item an, das die Ansage nennt ("angesagt"). Jede Ausgabe wird
eine normale Vergabe mit der Notiz "Regel: ...", die Lootleitung schreibt eine Zeile in den Raidchat
(abschaltbar), und zwar erst, wenn der Platz im Lootfenster frei wird (LOOT_SLOT_CLEARED); eine
Ausgabe ohne diese Bestätigung binnen 3 Sekunden (Taschen voll, außer Reichweite) steht nicht in der
Zeile, und der Chat des Plündermeisters sagt es. Regeln anderer Offiziere (MR/MQ) sind nur ein Vorschlag, bis jemand
"Übernehmen" klickt; Nachrichten von Nicht-Offizieren oder Gildenfremden werden verworfen.
**Grund:** Spec `docs/specs/2026-10-08-loot-abend.md` (Teil 2), vom Nutzer am 2026-10-09 freigegeben:
automatisch als Standard, beide Modi wählbar; Kleinkram soll ohne Klicks verteilt werden, ohne dass
eine Regel je über ein umkämpftes Item entscheidet.
**Folge:** Keine Regeln nach Klasse, Spec, Plus-Eins oder Würfen, keine ganze Qualitätsstufe an einen
Spieler, keine Regeln von der Website und keine bei Gruppenplündern. Höchstens 30 Regeln, 50 Items pro
Liste, MR in höchstens 4 Teilen, ein Vorschlag pro Offizier alle 30 Sekunden. Seit 2026-10-11 fasst keine
Regel eine Hard-Reserve des softres.it-Codes an (D-44).
**Durchgesetzt durch:** `tests/test_loot_rules.lua`, `tests/test_loot_rules_share.lua`,
`tests/test_loot_rules_review.lua`, `tests/test_award_candidate.lua`,
`tools/tests/test_contracts.py::test_every_message_kind_has_its_row_and_no_row_is_left_over`.

## D-38 Würfel-Fenster: die Zahl nur vom Server, Runden nur von der geprüften Lootleitung

**Datum:** 2026-10-09
**Entscheidung:** Startet die Lootleitung eine Roll- oder Punkterunde, schickt ihr Client `WS` in den
Raid; jeder Raider mit Amisia sieht ein kleines Fenster (Item mit Symbol und Tooltip, die Hinweise
"Reserviert von dir", "Dein Plus-Eins", "Upgrade für dich", "Auf deiner Wunschliste", Zeitbalken) mit
"Mainspec" (`RandomRoll(1, 100)`), "Offspec" (`RandomRoll(1, 99)`) und "Passen", in Punkterunden
einem Zahlenfeld mit "Bieten" bzw. "Bedarf (Preis N)" und "Gier (Preis N)". Die Würfelzahl kommt nur
aus der Systemzeile des Servers, nie aus einer Addon-Nachricht. "Passen", Bedarf, Gier und Gebote
gehen nur als Flüstern (`WA`) an die Lootleitung und zählen dort durch dieselben Funktionen wie
geflüstertes `!pass`, `!need`, `!greed`, `!bid` (gleiche Prüfungen, gleiche Antworten); "Passen"
schreibt nichts in den Chat, wer gepasst hat, darf bis zum Ende noch würfeln; ein Gebot steht (danach
ist "Passen" aus, wie `!pass` in einer Gebotsrunde nichts zurücknimmt). Eine Runde zählt nur
von der Lootleitung mit Offiziersrang in der eigenen Gruppe (dieselbe Prüfung wie bei "Wer braucht
das?"), höchstens eine pro Sekunde und Absender; eine neue Runde ersetzt die laufende, nie zwei
laufende Runden. Mehrere Items stehen untereinander nur so: das Ergebnis der vorigen Runde bleibt
5 Sekunden unter der neuen stehen (höchstens drei Zeilen). Ein Stechen sehen nur die Beteiligten.
Am Ende (`WE`) zeigt das Fenster 5 Sekunden "Gewinner: Anna (95, MS)"; ohne `WE` schließt es
3 Sekunden nach der eigenen Uhr. In der Kampfsperre sind die Knöpfe aus ("Würfeln erst nach dem
Kampf.") bis `ADDON_RESTRICTION_STATE_CHANGED`; ein `WS`, das in der Sperre (oder Drosselung) wartet,
verfällt nach 5 Sekunden (die Uhr der Raider beginnt bei seiner Ankunft und zeigte sonst mehr Zeit, als
die Runde der Lootleitung noch hat).
Das Roll-Fenster der Lootleitung zeigt "passt: N · ohne Antwort: M" (Raider mit Amisia ab dieser
Version). Abschnitt "Würfel-Fenster" (`rollwin`, für alle): an/aus, nur bei Reservierung, Upgrade
oder Wunsch, Ton, auch bei eigenen Runden (Lootleitung), Größe, Position zurücksetzen.
`/amisia wuerfeln test` (en `rolltest`) zeigt eine Proberunde nur bei dir, sendet nichts; die
Würfelknöpfe würfeln wirklich.
**Grund:** Spec `docs/specs/2026-10-08-loot-abend.md` (Teil 3), vom Nutzer am 2026-10-09
freigegeben ("Passen" als Addon-Nachricht, Gebote und Bedarf als Addon-Nachricht, die wie geflüstert
zählt). Raider sollen mit einem Klick im richtigen Bereich würfeln, ohne dass ein verändertes Addon
eine Zahl fälschen oder eine Runde vortäuschen kann.
**Folge:** Kein "immer automatisch Mainspec", keine parallelen Runden, kein Fenster für Gäste
außerhalb der Gilde, in Schlachtfeldern und Arenen; Raider ohne Amisia würfeln weiter mit `/roll`, die
Ansage im Raidchat bleibt. Gespeichert wird nur die Position (`settings.rollWindow`). Seit 2026-10-11
öffnet auch eine Runde, die die Lootleitung mit Gargul startet, das Fenster (D-44, aus dem Chat, kein
`WS`); eine Amisia-Runde geht vor.
**Durchgesetzt durch:** `tests/test_roll_window.lua`, `tests/test_roll_window_raid.lua`,
`tests/test_roll_window_names.lua`, `tests/test_roll_window_review.lua`,
`tools/tests/test_contracts.py::test_every_message_kind_has_its_row_and_no_row_is_left_over`.

## D-39 Handel-Helfer: nur Ausnahmen, Einlegen nur per Klick, der Vermerk bleibt beim Spieler

**Datum:** 2026-10-09
**Entscheidung:** Liegt in den eigenen Taschen eine noch handelbare Kopie eines Items, das in einem
Raid der letzten zwei Stunden (eigenes Buch oder vom Hüter abgeglichen) an jemand anderen vergeben ist
(Spieler, Bank oder Entzauberer), steht es unter "Noch zu übergeben" (oben auf der Seite Vergaben,
`/amisia uebergabe`, en `handover`), kürzeste Restzeit zuerst. Nicht dazu zählen: Vergaben an einen
selbst (so viele Kopien bleiben außen vor), Vergaben, deren Empfänger das Item laut Lootzeile schon
per Master Loot bekam, und Items ohne Vergabe. Die Restzeit kommt aus der Tooltipzeile
TradeTimeRemaining (Typ 36), gelesen über die Textvorlage `BIND_TRADE_TIME_REMAINING` (deutsche und
englische Einheiten); ohne Zeile steht "Handelszeit unbekannt" und es gibt keine Warnung (keine
Schätzung "Erhalt plus 2 Stunden", anders als der Entwurf der Spec). Warnungen nur im eigenen Chat,
mit Ton, bei 30 und 10 Minuten, je einmal (Abschnitt `trade`: an/aus, 30 und 10 / nur 10 / aus,
Ton). Eine Kopie, deren Zeit abläuft, meldet der Chat einmal ("Nicht mehr handelbar") und sie
verschwindet aus der Liste (statt rot stehen zu bleiben). Kopien werden über ihre Item-GUID verfolgt
(ein Umzug zwischen Taschen behält den Eintrag), ohne GUID über Tasche und Platz. Handelt der
Empfänger (Name vom Spiel, `UnitName("NPC")`; ein Vorname allein nur, wenn ihn im Raid nur einer
trägt) mit einem, steht neben dem Handelsfenster "Amisia: N Items einlegen"; erst ein Klick legt die
Items in freie Plätze (höchstens 6), nie im Kampf und nie, solange die Maus etwas hält; "Handeln"
drückt der Spieler. Nach dem Handel gilt als übergeben, was die Taschen verlassen hat (die Meldung
"Handel abgeschlossen" bzw. ihr Nachrichtentyp beschleunigt nur, ein abgebrochener Handel ändert
nichts, eine geheime Meldung stört nicht); ging es an jemand anderen, sagt der Chat es und die Vergabe
bleibt. Gespeichert wird nur der Vermerk (`AmisiaDB.handover`, 3 Tage, höchstens 200); er geht an
niemanden.
**Grund:** Spec `docs/specs/2026-10-08-loot-abend.md` (Teil 1), vom Nutzer am 2026-10-09 freigegeben:
nur für Ausnahmen unter Master Loot (Ausnahme zu D-27), Einlegen per Knopf, im Kampf nichts. Ob Forever
die 2 Stunden Handelszeit kennt und ob Einlegen ohne Klick ginge (Spec-Fragen 10 und 11), ist erst mit
einer Gruppe prüfbar (D-32); deshalb gibt es "automatisch" nicht.
**Folge:** Keine Warteschlange, kein Tausch für persönliches Plündern, keine Nachricht an andere
Spieler, kein Vermerk auf der Website. Zwei gleiche Items in den Taschen kann Amisia nicht
unterscheiden: es ordnet sie den Vergaben in Zeitfolge zu; nach dem Handel zählt deshalb die Anzahl
(Review 2026-10-09): die Kopien eines Items, die gingen, erfüllen zuerst die Vergaben an den
Handelspartner, und eine Vergabe, deren Kopie stattdessen ging, behält die gebliebene. Von einem
Stapel legt der Knopf nur eines ein (geteilt); übergeben ist es, wenn der Stapel kleiner wurde. Ein
Klick merkt sich die Handelsplätze, die er schon belegt hat (das Spiel meldet sie erst nach dem
Server), und zählt nur, was die Maus wirklich aufgenommen hat.
**Durchgesetzt durch:** `tests/test_handover.lua`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.

## D-40 Einrichtungshilfe: nur bestehende Einstellungen, jede Änderung sofort, nichts ohne Klick

**Datum:** 2026-10-10
**Entscheidung:** `/amisia einrichten` (en `setup`) öffnet für Offiziere (Offiziersrang oder
Offiziersansicht) das Fenster "Amisia einrichten" mit sechs Schritten: Bank-Charakter und Entzauberer
(`awards.bankName`, `awards.deName`; Gruppe und Gilde online zur Auswahl, "Anderer Name", "Mich
eintragen"), Lootleitung (`loot.lead`, D-27), Lootart (`points.system`; bei DKP `points.dkpMode`,
`points.minBid`, `points.price`, bei EPGP `points.gpBase`, `points.gpScale`, `points.minEp`),
Roll-Dauer (`rolls.seconds`, `rolls.countdown`), erste Lootregeln (die Vorlagen "Grünes zum
Entzaubern", "Grünes und Blaues zum Entzaubern", "Raidmaterialien an die Bank" über `ns.AddLootRule`,
dazu `lootrules.mode`) und eine Zusammenfassung mit "Ändern" je Zeile. Die Hilfe schreibt nur
bestehende Einstellungen, jede sofort über `ns.Set` (Prüfung und onChange wie auf der Seite
Einstellungen); "Weiter", "Überspringen" und "Zurück" schreiben nichts, jeder Schritt lässt sich
überspringen, beim erneuten Öffnen stehen die aktuellen Werte da. Eine Vorlage legt ihre Regel nur
einmal an (ein zweiter Klick sagt "Diese Regel gibt es schon."); die Raidmaterialien-Regel rückt vor
die Qualitätsregeln, damit kein grünes oder blaues Material beim Entzauberer landet. Einem Offizier
ohne Erledigt- und Nie-Vermerk bietet Amisia die Hilfe einmal pro Login beim ersten Öffnen des
Hauptfensters an ("Amisia einrichten? Ein paar Schritte vor dem ersten Raid." mit "Los", "Später",
"Nicht mehr fragen"); "Später" fragt beim nächsten Login wieder, "Nicht mehr fragen" und "Fertig"
nie mehr. Raider ohne Offiziersrang bekommen nur die Zeile "Die Einrichtung ist für Offiziere. Für
dich: Einstellungen, Würfel-Fenster."
**Grund:** Vom Nutzer am 2026-10-10 freigegeben (Einrichtungshilfe für den Gildenstart): neue
Offiziere sollen vor dem ersten Raid die wichtigen Einstellungen finden, ohne dass es zwei Stellen
für eine Einstellung gibt.
**Folge:** Keine eigenen Einstellungen der Hilfe, keine Vorgaben, die ohne Klick etwas anlegen.
Gespeichert wird nur `AmisiaDB.setup = { done, never }` (Zeitpunkte). Neue wichtige Einstellungen
kommen als weiterer Schritt oder Zeile dazu, nicht als Kopie.
**Durchgesetzt durch:** `tests/test_setup.lua`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.

## D-41 Raid-Aufstellung: nur Offiziere, eingefügter Text unvertraut, einladen per Klick (oder auf Flüstern mit Einstellung), nie Kicks

**Datum:** 2026-10-10
**Entscheidung:** Die Seite "Aufstellung" (Gruppe Raid, `/amisia aufstellung`, en `lineup`) und ihr
Einstellungsabschnitt "Raid-Aufstellung" gibt es nur in der Offiziersansicht und nur mit Offiziersrang
laut Gildenliste (Rangrecht 22, D-18). Ein Offizier fügt die Anmeldeliste einer Raidnacht ein: den
Block `#AMISIA-RAID` (von Hand, die Website schreibt ihn nicht), Zeilen "Name Rolle" oder den Text
eines Anmelde-Bots aus Discord (Überschriften, Emoji-Codes, Nummern, Zeiten; deutsche und englische
Rollen- und Klassenwörter). Amisia gleicht jeden Namen ab (gemerkte Korrektur, genau, ohne Groß/klein
und Umlaute, eindeutiger Vorname "vermutlich", ein Buchstabe anders "vermutlich", zwei Gleichnamige
"nicht eindeutig", "unbekannt", "Gast" außerhalb der Gilde) und rät fehlende Rollen aus der letzten
Aufstellung, sonst aus der Klasse (grau mit "?"). "Automatisch einteilen" folgt einfachen Regeln: Tanks
ab Gruppe 1, ein Heiler pro Gruppe (Schamanen und Paladine zu Nahkampf-, Priester und Druiden zu
Fernkampf-Gruppen, übrige Heiler zu den Tanks), Nahkampf zusammen mit je einem Krieger oder Schamanen,
Fernkampf zusammen; bei mehr Anmeldungen als Plätzen erst Tanks und Heiler (bis jede Gruppe einen hat),
dann die Reihenfolge der Liste, der Rest "überzählig" auf Ersatz. Festgehaltene bleiben stehen; "Ersatz"
aus der Liste oder vom Offizier bleibt Ersatz. Eingeteilt wird jede Anmeldung außer Abgemeldeten;
Gäste nur mit der Einstellung "Gäste einladen" (Standard aus). Unklare und unbekannte Namen werden mit
eingeteilt (der Planer geht so auch ohne Gildenliste) und stehen orange bzw. rot da, bis der Offizier
sie klärt; auf die Ersatzbank kommen sie nicht. "Ersatz auf die Ersatzbank" trägt "Ersatz" und Überzählige, die online sind, über
`ns.BenchAdd` mit der Notiz "Aufstellung" auf die Ersatzbank des Abends (nur für heute; nicht
Abgemeldete, Offline, Unklare); automatisch beim Start der Aufnahme nur mit der Einstellung (Standard
aus). Gespeichert pro Raidnacht (ab 06:00, D-23) in `AmisiaDB.lineup`, 8 Nächte, 80 Namen pro Nacht.
Namenskorrekturen teilen sich die Liste `srAliases` mit den Soft-Reserves (eine Wahl zwischen zwei
Gleichnamigen wird nicht gemerkt).
**Grund:** Spec `docs/specs/2026-10-10-raid-aufstellung.md`, vom Nutzer am 2026-10-10 freigegeben ("ja
passt so"): Flüstern beim Einladen Standard aus mit festem Text, Gäste nur mit Einstellung, die
Einteilungsregeln wie beschrieben, zuerst die allein prüfbaren Teile A, B und E. Kein eigener Bot und
kein Anmelde-Reiter auf der Website (Teil F entfällt).
**Folge:** Gebaut sind die Teile A, B und E (2.22.0) und seit 2.30.0 die Teile C und D (Einladen,
Sortieren) mit ihren Einstellungen `lineup.whisper` und `lineup.autoSort`; die Regeln dafür stehen in
D-47. Geändert am 2026-10-12 (Nutzer): Einladen auf Flüstern "inv" (`lineup.inv`, Standard aus) und
der automatische Assistent für Offiziere (`lineup.autoAssist`, Standard aus) kommen dazu; vorher galt
"kein Einladen auf Flüstern, keine Beförderung zum Assistenten". Nie Kicks, kein Leiterwechsel. Die Teile A bis E senden und empfangen keine Addon-Nachrichten
(die Anmeldungen aus Amisia und der Kalender kamen 2026-10-10 als Teile G und H dazu, D-42), keine neue
Exportzeile; eingefügter Text ist unvertraut (D-26: Codes und Striche entfernt, 200 Bytes pro Zeile,
2000 Zeilen, Namen ohne Ziffern und Steuerzeichen, 48 Zeichen). Die Website schreibt `#AMISIA-RAID`
nicht; der Vertragstest kennt dafür die Ausnahme "liest nur das Addon".
**Durchgesetzt durch:** `tests/test_lineup.lua`, `tests/test_lineup_page.lua`, `tests/test_lineup_invite.lua`,
`tools/tests/test_contracts.py::test_paste_in_blocks`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.

## D-42 Anmelden in Amisia und Kalender: nur für sich selbst, nur Gildenmitglieder, der Offizier-Teil liest nur

**Datum:** 2026-10-10 (geändert 2026-10-11: die Teilnehmerliste sieht die ganze Gilde, D-43; Teil H3 gebaut)
**Entscheidung:** Teil G und H der Spec `docs/specs/2026-10-10-raid-aufstellung.md`. **Kalender (Teil G):**
Auf der Seite Aufstellung zeigt "Kalender" die Gildenereignisse (`GUILD_EVENT`) der Raidnacht von heute
bis 14 Tage voraus, jede Art (die Art "Schlachtzug" verlangt in Forever eine Raid-Instanz; Prüfung 17 im
Spiel), das nächste der Art Schlachtzug gewählt, sonst das nächste. "Übernehmen" liest die Teilnehmerliste
in die Aufstellung der Nacht des Ereignisses (vor 06:00 die Nacht davor, D-23): das Ereignis wird geöffnet
(`OpenEvent` mit `offsetMonths`), gelesen nach `CALENDAR_OPEN_EVENT` (`CALENDAR_UPDATE_INVITE_LIST`
zählt auch) und danach immer geschlossen; nie, solange das Kalenderfenster des Spiels ein anderes
Ereignis zeigt (zeigt es genau dieses, liest Amisia es und lässt es offen), nie im Kampf; ohne Antwort
nach 10 Sekunden "Kalender antwortet nicht, gleich nochmal". Status: angemeldet/verfügbar
"angemeldet", bestätigt "bestätigt", vorläufig "vorläufig", Ersatz auf die Ersatzbank, abgesagt/raus
"abgemeldet", eingeladen und ohne Antwort grau unten, nicht eingeteilt. Solange die Seite offen ist,
liest Amisia das Ereignis der Nacht bei jeder Änderung im Kalender neu (höchstens alle 5 Sekunden, eine
Änderung bis 3 Sekunden nach dem eigenen Lesen gilt als dessen Echo) und fragt alle 30 Sekunden den
Kalender neu an; gelöscht oder verschoben: "Ereignis nicht mehr im Kalender", die Zeilen bleiben.
**Anmelden (Teil H):** Raider sehen auf der Karte "Raid-Anmeldung" (Übersicht, für alle) die nächsten
drei Termine mit der eigenen Anmeldung ("noch offen"), das Fenster "Raid-Anmeldung" hat Anmelden,
Vorläufig, Abmelden, die Rolle T/H/N/F (vorgewählt die letzte eigene, sonst aus der Klasse) und eine
Notiz (40 Bytes, ohne Farbcodes, Links, Striche, Tabulator, Steuerzeichen; "Für alle Offiziere
sichtbar."); `/amisia anmelden` (en `signup`; ein Rollenbuchstabe mit Notiz), `/amisia abmelden` (en `signoff`). Gespeichert
pro Charakter (`AmisiaDB.signup`, 4 Nächte, 12 Charaktere), gesendet als `AN` an die Gilde, beim Klick
und einmal nach dem Login (nicht innerhalb von 30 Minuten, auch nicht nach `/reload`); ein Offizier
fragt einmal nach dem Login (`AQ`), Raider antworten per Flüstern, nur einem geprüften Offizier, einmal
in 10 Minuten, höchstens 4 Nachrichten. Der Offizier nimmt `AN` nur von Gildenmitgliedern (der Name
ist der Absender des Servers, nie ein Feld), nur für heute bis 14 Tage, 4 Nächte pro Absender, 80 Namen
pro Nacht, nur in der Offiziersansicht mit Offiziersrang und `lineup.signups` (an). Eigene Charaktere
desselben Kontos übernimmt er ohne Nachricht aus `AmisiaDB.signup`. Meldet sich ein Eingeteilter ab,
kommt er aus der Gruppe (ein Festgehaltener bleibt, rot) und der Offizier bekommt eine Chatzeile.
**Welche Angabe gilt:** eine Zeile pro Name mit allen Quellen (L Liste, K Kalender, A Amisia); was der
Offizier von Hand macht (Gruppe, Festhalten, Ersatz, Rolle), bleibt; der Status ist die neueste Angabe
des Spielers: Amisia mit der Zeit des Klicks, der Kalender mit der Zeit, zu der Amisia einen
Statuswechsel sah (`EventGetInviteResponseTime` gibt in Forever nil, Prüfung 20); ein zum ersten Mal
gesehener Kalender-Status ist älter als jeder Amisia-Klick, eine eingefügte Liste älter als beide;
liegen Amisia und Kalender unter 2 Minuten auseinander, gilt Amisia. Rolle: Offizier vor Amisia vor
Liste vor letzter Aufstellung vor Klasse (geraten). Ein vom Offizier entfernter Name kommt nur mit einer
neuen Angabe zurück (neuer Klick, anderer Kalender-Status). Nachtrag 2026-10-10 (Prüfung nach dem Bau): die
Klicks eines Absenders ordnet seine eigene Uhr (eine Wiederholung trägt die Zeit des ersten Klicks und
ist kein neuer Klick, auch bei einer vorgehenden Uhr); eine Anmeldung legt keine neunte Nacht an, wenn
dafür heute oder eine kommende Nacht aus den 8 gespeicherten fiele; zwei `AN` für dieselbe Nacht gehen
mindestens 11 Sekunden auseinander (der Offizier verwirft eine zweite innerhalb von 10 Sekunden);
ein in der Wartezeit geöffnetes anderes Ereignis (Kalenderfenster, Prüfung) wird nicht gelesen, und die
Kalender-Prüfung startet nicht, während die Aufstellung ein Ereignis liest. Abmelden per Befehl
nur noch `/amisia abmelden` (en `signoff`); die Unterwörter `anmelden ab`/`off` entfallen (Nutzer).
**Grund:** Spec-Teile G und H, vom Nutzer am 2026-10-10 freigegeben ("ja": Kalender einzige
Terminquelle, `AT` nur falls nötig, Raider sehen keine Teilnehmerliste, keine Chat-Erinnerung beim
Login, die übrigen Fragen nach den Vorschlägen); Prüfungen 17 bis 20 im Spiel am 2026-10-10 21:37
(Gildenereignisse lesbar, `offsetMonths`, `OpenEvent` aus einem Timer ohne Sperre, nur
`CALENDAR_OPEN_EVENT`, Namen mit Nachnamen, keine Antwortzeit).
**Folge:** Amisia schreibt nie in den Kalender des Offiziers (kein Einladen, kein Status, kein Ereignis
anlegen, ändern oder löschen). Das Eintragen des Spielers selbst in den Spielkalender (Teil H3) ist seit 2026-10-11 gebaut
(siehe oben). Kein `AT` (Raidtermin in Amisia), keine Erinnerung im Chat, die Notiz nie in einem Chat oder im Export. Die Einstellung "Alle Arten
von Gildenereignissen zeigen" (`lineup.calendarAll`) der Spec entfällt: es zählt ohnehin jede Art. Der
Kalender-Lesecode ist einer (`Raid/Calendar.lua`) für Aufstellung, Anmeldung und die Kalender-Prüfung.
Alter Stand bis 2026-10-11: "keine Teilnehmerliste für Raider" (Frage 30); seitdem sieht jeder in der
Gilde die Liste im Fenster "Raid-Kalender" (D-43), und jeder Client behält die empfangenen `AN`.
Die Schreibprüfung `/amisia selbsttest kalender schreiben` (Prüfungen 23 bis 25, 2026-10-11) schreibt
nur nach Warnung im Chat und "Ausführen" im Fragefenster, nur für den eigenen Charakter, nur bei einem
Gildenereignis mit Anmeldung (nie bei einer normalen Einladung: Entfernen nähme sie weg), nie bei einem
selbst angelegten Ereignis, und stellt danach den alten Stand wieder her (die letzten 3 der 24 Schreibvorgänge
bleiben dafür frei).
**Teil H3 (2026-10-11):** Der Klick auf Anmelden / Vorläufig / Abmelden (und `/amisia anmelden`,
`/amisia abmelden`) trägt den Spieler bei einem Gildenereignis mit Anmeldung auch im Spielkalender ein,
mit den Aufrufen des Spiels selbst (Anmelden: Kontextmenü-Anmeldung im Klick, aus "vorläufig" erst
Entfernen; Vorläufig: `EventTentative`, aus "angemeldet" erst `RemoveEvent`; Abmelden: `RemoveEvent`),
Einstellung `signup.calendar` (an). Danach liest Amisia den eigenen Status neu; blockiert,
Kalenderfehler oder kein neuer Stand: "Bitte auch im Kalender eintragen." mit "Kalender öffnen" und
einmal der Grund im Chat. Nie für andere, nie im Kampf, nie bei offenem Kalenderfenster, nie beim
eigenen Ereignis (Ersteller), nie aus einer Wiederholung (`AN` nach dem Login, Antwort auf `AQ`), nie
erneut aus einem Timer. Nachtrag 2026-10-11 (Prüfung nach dem Bau): nie, solange eine Kalender-Prüfung läuft;
nie, wenn der Kalender nicht sagt, wer das Ereignis angelegt hat, oder den eigenen Stand nicht nennt; das
Tagesereignis muss die Kennung des Ereignisses tragen, und vor jedem Aufruf am geöffneten Ereignis prüft
Amisia Titel, Beginn und Anmeldung und dass das Kalenderfenster zu ist (sonst wird nichts aufgerufen).
Anmelden und Vorläufig schreiben nur aus "nicht angemeldet" (7) und zwischen angemeldet (6) und vorläufig (8),
wie die Knöpfe des Spiels; hat ein Offizier den Stand gesetzt (eingeladen, abgesagt, bestätigt, raus, Ersatz),
bleibt er ("Spielkalender: ein Offizier hat deinen Stand gesetzt (...), dort bleibt er."); Abmelden aus
bestätigt/Ersatz ist Entfernen (das Spiel bietet es dort an). Nie bei einem Ereignis eines vergangenen
Kalendertags (auch nicht in der Raidnacht nach 00:00). Die Schreibprüfung startet nicht aus einem vom Offizier
gesetzten Stand (eingeladen, bestätigt, raus, Ersatz). Alter Stand bis 2026-10-11: H3 wartete, das Fenster zeigte den Hinweis immer.
**Durchgesetzt durch:** `tests/test_calendar_lineup.lua`, `tests/test_signup.lua`,
`tests/test_signup_comm.lua`, `tests/test_selftest_calendar.lua`, `tests/test_selftest_calendar_write.lua`, `tests/test_signup_calendar.lua`,
`tests/test_calendar_write_review.lua`, `tests/test_calendar_write_officer.lua`,
`tools/tests/test_contracts.py::test_every_message_kind_has_its_row_and_no_row_is_left_over`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.

## D-43 Raid-Kalender: alle in der Gilde sehen, wer kommt

**Datum:** 2026-10-11 (Nachtrag 2.25.1, 2026-10-11: Ebene und Aussehen)
**Entscheidung:** Teil I der Spec `docs/specs/2026-10-10-raid-aufstellung.md`. Das Fenster "Raid-Kalender"
(`/amisia kalender`, en `calendar`; Knopf "Kalender" auf der Karte "Raid-Anmeldung" und im Fenster
"Raid-Anmeldung") zeigt **jedem in der Gilde** links die Termine der nächsten 14 Tage (Gildenereignisse
aus dem Spielkalender) und rechts die Teilnehmer des gewählten Termins in den Gruppen "Angemeldet /
Bestätigt", "Vorläufig", "Ersatz", "Abgemeldet", "Ohne Antwort" (Zahl im Kopf), je Zeile Rolle (grau "?"
wenn geraten), Name in Klassenfarbe, Stufe, Quellen (K Kalender, A Amisia) und Notiz (ganz im Tooltip),
darüber die Zahl der Angemeldeten je Rolle (seit 2.25.1 als Abzeichen mit den Rollen-Symbolen der
Gruppensuche, dazu die Summen je Status). Die Daten: die Teilnehmerliste des
Ereignisses (gelesen wie in Teil G: nie, solange das Kalenderfenster ein anderes Ereignis zeigt, immer
`CloseEvent`, nicht im Kampf; neu bei Änderungen höchstens alle 5 Sekunden und alle 30 Sekunden, solange
das Fenster offen ist) und die Anmeldungen aus Amisia, die **jeder Client** jetzt behält: empfangene
`AN` von Gildenmitgliedern (`AmisiaDB.signup.seen`: heute bis 14 Tage, 4 Nächte pro Absender, 80 Namen
pro Nacht, beim Laden gekürzt) und die eigenen Charaktere des Kontos. Welche Angabe gilt, entscheidet
dieselbe Funktion wie in der Aufstellung (`ns.LineupResolve`). Offiziere haben zusätzlich "Zur
Aufstellung". `AQ` bleibt bei den Offizieren, keine neue Nachrichtenart.
**Grund:** Nutzer am 2026-10-11 nach dem Test im Spiel: "Teil I", alle in der Gilde sehen die Liste mit
Rolle und Notiz (der Spielkalender zeigt die Teilnehmer ohnehin, die Notizen gehen schon an die ganze
Gilde, "Für die Gilde lesbar.").
**Folge:** Frage 30 der Spec ist geändert (D-42 nennt den alten Stand). Ein Raider sieht nur, was sein
Client empfangen hat: wer sich anmeldete, während er offline war, fehlt ihm bis zur Wiederholung beim
nächsten Login des anderen (keine neue Nachricht, kein `AQ` für Raider). Das Fenster schreibt nichts in
den Kalender. Seine Position steht in `settings.calendarWindow`; "Fensterposition zurücksetzen" setzt
sie zurück.
**Nachtrag 2.25.1 (Nutzer 2026-10-11: "1 ebene höher", "hübscher übersichtlicher professioneller"):**
Der Raid-Kalender und das Fenster "Raid-Anmeldung" stehen in der Ebene des Hauptfensters (`FULLSCREEN`,
über der Weltkarte wie das Hauptfenster), sind oberste Fenster ihrer Ebene und kommen beim Öffnen, beim
erneuten Öffnen und beim Klick nach vorn; die Frage (`W.Confirm`) steht eine Ebene höher
(`FULLSCREEN_DIALOG`) über allem, was Amisia zeigt. Aussehen wie das Berufsfenster: Termine links in
einem Einsatz mit dem Grund der Rezeptliste (Tag groß, Uhrzeit, Titel, eigener Stand als farbiges
Abzeichen, Auswahl mit dem Leuchten der Rezeptliste), rechts ein Einsatz mit Kopf (Symbol der
Ereignisart, Titel groß in Gold, Datumszeile, Rollen-Abzeichen, Summen je Status), Spaltenköpfen und den
Gruppen als Abschnittsleisten; Rollen- und Klassensymbole sind Atlanten der Gruppensuche des Spiels
(`groupfinder-icon-role-large-*`, `groupfinder-icon-class-*`, in der Erlaubnisliste von `UI/Theme.lua`).
Die Zeile unten sagt "Kalender wird gelesen ..." nur, solange gelesen wird; ein Termin ohne Kennung
wird auch gelesen (nach Zeit und Titel), ein belegter Kalender sagt es nach 8 Sekunden, und ein Öffnen
ohne Antwort hält den Kalender höchstens `Cal.WAIT` + 5 Sekunden belegt.
**Durchgesetzt durch:** `tests/test_raid_calendar.lua`, `tests/test_raid_calendar_read.lua`, `tests/test_signup_comm.lua`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.

## D-44 softres.it-Code und Gargul-Runden: lesen, nie senden; wer startet, entscheidet

**Datum:** 2026-10-11
**Entscheidung:** Spec `docs/specs/2026-10-11-softres-gargul.md`, Teile A2, B1 und B4 (B2 erst bei
Bedarf, B3 nicht).
**A2:** Der Soft-Reserve-Import (Fenster "Soft-Reserves" und `/amisia sr <Code>`) liest den Code von
softres.it (Knopf "Gargul"): Base64, `C_EncodingUtil.DecompressString` (zlib) und
`C_EncodingUtil.DeserializeJSON` des Clients, jeder Schritt unter `pcall`, keine fremde Bibliothek. Er
übernimmt die Soft-Reserves (Name, Klasse, Notiz auf 60 Zeichen, Items; doppelt = "2x"), die
Hard-Reserves (`hard`, "HR: <für>" im Tooltip, "HR" im Lootfenster, beim Start einer Runde die Rückfrage
"Hard-Reserve für X. Trotzdem würfeln?", keine Lootregel fasst sie an, D-37) und das softres +1 nur als
Hinweis (D-22 bleibt); Bonus-Würfe nicht ("N Bonus-Würfe nicht übernommen"). Die Vorschau sagt
"Gargul-Code erkannt: N Reservierungen, M Hard-Reserves"; ein kaputter Code, ein fehlender Client-Aufruf
oder ein leerer Code ergeben eine deutliche Meldung, und nichts wird übernommen. Höchstens 24 KB Code,
256 KB entpackt, 2000 Reservierungen; Namen ohne Codes und "-Realm". Nachtrag 2026-10-11 (Prüfung nach dem
Bau): `DecompressString` kennt keine Obergrenze und zlib packt bis 1032:1, darum begrenzt erst die Länge
des Codes, was der Client entpackt (24 KB statt 64 KB: höchstens etwa 19 MB, ein Raid mit 40 und Notizen
braucht unter 7 KB); JSON, das tiefer als 20 Ebenen verschachtelt ist, bekommt der Leser des Clients nie
(ein Stapelüberlauf dort wäre kein Lua-Fehler, den `pcall` fängt); Leerzeichen um Felder werden in
linearer Zeit entfernt (eine lange Leerzeichenkette in einer Notiz hielt den Client sonst minutenlang an).
Eine Hand-Eingabe in eine beobachtete Gargul-Runde macht sie nicht "noch nicht angesagt"; die englische
Ansage (B4) setzt Reservierende, die nicht in eine Zeile passen, in die nächste, statt sie abzuschneiden;
Start- und Endzeilen von jemandem, der nicht Plündermeister oder Leiter ist, warten nie auf die
Gildenliste.
**B1:** Startet die Lootleitung eine Runde mit Gargul, liest Amisia dessen Zeile im Raidchat oder als
Schlachtzugswarnung ("You have N seconds to roll on [Item]", deutsch "Du hast N Sekunden um auf [Item]
zu würfeln", dahinter vielleicht " - Notiz"), nur vom Plündermeister oder, ohne Master Loot, vom
Leiter, in der eigenen Gruppe und mit Offiziersrang, höchstens eine pro Sekunde und Absender. Jeder
Raider mit Amisia bekommt sein Würfel-Fenster mit "Runde von X (Gargul)" (Mainspec 1-100, Offspec 1-99
wie Gargul's Standard; "Passen" schließt nur, wie bei Gargul; `rollwin.foreign`, an). Die Amisia der
Lootleitung schreibt die Würfe still mit (`rolls.foreignWatch`, an): keine Ansage, kein `WS`, kein
Ergebnis, "Ergebnis ansagen" und "Nochmal" gehen nicht; das Roll-Fenster sagt "Gargul-Runde: Gargul
sagt den Gewinner an." Es endet bei "Stop your rolls!" / "Stopp deine Würfe!" des Starters oder nach
Ablauf der Zeit. Eine laufende Amisia-Runde geht vor (nie zwei Runden, D-38); dasselbe Item binnen
3 Sekunden mit beiden Addons gestartet ist eine Runde; sonst sagt der Chat der Lootleitung "Gargul-Runde
von X auf [Item] erkannt, während eine Amisia-Runde läuft." Eine geheime Zeile im Bosskampf wird nicht
gelesen; läuft die Runde schon, warten die Knöpfe wie im Würfel-Fenster.
**B4:** `rolls.announceEnglish` ("Rundenansage auch auf Englisch", aus): ein deutscher Client sagt eine
Amisia-Runde zusätzlich auf Englisch an ("Roll on [Item]: /roll for main spec, /roll 99 for off spec. N
seconds.", mit "Reserved by ..."), damit Raider mit Gargul sie verstehen.
**Grund:** Spec vom 2026-10-11, Entscheidungen "Gebaut wird nach der Empfehlung" und die übernommenen
Vorschläge der offenen Fragen; der Nutzer hat Gargul selbst installiert, die Client-Aufrufe sind im
Spiel geprüft (`DeserializeJSON` da, `Enum.CompressionMethod.Zlib` = 1).
**Folge:** Amisia sendet nie etwas an Gargul, meldet kein fremdes Präfix an (D-19 bleibt) und übernimmt
keinen Gargul-Code (Gargul ist "All Rights Reserved"); Gargul-Raider bekommen bei Amisia-Runden kein
Gargul-Fenster (B3 nicht gebaut), sie würfeln mit `/roll` und `/roll 99`. Stellt der Starter Gargul auf
eine andere Sprache um oder schaltet die Ansage ab, sieht Amisia nichts. Die Bereiche stehen nicht im
Chat: Amisia nimmt 100/99 an. `AmisiaDB.softres` hat Datenmodell 3.
**Durchgesetzt durch:** `tests/test_softres_code.lua`, `tests/test_roll_watch.lua`,
`tests/test_softres_code_review.lua`, `tests/test_roll_watch_review.lua`,
`tools/tests/test_softres_samples.py`, `tools/tests/test_contracts.py::test_the_named_exception_stays_narrow`.

## D-45 Hauptfenster: Reiter unten statt Abschnittsleisten, Suche oben links, Kalender als Reiter

**Datum:** 2026-10-11
**Entscheidung:** Spec `docs/specs/2026-10-11-fenster-reiter-kalender.md`. Unter dem Hauptfenster
stehen die Reiter des Spiels für Fenster (`PanelTabButtonTemplate`, wie unter dem Charakterfenster),
einer je Seitengruppe aus `ns.PANEL_GROUPS`: Raid, Ausrüstung, Gilde, Kalender, Amisia. Ein Reiter ohne
sichtbare Seite fehlt. Links stehen nur die Seiten des gewählten Reiters, ohne Abschnittsleisten und
ohne Titelleiste (die aufklappbaren Abschnitte von 2.13 entfallen, `settings.window.collapsed` wird
gelöscht). Der letzte Reiter und je Reiter die letzte Seite bleiben gemerkt (`settings.window.tab`,
`pages`); jede Seite, die sich öffnet (Klick, Befehl, Karte), wählt ihren Reiter. Gemerkt wird nur eine
Seite, die der Spieler oder ein Befehl gewählt hat: fällt die offene Seite auf die Übersicht zurück (Wechsel
der Ansicht, Seite nicht mehr sichtbar), bleibt die gemerkte Seite des Reiters. Die Seitenreiter
rechts bleiben. Oben links über der Seitenliste steht ein Suchfeld: ab 2 Zeichen ersetzt die
Ergebnisliste die Seitenliste, Gruppen "Seiten" (nur sichtbare), "Einstellungen" (Name, Hilfetext,
Auswahlwerte), "Items" (nur Namen, die der Client schon hat: Amisias Itemnamen und zwischengespeicherte
Items der Ausrüstungsdaten; keine Frage an den Server; die Ausrüstungsdaten werden erst ab 3 Zeichen
gebaut), "Spieler" (nur in der Offiziersansicht, aus Raids, Vergaben und Aufstellung), je höchstens 8.
Escape, das X und ein Klick auf einen Reiter (auch den offenen) leeren das Feld. Der Reiter "Kalender" hat die Seite "Kalender": ein Monatsblatt im
Aussehen des Spielkalenders (seine Bilder `Interface\Calendar\CalendarBackground` und `Highlights`,
Woche ab dem Wochentag des Spielkalenders), die Termine, die Amisia ohnehin liest (heute bis 14 Tage),
und die aufgezeichneten Raids; Klick auf einen Tag zeigt dessen Termine und die Teilnehmer wie das
Fenster "Raid-Kalender" (dieselben Daten, dieselbe Zeile, derselbe Leser nach den Regeln von D-42).
**Grund:** Nutzer am 2026-10-11 mit Bildschirmfotos eines anderen Addons: gewählt "Reiter unten am
Fenster", "Monatskalender", "Suchfeld oben links", der Kalender als eigener Reiter im Hauptfenster; das
Fenster "Raid-Kalender" bleibt. Nicht gewählt: eine Symbolleiste. Die Seitenliste war mit 19 Seiten
und vier Abschnitten zu lang geworden (Zeilen auf 16 px geschrumpft).
**Folge:** Eine neue Seite braucht `group` (ihr Reiter); eine neue Gruppe ist ein neuer Reiter und
passt in die Breite des Fensters (auch englisch). Die Spielersuche zeigt Raidern nichts (D-36). Die
Item-Suche öffnet keine Item-Seite: die Seite Ausrüstung kennt nur Ansicht und Platz
(`ns.ShowGear(view, slot)`), darum kommt der Link in die Chatzeile, der Tooltip zeigt das Item. Die
Kalender-Seite schreibt nie in den Kalender und liest nicht im Kampf und nicht, solange das
Kalenderfenster des Spiels ein anderes Ereignis zeigt.
**Nachtrag 2026-10-12 (2.29.0):** Die Seitenliste und die Suchergebnisse tragen die Balken der
Kategorienliste des Auktionshauses, ohne Symbole (D-06).
**Nachtrag 2026-10-17:** Kein blaues Leuchten mehr beim Überfahren der Balken (Nutzer: "dieses blaue
weglassen"); der Name wird weiß. Die Suche findet auch Einstellungsabschnitte nach ihrem Namen oder dem
ihres Reiters ("Allgemein"), Rezepte (ab 3 Zeichen, Namen aus dem Client) und Dungeons (Nutzer: "die
Suche für allgemein und z. B. Rezepte checken, dass alles gefunden werden kann").
**Durchgesetzt durch:** `tests/test_main_tabs.lua`, `tests/test_search.lua`,
`tests/test_calendar_page.lua`, `tests/test_calendar_page_review.lua`, `tests/test_main_tabs_review.lua`, `tests/test_style.lua`, `tests/test_search_more.lua`, die Layoutregeln (`tools/ui_layout.py`,
Regel "nav": jede sichtbare Seite des offenen Reiters hat ihre Zeile).

## D-46 Raid-Check und Raid-IDs: nur Offiziere sehen andere, Selbstauskunft, nichts im Kampf

**Datum:** 2026-10-12
**Entscheidung:** Spec `docs/specs/2026-10-12-raid-check.md`, Teile A, B und C. Eine Seite "Raid-Check"
im Reiter Raid (`/amisia raidcheck`), nur in der Offiziersansicht mit Offiziersrang (wie die
Aufstellung, D-41), mit den Ansichten "Buffs & Verbrauch", "Ausrüstung" und "Raid-IDs"; dazu auf der
Seite Aufstellung je Name ein "ID" (grün frei, rot gesperrt, grau unbekannt) für die dort gewählte
Instanz. **Buffs** liest Amisia selbst aus den Auren der Raider in Sichtweite, nur außerhalb des Kampfes
und der Sperre, geheime Werte übersprungen (D-20); Fläschchen, Elixiere (Aura ab 10 Minuten, keine reinen Nutz-Elixiere wie Wasseratmung, Wasserwandeln, Entdecken), Essen
("Satt") und Klassen-Buffs (Intelligenz, Ausdauer, Mal der Wildnis, Willenskraft, Segen) sind Listen
von Zauber-IDs aus den Client-Tabellen (`tools/build_raidcheck.py`, D-03); versorgt = ein Fläschchen
oder mindestens ein Elixier, dazu Essen; ein Klassen-Buff zählt nur, wenn seine Klasse im Raid ist
(Willenskraft, ein Talent, nur wenn jemand sie trägt). **Ausrüstung** nur als Selbstauskunft der
Amisia jedes Raiders (`XA`, kein Betrachten): niedrigste Haltbarkeit (rot unter `raidcheck.durability`,
30 %, orange unter 50 %), Itemstufe, leere Plätze (nicht die Schildhand neben einer Zweihandwaffe, nicht
der Distanzplatz von Paladin, Schamane, Druide), unverzauberte Plätze (Link, sonst Tooltip-Zeile Typ 15;
feste Liste Rücken, Brust, Handgelenke, Hände, Füße, Waffenhand, Schild, bis `SpellEquippedItems`
exportiert ist; Kopf, Schultern, Beine nie), freie Talentpunkte. "Prüfen" fragt den Raid (`XQ`, nur ein
geprüfter Offizier im eigenen Raid), jede Amisia antwortet nach 0-3 Sekunden, beim Bereitschaftscheck
einmal von selbst (nur wenn ein Mitglied der eigenen Gilde ihn startet); nichts im Kampf, in der Sperre oder bei einem geheimen Bereitschaftscheck, eine
Antwort, die nicht in 10 Sekunden rausgeht, verfällt, eine zweite Frage in 10 Sekunden wird nicht
erneut beantwortet. Antworten leben nur im Speicher (30 Minuten, bis der Raid endet). Die Chatzeile
"Amisia Raid-Check: Es fehlt: ..." gibt es nur mit `raidcheck.chat` (Standard aus), nur auf Klick
eines Offiziers, nie in der Sperre, höchstens zwei Zeilen, nur Namen der Raidliste und feste Wörter.
**Raid-IDs:** jede Amisia merkt sich die gesperrten IDs (Instanz, Schwierigkeit, Reset, Bosse) aller
Charaktere des Kontos und meldet sie der Gilde (`IV`: 60-180 s nach dem Login jeden Charakter, nach
einer neuen ID höchstens alle 5 Minuten, per Flüstern auf `IQ` eines geprüften Offiziers, höchstens
einmal in 10 Minuten); abschaltbar mit `raidcheck.lockouts`. Behalten wird `IV` nur in der
Offiziersansicht mit Offiziersrang, nur für Charaktere der Gildenliste; die eigene Angabe eines
Charakters gilt vor jeder anderen (D-12, 7 Tage), einen Charakter, den die Twink-Liste einem anderen
Main als dem des Absenders zuordnet, verwirft Amisia, sonst steht er grau "laut <Absender>"; höchstens
12 Charaktere pro Absender, 300 insgesamt, ein Reset mehr als 31 Tage voraus verwirft die Nachricht.
Raider sehen nur sich selbst: `/amisia raidcheck` schreibt ihre Zeile und die Raid-IDs der eigenen
Charaktere in den Chat.
**Grund:** Spec vom 2026-10-12, vom Nutzer freigegeben ("ja mach deine Vorschläge"): eigene Seite im
Reiter Raid, versorgt = Fläschchen oder Elixier plus Essen, Haltbarkeit 30/50, Antwort beim
Bereitschaftscheck, Chatzeile aus und nur per Klick, alle Charaktere des Kontos melden; "Raid-IDs für
wen" ohne Vorschlag, angenommen nur Offiziere (wie die Zahlen anderer Spieler, D-36), jeder sieht seine
eigenen.
**Folge:** Neue Nachrichtenarten `XQ`, `XA`, `IV`, `IQ` (keine neue Protokollnummer), neuer Schlüssel
`AmisiaDB.raidcheck`, Einstellungsabschnitt `raidcheck`, Daten `Data/RaidCheckData.lua`; keine
Exportzeile, nichts auf der Website. Abweichend vom Wortlaut der Spec meldet Amisia auch Charaktere ohne
ID (`-`), damit "frei" von "unbekannt" (ohne Amisia) unterscheidbar ist. Die Leser von Auren, Haltbarkeit,
Itemstufe, Verzauberung, Talentpunkten und Raid-IDs teilen sich Raid-Check und `/amisia selbsttest
gruppe` (`Raid/RaidCheckRead.lua`). Gruppen- und Gildenprüfungen erst nach dem Start (D-32).
**Durchgesetzt durch:** `tests/test_raidcheck.lua`, `tests/test_raidcheck_comm.lua`, `tests/test_raid_ids.lua`,
`tests/test_raidcheck_page.lua`, `tests/test_raid_ids_abuse.lua`, `tests/test_raidcheck_abuse.lua`, `tests/test_selftest_group.lua`, `tools/tests/test_build_raidcheck.py`,
`tools/tests/test_contracts.py::test_every_message_kind_has_its_row_and_no_row_is_left_over`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.

## D-47 Einladen und Sortieren der Aufstellung: gedrosselt, nie im Kampf, nur mit Führung; "inv" und Assistent nur mit Einstellung

**Datum:** 2026-10-13
**Entscheidung:** Spec `docs/specs/2026-10-10-raid-aufstellung.md`, Teile C und D, mit den Wünschen des
Nutzers vom 2026-10-12. Alles nur in der Offiziersansicht mit Offiziersrang (D-41), nie im Kampf, in
der Kampfsperre eines Bosses oder im Schlachtfeld, in einer Gruppe nur als Leiter oder Assistent eines
Raids (in einer Fünfergruppe nur als Leiter). **Einladen:** "Alle einladen", "Nochmal einladen" und
der Knopf einer Zeile nur für die Nacht von heute (andere Nächte: aus, "Nur für heute Abend"; Review
2026-10-13). "Alle einladen" lädt die eingeteilten
Spieler ein, die online und noch nicht in der Gruppe sind, aus einem Timer, eine Einladung alle
0,5 Sekunden; allein oder in einer Gruppe erst bis fünf in der Gruppe, nach dem ersten Beitritt wandelt
Amisia (als Leiter) in einen Raid um und lädt den Rest ein. Unklare Namen (vermutlich, nicht eindeutig,
unbekannt) und Offline-Spieler werden nicht eingeladen, Gäste nur mit `lineup.guests`. Der Status pro
Name kommt aus den Systemmeldungen über die Textvorlagen des Spiels (`ERR_*_S`, nie deutscher Text) und
aus der Raidliste: geplant, eingeladen, im Raid, abgelehnt, keine Antwort (nach 90 Sekunden), schon in
Gruppe, offline, unbekannt; eine geheime Meldung (Sperre) wird übersprungen; "Gruppe ist voll"
(`ERR_GROUP_FULL`, ohne Namen) gilt nur innerhalb von 3 Sekunden nach Amisias letzter Einladung
(Review 2026-10-13). "Nochmal einladen" nimmt
abgelehnt, keine Antwort und schon in Gruppe, einmal pro Klick; nie automatisch wiederholt; höchstens
drei Einladungen pro Name und Abend (Klick und Flüstern zusammen). Die Status leben nur im Speicher
(nach `/reload` neu aus der Raidliste, der Zähler beginnt neu). Flüstern beim Einladen
(`lineup.whisper`, aus): fester Text, nur die Gruppe wechselt, einmal pro Name und Abend.
**Sortieren:** "Gruppen sortieren" schiebt jeden Raider der Liste in seine Gruppe aus dem Planer
(`SetRaidSubgroup` auf einen freien Platz, sonst `SwapRaidSubgroup` mit einem Raider der Liste, der dort
nicht hingehört); wer nicht auf der Liste steht, bleibt, wo er ist. Ein Schritt pro Meldung der
Raidliste, höchstens 60 pro Klick; ein Kampf hält an ("Sortieren fortsetzen" per Klick). Automatisch
(`lineup.autoSort`, an) 2 Sekunden nach einem Beitritt, aber nur auf dem Client, der heute "Alle
einladen" geklickt hat. **Einladen auf Flüstern** (`lineup.inv`, aus): ein Flüstern, das genau "inv"
oder "invite" ist (Groß/klein egal), von einem Gildenmitglied laut Gildenliste (unter genau dem Namen
der Gildenliste, eingeladen in deren Schreibweise; ein unklarer Vorname reicht nicht; ein Gast nur, wenn er
auf der heutigen Aufstellung steht und `lineup.guests` an ist), nur solange eine Aufnahme läuft oder
heute eine Aufstellung steht, als Leiter, Assistent oder allein; einmal in 30 Sekunden pro Absender,
10 pro Minute; Meldungen nur im eigenen Chat. Seit dem Review 2026-10-13: die Grenzen zählen erst nach
der Prüfung der Gildenliste (Fremde verbrauchen sie nie, ein Fremder bekommt höchstens eine Zeile "nicht
in der Gilde" pro 5 Minuten); ein Flüstern wandelt nie in einen Raid um (volle Fünfergruppe: nichts
geht raus, eine Zeile "Gruppe voll, erst in einen Raid umwandeln."), und in einer Instanz für fünf
Spieler lädt es nicht ein. **Assistent** (`lineup.autoAssist`, aus): als
Schlachtzugsleiter wird jedes Gildenmitglied mit Offiziersrang laut Gildenliste (Rangrecht 22, D-18),
das im Raid ist, einmal pro Raid Assistent; nicht im Kampf und nicht in der Sperre. Der Name in der
Raidliste muss genau der Name der Gildenliste sein (Groß/klein egal); ein Vorname allein reicht für
die Beförderung nicht (Review 2026-10-13).
**Grund:** Nutzer am 2026-10-12: Teile C und D jetzt bauen, dazu "inv" per Flüstern (ändert Frage 8 der
Spec auf ja) und automatischer Assist für Offiziere. Prüfung 11 im Spiel (2026-10-12 17:46): InviteUnit
geht aus dem Tastendruck und aus einem C_Timer ohne Sperre; die deutschen Vorlagen stehen im Bericht.
**Folge:** Neue Dateien `Raid/LineupInvite.lua` und `Raid/LineupSort.lua`, die Ansicht "Einladen" auf
der Seite Aufstellung, `/amisia aufstellung einladen` und `sortieren` (en `invite`, `sort`), vier
Einstellungen im Abschnitt `lineup`. Keine Nachricht, keine Exportzeile, kein gespeicherter Schlüssel.
Beim Bau entschieden: allein zählt beim Flüstern wie Leiter (der erste Beitritt macht die Gruppe);
Umwandeln nur mit mehr Namen als fünf Plätzen; wer sortiert, entscheidet die Absprache (nur der
einladende Client sortiert automatisch). Prüfungen 12 und 13 (Umwandeln, Sortieren, auch als
Assistent) und alle Gruppenprüfungen erst ab 2026-11-04 (D-32).
**Durchgesetzt durch:** `tests/test_lineup_invite.lua`, `tests/test_lineup_sort.lua`,
`tests/test_lineup_inv_whisper.lua`, `tests/test_lineup_invite_en.lua`.

## D-48 Speicherstand mit Versionsnummer, Migrationen in einer Liste

**Datum:** 2026-10-13
**Entscheidung:** `AmisiaDB.schema` zählt die Schritte von `ns.MIGRATIONS` (`Core/Migrate.lua`). Ändert ein
Release die Form gespeicherter Daten über Teile hinweg, vor allem wenn eine Einstellung in einen anderen
Abschnitt zieht, kommt ein neuer Schritt ans Ende der Liste (nie umsortieren, nie löschen; ein
überflüssiger Schritt wird eine leere Funktion). Die Schritte laufen beim Laden vor der Prüfung der
Einstellungen, jeder genau einmal; ein Fehler hält die Kette an und sie läuft beim nächsten Laden weiter.
Eine Datei einer neueren Amisia bleibt unverändert (eine Chatzeile beim Login). Die eigenen Marken der
Teile (`settings.version`, `awardsVersion`, `softres.version`, die `v`-Felder) bleiben. Fensterzustand darf
neben den Einstellungen eines Abschnitts stehen, aber nie unter dem Namen einer Einstellung.
**Grund:** Auftrag des Nutzers vom 2026-10-13 ("Bestehende Einstellungen der Nutzer dürfen NICHT verloren
gehen ... eine Migration mit Versionsnummer"); Grundlage für das Neuordnen der Einstellungen.
**Folge:** Ohne Schritt in der Liste darf keine Einstellung umziehen.
**Durchgesetzt durch:** `tests/test_migrate.lua`, `tests/test_settings_state.lua`.

## D-49 Einstellungen nach Reitern, ein Knopf "Einstellungen" je Seite, keine Einstellungen in Seiten

**Datum:** 2026-10-13
**Entscheidung:** Spec `docs/specs/2026-10-13-dungeons-einstellungen.md` (Teil B). Jeder Einstellungsabschnitt
gehört zu genau einem Reiter (`group`) und nennt die Seiten, deren Knopf "Einstellungen" ihn öffnet (`pages`).
Steht man auf der Seite Einstellungen, zeigt die Seitenliste darunter die Reiter und unter dem gewählten
seine Abschnitte (Leisten des Auktionshauses); die Seite zeigt nur den gewählten Abschnitt, die Abschnitte
einer Seite (über ihren Knopf in der Kopfzeile, mit "Zurück zu <Seite>") oder die Suchtreffer aller
Abschnitte. "Zurücksetzen" setzt die gezeigten Abschnitte nach einer Rückfrage auf den Standard, "Alle
Einstellungen zurücksetzen" (Oberfläche) alle; Daten und Fensterplätze bleiben. Einstellungen stehen nie in
den Seiten selbst. Statt eines Zahnrads auf jeder Seite ein Knopf in der Kopfzeile (Auftrag "mach deine
reihenfolge"): eine Stelle für alle Seiten. Die Abschnittsliste steht in der Seitenliste statt in der Seite,
damit Zeilen und der Editor der Lootregeln ihre volle Breite behalten.
**Grund:** Auswahl des Nutzers 2026-10-13 ("Zahnrad + nach Reitern"), Ziel "alles besser und einfach finden /
einstellen".
**Folge:** Ein neuer Abschnitt braucht `group` und, wenn er zu einer Seite gehört, `pages`.
Nachtrag 2026-10-14 (Nutzer: "einstellungen usw ein/ausklappen"): ein Klick auf die offene Gruppe klappt ihre
Abschnitte zu, ein Klick auf "Einstellungen" alle Gruppen, wie die Kategorien des Auktionshauses; der gezeigte
Abschnitt bleibt. Das Zuklappen gilt nur für die Sitzung und nur, solange dieselbe Auswahl gezeigt wird (kein
gespeicherter Zustand), damit ein Abschnitt aus der Suche oder einem Seitenknopf nie zugeklappt erscheint.
**Durchgesetzt durch:** `tests/test_settings_pages.lua`.

## D-50 Orte auf der Karte: Eingänge lernt Amisia beim Betreten, sie leben im Archiv auf dem N100

**Datum:** 2026-10-16
**Entscheidung:** Spec `docs/specs/2026-10-16-karte-orte.md` (Fragen 1-5). Flugmeister nur der eigenen
Fraktion plus neutrale, alle gleich (nichts pro Charakter). Klick auf einen Eingang öffnet ihn in Amisia,
Shift-Klick setzt das Ziel. Eingänge, die keine Quelle kennt, merkt sich Amisia beim Betreten
(`AmisiaDB.entrances`): der letzte Ort im Freien, höchstens 20 s vor dem Ladebildschirm in eine Gruppen- oder
Raid-Instanz, nach der Instanz-ID; nicht nach einer Beschwörung oder einem Teleport der Gruppensuche, höchstens 60. `build.py data` (Schritt map)
nimmt sie in `tools/entrance_archive.json` auf (eine neuere Sichtung ersetzt die ältere, nichts fällt weg) und
in `Data/MapData.lua`, als letzte Quelle nach Client-Tabelle Map, AllTheThings und OneForAll. Anders als bei den
Scan-Daten (D-34) räumt das Addon nichts weg: der Schlüssel ist klein. Klassische Anleger stehen von Hand in
`tools/forever_transports.json`, neue Forever-Routen kommen dazu, wenn der Nutzer sie meldet. Stehen auf der Karte
des Spiels selbst Pins für Eingänge oder Flugpunkte (`DungeonEntrancePinTemplate`/`FlightPointPinTemplate`), lässt
Amisia diese Art weg; Client-Funktion und Daten-Provider allein zählen nicht (Forever hat beide, zeigt aber keine
Flugpunkte, 2.39.2).
**Grund:** Antwort des Nutzers 2026-10-16: "mach deine vorschläge"; die neuen Forever-Dungeons und -Raids hat
noch keine Quelle.
**Folge:** Das Archiv committen; es ist die einzige Kopie der gelernten Orte außerhalb der SavedVariables. Ein
falscher gelernter Ort wird erst durch eine neuere Sichtung oder eine bessere Quelle ersetzt.
**Durchgesetzt durch:** `tests/test_map_places.lua`, `tools/tests/test_build_map.py::test_learned_entrances_join_the_archive`,
`tools/tests/test_build_map.py::test_the_first_source_wins_and_only_real_second_entrances_join`.

## D-51 Neue Client-Tabellen: der PC exportiert, der N100 baut und prüft, veröffentlicht wird nur auf Zuruf

**Datum:** 2026-10-16
**Entscheidung:** Die Windows-Aufgabe "Amisia Client-Tabellen" (`tools/install_export_task.ps1`, einmal als
Administrator eingerichtet) startet 2 Minuten nach der Anmeldung und alle 2 Stunden im Hintergrund die neueste
`tools/export_db2.ps1` von GitHub; ohne neuen Build endet sie sofort, läuft WoW, versucht es der nächste Lauf.
Auf dem N100 schaut der systemd-Timer `amisia-auto-data.timer` (`tools/systemd/`, `tools/auto_data.py`) alle
15 Minuten nach einem vollständigen Export eines neueren Builds als dem der Daten auf main; dann baut er in einem
eigenen Worktree auf dem Branch `auto/data-<build>` (`build.py data`, `build.py check`), committet dort und
schreibt das Ergebnis nach `~/addons/_auto/amisia-data.txt`. Er pusht nicht, mergt nicht nach main und
veröffentlicht nicht.
**Grund:** Nutzer 2026-10-16: "können wir das besser machen und automatisieren?", dann "der N100 soll nur bauen
und prüfen, veröffentlichen will ich selbst anstoßen."
**Folge:** Zu Beginn einer Sitzung liest Claude `~/addons/_auto/amisia-data.txt` und meldet einen bereiten oder
roten Branch. Zum Veröffentlichen den Branch nach main mergen (oder `build.py data` auf main), dann
`build.py release`. Jeder Build wird einmal versucht (`--force` erneut).
**Durchgesetzt durch:** `tools/tests/test_auto_data.py`.

## D-52 Duelle: nur die Meldung des Spiels, Klassen ohne Nachfrage oder per Klick, nichts wird gesendet

**Datum:** 2026-10-16
**Entscheidung:** Spec `docs/specs/2026-10-16-duelle.md` (F-106). Amisia schreibt Duelle nur aus der
Systemmeldung mit (`CHAT_MSG_SYSTEM` über die Vorlagen `DUEL_WINNER_KNOCKOUT` und `DUEL_WINNER_RETREAT`
des Clients; eine geheime Meldung wird übersprungen), eigene und, mit `duels.nearby`, fremde in der Nähe;
kein Kampflog (D-20). Klassen kommen aus dem, was der Client ohnehin kennt (eigener Charakter, Gruppe,
Ziel, Maus, Namensplaketten mit `duels.plates`, Gildenliste, Freundesliste), sonst per `/who` nur auf
den Klick "Klassen suchen" (eine Frage pro Klick, höchstens alle 5 s, zuerst die eigene Zone, dann ein
Name). Nichts wird gesendet: keine Addon-Nachricht, keine Chatzeile, keine Exportzeile. Gespeichert werden
höchstens 5000 Duelle und keines älter als 90 Tage (`AmisiaDB.duels`). Ein einfacher Turnier-Modus
markiert die Duelle zwischen "Turnier starten" und "Turnier beenden". Die Seite "Duelle" steht im
sechsten Reiter "PvP" und ist für alle.
**Grund:** Nutzer 2026-10-16 mit Bildschirmfotos eines anderen Addons; zu allen sieben Fragen der Spec:
"passt, alle Vorschläge so übernehmen und bauen". `C_FriendList.SendWho` ist im Client eingeschränkt
(nur auf Tastendruck oder Klick), der Server drosselt `/who`.
**Folge:** Ein Austausch der Duelle mit der Gilde wäre ein eigenes Feature mit neuer Nachricht (Spec
nötig). D-45 bekommt den Reiter "PvP" zwischen Kalender und Amisia; der Einstellungsabschnitt `duels`
hat die Ordnung 70.
**Durchgesetzt durch:** `tests/test_duels.lua`.

## D-53 Soft-Reserves teilen: nur Offiziere mit eigener Liste, ganze Liste, neueste gewinnt

**Datum:** 2026-10-17
**Entscheidung:** Spec `docs/specs/2026-10-17-softres-teilen-vorschau.md` (F-107, F-108, F-109). Ein
Offizier in der Offiziersansicht, der eine Liste selbst übernommen hat, teilt sie mit dem Raid
(`softres.share`, an): `SV` kündigt sie an, wer einen anderen Stand hat, fragt mit `SQ`, die ganze Liste
kommt als Blob `SR`. Angenommen wird nur von einem verifizierten Offizier der eigenen Gilde in der
eigenen Gruppe, nur gefragt, Feld für Feld geprüft, mit dem angekündigten Hash. Raider und Offiziere
ohne eigene Liste übernehmen sie still (`softres.from`); ein Offizier mit eigener Liste bekommt sie nur
als Angebot ("Liste übernehmen", nur bis `/reload`). Es gilt die neueste Übernahme (gleich: der kleinere
Name); zwei Listen werden nie gemischt. Löschen geht als `SV <Zeit> -` hinaus und löscht die Kopien.
Geteilt wird nur im Raid (Amisias Addon-Nachrichten kennen keinen PARTY-Kanal), nicht in
Schlachtfeldern. Der Klassen-Abgleich (F-109) ist ein Hinweis und sperrt nichts; Namensvorschläge
bleiben ein Klick (kein automatisches Zuordnen), die Klasse ordnet sie nur. Die Ansage nach dem
Übernehmen (`softres.announce`, an) nennt Zahl und `!sr` und die Hard-Reserves; Englisch nach
`rolls.announceEnglish` wie die Rundenansage (D-44).
**Grund:** Nutzer 2026-10-17 nach dem Import-Fenster eines anderen Addons: "Passt, alle 5 Vorschläge so
übernehmen und bauen (Reihenfolge C, B, A)." Dort darf jeder senden und überschreibt die Liste der
anderen; das soll hier nicht gehen.
**Folge:** Raider sehen die Liste der Lootleitung in Tooltip, Lootfenster und auf der Seite, ohne
selbst zu importieren. Das Import-Fenster liegt jetzt in `UI/SoftResImport.lua`.
**Durchgesetzt durch:** `tests/test_softres_share.lua`, `tests/test_softres_preview.lua`,
`tests/test_softres_class.lua`.
