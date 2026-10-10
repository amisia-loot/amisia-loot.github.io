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
löschen statt halten. Generierte Daten tragen `[AllowLoadGameType camelot]`. `data/tbc.js` und Co.
sind nur noch Archiv (kein Neubau).
**Durchgesetzt durch:** `addon/tests/test_forever_only.lua`, `tools/tests/test_data_files.py::test_data_holds_forever_and_the_tbc_archive_only`,
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
Wowhead/zamimg und die eigenen Dienste der Seite), `tools/tests/test_site_wowhead.py`.

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

**Datum:** 2026-10-06
**Entscheidung:** AllTheThings (MIT) ist freigegeben, mit dem Lizenztext in
`addon/Amisia/LICENSES/AllTheThings-MIT.txt` (in einer Lizenzdatei, nicht in der UI). QuestieDB hat
keine Lizenz und ist entfernt. wowsrc.com, OneForAll und AtlasLoot bleiben Eingaben der Builds
("Ja können wir alles nutzen"; die Lizenzen hat der Nutzer entschieden, nicht geprüft).
Daten, die andere Repos von Wowhead/foreverchanges kopiert haben, sind nicht nutzbar, auch wenn das
Repo MIT ist.
**Grund:** Lizenztreue.
**Folge:** Neue Daten nur aus diesen Quellen; jede generierte Datei nennt im Kopf Generator und
Quellen, jede mit AllTheThings-Daten steht in der Lizenzdatei. Fremde Addons sonst nie nennen (D-05).
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_every_generated_file_names_its_generator_and_sources`,
`tools/tests/test_contracts.py::test_no_questie_data_left`, `tools/tests/test_build_quests.py::test_the_licence_names_every_file_from_allthethings`.

## D-05 Keine anderen Addons nennen

**Datum:** 2026-10-04
**Entscheidung:** Andere Addons werden in ausgelieferten Texten, Chat, Kommentaren, erzeugten
Dateien und Commits nicht genannt (in Entwürfen heißen sie "andere Loot-/Raid-Addons"). Ausnahme:
eine Datenquelle, deren Lizenz die Nennung verlangt (D-04). Die Notizen zur Konkurrenz liegen außerhalb
des Repos (`~/addons/_research`).
**Grund:** Wunsch des Nutzers seit der Konkurrenzrecherche.
**Folge:** Gargul-Importe der Seite heißen dort weiter so (die Seite liest deren Export); im Addon
nirgends.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_other_addons_are_not_named_in_the_addon`
(Liste bekannter Addon-Namen; Commits nicht maschinell geprüft).

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
**Grund:** Bildschirmfotos und Wünsche des Nutzers 2026-10-05/06/07; für die Talente das Foto des
klassischen Talentfensters 2026-10-10 ("können wir talente auch so machen") und das Foto von 2.19.0
("können wir das fenster wo die talente sind größer machen oder besser skalieren").
**Folge:** Client-Vorlagen und -Atlanten vor eigenen flachen Frames; ein neuer Atlas kommt nur in
`ns.Theme.ATLASES`, wenn er zum Stil passt. Kein `UIDropDownMenu`/`EasyMenu`/`MenuUtil`, keine
Blizzard-Einstellungskategorie, keine fremden Bibliotheken.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_the_forever_look`,
`tools/tests/test_contracts.py::test_no_foreign_libraries_menus_or_combat_log`, die Layoutregeln
(`tools/ui_layout.py`, Atlasliste), `addon/tests/test_style.lua` und für die Talente
`addon/tests/test_talents_page.lua` und `addon/tests/test_talent_window.lua` (Abstände beider Größen).

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
Schlüssel (`L["..."]`), Englisch steht in `addon/Amisia/Locales/enUS_*.lua`.
Maschinenformate (Export, Nachrichten, gespeicherte Schlüssel) übersetzt man nie.
**Grund:** Wahl des Nutzers aus dem Dungeon-Journal-Vergleich; umgesetzt in 2.9.0.
**Folge:** Neuer Text deutsch in `L[...]` plus englischer Eintrag im passenden Teil; Code-Kommentare
englisch; Texte der Website englisch.
**Durchgesetzt durch:** `tools/l10n.py` (in `build.py check`), `tools/tests/test_l10n.py::test_the_addon_is_translated`,
`addon/tests/test_locale_en.lua`, die englischen Addon-Tests (`run.py --locale enUS`).

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
**Durchgesetzt durch:** `addon/tests/test_collector.lua`, `addon/tests/test_collect_trust.lua`,
`tools/tests/test_collect_records.py::test_the_build_trusts_own_values_and_heard_ones_two_accounts_agree_on`.

## D-13 Wegpunkte und Pins nur aus eigenen (oder bestätigten) Daten

**Datum:** 2026-10-07
**Entscheidung:** Questgeber-Wegpunkte und -Pins kommen aus den Daten oder aus dem, was dieser
Client selbst gesehen hat; nur Gehörtes setzt keinen Wegpunkt.
**Grund:** Wunsch des Nutzers.
**Folge:** Gilt für Quests, Dungeons und Berufe.
**Durchgesetzt durch:** `addon/tests/test_quests.lua`, `addon/tests/test_dungeon_guide.lua`, `addon/tests/test_professions.lua`.

## D-14 Ein laufender Raid behält sein Punktesystem

**Datum:** 2026-10-08
**Entscheidung:** Wird das Lootsystem (Würfeln, DKP, EPGP) umgestellt, behält der laufende Raid das
System, mit dem er begann; erst der nächste Raid nimmt das neue. Würfel-Raids bekommen keine Punkte
nachträglich.
**Grund:** Vom Nutzer bestätigt.
**Folge:** Die Seite ist die Wahrheit der Stände; das Addon liefert nur Neues (PS/PE/PA/PX).
**Durchgesetzt durch:** `addon/tests/test_points_rounds.lua`, `addon/tests/test_points.lua`, `tools/tests/test_points_site.py`.

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
**Entscheidung:** `## Version:` in `addon/Amisia/Amisia.toc` ist die einzige Stelle; Core liest sie
beim Laden. Releases nur über `python3 tools/build.py release X.Y.Z`.
**Grund:** Zwei Stellen liefen auseinander.
**Folge:** Keine Versions-Literale im Lua.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_the_version_stands_only_in_the_toc`,
`tools/tests/test_build_tool.py::test_the_repo_toc_has_the_version_and_matches_the_folder`, `addon/tests/test_version_toc.lua`.

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
**Durchgesetzt durch:** `addon/tests/test_sync_raid.lua`, `addon/tests/test_sync_terms.lua`, `addon/tests/test_sync_ops.lua`,
`addon/tests/test_trust.lua`, `tools/tests/test_contracts.py::test_every_message_kind_has_its_row_and_no_row_is_left_over`.

## D-19 Nachrichten: zwei Präfixe, nichts in Sperre und Schlachtfeld, kein Dauerfunk

**Datum:** 2026-10-05
**Entscheidung:** Genau zwei Präfixe (`Amisia`, `AmisiaD`), Drosselung pro Präfix selbst
eingehalten, kein Präfixwechsel zum Umgehen. Kanäle nur RAID (eigene Raidgruppe), GUILD, WHISPER;
nie INSTANCE_CHAT. In der Kampfsperre, in Schlachtfeldern und Arenen wird nichts gesendet. In die
Gilde geht eine Versionsmeldung pro Sitzung; Fragen nur auf Knopfdruck (5 Minuten Abstand).
Packen nur mit `C_EncodingUtil` des Clients.
**Grund:** Forevers Sperren und Drosselung; keine fremden Bibliotheken.
**Folge:** Jede neue Nachricht läuft durch `Core/Comm.lua` und bekommt eine Zeile in ARCHITECTURE.md.
**Durchgesetzt durch:** `addon/tests/test_comm.lua`, `addon/tests/test_comm_bus.lua`,
`tools/tests/test_contracts.py::test_two_prefixes_and_one_sender`, `tools/tests/test_contracts.py::test_the_gap_of_every_kind_is_the_documented_one`.

## D-20 Kein Kampflog, keine Kampfdaten

**Datum:** 2026-10-05
**Entscheidung:** Amisia nutzt kein `COMBAT_LOG_EVENT_UNFILTERED`, keine Monster-Rufe, kein
`UNIT_DIED`; Kills kommen aus `ENCOUNTER_START/END`, `BOSS_KILL` und als Rückfall aus dem Lootfenster.
Geheime Werte (Forever) werden über `ns.Plain` erkannt und übersprungen, nie verglichen.
**Grund:** Forever gibt Addons kein Kampflog; Blizzards Linie.
**Folge:** Namen beim Kill werden nach der Sperre gelesen.
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_no_foreign_libraries_menus_or_combat_log`, `addon/tests/test_raidlog.lua`.

## D-21 Würfelbereiche und Rangfolge

**Datum:** 2026-09-19
**Entscheidung:** Mainspec `/roll` 1-100, Offspec `/roll 99` 1-99; andere Bereiche gelten nicht,
werden aber gezeigt. Reihenfolge: Reservierung (SR), dann MS, dann OS, dann der Wurf; mit Plus-Eins
weniger MS-Gewinne zuerst unter den MS-Würfen.
**Grund:** Wahl des Nutzers; der Bereich in der Systemmeldung macht jeden Wurf eindeutig.
**Folge:** Gildenwünsche und Loot-Prio ändern die Würfelordnung nicht.
**Durchgesetzt durch:** `addon/tests/test_rolls.lua`, `addon/tests/test_plusone.lua`, `addon/tests/test_guild_wishes.lua`.

## D-22 Plus-Eins zählt nur Mainspec-Gewinne

**Datum:** 2026-10-05
**Entscheidung:** Plus-Eins zählt nur lebende MS-Vergaben an Spieler; SR, OS, Bank und Entzaubern
zählen nicht (SR-Gewinne als +1: bewusst nein). Twinks zählen für ihren Main.
**Grund:** Entscheidung im Vergabe-Baustein (Assistent, vom Nutzer nicht widersprochen).
**Folge:** -
**Durchgesetzt durch:** `addon/tests/test_plusone.lua`, `addon/tests/test_alts.lua`.

## D-23 Zu spät: nur der erste Raid der Nacht zählt; Raidnacht beginnt um 06:00

**Datum:** 2026-09-24
**Entscheidung:** Ein Start vor 06:00 zählt zur Nacht davor. Verspätungen zählen nur im ersten Raid
einer Nacht (Hyjal zuerst, BT danach). Nur die erste Sichtung zählt; wer von der Ersatzbank kommt
(Offizierseintrag oder `!bench` vor der Grenze), ist nie zu spät.
**Grund:** Regel des Nutzers.
**Folge:** Addon und Seite setzen dieselbe Regel um.
**Durchgesetzt durch:** `addon/tests/test_late.lua`, `addon/tests/test_bench.lua`, `tools/tests/test_late_rule.py`.

## D-24 Materialien: gelernt, Maximum statt Summe

**Datum:** 2026-10-05
**Entscheidung:** Die Liste der Gildenmaterialien wird gelernt (alle Handelswaren der Qualitätsstufe,
die in Raids droppen), nicht im Code benannt; Offiziere nehmen Einträge heraus oder fügen hinzu.
Auf der Seite zählt pro Nacht, Raider und Item das Größere aus Vergabe und Addon-Loot, nie die Summe.
Eine Bankzählung schreibt nie Bestandskorrekturen.
**Grund:** Wunsch des Nutzers ("alle Materialien, die in Raids droppen"); Doppelzählung vermeiden.
**Folge:** Materialien gehen nach Hausregel an die Gildenbank und werden nie angesagt.
**Durchgesetzt durch:** `addon/tests/test_mats_learn.lua`, `addon/tests/test_mats_migrate.lua`, `tools/tests/test_site_mats.py`.

## D-25 Keine Spielernamen in Drop-Daten

**Datum:** 2026-10-05
**Entscheidung:** Ein Drop-Satz trägt eine Kennung aus der Leichen-GUID und eine zufällige
Client-Kennung, keinen Spielernamen; Exportzeilen und Seitendaten ebenso.
**Grund:** Datensparsamkeit beim Gildenaustausch.
**Folge:** Der gleiche Kill zählt einmal, egal wie viele ihn sehen.
**Durchgesetzt durch:** `addon/tests/test_drops.lua`, `tools/tests/test_drop_import.py`.

## D-26 Gewünschtes ändert keine Vergaberegel; Loot-Prio und Wünsche kommen von der Seite

**Datum:** 2026-10-05
**Entscheidung:** Gildenwünsche, Loot-Prio und "Wer braucht das?" zeigen Hinweise (Tooltip, "W",
"P1", Reihenfolge im Vergabe-Dialog), ändern aber nie die Würfelordnung. Die Website ist die Quelle
für Wünsche, Twinks, Loot-Prio und Punkte; das Addon bekommt sie als Einfügeblock und schickt eigene
Änderungen als Exportzeilen zurück. "Wer braucht das?" geht nie in den Raidchat.
**Grund:** Offiziere entscheiden; die Seite ist der gemeinsame Ort.
**Folge:** Eingefügter Text ist unvertraut und wird Feld für Feld geprüft.
**Durchgesetzt durch:** `addon/tests/test_guild_wishes.lua`, `addon/tests/test_loot_prio.lua`, `addon/tests/test_need.lua`,
`tools/tests/test_contracts.py::test_paste_in_blocks`.

## D-27 Eine Lootleitung pro Raid, Antworten per Flüstern

**Datum:** 2026-10-05
**Entscheidung:** Genau ein Client sagt Loot an und beantwortet `!sr`/`!bench`: der Plündermeister,
sonst der Schlachtzugsleiter, in Offiziersansicht (`loot.lead = "me"` übernimmt, wenn der Leiter
Amisia nicht hat). Antworten immer per Flüstern an den rohen Absender. Ansagen nur im Schlachtzug,
einmal pro Leiche; Chat nur über `ns.Say`, in der Sperre wird gewartet.
**Grund:** Zwei Offiziere mit Amisia sollen nicht doppelt posten.
**Folge:** Der Nutzer erwartet Master Loot (eine Tausch-Warteschlange ist nicht gewünscht). Ausnahme (2026-10-09, Spec `docs/specs/2026-10-08-loot-abend.md`): ein Handel-Helfer für vergebene Items, die doch in einer Tasche liegen, als Liste mit Knopf, keine Warteschlange für jeden Loot (gebaut als D-39).
**Durchgesetzt durch:** `addon/tests/test_lootannounce.lua`, `addon/tests/test_srchat.lua`, `addon/tests/test_chat.lua`.

## D-28 Daten werden erst bei Bedarf gebaut

**Datum:** 2026-10-07
**Entscheidung:** Große generierte Tabellen liegen beim Login nur als Text vor (`ns.LazyData`) und
werden beim ersten `ns.Data(...)` gebaut; Verfügbarkeitsprüfungen nur über `ns.HasData`/`ns.DataSize`.
**Grund:** Kurzer Login, wenig Speicher für Spieler, die die Seiten nie öffnen.
**Folge:** Neue große Daten über `tools/lua_data.py` `lazy()`; seit 2026-10-08 ohne überflüssige
Leerzeichen (`lua_data.compact`, Zeilen bleiben) und auch die Gewichte (`GEAR_WEIGHTS`).
**Durchgesetzt durch:** `addon/tests/test_lazy_data.lua`, `tools/tests/test_lua_data.py`.

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
**Folge:** Alles Gruppenbezogene bleibt bis dahin nur im Test-Stub belegt (`addon/tests/run.py`
Mehr-Client-Tests).
**Nicht maschinell geprüft**

## D-33 Die Seite: Sicherheit und Datenschutz

**Datum:** 2026-09-16
**Entscheidung:** E-Mail-Adressen sieht nur der Besitzer, nie ein E-Mail-Rückfall für Anzeigenamen.
Im `onAuthStateChange`-Callback nie auf Supabase warten. `refreshRole` setzt die Rolle erst nach der
Antwort zurück. Wer online ist, läuft über die Tabelle `presence` (Herzschlag), nicht über
Realtime-Presence. Mitgliederdaten stehen nicht im Ledger-JSON.
**Grund:** Datenschutz; Deadlocks und verlorene Speicherungen in der Praxis.
**Folge:** Nach jeder Änderung an `data/*.js` `BUILD_ID` in `index.html` erhöhen.
**Durchgesetzt durch:** `tools/tests/test_data_files.py::test_build_id_is_new_since_1_9` (nur BUILD_ID; der Rest ist nicht maschinell geprüft).

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
`tools/tests/test_scan_archive.py::test_the_committed_marker_is_current`, `addon/tests/test_scan_trim.lua`.

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
**Durchgesetzt durch:** `addon/tests/test_award_history.lua`.

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
Liste, MR in höchstens 4 Teilen, ein Vorschlag pro Offizier alle 30 Sekunden.
**Durchgesetzt durch:** `addon/tests/test_loot_rules.lua`, `addon/tests/test_loot_rules_share.lua`,
`addon/tests/test_loot_rules_review.lua`, `addon/tests/test_award_candidate.lua`,
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
Ansage im Raidchat bleibt. Gespeichert wird nur die Position (`settings.rollWindow`).
**Durchgesetzt durch:** `addon/tests/test_roll_window.lua`, `addon/tests/test_roll_window_raid.lua`,
`addon/tests/test_roll_window_names.lua`, `addon/tests/test_roll_window_review.lua`,
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
**Durchgesetzt durch:** `addon/tests/test_handover.lua`,
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
**Durchgesetzt durch:** `addon/tests/test_setup.lua`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.

## D-41 Raid-Aufstellung: nur Offiziere, eingefügter Text unvertraut, einladen nur per Klick, nie Kicks

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
**Folge:** Gebaut sind die Teile A, B und E (2.22.0). Einladen (Teil C: nur per Klick, gedrosselt,
höchstens drei Einladungen pro Name und Abend, kein Einladen auf Flüstern, Gäste nur mit Einstellung)
und Sortieren im Spiel (Teil D) kommen erst nach den Prüfungen 10, 11 und 13 der Spec; ihre
Einstellungen (`lineup.whisper`, `lineup.autoSort`) gibt es bis dahin nicht. Nie Kicks, kein
Leiterwechsel, keine Beförderung. Das Paket sendet und empfängt keine Addon-Nachrichten, keine neue
Exportzeile; eingefügter Text ist unvertraut (D-26: Codes und Striche entfernt, 200 Bytes pro Zeile,
2000 Zeilen, Namen ohne Ziffern und Steuerzeichen, 48 Zeichen). Die Website schreibt `#AMISIA-RAID`
nicht; der Vertragstest kennt dafür die Ausnahme "liest nur das Addon".
**Durchgesetzt durch:** `addon/tests/test_lineup.lua`, `addon/tests/test_lineup_page.lua`,
`tools/tests/test_contracts.py::test_paste_in_blocks`,
`tools/tests/test_contracts.py::test_every_saved_key_has_its_row`.
