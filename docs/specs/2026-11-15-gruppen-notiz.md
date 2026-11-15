# Spec: Gruppen-Notiz im Dungeon

Stand: 2026-11-15 · Status: freigegeben ·
Feature: F-213

## Ziel

Was die Raid-Notiz (F-196) im Raid kann, soll es in einer Fünfergruppe geben: der Gruppenleiter schreibt eine
Notiz (Taktik, wer was unterbricht, wer welches Ziel), schickt sie an die Gruppe, und jeder mit Amisia sieht sie
im selben kleinen Fenster, das auch im Kampf offen bleibt. Darunter steht die eigene Notiz zum Dungeon (F-212).
Gelöst ist es, wenn eine Gruppe im Dungeon die Taktik im Fenster hat statt im Chatverlauf.

## Was es tut

- **Ein Fenster für beides:** das Fenster "Raid-Notiz" (`AmisiaRaidNote`) heißt in einer Gruppe "Gruppen-Notiz".
  Oben die zuletzt empfangene (oder selbst gesendete) Notiz mit "von <Name>, <Uhrzeit>"; darunter, in einem Dungeon mit
  eigener Notiz (F-212), "Deine Notiz zu <Dungeon>" mit Text und Boss-Notizen, sonst wie bisher die eigene Notiz.
  Verschieben, Größe, Schloss, Schrift und Hintergrund wie bei der Raid-Notiz; im Kampf öffnen, schließen, scrollen.
- **Seite:** die Seite Raid > Raid-Notiz heißt "Raid- und Gruppen-Notiz" und gilt in Raid und Gruppe. Knopf "An Gruppe senden" in einer
  Gruppe, "An Raid senden" im Raid. Vorlagen (30) für beides.
- **Wer sendet:** in einer Gruppe nur der Gruppenleiter, auch wenn er nicht in der Gilde ist (Zufallsgruppen). Im Raid
  bleibt alles wie bisher (D-126).
- **Länge:** eine Gruppen-Notiz hat höchstens 1000 Bytes und 20 Zeilen (die Raid-Notiz 4000).
- **Beim Betreten:** in einem Dungeon öffnet sich das Fenster von selbst, wenn es eine Gruppen-Notiz oder eine eigene
  Dungeon-Notiz gibt (Einstellung "Fenster beim Betreten eines Dungeons öffnen", an).
- **Neue Notiz:** öffnet das Fenster (wie bisher, abschaltbar) und eine Chatzeile "Gruppen-Notiz von <Name>".
- **Später dazugekommen / `/reload`:** der Leiter schickt seine Notiz noch einmal, sobald jemand der Gruppe beitritt
  oder fragt.
- `/amisia notiz` und der Eintrag im Minimap-Menü öffnen das Fenster in Raid und Gruppe.

## Was es ausdrücklich nicht tut

- Keine Timer oder Ansagen im Kampf (wie bei der Raid-Notiz).
- Keine Links, Farbcodes oder Symbole von außen; nur Zielmarkierungen `{stern}` usw., Namen der Gruppe in
  Klassenfarbe, eigene Zeilen gelb (wie bei der Raid-Notiz).
- Die eigene Dungeon-Notiz (F-212) wird nie gesendet; es gibt keinen Knopf, der sie in die Gruppen-Notiz kopiert
  (später möglich).
- Keine Notiz von einem Gruppenmitglied, das nicht Leiter ist; keine Gruppen-Notiz in Schlachtfeldern.

## Abläufe

1. Der Gruppenleiter öffnet Raid > Raid- und Gruppen-Notiz, schreibt "{totenkopf} zuerst, Vulo unterbricht Heiler" und klickt
   "An Gruppe senden".
2. Jedes Mitglied mit Amisia bekommt sie binnen Sekunden: Chatzeile, das Fenster "Gruppen-Notiz" öffnet sich. Wer
   eine eigene Notiz zu diesem Dungeon hat, sieht sie darunter.
3. Ein Spieler kommt später dazu: der Leiter schickt die Notiz von selbst noch einmal.
4. Gibt der Leiter die Leitung ab, darf der neue Leiter eine neue Notiz senden; die alte bleibt stehen, bis sie ersetzt
   wird oder die Gruppe sich auflöst.
5. Ohne Gruppen-Notiz öffnet sich das Fenster beim Betreten eines Dungeons mit eigener Notiz und zeigt nur diese.

## Abnahmekriterien

- Wenn der Gruppenleiter unter Raid > Raid- und Gruppen-Notiz Text schreibt und "An Gruppe senden" klickt, dann sehen die anderen mit
  Amisia binnen Sekunden die Chatzeile und das Fenster "Gruppen-Notiz" mit dem Text (braucht: Gruppe).
- Wenn ein Mitglied, das nicht Leiter ist, die Seite öffnet, dann kann es nicht senden; nach "Leitung übergeben" an
  es kann es (braucht: Gruppe).
- Wenn jemand der Gruppe später beitritt oder `/reload` macht, dann hat er nach wenigen Sekunden die aktuelle Notiz
  (braucht: Gruppe).
- Wenn du einen Dungeon mit eigener Notiz betrittst, dann öffnet sich das Fenster und zeigt "Deine Notiz zu <Dungeon>"
  mit Text und Boss-Notizen, unter einer Gruppen-Notiz, wenn es eine gibt.
- Wenn du im Bosskampf `/amisia notiz` eingibst, dann öffnet und schließt sich das Fenster ohne Fehlermeldung.

## Sonderfälle

- Bosskampf/Kampfsperre: nichts wird gesendet ("An Gruppe senden" grau); empfangen und anzeigen geht.
- Gruppe wird Raid: ab dann gilt die Raid-Notiz mit ihren Regeln; die Gruppen-Notiz bleibt bis zur nächsten Notiz
  stehen. Raid wird Gruppe: ebenso umgekehrt.
- Gruppe verlassen oder aufgelöst: die Gruppen-Notiz verschwindet aus dem Fenster (die eigene bleibt).
- Leiter ohne Amisia: keine Gruppen-Notiz; das Fenster zeigt nur die eigene Dungeon-Notiz.
- Leiter von einem anderen Realm (Forever: Nachnamen): der Name, den der Server als Absender nennt.
- TBC und Era (kein Ausrüstungsmodul): Gruppen-Notiz geht, die eigene Dungeon-Notiz gibt es dort nicht.
- `/reload` des Leiters: er hat seine gesendete Notiz noch (gespeichert) und schickt sie beim Fragen.

## Missbrauch/Vertrauen

- Senden darf nur, wen die eigene Gruppenliste des Empfängers als Leiter nennt (`UnitIsGroupLeader`); der Absender
  ist der Name, den der Server setzt. Ein Fremder außerhalb der eigenen Gruppe wird nie gehört.
- Neu: Daten von einem Spieler außerhalb der Gilde. Sie gehen nicht über Datenblöcke (die bleiben nur für die Gilde,
  D-12), sondern als bis zu 6 kurze Nachrichten `TN` nur über PARTY; jede wird ganz geprüft, ein falsches Teil
  verwirft die Notiz. Der Text wird beim Anzeigen entschärft wie die Raid-Notiz (jedes `|` verdoppelt).
- Fluten: der Leiter sendet höchstens alle 10 s (auch beim Nachschicken), die Teile zweier Notizen werden getrennt
  zusammengesetzt, höchstens 1000 Bytes und 20 Zeilen; eine Frage `TQ` je 30 s.
- Ein böser Leiter kann nur Text in dieses Fenster schreiben; abschaltbar mit "Gruppen-Notiz annehmen" (an).

## Daten

- Neue Nachrichten (Präfix Steuerung, nur PARTY): `TN` (Leiter -> Gruppe: Id, Teil i/n, Textstück bis 200 Bytes;
  bei "Senden", bei einem Beitritt, als Antwort auf `TQ`), `TQ` (Mitglied -> Gruppe: "habe Id x" oder "-", nach
  Beitritt und `/reload`, je 30 s).
- `AmisiaDB.raidNote` bekommt `party = {id, at, by, text}` (die aktuelle Gruppen-Notiz; nach dem Verlassen der Gruppe
  gelöscht).
- Neue Einstellungen im Abschnitt `raidnote`: `raidnote.party` ("Gruppen-Notiz annehmen", an),
  `raidnote.dungeonOpen` ("Fenster beim Betreten eines Dungeons öffnen", an).
- Seite und Fenster bekommen neue Namen ("Raid- und Gruppen-Notiz", "Gruppen-Notiz"); ARCHITECTURE (Nachrichten, Schlüssel,
  Einstellungen) und eine Entscheidung in DECISIONS (Ausnahme von D-12 nur für `TN`) im selben Commit.

## Offene Fragen

Nichts. Die drei Fragen sind entschieden (unten).

## Entscheidungen

- 2026-11-15: Umfang: "Fenster + an Gruppe senden" -> Fenster wie die Raid-Notiz, der Gruppenleiter sendet an die
  Gruppe, die eigene Dungeon-Notiz darunter.
- 2026-11-15: Vertrauen: "Gruppenleiter, jeder" -> vom Leiter der eigenen Gruppe, auch außerhalb der Gilde.
- 2026-11-15: Fragen 1-3: "Passt, bauen" -> keine Vorschläge an den Leiter; das Fenster öffnet sich beim Betreten auch
  nur mit der eigenen Dungeon-Notiz (abschaltbar); 1000 Bytes und 20 Zeilen.
- 2026-11-15: Spec: "Passt, bauen" -> freigegeben.
