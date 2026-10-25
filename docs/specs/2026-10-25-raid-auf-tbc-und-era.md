# Spec: Raid-Teil auf TBC Anniversary und Classic Era

Stand: 2026-10-25 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-126

## Ziel

Amisia soll auch auf TBC Anniversary und Classic Era (mit SoD und Hardcore) laufen, aber nur mit dem
Raid-Teil: Aufnahme, Loot, Vergaben, Rolls, Soft-Reserves, Abgleich, Aufstellung, Raid-Check, Kalender
und die Einstellungen dafür. Ausrüstung, Dungeons, Talente, Sammeln, Karte und Duelle bleiben nur auf
Forever. Wunsch des Nutzers am 2026-10-25 mit einem Screenshot (2.46.1 auf TBC/Classic: Reiter ragen
rechts über das Fenster, die Felder "20:00" und "60" stehen versetzt, das rote X steht weit rechts).
Gelöst ist es, wenn das Fenster auf allen drei Clients sauber aussieht und auf TBC/Era nur die
Raid-Reiter zeigt.

## Was es tut

- **TOC:** eine `Amisia.toc` mit `## Interface: 16001, 20506, 11509` (Forever, TBC 2.5.6, Era 1.15.9).
  Die Forever-Dateien (Collect/*, Gear/*, Core/Duels.lua, die Seiten Ausrüstung, Dungeons, Raids
  (Ausrüstung), Karte, Berufe, Quests, Talente, Magierrollen, Duelle, Werkzeuge, GoalsWindow, SlotCard,
  DuelInfo) bekommen `[AllowLoadGameType camelot]` wie heute schon die Daten. Auf TBC/Era gibt es sie
  dann gar nicht: keine Seiten, Befehle, Hooks, Gildennachrichten. Die Reiter Ausrüstung und PvP und
  ihre Einstellungsgruppen fallen von selbst weg.
- **Ein Schalter:** `ns.GAME` ("forever", "tbc", "era") aus `WOW_PROJECT_ID`, dazu `ns.FOREVER`.
  `ns.Visible` blendet alles mit `forever = true` außerhalb von Forever aus (z. B. die Einstellungen
  Talent- und Zielgröße, die Seite Export, siehe Frage 1).
- **Aussehen auf TBC/Era:**
  - Die Reiter unter dem Fenster bekommen ihre Breite von Amisia selbst. Die Classic-Vorlage rechnet
    die Ränder doppelt, dadurch wird jeder Reiter etwa 140 px breit.
  - Die Pfeile der Zahlenfelder bekommen einen Ersatz, wo es die Forever-Grafik
    `common-dropdown-a-button` nicht gibt. Heute fehlen sie, deshalb steht "60" eingerückt.
  - Das gleiche gilt für Fensterhintergrund und Einlagen (`Profession-*`, `common-insideframe`).
- **Auf allen Clients:** Das rote X zum Zurücksetzen einer Einstellung steht direkt rechts neben ihrem
  Feld, nicht in einer festen Spalte 160 px weiter.
- **Item-Tooltips** (SR, HR, frühere Vergaben): Auf TBC/Era laufen Item-Tooltips noch über
  `OnTooltipSetItem`, deshalb hängt sich Amisia dort an diesen Weg.

## Was es ausdrücklich nicht tut

- Keine Ausrüstung, Dungeons, Talente, Berufe, Quests, Karte, Sammeln, Duelle auf TBC/Era und keine
  Daten für diese Clients (keine neuen Tabellen-Exporte, D-03 bleibt).
- Keine Website für TBC/Era: kein neuer Spielwähler, kein Ledger. Das TBC-Archiv bleibt Archiv (D-01).
- Kein Abgleich zwischen den Clients: Die Realms sind getrennt, Addon-Nachrichten kommen nie hinüber.
- SavedVariables von TBC/Era kommen nicht auf den N100 zurück.
- Mists, Retail und andere Clients bleiben weg.

## Abläufe

1. Der Nutzer legt am PC zwei Verknüpfungen von `VuloSync\Amisia` nach `_anniversary_\Interface\AddOns\Amisia`
   und `_classic_era_\Interface\AddOns\Amisia` an (einmalig, ich schreibe den Befehl dazu).
2. Login auf TBC: Amisia lädt ohne "veraltet". Unten stehen die Reiter Raid, Gilde, Kalender, Amisia,
   sauber unter dem Fenster.
3. Raidabend auf TBC: Aufnahme, Loot-Ansage, Rolls, Vergaben und Soft-Reserves laufen wie auf Forever.
   Der Abgleich läuft nur mit Gildenmitgliedern auf demselben Client.
4. Auf Forever ändert sich nichts außer dem roten X.

## Abnahmekriterien

- Wenn du dich auf TBC Anniversary oder Classic Era einloggst, dann lädt Amisia ohne "veraltet", und
  unten stehen nur Raid, Gilde, Kalender, Amisia, alle innerhalb der Fensterbreite.
- Wenn du dort Einstellungen, Raid, Aufnahme öffnest, dann stehen "20:00" und das Feld "60" mit
  sichtbaren Pfeilen bündig untereinander, und das rote X steht direkt rechts neben dem Häkchen.
- Wenn du auf TBC/Era mit der Maus über ein Item fährst, das soft-reserviert ist, dann steht die
  SR-Zeile im Tooltip (braucht: Soft-Reserve-Liste).
- Wenn du auf TBC/Era `/amisia selbsttest` eingibst, dann meldet er den Client und keine fehlenden
  Pflicht-Vorlagen.
- Wenn du auf Forever das Fenster öffnest, dann sieht alles aus wie vorher (Snapshots unverändert,
  bis auf das rote X).

## Sonderfälle

- Era mit Hardcore/SoD: Das ist derselbe Client mit derselben Interface-Nummer, also kein eigener Zweig.
- Vorhandene AmisiaDB von TBC aus der Zeit vor D-01: Die Migrationen laufen wie auf Forever. Schlüssel
  der Forever-Seiten bleiben liegen und werden nicht gelesen.
- Bosskampf: `C_RestrictedActions` gibt es auf beiden Clients. Wo die Sperre fehlt, ist sie einfach nie aktiv.
- Raid-Check auf TBC/Era: Die Buff-Liste kommt aus Forever-Daten, siehe Frage 4.
- Handel-Helfer: liest die Handelszeit aus `C_TooltipInfo`, das es auf TBC/Era nicht gibt, siehe Frage 3.
- Plündern-Verlauf (`C_LootHistory`) fehlt auf TBC/Era. Die R-Zeilen haben dort keinen Verlaufsteil.

## Missbrauch/Vertrauen

Nichts Neues: dieselben Nachrichten, Ränge und Deckel wie auf Forever. Einfügeblöcke der Website tragen
das Spiel "forever" und werden auf TBC/Era weiter abgelehnt (`OWN_GAME = ns.GAME`). Ein Export von
TBC/Era kann nicht im Forever-Ledger landen (Frage 1).

## Daten

- Keine neuen `AmisiaDB`-Schlüssel, Nachrichten, Blob-Arten oder Exportzeilen (bei Frage 1, Vorschlag).
- Die TOC bekommt die Interface-Liste und die camelot-Tags.
- DECISIONS: D-01 wird geändert ("Forever plus Raid-Teil auf TBC/Era", altes Wort "nie wieder" in einem
  Satz unter Folge). Neue Regel D-57 sagt, welche Dateien nur auf Forever laden und wie der Schalter heißt.
- Tests: `tests/test_forever_only.lua` und die Verträge `test_toc_is_forever_only` /
  `test_no_tbc_client_left_in_the_addon` werden zu "Forever-Teile nur mit camelot-Tag". Neu ist ein
  TBC-Lauf der Lua-Tests: ohne camelot-Dateien muss der Raid-Teil allein laden.
- ARCHITECTURE: Teile-Tabelle, TOC, Machines (Verknüpfungen auf dem PC).

## Offene Fragen

1. **Export zur Website auf TBC/Era?** Der Export-Kopf `#AMISIA 2` trägt kein Spiel. Ein TBC-Export
   würde auf der Seite im Forever-Ledger landen. Vorschlag: Export-Seite und Export-Erinnerung auf
   TBC/Era ausblenden. Die Alternative wäre eine Spiel-Zeile im Export und ein TBC/Era-Ledger auf der
   Seite (viel mehr Arbeit).
2. **Reiter Gilde (Bank, Mitglieder) auf TBC/Era?** Vorschlag: behalten. Beide hängen nicht an
   Forever-Daten.
3. **Handel-Helfer auf TBC/Era?** Vorschlag: ausblenden. Ohne Handelszeit findet er nichts. Später ginge
   ein Scan-Tooltip als Ersatz.
4. **Raid-Check Buffs auf TBC/Era?** Vorschlag: Die Buff-Ansicht dort ausblenden. Haltbarkeit,
   Itemlevel, Verzauberungen und Raid-IDs bleiben. Eine TBC-Buffliste bräuchte einen Tabellen-Export
   vom TBC-Client.

## Entscheidungen

- 2026-10-25: Nutzer wählt "Nur Raid-Teil + sauberes UI" (statt voll unterstützen oder nur UI-Fehler).
