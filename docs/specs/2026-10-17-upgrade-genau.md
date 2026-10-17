# Spec: Genaues Upgrade für deine Spezialisierung

Stand: 2026-10-17 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-115

## Ziel

"Upgrade für dich" soll so genau wie ein guter Stat-Rechner sagen, wie viel stärker ein Item dich in
deiner Spezialisierung macht, und zeigen, für welche Spezialisierung das gilt. Heute rechnet Amisia
lineare Gewichte gegen einen Referenz-Charakter je Fünf-Stufen-Bereich und gibt den Zuwachs in Prozent
des einen Slots an. So steht ein Umhang mit +5 Stärke gegen einen fast leeren Umhang bei "+122 %",
obwohl dein Schaden vielleicht um 1,5 % steigt. Gelöst ist das, wenn die Zahl im Tooltip der
tatsächliche Zuwachs deines Schadens, deiner Heilung bzw. deines Überlebens ist, nachgerechnet mit
deinen eigenen Werten.

## Was es tut

- **Tooltip-Zeile mit Spezialisierung und Gesamt-Prozent:** zum Beispiel
  "Upgrade für dich (Verstärkung): +1,6 % Schaden (Rücken)". Ist die Spezialisierung geraten,
  steht "(Verstärkung, geraten)". Die Größe heißt je Rolle "Schaden", "Heilung" oder "Überleben".
  Eine Nachkommastelle, unter 10 %.
- **Deine Werte statt Referenz:** Amisia liest außerhalb des Kampfs den Charakterbogen ab: Stufe,
  Primärwerte, Angriffs- und Distanzangriffskraft, Waffenschaden und -tempo, Krit-, Treffer- und
  Ausweichchance, Zauberschaden je Schule, Heilung, Zauberkrit, Mana, Rüstung, Gesundheit, Parieren
  und Blocken. Talente und Buffs, die schon im Bogen stecken, zählen damit automatisch mit.
  Prozent-Talente auf Werte (z. B. +10 % Intelligenz) liest Amisia als Verhältnis aus dem Bogen ab,
  sodass +5 Intelligenz dann als +5,5 zählen.
- **Vorher/Nachher statt linearer Gewichte:** Amisia nimmt das Modell der Spezialisierung aus
  `tools/build_bis.py` (Nahkampf/Distanz, Zauber, Heilung, Tank), rechnet es einmal mit deinen Werten
  und einmal mit "altes Item raus, neues rein" und gibt die Differenz an. Damit stimmen
  Trefferobergrenze, Krit mal Angriffskraft, Mana gegen Zauberschaden und Rüstungsabzug von selbst,
  ohne Sonderregel.
- **Genau dieselbe Stufe:** die Umrechnungen (Beweglichkeit je Krit, Rating je Prozent) gelten für
  deine Stufe, nicht für das obere Ende des Bereichs.
- **Setboni:** Bricht das neue Item einen getragenen Setbonus oder schließt es einen, zählt das mit.
- **Mit Shift:** die Zerlegung ("Schaden +2,0 %, Überleben −0,4 %"), der alte Slot-Prozentwert
  ("Slot: +122 %"), die anderen Spezialisierungen deiner Klasse in einer Zeile
  ("Elementar −0,2 %, Wiederherstellung +0,9 %") und die Verzauberung, die beim Wechsel am alten Item
  bleibt.
- **Überall, wo verglichen wird:** Tooltip, Questbelohnungen, Würfel-Fenster, Dungeon-Seite "Nur
  Upgrades", Seite Ausrüstung "Hier" und "Zuwachs" bei Ziele benutzen dieselbe Zahl
  (`ns.UpgradeOf`).
- **"Warum?"** erklärt die Rechnung: deine Ausgangswerte, die Werte nach dem Tausch, die Differenz je
  Wert.

## Was es ausdrücklich nicht tut

- Keine Kampfsimulation und kein Kampflog: das Modell rechnet einen gleichmäßigen Kampf mit
  Mittelwerten (D-11, "anzeigen ja, Verstecktes errechnen nein").
- Keine Proc- und Benutzen-Effekte, die das Modell nicht kennt: sie bleiben "Effekt nicht gewertet".
- Keine Werte von Websites oder fremden Addons; das Modell bleibt Amisias eigenes.
- Ausrüstungstabelle, Simulation und Planung für andere Klassen behalten die Referenzwerte: für sie
  gibt es keinen Charakterbogen.
- Keine Wahl einzelner Buffs ("mit Weltbuffs rechnen"); es gilt der Bogen, wie er ist.

## Abläufe

1. Du loggst ein. Sobald du nicht im Kampf bist, liest Amisia den Charakterbogen und merkt sich den
   Stand. Neu gelesen wird nach Ausrüstungswechsel, Stufenaufstieg und Talentänderung, aber nur
   außerhalb des Kampfs.
2. Du fährst über ein Item. Amisia nimmt deinen Stand, tauscht rechnerisch das verglichene Item
   (Ring/Schmuck: den schwächeren, Zweihänder: beide Hände) und zeigt die Differenz in Prozent deiner
   Gesamtleistung.
3. Mit Shift siehst du die Zerlegung und die anderen Spezialisierungen.
4. Wenn ein Offizier "Wer braucht das?" fragt, antwortet Amisia mit derselben Zahl (siehe Frage 4).

## Abnahmekriterien

- Wenn du als Verstärkungs-Schamane mit der Maus über einen Umhang mit +5 Stärke, +5 Intelligenz,
  +5 Willenskraft fährst und einen Umhang ohne Werte trägst, dann steht "Upgrade für dich
  (Verstärkung): +x,x % Schaden (Rücken)" mit einer kleinen Zahl, nicht über 100 %.
- Wenn du Shift hältst, dann zeigt der Tooltip die Zerlegung, "Slot: +N %" und eine Zeile mit den
  anderen Spezialisierungen deiner Klasse.
- Wenn deine Trefferchance schon an der Grenze ist, dann bringt ein Item mit nur Trefferwertung 0 %
  und steht nicht als Upgrade da.
- Wenn du im Kampf über ein Item fährst, dann rechnet Amisia mit dem Stand von vor dem Kampf und
  zeigt keinen Fehler.
- Wenn du "Warum?" bei einem Item klickst, dann stehen dort deine Ausgangswerte (z. B.
  Angriffskraft, Krit, Treffer) und was sich durch den Tausch ändert.

## Sonderfälle

- **Bosskampf/geheime Werte:** im Kampf wird nichts gelesen; es gilt der letzte Stand. Ist noch nie
  einer gelesen worden, rechnet Amisia wie bisher mit den Referenzgewichten und schreibt "(ungefähr)".
- **Buffs:** der Stand ist der Bogen mit den Buffs, die gerade wirken. Ein Wechsel der Buffs allein
  löst kein neues Lesen aus, damit die Zahl nicht flackert.
- **Gestaltwandel (Druide):** gelesen wird nur in Normalgestalt bzw. in der Gestalt, die zur
  Spezialisierung passt (Bär/Katze); sonst gilt der letzte passende Stand.
- **Leerer Slot:** "Upgrade für dich (…): +x,x % Schaden (Rücken, Platz leer)", mit Prozent, weil die
  Gesamtleistung nie null ist.
- **Item über deiner Stufe:** wie bisher "ab Stufe N", gerechnet mit deinem heutigen Stand.
- **Spezialisierung gewählt statt geraten:** gilt die gewählte; sie steht ohne "(geraten)" da.
- **Twinks:** jeder Charakter hat seinen eigenen Stand; nichts wird zwischen ihnen geteilt.
- **Englischer Client:** die neuen Texte kommen in `Locales/enUS_*.lua`.

## Missbrauch/Vertrauen

Die eigene Rechnung betrifft nur dich. Was andere davon sehen, ist die Antwort auf "Wer braucht das?":
die Zahl kommt wie bisher nur vom Absender, den der Server setzt, und bleibt gedeckelt. Wer seine
Zahl fälschen will, kann das heute schon; die Lootleitung entscheidet weiter selbst.

## Daten

- Kein neuer `AmisiaDB`-Schlüssel nötig: der Stand des Charakterbogens lebt nur im Speicher und wird
  nach dem Login neu gelesen. (Soll er `/reload` überstehen, wäre das ein Schlüssel unter
  `AmisiaDB.bis.chars[...]`; Vorschlag: nicht nötig.)
- Einstellung "Upgrade erst ab (Prozent mehr Wertung)" (`bis.minGain`) zählt künftig in Prozent der
  Gesamtleistung; die Voreinstellung sinkt von 2 % auf 0,3 % (siehe Frage 3).
- Neue Einstellung `bis.otherSpecs` (Schalter, an): die Zeile der anderen Spezialisierungen mit Shift.
- `GearWeights.lua` bekommt die Modell-Parameter je Spezialisierung (die `SPECS` aus `build_bis.py`)
  und die Umrechnungen je Stufe, damit Lua dasselbe Modell rechnet. `tools/tests/test_score_parity.py`
  hält Python und Lua gleich, jetzt auch für das Vorher/Nachher-Modell.
- "Wer braucht das?" (siehe Frage 4): die Antwort bekommt die Gesamt-Prozent in Zehnteln dazu; das
  Format kommt in `docs/ARCHITECTURE.md`.

## Offene Fragen

1. **Welche Zahl steht vorn?** Vorschlag: Prozent deiner Gesamtleistung vorn, Slot-Prozent nur mit
   Shift. Alternative: beides immer ("+1,6 % Schaden · Slot +122 %").
2. **Andere Spezialisierungen:** Vorschlag: mit Shift eine Zeile mit allen anderen Spezialisierungen
   der Klasse. Alternative: immer zeigen, oder gar nicht.
3. **Schwelle "Upgrade erst ab":** Vorschlag: 0,3 % der Gesamtleistung als Voreinstellung (bei
   deinem Beispiel wäre der Umhang klar drüber, ein Ring mit +1 Ausdauer nicht).
4. **"Wer braucht das?" und Würfel-Fenster:** Vorschlag: auch dort die Gesamt-Prozent, weil sie
   zwischen Spielern fairer vergleichbar sind (ein schwacher alter Umhang bläht die Slot-Zahl auf).
   Ältere Amisia-Versionen im Raid schicken weiter Slot-Prozent; die Liste der Lootleitung markiert
   diese Antworten mit "(alt)". Alternative: dort bleibt die Slot-Zahl.
5. **Verzauberungen:** Vorschlag: beide Items ohne Verzauberung vergleichen (die Verzauberung machst du
   neu oder sie bleibt am alten Item); Shift nennt, was am alten Item verloren ginge. Alternative: die
   Verzauberung des alten Items zählt als Verlust mit.

## Entscheidungen

Noch keine.
