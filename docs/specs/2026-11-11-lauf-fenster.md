# Spec: Lauf-Fenster als kleine Übersicht (Zeit, Mob-XP, Gold, Bosse, Rare)

Stand: 2026-11-11 · Status: freigegeben (Nutzer 2026-11-11: "können wir unser fenster so aussehen lassen", nach einem Bildschirmfoto) ·
Feature: F-180

## Ziel

Das Fenster "Lauf-Zeiten" (F-166) zeigt im Dungeon auf einen Blick, was der Lauf bisher gebracht hat: Zeit,
Erfahrung aus Kills, geplündertes Gold, welche Bosse schon tot sind und welche Rare es gibt. Gelöst ist es, wenn
das Fenster wie die Vorlage aufgebaut ist (Werte oben, Bossporträts, Rare grau bis getötet) und alles von F-166
erreichbar bleibt.

## Was es tut

- **Aufbau** (300 breit, Amisias Fenster `W.Window`, Schriften und Farben aus `UI/Theme.lua`, `T.RUNTIMER`):
  - Titel: der Name des Dungeons (ein Flügel als "Scharlachrotes Kloster: Friedhof", D-106), rechts das x.
  - Drei Werte nebeneinander, ein graues Wort über einem großen weißen Wert: "Zeit" (läuft; nach dem Ende die
    Endzeit), "Mob-XP" (die Erfahrung dieses Laufs aus Kills; "-" auf der Höchststufe), "Gold" (das in diesem
    Lauf geplünderte Geld mit den Münzen des Clients, ab einem Gold ohne Kupfer).
  - Darunter grau wie bisher: "Bestzeit 24:12", "Noch keine Bestzeit", "Bestzeit vorher ..." oder vor dem ersten
    Kampf "Die Uhr läuft ab dem ersten Kampf.".
  - Eine dünne goldene Linie, darunter die Bosse als runde Porträts (wie auf der Seite Dungeons) in der
    Reihenfolge des Spiels, sieben je Reihe; grau solange er lebt, in Farbe, sobald er in diesem Lauf getötet
    ist. Die Maus nennt Namen, Zwischenzeit und Unterschied zum besten Lauf (grün schneller, rot langsamer),
    beim nächsten Boss das Ziel aus dem besten Lauf, sonst "Noch nicht getötet" oder "Übersprungen".
  - Die goldene Überschrift "Rare" mit den Rare des Dungeons als Porträts, grau bis man sie tot sieht; die Maus
    nennt Namen, "getötet" oder "Noch nicht getötet" und dass ein Rarer nicht in jedem Lauf erscheint.
  - Unten links das Ergebnis ("Neue Bestzeit! -0:40", "Erste gemessene Zeit", "+1:40 zur Bestzeit",
    "Nicht beendet"), rechts der Link "Alle Zeiten".
- Viele Bosse (Schwarzfelstiefen: 21) brechen in Reihen um; das Fenster wächst nach unten.
- `/amisia selbsttest gruppe` nennt die neuen Client-Funktionen ("Lauf-Fenster: XP, Gold, Rare").

## Was es ausdrücklich nicht tut

- Keine Bilder, Texturen oder Pixel des anderen Addons; nur Anordnung und Inhalt.
- Kein Größengriff, kein Symbol im Titel; keine Zeilen je Boss mehr (die Zeiten stehen im Tooltip und im
  Reiter "Zeiten").
- Keine XP oder Gold anderer Spieler, kein Senden, kein Chattext, kein Kampflog.
- Keine erfundenen Rare: ein Dungeon ohne eigene Daten hat keine Reihe "Rare".

## Abläufe

1. Der Spieler betritt einen Dungeon und kämpft: das Fenster öffnet sich (wie F-166), alle Porträts grau,
   Mob-XP und Gold 0.
2. Jeder Kill bewegt die XP-Leiste: "Mob-XP" wächst; geplündertes Geld lässt "Gold" wachsen. Eine abgegebene
   Quest ändert keinen der beiden Werte; Verkaufen und Reparieren beim Händler auch nicht.
3. Ein Boss stirbt: sein Porträt wird farbig, die Maus zeigt seine Zwischenzeit.
4. Er sieht einen Rare tot (als Ziel, unter der Maus oder beim Plündern): dessen Porträt wird farbig.
5. `/reload`: Zeit, Mob-XP, Gold und die gesehenen Rare bleiben.
6. Der letzte Boss stirbt: das Ergebnis steht unten, die Werte bleiben stehen, bis er die Instanz verlässt.

## Abnahmekriterien

- Wenn du in den Todesminen den ersten Kampf beginnst, dann öffnet sich "Lauf-Zeiten" mit "Zeit", "Mob-XP"
  und "Gold" nebeneinander, darunter acht graue Bossporträts und unter "Rare" drei graue Porträts.
- Wenn du Mobs tötest und Geld plünderst, dann wachsen "Mob-XP" und "Gold"; gibst du eine Quest ab oder
  verkaufst beim Händler, ändern sie sich nicht.
- Wenn du einen Boss tötest, dann wird sein Porträt farbig und die Maus zeigt "Zwischenzeit m:ss" (im zweiten
  Lauf dazu grün oder rot den Unterschied zum besten Lauf).
- Wenn du Marisa du'Paige tot im Ziel hast, dann wird ihr Porträt unter "Rare" farbig; nach `/reload` sind
  Werte und Farben noch da.
- Wenn du in Schwarzfelstiefen kämpfst, dann stehen 21 Bossporträts in drei Reihen im Fenster, nichts ragt
  heraus; in der Halle der Thane steht keine Reihe "Rare".

## Sonderfälle

- Bosskampf: XP und Geld sind geheim; die Lesung wird übersprungen, nach dem Kampf zählt der ganze Schritt.
- Stufenaufstieg: der Rest der alten Leiste und der neue Teil zählen; mehrere Stufen auf einmal zählen nichts.
- Höchststufe oder XP aus: "-" statt 0.
- Draußen (Geist, Laufweg): die Uhr läuft weiter, XP und Gold zählen nicht.
- Instanz mehrerer Dungeons (Kloster, Schwarzfelsspitze): bis zum ersten Kill ist der Flügel geraten; ein Rarer
  zählt für jeden Dungeon der Karte.
- Client auf Englisch: englische Wörter ("Time", "Mob XP", "Gold", "Rares"), Namen wie die Seite Dungeons.
- Ohne `GetCoinTextureString` steht "1g 46s" mit den Münzzeichen des Clients.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen; nur die eigenen Werte des Clients. Gespeichertes wird beim Laden Feld für
Feld geprüft (Zahlenbereiche, NPC-IDs, höchstens 40 Rare).

## Daten

- `AmisiaDB.runTimes.live[c]`: neu `x` (Mob-XP), `g` (Kupfer), `rk` (`{ [NPC-ID] = true }`); ein Lauf neu `x`, `g`
  (alte Läufe ohne bleiben gültig). In ARCHITECTURE (Tabelle der gespeicherten Schlüssel) und D-112.
- `Data/DungeonData.lua`: neues Feld `rares` (`{ NPC-ID, englischer Name }`), gebaut von
  `tools/build_dungeons.py` (`rares_of`) aus AllTheThings.
- Keine neue Einstellung, keine Nachricht, kein Befehl. Der Tooltip von "Zeitfenster in Dungeons" nennt die
  neuen Teile.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-11: Nutzer: "können wir unser fenster so aussehen lassen" (mit Bildschirmfoto) -> Aufbau wie oben.
- Annahme (nicht gefragt): Mob-XP aus der XP-Leiste minus Quest-XP, nicht aus dem Chat (geheim im Bosskampf).
- Annahme (nicht gefragt): Gold nur aus Anstiegen außerhalb von Händler, Post, Handel, Bank, Auktionshaus,
  Gildenbank und Questbelohnung, ohne Questgeld; nie weniger.
- Annahme (nicht gefragt): XP und Gold zählen nur in der Instanz der Uhr; eine neue Uhr beginnt bei 0; beide gehen
  am Ende in den gespeicherten Lauf.
- Annahme (nicht gefragt): Rare aus AllTheThings' Instanzdaten; ein Rarer, der ein Boss der Reihenfolge ist,
  bleibt ein Boss; getötet heißt "tot gesehen" (Ziel, Maus, Lootfenster).
- Annahme (nicht gefragt): feste Breite 300, sieben Porträts je Reihe, kein Größengriff, kein Titelsymbol; die
  Zwischenzeiten im Tooltip, neu "Übersprungen".
- Annahme (nicht gefragt): ab einem Gold ohne Kupfer, damit der Wert in die Spalte passt.
