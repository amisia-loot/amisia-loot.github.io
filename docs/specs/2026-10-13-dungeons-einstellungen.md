# Spec: Seite Dungeons und Einstellungen nach Reitern

Stand: 2026-10-13 · Status: freigegeben (Auswahl des Nutzers 2026-10-13, offene Fragen nach Vorschlag: Auftrag
"mach deine reihenfolge") · Feature: F-102 (Seite Dungeons), F-103 (Einstellungen nach Reitern, Knopf
"Einstellungen", Zurücksetzen)

## Ziel

Alles soll sich leichter finden und einstellen lassen ("können wir es strukturieren das wir alle besser und
einfach finden / einstellen können", 2026-10-13). Der Dungeon-Journal steckt heute als Chip auf der Seite
Ausrüstung; die 29 Einstellungsabschnitte stehen untereinander auf einer Seite ganz hinten, und keine Seite
führt zu ihren Einstellungen. Gelöst ist es, wenn der Journal eine eigene Seite hat und jede Einstellung mit
höchstens zwei Klicks erreichbar ist: von der Seite, um die es geht, oder über die nach Reitern geordnete
Abschnittsliste.

## Was es tut

**Teil A: Seite "Dungeons" (F-102)**

- Neue Seite "Dungeons" im Reiter Ausrüstung, direkt unter "Ausrüstung", für alle (wie bisher nur mit
  Ausrüstungsdaten). Inhalt ist der bisherige Dungeon-Planer, unverändert: Rangliste, Kette, Bild, Bossmodell,
  Beute, Quests mit EP, Wegpunkte und "Alle Questgeber auf der Karte".
- In der Kopfzeile steht die Wahl der Spezialisierung. Es ist dieselbe wie auf der Seite Ausrüstung
  (`ns.BisSetSpec`): ein Wechsel auf der einen Seite gilt auch auf der anderen.
- Der Chip "Dungeons" auf der Seite Ausrüstung entfällt. Dort bleiben Ziele, Hier, Wunschliste und Gilde.
- `/amisia dungeon` ohne Zusatz öffnet die Seite, neu ist der Alias `/amisia journal`; die übrigen Formen
  (`naechster`, `kette`, `quests <Dungeon>`) bleiben. `ns.ShowGear("dungeons")` und die Übersichtskarte
  öffnen die Seite. Schnellmenü und Suche finden sie, weil sie alle sichtbaren Seiten führen.

**Teil B: Einstellungen nach Reitern (F-103)**

- Die Seite Einstellungen hat links eine Abschnittsliste in der Art der Seitenliste (Kategorie-Leisten
  des Auktionshauses): Überschriften in der Reihenfolge der Reiter (Raid, Kalender, Ausrüstung, Gilde,
  Allgemein; eine Überschrift ohne sichtbaren Abschnitt fehlt), darunter ihre Abschnitte. Rechts stehen nur
  die Zeilen des gewählten Abschnitts; lange Bezeichnungen brechen um. Ein Abschnitt mit geänderten Werten
  trägt in der Liste den goldenen Punkt. Der gewählte Abschnitt bleibt gemerkt.
- Das Suchfeld steht oben links über der Liste und sucht wie bisher in allen Abschnitten; rechts stehen
  dann die Treffer, nach Abschnitt gruppiert; Escape oder das X leeren das Feld.
- **Knopf "Einstellungen"** in der Kopfzeile des Hauptfensters links neben der Ansicht: er erscheint, wenn
  die offene Seite eigene Einstellungen hat (Spalte "Seiten" unten), Tooltip "Einstellungen: <Abschnitte>".
  Ein Klick öffnet die Einstellungen nur mit den Abschnitten dieser Seite, untereinander, mit "Zurück zu
  <Seite>" oben. Ein Knopf statt eines Zahnrads auf jeder Seite: eine Stelle für alle Seiten, kein Eingriff in
  23 Seitenlayouts, und das Wort findet man leichter als ein Symbol.
- **Zurücksetzen:** "Abschnitt zurücksetzen" oben rechts setzt nach einer Rückfrage alle Einstellungen der
  gezeigten Abschnitte auf ihren Standard (nur wenn einer geändert ist). Unter Allgemein, Oberfläche, steht
  "Alle Einstellungen zurücksetzen" (nach einer Rückfrage alle Einstellungen aller Abschnitte; Fensterplätze,
  Listen, Raids und andere Daten bleiben). Das Zurücksetzen einer Zeile bleibt.
- `/amisia einstellungen <Abschnitt>` wählt den Abschnitt in der Liste (statt ihn zu suchen).
- Jeder Abschnitt kommt in genau einen Reiter; die Seiten zeigen den Knopf:

| Reiter | Abschnitt | Seiten mit Knopf |
|---|---|---|
| Raid | Aufnahme (`record`) | Raid-Log, Übersicht |
| Raid | Raid-Log, Discord-Text (`raidlog`, `discord`) | Raid-Log |
| Raid | Ersatzbank (`bench`) | Raid-Log, Raids, Aufstellung |
| Raid | Roll-Runden, Wer braucht das?, Loot-Ansage, Lootregeln, Loot-Prio (`rolls`, `need`, `loot`, `lootrules`, `prio`) | Rolls |
| Raid | Würfel-Fenster (`rollwin`) | Rolls, Übersicht |
| Raid | Punkte (`points`), Soft-Reserves (`softres`), Raid-Aufstellung (`lineup`), Raid-Check (`raidcheck`) | ihre Seite |
| Raid | Vergaben, Handel-Helfer (`awards`, `trade`) | Vergaben |
| Kalender | Raid-Anmeldung (`signup`) | Kalender |
| Ausrüstung | Ausrüstung und Wünsche, Gildenwünsche (`bis`, `wishes`) | Ausrüstung |
| Ausrüstung | Drop-Daten (`drops`) | Dungeons |
| Ausrüstung | Karte und Wegpunkt (`map`) | Karte |
| Ausrüstung | Quests (`quests`) | Quests, Dungeons |
| Ausrüstung | Quellen-Sammler (`collect`) | Quests |
| Ausrüstung | Hersteller der Gilde (`crafters`) | Berufe |
| Gilde | Gildenbank, Raidmaterialien (`bank`, `mats`) | Gildenbank |
| Allgemein | Sync und Version, Oberfläche (`sync`, `ui`) | Über und Befehle |
| Allgemein | Werkzeuge (`tools`, Experten) | Werkzeuge |

## Was es ausdrücklich nicht tut

- Kein sechster Reiter "Journal"; keine Einstellungen in den Seiten selbst.
- Keine Einstellung entfällt oder ändert ihren Pfad; gespeicherte Werte bleiben.
- Kein Spoiler-Schutz ("nur gesehene Beute") in diesem Spec; ein eigenes kleines Feature danach.
- Dungeon-Planer und Ausrüstung ändern ihren Inhalt nicht; es ist ein Umzug.
- "Alle Einstellungen zurücksetzen" löscht keine Daten (Raids, Listen, Wünsche, Fensterplätze).

## Abläufe

1. Spieler klickt im Reiter Ausrüstung auf "Dungeons": der Planer erscheint als eigene Seite. Eine gemerkte
   Ansicht "Dungeons" der Seite Ausrüstung wird beim Öffnen zu "Ziele".
2. Ein Offizier steht auf der Seite Aufstellung und klickt "Einstellungen": rechts nur "Ersatzbank" und
   "Raid-Aufstellung", oben "Zurück zu Aufstellung". Er schaltet "Einladung flüstern" an und geht zurück.
3. Ein Spieler öffnet Einstellungen über den Reiter Amisia: links die Überschriften mit den Abschnitten,
   gewählt ist der zuletzt offene. Ein Klick auf "Karte und Wegpunkt" zeigt rechts dessen Zeilen; "Abschnitt
   zurücksetzen" fragt nach und setzt sie auf den Standard.
4. Ein Spieler tippt "flüster" ins Suchfeld: rechts stehen die Treffer, jeder unter seinem Abschnitt.

## Abnahmekriterien

- Wenn du den Reiter Ausrüstung öffnest, dann steht links "Dungeons" unter "Ausrüstung", die Seite zeigt
  Rangliste, Bild und Quests wie bisher, und auf der Seite Ausrüstung fehlt der Chip "Dungeons".
- Wenn du `/amisia journal` eingibst, dann öffnet sich die Seite Dungeons; wechselst du dort die
  Spezialisierung, ist sie auch auf der Seite Ausrüstung gewählt.
- Wenn du auf der Seite Karte oben "Einstellungen" klickst, dann zeigen die Einstellungen nur "Karte und
  Wegpunkt" mit "Zurück zu Karte"; der Knopf bringt dich zur Karte zurück.
- Wenn du die Einstellungen öffnest, dann stehen links Raid, Kalender, Ausrüstung, Gilde und Allgemein mit
  ihren Abschnitten; ein Klick auf einen Abschnitt zeigt rechts nur dessen Zeilen, und "Abschnitt
  zurücksetzen" setzt sie nach der Rückfrage auf den Standard.
- Wenn du als Raider (Ansicht "Raider") die Einstellungen öffnest, dann fehlen die Offiziersabschnitte,
  und eine Überschrift ohne Abschnitt fehlt auch.

## Sonderfälle

- **Raider-Ansicht:** die Seite Rolls ist nur für Offiziere; Raider erreichen "Würfel-Fenster" über den
  Knopf der Übersicht oder über die Liste. Der Knopf zeigt nur sichtbare Abschnitte; hat eine Seite für die
  Ansicht keinen, fehlt er.
- **Ohne Ausrüstungsdaten:** die Seite Dungeons fehlt wie heute der Chip, ihre Abschnitte fehlen in der Liste.
- **Gemerkter Abschnitt nicht mehr sichtbar** (Ansicht gewechselt): der erste sichtbare ist gewählt.
- **Kampf:** Seiten und Einstellungen sind keine geschützten Rahmen; nichts Neues.
- **Englischer Client:** Überschriften, Knopf und Rückfragen aus der Locale.
- **Platz:** rechts bleiben neben der Liste etwa 420 px; Bezeichnungen brechen um, der Editor der Lootregeln
  bekommt diese Breite. Geprüft mit `build.py snapshots` vor und nach dem Umbau.

## Missbrauch/Vertrauen

Nichts. Keine Nachricht, kein neuer Schreibzugriff, kein Austausch; Offiziersabschnitte bleiben in der
Raider-Ansicht verborgen.

## Daten

- `ns.RegisterSettings` bekommt `group` (Reiter-Schlüssel aus `ns.PANEL_GROUPS`, Pflicht;
  `tools/tests/test_contracts.py` prüft es) und `pages` (Seiten mit dem Knopf).
- `ns.ShowSettings(text)` bleibt (Suche); neu `ns.ShowSettingsSection(key)` und `ns.ShowSettingsFor(pageKey)`.
- `settings.window.section`: der zuletzt gewählte Abschnitt (Fensterzustand neben `tab` und `pages`).
- Neue Einstellung `ui.resetAll` (Knopf, speichert nichts).
- Neue Seite `dungeons` in `UI/Pages/Dungeons.lua` (TOC); `UI/Pages/Gear.lua` verliert den Planer; die
  gemerkte Ansicht `dungeons` der Seite Ausrüstung wird zu `goals`.
- Neue Regel D-49: Einstellungen nach Reitern, Knopf je Seite, keine Einstellungen in Seiten.
- Keine Exportzeilen, Einfügeblöcke, Nachrichten oder Blob-Arten.

## Offene Fragen

Keine (siehe Entscheidungen).

## Entscheidungen

- 2026-10-13: Umfang "Ganzes Addon", Journal "Eigene Seite im Reiter Ausrüstung", Einstellungen
  "Zahnrad + nach Reitern" (Auswahl des Nutzers).
- 2026-10-13: Auftrag "mach deine reihenfolge": Zahnrad als ein Knopf "Einstellungen" in der Kopfzeile;
  eine Seite mit mehreren Abschnitten zeigt alle untereinander; Spoiler-Schutz nicht in diesem Spec; die Seite
  heißt "Dungeons"; Zurücksetzen pro Abschnitt und für alle (Plan B5) gehört dazu.
