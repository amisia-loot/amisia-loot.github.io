# Spec: Was ist neu nach einem Update

Stand: 2026-11-25 · Status: freigegeben ·
Feature: F-236

## Ziel

Nach einem Update weiß der Spieler nicht, was die neue Version bringt, und findet neue Knöpfe nicht. Gelöst ist es,
wenn nach dem ersten Login mit einer neuen Version einmal, unaufdringlich, die wichtigsten Neuerungen dastehen, auf
Deutsch (englischer Client: Englisch), und man sie später jederzeit wieder aufrufen kann.

## Was es tut

- **Fenster "Neu in Amisia X.Y.Z"** (Amisia-Stil, `T.NEWS`): die Neuerungen der Versionen seit der zuletzt gesehenen
  bis zur laufenden, neueste zuerst, je Version eine goldene Zeile "Version X.Y.Z" (nur bei mehr als einer Version),
  darunter je Feature eine Zeile "· Titel". Acht Zeilen hoch, mehr scrollt. Unten links "Einstellungen" (Abschnitt
  Oberfläche), unten rechts "Schließen".
- Es kommt einmal, 6 s nach dem Betreten der Welt, nie im Kampf und nie während eines Bosskampfs (es wartet, bis
  beides vorbei ist).
- **Einstellung** `ui.whatsNew` (an) "Neuigkeiten nach einem Update zeigen" unter Allgemein > Oberfläche.
- **Klickweg** (D-167): Link "Neuigkeiten" im Kopf der Seite "Über und Befehle"; Abkürzung `/amisia neu` (en `news`).
  Beide zeigen alle Versionen der Datei.
- **Inhalt** aus dem Release: `tools/build_whatsnew.py` schreibt `Amisia/Data/WhatsNew.lua` aus `docs/FEATURES.md`
  (deutscher Titel je Feature) und `CHANGELOG.md` (englische Zusammenfassung). Je Version: die Features, die ihre
  `feat`-Notizen nennen (erste F-Nummer, eine Zeile je Feature, Notizen mit Scope `site` nicht), dann Features mit
  `Version:` dieser Version ohne eigene `feat`-Notiz. Die letzten fünf Versionen mit Einträgen. `build.py release`
  schreibt die Datei nach dem Setzen der Version und vor dem Check; die Notizen unter "Unreleased" zählen dann als die
  der neuen Version.

## Was es ausdrücklich nicht tut

- Keine Fehlerbehebungen und Datenänderungen (nur `feat`-Notizen und neue Features); dafür gibt es das Changelog.
- Kein Sprung von einer Zeile auf eine Seite: FEATURES.md kennt keine Seitenschlüssel, eine Zuordnung von Hand würde
  veralten.
- Kein Text aus dem Netz, keine Nachricht an andere Spieler.
- Erweitert eine Version ein älteres Feature, steht dessen deutscher Titel da (die englische Notiz lässt sich nicht
  übersetzen).

## Abläufe

1. Spieler hat 2.109.0, installiert 2.110.0, loggt ein: nach 6 s das Fenster mit den Neuerungen von 2.110.0.
   "Schließen" schließt es; beim nächsten Login kommt nichts mehr.
2. Spieler übersprang Versionen (2.107.0 -> 2.110.0): das Fenster zeigt 2.110.0, 2.109.0, 2.108.0, 2.107.1 mit ihren
   Überschriften (höchstens die fünf der Datei).
3. Login im Kampf oder im Bosskampf: das Fenster wartet bis zum Kampfende und Ende des Encounters.
4. Erste Installation: nichts, die Version wird gemerkt.
5. Jederzeit: "Über und Befehle" > "Neuigkeiten" oder `/amisia neu`.

## Abnahmekriterien

- Wenn du nach dem Update auf 2.110.0 einloggst, dann zeigt sich nach wenigen Sekunden einmal "Neu in Amisia 2.110.0" mit den Neuerungen; nach `/reload` nicht noch einmal.
- Wenn du im Kampf einloggst oder neu lädst, dann wartet das Fenster bis nach dem Kampf.
- Wenn du auf der Seite "Über und Befehle" auf "Neuigkeiten" klickst (oder `/amisia neu` tippst), dann zeigt das Fenster die Neuerungen der letzten Versionen.
- Wenn du "Neuigkeiten nach einem Update zeigen" unter Einstellungen > Oberfläche ausschaltest, dann kommt beim nächsten Update kein Fenster.
- Wenn das Spiel auf Englisch läuft, dann stehen die Neuerungen auf Englisch da.

## Sonderfälle

- Bosskampf/Kampf: warten (`InCombatLockdown`, `C_InstanceEncounter.IsEncounterInProgress`), dann zeigen.
- Installation vor diesem Schlüssel (kein `seenVersion`, aber eine gespeicherte Datei): die Neuerungen der laufenden
  Version. Ganz neue Installation (keine gespeicherte Datei): nichts.
- Ältere Version installiert als gesehen (zurückgestuft): nichts, der Schlüssel bleibt.
- Keine Einträge für die Versionen dazwischen (nur Fixes): nichts, als gesehen markiert.
- TBC Anniversary und Classic Era: die Datei lädt überall (keine Forever-Markierung).
- `/reload` ändert nichts: die Version ist da schon gemerkt.

## Missbrauch/Vertrauen

Nichts. Kein Austausch mit anderen Spielern; die Texte stammen aus dem Release.

## Daten

- Neuer Schlüssel `AmisiaDB.seenVersion` ("X.Y.Z"; alles andere fällt beim Laden weg).
- Neue Einstellung `ui.whatsNew` (Abschnitt `ui`, kein neuer Abschnitt).
- Neue generierte Datei `Amisia/Data/WhatsNew.lua` (lazy `WHATSNEW`, `tools/modules.py` `DATA_HOME`: core, ohne
  camelot-Markierung) und `UI/WhatsNew.lua` in `Amisia.toc` und den klassischen TOCs.
- `build.py whatsnew`, Schritt in `build.py release`; `tools/tests/test_build_whatsnew.py` hält die Datei aktuell.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-25: Der Nutzer hat das Feature freigegeben (Auftrag: einmal, unaufdringlich, Deutsch/Englisch, abschaltbar,
  Link auf der Seite "Über", `/amisia neu`). Klickbare Zeilen: weggelassen (keine saubere Zuordnung).
