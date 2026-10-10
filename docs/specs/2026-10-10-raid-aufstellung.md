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

### Teil G: Kalender

Viele Raider melden sich im Spielkalender an, nicht in Discord. Mit Teil G holt der Offizier diese
Anmeldungen mit einem Klick in dieselbe Aufstellung. Gelöst ist es, wenn niemand mehr Namen aus dem
Kalender abschreibt. (Teil G und H sind ein Entwurf vom 2026-10-10, noch nicht freigegeben.)

### Teil H: Anmelden in Amisia

Raider mit Amisia melden sich im Spiel an: mit Rolle und kurzer Notiz, ohne Discord. Gelöst ist es,
wenn der Offizier vor dem Raid jede Anmeldung mit Rolle in der Aufstellung sieht, egal ob sie aus
Discord, aus dem Kalender oder aus Amisia kommt.

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

### Teil G: Kalender

- Auf der Seite Aufstellung ein neuer Knopf **"Kalender"**. Er zeigt die kommenden Gildenereignisse
  aus dem Spielkalender: nur die Art "Schlachtzug", die nächsten 14 Tage. Ein Häkchen "Alle Arten
  zeigen" nimmt Dungeon, PvP, Treffen und Sonstiges dazu. Das nächste Schlachtzug-Ereignis ab heute
  ist schon gewählt.
- **"Übernehmen"** liest die Teilnehmerliste dieses Ereignisses in die Aufstellung. Die Raidnacht ist
  das Datum des Ereignisses (vor 06:00 zählt zur Nacht davor, D-23).
- Jede Zeile bekommt die Quelle **"Kalender"** (kleines Kalender-Zeichen) und den Status aus dem
  Kalender:

  | Im Kalender (`Enum.CalendarStatus`) | Amisia zeigt | Was es heißt |
  |---|---|---|
  | Signedup (6), Available (1) | angemeldet | wird eingeteilt |
  | Confirmed (3) | bestätigt | wird eingeteilt |
  | Tentative (8) | vorläufig | wie "vielleicht" |
  | Standby (5) | Ersatz | steht bei "Ersatz" |
  | Declined (2), Out (4) | abgesagt | wie "abgemeldet", nicht eingeteilt |
  | Invited (0) | eingeladen | grau unten, nicht eingeteilt |
  | NotSignedup (7) | ohne Antwort | grau unten, nicht eingeteilt |

- Klasse und Stufe kommen aus dem Kalender. Die **Rolle** steht nicht im Kalender. Sie kommt aus
  Teil H (der Spieler hat sich auch in Amisia angemeldet), sonst aus der letzten Aufstellung, sonst
  aus der Klasse (grau mit "?").
- Solange die Seite offen ist, liest Amisia die Liste neu, sobald sich im Kalender etwas ändert. Oben
  steht: "Kalender: Molten Core · Fr 20:00 · gelesen 19:42".
- Abgleich, Planer und Ersatzbank wie bei Teil A, B und E.
- Amisia **schreibt nie** in den Kalender des Offiziers: kein Einladen, kein Status, kein Ereignis
  anlegen oder ändern. Die einzige Ausnahme ist Teil H: ein Spieler meldet sich selbst an.

### Teil H: Anmelden in Amisia

- **Termine:** Raider sehen die kommenden Raidtermine. Die Termine kommen aus dem Spielkalender
  (Gildenereignisse der Art Schlachtzug, die nächsten 14 Tage). Nur wenn der Kalender in Forever
  nicht trägt, kündigt ein Offizier einen **"Raidtermin"** in Amisia an (Ersatzweg, Frage 26).
- **Karte "Raid-Anmeldung"** auf der Übersicht (für alle, auch Raider): die nächsten drei Termine,
  je eine Zeile, z. B. "Fr 20:00 Molten Core · angemeldet (H)" oder "noch offen". Ein Klick öffnet
  das kleine Fenster "Anmelden".
- **Fenster "Anmelden":** drei Knöpfe **Anmelden / Vorläufig / Abmelden**, die Rolle **T / H / N / F**
  (vorgewählt: die letzte eigene Rolle, sonst aus der Klasse) und ein Feld **Notiz** (höchstens 40
  Zeichen, z. B. "komme 20:15"). Darunter klein: "Für alle Offiziere sichtbar."
- **Befehl** `/amisia anmelden` (en `signup`): öffnet das Fenster für den nächsten Termin.
  `/amisia anmelden ab` (en `off`) meldet für den nächsten Termin ab, `/amisia anmelden H komme 20:15`
  meldet als Heiler mit Notiz an.
- **Chat** (nur beim Spieler selbst): "Raid-Anmeldung: Fr 20:00 Molten Core · angemeldet als Heiler."
  Und dahinter "Gesendet." oder "Kein Offizier online: Amisia schickt es, sobald einer kommt."
- **Kalender gleich mit:** Ist der Termin ein Gildenereignis mit Anmeldung, trägt derselbe Klick den
  Spieler auch im Spielkalender ein (Anmelden, Vorläufig, Abmelden). So sehen es auch Spieler ohne
  Amisia. Das geht nur, wenn das Spiel es aus einem Addon-Knopf erlaubt (Prüfungen 23 bis 25). Sonst
  zeigt das Fenster "Bitte auch im Kalender eintragen" mit einem Knopf, der den Kalender öffnet.
  Einstellung "Auch im Spielkalender eintragen" (an).
- **Beim Offizier:** Jede Anmeldung landet in der Aufstellung der Nacht, mit der Quelle **"Amisia"**,
  der Rolle und der Notiz (im Tooltip, dazu ein kleines Notiz-Zeichen). Die Zählung oben sagt
  zusätzlich "Liste 9 · Kalender 20 · Amisia 12".
- Meldet sich ein eingeteilter Spieler ab, schreibt Amisia dem Offizier eine Zeile:
  "Aufstellung: Anna Tankfrau hat sich abgemeldet (war Gruppe 3)."

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

### Teil G: Kalender

- **Kein Schreiben in den Kalender** durch den Offizier-Teil: kein Einladen, kein "Bestätigt" oder
  "Ersatz" setzen, kein Ereignis anlegen, kopieren oder löschen. Das bleibt im Kalenderfenster.
- **Keine Rollen im Kalender.** Der Kalender kennt keine.
- **Keine persönlichen Ereignisse und keine Gemeinschafts-Ereignisse**, nur Gildenereignisse.
- **Kein Lesen im Hintergrund:** Amisia liest den Kalender beim Offizier nur, wenn die Seite
  Aufstellung offen ist oder er klickt.

### Teil H: Anmelden in Amisia

- **Kein Anmelden für andere.** Jeder meldet nur sich selbst an: den Charakter, mit dem er gerade
  spielt.
- **Keine Anmeldung ohne Termin.**
- **Keine Website, kein eigener Discord-Bot** (Nutzer, 2026-10-10).
- **Kein Chat an andere:** die Anmeldung ist eine Addon-Nachricht. Die Notiz steht nie in einem Chat
  und nie im Export.
- **Kein Einladen auf Anmeldung.** Einladen bleibt der Klick des Offiziers (Teil C).
- **Keine Teilnehmerliste für Raider** ("wer kommt noch?"). Nur Offiziere sehen die Anmeldungen in
  Amisia (Frage 30); im Kalender sieht sie jeder wie bisher.
- **Keine Erinnerung im Chat** beim Login (Frage 31); nur die Karte zeigt "noch offen".

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

### Teil G: Kalender

1. Ein Offizier legt im Spielkalender ein Gildenereignis an ("Gilden-Ereignis erstellen", Art
   Schlachtzug, Datum, Uhrzeit). Raider melden sich dort an, oder über Amisia (Teil H).
2. Der Offizier öffnet die Seite Aufstellung und klickt "Kalender". Amisia fragt den Kalender ab und
   zeigt die Ereignisse. Das nächste Schlachtzug-Ereignis ist gewählt.
3. "Übernehmen": Amisia öffnet das Ereignis im Hintergrund, wartet auf die Antwort des Spiels und
   liest jeden Eintrag: Name, Klasse, Stufe, Status und wann er geantwortet hat.
4. Jeder Name geht durch denselben Abgleich wie bei Teil A (Korrektur, genau, Vorname ...). Steht
   der Name schon in der Liste (aus Discord oder Amisia), kommt er nicht doppelt hinein. Die Zeile
   bekommt die Quelle "Kalender" dazu, und der Status folgt der Regel "Welche Angabe gilt" (Teil H).
5. Die Nacht merkt sich das Ereignis (Titel, Beginn). Solange die Seite offen ist, liest Amisia bei
   jeder Änderung im Kalender neu, höchstens alle 5 Sekunden. Schließt der Offizier die Seite, schließt
   Amisia das Ereignis wieder.
6. Wer aus dem Kalender verschwindet und nur aus dem Kalender kam: grau "nicht mehr im Kalender",
   aus der Gruppe genommen (außer festgehalten).
7. Der Chat meldet: "Aufstellung: Kalender Molten Core, Fr 20:00: 22 Einträge, 18 angemeldet,
   2 vorläufig, 2 abgesagt."
8. Fügt der Offizier danach eine Liste ein (Teil A), ersetzt sie nur die Zeilen, die aus einer
   eingefügten Liste kamen. Zeilen aus Kalender und Amisia bleiben.

### Teil H: Anmelden in Amisia

Beim Raider:

1. 40 bis 70 Sekunden nach dem Login (nicht im Kampf) liest Amisia die Termine aus dem Kalender. Die
   Karte zeigt sie.
2. Der Raider klickt bei einem Termin "Anmelden", wählt Rolle und Notiz und klickt "Senden".
3. Amisia speichert die Anmeldung bei ihm (Charakter, Termin, Status, Rolle, Notiz, Zeit).
4. Amisia schickt eine Nachricht `AN` an die Gilde. Jeder Offizier mit Amisia, der online ist,
   nimmt sie in seine Aufstellung.
5. Ist der Termin ein Gildenereignis mit Anmeldung und die Einstellung an: derselbe Klick trägt ihn
   im Spielkalender ein. Nur beim Klick, nie beim Wiederholen.
6. Ändern: dasselbe Fenster, neuer Klick. Die neue Angabe ersetzt die alte.
7. Wiederholen, damit keine Anmeldung verloren geht: beim nächsten eigenen Login schickt Amisia die
   Anmeldungen für kommende Termine einmal erneut (höchstens 4, gedrosselt). Und wenn ein Offizier
   sich einloggt, fragt sein Amisia einmal in die Gilde (`AQ`); jeder Raider-Client antwortet ihm per
   Flüstern mit seinen offenen Anmeldungen, verteilt über 0 bis 20 Sekunden.

Beim Offizier:

8. Amisia prüft den Absender (Gildenmitglied laut Gildenliste; der Name ist der Absender, den der
   Server setzt), das Datum (heute bis 14 Tage) und jedes Feld. Dann kommt die Anmeldung in die
   Nacht, auch wenn es für die Nacht noch keine Aufstellung gibt.
9. Eigene Charaktere desselben Kontos: Amisia übernimmt ihre Anmeldungen direkt aus dem eigenen
   Speicher, ohne Nachricht.

**Welche Angabe gilt** (pro Name und Nacht):

1. **Was der Offizier von Hand macht, bleibt:** Gruppe, Festhalten, Ersatz, Rolle von Hand. Eine
   neue Anmeldung verschiebt niemanden. Hat der Offizier jemanden entfernt und der meldet sich
   danach neu an, steht er wieder unter "Nicht eingeteilt".
2. **Status** (angemeldet, vorläufig, abgemeldet): Es gilt die **neueste Angabe des Spielers selbst**,
   aus Amisia (Zeit des Klicks) oder aus dem Kalender (Antwortzeit des Kalenders). Liegen beide
   weniger als 2 Minuten auseinander, gilt Amisia (meist derselbe Klick; Amisia hat Rolle und Notiz).
3. Eine **eingefügte Liste** (Discord, Teil A) hat keine Zeit pro Zeile. Sie gilt als **älter** als
   jede Angabe in Amisia oder im Kalender. Ein Abmelden in Amisia oder im Kalender schlägt also
   immer ein "angemeldet" aus Discord, und umgekehrt. Weicht die Liste ab, zeigt die Zeile einen
   Hinweis: "Discord: angemeldet".
4. Was ein Offizier im Kalender setzt ("Bestätigt", "Ersatz", "Raus"), zählt wie eine Angabe des
   Kalenders mit ihrer Zeit.
5. **Rolle:** von Hand (Offizier) vor Amisia-Anmeldung vor eingefügter Liste vor letzter Aufstellung
   vor Klasse (geraten, "?"). Der Kalender kennt keine Rolle.
6. **Abmelden** eines Eingeteilten: er kommt aus der Gruppe, und der Offizier bekommt eine
   Chatzeile. Ein Festgehaltener bleibt in seiner Gruppe, rot "abgemeldet"; der Offizier entscheidet.
7. Ein Name aus mehreren Quellen ist **eine** Zeile mit allen Quellen-Zeichen (Liste, Kalender,
   Amisia).

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

"Allein" heißt bei Teil G und H: mit den eigenen Charakteren Vulo Hunt (Offizier) und Vulo Pala
(Veteran) desselben Kontos, nacheinander eingeloggt. Alles mit "(braucht: ...)" ab 2026-11-04 (D-32).

### Teil G: Kalender

F-086 (Vorschlag).

- Wenn du als Vulo Hunt im Spielkalender ein Gildenereignis "Schlachtzug" für morgen 20:00 anlegst
  und auf der Seite Aufstellung "Kalender" klickst, dann ist dieses Ereignis gewählt, und nach
  "Übernehmen" steht Vulo Hunt mit Quelle "Kalender" und Status "bestätigt" in der Aufstellung von
  morgen. (allein)
- Wenn sich Vulo Pala im Kalenderfenster des Spiels für dieses Ereignis anmeldet und du danach als
  Vulo Hunt "Übernehmen" klickst, dann steht Vulo Pala grün "angemeldet" als Paladin, mit der Rolle
  aus der letzten Aufstellung oder grau "H?". (allein)
- Wenn du nach dem Kalender einen Discord-Text einfügst, dann bleiben die Kalender-Zeilen stehen, und
  ein Name, der in beiden steht, steht einmal da, mit zwei Quellen-Zeichen. (allein)
- Wenn du "Übernehmen" geklickt hast, dann ist im Kalenderfenster nichts verändert: keine neuen
  Einladungen, kein anderer Status. (allein)
- Wenn sich ein anderes Gildenmitglied im Kalender anmeldet oder absagt, während deine Seite
  Aufstellung offen ist, dann ändert sich seine Zeile nach wenigen Sekunden ohne Klick.
  (braucht: Gilde)

### Teil H: Anmelden in Amisia

F-087 (Vorschlag).

- Wenn du als Vulo Hunt auf der Karte "Raid-Anmeldung" beim Termin von morgen "Anmelden" mit Rolle T
  und der Notiz "komme 20:15" sendest, dann steht Vulo Hunt in der Aufstellung von morgen mit Quelle
  "Amisia", Rolle T und der Notiz im Tooltip. (allein)
- Wenn du dich als Vulo Pala mit `/amisia anmelden` vorläufig als Heiler anmeldest und danach als
  Vulo Hunt einloggst, dann steht Vulo Pala orange "vorläufig" mit H und Quelle "Amisia". (allein:
  derselbe Account, ohne Nachricht)
- Wenn Vulo Pala über Amisia "Anmelden" klickt, dann zeigt das Kalenderfenster des Spiels bei
  Vulo Pala "Angemeldet", und Vulo Hunt sieht ihn danach mit den Quellen Kalender und Amisia.
  (allein; erst nach den Prüfungen 23 bis 25)
- Wenn du nach "Anmelden" "Abmelden" klickst, dann steht dein Name grau "abgemeldet" und ist aus
  seiner Gruppe genommen, und der Offizier liest im Chat "Aufstellung: ... hat sich abgemeldet (war
  Gruppe N)." (allein)
- Wenn du einen Discord-Text mit Vulo Pala als "Heiler" einfügst und Vulo Pala sich danach in Amisia
  abmeldet, dann steht er "abgemeldet" mit dem Hinweis "Discord: angemeldet". (allein)
- Wenn sich ein Raider anmeldet, während kein Offizier online ist, und sich später ein Offizier
  einloggt, während der Raider online ist, dann steht die Anmeldung nach höchstens 2 Minuten in der
  Aufstellung des Offiziers. (braucht: Gilde)
- Wenn ein Raider eine Notiz mit Farbcode und 100 Zeichen sendet, dann zeigt der Offizier höchstens
  40 Zeichen ohne Farbe, und kein Chat zeigt die Notiz. (braucht: Gilde)

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

### Teil G: Kalender

- **Kalender aus oder leer** (Forever schaltet ihn ab, `C_Calendar` fehlt, keine Ereignisse): der Knopf
  "Kalender" ist grau mit dem Grund. Teil A geht wie bisher.
- **Kalenderfenster des Spiels offen:** Amisia öffnet dann kein Ereignis, denn das würde im Fenster
  das gewählte Ereignis wechseln. Ist im Fenster genau das gewählte Ereignis offen, liest Amisia es;
  sonst steht da "Kalenderfenster schließen, dann Übernehmen".
- **Keine Antwort:** Kommt nach 10 Sekunden nichts, sagt Amisia "Kalender antwortet nicht, gleich
  nochmal". Fehler zeigt das Spiel selbst als Fenster.
- **Unvollständige Liste:** Meldet das Spiel, dass die Liste noch nicht ganz da ist, wartet Amisia auf
  den Rest. Höchstens 80 Namen wie bei Teil A.
- **Name ohne Nachname im Kalender** (Prüfung 20): Abgleich über den eindeutigen Vornamen wie bei
  Teil A, Schritt 4.
- **Zwei Schlachtzug-Ereignisse an einem Abend:** der Offizier wählt eines. Wechselt er, ersetzt das
  neue Ereignis die Kalender-Zeilen.
- **Ereignis um 00:30:** gehört zur Nacht davor (D-23).
- **Ereignis gelöscht oder verschoben:** "Ereignis nicht mehr im Kalender". Die Zeilen bleiben, das
  Kalender-Zeichen wird grau.
- **Kampf, Kampfsperre:** Amisia liest den Kalender nicht im Kampf; es wartet bis danach.

### Teil H: Anmelden in Amisia

- **Kein Termin:** die Karte sagt "Keine Raidtermine in den nächsten 14 Tagen." Anmelden geht nicht.
- **Kein Offizier online:** gespeichert und später geschickt (Abläufe, Schritt 7). Der Chat sagt es.
- **Nicht in einer Gilde:** die Karte sagt "Nur in einer Gilde". Nichts wird gesendet.
- **Twinks:** angemeldet ist der Charakter, mit dem man spielt. Die Karte zeigt die Anmeldungen der
  anderen eigenen Charaktere dazu ("Vulo Pala: angemeldet"), damit keiner zwei Charaktere anmeldet.
  Beim Offizier hilft der Twink-Tausch aus Teil A.
- **Kampf, Kampfsperre:** die Nachricht wartet, bis die Sperre vorbei ist (wie jede Nachricht). Der
  Kalender-Eintrag geht im Kampf nicht: der Knopf sagt "Nach dem Kampf".
- **`/reload`:** die Anmeldungen sind gespeichert. Das Wiederholen kommt nur einmal pro Sitzung.
- **Zwei Offiziere:** beide bekommen jede Anmeldung, jeder in seiner Aufstellung (kein Teilen,
  Frage 9).
- **Falsche Uhr des Raiders:** liegt die Zeit in der Zukunft, nimmt der Offizier "jetzt". Eine
  Wiederholung trägt die Zeit des ersten Klicks.
- **Termin vorbei:** nach 06:00 des nächsten Tages keine Anmeldung mehr; alte werden gelöscht.
- **Englischer Client:** die Rollen heißen dort Tank, Healer, Melee, Ranged; die Nachricht trägt
  immer T/H/M/R.
- **Gast** (kein Gildenmitglied): kann sich nicht in Amisia anmelden (Gildenkanal). Der Offizier
  sieht ihn nur über den Kalender oder die eingefügte Liste.

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

### Teil G: Kalender

- **Nur Offiziere** (D-41). Das Lesen verrät nichts Neues: jedes Mitglied sieht dieselbe Liste im
  Spiel.
- **Kalender-Texte sind unvertraut:** Titel, Namen und Notizen ohne Farbcodes und Striche, Titel und
  Notizen höchstens 40 Zeichen, Namen wie bei Teil A (48 Zeichen, keine Ziffern). Nur angezeigt.
- **Amisia schreibt beim Offizier nichts in den Kalender.** Ein Fehler kann dort niemanden einladen,
  ausladen oder umstellen.

### Teil H: Anmelden in Amisia

- **Nur für sich selbst:** der Name ist der Absender, den der Server setzt, nie ein Feld der
  Nachricht. Niemand kann einen anderen an- oder abmelden.
- **Nur Gildenmitglieder:** der Offizier nimmt `AN` nur von Mitgliedern laut Gildenliste. Fremde
  werden verworfen.
- **Offiziere kann man nicht vortäuschen:** ein Raider antwortet auf die Frage `AQ` nur, wenn der
  Fragende laut Gildenliste Offiziersrang hat (Rangrecht 22, D-18). Ein Raidtermin (`AT`, falls
  gebaut) zählt nur von einem geprüften Offizier. Was die Nachricht über den Absender sagt, zählt nie.
- **Fluten:** pro Absender und Nacht höchstens eine `AN` alle 10 Sekunden, eine `AQ` alle
  30 Sekunden, dazu die Grenzen aller Nachrichten (40 in 10 Sekunden). Der Offizier nimmt höchstens
  4 Nächte pro Absender, nur heute bis 14 Tage, 80 Namen pro Nacht. Ein Raider antwortet einem
  Offizier höchstens einmal in 10 Minuten, mit höchstens 4 Nachrichten.
- **Notiz:** höchstens 40 Zeichen, ohne Farbcodes, Links, Striche `|`, Tabulator und Steuerzeichen.
  Nur im Tooltip der Seite, nie in einem Chat, nie im Export. Sie geht an alle Amisia-Clients der
  Gilde; darum der Hinweis "Für alle Offiziere sichtbar".
- **Rolle und Klasse** nur aus festen Listen (T/H/M/R, die neun Klassen). Ein anderer Wert verwirft
  die ganze Nachricht.
- **Kalender-Eintrag** nur auf den eigenen Klick und nur für den eigenen Charakter (die Funktionen
  des Spiels kennen keinen anderen). Nie von einer Nachricht ausgelöst.
- **Raider ohne Amisia** merken nichts. Sie bekommen keine Nachricht und melden sich wie bisher an.
- **Kein Dauerfunk** (D-19): eine `AQ` pro Sitzung, das Wiederholen einmal pro Sitzung, nichts im
  Schlachtfeld; in der Sperre wartet es.

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

### Teil G: Kalender

- **Neue Datei** `Raid/Calendar.lua`: Termine und Teilnehmerliste lesen, Status übersetzen (für
  Teil G und H). Eine Zeile in der TOC und der Module map.
- **`AmisiaDB.lineup`** bleibt `v = 1`; neue Felder, beim Laden Feld für Feld geprüft:
  - pro Nacht `cal = { id = Kennung des Ereignisses, at = Beginn (Epoch), title (40), read = Epoch
    des letzten Lesens }`;
  - pro Eintrag `f` = Quellen (Buchstaben `L` Liste, `K` Kalender, `A` Amisia), `st` = Status der
    geltenden Angabe (`A` angemeldet, `B` bestätigt, `V` vorläufig, `E` Ersatz, `X` abgesagt oder
    abgemeldet, `I` eingeladen, `O` ohne Antwort, `G` nicht mehr im Kalender), `t` = Zeit dieser
    Angabe, `w` = Notiz (40), `h = true` Rolle vom Offizier gesetzt, `d` = abweichender Status der
    eingefügten Liste (für "Discord: angemeldet"). Die bisherigen Felder `m` (vielleicht), `a`
    (abgemeldet) und `b` (Ersatz) folgen dem Status.
- **Einstellung** im Abschnitt `lineup`: `lineup.calendarAll` "Alle Arten von Gildenereignissen
  zeigen" (aus).
- **Keine Nachricht, keine Blob-Art, keine Exportzeile, kein Einfügeblock.**
- **Spiel-Funktionen** (laut `Blizzard_APIDocumentationGenerated/CalendarDocumentation.lua`, Forever
  1.60.1.70205; Zeilennummer in Klammern):
  - Termine: `C_Calendar.OpenCalendar()` (821) lädt die Daten; `GetNumGuildEvents()` (733),
    `GetGuildEventInfo(i)` (625: `eventID`, Jahr, Monat, Tag, Stunde, Minute, `eventType`, `title`,
    `calendarType`, eigener `inviteStatus`), `GetGuildEventSelectionInfo(i)` (641: Monat-Versatz,
    Tag, Index im Tag). Ereignis `CALENDAR_UPDATE_GUILD_EVENTS` (981).
  - Liste: `OpenEvent(monat, tag, index)` (825, gibt true/false), dann `CALENDAR_OPEN_EVENT` (926);
    `GetEventInfo()` (599: Titel, Art, `calendarType`, `inviteType`, Zeit, gesperrt);
    `GetNumInvites()` (742), `EventGetInvite(i)` (246: `name`, `level`, `className`,
    `classFilename`, `inviteStatus`, `modStatus`, `type`, `notes`, `guid`; Aufbau Zeile 1066);
    `EventGetInviteResponseTime(i)` (263); `CALENDAR_UPDATE_INVITE_LIST` (987, mit
    `hasCompleteList`); `IsEventOpen()` (787), `CloseEvent()` (43).
  - Arten: `Enum.CalendarEventType` Raid 0, Dungeon 1, PvP 2, Meeting 3, Other 4
    (`CalendarConstantsDocumentation.lua` 128); `Enum.CalendarStatus` 0 bis 8 (dort 241);
    `Enum.CalendarInviteType` Normal 0, Signup 1 (216); `calendarType` ist ein Text: `"GUILD_EVENT"`,
    `"GUILD_ANNOUNCEMENT"`, `"PLAYER"`, `"COMMUNITY_EVENT"` (Blizzard_Calendar.lua 725-731).
  - Sperren: nur `AddEvent` (11) und `UpdateEvent` (877) tragen `HasRestrictions`; Lesen und
    Anmelden tragen kein Sperr-Kennzeichen, viele nur `SecretArguments = "AllowedWhenUntainted"`
    (heißt: keine geheimen Werte als Argument). Ob ein Addon sie ohne Tastendruck rufen darf:
    Prüfungen 19 und 23.
  - Achtung: das Kalenderfenster des Spiels reagiert auf jedes `CALENDAR_OPEN_EVENT` und zeigt das
    Ereignis an (Blizzard_Calendar.lua 1106-1120); darum öffnet Amisia nichts, solange es offen ist.

### Teil H: Anmelden in Amisia

- **Neue Dateien:** `Raid/Signup.lua` (eigene Anmeldungen, Nachrichten, Übernahme beim Offizier,
  Kalender-Eintrag) und `UI/Signup.lua` (Karte "Raid-Anmeldung", Fenster "Anmelden"), je eine Zeile
  in TOC und Module map. Texte in `L["…"]`, Englisch in `Locales/enUS_raid2.lua`.
- **`AmisiaDB.signup`** (neu, Owner `Raid/Signup.lua`): `{ v = 1, chars = { [Name] = { ["JJJJ-MM-TT"]
  = { s = A/V/X, r = T/H/M/R, t = Epoch des Klicks, w = Notiz (40), e = Kennung des
  Kalenderereignisses oder nil, k = "ok"/"err" (Kalender-Eintrag) } } }, sent = Epoch }`. Beim Laden
  geprüft: Nächte vor heute weg, 4 Nächte pro Charakter, 12 Charaktere.
- **Beim Offizier** keine eigene Tabelle: die Anmeldungen stehen in `AmisiaDB.lineup` (Felder siehe
  Teil G). Eine Anmeldung für eine Nacht ohne Aufstellung legt die Nacht an (zählt zu den 8 Nächten).
- **Nur falls der Ersatzweg gebaut wird** (Frage 26): `AmisiaDB.raidDates = { rev, by, list =
  { { d = JJJJ-MM-TT, hm = HHMM, title (40) } } }`, höchstens 4 Termine.
- **Einstellungsabschnitt** `signup` "Raid-Anmeldung" (für alle, `Raid/Signup.lua`):
  `signup.calendar` "Auch im Spielkalender eintragen" (an), `signup.card` "Karte auf der Übersicht"
  (an). Im Abschnitt `lineup` (Offiziere): `lineup.signups` "Anmeldungen aus Amisia annehmen" (an).
- **Befehl** `/amisia anmelden` (en `signup`), für alle; Unterwort `ab` (en `off`).
- **Karte** `signup` auf der Übersicht (`ns.RegisterCard`, für alle).
- **Neue Nachrichtenarten** (Präfix `Amisia`; Zeilen für ARCHITECTURE "Message kinds", `VALID`,
  `KIND_GAP`/`KEYED_GAP` in `Core/Comm.lua`; keine neue Protokollnummer, unbekannte Arten werfen
  alte Clients weg):

  | Kind | Sender -> channel | Receiver trust | Gap (per sender) | Fields (after the kind) |
  |---|---|---|---|---|
  | `AN` | raider -> GUILD on the click and once per session after the login (low); WHISPER as answer to an officer's `AQ` | member (the name is the sender); kept only in officer view with officer rank and `lineup.signups`; night today .. +14 days; 4 nights per sender | keyed 10 s per night | night `yyyy-mm-dd`, status `A`/`V`/`X`, role `T`/`H`/`M`/`R`/`-`, class token or `-`, epoch of the click, calendar event id (digits, max 20) or `-`, [note or `-`, 40 bytes, no `\|`, tab or control] |
  | `AQ` | everyone -> GUILD once 40-70 s after the login (low) | member; answered with WHISPER `AN` only to a verified officer, with `AT` only by an officer | 30 s | flag `O` (asks for sign-ups) or `-`, known raid date rev (0: none) |
  | `AT` | only with the fallback (question 26): officer -> GUILD after a change; WHISPER as answer to `AQ` | officer; only a newer rev (max 1 day ahead) | 30 s | rev, set by, dates `yyyymmdd:hhmm` (max 4, comma) or `-`, [title of the first, 40] |

- **Keine Blob-Art, keine Exportzeile, kein Einfügeblock, kein Website-Zustand.** Wer sich anmeldet,
  geht nicht an die Website (wie bei Teil A).
- **Spiel-Funktionen zum Eintragen** (CalendarDocumentation.lua): `ContextMenuSelectEvent(monat, tag,
  index)` (165) mit `ContextMenuEventSignUp()` (135), `ContextMenuInviteAvailable()` (149),
  `ContextMenuInviteTentative()` (161), `ContextMenuInviteDecline()` (153); nach `OpenEvent`:
  `EventSignUp()` (507), `EventAvailable()` (193), `EventTentative()` (522), `EventDecline()` (224),
  `RemoveEvent()` (842). Das Kalenderfenster ruft bei einem Ereignis mit Anmeldung
  `EventSignUp`/`EventTentative`, zeigt dort kein "Absagen" (Blizzard_Calendar.lua 3055-3070) und
  nimmt die Anmeldung mit "Entfernen" = `RemoveEvent()` zurück (2947-2949). Bei einer normalen
  Einladung: `EventAvailable`, `EventTentative`, `EventDecline` (2909-2934).
- **DECISIONS:** neue Regel (nächste freie Nummer, heute D-42): "Anmelden in Amisia und Kalender:
  nur für sich selbst, nur Gildenmitglieder, Offiziere laut Gildenliste, Kalender schreiben nur der
  Spieler per Klick für sich, der Offizier-Teil liest nur."
- **FEATURES:** F-086 (Teil G), F-087 (Teil H).

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

### Teil G: Kalender

17. **Prüfung allein: Termine lesen.** Als Vulo Hunt ein Gildenereignis "Schlachtzug" für morgen
    anlegen. Dann `/run C_Calendar.OpenCalendar()` und nach zwei Sekunden
    `/dump C_Calendar.GetNumGuildEvents(), C_Calendar.GetGuildEventInfo(1)`
    (erwartet: 1 oder mehr; eine Tabelle mit `eventType = 0`, `calendarType = "GUILD_EVENT"`, Titel,
    Datum, Uhrzeit). Dasselbe als Vulo Pala. Und ein Ereignis in 10 Tagen: zeigt die Liste so weit
    voraus? (Sonst nimmt Amisia die Tage aus `GetNumDayEvents`/`GetDayEvent`.)
18. **Prüfung allein: Teilnehmerliste ohne Kalenderfenster.** Kalenderfenster zu, dann
    `/run local i=C_Calendar.GetGuildEventSelectionInfo(1) print(C_Calendar.OpenEvent(i.offsetMonths or i.offsetMonth or 0, i.monthDay, i.eventIndex))`
    (erwartet: true; die Doku sagt `offsetMonths`, das Spiel selbst liest `offsetMonth`), dann
    `/dump C_Calendar.GetEventInfo()` und `/dump C_Calendar.GetNumInvites(), C_Calendar.EventGetInvite(1)`
    (erwartet: Titel, `calendarType = "GUILD_EVENT"`; ein Eintrag mit `name`, `classFilename =
    "HUNTER"`, `level`, `inviteStatus = 3`). Danach `/run C_Calendar.CloseEvent()`.
19. **Prüfung allein: ohne Tastendruck.** Wie 18, aber in
    `/run C_Timer.After(1,function() ... end)`, mit `/etrace` auf `ADDON_ACTION_BLOCKED`,
    `CALENDAR_OPEN_EVENT` und `CALENDAR_UPDATE_INVITE_LIST`. Erwartet: nichts blockiert. Sonst liest
    Amisia nur beim Klick auf "Übernehmen", und die Liste aktualisiert sich nicht von selbst.
20. **Prüfung allein: Name und Zeit.** Steht in `EventGetInvite(1).name` "Vulo Hunt" (mit Nachname)
    oder nur "Vulo"? Und `/dump C_Calendar.EventGetInviteResponseTime(1)` (erwartet: Jahr, Monat,
    Tag, Stunde, Minute).
21. **Notizen im Kalender:** `EventGetInvite(i).notes` gibt es, aber die Doku kennt keine Funktion,
    die eine eigene Notiz setzt. Vorschlag: anzeigen, wenn eine da ist; sonst nichts.
22. **Entscheidung:** nur die Art "Schlachtzug" vorschlagen, "Alle Arten zeigen" aus; neu lesen nur,
    solange die Seite offen ist. Vorschlag: ja.

### Teil H: Anmelden in Amisia

23. **Prüfung allein: Anmelden im Kalender aus Addon-Code.** Als Vulo Pala (noch nicht angemeldet)
    bei Vulo Hunts Ereignis, Kalenderfenster zu:
    `/run local i=C_Calendar.GetGuildEventSelectionInfo(1) C_Calendar.ContextMenuSelectEvent(i.offsetMonths or i.offsetMonth or 0,i.monthDay,i.eventIndex) C_Calendar.ContextMenuEventSignUp()`
    (erwartet: im Kalenderfenster "Angemeldet"; `/dump C_Calendar.GetGuildEventInfo(1).inviteStatus`
    gibt 6). Mit `/etrace` auf `ADDON_ACTION_BLOCKED` und `ADDON_ACTION_FORBIDDEN` achten. Geht es
    nicht, öffnet Amisia nur das Kalenderfenster, und der Spieler klickt dort selbst.
24. **Prüfung allein: Vorläufig.** Nach dem Öffnen wie in 18: `/run C_Calendar.EventTentative()`
    (erwartet: "Vorläufig", Status 8). Und ohne Öffnen:
    `/run ... C_Calendar.ContextMenuSelectEvent(...) C_Calendar.ContextMenuInviteTentative()` (geht das
    bei einem Ereignis mit Anmeldung?).
25. **Prüfung allein: Abmelden.** Das Spiel zeigt bei Ereignissen mit Anmeldung kein "Absagen", nur
    "Entfernen" (= `C_Calendar.RemoveEvent()`). Nach dem Öffnen `/run C_Calendar.EventDecline()`:
    steht Vulo Pala dann beim Offizier "abgesagt" (Status 2)? Sonst `/run C_Calendar.RemoveEvent()`:
    verschwindet der Name? Vorschlag: nehmen, was den Namen "abgesagt" stehen lässt; sonst Entfernen,
    und Amisias Abmeldung sagt dem Offizier den Grund.
26. **Entscheidung Termine.** Vorschlag: der Kalender ist die einzige Quelle der Termine. Den
    Ersatzweg "Raidtermin in Amisia" (`AT`) bauen wir nur, wenn 17 oder 18 scheitern oder die Gilde
    den Kalender nicht nutzen will. Alternative: beides von Anfang an.
27. **Entscheidung Rangfolge:** wie unter "Welche Angabe gilt" (Abläufe, Teil H). Vorschlag: ja; vor
    allem gilt eine eingefügte Discord-Liste immer als älter als Amisia und Kalender.
28. **Entscheidung Weg der Nachricht.** Vorschlag: eine Nachricht an die Gilde (alle Offiziere online
    bekommen sie; die Notiz können alle Amisia-Clients der Gilde lesen). Alternative: Flüstern nur an
    Offiziere, die Amisia haben (mehr Nachrichten, Notiz privater).
29. **Entscheidung Wiederholen.** Vorschlag: ja, einmal pro Sitzung beim eigenen Login und als
    Antwort auf die Frage eines Offiziers, der sich einloggt.
30. **Entscheidung:** Sehen Raider, wer sich angemeldet hat? Vorschlag: nein, nur Offiziere.
31. **Entscheidung:** Erinnerung im Chat beim Login ("Raid morgen 20:00: noch nicht angemeldet")?
    Vorschlag: nein, nur die Karte.
32. **Reihenfolge des Baus (G und H).** Vorschlag:
    1. Prüfungen 17 bis 20 und 23 bis 25 im Spiel, allein (der Nutzer, etwa 15 Minuten).
    2. Teil G1: Termine lesen und Auswahl auf der Seite Aufstellung (S).
    3. Teil G2: Teilnehmerliste lesen, Status übersetzen, mit Quellen zusammenführen, neu lesen bei
       Änderungen (M). Danach ist F-086 allein prüfbar.
    4. Teil H1: Karte, Fenster, `/amisia anmelden`, eigener Speicher, Übernahme der eigenen
       Charaktere ohne Nachricht, Regel "Welche Angabe gilt" (M). Allein prüfbar.
    5. Teil H2: Nachrichten `AN` und `AQ`, Annahme beim Offizier, Wiederholen (M). Voll prüfbar ab
       2026-11-04.
    6. Teil H3: Kalender-Eintrag aus dem Knopf (S), nur nach den Prüfungen 23 bis 25.
    7. Nur falls nötig (Frage 26): Raidtermin in Amisia, `AT` (S bis M).

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
- 2026-10-10: Teil G und H auf Wunsch des Nutzers ergänzt; noch nicht freigegeben.
- 2026-10-10: Nutzer gibt Teil G und H frei ("ja"): Kalender einzige Terminquelle (AT nur falls
  nötig), Raider sehen keine Teilnehmerliste, keine Chat-Erinnerung beim Login, die übrigen Fragen
  nach den Vorschlägen. Reihenfolge: zuerst ein Prüfbefehl `/amisia selbsttest kalender`, der die
  Prüfungen 17 bis 20 selbst macht und meldet; dann G, dann H1/H2; H3 (Eintrag in den Kalender)
  erst nach grüner Prüfung 23 bis 25.
- 2026-10-10: Gebaut: der Prüfbefehl `/amisia selbsttest kalender` (en `selftest calendar`) als F-085
  (2.23.0): macht die Prüfungen 17 bis 20 selbst (nur lesend, die Schreibfunktionen für 23 bis 25 nur
  nachgeschlagen) und zeigt den Bericht im Selbsttest-Fenster. Teil G heißt damit F-086, Teil H F-087.
- 2026-10-10: Im Spiel (Prüfung 17, Client 70338): das Ereignis des Nutzers kam als Art "Sonstiges"
  bzw. "Treffen" an. Die Art "Schlachtzug" verlangt im Kalender eine Raid-Instanz (Bildauswahl), die
  Forever vor dem Raidstart wohl nicht anbietet. Daher nimmt Teil G (und die Prüfung) jedes
  Gildenereignis (GUILD_EVENT); Schlachtzug-Ereignisse stehen nur vorn. Frage 22 ist damit geändert.
