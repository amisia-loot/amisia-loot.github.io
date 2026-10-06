# Amisia: Quellen-Sammler (Quests, Händler, Weltdrops) mit Gildenaustausch

Stand 2026-10-06. Nur WoW Forever 1.60.1 (TOC 16001). Keine Versionsänderung in diesem Schritt.
Baut auf dem Item-Sammler (`Collect.lua`, Notizen in `scan.sources`), den Drop-Daten
(`Drops.lua`, `DropSync.lua`) und der Nachrichtenschicht (`Comm.lua`, `Trust.lua`) auf.

## Ziel

Keine Client-Tabelle sagt, **woher** ein Item kommt. AllTheThings (MIT) deckt viel ab, aber nicht
alles (Beispiel: 280604 "Rage of the Storm", Belohnung der Schamanenquest "The Tempest's Weapons",
dort als fehlend markiert). Amisia sammelt deshalb beim normalen Spielen, was der Client in dem
Moment zeigt, und teilt es leise in der Gilde:

1. **Quests:** ID, Titel (lokalisiert; Schlüssel bleibt die ID), Questgeber und Abgabe-NPC
   (NPC-ID aus `UnitGUID("npc")`) mit Kartenposition, Belohnungen und Wahlbelohnungen, Questlevel,
   niedrigstes gesehenes Spielerlevel, Fraktion des Spielers, Vorquest (best effort).
2. **Händler:** NPC-ID, Name, Position, verkaufte Ausrüstung und Rezepte mit Preis, Merker
   "begrenzter Vorrat" und "andere Währung", nötiger Ruf, wenn der Tooltip ihn nennt.
3. **Weltdrops und Rare:** je NPC (nicht Boss) Name, Einstufung (normal, Elite, Rar, Rar-Elite),
   Position bzw. Instanz-ID, Items ab Qualität grün, die man anlegen kann, oder Rezepte.

Genutzt wird das von `tools/build_gear.py` (Quelle unter ATT, über "unbekannt"), vom
Dungeon-Questlisten-Startort (`ns.DungeonQuests`) und von der Seite (`via`-Zeile über
`tools/build_scan.py`).

## Rahmen

- Nur, was das Spiel ohnehin zeigt (Questfenster, Händlerfenster, Lootfenster). Kein Kampflog.
- **Geheime Werte:** jeder Rückgabewert geht durch `ns.Plain`; ein geheimer GUID, Name oder
  Link wird übersprungen, nie verglichen. Kein `UnitName` von Spielern wird gespeichert oder
  gesendet; nur NPC-Namen, Quest-Titel und Fraktionsnamen.
- Grenzen des bestehenden Codes bleiben: Boss-Loot bleibt bei `Drops.lua`. Der neue Teil nimmt
  aus einem Lootfenster nur Leichen, die weder `ns.DropsIsBoss` noch ein Kill-Datensatz von
  `Drops.lua` sind. `Collect.lua` bleibt der Item-Sammler (`scan.sources`-Notizen).
- UI-Texte deutsch, Kommentare englisch, keine Gedankenstriche, keine fremden Addons oder Seiten.

## Dateien

- `addon/Amisia/Collector.lua` (neu): Beobachtung, Speicher, Zusammenführen, Grenzen, Abfragen.
- `addon/Amisia/CollectSync.lua` (neu): Austausch in der Gilde.
- `Comm.lua`: neue Nachrichtenarten CV, CQ, CI, CR, CW und Datenart CK.
- `Collect.lua`: ruft im LOOT_OPENED nach `ns.DropsFromLoot` auch `ns.CollectorFromLoot` auf.
- `Dungeons.lua`: Questgeber und Punkte aus den Beobachtungen, wo die Questdaten keine haben.
- `SelfTest.lua`: neue Funktionen und Ereignisse in den Listen.
- `tools/build_scan.py`: liest `collect` aus den SavedVariables (`parse_collect`), schreibt
  Quest/Händler-Notizen in die `via`-Zeile der Seite.
- `tools/build_gear.py`: Beobachtungen als Quelle.

## Speicher (`AmisiaDB.collect`)

```
collect = { ver = 1,
  q = { [questID] = "<Satz>" },   -- Quests
  s = { [npcID]   = "<Satz>" },   -- Händler
  w = { [npcID]   = "<Satz>" },   -- Weltdrops / Rare / Instanz-Trash
}
```

Ein Datensatz ist **ein String** (Felder mit `;`, der freie Text zuletzt): in SavedVariables
ist das etwa ein Drittel einer Tabelle, und derselbe String geht unverändert über die Leitung.
Positionen `"<uiMapID>:<x>:<y>"` mit x/y in Hundertstel Prozent (0-10000, wie
`DungeonQuestData.lua`), nur `"<uiMapID>"` ohne Koordinaten (Instanz), leer wenn unbekannt.

- Quest: `Tag;Geber;GeberPos;Abgabe;AbgabePos;Belohnungen;Wahl;Questlevel;MinSpielerlevel;Fraktion;Vorquest;Gebername;Titel`
  (Geber/Abgabe: NPC-ID, negativ für ein Objekt, 0 unbekannt; Listen `id,id`, je höchstens 8;
  Fraktion `""`, `A`, `H`, `AH`).
- Händler: `Tag;Pos;Items;Name`, Items `id:Preis:Merker:Ruf` mit Komma (Merker `L` begrenzt,
  `x` andere Währung; Ruf `<Stufe 1-8>@<Fraktion>`), höchstens 48 Items.
- Welt: `Tag;Einstufung;Pos;Instanz;Items;Name`, Einstufung `n e r R b` oder leer, Items
  `id:Anzahl`, höchstens 16 Items (je bis 99).

`Tag` = Tage seit 2026-01-01 (wie Drops), letzter Tag, an dem der Satz gesehen/geändert wurde.

### Zusammenführen (für eigene Beobachtung, gehörte Daten und gespeicherte Daten gleich)

Eine Vereinigung, die in jeder Reihenfolge dasselbe ergibt (kommutativ, assoziativ, idempotent),
damit zwei Clients nach einem Austausch denselben Satz halten und nicht endlos nachziehen:
Tag = Maximum; Listen = Vereinigung (die kleinsten IDs bis zur Grenze); Anzahlen = Maximum;
Preis = Minimum (Rufrabatt); Merker = Vereinigung; Fraktion = Vereinigung; Questlevel = Maximum;
MinSpielerlevel und Vorquest = kleinster Wert über 0; Texte, IDs und Positionen = der vorhandene
Wert, bei zwei verschiedenen der kleinere (Bytevergleich). Das ist bei Positionen willkürlich, aber
stabil.

### Grenzen und Größe

Gemessen 2026-10-06: `Amisia.lua` vom PC ist 2,33 MB, davon `scan.items` 2,09 MB,
`scan.sources` 132 KB, alles andere unter 50 KB. Grenzen des Sammlers:

| | Sätze | typisch | voll |
|---|---|---|---|
| Quests `q` | 2500 | ~120 B | ~300 KB |
| Händler `s` | 500 | ~150 B | ~75 KB (bis 48 Items je Händler größer) |
| Welt `w` | 2000 | ~70 B | ~140 KB |

Zusätzlich ein Byte-Budget von 480 KB (Summe der Satzlängen plus 16 je Satz; das ist genau der
Text `[id] = "Satz",` mit zwei Tabs in der Datei). Darüber und über den Satzgrenzen fallen die
ältesten Sätze (kleinster Tag; am selben Tag zuerst Weltdrops, dann Händler, dann Quests; dann die
höchste ID), und zwar bis 95 % der Grenze, damit eine volle Tabelle nicht bei jedem Satz sortiert
wird. Beim Laden wird jeder Satz neu geprüft; kaputte fallen.

Messung im Test (`test_collector.lua`, volle Tabellen mit typischen Sätzen): 2375 Quests,
475 Händler, 926 Mobs passen in die 480 KB (477 745 Bytes Dateitext); das Budget, nicht die
Satzgrenze, begrenzt dann die Weltdrops. Ein Abend Spielen ergibt erfahrungsgemäß einige Dutzend
Quests und Mobs (wenige KB).

## Beobachtung

- **QUEST_DETAIL** (Geber): Quest-ID (`GetQuestID`), Titel (`GetTitleText`), Geber
  (`UnitGUID("npc")`: `Creature`/`Vehicle` als NPC-ID, `GameObject` negativ, Spieler/Item nichts),
  Gebername (`UnitName("npc")` nur bei NPC), Position des Spielers (`C_Map.GetBestMapForUnit` +
  `C_Map.GetPlayerMapPosition`), Belohnungen und Wahl (`GetQuestItemLink`), Spielerlevel,
  Fraktion (`UnitFactionGroup`).
  **Vorquest (best effort):** hat derselbe NPC in den letzten 30 s eine andere Quest abgenommen
  (QUEST_TURNED_IN), gilt diese als Vorquest. Ein NPC, der danach eine unabhängige Quest anbietet,
  ergibt einen falschen Eintrag; deshalb nur als Hinweis gedacht, nicht als Kette in der UI.
- **QUEST_PROGRESS / QUEST_COMPLETE** (Abgabe): Abgabe-NPC mit Position; bei QUEST_COMPLETE auch
  Belohnungen.
- **QUEST_ACCEPTED**: (`questLogIndex, questID` wie Classic oder nur `questID`) Questlevel aus dem
  Questlog (`C_QuestLog.GetLogIndexForQuestID` + `C_QuestLog.GetInfo`, sonst
  `GetQuestLogIndexByID` + `GetQuestLogTitle`), Titel falls noch keiner.
- **QUEST_TURNED_IN**: merkt Quest und NPC für die Vorquest-Regel.
- Ein Mindestlevel liefert der Client nicht; das niedrigste gesehene Spielerlevel beim Angebot
  ist eine obere Schranke und steht dafür.
- **MERCHANT_SHOW**: nur mit NPC-ID. Je Ware `GetMerchantItemLink`, `GetMerchantItemInfo`
  (Preis, `numAvailable >= 0` = begrenzt, `extendedCost` = andere Währung), Ruf aus
  `C_TooltipInfo.GetMerchantItem` mit dem Muster aus `ITEM_REQ_REPUTATION`
  (Stufe über `FACTION_STANDING_LABEL1..8`). Gespeichert werden Ausrüstung, Rezepte und begrenzte
  Waren (Futter und Reagenzien nicht: die Quelle braucht nur, was man anlegt oder lernt).
- **LOOT_OPENED** (über `Collect.lua`): je Lootplatz `GetLootSourceInfo`. Nur `Creature`-Quellen,
  nicht Boss (`ns.DropsIsBoss`, Kill-ID schon in `drops.k`). Items ab grün, anlegbar oder Rezept.
  Name und Einstufung nur, wenn die Leiche Ziel oder Mouseover ist (`UnitClassification`). Eine
  Leiche zählt einmal je Sitzung (die GUIDs geöffneter Leichen werden gemerkt).
- Schalter: `collect.quests`, `collect.vendors`, `collect.world` (je Standard an).

## Austausch in der Gilde (CollectSync.lua)

Nach dem Muster von `DropSync.lua`, aber Bündel statt Tage: jede Art (q, s, w) hat 64 Bündel
(`ID % 64`). Prüfsumme eines Satzes = 4 Hex über den Satz **ohne Tag** (der Tag soll keinen
Abgleich auslösen); Prüfsumme eines Bündels = 4 Hex über "id=summe" sortiert; Prüfsumme einer Art
über die Bündel.

- **CV** (Gilde) `<Sammelprotokoll> <Sätze> q:hhhh:n,s:hhhh:n,w:hhhh:n`: erste Ansage 90-210 s
  nach dem Login (gestreut nach der Client-ID), dann höchstens alle 30 Minuten nach eigenen neuen
  Daten oder einmal nach gehörten.
- **CQ** (Flüstern) `<Art>` -> **CI** `<Art> <Teil> <Teile> bb:hhhh:n,...` (bis 20 je Teil).
- **CR** (Flüstern) `(<Art><bb> <bekannt>)...`: bis 12 Bündel einer Art (höchstens 220 Zeichen);
  bekannt = je eigener Satz des Bündels 4 Hex über "id=summe", höchstens 45, sonst `*`. Antwort:
  Daten **CK** (Schlüssel `0000-00-00:<n>`, n = Art*100 + erstes Bündel + 1) mit
  `{ v = 1, k = Art, r = { id, Satz, ... } }`, nur Sätze, die der Fragende nicht so hat, höchstens
  60 Sätze und 20 Teile; was nicht passt, kommt in einer späteren Runde (das Bündel unterscheidet
  sich dann noch). Eine leere Antwort ist erlaubt (der Fragende wartet nicht umsonst).
- **CW** `<Sekunden>`: beschäftigt, später wieder.

Ein Fragender hat immer nur eine Anfrage offen (Wartezeit 180 s); eine neue ersetzt beim Antwortenden,
was für ihn noch wartet. Blieben Antworten aus (beschäftigt, verloren), fragt er denselben Absender
für dieselbe Ansage höchstens zweimal erneut (nach 60-90 s).

Regeln: Beide Seiten ziehen, keiner schiebt. Daten nur auf eine eigene offene Anfrage, nur von
Gildenmitgliedern (`ns.TrustWait(..., "member")`, Comm entpackt Daten nur von Mitgliedern).
Jeder empfangene Satz wird wie ein gespeicherter streng geprüft (IDs, Zahlenbereiche, Listen,
Grenzen, Texte über `DropsCleanName`); ein ungültiger Satz verwirft den ganzen Blob. Sätze eines
nicht erfragten Bündels, doppelte IDs, fremde Felder ebenso. Grenzen je Sitzung: 48 KB gesendet, ein Fragender höchstens ein Drittel,
ein Blob je 20 s und 40 Teile je 10 Minuten, 40 Anfragen je Stunde, höchstens 1500 neue Sätze von einem Absender.
Alles mit niedrigster Priorität der Warteschlange, nur außerhalb von Instanzen und Schlachtfeldern,
ohne Kampf, ohne Sperre (`ns.CommHeld`), nicht während ein Raid synchronisiert wird.
Abschalter `collect.share` (Standard an).

**Ältere und neuere Clients:** CV trägt die Sammelprotokollnummer; ein Client zieht nur von
derselben Nummer, eine andere wird still übergangen. Clients vor diesem Stand kennen CV nicht:
Comm verwirft die Nachricht als ungültig (Zähler, Debugzeile nur mit `sync.debug`), ohne den
Absender zu sperren; CQ/CR/CK gehen nur per Flüstern an Clients, die CV gesendet haben.

## Nutzung

- `ns.CollectQuest(id)`, `ns.CollectVendor(npc)`, `ns.CollectWorld(npc)`: der geprüfte Satz als
  Tabelle. `ns.CollectQuestStart(id)`: Gebername und Punkt `"map:x:y"`.
- `ns.DungeonQuests` / Wegpunkt: Questgeber und Punkt aus den Beobachtungen, wenn weder die
  Questdaten noch die Kartendaten einen haben.
- `tools/build_gear.py`: Reihenfolge ATT vor Beobachtung vor "unbekannt". Kennt ATT die Quest, gilt
  ATTs Satz (die beobachtete Belohnung kommt dazu, wenn ATT sie nicht listet); sonst ein Q-Satz aus
  Titel, Questlevel, Mindestlevel (beobachtet), Fraktion (`A`/`H`, beide = keine), Zone (Karte des
  Gebers), ID. Händler: ATTs NPC, sonst Name und Zone der Beobachtung. Welt: Rare (`r`/`R`) als R,
  in einer Instanz als Trash W, sonst W. So bekommt 280604 seine Quelle, sobald jemand die Quest
  sieht (QUEST_DETAIL reicht).
- Seite: `build_scan.py` hängt Quest- und Händler-Beobachtungen als Notizen an die `via`-Zeile
  ("Also seen"). Eine eigene Quellenansicht auf der Seite ist Folgearbeit.
- `/amisia quellen`: Zahlen, Größe, Austausch-Zähler.

## Tests

- `addon/tests/test_collector.lua`: Quest-, Händler-, Weltbeobachtung, Vorquest, Schalter,
  geheime Werte (GUID, Name, Link, Position) und Sperre, Grenzen und Kürzen, Laden kaputter Sätze,
  Zusammenführen in jeder Reihenfolge gleich.
- `addon/tests/test_collect_sync.lua` (mehrere Clients): Gleichstand nach dem Austausch, nur
  Fehlendes reist, Außenstehende werden ignoriert, kaputte/ungefragte Blobs verworfen, andere
  Protokollnummer übergangen, nichts in Instanz/Kampf/Sperre, Bytegrenze.
- `tools/tests/test_build_gear.py`, `test_build_scan.py`: Beobachtungen als Quelle, ATT gewinnt.

## Im Spiel zu prüfen

- `UnitGUID("npc")` bei QUEST_DETAIL/QUEST_COMPLETE und MERCHANT_SHOW (Forever), auch bei Quests
  aus Objekten und Items.
- Argumente von QUEST_ACCEPTED auf Forever (Index + ID oder nur ID).
- `GetMerchantItemInfo`-Rückgaben und die Ruf-Zeile im Händler-Tooltip.
- `C_Map.GetPlayerMapPosition` in Instanzen (nil erwartet).
- Größe von `AmisiaDB.collect` nach einigen Abenden (`/amisia quellen`).
