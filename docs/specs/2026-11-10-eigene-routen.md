# Spec: Eigene Routen auf der Karte (Stopps, Zeichnen, Teilen)

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10 auf die Liste der neun Punkte: "1,2,3,5,8,9") ·
Feature: F-167

## Ziel

Wer einen Weg plant (zum Questgeber, durch eine Höhle, durch einen Dungeon), zeichnet ihn auf der Weltkarte,
nummeriert die Stopps, folgt ihnen mit dem Ziel und schickt ihn seiner Gruppe. Bisher gab es nur den Laufplaner
des Dungeon-Journals (F-139) und das eine Ziel mit Pfeil, aber nichts zum Teilen. Gelöst ist es, wenn eine
Gruppe dieselbe Route sieht, nachdem einer sie geteilt und der andere sie angenommen hat.

## Was es tut

- **Routen-Leiste** (`AmisiaRouteBar`, `Gear/RouteMap.lua`) unten links auf der Weltkarte: "Route" (der
  Routen-Modus an/aus); an: "Stopp" (ein Klick auf die Karte setzt einen nummerierten Stopp), "Zeichnen" (mit
  gedrückter linker Maustaste eine Linie zeichnen), "Rückgängig" (der letzte Stopp oder die letzte Linie),
  "Leeren", ein Namensfeld, "Speichern", "Laden" (Angebote, die Routen dieser Karte, dann die anderen),
  "Teilen", "Mehr" (Route folgen, Weiter zum nächsten Stopp, Folgen beenden, Ziel als Punkt teilen,
  Gespeicherte Route löschen) und die Zählung "3 Stopps, 1 Linie". Aus: nur "Route" (und "Laden", solange
  Angebote warten).
- **Stopps und Linien:** Die Stopps sind nummeriert und in ihrer Reihenfolge mit einer dünnen goldenen Linie
  verbunden, gezeichnete Linien blau. Ein Klick (Rechtsklick mit Werkzeug) auf einen Stopp: "Beschriften" (das
  Namensfeld nimmt die Beschriftung, Enter), "Früher", "Später", "Löschen", "Punkt teilen". Grenzen: 30 Stopps,
  20 Linien zu je 60 Punkten; beim Zeichnen zählt ein Punkt erst 0,6 % der Karte nach dem letzten.
- **Eine Route gehört zu einer Karte** (die gezeigte beim Anlegen; Dungeonkarten wie Weltkarten) und steht nur
  auf ihr.
- **Gespeichert** für den Account (`AmisiaDB.routes`, höchstens 40): "Speichern" unter dem Namen im Feld
  (derselbe Name auf der Karte wird ersetzt, ein neuer Name benennt die geladene Route um), "Laden" im Menü,
  "Gespeicherte Route löschen" mit Nachfrage.
- **Folgen:** "Route folgen" setzt das Ziel (Wegpunkt oder Pfeil, wie jedes Ziel) auf Stopp 1 ("Stopp 1/7:
  Label"); näher als 15 Meter geht es zum nächsten; der letzte endet mit "Route "Name" zu Ende: alle 7 Stopps
  erreicht.". Wo das Spiel keine Position nennt (in Instanzen): "Weiter zum nächsten Stopp" oder
  `/amisia route weiter`. Nur Stopps, keine Linien.
- **Teilen:** "Teilen" schickt die gezeigte Route an die Gruppe (Raid oder Gruppe). Bei den anderen mit Amisia:
  eine Zeile "Anna teilt die Route "Name" (7 Stopps, Dun Morogh). /amisia route annehmen" und im Menü "Laden"
  "Angebot von Anna: Name - ansehen / verwerfen". Annehmen zeigt sie auf ihrer Karte (die Karte öffnet sich
  dort) und das Namensfeld trägt den Namen: "Speichern" behält sie.
- **Punkt teilen** (ein Stopp oder das Ziel): eine Zeile im Gruppenchat "Amisia-Punkt: Dun Morogh 45.2, 63.1
  (Label)", dazu der Kartenlink des Spiels, wenn dessen Wegpunkt genau dort steht; Amisia in der Gruppe sagt
  "Anna teilt einen Punkt: ... Als Ziel: /amisia route punkt".
- **Befehle:** `/amisia route` (Modus an/aus, öffnet die Weltkarte), `route folgen`, `route weiter`,
  `route stop`, `route annehmen` (das neueste Angebot), `route verwerfen` (alle), `route punkt` (englisch
  `follow`, `next`, `stop`, `accept`, `decline`, `point`).
- **Einstellungen** im Abschnitt "Karte und Wegpunkt": "Routen-Leiste auf der Weltkarte zeigen" (an),
  "Geteilte Routen annehmen dürfen" (an).

## Was es ausdrücklich nicht tut

- Kein Teilen an die Gilde oder per Flüstern, keine öffentlichen Links, kein Import fremder Routenformate.
- Keine Route zeigt sich von selbst, keine wird von selbst gespeichert.
- Keine Änderung an den Pins des Spiels, am Questlog, an der Karte selbst (D-64); nichts im geschützten Teil.
- Linienstärke und Farbe sind nicht einstellbar. Keine Route auf der Kontinentkarte.
- Der Laufplaner des Dungeon-Journals (F-139) bleibt, wie er ist.

## Abläufe

- **Allein:** Karte öffnen (oder `/amisia route`), "Route" an, "Stopp", dreimal auf die Karte klicken, "Zeichnen"
  und eine Linie ziehen, Namen eintippen, "Speichern". "Mehr" > "Route folgen": das Ziel springt von Stopp zu
  Stopp.
- **Gruppe:** Vulo zeigt seine Route, "Teilen". Anna liest die Zeile im Chat, tippt `/amisia route annehmen`
  (oder "Laden" > "ansehen"): ihre Karte öffnet sich auf der Route, "Speichern" behält sie. Kai ohne Amisia sieht
  nur, was im Chat steht (beim Punkt die Zeile mit Koordinaten).

## Abnahmekriterien

- Wenn du die Weltkarte öffnest, dann steht unten links "Route"; ein Klick darauf zeigt die Leiste, "Stopp" und
  drei Klicks auf die Karte setzen die Stopps 1, 2, 3, mit einer Linie verbunden; ist "Route" aus, verschiebt
  und zoomt die Karte wie immer.
- Wenn du "Zeichnen" wählst und mit gedrückter Maustaste ziehst, dann steht eine blaue Linie; "Rückgängig" nimmt
  sie, dann den letzten Stopp.
- Wenn du einen Namen eintippst und "Speichern" klickst und nach `/reload` "Laden" öffnest, dann steht die Route
  unter der Zone der Karte und lädt mit einem Klick.
- Wenn du "Mehr" > "Route folgen" klickst, dann ist Stopp 1 das Ziel ("Stopp 1/3"); läufst du hin, wird Stopp 2
  das Ziel; nach dem letzten steht "Route ... zu Ende".
- Wenn du in einer Gruppe "Teilen" klickst, dann steht beim anderen mit Amisia "<Name> teilt die Route ..." und
  nach `/amisia route annehmen` steht die Route auf seiner Karte; "Punkt teilen" schreibt "Amisia-Punkt: ..."
  in den Gruppenchat (braucht: Gruppe).

## Sonderfälle

- **Kampf, Bosskampf:** das Werkzeug geht im Kampf aus, die Klickebene wird im Kampf weder gebaut noch gezeigt;
  Teilen geht nicht im Kampf, in der Sperre, im Schlachtfeld; Empfangenes in der eigenen Sperre wird verworfen.
  Werte des Spiels laufen durch `ns.Plain`.
- **Instanzen:** die Weltkarte zeigt die Dungeonkarte, Routen gehen dort wie draußen; Folgen ohne Position von
  Hand; Amisia öffnet die Karte in Instanzen nicht selbst (D-62).
- **/reload:** gespeicherte Routen bleiben; die gezeigte, ungespeicherte Route, das Folgen und Angebote nicht.
- **Ohne `CreateLine`:** kleine Punkte entlang der Linien (höchstens 1500).
- **Englischer Client:** Texte und Befehle englisch; der Chattext des Punkts in der Sprache des Senders.
- **Twinks:** die Routen gehören dem Account.

## Missbrauch/Vertrauen

- **Wer darf senden:** nur an die eigene Gruppe (`RAID` im eigenen Raid, `PARTY` nur in einer eigenen Gruppe),
  nie Gilde, Flüstern oder `INSTANCE_CHAT`; eine Route je 30 Sekunden, ein Punkt je 10 Sekunden.
- **Wer wird angenommen:** nur der Absender, den der Server setzt (`ns.TrustName`), und nur wenn er in der
  eigenen Gruppe steht (`ns.InMyGroup`); nur auf `RAID`/`PARTY`; nur mit "Geteilte Routen annehmen dürfen".
  Ein Fremder, ein Gildenkanal oder ein Flüstern ändert nichts.
- **Fluten:** die Sendegrenzen von `Core/Comm.lua` je Absender (40 Nachrichten in 10 s, 20480 Bytes je Minute),
  `RO` höchstens alle 30 s je Absender, höchstens 6 offene Köpfe (150 s), 3 wartende Angebote und 3 Punkte
  (danach wird Neues verworfen; der eigene ältere eines Absenders ersetzt), 10 Minuten, nichts gespeichert.
- **Zu groß oder kaputt:** Kopf mit Teilen 1-24, Bytes 1-6000 (die Stücke müssen genau passen), Karte, die das
  Spiel kennt, Zahlen 0-30 und 0-20; jedes Stück nur einmal, nie mehr Bytes als angekündigt; der Text Zeichen
  für Zeichen geprüft (nur das Alphabet, Zahl der Stopps, Beschriftungen und Linien wie angekündigt, 2-60
  Punkte, Koordinaten 0-1); Namen und Beschriftungen ohne Codes, `|` und Steuerzeichen, gekürzt.
- **Nichts von selbst:** ein Angebot ist eine Zeile im Chat und ein Eintrag im Menü; gezeigt wird erst nach
  "annehmen", gespeichert erst nach "Speichern". Ein Punkt wird nur mit `/amisia route punkt` oder dem Menü das
  Ziel. Der Kartenlink geht nur hinaus, wenn der eigene Wegpunkt des Spiels genau dort steht; Amisia setzt ihn
  dafür nicht.

## Daten

- Neuer Schlüssel `AmisiaDB.routes = { v = 1, list = { { n, m, at, s = { { x, y, l } }, k = { { x1, y1, ... } } } } }`,
  geprüft in `R.Loaded` (siehe ARCHITECTURE.md).
- Einstellungen `map.routeBar`, `map.routeShare` im Abschnitt `map`.
- Nachrichten `RO` (Abstand 30 s), `RD` (keiner), `RX` (10 s) auf `RAID`/`PARTY`; neuer Kanal `PARTY` in
  `Core/Comm.lua` (D-97). Kein Blob, kein Export.
- Ereignis `ROUTES` (intern). Befehl `/amisia route`.

## Offene Fragen

1. Ist `PARTY` als Kanal recht (ändert D-19)? Vorschlag: ja, nur für diese drei Nachrichten und nur in einer
   eigenen Gruppe; ohne ihn ginge Teilen in einer Fünfergruppe nicht.
2. Sollen gespeicherte Routen auch auf der Seite "Karte" stehen? Vorschlag: erst nach dem Test im Spiel; heute
   im Menü "Laden" der Leiste.

## Entscheidungen

- 2026-11-10: Nutzer auf die Liste der neun Punkte: "1,2,3,5,8,9" -> Punkt 8 "Routen: auf der Karte zeichnen,
  nummerierte Stopps, Route oder Kartenpunkt mit der Gruppe teilen". D-97.
- 2026-11-10: Frage 1 (Kanal `PARTY`): dem Nutzer am 2026-11-10 als Entscheidung vorgelegt, mit der Wahl "Ohne
  Gruppen-Senden" (dann nur im Raid); er wählte beim Release "Ja, veröffentlichen" -> `PARTY` bleibt.
- Annahme (nicht gefragt): Teilen geht in einer Gruppe über `PARTY` (neu in `Core/Comm.lua`, nur in einer eigenen
  Gruppe) und im Raid über `RAID`; nicht über einen Blob, weil Blobs nur von Gildenmitgliedern angenommen werden
  und Gruppen auch Fremde haben.
- Annahme (nicht gefragt): die Leiste ist ein eigener Rahmen an UIParent, unten links in der Karte, ihr Platz
  jedes Bild aus der Karte gelesen (kein Anker an einem Rahmen der Karte); eingeklappt nur "Route".
- Annahme (nicht gefragt): die Klickebene ist ein eigener Rahmen auf der Leinwand, nur sichtbar, solange "Stopp"
  oder "Zeichnen" an ist; dann verschiebt Ziehen die Karte nicht (Mausrad zoomt weiter).
- Annahme (nicht gefragt): die Liste der Routen steht im Menü "Laden" (die Seite Karte hat in der Kopfzeile bei
  602 Breite keinen Platz); Umbenennen über das Namensfeld und "Speichern"; Löschen mit Nachfrage.
- Annahme (nicht gefragt): Grenzen 30 Stopps, 20 Linien zu 60 Punkten, 40 Routen, Namen 30 und Beschriftungen 24
  Bytes; Ankunft bei 15 Metern wie das Ziel der Karte.
- Annahme (nicht gefragt): `/amisia route annehmen` nimmt das neueste Angebot, `verwerfen` verwirft alle.
