# Spec: Werkzeuge: eine Zeile je Scan, Klartext, nächster Schritt

Stand: 2026-11-13 · Status: freigegeben (Nutzer 2026-11-13 auf der Seite Gilde > Werkzeuge: "wie können wir
die werkzeuge und das scannen und übermittel der daten verbesserm"; von sieben Vorschlägen "Ja, 1 bis 3": 1.
"Eine Zeile je Aufgabe statt sechs Links und vier Textzeilen", 2. "Klartext statt Technik", 3. "Eine Zeile
Nächster Schritt, die nur erscheint, wenn etwas zu tun ist") · Feature: F-186

## Ziel

Die Seite Werkzeuge zeigte sechs Links in einer Reihe, vier Textzeilen mit Nummern ("nächste ID 302971 von
3111111") und einen Hinweis auf Python-Dateien; "NPC-Scan fertig: 0 Namen gespeichert" las sich wie ein Fehler.
Gelöst ist es, wenn jede Aufgabe ihre Zeile mit Stand in Worten, Fortschritt und nur den passenden Aktionen hat
und eine Zeile sagt, was als Nächstes zu tun ist.

## Was es tut

- Vier Zeilen (Bänder `row`, `W.Page`): **Ausrüstung** (der Item-Scan), **Quests**, **NPCs** (die Scans per
  Nummer, D-104), **Sammler** (der Item-Sammler). Jede Zeile: Name (gold), Stand in Worten, ein Balken
  (`W.ProgressBar`, die Fertigkeitsleiste des Berufsfensters) solange ein Lauf läuft oder angehalten ist und die
  Gesamtzahl bekannt ist, rechts die Aktionen als ruhige Links (D-67).
- Stand in Worten: "Noch nicht gelaufen.", "Läuft: 10 %, etwa 2 h 05 min übrig", "Angehalten: 10 %, noch etwa
  2 h 05 min", "Fertig: 312 neue Quests warten auf die Übernahme.", "Fertig: alles übernommen."; NPCs: "Bekannte
  NPCs fertig; die Suche nach neuen dauert etwa ...", "Sucht neue NPCs: ...", "Der Client nennt keine
  NPC-Namen."; Sammler: "An: 501 Items mit Quelle warten auf die Übernahme." / "An: alles übernommen." / "Aus.".
- Prozent ehrlich: bezogen auf das, was der Lauf wirklich fragt: beim Bereich von seinem Anfang bis zu seinem
  Ende (auch nach "Fortsetzen" der ganze Bereich), bei der Ausrüstungsliste und "Offene wiederholen" die Liste
  des Laufs, bei Quests die Questliste des Clients, bei NPCs die Liste der Phase. Ohne bekannte Gesamtzahl kein
  Prozent ("Läuft ..."). Restzeit aus der Rate (Item-Scan: Einstellung `tools.scanRate`, Nummern je Sekunde;
  Quests und NPCs: ihre Schätzung wie im Chat), geschrieben mit `SB.Duration`.
- Aktionen: "Starten" (Ausrüstung: der Ausrüstungs-Scan `/amisia scan gear`; Quests, NPCs: ihr Scan),
  "Fortsetzen" nur bei einem angehaltenen Lauf (Ausrüstung: der Bereich `/amisia scan`), "Anhalten" nur in der
  Zeile, die läuft, "Offene wiederholen (n)" nur mit offenen Items, beim Sammler "Ausschalten"/"Einschalten"
  (schreibt die Einstellung `tools.collect`, die die Wahrheit bleibt). Ein fertiger NPC-Scan bietet nichts an.
- Nur ein Scan zur Zeit (D-104): läuft einer, sind die Start-Links der anderen Zeilen grau, ihr Tooltip sagt
  "Es läuft schon ein Scan". Neu lehnt auch der Item-Scan ab, solange ein Scan per Nummer läuft.
- "Nächster Schritt:" unter den Zeilen, das Erste, was zutrifft (sonst leer):
  1. Ein Scan hielt in einer Instanz an (in dieser Sitzung): "Ein Scan hielt in der Instanz an: außerhalb von
     Instanzen in seiner Zeile fortsetzen." (draußen: "... in seiner Zeile fortsetzen."). Er läuft nicht von
     selbst weiter.
  2. Neue Einträge seit dem Laden des Addons (Item-Scan, Quest-Scan, NPC-Scan, Sammler; ein Zähler):
     "312 neue Einträge seit dem Einloggen: ausloggen oder /reload, damit sie gespeichert werden."
  3. Items ohne Antwort: "3 Items ohne Antwort: Offene wiederholen."
  Während ein Scan läuft, steht dort nichts.
- Die Zeilen folgen einem laufenden Scan einmal je Sekunde, nur solange die Seite offen ist (nur Texte und
  Balken, nichts wird neu gebaut). Der Untertitel heißt "Scans für die Daten, Drops der Gilde.".
- Die Chatzeilen nennen keine Dateinamen mehr ("Diese Version hat keine Liste der Quests.").

## Was es ausdrücklich nicht tut

Nicht Teil: ein Knopf für alle Scans, die automatische Übernahme auf dem N100, Drops für die Website ohne
Einfügen, die Anzeige des Austauschs in der Gilde. Der Teil "Drop-Daten" bleibt, wie er ist. Die Befehle
`/amisia scan ...` bleiben gleich (die Zeilen rufen dieselben Funktionen); ihre Chatzeilen dürfen technisch
bleiben. Kein roter Knopf mehr im Scan-Teil.

## Abläufe

1. Der Spieler öffnet Gilde > Werkzeuge (Expertenmodus). Jede Zeile sagt ihren Stand.
2. Er klickt in der Zeile Quests "Starten": die Zeile zeigt "Läuft: 0 %, etwa 5 min übrig" und den Balken,
   rechts nur "Anhalten"; die anderen "Starten" sind grau.
3. Er geht in einen Dungeon: der Scan hält an, "Nächster Schritt" sagt, er solle ihn draußen fortsetzen.
4. Draußen klickt er "Fortsetzen"; am Ende "Fertig: 4901 neue Quests warten auf die Übernahme." und
   "Nächster Schritt: 4901 neue Einträge seit dem Einloggen: ausloggen oder /reload ...".
5. Nach dem nächsten Datenbau und Release räumt das Addon beim Login weg, was übernommen ist (D-34): die Zeile
   sagt "Fertig: alles übernommen.".

## Abnahmekriterien

- Wenn du Gilde > Werkzeuge öffnest, dann stehen vier Zeilen Ausrüstung, Quests, NPCs, Sammler mit ihrem Stand
  in Worten, ohne Nummern von IDs und ohne Dateinamen.
- Wenn du in der Zeile Quests "Starten" klickst, dann zeigt sie "Läuft: x %, etwa ... übrig" mit Balken und nur
  "Anhalten"; die "Starten" der anderen Zeilen sind grau, bis du anhältst.
- Wenn ein Scan fertig ist und das Addon nach dem nächsten Release beim Login weggeräumt hat, dann steht in
  seiner Zeile "Fertig: alles übernommen." statt "0 Namen gespeichert".
- Wenn du nach einem Scan noch nicht ausgeloggt hast, dann steht "Nächster Schritt: n neue Einträge seit dem
  Einloggen: ausloggen oder /reload, damit sie gespeichert werden."
- Wenn du in der Zeile Sammler "Ausschalten" klickst, dann steht dort "Aus" und in den Einstellungen
  (Werkzeuge) ist "Item-Sammler" aus.

## Sonderfälle

- Instanz: Scans halten an (wie bisher); der nächste Schritt sagt es. Kampf und Kampfsperre: die Scans warten
  (wie bisher), die Zeile zeigt weiter "Läuft".
- `/reload`: der Zähler der neuen Einträge beginnt bei 0 (gespeichert ist dann alles), "hielt in der Instanz
  an" ist vergessen; ein angehaltener Bereich und angehaltene Scans per Nummer zeigen weiter "Angehalten".
- Ein angehaltener Ausrüstungs-Scan (Liste) lässt sich nicht fortsetzen (die Liste lebt nur im Speicher):
  die Zeile bietet "Starten" an.
- Ohne Listen der Scans per Nummer: kein Prozent. Client ohne NPC-Namen: "Der Client nennt keine NPC-Namen.",
  kein Start. Client auf Englisch: alle Texte übersetzt.

## Missbrauch/Vertrauen

Nichts: keine Nachricht, kein fremder Inhalt; die Seite liest nur eigene Daten.

## Daten

Neu im gespeicherten `AmisiaDB.scan`: `done` (Zeit, zu der der letzte Lauf des Item-Scans alles gefragt hat;
`nil` nach einem Anhalten). Sonst nur im Speicher: der Zähler neuer Einträge (`ns.ScanAdded`,
`ns.ScanAddedCount`), "hielt in der Instanz an" je Scan, Liste und Art eines Listenlaufs.
Neue Abfragen: `ns.ScanProgress()`, `QS.Progress()`, `NS_.Progress()`; Widget `W.ProgressBar`, Maße
`T.PROGRESS`, `T.TOOLS`. Keine Einstellung, keine Nachricht, kein Export. Entscheidung D-118.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-13: Vorschläge 1 bis 3: "Ja, 1 bis 3".
- Annahme (nicht gefragt): kein roter Knopf im Scan-Teil; die eine wichtigste Aktion der Seite bleibt "Drops für
  die Website" in ihrer eigenen Ansicht (D-67). Grund: die vier Zeilen sind gleichrangig, ein roter "Starten"
  in einer Zeile wäre willkürlich; die Zahl roter Knöpfe der Seite sinkt von 2 auf 1.
- Annahme (nicht gefragt): "3111111" war kein Standardwert (der ist 250000), sondern das Ende eines von Hand
  getippten Bereichs (`/amisia scan 300000 3111111`); der Prozentwert bezieht sich ehrlich auf diesen Bereich
  (darum 0 % und etwa 7 h 48 min bei 100 je Sekunde). Am Bereich selbst ändert die Seite nichts.
- Annahme (nicht gefragt): "0 Namen gespeichert" war kein Fehler: Phase A und B waren fertig, der Datenbau hatte
  die Namen ins Archiv übernommen und das Addon sie beim Login weggeräumt (D-34). Die Zahl der ausgelieferten
  Namen zeigt die Zeile nicht: die Daten zählen Quests und NPCs nur zusammen.
- Annahme (nicht gefragt): ein "Fortsetzen" des Bereichs behält seinen Anfang, damit der Prozentwert nicht auf 0
  zurückfällt. Ein Quest-Scan, der gestartet und angehalten wurde, gilt als angehalten (auch bei 0 %).
- Annahme (nicht gefragt): der Zähler neuer Einträge zählt neue Itemzeilen, neue Quellen-Notizen, neue Quests
  und neue NPC-Namen; geänderte Zeilen zählen nicht. Er zählt auch, was der Sammler beim normalen Spielen
  aufnimmt, darum steht die Zeile oft da: sie ist die Erinnerung, dass erst das Ausloggen speichert.
