# Amisia: Dungeon-Ansicht mit Bild, Quest-EP, allen Questgebern auf der Karte und Anprobe

Stand 2026-10-06. Nur WoW Forever 1.60.1 (TOC 16001, Spieltyp camelot). Baut auf dem
Dungeon-Planer (`Dungeons.lua`, Seite "Ausrüstung", Ansicht "Dungeons") und den Kartenpins
(`MapPins.lua`) auf. Keine Versionsänderung; der Release setzt sie beim Zusammenführen.

## Ziel

Der Nutzer wählte am 2026-10-06 vier Punkte aus dem Vergleich mit einem Dungeon-Journal:

1. **Bild:** ein Kopfbild je Dungeon aus der eigenen Grafik des Clients, dazu ein Bossmodell.
2. **Quest-EP:** EP je Quest und die Summe je Dungeon (Start im Dungeon und draußen).
3. **"Alle auf der Karte":** ein Knopf markiert alle Questgeber des gewählten Dungeons auf der
   Weltkarte und nimmt die Markierung wieder weg.
4. **Anprobe:** Strg-Klick auf ein Item der Boss- und Questlisten öffnet die Anprobe des Clients,
   Shift-Klick verlinkt es wie gewohnt im Chat.

## Rahmen

- Keine Grafik, kein Code und keine Daten aus anderen Addons. Bilder nur aus dem Client selbst
  (Datei-IDs), Daten aus den Client-Tabellen (wago.tools-CSV bzw. `tools/export_db2.ps1`), ATT
  (MIT) und dem eigenen Sammler.
- UI-Texte deutsch, je Datei an einer Stelle gesammelt (Tabelle `TEXT` bzw. die bestehenden
  Konstanten), ohne zusammengesetzte Satzteile, damit die spätere englische Übersetzung sie
  einfach ersetzen kann. Kommentare englisch.
- Gemeinsame Dateien (Registry, MainFrame, Widgets) bleiben unberührt; parallel entstehen
  Quest-Tracker, Talente und Berufe.

## 1. Bild

**Quelle.** Die Client-Tabelle `Map` nennt je Instanz eine `LoadingScreenID`, die Tabelle
`LoadingScreens` dazu die Datei: alte Dungeons `NarrowScreenFileDataID` (4:3-Bild, als quadratische
Textur 2048x2048 gespeichert, z. B. 131833 LoadScreenDeadmines), die neuen Forever-Dungeons
`MainImageFileDataID` (Breitbild 2992x1684 mit Rand oben und unten, z. B. 7963782
LoadScreen_Camelot_RuinsofLordaeron). Weil der Client diese Ladebildschirme selbst zeigt, liegen
sie sicher im Forever-Client. `LFGDungeons` hat in Forever keine Bild-IDs (alle 0), die
Journal-Tabellen sind leer: Hintergründe der Dungeonsuche und Boss-Porträts des Journals gibt es
nicht verlässlich.

**Daten.** `tools/build_dungeonart.py` liest `Map` und `LoadingScreens` (aus `~/addons/_wago`, dann
`~/addons/_cache/wago`) und die Instanz-IDs der Dungeon-Fakten und schreibt `DungeonArt.lua`:
`ns.DUNGEON_ART = { build, D = { [key] = { fileID, "n" | "w" } }, party = {...}, raid = {...} }`.
Ohne eigenen Eintrag (Dungeons, die der Client noch nicht hat) gilt der allgemeine Ladebildschirm
für Dungeons (131838) bzw. Raids (131863), beide von `Map`-Zeilen des Clients benutzt.

**Anzeige.** Über der Boss- bzw. Questliste ein 48 px hohes Band: ein Ausschnitt aus der Mitte
des Bildes (Texturkoordinaten je Bildart so gewählt, dass das Seitenverhältnis stimmt, siehe
`D.ArtCoords`), links abgedunkelt, darauf der Name in Gold, Level und Passung. Die Dungeonliste
zeigt dafür sechs statt acht Zeilen (sie scrollt).

**Bossmodell.** Rechts im Band ein kleines Modell (`PlayerModel:SetCreature(npcID)`), wo der Boss
eine NPC-ID hat (Build-Fakten `ns.BIS.DG`, Encounter-Tabelle). Gezeigt wird der Boss der Zeile
unter der Maus, sonst der Boss mit dem größten Zuwachs, sonst der erste mit NPC-ID. Ohne
NPC-ID oder ohne `SetCreature` bleibt das Modell verborgen (keine eigene Einstellung, um keine
neue Einstellungsgruppe anzulegen).

**Selbsttest.** Die neuen Atlanten kommen in `ST.ATLASES` und den Stub; ein neuer Abschnitt prüft
die Bild-IDs mit `Texture:SetTexture(fileID)` (Rückgabe "success") und meldet fehlende.

## 2. Quest-EP

**Quelle.** Kein Client-Tabellenweg: `QuestXP` kennt nur EP je Questlevel und Schwierigkeitsstufe,
die Stufe einer Quest liefert erst der Server. ATT führt keine EP. Also eigene Beobachtung:

- `QUEST_DETAIL` und `QUEST_COMPLETE`: `GetRewardXP()` für `GetQuestID()`,
- `QUEST_TURNED_IN(questID, xpReward)`,
- Quests im Log: `GetQuestLogRewardXP(questID)` beim Anzeigen.

Gespeichert wird lokal (`AmisiaDB.questxp[questID] = { EP, Spielerlevel }`, höchster Wert gewinnt,
0 wird nicht gespeichert), **nicht** im geteilten Sammler-Datensatz: dessen Format ist
kanonisch und mit der Gilde abgeglichen, ein neues Feld bräuchte eine neue Protokollversion. Die
Gilde-Weitergabe kann später als Sammler-Feld folgen.

**Skalierung.** Wie der klassische Client: volle EP bis 5 Level über dem Questlevel, dann je
Level 20 % weniger, ab 10 Level darüber 10 % (Faktor `clamp(2*(Q-P)+20, 1, 10)/10`, gerundet auf
5/10/25/50 wie im klassischen Client). Das Questlevel kommt aus den Questdaten, dem Sammler oder dem
Questlog. Ohne Questlevel zeigt Amisia den beobachteten Wert mit "bei Level N". Ob Forever genau
so rechnet, ist ungeprüft: geschätzte Werte tragen "~".

**Anzeige.** Spalte "EP" in den Questzeilen, Tooltip mit Herkunft (im Log, gesehen bei Level N,
geschätzt). Kopfzeile der Questliste: "EP offen: 4350 (draußen 3100, im Dungeon 1250), 2 Quests
ohne Wert". Summiert werden die offenen Dungeon-Quests (Vorquests nicht).

## 3. Alle Questgeber auf der Karte

Ein Knopf "Alle auf Karte" in der Questansicht. Er merkt sich den Dungeon in `AmisiaDB.map.quests`
(bleibt über /reload), die Kartenpins zeigen dann je offenem Questgeber dieses Dungeons mit
Ort einen Pin mit dem Questsymbol des Clients (Atlas `QuestNormal`, sonst
`Interface\GossipFrame\AvailableQuestIcon`). Mehrere Quests eines Gebers teilen einen Pin; der
Tooltip nennt Geber und Quests, Klick setzt den Wegpunkt, Rechtsklick bietet "Markierung
entfernen". Ein zweiter Klick auf den Knopf ("Karte leeren") nimmt alles weg. Die Weltkarte
öffnet sich nicht von selbst (das würde das Amisia-Fenster schließen); eine Chatzeile nennt die
Zahl der markierten Geber. Quests, die im Dungeon starten, zeigen auf den Eingang (ohne bekannten
Eingang auf den Geber drinnen); Quests im Log und erledigte fallen weg.

## 4. Anprobe

`HandleModifiedItemClick` und `DressUpLink` gibt es in Forever (Mainline-Familie,
`Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua` mit Camelot-Override). Ein modifizierter
Klick auf ein Item der Dungeon-Listen geht an `HandleModifiedItemClick` (es achtet auf die
Tastenbelegung des Spielers: Chat-Link, Anprobe); wo der Client die Anprobe nicht ausführt, ruft
Strg-Klick `DressUpLink` selbst. Hinweiszeile und Tooltip nennen die Kürzel. Der Selbsttest führt
`DressUpLink`, `IsModifiedClick`, `GetRewardXP` und `GetQuestLogRewardXP` als optionale
Funktionen.

## Tests

Zuerst: Lua-Tests (lupa) für Bild-Auswahl und Koordinaten, EP-Aufzeichnung, Skalierung und Summe,
Kartenmarkierung (Pins, Löschen, Tooltip), Strg/Shift-Klick und die neue Kopfzeile; pytest für
`build_dungeonart.py`. Danach `syntax.cjs`.

## Für den Nutzer

- `tools/export_db2.ps1 -Tables LoadingScreens` (für spätere Builds; für 1.60.1.70235 liegt die
  Tabelle von wago.tools in `~/addons/_cache/wago`).
- Im Spiel prüfen: Bild je Dungeon (Ausschnitt), Bossmodell, EP nach dem Abgeben einer Quest,
  "Alle auf Karte", Strg-Klick-Anprobe, `/amisia selbsttest` Abschnitt "Dungeonbilder".
