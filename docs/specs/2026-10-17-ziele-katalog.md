# Spec: Ausrüstungsziele: Katalog mit Set-Kategorien und Itemsuche

Stand: 2026-10-17 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-123

## Ziel

Im Fenster "Ausrüstungsziele" sollen sich auch Items finden lassen, die nicht schon Ziel sind: nach
Set-Kategorien stöbern und alle Items durchsuchen (Wunsch des Nutzers 2026-10-17 mit zwei
Bildschirmfotos aus einem anderen Addon: eine Kategorienleiste "Raid Sets, Dungeon Sets, PvP Sets,
Crafted Sets, World Sets, Reputation, Mounts, Legendaries" und eine Suchzeile "Search all items..." mit
Stufenbereich "1 - 24", "My lvl", "All": "können wir die 2 sachen noch zu Ausrüstungsziele adden").
Gelöst, wenn man im Fenster ein Set oder Item findet, es am Modell anprobiert und als eigene Wahl setzt.

## Was es tut

- Neben "Ziele" und "Angelegt" ein dritter Umschalter **Katalog**. Das Modell links bleibt; Mitte und
  rechte Leiste zeigen dann den Katalog statt der Slotliste.
- **Kategorien** (links in der Mitte, Knöpfe im Stil der Seitenliste mit Symbol): Raid-Sets,
  Dungeon-Sets, PvP-Sets, Handwerks-Sets, Welt-Sets. Ein Set zählt zu der Kategorie, aus der seine Teile
  kommen (Quellen der Itemdaten: Raid, Dungeon, PvP-Händler, Handwerk, Weltdrop/Rar/Quest/Händler).
  Leere Kategorien grau (heute z. B. Raid-Sets, bis die Raids am 09.12. Daten bringen).
- Ein Klick auf eine Kategorie listet ihre Sets: Name, "N/M" (wie viele Teile du hast), Stufe, Boni
  im Tooltip. Ein Klick auf ein Set: seine Teile mit Slot, Zuwachs für dich (grün: Upgrade) und Quelle;
  "Set anprobieren" zieht alle Teile am Modell an.
- **Suchzeile** über der Liste: "Alle Items durchsuchen …", dazu Stufe von-bis (zwei Zahlenfelder),
  "Meine Stufe" (Bereich 1 bis deine Stufe: alles, was du jetzt tragen kannst) und "Alle" (1-60). Treffer: alle Items der Itemdaten,
  deren Name passt (Client-Name, Umlaute egal) und deren Stufe im Bereich liegt, nach Zuwachs für dich;
  ohne Suchtext die Items der gewählten Kategorie im Bereich.
- In jeder Liste wie gewohnt: Strg-Klick anprobieren, Shift-Klick in den Chat, Rechtsklick-Menü
  (eigene Wahl, Wunschliste, ausschließen), Klick auf die Quelle öffnet Dungeon/Raid/Karte.

## Was es ausdrücklich nicht tut

- **Ruf**: Amisia hat keine Daten, welcher Händler welchen Ruf verlangt. Erst wenn `export_db2.ps1` die
  Tabelle dafür auf dem PC mitnimmt (D-03, kein Netz-Download). Vorerst keine Kategorie.
- **Reittiere** und **Legendäres**: keine Ausrüstungsziele (im Bild ohnehin grau). Nicht dabei.
- Keine Items außerhalb der Itemdaten (was Amisia nicht kennt, findet die Suche nicht).
- Nichts wird gesendet; keine neuen Daten aus dem Netz.

## Abläufe

1. Ausrüstungsziele öffnen -> "Katalog". Zuerst die zuletzt gewählte Kategorie, sonst Dungeon-Sets.
2. Set anklicken -> Teile rechts; "Set anprobieren" -> Modell trägt das Set.
3. Rechtsklick auf ein Teil -> "Als meine Wahl" -> der Slot zeigt es unter "Ziele" mit Stern (D-55).
4. "Alle Items durchsuchen": "Wolfs" tippen -> Liste aller Items mit "Wolfs" im Bereich, bestes oben.
5. "Meine Stufe" setzt den Bereich, "Alle" auf 1-60; die Werte bleiben gespeichert.

## Abnahmekriterien

- Wenn du im Fenster Ausrüstungsziele "Katalog" klickst, dann stehen links Raid-Sets, Dungeon-Sets,
  PvP-Sets, Handwerks-Sets und Welt-Sets; leere grau.
- Wenn du Handwerks-Sets und dann "Devilsaur Armor" wählst, dann stehen beide Teile mit Slot, Zuwachs und
  Quelle da, und "Set anprobieren" zieht sie dem Modell an.
- Wenn du "Wolfs" in die Suche tippst und "Alle" klickst, dann listet Amisia jedes bekannte Item mit
  "Wolfs" im Namen, das beste für dich oben.
- Wenn du "Meine Stufe" klickst, dann steht im Bereich 1 bis deine Stufe und die Liste folgt.
- Wenn du ein Teil per Rechtsklick zur eigenen Wahl machst, dann zeigt "Ziele" es in seinem Slot mit
  Stern.

## Sonderfälle

- Englischer Client: Itemnamen vom Client; Suche nach Client-Name, sonst nach dem Namen der Daten.
- Items, deren Name der Client noch nicht geladen hat: Suche nach dem Datennamen, Liste aktualisiert sich,
  wenn der Name kommt.
- Kampf: nur Ansicht, nichts gesperrt. Große Treffermengen: höchstens 200 Treffer, Hinweis "mehr als 200,
  Suche eingrenzen".
- Keine Ausrüstungsdaten: der Umschalter Katalog fehlt.

## Missbrauch/Vertrauen

Nichts. Rein lokal, nichts gesendet oder empfangen.

## Daten

- Kein neuer `AmisiaDB`-Schlüssel; in `settings.goalWindow` neu `mode = catalog`, `cat` (Kategorie),
  `set` (Set-ID), `lo`, `hi` (Stufenbereich); der Suchtext wird nicht gespeichert (Frage 4).
- Keine Nachrichten, Exportzeilen, Einfügeblöcke.
- ARCHITECTURE: `UI/GoalsWindow.lua` (Katalog), Kategorien/Suche als Logik in `Gear/Bis.lua` oder einer
  neuen Datei `Gear/Catalog.lua` (dann TOC und Modulkarte).

## Offene Fragen

1. Platz: Katalog als dritter Umschalter im selben Fenster (Modell bleibt zum Anprobieren)? Vorschlag: ja.
2. Ruf, Reittiere, Legendäres weglassen (keine Daten bzw. keine Ausrüstung)? Vorschlag: ja; Ruf später,
   wenn du die Tabelle per `export_db2.ps1` lieferst.
3. "Meine Stufe" = 1 bis deine Stufe (wie im Bild "1 - 24"), also alles, was du jetzt tragen kannst? Vorschlag: ja.
4. Suchtext beim Schließen vergessen, Bereich und Kategorie merken? Vorschlag: ja.

## Entscheidungen

Noch keine.
