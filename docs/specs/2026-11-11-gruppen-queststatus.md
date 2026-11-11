# Spec: Gruppen-Queststatus im Dungeon

Stand: 2026-11-11 · Status: freigegeben (Nutzer 2026-11-11: Punkt 2 der angebotenen Liste) ·
Feature: F-178

## Ziel

Vor dem ersten Pull sieht die Gruppe, wem eine Dungeonquest noch fehlt (wem man sie teilen muss) und
wer sie schon abgeben kann. Gelöst ist es, wenn in einer Fünfergruppe mit Amisia die Seite Dungeons
und die Dungeon-Leiste das zeigen, ohne dass jemand im Chat fragt.

## Was es tut

- **Seite Dungeons, Teil "Quests":** in einer eigenen Gruppe (nicht im Raid) rechts in jeder Questzeile
  ein Zeichen je Mitglied: der Anfangsbuchstabe in Klassenfarbe, dahinter das Questzeichen des Spiels
  wie bei der eigenen Zeile (gelbes "!" fehlt und kann sie annehmen, graues "!" fehlt, noch nicht
  annehmbar, graues "?" im Log, gelbes "?" fertig zum Abgeben, Haken erledigt), "-" kann sie nie
  annehmen (Fraktion, Klasse, Volk, ausgeschlossen), grau mit "?" unbekannt (kein Amisia, Teilen aus,
  anderer Datenstand). Ein Mitglied ohne Amisia liest sich immer als "unbekannt", nie als "fehlt".
  Der Start der Quest rückt dafür zusammen (92 statt 188 Pixel).
- **Tooltip der Zeile:** "Gruppe:" und je Zustand die Namen ("Fertig zum Abgeben: ...", "Im Log: ...",
  "Erledigt: ...", "Fehlt: ...", "Fehlt, noch nicht annehmbar: ...", "Kann sie nicht annehmen: ...",
  "Unbekannt (kein Amisia oder Teilen aus): ..."), bei einer eigenen Quest im Log, die jemandem fehlt,
  "Kannst du teilen: Anna".
- **"Teilen":** ein leiser Link rechts in der Zeile, nur solange die Maus darauf steht (D-67), nur für
  eine eigene Quest im Log, die einem Mitglied fehlt, und nur, wenn der Client einen Teilen-Aufruf hat
  (`QuestLogPushQuest` mit `C_QuestLog.SetSelectedQuest` oder `SelectQuestLogEntry`). Ein Klick teilt
  sie (nie im Kampf); ohne den Aufruf bleibt der Text im Tooltip, man teilt im Questlog.
- **Dungeon-Leiste (F-168):** der Abschnitt Quests bekommt "· 2 teilen" (eigene Quests im Log, die
  einem Mitglied fehlen), in seiner Liste steht bei so einer Quest "fehlt 2" statt der Stufe. Das ist
  die eine Zusammenfassung; die Seite hat keine zweite.
- **Einstellung** im Abschnitt Quests: "Meinen Dungeon-Queststand mit der Gruppe teilen" (an). Aus:
  Amisia schickt keinen eigenen Stand; was die anderen schicken, zeigt es weiter.
- `/amisia selbsttest gruppe` meldet die Client-Funktionen unter "Gruppen-Queststand, Quest teilen".

## Was es ausdrücklich nicht tut

- Kein Raid: Raids haben auf ihrer Seite keine Quests (D-98), 40 Zeichen passen in keine Zeile, und
  der Gruppenkanal eines Raids ist nur die Untergruppe. Nur `PARTY` in einer eigenen Gruppe.
- Nichts an die Gilde, nie per Flüstern, nie an eine Gruppe der Dungeonsuche (`INSTANCE_CHAT`, D-19).
- Kein automatisches Teilen; kein Teilen per Chatzeile.
- Die Zeilen bleiben die eigene Questliste: eine Quest, die man selbst nicht annehmen kann (andere
  Klasse), steht dort weiter nicht, auch wenn ein Mitglied sie hätte.
- Nichts gespeichert; nach `/reload` fragt Amisia neu.

## Abläufe

1. Die Gruppe betritt einen Dungeon: jeder Client mit Amisia schickt nach 3 Sekunden seinen Stand
   dieses Dungeons (`QS`), und wer danach noch einen Stand vermisst, fragt einmal (`QR`, nach 3-6
   Sekunden je Name verteilt; eine Frage, die schon jemand stellte, stellt keiner nach).
2. Ein Mitglied kommt dazu: der Neue (er ist neu in einer Gruppe) und die anderen, die gerade auf
   einen Dungeon schauen (drinnen oder auf der Seite), schicken ihren Stand und fragen; die Antwort
   kommt nach 0,5-3,5 Sekunden je Name, bei fünf Clients also nicht zugleich.
3. Draußen am Versammlungsstein: wer die Seite Dungeons auf "Quests" eines Dungeons öffnet, fragt
   für genau diesen Dungeon (höchstens einmal je Minute) und schickt seinen Stand; alle antworten.
4. Eigene Änderung (angenommen, fertig, abgegeben, abgebrochen, Stufe): nach 2 Sekunden (gesammelt,
   höchstens 5) geht der neue Stand für die Dungeons, auf die die Gruppe schaut; nur wenn er sich
   geändert hat.
5. Im Kampf, in der Sperre einer Begegnung, im Schlachtfeld geht nichts; es wartet und geht danach.
6. Ein Mitglied geht: sein Stand verschwindet. Die Gruppe endet oder wird ein Raid: alles weg.

## Abnahmekriterien

- Wenn zwei mit Amisia in einer Gruppe einen Dungeon betreten, dann zeigt die Seite Dungeons bei jeder
  Quest das Zeichen des anderen, und der Tooltip nennt, wer sie hat, abgeben kann oder braucht (braucht: Gruppe).
- Wenn ein Mitglied kein Amisia hat oder das Teilen aus hat, dann steht es grau mit "?" da, nie als "fehlt" (braucht: Gruppe).
- Wenn man eine Quest im Log hat, die dem anderen fehlt, dann zeigt die Leiste "· 1 teilen" und die Zeile
  "Teilen"; ein Klick teilt sie außerhalb des Kampfes (braucht: Gruppe).
- Wenn der andere die Quest annimmt oder abschließt, dann ändert sich sein Zeichen nach ein paar Sekunden (braucht: Gruppe).
- Wenn man draußen die Quests eines Dungeons öffnet, dann kommen die Stände der anderen auch ohne Betreten (braucht: Gruppe).

## Sonderfälle

- **Bosskampf:** Addon-Nachrichten sind dort gesperrt oder geheim; Amisia sendet nichts (Kampf, Sperre)
  und nimmt in der eigenen Sperre nichts an. Was wartet, geht nach dem Kampf.
- **Flügel einer Karte (D-106):** vor dem ersten Kill geht der Stand für jeden Kandidaten einzeln
  (Kloster: bis zu vier `QS`); ein Stand gilt nur unter seinem Dungeon, nie unter einem anderen Flügel.
- **Anderer Datenstand:** eine Quest, die die Liste des Absenders nicht nennt, ist "unbekannt".
- **Ohne Nachricht:** die Questdaten sagen trotzdem "kann sie nicht annehmen" bei einer anderen Klasse
  (aus der Gruppenliste) oder Fraktion; Quests aus dem Quest-Scan ohne Fraktion (F-177) gelten als möglich.
- **Login, `/reload`:** nichts geht, bevor das Questlog einmal geantwortet hat (`QUEST_LOG_UPDATE`).
- **Nachnamen, Englisch:** Namen über die Gruppenliste (`ns.TrustName`), Texte in beiden Sprachen.
- **Ältere Amisia:** kennt `QS`/`QR` nicht und verwirft sie (Comm.lua); sie zählt als "unbekannt".

## Missbrauch/Vertrauen

Nur der Absender, den der Server setzt, und nur wenn er in der eigenen Gruppe steht; nur auf `PARTY`.
Jedes Feld wird geprüft (Schlüssel des eigenen Datenstands, kein Raid, Version 1-9, 1-100 Einträge,
Nummern bis 999999), ein Stand je Absender und Dungeon alle 3 Sekunden, eine Frage je Absender alle
10 Sekunden, dazu die Grenzen von Comm.lua (40 Nachrichten in 10 s, 20 KB je Minute). Höchstens vier
Dungeons je Mitglied, vier Mitglieder. Ein falscher Stand zeigt nur falsche Zeichen; er ändert nichts
und teilt nichts. Antworten verteilt, eigene Fragen höchstens alle 15 Sekunden, eigene Stände je
Dungeon alle 6 Sekunden, 12 in der Minute. Datenschutz: der Stand geht nur an die Gruppe; die
Einstellung schaltet das Senden ab.

## Daten

- Nachrichtenarten (Präfix `Amisia`, `PARTY`): `QS <Dungeon> <Version> <T|-> <Liste>` (Abstand 3 s je
  Dungeon), `QR <Dungeons mit Komma, höchstens 4> <Version>` (Abstand 10 s). Die Liste: die Quest-IDs
  der Liste des Dungeons aufsteigend, je als Abstand zur vorigen in Basis 36 und dahinter das Zeichen
  des Zustands (`.` kann annehmen, `<` noch nicht, `+` im Log, `!` fertig, `*` erledigt, `/` nie);
  `-` leer, `T` gekürzt. Beispiel Gnomeregan (29 Quests, 78 Bytes):
  `1QS\tgnomer\t1\t-\t26x.1.1+1p!i*1/1<1.1*1.1.1.1+1!e*2/1<1.1*1.1.1.9+19j!1*1/1<1.1*` (`\t` der Tabulator). Eine spätere Version hängt Felder hinten an.
- Einstellung `quests.groupShare` (an). Kein `AmisiaDB`-Schlüssel: der Stand lebt im Speicher.
- Modul `Gear/GroupQuests.lua`, `D.OwnQuestState` in `Gear/Dungeons.lua`.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-11: Nutzer wählt aus der angebotenen Liste Punkt 2: "Gruppen-Queststatus im Dungeon: wer in der
  Gruppe welche Dungeonquest hat, fertig hat oder noch braucht." -> gebaut wie oben.
- Annahme (nicht gefragt): nur `PARTY`, kein Raid (Gründe oben).
- Annahme (nicht gefragt): eine Liste mit einem Zustand je Quest statt dreier Listen: sie sagt zugleich,
  welche Quests der Absender überhaupt kennt, so wird ein anderer Datenstand "unbekannt" statt "fehlt".
- Annahme (nicht gefragt): Fragen statt ständigem Wiederholen: wer neu ist oder einen Stand vermisst,
  fragt einmal; die Antworten kommen nach Namen verteilt, und wer gerade (nach der letzten Änderung der
  Gruppe, binnen 10 s) gesendet hat, antwortet nicht noch einmal.
- Annahme (nicht gefragt): Senden standardmäßig an (der Nutzer wollte das Feature); auch mit Senden aus
  darf Amisia fragen (eine Frage verrät keine Quest).
- Annahme (nicht gefragt): die Zusammenfassung in der Dungeon-Leiste ("· 2 teilen", "fehlt 2"), nicht im
  Kopf der Seite.
- Annahme (nicht gefragt): Stände verfallen nach 30 Minuten.
