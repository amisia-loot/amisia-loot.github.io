# Spec: Einstellungen in logische Abschnitte

Stand: 2026-10-13 · Status: freigegeben (Auftrag des Nutzers 2026-10-13: "mach deine reihenfolge") ·
Feature: F-101

## Ziel

Jede Einstellung steht in dem Abschnitt, in dem man sie sucht, und kein Abschnittsname ist mit einem
anderen zu verwechseln. Heute stehen die Schalter von "Wer braucht das?" unter "Sync und Version",
Ersatzbank und Discord-Text unter "Raid-Log", die Plus-Eins-Regeln unter "Vergaben", die Gildenwünsche der
Offiziere in der eigenen Ausrüstung, und "Ausrüstung" steht neben "Ausrüstung und Wünsche". Gelöst ist es,
wenn jede Einstellung dort steht, wo ihr Feature ist, kein gespeicherter Wert verloren geht und keine zwei
Abschnitte dieselbe Sortierzahl haben.

## Was es tut

Neue Abschnitte und Umzüge (der alte Wert zieht mit, Migrationsschritt 2, D-48):

| Bisher | Neu | Abschnitt (neu) |
|---|---|---|
| `sync.shareUpgrades`, `sync.askUpgrades`, `sync.needTooltip` | `need.share`, `need.ask`, `need.tooltip` | "Wer braucht das?" (`need`, Raid/Need.lua) |
| `awards.plusScope`, `awards.plusOrder` | `rolls.plusScope`, `rolls.plusOrder` | "Roll-Runden" (`rolls`, bisher "Rolls und Vergabe") |
| `gear.kind`, `gear.upgradeDot` | `bis.kind`, `bis.upgradeDot` | "Ausrüstung und Wünsche" (`bis`); der Abschnitt "Ausrüstung" entfällt |
| `bis.guildTooltip`, `bis.guildLootMark`, `bis.guildAward` | `wishes.tooltip`, `wishes.lootMark`, `wishes.award` | "Gildenwünsche" (`wishes`, Offiziere, Gear/GuildWishes.lua) |
| `raidlog.benchChat`, `raidlog.benchGuildOnly`, `raidlog.benchNotify` | `bench.chat`, `bench.guildOnly`, `bench.notify` | "Ersatzbank" (`bench`, Offiziere, Raid/Bench.lua) |
| `raidlog.discordWipes`, `…Loot`, `…Names`, `…Head` | `discord.wipes`, `discord.loot`, `discord.names`, `discord.head` | "Discord-Text" (`discord`, Offiziere, Raid/RaidText.lua) |

Die Sortierzahlen werden eindeutig und folgen den Reitern: erst Raid (Aufnahme 10, Raid-Log 11, Ersatzbank 12,
Discord-Text 13, Roll-Runden 20, Würfel-Fenster 21, Wer braucht das? 22, Loot-Ansage 23, Lootregeln 24,
Loot-Prio 25, Punkte 26, Soft-Reserves 27, Vergaben 28, Handel-Helfer 29, Raid-Aufstellung 30, Raid-Check 31),
dann Kalender (Raid-Anmeldung 35), Ausrüstung (Ausrüstung und Wünsche 45, Gildenwünsche 46, Drop-Daten 47,
Karte und Wegpunkt 48, Quests 49, Quellen-Sammler 50, Hersteller der Gilde 51), Gilde (Gildenbank 60,
Raidmaterialien 61), zuletzt Allgemein (Sync und Version 85, Oberfläche 90, Werkzeuge 95).

## Was es ausdrücklich nicht tut

- Keine Einstellung entfällt, keine ändert Standard, Bereich oder Wirkung; nur Ort und Pfad.
- Die drei "mit der Gilde teilen"-Schalter (Drop-Daten, Quellen-Sammler, Hersteller) bleiben in ihren
  Abschnitten: jeder gehört zu seinem Feature, ein eigener Abschnitt mit nur drei Schaltern trennte sie davon.
- Abschnittsliste nach Reitern, Zahnrad und eigene Seite Dungeons: eigener Spec
  (`2026-10-13-dungeons-einstellungen.md`).
- Kein Fensterzustand zieht um (`settings.gear.class` usw. bleiben; D-48).

## Abläufe

1. Spieler lädt 2.32.0 mit alten Einstellungen: Migrationsschritt 2 verschiebt jeden gespeicherten Wert an
   seinen neuen Pfad, dann prüft Amisia die Einstellungen wie immer. Nichts ist anders eingestellt als vorher.
2. Spieler sucht "Ersatzbank" in den Einstellungen: der Abschnitt "Ersatzbank" steht da, mit seinen drei
   Schaltern. `/amisia einstellungen discord` öffnet "Discord-Text".

## Abnahmekriterien

- Wenn du vor dem Update "Plus-Eins in der Roll-Reihenfolge" angeschaltet hattest, dann ist es nach dem
  Update unter "Roll-Runden" immer noch an.
- Wenn du die Einstellungen öffnest, dann gibt es die Abschnitte "Wer braucht das?", "Ersatzbank",
  "Discord-Text" und "Gildenwünsche" (die drei letzten in der Offiziersansicht), aber keinen Abschnitt
  "Ausrüstung" mehr; "Gewichtung" und "Upgrade-Punkt in der Tabelle" stehen unter "Ausrüstung und Wünsche".
- Wenn du `/amisia einstellungen ersatzbank` eingibst, dann öffnet sich der Abschnitt "Ersatzbank".
- Wenn du unter "Sync und Version" nachsiehst, dann stehen dort nur noch Sync- und Versionsschalter.

## Sonderfälle

Ein Wert am neuen Pfad (ein Test, eine Hand im Speicherstand) bleibt und der alte fällt weg. Ein Client mit
Amisia vor 2.32.0 und einem Speicherstand von 2.32.0 (zurückgestuft): Schema 2 ist ihm unbekannt, er lässt die
Datei, wie sie ist, und sagt es einmal im Chat (D-48); die verschobenen Einstellungen stehen für ihn auf dem
Standard. Englischer Client: Abschnittsnamen aus der Locale.

## Missbrauch/Vertrauen

Nichts. Keine Nachricht, kein Austausch; Offiziersabschnitte bleiben in der Raider-Ansicht verborgen.

## Daten

Neue Abschnitte `need`, `wishes`, `bench`, `discord`; entfallen: `gear` (die Tabelle in `docs/ARCHITECTURE.md`,
Settings registry). Migrationsschritt 2 in `Core/Migrate.lua`. Keine neuen `AmisiaDB`-Schlüssel, Nachrichten,
Exportzeilen oder Einfügeblöcke.

## Offene Fragen

Keine.

## Entscheidungen

- 2026-10-13: Plan B2 der Analyse, Auftrag "mach deine reihenfolge": Umzüge wie oben, Teilen-Schalter bleiben,
  Abschnitt "Rolls und Vergabe" heißt "Roll-Runden".
