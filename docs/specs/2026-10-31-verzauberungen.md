# Spec: Verzauberungs-Vorschläge je Slot

Stand: 2026-10-31 · Status: freigegeben ·
Feature: F-128

## Ziel

Der Ausrüstungsplaner sagt heute, welches Item in einen Slot gehört, aber nicht, was darauf soll. Der
Raid-Check und der Filter "Ohne Verzauberung" (F-113) zeigen nur, dass etwas fehlt. Gelöst ist es, wenn
ein Spieler zu jedem verzauberbaren Slot sieht, was gerade drauf ist, was für seine Spezialisierung am
meisten bringt, wo er es herbekommt und wer in der Gilde es machen kann.

## Was es tut

- **Fenster Ausrüstungsziele, rechte Spalte des gewählten Slots:** ein neuer Abschnitt "Verzauberung".
  - Oben: was auf dem getragenen Item ist ("Keine" in Rot, wenn nichts drauf ist).
  - Darunter die besten passenden Verzauberungen für die eigene Spezialisierung, mit dem Gewinn gegen die
    jetzige Verzauberung in %, gerechnet wie die Upgrades (F-115, `ns.BisStatsChange` mit dem Modell der
    Upgrades). Fünf Zeilen sind zu sehen, das Mausrad zeigt die übrigen (gebaut so statt "Alle zeigen":
    die Spalte hat keinen Platz für mehr Zeilen; das Fenster wird dafür 76 px höher).
  - Jede Zeile: Name und Gewinn (oder "ab N" in Grau, wenn das Item eine höhere Stufe braucht).
    Quellen: Rezept der Verzauberkunst oder Ingenieurskunst (mit Fertigkeit und woher das Rezept kommt)
    oder ein Item (Rüstungsset, Zielfernrohr, Schriftrolle, Arkanum usw.).
  - Tooltip der Zeile: Werte (z. B. "+3 Beweglichkeit"), Quelle, Mindeststufe, Reagenzien mit
    "in der Tasche: N" und die Gildenmitglieder, die das Rezept kennen oder das Item herstellen
    (aus dem Austausch "Wer kann was herstellen", F-035).
  - Klick: Kartenziel auf die Quelle, wenn sie einen Ort hat (Lehrer, Händler); Shift: Chatlink des
    Rezepts bzw. Items.
- **Karte "Upgrades: <Slot>" am Charakterfenster (F-125):** eine Zeile über der Liste: "Verzauberung:
  <jetzt> · besser: <Name> (+x,x %)". Ein Klick öffnet das Fenster Ausrüstungsziele auf diesem Slot.
- **Neue Daten:** `Data/EnchantData.lua` aus den Client-Tabellen, gebaut von `build.py data`.

## Was es ausdrücklich nicht tut

- **Keine zeitweiligen Verzauberungen:** Öle, Wetzsteine, Gifte, Schamanen-Waffenzauber (Frage 2).
- **Nichts senden:** keine Anfrage an Verzauberer, kein Flüstern, keine neue Addon-Nachricht. Wer es kann,
  steht im Tooltip; anschreiben macht der Spieler selbst.
- **Kein Auktionshauspreis** und kein Kaufen.
- **Keine Verzauberung beim Bewerten der Items:** Die Upgrades vergleichen weiter die Werte der Items
  selbst (eine Verzauberung auf dem getragenen Item zählt dort nicht). Die Verzauberung ist ein eigener
  Vorschlag.
- **Kein Vorschlag für die Ziel-Items** (das, was man erst noch holen will): nur für das getragene Item
  (Frage 4).
- **Nicht auf TBC/Era** (Forever-Teil, D-57).

## Abläufe

1. Der Spieler öffnet das Fenster Ausrüstungsziele und klickt den Slot "Brust".
2. Rechts steht unter dem Ranking "Verzauberung: Keine" und darunter z. B. "Brust - Großartige Werte
   (+3 alle Werte) +1,8 % · Verzauberkunst 245 · Rezept: Händler in ...". Der Tooltip nennt die
   Reagenzien und "Können: Anna, Bert".
3. Er klickt die Zeile, die Karte zeigt den Weg zum Händler des Rezepts; oder er schreibt Anna selbst an.
4. Am Charakterfenster: Rechtsklick auf den Handschuh-Slot, die Karte zeigt oben "Verzauberung: +5
   Bergbau · besser: Handschuhe - Beweglichkeit (+2,4 %)".

## Abnahmekriterien

- Wenn du im Fenster Ausrüstungsziele einen Slot mit einem unverzauberten Item wählst, dann steht rechts
  "Verzauberung: Keine" in Rot und darunter höchstens fünf passende Verzauberungen, die mit dem größten
  Gewinn für deine Spezialisierung zuerst.
- Wenn das getragene Item verzaubert ist, dann steht der Name der Verzauberung oben, und jede Zeile darunter
  zeigt den Gewinn gegen diese; ist nichts besser, steht dort "Du hast schon die beste".
- Wenn du mit der Maus über eine Zeile fährst, dann nennt der Tooltip Quelle, Mindeststufe, Reagenzien mit
  der Zahl in deinen Taschen und die Gildenmitglieder, die das Rezept kennen (braucht: Gilde).
- Wenn du einen Slot ohne mögliche Verzauberung wählst (Ring, Schmuck, Hals), dann gibt es keinen
  Abschnitt "Verzauberung".
- Wenn du mit Alt + Rechtsklick die Karte eines Slots am Charakterfenster öffnest, dann steht oben die
  Zeile "Verzauberung: ..."; ein Klick darauf öffnet das Fenster Ausrüstungsziele auf diesem Slot.

## Sonderfälle

- **Welche Items passen:** nach `SpellEquippedItems` (Klasse, Unterklasse, Slot): Zweihand-Verzauberungen
  nur auf Zweihändern, Zielfernrohre nur auf Fernkampfwaffen, Schild-Verzauberungen nur auf Schilden.
- **Werte, die mit der Stufe skalieren** (Forever-Rüstungssets "Ausdauer +$k2 und Rüstung +$k1"): Kann
  der Build die Zahl nicht sicher ausrechnen, steht die Zeile ohne % am Ende der Liste.
- **Effekte ohne Werte** (z. B. Kreuzfahrer, Feuerwaffe, Lebensdiebstahl): ohne %, am Ende, mit dem
  Effekt-Text.
- **Mindeststufe:** Was das Item oder die Verzauberung erst ab einer höheren Stufe erlaubt, steht grau mit
  "ab Stufe N".
- **Client auf Englisch:** Namen aus den Client-Tabellen (deutsche Daten, englische Texte über die
  Spielfunktionen wo vorhanden, wie bei Rezepten).
- **Bosskampf:** Nichts liest geheime Werte; das Fenster rechnet nur auf Klick.
- **Zwei Waffen, Off-Hand:** jede Hand ihr eigener Slot; die Off-Hand mit Schild bekommt Schild-
  Verzauberungen.

## Missbrauch/Vertrauen

Nichts Neues wird gesendet oder empfangen. Die Namen der Hersteller kommen aus dem bestehenden Austausch
(Crafters) mit dessen Prüfungen; sie sind nur eine Anzeige.

## Daten

- **Neu:** `Amisia/Data/EnchantData.lua` mit `[AllowLoadGameType camelot]` (auch nicht in den TOCs für
  TBC/Era), gelesen über `ns.Data("ENCHANT")`. Gebaut von `tools/build_enchants.py`, aufgerufen von
  `build.py data`, aus `SpellEffect` (Effekt 53: Item verzaubern), `SpellItemEnchantment`,
  `SpellEquippedItems`, `SkillLineAbility`, `ItemEffect`/`ItemXItemEffect`, `ItemSparse`, `SpellName`,
  `SpellReagents`. Alle Tabellen kommen schon aus `export_db2.ps1`; nichts wird heruntergeladen (D-03).
- Kein neuer `AmisiaDB`-Schlüssel, keine Nachricht, keine Exportzeile.
- `docs/ARCHITECTURE.md`: die neue Datei in der Modulliste und der Builder bei `build.py data`.

## Offene Fragen

1. **Wo anzeigen:** nur im Fenster Ausrüstungsziele und in der Karte am Charakterfenster (Vorschlag), oder
   auch ein kleines Feld neben jedem Slot auf der Seite Ausrüstung?
2. **Zeitweilige Verzauberungen** (Öle, Wetzsteine): weglassen (Vorschlag), weil sie Verbrauch sind und in
   den Raid-Check gehören, oder mit aufnehmen?
3. **Was nicht erreichbar ist** (seltene Rezepte aus Raids, falsche Fraktion): zeigen, aber mit Quelle und
   grau, wenn die Stufe fehlt (Vorschlag), oder ganz ausblenden?
4. **Ziel-Items:** Nur für das getragene Item (Vorschlag), oder auch für das geplante Ziel-Item eines
   Slots?
5. **Abschalten:** eine Einstellung "Verzauberungen vorschlagen" (Ausrüstung, an)? Vorschlag: nein, der
   Abschnitt stört nicht und braucht dann keinen neuen Schlüssel.

## Entscheidungen

- 2026-10-31: alle fünf Fragen: "Passt" -> die Vorschläge gelten: (1) nur Fenster Ausrüstungsziele und
  Karte am Charakterfenster; (2) keine zeitweiligen Verzauberungen; (3) nicht Erreichbares grau mit
  "ab Stufe N" zeigen; (4) nur für das getragene Item; (5) keine eigene Einstellung.
