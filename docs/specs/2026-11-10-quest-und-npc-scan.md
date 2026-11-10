# Spec: Daten per Nummer: Datenprüfung, Quest-Scan, NPC-Scan

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10: "ja mach deine empfehling") · Feature: F-172

Gehört zu den acht Vorschlägen vom 2026-11-10, wie andere Werkzeuge ihre Daten sammeln (D-102 und D-103
sind die Vorschläge 6 und 7). Diese Spec sind die Vorschläge 1, 2 und 3 (D-104).

## Ziel

Amisia kennt viele Quests nur mit englischem Titel und ohne Stufe (Dungeonquests: 482 von 527 ohne Stufe;
Questquellen der Ausrüstung: 745 von 748 ohne Stufe) und viele NPCs nur mit englischem Namen; einige Bosse
und Rares der neuen Forever-Inhalte kennt keine erlaubte Quelle mit ihrer Nummer (Overseer Wrex, King Op,
Lady Illucia Barov; Gill, Umbra, Zin'aka). Der Client weiß das alles: ein Scan per Nummer fragt ihn, das
Ergebnis kommt über die SavedVariables zum N100 und mit dem nächsten Datenbau ins Addon. Gelöst ist es, wenn
die Seiten deutsche Titel und Namen und die Stufen zeigen und die Bosse ihr Porträt haben.

## Was es tut

- **Datenprüfung** `/amisia selbsttest daten` (en `selftest data`): fragt harmlos und gedrosselt, was dieser
  Client per Nummer liefert: NPC-Namen über `C_TooltipInfo.GetHyperlink` und über einen eigenen versteckten
  Tooltip (nie `GameTooltip`) für gesehene NPCs, Classic-Bosse aus unseren Daten und neue Forever-Bosse
  (sofort, nach 1 s, nach 3 s, nie; die ersten Zeilen), zehn hintereinander; Quests per Nummer
  (`HaveQuestData`, `RequestLoadQuestByID` mit `QUEST_DATA_LOAD_RESULT`, Titel, Stufen, Tag, Gruppe, der
  Quest-Tooltip) für eine Quest im Log, eine erledigte, zwei Dungeonquests, "The Drowned City" (95775) und
  eine Nummer, die es nicht gibt; ein eigenes Modell mit `SetCreature` für einen gesehenen und einen
  ungesehenen NPC (nur Bericht); ob Vignetten, Quests auf der Karte, das Dungeonjournal und die Flugkarte
  etwas liefern. Der Bericht kommt ins Selbsttest-Fenster und endet mit einem Urteil je Technik; die Urteile
  bleiben in `AmisiaDB.probe` (je Client-Build).
- **Quest-Scan** `/amisia scan quests` (en gleich): alle 6626 Quests der Client-Tabelle QuestV2
  (Liste in `Data/ScanLists.lua`), 20 pro Sekunde (Einstellung "Quest-Scan (Abfragen pro Sekunde)"), Titel
  in der Sprache des Clients, Schwierigkeitsstufe, Queststufe wo der Client sie hat, Art (Gruppe, Dungeon,
  Raid, PvP wie `Collect/QuestTags.lua`), Gruppengröße, die Ziele aus dem Quest-Tooltip nur, wenn die
  Datenprüfung ihn lesbar fand. Fortsetzbar, anhaltbar (`/amisia scan quests stop`, `/amisia scan stop`),
  nie im Kampf oder in einer Instanz; eine Fortschrittszeile im Chat alle 500 Quests.
- **NPC-Scan** `/amisia scan npcs`: Phase A fragt die 2133 NPCs, die unsere Daten nennen (Bosse,
  Questgeber, Händler, Rares, Kartenpunkte), Phase B die 34814 Nummern in 11 Bereichen, wo die neuen NPCs von
  Forever liegen (vorher Frage mit Dauer in `W.Confirm`). 5 pro Sekunde (Einstellung "NPC-Scan (Abfragen pro
  Sekunde)"), ein zweiter Versuch nach 1 s, langsamer wenn bekannte NPCs leer bleiben. Ohne Urteil der
  Datenprüfung erst eine Mini-Probe mit drei bekannten NPCs.
- **Werkzeuge-Seite** (Expertenmodus): Knöpfe "Quest-Scan", "NPC-Scan", "Anhalten" (hält jeden Scan an) und je
  eine Zeile mit Fortschritt und Restzeit.
- **N100:** `build.py data` nimmt beide Scans ins Scan-Archiv (je Sprache), das Addon räumt sie danach aus
  seiner Datei (D-34); die Builds nehmen die Queststufen, die Art, die deutschen Titel und Namen und die
  Boss-Nummern daraus.

## Was es ausdrücklich nicht tut

- Keine Addon-Nachricht, nichts an andere Spieler, kein Austausch in der Gilde.
- Keine Spielobjekte per Nummer (dafür gibt es keinen Weg), keine Positionen von NPCs (der Tooltip sagt keine).
- Kein Scan in Instanzen oder im Kampf, keine Hintergrundarbeit ohne Befehl oder Knopf.
- Kein Laden von Wowhead, foreverchanges oder Daten anderer Addons (D-03, D-04).

## Abläufe

1. Spieler: `/amisia selbsttest daten`, etwa 5 s warten, Bericht kopieren und schicken.
2. Spieler: `/amisia scan quests` (oder Werkzeuge > "Quest-Scan"); dauert etwa 6 Minuten; danach `/reload`.
3. Spieler: `/amisia scan npcs`: Phase A etwa 8 Minuten; dann noch einmal `/amisia scan npcs`, die Frage mit
   der Dauer von Phase B (bis zu knapp 4 Stunden, jederzeit anhaltbar) mit "Starten" bestätigen; danach `/reload`.
4. Syncthing bringt die SavedVariables zum N100; `build.py data` und ein Release bringen die Daten ins Spiel;
   beim nächsten Login räumt das Addon die ausgewerteten Zeilen aus seiner Datei.

## Abnahmekriterien

- Wenn du `/amisia selbsttest daten` eingibst, dann steht nach etwa 5 s ein Bericht im Fenster mit den
  Abschnitten "NPC-Namen per Nummer", "Quests per Nummer", "Modell per Nummer", "Weitere Quellen" und "Urteil".
- Wenn du `/amisia scan quests` eingibst, dann steht im Chat "Quest-Scan gestartet: 6626 von 6626 Quests offen"
  und auf der Seite Werkzeuge die Zeile "Quest-Scan läuft: ..." mit der Restzeit.
- Wenn du `/amisia scan npcs` eingibst und die Datenprüfung "NPC per Nummer: geht nicht" sagte, dann steht nur
  "Der Client nennt keine NPC-Namen per Nummer: NPC-Scan beendet." im Chat.
- Wenn Phase A fertig ist und du `/amisia scan npcs` noch einmal eingibst, dann fragt ein Fenster mit Zahl der
  Nummern und Dauer, bevor Phase B beginnt.
- Wenn nach dem nächsten Datenbau und Release die Seite Dungeons eine Dungeonquest zeigt, dann steht dort ihr
  deutscher Titel und ihre Stufe, auch für Quests, die der Client noch nicht geladen hat.

## Sonderfälle

- Kampf, Bosskampf (Kampfsperre, geheime Werte): die Datenprüfung startet nicht und bricht ab, ohne etwas zu
  speichern; die Scans warten im Kampf und halten in einer Instanz an. Geheime Tooltipzeilen zählen als leer.
- Client auf Englisch: die Scans speichern englische Titel und Namen unter `enUS`; das Archiv hält sie getrennt
  von den deutschen. Ein Wechsel der Sprache, während Zeilen der anderen noch auf den Datenbau warten, wird
  abgelehnt.
- Der Client antwortet nicht: der Quest-Scan endet nach den ersten 50 unbeantworteten Quests mit einer Zeile
  und zählt den Lauf nicht; der NPC-Scan endet nach der Mini-Probe (Urteil "none" je Build).
- Ein neuer Client-Build: alte Urteile gelten nicht mehr (die Datenprüfung neu laufen lassen).
- `/reload` oder Logout mitten im Scan: der Stand (`next`, `a`, `b`) ist gespeichert; Nummern, die gerade
  warteten, werden beim Fortsetzen neu gefragt.
- Leere Daten: ohne `ScanLists.lua` sagen beide Scans, dass die Liste fehlt; ohne Scan bleiben alle Daten wie heute.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen; nur der eigene Client wird gefragt. Die Drossel (Einstellungen, Rückfall
bei Zeitüberschreitungen und leeren Antworten) hält die Last für den Server klein. Die gespeicherten Zeilen
sind gekürzt (Tooltipzeilen ohne Codes, Ziele höchstens 200 Bytes) und gehen nur über Syncthing zum N100.

## Daten

- `AmisiaDB.scan.quests = { loc, next, n, at, done, list = { [questID] = "Titel\tSchwierigkeit\tQueststufe\tArt\tGruppe\tZiele" }, none = "a-b,c" }`
- `AmisiaDB.scan.npcs = { loc, a, b, n, at, doneA, doneB, list = { [npcID] = "Name\t<Titel>" }, empty = "a-b,c" }`
- `AmisiaDB.probe = { v = 1, build, at, src = probe/mini, npc, npcNew, quest, questTip, model, vignette, questMap, journal, taxi (ok/retry/none), route (info/tip), burst (0-10) }`
- Einstellungen `tools.questRate` (5-50, 20), `tools.npcRate` (1-20, 5).
- Generiert: `Data/ScanLists.lua` (`SCAN_LISTS`), `Data/ScanNames.lua` (`SCAN_NAMES`); `Data/ScanDone.lua`
  bekommt `QL`, `QE`, `NL`, `NE` (nur wenn es Scans gibt). Archiv `tools/scan_archive.json`: `quests`,
  `quest_none`, `npcs`, `npc_empty` je Sprache (nur wenn es welche gibt).
- Keine Nachrichtenart, keine Blob-Art, keine Exportzeile.

## Offene Fragen

Nur das Spiel kann sie beantworten; die Datenprüfung sagt es:

1. Nennt `C_TooltipInfo.GetHyperlink("unit:Creature-...")` auf Forever überhaupt NPC-Namen, und für
   ungesehene NPCs? (Urteil "NPC per Nummer"; öffentlich hat das für Forever niemand bestätigt.) Wenn nein,
   bleibt der NPC-Scan aus; dann bleibt für Boss-Nummern nur die Sichtung im Spiel.
2. Gilt das auch für neue Forever-NPCs (Drowned City)? (Urteil "Neue Forever-NPCs per Nummer") Wenn nein, ist
   Phase B sinnlos.
3. Wie viele Tooltips verträgt der Client am Stück? ("Zehn hintereinander") Danach richtet sich die Rate.
4. Liefert `RequestLoadQuestByID` Titel und Stufe für Quests, die der Spieler nie gesehen hat? Liefert der
   Quest-Tooltip die Ziele? (Urteile "Quest per Nummer", "Quest-Tooltip (Ziele)")
5. Zeigt ein eigenes Modell auch ungesehene NPCs? (Nur Bericht, für spätere Porträts.)
6. Sind Vignetten, Quests auf der Karte, das Dungeonjournal und die Flugkarte auf Forever gefüllt? (Für die
   Vorschläge 4 und 5.)

## Entscheidungen

- 2026-11-10: Vorschläge 1, 2 und 3 von acht: "ja mach deine empfehling" -> diese Spec, D-104.
- Annahme (nicht gefragt): eine gemeinsame Feature-Nummer F-172 für Datenprüfung, Quest-Scan und NPC-Scan,
  weil sie nur zusammen Sinn ergeben.
- Annahme (nicht gefragt): Phase B fragt jede Nummer bis zu zweimal; die Dauer wird darum mit zwei Abfragen je
  Nummer geschätzt ("bis zu").
- Annahme (nicht gefragt): Die deutschen Namen zeigt das Addon aus einer eigenen Datei (`ScanNames.lua`) statt
  die englischen Namen der Datendateien zu ersetzen; die englischen bleiben Schlüssel für Abgleiche.
- Annahme (nicht gefragt): Boss-Nummern aus dem Scan nur über den Namen der Begegnung in der Sprache des Scans:
  bei einem deutschen Scan braucht das die Tabelle `DungeonEncounter` in deDE
  (`python3 tools/build.py tables --tables DungeonEncounter --locale deDE`, einmal je Build).
- Annahme (nicht gefragt): `QuestData.lua` bekommt keine Queststufe (die Datei hat kein Feld dafür; der
  Questtracker zeigt die Mindeststufe aus AllTheThings, die vollständig ist).
