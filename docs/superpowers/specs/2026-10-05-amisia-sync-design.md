# Amisia 2.1: Gilden-Sync und Versionsprüfung

Stand 2026-10-05. Baustein 7 von 7 (Reihenfolge der Umsetzung laut Nutzer: 5, 4, 6, 3, 2, 7), der
erste Baustein nach dem Umbau auf "nur WoW Forever" (`docs/superpowers/specs/2026-10-05-amisia-forever-only-design.md`).
Baut auf Baustein 1 (Registry, Widgets, Hauptfenster), 5 (Vergabebuch mit Kennung, Grabsteinen,
Rückgängig, Plus-Eins), 4 (Chat-Warteschlange `ns.Say`, Sperre `ns.ChatLocked`, `ns.IsLootLead`), 6
(Bosskills, Ersatzbank, `ns.ReplyGate`) und 3 (`ns.BisGain`, Wünsche) auf. Ändert nur das Addon
`addon/Amisia` und seine Tests (`addon/tests`, `run.py`). Export, Website, Twin und Supabase ändern
sich nicht.

Wort-Hinweis: "Hüter" heißt in diesem Entwurf der eine Client, der den Stand eines Raids hält und
verteilt (in der Regel die Lootleitung). "Stand" ist die laufende Nummer dieses Stands (`rev`).
"Abbild" ist der vollständige Stand eines Raids, den der Hüter auf einmal sendet. "Sperre" ist die
Kampfsperre von Forever, in der Addon-Nachrichten nicht gesendet werden dürfen.

## Ziel

Bis 2.0 arbeitet jeder Client für sich. Die Bausteine 3 bis 6 haben deshalb ausdrücklich auf
Baustein 7 verschoben:

- Vergaben und Plus-Eins zwischen Offizieren abgleichen (Baustein 5); Ersatzbank und Bosskills
  zwischen Offizieren (Baustein 6).
- Raider sehen die Vergaben anderer im Spiel, nicht nur auf der Website (Baustein 5, Raider-Ansicht).
- "Für wen ist dieser Drop ein Upgrade?" aus den eigenen Rechnungen der Raider (Baustein 3).
- Versionsprüfung: wer in Gilde und Raid welche Amisia-Version hat (Baustein 1).

Baustein 7 bringt:

- **Eine robuste Nachrichtenschicht** (Comm.lua): zwei Präfixe, Umschlag mit Protokollnummer,
  Zerlegen großer Daten in Teile, eine Sendeschlange mit eigener Drosselung je Präfix, die in der
  Sperre wartet, Fehlercodes auswertet und nach Drosselung erneut sendet.
- **Versionsprüfung:** wer in Raid und Gilde welche Version hat, ein einmaliger Hinweis auf eine
  neuere Version, eine Liste auf der Seite "Über und Befehle".
- **Raid-Abgleich mit einem Hüter:** die Lootleitung hält den Stand des laufenden Raids (Vergaben
  mit Kennung, Änderungen und Grabsteinen, Plus-Eins, Ersatzbank, Bosskills) und sendet ihn nach
  jeder Änderung als vollständiges Abbild mit Prüfsumme. Andere Offiziere schicken ihre Änderungen an
  den Hüter; zwei gleichzeitige Änderungen derselben Vergabe ergeben einen sichtbaren Konflikt statt
  stiller Verluste.
- **Raider sehen alle Vergaben** ihres Raids (nur lesend, ohne Offiziersnotizen) und ihr eigenes
  Plus-Eins.
- **"Wer braucht das?":** die Lootleitung fragt beim Ansagen, und jeder Raider-Client antwortet aus
  seiner eigenen Wertung, ob das Item für ihn ein Upgrade oder ein Wunsch ist.

## Rahmen und Entscheidungen

- **Client, Bibliotheken, Schrift:** nur WoW Forever 1.60.1 (TOC 16001). Keine fremden
  Bibliotheken (kein fremdes Nachrichten-, Serialisier- oder Packmodul). UI- und Chat-Texte deutsch,
  nur Latin-1 (ä ö ü ß und "·", kein Gedankenstrich, keine Auslassungspunkte, keine Pfeile),
  Code-Kommentare englisch. Anmeldung nur über `ns.RegisterPanel`, `ns.RegisterCard`,
  `ns.RegisterSettings`, `ns.RegisterSlash`; Offiziersteile über `ns.IsOfficerView()`. Werte aus
  Ereignissen und APIs gehen durch `ns.Plain`; Namen werden über `ns.SameName`/`ns.SameNameIn`
  verglichen. Neue oder geänderte Texte unten sind wörtlich gemeint.
- **Keine anderen Addons nennen**, weder in UI-Texten, Chat, Kommentaren noch Commits. Im Entwurf
  heißen sie "andere Raid-Addons".
- **Ein Hüter, ganze Abbilder, keine Einzelschritt-Verschmelzung.** In anderen Raid-Addons ist der
  schrittweise Abgleich zwischen Offizieren in der Praxis auseinandergelaufen; ein einzelner,
  maßgeblicher Client, der seinen ganzen Stand verteilt, war robuster. Amisia macht es so: der Hüter
  sendet nach jeder Änderung (gebündelt) das ganze Abbild des Raids mit Stand und Prüfsumme. Wer eine
  andere Prüfsumme hat, fragt nach. Andere Offiziere ändern nicht selbst am gemeinsamen Stand,
  sondern schicken einen Änderungswunsch an den Hüter; der entscheidet und verteilt das Ergebnis.
- **Wer Hüter ist:** ein Client, der Lootleitung ist (`ns.IsLootLead()`, also Plündermeister, sonst
  Schlachtzugsleiter, oder `loot.lead = "me"`), eine laufende Aufnahme hat, Sync eingeschaltet hat
  und selbst Offiziersrang hat (siehe Vertrauen). Melden sich mehrere, gilt für alle Clients dieselbe
  Reihenfolge: Plündermeister vor Schlachtzugsleiter vor allen anderen, bei Gleichstand der Name
  alphabetisch. Ohne Hüter arbeitet jeder Offizier für sich wie in 2.0 und schickt seine Änderungen,
  sobald ein Hüter da ist.
- **Nur der laufende Raid wird abgeglichen.** Schlüssel ist die Raidnacht plus Instanz
  (`"2026-10-05:409"`, `ns.RaidKey(s)`), nicht die Raid-Kennung `s.id`, die jeder Client selbst
  vergibt. Änderungen an älteren Raids bleiben lokal; die Website gleicht sie wie bisher über die
  feste Kennung der Vergabe ab (`amKey`).
- **Nichts geht verloren.** Eine Vergabe, die nur ein Offizier hat (zum Beispiel von Hand
  eingetragen, bevor ein Hüter da war), wird beim ersten Abbild als Änderungswunsch an den Hüter
  geschickt, nicht überschrieben. Löschungen sind Grabsteine und wandern mit.
- **Kennungen bleiben gleich.** Ein abgeglichener Offizier exportiert dieselben Vergaben mit
  denselben Kennungen wie der Hüter; die Website erkennt sie über `amKey` als dieselben. Export,
  Website und Twin ändern sich nicht.
- **Vertrauen über die Gildenliste, nicht über Behauptungen.** Den Absender einer Addon-Nachricht
  setzt der Server; ein Client kann keinen fremden Namen vortäuschen. Geprüft wird darum, ob der
  Absender in der eigenen Gilde steht und sein Rang laut Gildenliste ein Offiziersrang ist
  (`C_Club`-Mitgliedsdaten, Rangrechte über `C_GuildInfo.GuildControlGetRankFlags`). Was eine
  Nachricht über ihren Absender sagt (Ansicht, Lootleitung), dient nur der Anzeige und der
  Hüterwahl unter schon geprüften Offizieren. Daten von Spielern außerhalb der Gilde werden
  ignoriert, auch Versionsmeldungen.
- **Offiziersnotizen bleiben bei Offizieren.** Das Abbild für den Raidkanal enthält Vergaben ohne
  Notiz, ohne ersten Empfänger und ohne "von Hand"; Notizen, Ersatzbank und Bosskills gehen per
  Flüsterung nur an geprüfte Offiziere in der Gruppe.
- **Pack- und Kodierfunktionen des Clients.** Forever hat `C_EncodingUtil` (CBOR, Deflate,
  Base64); Blizzards eigener Code nutzt genau diese Kette (`SerializeCBOR` -> `CompressString` ->
  `EncodeBase64`). Amisia schreibt keinen eigenen Serialisierer und keinen Packer. Fehlt
  `C_EncodingUtil` (Typprüfung), bleibt der Raid-Abgleich aus; Versionsprüfung und "Wer braucht das?"
  gehen weiter, weil ihre Nachrichten reiner Text sind.
- **Sperre:** in der Kampfsperre (Bosskampf) wird nichts gesendet. Die Schlange wartet, bis die
  Sperre endet; bei Abbildern bleibt nur das neueste je Raid in der Schlange. Eingehende Nachrichten
  mit Raid-Daten werden in der Sperre nur gesammelt und nach der Sperre geprüft, weil die
  Gildenliste (`C_Club`) in der Sperre geheim ist.
- **Nie im Schlachtfeld, nie `INSTANCE_CHAT`, kein Dauerfunk in der Gilde.** In Schlachtfeldern und
  Arenen sendet Amisia nichts. Der Raidkanal wird nur in einer eigenen Raidgruppe benutzt
  (`IsInRaid(LE_PARTY_CATEGORY_HOME)`), nie der Instanzkanal. In den Gildenkanal geht genau eine
  Versionsmeldung pro Sitzung (nach dem Login) und eine Versionsfrage nur auf Knopfdruck, höchstens
  alle 5 Minuten; Antworten gehen per Flüsterung. Es gibt keinen regelmäßigen Gruß in der Gilde.
- **Kein Präfix-Wechsel zum Umgehen der Drosselung.** Andere Raid-Addons verteilen ihren Verkehr auf
  viele Präfixe; Amisia nutzt genau zwei (Steuerung und Daten), hält die Grenze je Präfix selbst ein
  und hält große Daten klein (CBOR, Deflate).
- **"Wer braucht das?" ist drin**, als letzte Aufgabe. Es braucht nur zwei kurze Textnachrichten und
  liest auf Raider-Seite die vorhandene Wertung (`ns.BisGain`). Fällt die Aufgabe aus Zeitgründen weg,
  ist der Rest vollständig.
- **Version 2.1.0**, Sync-Protokoll 1 (`ns.SYNC_PROTO = 1`, `ns.SYNC_MIN_PROTO = 1`).

## Dateien

```
addon/Amisia/Comm.lua           NEU: Präfixe, Umschlag, Zerlegen und Zusammensetzen, Sendeschlange
                                mit Drosselung je Präfix, Sperre, Fehlercodes, Schlachtfeld-Sperre,
                                Empfangsgrenzen je Absender, Verteilung an Handler
addon/Amisia/Trust.lua          NEU: Gildenliste (C_Club, sonst GetGuildRosterInfo), Offiziersränge,
                                Absendername auf Gruppen- und Gildennamen abbilden
addon/Amisia/Version.lua        NEU: Versionsmeldung und -frage, gesehene Versionen, Hinweis auf
                                neuere Version, Befehl version
addon/Amisia/Sync.lua           NEU: Raid-Schlüssel, Hüterwahl, Abbild bauen, prüfen, senden und
                                anwenden, Änderungswünsche, Konflikte, Abschnitt "sync", Befehl sync
addon/Amisia/Need.lua           NEU: "Wer braucht das?" (Frage, Antwort, Anzeige, Tooltip-Zeile)
addon/Amisia/Awards.lua         meldet jede Änderung an ns.SyncNote; ns.AwardsQuiet(fn) für
                                angewandte fremde Änderungen (kein Rückgängig-Eintrag, keine Meldung);
                                Feld a.v (Revision der Vergabe); PlusCount nimmt die Zahl des Hüters
addon/Amisia/Bench.lua          meldet BenchAdd/BenchRemove an ns.SyncNote
addon/Amisia/RaidLog.lua        meldet AddKill/DeleteKill und neue Kills an ns.SyncNote
addon/Amisia/Core.lua           ns.VERSION "2.1.0"; s.sync beim Laden gesäubert; ns.Fire("RECORDING", s)
                                beim Starten, Fortsetzen und Beenden einer Aufnahme; AmisiaDB.sync
addon/Amisia/LootAnnounce.lua   fragt beim Ansagen "Wer braucht das?" (ns.NeedAsk), wenn eingeschaltet
addon/Amisia/AwardDialog.lua    Zeile "Upgrade für:" unter der Roll-Zeile; Fensterhöhe 230 -> 248
addon/Amisia/Pages/About.lua    Versionsliste mit "Raid fragen" und "Gilde fragen"; Befehle darunter
addon/Amisia/Pages/Awards.lua   Sync-Zeile, Marke "wartet", Konfliktleiste; Raider-Ansicht mit
                                "Deine Items" und "Alle Vergaben"
addon/Amisia/Amisia.toc         Comm.lua, Trust.lua, Version.lua nach Chat.lua; Sync.lua nach
                                Bench.lua; Need.lua nach GuildWishes.lua; Version 2.1.0
addon/tests/wow_stub.lua        SendAddonMessage mit Drosselung und Sperre, RegisterAddonMessagePrefix,
                                C_EncodingUtil (Lua-Nachbau), C_Club, GuildControlGetRankFlags,
                                IsGuildOfficer, IsInGuild, LE_PARTY_CATEGORY_*, C_PvP, Enums
addon/tests/run.py              Mehr-Client-Tests: --[[clients ...]] startet je Client eine eigene
                                Laufzeit, ein Bus in Python verteilt die Nachrichten
addon/tests/test_*.lua          neue Tests (unten)
```

Unverändert: Export (`ns.ExportText`, `sessionLines`, `ns.SessionHash`), index.html, data/, Twin,
Supabase, Rolls.lua, RollFrame.lua, SoftRes.lua, Bis.lua (nur gelesen), GuildWishes.lua, Gear*,
Map*, Widgets.lua, MainFrame.lua, alle übrigen Seiten.

## Nachrichten (Comm.lua)

### Präfixe und Umschlag

- Präfix **`Amisia`** für Steuerung (kurze Nachrichten), Präfix **`AmisiaD`** für Datenteile. Beide
  werden beim Laden der Datei angemeldet (`C_ChatInfo.RegisterAddonMessagePrefix`); Ergebnis 0
  (Erfolg) oder 1 (schon angemeldet) ist in Ordnung, 2 oder 3 (ungültig, zu viele Präfixe) schaltet
  die Nachrichtenschicht ab und meldet einmal "Amisia: Addon-Nachrichten sind nicht verfügbar
  (Präfix nicht angemeldet). Sync und Versionsprüfung sind aus.".
- Jede Nachricht: `<Protokoll><Typ>` und dann Felder, getrennt durch Tabulator (`\t`). Beispiel
  `1HI\t2.1.0\t1\tO\t2026-10-05:409`. Höchstens 250 Bytes Text je Nachricht (der Client erlaubt 255;
  5 Bytes Reserve). Freitext (Notizen, Quellnamen) steht nie im Klartext einer Nachricht, sondern nur
  in gepackten Daten.
- **Protokollnummer:** eine Ziffer, `ns.SYNC_PROTO = 1`. Nachrichten mit größerer Nummer werden
  nicht gelesen; die Versionsliste merkt sich nur "neueres Protokoll gesehen". Nachrichten unter
  `ns.SYNC_MIN_PROTO` ebenso nicht. Jede Versionsmeldung trägt die eigene Mindestnummer; ist die
  eigene Nummer kleiner als die Mindestnummer eines Hüters, meldet Amisia einmal "Amisia: Deine
  Version ist zu alt für den Abgleich mit <Name>. Bitte aktualisieren."

### Typen

| Typ | Präfix | Kanal | Felder | Zweck |
|---|---|---|---|---|
| `HI` | Amisia | GUILD, RAID, WHISPER | Version, Mindestprotokoll, Kennzeichen (`O` Offiziersansicht, `L` Lootleitung, `-`), Raid-Schlüssel oder `-` | Versionsmeldung und Antwort auf `VQ` |
| `VQ` | Amisia | GUILD, RAID | Frage-Nummer (4 Hex) | Versionsfrage; Antwort `HI` per Flüsterung |
| `ST` | Amisia | RAID, WHISPER | Raid-Schlüssel, Stand, Prüfsumme (16 Hex), Kennzeichen (`K` beansprucht Hüter, `M` Plündermeister nach eigener Sicht, `-`), Amtszeit | Stand des Hüters; Anspruch auf die Hüterrolle |
| `RQ` | Amisia | WHISPER an Hüter; mit `G` auch RAID | Raid-Schlüssel, eigener Stand, Teil (`P`, `O`, `PO`), eigene Amtszeit, `G` | Abbild anfordern; mit `G`: ein neuer Hüter sammelt (siehe Nachtrag) |
| `NW` | Amisia | WHISPER an Hüter | Raid-Schlüssel, eigener Stand, Prüfsumme, eigene Amtszeit | "ich habe einen neueren Stand" bzw. Antwort auf `RQ` mit `G` ohne Neueres |
| `BL` | AmisiaD | RAID, WHISPER | Art (`SP`, `SO`, `OP`), Raid-Schlüssel, Folgenummer, Teil i, Teile n, Base64-Stück | ein Teil gepackter Daten |
| `OK` | Amisia | WHISPER | Raid-Schlüssel, Wunsch-Kennung (12 Hex), neue Revision der Vergabe | Änderungswunsch übernommen |
| `NO` | Amisia | WHISPER | Raid-Schlüssel, Wunsch-Kennung, Grund (`CONFLICT`, `GONE`, `DENIED`, `NORAID`, `BAD`), aktuelle Revision | Änderungswunsch abgelehnt |
| `UQ` | Amisia | RAID | Frage-Nummer, bis zu 8 Item-IDs mit Komma | "Wer braucht das?" |
| `UA` | Amisia | WHISPER an Fragenden | Frage-Nummer, je Item `id:art:zuwachs:prozent:slot` (Art `U` Upgrade, `W` Wunsch mit Prio im Feld zuwachs, `-` nichts), mit Komma | Antwort (passt sie nicht in 250 Bytes, in mehreren `UA` derselben Frage) |

Feldprüfungen beim Empfang (sonst wird die Nachricht still verworfen und in der Fehlersuche gezählt):
Version `^%d+%.%d+%.%d+$`, Raid-Schlüssel `^%d%d%d%d%-%d%d%-%d%d:%d+$`, Stand 0 bis 999999,
Prüfsumme `^%x+$` mit 16 Zeichen, Kennungen 12 Hex, Item-IDs 1 bis 999999, Teile `1 <= i <= n <= 60`
(bei `OP` höchstens 8).

### Daten packen (`BL`)

- Packen: `C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(t),
  Enum.CompressionMethod.Deflate))`. Base64, weil `SendAddonMessage` einen C-String nimmt (kein
  Nullbyte) und CBOR wie Deflate binär sind.
- Zerlegen in Stücke zu 200 Zeichen; Kopf `1BL\t<Art>\t<Schlüssel>\t<Folge>\t<i>\t<n>\t` hat höchstens
  45 Bytes. Höchstens 60 Teile (12.000 Zeichen Base64, etwa 9 KB gepackt). Ein größeres Abbild wird
  nicht gesendet; der Hüter meldet einmal "Amisia: Der Raid-Stand ist zu groß für den Abgleich." (im
  Test geprüft: 60 Vergaben, 40 Grabsteine, 25 Kills passen in etwa 8 Teile).
- Zusammensetzen je Absender und Folgenummer; Teile dürfen in beliebiger Reihenfolge und doppelt
  kommen. Höchstens 3 offene Sätze je Absender, zusammen höchstens 90 Teile und 18.000 Zeichen (ein
  Teil darüber verwirft seinen Satz, vor jedem Entpacken); ein Satz verfällt nach 30 s ohne neuen
  Teil. Datenteile zählen nur von Mitgliedern der eigenen Gilde (`ns.IsVerifiedMember`): ist der
  Absender nachweislich keins, fällt schon sein erster Teil weg und seine Teile werden 60 s lang
  ungelesen verworfen; ist die Gildenliste gerade nicht lesbar, wird ein fertiger Satz erst nach der
  Prüfung (`ns.TrustWait`) entpackt. Fertig:
  `DecodeBase64`, `DecompressString` (Ergebnis höchstens 64 KB, sonst verworfen), `DeserializeCBOR`,
  alles in `pcall`; danach strenge Prüfung des Inhalts (siehe "Abbild prüfen"). Ein Fehler verwirft
  den ganzen Satz, nie einen Teil davon.

### Senden

```lua
ns.CommSend(kind, fields, chan, target, opts) -> true | nil, Grund
    -- kind: "HI", "VQ", ...; fields: Liste von Strings; chan "GUILD" | "RAID" | "WHISPER"
    -- opts.ttl (Sekunden, Standard 60), opts.key (gleicher Schlüssel ersetzt einen wartenden Eintrag),
    -- opts.jitter (zufällige Verzögerung 0 bis n Sekunden vor dem ersten Versuch)
ns.CommSendBlob(art, key, tbl, chan, target, opts) -> true | nil, Grund   -- packt, zerlegt, reiht ein
ns.CommOn(kind, fn(sender, fields, chan, raw))      -- Handler für einen Typ
ns.CommOnBlob(art, fn(sender, tbl, chan, key))
ns.CommReady() -> bool          -- Präfixe angemeldet, Sync eingeschaltet
ns.CommPacking() -> bool        -- C_EncodingUtil vorhanden
ns.CommQueueSize() -> n
ns.CommHeld() -> bool           -- Sperre hält die Schlange
```

- **Drosselung je Präfix:** Vorrat 10 Nachrichten, Nachfüllen 1 pro Sekunde (bekannte Grenze der
  Classic-Clients seit 4.4.0, für Forever im Spiel zu bestätigen). Dazu ein gemeinsamer Byte-Vorrat
  von 1.000 Bytes mit 500 Bytes pro Sekunde, damit beide Präfixe zusammen nie viel auf einmal senden.
  Steuerung vor Daten: ist der Vorrat knapp, wartet zuerst der Datenteil.
- **Schlange:** höchstens 200 Einträge. Ein Ticker (0,25 s) läuft nur, solange etwas wartet.
  Einträge mit gleichem `opts.key` ersetzen sich (das Abbild eines Raids nur einmal in der Schlange,
  immer das neueste; ein ersetztes Abbild verliert auch seine noch wartenden Teile). Über 200 fällt
  zuerst der älteste Datenteil, dann die älteste Steuerung; einmal je Minute in der Fehlersuche
  gemeldet.
- **Ergebnis von `C_ChatInfo.SendAddonMessage`** (`Enum.SendAddonMessageResult`):
  - 0 `Success`: weiter.
  - 3 `AddonMessageThrottle`, 8 `ChannelThrottle`: Eintrag bleibt vorn, die Schlange pausiert 2 s,
    dann 4, 8, 16 s; nach 5 Versuchen fällt er weg (Fehlersuche).
  - 11 `AddOnMessageLockdown`: Schlange hält wie in der Sperre (unten).
  - 5 `NotInGroup`, 10 `NotInGuild`, 12 `TargetOffline`: Eintrag fällt still weg.
  - 1, 2, 4, 6, 7, 9 (ungültig, allgemeiner Fehler): Eintrag fällt weg, einmal je Minute in der
    Fehlersuche gemeldet.
  - Der Aufruf läuft in `pcall`; ein Fehler gilt wie 9. Ein Rückgabewert `true` (falls ein Client
    noch den alten Wahrheitswert liefert) gilt als 0.
- **Sperre:** vor jedem Senden `ns.CommHeld()` = `ns.ChatLocked()` oder
  `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat)` (5; fehlt die
  Funktion: nur `ns.ChatLocked()`). Freigabe bei `ADDON_RESTRICTION_STATE_CHANGED` mit Zustand 0
  (`Inactive`), ausgewertet einen Takt nach dem Ereignis (die Abfrage gibt während des Ereignisses
  immer false), und spätestens beim Ticker alle 2 s. Wartende Einträge mit abgelaufener `ttl` fallen
  beim Freigeben heraus.
- **Kanäle:** `RAID` nur mit `IsInRaid(LE_PARTY_CATEGORY_HOME)` (fehlt die Konstante: `IsInRaid()`);
  sonst fällt der Eintrag weg. `INSTANCE_CHAT`, `PARTY`, `SAY`, `CHANNEL` und `OFFICER` werden nie
  benutzt. `GUILD` nur mit `IsInGuild()`. `WHISPER` nur an einen Namen aus Gruppe oder Gilde.
- **Schlachtfeld:** in Schlachtfeldern und Arenen (`GetInstanceInfo()` Art `pvp` oder `arena`, oder
  `C_PvP.IsActiveBattlefield()`) wird nichts gesendet; Einträge warten mit ihrer `ttl` und verfallen
  meist.
- **Fehlersuche** (`sync.debug`, Expertenmodus): jede gesendete und empfangene Nachricht als graue
  Zeile "Amisia Sync: > RAID ST 2026-10-05:409 17" bzw. "< Fraktur OP ...", höchstens 20 je Minute.

### Empfangen

- Ereignis `CHAT_MSG_ADDON` (Payload `prefix, text, channel, sender, target, zoneChannelID, localID,
  name, instanceID`; laut Doku ohne Geheim-Kennzeichen). Alle Werte gehen trotzdem durch `ns.Plain`;
  ein geheimer Wert verwirft die Nachricht.
- Eigene Nachrichten (Echo im Raid- und Gildenkanal) werden am genauen eigenen vollen Namen erkannt
  (ohne Groß-/Kleinschreibung, auch mit dem eigenen Realm dahinter) und ignoriert; nie am Vornamen
  allein, sonst wäre ein anderer Charakter mit demselben Vornamen taub.
- **Absendername:** `ns.TrustName(sender)` bildet den rohen Absender auf einen Namen aus Gruppe oder
  Gilde ab: gleich über `ns.SameNameIn` mit der Gruppe als Liste, sonst (falls der Client einen
  Realm anhängt) der Teil vor dem letzten "-", wenn er so in Gruppe oder Gilde steht und das Ende der
  **eigene** Realm ist (`GetNormalizedRealmName()`, sonst `UnitFullName("player")`); ein Spieler eines
  anderen Realms wird nie für das gleichnamige Gildenmitglied gehalten. Ohne Treffer
  zählt der Absender als unbekannt: Versions- und Raid-Daten werden ignoriert. Geantwortet wird an den
  rohen Absender-Text, wie bei `!sr`.
- **Grenzen je Absender:** höchstens 40 Nachrichten in 10 s und 20 KB in einer Minute; darüber
  werden seine Nachrichten 60 s lang ignoriert (Fehlersuche: "Amisia Sync: Fraktur sendet zu viel,
  60 s ignoriert."). Grenzen je Typ zusätzlich: `VQ` je Absender einmal in 5 Minuten beantwortet,
  `RQ` je Absender einmal in 20 s (`RQ` mit `G` getrennt davon), `UQ` je Absender einmal in 5 s,
  `NW` einmal in 10 s.
- Jeder Handler läuft in `pcall`; ein Fehler geht an `geterrorhandler` und trifft keine anderen
  Handler (wie `ns.OnEvent`).

## Vertrauen (Trust.lua)

```lua
ns.TrustName(raw) -> name | nil              -- roher Absender -> Name aus Gruppe oder Gilde
ns.GuildMember(name) -> { name, rank, guid, online } | nil, "unknown"   -- rank: Rangfolge, 1 = Gildenmeister
ns.IsOfficerRank(rank) -> bool
ns.IsVerifiedOfficer(name) -> true | false | nil   -- nil: Gildenliste gerade nicht lesbar
ns.SelfIsOfficer() -> bool
ns.InMyGroup(name) -> bool
ns.RankList() -> { { rank, name, officer, members } }   -- für /amisia sync raenge
```

- **Gildenliste:** zuerst `C_Club.GetGuildClubId()`, `C_Club.GetClubMembers(clubId)` und
  `C_Club.GetMemberInfo(clubId, memberId)` (Felder `name`, `guildRankOrder`, `guid`, `presence`); so
  liest auch die Gildenliste von Forever selbst Ränge (`Blizzard_Communities/GuildRoster.lua`). Sonst
  (Typprüfung) `GetNumGuildMembers`/`GetGuildRosterInfo` wie Bench.lua (Rang = rankIndex + 1). Die
  Liste wird gemerkt und bei `GUILD_ROSTER_UPDATE`, `CLUB_MEMBER_ADDED`, `CLUB_MEMBER_REMOVED`,
  `CLUB_MEMBER_UPDATED`, `CLUB_MEMBERS_UPDATED` und `PLAYER_GUILD_UPDATE` neu gebaut, höchstens alle
  10 s; vorher fragt Amisia höchstens alle 10 s `ns.RequestGuildRoster()` (Bench.lua). `C_Club`
  liefert in der Sperre geheime Werte (`SecretInChatMessagingLockdown`): gebaut wird nur außerhalb.
- **Offiziersrang:** Einstellung `sync.officerRanks` = "auto": Rang r ist Offiziersrang, wenn
  `C_GuildInfo.GuildControlGetRankFlags(r)[22]` wahr ist. Index 22 ist der Schalter "Offiziersrang"
  der Rangverwaltung (`Blizzard_GuildControlUI.xml`, `OfficerCheckbox` mit `id="22"`;
  `GuildControlUI_RankPermissions_Update` liest `flags[self.OfficerCheckbox:GetID()]`). Plausibel ist
  das Ergebnis nur, wenn Rang 1 (Gildenmeister) als Offiziersrang gilt; sonst, oder wenn die
  Funktion fehlt oder keine Tabelle liefert, gilt der Rückfall: Ränge 1 bis zum eigenen Rang, wenn der
  Spieler selbst Offizier ist (`C_GuildInfo.IsGuildOfficer()` oder `CanEditOfficerNote()`), sonst
  Ränge 1 und 2. Mit einer Zahl 1 bis 10 in `sync.officerRanks` gelten genau die Ränge 1 bis N.
- **Geprüfter Offizier:** steht in der Gilde und hat Offiziersrang. Ist die Liste leer oder gesperrt,
  ist das Ergebnis nil: Raid-Daten dieses Absenders warten bis zu 60 s (höchstens 20 Nachrichten
  insgesamt), Amisia fragt die Gildenliste an, danach wird geprüft oder verworfen.
- **Ich selbst:** `ns.SelfIsOfficer()` prüft den eigenen Rang auf dieselbe Weise. Eine erzwungene
  Offiziersansicht (`ui.view = "officer"`) macht niemanden zum Offizier für andere; der eigene Client
  beansprucht die Hüterrolle nur mit Offiziersrang.
- **Wer wem was schickt und was annimmt:**

  | Daten | Sender | Empfänger nimmt an, wenn |
  |---|---|---|
  | `HI`, `VQ` | jeder | Absender in der Gilde (oder in der Gruppe und in der Gilde) |
  | `ST` mit `K`, `SP`, `SO` | Hüter | Absender ist geprüfter Offizier, in der eigenen Gruppe und laut Hüterwahl der Hüter |
  | `RQ`, `OP` | Offizier | eigener Client ist Hüter; Absender geprüfter Offizier in der Gruppe (`RQ` mit Teil `P` auch von Raidern in der Gruppe und Gilde) |
  | `OK`, `NO` | Hüter | Absender ist der aktuelle Hüter |
  | `UQ` | Lootleitung | Absender geprüfter Offizier in der Gruppe, `sync.shareUpgrades` an |
  | `UA` | Raider | eigene offene Frage mit dieser Nummer, Absender in der Gruppe |

## Versionsprüfung (Version.lua)

```lua
ns.VersionSeen() -> { { name, v, p, mp, flags, where = "raid"|"guild", at } }   -- nach Gruppe, dann Name
ns.VersionNewer() -> v, name | nil       -- höchste gesehene Version über der eigenen
ns.VersionAsk(where) -> true | nil, Grund   -- "raid" | "guild"
ns.CompareVersion(a, b) -> -1 | 0 | 1
```

- **Meldung:** `HI` mit `ns.VERSION`, `ns.SYNC_MIN_PROTO`, Kennzeichen und Raid-Schlüssel der
  laufenden Aufnahme.
  - In die Gilde: einmal pro Sitzung, 20 bis 60 s (zufällig) nach `PLAYER_LOGIN`, nur mit
    `IsInGuild()`. Nach `/reload` nicht erneut (gemerkt in `AmisiaDB.sync.helloAt`, gilt 30 Minuten).
  - In den Raid: beim Eintritt in eine Raidgruppe (erstes `GROUP_ROSTER_UPDATE` mit
    `IsInRaid(LE_PARTY_CATEGORY_HOME)`) und beim Start oder Fortsetzen einer Aufnahme, 1 bis 5 s
    verzögert, höchstens einmal je 2 Minuten.
- **Frage:** `VQ` auf Knopfdruck oder per Befehl; Raid jederzeit (höchstens alle 30 s), Gilde
  höchstens alle 5 Minuten (sonst "Amisia: Die Gilde wurde gerade gefragt. Noch 3 Minuten."). Jeder
  Client antwortet mit `HI` per Flüsterung an den Fragenden, im Raid nach 0 bis 3 s, in der Gilde nach
  1 bis 15 s Zufall; demselben Fragenden höchstens einmal in 5 Minuten.
- **Gesehen:** `AmisiaDB.sync.seen[name] = { v, p, mp, flags, where, at }`; Einträge älter als 30
  Tage fallen beim Laden weg, höchstens 300 (die ältesten gehen). Nur Absender aus der Gilde.
- **Hinweis auf eine neuere Version** (`sync.outdatedWarn`, Standard an): sieht Amisia eine höhere
  Version als die eigene, einmal je Version (gemerkt in `AmisiaDB.sync.warned`): "Amisia: Es gibt eine
  neuere Version (2.1.1, gesehen bei Fraktur). Du hast 2.1.0." Zusätzlich die Zeile auf der Seite "Über
  und Befehle". Eine höhere Version wird nur gezählt, wenn sie von mindestens einem Offizier oder
  zwei verschiedenen Gildenmitgliedern kommt (ein einzelner verstellter Client löst keinen Hinweis aus).
- **Veraltet** in der Liste ist, wer eine kleinere Version als die höchste in der Gruppe gesehene
  hat, oder ein Protokoll unter der Mindestnummer des Hüters.

## Raid-Abgleich (Sync.lua)

### Hüterwahl

- **Anspruch:** ein Client beansprucht die Hüterrolle für den Raid-Schlüssel seiner laufenden
  Aufnahme, wenn `sync.enabled`, `ns.CommPacking()`, `ns.IsLootLead()`, `ns.SelfIsOfficer()` und eine
  laufende Aufnahme (`ns.Active()`) zusammenkommen. Er sendet dann `ST` mit `K` in den Raid: beim
  Start oder Fortsetzen der Aufnahme, nach jedem eigenen Abbild, alle 4 Minuten (einzige
  Wiederholung im Raid) und als Flüsterung auf ein `HI` eines neuen Raidmitglieds.
- **Wahl:** jeder Client merkt sich Ansprüche der letzten 15 Minuten von geprüften Offizieren seiner
  Gruppe mit dem eigenen Raid-Schlüssel. Jede Nachricht des Hüters (`ST`, `SP`, `SO`, `OK`, `NO`)
  frischt seinen Anspruch auf; solange die Kampfsperre die Schlange hält, verfällt kein Anspruch (der
  Takt frischt alle auf, nach dem Kampf gelten wieder volle 15 Minuten). Ein Anspruch fällt weg, wenn
  der Absender die Gruppe verlässt oder ein `ST`/`HI` ohne `K` sendet. Reihenfolge: (1) Plündermeister nach eigener Sicht
  (`C_PartyInfo.GetLootMethod`, Raid-Index des Plündermeisters), (2) Schlachtzugsleiter
  (`UnitIsGroupLeader` auf dessen Raid-Einheit), (3) alle anderen; bei Gleichstand der Name (klein
  geschrieben) alphabetisch. Alle Clients rechnen dasselbe aus denselben Ansprüchen.
- **Abgeben:** sieht ein Hüter einen Anspruch, der vor ihm steht, hört er auf zu senden, meldet mit
  `sync.notify` einmal "Amisia: Vulo Sturmwind hält jetzt den Raid-Stand (Plündermeister). Deine
  Änderungen gehen an ihn." und wird Folger. Seine Änderungen ab dann gehen als Wünsche an den neuen
  Hüter.
- **Übernehmen:** ein neuer Hüter sammelt zuerst (siehe "Nachtrag: Stand vor Hüter"), übernimmt den
  neuesten Stand und sendet dann sein erstes Abbild in einer neuen Amtszeit. So läuft der Stand über
  Hüterwechsel weiter und keine Änderung des alten Hüters geht verloren.

### Abbild

Zwei Teile mit demselben Raid-Schlüssel und Stand:

```lua
-- SP: public part, RAID to everyone. Arrays are positional to keep the payload small.
{ k = "2026-10-05:409", r = 17, h = "1a2b3c4d5e6f7081", by = "Vulo Sturmwind",
  d = "2026-10-05", i = 409, z = "Geschmolzener Kern", t0 = 1759690000,      -- t0: base for times
  a = { { "651f3a2c9b04", "Fraktur", 32235, 1214, "MS", "Ragnaros", "player", 3, 2210 }, ... },
        -- id, name, item, t - t0, kind, src, to, v, edited - t0 (0 = never edited)
  g = { { "651f3a2c9b05", 32236, 1300, 2400, "Kim Eisherz" }, ... },
        -- tombstones: id, item, t - t0, deleted - t0, name
  p = { s = "week", n = { ["Fraktur"] = 2, ["Kim Eisherz"] = 1 } },        -- plus-one of the keeper
}
-- SO: officer part, WHISPER to every verified officer in the group with Amisia.
{ k = "2026-10-05:409", r = 17,
  n = { ["651f3a2c9b04"] = { "Tausch mit Vuloo", "Frakture", 1 } },       -- note, orig, manual (1/0)
  b = { ["Bob"] = { 1759689000, "MAGE", 1, "-", "ab 21 Uhr" } },           -- t, class, self, by, note
  x = { { 663, "Lucifron", 1759690100, 1759690250, 1, 40, 9, "enc" } },   -- enc, name, start, t, ok, size, diff, src
}
```

- **Prüfsumme** `ns.SyncHash(s)`: `ns.Checksum` über eine feste Textform der Vergaben und Grabsteine
  (nach Kennung sortiert, alle Felder des SP-Teils, dazu Notiz, erster Empfänger und "von Hand" aus
  dem SO-Teil), der Ersatzbank (nach Name) und der Kill-Köpfe. Raider haben keinen SO-Teil; sie
  vergleichen nur Stand und Kennungen und fragen bei höherem Stand nach.
- **Kills** gehen ohne Anwesende (`who`): jeder Aufnehmende liest sie selbst, die Website führt sie
  zusammen. Beim Anwenden werden fehlende Kills ergänzt (gleicher Kampf: gleiche `enc` und Ende
  innerhalb 120 s, wie `sameKill` in RaidLog.lua); eigene Kills werden nie gelöscht.
- **Plus-Eins:** der Hüter rechnet `ns.PlusList()` in seiner Einstellung `awards.plusScope` und
  schickt sie mit. Folger und Raider nehmen für den laufenden Raid diese Zahl (`ns.PlusCount` liest
  `s.sync.plus`, wenn die Aufnahme ein Abbild hat), sonst wie bisher die eigene Zählung.
- **Senden:** jede Änderung am laufenden Raid auf dem Hüter (Vergabe neu, geändert, gelöscht,
  wiederhergestellt, umbenannt, Rückgängig, Ersatzbank, Kill) erhöht `rev` und plant ein Abbild in
  3 s (weitere Änderungen schieben es bis höchstens 10 s nach der ersten). Dann: SP in den Raid
  (`opts.key = "SP:" .. Schlüssel`), SO per Flüsterung an jeden geprüften Offizier der Gruppe, von dem
  in dieser Sitzung ein `HI` mit Protokoll 1 kam (`opts.key = "SO:" .. Schlüssel .. ":" .. Name`).
  Beim Beenden der Aufnahme (`RECORDING` mit nil) geht ein letztes Abbild, wenn sich seit dem
  letzten etwas geändert hat.
- **Nachfragen:** ein Folger, der ein `ST` mit anderem Stand oder anderer Prüfsumme sieht (oder nach
  `/reload` keins hat), schickt nach 0 bis 3 s Zufall ein `RQ` an den Hüter, außer in den letzten
  15 s kam schon ein SP dieses Stands an. Der Hüter antwortet per Flüsterung mit SP (und SO für
  Offiziere), höchstens einmal je Absender in 20 s und höchstens 6 Antworten je Minute; mehr Anfragen
  beantwortet er durch ein Abbild in den Raid (eins für alle). Fehlt nach 30 s ein angekündigter
  Teil, fragt der Folger einmal neu.

### Abbild prüfen

Vor dem Anwenden, ganz oder gar nicht:

- `k` passt zur eigenen Aufnahme (oder dem neuesten Raid mit diesem Schlüssel innerhalb
  `record.resumeHours`); sonst wird das Abbild ignoriert (kein neuer Raid nur aus einem Abbild).
- (Amtszeit `e`, Stand `r`) größer als der eigene, oder gleich mit anderer Prüfsumme (dann gewinnt
  der Hüter); ein älteres Abbild wird nie angewandt (siehe Nachtrag).
- Typen und Grenzen: höchstens 400 Vergaben, 400 Grabsteine, 40 Bankplätze, 400 Kill-Köpfe, 80
  Plus-Eins-Namen, 16 Einträge der Abstammung. `ns.SyncBuild` hält dieselben Grenzen ein, damit das
  eigene Abbild immer die eigene Prüfung besteht: über 40 Bankplätze gehen die frühesten 40, über 400
  Kill-Köpfe bleiben zuerst die ältesten Fehlversuche, dann die ältesten Kills draußen (jeder
  Aufnehmende liest seine Bosskämpfe selbst), Kill-Köpfe außerhalb der Raidtage bleiben ganz draußen.
  Namen höchstens 48 Bytes ohne `|` und Steuerzeichen (`ns.FullName` danach nicht
  leer); Quellnamen höchstens 80 Bytes, ohne `|`; Notizen über `ns.CleanNote` (60 bzw. 40 Bytes); Art
  aus MS/OS/SR/-, Ziel aus player/bank/de; Item 1 bis 999999; Zeiten zwischen dem Raidtag minus 1
  und plus 2 Tagen; Kennungen 12 Hex, im Abbild eindeutig.
- Ein ungültiges Abbild wird verworfen, gezählt und einmal in der Fehlersuche gemeldet; Amisia fragt
  es nicht erneut an (sonst fragt ein Client mit Fehler ewig).

### Anwenden

- **Raider** (`sync.raiderAwards` an, keine Offiziersansicht oder kein Offiziersrang): `s.awards`
  und `s.gone` der passenden Aufnahme werden durch die Vergaben des Abbilds ersetzt (ohne Notiz,
  ohne ersten Empfänger, ohne "von Hand"). Eigene Vergaben, die das Abbild nicht kennt (der Raider
  war vorher selbst Plündermeister), bleiben stehen. `s.sync.plus` bekommt die Plus-Eins.
- **Offizier** (Folger): SP und SO desselben Stands zusammen; kommt SO nicht binnen 20 s, fragt er
  `RQ` mit Teil `O`. Ersetzt werden `s.awards`, `s.gone` und `s.bench`; Kills werden ergänzt.
  Danach:
  - **Eigene wartende Wünsche** (`s.sync.pending`) werden erneut auf den neuen Stand gelegt (eine
    Änderung setzt Felder einer Kennung, eine neue Vergabe kommt dazu, falls ihre Kennung fehlt, eine
    Löschung verschiebt nach `s.gone`), damit die Seite zeigt, was der Offizier getan hat, bis der
    Hüter es bestätigt oder ablehnt.
  - **Beim ersten Abbild eines Raids** (oder eines neuen Hüters): jede eigene lebende Vergabe, deren
    Kennung das Abbild weder in `a` noch in `g` kennt und für die kein Wunsch wartet, wird als
    Wunsch "add" an den Hüter geschickt. Ebenso eigene Ersatzbank-Einträge, die das Abbild nicht hat
    ("bench+").
- Alles in einem Schritt: zuerst neue Tabellen bauen und prüfen, dann tauschen; die Tabellen `s`
  selbst behalten ihre Identität (Seiten halten Verweise). Kein Eintrag auf dem Rückgängig-Stapel,
  keine Anwesenheit (`s.members` bleibt), `s.last` bleibt. Danach `ns.Fire("DATA_CHANGED")` und
  `ns.Fire("SYNC_STATE")`.

### Änderungswünsche und Konflikte

- **Melden:** Awards.lua ruft nach jeder Änderung `ns.SyncNote(op, s, info)`:
  `add` (die ganze Vergabe), `edit` (Kennung und die geänderten Felder name, kind, note, to),
  `delete`, `restore` (Kennung), `rename` (from, to, Liste der Kennungen); `ns.UndoAward` meldet jeden
  Schritt als die Änderung, die er bewirkt (zurückgenommenes Hinzufügen als `delete`, Löschen als
  `restore`, Ändern als `edit` mit allen vier Feldern). Bench.lua meldet `bench+` (Name, Eintrag) und
  `bench-` (Name), RaidLog.lua `kill+` (Kill-Kopf) und `kill-` (enc, Ende). Innerhalb von
  `ns.AwardsQuiet(fn)` (angewandte fremde Änderungen) meldet nichts.
- **Hüter:** eigene Änderungen erhöhen `a.v` der Vergabe und `rev` und planen ein Abbild.
- **Folger mit Offiziersrang:** die Änderung wirkt sofort lokal (wie in 2.0) und landet als Wunsch
  in `s.sync.pending`: `{ opid, op, base = a.v, t, tries }`, `opid` 12 Hex. Gesendet als `BL` mit Art
  `OP` per Flüsterung an den Hüter (TTL 30 Minuten, also auch über einen Bosskampf). Ohne Hüter wartet
  der Wunsch, bis einer da ist. Höchstens 200 wartende Wünsche je Raid; darüber wird der älteste
  gesendet oder, ohne Hüter, verworfen mit Hinweis.
- **Der Hüter prüft** den Absender (geprüfter Offizier in der Gruppe), den Raid-Schlüssel (sonst
  `NORAID`) und bei `edit`, `delete`, `restore` die Revision: ist `base` kleiner als `a.v` der Vergabe
  und berührt der Wunsch ein Feld, das seit `base` geändert wurde, antwortet er `NO CONFLICT`; fehlt
  die Vergabe, `NO GONE`; sonst wendet er den Wunsch über `ns.AwardsQuiet` mit den bestehenden
  Funktionen an (`ns.AddAwardTo` mit der Kennung des Absenders, `ns.EditAward`, `ns.DeleteAward`,
  `ns.RestoreAward`, `ns.RenameAwards`, `ns.BenchAdd`, `ns.BenchRemove`, `ns.AddKill`, `ns.DeleteKill`),
  erhöht `a.v`, antwortet `OK` und plant das Abbild. Ein "add", dessen Kennung schon lebt, ist ein
  Doppel und wird mit `OK` bestätigt. Jede Zeit eines Wunsches (Vergabe, Kill-Kopf) wird geprüft wie
  im Abbild: eine ganze Zahl innerhalb der Raidtage, sonst `NO BAD` (ein Kill bei 1e15 oder eine
  Vergabezeit "keine Zahl" würde sonst jedes folgende Abbild ungültig machen). Fremde Änderungen landen nicht auf dem Rückgängig-Stapel des
  Hüters; seine Seite zeigt sie mit "geändert von Fraktur" im Status.
- **`ns.AddAwardTo` mit vorgegebener Kennung:** neues optionales Feld `f.id` (12 Hex, im Raid noch
  frei, sonst wird wie bisher eine neue gewürfelt). Nur Sync nutzt es.
- **Antwort beim Folger:** `OK` entfernt den Wunsch. `NO CONFLICT` und `NO GONE` entfernen ihn, legen
  einen Konflikt in `s.sync.conflicts` an (`{ opid, id, op, mine = Felder, by = Hüter, at }`,
  höchstens 20) und setzen den lokalen Stand auf das nächste Abbild. Mit `sync.notify` einmal im Chat:
  "Amisia: Konflikt bei Fluchsicht des Sargeras: Vulo Sturmwind hat die Vergabe zuerst geändert.
  Siehe Seite Vergaben." `NO DENIED` (kein Offiziersrang laut Hüter): Wunsch weg, Chat "Amisia: Vulo
  Sturmwind nimmt deine Änderungen nicht an (kein Offiziersrang laut Gildenliste)." einmal je Raid.
  `NO BAD`, `NO NORAID`: Wunsch weg, Fehlersuche.
- **Konflikt lösen** (Seite Vergaben): "Meine übernehmen" sendet den Wunsch neu mit `base` = aktuelle
  Revision (gewinnt also); "Verwerfen" löscht den Konflikt. Konflikte verfallen beim Ende der
  Raidnacht.
- **Ohne Antwort:** ein gesendeter Wunsch wird nach 30 s erneut geschickt (höchstens 5 Mal, dann
  bleibt er wartend und die Sync-Zeile sagt "1 Änderung nicht abgeglichen"). Nach einem Hüterwechsel
  gehen alle wartenden Wünsche an den neuen Hüter.
- Raider ohne Offiziersansicht senden nie Wünsche; ihre lokalen Änderungen (selten) bleiben lokal.

### Nachtrag: Stand vor Hüter

Befund des Reviews (2026-10-05): ein Hüter, dessen Stand zurückliegt (nach `/reload`, nach einem
Verbindungsabbruch oder wenn er Hüter war und es wieder wird), überschrieb mit seinem nächsten Abbild
spätere Änderungen und Löschungen aller anderen, weil nur der Stand `r` verglichen wurde und er nur
fragte, wenn er einen höheren Stand kannte. Seitdem gilt:

- **Amtszeit:** jedes Abbild trägt (`e`, `r`): Amtszeit des Hüters und Stand; `ST` trägt die Amtszeit
  als fünftes Feld. Verglichen wird lexikografisch (erst `e`, dann `r`). `s.sync.term` speichert sie.
- **Sammeln vor dem ersten Abbild:** wer Hüter wird, fragt **immer** zuerst: `RQ` mit eigener Amtszeit
  und `G` in den Raid und per Flüsterung an jeden Offizier, den er kennt (und den bisherigen Hüter).
  Jeder Offizier mit neuerem (`e`, `r`) schickt SP und SO per Flüsterung; ein Offizier ohne Neueres
  antwortet `NW` mit seinem Stand. Haben alle Gefragten geantwortet, endet das Sammeln, sonst nach
  10 s (in der Kampfsperre bis 10 s nach ihrem Ende). Der Hüter übernimmt das neueste geprüfte
  Abbild wie ein Folger und sendet dann mit Amtszeit = höchste gesehene + 1 und Stand = höchster
  gesehener (auch eigener) + 1. Wünsche, die währenddessen kommen, warten bis danach.
- **Folger nehmen nie ein älteres Abbild:** ein Folger (Raider wie Offizier), der von seinem Hüter ein
  `ST` oder SP mit älterem (`e`, `r`) als seinem eigenen sieht, wendet nichts an und flüstert dem
  Hüter `NW` (höchstens alle 20 s). Der Hüter sammelt daraufhin erneut (höchstens alle 20 s), ebenso
  wenn ein anderer beanspruchender Offizier per `ST` einen neueren Stand zeigt. Die Amtszeit aus dem
  `NW` eines Raiders hebt die eigene höchstens um 8 (ein verstellter Client treibt sie nicht hoch).
- **Tagebuch und Abstammung:** jede Änderung des Hüters (eigene und übernommene Wünsche, auch
  Änderungen und Löschungen) steht als Wunsch mit Basis-Revision, Amtszeit und Stand in
  `s.sync.mine` (höchstens 400). Das SO trägt die Abstammung `l`: je Hüter die neueste Amtszeit und
  den Stand daraus, die der Zustand enthält (höchstens 16 Hüter; `s.sync.lin`). Ein Hüterzustand
  enthält immer seine eigenen früheren Änderungen, daher genügt ein Eintrag je Hüter.
- **Hüterrolle verloren:** wer nicht mehr Hüter ist (ein anderer gewählt, der Anspruch überholt),
  vergleicht beim ersten Abbild des neuen Hüters sein Tagebuch mit dessen Abstammung: Enthaltenes
  fällt weg, alles andere geht als Wunsch an den neuen Hüter, mit der alten Basis-Revision (so zeigt
  sich ein echter Gegensatz über den bestehenden Konflikt). Ein Hüter, der beim Sammeln einen
  fremden Stand übernimmt, legt seine nicht enthaltenen Tagebuch-Einträge selbst erneut darauf; ein
  Gegensatz wird sein eigener Konflikt (auflösen wendet ihn sofort an).
- **Zwei Hüter zugleich** (getrennte Gruppen, gleichzeitiger Anspruch): beim Wiedersehen entscheidet
  die Wahl wie immer. Ist der Zustand des Gewinners neuer, wird der Verlierer Folger und schickt seine
  Änderungen als Wünsche; ist der des Verlierers neuer, weist er das Abbild des Gewinners ab, meldet
  `NW`, der Gewinner sammelt den neueren Stand und legt seine eigenen Änderungen darauf. In beiden
  Fällen geht keine Seite verloren; dasselbe Feld auf beiden Seiten geändert wird ein Konflikt.
- **Protokoll:** bleibt 1 (2.1 ist noch nicht ausgeliefert); die neuen Felder sind angehängt, `NW`
  ist neu.

## Datenmodell und Umzug

### Raid (`AmisiaDB.sessions[i]`)

```lua
s.sync = {                          -- NEU, optional: Stand des Abgleichs dieses Raids
  key = "2026-10-05:409",
  rev = 17, hash = "1a2b3c4d5e6f7081",
  keeper = "Vulo Sturmwind",        -- Hüter beim letzten Stand; der eigene Name, wenn man selbst Hüter war
  at = 1759690300,                  -- wann angewandt oder gesendet
  plus = { s = "week", n = { ["Fraktur"] = 2 } },
  pending = { { opid = "a1b2c3d4e5f6", op = { ... }, base = 3, t = 1759690200, tries = 1 } },
  conflicts = { { opid = "...", id = "651f3a2c9b04", op = "edit", mine = { name = "Vulo" }, by = "Vulo Sturmwind", at = 1759690310 } },
  by = { ["651f3a2c9b04"] = "Fraktur" },   -- Hüter: wer eine Vergabe zuletzt per Wunsch geändert hat (Anzeige)
  term = 3,                                -- Amtszeit des Stands (Nachtrag: Stand vor Hüter)
  lin = { ["vulo sturmwind"] = { 3, 17 } },  -- Abstammung: je Hüter neueste Amtszeit und Stand darin
  mine = { { opid, op, base, term, rev, t } },  -- Tagebuch der eigenen Hüter-Änderungen (höchstens 400)
}
a.v = 3                             -- NEU, optional: Revision der Vergabe, nur vom Hüter erhöht
```

`AmisiaDB.sync = { v = 1, seen = { [name] = {...} }, warned = "2.1.1", helloAt = epoch }` (NEU).

- `s.sync`, `a.v` stehen nicht im Export und nicht in `ns.SessionHash` (`sessionLines` schreibt nur
  benannte Felder); ein exportierter Raid bleibt "exportiert", bis ein Abbild wirklich etwas ändert.
- **Umzug** beim `ADDON_LOADED` (Core.lua, in der Schleife über die Raids, ohne Versionszähler):
  `s.sync` muss eine Tabelle mit passendem `key`-Muster sein, sonst nil; `pending` behält nur Einträge
  jünger als 24 Stunden, `conflicts` nur die der laufenden Raidnacht und höchstens 20; `a.v` bleibt
  nur als Zahl >= 0. `AmisiaDB.sync` wird angelegt; `seen` gesäubert (30 Tage, 300 Einträge). Zweimal
  laden ändert nichts; bestehende Daten bleiben.

## Ereignisse und APIs

Geprüft in den Client-Quellen 1.60.1.70205 (Forever, Gethe/wow-ui-source Zweig `forever`, Commit
e3ecc27), `Blizzard_APIDocumentationGenerated` und FrameXML, am 2026-10-05.

| API / Ereignis | Forever 1.60.1 | Verwendung |
|---|---|---|
| `C_ChatInfo.RegisterAddonMessagePrefix(prefix) -> result` | dokumentiert (`ChatInfoDocumentation.lua`), `Enum.RegisterAddonMessagePrefixResult` 0 Success, 1 DuplicatePrefix, 2 InvalidPrefix, 3 MaxPrefixes | Präfixe |
| `C_ChatInfo.SendAddonMessage(prefix, message, chatType, target) -> result` | dokumentiert, `SecretArguments = NotAllowed`, `message` ist `cstring`; `Enum.SendAddonMessageResult` 0 Success, 1 InvalidPrefix, 2 InvalidMessage, 3 AddonMessageThrottle, 4 InvalidChatType, 5 NotInGroup, 6 TargetRequired, 7 InvalidChannel, 8 ChannelThrottle, 9 GeneralError, 10 NotInGuild, 11 AddOnMessageLockdown, 12 TargetOffline (`ChatConstantsDocumentation.lua`) | Senden |
| `C_ChatInfo.SendAddonMessageLogged` | dokumentiert ("logged and throttled") | nicht genutzt |
| `CHAT_MSG_ADDON` | dokumentiert, Payload `prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID`, kein `SecretInChatMessagingLockdown` (anders als `CHAT_MSG_RAID` usw.) | Empfangen |
| `C_ChatInfo.InChatMessagingLockdown()` | dokumentiert | Sperre (wie Chat.lua) |
| `C_RestrictedActions.IsAddOnRestrictionActive(type)` | dokumentiert; gibt während `ADDON_RESTRICTION_STATE_CHANGED` immer false | Sperre |
| `Enum.AddOnRestrictionType` | 0 Combat, 1 Encounter, 2 ChallengeMode, 3 PvPMatch, 4 Map, 5 Chat (`RestrictedActionsConstantsDocumentation.lua`) | Typ 5 = Addon-Chat gesperrt |
| `ADDON_RESTRICTION_STATE_CHANGED` | dokumentiert, Payload `type, state`; `Enum.AddOnRestrictionState` 0 Inactive, 1 Activating, 2 Active | Freigabe der Schlange |
| `C_EncodingUtil.SerializeCBOR`, `DeserializeCBOR`, `CompressString`, `DecompressString`, `EncodeBase64`, `DecodeBase64` | dokumentiert (`EncodingUtilDocumentation.lua`, `Environment = All`); `Enum.CompressionMethod` Deflate 0; Grenzen `EncodingDecompressSizeLimit` 100 MB, `EncodingStackSizeLimit` 100. Blizzard nutzt die Kette selbst (`Blizzard_SharedXMLBase/CvarUtil.lua`, `Blizzard_CooldownViewer/...Serialization.lua`) | Abbilder packen |
| `C_Club.GetGuildClubId`, `GetClubMembers`, `GetMemberInfo`, `GetMemberInfoForSelf` | dokumentiert, `RequiresClubsInitialized`; `GetClubMembers`/`GetMemberInfo` `SecretInChatMessagingLockdown`; `ClubMemberInfo` hat `name`, `guid`, `guildRankOrder` (luaIndex), `presence`, `isSelf` | Gildenliste mit Rang |
| `C_GuildInfo.GuildControlGetRankFlags(rankOrder) -> permissions` | dokumentiert; FrameXML liest `flags[22]` für "Offiziersrang" (`Blizzard_GuildControlUI`) | Offiziersrang |
| `C_GuildInfo.IsGuildOfficer()`, `CanEditOfficerNote()`, `GuildRoster()`, `MemberExistsByName()` | dokumentiert | eigener Rang, Liste anfordern |
| `GuildControlGetNumRanks`, `GuildControlGetRankName` | globale Funktionen, von FrameXML benutzt (nicht in der Doku) | `/amisia sync raenge` |
| `GetNumGuildMembers`, `GetGuildRosterInfo` | `GetNumGuildMembers` von FrameXML benutzt; `GetGuildRosterInfo` in Forever-FrameXML nicht mehr benutzt (offener Punkt aus Baustein 6) | Rückfall Gildenliste |
| `GUILD_ROSTER_UPDATE`, `PLAYER_GUILD_UPDATE`, `CLUB_MEMBER_ADDED/REMOVED/UPDATED`, `CLUB_MEMBERS_UPDATED` | dokumentiert | Liste neu bauen |
| `IsInGuild()` | dokumentiert (`PlayerScriptDocumentation.lua`) | Gildenkanal |
| `IsInRaid(LE_PARTY_CATEGORY_HOME)`, `IsInGroup(...)` | von FrameXML so benutzt (`UnitPositionFrameTemplates.lua`, `Blizzard_PVPUI.lua`) | nur eigene Raidgruppe |
| `C_PvP.IsActiveBattlefield()` | von FrameXML benutzt | kein Senden im Schlachtfeld |
| `GetServerTime()` | dokumentiert (`SystemTimeDocumentation.lua`) | Zeitbasis der Wünsche und Konflikte |
| `C_PartyInfo.GetLootMethod`, `UnitIsGroupLeader`, `UnitIsUnit` | wie Baustein 4 | Hüterwahl |

Nicht gefunden: eine Konstante für die Länge einer Addon-Nachricht oder die Drosselung (die Werte 255
Bytes und 10 Nachrichten je Präfix mit 1 pro Sekunde stammen aus den Classic-Clients seit 4.4.0; im
Spiel bestätigen). Der Chat-Typ `OFFICER` für Addon-Nachrichten ist nicht dokumentiert und wird nicht
benutzt.

## Seiten und Anzeige

### Seite "Über und Befehle" (Pages/About.lua)

Inhaltsfläche 602 x 478.

```
+------------------------------------------------------------------------------------------+
| Amisia 2.1.0 · Sync-Protokoll 1                                                           |  y 0
| Raid-Aufnahme, Loot, Rolls, Soft-Reserves und Export für die Amisia-Loot-Seite.           |  y -18
| Es gibt eine neuere Version: 2.1.1 (gesehen bei Fraktur). Bitte aktualisieren.            |  y -38 (nur dann, orange)
| Amisia in Raid und Gilde                                   [Raid fragen] [Gilde fragen]   |  y -62
| Raid: 14 von 20 mit Amisia · 2 veraltet · Gilde: 23 gesehen                               |  y -86
| Name                    Version   Ansicht     Wo       Zuletzt                           |  y -104
| Vulo Sturmwind          2.1.0     Hüter       Raid     21:14                             |
| Kim Eisherz             2.0.0     Raider      Raid     21:10                             |  (Version orange)
| Bob                     -         -           Raid     kein Amisia?                      |  (grau)
| ...                                          (8 Zeilen à 20 px, Mausrad)                  |
| Befehle                                                                                   |  y -290
| /amisia hilfe - alle Befehle  ...                         (ScrollText wie bisher)         |  bis unten
+------------------------------------------------------------------------------------------+
```

- Spalten: Name 6-186 (Klassenfarbe, wenn bekannt), Version 190-262, Ansicht 266-346 ("Hüter",
  "Offizier", "Raider", "-"), Wo 350-410 ("Raid", "Gilde"), Zuletzt 414-540 ("21:14" heute, sonst
  "04.10."; "kein Amisia?" für Raidmitglieder ohne Antwort 10 s nach "Raid fragen").
- Sortierung: Raid zuerst (Gruppenreihenfolge nach Name), dann Gilde nach "Zuletzt" absteigend.
  Veraltete Versionen orange, das eigene Protokoll zu alt für den Hüter rot.
- "Raid fragen" (110) nur im Raid; "Gilde fragen" (110) nur in einer Gilde, gesperrt während der
  5 Minuten (Tooltip "Wieder in 3 Minuten."). Beide gesperrt, wenn `sync.versionCheck` aus ist
  (Tooltip "Versionsprüfung ist ausgeschaltet.").
- Leer: "Noch keine anderen Amisia-Clients gesehen." Ohne Präfix: "Addon-Nachrichten sind nicht
  verfügbar."
- Die Seite hört auf `SYNC_VERSIONS` und `SYNC_STATE`, Neubau höchstens einmal je Sekunde, nur
  sichtbar.

### Seite "Vergaben" (Pages/Awards.lua), Offiziersansicht

- **Sync-Zeile** rechts in der Zahlenzeile (`O.head`, y -28; die Zahlen links auf 330 px begrenzt,
  die Sync-Zeile rechtsbündig 260 px, grau, Tooltip mit Details):
  - "Sync: du bist Hüter · 3 Offiziere" (grün)
  - "Sync: Hüter Vulo Sturmwind · Stand 17 · vor 12 s"
  - "Sync: 2 Änderungen warten auf Vulo Sturmwind" (gold)
  - "Sync: wartet auf Kampfende (4 Nachrichten)" (gold)
  - "Sync: kein Hüter im Raid" (grau, Tooltip "Die Lootleitung hat kein Amisia 2.1 oder keinen
    Offiziersrang. Jeder Offizier arbeitet für sich; die Website gleicht über die Kennung ab.")
  - "Sync: älterer Raid, Änderungen bleiben lokal" (für nicht laufende Raids)
  - "Sync: aus" (`sync.enabled` aus) bzw. "Sync: dieser Client kann nicht packen" (ohne
    `C_EncodingUtil`)
- **Marke "wartet":** Zeilen mit einem wartenden Wunsch zeigen hinter dem Gewinner grau " · wartet".
  Der Status im Bearbeitungsbereich nennt "geändert von Fraktur" für Änderungen, die der Hüter aus
  einem Wunsch übernommen hat (`s.sync.by`).
- **Konfliktleiste:** liegt im gewählten Raid ein Konflikt, steht über dem Bearbeitungsbereich (an
  der Stelle der Zeile "Hinweis", y -80 im Bereich) eine goldene Leiste 602 x 40: "Konflikt (1 von 2):
  Vulo Sturmwind hat diese Vergabe zuerst geändert: an Kim Eisherz (MS). Deine Änderung: an Vulo (OS)."
  Bei `GONE`: "Konflikt: Vulo Sturmwind hat diese Vergabe gelöscht. Deine Änderung: an Vulo (OS)."
  Knöpfe "Meine übernehmen" (130) und "Verwerfen" (90). Ein Klick auf die Leiste wählt die betroffene
  Vergabe. Gibt es keine Vergabe mehr (gelöscht und nicht übernommen), heißt der erste Knopf
  "Wiederherstellen und ändern".

### Seite "Vergaben", Raider-Ansicht

- Kopf: Chips "Deine Items" (100) und "Alle Vergaben" (110) rechts neben dem Titel; "Alle Vergaben"
  nur, wenn ein Raid ein Abbild hat (`s.sync`). Wahl in `settings.awards.raiderView` (Fensterzustand).
- "Alle Vergaben": Raid-Auswahl (W.Picker 240, Raids mit Abbild, neueste zuerst), Liste (12 Zeilen à
  22 px): Zeit 6-60, Item 64-290 (Qualitätsfarbe, Tooltip), Gewinner 294-470 (Klassenfarbe aus
  `s.members`, Bank/Entzaubern grau wie in der Offiziersansicht, der eigene Name gold), Art 474-520,
  +1 524-560 (aus `s.sync.plus`). Fuß: "Stand von Vulo Sturmwind, 21:14 · Notizen sehen nur
  Offiziere." Leer: "Für diesen Raid hat Amisia noch keine Vergaben von der Lootleitung bekommen."
- "Deine Items" wie bisher; der Text darunter heißt neu "Alle Vergaben deines Raids siehst du unter
  Alle Vergaben, ältere auf der Amisia-Loot-Seite." (nur mit Abbild, sonst wie bisher).
- Karte "Deine Items letzte Nacht" unverändert; Zeile 2 nennt mit Abbild zusätzlich "Dein
  Plus-Eins: 1".

### "Wer braucht das?" (Need.lua)

```lua
ns.NeedAsk(items) -> qid | nil, Grund       -- Liste von Item-IDs (höchstens 8)
ns.NeedOf(item) -> { up = { { name, gain, pct, slot } }, wish = { { name, prio } }, none = n, asked = n, at }
ns.NeedText(item) -> "Anna +12 % (Brust), Bob Wunsch (hoch) · 2 ohne Upgrade" | nil
```

- **Fragen:** die Lootleitung mit `sync.askUpgrades` (Standard an) fragt beim Ansagen eines
  Lootfensters (LootAnnounce.lua, nach dem Senden der Ansage) mit den angesagten Items; außerdem per
  Befehl `/amisia wer <Item-Link>` und im Vergabe-Dialog mit dem Knopf "Fragen" (60), wenn für das
  Item noch nichts vorliegt. `UQ` geht in den Raid; dieselbe Item-Liste höchstens einmal in 2 Minuten.
  `ns.NeedCanAsk()` macht dieselben Prüfungen wie `ns.NeedAsk` ohne zu fragen (true, sonst false,
  Grund und Kennung) für Knöpfe, die nur erscheinen, wenn Fragen geht.
- **Antworten:** jeder Client mit `sync.shareUpgrades` (Standard an) und Ausrüstungsdaten
  (`Gear.Available()`) rechnet je Item `ns.BisGain(id)`: Upgrade (`ns.BisIsUpgrade`) -> `U` mit
  Zuwachs (ganzzahlig), Prozent (`gain / mine * 100`, ganzzahlig, 999 bei mine 0) und Slot-Schlüssel;
  ein Wunsch (`ns.BisChar().wish[id]`) -> `W` mit Prio; sonst `-`. Eine `UA`-Flüsterung je Frage mit
  allen Items, nach 0 bis 2 s Zufall; passt sie nicht in 250 Bytes, geht sie in mehreren `UA`. Wird
  das Senden verweigert, gilt die Frage nicht als beantwortet. Besessene Items (`ns.BisOwned`) zählen
  als `-`.
- **Anzeige** (nur Offiziersansicht): Vergabe-Dialog Zeile "Upgrade für: Anna +12 % (Brust), Bob
  Wunsch (hoch) · 2 ohne Upgrade · 5 ohne Antwort" (gekürzt auf die Breite, Tooltip mit allen); im
  Gewinner-Picker hinter dem Namen "(Upgrade +12 %)". Tooltip-Zeile für Offiziere
  (`sync.needTooltip`, Standard an) über `ns.OnItemTooltip`: "Upgrade für: Anna +12 %, Bob" (wie die
  Zeile "Gewünscht:"), nur solange eine Antwort jünger als 30 Minuten vorliegt. Keine Ausgabe im
  Raidchat.
- Antworten werden 30 Minuten gemerkt (nur im Speicher). "ohne Antwort" = Raidmitglieder mit Amisia
  2.1 (laut `HI`), die nicht geantwortet haben.

## Einstellungen

Neuer Abschnitt `ns.RegisterSettings{ key = "sync", label = "Sync und Version", order = 85 }`:

| Pfad | Typ | Standard | Ansicht | Text |
|---|---|---|---|---|
| sync.enabled | toggle | an | alle | "Raid-Stand mit anderen Amisia-Clients abgleichen" (Tip: "Vergaben, Plus-Eins, Ersatzbank und Bosskills des laufenden Raids. Die Lootleitung hält den Stand.") |
| sync.raiderAwards | toggle | an | alle | "Vergaben des Raids von der Lootleitung empfangen" |
| sync.shareUpgrades | toggle | an | alle | "Der Lootleitung sagen, für welche Items ich ein Upgrade habe" |
| sync.versionCheck | toggle | an | alle | "Versionsprüfung" (Tip: "Meldet die eigene Version einmal nach dem Login an die Gilde und beim Betreten eines Raids.") |
| sync.outdatedWarn | toggle | an | alle | "Hinweis auf eine neuere Amisia-Version" |
| sync.askUpgrades | toggle | an | Offiziere | "Beim Ansagen fragen, für wen ein Item ein Upgrade ist" |
| sync.needTooltip | toggle | an | Offiziere | "Tooltip-Zeile Upgrade für" |
| sync.notify | toggle | an | Offiziere | "Hüterwechsel und Konflikte im Chat melden" |
| sync.officerRanks | choice auto/1-10 | auto | Experte | "Offiziersränge" ("Automatisch", "Rang 1", "Rang 1 bis 2", ... "Rang 1 bis 10"; Tip: "Automatisch: Ränge mit dem Recht Offiziersrang in der Rangverwaltung.") |
| sync.debug | toggle | aus | Experte | "Sync-Nachrichten im Chat (Fehlersuche)" |

`sync.enabled` aus: keine Raid-Daten senden oder annehmen, keine Wünsche, keine Antworten auf
`UQ`; die Versionsprüfung hängt nur an `sync.versionCheck`. Beides aus: Amisia sendet keine einzige
Addon-Nachricht.

## Befehle

| Befehl | Ansicht | Wirkung |
|---|---|---|
| `/amisia sync` | alle | Stand im Chat: Hüter, Stand, Prüfsumme, wartende Wünsche, Konflikte, Schlange, Sperre |
| `/amisia sync jetzt` | Offiziere | Hüter: Abbild sofort senden; Folger: beim Hüter nachfragen |
| `/amisia sync an` / `aus` | alle | `sync.enabled` |
| `/amisia sync raenge` | Offiziere | alle Gildenränge mit Name, Zahl der Mitglieder und ob sie als Offiziersrang gelten (mit Quelle "Rangrechte" oder "Rückfall") |
| `/amisia sync debug` | Experte | `sync.debug` umschalten |
| `/amisia sync selbsttest` | Experte | packt das Abbild des laufenden oder neuesten Raids, entpackt es wieder und vergleicht (prüft `C_EncodingUtil` im Spiel), nennt Größe und Teile |
| `/amisia version` (Alias `versionen`) | alle | im Raid den Raid fragen, sonst die Gilde; nach 10 s die Liste im Chat |
| `/amisia wer <Item-Link>` (Alias `upgrade`) | Offiziere | "Wer braucht das?" für ein Item; nach 5 s die Antworten im Chat |

## Fehlerbehandlung

- Jeder Handler, jedes Packen und Entpacken läuft in `pcall`; Fehler gehen an `geterrorhandler`,
  nie in das Ereignis des Clients. Ein kaputtes Abbild ändert nichts (erst bauen, dann tauschen).
- Fehlende APIs per Typprüfung: ohne `C_ChatInfo.SendAddonMessage` oder bei abgelehnten Präfixen ist
  die Nachrichtenschicht aus (Seite und Befehl sagen es); ohne `C_EncodingUtil` kein Raid-Abgleich;
  ohne `C_Club` der Rückfall `GetGuildRosterInfo`; ohne beides gilt niemand als geprüft (keine
  Raid-Daten, Versionen nur aus der Gruppe ohne Gildenprüfung werden nicht gezählt); ohne
  `GuildControlGetRankFlags` der Rückfall der Offiziersränge; ohne `ADDON_RESTRICTION_STATE_CHANGED`
  der 2-s-Takt.
- Nachrichten, die nicht ins Schema passen, werden still verworfen und in der Fehlersuche gezählt;
  der Absender wird nicht angeschrieben.
- Ein Hüter, der während eines Bosskampfs ein Abbild plant, sendet nach der Sperre nur das neueste.
  Ein Folger, der in der Sperre Teile bekommt, setzt sie zusammen, prüft den Absender aber erst nach
  der Sperre.
- Verlust einzelner Teile: das Abbild bleibt unvollständig und verfällt nach 30 s; beim nächsten
  `ST` (spätestens nach 5 Minuten) oder sofort nach dem Verfall fragt der Folger nach.
- Uhren: Zeiten in Abbildern sind die des Hüters (Epoch, wie in Vergaben schon heute); Wünsche und
  Konflikte tragen `GetServerTime()`. Keine Entscheidung hängt an verglichenen Uhrzeiten zweier
  Clients, nur an Revisionen.
- Werte aus `GetRaidRosterInfo`, `C_Club`, `C_PartyInfo` und `CHAT_MSG_ADDON` gehen durch
  `ns.Plain`; geheime Werte gelten als unbekannt.
- Texte aus dem Netz (Namen, Quellen, Notizen) werden vor der Anzeige von `|` und Steuerzeichen
  befreit, damit kein fremder Client Farb- oder Link-Codes in Seiten und Chat schieben kann.

## Tests

### Stub (`addon/tests/wow_stub.lua`)

- `C_ChatInfo.RegisterAddonMessagePrefix` (merkt die Präfixe; `STUB.prefixResult` erzwingt ein
  Ergebnis), `C_ChatInfo.SendAddonMessage` (schreibt nach `STUB.addon`, gibt `STUB.addonResult` oder:
  11 während `STUB.chatLock`, 3 wenn mehr als 10 Nachrichten je Präfix in einer Sekunde Stub-Zeit,
  sonst 0; ruft `BUS_SEND`, falls gesetzt).
- `Enum.SendAddonMessageResult`, `Enum.RegisterAddonMessagePrefixResult`, `Enum.AddOnRestrictionType`,
  `Enum.AddOnRestrictionState`, `Enum.CompressionMethod`.
- `C_EncodingUtil`: `SerializeCBOR`/`DeserializeCBOR` als eigener, deterministischer Lua-Serialisierer
  (kein echtes CBOR; Rundweg für Zahlen, Strings, Wahrheitswerte, verschachtelte Tabellen),
  `CompressString`/`DecompressString` als Rundweg mit Kennung, `EncodeBase64`/`DecodeBase64` als echtes
  Base64 in Lua. `STUB.noEncoding` nimmt alles weg (preload).
- `C_Club` (`GetGuildClubId`, `GetClubMembers`, `GetMemberInfo` aus `STUB.guild` mit `rank`),
  `C_GuildInfo.GuildControlGetRankFlags` (aus `STUB.rankFlags[rank]`), `IsGuildOfficer`, `IsInGuild`,
  `GuildControlGetNumRanks`, `GuildControlGetRankName`, `LE_PARTY_CATEGORY_HOME = 1`,
  `LE_PARTY_CATEGORY_INSTANCE = 2`, `IsInRaid(cat)`/`IsInGroup(cat)` (`STUB.instanceGroup`),
  `C_PvP.IsActiveBattlefield` (`STUB.battlefield`).

### Mehr-Client-Tests (`addon/tests/run.py`)

- Eine Testdatei, die mit `--[[clients Vulo_Sturmwind Fraktur Kim_Eisherz]]` beginnt ("_" steht für
  das Leerzeichen), bekommt je Name eine eigene Lua-Laufzeit: Stub, gemeinsamer preload-Block,
  `STUB.player` auf den Namen, Addon in TOC-Reihenfolge, `ADDON_LOADED`. Der Testtext selbst läuft
  in einer eigenen Regie-Laufzeit.
- Ein Bus in Python: jede Laufzeit bekommt `BUS_SEND(sender, prefix, text, chan, target)`. Zustellung
  über `BUS.deliver()`: `RAID` an alle Laufzeiten in `BUS.raid` (Liste von Namen, auch zurück an den
  Absender wie der Client), `GUILD` an alle in `BUS.guild`, `WHISPER` an die Laufzeit mit diesem
  Spieler; Empfang als `STUB.fire("CHAT_MSG_ADDON", prefix, text, chan, sender, target, 0, 0, "", 0)`.
- Regie-Funktionen: `C(name, code)` führt Lua-Code in der Laufzeit `name` aus und gibt Zahlen,
  Strings und Wahrheitswerte zurück (Tabellen über `STUB.dump`); `BUS.tick(s)` lässt alle Uhren in
  Schritten von 0,1 s laufen und stellt nach jedem Schritt zu; `BUS.lock(on)` setzt die Sperre in allen
  Laufzeiten und feuert `ADDON_RESTRICTION_STATE_CHANGED`; `BUS.drop(fn)` verwirft Nachrichten, für
  die `fn(msg)` wahr ist; `BUS.count(filter)` zählt gesendete Nachrichten (nach Präfix, Typ, Kanal,
  Absender, Zeitfenster).
- Einzel-Client-Tests bleiben unverändert.

### Testdateien

- `test_comm.lua`: Umschlag lesen und schreiben; Protokoll zu neu oder zu alt ignoriert; Zerlegen an
  den Grenzen (199, 200, 201 Zeichen; 60 Teile, 61 abgelehnt); Zusammensetzen in falscher Reihenfolge
  und mit Doppeln; Verfall nach 30 s; Grenzen je Absender (40 Nachrichten, 20 KB); Drosselung 10 je
  Präfix, dann 1 je Sekunde (`STUB.addon` zeitlich gezählt), Steuerung vor Daten; Ergebnis 3 und 8
  mit Pause 2, 4, 8, 16 s und Aufgabe nach 5 Versuchen; Ergebnis 11 und `STUB.chatLock` halten, Freigabe
  einen Takt nach `ADDON_RESTRICTION_STATE_CHANGED` mit Zustand 0 und per 2-s-Takt ohne Ereignis;
  `ttl` verfällt in der Sperre; gleicher Schlüssel ersetzt (auch wartende Teile); Schlachtfeld und
  Arena senden nichts; nie `INSTANCE_CHAT`, `RAID` nur in eigener Raidgruppe; Präfix-Ergebnis 3
  schaltet ab mit Meldung; eigenes Echo ignoriert; Fehler im Handler geht an `geterrorhandler`.
- `test_trust.lua`: Rang aus `C_Club`, Rückfall `GetGuildRosterInfo`; Offiziersrang über `flags[22]`,
  unplausible Flags (Rang 1 ohne) -> Rückfall eigener Rang bzw. 1 bis 2; Einstellung 1 bis N;
  Nicht-Gildenmitglied abgelehnt; leere Liste -> nil, Warten bis 60 s, dann geprüft oder verworfen;
  Sperre -> keine `C_Club`-Abfrage; `ns.TrustName` mit Nachnamen, mit angehängtem Realm, mit nur
  Vornamen (eindeutig und mehrdeutig über `ns.SameNameIn`); erzwungene Offiziersansicht macht nicht
  zum Offizier.
- `test_version.lua` (Mehr-Client: drei Clients in Gilde, zwei im Raid): Meldung nach dem Login
  einmal (Zufall 20 bis 60 s), nicht erneut nach `/reload` binnen 30 Minuten; Meldung beim
  Raideintritt; Frage im Raid und in der Gilde, Antworten per Flüsterung mit Zufallsverzögerung,
  demselben Fragenden einmal in 5 Minuten; Gildenfrage-Sperre 5 Minuten; Hinweis auf neuere Version
  einmal je Version und erst ab einem Offizier oder zwei Mitgliedern; Absender außerhalb der Gilde
  ignoriert; `seen` gesäubert (30 Tage, 300); Seite "Über und Befehle" (Zeilen, Farben, "kein
  Amisia?", Knöpfe gesperrt); alle Texte Latin-1 (Byte-Prüfung wie in den Seitentests).
- `test_sync_raid.lua` (Mehr-Client: Hüter Vulo Sturmwind als Plündermeister und Offizier, Offizier
  Fraktur, Raider Kim Eisherz, Gast Pug außerhalb der Gilde): Hüterwahl (Plündermeister vor Leiter vor
  Name, Abgeben, Übernehmen mit höherem Stand); neue Vergabe beim Hüter erreicht Fraktur mit Notiz und
  Kim ohne Notiz, gleiche Prüfsumme; Stand steigt; Löschen, Wiederherstellen, Umbenennen, Rückgängig
  beim Hüter; Ersatzbank und Kill-Köpfe nur bei Fraktur, eigene Kills bleiben, fehlende ergänzt;
  Plus-Eins des Hüters bei Kim; Kim ohne Abbild (neu geladen) fragt mit `RQ` und bekommt es per
  Flüsterung; viele `RQ` -> ein Abbild in den Raid; Sperre: drei Änderungen im Bosskampf, nach der
  Sperre genau ein Abbild (gezählte Teile); verlorener Teil -> Verfall und Nachfrage, danach gleich;
  ungültiges Abbild (zu viele Vergaben, `|` im Namen, falscher Schlüssel) ändert nichts und wird nicht
  erneut angefragt; SP von Kim (Raider) oder von Pug ignoriert; ohne `C_EncodingUtil` kein Abgleich,
  Versionsprüfung geht; Export und `ns.SessionHash` bei Fraktur nach dem Abbild gleich dem Hüter bis
  auf `S`/`M`-Zeilen (gleiche Kennungen in `A`/`AX`/`AS`/`AD`); `s.last` und `s.members` unverändert.
- `test_sync_ops.lua` (Mehr-Client wie oben): Fraktur ändert eine Vergabe -> Wunsch -> Hüter wendet
  an, `a.v` steigt, `OK`, Abbild zurück, Wunsch weg; Marke "wartet" bis dahin; gleichzeitige Änderung
  desselben Felds bei Hüter und Fraktur -> `NO CONFLICT`, Konflikt bei Fraktur, Chat einmal;
  "Meine übernehmen" gewinnt; "Verwerfen"; Änderung an verschiedenen Feldern -> kein Konflikt;
  gelöschte Vergabe -> `GONE`; Fraktur trägt ohne Hüter von Hand ein, Hüter kommt -> Wunsch "add" mit
  derselben Kennung, beim Hüter ohne Doppel; doppeltes "add" -> `OK` ohne Doppel; Wunsch von Kim
  (Rang ohne Offiziersrecht, aber erzwungene Offiziersansicht) -> `NO DENIED`; Wünsche überstehen
  `/reload` (Datei neu geladen) und Hüterwechsel; kein Rückgängig-Eintrag beim Hüter für fremde
  Änderungen; Rückgängig bei Fraktur wird zum passenden Wunsch; 5 Versuche ohne Antwort.
- `test_sync_ui.lua`: Sync-Zeile in allen Zuständen; Marke "wartet"; Konfliktleiste mit beiden
  Knöpfen und "Wiederherstellen und ändern"; Raider-Ansicht mit Chips, Raid-Auswahl, Liste, Fuß,
  Leerzustand; Karte mit "Dein Plus-Eins"; Abschnitt "sync" mit allen Einträgen; Befehle `sync`,
  `sync jetzt`, `sync raenge`, `sync selbsttest`, `version`; Latin-1.
- `test_need.lua` (Mehr-Client: Lootleitung und zwei Raider mit Ausrüstungsdaten): Ansage löst `UQ`
  aus (mit `sync.askUpgrades`), Antworten `U`, `W`, `-`; `sync.shareUpgrades` aus -> keine Antwort;
  besessene Items als `-`; Frage von einem Raider ohne Offiziersrang ignoriert; gleiche Liste nicht
  zweimal in 2 Minuten; Anzeige im Vergabe-Dialog, im Picker und in der Tooltip-Zeile; Verfall nach
  30 Minuten; Sperre hält die Frage bis nach dem Kampf; `/amisia wer`.
- Bestehende Tests bleiben grün, insbesondere `test_awards_core.lua`, `test_award_page.lua`,
  `test_bench.lua`, `test_raidlog.lua`, `test_plusone.lua`, `test_pages.lua`, `test_chat.lua`,
  `test_export.lua`, `test_registry.lua`, `test_settings_features.lua`.

Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review), mit Augenmerk auf
Drosselung und Sperre, geheime Werte, Vertrauensprüfung (kann ein Raider oder Gast Daten
unterschieben?), Datenverlust beim Anwenden und Hüterwechsel.

## Vorschlag für den Plan (8 Aufgaben)

1. **Nachrichtenschicht und Prüfstand:** Comm.lua (Präfixe, Umschlag, Zerlegen, Schlange,
   Drosselung, Sperre, Fehlercodes, Schlachtfeld, Empfangsgrenzen, Fehlersuche); Stub-Ergänzungen;
   `run.py` mit Mehr-Client-Bus und Regie-Funktionen; `test_comm.lua`, ein kleiner Bus-Test.
2. **Vertrauen:** Trust.lua (Gildenliste über `C_Club` und Rückfall, Offiziersränge über Rangrechte,
   Rückfall, Einstellung, `ns.TrustName`, Warten bei leerer Liste); `/amisia sync raenge`;
   `test_trust.lua`.
3. **Versionsprüfung:** Version.lua, Seite "Über und Befehle" mit Liste und Knöpfen, Einstellungen
   `sync.versionCheck`, `sync.outdatedWarn`, Befehl `version`; `test_version.lua`.
4. **Abbild und Hüter:** Sync.lua (Raid-Schlüssel, Hüterwahl, Abbild bauen und prüfen, Prüfsumme,
   Senden, Nachfragen, Anwenden für Raider und Offiziere), `ns.SyncNote` in Awards.lua, Bench.lua,
   RaidLog.lua, `ns.AwardsQuiet`, `a.v`, `ns.Fire("RECORDING")` in Core.lua, Umzug; `test_sync_raid.lua`.
5. **Wünsche und Konflikte:** `OP`/`OK`/`NO`, wartende Wünsche mit Neuauflegen, erstes Abbild sendet
   nur lokale Vergaben, Übernehmen beim Hüterwechsel, `f.id` in `ns.AddAwardTo`, Rückgängig als
   Wunsch, Plus-Eins des Hüters in `ns.PlusCount`; `test_sync_ops.lua`.
6. **Anzeige und Einstellungen:** Sync-Zeile, Marke "wartet", Konfliktleiste, Raider-Ansicht "Alle
   Vergaben", Karte, Abschnitt "sync", Befehle `sync ...`; `test_sync_ui.lua`.
7. **"Wer braucht das?":** Need.lua, Anschluss in LootAnnounce.lua und AwardDialog.lua, Tooltip-Zeile,
   Befehl `wer`; `test_need.lua`.
8. **Auslieferung:** Version 2.1.0 (TOC, `ns.VERSION`), alle Tests
   (`~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
   `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs`), unabhängige
   Prüfung, `tools/release_addon.sh`, ZIP gegen die TOC prüfen (fünf neue Dateien drin).

## Auslieferung

Version 2.1.0. Commits lokal pro Aufgabe; nach der unabhängigen Prüfung Push und
`tools/release_addon.sh` (füllt den Release-Ordner, den Syncthing sendet). Keine neuen Texturen und
keine XML-Datei: im Spiel reicht `/reload`. Website, Export und Twin bleiben unverändert (kein Neubau
des Twins, `BUILD_ID` bleibt). Der Abgleich wirkt erst, wenn Lootleitung und Offiziere 2.1 haben; die
Versionsliste zeigt, wer noch fehlt.

## Ideen aus der Recherche

Übernommen:
- Ein maßgeblicher Client und ganze Abbilder statt schrittweiser Verschmelzung zwischen Offizieren
  (der schrittweise Weg ist bei anderen Raid-Addons auseinandergelaufen).
- Eigene Drosselung und Auswertung der Sendeergebnisse statt blinden Sendens (Nachrichtenverlust
  durch Drosselung war ein häufiger Fehler, der nur mit `/reload` verschwand).
- Kleine Nutzlast: CBOR und Deflate des Clients, Zeiten als Abstand, Felder nach Position.
- Mindestversion im Gruß: zu alte Clients werden erkannt und gewarnt, statt still falsch zu lesen.
- Kein Raidkanal im Schlachtfeld und nie der Instanzkanal (andere Raid-Addons erzeugten dort
  "nicht in einer Schlachtzugsgruppe"-Meldungen in Massen).
- "Für wen ist das ein Upgrade" aus den Rechnungen der Raider, nicht durch Inspizieren.

Später:
- Soft-Reserve-Liste mit dem Abbild an alle Raider verteilen, damit jeder die SR-Tooltip-Zeile hat
  (Baustein 4); das Abbild nimmt neue Felder auf, ältere Clients überlesen sie.
- Raider-Fenster mit MS/OS/Passen statt `/roll`, Antworten per Addon-Nachricht (Baustein 4).
- AFK-Prüfung und Bank-Abfrage der Ersatzbank per Addon-Nachricht (Baustein 6).
- Wegpunkte an andere Spieler senden (Baustein 2).
- Gildenwünsche und Wunschlisten zwischen Clients statt über die Website.
- Abgleich älterer Raids zwischen Offizieren (heute erledigt das die Website über die Kennung).
- Items mit Zufallsbonus in "Wer braucht das?" mit ihrem Bonus statt nur der ID.

## Nicht in Baustein 7

Abgleich älterer Raids; Verteilen der Soft-Reserves, der Gildenwünsche oder der Wunschlisten;
Raider-Fenster für Würfe; AFK-Prüfung; Wegpunkte senden; Senden in Schlachtfeldern, Arenen, 5er-
Gruppen und über den Instanzkanal; regelmäßige Meldungen im Gildenkanal; Daten von Spielern außerhalb
der Gilde; eigene Serialisierer, Packer oder fremde Nachrichtenbibliotheken; mehr als zwei Präfixe;
Änderungen an Export, Website, Twin und Supabase; Anwesende der Kills im Abgleich; Abstimmung oder
Loot-Rat über Addon-Nachrichten.

## Offene Punkte

Nur im Spiel zu klären (dafür `/amisia sync debug` und `/amisia sync selbsttest`):

- **Absendername** in `CHAT_MSG_ADDON` auf Forever: "Vorname Nachname", mit angehängtem Realm
  ("Vulo Sturmwind-Realm") oder anders. `ns.TrustName` deckt beides ab; die Fehlersuche zeigt den
  rohen Text. Ebenso, ob eine Flüsterung an "Vorname Nachname" ankommt.
- **Drosselung und Länge** auf Forever: 10 Nachrichten je Präfix mit 1 pro Sekunde und 255 Bytes
  (mit oder ohne Präfix). Prüfen mit `/amisia sync selbsttest` im Raid (Abbild mit 8 Teilen
  senden lassen) und der Fehlersuche (kommt Ergebnis 3?).
- **Sperre:** ob `SendAddonMessage` im Bosskampf 11 liefert, ob
  `C_RestrictedActions.IsAddOnRestrictionActive(5)` dann wahr ist und ob `CHAT_MSG_ADDON` in der Sperre
  zugestellt wird (`/dump C_RestrictedActions.IsAddOnRestrictionActive(5)` im Bosskampf). Fällt das
  Ereignis beim Ende aus, gibt der 2-s-Takt frei.
- **Rangrechte:** ob `C_GuildInfo.GuildControlGetRankFlags(r)` auch für Mitglieder ohne
  Gildenverwaltungsrecht eine Tabelle liefert und ob Index 22 "Offiziersrang" ist
  (`/amisia sync raenge` bei einem Offizier und einem Raider vergleichen). Sonst gilt der Rückfall,
  und die Gilde stellt bei Raidern ohne Offiziersrecht `sync.officerRanks` auf die richtige Zahl.
- **`C_Club` beim Login:** ob die Gildenliste über `C_Club` gleich nach dem Login gefüllt ist
  (`RequiresClubsInitialized`); sonst greift das Warten bis 60 s.
- **`C_EncodingUtil` für Addons:** ob die Funktionen für Addon-Code ohne Fehler laufen
  (`SecretArguments = AllowedWhenUntainted`; die Argumente sind keine geheimen Werte) und wie groß ein
  echtes Abbild gepackt ist (`/amisia sync selbsttest`).
- Entschieden: ein Hüter (die Lootleitung) mit ganzen Abbildern; nur der laufende Raid; Offiziere
  ändern über Wünsche mit Revision und sichtbarem Konflikt; Raider sehen alle Vergaben ohne Notizen;
  Prüfung über Gildenrang statt Behauptung, Index 22 mit Rückfall; Gäste außerhalb der Gilde werden
  ignoriert; zwei Präfixe; Packen nur mit `C_EncodingUtil`, ohne eigenen Rückfall; eine
  Gildenmeldung pro Sitzung, keine Wiederholung; "Wer braucht das?" drin, ohne Raidchat-Ausgabe;
  Plus-Eins des laufenden Raids vom Hüter.
