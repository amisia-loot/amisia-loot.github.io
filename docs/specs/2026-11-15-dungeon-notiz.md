# Spec: Eigene Notiz je Dungeon

Stand: 2026-11-15 · Status: freigegeben ·
Feature: F-212

## Ziel

Der Spieler hält zu jedem Dungeon (und Raid) fest, was er sich merken will: Taktik, Weg, was er dort noch braucht.
Gelöst ist es, wenn die Notiz beim Betreten des Dungeons ohne Suchen vor ihm steht.

## Was es tut

- **Reiter "Notiz"** auf der Detailseite eines Dungeons bzw. Raids (Seiten Dungeons und Raids), neben Bosse,
  Wunschliste, Karte, Zugang, Zeiten. Darin ein mehrzeiliges Eingabefeld für die Notiz des Dungeons (bis 1000 Zeichen)
  und darunter je Boss eine einzeilige Notiz (bis 120 Zeichen) mit Porträt und Name. Gespeichert wird beim Verlassen
  eines Feldes und beim Schließen des Fensters; ein Knopf "Leeren" löscht die Notiz des Dungeons nach Rückfrage.
- **Shift + Klick** auf ein Item (Taschen, Beute, Chat) fügt seinen Link in das Feld mit dem Cursor ein.
- **Kennzeichen:** ein Dungeon mit Notiz trägt in der Tabelle der Startseite ein kleines Notizzeichen; der Tooltip zeigt
  die ersten Zeilen. Der Reiter heißt dann "Notiz •".
- **Dungeon-Leiste:** steht der Spieler in einem Dungeon mit Notiz, hat die Leiste ein Segment "Notiz"; ein Klick zeigt
  darunter die Notiz und die Boss-Notizen (wie die Liste der Bosse), ein zweiter Klick oder Escape schließt sie.
  Ein Rechtsklick auf "Notiz" öffnet den Reiter Notiz der Seite.
- **Beim Betreten:** einmal je Betreten eine Chatzeile "Notiz zu <Dungeon>: <erste Zeile>" mit dem Link [Notiz].
  Abschaltbar unter Einstellungen > Dungeon-Leiste ("Notiz beim Betreten im Chat").
- **Boss-Notiz in der Bossliste:** in der Bossliste der Leiste steht die Boss-Notiz grau unter dem Namen des Bosses.

## Was es ausdrücklich nicht tut

- Nichts wird gesendet: keine Weitergabe an Gruppe, Gilde oder Website (eine eigene Spec, falls gewünscht).
- Keine Notizen je Charakter: eine Notiz gilt für den ganzen Account.
- Keine Vorlagen oder fertigen Taktiken von Amisia: nur, was der Spieler selbst schreibt.
- Keine Formatierung (fett, Farbe); nur Text und Item-Links.

## Abläufe

1. Der Spieler öffnet Dungeons > Die Todesminen > Notiz, schreibt "Erst links die Goblins, Rhahk'Zor allein ziehen"
   und bei Edwin VanCleef "Adds zuerst". Er klickt woanders hin: gespeichert.
2. In der Tabelle der Startseite steht bei den Todesminen das Notizzeichen; der Tooltip zeigt den Anfang.
3. Er betritt die Todesminen: im Chat "Notiz zu Die Todesminen: Erst links die Goblins, ..." [Notiz]; die Leiste hat
   "Notiz". Ein Klick darauf zeigt die ganze Notiz und "Edwin VanCleef: Adds zuerst".
4. Ein Klick auf [Notiz] im Chat oder ein Rechtsklick auf das Segment öffnet den Reiter Notiz, wo er weiterschreibt.

## Abnahmekriterien

- Wenn du auf der Detailseite eines Dungeons im Reiter "Notiz" etwas schreibst, woanders hinklickst und `/reload`
  machst, dann steht die Notiz noch da, auch auf einem anderen Charakter des Accounts.
- Wenn ein Dungeon eine Notiz hat, dann zeigt die Tabelle der Startseite bei ihm das Notizzeichen, und der Tooltip
  zeigt ihren Anfang.
- Wenn du einen Dungeon mit Notiz betrittst, dann steht einmal eine Chatzeile mit ihrer ersten Zeile und [Notiz], und
  die Dungeon-Leiste hat "Notiz"; ein Klick darauf zeigt die Notiz und die Boss-Notizen.
- Wenn du eine Boss-Notiz geschrieben hast, dann steht sie in der Bossliste der Leiste grau unter dem Boss.
- Wenn du unter Einstellungen > Dungeon-Leiste "Notiz beim Betreten im Chat" ausschaltest, dann kommt beim Betreten
  keine Chatzeile mehr; das Segment bleibt.

## Sonderfälle

- Bosskampf/Kampfsperre: Schreiben und Anzeigen gehen; nichts davon ist geschützt. Die Chatzeile ist eine eigene
  Ausgabe (`ns.msg`), kein gesendeter Chat.
- Mehrere Dungeons in einer Karte (Scharlachrotes Kloster, D-106): die Notiz gehört zum Dungeon, den `ns.Runs.Here()`
  nennt; wechselt das, wechselt das Segment (die Chatzeile nicht noch einmal).
- Dungeon-Leiste aus (rotes x) oder in Raids ohne "Auch in Raids": kein Segment; die Chatzeile kommt trotzdem, wenn sie
  an ist.
- Bosse anderen Addons überlassen (F-205): das Segment "Notiz" bleibt; die Boss-Notizen stehen dann nur in der Liste
  von "Notiz".
- Ein Boss, den ein neuer Build umbenennt oder neu ordnet: die Boss-Notiz hängt an der Begegnungsnummer, nicht am
  Platz in der Liste; ohne Begegnungsnummer an der NPC-Nummer.
- Englischer Client: Notizen sind freier Text und bleiben, wie sie geschrieben sind.
- Leere Notiz: kein Zeichen, kein Segment, keine Chatzeile; eine geleerte Notiz wird gelöscht.
- `/reload` im Dungeon: keine zweite Chatzeile für dasselbe Betreten (`R.entry`).

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen; nur der Spieler selbst schreibt. Gegen kaputte Anzeige: Farbcodes, Texturen und
alles außer Item-Links wird beim Speichern entfernt; Längen gedeckelt (1000 je Dungeon, 120 je Boss, höchstens
300 Dungeons mit Notiz).

## Daten

- Neuer Schlüssel `AmisiaDB.dungeonNotes`: `{v = 1, list = {[dkey] = {text, at, boss = {[encId] = text}}}}`
  (account-weit, `dkey` wie `ns.Runs`/`ns.Dungeons`).
- Neue Einstellung `dbar.noteChat` (an) im Abschnitt Dungeon-Leiste; neues Segment "note" in `DBar.SEGMENTS`.
- Chatlink `addon:Amisia:note:<dkey>` öffnet den Reiter.
- Keine Nachricht, keine Exportzeile, kein Website-Zustand. ARCHITECTURE (Schlüssel, Datei, Link) und eine kurze
  Entscheidung in DECISIONS im selben Commit.

## Offene Fragen

Nichts. Die drei Fragen sind entschieden (unten).

## Entscheidungen

- 2026-11-15: Art der Notiz: "Eigene Notiz je Dungeon" -> nur für den Spieler, account-weit, nichts gesendet.
- 2026-11-15: Boss-Notizen, Chatzeile beim Betreten (abschaltbar, an), auch Raids: "Passt, bauen" -> alle drei ja.
- 2026-11-15: Spec: "Passt, bauen" -> freigegeben.
