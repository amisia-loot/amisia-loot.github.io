# Amisia 1.8: BiS-Abgleich (Ziele je Slot, Wunschliste, Upgrade-Hinweise)

Stand 2026-10-05. Baustein 3 von 7 (Reihenfolge der Umsetzung laut Nutzer: 5, 4, 6, 3, 2, 7).
Baut auf Baustein 1 (`docs/superpowers/specs/2026-10-04-amisia-main-window-design.md`: Registry,
Widgets, Hauptfenster, Seiten, Karte "Deine Ausrüstung"), dem Ausrüstungsplaner aus 1.3 (`Gear.lua`,
`GearFrame.lua`, `GearData.lua`, `GearWeights.lua`, `tools/build_gear.py`), Baustein 4
(`docs/superpowers/specs/2026-10-05-amisia-loot-sr-design.md`: Tooltip-Zeile der Soft-Reserves,
SR-Marke an Lootfenster und Würfelfenstern, `ns.IsLootLead`, `ns.SameNameIn`) und Baustein 5
(`docs/superpowers/specs/2026-10-05-amisia-awards-design.md`: Vergabe-Dialog, Exportregel) auf.
Ändert das Addon `addon/Amisia`, `tools/build_gear.py`, ein neues Erzeugungsskript
`tools/build_bis.py` und die Wunschliste der Seite `index.html`.

## Ziel

Heute zeigt Amisia nur in WoW Forever, was ein Charakter beim Leveln tragen sollte: die Tabelle
`/amisia gear` und die Seite "Ausrüstung" mit dem besten Item je Slot gegenüber dem Angelegten. In
TBC Anniversary, wo die Gilde raidet, gibt es nichts. Niemand sieht, welche Drops eines Raids für ihn
ein Upgrade sind, was er schon besitzt, und wenn ein gewünschtes Item droppt, merkt er es nur, wenn
er die Ansage liest. Offiziere sehen beim Vergeben nicht, wer sich ein Item gewünscht hat, obwohl
die Wunschliste auf der Website steht.

"BiS-Abgleich" heißt in Amisia: **das Beste, was dein Charakter aus den Tabellen des Addons bekommen
kann, nach Amisias eigener Wertung, abgeglichen mit dem, was du schon hast.** Keine fremden
BiS-Listen. Baustein 3 bringt:

- **Ziele je Slot:** die drei besten Optionen pro Slot (nicht nur ein BiS-Item) für Klasse und
  Spezialisierung, mit Quelle, Zuwachs gegenüber dem Angelegten und Haken für alles, was du schon
  hast (angelegt, Taschen, Bank). Auf beiden Clients: TBC Anniversary (Raids, Heroics, Dungeons, Ruf,
  Abzeichen, Berufe, Level 70) und Forever (Leveln und Pre-Raid aus den Planerdaten, Level 1-60).
- **Ausschließen:** ein Item, einen Boss oder einen Ort ausschließen, die nächste Option rückt auf.
  Filter für Fraktion (automatisch), Berufe (alle oder nur deine), Quellenarten und in TBC die Phase.
- **"Hier":** was du in diesem Raid, Dungeon oder Gebiet noch holen kannst (oder in einem gewählten
  Ort, zum Planen).
- **Wunschliste:** Items merken; ein Hinweis (Toast) mit Ton, sobald ein Wunsch im Lootfenster, an
  einem Würfelfenster oder in der Loot-Ansage der Lootleitung auftaucht. Erhaltene Wünsche gehen von
  selbst weg. Dazu ein Hinweis für angesagte Upgrades, die nicht auf der Wunschliste stehen.
- **Tooltip-Zeile** "Upgrade für dich: +14 (Brust)" an jedem Item-Tooltip, geschützt, sodass sie
  nie andere Tooltips bricht.
- **Erklärte Wertung:** jede Zahl lässt sich aufschlüsseln ("30 Stärke x 2,0 = 60 ...").
- **Brücke zur Website-Wunschliste, ohne Sync:** Raider geben ihre Wünsche als Text an die Website;
  Offiziere holen die Wunschliste der Website als Text ins Spiel und sehen beim Loot, wer sich das
  Item wünscht (Tooltip, Lootfenster-Marke "W", Vergabe-Dialog).

## Rahmen und Entscheidungen

- **Clients, Bibliotheken, Schrift, Fensterebenen, Offiziersansicht:** wie Baustein 1, 4, 5 und 6.
  Ein TOC (`20506, 16001`), keine fremden Bibliotheken, kein `UIDropDownMenu`/`EasyMenu`, UI- und
  Chat-Texte deutsch und nur Latin-1 (ä ö ü ß und "·", kein Gedankenstrich, keine
  Auslassungspunkte, keine Pfeile), Code-Kommentare englisch, Texte der Website englisch. Anmeldung
  nur über `ns.RegisterPanel`, `ns.RegisterCard`, `ns.RegisterSettings`, `ns.RegisterSlash`;
  Offiziersteile über `ns.IsOfficerView()`. Alles in den Gruppen-Chat über `ns.Say` (Baustein 3
  schreibt dort nichts), eigene Meldungen über `ns.msg`. Werte aus Ereignissen gehen durch
  `ns.Plain`. Forever hat kein globales `GetItemInfo`/`GetItemInfoInstant`: alle neuen Dateien nehmen
  den `C_Item`-Shim wie Core.lua. Namen vergleichen über `ns.SameNameIn` mit `ns.GroupRoster()`.
- **Keine anderen Addons nennen**, weder in UI-Texten, Chat-Texten, Kommentaren noch Commits. Im
  Entwurf heißen sie "andere Ausrüstungs-Addons". Datenquellen (AtlasLootClassic, QuestieDB,
  RestedXP-Gewichte, OneForAll) werden nur dort genannt, wo die Lizenz es verlangt: im Kopf der
  erzeugten Dateien, in `tools/README.md` und in diesem Entwurf.
- **Keine BiS-Listen von Websites.** Kuratierte BiS-Listen der bekannten Seiten sind deren Werk,
  ihre Bedingungen verbieten das Abgreifen (Wowhead sperrt Bots per robots und Bedingungen; eine
  Forever-Datenseite verbietet das Kopieren ihrer Sammlung ausdrücklich). Amisias "BiS" ist das
  Ergebnis der eigenen Wertung über die eigenen Tabellen. Das ist ehrlich erklärbar ("bestes Item
  nach Amisias Gewichtung") und lässt sich pro Spezialisierung nachrechnen.
- **Eine Logik, zwei Datensätze.** `Gear.lua` (Wertung, beste Items, Quellen) bleibt der Kern. Auf
  Forever liefern `GearData.lua`/`GearWeights.lua` die Daten wie heute, auf Anniversary die neuen,
  erzeugten `BisDataTBC.lua`/`BisWeightsTBC.lua`. Beide füllen dieselben Tabellen `ns.GEAR` und
  `ns.GEAR_WEIGHTS`, mit `game = "forever"` bzw. `"tbc"` und `cap = 60` bzw. `70`. Auf jedem Client
  lädt nur ein Satz (TOC-Bedingung plus Wächter in der Datei, siehe "Datenquellen").
- **Der Planer bleibt Forever.** Die Tabelle `/amisia gear` (Levelbereiche 1-60) ergibt für TBC
  keinen Sinn; sie und der Einstellungsabschnitt "Ausrüstung" (Speedrun/Hardcore) prüfen künftig
  `Gear.Game() == "forever"`. Die Seite "Ausrüstung" gibt es auf beiden Clients.
- **Nur der eigene Charakter.** Die Ziele gelten für den eingeloggten Charakter (Klasse fest,
  Spezialisierung wählbar). Andere Klassen und Level simuliert weiter nur die Forever-Tabelle.
- **Forever-Haltung:** Blizzards Linie für Forever lautet: Informationen anzeigen ist erlaubt,
  versteckte Daten ausrechnen oder erraten nicht (gemeint sind Kampfdaten). Amisia wertet nur, was
  der Client jedem Spieler im Item-Tooltip zeigt (`C_Item.GetItemStats` liefert genau diese Werte),
  mit festen Gewichten, wie es ein Spieler mit Taschenrechner auch täte. Es liest keine Kampfdaten,
  keine geheimen Werte, nichts während eines Bosskampfs, und es rät keine Dropchancen (gezeigt wird
  nur, was die Quelldaten nennen). Das bleibt im erlaubten Bereich.
- **Besitz:** angelegt (live), Taschen (live) und Bank (beim Öffnen der Bank gemerkt, dazu
  `C_Item.GetItemCount(id, true)`, das die Bank aus dem Speicher des Clients mitzählt). Ein Item, das
  du besitzt, bekommt einen Haken und zählt in "Ziele" als erledigt; die nächste Option rückt nicht
  auf (du hast ja das Beste), außer du legst es nicht an, dann bleibt der Zuwachs sichtbar.
- **Wunschliste je Charakter, lokal.** Höchstens 50 Wünsche. Wer will, gibt sie als Text an die
  Website (neue Zeile `WL`). Die Website bleibt der gemeinsame Ort, an dem Offiziere alle Wünsche
  sehen.
- **Offiziersansicht ohne Sync:** Was andere Raider angelegt haben, kann ein Client nicht wissen
  (Inspizieren hat Reichweite und Drosselung, und auf Forever sind Einheiten-APIs in Instanzen
  heikel; deshalb kein Inspizieren). Ohne Sync sieht der Offizier im Spiel, **wer sich ein Item
  gewünscht hat** (aus der Website importiert) und wer es reserviert hat (Soft-Reserves, schon da).
  "Für wen ist dieser Drop ein Upgrade?" aus den eigenen Rechnungen der Raider kommt mit Baustein 7:
  jeder Raider-Client meldet dann auf eine Loot-Ansage, für welche Items er ein Upgrade hat.
- **Wünsche ändern keine Vergaberegel.** Sie stehen im Tooltip, als "W" am Lootfenster und zuerst
  im Vergabe-Dialog; die Roll-Reihenfolge (SR, MS, OS, +1) bleibt unverändert.
- **Exportregel** wie Baustein 5 und 6: bestehende Zeilen Byte für Byte gleich, neue Zeilenart mit
  zwei Buchstaben (`WL`), Kopf bleibt `#AMISIA 2`. Die Wünsche stehen nicht im Raid-Export, sondern in
  einem eigenen Text "Wunschliste für die Website"; der Raid-Export und `ns.SessionHash` ändern sich
  nicht.

## Dateien

```
tools/build_bis.py              NEU: erzeugt BisDataTBC.lua und BisWeightsTBC.lua (TBC-Itemliste aus
                                AtlasLootClassic, Tokens, Phasen, deutsche Bossnamen, eigene Gewichte)
tools/bis_atlas_tbc.json        NEU: Zwischenspeicher der gelesenen AtlasLootClassic-Tabellen
tools/bis_tbc_items.json        NEU, optional: Itemart, Level, Qualität, Klassen aus wago.tools-CSV
addon/Amisia/BisDataTBC.lua     NEU, erzeugt: ns.GEAR für TBC (Quellen, Items)
addon/Amisia/BisWeightsTBC.lua  NEU, erzeugt: ns.GEAR_WEIGHTS für TBC (Level 70, eigene Gewichte)
addon/Amisia/Gear.lua           Gear.Game/Cap, Sockel- und Abhärtungs-Schlüssel, Rating über 60,
                                Gear.ScoreParts, Ausschlüsse in Gear.Best, Zeilen aus dem Client
                                ergänzen (Gear.FillRow), Quellenarten X und F, Heroisch, Gear.PlaceOf,
                                Tooltip-Leser als Rückfall für GetItemStats
addon/Amisia/Bis.lua            NEU: Charakterdaten, Besitz, Ziele, Zuwachs, Ausschlüsse, Hier,
                                Wunschliste, Wunsch-Export, Tooltip-Zeile, Hinweis (Toast) und seine
                                Auslöser; Abschnitt "bis"; Befehle bis, wunsch
addon/Amisia/GuildWishes.lua    NEU: Import der Website-Wunschliste, ns.WishersOf, Tooltip-Zeile,
                                Lootfenster-Marke "W", Reihenfolge im Vergabe-Dialog; Befehl wuensche
addon/Amisia/Pages/Gear.lua     neu geschrieben: Seite "Ausrüstung" auf beiden Clients mit den
                                Ansichten Ziele, Hier, Wunschliste, Gilde; Karte "gear" für beide
addon/Amisia/GearFrame.lua      ns.GearMyUpgrades über ns.BisTargets; Planer und Abschnitt "gear" nur
                                Forever; Haken für Besitz in den Zellen; /amisia gear item geht auf
                                /amisia bis item
addon/Amisia/AwardDialog.lua    names(): Wünschende zuerst, Text "Anna (Wunsch hoch)"
addon/Amisia/Minimap.lua        Schnellmenü: "Ausrüstung" auf beiden Clients
addon/Amisia/Amisia.toc         BisDataTBC.lua, BisWeightsTBC.lua [AllowLoadGameType tbc] nach
                                GearWeights.lua; Bis.lua nach GearFrame.lua; GuildWishes.lua nach
                                Bis.lua; Version 1.8.0
tools/build_gear.py             Dungeon-Quellen mit Instanz- und Gebiets-ID; Forever-Raids aus
                                data/forever.js als Quellenart X, sobald es dort Raid-Zonen gibt
index.html                      Wunschliste: "Paste from the addon" (WL-Zeilen), "Copy for the addon";
                                amParseWishes; Import-Reiter: Hinweis bei WL-Zeilen
tools/README.md                 build_bis.py, Lizenzen, was den PC braucht
tools/tests/test_build_bis.py   NEU
tools/tests/site_wishes.cjs     NEU, mit tools/tests/test_wish_import.py
tools/tests/test_export_format.py   ergänzt: WL vom Addon bis zur Seite
addon/tests/*                   neue Tests, Stub ergänzt
```

Unverändert: Core.lua (Raid-Export), Rolls.lua, SoftRes.lua, LootAnnounce.lua (das Addon liest die
Ansage nur mit), RaidLog.lua, Bench.lua.

## Datenmodell

### Charakter (`AmisiaDB.bis`)

```lua
AmisiaDB.bis = {
  v = 1,
  chars = {                                -- Schlüssel ns.UnitFullName("player")
    ["Vulo Sturmwind"] = {
      class = "PRIEST",
      spec = "shadow",                     -- nil: aus den Talenten geraten (siehe "Spezialisierung")
      wish = {                             -- höchstens 50
        [28830] = { t = 1759601000, prio = 2, note = "" },   -- prio 3 hoch, 2 mittel, 1 niedrig
      },
      ex = {
        item  = { [28830] = true },        -- Item ausgeschlossen
        boss  = { ["Prinz Malchezaar"] = true },             -- Bossname wie in der Quelle
        place = { ["I:532"] = true, ["Z:1449"] = true },     -- I: Instanz-ID, Z: Gebiet (uiMapID)
      },
      bag  = { [28830] = 1759601000 },     -- in den Taschen gesehen (letzte Sichtung)
      bank = { [28830] = 1759601000 },     -- in der Bank gesehen
      bankAt = 1759601000,                 -- letzte Bank-Zählung, nil = nie
    },
  },
  guild = {                                -- importierte Website-Wunschliste (Offiziere)
    game = "tbc", date = "2026-10-05", at = 1759601000, by = "Vuloo", n = 42,
    list = { [28830] = { { name = "Anna", prio = 3, note = "nur MS" }, { name = "Bob", prio = 2 } } },
  },
}
```

- `note` bei Wünschen höchstens 40 Zeichen, ohne `|` und Zeilenumbruch (`ns.CleanNote(text, 40)`).
- `bag` und `bank` halten nur Item-IDs, die in `ns.GEAR.I` stehen oder angelegt werden können
  (kein Material, keine Quest-Items). Ein Eintrag, der beim nächsten Lesen fehlt, fällt weg.
- Die gespeicherten Wertungen bleiben im bestehenden Speicher `AmisiaDB.gear` (Schlüssel
  `v2/<built>/<client build>`); TBC hat ein eigenes `built` und damit einen eigenen Schlüssel.

### Umzug

Kein Versionszähler außer `v = 1`. Beim `ADDON_LOADED` (Bis.lua): `AmisiaDB.bis = AmisiaDB.bis or
{ v = 1, chars = {} }`. Der Eintrag des eigenen Charakters entsteht beim ersten Gebrauch; seine
Spezialisierung übernimmt dann `AmisiaDB.settings.gear.specs[class]` aus dem Forever-Planer, falls
gesetzt. Beim Laden werden geprüft: Wunsch-IDs Zahl, `prio` auf 1-3 begrenzt, Notiz gekürzt, mehr
als 50 Wünsche (die ältesten) entfernt; `guild.list` ohne Zahl-Schlüssel fällt weg. Zweimal laden
ändert nichts. Bestehende Daten (`settings.gear`, `AmisiaDB.gear`) bleiben, wie sie sind.

## Datenquellen und Erzeugung

### Forever (unverändert, plus zwei Ergänzungen)

`GearData.lua` und `GearWeights.lua` wie heute (Quellen und Lizenzen siehe `tools/README.md`:
QuestieDB GPL-3.0, AtlasLootClassic GPL-2.0, OneForAll, wowsrc.com, Amisias Item-Scan; DPS-Gewichte
von RestedXP unter CC BY-NC-SA 4.0, Heiler und Tanks eigene). `build_gear.py` liest die WoW-Installation
(QuestieDB, OneForAll, AtlasLoot, RXP, SavedVariables) und **läuft nur auf dem PC**. Baustein 3
ändert das Skript, laufen muss es danach auf dem PC:

- **Dungeon-Quellen mit Ort:** `D` bekommt Feld 5 Instanz-ID (aus AtlasLoots `InstanceID` bzw.
  Questies `instanceIdToAreaId`) und Feld 6 Gebiets-ID (`MapID`, eine areaID). Damit findet "Hier"
  den Dungeon über `GetInstanceInfo()`. Bis zur Neuerzeugung fehlen die Felder; "Hier" vergleicht dann
  den Instanznamen des Clients mit `rec[2]` (klappt nur, wo die Namen gleich sind; im Ort-Picker
  stehen die Dungeons trotzdem).
- **Forever-Raids:** Items aus `data/forever.js`, deren Quelle zu einer Raid-Zone gehört, kommen als
  Quellenart `X` dazu. Welche Zonen Raids sind, sagt ein neues Feld `"raid": true` in
  `tools/forever_zones.json` (heute Name -> Kürzel und Farben; die Forever-Raids Barrow Deeps,
  Hyjal Summit und Onyxia's Lair bekommen es, sobald sie dort stehen). Heute hat `data/forever.js`
  keine Raid-Zonen (die Raids öffnen nach dem Start am 2026-11-04); das Skript schreibt dann
  nichts Neues. Die Seite füllt die Tabelle, sobald Raids aufgezeichnet sind; danach auf dem PC
  neu erzeugen.

### TBC Anniversary (neu, `tools/build_bis.py`)

Läuft **auf dem N100** (keine WoW-Installation nötig); nur die optionalen deutschen Namen der
Dungeon-Bosse und der Item-Scan brauchen den PC.

```
python tools/build_bis.py [--refresh-atlas] [--item-csv <Item.csv> --itemsparse <ItemSparse.csv>]
                          [--wow-root <Pfad>] [--sv <Amisia.lua>...]
```

- **Itemliste und Quellen:** AtlasLootClassic (GitHub `Hoizame/AtlasLootClassic`, Lizenz GPL-2.0),
  nur die TBC-Dateien: `AtlasLootClassic_DungeonsAndRaids/data-tbc.lua` (Raids, Dungeons normal und
  heroisch, je Boss), `AtlasLootClassic_Factions/data-tbc.lua` (Ruf-Belohnungen mit Stufe),
  `AtlasLootClassic_Collections/data-tbc.lua` (Abzeichen-Händler je Phase, Welt-Epics),
  `AtlasLootClassic_Crafting/data-tbc.lua` (hergestellte Items mit Beruf und Fertigkeit),
  `AtlasLootClassic/Data/Token.lua` (Tier-Token -> Set-Teil je Klasse). `--refresh-atlas` lädt sie
  über `raw.githubusercontent.com` neu; geparst wird in `tools/bis_atlas_tbc.json` gespeichert (wie
  `gear_wowsrc.json`), damit der Bau ohne Netz und deterministisch läuft. Ausgelassen: PvP-Tabellen
  (Abhärtung), Feiertage, Reittiere, Haustiere, Wappenröcke, Rezepte selbst.
- **Tokens:** ein Token (z. B. "Brustschutz des gefallenen Verteidigers") ist kein tragbares Item.
  Jedes Set-Teil aus `Token.lua` bekommt die Quelle des Tokens (Raid, Boss) mit Token-ID und die
  Klassenmaske seiner Klasse; das Token selbst kommt nicht in die Liste.
- **Phase:** je Raid aus der Zuordnung der Website (`PHASES.tbc` in `index.html`: P1 kara, gruul,
  mag; P2 ssc, tk; P3 hyjal, bt; P4 za; P5 swp), im Skript als Tabelle über AtlasLoots
  Instanz-IDs; Abzeichen-Händler laut Tabellenname (`BadgeofJustice` 1, `BadgeofJustice4` 4,
  `BadgeofJusticeP5` 5); alles andere Phase 1.
- **Namen:** Item-Namen, Qualität und Symbol kommen im Spiel vom Client. Raid- und Dungeonnamen
  über die Gebiets-ID (`C_Map.GetAreaInfo(areaID)`, lokalisiert, beide Clients). Raid-Bossnamen
  deutsch aus `data/bossnames.js` (umgekehrt, `tbc`, 57 von 59), Dungeon-Bosse englisch aus
  AtlasLoot; mit `--wow-root` liest das Skript die deutschen Namen aus den Sprachdateien des
  installierten AtlasLootClassic (wie `build_bossnames.py`, nur PC).
- **Itemart:** ohne CSV bleibt in jeder Zeile Feld 1-7 leer (0); das Addon füllt Ausrüstungsplatz,
  Klasse und Unterklasse beim ersten Gebrauch aus `C_Item.GetItemInfoInstant` (sofort, aus der
  Client-Datenbank) und Level, Qualität, Bindung, Itemlevel aus `C_Item.GetItemInfo`, sobald der
  Lader das Item hat (`Gear.FillRow`). Nicht anlegbare Items (Edelsteine, Abzeichen, Muster) fallen
  dann im Spiel heraus. Mit `--item-csv`/`--itemsparse` (wago.tools, Export des Anniversary-Builds,
  wie schon `--itemsparse` in build_gear.py) füllt das Skript die Felder selbst, lässt Nicht-Ausrüstung
  weg und kennt Klassengrenzen und Waffentempo; die Auswahl wird in `tools/bis_tbc_items.json`
  gespeichert.
- **Werte (Stats)** kommen wie in Forever vom Client (`Gear.Stats`, mit Zwischenspeicher
  `AmisiaDB.gear`). `--sv` nimmt zusätzlich Scan-Dateien eines `/amisia scan gear` auf Anniversary
  (PC) und schreibt die Werte als `ST` in die Datei, wie `build_gear.py`.
- **Gewichte:** eigene, im Skript (`OWN_TBC`), Level 70, eine Tabelle je Spezialisierung (`all`).
  Keine fremden Werte übernommen; sie folgen den bekannten Faustregeln (Stärke gibt Kriegern 2
  Angriffskraft, Trefferwertung bis zur Grenze hoch, Heiler werten Heilung und Mana). Siehe
  "Wertung". `BisWeightsTBC.lua` trägt "Amisia's own weights" im Kopf.
- **Ausgabe:** `addon/Amisia/BisDataTBC.lua` und `addon/Amisia/BisWeightsTBC.lua`, Kopf
  `-- GENERATED by tools/build_bis.py. Do not edit; rebuild instead.` und die Quellenzeile
  `-- Sources: AtlasLootClassic (GPL-2.0), the Amisia loot tables, the Amisia item scan.` Erste
  Anweisung nach `local _, ns = ...` ist der Wächter `if ns.IsForever and ns.IsForever() then return
  end`, zusätzlich zur TOC-Bedingung `[AllowLoadGameType tbc]`. `build_gear.py` schreibt den
  umgekehrten Wächter (`if not ns.IsForever() then return end`) in `GearData.lua`/`GearWeights.lua`.
  So lädt auch dann nur ein Satz, wenn eine TOC-Bedingung anders wirkt als erwartet.
- Das Skript meldet die Zahl der Items je Quellenart und Phase, Tokens ohne Set-Teile und Bosse ohne
  deutschen Namen.

Format (gleiches Zeilenformat wie GearData, `I` Feld 1-10 dann Quellennummern):

```lua
ns.GEAR = {
    game = "tbc", cap = 70, built = "2026-10-05",
    S = {
        {"X", "Karazhan", "Prinz Malchezaar", 532, 3457, 1, 0},       -- Raid, Boss, Instanz, Gebiet, Phase, Token
        {"X", "Magtheridons Kammer", "Magtheridon", 544, 3836, 1, 29753},
        {"D", "Die Zerschmetterten Hallen", "Kriegsfürst Kargath", 0, 540, 3714, 1},  -- Dungeon, Boss, Chance, Instanz, Gebiet, heroisch
        {"F", "Die Sha'tar", 7, 935, ""},                              -- Fraktion, Stufe (5 freundlich .. 8 ehrfürchtig), factionID, A/H/""
        {"V", "G'eras", 1955, "", "Abzeichen der Gerechtigkeit", 4},    -- Händler, Gebiet, A/H, Titel, Phase
        {"C", "tailoring", 375},
        {"W", nil, 70, 73, 0},
    },
    I = { [28830] = {"", 0, 0, 0, 0, 0, 0, 0, 0, 0, 1}, ... },
    ST = { ... },        -- optional
}
```

Neue und erweiterte Quellenarten in `Gear.lua`:

| Art | Felder | Text (`Gear.SourceText`) | Filter |
|---|---|---|---|
| `X` Raid | Raid, Boss, Instanz-ID, Gebiets-ID, Phase, Token-ID | "Karazhan: Prinz Malchezaar" (mit Token " (Token)") | "Raids" |
| `D` Dungeon | wie bisher, dazu Instanz-ID, Gebiets-ID, heroisch (1/0) | "Die Zerschmetterten Hallen (heroisch): Kriegsfürst Kargath" | "Dungeons" bzw. "Heroisch" |
| `F` Ruf | Fraktion, Stufe, factionID, Seite | "Ruf: Die Sha'tar, ehrfürchtig" | "Ruf" |
| `V` Händler | wie bisher, dazu Phase (Feld 6) | wie bisher | "Händler" |

`KIND_ORDER` bekommt `X = 0` (Raid zuerst, wo er Quelle ist) und `F = 4.5` (zwischen Händler und
Rar); `FILTER_OF` bekommt `X = "X"`, `F = "F"` und für heroische `D` den Schlüssel `"H"` (über
`Gear.FilterKey(rec)`). `Gear.SourceOk` prüft zusätzlich Phase (`opts.phase`, 0 = alle), Seite
(`F`, `V`) und die Ausschlüsse (siehe unten).

### Lizenzen

| Was | Woher | Lizenz | Wo vermerkt |
|---|---|---|---|
| TBC-Itemliste, Quellen, Tokens | AtlasLootClassic (GitHub) | GPL-2.0 | Kopf von `BisDataTBC.lua`, `tools/README.md` |
| TBC-Gewichte | Amisia (eigene) | wie das Addon | Kopf von `BisWeightsTBC.lua` |
| Forever-Daten | wie bisher (QuestieDB GPL-3.0, AtlasLoot GPL-2.0, OneForAll, wowsrc.com, Scan) | wie bisher | Kopf von `GearData.lua` |
| Forever-DPS-Gewichte | RestedXP `StatWeights.lua` | CC BY-NC-SA 4.0 | Kopf von `GearWeights.lua` (bleibt) |
| Itemart/Level (optional) | wago.tools-Export der Client-Tabellen | Spieldaten von Blizzard, wie `gear_itemsparse.json` | `tools/README.md` |
| Item-Werte | der Client im Spiel | - | - |

Nicht verwendet: Wowhead (robots sperrt Bots, Bedingungen verbieten das Abgreifen), die
Forever-Datenseite, die das Kopieren ihrer Sammlung verbietet, und alle kuratierten BiS-Listen.

## Wertung (Gear.lua)

Die Formel bleibt `Gear.Score(s, w, level, kind, class)`. Änderungen:

- **Rating über Level 60** (nur TBC): `ratingPerPoint` rechnet bis 60 wie heute mit `(L-8)/52`, über
  60 mit TBCs Kurve `82 / (262 - 3 L)`. Bei 70 ergibt das 15,77 Trefferwertung, 12,62
  Zaubertreffer, 22,08 kritische Treffer, 15,77 Tempo, 15,77 Waffenkunde (3,94 je Punkt), 18,92
  Ausweichen, 23,65 Parieren, 7,88 Blocken je Prozent und 2,37 Verteidigung je Punkt. Forever bleibt
  unverändert (Level höchstens 60).
- **Neue Schlüssel in `STAT`:** `EMPTY_SOCKET_RED/YELLOW/BLUE` -> `SOCK` (Anzahl),
  `EMPTY_SOCKET_META` -> `META`, `ITEM_MOD_RESILIENCE_RATING(_SHORT)` -> `RES`,
  `ITEM_MOD_SPELL_PENETRATION(_SHORT)` -> `SPEN`. `SOCK` zählt `w.GEM` je Sockel (Wertung eines
  seltenen Edelsteins der Hauptwertung), `META` zählt `w.META`; der Sockelbonus wird nicht gerechnet.
  `RES` und `SPEN` haben in PvE-Gewichten 0.
- **Zweithand-Waffe:** der Faktor 0,25 auf Waffenschaden in der Schildhand wird zur Gewichtung
  `w.OHDPS` (Standard 0,25 wie heute; TBC-Gewichte für Zweihandkämpfer 0,5).
- **`Gear.ScoreParts(s, w, level, kind, class)`** (NEU) gibt dieselbe Summe in Teilen zurück:
  `{ { key, label, amount, weight, points }, ... }` nach `points` absteigend, Teile mit 0 Punkten
  ausgelassen. `label` deutsch ("Stärke", "Beweglichkeit", "Ausdauer", "Intelligenz", "Willenskraft",
  "Angriffskraft", "Distanzangriffskraft", "Angriffskraft (Gestalt)", "Zauberschaden", "Heilung",
  "Zaubermacht", "Schaden (Schule)", "Trefferwertung", "Zaubertrefferwertung", "kritische
  Trefferwertung", "Zauberkritwertung", "Tempowertung", "Waffenkundewertung", "Verteidigungswertung",
  "Ausweichwertung", "Parierwertung", "Blockwertung", "Blockwert", "Rüstung", "Mana alle 5 Sek.",
  "Gesundheit alle 5 Sek.", "Waffenschaden pro Sekunde", "Sockel", "Meta-Sockel"). Bei Ratings
  steht `amount` als Prozent mit Rating in Klammern ("1,2 % (26)"). Test: Summe der Teile ==
  `Gear.Score` auf 0,01.
- **Einheit:** jede Spezialisierung nennt in den Gewichten `unit` (`"AP"`, `"SP"`, `"HEAL"`,
  `"STA"`); hat diese Wertung das Gewicht 1, heißt ein Punkt "1 Angriffskraft", "1 Zauberschaden",
  "1 Heilung" bzw. "1 Ausdauer" und die Erklärung schreibt "+14 Punkte, so viel wie 14
  Angriffskraft". Die Forever-Gewichte (RestedXP) haben `AP = 1` für Nahkämpfer; wo kein Gewicht 1
  passt, steht nur "Punkte".
- **Werte lesen:** `Gear.ReadStats` nimmt `C_Item.GetItemStats`, sonst das globale `GetItemStats`,
  sonst (NEU) einen versteckten Tooltip (`AmisiaScanTip`, `GameTooltipTemplate`, `SetHyperlink`,
  Zeilen `AmisiaScanTipTextLeft<i>`), dessen Zeilen über Muster aus den `ITEM_MOD_*`-Texten des
  Clients gelesen werden (`%c` -> Vorzeichen, `%s`/`%d` -> Zahl). Der Rückfall ist für Anniversary,
  falls dort `GetItemStats` fehlt (offener Punkt); er liest nur, was der Tooltip zeigt.

### TBC-Gewichte (Startwerte in `build_bis.py`, Level 70)

Ratings je Prozent (wie im Planer), `DEF` je Verteidigungspunkt, sonst je Punkt. Nicht genannte
Schlüssel 0. `GEM`/`META` in Punkten. Werte sind Startwerte; ändern heißt Skript ändern und neu
erzeugen, Einstellungen dafür gibt es nicht.

| Klasse/Spez. | unit | Gewichte |
|---|---|---|
| Krieger Waffen/Furor | AP | STR 2.0, AGI 1.0, AP 1, CRIT 29, HIT 24, HASTE 19, EXP 25, STA 0.05, DPS 14, OHDPS 0.5, GEM 16, META 30 |
| Krieger Schutz | STA | STA 1, DEF 2.0, DODGE 18, PARRY 15, BLOCK 6, BLOCKVAL 0.5, ARMOR 0.06, AGI 0.6, STR 0.4, HIT 8, EXP 10, AP 0.1, DPS 3, GEM 12, META 20 |
| Paladin Heilig | HEAL | HEAL 1, INT 1.1, MP5 2.0, SCRIT 14, HASTE 10, SPI 0.1, STA 0.1, GEM 18, META 20 |
| Paladin Schutz | STA | STA 1, DEF 2.0, DODGE 18, PARRY 15, BLOCK 8, BLOCKVAL 0.6, ARMOR 0.06, SPD 0.6, INT 0.3, AGI 0.5, HIT 6, EXP 6, MP5 1, DPS 1, GEM 12, META 20 |
| Paladin Vergeltung | AP | STR 2.2, AGI 0.9, AP 1, CRIT 22, HIT 25, HASTE 15, EXP 22, SPD 0.4, INT 0.3, MP5 1, DPS 14, GEM 18, META 30 |
| Jäger | AP | AGI 1.6, AP 1, RAP 1, CRIT 22, HIT 25, HASTE 18, INT 0.4, MP5 1.5, RDPS 14, DPS 0.5, GEM 13, META 30 |
| Schurke | AP | AGI 1.8, STR 1.1, AP 1, CRIT 22, HIT 25, HASTE 19, EXP 25, STA 0.05, DPS 14, OHDPS 0.5, GEM 14, META 30 |
| Priester Heilig/Disziplin | HEAL | HEAL 1, SPI 0.8, INT 0.8, MP5 2.0, SCRIT 8, HASTE 12, STA 0.1, GEM 18, META 20 |
| Priester Schatten | SP | SP 1, SP_SHADOW 1, SHIT 14, SCRIT 8, HASTE 12, INT 0.2, SPI 0.15, MP5 0.8, STA 0.05, GEM 9, META 20 |
| Schamane Elementar | SP | SP 1, SP_NATURE 1, SHIT 14, SCRIT 13, HASTE 12, INT 0.3, MP5 0.8, GEM 9, META 20 |
| Schamane Verstärkung | AP | STR 2.0, AGI 0.9, AP 1, CRIT 22, HIT 25, HASTE 20, EXP 25, INT 0.3, MP5 1, DPS 14, OHDPS 0.5, GEM 16, META 30 |
| Schamane Wiederherstellung | HEAL | HEAL 1, MP5 2.2, INT 0.8, SCRIT 10, HASTE 14, SPI 0.2, STA 0.1, GEM 18, META 20 |
| Magier Arkan/Feuer/Frost | SP | SP 1, SP_ARCANE bzw. SP_FIRE bzw. SP_FROST 1, SHIT 14, SCRIT 11, HASTE 13, INT 0.4 (Arkan 0.7), SPI 0.2 (Arkan 0.3), MP5 0.5, GEM 9, META 20 |
| Hexenmeister Gebrechen | SP | SP 1, SP_SHADOW 1, SHIT 15, SCRIT 5, HASTE 12, INT 0.2, SPI 0.2, STA 0.1, GEM 9, META 20 |
| Hexenmeister Zerstörung | SP | SP 1, SP_SHADOW 1, SP_FIRE 0.3, SHIT 15, SCRIT 13, HASTE 12, INT 0.2, SPI 0.1, STA 0.1, GEM 9, META 20 |
| Druide Gleichgewicht | SP | SP 1, SP_ARCANE 0.6, SP_NATURE 0.4, SHIT 14, SCRIT 11, HASTE 12, INT 0.4, SPI 0.2, MP5 0.6, GEM 9, META 20 |
| Druide Wilder Kampf (Katze) | AP | STR 2.2, AGI 2.0, AP 1, FAP 1 (über `AP`), CRIT 22, HIT 25, HASTE 10, EXP 25, GEM 16, META 30 |
| Druide Bär | STA | STA 1, AGI 1.0, ARMOR 0.1, DODGE 15, DEF 1.0, STR 0.4, AP 0.1, HIT 6, EXP 8, CRIT 3, GEM 12, META 20 |
| Druide Wiederherstellung | HEAL | HEAL 1, SPI 0.9, INT 0.8, MP5 1.6, HASTE 12, SCRIT 4, STA 0.1, GEM 18, META 20 |

Kein Trefferwert-Cap in Baustein 3: Trefferwertung zählt linear. Das steht in der Erklärung
("Trefferwertung zählt ohne Obergrenze").

## Ziele je Slot (Bis.lua)

```lua
ns.BisOpts() -> opts            -- class, spec, kind, faction, level, sources, phase, prof, exclude
ns.BisTargets(opts?) -> res     -- je Slot { { id, score, gain, owned, wished, worn }, ... } höchstens 3
ns.BisGain(id, opts?) -> gain, slotKey, mine | nil, Grund
ns.BisExplain(id, opts?) -> lines                      -- Erklärung als Textzeilen (deutsch)
ns.BisOwned(id) -> "worn" | "bag" | "bank" | nil
ns.BisExclude(kind, key, on)    -- kind "item" | "boss" | "place"
ns.BisClearExcludes() -> n
ns.BisHere(placeKey?) -> place, list   -- list { { id, rec, score, gain, owned, wished } } nach gain
ns.BisPlaces() -> { { key, text } }    -- für den Ort-Picker
```

- **Optionen:** Klasse `UnitClass("player")`; Spezialisierung aus `chars[me].spec` oder geraten;
  Level `UnitLevel("player")` (TBC: `math.min(level, 70)`); Fraktion `UnitFactionGroup` als A/H;
  Quellen aus den Quellen-Chips der Seite (Fensterzustand `settings.bis.sources`, Standard alle an
  außer Auktionshaus und PvP); Phase `bis.phase` (TBC); Berufe `bis.prof` ("all" oder "mine").
- **Rechnung:** `Gear.Best(opts)` wie im Planer, erweitert um `opts.exclude` (die `ex`-Tabellen),
  `opts.phase`, `opts.prof` und `opts.skills` (eigene Berufe, siehe unten). Je Slot die ersten drei
  Einträge; Ringe und Schmuck wie heute (zweite Zeile beginnt nach der ersten Wahl), Waffen nach dem
  Plan Zweihand gegen Waffenhand plus Schildhand. Der Planer-Speicher (memo) wird nach Klasse,
  Spezialisierung, Gewichtung **und** einem Fingerabdruck der Ausschlüsse geführt.
- **Zuwachs** (`gain`): Wertung der Option minus Wertung des Angelegten im selben Slot
  (`Gear.ScoreLink` mit dem Link, also mit Zufallsbonus "...des Adlers", aber ohne Verzauberung und
  Edelsteine, beides Grundwerte). Ringe und Schmuck gegen das schwächere der beiden angelegten.
  Waffen: Zweihand gegen Waffenhand plus Schildhand; Einhand gegen Waffenhand; wer Zweihand trägt
  und eine Einhand-Option sieht, bekommt keine Zahl, sondern "Waffenwechsel" (der Plan der Seite
  zeigt beide Wege mit Summen). Ein Upgrade ist `gain > max(1, |mine| * bis.minGain / 100)`.
- **Besitz:** `owned` = "worn" (angelegt in einem passenden Slot), "bag", "bank" oder nil.
  Besitzt der Charakter Option 1 schon (angelegt), steht der Slot als erledigt; liegt sie in Tasche
  oder Bank, steht "in der Tasche, nicht angelegt" mit Zuwachs.
- **Spezialisierung raten:** die Talentgruppe mit den meisten Punkten über
  `C_SpecializationInfo.GetSpecializationInfo(i)` (7. Rückgabe `pointsSpent`, beide Clients
  dokumentiert), sonst `GetTalentTabInfo`, sonst die erste Spezialisierung der Gewichte. Zuordnung
  Talentbaum -> Schlüssel in Bis.lua (`TREE`, z. B. Krieger 1 und 2 -> `dps`, 3 -> `tank`; Druide 2
  -> `feral`, auf Wunsch `bear`). Raten nur, solange `chars[me].spec` nil ist; die Seite zeigt
  "(geraten)".
- **Eigene Berufe** (`opts.skills`): `GetNumSkillLines`/`GetSkillLineInfo` (beide Clients nutzen sie
  in FrameXML), Namen über eine deutsche und englische Tabelle auf die Schlüssel der Daten
  (`tailoring`, `leatherworking`, `blacksmithing`, `engineering`, `jewelcrafting`, `alchemy`,
  `enchanting`) mit Fertigkeit. Mit `bis.prof = "mine"` gelten hergestellte Items, die beim Aufheben
  gebunden sind, nur mit eigenem Beruf und Fertigkeit; beim Anlegen gebundene bleiben (kaufbar).
  Items, die einen Beruf zum Tragen brauchen (Ingenieursbrillen, Feld 10), gelten nur mit diesem
  Beruf. Lässt sich die Berufsliste nicht lesen, fehlt der Chip "nur meine".
- **Ausschlüsse:** `ex.item[id]` nimmt das Item aus allen Listen; `ex.boss[name]` nimmt jede Quelle
  dieses Bosses (`X`, `D`); `ex.place[key]` jede Quelle dieses Orts (`I:<Instanz>` für `X`/`D`,
  `Z:<uiMapID>` für Quests, Händler, Rare, Weltdrops). Ein Item mit einer anderen gültigen Quelle
  bleibt. Wünsche sind nie ausgeschlossen (ein Wunsch auf einem ausgeschlossenen Item bleibt auf der
  Wunschliste, die Seite zeigt "ausgeschlossen").
- **Hier** (`ns.BisHere`): Ort aus `GetInstanceInfo()` (8. Rückgabe `instanceID`) in einer Instanz,
  sonst `C_Map.GetBestMapForUnit("player")` und dessen Eltern bis zum Kontinent (`C_Map.GetMapInfo`).
  Liste: alle Items mit einer Quelle an diesem Ort, die für die Optionen gültig sind und entweder
  ein Upgrade sind oder auf der Wunschliste stehen, nach `gain`; Besitz markiert und unten. Der
  Ort-Picker der Seite (`ns.BisPlaces`) nennt alle Raids und Dungeons der Daten (Namen über
  `C_Map.GetAreaInfo`, sonst der Name der Quelle), heroische als eigener Eintrag, und "Hier".
- Neu gerechnet wird bei `PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED` (gedrosselt auf 1 s),
  `PLAYER_LEVEL_UP`, Talentänderung (`CHARACTER_POINTS_CHANGED`, `PLAYER_TALENT_UPDATE`,
  `ACTIVE_TALENT_GROUP_CHANGED`), `ns.Fire("SETTING")`, Wunsch- oder Ausschlussänderung
  (`ns.Fire("BIS_CHANGED")`) und wenn der Lader Items bringt (`Gear.OnData`). Gerechnet wird nur
  bei Bedarf (Seite offen, Karte, Tooltip), das Ergebnis bleibt bis zur nächsten Änderung.

### Besitz lesen

- **Angelegt:** `GetInventoryItemLink("player", inv)` für die 17 Slots, live.
- **Taschen:** `C_Container.GetContainerNumSlots`/`GetContainerItemID` für Taschen 0 bis
  `NUM_BAG_SLOTS`, bei `BAG_UPDATE_DELAYED` (gedrosselt), Ergebnis in `chars[me].bag`.
- **Bank:** bei `BANKFRAME_OPENED` und `PLAYERBANKSLOTS_CHANGED`, solange die Bank offen ist:
  Anniversary `BANK_CONTAINER` (-1) und `NUM_BAG_SLOTS + 1` bis `NUM_BAG_SLOTS + NUM_BANKBAGSLOTS`
  (wie FrameXML `TBC/BankFrame.lua`); Forever die Behälter aus
  `C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)` (Forever kennt keinen Behälter -1; die
  Bank besteht aus Tabs). Ergebnis in `chars[me].bank`, `bankAt = time()`.
- **Rückfall ohne Bankbesuch:** für Kandidaten, die weder angelegt noch in Taschen noch in `bank`
  stehen, `C_Item.GetItemCount(id, true) > C_Item.GetItemCount(id)` -> "bank". Das ist billig genug
  für die höchstens 51 angezeigten Optionen, nicht für alle Items.
- Die Seite zeigt "Bank zuletzt gezählt: 03.10." bzw. "Bank noch nicht geöffnet".

## Wunschliste und Hinweis (Bis.lua)

```lua
ns.WishAdd(id, prio?, note?) -> e | nil, Grund       -- prio Standard 2
ns.WishRemove(id) -> true | nil
ns.WishSetPrio(id, prio)
ns.Wishes() -> { { id, e, owned, slot, src } }       -- nach prio, dann Name
ns.WishExportText() -> text                           -- "#AMISIA 2 <Name>" + WL-Zeilen + "#END"
ns.BisToast(id, why, link?)                           -- why "wish" | "upgrade"
```

- **Ablehnen:** kein Item ("Kein Item."), nicht anlegbar für die Klasse ("Das kann dein Charakter
  nicht tragen."), mehr als 50 ("Die Wunschliste ist voll (50)."). Schon da: Priorität und Notiz
  werden aktualisiert.
- **Selbst aufräumen** (`bis.wishAutoRemove`, Standard an): taucht ein Wunsch in Taschen, Bank oder
  angelegt auf, wird er entfernt und im eigenen Chat steht "Amisia: Gürtel der Hoffnung von deiner
  Wunschliste genommen, du hast ihn." Aus: der Wunsch bleibt mit Haken "hast du".
- **Auslöser des Hinweises** (jeweils nur, wenn `bis.toast` an ist; Links und Texte über `ns.Plain`,
  geheime Werte übersprungen):
  1. `LOOT_OPENED`: `GetLootSlotLink(i)` für alle Slots (eigenes Plündern, Master Loot).
  2. `START_LOOT_ROLL`: `GetLootRollItemLink(rollID)` (Gruppenplündern).
  3. Loot-Ansage: `CHAT_MSG_RAID` und `CHAT_MSG_RAID_LEADER`, deren Text wie eine Item-Zeile der
     Amisia-Ansage aussieht (`^%d+%. |c`), und `CHAT_MSG_RAID_WARNING` mit Item-Link (Roll-Start
     "Roll auf [Item]" und Ansagen anderer Raid-Addons). Auf Forever sind diese Ereignisse in der
     Chat-Sperre geheim und werden übersprungen; die Ansage kommt nach dem Bosskampf, dann ist die
     Sperre vorbei.
  Für jedes Item: steht es auf der Wunschliste -> Hinweis "wish"; sonst, wenn `bis.toastUpgrade` an
  ist und `ns.BisGain` ein Upgrade ergibt -> Hinweis "upgrade". Gleiches Item höchstens einmal je 2
  Minuten, höchstens 3 Hinweise gleichzeitig (älteste gehen), nichts für Items, die man besitzt.
  Nicht in Schlachtfeldern und Arenen (`IsInInstance()` Typ `pvp`/`arena`).
- **Hinweis-Fenster** (`AmisiaBisToast`, 320 x 58, FULLSCREEN_DIALOG, oben Mitte bei y -150,
  stapelt nach unten mit 4 px Abstand): Symbol (36 px), Zeile 1 "Wunsch droppt!" (gold) bzw.
  "Upgrade für dich" (grün), Zeile 2 Item-Name in Qualitätsfarbe und "+14 (Brust)", Zeile 3 grau die
  Quelle ("Prinz Malchezaar" aus dem Lootfenster, sonst "Lootfenster", "Würfeln", "Ansage").
  Bleibt 8 s, Maus darüber hält ihn, Klick öffnet die Seite (Ansicht Ziele, Slot gewählt),
  Shift-Klick postet den Link (`HandleModifiedItemClick`), Rechtsklick schließt. Ton
  `PlaySound(SOUNDKIT.RAID_WARNING)` nur bei Wünschen und nur mit `bis.toastSound` (beide Clients
  nutzen diesen Ton in FrameXML; fehlt `SOUNDKIT`, kein Ton).
- **Erhalten:** `CHAT_MSG_LOOT` mit eigenem Link ("Ihr erhaltet Beute: ...", über die
  `LOOT_ITEM_SELF`-Texte des Clients wie Core.lua) löst das Taschen-Lesen sofort aus; Selbst-aufräumen
  folgt daraus.

### Export der Wünsche (`ns.WishExportText`)

```
#AMISIA 2 Vulo_Sturmwind
WL <itemID> <prio 1-3> <epoch> <name> [<note>]
#END
```

- Eine Zeile je Wunsch, nach Priorität absteigend, dann Item-ID; `<name>` ist `ns.ExportName` des
  eigenen Charakters, die Notiz das letzte Feld und darf Leerzeichen enthalten (`oneLine` wie die
  Bank-Notiz). Keine `S`-Blöcke, keine `N`-Zeilen.
- Die Zeilen werden mit `lines[#lines + 1] = ("WL %d %d %d %s%s"):format(...)` geschrieben, damit
  `test_export_format.py` sie findet.

## Tooltip-Zeile (Bis.lua)

- Anmeldung wie die SR-Zeile: `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
  ...)` (beide Clients; Anniversary nutzt es in FrameXML `TooltipDataRules.lua`), sonst
  `OnTooltipSetItem` an `GameTooltip` und `ItemRefTooltip`. Item über `TooltipUtil.GetDisplayedItem`
  bzw. `tip:GetItem()`.
- **Nie andere Tooltips brechen:** der ganze Rumpf läuft in `pcall`, Fehler gehen an
  `geterrorhandler`; eine Zeile je Tooltip-Aufbau (schwache Tabelle wie SoftRes, gelöscht bei
  `OnTooltipCleared`); nur `AddLine`, nie `SetText`, `ClearLines` oder `Show`; keine Arbeit für
  Tooltips, die keine Items zeigen; kein Laden, das den Tooltip neu aufbaut: fehlen die Werte, wird
  das Item beim Lader bestellt und die Zeile fehlt bis zum nächsten Zeigen.
- **Text** (`bis.tooltip`, Standard an), Farbe grün bzw. grau:
  - "Upgrade für dich: +14 (Brust)" (mit Wunsch: "Upgrade für dich: +14 (Brust) · auf deiner
    Wunschliste").
  - "Option 1 für Brust" statt Zahl, wenn das Item gerade Option 1-3 in Ziele ist und kein Upgrade
    gegenüber dem Angelegten (z. B. schon angelegt: "angelegt, Option 1 für Brust").
  - "Kein Upgrade für dich (-5)" nur mit `bis.tooltipNone` (Standard aus).
  - "Waffenwechsel für dich" (Einhand gegen getragene Zweihand).
  - Keine Zeile für Items, die die Klasse nicht tragen kann, für Nicht-Ausrüstung und für Items ohne
    Werte.
- Mit gedrückter Shift-Taste zusätzlich bis zu vier Zeilen der Erklärung (`ns.BisExplain`, die
  größten Teile, grau): "30 Stärke x 2,0 = 60". Tooltips werden beim Drücken nicht neu aufgebaut;
  die Zeilen erscheinen beim nächsten Zeigen.
- Bezug: das Item des Tooltips wird mit seinem Link gewertet (Zufallsbonus zählt), verglichen mit dem
  Angelegten wie in "Ziele". Das gilt auch für Items, die nicht in den Daten stehen (Tooltip, nicht
  Ziele).

## Gildenwünsche (GuildWishes.lua)

```lua
ns.ParseGuildWishes(text) -> res | nil, Grund   -- res { game, date, list, n, skipped }
ns.SetGuildWishes(text) -> res | nil, Grund     -- speichert AmisiaDB.bis.guild
ns.ClearGuildWishes()
ns.WishersOf(id, groupOnly?) -> { { name, prio, note, inGroup } }   -- nach prio, dann Name
ns.GuildWishesInfo() -> { date, n, age, game }
```

- **Format** (von der Website, "Copy for the addon"):

  ```
  #AMISIA-WL 1 tbc 2026-10-05
  W <itemID> <prio 1-3> <name> [<note>]
  #END
  ```

  Namen mit `_` statt Leerzeichen; unbekannte Zeilen werden übersprungen und gezählt. Abgelehnt:
  kein Kopf ("Das ist keine Wunschliste der Amisia-Seite."), anderes Spiel als der Client ("Diese
  Wunschliste ist für WoW Forever, du bist in TBC Anniversary."), keine Zeile ("Die Liste ist
  leer."). Höchstens 2000 Zeilen.
- **Anzeige** (nur, wenn eine Liste geladen ist; jede Stelle abschaltbar, Standard an):
  - Tooltip-Zeile `bis.guildTooltip` (Offiziere): "Gewünscht: Anna (hoch), Bob" in der Gruppe nur
    Namen aus `ns.GroupRoster()` (über `ns.SameNameIn`), die übrigen gezählt "(+2 außerhalb)", wie
    die SR-Zeile. Geschützt wie oben.
  - Lootfenster und Würfelfenster `bis.guildLootMark` (Offiziere): Marke "W" oben rechts am Symbol
    (die SR-Marke sitzt oben links), wenn jemand aus der Gruppe das Item wünscht; gleiche Hooks wie
    `ns.MarkLootButtons` und `markRoll` (eigene Funktion, aufgerufen aus denselben Ereignissen, nicht
    in SoftRes.lua eingebaut).
  - Vergabe-Dialog `bis.guildAward` (Offiziere): `names()` sortiert Wünschende nach Priorität zuerst,
    Text "Anna (Wunsch hoch)"; der Rest wie bisher alphabetisch.
- Alter: älter als 14 Tage -> Hinweis auf der Seite "Die Wunschliste ist 16 Tage alt." (grau).

## Seite "Ausrüstung" (Pages/Gear.lua)

`ns.RegisterPanel{ key = "gear", label = "Ausrüstung", icon = "Interface\\Icons\\INV_Chest_Chain_05",
order = 50, available = function() return Gear.Available() end }` auf beiden Clients (Gear.Available
wahr, sobald ein Datensatz geladen ist). Inhaltsfläche 602 x 478.

```
+------------------------------------------------------------------------------------------+
| [Schatten (geraten) v]  [Ziele] [Hier] [Wunschliste (4)] [Gilde]   [Tabelle öffnen]       |  y 0
| Level 70 · 9 Upgrades · Bank 03.10. · 2 ausgeschlossen [zurücksetzen]                     |  y -26
| [Raids][Heroisch][Dungeons][Ruf][Händler][Berufe: alle][Welt]          Phase [bis 3 v]    |  y -48
| Slot          Angelegt                 Bestes                      Quelle          Zuwachs|  y -74
| Kopf          Kapuze des Wahnsinns     [x] Krone des Unheils       Kara: Prinz M.    +18  |
| Hals          ...                      ...                                               |
| ...                                    (11 Zeilen à 24 px, Mausrad, 17 Slots)            |
+------------------------------------------------------------------------------------------+
| Kopf · Bestes für Schatten                                                               |  y -346
| 1 [ ] Krone des Unheils        Karazhan: Prinz Malchezaar     +18  [Wunsch] [Aus]       |
| 2 [x] Kapuze des Wahnsinns     angelegt                         0                        |
| 3 [ ] Schleier der Leere       Heroisch: Schattenlabyrinth      +6  [Wunsch] [Aus]       |
| +18 Punkte, so viel wie 18 Zauberschaden: 23 Zauberschaden, 1,1 % Zaubertreffer ...      |
+------------------------------------------------------------------------------------------+
```

- **Kopf** (y 0): Spezialisierung über W.Picker (180 px, `Gear.Specs(class)`, Text "(geraten)",
  solange nicht gewählt; Wahl setzt `chars[me].spec`), Ansicht-Chips, rechts "Tabelle öffnen"
  (130 px, nur Forever). "Gilde" erscheint in der Offiziersansicht oder wenn eine Liste geladen ist.
- **Zahlenzeile** (y -26): Level, Zahl der Upgrades, Bankstand, Ausschlüsse mit Knopf
  "zurücksetzen" (StaticPopup "Alle Ausschlüsse aufheben?"); "lädt noch 120 Items" golden, solange
  der Lader arbeitet. Ohne Daten: "Für diesen Client gibt es keine Ausrüstungsdaten."
- **Quellen-Chips** (y -48): TBC Raids, Heroisch, Dungeons, Ruf, Händler, Berufe, Welt; Forever
  Quests, Dungeons, Berufe, Händler, Welt, AH, PvP (wie die Tabelle, eigener Zustand
  `settings.bis.sources`). Der Chip "Berufe" schaltet per Klick zwischen "Berufe: alle", "Berufe:
  meine", aus. Rechts nur TBC "Phase" (W.Picker 90 px: "alle", "bis 1" bis "bis 5", setzt
  `bis.phase`).
- **Ziele** (Standardansicht): W.List (11 Zeilen à 24 px) mit allen 17 Slots: Slot 0-70,
  Angelegt 74-230 (Name in Qualitätsfarbe, leer "nichts"), Bestes 234-420 (Haken-Textur
  `Interface\RaidFrame\ReadyCheck-Ready` bei Besitz, Stern-Textur `Interface\TargetingFrame\UI-RaidTargetingIcon_1`
  bei Wunsch), Quelle 424-550 (kurz, `Gear.SourceText(rec, true)`), Zuwachs 554-602 (grün, "+18";
  erledigt: Haken; Waffenwechsel: "Wechsel"). Zeilen ohne Upgrade grau. Klick wählt den Slot;
  Mausrad scrollt; Tooltip des Items beim Überfahren der Spalte Bestes.
- **Detailbereich** (y -346 bis -478): Titel "Kopf · Bestes für Schatten", drei Zeilen à 26 px mit
  Rang, Haken, Name, Quelle, Zuwachs und den Knöpfen "Wunsch" (bzw. "Wunsch weg") und "Aus"
  (Item ausschließen; Rechtsklick auf die Zeile öffnet W.Menu mit "Item ausschließen", "Boss
  ausschließen", "Ort ausschließen", "Auf die Wunschliste", "Link in den Chat"). Darunter die
  Erklärung der Option 1 als eine Zeile (W.Text mit Umbruch, zwei Zeilen): "+18 Punkte, so viel wie
  18 Zauberschaden: 23 Zauberschaden, 1,1 % Zaubertreffer (14), ..." und bei TBC-Trefferwertung
  "Trefferwertung zählt ohne Obergrenze.". Waffen-Slots zeigen den Plan: "Zweihand 412 gegen
  Waffenhand plus Schildhand 398".
- **Hier**: Kopf mit Ort-Picker (W.Picker 240 px: "Hier: Karazhan" zuerst, dann `ns.BisPlaces`).
  W.List (14 Zeilen à 24 px): Boss 0-150, Item 154-370 (mit Haken/Stern), Slot 374-450, Zuwachs
  454-510, Knopf "Wunsch" 520-602. Unten grau: "Was du an diesem Ort noch holen kannst: Upgrades und
  Wünsche, Besitz unten." Ohne Treffer: "Hier gibt es nichts mehr für dich." bzw. "Diesen Ort kennen
  die Daten nicht.".
- **Wunschliste**: W.List (12 Zeilen à 24 px): Item 0-220, Slot 224-300, Quelle 304-470, Priorität
  474-540 (Chip, Klick wechselt hoch/mittel/niedrig), Zustand 544-580 ("hast du" grün, "aus"
  grau bei Ausschluss), Chip "x" 584-602 (entfernt). Darunter "Für die Website" (120 px) öffnet eine
  W.EditArea (Höhe 120, schreibgeschützt wie die Exportbox, markiert) mit `ns.WishExportText()` und
  dem Hinweis "Strg+A, Strg+C, auf der Website im Reiter Wishlist bei Paste from the addon
  einfügen." sowie "Erhaltene entfernen" (nur wenn `bis.wishAutoRemove` aus ist). Leer: "Noch keine
  Wünsche. Wunsch-Knopf in Ziele oder Hier, oder /amisia wunsch <Item-Link>.".
- **Gilde** (Offiziersansicht oder geladene Liste): oben "Liste vom 05.10.2026, 42 Wünsche" und
  Chip "Nur Gruppe" (Standard an im Raid); W.List (11 Zeilen): Item 0-260, Wünschende 264-602
  ("Anna (hoch), Bob, ..." in Klassenfarbe, sofern Raider bekannt). Offiziere: darunter W.EditArea
  (Höhe 70) mit Knöpfen "Importieren" und "Löschen" (StaticPopup "Die Gildenwünsche löschen?") und
  dem Hinweis "Auf der Website im Reiter Wishlist: Copy for the addon.".
- Die Seite hört auf `DATA_CHANGED`, `SETTING`, `BIS_CHANGED` und auf Gear.OnData (nur solange
  sichtbar, Neubau höchstens einmal je Sekunde). `ns.ShowGear(view, slotKey?)` öffnet sie.

### Karte, Planer, Schnellmenü

- Karte "gear" (Übersicht, Platz bleibt 30) auf beiden Clients: Titel "Deine Ausrüstung", Zeile 1
  "Level 70 · 9 Upgrades · 4 Wünsche", Zeile 2 "Bestes: Krone des Unheils (+18)" bzw. in einer
  Instanz "Hier: 3 Upgrades (Karazhan)"; Knopf "Ansehen". Keine neue Karte (die Übersicht hat 6
  Plätze).
- Forever-Tabelle (`GearFrame.lua`): `ns.GearMyUpgrades` nutzt `ns.BisTargets`; Zellen mit Items im
  Besitz bekommen den Haken; `Gear.PlannerAvailable()` = `Gear.Available() and Gear.Game() ==
  "forever"` für Fenster, Befehl `gear` und Abschnitt "gear".
- Schnellmenü (Minimap): Eintrag "Ausrüstung" auf beiden Clients (heute nur Forever), danach in
  Forever "Ausrüstungstabelle".

## Einstellungen

Neuer Abschnitt `ns.RegisterSettings{ key = "bis", label = "Ausrüstung und Wünsche", order = 45,
available = function() return Gear.Available() end }`:

| Pfad | Typ | Standard | Ansicht | Text |
|---|---|---|---|---|
| bis.tooltip | toggle | an | alle | "Tooltip-Zeile \"Upgrade für dich\"" |
| bis.tooltipNone | toggle | aus | alle | "Auch \"Kein Upgrade\" im Tooltip zeigen" |
| bis.minGain | slider 0-10 | 2 | Experte | "Upgrade erst ab (Prozent mehr Wertung)" |
| bis.toast | toggle | an | alle | "Hinweis, wenn ein Wunsch droppt" (Tip: Lootfenster, Würfeln und Loot-Ansage) |
| bis.toastUpgrade | toggle | an | alle | "Hinweis auch für andere Upgrades" |
| bis.toastSound | toggle | an | alle | "Ton beim Wunsch-Hinweis" |
| bis.wishAutoRemove | toggle | an | alle | "Erhaltene Wünsche von der Liste nehmen" |
| bis.phase | choice 0-5 | 0 | alle, nur TBC | "Inhalte bis Phase" (0 = "alle") |
| bis.prof | choice all/mine | all | alle | "Hergestellte Items" ("alle", "nur meine Berufe") |
| bis.guildTooltip | toggle | an | Offiziere | "Gildenwünsche im Tooltip" |
| bis.guildLootMark | toggle | an | Offiziere | "W-Markierung im Lootfenster und an den Würfelfenstern" |
| bis.guildAward | toggle | an | Offiziere | "Wünschende zuerst im Vergabe-Dialog" |

`bis.phase` hat `available` nur auf TBC (die Einstellungsseite blendet den Punkt sonst aus). Die
Quellen-Chips und die Ansicht der Seite sind Fensterzustand (`settings.bis.sources`,
`settings.bis.view`), kein Schema.

## Befehle

| Befehl | Ansicht | Wirkung |
|---|---|---|
| `/amisia bis` (Alias `ziele`, `ausruestung`) | alle | Seite Ausrüstung, Ansicht Ziele |
| `/amisia bis hier` | alle | Ansicht Hier |
| `/amisia bis item <Link>` | alle | Erklärung der Wertung im eigenen Chat: Spez., Slot, Wertung, Zuwachs, alle Teile, die Rohwerte des Clients (wie heute `/amisia gear item`) |
| `/amisia bis aus <Link>` | alle | Item ausschließen |
| `/amisia bis zurueck` | alle | alle Ausschlüsse aufheben |
| `/amisia wunsch <Link> [hoch\|mittel\|niedrig] [Notiz]` | alle | Wunsch eintragen oder ändern |
| `/amisia wunsch weg <Link>` (Alias `remove`) | alle | Wunsch entfernen |
| `/amisia wunsch` | alle | Ansicht Wunschliste |
| `/amisia wuensche` | Offiziere | Ansicht Gilde (Import) |

`/amisia gear item <Link>` bleibt als Alias von `bis item`. `/amisia gear` öffnet in TBC die Seite
statt der Tabelle ("Die Ausrüstungstabelle gibt es nur in WoW Forever, hier die Seite.").

## Ereignisse und APIs je Client

Geprüft in den Client-Quellen 2.5.6.69795 (Anniversary) und 1.60.1.70205 (Forever),
`Blizzard_APIDocumentationGenerated` und FrameXML.

| API / Ereignis | Anniversary 2.5.6 | Forever 1.60.1 | Verwendung |
|---|---|---|---|
| `C_Item.GetItemStats` | nicht dokumentiert, in FrameXML nicht genutzt | dokumentiert, `AllowedWhenUntainted` | Werte; Anniversary: globales `GetItemStats` (prüfen), sonst Tooltip-Leser |
| `C_Item.GetItemInfoInstant` | dokumentiert (equipLoc, classID, subClassID) | dokumentiert | `Gear.FillRow`, Slot eines Links |
| `C_Item.GetItemInfo`, `RequestLoadItemDataByID`, `IsItemDataCachedByID`, `ITEM_DATA_LOAD_RESULT` | dokumentiert | dokumentiert | Lader wie im Planer |
| `C_Item.GetItemCount(item, includeBank)` | dokumentiert | dokumentiert, `AllowedWhenUntainted` | Bank ohne Bankbesuch |
| `C_Container.GetContainerNumSlots/GetContainerItemID` | dokumentiert | dokumentiert | Taschen, Bank |
| Bankbehälter | `Enum.BagIndex.Bank` -1, `NUM_BAG_SLOTS+1 .. +NUM_BANKBAGSLOTS` (FrameXML TBC) | kein -1; `C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)` (Camelot-BankFrame) | Bank lesen |
| `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`, `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED` | dokumentiert | dokumentiert | Besitz |
| `GetInventoryItemLink` | Global, FrameXML | Global, FrameXML | Angelegtes |
| `TooltipDataProcessor.AddTooltipPostCall`, `TooltipUtil.GetDisplayedItem` | FrameXML (`TooltipDataRules.lua`) | FrameXML | Tooltip-Zeile |
| `LOOT_OPENED`, `GetLootSlotLink`, `START_LOOT_ROLL`, `GetLootRollItemLink` | dokumentiert, ohne Kennzeichen | dokumentiert, ohne Kennzeichen | Hinweis |
| `CHAT_MSG_RAID`, `CHAT_MSG_RAID_LEADER`, `CHAT_MSG_RAID_WARNING` | ohne Kennzeichen | `SecretInChatMessagingLockdown` | Hinweis aus der Ansage, über `ns.Plain` |
| `CHAT_MSG_LOOT` | ohne Kennzeichen | Ereignis ohne Sperr-Kennzeichen, Text nicht `NeverSecret` | Erhalten, über `ns.Plain` |
| `GetInstanceInfo` (8. Rückgabe instanceID) | FrameXML | FrameXML | Hier |
| `C_Map.GetBestMapForUnit`, `C_Map.GetMapInfo`, `C_Map.GetAreaInfo` | FrameXML | FrameXML | Hier, Ortsnamen |
| `C_SpecializationInfo.GetSpecializationInfo` (pointsSpent) | dokumentiert | dokumentiert | Spez. raten |
| `GetTalentTabInfo` | nicht gefunden | nur als Kompatibilitätsfunktion | Rückfall, Typprüfung |
| `GetNumSkillLines`, `GetSkillLineInfo` | FrameXML (`Classic/SkillFrame.lua`) | FrameXML (`Camelot/SkillsFrame.lua`) | eigene Berufe |
| `PlaySound(SOUNDKIT.RAID_WARNING)` | FrameXML | FrameXML | Ton |
| `[AllowLoadGameType tbc]` in der TOC-Dateizeile | in Blizzards eigenen TOCs von Anniversary vielfach | - | TBC-Daten nur auf Anniversary |

## Website (index.html)

Texte englisch. Nur der Reiter Wishlist und der Parser ändern sich; kein neuer Zustand im Ledger
(Wünsche leben in der Supabase-Tabelle `wishlist`, die es schon gibt).

- **amParseWishes(blocks)** (NEU, rein, testbar): liest `WL`-Zeilen aus allen `#AMISIA`-Blöcken:
  `[{item, prio (1-3, sonst 2), at, name (glCleanName, "_" -> " "), note (höchstens 80 Zeichen)}]`.
  `amParse` und `amParseBank` bleiben unverändert (sie überspringen `WL`).
- **Import-Reiter:** enthält ein eingefügter Text `WL`-Zeilen, steht über der Vorschau "This text
  holds a wishlist. Paste it on the Wishlist tab." Sonst nichts.
- **Wishlist, Panel "Paste from the addon"** (unter "Add to a wishlist", nur angemeldet): Textfeld,
  Knopf "Check". Vorschau: je Wunsch Item, Raider (über den Namen der Zeile aus `state.raiders`, wie
  `findRaider`), Priorität und Zustand: "new", "already on the list" (gleicher Raider und Item),
  "already received" (`wishGot`), "not in the loot tables" (kein `ITEM[id]`), "unknown raider" (Name
  nicht im Roster; Editoren können ihn auf dem Roster-Reiter anlegen). Knopf "Add n wishes" schreibt
  nur die neuen über `SUPA.from('wishlist').insert([...])` mit `boss = ITEM[id].sources[0]` und
  `created_by`/`created_name` wie das Formular; die Grenze von 30 offenen Wünschen je Raider gilt
  (Überschuss mit "over the limit of 30" abgelehnt). Danach `loadWishes()`.
- **Wishlist, Knopf "Copy for the addon"** (Toolbar, für alle): Panel mit schreibgeschütztem
  Textfeld und Copy-Knopf: `#AMISIA-WL 1 <gameKey> <today>` und je offenem Wunsch (`!wishGot`) des
  Spiels `W <item> <prio> <raider name with _> [<note>]`, sortiert nach Item, dann Priorität, dann
  `#END`. Funktion `wishAddonText(wishes)` (rein, testbar).
- **Twin:** der Reiter Wishlist fehlt im Twin (keine Datenbank); `build_twin.py` schneidet die neuen
  Funktionen mit ab und seine Prüfung ("nichts ruft eine geschnittene Funktion") muss grün bleiben.
  Nach der Änderung: Twin neu bauen, veröffentlichen, `python tools/twin_stamp.py --published`.
  `BUILD_ID` bleibt (keine Datendatei geändert).

## Fehlerbehandlung

- Seite und Karte bauen in `pcall` wie alle Seiten. Tooltip-Zeilen, Marken und Hinweise laufen in
  `pcall`, Fehler gehen an `geterrorhandler`, der Tooltip bleibt unberührt.
- Ohne Datensatz (`ns.GEAR` nil): Seite mit Hinweistext, keine Tooltip-Zeile, kein Hinweis für
  Upgrades (Wünsche gehen trotzdem: ein Wunsch braucht nur die Item-ID).
- Item ohne Werte: Lader bestellt es, Zeile oder Option fehlt bis dahin, die Seite zählt "lädt noch".
  Ein Item, das der Server nie beschreibt (`failed`), wird übersprungen.
- Zeilen mit leerer Itemart (TBC ohne CSV): `Gear.FillRow` füllt sie; liefert
  `GetItemInfoInstant` keinen Ausrüstungsplatz, wird die Zeile als "nicht anlegbar" markiert und nie
  wieder geprüft.
- Fehlende APIs (`C_Bank`, `C_SpecializationInfo`, `GetSkillLineInfo`, `GetItemStats`,
  `TooltipDataProcessor`, `SOUNDKIT`): Typprüfung, die Funktion fällt still weg (keine Bank, Spez.
  aus den Gewichten, Chip "nur meine" fehlt, Tooltip-Leser, alter Tooltip-Hook, kein Ton).
- Geheime Werte (Chat-Texte, Links, Lootrollen-ID) gehen durch `ns.Plain` und werden übersprungen.
- `ns.WishAdd`, `ns.SetGuildWishes`, `ns.BisExclude` geben bei ungültigen Angaben den Grund zurück;
  Befehl und Seite zeigen ihn.
- Website: kaputte `WL`-Zeilen (fehlende Zahl) werden ignoriert; ein Insert-Fehler zeigt die Meldung
  von Supabase wie das Formular; doppelte (unique) Wünsche gelten als "already on the list".

## Tests

Lua (`addon/tests`, Stub ergänzt: `C_Item.GetItemInfoInstant` und `GetItemStats` über `STUB.items`,
`C_Item.GetItemCount` mit Bank über `STUB.bank`, `C_Container` über `STUB.bags`, `C_Bank` über
`STUB.bankTabs`, `GetInventoryItemLink` über `STUB.worn`, `C_SpecializationInfo` über
`STUB.talents`, `GetSkillLineInfo` über `STUB.skills`, `GetInstanceInfo`/`C_Map` über `STUB.place`,
`PlaySound` zählt; TBC- und Forever-Client über `STUB.toc`; Tests ohne eine API über `--[[preload]]`):

- `test_bis_score.lua`: Rating bei 60 und 70 (15,77 Treffer, 22,08 Krit), Forever unverändert;
  Sockel und Meta; `OHDPS`; `Gear.ScoreParts` ergibt `Gear.Score`; Einheit-Text; Tooltip-Leser mit
  deutschen und englischen `ITEM_MOD_*`-Mustern.
- `test_bis_targets.lua`: drei Optionen je Slot; Besitz angelegt/Tasche/Bank (auch über
  `GetItemCount`); Item-, Boss- und Ortsausschluss rücken die nächste nach, ein Item mit zweiter
  Quelle bleibt; Phase; Fraktion; Berufe "mine" mit BoP und BoE; Tier-Teil nur für seine Klasse;
  Ringe und Schmuck; Zweihand gegen Einhand plus Schildhand, "Waffenwechsel"; Zuwachs gegen das
  schwächere Ring-Paar; Spez. raten und gewählte Spez.; `Gear.FillRow`; Hier in Instanz und Gebiet
  mit Eltern, Ort-Picker; Speicher wird mit neuen Ausschlüssen neu gerechnet.
- `test_bis_wish.lua`: hinzufügen, ändern, entfernen, Grenze 50, nicht tragbar abgelehnt;
  Selbst-aufräumen bei Tasche und `CHAT_MSG_LOOT`; Hinweis aus `LOOT_OPENED`, `START_LOOT_ROLL`,
  Amisia-Ansage im Raidchat, Schlachtzugswarnung; geheimer Text übersprungen; einmal je 2 Minuten;
  höchstens 3; nicht in Schlachtfeldern; Upgrade-Hinweis nur mit `bis.toastUpgrade`; Ton nur bei
  Wünschen; `ns.WishExportText` (Kopf, Zeilen, Notiz mit Leerzeichen, `|` entfernt); Umzug (zweimal
  laden, kaputte Einträge, Spez. aus `settings.gear.specs`).
- `test_bis_tooltip.lua`: eine Zeile je Aufbau, zweimal übergeben bleibt eine; Fehler im Rumpf bricht
  den Tooltip nicht (`geterrorhandler` gerufen); keine Zeile für Nicht-Ausrüstung, fremde
  Rüstungsklasse, ohne Werte (dann bestellt); "Option 1", "angelegt", "Kein Upgrade" nur mit
  Schalter; Shift-Erklärung; Rückfall `OnTooltipSetItem` ohne `TooltipDataProcessor`.
- `test_guild_wishes.lua`: Parser (Kopf, Spiel falsch, leer, unbekannte Zeilen, Namen mit `_`);
  `ns.WishersOf` mit Gruppe über `ns.SameNameIn` (Vorname nur eindeutig); Tooltip-Zeile mit
  "(+2 außerhalb)"; Marke "W" im Lootfenster und am Würfelfenster neben "SR"; Vergabe-Dialog mit
  Wünschenden zuerst; Schalter aus; Alter-Hinweis.
- `test_bis_page.lua`: Seite baut auf TBC und Forever, in Offiziers- und Raider-Ansicht; Ziele mit
  Detail und Erklärung; Knöpfe Wunsch und Aus; Menü-Einträge; Hier mit Picker; Wunschliste mit
  Export-Box; Gilde mit Import und Löschen nur für Offiziere; Karte auf beiden Clients; Planer und
  Abschnitt "gear" nur Forever; Schnellmenü.
- Bestehende Tests bleiben grün (insbesondere `test_gear.lua`, `test_softres.lua`,
  `test_lootannounce.lua`, `test_award_dialog.lua`, `test_pages.lua`, `test_export.lua`).

Python/Node (`tools/tests`):

- `test_build_bis.py`: kleine AtlasLoot-Auszüge als Fixtures (ein Raid mit Token, ein Dungeon normal
  und heroisch, ein Ruf, Abzeichen-Händler P4, ein Rezept); Tokens werden Set-Teile mit
  Klassenmaske und Token-Quelle; Phasen; deutsche Bossnamen aus `bossnames.js`; mit CSV fällt
  Nicht-Ausrüstung weg; die Ausgabe hat Kopf, Lizenzzeile und Wächter; Lua-Syntax über das
  bestehende Hilfsmittel; zweimal bauen gibt dieselbe Datei.
- `test_build_gear.py` (ergänzt): `D` mit Instanz- und Gebiets-ID; `X` aus einer `forever.js`-Raid-Zone
  (Fixture); Wächter in `GearData.lua`.
- `test_export_format.py` (ergänzt): das echte Addon schreibt eine Wunschliste, `amParseWishes`
  liest alle Felder; jeder geschriebene Buchstabe hat einen Leser; der Raid-Export ist mit und ohne
  Wünsche gleich.
- `test_wish_import.py` mit `site_wishes.cjs` (schneidet `amSplit`, `amParseWishes`,
  `wishAddonText`, `wishImportPlan` aus `index.html`, Stubs für `state`, `ITEM`, `WISHES`): neue,
  doppelte, erhaltene, unbekannte Items und Raider; Grenze 30; Text für das Addon und zurück durch
  den Lua-Parser (über `lupa` wie `test_export_format.py`).
- Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review).

## Vorschlag für den Plan (8 Aufgaben)

1. **Wertung und Kern:** Gear.lua (`Gear.Game`, `Gear.Cap`, Rating über 60, Sockel-, Abhärtungs-
   und Durchschlags-Schlüssel, `OHDPS`, `Gear.ScoreParts`, Einheit, Tooltip-Leser, `Gear.FillRow`,
   Quellenarten `X`/`F`/heroisch, `Gear.FilterKey`, `Gear.SourceOk` mit Phase und Ausschlüssen,
   `Gear.PlaceOf`, `Gear.PlannerAvailable`); GearFrame auf `PlannerAvailable`; Stub;
   `test_bis_score.lua`, `test_gear.lua` grün.
2. **TBC-Daten:** `tools/build_bis.py` (AtlasLoot lesen und zwischenspeichern, Tokens, Phasen, Namen,
   optionale CSV, Gewichte `OWN_TBC`, Ausgabe mit Wächter), erster Lauf auf dem N100,
   `BisDataTBC.lua`, `BisWeightsTBC.lua`, TOC; `build_gear.py` (Wächter, `D` mit Ort, `X` aus
   `forever.js`; laufen lassen erst auf dem PC); `tools/README.md`; `test_build_bis.py`,
   `test_build_gear.py`.
3. **Ziele, Besitz, Ausschlüsse, Hier:** Bis.lua (Charakterdaten und Umzug, `ns.BisOpts`,
   `ns.BisTargets`, `ns.BisGain`, `ns.BisExplain`, Besitz mit Bank je Client, Spez. raten, Berufe,
   Ausschlüsse, `ns.BisHere`, `ns.BisPlaces`), Abschnitt "bis", Befehle `bis`; `test_bis_targets.lua`.
4. **Wunschliste und Hinweis:** `ns.Wish*`, Selbst-aufräumen, Auslöser, Hinweis-Fenster, Ton,
   `ns.WishExportText`, Befehl `wunsch`; `test_bis_wish.lua`.
5. **Tooltip-Zeile:** Hook, Texte, Shift-Erklärung, Schutz; `test_bis_tooltip.lua`.
6. **Gildenwünsche:** GuildWishes.lua (Parser, Speichern, `ns.WishersOf`, Tooltip-Zeile, Marke "W",
   Vergabe-Dialog), Befehl `wuensche`; `test_guild_wishes.lua`.
7. **Seite und Anschlüsse:** Pages/Gear.lua neu (Ziele mit Detail, Hier, Wunschliste mit Export,
   Gilde mit Import), Karte, Planer-Haken, Schnellmenü; `test_bis_page.lua`, `test_pages.lua`.
8. **Website und Auslieferung:** `amParseWishes`, Import-Hinweis, "Paste from the addon", "Copy for
   the addon"; `site_wishes.cjs`, `test_wish_import.py`, `test_export_format.py`; Twin bauen,
   veröffentlichen, stempeln; Version 1.8.0 (TOC, `ns.VERSION`), alle Tests
   (`~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
   `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs`),
   `tools/release_addon.sh`, ZIP gegen die TOC prüfen, unabhängige Prüfung.

## Auslieferung

Version 1.8.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh` (füllt den Release-Ordner, den Syncthing sendet), im Spiel `/reload`.
Twin neu bauen, veröffentlichen und stempeln. Auf dem PC danach: `python tools/build_gear.py`
(Instanz-IDs für "Hier" in Forever-Dungeons), optional `python tools/build_bis.py --wow-root ...`
für deutsche Dungeon-Bossnamen, und auf Anniversary einmal `/amisia scan gear` plus `--sv`, damit
die Werte ohne Laden da sind.

## Ideen aus der Recherche

Übernommen:
- Mehrere Optionen je Slot (drei) statt eines einzigen BiS-Items; Besitz abhaken, angelegt und in
  der Bank mitgezählt.
- Item oder Quelle ausschließen, damit die nächste aufrückt; Filter für Fraktion und Berufe.
- "Was kann ich hier noch holen" für Raid, Dungeon und Gebiet.
- Wunschliste mit Hinweis beim Drop, die sich selbst aufräumt.
- Tooltip-Zeile, die nie andere Tooltips bricht, mit abschaltbarer Zusatzzeile; erklärte Wertung.
- Wenige Schalter, jeder Teil einzeln abschaltbar.
- Brücke Website <-> Spiel als Text: die Lücke "Wünsche der Website ins Spiel" schließen, ohne
  Begleitprogramm.

Später:
- Trefferwert-Grenze und andere Grenzen aus den eigenen sichtbaren Werten (`GetCombatRating`) statt
  linearer Trefferwertung.
- Setboni, Sockelbonus, Edelstein- und Verzauberungsvorschläge.
- Zufallsbonus-Items nach bestem möglichem Bonus werten ("...des Adlers").
- "Kette": Upgrades Schritt für Schritt virtuell anlegen und Dungeons nach Upgrade-Potenzial ordnen.
- Andere Klasse oder anderes Level simulieren auf der Seite (in Forever kann es die Tabelle).
- Pfeil oder Wegpunkt zur Quelle (Baustein 2, Karte).
- Upgrade-Marken an Taschen, Charakterfenster und Questbelohnungen.
- "Für wen ist das ein Upgrade" aus den Rechnungen der Raider (Baustein 7, Sync).

## Nicht in Baustein 3

Kuratierte BiS-Listen von Websites; Inspizieren anderer Raider; Sync der Wünsche oder Upgrades
zwischen Clients (Baustein 7); Wünsche als Regel in der Roll-Reihenfolge oder Loot-Rat mit
Abstimmung; Ansage der Wünschenden im Raidchat; PvP-Ausrüstung und Abhärtung; Questbelohnungen in
TBC; Setboni, Sockelbonus, Verzauberungen, Edelsteinwahl; Trefferwert-Grenzen; Simulation anderer
Klassen auf der Seite; Marken in Taschen und Charakterfenster; Karte und Wegpunkte (Baustein 2);
Wunschliste im Twin (keine Datenbank); deutscher Text auf der Website.

## Offene Punkte

Nur im Spiel zu klären:

- Ob Anniversary ein globales `GetItemStats` hat und welche Schlüssel es liefert (mit oder ohne
  `_SHORT`, `EMPTY_SOCKET_*`): `/dump GetItemStats("item:28830")` und `/amisia bis item <Link>`.
  Fehlt es, liest der Tooltip-Leser; der ist dann gegen echte deutsche Tooltip-Zeilen zu prüfen.
- Ob `[AllowLoadGameType tbc]` die TBC-Daten auf Anniversary lädt (der Wächter verhindert sie auf
  Forever sowieso): `/amisia bis` muss Daten zeigen.
- Ob `C_Item.GetItemCount(id, true)` die Bank ohne Bankbesuch zählt (beide Clients) und ob Forever die
  Bank über `C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)` liefert.
- Ob `GetInstanceInfo()` in TBC-Raids die Instanz-IDs von AtlasLoot liefert (Karazhan 532) und ob
  `C_Map.GetAreaInfo` deutsche Namen gibt.
- Ob `C_SpecializationInfo.GetSpecializationInfo(i)` auf beiden Clients die Talentpunkte je Baum
  liefert (Spez. raten).
- Ob `GetSkillLineInfo` auf Forever die Berufe mit Fertigkeit nennt.
- Ob die Tooltip-Zeile an Lootfenster, Würfelfenster, Chat-Link, Taschen und Auktionshaus erscheint
  und neben der SR-Zeile und Zeilen anderer Addons stehen bleibt.
- Ob der Hinweis aus der Loot-Ansage auf Forever nach dem Bosskampf ankommt (Raidchat in der Sperre
  geheim) und ob er bei Master Loot in TBC rechtzeitig vor dem Würfeln kommt.
- Ob die TBC-Startgewichte für die Gilde stimmige Reihenfolgen ergeben (Offiziere und Raider
  vergleichen ein paar Slots mit ihrem Wissen; Änderungen gehen ins Skript).
- Entschieden: keine fremden BiS-Listen, eigene Wertung; Wünsche lokal je Charakter und als Text zur
  Website; Gildenwünsche als Text ins Spiel; kein Inspizieren; Phase-Standard "alle"; Upgrade ab 2 %
  mehr Wertung; Wünschende zuerst im Vergabe-Dialog (abschaltbar), keine Änderung der
  Roll-Reihenfolge.
