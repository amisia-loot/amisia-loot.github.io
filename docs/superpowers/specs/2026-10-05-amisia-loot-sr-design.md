# Amisia 1.6: Loot-Ansage und SR-Check

Stand 2026-10-05. Baustein 4 von 7 (Reihenfolge der Umsetzung laut Nutzer: 5, 4, 6, 3, 2, 7).
Baut auf Baustein 1 (`docs/superpowers/specs/2026-10-04-amisia-main-window-design.md`: Registry,
Widgets, Hauptfenster, Seiten) und Baustein 5 (`docs/superpowers/specs/2026-10-05-amisia-awards-design.md`:
Vergabebuch, Vergabe-Dialog, `ns.Plain`, W.Picker, W.LineEdit) auf. Ändert nur das Addon
`addon/Amisia`. Export, Seite `index.html` und Twin bleiben unberührt.

## Ziel

Heute kennt Amisia die Soft-Reserves nur als Tabelle, als Tooltip-Zeile und als "SR" im
Lootfenster; ob die Liste zum Raid passt, sieht man nur an der Zeile "im Raid ohne Reserve".
Baustein 4 bringt die Reservierungen dahin, wo vergeben wird:

- **Loot-Ansage:** öffnet der Plündermeister eine Leiche, stehen die Items mit Link und den
  Reservierenden einmal im Schlachtzugschat. Bei Gruppenplündern dasselbe aus den Würfelfenstern,
  und die Würfelfenster reservierter Items tragen ein "SR".
- **SR-Check:** die geladene Liste wird mit dem Raid abgeglichen (ohne Reserve, nicht im Raid,
  unklare Namen, zu viele Reservierungen), schon in der Vorschau vor dem Import. Unklare Namen
  lassen sich mit einem Klick korrigieren, die Korrektur gilt auch für die nächste Liste.
- **SR-Erinnerung und `!sr`:** Raider ohne Reserve bekommen auf Knopfdruck eine Flüsterung; wer
  das Addon nicht hat, fragt mit `!sr` nach seinen Reservierungen oder mit `!sr <Item>`, wer ein
  Item reserviert hat.
- **Würfe von Hand:** ist der Chat im Bosskampf geheim (Forever), trägt der Plündermeister Würfe
  im Roll-Fenster selbst ein; eine Runde, die in dieser Zeit läuft, sagt das.
- **Tooltip:** die Zeile "Reserviert" zeigt nur noch Reservierende aus der Gruppe, mit Anzahl.

Alles, was in den Chat schreibt, läuft über eine gemeinsame Warteschlange mit Drosselung, die
während der Chat-Sperre wartet.

## Rahmen und Entscheidungen

- **Clients, Bibliotheken, Schrift, Fensterebenen, Offiziersansicht:** wie Baustein 1 und 5. Ein
  TOC (`20506, 16001`), keine fremden Bibliotheken, kein `UIDropDownMenu`/`EasyMenu`, UI- und
  Chat-Texte deutsch und nur Latin-1 (ä ö ü ß und "·", kein Gedankenstrich, keine
  Auslassungspunkte, keine Pfeile), Code-Kommentare englisch. Anmeldung nur über
  `ns.RegisterPanel`, `ns.RegisterCard`, `ns.RegisterSettings`, `ns.RegisterSlash`;
  Offiziersteile über `ns.IsOfficerView()`.
- **Keine anderen Addons nennen**, weder in UI-Texten, Chat-Texten, Kommentaren noch Commits. Im
  Entwurf heißen sie "andere Loot-Addons".
- **Wer ansagt und antwortet:** genau einer pro Raid, ohne Sync (Baustein 7). Die "Lootleitung"
  (`ns.IsLootLead()`) ist bei Master Loot der Plündermeister, sonst der Schlachtzugsleiter.
  Zusätzlich muss Amisia in der Offiziersansicht laufen. Die Einstellung `loot.lead = "me"` macht
  den eigenen Client zur Lootleitung, wenn der Leiter das Addon nicht hat. So posten zwei
  Offiziere mit Amisia nicht doppelt.
- **Nur im Schlachtzug.** In einer 5er-Gruppe gibt es keine Ansage und keine `!sr`-Antwort; der
  SR-Check läuft auch ohne Gruppe gegen den letzten Raid.
- **Einmal pro Leiche:** die Ansage merkt sich die Quelle (`GetLootSourceInfo`, sonst das Ziel).
  Ist die GUID geheim oder fehlt, gilt die sortierte Item-Liste als Schlüssel für 10 Minuten.
  Gemerkt wird in der laufenden Aufnahme (`s.announced`), damit ein `/reload` nicht doppelt
  ansagt. `s.announced` steht nicht im Export und nicht im Hash.
- **Materialien und ignorierte Items** (`ns.MATS`, `ns.IGNORE`) werden nie angesagt: sie gehen nach
  Hausregel an die Gildenbank.
- **Chat-Sperre (Forever):** `C_ChatInfo.InChatMessagingLockdown()` ist die Quelle der Wahrheit
  (auf beiden Clients vorhanden, Anniversary liefert vermutlich immer false). Während der Sperre
  sind `CHAT_MSG_SYSTEM`, `CHAT_MSG_RAID`, `CHAT_MSG_WHISPER` geheim; eingehende Zeilen werden über
  `ns.Plain` erkannt und übersprungen. Geheime Absender lassen sich auch nach dem Kampf nicht mehr
  verwenden, deshalb merkt Amisia sich keine geheimen Anfragen, sondern nur eigene ausgehende
  Zeilen, und schickt sie nach der Sperre. `SendChatMessage` liefert auf beiden Clients keinen
  Rückgabewert (Doku geprüft); ob ein Versand während der Sperre durchgeht, lässt sich nicht
  erkennen. Darum wird in der Sperre gar nicht gesendet, sondern gewartet.
- **Antworten auf `!sr` immer per Flüsterung** an den Absender, auch wenn im Schlachtzugschat
  gefragt wurde. Geantwortet wird an den Absender-Text, wie der Client ihn liefert (nicht an einen
  nachgebauten Namen), damit Forever-Namen mit Nachnamen ankommen.
- **Namen korrigieren statt raten:** der Abgleich vergleicht über `ns.SameName`. Was ohne Nachnamen
  passt, zählt als gefunden, wird aber als "ohne Nachnamen" vorgeschlagen; was sich um höchstens
  zwei Zeichen unterscheidet, wird nur vorgeschlagen. Korrigiert wird erst auf Klick.
- **Roll-Reihenfolge:** `rankOf` prüft eine Reservierung künftig zuerst exakt, dann über
  `ns.SameName` gegen `r.reserved`. Heute verliert "Vulo" aus der Liste den Vorrang, wenn der Wurf
  als "Vulo Sturmwind" ankommt.
- **Kein Ausbau der Website.** Reservierungen und der Abgleich bleiben im Spiel; die Seite liest
  Soft-Reserves weiter über ihren eigenen Import.

## Dateien

```
addon/Amisia/Chat.lua            NEU: Warteschlange mit Drosselung, Chat-Sperre, ns.Say, eingehende
                                 !-Befehle (ns.RegisterChatCommand), Zeilen teilen (ns.ChatLines)
addon/Amisia/Core.lua            ns.Announce schreibt über ns.Say; ADDON_LOADED ruft ns.MigrateSoftRes
addon/Amisia/SoftRes.lua         Datenmodell 2 (Anzahl je Name, Namenskorrekturen), Umzug,
                                 ns.SoftResCheck, ns.SoftResRoster, ns.RenameReserve, ns.ReservesOf,
                                 Tooltip nur Gruppe, !sr, Erinnerung, Zusammenfassung,
                                 Import-Fenster mit Vorschau; Einstellungen, Befehl "sr" mit Unterwörtern
addon/Amisia/LootAnnounce.lua    NEU: ns.IsLootLead, Ansage aus LOOT_OPENED und START_LOOT_ROLL,
                                 SR-Marke an den Würfelfenstern, Einstellungen "loot", /amisia ansage
addon/Amisia/Rolls.lua           rankOf mit SameName; ns.AddManualRoll, ns.RollDecide,
                                 ns.AnnounceRollResult; r.lockdown, r.hidden; Countdown mit kurzer
                                 Gültigkeit; /amisia wurf
addon/Amisia/RollFrame.lua       Zeile "Wurf eintragen" (Name, Wurf, MS/OS), Hinweis Bosskampf,
                                 Knopf "Ergebnis ansagen", Marke "Hand" in der Liste
addon/Amisia/Pages/SoftRes.lua   Abgleich, Ansichten Items/Raider/Abgleich, Knöpfe Erinnern und
                                 Im Raid posten, Namen korrigieren; Karte mit Abgleich
addon/Amisia/Pages/Rolls.lua     Bosskampf-Hinweis, "n von Hand" in der Rundenzeile
addon/Amisia/Amisia.toc          Chat.lua nach Names.lua, LootAnnounce.lua nach SoftRes.lua;
                                 Version 1.6.0
addon/tests/*                    neue Tests, Stub ergänzt
```

## Datenmodell

### Soft-Reserves (`AmisiaDB.softres`)

Bisher `{ date, byItem = { [item] = { names } }, raw, count }`. Neu:

```lua
AmisiaDB.softres = {
  version = 2,                          -- NEU
  date = "2026-10-05", raw = "...", count = 41,   -- count: Reservierungen inklusive Mehrfacher
  byItem = { [32235] = { "Fraktur", "Vulo Sturmwind" } },   -- wie bisher: Namen, eindeutig, sortiert
  times = { [32235] = { ["Vulo Sturmwind"] = 2 } },          -- NEU: nur Einträge mit mehr als 1
  renamed = { ["Vulo Sturmwind"] = "Vulo" },                  -- NEU: korrigierter Name -> wie in der Liste
  reminded = { ["Chorf"] = 1759690000 },                      -- NEU: wer schon erinnert wurde (Epoch)
}
AmisiaDB.srAliases = { ["vulo sturmwnd"] = "Vulo Sturmwind" } -- NEU: Korrekturen für jede Liste
```

- `ns.ParseSoftRes(text)` zählt doppelte Zeilen (gleicher Name, gleiches Item) in `times`, statt sie
  zu verwerfen, und wendet `AmisiaDB.srAliases` nach `shortName` an (Schlüssel klein geschrieben).
  Rückgabe wie bisher plus `times`. `byItem` bleibt in Form und Inhalt gleich, damit `ns.ReservedBy`,
  Tooltip, Lootmarke und Rolls unverändert lesen.
- `renamed` merkt die Korrekturen der geladenen Liste für die Anzeige ("Vulo Sturmwind, in der Liste
  Vulo"); `reminded` wird bei jedem neuen Import geleert.

**Umzug** (`ns.MigrateSoftRes(DB)`, aus Core beim `ADDON_LOADED` nach `ns.MigrateAwards`): fehlt
`softres.version`, dann `times = {}`, `renamed = {}`, `reminded = {}`, `version = 2`.
`DB.srAliases = DB.srAliases or {}`. Nichts geht verloren; zweimal laden ändert nichts. Eine
Liste aus 1.5 behält ihre Namen, Doppelte waren dort schon zusammengefasst und zählen einfach.

### Rolls

Runde (nur im Speicher, wie bisher) bekommt:

```lua
r.lockdown = true      -- Runde lief ganz oder teilweise in der Chat-Sperre
r.hidden = 3           -- geheime Systemzeilen während der Runde (nicht alle sind Würfe)
r.dirty = true         -- nach dem Ende von Hand geändert, Ergebnis noch nicht angesagt
e.manual = true        -- Wurf von Hand eingetragen (rolls[name])
```

### Aufnahme

`s.announced = { [key] = epoch }` in der laufenden Aufnahme, Schlüssel `"g:" .. guid`,
`"r:" .. rollID .. ":" .. epoch-Minute` oder `"i:" .. sortierte Item-IDs`. Einträge älter als
12 Stunden fallen beim Schreiben raus.

## Chat (Chat.lua)

```lua
ns.Say(text, chan, target, opts) -> "sent" | "queued" | nil, Grund
    -- chan: "RAID" | "RAID_WARNING" | "PARTY" | "WHISPER"; opts.ttl: Sekunden, nach denen eine
    -- wartende Zeile verfällt (Standard 600); opts.key: gleiche Schlüssel ersetzen sich in der Schlange
ns.ChatLocked() -> bool                -- C_ChatInfo.InChatMessagingLockdown(), fehlt sie: false
ns.ChatQueueSize() -> n
ns.ChatLines(head, parts, sep) -> { lines }   -- teilt eine Liste auf Zeilen mit höchstens 250 Bytes
ns.RegisterChatCommand(word, fn(sender, rest, chan))   -- "!word" im Flüstern, Raid- und Gruppenchat
```

- **Drosselung:** Vorrat 2000 Bytes, Nachfüllen 800 Bytes pro Sekunde (bekannte sichere Werte).
  Ist Vorrat da und keine Sperre, geht die Zeile sofort und synchron raus (so bleiben bestehende
  Tests, die `STUB.chat` direkt nach `ns.Announce` lesen, grün). Sonst wartet sie; ein Ticker
  (0,25 s) läuft nur, solange die Schlange nicht leer ist.
- **Zeilenlänge:** über 255 Bytes wird vor dem Senden am letzten Leerzeichen gekürzt; Links werden
  nie zerschnitten (`ns.ChatLines` setzt Teile nur ganz).
- **Sperre:** `ns.ChatLocked()` hält die ganze Schlange an. Freigabe bei
  `ADDON_RESTRICTION_STATE_CHANGED` und spätestens beim nächsten Tick (Prüfung alle 2 s, falls das
  Ereignis fehlt). Zeilen mit abgelaufener `ttl` fallen beim Freigeben raus; der Countdown eines
  Rolls hat `ttl = 3`, Loot-Ansagen `600`, Flüsterungen `120`.
- **Grenze:** höchstens 40 wartende Zeilen; darüber wird die neue Zeile abgelehnt und einmal pro
  Minute "Amisia: Chat-Warteschlange voll, Zeilen verworfen." im eigenen Chat gemeldet.
- `RAID_WARNING` ohne Leiter- oder Assistentenrecht wird zu `RAID`, `RAID` ohne Raid zu `PARTY`,
  ohne Gruppe verworfen (wie `ns.Announce` heute).
- Senden über `C_ChatInfo.SendChatMessage` oder das globale `SendChatMessage` wie heute, in `pcall`.
- **Eingehende Befehle:** Handler auf `CHAT_MSG_WHISPER`, `CHAT_MSG_RAID`, `CHAT_MSG_RAID_LEADER`,
  `CHAT_MSG_PARTY`, `CHAT_MSG_PARTY_LEADER`. Text und Absender gehen durch `ns.Plain`; ist eins
  geheim, wird die Zeile still übersprungen. Erkannt wird `^!(%a+)%s*(.-)%s*$`, ohne Groß/Klein.
  Eigene Zeilen werden ignoriert.

`ns.Announce(text, ttl)` behält seine Kanalwahl und schreibt über `ns.Say`.

## Loot-Ansage (LootAnnounce.lua)

### Lootleitung

```lua
ns.IsLootLead() -> bool
```

- Nur im Raid und in der Offiziersansicht. `loot.lead = "me"`: immer true.
- `auto`: `C_PartyInfo.GetLootMethod()` (beide Clients, Doku geprüft: `method, masterLootPartyID,
  masterLooterRaidID`, `Enum.LootMethod.Masterlooter = 2`); fehlt sie, das globale `GetLootMethod`
  ("master"). Bei Master Loot: true, wenn `UnitIsUnit("raid" .. masterLooterRaidID, "player")`
  (bzw. `masterLootPartyID == 0`). Sonst: `UnitIsGroupLeader("player")`.

### Master Loot und eigenes Plündern (LOOT_OPENED)

- Bei `LOOT_OPENED` (auf Forever nicht, wenn das zweite Argument `isFromItem` true ist) und
  `loot.announce`, `ns.IsLootLead()`: alle Slots mit `ns.LinkQuality(link) >= loot.quality`, ohne
  `ns.MATS`/`ns.IGNORE`, ohne Behälter aus den Taschen (Quelle `Item-...`, wie in Core).
- Pro Quelle eine Ansage, wenn ihr Schlüssel noch nicht in `s.announced` steht (ohne laufende
  Aufnahme: Tabelle im Speicher).
- Format (Kanal `RAID`, `ttl` 600):

```
Amisia Loot (Illidan Sturmgrimm): 3 Items
1. [Fluchsicht des Sargeras] SR: Fraktur, Vulo Sturmwind x2
2. [Kriegsklinge von Azzinoth] frei
3. [Schulterpolster der ewigen Gnade] SR: Chorf (+1 nicht im Raid)
```

  Quelle über `ns.LootSourceName`, durch `ns.Plain`; ist sie "?" oder geheim, fehlt die Klammer.
  Reservierende nur aus dem Raid (`ns.SameName`), Anzahl über `times`; wer reserviert hat und nicht
  im Raid ist, steht nur als "+n nicht im Raid". Höchstens 8 Item-Zeilen, dann "und n weitere".
- `loot.warning` (aus): zusätzlich eine Schlachtzugswarnung "Loot: 3 Items, 2 reserviert. Liste im
  Schlachtzugschat." (nur mit Leiter- oder Assistentenrecht, sonst entfällt sie).
- `/amisia ansage` (Alias `announce`) sagt das offene Lootfenster erneut an, ohne Schlüsselprüfung.

### Gruppenplündern (START_LOOT_ROLL)

- Bei `START_LOOT_ROLL(rollID, rollTime)` (beide Clients, Doku geprüft) und `loot.groupLoot`,
  `loot.announce`, `ns.IsLootLead()`: Link über `GetLootRollItemLink(rollID)` (Typprüfung; fehlt sie,
  keine Ansage), Qualitätsgrenze wie oben. Würfe, die innerhalb von 1,5 s beginnen, werden zu
  einer Ansage gesammelt (eine Leiche): Kopf "Amisia Würfeln: 2 Items", Zeilen wie oben, Schlüssel
  je `rollID`.
- **SR-Marke an den Würfelfenstern** (`softres.lootMark`, für alle, nicht nur die Lootleitung):
  `HookScript("OnShow")` an `GroupLootFrame1` bis `GroupLootFrame<NUM_GROUP_LOOT_FRAMES or 4>`. Beide
  Clients haben diese Frames mit `self.rollID` (Anniversary `Blizzard_UIPanels_Game/Classic/LootFrame.lua`,
  Forever `Mainline/GroupLootFrame.lua`). Ist das Item reserviert, zeigt ein goldenes "SR" oben links
  am Icon; reserviert der Spieler selbst, "SR (du)". Die Namen stehen im Item-Tooltip des Icons,
  der über `SetLootRollItem` ohnehin durch den Tooltip-Hook läuft. Hook nur auf `OnShow` per
  `HookScript`, kein Ersetzen von Blizzard-Funktionen; fehlt ein Frame, entfällt die Marke.

## SR-Check (SoftRes.lua)

```lua
ns.SoftResRoster() -> names, label
    -- im Raid: Raidliste (GetRaidRosterInfo, ns.Plain, ns.FullName), label "Raid (25)";
    -- sonst die laufende Aufnahme oder der neueste Raid (s.members), label "letzter Raid, 02.10.";
    -- ohne beides: {}, nil
ns.SoftResCheck(sr?, roster?) -> {
    roster = n, reservers = n, ok = { names },
    missing = { names },                       -- im Raid, ohne Reservierung
    absent  = { names },                       -- reserviert, nicht im Raid
    unclear = { { name, kind = "surname"|"typo", suggest = { names } } },
    over    = { { name, n } },                 -- mehr als softres.limit (nur wenn > 0)
    multi   = { { name, item, n } } }          -- dasselbe Item mehrfach reserviert (Hinweis)
ns.ReservesOf(name) -> { { item, n } }         -- über ns.SameName
ns.RenameReserve(from, to, remember) -> n      -- in byItem/times, renamed; remember: srAliases
ns.SoftResReminders() -> names                 -- missing ohne Eintrag in reminded
ns.SendSoftResReminders() -> n                 -- Flüsterungen über ns.Say, reminded setzen
ns.PostSoftResSummary()                        -- 1-2 Zeilen in den Schlachtzugschat
```

- **unclear "surname":** Name der Liste ohne Leerzeichen, im Raid genau ein Name mit diesem Vornamen
  (Forever). Zählt als reserviert, Vorschlag ist der volle Name.
- **unclear "typo":** nicht im Raid, aber ein Raidname ohne Reservierung mit Abstand höchstens 2
  (Levenshtein auf Kleinbuchstaben, nur ab 4 Zeichen) oder gleichem Vornamen. Zählt als "nicht im
  Raid", bis korrigiert. Mehrere Vorschläge nach Abstand sortiert, höchstens 3.
- Zu viele: Summe der Reservierungen eines Namens (mit `times`) über `softres.limit`.
- `ns.SoftResCheck` ist reine Rechnung (keine Frames, kein Chat), damit Vorschau, Seite, Karte und
  Befehl dieselbe Antwort zeigen.

### Vorschau vor dem Import

Das Import-Fenster (`AmisiaSoftResFrame`) bekommt über dem Ergebnistext eine Vorschauzeile, die
0,3 s nach der letzten Änderung des Textfelds neu rechnet (`ns.ParseSoftRes` plus
`ns.SoftResCheck` gegen `ns.SoftResRoster()`, nichts wird gespeichert):

```
Vorschau gegen Raid (25): 24 Raider, 41 Reservierungen · 2 ohne Reserve · 3 nicht im Raid · 1 Name unklar
```

Gespeicherte Korrekturen (`srAliases`) wirken schon in der Vorschau. Die Knöpfe heißen künftig
"Übernehmen" und "Leeren" (bisher ohne Umlaut). Korrigiert wird nach dem Import auf der Seite.

### Erinnerung und Zusammenfassung

- **Erinnern** (Offiziere, Seite oder `/amisia sr erinnern`): fragt per StaticPopup
  "%d Raidern ohne Reserve flüstern?", dann je Name eine Flüsterung über `ns.Say` (`ttl` 120):
  "Amisia: Du hast für heute noch nichts reserviert." plus `softres.remindText`, falls gesetzt
  (z. B. der Link zur Liste). Jeder Name einmal pro Liste (`reminded`). Wer auf dem Rückweg
  `!sr` fragt, bekommt die Antwort unten.
- **Im Raid posten** (Offiziere, `/amisia sr posten`): "Soft-Reserves: 22 von 25 haben reserviert.
  Ohne Reserve: Chorf, Anna, Bob." (Namen über `ns.ChatLines`, höchstens 2 Zeilen, Rest "und n
  weitere"). Nur im Raid.
- `/amisia sr pruefen` (Alias `check`): Ergebnis des Abgleichs im eigenen Chat, ohne zu senden.

### `!sr` (Chat-Befehl)

`ns.RegisterChatCommand("sr", ...)`, Alias `softres`. Antwortet nur, wenn `softres.chat` an,
`ns.IsLootLead()` und eine Liste geladen ist; Absender muss in der Gruppe sein (`ns.SameName`
gegen die Raidliste).

| Anfrage | Antwort (Flüsterung) |
|---|---|
| `!sr` | "Amisia: Deine Reservierungen (Liste vom 05.10.): [Item], [Item] x2" oder "Amisia: Du hast nichts reserviert (Liste vom 05.10.)." |
| `!sr <Item-Link>` oder `!sr <Teil des Namens>` | "Amisia: [Item] reserviert von Fraktur, Vulo Sturmwind x2" bzw. "niemand". Name: Teiltext ohne Groß/Klein über `ns.ItemName` der reservierten Items; bei mehreren Treffern die ersten 3 Items in einer Zeile. |

- Grenzen: pro Absender eine Antwort je 15 s (weitere still ignoriert), insgesamt höchstens
  20 Antworten pro Minute; lange Listen auf höchstens 3 Zeilen.
- Ist die Liste älter als `softres.warnDays`, hängt die Antwort "(Liste ist %d Tage alt)" an.
- In der Chat-Sperre kommen die Anfragen geheim an und werden übersprungen; wer im Bosskampf
  fragt, fragt danach noch einmal. Eine vor der Sperre angenommene Antwort wartet in der Schlange.

### Tooltip

- `softres.tooltipGroup` (an): in einer Gruppe nur Reservierende aus der Gruppe, Rest als
  "+n außerhalb"; ohne Gruppe alle. Anzahl als "x2", eigener Name als "du".
  Beispiel: "Reserviert: Fraktur, du x2 (+1 außerhalb)".
- Der Hook bleibt `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` (auf
  beiden Clients vorhanden, `Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua` geprüft; auch
  `SetLootRollItem` und `SetHyperlink` laufen dort durch), sonst `OnTooltipSetItem`. Neu: der Körper
  läuft in `pcall`, damit ein Fehler nie den Tooltip anderer Addons abbricht, und eine Zeile pro
  Tooltip-Aufbau (Merker am Tooltip, gelöscht über `OnTooltipCleared`), damit sie bei doppeltem
  Aufruf nicht zweimal erscheint. Das Item kommt wie heute aus `TooltipUtil.GetDisplayedItem`.

## Würfe von Hand (Rolls.lua, RollFrame.lua)

```lua
ns.AddManualRoll(name, value, kind) -> e | nil, Grund
    -- in die laufende Runde oder in die letzte, beendete Runde (bis 10 Minuten);
    -- kind "MS" (1-100) oder "OS" (1-99); ersetzt einen vorhandenen Wurf desselben Namens
ns.RollDecide(r)            -- Gewinner/Gleichstand aus der Rangfolge, ohne Ansage (finish nutzt es)
ns.AnnounceRollResult(r)    -- sagt Gewinner oder Gleichstand an, löscht r.dirty
```

- Name über `ns.FullName`, muss in der Gruppe oder in `s.members` stehen; Zahl ganz, im Bereich.
  Fehlergründe: "Keine Runde.", "Wurf 1-100 (MS) oder 1-99 (OS).", "%s ist nicht in der Gruppe.".
- Eingetragene Würfe haben `manual = true`, `low = 1`, `high = 100`/`99`, `t` wie ein neuer Wurf.
  Plus-Eins wird wie bei einem Chat-Wurf eingefroren. SR ergibt sich wie bisher aus der Liste.
- In einer beendeten Runde rechnet `ns.RollDecide` neu und setzt `r.dirty`; angesagt wird erst
  über "Ergebnis ansagen" (keine automatische Ansage, der Offizier sammelt erst alle Würfe).
- **Sperre:** `ns.StartRoll` setzt `r.lockdown`, wenn `ns.ChatLocked()`; ein
  `ADDON_RESTRICTION_STATE_CHANGED` während der Runde ebenso. `onSystem` zählt geheime Zeilen in
  `r.hidden`, statt sie nur zu verwerfen. Ansagen der Runde gehen über `ns.Announce` und warten in
  der Sperre; der Countdown verfällt nach 3 s.
- **Roll-Fenster** (Höhe +30): unten eine Zeile

```
[Name           v] [ 87 ] [MS] [OS]  [Eintragen]          [Ergebnis ansagen]
Bosskampf: Würfe im Chat nicht lesbar (3 Zeilen). Würfe von Hand eintragen.
```

  Name über W.Picker (Raidliste und `s.members`, über `ns.Plain`, mit "Anderer Name"), Wurf über
  W.LineEdit (40 px), Art über zwei Chips, Enter im Wurf-Feld trägt ein. Der Hinweis erscheint nur
  bei `r.lockdown`. In der Liste steht hinter dem Wurf eines eingetragenen Namens "Hand".
  "Ergebnis ansagen" ist nur aktiv bei `r.done and r.dirty`.
- `/amisia wurf <Name> <Zahl> [os]` (Offiziere, Alias `addroll`): dasselbe per Befehl; Forever-Namen
  mit Leerzeichen: die Zahl ist das erste rein numerische Wort, alles davor der Name.

## Seite "Soft-Reserves" (Pages/SoftRes.lua)

```
+-----------------------------------------------------------------------------------------+
| Liste vom 05.10.: 41 Reservierungen von 24 Raidern          [Importieren] [Löschen]     |
| Abgleich mit Raid (25): 22 reserviert · 3 ohne · 2 nicht im Raid · 1 unklar · 1 zu viel |
| [Items] [Raider] [Abgleich]                       [Erinnern (3)] [Im Raid posten]       |
| Item                              Reserviert von                                         |
| Fluchsicht des Sargeras           Fraktur, Vulo Sturmwind x2, Anna (nicht im Raid)      |
| ...                                                     (14 Zeilen, Mausrad scrollt)     |
+-----------------------------------------------------------------------------------------+
```

- **Kopf:** Datum, Reservierungen, Zahl der Reservierenden; Warnfarbe ab `softres.warnDays` wie
  heute. Zeile 2 aus `ns.SoftResCheck` mit dem Label aus `ns.SoftResRoster`; ohne Raid und ohne
  Aufnahme "Kein Raid zum Abgleichen.".
- **Ansichten** (Chips, gewählte golden; gemerkt bis zum Ausloggen):
  - **Items:** Item (Qualitätsfarbe, Tooltip beim Überfahren, Shift-Klick fügt den Link in den
    Chat), Reservierende mit "x2", Namen außerhalb des Raids grau mit "(nicht im Raid)".
  - **Raider:** Name (Klassenfarbe aus der Raidliste), Zahl der Reservierungen (rot über
    `softres.limit`), Items als Text. Raider ohne Reserve stehen mit "keine" dabei.
  - **Abgleich** (nur Offiziere): je Befund eine Zeile, sortiert unklar, zu viel, ohne Reserve,
    nicht im Raid, mehrfach. Unklare Namen tragen ihre Vorschläge als Chips ("Vulo Sturmwind");
    ein Klick ruft `ns.RenameReserve(from, to, true)` und merkt die Korrektur für kommende Listen.
    "Ohne Reserve"-Zeilen zeigen "erinnert 20:14", wenn schon geflüstert.
- **Knöpfe** (Offiziere): Importieren, Löschen (wie heute), Erinnern (Zahl der noch nicht
  Erinnerten, gesperrt bei 0 oder ohne Raid), Im Raid posten (gesperrt ohne Raid).
- **Raider-Ansicht:** Ansichten Items und Raider, eigene Zeile golden hervorgehoben, ohne Knöpfe.
  Der Abgleich-Kopf bleibt sichtbar (nur Zahlen).
- Die Seite hört auf `DATA_CHANGED`, `SETTING` und `GROUP_ROSTER_UPDATE` (über `ns.OnEvent`,
  Refresh nur solange sichtbar, wie alle Seiten).

### Karte "Soft-Reserves"

- Zeile 1 wie heute ("41 Reservierungen, vom 05.10.").
- Zeile 2 aus dem Abgleich: "22 von 25 im Raid reserviert · 1 Name unklar" (Teile nur, wenn
  zutreffend); ohne Raid "Abgleich mit letztem Raid: 3 ohne Reserve".
- Knopf "Ansehen"; in der Offiziersansicht mit unklaren Namen "Prüfen" (öffnet die Ansicht Abgleich).

### Seite "Rolls"

Laufende Runde zeigt zusätzlich "Bosskampf, 3 Zeilen nicht lesbar" bei `r.lockdown`; die
Rundenzeile nennt "2 von Hand", wenn eingetragene Würfe dabei sind. Hinweistext ergänzt:
"Im Bosskampf Würfe im Roll-Fenster von Hand eintragen."

## Ereignisse und APIs je Client

Geprüft in Gethe/wow-ui-source, Zweige `classic_anniversary` und `forever`.

| API / Ereignis | Anniversary 2.5.6 | Forever 1.60.1 | Verwendung |
|---|---|---|---|
| `LOOT_OPENED` | `autoLoot` | `autoLoot, isFromItem` | Ansage (ML), `isFromItem` überspringen |
| `START_LOOT_ROLL` | `rollID, rollTime, lootHandle` | gleich | Ansage bei Gruppenplündern |
| `GroupLootFrame1-4`, `.rollID` | ja (Classic/LootFrame.lua) | ja (Mainline/GroupLootFrame.lua) | SR-Marke per `HookScript("OnShow")` |
| `GetLootRollItemLink` | Altes Global, nicht in der Doku | nicht in der Doku | Typprüfung, sonst keine Ansage |
| `C_PartyInfo.GetLootMethod` | ja, Enum `Masterlooter = 2` | ja | Lootleitung |
| `C_ChatInfo.InChatMessagingLockdown` | ja | ja | Sperre |
| `ADDON_RESTRICTION_STATE_CHANGED` | ja | ja | Schlange freigeben, `r.lockdown` |
| `CHAT_MSG_SYSTEM/RAID/WHISPER(_INFORM)` | ohne Kennzeichen | `SecretInChatMessagingLockdown` | `ns.Plain`, überspringen |
| `C_ChatInfo.SendChatMessage` | fehlt (Global) | ja, kein Rückgabewert, `HasRestrictions` | über `ns.Say` |
| `TooltipDataProcessor.AddTooltipPostCall` | ja | ja | Tooltip |
| `ENCOUNTER_START/END` | nicht in der Doku | nicht in der Doku | nicht verwendet |

## Einstellungen

Neuer Abschnitt `ns.RegisterSettings{ key = "loot", label = "Loot-Ansage", order = 22, officer = true }`:

| Pfad | Typ | Standard | Text |
|---|---|---|---|
| loot.announce | toggle | an | "Loot im Schlachtzugschat ansagen" (Tip: einmal pro Leiche, nur als Lootleitung) |
| loot.quality | choice 3/4/5 | 4 | "Ansagen ab Qualität": "Selten" / "Episch" / "Legendär" |
| loot.groupLoot | toggle | an | "Auch bei Gruppenplündern aus den Würfelfenstern ansagen" |
| loot.warning | toggle | aus | "Zusätzlich eine Schlachtzugswarnung" |
| loot.lead | choice auto/me | auto | "Ansage und !sr-Antworten": "Plündermeister, sonst Leiter" / "Immer ich" |

Abschnitt "softres" (bisher für alle) bekommt:

| Pfad | Typ | Standard | Ansicht | Text |
|---|---|---|---|---|
| softres.tooltipGroup | toggle | an | alle | "Im Tooltip nur Reservierungen aus der Gruppe" |
| softres.lootMark | toggle | an | alle | Text neu: "SR-Markierung im Lootfenster und an den Würfelfenstern" |
| softres.limit | slider 0-6 | 0 | Offiziere | "Reservierungen pro Raider (0 = keine Prüfung)" |
| softres.chat | toggle | an | Offiziere | "Auf !sr antworten" (Tip: nur als Lootleitung, per Flüsterung) |
| softres.remindText | text | "" | Offiziere | "Zusatz in der Erinnerung" (Tip: z. B. Link zur Liste) |

`softres.remindText`: `validate` entfernt `|` und Zeilenumbrüche, höchstens 120 Zeichen.
`softres.limit` steht bewusst auf 0: die Grenze legt die SR-Seite des Raids fest, und eine falsche
Zahl würde jeden Raid rot färben.

## Befehle

| Befehl | Ansicht | Wirkung |
|---|---|---|
| `/amisia sr` | alle | Seite Soft-Reserves (wie heute) |
| `/amisia sr pruefen` (Alias `check`) | alle | Abgleich im eigenen Chat |
| `/amisia sr erinnern` (Alias `remind`) | Offiziere | Flüsterung an Raider ohne Reserve (mit Rückfrage) |
| `/amisia sr posten` (Alias `post`) | Offiziere | Zusammenfassung in den Schlachtzugschat |
| `/amisia ansage` (Alias `announce`) | Offiziere | offenes Lootfenster erneut ansagen |
| `/amisia wurf <Name> <Zahl> [os]` (Alias `addroll`) | Offiziere | Wurf von Hand in die Runde |

Die Unterwörter von `sr` stehen in der Hilfe als eine Zeile `/amisia sr [pruefen|erinnern|posten]`.
Chat-Befehle für Raider ohne Addon: `!sr`, `!sr <Item>`, Alias `!softres`.

## Fehlerbehandlung

- Seiten und Fenster bauen in `pcall` wie bisher. Tooltip-Hook und Würfelfenster-Hook laufen in
  `pcall`; ein Fehler geht an `geterrorhandler`, der Tooltip bleibt.
- Fehlende APIs (`GetLootRollItemLink`, `C_PartyInfo.GetLootMethod` und `GetLootMethod`,
  `InChatMessagingLockdown`, `GroupLootFrame<n>`, `TooltipUtil`): Typprüfung, die Funktion fällt still
  weg; ohne Lootmethode gilt der Leiter als Lootleitung.
- Geheime Werte (Absender, Text, Quelle, Kreaturname, GUID) gehen durch `ns.Plain` und werden nie
  verglichen. Fehlt dadurch der Ansage-Schlüssel, gilt der Item-Schlüssel.
- Senden in `pcall`; ein Fehler verwirft die Zeile und meldet einmal pro Minute "Amisia: Chat-Zeile
  konnte nicht gesendet werden.".
- Volle Schlange und Grenzen von `!sr`: wie oben, nie mehr als eine eigene Meldung pro Minute.
- `ns.AddManualRoll` mit ungültigen Angaben: Grund zurück, Befehl und Fenster zeigen ihn.
- `ns.RenameReserve` auf einen Namen, der in der Liste nicht mehr vorkommt: 0, nichts passiert.

## Tests

Lua (`addon/tests`, Stub ergänzt: `C_ChatInfo.InChatMessagingLockdown` über `STUB.chatLock`,
`C_PartyInfo.GetLootMethod` über `STUB.lootMethod` und `STUB.mlRaidID`, `UnitIsUnit`,
`GetLootRollItemLink` über `STUB.rolls`, Frames `GroupLootFrame1-4`, `SendChatMessage` mit
`target`, `ADDON_RESTRICTION_STATE_CHANGED` über `STUB.fire`):

- `test_chat.lua`: sofortiger Versand bei Vorrat; Drosselung über 2000 Bytes, Nachfüllen über
  `STUB.tick`; Sperre hält alles an, Freigabe per Ereignis und per Tick; `ttl` verfällt (Countdown);
  gleiche `key` ersetzen sich; Grenze 40 mit einer Meldung; Zeile über 255 Bytes gekürzt, Link
  ganz; `ns.ChatLines`; `RAID_WARNING` ohne Recht wird `RAID`; geheimer Absender oder Text wird
  übersprungen; `!SR` ohne Groß/Klein erkannt; eigene Zeilen ignoriert.
- `test_softres_check.lua`: Umzug aus 1.5 (ohne `version`) und zweimal laden; `times` aus doppelten
  Zeilen; `srAliases` wirken beim Parsen; `ns.SoftResCheck` mit ok, missing, absent, unclear
  (surname, typo, keine Vorschläge bei kurzen Namen), over (nur mit Grenze), multi; Roster ohne
  Raid aus dem letzten Raid; `ns.RenameReserve` mit und ohne Merken; `rankOf` gibt "Vulo" aus der
  Liste den Vorrang für den Wurf von "Vulo Sturmwind".
- `test_softres.lua` (ergänzt): Tooltip nur Gruppe mit "+n außerhalb", "x2", "du"; ein Fehler im
  Tooltip-Körper bricht nichts ab; doppelter Aufruf ergibt eine Zeile.
- `test_srchat.lua`: `!sr` per Flüsterung und aus dem Raidchat, Antwort immer Flüsterung an den
  rohen Absender; `!sr <Link>` und `!sr <Teilname>`; keine Antwort ohne Lootleitung, ohne
  Offiziersansicht, ohne Liste, von außerhalb der Gruppe; 15-s-Grenze je Absender und 20 pro
  Minute; Hinweis bei alter Liste; Erinnerung flüstert nur Fehlende und nur einmal; Zusammenfassung
  in zwei Zeilen höchstens.
- `test_lootannounce.lua`: Lootleitung (ML ich, ML andere, kein ML Leiter, `loot.lead = "me"`,
  Raider-Ansicht nie); `LOOT_OPENED` sagt einmal pro Quelle an, nach `/reload`-Ersatz (Neuladen
  der Datei mit gleicher Aufnahme) nicht erneut; Qualitätsgrenze, MATS und IGNORE fehlen;
  Reservierende nur aus dem Raid mit "+n nicht im Raid"; geheime GUID nimmt den Item-Schlüssel;
  `isFromItem` sagt nichts; Schlachtzugswarnung nur mit Recht; `START_LOOT_ROLL` sammelt zwei Würfe
  in eine Ansage; ohne `GetLootRollItemLink` nichts; SR-Marke am Würfelfenster erscheint und
  verschwindet beim Wiederverwenden des Frames; `/amisia ansage` wiederholt.
- `test_manualroll.lua`: Wurf eintragen in laufende und beendete Runde; ersetzt vorhandenen Wurf;
  Bereichsprüfung MS/OS; fremder Name abgelehnt; beendete Runde rechnet neu und setzt `dirty`,
  "Ergebnis ansagen" sagt an; `r.lockdown` bei Start in der Sperre und bei Wechsel während der
  Runde; `r.hidden` zählt geheime Zeilen; Countdown in der Sperre verfällt; Roll-Fenster zeigt
  Hinweis und "Hand"; `/amisia wurf Vulo Sturmwind 87 os`.
- `test_pages.lua` (ergänzt): Soft-Reserves-Seite in beiden Ansichten und allen drei Ansichten der
  Liste, Korrektur-Chip wirkt, Knöpfe nur für Offiziere; Karte mit Abgleich; Rolls-Seite mit
  Sperrhinweis.
- Bestehende Tests bleiben grün, insbesondere alle, die `STUB.chat` direkt nach einer Ansage lesen.
- Python/Node (`tools/tests`): keine Änderung, die Seite bleibt unberührt. `python -m pytest
  tools/tests -q` und `node addon/tests/syntax.cjs` laufen trotzdem mit.
- Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review).

## Vorschlag für den Plan (7 Aufgaben)

1. **Chat-Schicht:** Chat.lua (`ns.Say`, Drosselung, Sperre, `ttl`, Grenze, `ns.ChatLines`,
   `ns.RegisterChatCommand`), `ns.Announce` darüber, TOC; Stub; `test_chat.lua`.
2. **SR-Daten und Abgleich:** Datenmodell 2, `ns.MigrateSoftRes`, `times`, `srAliases`,
   `ns.SoftResRoster`, `ns.SoftResCheck`, `ns.RenameReserve`, `ns.ReservesOf`, `rankOf` mit
   SameName, Tooltip nur Gruppe mit `pcall` und Merker; `test_softres_check.lua`, `test_softres.lua`.
3. **Seite und Import:** Pages/SoftRes.lua mit drei Ansichten, Abgleich, Korrektur-Chips, Karte;
   Vorschau im Import-Fenster; Einstellungen "softres"; `test_pages.lua`.
4. **Erinnerung und `!sr`:** Erinnern mit Rückfrage, Zusammenfassung, `!sr`/`!sr <Item>`, Grenzen,
   Unterwörter von `/amisia sr`; `test_srchat.lua`.
5. **Loot-Ansage:** LootAnnounce.lua (`ns.IsLootLead`, `LOOT_OPENED`, `START_LOOT_ROLL`,
   `s.announced`, Schlachtzugswarnung, SR-Marke an den Würfelfenstern, `/amisia ansage`),
   Abschnitt "loot"; `test_lootannounce.lua`.
6. **Würfe von Hand:** `ns.AddManualRoll`, `ns.RollDecide`, `ns.AnnounceRollResult`, `r.lockdown`,
   `r.hidden`, Roll-Fenster-Zeile, Rolls-Seite, `/amisia wurf`; `test_manualroll.lua`.
7. **Auslieferung:** Version 1.6.0 (TOC, `ns.VERSION`), alle Tests, `tools/release_addon.sh`, ZIP
   gegen die TOC prüfen, unabhängige Prüfung. Kein Twin (Seite unverändert).

## Auslieferung

Version 1.6.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh` (füllt den Release-Ordner, den Syncthing sendet), im Spiel `/reload`.

## Ideen aus der Recherche

Übernommen:
- Items beim Öffnen des Lootfensters mit Reservierenden in den Raidchat, einmal pro Leiche, mit
  Qualitätsgrenze; bei Gruppenplündern aus den Würfelfenstern, SR-Marke an den Würfelfenstern.
- Vorschau der SR-Liste gegen den aktuellen Raid vor dem Import, falsch geschriebene Namen
  korrigieren (hier mit Merken für die nächste Woche, gedacht für Forever-Nachnamen).
- Tooltips auf die Gruppe beschränkt und so gebaut, dass sie andere Tooltips nie brechen.
- Chat-Befehle für Raider ohne Addon (`!sr`, `!sr <Item>`), gedrosselt, nur von einem Client.
- Gemeinsame Drosselung für alles, was Amisia in den Chat schreibt.
- Würfe von Hand, wenn der Chat im Bosskampf geheim ist.

Später:
- Raider-Fenster mit MS/OS/Passen statt `/roll` und Antworten per Addon-Nachricht (braucht die
  Sync-Schicht aus Baustein 7 und deren Warteschlange für die Sperre).
- SR-Liste per Addon-Nachricht an alle Raider verteilen, damit jeder den Tooltip hat (Baustein 7).
- Automatische Erinnerung beim Raidstart; jetzt nur auf Knopfdruck, um niemanden unaufgefordert
  anzuschreiben.
- Eigene Flüsterungen und `!sr`-Anfragen im Chat ausblenden (Nachrichtenfilter unterscheiden sich
  zwischen den Clients).
- SR+ (Bonuspunkte für wiederholte Reservierung) und Offspec-Reservierungen.
- Plus-Eins im Tooltip.

## Nicht in Baustein 4

Raider-Fenster und Addon-Nachrichten, Verteilen der SR-Liste, Sync und Versionscheck (Baustein 7);
SR+-Punkte, Offspec-Reservierungen, Prioritätslisten; automatische Erinnerung und Erinnerung an
Raider außerhalb der Gruppe; Ausblenden eigener Flüsterungen; Ansagen in 5er-Gruppen und
Schlachtfeldern; Ansage bei persönlichem Loot; Erkennen von Bossleichen gegenüber Trash (die
Qualitätsgrenze reicht); Bosskills, Ersatzbank, Discord-Text (Baustein 6); BiS-Abgleich (3);
Karte (2); Änderungen an Export und Website.

## Offene Punkte

Nur im Spiel zu klären:

- Ob `C_ChatInfo.InChatMessagingLockdown()` auf Forever genau dann true ist, wenn `CHAT_MSG_*`
  geheim ankommen, und ob `ADDON_RESTRICTION_STATE_CHANGED` beim Ende des Bosskampfs feuert. Prüfen
  mit `/dump C_ChatInfo.InChatMessagingLockdown()` und `/dump C_RestrictedActions.IsAddOnRestrictionActive(5)`
  im Bosskampf. Fällt das Ereignis aus, gibt der 2-s-Tick die Schlange frei.
- Ob `SendChatMessage` an `RAID` oder `WHISPER` während der Sperre blockiert wird (für den Entwurf
  egal, Amisia wartet ohnehin).
- Ob eine Flüsterung an einen Forever-Namen mit Leerzeichen über den rohen Absender-Text ankommt;
  ob der Absender in `CHAT_MSG_WHISPER` "Vorname Nachname" oder anders aussieht (`/amisia namen`
  erweitern ist nicht nötig, ein Test-`!sr` reicht).
- Ob `GetLootRollItemLink` auf Forever vorhanden ist und ob der Leiter `START_LOOT_ROLL` auch
  bekommt, wenn er tot oder weit weg ist (sonst sagt niemand an; `loot.lead = "me"` beim Plündernden
  hilft).
- Ob die GUID aus `GetLootSourceInfo` in Forever-Raids geheim ist (dann greift der Item-Schlüssel).
- Ob Master Loot auf Forever angeboten wird (offen seit Baustein 1; die Ansage funktioniert in
  beiden Fällen).
- Lage der SR-Marke auf den Würfelfenstern beider Clients (Forever-Fenster sind anders gebaut).
- Ob Raider "!sr" annehmen oder lieber im Raidchat fragen: beides wird beantwortet, die Antwort
  geht immer per Flüsterung.
