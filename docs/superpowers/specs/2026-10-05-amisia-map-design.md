# Amisia 1.9: Karte (Wegpunkt und Pins)

Stand 2026-10-05. Baustein 2 von 7 (Reihenfolge der Umsetzung laut Nutzer: 5, 4, 6, 3, 2, 7).
Baut auf Baustein 1 (`docs/superpowers/specs/2026-10-04-amisia-main-window-design.md`: Registry,
Widgets, Hauptfenster, Seiten) und Baustein 3 (`docs/superpowers/specs/2026-10-05-amisia-bis-design.md`:
Quellen in `Gear.lua`, `Gear.PlaceOf`, Ziele, Wunschliste, Hier, Tooltip-Zeile über
`ns.OnItemTooltip`) auf. Ändert das Addon `addon/Amisia`, ein neues Erzeugungsskript
`tools/build_map.py` und (nur für den späteren PC-Lauf) `tools/build_gear.py`. Website, Export und
Twin ändern sich nicht.

Wort-Hinweis: "Karte" heißt in diesem Entwurf die Weltkarte des Spiels und die neue Seite "Karte".
Die Kacheln der Übersicht heißen hier "Übersichtskarte".

## Ziel

Baustein 3 sagt, **was** ein Charakter holen sollte und **woher** es kommt ("Händler: Gorn One
Eye", "Quest: Die Eberjagd", "Karazhan: Prinz Malchezaar"). Wo dieser Händler steht oder wo die
Quest beginnt, muss der Spieler heute selbst suchen. In der Recherche ist genau das der meistgenannte
Wunsch an Ausrüstungs- und Dungeon-Addons ("Wegpunkte, Händlerorte", "Klick auf die Quest zeigt den
Start auf der Karte", "alle Marker auf einmal"). Baustein 2 bringt:

- **Wegpunkt zur Quelle:** ein Klick auf eine Quelle (Questgeber, Händler, Rüstmeister, Rare,
  benannter Gegner, Dungeon- oder Raid-Eingang) auf der Seite "Ausrüstung", in der Wunschliste, auf
  der neuen Seite "Karte" oder per Befehl setzt ein Ziel. In WoW Forever wird es der Wegpunkt des
  Clients (Weltkarte, Minimap, Wegweiser am Bildschirm); in TBC Anniversary, das keine
  Spieler-Wegpunkte kennt, zeigt Amisia einen eigenen Pin auf der Weltkarte und einen eigenen Pfeil
  mit Entfernung.
- **Pins auf der Weltkarte:** alle Orte, an denen es Upgrades aus "Ziele" oder Wünsche gibt, auf
  der gerade gezeigten Zone (und auf Wunsch auf der Kontinentkarte), mit Item-Symbol und Tooltip.
  Einzeln und gesamt abschaltbar.
- **Seite "Karte":** eine Liste der Orte einer Zone (Standard: die Zone, in der du stehst) mit
  Quelle, Koordinaten, Items und Knopf "Weg".
- **Fundort im Tooltip:** mit gedrückter Shift-Taste eine graue Zeile "Fundort: Gorn One Eye,
  Durotar 47, 33".

Alles ist reine Anzeige von Orten, die jeder Spieler auf der Karte selbst finden kann.

## Rahmen und Entscheidungen

- **Clients, Bibliotheken, Schrift:** wie die Bausteine 1, 3 bis 6. Ein TOC (`20506, 16001`), keine
  fremden Bibliotheken (keine Karten- oder Pin-Bibliothek), kein `UIDropDownMenu`/`EasyMenu`, UI-
  und Chat-Texte deutsch und nur Latin-1 (ä ö ü ß und "·", kein Gedankenstrich, keine
  Auslassungspunkte, keine Pfeile; der Pfeil ist eine Textur), Code-Kommentare englisch. Anmeldung
  nur über `ns.RegisterPanel`, `ns.RegisterCard` (hier nicht gebraucht), `ns.RegisterSettings`,
  `ns.RegisterSlash`. Forever hat kein globales `GetItemInfo`/`GetItemInfoInstant`: neue Dateien
  nehmen den `C_Item`-Shim wie Core.lua. Werte aus APIs gehen durch `ns.Plain`.
- **Keine anderen Addons nennen**, weder in UI-Texten, Chat, Kommentaren noch Commits. Die
  Datenquelle (QuestieDB) wird nur dort genannt, wo die Lizenz es verlangt: im Kopf der erzeugten
  Dateien, in `tools/README.md` und in diesem Entwurf.
- **Auf beiden Clients.** Baustein 1 sah die Karte nur für Forever vor; seit Baustein 3 gibt es die
  Ausrüstungsseite auch in TBC, und die TBC-Quellen (Raid- und Dungeon-Eingänge, Abzeichen-Händler,
  Rüstmeister) haben feste Orte. Die Karte kommt deshalb auf beide Clients, mit je eigenem Datensatz
  wie `GearData`/`BisDataTBC`.
- **Ein Ziel zur Zeit.** Amisia setzt höchstens ein Ziel (wie der Client nur einen
  Spieler-Wegpunkt kennt). Ein neues Ziel ersetzt das alte. Die Pins zeigen dagegen alle Orte.
- **Forever: Wegpunkt des Clients.** `C_Map.SetUserWaypoint` plus
  `C_SuperTrack.SetSuperTrackedUserWaypoint(true)` (beide in Forever dokumentiert, die Weltkarte
  von Forever lädt die Datenquellen für Wegpunkt und Wegweiser). Damit zeigen Weltkarte, Minimap und
  der Wegweiser am Bildschirm das Ziel ohne eigene Pfeil-Logik. Ein Wegpunkt, den der Spieler selbst
  gesetzt hat, wird nur ersetzt, wenn er ein Amisia-Ziel wählt; gelöscht wird nur ein Wegpunkt, den
  Amisia gesetzt hat (Position verglichen).
- **TBC Anniversary: eigener Pin und eigener Pfeil.** Die Client-Quellen 2.5.6 dokumentieren keine
  Spieler-Wegpunkte und kein `C_SuperTrack`; der einzige Aufruf von `C_Map.SetUserWaypoint` steht in
  Code eines anderen Spielmodus, und die TBC-Weltkarte lädt keine Wegpunkt-Datenquelle. Amisia
  markiert das Ziel deshalb mit einem hervorgehobenen Pin auf der Weltkarte und zeigt einen kleinen,
  verschiebbaren Pfeil mit Entfernung. Ein eigener Pin **auf der Minimap** kommt nicht: er bräuchte
  Tabellen für Minimap-Zoom und Innen/Außen je Client, die sich nicht aus den Client-Quellen
  belegen lassen (siehe "Nicht in Baustein 2").
- **Pins über die Datenquellen-Schnittstelle der Weltkarte** (`WorldMapFrame:AddDataProvider`,
  `MapCanvasDataProviderMixin`, `MapCanvasPinMixin`, `AcquirePin`), die beide Clients haben. Die
  Pin-Vorlage ist eine kleine XML-Datei (`MapPin.xml`, eine virtuelle Vorlage mit
  `mixin="AmisiaMapPinMixin"`), weil `AcquirePin` eine benannte Vorlage für seinen Frame-Pool
  braucht. Kein Schreiben in Tabellen der Weltkarte (`pinPools`), keine Hooks auf ihre Methoden.
- **Koordinaten erzeugt, nicht gesucht.** Orte kommen aus QuestieDB (NPC-Spawns, Objekte,
  Questgeber, Dungeon-Eingänge), das Questie im öffentlichen Git-Repository `Questie/QuestieDB` als
  Lua-Quelltext für Forever **und** TBC führt. Das neue Skript `tools/build_map.py` lädt diese
  Dateien über GitHub und **läuft auf dem N100**. Damit leuchtet fast alles ohne den PC auf (siehe
  "Was ohne PC geht").
- **Daten getrennt von den Itemdaten.** `MapData.lua` (Forever) und `MapDataTBC.lua` (TBC) halten
  Orte unter einem stabilen Schlüssel je Quelle (Quest-ID, NPC-Name, Instanz-ID, Fraktions-ID), nicht
  unter der Quellennummer. Ein Neubau von `GearData.lua` auf dem PC macht die Kartendaten nicht
  kaputt; neue Quellen bekommen ihren Ort beim nächsten `build_map.py`-Lauf.
- **Nur Zonen und Kontinente.** Pins und Pfeil gelten für die offene Welt. In Instanzen gibt es
  keine Koordinaten (Questie führt Bosse dort mit -1, -1; der Client gibt in Instanzen keine
  Spielerposition), deshalb zeigt Amisia für Raid- und Dungeon-Quellen den **Eingang**.
- **Forever-Haltung:** Informationen anzeigen ist erlaubt. Amisia zeigt feste Orte aus Questdaten
  und Spawnpunkten, wie eine Karte im Buch. Es liest keine Positionen anderer Spieler oder Gegner,
  keine Kampfdaten, und es arbeitet in Instanzen nicht.
- **Englische NPC-Namen.** Der Client kennt NPC-Namen nur von gesehenen Einheiten; die Daten
  führen die englischen Namen (wie heute die Händler in "Ziele"). Zonen heißen deutsch
  (`C_Map.GetMapInfo`), Raids und Dungeons ebenso (`C_Map.GetAreaInfo`).

## Dateien

```
tools/build_map.py              NEU: erzeugt MapData.lua und MapDataTBC.lua aus QuestieDB (GitHub)
                                und den erzeugten Itemdaten; läuft auf dem N100
tools/cache/questiedb/          NEU, nicht in git: geladene QuestieDB-Dateien mit COMMIT
tools/map_questie.json          NEU: Zwischenspeicher der gebrauchten Orte (in git, deterministischer Bau
                                ohne Netz, wie bis_atlas_tbc.json)
addon/Amisia/MapData.lua        NEU, erzeugt: ns.MAP für Forever
addon/Amisia/MapDataTBC.lua     NEU, erzeugt: ns.MAP für TBC
addon/Amisia/Map.lua            NEU: Schlüssel je Quelle, Punkte, nächster Punkt, Ziel, Wegpunkt
                                (Forever), Pfeil (beide), Zustand und Umzug, Abschnitt "map",
                                Befehl karte, Tooltip-Zeile "Fundort"
addon/Amisia/MapPins.lua        NEU: Datenquelle der Weltkarte, AmisiaMapPinMixin, Pin-Tooltip und -Menü
addon/Amisia/MapPin.xml         NEU: virtuelle Vorlage AmisiaMapPinTemplate (nur Größe und mixin)
addon/Amisia/Pages/Map.lua      NEU: Seite "Karte"
addon/Amisia/Media/Icons/arrow.tga   NEU: Pfeil-Textur (64 x 64, 32-bit TGA, über den Skill make-icon)
addon/Amisia/Pages/Gear.lua     Menüeinträge "Wegpunkt setzen", "Auf der Karte zeigen"; Karten-Knopf
                                an Quellen in Ziele (Detail), Hier und Wunschliste
addon/Amisia/Bis.lua            Shift-Zeile "Fundort" über ns.MapTooltipLine (nur ein Aufruf)
addon/Amisia/Minimap.lua        Schnellmenü: "Karte" nach "Ausrüstung"
addon/Amisia/Amisia.toc         MapData.lua [AllowLoadGameType camelot], MapDataTBC.lua
                                [AllowLoadGameType tbc] nach BisWeightsTBC.lua; Map.lua, MapPins.lua,
                                MapPin.xml nach GuildWishes.lua; Pages\Map.lua nach Pages\Gear.lua;
                                Version 1.9.0
addon/tests/run.py              überspringt .xml-Zeilen der TOC
tools/build_gear.py             (für den PC-Lauf) NPC-ID als letztes Feld in V, P, R, W
tools/README.md                 build_map.py, Lizenz, was den PC braucht
tools/tests/test_build_map.py   NEU
addon/tests/*                   neue Tests, Stub ergänzt
```

Unverändert: Core.lua, Gear.lua (nur gelesen: `Gear.PlaceOf`, `Gear.Sources`, `Gear.SourceText`),
GearData.lua, BisDataTBC.lua, index.html, Export.

## Datenmodell

### Kartendaten (`ns.MAP`, erzeugt)

```lua
-- GENERATED by tools/build_map.py. Do not edit; rebuild instead.
-- Sources: QuestieDB (GPL-3.0) npc, object, quest and zone data at <commit>; Amisia's quartermaster list.
local _, ns = ...
if not (ns.IsForever and ns.IsForever()) then return end      -- MapDataTBC.lua: if ns.IsForever and ns.IsForever() then return end

-- P: [source key] = up to four points "uiMapID:x:y" (x, y in hundredths of a percent, 0-10000),
-- separated by spaces. G: [source key] = who stands there (quest giver, quartermaster), English.
ns.MAP = {
    game = "forever", built = "2026-10-05", questie = "1a2b3c4d5e",
    P = {
        ["Q:7"] = "1429:4232:6510",                 -- quest 7 starts here (giver or object)
        ["V:Gorn One Eye"] = "1411:4720:3310",      -- vendor by name
        ["R:Muad"] = "1420:3510:5520 1420:3820:5010",
        ["W:Harvest Golem"] = "1436:4510:3720",     -- named mob of a world drop
        ["I:36"] = "1436:4250:7170",                -- raid or dungeon entrance by instance id
        ["N:The Deadmines"] = "1436:4250:7170",     -- entrance by dungeon name (records without instance id)
        ["F:935"] = "1955:5097:4170",               -- quartermaster of a faction (TBC)
        ["U:1234"] = "1411:4720:3310",              -- by NPC id, once build_gear.py writes ids (PC)
    },
    G = { ["Q:7"] = "Marshal McBride", ["F:935"] = "Almaador" },
}
```

- **Schlüssel je Quelle** (`ns.MapKeyOf(rec)`, eine Funktion für alle Stellen):

  | Quelle | Schlüssel | Woher der Ort |
  |---|---|---|
  | `Q` Quest | `Q:<rec[7] Quest-ID>` | Questgeber (NPC-Spawns) oder Start-Objekt; Quests, die ein Item startet, haben keinen Ort |
  | `V`, `P` Händler | `U:<NPC-ID>` wenn vorhanden, sonst `V:<rec[2]>` | NPC-Spawns |
  | `R` Rare | `U:<NPC-ID>`, sonst `R:<rec[2]>` | NPC-Spawns (wandernde Rare: bis zu vier Punkte) |
  | `W` benannter Gegner | `U:<NPC-ID>`, sonst `W:<rec[2]>` (nur mit Zone, nicht "Trash (...)") | NPC-Spawns |
  | `W` "Trash (Dungeon)" | `N:<Dungeon>` | Eingang |
  | `X`, `D` | `Gear.PlaceOf(rec)` ohne "/H", also `I:<Instanz>` oder `N:<Name>` | Eingang |
  | `F` Ruf | `F:<rec[4] factionID>` | Rüstmeister aus der Liste im Skript |
  | `C`, `A`, `W` ohne Namen | keiner | nicht ortsgebunden |

- **Punkte:** höchstens vier je Schlüssel. Bei mehreren Spawns wählt das Skript die vier, die am
  weitesten auseinander liegen (gierig, auf 2 % gerundet zusammengefasst), damit wandernde Rare und
  Questgeber beider Fraktionen alle vorkommen. Spawns mit -1, -1 (in Instanzen) fallen weg.
- **Zonen:** Questie führt Spawns nach Gebiets-ID (areaID); das Skript rechnet sie mit Questies
  Tabelle `areaIdToUiMapId` in uiMapIDs um. Gebiete ohne uiMapID fallen weg und werden gezählt.
- **Speicher:** etwa 1.000 Schlüssel je Client, als kurze Zeichenketten; geparst wird erst beim
  Gebrauch und dann je Schlüssel gemerkt (`Map.Points(key)`).

### Zustand (`AmisiaDB.map`)

```lua
AmisiaDB.map = {
    v = 1,
    target = {                       -- nil: kein Ziel
        map = 1411, x = 0.472, y = 0.331,          -- uiMapID, 0-1
        key = "V:Gorn One Eye", item = 6380,       -- Quelle und Item, für die Anzeige
        label = "Gorn One Eye",                    -- Kurztext für Pfeil und Seite
        at = 1759601000,
        ours = true,                               -- Forever: Wegpunkt des Clients von Amisia gesetzt
    },
    hidden = { ["V:Gorn One Eye"] = true },        -- auf der Weltkarte ausgeblendete Orte
}
```

Fensterzustand (kein Schema, wie bei Baustein 3): `settings.map.arrowPos` (Pfeilposition),
`settings.map.zone` (gewählte Zone der Seite, nil = aktuelle).

### Umzug

Beim `ADDON_LOADED` (Map.lua): `AmisiaDB.map = AmisiaDB.map or { v = 1, hidden = {} }`. Geprüft:
`target` braucht Zahl `map > 0` und `x`, `y` zwischen 0 und 1, sonst fällt es weg; `hidden` behält
nur Zeichenketten-Schlüssel mit `true`. Zweimal laden ändert nichts. Bestehende Daten bleiben.

## Datenquellen und Erzeugung

### `tools/build_map.py` (N100)

```
python tools/build_map.py [--refresh-questie] [--game forever|tbc|both]
```

- **Eingaben:**
  - QuestieDB (GitHub `Questie/QuestieDB`, Zweig `master`): `data/Forever/foreverNpcDB.lua`,
    `foreverQuestDB.lua`, `foreverObjectDB.lua`; `data/TBC/tbcNpcDB.lua`, `tbcQuestDB.lua`,
    `tbcObjectDB.lua`; `support/Zones/dungeons.lua` (Eingänge je Dungeon-Gebiet mit Zone und
    Koordinaten, auch alle TBC-Raids und -Dungeons), `areaIdToUiMapId.lua`,
    `instanceIdToAreaId.lua`. Jede Datei hält ihre Tabelle als `[[return {...}]]`; das Skript führt
    nur diesen Block mit `lupa` aus (wie `build_bis.py` AtlasLoot liest).
  - Die erzeugten Itemdaten `addon/Amisia/GearData.lua` und `BisDataTBC.lua` (mit `lupa` geladen,
    Wächter über ein `ns`-Stub): sie sagen, welche Schlüssel gebraucht werden. Nur diese kommen in die
    Ausgabe.
- `--refresh-questie` lädt die Dateien über `raw.githubusercontent.com` nach
  `tools/cache/questiedb/` (nicht in git) und schreibt den Commit (GitHub-API
  `repos/Questie/QuestieDB/commits/master`) nach `tools/cache/questiedb/COMMIT`. Das Gelesene
  (je gebrauchtem NPC, Objekt und Quest nur Name, Zone und Spawns) landet in `tools/map_questie.json`
  (in git), damit ein Bau ohne Netz dieselbe Datei ergibt.
- **Auflösung:**
  - `Q`: `questData[id][2]` (`startedBy`): Feld 1 NPCs, Feld 2 Objekte; Spawns aller Starter,
    `G` = Name des ersten NPC-Starters. Item-Starter (Feld 3): kein Ort.
  - `V`, `P`, `R`, `W` nach Name: alle NPCs dieses Namens; liegt einer in der Zone der Quelle
    (`rec` Zone über dieselbe Tabelle), nur diese, sonst alle. Doppelte Namen in verschiedenen Zonen
    zählt das Skript als "mehrdeutig" und meldet sie.
  - `U:<id>` (sobald `build_gear.py` NPC-IDs schreibt): die Spawns dieses NPC.
  - `I:`, `N:`: Eingang aus `dungeons.lua` (Feld 4, alle Eingänge, z. B. Karazhan zwei), über
    `instanceIdToAreaId` bzw. den Namen (Vergleich ohne Groß/Klein, Satzzeichen und "The", wie
    `dungeon_key` in build_gear.py), dazu Questies Korrekturen weiter unten in derselben Datei
    (`dungeons[area][4] = ...`).
  - `F`: Tabelle `QUARTERMASTERS` im Skript (Fraktions-ID -> NPC-Name), geprüft gegen
    `tbcNpcDB`: Ehrenfeste 946 "Logistics Officer Ulrike", Thrallmar 947 "Quartermaster Urgronn",
    Expedition des Cenarius 942 "Fedryen Swiftspear", Unteres Viertel 1011 "Nakodu", Sha'tar 935
    "Almaador", Hüter der Zeit 989 "Alurmi", Aldor 932 "Quartermaster Endarin", Seher 934
    "Quartermaster Enuril", Kurenai 978 "Trader Narasu", Mag'har 941 "Provisioner Nasela",
    Konsortium 933 "Karaaz", Das Violette Auge 967 "Archmage Leryda", Netherschwingen 1015 "Yarzill
    the Merc", Himmelswache der Sha'tari 1031 "Grella", Ogri'la 1038 "Jho'nass", Offensive der
    Zerschmetterten Sonne 1077 "Eldara Dawnrunner", Die Todeshörigen 1012 "Okuno", Die Wächter der
    Sande 990 "Indormi", Sporeggar 970 "Mycah". Tranquillien (922) hat keinen Rüstmeister in den
    Daten: kein Pin. Eine Fraktion ohne Eintrag meldet das Skript.
- **Ausgabe:** `addon/Amisia/MapData.lua` und `addon/Amisia/MapDataTBC.lua` mit Kopf
  `-- GENERATED by tools/build_map.py. Do not edit; rebuild instead.`, Quellenzeile mit Lizenz und
  Commit, Wächter als erste Anweisung nach `local _, ns = ...` (Forever-Datei:
  `if not (ns.IsForever and ns.IsForever()) then return end`; TBC-Datei umgekehrt), dazu die
  TOC-Bedingung. Schlüssel sortiert, damit zweimal bauen dieselbe Datei gibt.
- **Bericht:** je Quellenart "mit Ort / ohne Ort", unbekannte Gebiete, mehrdeutige Namen, Quests
  ohne Starter, Fraktionen ohne Rüstmeister.

Probelauf am 2026-10-05 gegen den heutigen Stand (Questie `master`, `GearData.lua` vom 04.10.,
`BisDataTBC.lua` vom 05.10.), nur NPC-Starter und Namensabgleich gezählt:

| Client | Quests | Händler | Rare | benannte Gegner | Dungeons/Raids | Ruf |
|---|---|---|---|---|---|---|
| Forever | 686 von 788 | 86 von 86 | 17 von 18 | 37 von 194 `W` (die übrigen sind Trash oder Weltdrops ohne Gegner) | Eingang je Dungeon über den Namen | - |
| TBC | - | 3 von 3 (G'eras) | - | - | alle 25 Gebiete haben einen Eingang in `dungeons.lua` | 19 von 20 Fraktionen |

Berufe (`C`, 207 bzw. 109) und das Auktionshaus haben keinen Ort.

### Was ohne PC geht und was nach dem PC-Lauf dazukommt

**Ohne PC (Baustein 2 liefert es so aus):** alles oben. `build_map.py` braucht nur GitHub und die
Itemdaten im Repository. Forever-Dungeons finden ihren Eingang über den Namen (`N:`), weil die
heutigen Forever-`D`-Quellen noch keine Instanz-ID tragen.

**Nach `python tools/build_gear.py` auf dem PC** (liest die WoW-Installation, siehe Baustein 3), dann
`python tools/build_map.py` auf dem N100:

- `D` mit Instanz- und Gebiets-ID (schon aus Baustein 3 offen): Eingänge über `I:`, auch für Dungeons,
  deren Namen in den Quellen anders geschrieben sind.
- **Neu in Baustein 2:** `build_gear.py` hängt die NPC-ID als letztes Feld an `V`, `P`, `R` und
  benannte `W` an (aus Questie, aus den Sammler-Notizen `[npcID]`). `Map.lua` nimmt dann `U:<id>`
  statt des Namens: richtige Spawns bei gleichnamigen NPCs, und Händler und Gegner, die der Sammler
  mit deutschem Namen notiert hat, bekommen einen Ort. Das neue Feld steht hinten; `Gear.lua` liest
  es nicht und bleibt gleich.
- Neue Quellen aus neuen Scans und Sammler-Notizen bekommen ihren Ort beim nächsten
  `build_map.py`-Lauf.

TBC-Daten (`BisDataTBC.lua`) entstehen schon auf dem N100; `build_map.py` braucht für TBC nie den PC.
AtlasLootClassic führt keine Koordinaten (nur `MapID` und `npcID`); es bleibt Quelle der Items.

### Lizenzen

| Was | Woher | Lizenz | Wo vermerkt |
|---|---|---|---|
| NPC-Spawns, Questgeber, Objekte, Dungeon-Eingänge, Gebiets-Tabellen | QuestieDB (GitHub `Questie/QuestieDB`) | GPL-3.0 (wie bisher für `GearData.lua` vermerkt; siehe offene Punkte) | Kopf von `MapData.lua`/`MapDataTBC.lua`, `tools/README.md` |
| Rüstmeister-Liste | Amisia (eigene Zuordnung) | wie das Addon | `build_map.py` |
| Zonen- und Ortsnamen | der Client im Spiel | - | - |

Nicht verwendet: Wowhead und andere Datenseiten (Bedingungen verbieten das Abgreifen), Kartendaten
anderer Addons.

## Ereignisse und APIs je Client

Geprüft in den Client-Quellen 2.5.6.69795 (Anniversary) und 1.60.1.70205 (Forever),
`Blizzard_APIDocumentationGenerated` und FrameXML.

| API / Ereignis | Anniversary 2.5.6 | Forever 1.60.1 | Verwendung |
|---|---|---|---|
| `C_Map.SetUserWaypoint`, `ClearUserWaypoint`, `CanSetUserWaypointOnMap`, `GetUserWaypoint`, `HasUserWaypoint`, `USER_WAYPOINT_UPDATED` | nicht dokumentiert; einziger Aufruf im Code eines anderen Spielmodus | dokumentiert, `SetUserWaypoint` mit `SecretArguments = AllowedWhenUntainted` | Wegpunkt (Forever) |
| `UiMapPoint.CreateFromCoordinates` | fehlt | `Blizzard_ObjectAPI/Mainline/UiMapPoint.lua` | Wegpunkt bauen |
| `C_SuperTrack.SetSuperTrackedUserWaypoint`, `IsSuperTrackingUserWaypoint`, `SUPER_TRACKING_CHANGED` | nicht dokumentiert | dokumentiert (`SuperTrackManagerDocumentation`) | Wegweiser am Bildschirm |
| Wegpunkt-Pins der Weltkarte (`WaypointLocationDataProvider`, `SuperTrackWaypointDataProvider`) | nicht geladen (TBC-Weltkarte) | geladen (Mainline-`Blizzard_WorldMap.lua`, Forever lädt sie mit) | Anzeige des Client-Wegpunkts |
| `Blizzard_QuestNavigation` (`SuperTrackedFrame`) | - | vorhanden | Wegweiser am Bildschirm |
| `WorldMapFrame:AddDataProvider`, `RemoveDataProvider`, `AcquirePin`, `RemoveAllPinsByTemplate`, `GetMapID` | `Blizzard_MapCanvas`, TBC-Weltkarte nutzt sie | `Blizzard_MapCanvas` (mit `MapCanvasSecureUtil`, Datenquellen über `secureexecuterange`) | Pins |
| `MapCanvasDataProviderMixin` (`OnAdded`, `RefreshAllData`, `RemoveAllData`, `OnMapChanged`, `OnCanvasScaleChanged`) | vorhanden | vorhanden | Datenquelle |
| `MapCanvasPinMixin` (`SetPosition`, `SetScalingLimits`, `UseFrameLevelType`, `OnMouseEnter`, `OnClick`) | vorhanden | vorhanden (`OnMouseUp(button, upInside)`) | Pin |
| `C_Map.GetPlayerMapPosition(uiMapID, "player")` | dokumentiert | dokumentiert, `AllowedWhenUntainted` | Pfeil, Entfernung, Sortierung |
| `C_Map.GetWorldPosFromMapPos`, `C_Map.GetMapRectOnMap`, `C_Map.GetMapInfo`, `C_Map.GetBestMapForUnit` | dokumentiert | dokumentiert | Entfernung, Kontinentkarte, Zonen |
| `CreateVector2D` | FrameXML | FrameXML | Kartenposition |
| `GetPlayerFacing` | nicht in den Quellen (seit Classic 1.13 vorhanden, im Spiel prüfen) | dokumentiert (`PlayerScriptDocumentation`) | Pfeil drehen |
| `UnitPosition("player")` | FrameXML nutzt es | FrameXML nutzt es | Rückfall für die Weltposition |
| Textur `SetRotation` | in den Quellen nur an Modellen genutzt (im Spiel prüfen) | Standard | Pfeil drehen |
| `C_EncounterJournal.GetDungeonEntrancesForMap` | dokumentiert, die TBC-Weltkarte schaltet ihre Eingangs-Pins aber aus | dokumentiert | nicht genutzt (eigene Eingänge aus den Daten) |
| Geheimwerte auf Karten | - | Prädikat `SecretOnRestrictedMaps` existiert, keine Karten-API trägt es | in Instanzen arbeitet Amisia ohnehin nicht |

Ergebnis: **Forever** setzt den Wegpunkt des Clients (Weltkarte, Minimap und Wegweiser zeigen ihn,
im Spiel zu bestätigen); **Anniversary** nimmt Pin plus eigenen Pfeil. Die Wahl trifft
`Map.ClientWaypoints()` zur Laufzeit (`C_Map.SetUserWaypoint`, `UiMapPoint` und `C_SuperTrack`
vorhanden), nicht über die Client-Version.

## Ziel und Wegpunkt (Map.lua)

```lua
ns.MapKeyOf(rec) -> key | nil
ns.MapPoints(key) -> { { map, x, y }, ... }        -- x, y 0-1; leer, wenn unbekannt
ns.MapItemPlaces(id, opts?) -> { { key, rec, points, giver }, ... }   -- Quellen des Items mit Ort, Reihenfolge wie Gear.Sources
ns.MapNearest(points) -> point, yards | point, nil   -- nächster Punkt zum Spieler (gleicher Kontinent), sonst der erste
ns.MapSetTarget(id, key?) -> true | nil, Grund     -- Item und optional Quelle; ohne Quelle die nächste
ns.MapSetPoint(point, label, key?, id?) -> true | nil, Grund
ns.MapClearTarget()
ns.MapTarget() -> target | nil
ns.MapShowOnWorldMap(point)                        -- öffnet die Weltkarte auf der Zone des Punkts
ns.MapTooltipLine(id) -> text | nil
```

- **Ziel setzen** (`ns.MapSetTarget`): Quellen des Items über `Gear.Sources(id, ns.BisOpts())`
  (Filter, Fraktion, Klasse, Phase wie in "Ziele"; ein Wunsch ohne passende Quelle nimmt alle
  Quellen), nur Quellen mit Ort. Mit `key` genau diese Quelle. Unter mehreren Punkten der nächste
  (`ns.MapNearest`): Spielerposition über `C_Map.GetBestMapForUnit("player")` und
  `C_Map.GetPlayerMapPosition`, Weltposition beider Punkte über `C_Map.GetWorldPosFromMapPos`;
  gleicher Kontinent -> kürzeste Entfernung in Metern (Spiel-Einheiten), sonst Punkte auf dem eigenen
  Kontinent zuerst, sonst der erste. Ergebnis in `AmisiaDB.map.target`, `ns.Fire("MAP_TARGET")`,
  Chat (eigener): "Amisia: Ziel Gorn One Eye, Durotar 47, 33 (Lederhose der Wildnis)."
- **Gründe** (Rückgabe, Seite und Befehl zeigen sie): "Für dieses Item kennt Amisia keinen Ort."
  (keine Quelle mit Ort), "Keine Kartendaten für diesen Client." (`ns.MAP` nil), "Diese Zone kennt
  der Client nicht." (`C_Map.GetMapInfo(map)` nil).
- **Forever** (`Map.ClientWaypoints()` wahr): `C_Map.CanSetUserWaypointOnMap(map)` prüfen, dann
  `C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))` und
  `C_SuperTrack.SetSuperTrackedUserWaypoint(true)`; `target.ours = true`. Kann die Karte keinen
  Wegpunkt (Rückgabe falsch), gilt der Weg wie in TBC (Pin plus Pfeil). Auf `USER_WAYPOINT_UPDATED`:
  ist der Wegpunkt weg oder steht er woanders (Spieler hat einen eigenen gesetzt oder ihn gelöscht,
  Abstand > 0,001), löscht Amisia sein Ziel still (`target = nil`), ohne den Wegpunkt anzufassen.
- **Ziel löschen** (`ns.MapClearTarget`): eigenes Ziel weg; in Forever `C_Map.ClearUserWaypoint()`
  nur, wenn `target.ours` und der Wegpunkt noch an derselben Stelle steht.
- **Ankommen:** näher als 15 Meter (Pfeil-Takt oder `USER_WAYPOINT_UPDATED`) -> Chat "Amisia: Ziel
  erreicht (Gorn One Eye)." und mit `map.autoClear` (Standard an) Ziel löschen. In Forever löscht der
  Client den Wegpunkt beim Erreichen selbst; Amisia folgt über das Ereignis.
- **Nach `/reload`:** das Ziel bleibt gespeichert. Forever: steht der Wegpunkt noch, bleibt `ours`;
  sonst wird er neu gesetzt (nur wenn kein fremder Wegpunkt steht). TBC: Pin und Pfeil kommen wieder.
- **Auf der Weltkarte zeigen** (`ns.MapShowOnWorldMap`): `ToggleWorldMap`/`OpenWorldMap` falls zu,
  dann `WorldMapFrame:SetMapID(map)`; kein Eingriff in Zoom. Nicht im Kampf
  (`InCombatLockdown()` -> Hinweis "Im Kampf öffnet Amisia die Weltkarte nicht.").

### Pfeil (`AmisiaArrow`)

- Gezeigt bei `map.arrow` = "auto" (Standard: nur ohne Client-Wegweiser, also in TBC) oder "an", und
  nur mit Ziel, außerhalb von Instanzen und wenn die Spielerposition lesbar ist.
- Frame 96 x 84, MEDIUM, beweglich mit Linksziehen (Position in `settings.map.arrowPos`), oben Mitte
  bei y -120 als Start. Inhalt: Textur `Media\Icons\arrow.tga` (56 x 56, Spitze nach oben),
  darunter Zeile 1 `label` (weiß, gekürzt auf 90 px), Zeile 2 "230 m" (gold) bzw. "Angekommen"
  (grün) bzw. "Anderer Kontinent" (grau, Pfeil ausgeblendet).
- Drehung: Winkel zum Ziel aus den Weltpositionen minus `GetPlayerFacing()`, `texture:SetRotation`.
  Fehlt `GetPlayerFacing` oder `SetRotation`, bleibt der Pfeil aus und Zeile 2 nennt die Richtung in
  Worten nach Kartennorden ("230 m Nordost"; acht Richtungen: Nord, Nordost, Ost, Südost, Süd,
  Südwest, West, Nordwest).
- Takt: `OnUpdate`, gedrosselt auf 0,1 s, nur solange der Pfeil sichtbar ist. Kein Takt ohne Ziel.
- Klick: Rechtsklick öffnet W.Menu mit "Ziel löschen", "Auf der Weltkarte zeigen", "Pfeil
  ausblenden" (setzt `map.arrow` = "aus"). Tooltip beim Überfahren: Quelle und Item.

### Tooltip-Zeile "Fundort"

`ns.MapTooltipLine(id)` liefert mit `map.tooltip` (Standard an) für ein Item mit Ort "Fundort:
<Name>, <Zone> <x>, <y>" (nächster Punkt, Koordinaten ganzzahlig), sonst nil. Bis.lua hängt sie an
die bestehenden Shift-Zeilen der Tooltip-Zeile an (grau, gleiche Schutzregeln: in `pcall`, nur
`AddLine`). Keine eigene Tooltip-Anmeldung. Für Raids und Dungeons: "Fundort: Karazhan (Eingang
Gebirgspass der Totenwinde 47, 70)".

## Pins auf der Weltkarte (MapPins.lua, MapPin.xml)

- **Anmeldung:** sobald `WorldMapFrame` existiert (`PLAYER_LOGIN`; die Weltkarte ist in beiden
  Clients beim Login geladen, sonst bei `ADDON_LOADED` "Blizzard_WorldMap"):
  `provider = CreateFromMixins(MapCanvasDataProviderMixin, AmisiaMapProviderMixin)`,
  `WorldMapFrame:AddDataProvider(provider)`. Fehlt eins davon (Typprüfung), gibt es keine Pins; Seite,
  Wegpunkt und Pfeil gehen trotzdem.
- **Vorlage** (`MapPin.xml`): `<Frame name="AmisiaMapPinTemplate" mixin="AmisiaMapPinMixin"
  virtual="true"><Size x="20" y="20"/></Frame>`. `AmisiaMapPinMixin = CreateFromMixins(MapCanvasPinMixin)`
  steht in MapPins.lua (lädt vor der XML-Datei). Texturen (Symbol, Rahmen, Zahl) entstehen in
  `OnLoad` in Lua.
- **Welche Orte** (`Map.PinPlaces(mapID)`): aus "Ziele" die Optionen 1-3 je Slot, die ein Upgrade
  sind und nicht besessen werden (`map.pinsTargets`, Standard an), und alle Wünsche, die nicht
  besessen werden (`map.pinsWishes`, Standard an). Je Item seine Quellen mit Ort (wie
  `ns.MapSetTarget`, Filter der Seite), je Punkt auf der gezeigten Karte ein Eintrag. Punkte mit
  gleichem Schlüssel und gleicher Stelle (auf 0,5 % gerundet) werden ein Pin mit mehreren Items.
  Ausgeblendete Schlüssel (`AmisiaDB.map.hidden`) fehlen. Höchstens 60 Pins je Karte, nach
  Wunsch-Priorität, dann Zuwachs.
- **Kartenarten:** Zone (`Enum.UIMapType.Zone`, 3): Punkte dieser uiMapID. Kontinent (2), nur mit
  `map.pinsContinent` (Standard an): Punkte aller Zonen, deren Rechteck `C_Map.GetMapRectOnMap(zone,
  continent)` liefert, umgerechnet (`x' = left + x * (right - left)`), Pins dort 70 % groß. Welt,
  Dungeon, Mikro: keine Pins.
- **Neu zeichnen:** `RefreshAllData` (Karte gezeigt, Kartenwechsel über `OnMapChanged`) und auf
  `BIS_CHANGED`, `MAP_TARGET`, `SETTING` (nur `map.*`) und `ns.BisOnOwned`, solange die Weltkarte
  offen ist (gedrosselt 0,5 s). Die Pin-Liste je Karte wird mit `ns.BisStamp()` gemerkt.
- **Aussehen:** Item-Symbol des besten Items (`C_Item.GetItemIconByID`, Shim) 18 x 18 mit
  Rahmen 1 px: gold für Wünsche, grün für Upgrades; bei mehreren Items eine kleine Zahl unten rechts
  ("3"). Das Ziel bekommt einen eigenen Pin: Textur `Media\Icons\dot.tga` gold, 24 x 24, darüber das
  Symbol, Rahmenebene über den anderen (`UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")`, im Spiel
  prüfen, sonst Standard). Skalierung `SetScalingLimits(1, 1.0, 1.6)` mal `map.pinScale`.
- **Tooltip** (GameTooltip am Pin): Titel `Gear.SourceText(rec)` (bei Quests mit Questgeber "Quest:
  Die Eberjagd (5) · Marshal McBride"), Koordinaten grau "47, 33", dann je Item eine Zeile Name in
  Qualitätsfarbe und rechts "+14 (Brust)" bzw. "Wunsch (hoch)"; unten grau "Klick: Ziel setzen.
  Rechtsklick: mehr." Nur `AddLine`/`AddDoubleLine` am eigenen `SetOwner`.
- **Klick:** Links setzt das Ziel auf diesen Punkt (`ns.MapSetPoint`). Shift-Links postet in Forever
  den Wegpunkt-Link (`C_Map.GetUserWaypointHyperlink()` nach dem Setzen, über
  `ChatEdit_InsertLink`), in TBC "<Name> <Zone> 47, 33" als Text in die Eingabe. Rechts öffnet W.Menu:
  "Ziel setzen", "Item auf der Seite zeigen" (`ns.ShowGear("goals", slot)` bzw. Wunschliste), "Diesen
  Ort ausblenden" (`hidden[key] = true`), "Alle Pins aus" (`map.pins` aus).
- Pins sind reine Anzeige: keine geschützten Aktionen, keine Hooks an Karten-Methoden, keine
  Änderungen an Frames der Weltkarte außer den eigenen Pins.

## Seite "Karte" (Pages/Map.lua)

`ns.RegisterPanel{ key = "map", label = "Karte", icon = "Interface\\Icons\\INV_Misc_Map_01",
order = 55, available = function() return Gear.Available() and ns.MAP ~= nil end }` auf beiden
Clients. Inhaltsfläche 602 x 478.

```
+------------------------------------------------------------------------------------------+
| [Hier: Durotar v]      [Ziele] [Wünsche]                         [Weltkarte öffnen]       |  y 0
| 9 Orte · 14 Items · 3 Items ohne Ort (Berufe, Weltdrops)                                  |  y -26
| Ziel: Gorn One Eye, Durotar 47, 33 · 230 m                          [Ziel löschen]        |  y -48
| Art        Quelle                     Ort         Items                     Weg            |  y -74
| Händler    Gorn One Eye               47, 33      Lederhose der Wildnis +2   [Weg]         |
| Quest      Die Eberjagd (Marshal M.)  41, 66      Ring des Tals              [Weg]         |
| ...                                    (12 Zeilen à 24 px, Mausrad)                        |
+------------------------------------------------------------------------------------------+
| Klick auf eine Zeile: Ziel setzen. Shift-Klick: auf der Weltkarte zeigen.                 |  y -390
| Kartendaten vom 05.10.2026 · Orte nach Questie-Daten, Namen englisch.                     |  y -408
+------------------------------------------------------------------------------------------+
```

- **Kopf** (y 0): Zonen-Picker (W.Picker 240 px): "Hier: <Zone>" zuerst (aktuelle Zone aus
  `C_Map.GetBestMapForUnit`, bei Unterzonen die nächste Eltern-Zone vom Typ Zone; in einer Instanz
  die Zone des Eingangs, sonst "Hier: in einer Instanz"), dann alle Zonen mit mindestens einem Ort
  aus den aktuellen Zielen und Wünschen, alphabetisch mit Zahl ("Durotar (4)"). Wahl in
  `settings.map.zone`. Chips "Ziele" (60) und "Wünsche" (70) schalten `map.pinsTargets` und
  `map.pinsWishes` (dieselben Schalter wie die Pins: was die Seite zeigt, zeigt die Karte). Rechts
  "Weltkarte öffnen" (130), öffnet die Weltkarte auf der gewählten Zone.
- **Zahlenzeile** (y -26): Orte, Items, Items ohne Ort mit Grund in Klammern (Quellenarten).
- **Zielzeile** (y -48): "Ziel: <label>, <Zone> x, y · 230 m" oder "Kein Ziel gesetzt."; Knopf "Ziel
  löschen" (110) nur mit Ziel. In Forever mit eigenem Wegpunkt des Spielers: "Dein eigener Wegpunkt
  ist gesetzt; Weg ersetzt ihn." (grau).
- **Liste** (W.List 12 Zeilen à 24 px, ab y -92): Art 0-70 ("Quest", "Händler", "PvP-Händler", "Rar",
  "Gegner", "Eingang", "Rüstmeister"), Quelle 74-260 (Name, bei Quests Titel und Geber in
  Klammern; Ziel-Zeile gold), Ort 264-330 ("47, 33"; mit Entfernung, wenn der Spieler in dieser Zone
  ist, sortiert danach), Items 334-540 (bestes Item in Qualitätsfarbe mit Stern bei Wunsch, "+2" für
  weitere; Tooltip zeigt alle wie der Pin), Knopf "Weg" 548-602 (54). Klick auf die Zeile = "Weg";
  Shift-Klick = auf der Weltkarte zeigen; Rechtsklick = W.Menu wie am Pin plus "Wieder einblenden",
  wenn der Ort ausgeblendet ist (ausgeblendete Orte stehen grau unten).
- **Leer:** "In dieser Zone liegt nichts aus deinen Zielen und Wünschen." bzw. ohne Daten "Für
  diesen Client gibt es keine Kartendaten." Ohne Ziele und Wünsche: "Noch keine Ziele oder Wünsche.
  Siehe Seite Ausrüstung."
- **Fuß** (y -390, y -408, grau): Bedienhinweis und Datenstand (`ns.MAP.built`), Hinweis auf
  englische Namen. Mit ausgeblendeten Orten zusätzlich Knopf "Ausgeblendete zeigen (3)" (170) rechts
  bei y -400, setzt `hidden` zurück.
- Die Seite hört auf `BIS_CHANGED`, `MAP_TARGET`, `SETTING`, `ZONE_CHANGED_NEW_AREA` (nur wenn
  "Hier" gewählt) und `ns.BisOnOwned`, nur solange sichtbar, Neubau höchstens einmal je Sekunde. Die
  Entfernung in der Zielzeile läuft im Takt des Pfeils mit (0,5 s, nur sichtbar).
- `ns.ShowMap(zone?)` öffnet die Seite.
- Keine neue Übersichtskarte (die Übersicht hat 6 Plätze). Die Übersichtskarte "gear" bekommt
  keine Änderung.

### Anschlüsse an die Seite "Ausrüstung" (Pages/Gear.lua)

- **Ziele, Detailbereich:** in jeder der drei Optionszeilen ein Karten-Knopf (16 x 16, Textur
  `Interface\Icons\INV_Misc_Map_01`, links vor der Quelle), nur wenn `ns.MapItemPlaces(id)` etwas
  liefert. Klick: Ziel setzen (nächste Quelle); Shift-Klick: auf der Weltkarte zeigen. Tooltip
  "Wegpunkt zur Quelle" mit dem Fundort.
- **Hier:** derselbe Knopf in der Spalte Boss (bei Eingängen nur außerhalb der Instanz sinnvoll; in
  der Instanz fehlt er).
- **Wunschliste:** derselbe Knopf vor der Quelle.
- **Menüs** (W.Menu der Optionszeilen, neu auch Rechtsklick auf Zeilen von Hier und Wunschliste):
  Einträge "Wegpunkt setzen" und "Auf der Karte zeigen" nach "Auf die Wunschliste", nur mit Ort.
- Keine neuen Spalten, keine Verschiebung bestehender Spalten (der Knopf sitzt in den 18 px vor dem
  Quellentext, der Text rückt um 18 px ein und wird gekürzt).

### Schnellmenü

Minimap-Schnellmenü: Eintrag "Karte" nach "Ausrüstung" (beide Clients, wenn das Panel verfügbar ist).

## Einstellungen

Neuer Abschnitt `ns.RegisterSettings{ key = "map", label = "Karte und Wegpunkt", order = 47,
available = function() return ns.MAP ~= nil end }`:

| Pfad | Typ | Standard | Ansicht | Text |
|---|---|---|---|---|
| map.pins | toggle | an | alle | "Orte auf der Weltkarte zeigen" (Tip: "Pins für Upgrades und Wünsche, mit Item-Symbol.") |
| map.pinsTargets | toggle | an | alle | "Pins für Upgrades aus Ziele" |
| map.pinsWishes | toggle | an | alle | "Pins für Wünsche" |
| map.pinsContinent | toggle | an | alle | "Pins auch auf der Kontinentkarte" |
| map.pinScale | slider 60-160, Schritt 10 | 100 | Experte | "Pin-Größe (%)" |
| map.arrow | choice auto/on/off | auto | alle | "Pfeil zum Ziel" ("Automatisch", "Immer", "Aus"; Tip: "Automatisch: nur wo der Client keinen eigenen Wegweiser hat (TBC).") |
| map.autoClear | toggle | an | alle | "Ziel beim Ankommen löschen" |
| map.tooltip | toggle | an | alle | "Fundort im Tooltip (mit Shift)" |
| map.resetHidden | button | - | alle | "Ausgeblendete Orte wieder zeigen" |
| map.resetArrow | button | - | Experte | "Pfeilposition zurücksetzen" |

## Befehle

| Befehl | Ansicht | Wirkung |
|---|---|---|
| `/amisia karte` (Alias `map`) | alle | Seite Karte |
| `/amisia karte <Item-Link>` | alle | Ziel zur nächsten Quelle des Items; ohne Ort der Grund im Chat |
| `/amisia karte aus` (Alias `clear`) | alle | Ziel löschen |
| `/amisia karte pins` | alle | Pins an/aus (`map.pins`), Rückmeldung "Amisia: Pins auf der Weltkarte an." |
| `/amisia karte pfeil` | alle | Pfeil an/aus (zwischen "auto" bzw. "an" und "aus") |

Item-Links werden wie in `/amisia wunsch` gelesen (ID aus `|Hitem:`), auch eine bloße Item-ID.

## Fehlerbehandlung

- Seite baut in `pcall` wie alle Seiten. Pins: `RefreshAllData` und Pin-Tooltip in `pcall`, Fehler
  an `geterrorhandler`; ein Fehler lässt die Weltkarte unberührt (keine halben Pins: erst
  `RemoveAllPinsByTemplate`, dann neu).
- Ohne `ns.MAP` (Daten fehlen, falscher Client): Panel und Abschnitt nicht verfügbar, Menüeinträge
  und Knöpfe fehlen, Befehl antwortet "Keine Kartendaten für diesen Client.".
- Fehlende APIs per Typprüfung: ohne Client-Wegpunkt -> Pin plus Pfeil; ohne `AddDataProvider` oder
  Mixins -> keine Pins (einmal im Debug-Chat nichts, still); ohne `GetPlayerFacing`/`SetRotation` ->
  Richtung in Worten; ohne `GetPlayerMapPosition` und `UnitPosition` -> keine Entfernung, Pfeil aus,
  Ziel bleibt auf der Karte.
- Unbekannte uiMapID (`C_Map.GetMapInfo` nil, z. B. falsche Zonen-ID in den Daten): der Punkt wird
  übersprungen und einmal je Sitzung gemerkt; die Seite zählt ihn bei "ohne Ort".
- `C_Map.SetUserWaypoint` gibt falsch zurück oder wirft (geschützte Karte): Rückfall Pin plus Pfeil,
  kein Fehler an den Spieler.
- Werte aus `GetBestMapForUnit`, `GetPlayerMapPosition`, `GetPlayerFacing` gehen durch `ns.Plain`;
  geheime Werte gelten als "unbekannt".
- Im Kampf: Pins und Pfeil laufen weiter (reine Anzeige); die Weltkarte wird nicht von Amisia
  geöffnet.

## Tests

Lua (`addon/tests`, Stub ergänzt: `C_Map` mit `GetBestMapForUnit`, `GetPlayerMapPosition`,
`GetMapInfo`, `GetWorldPosFromMapPos`, `GetMapRectOnMap` über `STUB.map`; Wegpunkt-APIs
`SetUserWaypoint`, `ClearUserWaypoint`, `GetUserWaypoint`, `CanSetUserWaypointOnMap`,
`GetUserWaypointHyperlink` und `C_SuperTrack` über `STUB.waypoint`, `UiMapPoint`, `CreateVector2D`,
`GetPlayerFacing` über `STUB.facing`; `WorldMapFrame` mit `AddDataProvider`, `AcquirePin` (legt
Frames mit dem Mixin an, ohne XML), `RemoveAllPinsByTemplate`, `GetMapID`, `SetMapID`;
`MapCanvasDataProviderMixin`, `MapCanvasPinMixin`; TBC-Client ohne Wegpunkt-APIs über
`--[[preload]]`):

- `test_map_data.lua`: `ns.MapKeyOf` für jede Quellenart (Q mit und ohne ID, V/P/R/W mit Name und
  mit NPC-ID-Feld, Trash -> `N:`, X/D über `Gear.PlaceOf` ohne "/H", F, C/A nil); Punkte parsen
  (mehrere, kaputte Teile übersprungen, Merken); `ns.MapItemPlaces` mit Filtern und Fraktion;
  `ns.MapNearest` (gleiche Zone, anderer Kontinent, ohne Position); Umzug (zweimal laden, kaputtes
  Ziel, `hidden` gesäubert); unbekannte uiMapID übersprungen.
- `test_map_waypoint.lua`: Forever setzt Wegpunkt und Wegweiser, `ours`; fremder Wegpunkt wird nur
  beim Setzen ersetzt; `USER_WAYPOINT_UPDATED` mit anderem Wegpunkt löscht nur das Amisia-Ziel;
  Löschen räumt nur den eigenen Wegpunkt; `CanSetUserWaypointOnMap` falsch -> Pfeil; TBC (preload
  ohne APIs) -> Pfeil sichtbar mit Entfernung, Drehung über `GetPlayerFacing`, ohne
  `GetPlayerFacing` Richtung in Worten ("Nordost"); Ankommen < 15 m mit und ohne `map.autoClear`;
  Ziel nach `/reload` (Datei neu geladen) wieder da; in einer Instanz kein Pfeil; Befehle `karte
  <Link>`, `karte aus`, `karte pins`, `karte pfeil`, Gründe im Chat; alle Texte Latin-1 (Prüfung über
  Byte-Werte wie in den bestehenden Seitentests).
- `test_map_pins.lua`: Datenquelle wird angemeldet, fehlt sie (preload ohne Mixin), keine Pins und
  kein Fehler; Pins nur für die gezeigte Zone; Kontinent mit Rechteck-Umrechnung und nur mit
  `map.pinsContinent`; gleiche Stelle wird ein Pin mit Zahl; Grenze 60; Ziele/Wünsche-Schalter;
  besessene Items fehlen; ausgeblendete Orte fehlen; Ziel-Pin; Tooltip-Zeilen; Klick setzt Ziel,
  Rechtsklick-Menü; Fehler im Aufbau geht an `geterrorhandler`.
- `test_map_page.lua`: Seite baut auf TBC und Forever; Picker mit "Hier" und Zonen mit Zahl; Liste,
  Sortierung nach Entfernung; Weg-Knopf, Shift-Klick, Menü; Zielzeile und "Ziel löschen"; leere
  Zustände; Karten-Knopf und Menüeinträge auf der Seite Ausrüstung (Ziele, Hier, Wunschliste) nur
  mit Ort; Tooltip-Zeile "Fundort" nur mit Shift und `map.tooltip`; Schnellmenü; Panel und Abschnitt
  fehlen ohne `ns.MAP`.
- `run.py`: `.xml`-Zeilen der TOC werden übersprungen (Test in `test_registry.lua` oder eigener
  kleiner Python-Test, dass `toc_files()` keine `.xml` liefert); `syntax.cjs` prüft nur `.lua`
  (unverändert).
- Bestehende Tests bleiben grün (insbesondere `test_bis_page.lua`, `test_bis_tooltip.lua`,
  `test_pages.lua`, `test_minimap.lua`, `test_settings_features.lua`).

Python (`tools/tests/test_build_map.py`, Fixtures als kleine Auszüge der Questie-Dateien und einer
Mini-`GearData.lua`/`BisDataTBC.lua`):

- Lesen der `[[return {...}]]`-Blöcke; areaID -> uiMapID inklusive Überschreibungen; Spawns -1, -1
  fallen weg; höchstens vier Punkte, weit auseinander; Rundung auf Hundertstel Prozent.
- Quest mit NPC-Starter, mit Objekt-Starter, mit Item-Starter (kein Ort); `G` mit Gebername.
- Händler nach Name mit Zonenvorzug, mehrdeutige Namen gemeldet; `U:`-Schlüssel bei NPC-ID-Feld.
- Eingänge über Instanz-ID und über Namen (mit "The", Groß/Klein), Questies Korrekturzeilen
  (`dungeons[a][4] = ...`) gewinnen, Karazhan mit zwei Eingängen.
- `QUARTERMASTERS`: jeder Name steht im (Fixture-)NPC-Bestand mit "Quartermaster" im Untertitel
  oder ist ausdrücklich als Ausnahme gelistet; Fraktion ohne Eintrag gemeldet.
- Ausgabe: Kopf, Lizenz- und Commit-Zeile, Wächter je Client, sortierte Schlüssel, nur gebrauchte
  Schlüssel; zweimal bauen gibt dieselbe Datei; Lua-Syntax über `lupa`.
- `test_build_gear.py` (ergänzt): NPC-ID als letztes Feld in `V`, `P`, `R`, `W`; `Gear.lua`-Felder
  davor unverändert.

Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review), mit Augenmerk auf
Taint an der Weltkarte und auf geschützte Aufrufe.

## Vorschlag für den Plan (6 Aufgaben)

1. **Kartendaten:** `tools/build_map.py` (Laden und Zwischenspeichern von QuestieDB, Auflösung je
   Quellenart, Eingänge, Rüstmeister, Ausgabe mit Wächter), erster Lauf auf dem N100,
   `MapData.lua`, `MapDataTBC.lua`, TOC-Zeilen; `build_gear.py` mit NPC-ID-Feld (laufen erst auf
   dem PC); `tools/README.md` mit Lizenz; `test_build_map.py`, `test_build_gear.py`. Lizenzlage von
   QuestieDB prüfen (offener Punkt) und im Kopf richtig vermerken.
2. **Kern, Ziel und Wegpunkt:** Map.lua (`ns.MapKeyOf`, Punkte, `ns.MapItemPlaces`, `ns.MapNearest`,
   Ziel, Forever-Wegpunkt mit `USER_WAYPOINT_UPDATED`, Ankommen, Umzug, Abschnitt "map", Befehl
   `karte`, `ns.MapTooltipLine`); Stub; `test_map_data.lua`, Teil von `test_map_waypoint.lua`.
3. **Pfeil:** `AmisiaArrow` mit Drehung und Rückfall in Worten, Takt, Menü, Position;
   `Media\Icons\arrow.tga` über den Skill make-icon (echte 32-bit-TGA, 64 x 64; braucht einen vollen
   Neustart des Spiels); Rest von `test_map_waypoint.lua`.
4. **Pins:** MapPins.lua, MapPin.xml, Datenquelle, Kontinent, Zusammenfassen, Ziel-Pin, Tooltip,
   Klick und Menü, Schalter; `run.py` überspringt `.xml`; `test_map_pins.lua`.
5. **Seite und Anschlüsse:** Pages/Map.lua, Karten-Knopf und Menüeinträge in Pages/Gear.lua,
   Tooltip-Zeile in Bis.lua, Schnellmenü; `test_map_page.lua`, `test_pages.lua`.
6. **Auslieferung:** Version 1.9.0 (TOC, `ns.VERSION`), alle Tests
   (`~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
   `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs`), unabhängige
   Prüfung, `tools/release_addon.sh`, ZIP gegen die TOC prüfen (auch `MapPin.xml` und `arrow.tga`
   drin).

## Auslieferung

Version 1.9.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh` (füllt den Release-Ordner, den Syncthing sendet). Wegen der neuen Textur
`arrow.tga` und der neuen XML-Datei reicht `/reload` beim ersten Mal nicht: **das Spiel einmal ganz
neu starten**, danach genügt `/reload`. Website, Export und Twin bleiben unverändert (kein Neubau
des Twins, `BUILD_ID` bleibt). Auf dem PC danach: `python tools/build_gear.py` (NPC-IDs und
Instanz-IDs), dann auf dem N100 `python tools/build_map.py`, committen, neu ausliefern.

## Ideen aus der Recherche

Übernommen:
- Klick auf eine Quelle zeigt den Ort; Wegpunkt mit Wegweiser, wo der Client ihn hat, sonst ein
  eigener Pfeil.
- Alle Marker auf einmal: Pins für alle Ziele und Wünsche einer Zone, einzeln ausblendbar.
- Händler- und Questgeber-Orte (meistgenannter Wunsch an Ausrüstungs-Addons).
- Dungeon-Eingänge auf der Karte, auch für die TBC-Raids.
- Wenige Schalter, jeder Teil einzeln abschaltbar.

Später:
- Eigener Pin auf der Minimap in TBC (braucht Zoom- und Innen/Außen-Tabellen je Client).
- Pins für die Abgabe einer Quest (Questende) und für Quest-Ketten (Vorquests).
- Dungeon-Questliste je Dungeon mit Geberorten außerhalb und innerhalb ("Dungeon-Quests").
- Route über mehrere Ziele (nächstes Ziel nach dem Ankommen).
- Eingänge aus `C_EncounterJournal.GetDungeonEntrancesForMap` als Abgleich der eigenen Daten.
- Pins auf der kleinen Zonenkarte (Shift-M) und auf instanzinternen Karten (Bossräume).
- Deutsche NPC-Namen (aus Sammler-Notizen, sobald genug gesehen sind).

## Nicht in Baustein 2

Eigene Minimap-Pins; Koordinaten innerhalb von Instanzen und Bosspositionen; Questende, Vorquests
und Questziele; Routen über mehrere Ziele; Pins für Dinge, die nicht in Ziele oder Wunschliste stehen
(etwa alle Händler einer Zone); Wegpunkte an andere Spieler senden (Baustein 7, Sync); Änderungen an
Export, Website und Twin; fremde Karten- oder Pin-Bibliotheken; Daten von Datenseiten.

## Offene Punkte

Nur im Spiel zu klären:

- Forever: ob `C_Map.SetUserWaypoint` plus `C_SuperTrack.SetSuperTrackedUserWaypoint(true)` den
  Wegpunkt auf Weltkarte, Minimap **und** als Wegweiser am Bildschirm zeigt, und ob der Client ihn
  beim Ankommen selbst löscht (`/amisia karte <Link>`, hinlaufen).
- Anniversary: ob es `C_Map.SetUserWaypoint` doch gibt (`/dump C_Map.SetUserWaypoint`); wenn ja,
  bleibt es trotzdem beim Pfeil, solange die TBC-Weltkarte den Wegpunkt nicht zeichnet.
- Anniversary: ob `GetPlayerFacing()` eine Zahl liefert und `texture:SetRotation` wirkt (Pfeil
  dreht sich mit), sonst Richtung in Worten.
- **Zonen-IDs der Outland-Karten auf Anniversary:** Questie (TBC-Daten) führt Shattrath als 1955,
  Höllenfeuerhalbinsel 1944 usw.; `build_bis.py` schreibt für G'eras 111. `/dump
  C_Map.GetBestMapForUnit("player")` in Shattrath. Ist es 1955, wird `SHATTRATH` in `build_bis.py`
  korrigiert (betrifft auch "Hier" für den Abzeichen-Händler); ist es 111, braucht `build_map.py`
  eine Umrechnungstabelle für Outland.
- Ob die Pins auf beiden Weltkarten an der richtigen Stelle sitzen (Stichproben: ein Händler in
  Orgrimmar/Sturmwind, ein Questgeber, der Karazhan-Eingang, ein Rüstmeister in Shattrath) und ob
  Forever die Koordinaten von Classic-NPCs unverändert hat.
- Ob die eigene Datenquelle auf Forever Taint an der Weltkarte erzeugt (`/console taintLog 1`, Karte
  im Kampf öffnen, Quest anklicken; `AddDataProvider` aus Addon-Code ist der vorgesehene Weg).
- Ob `UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")` auf beiden Clients existiert (sonst Standard-
  Ebene).
- **Lizenz von QuestieDB:** `GearData.lua` und `tools/README.md` vermerken GPL-3.0, aber weder
  `Questie/Questie` noch `Questie/QuestieDB` enthalten heute eine LICENSE-Datei (auch nicht in der
  Git-Geschichte von `Questie/Questie`), und GitHub nennt keine Lizenz. Vor der Auslieferung prüfen
  (Projektseite auf CurseForge, die eine Lizenz angeben muss, oder die Questie-Autoren fragen).
  Standard bis dahin: wie bei `GearData.lua` mit Nennung der Quelle und GPL-3.0 im Kopf.
- Entschieden: Karte auf beiden Clients; Forever nutzt den Client-Wegpunkt, TBC Pin plus eigenen
  Pfeil; kein eigener Minimap-Pin; Pins für Upgrades und Wünsche (beide Standard an), auch auf
  Kontinenten; Orte aus QuestieDB über GitHub, gebaut auf dem N100; stabile Schlüssel statt
  Quellennummern; NPC-IDs aus dem PC-Lauf verbessern nur die Treffer; eigene Seite "Karte" statt
  einer fünften Ansicht in "Ausrüstung" (dort ist im Kopf kein Platz mehr neben "Tabelle öffnen");
  englische NPC-Namen; Ankommen bei 15 Metern.
