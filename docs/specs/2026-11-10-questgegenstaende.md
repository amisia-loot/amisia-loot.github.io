# Spec: Questgegenstände aufräumen

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10: "Ja, so bauen") · Feature: F-173

Der Nutzer fragte am 2026-11-10: "Können wir das noch irgendwie so hinkriegen, so eine Funktion, Einstellung,
dass zum Beispiel, wenn man ein Quest abgeschlossen hat, aber die Questgegenstände noch im Inventar ist, dass
man die löschen kann? Kannst du das rausfinden, welche Items man nicht mehr braucht, dass man das irgendwie
rausfindet, ob man die Quest abgeschlossen hat und wirklich 100 % sicher ist, dass die Items gelöscht werden
können, damit das Inventar nicht voll ist mit Quest-Items, die man gar nicht mehr braucht?" Die Antwort war,
was sich sicher wissen lässt (das Spiel sagt je Charakter, ob eine Quest abgeschlossen ist und was im Log
steht; welche Quest ein Gegenstand braucht, sagt es nur für Startgegenstände und am Abgabefenster, sonst nur
die Daten), mit dem Vorschlag der drei Gruppen unten, gelöscht wird nur aus "sicher". Der Nutzer: "Ja, so
bauen". DECISIONS D-105.

## Ziel

Die Taschen füllen sich mit Questgegenständen abgeschlossener Quests. Amisia sagt je Gegenstand, ob er
sicher, wahrscheinlich oder unklar überflüssig ist, und löscht nur die sicheren auf einen Klick. Gelöst ist
es, wenn der Spieler die sicheren mit wenigen Klicks los ist und bei den anderen sieht, warum Amisia sie
nicht löscht.

## Was es tut

- **Fenster "Questgegenstände aufräumen"** (`/amisia questgegenstaende`, en `questitems`; auf der Seite
  Quests der Link "Aufräumen", mit der Zahl der sicheren: "Aufräumen (3)"): die Questgegenstände der Taschen
  (Gegenstandsklasse Quest, oder der Quest-Vermerk des Taschenplatzes; nie Ausrüstung, Schlüssel oder eine
  andere Klasse, auch wenn die Daten sie mit einer Quest verbinden; nie die Bank) in den Gruppen
  "Sicher überflüssig", "Wahrscheinlich überflüssig", "Unklar" und "Behalten", je Zeile Symbol, Name, Anzahl
  und der Grund in Worten: "startet die Quest ... (abgeschlossen)", "war Ziel der Quest ... (abgeschlossen),
  von Amisia gesehen", "laut Daten für ... (abgeschlossen)", "Quest ... nicht im Log", "keine Quest bekannt".
  Oben "N sicher · N wahrscheinlich · N unklar · N noch gebraucht" und der rote Knopf "Nächsten sicheren
  löschen (N)". Maus auf der Zeile: der Tooltip des Gegenstands; Rechtsklick: "Behalten" / "Nicht mehr
  behalten". Verschiebbar, Platz gemerkt, "Fensterposition zurücksetzen" setzt ihn zurück.
- **Löschen** nur in "sicher": "Löschen" in der Zeile fragt mit `W.Confirm` (Gegenstand, Anzahl des Stapels,
  "(1 von N Stapeln)", der Grund, "Gelöschte Questgegenstände lassen sich nicht zurückholen."); "Löschen" in
  der Frage löscht einen Stapel. Einstellung "Questgegenstände ohne Nachfrage löschen" (aus) überspringt die
  Frage.
- **Tooltip** eines Questgegenstands: eine Zeile "Quest: Name (abgeschlossen / im Log / nicht im Log)", in den
  ersten beiden Gruppen grün "wird nicht mehr gebraucht" oder gelb "wahrscheinlich nicht mehr gebraucht".
  Einstellung "Questgegenstände im Tooltip" (an), Abschnitt Quests.
- **Eigene Beobachtung**: am Abgabefenster (`QUEST_PROGRESS`) die verlangten Questgegenstände, im Questlog die
  Gegenstandsziele einer Quest, deren Name genau einem Gegenstand der Taschen gleicht: Amisia merkt sich
  "Gegenstand gehört zu Quest" (`AmisiaDB.questItems.links`). Der N100 sammelt das in
  `tools/quest_item_archive.json` und schreibt es als Art O in die Daten.
- **Daten** `Data/QuestItemData.lua` (`tools/build_questitems.py`, lazy `QUEST_ITEMS`): je Questgegenstand die
  Quests, S (startet sie, Client-Tabelle ItemSparse), O (eigene Beobachtung des Autors), D (AllTheThings).

## Was es ausdrücklich nicht tut

- Kein automatisches Löschen, kein Löschen aus "wahrscheinlich" oder "unklar", kein Verkaufen, nie die Bank.
- Nichts wird gesendet; gehörte Daten anderer Spieler gibt es hier nicht und sie machen nie etwas sicher.
- Keine eigene Liste "noch gebraucht" (nur die Zahl): was noch gebraucht wird, bleibt in Ruhe.

## Abläufe

1. Der Spieler öffnet das Fenster (Befehl oder "Aufräumen" auf der Seite Quests). Vor der ersten Antwort des
   Spiels nach dem Login ("Warte, bis das Spiel die abgeschlossenen Quests meldet ...") ist nichts sicher.
2. Er klickt "Löschen" bei einem sicheren Gegenstand, liest die Frage und klickt "Löschen": Amisia sucht den
   Platz, der den Gegenstand jetzt hält, nimmt ihn auf, prüft, dass die Maus genau diesen Gegenstand hält
   (`GetCursorInfo`), und löscht ihn (`DeleteCursorItem`). Die Zeile zeigt "wird gelöscht ...", bis die Tasche
   meldet, dass der Stapel weg ist ("Gelöscht: Name xN."); bleibt er, sagt der Chat es.
3. "Nächsten sicheren löschen" geht die sicheren der Reihe nach durch, ein Stapel je Klick, mit derselben Frage.
4. Lässt das Spiel das Löschen nicht zu (`ADDON_ACTION_FORBIDDEN`/`_BLOCKED` für Amisia), sagt der Chat
   einmal "Das Spiel lässt Addons keine Gegenstände löschen: zieh den Gegenstand selbst aus der Tasche und lass
   ihn fallen."; die Knöpfe verschwinden bis zum nächsten Login, die Gruppen bleiben als Hilfe.

## Abnahmekriterien

- Wenn du `/amisia questitems` eingibst, dann öffnet sich "Questgegenstände aufräumen" mit deinen
  Questgegenständen in Gruppen, jeder mit Grund; ein Schlüssel oder eine Rüstung steht nie darin.
- Wenn du die Maus auf einen Questgegenstand einer abgegebenen Quest hältst, dann steht im Tooltip
  "Quest: Name (abgeschlossen)" und grün "wird nicht mehr gebraucht" oder gelb "wahrscheinlich ...".
- Wenn du bei einem sicheren Gegenstand "Löschen" und in der Frage "Löschen" klickst, dann ist ein Stapel weg und
  der Chat sagt "Gelöscht: Name xN."; sagt er stattdessen "Das Spiel lässt Addons keine Gegenstände löschen",
  dann melde das (dann geht es nur von Hand).
- Wenn du eine Quest abgibst, deren Questgegenstand noch in der Tasche liegt (zu viele gesammelt), dann steht er
  nach einer Sekunde unter "Sicher überflüssig" mit "war Ziel der Quest ... von Amisia gesehen".
- Wenn du einen Gegenstand mit Rechtsklick "Behalten" markierst, dann steht er unter "Behalten" und wird nie
  mehr zum Löschen angeboten, auch nicht auf deinen Twinks; "Nicht mehr behalten" nimmt das zurück.

## Sonderfälle

- **Mehrere Stapel** desselben Gegenstands: eine Zeile mit der Summe und "N Stapel"; ein Klick löscht einen.
- **Gegenstand inzwischen weg** (verkauft, verschoben): "Der Gegenstand liegt nicht mehr in den Taschen.",
  nichts gelöscht; ein verschobener Stapel wird am neuen Platz gefunden.
- **Quest wird abgeschlossen, während das Fenster offen ist**: neu bewertet nach der Abgabe (1 s, der Vermerk des
  Spiels kann nachhängen) und bei jeder Taschenänderung; vor dem Löschen wird noch einmal geprüft.
- **Gegenstände mit Ladungen**: die Anzahl des Stapels (ein negativer Wert alter Clients zählt als Zahl).
- **Quest der anderen Fraktion oder Klasse** (laut Questdaten): betrifft den Charakter nicht ("wahrscheinlich"),
  macht aber nichts "sicher".
- **Wiederholbare Quest**: nie abgeschlossen (das Spiel vermerkt sie nicht; die Daten-Markierung R zählt auch).
- **Bank, Briefkasten, Händler, Handel oder Gildenbank offen**: kein Löschen ("Erst Bank, Briefkasten, Händler oder
  Handel schließen."); nur die Taschen 0 bis 4 zählen.
- **Kampf und Bosssperre** (geheime Werte): das Fenster zeigt "Im Kampf nicht verfügbar.", kein Löschen, keine
  Tooltip-Zeile; alles über `ns.Plain`.
- **Maus hält etwas**: kein Löschen; hält sie nach dem Aufnehmen nicht genau den Gegenstand: Maus leeren, eine
  Chatzeile, nichts gelöscht; ein gesperrter Platz wird übersprungen.
- **Charakter frisch eingeloggt**: kein "sicher", bevor das Spiel die Quests gemeldet hat (`QUEST_LOG_UPDATE`).
- **Englischer Client**: alle Texte über die Locale; der Abgleich der Questziele vergleicht Namen in der Sprache
  des Clients, die Zuordnung (Nummern) ist sprachfrei.
- **/reload, Twinks**: die eigenen Zuordnungen und "Behalten" gelten für den ganzen Account; ob eine Quest
  abgeschlossen ist, fragt Amisia je Charakter.

## Missbrauch/Vertrauen

- Keine Nachricht, nichts gesendet, nichts empfangen: niemand kann etwas als "sicher" markieren lassen.
- Sicher macht nur, was das Spiel selbst sagt (Startquest des Gegenstands, Abschluss je Charakter) oder was dieser
  Account selbst sah. Die Daten (AllTheThings, auch die Art O der Datei, die vom Konto des Autors stammt) reichen
  nur für "wahrscheinlich".
- Jede andere bekannte, nicht abgeschlossene Quest am Gegenstand verhindert "sicher".
- Löschen nur im Klick des Spielers, ein Stapel je Klick, Prüfung von Platz und Maus direkt davor; abgelehnt
  einmal = aus bis zum nächsten Login.

## Daten

- Neuer Schlüssel `AmisiaDB.questItems = { v = 1, links = { [Gegenstand] = "q1,q2" }, keep = { [Gegenstand] = true } }`:
  beim Laden nur ganze Nummern, höchstens 8 Quests je Gegenstand, die 2000 höchsten Gegenstände, 500 "Behalten".
- Einstellungen im Abschnitt `quests`: `quests.itemTooltip` (an), `quests.itemNoAsk` (aus). Fensterplatz
  `settings.questItemsWindow`.
- Neue Datei `Data/QuestItemData.lua` (`tools/build_questitems.py`, Schritt "quest items" von `build.py data`),
  Archiv `tools/quest_item_archive.json`. `tools/att_data.py` liefert je Quest `items`.
- Keine Nachrichtenart, keine Exportzeile, kein Einfügeblock.

## Offene Fragen

1. Lässt Forever ein Addon `DeleteCursorItem` im Klick aufrufen? Vorschlag: ausprobieren; die Ablehnung ist
   abgefangen (dann nur die Gruppen als Hilfe).
2. Liefert Forever `C_Container.GetContainerItemQuestInfo` (Startquest des Taschenplatzes)? Vorschlag: der Selbsttest
   nennt es; ohne bleibt die Client-Tabelle (Art S der Daten).

## Entscheidungen

- 2026-11-10: Vorschlag der drei Gruppen, Löschen nur aus "sicher": "Ja, so bauen".
- Annahme (nicht gefragt): eine Quest anderer Fraktion oder Klasse macht einen Gegenstand nicht "sicher", nur
  "wahrscheinlich" (die Daten könnten sich irren).
- Annahme (nicht gefragt): die eigenen Zuordnungen in der Datendatei (Art O) zählen bei anderen Spielern nur als
  Daten, weil sie vom Konto des Autors stammen.
- Annahme (nicht gefragt): vor dem Löschen sperren auch Bank, Briefkasten, Händler, Handel und Gildenbank.
- Annahme (nicht gefragt): der Befehl heißt `questgegenstaende` (en `questitems`), wie `uebergabe` ohne Umlaut.
- Annahme (nicht gefragt): "Nächsten sicheren löschen" fragt wie die Zeile (ohne Frage nur mit der Einstellung).
