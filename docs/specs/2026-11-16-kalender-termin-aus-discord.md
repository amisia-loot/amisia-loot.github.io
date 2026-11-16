# Spec: Termin des Anmelde-Bots aus Discord in den Kalender einfügen

Stand: 2026-11-16 · Status: freigegeben ·
Feature: F-223

## Ziel

Nutzer 2026-11-16, mit einem Bild der Seite des Anmelde-Bots in Discord: "können wir auch von hier termine (discord
bot) in den kalender einfügen". F-217 geht von Amisia nach Discord ("Für Discord"); hier geht es zurück: ein Termin,
den der Offizier im Bot angelegt hat, soll ohne Abtippen im Spielkalender und auf Amisias Blatt stehen. Gelöst ist es,
wenn dafür ein Kopieren in Discord bzw. im Browser, ein Einfügen in Amisia und ein Klick auf "Anlegen" reichen.

Ein Addon hat kein Netz: es kann den Bot nicht selbst fragen. Der Bot gibt aber jeden Termin unter einer öffentlichen
Adresse ohne Schlüssel als JSON heraus (`.../api/v4/events/<ID>`, die ID ist die der Discord-Nachricht des Termins; im
Dashboard des Bots der Knopf "JSON"). Geprüft am 2026-11-16 an der Dokumentation des Bots, noch nicht an einem echten
Termin (siehe Frage 1).

## Was es tut

**A. Einfügen im Formular.**
- Das Formular "Termin anlegen ..." (F-217) bekommt den Link "Aus Discord ...". Er zeigt ein Einfügefeld mit der
  Anleitung: "Im Dashboard des Bots beim Termin auf 'JSON' klicken, alles markieren (Strg+A), kopieren (Strg+C), hier
  einfügen (Strg+V)."
- Amisia liest aus dem Eingefügten nur: `title`, `description`, `startTime` (Unix-Zeit) und die Anmeldungen
  (`signUps`, für Teil B). Daraus füllt es das Formular: Tag und Uhrzeit in der Zeit des Spielkalenders (Realm-Zeit, wie
  "Für Discord" rückwärts), Titel (höchstens 31 Zeichen), Beschreibung (höchstens 255, ohne Discord-Zeichen, Emoji-Codes
  und Links). Das Blatt springt auf den Monat und Tag des Termins.
- Art ist "Gildenereignis (mit Anmeldung)". Typ und Instanz: nennt der Titel eine Instanz, die das Spiel anbietet
  (`EventGetTextures`), ist sie gewählt (Schlachtzug bzw. Dungeon); sonst wählt der Spieler selbst.
- Der Spieler sieht alles im Formular, kann es ändern und klickt "Anlegen". Ab da ist es F-217: dieselben Aufrufe,
  dieselben Sperren, dieselbe Chatzeile.
- Steht am selben Tag schon ein Termin mit derselben Uhrzeit, sagt das Formular "Um 19:45 steht schon 'Black Temple'
  im Kalender." Anlegen geht trotzdem (der Spieler entscheidet).

**B. Die Anmeldungen desselben Einfügens.**
- Dasselbe JSON enthält die Anmeldungen (Name, Klasse, Rolle, Stand). Das Feld "Einfügen" der Seite Aufstellung liest es
  zusätzlich zum bisherigen Bot-Text und zum Block `#AMISIA-RAID`, mit denselben Regeln wie heute (höchstens 80 Namen,
  Abgleich mit der Gilde, Abwesend/Vorläufig/Ersatzbank aus den Angaben des Bots).
- Nach dem Anlegen in Teil A bietet die Chatzeile nichts Automatisches an; der Offizier fügt den Text bei der
  Aufstellung ein, wenn er die Liste will.

## Was es ausdrücklich nicht tut

- Keine Verbindung zum Bot: kein Abruf aus dem Spiel (geht nicht), kein Schlüssel des Discord-Servers in Amisia oder auf
  der Website, kein eigener Server. Die Liste aller Termine eines Servers gibt der Bot nur mit dem Schlüssel eines
  Admins heraus; die nutzt Amisia nicht (Frage 3).
- Kein Abgleich danach: ändert oder löscht jemand den Termin im Bot, merkt Amisia das nicht. Der Offizier ändert den
  Spieltermin dann selbst (F-222) oder fügt neu ein.
- Nichts zurück in den Bot: keine Anmeldung, kein Termin (das bleibt der Text "Für Discord").
- Nie ohne Klick und nie mehrere auf einmal: das Spiel nimmt je Klick einen Termin (`AddEvent`).
- Kein Link in Amisia zum Bot und kein Name des Bots in Texten: die Anleitung nennt nur den Weg.
- Kein Lesen des Discord-Beitrags als Text für den Termin (der Titel besteht dort aus Bildern, Datum und Zeit hängen
  an der Zeitzone des Lesers): dafür ist das JSON da.

## Abläufe

1. Vulo legt in Discord mit dem Bot "Black Temple" für So 22.11. 19:45 an.
2. Er öffnet im Dashboard des Bots den Termin, klickt "JSON", markiert alles und kopiert.
3. In Amisia: Gilde > Kalender, "Termin anlegen ...", "Aus Discord ...", einfügen. Das Blatt zeigt den 22.11., das
   Formular "Black Temple", 19:45, Schlachtzug und die Beschreibung.
4. Er klickt "Anlegen". Der Termin steht im Spielkalender für die ganze Gilde und auf Amisias Blatt.
5. Am Raidtag kopiert er das JSON noch einmal und fügt es bei der Aufstellung unter "Einfügen" ein: die Anmeldungen des
   Bots stehen mit Klasse und Rolle in der Liste.

## Abnahmekriterien

- Wenn du das JSON eines Bot-Termins unter "Termin anlegen ..." > "Aus Discord ..." einfügst, dann zeigt das Blatt den
  Tag des Termins, und das Formular hat Titel, Uhrzeit (wie in Discord bei dir angezeigt, wenn dein PC in der Zeitzone
  des Realms steht) und Beschreibung.
- Wenn du danach "Anlegen" klickst, dann steht der Termin im Spielkalender und auf Amisias Blatt.
- Wenn du etwas anderes einfügst (z. B. den Text des Discord-Beitrags), dann steht dort "Das ist kein Termin des
  Anmelde-Bots (JSON).", und das Formular bleibt, wie es war.
- Wenn du dasselbe JSON auf der Seite Aufstellung unter "Einfügen" einfügst, dann stehen die Anmeldungen des Bots mit
  Rolle und Klasse in der Liste.
- Wenn der Termin des Bots schon vorbei ist, dann füllt Amisia das Formular nicht und sagt "Der Termin liegt in der
  Vergangenheit."

## Sonderfälle

- **Zeitzone:** `startTime` ist ein fester Zeitpunkt. Amisia rechnet ihn mit dem Abstand zwischen Realm-Uhr und PC-Uhr
  in die Zeit des Spielkalenders um (derselbe Wert wie bei "Für Discord", `CC.Skew`).
- **Zu spät oder zu früh:** vor heute oder nach `GetMaxCreateDate`: nicht gefüllt, mit dem Grund.
- **Titel länger als 31 Zeichen:** gekürzt; der volle Titel steht am Anfang der Beschreibung, soweit Platz ist.
- **Minuten, die das Spiel nicht nimmt:** das Formular nimmt jede Minute; lehnt das Spiel sie ab, kommt sein Fehler.
- **Großes Einfügen:** höchstens 262144 Zeichen und 20 Ebenen (wie der Soft-Reserve-Code); mehr: "Zu groß."
- **Fehlt der JSON-Leser des Clients** (`C_EncodingUtil.DeserializeJSON`): der Link "Aus Discord ..." fehlt.
- **Kampf, offener Spielkalender:** Einfügen und Füllen gehen; "Anlegen" ist grau wie bisher.
- **Englischer Client:** Instanznamen im Titel des Bots sind meist englisch; passt keiner zur Liste des Spiels, wählt
  der Spieler die Instanz selbst.

## Missbrauch/Vertrauen

- Eingefügter Text ist unvertraut (D-12): nur die genannten Felder, jedes geprüft und gekappt, Farbcodes, Links,
  Steuerzeichen und Balken heraus (`ns.CleanNote`, `CC.Clean`); Zahlen nur als Zahlen in sinnvollen Grenzen.
- Nichts geschieht durch das Einfügen allein: es füllt ein Formular. Angelegt wird nur mit dem Klick des Spielers, mit
  den Rechten, die das Spiel ihm gibt.
- Kein neuer Weg für andere Spieler: keine Nachricht, kein Empfang. Wer ein manipuliertes JSON einfügt, schadet nur
  seinem eigenen Formular.
- Die Anmeldungen in der Aufstellung laufen durch denselben Abgleich wie heute der Bot-Text (unbekannte Namen grau).

## Daten

- Kein neuer gespeicherter Schlüssel, keine Einstellung, keine Addon-Nachricht, keine Exportzeile, kein
  Website-Zustand.
- **Neues Einfügeformat** (kein Block der Website): das Termin-JSON des Anmelde-Bots, gelesen von
  `ns.CalCreate.FromBot(text)` (Formular) und `ns.ParseLineup` (Anmeldungen). Kommt in `docs/ARCHITECTURE.md` in den
  Absatz unter "Paste-in blocks" (neben Soft-Reserve-Code und Bot-Text).
- **Neue Entscheidung D-148:** Amisia liest das Termin-JSON des Anmelde-Bots nur als Einfügetext; keine Verbindung,
  kein Schlüssel. Führt die "Folge" von D-142 (keine Verbindung zu einem Discord-Bot) fort.

## Offene Fragen

1. **Ein echter Termin zum Prüfen.** Die Felder stehen in der Dokumentation des Bots, gesehen habe ich noch keinen
   echten Termin (Zeit in Sekunden? Titel als Klartext? Namen der Rollen und der Klassen "abwesend"/"vorläufig"?).
   Vorschlag: du schickst vor dem Bau die ID oder das JSON eines eurer Termine; daraus wird auch der Test.
2. **Die Anmeldungen mit übernehmen (Teil B)?** Vorschlag: ja, über das bestehende "Einfügen" der Aufstellung.
3. **Alle Termine des Servers auf einmal?** Der Bot gibt die Liste nur mit dem Schlüssel eines Admins (`/apikey`)
   heraus. Vorschlag: nein, Termin für Termin ohne Schlüssel. Die Alternative: der N100 holt die Liste mit dem Schlüssel
   und legt sie nur für dich bereit; das wäre eine eigene Spec und nichts für andere Nutzer des Addons.
4. **Umweg über die Amisia-Website?** Sie könnte aus dem Link des Termins einen kurzen Block zum Einfügen machen (der
   Bot erlaubt den Abruf aus dem Browser). Vorschlag: nein, das JSON direkt einfügen ist ein Schritt weniger.
5. **Art des Termins.** Vorschlag: immer "Gildenereignis (mit Anmeldung)", im Formular änderbar.
6. **Hinweis in der Beschreibung**, dass die Anmeldung in Discord läuft? Vorschlag: nein, der Spieler schreibt es
   selbst dazu, wenn er es will.

## Entscheidungen

- 2026-11-16: Nutzer: "Passt, beide bauen" -> alle sechs Vorschläge übernommen: Frage 1 ein echter Termin zum Prüfen
  (gebaut wird nach der Dokumentation des Bots; die ID oder das JSON eines echten Termins steht noch aus und wird vor
  dem Release geprüft); Frage 2 die Anmeldungen über "Einfügen" der Aufstellung; Frage 3 kein Schlüssel, Termin für
  Termin; Frage 4 kein Umweg über die Website; Frage 5 immer "Gildenereignis (mit Anmeldung)", änderbar; Frage 6 kein
  Hinweis in der Beschreibung.
