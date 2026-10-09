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
- Version: 2.13.3
- Status: gebaut
- Prüfung: Wenn du `/amisia` eingibst, dann öffnet sich das Amisia-Fenster mit Porträt oben links, goldenem Titel und rotem Schließen-X, links die Seitenliste mit den Abschnitten Raid, Ausrüstung, Gilde und Amisia.
- Prüfung: Wenn du eine Seite in der Liste anklickst, dann wechselt das Fenster auf sie; Escape schließt das Fenster.
- Prüfung: Wenn du unter Einstellungen, Oberfläche die Fenstergröße (%) verschiebst, dann ändert sich die Größe sofort, und "Fensterposition zurücksetzen" holt es in die Mitte.
- Prüfung: Wenn du die Reiter rechts am Fenster ansiehst (Ausrüstungstabelle, in der Offiziersansicht auch Rolls und Soft-Reserve-Import), dann sitzen die Symbole mit etwas Rand im Reiter, und die Würfel der Rolls sind scharf.
- Notiz: 2026-10-08 im Spiel: Symbole füllten den Reiter ganz aus, die Würfel (UI-GroupLoot-Dice-Up, 32 px) waren verpixelt; 2.13.3 zieht die Symbole 4 px ein und nimmt INV_Misc_Dice_01.

### F-002 Einheitliches Seitengerüst
- Version: 2.12.0
- Status: gebaut
- Prüfung: Wenn du jede Seite der Seitenliste einmal öffnest, dann haben alle denselben Aufbau (Kopfzeile, Filter, Liste, Fußzeile), und kein Text oder Knopf ragt über den Rand oder ist abgeschnitten.
- Prüfung: Wenn eine Seite nichts zu zeigen hat (z. B. Statistik ohne Raid: "Noch kein Raid aufgezeichnet"), dann steht ein Leerzustand mit Erklärung in der Mitte statt einer leeren Liste.

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
- Version: 2.14.0
- Status: gebaut
- Prüfung: Wenn du oben im Fenster links neben "Pausieren" auf "Raider-Ansicht" klickst, dann steht dort "Offiziersansicht", und links erscheinen die Offiziersseiten (Raids, Rolls, Punkte, Export); ein zweiter Klick schaltet zurück.
- Prüfung: Wenn du `/amisia ansicht offizier`, `raider` oder `auto` eingibst, dann wechselt die Ansicht und der Chat nennt sie; ohne Wort nennt er nur die aktuelle.
- Prüfung: Wenn du auf der Seite Einstellungen oben ins Suchfeld "ansicht" tippst, dann stehen nur noch passende Einstellungen da, mit "N Einstellungen gefunden"; ein Abschnittsname wie "Oberfläche" zeigt den ganzen Abschnitt.
- Prüfung: Wenn du etwas suchst, das es nicht gibt, dann steht "Nichts gefunden ..."; das X im Suchfeld zeigt wieder alles.
- Notiz: 2026-10-08: der Nutzer fand die Ansicht unten in den Einstellungen schwer.

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
- Version: 1.5.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier nach dem Raid die Seite Export öffnest, dann steht dort "1 Raid(s) neu oder geändert" und ein Text, der mit `#AMISIA 2` beginnt.
- Prüfung: Wenn du den Text (Strg+A, Strg+C) auf der Website im Reiter Import einfügst, dann zeigt die Vorschau Raider, Bosse und Vergaben des Abends.
- Prüfung: Wenn du danach noch einmal exportierst, dann steht "Nichts Neues seit dem letzten Export ...".

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

### F-020 Roll-Runden und Roll-Fenster
- Version: 1.6.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du als Offizier mit Alt-Klick ein Item im Lootfenster anklickst (oder `/amisia roll <Item-Link>`), dann öffnet sich das Roll-Fenster mit der Runde, und `/roll` (MS) und `/roll 99` (OS) erscheinen darin.
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
- Version: 2.10.0
- Status: gebaut
- Prüfung: Wenn du als Offizier `/amisia prio <Item-Link>` eingibst, dann öffnet sich der Dialog "Loot-Prio", in dem du Spieler in eine Reihenfolge bringst und eine Notiz schreibst.
- Prüfung: Wenn ein Item eine Prio hat, dann zeigt sein Tooltip "Prio: ...".
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
- Version: 2.11.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn die Website (Reiter Points) DKP oder EPGP einstellt und du "Copy for the addon" auf der Seite Punkte bei "Einfügen" einfügst, dann zeigt die Seite Punkte den Stand jedes Spielers und "Website vom <Datum>".
- Prüfung: Wenn du `/amisia punkte` eingibst, dann nennt der Chat deinen Punktestand.
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
- Prüfung: Wenn ein Item reserviert ist (oder eine Loot-Prio, einen Gildenwunsch oder eine Upgrade-Antwort hat), dann fasst keine Regel es an, und es steht in der normalen Ansage.
- Prüfung: Wenn der Entzauberer zu weit weg ist, dann bleibt das Item liegen und dein Chat sagt "Name ist kein Kandidat für [Item]. Das Item bleibt liegen."
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

## Addon: Ausrüstung und Welt

### F-038 Ausrüstungstabelle
- Version: 1.4.1
- Status: gebaut
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

### F-048 Quest-Tracker
- Version: 2.7.0
- Status: gebaut
- Prüfung: Wenn du `/amisia quests` eingibst, dann öffnet sich die Seite Quests mit "N im Log · N annehmbar · N gesperrt · N erledigt".
- Prüfung: Wenn du "Nur Upgrades" setzt, dann bleiben nur Quests, deren Belohnung für dich ein Upgrade ist.
- Prüfung: Wenn du bei einer Quest "Weg" klickst, dann setzt Amisia einen Wegpunkt zum Questgeber; ein Klick auf die Quest klappt Reihe und Belohnungen auf.

### F-049 Talentrechner
- Version: 2.9.5
- Status: im Spiel geprüft (2026-10-07)
- Prüfung: Wenn du `/amisia talente` eingibst, dann öffnet sich die Seite Talente mit den drei Bäumen deiner Klasse; die Knöpfe sind 36 px groß, voll sichtbar, mit dünnem abgerundetem Rahmen (grün frei, gold voll, grau gesperrt).
- Prüfung: Wenn du einen Knoten links anklickst, dann steigt sein Rang (rechts: sinkt, Shift: alle Ränge), und die Punktezahl oben stimmt.
- Prüfung: Wenn du "Eigene laden" klickst, dann meldet der Chat "Talente aus dem Spiel geladen (N Punkte)" und die Bäume zeigen deine echten Talente.
- Notiz: Aussehen nach den Korrekturen des Nutzers (2.9.2 bis 2.9.5); auf die Frage "Wie sieht der Talentrechner aus?" (Punkt 2) am 2026-10-07: "2. ist ok". Baum und Knoten laut Selbsttest 2026-10-07 gleich dem Client.

### F-050 Talent-Code teilen und übernehmen
- Version: 2.7.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Talente den Build-Code kopierst (Strg+C), dann beginnt er mit "AT1." und deiner Klasse.
- Prüfung: Wenn du `/amisia talente <Code>` eingibst (oder den Code in das Feld einfügst und Enter drückst), dann meldet der Chat "Code übernommen: <Klasse>, N Punkte." und die Bäume zeigen den Build.
- Prüfung: Wenn der Code kaputt ist, dann meldet der Chat, was nicht stimmt (z. B. "Kein Amisia-Talentcode ..."), und nichts ändert sich.

### F-051 Berufe: Rezepte, Lager, Händlergunst
- Version: 2.9.1
- Status: gebaut
- Prüfung: Wenn du `/amisia berufe` eingibst, dann öffnet sich die Seite Berufe mit den Rezepten deines Berufs, deinem Rang und den Reagenzien jedes Rezepts.
- Prüfung: Wenn du das Berufsfenster einmal öffnest, dann zeigt der Filter "Bekannt" genau die Rezepte, die du kennst.
- Prüfung: Wenn du `/amisia berufe lager` eingibst, dann siehst du die Lagerobjekte (Camping) mit Beschreibung ("Beschreibung lädt ..." nur kurz).
- Prüfung: Wenn du `/amisia berufe gunst` eingibst, dann zeigt die Seite die Händlergunst und welche Items einen Handwerksauftrag haben.

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
