# Spec: Lauf-Zeiten (Speedrun-Timer) für Dungeons und Raids

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10 auf die Liste der neun Punkte: "1,2,3,5,8,9") ·
Feature: F-166

## Ziel

Wer einen Dungeon oder Raid läuft, sieht seine Zeit: die Uhr des Laufs, die Zwischenzeit je Boss gegen den
besten Lauf und am Ende "Neue Bestzeit!" oder den Abstand. Bisher zeigte Amisia nur, welche Bosse tot sind
(F-146), und das Raid-Log die Kills eines aufgenommenen Raids, aber nichts zum Vergleichen. Gelöst ist es,
wenn ein zweiter Lauf derselben Instanz grün und rot gegen den ersten zählt.

## Was es tut

- **Uhr** (`Gear/RunTimes.lua`): sie startet mit dem ersten Kampf (`PLAYER_REGEN_DISABLED`) in der Instanz,
  solange der eigene Lauf (`Gear/Runs.lua`) noch keinen toten Boss hat, einmal je Lauf. Betreten allein
  startet nichts (man wartet am Eingang). Jeder Kill eines Bosses der Liste (`ENCOUNTER_END` mit Erfolg,
  `BOSS_KILL`) speichert seine Zwischenzeit in Sekunden seit dem Start; der Kill des letzten Bosses in der
  Reihenfolge des Spiels (die Fakten, `R.Fact`) beendet den Lauf. Es ist Wanduhrzeit: draußen und ausgeloggt
  läuft sie weiter.
- **Nicht beendet:** endet der Lauf von `Runs.lua` vorher (die Instanz zurückgesetzt, eine andere Instanz, ein
  frischer Lauf), ist man 30 Minuten draußen, läuft die Uhr 12 Stunden oder tippt man `/amisia zeiten stop`,
  steht der Lauf als "nicht beendet" im Verlauf, mit der Zeit bis zu seinem letzten Kill, und wird nie Bestzeit.
- **Fenster** "Lauf-Zeiten" (`Gear/RunTimer.lua`, `AmisiaRunTimer`): Titel der Instanzname, die laufende Zeit,
  darunter grau "Bestzeit 25:01", dann je Boss in der Reihenfolge des Spiels Name, Zwischenzeit und daneben der
  Abstand zum besten Lauf (grün schneller "-0:12", rot langsamer "+0:07"); beim nächsten Boss grau die
  Zwischenzeit des besten Laufs als Ziel. Am Ende "Neue Bestzeit! -0:48", "+1:40 zur Bestzeit" (rot) oder
  "Erste gemessene Zeit"; der Link "Alle Zeiten" öffnet den Teil Zeiten der Seite. Es öffnet sich von selbst
  beim Start der Uhr, bleibt während sie läuft (auch draußen als Geist), zeigt das Ergebnis bis zum Verlassen
  der Instanz und schließt sich, wenn die Uhr nicht beendet endet. Verschiebbar, Platz gemerkt, Escape lässt es
  offen.
- **Seiten Dungeons und Raids:** im Detail ein Reiter "Zeiten" (nur mit den Encounter-IDs der Bosse): "Bester
  Lauf" (Datum, Zeit, Gruppe, Charakter), "Bestzeit je Boss" (die Zwischenzeit im besten Lauf und die
  schnellste Strecke vom Boss davor bis zu ihm), "Letzte Läufe" (Datum, Zeit oder "nicht beendet · 2/4 Bosse",
  Gruppe, Charakter); in der Zeile der Überschrift "Zeiten löschen" (nach `W.Confirm`).
- **Chat** (nur bei dir) am Ende eines beendeten Laufs: "Burg Schattenfang in 24:13 (Bestzeit 25:01, -0:48)."
  bzw. "Burg Schattenfang in 24:13 (erste gemessene Zeit)."
- **Befehl:** `/amisia zeiten` (en `times`): das Fenster der laufenden Uhr oder der Instanz, in der man steht;
  draußen der Teil Zeiten der zuletzt gemessenen Instanz. `/amisia zeiten stop` hält die Uhr ohne Bestzeit an.
- **Einstellungen** "Lauf-Zeiten" (Reiter Dungeons & Raids, alle): "Zeitfenster in Dungeons" (an), "Zeitfenster
  auch in Raids" (an), "Alle Bestzeiten löschen" (fragt erst).

## Was es ausdrücklich nicht tut

- Keine Zeiten an andere Spieler, keine Gilden-Rangliste, keine neue Addon-Nachricht.
- Keine Änderung an der Raid-Aufnahme oder ihrem Export (`Raid/RaidLog.lua` bleibt, wie er ist).
- Keine Timer für Bossfähigkeiten, keine Zeiten für Trash oder Abschnitte ohne Boss.

## Abläufe

- **Allein im Dungeon:** Betreten, am Eingang warten: nichts. Erster Kampf: das Fenster geht auf, die Uhr läuft.
  Jeder Boss bekommt seine Zeit; der letzte Boss beendet den Lauf, das Fenster zeigt das Ergebnis, im Chat steht
  die Zeile. Rauslaufen schließt das Fenster.
- **Abbruch:** "Instanz zurücksetzen" oder 30 Minuten draußen: der Lauf steht "nicht beendet" im Verlauf, das
  Fenster geht zu. Ein neuer Lauf beginnt mit dem nächsten Kampf.
- **Nachsehen:** Seite Dungeons, Dungeon wählen, Reiter "Zeiten"; oder `/amisia zeiten` draußen.

## Abnahmekriterien

- Wenn du allein einen Dungeon betrittst und eine Minute am Eingang wartest, dann ist kein Fenster offen; beim
  ersten Kampf geht "Lauf-Zeiten" mit dem Namen des Dungeons auf und die Zeit läuft ab 0:00.
- Wenn du den ersten Boss tötest, dann steht seine Zeit in seiner Zeile; tötest du den letzten Boss, dann steht
  im Chat "<Dungeon> in m:ss (erste gemessene Zeit)." und im Fenster "Erste gemessene Zeit".
- Wenn du denselben Dungeon nach "Instanz zurücksetzen" noch einmal läufst, dann steht beim nächsten Boss grau
  die Zeit des ersten Laufs, nach dem Kill grün "-m:ss" oder rot "+m:ss"; am Ende "Neue Bestzeit!" oder die
  Differenz in Rot.
- Wenn du `/amisia zeiten stop` tippst, dann steht "Uhr angehalten: der Lauf zählt als nicht beendet." und der
  Reiter Zeiten zeigt den Lauf als "nicht beendet"; die Bestzeit bleibt.
- Wenn du in einem Raid den ersten Kampf beginnst, dann geht das Fenster ebenso auf (Einstellung "Zeitfenster
  auch in Raids") (braucht: Raid).

## Sonderfälle

- Bosskampf: Werte der Ereignisse gehen durch `ns.Plain`; ein geheimer Wert zählt nicht (kein Split). Das
  Fenster ist ein einfacher Rahmen ohne geschützte Aufrufe, gebaut beim Betreten (außerhalb des Kampfes);
  sichtbar wird es auch im Kampf.
- Tod und Geist: draußen läuft die Uhr weiter, das Fenster bleibt offen.
- `/reload` oder Ausloggen: die Uhr steht gespeichert (`time()`), nach dem Login zeigt das Fenster sie wieder,
  wenn man in der Instanz steht; die Anzeige läuft mit `GetTime()`.
- Ein Boss von Hand markiert (F-146): kein Split; ein Lauf mit schon totem Boss startet keine Uhr.
- Zwei Schlüssel auf einer Karte (Blackrock Spire): der erste Kill entscheidet den Schlüssel.
- Ein Boss, der übersprungen wird: kein Split, keine Strecke; der Lauf endet trotzdem beim letzten Boss.
- Twinks: Zeiten sind für den Account, jeder Lauf nennt den Charakter; jede Uhr gehört einem Charakter.
- Englischer Client: Texte und Befehl englisch (`/amisia times`); Instanzname aus dem Client.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen; die gespeicherten Daten werden beim Laden Feld für Feld geprüft.

## Daten

- Neuer Schlüssel `AmisiaDB.runTimes = { v = 1, inst = { [Dungeon-Schlüssel] = { nm, best, seg, runs } },
  live = { [Charakter] = { k, i, nm, at, r, s, n } }, last = { [Charakter] = { r, i } } }`; ein Lauf
  `{ at, t, s = { [Encounter-ID] = Sekunden }, n = Gruppengröße, c = Charakter, d = beendet }`, `seg[Encounter-ID]
  = { t, at, c }` die schnellste Strecke. Beim Laden (`RT.Loaded`): jedes Feld geprüft, 20 Läufe je Instanz
  (die neuesten), 60 Instanzen (die zuletzt gelaufenen), eine Bestzeit nur aus einem beendeten Lauf, 12 Uhren,
  40 letzte Läufe.
- Einstellungen: Abschnitt `runtimes` mit `runtimes.window`, `runtimes.raids`, dem Knopf `runtimes.clear`;
  Fensterplatz `settings.runTimerWindow`.
- Ereignis `RUNTIMES` (intern). Keine Nachricht, kein Export.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-10: Nutzer auf die Liste der neun Punkte: "1,2,3,5,8,9" -> Punkt 5 "Speedrun-Timer: Zwischenzeit je
  Boss, Bestzeit, Verlauf". D-96.
- Annahme (nicht gefragt): der Schlüssel ist nur der Dungeon- oder Raid-Schlüssel, ohne Größe und
  Schwierigkeit: die Fakten dieses Clients kennen je Instanz eine Schwierigkeit (normal), Raids haben eine
  feste Größe; die Gruppengröße steht in jedem Lauf.
- Annahme (nicht gefragt): der Lauf endet mit dem letzten Boss der Reihenfolge des Spiels, nicht erst, wenn
  alle Bosse tot sind (seltene und optionale Bosse würden sonst jeden Lauf offen lassen).
- Annahme (nicht gefragt): das Fenster ist in Dungeons und Raids standardmäßig an, weil es erst beim ersten
  Kampf in einer Instanz erscheint und nie in der offenen Welt.
- Annahme (nicht gefragt): die Zeiten stehen als Reiter "Zeiten" im Detail der Seiten Dungeons und Raids (wie
  Zugang, nur mit den Bossen der Fakten), nicht als Ansicht im Fenster: dort sind schon Bosse, Karte und Zugang
  der Instanz, und das Fenster bleibt klein.
- Annahme (nicht gefragt): "Bestzeit je Boss" ist die schnellste Strecke vom Boss davor (der Zeit nach) bis zu
  ihm, nur aus beendeten Läufen; ein nicht beendeter Lauf trägt die Zeit bis zu seinem letzten Kill.
- Annahme (nicht gefragt): 30 Minuten draußen beenden die Uhr, wie `Runs.lua` einen Dungeon nach 30 Minuten
  neu beginnt; in Raids ebenso (der Lauf von `Runs.lua` hält dort bis zur Raid-ID, ein Raidabend nicht).
