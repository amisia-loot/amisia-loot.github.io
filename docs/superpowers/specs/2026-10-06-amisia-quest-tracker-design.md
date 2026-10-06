# Amisia: Quest-Tracker für die ganze Welt

Stand 2026-10-06. Nur WoW Forever 1.60.1 (TOC 16001). Baut auf der Questliste je Dungeon
(`docs/superpowers/specs/2026-10-06-amisia-dungeon-guide-design.md`), der Karte (`Map.lua`) und dem
Quellen-Sammler (`Collector.lua`) auf. Keine Versionsänderung, kein Release in diesem Schritt.

## Ziel

Der Nutzer wählte am 2026-10-06 einen Quest-Tracker für die ganze Welt (nicht nur Dungeons): eine
neue Seite "Quests" im Hauptfenster, die für Level, Fraktion, Volk und Klasse des Charakters zeigt,

- welche Quests **jetzt annehmbar** sind,
- welche **gesperrt** sind und warum (Vorquest fehlt, Level, Klasse, Fraktion, Volk, Beruf,
  Alternative schon erledigt),
- welche **im Log** sind (`C_QuestLog.IsOnQuest`) und welche **erledigt** sind
  (`C_QuestLog.GetAllCompletedQuestIDs`, sonst `IsQuestFlaggedCompleted` je Quest),
- mit **Questreihen** (Vorquests, Fortschritt "3/7"), **Belohnungen** mit der vorhandenen
  Upgrade-Marke (`ns.UpgradeOf`/`ns.UpgradeShort`), nach **Zonen** gruppiert, mit **Suche** und
  **Filtern** (Zone, annehmbar/im Log/gesperrt/erledigt, nur Reihen, nur Upgrades, nur für mich),
- und je Quest einem **Weg-Knopf**: Kartenziel (Wegpunkt mit Pfeil, `ns.MapSetPoint`) zum Questgeber.

## Daten (tools/build_quests.py -> addon/Amisia/QuestData.lua)

- Quelle nur AllTheThings (MIT, freigegeben, `tools/att_data.py` mit Sandbox): die Forever-Ordner
  und, wie beim Dungeon-Planer, die Classic-Ordner unter `zzOLD/` (Quests, die die Autoren noch nicht
  verschoben haben; ein Forever-Eintrag gewinnt). Neu geladen werden zusätzlich `character/`
  (Klassenquests: Jäger-Zähmen, Hexenmeister-Dämonen, Schurken-Gifte) und
  `zzOLD/10 - Professions/` (Berufsquests); `refresh()` lädt sie mit, die anderen Builds lesen sie
  nicht (eigene Ordnerliste `QUEST_DIRS`). Feiertage und Weltereignisse bleiben draußen.
- Der Leser liefert je Quest zusätzlich Volksmaske, Beruf (`requireSkill`, Skill-Line-ID),
  Hinweis-Quest (`isBreadcrumb`) und wiederholbar (`repeatable`). `altQuests` heißt in den Daten
  "schließt sich gegenseitig aus" (Beispiel Darkshore 994/995), nicht "eine von mehreren Vorquests".
- Kompakt: eine Zeichenkette je Quest, Felder mit `;` getrennt, Questgeber als NPC-ID mit eigener
  NPC-Tabelle (Name und Orte einmal statt je Quest), nur Ausrüstungsbelohnungen (Klasse Waffe/Rüstung
  im ItemDB-Export). Zonennamen englisch als Rückfall, der Client-Name (`C_Map.GetMapInfo`) gewinnt.
- Das Skript misst die Größe und schreibt sie ins Log. Ziel: unter 400 KB Datei.

## Laden und Speicher

- Die Datei hält nur Zeichenketten (kaum Tabellen). Zerlegt wird erst beim ersten Öffnen der Seite
  oder beim ersten `/amisia quests` (`ns.QuestIndex()`), dann bleibt der Index bis zum /reload.
- Einstellung `quests.enabled` (Standard an): aus, dann gibt es weder Seite noch Index; der Befehl
  sagt, wie man sie einschaltet. Ein eigenes Load-on-Demand-Addon lohnt nicht: es bräuchte einen
  zweiten Syncthing-Ordner und eine zweite Verknüpfung auf dem PC.

## Logik (Quests.lua)

- `ns.QuestIndex()`: alle Quests zerlegt, Rückwärtsliste der Folgequests.
- `ns.QuestInfo(qid, o)`: Status `done`, `active`, `open` (annehmbar) oder `locked` mit Gründen
  `{ kind, text }` (kind: `faction`, `race`, `class`, `level`, `pre`, `skill`, `alt`). Eine Vorquest
  gilt als erledigt, wenn sie oder eine ihrer Alternativen erledigt ist. Beruf: nur prüfbar, wenn
  der Client die Fertigkeiten nennt (`ns.BisSkills`), sonst Hinweis ohne Sperre.
- Reihe: alle Vorquests (rekursiv) plus alle Folgequests, die der Charakter annehmen kann
  (Fraktion, Klasse, Volk), höchstens 40; Fortschritt "erledigt/gesamt".
- `ns.QuestList(filter)`: gefilterte, nach Zone gruppierte, sortierte Liste; nach Zuständen
  zwischengespeichert (Quest-Ereignisse, Level, Ausrüstung über `ns.BisStamp`).
- Startort: Punkte der Quest, sonst des Questgebers aus den Daten, sonst die **eigene**
  Beobachtung des Sammlers (`ns.CollectQuestOwnStart`: nur Felder mit eigenem Bit). Nur Gehörtes
  setzt keinen Wegpunkt. Quest durch ein Item: kein Weg, Hinweis.

## Seite (Pages/Quests.lua)

- Gruppe "Ausrüstung", nach "Karte". Kopf: Zonenwahl (W.Picker: Alle, Hier, Zonen mit Anzahl),
  Suchfeld (W.SearchBox), Zähler. Darunter rote Chips (W.Chip): Annehmbar, Im Log, Gesperrt,
  Erledigt, dann Nur Reihen, Upgrades, Nur für mich.
- Liste (W.List): Zonenkopf-Zeilen (Gold, Klick klappt zu), Questzeilen (Titel, Level in
  Questlog-Farben, Status/Grund, beste Belohnung mit Marke, Knopf "Weg"). Klick auf eine Quest
  klappt Reihe und Belohnungen darunter auf; Tooltip mit allem.
- Befehl `/amisia quests [suche]` öffnet die Seite mit der Suche.

## Tests

- pytest: Leser (Volk, Beruf, Hinweis, wiederholbar, Zusatzordner), Rendern (deterministisch,
  gültiges Lua, Felder, Größe), TOC und Lizenz.
- lupa: Status und Gründe, Alternativen, Reihe und Fortschritt, Filter, Suche, Zonen, Weg (Daten,
  eigene Beobachtung ja, nur gehörte nein, Item-Start), Upgrades, Befehl, Einstellung aus, Seite
  mit Layout bei 602 x 478.
