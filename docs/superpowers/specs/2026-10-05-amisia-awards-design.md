# Amisia 1.5: Vergaben verwalten

Stand 2026-10-05. Baustein 5 von 7 (Reihenfolge der Umsetzung laut Nutzer: 5, 4, 6, 3, 2, 7).
Baut auf dem Fundament aus Baustein 1 auf (`docs/superpowers/specs/2026-10-04-amisia-main-window-design.md`):
Registry, Widgets, Hauptfenster, Seiten. Ändert das Addon `addon/Amisia`, das Exportformat (nur
neue Zeilen) und den Import der Seite `index.html`.

## Ziel

Heute schreibt Amisia eine Vergabe nur, wenn Master Loot sie bestätigt oder ein Offizier
`/amisia award` tippt; korrigieren lässt sich nur die letzte (`/amisia unaward`). Nach dem Raid
sieht man Vergaben nur als Fließtext in den Raid-Details. Baustein 5 macht Vergaben zu einer
eigenen Seite, auf der Offiziere jede Vergabe eines Raids sehen, ändern, löschen, zurücknehmen und
von Hand ergänzen. Items, die an die Gildenbank gehen oder entzaubert werden, bekommen einen eigenen
Empfänger, den Export und Seite verstehen. Ein Plus-Eins-Zähler zeigt, wer in diesem Raid oder
dieser ID-Woche schon ein Mainspec-Item bekommen hat, und kann auf Wunsch die Roll-Reihenfolge
beeinflussen. Jede Vergabe bekommt eine feste Kennung, damit die Seite einen erneuten Import
derselben Vergabe erkennt und Änderungen aus dem Spiel übernimmt statt Doppel anzulegen.

## Rahmen und Entscheidungen

- **Clients, Bibliotheken, Schrift, Fensterebenen, Offiziersansicht:** wie Baustein 1. Ein TOC
  (`20506, 16001`), keine fremden Bibliotheken, kein `UIDropDownMenu`/`EasyMenu`, UI-Texte deutsch
  und nur Latin-1 (ä ö ü ß und "·", kein Gedankenstrich, keine Auslassungspunkte, keine Pfeile),
  Code-Kommentare englisch. Anmeldung nur über `ns.RegisterPanel`, `ns.RegisterCard`,
  `ns.RegisterSettings`, `ns.RegisterSlash`; Offiziersteile über `ns.IsOfficerView()`.
- **Keine anderen Addons nennen**, weder in UI-Texten, Kommentaren noch Commits. Im Entwurf heißen
  sie "andere Loot-Addons".
- **Exportregel:** bestehende Zeilen und Felder bleiben Byte für Byte gleich; Neues kommt als neue
  Zeilenart. Die Seite liest weiter Version 1 und 2. Der Kopf bleibt `#AMISIA 2`: eine ältere Seite
  überspringt die neuen Zeilen (ihr Parser vergleicht `f[0] === 'A'` exakt), eine neue Seite liest
  sie. Ein neues Feld ans Ende der `A`-Zeile zu hängen geht nicht, weil der Quellname dort das
  letzte Feld ist und Leerzeichen enthält.
- **Gelöschte Vergaben bleiben als Grabstein** in einer eigenen Liste `s.gone`, nicht in
  `s.awards`. Alles, was heute `s.awards` liest (Anzahl, Raid-Details, Export der `A`-Zeilen), sieht
  so nur lebende Vergaben und muss nicht jede Stelle auf "gelöscht" prüfen.
- **Vergaben vergangener Raids sind änderbar**, nicht nur die der laufenden Aufnahme. Eine Änderung
  setzt nie `s.last` (sonst würde `findReusable` einen alten Raid fortsetzen) und fügt keine
  Anwesenheit hinzu, außer der neue Name steht schon in `s.members` oder (nur in der laufenden
  Aufnahme) in der Gruppe, wie bei `ns.AddAward` heute.
- **Sofort anwenden, dafür Rückgängig:** Änderungen auf der Seite wirken beim Klick, ohne
  Speichern-Knopf und ohne Rückfrage; jede Änderung landet auf einem Rückgängig-Stapel (20 Schritte,
  nur bis zum Ausloggen). Nur das Vergeben über Master Loot fragt weiter vorher, wie im Roll-Fenster.
- **Forever:** Roll-Ergebnisse (`CHAT_MSG_SYSTEM`) können während eines Bosskampfs geheim sein,
  `UnitName` und Kreaturnamen in Instanzen ebenso. Vergeben darf davon nicht abhängen: der
  Vergabe-Dialog nimmt den Gewinner aus einer Namensliste (Anwesenheit, Raidliste, Master-Loot-
  Kandidaten), die Roll-Runde füllt ihn nur vor, wenn sie einen Gewinner hat. Bestätigt wird über
  `GiveMasterLoot`-Hook, `CHAT_MSG_LOOT` und `LOOT_SLOT_CLEARED`, die nicht als geheim markiert
  sind. Geheime Werte werden über `ns.Plain(v)` erkannt und übersprungen, nie verglichen.
- **Plus-Eins zählt nur Mainspec-Gewinne** (Art `MS`) an Spieler in lebenden Vergaben. SR, OS,
  Bank und Entzaubern zählen nicht. Plus-Eins wirkt, wenn eingeschaltet, nur zwischen
  MS-Würfen; Reservierungen stehen weiter vorn, OS dahinter.
- **Raider-Ansicht:** Raider haben ohne Sync (Baustein 7) die Vergaben anderer nicht. Sie sehen
  auf der Seite nur ihre eigenen Items aus der Aufnahme (`s.items` mit eigenem Namen, dazu eigene
  `s.awards`, falls sie selbst Plündermeister waren), nur lesend.

## Dateien

```
addon/Amisia/Core.lua           ns.AddAward ruft ns.AddAwardTo(active, ...); ns.NoteMember und
                                ns.RememberItem öffentlich; Export schreibt AX, AS, AD;
                                ns.SessionHash(s, legacy); Umzug beim Laden (ns.MigrateAwards)
addon/Amisia/Awards.lua         Vergabebuch: Kennung, AddAwardTo, EditAward, DeleteAward,
                                RestoreAward, Rückgängig-Stapel, Bank/Entzaubern, Namensvorschläge,
                                PlusCount, Umzug; Bestätigung erkennt Bank-/Entzauber-Charakter;
                                Einstellungen "awards", Befehle
addon/Amisia/AwardDialog.lua    NEU: Vergabe-Dialog (Item, Raid, Gewinner, Art, Notiz; Vergeben,
                                Bank, Entzaubern, Abbrechen) und Alt+Shift-Klick
addon/Amisia/Names.lua          ns.Plain(v): nil für geheime Werte (issecretvalue, falls vorhanden)
addon/Amisia/Rolls.lua          Plus-Eins in ns.RollRanking und Gleichstand; Wurfzeile mit
                                geheimem Text wird ignoriert
addon/Amisia/RollFrame.lua      Spalte Art zeigt "MS +1"; Alt-Klick startet nur ohne Shift
addon/Amisia/Widgets.lua        NEU W.Picker (Auswahlliste mit Filter und Scrollen),
                                W.LineEdit (einzeilige Eingabe, links bündig)
addon/Amisia/Pages/Awards.lua   NEU: Seite "Vergaben" und Karte "Vergaben letzte Nacht"
addon/Amisia/Pages/Raids.lua    Karte "awards" wandert nach Pages/Awards.lua; Details zeigen
                                Bank/Entzaubern und Notizen
addon/Amisia/Pages/Rolls.lua    Gewinnerzeile zeigt +1 des Gewinners
addon/Amisia/Pages/Settings.lua Zeilentyp "text" (W.LineEdit), bisher ohne Steuerelement
addon/Amisia/Minimap.lua        Schnellmenü: Eintrag "Vergaben" (Offiziere)
addon/Amisia/Amisia.toc         AwardDialog.lua nach RollFrame.lua, Pages\Awards.lua nach
                                Pages\Rolls.lua; Version 1.5.0
index.html                      amParse liest AX, AS, AD; amAwardRows mit Kennung; glResolve
                                kennt "change" und "gone"; state.lootAway; Nachtansicht zählt
                                Bank/Entzaubern als vergeben
tools/tests/site_parser.cjs     Zeilenarten mit zwei Buchstaben
tools/tests/site_awards.cjs     NEU: glResolve und amApplyAwardChanges gegen Stubs
tools/tests/test_export_format.py, tools/tests/test_award_import.py (NEU)
addon/tests/*                   neue Tests, Stub ergänzt
```

## Datenmodell

Vergabe in `s.awards` (bisher `name, item, t, kind, src`):

```lua
{ id = "651f3a2c9b04",   -- NEU: 12 Hex-Zeichen, im Raid eindeutig, ändert sich nie
  name = "Fraktur",      -- Empfänger; bei Bank/Entzaubern der Charakter, der es bekam, sonst "-"
  item = 32235, t = 1759600000, kind = "MS" | "OS" | "SR" | "-", src = "Illidan Sturmgrimm",
  to = "player" | "bank" | "de",   -- NEU, fehlt = "player"
  note = "Tausch mit Vuloo",       -- NEU, optional, höchstens 60 Zeichen, ohne "|" und Zeilenumbruch
  edited = 1759603600,             -- NEU, optional: Zeit der letzten Änderung
  orig = "Frakture",               -- NEU, optional: erster Empfänger, gesetzt bei der ersten Namensänderung
  manual = true }                  -- NEU, optional: von Hand eingetragen (Befehl, Seite, Dialog aus Taschen)
```

Neu im Raid: `s.gone = { <Vergabe mit deleted = epoch> }`: gelöschte Vergaben mit allen Feldern,
für Rückgängig und für die `AD`-Zeile. Wird mit dem Raid gelöscht oder beim Kürzen der Liste
(`record.keepSessions`) mit entfernt.

- **Kennung:** neue Vergaben `("%08x%04x"):format(t, math.random(0, 65535))`; ist sie im Raid
  schon vergeben (auch in `s.gone`), neu würfeln. Für den Umzug deterministisch aus
  `checksum(s.id .. "\t" .. name .. "\t" .. item .. "\t" .. t)`, die ersten 12 Zeichen, damit zwei
  Ladevorgänge dieselbe Kennung ergeben.
- **Zeit:** bleibt Epoch-Sekunden (`t`, `edited`, `deleted`), wie bisher in Export und Seite.

### API (Awards.lua, Kern-Hilfen aus Core.lua)

```lua
ns.AddAwardTo(s, { name, item, kind, src, t, to, note, manual }) -> a | nil, Grund
ns.AddAward(name, item, kind, src, t)          -- wie heute, ruft AddAwardTo(ns.Active(), ...)
ns.EditAward(s, id, { name?, kind?, note?, to? }) -> a | nil, Grund
ns.DeleteAward(s, id) -> a                     -- nach s.gone, deleted = time()
ns.RestoreAward(s, id) -> a                    -- aus s.gone zurück, nach t einsortiert
ns.UndoAward() -> Beschreibung | nil           -- letzter Schritt des Stapels
ns.UndoLabel() -> "Löschen von <Item> an <Name>" | nil
ns.FindAward(s, id) -> a, index, inGone
ns.RenameAwards(s, from, to) -> Anzahl         -- "Namen korrigieren" für alle Vergaben an from
ns.NameSuggestions(s, name) -> { names }       -- Mitglieder mit ns.SameName oder gleichem Vornamen
ns.IsSpecialName(name) -> "bank" | "de" | nil  -- awards.bankName / awards.deName
ns.PlusCount(name, scope?) -> n                -- scope "raid" | "week", Standard awards.plusScope
ns.MigrateAwards(DB)
ns.NoteMember(s, name, class, t), ns.RememberItem(id, link, q)   -- aus Core, bisher lokal
```

- Jede Änderung ruft `ns.Fire("DATA_CHANGED")` (das Hauptfenster hört schon darauf) und legt einen
  Eintrag `{ op = "add"|"edit"|"delete", s, id, before = Kopie }` auf den Stapel.
- Rückgängig: `add` -> Löschen (Grabstein, damit eine schon exportierte Vergabe auf der Seite
  verschwindet); `delete` -> Wiederherstellen; `edit` -> alte Felder zurück, `edited = time()`
  (die Seite übernimmt den zurückgesetzten Stand, weil er neuer ist).
- `/amisia unaward` löscht die neueste lebende Vergabe der laufenden Aufnahme über `DeleteAward`
  und ist damit rückgängig zu machen.
- `EditAward` mit neuem Namen setzt `orig` beim ersten Mal auf den alten Namen. Mit `to = "bank"`
  oder `"de"` wird `kind` zu `"-"`; `name` bleibt der Charakter, der es bekam.
- Bestätigung über Master Loot (`commit` in Awards.lua): ist der Empfänger `awards.bankName` oder
  `awards.deName`, wird die Vergabe mit `to = "bank"` bzw. `"de"` und `kind = "-"` geschrieben.

## Umzug bestehender Daten

Beim Laden, wenn `AmisiaDB.awardsVersion` fehlt oder < 1 ist, in dieser Reihenfolge:

1. Für jeden Raid mit Exportmarke `DB.exported[s.id]`: `ns.SessionHash(s, true)` (alte Form, ohne
   `AX`/`AS`/`AD`, alle Vergaben als `A`) mit der gespeicherten Marke vergleichen und merken.
2. Jede Vergabe ohne `id` bekommt die deterministische Kennung, `to = "player"`; `s.gone = {}`.
3. Raids, deren alte Marke passte, bekommen die neue Marke `ns.SessionHash(s)`. Ein schon
   exportierter Raid steht danach weiter als "exportiert" da, statt durch die neuen Zeilen auf
   "geändert" zu springen.
4. `AmisiaDB.awardsVersion = 1`.

Läuft in Core beim `ADDON_LOADED` nach dem Auffüllen der Raid-Tabellen und vor dem Aufräumen der
Exportmarken. Ein Raid ohne passende alte Marke bleibt, wie er war ("neu" oder "geändert").

## Export

Bestehende Zeilen unverändert. Neue Zeilen im `S..E`-Block, Namen wie überall mit `_` statt
Leerzeichen:

```
A  <name> <itemID> <epoch> <MS|OS|SR|-> <source name>            unverändert, nur to = player
AX <id> <edited epoch|0> <first winner|-> [<note>]               direkt nach jeder A- und AS-Zeile
AS <id> <itemID> <epoch> <BANK|DE> <receiver|-> <source name>    Vergabe an Bank oder Entzaubern
AD <id> <itemID> <epoch> <deleted epoch>                         gelöschte Vergabe (Grabstein)
```

- `AX` gehört zur Vergabe mit derselben Kennung im selben Block; die Notiz ist das letzte Feld und
  darf Leerzeichen enthalten. Eine Vergabe ohne Änderung und Notiz schreibt `AX <id> 0 -`.
- `AS`- und `AD`-Items kommen in die `N`-Zeilen wie `A`-Items.
- `ns.SessionHash` deckt die neuen Zeilen mit ab: jede Änderung, Löschung oder Notiz macht den Raid
  "geändert", er erscheint unter "Neue und geänderte" auf der Export-Seite.
- `tools/tests/test_export_format.py` liest die Zeilenarten aus Core.lua heraus; das Muster wird
  auf ein bis zwei Großbuchstaben erweitert (Addon und `site_parser.cjs`), sonst fallen `AX`, `AS`,
  `AD` durch die Prüfung "jede geschriebene Zeile wird gelesen".

## Website (index.html)

Texte der Seite bleiben englisch wie die ganze Seite.

- **amParse:** neue Zweige für `AX` (sucht die Vergabe mit der Kennung in `cur.awards` oder
  `cur.away` und setzt `uid`, `edited`, `orig`, `note`), `AS` (nach `cur.away`:
  `{uid, item, at, to: 'bank'|'de', receiver, source}`), `AD` (nach `cur.gone`:
  `{uid, item, at, deleted}`). Die `A`-Zweige bleiben, wie sie sind.
- **amAwardRows:** Zeilen tragen zusätzlich `amKey` (= `uid`), `amEdited`, `orig`; `note` wird aus
  SR und der Notiz mit " · " verbunden. Ohne `AX` (Export aus 1.4) fehlen die Felder, alles bleibt
  wie heute.
- **glResolve,** in dieser Reihenfolge:
  1. `amKey` und eine Vergabe im Ledger mit `a.am === amKey`: weichen Empfänger, OS oder Notiz ab
     und ist `amEdited > (a.amEdited || 0)`, Status `change` (Vorschau: "Changes" mit dem, was sich
     ändert); sonst `dup`. Eine Änderung auf der Seite wird so nicht von einem alten Export
     überschrieben.
  2. `amKey`, aber keine solche Vergabe: der bisherige Abgleich über `date|item|name`, zusätzlich
     über `date|item|orig`. Trifft er eine Vergabe ohne `a.am`, wird sie `fill` und bekommt die
     Kennung (`fill.am`), bei abweichendem Empfänger `change`.
  3. `dropped` kennt neben `k<gargul-key>` und der Signatur auch `m<amKey>`: eine auf der Seite
     entfernte Vergabe kommt nicht zurück.
- **amGoneRows(sessions):** jede `AD`-Zeile, zu der das Ledger eine Vergabe mit `a.am` hat, wird
  eine Zeile mit Status `gone` ("Removed in game"); ohne Treffer wird sie nicht angezeigt.
- **amApplyAwardChanges(rows):** neue benannte Funktion, die der Import-Knopf aufruft (testbar):
  `change` setzt Raider (wie der bestehende "lootmove"), Notiz, OS, `a.amEdited`, und schreibt die
  alte Signatur nach `dropped`, damit der Export eines zweiten Aufnehmenden mit dem alten Gewinner
  als "Removed" erscheint; `gone` entfernt die Vergabe über `forgetImport`. `importSig`/`forgetImport`
  merken zusätzlich `m<amKey>`.
- **Bank und Entzaubern:** `AS`-Zeilen erscheinen in der Vorschau als "Ignored" mit Grund "to the
  guild bank" bzw. "disenchanted" und legen keinen Raider an. Beim Import landen sie in der neuen
  Liste `state.lootAway` (`{key: amKey, date, instance, item, to}`, doppelt über `key` erkannt),
  die in `PER_GAME` und im Laden des Zustands (Typprüfung wie `lootDrops`) dazukommt. Die
  Nachtansicht zählt sie bei "taken" mit, so stehen sie nicht mehr unter "nicht vergeben".
  `amResolve` zählt einen Raid mit neuen `AS`-Einträgen als neu (`addsAway`).
- Neue Felder an Ledger-Vergaben: `am` (Kennung), `amEdited`.
- Nach der Änderung: Twin neu bauen und veröffentlichen, `python tools/twin_stamp.py --published`.
  `BUILD_ID` bleibt (keine Datendatei geändert).

## Seite "Vergaben" (Pages/Awards.lua)

`ns.RegisterPanel{ key = "awards", label = "Vergaben", icon = "Interface\\Icons\\INV_Misc_Bag_08",
order = 35 }`, für alle sichtbar; Inhalt nach `ns.IsOfficerView()`.

### Offiziersansicht

```
+-----------------------------------------------------------------------------------------+
| [Schwarzer Tempel, 02.10. v]  [Suche: Name oder Item      ]   [Hinzufügen] [Rückgängig] |
| 14 Vergaben · 1 Bank · 2 Entzaubern · Raid nicht exportiert                             |
| Zeit   Item                          Gewinner            Art   +1  Quelle                |
| 21:14  Fluchsicht des Sargeras       Fraktur             MS    2   Illidan Sturmgrimm    |
| 21:16  Kriegsklinge von Azzinoth     Bank (Vulobank)     -         Illidan Sturmgrimm    |
| 21:20  Schulterpolster des ...       Vulo ?              OS        Mutter Shahraz        |
| ...                                                (12 Zeilen, Mausrad scrollt)          |
+-----------------------------------------------------------------------------------------+
| Fluchsicht des Sargeras · 21:14 · Illidan Sturmgrimm                                    |
| Gewinner [Fraktur      v]   Art [MS] [OS] [SR] [-]   Notiz [Tausch mit Vuloo         ]  |
| [Bank] [Entzaubern] [Löschen]          geändert 22:03, zuerst an Frakture               |
| Hinweis: "Vulo" steht nicht in der Anwesenheit. Gemeint: [Vulo Sturmwind] [x alle 3]    |
+-----------------------------------------------------------------------------------------+
```

- **Raid-Auswahl** (W.Picker): laufende Aufnahme zuerst, dann die gespeicherten Raids neueste zuerst
  ("Datum, Zone"), am Ende "Alle Raids". Standard: laufende Aufnahme, sonst der neueste Raid.
- **Suche** (W.LineEdit): Teiltext, ohne Groß/Klein, gegen Gewinner, Itemname (`ns.ItemName`),
  Quelle und Notiz. Mit "Alle Raids" durchsucht sie alle gespeicherten Raids (Spalte Zeit zeigt
  dann "02.10." statt der Uhrzeit). Die Seite der Website bleibt die vollständige Historie; im Spiel
  reicht sie so weit wie `record.keepSessions`.
- **Liste** (W.List, 12 Zeilen à 22 px): Zeit, Item (Qualitätsfarbe aus `DB.itemNames`, Tooltip
  mit dem Item beim Überfahren), Gewinner (Klassenfarbe aus `s.members`; Bank/Entzaubern als
  "Bank (Name)" / "Entzaubern (Name)" in Grau; ein goldenes "?" hinter Namen, die nicht in
  `s.members` stehen), Art, +1 (des Gewinners, nur bei MS-Vergaben an Spieler), Quelle. Ein Klick
  wählt die Zeile; Shift-Klick auf eine Zeile fügt den Item-Link in die Chat-Eingabe ein.
- **Bearbeiten** (unter der Liste, nur bei gewählter Zeile):
  - Gewinner: W.Picker mit den Namen aus `s.members`, in der laufenden Aufnahme dazu der Raidliste,
    sortiert, mit Filterfeld; der letzte Eintrag "Anderer Name" nimmt freien Text an.
  - Art: vier Chips MS/OS/SR/-; Notiz: W.LineEdit, übernimmt bei Enter oder beim Verlassen.
  - Knöpfe "Bank", "Entzaubern" (setzen `to`; auf einer Bank-/Entzauber-Vergabe heißt der Knopf
    "An Spieler" und öffnet den Gewinner-Picker), "Löschen".
  - Status rechts: "geändert HH:MM, zuerst an <orig>", "von Hand eingetragen", Notiz-Länge.
  - **Namen korrigieren:** steht der Gewinner nicht in `s.members`, zeigt die Zeile darunter
    `ns.NameSuggestions` als Chips ("Vulo Sturmwind"); ein Klick ändert diese Vergabe, der Chip
    "alle <n>" ändert alle Vergaben dieses Namens im Raid (`ns.RenameAwards`, ein Schritt auf dem
    Stapel). Gedacht für Forever-Namen ohne Nachnamen und Tippfehler bei `/amisia award`.
- **Hinzufügen** öffnet den Vergabe-Dialog für den gewählten Raid (bei "Alle Raids": laufende
  Aufnahme, sonst der neueste Raid) ohne Item. **Rückgängig** ist nur aktiv, wenn der Stapel etwas
  hat; Tooltip `ns.UndoLabel()`.
- Kopfzeile unter der Auswahl: Anzahl, Bank, Entzaubern, Exportstatus des Raids (`ns.ExportState`).

### Raider-Ansicht

Überschrift "Deine Items", Liste über alle gespeicherten Raids: Datum, Item, Raid (Zone), Art (aus
eigenen `s.awards`, sonst leer). Quelle sind `s.items` mit `ns.SameName(name, ich)`, dazu eigene
`s.awards`; dasselbe Item im selben Raid nur einmal. Keine Knöpfe, keine Suche. Text darunter:
"Vergaben anderer siehst du auf der Amisia-Loot-Seite."

### Karte "Vergaben letzte Nacht"

Zieht von Pages/Raids.lua nach Pages/Awards.lua (gleicher Schlüssel `awards`, order 40).
- Offiziere: Zeile 1 "%d Items am %s" (lebende Vergaben der letzten Nacht, Bank/Entzaubern
  mitgezählt), Zeile 2 "davon %d Bank · %d Entzaubern · noch nicht exportiert" (Teile nur, wenn
  zutreffend), Knopf "Öffnen" -> `ns.ShowPage("awards")` mit dem neuesten Raid gewählt.
- Raider: Titel "Deine Items letzte Nacht", Zahl der eigenen Items, Knopf "Öffnen".

### Raids-Seite

Details zeigen Vergaben als "Item an Name (MS)", Bank/Entzaubern als "Item: Bank (Name)" bzw.
"Item: entzaubert (Name)", Notizen in Klammern; gelöschte fehlen.

## Vergabe-Dialog und Alt+Shift-Klick (AwardDialog.lua)

Eigenes Fenster `AmisiaAwardDialog`, 380 x 230, FULLSCREEN_DIALOG, Escape schließt.

```
Vergabe                                                     [x]
[Icon] Fluchsicht des Sargeras            Raid: Schwarzer Tempel, 02.10.
Gewinner [Fraktur              v]   Art [MS] [OS] [SR] [-]
Notiz    [                                   ]
Roll: Fraktur 87 (MS) · +1: 2
[Vergeben]  [Bank]  [Entzaubern]                       [Abbrechen]
```

- **Öffnen:** Alt+Shift-Klick auf einen Item-Link (Lootfenster, Taschen, Chat-Link; Hook auf
  `HandleModifiedItemClick`, nur in der Offiziersansicht und mit `awards.modClick`), der Knopf
  "Hinzufügen" der Seite (Item-Feld leer: W.LineEdit nimmt einen Link per Shift-Klick über einen
  Hook auf `ChatEdit_InsertLink`, falls vorhanden, oder eine Item-ID), `/amisia award` ohne Item.
  Der bestehende Alt-Klick startet nur noch einen Roll, wenn Shift nicht gedrückt ist.
- **Vorbelegung:** Gibt es für das Item eine beendete Runde mit Gewinner (`ns.CurrentRoll`/
  `ns.LastRoll`, 10 Minuten), steht dieser als Gewinner und seine Art (`ns.RollKind`) drin, die
  Roll-Zeile zeigt Wurf und +1. Sonst ist der Gewinner leer und "Vergeben" gesperrt, bis einer
  gewählt ist. Es wird nie automatisch vergeben: Alt+Shift öffnet immer den Dialog.
- **Vergeben:** liegt das Item im offenen Lootfenster und Master Loot ist möglich, geht es über
  `ns.AwardFromRoll` an den Kandidaten; die Bestätigung schreibt die Vergabe wie heute, der Dialog
  gibt Art und Notiz an die wartende Vergabe weiter (`pending[slot].kind/note`). Sonst (Item in
  den Taschen, kein Plündermeister, Lootfenster zu) heißt der Knopf "Eintragen" und schreibt die
  Vergabe direkt (`manual = true`) in den gewählten Raid; die Übergabe (Handeln) macht der Offizier
  selbst.
- **Bank / Entzaubern:** mit Lootfenster und eingetragenem `awards.bankName` bzw. `awards.deName`,
  der Kandidat ist: Master Loot an diesen Charakter, die Bestätigung markiert `to`. Sonst wird die
  Vergabe direkt als Bank/Entzaubern eingetragen (Empfänger "-") und ein Hinweis sagt, dass das
  Item noch im Lootfenster bzw. in den Taschen liegt.
- **Namensliste:** `s.members` des Raids, Raidliste (`GetRaidRosterInfo`), Master-Loot-Kandidaten
  des Slots; jeder Wert durch `ns.Plain`, doppelte über `ns.SameName` zusammengefasst.

## Plus-Eins

- `ns.PlusCount(name, scope)`: Zahl der lebenden Vergaben mit `to = "player"`, `kind = "MS"` und
  `ns.SameName(a.name, name)`; Bereich `raid` = die laufende Aufnahme (sonst der neueste Raid),
  `week` = alle Raids mit `s.start >=` Beginn der ID-Woche. Beginn der ID-Woche:
  `time() + C_DateAndTime.GetSecondsUntilWeeklyReset() - 7 * 86400`; fehlt die Funktion, gilt
  `raid` und der Tooltip der Einstellung sagt das.
- Anzeige: Roll-Fenster (Spalte Art "MS +2"), Rolls-Seite (Gewinner "(MS, +2)"), Vergaben-Seite
  (Spalte +1), Vergabe-Dialog.
- Reihenfolge (`awards.plusOrder`, Standard aus): innerhalb des Rangs MS sortiert `ns.RollRanking`
  zuerst nach weniger Plus-Eins, dann nach Wurf, dann nach Zeit. SR bleibt vorn, OS unberührt. Der
  Gleichstand in `finish()` verlangt dann zusätzlich gleiche Plus-Eins-Zahl. Die Zahl wird beim
  Start der Runde je Name eingefroren (`r.plus[name]`), damit eine Vergabe während der Runde die
  Reihenfolge nicht verschiebt; die Ansage nennt sie mit ("Gewinner: Fraktur (87, MS, +1)").

## Einstellungen

Neuer Abschnitt `ns.RegisterSettings{ key = "awards", label = "Vergaben", order = 25, officer = true }`:

| Pfad | Typ | Standard | Text |
|---|---|---|---|
| awards.plusScope | choice raid/week | raid | "Plus-Eins zählt" : "Dieser Raid" / "Diese ID-Woche" |
| awards.plusOrder | toggle | aus | "Plus-Eins in der Roll-Reihenfolge" (Tip: weniger +1 gewinnt vor höherem Wurf, nur bei MS) |
| awards.modClick | toggle | an | "Alt+Shift-Klick auf ein Item öffnet die Vergabe" |
| awards.bankName | text | "" | "Bank-Charakter" (Tip: Master Loot an diesen Namen zählt als Bank) |
| awards.deName | text | "" | "Entzauberer" (Tip: Master Loot an diesen Namen zählt als Entzaubern) |

Die beiden Textfelder laufen durch `ns.FullName`; `validate` lehnt Ziffern und mehr als ein
Leerzeichen ab. Pages/Settings.lua bekommt dafür den Zeilentyp `text` (W.LineEdit, 150 px,
übernimmt bei Enter/Verlassen, Fehlergrund im Chat wie bei `time`).

## Befehle

| Befehl | Ansicht | Wirkung |
|---|---|---|
| `/amisia vergaben` (Alias `awards`) | alle | Seite Vergaben öffnen |
| `/amisia award <Name\|bank\|de> <Item-Link\|ID> [ms\|os\|sr]` | Offiziere | wie heute; `bank`/`de` tragen Bank bzw. Entzaubern ein; ohne Item öffnet der Dialog |
| `/amisia unaward` | Offiziere | neueste Vergabe der Aufnahme löschen (rückgängig machbar) |
| `/amisia rueckgaengig` (Alias `undo`) | Offiziere | letzte Änderung an Vergaben zurücknehmen |
| `/amisia plus [Name]` | Offiziere | Plus-Eins aller Gewinner im Bereich, oder eines Namens, im Chat |

Schnellmenü (Minimap, Offiziersansicht): Eintrag "Vergaben".

## Fehlerbehandlung

- Seite und Dialog bauen in `pcall` wie alle Seiten. `EditAward`/`DeleteAward` auf eine Kennung,
  die es nicht mehr gibt (Raid inzwischen gelöscht), geben `nil, "Vergabe nicht mehr vorhanden."`.
- Notizen: `|` und Zeilenumbrüche werden entfernt, auf 60 Zeichen gekürzt.
- Ein Rückgängig-Schritt, dessen Raid gelöscht wurde, wird übersprungen.
- Fehlende APIs (`HandleModifiedItemClick`, `ChatEdit_InsertLink`, `C_DateAndTime`,
  `issecretvalue`, `GiveMasterLoot`): Typprüfung, die Funktion fällt still weg bzw. auf "Eintragen"
  zurück.

## Tests

Lua (`addon/tests`, Stub: `math.random` fest, `C_DateAndTime.GetSecondsUntilWeeklyReset` über
`STUB.weekReset`, `issecretvalue` über `STUB.secret`, `ChatEdit_InsertLink`, `GetMasterLootCandidate`
mit Liste):

- `test_award_book.lua`: Kennung eindeutig und fest; `AddAwardTo` in einen alten Raid ändert
  `s.last` nicht und erfindet keine Anwesenheit; `EditAward` Name (setzt `orig` einmal, `edited`),
  Art, Notiz (bereinigt, gekürzt), `to`; `DeleteAward` nach `s.gone`, `RestoreAward` an die richtige
  Stelle; Rückgängig für add/edit/delete und Stapelgrenze 20; `/amisia unaward` ist rückgängig zu
  machen; `ns.NameSuggestions` und `ns.RenameAwards`; Master Loot an `awards.bankName` wird Bank.
- `test_award_migrate.lua`: Daten aus 1.4 (Vergaben ohne `id`) bekommen feste Kennungen und
  `to = "player"`; ein vorher exportierter Raid bleibt "done", ein geänderter bleibt "changed";
  zweimal laden ändert nichts.
- `test_plusone.lua`: zählt nur lebende MS an Spieler; Bereich Raid und Woche (Raid vor dem
  Wochenbeginn zählt nicht); ohne `C_DateAndTime` gilt Raid; Reihenfolge mit und ohne
  `awards.plusOrder`; SR bleibt vorn; ungleiche Plus-Eins sind kein Gleichstand; eingefrorene Zahl.
- `test_export.lua` (ergänzt): `A`-Zeile byte-gleich zu 1.4; `AX` direkt nach jeder `A`/`AS`;
  `AS` für Bank/Entzaubern statt `A`; `AD` für Grabsteine; Items in `N`; Hash ändert sich bei
  Notiz, Löschen, Rückgängig.
- `test_award_page.lua`: Seite baut in Offiziers- und Raider-Ansicht; Raid-Auswahl, "Alle Raids",
  Suche; Bearbeiten wirkt und Rückgängig stellt her; Namenshinweis erscheint nur bei fremdem Namen;
  Karte zeigt Bank/Entzaubern und der Knopf öffnet die Seite.
- `test_award_dialog.lua`: Alt+Shift öffnet den Dialog mit dem Rundengewinner, Alt allein startet
  weiter einen Roll, Alt+Shift startet keinen; mit Lootfenster ruft "Vergeben" `GiveMasterLoot` mit
  dem Kandidaten, ohne schreibt "Eintragen" direkt; "Bank" mit Kandidat geht über Master Loot, ohne
  trägt ein; geheime Namen (`STUB.secret`) fehlen in der Liste; Raider-Ansicht öffnet nichts.
- `test_rolls.lua` (ergänzt): eine geheime Wurfzeile wird ignoriert, ohne Fehler.

Python/Node (`tools/tests`):

- `test_export_format.py`: Zeilenarten mit ein bis zwei Buchstaben auf beiden Seiten; die echte
  Aufnahme exportiert eine geänderte Vergabe mit Notiz, eine Bank-Vergabe und eine gelöschte; der
  Seiten-Parser liest `uid`, `orig`, `note`, `away`, `gone`; ein Export aus 1.4 (ohne neue Zeilen)
  liest sich wie bisher.
- `test_award_import.py` mit `site_awards.cjs` (schneidet `glResolve`, `amAwardRows`,
  `amGoneRows`, `amApplyAwardChanges`, `importSig`, `forgetImport` aus `index.html`, Stubs für
  `$('#glDups')`, `ITEM`, `BOSSES`, `state`): erneuter Import ist `dup`; neuerer Empfänger ist
  `change` und verschiebt; älterer `amEdited` überschreibt eine Änderung auf der Seite nicht; `AD`
  entfernt und landet in `dropped`; Vergabe aus 1.4 ohne `am` bekommt die Kennung per `fill`; der
  zweite Aufnehmende mit altem Gewinner wird "Removed"; `AS` legt keinen Raider an und landet in
  `lootAway`.
- Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review).

## Vorschlag für den Plan (8 Aufgaben)

1. Vergabebuch und Umzug (Awards.lua, Core-Hilfen, `s.gone`, Stapel) mit `test_award_book.lua`,
   `test_award_migrate.lua`.
2. Export `AX`/`AS`/`AD`, `SessionHash(s, legacy)`, `test_export.lua`, `site_parser.cjs`-Muster.
3. Website: amParse, amAwardRows, glResolve, amGoneRows, amApplyAwardChanges, lootAway,
   Nachtansicht; `site_awards.cjs`, `test_award_import.py`, `test_export_format.py`; Twin.
4. Plus-Eins: `ns.PlusCount`, Ranking, Gleichstand, Anzeige in Roll-Fenster und Rolls-Seite,
   Abschnitt "awards" der Einstellungen; `test_plusone.lua`, geheime Wurfzeile.
5. Widgets `W.Picker`, `W.LineEdit`, Einstellungszeile `text`; Tests in `test_widgets.lua`.
6. Seite Vergaben, Raider-Ansicht, Karte, Raids-Details, Schnellmenü; `test_award_page.lua`.
7. Vergabe-Dialog, Alt+Shift-Klick, Bank/Entzaubern über Master Loot, `ns.Plain`, Befehle;
   `test_award_dialog.lua`.
8. Version 1.5.0 (TOC, `ns.VERSION`), `tools/release_addon.sh`, ZIP gegen die TOC prüfen,
   Twin veröffentlichen und stempeln, unabhängige Prüfung.

## Auslieferung

Version 1.5.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh` (füllt den Release-Ordner, den Syncthing sendet). Im Spiel danach `/reload`.

## Ideen aus der Recherche

Übernommen:
- Vergabe per Modifier-Klick aus Lootfenster, Taschen und Chat-Link (Alt+Shift öffnet den Dialog,
  vorbelegt mit dem Rundengewinner). Bewusst ohne Sofort-Vergabe ohne Dialog.
- Feste Kennung je Vergabe, damit die Seite erneute Importe erkennt, Änderungen übernimmt und
  Löschungen nachzieht.
- Zeitstempel: Epoch-Sekunden bleiben, wie sie sind; neu nur `edited` und `deleted`.
- Durchsuchbarer Verlauf über alle gespeicherten Raids nach Spieler, Item, Quelle, Notiz.
- "Namen korrigieren", wenn ein Gewinner nicht in der Anwesenheit steht (Forever-Nachnamen,
  Tippfehler), einzeln oder für alle Vergaben dieses Namens.

Später:
- Verlauf über `record.keepSessions` hinaus (eigenes Archiv) - die Website ist die Historie.
- Vergabe im Handelsfenster bei Gruppenplündern mit 2-Stunden-Handelsfrist (eigener Baustein).
- Würfe von Hand eintragen, wenn der Chat im Bosskampf geheim ist (Baustein 4, Loot-Ansage).
- Vergaben und Plus-Eins zwischen Offizieren und für Raider abgleichen (Baustein 7, Sync).

## Nicht in Baustein 5

Loot-Ansage beim Öffnen des Lootfensters, SR-Erinnerung und `!sr` (Baustein 4); Würfe von Hand;
Bosskills, Ersatzbank, Discord-Text (Baustein 6); BiS-Abgleich (3); Karte (2); Sync, Versionscheck
und das Teilen von Vergaben mit Raidern (7); Prioritätsliste und Loot-Rat-Notizen; Raider-Fenster
mit MS/OS/Passen statt `/roll`; Vergabe im Handelsfenster; Archiv über die gespeicherten Raids
hinaus; Plus-Eins auf der Website.

## Offene Punkte

- Ob Alt+Shift-Klick im Lootfenster, in den Taschen und im Chat auf beiden Clients bei
  `HandleModifiedItemClick` ankommt, ohne dass der Client zuerst den Link in die Chat-Eingabe setzt
  (Shift = CHATLINK). Im Spiel prüfen; fällt es aus, bleibt der Dialog über Seite und Befehl.
- Ob `GiveMasterLoot` auf Forever während der Kampfsperre eines Bosses erlaubt ist (der Dialog fällt
  sonst auf "Eintragen" zurück). Prüfen mit `/dump C_RestrictedActions.IsAddOnRestrictionActive(1)`
  im Bosskampf.
- Ob `C_DateAndTime.GetSecondsUntilWeeklyReset` auf TBC Anniversary und Forever die Raid-ID-Woche
  liefert.
- Entschieden: SR-Gewinne zählen nicht als Plus-Eins, nur MS (die Reservierung ist schon der Vorrang).
