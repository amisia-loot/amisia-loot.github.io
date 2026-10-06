# Amisia: Vergleich mit der angelegten Ausrüstung und Aussehen-Hinweis

Stand 2026-10-06. Zwei der vom Nutzer gewählten Vorschläge (9 "Upgrade-% gegen das Angelegte"
und 4 "Aussehen-Hinweis im Roll-Fenster"). Baut auf der Wertung aus Baustein 3
(`2026-10-05-amisia-bis-design.md`: `Bis.lua`, `ns.BisGain`, Tooltip-Hook `ns.OnItemTooltip`) und
auf "Wer braucht das?" aus Baustein 7 (`Need.lua`, Nachrichten UQ/UA) auf. Ändert nur das Addon;
keine Versionsnummer, kein Release.

## Ziel

Wo ein Item angeboten wird, sieht der Spieler auf einen Blick, wie viel es gegenüber dem bringt,
was er in diesem Platz trägt, in Prozent der Wertung:

- **Tooltip:** die Zeile "Upgrade für dich" bekommt die Prozente und darunter, gegen welches
  angelegte Item verglichen wird ("statt [Ring] (schwächerer Ring)").
- **Würfelfenster (Gruppenplündern):** "+12%" unten auf dem Item-Symbol.
- **Questbelohnungen:** dasselbe auf jedem Belohnungsknopf (Auswahl und feste Belohnung), im
  Questfenster, im Questlog und in der Kartenansicht.
- **Roll-Fenster (Lootleitung):** pro Würfelndem eine Spalte "+12%" oder "W" (Wunsch) aus den
  Antworten auf "Wer braucht das?"; darüber eine Zeile, für wen das Item überhaupt ein Upgrade
  ist (Antworten, Gildenwünsche, die eigene Wertung). Beginnt eine Runde, ohne dass das Item in
  den letzten 30 Minuten gefragt wurde, fragt das Fenster selbst (wie die Loot-Ansage, Schalter
  `sync.askUpgrades`).
- **Aussehen-Hinweis:** im Roll-Fenster bei grünen und blauen, beim Aufheben gebundenen Items die
  Zeile "Aussehen bekommen laut Blizzard alle Berechtigten schon beim Plündern. Nur würfeln, wer
  es tragen will." Ein Hinweis, keine Regel: an der Runde ändert er nichts.

Ein eigenes Bedarfsfenster für Raider gibt es nicht; die Raider sehen ihren Vergleich im
Tooltip, auf den Würfelfenstern und im bestehenden Upgrade-Hinweis (Toast).

## Eine Wertung

Alles geht durch `ns.UpgradeOf(item)` in `Bis.lua`. Sie nutzt dieselbe interne Bewertung wie
`ns.BisGain` (Klassen- und Rüstungsregeln aus `Gear.Usable`, Klassenmaske der Daten, Werte aus
dem Client, Gewichte aus `Gear.Weights`). Wenn 2.4 die Gewichte ersetzt, ändert sich nur, was
`Gear.Weights`/`Gear.Score` liefern; kein Anzeigeteil rechnet selbst.

Ergebnis: `{ gain, pct, mine, score, slotKey, up, against = { links }, weaker, later }` oder
`nil, Grund, Code` wie bei `ns.BisGain`.

- **pct** = gain / mine * 100, gerundet; `nil`, wenn der Platz leer ist (mine <= 0). Dann zeigt
  die Anzeige "neu" statt einer Zahl.
- **Ringe, Schmuck:** verglichen wird mit dem schwächeren der beiden Plätze; `weaker = true`.
- **Waffen:** eine Zweihandwaffe gegen Waffen- plus Schildhand; eine Einhandwaffe gegen eine
  angelegte Zweihandwaffe ist "Waffenwechsel" (kein Prozentwert), wie bisher.
- **Stufe:** liegt die Mindeststufe des Items (`C_Item.GetItemInfo`, 5. Wert) über der eigenen,
  ist `later` diese Stufe. Die Anzeige sagt dann "ab Stufe N" und färbt orange; "Wer braucht
  das?" zählt es nicht als Upgrade.
- **up** = `ns.BisIsUpgrade(gain, mine)` (Schwelle `bis.minGain`) und nicht `later`.

`Need.lua` (Antwort eines Raiders) rechnet die Prozente jetzt über `ns.UpgradeOf`; das Format
der Antwort (`id:U:gain:pct:slot`, 999 = leerer Platz) bleibt, alte und neue Clients verstehen
sich weiter.

## Aussehen: was belegt ist

Quelle ist Blizzards BlizzCon-Panel "World of Warcraft: Forever Deep Dive" (13./14.09.2026), nur
aus zweiter Hand über mehrere Berichte (Zusammenfassungen und Newsseiten), keine Patchnotiz und
kein Blauer Beitrag. Inhalt übereinstimmend:

- Grüne und blaue, beim Aufheben gebundene **Dungeon**-Drops: das Aussehen bekommt jeder
  berechtigte Spieler, der beim Plündern da ist.
- **Epische Raid-Drops:** das Aussehen bekommt nur, wer das Item aufhebt und bindet.
- Berechtigt heißt wohl: der Rüstungstyp passt (Platte zu Platte, Stoff zu Stoff).

Daraus folgt:

- Der Hinweis erscheint nur bei Qualität 2 und 3 mit Bindung beim Aufheben (`bindType` 1), nie
  bei Epics.
- Einstellung `rolls.lookHint` (Offiziere): "nur in Dungeons" (Standard, dort ist die Aussage
  belegt), "überall" (auch grüne und blaue Drops im Schlachtzug, wo es nicht angekündigt ist),
  "aus". Der Text sagt "laut Blizzard" und verspricht nichts für den einzelnen Spieler.
- Im Spiel prüfen: bekommt ein Gruppenmitglied, das ein blaues Dungeon-Item nicht gewinnt, das
  Aussehen in der Sammlung?

## Einstellungen

- `bis.compare` (alle, Standard an): Prozente und "statt ..." im Tooltip, Markierungen auf
  Würfelfenstern und Questbelohnungen, Upgrade-Spalte und -Zeile im Roll-Fenster. Aus: alles wie
  vor dieser Änderung.
- `rolls.lookHint` (Offiziere, Auswahl, Standard "nur in Dungeons").

## Client-API (Forever 1.60.1, FrameXML-Zweig forever)

- `QuestInfo_Display` (Blizzard_UIPanels_Game/Mainline/QuestInfo.lua, für camelot geladen):
  `hooksecurefunc`, danach `QuestInfoFrame.rewardsFrame.RewardButtons` mit `type`
  ("choice"/"reward"), `objectType == "item"` und `GetID()`. Link über `GetQuestLogItemLink`
  (Questlog, `QuestInfoFrame.questLog`) oder `GetQuestItemLink` (Questgeber).
- `GroupLootFrame1-4` (Mainline/GroupLootFrame.xml) mit `rollID` und `IconFrame`, `OnShow`
  wie schon für "W" und "SR"; `GetLootRollItemLink`.
- `C_Item.GetItemInfo`: 5. Wert Mindeststufe, 14. Wert Bindung.
- Tooltip nur über `TooltipDataProcessor` (gemeinsamer Hook in Core.lua), kein
  `OnTooltipSetItem`; kein `SetText`, `ClearLines`, `Show`.
- Neu im Selbsttest: `GetQuestLogItemLink`, `QuestInfo_Display`, Objekte `QuestInfoFrame`,
  `QuestInfoRewardsFrame`.

Werte laden noch: eine Markierung versucht es bis zu fünfmal im Abstand einer halben Sekunde.
Fehler gehen an den Fehlerhandler, nie in das Fenster des Clients.

## Tests

`addon/tests/test_upgrade_compare.lua`: `ns.UpgradeOf` (Prozent, leerer Platz, schwächerer Ring,
Zweihand gegen Waffen- plus Schildhand, Waffenwechsel, Stufe, Klasse), Tooltip-Zeilen,
Würfelfenster, Questbelohnungen (Questgeber und Questlog), Schalter. `test_rollframe_upgrade.lua`
(mehrere Clients): Spalte und Zeile im Roll-Fenster aus den Antworten, Selbstfragen beim Start,
Aussehen-Hinweis nach Qualität, Bindung, Instanztyp und Einstellung.
