# Spec: Raid-Notiz für Cooldowns und Einteilungen

Stand: 2026-11-13 · Status: freigegeben ·
Feature: F-196

## Ziel

Die Raidleitung schreibt vor dem Pull eine Notiz (wer welchen Cooldown wann zieht, wer welche Seite, wer
welches Ziel unterbricht) und schickt sie an den Raid. Jeder mit Amisia sieht sie in einem kleinen Fenster,
das er an eine feste Stelle schiebt und das auch im Kampf offen bleibt und sich öffnen lässt. Gelöst ist es,
wenn niemand mehr im Bosskampf in den Discord schauen muss, um seine Aufgabe zu kennen.

## Was es tut

- **Seite "Raid-Notiz"** im Reiter Raid (alle). Oben "Raid-Notiz" mit einem großen Textfeld, "An Raid senden",
  "Vorlagen" (speichern, laden, löschen; z. B. eine je Boss, bis zu 30) und "Fenster zeigen"; diesen Teil
  bearbeiten und senden nur Offiziere sowie Raidleiter und Assistenten des eigenen Raids, die anderen sehen
  dort die empfangene Notiz (gesperrt und grau, ohne Schreibmarke). Offiziere schreiben Notiz und Vorlagen auch
  außerhalb eines Raids; senden geht erst im Raid (Nachtrag 2026-11-14, D-126). Darunter "Eigene Notiz": ein kleineres Feld nur für dich, nie gesendet.
  Eine Hilfezeile: `{stern}` ... `{totenkopf}` (auch `{star}` ... `{skull}`, `{rt1}` ... `{rt8}`) werden zu
  Zielmarkierungen; Namen von Raidmitgliedern erscheinen in Klassenfarbe; die Zeilen mit dem eigenen Namen
  hebt jeder Empfänger selbst gelb hervor.
- **Fenster "Raid-Notiz"** (`AmisiaRaidNote`, alle): oben die zuletzt empfangene (oder selbst gesendete)
  Notiz mit "von <Name>, <Uhrzeit>", darunter durch eine Linie getrennt die eigene Notiz (nur wenn sie Text
  hat). Ziehen verschiebt es, die Stelle bleibt (auch nach `/reload`); unten rechts ein Griff für die Größe.
  Ein Schloss oben rechts sperrt Stelle und Größe; gesperrt gehen Mausklicks durch, außer auf Schloss und X.
  Hintergrund und Schriftgröße in den Einstellungen. Im Kampf: öffnen, schließen, scrollen geht; Verschieben
  und Größe ändern erst nach dem Kampf.
- **Öffnen:** `/amisia notiz` (en `/amisia note`), Eintrag "Raid-Notiz" in der ersten Ebene des
  Minimap-Menüs, auf der Seite "Fenster zeigen". Bei einer neuen Notiz öffnet es sich von selbst
  (Einstellung, an; im Kampf erst danach, wenn es zu war).
- **Chat:** beim Empfang eine Zeile "Raid-Notiz von <Name> (12 Zeilen). /amisia notiz zeigt sie."
  (einmal je Notiz, abschaltbar).
- **Spät dazugekommen / `/reload`:** wer in den Raid kommt oder neu lädt, bekommt die aktuelle Notiz von selbst
  (wer gesendet hat, kündigt sie an; wer sie nicht hat, fragt nach).

## Was es ausdrücklich nicht tut

- Keine Timer, Countdowns oder Ansagen zu Zeitpunkten im Kampf (das wäre ein Boss-Mod; dafür fehlt auf Forever
  ohnehin das Kampflog). Zeiten wie "1:30" sind nur Text.
- Keine Zauber- oder Gegenstandssymbole im Text (Symbole nur Zielmarkierungen), keine Links, keine Farbcodes
  von außen: der Text wird vor dem Anzeigen entschärft.
- Kein Senden im Kampf oder in der Kampfsperre: "An Raid senden" ist dann grau; vorbereitet wird vor dem Pull.
- Keine Notiz in einer Fünfergruppe, für die Gilde außerhalb eines Raids oder an Fremde; kein Import fremder
  Notiz-Formate; die eigene Notiz wird nie gesendet.

## Abläufe

1. Offizier (oder Raidleiter/Assistent) öffnet Raid > Raid-Notiz, schreibt (oder lädt die Vorlage
   "Ragnaros"), klickt "An Raid senden". Amisia speichert sie als aktuelle Notiz und schickt sie in den Raid.
2. Jeder Raider mit Amisia bekommt sie, sieht die Chatzeile und das Fenster. Er schiebt das Fenster neben
   seine Leisten, sperrt es mit dem Schloss und schreibt sich unter "Eigene Notiz" etwas dazu.
3. Im Bosskampf öffnet/schließt er das Fenster mit `/amisia notiz` oder über das Minimap-Menü; seine Zeilen
   sind gelb.
4. Kommt jemand später dazu oder macht `/reload`, holt sein Amisia die Notiz.
5. Sendet jemand Berechtigtes eine neue Notiz, ersetzt sie die alte bei allen.

## Abnahmekriterien

- Wenn ein Offizier im Raid unter Raid-Notiz Text mit `{totenkopf} Tank: Name` schreibt und "An Raid senden"
  klickt, dann sehen die anderen mit Amisia binnen Sekunden die Chatzeile und im Fenster den Totenkopf und den
  Namen in Klassenfarbe; ihre eigenen Zeilen sind gelb. (braucht: Raid)
- Wenn du das Fenster verschiebst, die Größe änderst, das Schloss schließt und `/reload` machst, dann steht es
  an derselben Stelle in derselben Größe, gesperrt, mit derselben Notiz und deiner eigenen Notiz darunter.
- Wenn du im Bosskampf `/amisia notiz` eingibst oder im Minimap-Menü "Raid-Notiz" klickst, dann öffnet und
  schließt sich das Fenster ohne Fehlermeldung und ohne "Aktion blockiert". (braucht: Raid)
- Wenn du mitten im Abend in den Raid kommst oder `/reload` machst, dann hast du nach spätestens etwa einer
  Minute die aktuelle Notiz. (braucht: Raid)
- Wenn ein Raider ohne Offiziersrang, der weder Raidleiter noch Assistent ist, die Seite öffnet, dann kann er
  die Raid-Notiz nicht senden; ein Assistent kann es. (braucht: Raid)

## Sonderfälle

- **Bosskampf/Kampfsperre:** Senden und Nachfragen warten bis danach (die Sendeschlange hält in der Sperre an).
  Anzeigen geht immer: das Fenster ist kein geschützter Rahmen. Verschieben und Größe erst nach dem Kampf.
- **Zwei Berechtigte senden:** die zuletzt angekommene Notiz gilt; das Fenster nennt "von <Name>".
- **Raidleiter/Assistent außerhalb der Gilde:** Datenblöcke nimmt Amisia nur von Gildenmitgliedern an (D-12);
  ein Gast-Raidleiter kann also nicht senden. Die Seite sagt ihm das.
- **Assistent verliert den Rang:** was er gesendet hat, bleibt stehen; neue Notizen von ihm gelten nicht mehr.
- **Nachnamen, Twinks:** Namen wie im Raid ("Vulo Pala"); farbig nur, wer im Raid ist.
- **Client auf Englisch:** `{star}`, `{skull}` usw. gehen auch; die Hilfezeile nennt beide.
- **Leere Notiz:** "Keine Raid-Notiz. Die Raidleitung schickt sie vor dem Pull." im Fenster.
- **Sehr lang:** Raid-Notiz höchstens 4000 Zeichen und 120 Zeilen, eigene Notiz 1000 Zeichen; das Feld sagt,
  wie viel noch geht.

## Missbrauch/Vertrauen

- Senden dürfen Gildenmitglieder in der eigenen Gruppe, die Offizier (Rang-Flag 22) sind oder im Raid gerade
  Leiter oder Assistent (Raidliste des Empfängers zum Zeitpunkt des Empfangs). Der Absender ist der vom Server,
  nie ein Feld (D-12). Alles andere wird ungelesen verworfen.
- Fremde Farbcodes, Texturen und Links werden entschärft (jedes `|` wird `||`), erst danach setzt Amisia
  die eigenen Zielmarkierungen und Klassenfarben ein.
- Fluten: eine Notiz je Absender höchstens alle 10 s, Deckel 4000 Zeichen, Blob höchstens 30 Teile; Ankündigung
  alle 240 s, Nachfrage höchstens alle 5 s je Notiz, eine Antwort je Fragendem und Notiz alle 30 s. Eine Notiz,
  die älter als 12 Stunden ist (oder mehr als 5 Minuten in der Zukunft liegt), wird weder angekündigt noch
  angenommen: die Notiz der letzten Woche kommt nicht wieder.

## Daten

- **Nachrichten:** `NV` Absender -> RAID (nach dem Senden, dann alle 240 s, bald nachdem jemand beitritt):
  Notiz-Id, 16 hex Hash, Zeilen; `NQ` Raider -> Absender WHISPER (Hash fehlt oder anders): Notiz-Id, eigener
  Hash; Blob-Art `RN` Absender -> RAID (beim Senden) oder WHISPER (Antwort): `{v = 1, id, at, t = Text}`.
  Empfänger: wie oben unter Vertrauen; Blob ganz geprüft, Hash wie angekündigt.
- **AmisiaDB:** `raidNote = {v = 1, sets = {{name, text, at}} (höchstens 30), cur = {id, at, by, text, h}
  (die aktuelle, gesendete oder empfangene), draft = Text, own = eigene Notiz}`.
- **Einstellungen:** Abschnitt `raidnote` ("Raid-Notiz", Reiter Raid): `raidnote.autoShow` (bei neuer Notiz
  öffnen, an), `raidnote.chat` (Chatzeile, an), `raidnote.font` (Schriftgröße 10-18, 12), `raidnote.alpha`
  (Hintergrund 0-100 %, 70). Fensterstelle `settings.raidNoteWindow = {point, x, y, w, h, locked}`.
- **Seite:** `raidnote` im Reiter Raid (alle), Symbol aus `T.NAV_ICONS`.

## Offene Fragen

Keine mehr.

## Entscheidungen

- 2026-11-13: Wer darf senden: "Offiziere + Raidleiter/Assist" -> Offiziere sowie Leiter und Assistenten des
  Raids, solange sie Gildenmitglieder sind (Datenblöcke nur von Gildenmitgliedern).
- 2026-11-13: Vorlagen: "Ja, bis zu 30".
- 2026-11-13: Fenster öffnet sich bei neuer Notiz: "Ja, abschaltbar".
- 2026-11-13: Eigene Notiz: "Gleich mit bauen" -> Feld "Eigene Notiz", nur lokal, im Fenster unter der
  Raid-Notiz.
- 2026-11-13 (Vorschlag, nicht gefragt): nur im Raid, nicht in einer Fünfergruppe.
- 2026-11-13: Freigabe: "Passt, bauen".
- 2026-11-14: Offiziere (und der Charakter des Autors) schreiben Notiz und Vorlagen auch außerhalb eines Raids, senden nur im Raid; das gesperrte Feld ist grau: "Ja, umbauen".
