# Spec: Berufslehrer lesen (echte Lernstufen und Lehrer jedes Rezepts)

Stand: 2026-11-08 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-154

## Ziel

Die Berufsdaten sollen so genau wie möglich sein. Zwei Lücken lassen sich aus keiner erlaubten Quelle
schließen (Client-Tabellen, AllTheThings, Scan; D-03): die **Lernstufe der Lehrer-Rezepte** (die
Tabellen haben sie nicht; Amisia schätzt sie heute aus Gelb und der Lehrerstufe, z. B. "Zinn verhütten
ab 1") und **84 Rezepte ohne Quelle** (Verhütten, alle Gifte, zehn Kochrezepte, neue Forever-Rezepte).
Beides steht im Lehrerfenster des Spiels. Gelöst ist es, wenn nach dem Besuch der Lehrer jede
Lehrer-Lernstufe stimmt und kein Lehrer-Rezept mehr "Quelle unbekannt" zeigt.

## Was es tut

- Öffnet der Spieler einen Lehrer (Beruf oder Klasse), liest Amisia still jedes Angebot, das zu einem
  Rezept der Berufsdaten gehört: die nötige Fertigkeit, den Preis, die Mindeststufe, den Lehrer (NPC).
- Die Seite Berufe nutzt das sofort: in "Details" steht "lernbar ab 65 (vom Lehrer)" statt der
  Schätzung, "Gelernt bei" nennt den Lehrer mit Wegpunkt, die Route nimmt die echten Lernkosten.
- Geschätzte Lernstufen tragen ein "?" ("lernbar ab 50?"); der Kopf sagt "12 Lernstufen geschätzt (?) –
  beim Lehrer einmal öffnen", wie im Vorbild.
- `build.py data` übernimmt die gelesenen Angebote aus den SavedVariables in `tools/trainer_archive.json`
  (für immer, wie Scan und Eingänge) und von dort in `Data/ProfessionData.lua`; damit hat jeder Spieler
  die Werte nach dem nächsten Release.
- `/amisia lehrer` meldet, wie viele Lehrer und Angebote gelesen sind.

## Was es ausdrücklich nicht tut

- Nichts lernen oder kaufen (geschützte Aktionen) und nichts an Gilde oder Gruppe senden.
- Keine Lehrer-Rezepte "erfinden": ein Angebot ohne Rezept in den Daten wird nur gezählt (Bericht beim Bauen).
- Keine Daten aus dem Netz (D-03).

## Abläufe

1. Spieler spricht einen Berufslehrer an; das Lehrerfenster öffnet sich.
2. Amisia stellt die Filter des Fensters kurz auf "alle" (verfügbar, nicht verfügbar, gelernt), liest
   die Angebote und stellt die Filter sofort zurück; das Fenster sieht danach aus wie vorher.
3. Die Seite Berufe zeigt die echten Werte; nach `build.py data` und Release stehen sie in den Daten.

## Abnahmekriterien

- Wenn du einen Bergbaulehrer ansprichst und danach die Seite Berufe, Bergbau, "Zinn verhütten" öffnest,
  dann steht in Details "lernbar ab <Wert des Lehrers> (vom Lehrer)" und "Gelernt bei" nennt den Lehrer mit Wegpunkt.
- Wenn du einen Rezept-Eintrag mit geschätzter Lernstufe öffnest, dann steht hinter der Zahl ein "?", und der Kopf nennt die Zahl der geschätzten.
- Wenn du einen Lehrer mit eingestellten Filtern ansprichst, dann sind die Filter danach wie vorher.
- Wenn du `/amisia lehrer` eingibst, dann meldet der Chat "N Lehrer, M Angebote gelesen".

## Sonderfälle

Lehrer im Kampf geöffnet (nichts lesen, nach dem Kampf nicht nachholen); Klassenlehrer (nur Angebote,
die Rezepte eines Berufs sind, z. B. Gifte beim Schurkenlehrer); englischer Client (Zuordnung über die
Item-ID des Angebots, sonst den Zaubernamen des Clients, beides sprachunabhängig bzw. in derselben
Sprache); Angebote ohne Item (Verzauberungen): über den Namen; zwei Rezepte mit gleichem Namen: nicht
zuordnen; Lehrer der anderen Fraktion: nie gesehen, bleibt geschätzt; Werte ändern sich mit einem Patch:
der neueste Besuch gewinnt.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen; nur eigene Beobachtungen. Größe gedeckelt (höchstens 300 Lehrer,
je 400 Angebote); `ns.TrainersLoaded` prüft Feld für Feld (Zahlen, Längen).

## Daten

- Neuer Schlüssel `AmisiaDB.trainers = { [npc] = { day, skill, s = { [spell] = "rank:copper:level" } } }`,
  nach dem Übernehmen von `build.py data` (Markierung in `Data/ScanDone.lua` wie D-34) gekürzt.
- Neues Archiv `tools/trainer_archive.json` (committen und pushen: die einzige Kopie).
- `ProfessionData.lua`: die Lernstufe `learn` aus dem Lehrer; neuer Quell-Token `N<npc>` (Lehrer),
  `L` (Lernkosten) aus den gelesenen Preisen; ein Zeichen für "geschätzt" je Rezept.
- ARCHITECTURE (Schlüssel, Datei, Archiv) und DECISIONS (neue D-Nummer) im selben Commit.

## Offene Fragen

1. Lehrerfilter beim Lesen kurz auf "alle" und zurück? Vorschlag: ja (sonst fehlen die nicht
   verfügbaren Angebote, und gerade die braucht man).
2. Auch Klassenlehrer lesen (Gifte beim Schurkenlehrer)? Vorschlag: ja, nur Berufs-Rezepte.
3. Das "?" für geschätzte Lernstufen schon vor dem ersten Lehrerbesuch zeigen? Vorschlag: ja.

## Entscheidungen

Noch keine.
