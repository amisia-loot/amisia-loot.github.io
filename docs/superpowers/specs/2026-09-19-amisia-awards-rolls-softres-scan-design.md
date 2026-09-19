# Amisia 1.2: Vergabe, Rolls, Soft-Reserves, Item-Scan

Stand 2026-09-19. Erweitert das Addon `addon/Amisia` und den Import der Seite `index.html`.

## Ziel

Der Master Looter braucht Gargul nicht mehr für das, was die Loot-Seite versteht:
Vergaben werden im Addon aufgezeichnet und mit dem bestehenden Export importiert,
Rolls laufen über ein eigenes Fenster, Soft-Reserves sind im Tooltip und im Lootfenster
sichtbar. Dazu ein Item-Scan, der auf WoW Forever die Datenbasis für ein eigenes
Loot-Datenfile liefert.

## Rahmen und Entscheidungen

- **Clients:** Anniversary 2.5.6 (`GetItemInfo`, Master Loot vorhanden) und Forever 1.60.1
  (Retail-Familie, nur `C_Item`, kein Master-Loot-Fenster: das Lootfenster des Clients
  sagt selbst "if these frames are returned to service"). Ein TOC mit
  `## Interface: 20506, 16001`. Alles, was auf Forever fehlt, wird zur Laufzeit geprüft
  und still übersprungen. Getestet wird auf Anniversary; auf Forever nur der Scan und das
  Laden ohne Fehler.
- **Roll-Bereiche:** Mainspec `/roll` (1-100), Offspec `/roll 99` (1-99). Die Systemmeldung
  nennt den Bereich, daher ist jeder Wurf eindeutig zuzuordnen. Andere Bereiche gelten
  als ungültig, werden aber angezeigt.
- **Soft-Reserves:** softres.it-CSV oder einfache Zeilen `Name [Item-Link]` /
  `Name 32837`.
- **Entzaubern, Bank:** ein Award an einen Namen ist ein Award. Wer an die Bank vergibt,
  vergibt an den Bank-Charakter, die Seite behandelt ihn wie heute.
- **Kein Sync zwischen Raidern.** Nur der Master Looter braucht die Module. Rolls kommen
  aus dem Systemchat, den jeder sieht.
- **Beta-Bug Forever:** der Client schreibt SavedVariables beim Ausloggen, liest sie aber
  nicht zurück. Ein Scan muss in einer Sitzung fertig werden, das Python-Skript liest die
  Datei nach dem Ausloggen.

## Dateien

```
addon/Amisia/Amisia.toc      Interface 20506, 16001; Version 1.2.0; neue Dateien
addon/Amisia/Core.lua        Kompat-Shim GetItemInfo, Awards im Session-Modell, Export A-Zeilen
addon/Amisia/Awards.lua      Master-Loot-Hook, manuelle Vergabe, Bestätigung
addon/Amisia/Rolls.lua       Roll-Runde, Parser, Ansagen, Roll-Fenster
addon/Amisia/SoftRes.lua     Import, Tooltip, Lootfenster-Marker
addon/Amisia/Scan.lua        Item-Scan mit Drosselung und Fortschritt
addon/Amisia/UI.lua          Buttons für Soft-Reserves und Scan-Status, Vergaben im Tooltip
tools/build_scan.py          SavedVariables -> data/forever.js
index.html                   amParse A-Zeilen, Awards in die Award-Vorschau, Forever-Datenfile
```

Alles hängt am Addon-Namespace `ns`. Jedes Modul hat einen kleinen öffentlichen Teil,
den Rest hält es lokal.

## 1. Vergabe-Aufzeichnung (Awards.lua)

**Datenmodell.** Jede Session bekommt `s.awards = { {name, item, t, kind, src} }`.
`kind` ist `MS`, `OS`, `SR` oder `-`. `src` ist der Quellname, so wie die D-Zeilen ihn
kennen (Bossname, sonst `?`).

**Master Loot.** Wenn `GiveMasterLoot` existiert: `hooksecurefunc("GiveMasterLoot",
fn(slot, candidate))`. Der Hook merkt sich einen Vorgang: Link aus `GetLootSlotLink(slot)`,
Empfänger aus `GetMasterLootCandidate(slot, candidate)`, Quelle aus dem offenen Lootfenster
(`GetLootSourceInfo(slot)` GUID, Name über die Drops der Session oder das Ziel). Der Vorgang
wird bestätigt durch das Erste von: Loot-Chatzeile mit diesem Namen und Item, oder
`LOOT_SLOT_CLEARED` für den Slot. Ohne Bestätigung innerhalb von 5 Sekunden oder bei
`LOOT_CLOSED` verfällt er. Erst die Bestätigung schreibt den Award.

**Roll-Kontext.** Beim Schreiben fragt Awards `ns.RollKind(item, name)` bei Rolls an:
war der Empfänger Gewinner oder Mitroller einer Runde für dieses Item in den letzten
10 Minuten, gibt das seinen Bereich (`MS`/`OS`), bei Reservierung `SR`. Sonst `-`.

**Manuell.** `/amisia award <Name> <Item-Link oder ID> [ms|os|sr]` schreibt einen Award in
die laufende Session, für Gruppenloot oder Handel. `/amisia unaward` entfernt den letzten
Award der laufenden Session. Beides meldet im Chat, was passiert ist.

**Ohne laufende Session** (kein Raid, keine Instanz) wird nichts geschrieben, mit Hinweis.

**Export.** In jedem S..E-Block nach den D-Zeilen:

```
A <Name> <ItemID> <Epoch> <MS|OS|SR|-> <Quellname...>
```

Die Item-IDs der A-Zeilen kommen in die N-Zeilen. `#AMISIA 1` bleibt: alte Seitenversionen
ignorieren unbekannte Zeilen, alte Addons schreiben keine A-Zeilen.

**Seite.** `amParse` liest A-Zeilen in `cur.awards`. Die Vorschau wandelt sie in Zeilen der
bestehenden Award-Vorschau: `{item, rawName, name, date: Sessiondatum, ts: Epoch*1000,
os: kind==='OS', boss: Quellname, cls: Klasse aus der M-Zeile, note: 'SR' bei SR}`
und hängt sie an die Gargul-Zeilen an, bevor `glResolve` läuft. Dadurch gelten dieselben
Regeln: Item muss in den Loot-Tabellen sein (sonst "ignoriert"), Boss wird gegen die
Quellen des Items geprüft und sonst auf die erste Quelle gesetzt, Duplikate über
`Datum|Item|Name` und die Liste entfernter Awards. Sessions, die nur Awards bringen, zählen
in der Session-Vorschau als "Imported", die Awards selbst erscheinen in der Award-Tabelle.

## 2. Roll-Tracking (Rolls.lua)

**Start.** Alt-Klick auf ein Item im Lootfenster (Hook auf `HandleModifiedItemClick`,
nur wenn das Lootfenster offen ist und Alt gedrückt) oder
`/amisia roll <Item-Link> [Sekunden]`. Standard 20 Sekunden, `/amisia rollzeit N` speichert
den Standard. Nur eine Runde gleichzeitig; ein Start während einer Runde bricht die alte ab.

**Ansagen.** Kanal `RAID_WARNING`, wenn Leiter oder Assistent, sonst `RAID`, außerhalb
eines Raids `PARTY`. Texte:

- Start: `Roll auf [Item]: /roll für Mainspec, /roll 99 für Offspec. 20 Sekunden.`
- Reservierung: `Reserviert von A, B.` (nur wenn vorhanden)
- Countdown bei 10, 5 und 3 Sekunden, jeweils nur wenn die Runde länger ist.
- Ende: `Stopp! Gewinner: Name (97, MS).` oder
  `Stopp! Gleichstand: A und B (97, MS). Bitte nochmal würfeln.`
- Ohne Wurf: `Stopp! Niemand hat gewürfelt.`

**Parser.** Muster aus `RANDOM_ROLL_RESULT` über den vorhandenen `buildMatcher` (die
`%d`-Spezifizierer sind dort schon vorgesehen). `CHAT_MSG_SYSTEM` wird nur während einer
Runde ausgewertet. Ein Wurf zählt, wenn der Name zur Raidgruppe gehört (Kurzname ohne
Realm), es der erste Wurf dieser Person ist und der Bereich 1-100 oder 1-99 ist. Zweite
Würfe und fremde Bereiche werden in der Liste grau mit Grund gezeigt und zählen nicht.

**Rangfolge.** Reservierer vor MS vor OS, innerhalb nach Wurf absteigend. Gleichstand:
gleicher Rang (Reservierung oder Bereich) und gleicher Wurf an der Spitze.

**Nochmal.** Bei Gleichstand startet "Nochmal" eine Runde mit 10 Sekunden, in der nur die
Namen mit Gleichstand zählen. Ansage: `Stechen: A, B. /roll. 10 Sekunden.`

**Fenster** `AmisiaRollFrame`, verschiebbar, über dem Lootfenster: Kopf mit Item-Icon,
Link und Restzeit; Liste (Name in Klassenfarbe, Bereich, Wurf, Hinweis); Buttons
"Stopp", "Nochmal", "Schließen"; pro Zeile "Vergeben". "Vergeben" sucht den Slot mit dem
Item im offenen Lootfenster und ruft `GiveMasterLoot(slot, kandidatenIndex)`; ohne
Master Loot, ohne offenes Lootfenster oder wenn das Item nicht mehr dort liegt, kommt ein
Hinweis im Chat, und der Award kann manuell geschrieben werden. Eine Runde bleibt
10 Minuten für `ns.RollKind` abrufbar.

## 3. Soft-Reserves (SoftRes.lua)

**Daten.** `DB.softres = { date, byItem = { [itemID] = { "Name", ... } }, raw }`. Eine
Liste pro Raidtag; beim Öffnen des Import-Fensters wird eine Liste eines anderen Tages als
"alt" markiert, bleibt aber, bis "Leeren" gedrückt wird.

**Import-Fenster.** Button "Soft-Reserves" im Amisia-Fenster öffnet ein kleines Fenster:
EditBox, "Übernehmen", "Leeren", Ergebniszeile (n Reservierungen, m Zeilen nicht erkannt).
Parser:

- Erste Zeile enthält `ItemId` (Groß/Klein egal): CSV, Trenner Komma oder Semikolon,
  Spalten über die Kopfzeile (`ItemId`, `Name`). Anführungszeichen wie bei
  `splitDelimited` auf der Seite.
- Sonst pro Zeile: `Name` gefolgt von Item-Link oder Item-ID, Trenner Leerzeichen,
  Tabulator, Komma, Semikolon oder Doppelpunkt. Ein Name ohne Link oder ID wird als nicht
  erkannt gezählt.
- Namen werden auf Kurznamen ohne Realm normalisiert, Doppelte pro Item entfernt.

**Tooltip.** `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`
wenn vorhanden, sonst `GameTooltip` und `ItemRefTooltip` `HookScript("OnTooltipSetItem")`.
Zeile `Reserviert: A, B` in Gold.

**Lootfenster.** Anniversary: nach `LOOT_OPENED`, `LOOT_SLOT_CLEARED` und einem Hook auf
`LootFrame_Update` bekommt jeder sichtbare `LootButton1..4` mit `.slot` eine kleine
Textmarke "SR" über dem Icon, wenn das Item reserviert ist. Forever:
`LootFrame.ScrollBox:ForEachFrame` nach `LOOT_OPENED` im nächsten Frame, Marke am
Element; fehlt die API, wird nichts markiert.

**Rolls.** Beim Start liefert `ns.ReservedBy(itemID)` die Namen für Ansage und Rangfolge.

## 4. Item-Scan (Scan.lua, tools/build_scan.py)

**Befehle.** `/amisia scan <von> <bis>` startet oder setzt fort, `/amisia scan stop`,
`/amisia scan status`, `/amisia scan rate N` (Anfragen pro Sekunde, Standard 100).
Ohne Bereich wird ab dem gespeicherten Fortschritt bis 250000 gescannt.

**Ablauf.** Ein Ticker alle 0,1 Sekunden schickt `rate/10` Anfragen über
`C_Item.RequestLoadItemDataByID`, höchstens 200 offen. `ITEM_DATA_LOAD_RESULT(itemID,
success)` schließt eine Anfrage: bei Erfolg werden die Felder gespeichert, bei Misserfolg
gilt die ID als nicht vorhanden. Eine offene Anfrage ohne Antwort nach 3 Sekunden wird
einmal wiederholt, dann in `DB.scan.retry` abgelegt. Der Scan läuft nur außerhalb von
Instanzen und pausiert im Kampf.

**Felder** über `C_Item.GetItemInfo` und `C_Item.GetItemInfoInstant`, als eine Zeile pro
Item, Tab-getrennt, damit die Datei klein bleibt:
`name, quality, itemLevel, minLevel, classID, subclassID, equipLoc, iconFileID, bindType`.
Ablage `DB.scan = { from, to, next, rate, items = { [id] = "..." }, retry = {}, at }`.
Nicht vorhandene IDs werden nicht gespeichert; `next` ist der Fortschritt.

**Fortschritt** im Chat alle 5000 IDs und im Amisia-Fenster als Statuszeile.

**build_scan.py.** Aufruf mit einer oder mehreren SavedVariables-Dateien (Anniversary
und Forever, mehrere Officers):

1. Liest jede Datei mit `lupa`, sammelt `scan.items` (Union, neuester gewinnt) und die
   Sessions mit ihren Drops (Zone, Instanz-ID, Quellname, Item-ID, Anzahl).
2. Zonen: aus den Sessions (Zonenname, Instanz-ID), Schlüssel und Farben aus
   `tools/forever_zones.json`, das der Officer pflegt (unbekannte Zonen bekommen einen
   Standard und werden gemeldet).
3. Bosse: Quellnamen pro Zone. `tools/forever_bosses.json` markiert Namen als Trash
   (dann `Trash (Zone)`) oder benennt sie um; unbekannte Quellen werden als Boss geführt
   und gemeldet.
4. Items: nur IDs, die in Drops vorkommen, mit Name, Qualität, Slot (aus `equipLoc`,
   Rezepte über `classID`), Quellen. Icon-Name pro Item von Wowhead
   (`item=ID&xml`, Cache `tools/icon-cache.json`), Sprite mit Pillow wie beim TBC-Build;
   ohne Icon ein Platzhalter im Sprite.
5. Schreibt `data/forever.js` im Format von `data/tbc.js`
   (`window.__LOOT["forever"] = {zones, bosses, items, sprite}`) und meldet, was von Hand
   zu prüfen ist.

**Seite.** Der Eintrag `forever` in `GAMES` bekommt `file: 'data/forever.js'` und verliert
`soon`, sobald die Datei existiert. `BUILD_ID` wird beim Ausliefern erhöht.

## UI-Änderungen (UI.lua)

- Session-Tooltip zeigt `Vergaben: n`.
- Zwei Buttons neben "Export erstellen": "Soft-Reserves" und "Rolls" (öffnet das
  Roll-Fenster der letzten Runde, falls vorhanden).
- Statuszeile zeigt einen laufenden Scan (`Scan 120000 von 250000, 3812 Items`).
- Alle Texte innerhalb Latin-1, keine Sonderzeichen (Schriftart des Clients).

## Fehlerfälle

- Hook auf eine fehlende Funktion wird übersprungen, das Addon lädt trotzdem.
- Roll-Runde ohne Gruppe: keine Ansage (kein Sagen-Kanal), Fenster und Parser laufen
  trotzdem, damit sich alles allein in der Stadt testen lässt.
- Scan im Kampf oder in einer Instanz pausiert und meldet es einmal.
- Verbindungsabbruch während des Scans: `next` bleibt, `/amisia scan` setzt fort
  (auf Forever-Beta nur innerhalb einer Sitzung).
- Import auf der Seite mit einem Addon 1.1-Export: unverändert, keine A-Zeilen.

## Tests

- Lua-Logik unter Python `lupa` mit einer kleinen WoW-Attrappe (`_G`-Strings,
  `CreateFrame`, `C_Timer`): Roll-Parser (deutsch und englisch, beide Bereiche,
  Doppelwurf, Fremder), Rangfolge und Gleichstand, SR-Parser (CSV, einfache Zeilen,
  Fehlerzeilen), Award-Bestätigung (Chatzeile, Slot geleert, Verfall), Export mit
  A-Zeilen, Scan-Zustandsmaschine (Antwort, Misserfolg, Timeout, Wiederholung).
- Syntax jeder Lua-Datei mit `luaparse` aus `VuloForeverUI/tools/node_modules`.
- Seite: `amParse` mit A-Zeilen, Duplikate, unbekanntes Item, Boss außerhalb der Quellen,
  im Browser mit einem Beispiel-Export.
- Im Spiel: Alt-Klick im Lootfenster, Roll-Runde mit zwei Charakteren, Vergabe über
  das Fenster, Tooltip und Marke, Scan über 1..5000 auf Anniversary und Forever-Beta.

## Reihenfolge

1. Core-Shim, TOC, Awards mit Export und Seiten-Import.
2. Rolls mit Fenster.
3. Soft-Reserves.
4. Scan und Build-Skript.

Jeder Schritt ist für sich auslieferbar.
