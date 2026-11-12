# Spec: Leistung messen (`/amisia leistung`)

Stand: 2026-11-12 · Status: freigegeben (Nutzer 2026-11-12: "Ja, einbauen", auf den Vorschlag, dass Amisia
seine eigene Rechenzeit im Spiel misst und das Ergebnis für die Auswertung auf dem N100 speichert) ·
Feature: F-184

## Ziel

Der Nutzer bat um "Performance-Updates". Niemand hat je gemessen, wo Amisias Rechenzeit im echten Spiel
hingeht (25 OnUpdate-Skripte, ein Dutzend Tooltip-Erweiterungen, fast 30 Ticker, der Ereignisbus). Gelöst ist
es, wenn eine Messung im Spiel die teuersten Stellen mit Namen nennt und dasselbe Ergebnis nach dem Ausloggen
in den SavedVariables auf dem N100 lesbar ist (`python3 tools/build.py perf`). Optimiert wird hier nichts.

## Was es tut

- `/amisia leistung` (en `performance`): ohne Wort startet eine Messung, der zweite Aufruf beendet sie und
  zeigt den Bericht im Chat. `an`/`aus` (en `on`/`off`) starten und beenden ausdrücklich, `bericht` (en
  `report`) zeigt das letzte Ergebnis noch einmal, eine Zahl misst so viele Minuten und hört dann selbst auf.
  Jede Messung endet spätestens nach 60 Minuten und beim Ausloggen oder `/reload` (das Ergebnis wird vorher
  gespeichert). `login` misst die nächste Anmeldung oder das nächste `/reload` ab `ADDON_LOADED` 60 Sekunden lang.
- Beim Start eine ruhige Zeile im Chat, dazwischen keine.
- Gemessen wird mit `debugprofilestop` (sonst `GetTimePreciseSec`; ohne beide sagt der Befehl, dass Messen
  hier nicht geht): jeder Handler des Ereignisbusses (`ns.OnEvent`) und der internen Nachrichten (`ns.Fire`),
  benannt nach Ereignis und Datei:Zeile der Anmeldung; jedes OnUpdate-Skript, jeder Tooltip-Teil, jeder
  `hooksecurefunc`-Rückruf, jeder Ticker, die Selbst-Wiederholer mit `C_Timer.After`, das Neuzeichnen der
  Seite (je Seite) und der Bau der Daten (D-28), jeweils mit festem Namen.
- Bericht: Dauer, Frames und Bild pro Sekunde, Sekunden im Kampf, Amisias Zeit je Sekunde und je Frame (in
  Prozent von 16,7 ms, einem Frame bei 60 fps), Speicher am Anfang und Ende, Müll von Amisia je Sekunde, die
  Ladezeit der Dateien und der Login-Schritte, die gebauten Daten, dann die zehn teuersten Stellen (Aufrufe,
  ms gesamt, ms je Aufruf, längster Aufruf, Aufrufe über 5 ms).
- Immer (ohne Messung, billig): die Ladezeit der Dateien und die Zeit der Bus-Handler bis zum ersten
  `PLAYER_ENTERING_WORLD`.
- `/amisia selbsttest` sagt in einer Zeile, ob der Client die Uhren hat.

## Was es ausdrücklich nicht tut

- Nichts wird schneller gemacht; keine Reihenfolge, kein Zeitpunkt ändert sich.
- Nichts Sicheres oder Geschütztes wird umwickelt (der sichere Knopf des Quest-Start-Fensters).
- Echte Einmal-Timer, die Zeichenzeit des Clients für Amisias Frames und die Ladezeit anderer Addons misst es
  nicht. Keine Spieler- oder Charakternamen in den Ergebnissen.
- Keine Nachricht an andere Spieler, nichts im Chat-Kanal.

## Abläufe

1. Der Spieler tippt `/amisia leistung`, spielt ein paar Minuten, tippt es wieder: der Bericht steht im Chat.
2. Er loggt aus; Syncthing bringt die SavedVariables auf den N100; `python3 tools/build.py perf` zeigt die
   gespeicherten Läufe als Tabelle.
3. `/amisia leistung login`, dann `/reload`: nach 60 Sekunden steht der Bericht des Logins im Chat.

## Abnahmekriterien

- Wenn du `/amisia leistung` tippst, ein paar Minuten spielst und es wieder tippst, dann steht im Chat der
  Bericht mit Dauer, Frames, Amisias ms je Sekunde, Speicher, Laden und zehn Zeilen der teuersten Stellen.
- Wenn du danach `/amisia leistung bericht` tippst, dann kommt derselbe Bericht noch einmal.
- Wenn du `/amisia leistung login` tippst und `/reload` machst, dann steht nach etwa einer Minute der Bericht
  des Logins im Chat.
- Wenn du `/amisia leistung 2` tippst, dann endet die Messung nach zwei Minuten von selbst mit dem Bericht.
- Wenn du `/amisia selbsttest` öffnest, dann sagt die Zeile "Zeitmessung", welche Uhr der Client hat.

## Sonderfälle

- Kampf und Kampfsperre: Messen geht weiter, kein Chat außer Start und Bericht; geschützte Aufrufe bleiben unberührt.
- Ein anderes Addon setzt mit `debugprofilestart` die Uhr zurück: ein negativer Abschnitt zählt 0.
- Ein Fehler in einem umwickelten Aufruf geht unverändert weiter; seine Zeit fehlt dann. Der Zähler der
  verschachtelten Zeit wird je Frame zurückgesetzt.
- `/reload` und Ausloggen während einer Messung: das Ergebnis wird mit "Logout" gespeichert.
- Client auf Englisch: alle Texte übersetzt; TBC und Era: auch dort (Raid-Teil).

## Missbrauch/Vertrauen

Nichts: keine Nachricht, kein fremder Inhalt. Die gespeicherten Namen sind feste Wörter und Dateistellen.

## Daten

Neuer Schlüssel `AmisiaDB.perf = { v = 1, arm = true|nil, runs = { ... } }`: die 5 neuesten Läufe, je
höchstens 60 Zeilen (im schlimmsten Fall etwa 85 KB in der SavedVariables-Datei). Keine Einstellung, keine Nachricht, kein Export.
Ein Lauf: Zeitpunkt (Serverzeit), Addon-Version, Client-Build, Spiel, Art, Grund des Endes, Dauer, Frames,
Kampfsekunden, wo (Instanz-Art), Summen, Speicher, Laden, gebaute Daten, die Zeilen.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-12: "Ja, einbauen" -> Messung im Spiel, Ergebnis in `AmisiaDB.perf`, Leser `build.py perf`.
- Annahme (nicht gefragt): die Zahlen einer Zeile sind ihre eigene Zeit ohne die Zeit der darin
  gemessenen Stellen; so ergeben die Zeilen zusammen Amisias Zeit ohne Doppelzählung.
- Annahme (nicht gefragt): eine Spitze ist ein Aufruf mit mehr als 5 ms eigener Zeit.
