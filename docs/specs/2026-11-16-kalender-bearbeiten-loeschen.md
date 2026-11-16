# Spec: Termine im Kalender bearbeiten und löschen

Stand: 2026-11-16 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-222

## Ziel

Nutzer 2026-11-16, mit einem Bild des in Amisia angelegten Termins "test" (Mo 16.11. 23:45): "können wir die sachen im
Kalender auch bearbeiten und löschen". Das Anlegen (F-217) geht in Forever; Frage 3 jener Spec hatte Bearbeiten und
Löschen bis dahin zurückgestellt. Gelöst ist es, wenn man einen Termin, den man im Spiel ändern oder löschen darf, auf
der Seite Gilde > Kalender ändern und löschen kann, ohne den Spielkalender zu öffnen.

## Was es tut

**A. Wer darf was.** Amisia fragt für den gewählten Termin das Spiel (`C_Calendar.ContextMenuEventCanEdit` und
`ContextMenuEventCanRemove`, dieselben Fragen wie das Rechtsklick-Menü des Spielkalenders). Nur bei "ja" stehen unten
neben "Für Discord" die Links "Bearbeiten" und "Löschen". Das gilt für Gildenereignisse, Gildenankündigungen und eigene
Termine, gleich ob sie in Amisia oder im Spielkalender angelegt wurden. Aufrufe der Gilde (lila, F-218) sind keine
Spieltermine; sie ändert man weiter auf der Seite Aufrufe.

**B. Bearbeiten.**
- "Bearbeiten" öffnet den Termin im Spiel (`OpenEvent`, lesend) und zeigt rechts das Formular von "Termin anlegen ..."
  mit seinen Werten: Typ, Instanz, Uhrzeit, Titel, Beschreibung. Tag und Art (Gildenereignis oder Ankündigung) stehen
  als Text da und lassen sich nicht ändern (wie im Spielkalender). Der Knopf heißt "Speichern", daneben "Abbrechen".
- "Speichern" setzt im selben Klick die geänderten Felder (`EventSetTitle`, `EventSetDescription`, `EventSetTime`,
  `EventSetType`, `EventSetTextureID`) und ruft `UpdateEvent` (braucht wie `AddEvent` einen Klick). Ohne Änderung ist
  "Speichern" grau (`EventHaveSettingsChanged`).
- Antwortet das Spiel: im Chat "Termin geändert: Fr 21.11. 19:30 Molten Core", das Blatt liest neu. Die Anmeldungen
  bleiben, das Spiel behält sie.
- Fehler wie beim Anlegen: der Text des Spiels, eine Sperre für Amisia (dann bleiben "Speichern" und "Löschen" bis
  /reload aus) oder nach 10 Sekunden keine Antwort, jeweils mit "Ändere ihn bitte im Spielkalender."
- Solange das Formular offen ist, hält Amisia den Termin im Spiel offen (sonst ginge "Speichern" nicht in einem Klick).
  "Abbrechen", ein anderer Tag, eine andere Seite, das Schließen des Fensters, ein Kampf oder das Öffnen des
  Spielkalenders schließen Formular und Termin ohne Änderung.

**C. Löschen.**
- "Löschen" fragt erst: "Termin 'Molten Core' am Fr 21.11. 19:30 löschen? Er verschwindet für die ganze Gilde, alle
  Anmeldungen gehen verloren." (bei einem eigenen Termin: "für alle Eingeladenen") mit "Löschen" und "Abbrechen".
- "Löschen" im Fenster ruft im selben Klick `ContextMenuSelectEvent` und `ContextMenuEventRemove` (der Weg des
  Spielkalenders). Vorher prüft Amisia, dass an dieser Stelle noch derselbe Termin steht (seine `eventID`).
- Ist der Termin danach weg: im Chat "Termin gelöscht: Fr 21.11. 19:30 Molten Core", das Blatt liest neu. Sonst der
  Fehler wie oben mit "Lösche ihn bitte im Spielkalender."

Für beides gilt wie beim Anlegen: nie im Kampf, nie bei offenem Kalenderfenster des Spiels, nie während Amisia den
Kalender liest oder schreibt oder eine Antwort aussteht; dann sind die Links grau mit dem Grund im Tooltip.

## Was es ausdrücklich nicht tut

- Kein Verschieben auf einen anderen Tag und kein Wechsel zwischen Gildenereignis und Ankündigung (das kann auch der
  Spielkalender nicht: löschen und neu anlegen).
- Kein Kopieren, keine Einladungen, kein Entfernen einzelner Teilnehmer, kein Ändern fremder Anmeldungen, kein Sperren,
  kein Moderator: das bleibt im Spielkalender.
- Keine eigenen Rechte: wer im Spiel nicht ändern oder löschen darf, sieht die Links nicht.
- Nichts ohne Klick: kein Timer, keine Nachricht, kein zweiter Versuch. Keine Nachricht an die Gilde über die Änderung.
- Kein Papierkorb: gelöscht ist gelöscht, wie im Spiel.
- Amisia öffnet das Kalenderfenster des Spiels nicht (D-64).

## Abläufe

1. Vulo hat für Fr 21.11. 20:00 "Molten Core" angelegt. Er wählt den Tag, klickt "Bearbeiten", stellt 19:30 ein,
   ergänzt die Beschreibung und klickt "Speichern". Die Chatzeile bestätigt es, das Blatt zeigt "19:30 Molten Core".
2. Die Gilde sieht die neue Zeit im Spielkalender und in Amisia; wer angemeldet war, bleibt angemeldet.
3. Der Raid fällt aus. Vulo klickt "Löschen", liest die Frage und bestätigt. Der Termin ist für alle weg; eine
   Aufstellung, die ihn übernommen hatte, zeigt wie bisher "Ereignis nicht mehr im Kalender" und behält ihre Zeilen.
4. Kim (ohne Recht) wählt Vulos Termin: "Bearbeiten" und "Löschen" stehen bei ihr nicht da.

## Abnahmekriterien

- Wenn du unter Gilde > Kalender deinen Termin "test" wählst, "Bearbeiten" klickst, Titel und Uhrzeit änderst und
  "Speichern" klickst, dann steht im Chat "Termin geändert: ...", und Blatt und Spielkalender zeigen die neuen Werte.
- Wenn du deinen Termin wählst, "Löschen" klickst und die Frage bestätigst, dann steht im Chat "Termin gelöscht: ...",
  und der Termin fehlt auf dem Blatt und im Spielkalender.
- Wenn du bei der Frage "Abbrechen" klickst oder das Formular mit "Abbrechen" schließt, dann ist am Termin nichts
  geändert.
- Wenn ein Gildenmitglied ohne Recht deinen Termin wählt, dann sieht es weder "Bearbeiten" noch "Löschen"
  (braucht: Gilde).
- Wenn ein anderer sich angemeldet hat und du danach die Uhrzeit änderst, dann steht er weiter als angemeldet in der
  Liste (braucht: Gilde).
- Wenn das Kalenderfenster des Spiels offen ist, dann sind "Bearbeiten" und "Löschen" grau ("Erst den Spielkalender
  schließen.").

## Sonderfälle

- **Kampf:** die Links sind grau ("Nicht im Kampf."); beginnt ein Kampf bei offenem Formular, schließt es sich.
- **Vergangene Termine:** das Spiel entscheidet, ob Löschen noch geht. Bearbeiten bietet Amisia nur für Termine, die
  noch kommen; eine neue Uhrzeit, die heute schon vorbei ist, wird nicht gespeichert.
- **Termin inzwischen weg oder verschoben** (ein anderer hat ihn gelöscht, die Liste hat sich bewegt): Amisia vergleicht
  die `eventID` vor dem Öffnen und vor dem Löschen; passt sie nicht: "Ereignis nicht mehr im Kalender.", nichts wird
  gerufen.
- **Zwei ändern gleichzeitig:** die letzte Antwort des Spiels gilt; Amisia liest danach neu.
- **Termin eines anderen Monats:** die Aufrufe des Spiels zählen vom gesetzten Monat. Amisia setzt für Bearbeiten und
  Löschen den Monat des Termins und danach den vorigen zurück (wie beim Lesen eines fremden Monats, D-142).
- **Aufstellung und Anmeldung:** sie finden den Termin über seine `eventID`, also auch nach neuem Titel oder neuer
  Uhrzeit; die Nacht einer übernommenen Aufstellung bleibt die alte, bis man erneut "Übernehmen" klickt.
- **Geheime Werte (Forever):** kann Amisia den Termin nicht lesen (`ns.Plain`), öffnet sich das Formular nicht:
  "Der Kalender wird gerade gelesen." bzw. der Grund des Spiels.
- **/reload bei offenem Formular:** der Termin im Spiel ist danach zu, nichts ist geändert.
- **Englischer Client:** Texte über die Locale, Typ- und Instanznamen vom Spiel.

## Missbrauch/Vertrauen

- Die Rechte prüft allein das Spiel, vor dem Zeigen der Links und noch einmal beim Aufruf. Amisia gibt niemandem mehr
  Rechte: ein Mitglied ohne Recht kann über Amisia nichts ändern oder löschen, was es im Spielkalender nicht könnte.
- Löschen trifft andere (ihre Anmeldungen): darum immer die Rückfrage mit Titel, Tag und Uhrzeit, und nie ohne Klick.
- Keine neue Nachricht, kein Fremdtext: Titel und Beschreibung tippt der Spieler, Amisia nimmt Farbcodes, Links und
  Steuerzeichen heraus (wie beim Anlegen). Der gelesene Titel in Frage und Chatzeile ist gesäubert (`Cal.Clean`).
- Fluten: ein Aufruf je Klick, keiner, solange eine Antwort aussteht.

## Daten

- Kein neuer gespeicherter Schlüssel, keine Einstellung, keine Nachricht, keine Exportzeile, kein Website-Zustand.
- **Neue Datei** `Amisia_Raid/Raid/CalendarEdit.lua` (`ns.CalEdit`: Rechte, Öffnen zum Bearbeiten, Speichern, Löschen);
  die Seite `UI/Pages/Calendar.lua` bekommt die zwei Links und das Formular im Bearbeiten-Modus. TOC und
  `docs/ARCHITECTURE.md` im selben Commit.
- **Neue Entscheidung D-147:** Amisia ändert und löscht auf Klick Termine im Spielkalender, soweit das Spiel es dem
  Spieler erlaubt. Das ändert die "Folge" von D-142 ("Bearbeiten, Löschen ... weiter nicht in Amisia").

## Offene Fragen

1. **Wer darf?** Vorschlag: genau wer es im Spielkalender darf (der Ersteller, bei Gildenterminen auch wem das Spiel es
   über den Gildenrang erlaubt). Die Alternative: nur der Ersteller.
2. **Welche Termine?** Vorschlag: Gildenereignisse, Gildenankündigungen und eigene Termine, auch die im Spielkalender
   angelegten.
3. **Tag verschieben?** Vorschlag: nein, wie im Spiel: löschen und neu anlegen.
4. **Rückfrage vor dem Löschen?** Vorschlag: ja, immer.
5. **Die Gilde im Chat über Änderung oder Absage informieren?** Vorschlag: nein, nur die eigene Chatzeile; der
   Spielkalender zeigt den neuen Stand.
6. **Kopieren eines Termins (z. B. auf die nächste Woche)?** Vorschlag: nicht jetzt; wäre ein eigener Schritt.

## Entscheidungen

Noch keine.
