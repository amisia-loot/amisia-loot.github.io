# Spec: Raid-Aufstellung: Vorlagen, aus dem Raid, Spielerliste, Leeren, Export

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10: "Ja, alle fünf") · Feature: F-161

Ergänzt die Spec [2026-10-10-raid-aufstellung.md](2026-10-10-raid-aufstellung.md) (D-41, D-42, D-47).

## Ziel

Ein Offizier baut die Gruppen auch ohne Anmeldeliste: aus dem laufenden Raid, aus einer gespeicherten
Vorlage oder Name für Name aus Raid und Gilde. Gelöst ist es, wenn die Stammaufstellung einmal gespeichert
und an jedem Raidabend mit zwei Klicks wieder da ist.

## Was es tut

Alles auf der Seite "Aufstellung" (nur Offiziere, wie bisher):

1. **Vorlagen.** Der Knopf "Vorlagen" in der Kopfzeile öffnet die Ansicht "Vorlagen": die gespeicherten
   Vorlagen mit Name, Größe, Zahl der Spieler und Datum. "Laden" setzt die gewählte Vorlage in die
   gezeigte Nacht, "Löschen" entfernt sie (mit Nachfrage). Ein Namensfeld und "Speichern" legen die
   gezeigte Nacht als Vorlage ab; derselbe Name überschreibt. Höchstens 12 Vorlagen.
2. **Aus dem Raid.** Im Planer unter "Mehr": "Aus dem Raid übernehmen" setzt jeden Raider in die Gruppe, in
   der er im Raid steht. Wer in der Liste fehlt, kommt dazu.
3. **Spielerliste.** Im Planer schaltet "Spieler" den unteren Teil um: statt "Nicht eingeteilt" und
   "Ersatz" steht dort ein Raster mit den Namen aus "Raid" oder "Gilde", mit "nur online", Klassenfilter
   und Suche. Ein Klick wählt einen Namen, der nächste Klick auf einen Platz setzt ihn (Ziehen geht
   auch). Der Planer geht jetzt auch in einer Nacht ohne Liste auf.
4. **Leeren.** "Mehr" > "Gruppen leeren" nimmt alle aus Gruppen und Ersatz (mit Nachfrage). Die Liste
   bleibt.
5. **Export.** "Mehr" > "Als Text exportieren" zeigt den Block `#AMISIA-RAID` der Nacht zum Kopieren, jetzt
   mit der Gruppe jedes Spielers. "Einfügen" bei einem anderen Offizier liest ihn mit den Gruppen.

## Was es ausdrücklich nicht tut

- Kein Senden an andere Offiziere per Addon-Nachricht: der Export ist Text zum Kopieren.
- Keine Vorlagen pro Boss und kein automatisches Umsortieren im Kampf.
- "Aus dem Raid" und die Spielerliste laden niemanden ein und verschieben niemanden im Spiel. Das tun
  weiter nur "Alle einladen" und "Gruppen sortieren".
- Die übrigen Reiter des Vorbilds (Rollen: Haupttanks, Assistenten, Plündermeister; Gilde nach Rang
  einladen; Einladungen annehmen) gehören nicht dazu: offen, siehe "Offene Fragen".

## Abläufe

- **Vorlage speichern:** Planer fertig > "Vorlagen" > Name eintippen > "Speichern". Gespeichert werden
  die Spieler mit Gruppe, Ersatz, Festhalten, Rolle und Klasse, ohne Abgemeldete und ohne Status.
- **Vorlage laden:** Nacht wählen > "Vorlagen" > Zeile wählen > "Laden". Wer in der Vorlage steht,
  bekommt deren Gruppe, Rolle und Ersatz; wer in der Liste der Nacht fehlt, kommt dazu. Wer in der Nacht
  steht, aber nicht in der Vorlage, verliert seine Gruppe (Ersatz bleibt Ersatz). Anmeldestatus, Quellen und Notizen der Nacht
  bleiben; wer abgemeldet ist, bleibt draußen, außer die Vorlage hält ihn fest.
- **Aus dem Raid:** wie Laden, nur mit den Gruppen des Raids. Braucht der Raid mehr Gruppen als die
  Nacht, wächst ihre Größe (10/20/40). Wer abgemeldet, aber im Raid ist, wird eingeteilt und festgehalten.
- Hat die Nacht schon Gruppen, fragt Amisia vor dem Laden und vor "Aus dem Raid" nach.
- **Von Hand:** "Planer" > "Spieler" > Name anklicken > Platz anklicken. Ein Name, der schon eingeteilt
  ist, steht grau mit seiner Gruppe im Raster.

## Abnahmekriterien

- Wenn du im Planer eine Aufstellung hast, "Vorlagen" klickst, "Stamm" eintippst und "Speichern" klickst,
  dann steht "Stamm" in der Liste mit Größe und Spielerzahl, auch nach `/reload`.
- Wenn du eine leere Nacht wählst, unter "Vorlagen" die Zeile "Stamm" wählst und "Laden" klickst, dann
  zeigt der Planer dieselben Gruppen wie beim Speichern.
- Wenn du in einem Raid bist und im Planer "Mehr" > "Aus dem Raid übernehmen" klickst, dann steht jeder
  Raider in seiner Raidgruppe (braucht: Raid).
- Wenn du im Planer "Spieler" klickst, "Gilde" wählst, einen Namen anklickst und dann einen freien Platz,
  dann steht der Spieler dort; im Raster ist er grau mit der Gruppennummer.
- Wenn du "Mehr" > "Als Text exportieren" klickst, dann steht ein Block, der mit `#AMISIA-RAID 1 forever`
  beginnt; fügst du ihn in einer leeren Nacht unter "Einfügen" ein, stehen alle wieder in ihren Gruppen.
- Wenn du "Mehr" > "Gruppen leeren" klickst und bestätigst, dann sind alle Gruppen frei und alle Namen
  stehen unter "Nicht eingeteilt".

## Sonderfälle

- Kampf: alles hier ändert nur die gespeicherte Liste, nichts im Spiel; es geht auch im Kampf.
  Geheime Namen des Raids werden übersprungen (wie beim Sortieren).
- Kein Raid: "Aus dem Raid übernehmen" ist grau; die Quelle "Raid" der Spielerliste ist leer.
- Gäste (nicht in der Gilde): "Aus dem Raid" setzt sie in ihre Gruppe, weil sie schon im Raid sind. Von
  Hand geht ein Gast nur mit der Einstellung "Gäste einladen" in eine Gruppe (wie bisher).
- Volle Gruppe in einem eingefügten Block (mehr als 5) oder eine Gruppe über der Raidgröße: die
  Überzähligen stehen "Nicht eingeteilt".
- 80 Namen pro Nacht bleiben die Grenze; was darüber ist, wird nicht aufgenommen und gemeldet.
- Zwei Offiziere: jede Seite hat ihre eigenen Vorlagen (kein Abgleich); der Export ist der Weg.
- Englischer Client: alle Texte übersetzt; der Block ist sprachneutral.

## Missbrauch/Vertrauen

- Nur Offiziere mit Offiziersrang sehen die Seite (D-41). Nichts wird gesendet, nichts von anderen
  empfangen: keine neue Nachricht.
- Der eingefügte Block bleibt unvertraut: die Gruppe zählt nur als Zahl 1 bis 8, höchstens 5 pro Gruppe;
  alles andere wie bisher (Namen ohne Ziffern, 200 Byte pro Zeile, 80 Anmeldungen).
- Vorlagen aus den SavedVariables werden beim Laden Feld für Feld geprüft (wie die Nächte).

## Daten

- `AmisiaDB.lineup.sets = { { name (30), at, by, size, list = { { n, r, c, g, b, k, q } } } }`,
  höchstens 12, je höchstens 80 Namen.
- Block `#AMISIA-RAID`: die Zeile `S` bekommt ein fünftes Feld, die Gruppe `1`-`8` (oder `-`). Alte Blöcke
  ohne das Feld gelten weiter.
- Keine neue Einstellung, keine neue Nachricht.

## Offene Fragen

1. Rollen wie im Vorbild (Haupttanks in Reihenfolge, Assistenten nach Namensliste, Plündermeister mit
   Schwelle, "jetzt setzen")? Vorschlag: eigenes Feature; vorher prüft `/amisia selbsttest gruppe`, ob der
   Client die Funktionen dafür hat.
2. Einladen wie im Vorbild ("Gilde einladen" bis zu einem Rang, eigene Stichwörter statt nur "inv",
   Einladungen von Gilde und Freunden annehmen)? Vorschlag: eigenes Feature.

## Entscheidungen

- 2026-11-10: Nutzer auf "Soll ich die fünf fehlenden Punkte bauen?": "Ja, alle fünf" -> Punkte 1 bis 5 wie
  oben. Annahmen (nicht gefragt): Vorlagen als eigene Ansicht statt eines Menüs; die Spielerliste unten im
  Planer statt rechts (die Seite ist 602 breit); "Leeren" leert die Gruppen, nicht die Liste; Export als
  Text, keine Addon-Nachricht. D-91.
