# Spec: Dungeon-Leiste (Bosse, Quests, Zeit, Route)

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10 auf die Liste der neun Punkte: "1,2,3,5,8,9") ·
Feature: F-168

## Ziel

Wer in einem Dungeon steht, sieht auf einen Blick, was Amisia über ihn weiß: wie viele Bosse tot sind, welche
Quests dort offen oder fertig sind, die Uhr des Laufs und den Stopp der Route, der er folgt. Bisher stand das
verteilt auf der Seite Dungeons, im Fenster "Lauf-Zeiten" und auf der Weltkarte. Gelöst ist es, wenn eine kleine
Leiste beim Betreten von selbst erscheint, beim Verlassen verschwindet und jeder ihrer Teile mit einem Klick
dorthin führt, wo es mehr gibt.

## Was es tut

- **Leiste** (`Gear/DungeonBar.lua`, `AmisiaDungeonBar`): eine Zeile, so hoch wie eine Chipreihe, dunkler Grund
  mit goldenem Rand. Links der Name der Instanz (vom Client, gekürzt auf 130 px), daran wird sie gezogen;
  rechts das rote x. Dazwischen die Abschnitte, jeder nur, wenn er etwas zu zeigen hat:
  1. **"Bosse 2/5"**: die Bosse in der Reihenfolge des Spiels, gezählt die Kills des eigenen Laufs
     (`Gear/Runs.lua`); ohne Encounter-IDs nur "Bosse 5". Ein Klick öffnet darunter die Liste: Haken und grau
     die getöteten ("besiegt"), gold der nächste ("als Nächstes"); ein Klick auf einen Boss öffnet die Seite
     Dungeons (ein Raid: Raids) im Teil Übersicht auf diesem Boss (`ns.ShowDungeonBoss`, neu, wie der
     Quellen-Sprung F-157).
  2. **"Quests 3"**, mit grün "(1 fertig)", wenn welche abgabebereit sind: die Quests des Dungeons, die der
     Charakter hat oder noch bekommen kann (nicht erledigt, nicht mehr möglich), fertige zuerst, dann im Log,
     annehmbar, gesperrt; je Zeile das Zeichen des Quest-Journals (`D.QuestStateIcon`), der Titel (fertig grün)
     und rechts die Stufe. Ein Klick öffnet ihren Weg im Quest-Journal der Seite (`ns.ShowDungeonQuest`, wie
     der Klick im Journal selbst).
  3. **"Zeit 12:40"**, solange die Uhr des Laufs läuft (F-166): ein Klick zeigt oder verbirgt das Fenster
     "Lauf-Zeiten". Keine Liste.
  4. **"Route 3/7"**, solange einer eigenen Route gefolgt wird (F-167): die Liste zeigt die Stopps (vorbei mit
     Haken, das Ziel gold) und darunter "Weiter zum nächsten Stopp" und "Folgen beenden"; ein Rechtsklick auf
     den Abschnitt geht gleich zum nächsten Stopp.
- **Liste** (`AmisiaDungeonBarList`): ein eigenes kleines Feld unter der Leiste (kein Menü, weil Zeilen
  Zeichen, Haken und rechts eine Notiz tragen), höchstens 20 Zeilen; zu mit einem zweiten Klick auf den
  Abschnitt, mit Escape (die Leiste bleibt) und beim Verlassen; ein anderer Abschnitt ersetzt sie. Sie folgt
  Kills, dem Quest-Log und der Route.
- **Wann:** von selbst beim Betreten eines Dungeons, den die Fakten kennen (`R.Here()`), weg beim Verlassen; in
  Raids nur mit der Einstellung "Auch in Raids" (aus). Das x verbirgt sie bis zum nächsten Betreten oder
  `/amisia leiste`.
- **Platz:** oben in der Mitte (40 px unter dem Rand), verschiebbar am Namen, am Bildschirm gehalten, gemerkt;
  "Fensterposition zurücksetzen" (Einstellungen, Allgemein) setzt sie mit zurück.
- **Befehl:** `/amisia leiste` (en `bar`): zeigt oder verbirgt sie jetzt (auch in einem Raid und mit der
  Einstellung aus); draußen "Die Dungeon-Leiste zeigt sich in einem Dungeon.".
- **Einstellungen** "Dungeon-Leiste" (Reiter Dungeons & Raids, alle): "Dungeon-Leiste zeigen" (an), "Auch in
  Raids" (aus), "Bosse in der Leiste", "Quests in der Leiste", "Zeit in der Leiste", "Route in der Leiste"
  (alle an). Keine Größe.

## Was es ausdrücklich nicht tut

- Keine Gruppe: was die anderen an Quests haben, bräuchte Nachrichten; es wird nichts gesendet oder empfangen.
- Keine eigenen Daten, keine neue Datendatei, kein neuer gespeicherter Schlüssel außer dem Platz.
- Keine Änderung am Quest-Tracker (Seite Quests), am Fenster "Lauf-Zeiten" oder an den Seiten außer dem kleinen
  Sprung `ns.ShowDungeonBoss`.
- Öffnet in Instanzen keine Weltkarte (D-62: das tut Amisia dort nie).

## Abläufe

- **Allein im Dungeon:** Betreten: oben in der Mitte "Halle der Thane · Bosse 0/4 · Quests 3". Erster Kampf:
  "Zeit 0:00" kommt dazu. Boss tot: "Bosse 1/4". Klick auf "Bosse": die Liste, der nächste gold; Klick auf ihn:
  die Seite Dungeons auf diesem Boss. Rauslaufen: die Leiste ist weg.
- **Quest abgeben:** eine Quest wird fertig: "Quests 3 (1 fertig)" grün; die Liste zeigt sie oben mit dem gelben
  "?"; Klick: ihr Weg im Quest-Journal.
- **Route:** auf der Weltkarte "Route folgen"; im Dungeon "Route 1/5"; Rechtsklick: "Route 2/5".
- **Weg damit:** das x; beim nächsten Dungeon ist sie wieder da. Ganz aus: Einstellungen.

## Abnahmekriterien

- Wenn du allein einen Dungeon betrittst, dann steht oben in der Mitte eine kleine Leiste mit seinem Namen,
  "Bosse 0/n" und (wenn du dort Quests hast oder bekommen kannst) "Quests n"; läufst du hinaus, ist sie weg.
- Wenn du den ersten Boss tötest, dann steht "Bosse 1/n"; ein Klick auf "Bosse" zeigt die Liste mit Haken beim
  ersten und dem zweiten gold "als Nächstes"; ein Klick auf einen Boss öffnet die Seite Dungeons auf ihm; ein
  zweiter Klick auf "Bosse" oder Escape schließt die Liste, die Leiste bleibt.
- Wenn eine Quest dieses Dungeons fertig ist, dann steht grün "(1 fertig)" hinter "Quests n" und sie steht oben
  in der Liste; ein Klick öffnet ihren Weg im Quest-Journal.
- Wenn der erste Kampf beginnt, dann steht "Zeit 0:00" und läuft; ein Klick darauf verbirgt das Fenster
  "Lauf-Zeiten", ein zweiter zeigt es.
- Wenn du die Leiste am Namen verschiebst, `/reload` machst und wieder in einen Dungeon gehst, dann steht sie am
  neuen Platz; das x verbirgt sie, `/amisia leiste` zeigt sie wieder.

## Sonderfälle

- `/reload` im Kampf in einem Dungeon: die Leiste wird beim Betreten der Welt gebaut, ein einfacher Rahmen ohne
  geschützte Aufrufe, und zeigt sich auch im Kampf.
- Zwei Schlüssel auf einer Karte (Blackrock Spire): der Schlüssel der laufenden Uhr gilt, sonst der erste.
- Ein Dungeon ohne Encounter-IDs: "Bosse n" ohne Zähler, keine Haken.
- Ein Raid: kein Abschnitt Quests (die Seite Raids hat kein Quest-Journal).
- Keine Quests, keine Uhr, keine Route: nur der Name und "Bosse".
- Englischer Client: Texte englisch (`/amisia bar`), Instanzname vom Client.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen; die Leiste liest nur, was andere Module schon wissen.

## Daten

- Neu nur der Platz `settings.dungeonBar = { point, x, y }`.
- Einstellungen: Abschnitt `dungeonbar` mit `dungeonbar.on`, `dungeonbar.raids`, `dungeonbar.bosses`,
  `dungeonbar.quests`, `dungeonbar.time`, `dungeonbar.route`.
- Gelesen: `ns.Runs` (Fakten, Kills), `ns.DungeonQuests`/`D.QuestState`, `ns.RunTimes.Live`,
  `ns.Routes.Following`; Ereignisse `RUN`, `RUNTIMES`, `ROUTES`, das Quest-Log.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-10: Nutzer auf die Liste der neun Punkte: "1,2,3,5,8,9" -> Punkt 9 "Kleine Leiste im Dungeon mit
  Quests, Bossen und Route, frei verschiebbar". D-98.
- Annahme (nicht gefragt): standardmäßig an, weil sie nur in Dungeons erscheint und ein Klick sie bis zum
  nächsten Mal verbirgt; in Raids aus, weil die Raid-Werkzeuge eigene Fenster haben.
- Annahme (nicht gefragt): "Route" zeigt nur eine gefolgte eigene Route; die Halte des Laufplaners (F-139)
  liegen draußen vor und nach dem Dungeon, drinnen hätte er nichts zu zeigen, und seine Bosse mit Questzielen
  stehen schon auf der Seite.
- Annahme (nicht gefragt): ein Klick auf "Route" öffnet die Liste der Stopps statt der Weltkarte, weil Amisia in
  Instanzen die Weltkarte nie öffnet (D-62); Rechtsklick geht weiter.
- Annahme (nicht gefragt): oben in der Mitte als Platz, weil rechts der Quest-Tracker des Spiels und das Fenster
  "Lauf-Zeiten" stehen und links die Gruppe.
- Annahme (nicht gefragt): `/amisia leiste` zeigt sie auch in einem Raid und bei ausgeschalteter Einstellung, bis
  zum Verlassen (wer tippt, will sie sehen).
