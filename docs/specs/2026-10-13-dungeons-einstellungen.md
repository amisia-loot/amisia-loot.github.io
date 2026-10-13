# Spec: Seite Dungeons und Einstellungen nach Reitern

Stand: 2026-10-13 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-102 (Seite Dungeons), F-103 (Einstellungen nach Reitern, Zahnrad)

## Ziel

Alles soll sich leichter finden und einstellen lassen ("können wir es strukturieren, dass wir alles
besser und einfach finden / einstellen können", 2026-10-13). Heute steckt der Dungeon-Journal als
Chip auf der Seite Ausrüstung. Die 25 Einstellungsabschnitte stehen untereinander auf einer Seite
ganz hinten im Reiter Amisia, und keine Seite führt zu ihren Einstellungen. Gelöst ist es, wenn
der Journal eine eigene Seite hat und jede Einstellung mit höchstens zwei Klicks erreichbar ist:
entweder von der Seite, um die es geht, oder über die nach Reitern geordnete Abschnittsliste.

## Was es tut

**Teil A: Seite "Dungeons" (F-102)**

- Neue Seite "Dungeons" im Reiter Ausrüstung, direkt unter "Ausrüstung", für alle. Inhalt ist der
  bisherige Dungeon-Planer, unverändert: Rangliste, Kette, Bild, Bossmodell, Beute, Quests mit EP,
  Wegpunkte und "Alle Questgeber auf der Karte".
- In der Kopfzeile steht die Wahl der Spezialisierung. Es ist dieselbe wie auf der Seite Ausrüstung
  (`ns.BisSetSpec`): ein Wechsel auf der einen Seite gilt auch auf der anderen.
- Der Chip "Dungeons" auf der Seite Ausrüstung entfällt. Dort bleiben Ziele, Hier, Wunschliste und Gilde.
- `/amisia dungeon` ohne Zusatz öffnet die Seite. Neu ist der Alias `/amisia journal`. Die übrigen
  Formen (`naechster`, `kette`, `quests <Dungeon>`) bleiben, wie sie sind.
- Das Schnellmenü an der Minimap und die Suche finden die Seite, weil sie alle sichtbaren Seiten führen.

**Teil B: Einstellungen nach Reitern (F-103)**

- Die Seite Einstellungen hat links eine Abschnittsliste mit Überschriften in der Reihenfolge der
  Reiter: Raid, Ausrüstung, Gilde, Kalender und Allgemein (statt "Amisia"). Rechts stehen nur die
  Zeilen des gewählten Abschnitts. Ein Abschnitt mit geänderten Werten trägt in der Liste den
  goldenen Punkt.
- Das Suchfeld steht oben über der Abschnittsliste und sucht wie bisher in allen Abschnitten. Rechts
  stehen dann die Treffer, nach Abschnitt gruppiert. Escape leert das Feld.
- Der zuletzt gewählte Abschnitt bleibt gemerkt.
- **Zahnrad:** Jede Seite mit eigenen Einstellungen bekommt oben rechts ein Zahnrad. Der Tooltip
  lautet "Einstellungen: <Abschnitte>". Ein Klick öffnet die Einstellungen nur mit den Abschnitten
  dieser Seite, untereinander. Oben stehen "Zurück zu <Seite>" und "Alle Einstellungen".
- Umbenannt wird der Abschnitt "Ausrüstung" (die Tabelle) zu "Ausrüstungstabelle", damit er sich von
  "Ausrüstung und Wünsche" unterscheidet.
- Jeder Abschnitt kommt in genau einen Reiter. Das Zahnrad zeigen die Seiten aus der Spalte "Seiten":

| Reiter | Abschnitt | Seiten (Zahnrad) |
|---|---|---|
| Raid | Aufnahme (`record`) | Raid-Log, Übersicht |
| Raid | Rolls und Vergabe, Loot-Ansage, Lootregeln, Loot-Prio (`rolls`, `loot`, `lootrules`, `prio`) | Rolls |
| Raid | Würfel-Fenster (`rollwin`) | Rolls, Übersicht |
| Raid | Punkte (`points`) | Punkte |
| Raid | Raid-Aufstellung (`lineup`) | Aufstellung |
| Raid | Raid-Check (`raidcheck`) | Raid-Check |
| Raid | Vergaben, Handel-Helfer (`awards`, `trade`) | Vergaben |
| Raid | Soft-Reserves (`softres`) | Soft-Reserves |
| Ausrüstung | Ausrüstung und Wünsche, Ausrüstungstabelle (`bis`, `gear`) | Ausrüstung |
| Ausrüstung | Drop-Daten (`drops`) | Dungeons |
| Ausrüstung | Karte und Wegpunkt (`map`) | Karte |
| Ausrüstung | Quests (`quests`) | Quests, Dungeons |
| Ausrüstung | Hersteller der Gilde (`crafters`) | Berufe |
| Gilde | Gildenbank, Raidmaterialien (`bank`, `mats`) | Gildenbank |
| Gilde | Werkzeuge (`tools`, Experten) | Werkzeuge |
| Kalender | Raid-Anmeldung (`signup`) | Kalender |
| Allgemein | Oberfläche, Sync und Version, Quellen-Sammler (`ui`, `sync`, `collect`) | Über und Befehle |

## Was es ausdrücklich nicht tut

- Es bleibt bei den fünf Reitern unten, ein sechster Reiter "Journal" kommt nicht dazu.
- Einstellungen wandern nicht in die Seiten. Es bleibt eine zentrale Seite, und das Zahnrad führt dorthin.
- Es entfällt keine Einstellung, und keine ändert ihren Pfad. Gespeicherte Werte bleiben gültig.
- Ein Spoiler-Schutz ("nur Beute zeigen, die ich gesehen habe") gehört nicht dazu, siehe Frage 2.
- Die Inhalte von Dungeon-Planer und Ausrüstung ändern sich nicht. Es ist ein reiner Umzug.

## Abläufe

1. Spieler klickt im Reiter Ausrüstung auf "Dungeons": der Planer erscheint wie bisher unter dem Chip,
   jetzt als eigene Seite. Eine gemerkte Ansicht "Dungeons" der Seite Ausrüstung wird beim Laden zu
   "Ziele", und die Seite Dungeons ist dafür die gemerkte Seite des Reiters.
2. Ein Offizier steht auf der Seite Aufstellung und klickt das Zahnrad: die Einstellungen zeigen nur
   "Raid-Aufstellung". Er schaltet "Einladung flüstern" an und klickt "Zurück zu Aufstellung".
3. Ein Spieler öffnet Einstellungen über den Reiter Amisia: links stehen die Überschriften, gewählt
   ist der zuletzt offene Abschnitt. Ein Klick auf "Karte und Wegpunkt" zeigt rechts dessen Zeilen.
4. Ein Spieler tippt "flüster" ins Suchfeld: rechts stehen die Treffer aus "Raid-Aufstellung" und anderen
   Abschnitten, jeweils mit dem Namen ihres Abschnitts als Überschrift.

## Abnahmekriterien

- Wenn du den Reiter Ausrüstung öffnest, dann steht links "Dungeons" unter "Ausrüstung", und die
  Seite zeigt Rangliste, Bild und Quests wie bisher. Auf der Seite Ausrüstung fehlt der Chip "Dungeons".
- Wenn du `/amisia journal` eingibst, dann öffnet sich die Seite Dungeons.
- Wenn du auf der Seite Dungeons die Spezialisierung wechselst und auf "Ausrüstung" gehst, dann ist
  dort dieselbe Spezialisierung gewählt.
- Wenn du auf der Seite Karte das Zahnrad klickst, dann zeigen die Einstellungen nur "Karte und
  Wegpunkt" und oben "Zurück zu Karte". Ein Klick darauf bringt dich zur Karte zurück.
- Wenn du die Einstellungen öffnest, dann stehen links die Überschriften Raid, Ausrüstung, Gilde,
  Kalender und Allgemein mit ihren Abschnitten. Ein Klick auf einen Abschnitt zeigt rechts nur dessen Zeilen.
- Wenn du als Raider (Ansicht "Raider") die Einstellungen öffnest, dann fehlen die Offiziersabschnitte
  (Rolls und Vergabe, Lootregeln, Raid-Aufstellung ...), und eine Überschrift ohne Abschnitt fehlt auch.

## Sonderfälle

- **Raider-Ansicht:** Die Seite Rolls ist nur für Offiziere. Raider erreichen "Würfel-Fenster"
  deshalb über das Zahnrad der Übersicht oder über die Liste.
- **Seite ohne Daten:** Gibt es keine Ausrüstungsdaten (`Gear.Available()` falsch), fehlt die Seite
  Dungeons wie heute der Chip, und ihre Abschnitte fehlen in der Liste. Ein Reiter ohne Seite fällt
  wie bisher weg (D-45).
- **Einzelne Zeilen nur für Offiziere:** Zeilen wie `raidcheck.chat` oder `rollwin.self` bleiben in
  ihrem Abschnitt. Hat ein Abschnitt für Raider nur solche Zeilen, fehlt er für Raider.
- **Kampf:** Seiten und Einstellungen sind schon heute außerhalb geschützter Rahmen. Neu ist nichts.
- **Englischer Client:** Überschriften und Zahnrad-Tooltip kommen aus der Locale.
- **`/reload`:** Gemerkter Abschnitt und gemerkte Seite bleiben erhalten.
- **Platz:** Rechts bleiben neben der Liste etwa 450 px. Der Editor der Lootregeln (`custom`) muss in
  diese Breite passen. Geprüft wird das mit `build.py snapshots` vor und nach dem Umbau.

## Missbrauch/Vertrauen

Nichts. Es gibt keine Nachricht, keinen neuen Schreibzugriff und keinen Austausch mit anderen
Spielern. Offiziersabschnitte bleiben in der Raider-Ansicht verborgen, wie bisher.

## Daten

- `ns.RegisterSettings` bekommt zwei neue Felder:
  - `group`: der Reiter, ein Schlüssel aus `ns.PANEL_GROUPS`. Pflicht. `tools/tests/test_contracts.py`
    prüft, dass jeder Abschnitt einen gültigen Reiter hat.
  - `pages`: die Seiten mit Zahnrad.
- `ns.ShowSettings` bekommt eine Form für die Abschnitte einer Seite: `ns.ShowSettings{ page = "map" }`.
  Die Form mit Suchtext bleibt.
- `settings.window.section` hält den zuletzt gewählten Abschnitt. Neuer gespeicherter Schlüssel, er
  kommt in die Tabelle in `docs/ARCHITECTURE.md`.
- Neue Seite `dungeons` in einer neuen Datei `UI/Pages/Dungeons.lua` (TOC). Sie bekommt einen Eintrag
  in der Modulkarte, und `Gear.lua` verliert den Planer.
- Die Seite Ausrüstung kennt die Ansicht `dungeons` nicht mehr. Eine gespeicherte `dungeons`-Ansicht
  wird beim Laden zu `goals`.
- Neue Regel D-49 in `docs/DECISIONS.md`: Einstellungen nach Reitern, Zahnrad je Seite, keine
  Einstellungen in Seiten.
- Es gibt keine Exportzeilen, Einfügeblöcke, Nachrichten oder Blob-Arten.

## Offene Fragen

1. Was zeigt das Zahnrad bei einer Seite mit mehreren Abschnitten? Ein Beispiel ist Rolls mit vier
   Abschnitten. Vorschlag: alle Abschnitte dieser Seite untereinander, statt nur den ersten.
2. Kommt der Spoiler-Schutz für die Seite Dungeons ("nur Beute, die ich oder die Gilde gesehen habe")
   in diesen Spec? Vorschlag: nein. Danach kommt er als kleines eigenes Feature mit einem Schalter
   unter "Drop-Daten".
3. Wie heißt die Seite? Vorschlag: "Dungeons", obwohl sie auch Raids zeigt. "Dungeons und Raids" ist
   in der Seitenliste zu lang.

## Entscheidungen

- 2026-10-13: Umfang "Ganzes Addon", Journal "Eigene Seite im Reiter Ausrüstung", Einstellungen
  "Zahnrad + nach Reitern" (Auswahl des Nutzers).
