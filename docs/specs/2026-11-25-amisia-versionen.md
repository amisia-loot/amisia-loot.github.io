# Spec: Seite "Amisia-Versionen"

Stand: 2026-11-25 · Status: freigegeben ·
Feature: F-237

## Ziel

Wer in Gilde und Raid Amisia hat und welche Version, stand bisher als kleine Liste mit acht Zeilen auf der Seite
"Über und Befehle", geteilt mit der Befehlsliste; wer kein Amisia hat, sah man nur im Raid nach "Raid fragen".
Gelöst ist es, wenn eine eigene Seite die ganze Höhe nutzt, Version, Module, Spielsprache und Ansicht jedes
Amisia-Nutzers zeigt, nach jeder Spalte sortiert, filtert (online, veraltet, ohne Amisia) und ehrlich sagt, von wem
nur noch nichts gehört wurde.

## Was es tut

- **Seite "Amisia-Versionen"** (Schlüssel `versions`, Reiter Gilde, Reihenfolge 78, alle Clients, jede Ansicht,
  Tokens `T.VERSIONS`):
  - Kopfzeile: die Filter als Text-Reiter "Alle", "Online", "Veraltet", "Ohne Amisia"; rechts die Links "Raid fragen"
    und "Gilde fragen" (von "Über und Befehle" hierher), gesperrt mit Tooltip wie bisher ("Nur in einer Raidgruppe.",
    "Nur in einer Gilde.", "Wieder in 3 Minuten.", "Versionsprüfung ist ausgeschaltet.", "Addon-Nachrichten sind nicht
    verfügbar.").
  - Zeile darunter: "14 mit Amisia · 9× 2.110.0 · 3× 2.109.0 · 2 veraltet" (die drei häufigsten Versionen, dann
    "· N weitere"; "· N ohne Raid" wo es das gibt); darunter der Hinweis auf eine neuere Version (`ns.VersionNewer`).
  - Spalten (ein Klick auf den Kopf sortiert, ein zweiter dreht um): Name (Klassenfarbe, davor der grüne
    Online-Punkt des Spiels aus der Gildenliste), Version (orange älter als die höchste gesehene, rot zu alt für den
    Hüter, grau "ohne Raid"), Module (Symbole der Reiter Ausrüstung, Dungeons & Raids, Talente; nur Forever), Sprache
    (`ns.VersionLang`), Ansicht (`ns.VersionView`), Wo (Raid/Gilde), Zuletzt (Uhrzeit von heute, sonst Tag).
  - Ohne Sortierung: der Raid, dann die Gilde wie bisher (`ns.VersionRows`), dann die Mitglieder ohne Amisia, die
    online zuerst.
  - Tooltip je Zeile: voller Name, Version, Module, Sprache, Ansicht, wo gesehen, zuletzt mit Datum und Uhrzeit; bei
    einem Mitglied ohne Hallo, was das heißt.
- **Mitglieder ohne Amisia:** jedes Mitglied der Gildenliste ohne Hallo in den letzten 30 Tagen, grau, "-" als
  Version. Wortlaut: "nichts gehört"; "kein Amisia?" erst, wenn das Mitglied online ist und eine Gildenfrage dieser
  Sitzung ihre Antworten hatte (16 s), und wie bisher für Raidmitglieder 10 s nach "Raid fragen".
- **Über und Befehle:** statt der Liste eine Zeile "N mit Amisia gesehen" und der Link "Alle Versionen" (öffnet die
  Seite); Kopf, Neuigkeiten, Selbsttest und der Hinweis auf eine neuere Version bleiben, die Befehle bekommen den Platz.
- **Einstellungen:** das Zahnrad der Seite öffnet "Sync und Version" (`pages` um `versions` ergänzt).
- `/amisia version` bleibt, wie es ist (fragt und schreibt die Liste in den Chat).

## Was es ausdrücklich nicht tut

- Keine neue Nachricht, kein neues Feld im Hallo, kein neuer gespeicherter Schlüssel: Filter und Sortierung gelten
  für die Sitzung.
- Kein Flüstern oder Einladen aus der Liste (das hat die Seite Mitglieder).
- Kein Link in der Zählzeile der Seite Mitglieder: die Zeile ist ein Text der Fußzeile, ein Link passt dort nicht
  sauber hinein.
- Keine Marken in der Seitenleiste: vier Filter sind schon in der Kopfzeile.

## Abläufe

1. Spieler öffnet Gilde > Amisia-Versionen: die eigene Zeile, alle gesehenen Hallos, darunter grau die Mitglieder
   ohne Hallo ("nichts gehört"), die online zuerst.
2. Er klickt "Gilde fragen": jedes Amisia der Gilde antwortet in 1 bis 15 s; nach 16 s steht bei Mitgliedern, die
   online sind und nicht antworteten, "kein Amisia?". Der Link ist 5 Minuten gesperrt (Tooltip "Wieder in ...").
3. Im Raid "Raid fragen": nach 10 s die Raidmitglieder ohne Antwort mit "kein Amisia?".
4. "Veraltet" zeigt nur, wer eine ältere Version hat; ein Klick auf "Version" sortiert nach Version.
5. Ohne Gilde (z. B. ein Raid auf TBC/Era mit Fremden): die eigene Zeile und der Raid; "Ohne Amisia" zeigt die
   Raidmitglieder ohne Antwort.

## Abnahmekriterien

- Wenn du Gilde > Amisia-Versionen öffnest, dann stehen dort du und alle, deren Amisia sich gemeldet hat, mit Version, Modulen, Sprache und Ansicht, und oben "N mit Amisia · ...".
- Wenn du "Gilde fragen" klickst und 20 Sekunden wartest, dann stehen Mitglieder, die online sind und nicht antworteten, unter "Ohne Amisia" mit "kein Amisia?" (braucht: Gilde).
- Wenn du auf "Veraltet" klickst, dann stehen nur die älteren Versionen da, orange; ein Klick auf "Version" sortiert nach Version.
- Wenn du auf "Über und Befehle" auf "Alle Versionen" klickst, dann öffnet sich die Seite Amisia-Versionen.
- Wenn du im Raid "Raid fragen" klickst, dann stehen nach 10 Sekunden die Raidmitglieder ohne Amisia grau mit "kein Amisia?" (braucht: Raid).

## Sonderfälle

- Kampfsperre: die Gildenliste vor der Sperre (`ns.GuildRoster`); die Links fragen wie bisher.
- Keine Gilde: keine Zeilen "ohne Amisia" aus der Gilde; die Seite bleibt im Reiter Gilde, den die Seite Mitglieder
  auf jedem Client zeigt (auch TBC und Era).
- TBC/Era: keine Module (Spalte leer, ohne Kopf).
- Ein Hallo eines Amisia vor 2.104.0 mit "g" heißt alle drei Module, eines ohne Feld (vor F-202) ebenso.
- Mitglieder, die seit über 30 Tagen nicht online waren: "nichts gehört" (die Liste vergisst Hallos nach 30 Tagen).
- Nachnamen: ein Hallo ohne Nachnamen passt zum einzigen Mitglied mit diesem Vornamen.
- Große Gilde: die Liste baut nur neu, wenn sich Hallos, Gildenliste, Gruppe oder eine Frage ändern.

## Missbrauch/Vertrauen

Nichts Neues: die Seite liest nur, was `Version.lua` schon annimmt (Absender aus der eigenen Gilde, `ns.TrustWait`).
Ein Fremder kann keine Zeile erzeugen. Namen und Versionen kommen als Text in Zellen (keine Codes: die Version muss
"x.y.z" sein, um zu zählen; ein Name steht so da, wie der Server ihn setzt).

## Daten

Nichts Neues im Protokoll und in `AmisiaDB`. `ns.VersionSeen`/`ns.VersionRows` geben zusätzlich `lc` weiter;
neu `ns.VersionModuleKeys(row)` (die Module einer Zeile) und `ns.VersionAnswered(where)` (ob die letzte Frage
an Raid oder Gilde ihre Antworten hatte). Einstellungsabschnitt `sync`: `pages = { "about", "versions" }`.
Regel in `docs/DECISIONS.md` D-170.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-25: Anzeige wer Amisia hat und welche Version: "Eigene Seite" -> eine Seite im Reiter Gilde, die kleine
  Liste auf "Über und Befehle" wird eine Zeile mit Link.
