# Amisia 2.3: eigene BiS-Wertung, Dungeon-Planer und Drop-Daten der Gilde

Stand 2026-10-05. Nur WoW Forever 1.60.1 (TOC 16001, Spieltyp `camelot`). Baut auf dem
Ausrüstungsplaner aus 1.3 (`Gear.lua`, `GearData.lua`, `GearWeights.lua`, `tools/build_gear.py`),
dem BiS-Abgleich aus 1.8 (`docs/superpowers/specs/2026-10-05-amisia-bis-design.md`: `Bis.lua`, Ziele,
Hier, Wunschliste, Tooltip-Zeile, erklärte Wertung), der Karte aus 1.9 (`MapData.lua`, Wegpunkte),
dem Umbau auf Forever aus 2.0 (`2026-10-05-amisia-forever-only-design.md`) und der
Nachrichtenschicht aus 2.1 (`2026-10-05-amisia-sync-design.md`: `Comm.lua`, `Trust.lua`, Drosselung,
Sperre, Blob-Pakete) auf. **Folgt dem Restyle** (`docs/superpowers/specs/2026-10-05-amisia-style-design.md`,
parallel entworfen, die Version vor 2.3): dieser Entwurf regelt Daten und Logik; Oberflächen
beschreibt er nur als "welche Ansicht zeigt welche Information", Maße, Farben und Bausteine kommen
aus dem Restyle.

Ändert das Addon `addon/Amisia`, `tools/build_gear.py`, `tools/build_scan.py`, ein neues
Erzeugungsskript `tools/build_bis.py`, die Website `index.html` und `data/`.

## Ziel

Heute rechnet Amisia das beste Item je Slot mit Gewichten, deren DPS-Teil aus einem fremden
Leveling-Guide stammt (CC BY-NC-SA 4.0, aus dessen installierten Dateien auf dem PC gelesen).
Setboni, Waffentempo-Pläne, Zufallsboni ("...des Adlers") und der Aufwand, ein Item zu bekommen,
fehlen. Welcher Dungeon sich gerade lohnt, sagt niemand. Und Loot-Tabellen für Forever gibt es nur,
soweit Quelldaten aus Classic und die eigenen Scans reichen: für sechs der neun neuen Dungeons und
für alle Raids (ab 9.12.2026) fehlen sie.

Nutzer-Vorgabe (2026-10-05): **eine eigene, bessere Version aus allen gefundenen und noch zu
findenden Fakten, keine Kopie einer fremden Seite.** 2.3 bringt:

- **Eigene BiS-Wertung je Levelbereich** für jede Klasse und Spezialisierung: aus echten
  Item-Werten (Scan im Spiel, Client-Tabellen, berechnete Werte für ungescannte Items), mit eigenen,
  hergeleiteten und dokumentierten Gewichten; die drei besten Optionen je Slot mit Quelle. "Besser"
  heißt konkret: erklärte Zahl, Vergleich "warum nicht das andere", Setboni, Waffentempo,
  Waffenplan (Zweihand, zwei Waffen, Waffe und Schild), Questketten und Level, Fraktion, Berufe,
  Zufallsboni mit dem besten bekannten Wurf, Aufwand als Gleichstandsregel.
- **Dungeon-Planer:** je Dungeon (auch die neuen von Forever) die Zahl und Größe der Upgrades für
  den eigenen Charakter auf seinem Level, welche Bosse sie tragen, dazu Questbelohnungen des
  Dungeons; daraus eine Empfehlung "nächster Dungeon".
- **Drop-Daten der Gilde:** der Sammler zeichnet Boss-Kills mit ihrem Loot auf, die Clients der
  Gilde tauschen sie leise aus (2.1-Nachrichtenschicht, niedrige Priorität, gedrosselt), daraus
  entstehen beobachtete Dropraten je Boss. Sie gehen als neue Exportzeilen an die Website, die
  daraus Forever-Loot-Tabellen zeigt, und über den Bau zurück ins Addon. Raids bekommen ihre
  Tabellen ab dem ersten aufgezeichneten Kill von selbst.

## Rahmen und Entscheidungen

- **Client, Bibliotheken, Schrift, Anmeldung:** wie 2.0 und 2.1. Keine fremden Bibliotheken. UI-
  und Chat-Texte deutsch und nur Latin-1 (ä ö ü ß und "·", kein Gedankenstrich, keine
  Auslassungspunkte, keine Pfeile), Code-Kommentare englisch, Texte der Website englisch. Anmeldung
  nur über `ns.RegisterPanel`, `ns.RegisterCard`, `ns.RegisterSettings`, `ns.RegisterSlash`. Werte aus
  Ereignissen gehen durch `ns.Plain`. `C_Item`-Shim wie Core.lua.
- **Keine anderen Addons nennen**, weder in UI-Texten, Chat, Kommentaren, erzeugten Dateien noch
  Commits. Im Entwurf heißen sie "andere Ausrüstungs-Addons". Datenquellen (QuestieDB, OneForAll,
  AtlasLootClassic) werden nur dort genannt, wo ihre Lizenz es verlangt.
- **Keine Links auf fremde Seiten, nirgends.** Weder im Addon (auch nicht als kopierbarer Text) noch
  auf der Website kommen neue Verweise auf Forever-Datenseiten, Guide-Seiten oder Ähnliches dazu.
  Was der Spieler wissen muss, zeigt Amisia selbst. (Die vorhandenen Item-Links der Website auf die
  Item-Datenbank bleiben, wie sie sind; 2.3 fügt keine hinzu.)
- **Keine fremde Kompilation.** Die bekannte Forever-Datenseite verbietet, ihre zusammengestellten
  Daten im Ganzen zu kopieren, und ihre BiS-Ranglisten sind ihre eigene Auswahl; Wowhead sperrt
  Claude-Agenten per robots.txt und verbietet das Abgreifen; wago.tools erlaubt Crawlern nur die
  Startseite. Daraus folgt für 2.3: **kein Abruf durch Skripte**, keine Übernahme fremder BiS-Listen
  oder Loot-Tabellen. Fakten selbst sind nicht geschützt (Level-Bereiche der Dungeons, Bossnamen,
  Raid-Termine); einzelne Nachschläge von Hand im Browser zur Prüfung sind in Ordnung und werden im
  Kopf der Faktendatei mit Datum vermerkt. Primärquellen sind der eigene Client (Scan, Sammler,
  Drop-Aufzeichnung) und die Client-Tabellen, die der Nutzer bei wago.tools **von Hand** als CSV
  herunterlädt (wie heute `--itemsparse`).
- **Eigene Gewichte statt der CC-BY-NC-SA-Gewichte.** Entschieden: die DPS-Gewichte des fremden
  Leveling-Guides fallen weg. Gründe: (1) sie sind nicht erklärbar (keine Herleitung, nur Zahlen),
  (2) `build_gear.py` braucht dafür ein fremdes, installiertes Addon auf dem PC, (3) ShareAlike
  bindet `GearWeights.lua` an deren Lizenz. Behalten wäre rechtlich möglich (Amisia ist kostenlos,
  also nicht-kommerziell, und die Namensnennung steht im Dateikopf), aber eigene Gewichte sind
  besser begründbar. Die neuen Gewichte werden aus Spielmechanik und Client-Tabellen **hergeleitet**,
  nicht an die alten Zahlen angepasst; der alte Satz dient auch nicht als Testorakel. Mit 2.3 steht
  im Kopf von `GearWeights.lua` "Amisia's own weights" und der Hinweis auf CC BY-NC-SA entfällt,
  weil keine Zahl mehr daraus stammt.
- **Eine Wertung, zwei Rechner.** `Gear.lua` rechnet im Spiel (eigener Charakter, alle Filter),
  `tools/build_bis.py` rechnet dieselbe Formel in Python vor (alle Klassen, Specs, Level, für die
  Website und als Startwert im Addon). Ein Test lässt beide über dieselben Items laufen und verlangt
  Gleichheit auf 0,01.
- **Forever-Haltung** wie 1.8: Amisia wertet nur, was jeder Tooltip und das Charakterfenster zeigen,
  liest keine Kampfdaten, nichts während eines Bosskampfs. Dropraten sind **gezählte Beobachtungen**
  der Gilde (Lootfenster, die ein Spieler selbst geöffnet hat), kein Raten versteckter Werte; die
  Anzeige sagt immer, aus wie vielen Kills eine Zahl stammt.
- **Drop-Austausch ist leise, gedeckelt und nie maßgeblich.** Nur Gildenmitglieder (geprüft über
  `ns.IsVerifiedMember`), nur außerhalb von Instanzen, Kampf, Sperre und laufendem Raid-Abgleich,
  niedrigste Priorität in der Schlange, feste Byte- und Teilegrenzen. Daten werden **vereinigt**
  (gleicher Kill zählt einmal), nie überschrieben; kein Client ist Hüter dieser Daten.
- **Keine Spielernamen in Drop-Daten.** Ein Kill trägt eine Kennung aus der Leichen-GUID (ohne
  Spielerbezug) und eine zufällige Client-Kennung als Herkunft, keinen Namen. Exportzeilen und
  Website-Daten enthalten keine Namen.
- **Exportregel** wie 1.8 und 2.1: bestehende Zeilen Byte für Byte gleich, Kopf `#AMISIA 2`, neue
  Zeilenarten mit zwei Buchstaben (`DK`, `DN`, `DZ`). Drop-Daten stehen nicht im Raid-Export, sondern
  in einem eigenen Text "Drops für die Website"; Raid-Export und `ns.SessionHash` ändern sich nicht.
- **Version 2.3.0.** `ns.SYNC_PROTO` bleibt 1 (neue Nachrichtentypen stören alte Clients nicht, sie
  verwerfen unbekannte Typen; siehe Tests). Der Drop-Austausch trägt eine eigene Protokollziffer im
  Feld (`ns.DROP_PROTO = 2`; 1 prüfte nur Kennungen, siehe Austausch).

## Dateien

```
tools/build_bis.py              NEU (N100): Client-Tabellen aus wago-CSV zwischenspeichern, eigene
                                Gewichte herleiten, Werte ungescannter Items berechnen, Setboni,
                                Zufallsboni-Pools, Dungeon-Fakten, Drop-Grundstock, BiS vorrechnen;
                                schreibt GearWeights.lua, BisData.lua, data/bis-forever.js
tools/bis_gamedata.json         NEU, erzeugt: kompakter Auszug der CSVs (nur benutzte Spalten/Zeilen)
tools/forever_dungeons.json     NEU, von Hand: Fakten je Dungeon/Raid (Name, Level, Größe, Instanz-ID
                                sobald bekannt, Quelle und Datum der Prüfung)
tools/drop_obs.json             NEU, erzeugt: Archiv aller je gesehenen Kill-Datensätze (vereinigt)
tools/build_gear.py             ohne fremde Gewichte; D-Quellen mit NPC-ID und Instanz-ID; Questketten
tools/build_scan.py             liest Kill-Datensätze aus SavedVariables und Website-Download, pflegt
                                tools/drop_obs.json, Boss-Tabellen mit Beobachtungen in data/forever.js
tools/forever_zones.json        Dungeons und Raids mit "kind", "instance", Level
addon/Amisia/GearWeights.lua    erzeugt von build_bis.py (statt build_gear.py), eigene Gewichte
addon/Amisia/BisData.lua        NEU, erzeugt: Dungeons, Setboni, Zufallsboni, berechnete Werte,
                                Drop-Grundstock, Aufwand-Parameter
addon/Amisia/Gear.lua           12 Levelbereiche, Waffenplan, Setboni, Zufallsboni, Aufwand,
                                Trefferwert-Grenze, Vergleichserklärung, Live-Umrechnungen
addon/Amisia/Bis.lua            Ziele mit den neuen Regeln, beliebiges Level/Spec simulieren
addon/Amisia/Dungeons.lua       NEU: Dungeon-Planer (Wert je Dungeon, Bosse, Quests, Empfehlung)
addon/Amisia/Drops.lua          NEU: Kill-Aufzeichnung, Namen, Raten, Grundstock, Export-Text
addon/Amisia/DropSync.lua       NEU: Austausch DV/DQ/DI/DR über Comm.lua
addon/Amisia/Comm.lua           Blob-Art "DK", Schlüssel Tag:Instanz, Option low (niedrige Priorität)
addon/Amisia/Collect.lua        übergibt Lootfenster an Drops.lua; ns.Plain auf Quell-GUIDs
addon/Amisia/Pages/*            Ansichten laut "Anzeige" (nach dem Restyle)
addon/Amisia/Amisia.toc         BisData.lua [AllowLoadGameType camelot] nach GearWeights.lua;
                                Drops.lua, DropSync.lua nach Collect.lua; Dungeons.lua nach Bis.lua;
                                Version 2.3.0
index.html                      Import von DK/DN/DZ, Ledger-Feld dropObs, Loot-Tabellen aus
                                Beobachtungen, Reiter "Gear guide" aus data/bis-forever.js
data/forever.js, data/bis-forever.js   erzeugt; BUILD_ID erhöhen
tools/README.md                 build_bis.py, CSV-Liste, was den PC braucht, Lizenzen
tools/tests/*, addon/tests/*    siehe "Tests"
```

Unverändert: Core.lua (Raid-Export), Rolls, SoftRes, Awards, RaidLog, Sync.lua (Raid-Abgleich),
Need.lua (nutzt weiter `ns.BisGain`).

## Herkunft der Daten

Jedes Datum, das 2.3 zeigt oder rechnet, hat genau eine der folgenden Herkünfte. Die Tabelle steht
sinngemäß auch in `tools/README.md`.

| Teil | Herkunft | Wie es ins Repo kommt | Lizenz/Status | Vermerkt in |
|---|---|---|---|---|
| Item-Werte (gescannt) | eigener Client, `/amisia scan gear`, `C_Item.GetItemStats` | SavedVariables -> `build_gear.py` -> `GearData.lua` `ST` | eigene Beobachtung | Kopf `GearData.lua` |
| Item-Werte (berechnet) | Client-Tabellen `ItemSparse`, `RandPropPoints` (wago-CSV, von Hand) | `build_bis.py` -> `BisData.lua` `SC` | Spieldaten von Blizzard | Kopf `BisData.lua`, README |
| Itemart, Level, Klassen, Tempo | `ItemSparse` (wago-CSV) und Scan | wie heute `gear_itemsparse.json` | Spieldaten | README |
| Setboni | `ItemSet`, `SpellEffect` (wago-CSV) | `build_bis.py` -> `BisData.lua` `SET` | Spieldaten | README |
| Zufallsboni | `ItemRandomProperties`, `ItemRandomSuffix`, `SpellItemEnchantment` (wago-CSV); **welche Item welche Boni würfeln kann**, steht nicht im Client: nur beobachtete Links (Sammler, Gilde) | `build_bis.py` -> `BisData.lua` `RP`, `RS` | Spieldaten + eigene Beobachtung | README |
| Umrechnungen (Krit je Beweglichkeit, Rating je Prozent) | Spieltabellen `gtChanceToMeleeCrit*`, `gtChanceToSpellCrit*`, `gtCombatRatings`, Mana-Regeneration (wago-CSV); im Spiel nachgeprüft über die Charakterwerte | `build_bis.py` | Spieldaten | Kopf `GearWeights.lua` |
| Gewichte | eigene Herleitung (Formeln und Annahmen in `build_bis.py`) | `GearWeights.lua` | Amisia (wie das Addon) | Kopf `GearWeights.lua` |
| Quellen (Quest, Händler, Dungeon-Boss, Rar, Welt, Beruf) | QuestieDB (GPL-3.0), OneForAll, AtlasLootClassic (GPL-2.0), wowsrc.com, Sammler | `build_gear.py` (PC) | wie heute | Kopf `GearData.lua` |
| Questketten | QuestieDB (Vorquests) | `build_gear.py` (PC), Feld in `S.Q` | GPL-3.0 | Kopf `GearData.lua` |
| Dungeon-Level, -Größe, Raid-Termine | öffentliche Fakten (Blizzard-Ankündigungen; neue Dungeons laut öffentlicher Liste, von Hand geprüft am 2026-10-05); Classic-Dungeons aus `LFGDungeons` (wago-CSV) | `tools/forever_dungeons.json` | Fakten | Kopf der JSON-Datei |
| Instanz-IDs der neuen Dungeons/Raids | eigener Client (`GetInstanceInfo`, Sammler, Drop-Aufzeichnung) | `DZ`-Zeilen, SavedVariables | eigene Beobachtung | - |
| Dropraten | Kills der Gilde (Drop-Aufzeichnung) | SavedVariables / Website -> `build_scan.py` -> `tools/drop_obs.json`, `data/forever.js`, `BisData.lua` `O` | eigene Beobachtung | Website-Hinweis |
| Bossnamen | eigener Client (Ereignis- und Einheitennamen, deutsch), englisch über QuestieDB-NPC-Namen im Bau | `DN`-Zeilen, `build_scan.py` | Beobachtung / GPL-3.0 | - |

Nicht verwendet: Wowhead (keine Abrufe, keine Daten), die Forever-Datenseite (weder Daten noch
Links), kuratierte BiS-Listen jeder Art, fremde Stat-Gewichte.

## Datenmodell und Umzug

### Kill-Datensätze (`AmisiaDB.drops`)

```lua
AmisiaDB.drops = {
  v = 1,
  me = "3fa9c2e1",                 -- zufällige Client-Kennung (8 Hex), einmal erzeugt, kein Name
  k = {                            -- Kill-Datensätze nach Kennung
    ["9b1e44a0"] = {
      npc = 213450,                -- NPC-ID aus der Leichen-GUID
      inst = 2834,                 -- Instanz-ID (GetInstanceInfo, 8. Rückgabe)
      diff = 1,                    -- difficultyID
      day = 278,                   -- Tag seit 2026-01-01 (Serverzeit, UTC)
      o = "3fa9c2e1",              -- Herkunft: Client-Kennung des Aufzeichners
      enc = 3012,                  -- encounterID, wenn ein Kill-Ereignis passte, sonst nil
      it = { [262888] = 1, [219004] = 1 },   -- Item -> Anzahl im Lootfenster
      src = "G",                   -- G Leichen-GUID, E nur Ereignis (Rückfall, siehe unten)
    },
  },
  npc = { [213450] = "Faldrim Ambossmahl" },  -- Namen, wie der Client sie zeigt (höchstens 2000)
  inst = { [2834] = { "party", "Halle der Thane" } },
  heard = 1759601000,              -- letzter erfolgreicher Austausch
  peers = { ["3fa9c2e1"] = 278 },  -- Herkunft -> neuester Tag (nur Zählung, keine Namen)
}
```

- **Kennung `h`:** 8 Hex aus `ns.Checksum` über `serverID-zoneUID-npcID-spawnUID` der Leichen-GUID
  (`Creature-0-<server>-<map>-<zoneUID>-<npc>-<spawnUID>`). Wer dieselbe Leiche öffnet, bekommt
  dieselbe Kennung; so zählt ein Kill einmal, auch wenn fünf Gildenmitglieder ihn aufzeichnen.
- **Rückfall ohne GUID** (`src = "E"`, falls Forever die Quell-GUID in Instanzen geheim hält):
  Kennung aus `encounterID`, Instanz-ID und `floor(GetServerTime() / 120)` des Kill-Ereignisses.
  Mitglieder derselben Gruppe treffen fast immer denselben Zeitkorb; ein Kill an der Korbgrenze
  zählt dann doppelt (in Kauf genommen, in der Anzeige nicht unterschieden). NPC-ID ist dann 0 und
  der Boss wird über `enc` geführt.
- **Aufbewahrung:** 28 Tage und höchstens 4000 Datensätze (älteste zuerst weg). Langfristig leben
  die Daten im Archiv `tools/drop_obs.json` (über Website oder SavedVariables) und im erzeugten
  Grundstock `BisData.lua` `O`.
- **Vereinigung:** gleiche Kennung aus zwei Quellen -> ein Datensatz; `it` je Item das Maximum,
  danach in den Obergrenzen (16 Items, 20 je Item; in jeder Reihenfolge dasselbe); `day` der frühere
  Tag (eine Leiche vor und nach Mitternacht UTC ist ein Kill); `o` bleibt bei einem eigenen
  Datensatz, sonst die kleinere Kennung (damit alle Clients dasselbe Ergebnis haben); ein Datensatz
  nach heute wird abgelehnt, bei 4000 gespeicherten auch einer älter als der älteste;
  `ns.BIS.OI` (Kennungen des letzten Tags des Grundstocks) zählt ein Kill nicht doppelt; `enc`, `npc` gefüllt, wenn
  einer sie hat. Nichts wird gelöscht außer durch Alter oder Obergrenze.

### BiS je Charakter (`AmisiaDB.bis`, Erweiterung)

```lua
chars[me].plan = "auto"           -- Waffenplan: auto | 2H | DW | SHIELD
chars[me].sim = { class = nil, spec = nil, level = nil }   -- Simulation, nil = eigener Charakter
```

Einstellungen siehe unten. Bestehende Felder (`wish`, `ex`, `bag`, `bank`, `spec`) bleiben.

### Umzug

`ns.DropsMigrate(root)` und `ns.BisMigrate(root)` (erweitert) beim `ADDON_LOADED`:
`AmisiaDB.drops = AmisiaDB.drops or { v = 1, k = {}, npc = {}, inst = {}, peers = {} }`; `me` wird
erzeugt, falls es fehlt (`("%08x"):format(math.random(0, 0x7fffffff))` nach `math.random` mit
`GetServerTime()`-Saat); Datensätze mit kaputten Feldern fallen weg; Aufbewahrung wird angewandt;
`plan` ungültig -> "auto". Zweimal laden ändert nichts. Bestehende Sammler-Notizen
(`scan.sources`) bleiben; aus ihnen werden **keine** Kill-Datensätze rückwirkend gebaut (kein
Kill-Bezug). Der Wertungs-Speicher `AmisiaDB.gear` bekommt durch das neue `built` einen neuen
Schlüssel; alte Einträge fallen beim ersten Lesen wie heute weg.

## Erzeugung: was wo läuft

```
PC (WoW-Installation)                         N100 (Repo, keine WoW-Installation)
---------------------------------------       ---------------------------------------------------
/amisia scan gear  -> SavedVariables          wago-CSV von Hand im Browser laden, nach
build_gear.py (QuestieDB, OneForAll,           tools/wago/<build>/ legen (nicht committen)
  AtlasLoot, Scan) -> GearData.lua            build_bis.py --wago tools/wago/1.60.1.<build>
build_scan.py <Amisia.lua> -> data/forever.js     -> tools/bis_gamedata.json (committet)
  und tools/drop_obs.json                     build_bis.py -> GearWeights.lua, BisData.lua,
                                                 data/bis-forever.js
                                              Tests, Twin, Release
```

- `build_scan.py` liest nur SavedVariables und braucht keine WoW-Installation; es läuft auf dem
  N100, sobald `Amisia.lua` (SavedVariables) dort liegt (siehe "Offene Fragen an den Nutzer").
  `--obs <datei.json>` nimmt zusätzlich den Download der Website ("Download observations").
- `build_bis.py` braucht nur Repo-Dateien und den CSV-Auszug, läuft also immer auf dem N100. Es
  liest `GearData.lua` (Zeilen `I`, `S`, `ST`) als Eingabe, ändert sie nicht.
- Reihenfolge nach neuen Daten: (PC) Scan und `build_gear.py`, (N100 oder PC) `build_scan.py`,
  (N100) `build_bis.py`, Tests, `BUILD_ID` erhöhen, Twin bauen und veröffentlichen,
  `python tools/twin_stamp.py --published`, Release.

### CSV-Liste (Forever-Build, von Hand bei wago.tools herunterladen)

`ItemSparse`, `Item`, `ItemSet`, `ItemRandomProperties`, `ItemRandomSuffix`,
`SpellItemEnchantment`, `RandPropPoints`, `SpellEffect`, `LFGDungeons`, `gtChanceToMeleeCrit`,
`gtChanceToMeleeCritBase`, `gtChanceToSpellCrit`, `gtChanceToSpellCritBase`, `gtCombatRatings`,
`gtRegenMPPerSpt` (falls vorhanden). `build_bis.py --wago <ordner>` liest, was da ist, meldet, was
fehlt, und schreibt nur die benutzten Spalten und Zeilen nach `tools/bis_gamedata.json` (mit
Build-Nummer und Datum). Ohne neue CSV baut das Skript aus dem Zwischenspeicher. Fehlt eine Tabelle
ganz, fällt nur ihr Teil weg (z. B. keine Setboni) und die Ausgabe sagt es im Kopf.

### Ausgabe

- `GearWeights.lua`: Kopf `-- GENERATED by tools/build_bis.py. Do not edit; rebuild instead.` und
  `-- Amisia's own weights, derived in tools/build_bis.py from game mechanics and the client's game
  tables.` Format wie heute (`brackets`, `order`, `specs`), aber 12 Bereiche passend zu
  `Gear.COLUMNS` (`{9, 14, 19, ..., 59, 60}`), je Spec `Speedrun` und `Hardcore`, dazu `unit` und
  `why` (deutsche Kurzbegründung je Spec, eine Zeile, für die Erklärung im Spiel).
- `BisData.lua` (Wächter `if not ns.IsForever() then return end`), Tabelle `ns.BIS`:

```lua
ns.BIS = {
  built = "2026-10-20", gamedata = "1.60.1.70205",
  SC = { [219004] = "STRENGTH=12;STAMINA=9" },      -- berechnete Werte ungescannter Items
  SET = { [801] = { items = {219001, 219002, 219003}, b = { {2, "ARMOR=50"}, {4, "STRENGTH=10"} } } },
  RS = { [12] = "AGILITY=1.0;STAMINA=0.66" },      -- Zufallsbonus -> Anteile (mit RP mal Budget)
  RP = { [15210] = { pts = 23, s = {12, 14, 31} } },   -- Item -> Budget und beobachtete Boni
  DG = {                                              -- Dungeons und Raids
    { key = "thanes", name = "Hall of Thanes", kind = "party", min = 13, max = 18, size = 5,
      inst = 2834, area = 0, bosses = { 213450, 213451 }, quests = { 82001, 82002 } },
  },
  O = { [213450] = { k = 41, it = { [219004] = 9, [219005] = 6 } } },   -- Drop-Grundstock: Kills, Sichtungen
  OT = 278,                                           -- Grundstock enthält Kills bis zu diesem Tag
  EF = { V = 1, C = 2, A = 2, Q = 2, QSTEP = 1, D = 3, R = 8, W = 20, P = 25 },   -- Aufwand
}
```

- `data/bis-forever.js`: vorgerechnete Ziele für die Website (siehe "Leistung").

## Wertung (Gear.lua, build_bis.py)

Die Formel bleibt `Gear.Score(s, w, level, kind, class)` mit `terms()` als einziger Quelle für Summe
und Teile. Neu und geändert:

### Eigene Gewichte: Herleitung

Jede Spec hat eine **Einheit** (`unit`): Nahkampf und Jäger "1 Angriffskraft", Zauberschaden-Specs
"1 Zauberschaden", Heiler "1 Heilung", Tanks "1 Ausdauer". Jedes andere Gewicht sagt, wie viele
Einheiten ein Punkt (bei Ratings: ein Prozent) wert ist. Hergeleitet wird je Levelbereich an einem
**Bezugscharakter**: die Werte, die die eigene BiS-Ausrüstung des vorigen Bereichs ergibt
(Fixpunkt: Gewichte rechnen, BiS wählen, Bezugswerte daraus, Gewichte neu; drei Durchläufe, danach
ändert sich kein Gewicht mehr als 1 %; das Skript meldet, wenn nicht). So passen Gewichte zu dem,
was ein Charakter auf dem Level wirklich trägt, statt zu einem Endspiel-Profil.

Bausteine (alle Konstanten mit Kommentar im Skript; was aus Client-Tabellen kommt, ist markiert):

- **Umrechnungen** (Spielmechanik, bei Forever im Spiel zu bestätigen, siehe "Offene Punkte"):
  Stärke -> Angriffskraft (Krieger, Paladin, Schamane, Druide 2, Schurke und Jäger 1),
  Beweglichkeit -> Angriffskraft (Schurke, Jäger 1; Druide in Gestalt 1), Beweglichkeit -> Distanz-
  Angriffskraft (Jäger 2), Beweglichkeit -> Krit und Intelligenz -> Zauberkrit **je Klasse und Level aus
  `gtChanceToMeleeCrit`/`gtChanceToSpellCrit`**, Rating je Prozent aus `gtCombatRatings` (heute fest
  `RATING_60` mit `(L-8)/52`; wird durch die Tabelle ersetzt, wenn sie da ist).
- **Physischer Schaden:** Schaden je Sekunde des Bezugs `D = (wDPS + AP/14) * (1 + c*(m-1)) * t`
  mit Waffen-DPS `wDPS`, Krit `c`, Krit-Faktor `m = 2`, Trefferanteil `t`. Dann: 1 Angriffskraft = 1
  Einheit; 1 % Krit = `14 * 0,01 * (m-1) * (wDPS + AP/14)`; 1 % Treffer = `14 * 0,01 * (wDPS + AP/14) *
  (1 + c*(m-1)) / t`, unterhalb der Grenze voll, darüber 0 (siehe "Grenzen"); 1 % Tempo =
  Tempoanteil `h` der Spec mal `14 * 0,01 * D/t`; 1 Waffen-DPS = `14 * a` mit Anteil `a` des
  Waffenschadens (Nahkampf 1,0); Waffentempo siehe unten.
- **Zauberschaden:** Bezugszauber je Levelbereich (Grundschaden und Zauberzeit der
  Hauptzauber-Rangstufe aus einer kleinen, kommentierten Tabelle im Skript, z. B. Frostblitz für
  Frost); Koeffizient `k = Zauberzeit / 3,5`. 1 Zauberschaden = 1 Einheit; 1 % Zauberkrit =
  `0,01 * 0,5 * (B + k*SP) / k`; 1 % Zaubertreffer analog mit dem Fehlanteil; Intelligenz =
  Krit über die Tabelle plus Manawert (15 Mana je Intelligenz mal `v_mana(L)`, Wert von Mana in
  Einheiten über Schaden je Mana des Bezugszaubers und einen festen Anteil "Mana ist knapp" je
  Spec); Willenskraft und MP5 über denselben Manawert mit der Regeneration aus der Tabelle.
- **Heilung:** 1 Heilung = 1 Einheit; Mana wie oben, aber mit höherem Anteil "Mana ist knapp";
  Zauberkrit mit Heilkrit-Faktor 1,5; Tempo über den Tempoanteil.
- **Tank:** effektive Gesundheit `EH = HP / (1 - Rüstungsminderung) / (1 - Vermeidung)` gegen einen
  Gegner zwei Level über dem Bezug (Rüstungsminderung nach `Rüstung / (Rüstung + 400 + 85 * L)`).
  1 Ausdauer = 1 Einheit (10 Gesundheit); Rüstung, Verteidigung, Ausweichen, Parieren, Blocken als
  Ableitung von EH in Ausdauer-Einheiten; Bedrohung (Stärke, Angriffskraft, Treffer, Waffenkunde)
  mit einem kleinen festen Anteil (0,15), damit ein reines Ausdauer-Item nicht immer gewinnt.
- **Hardcore:** Speedrun-Gewichte plus Überlebensanteil (Ausdauer und Rüstung über die Tank-Formel
  mal 0,3); ersetzt die heutige zweite Tabelle mit derselben Bedeutung.
- Jede Spec hat einen Parametersatz (Anteile `a`, `h`, Manaknappheit, Bezugszauber, Waffenplan
  Standard) mit einem Satz Begründung im Skript; `why` in `GearWeights.lua` fasst sie für die
  Erklärung im Spiel zusammen ("Schurke: Waffenschaden zählt voll, Treffer bis 6 %, Beweglichkeit
  gibt Angriffskraft und Krit.").

### Grenzen

Trefferwertung zählt bis zur Grenze gegen Gegner zwei Level über dem Bezug (Nahkampf 6 %, Zauber 6
%, aus den Classic-Regeln, im Spiel zu bestätigen), darüber 0. Im Vorrechnen gilt der Bezugswert;
im Spiel der eigene sichtbare Wert (`GetCombatRatingBonus`/`GetHitModifier`, falls vorhanden, siehe
APIs): ein Item zählt nur den Teil seiner Trefferwertung, der unter die Grenze fällt, gerechnet
gegen das Angelegte im selben Slot. Fehlt die API, zählt Treffer linear wie heute und die Erklärung
sagt "Trefferwertung zählt ohne Obergrenze".

### Waffen: Tempo und Plan

- **Tempo:** Specs, deren Hauptangriffe den Waffenschaden je Schlag nehmen (Krieger, Paladin,
  Schurke, Verstärkung, Jäger mit Distanz), bekommen `SPD_<art>` = Anteil dieser Angriffe am Schaden
  mal Waffen-DPS-Gewicht mal 0,1 je 0,1 s über dem Bezugstempo; die Zahl steht in der Erklärung als
  "Waffentempo 3,6 s: +12". Andere Specs 0.
- **Plan** (`chars[me].plan`, Wahl auf der Seite): "auto" (wie heute: beste Summe aus Zweihand gegen
  Waffenhand plus Schildhand), "2H" (nur Zweihand), "DW" (zwei Waffen, nur wenn die Klasse es auf dem
  Level kann), "SHIELD" (Waffe und Schild oder Nebenhand). Der Planer zeigt immer beide Summen;
  "auto" nennt den Gewinner. Die Off-Hand-Faktoren (`OHDPS`) kommen aus der Herleitung
  (halber Schaden, Fehlschlag-Aufschlag beim Beidhändigkeitskampf).

### Setboni

`ns.BIS.SET`: je Set die Teile und Boni (Schwelle, Werte). Werte werden nur aus einfachen Effekten
gelesen (Attribut, Rating, Angriffskraft, Zauberschaden/Heilung, Rüstung, MP5); ein Bonus mit
anderem Effekt zählt 0 und steht als "Setbonus nicht gewertet" in der Erklärung. Rechnung in
`Gear.Best`: nach der Wahl je Slot prüft `Gear.SetPlan` jedes Set mit mindestens zwei erreichbaren
Teilen: für jede Schwelle die beste Belegung "k Teile des Sets plus die besten Einzelteile in den
übrigen Slots" gegen die Einzelwahl; gewinnt das Set, ersetzt es die Wahl in seinen Slots und die
Option trägt "Set: 3/5, +18 Bonus". Höchstens 2 Sets gleichzeitig, Aufwand je Set linear in seinen
Teilen (kein Durchprobieren aller Kombinationen).

### Zufallsboni ("...des Adlers")

Welche Boni ein Item würfeln kann, steht nicht in den Client-Tabellen (serverseitig). Darum:
- `RP[item].s` = Boni, die der Sammler oder die Gilde an diesem Item **gesehen** hat (Item-Links mit
  Bonus-Feld, aus `scan.sources`-Links und Drop-Datensätzen, im Bau gesammelt). Werte je Bonus über
  `RS` mal Budget `RP[item].pts` (aus `RandPropPoints` je Itemlevel und Qualität), bzw. feste Werte bei
  den älteren Eigenschaften (`ItemRandomProperties` -> `SpellItemEnchantment`).
- Gewertet wird mit dem **besten gesehenen Bonus** für die Spec; die Option heißt dann "Kettenhemd
  des Adlers (bester gesehener Bonus)". Ist kein Bonus gesehen, gilt der Grundwert (wie heute) mit
  dem Hinweis "Zufallsbonus unbekannt". Der Tooltip wertet wie heute den konkreten Link.
- Einstellung `bis.suffix` ("best" Standard, "base" nur Grundwerte).

### Berechnete Werte

Für Items, die kein Scan gesehen hat, rechnet `build_bis.py` die Werte aus `ItemSparse` (Anteile je
Wert) und `RandPropPoints` (Budget je Itemlevel und Qualität), wie Forever sie laut Spieldaten
bildet. **Pflichtprüfung im Bau:** für alle gescannten Items wird dieselbe Rechnung gemacht; stimmen
weniger als 98 % exakt, schreibt das Skript keine `SC` und meldet die Abweichungen. Im Spiel gehen
gescannte Werte (`ST`) und Client-Werte immer vor `SC`; Optionen aus `SC` tragen "(berechnet)".

### Level, Questketten, Fraktion, Berufe

- Level wie heute (Pflichtlevel, Quest-Items ab Questlevel - 4, Berufe Fertigkeit / 5). Neu:
  Quests mit Vorquests tragen `chain` (Zahl der Quests bis hierher, aus QuestieDB, Feld 10 in `S.Q`)
  und das Level, ab dem die Kette beginnt; der Text sagt "Questreihe, 4 Quests".
- Fraktion, Berufe ("alle"/"nur meine"), Ausschlüsse: wie 1.8.

### Aufwand als Gleichstandsregel

Jede Quelle hat einen Aufwand (`EF`, Einheit "ungefähr ein Dungeonlauf = 3"): Händler 1,
Auktionshaus und kaufbares Hergestelltes 2, Quest 2 plus 1 je Kettenschritt, Dungeon-Drop `3 / p`
(gedeckelt bei 30; `p` siehe "Dropraten"), Rar 8, Weltdrop 20, PvP-Rang 25. Liegen Optionen eines
Slots innerhalb von `bis.effortTie` Prozent (Standard 3) der besten Wertung, ordnet der Aufwand. Die
Zahl ändert die Wertung nie, nur die Reihenfolge innerhalb des Gleichstands; die Seite zeigt
"leichter zu bekommen" an der vorgezogenen Option.

### Erklärung und Vergleich

- `Gear.ScoreParts` wie 1.8, ergänzt um Teile "Setbonus", "Waffentempo", "Trefferwertung über der
  Grenze (0)".
- **NEU `ns.BisCompare(a, b, opts)`**: Teile von a minus Teile von b, nach Betrag sortiert, als
  Zeilen: "+24 Stärke (+48), -1,1 % Krit (-15), ..." und ein Satz "Option 1 liegt 21 vorn, vor
  allem durch Stärke.". Auf der Seite für Option 1 gegen 2 und gegen das Angelegte.
- **"Warum diese Gewichte"**: die `why`-Zeile der Spec und die Bezugswerte ("Bezug Level 30: 410
  Angriffskraft, 22 Waffen-DPS, 14 % Krit").
- **Live-Gewichte** (`bis.liveWeights`, Standard aus): statt des Bezugscharakters die eigenen
  sichtbaren Werte (Angriffskraft, Krit, Waffen-DPS, Trefferbonus aus dem Charakterfenster) in
  dieselben Formeln; nur der eigene Charakter, nur außerhalb des Kampfes neu gerechnet.

## BiS je Levelbereich (Bis.lua)

- `ns.BisTargets(opts)` wie 1.8 (drei Optionen je Slot, Besitz, Wünsche, Ausschlüsse) mit den neuen
  Regeln: Waffenplan, Setplan, Zufallsboni, Aufwand-Gleichstand, Grenzen.
- **NEU `ns.BisFor(class, spec, level, opts?)`**: dieselbe Rechnung für eine beliebige
  Klasse/Spec/Level ohne Besitz und ohne Zuwachs (Simulation, Planertabelle). Die Planertabelle
  (`GearFrame.lua`, 12 Spalten) nutzt sie.
- **Startwerte aus dem Vorrechnen:** `data/bis-forever.js` ist für die Website; im Addon wird live
  gerechnet (Filter wie Fraktion, Berufe, Ausschlüsse machen Vorrechnen dort wertlos). Die Rechnung
  ist billig genug (siehe "Leistung").

## Dungeon-Planer (Dungeons.lua)

```lua
ns.DungeonList(opts?) -> { { key, name, min, max, kind, size, value, once, perRun, upgrades,
                             bosses = { { npc, name, items = { {id, gain, p, owned, wished} } } },
                             quests = { { qid, title, best = {id, gain}, done } }, fit } }
ns.DungeonNext(opts?) -> entry, reason
ns.DungeonInfo(key) -> entry      -- auch für Dungeons außerhalb des Levels
```

- **Welche Dungeons:** `ns.BIS.DG` (aus `forever_dungeons.json`, alle 35 Forever-Dungeons und die
  Raids, Level-Bereiche als Fakten). Bosse über die D-Quellen mit NPC-ID und den Drop-Grundstock;
  Items je Boss = Vereinigung aus Quelldaten (`D`) und Beobachtungen (`O` plus eigene Datensätze).
- **Je Item:** Zuwachs `ns.BisGain` für den eigenen Charakter (oder die Simulation), nur Upgrades
  über `bis.minGain`; Drop-Wahrscheinlichkeit `p` (siehe unten).
- **Je Dungeon:** `perRun` = Summe über Bosse und Upgrades von `gain * p` (erwarteter Zuwachs je
  Lauf, "ohne Mitbewerber"; eine Zeile sagt das); `once` = Summe der besten Questbelohnung je
  offener Dungeon-Quest (Quests mit `S.Q` Feld 9 = dieser Dungeon, Fraktion passend, nicht erledigt
  laut `C_QuestLog.IsQuestFlaggedCompleted`); `upgrades` = Zahl der Upgrade-Items; `value = once +
  2 * perRun` (zwei Läufe als üblicher Plan); `fit`: "passt" (Level im Bereich), "bald" (Level bis zu
  2 darunter), "leicht" (über dem Bereich, grau), "zu hoch" (mehr als 2 darunter).
- **Nächster Dungeon:** der höchste `value` unter "passt" und "bald"; Begründung als Text
  ("Halle der Thane: 4 Upgrades, 2 Quests mit Upgrades, Schwerpunkt Faldrim Ambossmahl").
  Ohne Treffer: "Für dein Level hat kein Dungeon noch Upgrades für dich.".
- Raids erscheinen ab Level 60 mit eigener Kennzeichnung; `p` dort nur aus Beobachtungen.
- Wegpunkt zum Eingang über die Karte aus 1.9 (`ns.MapSetPoint` mit `N:<Name>`/`I:<ID>`), wo
  `MapData` den Eingang kennt.

### Dropraten (`ns.DropRate(npc, item)`)

`p = (n + 3 * p0) / (K + 3)` mit `n` Sichtungen und `K` Kills der Gilde (Grundstock `O` plus eigene
Datensätze nach `OT`), `p0` aus der Quelle (Chance im `D`-Datensatz), sonst `1 / Zahl der
bekannten Items gleicher Qualität des Bosses` (Forever: jeder Dungeon-Boss lässt ein seltenes Item
fallen). Anzeige: "9 von 41 Kills der Gilde (22 %)"; unter 5 Kills nur "gesehen 2-mal in 3 Kills".
Ohne Beobachtung: Quell-Chance oder "Chance unbekannt".

## Drop-Daten der Gilde

### Aufzeichnen (Drops.lua)

- Auslöser `LOOT_OPENED` (Collect.lua ruft `ns.DropsFromLoot()`); alle Werte durch `ns.Plain`,
  geheime Werte überspringen.
- **Nur in Instanzen** (`GetInstanceInfo()` Art `party` oder `raid`). Ein geöffnetes Lootfenster einer
  Leiche (Quell-GUID `Creature-`/`Vehicle-`, nie `Item-`) wird ein Kill-Datensatz, wenn der NPC ein
  Boss ist: NPC-ID in den D-Quellen oder im Grundstock, **oder** ein `ENCOUNTER_END` mit Erfolg (bzw.
  `BOSS_KILL`) dieser Instanz innerhalb von 120 s (Zuordnung über RaidLog.lua, das die Ereignisse
  schon liest), **oder** das Fenster enthält ein Item der Qualität 3 oder höher (Forever: Bosse
  lassen immer ein seltenes Item fallen). Trash bleibt wie heute nur Sammler-Notiz und wird nicht
  geteilt. Das Kill-Ereignis geht an eine Leiche eines bekannten Bosses oder mit seltenem Item; eine
  Leiche ohne beides hält es nur vorläufig: öffnet man innerhalb der 120 s eine bessere, übernimmt
  diese das Ereignis, und die erste (doch Trash) verliert Datensatz und Ereignis-Namen.
- **Was zählt:** jedes Item der Qualität 2 oder höher, dazu Rezepte und Baupläne (Item-Klasse 9)
  jeder Qualität; Anzahl laut `GetLootSlotInfo`. Ein Kill ohne solche Items wird trotzdem
  gespeichert (`it = {}`), denn er zählt für die Rate. Obergrenzen überall (eigenes Fenster,
  Austausch, SavedVariables): höchstens 16 Items je Datensatz (die 16 kleinsten IDs), höchstens 20
  je Item.
- **Nur einmal je Leiche:** ein zweites Öffnen derselben Leiche ergänzt `it` (Maximum je Item),
  zählt keinen zweiten Kill.
- **Namen:** NPC-Namen über `UnitName("target")`, wenn das Ziel die GUID der Leiche hat, sonst über
  den Bossnamen aus `ENCOUNTER_END`; Instanzname aus `GetInstanceInfo()`. Geheime Namen werden
  übersprungen und später nachgetragen.
- In Schlachtfeldern und Arenen nichts.

### Austausch (DropSync.lua, über Comm.lua)

Ablauf als Ziehen in drei Stufen (Prüfsummenbaum), damit nur Fehlendes wandert:

| Typ | Präfix | Kanal | Felder | Zweck |
|---|---|---|---|---|
| `DV` | Amisia | GUILD | Drop-Protokoll (2), Zahl der Datensätze, neuester Tag, vier Wochen-Angaben `w:hhhh:n` (w 0-3 = Alter in Wochen, 4 Hex Prüfsumme, Anzahl), mit Komma | "so viele Kills kenne ich" |
| `DQ` | Amisia | WHISPER | Woche (0-3) | nach der Eimerliste einer Woche fragen |
| `DI` | Amisia | WHISPER | Woche, Teil i, Teile n, bis zu 12 Eimer `tag:inst:hhhh:n` mit Komma | Eimerliste (Eimer = Tag und Instanz) |
| `DR` | Amisia | WHISPER | bis zu 12 Paare: Eimer-Schlüssel `JJJJ-MM-TT:<inst>`, eigene Kennungen in diesem Eimer mit 4 Hex Item-Prüfsumme (bis zu 16, je 12 Hex, Komma) oder `*` | Eimer anfordern, ohne das schon Bekannte |
| `DW` | Amisia | WHISPER | Sekunden | "beschäftigt, später fragen" |
| `BL` Art `DK` | AmisiaD | WHISPER | wie 2.1, Schlüssel = erster Eimer-Schlüssel der Anfrage | die fehlenden Datensätze (höchstens 20 Teile; `m = 1`: eine zweite Hälfte folgt) |

- **Prüfsummen (Drop-Protokoll 2):** Eimer-Prüfsumme = `ns.Checksum` über die sortierten Kennungen
  des Eimers, jede mit der Prüfsumme ihrer Items und ihres `enc`; so ziehen auch Clients mit gleichen
  Kennungen, aber anderen Items, und gleichen sich an. Wochen-Prüfsumme über die Eimer-Summen.
  Protokoll 1 prüfte nur Kennungen; Clients mit 1 und 2 ignorieren die `DV` des anderen.
- **Ziehen:** wer ein `DV` mit abweichender Wochen-Prüfsumme hört, fragt nach 0 bis 30 s (Zufall)
  höchstens **einen** Absender zur Zeit (`DQ`; unter mehreren gehörten einen zufälligen), vergleicht
  die Eimer und schickt für fehlende oder abweichende Eimer `DR`, mehrere Eimer je Anfrage (bis 12,
  nach den Zahlen des Absenders bis 100 Datensätze); der Antwortende sendet die Datensätze, deren
  Kennung nicht genannt ist oder deren Item-Prüfsumme abweicht (bei `*` alle). Beide Seiten ziehen,
  keine schiebt. Mehr als 16 eigene Kennungen in einem Eimer: höchstens einmal je 7 Tage `*`.
- **Eine Anfrage, eine Antwort:** angenommen wird genau die Antwort auf ein `DR` (ein Blob, oder die
  zwei Hälften einer großen Antwort), danach gilt jeder weitere Blob als unverlangt. Datensätze, die
  die Anfrage mit gleicher Item-Prüfsumme als bekannt nannte, werden verworfen; je Eimer nicht mehr
  Datensätze als der Absender in `DI` zählte (sonst der ganze Blob), je Anfrage höchstens 300; je
  Sitzung höchstens 600 neue Datensätze einer Herkunft und 1500 eines Absenders.
- **Beschäftigt:** ein Antwortender bedient zwei Fragende zugleich; ein dritter (oder eine volle
  Warteschlange von 12 Anfragen, 2 je Fragendem) bekommt `DW 120` und fragt erst einen anderen
  Absender oder nach der Wartezeit wieder. Bedient wird reihum (wer am längsten wartet, zuerst).
- **Wann:** ein `DV` 60 bis 180 s nach dem Login (Zufall); ein Client, der dann nichts hatte, sobald
  er Datensätze gelernt hat und sein Ziehen fertig ist (so ziehen andere auch von ihm). Danach
  höchstens alle 30 Minuten: nach neuen eigenen Datensätzen, und einmal je Sitzung nach gelernten.
  Gesendet und geantwortet wird nur, wenn alles gilt:
  `drops.share` an, nicht in einer Instanz (`IsInInstance()` falsch), nicht im Kampf
  (`InCombatLockdown()`), keine Sperre (`ns.CommHeld()`), keine laufende Raid-Aufnahme mit Sync, kein
  Schlachtfeld.
- **Grenzen:** höchstens ein offener `DR` je Client; höchstens 30 `DR` je Stunde; ein Antwortender
  bedient höchstens einen Blob je 30 s und 40 Teile je 10 Minuten; Blob höchstens 20 Teile (etwa 3 KB
  gepackt, etwa 100 Datensätze; ein größerer Eimer wird nach Kennungen in Hälften geteilt und mit
  zwei Blobs beantwortet); höchstens 60 KB Senden je Sitzung, davon höchstens ein Drittel an einen
  Fragenden; empfangen wird höchstens ein `DQ` je Woche und Absender je 60 s und ein `DR` je
  (erstem) Eimer und Absender je 60 s (Comm.lua). Alles mit `opts.low`: solche Einträge
  gehen erst, wenn sonst nichts in der Schlange wartet, und fallen nach 120 s (ttl).
- **Vertrauen:** gelesen wird nur von geprüften Gildenmitgliedern (`ns.IsVerifiedMember`, sonst
  `ns.TrustWait`); Flüsterungen gehen nur an Gildenmitglieder. Absendernamen werden nicht
  gespeichert, nur `peers[o]` (Herkunft aus den Daten, keine Namen).
- **Prüfung des Blob-Inhalts** (alles oder nichts, wie 2.1): `{ v = 1, r = { {h, npc, inst, diff,
  day, o, enc, {id, n, id, n, ...}, src}, ... }, n = { [npc] = name }, z = { [inst] = {kind, name} } }`;
  `h`, `o` 8 Hex; `npc` 0 bis 9999999; `inst` 1 bis 99999; `diff` 0 bis 255; `day` innerhalb der
  letzten 28 Tage und nicht nach heute (UTC); höchstens 16 Items je Datensatz, IDs 1 bis
  9999999, Anzahl 1 bis 20; höchstens 300 Datensätze; Namen höchstens 48 Bytes gültiges UTF-8 ohne
  Steuerzeichen und `|`; `kind` `party` oder `raid`; jeder Datensatz muss zu einem Eimer der Anfrage
  passen.
- **Comm.lua:** `BLOB_ARTS` bekommt `DK` (höchstens 20 Teile); der Schlüssel `Tag:Instanz` hat schon
  das Format der Raid-Schlüssel; `opts.low` ordnet hinter Daten und Steuerung; Grenzen je Absender
  wie 2.1 gelten zusätzlich.

### Export ("Drops für die Website", Drops.lua)

```
#AMISIA 2 Vulo_Sturmwind
DZ <instanceID> <party|raid> <name>
DN <npcID> <encounterID|0> <name>
DK <h> <npcID> <instanceID> <difficultyID> <JJJJ-MM-TT> <origin> <G|E> <itemID>:<n>,<itemID>:<n>|-
#END
```

- Alle gespeicherten Datensätze (eigene und gehörte, 28 Tage), sortiert nach Tag, dann Kennung. Der
  Name im Kopf ist wie bei der Wunschliste der eigene Charakter (wer exportiert, nicht wer gesehen
  hat); in den Zeilen steht kein Name.
- Geschrieben mit `lines[#lines + 1] = ("DK %s %d %d %d %s %s %s %s"):format(...)` usw., damit
  `test_export_format.py` sie findet.
- Raid-Export, `ns.SessionHash`, bestehende Zeilen: unverändert.

## Website (index.html, build_scan.py)

Texte englisch.

- **Parser `amParseDrops(blocks)`** (rein, testbar): liest `DZ`, `DN`, `DK` aus allen `#AMISIA`-Blöcken;
  `amParse`, `amParseBank`, `amParseWishes` überspringen sie (unverändert).
- **Import-Reiter:** ein Text mit `DK`-Zeilen zeigt "This text holds n boss kills seen by the guild
  (m new)." und einen Knopf "Add the kills"; geschrieben wird ins Ledger-Feld `dropObs` (in
  `PER_GAME`), vereinigt nach Kennung wie im Addon (Items Maximum, kleinste Herkunft), dazu
  `dropNames` (NPC -> Name) und `dropZones` (Instanz -> Art, Name). Zweimal importieren ändert
  nichts. Gespeichert wird kompakt (`[h, npc, inst, diff, day, o, src, [id, n, ...]]`).
- **Loot-Tabellen aus Beobachtungen:** die Forever-Ansicht der Loot-Tabellen bekommt je Dungeon und
  Raid die Bosse mit "Kills seen by the guild: 41" und je Item "9 of 41 (22 %)", sortiert nach Rate.
  Quelle der Zahlen: `data/forever.js` (Archiv bis zum Bau) plus `dropObs` mit Tag nach dem Bau
  (keine Doppelzählung über den Stichtag `obsThrough`). Zonen ohne Eintrag in `forever.js` entstehen
  aus `dropZones` (so erscheinen Barrow Deeps, Hyjal Summit und Onyxia von selbst ab dem ersten
  importierten Kill, mit Standardfarbe, bis `forever_zones.json` sie nennt). Ein Satz unter jeder
  Tabelle: "Drop rates are counted from loot windows guild members opened; they are observations,
  not official chances."
- **Download observations** (nur Editoren): lädt `dropObs` als JSON für `build_scan.py --obs`.
- **`build_scan.py`:** liest `drops.k` aus den SavedVariables und optional `--obs`, vereinigt mit
  `tools/drop_obs.json` (Archiv, committet), schreibt das Archiv zurück und in `data/forever.js` je
  Boss `{npc, name, zone, kills, obs: {item: n}}` sowie `obsThrough`. Englische Bossnamen über
  QuestieDB-NPC-Namen, wo der Bau auf dem PC läuft, sonst der Name aus `DN`. Bestehende Teile
  (Raid-Drops aus Sitzungen, Katalog, Sammler-`via`) bleiben.
- **Reiter "Gear guide"** (NEU, aus `data/bis-forever.js`, für alle): Klasse, Spec, Level (1-60),
  Fraktion, Waffenplan; je Slot die drei besten Optionen mit Quelle, Wertung und den drei größten
  Teilen der Erklärung; ein Absatz "How Amisia scores" mit Einheit, Bezugswerten und der
  Kurzbegründung der Spec. Kein Verweis auf andere Seiten: Items im Gear guide und in den neuen
  Beobachtungs-Zeilen werden ohne Link gezeichnet (`link === false` im vorhandenen Icon-Helfer);
  die Item-Links bestehender Ansichten bleiben unverändert (siehe "Offene Frage an den Nutzer").
- **Dungeons** in den Loot-Tabellen: Level-Bereich und Größe aus `forever_dungeons.json` neben dem
  Namen; für die gewählte Spec im "Gear guide" ein Zeichen an Items, die dort in den ersten drei
  stehen.
- `BUILD_ID` erhöhen (Datendateien ändern sich), Twin bauen, veröffentlichen, stempeln; `build_twin.py`
  schneidet Import und Download mit ab (keine Datenbank im Twin); Gear guide und
  Beobachtungs-Tabellen aus `forever.js` bleiben im Twin.

## Anzeige (welche Ansichten, nach dem Restyle)

Maße, Farben, Bausteine und Anordnung bestimmt der Restyle; hier steht nur, welche Information wo
erscheint.

- **Seite "Ausrüstung", Ansicht Ziele:** wie 1.8, dazu Waffenplan-Wahl, Markierungen "Set 3/5",
  "(berechnet)", "bester gesehener Bonus", "leichter zu bekommen"; Detail mit Vergleich Option 1
  gegen 2 und gegen das Angelegte; "Warum diese Gewichte".
- **Ansicht Simulation:** Klasse, Spec, Level frei wählen (`ns.BisFor`), ohne Besitz und Zuwachs.
  Die Planertabelle (`/amisia gear`) bleibt als Übersicht aller 12 Bereiche.
- **Ansicht Dungeons** (NEU): Liste der Dungeons mit Level-Bereich, Passung, Zahl der Upgrades,
  erwartetem Zuwachs je Lauf, Quest-Zuwachs; oben die Empfehlung "Nächster Dungeon" mit Begründung;
  Auswahl zeigt Bosse mit ihren Upgrades (Zuwachs, Rate mit Kill-Zahl, Besitz, Wunsch) und die
  Dungeon-Quests mit bester Belohnung; Knopf Wegpunkt zum Eingang.
- **Ansicht Hier:** wie 1.8, mit Raten aus Beobachtungen.
- **Seite "Werkzeuge", Abschnitt Drop-Daten:** Zahl der Kills (eigene/gehörte), Bosse, neuester
  Tag, letzter Austausch, Schalter Teilen, Knopf "Drops für die Website" (Textfeld zum Kopieren).
- **Tooltip:** an Items mit Beobachtung eine graue Zeile "Gilde: 9 von 41 Kills (Faldrim
  Ambossmahl)" (`drops.tooltip`, Standard an), geschützt wie die Upgrade-Zeile.
- **Übersicht, Karte "Deine Ausrüstung":** zusätzlich "Nächster Dungeon: Halle der Thane".

## Einstellungen

| Pfad | Typ | Standard | Text |
|---|---|---|---|
| bis.suffix | choice best/base | best | "Zufallsboni" ("bester gesehener", "nur Grundwerte") |
| bis.sets | toggle | an | "Setboni werten" |
| bis.effortTie | slider 0-10 | 3 | "Gleichstand für Aufwand (Prozent)" (Experte) |
| bis.liveWeights | toggle | aus | "Gewichte aus deinen Charakterwerten" (Experte) |
| bis.hitCap | toggle | an | "Trefferwertung nur bis zur Grenze" |
| drops.record | toggle | an | "Boss-Loot in Dungeons und Raids aufzeichnen" |
| drops.share | toggle | an | "Drop-Daten mit der Gilde teilen" (Tip: "ohne Namen, nur außerhalb von Instanzen") |
| drops.tooltip | toggle | an | "Dropraten der Gilde im Tooltip" |

Der Waffenplan ist Charakterzustand (`chars[me].plan`), kein Schema.

## Befehle

| Befehl | Wirkung |
|---|---|
| `/amisia dungeon` (Alias `dungeons`) | Ansicht Dungeons |
| `/amisia dungeon naechster` | Empfehlung mit Begründung im eigenen Chat |
| `/amisia bis vergleich <Link> <Link>` | Vergleich zweier Items im eigenen Chat |
| `/amisia bis gewichte` | Gewichte und Bezugswerte der eigenen Spec im eigenen Chat |
| `/amisia drops` | Status der Drop-Daten |
| `/amisia drops export` | Werkzeuge, Text "Drops für die Website" |

## Ereignisse und APIs

Vor der Umsetzung in den Forever-Quellen (1.60.1, `Blizzard_APIDocumentationGenerated`, FrameXML)
zu prüfen; Typprüfung, fehlende Funktion -> Teil fällt still weg.

| API / Ereignis | Verwendung | Rückfall |
|---|---|---|
| `LOOT_OPENED`, `GetLootSourceInfo`, `GetLootSlotLink`, `GetLootSlotInfo` | Kill-Datensatz | - |
| `ENCOUNTER_END`, `BOSS_KILL` (über RaidLog.lua) | Boss erkennen, Rückfall-Kennung | nur NPC- und Qualitätsregel |
| `GetInstanceInfo`, `IsInInstance`, `InCombatLockdown` | Ort, Sendebedingungen | - |
| `GetServerTime` | Tag, Zeitkorb | `time()` |
| `C_QuestLog.IsQuestFlaggedCompleted` | erledigte Dungeon-Quests | Quests gelten als offen |
| `GetCritChanceFromAgility`, `GetSpellCritChanceFromIntellect`, `GetAttackPowerForStat` | Live-Gewichte, Prüfung der Umrechnungen | Tabellenwerte |
| `GetCombatRatingBonus`, `GetHitModifier`, `GetSpellHitModifier` | Trefferwert-Grenze | linear |
| `C_Item.GetItemStats` mit Link (Bonus) | Tooltip und Besitz mit Bonus | Grundwerte |
| `CHAT_MSG_ADDON`, `C_ChatInfo.SendAddonMessage` (über Comm.lua) | Austausch | - |

## Leistung

- **Im Spiel:** `Gear.Best` läuft über rund 4.000 Items mit dem vorhandenen Speicher je
  Klasse/Spec/Gewichtung (eine Wertung je Item und Level). Setplan: nur Sets mit zwei oder mehr
  Teilen in den Kandidaten, höchstens 2 Sets, linear. Zufallsboni: höchstens die gesehenen Boni je
  Item (meist unter 10), nur für Items, die nach Grundwerten mindestens 80 % der besten Option
  erreichen. Dungeon-Planer: ein Index Ort -> Items wird einmal beim Laden gebaut; je Aufruf eine
  `Gear.Best`-Rechnung plus `ns.BisGain` für die Items der Dungeons im Level-Fenster (etwa 15
  Dungeons, unter 1.000 Items); Ergebnis bis zum nächsten `ns.BisStamp`-Wechsel gespeichert.
  Drop-Raten: Summen je NPC werden bei neuen Datensätzen fortgeschrieben, nicht bei jeder Anzeige
  neu gezählt. Ziel: unter 50 ms je volle Neuberechnung, im Test mit dem echten `GearData.lua`
  gemessen (Lua-Zeit im Testlauf als Grenze 4x davon, damit langsame Rechner Luft haben).
- **Vorrechnen (build_bis.py):** 22 Specs x 2 Gewichtungen x 60 Level. Gespeichert werden nur
  Änderungen: je Spec, Gewichtung und Slot eine Liste `[ab Level, Option1, Option2, Option3]`, eine
  neue Zeile nur, wenn sich die drei ändern; dazu je Option Fraktion und Quelle. Erwartet unter 400 KB
  (das Skript meldet die Größe; über 800 KB bricht der Bau ab). Faction-Varianten als Markierung an
  der Option, die Seite filtert und rückt nach (darum je Slot bis zu 5 statt 3 gespeichert).
- **Austausch:** siehe Grenzen; pro Sitzung höchstens 60 KB gesendet.

## Fehlerbehandlung

- Alles in Lootfenster-, Tooltip- und Nachrichten-Pfaden läuft in `pcall`, Fehler gehen an
  `geterrorhandler`; ein Fehler in Drops.lua verliert höchstens den einen Kill.
- Geheime Werte (GUID, Name, Link) -> übersprungen; Kill ohne GUID nur über die Rückfall-Kennung.
- Kaputte oder zu große Blobs werden ganz verworfen (wie 2.1), in der Fehlersuche gezählt.
- Fehlt `ns.BIS` (BisData.lua nicht geladen): Wertung wie 1.8 ohne Setboni, Zufallsboni,
  berechnete Werte und Dungeon-Fakten; der Dungeon-Planer zeigt "Keine Dungeon-Daten.".
- Gewichte-Herleitung im Bau: ein negatives Gewicht für eine Hauptwertung, ein nicht
  konvergierender Fixpunkt oder eine Prüfquote der berechneten Werte unter 98 % brechen den Bau mit
  Meldung ab (bzw. lassen `SC` weg).
- Website: kaputte `DK`-Zeilen werden gezählt und ignoriert; Import-Fehler zeigen die Meldung von
  Supabase wie die anderen Importe.

## Tests

Lua (`addon/tests`, Stub ergänzt: Lootfenster mit Quell-GUID und `GetLootSlotInfo`, `GetServerTime`,
`ENCOUNTER_END`, Charakterwerte für Live-Gewichte, `C_QuestLog`; Mehr-Client-Läufe wie 2.1):

- `test_bis_weights.lua`: `Gear.Score` mit den neuen Gewichten; Teile-Summe = Wertung; Setbonus ab
  Schwelle, ungewerteter Bonus; Zufallsbonus bester gesehener vs. Grundwert; Waffenplan 2H/DW/SHIELD;
  Treffer über der Grenze 0 mit API, linear ohne; Aufwand ordnet nur im Gleichstand; `ns.BisCompare`.
- `test_bis_sim.lua`: `ns.BisFor` für fremde Klasse/Level; Planertabelle nutzt es; berechnete
  Werte nur ohne Scan.
- `test_dungeons.lua`: Wert je Dungeon, Quests nur offen und mit passender Fraktion, Passung,
  Empfehlung, kein Treffer, Raid ab 60, Raten mit und ohne Beobachtung.
- `test_drops.lua`: Kill aus Lootfenster (Boss über D-Quelle, über Ereignis, über Qualität), Trash
  nicht; zweites Öffnen zählt nicht doppelt; Kill ohne Items; Rückfall-Kennung; geheime Werte;
  Aufbewahrung 28 Tage und 4000; Umzug zweimal; Export-Text (Kopf, Zeilen, keine Namen in Zeilen).
- `test_drop_sync.lua` (mehrere Clients): `DV` nach Login, Ziehen über `DQ`/`DI`/`DR`, nur Fehlendes
  wandert, zwei Clients mit demselben Kill zählen ihn einmal, Vereinigung ist reihenfolgeunabhängig
  und idempotent, Nicht-Mitglied wird ignoriert, nichts in Instanz/Kampf/Sperre/Raid-Sync, Grenzen
  (ein offener `DR`, 20 Teile, 60 KB), `opts.low` hinter Raid-Daten, kaputter Blob verworfen, ein
  2.1-Client ohne die Typen bleibt unberührt.
- `test_perf_bis.lua`: volle Neuberechnung mit dem echten `GearData.lua`/`BisData.lua` unter der
  Zeitgrenze.
- Bestehende Tests bleiben grün (`test_gear.lua`, `test_bis_*.lua`, `test_sync*.lua`, `test_need.lua`,
  `test_export.lua`, `test_pages.lua`).

Python/Node (`tools/tests`):

- `test_build_bis.py`: CSV-Auszug aus Fixture-CSVs; Gewichte-Herleitung (Vorzeichen, Einheit = 1,
  Fixpunkt konvergiert, Tank-EH-Ableitung, Hardcore > Speedrun bei Ausdauer); berechnete Werte
  gegen gescannte Fixture-Items (98-%-Regel, Abbruch darunter); Setboni; Zufallsboni-Pools nur aus
  Beobachtungen; Dungeon-Fakten; Ausgabe mit Kopf, Wächter, gültigem Lua; zweimal bauen gleich;
  Größe von `bis-forever.js` unter der Grenze.
- `test_score_parity.py`: Python-Wertung und `Gear.Score` (über `lupa`) auf 200 Fixture-Items je
  Spec gleich auf 0,01.
- `test_build_scan.py` (ergänzt): Kill-Datensätze aus SavedVariables und `--obs`, Archiv vereinigt,
  `obsThrough`, Raid-Zone entsteht aus `DZ`.
- `test_build_gear.py` (ergänzt): keine fremden Gewichte mehr gelesen; D mit NPC-ID; Questketten.
- `test_export_format.py` (ergänzt): das Addon schreibt `DZ`/`DN`/`DK`, `amParseDrops` liest alle
  Felder; jeder geschriebene Buchstabe hat einen Leser; Raid-Export mit und ohne Drops gleich.
- `site_drops.cjs` mit `test_drop_import.py`: Vereinigung nach Kennung, zweimal importieren gleich,
  Stichtag gegen Doppelzählung, Zone aus `dropZones`, Raten-Text.
- Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review).

## Vorschlag für den Plan (8 Aufgaben)

1. **Gewichte und Spieldaten (N100):** `tools/build_bis.py` Teil 1: CSV-Auszug
   (`bis_gamedata.json`), Umrechnungen, Herleitung der Gewichte mit Fixpunkt, 12 Bereiche,
   `GearWeights.lua` neu mit eigenem Kopf; `build_gear.py` ohne fremde Gewichte; `tools/README.md`;
   `test_build_bis.py` (Gewichte), `test_build_gear.py`.
2. **Werte, Sets, Zufallsboni, Dungeon-Fakten (N100):** `build_bis.py` Teil 2: berechnete Werte mit
   Prüfquote, `SET`, `RS`/`RP`, `forever_dungeons.json`, `DG`, Aufwand `EF`, Ausgabe `BisData.lua`,
   TOC; Tests.
3. **Wertungskern im Addon:** Gear.lua (Bereiche, Tabellen-Ratings, Waffenplan und Tempo, Setplan,
   Zufallsboni, berechnete Werte, Treffergrenze, Aufwand-Gleichstand, Teile), `ns.BisCompare`,
   `ns.BisFor`, Live-Gewichte, Planertabelle; `test_bis_weights.lua`, `test_bis_sim.lua`,
   `test_score_parity.py`.
4. **Drop-Aufzeichnung:** Drops.lua (Kill-Erkennung, Kennung, Namen, Aufbewahrung, Umzug, Raten mit
   Grundstock, Export-Text), Collect.lua-Anschluss, Befehl `drops`; `test_drops.lua`,
   `test_export_format.py`.
5. **Drop-Austausch:** Comm.lua (`DK`, `opts.low`), DropSync.lua (`DV`/`DQ`/`DI`/`DR`, Prüfsummen,
   Bedingungen, Grenzen, Vertrauen, Inhaltsprüfung); `test_drop_sync.lua`.
6. **Dungeon-Planer:** Dungeons.lua (Liste, Wert, Quests, Passung, Empfehlung, Wegpunkt), Befehl
   `dungeon`, Tooltip-Zeile der Raten; `test_dungeons.lua`, `test_perf_bis.lua`.
7. **Ansichten (nach dem Restyle):** Ziele-Ergänzungen, Simulation, Dungeons, Abschnitt Drop-Daten,
   Karte, Einstellungen; Seitentests.
8. **Website und Auslieferung:** `build_scan.py` (Archiv, Boss-Tabellen, `obsThrough`), `build_bis.py`
   Teil 3 (`data/bis-forever.js`), `index.html` (`amParseDrops`, Import, `dropObs`, Tabellen aus
   Beobachtungen, Download, Gear guide), `site_drops.cjs`, `BUILD_ID`, Twin bauen/veröffentlichen/
   stempeln; Version 2.3.0 (TOC, `ns.VERSION`), alle Tests
   (`~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
   `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs`),
   `tools/release_addon.sh`, unabhängige Prüfung.

Aufgaben 1, 2, 4 und 5 sind unabhängig voneinander; 3 braucht 1 und 2, 6 braucht 3 und 4, 7 braucht
den Restyle und 3 bis 6, 8 kommt zuletzt.

## Auslieferung

Version 2.3.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh`, im Spiel `/reload`. Vorher einmal auf dem PC `/amisia scan gear` und
`python tools/build_gear.py` (NPC-IDs der Bosse, Questketten); die CSVs von Hand laden; dann auf dem
N100 `build_bis.py` und `build_scan.py`.

## Nicht in 2.3

Links zu anderen Seiten (auch nicht als Text); Übernahme fremder BiS-Listen, Loot-Tabellen oder
Gewichte; Abrufe von Websites durch Skripte; Spielernamen in Drop-Daten; Trash-Drops im Austausch;
Kampfdaten oder Simulation von Rotationen; Edelstein- und Verzauberungsvorschläge; Upgrade-Marken an
Taschen und Questbelohnungen; "Kette" (Upgrades schrittweise virtuell anlegen); Mitbewerber in der
Gruppe im Dungeon-Wert.

## Später

- "Kette": Dungeons in Reihenfolge, jeder Lauf legt die erwarteten Upgrades virtuell an.
- Mitbewerber: Gruppenmitglieder mit Amisia nennen ihre Klasse/Spec (kurze Nachricht), der
  Dungeon-Wert teilt Items, die auch ihnen helfen.
- Zufallsboni-Pools von Items gleicher Art übertragen, wo ein Item noch keinen Wurf gesehen hat.
- Raten je Schwierigkeit getrennt, sobald Forever heroische Stufen hat.

## Offene Punkte

Nur im Spiel zu klären (kein Nutzer-Entscheid, Prüfauftrag nach dem ersten Release):

- Ob `GetLootSourceInfo` in Forever-Dungeons nach dem Kampf eine lesbare Leichen-GUID liefert (sonst
  Rückfall-Kennung) und ob `UnitName` von Bossen dort geheim ist.
- Ob `GetCritChanceFromAgility`, `GetSpellCritChanceFromIntellect`, `GetAttackPowerForStat`,
  `GetCombatRatingBonus` auf Forever da sind und zu den Tabellenwerten passen (`/amisia bis gewichte`
  zeigt beides nebeneinander).
- Ob Forever Zufallsboni als ältere Eigenschaften oder als budgetierte Suffixe führt (Link-Feld
  positiv oder negativ) und ob `C_Item.GetItemStats(link)` den Bonus mitzählt.
- Ob die Formel der berechneten Werte die 98-%-Prüfung gegen echte Scans besteht.
- Trefferwert-Grenzen gegen Gegner zwei Level höher (6 %/6 % angenommen).
- Ob Flüsterungen außerhalb von Instanzen auf Forever von der Drosselung ausgenommen sind (die
  Grenzen oben gelten so oder so).
- Instanz-IDs der neuen Dungeons und der Raids (kommen über `DZ` von selbst).
- Ob die hergeleiteten Gewichte für die Gilde stimmige Reihenfolgen ergeben (Stichprobe je Rolle;
  Änderungen gehen in die Parameter des Skripts, nicht in die Datei).

Aus der Umsetzung der Teile ohne CSV (Aufgabe 7 Drop-Daten, Aufgabe 8 Website und `build_scan.py`,
2026-10-06):

- `data/forever.js` trägt die Beobachtungen in eigenen Schlüsseln neben `zones`/`bosses`/`items`:
  `obsBosses` (je Boss `{npc, name, zone, kills, obs}`), `obsZones` (mit `inst` und `kind`),
  `obsItems` (gescannte Namen beobachteter Items außerhalb der Loot-Tabellen) und `obsThrough`.
  So erneuert `build_scan.py` ohne SavedVariables-Datei nur diese Schlüssel an Ort und Stelle (Archiv
  aus `~/addons/_SavedVariables/Amisia.lua`, falls vorhanden, `--obs` und `--drops`), der Katalog des
  letzten vollen Baus bleibt. Die Website zeigt die Tabellen im neuen Reiter "Loot Tables".
- `DK`-Zeilen tragen keine encounterID: Rückfall-Datensätze (`src = "E"`, NPC 0) kann die Website
  keinem Boss zuordnen; sie bleiben im Archiv und in `dropObs`, zählen aber in keiner Tabelle. Falls
  das im Spiel häufig ist (siehe GUID-Frage oben), bräuchte `DK` ein Feld für die Begegnung.
- Der Twin behält Import und Download der Drops: er speichert das Ledger selbst (data.json), eine
  Datenbank braucht keiner der beiden.

Entschieden: eigene Gewichte statt der CC-BY-NC-SA-Gewichte; keine Links und keine Daten fremder
Seiten; Drop-Austausch an, ohne Namen, nur Gildenmitglieder, Vereinigung statt Überschreiben;
Aufwand nur als Gleichstandsregel; Zufallsboni mit dem besten gesehenen Wurf; Website zeigt
Beobachtungen mit Kill-Zahl.

### Offene Frage an den Nutzer

- **SavedVariables von Amisia zurück auf den N100?** Syncthing sendet heute nur die SavedVariables
  eines anderen Addons zurück. Kommt `Amisia.lua` ebenso nach `~/addons/_SavedVariables/`, laufen
  `build_scan.py` (Drop-Archiv, `data/forever.js`) und die Zufallsboni-Pools ganz auf dem N100; sonst
  braucht jeder Datenstand einen Lauf auf dem PC oder den Website-Download.
- **Bestehende Item-Links der Website:** heute verlinken Items auf der Website schon auf eine
  externe Item-Datenbank (Forever-Pfad, Tooltip-Skript). 2.3 fügt keine Links hinzu und lässt diese
  stehen. Soll "keine Links auf fremde Seiten" auch diese bestehenden Item-Links entfernen?
- Nutzer-Handgriff (keine Frage): die CSV-Liste oben einmal je Forever-Build bei wago.tools im Browser
  herunterladen und nach `tools/wago/<build>/` legen.

## Nachtrag 2026-10-06: Aufgaben 1 bis 3 mit den echten Client-Tabellen

Umgesetzt mit den wago-CSVs von Forever 1.60.1.70235 (`ItemSparse`, `Item`, `ItemSet`, `SpellEffect`,
`SpellItemEnchantment`, `RandPropPoints`, `LFGDungeons`, `UiMapAssignment`). Abweichungen vom Entwurf:

- **Ordner:** die CSVs liegen in `~/addons/_wago` (Syncthing-Ordner `amisia-wago`, nur empfangen),
  nicht in `tools/wago/<build>/`; `build_bis.py --wago` liest von dort, die Dateien heißen
  `<Tabelle>.<build>.csv`. Committet wird nur der Auszug `tools/bis_gamedata.json`.
- **Nicht auf wago für Forever:** `ItemRandomProperties`, `ItemRandomSuffix` und alle `gt*`-Tabellen
  (`gtChanceToMeleeCrit(Base)`, `gtChanceToSpellCrit(Base)`, `gtCombatRatings`, `gtRegenMPPerSpt`). Noch
  nicht geladen, aber vorhanden: `ItemSetSpell` (Setboni) und `ContentTuning` (Level der
  Classic-Dungeons aus `LFGDungeons`); das Skript liest sie, sobald sie im Ordner liegen.
- **Umrechnungen ohne gt-Tabellen:** Beweglichkeit und Intelligenz je Prozent Krit, Rating je Prozent
  (Kurve `(L-8)/52` wie bisher) und Mana je Willenskraft sind dokumentierte Standardwerte im Skript
  (Classic-Werte, Konstanten mit Kommentar). Messungen im Spiel ersetzen sie: `tools/bis_measured.json`
  mit `samples` (Rohwerte: `level`, `class`, `agi`, `int`, `crit`, `spellcrit`, je Rating
  `cr_<ART>=<Rating>:<Bonus %>`, wie sie der Abschnitt "Werte" des Selbsttests als `AMISIA-WERTE`-Zeile
  ausgibt; `build_bis.py --werte "<Zeile>"` trägt sie ein) und `overrides` (`rating60`,
  `agiPerCritScale`, `intPerCritScale`, `manaPerSpirit5`). Eine Messung korrigiert die Kurve einer Klasse
  um ihr Verhältnis zum Standard. Die benutzten Ratings stehen als `ratings` in `GearWeights.lua`;
  Gear.lua rechnet damit.
- **Zufallsboni nur aus Beobachtung:** ohne `ItemRandomProperties`/`ItemRandomSuffix` gibt es kein `RS`
  (Anteile mal Budget). Der Sammler speichert stattdessen je Item und Bonus-ID die vollen Werte, die
  `C_Item.GetItemStats(link)` für den Link nennt (`AmisiaDB.scan.suffix[item][bonus]`, höchstens 12 je
  Item, 1500 Items); `build_bis.py` übernimmt die der SavedVariables als `RP[item][bonus] = "Werte"`,
  Gear.lua liest beide. Gewertet wird der beste gesehene Wurf (`bis.suffix`).
- **Berechnete Werte nur für Rüstung und Schmuck:** Waffen (Schaden braucht Schadenstabellen) und
  Schmuckstücke (Anlegeeffekte stehen in `ItemEffect`) bekommen kein `SC`; sie zählen auch nicht in der
  98-%-Prüfung. Stand: 100 % von 1.138 geprüften Items exakt, 223 Items mit `SC`. Unbekannte Stat-IDs
  und Widerstände werden ausgelassen.
- **Setboni:** `SET` hat die Teile aus `ItemSet`; ohne `ItemSetSpell` sind alle Boni `""` (nicht
  gewertet), der Setplan greift erst mit der Tabelle. Bonus-Effekte gelesen: Attribut, Rüstung,
  Angriffskraft, Distanzangriffskraft, Zauberschaden (alle Schulen), Heilung, Mana alle 5 Sek.
- **Dungeons:** `DG` = die Fakten aus `forever_dungeons.json` plus `bosses` als NPC-IDs aus
  AllTheThings' Forever-Daten (Bosse je Instanz; in einer Instanz mit mehreren Dungeons nur, wo die
  Item-Daten oder Fakten den Boss nennen) und `bossNames` (NPC -> englischer Name). Bossnamen ohne
  passende ID bleiben als Name stehen. Dungeons.lua hängt die NPC-ID über `bossNames` an den
  gleichnamigen Boss der Item-Daten; Drops.lua erkennt damit Boss-Kills ohne seltenes Item und ohne
  Kill-Ereignis. Instanz-IDs liefert `UiMapAssignment` nur für Außengebiete, `LFGDungeons` ohne MapID:
  sie kommen weiter über die Drop-Aufzeichnung.
- **BisData.lua** hat keinen `IsForever`-Wächter mehr (das Addon ist nur noch Forever, die TOC-Bedingung
  `[AllowLoadGameType camelot]` reicht).
- **Herleitung, genauer als oben:** Schaden je Sekunde `(wDPS + AP/14) * (1 + r*s) * (1 + c) * t` mit
  `r` Spezialangriffen je Sekunde, die je einen Schlag Waffenschaden tragen (Classic: Tempo `s` zählt),
  also Waffentempo = `14 * r * B / (1 + r*s)` je Sekunde über dem Bezugstempo (`SPDREF_2H` 3,3,
  `SPDREF_MH` 2,6, `SPDREF_RANGED` 2,8; Gear.lua rechnet `SPEED - SPDREF`). Krit ohne den Faktor des
  Entwurfs, sondern als Ableitung derselben Formel `14 * 0,01 * B / (1 + c)`. Zauber: Manawert über den
  Manavorrat (`Anteil Mana knapp * (B + k*SP) / (k * Vorrat)`), Zauberanteil an der Zeit 0,6 (Heiler
  0,4) für Mana alle 5 Sek. und Willenskraft. Speedrun enthält 10 %, Hardcore 30 % der Tank-Sicht auf
  Ausdauer, Rüstung und Vermeidung (in Einheiten über "ein Budgetpunkt = 2 AP / 1,2 Zauberschaden /
  2,2 Heilung"); Klassen ohne Mana bekommen Willenskraft als kürzere Pausen. Der Fixpunkt rechnet
  bis zu 16 Runden mit kleiner werdendem Schritt (wo die beste Ausrüstung zwischen zwei Sets kippt,
  pendeln die Gewichte sonst); stoppt eine Runde nicht unter 1 %, bricht der Bau ab.
- **Treffergrenze im Spiel:** 6 % für Waffen und Zauber, eigener Wert über
  `GetCombatRatingBonus(6/8)` plus `GetHitModifier`/`GetSpellHitModifier`, je Zeile gegen das
  Angelegte; ohne API linear mit dem Hinweis "Trefferwertung zählt ohne Obergrenze".
- **Ansichten:** Waffenplan-Auswahl rechts neben den Quellen-Chips (Ziele), Hinweise an den Optionen
  ("Set 2/5, +18 Bonus", "berechnet", "bester gesehener Bonus", "leichter zu bekommen"), Vergleich
  Option 1 gegen 2 und gegen das Angelegte beim Überfahren der Erklärung, Knopf "Warum?" (Begründung,
  Einheit, Bezugswerte) und Knopf "Simulation" (eigene Ansicht `sim`: Klasse, Spec, Level, Waffenplan;
  17 Slots aus `ns.BisFor`). Die Planertabelle rechnet über `ns.BisFor`. Befehle `/amisia bis
  vergleich`, `gewichte`, `plan`, `sim`.
- **Noch offen:** `bis.liveWeights` (Gewichte aus den eigenen Charakterwerten) ist nicht umgesetzt;
  `data/bis-forever.js` und der Reiter "Gear guide" gehören zu Aufgabe 8. `tools/build_gear.py`
  schreibt `GearWeights.lua` noch, wenn auf dem PC die Gewichte des fremden Leveling-Guides
  installiert sind; dieser Teil muss aus `build_gear.py` heraus (sonst überschreibt ein PC-Lauf die
  eigenen Gewichte).
- **Erste Messungen im Spiel (2026-10-06, `tools/bis_measured.json`):** Schamane 18 mit und ohne ein
  Beweglichkeits-Item (35 -> 33 Beweglichkeit, Krit 11,563 -> 11,3354 %): 8,79 Beweglichkeit je 1 %
  Krit (Classic-Kurve mal 1,46) und 7,58 % Krit bei 0 Beweglichkeit (Grundwert mit Talenten, statt
  Classic 1,7 %; gilt für den Schamanen auf allen Leveln). Ausweichen steigt je Beweglichkeit genauso.
  Eine einzelne Messung legt weder Verhältnis noch Grundwert fest (Paladin 9, Jäger 5: nur zur
  Prüfung, `unpinned`). Klassen ohne eigene Steigung nehmen den Faktor der gemessenen (Annahme:
  Forever ändert die Kurve für alle Klassen um denselben Faktor, die Form `max(Level, 10) / 60` bleibt
  Classics); der Paladin-9-Punkt liegt damit unter 1 % Krit daneben. Zauberkrit je Intelligenz und
  die Ratings sind noch ungemessen (alle Ratings 0 in den Zeilen). Angriffskraft bestätigt: Schamane
  und Paladin 2 je Stärke, 0 je Beweglichkeit; Jäger im Nahkampf 1 je Stärke und Beweglichkeit, Distanz
  2 je Beweglichkeit - 10 ohne Levelanteil (Formel angepasst). Der Schamane hat 16 Angriffskraft mehr
  als `2*Stärke + 3*Level - 20`; Herkunft offen.
- **Weitere Messungen (2026-10-06):** Priester 23 mit und ohne einen Intelligenz/Willenskraft-Umhang:
  19,8 Intelligenz je 1 % Zauberkrit (Classic-Kurve mal 0,87), 0,80 % Zauberkrit bei 0 Intelligenz,
  15 Mana je Intelligenz, 0,625 Mana je Willenskraft und 5 Sek. (genau der Classic-Wert). Der Nahkampfkrit
  dieses Paars fiel ohne Änderung der Beweglichkeit (ungeklärt) und zählt nicht. Klassen ohne eigene
  Messung nehmen für Intelligenz den Faktor des Priesters. Krieger 15 mit und ohne ein
  Stärke/Ausdauer-Item: 2 Angriffskraft je Stärke, 10 Gesundheit je Ausdauer, Krit und Vermeidung
  unverändert (bestätigt das Modell). Prüfpunkte gegen die Schätzung mit dem Schamanen-Faktor:
  Krieger 15 4,5 % geschätzt gegen 5,1 % gemessen, Paladin 9 5,4 % gegen 4,6 %; Jäger 5 1,9 % gegen
  5,4 % (die Jäger-Kurve von Classic, 53 Beweglichkeit je % bei 60, passt bei Level 5 nicht; Jäger
  brauchen eine eigene Steigung). `ITEM_MOD_SPELL_POWER_SHORT` gibt es auf Forever-Items (gesehen an
  einem Umhang mit Zufallsbonus); es zählt als Zaubermacht für Zauberschaden und Heilung, und
  `GetItemStats` mit einem Link liefert die Werte des Zufallsbonus mit.
