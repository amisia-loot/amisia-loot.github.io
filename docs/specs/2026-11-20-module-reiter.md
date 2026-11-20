# Spec: Ein Modul je Reiter (Ausrüstung, Dungeons & Raids, Talente), Rest im Kern

Stand: 2026-11-20 · Status: freigegeben ·
Feature: F-228

## Ziel

Heute hat Amisia drei Teile (F-202, D-130): Kern, Raid und "Ausrüstung & Dungeons". Der Nutzer will die
Reiter **Ausrüstung**, **Dungeons & Raids** und **Talente** je als eigenes Modul an- und abhaken können;
**Berufe**, **Raid** und **Gilde** sollen immer da sein, also im Hauptaddon `Amisia` stecken. Gelöst ist es,
wenn jedes der drei Module einzeln abgehakt werden kann, ohne dass ein Lua-Fehler kommt oder ein anderer
Reiter fehlt, und nach dem Wiederanhaken alles noch da ist.

## Was es tut

In der AddOn-Liste stehen danach vier statt drei Einträge:

- **Amisia** (Kern, alle Clients): alles von heute, dazu
  - der ganze Raid-Teil von `Amisia_Raid` (der Ordner entfällt; läuft weiter auf Forever, TBC und Era);
  - nur auf Forever (Zeilen mit `[AllowLoadGameType camelot]` in der Kern-TOC, wie vor D-130):
    **Berufe** (Berufe, Berufsroute, Lehrer, Handwerker, Magierschriftrollen), die Forever-Teile von
    **Gilde** (Layer, Duelle, Werkzeuge/Scans), das **Sammeln** (Scan, Drop-Austausch, Quest-XP,
    Quest-Merkmale) und die Daten, die mehrere Reiter lesen: `GearData` (Items und Quellen),
    `ScanDone`/`ScanLists`/`ScanNames`, `ProfessionData`, `MageScrollData`, `RaidCheckData`, `RaidBuffData`.
- **Amisia: Ausrüstung** (Ordner `Amisia_Gear`, bleibt, nur Forever): Ausrüstungsplaner, Ausrüstung mit
  Sets und Ruf, BiS-Bewertung, Gewichte, Spielstil, Verzauberungen, Vergleich, Ziele, Gildenwünsche, Items
  ohne Quelle; Daten `GearWeights`, `BisData`, `GearNoSource`, `EnchantData`.
- **Amisia: Dungeons & Raids** (neuer Ordner `Amisia_Dungeons`, nur Forever): Dungeons, Raids (Journal),
  Quests, Karte, Routen, Läufe, Bestzeiten, Speedrun-Timer, Dungeon-Leiste, Dungeon-Notiz, Gruppen-Queststatus,
  Questgegenstände, Questgeber auf der Karte; Daten `DungeonData`, `DungeonQuestData`, `QuestData`,
  `QuestItemData`, `MapData`, `DungeonArt`.
- **Amisia: Talente** (neuer Ordner `Amisia_Talents`, nur Forever): Talente, Talentrechner, Talent-Links;
  Daten `TalentData`.

Einstellungen, Abschnitt "Module" und `/amisia module` zeigen die drei Module (statt Raid und
Ausrüstung & Dungeons). Fehlt ein Modul, fehlt sein Reiter samt Seiten, Karten, Einstellungen und Befehlen.

## Was es ausdrücklich nicht tut

- Kein Modul für Berufe, Raid oder Gilde: die bleiben fest im Kern (Wunsch des Nutzers).
- Keine eigenen SavedVariables, kein LoadOnDemand, keine Änderung an Nachrichten, Export, Website oder
  Funktionen (wie F-202). `AmisiaDB` bleibt wie es ist.
- Keine Ersatz-Bewertung in Dungeons & Raids, wenn Ausrüstung fehlt: dann gibt es dort eben keine Upgrades.

## Abläufe

1. Spieler hakt "Amisia: Talente" ab und loggt ein: der Reiter Talente fehlt, alles andere wie vorher.
2. Spieler hakt "Amisia: Ausrüstung" ab: der Reiter Ausrüstung fehlt. Dungeons & Raids zeigt Bosse, Beute,
   Quests, Karte und Läufe, aber keine Spalten/Texte "Upgrades", "je Lauf", "Wert", keine Sortierung "Wert",
   keinen Spielstil-Wähler, keinen BiS-Stern; "Nächster Dungeon" nur nach Stufe. Auf der Raid-Übersicht fehlt
   die Karte "Deine Ausrüstung".
3. Spieler hakt "Amisia: Dungeons & Raids" ab: der Reiter fehlt; im Planer fehlt bei Quellen der Knopf "auf
   der Karte zeigen".
4. Wieder anhaken: Ziele, Wünsche, Routen, Bestzeiten, Talentpläne sind unverändert da.

Technisch, in Schritten, jeder mit `build.py check` grün:

1. **Raid in den Kern:** `Amisia_Raid/*` nach `Amisia/` (Pfade bleiben gleich, `Raid/Module.lua` entfällt,
   `ns.HasModule("raid")` ist immer wahr). Der Raid-Check findet seine Daten im Kern.
2. **Berufe, Gilde, Sammeln, gemeinsame Daten in den Kern** (Forever-Zeilen der Kern-TOC). Heute rufen sie
   Ausrüstung an 1 Stelle und Dungeons an 2 Stellen auf; die werden geprüft.
3. **Talente nach `Amisia_Talents`:** es gibt keinen einzigen Aufruf über die Grenze.
4. **Dungeons & Raids nach `Amisia_Dungeons`:** es ruft Ausrüstung an rund 120 Stellen auf (`ns.Gear`,
   `ns.GearPageKit` mit Item-Text, Tooltip, Menü, Spielstil-Wähler, `ns.Bis*`, Wünsche). Was nur Anzeige ist
   (Item-Text, Tooltip, Klick, Menü), zieht in den Kern; der Rest bekommt Prüfungen. Ausrüstung ruft die
   Karte an 8 Stellen auf, auch die werden geprüft.
5. **Weg ins Spiel:** `tools/modules.py` (Teile core, gear, dungeons, talents; Reihenfolge Kern, Ausrüstung,
   Dungeons, Talente), TOCs, Datenbauer (`build.py data` schreibt jede `Data/*` in den Ordner ihres Teils),
   `tools/release_addon.sh`, `tools/install_junctions.ps1`, `Amisia.zip`, die Locale-Dateien je Ordner,
   `tests/ui_scene.lua` je ein Lauf "ohne Ausrüstung", "ohne Dungeons", "ohne Talente".

## Abnahmekriterien

- Wenn du "Amisia: Ausrüstung" abhakst und einloggst, dann kommt kein Lua-Fehler, der Reiter Ausrüstung fehlt
  und Dungeons & Raids zeigt Bosse, Beute und Quests ohne Upgrade-Angaben.
- Wenn du "Amisia: Dungeons & Raids" abhakst, dann laufen Ausrüstungsplaner, Berufe, Talente, Raid und Gilde
  ohne Lua-Fehler.
- Wenn du "Amisia: Talente" abhakst, dann fehlt nur der Reiter Talente.
- Wenn du alle drei Module abhakst, dann sind Berufe, Raid und Gilde (mit Layer, Duellen, Werkzeugen) da, und
  im Raid zeichnet Amisia auf.
- Wenn du auf TBC Anniversary einloggst, dann laden Kern und Raid wie bisher; Berufe und die drei Module
  fehlen ohne Fehler, und es gibt keinen "Amisia: Raid"-Eintrag mehr.

## Sonderfälle

- **Update bei bestehenden Spielern:** Der Ordner `Amisia_Raid` muss weg. Bleibt er liegen (Hand-Update),
  würden Raid-Dateien zweimal laden: der Kern erkennt einen geladenen `Amisia_Raid` und meldet einmal im
  Chat "bitte den Ordner Amisia_Raid löschen"; der alte `Raid/Module.lua` tut ohne Gegenstück nichts.
  Am PC löscht das Skript die alte Verknüpfung und legt `Amisia_Dungeons` und `Amisia_Talents` an.
- **War "Raid" oder "Ausrüstung & Dungeons" abgehakt:** Raid ist jetzt immer an. Die neuen Module lädt WoW
  angehakt; wer vorher Ausrüstung & Dungeons aus hatte, hakt danach drei Module ab.
- **Versionsruf (Feld `m`):** neu die Buchstaben `g`, `d`, `t`; `r` steht immer. Ältere Versionen mit `g`
  zählen als `gdt`.
- **Einstellungen eines fehlenden Moduls** bleiben in `AmisiaDB` stehen (D-130 gilt weiter).
- **Sammel-Einstellungen**, die heute unter Dungeons & Raids stehen, bleiben sichtbar, wenn das Modul fehlt.

## Missbrauch/Vertrauen

Nichts Neues. Der Versionsruf verrät nur, welche Module jemand nutzt.

## Daten

- Keine neuen `AmisiaDB`-Schlüssel, keine neue Nachrichtenart; im Versionsruf neue Werte im Feld `m`.
- `docs/ARCHITECTURE.md`: Ordner, TOCs, Modulgrenzen, Maschinen. DECISIONS: neue Entscheidung, die D-130
  ändert (vier Teile statt drei, Raid im Kern). `CLAUDE.md`: Ordnerliste.

## Offene Fragen

1. **Ordnernamen:** `Amisia_Gear` bleibt (Ausrüstung, Verknüpfung am PC bleibt), neu `Amisia_Dungeons`
   und `Amisia_Talents`. Vorschlag: so.
2. **Sammeln (Scan, Drop-Austausch) in den Kern?** Es füllt Daten für alle Reiter und die Gilde-Seite
   Werkzeuge braucht es. Vorschlag: ja.
3. **Raid-Übersicht "Deine Ausrüstung":** ohne Ausrüstungs-Modul fehlt die Karte einfach. Vorschlag: so.
4. **Reihenfolge:** die fünf Schritte oben nacheinander, jeder ein Commit; ein Release erst nach Schritt 5.
   Vorschlag: ja.

## Entscheidungen

Beim Bauen (2026-11-20) zusätzlich in den Kern, weil mehrere Teile sie lesen: `Data/DungeonData.lua` (Raid-IDs,
Gilden-Aufrufe), `Data/BisData.lua` (Bosse, Encounter, Grundstock der Drops), `Data/DungeonQuestData.lua` (der
Sammler), `Data/GearWeights.lua` und die Item-Bibliothek `Gear/Gear.lua` (Items, Quellen, Werte) sowie die
Anzeige der Item-Zeilen `UI/ItemKit.lua`; so braucht Dungeons & Raids ohne Ausrüstung nur rund 25 Prüfungen statt
120. Alles nur auf Forever (DECISIONS D-158).

- 2026-11-20: Nutzer: "können wir amisia ausrüstungs tab 1 modular dungeonsund raids 1 modular", "talente
  auch", "berufe Raid und Gilde Tab soll in Amisia Main immer sein" -> drei Module, Rest im Kern.
- 2026-11-20: "Läuft auch allein" -> Dungeons & Raids läuft ohne Ausrüstung, nur ohne Upgrades.
- 2026-11-20: Raid: zuerst "Eigenes Addon lassen", dann zur Raid-Seite "das soll in amisia main sein" ->
  Raid zieht in den Kern, `Amisia_Raid` entfällt.
- 2026-11-20: Fragen 1 bis 4 und Spec: "Passt, bauen" -> alle Vorschläge so.
