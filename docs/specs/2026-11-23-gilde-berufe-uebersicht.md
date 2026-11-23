# Spec: Berufe der Gilde: Übersicht, Material-Suche und Rezept-Wunsch

Stand: 2026-11-23 · Status: freigegeben ·
Feature: F-233

## Ziel

Offiziere und Handwerker wollen wissen, wo die Gilde bei den Berufen steht: wer welchen Beruf auf Höchstrang hat,
welche Rezepte niemand kann, und was die Gilde aus einem Material machen könnte. Spieler wollen erfahren, wenn jemand
ein gesuchtes Rezept lernt. Gelöst ist es, wenn das ohne Durchklicken einzelner Mitglieder geht. Ein verbreitetes
Gildenaddon für Berufe zeigt das (Recherche 2026-11-23); eigener Code. Alles beruht auf Daten, die Amisia schon hat:
dem Rezept-Austausch (F-035), den Gildennotizen (F-133) und den Berufsdaten.

## Was es tut

- **Auf der Übersicht der Seite Berufe (F-151)** auf jeder Kachel eine Zeile "Gilde", in der Reihe "Alle Berufe": Zahl
  der Mitglieder mit dem Beruf (davon mit Amisia), wie viele auf dem höchsten Rang stehen, der höchste Rang, und
  "Rezepte in der Gilde: 142 von 196". Darunter klein, woher es kommt: "Rezepte von 6 Mitgliedern mit Amisia; 11
  weitere laut Gildennotiz (ohne Rezepte)". Klick auf diese Zeile: der Beruf mit dem Filter "Gilde: Kann niemand".
- **Filter "Gilde" mit drei Stufen** statt des heutigen Chips "Gilde (N)": ein Dropdown wie "Bekannt" mit
  "Gilde: Alle", "Gilde: Kann jemand (N)", "Gilde: Kann niemand (N)".
- **Material-Suche:** auf der Seite Berufe oben neben der Suche ein Schalter "Rezepte | Aus Material". Im Modus "Aus
  Material" sucht das Feld nach Material-Namen (oder nimmt einen per Shift-Klick eingefügten Item-Link) und listet alle
  Rezepte aller Berufe, die es brauchen: Rezept, Beruf, Menge je Herstellung, ob du es kannst, wer in der Gilde
  (Namen wie in "Hergestellt von"). Klick: das Rezept mit Details wie sonst.
- **Tooltip-Zeile auf Materialien** (abschaltbar, Vorgabe: siehe Fragen): "Material für 12 Rezepte (Gilde kann 5)".
- **Rezept-Wunsch:** in den Details eines Rezepts, das niemand aus der Gilde kann, ein Knopf mit Glocke "Melden, wenn
  es jemand lernt". Die gemerkten Rezepte stehen im Reiter "Favoriten" in einem eigenen Block "Gesucht" mit
  "noch niemand" oder "kann jetzt: Ben". Lernt es ein Gildenmitglied (sein Rezept-Austausch bringt es), sagt der Chat
  einmal "Amisia: Ben kann jetzt [Rezept]." Ein zweiter Klick auf die Glocke nimmt den Wunsch heraus; erfüllte Wünsche
  bleiben stehen, bis man sie herausnimmt.
- `/amisia berufe gilde` öffnet die Übersicht bei den Kacheln.

## Was es ausdrücklich nicht tut

- Keine neue Nachricht und kein Senden: der Rezept-Wunsch ist privat, niemand in der Gilde sieht ihn (dafür gibt es
  die Gildenaufträge, F-231).
- Keine Rezepte aus Gildennotizen: eine Notiz nennt Beruf und Rang, nie Rezepte; solche Mitglieder zählen bei
  Mitgliedern und Rängen, nie bei "Rezepte in der Gilde".
- Keine Preise, kein Gewinn je Material (keine Auktionshauspreise, Nutzer 2026-11-06).
- Keine Liste je Mitglied (das ist F-182, Klick auf den Beruf auf Gilde > Mitglieder).

## Abläufe

1. Ein Offizier öffnet Berufe, Übersicht: unter "Alle Berufe" zeigt die Kachel Schmiedekunst "Gilde: 9 (4 mit
   Amisia), 2 auf 300, Rezepte 88 von 141". Klick: Schmiedekunst mit "Gilde: Kann niemand (53)".
2. Anna hat 20 Thorium und will wissen, was daraus geht: "Aus Material", tippt "Thorium" (oder Shift-Klick auf den
   Barren in der Tasche): die Liste zeigt Rezepte aus Schmiedekunst, Ingenieurskunst und Alchimie mit "Gilde: Ben".
3. Anna sucht "Rezept: Flask of the Titans"; niemand kann es. Sie klickt die Glocke. Wochen später lernt Clara es;
   sobald Claras Rezepte bei Anna ankommen (Rezept-Austausch), steht im Chat "Clara kann jetzt [Flask of the Titans]."
   und im Block "Gesucht" "kann jetzt: Clara".

## Abnahmekriterien

- Wenn du Berufe öffnest und kein Beruf gewählt ist, dann zeigt jede Kachel unter "Alle Berufe" die Zeile der Gilde mit
  Mitgliedern, Höchstrang und "Rezepte in der Gilde: N von M" (braucht: Gilde).
- Wenn du einen Beruf mit "Gilde: Kann niemand" filterst, dann bleiben nur Rezepte, die kein Gildenmitglied mit Amisia
  kann, und "N von M Rezepten" stimmt mit der Kachel überein (braucht: Gilde).
- Wenn du auf "Aus Material" schaltest und "Thorium" suchst, dann stehen alle Rezepte, die einen Thoriumbarren
  brauchen, mit Beruf und Menge.
- Wenn du bei einem Rezept die Glocke klickst und ein Gildenmitglied mit Amisia es später lernt, dann meldet der Chat
  "<Name> kann jetzt [Rezept]." einmal, und der Block "Gesucht" nennt den Namen (braucht: Gilde).
- Wenn du mit der Maus auf ein Material gehst und die Tooltip-Zeile an ist, dann steht dort "Material für N Rezepte".

## Sonderfälle

- **Niemand sonst mit Amisia:** die Kacheln sagen "Rezepte: nur deine eigenen" und zählen Mitglieder aus den Notizen;
  "Kann niemand" heißt dann "niemand mit Amisia" (Tooltip sagt es).
- **Twinks:** eigene Charaktere zählen mit, wie in "Hergestellt von"; ein Mitglied mit zwei Schmieden zählt einmal je
  Charakter.
- **Alte Daten:** Listen älter als 45 Tage fallen wie im Rezept-Austausch heraus; die Kachel nennt das Alter der
  ältesten verwendeten Liste nicht (zu viel Text), nur der Tooltip.
- **Höchstrang:** der Rang, den die Berufsdaten als höchsten kennen (heute 300), nicht das Limit des Lehrers.
- **Material, das in keinem Rezept steht:** "Kein Rezept braucht <Item>."; Shift-Klick auf ein Nicht-Material ebenso.
- **Client auf Englisch:** Suche nach dem Namen in der Sprache des Clients (Item-Namen aus dem Client, wie die Suche heute).
- **Ein Wunsch für ein Rezept, das man selbst lernt:** fällt still heraus.
- **TBC/Era:** nur wo die Seite Berufe läuft (Forever).

## Missbrauch/Vertrauen

Nichts Neues: keine Nachricht, kein Senden. Es gilt, was der Rezept-Austausch (F-035, D-12) an Prüfungen hat; die
Chatzeile des Rezept-Wunsches höchstens einmal je Rezept und Name und höchstens 10 je Stunde (ein Mitglied, das plötzlich
viele Rezepte meldet, flutet nicht).

## Daten

- **`AmisiaDB.prof.watch`** = `{[spell] = {at = Epoche des Wunsches, hit = Name oder nil, hitAt}}`, je Account,
  höchstens 50 Wünsche, nur Spells der Berufsdaten; geprüft beim Laden.
- **Einstellungen** im Abschnitt Berufe: `prof.reagentTooltip` (Tooltip-Zeile auf Materialien), `prof.watchChat`
  (Chatzeile beim Rezept-Wunsch, an).
- **Fensterstand** `settings.professions.guildFilter` (all/has/none) statt des heutigen Chip-Schalters (Migration:
  Chip an = "has").
- **Datenbau:** keine neuen Tabellen; der Rückwärtsindex Material -> Rezepte wird zur Laufzeit beim ersten Gebrauch aus
  `ProfessionData` gebaut (lazy, D-28).
- Keine neue Datei nötig: `Gear/Professions.lua` (Index), `Gear/Crafters.lua` (Ereignis "neuer Hersteller für ein
  Rezept"), `UI/Pages/Professions.lua`. ARCHITECTURE (AmisiaDB, Einstellungen) im selben Commit.

## Offene Fragen

1. **Tooltip-Zeile auf Materialien an oder aus als Vorgabe?** Vorschlag: aus (Tooltips sollen kurz bleiben); wer sie
   will, schaltet sie ein.
2. **Filter "Gilde" als Dropdown mit drei Stufen** statt des Chips? Vorschlag: ja, wie "Bekannt".
3. **Ort der Material-Suche:** Schalter auf der Seite Berufe (Vorschlag) oder eigener Reiter?
4. **Rezept-Wunsch auch für Rezepte, die schon jemand kann** (z. B. "sag Bescheid, wenn ein zweiter es lernt")?
   Vorschlag: nein, die Glocke nur bei "kann niemand".

## Entscheidungen

2026-11-23, Nutzer: "Passt, alle drei" zu den Vorschlägen:
1. Tooltip-Zeile auf Materialien: aus als Vorgabe.
2. Filter "Gilde" als Dropdown mit drei Stufen statt des Chips.
3. Material-Suche als Schalter "Rezepte | Aus Material" auf der Seite Berufe.
4. Glocke nur bei Rezepten, die niemand in der Gilde kann.
