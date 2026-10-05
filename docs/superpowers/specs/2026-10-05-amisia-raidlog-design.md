# Amisia 1.7: Raid-Log (Bosskills, Ersatzbank, Discord-Text)

Stand 2026-10-05. Baustein 6 von 7 (Reihenfolge der Umsetzung laut Nutzer: 5, 4, 6, 3, 2, 7).
Baut auf Baustein 1 (`docs/superpowers/specs/2026-10-04-amisia-main-window-design.md`: Registry,
Widgets, Hauptfenster, Seiten), Baustein 5 (`docs/superpowers/specs/2026-10-05-amisia-awards-design.md`:
Vergabebuch, `ns.Plain`, W.Picker, W.LineEdit, Exportregel mit zweibuchstabigen Zeilen) und
Baustein 4 (`docs/superpowers/specs/2026-10-05-amisia-loot-sr-design.md`: `ns.Say`,
`ns.RegisterChatCommand`, `ns.IsLootLead`, `ns.SameNameIn`) auf. Ändert das Addon `addon/Amisia`,
das Exportformat (nur neue Zeilen) und den Import der Seite `index.html`.

## Ziel

Heute weiß Amisia pro Raid, wer da war, wer zu spät kam und was gedroppt und vergeben wurde, aber
nicht, welche Bosse fielen, wann, und wer beim Kill dabei war. Wer draußen auf Abruf wartet, fehlt
ganz: die Aufnahme zählt nur, wer in der Instanz steht, und auf der Website gilt die Ersatzbank als
nicht da. Nach dem Raid tippt ein Offizier die Zusammenfassung für Discord von Hand. Baustein 6
bringt:

- **Bosskills und Wipes** je Raid mit Uhrzeit, Kampfdauer und den Raidern, die beim Kill in der
  Instanz waren, ohne Kampflog (Forever hat keins für Addons). Quelle sind die Kampfereignisse des
  Clients; fehlen sie, erkennt Amisia einen Boss am Lootfenster seiner Leiche, und Offiziere können
  einen Kill von Hand eintragen.
- **Ersatzbank:** Offiziere tragen Spieler für einen Raid auf die Ersatzbank ein (aus Gilde,
  Freunden, Gruppe draußen oder getippt). Spieler tragen sich mit `!bench` selbst ein. Die Website
  zählt die Ersatzbank in der Anwesenheit mit eigener Markierung und einstellbarer Wertung.
- **Discord-Text:** eine kopierbare Zusammenfassung des Raids (Datum, Raid, Bosse mit Uhrzeit,
  Anwesenheit, zu spät, Ersatzbank, Loot je Boss mit Gewinner und MS/OS/SR, Bank und Entzaubern),
  deutsch, Markdown für Discord.
- **Seite "Raid-Log"** mit dem Verlauf eines Raids, der Ersatzbank und dem Discord-Text.
- **Export und Website:** neue Zeilen für Bossversuche, Anwesende beim Kill und Ersatzbank; die
  Seite zeigt die Bosse pro Nacht und die Ersatzbank in der Anwesenheit.

## Rahmen und Entscheidungen

- **Clients, Bibliotheken, Schrift, Fensterebenen, Offiziersansicht:** wie Baustein 1, 4 und 5. Ein
  TOC (`20506, 16001`), keine fremden Bibliotheken, kein `UIDropDownMenu`/`EasyMenu`, UI- und
  Chat-Texte deutsch und nur Latin-1 (ä ö ü ß und "·", kein Gedankenstrich, keine
  Auslassungspunkte, keine Pfeile), Code-Kommentare englisch, Texte der Website englisch. Anmeldung
  nur über `ns.RegisterPanel`, `ns.RegisterCard`, `ns.RegisterSettings`, `ns.RegisterSlash`;
  Offiziersteile über `ns.IsOfficerView()`. Alles in den Chat über `ns.Say`. Forever hat kein
  globales `GetItemInfo`/`GetItemInfoInstant`: Dateien, die Itemdaten brauchen, nehmen den
  `C_Item`-Shim wie Core.lua.
- **Keine anderen Addons nennen**, weder in UI-Texten, Chat-Texten, Kommentaren noch Commits. Im
  Entwurf heißen sie "andere Raid-Addons".
- **Kein Kampflog.** `COMBAT_LOG_EVENT_UNFILTERED` hat auf beiden Clients `HasRestrictions`, Forever
  gibt Addons keins. Amisia nutzt nur die Kampfereignisse `ENCOUNTER_START`, `ENCOUNTER_END`,
  `BOSS_KILL` (beide Clients dokumentiert, Payload ohne Geheim-Kennzeichen) und als Rückfall das
  Lootfenster. Monster-Rufe (`CHAT_MSG_MONSTER_YELL`, auf Forever `SecretInChatMessagingLockdown`,
  außerdem sprachabhängig) und `UNIT_DIED` (Forever `SecretWhenUnitIdentityRestricted`, nur eine
  GUID, bräuchte eine eigene Bosstabelle) werden nicht verwendet.
- **Jeder Client mit Amisia zeichnet auf**, wie die Anwesenheit heute. Die Kills brauchen keine
  Lootleitung; zwei Aufnehmende ergeben auf der Website dieselben Kills, die Seite fasst sie
  zusammen.
- **Anwesend beim Kill** sind die Raider, die beim Ende des Kampfs online und in derselben Zone wie
  der Aufnehmende stehen (dieselbe Regel wie `snapshotRoster`). Auf Forever können Namen der
  Raidliste im Bosskampf geheim sein: die Liste wird nach dem Kampf gelesen, sobald sie lesbar ist
  (siehe "Anwesend beim Kill"). Bei Wipes wird nur die Zahl gespeichert, keine Namen.
- **Ersatzbank gehört zum Raid** (`s.bench`), nicht zur Gilde. Vor dem ersten Betreten der Instanz
  (Gruppe sammelt sich in der Stadt) gibt es noch keine Aufnahme; Einträge landen dann in
  `AmisiaDB.benchNext` für die laufende Raidnacht und wandern in die erste Aufnahme dieser Nacht.
- **Ersatzbank schützt vor "zu spät":** wer auf der Ersatzbank stand und später eingewechselt wird,
  gilt nicht als zu spät (`noteMember` prüft `s.bench`). Ein eingewechselter Raider bleibt in
  `s.bench` (mit Hinweis "eingewechselt"), auf der Website gewinnt die Anwesenheit.
- **`!bench` beantwortet nur die Lootleitung** (`ns.IsLootLead()`, also nur im Raid und in der
  Offiziersansicht), wie `!sr`. Antworten immer per Flüsterung an den rohen Absender.
- **Discord-Text nur im Addon und nur für Offiziere.** Er braucht die Vergaben, die nur der
  Plündermeister vollständig hat. Die Website bekommt keinen deutschen Text; ihr bestehendes
  "Copy as text" der Nachtansicht nennt künftig Bosse und Ersatzbank (englisch).
- **Wertung der Ersatzbank entscheidet die Website**, nicht das Addon: das Addon exportiert, wer
  auf der Ersatzbank stand; die Seite rechnet nach `state.benchMode` (Standard: zählt als
  anwesend). "Nacht zählt nicht" pro Raidnacht gibt es auf der Seite schon (`n.off`) und bleibt.
- **Exportregel** wie Baustein 5: bestehende Zeilen Byte für Byte gleich, neue Zeilenarten mit
  zwei Buchstaben, Kopf bleibt `#AMISIA 2`. Ein Raid ohne Kills und ohne Ersatzbank schreibt keine
  neue Zeile, sein Fingerabdruck (`ns.SessionHash`) bleibt gleich; ein Umzug der Exportmarken ist
  nicht nötig.

## Dateien

```
addon/Amisia/RaidLog.lua         NEU: Bossversuche aus ENCOUNTER_START/END und BOSS_KILL, Rückfall
                                 Lootfenster, Kill von Hand, Anwesende nach dem Kampf, ns.Kills,
                                 Ereignis-Merker für /amisia log ereignisse; Abschnitt "raidlog";
                                 Befehle log, boss
addon/Amisia/Bench.lua           NEU: Ersatzbank (ns.BenchAdd/Remove/List), benchNext, Vorschläge
                                 (Gilde, Freunde, Gruppe draußen), !bench; Befehl ersatz
addon/Amisia/RaidText.lua        NEU: ns.RaidSummary(s) -> Discord-Text in Teilen; Befehl discord
addon/Amisia/Pages/RaidLog.lua   NEU: Seite "Raid-Log" (Verlauf, Ersatzbank, Discord)
addon/Amisia/Core.lua            s.kills, s.bench, s.outside, s.pull anlegen; snapshotRoster liest
                                 Namen und Zone über ns.Plain und merkt Gruppe draußen; noteMember
                                 ohne "zu spät" für Ersatzbank; Export EK, EP, BN; Aufnahme-Start
                                 übernimmt benchNext
addon/Amisia/Chat.lua            CHAT_MSG_GUILD als Kanal "GUILD" für !-Befehle; ns.ReplyGate
addon/Amisia/Pages/Raids.lua     Details mit Bossen und Ersatzbank; Karte "raid" nennt die Bosse
addon/Amisia/Minimap.lua         Schnellmenü: Eintrag "Raid-Log"
addon/Amisia/Amisia.toc          RaidLog.lua, Bench.lua, RaidText.lua nach LootAnnounce.lua;
                                 Pages\RaidLog.lua nach Pages\Raids.lua; Version 1.7.0
index.html                       amParse liest EK, EP, BN; amNightLog; nightKills; benchOn;
                                 attendance mit benchMode; Nachtansicht, Anwesenheit, Vorschau,
                                 nightText; state.benchMode beim Wiederherstellen
tools/tests/site_raidlog.cjs     NEU: amNightLog, nightKills, attendance gegen Stubs
tools/tests/test_raidlog_import.py   NEU
tools/tests/test_export_format.py    ergänzt: Kills und Ersatzbank vom Addon bis zur Seite
addon/tests/*                    neue Tests, Stub ergänzt
```

SoftRes.lua bleibt unverändert (`!sr` behält seine eigene Drosselung; sie auf `ns.ReplyGate`
umzustellen ist eine spätere Aufräumarbeit).

## Datenmodell

### Raid (`AmisiaDB.sessions[i]`)

```lua
s.kills = {          -- NEU: jeder Bossversuch, nach Ende sortiert
  { enc = 601,                         -- encounterID, 0 wenn unbekannt (Lootfenster, von Hand)
    name = "Hochkriegsfürst Naj'entus",  -- wie der Client ihn nennt (lokalisiert)
    start = 1759601000,                -- Beginn (Epoch); ohne Beginn = t
    t = 1759601192,                    -- Ende (Epoch)
    ok = true,                         -- true Kill, false Wipe
    size = 25, diff = 4,               -- groupSize, difficultyID aus dem Ereignis; 0 wenn unbekannt
    src = "enc" | "kill" | "loot" | "hand",   -- ENCOUNTER_END, BOSS_KILL, Lootfenster, von Hand
    who = { "Fraktur", "Vulo Sturmwind" },     -- nur Kills: Anwesende, sortiert; fehlt solange wait
    wait = true,                       -- Anwesende werden noch gelesen (nach dem Kampf)
    n = 25 },                          -- Zahl der Anwesenden (auch bei Wipes, aus der Raidliste)
}
s.pull = { enc = 601, name = "...", start = 1759601000, size = 25, diff = 4 }
                     -- NEU: laufender Versuch (übersteht /reload im Kampf), nil außerhalb
s.bench = {          -- NEU: Ersatzbank des Raids, Schlüssel = ns.FullName
  ["Bob"] = { t = 1759599000, class = "MAGE", self = true, note = "ab 21 Uhr" },
  ["Kim Eisherz"] = { t = 1759599300, class = "", by = "Vuloo" },
}
s.outside = { ["Bob"] = 1759600200 }   -- NEU: in der Gruppe, online, nicht in der Instanz
                                       -- (letzte Sichtung); nur für Vorschläge, nicht im Export
```

- `who` hält Namen über `ns.FullName`, wie `s.members`. Höchstens 40 Namen.
- Bank-Einträge: `self = true` hat sich per `!bench` selbst eingetragen, sonst `by` = Offizier
  (`ns.UnitFullName("player")`). `note` höchstens 40 Zeichen, ohne `|` und Zeilenumbruch
  (`ns.CleanNote` aus Awards.lua bekommt dafür ein optionales zweites Argument für die Länge, Standard 60 wie bisher). `class` aus Gilde, Freunden oder Raidliste, sonst "".
- `s.members[name].bench = true` (NEU, optional): kam von der Ersatzbank, deshalb nicht zu spät.

### Raidnacht vor der Aufnahme

```lua
AmisiaDB.benchNext = { date = "2026-10-05", list = { ["Bob"] = { ...wie s.bench... } } }
```

Beim Start einer neuen Aufnahme (`newSession`) mit `s.date == benchNext.date` wandert `list` in
`s.bench` und `benchNext` wird gelöscht. Beim Fortsetzen einer Aufnahme (`findReusable`) ebenso.
Ein `benchNext` mit älterem Datum fällt beim Laden und beim nächsten Schreiben weg.

### Umzug

Kein Versionszähler nötig. Beim `ADDON_LOADED` in der Schleife, die heute `s.awards`/`s.gone`
auffüllt: `s.kills = s.kills or {}`, `s.bench = s.bench or {}`, `s.outside = s.outside or {}`.
Ein `s.pull` älter als 2 Stunden wird verworfen. Weil leere Listen keine Exportzeile schreiben,
bleibt jeder schon exportierte Raid "exportiert". Zweimal laden ändert nichts.

## Ereignisse und APIs je Client

Geprüft in den Client-Quellen 2.5.6.69795 (Anniversary) und 1.60.1.70205 (Forever),
`Blizzard_APIDocumentationGenerated` und FrameXML.

| API / Ereignis | Anniversary 2.5.6 | Forever 1.60.1 | Verwendung |
|---|---|---|---|
| `ENCOUNTER_START` | `encounterID, encounterName, difficultyID, groupSize` | gleich, kein Geheim-Kennzeichen | Beginn, `s.pull` |
| `ENCOUNTER_END` | dazu `success` (Zahl), `encounterUnitStatus` (Tabelle) | gleich, kein Geheim-Kennzeichen | Kill oder Wipe |
| `BOSS_KILL` | `encounterID, encounterName` | gleich; FrameXML nutzt es (BossBannerToast) | Kill, falls `ENCOUNTER_END` fehlt |
| `ENCOUNTER_STATE_CHANGED` | `isInProgress` | gleich | nicht verwendet (kein Name) |
| `C_InstanceEncounter.IsEncounterInProgress` | ja | ja | Prüfung beim Laden: offener Versuch |
| `INSTANCE_ENCOUNTER_ENGAGE_UNIT` | ja, ohne Payload | ja | nicht verwendet |
| `CHAT_MSG_MONSTER_YELL` | ohne Kennzeichen | `SecretInChatMessagingLockdown` | nicht verwendet |
| `UNIT_DIED` | `unitGUID` | `SecretWhenUnitIdentityRestricted` | nicht verwendet |
| `COMBAT_LOG_EVENT_UNFILTERED` | `HasRestrictions` | `HasRestrictions`, für Addons leer | nicht verwendet |
| `UnitClassification` | Global, von FrameXML genutzt | dokumentiert, Rückgabe ohne Kennzeichen | Rückfall Lootfenster: `"worldboss"` |
| `UnitIsDead` | ja | `AllowedWhenUntainted` | Rückfall Lootfenster |
| `GetRaidRosterInfo` | Global | Global (nicht in der Doku) | Anwesende, über `ns.Plain` |
| `C_RestrictedActions.IsAddOnRestrictionActive(1)` | ja (Typ Encounter = 1) | ja | Anwesende erst nach dem Kampf lesen |
| `ADDON_RESTRICTION_STATE_CHANGED` | ja | ja | Anwesende lesen, sobald frei |
| `C_GuildInfo.GuildRoster`, `GUILD_ROSTER_UPDATE` | ja | ja | Gildenliste anfordern |
| `GetNumGuildMembers`, `GetGuildRosterInfo` | Global, FrameXML nutzt es | `GetNumGuildMembers` in FrameXML, `GetGuildRosterInfo` nicht | Typprüfung, sonst keine Gildenvorschläge |
| `C_FriendList.GetNumFriends`, `GetFriendInfoByIndex` | ja (`name`, `className`, `connected`) | ja | Vorschläge |
| `CHAT_MSG_GUILD` | ohne Kennzeichen | vermutlich gesperrt im Kampf, `ns.Plain` | `!bench` im Gildenchat |

Die frühere Zeile "`ENCOUNTER_START/END` nicht in der Doku" im Entwurf von Baustein 4 stimmt nicht:
beide stehen in `EncounterInfoDocumentation.lua` beider Clients. Ob der Server sie für die alten
Raids auch sendet, ist im Spiel zu prüfen (Anniversary nutzt sie in FrameXML nirgends). Darum der
Rückfall.

## Bossversuche (RaidLog.lua)

```lua
ns.Kills(s) -> { attempts }            -- s.kills, nach t sortiert (Kopie der Liste, nicht der Einträge)
ns.KillCount(s) -> kills, wipes, bosses -- bosses: verschiedene Bosse mit Kill
ns.AddKill(s, { name, t, ok, start?, enc?, src = "hand" }) -> k | nil, Grund
ns.DeleteKill(s, k) -> true | nil
ns.KillFor(s, srcName, t) -> k | nil   -- der Kill, zu dem ein Lootquell-Name gehört (Discord, Seite)
ns.EncounterTrace() -> { { t, event, text } }   -- letzte 20 Kampfereignisse, nur im Speicher
```

Alles nur mit laufender Aufnahme (`ns.Active()`) und `raidlog.track`.

- **ENCOUNTER_START:** `s.pull = { enc, name = ns.Plain(name) or ("Boss " .. enc), start = time(),
  size, diff }`. Ein offener `s.pull` mit anderem `enc` wird verworfen (kein Ende gesehen).
- **ENCOUNTER_END:** Eintrag mit `start` aus `s.pull` (gleiches `enc`, sonst `start = t`),
  `ok = (success == 1)`, `src = "enc"`, `n` = Zahl der lesbaren Raider in der Zone. `s.pull = nil`.
  Bei Kill: `wait = true`, dann "Anwesend beim Kill". `ns.Fire("DATA_CHANGED")`.
- **BOSS_KILL:** gibt es in `s.kills` schon einen Kill mit gleichem `enc` und `t` höchstens 120 s
  zurück, nichts. Sonst neuer Kill mit `src = "kill"`, `start` aus `s.pull` wie oben.
- **Ein `ENCOUNTER_END` nach einem `BOSS_KILL`** (andere Reihenfolge) ergänzt den vorhandenen
  Eintrag (`start`, `size`, `diff`, `src = "enc"`), statt einen zweiten anzulegen.
- **Rückfall Lootfenster** (`raidlog.lootKills`, Standard an): `ns.OnEvent("LOOT_OPENED")` läuft
  nach Core (`onLootOpened` hat `s.drops` schon gefüllt). Bedingungen: Ziel ist tot
  (`UnitIsDead("target")`), `UnitClassification("target") == "worldboss"`, Name und GUID über
  `ns.Plain` lesbar, die GUID ist eine Quelle des offenen Fensters. Dann ein Kill mit `src = "loot"`,
  `enc = 0`, `name` = Zielname, `t = s.drops[guid].t` (erstes Öffnen), `who` sofort aus der
  Raidliste. Nicht, wenn es in `s.kills` einen Kill gibt mit gleichem Namen (ohne Groß/Klein) oder
  mit `t` höchstens 10 Minuten vor dem ersten Öffnen dieser Leiche (Kampfname und Kreaturname
  weichen ab, z. B. ein Rat aus vier Bossen). Ein späterer `ENCOUNTER_END`/`BOSS_KILL` für denselben
  Kampf ersetzt den Lootfenster-Kill, wenn dessen `t` höchstens 10 Minuten danach liegt.
- **Von Hand** (`ns.AddKill`, Offiziere über Seite und `/amisia boss`): Name (bereinigt wie eine
  Notiz, höchstens 60 Zeichen), `ok`, `t` (Standard jetzt, auf der Seite die Zeit des ersten
  Lootfensters dieser Quelle, falls gewählt), `src = "hand"`, `who` aus der Raidliste, wenn die
  Aufnahme läuft, sonst leer. Geht auch in einen alten Raid (wie Vergaben: setzt nie `s.last`).
- **Löschen** (`ns.DeleteKill`): entfernt den Eintrag; der Raid wird "geändert" (Hash).
- `/reload` im Kampf: `s.pull` bleibt gespeichert; kommt danach `ENCOUNTER_END`, passt es. Ist
  beim Laden `C_InstanceEncounter.IsEncounterInProgress()` false und `s.pull` älter als
  15 Minuten, wird er verworfen.
- **Ereignis-Merker:** jedes der drei Ereignisse und jeder Lootfenster-Kill landet mit Zeit und
  Kurztext in einem Ringpuffer (20 Einträge, nicht gespeichert); `/amisia log ereignisse` gibt ihn
  im eigenen Chat aus. Gedacht für die Prüfung im Spiel, ob die Ereignisse kommen.

### Anwesend beim Kill

```lua
local function readPresent() -> names | nil   -- nil, solange ein Name oder die Zone geheim ist
```

- Liest `GetRaidRosterInfo` wie `snapshotRoster`: online, Zone wie die eigene (Zone und Namen über
  `ns.Plain`), Namen über `ns.FullName`.
- Nach `ENCOUNTER_END` (Kill): `C_Timer.After(1, ...)` versuchen; ist
  `C_RestrictedActions.IsAddOnRestrictionActive(1)` true oder `readPresent()` nil, erneut bei
  `ADDON_RESTRICTION_STATE_CHANGED` und spätestens alle 2 s, höchstens 60 s lang. Danach (oder
  wenn die Aufnahme endet) `who` aus `s.members` mit `last >= start - 60` und `first <= t`
  (die Raidliste der Minutenschnappschüsse), `wait = nil`.
- `n` bei Wipes: Zahl der lesbaren Raider in der Zone beim Ende, sonst `#s.members` mit
  `last >= start - 60`.

### Kill zu Lootquelle (`ns.KillFor`)

Für Discord-Text und Seite: eine Vergabe nennt ihre Quelle (`a.src`, Kreaturname), ein Kill seinen
Kampfnamen. Zuordnung in dieser Reihenfolge:

1. Kill mit gleichem Namen (ohne Groß/Klein).
2. Die Lootfenster-Quelle `d` in `s.drops` mit `d.src == srcName`; der letzte Kill mit
   `k.t <= d.t` und `d.t - k.t <= 600`.
3. Sonst nil (die Vergabe steht unter ihrem Quellnamen ohne Uhrzeit).

## Ersatzbank (Bench.lua)

```lua
ns.BenchAdd(s, name, { self = bool, note = text, class = token }) -> e | nil, Grund
ns.BenchRemove(s, name) -> true | nil, Grund
ns.BenchList(s) -> { { name, e, joined = epoch|nil } }   -- nach Name; joined: später im Raid
ns.BenchTarget() -> s, label        -- laufende Aufnahme, sonst benchNext der Nacht ("heute, vor dem Raid")
ns.BenchSuggestions(s) -> { { value = name, text = "Bob (Gilde, online)" } }
ns.IsBenched(s, name) -> e | nil    -- über ns.SameNameIn gegen die Bank-Namen
```

- `s` ist ein Raid oder die Pseudo-Aufnahme `benchNext` (`ns.BenchTarget()`); ohne beides (keine
  Aufnahme, kein Raid heute) legt `BenchAdd` `benchNext` für die laufende Nacht an (Datum wie
  `newSession`, Regel `record.nightStart`).
- **Ablehnen:** Name ungültig ("Name fehlt."); Name steht in `s.members` mit `last` innerhalb der
  letzten 10 Minuten oder ist gerade in der Instanz ("%s ist im Raid."). Ein schon eingetragener
  Name wird aktualisiert (Notiz, `self` bleibt, wenn ein Offizier nachträgt, wird `by` gesetzt).
- **Entfernen:** Offiziere jeden Eintrag; über `!bench aus` nur eigene `self`-Einträge.
- **Einwechseln:** `noteMember` (Core) legt einen neuen Raider mit `late = nil, bench = true` an,
  wenn `ns.IsBenched(s, name)` einen Eintrag mit `t <=` jetzt findet. `ns.BenchList` setzt dann
  `joined = m.first`.
- **Vorschläge** (`ns.BenchSuggestions`, für W.Picker), jeweils über `ns.Plain` und `ns.FullName`,
  doppelte über `ns.SameName` zusammengefasst, ohne wer schon auf der Bank oder in der Instanz ist:
  1. Gruppe draußen: `s.outside` der letzten 10 Minuten, Text "Bob (in der Gruppe, draußen)".
  2. Gilde online: `GetNumGuildMembers`/`GetGuildRosterInfo` (Name, Klasse über das 11. Feld
     `classFileName`, `online`), Text "Bob (Gilde)". `C_GuildInfo.GuildRoster()` wird beim Öffnen
     der Ansicht einmal angefordert (höchstens alle 10 s).
  3. Freunde online: `C_FriendList.GetFriendInfoByIndex` (`connected`, `name`, `className`), Text
     "Bob (Freund)".
  4. "Anderer Name" (freier Text).
- **Gruppe draußen** merkt `snapshotRoster` (Core): online, Zone lesbar und anders als die eigene ->
  `s.outside[name] = t`. Heute werden diese Raider nur übersprungen.

### `!bench` (Chat-Befehl)

`ns.RegisterChatCommand("bench", ...)`, Alias `ersatz`. Kanäle: Flüstern, Raid, Gruppe und neu
Gildenchat (Chat.lua meldet `CHAT_MSG_GUILD` als `"GUILD"`; `!sr` antwortet dort wie bisher nur
Gruppenmitgliedern, weil sein Handler die Gruppe prüft).

Antwortet nur, wenn `raidlog.benchChat` an ist und `ns.IsLootLead()`. Absender über `ns.Plain`
(Chat.lua), Name über `ns.FullName`. Ist `raidlog.benchGuildOnly` an (Standard), muss der Name in
der Gildenliste stehen (`ns.SameName`); lässt sich die Gildenliste nicht lesen (Funktion fehlt
oder 0 Mitglieder), wird angenommen und der Eintrag bekommt `note = "Gilde nicht geprüft"`, falls
leer.

| Anfrage | Wirkung | Antwort (Flüsterung) |
|---|---|---|
| `!bench` | Eintrag `self = true` in `ns.BenchTarget()` | "Amisia: Du stehst auf der Ersatzbank (Schwarzer Tempel, 05.10.). Mit !bench aus trägst du dich aus." |
| `!bench <Text>` | wie oben, Text als Notiz | dazu " Notiz: ab 21 Uhr." |
| `!bench aus` (auch `off`, `weg`) | eigenen `self`-Eintrag entfernen | "Amisia: Du stehst nicht mehr auf der Ersatzbank." bzw. "Amisia: Ein Offizier hat dich eingetragen. Frag bitte ihn." |
| `!bench ?` | nichts | "Amisia: Du stehst auf der Ersatzbank (seit 20:14)." bzw. "Amisia: Du stehst nicht auf der Ersatzbank." |

- Abgelehnt: "Amisia: Du bist schon im Raid." / "Amisia: Die Ersatzbank ist nur für Gildenmitglieder.".
- Ohne Aufnahme lautet der Klammerteil "(heute, 05.10.)".
- **Grenzen** über `ns.ReplyGate("bench", name)` (Chat.lua, neu): pro Absender eine Antwort je 15 s,
  insgesamt 20 je Minute, sonst still; einmal pro Minute "Viele !bench-Anfragen: weitere bleiben bis
  zu einer Minute unbeantwortet." im eigenen Chat.
- In der Chat-Sperre kommen Anfragen geheim an und werden übersprungen (wie `!sr`).
- Jede Änderung: `ns.Fire("DATA_CHANGED")`; im eigenen Chat "Amisia: Bob steht auf der Ersatzbank
  (selbst eingetragen)." (abschaltbar über `raidlog.benchNotify`, Standard an).

```lua
ns.ReplyGate(word, key) -> bool   -- Chat.lua: 15 s je key, 20 je Minute je word; meldet einmal pro Minute
```

## Discord-Text (RaidText.lua)

```lua
ns.RaidSummary(s) -> parts, total     -- parts: Liste von Texten mit höchstens 1900 Zeichen
ns.DiscordEscape(text) -> text
```

Reine Rechnung (keine Frames, kein Chat). Aufbau (Beispiel, Markdown für Discord):

```
**Schwarzer Tempel** · Donnerstag, 02.10.2026 · 20:02 bis 23:10
Bosse: 7 · Wipes: 3 · Raider: 25 · zu spät: 2 · Ersatzbank: 3

**Bosse**
20:14 Hochkriegsfürst Naj'entus (Kampf 3:12)
20:41 Supremus (2 Wipes, Kampf 4:05)
ca. 21:30 Mutter Shahraz (aus dem Lootfenster)

**Loot**
__Hochkriegsfürst Naj'entus__ 20:14
- Zahn des Naj'entus: Fraktur (MS)
- Halskette der Tiefe: Vulo Sturmwind (SR)
__Supremus__ 20:41
- Klinge des Supremus: Anna (OS) · Tausch mit Bob
__Ohne Boss__
- Schulterpolster der ewigen Gnade: Chorf (MS)
Bank: Kriegsklinge von Azzinoth · Entzaubert: Umhang der Hochgeborenen, Ring des Zorns

**Zu spät:** Chorf (20:12), Anna (20:31)
**Ersatzbank:** Bob (ab 21 Uhr), Fred, Kim (eingewechselt 21:40)
```

- Kopf: `raidlog.discordHead` (falls gesetzt) als eigene erste Zeile, dann Zone fett, Wochentag
  (eigene deutsche Tabelle, `date("*t")`), Datum `TT.MM.JJJJ`, erste und letzte Zeit
  (`s.firstScan or s.start` bis `s.last`).
- Zahlenzeile: Bosse = verschiedene Bosse mit Kill, Wipes (nur mit `raidlog.discordWipes`),
  Raider = `ns.MemberCount`, zu spät und Ersatzbank nur, wenn > 0.
- **Bosse:** je Boss eine Zeile in Kill-Reihenfolge; Wipes desselben Bosses (gleiches `enc`, sonst
  gleicher Name) davor werden gezählt; Kampfdauer `m:ss` aus `t - start`, nur bei `src = "enc"`;
  Lootfenster-Kills mit "ca." vor der Zeit und "(aus dem Lootfenster)"; von Hand ohne Zusatz.
  Wipes ohne späteren Kill: "21:50 Illidan Sturmgrimm (3 Wipes, kein Kill)".
- **Loot** (`raidlog.discordLoot`, Standard an): lebende Vergaben an Spieler (`s.awards`, `to`
  `player`), gruppiert über `ns.KillFor(s, a.src, a.t)`; Gruppen in Kill-Reihenfolge, dann Quellen
  ohne Kill nach Name, "?" als "Ohne Boss" zuletzt. Zeile "- Item: Name (Art)", Art nur wenn nicht
  "-", Notiz mit " · ". Bank und Entzaubern als eine Zeile je Ziel am Ende. Hat der Raid keine
  Vergaben, aber `s.items` (Gruppenplündern), steht stattdessen "**Geplündert**" mit "- Item: Name"
  (Anzahl als "x2").
- **Zu spät**, **Ersatzbank**: Namen mit Zeit bzw. Notiz; eingewechselte mit "(eingewechselt HH:MM)".
  Mit `raidlog.discordNames` (Standard aus) zusätzlich "**Dabei:** " mit allen Namen.
- **Escape:** in Namen, Itemnamen, Notizen und Kopf werden `\ * _ ~ ` | > #` und `[ ]` mit
  Backslash versehen (`ns.DiscordEscape`); Item-Links und Farbcodes werden nie eingesetzt, nur
  Namen über `ns.ItemName`. Eigene Zeichen nur ASCII plus ä ö ü ß und "·" (Latin-1, die Schrift im
  Spiel zeigt sie; Discord liest UTF-8).
- **Teilen:** über 1900 Zeichen (Discord erlaubt 2000) wird an Zeilengrenzen geteilt, ein
  Abschnitt bleibt nach Möglichkeit ganz; jeder Teil ab dem zweiten beginnt mit
  "**Schwarzer Tempel, 02.10. (Teil 2)**".

## Seite "Raid-Log" (Pages/RaidLog.lua)

`ns.RegisterPanel{ key = "raidlog", label = "Raid-Log", icon = "Interface\\Icons\\INV_Misc_Note_01",
order = 25 }`, für alle sichtbar; Bearbeiten und Discord nur in der Offiziersansicht. Inhaltsfläche
602 x 478 (Fenster 800 x 540, Seitenleiste 160).

```
+------------------------------------------------------------------------------------------+
| [Schwarzer Tempel, 02.10.     v]                    [Boss eintragen]  [Discord-Text]     |
| 7 Bosse · 3 Wipes · 20:02 bis 23:10 · 25 Raider · 2 zu spät · 3 Ersatzbank               |
| [Verlauf] [Ersatzbank (3)] [Discord]                                                     |
| Zeit   Ereignis                          Ergebnis   Dauer   Dabei   Quelle              |
| 20:02  Aufnahme gestartet                                                               |
| 20:12  Chorf kommt                        zu spät                                        |
| 20:14  Hochkriegsfürst Naj'entus          Kill       3:12    25      Kampf               |
| 20:33  Supremus                           Wipe       2:01    25      Kampf               |
| 21:30  Mutter Shahraz                     Kill               24      Lootfenster        |
| ...                                                    (12 Zeilen à 22 px, Mausrad)      |
+------------------------------------------------------------------------------------------+
| Hochkriegsfürst Naj'entus · Kill 20:14 · Kampf 3:12                       [Löschen]      |
| Dabei (25): Anna, Bob, Chorf, ...                                                        |
| Nicht dabei: Kim (kam 21:40)    Ersatzbank: Fred, Kim                                    |
| Loot: Zahn des Naj'entus an Fraktur (MS), Halskette der Tiefe an Vulo Sturmwind (SR)     |
+------------------------------------------------------------------------------------------+
```

- **Kopf** (y 0): Raid-Auswahl über W.Picker (220 px) wie die Vergaben-Seite: laufende Aufnahme
  zuerst, dann gespeicherte Raids neueste zuerst; Standard laufende Aufnahme, sonst der neueste
  Raid. Rechts (Offiziere) "Boss eintragen" (110 px) und "Discord-Text" (110 px, öffnet die Ansicht
  Discord).
- **Zahlenzeile** (y -26): aus `ns.KillCount`, `ns.MemberCount`, `ns.LateCount`, Bank; Teile nur
  wenn > 0. Ohne Raid: "Noch kein Raid aufgezeichnet.".
- **Ansichten** (Chips, y -48, gewählte golden, gemerkt bis zum Ausloggen):
  - **Verlauf:** Liste (W.List, 12 Zeilen à 22 px) mit Zeilen für Aufnahmestart (`s.start`),
    Raider, die zu spät kamen ("Chorf kommt", Ergebnis "zu spät"), Eingewechselte ("Kim kommt von
    der Ersatzbank"), jeden Bossversuch (Kill grün, Wipe rot; laufender Versuch "läuft" golden) und
    Aufnahmeende (`s.last`, nur wenn die Aufnahme nicht läuft). Spalten: Zeit 0-50, Ereignis
    54-300, Ergebnis 304-380, Dauer 384-430, Dabei 434-480, Quelle 484-602 ("Kampf", "Kampf
    (Ende)", "Lootfenster", "von Hand"). Lootfenster-Kills zeigen die Zeit grau mit "ca.".
    Ein Klick auf einen Bossversuch wählt ihn; darunter der **Detailbereich** (W.ScrollText, 4
    Zeilen): Name, Ergebnis, Zeit, Dauer; "Dabei (n):" mit Namen (Klassenfarbe aus `s.members`;
    "wird nach dem Kampf gelesen" bei `wait`); "Nicht dabei:" Raider aus `s.members`, die vor dem
    Ende schon da waren oder erst danach kamen ("kam 21:40"); "Ersatzbank:"; "Loot:" die Vergaben,
    die `ns.KillFor` diesem Kill zuordnet. Offiziere haben dort "Löschen" (StaticPopup "Diesen
    Eintrag aus dem Raid-Log löschen?").
  - **Ersatzbank:** oben (Offiziere) eine Eingabezeile `[Name v] [Notiz          ] [Eintragen]`:
    W.Picker (200 px) mit `ns.BenchSuggestions`, W.LineEdit (200 px), Knopf (90 px). Ohne
    laufende Aufnahme und ohne gewählten alten Raid steht davor "Für heute, vor dem Raid:" und es
    gilt `benchNext`. Liste (10 Zeilen à 22 px): Name (Klassenfarbe), seit (HH:MM), wie
    ("selbst, !bench" oder "von Vuloo"), Notiz, "eingewechselt 21:40" wenn `joined`, rechts ein
    Chip "x" (Offiziere, entfernt). Darunter "In der Gruppe, nicht in der Instanz: Bob, Kim" mit
    Knopf "Alle eintragen" (Offiziere, nur laufende Aufnahme, nur Namen aus `s.outside` der letzten
    10 Minuten ohne Bank-Eintrag). Hinweis grau: "Raider tragen sich mit !bench im Flüster-, Raid-
    oder Gildenchat selbst ein. Es antwortet die Lootleitung." Raider-Ansicht: nur die Liste.
  - **Discord** (nur Offiziere): W.EditArea (volle Breite, Höhe 340) mit dem Text aus
    `ns.RaidSummary`, schreibgeschützt wie die Exportbox (Eingabe setzt den Text zurück und
    markiert ihn). Bei mehreren Teilen Chips "Teil 1", "Teil 2", ... über der Box. Unten grau:
    "Strg+A, Strg+C, in Discord einfügen. 1840 Zeichen." Der Text wird beim Öffnen der Ansicht und
    bei `DATA_CHANGED` neu gebaut, die Markierung beim Neubau gesetzt.
- **Boss eintragen** öffnet unter dem Knopf eine kleine Zeile im Detailbereich:
  `[Boss v] [Kill] [Wipe] [Eintragen]`. W.Picker mit den Quellnamen aus `s.drops` (ohne "?",
  sortiert nach erstem Öffnen, Text "Mutter Shahraz (Lootfenster 21:30)") und "Anderer Name"; mit
  einer Quelle gilt deren Zeit, sonst jetzt (laufende Aufnahme) bzw. `s.last` (alter Raid).
- Die Seite hört auf `DATA_CHANGED`, `SETTING`, `GROUP_ROSTER_UPDATE` (über `ns.OnEvent`, Refresh
  nur solange sichtbar). `ns.ShowRaidLog(view, sessionId)` öffnet die Seite mit einer Ansicht.

### Raids-Seite und Karte

- `ns.RaidDetailText` bekommt zwei Zeilen nach "Raider": "Bosse: Hochkriegsfürst Naj'entus 20:14,
  Supremus 20:41 (2 Wipes), ..." bzw. "keine", und "Ersatzbank: Bob, Fred" bzw. "keine".
- Karte "raid" (Übersicht): Zeile 2 nennt nach den Raidern "7 Bosse", wenn es Kills gibt. Keine
  neue Karte: die Übersicht hat 6 Plätze, in der Offiziersansicht auf Forever sind alle belegt.
- Schnellmenü (Minimap): Eintrag "Raid-Log" für alle, nach "Soft-Reserves".

## Export

Bestehende Zeilen unverändert. Neue Zeilen im `S..E`-Block nach den `AD`-Zeilen, Namen wie überall
mit `_` statt Leerzeichen, nur wenn es Einträge gibt und nicht in der alten Form (`legacy`):

```
EK <encounterID|0> <start epoch> <end epoch> <K|W> <size> <difficulty> <E|B|L|H> <boss name>
EP <encounterID|0> <end epoch> <name> <name> ...       direkt nach dem EK eines Kills mit who
BN <name> <class|UNKNOWN> <epoch> <S|O> <officer|-> [<note>]
```

- `EK`: jeder Bossversuch nach `t` sortiert; K = Kill, W = Wipe; Quelle E = Kampfereignis
  (`enc`), B = `BOSS_KILL`, L = Lootfenster, H = von Hand. Der Bossname ist das letzte Feld und darf
  Leerzeichen enthalten. Ein Kill mit `wait` schreibt sein `EP` erst, wenn `who` da ist.
- `EP`: Namen sortiert, durch Leerzeichen getrennt; gehört zum `EK` mit gleichem `enc` und `end`.
- `BN`: je Bank-Eintrag nach Name; S = selbst (`!bench`), O = Offizier; die Notiz ist das letzte
  Feld und darf Leerzeichen enthalten.
- `ns.SessionHash` deckt die neuen Zeilen mit ab (sie stehen in `sessionLines`): ein neuer Kill,
  ein gelöschter Kill oder eine Bank-Änderung macht den Raid "geändert". Die Zeilen werden in
  Core.lua mit `lines[#lines + 1] = ("EK ...` geschrieben, damit `test_export_format.py` sie findet.
- Eine ältere Seite überspringt die Zeilen: ihr `amParse` vergleicht `f[0]` exakt und hat keinen
  Sonst-Zweig; `amParseBank` liest nur `K` und `B` exakt (`BN` ist nicht `B`).

## Website (index.html)

Texte englisch. Neue Daten liegen an den Nacht-Objekten (`state.nights`, schon in `PER_GAME`), keine
neue Liste im Zustand. Dazu `state.benchMode` (global).

- **amParse:** neue Zweige `EK` (nach `cur.kills`: `{enc, start, end, ok, size, diff, src, name}`,
  Name höchstens 60 Zeichen), `EP` (setzt `present` am letzten Kill mit gleichem `enc` und `end`),
  `BN` (nach `cur.bench`: `{name, cls, at, self, by, note}`). `S` legt `kills: [], bench: []` an.
- **amNightLog(n, s, idOf)** (NEU, rein, testbar wie `amLate`): ersetzt in der Nacht `n` alle Kills
  und Bank-Einträge mit `sid === s.sid` durch die der Sitzung. `n.kills` =
  `[{sid, enc, name, start, end, ok, size, src, present: [raiderIds]}]` (Namen ohne Raider fallen aus
  `present` raus); `n.bench` = `{raiderId: {sid, at, self, note}}`. So nimmt ein neuerer Export
  desselben Raids gelöschte Kills und ausgetragene Bank-Einträge mit, ohne Grabsteine.
- **importAmisia:** Bank-Namen gehen durch `findOrAdd(name, cls)` wie Mitglieder (neue Raider werden
  angelegt); danach `amNightLog`. Bank-Einträge setzen nicht `present`.
- **amResolve:** neue Namen umfassen Bank-Namen; neues Merkmal `addsLog` (Kills oder Bank dieser
  `sid` weichen von der Nacht ab), zählt wie `addsLate` als neu.
- **amRender:** in der Loot-Spalte zusätzlich "7 boss kills · 3 on the bench", wenn vorhanden.
- **nightKills(date)** (NEU): die Kills der Nacht über alle `sid`, zusammengefasst, wenn `enc`
  (oder bei `enc` 0 der übersetzte Name `bossHere`) gleich und die Enden höchstens 180 s auseinander
  liegen; behalten wird der Eintrag mit mehr Anwesenden, Wipes werden je Boss gezählt.
- **benchOn(date)** (NEU): `{raiderId: entry}` der Nacht, ohne wer laut `presentOn(date)` da war.
- **attendance(rid)** rechnet die Ersatzbank nach `state.benchMode`:
  - `'present'` (Standard): zählt als da (`was`), dazu `bench`-Zähler.
  - `'excused'`: die Nacht fällt für diesen Raider aus Zähler und Nenner.
  - `'missed'`: zählt nicht, wird aber markiert.
  Rückgabe zusätzlich `bench`. Nächte mit `n.off` bleiben wie heute draußen.
- **Anwesenheit:** Zelle für Ersatzbank (nicht da, auf der Bank) zeigt ein "B" in eigener Farbe
  (`.bench`, gedämpftes Blau) mit Titel "on the bench" plus Notiz bzw. "signed up themselves";
  Klick ändert wie bisher die Anwesenheit. Die Spalte "Raids" bekommt einen Titel mit der Zahl der
  Bank-Nächte. Hinweistext ergänzt: "A B means the raider was on the bench; how that counts is set
  on the right." Im Seitenbereich (nur Editoren) eine Auswahl "Bench counts as": "attended" /
  "excused (left out of the rate)" / "missed". Filter `attShow` bekommt "On the bench".
- **Nachtansicht:** Kopf zeigt zusätzlich "7 bosses" und "3 bench". Neues Panel "Bosses" über
  "Who was there": je Boss Uhrzeit (`end`, "~" vor der Zeit bei `src` L), übersetzter Name
  (`bossHere`, Zonen-Tag über `BOSSZONE`), "kill" oder "n wipes", Dauer, Zahl der Anwesenden mit
  Titel aller Namen. Panel "Bench" mit Namen, Notiz und "signed up themselves". "Missing" lässt
  Bank-Raider aus und nennt sie dort.
- **nightText:** Zeilen "Bosses: Naj'entus 20:14, Supremus 20:41 (2 wipes), ..." und
  "Bench: Bob, Fred".
- **Wiederherstellen** (Backup-Import, Zeile mit `state = {version:1, ...}`): `benchMode` wird
  übernommen, wenn es einer der drei Werte ist.
- Nach der Änderung: Twin neu bauen und veröffentlichen, `python tools/twin_stamp.py --published`.
  `BUILD_ID` bleibt (keine Datendatei geändert). Die Veröffentlichung geht auch vom N100 aus.

## Einstellungen

Neuer Abschnitt `ns.RegisterSettings{ key = "raidlog", label = "Raid-Log", order = 12 }` (für alle,
einzelne Punkte nur Offiziere oder Experte):

| Pfad | Typ | Standard | Ansicht | Text |
|---|---|---|---|---|
| raidlog.track | toggle | an | alle | "Bosskämpfe aufzeichnen" (Tip: Kills und Wipes mit Uhrzeit und Anwesenden) |
| raidlog.lootKills | toggle | an | Experte | "Boss am Lootfenster erkennen" (Tip: wenn der Client keine Kampfereignisse meldet) |
| raidlog.benchChat | toggle | an | Offiziere | "Auf !bench antworten" (Tip: nur als Lootleitung, per Flüsterung) |
| raidlog.benchGuildOnly | toggle | an | Offiziere | "!bench nur für Gildenmitglieder" |
| raidlog.benchNotify | toggle | an | Offiziere | "Neue Einträge der Ersatzbank im Chat melden" |
| raidlog.discordWipes | toggle | an | Offiziere | "Wipes im Discord-Text" |
| raidlog.discordLoot | toggle | an | Offiziere | "Loot im Discord-Text" |
| raidlog.discordNames | toggle | aus | Offiziere | "Alle Anwesenden im Discord-Text nennen" |
| raidlog.discordHead | text | "" | Offiziere | "Erste Zeile im Discord-Text" (Tip: z. B. Gildenname oder eine Erwähnung) |

`raidlog.discordHead`: `validate` entfernt `|` und Zeilenumbrüche, höchstens 80 Zeichen.

## Befehle

| Befehl | Ansicht | Wirkung |
|---|---|---|
| `/amisia log` (Alias `raidlog`) | alle | Seite Raid-Log, Ansicht Verlauf |
| `/amisia log ereignisse` (Alias `events`) | alle | letzte Kampfereignisse im eigenen Chat (Prüfung im Spiel) |
| `/amisia boss <Name> [wipe]` (Alias `kill`) | Offiziere | Kill (oder Wipe) von Hand in die laufende Aufnahme, sonst in den neuesten Raid |
| `/amisia ersatz [Name] [Notiz]` (Alias `bench`) | Offiziere | ohne Name: Seite, Ansicht Ersatzbank; sonst eintragen |
| `/amisia ersatz weg <Name>` (Alias `remove`) | Offiziere | austragen |
| `/amisia discord` | Offiziere | Seite, Ansicht Discord, für die laufende Aufnahme oder den neuesten Raid |

Forever-Namen mit Leerzeichen: bei `ersatz` ist der Name das erste Wort, oder die ersten zwei
Wörter, wenn genau diese zwei einen Namen der Vorschläge ergeben; der Rest ist die Notiz. Bei
`boss` ist alles bis auf ein abschließendes `wipe` der Name.

Chat-Befehle für Raider ohne Addon: `!bench`, `!bench <Notiz>`, `!bench aus`, `!bench ?`, Alias
`!ersatz`.

## Fehlerbehandlung

- Seite und Discord-Ansicht bauen in `pcall` wie alle Seiten. Ereignis-Handler laufen über
  `ns.OnEvent`; ein Fehler darin geht an `geterrorhandler`, die Aufnahme läuft weiter.
- **Geheime Werte** (Kampfname, Raidlisten-Namen, Zone, Zielname, GUID, Chat-Absender) gehen durch
  `ns.Plain` und werden nie verglichen oder verkettet. Geheimer Kampfname: "Boss <encounterID>".
  Geheime Namen in der Raidliste: `who` wird später gelesen (siehe oben), nie mit Teilmengen gefüllt.
- `snapshotRoster` (Core) liest Namen und Zone heute ohne `ns.Plain`; auf Forever könnte ein
  geheimer Name im Bosskampf `ns.FullName` (String-Operationen) brechen. Baustein 6 setzt
  `ns.Plain` davor: geheime Zeilen werden übersprungen, `last` der übrigen trotzdem gesetzt.
- Fehlende APIs (`C_InstanceEncounter`, `C_RestrictedActions`, `UnitClassification`,
  `GetGuildRosterInfo`, `C_FriendList`, `C_GuildInfo.GuildRoster`): Typprüfung, die Funktion fällt
  still weg (keine Gilden- oder Freundesvorschläge, kein Lootfenster-Kill, Anwesende nach 1 s).
- Doppelte Ereignisse (zwei `ENCOUNTER_END`, `BOSS_KILL` und `ENCOUNTER_END`, Kill nach
  Lootfenster-Kill): siehe Regeln oben, nie zwei Kills desselben Kampfs innerhalb von 120 s.
- `ns.AddKill`/`ns.BenchAdd` mit ungültigen Angaben: Grund zurück, Befehl und Seite zeigen ihn.
- `ns.RaidSummary` auf einen Raid ohne alles: ein Teil mit Kopf und "Keine Bosse, kein Loot.".
- Website: `EP` ohne passendes `EK` und `BN` mit leerem Namen werden ignoriert; `state.benchMode`
  mit unbekanntem Wert gilt als `'present'`.

## Tests

Lua (`addon/tests`, Stub ergänzt: `UnitClassification` und `UnitIsDead` über `STUB.targetClass`
und `STUB.targetDead`; `C_InstanceEncounter.IsEncounterInProgress` über `STUB.encounter`;
`C_RestrictedActions.IsAddOnRestrictionActive` über `STUB.restricted`; Gildenliste
`GetNumGuildMembers`/`GetGuildRosterInfo` über `STUB.guild`; `C_GuildInfo.GuildRoster`;
`C_FriendList` über `STUB.friends`; Zone und `online` gibt es in `STUB.roster[i]` schon; Kampfereignisse
über `STUB.fire`; Tests ohne eine API über `--[[preload]]`):

- `test_raidlog.lua`: START/END ergibt Kill mit Dauer, `n`, `who` nach 1 s; END mit `success = 0`
  ergibt Wipe ohne `who`; `BOSS_KILL` allein ergibt Kill `src = "kill"`, mit END davor oder danach
  nur ein Eintrag; geheime Raidliste (`STUB.secret`) und `STUB.restricted` verzögern `who` bis
  `ADDON_RESTRICTION_STATE_CHANGED`; nach 60 s Rückfall auf `s.members`; geheimer Kampfname ergibt
  "Boss 601"; `/reload`-Ersatz mit offenem `s.pull` (Datei neu laden, gleiche Aufnahme); Rückfall
  Lootfenster nur bei "worldboss", totem Ziel und ohne Kill in 10 Minuten; späterer END ersetzt den
  Lootfenster-Kill; `ns.AddKill`/`ns.DeleteKill` in einen alten Raid ändern `s.last` nicht;
  `ns.KillFor` über Namen und über die Lootfenster-Zeit; `raidlog.track` aus zeichnet nichts;
  ohne `UnitClassification` (preload) kein Lootfenster-Kill, kein Fehler; snapshotRoster überspringt
  geheime Namen und merkt `s.outside`; Ringpuffer und `/amisia log ereignisse`.
- `test_bench.lua`: eintragen, aktualisieren, austragen; Name im Raid abgelehnt; `benchNext` ohne
  Aufnahme und Übernahme beim Start und beim Fortsetzen; altes `benchNext` fällt weg; eingewechselt
  ist nicht zu spät (`late` nil, `bench` true), ohne Bank-Eintrag schon; `ns.IsBenched` mit
  `ns.SameNameIn` (Vorname nur eindeutig); Vorschläge aus Gruppe draußen, Gilde, Freunden ohne
  Doppel und ohne Raider in der Instanz; `!bench`, `!bench <Notiz>`, `!bench aus` (eigener und
  Offiziers-Eintrag), `!bench ?`; Antwort nur als Lootleitung, Flüsterung an den rohen Absender, aus
  Gildenchat; nur Gildenmitglieder, ohne Gildenliste mit Hinweis; `ns.ReplyGate` 15 s und 20 pro
  Minute; geheimer Absender übersprungen; `/amisia ersatz Vulo Sturmwind ab 21 Uhr`.
- `test_raidtext.lua`: Kopf mit Wochentag und `raidlog.discordHead`; Bosse mit Wipes, Dauer,
  "ca." für Lootfenster, "kein Kill"; Loot je Boss über `ns.KillFor`, "Ohne Boss", Bank und
  Entzaubern, Notiz; ohne Vergaben "Geplündert"; zu spät, Ersatzbank mit eingewechselt; Escape von
  `*_~` und `|`; Teilen über 1900 Zeichen mit Kopf "(Teil 2)"; Schalter discordWipes, discordLoot,
  discordNames; nur Latin-1-Zeichen im eigenen Text.
- `test_raidlog_page.lua`: Seite baut in Offiziers- und Raider-Ansicht; Verlauf mit Start, zu spät,
  Kill, Wipe, laufendem Versuch; Detailbereich mit Dabei/Nicht dabei/Loot; Löschen mit Rückfrage;
  Boss eintragen mit Lootfenster-Quelle; Ersatzbank eintragen und entfernen, "Alle eintragen";
  Discord-Ansicht mit Teilen, nur Offiziere; Raids-Details und Karte nennen Bosse; Schnellmenü.
- `test_export.lua` (ergänzt): `EK`, `EP` direkt danach, `BN` mit Notiz; ein Raid ohne Kills und
  Bank exportiert byte-gleich zu 1.6 und behält seinen Hash; `legacy` schreibt keine neue Zeile;
  Hash ändert sich bei neuem Kill, Löschen, Bank-Änderung; `wait` schreibt kein `EP`.
- Bestehende Tests bleiben grün (insbesondere `test_late.lua`, `test_core.lua`, `test_chat.lua`,
  `test_srchat.lua`).

Python/Node (`tools/tests`):

- `test_export_format.py` (ergänzt): das echte Addon zeichnet einen Kampf (START/END), einen Wipe,
  einen Bank-Eintrag mit Notiz auf; der Seiten-Parser liest `kills`, `present`, `bench`; alle
  geschriebenen Zeilenarten werden gelesen; die alten Felder (S, M, L, I, D, A) sind mit und ohne
  die neuen Zeilen gleich.
- `test_raidlog_import.py` mit `site_raidlog.cjs` (schneidet `amParse`, `amNightLog`, `nightKills`,
  `benchOn`, `presentOn`, `lateOn`, `countedNights`, `allNights`, `attendance` aus `index.html`,
  Stubs für `state`, `bossHere`, `nights`): Import legt Kills und Bank an die Nacht; derselbe Raid
  erneut ohne einen Kill und ohne einen Bank-Eintrag entfernt beide; zweiter Aufnehmender (andere
  `sid`) ergibt in `nightKills` je Boss einen Kill; Anwesenheit in allen drei `benchMode`;
  Anwesenheit gewinnt gegen Bank; `n.off` bleibt draußen; unbekannter `benchMode` gilt als
  `'present'`.
- Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review).

## Vorschlag für den Plan (7 Aufgaben)

1. **Bossversuche:** RaidLog.lua (Ereignisse, `s.pull`, Wipes, Anwesende nach dem Kampf,
   `BOSS_KILL`, Lootfenster-Rückfall, `ns.AddKill`/`DeleteKill`/`KillFor`, Ringpuffer), Core
   (Felder anlegen, `snapshotRoster` mit `ns.Plain` und `s.outside`), Abschnitt "raidlog" (track,
   lootKills), Befehle `log`, `boss`, TOC; Stub; `test_raidlog.lua`.
2. **Ersatzbank:** Bench.lua (`BenchAdd/Remove/List/Target/Suggestions`, `IsBenched`,
   `benchNext`), `noteMember` ohne "zu spät", Übernahme beim Start und Fortsetzen; Chat.lua
   (`CHAT_MSG_GUILD`, `ns.ReplyGate`); `!bench`; Einstellungen bench*; Befehl `ersatz`;
   `test_bench.lua`.
3. **Export:** `EK`, `EP`, `BN` in `sessionLines`, Hash; `amParse`-Zweige in `index.html` (nur
   Lesen) damit `test_export_format.py` grün bleibt; `test_export.lua`, `test_export_format.py`.
4. **Website:** `amNightLog`, `importAmisia`, `amResolve`, `amRender`, `nightKills`, `benchOn`,
   `attendance` mit `benchMode`, Anwesenheit (Zelle, Auswahl, Filter, Hinweis), Nachtansicht,
   `nightText`, Wiederherstellen; `site_raidlog.cjs`, `test_raidlog_import.py`; Twin bauen (veröffentlicht
   wird in Aufgabe 7).
5. **Discord-Text:** RaidText.lua (`ns.RaidSummary`, Escape, Teilen, Wochentage), Einstellungen
   discord*, Befehl `discord`; `test_raidtext.lua`.
6. **Seite und Anschlüsse:** Pages/RaidLog.lua (Verlauf, Detailbereich, Boss eintragen, Ersatzbank,
   Discord), Raids-Details, Karte, Schnellmenü; `test_raidlog_page.lua`, `test_pages.lua` ergänzt.
7. **Auslieferung:** Version 1.7.0 (TOC, `ns.VERSION`), alle Tests (`~/.venvs/amisia/bin/python
   addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
   `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs`),
   `tools/release_addon.sh`, ZIP gegen die TOC prüfen, unabhängige Prüfung.

## Auslieferung

Version 1.7.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh` (füllt den Release-Ordner, den Syncthing sendet), im Spiel `/reload`.
Twin neu bauen, veröffentlichen und stempeln.

## Ideen aus der Recherche

Übernommen:
- Raid als Sitzung mit Beginn, Ende und Bosskills mit Zeitstempel; Export als Vertrag (nur neue
  Zeilen, nie bestehende ändern).
- Ersatzbank getrennt von "da": Spieler tragen sich mit `!bench` selbst ein, Offiziere tragen ein;
  online-Prüfung getrennt vom Raid (Gruppe draußen, Gilde online).
- Wertung getrennt vom Status: die Seite entscheidet, ob die Bank als anwesend, entschuldigt oder
  verpasst zählt; Bemerkung (Notiz) getrennt; "Nacht zählt nicht" pro Raidnacht bleibt.
- Discord-Text als fertige Zusammenfassung des Abends.

Später:
- Wertung als Prozentsatz (z. B. Bank zählt 50 %) und Zerfall über die Zeit (verlangt Brüche in der
  Anwesenheit und eine Darstellung dafür).
- AFK-Prüfung für die Ersatzbank (Rückfrage an Bank-Spieler zu einer Uhrzeit) und Bank-Abfrage per
  Addon-Nachricht (Baustein 7, Sync und Sperr-Warteschlange).
- Twinks dem Main zuordnen (die Seite kennt keine Main/Twink-Beziehung).
- Andere Ausgabeformate (CSV, BBCode, JSON, eigene Vorlagen mit Platzhaltern).
- Anwesenheit pro Boss statt pro Nacht auf der Website (die Daten dafür kommen mit `EP` schon mit).

## Nicht in Baustein 6

Kampflog, Schaden, Heilung, Tode; Erkennen von Bossen über Monster-Rufe oder eine eigene
Bosstabelle; Fortschritt über die ID-Woche und Sperren; DKP, EPGP, Wertung in Prozent, Zerfall;
AFK-Prüfung und Bank-Abfrage per Addon-Nachricht, Sync zwischen Offizieren (Baustein 7);
Twinks; Discord-Webhook oder Senden aus dem Spiel (nicht möglich), andere Formate als
Discord-Markdown; deutscher Text auf der Website; Ersatzbank für 5er-Gruppen; `!sr` auf
`ns.ReplyGate` umstellen; BiS-Abgleich (3); Karte (2).

## Offene Punkte

Nur im Spiel zu klären (dafür `/amisia log ereignisse`):

- Ob `ENCOUNTER_START`, `ENCOUNTER_END` und `BOSS_KILL` auf TBC Anniversary und auf Forever für die
  alten Raids feuern (die Doku hat sie auf beiden, FrameXML von Anniversary nutzt sie nicht). Fallen
  sie aus, tragen Lootfenster und "Boss eintragen" die Kills; Wipes gibt es dann nicht.
- Welche Namen `encounterName` liefert (lokalisiert, Kampfname wie "Der Illidari-Rat") und ob die
  Website sie über `bossHere` übersetzt; sonst stehen sie unübersetzt in der Nachtansicht.
- Ob die Raidliste (`GetRaidRosterInfo`) auf Forever im Bosskampf geheim ist und wie lange nach
  `ENCOUNTER_END` (`/dump C_RestrictedActions.IsAddOnRestrictionActive(1)` direkt nach dem Kill).
- Ob `UnitClassification` für Bosse der alten Raids auf beiden Clients `"worldboss"` liefert (für
  den Lootfenster-Rückfall).
- Ob `GetGuildRosterInfo` auf Forever vorhanden ist und wie es Namen schreibt (mit Nachnamen?);
  sonst gibt es nur Freunde und Gruppe als Vorschläge, und `!bench` nimmt jeden an (mit Hinweis).
- Ob `CHAT_MSG_GUILD` auf Forever in der Chat-Sperre geheim ist (dann gilt: nach dem Kampf erneut).
- Ob die Exportbox und die Discord-Box auf beiden Clients 2000 Zeichen und mehr fassen und sich
  mit Strg+A, Strg+C ganz kopieren lassen.
- Entschieden: die Ersatzbank zählt auf der Website standardmäßig als anwesend (umstellbar auf
  "entschuldigt" oder "verpasst"); eingewechselte Bank-Spieler sind nie zu spät; der Discord-Text
  ist deutsch und nur im Addon.
