# Spec: Einladen: Gilde nach Rang, eigene Stichwörter, Einladungen annehmen

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10 auf die Liste der neun Punkte: "1,2,3,5,8,9") ·
Feature: F-163

Ergänzt die Spec [2026-10-10-raid-aufstellung.md](2026-10-10-raid-aufstellung.md), Teil C (D-41, D-47), und
[2026-11-10-aufstellung-vorlagen.md](2026-11-10-aufstellung-vorlagen.md) (dort "Offene Fragen" 2).

## Ziel

Der Raidleiter bekommt seine Gilde ohne Anmeldeliste in den Raid (alle bis zu einem Rang mit einem Klick),
Raider kommen mit ihrem eigenen Stichwort per Flüstern hinein, und wer will, landet ohne Klick in der Gruppe
eines Gildenmitglieds oder Freundes. Gelöst ist es, wenn ein Abend ohne Liste mit "Gilde einladen" startet.

## Was es tut

1. **Gilde einladen** (Seite Aufstellung, Ansicht "Einladen", nur Offiziere): ein Auswahlfeld "bis <Rang>"
   mit den Rängen der Gilde (gemerkt als Einstellung `lineup.inviteRank`) und der Link "Gilde einladen". Ein
   Klick fragt "N Gildenmitglieder bis Rang X einladen?" (`W.Confirm`) und lädt dann alle Gildenmitglieder
   dieses Rangs oder eines höheren ein, die online und nicht in der Gruppe sind, durch denselben Ablauf wie
   "Alle einladen". Die Ansicht "Einladen" geht auch in einer Nacht ohne Liste auf.
2. **Liste:** Wer über die Gilde (oder auf Flüstern) eingeladen und nicht eingeteilt ist, steht in der Ansicht
   mit Status (eingeladen, abgelehnt, keine Antwort ...), Versuchen und "über Gilde einladen" bzw. "auf
   Flüstern"; ist er im Raid, steht er bei den Raidern ohne Liste mit "im Raid".
3. **Eigene Stichwörter:** Einstellung "Stichwörter zum Einladen" (`lineup.invWords`, Standard "inv, invite")
   im Abschnitt Raid-Aufstellung. Der Schalter "Einladen auf Flüstern" bleibt.
4. **Einladungen annehmen:** Abschnitt "Gruppeneinladungen" (Reiter Raid, für alle), Schalter "Einladungen von
   Gilde und Freunden annehmen" (aus). An: Einladung eines Gildenmitglieds oder Freundes wird sofort
   angenommen, das Fenster des Spiels geht zu, Chat: "Einladung von <Name> angenommen (Gilde)." / "(Freund)".

## Was es ausdrücklich nicht tut

- Kein eigener Schalter "Gruppe in einen Raid umwandeln, wenn voll": der Ablauf wandelt schon um.
- Keine Einladung von Spielern außerhalb der Gilde nach Rang; keine Battle.net-Freunde.
- Keine Änderung daran, wer die Seite Aufstellung sieht (D-41, D-92).
- Nichts wird gespeichert außer den Einstellungen; keine Addon-Nachricht.

## Abläufe

- **Gilde einladen:** Offizier > Aufstellung > "Einladen" > "bis Veteran" > "Gilde einladen" > Nachfrage
  "Einladen". Allein oder in einer Gruppe: erst bis fünf in der Gruppe, nach dem ersten Beitritt ein Raid, dann
  der Rest; eine Einladung alle 0,5 Sekunden. Ein zweiter Klick lädt die ein, die abgelehnt oder nicht
  geantwortet haben (höchstens drei Einladungen pro Name und Abend).
- **Stichwort:** Einstellung auf "raid, komm"; ein Gildenmitglied flüstert "komm"; es wird eingeladen wie bisher
  mit "inv".
- **Annehmen:** Raider schaltet die Einstellung an; ein Gildenmitglied lädt ihn ein; er ist in der Gruppe.

## Abnahmekriterien

- Wenn du als Offizier unter Aufstellung "Einladen" klickst (auch ohne Liste), dann siehst du "bis <Rang>"
  und "Gilde einladen" (braucht: Gilde).
- Wenn du "bis Veteran" wählst und "Gilde einladen" klickst, dann fragt Amisia mit der Zahl der Spieler und
  lädt nach "Einladen" einen nach dem anderen ein; die Liste zeigt "eingeladen" und "über Gilde einladen"
  (braucht: Gilde).
- Wenn der Erste beitritt und mehr als fünf eingeladen werden, dann wird die Gruppe ein Raid und der Rest
  eingeladen (braucht: Gruppe).
- Wenn du "Stichwörter zum Einladen" auf "raid, komm" setzt und dir ein Gildenmitglied "komm" flüstert, dann wird
  es eingeladen; "inv" lädt nicht mehr ein (braucht: Gilde).
- Wenn du "Einladungen von Gilde und Freunden annehmen" anschaltest und ein Gildenmitglied dich einlädt, dann
  bist du ohne Klick in der Gruppe und der Chat sagt "Einladung von <Name> angenommen (Gilde)." (braucht: Gilde).

## Sonderfälle

- Kampf, Bosssperre, Schlachtfeld, ohne Leitung, andere Nacht: "Gilde einladen" ist aus, mit dem Grund wie
  "Alle einladen".
- Gildenliste noch nicht gelesen: "Die Gildenliste ist noch nicht gelesen. Gleich nochmal versuchen."; keine
  Gilde: "Du bist in keiner Gilde.".
- Raid voll (40): der Ablauf hält an ("der Raid ist voll").
- Ein eingeteilter Spieler, der über die Gilde eingeladen wird, bleibt in seiner Zeile mit seiner Gruppe.
- Ungültige Stichwörter (mehr als 5, zu kurz, zu lang, Zeichen außer Buchstaben und Ziffern, leer): die
  Einstellung nimmt sie nicht; ein kaputter gespeicherter Wert gilt als Standard.
- Annehmen: Absender eines anderen Realms (gleichnamig), nur Vorname, geheimer Name (Bosskampf), schon in einer
  Gruppe: nichts. Feuert das Spiel die Einladung zweimal, wird einmal angenommen.
- `/reload`: die Status sind weg (nur im Speicher), wie bei "Alle einladen".
- Englischer Client: alle Texte übersetzt.

## Missbrauch/Vertrauen

- Gilde einladen: nur Offiziere (D-41); nur Namen der Gildenliste; dieselben Drosseln wie "Alle einladen"
  (0,5 Sekunden, drei pro Name und Abend), vorher eine Nachfrage mit der Zahl.
- Stichwörter: wie bisher nur Gildenmitglieder (genauer Name), Gäste nur mit "Gäste einladen", 30 Sekunden
  pro Absender, zehn pro Minute.
- Annehmen: es zählt nur der Name, den das Spiel als Absender nennt; genau ein Name der Gildenliste (kein
  Vorname allein, kein anderer Realm) oder der Freundesliste. Ein Fremder kann einen Spieler damit nicht in
  seine Gruppe holen.

## Daten

- Einstellungen: `lineup.invWords` (Text, "inv, invite"), `lineup.inviteRank` (1-10, 10), neuer Abschnitt
  `invites` mit `invites.accept` (aus).
- Kein neuer `AmisiaDB`-Schlüssel, keine Nachricht, kein Export.
- Client: `PARTY_INVITE_REQUEST`, `AcceptGroup`, `StaticPopup_Hide`; `/amisia selbsttest gruppe` meldet die
  beiden Funktionen.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-10: Nutzer auf die Liste der neun Punkte: "1,2,3,5,8,9" -> Punkt 2 wie oben. D-93.
- Annahme (nicht gefragt): "bis Rang" heißt dieser Rang und alle höheren; Standard alle Ränge, die Nachfrage
  nennt die Zahl.
- Annahme (nicht gefragt): Stichwörter nur aus Buchstaben und Ziffern (ASCII), höchstens 5.
- Annahme (nicht gefragt): Freunde = die Freundesliste des Spiels, keine Battle.net-Freunde.
- Annahme (nicht gefragt): das Annehmen ist eine Einstellung für jeden (eigener Abschnitt im Reiter Raid),
  nicht nur für Offiziere.
