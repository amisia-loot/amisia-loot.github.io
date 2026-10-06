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
  nennen, keine Links auf fremde Seiten. Quelle der Questdaten ist QuestieDB (GPL-3.0), genannt im
  Kopf der erzeugten Datei und in `tools/README.md`, wie bei `MapData.lua`.

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
  OneForAll-Quests). Es fehlen Quests ohne Ausrüstungsbelohnung, die Zuordnung Quest -> Dungeon
  für die QuestieDB-Quests, Vorquests und der Startort.
- `MapData.lua` (`tools/build_map.py`, N100) kennt Startpunkte nur für Quests aus `GearData.lua`.
- QuestieDB (Forever-Datenbank auf GitHub, GPL-3.0) hat alles Nötige: `startedBy`, `requiredLevel`,
  `questLevel`, `requiredRaces`, `requiredClasses`, `objectives`, `preQuestGroup`,
  `preQuestSingle`, `zoneOrSort`; dazu NPC- und Objekt-Spawns und die Dungeon-Gebiete.
  `build_map.py` lädt diese Dateien schon (`--refresh-questie`, Zwischenspeicher
  `tools/cache/questiedb/`, nicht im Repo). Damit läuft der neue Bau **auf dem N100**, ohne
  WoW-Installation.
- QuestieDB Forever enthält nur die Classic-Quests (IDs bis 9665). Für die neuen Dungeons von
  Forever (Hall of Thanes, Ruins of Lordaeron, ...) gibt es dort keine Quests: die Seite zeigt
  "Questdaten fehlen noch." und listet nur, was `GearData.lua` als Dungeon-Quest kennt (Sammler,
  OneForAll). Eigene Erfassung (Sammler-Notizen `Quest:`) füllt das später.

### Erzeugung: `tools/build_dungeonquests.py` (neu, N100)

```
python tools/build_dungeonquests.py [--cache tools/cache/questiedb] [--refresh-questie]
```

- Liest die QuestieDB-Dateien wie `build_map.py` (dieselben Lese- und Punktfunktionen) und die
  Dungeon-Fakten `tools/forever_dungeons.json`.
- **Dungeon einer Quest:** `zoneOrSort` ist ein Gebiet des Dungeons (Hauptgebiet oder Nebengebiet),
  sonst ein Kill- oder Objekt-Ziel, dessen Spawns alle in genau einem Dungeon liegen (z. B. "The
  Defias Brotherhood", in Westfall einsortiert, Ziel im Dungeon). Dungeon-Gebiet -> Fakten-Schlüssel
  über `area` der Fakten, sonst gleichen Namen (Name oder Alias, `dungeon_key`). Schlachtfelder und
  Gebiete ohne Fakten fallen weg (gezählt im Bericht).
- **Startort:** erster Start-NPC oder -Objekt mit Spawns; `I` alle Spawns im Dungeon (Punkte =
  Eingänge), `O` draußen (bis 4 Punkte "uiMapID:x:y" wie `MapData.lua`), `X` Start durch ein Item,
  leer: unbekannt.
- **Vorquests:** `preQuestGroup` (alle nötig) und `preQuestSingle` (eine davon), rekursiv bis zur
  Wurzel (höchstens 30 Stufen, ohne Schleifen); jede Vorquest kommt mit eigenem Datensatz in die
  Datei.
- Fallen weg: Namen mit `UNUSED`, `NYI`, `DEPRECATED`, `<...>`, `[...]`.
- Ausgabe `addon/Amisia/DungeonQuestData.lua` (`[AllowLoadGameType camelot]`, nach
  `DungeonData.lua` in der TOC):

```lua
ns.DUNGEON_QUESTS = {
    built = "2026-10-06", questie = "9d39232dab",
    D = { deadmines = { 166, 214, ... } },           -- Dungeon-Schlüssel -> Quest-IDs (Ziel im Dungeon)
    Q = { [166] = { "The Defias Brotherhood", 14, 22, "A", 0, "O", "Gryan Stoutmantle",
                    "1436:5604:4752", { 155 }, nil, "deadmines" } },
    -- Q: Name, Mindestlevel, Questlevel, Fraktion ("A", "H", ""), Klassenmaske (0 alle),
    --    Start ("I", "O", "X", ""), Questgeber, Punkte, Vorquests alle, Vorquests eine davon,
    --    Dungeon-Schlüssel (nil bei reinen Vorquests)
}
```

- Belohnungen stehen nicht in der Datei: im Spiel kommen sie aus `GearData.lua` (Items mit einer
  `Q`-Quelle dieser Quest-ID). Nur Ausrüstung zählt für die Upgrade-Marke.
- Tests `tools/tests/test_build_dungeonquests.py` auf kleinen Fixture-Texten im QuestieDB-Format:
  Zuordnung über Gebiet und über Ziel, Start innen/außen/Item, Vorquest-Kette mit Schleife,
  Fraktion, Ausschlussnamen, deterministische und gültige Lua-Ausgabe; dazu ein Test, dass die
  ausgelieferte Datei lädt und in der TOC steht.

### Im Spiel (Dungeons.lua)

```lua
ns.DungeonQuests(key, opts?) -> list, status
-- list: { { qid, title, minLevel, level, faction, start, giver, points, done, active,
--           fit, chain = { { qid, title, minLevel, level, start, giver, points, done, active,
--           one } }, rewards = { { id, gain, slotKey, upgrade, owned } }, best, source } }
-- status: "ok", "partial" (nur Item-Quellen, keine QuestieDB-Quests), "none" (Dungeon ohne
-- bekannte Quest), "nodata" (DungeonQuestData.lua fehlt)
```

- Quellen vereinigt nach Quest-ID: `DUNGEON_QUESTS.D[key]` und die Dungeon-Quests von
  `GearData.lua` (`S.Q` Feld 9). Gefiltert nach Fraktion und Klasse wie `Gear.SourceOk`.
- **erledigt** über `C_QuestLog.IsQuestFlaggedCompleted`, **im Log** über `C_QuestLog.IsOnQuest`
  (Forever 1.60.1, beide in `QuestLogDocumentation.lua` geprüft; fehlt eine, gilt die Quest als
  offen bzw. nicht im Log). Titel über `C_QuestLog.GetTitleForQuestID`, sonst der englische Name.
- **Passung:** "zu niedrig" (Mindestlevel über dem eigenen), sonst Questlevel-Farbe wie im
  Questlog (grau ab 6 darunter, grün, gelb, orange, rot ab 5 darüber, vereinfacht).
- **Kette:** Vorquests von der Wurzel her; bei "eine davon" erscheint die erste offene mit dem
  Zusatz "(oder eine andere)". Eine Vorquest der anderen Fraktion fällt weg.
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
"Quests" zeigt je Quest eine Zeile (Status, Titel, Level "20 (ab 15)", Startort) und darunter
eingerückt die Vorquests und die Belohnungen. Tooltip einer Questzeile: Questgeber, Zone und
Koordinaten, Kette. Ohne Daten: "Questdaten fehlen noch." bzw. "Für diesen Dungeon kennt Amisia
keine Quests.".

## SelfTest

`C_QuestLog.IsOnQuest` kommt in die optionalen Funktionen (`IsQuestFlaggedCompleted` und
`GetTitleForQuestID` stehen schon in den Pflichtfunktionen).

## Was der Nutzer tun muss

- Nichts am PC: `build_dungeonquests.py` läuft auf dem N100 aus dem QuestieDB-Download. Neu bauen
  nach `python tools/build_map.py --refresh-questie` (neuer QuestieDB-Stand).
- Im Spiel prüfen: Rangliste/Kette plausibel, Questliste eines Classic-Dungeons (z. B. Todesminen)
  mit Vorquests und Wegpunkt, "erledigt"/"im Log", Fallback-Text bei Hall of Thanes.
