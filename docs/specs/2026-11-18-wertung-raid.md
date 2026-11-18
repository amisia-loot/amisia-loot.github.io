# Spec: Wertung "Raid" ab Stufe 60

Stand: 2026-11-18 · Status: freigegeben ·
Feature: F-225

## Ziel

Nutzer 2026-11-18, nach dem Vergleich von Amisias Schatten-Gewichten mit einer Raid-Simulation ("Ja, Spec schreiben"):
Amisia wertet Ausrüstung nur fürs Leveln und für Dungeons ("Speedrun", "Hardcore"). Im Raid gelten andere Regeln: das
Mana geht kaum aus, der Boss ist drei Stufen höher, der Zauberstab ruht. Auf Stufe 60 bevorzugt Amisia deshalb
Intelligenz und Willenskraft zu stark und Treffer und Tempo zu wenig (Schatten, Stufe 60: Intelligenz 1,70 je Punkt
gegen 0,24 in der Simulation). Gelöst ist es, wenn ein Spieler auf 60 eine dritte Wertung "Raid" wählen kann und die
Vorschläge, die Ziele und "Upgrade für dich" danach für einen Bosskampf rechnen.

## Was es tut

**A. Eine dritte Gewichtung.** Die Einstellung "Gewichtung" (`bis.kind`) bekommt neben "Speedrun" und "Hardcore" den
Wert "Raid". Der Umschalter im Ausrüstungsfenster geht reihum durch alle drei. Der Tooltip sagt: "Raid rechnet einen
Bosskampf auf Stufe 60: Ziel drei Stufen höher, Mana kaum knapp."

**B. Nur auf Stufe 60.** "Raid" hat eigene Gewichte allein für die Stufe 60. Für jede Stufe darunter rechnet "Raid"
wie "Speedrun"; der Tooltip des Umschalters und "Warum diese Gewichte" sagen das ("Raid gilt ab Stufe 60, bis dahin
Speedrun").

**C. Was "Raid" anders rechnet** (Vorschlag der Zahlen, alle in `tools/build_bis.py`, jede mit ihrem Grund):

| Was | Speedrun | Raid | Grund |
|---|---|---|---|
| Ziel | zwei Stufen höher | drei Stufen höher (63) | Raidboss |
| Zaubertreffer zählt bis | 6 % | 16 % | 17 % verfehlen, 1 % bleibt immer |
| Nahkampftreffer zählt bis | 6 % | 9 % | Boss der Stufe 63 |
| Manaknappheit der Schadenszauberer | 0,5 | 0,1 | Tränke, Totems, Richturteil der Weisheit |
| Zauberstab (Distanz-DPS) | zählt | zählt nicht | im Bosskampf wird nicht gestabt |
| Überleben (Ausdauer, Rüstung) für Schaden | 10 % | 10 % | unverändert |
| Heiler | eigene Gewichte | unverändert | ihr Mana bleibt im Raid knapp |
| Tanks | eigene Gewichte | unverändert bis auf das Ziel | siehe Frage 3 |

Für Schatten auf 60 ergibt das mit derselben Formel (gebaut am 2026-11-18): Intelligenz 0,50 statt 1,69,
Willenskraft 0,10 statt 0,47, Tempo 1,11 statt 0,60 je Wertungspunkt, Treffer 1,60 statt 1,51 je Wertungspunkt und
bis 16 % statt bis 6 %.

**D. Überall, wo die Gewichtung heute wirkt:** Vorschläge und Ziele des Planers, die Liste der Ausrüstungsseite,
"Upgrade für dich" im Item-Tooltip, "Warum diese Gewichte" (dort steht bei "Raid" der Satz aus dem Tooltip und die
Tabelle oben für die eigene Klasse).

## Was es ausdrücklich nicht tut

- Keine Simulation: keine Rotation, keine Procs, keine Buffs und Verbrauchsgüter am Referenzcharakter. Es bleiben
  Amisias eigene Formeln mit anderen Annahmen.
- Keine Zahlen und keine Listen aus fremden Simulationen oder BiS-Listen (D-03, D-04). Die Simulation war nur der
  Anlass, die Annahmen zu prüfen.
- Kein eigener Satz Gewichte je Raid oder je Boss, keine Resistenz-Ausrüstung.
- Kein automatisches Umschalten: Amisia wechselt die Gewichtung nicht von selbst, wenn man 60 wird oder einem Raid
  beitritt (siehe Frage 2).
- Keine eigene Raid-Wertung unter Stufe 60.
- Nicht auf TBC Anniversary und Classic Era: der Ausrüstungsteil läuft nur in Forever.

## Abläufe

1. Der Spieler ist 60 und öffnet die Ausrüstungsseite. Er klickt den Umschalter der Gewichtung, bis "Raid" dasteht (oder
   wählt es in den Einstellungen).
2. Liste, Ziele und Planer rechnen sofort neu. Teile mit Treffer und Tempo steigen, Teile mit viel Intelligenz und
   Willenskraft fallen.
3. Im Tooltip eines Items rechnet "Upgrade für dich" mit "Raid".
4. Schaltet er zurück auf "Speedrun", steht alles wie vorher.
5. Bei anderen Spielern passiert nichts; nichts wird gesendet.

## Abnahmekriterien

- Wenn du auf Stufe 60 die Gewichtung auf "Raid" stellst, dann ändert sich die Reihenfolge der Vorschläge im Planer, und
  "Warum diese Gewichte" nennt Ziel Stufe 63 und die Trefferkappe deiner Klasse.
- Wenn du als Schatten-Priester auf "Raid" ein Stoffteil mit Treffer und eines mit gleich viel Intelligenz vergleichst,
  dann steht das mit Treffer höher; auf "Speedrun" ist es umgekehrt oder knapper.
- Wenn du als Zauberer mit 6 % Zaubertreffer ein Teil mit weiterem Treffer ansiehst, dann zeigt "Upgrade für dich" auf
  "Raid" einen Gewinn dafür, auf "Speedrun" keinen.
- Wenn du mit einem Charakter unter 60 "Raid" wählst, dann sind die Vorschläge dieselben wie auf "Speedrun", und
  "Warum diese Gewichte" sagt "Raid gilt ab Stufe 60, bis dahin Speedrun".
- Wenn du den Umschalter dreimal klickst, dann steht wieder die erste Gewichtung da.

## Sonderfälle

- **Gespeicherte Wahl von früher:** "Speedrun" und "Hardcore" bleiben, wie sie sind; niemand landet ungefragt auf "Raid".
- **Simulierter Charakter** (Seite Wertung vergleichen, F-044): rechnet mit der gewählten Gewichtung und seiner Stufe;
  unter 60 wie Speedrun.
- **Klassen ohne eigene Raid-Annahme** (Heiler): "Raid" zeigt ihre heutigen Gewichte, der Satz unter "Warum diese
  Gewichte" sagt das.
- **Werte über der Kappe:** Treffer über 16 % (Zauber) bzw. 9 % (Nahkampf) zählt wie heute über 6 %: nicht mehr.
- **Client auf Englisch:** "Raid" heißt in beiden Sprachen gleich; die neuen Sätze kommen in `Locales/enUS_gear.lua`.
- **Alte Datendatei:** fehlt `Raid` in `GearWeights.lua`, rechnet das Addon mit "Speedrun" (so liest `Gear.Weights`
  schon heute eine unbekannte Gewichtung).

## Missbrauch/Vertrauen

Nichts. Die Wertung ist lokal: keine Nachricht, kein Abgleich, keine Aktion für andere.

## Daten

- **Kein neuer gespeicherter Schlüssel.** `bis.kind` bekommt den dritten Wert "Raid".
- **`Data/GearWeights.lua`:** je Spezialisierung neben `Speedrun` und `Hardcore` ein Satz `Raid` (nur der letzte
  Bereich, Stufe 60); in `model` die neuen Konstanten (Ziel, Kappen, Knappheit). `tools/build_bis.py`: `KINDS` mit
  "Raid", die Tabelle aus C als benannte Konstanten.
- **Formel zweimal:** `tools/build_bis.py` und `Gear/Gear.lua` / `Gear/Model.lua` rechnen gleich;
  `tools/tests/test_score_parity.py` hält sie gleich und bekommt "Raid" dazu.
- **Regel:** ein neuer Eintrag in `docs/DECISIONS.md` mit den Annahmen aus C und ihrer Herkunft; die Trefferwerte gegen
  Stufe 63 sind Classic-Werte und gelten, bis eine Messung im Spiel sie ändert (`tools/bis_measured.json`).

## Offene Fragen

1. **Die Zahlen aus C.** Manaknappheit 0,1 und die Kappen 16 % und 9 % sind Classic-Werte, in Forever nicht gemessen.
   Vorschlag: so übernehmen, in "Warum diese Gewichte" als Annahme zeigen, und später am Raidboss messen.
2. **Hinweis statt Automatik?** Vorschlag: kein Umschalten von selbst; wer 60 ist und noch "Speedrun" hat, sieht im
   Kopf des Ausrüstungsfensters (dort steht der Umschalter) einmal je Sitzung den ruhigen Link "Für Raids:
   Gewichtung Raid".
3. **Tanks.** Vorschlag für die erste Fassung: nur das Ziel (Stufe 63) ändert sich; eine eigene Regel für
   Krit-Immunität über Verteidigung kommt erst, wenn sie in Forever gemessen ist.
4. **Heiler.** Vorschlag: unverändert. Wenn du willst, dass im Raid Manaregeneration (alle 5 Sek.) mehr und
   Willenskraft weniger zählt, wäre das ein zweiter Schritt.
5. **Krit der Zauberer.** Amisia zählt einen kritischen Zauber mit halbem Zusatzschaden; die Simulation kommt etwa auf
   das Doppelte. Vorschlag: nicht Teil dieser Spec; erst klären, welches Talent oder welche Regel in Forever dahinter
   steht.

## Entscheidungen

- 2026-11-18: Spec gewünscht ("Ja, Spec schreiben") nach dem Vorschlag einer dritten Wertung "Raid" ab Stufe 60. Die
  offenen Fragen sind noch nicht beantwortet.
- 2026-11-18, beim Bauen: der Link aus Frage 2 steht im Ausrüstungsfenster neben "Mein Charakter" (dort ist der
  Umschalter), nicht auf der Seite Ausrüstung des Hauptfensters; den Satz "Raid gilt ab Stufe 60, bis dahin Speedrun"
  sagen der Tooltip des Umschalters und "Warum diese Gewichte" statt eines Kopfs. Die Zahlen für Schatten in C sind
  die gebauten.
- 2026-11-18: "passt" auf den Entwurf mit seinen fünf Fragen -> jede Frage wie vorgeschlagen:
  - Frage 1: die Zahlen aus C übernehmen (Manaknappheit 0,1, Zaubertreffer bis 16 %, Nahkampftreffer bis 9 %), als
    Annahme zeigen, später am Raidboss messen.
  - Frage 2: kein Umschalten von selbst; ein ruhiger Link im Kopf der Ausrüstungsseite, einmal je Sitzung, für
    Stufe 60 mit "Speedrun".
  - Frage 3: Tanks: nur das Ziel (Stufe 63) ändert sich.
  - Frage 4: Heiler: unverändert.
  - Frage 5: der Krit der Zauberer ist nicht Teil dieser Spec.
