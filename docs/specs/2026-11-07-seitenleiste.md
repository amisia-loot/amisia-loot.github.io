# Spec: Eine Seitenleiste statt drei Navigationen

Stand: 2026-11-07 · Status: freigegeben (der Nutzer: "Passt") ·
Feature: F-141

Schritt 1 von 4 der UI-Überholung (Nutzer am 2026-11-07: "ich brauche eine ui overhall ... aber ich will
es im WoW Forever classic style"; zu Schritt 1: "Ja, Spec für Schritt 1"). Danach folgen: 2 Seitenkopf,
3 Startseite und Detailseite, 4 aufklappbare Zeilen, jeweils mit einer eigenen Spec.

## Ziel

Heute führen drei Wege durch Amisia: die Reiter unter dem Fenster (Raid, Ausrüstung, Gilde, Kalender,
PvP, Amisia), die Seitenliste links mit den Seiten des gewählten Reiters und die großen Seitenreiter
rechts für die Seitenfenster. Danach gibt es nur noch die Seitenleiste links: Gruppen mit ihren Seiten
untereinander, so wie die Kategorienliste des Auktionshauses. Gelöst ist es, wenn man jede Seite und
jedes Seitenfenster von links aus erreicht und unter und rechts neben dem Fenster nichts mehr hängt.

## Was es tut

- **Gruppen als Kategorien des Auktionshauses.** Jede Gruppe ist ein Balken der obersten Ebene, gold mit
  dem Plus- oder Minuszeichen des Auktionshauses. Ihre Seiten stehen darunter eingerückt als Balken der
  Unterkategorie, wie heute die Abschnitte der Einstellungen (`NAV_SUB_X`). Die gewählte Seite ist weiß
  und hat das Leuchten des Auktionshauses. Es bleibt bei den Balken ohne Symbole (D-06).
- **Immer nur eine Gruppe offen,** wie im Auktionshaus. Ein Klick auf eine Gruppe klappt sie auf, die
  vorher offene klappt zu, und ihre zuletzt gewählte Seite öffnet sich (wie heute der Reiter). Ein Klick
  auf die offene Gruppe klappt sie zu, die Seite bleibt offen. Jede Seite, die sich anders öffnet
  (Befehl, Karte der Übersicht, Suche), klappt ihre Gruppe auf.
- **Neue Gruppen (Vorschlag, Frage 1):**
  - Raid: Übersicht, Aufstellung, Soft-Reserves, Raid-Check, Rolls, Vergaben, Raid-Log, Punkte,
    Statistik, Raid-Archiv, Export. Das ist die Reihenfolge der Raidnacht wie heute.
  - Charakter: Ausrüstung, Talente, Berufe, Schriftrollen.
  - Welt: Dungeons, Raids, Quests, Karte.
  - Gilde: Mitglieder, Kalender, Gildenbank, Duelle, Werkzeuge.
  - Amisia: Einstellungen, Feedback, Über und Befehle.

  Kalender und PvP haben heute je nur eine Seite. In der Leiste wären sie eine Gruppe mit einer Zeile,
  darum ziehen sie in Gilde.
- **Seitenfenster in der Leiste (Vorschlag, Frage 2).** Die fünf Seitenreiter rechts entfallen. Ihre
  Fenster stehen als eigene Zeile in ihrer Gruppe, mit einem kleinen Fenster-Zeichen rechts im Balken:
  - Ausrüstungstabelle, Ausrüstungsziele und Talentrechner unter Charakter.
  - Würfelfenster und Soft-Reserve-Import unter Raid, nur in der Offiziersansicht.

  Ein Klick öffnet oder schließt das Fenster, die Hauptseite bleibt. Solange das Fenster offen ist,
  steht die Zeile weiß. Der Tooltip nennt wie heute den Namen und wozu das Fenster da ist.
- **Die Reiter unter dem Fenster entfallen.** Das Fenster wird unten um ihre Höhe ruhiger. An seine
  Stelle tritt nichts.
- **Das Fenster lässt sich in der Höhe ziehen (Frage 3).** Unten rechts sitzt der Größengriff des
  Chatfensters. Die Höhe reicht von 560 (heute) bis 860 und wird nie größer als der Bildschirm.
  Listen, die bis zum unteren Rand reichen (`fill`), wachsen mit. Die Leiste zeigt mehr Zeilen, bevor
  sie rollt. Die Höhe bleibt gemerkt. "Fensterposition zurücksetzen" setzt sie wieder auf 560.
- **Was bleibt:**
  - Das Suchfeld oben in der Leiste, ab 2 Zeichen ersetzen die Treffer die Leiste (D-45).
  - Unter der offenen Seite "Einstellungen" stehen deren Reiter und Abschnitte als dritte Ebene (D-49).
  - Der Kopf mit Aufnahme-Menü, Zahnrad und "i" (D-67).
  - Das Porträt als Knopf zur Übersicht.
- **Rollen in der Leiste.** Die Leiste rollt mit dem Mausrad, wenn die offene Gruppe nicht in die Höhe
  passt. Die Zeilen schrumpfen nicht mehr (heute bis 16 px). Die offene Seite bleibt beim Öffnen im
  Bild.

## Was es ausdrücklich nicht tut

- Die Breite bleibt 806. Alle Seiten sind auf 602 px Breite gebaut. Eine ziehbare Breite gehört zu
  einem späteren Schritt.
- Kein neuer Seitenkopf mit Titel und Unterzeile (Schritt 2), kein Kachelraster und kein Bildband
  (Schritt 3), keine aufklappbaren Zeilen auf den Seiten (Schritt 4).
- Keine Symbole in der Leiste (D-06) und keine eigenen Bilder, nur die Balken des Auktionshauses.
- Seiten lassen sich nicht als eigenes Fenster herauslösen. Die bestehenden Seitenfenster bleiben,
  wie sie sind.
- Keine Seite wird gelöscht oder umbenannt, nur ihre Gruppe ändert sich.

## Abläufe

1. `/amisia`: Das Fenster zeigt die zuletzt offene Seite, ihre Gruppe ist aufgeklappt, die anderen
   Gruppen stehen als goldene Balken darunter und darüber.
2. Klick auf "Welt": Raid klappt zu, Welt klappt auf, die zuletzt in Welt gewählte Seite (oder
   Dungeons) öffnet sich.
3. Klick auf "Ausrüstungstabelle ⧉" unter Charakter: Das Seitenfenster geht auf, die Zeile wird weiß,
   die offene Seite bleibt. Noch ein Klick schließt es.
4. Unten rechts am Griff ziehen: Das Fenster wird höher, die Liste der Dungeons zeigt mehr Zeilen. Nach
   `/reload` hat es dieselbe Höhe.

## Abnahmekriterien

- Wenn du das Fenster öffnest, dann hängen keine Reiter mehr unter dem Fenster und keine Seitenreiter
  rechts daneben, und links stehen die Gruppen Raid, Charakter, Welt, Gilde und Amisia.
- Wenn du auf eine zugeklappte Gruppe klickst, dann klappt die vorher offene zu und die zuletzt
  gewählte Seite der neuen Gruppe öffnet sich.
- Wenn du auf "Ausrüstungstabelle" klickst, dann öffnet sich das Seitenfenster, die Zeile ist weiß,
  solange es offen ist, und ein zweiter Klick schließt es.
- Wenn du das Fenster am Griff unten rechts höher ziehst und `/reload` machst, dann hat es dieselbe
  Höhe und lange Listen (Dungeons, Quests, Mitglieder) reichen bis zum unteren Rand.
- Wenn du in die Suche "dead" tippst und einen Treffer anklickst, dann klappt dessen Gruppe auf und die
  Seite ist darin gewählt.

## Sonderfälle

- **Raider-Ansicht:** Offiziersseiten (Rolls, Raid-Archiv, Export) und Offiziersfenster fehlen in der
  Leiste. Eine Gruppe ohne sichtbare Zeile fehlt ganz. Wechselt die Ansicht und die offene Seite
  verschwindet, öffnet sich die Übersicht und Raid klappt auf (wie heute).
- **Gespeicherter alter Reiter:** `settings.window.tab` hieß "gear", "calendar" oder "pvp". Dieser Wert
  wird beim ersten Lesen auf die neue Gruppe der zuletzt offenen Seite umgeschrieben. In `pages` werden
  die Seiten nach ihrer neuen Gruppe einsortiert. Was nicht passt, fällt weg.
- **Kleiner Bildschirm oder große `ui.scale`:** Die Höhe wird beim Öffnen und beim Ziehen auf die Höhe
  des Bildschirms begrenzt (geteilt durch die Skalierung).
- **Kampf:** Das Fenster und die Leiste sind keine geschützten Frames, Ziehen und Klappen gehen auch im
  Kampf.
- **TBC Anniversary und Era (D-57):** Balken und Plus/Minus des Auktionshauses, der Größengriff
  (`Interface\ChatFrame\UI-ChatIM-SizeGrabber-*`) und das Fenster-Zeichen gibt es dort auch. Fehlt ein
  Bild, steht der Balken ohne Zeichen.
- **Englischer Client:** Die Gruppennamen "Charakter" und "Welt" kommen neu nach
  `Locales/enUS_core.lua` ("Character", "World").
- **Ein Seitenfenster, das der Spieler mit seinem X schließt:** Die Zeile wird beim nächsten Neuzeichnen
  wieder gold (wie heute `ns.UpdateSideTabs`).

## Missbrauch/Vertrauen

Nichts. Nur die Anordnung des eigenen Fensters, nichts wird gesendet oder empfangen.

## Daten

- `settings.window.h`: die gezogene Höhe, Zahl 560 bis 860. Ein anderer Wert fällt beim Lesen weg.
- `settings.window.tab` und `pages`: neue Gruppenschlüssel `char` und `world` und der einmalige Umzug
  der alten Werte, siehe Sonderfälle.
- `ns.PANEL_GROUPS` wird zu Raid, Charakter, Welt, Gilde, Amisia. Die Seiten bekommen ihr neues `group`.
  Die Einstellungsabschnitte gehören heute zu einem Reiter (D-49). Sie ziehen mit: "gear" wird je nach
  Seite "char" oder "world", "calendar" und "pvp" werden "guild".
- Theme: `T.MAIN` bekommt `H_MIN`, `H_MAX`, `GRIP` und die Tokens der Gruppenbalken. `BTAB_*` und
  `TAB_*` der Seitenreiter fallen weg. `T.PAGE_H` wird zur Höhe der offenen Fensterhöhe abzüglich Kopf
  (Seiten lesen sie über eine Funktion statt der festen 478).
- In `docs/ARCHITECTURE.md` (Zeilen MainFrame, Registry, `settings`) und `docs/DECISIONS.md`: eine neue
  Entscheidung D-68 ersetzt in D-45 die Reiter unten und die Seitenreiter rechts. Suche und Gedächtnis
  der Seiten bleiben, D-52 (Reiter PvP) entfällt.

## Offene Fragen

1. **Gruppen:** Raid, Charakter, Welt, Gilde, Amisia wie oben, also Kalender und Duelle in Gilde?
   Vorschlag: ja. Die Alternative ist, die heutigen sechs Gruppen zu behalten (Ausrüstung bliebe dann
   mit 8 Seiten eine lange Gruppe).
2. **Seitenfenster:** als Zeilen mit Fenster-Zeichen in ihrer Gruppe? Vorschlag: ja. Die Alternative
   wären kleine Symbole im Kopf der passenden Seite (Ausrüstung, Talente, Rolls, Soft-Reserves).
3. **Größe:** nur die Höhe ziehbar, 560 bis 860? Vorschlag: ja. Für eine ziehbare Breite müssten erst
   alle Seiten mitwachsen können, das wäre ein eigener Schritt.

## Entscheidungen

- 2026-11-07: "Passt" -> alle drei Vorschläge: Gruppen Raid, Charakter, Welt, Gilde, Amisia (Kalender und
  Duelle in Gilde); die Seitenfenster als Zeilen mit Fenster-Zeichen in ihrer Gruppe; nur die Höhe ziehbar,
  560 bis 860.
- 2026-11-07, beim Bauen: Das Auktionshaus hat kein Plus/Minus an seinen Balken, darum steht dort das des Questlogs
  (`UI-PlusButton-Up`/`UI-MinusButton-Up`); das Fenster-Zeichen ist das Maximieren-Zeichen des Chatfensters
  (`UI-ChatIcon-Maximize-Up`). Die Seitenfenster stehen direkt unter ihrer Seite. Das Offiziers-Würfelfenster heißt in
  der Leiste "Würfelfenster" (neben der Seite "Rolls"). `T.PAGE_H` bleibt eine Zahl, die das Fenster beim Ziehen neu
  setzt; die Listen mit `fill` und die Bossliste der Dungeons merken sich ihren Platz (`W.FillTo`) und passen sich
  am Ende des Ziehens an (`W.FitLists`). Die Einstellungsabschnitte sind die vierte Ebene (`NAV_SUB3_X`).
