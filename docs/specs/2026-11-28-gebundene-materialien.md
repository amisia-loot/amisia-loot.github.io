# Spec: Wer in der Gilde seelengebundene Materialien hat

Stand: 2026-11-28 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-242

## Ziel

Manche Rezepte brauchen Materialien, die beim Aufheben gebunden werden (Dämonische Rune, Blut der Helden,
Ogergerbsäure, Haut des Schattens ...). Die kann man nicht kaufen oder verschicken; wer sie hat, muss selbst
herstellen oder sie selbst verbrauchen. Heute weiß Amisia das nur für die eigenen Charaktere. Gelöst ist es, wenn
man bei einem solchen Rezept sieht, wer in der Gilde die Materialien hält, und ihn fragen kann.

## Was es tut

- **Welche Materialien:** die Reagenzien der Berufsdaten, die das Spiel als "beim Aufheben gebunden" führt
  (`ItemSparse.Bonding = 1`). Heute sind das 7: Goblin-Bauhelm, Dämonische Rune, Ausgefranste Monstrositätsnaht,
  Haut des Schattens, Blut der Helden, Weihwasser von Stratholme, Ogergerbsäure. Neue kommen mit dem Datenbau.
- **Teilen:** jedes Mitglied mit Amisia sagt der Gilde, wie viele davon seine Charaktere dieser Gilde in Taschen
  und Bank haben (dieselbe Zählung wie die Spalte "Twinks" der Route, F-159).
- **Anzeigen:**
  - Rezept-Details auf Berufe: unter den Materialien eine Zeile "Gebunden in der Gilde: Anna 3, Bob 1"
    (online zuerst und grün, wie die Hersteller).
  - Item-Tooltip eines solchen Materials: dieselbe graue Zeile (mit der bestehenden Einstellung
    "Materialien im Item-Tooltip").
  - Einkaufsliste der Route: bei einem gebundenen Material der Hinweis "gebunden, in der Gilde: Anna 3".
- **Einstellung** unter Berufe: "Gebundene Materialien mit der Gilde teilen" (an).

## Was es ausdrücklich nicht tut

- Keine anderen Materialien: was handelbar ist, gehört in die Gildenbank oder ins Auktionshaus. Ein Bestand aller
  Taschen der Gilde wäre zu viel und zu privat.
- Kein Anfragen-Knopf mit eigenem Ablauf: die Zeile hat das Flüstern-Menü wie die Hersteller.
- Keine Mengen für andere Realms oder Fraktionen.

## Abläufe

1. Anna hat 3 Dämonische Runen auf ihrem Twink. 60-180 s nach ihrem Login (und nach einer Änderung höchstens
   einmal in 5 Minuten) geht ihre Zählung an die Gilde.
2. Bob öffnet auf Berufe das Rezept "Fläschchen der Titanen" und sieht "Gebunden in der Gilde: Anna (Twink) 3".
3. Ein Klick auf die Zeile öffnet das Menü mit "Flüstern".

## Abnahmekriterien

- Wenn ein Gildenmitglied mit Amisia eine Dämonische Rune in Tasche oder Bank hat, dann steht sie binnen etwa
  4 Minuten nach seinem Login in den Rezept-Details eines Rezepts, das sie braucht, unter "Gebunden in der Gilde"
  (braucht: Gilde).
- Wenn du mit der Maus auf eine Dämonische Rune gehst und "Materialien im Item-Tooltip" an ist, dann nennt der
  Tooltip, wer in der Gilde welche hat (braucht: Gilde).
- Wenn das Mitglied seine Runen verbraucht, dann ist es binnen 5 Minuten aus der Zeile verschwunden (braucht:
  Gilde).
- Wenn du "Gebundene Materialien mit der Gilde teilen" ausschaltest, dann sehen die anderen deine Mengen
  spätestens nach dem nächsten Login nicht mehr.

## Sonderfälle

- Bosskampf, Kampfsperre, Schlachtfeld, Instanz: die Nachricht wartet wie `PC` (F-232), aus einer Instanz 5-15 s
  danach.
- Twinks: gemeldet werden die eigenen Charaktere dieser Gilde (wie `AC`, D-135), jeder mit seinem Namen.
- Bank nie geöffnet: die Bank zählt erst nach dem ersten Besuch (wie heute bei den Twinks).
- Nichts gebunden: die Nachricht sagt "nichts" (damit alte Mengen verschwinden), sendet aber nur, wenn sich etwas
  geändert hat oder beim ersten Mal.
- Client auf Englisch: Item-Namen vom Client.

## Missbrauch/Vertrauen

Nur GUILD, nur Mitglieder; ein Name außerhalb des Rosters fällt allein heraus. Ein Feld außerhalb seiner Grenzen
(Item nicht in der Liste der Daten, Menge 1-999, 10 Charaktere, 7 Items je Charakter) verwirft die ganze
Nachricht. Höchstens 300 gehörte Namen, 14 Tage. Ein Mitglied könnte falsche Mengen melden; das schadet höchstens
einer Frage per Flüstern. Der Bestand eines Charakters gilt nur vom Konto, das ihn meldet: ein zweiter Absender
für denselben Charakter ersetzt ihn nur, wenn er der Charakter selbst ist.

## Daten

- `ProfessionData` bekommt `BOP = { [item] = true }` (die gebundenen Reagenzien), außerhalb der Lazy-Tabelle wie
  `ns.PROF_COOLDOWNS`, damit Login und Nachricht die Berufsdaten nicht bauen.
- Neue Nachrichtenart `PB` (GUILD, low, 300 s Abstand): `1`, dann bis zu 10 Einträge
  `<Name>:<item>=<n>[,<item>=<n>]`.
- Neuer gespeicherter Schlüssel `prof.bopHeard = { [name] = { by, at, [item] = n } }`.
- Einstellung `prof.bopShare` (an).
- ARCHITECTURE (Datei, Nachricht, Schlüssel, Einstellung), DECISIONS D-177.

## Offene Fragen

1. Nur gebundene Materialien, nicht alle seltenen? Vorschlag: nur gebundene (handelbare zeigt die Gildenbank).
2. Teilen standardmäßig an? Vorschlag: an, wie die Abklingzeiten.
3. Auch die eigenen Twinks in der Zeile nennen ("Dein Twink Kim 2")? Vorschlag: ja, grau, zuerst.

## Entscheidungen

Noch keine.
