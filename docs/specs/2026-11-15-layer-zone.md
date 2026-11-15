# Spec: Layer-Wechsel mit allen Amisia-Nutzern der Zone

Stand: 2026-11-15 · Status: freigegeben ·
Feature: F-216

## Ziel

Nutzer 2026-11-15, nach 2.93.0 (F-214): "layer soll genau so gehen wie das addon <ein anderes Layer-Addon> oder
besser". Gelesen: dessen Projektseite (Stand 1.14.25, nur die Beschreibung, kein Code, Notiz in `~/addons/_research`).
Der große Unterschied: dort erreicht "Layer wechseln" auf Forever alle Nutzer des Addons in der Zone, nicht nur die
Gilde, unsichtbar und ohne Chat; jeder, der es hört, antwortet; Helfen ist ab Login an und lädt ohne Frage ein; nach
dem Wechsel verlässt es die Gruppe nach ein paar Sekunden. Gelöst ist es, wenn ein Klick auf "Layer wechseln" auch
ohne Gilde einen anderen Layer bringt, sobald in der Zone ein anderer Amisia-Nutzer auf einem anderen Layer steht.

Ehrliche Grenze: die Nutzer des anderen Addons erreicht Amisia so nicht (seine versteckten Nachrichten kennt nur sein
Code, D-04). Mit ihnen geht weiter nur die Chat-Zeile "inv layer" (F-191).

## Was es tut

**Teil 1, die Zone fragen (Forever).** "Layer wechseln" fragt wie bisher die Gilde und zusätzlich die Zone:
- Jeder Klick stellt eine `/who`-Abfrage (das Spiel erlaubt sie nur nach einem Tastendruck oder Klick, eine pro
  Klick): beim ersten Klick die ganze Zone, bei jedem weiteren Klick eine Klasse der Zone (die Liste des Spiels hat
  höchstens 50 Namen). Das Fenster "Wer" des Spiels öffnet sich dabei nicht, nichts steht im Chat.
- An jeden gefundenen Namen außerhalb der Gilde geht leise die Frage `ZQ` (Zone, eigener Layer, Frage-Id), zuerst an
  Spieler, die in den letzten 7 Tagen als Amisia-Nutzer geantwortet haben; wer in den letzten 6 Stunden gefragt wurde
  und nicht antwortete, nicht noch einmal. Höchstens 50 Fragen je Klick, gedrosselt wie alle Addon-Nachrichten.
- Jeder Amisia-Nutzer, der die Frage hört, antwortet leise mit `ZA` (sein Layer in dieser Zone oder "unbekannt", ob
  er hilft), auch wenn er nicht hilft. Das Fenster zeigt dann "Erreicht: 23 · gehört: 3 · auf anderem Layer: 1" und
  ob ein weiterer Klick neue Spieler erreicht ("Weiter fragen: Krieger").
- Die Wahl bleibt die von F-214: nach der ersten passenden Antwort (Gilde oder Zone) bittet Amisia von selbst um die
  Einladung (`YI`, jetzt auch an einen Fremden, der geantwortet hat). Ein Host lädt ein, nicht mehrere: das verhindert
  doppelte Einladungen ohne Absprache zwischen den Hosts.
- Ein zweiter Klick, während Amisia wartet, fragt weiter (die nächste Klasse); "Stopp" (Rechtsklick-Menü, Befehl)
  beendet die Suche.

**Teil 2, Helfen wie dort.**
- Helfen ist ab Login an (schon so) und lädt eine Bitte über Amisia ohne Frage ein (neu: Voreinstellung "Ohne Frage
  einladen" an); Chat-Bitten von Fremden fragen weiter. Nur Bitten aus der eigenen Zone; nie in Instanzen; höchstens
  sechs Einladungen in zehn Minuten (dann nennt das Fenster die Pause); derselbe Spieler einmal pro Minute; nur allein
  oder als Leiter einer Gruppe, die Amisia für Wechsel gefüllt hat; nicht, während man in der Gruppensuche steht.
- Neu: "Helfen im Kampf pausieren" (aus). Die Gruppe für einen Wechsel bekommt "Jeder gegen jeden" als Beute.
- Helfen aus entfernt die Spieler, die Amisia für Wechsel eingeladen hat, aus der Gruppe (`/amisia layer kick` auch).

**Teil 3, nach dem Wechsel.**
- "Gruppe nach dem Wechsel verlassen" ist voreingestellt an, nach 5 Sekunden statt 30 (der Layer bleibt auf Forever).
- Hat der Host nicht bewegt (die Kreaturen zeigen nach frühestens 15 Sekunden noch den alten Layer), verlässt Amisia
  die Gruppe von selbst und das Fenster bietet "Layer wechseln" wieder an.

**Teil 4, Leiste und Befehle.**
- Leiste: das Symbol gold beim Helfen, grau bei Helfen aus, grün während einer eigenen Suche; in einem Dungeon der Name
  des Orts statt verschwinden; Rechtsklick aufs Symbol: die bekannten Layer zum gezielten Wechsel.
- `/amisia layer swap` (jeder andere Layer), `/amisia layer swap B`, `/amisia layer swap neu` (nur Layer, die in der
  letzten Stunde in dieser Zone niemand gesehen hat), `/amisia layer gilde`, `/amisia layer stopp`,
  `/amisia layer helfen`, `/amisia layer kick`.
- Neu: "Nur neue Layer" (aus): "Layer wechseln" nimmt nur Antworten von solchen Layern.

**Teil 5, der Selbsttest** prüft vorher im Client: `/who` aus einem Klick (Zahl der Namen), ob das Fenster "Wer"
aufgeht, eine leise Nachricht an einen Fremden (geht sie raus, kommt eine Fehlerzeile).

## Was es ausdrücklich nicht tut

- Keine Nachrichten des anderen Addons sprechen oder nachbauen; keine Chatzeile in Allgemein von selbst.
- Kein `/who` ohne Klick (das Spiel sperrt es; ein Timer würde blockiert).
- Keine Countdown-Anzeige für einen Neustart der Welt: wie das andere Addon davon erfährt, steht nirgends. Später,
  wenn der Selbsttest eine Systemzeile dafür findet.
- Kein "Abstand zu Fragenden überspringen" in diesem Schritt (braucht die Kartenposition in der Frage; später möglich).
- Keine gespeicherten Namen außer der Liste "hat geantwortet" (7 Tage, höchstens 200) und "gefragt ohne Antwort" (nur
  in der Sitzung).

## Abläufe

1. Ohne Gilde, Un'Goro-Krater, Layer A bekannt: "Layer wechseln". `/who` findet 31 Spieler, 31 leise Fragen gehen raus;
   zwei Amisia-Nutzer antworten, einer auf Layer B mit Helfen an. Amisia bittet ihn, er lädt ohne Frage ein, Amisia
   nimmt an, ein NPC zeigt Layer B, nach 5 Sekunden verlässt Amisia die Gruppe.
2. Niemand auf einem anderen Layer: das Fenster sagt "Erreicht: 31 · gehört: 0"; nächster Klick fragt die Krieger der
   Zone, danach die Magier usw.; nach allen Klassen "Im Kanal fragen".
3. Als Helfer: eine `ZQ` aus der Zone kommt, Amisia antwortet; die `YI` danach lädt ohne Frage ein, die Gruppe steht
   auf "Jeder gegen jeden"; der Gast geht nach dem Wechsel von selbst.

## Abnahmekriterien

- Wenn du ohne Gilde (oder ohne Gildenmitglied in der Zone) "Layer wechseln" klickst und ein anderer Amisia-Nutzer in
  der Zone auf einem anderen Layer hilft, dann lädt er dich ohne weiteren Klick ein, und nach einem angezielten NPC
  steht "Gewechselt: Layer B"; nach 5 Sekunden bist du aus der Gruppe (braucht: Gruppe).
- Wenn du "Layer wechseln" klickst, dann öffnet sich das Fenster "Wer" nicht und nichts steht im Chat; im Fenster
  steht "Erreicht: n · gehört: m".
- Wenn niemand antwortet und du noch einmal klickst, dann fragt Amisia eine Klasse der Zone ("Weiter fragen: ...").
- Wenn ein Fremder mit Amisia dich über "Layer wechseln" fragt und du hilfst, dann lädt Amisia ihn ohne Frage ein und
  die Beute steht auf "Jeder gegen jeden" (braucht: Gruppe).
- Wenn du "Helfen: AN" klickst, während Amisia zwei Gäste eingeladen hat, dann sind sie aus der Gruppe.

## Sonderfälle

- Bosskampf, Kampfsperre der Nachrichten: keine Frage, keine Antwort (wie bisher).
- `/who` liefert nichts (zu viele Abfragen, die Antwort kommt nie): nach 5 Sekunden "Das Spiel hat die Liste nicht
  geschickt", der nächste Klick versucht es wieder.
- Ein anderes Addon (oder der Spieler) hat das Fenster "Wer" offen: Amisia ändert dessen Liste nicht, fragt nur die
  Gilde und sagt es.
- Ein Name aus `/who` ist inzwischen offline: die Nachricht geht ins Leere; Amisia fängt die Systemzeile "Kein Spieler
  namens ..." für diese Namen ab, damit der Chat sauber bleibt.
- Zwei Amisia-Nutzer fragen zugleich: wer fragt, hilft nicht (F-214, D-139).
- TBC Anniversary und Era: kein Teil 1 (kein Layer-Wechsel dort, `forever = true`).

## Missbrauch/Vertrauen

- Fremde dürfen nur `ZQ`, `ZA` und `YI` schicken, alles andere bleibt Gilde (D-12). Jedes Feld wird geprüft (Zahlen,
  Länge); eine `ZA`/`YI` zählt nur zur eigenen offenen Frage bzw. Antwort (Id, Zone, Layer).
- Ein Fremder kann jemanden zum Einladen bringen, mehr nicht: dieselben Grenzen (sechs in zehn Minuten, eine pro Minute
  je Spieler, nie in Instanzen), nur aus der eigenen Zone, Helfen aus jederzeit.
- Fluten: höchstens eine beantwortete `ZQ` je Absender in 30 Sekunden und 20 je Minute insgesamt; leise Nachrichten an
  Fremde nur an Namen aus der eigenen `/who`-Liste der letzten 2 Minuten oder an Absender einer Frage/Antwort.
- Die Beute "Jeder gegen jeden" nur in der Gruppe, die Amisia für den Wechsel gebildet hat.

## Daten

- Nachrichten (Präfix Steuerung, WHISPER): `ZQ` <Frage-Id> <Zonen-Karte> <zoneUID|0>; `ZA` <Frage-Id> <Zonen-Karte>
  <zoneUID|0> <1 hilft|0>; `YI` jetzt auch an und von Fremden, die geantwortet haben.
- `AmisiaDB.layerHosts` = { [Name] = Zeit der letzten Antwort } (7 Tage, höchstens 200).
- Einstellungen (Abschnitt Layer): "Nur neue Layer" (aus), "Helfen im Kampf pausieren" (aus); Voreinstellungen
  "Ohne Frage einladen" an, "Gruppe nach dem Wechsel verlassen" an, "Verlassen nach Sekunden" 5.
- DECISIONS: neuer Eintrag (ändert D-117/D-124: Amisia-Nachrichten auch mit Fremden der Zone); ARCHITECTURE:
  Nachrichten, Schlüssel, Einstellungen.

## Offene Fragen

1. Fremde Amisia-Nutzer der Zone per `/who` und leiser Nachricht fragen (die Ausnahme von "Nachrichten nur in der
   Gilde")? Vorschlag: ja, nur `ZQ`/`ZA`/`YI`, mit den Grenzen oben.
2. Helfen lädt eine Bitte über Amisia ohne Frage ein (voreingestellt), auch von Fremden? Vorschlag: ja, wie dort;
   Chat-Bitten von Fremden fragen weiter.
3. Nach dem Wechsel von selbst verlassen, voreingestellt an, nach 5 Sekunden? Vorschlag: ja.
4. Alles in einem Release oder erst Teil 5 (Selbsttest, 2.94.0) und nach deinem Bericht Teil 1 bis 4? Vorschlag: alles
   zusammen bauen, der Selbsttest kommt mit; was er als gesperrt meldet, schaltet Amisia von selbst ab.

## Entscheidungen

- 2026-11-15: alle vier Fragen: "Passt, bauen" -> Fremde Amisia-Nutzer der Zone per `/who` und `ZQ`/`ZA`/`YI` fragen;
  Bitten über Amisia ohne Frage einladen (auch Fremde), Chat-Bitten von Fremden fragen weiter; nach dem Wechsel von
  selbst verlassen, an, 5 Sekunden; alles in einem Release mit dem Selbsttest.
