# Spec: Seite Mitglieder (Gilde)

Stand: 2026-10-16 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-104

## Ziel

Auftrag des Nutzers (2026-10-16): "bei Gilde ein tab member oder so ... mit Name lvl Ort berufe usw",
als Bild eine Charakterliste mit Porträt, Name, Stufe und Klasse, Ort, Zeit und Berufen mit Skill.
Auf einen Blick: wer ist in der Gilde, wie weit, wo, seit wann weg, und wer kann welchen Beruf.

## Was es tut

- **Seite "Mitglieder"** im Reiter Gilde (für alle Ansichten), eine Zeile je Gildenmitglied, in der Art
  des Bildes, mit den Teilen aus `UI/Theme.lua`:
  - links ein rundes Klassen-Symbol (das Spiel nennt Volk und Geschlecht anderer nicht, darum kein
    Gesicht wie im Bild);
  - **Name** in Klassenfarbe, darunter **Stufe, Klasse und Rang**;
  - **Ort** (Zone aus der Gildenliste), darunter **online** (grün) oder **"zuletzt vor 2 Tagen 19 Stunden"**;
  - **Berufe mit Skill** als Symbol und Balken wie im Bild (bis zu zwei Haupt- und drei Nebenberufe), aus
    dem Rezept-Austausch (F-035, `AmisiaDB.crafters`): nur bei Mitgliedern mit Amisia, sonst leere
    Felder; die eigenen Charaktere immer.
  - Tooltip der Zeile: öffentliche Notiz, (Offiziere) Offiziersnotiz, Main/Twinks aus der Twink-Liste.
- **Kopfzeile:** Dropdown **Klasse**, Dropdown **Beruf** (wie im Bild), Schalter **"nur online"**, Suche
  nach Namen; Sortieren nach Name, Stufe, Ort, zuletzt online (Klick auf die Spaltenköpfe).
- **Maus auf einem Beruf:** "Alchemie 225/300, 84 Rezepte, Stand vor 3 Tagen".
- **Klick auf eine Zeile:** Menü mit Flüstern und Einladen.
- Unten: "N Mitglieder, M online, K mit Amisia".

## Was es ausdrücklich nicht tut

- **Kein Gold und keine Erfahrungsleiste anderer:** das Spiel gibt beides nicht her; es zu verschicken
  bräuchte eine neue Nachricht und ist bei Gold Privatsache. (Für die eigenen Charaktere siehe Frage 3.)
- Keine Gildenverwaltung (befördern, Notizen schreiben, entfernen): das kann das Spielfenster.
- Kein Gildenbuch (Beitritte, Austritte, Rangwechsel mitschreiben): eigenes Feature, wenn gewünscht.
- Keine neue Addon-Nachricht: Berufe kommen aus dem bestehenden Handwerker-Austausch (PV/PQ/PW/PK).

## Abläufe

1. Spieler öffnet Amisia, Reiter Gilde, Seite Mitglieder: Amisia fragt die Gildenliste an
   (`ns.RequestGuildRoster`), zeigt sie, sobald sie da ist, sortiert nach "online zuerst, dann Name".
2. Er wählt Klasse "Priester" und Beruf "Alchemie": nur Priester mit bekannter Alchemie bleiben.
3. Er fährt über die Alchemie eines Treffers (Skill, Rezeptzahl, Stand) und klickt "Flüstern".
4. Ein Mitglied loggt sich ein: die Zeile wird beim nächsten Gildenlisten-Ereignis grün (gebündelt,
   höchstens alle 10 s neu gebaut wie `ns.GuildRoster`).

## Abnahmekriterien

- Wenn du im Reiter Gilde "Mitglieder" öffnest, dann steht dort jedes Gildenmitglied mit Name in
  Klassenfarbe, Stufe, Klasse, Rang und Ort; wer online ist, zuerst und grün. (braucht: Gilde)
- Wenn ein Mitglied offline ist, dann steht unter dem Ort "zuletzt vor …" wie im Gildenfenster des Spiels. (braucht: Gilde)
- Wenn ein Gildenmitglied mit Amisia Berufe hat, dann zeigt seine Zeile sie mit Skill (z. B. "Alchemie 225");
  deine eigenen immer. (braucht: Gilde)
- Wenn du Klasse oder Beruf im Dropdown wählst oder "nur online" anhakst, dann bleiben nur passende Zeilen,
  unten steht die Zahl.
- Wenn du eine Zeile anklickst und "Flüstern" wählst, dann steht "/w Name " in der Chatzeile.

## Sonderfälle

- **Bosskampf/Kampfsperre:** die Gildenliste kann geheime Werte liefern; die Seite zeigt dann den letzten
  Stand und baut erst nach der Sperre neu (wie `ns.GuildRoster`).
- **Kein Gildenmitglied:** die Seite fehlt im Reiter (wie Gildenbank) oder sagt "Du bist in keiner Gilde."
- **Große Gilde (1000):** virtuelle Liste (`W.List`), nur sichtbare Zeilen werden gefüllt.
- **Berufe veraltet:** der Rezept-Austausch hält Einträge 45 Tage; die Zeile zeigt das Alter im Tooltip.
- **Twinks:** jeder Charakter eine Zeile; der Tooltip nennt Main/Twinks (Frage 4).
- Englischer Client: Klassen-, Rang- und Zonennamen kommen vom Client.

## Missbrauch/Vertrauen

Nichts Neues: keine neue Nachricht. Berufe stammen aus dem Handwerker-Austausch mit dessen Regeln
(nur Gildenmitglieder, Drossel, Deckel, D-18/D-19); Offiziersnotizen zeigt die Seite nur, wenn der
Client sie dem Spieler ohnehin zeigt (`C_GuildInfo.CanViewOfficerNote`).

## Daten

- Keine neue Nachricht, keine Exportzeile.
- Neuer Code: `UI/Pages/Members.lua` (Seite), Zone und "zuletzt online" in der Gildenliste
  (`Core/Trust.lua`: `zone`, `last` aus `GetGuildRosterInfo`/`GetGuildRosterLastOnline` bzw. `C_Club`).
- Gespeichert: nur die Filter der Seite im Fensterzustand (`settings.window.members`); bei Frage 3 "ja"
  zusätzlich `AmisiaDB.chars` (je eigener Charakter: Stufe, Klasse, Volk, Ort, Gold, Erfahrung, Ruhe-EP,
  Berufe, Zeit), dann neue Zeile in ARCHITECTURE.

## Offene Fragen

1. Name der Seite: **"Mitglieder"** (Vorschlag) oder "Gildenliste"?
2. Wer sieht sie: **alle** (Vorschlag) oder nur Offiziere?
3. Zusätzlich ein Schalter **"Meine Charaktere"** genau wie im Bild: deine eigenen Charaktere mit
   Gesicht, Erfahrungsleiste in %, Gold und Ruhe-Zeit (merkt sich jeder Charakter beim Einloggen, nur auf
   deinem PC)? Vorschlag: **ja**, als zweite Ansicht derselben Seite.
4. Twinks: **jeder Charakter eine Zeile, Main/Twinks im Tooltip** (Vorschlag) oder Twinks unter ihrem
   Main eingerückt?

## Entscheidungen

Nichts.
