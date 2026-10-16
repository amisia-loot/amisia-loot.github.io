# Spec: Orte auf der Weltkarte (Eingänge, Flugmeister, Zeppeline, Schiffe)

Stand: 2026-10-16 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-105

## Ziel

Auf der Weltkarte sieht man, wo die Eingänge der Dungeons und Raids liegen, wo Flugmeister stehen
und wo Zeppeline und Schiffe ablegen. Ein Klick auf einen Eingang öffnet diesen Dungeon in Amisia
(Seite Dungeons). Gelöst ist es, wenn man für Weg und Planung kein zweites Addon und keine
Fan-Seite mehr braucht.

## Was es tut

- Neue Pins auf Zonen- und Kontinentkarten (derselbe Daten-Provider wie die Ziel-Pins aus
  `Gear/MapPins.lua`, eigene Vorlage, nur eigene Pins):
  - **Eingänge**: Dungeon-Symbol (Raid mit eigenem Symbol). Tooltip: Name, Stufenbereich,
    Gruppengröße, "öffnet am ..." für noch geschlossene; "Klick: in Amisia öffnen.
    Shift-Klick: Ziel setzen."
  - **Flugmeister**: Flugpunkt-Symbol, nur die der eigenen Fraktion (neutrale immer). Tooltip: Ort
    und Name des Flugmeisters.
  - **Zeppeline und Schiffe**: Zeppelin- bzw. Schiffssymbol am Anleger. Tooltip: "Zeppelin nach ..."
    / "Schiff nach ...", Fraktion.
- Klick auf einen Eingang: das Amisia-Fenster geht auf, Reiter Ausrüstung, Seite Dungeons, dieser
  Dungeon gewählt (auch Raids, die die Seite schon kennt). Shift-Klick setzt das Ziel mit Wegpunkt
  und Pfeil (wie "Wegpunkt zum Eingang").
- Einstellungen im Abschnitt "Karte und Wegpunkt": je ein Schalter "Eingänge auf der Karte",
  "Flugmeister auf der Karte", "Zeppeline und Schiffe auf der Karte". Der Pin-Rechtsklick bekommt
  dieselben drei Einträge zum Ausschalten.

## Was es ausdrücklich nicht tut

- Keine Flugrouten-Linien, keine Flugzeiten, kein Flugplaner (das ist die Flugkarte des Spiels).
- Keine Fahrpläne der Zeppeline und Schiffe (Abfahrtszeiten wären geraten).
- Keine Briefkästen, Lehrer, Gasthäuser oder Händler (wächst sonst zu einem Karten-Addon).
- Nichts wird von wago.tools, Wowhead oder Fan-Seiten geladen (D-03); kein Link nach außen.
- Ändert keine Pins des Spiels und hakt sich in keine Methode der Karte ein (wie bisher).

## Abläufe

1. Spieler öffnet die Weltkarte auf dem Brachland: Eingänge (Höhlen des Wehklagens, Kral der
   Klingenhauer), Flugmeister (Das Wegekreuz, Camp Taurajo ...), Schiff in Ratschet nach Beutebucht.
2. Fährt mit der Maus über den Eingang: Tooltip mit Stufe, Größe, Klickhinweis.
3. Klickt: Amisia öffnet die Seite Dungeons mit diesem Dungeon; die Weltkarte bleibt offen und liegt
   vor dem Fenster (F-011 bleibt).
4. Shift-Klick stattdessen: Ziel gesetzt, Chat "Ziel ...", Pfeil zeigt hin.
5. Kontinentkarte Kalimdor: dieselben Orte, kleiner; bei zu vielen Pins (Deckel) haben Eingänge
   Vorrang vor Anlegern vor Flugmeistern.

## Abnahmekriterien

- Wenn du die Weltkarte im Brachland öffnest, dann siehst du die Eingänge der Höhlen des
  Wehklagens, Flugmeister deiner Fraktion und das Schiff in Ratschet; der Tooltip des Schiffs sagt
  "Schiff nach Beutebucht".
- Wenn du auf den Eingang der Höhlen des Wehklagens klickst, dann öffnet sich Amisia auf der Seite
  Dungeons mit "Höhlen des Wehklagens" gewählt.
- Wenn du ihn mit Shift anklickst, dann setzt Amisia das Ziel zum Eingang (Chat "Ziel ...", Pfeil).
- Wenn du in den Einstellungen "Flugmeister auf der Karte" ausschaltest, dann verschwinden die
  Flugmeister-Pins sofort, die Eingänge bleiben.
- Wenn du als Horde in Durotar schaust, dann siehst du keine Allianz-Flugmeister; in Beutebucht nur
  den der eigenen Fraktion.

## Sonderfälle

- Dungeon ohne bekannten Eingang (neue Forever-Dungeons, siehe Frage 4): kein Pin; die Seite
  Dungeons sagt wie heute "Für diesen Dungeon kennt Amisia keinen Eingang."
- Ein Dungeon mit zwei Eingängen (Uldaman, Höhlen des Wehklagens): zwei Pins, beide öffnen
  denselben Dungeon.
- Eingang auf einer Karte, die das Spiel als Unterzone führt (Schwarzfelsspitze, Höhlen der Zeit): der
  Punkt steht auf der Zone und auf der Unterzone, wenn das Spiel sie umrechnen kann.
- Im Kampf: Klick öffnet das Fenster nicht, solange das Fenster es nicht darf; dann nur ein Chathinweis.
- Englischer Client: Namen der Dungeons aus den Locale-Dateien wie auf der Seite Dungeons.
- Raids, die erst später öffnen (Barrow Deeps, Hyjal ab 2026-12-09): Pin mit "öffnet am ...",
  sobald der Ort bekannt ist.

## Missbrauch/Vertrauen

Nichts. Nur lokale Anzeige aus mitgelieferten Daten; nichts wird gesendet oder empfangen.

## Daten

- Keine Nachricht, keine Exportzeile, kein Einfügeblock, nichts auf der Website.
- `Data/MapData.lua` (`tools/build_map.py`) bekommt zwei Tabellen: `F` Flugmeister (aus den
  `fp(...)`-Einträgen von AllTheThings: Koordinate, Fraktion, NPC; 68 Stück, MIT, steht schon in
  LICENSES) und `T` Anleger (handgepflegt in `tools/forever_transports.json`, mit Quelle je Eintrag,
  wie `forever_dungeons.json`).
- Fehlende Eingänge klassischer Dungeons (Schwarzfelsspitze, Düsterbruch, Stratholme, Onyxias Hort
  ...) handgepflegt in `tools/forever_dungeons.json` (Feld `entrance`, mit Quelle), solange
  AllTheThings sie nicht hat.
- Einstellungen: `map.entrances`, `map.flights`, `map.transports` (alle an) im Abschnitt `map`;
  ARCHITECTURE (Einstellungen, Data/MapData) im selben Commit.
- Wenn Frage 4 "lernen" gewählt wird: neuer Schlüssel `AmisiaDB.entrances` (Dungeon -> Punkt),
  dann auch in ARCHITECTURE und eine kurze Regel in DECISIONS.

## Offene Fragen

1. Flugmeister: **nur die der eigenen Fraktion plus neutrale** (Vorschlag) oder alle?
2. Flugmeister: **alle der Fraktion gleich** (Vorschlag), oder sich merken, welche dieser
   Charakter schon kennt (beim Öffnen der Flugkarte) und unbekannte grau zeigen? Das bräuchte einen
   neuen gespeicherten Schlüssel pro Charakter.
3. Klick auf einen Eingang: **Klick öffnet in Amisia, Shift-Klick setzt das Ziel** (Vorschlag), oder
   umgekehrt wie bei den bisherigen Ziel-Pins (Klick = Ziel)?
4. Eingänge, die keine Quelle kennt (Hall of Thanes, Ruins of Lordaeron, Dalaran, Drowned City,
   Krol'dok, Alcaz, Blackmaw Hold, Shaper's Terrace, Barrow Deeps, Hyjal): **Amisia merkt sich den
   Ort, wenn du einen Dungeon betrittst** (Vorschlag; Punkt kurz vor dem Ladebildschirm, bleibt im
   Account, kommt beim nächsten `build.py data` ins Archiv und in die mitgelieferten Daten), oder nur
   abwarten, bis AllTheThings sie hat?
5. Zeppeline und Schiffe: die klassischen Anleger trage ich von Hand ein (Orgrimmar, Unterstadt,
   Grom'gol, Ratschet, Beutebucht, Menethil, Theramore, Auberdine, Rut'theran). Gibt es auf Forever
   neue Routen (z. B. zu Riverglades), die du kennst? Sonst kommen sie nach, wenn du sie meldest.

## Entscheidungen

Nichts.
