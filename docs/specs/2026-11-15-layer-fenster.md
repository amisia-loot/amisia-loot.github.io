# Spec: Fenster Layer mit einem Wechsel-Knopf und Helfen an/aus

Stand: 2026-11-15 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-214

## Ziel

Nutzer 2026-11-15 zu einem Bild eines anderen Layer-Addons: "können wir das genauso machen wie <das andere> oder
besser", gewählt: "Nur Fenster (A)". Das Fenster Layer (F-185, F-191, F-204) kann schon alles, was dort zu sehen
ist, verteilt es aber auf drei Links und fünf Einstellungen. Gelöst ist es, wenn ein Klick auf "Layer wechseln" den
Wechsel anstößt, ein Klick auf "Helfen" das Helfen für andere an- und ausschaltet und das Fenster zeigt, was dabei
geschah.

## Was es tut

Das Fenster von oben nach unten (Größen, Schriften, Farben aus `T.LAYER`, rote Knöpfe als Chips):

- **"Dein Layer"** (Überschrift), groß "Layer A" (sonst "unbekannt"), grau darunter die Zonen-Kennung und die Zone:
  "Kennung 105 · Un'Goro-Krater" (ohne Layer wie bisher "Ziele oder überfahre einen NPC."). Die Kennung ist die Zahl
  aus den Kreatur-GUIDs, mit der zwei Spieler ihre Layer vergleichen können, auch wenn ihre Buchstaben abweichen.
- **"Gesehen in dieser Zone"** wie bisher. Neu: eine Zeile eines anderen Layers ist anklickbar (Hervorhebung beim
  Überfahren, Tooltip "Klick: die Gilde fragen, wer auf Layer C ist, und dorthin wechseln"). Der Klick tut dasselbe wie
  "Layer wechseln", nimmt aber nur eine Antwort von genau diesem Layer.
- **Zwei Zeilen mit Symbol** (Spielgrafik, keine Zauber- oder Gegenstandssymbole): "Im Gildenchat fragen", grau
  darunter "Der Gildenchat erreicht jeden Layer."; "Im Kanal fragen", grau darunter "Erreicht alle Spieler der Zone,
  mit und ohne Addon." Ein Klick auf die Zeile tut, was die beiden Links bisher tun (Chatzeile öffnen, eine Minute
  lang die Einladung annehmen).
- **Zwei rote Knöpfe nebeneinander: "Layer wechseln" und "Helfen: AN" / "Helfen: AUS".**
  - "Layer wechseln": in einer Gilde fragt er die Gilde (wie "Gilde fragen"). Kommt binnen 10 Sekunden eine Antwort,
    bittet Amisia von selbst um die Einladung, und zwar bei einem Layer, den du in dieser Zone noch nicht gesehen hast
    (in der Liste "neu"), sonst bei der ersten Antwort. Die übrigen Antworten bleiben darunter mit "Einladung
    erbitten" stehen, solange nichts läuft. Kommt keine Antwort, heißt der Knopf "Im Kanal fragen" und öffnet beim
    nächsten Klick die Chatzeile des Kanals. Ohne Gilde öffnet schon der erste Klick die Chatzeile des Kanals.
    Während Amisia wartet, heißt er "Warte ..." und ist grau.
  - "Helfen": ein Schalter über alles, womit Amisia anderen hilft: Antworten an die Gilde (`layer.answer`),
    Chat-Bitten aus der Gilde (`layer.chat`) und von Fremden (`layer.others`), Fragen und Einladungen. AUS: Amisia
    antwortet niemandem, fragt nichts und lädt niemanden ein. Die Einstellungen sagen weiter, wem und ob mit Frage;
    AN schaltet nichts ein, was dort aus ist. Nach jedem Login ist er AN.
- **Grau darunter:** bei AN "Helfen an: Amisia lädt Fragende ein, wie unter Einstellungen, Gilde, Layer eingestellt.
  Aus gilt bis zum Ausloggen.", bei AUS "Helfen aus: Amisia antwortet niemandem und lädt niemanden ein, bis du es
  wieder anschaltest oder dich neu einloggst."
- **Grün darunter, sobald etwas geschah:** "Geholfen: 3 haben gefragt, 2 eingeladen, 1 gekommen." (diese Sitzung).
- Darunter wie bisher die Statuszeile des eigenen Wechsels, die Antworten und "Gruppe verlassen".
- **Die Leiste (F-204):** die graue Zeile zeigt, solange ein eigener Wechsel läuft, dessen Stand kurz ("Gefragt ...",
  "Antworten: 2", "Einladung kam", "Gewechselt"), sonst die Zone, bei AN mit grünem " · Helfen" dahinter.
  Rechtsklick auf die Leiste: ein kleines Menü "Layer wechseln", "Helfen an/aus", "Fenster öffnen".
- Der Link "Gilde fragen" und die zwei Chat-Links verschwinden (ihr Tun steckt im Knopf und in den zwei Zeilen).
  `/amisia layer` bleibt.

## Was es ausdrücklich nicht tut

- Keine neuen Addon-Nachrichten und keine Wege zu Fremden außer der Chat-Zeile (das war Teil B und ist zurückgestellt).
  Die versteckten Nachrichten eines anderen Layer-Addons spricht Amisia weiter nicht (D-04, D-124).
- Amisia öffnet die Chatzeile nie von selbst, nur nach einem Klick: eine Chatzeile, die mitten im Laufen aufgeht,
  schluckt die Tastatur.
- Kein Countdown zu einem Neustart der Welt und keine Layer-Nummern anderer Addons ("inv layer 1,3" bleibt ohne Zahl).
- "Helfen" ersetzt keine Einstellung und wird nicht gespeichert.
- Kein eigener Knopf "Mini-Leiste: AN" wie im Bild: das rote "-" (F-204) bleibt.

## Abläufe

1. Allein in einer belebten Zone, Layer A bekannt: "Layer wechseln" klicken. Ein Gildenmitglied auf Layer C
   antwortet, Amisia bittet es um die Einladung, es lädt ein (oder wird gefragt), Amisia nimmt an, nach einem
   angezielten NPC steht "Gewechselt: Layer C".
2. Niemand antwortet: nach 10 Sekunden heißt der Knopf "Im Kanal fragen"; Klick, Enter, ein Spieler lädt ein, Amisia
   nimmt an.
3. Gezielt: unter "Gesehen in dieser Zone" auf "Layer B · vor 12 Min." klicken; nur eine Antwort von Layer B zählt,
   sonst "Niemand aus der Gilde auf Layer B."
4. Helfen: der Spieler will in Ruhe questen und klickt "Helfen: AN"; der Knopf zeigt "Helfen: AUS", Bitten aus Gilde
   und Kanal bleiben unbeantwortet, bis er wieder klickt oder sich neu einloggt.
5. Als Helfer: eine Bitte kommt, Amisia fragt oder lädt ein; die grüne Zeile zählt mit.

## Abnahmekriterien

- Wenn du allein in einer Gilde "Layer wechseln" klickst und ein Gildenmitglied in derselben Zone auf einem anderen
  Layer ist, dann bittet Amisia es ohne weiteren Klick um die Einladung, nimmt sie an, und nach einem angezielten NPC
  steht "Gewechselt: Layer C" (braucht: Gilde).
- Wenn binnen 10 Sekunden keine Antwort kommt, dann heißt der Knopf "Im Kanal fragen", und ein Klick öffnet die
  Chatzeile mit "/1 inv layer".
- Wenn du "Helfen: AN" klickst und ein Gildenmitglied dich danach um einen Wechsel bittet (Knopf oder "inv layer" im
  Gildenchat), dann passiert bei dir nichts und der Knopf zeigt "Helfen: AUS"; nach `/reload` oder neuem Login ist er
  wieder AN (braucht: Gilde).
- Wenn du als Helfer jemanden einlädst und er beitritt, dann steht grün "Geholfen: 1 haben gefragt, 1 eingeladen, 1
  gekommen." (braucht: Gruppe).
- Wenn du einen Layer kennst, dann steht unter "Layer A" grau "Kennung <Zahl> · <Zone>"; ein Klick auf eine Zeile eines
  anderen Layers fragt nur nach diesem.

## Sonderfälle

- Im Kampf: "Layer wechseln" fragt, eingeladen wird wie bisher erst danach; in Instanzen gibt es das Fenster nicht.
- In einer Gruppe: "Layer wechseln" sagt den Grund wie "Gilde fragen" bisher ("nur allein").
- `/reload` während des Wartens: die Frage ist weg, der Knopf heißt wieder "Layer wechseln"; die Zähler beginnen bei 0.
- Helfen AUS während einer offenen Frage an dich ("... Einladen?"): die Frage schließt sich, nichts wird eingeladen.
- Eigener Wechsel läuft: Amisia hilft niemandem (wie bisher, wer fragt, hostet nicht), egal wie "Helfen" steht.
- Ein Layer, den nur die Gilde gemeldet hat ("Gilde"), ist anklickbar wie ein selbst gesehener.
- Englischer Client: alle neuen Texte in `Locales/enUS_*.lua` des Gear-Ordners.
- Die Zahl der Kennung kann sehr lang sein: die Zeile kürzt die Zone, nie die Zahl.

## Missbrauch/Vertrauen

- Die automatische Bitte um Einladung geht nur an eine Antwort (YA) aus der Gilde, die zur eigenen Frage gehört; es
  zählt der Absender, den der Server setzt (wie in D-117). Wer viele Antworten schickt, bekommt höchstens eine Bitte
  (`REQUEST_GAP`).
- Helfen AUS ist der schnelle Ausweg gegen viele Bitten aus dem Kanal; die Grenzen der Einladungen (sechs in zehn
  Minuten, derselbe Spieler einmal pro Minute) bleiben.
- Die Zähler leben nur in der Sitzung und gehen nirgends hin.

## Daten

- Kein neuer `AmisiaDB`-Schlüssel, keine neue Einstellung, keine Nachricht. "Helfen" lebt in der Sitzung
  (`SW.Hosting()`/`SW.SetHosting(on)`, Ereignis `LAYER_CHANGE`).
- Zähler in `Gear/LayerChange.lua` je Sitzung: Bitten, die das Helfen erreicht haben (YI und Chat-Bitten, die durch
  die Filter kamen), gesendete Einladungen, Beigetretene (aus `SW.Trace`).
- DECISIONS: neuer Eintrag "Layer: ein Wechsel-Knopf, Helfen als Schalter der Sitzung" (ergänzt D-117, D-124).
  ARCHITECTURE: die Beschreibung des Fensters Layer.

## Offene Fragen

1. "Helfen: AUS" gilt bis zum Ausloggen (wie im Bild) oder bleibt gespeichert? Vorschlag: bis zum Ausloggen, damit
   niemand das Helfen für immer vergisst.
2. Nimmt "Layer wechseln" von selbst die erste passende Antwort, oder zeigt es erst die Liste? Vorschlag: von selbst,
   ein neuer Layer zuerst; die anderen Antworten bleiben zum Wählen stehen.
3. Nach 10 Sekunden ohne Antwort: Knopf wird "Im Kanal fragen" (zweiter Klick) oder die Chatzeile geht von selbst auf?
   Vorschlag: zweiter Klick (siehe "nicht").
4. Wort auf dem Knopf: "Helfen" oder "Host"? Vorschlag: "Helfen", weil das Addon sonst deutsch spricht.

## Entscheidungen

Noch keine.
