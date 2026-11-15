# Spec: Kalender in beide Richtungen (Termin in Amisia anlegen, alle Spieltermine zeigen, Discord)

Stand: 2026-11-15 · Status: freigegeben ·
Feature: F-217

## Ziel

Nutzer 2026-11-15: "können wir es auch machen das man in addon kalender einen termin erstellen kann und aus den
ingame blizzards Kalender also das beide wege gehen" und "vllt auch mit discord / bot". Auf der Seite Gilde >
Kalender legt man einen Gildentermin an, der sofort im Spielkalender steht (für die ganze Gilde, auch ohne
Amisia), und jeder Termin des Spielkalenders steht auch auf Amisias Monatsblatt. Gelöst ist es, wenn niemand mehr
den Spielkalender öffnen muss, um einen Raid anzusetzen oder zu sehen, was ansteht.

Der Weg zurück läuft über den Spielkalender selbst: was Amisia anlegt, verteilt das Spiel an alle, und Amisia
liest den Spielkalender. Es braucht dafür keine neue Addon-Nachricht.

## Was es tut

**A. Termin anlegen (Amisia → Spielkalender)**
- Unten auf der Seite Kalender der Knopf "Termin anlegen ..." (für einen Tag von heute bis zum letzten Tag, den das
  Spiel erlaubt: `C_Calendar.GetMaxCreateDate`). Er öffnet rechts statt der Teilnehmer ein Formular für den gewählten
  Tag:
  - **Art des Eintrags:** "Gildenereignis (mit Anmeldung)" (wie im Spielkalender: jedes Gildenmitglied darf das) oder
    "Gildenankündigung" (nur mit dem Recht des Spiels, `CanEditGuildEvent`).
  - **Typ:** Schlachtzug, Dungeon, PvP, Treffen, Sonstiges. Bei Schlachtzug und Dungeon eine Auswahl der Instanzen
    aus dem Spiel (`C_Calendar.EventGetTextures`). In Forever verlangt "Schlachtzug" eine Raid-Instanz (D-42).
  - **Uhrzeit:** Stunde und Minute zum Eintippen, mit Pfeilen in 15-Minuten-Schritten. Vorgabe ist die zuletzt
    benutzte Zeit, sonst 20:00.
  - **Titel:** höchstens 31 Zeichen wie im Spiel. Vorgabe ist der Name der gewählten Instanz.
  - **Beschreibung:** höchstens 255 Zeichen.
  - "Anlegen" und "Abbrechen".
- "Anlegen" ruft im selben Klick die Aufrufe des Spiels auf: `CreateGuildSignUpEvent` bzw.
  `CreateGuildAnnouncementEvent`, `EventSetTitle`, `EventSetDescription`, `EventSetType`, `EventSetTextureID`,
  `EventSetDate`, `EventSetTime` und `AddEvent`. `AddEvent` geht nur aus einem Klick (Hardware-Ereignis).
  - Kommt `CALENDAR_NEW_EVENT`: im Chat "Termin im Spielkalender angelegt: Fr 21.11. 20:00 Molten Core". Das Blatt
    liest neu, der Tag ist gewählt.
  - Kommt ein Fehler (`CALENDAR_UPDATE_ERROR`, `ADDON_ACTION_BLOCKED/FORBIDDEN` für Amisia, oder nach 10 Sekunden
    keine Antwort): rechts der Grund und "Lege ihn bitte im Spielkalender an." Bei einer Sperre des Spiels bleibt der
    Knopf bis zum /reload grau, mit dem Grund im Tooltip.
- Nach dem Anlegen kann sich jeder wie bisher über Amisia anmelden (F-090), und die Aufstellung liest den Termin
  (F-087/F-088).

**B. Alle Spieltermine auf dem Blatt (Spielkalender → Amisia)**
- Bisher zeigt das Blatt nur Gildenereignisse von heute bis 14 Tage voraus (`GetGuildEventInfo`). Neu liest es den
  gezeigten Monat aus dem Spielkalender (`GetNumDayEvents`/`GetDayEvent`):
  - Gildenereignisse, Gildenankündigungen und eigene Termine bzw. Einladungen;
  - vergangene Tage des Monats ebenfalls;
  - vorwärts bis zum letzten Tag, den das Spiel zum Anlegen erlaubt.
- Ein Tag zeigt wie bisher Uhrzeit und Titel. Gildenankündigungen (hellblau) und eigene Termine (grün) sind an der
  Farbe zu erkennen (beim Bau: ein eigenes Zeichen passt nicht in die kleine Zelle). Rechts stehen Art, Ersteller und Typ. Die Teilnehmerliste gibt es weiter nur bei
  Gildenereignissen mit Anmeldung (der bisherige Leser).
- Einen anderen Monat lädt Amisia mit `SetAbsMonth`, liest ihn nach
  `CALENDAR_UPDATE_EVENT_LIST` und stellt danach den vorher gesetzten Monat wieder ein. Das geschieht nie, solange das
  Kalenderfenster des Spiels offen ist, im Kampf oder während Amisia ein Ereignis liest oder schreibt (`Cal.Busy`).

**C. Discord**
- Bei einem gewählten Termin der Link "Für Discord": ein Kopierfeld (wie bei der Gildenbank) mit
  `**Titel**`, `<t:EPOCH:F> (<t:EPOCH:R>)`, Typ und Beschreibung sowie der Zeile "Anmelden: im Spielkalender oder in
  Amisia". Discord zeigt die Zeit jedem in seiner Zeitzone. Für einen Anmelde-Bot überträgt der Offizier Titel, Datum
  und Uhrzeit aus dieser Zeile.
- Die Anmeldungen eines Bots kommen wie bisher in die Aufstellung: dort den Text einfügen, der Leser kennt Bot-Text.

## Was es ausdrücklich nicht tut

- Kein Bearbeiten, Löschen oder Kopieren von Terminen, keine Einladungen, kein Masseneinladen, kein Sperren und kein
  Moderator: das bleibt im Spielkalender (Frage 3).
- Keine wiederkehrenden Termine, nichts für andere Spieler und nie etwas ohne Klick (kein Timer, keine Nachricht,
  kein /reload).
- Amisia öffnet das Kalenderfenster des Spiels nicht (D-64).
- Keine automatische Verbindung zu Discord oder einem Bot. Ein Addon hat kein Netz, die Website hat keine
  Geheimnisse (ein API-Schlüssel des Discord-Servers dürfte dort nicht liegen), und die Schnittstelle des Bots ist
  hier nicht geprüft. Falls das gewünscht ist, kommt es in eine eigene Spec (Frage 5).
- Keine Feiertage und Weltereignisse auf dem Blatt (Frage 4) und keine Raid-Resets (die zeigt Raid-Check, F-099).
- Anmeldung, Aufstellung und Raid-Kalender-Fenster bleiben bei "heute bis 14 Tage, nur Gildenereignisse".

## Abläufe

1. Vulo öffnet Gilde > Kalender, klickt auf Fr 21.11., dann "Termin anlegen ...". Er wählt Gildenereignis,
   Schlachtzug und Molten Core, tippt 19:30 und schreibt "Bitte Feuerresi mitbringen" dazu.
2. Er klickt "Anlegen". Amisia legt den Termin im selben Klick im Spielkalender an. Die Chatzeile bestätigt es, und das
   Blatt zeigt am 21.11. "19:30 Molten Core".
3. Alle Gildenmitglieder sehen den Termin im Spielkalender (das macht das Spiel). Wer Amisia hat, sieht ihn auch auf
   der Seite Kalender, auf der Karte "Raid-Anmeldung" und im Raid-Kalender, und meldet sich dort an (F-090).
4. Kim legt im Spielkalender eine Gildenankündigung "Gildentreffen" für den 3.12. an. Vulo blättert in Amisia zum
   Dezember: der Termin steht am 3.12. mit dem Zeichen für Ankündigung.
5. Vulo klickt beim 21.11. auf "Für Discord", kopiert den Text und postet ihn in Discord. Später fügt er die
   Anmeldeliste des Bots in die Aufstellung ein.

## Abnahmekriterien

- Wenn du unter Gilde > Kalender auf einen Tag klickst, "Termin anlegen ..." wählst, Gildenereignis, Schlachtzug,
  eine Instanz und eine Zeit einstellst und "Anlegen" klickst, dann steht der Termin danach im Spielkalender und auf
  Amisias Blatt, und im Chat steht "Termin im Spielkalender angelegt: ...".
- Wenn ein anderes Gildenmitglied den Spielkalender öffnet, dann sieht es deinen Termin und kann sich anmelden
  (braucht: Gilde).
- Wenn du im Spielkalender einen eigenen Termin oder eine Gildenankündigung in 3 Wochen anlegst, dann steht er nach
  dem Blättern auf Amisias Blatt am richtigen Tag.
- Wenn das Kalenderfenster des Spiels offen ist, dann ist "Anlegen" grau ("Erst den Spielkalender schließen."), und
  Amisia blättert keinen anderen Monat.
- Wenn du bei einem Termin "Für Discord" klickst und den Text in Discord postest, dann zeigt Discord Datum und
  Uhrzeit in deiner Zeitzone.

## Sonderfälle

- **Kampf:** Anlegen und Monatswechsel warten. Der Knopf ist grau mit "Nicht im Kampf.".
- **Kein Gildenmitglied:** nur "Eigener Termin" (`CreatePlayerEvent`)? Siehe Frage 2. Vorschlag: ohne Gilde gibt es
  keinen Knopf.
- **Testkonto:** `AddEvent` geht für Testkonten nicht (#nofreetrial). Der Fehler des Spiels kommt als Grund.
- **Datum:** ein Tag vor heute oder nach `GetMaxCreateDate` lässt sich nicht anlegen. Ein heutiger Termin mit einer
  Uhrzeit in der Vergangenheit: Amisia warnt und legt nicht an.
- **Spielkalender oder eigener Leser offen:** wenn das Kalenderfenster offen ist, eine Kalender-Prüfung läuft oder
  die Aufstellung bzw. das Raid-Kalender-Fenster gerade ein Ereignis offen hält, wird nichts angelegt. Das Anlegen
  ersetzt das offene Ereignis des Clients.
- **Doppelt klicken:** solange eine Antwort aussteht (`C_Calendar.IsActionPending`), ist "Anlegen" grau. Kein
  zweiter Versuch aus einem Timer.
- **Englischer Client:** Typnamen und Instanznamen kommen vom Spiel, die Texte über die Locale.
  `CALENDAR_FIRST_WEEKDAY` gilt wie bisher.
- **Geheime Werte (Forever, Kampf und Chat-Sperre):** `GetDayEvent` kann geheim sein. Es wird nur `ns.Plain`
  gelesen; ein geheimer Tag bleibt leer bis zum nächsten Lesen.
- **/reload während des Wartens:** dann gibt es keine Meldung. Das Blatt zeigt den Termin nach dem nächsten Lesen.
- **Monatswechsel des Spiels:** nach dem Lesen eines anderen Monats stellt Amisia immer den laufenden Monat wieder
  ein. Die übrigen Leser (Anmeldung, Aufstellung) rechnen ihren Monats-Versatz neu aus
  `GetGuildEventSelectionInfo`.

## Missbrauch/Vertrauen

- Amisia legt nur an, was der Spieler selbst in seinem Formular und mit seinem Klick will. Die Rechte prüft das Spiel
  (Gildenereignis: jedes Mitglied; Ankündigung: `CanEditGuildEvent`). Amisia gibt niemandem mehr Rechte als das Spiel.
- Keine neue Nachricht, kein eingefügter Fremdtext. Titel und Beschreibung tippt der Spieler selbst; Amisia nimmt
  Farbcodes, Links und Steuerzeichen heraus (`ns.CleanNote`).
- Gelesene Termine anderer (Titel, Ersteller) werden wie bisher mit `Cal.Clean` gesäubert und nur gezeigt.
- Fluten: ein Anlegen pro Klick und keines, solange eine Antwort aussteht. Das Spiel drosselt selbst.
- Discord-Text: Titel und Beschreibung laufen durch `ns.DiscordEscape`, damit kein `@everyone` und keine Erwähnung
  entsteht.

## Daten

- **Neuer gespeicherter Schlüssel** `AmisiaDB.calform = {kind = "signup"/"announce", type = 0..4, tex = index,
  h, m}`: das zuletzt benutzte Formular. Titel und Beschreibung werden nicht gespeichert.
  `ns.CalFormLoaded` prüft jedes Feld.
- **Keine neue Einstellung** (Frage 6). Keine neue Nachricht, keine Exportzeile, kein Website-Zustand.
- **Neue Dateien:**
  - `Amisia_Raid/Raid/CalendarCreate.lua`: `ns.CalCreate`, das Anlegen mit den Regeln oben.
  - `Raid/Calendar.lua` bekommt `Cal.Month(y, m, fn)` (alle Ereignisse eines Monats, Lesen ohne Schreiben).
  - Die Seite `UI/Pages/Calendar.lua` bekommt das Formular und "Für Discord".
- **Neue Entscheidung D-142:** Amisia legt auf Klick des Spielers Gildentermine im Spielkalender an. Das ändert die
  "Folge" von D-42 ("kein Ereignis anlegen"). Bearbeiten, Löschen und Einladen bleiben verboten.

## Offene Fragen

1. **Wer darf anlegen?** Vorschlag: wie im Spiel jedes Gildenmitglied ein Gildenereignis, eine Ankündigung nur mit dem
   Recht des Spiels. Die Alternative wäre, Amisia auf den Offiziersrang zu beschränken.
2. **Eigene Termine (nicht Gilde)?** Vorschlag: nein, nur Gildenereignis und Gildenankündigung. Die Seite ist eine
   Gildenseite.
3. **Bearbeiten und Löschen eigener Termine in Amisia?** Vorschlag: noch nicht. Erst prüfen, ob das Anlegen in Forever
   geht. Danach kann es als eigener Schritt kommen (`UpdateEvent` braucht auch einen Klick).
4. **Feiertage und Weltereignisse des Spielkalenders (Dunkelmond-Jahrmarkt und Co.) auf dem Blatt?** Vorschlag: nein,
   das Blatt bleibt bei Gilde und eigenen Terminen.
5. **Discord:** Vorschlag: nur der Kopiertext "Für Discord" (Teil C). Eine echte Verbindung zum Bot (Termin dort
   anlegen, Anmeldungen zurückholen) braucht dessen API-Schlüssel und einen Server. Das wäre eine eigene Spec, nachdem
   du in Discord geschaut hast, was der Bot anbietet (`/apikey`, Export).
6. **Schalter in den Einstellungen?** Vorschlag: keiner. Der Knopf tut nur etwas, wenn man ihn klickt.

## Entscheidungen

- 2026-11-15: Nutzer: "Passt" -> alle Vorschläge übernommen: Frage 1 jedes Gildenmitglied ein Gildenereignis, eine
  Ankündigung nur mit dem Recht des Spiels; Frage 2 keine eigenen Termine; Frage 3 kein Bearbeiten und Löschen;
  Frage 4 keine Feiertage; Frage 5 nur der Kopiertext für Discord; Frage 6 kein Schalter.
