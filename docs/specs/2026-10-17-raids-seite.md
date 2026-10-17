# Spec: Seite "Raids" im Reiter Ausrüstung

Stand: 2026-10-17 · Status: freigegeben ·
Feature: F-122

## Ziel

Die Raids bekommen eine eigene Seite unter "Dungeons" (Wunsch des Nutzers 2026-10-17 mit Bildschirmfoto
der Seitenliste: "können wir hier unter Dungeons noch Raids machen"). Heute stehen die drei Raids erst ab
Stufe 60 am Ende der Dungeon-Liste und gehen dort unter. Gelöst ist es, wenn man in der Liste links
"Raids" anklickt und alle Raids mit Bild, Bossen, Beute und Öffnungstag sieht, auf jeder Stufe.

## Was es tut

- Neue Seite **Raids** im Reiter Ausrüstung, direkt unter "Dungeons" (order 52, nur mit Ausrüstungsdaten).
- Kopfzeile: die Spezialisierung der Seite Ausrüstung (dieselbe Wahl), keine Chips Level/Wert/Kette (bei
  drei Raids sinnlos).
- Zeile darunter: der nächste offene Raid mit Upgrades für dich ("Nächster Raid: Onyxia's Lair · 3
  Upgrades"), vor dem Start "Raids öffnen am 09.12." bzw. unter 60 "Raids ab Stufe 60".
- Liste aller Raids (heute Barrow Deeps 10, Hyjal Summit 20, Onyxia's Lair 40): Name, Größe, Passung
  ("ab 09.12.", "ab Stufe 60", "passt"), Upgrades, Je Lauf, Wert, und **ID**: deine eigene Raid-ID der
  Instanz ("gesperrt bis Mi 18:00" bzw. leer) aus den gespeicherten Instanzen des Spiels.
- Darunter wie bei den Dungeons: Bild des Raids mit Bossmodell, die Bosse mit ihrer Beute (grün:
  Upgrade für dich, Chance, Zuwachs), Rechtsklick-Menü, Strg-Klick Anprobe, Shift-Klick in den Chat, Knopf
  "Wegpunkt" zum Eingang. Keine Quests-Ansicht.
- Die Seite Dungeons zeigt danach nur noch Dungeons; "Nächster Dungeon", Rangliste und Kette empfehlen
  nie einen Raid.
- `/amisia raids` (en `raids`) öffnet die Seite; die Suche und ein Klick auf einen Raid-Eingang auf der
  Weltkarte öffnen den Raid auf der Seite Raids statt auf der Seite Dungeons.

## Was es ausdrücklich nicht tut

- Keine Raid-Beute aus dem Netz (D-03): Bosse und Beute kommen aus den Fakten, den Itemdaten und den
  Drop-Aufzeichnungen der Gilde; vor dem 09.12. ist die Beuteliste daher fast leer (Hinweis statt
  Fantasie-Chancen).
- Keine Raid-IDs anderer Spieler (das macht der Raid-Check für Offiziere), keine Anmeldung, kein Kalender.
- Kein Soft-Reserve oder Loot-Prio auf dieser Seite (eigene Seiten im Reiter Raid).
- Keine Attunement-Kette (Onyxia) als eigene Ansicht.

## Abläufe

1. Spieler öffnet Ausrüstung -> "Raids". Die Seite wählt den zuletzt gewählten Raid, sonst den
   empfohlenen, sonst den ersten.
2. Klick auf einen Raid: Bild, Bossmodell und Bossliste wechseln. Maus auf einem Boss: sein Modell.
3. "Wegpunkt": Kartenziel auf den Eingang (fehlt er, wird der Knopf grau).
4. Unter Stufe 60 oder vor dem Start: alle Raids sichtbar, grau, mit "ab Stufe 60" bzw. "ab 09.12.";
   ihre Beute wird trotzdem bewertet (wie heute ein Raid, den die Weltkarte öffnet).

## Abnahmekriterien

- Wenn du den Reiter Ausrüstung öffnest, dann steht links "Raids" direkt unter "Dungeons", und die
  Seite listet Barrow Deeps (10), Hyjal Summit (20) und Onyxia's Lair (40), vor dem 09.12. mit "ab 09.12.".
- Wenn du auf der Seite Dungeons bist, dann steht dort kein Raid mehr, auch nicht mit Stufe 60.
- Wenn du Onyxia's Lair wählst, dann zeigt das Bild den Raid mit Onyxias Modell, darunter "Onyxia" mit
  der bekannten Beute; "Wegpunkt" setzt das Kartenziel auf den Eingang in den Düstermarschen.
- Wenn du `/amisia raids` eingibst, dann öffnet sich die Seite Raids.
- Wenn du eine Raid-ID hast (braucht: Raid), dann steht in der Spalte ID "bis <Tag Uhrzeit>".

## Sonderfälle

- Keine Ausrüstungsdaten: Seite fehlt (wie Dungeons). Keine Raid-Fakten: "Keine Raid-Daten."
- Englischer Client: Namen aus den Fakten wie bei den Dungeons; Spalten und Texte über `L[...]`.
- Kampf und Kampfsperre: die Seite liest nur Daten und die eigenen gespeicherten Instanzen
  (`GetSavedInstanceInfo`), sendet nichts; im Kampf bleibt die ID-Spalte beim letzten Stand.
- Ein gespeicherter `settings.bis.dungeon`, der ein Raid war: die Seite Dungeons nimmt dann ihren
  empfohlenen Dungeon; die Seite Raids hat ihre eigene Wahl.

## Missbrauch/Vertrauen

Nichts. Die Seite sendet und empfängt nichts; Drop-Aufzeichnungen anderer kommen wie bisher über den
bestehenden Abgleich mit seinen Prüfungen.

## Daten

- Kein neuer `AmisiaDB`-Schlüssel; in `settings.bis` neu `raid` (Schlüssel des gewählten Raids), geprüft
  wie `dungeon`.
- Keine Nachrichten, Exportzeilen oder Einfügeblöcke.
- ARCHITECTURE: neue Datei `UI/Pages/Raids.lua` in der Modulkarte und TOC; `ns.RaidList` in
  `Gear/Dungeons.lua`; Befehl `raids`.

## Offene Fragen

1. Raids ganz von der Seite Dungeons nehmen? Vorschlag: ja (sonst stehen sie doppelt).
2. Spalte "ID" mit deiner eigenen Raid-ID? Vorschlag: ja, nur die eigene.
3. Raids auf jeder Stufe zeigen (grau unter 60)? Vorschlag: ja.

## Entscheidungen

- 2026-10-17: "Passt, alle drei Vorschläge so. Bauen." -> Frage 1: Raids nur noch auf der Seite Raids;
  Frage 2: Spalte ID mit der eigenen Raid-ID; Frage 3: Raids auf jeder Stufe (grau unter 60).
- 2026-10-17 beim Bauen: die Offiziersseite "Raids" (aufgezeichnete Raids, Reiter Raid) hat schon den
  Schlüssel `raids`; die neue Seite heißt intern `raidjournal` (Datei `UI/Pages/RaidJournal.lua`),
  sichtbar "Raids". Die Einstellungen "Drop-Daten" gelten auch für sie.
