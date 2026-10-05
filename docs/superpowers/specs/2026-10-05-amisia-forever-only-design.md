# Amisia 2.0: nur noch WoW Forever

Stand 2026-10-05. Kein neuer Baustein, sondern ein Umbau zwischen Baustein 2 (Karte, 1.9) und
Baustein 7 (Sync). Beginnt erst, wenn die Prüfung und die Korrekturen von 1.9 committet sind (die
Kartendateien sind gerade in Arbeit). Ändert das Addon `addon/Amisia`, seine Tests, die
Erzeugungsskripte in `tools/`, die Website `index.html`, die Datendateien in `data/`, den Twin und
die Doku (`CLAUDE.md`, `tools/README.md`). Der Supabase-Bestand bleibt, wie er ist (kein Schema-
Umbau, keine Datenänderung durch Amisia).

Wort-Hinweis: "TBC" heißt in diesem Entwurf TBC Anniversary (Client 2.5.6, TOC 20506), "Forever" WoW
Forever (Client 1.60.1, TOC 16001, Spieltyp `camelot`). "Archiv" heißt die schreibgeschützte
Ansicht der TBC-Daten auf der Website.

## Ziel

Der Nutzer hat am 2026-10-05 entschieden: Amisia zielt nur noch auf WoW Forever (Start 2026-11-04,
die Gilde zieht um). TBC Anniversary "ist nicht mehr wichtig", Classic Era, Hardcore, Season of
Discovery und Mists of Pandaria Classic fallen ganz weg. Zwei Clients haben bisher jede Funktion,
jeden Test und jede Prüfung verdoppelt (Baustein 2 hat Pin plus eigenen Pfeil nur für TBC gebaut,
Baustein 3 zwei Datensätze, zwei Chip-Sätze und Phasen).

2.0 bringt:

- **Addon nur für Forever:** ein TOC mit `## Interface: 16001`, keine TBC-Daten, keine TBC-Zweige,
  `ns.IsForever` entfällt. Alles, was Forever braucht, bleibt und läuft weiter wie in 1.9.
- **Tests laufen als Forever:** der Stub ist ab 2.0 der Forever-Client. Heute laufen 52 von 62
  Lua-Testdateien als TBC-Client (Stub-Standard `STUB.toc = 20506`); nach 2.0 laufen alle als
  Forever. Forever bekommt dadurch mehr Abdeckung, nicht weniger.
- **Website nur für Forever, TBC als Archiv:** der Spielwähler kennt nur Forever. Die Loot-Daten der
  Gilde aus TBC (heute 136 Vergaben, 9 Raidabende) bleiben gespeichert und für jeden lesbar, als
  Ansicht "Archive: TBC Anniversary". Era, Hardcore, SoD und MoP verschwinden mit ihren Datendateien.
- **Kein Datenverlust:** weder im Ledger (Supabase, Twin, Sicherungen) noch in den SavedVariables.

## Rahmen und Entscheidungen

- **Schrift und Sprache wie bisher:** UI- und Chat-Texte des Addons deutsch, nur Latin-1 (ä ö ü ß
  und "·", kein Gedankenstrich, keine Auslassungspunkte, keine Pfeile), Code-Kommentare englisch,
  Texte der Website englisch. Keine anderen Addons nennen, weder in Texten, Chat, Kommentaren noch
  Commits. Neue oder geänderte Texte unten sind wörtlich gemeint.
- **Version 2.0.0** (TOC `## Version`, `ns.VERSION` in Core.lua). Der Sprung auf 2 zeigt: ein Client
  weniger, gespeicherte Einstellungen nur für TBC fallen weg.
- **TOC:** `## Interface: 16001` allein. Die Zeilen `GearData.lua`, `GearWeights.lua`, `MapData.lua`
  **behalten** `[AllowLoadGameType camelot]`. Gründe: die Bedingung ist in Forever erprobt (1.8 und
  1.9 laden die Daten damit), sie kostet nichts, und ein Spieler, der auf einem anderen Client
  "Veraltete AddOns laden" anhakt, bekommt dann keine falschen Daten, sondern eine Ausrüstungs- und
  Kartenseite ohne Daten ("nicht verfügbar"). Die Zeilen `BisDataTBC.lua`, `BisWeightsTBC.lua`,
  `MapDataTBC.lua` und ihre Dateien entfallen. Eine TOC-weite Zeile `## AllowLoadGameType: camelot`
  gibt es in Blizzards eigenen Forever-TOCs, für fremde Addons ist sie nicht belegt; sie kommt
  **nicht** (Risiko: Addon lädt gar nicht), siehe "Später".
- **Lua-Wächter in den erzeugten Dateien entfallen.** `GearData.lua` hat heute keinen,
  `GearWeights.lua` bekommt seinen aus `build_gear.py` (Zeilen 185 und 927:
  `if not ns.IsForever() then return end`), `MapData.lua` aus `build_map.py` (Zeile 589f.). Mit
  `ns.IsForever` gehen sie; die TOC-Bedingung bleibt die einzige Sperre.
- **`ns.IsForever` wird gelöscht, nicht auf `true` gesetzt.** Jede Stelle, die es fragt, verliert
  den TBC-Zweig. Ebenso `Gear.Game()`: es gibt nur noch einen Datensatz; `Gear.PlannerAvailable()`
  wird zu `Gear.Available()` (der Aufruf in Minimap.lua und GearFrame.lua wird umgestellt, die
  Funktion entfällt). `Gear.Cap()` bleibt (liest `ns.GEAR.cap`, sonst 60).
- **Welche Rückfälle gehen, welche bleiben.** Geprüft in Gethe/wow-ui-source, Zweig `forever`
  (1.60.1), am 2026-10-05:

  | Stelle | Forever hat | Entscheidung |
  |---|---|---|
  | Tooltip: `TooltipDataProcessor.AddTooltipPostCall` sonst `OnTooltipSetItem` (Core.lua 84-89) | `TooltipDataProcessor` (`Blizzard_SharedXMLGame/Tooltip/TooltipDataRules.lua` meldet sich selbst für `Item` an) | `OnTooltipSetItem`-Rückfall entfällt; ohne Prozessor (Typprüfung) gibt es keine Tooltip-Zeilen, kein Fehler |
  | Lootfenster: `LootButton1..n`, `LOOTFRAME_NUMBUTTONS`, `hooksecurefunc("LootFrame_Update")` (SoftRes.lua, GuildWishes.lua) | nur `LootFrame.ScrollBox` mit Elementen `GetSlotIndex()` und `ScrollUtil.AddInitializedFrameCallback` (`Mainline/LootFrame.lua`); kein `LootButton`, kein `LootFrame_Update` | Schleife über `LootButton` und der `LootFrame_Update`-Hook entfallen; Marke immer am `btn.Item` des Elements |
  | Berufe: `C_SkillInfo` sonst `GetNumSkillLines`/`GetSkillLineInfo` (Bis.lua 243-268) | `C_SkillInfo.GetNumSkillLines/GetSkillLineInfo` (`Camelot/SkillsFrame.lua` nutzt nur diese); die Globalen stehen in keiner Deprecated-Datei, die Forever lädt | Globaler Zweig entfällt (der Entwurf von Baustein 3 nannte `Camelot/SkillsFrame.lua` mit Globalen; das stimmt für den heutigen Stand nicht) |
  | Bank: Behälter -1 und Bankfächer (Bis.lua 435-452) | `C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)` (`Camelot/BankFrame.lua`) | Nur noch der Forever-Weg; `BANK_CONTAINER`, `NUM_BANKBAGSLOTS` fallen weg |
  | Item-APIs: `C_Item.X or _G.X` (Awards.lua, AwardDialog.lua, Core.lua, Pages/Awards.lua, Scan.lua, Gear.lua, GearFrame.lua, MapPins.lua, Pages/Gear.lua, Pages/Map.lua) | `C_Item.GetItemInfo`, `GetItemInfoInstant`, `GetItemIconByID`, `GetItemStats` dokumentiert (`ItemDocumentation.lua`); die Globalen fehlen | Alle Stellen nehmen `C_Item` direkt bzw. den einen Shim in Core.lua; der `_G`-Teil entfällt |
  | Werte ohne `GetItemStats`: `Gear.TooltipStats` mit verstecktem Tooltip `AmisiaScanTip` (Gear.lua 198-247, 596) | `C_Item.GetItemStats` und `C_TooltipInfo.GetItemByID` (`TooltipInfoDocumentation.lua`) | `Gear.TooltipStats` und `AmisiaScanTip` entfallen, wenn kein anderer Aufrufer übrig ist (Aufgabe 2 prüft mit grep); die Zeilen für Klassen und Waffentempo kommen weiter aus `C_TooltipInfo` |
  | Chat: `C_ChatInfo.SendChatMessage` sonst `SendChatMessage` (Chat.lua 120) | `C_ChatInfo.SendChatMessage` | Globaler Rückfall entfällt |
  | Link in den Chat: `ChatFrameUtil.InsertLink` sonst `ChatEdit_InsertLink` (Pages/Gear.lua, Pages/Awards.lua, MapPins.lua); Hook auf `ChatEdit_InsertLink` (AwardDialog.lua 413-422) | `ChatFrameUtil.InsertLink` | Rückfall entfällt. Ob der Hook auf den Alias in Forever überhaupt greift, prüft Aufgabe 2 im Zweig `forever` (grep nach `ChatEdit_InsertLink`); ohne Definition dort geht auch der Hook |
  | `C_Container.X or _G.GetContainer*` (Collect.lua 98f., Bis.lua 386-388) | `C_Container` dokumentiert | `_G`-Teil entfällt |
  | `C_SpecializationInfo` sonst `GetTalentTabInfo` (Bis.lua) | beides (Talent-Tab nur als Kompatibilitätsfunktion) | bleibt wie es ist (Forever-Rückfall, nicht TBC) |
  | `C_GuildInfo.CanEditOfficerNote or _G.CanEditOfficerNote`, `C_GuildInfo.GuildRoster or _G.GuildRoster` | Namensraum vorhanden | `_G`-Teil entfällt, Typprüfung bleibt (Test `test_bench_noapi.lua` deckt "fehlt ganz") |
  | Karte: `Map.ClientWaypoints()` und der eigene Pfeil | Wegpunkt des Clients vorhanden | **bleibt.** Der Pfeil ist in Forever der Rückfall, wenn `C_Map.CanSetUserWaypointOnMap` falsch gibt oder `SetUserWaypoint` scheitert (Entwurf 1.9). Nur Texte und Kommentare, die "TBC" nennen, ändern sich |

  Regel für alles, was diese Tabelle nicht nennt: ein Zweig, der nur einem Client ohne die
  Forever-API diente, geht; eine Typprüfung, die Forever selbst vor einem fehlenden Teil schützt
  (geheime Werte, Kampfsperre, fehlende Gildenbank), bleibt.
- **Materialien der Gildenbank (`ns.MATS`) sind TBC-Gegenstände** (Mal der Illidari, Herz der
  Dunkelheit, sechs epische Rohedelsteine). Die Mechanik (Zählung beim Öffnen der Gildenbank,
  `B`-Zeile im Export, Loot der Materialien) bleibt, die Liste wird **leer**. Ohne Einträge zählt
  Amisia nichts, der Export schreibt keine `B`-Zeilen und die Gildenbank-Zeile auf der Seite Export
  sagt nichts. Welche Forever-Materialien die Gilde zählen will, ist ein offener Punkt; die Liste
  wird dann wieder gefüllt, ohne Codeänderung außer der Tabelle.
- **`ns.IGNORE`:** die TBC-Einträge (29434 Abzeichen der Gerechtigkeit, 22450 Leerenkristall, 22449
  und 22448 Prismatische Splitter) gehen, die Classic-Entzauberungsreste (20725, 14344, 14343)
  bleiben.
- **Spielname im Gildenwunsch-Kopf** (`#AMISIA-WL 1 <game>`): `GAME_NAMES` behält nur `forever`
  ("WoW Forever") und `tbc` ("TBC Anniversary", damit eine alte Liste verständlich abgewiesen wird);
  andere Schlüssel zeigen wie heute den gesäuberten Rohtext. Der eigene Spielname ist immer
  `forever`.
- **Namen:** `ns.FullName` verliert den Anniversary-Zweig (Realm abschneiden). Ein Bindestrich in
  Forever-Nachnamen bleibt dadurch auf jeden Fall erhalten.
- **Kommentare,** die "Anniversary" oder "TBC" als zweiten Client erklären, werden umgeschrieben
  oder gelöscht (Names.lua, SoftRes.lua 478, 578, GuildWishes.lua 268, MapPins.lua 13, 398, Map.lua
  2-4, 620, Bis.lua 159, 243, 286, 435, 619, Gear.lua 130-132, 367-368, 484, 527, 549, 600, 671).
  `Gear.lua` 130 ("Forever uses TBC-style ratings") bleibt sinngemäß, weil es die Herkunft der
  Wertungs-Kurve erklärt.
- **Website: Forever ist das einzige spielbare Spiel; TBC bleibt als Archiv.** Die Daten für das
  Archiv (`data/tbc.js`, `data/craft-tbc.js`, ihre Sprites, der TBC-Teil von `data/bossnames.js`)
  bleiben und sind ab 2.0 **nur für das Archiv** da (Kopfkommentar in den Skripten, Hinweis in
  `tools/README.md`, kein Neubau mehr).
- **Der Live-Ledger ist schon umgestellt.** Geprüft per lesender SQL-Abfrage am 2026-10-05:
  `ledgers.main` Version 23, `game = "forever"`, `shelfGame = "forever"`, `shelf.tbc` mit 136
  Vergaben und 9 Raidabenden, oben 0 Vergaben. `wishlist` und `mat_requests` sind leer,
  `ledger_history` hat 20 Stände. Der Twin (`data.json`) hat dagegen TBC noch oben
  (`{"game":"tbc", awards, raiders, ...}`), ebenso der eingebaute Startstand in `index.html`
  (`<script id="ledger-data">`) und jede ältere Sicherung.
- **Umzug auf der Website automatisch und verlustfrei statt per Knopf.** Ein Ledger, dessen oberes
  Spiel nicht Forever ist, wird beim Laden **im Speicher** mit dem bestehenden Regal-Mechanismus auf
  Forever gestellt (`fitShelf`): die TBC-Daten wandern nach `shelf.tbc`, oben steht Forever (leer
  oder vom Regal zurück). Gespeichert wird das erst mit dem nächsten Speichern eines Editors (Autosave
  nach jeder Änderung, oder der neue Knopf "Save the move to Forever" in einer Hinweiszeile für
  Editoren). Gelöscht wird dabei nichts, und das Archiv zeigt die verschobenen Daten sofort, auch
  Zuschauern. Ein eigener Bestätigungsdialog entfällt, weil nichts unsichtbar wird; der Live-Ledger
  braucht ohnehin keinen Umzug mehr.
- **Archiv für alle.** Die Archivansicht ist für Zuschauer, Mitglieder und Editoren gleich und immer
  schreibgeschützt, auch für den Besitzer. Sie liest `shelf.tbc`, oder, solange ein Ledger noch nicht
  umgezogen ist, die Daten oben (siehe "Website").
- **Daten anderer gelöschter Spiele** (falls eine Sicherung `shelf.classic`, `shelf.mop` usw. hat)
  bleiben unverändert im JSON, werden aber nirgends gezeigt. Ein Ledger, dessen oberes Spiel eines
  davon ist, wird wie TBC auf Forever gestellt; seine Daten liegen dann in `shelf.<spiel>`.
- **Supabase bleibt unverändert.** Kein Schema, keine Migration, kein Edge-Function-Umbau. Die
  Tabelle `wishlist` behält ihre Spalte `game`; die Seite liest und schreibt nur noch `forever`.

## Dateien

### Addon (`addon/Amisia`)

```
Amisia.toc            ## Interface: 16001; Zeilen BisDataTBC.lua, BisWeightsTBC.lua, MapDataTBC.lua
                      weg; GearData/GearWeights/MapData behalten [AllowLoadGameType camelot];
                      ## Notes ohne "in WoW Forever" (gilt jetzt immer); ## Version 2.0.0
BisDataTBC.lua        GELÖSCHT
BisWeightsTBC.lua     GELÖSCHT
MapDataTBC.lua        GELÖSCHT
GearWeights.lua       erzeugt ohne IsForever-Wächter (Neubau durch build_gear.py erst auf dem PC;
                      bis dahin wird nur die Wächterzeile von Hand entfernt, siehe Aufgabe 1)
MapData.lua           erzeugt ohne Wächter (build_map.py läuft auf dem N100)
Names.lua             ns.IsForever gelöscht; FullName ohne Realm-Zweig; Kopfkommentar
Core.lua              ns.VERSION "2.0.0"; Tooltip nur über TooltipDataProcessor; ns.MATS = {} und
                      ns.MAT_ORDER = {}, ns.GEMS = {} (Mechanik bleibt); IGNORE ohne TBC-Ids;
                      GetItemInfo-Shim nur C_Item; Umzug der Einstellungen (unten)
Gear.lua              Gear.Game, Gear.PlannerAvailable, DUAL_WIELD_SPEC, der tbc-Zweig in den
                      Wertungen (Treffer, Krit, Tempo getrennt), die Kurve über 60 in ratingPerPoint
                      (Stufe auf 60 begrenzt), Gear.PhaseOf und opts.phase im Filter weg;
                      Gear.FillRow (leere Zeilen) und die Tabellenform von Gear.WearProf
                      ({Fertigkeit, Rang}) weg, sobald der neue Test belegt, dass GearData keine
                      leere Zeile hat (Aufgabe 2); Gear.TooltipStats nach Prüfung weg; Kommentare
Bis.lua               Phase aus BisOpts und dem Merk-Schlüssel; Einstellung bis.phase und PHASES
                      weg; Berufe nur C_SkillInfo; Bank nur C_Bank; Trefferwertungs-Hinweis in
                      BisExplain weg; Quellen-Standard ohne H und F; Kommentare
Pages/Gear.lua        CHIPS nur Forever (ohne Schlüsselwahl); Phasen-Picker und Text "Phase" weg;
                      "Tabelle öffnen" hängt an Gear.Available(); Link-Einfügen nur ChatFrameUtil
GearFrame.lua         ToggleGearFrame ohne TBC-Zweig und ohne die Meldung "Die Ausrüstungstabelle
                      gibt es nur in WoW Forever"; Abschnitt "gear" verfügbar mit Gear.Available()
Minimap.lua           Gear.Available() statt PlannerAvailable
SoftRes.lua           MarkLootButtons nur über LootFrame.ScrollBox; LootFrame_Update-Hook weg;
                      Kommentare
GuildWishes.lua       clientGame weg (immer "forever"); GAME_NAMES nur forever und tbc; markLoot nur
                      ScrollBox; Kommentare
LootAnnounce.lua      unverändert bis auf den Kommentar zur Materialliste (ns.MATS leer)
Map.lua               Kommentare und Tip-Text von map.arrow (unten); sonst wie 1.9
MapPins.lua           Kommentare; Item-Info und Link-Einfügen nur über C_Item/ChatFrameUtil
Pages/Map.lua         Item-Info nur über C_Item
Chat.lua              nur C_ChatInfo.SendChatMessage
Collect.lua           nur C_Container
Awards.lua, AwardDialog.lua, Pages/Awards.lua, Scan.lua, Registry.lua, Bench.lua
                      _G-Rückfälle der Tabelle oben weg
```

Unverändert: Rolls.lua, RollFrame.lua, RaidLog.lua, RaidText.lua, Widgets.lua, MainFrame.lua,
alle übrigen Seiten, MapPin.xml, Media.

Neuer Tip-Text `map.arrow`: "Automatisch: nur wenn der Client den Wegpunkt nicht setzen kann."
(ersetzt "... hat (TBC).").

### Werkzeuge (`tools`)

```
build_bis.py              GELÖSCHT (baut nur BisDataTBC/BisWeightsTBC)
bis_atlas_tbc.json        GELÖSCHT (Zwischenspeicher von build_bis.py)
bis_tbc_items.json        GELÖSCHT, falls vorhanden; cache/atlasloot-tbc/ (nicht in git) darf weg
tests/test_build_bis.py   GELÖSCHT
build_map.py              nur Forever: --game entfällt, EXPANSION/QUESTIE-Pfade/GEAR/OUT ohne tbc,
                          QUARTERMASTERS (nur TBC-Fraktionen) weg, Wächterzeile weg, Docstring
map_questie.json          neu erzeugt ohne TBC-Teil (build_map.py --refresh-questie entfällt dafür
                          nicht nötig: ein Lauf schreibt nur noch, was Forever braucht)
build_gear.py             Wächterzeilen (185, 927) weg; QUESTIE_TOC unter _classic_era_ BLEIBT
                          (dort liegt die Forever-Datenbank der Questdaten); läuft weiter auf dem PC
build_scan.py             unverändert (liest schon nur Forever-SavedVariables aus _classic_beta_)
build_bossnames.py        GAMES = ('tbc',) und nur das Classic-Gebietsmodul (MoP-Modul weg);
                          Docstring: "only the TBC archive"; läuft nur noch, wenn das Archiv neue
                          Namen bräuchte (praktisch nie)
fill_quality.py           Spielauswahl nur tbc (Archiv); Forever bekommt Qualität aus dem Scan
sync_addon.ps1            $Flavors = @('_classic_beta_'); Beschreibung ohne TBC. Auf dem N100 ohne
                          Belang (Syncthing), bleibt für den PC-Fall
release_addon.sh          unverändert; zusätzlich baut Aufgabe 6 addon/Amisia.zip neu (Download der
                          Website), wie bei 1.8
README.md                 Abschnitt build_bis.py weg; build_map.py nur Forever; Lizenzzeilen ohne
                          BisDataTBC/MapDataTBC; build_bossnames/fill_quality "nur Archiv"
build_twin.py             siehe "Twin"
twin_stamp.py             unverändert (liest data/ neu; gelöschte Dateien verschwinden beim nächsten
                          --published)
```

### Website und Daten

```
index.html                GAMES, Archiv, Umzug, Texte (siehe "Website"); BUILD_ID neu
data/classic.js           GELÖSCHT (auch Hardcore nutzte ihn)  + data/classic.8269de17.jpg
data/sod.js               GELÖSCHT  + data/sod.bf69227b.jpg
data/mop.js               GELÖSCHT  + data/mop.7b411ce8.jpg
data/craft-classic.js     GELÖSCHT  + data/craft-classic.21b3ce46.jpg
data/craft-sod.js         GELÖSCHT  + data/craft-sod.9acb97fe.jpg
data/craft-mop.js         GELÖSCHT  + data/craft-mop.e0f4de57.jpg
data/bossnames.js         nur noch window.__BOSSNAMES["tbc"] (gefiltert, Inhalt byte-gleich)
data/tbc.js, data/tbc.616eee65.jpg, data/craft-tbc.js, data/craft-tbc.c4f6e55d.jpg
                          BLEIBEN, nur für das Archiv
data/forever.js, data/forever.c514e4bd.jpg   bleiben
```

`data/bossnames.js` wird auf dem N100 nicht neu gebaut (das Skript liest die WoW-Installation),
sondern einmal mit einem kleinen Python-Schritt gefiltert: die Zeile mit `["tbc"]` bleibt,
`classic`, `sod`, `mop` gehen. Ein Test vergleicht die TBC-Tabelle vorher und nachher.

### Doku

```
CLAUDE.md                 Zeile 12: "the Amisia folder in _classic_beta_ is a junction on it"
                          (ohne _anniversary_); Hinweis "Forever only since 2.0"; build_bis.py fällt
                          aus der PC-Liste (stand dort nicht), build_bossnames.py "archive only"
tools/README.md           siehe oben
```

Die Erinnerungen des Nutzers (`~/.claude/projects/-home-alex-addons-Amisia/memory/`) liegen nicht
im Repository. Nach der Auslieferung aktualisiert die Hauptsitzung dort `amisia-addon.md`,
`amisia-addon-1-2.md`, `amisia-gear-planner.md`, `amisia-loot-ledger-project.md` und
`amisia-1-4-progress.md` (Pfade `_anniversary_`, "beide Clients", TBC-Datensatz) und hängt an
`forever-only.md` den Stand von 2.0 an. Nicht Teil der Aufgaben unten.

## Datenmodell und Umzug

### SavedVariables des Addons

SavedVariables liegen je Installation (`WTF` von `_anniversary_` bzw. `_classic_beta_`). Die
TBC-Raids, Vergaben und Wünsche stehen in der `Amisia.lua` der Anniversary-Installation und werden
von 2.0 nie angefasst: die Datei bleibt auf dem PC liegen, auch wenn die Verknüpfung weg ist. Ihre
Raids sind über den Export längst im Ledger (Archiv). Die Forever-Datei kann TBC-Reste nur aus
Einstellungen oder Wunschlisten-Texten haben.

Beim `ADDON_LOADED` (in `ns.BisMigrate`, das schon jetzt zweimal laufen darf):

| Schlüssel | Herkunft | Behandlung |
|---|---|---|
| `AmisiaDB.settings.bis.phase` | Einstellung "Inhalte bis Phase" (nur TBC sichtbar, aber per `ns.Set` überall setzbar) | entfernt |
| `AmisiaDB.settings.bis.sources.H`, `.F` | Chips "Heroisch" und "Ruf" (nur TBC) | entfernt (Forever-Daten haben weder heroische Dungeons noch Ruf-Quellen) |
| `AmisiaDB.bis.guild` mit `game ~= "forever"` | Gildenwünsche aus einer Liste für ein anderes Spiel (eigentlich unmöglich, der Parser lehnt sie ab) | entfernt |
| `AmisiaDB.bis.chars[*].ex.place` mit `I:<TBC-Instanz>` | Ausschlüsse von TBC-Orten | bleiben (harmlos, nie getroffen; Löschen bräuchte eine Liste der TBC-Instanzen) |
| `AmisiaDB.map.*`, `settings.map.*` | 1.9 | unverändert; `map.arrow` = "auto" heißt jetzt "nur wenn der Wegpunkt scheitert" |
| `AmisiaDB.bank` | Zählung der TBC-Materialien | bleibt; mit leerer Liste kommt keine neue dazu, die alte wird nicht mehr exportiert (`ns.Bank()` liefert nur Materialien der Liste) |

Zweimal laden ändert nichts. Raids, Vergaben, Rolls, Soft-Reserves, Bank, Scan, Wünsche, Karte
bleiben unberührt.

### Ledger auf der Website

Heute (`index.html` 1049-1067): die Daten des Spiels in Gebrauch stehen oben im Ledger, die der
anderen Spiele in `state.shelf[spiel]`, `state.shelfGame` nennt das Spiel der oberen Daten (fehlt es,
ist es `tbc`). `fitShelf(state)` tauscht beim Rendern um, wenn `state.game !== shelfGame`.
`PER_GAME` listet die Schlüssel je Spiel, Raider und Gildeneinstellungen sind gemeinsam.

Neu:

```js
const PLAY = 'forever';                 // the only game the ledger is kept for
const ARCHIVE = {tbc: {...}};           // games kept read-only: name, file, craft, classes, blurb
function fitShelf(s){                   // unchanged swap, but the wanted game is PLAY unless archived
  const want = archiveOn ? 'tbc' : PLAY, have = s.shelfGame || 'tbc';   // missing shelfGame still means tbc
  if (s.game !== want) s.game = want;
  ...                                   // the existing move: top -> shelf[have], shelf[want] -> top
}
```

- **`s.shelfGame || 'tbc'` bleibt so.** Es ist die alte Bedeutung "Ledger von vor dem Regal, alles
  TBC" und darf nicht auf `forever` umgestellt werden. Alle anderen Stellen, die heute
  `state.game || 'tbc'` oder `GAME.tbc` als Rückfall nehmen (Zeilen 904, 960, 1268, 1407, 2479, 3607,
  3618, 3625 und die Twin-Stelle), nehmen `PLAY`.
- **Ergebnis je Ausgangslage** (Test `site_archive.cjs`):

  | Vorher | Nachher (im Speicher) | Archiv liest |
  |---|---|---|
  | Live heute: `game forever`, `shelfGame forever`, `shelf.tbc` | unverändert | `shelf.tbc` |
  | Twin, Startstand, alte Sicherung: `game tbc` oder ohne `game`, kein `shelfGame` | `game forever`, `shelfGame forever`, TBC-Daten in `shelf.tbc`, oben leer | `shelf.tbc` |
  | Sicherung mit `game mop` oben und `shelf.tbc` | MoP-Daten in `shelf.mop`, oben Forever, `shelf.tbc` unverändert | `shelf.tbc` |
  | Ledger ganz ohne TBC-Daten | oben Forever | nichts; der Archiv-Knopf fehlt |

- **Gespeichert** wird der Umzug wie jede Änderung: der Speicherweg (`publish`, Autosave,
  Twin-`art.publish`) sendet das ganze `state`. Damit ein Editor ihn bewusst sichern kann, ohne etwas
  anderes zu ändern, zeigt die Seite Editoren eine Hinweiszeile, solange der geladene Stand oben nicht
  Forever war (`movedOnLoad`): "This ledger still had TBC Anniversary on top. Its loot and raid
  nights are now in the TBC archive. [Save the move to Forever]". Der Knopf ruft `markDirty()`. Für
  Zuschauer keine Zeile.
- **Raider entfernen** (`forgetRaider` über `allBuckets()`) darf das Archiv nicht ausdünnen.
  `allBuckets()` gibt ab 2.0 nur das obere Bucket und die Regale **außer** `shelf.tbc` zurück. Hat
  der entfernte Raider im Archiv Vergaben, Abende oder Handwerk, wird sein Raider-Objekt nach
  `shelf.tbc.retired` (Liste, ohne Doppelte nach `id`) kopiert, bevor er aus `state.raiders` geht.
  Die Archivansicht kennt `state.raiders` plus `shelf.tbc.retired`. `retired` kommt zu `PER_GAME`.
  Der Bestätigungstext sagt dann: "Remove Anna from the roster? Their loot in the TBC archive stays."
  (statt "... in every game version").
- **Sicherung zurückspielen** (`#importBtn`): baut `state` wie heute, `game` aus der Sicherung
  (Rückfall `tbc`, weil eine Sicherung ohne Feld TBC war), `shelfGame` wie heute; der folgende
  `fitShelf` zieht auf Forever um. Die Rückfrage bleibt.
- **Startstand in `index.html`** (TBC-Beispieldaten mit `"game":"tbc"`) bleibt unverändert; er wird
  beim Booten wie jede alte Sicherung umgezogen und vom Serverstand ersetzt.

## Website (index.html)

Texte englisch. Nach jeder Änderung `BUILD_ID` neu (Datendateien ändern sich).

### Spiele

- `GAMES` hat nur noch Forever (Eintrag wie heute, mit `rulesets`). `ARCHIVE.tbc` übernimmt den
  heutigen TBC-Eintrag (`file: 'data/tbc.js'`, `craft: 'tbc'`, `classes: CLASSIC_CLASSES`, `blurb:
  'Karazhan to Sunwell Plateau'`, `archive: true`). `GAME` wird aus beiden gebaut, damit Namen,
  Wowhead-Links und `loadGame('tbc')` im Archiv weiter gehen.
- `CLASSIC_CLASSES` bleibt (TBC-Archiv), `MOP_CLASSES` bleibt als Klassenliste von Forever (heute so
  gesetzt).
- `PHASES` behält `tbc` (Phasen-Filter im Archiv). `PROF_LIST` nur `tbc` (Archiv); Forever fällt wie
  heute auf `BASE_PROFS`. `WOWHEAD_DB = {tbc: 'tbc', forever: 'classic'}`, `WOWHEAD_ENV = {tbc: 5}`.
  `MATS` behält `tbc` (Archiv-Reiter Mats). `gameKey` startet als `'forever'`.
- **Einstellungen, Spielwähler:** `#gGame` listet nur "World of Warcraft Forever" und ist
  deaktiviert (eine Wahl gibt es nicht mehr); der Wechsel-Dialog in `#saveSettings` entfällt,
  `state.game` bleibt `forever`. Das Regelwerk-Feld (PvE, PvP, Hardcore) bleibt.
- **Kopf:** Standardtext der Zeile `#eyebrow` "World of Warcraft Forever" (wird wie heute aus
  `gm.name + ' · ' + gm.blurb` gesetzt).

### Archiv "TBC Anniversary"

- **Einstieg:** im Kopf rechts neben der Gildenzeile ein kleiner Knopf "TBC archive" (Klasse wie
  `.btn sm ghost`), nur wenn das Archiv Daten hat (Vergaben, Abende oder Handwerker). Sichtbar für
  alle, auch ohne Anmeldung. Direktlink über `#archive` in der Adresse (beim Laden geprüft).
- **Im Archiv:** Kopfzeile "Archive · TBC Anniversary · Karazhan to Sunwell Plateau", darunter
  eine Hinweiszeile "You are looking at the TBC Anniversary archive. It is read-only. [Back to
  Forever]". Der Knopf im Kopf heißt dann "Back to Forever".
- **Technik:** `enterArchive()` merkt `liveState = state` und setzt `state = archiveView(liveState)`:
  eine tiefe Kopie (`structuredClone`) aus den gemeinsamen Schlüsseln (`guild`, `realm`, `faction`,
  `benchMode`, `raiders` plus `shelf.tbc.retired`) und dem TBC-Bucket (`shelf.tbc`, oder oben, wenn
  `shelfGame` tbc ist und kein Umzug lief), mit `game: 'tbc'`, `shelfGame: 'tbc'`, `shelf: {}`.
  `archiveOn = true`, `loadGame('tbc')`. `leaveArchive()` setzt `state = liveState`, `archiveOn =
  false`, `loadGame(PLAY)`.
- **Schreibschutz:** im Archiv gilt `readOnly = true` für jeden (`refreshRole` setzt `readOnly =
  archiveOn || !isEditor`); `markDirty()` tut nichts; `publish()` und der Autosave brechen ab;
  `#discardBtn` ist versteckt. Den Archiv-Knopf gibt es nur ohne ungespeicherte Änderungen
  (`dirty` oder `saving`: deaktiviert mit Tip "Save or discard your changes first.").
- **Neue Serverstände** (Realtime-Update Zeile 1407, `loadFromServer`): schreiben im Archiv nach
  `liveState` und bauen die Archivansicht neu. Dafür eine Funktion `takeState(next)` für alle drei
  Stellen (Realtime, `loadFromServer`, Twin-`data.json`).
- **Reiter im Archiv:** Armory, Loot Log, Nights, Attendance, Slot Coverage, Crafting (ohne "I can
  craft this" und ohne Mitglieder-Filter), Mats (nur "looted" und die alte Bankzählung, keine
  Anfragen), Roster (Liste ohne Formulare). Ausgeblendet: Wishlist, Import, Settings. Der Warcraft-
  Logs-Teil liegt im Import und fehlt damit auch.
- **Mitglieder-Daten** (Supabase `members`: Ränge, Berufe, Handwerk) gelten für den Kader und
  werden im Archiv nur angezeigt (Rang-Schild), nicht geändert.

### Forever-Ansicht

- **Mats:** ohne Forever-Materialien die bestehende Leer-Box mit neuem Text: "No tracked materials
  for World of Warcraft Forever yet. The TBC counts are in the TBC archive." (ersetzt "Materials are
  tracked for TBC Anniversary so far.").
- **Import, Anleitung des Addons** (Zeilen 809-814): "Unpack it into the `Interface\AddOns` folder of
  your WoW Forever install." statt `_anniversary_\Interface\AddOns`; die Aufzählung der
  aufgezeichneten Dinge ohne "who looted Mark of the Illidari, Heart of Darkness or one of the six
  epic raid gems" (stattdessen "who looted a tracked material"); der Bank-Schritt bleibt, mit dem
  Zusatz "(only when materials are tracked)".
- **Import, Absatz zu anderen Exporten:** "Disenchanted items and drops that are not from one of the
  nine Burning Crusade raids are ignored." wird zu "Disenchanted items and items that are not in the
  Forever loot tables are ignored." (Verhalten unverändert: der Abgleich läuft über die geladenen
  Tabellen).
- **Wishlist:** liest und schreibt nur `game = 'forever'` (heute `gameKey`, das jetzt immer Forever
  ist); keine Änderung an der Tabelle.
- **Bossnamen:** `bossHere` liest `__BOSSNAMES[gameKey]`; für Forever gibt es keinen Eintrag (die
  Forever-Tabellen kommen schon mit den Namen des Clients), im Archiv der TBC-Eintrag.

## Twin

- `tools/build_twin.py` schneidet wie heute die Supabase-Teile heraus. Neu: die Archiv-Teile bleiben
  drin; die `assert`-Liste der geschnittenen Funktionen wird um nichts Neues ergänzt, aber die
  Twin-Stelle Zeile 171 (`data.json` nachladen) nimmt `takeState` statt eigener Zuweisung, und der
  Mats-Leertext (Zeile 212) bekommt den neuen Wortlaut. Der Twin hat ohnehin keine Wishlist.
- Der Twin trägt TBC noch oben. Er wird beim ersten Öffnen im Speicher umgezogen und zeigt Forever
  leer plus Archiv; gespeichert wird das, sobald der Besitzer im Twin etwas ändert oder "Save the
  move to Forever" drückt. Kein Eingriff in `data.json` beim Veröffentlichen.
- **Veröffentlichen** (wo das Artifact-Werkzeug verfügbar ist): `python tools/build_twin.py <out>
  <data.json des Twins>`, dann Artifact mit der Seite und den Dateien, die gelöschten Datendateien als
  `null` (`data/classic.js`, `data/sod.js`, `data/mop.js`, `data/craft-classic.js`,
  `data/craft-sod.js`, `data/craft-mop.js` und ihre sechs `.jpg`), danach `python
  tools/twin_stamp.py --published`. Vorher `data.json` des Twins lesen (Artifact `read`) und lokal
  sichern (siehe Risiken).

## Tests

### Grundsatz: der Stub ist Forever

`addon/tests/wow_stub.lua` wird der Forever-Client:

- `STUB.toc = 16001`, `GetBuildInfo` meldet "1.60.1".
- Keine globalen `GetItemInfo`, `GetItemInfoInstant`; `C_Item` bekommt die Funktionen direkt (heute
  verweist es auf die Globalen).
- `C_SkillInfo` mit `GetNumSkillLines`/`GetSkillLineInfo` (Tabelle je Zeile: `skillLineName`,
  `skillID`, `skillLineRank`, `isHeader`, wie `SkillInfoDocumentation.lua`) über `STUB.skills`;
  die Globalen gehen.
- `C_Bank.FetchPurchasedBankTabIDs` und `Enum.BankType.Character` über `STUB.bankTabs`;
  `BANK_CONTAINER` und `NUM_BANKBAGSLOTS` gehen.
- `LootFrame.ScrollBox` (aus der Vorlade-Zeile von `test_review18_ui.lua`) und `ScrollUtil` als
  Standard; keine `LootButton`-Frames.
- `TooltipDataProcessor` und `TooltipUtil.GetDisplayedItem` als Standard (heute nur in Vorlade-
  Zeilen von `test_bis_tooltip.lua`, `test_softres_check.lua`).
- `C_ChatInfo.SendChatMessage`, `ChatFrameUtil.InsertLink` als Standard; `SendChatMessage` und
  `ChatEdit_InsertLink` gehen.
- Die Wegpunkt-APIs von `C_Map` und `C_SuperTrack` bleiben Standard (wie heute).

Vorlade-Zeilen, die nur `STUB.toc = 16001` setzen oder Globale wegnehmen, die der Stub nicht mehr
hat, werden gelöscht. `addon/tests/run.py` bleibt (lädt die TOC-Dateien ohne Bedingung).

### Bestandsaufnahme vor dem Umbau

Aufgabe 1 schreibt vor jeder Änderung je Testdatei die Zahl der `assert`- und `check`-Aufrufe in eine
Liste (nur in der Aufgabe, nicht ins Repository) und ordnet am Ende jede weggefallene Prüfung einer
Zeile der Tabelle unten zu. Was nicht "nur TBC" ist, muss in einer Forever-Datei wieder vorkommen.

### Lua-Tests je Datei

| Datei | Heute | 2.0 |
|---|---|---|
| `test_bis_data.lua` | TBC-Datensatz auf TBC (Phasen 1-5, Ruf, heroisch) | GELÖSCHT; Forever-Gegenstück `test_bis_data_forever.lua` bleibt und bekommt: jede `I`-Zeile von `GearData.lua` hat eine Ausrüstungsstelle (belegt das Entfernen von `FillRow`), kein `game`-Feld nötig |
| `test_bis_page.lua` | Seite Ausrüstung auf TBC (504 Zeilen: Kopf, Ansichten Ziele/Hier/Wunsch/Gilde, Menüs, Erklärung, Phase, TBC-Chips) | wird Forever: Mini-Datensatz in Forever-Form (`cap = 60`, Quellen Q/D/X/V/C/W/A/P), Phasen- und TBC-Chip-Prüfungen gehen, alles andere bleibt. Zahlen der Wertungen werden für Stufe 60 neu gerechnet |
| `test_bis_page_forever.lua` | Forever-Seite | bleibt, Vorlade-Zeile weg; Doppelungen mit der umgestellten `test_bis_page.lua` dürfen bleiben |
| `test_bis_score.lua` | beide Clients | TBC-Kurve über 60, getrennte TBC-Wertungen, `FillRow`, Phasen und die "TBC-Welt" (Ruf, heroisch, Abzeichen, Token) gehen; die Filterprüfungen (Quellenart, Fraktion, Klasse, Ausschlüsse, Rangfolge) laufen auf einer Forever-Welt (Raid X, Dungeon D, Quest Q, Händler V, PvP P, Beruf C, AH A) |
| `test_bis_targets.lua` | TBC-Daten, Phasen, Bank -1, Umschalten der TOC (226, 235) | Forever-Daten; Phase und TOC-Umschalten weg; Bank über `C_Bank`-Fächer; Hinweis "Trefferwertung zählt ohne Obergrenze." weg; Einstellung `bis.phase` nicht mehr vorhanden (Prüfung umgedreht) |
| `test_bis_wish.lua`, `test_bis_tooltip.lua` | Mini-Datensatz `game = "tbc", cap = 70` | Forever-Form, Stufe 60; Tooltip-Prozessor aus dem Stub; neu in `test_bis_tooltip.lua`: ohne `TooltipDataProcessor` (Vorlade-Zeile nimmt ihn weg) keine Zeile und kein Fehler |
| `test_review18.lua` | Prüfungen 1-3 nur TBC (leere Zeile füllen, Zaubertempo, TBC-Regeln unter 61) | diese drei gehen, der Rest (deutsche Berufsnamen u. a.) bleibt |
| `test_review18_ui.lua` | Anniversary-Lootknopf und Forever-Scrollbox | Lootknopf-Prüfung geht, Scrollbox bleibt (Vorlade-Zeile wird zum Stub-Standard) |
| `test_guild_wishes.lua` | Liste für `tbc` ist die eigene, `forever` die fremde; Lootknöpfe | umgedreht: eigene Liste `forever`; fremde `tbc` ergibt "Diese Wunschliste ist für TBC Anniversary, du bist in WoW Forever."; Markierung über die Scrollbox-Elemente |
| `test_softres.lua` | SR-Marke an `LootButton1/2` | SR-Marke an Scrollbox-Elementen (`btn.Item`), auch nach dem Scrollen (Rückruf) |
| `test_names.lua` | Anniversary schneidet den Realm ab, Forever Vor- und Nachname | Anniversary-Teil geht; neu: "Anna Berg-Tal" bleibt ganz, "Anna" mit Nachname aus `UnitName` |
| `test_map_data.lua` | `MapDataTBC.lua` auf TBC, Wächter beider Dateien, TBC-Schlüssel (F:, G'eras) | Forever-Daten (`MapData.lua`, Spieltyp über die TOC-Zeile), keine Wächterprüfung mehr; Schlüssel-Tests ohne `F:` (Ruf gibt es in Forever-Daten nicht), `ns.MapKeyOf` für F liefert nil; Rest bleibt |
| `test_map_page.lua` | Seite Karte auf TBC | wird Forever (Mini-Daten in Forever-Form, Zonen 1411/1429); Zielzeile mit Client-Wegpunkt; Doppelungen mit `test_map_page_forever.lua` dürfen bleiben |
| `test_map_pins.lua` | Pins auf TBC (ohne Wegpunkt-APIs) | Pins auf Forever; Ziel-Pin, wenn der Wegpunkt scheitert (`CanSetUserWaypointOnMap` falsch) |
| `test_map_arrow.lua` | Pfeil auf TBC (ohne Wegpunkt-APIs) | bleibt als "Client ohne Wegpunkt-APIs" (Vorlade-Zeile bleibt, Typprüfung in `Map.ClientWaypoints`), Kopfkommentar ohne TBC; neu: Pfeil erscheint in Forever, wenn `CanSetUserWaypointOnMap` falsch gibt und `map.arrow` "auto" ist |
| `test_map_pins_noapi.lua` | Mini-Daten TBC | Mini-Daten Forever |
| `test_pages.lua` | echte TBC-Daten für Ausrüstung und Karte | echte Forever-Daten (`GearData.lua`, `MapData.lua`) |
| `test_award_forever.lua`, `test_map_page_forever.lua`, `test_map_pins_forever.lua`, `test_map_waypoint.lua`, `test_gear.lua`, `test_review16.lua`, `test_bis_data_forever.lua` | Forever per Vorlade-Zeile | Vorlade-Zeile weg (Stub-Standard); Prüfungen auf `NS.IsForever()` werden zu Prüfungen auf die Daten (`NS.GEAR`, `NS.MAP`) |
| `test_collect.lua` | ein TBC-Bezug | auf Forever-Daten |
| alle übrigen (Raids, Vergaben, Rolls, SR, Bank, Raidlog, Discord-Text, Widgets, Hauptfenster, Registry, Chat, Export, Scan, Minimap) | liefen als TBC-Client | laufen unverändert als Forever-Client; wo sie an fehlenden Globalen scheitern, wird der Test an den Forever-Weg angepasst, nicht der Stub zurückgedreht |

Neue Datei `test_forever_only.lua`:

- Die TOC hat genau `## Interface: 16001`, keine Zeile mit `TBC` oder `[AllowLoadGameType tbc]`,
  `GearData.lua`, `GearWeights.lua`, `MapData.lua` tragen `[AllowLoadGameType camelot]`,
  `## Version: 2.0.0`, und `NS.VERSION` stimmt damit überein.
- Im Addon-Ordner gibt es keine Datei mit `TBC` im Namen; keine Lua-Datei enthält `IsForever`,
  `LootButton`, `LootFrame_Update`, `GetSkillLineInfo(` als Globale, `BANK_CONTAINER`,
  `OnTooltipSetItem`, `20506` (Suche über den Dateitext).
- `NS.IsForever == nil`, `NS.Gear.Game == nil`, `NS.Gear.PlannerAvailable == nil`,
  `NS.SettingItem("bis.phase") == nil`.
- Umzug: ein `AmisiaDB` mit `settings.bis.phase = 2`, `settings.bis.sources = { H = true, F = true,
  X = true }` und `bis.guild = { game = "tbc", ... }` verliert genau diese drei Dinge; zweimal laden
  ändert nichts; Raids und Wünsche bleiben gleich.
- `NS.IGNORE` ohne 29434, 22450, 22449, 22448, mit 20725; `NS.MATS` leer.
- Leere Materialliste: Gildenbank öffnen und zählen ergibt keine neue Zählung, der Export enthält
  keine `B`-Zeile; mit einer im Test gesetzten Liste (`NS.MATS = { [12345] = "Testerz" }`,
  `NS.MAT_ORDER = { 12345 }`) läuft die Mechanik wie bisher (Zählung, `B 12345 n`).

### Python und Website-Tests

- `tools/tests/test_build_bis.py`: GELÖSCHT.
- `tools/tests/test_build_map.py`: TBC-Fälle gehen (`GEAR_TBC`, `test_quartermasters_and_entrances_on_tbc`,
  die TBC-Korrekturzeile der Eingänge, Karazhan mit zwei Eingängen); die Leseprüfungen der Eingänge
  laufen auf einem Forever-Dungeon (Deadmines, Era-Zeile). Neu: die Ausgabe hat keine Wächterzeile;
  `--game` gibt es nicht mehr.
- `tools/tests/test_build_gear.py`: neu: die Ausgabe von `GearWeights.lua` hat keine Wächterzeile.
- `tools/tests/test_export_format.py`: die Materialien-Prüfungen (32897, `B 32897 120`) setzen die
  Liste im Lua-Teil selbst (wie der neue Addon-Test); der Site-Parser liest `B`-Zeilen weiter, auch
  für das Archiv (alte Exporte).
- `tools/tests/site_wishes.cjs` / `test_wish_import.py`: Standardspiel `forever`; eine `tbc`-Zeile
  bleibt als "anderes Spiel, wird nicht gezählt".
- `tools/tests/site_archive.cjs` und `tools/tests/test_site_archive.py` (NEU, Muster wie
  `site_wishes.cjs`: Funktionen per `grab` aus `index.html`): `fitShelf` für die vier Ausgangslagen
  der Tabelle oben, zweimal ausgeführt gleich; `shelfGame` fehlt = tbc; `archiveView` aus `shelf.tbc`
  und aus den oberen Daten, mit `retired`; Raider entfernen lässt `shelf.tbc` gleich und legt
  `retired` an; `markDirty` im Archiv ändert `dirty` nicht; `takeState` im Archiv schreibt nach
  `liveState`; die Zahl der Vergaben und Abende ist vor und nach Umzug plus Archivansicht gleich
  (an einer Kopie des Twin-Startstands: 65 Vergaben im eingebauten Stand).
- `tools/tests/test_data_files.py` (NEU, klein): `data/` enthält genau `forever.*`, `tbc.*`,
  `craft-tbc.*`, `bossnames.js`; `bossnames.js` hat nur den Schlüssel `tbc`, und dessen Tabelle ist
  gleich der vor dem Filtern (Prüfsumme im Test festgehalten); jede Datei, die `index.html` lädt,
  existiert; `BUILD_ID` hat sich gegenüber 1.9 geändert (Wert im Test nicht fest, nur: die
  `twin-stamp.json`-Prüfung meldet den Twin als veraltet, bis er veröffentlicht ist).
- Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review), mit Augenmerk
  auf: nichts, was Forever braucht, ist mit einem TBC-Zweig verschwunden (Tooltip, Lootfenster,
  Bank, Berufe, Wegpunkt-Rückfall), und auf der Website kann kein Weg das Archiv beschreiben oder
  `shelf.tbc` löschen.

## Vorschlag für den Plan (6 Aufgaben)

1. **Stub und Bestandsaufnahme:** Zählung der Prüfungen je Testdatei; `wow_stub.lua` wird Forever
   (alle Punkte oben); Vorlade-Zeilen aufräumen; Testlauf zeigt, welche Dateien jetzt scheitern
   (erwartet: die TBC-Tests und alles, was an `LootButton`, Globalen, Bank -1 hängt). Noch keine
   Addon-Änderung. Aus `GearWeights.lua` nur die Wächterzeile entfernen (sonst fehlt in Aufgabe 2
   `ns.IsForever`), mit Kommentar in der Commit-Nachricht, dass `build_gear.py` sie auf dem PC nicht
   mehr schreibt (Aufgabe 2 ändert das Skript).
2. **Addon-Kern:** Names.lua, Core.lua (Tooltip, Shim, MATS, IGNORE, Version), Gear.lua, Bis.lua,
   Pages/Gear.lua, GearFrame.lua, Minimap.lua, SoftRes.lua, GuildWishes.lua, Chat.lua, Collect.lua,
   die `_G`-Rückfälle; Umzug in `ns.BisMigrate`; TOC (Zeilen weg, Interface, Version);
   `BisDataTBC.lua`, `BisWeightsTBC.lua` löschen; `build_gear.py` ohne Wächter; Lua-Tests der
   Ausrüstung, Namen, SR, Gildenwünsche, Review 18 umstellen; `test_forever_only.lua` (ohne
   Kartenteil); `test_bis_data.lua`, `test_build_bis.py`, `build_bis.py`, `bis_atlas_tbc.json`
   löschen; alle Addon-Tests grün.
3. **Karte:** erst nach den 1.9-Korrekturen. `MapDataTBC.lua` löschen, `build_map.py` nur Forever,
   Lauf auf dem N100 (neue `MapData.lua` ohne Wächter, `map_questie.json` ohne TBC), Kommentare und
   Tip-Text in Map.lua/MapPins.lua, `test_map_*` umstellen, `test_build_map.py`; Kartenteil von
   `test_forever_only.lua`.
4. **Website:** `GAMES`/`ARCHIVE`, `fitShelf` mit `PLAY`, `takeState`, Archivansicht mit
   Schreibschutz, Raider-Entfernen mit `retired`, Hinweiszeile für Editoren, Texte (Kopf, Mats,
   Import, Einstellungen), `BUILD_ID`; Datendateien löschen, `bossnames.js` filtern;
   `site_archive.cjs`, `test_site_archive.py`, `test_data_files.py`, `site_wishes.cjs`. Vorher eine
   Kopie des Live-Ledgers sichern (siehe Risiken).
5. **Werkzeuge und Doku:** `build_bossnames.py`, `fill_quality.py`, `sync_addon.ps1`,
   `tools/README.md`, `CLAUDE.md`; `test_export_format.py`.
6. **Auslieferung:** alle Tests
   (`~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
   `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs`), unabhängige
   Prüfung, `addon/Amisia.zip` neu bauen (aus `git archive` von `addon/Amisia`, wie die 1.8-Datei
   aufgebaut ist), Push (GitHub Pages), Twin bauen und veröffentlichen, `twin_stamp.py --published`,
   `tools/release_addon.sh`, ZIP und Release-Ordner gegen die TOC prüfen (keine TBC-Datei drin).

## Auslieferung

Version 2.0.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh`. Im Spiel genügt `/reload` (keine neue Textur, keine neue XML-Datei; drei
Dateien fallen weg, das ist für den Client unkritisch). Die Website ist mit dem Push live; die Seite
lädt neue Daten wegen der neuen `BUILD_ID`.

## Risiken

- **Datenverlust im Ledger.** Gegenmaßnahmen: der Umzug verschiebt nur, er löscht nie (Test zählt
  Vergaben und Abende vor und nach); `shelf.tbc` ist von `forgetRaider` ausgenommen; das Archiv kann
  nicht speichern. Vor Aufgabe 4 sichert die Aufgabe den Live-Stand: lesende Abfrage `select state,
  version from ledgers where id = 'main'` als JSON nach `~/addons/_backup/amisia-ledger-2026-10-05.json`
  (außerhalb des Repositorys, nicht von Syncthing gesendet). Supabase hält zusätzlich 40 Stände in
  `ledger_history` (heute 20), und `restore_ledger` holt einen davon zurück. Den Twin sichert die
  Aufgabe 6 vor dem Veröffentlichen genauso (`data.json` lesen und neben die Live-Kopie legen).
- **Ein alter Browser-Entwurf** (`localStorage guild-loot-ledger.site.v1`) eines Editors mit TBC oben
  wird beim Laden ebenfalls umgezogen und speichert gegen seine `baseVersion`; ist der Server neuer,
  gibt es wie heute einen Konflikt statt eines Überschreibens.
- **Die Junction auf dem PC.** Wird die `_anniversary_`-Verknüpfung falsch entfernt (Löschen mit
  Inhalt), löscht Windows die Dateien im Ziel `C:\Users\aobiw\VuloSync\Amisia`, das auch Forever
  nutzt; Syncthing (Empfangen) meldet dann lokale Löschungen, und Forever hat bis zum
  "Lokale Änderungen zurücksetzen" kein Addon. Deshalb der genaue Befehl unten.
- **Forever-Abdeckung geht bei der Umstellung verloren.** Gegenmaßnahme: die Bestandsaufnahme mit
  Zuordnung jeder gelöschten Prüfung, und alle bisher als TBC laufenden Tests laufen danach als
  Forever.
- **Ein gelöschter Rückfall wird in Forever doch gebraucht** (etwa ein Item ohne
  `C_Item.GetItemStats`-Antwort, der Alias `ChatEdit_InsertLink`). Gegenmaßnahme: Belege aus dem
  Zweig `forever` in der Tabelle oben; was dort nicht belegt ist, prüft Aufgabe 2 vor dem Löschen;
  im Spiel nach `/reload` die Prüfliste unten.
- **Gleichzeitige Arbeit an 1.9:** Aufgabe 3 wartet auf die committeten Korrekturen; Aufgaben 1, 2,
  4, 5 fassen die Kartendateien nur, wo die Tabelle es sagt (Item-Shim in MapPins.lua/Pages/Map.lua),
  und werden nach den 1.9-Commits begonnen.
- **Die gefilterte `bossnames.js`** weicht nicht von einem späteren Neubau mit `GAMES = ('tbc',)`
  ab, weil das Skript die Spiele getrennt schreibt; der Test hält die TBC-Tabelle fest.

## Schritte für den Nutzer

Am PC, einmal, wenn 2.0 ausgeliefert ist:

1. WoW Anniversary schließen. In einer Eingabeaufforderung (nicht PowerShell `Remove-Item`):
   `rmdir "C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\Amisia"`
   **ohne** `/s`. Das entfernt nur die Verknüpfung; `C:\Users\aobiw\VuloSync\Amisia` und die
   SavedVariables der Anniversary-Installation (`_anniversary_\WTF\...\Amisia.lua`) bleiben.

Sonst nichts. In Forever genügt `/reload`.

Im Spiel zu prüfen (Forever, nach `/reload`): Tooltip-Zeilen an Items (Upgrade, SR, Gildenwünsche,
Fundort mit Shift); SR- und W-Marke im Lootfenster, auch nach dem Scrollen; Seite Ausrüstung ohne
Phasen-Feld, mit "Tabelle öffnen"; "nur meine Berufe" kennt die eigenen Berufe; Bankinhalt nach
einem Bankbesuch in "Besitz"; Wegpunkt zu einem Ziel.

## Nicht in 2.0

Neue Forever-Funktionen; eine Liste von Forever-Materialien (offener Punkt); Neubau von
`GearData.lua` (bleibt PC-Lauf aus Baustein 3); Änderungen an Supabase (Schema, Edge-Function
`wcl-attendance`, Tabellen); Löschen von `shelf.<spiel>`-Daten aus alten Sicherungen; ein eigenes
Archiv im Addon (die TBC-Daten des Addons bleiben in der Anniversary-`Amisia.lua` auf dem PC);
Wowhead-Qualitäten für Forever (`fill_quality.py`).

## Später

- TOC-weite Zeile `## AllowLoadGameType: camelot`, sobald belegt ist, dass Forever sie für fremde
  Addons liest (Test: Zeile setzen, Addon lädt in Forever; in Anniversary erscheint es nicht in der
  Liste).
- Ausschlüsse von TBC-Orten (`ex.place` mit `I:<TBC-Instanz>`) aufräumen, wenn es eine Liste der
  Forever-Instanzen gibt.
- `index.html`-Startstand durch einen leeren Forever-Stand ersetzen (heute TBC-Beispieldaten).

## Offene Punkte

Für den Nutzer:

- **Welche Materialien soll Amisia in Forever zählen** (Gildenbank-Zählung, Loot der Materialien,
  Reiter Mats)? Standard bis zur Antwort: keine; die Mechanik bleibt und wird mit einer Liste von
  Item-IDs wieder aktiv.

Nur im Spiel oder an Quellen zu klären (blockiert nichts):

- Ob der Alias `ChatEdit_InsertLink` in Forever existiert (Zweig `forever` durchsuchen); davon hängt
  nur ab, ob der Hook in AwardDialog.lua bleibt.
- Ob `GearData.lua` nach dem nächsten PC-Lauf von `build_gear.py` je eine Zeile ohne
  Ausrüstungsstelle schreibt (der neue Test in `test_bis_data_forever.lua` fängt das; dann käme
  `Gear.FillRow` zurück).

Entschieden: Interface nur 16001; `[AllowLoadGameType camelot]` bleibt an den drei Datenzeilen, keine
TOC-weite Zeile; `ns.IsForever`, `Gear.Game`, `Gear.PlannerAvailable` gelöscht; Pfeil bleibt als
Forever-Rückfall; Materialliste leer, Mechanik bleibt; Tests laufen als Forever-Client; Website mit
Forever als einzigem Spiel und TBC als schreibgeschütztem Archiv für alle; Umzug automatisch im
Speicher, gespeichert mit dem nächsten Editor-Speichern oder per Knopf; `shelf.tbc` unantastbar,
entfernte Raider des Archivs in `retired`; Era, Hardcore, SoD, MoP samt Daten gelöscht, ihre
Regal-Daten in alten Sicherungen bleiben unberührt; TBC-Daten der Website nur noch für das Archiv;
Supabase unverändert.
