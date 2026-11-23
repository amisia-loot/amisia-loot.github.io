# Spec: Berufs-Abklingzeiten (eigene Charaktere und Gilde)

Stand: 2026-11-23 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-232

## Ziel

Rezepte mit langer Abklingzeit (Transmutationen, Mondstoff) verschenken Ertrag, wenn man vergisst, sie zu nutzen, und
wer Arkanit braucht, weiß nicht, wer in der Gilde gerade transmutieren kann. Gelöst ist es, wenn man auf einen Blick
sieht, welche eigenen Charaktere (auch Twinks) und welche Gildenmitglieder heute "bereit" sind, und beim Einloggen
daran erinnert wird. Zwei verbreitete Gildenaddons zeigen das (Recherche 2026-11-23); eigener Code.

## Was es tut

- **Neuer Reiter "Abklingzeiten" auf der Seite Berufe** (nach "Route"), zwei Blöcke:
  - "Deine Charaktere": je Charakter des Accounts (gleicher Realm) und Abklingzeit eine Zeile: "Transmutation",
    "Mondstoff" mit grün "bereit" oder "in 14 Std. 20 Min." und dem Rezept, das sie zuletzt auslöste.
  - "Gilde": je Abklingzeit die Gildenmitglieder mit Amisia, erst die bereiten (grün), dann nach Restzeit; Name in
    Klassenfarbe, online zuerst; Klick: das Menü mit Flüstern wie auf der Mitgliederseite.
- **Chatzeile beim Einloggen** (abschaltbar): "Amisia: bereit: Transmutation (Anna), Mondstoff (Annatwink)." nur für
  eigene Charaktere, einmal je Sitzung.
- **Tooltip** eines Items, das ein Rezept mit Abklingzeit macht (z. B. Arkanitbarren, Mondstoff), unter der bisherigen
  Zeile "Hergestellt von" (F-035): "Bereit in der Gilde: Ben, Clara" (nur wenn jemand bereit ist).
- `/amisia abklingzeiten` öffnet den Reiter; im Chat die eigenen Zeilen, wenn das Fenster nicht aufgeht.

Welche Rezepte eine Abklingzeit haben, sagt der Datenbau (Client-Tabellen `SpellCooldowns`, `SpellCategories`, heute
schon für die Route genutzt: 15 Rezepte in `ProfessionData` `CD`). Rezepte mit gemeinsamer Kategorie (alle
Transmutationen: Kategorie 310) bilden eine Zeile "Transmutation"; die Restzeit liest Amisia aus dem Spiel, nicht aus
den Tabellen. Angezeigt werden Abklingzeiten ab 20 Stunden (Arkanit, "Transmute: Legionite" (1317279, neu auf Forever) und die
Elementtransmutationen: 23-47 Std., Mondstoff 95 Std.); kürzere (Eisen zu Gold 1 Std., Elementarfeuer 10 Min.) nicht.

## Was es ausdrücklich nicht tut

- Keine Gegenstands-Abklingzeiten (Salzstreuer u. Ä.), keine Abklingzeiten von Zaubern oder Ruhesteinen.
- Kein Wecker und kein Ton; nur die Login-Zeile.
- Keine Charaktere anderer Realms oder der anderen Fraktion in "Deine Charaktere".
- Nichts auf der Website, kein Export.

## Abläufe

1. Anna (Alchimistin) loggt sich ein. Amisia liest für jedes bekannte Rezept mit Abklingzeit die Restzeit aus dem Spiel
   (beim Login, nach jedem Herstellen, beim Öffnen des Berufsfensters) und speichert sie als Zeitpunkt "bereit ab".
2. Sie transmutiert Arkanit: die Zeile "Transmutation" springt auf "in 47 Std.". Amisia sagt der Gilde den neuen Stand
   (`PC`, höchstens einmal je Minute) mit allen eigenen Charakteren dieser Gilde.
3. Ben öffnet Berufe > Abklingzeiten und sieht unter "Gilde", "Transmutation": Clara "bereit", Anna "in 47 Std.".
   Er flüstert Clara über den Namen.
4. Zwei Tage später loggt Anna mit ihrem Twink ein: "Amisia: bereit: Transmutation (Anna), Mondstoff (Annatwink)."

## Abnahmekriterien

- Wenn du ein Rezept mit Abklingzeit herstellst (z. B. eine Transmutation), dann zeigt Berufe > Abklingzeiten bei
  deinem Charakter "Transmutation" mit der Restzeit des Spiels (auf eine Minute genau).
- Wenn du dich mit einem Twink einloggst, dann steht unter "Deine Charaktere" auch dein anderer Charakter mit seinem
  gespeicherten Stand, und ist er bereit, nennt ihn die Login-Zeile.
- Wenn ein Gildenmitglied mit Amisia ein Rezept mit Abklingzeit kann, dann steht es binnen etwa 4 Minuten nach seinem
  Login unter "Gilde" mit "bereit" oder der Restzeit (braucht: Gilde).
- Wenn du mit der Maus auf einen Arkanitbarren gehst und jemand in der Gilde bereit ist, dann nennt der Tooltip
  "Bereit in der Gilde: <Namen>" (braucht: Gilde).
- Wenn du `/amisia selbsttest` öffnest, dann sagt die Zeile "Abklingzeit eines Rezepts", ob das Spiel die Restzeit auch
  bei geschlossenem Berufsfenster liefert.

## Sonderfälle

- **Restzeit nur bei offenem Berufsfenster:** liefert das Spiel sie ohne Fenster nicht (`C_Spell.GetSpellCooldown` für
  ein Rezept), gilt der letzte gelesene Stand; der Selbsttest zeigt, was der Client kann. Herstellen liest immer.
- **Uhren:** gesendet wird die Restzeit in Sekunden, nie ein Zeitpunkt; der Empfänger rechnet mit seiner eigenen Uhr.
- **Zeit im Spiel vs. Realzeit:** Abklingzeiten laufen auch offline; ein gespeicherter Stand eines Twinks gilt, bis sein
  Zeitpunkt vorbei ist ("bereit").
- **Rezept verlernt / Beruf gewechselt:** beim nächsten Lesen des Berufs fällt die Zeile weg.
- **Mitglied verlässt die Gilde:** fällt beim nächsten Roster heraus; gehörte Stände ohne neue Nachricht nach 7 Tagen.
- **Kampfsperre, Instanz, Schlachtfeld:** wie der Rezept-Austausch (F-035): nichts in der Sperre oder im Schlachtfeld,
  aus einer Instanz 5-15 s nach dem Verlassen.
- **Client auf Englisch:** gesendet werden Spell-Nummern; der Name "Transmutation"/"Transmute" kommt aus der Locale.
- **TBC/Era:** nur wo die Seite Berufe läuft (Forever).

## Missbrauch/Vertrauen

- Nur GUILD, nur Gildenmitglieder nach dem Roster; Charaktere in der Nachricht müssen im Roster stehen, sonst wird der
  Eintrag verworfen; der eigene Bericht eines Charakters gilt vor dem eines anderen Absenders (wie `AC`, F-210).
- Jedes Feld geprüft: nur Spell-Nummern aus `ProfessionData` `CD`, Restzeit 0 bis 400000 s, höchstens 10 Charaktere
  und 4 Abklingzeiten je Charakter, Nachricht unter 250 Bytes; ein Fehler verwirft die ganze Nachricht.
- Falsche Angaben über sich selbst sind möglich (man flüstert dann umsonst); sonst kann niemand etwas auslösen.
- Höchstens 300 gehörte Charaktere; Abstand je Absender 60 s.

## Daten

- **Nachrichtenart `PC`** (profession cooldowns), jeder Amisia-Nutzer -> GUILD: 60-180 s nach dem Login (low), nach
  einer eigenen Änderung (höchstens einmal je 60 s), nie beantwortet. Felder: `1`, dann bis zu 10 Einträge
  `<Charakter>:<spell>=<Sekunden>[,<spell>=<Sekunden>]` (spell = das Rezept, das zuletzt auslöste, oder das erste
  bekannte der Kategorie; Sekunden 0 = bereit). Abstand 60 s je Absender.
- **`AmisiaDB.prof.cd`** = `{[eigener Charakter] = {realm, faction, [spell] = bereit-ab-Epoche}}` und
  **`AmisiaDB.prof.cdHeard`** = `{[Name] = {by, at, [spell] = bereit-ab-Epoche}}`, geprüft beim Laden (7 Tage, 300
  Namen, nur `CD`-Spells).
- **Datenbau:** `ProfessionData` `CD` trägt künftig je Spell die Kategorie und die Dauer in Stunden
  (`[17187] = "310:47"`), damit die Seite gruppieren und unter 20 Std. weglassen kann (`tools/build_professions.py`).
- **Einstellungen** im Abschnitt Berufe: `prof.cdLogin` (Login-Zeile, an), `prof.cdShare` (mit der Gilde teilen, an),
  `prof.cdTooltip` (an).
- Neue Datei `Amisia/Gear/ProfCooldowns.lua`; Reiter in `UI/Pages/Professions.lua`; Selbsttest-Zeile. ARCHITECTURE und
  eine Entscheidung D-163 im selben Commit.

## Offene Fragen

1. **Grenze 20 Stunden?** Vorschlag: ja, kürzere sind im Spiel selbst sichtbar und nicht planbar.
2. **Mit der Gilde teilen an als Vorgabe?** Vorschlag: an (sonst sieht keiner etwas), abschaltbar.
3. **Twinks mitsenden?** Vorschlag: ja, nur Twinks derselben Gilde (wie `AC`); wer das nicht will, schaltet Teilen aus.
4. **Ort:** Reiter auf Berufe (Vorschlag) oder Spalte auf Gilde > Mitglieder?

## Entscheidungen

Noch keine.
