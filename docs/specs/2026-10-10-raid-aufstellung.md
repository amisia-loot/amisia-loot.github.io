# Spec: Raid-Aufstellung (Anmeldeliste, Einladen, Gruppen sortieren)

Stand: 2026-10-10 · Status: freigegeben, Teile A, B und E gebaut ·
Feature: F-083 (Aufstellung: Einfügen, Abgleich, Planer, Ersatzbank), F-084 (Einladen, Sortieren);
F-082 war beim Bau schon vergeben (Einrichtungshilfe). Regel: DECISIONS D-41.

Vom Nutzer am 2026-10-10 gewählt. Das Paket hat fünf Teile, die nacheinander gebaut werden und
einzeln ausgeliefert werden können: **A** Liste einfügen und Namen abgleichen, **B** Planer
(Gruppen einteilen), **C** Einladen mit Status, **D** Gruppen im Spiel sortieren, **E** Ersatzbank.
Ein Reiter auf der Website kommt später (Teil F, nicht in dieser Spec gebaut).

## Ziel

Der Raidstart dauert heute lange: Namen aus Discord abschreiben, einzeln einladen, Gruppen von Hand
ziehen, die Ersatzbank eintragen. Mit Amisia fügt ein Offizier die Anmeldeliste ein, prüft kurz die
Einteilung und klickt "Alle einladen". Gelöst ist es, wenn ein Raid mit 40 Anmeldungen in wenigen
Minuten steht, jede Gruppe einen Heiler hat und keiner fragt "in welcher Gruppe bin ich?".

## Was es tut

### Teil A: Liste einfügen und abgleichen

- Neue Seite **"Aufstellung"** in der Gruppe Raid (nur Offiziersansicht), Befehl
  `/amisia aufstellung` (en `lineup`).
- Knopf **"Einfügen"** öffnet ein Textfeld. Amisia liest drei Arten von Text:
  1. den Block **`#AMISIA-RAID`** (Aufbau wie die anderen Einfügeblöcke, siehe "Daten"); heute
     von Hand oder später von der Website;
  2. **einfache Zeilen** "Name Rolle", z. B. `Vulo Pala Heiler`, `Anna Tank`, `Bob, Nahkampf`.
     Rolle und Klasse dürfen deutsch oder englisch sein (`Heiler`/`Healer`, `Krieger`/`Warrior`);
  3. den **Text eines Anmelde-Bots aus Discord** (allgemeine Regeln, kein bestimmter Bot):
     Überschriften wie "Tanks (2)", "**Heiler**", "Melee:", "Ersatz", "Abgemeldet"; Zeilen mit
     Nummern, Emoji-Codes (`:Warrior:`), Fettschrift und Zeitangaben. Amisia nimmt aus jeder Zeile
     den Namen, und aus Überschrift oder Emoji Rolle und Klasse.
- Danach steht jede Anmeldung in einer Liste mit **Abgleich** gegen die Gildenliste:
  - grün "gefunden": der Name passt genau (Groß/klein und Umlaute egal);
  - gelb "vermutlich": nur der Vorname passt und ist in der Gilde einmalig, oder ein Buchstabe
    ist anders (Tippfehler). Ein Klick bestätigt;
  - orange "nicht eindeutig": zwei Gildenmitglieder heißen so ("Vulo Pala" und "Vulo Hunt"). Ein
    Klick wählt;
  - rot "unbekannt": nichts passt. Ein Feld nimmt den richtigen Namen; Amisia merkt sich die
    Korrektur für das nächste Mal (Namenskorrekturen, siehe Frage 3);
  - grau "Gast": der Name ist richtig geschrieben, aber nicht in der Gilde.
- Twinks (aus der Twink-Liste der Website): Ist der angemeldete Charakter offline und genau ein
  Twink desselben Spielers online, zeigt die Zeile "Twink online: Kleinfrak · tauschen".
- Pro Zeile: Klasse (Farbe), Rolle (T, H, N, F), Stufe, online/offline.

### Teil B: Planer

- Acht Kästen "Gruppe 1" bis "Gruppe 8" mit je fünf Plätzen, links die Liste "Nicht eingeteilt"
  und "Ersatz".
- Knopf **"Automatisch einteilen"** verteilt nach einfachen Regeln (siehe "Abläufe", Teil B).
- Von Hand: Zeile ziehen und auf einen Platz fallen lassen. Oder: eine Zeile anklicken, dann eine
  andere anklicken, die beiden tauschen. Rechtsklick: Rolle ändern, "Ersatz", "Festhalten" (die
  automatische Einteilung bewegt diesen Spieler nicht mehr), "Entfernen".
- Oben eine Zeile mit der Zählung: "Tanks 3 · Heiler 8 · Nahkampf 15 · Fernkampf 14 · Ersatz 4".
  Hat eine Gruppe keinen Heiler, ist ihr Kasten rot umrandet.
- Die Aufstellung wird **pro Raidnacht gespeichert** (Raidnacht ab 06:00 wie bei D-23) und
  übersteht `/reload`. Eine Auswahl oben zeigt die letzten Nächte; "Von letzter Woche übernehmen"
  kopiert eine alte Aufstellung als Anfang.

### Teil C: Einladen

- Knopf **"Alle einladen"**: lädt alle eingeteilten, online stehenden Spieler ein, die noch nicht
  im Raid sind. Die Ersatzbank wird nicht eingeladen.
- Status pro Name, als farbiger Punkt mit Text: "geplant", "eingeladen", "im Raid", "abgelehnt",
  "keine Antwort", "in anderer Gruppe", "offline", "unbekannt".
- Knopf **"Nochmal einladen (N)"** lädt alle mit "abgelehnt" oder "keine Antwort" erneut ein,
  einmal pro Klick.
- Wird jemand online, der offline war: Zeile blinkt kurz, "Anna ist jetzt online · Einladen".
- Optional (Einstellung, Standard aus): ein Flüstern an jeden Eingeladenen:
  "Amisia: Einladung zum Raid (Gruppe 3). Bitte annehmen." Der Text ist fest, nur die Gruppe ändert
  sich.

### Teil D: Gruppen sortieren

- Knopf **"Gruppen sortieren"**: schiebt jeden Raider im Spiel in die Gruppe aus dem Planer.
- Einstellung "Automatisch sortieren, wenn jemand beitritt" (Standard an).
- Wer im Raid ist, aber nicht auf der Liste steht, bleibt, wo er ist, und steht unter
  "Im Raid, nicht angemeldet".

### Teil E: Ersatzbank

- Knopf **"Ersatz auf die Ersatzbank"**: trägt alle mit "Ersatz" (und die Überzähligen, siehe
  Sonderfälle) auf die Ersatzbank des Abends ein, wie `/amisia ersatz` es heute tut, mit der Notiz
  "Aufstellung". Wie die Ersatzbank zählt, entscheidet weiter die Website (D-29).
- Einstellung "Ersatz automatisch eintragen, sobald die Aufnahme läuft" (Standard aus).

### Einstellungen

Neuer Abschnitt **"Raid-Aufstellung"** (nur Offiziere): Raidgröße (10, 20, 40; Standard 40),
Einladung flüstern (aus), Automatisch sortieren (an), Gäste einladen (aus), Ersatz automatisch
eintragen (aus).

## Was es ausdrücklich nicht tut

- **Kein Rauswerfen.** Amisia wirft nie jemanden aus der Gruppe (auch nicht, wer nicht angemeldet
  ist). Das macht der Leiter von Hand.
- **Kein Einladen auf Flüstern** ("inv" an den Leiter) in diesem Paket: das öffnet Tür und Tor
  für Spam und Fremde (siehe Frage 8).
- **Keine Raidziele, Markierungen oder Aufgaben** (wer welchen Boss tankt, Heiler-Zuteilung). Das
  ist ein eigenes Thema.
- **Kein Teilen zwischen Offizieren.** Die Aufstellung liegt bei dem Offizier, der einlädt. Ein
  zweiter Offizier fügt dieselbe Liste bei sich ein, wenn er sie sehen will (siehe Frage 9).
- **Keine neue Exportzeile.** Wer angemeldet war, aber nicht kam, geht nicht an die Website.
  Anwesenheit und Ersatzbank laufen wie heute über die Raidaufnahme.
- **Keine Daten von Fremdseiten**: Amisia liest nur Text, den der Offizier einfügt. Kein Abruf aus
  Discord oder dem Netz.
- **Nicht im Kampf**: kein Einladen, Umwandeln und Sortieren im Kampf und in der Kampfsperre.
- Kein automatisches Wiederholen von Einladungen. Jede neue Einladung braucht einen Klick.

## Abläufe

### Teil A: Einfügen

1. Die Gilde meldet sich wie gewohnt in Discord an. Der Offizier kopiert den Text des Bots (oder
   schreibt "Name Rolle" untereinander, oder kopiert später den Block von der Website).
2. Im Spiel: Seite Aufstellung, "Einfügen", Text hinein, "Übernehmen".
3. Amisia fragt die Gildenliste neu ab (höchstens alle 10 Sekunden, wie heute bei der Ersatzbank)
   und gleicht jeden Namen ab, in dieser Reihenfolge:
   1. Namenskorrektur aus einer früheren Liste ("Vulo" heißt bei uns "Vulo Hunt");
   2. ganzer Name genau;
   3. ganzer Name ohne Unterschied von Groß/klein und Umlauten;
   4. nur der Vorname, wenn genau ein Gildenmitglied ihn trägt (Regel aus `Core/Names.lua`:
      Forever-Namen sind "Vorname Nachname", ein Vorname allein zählt nur, wenn er eindeutig ist);
   5. ein Buchstabe anders (fehlt, zu viel, vertauscht), wenn genau ein Name so passt: "vermutlich".
   Was dann noch übrig ist, ist "unbekannt" oder, wenn der Spieler gefunden wird, aber nicht in der
   Gilde ist, "Gast".
4. Rolle: aus der Liste. Fehlt sie, aus der letzten Aufstellung dieses Spielers. Fehlt sie dort
   auch, aus der Klasse (Krieger und Schurke Nahkampf; Jäger, Magier und Hexenmeister Fernkampf;
   Priester, Paladin, Schamane und Druide Heiler). Eine geratene Rolle steht grau mit "?".
5. Doppelte Namen in der Liste zählen einmal (die erste Zeile gilt). Eine Zeile "Abgemeldet" oder
   "Absent" wird nicht eingeteilt, steht aber grau unten ("abgemeldet: 3").
6. Der Chat meldet: "Aufstellung: 38 Anmeldungen, 35 gefunden, 2 vermutlich, 1 unbekannt."

### Teil B: Automatisch einteilen

Die Regeln sind einfach, damit man sie nachvollziehen kann. Festgehaltene Spieler bleiben stehen.

1. **Größe:** So viele Gruppen, wie die Raidgröße braucht (40: acht Gruppen, 20: vier, 10: zwei).
   Wer nicht hineinpasst, kommt auf "Ersatz" (siehe Sonderfälle).
2. **Tanks** zuerst: einer pro Gruppe, ab Gruppe 1.
3. **Heiler**: reihum, damit jede Gruppe mindestens einen hat. Übrige Heiler gehen in die Gruppen
   mit Tanks. Schamanen bevorzugt in Nahkampf-Gruppen, Priester und Druiden in Fernkampf-Gruppen.
4. **Nahkampf** zusammen: die Gruppen mit Tanks werden mit Nahkampf aufgefüllt, dann die nächsten.
   Ein Schamane (Totems) oder ein Krieger (Schlachtruf) gehört in jede Nahkampf-Gruppe, wenn genug da
   sind.
5. **Fernkampf** zusammen in die übrigen Gruppen. Jäger zählen als Fernkampf.
6. Was am Ende noch frei ist, füllt die nächste freie Lücke.
7. Ergebnis ansehen, von Hand verschieben, festhalten, fertig. Jede Änderung wird sofort gespeichert.

### Teil C: Einladen

1. Der Offizier klickt "Alle einladen". Amisia prüft vorher: Offiziersansicht und Offiziersrang
   (geprüft über die Gildenliste), kein Kampf, keine Kampfsperre, kein Schlachtfeld. Bist du in
   einer Gruppe, musst du Leiter oder Assistent sein. Sonst steht der Grund am Knopf.
2. Bist du allein oder in einer Gruppe (nicht Raid): Amisia lädt zuerst höchstens vier ein (eine
   Gruppe hat fünf Plätze). Sobald der Erste angenommen hat, wandelt es die Gruppe in einen Raid um
   und lädt den Rest ein.
3. Einladungen gehen gedrosselt raus: eine alle 0,5 Sekunden (Vorschlag; Frage 11 klärt, ob ein
   Klick für alle reicht).
4. Status kommt aus den Systemmeldungen des Spiels ("... lehnt Eure Einladung ab", "... ist bereits
   in einer Gruppe", "Spieler nicht gefunden") und aus der Raidliste. Amisia liest die Meldungen über
   die Textvorlagen des Spiels, nicht über deutschen Text. Ohne Antwort nach 90 Sekunden:
   "keine Antwort".
5. Offline-Spieler werden nicht eingeladen. Gäste nur mit der Einstellung "Gäste einladen".
6. Der Offizier sieht die Liste füllen. Er klickt bei Bedarf "Nochmal einladen".
7. Höchstens drei Einladungen pro Name und Abend.

### Teil D: Sortieren

1. "Gruppen sortieren" (oder automatisch nach jedem Beitritt, mit 2 Sekunden Ruhe, damit nicht bei
   jedem einzeln geschoben wird).
2. Amisia geht die Raider durch. Ist in der Zielgruppe ein Platz frei, schiebt es den Raider hin.
   Ist sie voll, tauscht es ihn mit jemandem, der dort nicht hingehört.
3. Ein Schritt nach dem anderen, und erst weiter, wenn das Spiel die Raidliste neu meldet.
   Höchstens 60 Schritte pro Klick.
4. Kommt ein Kampf dazwischen: Amisia hört auf und zeigt "Sortieren nach dem Kampf fortsetzen".

### Teil E: Ersatzbank

1. Nach dem Einladen klickt der Offizier "Ersatz auf die Ersatzbank". Ist noch keine Aufnahme
   gestartet, landen die Namen wie heute in der Ersatzbank des Abends und gehen mit dem ersten Raid
   in die Aufnahme.
2. Wer nur abgelehnt hat, offline ist oder sich abgemeldet hat, kommt nicht auf die Ersatzbank.
3. Kommt ein Ersatzspieler später doch in den Raid, gilt er wie heute als "von der Ersatzbank" und
   ist nie zu spät.

## Abnahmekriterien

Allein prüfbar vor 2026-11-04 sind nur die Zeilen ohne "(braucht: ...)". Der Nutzer hat kein
zweites Konto; alle Gruppenprüfungen ab 2026-11-04 (D-32).

### Teil A und B (F-082)

- Wenn du als Offizier `/amisia aufstellung` eingibst, dann öffnet sich die Seite Aufstellung;
  mit einem Charakter ohne Offiziersrang (Vulo Pala) gibt es die Seite nicht. (braucht: Gilde)
- Wenn du drei Zeilen `Vulo Hunt Tank`, `vulo pala heiler` und `Niemand Nirgends Nahkampf` einfügst,
  dann stehen die ersten beiden grün "gefunden" und die dritte rot "unbekannt". (braucht: Gilde)
- Wenn du einen Text mit den Überschriften "Tanks", "Healers" und "Bench" einfügst, dann haben die
  Namen darunter die Rollen T, H und "Ersatz".
- Wenn du "Automatisch einteilen" mit 8 Heilern und 40 Anmeldungen klickst, dann hat jede der acht
  Gruppen einen Heiler, und die Zählung oben stimmt.
- Wenn du einen Spieler festhältst und neu einteilst, dann bleibt er in seiner Gruppe; nach
  `/reload` ist die Aufstellung noch da.

### Teil C, D und E (F-083)

- Wenn du im Kampf "Alle einladen" klickst, dann passiert nichts, und am Knopf steht "Nicht im
  Kampf".
- Wenn du "Alle einladen" klickst, dann bekommen alle eingeteilten Online-Spieler eine Einladung,
  der Raid wird nach dem ersten Beitritt umgewandelt, und die Status wechseln auf "eingeladen" und
  "im Raid". (braucht: Gruppe, Gilde)
- Wenn jemand die Einladung ablehnt, dann steht er rot "abgelehnt", und "Nochmal einladen (1)" lädt
  ihn erneut ein. (braucht: Gruppe)
- Wenn alle im Raid sind und du "Gruppen sortieren" klickst, dann stehen alle in der Gruppe aus dem
  Planer. (braucht: Raid)
- Wenn du "Ersatz auf die Ersatzbank" klickst, dann stehen die Ersatzspieler mit der Notiz
  "Aufstellung" im Raid-Log unter Ersatzbank (`/amisia ersatz` zeigt sie).

## Sonderfälle

- **Mehr Anmeldungen als Plätze (über 40, oder über 20 bei ZG/AQ20):** "Automatisch einteilen"
  nimmt erst Tanks und Heiler, bis jede Gruppe einen Heiler hat, dann die Reihenfolge der Liste
  (wer sich früher angemeldet hat). Die übrigen stehen auf "Ersatz". Höchstens 80 Anmeldungen pro
  Abend; mehr Zeilen werden gezählt und übersprungen.
- **Schon in einer anderen Gruppe:** Status "in anderer Gruppe" (orange). Nochmal einladen geht,
  wenn er die Gruppe verlassen hat.
- **Gleicher Vorname zweimal** ("Vulo" bei "Vulo Pala" und "Vulo Hunt"): nie raten, immer "nicht
  eindeutig" mit Auswahl. Gilt auch für die Gruppe: ein Vorname allein trifft nur, wenn er im Raid
  einmalig ist (`ns.SameNameIn`).
- **Offline:** nicht einladen; Hinweis, sobald er online kommt. Twink online: Vorschlag zum Tauschen,
  nie automatisch.
- **Andere Realms, Gäste:** Forever-Namen sind nach heutigem Wissen pro Region einmalig; ob die
  Einladung mit "Vorname Nachname" über Realms hinweg klappt, ist offen (Frage 15). Ein Strich im
  Namen gehört zum Nachnamen und wird nicht als Realm abgeschnitten.
- **Discord-Name anders als Charaktername:** landet als "unbekannt"; die Korrektur wird gemerkt und
  gilt nächste Woche von selbst.
- **Du bist nicht Leiter oder Assistent:** Einladen und Sortieren sind aus; Planer und Einfügen
  gehen.
- **Kampf, Kampfsperre (Bosskampf):** Einladen, Umwandeln und Sortieren warten; ein laufendes
  Sortieren hört auf und bietet "fortsetzen" an. Systemmeldungen sind in der Sperre geheim; Amisia
  liest dort keine Status.
- **Schlachtfeld, Arena:** nichts.
- **Zwei Offiziere gleichzeitig:** jeder mit eigener Aufstellung. Laden beide ein, meldet das Spiel
  "bereits in einer Gruppe" für die schon Eingeladenen; das schadet nicht. Sortieren sollte nur einer
  (Absprache; der Knopf sagt "Sortiert gerade nur dein Client").
- **Login oder `/reload` mitten im Einladen:** die Aufstellung bleibt; die Status baut Amisia aus der
  Raidliste neu ("im Raid" oder "geplant"); die laufende Einladerunde endet und braucht einen neuen
  Klick.
- **Stufe zu niedrig:** Hinweis "Stufe 52" in der Zeile; eingeladen wird trotzdem, wenn eingeteilt.
- **Client auf Englisch:** Rollen- und Klassenwörter in beiden Sprachen; Systemmeldungen über die
  Textvorlagen des Spiels.
- **Gildenliste nicht lesbar** (keine Gilde, noch nicht geladen): Abgleich nur gegen Gruppe und
  Freundesliste, sonst "unbekannt"; der Chat sagt "Gildenliste noch nicht geladen, gleich nochmal".
- **Leere oder kaputte Liste:** "Kein Name erkannt." und nichts wird überschrieben.

## Missbrauch/Vertrauen

- **Nur Offiziere.** Seite, Befehle und Einstellungen gibt es nur in der Offiziersansicht und nur
  mit Offiziersrang laut Gildenliste (Rangrecht Flag 22, D-18). Ein Raider kann nichts auslösen.
- **Keine Nachrichten von anderen.** Das Paket sendet und empfängt keine Addon-Nachrichten. Niemand
  kann von außen eine Aufstellung schicken oder Einladungen auslösen.
- **Eingefügter Text ist unvertraut** (D-26): Farbcodes und Striche entfernt, jede Zeile geprüft und
  gekürzt (200 Bytes), höchstens 2000 Zeilen gelesen, 80 Anmeldungen genommen, Namen ohne Ziffern
  und Steuerzeichen, höchstens 48 Zeichen. Notizen aus der Liste werden nur angezeigt, nie in einen
  Chat geschrieben.
- **Kein Spam:** das Flüstern hat einen festen Text (nur die Gruppennummer wechselt), geht nur an
  Eingeladene und nur einmal pro Name und Abend. Einladungen gedrosselt, höchstens drei pro Name und
  Abend, nie automatisch wiederholt.
- **Gäste** (nicht in der Gilde) werden nur mit eigener Einstellung eingeladen, damit eine
  untergeschobene Liste keine Fremden in den Raid holt.
- **Keine Kicks**, kein Leiterwechsel, keine Beförderung zum Assistenten.
- **Ersatzbank:** nur über den bestehenden Weg (`ns.BenchAdd`), mit dem Offizier als "eingetragen
  von"; der Raid-Abgleich zeigt es den anderen Offizieren wie heute.

## Daten

Alles hier kommt beim Bauen im selben Commit in `docs/ARCHITECTURE.md` (Module map, Paste-in
blocks, SavedVariables, Settings) und die Regel in `docs/DECISIONS.md`.

- **Neue Dateien:** `Raid/Lineup.lua` (Einlesen, Abgleich, Einteilen, Einladen, Sortieren) und
  `UI/Pages/Lineup.lua` (Seite "Aufstellung", Gruppe Raid, `officer = true`), je eine Zeile in der
  TOC und der Module map. Texte in `L["…"]`, Englisch in `Locales/enUS_<Bereich>.lua`.
- **Befehl:** `/amisia aufstellung` (en `lineup`), mit `einladen` (en `invite`) und `sortieren`
  (en `sort`); nur Offiziere.
- **`AmisiaDB.lineup`:** `{ v = 1, nights = { ["JJJJ-MM-TT"] = { at, by, title, size, list = {
  { n = Name, r = "T"/"H"/"M"/"R", c = Klassen-Token, g = Gruppe 1-8 oder nil, b = true (Ersatz),
  k = true (festgehalten), q = true (Rolle geraten), m = true (vielleicht), s = Name in der Liste,
  wenn anders } } } } }`. Beim Laden Feld für Feld geprüft; höchstens 8 Nächte (die neuesten),
  80 Namen pro Nacht. Die Status (eingeladen, abgelehnt …) werden nicht gespeichert.
- **Namenskorrekturen:** Vorschlag: die bestehende Tabelle `srAliases` der Soft-Reserves mitnutzen
  (eine Liste "Name in Listen -> echter Name" für beides; Frage 3). Sonst ein Feld `alias` in
  `lineup` (höchstens 300).
- **Einstellungsabschnitt** `lineup` "Raid-Aufstellung" (`Raid/Lineup.lua`, nur Offiziere):
  `lineup.size` (10/20/40, Standard 40), `lineup.whisper` (aus), `lineup.autoSort` (an),
  `lineup.guests` (aus), `lineup.autoBench` (aus).
- **Neuer Einfügeblock** `#AMISIA-RAID`:
  `#AMISIA-RAID 1 forever <JJJJ-MM-TT> [<Titel …>]`, dann Zeilen
  `S <Name mit _> <T/H/M/R/-> [<Klassen-Token oder ->] [<B Ersatz / ? vielleicht / ->]`, bis `#END`.
  Gelesen von `ns.ParseLineup`, aufgerufen über `ns.SiteBlocks`/`ns.ImportSiteText` (Alts.lua)
  und über das eigene Feld der Seite Aufstellung. Die Website schreibt ihn erst mit Teil F; bis dahin
  braucht `tools/tests/test_contracts.py::test_paste_in_blocks` eine Ausnahme "liest nur das Addon"
  (Frage 2). Die einfachen Zeilen und der Bot-Text sind kein Block (wie die Soft-Reserves).
- **Keine neuen Nachrichtenarten, keine Blob-Art, keine Exportzeile, kein neuer Website-Zustand.**
  Ersatzbank-Einträge sind die bestehenden `BN`-Zeilen.
- **Spiel-Funktionen** (laut FrameXML 1.60.1.70205, Rest offen):
  - `C_PartyInfo.InviteUnit(name)`: ohne Sperr-Kennzeichen (`HasRestrictions`), aber
    `RequiresValidInviteTarget`; das Spiel ruft es selbst mit dem vollen Namen aus der Freundes- und
    Gildenliste auf. Ob ein Addon es ohne Tastendruck darf: Frage 11.
  - `C_PartyInfo.ConvertToRaid()`: `HasRestrictions` (wie `SendChatMessage`), also gesperrt in der
    Kampfsperre; außerhalb erlaubt. Kann laut Doku manchmal nachfragen.
  - `SetRaidSubgroup(index, gruppe)`, `SwapRaidSubgroup(index1, index2)`: alte globale Funktionen,
    nicht in der Doku; das Raidfenster des Spiels nutzt sie nur für Leiter und Assistenten
    (`UnitIsGroupLeader`/`UnitIsGroupAssistant`). Ob sie im Kampf gehen: Frage 13.
  - Sperren: `C_RestrictedActions.IsAddOnRestrictionActive(0)` (Kampf), `(1)` (Bosskampf),
    `(5)` (Chat), `InCombatLockdown()`.
  - `UninviteUnit` und `PromoteToAssistant` nutzt Amisia nicht.
- **DECISIONS:** neue Regel (nächste freie Nummer, heute D-40): "Raid-Aufstellung: nur Offiziere,
  Einladen nur per Klick und gedrosselt, nie Kicks, kein Einladen auf Flüstern, Gäste nur mit
  Einstellung, eingefügter Text unvertraut."

## Offene Fragen

Zuerst die Reihenfolge, dann die Entscheidungen, dann die Prüfungen im Spiel. Prüfungen mit
"allein" gehen heute; der Rest ab 2026-11-04.

1. **Reihenfolge des Baus.** Vorschlag:
   1. Teil A: Einfügen und Abgleich (M). Allein prüfbar mit der Gilde online: alle drei Textarten,
      Abgleich, unbekannte Namen, Korrekturen.
   2. Teil B: Planer und "Automatisch einteilen" (M). Ganz allein prüfbar (Ziehen, Tauschen,
      Festhalten, Speichern, `/reload`). Danach ist F-082 fertig.
   3. Teil E: Ersatzbank (S). Allein prüfbar (`/amisia ersatz` zeigt die Namen).
   4. Teil C: Einladen mit Status (M). Erst nach den Prüfungen 10 und 11; voll prüfbar ab 2026-11-04.
   5. Teil D: Sortieren (S bis M). Erst nach Prüfung 13; prüfbar erst im Raid.
   6. Später, eigene Spec: Teil F, Reiter "Sign-ups" auf der Website mit "Copy for the addon"
      (`#AMISIA-RAID`) (L).
2. **Block `#AMISIA-RAID` jetzt schon?** Vorschlag: ja, das Addon liest ihn ab Teil A (man kann ihn
   auch von Hand schreiben), und der Vertragstest bekommt eine Ausnahme "Block, den die Website noch
   nicht schreibt". Alternative: der Block kommt erst mit Teil F.
3. **Namenskorrekturen gemeinsam mit den Soft-Reserves?** Vorschlag: ja, eine Liste für beides
   (`srAliases`), weil es dieselben Leute mit denselben Discord-Namen sind.
4. **Einteilungsregeln:** Ist "ein Heiler pro Gruppe, Tanks ab Gruppe 1, Nahkampf zusammen mit
   Schamane oder Krieger, Fernkampf zusammen" so richtig für eure Gilde? Vorschlag: ja, und Rolle aus
   der Klasse raten, wenn die Liste keine nennt.
5. **Flüstern beim Einladen:** Vorschlag: Standard aus, fester Text "Amisia: Einladung zum Raid
   (Gruppe 3). Bitte annehmen."
6. **Gäste:** Vorschlag: nur mit Einstellung "Gäste einladen" (Standard aus).
7. **Ersatzbank:** Vorschlag: nur "Ersatz" und Überzählige, die online sind; nicht wer ablehnt,
   offline ist oder sich abgemeldet hat. Automatisch eintragen Standard aus.
8. **Einladen auf Flüstern ("inv")?** Vorschlag: nein in diesem Paket. Wenn gewünscht, später nur
   für Namen auf der Aufstellung und nur für Gildenmitglieder.
9. **Teilen zwischen Offizieren?** Vorschlag: nein (keine neue Nachricht). Wenn später gewünscht:
   eine Blob-Art "Aufstellung" an geprüfte Offiziere, mit eigener Spec-Ergänzung.
10. **Prüfung allein: Funktionen und Textvorlagen.**
    `/dump C_PartyInfo.InviteUnit, C_PartyInfo.ConvertToRaid, C_PartyInfo.CanInvite(), SetRaidSubgroup, SwapRaidSubgroup`
    (erwartet: fünfmal etwas, nicht nil) und
    `/dump ERR_INVITE_PLAYER_S, ERR_DECLINE_GROUP_S, ERR_ALREADY_IN_GROUP_S, ERR_BAD_PLAYER_NAME_S, ERR_GROUP_FULL, ERR_JOINED_GROUP_S, ERR_RAID_MEMBER_ADDED_S`
    (erwartet: die deutschen Vorlagen mit `%s`).
11. **Prüfung allein: Einladen mit vollem Namen und ohne Tastendruck.** Einen Namen einladen, den es
    nicht gibt: `/run C_PartyInfo.InviteUnit("Niemand Nirgends")` (erwartet: "Spieler nicht gefunden"
    o. ä. im Chat, kein Fehler). Dann ohne Tastendruck:
    `/run C_Timer.After(1,function() C_PartyInfo.InviteUnit("Niemand Nirgends") end)`. Kommt
    dieselbe Meldung (und kein "Aktion blockiert", mit `/etrace` auf `ADDON_ACTION_BLOCKED` und
    `MACRO_ACTION_FORBIDDEN` achten), darf Amisia gedrosselt in einem Rutsch einladen. Sonst lädt
    jeder Klick auf "Alle einladen" nur den Nächsten ein (Knopf zeigt "Weiter einladen (12)").
    Mit Gruppe ab 2026-11-04: dasselbe mit einem echten Online-Namen "Vorname Nachname".
12. **Prüfung mit Gruppe: Umwandeln.** In einer Gruppe mit zwei Spielern:
    `/run C_Timer.After(1,function() C_PartyInfo.ConvertToRaid() end)` (erwartet: Raid ohne
    Nachfrage). Und `/dump C_PartyInfo.AllowedToDoPartyConversion(true)` vorher (erwartet true).
13. **Prüfung im Raid: Sortieren, auch im Kampf.** Außerhalb des Kampfes:
    `/run C_Timer.After(1,function() SetRaidSubgroup(2,3) end)` (Raider 2 in Gruppe 3) und
    `/run C_Timer.After(1,function() SwapRaidSubgroup(1,2) end)`. Dann einmal im Kampf (an einer
    Übungspuppe) und einmal im Bosskampf mit `/dump C_RestrictedActions.IsAddOnRestrictionActive(1)`.
    Geht es im Kampf nicht, bleibt die Regel "nur außerhalb". Und als Assistent (nicht Leiter)
    dasselbe.
14. **Prüfung mit Gruppe: Systemmeldungen und Ablaufzeit.** Mit `/etrace` beobachten, welche
    `CHAT_MSG_SYSTEM`-Zeilen bei Annehmen, Ablehnen, "schon in einer Gruppe" und bei einer
    unbeantworteten Einladung kommen, und nach wie vielen Sekunden die Einladung verfällt (der
    Vorschlag nimmt 90 Sekunden an). Steht der Nachname mit in der Zeile?
15. **Prüfung mit Gruppe: anderer Realm.** Einen Spieler eines anderen Realms (falls es in Forever
    getrennte Realms gibt) mit `/run C_PartyInfo.InviteUnit("Vorname Nachname")` einladen. Klappt es
    nicht, sind Gäste von anderen Realms "nur von Hand".
16. **Zweites Konto?** Laut Loot-Abend-Spec (2026-10-09) keins; alle Zeilen mit "(braucht: ...)"
    warten bis 2026-11-04 (D-32). Stimmt das noch?

## Entscheidungen

- 2026-10-10: Der Nutzer wählt das Feature "Raid-Aufstellung": Amisia nimmt eine Anmeldeliste, lädt
  automatisch ein und sortiert die Gruppen. Spec geschrieben; noch nicht freigegeben, gebaut wird
  erst nach "passt".
- 2026-10-10: Nutzer gibt frei ("ja passt so"): Flüstern beim Einladen Standard aus mit festem
  Text; Gäste nur mit der Einstellung "Gäste einladen" (Standard aus); die Einteilungsregeln wie
  beschrieben. Die übrigen Fragen nach den Vorschlägen der Spec. Bau zuerst Teil A, B und E (allein
  prüfbar); Teil C und D nach den Prüfungen 10, 11 und 13.
- 2026-10-10: Nutzer: kein eigener Discord-Bot und kein Anmelde-Reiter auf der Website (Teil F
  entfällt). Discord nur über das Einfügen des Bot-Texts (Teil A). Neu vorgesehen: Anmeldungen aus
  dem Ingame-Kalender (Gildenereignis mit Anmeldung, C_Calendar laut FrameXML 1.60.1 vorhanden) in
  dieselbe Liste; eigene Ergänzung der Spec, sobald der Nutzer im Spiel bestätigt hat, dass ein
  Gildenereignis mit Anmeldung angelegt werden kann.
- 2026-10-10: Gebaut: Teil A, B und E als F-083 (2.22.0), Regel D-41. Beim Bau entschieden: unklare
  und unbekannte Namen werden mit eingeteilt (orange/rot im Planer), damit der Planer auch ohne
  Gildenliste geht; nur Gäste warten auf "Gäste einladen". Der eigene Charakter zählt immer als online
  (Ersatzbank allein prüfbar). Die Einstellungen von Teil C und D (Flüstern, automatisch sortieren)
  kommen mit ihnen. `#AMISIA-RAID` liest nur das Addon (Ausnahme im Vertragstest), Teil F entfällt.
