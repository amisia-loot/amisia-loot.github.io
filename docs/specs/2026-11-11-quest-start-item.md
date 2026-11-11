# Spec: Fenster bei Gegenständen, die eine Quest starten

Stand: 2026-11-11 · Status: freigegeben (Nutzer 2026-11-11: "wenn ich ein item loote das ne q startet mir angezeigt wird", nach einem Bildschirmfoto) ·
Feature: F-181

## Ziel

Ein Gegenstand, der eine Quest startet, geht in vollen Taschen leicht unter. Amisia zeigt ihn, sobald er in den
Taschen landet, in einem kleinen Fenster; ein Klick auf sein Symbol öffnet die Quest. Gelöst ist es, wenn man
nach dem Plündern einer solchen Zeichnung das Fenster sieht und die Quest mit einem Klick annehmen kann.

## Was es tut

- **Fenster** (`AmisiaQuestStart`, 260 breit, Amisias Fenster `W.Window`, Maße `T.QUESTSTART`): im Titel der Name
  des Gegenstands (mehrere wartend: "Einfache Zeichnung (1 von 2)"), rechts das x; in der Mitte sein Symbol im
  abgerundeten Ring der Planer-Plätze in der Farbe seiner Qualität, unten rechts am Symbol das gelbe "!" des
  Gesprächsfensters (wie die Geber-Pins von F-179); darunter grau eine Zeile "Klick auf das Symbol startet die
  Quest.". Die Maus auf dem Symbol zeigt den Tooltip des Gegenstands und "Startet die Quest: <Titel>".
- **Klick:** ein sicherer Knopf des Spiels (`SecureActionButtonTemplate`, Art "item", Gegenstand "item:<id>")
  liegt über dem Symbol; der Klick benutzt den Gegenstand, das Questfenster des Spiels öffnet sich.
- **Wann:** ein Gegenstand kommt in die Taschen 0 bis 4 (geplündert, gehandelt, Post, gekauft), er startet eine
  Quest, und die Quest ist weder im Log noch abgeschlossen. Nach dem Login oder `/reload` zeigt Amisia die schon
  liegenden einmal, 5 Sekunden später und erst, wenn das Spiel das Questlog gemeldet hat, höchstens drei.
- **Einstellung** `quests.startPopup` ("Fenster bei Gegenständen, die eine Quest starten", an) im Abschnitt Quests.
- `/amisia selbsttest gruppe` nennt die Client-Funktionen ("Quest-Startgegenstände").

## Was es ausdrücklich nicht tut

- Keine Bilder, Texturen oder Code des anderen Addons; nur die Idee und die Anordnung.
- Kein Raten aus Name oder Tooltip-Farbe des Gegenstands; keine Bank, kein Angelegtes.
- Nichts im Kampf öffnen, schließen oder verschieben; kein Escape zum Schließen (siehe Entscheidungen).
- Kein Merken über den Login hinaus, kein "nie mehr zeigen" je Gegenstand (der Schalter schaltet alles ab).
- Kein Senden, keine Nachricht, kein gespeicherter Schlüssel außer dem Platz.

## Abläufe

1. Der Spieler plündert "Einfache Zeichnung". Nach der Taschenmeldung (`BAG_UPDATE_DELAYED`, höchstens alle
   0,5 s gelesen) fragt Amisia den Quest-Vermerk jedes Taschenplatzes; die Zeichnung startet eine offene Quest,
   das Fenster öffnet sich.
2. Klick auf das Symbol: das Spiel benutzt den Gegenstand, das Questfenster erscheint; nimmt er an
   (`QUEST_ACCEPTED`), schließt Amisias Fenster, ein weiterer wartender Gegenstand folgt.
3. Das x schließt; der Gegenstand kommt in dieser Sitzung nicht wieder, auch nicht nach weiteren Taschenmeldungen.
4. Verlässt der Gegenstand die Taschen (nicht nur auf der Maus beim Verschieben), schließt das Fenster.
5. Im Kampf: ein neuer Gegenstand wartet bis `PLAYER_REGEN_ENABLED`. Ist das Fenster schon offen, bleibt es, wie
   es ist (der Klick geht weiter); das x, eine angenommene Quest oder ein weggegangener Gegenstand ändern nur die
   Zeile in "Schließt nach dem Kampf."; danach schließt es oder zeigt den nächsten.

## Abnahmekriterien

- Wenn du einen Gegenstand plünderst, der eine Quest startet, die du nicht hast und nicht gemacht hast, dann
  öffnet sich mitten im Bild ein kleines Fenster mit seinem Namen, seinem Symbol mit gelbem "!" und "Klick auf das
  Symbol startet die Quest."
- Wenn du auf das Symbol klickst, dann öffnet sich das Questfenster; nimmst du an, schließt Amisias Fenster.
- Wenn du das Fenster mit dem x schließt und danach Taschen umräumst oder plünderst, dann kommt es für diesen
  Gegenstand nicht wieder; nach `/reload` erscheint es einmal wieder, solange die Quest offen ist.
- Wenn du so einen Gegenstand im Kampf plünderst, dann erscheint das Fenster erst nach dem Kampf; beginnt ein
  Kampf bei offenem Fenster, dann bleibt es stehen, ohne Fehlermeldung "Aktion blockiert".
- Wenn "Fenster bei Gegenständen, die eine Quest starten" (Einstellungen, Quests) aus ist, dann erscheint nichts.

## Sonderfälle

- **Bosskampf, Kampfsperre:** nicht geöffnet und die Taschen nicht gelesen (Werte können geheim sein); es wartet
  bis `ENCOUNTER_END`, `ADDON_RESTRICTION_STATE_CHANGED` oder `PLAYER_REGEN_ENABLED`.
- **Schutz:** das Fenster hält den sicheren Knopf und ist dadurch selbst geschützt: im Kampf kann ein Addon es
  weder zeigen noch verstecken noch verschieben. Darum nichts davon im Kampf (siehe D-113).
- **Client ohne Quest-Vermerk** (Funktion fehlt oder antwortet nicht): eigene Daten entscheiden (Art S von
  `QuestItemData.lua`, Startgegenstände von `DungeonQuestData.lua`). Sagt der Client etwas, gilt nur er.
- **Client ohne `SecureActionButtonTemplate` oder Ablehnung** (`ADDON_ACTION_FORBIDDEN`/`_BLOCKED` für Amisia nach
  einem Klick): das Fenster informiert nur: "Rechtsklick auf den Gegenstand in der Tasche startet die Quest
  (Tasche 2, Platz 3)."
- **Vor der Antwort des Questlogs** gilt nichts als abgeschlossen: Amisia wartet darauf, bevor es entscheidet.
- **Viele auf einmal:** eine Schlange, höchstens zehn; beim Login höchstens drei, die übrigen gelten als gesehen.
- **Wiederholbare Quest:** gilt nie als abgeschlossen, das Fenster kommt also bei jedem neuen Gegenstand.
- **Englischer Client:** alle Texte in `enUS_world.lua`.

## Missbrauch/Vertrauen

Nichts: keine Nachricht, nichts von anderen Spielern. Der Knopf benutzt nur den Gegenstand mit genau dieser
Nummer (nicht einen Taschenplatz, der inzwischen etwas anderes halten könnte).

## Daten

- Einstellung `quests.startPopup` (an) im Abschnitt `quests`.
- Platz des Fensters `AmisiaDB.settings.questStartWindow = {point, x, y}` (zurückgesetzt mit den anderen
  Fenstern).
- Keine Nachrichtenart, keine Exportzeile, kein Einfügeblock, nichts auf der Website.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-11: Nutzer: "können wir das auch so machen ... wenn ich ein item loote das ne q startet mir angezeigt
  wird" -> gebaut wie oben, D-113.
- Annahme (nicht gefragt): nach dem Login oder `/reload` einmal die schon liegenden, 5 Sekunden später, höchstens drei.
- Annahme (nicht gefragt): ein geschlossener Gegenstand kommt nur nach Login oder `/reload` wieder (nur im Speicher);
  kein "nie mehr zeigen" je Gegenstand.
- Annahme (nicht gefragt): Escape schließt nicht (ein geschützter Rahmen in `UISpecialFrames` würde im Kampf blockiert).
- Annahme (nicht gefragt): an von Haus aus; der Platz mitten im Bild, etwas oberhalb der Mitte.
- Annahme (nicht gefragt): der Gegenstand per Nummer ("item:<id>"), nicht per Taschenplatz.
