# Spec: Zielfenster mit Kompass (Kartenmarkierung und Amisia-Ziel)

Stand: 2026-11-14 · Status: freigegeben ·
Feature: F-203

## Ziel

Der Weg zu einem Ziel soll auf einen Blick lesbar sein: ein kleines Fenster mit Kompass, Entfernung,
geschätzter Zeit und Koordinaten, für die eigene Kartenmarkierung des Clients (Strg + Klick auf die
Weltkarte) wie für ein Ziel, das Amisia setzt (Seite Karte, Eingänge, `/amisia karte`). Eigene Umsetzung
in Amisias Stil; kein Code, keine Bilder und kein Name eines anderen Addons (D-03, D-04).

## Was es tut

- Ein Fenster "Ziel" (nur Forever, wie die Karte), sobald es ein Ziel gibt:
  - links ein runder Kompass, darin ein Pfeil, der sich mit der Blickrichtung dreht (wie der bisherige
    Pfeil, `GetPlayerFacing`);
  - rechts der Name ("Kartenmarkierung" oder der Name des Amisia-Ziels), groß die Entfernung ("85 m",
    "1,2 km" bzw. "85 yd", "1.2k yd" wie heute in Amisias Sprache), daneben die geschätzte Zeit ("39 s",
    "2 min") aus der Geschwindigkeit, mit der du dich dem Ziel näherst (ohne Bewegung: nichts);
  - darunter grau die Koordinaten und die Zone des Ziels, darunter "Du 43,9, 59,0".
- Oben rechts ein Knopf "Kompakt" (nur Kompass und Entfernung) und ein X (Ziel löschen; die eigene
  Kartenmarkierung des Clients geht mit, wie beim X des Clients).
- Ziehen verschiebt das Fenster (nicht im Kampf); Rechtsklick: "Ziel löschen", "Auf der Weltkarte zeigen",
  "Kompakt"/"Ausführlich", "Fenster ausblenden".
- Angekommen (unter 15 m): "Angekommen" in Grün, wie heute; mit "Ziel beim Ankommen löschen" geht es weg.
- Anderer Kontinent oder in einer Instanz: "Anderer Kontinent" bzw. das Fenster versteckt sich.

## Was es ausdrücklich nicht tut

- Keine eigene Art, Markierungen zu setzen: Strg + Klick auf die Weltkarte setzt die Markierung des Clients
  (Forever kann das selbst); Amisia liest sie nur. Keine Liste mehrerer Wegpunkte, keine Route (das ist F-167).
- Kein Teilen mit der Gruppe (die Routen haben das schon).
- Nicht auf TBC Anniversary und Era (dort gibt es weder die Karte von Amisia noch die Markierung des Clients).
- Keine Laufwege um Berge herum: Entfernung und Zeit sind Luftlinie.

## Abläufe

1. Strg + Klick auf die Weltkarte: der Client setzt seine Markierung; Amisia zeigt das Fenster "Ziel" mit
   "Kartenmarkierung", Kompass, Entfernung, Koordinaten.
2. Klick auf eine Zeile der Seite Karte: Amisia setzt sein Ziel (wie heute); das Fenster zeigt dessen Namen.
3. Beim Laufen dreht sich der Pfeil, Entfernung und Zeit zählen herunter (zehnmal je Sekunde, nur solange das
   Fenster zu sehen ist).
4. X oder Ankommen: Ziel weg, Fenster weg.

## Abnahmekriterien

- Wenn du mit Strg auf die Weltkarte klickst, dann erscheint das Fenster "Ziel" mit "Kartenmarkierung", einem Pfeil im
  Kompass, der beim Drehen der Figur mitdreht, der Entfernung und den Koordinaten mit Zone; beim Hinlaufen steht
  neben der Entfernung eine Zeit in Sekunden, die kleiner wird.
- Wenn du auf "Kompakt" klickst, dann bleiben nur Kompass und Entfernung; nach `/reload` ist es weiter kompakt und an
  derselben Stelle.
- Wenn du auf das X klickst, dann sind Fenster und Markierung weg (auch die gelbe Markierung des Clients auf der Karte).
- Wenn du auf der Seite Karte eine Zeile anklickst, dann zeigt das Fenster ihren Namen statt "Kartenmarkierung".
- Wenn du einen Dungeon betrittst oder in den Kampf kommst, dann gibt es keine Lua-Fehler und keine Meldung
  "Aktion blockiert"; draußen ist das Fenster wieder da.

## Sonderfälle

- Instanz: keine Position, das Fenster versteckt sich (wie der Pfeil heute).
- Kampf und Kampfsperre: das Fenster zeigt weiter (es ist nicht geschützt), aber der Client-Wegpunkt wird nicht
  angefasst (D-62); das X löscht dann nur Amisias Ziel, die Markierung des Clients nach dem Kampf.
- Die Markierung des Clients auf einer Karte ohne Weltposition (z. B. eine Instanzkarte): "Anderer Kontinent".
- Ein anderes Addon setzt die Markierung des Clients: Amisia zeigt sie wie jede andere.
- Geheime Werte (Position, Blickrichtung): zählen als unbekannt, kein Fehler.

## Missbrauch/Vertrauen

Nichts. Nur lokal, nichts wird gesendet.

## Daten

- Einstellungen im Abschnitt "Karte und Wegpunkt": `map.arrow` bekommt die Werte "Immer" (Standard neu: das
  Fenster bei jedem Ziel), "Nur ohne Pfeil des Clients" (das bisherige "Automatisch") und "Aus"; neu `map.compact`
  (Schalter, aus). Der Platz bleibt `settings.map.arrowPos`.
- Kein neuer `AmisiaDB`-Schlüssel außerhalb der Einstellungen, keine Nachricht.
- Das Fenster ersetzt den bisherigen Pfeil `AmisiaArrow` (gleicher Name, damit Platz und Einstellungen bleiben).
- Bilder: ein eigener Kompassring (Lucide, `tools/make_ui_icons.py`) und der vorhandene Pfeil `Media/Icons/arrow`.

## Offene Fragen

1. Soll das Fenster auch die eigene Kartenmarkierung des Clients (Strg + Klick) zeigen, nicht nur Amisias Ziel?
   Vorschlag: ja.
2. Ersetzt es den bisherigen kleinen Pfeil? Vorschlag: ja, und es zeigt sich standardmäßig bei jedem Ziel (bisher nur,
   wenn der Client keinen Pfeil zeigen konnte).
3. Entfernung in Metern oder Yards? Vorschlag: wie heute in Amisia ("m" auf Deutsch, "yd" auf Englisch).

## Entscheidungen

- 2026-11-14: Frage 1: "Ja, beides" -> die Kartenmarkierung des Clients und Amisias Ziele.
- 2026-11-14: Frage 2: "Ersetzen, immer zeigen" -> das Fenster ersetzt `AmisiaArrow`, `map.arrow` Standard "Immer".
- 2026-11-14: Frage 3 nicht gestellt: Vorschlag übernommen (m auf Deutsch, yd auf Englisch, wie bisher).
- 2026-11-14: Spec: "Passt, bauen".
