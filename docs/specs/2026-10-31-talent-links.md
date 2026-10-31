# Spec: Talent-Builds aus Links der Talentrechner-Seiten übernehmen

Stand: 2026-10-31 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-127

## Ziel

Builds für Forever werden meist als Link der beiden Talentrechner-Seiten talentsforever.com und
wowforevertalents.com geteilt (Discord, Gildenchat). Heute muss man so einen Build Punkt für Punkt
nachklicken, weil Amisias Talentrechner nur den eigenen Code `AT1.KLASSE.x.y.z` versteht. Gelöst ist es,
wenn man den Link ins Code-Feld einfügt, Enter drückt und der Plan steht.

Export und Import des eigenen Codes gibt es schon (F-081, F-121: Feld "Code", `/amisia talente <Code>`).
Neu ist nur, dass dieselben Wege auch die beiden Link-Formate lesen.

## Was es tut

- **Code-Feld** auf der Seite Talente und im Fenster Talentrechner: Ein eingefügter Link einer der beiden
  Seiten wird wie ein Amisia-Code übernommen, in den gerade gewählten Plan (Primär oder Sekundär). Die
  Chatmeldung ist dieselbe wie beim eigenen Code: "Code übernommen: Magier, 51 Punkte."
- **`/amisia talente <Link>`** übernimmt einen Link genauso.
- Danach zeigt das Code-Feld wie immer den Amisia-Code des Plans, zum Weitergeben im Spiel.
- **Stufe:** wie beim Amisia-Code: Reichen die Punkte der eingestellten Stufe nicht, hebt der Rechner
  die Stufe so weit an, dass der Build passt. Die Stufe im Link von talentsforever.com wird überlesen.
- **Fehlermeldungen** im Chat, wie beim eigenen Code: unbekannte Klasse, Build passt nicht zu den
  aktuellen Bäumen (zu viele Talente oder ein Rang zu hoch, etwa nach einem Talent-Patch), Voraussetzung
  verletzt, mehr Punkte als die Bäume erlauben (51). Der Plan bleibt dann, wie er war.
- Der Tooltip des Code-Felds nennt, dass auch Links der Talentrechner-Seiten gehen (Wortlaut: Frage 1).

## Was es ausdrücklich nicht tut

- **Kein Export als Link** der Seiten. DECISIONS D-02 verbietet Links auf Fanseiten, auch als
  kopierbaren Text. Exportiert wird weiter nur der Amisia-Code.
- **Keine Abfrage der Seiten.** Amisia liest nur den eingefügten Text. Kein Skript lädt etwas von den
  Seiten (D-03 sinngemäß), auch nicht für Tests: Beispiel-Links liefert der Nutzer (Frage 3).
- **Keine Lernreihenfolge.** talentsforever.com kann die Reihenfolge der Punkte mitschicken. Amisias
  Plan kennt keine Reihenfolge; dieser Teil wird überlesen.
- **Keine Builds anderer Addons** (deren eigene Build-Texte). Nur die beiden Seiten und der Amisia-Code.
- **Kein Erkennen im Chat.** Ein Link in einer Chatzeile wird nicht anklickbar gemacht.
- **Nichts auf TBC/Era.** Der Talentrechner ist ein Forever-Teil (D-57).

## Abläufe

1. Ein Spieler kopiert aus Discord einen Build-Link, öffnet in Amisia die Seite Talente (oder das große
   Fenster), wählt Primär oder Sekundär, klickt ins Feld "Code", fügt mit Strg+V ein und drückt Enter.
2. Amisia erkennt die Seite am Text, liest Klasse und die drei Bäume (eine Ziffer pro Talent, Rang, in
   der Reihenfolge Zeile/Spalte, wie im Amisia-Code) und baut den Plan nach den Regeln neu auf, wie beim
   eigenen Code (`T.Decode`).
3. Der Rechner wechselt auf die Klasse des Builds, die Bäume zeigen ihn, der Chat meldet die Übernahme.
   Das Code-Feld zeigt den Amisia-Code. Andere Spieler merken nichts.

Formate, wie sie die Seiten heute schreiben (aus Beispielen abzusichern, Frage 3):

- `talentsforever.com/<klasse>/<stufe>/<baum1>-<baum2>-<baum3>[-<reihenfolge>]-<version>`
- `wowforevertalents.com/<klasse>/?t=<Versionsbuchstabe><baum1>-<baum2>-<baum3>`

Jeder Baum ist eine Ziffernfolge, Nullen am Ende fehlen; ein leerer Baum ist leer. Mit oder ohne
`https://` und `www.`, Groß- und Kleinschreibung egal, Leerzeichen um den Link herum egal.

## Abnahmekriterien

- Wenn du einen Link von talentsforever.com in das Feld "Code" der Seite Talente einfügst und Enter
  drückst, dann zeigen die Bäume genau den Build der Seite (gleiche Talente, gleiche Ränge, gleiche
  Punkte je Baum), der Chat meldet "Code übernommen: <Klasse>, <Punkte> Punkte." und im Feld steht ein
  `AT1.`-Code.
- Wenn du dasselbe mit einem Link von wowforevertalents.com machst, dann gilt dasselbe.
- Wenn du `/amisia talente <Link>` eingibst, dann öffnet sich die Seite Talente mit diesem Build.
- Wenn du im Plan Sekundär einen Link übernimmst, dann bleibt Primär unverändert (auch nach `/reload`).
- Wenn du einen Link mit einem Fehler einfügst (z. B. eine Ziffer zu viel im ersten Baum), dann steht im
  Chat, warum es nicht geht, und der Plan bleibt, wie er war.

## Sonderfälle

- **Talent-Patch:** Ändert Blizzard einen Baum, passen alte Links nicht mehr (Zahl der Talente oder
  Höchstränge). Dann gibt es die Fehlermeldung, nie einen halb übernommenen Plan. Der Versionsbuchstabe
  bzw. die Versionsnummer im Link wird gelesen, aber nicht ausgewertet (Frage 2).
- **Reihenfolge der Bäume:** Amisia ordnet die Bäume wie das Spiel. Weicht eine Seite davon ab, braucht
  sie eine Zuordnung pro Klasse. Das zeigen die Beispiel-Links (Frage 3).
- **Klassenname:** Die Seiten schreiben die Klasse englisch und klein (`mage`, `warlock`). Amisia liest
  das unabhängig von der Sprache des Clients.
- **Andere Klasse als der eigene Charakter:** geht, wie beim Code; "Eigene laden" holt den eigenen
  Build zurück.
- **Kampf:** Der Rechner ändert nichts an echten Talenten, also keine Kampfsperre.
- **Lange Eingabe:** Das Feld hat keine Längengrenze; ein Link passt hinein, wird aber abgeschnitten
  angezeigt (Frage 4).

## Missbrauch/Vertrauen

Der Link ist eingefügter, unvertrauter Text. Er wird Zeichen für Zeichen geprüft (nur Ziffern,
`-`, Buchstaben für Klasse und Version), jeder Rang gegen den Höchstrang und jede Voraussetzung gegen
die Regeln, wie beim Amisia-Code. Er ändert nur den eigenen Plan, nichts wird gesendet oder ausgeführt.
Keine neue Nachricht, kein Austausch mit anderen Spielern.

## Daten

Nichts Neues: kein `AmisiaDB`-Schlüssel, keine Einstellung, keine Nachricht, keine Exportzeile. Der Plan
landet wie bisher in `AmisiaDB.talents.plans` bzw. `plans2`. Neue Texte in `L[...]` mit Englisch in
`Locales/enUS_gear.lua`. In `docs/DECISIONS.md` ein Nachtrag zu D-02: Die beiden Seiten dürfen im Code
als erkannte Formate stehen (ohne `http`-Link), Export als Link bleibt verboten.

## Offene Fragen

1. **Seitennamen in Amisia:** Darf der Tooltip die beiden Seiten nennen ("Auch Links von talentsforever.com
   und wowforevertalents.com gehen")? Vorschlag: ja, nur als Name ohne `https://`, weil der Spieler
   sonst nicht weiß, welche Links gehen. Alternativ allgemein: "Auch Links der Talentrechner-Seiten".
2. **Alte Links nach einem Patch:** Nur ablehnen, wenn sie nicht mehr passen (Vorschlag), oder zusätzlich
   warnen, wenn die Version im Link nicht die neueste ist? Dafür müsste Amisia die aktuelle Version der
   Seiten kennen; das geht ohne Abfrage nicht verlässlich.
3. **Beispiel-Links:** Kannst du je Seite zwei bis drei Links schicken (am besten verschiedene Klassen,
   einer mit leerem Baum, einer von talentsforever.com mit Reihenfolge) und dazu sagen, wie viele Punkte
   in welchem Baum stehen? Sie kommen als Testfälle in die Lua-Tests. Vorschlag: ja, sonst baue ich nach
   den bekannten Formaten und wir prüfen im Spiel.
4. **Feldbreite:** Das Code-Feld ist schmal; ein Link wird darin abgeschnitten angezeigt, geht aber ganz
   hinein. Reicht das (Vorschlag), oder lieber ein eigenes Fenster "Build einfügen"?

## Entscheidungen

Nichts.
