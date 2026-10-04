# Amisia 1.4: Fundament und neues Hauptfenster

Stand 2026-10-04. Baustein 1 von 7. Ändert das Addon `addon/Amisia` und den Import der Seite
`index.html` (Forever-Nachnamen). Die weiteren Bausteine bekommen je einen eigenen Entwurf:
2 Karte (Wegpunkt und Pins), 3 BiS-Abgleich, 4 Loot-Ansage und SR-Check, 5 Vergaben verwalten,
6 Raid-Protokoll, 7 Gilden-Sync und Versionscheck.

## Ziel

Amisia wird von der ganzen Gilde benutzt. Das Hauptfenster soll einfach sein, alles Einstellbare
soll an einer Stelle liegen, und neue Funktionen sollen sich ohne Umbau einfügen: eine Datei
meldet ihre Seite, ihre Einstellungen und ihre Befehle an, Fenster, Einstellungsseite und Hilfe
passen sich selbst an. Dazu zwei Pflichtpunkte: Forever-Namen mit Nachnamen im Export und auf der
Seite, und zwei Fehler der Ausrüstungstabelle.

## Rahmen und Entscheidungen

- **Clients:** TBC Anniversary 2.5.6 und WoW Forever 1.60.1, ein TOC. Alles, was einem Client
  fehlt, wird zur Laufzeit geprüft. Ausrüstung und Karte gibt es nur in Forever.
- **Keine fremden Bibliotheken.** Das Fundament ist klein und eigen, nach dem Muster von OneForAll
  (Panel-Registry) und VuloForeverUI (Module, Optionen, Slash-Registry).
- **Keine Blizzard-Einstellungskategorie.** Die Einstellungen liegen im eigenen Fenster.
  `InterfaceOptions_AddCategory` fehlt in Forever, Kategorien sind dort heikel.
- **Kein UIDropDownMenu / EasyMenu.** Fehlt in Forever. Auswahllisten und das Schnellmenü sind
  eigene kleine Popups.
- **Schrift:** nur Latin-1. Symbole sind Texturen (wie `Media\Icons\dot`). Neue Texturen sind echte
  32-bit-TGA, 2er-Potenz, quadratisch, und brauchen einen vollen Neustart des Spiels.
- **Fensterebenen:** Hauptfenster und Ausrüstungstabelle FULLSCREEN mit `SetToplevel`; ein Fenster,
  das geöffnet oder angeklickt wird, kommt nach vorne (`Raise`). Roll- und Soft-Reserve-Fenster
  bleiben FULLSCREEN_DIALOG.
- **Offiziere:** wer Offiziersnotizen bearbeiten darf (`C_GuildInfo.CanEditOfficerNote`, sonst
  das globale `CanEditOfficerNote`), sieht den Offiziersbereich. Einstellung "Ansicht" kann das
  auf Offizier oder Raider festlegen. Die Aufnahme im Raid läuft bei jedem, der das Addon hat,
  unabhängig von der Ansicht.

## Dateien

```
addon/Amisia/Core.lua         Slash-Block raus (Befehle gehen an die Registry), Einstellungen über ns.Get
addon/Amisia/Registry.lua     NEU: Panels, Karten, Einstellungsschema, Slash, interne Nachrichten
addon/Amisia/Widgets.lua      NEU: gemeinsame Bausteine (Text, Knopf, Chip, Rahmen, Schalter, Regler,
                              Uhrzeit, Auswahl-Popup, Liste mit wiederverwendeten Zeilen)
addon/Amisia/MainFrame.lua    NEU: Fenster, Kopfzeile, Seitenleiste, Seitenwechsel, Skalierung, Position
addon/Amisia/Pages/Overview.lua   NEU: Übersicht mit Karten
addon/Amisia/Pages/Raids.lua      Inhalt des alten UI.lua: Raid-Liste, Details, Löschen
addon/Amisia/Pages/Export.lua     Inhalt des alten UI.lua: Exportbox, Modi
addon/Amisia/Pages/Rolls.lua      letzte Runden, Roll starten, Fenster öffnen
addon/Amisia/Pages/SoftRes.lua    Tabelle der geladenen Liste, Import/Löschen (Offizier)
addon/Amisia/Pages/Gear.lua       eigene Upgrades, Knopf zur Tabelle (nur Forever)
addon/Amisia/Pages/Bank.lua       letzte Gildenbank-Zählung
addon/Amisia/Pages/Tools.lua      Scan, Scan gear, Sammler (nur Expertenmodus)
addon/Amisia/Pages/Settings.lua   Einstellungsseite, aus dem Schema gebaut
addon/Amisia/Pages/About.lua      Version, Befehle (aus der Slash-Registry)
addon/Amisia/Names.lua        NEU: ns.FullName, Export-Kodierung von Namen
addon/Amisia/Minimap.lua      Linksklick Übersicht, Rechtsklick Schnellmenü
addon/Amisia/UI.lua           entfällt (Inhalte gehen in Pages/*)
addon/Amisia/Rolls.lua, RollFrame.lua, SoftRes.lua, Awards.lua, Collect.lua, Scan.lua,
Gear.lua, GearFrame.lua       melden ihre Einstellungen und Befehle an, lesen über ns.Get
index.html                    amParse liest #AMISIA 1 und 2, Namen mit Leerzeichen
tools/build_gear.py           Testitems ausschließen
addon/tests/*                 neue Tests, Stub ergänzt
```

Die TOC lädt Registry vor Core (Core meldet beim Laden schon an), Widgets direkt nach Core, die Feature-Dateien danach, MainFrame und
die Seiten zuletzt. Seiten werden nur angemeldet; gebaut werden sie beim ersten Öffnen.

## Registry (Registry.lua)

```lua
ns.RegisterPanel{ key, label, icon, order, officer = bool, expert = bool,
                  available = function() return bool end,     -- nil = immer
                  create = function(parent) return frame end, -- beim ersten Öffnen
                  refresh = function(frame) end }             -- nur solange sichtbar
ns.RegisterCard{ key, order, officer = bool, available = fn,
                 fill = function(card) end }                  -- Übersicht: Titel, Zeilen, ein Knopf
ns.RegisterSettings{ key = "rolls", label = "Rolls und Vergabe", order = 20, officer = bool,
                     items = { { key = "rolls.seconds", type = "slider", label, tip, default = 20,
                                 min = 5, max = 120, step = 1, expert = bool,
                                 validate = fn(v) -> v|nil, onChange = fn(v) }, ... } }
ns.Get(path) -> Wert (Standard, wenn nichts gespeichert)
ns.Set(path, value) -> true | false, Grund   -- prüft, speichert, ruft onChange, ns.Fire("SETTING", path, v)
ns.Reset(path)
ns.RegisterSlash(word, { aliases = {...}, args = "<5-120>", desc, officer = bool, run = fn(rest) })
ns.Listen(name, fn) / ns.Fire(name, ...)     -- interne Nachrichten
ns.IsOfficerView() -> bool
```

- Typen der Einstellungen: `toggle`, `slider`, `time` (HH:MM, mit `allowOff` für "aus"), `choice`
  (Werte und Texte), `text`, `button` (führt `run` aus), `desc` (nur Text).
- `ns.Set` lehnt ungültige Werte ab und meldet den Grund; gespeicherte ungültige Werte fallen beim
  Laden auf den Standard zurück.
- Die Einstellungen liegen in `AmisiaDB.settings` als verschachtelte Tabellen nach dem Pfad
  (`settings.rolls.seconds`). `AmisiaDB.settings.version = 2` markiert das neue Format.
- **Umzug** beim ersten Laden mit Version < 2: `enabled` -> `record.enabled`, `lateAt` ->
  `record.lateAt` (false bleibt "aus"), `rollSeconds` -> `rolls.seconds`, `collect` ->
  `tools.collect`, `minimap.hide` -> `ui.minimap` (umgekehrt), `minimap.angle` bleibt Fensterzustand.
  Fensterzustände (Ausrüstungsfilter, Minimap-Winkel, Fensterposition) sind keine Einstellungen im
  Schema und bleiben in `settings.gear`, `settings.minimap`, `settings.window`.
- `/amisia` ohne Wort öffnet die Übersicht, `/amisia hilfe` listet alle angemeldeten Befehle.
  Unbekannte Wörter zeigen die Hilfe. Befehle mit `officer = true` stehen nur in der Offiziershilfe,
  funktionieren aber für jeden (wie heute).

## Hauptfenster (MainFrame.lua)

- Etwa 800 x 540, verschiebbar, Position und Skalierung (`ui.scale`, 70-130 %) gespeichert, Escape
  schließt (UISpecialFrames), FULLSCREEN mit `SetToplevel`.
- Kopfzeile: Logo, "Amisia" und Version, rechts Aufnahmestatus (Punkt-Textur grün/grau/orange, Zone,
  Raider, Zu-spät) und der Knopf Pausieren/Fortsetzen, ganz rechts Schließen.
- Seitenleiste 160 px: Icon und Name je Seite, gewählte Seite golden hinterlegt; Seiten ohne
  `available()` oder mit `officer` in Raider-Ansicht fehlen; Einstellungen und "Über" unten.
- Inhalt rechts, eine Seite zur Zeit; `refresh` läuft bei Seitenwechsel, beim Öffnen und auf die
  internen Nachrichten, die die Seite abonniert.

## Seiten in Baustein 1

| Seite | Ansicht | Inhalt |
|---|---|---|
| Übersicht | alle | Karten im Raster: Aufnahme bzw. letzter Raid (Datum, Raid, Raider, Zu-spät, Mal/Herz/Edelsteine; Knopf Exportieren für Offiziere), Soft-Reserves (Anzahl, Datum, Raider im Raid ohne Reserve; Knopf Ansehen), Deine Ausrüstung (nur Forever: Level, Zahl der Upgrades, bestes Upgrade; Knopf Ansehen), Vergaben letzte Nacht (Anzahl, davon nicht exportiert), Gildenbank (Offiziere: Datum, Mal/Herz/Edelsteine), Export (Offiziere: neue oder geänderte Raids) |
| Raids | Offiziere | Raid-Liste wie heute (Datum, Raid, Raider, Mal, Herz, Edelsteine, Exportstatus), Auswahl, Alle wählen, Löschen. Ein Klick auf eine Zeile zeigt darunter Details: Raider mit Zu-spät-Zeit, Loot (`s.items`), Drops, Vergaben |
| Rolls | Offiziere | Laufende/letzte Runde, die letzten Runden mit Gewinner, Knopf Roll-Fenster, Hinweis Alt-Klick |
| Soft-Reserves | alle | Tabelle Raider - Item der geladenen Liste, Datum; Importieren und Löschen nur Offiziere |
| Ausrüstung | alle, Forever | Eigenes Level, die Upgrades je Slot gegenüber dem Angelegten mit Quelle und Zuwachs, Knopf "Tabelle öffnen" |
| Export | Offiziere | Exportbox, Knöpfe "Neue und geänderte" und "Ausgewählte", Kopierhinweis |
| Gildenbank | Offiziere | Letzte Zählung je Material, Datum, wer gezählt hat, Hinweis bei unsichtbaren Tabs |
| Werkzeuge | Expertenmodus | Scan-Status und Fortschritt, Scan starten/anhalten, Scan gear, Sammler an/aus |
| Einstellungen | alle | aus dem Schema; Offiziersabschnitte nur in der Offiziersansicht |
| Über und Befehle | alle | Version, Befehlsliste aus der Slash-Registry |

## Einstellungen in Baustein 1

| Pfad | Typ | Standard | Ansicht |
|---|---|---|---|
| record.enabled | toggle | an | alle |
| record.lateAt | time, allowOff | 20:00 | alle |
| record.keepSessions | slider 10-200 | 60 | alle |
| record.resumeHours | slider 1-6 | 2 | Experte |
| record.nightStart | time | 06:00 | Experte |
| rolls.seconds | slider 5-120 | 20 | Offiziere |
| rolls.countdown | toggle | an | Offiziere |
| rolls.channel | choice RAID_WARNING/RAID | RAID_WARNING | Offiziere |
| rolls.altClick | toggle | an | Offiziere |
| softres.tooltip | toggle | an | alle |
| softres.lootMark | toggle | an | alle |
| softres.warnDays | slider 1-30 | 7 | alle |
| bank.count | toggle | an | Offiziere |
| gear.kind | choice Speedrun/Hardcore | Speedrun | alle, Forever |
| gear.upgradeDot | toggle | an | alle, Forever |
| ui.minimap | toggle | an | alle |
| ui.scale | slider 70-130 % | 100 | alle |
| ui.resetPosition | button | - | alle |
| ui.view | choice auto/officer/raider | auto | alle |
| ui.expert | toggle | aus | alle |
| tools.collect | toggle | an | Experte |
| tools.scanRate | slider 10-1000 | 100 | Experte |

Bisherige Konstanten (`KEEP_SESSIONS`, Fortsetzungsfenster, `NIGHT_START`) werden zu diesen
Einstellungen. Befehle `spaet`, `rollzeit`, `sammeln`, `minimap`, `pause`, `scan`, `award`,
`unaward`, `roll`, `rolls`, `sr`, `gear`, `status`, `export` bleiben und schreiben über `ns.Set`.

## Minimap

Linksklick öffnet die Übersicht, Rechtsklick ein eigenes Schnellmenü (Ausrüstung in Forever,
Rolls, Soft-Reserves, Export, Einstellungen, Pausieren/Fortsetzen; Offizierseinträge nur in der
Offiziersansicht). Der Eintrag im Addon-Menü von Forever macht dasselbe.

## Forever-Nachnamen

- Forever-Charaktere heißen "Vorname Nachname" (Trennzeichen Leerzeichen, voller Name pro Region
  eindeutig). Wo der Client den Nachnamen liefert (Raidliste, `UnitName` zweiter Wert, Chat), ist
  noch zu prüfen.
- `Names.lua`: `ns.FullName(name, surnameOrRealm)` baut den Namen einheitlich ("Vorname Nachname",
  ein Leerzeichen; auf Anniversary der Name ohne Realm wie heute). Anwesenheit, Loot, Awards, Rolls
  und Soft-Reserves vergleichen nur noch über `ns.FullName`.
- Export: Namen werden mit `_` statt Leerzeichen geschrieben (Unterstrich kommt in WoW-Namen nicht
  vor). Kopf `#AMISIA 2 <Exporteur>`. Betroffen: M, L, I, A und der Exporteur. Version 1 bleibt
  lesbar.
- Seite (`index.html`): `amParse` liest Version 1 und 2, wandelt `_` in Namen zurück in ein
  Leerzeichen; `glCleanName` erlaubt ein inneres Leerzeichen. Unbekannte volle Namen laufen durch
  den bestehenden Weg "Raider hinzufügen"; gibt es genau einen Raider mit diesem Vornamen, schlägt
  die Vorschau ihn vor.
- Soft-Reserve-Import: CSV-Spalte Name unverändert, Zeilen `Name [Link]` nehmen alles vor dem Link.
- `/amisia namen`: zeigt, wie Amisia den eigenen Namen und die Namen der Gruppe liest (Rohwerte
  von `UnitName`, `GetRaidRosterInfo` und das Ergebnis von `ns.FullName`), zum Prüfen in der Beta.
- Nach der Änderung an `index.html`: Twin neu bauen und veröffentlichen, `tools/twin_stamp.py
  --published` (CLAUDE.md).

## Ausrüstung: Korrekturen

- Wert-Spalte der Liste und der Übersichtskarte: absoluter Zuwachs ("+190"). Prozent nur im
  Tooltip und nur, wenn das angelegte Item mindestens 20 Punkte hat.
- `tools/build_gear.py`: feste Ausschlussliste für Testitems (u. a. 8350 "Der Eine Ring") und
  Namensmuster (`Test`, `Monster -`, `[PH]`, `Deprecated`, `QA`).

## Fehlerbehandlung

- Jede Seite baut in `pcall`; schlägt das fehl, zeigt die Seite "Diese Seite konnte nicht geladen
  werden" mit der ersten Fehlerzeile, das Fenster bleibt benutzbar.
- `ns.Set` gibt bei ungültigen Werten den Grund zurück; Befehle melden ihn im Chat.
- Fehlende Client-APIs: Seiten mit `available()`, Funktionen mit Typprüfung wie bisher.

## Tests

- Lua (`addon/tests`, Stub ergänzt): Registry (Anmelden, Sortierung, available/officer/expert),
  Einstellungen (Standard, Prüfung, Reset, onChange, Umzug von Version 1), Slash (Aufruf, Hilfe,
  unbekanntes Wort), Fenster (Bau, Seitenwechsel, Seite mit Fehler), Offiziersansicht (auto,
  erzwungen), Namen (`ns.FullName`, Export mit Leerzeichen).
- Export-Test (`tools/tests/test_export_format.py`): das echte Addon exportiert Namen mit
  Nachnamen, der echte Seiten-Parser liest sie zurück; Version 1 bleibt lesbar.
- `tools/tests/test_build_gear.py`: Testitems fallen raus.
- Am Ende eine unabhängige Prüfung über alle Änderungen.

## Auslieferung

Version 1.4.0 in TOC und `ns.VERSION`, Synchronisieren in die WoW-Ordner, ZIP neu bauen und gegen
die TOC prüfen, Twin neu bauen und veröffentlichen. Commit und Push nach Freigabe.

## Nicht in Baustein 1

Kartenmarker, BiS-Abgleich, Loot-Ansage, SR-Erinnerung und `!sr`, Vergaben bearbeiten, Bank- und
Entzaubern-Knöpfe, Plus-Eins, Bosskills, Ersatzbank, Discord-Text, Sync und Versionscheck,
Prioritätsliste. Diese Bausteine melden sich später über dieselbe Registry an.

## Offene Punkte

- Was Forever für Namen in Raidliste, `UnitName` und Chat liefert (`/amisia namen` in der Beta).
- Ob Master Loot in Forever-Raids angeboten wird (betrifft Vergabe, nicht dieses Fenster).
