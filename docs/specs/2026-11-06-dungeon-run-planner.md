# Spec: Lauf-Planer im Dungeon-Journal

Stand: 2026-11-06 · Status: freigegeben (der Nutzer: "du musst deutlich kreativer werden" zum Journal von
F-138; nach einem Entwurf mit Laufbilanz, Bossleiste, Lohn, Levelfenster, Belohnung gegen Getragenes und
Abholroute: "Ja, alles bauen") · Feature: F-139

## Ziel

Das Journal von F-138 zeigt, was es gibt. Der Lauf-Planer beantwortet die Fragen vor einem Dungeon: Was bringt
mir der Lauf? Was muss ich vorher abholen und in welcher Reihenfolge? Was passiert bei welchem Boss? Welche
Quest lohnt sich, welche kann weg? Gelöst ist es, wenn man vor dem Lauf eine Route abfährt, im Dungeon weiß,
bei welchem Boss welche Quest hängt, und danach weiß, wo man abgibt.

## Was es tut

- **Laufbilanz** im Bild des Dungeons, rechts neben dem Namen: "Dieser Lauf: +8950 EP · 3 Upgrades" und ein
  EP-Balken: der eigene Stand (lila wie im Spiel) und dahinter, was die offenen Quests bringen (blau). Der
  Tooltip sagt "Stufe 17, 38 %" und "nach dem Lauf: Stufe 18, 20 %". Auf der Höchststufe nur die Upgrades.
  Quests ohne bekannte EP zählen nicht; dann steht "mindestens" davor.
- **"Dein Lauf"** als erste Zeile der Questliste links (Symbol: das Dungeon-Zeichen; darunter "4 offen ·
  3 Halte"). Ein Klick zeigt rechts den Lauf-Planer:
  - **Vor dem Lauf:** die nächsten Schritte der offenen Quests, die draußen liegen (annehmen, abgeben, was
    fertig im Log steht), nach Zonen gruppiert und durchnummeriert, die eigene Zone zuerst, dann die Zonen mit
    den meisten Halten. Jeder Halt mit "Karte". Der Knopf der Kopfzeile heißt hier "Route: Halt 1/4 auf
    der Karte" und geht mit jedem Klick einen Halt weiter (nach dem letzten wieder zum ersten).
    Darunter in Orange, was noch nicht geht: "ab Stufe 20: <Quest>".
  - **Im Dungeon:** die Bosse in der Reihenfolge des Spiels (Client-Tabelle `DungeonEncounter`,
    `OrderIndex`) als senkrechte Leiste. An jedem Boss: die Quests, deren Ziel ihn nennt ("Ziel: ..."), die
    Quests, deren Start-Gegenstand er fallen lässt ("startet: ..."), und wie viele Upgrades er für dich hat.
    Quests mit Ziel im Dungeon, die keinem Boss zugeordnet sind, stehen unter "Sonst im Dungeon".
  - **Nach dem Lauf abgeben:** wo die Dungeon-Quests abgegeben werden, nach Zonen gruppiert, mit "Karte".
- **Lohn** je Quest der Liste: rechts in der zweiten Zeile ein Wort in Farbe ("Muss" grün, "Lohnt" hellgrün,
  "Kann weg" grau, "Später" orange bei zu niedriger Stufe), darunter ein dünner Balken, wie viel sie im
  Vergleich zur besten Quest des Dungeons bringt. Der Upgrade-Wert wandert in die erste Hälfte der Zeile.
  Lohn = EP der offenen Pflichtschritte in Prozent einer Stufe plus 25 für ein Upgrade, geteilt durch den
  Aufwand (1 + 0,5 je Zone draußen; Schritte kosten nichts, sie bringen eigene EP). "Muss" ab 20, "Lohnt" ab 8,
  "?" ohne bekannte EP und ohne Upgrade. Der Tooltip zeigt die Teile.
- **Levelfenster** rechts über "Nächster Schritt": ein Balken von der Mindeststufe bis zu der Stufe, ab der
  die Quest grau wird (die "green range" des Clients, D-66), mit einem Strich bei der eigenen
  Stufe; daneben "grau ab 24 (noch 7 Stufen)" oder "schon grau: wenig EP".
- **Belohnung gegen Getragenes:** in der Kachel "statt <Item>" (was in diesem Platz angelegt ist, "Platz
  leer" ohne Item); bei mehreren Belohnungen trägt das beste Upgrade "beste Wahl".
- **Erledigte Schritte am Stück** am Anfang des Questwegs werden eine Zeile ("Schritte 1-5 erledigt");
  ein Klick klappt sie auf und wieder zu.

## Was es ausdrücklich nicht tut

- Kein Hinweis für Twinks: Amisia kennt die Taschen der Twinks (F-137), nicht ihre Ausrüstung.
- Keine Gruppen-Abstimmung (wer in der Gruppe welche Quest hat): braucht eine neue Addon-Nachricht und eine
  eigene Spec.
- Keine kürzeste Route über Kontinente: geordnet wird nach Zonen, nicht nach Entfernung.
- Nichts Neues gespeichert: Route und aufgeklappte Schritte leben nur im Speicher.

## Abläufe

1. Seite Dungeons, Quests, eine Quest anklicken: das Journal; oben die Laufbilanz.
2. Links "Dein Lauf": rechts Vor dem Lauf, Im Dungeon, Nach dem Lauf.
3. "Route: Halt 1/3 auf der Karte" klicken: Weltkarte und Wegpunkt beim ersten Halt; noch einmal: der zweite.

## Abnahmekriterien

- Wenn du das Journal eines Dungeons mit offenen Quests öffnest, dann steht im Bild "Dieser Lauf: +... EP"
  mit einem Balken, und sein Tooltip nennt deine Stufe nach dem Lauf.
- Wenn du links "Dein Lauf" anklickst, dann stehen rechts die Halte vor dem Lauf nach Zonen, die Bosse in
  ihrer Reihenfolge mit den Quests daran und die Abgaben nach dem Lauf.
- Wenn du "Route: Halt 1/n auf der Karte" mehrmals klickst, dann springt der Wegpunkt von Halt zu Halt.
- Wenn du die Questliste ansiehst, dann steht bei jeder offenen Quest "Muss", "Lohnt", "Kann weg" oder
  "Später" mit einem Balken, und der Tooltip erklärt den Wert.
- Wenn eine Belohnung ein Upgrade ist, dann steht in ihrer Kachel "statt <dein Item>", und bei mehreren
  Belohnungen trägt die beste "beste Wahl".

## Sonderfälle

In Instanzen und im Kampf setzt "Karte" nur Amisias eigenes Ziel (D-62). Dungeons ohne Bossreihenfolge in den
Daten zeigen die Bosse in der Reihenfolge der Item-Daten. Ohne bekannte EP zählt eine Quest nur mit ihrem
Upgrade. Auf der Höchststufe zählen nur Upgrades. Englischer Client: alle neuen Texte in
`Locales/enUS_gear.lua`. Boss-Namen im Zieltext werden ohne Leerzeichen und Groß-/Kleinschreibung verglichen
("Edwin van Cleef" = "Edwin VanCleef").

## Missbrauch/Vertrauen

Nichts. Nur eigene Daten und die Daten des Addons, nichts wird gesendet.

## Daten

`Data/DungeonData.lua` bekommt je Dungeon `order` (Namen der Bosse in der Reihenfolge des Spiels) aus der
Client-Tabelle `DungeonEncounter`, die `tools/export_db2.ps1` schon exportiert (`tools/build_dungeons.py
--wago`). Keine neuen Schlüssel in `AmisiaDB`; Layout-Werte in `T.DJOURNAL`.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-06: alle Teile des Entwurfs bauen, außer Twinks (keine Daten) und Gruppe (eigene Spec).
- Lohn-Formel und Grenzen wie oben; Graustufe nach der Tabelle des Spiels (D-66).
- 2026-11-06, beim Bauen: Schritte kosten keinen Aufwand mehr (die erste Formel nannte große Upgrades am Ende
  langer Questreihen "Kann weg"); ohne angelegtes Item steht "Platz leer" statt "statt ...".
- 2026-11-06, nach dem Review: Graustufe nach `GetQuestGreenRange`/Graustufe der Kreaturen statt der
  Erfahrungstabelle; Bossreihenfolge nur der normalen Schwierigkeit; die Bosse der Item-Daten ohne "Trash";
  geteilte Halte einmal; Quests über der eigenen Stufe zählen nicht in der Laufbilanz.
