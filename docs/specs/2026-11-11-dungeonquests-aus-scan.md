# Spec: Dungeonquests aus dem eigenen Quest-Scan

Stand: 2026-11-11 · Status: freigegeben (Nutzer 2026-11-11: Punkt 1 der angebotenen Liste) ·
Feature: F-177

## Ziel

"Dungeonquests der neuen Dungeons. Alcaz-Gefängnis, Blackmaw-Feste und Terrasse des Formers haben bei uns gar
keine Quests, Krol'dok nur zwei." Die Dungeonseiten (Teil Quests, Questweg), die Dungeon-Leiste (F-168) und
alles, was `Data/DungeonQuestData.lua` liest, zeigen die Quests dieser Dungeons, genommen aus unserem eigenen
Quest-Scan (F-172, D-104). Gelöst ist es, wenn Alcaz, Schwarzschlundfeste und Terrasse des Formers Quests
haben und Krol'dok mehr als zwei, ohne dass eine Quest im falschen Dungeon steht.

## Was es tut

- `tools/build_dungeonquests.py` nimmt jede gescannte Quest mit dem Tag Dungeon oder Schlachtzug ("D", "R"),
  die keine Quelle (AllTheThings, Hinweise) in einen Dungeon setzt, und setzt sie in den einen Dungeon, den
  ihr Titel oder ihr Ziel nennt: den Namen des Dungeons oder eines seiner Bosse (Regel D-109).
- Eine solche Quest trägt die Stufe des Scans, das Ziel (ohne die Liste "Anforderungen:"), die Belohnungen,
  die EP des Scans (neues Feld 23) und die Marke "nur aus dem Quest-Scan" (Feld 24). Questgeber, Ort und
  Mindeststufe kennt keine Quelle: sie bleiben leer.
- Die Fraktion entscheidet der Text, wo er eine Stadt oder einen Ort nur einer Fraktion nennt (meist der
  Abgabeort, "für Nara Wildmane in Thunder Bluff"); zwei Quests gleichen Titels im selben Dungeon, die eine
  mit Fraktion, die andere ohne: die andere ist die der Gegenseite. Sonst sehen beide Fraktionen die Quest.
- Seite Dungeons: Die Zeile zeigt keinen Start; der Tooltip sagt "Nur aus dem Quest-Scan: Questgeber und Ort
  noch unbekannt" und nennt die EP des Scans als Schätzung ("~6050", "aus dem Quest-Scan,
  geschätzt"). Die Karte des Questwegs sagt "Annehmen: Ort unbekannt; Amisia lernt ihn,
  sobald du die Quest siehst", "Abgeben: noch unbekannt" und trägt die Marke "nur aus dem Quest-Scan".
- Der Bau schreibt eine Liste aller nicht gesetzten Quests mit Grund nach
  `~/addons/_cache/dungeonquest_scan_report.txt` und eine Zeile mit den Zahlen ins Protokoll.

## Was es ausdrücklich nicht tut

- Keine Quest, die eine Quelle schon in einen Dungeon setzt, wechselt den Dungeon; der Scan füllt nur Lücken.
- Keine Folgequest ohne Dungeonnamen ("Traurige Nachrichten", "Schlechte Nachrichten für Folkar", "Das muss
  Thrall wissen"): dieselbe Titelkette ist keine saubere Regel.
- Kein Flügel geraten: eine Quest, die nur "Scharlachrotes Kloster" nennt, keinen Flügel und keinen Boss eines
  Flügels, bleibt draußen (ebenso "Schwarzfelsspitze" ohne "Untere"/"Obere" oder einen Boss).
- Keine Massenzuweisung in `tools/quest_hints.json`; dort bleiben einzelne Korrekturen (neu: `"dungeon"`).
- Kein Download außer den drei Tabellen in deDE einmal über `build.py tables` (D-101).

## Abläufe

1. Der Nutzer scannt im Spiel (`/amisia scan quests`), loggt aus; `python3 tools/build.py data` baut.
2. `build_dungeonquests.py` liest die Namen (Facts, `forever_dungeons_client.json`, Map/LFGDungeons/
   DungeonEncounter/AreaTable in Englisch und Deutsch, die Namen des NPC-Scans), setzt die Quests, dann
   Hinweise, eigene Beobachtungen, Stufen und EP, und schreibt die Datei.
3. Nach dem Release und `/reload` stehen die Quests im Teil Quests ihres Dungeons. Sieht ein Spieler eine
   solche Quest beim Geber, lernt der Sammler Geber und Ort (er hält Quests der Dungeonquestdaten schon fest),
   und der nächste Datenbau trägt sie ein.

## Abnahmekriterien

- Wenn du (Allianz, deutscher Client) den Dungeon "Gefängnis von Alcaz" öffnest, Teil Quests, dann stehen dort
  Quests wie "Das geheime Gefängnis" und "Das Tagebuch des Drachen", ohne Ort in der Zeile.
- Wenn du die Maus auf eine dieser Quests hältst, dann steht im Tooltip "Nur aus dem Quest-Scan: Questgeber und
  Ort noch unbekannt" und keine leere Zeile "Start:".
- Wenn du "Schwarzschlundfeste" als Allianz öffnest, dann steht "Die Wurzel des Problems" einmal da (die Quest
  für Darnassus); als Horde ebenfalls einmal (die für Thunder Bluff).
- Wenn du eine solche Quest anklickst, dann sagt der Questweg "Annehmen: Ort unbekannt; Amisia lernt ihn, sobald
  du die Quest siehst" und "Abgeben: noch unbekannt", ohne Knopf "Karte".
- Wenn du "Terrasse des Formers" betrittst, dann zeigt die Dungeon-Leiste "Quests" mit diesen Quests.

## Sonderfälle

- Englischer Client: Titel des Clients, sobald er die Quest geladen hat, sonst "Quest <Nummer>"; nie der
  deutsche Titel des Scans (`ns.ScannedQuestTitle` liefert nur die Sprache des Clients). Das Ziel steht wie bei
  den Beobachtungen des Sammlers in der Sprache des Scans.
- Leerer Scan, fehlende deutsche Tabellen: nur die englischen Namen; ohne Scan ändert sich nichts.
- Ein neuer Scan mit mehr Belohnungen oder EP verbessert die Daten beim nächsten Bau ohne Handarbeit.
- Eine Quest, deren Fraktion der Text nicht verrät, sieht jede Fraktion; Amisia schreibt dann nichts.

## Missbrauch/Vertrauen

Nichts. Nur die eigenen SavedVariables und das Scan-Archiv des Nutzers; nichts wird gesendet.

## Daten

Keine neuen `AmisiaDB`-Schlüssel, Einstellungen oder Nachrichten. `Data/DungeonQuestData.lua`: Feld 23 (EP des
Scans) und 24 (`true`: nur aus dem Scan), in `docs/ARCHITECTURE.md`. Neue Tabellen auf der Platte:
`Map`, `LFGDungeons`, `AreaTable` in deDE (`~/addons/_cache/wago/*.1.60.1.70888.deDE.csv`, 2026-11-11, wowf).
Hinweise: neues Feld `"dungeon"` in `tools/quest_hints.json`. Regel: D-109.

## Offene Fragen

1. Das "Ein aufrichtiges Angebot" (84147 ff.) trägt das Tag Dungeon, nennt aber keinen Dungeon: bleibt
   draußen. Vorschlag: so lassen.
2. Die Quests des Versunkenen Tempels (1445, 3446 ...) nennen ihn, aber der Tempel steht nicht in
   `tools/forever_dungeons.json`. Vorschlag: eigenes Feature, wenn er auf Forever ein Dungeon ist.

## Entscheidungen

- 2026-11-11: "Dungeonquests der neuen Dungeons ..." (Punkt 1 der angebotenen Liste) -> gebaut wie oben.
- Annahme (nicht gefragt): Ein Name zählt nur als ganzes Wort (mit leichter deutscher Beugung); ein Bossname
  mit Artikel ("Die Sieben", "Das Gewölbe") und ein Bossname aus einem Wort, den der deutsche Client übersetzt
  ("Zunder", "Plünderung", "Erdrutsch"), zählen nicht, ein Ein-Wort-Name nur, wo beide Sprachen ihn gleich
  schreiben ("Onyxia", "Noxxion").
- Annahme (nicht gefragt): Ein Dungeonname, der zugleich Name einer Karte außerhalb jeder Instanz ist, zählt
  nicht ("Dalaran": Stadt und Dungeon; "Stadt Dalaran" auf Englisch zählt).
- Annahme (nicht gefragt): Die Fraktionsorte sind eine eigene kleine Liste englischer Namen (Hauptstädte,
  Orte einer Fraktion, Heimatgebiete), ihre deutschen Namen aus AreaTable in deDE; Orte, deren deutscher Name
  ein gewöhnliches Wort ist ("Die Zuflucht", "Das Grabmal"), und neutrale Orte fehlen.
- Annahme (nicht gefragt): Die EP des Scans gelten als Schätzung (Stufe des scannenden Charakters unbekannt)
  und zählen im Plan "Quest-EP offen" mit "~", nach den eigenen Werten des Clients.
