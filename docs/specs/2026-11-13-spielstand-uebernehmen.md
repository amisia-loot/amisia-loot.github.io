# Spec: Der N100 übernimmt den Spielstand von selbst

Stand: 2026-11-13 · Status: freigegeben (Nutzer 2026-11-13 auf der Seite Gilde > Werkzeuge: "wie können wir die
werkzeuge und das scannen und übermittel der daten verbesserm"; nach F-186 "mach alle aber nach deinen vorschlag";
dies ist Vorschlag 5: "Der N100 übernimmt deinen Spielstand von selbst: Heute liegen deine Scan-Daten nach dem
Ausloggen zwar auf dem N100, landen aber erst im Addon, wenn ich dort den Datenbau starte. Ein Zeitplan auf dem
N100 könnte das nach jedem Ausloggen selbst tun und festhalten, was neu ist. Veröffentlicht würde weiter nur auf
dein Wort.") · Feature: F-190

## Ziel

Nach dem Ausloggen baut der N100 die Daten mit dem neuen Spielstand (`~/addons/_SavedVariables/Amisia.lua`) von
selbst, prüft sie und hält fest, was neu ist. Die nächste Sitzung weiß damit schon vor einem Release, was der
Spielstand bringt und ob er etwas rot macht (wie am 2026-11-13 ein Dungeonname ohne Eintrag kurz vor einem Release).

## Was es tut

- **Dritter Auslöser C in `tools/auto_data.py`** (der Timer `amisia-auto-data.timer` läuft schon alle 15 Minuten):
  nur wenn A (Export des PCs) und B (täglicher Blick bei wago.tools) nichts bauen und kein neuer Client-Build
  wartet. Die Datei der SavedVariables zählt als neu, wenn ihr Inhalt (SHA-256; Größe und Zeit nur als schneller
  Vorabblick) sich gegenüber der zuletzt übernommenen geändert hat (`~/addons/_auto/amisia-sv.json`), sie seit
  5 Minuten ruht (Syncthing schreibt sonst noch) und der letzte Lauf von C mindestens 6 Stunden her ist.
- **Bau im Worktree** `~/addons/.amisia-auto`, losgelöst auf dem committeten `main`: `build.py data --sv <Datei>`.
  Ändert sich weder ein Archiv noch eine erzeugte Datei: eine Zeile "nichts Neues", kein Branch, keine Prüfung.
  Sonst `build.py check`, Commit, und der Branch `auto/sv-<JJJJ-MM-TT>` zeigt auf diesen Commit.
- **Block im Statusfile** `~/addons/_auto/amisia-data.txt`, unter dem Bericht eines Client-Builds und über der
  Zeile von wago.tools:
  `Spielstand vom 2026-11-13 12:01: übernommen auf Branch auto/sv-2026-11-13 (abc1234), Prüfung grün.`,
  `Neu gegenüber main: 312 Items, 18 Questnamen, 40 Kills.`, `Geänderte Dateien (n): ...`,
  `Zum Veröffentlichen: build.py data auf main, dann build.py release.`; bei roter Prüfung `Prüfung ROT:` mit den
  ersten fehlschlagenden Zeilen.
- **Veralteter Bericht:** hat main die Daten des Client-Builds, über den das Statusfile noch "FEHLER" oder "bereit"
  sagt, ersetzt der nächste Lauf den Bericht durch eine Zeile "main hat diese Daten inzwischen".
- `--force-sv` übernimmt sofort (ohne Abstand, auch denselben Inhalt); `--dry-run` sagt nur, was es täte; aus mit
  `~/addons/_auto/amisia-sv.off` oder `AMISIA_AUTO_SV=0`.

## Was es ausdrücklich nicht tut

- Kein Push, kein Merge nach main, kein Release, kein Commit auf main (D-51 bleibt; D-122).
- Ändert nichts im Addon und nichts im Spiel; schreibt nie in die SavedVariables (nur lesen).
- Kein Netz: C fragt nichts (der Datenbau nimmt die Tabellen auf der Platte, `tools/client_tables.py`).
- Kein neuer Timer, keine neue systemd-Einheit: der vorhandene Timer ruft dasselbe Skript.

## Abläufe

1. Spieler loggt aus; Syncthing bringt `Amisia.lua` auf den N100.
2. Der nächste Timerlauf nach 5 Minuten Ruhe: A und B haben nichts; C sieht einen neuen Inhalt; ist der letzte
   Lauf von C 6 Stunden her (oder nie gewesen), baut er im Worktree, prüft, committet auf `auto/sv-<Tag>` und
   schreibt den Block. Ein zweiter Lauf am selben Tag fängt wieder bei main an und setzt den Branch des Tages neu
   (die neuere Datei enthält alles der älteren, solange nicht veröffentlicht wurde).
3. Sitzungsbeginn: Claude liest `amisia-data.txt` und meldet, was neu ist oder was rot ist.
4. Veröffentlichen nur auf Wort des Nutzers: `build.py data` auf main, dann `build.py release` (oder den Branch
   mergen).

## Abnahmekriterien

- Wenn du ausloggst und etwa 6 Stunden nach dem letzten Lauf (beim ersten Mal sofort) plus 5 Minuten Ruhe und bis
  zu 15 Minuten Takt vergehen, dann steht in `~/addons/_auto/amisia-data.txt` ein Block "Spielstand vom ...", der
  nennt, was neu ist (Items, Questnamen, NPC-Namen, Kills ...), und es gibt den Branch `auto/sv-<Tag>`.
- Wenn die Prüfung mit dem Spielstand rot ist, dann sagt der Block "Prüfung ROT:" mit den ersten fehlschlagenden
  Zeilen, und der Branch bleibt.
- Wenn der Spielstand nichts Neues bringt, dann steht dort eine Zeile "nichts Neues gegenüber main." und kein
  Branch entsteht.
- Wenn C gelaufen ist, dann sind main, sein Arbeitsverzeichnis und die SavedVariables unverändert.

## Sonderfälle

- **Datei wird noch geschrieben:** jünger als 5 Minuten wartet sie.
- **Gleicher Inhalt, neue Zeit** (Syncthing schreibt neu): kein Lauf, nur die Zeit wird gemerkt.
- **Kaputte Datei:** ohne `AmisiaDB` eine Zeile "nicht lesbar"; scheitert der Parser des Datenbaus, steht dessen
  Meldung im Block. Kein Branch; erst eine geänderte Datei (oder `--force-sv`) versucht es wieder.
- **Neuer Client-Build wartet** (Export noch unvollständig, höchstens einen Tag; wago.tools unvollständig geladen):
  C wartet, A und B zuerst. Ein versuchter, aber nicht auf main gelandeter Build hält C nicht auf; der Block sagt
  dann, dass der Branch auch dessen Tabellen enthält.
- **main schmutzig oder mitten im Release:** egal, gebaut wird aus dem committeten `main` im Worktree; die
  Builder schreiben neben ihr eigenes Skript (`HERE`/`ROOT`), also ins Worktree.
- **Fehler unterwegs** (git, Worktree): eine Zeile "abgebrochen", der Worktree wird immer entfernt.

## Missbrauch/Vertrauen

Nichts verlässt den N100. Die SavedVariables sind die eigenen des Nutzers und werden nur gelesen; der Datenbau
liest sie im Sandkasten wie bisher (`tools/build_scan.py`). Die Gildendaten darin (gehörte Kills) gelangen nur über
den bestehenden Datenbau in die Archive, und erst mit einem Push des Nutzers auf die Seite.

## Daten

Kein `AmisiaDB`-Schlüssel, keine Einstellung, keine Nachricht. Neu nur auf dem N100: `~/addons/_auto/amisia-sv.json`
(Größe, Zeit und SHA-256 der zuletzt übernommenen Datei, Zeit des letzten Laufs, Ergebnis, Branch, Commit, die
Zeilen des Blocks), der Schalter `~/addons/_auto/amisia-sv.off`, die Branches `auto/sv-<JJJJ-MM-TT>` (die neuesten
5 bleiben) und der Block "Spielstand vom ..." in `amisia-data.txt`. ARCHITECTURE "Machines", DECISIONS D-122.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-13: Nutzer: "mach alle aber nach deinen vorschlag" -> Vorschlag 5 so gebaut.
- Annahme (nicht gefragt): 6 Stunden Abstand zwischen zwei Läufen von C (ein Abend mit vielen Logouts kostet einen
  Bau und eine Prüfung von etwa 15 Minuten statt eines je Logout), 5 Minuten Ruhe wie beim Export des PCs.
- Annahme (nicht gefragt): ein Branch je Tag; ein zweiter Lauf am Tag fängt wieder bei main an und setzt den
  Branch neu (keine Endungen, kein Weiterbauen auf einem veralteten Stand); die neuesten 5 `auto/sv-*` bleiben,
  ältere werden gelöscht (sie sind aus Datei und main jederzeit neu zu bauen), `auto/data-*` bleiben unberührt.
- Annahme (nicht gefragt): "neu" zählt je Archiv neue und geänderte Einträge gegenüber dem committeten main
  (Items, Item-Quellen, Questnamen, NPC-Namen, beobachtete Quests, Quest-Items, Quest-Merkmale, Eingänge, Lehrer,
  Kills) und nennt die geänderten Dateien; was die Builder sonst ändern, steht nur in der Dateiliste.
- Annahme (nicht gefragt): ein Bericht über einen Client-Build, dessen Daten main schon hat, wird auch ersetzt,
  wenn er "bereit" sagte (dann ist er genauso überholt wie "FEHLER").
- Annahme (nicht gefragt): kein Eintrag im CHANGELOG: kein Spieler merkt es (D-60), wie D-103.
