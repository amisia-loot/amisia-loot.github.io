# Spec: Spielstil-Filter und Rechtsklick auf den Charakter-Slot

Stand: 2026-10-24 · Status: freigegeben ·
Feature: F-124 (Spielstil), F-125 (Slot-Rechtsklick)

## Ziel

Die Ziele sollen zur Spielweise passen, nicht nur zur Quelle: wer keine Gruppe findet, nur kaufen will
oder gerade in einer Zone questet, sieht nur, was er so auch bekommt. Dazu soll man die Upgrades eines
Slots ohne Umweg über `/amisia` finden, direkt im Charakterfenster. Wunsch des Nutzers 2026-10-24 nach dem
Vergleich mit einem anderen Leveling-Addon. Gelöst ist es, wenn ein Solo-Spieler mit "Solo machbar" keine
Dungeonbeute mehr als Ziel hat und ein Rechtsklick auf den Kopf-Slot die besten Köpfe zeigt.

## Was es tut

**F-124 Spielstil.** Auf der Seite Ausrüstung (Ziele) und im Fenster "Ausrüstungsziele" kommt neben die
Quellen-Chips der Knopf **Spielstil**. Er öffnet ein Menü mit fünf Häkchen, jedes mit einer Zeile Erklärung
im Tooltip. Mehrere dürfen gleichzeitig an sein; dann muss eine Quelle alle erfüllen:

| Spielstil | Was bleibt |
|---|---|
| **Keine Dungeons** | keine Dungeon- und Raidbeute (D, X), keine Quest mit Dungeon (Feld `dungeon` oder Start `I` in QuestData) |
| **Solo machbar** | wie Keine Dungeons; seltene Gegner nur bis zur eigenen Stufe + 1; Quests, die Amisia als Gruppenquest kennt, fallen weg (siehe Daten) |
| **Kaufbar** | Händler deiner Fraktion (V), gesehen im Auktionshaus (A) und jedes Item, das nicht beim Aufheben bindet (Feld bind ≠ 1), Quelle dann "Auktionshaus (bindet beim Anlegen)" |
| **Jetzt holbar** | Ruf erreicht (Item verlangt einen Ruf: deiner muss mindestens so hoch sein); hergestellt und bindet beim Aufheben nur mit eigenem Beruf und Skill; bindet es beim Anlegen, bleibt es (kaufbar) |
| **Fokus-Zone** | nur Quellen in deiner jetzigen Zone (Quest, Händler, Rarer, Weltdrop) oder Instanz; Dungeons, deren Eingang in der Zone liegt, zählen dazu. Folgt dem Zonenwechsel. |

- Ist ein Spielstil an, heißt der Knopf "Spielstil (N)" und leuchtet wie ein gewählter Chip. Im Kopf der
  Liste steht "Spielstil blendet N Ziele aus"; mit der Maus darüber die ersten zehn mit Grund.
- Er gilt überall, wo Amisia die eigenen Ziele nutzt (`ns.BisOpts`): Seite Ziele, Fenster
  Ausrüstungsziele, Karten-Pins, "Hier", der Upgrade-Punkt der Ausrüstungstabelle in der eigenen Spalte und
  der Slot-Rechtsklick (F-125). Bei Jetzt holbar sagt die Quellzeile den Ruf: "Ruf: Sturmwind, Wohlwollend
  (du: Freundlich)".
- Befehl: `/amisia spielstil` zeigt den Stand im Chat; `/amisia spielstil kaufbar` (oder `keine-dungeons`,
  `solo`, `jetzt`, `zone`, `aus`) schaltet um.

**F-125 Rechtsklick auf den Slot.** Ein Rechtsklick auf einen Slot im Charakterfenster öffnet daneben eine
kleine Karte "Upgrades: <Slot>": die bis zu fünf besten Items für diesen Slot (mit Spielstil und
Quellen-Chips), je Zeile Symbol, Name, "+x,x %" und die erste Quelle. Klick auf eine Zeile setzt das
Kartenziel (wie auf der Seite Karte), Strg-Klick Anprobe, Shift-Klick in den Chat, Rechtsklick das Menü der
Ziele (eigene Wahl, Wunschliste, ausschließen). Unten "Im Fenster Ausrüstungsziele" öffnet das Fenster mit
diesem Slot. Escape oder ein zweiter Rechtsklick schließt die Karte. Im Tooltip des Slots steht unten
"Rechtsklick: Upgrades (Amisia)".

## Was es ausdrücklich nicht tut

- **Nur Dungeons**: dafür gibt es die Seite Dungeons mit Rangliste und Kette. Nicht als Spielstil.
- **Auktionshauspreise**: Amisia liest keine Preise anderer Addons; "Kaufbar" sagt nur, dass es zu kaufen ist.
- Spielstil ändert keine Wertung, nur welche Quellen zählen. Ausrüstungstabelle (fremde Spalten),
  Simulation und Seite Dungeons rechnen weiter ohne Spielstil (sie planen, sie filtern nicht für dich).
- Kein Rechtsklick auf Slots im Betrachten-Fenster anderer Spieler, kein Ändern der Ausrüstung: Amisia legt
  nie etwas an (Ziel setzen ja, anlegen nein).
- Nichts wird gesendet; keine neuen Daten aus dem Netz (D-03).

## Abläufe

1. Seite Ausrüstung, Ziele -> "Spielstil" -> "Solo machbar" anhaken. Die Liste rechnet neu; Dungeonbeute
   verschwindet, der Kopf sagt "Spielstil blendet 7 Ziele aus".
2. Beim nächsten `/reload` oder Login bleibt der Spielstil (je Account, wie die Quellen-Chips).
3. "Fokus-Zone" an, nach Westfall reisen: die Liste wechselt beim Zonenwechsel auf Westfall (Quests,
   Händler, Rare, Deadmines über den Eingang). In einer Stadt ohne Quellen: "Hier gibt es mit diesem
   Spielstil nichts für dich."
4. Charakterfenster (C) -> Rechtsklick auf Hände -> Karte mit den fünf besten Handschuhen -> Klick auf den
   ersten: Chat "Ziel ...", Pfeil zeigt hin.

## Abnahmekriterien

- Wenn du "Keine Dungeons" anhakst, dann steht auf der Seite Ziele keine Quelle "Dungeon", "Raid" oder eine
  Quest aus einem Dungeon mehr, und der Knopf heißt "Spielstil (1)".
- Wenn du "Kaufbar" anhakst, dann bleiben nur Händlerware und Items, die beim Anlegen binden; bei einem
  Weltdrop steht als Quelle "Auktionshaus (bindet beim Anlegen)".
- Wenn du "Jetzt holbar" anhakst und dein Ruf bei der Fraktion eines Ruf-Items zu niedrig ist, dann fehlt
  das Item; mit der Maus über dem Knopf "Spielstil (1)" steht es unter "Spielstil blendet N Ziele aus:" mit
  "Ruf: <Fraktion>, <Stufe> (du: <Stufe>)".
- Wenn "Fokus-Zone" an ist und du die Zone wechselst, dann zeigt die Liste nach einigen Sekunden nur
  Quellen der neuen Zone; die Karten-Pins folgen.
- Wenn du im Charakterfenster mit rechts auf einen Slot klickst, dann öffnet sich die Karte "Upgrades:
  <Slot>" mit bis zu fünf Items; Klick auf eine Zeile setzt das Kartenziel.
- Wenn du mit rechts auf ein Schmuckstück mit Benutzen-Effekt klickst, dann wird es wie im Spiel benutzt und
  die Karte öffnet sich nicht (siehe Frage 3).

## Sonderfälle

- **Kampf**: Spielstil umschalten geht; die Liste rechnet nach dem Kampf neu (wie heute). Die Slot-Karte
  öffnet sich auch im Kampf (eigenes, nicht geschütztes Fenster), Klicks setzen nur Ziele.
- **Benutzen-Effekte**: der Rechtsklick des Spiels benutzt ein angelegtes Item mit Benutzen-Effekt
  (Schmuck, manche Köpfe). Amisia hängt sich nur nach dem Klick des Spiels an (`HookScript`, kein
  Ersetzen, keine Verschmutzung), siehe Frage 3.
- **Eigene Wahl** (D-55): bleibt Option 1 ihres Slots, auch wenn der Spielstil ihre Quelle ausblendet, mit
  "außerhalb deines Spielstils". BiS-Empfehlungen (D-09) werden gefiltert wie alles andere.
- **Ruf**: Fraktion unbekannt oder vom Client nicht lesbar -> Item zählt als holbar (lieber zeigen als
  verstecken), Shift-Tooltip "Ruf nicht lesbar".
- **Fokus-Zone in Höhlen und Unterzonen**: die Karte des Spielers wird bis zur Zone hochgegangen
  (`C_Map.GetMapInfo` parentMapID bis mapType Zone). In einer Instanz zählt die Instanz.
- **Zonen ohne Eingangsdaten**: Dungeon zählt dann nicht zur Zone (kein Raten).
- **Leere Liste**: jeder Slot ohne Treffer zeigt "Nichts mit diesem Spielstil"; der Upgrade-Punkt und
  die Pins fehlen dort.
- **Englischer Client**: Fraktions- und Rufnamen vom Client; Befehlswörter Deutsch und Englisch
  (`buyable`, `nodungeons`, `solo`, `now`, `zone`, `off`).
- **Charakterfenster eines anderen Addons**: Amisia hängt sich nur an die Slot-Knöpfe des Spiels
  (`Character<Slot>Slot`); fehlen sie, gibt es keinen Rechtsklick und `/amisia selbsttest` sagt es.

## Missbrauch/Vertrauen

Nichts. Rein lokal; nichts gesendet oder empfangen. "Wer braucht das?" schickt weiter die Wertung ohne
Spielstil (sonst würde ein Filter die Lootvergabe färben).

## Daten

- **Window state**, kein registrierter Schlüssel (wie `settings.bis.sources`, D-49):
  `settings.bis.style = { nodungeon, solo, buy, now, zone }` (nur `true`, sonst fehlt der Schlüssel),
  je Account. `settings.goalWindow` bekommt nichts Neues (das Fenster liest denselben Stand).
- **Neue Einstellung** `bis.slotClick` ("Rechtsklick auf Slots im Charakterfenster", Abschnitt `bis`,
  an, mit `tip`).
- **Ruf**: aus der Client-Tabelle `ItemSparse` (`MinFactionID`, `MinReputation` 0-7), schon exportiert;
  468 Items im Build 70532. `tools/build_gear.py` schreibt sie in eine eigene Tabelle der GEAR-Daten
  `RP = {[itemID] = factionID * 10 + standing}` (keine neue Spalte in `I`, damit `Gear.FIRST_SOURCE`
  bleibt). Der Stand des Spielers über `C_Reputation.GetFactionDataByID` bzw. `GetFactionInfoByID`.
  Damit fällt auch die Lücke "Ruf" aus F-123 weg (die Katalog-Kategorie Ruf wäre ein kleiner Nachtrag).
- **Gruppenquests**: weder QuestData noch AllTheThings haben ein Merkmal dafür. Amisia liest für Quests im
  Log den Typ des Spiels (`C_QuestLog.GetQuestTagInfo`, sonst die empfohlene Gruppengröße: G Gruppe, D
  Dungeon, R Raid, P PvP) in den neuen Schlüssel `AmisiaDB.questtags` (nie gesendet); `tools/build_gear.py`
  sammelt ihn in `tools/quest_tag_archive.json` und schreibt die Typen der eigenen Quests als `QT` in die
  GEAR-Daten. Bis dahin filtert "Solo machbar" nur Dungeonquests und was dieser Client schon gelernt hat.
- **Neue Dateien**: `Gear/PlayStyle.lua` (Filterregeln, Befehl), `Collect/QuestTags.lua` (Questtypen aus dem
  Log) und `UI/SlotCard.lua` (Karte, Hook auf die Slot-Knöpfe). Beides in TOC und Modulkarte; nach dem Release WoW ganz neu starten.
- Keine Nachrichten, Blob-Arten, Exportzeilen, Einfügeblöcke. Eine Regel in DECISIONS (D-56: Spielstil
  filtert Quellen, nie Wertung, nie gesendet; Rechtsklick nur nach dem Spiel).

## Offene Fragen

1. Mehrere Spielstile gleichzeitig mit "alle müssen passen" (z. B. Kaufbar + Fokus-Zone = Händler hier)?
   Vorschlag: ja.
2. Spielstil auch auf den Upgrade-Punkt der Ausrüstungstabelle und die Karten-Pins anwenden, aber nicht auf
   den Tooltip "Upgrade für dich" (der vergleicht nur mit dem Angelegten)? Vorschlag: ja.
3. Rechtsklick auf ein Item mit Benutzen-Effekt: nur benutzen (keine Karte), und Alt+Rechtsklick öffnet die
   Karte auf jedem Slot? Vorschlag: ja; sonst würde jedes Schmuckstück beim Blick auf Upgrades ausgelöst.
4. Gruppenquests lernen über den Sammler (Typ aus dem Questlog, kommt mit dem nächsten `build.py data`)?
   Vorschlag: ja, als Teil von F-124; ohne das erkennt "Solo machbar" Elitequests nicht.
5. Die Katalog-Kategorie "Ruf" (F-123) gleich mit nachziehen, jetzt wo die Ruf-Daten da sind? Vorschlag:
   ja, als kleiner Nachtrag zu F-123 im selben Release.
6. Spielstil je Charakter statt je Account (z. B. Twink "Solo", Main "Jetzt holbar")? Vorschlag: je
   Account, wie die Quellen-Chips; einfacher, und man schaltet selten um.

## Entscheidungen

- 2026-10-24: "Passt, alle sechs Vorschläge so übernehmen und bauen." -> mehrere Spielstile, alle müssen
  passen; gilt für Pins und Upgrade-Punkt, nicht für den Tooltip; Rechtsklick auf Items mit Benutzen-Effekt
  benutzt nur, Alt+Rechtsklick öffnet die Karte auf jedem Slot; Gruppenquests lernt der Sammler aus dem
  Questlog; Katalog-Kategorie Ruf im selben Release; Spielstil je Account.
- 2026-10-24 beim Bauen: Questtypen kommen als `QT` in die GEAR-Daten (nicht als Flag in QuestData), mit eigenem
  Schlüssel `AmisiaDB.questtags` statt im Sammler-Datensatz (der wird mit der Gilde getauscht). "Kaufbar" zusammen
  mit "Fokus-Zone" lässt nur Händler der Zone (das Auktionshaus hat keine Zone). Ein Item ohne lesbaren Beruf zählt
  bei "Jetzt holbar" nur, wenn der Client gar keine Berufe nennt. Die Ruf-Zeile steht bei jedem Ruf-Item, nicht nur mit
  "Jetzt holbar"; die Liste der ausgeblendeten Ziele steht im Tooltip des Knopfs "Spielstil". Die Ruf-Gruppe des
  Katalogs zeigt sich ab ihrem niedrigsten Item.
- 2026-10-24 Review: Trash-Drops zählen als Dungeon; BiS-Empfehlungen folgen dem Spielstil (eine ohne bekannte
  Quelle fällt weg); "außerhalb deines Spielstils" nur, wenn die Schalter das Item ausschließen; "Hier" prüft den Ruf und
  ein dort gewählter Ort braucht keine Fokus-Zone; Shift- und Strg-Rechtsklick bleiben dem Spiel; die Tooltip-Zeile
  bleibt auch beim Drücken von Alt.
