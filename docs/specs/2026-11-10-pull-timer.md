# Spec: Pull- und Pausen-Timer

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10 auf die Liste der neun Punkte: "1,2,3,5,8,9") ·
Feature: F-164

## Ziel

Der Raidleiter zählt den Pull herunter und sagt Pausen an, ohne ein zweites Addon: die Gruppe sieht die
Zahlen des Spiels und eine Zeile im Chat, Amisia zeigt den laufenden Timer. Gelöst ist es, wenn ein Pull
mit `/amisia pull` oder zwei Klicks im Menü startet.

## Was es tut

- `/amisia pull [Sekunden]` (3 bis 60, Standard 10; `stop` oder 0 bricht ab), en `pull`.
- `/amisia raidpause [Minuten]` (1 bis 30, Standard 5; `stop` bricht ab), en `break`; `/amisia pause 5` (mit
  Zahl) ebenso, `/amisia pause` allein pausiert weiter die Aufnahme.
- Gruppe: hat das Spiel `C_PartyInfo.DoCountdown`, die großen Zahlen für alle und eine Zeile "Pull in 10
  Sekunden" (Schlachtzugswarnung, sonst Raid- oder Gruppenchat); ohne diese Funktion zusätzlich "5", "4",
  "3", "2", "1", "Pull!". Pause: "Pause: 5 Minuten (bis 20:35)", "Pause: noch 1 Minute", "Pause vorbei".
  Abbrechen: "Pull abgebrochen!" / "Pause abgebrochen".
- Amisia: die Statuszeile unten links zeigt "Pull in 7 s" bzw. "Pause: noch 4:50"; ihr Menü hat
  "Pull-Timer (10 s)" und "Pause (5 min)", während einer läuft "Pull-Timer abbrechen" / "Pause abbrechen".
- Einstellungen: Abschnitt "Pull- und Pausen-Timer" (Reiter Raid): Sekunden und Minuten.
- `/amisia selbsttest gruppe` meldet, ob das Spiel `C_PartyInfo.DoCountdown` hat.

## Was es ausdrücklich nicht tut

- Keine eigene Leiste oder großen Zahlen von Amisia (das Spiel hat seine), keine Addon-Nachricht an andere
  Amisia-Clients, keine Sprachausgabe.
- Kein Timer im Bosskampf (Chatsperre), keine Wiederholung nach `/reload`.

## Abläufe

- **Pull:** Leiter tippt `/amisia pull` oder wählt im Menü der Statuszeile "Pull-Timer (10 s)". Alle sehen die
  Zahlen des Spiels und die Zeile; bei Amisia zählt die Statuszeile herunter. Beginnt der Kampf früher, endet
  der Timer bei ihm.
- **Pause:** `/amisia raidpause 10` oder Menü "Pause (5 min)": Ansage mit Ende, eine Minute vorher und am Ende.
- **Allein:** dasselbe nur im eigenen Chat und in der Statuszeile.

## Abnahmekriterien

- Wenn du allein `/amisia pull` tippst, dann steht "Pull in 10 Sekunden (nur bei dir ...)" im Chat, die
  Statuszeile zählt herunter, nach 10 Sekunden "Pull!".
- Wenn du als Leiter einer Gruppe `/amisia pull 15` tippst, dann sehen alle die Zahlen des Spiels (falls es sie
  hat) und "Pull in 15 Sekunden" im Chat (braucht: Gruppe).
- Wenn du als Leiter im Menü der Statuszeile "Pause (5 min)" wählst, dann stehen die drei Pausenzeilen zu ihrer
  Zeit im Chat, und der Menüeintrag heißt solange "Pause abbrechen" (braucht: Gruppe).
- Wenn du als Raider ohne Assistent `/amisia pull` tippst, dann steht "Nur als Leiter oder Assistent" und
  nichts geht an die Gruppe (braucht: Raid).
- Wenn du im Kampf `/amisia pull` tippst, dann steht "Nicht im Kampf".

## Sonderfälle

- Bosskampf: in der Chatsperre startet nichts ("Der Chat ist im Bosskampf gesperrt."); kommt die Sperre
  während eines Timers, endet er mit einer eigenen Zeile. Eine Zeile, die das Spiel nicht annimmt, ebenso.
- Kampf beginnt während des Pull-Timers: der Timer endet (der Pull ist passiert).
- Ein neuer Timer ersetzt den laufenden; eine Pause beendet einen laufenden Pull (Countdown des Spiels mit 0).
- Eine Pause von 1 Minute sagt kein "noch 1 Minute".
- Englischer Client: Zeilen und Befehle auf Englisch (`/amisia break`).
- `/reload`: der Timer ist bei Amisia weg, der Countdown des Spiels läuft weiter.

## Missbrauch/Vertrauen

- Nur Leiter oder Assistent (Raid) bzw. Leiter (Gruppe) sagen etwas an; der Chat geht durch `ns.Say` (Drossel,
  Warteschlange, Lebensdauer der Zeilen). Kein Empfang von anderen, keine Nachricht.

## Daten

- Einstellungen: Abschnitt `pull` mit `pull.seconds` (3-60, 10) und `pull.minutes` (1-30, 5).
- Kein `AmisiaDB`-Schlüssel, keine Nachricht, kein Export. Ereignis `PULLTIMER` (intern, Statuszeile).
- Client: `C_PartyInfo.DoCountdown` (nachgeschlagen, in `GT.FUNCTIONS` der Gruppenprüfung).

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-10: Nutzer auf die Liste der neun Punkte: "1,2,3,5,8,9" -> Punkt 3 wie oben. D-94.
- Annahme (nicht gefragt): der Pausenbefehl heißt `/amisia raidpause` (en `break`), weil `/amisia pause` schon die
  Aufnahme pausiert; `/amisia pause <Minuten>` geht trotzdem.
- Annahme (nicht gefragt): eine Pause darf auch im Kampf starten, nur der Pull nicht.
- Annahme (nicht gefragt): die Menüeinträge stehen für alle im Menü der Statuszeile, ohne Führung grau mit dem Grund.
