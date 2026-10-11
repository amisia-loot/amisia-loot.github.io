# Spec: Reiter unten, Suchfeld und Monatskalender im Hauptfenster

Stand: 2026-10-11 · Status: freigegeben (Entscheidungen des Nutzers vom 2026-10-11, gebaut für 2.27.0) ·
Feature: F-094 (Reiter), F-095 (Suche), F-096 (Kalender-Seite)

## Ziel

Das Hauptfenster wird übersichtlicher: statt einer langen Seitenliste mit aufklappbaren Abschnitten
wählt man unten einen Reiter (wie im Charakterfenster des Spiels), links stehen nur dessen Seiten.
Ein Suchfeld oben links findet Seiten, Einstellungen, Items und Spieler. Ein neuer Reiter "Kalender"
zeigt die Raidtermine als Monatsblatt. Gelöst ist es, wenn man jede Seite mit höchstens zwei Klicks
erreicht und den nächsten Raid ohne das Kalenderfenster des Spiels sieht.

## Was es tut

- **Reiter unten am Fenster** (die Reiter-Vorlage des Spiels für Fenster, `PanelTabButtonTemplate`):
  Raid, Ausrüstung, Gilde, Kalender, Amisia in dieser Reihenfolge. Ein Reiter ohne sichtbare Seite
  (Offiziers- oder Expertenseiten) fehlt. Links stehen nur die Seiten des gewählten Reiters, ohne
  Abschnittsleisten. Der letzte Reiter und je Reiter die letzte Seite bleiben gemerkt
  (`settings.window.tab`, `settings.window.pages`); `ns.ShowPage` und jeder Befehl, der eine Seite
  öffnet, wechseln den Reiter mit. Die Seitenreiter rechts bleiben.
- **Suchfeld oben links** über der Seitenliste: ab zwei Zeichen wird die Seitenliste zur
  Ergebnisliste mit den Gruppen "Seiten", "Einstellungen", "Items", "Spieler" (je höchstens 8).
  Seiten nach Namen (nur sichtbare), Einstellungen nach Name, Hilfetext und Auswahlwerten (Klick:
  Seite Einstellungen mit diesem Suchtext), Items nach Namen aus den Namen, die Amisia schon kennt,
  und den Ausrüstungsdaten (Klick: der Link in die Chatzeile; Maus darüber: Tooltip), Spieler aus
  den aufgezeichneten Raids, Vergaben und der Aufstellung (nur Offiziersansicht; Klick: Statistik mit
  diesem Spieler). Escape oder das X leeren das Feld.
- **Seite "Kalender"** (Reiter Kalender, für alle): goldener Monatstitel ("Oktober 2026") mit
  Pfeilen links und rechts, Wochentage auf der braunroten Leiste des Spielkalenders, 6 Reihen
  Tagesfelder auf dem Pergament des Spielkalenders, Tage anderer Monate dunkler, heute hervorgehoben.
  Ein Tag mit Raidtermin zeigt Uhrzeit und kurzen Titel und einen Punkt in der Farbe des eigenen
  Stands; ein vergangener Tag mit aufgezeichnetem Raid zeigt die Zone. Klick auf einen Tag: rechts die
  Termine des Tages und die Teilnehmer (dieselbe Liste wie im Fenster "Raid-Kalender"), "Anmelden ..."
  bzw. "Ändern ..." und für Offiziere "Zur Aufstellung". Der Wochenbeginn folgt dem Spielkalender
  (deutscher Client: Montag, englischer: Sonntag).

## Was es ausdrücklich nicht tut

- Keine Symbolleiste (vom Nutzer nicht gewählt).
- Das Fenster "Raid-Kalender" bleibt; die Seite ersetzt es nicht.
- Die Seite schreibt nichts in den Spielkalender und liest nur nach den Regeln von `ns.Cal` (D-42).
- Keine Termine über die 14 Tage hinaus, die Amisia ohnehin liest; keine Daten aus dem Netz.
- Die Suche baut keine Daten beim ersten Buchstaben und lädt keine Item-Daten vom Server nach.

## Abläufe

1. Spieler öffnet `/amisia`: das Fenster zeigt den zuletzt gewählten Reiter mit seiner letzten Seite.
2. Klick auf "Ausrüstung" unten: links Ausrüstung, Karte, Quests, Berufe, Talente; rechts die zuletzt
   dort offene Seite. `/amisia einstellungen` springt auf den Reiter Amisia.
3. Spieler tippt "ger" ins Suchfeld: links stehen "Seiten: Ausrüstung", Einstellungen mit "Ger..." usw.
   Klick auf ein Ergebnis führt hin und leert das Feld.
4. Klick auf "Kalender": das Monatsblatt des heutigen Monats, der nächste Termin ist gewählt, rechts
   seine Teilnehmer; ein Klick auf einen anderen Tag zeigt dessen Termine. Pfeile blättern.

## Abnahmekriterien

- Wenn du `/amisia` öffnest, dann stehen unten am Fenster die Reiter "Raid", "Ausrüstung", "Gilde",
  "Kalender", "Amisia"; links nur die Seiten des gewählten Reiters.
- Wenn du auf "Ausrüstung" klickst, eine Seite wählst, das Fenster schließt und `/reload` machst, dann
  öffnet `/amisia` wieder diesen Reiter mit dieser Seite; `/amisia einstellungen` wechselt auf "Amisia".
- Wenn du "Expert" ins Suchfeld tippst, dann steht unter "Einstellungen" "Expertenmodus"; ein Klick
  öffnet die Einstellungen mit diesem Suchtext, Escape leert das Feld.
- Wenn du den Reiter "Kalender" öffnest, dann zeigt das Blatt den Monat golden mit Pfeilen, heute ist
  hervorgehoben und der Raid von Vulo Hunt steht mit Uhrzeit und Titel im Tag; ein Klick zeigt rechts
  die Teilnehmer und "Anmelden ...". (braucht: Gilde)
- Wenn du als Raider (Ansicht "Raider") die Reiter ansiehst, dann fehlt keiner, und die Seite Export
  fehlt unter "Gilde".

## Sonderfälle

Kampf und Kalenderfenster des Spiels offen: die Seite liest dann nicht (Grund in der Zeile unten).
Keine Gilde: das Blatt zeigt nur aufgezeichnete Raids, die Tagesliste sagt "Nur in einer Gilde".
Englischer Client: Reiter und Wochentage auf Englisch, Woche ab Sonntag. Ein Reiter, der durch einen
Wechsel der Ansicht leer wird, verschwindet, die offene Seite fällt auf die Übersicht zurück.

## Missbrauch/Vertrauen

Nichts Neues: keine Nachricht, kein Schreibzugriff. Die Spielersuche zeigt Namen nur in der
Offiziersansicht (D-36: Zahlen pro Spieler sehen nur Offiziere). Kalendertitel werden wie bisher
gereinigt (`Cal.Clean`).

## Daten

`settings.window` bekommt `tab` (Gruppe des letzten Reiters) und `pages` (`{[Gruppe] = Seitenschlüssel}`);
`collapsed` entfällt (beim Laden gelöscht). `ns.PANEL_GROUPS` bekommt `calendar`. Keine neuen
Nachrichten, Exportzeilen oder Einfügeblöcke.

## Offene Fragen

1. Wo sitzt das Suchfeld? Vorschlag: oben in der Seitenliste, die Ergebnisse ersetzen die Liste.
2. Bleibt über der Seitenliste eine Titelleiste des Reiters? Vorschlag: nein, der Reiter zeigt es.

## Entscheidungen

- 2026-10-11: Nutzer wählt "Reiter unten am Fenster", "Monatskalender", "Suchfeld oben links"; der
  Kalender als eigener Reiter im Hauptfenster, das Fenster "Raid-Kalender" bleibt. Keine
  Symbolleiste.
- 2026-10-11: Fragen 1 und 2 nach Vorschlag (Auftrag: "your call, keep it clean").
