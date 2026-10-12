# Spec: Raid-Check (Buffs & Verbrauch, Ausrüstung) und Raid-IDs

Stand: 2026-10-12 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-098 (Raid-Check), F-099 (Raid-IDs von Mains und Twinks); F-097 ist der Prüfbefehl
`/amisia selbsttest gruppe`. Einladen und Sortieren (Idee 10) stehen in der Spec
`2026-10-10-raid-aufstellung.md`, Teil C und D (F-084).

Vom Nutzer am 2026-10-12 gewählt (Recherche über Gilden-Addons, Ideen 1, 6, 9 und 10). Diese Spec
hat drei Teile: **A** Raid-Check "Buffs & Verbrauch", **B** Raid-Check "Ausrüstung", **C** Raid-IDs.
A und B sind ein Feature mit zwei Ansichten, C ein eigenes.

## Ziel

Vor dem Pull fragt heute jemand im Raid-Chat "alle Flask?", "wer hat noch Rot an der Rüstung?", und
keiner weiß, wer noch frei für einen zweiten Lauf ist. Mit Amisia sieht der Offizier auf einer Seite,
wem Fläschchen, Essen, wichtige Buffs, Haltbarkeit, Verzauberungen, Talentpunkte oder Amisia fehlen,
und vor dem Abend, welche Mains und Twinks der Gilde für eine Instanz noch keine Raid-ID haben.
Gelöst ist es, wenn ein Klick "Prüfen" vor dem Pull reicht und die Frage "wer kann noch mit?" ohne
Rundfrage beantwortet ist.

## Was es tut

### Wo es liegt

Vorschlag: eine neue Seite **"Raid-Check"** im Reiter Raid (nur Offiziersansicht mit Offiziersrang,
wie die Aufstellung, D-41) mit drei Schaltern oben: **Buffs & Verbrauch**, **Ausrüstung**,
**Raid-IDs**. Dazu auf der Seite Aufstellung je Name ein kleines Zeichen "ID" (grün frei, rot
gesperrt) für die Instanz, die der Offizier dort wählt. Befehl `/amisia raidcheck` (en `raidcheck`).
Alternative (Frage 1): die drei Ansichten als Schalter auf der Seite Aufstellung.

### Teil A: Buffs & Verbrauch

Eine Zeile pro Raider (Gruppe, Klasse, Name), Spalten:

| Spalte | Woher | Ohne Amisia beim Raider |
|---|---|---|
| Fläschchen | Buffs des Raiders (`C_UnitAuras`, außerhalb des Kampfes lesbar) | ja, aus den Buffs |
| Elixiere (Anzahl) | Buffs | ja |
| Essen ("Satt") | Buffs | ja |
| Wichtige Buffs (Intelligenz, Ausdauer, Mal der Wildnis, Segen, Willenskraft) | Buffs; nur Gruppen, deren Klasse im Raid ist | ja |
| Amisia-Version | die Versionsmeldung `HI` (gibt es schon, F-012) | "—" |

Ist ein Raider außer Sichtweite, liest der Client seine Buffs nicht: dann gelten die Angaben, die
seine Amisia selbst schickt (Fläschchen/Elixiere/Essen als Kürzel), sonst "außer Sicht".
Knopf **"Prüfen"** (fragt alle Amisia-Clients des Raids, liest alle Buffs neu). Fehlt etwas, ist die
Zelle rot; ein Tooltip nennt den Buff und die Restzeit. Oben eine Zeile "Es fehlt: 3 Fläschchen,
2 Essen, 1 Segen der Könige".

Optional (Einstellung, Standard **aus**, nur Offiziere): Knopf **"Im Raid-Chat sagen"** schreibt
eine Zeile wie "Amisia Raid-Check: Es fehlt: Fläschchen: Anna, Bert · Essen: Carl · Haltbarkeit
unter 30 %: Dora". Nur auf Klick, nie automatisch, nie in der Kampfsperre (Knopf dann grau; eine
Zeile, die wartet, verfällt nach 10 Sekunden), höchstens zwei Zeilen; im Text stehen nur Namen aus
der Raidliste und feste Wörter, nie Text aus einer Nachricht.

### Teil B: Ausrüstung

| Spalte | Woher | Ohne Amisia |
|---|---|---|
| Durchschnittliche Itemstufe (angelegt) | eigene Amisia: `GetAverageItemLevel` | "—" |
| Niedrigste Haltbarkeit (%) und Zahl der Items unter der Schwelle | eigene Amisia: `GetInventoryItemDurability` | "—" |
| Leere Plätze | eigene Amisia: `GetInventoryItemLink` | "—" |
| Fehlende Verzauberungen (Plätze) | eigene Amisia: Verzauberung im Itemlink, zur Sicherheit die Tooltip-Zeile Typ 15 | "—" |
| Freie Talentpunkte | eigene Amisia: wie die Seite Talente (`ns.Talents.Live`, Talentwährung "frei") | "—" |
| Stand | wann die Angabe kam ("vor 2 Min.") | |

Andere Spieler kann Amisia ohne "Betrachten" (Inspect) nicht lesen; Betrachten geht nur in der Nähe,
einzeln und gedrosselt. Darum meldet jede Amisia ihre eigenen Werte. Ohne Amisia steht "—" und im
Tooltip "Ohne Amisia: nur Buffs".

### Teil C: Raid-IDs

- Jede Amisia merkt sich beim Login und nach jedem Boss-Kill die Raid-IDs des eingeloggten Charakters
  (`RequestRaidInfo`, `GetSavedInstanceInfo`: Instanz, Schwierigkeit, Bosse, Reset) und behält sie
  für alle Charaktere des Kontos bis zum Reset.
- Sie teilt sie der Gilde mit: einmal nach dem Login, nach einer neuen ID und auf Frage eines
  Offiziers (eine Nachricht pro Charakter).
- Ansicht **Raid-IDs**: Instanz wählen (z. B. Geschmolzener Kern), dann Liste der Gilde, gruppiert
  nach Main (Twinks eingerückt, aus der Twink-Liste der Website, F-028): "frei", "gesperrt (4/10,
  Reset Mi 05:00)", "unbekannt" (keine Amisia). Filter "nur frei", "nur Stufe 60".
  Knopf "Raid-IDs abfragen" (höchstens alle 5 Minuten).
- Auf der Seite Aufstellung: "ID" grün/rot je Name für die dort gewählte Instanz; Tooltip mit
  Bossen und Reset; die Twinks des Mains, die noch frei sind.

### Wichtige Listen (aus den Client-Tabellen, nie aus dem Netz)

Ein neuer Builder `tools/build_raidcheck.py` macht `Data/RaidCheckData.lua` (lazy `RAIDCHECK`) aus
den Tabellen, die `tools/export_db2.ps1` schon exportiert (D-03):

- **Fläschchen:** Items der Klasse 0 Unterklasse 3 (Flask), über ItemXItemEffect und ItemEffect
  (Auslöser "Benutzen") die Zauber-ID = der Buff. Build 70338: 9 Fläschchen (5 klassische, 4 neue
  "Flask of Natural ...").
- **Elixiere:** Klasse 0 Unterklasse 2 (74 Items), ebenso; nur Zauber, die eine Aura mit Dauer ab
  10 Minuten anlegen (SpellEffect "Aura anlegen", SpellMisc/SpellDuration), damit Heiltränke und
  "Gift heilen" herausfallen.
- **Essen:** Klasse 0 Unterklasse 5 (318 Items): der Benutzen-Zauber ("Nutritious Food") löst über
  `EffectTriggerSpell` den Buff "Well Fed" aus (Build 70338: 30 Satt-Zauber). Getränke ohne Satt
  fallen heraus.
- **Klassen-Buffs:** eine kleine Namensliste im Builder (Arcane Intellect/Brilliance, Power Word:
  Fortitude/Prayer of Fortitude, Mark/Gift of the Wild, Blessings und Greater Blessings, Divine
  Spirit/Prayer of Spirit), aufgelöst gegen SpellName zu allen Rängen; je Gruppe die Klasse, die
  ihn gibt. Englische Namen nur im Builder; das Addon vergleicht Zauber-IDs (geht auf jedem Client).
- **Verzauberbare Plätze:** aus den Verzauber-Rezepten der Berufsdaten (`Data/ProfessionData.lua`,
  Beruf 333, Rezepte ohne Item) und ihren Zielplätzen; dafür fehlt noch die Tabelle
  `SpellEquippedItems` in `tools/export_db2.ps1` (Frage 4). Bis dahin eine feste Liste (Rücken,
  Brust, Handgelenke, Hände, Füße, Waffenhand, Schild).

## Was es ausdrücklich nicht tut

- **Kein Betrachten (Inspect)** fremder Spieler und kein Lesen fremder Ausrüstung: nur Selbstauskunft.
- **Kein Kampflog**, keine Prüfung im Kampf oder Bosskampf (Buffs sind dann geheim, D-20).
- **Keine Resistenzen, Waffenöle, Weltbuffs** in dieser Spec (später möglich, eigene Ergänzung).
- **Kein automatisches Flüstern** an Raider, keine automatische Chatzeile, kein Ton.
- **Kein Kick, keine Strafe, keine Punkte** für fehlende Buffs (DKP/EPGP bleibt unberührt).
- **Keine Bewertung der Ausrüstung** (dafür gibt es den Gear-Planer und "Wer braucht das?").
- **Raid-IDs anderer Gilden** und fremder Spieler: nein. Kein Eintrag auf der Website.
- **Einladen, Sortieren, "inv" per Flüstern, Assist für Offiziere:** nicht hier, sondern Spec
  2026-10-10 Teil C/D (F-084).

## Abläufe

### Raid-Check vor dem Pull

1. Der Offizier öffnet die Seite Raid-Check (oder startet einen Bereitschaftscheck im Spiel).
2. Amisia liest sofort die Buffs aller Raider in Sichtweite (außerhalb des Kampfes).
3. "Prüfen" (oder der Bereitschaftscheck) schickt eine Frage `XQ` an den Raid. Jede Amisia antwortet
   nach 0 bis 3 Sekunden mit `XA` an den Raid (Haltbarkeit, Itemstufe, leere und unverzauberte
   Plätze, freie Punkte, eigene Fläschchen/Elixiere/Essen). Beim Bereitschaftscheck antwortet jede
   Amisia einmal von selbst, ohne Frage.
4. Die Tabelle füllt sich; Raider ohne Amisia zeigen "—" bei Ausrüstung.
5. Optional: "Im Raid-Chat sagen".
6. Im Kampf: die Seite zeigt "Im Kampf: Werte von HH:MM" und liest nichts neu.

### Raid-IDs

1. Raider loggt ein: 60 bis 180 Sekunden später fragt Amisia die eigenen Raid-IDs ab und sendet für
   jeden Charakter des Kontos mit einer gültigen ID eine Zeile `IV` an die Gilde (leise, gedrosselt).
2. Ein Boss stirbt: nach dem Kampf (`UPDATE_INSTANCE_INFO`) eine neue `IV` für diesen Charakter,
   höchstens alle 5 Minuten.
3. Offizier: Ansicht Raid-IDs, Instanz wählen, liest die Liste. "Raid-IDs abfragen" schickt `IQ` an
   die Gilde; wer online ist, antwortet per Flüstern.
4. Nach dem Reset fallen die alten IDs von selbst weg.

## Abnahmekriterien

Allein heißt: mit Vulo Hunt (Offizier) und Vulo Pala desselben Kontos. Alles mit "(braucht: ...)"
ab 2026-11-04 (D-32), Raids ab 2026-12-09.

### Teil A und B (F-098)

- Wenn du allein (Offiziersansicht) mit Fläschchen und Essen die Seite Raid-Check öffnest, dann
  steht deine Zeile mit grünem Fläschchen und Essen; ohne Essen ist "Essen" rot. (allein)
- Wenn du "Ausrüstung" wählst, dann zeigt deine Zeile Itemstufe, niedrigste Haltbarkeit, leere und
  unverzauberte Plätze und freie Talentpunkte wie dein Charakterfenster. (allein)
- Wenn du im Kampf "Prüfen" klickst, dann steht "Nicht im Kampf" und nichts wird gesendet. (allein)
- Wenn ein Raider mit Amisia im Raid ist und du "Prüfen" klickst, dann steht nach höchstens
  5 Sekunden seine Haltbarkeit und Itemstufe da; ein Raider ohne Amisia hat "—". (braucht: Gruppe)
- Wenn die Chatzeile eingeschaltet ist und du "Im Raid-Chat sagen" klickst, dann steht im Raid-Chat
  eine Zeile "Amisia Raid-Check: Es fehlt: ..."; im Bosskampf ist der Knopf grau. (braucht: Raid)

### Teil C (F-099)

- Wenn Vulo Pala eine Raid-ID hat und du danach als Vulo Hunt einloggst, dann zeigt die Ansicht
  Raid-IDs für diese Instanz Vulo Pala "gesperrt" mit Bossen und Reset, Vulo Hunt "frei". (allein)
- Wenn der Reset vorbei ist, dann steht Vulo Pala wieder "frei" (nach dem nächsten Login). (allein)
- Wenn ein Gildenmitglied mit Amisia eine ID hat und du "Raid-IDs abfragen" klickst, dann steht es
  nach höchstens 30 Sekunden mit seinen Twinks in der Liste. (braucht: Gilde)
- Wenn du auf der Seite Aufstellung eine Instanz wählst, dann trägt jeder Name ein grünes oder
  rotes "ID", und der Tooltip nennt die freien Twinks seines Mains. (braucht: Gilde)

## Sonderfälle

- **Kampf, Bosskampf, Kampfsperre:** Buffs anderer sind im Kampf geheim (`SecretWhenUnitAuraRestricted`:
  Kampf, Bosskampf, Herausforderung, PvP). Amisia liest dann nichts, vergleicht keine geheimen Werte
  (`ns.Plain`) und zeigt die letzten Werte mit Uhrzeit. `XQ`/`XA`/`IV` warten nicht in der Sperre:
  eine Antwort, die nicht innerhalb von 10 Sekunden rausgeht, verfällt.
- **Bereitschaftscheck im Bosskampf:** das Ereignis ist dann geheim; Amisia antwortet nicht.
- **Außer Sichtweite, tot, offline:** "außer Sicht" / "tot" / "offline"; Selbstauskunft gilt, wenn sie
  höchstens 10 Minuten alt ist.
- **Stufe unter 60:** freie Talentpunkte sind normal; die Spalte zeigt sie grau.
- **Zweihandwaffe:** leere Schildhand zählt nicht als leer.
- **Twinks und Nachnamen:** Namen immer "Vorname Nachname" wie überall; Main aus der Twink-Liste.
  Ohne Twink-Liste stehen Charaktere eines Kontos nicht zusammen, nur "laut <Absender>".
- **Client auf Englisch:** Zauber-IDs statt Namen; Chatzeile in der Sprache des Senders.
- **Schlachtfeld:** nichts wird gesendet (D-19).
- **Zwei Offiziere fragen gleichzeitig:** Antworten gehen an den Raid, beide sehen sie; eine zweite
  Frage innerhalb von 10 Sekunden beantwortet niemand doppelt.
- **Login mitten im Raid, `/reload`:** die eigene Antwort kommt beim nächsten "Prüfen"; Raid-IDs werden
  nach dem Login neu gelesen.
- **Neue Client-Version:** die Listen kommen aus den Client-Tabellen; nach `export_db2.ps1` neu bauen.
- **Raid-Reset in Forever:** die Regeln (Tag, Uhrzeit, gemeinsame IDs) kennt niemand vor 2026-12-09;
  Amisia nimmt immer die Reset-Zeit, die das Spiel pro ID nennt.

## Missbrauch/Vertrauen

- **Fragen nur von Offizieren:** `XQ` und `IQ` beantwortet Amisia nur von einem geprüften Offizier
  (Rang laut Gildenliste, Rangrecht 22, D-18), `XQ` nur im eigenen Raid.
- **Selbstauskunft kann lügen:** wer Amisia ändert, kann sich 100 % Haltbarkeit geben. Die Spalten
  heißen darum "laut Amisia"; Buffs liest Amisia selbst. Keine Folge außer der Anzeige.
- **Fremde Raid-IDs:** ein Absender darf IDs nur für Charaktere melden, die in der Gildenliste stehen.
  Meldet ein Charakter selbst, gilt seine Angabe vor jeder anderen (eigene Daten vor gehörten, D-12).
  Ein Charakter, den die Twink-Liste einem anderen Main zuordnet als dem des Absenders, wird
  verworfen; sonst steht er grau "laut <Absender>".
- **Fluten und Größe:** Abstand pro Absender (`XQ` 10 s, `XA` 10 s, `IV` je Charakter 60 s, `IQ`
  300 s), jede Nachricht unter 250 Bytes, höchstens 12 Charaktere pro Absender, 300 Charaktere
  insgesamt, Werte außerhalb ihrer Grenzen verwerfen die ganze Nachricht.
- **Chatzeile:** nur Namen aus der Raidliste und feste Wörter; nie Text aus einer Nachricht; nur auf
  Klick des Offiziers.
- **Sichtbarkeit:** Ausrüstung und Raid-IDs sehen nur Offiziere (Vorschlag, Frage 7); Raider sehen
  nur ihre eigene Zeile.

## Daten

- **Neue Nachrichtenarten** (Präfix `Amisia`, keine neue Protokollnummer; ARCHITECTURE "Message kinds"):
  - `XQ` Offizier -> RAID ("Prüfen"): Frage-Kennung (4 hex). Vertrauen: Offizier, in der Gruppe.
    Abstand 10 s.
  - `XA` Raider -> RAID (auf `XQ` nach 0-3 s, einmal beim Bereitschaftscheck): Frage-Kennung oder `-`,
    niedrigste Haltbarkeit 0-100, Zahl unter der Schwelle, Itemstufe x10, leere Plätze (Platznummern
    mit Komma oder `-`), unverzauberte Plätze (ebenso), freie Talentpunkte 0-99, Verbrauch (`F` Fläschchen,
    `E<n>` Elixiere, `W` Satt, `-`). Vertrauen: Mitglied, in der Gruppe; gezeigt nur in der
    Offiziersansicht. Abstand 10 s, ttl 10 s.
  - `IV` jeder -> GILDE (60-180 s nach dem Login, nach einer neuen ID höchstens alle 5 Min., niedrige
    Priorität) oder FLÜSTERN als Antwort auf `IQ`: Charakter, Klasse, Stufe, bis zu 6 IDs
    `Instanz:Schwierigkeit:Reset-Epoche:getötet/gesamt`. Vertrauen: Mitglied; die Regeln oben.
    Abstand je Charakter 60 s (`KEYED_GAP`).
  - `IQ` Offizier -> GILDE ("Raid-IDs abfragen"): `-`. Vertrauen: Offizier. Abstand 300 s; Antwort
    per Flüstern nach 0-20 s, höchstens einmal in 10 Minuten pro Offizier.
- **Neuer Schlüssel** `AmisiaDB.raidcheck = { v = 1, own = { [Charakter] = { at, c = Klasse, l = Stufe,
  ids = { { m = Instanz, d = Schwierigkeit, r = Reset-Epoche, k = getötet, t = gesamt } } } },
  heard = { [Charakter] = { by, at, c, l, ids } } }`. Aufräumen beim Laden: IDs nach dem Reset weg,
  `own` Charaktere nach 60 Tagen ohne Login weg, `heard` nur in der Offiziersansicht, 30 Tage,
  300 Charaktere. Die Antworten des Raid-Checks (`XA`) leben nur im Speicher (bis der Raid endet,
  höchstens 30 Minuten).
- **Neuer Einstellungsabschnitt** `raidcheck` "Raid-Check": für alle `raidcheck.answer` ("Auf
  Raid-Check antworten", an), `raidcheck.lockouts` ("Raid-IDs der Gilde mitteilen", an); für Offiziere
  `raidcheck.chat` ("Chatzeile 'Es fehlt' anbieten", aus), `raidcheck.durability` (Schwelle, 30 %).
- **Neue Daten** `Data/RaidCheckData.lua` (Builder `tools/build_raidcheck.py`, lazy `RAIDCHECK`).
- Keine Exportzeile, kein Einfügeblock, nichts auf der Website. Neue Regel in DECISIONS (D-46).

## Offene Fragen

1. **Wo?** Vorschlag: eigene Seite "Raid-Check" im Reiter Raid mit drei Ansichten, dazu das
   "ID"-Zeichen auf der Seite Aufstellung. Alternative: alles als Ansichten der Aufstellung.
2. **Was zählt als "versorgt"?** Vorschlag: ein Fläschchen **oder** mindestens ein Elixier, dazu
   Essen (Satt). Strenger: Fläschchen Pflicht.
3. **Welche Klassen-Buffs?** Vorschlag: Intelligenz, Ausdauer, Mal der Wildnis, Willenskraft und die
   Segen (Könige, Macht, Weisheit, Rettung), jeweils nur, wenn die Klasse im Raid ist. Fehlt einer
   Gruppe ein Buff, den keiner im Raid geben kann, wird er nicht gezählt.
4. **Verzauberbare Plätze:** Vorschlag: Tabelle `SpellEquippedItems` in `tools/export_db2.ps1`
   aufnehmen (der Nutzer exportiert einmal), bis dahin die feste Liste. Kopf, Beine, Schultern
   (Verzauberungen aus Ruf oder Quests) erst einmal nicht zählen?
5. **Haltbarkeit:** Vorschlag: rot unter 30 %, orange unter 50 %, einstellbar.
6. **Chatzeile:** so lassen (Standard aus, nur Klick, nur Offiziere, Text wie oben)?
7. **Wer sieht was?** Vorschlag: Ausrüstung und Raid-IDs nur Offiziere. Alternative: Raid-IDs für
   die ganze Gilde (wie der Raid-Kalender, D-43), damit Raider selbst Twink-Läufe planen.
8. **Twinks melden:** Vorschlag: Amisia meldet alle Charaktere des Kontos (wie die Anmeldung,
   F-087), abschaltbar mit `raidcheck.lockouts`.
9. **Antwort beim Bereitschaftscheck von selbst:** Vorschlag ja (eine Nachricht pro Raider).
10. **Reihenfolge:** Vorschlag: erst `/amisia selbsttest gruppe` (F-097, gebaut) laufen lassen und den
    Bericht schicken; dann Teil A und B (allein prüfbar bis auf andere Raider), dann Teil C; Einladen
    und Sortieren (F-084) parallel nach Spec 2026-10-10.

Prüfungen im Spiel (die ersten drei macht `/amisia selbsttest gruppe` allein):

11. **Eigene Buffs und Geheimhaltung:** mit Fläschchen und Essen `/amisia selbsttest gruppe`, dann
    an einer Übungspuppe im Kampf noch einmal. Erwartet: außerhalb "Eigene Buffs: N gelesen, 0
    geheim" mit Zauber-IDs; im Kampf geheim. Stimmen die Zauber-IDs mit den Fläschchen-Items überein?
12. **Verzauberung erkennen:** mit einem verzauberten Item: steht "Verzauberung im Link <Zahl>" und
    eine Zeile Typ 15? Welche Zeilenarten zeigt "Zeilenarten gesehen"?
13. **Raid-IDs:** nach einem Boss-Kill in einem Dungeon: zeigt "Raid-IDs" Name, ID, Instanz (die
    14. Rückgabe, Karten-ID), Schwierigkeit, Bosse und Reset? Kommt `UPDATE_INSTANCE_INFO`?
14. **Buffs anderer (braucht: Gruppe):** einen Gruppenpartner anwählen und den Prüfbefehl: "Ziel:
    sichtbar true, N Buffs gelesen, 0 geheim"? Dann aus 50 und aus 200 Metern
    `/dump UnitIsVisible("party1"), C_UnitAuras.GetAuraDataByIndex("party1", 1, "HELPFUL")`.
15. **Bereitschaftscheck (braucht: Gruppe):** `/etrace` beim Bereitschaftscheck außerhalb des Kampfes:
    kommen `READY_CHECK`, `READY_CHECK_CONFIRM`, `READY_CHECK_FINISHED`, und sind ihre Werte lesbar?
16. **Talentpunkte:** stimmt "frei N" des Prüfbefehls mit dem Talentfenster überein (auch auf Stufe 60
    mit 0 freien)?
17. **Raid-Reset (ab 2026-12-09):** wann setzt Forever Raid-IDs zurück, und teilen sich Schwierigkeiten
    eine ID?

## Entscheidungen

- 2026-10-12: Nutzer wählt nach der Recherche über Gilden-Addons die Ideen 1 (Raid-Check vor dem
  Pull), 6 (Ausrüstungs-Check des Raids), 9 (Raid-IDs von Mains und Twinks) und 10 (Einladen und
  Sortieren mit "inv" per Flüstern und automatischem Assist für Offiziere, in der Spec 2026-10-10
  Teil C/D). Diese Spec für 1, 6 und 9 geschrieben; noch nicht freigegeben. Vorher gebaut: der
  Prüfbefehl `/amisia selbsttest gruppe` (F-097).
- 2026-10-12: Nutzer gibt frei ("ja mach deine Vorschläge"): eigene Seite "Raid-Check" im Reiter
  Raid; versorgt = Fläschchen oder mindestens ein Elixier, dazu Essen; Haltbarkeit rot unter 30 %,
  orange unter 50 %; beim Bereitschaftscheck meldet Amisia die Ausrüstung von selbst; Chatzeile wie
  vorgeschlagen (aus, nur Offiziere, nur per Klick, nie in der Sperre); alle Charaktere des Kontos
  melden ihre Raid-IDs. Frage "Raid-IDs für wen" hatte keinen Vorschlag: angenommen **nur
  Offiziere** (wie die Zahlen anderer Spieler, D-36); jeder sieht seine eigenen. Die übrigen Fragen
  nach den Vorschlägen der Spec. Einladen und Sortieren (Spec 2026-10-10 Teil C/D) folgen nach dem
  Bericht von `/amisia selbsttest gruppe`.
