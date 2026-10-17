# Spec: Fenster "Ausrüstungsziele" (Puppe, Wertung, Slot-Leiste, Fortschritt)

Stand: 2026-10-17 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-110 (A, Fenster mit Puppe), F-111 (B, Wertungs-Kopf), F-112 (C, Slot-Leiste und eigene Wahl),
F-113 (D, Fortschritt und Filter)

Anstoß: der Nutzer hat am 2026-10-17 die BiS-Liste eines anderen Addons gezeigt ("können wir sowas auch
einbauen"): links Charaktermodell mit den Slots drumherum und Umschalter "BiS/Jetzt", darunter eine
Wertung mit Balken und Wertänderungen, in der Mitte die Liste je Slot mit Fortschritt und Filtern, rechts
pro Slot eine Rangliste mit eigener Wahl und Dungeon-Drops. Nach D-05 heißt es hier nur "ein anderes
Addon"; Code und Namen (auch der Name seiner Wertung) werden nicht übernommen. Was Amisia davon schon
hat: Seite Ausrüstung, Ansicht Ziele (bestes Item je Slot nach eigener Wertung, D-11, mit Quelle,
Zuwachs, drei Optionen, "Warum?", Ausschließen, Wunsch, Waffenplan), BiS-Empfehlungen (D-09), Hier,
Simulation, Dungeon-Rangliste, Karte mit Pins, Anprobe per Strg-Klick.

Vier Teile, gebaut in der Reihenfolge A → D → C → B (A ist das Gerüst, das die anderen brauchen).
Zwei weitere Teile kommen später mit eigenem Nachtrag zu dieser Spec: **E "Als Nächstes"** (der eine
nächste Schritt: Dungeon mit den meisten Upgrades, ein Rezept, eine Quest, mit Wegpunkt) und
**F "Liste teilen"** (Ziele als Code kopieren und einfügen, wie der Talent-Code; braucht einen eigenen
Abschnitt "Missbrauch/Vertrauen" für eingefügten Text).

## Ziel

Ein Blick zeigt, wo der Charakter mit seiner Ausrüstung steht: was er anhat, was das Ziel je Slot ist,
wie viel besser er damit wäre und was ihm noch fehlt. Der Spieler kann das Ziel eines Slots selbst
wählen, statt nur Vorschläge auszuschließen. Gelöst, wenn der Spieler seine Ziele ohne Chat-Befehle und
ohne zwischen Ziele, Hier und Simulation zu springen planen kann.

## Was es tut

### A: Fenster mit Puppe (F-110)

- Neues Fenster **"Ausrüstungsziele"** (en "Gear Goals", `AmisiaGoalsFrame`), etwa 940 × 600 bei 100 %,
  im Stil des Fensters "Talentrechner" (PortraitFrameTemplate, D-06). Öffnen: auf der Seite Ausrüstung,
  Ansicht Ziele, Knopf "Großes Fenster"; `/amisia bis gross` (en `/amisia bis big`); ein Reiter rechts am
  Amisia-Fenster (markiert, solange das Fenster offen ist). Größe über die neue Einstellung
  "Größe des Zielefensters (%)" (70 bis 150) und Strg + Mausrad wie beim Talentfenster.
- Kopfzeile: die Spezialisierungs-Chips der Seite (eine Wahl für Seite, Fenster und Dungeons,
  `ns.BisSetSpec`), der Waffenplan als Text ("Waffen: Zweihand"), "Warum?" wie auf der Seite.
- **Linke Spalte, die Puppe:** ein 3D-Modell des eigenen Charakters (`DressUpModel`), links davon Kopf,
  Hals, Schultern, Rücken, Brust, Handgelenke; rechts Hände, Taille, Beine, Füße, Finger, Finger,
  Schmuck, Schmuck; darunter Waffenhand, Schildhand, Distanz (die 17 Slots von `Gear.SLOTS`, angeordnet
  wie im Charakterfenster). Jeder Slot ist ein 36-px-Knopf mit dem Item-Symbol im Rahmen der
  Qualitätsfarbe, leer mit dem Slot-Bild des Charakterfensters; ein Punkt unten rechts zeigt den Stand
  des Ziels (grün angelegt, gelb in Tasche oder Bank, kein Punkt: noch zu holen).
- Umschalter unter dem Modell: **"Ziele"** (Modell und Slots zeigen die Ziele, Slots ohne Ziel das
  Angelegte) und **"Angelegt"** (das, was du trägst). Ziehen dreht das Modell, Mausrad zoomt,
  Rechtsklick setzt zurück; die Zeile darunter sagt das.
- Slot-Knopf: Tooltip des gezeigten Items mit der Amisia-Zeile ("Upgrade für dich ..."), Klick wählt den
  Slot (Teil C), Strg-Klick Anprobe, Shift-Klick Link in den Chat.
- **Mittlere Spalte, die Liste:** Abschnitte "Rüstung" (10 Slots), "Schmuck" (Hals, 2 Finger, 2 Schmuck)
  und "Waffen" (3), je Zeile Slot, Item (Symbol + Name in Qualitätsfarbe, Abzeichen "BiS-Empfehlung"
  oder Stern für die eigene Wahl), Zuwachs ("+10 %", grün; angelegt: "angelegt") und Quelle (wie auf
  der Seite, mit dem Karten-Knopf). Klick wählt den Slot, die gewählte Zeile leuchtet wie ein gewähltes
  Rezept; Rechtsklick das Menü der Seite (Ausschließen, Boss/Ort ausschließen, Wunsch, Karte).
- Die Seite Ziele bleibt, wie sie ist (für kleine Bildschirme und den Raider-Alltag); Fenster und Seite
  zeigen dieselben Daten (`ns.BisTargets`).

### B: Wertungs-Kopf (F-111)

Unter der Puppe:

- groß **"Wertung 18,6"** mit deinen Zielen, daneben klein "jetzt 17,2" und grün "+1,4" (die Summe der
  Wertungen je Slot, dieselbe Zahl wie die Spalte "Wertung" der Seite; Zweihand zählt einmal);
- ein Balken von 0 bis **"Bestes auf Stufe 30: 26,7"** (das Ergebnis der Simulation für deine Klasse,
  Spezialisierung und Stufe mit allen Quellen an, ohne Ausschlüsse und ohne eigene Wahl), darin ein
  Strich für "jetzt" und die Füllung bis "mit Zielen"; Tooltip: was "Bestes" heißt;
- bis zu sechs Wertänderungen Ziele gegen Angelegt in zwei Spalten, nach Gewicht sortiert, grün oder rot
  ("Intelligenz +9", "Trefferchance +1 %", "Zaubermacht −9"); der Tooltip zeigt alle. Werte, die die
  Wertung nicht zählt, fehlen; Anlegen-Effekte stehen wie auf der Seite als "Effekt nicht gewertet".

### C: Slot-Leiste und eigene Wahl (F-112)

Rechte Spalte, für den gewählten Slot (ohne Wahl: der erste Slot mit Upgrade):

- Kopf "Kopf · Feuer-Magier" (Slot und Spezialisierung).
- **"Deine Wahl"**: das selbst gewählte Ziel mit Stern, Quelle und rotem X zum Entfernen; ohne Wahl
  "Keine eigene Wahl: Amisia nimmt das Beste." Die eigene Wahl ist das Ziel dieses Slots auf Seite,
  Fenster, Karte, Hier und in der Dungeon-Rangliste; sie schlägt die BiS-Empfehlung.
- **"Rangliste für Feuer-Magier · N"**: die zehn besten Items des Slots nach Amisias Wertung (aus
  `Gear.Best`, mit deinen Quellen und Ausschlüssen), je Zeile Rang, Symbol, Name, Quelle, Zuwachs,
  Stern bei der eigenen Wahl, "hast du" bei Besitz. Klick macht die Zeile zur eigenen Wahl (noch einmal:
  Wahl weg), Rechtsklick das Menü, Strg-Klick Anprobe.
- **"Dungeon-Drops nahe deiner Stufe"**: bis zu drei Items dieses Slots aus Dungeons, deren Levelbereich
  zu deiner Stufe passt (aus der Dungeon-Rangliste), mit Boss und Dungeon; "Alle zeigen" öffnet die Seite
  Dungeons.
- unten ein Feld **"Item-Link oder ID"** mit "Hinzufügen": ein Item, das in den Slot passt und das deine
  Klasse tragen kann, wird eigene Wahl, auch wenn es in den Daten fehlt (dann mit den Werten, die der
  Client kennt, Quelle "unbekannt"). Shift-Klick auf einen Link setzt ihn ins Feld.
- **Überholt:** Ist die eigene Wahl angelegt und das beste Item der Rangliste um mindestens
  "Upgrade erst ab" (`bis.minGain`) besser, steht unter der Wahl "Überholt: <Item> ist +N % besser" mit
  "Übernehmen"; Amisia ändert die Wahl nie selbst.

### D: Fortschritt und Filter (F-113)

Über der Liste:

- "**3/17** Ziele hast du" und ein Balken aus 17 Teilen (grün angelegt, gelb in Tasche/Bank, grau noch
  zu holen, dunkel ohne Ziel); die Abschnitte der Liste sagen "Rüstung 2 von 10 hast du".
- Filter-Chips **Alle · Zu holen N · In der Tasche N · Ohne Verzauberung N**: "In der Tasche" sind Ziele
  in Tasche oder Bank, nicht angelegt; "Ohne Verzauberung" sind angelegte Items in verzauberbaren Slots
  ohne Verzauberung (dieselbe Prüfung wie der Raid-Check, F-098). Nur der Hinweis, keine Empfehlung,
  welche Verzauberung. Der Filter gilt nur der Liste; die Puppe zeigt immer alle Slots.

## Was es ausdrücklich nicht tut

- Keine fremden BiS-Listen, keine fremde Wertung, kein Name einer fremden Wertung (D-05, D-11). Die Zahl
  ist Amisias Wertung.
- Keine Empfehlung von Verzauberungen (bräuchte eigene Daten; wäre ein späterer Teil).
- Kein Teilen und Einfügen von Listen (Teil F, später), kein "Als Nächstes" (Teil E, später).
- Keine Gegenstände per Wowhead-Adresse im Feld (nur Item-Link oder Zahl; D-02, D-03).
- Nichts wird gesendet; die eigene Wahl sehen andere Spieler nicht (auch nicht "Wer braucht das?").
- Die Ansicht Ziele der Seite wird nicht umgebaut und nicht ersetzt.
- Kein Anlegen von Items aus dem Fenster (das Ausrüstungsset bleibt Sache des Spielers).

## Abläufe

1. Spieler (Stufe 30, Feuer-Magier) öffnet Ausrüstung → Ziele → "Großes Fenster". Das Fenster zeigt das
   Modell in seinen Zielen, links und rechts die Slots, darunter "Wertung 18,6 · jetzt 17,2 +1,4".
2. Er klickt auf "Angelegt": Modell und Slots zeigen seine jetzige Ausrüstung. Zurück auf "Ziele".
3. Er klickt den Kopf-Slot. Rechts steht die Rangliste mit zehn Kopfteilen. Er klickt Platz 3, weil er
   Schneider ist: Platz 3 trägt den Stern, die Zeile Kopf in der Liste zeigt es mit Stern, Wertung und
   Balken rechnen neu, die Karte zeigt den Pin des neuen Ziels.
4. Er wählt den Filter "Zu holen": die Liste zeigt nur die Slots, deren Ziel er noch nicht hat.
5. Später trägt er das Kopfteil; der Punkt am Slot wird grün, "4/17". Mit Stufe 40 steht unter der Wahl
   "Überholt: <Item> ist +14 % besser" — er klickt "Übernehmen" oder lässt es.

## Abnahmekriterien

- Wenn du auf der Seite Ausrüstung, Ziele "Großes Fenster" klickst (oder `/amisia bis gross` eingibst),
  dann öffnet sich das Fenster "Ausrüstungsziele" mit deinem Charaktermodell, den 17 Slots links, rechts
  und darunter, der Liste in der Mitte und rechts der Leiste des ersten Slots mit Upgrade.
- Wenn du "Angelegt" wählst, dann tragen Modell und Slots deine jetzige Ausrüstung; mit "Ziele" die Ziele
  (Slots ohne Ziel das Angelegte). Ziehen dreht, Mausrad zoomt, Rechtsklick setzt zurück.
- Wenn du ein Item der Rangliste anklickst, dann trägt es den Stern, ist in der Liste, auf der Seite Ziele
  und als Pin auf der Weltkarte das Ziel dieses Slots, und nach `/reload` noch immer; ein zweiter Klick
  (oder das rote X unter "Deine Wahl") nimmt die Wahl weg.
- Wenn du eine Wahl triffst, dann ändern sich "Wertung", "+N" und die Wertänderungen unter der Puppe; der
  Balken endet bei "Bestes auf Stufe N", das sich durch deine Wahl nicht ändert.
- Wenn du "Zu holen" wählst, dann zeigt die Liste nur Slots mit Ziel, das du nicht hast, der Chip sagt
  die Zahl; "Ohne Verzauberung" zeigt die angelegten Items in Rücken, Brust, Handgelenken, Händen,
  Füßen, Waffen- und Schildhand ohne Verzauberung.
- Wenn du einen Item-Link in das Feld der Leiste ziehst, der nicht in den Slot passt, dann sagt die
  Zeile darunter "Passt nicht in Kopf." und nichts ändert sich.
- Wenn du `/amisia selbsttest` eingibst, dann steht dort eine Zeile "Charaktermodell" (DressUpModel,
  SetUnit, Undress, TryOn: vorhanden oder was fehlt).

## Sonderfälle

- **Kein DressUpModel oder kein TryOn in Forever:** Die Puppe zeigt nur die Slots ohne Modell und den
  Hinweis "Modell nicht verfügbar"; der Rest geht. Deshalb kommt die Selbsttest-Zeile zuerst (kann mit
  dem nächsten Release raus, bevor gebaut wird).
- **Keine Gear-Daten** (`Gear.Available()` falsch, z. B. nicht Forever): Fenster und Knopf fehlen wie die
  Seite; `/amisia bis gross` sagt es im Chat.
- **Items noch nicht im Client:** Symbol mit Fragezeichen und "lädt noch N Items" wie auf der Seite;
  das Modell probiert sie an, sobald sie da sind.
- **Zweihand-Plan:** Schildhand zeigt "Die Zweihandwaffe belegt beide Hände.", zählt im Fortschritt als
  erledigt, wenn die Zweihandwaffe angelegt ist; die Wertung zählt die Zweihandwaffe einmal.
- **Eigene Wahl, die nicht mehr passt** (Spezialisierung gewechselt, Klasse kann sie nicht tragen,
  Waffenplan geändert): die Wahl gilt je Spezialisierung; passt sie zum Plan nicht, bleibt sie gespeichert,
  wird aber nicht genutzt, und die Leiste sagt "Passt nicht zum Waffenplan".
- **Im Kampf / Bosskampf:** das Fenster bleibt bedienbar (nichts Geschütztes); keine geheimen Werte
  beteiligt. Das Modell lädt nicht neu, solange du im Kampf bist und das Fenster zu ist.
- **Twinks:** eigene Wahl und Stand je Charakter (`bis.chars[<Name>]`).
- **Englischer Client:** Spalten und Chips mit `W.FitChip`, Snapshots `--locale enUS`.
- **`/reload`:** Fenster bleibt zu; Platz, Größe, Umschalter und Filter sind gemerkt.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen; nur der Spieler selbst ändert seine Wahl. Das Feld "Item-Link oder
ID" nimmt eingegebenen Text: nur ein Item-Link oder eine Zahl wird gelesen (`ns.ItemID`), sonst
"Kein Item."; das Item muss in den Slot passen und für die Klasse tragbar sein. Höchstens eine Wahl je
Slot und Spezialisierung (17 × 3 Zahlen je Charakter), also kein Wachstum der SavedVariables.

## Daten

- `AmisiaDB.bis.chars[<Name>].pick = { [<Spezialisierung>] = { [<Slot>] = itemID } }` — die eigene Wahl
  (C); `ns.BisMigrate`/`cleanChar` prüft Slot-Schlüssel gegen `Gear.SLOTS` und Zahlen; die Tabelle in
  `docs/ARCHITECTURE.md` (`bis`) bekommt `pick`.
- Einstellung `ui.goalScale` (Schieber 70–150, Standard 100) im Abschnitt Oberfläche neben
  `ui.talentScale` (D-49: keine Einstellung in der Seite).
- `settings.goalWindow` (Platz, Umschalter Ziele/Angelegt, Filter, gewählter Slot) wie
  `settings.talentWindow`.
- Neue Dateien: `Amisia/UI/GoalsWindow.lua` (Fenster, Puppe, Liste, Leiste), Logik für eigene Wahl,
  Wertungssumme, Wertänderungen und Rangliste in `Gear/Bis.lua` (`ns.BisPick`, `ns.BisSetPick`,
  `ns.BisSummary`, `ns.BisRanking`); TOC-Eintrag; Theme-Token `T.GOALS` in `UI/Theme.lua`; Slot-Bilder
  `Interface\PaperDoll\UI-PaperDoll-Slot-*` in `ns.Theme.ATLASES`/der Texturliste.
- Selbsttest-Zeile "Charaktermodell" in `Core/SelfTest.lua`.
- Neue Regel in `docs/DECISIONS.md` (D-54): eigene Wahl schlägt BiS-Empfehlung und Wertung, gilt je
  Spezialisierung, wird nie automatisch geändert, wird nie gesendet.
- Keine Nachrichten, Blob-Arten, Exportzeilen, Einfügeblöcke, kein Website-Zustand.

## Offene Fragen

1. **Eigenes Fenster oder Seite umbauen?** Die Seite ist 602 px breit, zu schmal für Puppe, Liste und
   Leiste nebeneinander. Vorschlag: eigenes Fenster wie der Talentrechner, die Seite Ziele bleibt.
2. **Name?** Vorschlag: "Ausrüstungsziele" (en "Gear Goals"); "BiS-Liste" wäre kürzer, aber "BiS" steht
   bei uns für Empfehlungen (D-09).
3. **Wo gilt die eigene Wahl?** Vorschlag: überall, wo Amisia ein Ziel nutzt (Seite Ziele, Fenster,
   Karten-Pins, Hier, Dungeon-Rangliste, Pfeil); der Tooltip "Upgrade für dich" rechnet weiter nur nach
   der Wertung gegen das Angelegte.
4. **Überholte Wahl beim Leveln:** Vorschlag: Hinweis "Überholt ... Übernehmen" in der Leiste, nie
   automatisch. Alternative: die Wahl fällt weg, sobald du das gewählte Item ablegst.
5. **Modell im Modus "Ziele":** Vorschlag: erst ausziehen, dann alle Ziele und für Slots ohne Ziel das
   Angelegte anprobieren (so sieht man das Ziel-Set, nicht eine Mischung mit altem Kram).
6. **Item außerhalb der Daten im Feld:** Vorschlag: erlaubt, wenn es passt; gewertet mit den Werten, die
   der Client kennt, Quelle "unbekannt", kein Pin.

## Entscheidungen

Noch keine.
