# Entscheidungen

Die Entscheidungen des Nutzers (und die Regeln, die aus seinen Antworten folgen), gesammelt aus den
Erinnerungen und den Entwürfen unter `docs/superpowers/specs`. Jede steht mit Datum, Grund, Folge
und wie sie gehalten wird. Wer eine Entscheidung ändert, ändert diesen Eintrag im selben Commit
(neues Datum, alter Stand in einem Satz unter "Folge"). Technische Verträge (Nachrichten, Zeilen,
gespeicherte Schlüssel) stehen in [ARCHITECTURE.md](ARCHITECTURE.md).

`tools/tests/test_contracts.py` prüft, dass jeder Eintrag Datum, Entscheidung, Grund, Folge und
"Durchgesetzt durch" (oder "Nicht maschinell geprüft") hat und dass jeder hier genannte Test
existiert.

## D-01 WoW Forever mit allem, TBC Anniversary und Classic Era nur mit dem Raid-Teil; TBC lebt auf der Seite nur als Archiv

**Datum:** 2026-10-25 (zuerst 2026-10-05)
**Entscheidung:** Das Addon zielt auf WoW Forever (TOC-Interface 16001) mit allen Teilen. Seit F-126 lädt es
auch auf TBC Anniversary (20506) und Classic Era mit SoD und Hardcore (11509), dort aber nur mit dem Raid-Teil
(D-57). Mists, Retail und andere Clients bleiben weg. Die Seite zeigt nur Forever im Spielwähler; der TBC-Ledger
der Gilde bleibt als schreibgeschütztes Archiv lesbar. Für TBC/Era gibt es keine Seite, keinen Ledger und keine Daten.
**Grund:** Die Gilde zieht nach Forever (Start 2026-11-04); zwei vollständige Clients verdoppelten Arbeit und
Review-Funde. Nutzer 2026-10-25 mit einem Screenshot von 2.46.1 auf TBC/Classic: "Nur Raid-Teil + sauberes UI".
**Folge:** Kein TBC-Code des alten 1.9-Clients und keine Daten oder Seiten für TBC/Era; die Forever-Teile laden nur
mit `[AllowLoadGameType camelot]` (D-57). Generierte Daten tragen `[AllowLoadGameType camelot]`.
`Amisia-Website/data/tbc.js` und Co. sind nur noch Archiv (kein Neubau). Bis 2026-10-25 galt: nur Forever
(`## Interface: 16001` allein), nie wieder TBC- oder Fremdversions-Code.
**Durchgesetzt durch:** `tests/test_forever_only.lua`, `tests/test_tbc_raid.lua`, `tests/test_era_raid.lua`,
`tools/tests/test_data_files.py::test_data_holds_forever_and_the_tbc_archive_only`,
`tools/tests/test_site_archive.py`, `tools/tests/test_contracts.py::test_the_toc_loads_the_forever_parts_on_forever_only`,
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
**Nachtrag 2026-10-31 (F-127):** Der Talentrechner liest eingefügte Build-Links von talentsforever.com und
wowforevertalents.com. Beide Namen dürfen im Code und im Tooltip des Code-Felds stehen, nie als `http`-Link;
Amisia exportiert keinen Link dorthin und fragt die Seiten nie ab.

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

**Datum:** 2026-11-04 (zuerst 2026-10-06, dann 2026-10-15)
**Entscheidung:** AllTheThings (MIT) ist freigegeben, mit dem Lizenztext in
`Amisia/LICENSES/AllTheThings-MIT.txt` (in einer Lizenzdatei, nicht in der UI). QuestieDB hat
keine Lizenz und ist entfernt. wowsrc.com bleibt eine Eingabe der Builds ("Ja können wir alles
nutzen"; die Lizenz hat der Nutzer entschieden, nicht geprüft). Seit 2026-11-04 keine Daten und keine
Grafik unter einer Copyleft-Lizenz: OneForAll (GPL-3.0) und AtlasLoot (GPL-2.0) sind aus den Builds
entfernt, damit Amisia seine eigene Lizenz frei wählen kann. Ersatz: die Berufsstufe der Rezepte aus
den Client-Tabellen (`build_gear.client_crafts`: das höhere von `SkillLineAbility.MinSkillLineRank`
und der `RequiredSkillRank` des Rezept-Items; gegen die alten Werte 1535 von 1540 gleich), Anleger und
die Flugmeister, die AllTheThings fehlen, von Hand in `tools/forever_transports.json` (die bekannten
Classic-Orte, im Spiel zu prüfen), die Karten-Symbole eigene (`tools/make_place_icons.py`); die
Dungeon-Beute, Dungeon-Quests und Eingänge, die nur OneForAll kannte (23 Beute-Quellen, 6 Quests,
3 Eingänge der neuen Forever-Dungeons), lernt Amisia im Spiel (Sammler, D-50).
Daten, die andere Repos von Wowhead/foreverchanges kopiert haben, sind nicht nutzbar, auch wenn das
Repo MIT ist.
**Grund:** Lizenztreue. Nutzer 2026-11-04 beim CurseForge-Upload: "kommen wir die sachen die unter
license sind selber neu erstellen", nach der Aufstellung "ok mach das". Bis dahin war OneForAll 5.x
seit 2026-10-15 freigegeben ("Nutz OneForAll 5.6.0 als Quelle", für die Orte der Karte "OneForAll als
Quelle passt") und machte Amisia GPL-pflichtig.
**Folge:** Neue Daten nur aus diesen Quellen; jede generierte Datei nennt im Kopf Generator und
Quellen, jede mit AllTheThings-Daten steht in dessen Lizenzdatei. Eine neue Lizenzdatei unter
`Amisia/LICENSES/` oder eine Quelle mit Copyleft entscheidet der Nutzer vorher. Fremde Addons sonst
nie nennen (D-05).
**Durchgesetzt durch:** `tools/tests/test_contracts.py::test_every_generated_file_names_its_generator_and_sources`,
`tools/tests/test_contracts.py::test_no_questie_data_left`, `tools/tests/test_build_quests.py::test_the_licence_names_every_file_from_allthethings`,
`tools/tests/test_build_gear.py::test_recipes_and_their_skill_come_from_the_client_tables`.

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
Seit 2026-11-06 (D-67) sind Ansichten und Filter keine roten Chips mehr, sondern Textreiter (`W.Tab`, `W.TabCheck`);
rot bleiben die eine Hauptaktion je Ansicht und Knöpfe in Zeilen.
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
**Nachtrag 2026-11-07 (Audit):** Ein Offizier, der in der Raider-Ansicht nur den öffentlichen Teil übernimmt,
behält Notiz, Erstgewinner und "von Hand" seiner Vergaben (`sync.pub`); in der Offiziersansicht fragt er den Offiziersteil
nach, und als neuer Hüter sammelt er eine Revision tiefer, damit ein Offizier mit dem ganzen Stand derselben Revision
antwortet. Angenommenes Restrisiko: Antwortet beim Sammeln niemand mit dem ganzen Stand, kann ein solcher Hüter eine
Notiz (oder Erstgewinner, "von Hand") zurückbringen, die ein Offizier in einer späteren Revision geändert hat; vorher
gingen diese Felder dabei für den ganzen Raid verloren. Treffen sich zwei solche Offiziere derselben Revision, nimmt der
neue Hüter den Teil des anderen und verliert nur die Felder, die er selbst mitgenommen hatte.
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
Leerzeichen (`lua_data.compact`, Zeilen bleiben) und auch die Gewichte (`GEAR_WEIGHTS`). Ereignisse
(Login, Taschen, Bank, Logout) bauen keine Tabelle; was sie aus einer brauchen, merken sie sich, wenn
eine Seite sie ohnehin gebaut hat (`ns.DataLoaded`; seit 2026-11-06 die Liste der Berufsreagenzien in
`prof.bags`, F-137).
**Durchgesetzt durch:** `tests/test_lazy_data.lua`, `tests/test_prof_route_lazy.lua`, `tools/tests/test_lua_data.py`.

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
Kalenderfehler oder kein neuer Stand: "Bitte auch im Kalender eintragen." mit "Kalender öffnen" (seit 2.57.1
"Warum?": Amisia öffnet den Spielkalender nicht selbst, D-64) und einmal der Grund im Chat. Nie für andere, nie im Kampf, nie bei offenem Kalenderfenster, nie beim
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
**Nachtrag 2026-11-06:** Der Reiter Raid ordnet seine Seiten wie eine Raidnacht: davor Übersicht, Aufstellung,
Soft-Reserves, Raid-Check; währenddessen Rolls, Vergaben, Raid-Log; danach Punkte, Statistik, Raid-Archiv,
Export. Die Offiziersseite "Raids" (aufgezeichnete Raids, Schlüssel `raids`) heißt jetzt "Raid-Archiv", damit
"Raids" nur noch die Seite in Ausrüstung ist (Spec 2026-10-17). Export zieht vom Reiter Gilde in den Reiter Raid
neben das Raid-Archiv: er exportiert vor allem Raids (neue, geänderte, angekreuzte); Gildenbank, Bedarf und
Loot-Prio gehen im selben Text mit. Beide bleiben Offiziersseiten.
**Nachtrag 2026-11-06:** Zurechtfinden: Seiten und Einstellungsabschnitte haben Stichwörter (deutsch und
englisch, nie angezeigt: "dkp" findet die Punkte, "waypoint" die Karte), die Gruppe "Befehle" (ab 3 Zeichen,
ein Klick schreibt den Befehl nur in die Chatzeile), das Suchfeld sagt im Tooltip, was es ab wie vielen Zeichen
findet, und unter 2 Zeichen "Noch 1 Zeichen für die Suche"; ein Auffrischen lässt die Treffer an ihrer
Scrollstelle. Das Porträt öffnet die Übersicht. Das Schnellmenü der Minimap folgt den Reitern: je Reiter ein
Eintrag, der dessen sichtbare Seiten im selben Menü zeigt (kein Untermenü-Fenster, kein fremdes Menü, D-06).
**Nachtrag 2026-11-07:** Die Reiter unter dem Fenster und die Seitenreiter rechts ersetzt D-68 (eine Seitenleiste
mit Gruppen); Suche, Gedächtnis der Seiten (`settings.window.tab`, `pages`) und Kalender-Seite bleiben.
**Durchgesetzt durch:** `tests/test_main_sidebar.lua`, `tests/test_search.lua`, `tests/test_nav_find.lua`,
`tests/test_calendar_page.lua`, `tests/test_calendar_page_review.lua`, `tests/test_main_sidebar_review.lua`, `tests/test_style.lua`, `tests/test_search_more.lua`, die Layoutregeln (`tools/ui_layout.py`,
Regel "nav": jede sichtbare Seite der offenen Gruppe hat ihre Zeile).

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
damit Zeilen und der Editor der Lootregeln ihre volle Breite behalten. Seit 2026-11-06 (D-67) ist der Knopf das
Zahnrad des Questlogs rechts im Fensterkopf statt eines roten Knopfs "Einstellungen"; die Stelle bleibt eine für alle Seiten.
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
in `Data/MapData.lua`, als letzte Quelle nach Client-Tabelle Map und AllTheThings. Anders als bei den
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
**Nachtrag 2026-10-17 (F-114, Nutzer: "können wir klasse und spec hinzufügen"):** Die Spezialisierung ist der
Talentbaum mit den meisten Punkten, je Name gespeichert (`AmisiaDB.duels.spec`). Die eigene kommt aus den
Talenten; die anderen liest Amisia mit `duels.inspect` durch Betrachten (`NotifyInspect`, kein Fenster) eines
Duellanten, der als Ziel, unter der Maus oder auf einer Namensplakette in der Nähe steht: jeder Name einmal pro
Sitzung, eine Anfrage alle 2 s, nie im Kampf, in der Sperre oder bei offenem Betrachten-Fenster; eine fremde
Anfrage dazwischen verwirft Amisias Antwort. Auch das sendet nichts an andere Spieler. Fremde Duellanten, die
nie in der Nähe standen, bleiben ohne Spezialisierung (kein `/who`-Weg dafür).
**Nachtrag 2026-10-17 (F-116..F-120, Nutzer: "bau zuerst die Ideen mit ein"):** Die Duell-Daten erscheinen auch
außerhalb der Seite, nur lesend: eine Karte unter der Duell-Anfrage des Spiels (`duels.request`) und eine Zeile
im Spieler-Tooltip (`duels.tooltip`); dazu Serien, Erzfeind/Lieblingsgegner, Zeitraum und Klassen nach
Spezialisierung. Nicht gebaut (bräuchten eine eigene Spec): Turnierbaum, Elo-Wertung, Dauer und Restleben
eigener Duelle, Stufenunterschiede.
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

## D-54 Upgrade in Prozent der ganzen Leistung, gerechnet mit dem Charakterbogen

**Datum:** 2026-10-17
**Entscheidung:** Spec `docs/specs/2026-10-17-upgrade-genau.md` (F-115). "Upgrade für dich" ist die
Änderung der ganzen Leistung der Spezialisierung (Schaden, Heilung, beim Tank Überleben mit Bedrohung zu
15 %) in Prozent, nicht mehr der Zuwachs der Wertung eines Slots. Gerechnet wird mit den vier Modellen,
aus denen `tools/build_bis.py` die Gewichte herleitet (Gewichte = ihre Steigung am Referenz-Charakter),
jetzt mit den eigenen Werten: der Charakterbogen, gelesen außerhalb des Kampfs nach Ausrüstungs-, Stufen-
und Talentwechsel (nicht nach Buffs), im Kampf der letzte Stand; ohne Bogen Grundwerte plus Ausrüstung,
"(ungefähr)". Vorher/Nachher statt Gewicht mal Wert: Trefferobergrenze, Krit mal Angriffskraft und Mana
gegen Zauberschaden ergeben sich aus den Formeln. Prozent-Talente auf Attribute zählen als Verhältnis
Bogen zu Basis plus Ausrüstung (1 bis 1,2). Setboni, die ein Tausch bricht oder schließt, zählen mit;
Verzauberungen nicht (beide Items ohne). Die Zeile nennt die Spezialisierung; Shift zeigt die Teile,
die Slot-Prozent, die anderen Spezialisierungen (`bis.otherSpecs`) und die Werte, die sich bewegen. Die
Schwelle `bis.minTotal` (0,3 %) ersetzt `bis.minGain` und gilt über die Größe der Leistung auch für
Tabelle, Ziele und Dungeons. "Wer braucht das?" schickt die Gesamt-Prozent in Zehnteln am Slot
(`HEAD-17`); Antworten älterer Versionen zeigen ihre Slot-Prozent mit "(alt)" und stehen hinten.
Ausrüstungstabelle, Simulation und Planung behalten die Referenzgewichte.
**Grund:** Nutzer 2026-10-17 nach "+141 %" für einen Umhang in einem anderen Addon: "ich will auch das es
für den spek angezeigt und ich will die bestmögliche und genau berechnung"; Spec-Fragen 1-5: "passt, alle
Vorschläge übernehmen und bauen".
**Folge:** Die Zahlen im Tooltip sind klein (ein Umhang selten über 3 %), aber zwischen Slots und Spielern
vergleichbar. Python (`m_*` in `build_bis.py`) und Lua (`Gear/Model.lua`) rechnen dieselben Formeln.
**Durchgesetzt durch:** `tools/tests/test_upgrade_model.py` (Lua gleich Python, Steigung gleich Gewicht),
`tests/test_upgrade_model.lua`, `tests/test_need.lua`.

## D-55 Eigene Wahl je Slot: schlägt BiS-Empfehlung und Wertung, gilt je Spezialisierung, nie automatisch, nie gesendet

**Datum:** 2026-10-17
**Entscheidung:** Spec `docs/specs/2026-10-17-ziele-fenster.md` (F-110 bis F-113). Der Spieler kann im
Fenster "Ausrüstungsziele" je Slot und Spezialisierung ein Item zum Ziel machen (`AmisiaDB.bis.chars[<Name>].pick`,
`ns.BisSetPick`): aus der Rangliste per Klick oder über das Feld "Item-Link oder ID" (nur ein Item-Link
oder eine Zahl; das Item muss in den Slot passen und für die Klasse tragbar sein; ein Item außerhalb der
Daten zählt mit den Werten des Clients, Quelle "unbekannt", ohne Pin). Die eigene Wahl ist Option 1 ihres
Slots überall, wo Amisia ein Ziel nutzt (`ns.BisTargets`: Seite Ziele, Fenster, Karten-Pins; "Hier" und
die Dungeon-Rangliste zählen sie als Upgrade, bis sie angelegt ist, und dann in ihrem Slot nichts
anderes) und schlägt eine BiS-Empfehlung (D-09). Der Tooltip "Upgrade für dich" rechnet weiter nur nach
der Wertung gegen das Angelegte. Eine Wahl, die zum Waffenplan nicht passt (oder die die Klasse nicht mehr
tragen kann), bleibt gespeichert, wird aber nicht genutzt ("Passt nicht zum Waffenplan"). Amisia ändert
eine Wahl nie selbst: ist sie angelegt und das beste Item der Rangliste um mindestens `bis.minGain`
besser, steht nur "Überholt: ... Übernehmen" da. Die Wahl wird nie gesendet (auch nicht an "Wer braucht
das?"). Die Wertung des Fensters ist Amisias eigene (D-11): dieselbe Formel, kein fremder Name.
**Grund:** Nutzer 2026-10-17 zur Spec nach der BiS-Liste eines anderen Addons: "passt, alle sechs Vorschläge
so übernehmen".
**Folge:** `ns.BisOpts` trägt die genutzten Wahlen (`own`) und die nicht genutzten (`ownUnused`), der
Schlüssel der Ergebnisse auch; `ns.BisMigrate` prüft Spezialisierung, Slot und Zahl (höchstens 17 Zahlen je
Spezialisierung, keine neue Migration nach D-48 nötig). Ein Teilen von Listen (Teil F) braucht einen
eigenen Nachtrag zur Spec.
**Durchgesetzt durch:** `tests/test_goals_picks.lua`.

## D-56 Spielstil filtert Quellen der eigenen Ziele, nie die Wertung; Rechtsklick auf Slots nur nach dem Spiel

**Datum:** 2026-10-24
**Entscheidung:** Spec `docs/specs/2026-10-24-spielstil-slotklick.md` (F-124, F-125). Fünf Schalter über den
Quellen-Chips (Keine Dungeons, Solo machbar, Kaufbar, Jetzt holbar, Fokus-Zone), beliebig viele zugleich: eine
Quelle muss alle erfüllen. Sie gelten nur für die eigenen Optionen (`ns.BisOpts`: Seite Ziele, Fenster
Ausrüstungsziele, Karten-Pins, "Hier", der Upgrade-Punkt der eigenen Spalte der Tabelle, die Slot-Karte, die
BiS-Empfehlungen: eine ohne bekannte Quelle fällt bei jedem Schalter weg), nicht für
den Tooltip "Upgrade für dich", die anderen Spalten der Tabelle, die Simulation, die Seiten Dungeons und Raids und
"Wer braucht das?" (nichts davon wird gesendet). Sie ändern keine Wertung. "Kaufbar" lässt jedes Item herein, das nicht
beim Aufheben bindet (Quelle "Auktionshaus (bindet beim Anlegen)"), auch wenn sein Chip aus ist; das Auktionshaus hat
keine Zone. "Jetzt holbar": Ruf aus der Client-Tabelle ItemSparse; ein Ruf, den der Client nicht nennt, zählt als
erreicht; nennt der Client gar keine Berufe, zählt Hergestelltes. Gruppenquests lernt Amisia aus dem eigenen Questlog
(`AmisiaDB.questtags`, nie gesendet, Archiv `tools/quest_tag_archive.json`). Die eigene Wahl (D-55) bleibt Option 1
ihres Slots, mit "außerhalb deines Spielstils" (nur wenn die Schalter, nicht die Chips, sie ausschließen). Trash-Drops
eines Dungeons ("Trash (...)") zählen als Dungeon. Die Schalter sind Fensterzustand (`settings.bis.style`, je Account),
keine Einstellung (D-49). Der Rechtsklick auf einen Slot des Charakterfensters hängt sich nur nach dem Klick des
Spiels an (`HookScript`); auf einem Item mit Benutzen-Effekt benutzt das Spiel es und nur Alt+Rechtsklick öffnet die
Karte; Amisia legt nie etwas an.
**Grund:** Nutzer 2026-10-24 nach dem Vergleich mit einem anderen Leveling-Addon: "Schreib eine Spec für die
Spielstil-Filter ... plus Rechtsklick auf den Slot im Charakterfenster"; zur Spec: "Passt, alle sechs Vorschläge so
übernehmen und bauen."
**Folge:** Der Schlüssel der Optionen trägt Schalter, Ort und einen Zähler (Ruf, Zone, gelernte Questtypen), sonst
stimmt kein Cache. Elitequests ohne Questlog-Eintrag erkennt "Solo machbar" erst nach dem nächsten Daten-Build.
**Durchgesetzt durch:** `tests/test_play_style.lua`, `tools/tests/test_build_gear.py`.

## D-57 Raid-Teil auf TBC und Era: die Forever-Teile laden nur auf Forever, ein Schalter `ns.GAME`

**Datum:** 2026-10-25
**Entscheidung:** Spec `docs/specs/2026-10-25-raid-auf-tbc-und-era.md` (F-126). Eine `Amisia.toc` mit
`## Interface: 16001, 20506, 11509`. Nur auf Forever laden (`[AllowLoadGameType camelot]`): `Data/*`, `Collect/*`,
`Gear/*`, `Core/Duels.lua`, `Raid/Handover.lua` (Handel-Helfer), `UI/GoalsWindow.lua`,
`UI/SlotCard.lua`, `UI/DuelInfo.lua` und die Seiten Ausrüstung, Dungeons, Raids (Ausrüstung), Karte, Berufe, Quests,
Talente, Magierrollen, Duelle, Werkzeuge und Export. Alles andere ist der Raid-Teil und lädt auf allen drei Clients;
er greift auf die Forever-Teile nur zur Laufzeit und nur geprüft zu (`if ns.Gear and ...`). Der Schalter heißt
`ns.GAME` ("forever", "tbc", "era"; `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT` zuerst, sonst die Interface-Nummer des
Builds) mit `ns.FOREVER`; `ns.Visible` blendet alles mit `forever = true` außerhalb von Forever aus (Talent- und
Zielfenstergröße, Export-Erinnerung `record.exportWarn`, Befehl `/amisia export`). Außerhalb von Forever fehlen
außerdem die Ansicht "Buffs & Verbrauch" des Raid-Checks (die Buffliste ist Forever-Datenbestand; Ausrüstung und
Raid-IDs bleiben) und das Aufheben nicht exportierter Raids über "Raids aufbewahren". Die Einfügeblöcke der Seite
gelten nur für ihr Spiel (`OWN_GAME = ns.GAME`). Der Reiter Gilde (Bank, Mitglieder) bleibt. Item-Tooltips hängen sich
auf TBC/Era an `OnTooltipSetItem`, die Reiter unter dem Fenster bekommen ihre Breite auf allen Clients von Amisia, die
Pfeile der Zahlenfelder ohne Forevers Atlas die Seiten- und Scrollpfeile des Clients.
**Nachtrag 2026-10-30:** TBC Anniversary hält sich nicht an `[AllowLoadGameType camelot]` (2.47.0 lud dort `Gear/*`,
Fehler in `Gear.lua` bei jedem Taschen-Tooltip). TBC und Era bekommen deshalb eigene TOCs, die sie vor `Amisia.toc`
laden: `Amisia_TBC.toc` (20506) und `Amisia_Vanilla.toc` (11509), beide `Amisia.toc` ohne die camelot-Zeilen.
`Amisia.toc` bleibt die Quelle (Forever); `build.py tocs` schreibt die beiden, `release` mit der neuen Version,
`check` schlägt fehl, solange sie abweichen. Die Lua-Tests für TBC/Era laden die Dateien dieser TOCs.
**Grund:** Nutzer 2026-10-25: "Nur Raid-Teil + sauberes UI"; zu den vier offenen Fragen der Spec "passt" (Export
und Export-Erinnerung aus, Gilde bleibt, Handel-Helfer aus, Raid-Check-Buffs aus).
**Folge:** Eine neue Datei gehört entweder zum Raid-Teil (lädt überall, kein Forever-Global beim Laden) oder trägt den
camelot-Tag und steht in den Listen der beiden Tests. Ein Export von TBC/Era kann nicht im Forever-Ledger landen.
SavedVariables von TBC/Era kommen nicht auf den N100 zurück; Spiel-Tests dort macht der Nutzer.
**Durchgesetzt durch:** `tests/test_forever_only.lua`, `tests/test_tbc_raid.lua`, `tests/test_era_raid.lua`,
`tests/test_game_switch.lua`, `tools/tests/test_contracts.py::test_the_toc_loads_the_forever_parts_on_forever_only`,
`tools/tests/test_contracts.py::test_the_classic_clients_have_their_own_toc_without_the_forever_parts`, `build.py check`
(TOC against the folder).

## D-58 Releases auch auf CurseForge: Upload aus dem Release, Token nur auf dem N100

**Datum:** 2026-11-04
**Entscheidung:** `build.py release` lädt nach dem Push `Amisia-Website/Amisia.zip` über die Upload-API von
CurseForge hoch (`tools/curseforge.py`). Das Projekt steht in `## X-Curse-Project-ID` von `Amisia.toc`, der Token in
`~/.config/amisia/curseforge.token` (nie im Repository, nie im Chat). Die Spielversionen sind die Interface-Nummern
der TOC, wie CurseForge sie nennt (16001 -> 1.60.1, 20506 -> 2.5.6, 11509 -> 1.15.9), der Changelog ist der Abschnitt
der Version in `CHANGELOG.md`, der Dateityp "release". Ohne Projekt oder Token wird übersprungen; kennt CurseForge
eine Spielversion nicht, wird nichts hochgeladen. Ein fehlgeschlagener Upload lässt den Release stehen (Exit 1,
nochmal mit `python3 tools/curseforge.py upload`); `--no-upload` lässt ihn aus. Die Website bleibt mit derselben Zip.
**Grund:** Nutzer 2026-11-04: "können wir Amisia auch bei curseforge hochladen", dann "Ja, vorbereiten". Updates
kommen so über die CurseForge-App, ohne Zip von der Website.
**Folge:** Die Projektseite auf CurseForge hat wie das Addon keine Links zu Fan-Seiten und nennt keine anderen
Addons. Vor dem ersten Upload entscheidet der Nutzer die Lizenz von Amisia; die OneForAll-Daten gehen nicht mit (D-04,
2026-11-04).
**Durchgesetzt durch:** `tools/tests/test_curseforge.py`,
`tools/tests/test_build_tool.py::test_release_uploads_only_what_was_pushed`.

## D-59 Realistische Quellen: geplant wird nur, was man gezielt bekommt

**Datum:** 2026-11-05
**Entscheidung:** Ziele, Ausrüstungstabelle, Stufen-Sets und Simulation planen mit festen Quellen: Quests,
Dungeon- und Raid-Bosse, Handwerk, Händler, PvP-Ränge und benannte seltene Mobs (`R`, ohne Schalter).
Zufällige Welt-Drops (`W`) zählen nur mit dem Chip "Weltdrops" (seit 2.51 aus, einmal für alle Spieler
ausgeschaltet: `srcRule` 2) und nie als Epics. Das Auktionshaus (Chip "AH" und Spielstil "Kaufbar") zählt nur
für ein Item mit fester Quelle oder einen nicht epischen Welt-Drop bei eingeschalteten Welt-Drops
(`Gear.BuyRealistic`). Items, die nur der Server beschreibt (nicht in der Client-Tabelle), zeigt Amisia mit
Name (nur deutscher Client) und Symbol aus dem Scan (`N`, `IC` in GearData) und einem eigenen Tooltip.
**Grund:** Wunsch des Nutzers 2026-11-05 ("nur realistische Sachen rein machen, die man wirklich bekommt"):
Epics der Stufe 30 ab Stufe 1 (288xxx), die die Gilde nur am 23.10.2026 bei normalen Mobs in Durotar und
Tirisfal fallen sah und die der Server danach nicht mehr beschrieb, füllten die Tabelle von 1 bis 50.
Leveling-Listen anderer planen zufällige BoE-Drops nicht ein: man findet zufällige Items, aber nie gezielt
ein bestimmtes.
**Folge:** Wer zufällige Welt-Drops will, schaltet "Weltdrops" ein; Epics aus Welt-Drops bleiben draußen.
**Durchgesetzt durch:** `tests/test_bis_score.lua` (Regeln, eigener Tooltip), `tests/test_bis_targets.lua`,
`tests/test_play_style.lua`, `tools/tests/test_build_gear.py::test_names_and_icons_only_for_items_the_client_lacks`.

## D-60 Changelog auf Englisch, mit Links, aus eigenen Notizen

**Datum:** 2026-11-05
**Entscheidung:** `CHANGELOG.md` ist englisch. Jede Änderung, die ein Spieler merkt, schreibt im selben Commit eine
Notiz unter `## Unreleased`: `- type(scope): summary (F-xxx)` (feat, fix, perf, data, docs, chore), eine Leerzeile, ein
eingerückter kurzer Absatz. `build.py release` macht daraus den Abschnitt der Version mit der Überschrift
`## [vX.Y.Z](<repo>/releases/tag/vX.Y.Z) (Datum)` und der Zeile `[Full Changelog]` (Vergleich mit der Version davor)
`[Previous Releases]`, setzt den Tag `vX.Y.Z`, schiebt ihn mit und macht daraus ein GitHub-Release; CurseForge bekommt
denselben Abschnitt. Ohne Notiz bricht der Release ab, bevor sich etwas ändert. Andere Addons und Fan-Seiten werden
auch hier nicht genannt (D-02, D-05).
**Grund:** Wunsch des Nutzers 2026-11-05 ("changelog sollen so aussehen und auf englisch sein", Bildschirmfoto eines
Changelogs mit Versions-Link, Full Changelog, Previous Releases und Einträgen `fix(scope): ...` mit Absatz); die
Commit-Betreffe sind deutsch. Die 76 älteren Abschnitte wurden übersetzt, alle Release-Commits bekamen ihren Tag.
**Folge:** Die Notiz gehört zur Änderung, nicht zum Release; Daten-Releases bekommen eine `data(...)`-Notiz.
**Durchgesetzt durch:** `tools/tests/test_build_tool.py::test_release`,
`tools/tests/test_build_tool.py::test_release_uploads_only_what_was_pushed`,
`tools/tests/test_curseforge.py::test_the_changelog_is_the_release_section`.

## D-61 Feedback nur an den Autor: Fremde dürfen senden, der Empfänger deckelt alles

**Datum:** 2026-11-05
**Entscheidung:** Die Seite "Feedback" (F-130) schickt einen Bug oder Wunsch (höchstens 500 Zeichen) nur an die
Charaktere des Autors, die fest in `Core/Feedback.lua` stehen (`Fb.AUTHORS`: "Vulo Vultrox", WoW Forever, Horde),
als unsichtbare Addon-Nachricht `FB` per WHISPER; der Autor-Client antwortet `FA` ("angekommen"). Es ist die
einzige Nachricht an einen Namen außerhalb von Gruppe und Gilde (`opts.anyone` in `Core/Comm.lua`) und die einzige,
die Gildenfremde senden dürfen (Ausnahme von D-18). Dafür deckelt der Empfänger: nur ein Autor-Client nimmt `FB`,
Absender ist der Name des Servers, eine offene Meldung je Absender, alle Teile (höchstens 4) binnen 60 s, 3 Meldungen
je Absender und Tag, Text höchstens 500 Zeichen, Farbcodes, Links und Striche entfernt, blockierte Absender und alles
über 300 Meldungen im Eingang (die ältesten erledigten zuerst) still verworfen. `FA` gilt nur vom Autor und nur für
eine eigene Meldung. Der Absender schickt höchstens 3 am Tag; ist der Autor offline (Systemzeile "nicht online",
verschluckt, oder 30 s ohne Antwort), wartet die Meldung und geht nach einem Login in 2-5 Minuten, danach höchstens
alle 30 Minuten wieder, nie im Kampf, in der Kampfsperre, in Schlachtfeld oder Arena (D-19), eine Wiederholung nie in
einer Instanz; nach 10 Versuchen "nicht zugestellt" mit "Nochmal". Erreichbar ist der Autor nur vom gleichen Client
(`ns.GAME`) und der gleichen Fraktion; sonst steht auf der Seite "Auf diesem Server kann Amisia den Autor nicht
erreichen." und "Abschicken" ist aus. Den Server prüft Amisia nicht (der Server des Autors steht nirgends): ein
Spieler eines anderen Servers wartet bis "nicht zugestellt".
**Grund:** Wunsch des Nutzers 2026-11-05 (Spec `docs/specs/2026-11-05-feedback.md`, "Passt, bauen"): Rückmeldungen
ohne Discord, Website oder Forum; Addons können nicht ins Internet. Weil jeder senden darf, schützen nur die Deckel
beim Empfänger.
**Folge:** Ein neuer Autor-Charakter ist eine Zeile in `Fb.AUTHORS`. Keine Weitergabe an Offiziere oder die Gilde,
keine Antwort außer "angekommen", keine Daten anderer Spieler im Anhang; der letzte Amisia-Fehler geht nur bei einem
Bug und nur mit "Fehler anhängen" mit.
**Durchgesetzt durch:** `tests/test_feedback.lua`,
`tools/tests/test_contracts.py::test_every_message_kind_has_its_row_and_no_row_is_left_over`,
`tools/tests/test_contracts.py::test_the_gap_of_every_kind_is_the_documented_one`.

## D-62 Wegpunkt, Verfolgung und Weltkarte des Clients nur außerhalb von Instanzen und Kampf

**Datum:** 2026-11-05
**Entscheidung:** Amisia setzt oder löscht den Wegpunkt des Clients (`C_Map.SetUserWaypoint`, `ClearUserWaypoint`),
die Verfolgung (`C_SuperTrack`) und öffnet die Weltkarte nur, wenn `Map.ClientSafe()` gilt: nicht in einer Instanz,
nicht im Kampf, nicht in der Kampfsperre. Sonst ändert sich nur Amisias eigenes Ziel (mit eigenem Pfeil im Modus
"Automatisch"), die Karte bleibt zu ("In Instanzen öffnet Amisia die Weltkarte nicht."), und ein Wegpunkt, den Amisia
löschen wollte, geht erst beim Verlassen der Instanz, nach dem Kampf oder nach der Kampfsperre, außer ein neues Ziel
von Amisia steht dort.
**Grund:** Fehler aus dem Spiel 2026-11-05 nach 2.54.x: "GetAuraDataByIndex(): Auras cannot be accessed when secret
while tainted by 'Amisia'" in `ShouldShowMawBuffs` aus dem Szenario-Teil des Objective Trackers. Diese Aufrufe lassen
den Tracker sich im nächsten Frame mit Amisias Taint neu aufbauen; in einer Instanz liest sein Szenario-Teil Auren,
die dort geheim sind. F-134 öffnete die Karte per Klick und setzte Ziele an Dungeon-Eingängen, die beim Betreten
gelöscht wurden.
**Folge:** In Instanzen kein Spiel-Wegpunkt und keine Karte aus Amisia; neue Aufrufe von Client-Funktionen, die den
Tracker, die Karte oder die Verfolgung anstoßen, gehen durch `Map.ClientSafe()`.
**Durchgesetzt durch:** `tests/test_map_client_safe.lua`.

## D-63 Questweg: Quelle der Questangaben, Zieltext nur selbst gesehen

**Datum:** 2026-11-05
**Entscheidung:** Der Questweg der Dungeon-Quests (F-135) zeigt nur, was die Daten (AllTheThings, MIT, D-04) oder
eigene Beobachtungen dieses Clients sagen; eigene Beobachtungen gehen vor (Questgeber und Ort, Abgabe-NPC und Ort,
Zieltext). Den Zieltext liest der Sammler nur im Annahmefenster und nur für Dungeon-Quests und ihre Vorquests
(Sammler-Version 3: `...;giverName;enderName;objective;title`); Abgabe-NPC-Name und Zieltext gehen nicht in den
Quellen-Austausch der Gilde (gesendet wird das Format 2), gehörte werden geleert und nie gezeigt. Über die
SavedVariables kommen die eigenen Beobachtungen beim nächsten `build.py data` in `tools/quest_obs.json` und in die
Daten für alle. Keine englischen ATT-Hinweise, keine Texte anderer Quest-Datenbanken (D-03). Brotkrumen-Quests
sind optional und zählen nicht im Fortschritt; höchstens 15 Schritte werden gezeigt.
**Grund:** Spec `docs/specs/2026-11-05-questweg.md` ("Passt, bauen"): der Spieler soll genau sehen, wo und wie er
die Dungeon-Quests bekommt; ein einzelnes Gildenmitglied soll keine falschen Texte oder Orte verbreiten können.
**Folge:** Fehlt ein Ort oder eine Abgabe, steht "Ort unbekannt" bzw. "noch unbekannt", bis jemand mit Amisia die
Quest sieht und die Daten neu gebaut werden.
**Durchgesetzt durch:** `tests/test_quest_path.lua`, `tests/test_collect_sync.lua`,
`tools/tests/test_collect_records.py`, `tools/tests/test_build_dungeonquests.py`.

## D-64 Keine Datenlieferanten der Weltkarte: Amisias Pins auf eigener Ebene

**Datum:** 2026-11-05
**Entscheidung:** Amisias Weltkarten-Pins (Ziele, Wünsche, Questgeber, Eingänge, Flugmeister, Zeppeline, Schiffe)
liegen auf einer eigenen Ebene unter der Leinwand der Karte (`WorldMapFrame.ScrollContainer.Child`), als Amisias
eigene Knöpfe in eigenen Pools. Kein `AddDataProvider`, kein `AcquirePin`, keine Pin-Pools oder Mixins der Leinwand,
keine Schreibzugriffe auf `WorldMapFrame` und seine Kinder, keine ersetzten Skripte, keine Aufrufe von
Karten-Aktualisierungen. Die Ebene liest nur, in ihrem eigenen OnUpdate, solange die Karte offen ist; ihr OnShow setzt
nur eine Marke.
**Grund:** Fehler aus dem Spiel 2026-11-05: `[ADDON_ACTION_BLOCKED] ... 'Frame:SetPropagateMouseClicks()'` aus dem
AreaPOI-Datenlieferanten und "tainted by 'Amisia'" im Objective Tracker und Edit Mode. Ruft die Karte alle
Datenlieferanten nacheinander auf und kommt Amisias Lieferant vor einem des Clients dran, läuft der Rest der Kette
verunreinigt weiter; im Kampf werden geschützte Aufrufe blockiert. Bewährte Pin-Bibliotheken zeichnen deshalb auf
eigenen Frames.
**Folge:** `Gear/MapPin.xml` entfällt (TOC geändert: einmal WoW neu starten). Amisia öffnet die Karte weiter selbst
(`ns.MapShowOnWorldMap`, außerhalb von Instanzen und Kampf, D-62; der Nutzer wählte 2026-11-06 "Weiter selbst
öffnen"), aber seit 2.57.1 nur über `C_Map.OpenWorldMap(mapID)`: der Client feuert `WORLD_MAP_OPEN`, und der eigene
Ereignis-Handler der Karte öffnet sie auf dieser Karte, ohne Taint. Amisias eigener Aufruf von `OpenWorldMap`
(Lua des Clients) und `WorldMapFrame:SetMapID` lief verunreinigt durch den Panel-Manager und die Datenlieferanten; der
Taint blieb, bis der Spieler die Karte schloss, und dann wurde `SetPassThroughButtons` im Questlieferanten blockiert
(Fehler aus dem Spiel 2026-11-06, mit 2.57.0, Stack: Schließen-Knopf, `HideUIPanel`, `QuestDataProvider:AddQuest`).
Ohne `C_Map.OpenWorldMap` öffnet Amisia nichts und sagt "Öffne die Weltkarte mit M.". Kein Addon-Code ruft
`OpenWorldMap(`, `ToggleWorldMap(` oder `:SetMapID(`.
Nachtrag 2026-11-06 (Spiel, Dungeon): Der Taint sitzt im Panel-Manager des Clients (`FramePositionDelegate`): ruft ein
Addon `ShowUIPanel`/`HideUIPanel` (auch über `OpenWorldMap`, `ToggleCalendar`) für ein Fenster mit Bereich, schreibt
dessen Lauf die Felder des Managers verunreinigt, und jeder spätere Wechsel eines Fensters liest sie, bis `/reload`
("BLOCKIERT: Amisia -> Frame/Button:SetPassThroughButtons" mitten im Kampf). Darum ruft Amisia keine dieser
Funktionen: "Klassen suchen" (Duelle) lässt die /who-Liste offen, die die Antwort öffnet (SetWhoToUi zurück, sobald
sie schließt), und das Anmeldefenster zeigt statt "Kalender öffnen" den Knopf "Warum?" mit dem Kalenderknopf an der
Minimap. Offen bleibt der Klick mit Strg/Shift auf ein Item (`HandleModifiedItemClick`, Anprobe), wie in jedem Addon.
**Durchgesetzt durch:** `tests/test_map_layer_safe.lua` (statische Suche, auch `ShowUIPanel(`, `HideUIPanel(`,
`ToggleUIPanel(`, `ToggleCalendar(`, und Schutz im Stub), `tests/test_duels_who.lua`, `tests/test_map_pins.lua`,
`tests/test_map_places.lua`.


## D-65 Eigene Fundort-Hinweise für Dungeon-Quests, die keine Quelle kennt

**Datum:** 2026-11-06
**Entscheidung:** Für Dungeon-Quests, deren Start oder Abgabe weder AllTheThings noch der Sammler kennt, gibt es
von Hand gepflegte Hinweise in `tools/quest_hints.json`: der Dungeon, in dem ein Start-Gegenstand liegt (der Knopf
"Karte" führt zum Eingang), der Abgabe-NPC (eine NPC-Kennung der Daten mit deren Name und Ort, oder nur ein Name)
und die Fundorte im Dungeon als eigene Sätze auf Deutsch und Englisch (Feld 22 der Questdaten). Sie füllen nur
Lücken: Werte der Daten bleiben, eigene Beobachtungen des Sammlers gehen weiter vor (D-63). Die Schrittkarte des
Questwegs zeigt die Fundorte unter "Annehmen" mit dem grauen Satz "nach Berichten von Spielern, von Amisia nicht
selbst gesehen". Erste Quest: "Wappen von Lordaeron" (95204 Horde, 95189 Allianz) in Ruins of Lordaeron.
**Grund:** Wunsch des Nutzers 2026-11-06 nach einer Websuche zu dieser Quest ("bau es ins addon damit man es genau
sieht und leicht versteht wo man es bekommt findet"). AllTheThings vermerkt das Objekt als fehlend, der Sammler
lernt Fundorte im Dungeon nicht. Ausnahme von D-02/D-63 nur für solche Lücken: Einzelne Quests werden von Hand
nachgeschlagen und in eigenen Worten beschrieben; keine kopierten Texte, keine Sammlungen, keine Quelle wird
genannt oder verlinkt, nichts wird per Skript geladen (D-03).
**Folge:** Ein neuer Hinweis ist ein Eintrag in `tools/quest_hints.json` und ein `build.py data`. Orte ohne
bestätigte Koordinaten bekommen keinen Wegpunkt (D-13); Lady Dena Kennedy (95189) steht ohne Ort, bis der Sammler
die Abgabe sieht.
**Durchgesetzt durch:** `tools/tests/test_build_dungeonquests.py::test_hints_fill_gaps_only_and_render_as_field_22`,
`tools/tests/test_build_dungeonquests.py::test_the_shipped_hints_name_quests_of_the_data`, `tests/test_quest_path.lua`,
`tests/test_quest_path_en.lua`.

## D-66 Lauf-Planer: Lohn einer Quest und Graustufe nach eigenen, offenen Regeln

**Datum:** 2026-11-06
**Entscheidung:** Spec `docs/specs/2026-11-06-dungeon-run-planner.md` (F-139). Der Lohn einer Dungeon-Quest ist
(EP der offenen Pflichtschritte in Prozent einer Stufe + 25 für ein Upgrade) / (1 + 0,5 je Zone draußen, in die
ihre offenen Schritte führen); "Muss" ab 20, "Lohnt" ab 8, sonst "Kann weg"; "Später", wenn die eigene Stufe unter
der Mindeststufe liegt; "?", wenn weder EP noch ein Upgrade bekannt sind (auf der Höchststufe zählen nur Upgrades).
Schritte selbst kosten nichts, weil jeder Schritt eigene EP bringt. Nur selbst gesehene EP zählen (QuestXP, keine
geschätzten Werte fremder Quellen); Quests, die die eigene Stufe noch nicht erreicht, zählen nicht in der Laufbilanz.
Die Graustufe: grau, sobald die eigene Stufe um mehr als die "green range" über der Queststufe liegt; für die eigene
Stufe die Antwort des Clients (`GetQuestGreenRange`), für spätere Stufen die Graustufe der Kreaturen, die das
Questlog teilt (`GetRelativeDifficultyColor`): 4 + floor(Stufe / 10) bis 39, floor(Stufe / 5) bis 59, 8 darüber, bis
Stufe 5 nie grau. Die Bosse stehen in der Reihenfolge der Client-Tabelle `DungeonEncounter` (`OrderIndex`, nur die
Schwierigkeit 0 und 1 des normalen Dungeons); gezeigt werden die Bosse der Item-Daten (ohne "Trash"), nach dieser
Reihenfolge sortiert. Ein Boss gilt als Ziel einer Quest, wenn ihr Zieltext seinen Namen als ganze Wörter enthält
oder einen langen Namen (ab 8 Buchstaben) ohne Leerzeichen; ein Halt, den mehrere Quests teilen, steht einmal da.
**Grund:** Wunsch des Nutzers 2026-11-06 ("du musst deutlich kreativer werden", dann "Ja, alles bauen"). Die
erste Fassung bestrafte jeden Schritt einer Questreihe und nannte große Upgrades am Ende langer Reihen "Kann weg";
das Review fand die Tabelle der Erfahrung ("zero difference") statt der Graustufe (Quests wurden Stufen zu spät
grau), gemischte Schwierigkeiten in der Bossreihenfolge und doppelte Halte. Ob der Client auf Forever genau diese
Graustufe nutzt, prüft `/dump GetQuestGreenRange()` im Spiel (Stufe 30: 7).
**Folge:** Die Werte stehen in `D.WORTH` (Gear/Dungeons.lua); der Tooltip jeder Quest zeigt die Teile. Keine
Gruppen-Abstimmung und keine Twinks (keine Daten); beides bräuchte eine eigene Spec.
**Durchgesetzt durch:** `tests/test_dungeon_run_plan.lua`, `tools/tests/test_build_dungeons.py::test_reading_the_client_tables`.

## D-67 Klare Linie: höchstens ein roter Knopf je Ansicht, Erklärungen hinter dem "i", Zeilenknöpfe erst unter der Maus

**Datum:** 2026-11-06
**Entscheidung:** Die Oberfläche wird in drei Schritten ruhiger (F-140). Regeln: (1) Der Fensterkopf hat keine roten
Knöpfe: der Raid-Status steht mittig mit einem Pfeil (`W.ArrowButton`), der ein Menü öffnet ("Aufnahme
pausieren/fortsetzen", "Zur Offiziersansicht/Raider-Ansicht"); rechts das Zahnrad des Questlogs (`questlog-icon-setting`,
`W.IconButton`) für die Einstellungen der Seite (D-49) und das "i" der Hilfe des Spiels (`Interface\common\help-i`).
(2) Erklärungen ("Klick auf ...", Legenden, Datenstand) stehen nicht mehr unten auf der Seite: eine Fußzeile
`{ "hint", help = true }` wird nicht gezeichnet, das "i" zeigt ihren Text (`W.HelpLines`); ohne Erklärung fehlt das "i".
Zustände (Zähler, "Noch keine Wünsche", Zeichenzahl des Discord-Texts) bleiben sichtbar. Seiten mit eigener Breite
(Seitenfenster) behalten ihre Fußzeile. (3) Knöpfe einer Listenzeile ("Karte", "Wegpunkt", "Wunsch", "Aus",
"Entfernen") erscheinen erst, wenn die Maus auf der Zeile steht (`W.RowAction`: nur die Deckkraft folgt der Maus,
gezeigt und versteckt wird wie vorher; `W.PinRowActions` hält sie sichtbar, wie auf der Karte des nächsten
Questschritts). (4) Ziel je Ansicht: höchstens ein roter Knopf; die Zahl je Seite steht in
`tools/ui_red_budget.json` und darf nur sinken. (5, Schritt 2) Ansichten und Auswahlen sind Textreiter (`W.Tab`: goldenes
Wort, das gewählte weiß über einer dünnen goldenen Linie), An/Aus-Filter Textreiter mit dem kleinen Häkchenfeld des
Spiels (`W.TabCheck`), Werte zum Wählen das Dropdown-Feld des Spiels (`W.Choice` auf `W.Picker`, statt bei jedem Klick
zum nächsten Wert zu springen); jede Aktion außer der einen wichtigsten einer Ansicht ist ein ruhiger Link (`W.Link`:
"Warum?", "Alle auf Karte", "Zurück", "Filter zurücksetzen"); die Karten der Übersicht haben Links statt roter Knöpfe,
ein Klick auf die Karte öffnet. Rot blieben bis Schritt 3: die eine Hauptaktion je Ansicht, Knöpfe in Zeilen (unter der Maus), das
Würfel-Fenster, der Vergabe-Dialog, die Einrichtung. Listen nehmen den Platz der weggefallenen Fußzeilen (`fill`).
(6, Schritt 3) Die übrigen Seiten und die Seitenfenster folgen derselben Regel: Ausrüstungstabelle (Specs und Ansichten
als Textreiter, Quellen mit Häkchen, Gewichtung und Fraktion als Links), Ziele-Fenster, Anmeldung, Raid-Kalender,
Soft-Reserve-Import, Einrichtung, Selbsttest, Offiziers-Würfelfenster (MS/OS als Textreiter, "Vergeben" beim Gewinner
und bei einem Gleichstand immer, sonst unter der Maus) und Vergabe-Dialog ("Vergeben" rot, Bank/Entzaubern/Abbrechen Links); "Hoch" und das
rote x der Lootregeln und "Nochmal" im Feedback-Ausgang unter der Maus (eine verlorene Meldung zeigt es immer),
"Bestätigen" im Abgleich als Link. Mit
Absicht mehr als ein roter Knopf: das Würfel-Fenster der Raider (Mainspec, Offspec, Passen: eine schnelle Antwort im
Kampf), der Bestätigen-Dialog, die Einrichtung, wo zwei Gruppen je ihre Aktion haben (Gildenbank-Bedarf: Setzen und
Spenden zusagen), der Lootregel-Editor (Hinzufügen und Übernehmen eines Vorschlags) und die Karte des nächsten
Questschritts. Die Regel "red" zählt seit Schritt 3 auch die Seitenfenster.
**Grund:** Nutzer 2026-11-06: "finde das ganze ui zu unübersichtlich keine klare linie und so ist so voll nicht
aufgeräumt"; nach einem Entwurf mit acht Regeln "Ja, Schritt 1". Die Schnappschüsse zeigten bis zu 19 rote Knöpfe und
Chips auf einer Seite (1471 auf 240 Seitenbildern), drei rote Knöpfe im Kopf jeder Seite und auf 13 Seiten graue
Erklärzeilen unten.
**Folge:** Seit D-06 (2.4.5) war jeder Chip ein roter Knopf; seit Schritt 2 sind Ansichten und Filter Textreiter (D-06
geändert). Die Zahl roter Knöpfe und Chips auf den Seitenbildern fiel von 1471 auf 1354 (Schritt 1), 280 (Schritt 2)
und 147 (Schritt 3); mit den Seitenfenstern sind es 200 auf 273 Bildern.
Die Knöpfe "Pausieren", "Raider-Ansicht"/"Offiziersansicht" und "Einstellungen" im Kopf entfallen (Menü und Zahnrad
statt dessen); `/amisia pause` und `/amisia ansicht` bleiben.
**Durchgesetzt durch:** `tools/tests/test_ui_layout.py::test_rule_red_budget` (Regel "red" in `build.py check`),
`tests/test_widgets.lua`, `tests/test_style.lua`, `tests/test_nav_find.lua`.

## D-68 Eine Seitenleiste: Gruppen wie im Auktionshaus statt Reiter unten und Seitenreiter rechts

**Datum:** 2026-11-07
**Entscheidung:** Spec `docs/specs/2026-11-07-seitenleiste.md` (F-141), Schritt 1 von 4 der UI-Überholung. Das
Hauptfenster hat nur noch einen Weg zu den Seiten: links die Seitenleiste unter dem Suchfeld. Jede Gruppe aus
`ns.PANEL_GROUPS` (Raid, Charakter, Welt, Gilde, Amisia) ist ein Balken der obersten Ebene der Kategorienliste des
Auktionshauses mit dem Plus oder Minus des Questlogs rechts; immer nur eine ist aufgeklappt (wie im Auktionshaus),
darunter ihre Seiten als Balken der Unterkategorie, unter der offenen Seite "Einstellungen" deren Reiter und Abschnitte
(D-49, dritte und vierte Ebene), und die Seitenfenster der Gruppe als eigene Zeile direkt unter ihrer Seite, mit dem
Maximieren-Zeichen des Chatfensters (Ausrüstungstabelle, Ausrüstungsziele, Talentrechner unter Charakter;
Würfelfenster und Soft-Reserve-Import unter Raid, nur Offiziersansicht); ein Klick öffnet oder schließt das Fenster,
die Zeile ist weiß, solange es offen ist. Ein Klick auf eine zugeklappte Gruppe öffnet ihre zuletzt gewählte Seite,
ein Klick auf die offene klappt sie zu (die Seite bleibt, die Gruppe leuchtet). Die Leiste rollt, statt Zeilen zu
schrumpfen, und rollt die geöffnete Seite ins Bild. Die Reiter unter dem Fenster (`PanelTabButtonTemplate`) und die
Seitenreiter rechts (`LargeSideTabButtonTemplate`) entfallen. Die Höhe lässt sich am Größengriff des Chatfensters
unten rechts ziehen, `T.MAIN.H_MIN` bis `H_MAX` (560 bis 860), nie höher als der Bildschirm; `T.PAGE_H` folgt, Listen
mit `fill` und die Bossliste der Dungeons wachsen mit (`W.FillTo`, `W.FitLists`, `list:Fit`); gemerkt in
`settings.window.h`, "Fensterposition zurücksetzen" setzt sie zurück. Die Breite bleibt 806 (alle Seiten sind 602 breit).
Kalender und Duelle ziehen in Gilde; die Gruppen "gear", "calendar" und "pvp" gibt es nicht mehr. Gespeicherte Werte
ziehen einmal je Sitzung um: jede Seite in `settings.window.pages` unter ihre heutige Gruppe (bei zwei alten Gruppen in
einer gewinnt die erste nach Namen), ein unbekannter `tab` wird die Gruppe seiner letzten Seite.
**Grund:** Nutzer 2026-11-07: "ich brauche eine ui overhall ... aber ich will es im WoW Forever classic style", nach
einem Vergleich mit einem anderen Addon (eine gruppierte Seitenleiste, Start- und Detailseiten, aufklappbare Zeilen) und
einem Entwurf in vier Schritten; zur Spec "Passt" mit allen drei Vorschlägen (Gruppen, Seitenfenster als Zeilen, nur die
Höhe ziehbar). Drei Wege gleichzeitig (Reiter unten, Liste links, Reiter rechts) waren der Hauptgrund für "keine klare
Linie" (D-67).
**Folge:** D-45 verliert die Reiter unten und die Seitenreiter, D-52 den Reiter PvP (Duelle in Gilde). Eine neue Seite
braucht `group` aus `ns.PANEL_GROUPS`; eine neue Gruppe ist ein Balken mehr in der Leiste. Ein neues Seitenfenster
kommt in `SIDE_WINDOWS` (MainFrame) mit Gruppe und Seite, und sein Fenster ruft bei Zeigen und Verstecken
`ns.UpdateSideTabs`. Seiten, die Höhen aus `T.PAGE_H` rechnen, tun das nur über `fill`/`W.FillTo`. Ohne die Balken des
Auktionshauses (TBC, Era) bleibt der Fallback der Rezeptliste (Leuchten und Hover).
**Durchgesetzt durch:** `tests/test_main_sidebar.lua`, `tests/test_main_sidebar_review.lua`, `tests/test_nav_find.lua`,
`tests/test_style.lua`, die Layoutregel "nav" (`tools/ui_layout.py`).

## D-69 Seitenkopf, Startseiten mit Kacheln, aufklappbare Zeilen (Schritte 2 bis 4 der UI-Überholung)

**Datum:** 2026-11-07
**Entscheidung:** Schritt 2 (F-142): Über jeder Seite steht im Hauptfenster ein Seitenkopf (`T.MAIN.PAGE_HEAD`, 38
hoch): der Name der Seite (`T.FONT.big`, gold), darunter ihre eine Zeile (`sub` der Seite, `T.FONT.hint`; ein Text), darunter eine goldene Linie, die zu beiden Rändern ausläuft (`W.GoldRule`, die Verläufe des
Clients; ohne `SetGradient` eine gleichmäßige Linie). Das "i" und das Zahnrad (D-49, D-67) sitzen rechts in diesem
Kopf statt im Fensterkopf; der Fensterkopf hat nur noch den Raid-Status mit seinem Menü. Das Fenster wird um den
Seitenkopf höher (598, ziehbar 598 bis 898, D-68), die Seite bleibt 602 x 478: keine Seite ändert ihr Layout.
**Grund:** Nutzer 2026-11-07: "mach die nächsten schritte" nach Schritt 1 (D-68); der Entwurf der UI-Überholung
hatte als Schritt 2 "Titel, Unterzeile und eine goldene Linie" (wie die Hub-Seiten eines anderen Addons, im Look des
Clients). Ohne Kopf war der Name der offenen Seite nur in der Seitenleiste zu sehen.
**Folge:** Eine neue Seite bringt `sub` mit (deutsch in `L[]`, englisch in `Locales/enUS_core.lua`). Wer Höhen der
Seite rechnet, nimmt weiter `T.PAGE_H` (478 bei 598).
**Nachtrag 2026-11-07 (Schritt 3, F-143):** Die Seiten Dungeons und Raids haben zwei Ansichten statt "kleine
Tabelle oben, Bild, Bosse unten". Die Startseite ("Alle Dungeons"/"Alle Raids"): Kopfzeile wie bisher (Spezialisierung,
auf Dungeons die Reiter Level/Wert/Kette), der nächste Dungeon und warum, darunter jeder Dungeon (Raid) als Kachel
(`T.DCARD`: 192 x 84, 7 px Abstand, drei je Zeile einer `W.List` mit `fill`, die mit der Fensterhöhe wächst): oben
sein Bild, zum unteren Rand mit dem Verlauf des Clients abgedunkelt (ohne `SetGradient` gleichmäßig), der Name in Gold
darauf, darunter Level und Passung (Raids: Größe, Passung, die eigene Raid-ID) und "N Upgrades · +X je Lauf · Wert V";
der empfohlene mit einem grünen "Empfohlen" rechts oben, der gewählte mit hellerem Goldrahmen, unpassende entsättigt
mit grauem Namen; die Maus zeigt den Tooltip der früheren Zeile. Ein Klick wählt und öffnet die Detailseite: links in
der Kopfzeile der ruhige Link "< Alle Dungeons" ("< Alle Raids") vor der Spezialisierung, die Reiter und die Texte des
nächsten Dungeons fehlen, direkt unter der Kopfzeile das Bild, darunter Bosse/Quests mit Wegpunkt und die Liste bis
zum unteren Rand. Das Questjournal und der Laufplaner öffnen von dort wie bisher, ihr "Zurück" führt zur Detailseite.
Die Ansicht liegt nur im Speicher (kein neuer Schlüssel in `AmisiaDB`): die erste Öffnung je Sitzung zeigt die
Startseite, das Verlassen der Seite behält die Ansicht; `ns.ShowDungeon`, `ns.ShowDungeonQuest`, `ns.ShowRaid`, die
Suche und die Eingänge auf der Karte öffnen die Detailseite. Die Spaltenköpfe und die Tabelle entfallen. Grund: der
Entwurf der Überholung (Startseiten mit Kacheln wie die Hub-Seiten eines anderen Addons, im Look des Clients); die
Bossliste beginnt auf Dungeons rund 200 px, auf Raids rund 150 px höher. Das Zeichen "<" statt "‹": wie das
"< Zurück zu den Dungeons" des Journals, und die Schrift des Clients hat das "‹" nicht sicher.
**Nachtrag 2026-11-07 (Schritt 4, F-144):** Auf den Detailseiten von Dungeons (Teil Bosse) und Raids ist die
Bossliste aufklappbar. Jeder Boss ist eine Kopfzeile (`T.DBOSS`): links das Plus oder Minus des Questlogs
(`UI-PlusButton-Up`/`UI-MinusButton-Up`, wie die Seitenleiste, 14 px), der Name in Gold ab 22 px, "je Lauf +X" ab
228 px; zugeklappt fehlen seine Itemzeilen, statt dessen steht rechts in der Zeile eine Leiste von höchstens sechs
Itemsymbolen (18 px, 2 px Abstand, 1 px Rahmen in der Farbe der Qualität, in der Reihenfolge der Itemzeilen) und
"+N" für den Rest. Ein Symbol zeigt den Tooltip seines Items; ein einfacher Klick darauf klappt den Boss auf, Strg-,
Shift- und Rechtsklick tun, was sie auf seiner Zeile tun (Anprobe, Link, Menü); die Maus darauf zeigt den Boss im Bild. Ein Klick auf die Kopfzeile klappt
auf oder zu; ein Boss ohne Items hat weder Zeichen noch Leiste. Vorgabe beim ersten Zeigen eines Dungeons (Raids):
aufgeklappt sind die Bosse mit einem Upgrade (ein Item, das seine Zeile als "Upgrade" markiert: Schwelle der Ausrüstungsdaten, eigene Wahl nach D-55), die anderen
zugeklappt. In der Zeile der Überschrift steht der ruhige Link "Alle aufklappen" ("Alle zuklappen", wenn alle offen
sind), auf Dungeons rechts von Bosse/Quests, auf Raids links von Wegpunkt, nur im Teil Bosse und nur, wenn ein Boss
Items hat; die Überschrift endet vor Reitern und Links (`placeParts`). Der Zustand liegt nur im Speicher (kein
Schlüssel in `AmisiaDB`): je Seite und Dungeon (Raid) die Menge der aufgeklappten Bosse; ein anderer Dungeon hat seine
eigene Vorgabe, Höhe des Fensters (`W.FitLists`) und Neuzeichnen behalten ihn, beim Zuklappen rückt die Liste nach
oben, soweit sie kürzer wird. Grund: der Entwurf der Überholung (aufklappbare Zeilen wie in einem anderen Addon, im
Look des Clients); eine Bossliste mit allen Items war auf großen Dungeons und Raids eine lange Rolle.
**Durchgesetzt durch:** `tests/test_style.lua` (Lage von Kopf, Linie, "i" und Zahnrad, Seite 602 x 478),
`tests/test_mainframe.lua`, `tests/test_settings_pages.lua`, `tests/test_dungeon_cards.lua` (Schritt 3),
`tests/test_boss_fold.lua` (Schritt 4).

## D-70 Hauptfenster nach dem Hub eines anderen Addons: Kopf mit Logo, Überschriften, Symbolzeilen

**Datum:** 2026-11-08
**Entscheidung:** Schritt 1 der Spec `docs/specs/2026-11-07-hauptfenster-journal.md` (F-145):
- Die Seitenleiste hat oben einen Kopf (`T.MAIN.NAV_HEAD`, 40 hoch):
  - das Amisia-Logo rund auf einer schwarzen Scheibe;
  - "Amisia" in Gold;
  - darunter grau die Version und die Ansicht;
  - darunter die goldene Linie (`W.GoldRule`).
- Darunter stehen das Suchfeld und die Liste.
- Jede Gruppe mit einer sichtbaren Seite ist eine goldene Überschrift in Großbuchstaben, ohne Balken. Ab der zweiten steht die goldene Linie darüber.
- Die Gruppen stehen immer offen: Unter jeder Überschrift kommen alle ihre Seiten und Seitenfenster als Unterkategorie-Balken des Auktionshauses. Jede Zeile trägt ihr Symbol (`T.NAV_ICONS`, 14 px) vor dem Namen.
- Das Auf- und Zuklappen der Gruppen von D-68 entfällt (kein `openGroup` mehr); ein Klick auf eine Überschrift tut nichts.
- Was nicht passt, wird gescrollt. Die offene Seite wird wie bisher in Sicht gescrollt.
- Die Version steht nicht mehr im Fenstertitel.

**Grund:** Nutzer 2026-11-07: "genauso wie" das Hub-Fenster des Vorbilds, im Forever-Classic-Rahmen; freigegeben 2026-11-08 ("Passt, Schritt 1").

**Folge:**
- **Symbole:** Sie sind nur Marken aus dem Client: die Verfolgungssymbole der Minimap, Gossip-Symbole, Kartenmarken, Geld- und Würfelgrafik. Zauber- oder Gegenstandssymbole kommen nicht in Frage. Eine neue Seite trägt ihr Symbol in `T.NAV_ICONS` ein; ohne Eintrag bleibt die Zeile ohne Symbol.
- **Zeilen:** Bei 598 Höhe passen 21 Zeilen (vorher 23), höhere Fenster zeigen mehr.
- **`ns.ShowTab(group)`** öffnet weiter die letzte Seite der Gruppe. `settings.window.tab` und `pages` bleiben.
- **Symbole nur, wo der Client sie hat:** Ein Atlas wird nur gesetzt, wenn ihn der Client kennt, eine Datei nur, wenn `GetFileIDFromPath` sie findet; sonst bleibt die Zeile ohne Symbol. Der Selbsttest (Abschnitt Atlanten) nennt fehlende Symbole.

**Durchgesetzt durch:** `tests/test_main_sidebar.lua` (Kopf, Überschriften, Symbole, kein Aufklappen), `tests/test_style.lua` (jede Seite hat ein Symbol, keines aus `Interface\Icons`, Abstände und Zeilen), die Layoutregel `nav` (`tools/ui_layout.py`).

## D-71 Hauptfenster in der Breite ziehbar und zu einer Leiste minimierbar

**Datum:** 2026-11-08
**Entscheidung:** Schritt 2 der Spec `docs/specs/2026-11-07-hauptfenster-journal.md` (F-145):
- **Breite:**
  - Der Griff unten rechts zieht Breite und Höhe. Die Breite reicht von `T.MAIN.W_MIN` 806 bis `W_MAX` 1440 und nie über den Bildschirm hinaus. Sie steht in `settings.window.w`, nil bei 806. "Positionen zurücksetzen" setzt sie zurück.
  - `T.PAGE_W` bleibt 602, die Breite, für die jede Seite gebaut ist; `T.PAGE_W_NOW` ist die Breite, die die Seite jetzt hat.
  - Was an den rechten Rand der Seite geankert ist, rückt mit: Bänder, Listen ohne feste Breite, die Detailfläche. Das füllende Element eines Bands nimmt den Platz (`W.FitWidths` platziert die Bänder am Ende des Ziehens neu).
  - Feste Breiten aus `T.PAGE_W` bleiben. Was mehr will, meldet sich mit `W.FollowWidth(owner, fn)` an. Die Kacheln der Dungeons und Raids tun das: 3 bis 6 je Reihe (`T.DCARD.MAX_COLS`).
  - Die Statuszeile ist so breit wie das Fenster.
  - Die Layoutregeln laufen zusätzlich in der Ansicht `wide` (Experte, Fenster 1440 breit).
- **Minimieren:**
  - Links vom roten X sitzt der rote Knopf des Clients zum Verkleinern (`UIPanelHideButtonNoScripts`; ohne die Vorlage die alte Grafik `UI-Panel-SmallerButton`).
  - Der Rahmen bekommt dazu die Ecke für zwei Knöpfe, wie die minimierbaren Fenster des Clients (`SetBorder("PortraitFrameTemplateMinimizable")`).
  - Im flachen Fenster von TBC und Era ist der Knopf 20 px groß und mittig neben dem alten X.
  - Ein Klick versteckt das Fenster und zeigt an seiner oberen rechten Ecke die Leiste `AmisiaMiniBar`: 214×36 im Tooltip-Rahmen, mit Logo, "Amisia", dem Namen der offenen Seite und einem kleinen X.
  - Die Leiste lässt sich ziehen. Ein Klick auf sie öffnet das Fenster mit seiner oberen rechten Ecke dort, wo die Leiste ist, und merkt die Stelle. `/amisia` und das Minimap-Symbol öffnen das Fenster ebenso, die Leiste geht dabei weg. Das X der Leiste schließt sie.
  - Die Leiste wird nicht gespeichert: Nach `/reload` ist sie zu.

**Grund:** Nutzer 2026-11-07: Breite frei ziehbar und Minimieren zur Leiste wie beim Vorbild (Auswahl in der Rückfrage), Spec freigegeben 2026-11-08; "Committen, dann Schritt 2".

**Folge:**
- Eine neue Seite legt sich weiter auf 602 aus, ankert aber, was rechts sitzt, an den rechten Rand (Scaffold-Bänder tun das von selbst).
- Wer die Breite für mehr nutzen will (Spalten, Kacheln), meldet sich mit `W.FollowWidth` an und liest `T.PAGE_W_NOW`.

**Durchgesetzt durch:** `tests/test_main_size.lua` (Ziehen, Grenzen, Merken, Zurücksetzen, Bänder, Leiste), `tests/test_dungeon_cards.lua` (Kacheln je Breite), die Layoutregeln in der Ansicht `wide` (`tools/ui_layout.py`).

## D-72 Journal für Dungeons und Raids: Filter, Lauf, Reiter, Instanzkarte, Zugang

**Datum:** 2026-11-08
**Entscheidung:** Schritte 3 bis 5 der Spec `docs/specs/2026-11-07-hauptfenster-journal.md` (F-146).
- **Start:**
  - Unter der Kopfzeile kommt eine Filterzeile: das Suchfeld (Instanz, Bosse, Beutenamen, die der Client kennt, Questtitel; ab 2 Zeichen), die Reiter Alle/Passend/Quests (Raids ohne Quests) und "Wo bin ich". Der Filter liegt nur im Speicher.
  - Jede Kachel hat oben links ein Abzeichen: Totenkopf mit "1/4" des Laufs, Questzeichen mit der Zahl offener Quests, bis zu zwei Schlüssel (grau, solange sie fehlen).
  - Die Instanz, in der man steht, trägt "Hier bist du" und den vollen Goldrand.
- **Öffnen:** In einer Instanz öffnet die Seite deren Detail, einmal je Betreten (`ns.Runs.entry`). Das gilt auch, wenn man bei offener Seite hineingeht.
- **Lauf** (`Gear/Runs.lua`):
  - Die Kills zählen nach Encounter-ID (ENCOUNTER_END mit Erfolg, BOSS_KILL) in der Instanz, in der man steht.
  - Ein neuer Lauf beginnt in einer anderen Instanz. Im Dungeon beginnt er auch nach 30 Minuten draußen; das Ausloggen zählt als Verlassen. Im Raid hält er, solange die Raid-ID gilt.
  - Die Meldung des Clients über das Zurücksetzen beendet den Lauf ihrer Instanz; steht man darin, beginnt ein frischer.
  - Ein gezielt geöffneter Dungeon (Suche, Karte, Ziele) hat Vorrang vor dem Sprung in die Instanz, in der man steht.
  - Ein Boss lässt sich von Hand markieren, aber nur in der Instanz oder für ihren laufenden Lauf.
  - Gespeichert wird je Charakter in `bis.chars[name].run`.
  - Die Encounter-IDs stehen in den Fakten (`enc`, aus DungeonEncounter, in der Reihenfolge von `order`).
- **Detail:**
  - Unter dem Bild stehen Reiter: Übersicht, Karte, Quests (nur Dungeons), Wunschliste, Zugang (nur mit Schlüssel). Der Reiter wird in `settings.bis.dpart` bzw. `rpart` gemerkt. Der Wegpunkt steht am rechten Ende.
  - **Übersicht:** "1/4" mit Balken und "Lauf zurücksetzen". Ein getöteter Boss bekommt einen Haken und wird grau; Rechtsklick markiert.
  - **Wunschliste:** Bosse mit gewünschten oder empfohlenen Items, nur diese. Die Meldung beim Drop ist der bestehende Hinweis "Wunsch droppt!" mit Ton.
  - **Karte:** die Kartengrafik des Clients für die Ebenen der Instanz, Mausrad zoomt (1 bis 6), Ziehen verschiebt, Pfeile wechseln die Ebene, dazu der Pfeil des Spielers, wo der Client ihn verrät.
    - Die Ebenen kommen aus den Fakten (`maps`, aus UiMapAssignment). Die Forever-Tabellen haben dort aber keine Dungeon-Ebenen, darum lernt Amisia sie in der Instanz selbst (`AmisiaDB.floors`: die Karte, auf der man steht, und ihre Kartengruppe).
    - Ohne gelernte Ebenen steht dort, dass man die Instanz einmal betreten muss; ohne Grafik "Für diese Instanz hat das Spiel keine Karte."
  - **Zugang:** je Schlüssel der Fakten (`keys`, aus `tools/forever_dungeon_keys.json`, Item-IDs gegen ItemSparse geprüft) Name, nötig/optional, wofür, vorhanden/fehlt und die Quests dahin. Ein Klick setzt den Wegpunkt.

**Grund:** Nutzer 2026-11-07: Raid und Dungeons wie das Journal des Vorbilds nachbauen (Rückfrage), mit eigenem Code und eigenen Daten, denn dessen Lizenz verbietet die Übernahme. Spec freigegeben 2026-11-08; "mach alle schritte fertig".

**Folge:**
- Die Kartengrafiken und gezeichneten Karten des Vorbilds kommen nicht in Frage, nur die Grafik des Clients.
- Bosspins und Eingangspins auf der Instanzkarte gibt es nicht. Dafür fehlen Koordinaten, und Amisia lernt sie noch nicht (Spec, Frage 3).
- Bossfähigkeiten fehlen, weil Forever keine Encounter-Journal-Tabellen hat.

**Durchgesetzt durch:** `tests/test_journal_start.lua` (Lauf, Abzeichen, Filter, Öffnen), `tests/test_journal_parts.lua` (Reiter, Lauf, Wunschliste, Karte, Zugang), die Layoutregeln.

