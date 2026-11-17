# Spec: Buffs der Aufstellung im Planer

Stand: 2026-11-17 · Status: freigegeben ·
Feature: F-224

## Ziel

Nutzer 2026-11-17, mit einem Bild des leeren Planers (Raid > Aufstellung): "können wir hier in raidplaner wenn wir den
raid mit den klassen gefüllt haben anzeigen welche buffs wir haben und welche uns fehlen". Gelöst ist es, wenn der
Offizier beim Einteilen ohne Rechnen sieht, was die eingeteilten Klassen mitbringen und was fehlt, und die Anzeige bei
jedem Verschieben mitgeht.

## Was es tut

**A. Der Link "Buffs".** Im Planer steht rechts neben "Spieler" der Link "Buffs". Ein Klick zeigt unter den Gruppen
statt der Listen ("Nicht eingeteilt", "Ersatz" oder der Spielerliste) die Übersicht; ein zweiter Klick zeigt wieder die
Listen. "Spieler" und "Buffs" schließen einander aus. Die Wahl gilt für die Sitzung.

**B. Die Übersicht** hat drei Blöcke nebeneinander:

- **Buffs:** Arkane Intelligenz, Machtwort: Seelenstärke, Göttlicher Willen, Schattenschutz, Mal der Wildnis, Segen der
  Könige / der Macht / der Weisheit, die Auren des Paladins, Schlachtruf, Befehlsruf, die Totems, Aura des Volltreffers,
  Rudelführer, Mondkin-Aura, Blutpakt.
- **Auf dem Boss:** Rüstung zerreißen, Rüstung schwächen, Feenfeuer, Fluch der Elemente / der Tollkühnheit, Mal des
  Jägers, Demoralisierender Ruf, Donnerknall, Richturteil der Weisheit / des Lichts, Verbessertes Versengen, Winterkälte,
  Schattenwirken, Vampirberührung.
- **Nützliches:** Wiederbelebung im Kampf, Seelenstein, Gesundheitsstein, Fluch / Magie / Gift / Krankheit entfernen,
  Einlullender Schuss, Furchtzauberschutz, Anregen, Totem der Manaflut.

Die Liste ist die von Forever (Client-Build 1.60.1.70938), nicht die von Classic: Segen der Rettung gibt es dort nicht,
Befehlsruf und Vampirberührung schon. Namen und Symbole kommen vom Spiel selbst, also in der Sprache des Clients.

**C. Eine Zeile je Buff** mit Symbol, Name und Stand:

- **weiß, dahinter die Zahl** (z. B. "2"): mindestens eine eingeteilte Klasse bringt ihn von Haus aus.
- **gelb "Talent"**: eine eingeteilte Klasse kann ihn bringen, aber nur mit einem Talent (z. B. Aura des Volltreffers).
  Die Rolle zählt mit: Rudelführer nur bei Druiden als Tank oder Nahkämpfer, Mondkin-Aura nur als Fernkämpfer, Totem der
  Manaflut nur beim Heiler-Schamanen.
- **rot "fehlt"**: niemand Eingeteiltes kann ihn bringen.
- Buffs, die nur die eigene Gruppe treffen (Totems, Schlachtruf, Aura des Volltreffers, Rudelführer, Mondkin-Aura,
  Blutpakt, Paladin-Auren), nennen statt der Zahl die Gruppen: "Gr. 1, 3".

In jedem Block stehen die roten Zeilen oben, dann die gelben, dann die weißen (ein Block zeigt sechs Zeilen und rollt).

Der Tooltip einer Zeile nennt die Klasse, die ihn bringt, ob es ein Talent ist, und die Namen der Eingeteilten in
Klassenfarbe.

**D. Die Zeile "Es fehlt".** Im Planer steht immer (auch ohne "Buffs") eine Zeile "Es fehlt: Mal der Wildnis, Fluch der
Elemente (+3)": die roten Einträge, gekürzt auf die Breite. Fehlt nichts: grün "Alle Buffs da". Ein Klick öffnet die
Übersicht.

**E. Wer zählt.** Alle, die in einer Gruppe stehen. Steht noch niemand in einer Gruppe, zählen alle der Nacht, die
weder fehlen noch auf der Ersatzbank sind, und die Zeile sagt "(alle Anmeldungen)".

## Was es ausdrücklich nicht tut

- Es liest keine echten Buffs im Raid: das ist der Raid-Check (F-098). Hier zählt nur, was die Klassen der Aufstellung
  bringen können.
- Es kennt keine Skillung einzelner Spieler und fragt sie nicht ab (kein Inspect, keine Nachricht). Talent-Buffs bleiben
  deshalb gelb.
- "Automatisch einteilen" und "Gruppen sortieren" ändern sich nicht; die Übersicht warnt nur.
- Keine Fläschchen, Elixiere, Bufffood und Weltbuffs.
- Nicht auf TBC Anniversary und Classic Era: die Daten stammen aus den Tabellen von Forever. Dort fehlen Link und Zeile.

## Abläufe

1. Der Offizier öffnet Raid > Aufstellung > Planer und zieht Spieler in die Gruppen.
2. Nach jedem Ziehen, Tauschen, Entfernen oder Rollenwechsel rechnet Amisia neu; die Zeile "Es fehlt" ändert sich sofort.
3. Er klickt "Buffs" und sieht die drei Blöcke; rote Zeilen sagen, welche Klasse noch fehlt (Tooltip).
4. Er holt z. B. einen Druiden aus "Nicht eingeteilt" in eine Gruppe; "Mal der Wildnis" wird weiß.
5. Bei den anderen im Raid und in der Gilde passiert nichts.

## Abnahmekriterien

- Wenn du im Planer "Buffs" klickst, dann stehen unter den Gruppen die Blöcke "Buffs", "Auf dem Boss" und "Nützliches"
  mit Symbol und Namen in deiner Spielsprache; ein zweiter Klick zeigt wieder die Listen.
- Wenn kein Magier in einer Gruppe steht, dann ist "Arkane Intelligenz" rot mit "fehlt" und steht in der Zeile "Es
  fehlt"; ziehst du einen Magier in eine Gruppe, dann wird sie sofort weiß mit "1" und verschwindet aus "Es fehlt".
- Wenn ein Jäger eingeteilt ist, dann steht bei "Aura des Volltreffers" gelb "Talent" und seine Gruppe.
- Wenn ein Schamane in Gruppe 2 steht, dann steht bei "Totem des Windzorns" "Gr. 2".
- Wenn du mit der Maus auf eine Zeile gehst, dann nennt der Tooltip die Klasse und die eingeteilten Spieler, die ihn
  bringen.
- Wenn noch niemand in einer Gruppe steht, aber Anmeldungen da sind, dann rechnet die Zeile mit allen und sagt "(alle
  Anmeldungen)".
- Wenn du Amisia auf TBC Anniversary oder Classic Era öffnest, dann gibt es im Planer weder "Buffs" noch "Es fehlt".

## Sonderfälle

- **Eintrag ohne Klasse** (Name aus einer eingefügten Liste, den Amisia niemandem zuordnen kann): zählt nichts; unter der
  Übersicht steht grau "3 ohne Klasse".
- **Leere Nacht:** keine Zeile "Es fehlt", in der Übersicht grau "Noch niemand eingeteilt".
- **Twink getauscht** ("tauschen"): die Klasse des Eintrags ändert sich, die Übersicht rechnet neu.
- **Raidgröße 10/20:** dieselbe Liste; es gibt keine eigene Liste je Größe.
- **Client auf Englisch oder Amisia auf Englisch:** Zaubernamen vom Client, die festen Worte ("Talent", "fehlt", "Es
  fehlt") aus der Locale.
- **Ein Zauber fehlt im Client** (neuer Build, Zauber entfernt): die Zeile fällt weg, statt leer zu stehen; der Datenbau
  meldet es (Werkzeugtest).
- **Kampf, Bosskampf, `/reload`:** alles lokal aus gespeicherter Aufstellung, keine Sperre nötig.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen. Die Seite ist wie die ganze Aufstellung nur für Offiziere (D-41, D-92). Die Klasse
eines Eintrags kommt wie bisher aus Gilde, Raid oder der eingefügten Liste; eine falsche Klasse in einer eingefügten
Liste zeigt höchstens einen falschen Buff an.

## Daten

- **Neue erzeugte Tabelle** `Amisia_Gear/Data/RaidBuffData.lua` (`ns.Data("RAIDBUFFS")`), gebaut von
  `tools/build_raidbuffs.py` in `build.py data`: je Eintrag Schlüssel, Block (Buff / Boss / Nützliches), Klasse, Talent
  ja/nein, erlaubte Rollen, Reichweite (Raid oder Gruppe), Zauber-ID für Name und Symbol. Der Builder hält eine kurze
  Liste englischer Zaubernamen (wie `build_raidcheck.py`) und löst sie gegen `SpellName`, `SkillLineAbility`,
  `SkillRaceClassInfo` und die Talentbäume auf; die Klasse und "Talent" kommen aus den Tabellen, nicht aus der Liste.
  Ein Werkzeugtest wird rot, wenn ein Name keiner Klasse mehr gehört.
- **Neue Dateien** in der TOC (Rechnen im Raid-Teil, Daten im Ausrüstungs-Teil): nach dem Release einmal das Spiel ganz
  neu starten.
- Kein neuer `AmisiaDB`-Schlüssel, keine Einstellung, keine Nachricht, keine Exportzeile, nichts auf der Website.
- Keine Daten aus anderen Addons oder von Fanseiten (D-03, D-04).

## Offene Fragen

1. **Wer zählt?** Vorschlag: nur wer in einer Gruppe steht (Abschnitt E), ohne Eingeteilte alle Anmeldungen. Alternative:
   immer alle Anmeldungen.
2. **Umfang?** Vorschlag: alle drei Blöcke (Buffs, Auf dem Boss, Nützliches). Alternative: nur Buffs.
3. **Gruppen-Buffs je Gruppe?** Vorschlag: ja, als "Gr. 1, 3" in der Zeile; keine eigene Warnung je Gruppe (z. B. "Gruppe 4
   ohne Windzorn"). Alternative: nur "da / fehlt" für den ganzen Raid.

## Entscheidungen

- 2026-11-17: alle drei Fragen: "Passt, bauen" -> es zählt, wer in einer Gruppe steht (ohne Eingeteilte alle
  Anmeldungen); alle drei Blöcke (Buffs, Auf dem Boss, Nützliches); Gruppen-Buffs nennen ihre Gruppen ("Gr. 1, 3"),
  ohne eigene Warnung je Gruppe.
