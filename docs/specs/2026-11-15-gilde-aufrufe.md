# Spec: Aufrufe der Gilde (Gruppe suchen mit Anmeldung)

Stand: 2026-11-15 · Status: freigegeben ·
Feature: F-211

## Ziel

Ein Gildenmitglied sucht schnell Leute für einen Dungeon, eine Gruppenquest oder Hilfe. Es stellt in Amisia einen
Aufruf ein, alle Gildenmitglieder mit Amisia sehen genau, worum es geht und wer noch fehlt, melden sich mit einem
Klick an, und der Ersteller lädt die Angemeldeten mit einem Klick ein. Gelöst ist es, wenn eine Gruppe ohne
Gildenchat-Hin-und-Her zustande kommt.

## Was es tut

- **Seite "Aufrufe"** im Reiter Gilde (Raid-Modul, alle Clients), nach Mitglieder:
  - oben "Aufruf erstellen" (bzw. "Mein Aufruf", solange einer läuft), die Filter Alle / Dungeon / Quest / Hilfe /
    Sonstiges;
  - je Aufruf eine Karte: Art, Titel, Ersteller (Klassenfarbe), Stufe ab, wann ("jetzt" oder "ab 20:30"), Notiz,
    die Rollen "Tank 1/1 · Heiler 0/1 · Schaden 2/3", wie lange er noch gilt; Knöpfe "Anmelden" (mit Rolle) bzw.
    "Abmelden".
- **Erstellen:** ein kleines Formular auf der Seite: Art (Dungeon, Quest, Hilfe, Sonstiges); bei Dungeon eine
  Auswahl der Dungeons aus Amisias Daten (mit Ausrüstungsmodul; füllt Titel und Stufe), sonst freier Titel
  (40 Zeichen); Stufe ab; gesuchte Rollen Tank/Heiler/Schaden (zusammen 2 bis 40); "jetzt" oder eine Uhrzeit heute;
  Notiz (80 Zeichen). Höchstens ein eigener Aufruf zur Zeit.
- **Ersteller-Ansicht** seines Aufrufs: die Anmeldungen mit Name, Klasse, Stufe, Rolle, Itemlevel (soweit bekannt);
  je Zeile "Einladen" und "Ablehnen"; "Alle einladen" (so viele, wie die Rollen brauchen, in Anmeldereihenfolge);
  "Beenden". Wer in der Gruppe ist, zählt als "dabei"; ist der Aufruf voll, steht er bei allen auf "voll".
- **Chatzeile:** kommt ein neuer Aufruf, steht im Chat (eigenes Amisia-Präfix) "Vulo sucht: Kloster - Kathedrale
  (ab 35), Heiler, 2 Schaden [Anmelden]". Ein Klick auf [Anmelden] öffnet die Seite bei diesem Aufruf. Schalter
  `guildCalls.chat` (an).
- **Ende:** ein Aufruf endet mit "Beenden", wenn der Ersteller ausloggt (kein Lebenszeichen mehr) oder 2 Stunden
  nach seiner Zeit.

## Was es ausdrücklich nicht tut

- Kein Eintrag im Gildenchat für Spieler ohne Amisia (nicht gewählt).
- Kein automatisches Einladen; der Ersteller wählt (gewählt).
- Keine Aufrufe über die Gilde hinaus, kein Kalender-Eintrag, keine wiederkehrenden Termine (dafür ist der Kalender
  da).
- Keine Punkte, keine Vergaben, nichts Gespeichertes über das Sitzungsende hinaus außer dem eigenen Aufruf.

## Abläufe

1. Vulo öffnet Gilde > Aufrufe > "Aufruf erstellen", wählt Dungeon "Kloster - Kathedrale", 1 Tank, 1 Heiler,
   3 Schaden, "jetzt", Notiz "Quest Herod". Amisia schickt den Aufruf an die Gilde.
2. Alle Gildenmitglieder mit Amisia sehen die Chatzeile und die Karte auf der Seite.
3. Kim klickt "Anmelden" > Heiler. Kims Amisia flüstert Vulos Amisia die Anmeldung. Vulos Seite zeigt Kim unter den
   Anmeldungen; der Aufruf geht mit "Heiler 0/1, 1 angemeldet" neu an die Gilde.
4. Vulo klickt "Alle einladen": Amisia lädt Kim und die anderen Angemeldeten ein (Gruppe, ab 6 ein Schlachtzug).
   Wer in der Gruppe ist, zählt als dabei. Voll: der Aufruf steht auf "voll", die Chatzeile kommt nicht noch einmal.
5. Wer sich nach dem Aufruf einloggt, fragt die Gilde einmal nach laufenden Aufrufen; jeder Ersteller antwortet nur
   mit seinem eigenen.
6. Vulo klickt "Beenden" oder loggt aus: der Aufruf verschwindet bei allen (spätestens 10 Minuten ohne Lebenszeichen).

## Abnahmekriterien

- Wenn du unter Gilde > Aufrufe einen Aufruf für einen Dungeon mit 1 Tank, 1 Heiler, 3 Schaden erstellst, dann sehen
  Gildenmitglieder mit Amisia ihn auf ihrer Seite und als Chatzeile mit [Anmelden] (braucht: Gilde).
- Wenn sich ein Gildenmitglied als Heiler anmeldet, dann steht es bei dir unter den Anmeldungen und bei allen steht
  "Heiler 1/1" bzw. "angemeldet" (braucht: Gilde).
- Wenn du "Alle einladen" klickst, dann lädt Amisia die Angemeldeten ein; mehr als 5: die Gruppe wird ein
  Schlachtzug (braucht: Gilde).
- Wenn du "Beenden" klickst oder ausloggst, dann ist der Aufruf bei allen weg (beim Ausloggen nach spätestens
  10 Minuten) (braucht: Gilde).
- Wenn du dich einloggst, während ein Aufruf läuft, dann steht er nach kurzer Zeit auf deiner Seite (braucht: Gilde).

## Sonderfälle

- Kampfsperre und Bosskampf: in der Sperre wird nichts gesendet; Anmelden und Erstellen warten mit einer Zeile, bis
  sie vorbei ist. Einladen nie im Kampf (Grund am Knopf).
- Der Ersteller ist in einer Gruppe, aber nicht Leiter: "Einladen" ist aus mit Grund.
- `/reload` des Erstellers: der eigene Aufruf und seine Anmeldungen bleiben (gespeichert) und gehen neu an die Gilde.
- Ein Angemeldeter loggt aus: er bleibt in der Liste, grau "offline"; Einladen geht dann nicht.
- Zwei Charaktere desselben Spielers: jeder meldet sich für sich an.
- Uhrzeit: die Zeit des Servers (`GetServerTime`); "ab 20:30" heißt heute, eine Zeit vor jetzt heißt morgen.
- Englischer Client: Dungeon-Namen aus Amisias Daten in der Sprache des Empfängers (der Aufruf trägt den Schlüssel).
- Titel und Notiz: freie Eingabe; Farbcodes und Links werden entfernt.

## Missbrauch/Vertrauen

- Es zählt nur der Absender, den der Server setzt; nur Mitglieder der eigenen Gilde (`ns.TrustWait` "member").
- Einen Aufruf ändert oder beendet nur sein Ersteller (die Nachricht kommt von ihm). Eine Anmeldung gilt nur für den
  Absender selbst; abmelden kann sich nur er.
- Fluten: höchstens ein Aufruf je Ersteller; neue Fassung des Aufrufs höchstens alle 10 s, Lebenszeichen alle
  5 Minuten; Anmelden/Abmelden je Absender und Aufruf höchstens alle 5 s; höchstens 30 Anmeldungen je Aufruf,
  höchstens 20 fremde Aufrufe gemerkt.
- Felder Stück für Stück geprüft (Längen, Zahlenbereiche, Rollen); ein falsches Feld verwirft die Nachricht.
- Die Chatzeile kommt je Aufruf einmal, nicht bei jeder neuen Fassung.

## Daten

- Neue Nachrichten (Präfix Steuerung):
  - `EA` Ersteller -> GUILD: neuer Aufruf und jede Änderung (Abstand 10 s), Lebenszeichen alle 5 Minuten; WHISPER
    als Antwort auf `EQ`. Felder: Aufruf-Id (4 hex), Fassung, Art (`D`/`Q`/`H`/`S`), Dungeon-Schlüssel oder `-`,
    Titel, Stufe ab, Zeit (Server-Epoch oder `0` = jetzt), gesucht T/H/S, angemeldet T/H/S, dabei T/H/S, Zustand
    (`O` offen, `F` voll), Notiz.
  - `EJ` Mitglied -> WHISPER an den Ersteller: Anmeldung (Aufruf-Id, Rolle `T`/`H`/`S`, Stufe) oder Abmeldung
    (Aufruf-Id, `-`). Abstand 5 s.
  - `EX` Ersteller -> GUILD: Aufruf beendet (Aufruf-Id).
  - `EQ` Mitglied -> GUILD einmal nach dem Login: nach laufenden Aufrufen fragen (Abstand 300 s); Ersteller antworten
    nach 0 bis 5 s per WHISPER mit `EA`.
- Neuer Schlüssel `AmisiaDB.guildCall`: der eigene laufende Aufruf mit seinen Anmeldungen (eins; beim Laden
  verworfen, wenn älter als 2 Stunden nach seiner Zeit).
- Einstellung `guildCalls.chat` (Chatzeile, an) im bestehenden Abschnitt der Gilde bzw. einem neuen Abschnitt
  "Aufrufe".
- Neue Seite `calls` im Reiter Gilde, neue Dateien für Logik und Seite (TOC des Raid-Moduls).
- DECISIONS: neue Entscheidung zu Ablauf, Vertrauen und Drosseln.

## Offene Fragen

Nichts. Die drei Fragen sind entschieden (unten).

## Entscheidungen

- 2026-11-15: Erstellen: "Jedes Mitglied (Recommended)" -> jedes Mitglied mit Amisia, ein Aufruf zur Zeit.
- 2026-11-15: Hinweis: "Chatzeile mit Link (Recommended)" -> eine Chatzeile mit [Anmelden], kein Fenster, kein
  Gildenchat.
- 2026-11-15: Anmeldung: "Ersteller wählt (Recommended)" -> Liste mit Rolle, Einladen einzeln oder "Alle einladen".
- 2026-11-15: Spec: "Passt" -> freigegeben.
