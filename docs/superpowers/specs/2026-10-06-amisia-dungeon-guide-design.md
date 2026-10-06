# Amisia: Dungeon-Rangliste mit Kette und Questliste je Dungeon

Stand 2026-10-06. Nur WoW Forever 1.60.1 (TOC 16001). Baut auf dem Dungeon-Planer aus 2.3
(`Dungeons.lua`, `DungeonData.lua`, Seite "Ausrüstung" Ansicht "Dungeons",
`docs/superpowers/specs/2026-10-05-amisia-bis-own-design.md`, Abschnitt "Dungeon-Planer") und der
Karte aus 1.9 (`Map.lua`, `MapData.lua`, `tools/build_map.py`) auf. Keine Versionsänderung in
diesem Schritt; die Version setzt der Release, der diesen Zweig mit den anderen zusammenführt.

## Ziel

Der Nutzer wählte am 2026-10-06 zwei Funktionen aus den Vorschlägen:

- **10 Dungeon-Rangliste (+ Kettenmodus):** welcher Dungeon bringt *diesem* Charakter gerade am
  meisten. Der Planer rechnet das schon (`value = once + 2 * perRun`), zeigt die Liste aber nach
  Level sortiert und nur einen Treffer ("Nächster Dungeon"). Neu: die Liste nach Wert sortierbar
  (Rangliste) und eine **Kette**: das beste Ziel virtuell anlegen, neu reihen, wiederholen. So sieht
  man, ob sich nach Dungeon A der Dungeon B noch lohnt oder A dessen Upgrades schon abdeckt.
- **11 Questliste je Dungeon:** alle Quests eines Dungeons mit Vorquests, Startort (im Dungeon
  oder draußen, Zone und Koordinaten, Klick setzt den Wegpunkt), Levelbereich, Belohnungen mit
  Upgrade-Marke und erledigt/im Log/offen.

## Rahmen

- Eine Wertung: alle Zuwächse kommen aus `ns.BisGain` (Bis.lua, Gear.lua). Wenn 2.4 die Gewichte
  ersetzt, ändert sich hier nichts.
- Nur, was Tooltips, Charakterfenster und Questlog zeigen; nichts aus Kämpfen.
- UI-Texte deutsch (Latin-1, keine Gedankenstriche), Kommentare englisch, keine anderen Addons
  nennen, keine Links auf fremde Seiten. Quelle der Questdaten sind die handgepflegten Forever-Daten
  von AllTheThings (MIT, vom Nutzer am 2026-10-06 freigegeben); Copyright-Zeile und Lizenztext liegen
  in `addon/Amisia/LICENSES/AllTheThings-MIT.txt`, nicht in der Oberfläche. **Keine neuen Daten aus
  QuestieDB** (dort gibt es keine Lizenzdatei, siehe Recherche 2026-10-06).

## A. Rangliste und Kette (Dungeons.lua)

### Rangliste

- Die Ansicht "Dungeons" bekommt drei Sortierungen als Chips: **Level** (wie bisher), **Wert**
  (Rangliste: passende und "bald" zuerst nach Wert, dann der Rest nach Level) und **Kette**.
  Gespeichert im Fensterzustand (`state().dsort`), Standard "Level".
- `ns.DungeonRanking(opts?)` gibt die Liste nach Wert (nur berechnete Einträge mit Wert > 0 der
  Passung "passt"/"bald"); `ns.DungeonNext` bleibt deren erster Eintrag.

### Kette (`ns.DungeonChain(opts?, steps?)`)

- Ausgangspunkt sind die angelegten Werte je Slot (`ns.BisWornScores(opts)`, neu in Bis.lua, die
  vorhandene Kontext-Rechnung, als Kopie). Ein Zuwachs mit virtuell angelegten Items rechnet wie
  `gainFor` in Bis.lua: Ringe und Schmuck gegen den schwächeren der beiden, Zweihänder gegen
  Haupt- plus Nebenhand, Einhänder bei angelegtem Zweihänder zählen nicht (Waffenwechsel).
- Schritt: für jeden noch nicht gewählten Dungeon (Passung "passt"/"bald", berechnet) wird der
  Wert mit den virtuellen Werten neu gerechnet: je Item `score = gain + mine` aus dem Planer, neuer
  Zuwachs gegen die virtuellen Slots, Upgrade nur über `ns.BisIsUpgrade`. Der höchste Wert gewinnt
  den Schritt.
- **Annahme beim virtuellen Anlegen:** alle offenen Quest-Upgrades des Dungeons (sicher) und je
  Boss das größte Upgrade (zwei Läufe, ein Teil je Boss; Dropglück wird nicht simuliert). Ein Item
  wird nur angelegt, wenn es dann noch ein Upgrade ist.
- Höchstens 5 Schritte (`steps`), Abbruch, wenn kein Dungeon mehr Wert hat. Ergebnis:
  `{ { entry, value, upgrades, items = { ids } }, ... }` und der Grund des Endes.
- Schritt 1 ist immer gleich `ns.DungeonNext` (gleiche Rechnung ohne virtuelle Items; Test).
- Anzeige: Sortierung "Kette" zeigt oben "Kette: 1. Hall of Thanes · 2. Ruins of Lordaeron · ..."
  und ordnet die Liste in Kettenreihenfolge mit Rangnummer, Spalte "Wert" mit dem Kettenwert.
- Befehl `/amisia dungeon kette`: die Kette im eigenen Chat.
- Zwischengespeichert wie die Liste (gleicher Zustandsschlüssel).

## B. Questliste je Dungeon

### Daten: was schon da ist und was fehlt

- `GearData.lua` (`tools/build_gear.py`, PC) kennt Quests nur als **Quelle eines Items**
  (`S.Q`: Name, Questlevel, Mindestlevel, Fraktion, Zone, Quest-ID, Klassen, Dungeon-Name nur bei
  einem Teil). Es fehlen Quests ohne Ausrüstungsbelohnung, die Zuordnung Quest -> Dungeon, Vorquests
  und der Startort.
- Offene Quelle: AllTheThings, Ordner `.contrib/.db/forever` (MIT). Je Dungeon die Quests mit
  Questgeber (NPC-ID, Name im Kommentar), Koordinaten (Karte + x/y), Fraktion, Mindestlevel,
  Vorquests (`sourceQuest(s)`, Alternativen `altQuests`), Start durch ein Item (`qs`/`qi`),
  Belohnungs-Items. Abgedeckt sind die Dungeons bis etwa Level 30 (auch Hall of Thanes, Ruins of
  Lordaeron, Excavation Site, City of Dalaran); höhere Dungeons und die Raids fehlen dort noch: die
  Seite zeigt dann "Questdaten fehlen noch." und listet nur, was `GearData.lua` als Dungeon-Quest
  kennt. Ein Questlevel steht dort nicht (nur das Mindestlevel), Klassenbeschränkungen werden nicht
  gelesen.

### Erzeugung: `tools/build_dungeonquests.py` (neu, N100)

```
python tools/build_dungeonquests.py [--att ~/addons/_cache/att] [--refresh-att] [--json DATEI] [--empty]
```

- **Eingabe austauschbar:** jeder Leser liefert eine neutrale Form (Dungeon -> Quest-IDs; je Quest
  Name, Mindestlevel, Questlevel, Fraktion, Klassen, Start, Questgeber, Punkte, Vorquests alle/eine,
  Dungeon, Belohnungen); `render()` schreibt nur aus dieser Form. Leser: AllTheThings (`--att`),
  neutrales JSON (`--json`), leer (`--empty`).
- **AllTheThings-Leser:** `--refresh-att` lädt die Dungeon- und Zonendateien und die
  Kartenkonstanten über die GitHub-API nach `~/addons/_cache/att` (außerhalb des Repos). Die Dateien
  sind eine Lua-Bausprache (`inst`, `q`, `e`, `i`, `n`, `objective`, ...); sie laufen unter lupa mit
  Platzhaltern, die nur aufzeichnen. Dungeon-Datei -> Fakten-Schlüssel über Dateiname bzw.
  Gebiets-ID; Vorquests aus den Zonendateien.
- **Startort:** Koordinaten auf der Karte des Dungeons -> `I` (drinnen), sonst `O` mit bis zu 4
  Punkten "uiMapID:x:y"; ohne Questgeber mit Item-Start `X`; sonst leer (unbekannt).
- Ausgabe `addon/Amisia/DungeonQuestData.lua` (`[AllowLoadGameType camelot]`, nach
  `DungeonData.lua` in der TOC); nur Dungeon-Quests und ihre Vorquests:

```lua
ns.DUNGEON_QUESTS = {
    built = "2026-10-06", source = "f8d7232b7c",
    D = { deadmines = { 166, 167, ... } },
    Q = { [166] = { "The Defias Brotherhood (7/7)", 14, 0, "A", 0, "O", "Gryan Stoutmantle",
                    "1436:5630:4750", nil, nil, "deadmines", { 6087, 2042, 2041 } } },
    -- Q: Name, Mindestlevel, Questlevel (0 unbekannt), Fraktion, Klassenmaske, Start, Questgeber,
    --    Punkte, Vorquests alle, Vorquests eine davon, Dungeon-Schlüssel, Ausrüstungsbelohnungen
}
```

- Belohnungen: die der Questdaten plus die Items mit einer `Q`-Quelle dieser Quest-ID in
  `GearData.lua`.
- Tests `tools/tests/test_build_dungeonquests.py` auf einer handgemachten Fixture in der
  Bausprache (`tools/tests/fixtures/att`, keine echten Daten): Zuordnung, Namen aus Kommentaren,
  Start innen/außen/Item/unbekannt, Vorquests mit Schleife und fehlender Vorquest, Belohnungen,
  unbekannte Hüllfunktionen, deterministische gültige Lua-Ausgabe, JSON-Eingabe, leere Datei, die
  ausgelieferte Datei mit TOC-Eintrag und Lizenzdatei.

### Im Spiel (Dungeons.lua)

```lua
ns.DungeonQuests(key, opts?) -> list, status
-- list: { { qid, title, minLevel, level, start, giver, points, done, active,
--           chain = { { qid, title, minLevel, level, start, giver, points, done, active, one } },
--           rewards = { { id, gain, slotKey, upgrade, owned } }, best } }
-- status: "ok" (die Questdaten kennen den Dungeon), "missing" (kennen ihn nicht: nur die
-- Dungeon-Quests von GearData.lua), "nodata" (DungeonQuestData.lua fehlt); beide Fälle zeigen
-- "Questdaten fehlen noch."
```

- Quellen vereinigt nach Quest-ID: `DUNGEON_QUESTS.D[key]` und die Dungeon-Quests von
  `GearData.lua` (`S.Q` Feld 9). Gefiltert nach Fraktion und Klasse wie `Gear.SourceOk`.
- **erledigt** über `C_QuestLog.IsQuestFlaggedCompleted`, **im Log** über `C_QuestLog.IsOnQuest`
  (Forever 1.60.1, beide in `QuestLogDocumentation.lua` geprüft; fehlt eine, gilt die Quest als
  offen bzw. nicht im Log). Titel über `C_QuestLog.GetTitleForQuestID`, sonst der englische Name.
- **Passung:** "zu niedrig" (Mindestlevel über dem eigenen), sonst Questlevel-Farbe wie im
  Questlog (grau ab 6 darunter, grün, gelb, orange, rot ab 5 darüber, vereinfacht).
- **Kette:** Vorquests von der Wurzel her; bei "eine davon" die erledigte, sonst die erste offene,
  mit dem Zusatz "(oder eine andere)". Eine Vorquest der anderen Fraktion fällt weg.
- **Belohnungen:** jede Ausrüstungsbelohnung mit `ns.BisGain`; Upgrade-Marke grün "+12",
  Besitz und Nicht-Upgrades grau. Der Wert `once` des Planers nimmt jetzt alle Dungeon-Quests mit
  (bisher nur die mit Dungeon-Namen aus `GearData.lua`).
- **Wegpunkt:** Klick auf eine Quest (oder Vorquest) setzt das Kartenziel auf den nächsten
  Startpunkt (`ns.MapSetPoint`, Text "Questgeber <Name>"); Start im Dungeon: der Eingang. Dazu
  `Map.ParsePoints(text)` (die vorhandene Punkt-Zerlegung aus `ns.MapPoints`, herausgezogen).
- Befehl `/amisia dungeon quests [<Dungeon>]`: die Quests im eigenen Chat (Standard: gewählter
  bzw. nächster Dungeon).

### Anzeige

Im unteren Teil der Ansicht "Dungeons" zwei Chips **Bosse** / **Quests** (`state().dpart`).
"Bosse" zeigt nur noch Bosse und ihre Items (bisher hingen die Quests darunter). "Quests" zeigt je Quest eine Zeile (Status, Titel, Level "20 (ab 15)", Startort) und darunter
eingerückt die Vorquests und die Belohnungen. Tooltip einer Questzeile: Questgeber, Zone und
Koordinaten, Kette. Ohne Daten: "Questdaten fehlen noch." bzw. "Für diesen Dungeon kennt Amisia
keine Quests.".

## SelfTest

`C_QuestLog.IsOnQuest` kommt in die optionalen Funktionen (`IsQuestFlaggedCompleted` und
`GetTitleForQuestID` stehen schon in den Pflichtfunktionen).

## Was der Nutzer tun muss

- Nichts am PC: `build_dungeonquests.py --refresh-att` läuft auf dem N100. Neu bauen, wenn die
  Quelle neue Dungeons hat.
- Im Spiel prüfen: Rangliste/Kette plausibel, Questliste eines Classic-Dungeons (z. B. Todesminen)
  mit Vorquests und Wegpunkt, "erledigt"/"im Log", Fallback-Text bei Hall of Thanes.
