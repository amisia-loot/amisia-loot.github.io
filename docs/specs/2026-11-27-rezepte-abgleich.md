# Spec: Rezepte der Gilde schneller und vollständiger

Stand: 2026-11-27 · Status: freigegeben ·
Feature: F-240

## Ziel

Wer Amisia neu hat (oder lange weg war), sieht auf der Seite Berufe und unter "Hergestellt von" die Gilde heute erst
nach bis zu einer Stunde, und Mitglieder, die zu anderen Zeiten spielen, nie. Gelöst ist es, wenn ein neuer Nutzer
wenige Minuten nach dem Login die Berufe fast aller Amisia-Nutzer der Gilde sieht, auch derer, die gerade offline sind.

Ursache (Stand 2.112.0, `Amisia/Gear/Crafters.lua`, F-035): Jeder meldet seinen Fingerabdruck (`PV`) nur 2-4 min nach
dem eigenen Login und dann stündlich; ein Neuer kann nicht selbst fragen. Und jeder schickt nur die eigenen
Charaktere: "das Wort eines anderen Mitglieds über jemand anderen wird nie übernommen" (`sameAccount`).

## Was es tut

Schritt 1 und 2 werden nacheinander gebaut und released; Schritt 1 hilft allein schon.

**Schritt 1: Frage beim Login.**
- Ein Client, dessen Rezeptwissen leer oder älter als ein Tag ist (kein Sender heute gehört), fragt 60-120 s nach dem
  Login einmal die Gilde (`PH`, GUILD, eine Zeile ohne Inhalt außer Protokoll und eigener Zahl gehörter Hersteller).
- Jedes Mitglied mit Amisia, das teilt, antwortet ihm gestreut nach 5-60 s mit seinem Fingerabdruck per Flüstern
  (dasselbe `PV`, nur als WHISPER an den Fragenden), höchstens einmal je Fragendem in der Stunde und höchstens zehn
  Fragenden in der Stunde.
- Der Fragende holt dann wie heute (`PQ`/`PK`). Für die erste Stunde nach einer solchen Frage dürfen es 40 statt 20
  Abfragen sein.

**Schritt 2: Weitergeben.**
- Wer gefragt wird, schickt auf Wunsch (neues Format `R` in `PQ`) neben den eigenen Charakteren auch die Hersteller, die
  er **direkt von ihnen selbst** gehört hat (`self`), höchstens 14 Tage alt, nur Namen aus seinem Gildenroster, nach
  Alter (neueste zuerst), in den heutigen Grenzen (20 Teile je Antwort). Weitergegebenes wird nie weitergegeben.
- Die Antwort auf `PH` (Schritt 1) sagt dazu, wie viele solche Hersteller der Antwortende kennt; der Fragende holt das
  Weitergegebene bei den zwei mit den meisten, einmal je Sitzung.
- Beim Empfänger zählt ein weitergegebener Hersteller nur, wenn er im eigenen Roster steht, kein eigener Charakter ist
  und keinen Eintrag hat, den er selbst geschickt hat (Review 2026-11-27: auch keinen älteren, sonst könnte jeder mit
  "Stand heute" das eigene Wort eines Mitglieds überschreiben), und keinen weitergegebenen vom selben Tag oder neuer. Er behält das Datum, an dem er selbst gesendet hat
  (nicht "heute"), und den Weitergebenden (`via`). Ein Eintrag vom Hersteller selbst ersetzt ihn immer.
- Anzeige: im Kasten "Gildenmitglieder, die es können" und im Mitgliedsmodus der Seite Berufe grau "laut <Name>,
  Stand vor N Tagen", wenn der Eintrag weitergegeben ist.

## Was es ausdrücklich nicht tut

- Kein Weitergeben über mehrere Stationen (nur, was der Hersteller selbst geschickt hat), damit ein falscher Eintrag
  nicht durch die Gilde wandert.
- Kein Senden ohne Frage: niemand schickt Rezepte, die keiner angefordert hat (wie heute).
- Keine neuen Inhalte: Rang, Rezepte und Format bleiben wie heute; Abklingzeiten (`PC`) und Gildenaufträge bleiben
  unberührt.
- Nichts für Spieler außerhalb der Gilde.

## Abläufe

1. Neu installiert, Login: nach 60-120 s geht `PH` an die Gilde.
2. Fünf Mitglieder sind online; jedes flüstert nach 5-60 s sein `PV`, mit "kennt 14 Hersteller".
3. Der Neue holt der Reihe nach die eigenen Rezepte der fünf (`PQ` B/L) und bei den zwei mit den meisten das
   Weitergegebene (`PQ` R). Nach etwa 3-5 Minuten stehen auf der Seite Berufe die fünf und die bis zu 28 gehörten.
4. Loggt einer der Gehörten später ein, kommt sein eigenes `PV` wie heute; sein eigener Eintrag ersetzt den
   weitergegebenen.

## Abnahmekriterien

- Wenn du Amisia neu installierst und dich einloggst, während Gildenmitglieder mit Amisia online sind, dann siehst du
  nach höchstens 5 Minuten deren Berufe auf der Seite Berufe (Gilde) (braucht: Gilde).
- Wenn ein Mitglied gerade offline ist, das ein anderes Online-Mitglied in den letzten 14 Tagen gehört hat, dann siehst
  du nach höchstens 5 Minuten auch dessen Berufe, mit "laut <Name>" (braucht: Gilde).
- Wenn dieses Mitglied später selbst online kommt, dann verschwindet "laut <Name>" und es steht sein eigener Stand da.
- Wenn du dich zweimal am selben Tag einloggst, dann fragt Amisia beim zweiten Mal nicht noch einmal.
- Wenn `/amisia hersteller` eingegeben wird, dann nennt der Chat auch Fragen, Antworten und weitergegebene Hersteller.

## Sonderfälle

- Viele Neue gleichzeitig (Gildenevent): je Antwortendem höchstens zehn Fragende in der Stunde; die heutigen Byte-
  Grenzen je Sitzung gelten weiter, ein erschöpfter Sender sagt es (`PW`).
- Login in einer Instanz oder während eines Raid-Abgleichs: die Frage wartet wie alles im Rezeptaustausch und geht
  danach (aus einer Instanz 5-15 s danach).
- Ältere Clients kennen `PH` und das Format `R` nicht: sie verwerfen `PH`; Format `R` wird nur bei einem Antwortenden
  angefragt, dessen `PV`-Antwort die Zahl weitergebbarer Hersteller trägt.
- Twinks: ein weitergegebener Hersteller, der ein eigener Charakter ist, wird nie genommen.
- Ein Mitglied hat die Gilde verlassen: nicht im Roster, also weder weitergegeben noch genommen.
- Anderer Rezept-Index (andere Daten): wie heute, Listen statt Bits.

## Missbrauch/Vertrauen

- Ein Mitglied könnte einem anderen falsche Rezepte zuschreiben. Gegenmittel: nur Gildenmitglieder (Roster), nur
  Hersteller im Roster, nur Gehörtes erster Hand, sichtbar "laut <Name>", der eigene Eintrag des Herstellers gewinnt
  immer, und weitergegebene Einträge altern mit ihrem echten Datum (nach 45 Tagen weg wie heute).
- Fluten: `PH` einmal je Sitzung und nur mit altem Wissen; Antworten gestreut und gedeckelt; Weitergegebenes nur auf
  Anfrage, in den heutigen Byte-Grenzen je Absender und gesamt (`viaBytes`, `storeBytes`).
- Größe: eine Antwort höchstens 20 Teile wie heute; jede Zeile wird wie heute ganz geprüft, ein schlechtes Feld
  verwirft die ganze Antwort.

## Daten

- Neue Nachricht `PH` (asker -> GUILD, einmal je Sitzung): Protokoll, Zahl gehörter Hersteller. `PV` darf zusätzlich
  als WHISPER an einen Fragenden gehen, mit einem vierten Feld: Zahl weitergebbarer Hersteller.
- `PQ` bekommt das Format `R`; die Antwort `PK` im Format `R` trägt je Hersteller zusätzlich das Datum seines eigenen
  Sendens (Tag) und gilt nur für Hersteller, nicht für den Sender selbst.
- `AmisiaDB.crafters`: Einträge bekommen `relay = true` (weitergegeben) neben `via` und `seen`; `src[sender].r` der Tag
  der letzten Weitergabe-Abfrage. Kein neuer Einstellungsabschnitt: `crafters.share` schaltet alles.
- `CRAFT_PROTO` bleibt 1 (die neuen Teile sind Ergänzungen, alte Clients verwerfen sie).
- In `docs/ARCHITECTURE.md` die Zeilen `PH`, `PV`, `PQ`, `PK`; in `docs/DECISIONS.md` ein neuer Eintrag, der die Regel
  "nie das Wort eines anderen" von F-035 für Gehörtes erster Hand ändert.

## Offene Fragen

1. Wer darf weitergeben: jedes Mitglied oder nur Offiziere? Vorschlag: jedes Mitglied, mit "laut <Name>" sichtbar;
   Offiziere allein wären zu wenige, um Offline-Mitglieder abzudecken.
2. Wie alt darf Weitergegebenes sein? Vorschlag: 14 Tage (wie `selfDays`).
3. Ab wann fragt ein Client beim Login? Vorschlag: wenn er heute noch keinen Sender gehört hat (also höchstens einmal
   am Tag), nicht bei jedem Login.
4. Erst Schritt 1 releasen, dann Schritt 2? Vorschlag: ja, Schritt 1 ist klein und hilft sofort.

## Entscheidungen

- 2026-11-27: "Passt, bauen" -> die vier Vorschläge gelten: jedes Mitglied gibt weiter; 14 Tage; die Frage beim Login
  höchstens einmal am Tag (nur ohne heute gehörten Sender); Schritt 1 vor Schritt 2.
- 2026-11-27: Nutzer "was ist die beste lösung", auf die Antwort "beides, in zwei Schritten" mit "ja" -> diese Spec.
