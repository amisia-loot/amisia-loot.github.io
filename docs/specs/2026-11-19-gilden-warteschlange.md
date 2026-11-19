# Spec: Gilden-Warteschlange für Schlachtfelder

Stand: 2026-11-19 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-227

## Ziel

Wer in der Warteschlange für ein Schlachtfeld steht, sieht, welche Gildenmitglieder gerade auch warten (nach
Schlachtfeld getrennt, mit Wartezeit), und wann deren Warteschlange aufgeht und sie beitreten oder ablehnen. So
weiß man, ob man zusammen in dasselbe Schlachtfeld kommen kann. Vorbild ist das Verhalten eines verbreiteten
Addons (Nutzer 2026-11-19: "so wie bei fojjicore"); eigener Code, eigene Nachrichten, Amisias Fensterstil.

## Was es tut

- **Fenster "Gilden-Warteschlange"**: erscheint von selbst, solange man selbst für ein Schlachtfeld ansteht, und
  geht zu, sobald man nicht mehr wartet oder im Schlachtfeld ist. Kopf mit der Zahl der Gildenmitglieder in einer
  Warteschlange, einklappbar, verschiebbar (Position wird gemerkt).
- **Je Schlachtfeld ein Balken** (das eigene zuerst, dann nach Zahl der Wartenden): Name, eigene Wartezeit
  ("4:12", mit der geschätzten Zeit des Spiels: "4:12 / ~6 min"). Darunter die Gildenmitglieder in Klassenfarbe:
  erst die, deren Warteschlange aufging, dann die am längsten Wartenden. Rechts: Wartezeit "m:ss", grün
  "Aufgegangen", "Beigetreten" (10 s), grau "Abgelehnt" (5 s).
- **Einstellungen** (Abschnitt "Gilden-Warteschlange"): "Eigene Warteschlange mit der Gilde teilen" (an),
  "Fenster zeigen" (an), "Nur wenn noch jemand aus der Gilde wartet" (aus), "Ton, wenn jemand aus der Gilde in
  meine Warteschlange kommt" (aus).
- `/amisia warteschlange` öffnet das Fenster auch ohne eigene Warteschlange (nur ansehen).

## Was es ausdrücklich nicht tut

- Kein gemeinsames Anmelden und kein Einladen in eine Gruppe (das ist Sache des Spiels).
- Keine Arenen und keine gewerteten Spiele (gibt es auf Forever nicht; ein solcher Eintrag wird übergangen).
- Nichts gespeichert über andere Spieler (nur im Speicher der Sitzung), kein Export, nichts auf der Website.
- Keine Nachricht im Schlachtfeld und keine Chatzeilen.

## Abläufe

1. Ich melde mich für Warsongschlucht an. Amisia liest die eigene Warteschlange (Ereignis
   `UPDATE_BATTLEFIELD_STATUS`, `GetBattlefieldStatus` je Platz, Wartezeit `GetBattlefieldTimeWaited`, geschätzt
   `GetBattlefieldEstimatedWaitTime`) und sagt der Gilde nach 2 s leise "ich warte auf Warsongschlucht seit 0 s".
2. Das Fenster geht auf. Andere Amisia-Nutzer der Gilde, die auch warten, haben es ebenso gesagt; sie stehen unter
   ihrem Schlachtfeld. Wer neu dazukommt, erscheint beim nächsten Wiederholen (alle 75 s schickt jeder Wartende
   seinen Stand noch einmal; wer 180 s nichts sagt oder offline geht, fällt heraus).
3. Bei Anna geht die Warteschlange auf: sie sagt es sofort ("aufgegangen, noch 90 s"); bei mir steht sie grün oben.
4. Anna klickt "Betreten": Amisia hängt sich an `AcceptBattlefieldPort` und sagt "beigetreten", noch bevor der
   Ladebildschirm kommt (im Schlachtfeld gehen keine Nachrichten). Bei mir steht 10 s "Beigetreten", dann ist sie weg.
   Lehnt sie ab oder läuft die Zeit ab: "Abgelehnt", 5 s.
5. Ich verlasse die Warteschlange: ich sage "warte nicht mehr", und das Fenster geht zu.

## Abnahmekriterien

- Wenn du dich für ein Schlachtfeld anmeldest, dann geht das Fenster "Gilden-Warteschlange" auf und zeigt das
  Schlachtfeld mit deiner Wartezeit, die jede Sekunde weiterzählt.
- Wenn ein Gildenmitglied mit Amisia für dasselbe Schlachtfeld wartet, dann steht es binnen 75 Sekunden unter dem
  Balken mit seiner Wartezeit (braucht: Gilde).
- Wenn bei ihm die Warteschlange aufgeht und es "Betreten" klickt, dann steht bei dir erst grün "Aufgegangen",
  dann 10 Sekunden "Beigetreten" (braucht: Gilde).
- Wenn du die Warteschlange verlässt oder das Schlachtfeld betrittst, dann geht das Fenster zu.
- Wenn du "Eigene Warteschlange mit der Gilde teilen" ausschaltest, dann sehen die anderen dich nicht mehr
  (spätestens nach 180 Sekunden), und du siehst sie weiter.

## Sonderfälle

- **Im Schlachtfeld**: Forever sperrt Addon-Nachrichten dort (so verhält sich das Vorbild); nichts wird gesendet,
  die Sendewarteschlange für diese Nachrichtenart verworfen, das Fenster ist zu. "Beigetreten" geht vor dem Laden.
- **Kampf und Kampfsperre**: nichts wird gesendet; der Stand geht nach dem Kampf (`PLAYER_REGEN_ENABLED`) bzw. wenn
  die Sperre endet. Ein Aufgehen im Kampf geht sofort danach.
- **Mehrere Warteschlangen** (bis zu drei Plätze): jede einzeln, höchstens 3 wartend und 2 aufgegangen je Spieler.
- **`/reload` während des Wartens**: die Wartezeit kommt vom Spiel, der Stand geht 2 s später neu hinaus; die
  anderen Gildenmitglieder sind bis zu ihrem nächsten Wiederholen nicht sichtbar.
- **Gruppe in der Warteschlange**: jeder mit Amisia meldet sich selbst; kein Unterschied.
- **Client auf Englisch und Deutsch**: das Schlachtfeld wird nicht als Name, sondern als Nummer der Client-Tabelle
  `BattlemasterList` geschickt (gefunden über den Namen in der Sprache des Clients), damit ein deutscher und ein
  englischer Client dasselbe Schlachtfeld meinen; ein unbekannter Name wird übergangen.
- **Ohne Gilde**: nichts wird gesendet, das Fenster zeigt nur die eigenen Warteschlangen.
- **TBC Anniversary und Era**: dieselben Schlachtfelder und Funktionen; läuft dort ebenso (Raid-Teil, D-57).

## Missbrauch/Vertrauen

- Nur über GUILD; der Absender muss nach dem Gildenroster ein Mitglied sein (`ns.TrustName`), sonst verworfen.
- Jedes Feld geprüft (Comm `VALID`): Schlachtfeld eine bekannte Nummer, Wartezeit 0 bis 86400, Restzeit 0 bis 600,
  höchstens 6 Einträge, Nachricht unter 120 Zeichen; Klasse aus dem Roster, nicht aus der Nachricht.
- Höchstens 60 Gildenmitglieder im Speicher; ein Absender höchstens eine Nachricht alle 10 s (die Wiederholung
  kommt alle 75 s, Änderungen sofort); eine Flut wird wie überall von Comm gedrosselt.
- Falsche Angaben eines Mitglieds über sich selbst sind möglich (man sieht nur, was es sagt); es kann niemand
  anderes eintragen, kein Einladen auslösen und nichts Gespeichertes ändern.

## Daten

- **Nachrichtenart `QW`** ("queue wait"), GUILD, nie beantwortet: `1`, dann bis zu 6 Einträge
  `<BattlemasterList-ID>:<Zustand>:<Sekunden>` mit Zustand `W` wartet (Sekunden gewartet), `P` aufgegangen
  (Sekunden bis zum Ablauf), `J` beigetreten, `L` abgelehnt; leer heißt "wartet nicht mehr". Abstand je Absender
  10 s; gesendet nach 2 s bei einer Änderung, sofort bei Aufgehen, Beitreten, Ablehnen, alle 75 s solange man wartet.
- **Einstellungsabschnitt** "Gilden-Warteschlange" (`bgqueue.share`, `bgqueue.window`, `bgqueue.onlyOthers`,
  `bgqueue.sound`) und die Fensterposition (`AmisiaDB.settings`); kein neuer Schlüssel sonst.
- **Erzeugte Daten**: die Schlachtfelder aus `BattlemasterList` (ID, englischer und deutscher Name) in einer kleinen
  Datendatei des Raid-Teils (läuft auch auf TBC und Era). Die Tabelle liegt noch nicht vor: sie kommt in die Liste
  von `tools/export_db2.ps1` und wird mit `python3 tools/build.py tables` von wago.tools geholt (D-101).
- Neue Datei `Amisia_Raid/Raid/GuildQueue.lua` mit dem Fenster.

## Offene Fragen

1. **Teilen an oder aus als Vorgabe?** Vorschlag: an (sonst sieht keiner etwas), mit dem Schalter in den
   Einstellungen; es geht nur an die eigene Gilde.
2. **Wo hängt es?** Vorschlag: im Raid-Teil (Gildenfunktionen, läuft auch auf TBC und Era), nicht im Teil
   "Ausrüstung & Dungeons".
3. **Ton**, wenn jemand in meine Warteschlange kommt: Vorschlag aus als Vorgabe.
4. **Gibt es auf Forever schon Schlachtfelder?** Wenn nicht, wird es erst dort sichtbar, wo es sie gibt (TBC
   Anniversary, Era); im Spiel zu prüfen.

## Entscheidungen
