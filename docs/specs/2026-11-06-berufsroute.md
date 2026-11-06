# Spec: Berufsroute mit Einkaufsliste

Stand: 2026-11-06 · Status: freigegeben ·
Feature: F-137

## Ziel

Der Spieler sieht für einen Herstellungsberuf den günstigsten Weg von seinem Rang bis zum Höchstrang:
welches Rezept er wie oft herstellt, wann er zum Lehrer muss, was das kostet und welche Materialien er
dafür noch kaufen oder sammeln muss. Gelöst ist es, wenn man die Route Schritt für Schritt abarbeiten
kann, ohne nebenher eine Webseite offen zu haben.

## Was es tut

- **Seite Berufe, Umschalter "Rezepte | Route"** oben neben der Berufswahl. "Route" gibt es für
  Alchemie, Schmiedekunst, Verzauberkunst, Ingenieurskunst, Lederverarbeitung, Schneiderei, Kochen,
  Erste Hilfe und Gifte. Die vier Sammelberufe und Angeln haben keine Route.
- **Kopf der Route:** "Rang 112 → 300 · etwa 14 g 30 s · 9 Schritte", darunter die Einstellung
  "Rezepte: nur Lehrer | auch Händler" (siehe Frage 2).
- **Schritte als Karten**, von oben nach unten:
  - Rezeptschritt: "112–125: 13× Schweres Leinenverband". Dazu die Farbe beim Start und am Ende
    (orange → gelb), die erwartete Zahl der Herstellungen ("etwa 15×", weil gelbe Rezepte nicht immer
    einen Punkt geben), die Reagenzien je Stück und die Kosten des Schritts.
  - Lehrerschritt: "Bei 125: zum Lehrer, Experte lernen (bis 225)", mit Lernkosten, wenn die Daten sie
    haben.
  - Rezeptkauf (nur mit "auch Händler"): "Rezept kaufen: Muster: Rotes Leinenhemd bei <Händler>" mit
    Wegpunkt.
- **Der aktuelle Schritt ist hervorgehoben.** Erledigte Schritte sind abgehakt und eingeklappt. Steigt
  der Rang (Berufsfenster, `TRADE_SKILL_LIST_UPDATE`), rechnet die Route ab dem neuen Rang neu.
- **Einkaufsliste** unter den Schritten (oder als zweiter Umschalter "Schritte | Einkauf"): je Material
  Bedarf, "hast" (Taschen und Bank dieses Charakters über `C_Item.GetItemCount`), "fehlt", Stückpreis
  und Quelle ("Händler", "sammeln: Kräuterkunde", "entzaubern", "Drop", "Auktionshaus"). Hast du genug,
  wird die Zeile grün. Ein Klick auf ein Material vom Händler setzt den Wegpunkt zum nächsten Händler
  mit bekanntem Ort (wie heute bei den Rezeptquellen).
- **Zwischenprodukte:** Braucht ein Rezept etwas, das derselbe Beruf herstellt (z. B. Bolzen aus
  Wollstoff), steht es als eigener Schritt davor. Diese Herstellungen zählen für den Rang mit, wenn sie
  noch Punkte geben.
- **Tooltip eines Schritts:** die Farbstufen des Rezepts (orange bis x, gelb bis y, grün bis z) und
  warum es gewählt wurde ("billigster Punkt bei Rang 112").

## Was es ausdrücklich nicht tut

- Kein automatisches Herstellen, Kaufen oder Einstellen ins Auktionshaus, auch nicht per Klick.
- Keine Auktionshauspreise aus fremden Quellen und kein Abfragen des Auktionshauses durch Amisia.
  Ohne eigene Beobachtung (Frage 4) hat ein Material ohne Händlerpreis keinen Preis. Es steht dann als
  "farmen oder Auktionshaus" in der Liste und zählt nicht zu den Kosten.
- Kein Austausch mit der Gilde: Die Route rechnet nur lokal und sendet nichts.
- Keine Routen für Sammelberufe, Angeln und die Camping-Lagerobjekte.
- Keine Daten aus anderen Addons oder von Fan-Seiten (D-03, D-04): nur die Client-Tabellen und ATT,
  wie heute für die Berufe.

## Abläufe

1. Der Spieler öffnet Berufe, wählt z. B. Schneiderei und schaltet auf "Route".
2. Amisia nimmt den gespeicherten Rang aus `AmisiaDB.prof` (zuletzt im Berufsfenster gesehen). Ist der
   Beruf nicht erlernt, startet die Vorschau bei 1 und sagt das im Kopf.
3. Die Route rechnet Punkt für Punkt: Für jeden Rang nimmt sie das Rezept mit den kleinsten erwarteten
   Kosten je Punkt. Die Kosten einer Herstellung sind ein Maß in Kupfer: je Reagenz der Händlerpreis;
   ohne Händlerpreis ein Schätzwert (was der eigene Beruf oder das Verhütten daraus macht, oder der
   Verkaufspreis beim Händler mal 4, mindestens 20 Kupfer, das Billigere; ohne jeden Preis 20 Silber);
   dazu ein kleiner Aufschlag je Herstellung (30 Kupfer, auch für Zwischenprodukte), damit ein langer
   grüner Rest gegen ein oranges oder gelbes Rezept verliert, und die einmaligen Kosten (Lernen,
   Rezeptkauf) verteilt auf die Ränge mit sicheren Punkten. Das geteilt durch die Chance auf einen
   Punkt: orange 1, gelb und grün `(grau − Rang) / (grau − gelb)`, grau 0; unter einer Chance von 1/4
   ist ein Rezept kein Schritt. Gleiche Rezepte hintereinander werden zu einem Schritt zusammengefasst.
   Bei gleichen Kosten gewinnt ein schon bekanntes Rezept, dann das mit weniger verschiedenen
   Reagenzien. Angezeigt werden nur echte Händlerkosten ("etwa X" oder "Kosten unbekannt"); dass
   Materialien ohne Händlerpreis nach einem Schätzwert gewählt, aber nicht mitgezählt werden, sagt der
   Hinweis.
4. Erlaubt sind Rezepte, die der Spieler kennt oder die sein Lehrer bis zum nächsten Limit lehrt.
   Mit "auch Händler" kommen Rezepte von Händlern dazu, mit dem Kaufpreis des Rezepts in den Kosten.
5. Der Spieler kauft nach der Einkaufsliste ein, öffnet das Berufsfenster und stellt her. Mit jedem
   Punkt springt die Hervorhebung weiter, und "hast" in der Einkaufsliste zählt mit.

## Abnahmekriterien

- Wenn ich Schneiderei auf Rang 1 habe und "Route" wähle, dann zeigt die Route Schritte bis zum
  Höchstrang mit Lehrerschritten bei den Limits, und jeder Rang ist von genau einem Schritt abgedeckt.
- Wenn ich einen Schritt herstelle und dabei einen Punkt bekomme, dann steht die Route danach auf dem
  neuen Rang, ohne `/reload`.
- Wenn ich ein Material der Einkaufsliste in die Tasche lege oder auf die Bank bringe, dann steigt
  "hast" und "fehlt" sinkt, bei genug wird die Zeile grün.
- Wenn ein Material nur beim Händler zu kaufen ist, dann steht sein Preis in der Liste. Ein Klick
  setzt den Wegpunkt zum Händler, wenn ein Ort bekannt ist.
- Wenn ich auf "auch Händler" schalte, dann können Händlerrezepte in die Route kommen, mit einem
  Schritt "Rezept kaufen".
- Wenn der Client auf Englisch ist, dann stehen alle Rezepte, Materialien und Texte auf Englisch.

## Sonderfälle

- Rang unbekannt (Berufsfenster nie geöffnet): Start beim gespeicherten Rang oder bei 1, Hinweis
  "Berufsfenster einmal öffnen, dann stimmt der Rang".
- Rezept ohne Reagenzdaten (`G` fehlt, Client antwortet nicht): Es kommt nicht in die Route. Fehlt es
  dadurch für einen Rangbereich, steht dort "kein Rezept mit bekannten Reagenzien".
- Lücke ohne Rezept, das noch Punkte gibt: Der Schritt sagt das ehrlich, statt grau zu rechnen.
- Rezepte mit mehreren Stück je Herstellung (`count` > 1) und Rezepte nur für eine Fraktion (nur die
  eigene zählt).
- Verzauberkunst: Die Materialien kommen aus dem Entzaubern, haben also meist keinen Händlerpreis.
  Die Route wählt dann nach dem Schätzwert (Entzauberungsmaterialien verkaufen sich für 1 Kupfer, also
  gilt der Mindestwert: praktisch nach Menge) und sagt das im Hinweis.
- Bosskampf und Sperre: Die Route ist rein lokal und braucht keine geschützten Werte. Neu gerechnet
  wird erst nach dem Kampf (`ns.RefreshSoon`), nie mitten im Kampf.
- Twinks: Jeder Charakter hat seine eigene Route aus seinem Rang. Die Taschen der Twinks siehe Frage 3.
- Viele Rezepte: Gerechnet wird höchstens einmal je Rangänderung und nur bei offener Seite.
- Rezepte mit Abklingzeit (Transmutationen, Mondstoff): nie ein Schritt, auch wenn bekannt, weil man
  sie nicht für Punkte wiederholen kann (`CD`).
- Lernrang: wo die Daten keinen haben (Lehrerrezepte), nie früher als das Spiel erlaubt: ab gelb,
  nicht unter dem, was der Lehrer der Stufe verlangt.
- Rezepte ohne Quelle kommen nur in die Route, wenn sie bekannt sind oder der Beruf keine Lehrerliste
  in den Daten hat (Kochen, Gifte); Rezepte einer Spezialisierung nur, wenn bekannt.
- Höchstwert unter einem Lehrer-Limit (z. B. Rang 90, Höchstwert 100): Der Höchstwert kommt von der
  Stufe, die Route endet dort mit dem Hinweis "Höchstwert für deine Stufe: 100", ohne Lehrerschritt.
- Gifte haben keine Lehrerstufen (der Höchstwert hängt an der Stufe): keine Lehrerschritte.
- Rang über dem bekannten Höchstrang (Höchstwert unbekannt): Der Rang ist das Ende, ein Hinweis sagt,
  das Berufsfenster zu öffnen.
- Ein Material, dessen bekannte Händler alle zur anderen Fraktion gehören (Handwerkswaren gibt es auf
  beiden Seiten): Preis ja, kein Wegpunkt, Quelle "Händler (Ort unbekannt)". Rezepte der anderen
  Fraktion bleiben draußen.

## Missbrauch/Vertrauen

Nichts wird gesendet oder empfangen, also gibt es keine Absender und keine Flut. Die Route liest nur
die eigenen Daten und die generierten Tabellen.

## Daten

- **Generiert:** In `PROFESSIONS` kommt der Abschnitt `V = { [item] = "Kaufpreis in Kupfer:NPC,..." }`.
  Er enthält Reagenzien und Rezept-Items, die ein Händler für Gold verkauft (Händler laut ATT oder vom
  Sammler gesehen). Der Preis kommt aus der Spalte `BuyPrice` von `ItemSparse` (geteilt durch
  `VendorStackCount`). Dazu `S = { [item] = Verkaufspreis in Kupfer }` für jedes Reagenz ohne
  Händlerpreis (`SellPrice` von `ItemSparse`, Grundlage des Schätzwerts) und `CD = { [Zauber] = 1 }`
  für die Rezepte mit Abklingzeit (Client-Tabelle `SpellCooldowns`, bis sie exportiert ist die
  handgepflegte Liste `tools/prof_cooldowns.json`); Rezepte einer Spezialisierung tragen die Quelle `S`.
  Lehrer-Lernkosten nur, wenn ATT sie hat. Keine neue Datenquelle außer den Client-Tabellen.
- **Einstellungen:** in `settings.professions` (wo die Filter der Seite schon liegen) die Felder `mode`
  ("recipes"/"route"; `view` hält schon den gewählten Beruf), `routeTab` ("steps"/"shop") und
  `routeVendor` (true/nil). Kein neuer Abschnitt.
- **AmisiaDB:** `AmisiaDB.prof.bags` (Frage 3): je eigenem Charakter Tag, Realm, Fraktion, die Mengen,
  der Bankanteil und die Liste der Reagenzien, die sich zu zählen lohnen (aus den Daten, wenn sie ohnehin
  gebaut sind; Ereignisse bauen sie nie, D-28). Kein `AmisiaDB.prices` (Frage 4).
- Keine Nachrichten, Exportzeilen oder Website-Teile. Neue Dateien `Gear/ProfRoute.lua` (Rechnung) und
  der Teil in `UI/Pages/Professions.lua`, beide in ARCHITECTURE.

## Offene Fragen

1. **Bis wohin rechnet die Route?** Vorschlag: bis zum Höchstrang, mit Lehrerschritten an den Limits.
   Die Alternative "nur bis zum nächsten Lehrer" ist kürzer, zeigt aber nicht den ganzen Weg.
2. **Rezepte von Händlern und Drops?** Vorschlag: Schalter, Standard "nur Lehrer". Mit "auch Händler"
   kommen nur Händlerrezepte dazu (mit Preis und Ort). Drops nie, weil man sie nicht planen kann.
3. **Taschen und Bank der Twinks mitzählen?** Dafür müsste Amisia beim Ausloggen und an der Bank die
   Menge der Berufsmaterialien je eigenem Charakter speichern (neuer Schlüssel `AmisiaDB.prof.bags`,
   nur eigene Charaktere, nichts wird gesendet). Vorschlag: ja, als eigene Spalte "Twinks", in der
   Bank des Twinks gesehen.
4. **Eigene Auktionshauspreise merken?** Amisia sieht beim Stöbern im Auktionshaus schon die Items.
   Es könnte den niedrigsten Sofortkaufpreis je Material merken (`AmisiaDB.prices`, nur selbst
   gesehen, nach 7 Tagen "alt"). Vorschlag: noch nicht. Erst die Route mit Händlerpreisen bauen und
   schauen, ob die Kosten ohne AH-Preise reichen.
5. **Wo sitzt es?** Vorschlag: Umschalter "Rezepte | Route" auf der Seite Berufe. Ein eigener Reiter
   wäre eine neue Seite und brächte mehr Klicks.

## Entscheidungen

- 2026-11-06: alle fünf Fragen: "Passt, bauen" -> wie vorgeschlagen:
  1. bis zum Höchstrang, Lehrerschritte an den Limits;
  2. Schalter "nur Lehrer | auch Händler", Standard nur Lehrer, Drop-Rezepte nie;
  3. Twinks mitzählen: `AmisiaDB.prof.bags`, nur eigene Charaktere, Spalte "Twinks";
  4. keine Auktionshauspreise (kein `AmisiaDB.prices`);
  5. Umschalter "Rezepte | Route" auf der Seite Berufe.
- 2026-11-06: Review: Kostenmaß mit Schätzwert, keine Abklingzeit-Rezepte, Stufen-Höchstwert. Statt
  "erst Stücke ohne Preis, dann Gold" ein Maß in Kupfer je Punkt (Schätzwert aus dem Verkaufspreis,
  Aufschlag je Herstellung, fast graue Rezepte kein Schritt); Rezepte mit Abklingzeit nie; Lernrang
  ohne Daten ab gelb; Rezepte ohne Quelle nur ohne Lehrerliste; ein Höchstwert unter dem Lehrer-Limit
  beendet die Route; Gifte ohne Lehrerstufen; Twinks nur gleicher Realm und gleiche Fraktion; die
  Ereignisse bauen die Berufsdaten nicht (D-28). Die fünf Entscheidungen oben bleiben.
