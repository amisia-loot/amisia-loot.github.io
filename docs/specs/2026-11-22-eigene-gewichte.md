# Spec: Eigene Gewichte, Einfügen und Vorlagen aus der Simulation

Stand: 2026-11-22 · Status: freigegeben ·
Feature: F-230

## Ziel

Nutzer 2026-11-22 mit einem Bild des Ausrüstungsplaners: "können wir bei amisia die gewichtung der stats selbst
verändern und danach werden einem die items vorgeschlagen und paar vorgefertigte set von icy veins shadow forever
wowhead und discord shadow server". Heute rechnet Amisia nur mit seinen eigenen Gewichten (Speedrun, Hardcore, Raid,
F-225); wer einer Raid-Simulation oder den Zahlen seiner Gilde folgen will, kann das nicht. Gelöst ist es, wenn ein
Spieler eigene Gewichte eintippen, einfügen oder aus einer Vorlage übernehmen kann und Vorschläge, Ziele und
"Upgrade für dich" danach rechnen.

## Was es tut

**A. Gewichtung "Eigene".** Die Einstellung "Gewichtung" (`bis.kind`) bekommt einen vierten Wert "Eigene". Steht sie
darauf, rechnet Amisia mit dem gewählten eigenen Satz der Spezialisierung. Der Umschalter im Planer geht reihum durch
alle vier; hat die Spezialisierung keinen eigenen Satz, überspringt er "Eigene".

**B. Sätze je Klasse und Spezialisierung, für alle Charaktere.** Je Spezialisierung beliebig benannte Sätze (z. B.
"Discord Schatten", "Mein Raid"), einer davon gewählt. Sie gelten für jeden Charakter dieser Klasse auf dem Account.

**C. Bearbeiten im Planer, Reiter "Optionen", Abschnitt "Gewichte".**
- Oben die Auswahl des Satzes, daneben "Neu", "Umbenennen", "Löschen".
- Darunter je Wert eine Zeile mit Namen und Zahlenfeld: die Werte der Rolle zuerst (Zauberer: Zaubermacht, Schaden
  der Schule, Intelligenz, Willenskraft, Mana alle 5 Sek., Treffer-, Krit-, Tempowertung), darunter aufklappbar "Weitere
  Werte" (Ausdauer, Rüstung, Waffenschaden ...). Leer heißt 0.
- **Die Zahl gilt je Punkt, so wie er auf dem Item steht**: "+10 Trefferwertung" zählt 10 mal das Gewicht. Amisia
  rechnet intern weiter je Prozent (`ratings` aus `GearWeights.lua`), der Nutzer sieht nur Punkte.
- "Amisias Zahlen übernehmen" füllt den Satz mit Amisias Gewichten der gerade gewählten Gewichtung und der eigenen
  Stufe, umgerechnet auf Punkte, als Startpunkt zum Anpassen.
- Jede Änderung rechnet Vorschläge und Ziele nach 0,3 Sekunden neu (nicht bei jedem Tastendruck).

**D. Einfügen und Kopieren.**
- "Einfügen" öffnet ein Textfeld. Amisia liest zwei Formen:
  1. eine Liste `Name=Zahl`, getrennt durch Komma, Semikolon oder Zeilen, mit den Namen der Werte auf Deutsch oder
     Englisch, wie sie im Spiel heißen (`Intelligenz=0,24`, `Spell Power=1`, `Hit Rating=1.14`) und den kurzen
     englischen Namen der verbreiteten Gewichte-Zeile (`Intellect=0.24, SpellDamage=1, HitRating=1.14`);
  2. diese Liste in Klammern mit Kopf, wie Simulationen und Guides sie zum Kopieren anbieten
     (`( Name: v1: "Shadow": Class=Priest, Intellect=0.24, ... )`); der Name in Anführungszeichen wird der Name des Satzes.
- Vor dem Übernehmen eine Vorschau: welche Werte erkannt wurden, welche nicht ("unbekannt: Foo"), und ob ein Satz
  gleichen Namens ersetzt wird.
- "Kopieren" zeigt den gewählten Satz als Zeile der Form 2 zum Markieren und Kopieren (zum Teilen in Discord oder mit
  der Gilde).

**E. Vorlagen aus der Simulation.** Unter "Vorlage" stehen je Klasse die Gewichte der WoWSims-Simulation für Forever
(MIT-Lizenz), z. B. bei Priestern "Schatten", "Schmettern", "Disziplin Einzelziel", "Disziplin Raid", "Heilig
Einzelziel", "Heilig Raid". Ein Klick legt einen eigenen Satz "<Name> (Sim)" an, den man danach ändern kann; die
Vorlage selbst bleibt unverändert. Stand 2026-11-22 haben 12 von 18 Spezialisierungen der Simulation Gewichte; Magier,
Hexenmeister, Heilig- und Schutz-Paladin, Wiederherstellungs-Schamane und -Druide noch keine.

**F. Wo es wirkt:** Vorschläge und Ziele des Planers, die Liste der Ausrüstungsseite, die Set-Wertung, "Upgrade für
dich" im Item-Tooltip und "Warum diese Gewichte" (dort: "Eigene Gewichte: <Name>" und die Tabelle je Punkt).

## Was es ausdrücklich nicht tut

- **Keine Vorlagen von Wowhead oder Icy Veins.** Wowhead sperrt KI-Agenten in seiner robots.txt (D-03); Icy Veins
  weist automatische Abrufe seiner Nutzungsbedingungen ab, also ist nicht zu klären, ob Übernehmen erlaubt ist, und
  dort steht eine Itemliste, keine Gewichte. Zahlen von dort, aus Discord oder sonstwo tippt oder fügt der Spieler
  selbst ein.
- **Keine Ausrüstungslisten der Simulation.** Ihre Gear-Sets sind für Forever-Schatten nur ein Test-Set für Entwickler;
  Amisia schlägt die Items mit den Gewichten selbst vor.
- **Kein Modell für eigene Gewichte.** Amisias Upgrade-Modell (D-54, `Gear/Model.lua`) rechnet seine eigenen Annahmen
  (Mana, Krit mal Zaubermacht); mit "Eigene" zählt nur die gerade Summe Wert mal Gewicht. Die Trefferkappe gilt weiter
  (Treffer über der Kappe zählt nicht).
- **Kein Senden.** Sätze gehen nicht über Addon-Nachrichten an die Gilde; geteilt wird per Kopieren und Einfügen.
- **Keine Gewichte je Stufe.** Ein eigener Satz gilt für jede Stufe gleich.
- Nicht auf TBC Anniversary und Classic Era (der Ausrüstungsteil läuft nur in Forever).

## Abläufe

1. Der Spieler (Schatten, Stufe 60) öffnet Ausrüstung > Ausrüstungsplaner > Optionen > Gewichte.
2. Er wählt "Vorlage" > "Schatten" → ein Satz "Schatten (Sim)" ist da und gewählt, die Gewichtung steht auf "Eigene".
3. Vorschläge und Ziele rechnen neu: Teile mit Treffer und Krit steigen, Teile mit viel Intelligenz und Willenskraft
   fallen. Die Prozente rechts sagen, wie viel ein Teil an der eigenen Wertung zulegt.
4. Er ändert Willenskraft von 0,01 auf 0,2 → nach einem Augenblick stehen die Vorschläge neu.
5. Aus Discord kopiert er eine Zeile, klickt "Einfügen", sieht die Vorschau und übernimmt sie als "Discord Schatten".
6. Über den Umschalter geht er zurück auf "Raid": alles rechnet wieder mit Amisias Zahlen; die eigenen Sätze bleiben.
7. Ein zweiter Priester auf dem Account findet dieselben Sätze vor. Andere Spieler merken nichts.

## Abnahmekriterien

- Wenn du im Planer unter Optionen > Gewichte "Vorlage" > "Schatten" wählst, dann steht die Gewichtung auf
  "Eigene: Schatten (Sim)", die Felder zeigen Zaubermacht 1, Schaden (Schatten) 1, Intelligenz 0,24, Trefferwertung
  1,14, und die Reihenfolge der Vorschläge ändert sich.
- Wenn du dort Intelligenz auf 2 setzt, dann rücken Teile mit viel Intelligenz in den Vorschlägen nach oben, ohne
  `/reload`.
- Wenn du `Intellect=0.5, SpellDamage=1, HitRating=1.2, Foo=3` einfügst, dann nennt die Vorschau drei erkannte Werte und
  "unbekannt: Foo", und nach "Übernehmen" steht der neue Satz in der Auswahl.
- Wenn du "Kopieren" klickst und die Zeile in ein neues "Einfügen" gibst, dann entsteht ein Satz mit denselben Zahlen.
- Wenn du auf "Raid" zurückschaltest, dann stehen die Vorschläge wie vorher, und mit einem anderen Charakter derselben
  Klasse findest du deine Sätze wieder.
- Wenn du über ein Item fährst, während "Eigene" gewählt ist, dann rechnet "Upgrade für dich" mit deinem Satz.

## Sonderfälle

- **Satz gelöscht, der gewählt war:** die Gewichtung fällt auf "Speedrun" zurück, eine Chatzeile sagt es.
- **Alle Gewichte 0 oder leer:** der Satz lässt sich speichern, der Planer zeigt "Alle Gewichte sind 0." statt Vorschläge.
- **Negative Zahlen:** erlaubt (z. B. Willenskraft -0,1 für "lieber nicht"), von -10 bis 100 je Punkt.
- **Komma oder Punkt:** beide werden als Dezimalzeichen gelesen; Tausenderpunkte gibt es nicht.
- **Zwei Werte, die Amisia zusammen führt:** "Zaubermacht" (Schaden und Heilung) und "Heilung" bleiben getrennt wie in
  `terms`; "Trefferwertung" zählt für Nahkampf und Zauber, wie ein Wertungspunkt in Forever für beide gilt.
- **Spezialisierung geraten** (Bild: "Schatten (geraten)"): die Sätze hängen an der gewählten Spezialisierung; wechselt
  sie, gilt deren gewählter Satz oder, ohne einen, "Speedrun".
- **Simulierter Charakter** (F-044): rechnet mit den Sätzen seiner Klasse und Spezialisierung.
- **Alte Datendatei ohne Vorlagen:** "Vorlage" ist grau mit dem Hinweis, dass die Daten keine haben.
- **Client auf Englisch:** alle neuen Texte in `Locales/enUS_gear.lua`; die Namen der Werte im Einfügen kennt Amisia in
  beiden Sprachen unabhängig von der Spielsprache.

## Missbrauch/Vertrauen

Eingefügter Text ist unvertraut (D-26): höchstens 4000 Zeichen gelesen, höchstens 40 Werte, Zahlen nur als Ziffern mit
höchstens einem Dezimalzeichen, außerhalb -10 bis 100 abgelehnt mit Hinweis, Name des Satzes ohne Farbcodes und
Steuerzeichen, höchstens 32 Zeichen; nichts davon wird ausgeführt (kein `loadstring`). Höchstens 20 Sätze je
Spezialisierung. Sonst lokal: keine Nachricht, keine Aktion für andere.

## Daten

- **Neuer gespeicherter Schlüssel `AmisiaDB.weights`** (accountweit): `{ [class] = { [specKey] = { pick = name,
  sets = { [name] = { [stat] = Zahl je Punkt } } } } }`; die Wertschlüssel sind Amisias (`INT`, `SP`, `SP_SHADOW`,
  `HIT`, `CRIT`, `HASTE` ...). Prüfung und Bereinigung beim Laden wie `AmisiaDB.bis`.
- **`bis.kind`** bekommt den Wert "Eigene"; kein neuer Einstellungsabschnitt (der Abschnitt "Gewichte" lebt im Reiter
  Optionen des Planers).
- **Neues Werkzeug `tools/wowsims_weights.py`** (`python3 tools/build.py wowsims`): lädt über die GitHub-API die Dateien
  `ui/specs/*/*/presets.ts` von `wowsims/forever` in einen Cache außerhalb des Repos, eine Anfrage nach der anderen,
  und liest daraus nur die Aufrufe `makePresetEpWeights` als Text (Name, `Stat...: Zahl`), ohne den Code auszuführen.
  `build.py data` liest nur den Cache und schreibt die Vorlagen als `SIM` in `Data/GearWeights.lua`:
  `{ [class] = { { name, spec = specKey oder nil, w = { [stat] = Zahl je Punkt } } } }`; die Zuordnung der
  Simulations-Spezialisierungen zu Amisias (`priest/dps` → `PRIEST` `shadow`) steht von Hand im Werkzeug.
- **Lizenz:** WoWSims steht unter MIT; der Lizenztext kommt nach `Amisia/LICENSES/`, `THIRD-PARTY.md` nennt die Quelle,
  der Kopf von `GearWeights.lua` auch.
- **Regel:** ein neuer Eintrag in `docs/DECISIONS.md`: eigene Gewichte rechnen linear ohne Modell, je Punkt eingegeben;
  WoWSims als erlaubte Datenquelle (D-04 Nachtrag); der Satz "keine Zahlen aus fremden Simulationen" der Spec F-225
  gilt für Amisias eigene Gewichte weiter, die Vorlagen sind getrennt davon und als "(Sim)" gekennzeichnet.
- **Tests:** Lesen beider Einfüge-Formen, Grenzen und Fehler, Umrechnung Punkt ↔ Prozent gegen `ratings`,
  `tools/tests/test_score_parity.py` mit einem eigenen Satz, der Parser des Werkzeugs gegen einen Ausschnitt von
  `presets.ts`.

## Offene Fragen

1. **Wo der Editor steht.** Vorschlag: im Reiter "Optionen" des Planers (dort, wo man ihn sucht, wenn man Vorschläge
   ändern will), nicht in den allgemeinen Einstellungen.
2. **Die Prozente rechts mit "Eigene".** Ohne Modell gibt es keinen "Anteil an deinem Schaden". Vorschlag: der Zuwachs
   der eigenen Wertung gegen die Wertung des angelegten Teils in diesem Platz, wie heute ohne Modell; im Tooltip "nach
   deinen Gewichten".
3. **Den Namen des verbreiteten Formats nennen?** Die Klammer-Zeile aus D stammt von einem anderen Addon. Vorschlag:
   Amisia liest sie, nennt den Namen aber nicht (D-05); in der Hilfe steht "die Gewichte-Zeile, die Simulationen und
   Guides zum Kopieren anbieten".
4. **"WoWSims" in der Oberfläche.** Vorschlag: die Vorlagen heißen "<Name> (Sim)", der Tooltip sagt "aus der
   WoWSims-Simulation für Forever (MIT)", ohne Link (keine Links zu Fan-Seiten).
5. **Wie oft die Vorlagen kommen.** Vorschlag: `build.py wowsims` von Hand vor einem Release, wenn sich etwas ändern soll;
   nicht im täglichen automatischen Lauf.
6. **Sätze per Gilde teilen?** Vorschlag: nicht in dieser Spec; Kopieren und Einfügen reicht. Ein Teilen per Nachricht
   wäre eine eigene Spec.

## Entscheidungen

- 2026-11-22: Spec gewünscht ("Ja, Spec schreiben") nach dem Vorschlag: eigene Gewichte je Spezialisierung, Einfügen per
  Text, Vorlagen aus WoWSims (MIT); Wowhead (gesperrt) und Icy Veins (Abruf abgewiesen) nicht als Quelle. Die offenen
  Fragen sind noch nicht beantwortet.
- 2026-11-22: "Passt, bauen" auf den Entwurf mit seinen sechs Fragen -> jede Frage wie vorgeschlagen:
  - Frage 1: der Editor steht im Reiter "Optionen" des Planers.
  - Frage 2: die Prozente mit "Eigene" sind der Zuwachs der eigenen Wertung gegen das angelegte Teil des Platzes, im
    Tooltip "nach deinen Gewichten".
  - Frage 3: Amisia liest die Klammer-Zeile, nennt den Namen des Formats nicht (D-05).
  - Frage 4: Vorlagen heißen "<Name> (Sim)", der Tooltip nennt WoWSims (MIT), ohne Link.
  - Frage 5: `build.py wowsims` von Hand vor einem Release, nicht im automatischen Lauf.
  - Frage 6: kein Teilen per Nachricht in dieser Spec.
- 2026-11-22, beim Bauen:
  - "Optionen" ist im Planer ein Menü, kein Reiter. Der Abschnitt "Gewichte" ist darum ein eigenes Fenster
    ("Gewichte", geöffnet über Optionen > "Gewichte ..."), das neben dem Planer steht: so bleiben Vorschläge und Ziele
    beim Ändern sichtbar (Abläufe 3 und 4). Der Umschalter der Gewichtung steht im Ausrüstungsfenster und als Link im
    Fenster "Gewichte"; beide gehen reihum Speedrun, Hardcore, Raid, Eigene (nur mit einem gewählten Satz).
  - Treffer- und Kritwertung eines Satzes zählen auf der Seite der Spezialisierung: bei Zauberern und Heilern als
    Zauberwertung, sonst als Waffenwertung (so zählt ein Punkt einmal und die passende Trefferkappe greift). Tempo und
    Waffenkunde stehen immer (leer ist 0), damit kein Ersatz aus Krit und Treffer greift.
  - Die kopierte Zeile beginnt mit `( Amisia: v1: "Name": Class=...`; gelesen wird jedes Wort an dieser Stelle. Eine
    eingefügte Liste ohne Namen heißt "Eingefügt" (danach "Eingefügt 2" ...) und ersetzt nie einen Satz; eine Zeile mit
    Namen ersetzt den Satz gleichen Namens (die Vorschau sagt es). Eine Vorlage ersetzt ihren Satz "<Name> (Sim)".
  - Jeder neu angelegte oder gewählte Satz wird der gewählte, und die eigene Gewichtung springt auf "Eigene"
    (Ablauf 2 für Vorlage, Einfügen, Neu und die Auswahl gleich).
  - Vorlagen: die Namen der Simulation von Hand ins Deutsche (z. B. "Disc Raid Healing" -> "Disziplin Raid"); ein
    Satz der Simulation, der berechnet statt als Zahlen steht (die Hybrid-Werte von Katze und Bär), und Werte wie
    `2.32 * Mechanics...` fehlen mit einer Zeile im Bau. Stand 3289d8314f: 26 Vorlagen.
