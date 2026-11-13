# Spec: Drops ohne Kopieren auf die Website

Stand: 2026-11-13 · Status: freigegeben (Nutzer 2026-11-13 auf der Seite Gilde > Werkzeuge: "wie können wir die
werkzeuge und das scannen und übermittel der daten verbesserm"; nach F-186 "mach alle aber nach deinen vorschlag",
Reihenfolge 6, 4, 7, 5; dies ist Vorschlag 6: "Drops ohne Kopieren auf die Website: Heute klickst du 'Drops für die
Website', kopierst den Text und fügst ihn auf der Website ein. Dein Spielstand mit den Drop-Daten (eigene und aus
der Gilde gehörte) liegt aber ohnehin auf dem N100. Der Datenbau könnte sie direkt in die Website schreiben, sodass
das Kopieren entfällt.") · Feature: F-187

## Ziel

Die Kills, die das Addon des Nutzers aufzeichnet oder in der Gilde hört, erscheinen im Reiter Loot Tables der
Website, ohne dass jemand im Spiel "Drops für die Website" klickt, den Text kopiert und im Reiter Import einfügt.
Gelöst ist es, wenn nach einem Datenbau und einem Push die Kills auf der Seite stehen und ein trotzdem
eingefügter Text keinen Kill doppelt zählt.

## Was es tut

- **Datenbau:** `python3 tools/build.py data` hat einen neuen Schritt "site drops" (`tools/build_site_drops.py`,
  auch allein lauffähig), vor dem BiS-Bau. Er liest die Drop-Sätze der SavedVariables (`AmisiaDB.drops.k`,
  eigene und gehörte; Standard `~/addons/_SavedVariables/Amisia.lua`, `--sv` wie die anderen Schritte), legt sie
  ins Archiv `tools/drop_obs.json` (gibt es seit F-063, gleiche Regeln wie `tools/build_scan.py`: ein Kill je
  Kennung, je Item die größere Zahl, der frühere Tag) und schreibt jeden Kill des Archivs in die Datei
  `Amisia-Website/data/drops-forever.js`.
- **Inhalt der Datei** (`window.__DROPS["forever"]`): `k` die Kills nach Tag, dann Kennung:
  `[Kennung, NPC, Instanz, Schwierigkeit, Tag, G|E, [Item, Anzahl, ...]]`; `names` Bossnamen je NPC und `zones`
  `[party|raid, Name]` je Instanz, nur die, die ein Kill nutzt. Das ist der Inhalt des Textes (DZ/DN/DK) ohne
  seine Kopfzeile und ohne die Herkunft je Kill (siehe Daten).
- **BUILD_ID:** ändert sich der Inhalt der Datei, hebt der Schritt `BUILD_ID` in `Amisia-Website/index.html` auf
  die aktuelle Unix-Zeit (mindestens um eins); gleicher Inhalt, gleiche Bytes, keine Änderung.
- **Seite:** Forever lädt die Datei wie die anderen Datendateien (Skript mit `?v=BUILD_ID`, einmal, nur für das
  Spiel, zu dem sie gehört; das TBC-Archiv hat keine). Loot Tables zählt die Kills der Datei und des Ledgers
  (`state.dropObs`) zusammen, je Kill-Kennung einmal. Das Feld "Boss kills from the Amisia addon" im Reiter Import
  und "Add the kills" bleiben (andere Offiziere fügen weiter ein); der Text sagt jetzt "(m new, k already on the
  site from the data build)" und dass die Kills, die das Addon des Seitenbesitzers aufzeichnet oder hört, mit
  jedem Datenbau von selbst kommen. Der Hinweis über Loot Tables und der leere Zustand sagen dasselbe.

## Was es ausdrücklich nicht tut

- Kein Schreiben nach Supabase aus einem Skript, keine Änderung am Supabase-Schema: die Datei ist statisch.
- Kein Netz: der Schritt liest nur Dateien auf dem N100.
- Keine Änderung am Addon. Der Hinweis im Spiel unterbleibt: das Addon ist öffentlich (CurseForge), ein Satz
  "deine Kills kommen von selbst" stimmt nur für den Seitenbesitzer und wäre für jeden anderen Spieler falsch.
- Das Addon wird nicht gekürzt: seine 28 Tage und 4000 Sätze bleiben, der Austausch in der Gilde braucht sie.
- Kein Push: live geht die Datei mit dem Push eines Datenbaus (GitHub Pages), nicht mit einem Addon-Release.

## Abläufe

1. Spieler loggt aus; Syncthing bringt `Amisia.lua` auf den N100.
2. `python3 tools/build.py data` (von Hand oder auf einem `auto/data-<build>`-Zweig): der Schritt "site drops"
   nimmt neue Kills ins Archiv, schreibt die Datei neu, wenn sich etwas änderte, und hebt dann `BUILD_ID`; am Ende
   zeigt `git diff --stat` auch `Amisia-Website/data` und `index.html`.
3. Commit und Push nach main: GitHub Pages veröffentlicht die Seite; Browser holen die neue Datei wegen der neuen
   `BUILD_ID`.
4. Auf der Seite: Loot Tables zeigt die Kills. Fügt ein Offizier denselben Text noch einmal ein, nennt das Feld
   sie "already on the site from the data build"; "Add the kills" ändert keine Zahl.

## Abnahmekriterien

- Wenn nach einem Datenbau (`python3 tools/build.py data`) und dem Push der Reiter Loot Tables geöffnet wird, dann
  zeigt er die Kills des eigenen Addons (eigene und gehörte), ohne dass ein Text eingefügt wurde.
- Wenn ein Offizier danach den Text "Drops für die Website" mit denselben Kills im Reiter Import einfügt, dann sagt
  das Feld "(0 new, n already on the site from the data build)", und nach "Add the kills" bleiben die Zahlen gleich.
- Wenn ein Offizier Kills einfügt, die der Datenbau nicht hat, dann kommen sie zu den Kills der Datei dazu.

## Sonderfälle

- **Keine SavedVariables** (Werkzeugtests, ein neuer Rechner): das Archiv bleibt, die Datei wird aus ihm
  geschrieben (leer, wenn es leer ist); `build.py data` bleibt grün. Eine kaputte Datei: eine Zeile "not read",
  der Bau läuft weiter.
- **Fehlende oder kaputte Datei auf der Seite:** `onerror` setzt nichts, die Seite zählt nur den Ledger; Zeilen der
  Datei, die nicht die Form haben, werden übergangen.
- **Datei kommt an, während das TBC-Archiv offen ist:** sie wartet in `window.__DROPS`, Forever nimmt sie beim
  Zurückkehren.
- **Kill um Mitternacht:** gleiche Kennung, der frühere Tag gilt (wie im Addon und im Archiv).
- **Beobachtungen in `data/forever.js`** (`obsThrough`, `obsIds`, aus einem vollen Bau von `build_scan.py`): Kills
  der Datei bis zu diesem Tag zählen dort, nicht noch einmal (gleiche Regel wie für den Ledger).
- **Kills ohne NPC** (Ersatzkennungen der Begegnung, `E`): stehen in der Datei wie im Text, zählen auf der Seite
  nirgends (wie bisher).

## Missbrauch/Vertrauen

- Die Datei ist öffentlich, sobald sie gepusht ist (GitHub Pages); der Ledger hinter der Anmeldung nicht. Darum
  nur Drop-Statistik: keine Spieler-, Charakter-, Gilden-, Realm- oder Kontonamen, nicht die Kopfzeile des Textes
  ("#AMISIA 2 <Name des Exportierenden>"), nicht die Herkunft je Kill (die zufällige Client-Kennung `o`, mit der
  sich Kills eines Clients verbinden ließen; im Archiv bleibt sie, für die Zusammenführung).
- Die Kill-Kennung ist ein Hash der Leichen-GUID (D-25), kein Name. Die Tage zeigen, an welchen Tagen Bosse fielen.
- Bossnamen und Instanznamen kommen von Clients (auch gehörte): die Seite setzt sie wie bisher durch `esc()` und
  nutzt Tabellen ohne Prototyp.

## Daten

- Neue Datei `Amisia-Website/data/drops-forever.js` (erzeugt, im Repo), Archiv `tools/drop_obs.json` (gab es schon,
  jetzt bei jedem `build.py data` gefüllt). Neue Seitenteile: `GAMES[].drops`, `DROPS`, `loadDrops`, `applyDrops`,
  `dropBaseOk`, `dropBaseKills`; `dropTables(data, st, drops)`, `dropPlan(parsed, st, drops)` mit `known`.
- Kein neuer `AmisiaDB`-Schlüssel, keine Einstellung, keine Nachricht, keine Exportzeile, kein Einfügeblock,
  kein neues Ledger-Feld.
- Was der Text heute trägt und was die Datei davon nimmt: Kopfzeile (Name des Exportierenden) nein; DZ Instanz,
  Art, Name ja (nur genutzte); DN NPC, Name ja, die Begegnung nein (die Seite nutzt sie nicht); DN 0 Begegnung,
  Name nein (die Seite nutzt sie nicht); DK Kennung, NPC, Instanz, Schwierigkeit, Tag, G/E, Items ja, Herkunft nein.
- Folge für das Addon: `tools/drop_obs.json` ist auch der Grundbestand der Dropraten (`build_bis.py`, `ns.BIS.O`);
  ein Datenbau mit neuen Kills ändert darum auch `Amisia/Data/BisData.lua` (geht mit dem nächsten Release ins Spiel).

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-13: Vorschlag 6, Status-Zeile oben.
- Annahme (nicht gefragt): Das vorhandene Archiv `tools/drop_obs.json` und seine Zusammenführung aus
  `tools/build_scan.py` werden genutzt statt eines zweiten Archivs; es war bisher leer, weil `build_scan.py` nicht
  Teil von `build.py data` ist.
- Annahme (nicht gefragt): Eine eigene Datei je Spiel mit einzelnen Kills statt der Summen in `data/forever.js`:
  die Seite kann so Kill für Kill mit dem Ledger abgleichen, und die große Item-Datei bleibt unberührt.
- Annahme (nicht gefragt): Ohne Kills wird die Datei trotzdem geschrieben (leer), damit die Seite kein 404 lädt und
  der Test "Datei passt zum Archiv" immer gilt.
- Annahme (nicht gefragt): `BUILD_ID` wird die aktuelle Unix-Zeit (wie die bisherigen Werte), mindestens alt + 1.
- Annahme (nicht gefragt): Die Herkunft je Kill bleibt aus der öffentlichen Datei, obwohl sie kein Name ist.
- Annahme (nicht gefragt): Kein Hinweis im Addon (siehe "Was es ausdrücklich nicht tut").
- Annahme (nicht gefragt): Der Schritt läuft vor dem BiS-Bau, damit Datei und Grundbestand aus demselben Archiv kommen.
