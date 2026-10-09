# Spec: Loot-Abend schneller (Handel-Helfer, Lootregeln, Würfel-Fenster)

Stand: 2026-10-08 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-074 (Lootregeln), F-075 (Würfel-Fenster), F-076 (Handel-Helfer); sind die Nummern beim
Freigeben schon vergeben, die dann nächsten freien.

Ein Paket aus drei Teilen. Jeder Teil lässt sich allein bauen, freigeben und ausliefern. Die Spec
ist deshalb länger als zwei Seiten; innerhalb jeder Überschrift stehen die Teile in derselben
Reihenfolge: Teil 1 Handel-Helfer, Teil 2 Lootregeln, Teil 3 Würfel-Fenster.

## Ziel

Der Loot nach einem Boss dauert kürzer und es passieren weniger Fehler: Kleinkram (Materialien,
grüne und blaue Items) verteilt sich nach festen Regeln, Raider würfeln mit einem Klick im richtigen
Bereich, und kein vergebenes Item verfällt in einer Tasche, weil die zwei Stunden Handelszeit
abgelaufen sind. Gelöst ist es, wenn die Lootleitung pro Boss nur noch die Items anfasst, um die
wirklich gewürfelt wird, und niemand mehr fragt "/roll oder /roll 99?".

## Was es tut

### Teil 1: Handel-Helfer (für jeden, der ein vergebenes Item in der Tasche hat)

- Amisia merkt, wenn in deinen Taschen ein Item liegt, das in der laufenden Raidaufnahme an jemand
  anderen vergeben ist (an einen Spieler, die Bank oder den Entzauberer) und noch handelbar ist.
- Liste "Noch zu übergeben" oben auf der Seite Vergaben und mit `/amisia uebergabe` (en `handover`):
  Item, an wen, Restzeit ("noch 1:12 h"), das Kürzeste zuerst.
- Warnung nur in deinem Chat, mit Ton: "Noch 30 Minuten: [Item] an Anna übergeben." und noch einmal
  bei 10 Minuten.
- Öffnet sich das Handelsfenster mit dem Empfänger, steht am Handelsfenster ein Knopf "Amisia: 2 Items
  einlegen". Ein Klick legt die Items in den Handel. "Handeln" drückst du selbst.
- Ist der Handel durch, meldet der Chat "Übergeben: [Item] an Anna." Der Eintrag verschwindet aus der
  Liste, die Vergabe bekommt bei dir den Vermerk "übergeben".
- Einstellungen, neuer Abschnitt "Handel-Helfer": an/aus, Warnungen (30 und 10 Minuten / nur 10 /
  aus), Ton an/aus, Einlegen "per Knopf" oder "automatisch" (nur, wenn die Prüfung in Frage 2 zeigt,
  dass es ohne Klick geht).

### Teil 2: Automatische Lootregeln (Plündermeister, Offiziere)

- Einstellungen, neuer Abschnitt "Lootregeln" (nur Offiziersansicht): eine Liste von Regeln, oben
  ein Schalter "Pause". Regelarten:
  1. "Qualität bis Selten (blau) -> Entzaubern" (oder -> Bank). Nur Bank oder Entzauberer als Ziel.
  2. "Raidmaterialien -> Bank" (die gelernte Liste von `/amisia mats`).
  3. "Diese Items -> Bank / Entzaubern" (eine Liste von Items, per Link eingefügt).
  4. "Dieses Item -> Spieler" (genau ein Item, ein Name; z. B. ein Questitem für den Tank).
- Die erste passende Regel von oben gewinnt. Bank und Entzauberer sind die Namen aus Einstellungen,
  Vergaben ("Bank-Charakter", "Entzauberer").
- Öffnet der Plündermeister eine Leiche, zeigt Amisia neben dem Lootfenster eine Leiste: "Regeln:
  2 an die Bank, 1 zum Entzaubern · Verteilen". Der Tooltip nennt jedes Item und seine Regel. Ein
  Klick auf "Verteilen" gibt sie per Master Loot aus. Wahlweise (Einstellung "automatisch") ohne Klick,
  eine Sekunde nach dem Öffnen.
- Jede Ausgabe wird eine normale Vergabe (Bank, Entzaubern oder Spieler) mit der Notiz
  "Regel: <Regel>". Sie steht auf der Seite Vergaben, im Abgleich und im Export.
- Eine Zeile im Raidchat: "Amisia-Regeln: [Item] an die Bank (Bankname), [Item] zum Entzaubern
  (Name)." (abschaltbar).
- Befehle: `/amisia regeln` (öffnet den Abschnitt), `/amisia regeln pause` / `weiter`,
  `/amisia regeln probe` (zeigt für das offene Lootfenster, was passieren würde, gibt nichts aus).
- Knopf "An Offiziere senden": die anderen Offiziere bekommen die Regeln als Vorschlag
  ("Neue Lootregeln von Vulo Hunt: Übernehmen / Ablehnen").

### Teil 3: Würfel-Fenster für Raider (jeder mit Amisia im Raid)

- Startet die Lootleitung eine Roll-Runde (wie heute: Alt-Klick, `/amisia roll`, Roll-Fenster),
  bekommt jeder Raider mit Amisia ein kleines Fenster: Item mit Symbol und Tooltip, ein Zeitbalken und
  drei Knöpfe: "Mainspec" (würfelt 1-100), "Offspec" (würfelt 1-99), "Passen".
- Darunter die Hinweise, die es schon gibt: "Reserviert von dir" oder "Reserviert von 2 anderen",
  "Dein Plus-Eins: 1", "Upgrade für dich: +12 % (Brust)", "Auf deiner Wunschliste".
- Nach dem Klick: "Gewürfelt: Mainspec" und die Zahl, sobald die Systemzeile sie zeigt; die
  Würfelknöpfe sind dann aus. "Passen" schreibt nichts in den Chat.
- Am Ende: "Gewinner: Anna (95, MS)" für 5 Sekunden, dann schließt das Fenster. Das X schließt es
  jederzeit.
- DKP-Gebote: ein Zahlenfeld, "Bieten" und "Passen", dazu dein Stand und das Mindestgebot.
  Bedarf/Gier (EPGP, DKP mit festen Preisen): "Bedarf (Preis 50)", "Gier (Preis 25)", "Passen".
- Stechen: nur die Beteiligten sehen das Fenster ("Stechen: Anna, Bob").
- Das Roll-Fenster der Lootleitung zeigt zusätzlich "passt: 3 · ohne Antwort: 5" (nur Raider mit
  Amisia).
- Einstellungen, neuer Abschnitt "Würfel-Fenster" (für alle): an/aus, "nur zeigen, wenn reserviert,
  Upgrade oder Wunsch", Ton, Position zurücksetzen.
- `/amisia wuerfeln test` (en `rolltest`) zeigt eine Proberunde nur bei dir; die Knöpfe würfeln dann
  wirklich (allein sieht das nur dein Chat).

## Was es ausdrücklich nicht tut

- Teil 1: Amisia öffnet nie selbst einen Handel und drückt nie "Handeln"; der Spieler bestätigt immer.
  Es ersetzt Master Loot nicht (DECISIONS D-27): kein Tauschsystem für persönliches Plündern, keine
  Warteschlange "wer bekommt was zuerst". Items ohne Vergabe verfolgt es nicht. Der Vermerk
  "übergeben" geht weder an andere Spieler noch an die Website.
- Teil 2: Regeln entscheiden nie über Items, die jemand reserviert hat, die eine Loot-Prio haben, auf
  der Gildenwunschliste eines Raiders stehen oder bei "Wer braucht das?" als Upgrade oder Wunsch
  gemeldet wurden. Keine Regeln nach Klasse, Spec, Plus-Eins oder Würfen. Keine Regeln bei
  Gruppenplündern (nur Master Loot). Keine Regel "ganze Qualitätsstufe an einen Spieler". Keine Regeln
  von der Website (vielleicht später), keine Regeln für Raider.
- Teil 3: keine parallelen Runden (Amisia führt heute eine Runde nach der anderen; das bleibt). Die
  Würfelzahl kommt nur vom Server (Systemzeile), nie aus einer Addon-Nachricht. Kein "immer
  automatisch Mainspec". Raider ohne Amisia würfeln weiter mit `/roll` wie heute. Die Würfelfenster
  des Spiels bei Gruppenplündern bleiben, wie sie sind.
- Alle Teile: nichts wird in der Kampfsperre gesendet oder ausgegeben (D-19); kein Kampflog (D-20).

## Abläufe

### Teil 1: Handel-Helfer

1. Ein Item landet in deinen Taschen: du bist Plündermeister und hast es dir selbst gegeben (der
   Empfänger war zu weit weg), du hast es beim Gruppenplündern gewonnen, oder eine Vergabe wurde von
   Hand eingetragen, während das Item bei dir liegt (Vergabe-Dialog: "Das Item liegt noch in den
   Taschen").
2. Amisia vergleicht nach jeder Taschenänderung: Gibt es in der laufenden Raidaufnahme (eigene
   Vergaben oder vom Hüter abgeglichen) eine Vergabe dieses Items an jemand anderen, und liegt eine
   noch handelbare Kopie in deinen Taschen? Dann merkt es sich genau diese Kopie (ihre Item-GUID).
3. Die Kopie erscheint in "Noch zu übergeben". Die Restzeit liest Amisia aus der Tooltipzeile des
   Spiels; klappt das nicht, schätzt es: Zeitpunkt des Erhalts plus 2 Stunden.
4. Bei 30 und 10 Minuten Rest kommt die Warnung in deinem Chat.
5. Der Empfänger öffnet den Handel mit dir (oder du mit ihm). Amisia liest den Namen des
   Handelspartners. Hat es Items für ihn, zeigt es den Knopf "Amisia: N Items einlegen".
6. Klick: Amisia legt die Items nacheinander in freie Handelsplätze (höchstens 6). Hältst du gerade
   etwas mit der Maus, legt es nichts ein und sagt es.
7. Beide drücken "Handeln". Meldet das Spiel "Handel abgeschlossen", vermerkt Amisia die Items, die
   zuletzt im Handel lagen, als übergeben. Bricht jemand ab, ändert sich nichts.
8. Geht ein Item an jemand anderen als laut Vergabe: Hinweis "[Item] ging an Bob, vergeben ist es an
   Anna. Vergabe ändern?" mit Verweis auf den Vergabe-Dialog. Amisia ändert die Vergabe nicht selbst.
9. Läuft die Zeit ab: Eintrag rot "nicht mehr handelbar", bis du ihn entfernst oder einen Tag nach
   dem Raid.

### Teil 2: Lootregeln

1. Ein Offizier legt in Einstellungen, Lootregeln seine Regeln an. Fehlt der Bank- oder
   Entzauberer-Name, steht bei der Regel "Bank-Charakter fehlt (Einstellungen, Vergaben)".
2. Optional: "An Offiziere senden". Online-Offiziere mit Amisia sehen den Vorschlag mit den
   Unterschieden (neu, geändert, entfernt) und übernehmen oder lehnen ab. Wer später einloggt, fragt
   einmal nach und bekommt den Vorschlag dann.
3. Im Raid öffnet der Plündermeister (Lootleitung, Offiziersansicht) eine Leiche. Amisia prüft jedes
   Item im Lootfenster von oben: Geld, Währung und Questitems überspringen; reservierte Items, Items
   mit Loot-Prio, mit Gildenwunsch eines Raiders oder mit Upgrade-/Wunsch-Antwort überspringen; sonst
   die erste passende Regel.
4. "Ein Klick" (Vorschlag als Standard): die Leiste zeigt, was die Regeln tun würden. Klick auf
   "Verteilen": für jedes Item Master Loot an den Kandidaten. Die Vergabe wird wie heute erst
   geschrieben, wenn das Spiel die Übergabe bestätigt (Lootzeile oder leerer Platz).
5. "Automatisch": dasselbe eine Sekunde nach dem Öffnen, nur außerhalb von Kampf und Kampfsperre,
   nur einmal pro Leiche (Merkzeichen wie bei der Loot-Ansage).
6. Ist ein Ziel kein Kandidat (zu weit weg, nicht berechtigt), bleibt das Item liegen: "Bankname ist
   kein Kandidat für [Item]."
7. Eine Zeile im Raidchat nennt, was die Regeln verteilt haben. Die übrigen Items gehen den normalen
   Weg (Ansage, Roll-Runde, Vergabe-Dialog).

### Teil 3: Würfel-Fenster

1. Die Lootleitung startet eine Runde wie heute. Die Ansage im Raidchat bleibt, damit Raider ohne
   Amisia wissen, was los ist.
2. Zusätzlich schickt Amisia eine Addon-Nachricht "Runde beginnt" in den Raid. Hält die Kampfsperre
   sie auf, verfällt sie nach der Rundendauer. (Umgesetzt 2026-10-09: nach höchstens 5 Sekunden, D-38;
   die Uhr der Raider beginnt bei der Ankunft und zeigte sonst zu viel Zeit.)
3. Jeder Raider-Client prüft den Absender: Offiziersrang in der eigenen Gilde, in der Gruppe und
   Lootleitung (dieselbe Prüfung wie bei "Wer braucht das?"). Dann erscheint das Fenster.
4. Klick "Mainspec": Amisia würfelt für den Raider 1-100, "Offspec" 1-99. Der Server schreibt die
   Zeile "Anna würfelt 87 (1-100)" für alle; die Lootleitung liest sie wie heute.
5. Klick "Passen": eine Addon-Nachricht nur an die Lootleitung, nichts im Chat. Wer gepasst hat, kann
   bis zum Ende doch noch würfeln; der Wurf zählt dann.
6. Das Roll-Fenster der Lootleitung zeigt, wer gepasst hat und wer noch nicht geantwortet hat. Stopp
   bleibt ein Klick der Lootleitung.
7. Ende (Zeit um oder Stopp): Amisia schickt "Runde vorbei, Gewinner Anna 95 MS". Das Fenster zeigt es
   5 Sekunden und schließt. Kommt diese Nachricht nicht, schließt es 3 Sekunden nach Ablauf der
   eigenen Uhr.
8. Punkte-Runden: Gebot, Bedarf, Gier und Passen gehen als Addon-Nachricht an die Lootleitung und
   zählen dort wie ein geflüstertes `!bid 50` bzw. `!need`. Die Antworten der Lootleitung (abgelehnt,
   angenommen, Höchstgebot im Raidchat) bleiben wie heute.
9. Stechen: die Nachricht nennt die Beteiligten; nur sie sehen das Fenster.
10. Startet die Lootleitung eine neue Runde, ersetzt das neue Fenster das alte.

## Abnahmekriterien

Allein prüfbar vor 2026-11-04 sind nur die Zeilen ohne "(braucht: ...)". "Gruppe" heißt hier: zwei
Spieler, für Teil 3 in einen Schlachtzug umgewandelt; für Teil 2 mit Master Loot.

### Teil 1: Handel-Helfer

- Wenn du `/amisia uebergabe` eingibst und nichts offen ist, dann meldet der Chat "Nichts zu übergeben."
- Wenn du als Plündermeister ein Item dir selbst gibst und es danach per Vergabe-Dialog an Anna
  vergibst, dann steht es auf der Seite Vergaben unter "Noch zu übergeben" mit Restzeit. (braucht: Gruppe)
- Wenn Anna den Handel mit dir öffnet, dann zeigt das Handelsfenster "Amisia: 1 Item einlegen", und ein
  Klick legt das Item in den ersten freien Platz. (braucht: Gruppe)
- Wenn beide "Handeln" gedrückt haben, dann meldet der Chat "Übergeben: [Item] an Anna.", und der
  Eintrag ist aus der Liste. (braucht: Gruppe)
- Wenn nur noch 10 Minuten bleiben, dann warnt der Chat mit Ton; bricht der Handel ab, bleibt der
  Eintrag stehen. (braucht: Gruppe)

### Teil 2: Lootregeln

- Wenn du als Offizier unter Einstellungen, Lootregeln "Qualität bis Selten -> Entzaubern" anlegst,
  dann steht die Regel in der Liste, mit dem Entzauberer-Namen oder dem Hinweis, dass er fehlt.
- Wenn du allein eine Leiche öffnest und `/amisia regeln probe` eingibst, dann nennt der Chat für jedes
  Item die Regel oder den Grund, warum keine greift ("reserviert", "Loot-Prio", "keine Regel").
- Wenn du als Plündermeister eine Leiche mit einem grünen Item öffnest und "Verteilen" klickst, dann
  bekommt der Entzauberer es, und die Seite Vergaben zeigt "zum Entzaubern" mit Notiz "Regel: ...".
  (braucht: Gruppe)
- Wenn ein Item reserviert ist, dann fasst keine Regel es an, und es steht in der normalen Ansage.
  (braucht: Gruppe)
- Wenn "Pause" an ist, dann zeigt das Lootfenster keine Leiste und nichts wird verteilt; `/amisia
  regeln weiter` schaltet zurück.

### Teil 3: Würfel-Fenster

- Wenn du `/amisia wuerfeln test` eingibst, dann erscheint das Fenster mit einem Probe-Item, und
  "Offspec" schreibt "Du würfelst ... (1-99)" in deinen Chat.
- Wenn die Lootleitung eine Runde startet, dann sieht jeder Raider mit Amisia das Fenster mit Item,
  Zeitbalken und den drei Knöpfen; Raider ohne Amisia sehen nur die Chatansage. (braucht: Gruppe)
- Wenn ein Raider "Mainspec" klickt, dann steht sein Wurf (1-100) im Roll-Fenster der Lootleitung,
  genau wie bei `/roll`. (braucht: Gruppe)
- Wenn ein Raider "Passen" klickt, dann steht nichts im Chat, und das Roll-Fenster der Lootleitung
  zeigt "passt: 1". (braucht: Gruppe)
- Wenn ein Spieler ohne Offiziersrang oder nicht die Lootleitung eine Runde vortäuscht, dann erscheint
  bei niemandem ein Fenster. (braucht: Gilde, Gruppe)

## Sonderfälle

### Teil 1

- Kampf und Kampfsperre: kein automatisches Einlegen; der Knopf bleibt (das Spiel lässt Handeln im
  Kampf ohnehin nur eingeschränkt zu, siehe Frage 3).
- Zwei gleiche Items (zwei Kopien eines Tokens): Amisia folgt jeder Kopie über ihre GUID und ordnet sie
  den Vergaben in Zeitfolge zu.
- Forever-Nachnamen und doppelte Vornamen: Zuordnung über den vollen Namen; ist er nicht eindeutig,
  legt Amisia nichts ein und zeigt die Auswahl.
- Twinks: die Vergabe nennt den Charakter im Raid; gehandelt wird mit genau diesem.
- `/reload` oder neuer Login: die Liste baut sich aus Vergaben und Taschen neu; nur der Vermerk
  "übergeben" ist gespeichert.
- Raid zu Ende, Aufnahme gestoppt: die Liste gilt für die letzte Aufnahme noch bis 2 Stunden nach ihrem
  Ende (länger ist kein Item handelbar).
- Client auf Englisch: die Tooltipzeile wird über die Textvorlage des Spiels gelesen, nicht über
  deutschen Text.

### Teil 2

- Kein Master Loot, oder du bist nicht der Plündermeister: keine Leiste, keine Regel.
- Kampf, Kampfsperre: "automatisch" wartet, bis das Lootfenster nach dem Kampf geöffnet wird; die
  Chatzeile wartet wie jede Ansage.
- Zwei Offiziere: nur der Plündermeister wendet Regeln an; die anderen sehen die Vergaben über den
  Abgleich.
- "Wer braucht das?"-Antworten kommen erst 0-2 Sekunden nach der Frage: deshalb die Sekunde Wartezeit
  im automatischen Modus; im Ein-Klick-Modus prüft der Klick noch einmal.
- Legendäre Items: nie per Regel.
- Mehrere Kopien eines Materials in einem Platz: der ganze Platz geht an die Bank (wie heute).
- Bank- oder Entzauberer-Charakter nicht im Raid: kein Kandidat, Item bleibt liegen, Hinweis.

### Teil 3

- Kampfsperre: die Nachricht wartet; die Knöpfe sind aus mit "Würfeln erst nach dem Kampf" (die
  Lootleitung könnte die Würfe in der Sperre nicht lesen).
- Das Fenster nutzt keine geschützten Vorlagen und darf deshalb auch im Kampf erscheinen.
- Die Lootleitung selbst: sieht das kleine Fenster auch (sie würfelt oft mit); abschaltbar.
- Raider in keiner oder einer anderen Gilde (Gäste): sehen kein Fenster, würfeln per Chat.
- Doppelter Wurf (Knopf und `/roll`): der zweite zählt nicht, wie heute ("schon gewürfelt").
- Login oder `/reload` mitten in der Runde: kein Fenster bis zur nächsten Runde.
- Schlachtfeld, Arena: nichts (keine Nachrichten dort, D-19).
- Items mit Zufallssuffix ("des Bären"): die Nachricht trägt den Itemtext ohne Farbcodes, damit das
  Fenster genau dieses Item zeigt.

## Missbrauch/Vertrauen

Es zählt immer nur der Absender, den der Server setzt, und sein Rang in der Gildenliste (D-18).

### Teil 1

- Der Handelspartner kommt vom Spiel, nicht aus einer Nachricht; niemand kann sich als Anna ausgeben.
- Amisia legt nur ein, bestätigt nie: auch eine falsche Vergabe (z. B. von einem böswilligen Offizier
  geändert) kostet nichts ohne deinen Klick auf "Handeln". Der Knopf nennt, wer die Vergabe gemacht
  hat ("laut Vergabe von Vulo Hunt").
- Vergaben kommen nur aus dem eigenen Buch oder vom geprüften Hüter (Abgleich wie heute).

### Teil 2

- Regeln wirken nur auf dem Client des Plündermeisters und nur mit Offiziersrang und Offiziersansicht.
- Regeln von anderen Offizieren werden nie von selbst aktiv: erst "Übernehmen". Nachrichten mit Regeln
  von Nicht-Offizieren oder Gildenfremden werden verworfen.
- Ein böswilliger Offizier könnte eine Regel "Item -> ich" verschicken. Dagegen: Spieler-Regeln nur
  für einzelne, benannte Items; nie für reservierte, priorisierte, gewünschte oder gebrauchte Items;
  jede Ausgabe steht im Raidchat, als Vergabe mit Notiz "Regel" im Abgleich, im Export und auf der
  Website; jede Regel trägt, wer sie angelegt hat.
- Deckel: höchstens 30 Regeln, 50 Items pro Liste, Nachrichten in höchstens 4 Teilen, ein Vorschlag pro
  Offizier alle 30 Sekunden.

### Teil 3

- "Runde beginnt" zählt nur von der geprüften Lootleitung in der eigenen Gruppe; alles andere wird
  verworfen. Höchstens eine Runde pro Sekunde und Absender; eine neue ersetzt die alte, es entstehen
  nie mehrere Fenster.
- Würfelzahlen kommen nur aus der Systemzeile des Servers; ein Raider kann mit einem veränderten Addon
  keine Zahl fälschen.
- "Passen", Bedarf, Gier und Gebote zählen nur für den Absender selbst, nur in der laufenden Runde,
  nur von Gildenmitgliedern in der Gruppe; die letzte Antwort zählt. Für Gebote gelten dieselben
  Prüfungen wie für `!bid` (Mindestgebot, eigener Stand, verdeckt nur geflüstert: die Addon-Nachricht
  ist geflüstert).
- Ein Spieler, der Text im Chat fälscht ("Roll auf ..."), öffnet kein Fenster.

## Daten

Alles hier kommt beim Bauen im selben Commit in `docs/ARCHITECTURE.md` (Module map, Message kinds,
SavedVariables, Settings).

- Neue Dateien: `Raid/Handover.lua` (Teil 1), `Raid/LootRules.lua` (Teil 2), `Raid/RollWindow.lua`
  (Teil 3), je eine Zeile in der TOC und der Module map.
- `AmisiaDB.handover` (Teil 1): `{ ["<Raid-Schlüssel>/<Vergabe-ID>"] = { t = Zeitpunkt, to = Name,
  g = Item-GUID } }`, nur der Vermerk "übergeben"; Einträge fallen nach 3 Tagen weg, höchstens 200.
- `AmisiaDB.lootRules` (Teil 2): `{ v = 1, rev, by, at, list = { { id, k = "q"/"m"/"i"/"p", q, items,
  to = "bank"/"de"/Name, by } }, offer = { from, rev, at, list } }`; beim Laden Feld für Feld
  geprüft, Deckel wie oben.
- Teil 3 speichert nichts außer seinen Einstellungen.
- Einstellungsabschnitte: `trade` "Handel-Helfer" (Handover.lua, alle), `lootrules` "Lootregeln"
  (LootRules.lua, nur Offiziere), `rollwin` "Würfel-Fenster" (RollWindow.lua, alle).
- Neue Nachrichtenarten (Präfix `Amisia`, Envelope wie alle, höchstens 250 Bytes):

| Art | Absender -> Kanal | Vertrauen beim Empfänger | Abstand | Felder |
|---|---|---|---|---|
| `WS` | Lootleitung -> RAID beim Start einer Runde (Wartezeit höchstens die Rundendauer) | Offizier, in der Gruppe, Lootleitung (wie `UQ`) | 1 s | Runden-ID (4 hex), Itemtext ohne Farben (`item:...`, höchstens 120 Zeichen), Sekunden 5-120, Art `R`/`B`/`N`, Flags (`T` Stechen, `S` verdeckt, `-`), Reservierer (Komma, höchstens 8) oder `-`, [Mindestgebot oder Preis MS], [Preis OS], [Stechen-Namen] |
| `WE` | Lootleitung -> RAID am Ende | wie `WS`, nur für die laufende Runde | keiner | Runden-ID, `D` fertig / `X` abgebrochen, Gewinner oder `-`, [`Wert:Art`] |
| `WA` | Raider -> Lootleitung WHISPER | Mitglied, in der Gruppe, nur für die eigene laufende Runde | je Runden-ID 2 s | Runden-ID, `P` passen / `N` Bedarf / `G` Gier / `B` Gebot, [Betrag] |
| `MR` | Offizier -> GUILD auf Knopfdruck; WHISPER als Antwort auf `MQ` | Offizier; nur neuere Fassung, alle Teile in 30 s | 30 s | Fassung, Teil, Teile (höchstens 4), gesetzt von, Regeln `id:art:wert:ziel` (höchstens 6) oder `-` |
| `MQ` | Offizier -> GUILD einmal nach dem Login (niedrige Priorität) | Offizier | 30 s | eigene Fassung |

- Keine neue Exportzeile: Regel-Vergaben sind normale `A`- bzw. `AS`-Zeilen, ihre Notiz geht wie heute
  mit `AX`. Kein neuer Einfügeblock, kein neuer Website-Zustand.
- DECISIONS: ein Satz zu D-27 (siehe Frage 4) und, wenn freigegeben, eine neue Regel "Lootregeln
  fassen nie Reserviertes, Priorisiertes oder Gewünschtes an; Regeln anderer Offiziere erst nach
  Übernehmen".

## Offene Fragen

Zuerst die Reihenfolge, dann die Entscheidungen, dann die Prüfungen im Spiel. Die Prüfungen mit
"allein" gehen heute schon; ein Teil davon kommt beim Bauen in `/amisia selbsttest`.

1. **Reihenfolge des Baus.** Vorschlag:
   1. Teil 2 Lootregeln (M), zuerst ohne Teilen; das Teilen unter Offizieren (`MR`/`MQ`) danach (S).
      Spart jeden Abend die meisten Klicks, wirkt nur beim Plündermeister, kaum Risiko. Allein
      prüfbar: Regel-Editor, `/amisia regeln probe`, Pause.
   2. Teil 3 Würfel-Fenster (L). Größter Nutzen für die Raider, braucht aber beide Seiten und drei
      neue Nachrichten. Allein prüfbar: `/amisia wuerfeln test` und die Würfel selbst; der Rest erst
      ab 2026-11-04 mit einer Gruppe.
   3. Teil 1 Handel-Helfer (M), erst nach den Prüfungen 9-11 (gibt es die Handelszeit in Forever
      überhaupt, geht das Einlegen). Unter Master Loot ist er nur für Ausnahmen da.
2. **Einlegen per Knopf oder automatisch?** Vorschlag: per Knopf als Standard; "automatisch" nur
   anbieten, wenn Prüfung 10 zeigt, dass es ohne Klick geht.
3. **Handeln im Kampf:** Vorschlag: Amisia legt im Kampf nichts automatisch ein, der Knopf bleibt.
4. **D-27 sagt "eine Tausch-Warteschlange ist nicht gewünscht".** Vorschlag: der Handel-Helfer ist
   keine Warteschlange, sondern hilft nur bei Ausnahmen unter Master Loot (Empfänger zu weit weg,
   Gruppenplündern); D-27 bekommt dazu einen Satz. Einverstanden?
5. **Lootregeln: Standard "Ein Klick" oder "automatisch"?** Vorschlag: "Ein Klick"; "automatisch"
   als Einstellung, wenn Prüfung 12 zeigt, dass Master Loot ohne Klick geht.
6. **Spieler-Regeln ("Item -> Spieler") überhaupt?** Vorschlag: ja, aber nur für einzelne, benannte
   Items.
7. **Regeln anderer Offiziere:** Vorschlag: nur per "Übernehmen". Alternative: die neueste Fassung
   gilt von selbst (wie die Bankbedarfe).
8. **Würfel-Fenster: "Passen" als Addon-Nachricht an die Lootleitung** (Vorschlag) oder gar nichts
   senden? Und Gebote/Bedarf/Gier im Fenster als Addon-Nachricht statt als Chatwort (Vorschlag:
   Addon-Nachricht, zählt wie geflüstert)?
9. **Prüfung allein: Handelszeit-Konstanten.** `/dump Enum.TooltipDataLineType.TradeTimeRemaining`
   (erwartet 36), `/dump BIND_TRADE_TIME_REMAINING` (die Textvorlage), `/dump ERR_TRADE_COMPLETE`,
   `/dump C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(0,1))` (eine GUID, wenn in Tasche 0
   Platz 1 etwas liegt).
   **Ergebnis 2026-10-09 (Nutzer, Client 1.60.1):** `TradeTimeRemaining` = 36; `BIND_TRADE_TIME_REMAINING`
   = "Ihr könnt diesen Gegenstand innerhalb von %s (inklusive Zeit offline) mit anderen Spielern
   handeln, die ebenfalls berechtigt waren, diesen Gegenstand zu plündern."; `ERR_TRADE_COMPLETE` =
   "Handel abgeschlossen." Die GUID-Prüfung steht noch aus.
10. **Prüfung mit Gruppe: gibt es die 2 Stunden Handelszeit in Forever?** Nach einem Item, das in der
    Gruppe geplündert wurde und beim Aufheben gebunden ist:
    `/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b) do local d=C_TooltipInfo.GetBagItem(b,s) for _,l in ipairs(d and d.lines or {}) do if l.type==36 then print(b,s,l.leftText) end end end end`
    Erwartet: eine Zeile mit Platz und Text "... noch 1 Std. 59 Min. handeln". Kommt nichts, entfällt
    Teil 1 oder schrumpft auf die Liste ohne Restzeit.
11. **Prüfung mit Gruppe: Einlegen und Partnername.** Bei offenem Handel (Item in Tasche 0, Platz 1):
    erst `/run C_Container.PickupContainerItem(0,1) ClickTradeButton(1)` (mit Tastendruck), dann
    zurücknehmen und `/run C_Timer.After(1,function() C_Container.PickupContainerItem(0,1) ClickTradeButton(1) end)`
    (ohne Tastendruck). Liegt das Item beide Male im Handel, geht "automatisch". Dazu
    `/dump UnitName("NPC")` (Name und Nachname des Partners) und nach dem Handel mit `/etrace`
    nachsehen, ob `UI_INFO_MESSAGE` mit "Handel abgeschlossen" und `TRADE_ACCEPT_UPDATE` kommen.
12. **Prüfung mit Gruppe: Master Loot in Forever und ohne Klick.** `/dump C_PartyInfo.GetLootMethod()`
    nach dem Umstellen auf Plündermeister (erwartet 2; sonst entfällt Teil 2 ganz). Dann mit offener
    Leiche `/run C_Timer.After(1,function() GiveMasterLoot(1,1) end)`: geht das Item an den ersten
    Kandidaten, geht "automatisch". Und dasselbe einmal im Bosskampf direkt nach dem Kill, solange die
    Sperre noch gilt (`/dump C_RestrictedActions.IsAddOnRestrictionActive(1)`).
13. **Prüfung allein: Würfeln aus dem Addon.** `/run RandomRoll(1,99)` (erwartet die Zeile "Du würfelst
    ... (1-99)"). Im Bosskampf mit Gruppe: ob die Zeile eines anderen lesbar ist (heute: nein, sie ist
    geheim; deshalb die gesperrten Knöpfe).
14. **Zwei Konten?** Hast du einen zweiten Account oder einen Freund für Handels- und Gruppentests vor
    2026-11-04? Sonst warten alle Zeilen mit "(braucht: Gruppe)" bis zum Start (D-32).

## Entscheidungen

- 2026-10-08: Spec auf Wunsch des Nutzers geschrieben (Paket "Loot-Abend schneller"); noch nicht
  freigegeben, gebaut wird erst nach "passt".
- 2026-10-09: Nutzer gibt frei ("mach dein Vorschlag", Antworten auf die Fragen 4, 5 und 14):
  - Frage 4: der Handel-Helfer kommt nur für Ausnahmen (Master Loot bleibt der Weg, D-27 bekommt
    dazu einen Satz).
  - Frage 5: Lootregeln laufen **automatisch** als Standard (nicht "Ein Klick"); Pause und
    `/amisia regeln probe` bleiben, die Schutzregeln (Reservierung, Prio, Wunsch, Upgrade) auch.
  - Frage 14: kein zweites Konto; Gruppenprüfungen erst ab 2026-11-04.
  - Nachtrag 2026-10-09: Lootregeln haben **beide Modi** zur Wahl, "Automatisch" (Standard) und
    "Ein Klick" (Leiste am Lootfenster mit einem Knopf); Schutzregeln, Probe und Vergabe gleich.
  - Die übrigen Fragen nach den Vorschlägen der Spec (Reihenfolge Lootregeln, Würfel-Fenster,
    Handel-Helfer; Einlegen per Knopf; im Kampf nichts einlegen; Spieler-Regeln nur für benannte
    Items; fremde Regeln nur per "Übernehmen"; "Passen" als Addon-Nachricht).
- 2026-10-09: Teil 3 gebaut (F-075, F-079, DECISIONS D-38): `WS`/`WE`/`WA`, Abschnitt `rollwin`,
  `/amisia wuerfeln test` (en `rolltest`). "Mehrere Items" heißt dabei: das Ergebnis der vorigen
  Runde steht 5 Sekunden unter der neuen; eine neue Runde ersetzt die laufende (keine parallelen Runden).
