# Spec: Quest-Journal eines Dungeons

Stand: 2026-11-06 · Status: freigegeben (der Nutzer: "schau dir das an und mach es besser", mit einem
Bild eines anderen Dungeon-Journals) · Feature: F-138

## Ziel

Der Questweg (F-135) zeigte immer nur eine Quest auf der ganzen Seite; wer die nächste Quest des
Dungeons sehen wollte, musste zurück in die Tabelle mit fünf Zeilen. Das Journal zeigt alle Quests eines
Dungeons links und die gewählte rechts, aufgeräumt wie ein Journal: Zustand, nächster Schritt,
Belohnungen mit Symbol und Upgrade-Wert, EP und der Questweg. Gelöst ist es, wenn man alle Quests eines
Dungeons durchklicken kann, ohne die Ansicht zu verlassen.

## Was es tut

- Ein Klick auf eine Quest der Seite Dungeons (Teil "Quests"), "Questweg zeigen" eines Karten-Pins und
  `ns.ShowDungeonQuest` öffnen das Journal des Dungeons mit dieser Quest gewählt (statt nur ihres Questwegs).
- Kopfzeile: "< Zurück zu den Dungeons" links, "Nächsten Schritt auf der Karte" rechts (wie bisher).
- Darunter das Bild des Dungeons (wie im Planer) mit Name, "Level 15-20 · leicht" und
  "6 Quests, 4 offen · EP: 12.300" sowie dem Bossmodell.
- Links die Quests als Karten mit zwei Zeilen: das Zustandssymbol wie im Spiel (F-134), der Titel (grau,
  wenn erledigt oder nicht mehr möglich), rechts oben der Zustand als Wort in Farbe ("im Log" gelb,
  "im Log, fertig" grün, "erledigt"/"nicht mehr möglich" grau); in der zweiten Zeile die Stufe in den
  Farben des Questlogs, "Weg 2/4", das Dungeon-Symbol bei einem Start im Dungeon und rechts der
  Upgrade-Wert in Grün. Die gewählte Quest ist hervorgehoben; der Tooltip wie bisher.
- Rechts die gewählte Quest: Zustandssymbol und Titel groß, darunter Stufe, Zustand und Fortschritt; dann
  scrollend:
  - "Nächster Schritt: ..." in einem hervorgehobenen Kasten (fehlt, wenn alles erledigt ist);
  - "Belohnung:" als Kacheln, zwei je Zeile: Item-Symbol im Rahmen der Qualität, Name mit den Markierungen,
    darunter Platz und Zuwachs ("Brust · +15"); Tooltip, Strg-Klick Anprobe, Shift-Klick Chat wie überall;
  - "EP: 3.450 · laut Questlog" (oder "EP: noch nicht gesehen");
  - "Questweg:" mit den Schrittkarten von F-135. Die Felder (Annehmen, Abgeben, Voraussetzung, Ziel,
    Fundorte) stehen jetzt über ihrem Text statt links daneben, damit die schmale Spalte nicht bricht;
    erledigte Schritte sind auf ihre Kopfzeile eingeklappt.
- Fußzeile: was Klick, Strg-Klick und "Karte" tun.

## Was es ausdrücklich nicht tut

- Kein Umschalter Allianz/Horde: der Planer gilt dem eigenen Charakter; Quests der anderen Fraktion
  bleiben weg (wie bisher).
- Kein Knopf "Teilen": Quests teilen geht im Spiel über das Questlog; Amisia öffnet keine Fenster des
  Spiels (D-64).
- Keine Bosse im Journal; der Teil "Bosse" bleibt im Planer.
- Nichts Neues gespeichert: die gewählte Quest lebt nur im Speicher (nach `/reload` zeigt der Planer).

## Abläufe

1. Seite Dungeons, Dungeon wählen, "Quests", eine Quest anklicken: das Journal öffnet sich mit ihr.
2. Links eine andere Quest anklicken: rechts steht sie, die Liste bleibt.
3. "< Zurück zu den Dungeons", der Teil "Bosse" oder ein anderer Dungeon: der Planer wie zuvor.

## Abnahmekriterien

- Wenn du auf der Seite Dungeons bei "Quests" eine Quest anklickst, dann stehen links alle Quests des
  Dungeons (die angeklickte hervorgehoben) und rechts ihr Titel, "Nächster Schritt", die Belohnungen als
  Kacheln mit Symbol, die EP und ihr Questweg.
- Wenn du links eine andere Quest anklickst, dann wechselt nur die rechte Seite.
- Wenn eine Belohnung ein Upgrade ist, dann steht in ihrer Kachel und in der Zeile der Quest links der
  Zuwachs in Grün.
- Wenn ein Schritt des Questwegs erledigt ist, dann zeigt seine Karte nur noch die Kopfzeile mit Haken.
- Wenn du "< Zurück zu den Dungeons" klickst, dann siehst du wieder die Dungeon-Liste mit den Quests.

## Sonderfälle

In Instanzen und im Kampf öffnet "Karte" die Weltkarte nicht (D-62, wie bisher). Englischer Client: alle
neuen Texte in `Locales/enUS_gear.lua`. Ein Dungeon ohne Quests öffnet kein Journal (keine Zeile zum
Anklicken). Verschwindet die gewählte Quest (Daten, Fraktion), zeigt das Journal die erste.

## Missbrauch/Vertrauen

Nichts. Nur eigene Daten, nichts wird gesendet.

## Daten

Nichts. Keine neuen Schlüssel; Layout-Werte in `T.DJOURNAL` (UI/Theme.lua).

## Offene Fragen

Nichts.

## Entscheidungen

- Felder der Schrittkarten über dem Text statt daneben (schmale Spalte).
- Erledigte Schritte eingeklappt.
