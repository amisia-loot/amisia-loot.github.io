# Spec: Gildenfenster-Knopf, Twinks und Itemlevel bei Mitglieder

Stand: 2026-11-15 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-210

## Ziel

Aus dem Gildenfenster des Spiels kommt man mit einem Klick zu Amisia, und die Seite "Mitglieder" zeigt, welche
Charaktere zu einem Spieler gehören und welches Itemlevel sie haben. Gelöst ist es, wenn unter Mitglieder die Twinks
eingerückt unter ihrem Main stehen, jeder mit Itemlevel, auch wenn er offline ist.

## Was es tut

- **Knopf im Gildenfenster:** ein roter Knopf "Amisia" unten rechts am Gildenfenster des Spiels (Forever:
  `CommunitiesFrame`; TBC/Era: das Gildenfenster der Freundesliste). Ein Klick öffnet Amisia auf der Seite
  "Mitglieder"; ohne Raid-Modul das Hauptfenster.
- **Eigene Charaktere:** Amisia merkt sich je Account die eigenen Charaktere mit Klasse, Stufe, Gilde und Itemlevel
  (beim Einloggen und nach einem Ausrüstungswechsel, höchstens alle 10 s).
- **Meldung an die Gilde:** einmal pro Sitzung, zusammen mit dem Hallo (20 bis 60 s nach dem Login), schickt Amisia
  der Gilde die eigenen Charaktere dieser Gilde: den Main und je Charakter das Itemlevel (neue Nachricht `AC`).
- **Main des Accounts:** der Charakter mit der höchsten Stufe, bei Gleichstand das höhere Itemlevel, dann der Name.
- **Gildennotizen:** steht in der öffentlichen oder der Offiziersnotiz eines Mitglieds genau der Name eines anderen
  Mitglieds (voll oder ein eindeutiger Vorname) oder "Twink von X", "X Twink", "Twink: X", "Main: X", "alt of X",
  "X's alt", gilt es als Twink von X.
- **Mitglieder:** Twinks stehen eingerückt unter ihrem Main (Klassensymbol und Name um eine Stufe nach rechts). Jede
  Zeile zeigt rechts neben dem Namen das Itemlevel ("iLvl 45" im Tooltip, in der Zeile die Zahl); ohne bekannten Wert
  nichts. Der Tooltip nennt Main bzw. Twinks wie bisher, dazu woher Amisia das weiß und wie alt das Itemlevel ist.
- **Itemlevel-Quellen:** die Meldung `AC` (je Charakter, auch offline gemerkt), das Betrachten mit der Maus
  (Spieler-Tooltip) und für den eigenen Account die eigenen Werte.

## Was es ausdrücklich nicht tut

- Es ändert nicht, wer für Punkte, Loot-Prio, Aufstellung und Soft-Reserves als Main gilt: `ns.MainOf` bleibt bei
  der Twink-Liste der Website (Offiziere, vertraut). Die neuen Quellen gelten nur für die Anzeige unter Mitglieder.
- Keine Ausrüstung, Talente oder Berufe der Twinks über `AC` (nur Name, Main, Itemlevel).
- Kein eigener Schalter "Mein Main" (vorerst die Regel oben; später möglich).
- Kein Sortieren nach Itemlevel (nicht gewünscht; später möglich).

## Abläufe

1. Spieler A loggt Charakter A1 ein. Amisia merkt sich A1 (Klasse, Stufe, Itemlevel, Gilde). 20 bis 60 s später
   gehen Hallo und `AC` an die Gilde: Main A2 (Stufe 60), A1 mit iLvl 31, A2 mit iLvl 58.
2. Spieler B (Amisia) bekommt `AC`: nur von einem Mitglied der eigenen Gilde, nur Namen, die im Gildenroster stehen.
   B merkt sich je Charakter Main, Itemlevel und Zeit.
3. B öffnet Mitglieder: A2 steht als Zeile, darunter eingerückt A1, beide mit Itemlevel. Ein Mitglied ohne Amisia,
   dessen Notiz "Twink von A2" sagt, steht ebenfalls unter A2.
4. B öffnet das Gildenfenster des Spiels und klickt "Amisia": Amisia öffnet Mitglieder.

## Abnahmekriterien

- Wenn du das Gildenfenster des Spiels öffnest, dann steht unten rechts ein roter Knopf "Amisia"; ein Klick öffnet
  Amisia auf der Seite Mitglieder.
- Wenn ein Gildenmitglied mit dieser Version mit einem Twink online war, dann steht der Twink unter Mitglieder
  eingerückt unter seinem Main, beide mit Itemlevel, auch nachdem er offline ist (braucht: Gilde).
- Wenn in der Notiz eines Mitglieds "Twink von <Name>" oder nur der Name eines anderen Mitglieds steht, dann steht es
  unter diesem eingerückt.
- Wenn du mit einem deiner Charaktere einloggst, dann stehen deine eigenen Charaktere der Gilde unter deinem Main
  mit ihrem Itemlevel.
- Wenn du einen Spieler mit der Maus betrachtest hast, dann steht sein Itemlevel auch unter Mitglieder.

## Sonderfälle

- Kampfsperre und Bosskampf: `AC` geht wie das Hallo nie in der Sperre; ein geheimer Wert zählt nicht.
- Ein Main, der die Gilde verlassen hat: seine Twinks stehen als eigene Zeilen (mit "Twink von X" im Tooltip).
- Ein Filter (Klasse, Beruf, nur online, Suche): jeder Charakter, der passt, steht da; ein Twink unter seinem Main nur,
  wenn der Main auch dasteht, sonst als eigene Zeile.
- Sortieren nach einer Spalte: die Gruppen nach ihrem Main, die Twinks darunter nach Name.
- Widerspruch der Quellen: Website-Liste vor der eigenen Meldung des Charakters vor der Meldung eines anderen
  Charakters vor der Notiz. Ein Charakter, der selbst einen anderen Main meldet, zählt mit seinem eigenen Wort.
- Nachnamen (Forever): Namen wie "Vulo Vultrox"; ein Vorname in einer Notiz nur, wenn er eindeutig ist.
- Zu viele Charaktere für eine Nachricht (250 Bytes): der Main zuerst, dann nach Stufe; was nicht passt, fällt weg.
- Twinks in einer anderen Gilde: nicht gemeldet.
- `/reload`: keine zweite Meldung in 30 Minuten (wie das Hallo).

## Missbrauch/Vertrauen

- Es zählt nur der Absender, den der Server setzt, und nur Mitglieder der eigenen Gilde (`ns.TrustWait` "member").
- Ein Mitglied könnte fremde Charaktere als seine Twinks melden. Das ändert nur die Anzeige unter Mitglieder, nichts
  an Punkten oder Vergaben (`ns.MainOf` unverändert). Sobald der fremde Charakter selbst meldet, zählt sein Wort; die
  Website-Liste der Offiziere steht über beidem.
- Nur Namen aus dem Gildenroster, höchstens 10 je Meldung, Itemlevel 1 bis 999; ein Feld außerhalb verwirft die
  ganze Nachricht. Eine Meldung je Absender in 300 s (Drossel), gemerkt höchstens 1000 Charaktere, 60 Tage.
- Gildennotizen setzt nur, wer das Recht dazu hat; sie sind die schwächste Quelle.

## Daten

- Neue Nachricht `AC`: Mitglied -> GUILD einmal pro Sitzung mit dem Hallo (nicht in 30 Minuten nach einem `/reload`);
  Abstand 300 s je Absender; Felder: Main, dann bis zu 10 Einträge `Name:Itemlevel` (Itemlevel `-` ohne Wert).
- Neuer Schlüssel `AmisiaDB.account`: `{v = 1, chars = {[Name] = {class, level, il, guild, at}}}` (die eigenen
  Charaktere des Accounts, höchstens 50).
- Neuer Schlüssel `AmisiaDB.guildChars`: `{v = 1, list = {[Name] = {main, il, at, by, self}}}` (gemeldete
  Charaktere der Gilde: `by` der Absender, `self` = der Charakter hat selbst gemeldet; 1000, 60 Tage).
- Das Betrachten (`UI/UnitInfo.lua`) legt sein Itemlevel zusätzlich in `guildChars` ab, wenn der Spieler in der Gilde
  ist (Main unverändert).
- Kein neuer Einstellungsabschnitt. Neue Datei für den Knopf im Gildenfenster (TOC).
- DECISIONS: neue Entscheidung zu Quellen, Rangfolge und Vertrauen.

## Offene Fragen

Nichts. Die drei Fragen sind entschieden (unten).

## Entscheidungen

- 2026-11-15: Twinks: "Amisia + Notizen (Recommended)" -> eigene Meldung `AC`, Gildennotizen und Website-Liste.
- 2026-11-15: Itemlevel: "Amisia meldet es (Recommended)" -> mit der Meldung beim Einloggen, je Charakter gemerkt,
  dazu Werte vom Betrachten.
- 2026-11-15: Anzeige: "Unter dem Main (Recommended)" -> Twinks eingerückt unter dem Main, Itemlevel in jeder Zeile.
