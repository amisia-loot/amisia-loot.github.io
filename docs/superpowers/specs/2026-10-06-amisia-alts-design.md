# Amisia: Twinks ihrem Main zuordnen

Stand 2026-10-06. Kleiner Baustein nach 2.3.1, vor 2.4. Ändert die Website `index.html`, das
Addon `addon/Amisia` (neue Datei `Alts.lua`, Anpassungen in `Awards.lua`, `Sync.lua`,
`RollFrame.lua`, `Pages/Gear.lua`, `Pages/Raids.lua`) und ihre Tests. Keine Versionsnummer, kein
Release (das macht der Nutzer). Supabase bleibt, wie es ist: kein Schema-Umbau, die Zuordnung lebt
im Ledger-JSON.

Wort-Hinweis: "Twink" heißt ein weiterer Charakter desselben Spielers, "Main" sein Hauptcharakter.
Auf der Website (englisch) heißt es "alt" und "main".

## Ziel

Spielt jemand an einem Abend seinen Twink, sollen Anwesenheit, Vergaben und Plus-Eins trotzdem
beim Main zählen. Die Offiziere legen einmal pro Raider fest "Twink von <Main>"; Website und Addon
rechnen ab dann pro Spieler statt pro Charakter, wo es um Zählen geht.

## Entscheidungen

- **Rohdaten bleiben pro Charakter.** Ein Import legt Anwesenheit, Vergaben, Bank und Late weiter
  unter dem Charakter ab, der im Export steht (wie bisher; ein Twink, der noch nicht im Roster ist,
  wird wie jeder neue Name angelegt). Zusammengezählt wird erst in den Ansichten. So ist das
  Lösen einer Zuordnung verlustfrei, und eine falsche Zuordnung verfälscht nichts dauerhaft.
- **Datenfeld:** `raider.main = <id des Mains>` in `state.raiders` (Roster, für alle Spielversionen
  gemeinsam). Zusätzlich, ein Ledger ohne das Feld läuft wie bisher. Gültig ist ein Verweis nur,
  wenn der Main existiert, nicht der Raider selbst ist und selbst kein Twink ist (eine Ebene, keine
  Ketten). Ungültige Verweise werden ignoriert, nicht gelöscht.
- **Wer darf:** wer den Roster bearbeiten darf (Editor), in der Bearbeiten-Zeile des Rosters
  ("Main"-Auswahl). Ein Main mit Twinks kann selbst kein Twink werden (Auswahl gesperrt, Hinweis).
  Wird ein Main aus dem Roster entfernt, verlieren seine Twinks den Verweis.
- **Website, was zusammengezählt wird:**
  - Attendance-Reiter: eine Zeile pro Main, seine Twinks klein darunter ("alts: Bob, Kim"). Ein
    Abend zählt als da, wenn einer der Charaktere da war; als zu spät nur, wenn alle anwesenden
    Charaktere zu spät kamen; Bank nur, wenn keiner da war. Items und "Per raid" über alle
    Charaktere. Die Suche findet einen Main auch über den Namen seines Twinks.
  - Armory: eine Karte pro Main mit den Vergaben aller seiner Charaktere; bei einer Vergabe an
    einen Twink steht dessen Name in der Detailtabelle.
  - Roster: jeder Charakter bleibt eine eigene Zeile (Klasse, Berufe, eigene Items), Twinks direkt
    unter ihrem Main mit dem Hinweis "alt of <Main>".
  - Loot Log, Gear-Matrix, Nights, Wishlist, Crafting, Mats bleiben pro Charakter: Ausrüstung,
    Wünsche und Berufe gehören zum Charakter.
  - Die Website kennt kein eigenes Plus-Eins; "Plus-Eins" rollt im Addon hoch (siehe unten).
- **Text fürs Addon:** neuer eigener Block, der Wunschlisten-Text bleibt unverändert:

  ```
  #AMISIA-ALTS 1 forever <yyyy-mm-dd>
  A <Twink, _ für Leerzeichen> <Main, _ für Leerzeichen>
  #END
  ```

  "Copy for the addon" im Wishlist-Reiter hängt diesen Block an den Wunschlisten-Text an, wenn es
  Zuordnungen gibt (ein Einfügen bringt beides ins Spiel; ein Addon vor diesem Baustein liest bis
  zum ersten `#END` und übersieht den Block). Zusätzlich gibt es im Roster-Reiter ein Feld
  "Alts for the addon" mit nur diesem Block.
- **Addon, Speicher und Import:** `AmisiaDB.alts = { date, at, by, n, list = { { alt, main } } }`.
  Das Importfeld der Ausrüstungsseite (Ansicht "Gilde", nur Offiziere) nimmt jetzt Wunschliste,
  Twinks oder beides in einem Text. Ein Text, der nur Twinks hat, lässt die geladene Wunschliste
  stehen und umgekehrt. Der Text ist nicht vertrauenswürdig: Escape-Codes und Striche raus, Namen
  geprüft (ohne Ziffern, höchstens 48 Bytes), höchstens 2000 Zeilen, ein Twink, der zugleich Main
  ist, und ein Twink seiner selbst werden übersprungen.
- **Addon, Namensabgleich:** `ns.MainOf(name)` gibt den Main eines Twinks (sonst den Namen selbst).
  Erst exakt (Groß-/Kleinschreibung egal), dann über `ns.SameName` (ein Name ohne Nachnamen), aber
  nur, wenn genau ein Eintrag passt. `ns.SameMain(a, b)`: gleicher Charakter oder gleicher Main.
- **Addon, was hochrollt:**
  - Plus-Eins (`ns.PlusCount`, `ns.PlusList`, also Roll-Reihenfolge, "+n" im Rollfenster, die
    Vergabe-Liste, der Vergabe-Dialog und `/amisia plus`) zählt die MS-Gewinne aller Charaktere
    eines Spielers. `ns.PlusList` führt einen Eintrag pro Main (Name des Mains).
  - Sync: der Hüter schreibt die Plus-Eins jedes Spielers in seinen Snapshot unter dem Main **und**
    unter jedem verknüpften Twink. Raider ohne Twink-Liste (oder mit einer älteren Version) finden
    so die richtige Zahl unter dem Namen, mit dem sie gerade spielen. Keine neue Nachricht, kein
    neues Protokoll: die Twink-Liste selbst kommt nur per Einfügen von der Website.
  - Anzeige: im Rollfenster steht hinter einem Twink sein Main in Grau ("Bob (Anna)"); in den
    Raid-Details (Seite Raids) bei Anwesenden "Bob (Twink von Anna)".
- **Bleibt pro Charakter:** Soft-Reserves, Gildenwünsche (Markierung, Tooltip, Vergabe-Dialog),
  Bank-Anmeldung, Late: die gehören zum Charakter, der im Raid ist. Ein Main, der für seinen Twink
  reserviert hat, ist eine andere Klasse mit anderer Ausrüstung.
- **Export `#AMISIA 2`:** unverändert. Die Zuordnung entsteht auf der Website, das Addon schickt
  nichts zurück.

## Tests

- Addon: `addon/tests/test_alts.lua` (Parser, Speicher, Import mit Wunschliste im selben Text,
  `MainOf`/`SameMain`, Plus-Eins über Twinks, Liste pro Main, Sync-Snapshot mit Twink-Namen,
  Rollfenster-Hinweis, Raids-Details).
- Website: `tools/tests/site_alts.cjs` mit `tools/tests/test_alts_site.py` (Gültigkeit der
  Verweise, Anwesenheit/Late/Bank pro Main, Text fürs Addon, der durch den Addon-Parser
  zurückgelesen wird, Entfernen eines Mains).

## Im Spiel zu prüfen

- Einfügen von Wunschliste plus Twinks in einem Text (Länge des Eingabefelds reicht?).
- Rollfenster: passt "Bob (Anna)" in die Namensspalte?
- Ein Raider (kein Offizier) sieht beim Twink das Plus-Eins seines Mains (Zahl vom Hüter).
