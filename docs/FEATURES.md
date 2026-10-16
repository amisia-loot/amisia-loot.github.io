# Features

Was Amisia kann (Addon und Seite), seit welcher Version, wie weit es geprüft ist und wie der Nutzer es
im Spiel prüft. Eine Zeile pro Feature, keine Fehlerbehebungen: ein Fix gehört zu seinem Feature.
`tools/features.py` liest diese Datei, `python3 tools/build.py testlist` macht daraus die Testliste,
`python3 tools/build.py tested F-xxx` trägt ein Ergebnis ein, `build.py release` zeigt am Ende die
Prüfungen der neuen Version. `tools/tests/test_features.py` prüft das Format.

## Format

```
### F-012 Kurzer deutscher Titel
- Version: 2.13.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du ..., dann ...
- Notiz: ...
```

- **Kennung:** `F-` und drei Ziffern, fortlaufend und für immer fest (auch wenn das Feature entfällt:
  dann Notiz "entfernt in X.Y.Z" statt löschen). Ein neues Feature bekommt die nächste freie Nummer,
  auch wenn es in einem anderen Abschnitt steht.
- **Version:** das Release, das das Feature (in seiner heutigen Form) brachte. Ändert ein Release ein
  Feature so, dass es neu geprüft werden muss, bekommt es die neue Version und wieder `gebaut`.
  Seitenfeatures tragen die Addon-Version, mit der sie live gingen (die Seite hat keine eigene).
  `-` nur bei `geplant`.
- **Status**, genau eines von:
  - `geplant`: beschlossen, noch nicht gebaut (meist mit Spec unter `docs/specs`);
  - `gebaut`: in einem Release, noch niemand hat es im Spiel geprüft;
  - `im Spiel geprüft (JJJJ-MM-TT)`: der Nutzer hat bestätigt, dass es im Spiel klappt;
  - `im Raid bewährt (JJJJ-MM-TT)`: in einem echten Raid oder einer echten Gruppe benutzt.
- **Braucht** (nur wenn nötig): `Gruppe`, `Gilde` und/oder `Raid`, mit Komma getrennt. Solche Features
  lassen sich allein nicht prüfen: Gruppen ab dem Start von WoW Forever am 2026-11-04, Raids ab
  2026-12-09 (DECISIONS D-32). Die Testliste zeigt sie erst mit `--all`.
- **Prüfung:** 1 bis 5 Zeilen "Wenn ..., dann ...", konkret und im Spiel (oder auf der Seite) prüfbar,
  mit den echten Befehlen, Knöpfen und Seitennamen.
- **Notiz** (beliebig oft): Belege für einen Status, Grenzen, Verweise.
- Andere Zeilen innerhalb eines Eintrags sind ein Fehler (der Test nennt die Zeile).

## Addon: Grundlagen

### F-001 Hauptfenster im Forever-Stil
- Version: 2.27.0
- Status: gebaut
- Prüfung: Wenn du `/amisia` eingibst, dann öffnet sich das Amisia-Fenster mit Porträt oben links, goldenem Titel und rotem Schließen-X, links oben das Suchfeld und darunter die Seiten des gewählten Reiters, unten am Fenster die Reiter Raid, Ausrüstung, Gilde, Kalender und Amisia.
- Prüfung: Wenn du eine Seite in der Liste anklickst, dann wechselt das Fenster auf sie; Escape schließt das Fenster.
- Prüfung: Wenn du unter Einstellungen, Oberfläche die Fenstergröße (%) verschiebst, dann ändert sich die Größe sofort, und "Fensterposition zurücksetzen" holt es in die Mitte.
- Prüfung: Wenn du die Reiter rechts am Fenster ansiehst (Ausrüstungstabelle, in der Offiziersansicht auch Rolls und Soft-Reserve-Import), dann sitzen die Symbole mit etwas Rand im Reiter, und die Würfel der Rolls sind scharf.
- Notiz: 2026-10-08 im Spiel: Symbole füllten den Reiter ganz aus, die Würfel (UI-GroupLoot-Dice-Up, 32 px) waren verpixelt; 2.13.3 zieht die Symbole 4 px ein und nimmt INV_Misc_Dice_01.
- Notiz: 2.27.0: die aufklappbaren Abschnitte der Seitenliste sind durch die Reiter unten ersetzt (F-094, D-45); das Suchfeld ist F-095, die Kalender-Seite F-096.
- Notiz: 2.29.0: die Seitenliste sieht aus wie die Kategorienliste des Auktionshauses (D-06): dunkle Balken mit Bronzerand, goldene Namen, die gewählte Seite mit hellem Goldrand, keine Symbole. Prüfung: Wenn du `/amisia` öffnest, dann ist jede Seite links ein solcher Balken; unter der Maus leuchtet er und der Name wird weiß; in der Offiziersansicht mit Expertenmodus passen alle Seiten von "Raid" ohne kleinere Zeilen.

### F-094 Reiter unten am Hauptfenster
- Version: 2.27.0
- Status: gebaut
- Prüfung: Wenn du `/amisia` öffnest, dann hängen unten am Fenster die Reiter "Raid", "Ausrüstung", "Gilde", "Kalender" und "Amisia" im Stil der Reiter unter dem Charakterfenster; der gewählte ist hell, und links stehen nur seine Seiten (bei "Raid" Übersicht, Raid-Log, Vergaben, Statistik, Soft-Reserves; in der Offiziersansicht auch Raids, Rolls, Punkte).
- Prüfung: Wenn du auf "Ausrüstung" klickst, dort "Karte" wählst, auf "Raid" und wieder auf "Ausrüstung" klickst, dann öffnet sich wieder "Karte"; nach `/reload` öffnet `/amisia` den Reiter "Ausrüstung" mit "Karte". Fällt eine Seite durch einen Wechsel der Ansicht auf die Übersicht zurück, bleibt die gemerkte Seite des Reiters.
- Prüfung: Wenn du `/amisia einstellungen` eingibst, dann ist der Reiter "Amisia" gewählt und links stehen Einstellungen und "Über und Befehle"; `/amisia statistik` wählt "Raid".
- Prüfung: Wenn du die Ansicht auf "Raider" stellst, dann fehlt unter "Gilde" die Seite Export; die Reiter passen auch auf einem englischen Client nebeneinander ("Raid", "Gear", "Guild", "Calendar", "Amisia").
- Notiz: Spec docs/specs/2026-10-11-fenster-reiter-kalender.md; DECISIONS D-45. Die Reiter sind die Vorlage des Spiels (`PanelTabButtonTemplate`); ein Reiter ohne sichtbare Seite fehlt. Gemerkt in `settings.window.tab` und `pages`.
- Notiz: 2.29.0: die Seiten links unter den Reitern stehen als Balken der Kategorienliste des Auktionshauses (21 px, ohne Symbole); in der Suche ist eine Gruppe ein Balken, ihre Treffer eingerückte Unterbalken (D-06, Nachtrag D-45).

### F-095 Suchfeld oben links im Hauptfenster
- Version: 2.27.0
- Status: gebaut
- Prüfung: Wenn du oben links ins Suchfeld "experten" tippst, dann wird die Seitenliste zur Ergebnisliste mit der Leiste "Einstellungen 1" und dem Eintrag "Expertenmodus"; ein Klick öffnet die Einstellungen mit "Expertenmodus" im Suchfeld der Seite, und das Suchfeld oben links ist wieder leer.
- Prüfung: Wenn du "ra" tippst, dann stehen unter "Seiten" die passenden Seiten (in der Offiziersansicht "Raids" und "Raid-Log"), unter "Einstellungen" höchstens 8 Einträge und in der Offiziersansicht unter "Spieler" Namen aus deinen Raids; ein Klick auf einen Spieler öffnet die Statistik mit ihm unter der Liste.
- Prüfung: Wenn du den Namen eines Items tippst, das in deinen Raids fiel (mindestens drei Buchstaben), dann steht es unter "Items"; die Maus darauf zeigt seinen Tooltip, ein Klick setzt den Link in die Chatzeile.
- Prüfung: Wenn du nur einen Buchstaben tippst, dann bleibt die Seitenliste; bei "qqqxx" steht "Nichts gefunden."; Escape oder das X im Feld leeren es und die Seitenliste kommt zurück. Ein Klick auf einen Reiter (auch den gewählten) leert es ebenso und zeigt die Seiten dieses Reiters.
- Notiz: DECISIONS D-45. Items nur mit Namen, die der Client schon kennt (keine Frage an den Server); die Spielersuche gibt es nur in der Offiziersansicht (D-36).

### F-002 Einheitliches Seitengerüst
- Version: 2.12.0
- Status: gebaut
- Prüfung: Wenn du jede Seite der Seitenliste einmal öffnest, dann haben alle denselben Aufbau (Kopfzeile, Filter, Liste, Fußzeile), und kein Text oder Knopf ragt über den Rand oder ist abgeschnitten.
- Prüfung: Wenn eine Seite nichts zu zeigen hat (z. B. Statistik ohne Raid: "Noch kein Raid aufgezeichnet"), dann steht ein Leerzustand mit Erklärung in der Mitte statt einer leeren Liste.
- Notiz: Seit 2.27.0 stehen die Seiten unter ihren Reitern (F-094); "jede Seite der Seitenliste" heißt: jeden Reiter durchklicken. Die Kalender-Seite (F-096) ist mit demselben Gerüst gebaut.

### F-003 Übersicht mit Karten
- Version: 1.4.0
- Status: gebaut
- Prüfung: Wenn du die Seite Übersicht öffnest, dann stehen dort Karten (Raid, Soft-Reserves, Ausrüstung, Vergaben) mit dem Knopf "Ansehen", oder "Noch nichts zu zeigen", solange es nichts gibt.
- Prüfung: Wenn du bei der Karte Ausrüstung auf "Ansehen" klickst, dann öffnet sich die Seite Ausrüstung bei Ziele.

### F-004 Minimap-Button und Schnellmenü
- Version: 1.4.0
- Status: gebaut
- Prüfung: Wenn du mit der Maus über den runden Amisia-Button an der Minimap fährst, dann zeigt der Tooltip "Linksklick: Amisia-Fenster" und "Rechtsklick: Schnellmenü".
- Prüfung: Wenn du ihn rechts anklickst, dann öffnet sich das Schnellmenü (Ausrüstung, Karte, Soft-Reserves, Raid-Log, Einstellungen), und jeder Eintrag öffnet seine Seite.
- Prüfung: Wenn du `/amisia minimap` eingibst, dann verschwindet der Button; noch einmal holt ihn zurück.

### F-005 Einstellungen und Ansichten
- Version: 2.13.3
- Status: gebaut
- Prüfung: Wenn du `/amisia einstellungen` eingibst, dann öffnet sich die Seite Einstellungen mit ihren Abschnitten (Aufnahme, Oberfläche und weitere), jede Einstellung mit Tooltip und "Zurücksetzen".
- Prüfung: Wenn du unter Oberfläche die Ansicht auf "Offizier" stellst, dann erscheinen die Offiziersseiten (Raids, Rolls, Export); auf "Raider" verschwinden sie wieder.
- Prüfung: Wenn du "Expertenmodus" einschaltest, dann erscheint die Seite Werkzeuge mit dem Abschnitt Werkzeuge in den Einstellungen.
- Prüfung: Wenn du ganz unten bei Ansicht oder Expertenmodus klickst und dadurch Abschnitte dazukommen oder wegfallen, dann bleibt die angeklickte Zeile an derselben Stelle im Fenster (die Liste springt nicht).
- Notiz: 2026-10-08 im Spiel: die Ansicht war schwer zu finden (Oberfläche ganz unten), und ein Klick auf "Offizier" ließ die Liste springen; behoben in 2.13.2. Danach sprang sie noch beim Klick auf "Automatisch" (Abschnitte kamen dazu; die Bildlaufleiste des Clients behielt den alten Anteil); 2.13.3 setzt die Zeile auch beim Wechsel des Bildlaufbereichs zurück.

### F-006 Befehle und Seite "Über und Befehle"
- Version: 2.1.0
- Status: gebaut
- Prüfung: Wenn du `/amisia hilfe` eingibst, dann listet der Chat alle Befehle mit kurzer Beschreibung; ein unbekanntes Wort meldet "Unbekannter Befehl" und zeigt die Liste.
- Prüfung: Wenn du die Seite "Über und Befehle" öffnest, dann stehen dort Version, Befehle und die Knöpfe "Selbsttest", "Raid fragen" und "Gilde fragen".

### F-007 Englisch für nicht-deutsche Clients
- Version: 2.9.0
- Status: gebaut
- Prüfung: Wenn du den Client auf Englisch stellst und Amisia öffnest, dann sind alle Seiten, Tooltips und Chatmeldungen englisch, ohne Lücken oder deutsche Reste.
- Prüfung: Wenn du im englischen Client `/amisia help` eingibst, dann zeigt die Liste die englischen Befehle (`/amisia settings`, `/amisia selftest` ...), und die deutschen funktionieren weiter.

### F-008 Selbsttest
- Version: 2.3.1
- Status: im Spiel geprüft (2026-10-07)
- Prüfung: Wenn du `/amisia selbsttest` eingibst, dann öffnet sich das Fenster "Amisia-Selbsttest" mit einem Bericht zum Kopieren, der mit "Amisia-Selbsttest <Version> | Client ..." und "Ergebnis: N OK, N FEHLT, N FEHLER, N WERT" beginnt.
- Prüfung: Wenn du `/amisia selbsttest kurz` eingibst, dann meldet der Chat nur "Selbsttest: keine Probleme ..." oder die Zahl der Probleme.
- Notiz: Berichte des Nutzers 2026-10-06 (2.4.0 und 2.4.6, mehrere Klassen) und 2026-10-07 (2.9.1, 37 OK, 0 FEHLER; Berufe, Talente 50/50 Knoten, Dungeon-Bilder 24/24).

### F-009 Werte messen (AMISIA-WERTE)
- Version: 2.4.6
- Status: im Spiel geprüft (2026-10-06)
- Prüfung: Wenn du `/amisia selbsttest` eingibst, dann steht oben im Bericht eine Zeile "AMISIA-WERTE 1 <KLASSE> <Stufe> ..." mit Stärke, Beweglichkeit, Krit und Angriffskraft deines Charakters.
- Prüfung: Wenn du ein Teil ausziehst und den Selbsttest wiederholst, dann ändern sich die Werte der Zeile entsprechend.
- Notiz: 2026-10-06 sieben Berichte mit AMISIA-WERTE (Schamane, Paladin, Jäger, Priester, Krieger) geschickt; daraus `tools/bis_measured.json`.

### F-010 Namen mit Forever-Nachnamen
- Version: 1.4.0
- Status: gebaut
- Prüfung: Wenn du `/amisia namen` eingibst, dann zeigt der Chat "Du: UnitName = ..." mit dem Namen, wie Amisia ihn liest, und in einer Gruppe dieselbe Zeile für jedes Mitglied.
- Prüfung: Wenn ein Charakter einen Nachnamen trägt, dann steht er in Listen und im Export mit vollem Namen, nicht abgeschnitten.

### F-011 Fenster bleibt bei offener Weltkarte
- Version: 2.9.4
- Status: im Spiel geprüft (2026-10-07)
- Prüfung: Wenn du auf der Seite Karte "Weltkarte öffnen" klickst, dann bleibt das Amisia-Fenster offen und liegt unter der Karte.
- Prüfung: Wenn du die Weltkarte wieder schließt, dann ist das Amisia-Fenster wieder ganz vorn.
- Notiz: Nutzer 2026-10-07 auf die Frage "Bleibt das Fenster beim Öffnen der Weltkarte offen?" (Punkt 2): "2. ist ok".

### F-012 Versionsprüfung in Raid und Gilde
- Version: 2.1.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du `/amisia version` eingibst, dann listet der Chat "Amisia-Versionen:" mit jedem Amisia-Nutzer in Raid und Gilde und seiner Version.
- Prüfung: Wenn ein Gildenmitglied eine neuere Version hat, dann meldet Amisia einmal "Es gibt eine neuere Version (...)".
- Prüfung: Wenn du auf "Über und Befehle" "Gilde fragen" klickst, dann füllt sich die Liste mit den Gildenmitgliedern, die Amisia haben.

### F-071 Speicher messen
- Version: 2.13.1
- Status: im Spiel geprüft (2026-10-08)
- Prüfung: Wenn du `/amisia speicher` eingibst, dann nennt der Chat "Speicher: X MB, davon Müll Y MB, echte Daten Z MB." und die geladenen Datenteile mit ihrer Größe.
- Prüfung: Wenn du vorher die Seite Ausrüstung öffnest, dann steht danach GEAR unter "Geladene Daten" statt unter "Noch nicht geladen".
- Prüfung: Wenn du im Kampf bist, dann misst der Befehl nicht und sagt das.
- Notiz: 2026-10-08 im Spiel: "Speicher: 7.2 MB, davon Müll 1.1 MB, echte Daten 6.1 MB", GEAR und GEAR_WEIGHTS geladen, der Rest wartet. Die Größen der Datenteile messen den Aufbau samt Müll (GEAR 5.1 MB), daher seit 2.13.2 so beschriftet. Im Kampf nicht geprüft.

### F-072 Ansicht umschalten und Einstellungen suchen
- Version: 2.31.0
- Status: gebaut
- Prüfung: Wenn du oben im Fenster links neben "Pausieren" auf "Raider-Ansicht" klickst, dann steht dort "Offiziersansicht", und links erscheinen die Offiziersseiten (Raids, Rolls, Punkte, Export); ein zweiter Klick schaltet zurück.
- Prüfung: Wenn du `/amisia ansicht offizier`, `raider` oder `auto` eingibst, dann wechselt die Ansicht und der Chat nennt sie; ohne Wort nennt er nur die aktuelle.
- Prüfung: Wenn du auf der Seite Einstellungen oben ins Suchfeld "ansicht" tippst, dann stehen nur noch passende Einstellungen da, mit "N Einstellungen gefunden"; ein Abschnittsname wie "Oberfläche" zeigt den ganzen Abschnitt, etwas, das es nicht gibt, "Nichts gefunden ...", und das X zeigt wieder alles; "ÜBERGABE" findet dasselbe wie "übergabe".
- Prüfung: Wenn du `/amisia einstellungen karte` eingibst, dann öffnen sich die Einstellungen mit dem ganzen Abschnitt "Karte und Wegpunkt"; `/amisia einstellungen wegpunkt` sucht nach "wegpunkt".
- Prüfung: Wenn du mit der Maus über eine beliebige Einstellung fährst, dann erklärt ihr Tooltip, was sie tut (keine Einstellung ohne Text).
- Notiz: 2026-10-08: der Nutzer fand die Ansicht unten in den Einstellungen schwer.

### F-101 Einstellungen in logischen Abschnitten
- Version: 2.32.0
- Status: gebaut
- Prüfung: Wenn du vor dem Update eine der umgezogenen Einstellungen geändert hattest (z. B. "Plus-Eins in der Roll-Reihenfolge" an oder "Gewichtung" auf Hardcore), dann steht sie nach dem Update am neuen Ort unverändert.
- Prüfung: Wenn du in der Offiziersansicht die Einstellungen öffnest, dann gibt es die Abschnitte "Wer braucht das?", "Ersatzbank", "Discord-Text" und "Gildenwünsche", aber keinen Abschnitt "Ausrüstung" mehr; "Gewichtung" und "Upgrade-Punkt in der Tabelle" stehen unter "Ausrüstung und Wünsche".
- Prüfung: Wenn du `/amisia einstellungen ersatzbank` eingibst, dann öffnet sich der Abschnitt "Ersatzbank".
- Prüfung: Wenn du unter "Sync und Version" nachsiehst, dann stehen dort nur noch Sync- und Versionsschalter; "Roll-Runden" hat die beiden Plus-Eins-Einstellungen.
- Notiz: Spec `docs/specs/2026-10-13-einstellungen-abschnitte.md`, Migrationsschritt 2 (D-48).

### F-103 Einstellungen nach Reitern, Knopf "Einstellungen", Zurücksetzen
- Version: 2.37.0
- Status: gebaut
- Prüfung: Wenn du die Einstellungen öffnest, dann stehen in der Seitenliste links unter "Einstellungen" die Gruppen Raid, Ausrüstung, Gilde, Kalender und Allgemein, unter der gewählten ihre Abschnitte; ein Klick auf einen Abschnitt zeigt rechts nur dessen Zeilen; ein Klick auf die offene Gruppe (z. B. "Raid") klappt sie zu und wieder auf, ein Klick auf "Einstellungen" alle Gruppen, der Abschnitt rechts bleibt.
- Prüfung: Wenn du auf der Seite Karte oben links neben der Ansicht "Einstellungen" klickst, dann zeigen die Einstellungen nur "Karte und Wegpunkt", oben "Zurück zu Karte"; der Knopf bringt dich zur Karte zurück.
- Prüfung: Wenn du in einem Abschnitt etwas änderst und oben "Zurücksetzen" klickst, dann fragt Amisia nach und setzt nur diesen Abschnitt auf den Standard; der Abschnitt trägt vorher in der Liste den goldenen Punkt.
- Prüfung: Wenn du unter Allgemein, Oberfläche "Alle Einstellungen zurücksetzen" klickst und bestätigst, dann meldet der Chat "N Einstellungen auf den Standard gesetzt.", und deine Raids und Listen sind noch da.
- Prüfung: Wenn du als Raider (Ansicht "Raider") die Einstellungen öffnest, dann fehlen die Offiziersabschnitte, und auf einer Seite ohne eigene Einstellungen (z. B. Talente) fehlt der Knopf.
- Notiz: Spec `docs/specs/2026-10-13-dungeons-einstellungen.md`, Teil B, D-49.

## Addon: Raid und Loot

### F-013 Raid-Aufnahme (Anwesenheit, Bosse, Loot)
- Version: 1.1.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du mit einer Raidgruppe eine Raidinstanz betrittst, dann meldet der Chat "Aufnahme gestartet: <Zone>. /amisia zeigt die Liste.", und `/amisia status` nennt Zone und Zahl der Raider.
- Prüfung: Wenn du `/amisia pause` eingibst, dann meldet der Chat "Aufnahme pausiert."; noch einmal: "Aufnahme aktiv.".
- Prüfung: Wenn der Raid vorbei ist, dann steht er auf der Seite Raids mit Datum, Raidern, Bossen und dem blauen und epischen Loot.

### F-014 Zu-spät-Markierung
- Version: 1.2.3
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du `/amisia spaet 20:00` eingibst, dann meldet der Chat "Raidbeginn 20:00 ...", und unter Einstellungen, Aufnahme steht "Raidbeginn (zu spät ab)" auf 20:00.
- Prüfung: Wenn jemand nach 20:00 zum ersten Mal in den Raid kommt, dann zeigt die Seite Raids "1 zu spät"; wer von der Ersatzbank kommt, ist nie zu spät.
- Prüfung: Wenn an einem Abend zwei Raids laufen, dann zählt die Verspätung nur im ersten.

### F-015 Vergaben, Vergabe-Dialog und Rückgängig
- Version: 1.5.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier im Raid `/amisia award` ohne Angaben eingibst, dann öffnet sich der Vergabe-Dialog; eine Vergabe an einen Spieler, die Bank oder Entzaubern steht danach auf der Seite Vergaben.
- Prüfung: Wenn du `/amisia rueckgaengig` eingibst, dann meldet der Chat "Rückgängig: ..." und die letzte Änderung ist zurückgenommen.
- Prüfung: Wenn du als Raider die Seite Vergaben öffnest, dann siehst du "Deine Items" und dein Plus-Eins.

### F-016 Plus-Eins
- Version: 1.5.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn ein Spieler ein Item mit MS gewinnt, dann zählt `/amisia plus <Name>` "Plus-Eins von <Name> (...): 1."; SR-, OS-, Bank- und Entzaubern-Vergaben zählen nicht.
- Prüfung: Wenn unter Einstellungen, Vergaben "Plus-Eins in der Roll-Reihenfolge" an ist, dann steht im Roll-Fenster der MS-Wurf mit weniger Plus-Eins vor dem höheren.

### F-017 Export für die Website
- Version: 2.34.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier nach dem Raid die Seite Export öffnest, dann steht dort "1 Raid(s) neu oder geändert" und ein Text, der mit `#AMISIA 2` beginnt.
- Prüfung: Wenn du den Text (Strg+A, Strg+C) auf der Website im Reiter Import einfügst, dann zeigt die Vorschau Raider, Bosse und Vergaben des Abends.
- Prüfung: Wenn du danach noch einmal exportierst, dann steht "Nichts Neues seit dem letzten Export ...".
- Prüfung: Wenn als Offizier eine Aufnahme endet und ein Raid noch nicht exportiert ist, dann meldet der Chat "1 Raid ist noch nicht auf der Website. Seite Export oder /amisia export." (abschaltbar unter Aufnahme, "An nicht exportierte Raids erinnern").

### F-018 Loot-Ansage durch die Lootleitung
- Version: 1.6.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Plündermeister eine Boss-Leiche öffnest, dann sagt Amisia die Items einmal im Raidchat an; Materialien werden nie angesagt.
- Prüfung: Wenn zwei Offiziere Amisia haben, dann sagt nur die Lootleitung an, nicht beide.
- Prüfung: Wenn du `/amisia ansage` eingibst, dann wird das offene Lootfenster noch einmal angesagt.

### F-019 Soft-Reserves
- Version: 1.6.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du auf der Seite Soft-Reserves eine softres.it-CSV einfügst und "Importieren" klickst, dann steht dort "N Reservierungen, vom <Datum>", und "Prüfen" zeigt, wer nicht im Raid oder ohne Reserve ist.
- Prüfung: Wenn ein Raider `!sr` flüstert, dann antwortet die Lootleitung per Flüstern mit seinen Reservierungen.
- Prüfung: Wenn du "Erinnern" klickst, dann bekommt jeder im Raid ohne Reservierung nach einer Rückfrage einmal ein Flüstern.
- Notiz: 2.25.2 (2026-10-11): die heutige softres.it-CSV hat den Namen in "Raider Name"; vorher kamen 0 Reservierungen an.
- Notiz: Den Code von softres.it (Knopf "Gargul") liest F-091 (2.26.0).

### F-020 Roll-Runden und Roll-Fenster
- Version: 2.30.1
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du als Offizier mit Alt-Klick ein Item im Lootfenster anklickst (oder `/amisia roll <Item-Link>`), dann öffnet sich das Roll-Fenster mit der Runde, und `/roll` (MS) und `/roll 99` (OS) erscheinen darin.
- Prüfung: Wenn du in der Raider-Ansicht mit Alt-Klick ein Item im Lootfenster anklickst, dann startet keine Runde und es kommt keine Ansage.
- Prüfung: Wenn ein Raider würfelt und der Chat nur seinen Vornamen zeigt, dann steht bei seiner Vergabe "MS" (bzw. "OS"), nicht "-".
- Prüfung: Wenn die Zeit um ist, dann ordnet das Fenster SR vor MS vor OS und steht der Gewinner oben; ein anderer Bereich als 1-100 oder 1-99 wird gezeigt, zählt aber nicht.
- Prüfung: Wenn im Bosskampf Würfe nicht lesbar sind, dann trägst du sie mit `/amisia wurf <Name> <Zahl>` von Hand ein.

### F-021 Upgrade-Spalte und Aussehen-Hinweis im Roll-Fenster
- Version: 2.4.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn eine Runde läuft, dann zeigt das Roll-Fenster pro Wurf, wie viel Prozent Upgrade das Item für diesen Spieler ist.
- Prüfung: Wenn um ein grünes oder blaues Item im Dungeon gewürfelt wird, dann steht der Hinweis "Aussehen: bekommen laut Blizzard alle Berechtigten schon beim Plündern ...".

### F-022 Raid-Log mit Bosskills und Wipes
- Version: 1.7.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn im Raid ein Boss stirbt oder die Gruppe wiped, dann steht er auf der Seite Raid-Log mit Uhrzeit, Dauer und "Dabei:" (die Namen werden nach dem Kampf gelesen).
- Prüfung: Wenn ein Kill fehlt, dann trägt "Boss eintragen" (oder `/amisia boss <Name>`) ihn von Hand nach.
- Prüfung: Wenn du `/amisia log ereignisse` eingibst, dann zeigt der Chat die letzten Kampfereignisse.

### F-023 Ersatzbank und !bench
- Version: 1.7.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn ein Gildenmitglied der Lootleitung `!bench` flüstert, dann antwortet sie "Amisia: Du stehst auf der Ersatzbank (...)", und es steht auf dem Raid-Log unter Ersatzbank.
- Prüfung: Wenn du als Offizier `/amisia ersatz <Name>` eingibst, dann steht der Spieler auf der Ersatzbank; `/amisia ersatz weg <Name>` trägt ihn aus.

### F-024 Discord-Text des Raids
- Version: 1.7.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier nach dem Raid `/amisia discord` eingibst (oder "Discord-Text" im Raid-Log), dann öffnet sich ein Text mit Bossen, Raidern, Ersatzbank, Verspätungen und Vergaben zum Kopieren.
- Prüfung: Wenn du ihn in Discord einfügst, dann pingt er niemanden (keine @-Erwähnung wird ausgelöst).

### F-025 Raid-Abgleich zwischen Offizieren (Hüter)
- Version: 2.1.0
- Status: gebaut
- Braucht: Gilde, Raid
- Prüfung: Wenn zwei Offiziere mit Amisia im selben Raid sind und die Lootleitung etwas vergibt, dann steht die Vergabe nach wenigen Sekunden auch beim anderen auf der Seite Vergaben.
- Prüfung: Wenn der andere Offizier eine Vergabe ändert, dann geht die Änderung an den Hüter und kommt bei beiden gleich an; `/amisia sync` zeigt den gleichen Stand.
- Prüfung: Wenn jemand außerhalb der Gilde Amisia-Nachrichten schickt, dann ändert das nichts.

### F-026 Wer braucht das?
- Version: 2.1.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier `/amisia wer <Item-Link>` eingibst, dann antworten die Amisia-Nutzer im Raid aus ihrer Ausrüstung, und die Liste zeigt, für wen das Item ein Upgrade ist.
- Prüfung: Wenn die Antworten kommen, dann steht nichts davon im Raidchat.

### F-027 Raidmaterialien (gelernt)
- Version: 2.1.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn im Raid eine Handelsware droppt, dann lernt Amisia sie als Raidmaterial, und `/amisia mats` zeigt sie.
- Prüfung: Wenn du `/amisia mats weg <Link>` eingibst, dann ist das Material aus der Liste und wird nicht wieder gelernt; `/amisia mats add <Link>` holt es zurück.

### F-028 Twinks zählen für ihren Main
- Version: 2.4.0
- Status: gebaut
- Prüfung: Wenn du auf der Website im Reiter Roster "Copy for the addon" kopierst und es im Addon auf der Seite Ausrüstung, Gilde bei "Importieren" einfügst, dann meldet der Chat "N Twinks übernommen".
- Prüfung: Wenn du danach `/amisia twinks <Twinkname>` eingibst, dann nennt der Chat seinen Main.
- Prüfung: Wenn ein Twink im Raid ist, dann steht er auf der Seite Raids als "(Twink von <Main>)", und Plus-Eins und Statistik zählen für den Main.

### F-029 Loot-Rat und Loot-Prio
- Version: 2.27.4
- Status: gebaut
- Prüfung: Wenn du als Offizier `/amisia prio <Item-Link>` eingibst, dann öffnet sich der Dialog "Loot-Prio", in dem du Spieler in eine Reihenfolge bringst und eine Notiz schreibst.
- Prüfung: Wenn ein Item eine Prio hat, dann zeigt sein Tooltip "Prio: ...".
- Prüfung: Wenn du im Dialog "Loot-Prio" eines Items mit Prio "Leeren" klickst, dann schließt sich der Dialog sofort, der Chat sagt "Loot-Prio von <Item> geleert." und der Tooltip zeigt keine Prio mehr; `/amisia prio <Item-Link> löschen` tut dasselbe ohne Dialog.
- Prüfung: Wenn du auf der Website im Reiter Loot Council "Copy for the addon" kopierst und im Addon importierst, dann meldet der Chat "N Items mit Prio übernommen".

### F-030 Statistik und Ruhmeshalle
- Version: 2.10.0
- Status: gebaut
- Prüfung: Wenn du `/amisia statistik` eingibst, dann öffnet sich die Seite Statistik; ohne Raid steht "Noch kein Raid aufgezeichnet".
- Prüfung: Wenn Raids aufgezeichnet sind, dann zeigt sie Items, Raids, Teilnahme, Serie und Bosse pro Spieler (Twinks beim Main); ein Klick auf eine Zeile zeigt die Wochen des Spielers.
- Prüfung: Wenn du "Ruhmeshalle" wählst, dann stehen dort die Bestwerte der Gilde, sichtbar für alle.

### F-031 Würfe bei Gruppenloot aufzeichnen
- Version: 2.10.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn in einer Gruppe um ein Item gewürfelt wird (Bedarf, Gier, Entzaubern, Passen), dann zeigt `/amisia log würfe` jeden Spieler mit seiner Wahl, Zahl und dem Gewinner.
- Prüfung: Wenn du im Raid-Log die Würfe öffnest und "Dungeons" wählst, dann stehen dort die Würfe der Dungeon-Läufe.

### F-032 DKP und EPGP
- Version: 2.27.4
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn die Website (Reiter Points) DKP oder EPGP einstellt und du "Copy for the addon" auf der Seite Punkte bei "Einfügen" einfügst, dann zeigt die Seite Punkte den Stand jedes Spielers und "Website vom <Datum>".
- Prüfung: Wenn du `/amisia punkte` eingibst, dann nennt der Chat deinen Punktestand.
- Prüfung: Wenn du als Offizier auf der Seite Punkte bei "Einfügen" den roten Knopf "Punkte entfernen" klickst, dann fragt ein Fenster "Punktestand entfernen?" (mit der Zahl der Korrekturen, die noch nicht auf der Website sind); "Abbrechen" ändert nichts, "Entfernen" löscht den Stand und der Chat sagt "Punktestand entfernt. Einfügen holt ihn von der Website zurück."; `/amisia punkte löschen` fragt genauso, als Raider gibt es den Knopf nicht.
- Prüfung: Wenn du als Offizier `/amisia korrektur <Name> +10 <Grund>` eingibst, dann steht die Korrektur auf der Seite Punkte und geht mit dem nächsten Export an die Website.
- Prüfung: Wenn ein Raid mit Punkten läuft und ein Item verteilt wird, dann bieten die Raider (offen oder verdeckt) bzw. würfeln nach PR, und ein laufender Raid behält sein System, auch wenn die Website umstellt.

### F-073 Vergabe-Verlauf im Tooltip und im Roll-Fenster
- Version: 2.15.0
- Status: gebaut
- Prüfung: Wenn du mit der Maus über ein Item gehst, das in einem aufgezeichneten Raid vergeben wurde (Taschen, Lootfenster, Link im Chat), dann steht im Tooltip z. B. "Vergeben: Fraktur (MS), 09.09."; höchstens drei Zeilen, neueste zuerst, darunter "+N weitere".
- Prüfung: Wenn du `/amisia rueckgaengig` nach einer Vergabe eingibst und das Item wieder ansiehst, dann ist die zurückgenommene Vergabe aus dem Tooltip verschwunden; eine Vergabe an Bank oder Entzauberer steht als "Vergeben: Bank, ..." bzw. "Vergeben: Entzaubern, ...".
- Prüfung: Wenn du unter Einstellungen, Vergaben "Vergabe-Verlauf im Item-Tooltip" ausschaltest, dann steht die Zeile nicht mehr im Tooltip; als Raider findest du den Schalter auch.
- Prüfung: Wenn du als Offizier im Roll-Fenster mit der Maus über einen Wurf gehst, dann zeigt der Tooltip den Namen, "Letzte 4 Wochen: 2 Items (1 MS, 1 OS)" (oder "Letzte 4 Wochen: nichts bekommen") und "Zuletzt: <Item>, <Tag>".
- Notiz: Twinks zählen im Roll-Fenster für ihren Main; im Item-Tooltip steht ein Twink als "Kleinfrak (Twink von Fraktur, MS)". DECISIONS D-36.

### F-074 Lootregeln anlegen, proben und pausieren
- Version: 2.16.0
- Status: gebaut
- Prüfung: Wenn du als Offizier `/amisia regeln` eingibst, dann öffnen sich die Einstellungen beim Abschnitt Lootregeln mit "Pause", "Modus" (Automatisch / Ein Klick), "Eine Zeile im Raidchat" und "Noch keine Regeln. Ohne Regeln verteilt Amisia nichts von selbst."
- Prüfung: Wenn du dort "Qualität", "bis Selten", "Entzaubern" wählst und "Hinzufügen" klickst, dann steht "1. Qualität bis Selten -> Entzaubern" in der Liste, rechts der Entzauberer-Name oder rot "Name fehlt" (der Tooltip sagt "Entzauberer fehlt (Einstellungen, Vergaben)"); "Hoch" verschiebt eine Regel, das rote X entfernt sie.
- Prüfung: Wenn du "Itemliste" wählst, ins Feld klickst und mit Shift-Klick zwei Items aus der Tasche einfügst, dann legt "Hinzufügen" eine Regel "2 Items -> Bank" an; "Item an Spieler" nimmt genau ein Item und einen Namen.
- Prüfung: Wenn du allein eine Leiche oder Truhe öffnest und `/amisia regeln probe` eingibst, dann nennt dein Chat für jedes Item die Regel oder den Grund ("keine Regel", "reserviert", "Loot-Prio") und am Ende den Grund, warum jetzt nichts verteilt würde (allein: "Jetzt würde nichts verteilt: Lootregeln nur im Raid."); nichts wird verteilt. `/amisia regeln probe` mit einem Item-Link prüft dieses Item.
- Prüfung: Wenn du `/amisia regeln pause` eingibst, dann ist "Pause" in den Einstellungen an und der Chat sagt "Lootregeln pausiert"; `/amisia regeln weiter` schaltet zurück.
- Notiz: Spec docs/specs/2026-10-08-loot-abend.md, Teil 2; DECISIONS D-37. Die Spec nannte F-074 bis F-076; F-075 und F-076 bleiben für Würfel-Fenster und Handel-Helfer, die Teile der Lootregeln, die eine Gruppe oder Gilde brauchen, stehen unter F-077 und F-078.

### F-077 Lootregeln im Raid: automatisch oder mit einem Klick verteilen
- Version: 2.16.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du als Plündermeister (Master Loot, Offiziersansicht) mit Regel "Qualität bis Selten -> Entzaubern" die erste Leiche des Raids öffnest, dann sagt dein Chat einmal "Lootregeln aktiv: 1 (Pause: /amisia regeln pause)", eine Sekunde später bekommt der Entzauberer das grüne Item, die Seite Vergaben zeigt "zum Entzaubern" mit Notiz "Regel: Qualität bis Selten -> Entzaubern", und im Raidchat steht "Amisia-Regeln: [Item] zum Entzaubern (Name)."
- Prüfung: Wenn ein Item reserviert ist (oder eine Loot-Prio, einen Gildenwunsch oder eine Upgrade-Antwort hat), dann fasst keine Regel es an, und es steht in der normalen Ansage. Gilt im Modus Automatisch eine Regel "[Episches Item] -> Spieler", dann nennt die Ansage dieses Item nicht, und die Zeile "Amisia-Regeln: ..." sagt, wer es bekam.
- Prüfung: Wenn der Entzauberer zu weit weg ist, dann bleibt das Item liegen und dein Chat sagt "Name ist kein Kandidat für [Item]. Das Item bleibt liegen." (oder, wenn das Item nicht ankommt, "[Item] an Name ist nicht bestätigt ..."); im Raidchat steht nur, was angekommen ist.
- Prüfung: Wenn du unter Lootregeln den Modus "Ein Klick" wählst und eine Leiche öffnest, dann steht neben dem Lootfenster die Leiste "Lootregeln: 2 Items nach Regeln verteilen" mit dem Knopf "Verteilen"; erst der Klick gibt die Items aus. Im Modus Automatisch zeigt die Leiste nur, was verteilt wurde ("Verteilt: ...").
- Prüfung: Wenn du eine Leiche direkt nach einem Bosskill noch in der Kampfsperre öffnest, dann sagt der Chat "Lootregeln warten bis nach dem Kampf (Kampfsperre)." und verteilt, sobald die Sperre endet, solange das Lootfenster offen ist.
- Notiz: Spec-Frage 12 (Master Loot in Forever, GiveMasterLoot ohne Klick) ist erst mit der Gruppe ab 2026-11-04 prüfbar (D-32).

### F-078 Lootregeln an Offiziere senden
- Version: 2.16.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du unter Lootregeln "An Offiziere senden" klickst, dann sieht ein anderer Offizier mit Amisia "Neue Lootregeln von <Name> (N Regeln): ..." und unter Einstellungen, Lootregeln "Neue Lootregeln von <Name>: N neu, M geändert, K entfernt" mit "Übernehmen" und "Ablehnen"; seine eigenen Regeln bleiben, bis er "Übernehmen" klickt.
- Prüfung: Wenn ein Offizier sich nach dem Senden erst einloggt, dann bekommt er den Vorschlag etwa eine Minute nach dem Login.
- Prüfung: Wenn ein Raider ohne Offiziersrang Regeln sendet (z. B. mit einem veränderten Addon), dann erscheint bei niemandem ein Vorschlag.

### F-075 Würfel-Fenster für Raider
- Version: 2.17.0
- Status: gebaut
- Braucht: Gruppe, Gilde
- Prüfung: Wenn die Lootleitung (Offizier, Plündermeister, beide mit Amisia im Schlachtzug) mit Alt-Klick im Lootfenster eine Runde startet, dann sieht der andere Spieler das Fenster "Würfeln" mit Item, Zeitbalken und "Mainspec", "Offspec", "Passen"; die Ansage im Raidchat bleibt (Raider ohne Amisia sehen nur sie).
- Prüfung: Wenn der Raider "Mainspec" klickt, dann steht sein Wurf (1-100) im Roll-Fenster der Lootleitung wie bei `/roll`, und sein Fenster zeigt "Gewürfelt: Mainspec" mit der Zahl; die Würfelknöpfe sind danach aus.
- Prüfung: Wenn der Raider "Passen" klickt, dann steht nichts im Chat, und das Roll-Fenster der Lootleitung zeigt unten "passt: 1 · ohne Antwort: 0".
- Prüfung: Wenn die Runde endet (Zeit oder "Stopp"), dann zeigt das Fenster 5 Sekunden "Gewinner: <Name> (95, MS)" und schließt; bei Gleichstand bekommen nur die Beteiligten mit "Nochmal" ein Fenster mit "Stechen: <Namen>".
- Prüfung: Wenn in einem DKP-Raid der Raider im Fenster eine Zahl über seinem Stand eingibt und "Bieten" klickt, dann flüstert die Lootleitung "Amisia: Gebot abgelehnt: Mehr als der eigene Stand (...)." wie bei `!bid`; ein Spieler ohne Offiziersrang oder ein Offizier, der nicht die Lootleitung ist, öffnet mit einer Runde bei niemandem ein Fenster.
- Notiz: Spec docs/specs/2026-10-08-loot-abend.md, Teil 3; DECISIONS D-38. Im Bosskampf (Kampfsperre) sind die Knöpfe aus ("Würfeln erst nach dem Kampf."); ob eine fremde Würfelzeile im Bosskampf lesbar ist, prüft Spec-Frage 13 erst mit Gruppe ab 2026-11-04.

### F-079 Würfel-Fenster: Probe und Einstellungen
- Version: 2.17.1
- Status: gebaut
- Prüfung: Wenn du `/amisia wuerfeln test` eingibst, dann erscheint das Fenster "Würfeln" mit dem Ruhestein, "Reserviert von dir", dem Zeitbalken und "Mainspec", "Offspec", "Passen", und der Chat sagt "Probe-Runde nur bei dir: nichts wird gesendet. ..."
- Prüfung: Wenn du dort "Offspec" klickst, dann zeigt dein Chat die Würfelzeile des Spiels mit "(1-99)", das Fenster "Gewürfelt: Offspec" und die Zahl, und beide Würfelknöpfe sind aus; "Passen" zeigt "Gepasst. Probe: nichts gesendet."
- Prüfung: Wenn du `/amisia wuerfeln test dkp` (oder `bedarf`) eingibst, dann zeigt das Fenster ein Zahlenfeld mit "Bieten" und "Mindestgebot: 10" (bzw. "Bedarf (Preis 50)" und "Gier (Preis 25)"); das Fenster lässt sich ziehen, das X schließt es, nach der Roll-Dauer (Einstellungen, Rolls und Vergabe, "Roll-Dauer (Sekunden)", oder `/amisia rollzeit <5-120>`) und 3 Sekunden Nachlauf schließt es von selbst.
- Prüfung: Wenn du `/amisia wuerfeln` eingibst, dann öffnen sich die Einstellungen beim Abschnitt Würfel-Fenster mit "Würfel-Fenster zeigen, wenn die Lootleitung eine Runde startet", "Nur zeigen, wenn reserviert, Upgrade oder Wunsch", "Ton, wenn das Fenster aufgeht", "Größe des Würfel-Fensters (%)" und "Position zurücksetzen".
- Prüfung: Wenn du `/amisia wuerfeln aus` eingibst, dann sagt der Chat "Würfel-Fenster aus. ..."; `/amisia wuerfeln an` sagt "Würfel-Fenster an."
- Notiz: Was allein prüfbar ist (F-075 braucht Gruppe und Gilde). Spec-Frage 13 (allein): `/run RandomRoll(1,99)` zeigt dieselbe Zeile wie der Knopf.

### F-076 Handel-Helfer: vergebene Items aus den Taschen übergeben
- Version: 2.18.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du als Plündermeister ein Item dir selbst gibst und es danach im Vergabe-Dialog an Anna vergibst, dann öffnet die Seite Vergaben oben "Noch zu übergeben" mit dem Item, "Anna", der Restzeit (z. B. "noch 1:58 h") und "Vergabe von", und `/amisia uebergabe` nennt es im Chat ("[Item] an Anna, noch 1:58 h"); "Zu den Vergaben" zeigt die Vergaben mit "1 zu übergeben" in der Kopfzeile.
- Prüfung: Wenn Anna den Handel mit dir öffnet, dann steht rechts am Handelsfenster das Fenster "Handel-Helfer" mit "Für Anna: [Item]", "laut Vergabe von <Name>" und dem Knopf "Amisia: 1 Item einlegen"; ein Klick legt das Item in den ersten freien Platz, der Knopf zeigt dann "Amisia: alles eingelegt". Mit einem anderen Spieler erscheint das Fenster nicht.
- Prüfung: Wenn du im Kampf auf den Knopf klickst, dann legt Amisia nichts ein und der Chat sagt "Im Kampf legt Amisia nichts ein. Nach dem Kampf noch einmal klicken."
- Prüfung: Wenn beide "Handeln" gedrückt haben, dann meldet der Chat "Übergeben: [Item] an Anna.", der Eintrag ist aus der Liste, und die Vergabe zeigt "· übergeben"; bricht einer den Handel ab, bleibt der Eintrag stehen.
- Prüfung: Wenn nur noch 30 bzw. 10 Minuten bleiben, dann warnt dein Chat mit Ton "Noch 30 Minuten: [Item] an Anna übergeben." (je einmal); läuft die Zeit ab, sagt er "Nicht mehr handelbar: [Item] (vergeben an Anna)." und der Eintrag verschwindet.
- Notiz: Spec docs/specs/2026-10-08-loot-abend.md, Teil 1; DECISIONS D-39 (Ausnahme zu D-27). Offen bis zur Gruppe ab 2026-11-04: Spec-Frage 10 (gibt es die Tooltipzeile mit der Handelszeit; ohne sie steht "Handelszeit unbekannt" und es gibt keine Warnung) und Frage 11 (Partnername, "Handel abgeschlossen").

### F-080 Handel-Helfer: Befehl, Einstellungen und Selbsttest
- Version: 2.18.0
- Status: gebaut
- Prüfung: Wenn du `/amisia uebergabe` eingibst und nichts offen ist, dann meldet der Chat "Nichts zu übergeben." (`/amisia handover` ebenso).
- Prüfung: Wenn du die Einstellungen öffnest, dann gibt es den Abschnitt "Handel-Helfer" mit "Vergebene Items in deinen Taschen verfolgen", "Warnungen" (bei 30 und 10 Minuten / nur bei 10 Minuten / aus) und "Ton bei einer Warnung"; ist der Helfer aus, sagt `/amisia uebergabe` "Der Handel-Helfer ist aus (Einstellungen, Handel-Helfer)."
- Prüfung: Wenn du mit einem Item in Tasche 0, Platz 1 (dem ersten Platz des Rucksacks) `/amisia selbsttest` ausführst, dann steht unter "Item-Konstanten" "Enum.TooltipDataLineType.TradeTimeRemaining: 36", "Item-GUID (Tasche 0, Platz 1)" mit einer GUID (beginnt mit "Item-") und "Handelszeit in den Taschen".
- Notiz: Was allein prüfbar ist (F-076 braucht Gruppe). Die Zeile Item-GUID ist der offene Teil von Spec-Frage 9.

### F-082 Einrichtungshilfe für den Gildenstart
- Version: 2.21.0
- Status: gebaut
- Prüfung: Wenn du als Offizier nach dem Login zum ersten Mal `/amisia` öffnest, dann erscheint "Amisia einrichten? Ein paar Schritte vor dem ersten Raid." mit "Los", "Später" und "Nicht mehr fragen"; nach "Später" kommt die Frage erst beim nächsten Login (oder `/reload`) wieder, nach "Nicht mehr fragen" nie mehr.
- Prüfung: Wenn du `/amisia einrichten` eingibst, dann öffnet sich "Amisia einrichten" mit "Schritt 1 von 6", "Bank und Entzauberer"; "Mich eintragen" setzt deinen Namen als Entzauberer, und unter Einstellungen, Vergaben steht er sofort bei "Entzauberer".
- Prüfung: Wenn du mit "Weiter" bis "Erste Lootregeln" gehst und "Grünes zum Entzaubern" klickst, dann steht darunter "1. Qualität bis Ungewöhnlich -> Entzaubern" mit dem Namen des Entzauberers; ein zweiter Klick sagt "Diese Regel gibt es schon." und legt keine zweite an.
- Prüfung: Wenn du in der "Zusammenfassung" bei "Roll-Dauer (Sekunden): ..." auf "Ändern" klickst, dann springt das Fenster zu Schritt 4; "Fertig" schließt es mit "Einrichtung fertig. ..." im Chat, und nach dem nächsten Login fragt Amisia nicht mehr.
- Prüfung: Wenn ein Raider ohne Offiziersrang `/amisia einrichten` eingibt, dann sagt der Chat nur "Die Einrichtung ist für Offiziere. Für dich: Einstellungen, Würfel-Fenster."
- Notiz: DECISIONS D-40; schreibt nur bestehende Einstellungen über ns.Set, "Weiter" und "Überspringen" ändern nichts. `/amisia setup` auf englischen Clients.

### F-083 Raid-Aufstellung planen
- Version: 2.22.0
- Status: gebaut
- Prüfung: Wenn du als Offizier `/amisia aufstellung` eingibst, dann öffnet sich unter Raid die Seite "Aufstellung" mit "Noch keine Anmeldungen", "Einfügen" und "Automatisch einteilen"; nach `/amisia ansicht raider` fehlt sie in der Seitenliste, und `/amisia aufstellung` sagt "Die Aufstellung ist nur für Offiziere." (`/amisia lineup` auf englischen Clients).
- Prüfung: Wenn du "Einfügen" klickst, diesen Text einfügst und "Übernehmen" klickst: "Tanks", "Anna Tankfrau", "Healers", "Bert Heilmann", "Bench", "Carl Bankmann" (je eine Zeile), dann meldet der Chat "Aufstellung: 3 Anmeldungen, ...", unter "Abgleich" stehen Anna mit T und Bert mit H, und unter "Planer" steht Carl rechts bei "Ersatz (1)".
- Prüfung: Wenn du 40 Zeilen "Vorname Nachname Rolle" mit 3 Tanks, 8 Heilern (Rolle "Heiler"), Nahkampf und Fernkampf einfügst (ausgedachte Namen stehen rot "unbekannt", werden aber eingeteilt) und "Automatisch einteilen" klickst, dann zeigt der Planer acht Gruppen mit je 5/5 und einem H, keine ist rot umrandet, die Tanks stehen in Gruppe 1 bis 3, und die Zeile oben sagt "Tanks 3 · Heiler 8 · ...".
- Prüfung: Wenn du im Planer einen Namen anklickst und dann einen anderen (oder einen Namen auf einen anderen ziehst), dann tauschen die beiden ihren Platz; Rechtsklick "Festhalten" zeigt ein Schloss, und nach erneutem "Automatisch einteilen" und `/reload` steht er noch in derselben Gruppe.
- Prüfung: Wenn du deinen eigenen Namen per Rechtsklick auf "Ersatz" setzt und "Ersatz auf die Ersatzbank" klickst (außerhalb eines Raids), dann meldet der Chat "Ersatzbank: <dein Name> (Notiz "Aufstellung").", und `/amisia ersatz` zeigt dich mit der Notiz "Aufstellung".
- Notiz: Spec docs/specs/2026-10-10-raid-aufstellung.md, Teile A, B und E; DECISIONS D-41. Mit der Gilde online (ab 2026-11-04, D-32): "Vulo Hunt Tank" und "vulo pala heiler" stehen grün "gefunden", "Niemand Nirgends Nahkampf" rot "unbekannt"; ein eindeutiger Vorname gelb "vermutlich" ("Bestätigen"), zwei Gleichnamige orange "nicht eindeutig" (Auswahl); ein offline angemeldeter Spieler mit genau einem Twink online zeigt "Twink online: <Name>" mit "tauschen".
- Notiz: Einstellungen, "Raid-Aufstellung": Raidgröße (10/20/40), "Gäste einladen" (aus: Gäste stehen grau "Gast" und werden nicht eingeteilt), "Ersatz automatisch eintragen, sobald die Aufnahme läuft" (aus). Einladen und Sortieren (Teile C und D) sind F-084.

### F-084 Raid-Aufstellung: einladen und Gruppen sortieren
- Version: 2.30.0
- Status: gebaut
- Braucht: Gruppe, Gilde, Raid
- Prüfung: Wenn du auf der Seite Aufstellung in der Ansicht "Einladen" "Alle einladen (N)" klickst, dann sagt der Chat "Einladen: N Spieler, einer alle 0,5 Sekunden.", die eingeteilten Online-Spieler bekommen nacheinander eine Einladung (allein erst vier; sobald der Erste angenommen hat, wird die Gruppe ein Raid, dann folgt der Rest), die Spalte "Einladung" wechselt von "geplant" auf "eingeladen" und "im Raid", und am Ende sagt der Chat "Einladen: N eingeladen.".
- Prüfung: Wenn jemand die Einladung ablehnt, dann steht er rot "abgelehnt" mit "1/3" unter "Versuche", und "Nochmal einladen (1)" lädt ihn erneut ein; wer schon in einer Gruppe ist, steht orange "schon in Gruppe", wer 90 Sekunden nicht antwortet orange "keine Antwort", ein falsch geschriebener Name rot "unbekannt"; nach der dritten Einladung eines Namens gibt es an diesem Abend keine vierte.
- Prüfung: Wenn alle im Raid sind und du in der Ansicht "Planer" "Gruppen sortieren" klickst, dann steht jeder in seiner Gruppe aus dem Planer, wer nicht auf der Liste steht, bleibt, und der Chat sagt "Gruppen sortiert: N Schritte."; beginnt dabei ein Kampf, hört es mit "Sortieren nach dem Kampf fortsetzen." auf, und der Knopf heißt nach dem Kampf "Sortieren fortsetzen".
- Prüfung: Wenn in den Einstellungen `Einladen auf Flüstern "inv"` an ist, heute eine Aufstellung steht und dir ein Gildenmitglied "inv" flüstert, dann wird es eingeladen, und dein Chat sagt "Einladen auf Flüstern: <Name> wird eingeladen."; flüstert dir jemand außerhalb der Gilde "inv", bekommt er nichts, und dein Chat sagt "Einladen auf Flüstern: <Name> ist nicht in der Gilde, nicht eingeladen.".
- Prüfung: Wenn "Offiziere automatisch zum Assistenten" an ist und ein Offizier deiner Gilde deinem Raid beitritt, während du Leiter bist, dann ist er nach etwa 2 Sekunden Assistent, und dein Chat sagt "Assistent: <Name> (Offiziersrang)."; ein Raider ohne Offiziersrang wird es nicht.
- Notiz: Spec docs/specs/2026-10-10-raid-aufstellung.md, Teile C und D; DECISIONS D-41, D-47. Die Prüfungen 12 und 13 der Spec (Umwandeln ohne Nachfrage, Sortieren als Leiter und als Assistent) beantwortet der erste Raid: bitte melden, wenn der Chat "Einladen angehalten: Umwandeln in einen Raid ging nicht." oder "Sortieren angehalten: das Spiel hat <Name> nicht verschoben." sagt. Mit "Einladung flüstern" bekommt jeder Eingeladene einmal am Abend "Amisia: Einladung zum Raid (Gruppe N). Bitte annehmen."; "Automatisch sortieren, wenn jemand beitritt" sortiert nur auf dem Client, der "Alle einladen" geklickt hat. `/amisia aufstellung einladen` und `/amisia aufstellung sortieren` (en `lineup invite`, `lineup sort`).

### F-100 Raid-Aufstellung: Ansicht "Einladen" und ihre Einstellungen
- Version: 2.30.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Aufstellung mit einer eingeteilten Liste die Ansicht "Einladen" wählst, dann steht jede eingeteilte Zeile mit Gruppe, Rolle, Name und "geplant" (offline grau "offline", ein unklarer Name rot "unbekannt", du selbst grün "im Raid"), daneben ein Knopf "Einladen", darüber "Im Raid ... · noch einzuladen N" und rechts "Nochmal einladen (0)" (grau) und "Alle einladen (N)".
- Prüfung: Wenn du an einer Übungspuppe im Kampf bist, dann heißt der Knopf "Nicht im Kampf", ist grau, die Zeile darüber sagt rot "Nicht im Kampf", und niemand wird eingeladen; nach dem Kampf heißt er wieder "Alle einladen (N)".
- Prüfung: Wenn du allein in der Ansicht "Planer" bist, dann ist "Gruppen sortieren" grau, und die Zeile darüber sagt rot "Sortieren: Nur im Raid"; `/amisia aufstellung sortieren` sagt im Chat "Nur im Raid".
- Prüfung: Wenn du in den Einstellungen "Raid-Aufstellung" öffnest, dann stehen dort "Einladung flüstern" (aus), "Automatisch sortieren, wenn jemand beitritt" (an), `Einladen auf Flüstern "inv"` (aus) und "Offiziere automatisch zum Assistenten" (aus), jede mit ihrer Erklärung unter der Maus.
- Notiz: Der allein prüfbare Teil von F-084 (DECISIONS D-47).

### F-085 Kalender-Prüfung
- Version: 2.23.0
- Status: gebaut
- Prüfung: Wenn du als Vulo Hunt ein Gildenereignis "Schlachtzug" für morgen anlegst, das Kalenderfenster schließt und `/amisia selbsttest kalender` eingibst, dann meldet der Chat nach einigen Sekunden "Kalender-Prüfung: N Gildenereignisse, Teilnehmerliste gelesen (N), ohne Tastendruck geht ..." und das Fenster zeigt den Bericht "Amisia-Kalender-Prüfung ..." mit den Abschnitten 17 bis 20 (Termine mit Datum, Art und deinem Status, "Am weitesten voraus", die Teilnehmer mit Klasse und Status, "Blockiert", "Namen mit Nachname", "EventGetInviteResponseTime(1)") zum Kopieren (`/amisia selftest calendar` auf englischen Clients).
- Prüfung: Wenn du das Kalenderfenster offen lässt und `/amisia selbsttest kalender` eingibst, dann steht unter 18 "Kalenderfenster: offen: 18 und 19 übersprungen ...", und im Kalender hat sich nichts geändert (keine Anmeldung, kein Status).
- Notiz: Prüfungen 17 bis 20 der Spec 2026-10-10 (Teil G); nur lesend: die Schreibfunktionen für 23 bis 25 stehen nur als "da"/"fehlen" im Bericht. Den Bericht bitte an uns, danach wird Teil G gebaut.

### F-086 Raid-Aufstellung: Anmeldungen aus dem Spielkalender
- Version: 2.24.0
- Status: gebaut
- Prüfung: Wenn du als Vulo Hunt im Spielkalender ein Gildenereignis für morgen 20:00 anlegst, das Kalenderfenster schließt und auf der Seite Aufstellung "Kalender" klickst, dann steht dein Ereignis in der Liste (Wann, Gildenereignis, Art, "du: bestätigt") und ist gewählt; nach "Übernehmen" meldet der Chat "Aufstellung: Kalender <Titel>, <Tag> 20:00: 1 Einträge, 1 angemeldet, 0 vorläufig, 0 abgesagt.", die Seite zeigt die Nacht von morgen mit Vulo Hunt (Quelle "K", "bestätigt"), und darüber steht "Kalender: <Titel> · <Tag> 20:00 · gelesen <Uhrzeit>".
- Prüfung: Wenn sich Vulo Pala im Kalenderfenster des Spiels für dieses Ereignis anmeldet und du danach als Vulo Hunt "Kalender" und "Übernehmen" klickst, dann steht Vulo Pala grün "angemeldet" als Paladin, mit grauem "H?" (oder der Rolle aus der letzten Aufstellung).
- Prüfung: Wenn du danach "Einfügen" klickst und die zwei Zeilen "Heiler" und "Vulo Pala" übernimmst, dann bleiben die Kalender-Zeilen stehen, Vulo Pala steht einmal da mit den Quellen "L K" und der Rolle H, und die Zeile oben sagt "... · Liste 1 · Kalender 2 · Amisia 0".
- Prüfung: Wenn im Kalenderfenster des Spiels ein anderes Ereignis offen ist und du "Übernehmen" klickst, dann sagt der Chat "Kalenderfenster schließen, dann Übernehmen."; nach einem "Übernehmen" ist im Kalender nichts verändert (keine neue Einladung, kein anderer Status).
- Prüfung: Wenn du das Ereignis im Spielkalender löschst, während die Seite Aufstellung offen ist, dann steht oben nach höchstens einer halben Minute "Ereignis nicht mehr im Kalender", das "K" der Zeilen wird grau, und die Zeilen bleiben.
- Notiz: Braucht: Gilde (ab 2026-11-04, D-32): Wenn sich ein anderes Gildenmitglied im Kalender anmeldet oder absagt, während deine Seite Aufstellung offen ist, dann ändert sich seine Zeile nach wenigen Sekunden ohne Klick ("abgemeldet" nimmt einen Eingeteilten aus der Gruppe, mit der Chatzeile "Aufstellung: <Name> hat sich abgemeldet (war Gruppe N).").
- Notiz: Spec docs/specs/2026-10-10-raid-aufstellung.md, Teil G (G1 und G2); DECISIONS D-42. Jedes Gildenereignis zählt, die Art Schlachtzug ist vorgewählt (Prüfung 17). Der Lesecode ist Raid/Calendar.lua, derselbe wie in `/amisia selbsttest kalender` (F-085).

### F-087 Raid-Anmeldung in Amisia
- Version: 2.25.0
- Status: gebaut
- Prüfung: Wenn du als Vulo Hunt (Gildenereignis für morgen angelegt) etwa eine Minute nach dem Login die Übersicht öffnest, dann zeigt die Karte "Raid-Anmeldung" "<Tag> 20:00 <Titel> · noch offen" und den Knopf "Anmelden"; nach dem Anmelden heißt der Knopf "Ändern", und das Fenster "Raid-Anmeldung" hat unter "Für die Gilde lesbar." keine leere Lücke mehr (die Knöpfe folgen direkt).
- Prüfung: Wenn du "Anmelden" klickst, im Fenster "Raid-Anmeldung" die Rolle "T" wählst, unter "Notiz" "komme 20:15" schreibst und "Anmelden" klickst, dann sagt der Chat "Raid-Anmeldung: <Tag> 20:00 <Titel> · angemeldet als Tank. Gesendet.", die Karte zeigt "angemeldet (T)", und auf der Seite Aufstellung von morgen steht Vulo Hunt mit Quelle "A", Rolle T und einem goldenen "*" am Namen; der Tooltip zeigt "Notiz: komme 20:15".
- Prüfung: Wenn du dich als Vulo Pala mit `/amisia anmelden` (Rolle "H", Knopf "Vorläufig") vorläufig anmeldest und danach als Vulo Hunt einloggst, dann steht Vulo Pala auf der Seite Aufstellung von morgen orange "vorläufig" mit H und Quelle "A" (derselbe Account, ohne Nachricht); im Fenster von Vulo Hunt steht "Deine anderen Charaktere: Vulo Pala: vorläufig (H)".
- Prüfung: Wenn du Vulo Pala als Vulo Hunt im Planer in eine Gruppe setzt, dich als Vulo Pala mit `/amisia abmelden` abmeldest (Chat: "... · abgemeldet. ...") und als Vulo Hunt die Seite Aufstellung öffnest, dann liest der Chat "Aufstellung: Vulo Pala hat sich abgemeldet (war Gruppe N)." und Vulo Pala steht grau "abgemeldet" unten, nicht mehr in der Gruppe; `/amisia hilfe` zeigt `/amisia anmelden [T/H/N/F [Notiz]]` und `/amisia abmelden`, `/amisia anmelden ab` nur "Aufruf: /amisia anmelden [T/H/N/F [Notiz]]".
- Prüfung: Wenn du einen Discord-Text mit "Heiler" und "Vulo Pala" einfügst und Vulo Pala sich danach in Amisia abmeldet, dann steht er "abgemeldet" mit dem Hinweis "Discord: angemeldet".
- Notiz: Braucht: Gilde (ab 2026-11-04, D-32): Wenn sich ein Raider anmeldet, während kein Offizier online ist ("Kein Offizier online: Amisia schickt es, sobald einer kommt."), und sich später ein Offizier einloggt, während der Raider online ist, dann steht die Anmeldung nach höchstens 2 Minuten in der Aufstellung des Offiziers (Frage AQ, Antwort per Flüstern). Wenn ein Raider eine Notiz mit Farbcode und 100 Zeichen sendet, dann zeigt der Offizier höchstens 40 Zeichen ohne Farbe, und kein Chat zeigt die Notiz.
- Notiz: Teil H3 (derselbe Klick trägt auch im Spielkalender ein) ist F-090 (2.25.0). Einstellungen: "Raid-Anmeldung", "Karte auf der Übersicht" (an); "Raid-Aufstellung", "Anmeldungen aus Amisia annehmen" (an). `/amisia signup` und `/amisia signoff` auf englischen Clients. Spec Teil H (H1 und H2), DECISIONS D-42; Raider sehen keine Liste anderer.

### F-088 Raid-Kalender: wer kommt (für die ganze Gilde)
- Version: 2.27.4
- Status: gebaut
- Prüfung: Wenn du als Vulo Pala (kein Offizier) `/amisia kalender` eingibst, dann öffnet sich das Fenster "Raid-Kalender" im Stil des Berufsfensters: links in einem Rahmen die Gildenereignisse der nächsten 14 Tage (je Zeile groß "Mo 12.10.", daneben "20:00", darunter der Titel, rechts dein Stand als farbiges Abzeichen, z. B. grün "angemeldet (H)"; der gewählte Termin leuchtet wie ein gewähltes Rezept), rechts in einem Rahmen für Vulo Hunts Ereignis oben das Symbol der Ereignisart, der Titel groß in Gold, darunter "Mo 12.10. · 20:00 · Schlachtzug", eine Reihe Abzeichen "Tank 0", "Heiler 0", "Nahkampf 0", "Fernkampf 1" mit den Rollen-Symbolen der Gruppensuche und die Summen "angemeldet 1 · vorläufig 0 · abgemeldet 0 · ohne Antwort 0"; darunter die Spaltenköpfe "Rolle, Name, Stufe, Quelle, Notiz" und die Leiste "Angemeldet / Bestätigt 1" mit Vulo Hunt (Rollen-Symbol grau mit "F?" oder farbig wie seine Amisia-Anmeldung, Klassensymbol, Name in Klassenfarbe, Stufe rechtsbündig, Quelle "K", mit Amisia-Anmeldung "K A"); unten links "Kalender gelesen <Uhrzeit>" (nach wenigen Sekunden, nie dauerhaft "Kalender wird gelesen ..."); einen Knopf "Zur Aufstellung" gibt es nicht.
- Prüfung: Wenn du als Vulo Pala im Fenster "Anmelden ..." klickst, im Fenster "Raid-Anmeldung" Rolle "H" und die Notiz "komme 20:15" wählst und "Vorläufig" klickst, dann steht Vulo Pala im Raid-Kalender unter der Leiste "Vorläufig 1" mit dem Heiler-Symbol und "H", Quelle "A" (nach dem nächsten Lesen "K A") und der Notiz; links steht dein Stand orange "vorläufig (H)"; die Maus auf der Zeile zeigt "Notiz: komme 20:15" und die Quellen; die Maus auf dem Abzeichen "Heiler" zeigt die Namen; der Knopf heißt jetzt "Ändern ...".
- Prüfung: Wenn du auf der Übersicht bei der Karte "Raid-Anmeldung" "Kalender" klickst (oder im Fenster "Raid-Anmeldung" "Kalender" neben dem Datum), dann öffnet sich derselbe Raid-Kalender über dem Amisia-Hauptfenster (ein Klick ins Hauptfenster holt dieses nach vorn, ein Klick in den Raid-Kalender ihn wieder; "Anmelden ..." öffnet "Raid-Anmeldung" darüber); du kannst ihn verschieben, Escape schließt ihn, und nach `/reload` öffnet er sich an derselben Stelle. Klickst du unten "Im Kalender zeigen", dann schließt er sich, und das Hauptfenster zeigt den Reiter Kalender mit dem Monat und dem Tag dieses Termins gewählt.
- Prüfung: Wenn du danach als Vulo Hunt `/amisia kalender` öffnest, dann siehst du Vulo Pala mit Heiler-Symbol, "H", "K A" und der Notiz (dieselbe Liste wie in der Aufstellung) und unten zusätzlich "Zur Aufstellung", das die Seite Aufstellung mit dieser Nacht öffnet. Sind mehr Namen da, als Zeilen passen, rollt die Liste mit dem Mausrad und der dünnen Leiste.
- Prüfung: Wenn das Kalenderfenster des Spiels ein anderes Ereignis zeigt, während der Raid-Kalender offen ist, dann steht unten "Kalenderfenster des Spiels schließen, dann liest Amisia die Liste." und im Kalender ändert sich nichts. Liest gerade die Aufstellung oder eine Kalender-Prüfung, steht nach 8 Sekunden "Kalender belegt (Aufstellung, Anmeldung oder Prüfung liest), Amisia versucht es weiter ..." und danach wieder "Kalender gelesen <Uhrzeit>".
- Notiz: Braucht: Gilde (ab 2026-11-04, D-32): Wenn sich ein anderes Gildenmitglied mit Amisia anmeldet, während du online bist, dann steht es nach wenigen Sekunden in deinem Raid-Kalender mit Rolle und Notiz (auch als Raider).
- Notiz: Spec docs/specs/2026-10-10-raid-aufstellung.md, Teil I; DECISIONS D-43 (alle in der Gilde sehen die Liste, Nutzer 2026-10-11; Ebene und Aussehen 2.25.1). Die Daten: Teilnehmerliste des Kalenders (K) und Anmeldungen aus Amisia (A: empfangene AN und die eigenen Charaktere), dieselbe Regel "Welche Angabe gilt" wie die Aufstellung. `/amisia calendar` auf englischen Clients. Fehlen die Rollen- oder Klassensymbole im Spiel, zeigt `/amisia selbsttest` sie unter den Atlanten als fehlend; die Buchstaben T/H/N/F bleiben dann.

### F-096 Kalender-Seite: Monatsblatt im Hauptfenster
- Version: 2.27.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du als Vulo Pala im Hauptfenster unten auf "Kalender" klickst, dann zeigt die Seite oben golden den Monat ("Oktober 2026") zwischen zwei Pfeilen, darunter auf der braunroten Leiste "Mo" bis "So" und 6 Reihen Tage auf Pergament; Tage anderer Monate sind dunkler, heute hat einen goldenen Rahmen, und der Tag von Vulo Hunts Raid zeigt "20:00", den Titel und einen Punkt (grau ohne Anmeldung, grün angemeldet, orange vorläufig).
- Prüfung: Wenn du auf den Tag des Raids klickst, dann stehen rechts der Tag ("Mo 12.10."), "20:00 <Titel>", die Summen "angemeldet N · vorläufig N" und die Teilnehmer wie im Fenster "Raid-Kalender" (Leisten "Angemeldet / Bestätigt", "Vorläufig" ..., Rollen- und Klassensymbol, Name, "K A"); unten "Kalender gelesen <Uhrzeit>" und "Anmelden ..." (nach der Anmeldung "Ändern ..."), das das Fenster "Raid-Anmeldung" öffnet.
- Prüfung: Wenn du auf einen Tag ohne Termin klickst, dann steht rechts "Kein Termin an diesem Tag." und es gibt keinen Knopf; ein Tag mit aufgezeichnetem Raid zeigt die Zone, rechts "Aufgezeichnet: <Zone>", und ein Klick darauf öffnet den Raid-Log dieses Raids.
- Prüfung: Wenn du die Pfeile klickst, dann geht es vorwärts nur bis zum Monat, in dem die gelesenen 14 Tage enden, und zurück bis zum Monat deines ersten aufgezeichneten Raids; "Heute" springt zum heutigen Monat.
- Prüfung: Wenn du als Vulo Hunt (Offizier) dieselbe Seite öffnest, dann steht unten zusätzlich "Zur Aufstellung", das die Aufstellung mit dieser Nacht öffnet; ist das Kalenderfenster des Spiels offen, liest die Seite nicht und sagt "Kalenderfenster des Spiels schließen, dann liest Amisia die Liste.".
- Notiz: Spec docs/specs/2026-10-11-fenster-reiter-kalender.md; DECISIONS D-45. Dieselben Daten, dieselbe Zeile und derselbe Leser wie der Raid-Kalender (F-088), das Fenster bleibt. Woche ab Montag auf einem deutschen Client, ab Sonntag auf einem englischen (wie der Spielkalender). Die Bilder sind die des Spielkalenders (`Interface\Calendar\CalendarBackground`, `Highlights`); fehlen sie im Spiel, bitte melden.

### F-089 Kalender-Schreibprüfung
- Version: 2.25.0
- Status: im Spiel geprüft (2026-10-11)
- Prüfung: Wenn du als Vulo Hunt ein Gildenereignis mit Anmeldung für morgen anlegst, dich als Vulo Pala einloggst (dort noch nicht angemeldet), das Kalenderfenster schließt und `/amisia selbsttest kalender schreiben` eingibst, dann steht im Chat "Kalender-Schreibprüfung: schreibt in den Kalender: meldet dich beim gewählten Ereignis an, vorläufig, entfernt dich und stellt danach deinen alten Stand wieder her. Ereignis: <Titel>, ..." und ein Fenster fragt mit "Ausführen" und "Abbrechen"; bis zum Klick ändert sich im Kalender nichts.
- Prüfung: Wenn du dort "Abbrechen" klickst, dann sagt der Chat "Kalender-Schreibprüfung abgebrochen: nichts geschrieben." und im Kalender ist nichts verändert.
- Prüfung: Wenn du "Ausführen" klickst und etwa eine Minute wartest (nicht kämpfen, Kalenderfenster zu lassen), dann meldet der Chat "Kalender-Schreibprüfung: Anmelden (Menü) ..., Anmelden (EventSignUp) ..., Vorläufig ..., Entfernen ..., Absagen ...; aus einem Timer ...; alter Stand wiederhergestellt. Bericht im Fenster." und das Selbsttest-Fenster zeigt je Versuch "vorher ..., nachher ..." mit OK/WERT/FEHLER; danach steht Vulo Pala im Kalender wieder so wie vorher (nicht angemeldet).
- Prüfung: Wenn du `/amisia selbsttest kalender schreiben` als Vulo Hunt eingibst und es nur seine eigenen Ereignisse gibt, dann sagt der Chat "... braucht ein Gildenereignis mit Anmeldung der nächsten 14 Tage, das ein anderer Charakter angelegt hat ..." und es kommt keine Frage.
- Prüfung: Wenn Vulo Pala bei dem Ereignis schon "Bestätigt", "Ersatz", "Raus" oder "Eingeladen" ist, dann sagt der Chat "Kalender-Schreibprüfung: dein Stand bei ... ist ..., von einem Offizier gesetzt; ... Bitte ein Ereignis nehmen, bei dem du noch nicht angemeldet bist (7 NotSignedup)." und es kommt keine Frage.
- Notiz: Prüfungen 23 bis 25 der Spec 2026-10-10 (Teil H3). Den Bericht bitte an uns: er zeigt, welche Aufrufe gehen; die Anmeldung aus Amisia (F-090) nutzt die Aufrufe, die das Spiel selbst nimmt, und meldet jeden Fehlschlag. `/amisia selftest calendar write` auf englischen Clients.
- Notiz: 2026-10-11 im Spiel (Vulo Pala auf Vulo Hunts Ereignis): alle Schreibwege gehen aus einem Timer, EventTentative aus "angemeldet" und EventDecline ohne Wirkung, alter Stand wiederhergestellt.

### F-090 Raid-Anmeldung trägt auch im Spielkalender ein
- Version: 2.25.0
- Status: gebaut
- Prüfung: Wenn du als Vulo Pala (Kalenderfenster zu, nicht im Kampf) im Fenster "Raid-Anmeldung" bei Vulo Hunts Ereignis mit Anmeldung "Anmelden" klickst, dann sagt der Chat "Raid-Anmeldung: ... angemeldet als ... Gesendet." und wenige Sekunden später "Spielkalender: angemeldet.", und im Kalenderfenster des Spiels steht Vulo Pala bei diesem Ereignis "Angemeldet"; im Fenster steht kein Hinweis "Bitte auch im Kalender eintragen.".
- Prüfung: Wenn du danach "Vorläufig" klickst, dann sagt der Chat "Spielkalender: vorläufig." und das Kalenderfenster zeigt "Vorläufig"; nach "Abmelden" sagt er "Spielkalender: entfernt." und Vulo Pala steht im Kalender nicht mehr angemeldet.
- Prüfung: Wenn du `/amisia anmelden h` eingibst, dann trägt derselbe Befehl dich auch im Kalender ein ("Spielkalender: angemeldet."); bei Vulo Hunts eigenem Ereignis sagt der Chat stattdessen "Spielkalender: du hast das Ereignis angelegt, dort bleibt dein Stand.".
- Prüfung: Wenn das Kalenderfenster des Spiels offen ist (oder du im Kampf bist) und du "Anmelden" klickst, dann sagt der Chat "Spielkalender: nicht eingetragen (Das Kalenderfenster des Spiels ist offen.) Bitte auch im Kalender eintragen.", und das Fenster zeigt "Bitte auch im Kalender eintragen." mit "Kalender öffnen" (Tooltip: der Grund). Ebenso ohne Kalender-Eintrag, aber mit dem Hinweis: mit "Auch im Spielkalender eintragen" (Einstellungen, "Raid-Anmeldung") aus.
- Prüfung: Wenn Vulo Hunt Vulo Pala im Kalender auf "Bestätigt" (oder "Ersatz", "Raus") gesetzt hat und Vulo Pala in Amisia "Anmelden" oder "Vorläufig" klickt, dann ändert sich im Kalender nichts und der Chat sagt einmal "Spielkalender: ein Offizier hat deinen Stand gesetzt (bestätigt), dort bleibt er." ("Abmelden" entfernt ihn dort wie "Entfernen"); nach Mitternacht (vor 06:00) beim Raid von gestern Abend sagt er stattdessen "Spielkalender: der Termin liegt an einem vergangenen Tag, dort ändert sich nichts mehr.".
- Notiz: Spec docs/specs/2026-10-10-raid-aufstellung.md, Teil H3; DECISIONS D-42. Erst `/amisia selbsttest kalender schreiben` (F-089) laufen lassen: zeigt der Bericht, dass ein Aufruf nicht geht, passen wir `CW.PLAN` in Raid/CalendarWrite.lua an. Die Wiederholung nach dem Login und die Antwort auf `AQ` schreiben nie in den Kalender.

### F-091 Soft-Reserves: softres.it-Code (Gargul-Export) einlesen
- Version: 2.26.0
- Status: gebaut
- Prüfung: Wenn du auf softres.it bei deinem Raid "Gargul" öffnest, "Copy to Clipboard" klickst, in Amisia auf der Seite Soft-Reserves "Importieren" klickst und den Text einfügst, dann beginnt die Zeile unter dem Textfeld nach einem Moment mit "Gargul-Code erkannt: N Reservierungen, M Hard-Reserves", und "Übernehmen" meldet "N Reservierungen übernommen, Hard-Reserves: M." mit denselben Zahlen wie auf softres.it.
- Prüfung: Wenn du stattdessen den Beispielcode `eNpljzFPxDAMhf+L5wxNVdoj27EwggSIAXVwa1dEpMnJSVmq/ncSDkErMsXv6X1+XmHmhIQJwaxgCQzgoOuRQMEojInpnMDo7la3N1V+CpYLHWX9LQtaekooKf46bd0U590SsQczoYusgGwcg9CLuLwMNgUxTEk4snxyBPO2gseZs3f2HksNhzHr8CiWY8qCD6nY+XdxS3zwJZXX2MTzNV/O0KeTbja1H/oy/rDvwrBDv6KIDfLHfkb/ceDrf/yu6tqM7PN9KHTof/XrqlEwZaqBe+uId81Lagh+iRKcK5l++wJJR3km` einfügst und "Übernehmen" klickst, dann zeigt die Vorschau "Gargul-Code erkannt: 3 Reservierungen, 1 Hard-Reserve", die Seite Soft-Reserves Anna mit [Choker of the Fire Lord] x2 und Bob mit [Bonereaver's Edge], und der Tooltip von [Bonereaver's Edge] auf der Seite "Reserviert: Bob (Tank, softres +1: 1)"; `/amisia plus Bob` bleibt bei 0.
- Prüfung: Wenn du aus dem Code ein Zeichen in der Mitte löschst, dann sagt die Vorschau "Der Code ist unvollständig oder verändert. Auf softres.it 'Gargul' öffnen, ..." und "Übernehmen" sagt dasselbe und lässt die geladene Liste, wie sie ist.
- Prüfung: Wenn du nach dem Beispielcode in der Offiziersansicht `/amisia roll item:17204 20` eingibst, dann fragt ein Fenster "Hard-Reserve für Gilde. Trotzdem würfeln?"; erst "Würfeln" startet die Runde (das Roll-Fenster öffnet sich), "Abbrechen" startet keine.
- Notiz: Spec docs/specs/2026-10-11-softres-gargul.md, Teil A2; DECISIONS D-44 und die Ausnahme von D-05. Entpackt mit `C_EncodingUtil` des Spiels (im Spiel geprüft: `DeserializeJSON` da, Zlib = 1). Bonus-Würfe werden nicht übernommen ("N Bonus-Würfe nicht übernommen"); das softres +1 ist nur ein Hinweis (D-22). Hard-Reserves stehen als "HR: <für>" im Tooltip und als "HR" im Lootfenster, Lootregeln fassen sie nicht an. `/amisia sr <Code>` geht auch, aber eine Chatzeile fasst nur 255 Zeichen: echte Codes gehören ins Fenster.

### F-092 Gargul-Runden: Würfel-Fenster und stilles Mitschreiben
- Version: 2.26.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn ein Gildenmitglied mit Offiziersrang als Plündermeister (ohne Master Loot: als Leiter) mit Gargul eine Runde startet ("You have 20 seconds to roll on [Item]" oder "Du hast 20 Sekunden um auf [Item] zu würfeln"), dann öffnet sich bei dir das Würfel-Fenster mit dem Item und oben "Runde von <Name> (Gargul)"; "Mainspec" würfelt 1-100, "Offspec" 1-99, "Passen" schließt nur.
- Prüfung: Wenn du selbst als Plündermeister in der Offiziersansicht mit Gargul eine Runde startest, dann öffnet sich Amisias Roll-Fenster mit dem Hinweis "Gargul-Runde: Gargul sagt den Gewinner an.", zeigt die Würfe der anderen, und Amisia schreibt nichts in den Chat; bei Gargul's "Stop your rolls!" endet die Runde, und "Ergebnis ansagen" bleibt aus.
- Prüfung: Wenn ein Raider ohne Leiter- oder Plündermeister-Rolle (oder ohne Offiziersrang) eine Gargul-Runde startet, dann öffnet sich bei dir kein Fenster.
- Prüfung: Wenn eine Amisia-Runde läuft und die Lootleitung dazu mit Gargul ein anderes Item startet, dann bleibt die Amisia-Runde, und der Chat der Lootleitung sagt "Gargul-Runde von <Name> auf [Item] erkannt, während eine Amisia-Runde läuft."
- Notiz: Spec Teil B1 ("wer startet, entscheidet"); DECISIONS D-44. Du hast Gargul selbst installiert: in einer Gruppe mit einem Gildenmitglied, das Amisia hat, kannst du mit Gargul starten und beide Seiten prüfen. Einstellungen: Rolls und Vergabe, "Runden anderer Loot-Addons erkennen" (an); Würfel-Fenster, "Fenster auch bei Runden anderer Loot-Addons" (an). Amisia liest nur Gargul's Chatzeilen (Englisch und Deutsch) und sendet nichts an Gargul; im Bosskampf sind die Zeilen geheim, dann gibt es kein Fenster.

### F-093 Rundenansage auch auf Englisch
- Version: 2.26.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du unter Einstellungen, Rolls und Vergabe "Rundenansage auch auf Englisch" einschaltest und in einer Gruppe als Lootleitung eine Runde startest, dann steht nach "Roll auf [Item]: /roll für Mainspec, /roll 99 für Offspec. 20 Sekunden." die Zeile "Roll on [Item]: /roll for main spec, /roll 99 for off spec. 20 seconds." (mit "Reserved by ..." bei reservierten Items).
- Prüfung: Wenn die Einstellung aus ist (Standard), dann kommt nur die deutsche Ansage.
- Notiz: Spec Teil B4; DECISIONS D-44. Für Raider mit Gargul oder englischem Client: sie würfeln mit `/roll` (MS) und `/roll 99` (OS), genau Gargul's Standardbereiche. Ein englischer Client sagt ohnehin Englisch an und schreibt keine zweite Zeile.

### F-097 Gruppen-Prüfung
- Version: 2.28.0
- Status: gebaut
- Prüfung: Wenn du außerhalb des Kampfes `/amisia selbsttest gruppe` eingibst, dann steht im Chat sofort "Spieler 'Niemand Nirgends' nicht gefunden." (oder die Meldung deines Clients), nach etwa 2 Sekunden noch einmal, und nach etwa 6 Sekunden "Gruppen-Prüfung: Einladen aus dem Tastendruck Spieler nicht gefunden, aus einem Timer ...; N Raid-IDs; Buffs ...; Haltbarkeit ... %; Itemstufe ...; Verzauberungen ...; freie Talentpunkte ...; N Problem(e). Bericht im Fenster." (`/amisia selftest group` auf englischen Clients).
- Prüfung: Wenn du vorher ein Fläschchen oder Essen nimmst, dann listet der Bericht unter "Auren" die Buffs mit Zauber-ID und Dauer und unter "Lange Buffs (Fläschchen, Elixier, Essen?)" diesen Buff; unter "Haltbarkeit" steht jedes angelegte Item mit "aktuell/maximal (Prozent)", unter "Ausrüstung" je Item "Verzauberung im Link ..., Zeile Typ 15: ..." und "Zeilenarten gesehen: ...".
- Prüfung: Wenn du diese Woche in einem Dungeon oder Raid gespeichert bist, dann stehen unter "Raid-IDs" "UPDATE_INSTANCE_INFO: 1-mal nach RequestRaidInfo" und je Raid-ID Name, ID, Schwierigkeit, gesperrt und Reset mit Datum.
- Prüfung: Wenn du im Kampf (an einer Übungspuppe) `/amisia selbsttest gruppe` eingibst, dann wird niemand eingeladen ("übersprungen (im Kampf)"), und unter "Auren" steht, wie viele Buffs jetzt geheim sind.
- Notiz: Prüfungen 10 und 11 der Spec 2026-10-10 (Teil C) und die Datenquellen der Spec 2026-10-12 (Raid-Check, Raid-IDs), allein; Prüfung 13 (Sortieren) und Umwandeln brauchen einen Raid, der Befehl schlägt dafür nur die Funktionen nach. Den Bericht bitte an uns, danach werden Einladen/Sortieren (F-084) und der Raid-Check gebaut. Lädt nur den Namen ein, den es nicht gibt; wandelt nie um, sortiert, befördert und startet keinen Bereitschaftscheck.

### F-098 Raid-Check: Buffs & Verbrauch, Ausrüstung
- Version: 2.29.0
- Status: gebaut
- Prüfung: Wenn du als Vulo Hunt (Offiziersansicht) mit einem Fläschchen und Essen ("Satt") im Reiter Raid die Seite "Raid-Check" öffnest (oder `/amisia raidcheck` eingibst), dann steht in "Buffs & Verbrauch" deine Zeile mit grünem "ja" bei Fläschchen und Essen, deiner Amisia-Version und oben "Es fehlt nichts." (ohne Essen ist "Essen" rot "fehlt" und oben "Es fehlt: 1 Essen"); die Maus auf der Zeile zeigt das Fläschchen und das Essen mit Restzeit.
- Prüfung: Wenn du "Ausrüstung" wählst, dann zeigt deine Zeile Itemstufe, niedrigste Haltbarkeit (rot unter 30 %, orange unter 50 %, dahinter in Klammern die Zahl der Items unter 30 %), die Zahl leerer und unverzauberter Plätze (die Maus auf der Zeile nennt sie: Rücken, Brust, Handgelenke, Hände, Füße, Waffenhand, Schild) und freie Talentpunkte wie dein Charakter- und Talentfenster (unter Stufe 60 grau).
- Prüfung: Wenn du an einer Übungspuppe im Kampf "Prüfen" klickst, dann sagt der Chat "Nicht im Kampf.", oben steht orange "Im Kampf: Werte von HH:MM", "Prüfen" ist grau und nichts wird gesendet.
- Prüfung: Wenn du als Vulo Pala (kein Offizier) `/amisia raidcheck` eingibst, dann gibt es keine Seite "Raid-Check", aber der Chat zeigt deine eigene Zeile "Raid-Check: Fläschchen ... · Elixiere ... · Essen ... · Haltbarkeit ... · Itemstufe ... · leer: ... · unverzaubert: ... · freie Talentpunkte ..." und deine Raid-IDs; in den Einstellungen "Raid-Check" stehen nur "Auf Raid-Check antworten" und "Raid-IDs der Gilde mitteilen".
- Prüfung: Wenn du als Vulo Hunt in den Einstellungen "Raid-Check" "Chatzeile \"Es fehlt\" anbieten" einschaltest, dann steht auf der Seite neben "Prüfen" der Knopf "Im Raid-Chat sagen" (ohne Raid grau); ausgeschaltet fehlt er.
- Notiz: Braucht: Gruppe/Raid (ab 2026-11-04, D-32): Wenn ein Raider mit Amisia im Raid ist und du "Prüfen" klickst (oder einen Bereitschaftscheck startest), dann steht nach höchstens 5 Sekunden seine Haltbarkeit und Itemstufe unter "Ausrüstung"; ein Raider ohne Amisia hat "-" und "Ohne Amisia: nur Buffs." im Tooltip; ein Raider außer Sicht zeigt seine eigenen Angaben mit "*". Wenn die Chatzeile an ist und du "Im Raid-Chat sagen" klickst, dann steht im Raid-Chat "Amisia Raid-Check: Es fehlt: Fläschchen: ... · Essen: ... · Haltbarkeit unter 30 %: ..."; im Bosskampf ist der Knopf grau.
- Notiz: Spec docs/specs/2026-10-12-raid-check.md, Teile A und B; DECISIONS D-46. Nachrichten XQ/XA; die Listen (Fläschchen, Elixiere, Essen, Klassen-Buffs) kommen aus den Client-Tabellen (tools/build_raidcheck.py, Data/RaidCheckData.lua); die verzauberbaren Plätze aus der festen Liste, bis `tools/export_db2.ps1` die Tabelle SpellEquippedItems geliefert hat. Klassen-Buffs zählen nur, wenn die Klasse im Raid ist (Willenskraft nur, wenn jemand sie trägt).

### F-099 Raid-IDs von Mains und Twinks
- Version: 2.29.0
- Status: gebaut
- Prüfung: Wenn Vulo Pala eine Raid- oder Dungeon-ID hat (einen Boss getötet) und du danach als Vulo Hunt einloggst und auf der Seite "Raid-Check" "Raid-IDs" wählst, dann steht oben die Instanz (z. B. "Geschmolzener Kern: 1 frei · 1 gesperrt · N unbekannt"), Vulo Pala rot "gesperrt (4/10, Reset Mi 05:00)" und Vulo Hunt grün "frei"; mit der Twink-Liste der Website steht Vulo Pala eingerückt unter Vulo Hunt, und die Maus auf Vulo Pala nennt "Freie Twinks: Vulo Hunt".
- Prüfung: Wenn der Reset der ID vorbei ist, dann steht Vulo Pala wieder grün "frei" (spätestens nach dem nächsten Login).
- Prüfung: Wenn du "nur frei" oder "nur Stufe 60" anklickst, dann verschwinden die gesperrten Namen bzw. Vulo Pala (Stufe unter 60); "Raid-IDs abfragen" sagt im Chat "Raid-IDs: die Gilde ist gefragt, ..." und ist danach 5 Minuten grau.
- Prüfung: Wenn du auf der Seite Aufstellung eine Liste mit Vulo Pala und Vulo Hunt hast, dann steht neben "Abgleich"/"Planer" die Auswahl "ID: <Instanz>" und in der Spalte "ID" bei Vulo Pala ein rotes, bei Vulo Hunt ein grünes "ID"; "Raid-ID: aus" nimmt die Zeichen weg.
- Prüfung: Wenn du als Vulo Pala `/amisia raidcheck` eingibst, dann stehen im Chat "Raid-IDs Vulo Hunt: keine" und "Raid-IDs Vulo Pala: <Instanz> 4/10, Reset ..." (die Charaktere dieses Kontos).
- Notiz: Braucht: Gilde (ab 2026-11-04, D-32): Wenn ein Gildenmitglied mit Amisia eine ID hat und du "Raid-IDs abfragen" klickst, dann steht es nach höchstens 30 Sekunden mit seinen Twinks in der Liste (von einem anderen Charakter seines Kontos gemeldet: grau "laut <Name>"); auf der Seite Aufstellung trägt jeder Name ein grünes oder rotes "ID", und der Tooltip nennt die freien Twinks seines Mains.
- Notiz: Spec docs/specs/2026-10-12-raid-check.md, Teil C; DECISIONS D-46. Nachrichten IV/IQ, gespeichert in AmisiaDB.raidcheck. Einstellung "Raid-IDs der Gilde mitteilen" (an); nur Offiziere sehen die Raid-IDs anderer, jeder seine eigenen (`/amisia raidcheck`). Die Reset-Zeit ist die, die das Spiel pro ID nennt (Forevers Regeln sind vor 2026-12-09 unbekannt, Prüfung 17 der Spec).

## Addon: Gilde

### F-033 Gildenbank: Bestand, Bedarf, Zusagen und Protokoll
- Version: 2.10.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du die Gildenbank öffnest, dann zeigt die Seite Gildenbank unter Bestand "Gezählt am <Datum>" mit den Raidmaterialien, die in den sichtbaren Tabs liegen.
- Prüfung: Wenn ein Offizier unter Bedarf ein Material wählt, Minimum einstellt und "Setzen" klickt, dann sehen alle Amisia-Nutzer der Gilde den Bedarf und können "Spenden zusagen".
- Prüfung: Wenn du unter Protokoll schaust, dann stehen Einzahlungen und Abhebungen jedes Tabs, das du sehen darfst, und das Goldprotokoll.

### F-034 Gildenwünsche
- Version: 1.8.0
- Status: gebaut
- Prüfung: Wenn du als Offizier `/amisia wuensche` eingibst, dann öffnet sich die Seite Ausrüstung bei Gilde mit dem Feld zum Einfügen; der Text aus dem Reiter Wishlist ("Copy for the addon") meldet "N Wünsche übernommen".
- Prüfung: Wenn ein Item gewünscht ist, dann zeigt sein Tooltip, wer es sich wünscht; die Würfelordnung ändert sich nicht.

### F-035 Wer kann was herstellen (Rezept-Austausch)
- Version: 2.10.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn Gildenmitglieder mit Amisia ihr Berufsfenster einmal geöffnet haben, dann zeigt die Seite Berufe bei einem Rezept "Hergestellt von: <Namen>", und der Filter Gilde zeigt nur Rezepte, die jemand aus der Gilde kennt.
- Prüfung: Wenn du bei einem Rezept "Fragen" klickst, dann öffnet sich ein Flüstern an jemanden, der es kennt (wer online ist, zuerst).
- Prüfung: Wenn du `/amisia hersteller` eingibst, dann meldet der Chat den Stand des Rezept-Austauschs.

### F-036 Drop-Daten der Gilde
- Version: 2.3.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du in einem Dungeon die Leiche eines Bosses plünderst, dann zählt `/amisia drops` einen Kill mehr ("N Kills (N eigene, N gehörte) ...").
- Prüfung: Wenn ein anderes Gildenmitglied mit Amisia Kills hat, dann kommen sie außerhalb von Instanzen als "gehörte" Kills an, ohne Spielernamen.
- Prüfung: Wenn du `/amisia drops export` eingibst und den Text im Reiter Import der Website einfügst, dann zeigt der Reiter Loot Tables die beobachteten Drops mit der Zahl der Kills.

### F-037 Quellen-Austausch in der Gilde
- Version: 2.9.2
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn ein anderes Gildenmitglied mit Amisia Quests, Händler und Weltdrops gesammelt hat, dann steigt bei dir nach einiger Zeit außerhalb von Instanzen "Gelernt" in `/amisia quellen`.
- Prüfung: Wenn ein Ort nur von einem anderen Spieler gemeldet ist, dann setzt Amisia keinen Wegpunkt dorthin; der Ort steht als Text mit "(von der Gilde)".

### F-104 Seite Mitglieder (Gildenliste mit Ort und Berufen)
- Version: 2.38.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du im Reiter Gilde "Mitglieder" öffnest, dann steht dort jedes Gildenmitglied mit Name in Klassenfarbe, Stufe, Klasse, Rang und Ort; wer online ist, zuerst und grün.
- Prüfung: Wenn ein Mitglied offline ist, dann steht unter dem Ort "zuletzt vor …" wie im Gildenfenster des Spiels.
- Prüfung: Wenn ein Gildenmitglied mit Amisia Berufe hat, dann zeigt seine Zeile sie mit Skill (z. B. "Alchemie 225"); deine eigenen immer.
- Prüfung: Wenn du Klasse oder Beruf im Dropdown wählst oder "nur online" anhakst, dann bleiben nur passende Zeilen, unten steht die Zahl.
- Prüfung: Wenn du eine Zeile anklickst und "Flüstern" wählst, dann steht "/w Name " in der Chatzeile.
- Notiz: Spec `docs/specs/2026-10-16-gilde-mitglieder.md`.

### F-106 Duelle: Verlauf, Rangliste, Klassen
- Version: 2.40.0
- Status: gebaut
- Prüfung: Wenn du ein Duell gewinnst oder verlierst, dann steht es im Reiter PvP auf der Seite Duelle im Verlauf mit Zeit, beiden Namen in Klassenfarbe mit Klasse, "Sieg" und dem Ort.
- Prüfung: Wenn zwei andere in deiner Nähe ein Duell beenden, dann steht auch ihr Duell im Verlauf.
- Prüfung: Wenn jemand aus einem Duell flieht (Abstand), dann steht es als "Flucht" mit ihm als Verlierer.
- Prüfung: Wenn ein Spieler "unbekannt" ist und du "Klassen suchen" klickst, dann geht kein Fenster auf, der Chat sagt "Duelle: /who ... brachte N Klassen", seine Klasse steht danach in allen seinen Duellen (sofern /who ihn findet) und die Zahl auf dem Knopf sinkt.
- Prüfung: Wenn du die Ansicht Klassen öffnest, dann siehst du je Klasse Spiele, Spieler, S-N und Siegrate und unten, wie viel Prozent der Klassen bekannt sind; ein Klick auf eine Klasse zeigt sie gegen jede andere.
- Notiz: Spec `docs/specs/2026-10-16-duelle.md`; DECISIONS D-52. Nichts wird gesendet; Duelle der Gilde teilen wäre ein eigenes Feature.

## Addon: Ausrüstung und Welt

### F-038 Ausrüstungstabelle
- Version: 2.30.1
- Status: gebaut
- Prüfung: Wenn du unter Einstellungen "Upgrade erst ab (Prozent mehr Wertung)" auf 10 stellst, dann verschwinden in deiner Spalte der Tabelle die Upgrade-Punkte der kleinen Verbesserungen, genau wie ihr "Upgrade für dich" im Tooltip.
- Prüfung: Wenn du `/amisia gear` eingibst (oder auf der Seite Ausrüstung "Tabelle"), dann öffnet sich die Ausrüstungstabelle mit den besten Items aller Levelbereiche für jede Spezialisierung.
- Prüfung: Wenn du deine eigene Spalte ansiehst, dann plant sie für deine Stufe, nicht für das obere Ende des Levelbereichs.

### F-039 Ziele: beste Ausrüstung mit eigener Wertung
- Version: 2.5.0
- Status: gebaut
- Prüfung: Wenn du `/amisia bis` eingibst, dann öffnet sich die Seite Ausrüstung bei Ziele mit dem besten Item je Slot für deine Spezialisierung und Stufe, mit Quelle und Zuwachs gegen das Angelegte.
- Prüfung: Wenn du "Warum?" bei einem Item klickst, dann erklärt Amisia die Wertung; "Warum diese Gewichte" zeigt die Gewichte deiner Spezialisierung.
- Prüfung: Wenn du bei einem Item "Ausschließen" klickst, dann rückt die nächste Option auf; "zurücksetzen" hebt alle Ausschlüsse auf.
- Prüfung: Wenn du `/amisia bis plan 2h` (oder `dw`, `schild`) eingibst, dann plant die Seite die Waffen entsprechend.

### F-040 Hier: was es an diesem Ort für dich gibt
- Version: 2.5.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Ausrüstung "Hier" wählst, dann zeigt sie, was du in deiner Zone oder Instanz noch holen kannst (Upgrades und Wünsche, Besitz unten).
- Prüfung: Wenn du `/amisia bis hier` in einem Dungeon eingibst, dann zeigt die Liste die Upgrades dieses Dungeons.

### F-041 Upgrade-Prozent im Tooltip
- Version: 2.4.0
- Status: gebaut
- Prüfung: Wenn du mit der Maus über ein Item fährst, das für dich besser ist, dann steht im Tooltip "Upgrade für dich: +N % (...)" mit dem verglichenen Slot.
- Prüfung: Wenn unter Einstellungen, Ausrüstung und Wünsche "Auch \"Kein Upgrade\" im Tooltip zeigen" an ist, dann steht bei schlechteren Items "Kein Upgrade für dich (...)".
- Prüfung: Wenn eine Questbelohnung ein Upgrade ist, dann ist sie im Questfenster markiert.

### F-042 Wunschliste mit Drop-Hinweis
- Version: 1.8.0
- Status: gebaut
- Prüfung: Wenn du `/amisia wunsch <Item-Link> hoch` eingibst, dann meldet der Chat "<Item> auf deiner Wunschliste (hoch ...)", und die Seite Ausrüstung, Wunschliste zeigt es.
- Prüfung: Wenn ein Item von deiner Wunschliste droppt, dann erscheint ein Hinweis mit Ton (abschaltbar unter Einstellungen, Ausrüstung und Wünsche).
- Prüfung: Wenn du das Item bekommst, dann meldet der Chat "<Item> von deiner Wunschliste genommen, du hast das Item."

### F-043 BiS-Empfehlungen (von Hand gesetzte Picks)
- Version: 2.5.3
- Status: gebaut
- Prüfung: Wenn du als Verstärkungs-Schamane der Stufen 30 bis 34 die Seite Ausrüstung, Ziele öffnest, dann steht in der Haupthand Wut des Sturms (280604) mit dem Abzeichen "BiS-Empfehlung".
- Prüfung: Wenn du den Tooltip oder "Warum?" ansiehst, dann nennt die Quelle die Schamanen-Quest nach dem Luft-Totem (Kral der Klingenhauer, letzter Boss und 20 Totems).
- Notiz: Der Nutzer hat den Pick am 2026-10-06 bestellt und am 2026-10-07 nach dem Blick auf Stufe und Questreihe bestätigt: bleibt 30 bis 34 (DECISIONS D-10). Ein ausdrückliches "klappt im Spiel" gibt es nicht; ein schwacher Beleg.

### F-044 Wertung vergleichen und Simulation
- Version: 2.5.0
- Status: gebaut
- Prüfung: Wenn du `/amisia bis vergleich <Link> <Link>` eingibst, dann zeigt Amisia beide Items mit ihrer Wertung und dem Unterschied.
- Prüfung: Wenn du auf der Seite Ausrüstung "Simulation" wählst, dann zeigt sie die besten Items für eine andere Klasse, Spezialisierung oder Stufe, ohne deinen Besitz.
- Prüfung: Wenn ein Item einen Anlegen-Effekt hat, den die Wertung nicht zählt, dann steht "Effekt nicht gewertet" dabei.

### F-045 Karte: Ziel, Pfeil und Pins
- Version: 1.9.0
- Status: gebaut
- Prüfung: Wenn du `/amisia karte <Item-Link>` eingibst, dann setzt Amisia das Ziel zur Quelle des Items ("Ziel ...") mit Wegpunkt und Pfeil; "Ziel erreicht" kommt am Ort.
- Prüfung: Wenn du die Weltkarte öffnest, dann stehen Pins mit Item-Symbol für deine Upgrades und Wünsche (abschaltbar unter Einstellungen, Karte und Wegpunkt).
- Prüfung: Wenn du auf der Seite Karte eine Zeile anklickst, dann wird sie das Ziel; Shift-Klick zeigt sie auf der Weltkarte.

### F-105 Orte auf der Weltkarte (Eingänge, Flugmeister, Zeppeline, Schiffe)
- Version: 2.39.6
- Status: gebaut
- Prüfung: Wenn du die Weltkarte im Brachland öffnest, dann siehst du die Eingänge der Höhlen des Wehklagens und des Kral der Klingenhauer, Flugmeister deiner Fraktion und das Schiff in Ratschet; der Tooltip des Schiffs sagt "Schiff nach Beutebucht".
- Prüfung: Wenn du auf den Eingang der Höhlen des Wehklagens klickst, dann öffnet sich Amisia auf der Seite Dungeons mit diesem Dungeon gewählt, die Weltkarte bleibt vorn; mit Shift setzt der Klick das Ziel zum Eingang (Chat "Ziel ...", Pfeil).
- Prüfung: Wenn du in den Einstellungen (Karte und Wegpunkt) "Flugmeister auf der Karte" ausschaltest oder im Rechtsklick eines Pins "Flugmeister ausblenden" wählst, dann verschwinden die Flugmeister-Pins sofort, die Eingänge bleiben.
- Prüfung: Wenn du als Horde in Durotar und im Schlingendorntal schaust, dann siehst du keine Allianz-Flugmeister; in Beutebucht nur den deiner Fraktion.
- Prüfung: Wenn du `/amisia selbsttest` eingibst, dann stehen dort Zeilen zu C_TaxiMap und C_EncounterJournal und zu den Symbolen Dungeon/Raid; nach dem Betreten eines Dungeons ohne bekannten Eingang (z. B. Hall of Thanes) hat er nach dem nächsten Daten-Build einen Pin.
- Notiz: Spec `docs/specs/2026-10-16-karte-orte.md`; DECISIONS D-50 (gemerkte Eingänge), D-04 (OneForAll-Orte). Namen der Dungeons wie auf der Seite Dungeons (auf deutschen Clients teils englisch). Symbole: Flügelstiefel, Schiff in Fraktionsfarbe, Zeppelin (Media/Icons/place_*.tga), in 2.39.5/2.39.6 neu gezeichnet (glatter Rand, weicher Schatten).

### F-046 Dungeon-Planer: Rangliste, Kette, Quests
- Version: 2.4.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Ausrüstung "Dungeons" wählst und "Rangliste" sortierst, dann stehen die lohnendsten Dungeons für dich oben (offene Quests plus zwei Läufe).
- Prüfung: Wenn du "Kette" wählst, dann zeigt sie bis zu fünf Dungeons hintereinander, jeweils mit den Upgrades des vorigen als angelegt.
- Prüfung: Wenn du `/amisia dungeon quests <Dungeon>` eingibst, dann listet der Chat "Quests in <Dungeon>:" mit Vorquests und Start.
- Prüfung: Wenn du "Wegpunkt zum Eingang" klickst, dann zeigt der Pfeil zum nächsten Eingang.

### F-047 Dungeon-Journal: Bilder, Bossmodell, Quest-EP, Anprobe
- Version: 2.7.0
- Status: gebaut
- Prüfung: Wenn du einen Dungeon im Planer öffnest, dann zeigt er das Bild des Dungeons und das 3D-Modell des Bosses.
- Prüfung: Wenn du die Quests eines Dungeons ansiehst, dann steht bei jeder "EP: ..." (oder "EP: noch nicht gesehen").
- Prüfung: Wenn du "Alle Questgeber auf der Karte" klickst, dann meldet der Chat "N Questgeber auf der Weltkarte markiert." und die Weltkarte zeigt sie; noch einmal entfernt die Markierung.
- Prüfung: Wenn du mit Strg-Klick ein Item der Beuteliste anklickst, dann öffnet sich die Anprobe.

### F-102 Seite Dungeons (Dungeon-Journal)
- Version: 2.37.2
- Status: gebaut
- Prüfung: Wenn du den Reiter Ausrüstung öffnest, dann steht links "Dungeons" direkt unter "Ausrüstung", und die Seite zeigt Rangliste, Bild, Bossmodell und Quests wie bisher; auf der Seite Ausrüstung gibt es den Chip "Dungeons" nicht mehr.
- Prüfung: Wenn du `/amisia journal` oder `/amisia dungeon` eingibst, dann öffnet sich die Seite Dungeons.
- Prüfung: Wenn du auf der Seite Dungeons die Spezialisierung wechselst, dann ist sie auch auf der Seite Ausrüstung gewählt.
- Prüfung: Wenn du mit einer Lederträger-Spezialisierung um Stufe 25 auf der Seite Dungeons Razorfen Kraul ansiehst, dann zählen "Thornweaver Drape" (Roogug) und die Forever-Lederhelme (z. B. "Brawler's Leather Helm") zur Beute, soweit sie Upgrades für dich sind.
- Notiz: Spec `docs/specs/2026-10-13-dungeons-einstellungen.md`, Teil A; vorher der Chip "Dungeons" der Seite Ausrüstung (F-046, F-047).
- Notiz: 2.37.2: Boss-, Trash- und Questbeute der Dungeons zusätzlich aus OneForAll 5.6.0 (nur Items mit Forever-ID oder die der Client kennt; DECISIONS D-04).

### F-048 Quest-Tracker
- Version: 2.7.0
- Status: gebaut
- Prüfung: Wenn du `/amisia quests` eingibst, dann öffnet sich die Seite Quests mit "N im Log · N annehmbar · N gesperrt · N erledigt".
- Prüfung: Wenn du "Nur Upgrades" setzt, dann bleiben nur Quests, deren Belohnung für dich ein Upgrade ist.
- Prüfung: Wenn du bei einer Quest "Weg" klickst, dann setzt Amisia einen Wegpunkt zum Questgeber; ein Klick auf die Quest klappt Reihe und Belohnungen auf.

### F-049 Talentrechner
- Version: 2.19.0
- Status: gebaut
- Prüfung: Wenn du `/amisia talente` eingibst, dann öffnet sich die Seite Talente mit den drei Bäumen deiner Klasse wie im klassischen Talentfenster: jeder Baum ein dunkles Feld, oben mittig der Baumname groß in Gold und darunter klein "N Punkte", keine Stufenzahlen links; fährst du mit der Maus über den Kopf, erscheint oben rechts ein rotes X, und ein Klick darauf oder ein Rechtsklick auf den Kopf setzt nur diesen Baum zurück.
- Prüfung: Wenn du die Knöpfe ansiehst, dann sind es eckige 34-px-Symbole mit dünnem eckigem Rahmen und dem Rang ("0/5") auf einem dunklen Schild unten rechts: noch nicht erreichbar grau und abgedunkelt, erreichbar farbig mit weißem Rang, angefangen mit grünem Rang und grünem Rahmen, voll mit hellgoldenem Rahmen, goldenem Leuchten und goldenem Rang.
- Prüfung: Wenn ein Talent ein anderes voraussetzt, dann verbindet eine gerade Linie mit Pfeilspitze die beiden Knöpfe, golden sobald die Voraussetzung voll ist, sonst dunkelgrau; der Tooltip eines gesperrten Talents nennt "Benötigt N Punkte in <Baum>".
- Prüfung: Wenn du einen Knoten links anklickst, dann steigt sein Rang (rechts: sinkt, Shift: alle Ränge), und die Punktezahl oben stimmt.
- Prüfung: Wenn du "Eigene laden" klickst, dann meldet der Chat "Talente aus dem Spiel geladen (N Punkte)" und die Bäume zeigen deine echten Talente.
- Notiz: 2.9.5 im Spiel geprüft (2026-10-07, runder Rahmen). 2.19.0: Aussehen wie das klassische Talentfenster nach dem Bildschirmfoto des Nutzers 2026-10-10 ("können wir talente auch so machen"); Baum und Knoten laut Selbsttest 2026-10-07 gleich dem Client.
- Notiz: 2.20.0: auf der Seite 34 px statt 36 px und 10 px statt 14 px zwischen den Knöpfen, damit die äußeren Knöpfe (mit Leuchten und Rangschild) mindestens 8 px vom Rand ihres Baums bleiben (Bildschirmfoto des Nutzers 2026-10-10: links und rechts klebten sie am Rand); größer im Talentrechner-Fenster, F-081.

### F-050 Talent-Code teilen und übernehmen
- Version: 2.7.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Talente den Build-Code kopierst (Strg+C), dann beginnt er mit "AT1." und deiner Klasse.
- Prüfung: Wenn du `/amisia talente <Code>` eingibst (oder den Code in das Feld einfügst und Enter drückst), dann meldet der Chat "Code übernommen: <Klasse>, N Punkte." und die Bäume zeigen den Build.
- Prüfung: Wenn der Code kaputt ist, dann meldet der Chat, was nicht stimmt (z. B. "Kein Amisia-Talentcode ..."), und nichts ändert sich.

### F-081 Großes Talentfenster
- Version: 2.20.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Talente unten rechts "Großes Fenster" klickst (oder `/amisia talente gross` eingibst, oder den Reiter mit dem Bogenschützen-Symbol rechts am Amisia-Fenster), dann öffnet sich das Fenster "Talentrechner" mit denselben drei Bäumen, größer (44-px-Symbole), mit Klasse, Stufe, Talentiert, Punkten, "Eigene laden", "Alles zurücksetzen", Code und dem Hinweis "Linksklick: +1 · Rechtsklick: -1 · Shift: alle Ränge"; kein Knopf und kein Rangschild berührt den Rand seines Baums.
- Prüfung: Wenn du im Fenster ein Talent anklickst, dann zeigt die Seite Talente denselben Rang und dieselben Punkte (und umgekehrt); der Reiter am Amisia-Fenster ist markiert, solange das Fenster offen ist.
- Prüfung: Wenn du Strg gedrückt hältst und über dem Fenster das Mausrad drehst, dann wird es in 5-%-Schritten größer oder kleiner (zwischen 70 und 150 %), und unter Einstellungen, Oberfläche steht derselbe Wert bei "Größe des Talentfensters (%)"; der Schieber dort ändert die Größe sofort.
- Prüfung: Wenn du das Fenster verschiebst und `/reload` machst, dann öffnet es sich an derselben Stelle; "Fensterposition zurücksetzen" (Einstellungen, Oberfläche) setzt es in die Bildschirmmitte, Escape schließt es.
- Notiz: Wunsch des Nutzers 2026-10-10 ("können wir das fenster wo die talente sind größer machen oder besser skalieren") mit Bildschirmfoto von 2.19.0.

### F-051 Berufe: Rezepte, Lager, Händlergunst
- Version: 2.9.1
- Status: gebaut
- Prüfung: Wenn du `/amisia berufe` eingibst, dann öffnet sich die Seite Berufe mit den Rezepten deines Berufs, deinem Rang und den Reagenzien jedes Rezepts.
- Prüfung: Wenn du das Berufsfenster einmal öffnest, dann zeigt der Filter "Bekannt" genau die Rezepte, die du kennst.
- Prüfung: Wenn du `/amisia berufe lager` eingibst, dann siehst du die Lagerobjekte (Camping) mit Beschreibung ("Beschreibung lädt ..." nur kurz).
- Prüfung: Wenn du `/amisia berufe gunst` eingibst, dann zeigt die Seite die Händlergunst und welche Items einen Handwerksauftrag haben.
- Notiz: seit 2026-10-11 ist die Rezeptliste nach der Lernstufe sortiert (dann nach Gelb, dann Name); vorher die Reihenfolge der Daten.

### F-052 Magier-Schriftrollen
- Version: 2.10.0
- Status: gebaut
- Prüfung: Wenn du als Magier `/amisia schriftrollen` eingibst, dann öffnet sich die Seite Schriftrollen mit "Arkanes Verständnis: N / N" und den Schriftrollen nach Stufe, gefärbt wie im Berufsfenster.
- Prüfung: Wenn du `/amisia schriftrollen ergebnisse` eingibst, dann zeigt sie die möglichen Ergebnisse; mit `bibliothek` die Bücher für die Bibliothek mit "N von N Büchern abgegeben".
- Prüfung: Wenn du bei einem Eintrag "Weg" klickst, dann setzt Amisia den Wegpunkt auf seinen Ort.

## Addon: Sammeln und Daten

### F-053 Item-Scan
- Version: 1.2.1
- Status: im Spiel geprüft (2026-10-06)
- Prüfung: Wenn du außerhalb einer Instanz `/amisia scan 1 5000` eingibst, dann meldet der Chat "Scan gestartet: ID 1 bis 5000, N Anfragen pro Sekunde ..." und später "Scan fertig: N Items gespeichert ...".
- Prüfung: Wenn du `/amisia scan status` eingibst, dann nennt der Chat den Stand; `/amisia scan stop` hält an, in einer Instanz pausiert der Scan von selbst.
- Prüfung: Wenn du nach dem Scan ausloggst, dann steht der Scan in der Datei Amisia.lua, die der PC an den N100 schickt.
- Notiz: Scan des Nutzers 2026-10-06 kam als Amisia.lua an (20.934 Items); 2.5.4 wurde damit gebaut.

### F-054 Scan-Daten aufräumen
- Version: 2.13.0
- Status: im Spiel geprüft (2026-10-08)
- Prüfung: Wenn du `/amisia scan aufräumen` eingibst, dann meldet der Chat "Scan aufgeräumt (Stand ...): N Items, N Quellen und N offene IDs entfernt, etwa N KB ...".
- Prüfung: Wenn du danach `/reload` machst und ausloggst, dann ist Amisia.lua auf wenige KB geschrumpft (vorher rund 2,4 MB).
- Prüfung: Wenn "Ausgewertete Scan-Daten beim Login entfernen" (Einstellungen, Werkzeuge) an ist, dann räumt Amisia das einige Sekunden nach dem Login von selbst auf, ohne Ruckler.
- Notiz: 2026-10-08: die Amisia.lua des Nutzers kam nach dem ersten Login mit 2.13.0 mit 15 KB statt 2,3 MB an, die Marke `scan.trim` trägt den Stand 2026-10-08; das automatische Aufräumen lief.

### F-055 Quellen-Sammler: Quests, Händler, Weltdrops
- Version: 2.6.0
- Status: im Spiel geprüft (2026-10-07)
- Prüfung: Wenn du eine Quest annimmst und abgibst, dann zählt `/amisia quellen` sie ("Quellen: N Quests, N Händler, N Weltdrop-NPCs ...").
- Prüfung: Wenn du einen Händler mit Ausrüstung oder Rezepten ansprichst, dann zählt er als Händler, mit seinen Waren, Preisen und Ort.
- Prüfung: Wenn du einen Gegner mit einem Weltdrop plünderst, dann zählt er unter Weltdrop-NPCs.
- Notiz: Amisia.lua vom 2026-10-07 hatte 4 Quests mit Geber, Ort und EP, 3 Händler (Handor mit 41 Waren) und 2 Weltdrop-Gegner; der Nutzer bestätigte Quests angenommen und abgegeben zu haben. Die Händlerpreise (2.9.6, 0 gilt als unbekannt) sind danach nicht mehr eigens geprüft.

### F-056 Item-Sammler aus Taschen, Händlern, Loot und Tooltips
- Version: 1.2.1
- Status: gebaut
- Prüfung: Wenn du `/amisia sammeln` eingibst, dann schaltet der Item-Sammler aus oder an; die Seite Werkzeuge (Expertenmodus) zeigt "Item-Sammler: an, N Items mit Quelle.".
- Prüfung: Wenn du ein neues Item looten oder beim Händler siehst, dann steigt die Zahl der Items mit Quelle.

## Seite

### F-057 Loot Log und Vergaben auf der Website
- Version: 1.1.0
- Status: gebaut
- Prüfung: Wenn du auf der Website den Reiter Loot Log öffnest, dann stehen dort alle Vergaben mit Raider, Item, Boss und Datum, Items mit Wowhead-Link.
- Prüfung: Wenn du als Editor angemeldet "Add award" nutzt und "Save changes" klickst, dann steht die Vergabe nach einem Neuladen noch da.

### F-058 Anmeldung, Editoren und Versionen
- Version: 1.1.0
- Status: gebaut
- Prüfung: Wenn du auf der Website "Sign in with Discord" klickst, dann bist du angemeldet, und als Editor erscheinen die Reiter Import und Settings.
- Prüfung: Wenn du in Settings eine frühere Version wiederherstellst ("Restore"), dann zeigt die Seite den alten Stand, und "Discard" verwirft ungespeicherte Änderungen.
- Prüfung: Wenn du nicht angemeldet bist, dann siehst du alles, kannst aber nichts ändern, und nirgends steht eine E-Mail-Adresse.

### F-059 Import der Addon-Exporte
- Version: 1.5.0
- Status: gebaut
- Prüfung: Wenn du im Reiter Import den Export des Addons einfügst und "Preview import" klickst, dann zeigt die Vorschau Raider, Kills, Vergaben, Ersatzbank und Verspätungen.
- Prüfung: Wenn du denselben Export zweimal einfügst, dann kommt nichts doppelt hinein.
- Prüfung: Wenn du einen Loot-Export eines anderen Addons einfügst, dann liest die Seite ihn ebenfalls.

### F-060 Nights und Attendance
- Version: 1.1.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Nights öffnest, dann steht jede Raidnacht mit Raidern und Loot; ein Start vor 06:00 zählt zur Nacht davor.
- Prüfung: Wenn du den Reiter Attendance öffnest, dann zeigt er, wer an welcher Nacht da war, mit Quote; die Ersatzbank zählt nach Settings "Bench counts as".
- Prüfung: Wenn eine Nacht nicht zählen soll (nur Trash), dann steht sie unter Nights mit "(not counted for attendance)" und zählt nicht in die Quoten.

### F-061 Armory und Slot Coverage
- Version: 1.1.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Armory öffnest, dann siehst du die Raider mit ihrem Loot; ein Klick auf einen Raider zeigt seine Items.
- Prüfung: Wenn du den Reiter Slot Coverage öffnest, dann zeigt eine Tabelle, welcher Raider in welchem Slot schon Raid-Loot hat.

### F-062 Wishlist
- Version: 1.8.0
- Status: gebaut
- Prüfung: Wenn du angemeldet im Reiter Wishlist ein Item mit "Add to wishlist" wünschst, dann steht es mit Priorität 1 bis 3 und Notiz in der Liste, und der Loot Log zeigt beim Boss den Bedarf.
- Prüfung: Wenn du die Wunschliste des Addons (Seite Ausrüstung, Wunschliste, "Für die Website") bei "Paste from the addon" einfügst, dann kommen die Wünsche dazu.
- Prüfung: Wenn der Raider das Item bekommen hat, dann gilt der Wunsch als erfüllt.

### F-063 Loot Tables aus beobachteten Drops
- Version: 2.3.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Loot Tables öffnest, dann zeigt er je Dungeon und Boss die Items mit Dropchance aus den Kills der Gilde ("N Kills").
- Prüfung: Wenn du einen Drop-Export des Addons importierst, dann steigen die Zahlen der Kills.

### F-064 Roster mit Twinks
- Version: 2.4.0
- Status: gebaut
- Prüfung: Wenn du im Reiter Roster einen Twink mit seinem Main verknüpfst, dann zählen Loot, Attendance und Stats für den Main; "Unlink" löst es wieder.
- Prüfung: Wenn du "Copy for the addon" klickst, dann kopiert die Seite die Twink-Liste für das Addon (siehe F-028).

### F-065 Loot Council
- Version: 2.10.0
- Status: gebaut
- Prüfung: Wenn du als Editor im Reiter Loot Council einem Item eine Reihenfolge von Spielern und eine Notiz gibst und speicherst, dann steht die Prio dort für alle.
- Prüfung: Wenn du "Copy for the addon" klickst und im Addon importierst, dann zeigt der Item-Tooltip im Spiel dieselbe Prio (siehe F-029).

### F-066 Stats und Hall of Fame
- Version: 2.10.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Stats öffnest, dann zeigt er pro Spieler Items, Raids und Teilnahme (Twinks beim Main) und die Hall of Fame.

### F-067 Points (DKP/EPGP) auf der Website
- Version: 2.11.0
- Status: gebaut
- Prüfung: Wenn du als Editor im Reiter Points DKP oder EPGP einstellst, dann zeigt er den Stand jedes Spielers; "Apply correction" bucht eine Korrektur mit Grund, "Apply the decay" den Verfall.
- Prüfung: Wenn du einen Addon-Export mit Punkten importierst, dann kommen die neuen Buchungen dazu, ohne alte doppelt.
- Prüfung: Wenn du "Copy for the addon" klickst und es im Addon auf der Seite Punkte einfügst, dann zeigt das Addon denselben Stand (siehe F-032).

### F-068 Crafting
- Version: 1.1.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Crafting öffnest, dann stehen die raidwürdigen Rezepte mit den Raidern, die sie herstellen können.
- Prüfung: Wenn du angemeldet "I can craft this" klickst und "Save professions", dann stehst du als Hersteller beim Rezept.

### F-069 Mats: Materialanfragen und Bestand
- Version: 1.1.0
- Status: gebaut
- Prüfung: Wenn du angemeldet im Reiter Mats eine Anfrage stellst ("Send request"), dann sehen die Editoren sie und können "Handed out" oder "Decline" wählen.
- Prüfung: Wenn das Addon eine Gildenbank-Zählung exportiert hat und du sie importierst, dann zeigt Mats den Bestand vom Zähltag.

### F-070 TBC-Archiv
- Version: 2.0.0
- Status: gebaut
- Prüfung: Wenn du auf der Website "TBC archive" klickst, dann zeigt sie den TBC-Ledger mit dem Hinweis "You are looking at the TBC Anniversary archive. It is read-only." und nichts lässt sich ändern.
- Prüfung: Wenn du "Back to Forever" klickst, dann bist du wieder beim Forever-Ledger.
