# Spec: Soft-Reserves teilen, Vorschau im Import-Fenster, Klassen-Abgleich

Stand: 2026-10-17 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-107 (A, Liste teilen), F-108 (B, Vorschau und Hard-Reserve-Ansage), F-109 (C, Klassen-Abgleich)

Anstoß: der Nutzer hat am 2026-10-17 den Import eines anderen Loot-Addons gezeigt (Vorschau pro Spieler
mit Item-Symbolen, Kasten "im Raid ohne Reserve", Hinweis "Klasse passt nicht", Hard-Reserves oben,
"Import & Broadcast"). Nach D-05 heißt es hier nur "ein anderes Loot-Addon"; Code wird nicht
übernommen. Was Amisia davon schon hat: Vorschau als eine Textzeile, Abgleich mit dem Raid (Seite,
Ansicht "Abgleich"), "Erinnern" und "Im Raid posten", Namensvorschläge mit Merken, Hard-Reserves in
Tooltip, Lootfenster und Rundenstart (F-019, F-091, D-44).

Drei Teile, einzeln baubar, Reihenfolge C → B → A (C ist klein und B zeigt sein Ergebnis; A ist der
größte Teil und braucht eine Gruppe zum Prüfen).

## Ziel

**A:** Lädt die Lootleitung eine Liste, haben sie alle Amisia-Nutzer der Gruppe, auch wer später
kommt: Raider sehen ihre Reserves im Tooltip, im Lootfenster und auf der Seite, ein zweiter Offizier
kann übernehmen. Gelöst, wenn kein Raider mehr "Die Lootleitung hat noch keine Liste geladen" sieht,
obwohl die Lootleitung eine hat.

**B:** Vor "Übernehmen" sieht der Offizier im Import-Fenster, was er bekommt: wer fehlt, wer nicht da
ist, welcher Name oder welche Klasse nicht passt, alle Items als Symbole. Fehler fallen vor dem Raid
auf, nicht beim ersten Drop.

**C:** Steht auf softres.it die falsche Klasse (Twink, falscher Charakter, Tippfehler auf einen
anderen Spieler), sagt Amisia es.

## Was es tut

### A: Liste teilen (F-107)

- Nach "Übernehmen" (oder `/amisia sr <Code>`) in einer Gruppe schickt Amisia die Liste an die Gruppe;
  die Ergebniszeile sagt "… übernommen, mit der Gruppe geteilt." Ein Offizier, der erst danach in die
  Gruppe kommt oder `/reload` macht, schickt sie ebenso.
- Raider (und Offiziere ohne eigene Liste) übernehmen eine geteilte Liste still. Die Seite zeigt oben
  "Liste vom 17.10. von <Name>: 89 Reservierungen von 30 Raidern".
- Ein Offizier mit einer **eigenen** Liste bekommt eine andere geteilte Liste nur als Angebot: Zeile
  auf der Seite "Neuere Liste von <Name> (20:01, 92 Reservierungen)" mit "Übernehmen".
- "Löschen" der Lootleitung leert die geteilte Liste bei allen, die sie von ihr haben.
- Einstellung `softres.share` (Abschnitt Soft-Reserves, Offiziere, an): "Liste mit der Gruppe teilen".
- Geteilt werden die fertigen Daten (Namen mit den Korrekturen der Lootleitung, Klasse, Items mit
  Doppelten, Notiz, softres +1, Hard-Reserves, Datum), nicht der eingefügte Text.

### B: Vorschau im Import-Fenster (F-108)

Das Fenster "Soft-Reserves" wird größer (etwa 560 × 640) und bekommt unter dem Textfeld:

1. **Prüfzeile** wie heute, kürzer: "Gargul-Code erkannt: 30 Raider · 89 Reservierungen · 1 Hard-Reserve"
   (für CSV/Zeilen "Erkannt: …"); Fehler des Codes wie heute.
2. **Kasten "Im Raid ohne Reserve · N"** mit den Namen als Chips in Klassenfarbe, rechts "Erinnern (N)"
   und "Im Raid posten" (die Funktionen von heute). Beide gelten der geladenen Liste: solange der Text
   im Feld von ihr abweicht, sind sie aus, Tooltip "Erst übernehmen". Ohne Fehlende: "Alle im Raid
   haben reserviert." Ohne Raid: "Kein Raid zum Abgleichen (letzter Raid: …)" wie heute.
3. **Liste "Vorschau · N Raider"** (scrollbar, Zeilen 36 px):
   - oben eine rot umrandete Zeile "Hard-Reserves" mit den Items, rechts der Chip "Ansagen";
   - pro Raider: Name in Klassenfarbe (aus dem Raid, sonst aus softres.it), darunter der Befund:
     grau "nicht im Raid", orange "Klasse passt nicht: softres Magier, im Raid Priester", orange
     "Name unklar" mit den Vorschlags-Chips von heute (Klick merkt die Korrektur, die Vorschau rechnet
     neu), gelb "korrigiert aus <Listenname>", rot "zu viel: 4 von 3", sonst nichts;
   - rechts die Items als Symbole (28 px) mit Rahmen in Qualitätsfarbe, "2x" auf dem Symbol bei
     Doppelten, Tooltip beim Zeigen, Shift-Klick setzt den Link in den Chat;
   - Reihenfolge: erst die mit Befund, dann im Raid, dann nicht im Raid; darin nach Name.
4. Unten wie heute "Übernehmen" und "Leeren" und die Ergebniszeile.

**Hard-Reserve-Ansage:** Beim Übernehmen in einem Raid (Einstellung `softres.announce`, Offiziere,
an) und mit dem Chip "Ansagen" schreibt Amisia in den Raidchat:
"Soft-Reserves geladen: 89 Reservierungen von 30 Raidern. '!sr' an <Lootleitung> flüstern zeigt
deine." und, wenn es welche gibt, "Hard-Reserves: [Item] für Gildenbank, [Item] für Anna (Tank), …"
(Zeilen höchstens 255 Bytes, höchstens drei; wartet bis 5 s auf die Item-Links, sonst "[Name]").
Englisch nach derselben Regel wie die Rundenansage (`rolls.announceEnglish`, D-44 B4). Nie in der
Kampfsperre: dann wartet die Zeile wie jede andere `ns.Say`-Zeile (ttl 120).

### C: Klassen-Abgleich (F-109)

- Die Klasse aus softres.it (Code: `class`, CSV: Spalte `Raider Class`/`Class`, die heute nicht
  gelesen wird) wird mit der Klasse des zugeordneten Raidmitglieds verglichen (englischer Klassenname
  → Token, z. B. "Death Knight" → `DEATHKNIGHT`; Forever hat nur die klassischen neun).
- Abweichung: Befund "Klasse passt nicht" in der Vorschau (B), als eigene Zeile in der Ansicht
  "Abgleich" der Seite und als "N Klasse falsch" in Prüfzeile und `/amisia sr pruefen`.
- Bei den Namensvorschlägen zählt die Klasse mit: gleiche Klasse erlaubt einen Tippfehler mehr
  (Abstand ≤ 3 statt ≤ 2) und kommt vor anderen Vorschlägen; eine andere Klasse bleibt Vorschlag,
  aber hinten.

## Was es ausdrücklich nicht tut

- Kein Senden an andere Loot-Addons und kein Lesen ihrer Nachrichten (D-44 "lesen, nie senden").
- Raider können nichts teilen und nichts an der geteilten Liste ändern; es gibt kein Zusammenführen
  zweier Listen: es gilt eine ganze Liste.
- Kein automatisches Zuordnen eines Tippfehlers ohne Klick (Frage 3), kein Erinnern vor "Übernehmen".
- Keine Bonus-Würfe, kein Rückweg nach softres.it, keine Liste auf der Website (unverändert).
- Kein Teilen außerhalb der Gruppe (nicht in die Gilde) und nicht in Schlachtfeldern oder Arenen.

## Abläufe

1. Offizier (Lootleitung) kopiert auf softres.it den Gargul-Code, `/amisia` → Soft-Reserves →
   "Importieren", fügt ein. Nach 0,3 s füllt sich die Vorschau: 2 ohne Reserve (Chips), 1 Zeile orange
   "Klasse passt nicht", 1 "Name unklar" mit Vorschlag. Er klickt den Vorschlag; die Zeile wird gelb
   "korrigiert aus …".
2. "Übernehmen": Liste gespeichert, Ergebnis "89 Reservierungen übernommen, Hard-Reserves: 1. Mit der
   Gruppe geteilt."; im Raidchat die zwei Zeilen der Ansage. "Erinnern (2)" ist jetzt an.
3. Bei den Raidern mit Amisia: nach wenigen Sekunden zeigt der Tooltip "Reserviert: …", das
   Lootfenster "SR", die Seite die Liste "von <Lootleitung>". Ein Raider, der später kommt, hat sie
   kurz nach dem Beitritt.
4. Zweiter Offizier hat schon eine eigene ältere Liste: er sieht "Neuere Liste von <Name>" und klickt
   "Übernehmen" (oder lässt seine).
5. Nach dem Raid "Löschen" bei der Lootleitung: die geteilte Liste verschwindet bei den Raidern, die
   noch in der Gruppe sind; wer schon weg ist, behält sie bis zur nächsten.

## Abnahmekriterien

- Wenn du einen Gargul-Code einfügst, dann zeigt das Fenster vor "Übernehmen" jeden Raider mit seinen
  Items als Symbole, oben die Hard-Reserves, und im Kasten die Raidmitglieder ohne Reserve (braucht: Raid).
- Wenn auf softres.it bei einem Raider eine andere Klasse steht als im Raid, dann steht in der Vorschau
  und in der Ansicht "Abgleich" "Klasse passt nicht" mit beiden Klassen (braucht: Raid).
- Wenn die Lootleitung übernimmt, dann zeigt bei einem Raider mit Amisia nach höchstens 30 s der
  Tooltip eines reservierten Items "Reserviert: …" und die Seite "Liste vom … von <Name>" (braucht: Gruppe).
- Wenn ein Raider nach dem Übernehmen in die Gruppe kommt (oder `/reload` macht), dann hat er die Liste
  nach höchstens 60 s (braucht: Gruppe).
- Wenn die Lootleitung im Raid übernimmt und es Hard-Reserves gibt, dann stehen im Raidchat die Zeile
  "Soft-Reserves geladen: …" und "Hard-Reserves: [Item] für …" (braucht: Raid).

## Sonderfälle

- **Bosskampf/Kampfsperre:** gesendet wird nur außerhalb; die Comm-Warteschlange hält Teile an
  (`ns.ChatLocked`); die Ansage wartet (ttl 120), danach fällt sie. Empfangen geht immer.
- **Nachnamen:** Zuordnung über `ns.SameName` wie heute; der Klassen-Abgleich nur für eine eindeutige
  Zuordnung. Ein Listenname, der nur ein Vorname ist, bleibt "unklar".
- **Zwei Offiziere mit Listen:** jeder sendet seine; Raider nehmen die mit der neuesten Übernahmezeit
  (gleich: die der Lootleitung, sonst der kleinere Name). Offiziere mit eigener Liste bekommen nur das
  Angebot.
- **Englischer Client:** Ansage einsprachig englisch; Klassen kommen von softres.it immer englisch.
- **Leere Liste / nur Hard-Reserves:** wird geteilt; die Vorschau zeigt nur die HR-Zeile.
- **`/reload` des Raiders:** die geteilte Liste ist gespeichert; er fragt mit ihrem Stand nach und
  bekommt nur bei einem anderen Stand eine neue.
- **Große Liste:** 40 Raider mit Notizen sind gepackt etwa 3-4 KB (unter 25 Teilen); mehr als
  `MAX_PARTS_SR` Teile wird nicht gesendet ("Liste zu groß zum Teilen", nur bei der Lootleitung).
- **Gruppe statt Raid:** Teilen geht auch in einer 5er-Gruppe; Kasten, Erinnern und Ansage nur im Raid
  (wie heute).

## Missbrauch/Vertrauen

- Angenommen wird nur von einem verifizierten Offizier (Rangrecht 22) der eigenen Gilde in der eigenen
  Gruppe; der Absender ist der des Servers (D-12, D-19). Ein Raider kann keine Liste unterschieben;
  anders als beim gezeigten Addon, wo jeder senden darf und die Liste der anderen überschreibt.
- Der Inhalt ist unvertraut (D-26): jedes Feld geprüft und gekappt wie beim Code-Import (Namen 48,
  Notizen 60, Items 1-9999999, höchstens 2000 Reservierungen, 100 Raider, Klassen nur aus der festen
  Liste); eine kaputte Liste ersetzt nichts. Farb- und Linkcodes werden entfernt.
- Fluten: `SV` höchstens alle 8 s je Absender, Wiederholung alle 240 s; `SQ` 15 s je Frager; eine Antwort
  je Frager in 30 s; bei drei oder mehr Fragern innerhalb 2 s eine Sendung in die Gruppe (wie `LV/LQ/LC`).
- Ansage und Erinnern nur in der Offiziersansicht und im Raid (wie heute); Offiziere bekommen eine
  fremde Liste nie ungefragt über ihre eigene.

## Daten

- **Nachrichtenarten** (Präfix wie `LV`/`LQ`, in ARCHITECTURE "Message kinds"):
  - `SV` Lootleitung/Offizier mit eigener Liste → Gruppe, 10 s nach einer Änderung, sonst alle 240 s,
    und beim Beitritt eines Mitglieds: Listen-ID (8 hex), Übernahmezeit (epoch), Stand (16 hex),
    Reservierungen; Stand `-` = gelöscht. Empfänger: Offizier, in Gruppe. Abstand 8 s.
  - `SQ` Empfänger → Absender WHISPER bei anderem Stand: Listen-ID, eigener Stand oder `-`. Empfänger:
    Mitglied, in Gruppe. Abstand 15 s.
- **Blob-Art** `SR`: Absender → WHISPER (drei und mehr Frager: Gruppe, niedrig); Empfänger: Offizier, in
  Gruppe, nur gefragt; höchstens 30 Teile;
  `{v = 1, id, at, d = Datum, sid, r = {{n = Name, c = Klasse, i = {Item-IDs, Doppelte wiederholt}, o = Notiz, p = +1}}, h = {{id, to, note}}}`.
- **`AmisiaDB.softres` Datenmodell 4:** neu `id` (Listen-ID), `at` (Übernahmezeit), `from` (Name des
  teilenden Offiziers, nur bei einer geteilten Liste), `offer` (eine angebotene Liste für Offiziere mit
  eigener, nur im Speicher, Frage 4); Migration 3 → 4 setzt `id`/`at` für eine vorhandene Liste.
  `classes` bekommt auch die CSV-Klassen.
- **Einstellungen** im Abschnitt `softres`: `softres.share` (an, Offiziere), `softres.announce` (an,
  Offiziere).
- **DECISIONS:** neue Entscheidung D-53 (Teilen nur von Offizieren an die Gruppe, ganze Liste,
  neueste gewinnt, Offiziere nur als Angebot; Klassen-Abgleich als Hinweis, nie Sperre).
- Keine Exportzeile, kein Einfügeblock, nichts auf der Website.

## Offene Fragen

1. **Wer teilt?** Vorschlag: jeder Offizier in der Offiziersansicht, der selbst eine Liste
   übernommen hat (nicht nur die gewählte Lootleitung), weil oft der Raidleiter importiert und ein
   anderer plündert. Alternative: nur die Lootleitung (`ns.IsLootLead`).
2. **Ansage beim Übernehmen automatisch?** Vorschlag: ja, im Raid, abschaltbar (`softres.announce`).
   Alternative: nur über den Chip "Ansagen".
3. **Tippfehler automatisch zuordnen?** Das gezeigte Addon ordnet Namen mit kleinem Tippfehler (bei
   passender Klasse auch größerem) selbst zu und schreibt "automatisch zugeordnet". Vorschlag: nein,
   wie bisher ein Klick auf den Vorschlag (er wird gemerkt, und eine falsche Zuordnung würde Loot
   falsch verteilen); nur die Reihenfolge der Vorschläge berücksichtigt die Klasse.
4. **Angebot an Offiziere mit eigener Liste:** Vorschlag: nur bis `/reload` merken (kein neues Feld
   auf Dauer); nach einem `/reload` kommt es mit dem nächsten `SV` ohnehin wieder.
5. **Geteilte Liste nach dem Raid:** Vorschlag: bleibt beim Raider, bis eine neue kommt oder die
   Lootleitung löscht, solange er in der Gruppe ist (die Altersanzeige `softres.warnDays` gilt wie
   heute). Alternative: beim Verlassen der Gruppe verwerfen.

## Entscheidungen

Noch keine.
