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

### F-185 Layer erkennen und in der Gilde wechseln
- Version: -
- Status: geplant
- Braucht: Gilde
- Prüfung: Wenn du in einer Zone zwei verschiedene NPCs ins Ziel nimmst und `/amisia layer` tippst, dann zeigt das Fenster "Layer" groß "Layer A" (oder einen anderen Buchstaben) und darunter "Layer A · hier · gerade eben"; mit "Layer-Chip zeigen" (Einstellungen, Gilde, Layer) steht zusätzlich ein kleiner Kasten "Layer A" auf dem Bildschirm.
- Prüfung: Wenn ein zweites Gildenmitglied mit Amisia in derselben Zone auf einem anderen Layer ist (es hat auch zwei NPCs im Ziel gehabt) und du allein "Gilde fragen" klickst, dann steht nach ein paar Sekunden "<Name> · Layer B" mit "Einladung erbitten"; ein Mitglied auf deinem Layer antwortet nicht.
- Prüfung: Wenn du "Einladung erbitten" klickst, dann fragt das Mitglied "<Name> möchte auf deinen Layer wechseln (Layer B). Einladen?"; nach "Einladen" nimmt dein Amisia die Einladung von selbst an (Chatzeile "Einladung von ... angenommen (Layer-Wechsel).").
- Prüfung: Wenn du danach in der Gruppe einen NPC ins Ziel nimmst, dann steht "Gewechselt: Layer B" im Chat und im Fenster; "Gruppe verlassen" verlässt die Gruppe, mit "Gruppe nach dem Wechsel verlassen" geht Amisia nach 30 Sekunden selbst (bitte melden, wenn der Layer gleich bleibt: dann steht nach einer Minute "Kein Wechsel").
- Prüfung: Wenn ein Gildenmitglied in deiner Zone 'inv layer' in den Gildenchat schreibt, dann fragt Amisia "<Name> bittet im Chat um einen Layer-Wechsel. Einladen?"; "Im Gildenchat fragen" im Fenster öffnet die Chatzeile mit "/g inv layer", und nach dem Abschicken nimmt Amisia eine Minute lang die Einladung eines Gildenmitglieds an.
- Notiz: Spec `docs/specs/2026-11-12-layer.md`; DECISIONS D-117. Ungeprüft: ob die Zonen-Kennung in den Kreatur-GUIDs auf dem Forever-Client die Layer trennt wie auf den anderen Classic-Clients, ob ein Addon dort einladen, annehmen und verlassen darf (`/amisia selbsttest gruppe`: "Layer: Wechsel in der Gilde", "Layer: Kreatur-GUID") und wie lange die Kennungen leben (Amisia vergisst sie nach 6 Stunden und bei `/reload`).
- Notiz: Läuft neben anderen Layer-Addons: eigenes Präfix und eigene Nachrichten (YQ, YA, YI) zwischen Amisia-Clients; die Chat-Bitten anderer Layer-Addons ("inv layer") versteht Amisia nur im Gildenchat und im Flüstern von Gildenmitgliedern, Zahlen darin zählen nicht.

### F-184 Leistung messen: wo Amisia Rechenzeit braucht
- Version: 2.79.0
- Status: gebaut
- Prüfung: Wenn du `/amisia leistung` tippst, ein paar Minuten spielst (Taschen, Karte, Tooltips, Hauptfenster) und es wieder tippst, dann steht im Chat der Bericht: Dauer, Frames, Amisias ms je Sekunde, Speicher, Laden, gebaute Daten und zehn Zeilen mit den teuersten Stellen.
- Prüfung: Wenn du danach `/amisia leistung bericht` tippst, dann kommt derselbe Bericht noch einmal; nach dem Ausloggen liest `python3 tools/build.py perf` ihn auf dem N100.
- Prüfung: Wenn du `/amisia leistung login` tippst und `/reload` machst, dann steht gleich "Der Login wird 60 s lang gemessen" im Chat und nach etwa einer Minute der Bericht des Logins.
- Prüfung: Wenn du `/amisia leistung 2` tippst, dann endet die Messung nach zwei Minuten von selbst mit dem Bericht.
- Prüfung: Wenn du `/amisia selbsttest` öffnest, dann sagt die Zeile "Zeitmessung", welche Uhr der Client hat ("debugprofilestop, mit debugstack").
- Notiz: DECISIONS D-116, Spec `docs/specs/2026-11-12-leistung-messen.md`. Optimiert nichts, misst nur.

### F-183 Der Versunkene Tempel als Dungeon
- Version: 2.78.0
- Status: gebaut
- Prüfung: Wenn du die Seite Dungeons öffnest, dann steht "The Temple of Atal'Hakkar" mit "~45" zwischen Maraudon und dem Gefängnis von Alcaz; im Teil Übersicht stehen acht Bosse mit Porträt in der Reihenfolge des Spiels, von Atal'alarion bis Jammal'an, jeder mit "keine Beute bekannt" (die Itemtabellen des Spiels haben seine Beute noch nicht).
- Prüfung: Wenn du dort den Teil Quests öffnest, dann stehen die Quests des Tempels da (als Horde zum Beispiel "Der versunkene Tempel", für beide Seiten die Quests von Jammal'an und Morphaz), jede mit Questgeber und Ort.
- Prüfung: Wenn du die Weltkarte der Sümpfe des Elends öffnest, dann zeigt sie den Eingang "The Temple of Atal'Hakkar (Eingang)"; "Wegpunkt" beim Tempel auf der Seite Dungeons setzt das Kartenziel dorthin.
- Prüfung: Wenn du den Versunkenen Tempel betrittst, dann zeigt die Dungeon-Leiste seine Bosse und Quests, und das Lauf-Fenster zeigt die acht Bosse als Porträts in Farbe; die Uhr startet mit dem ersten Kampf.
- Prüfung: Wenn du einen Boss tötest, dann wird sein Porträt blasser und bekommt ein rotes Kreuz, und die Zwischenzeit steht im Tooltip; mit Jammal'an (dem letzten Boss der Reihenfolge des Spiels) endet die Uhr als beendet. Sag Bescheid, wenn das zu früh ist.
- Notiz: DECISIONS D-115. Ohne Spec (README: neue Daten aus den bekannten Quellen). Bosse, Stufe, Instanz, Ladebild und Eingang aus den Tabellen des Spiels, die NPCs der Bosse und die Quests aus AllTheThings.

### F-182 Rezepte eines Gildenmitglieds per Klick auf seinen Beruf
- Version: 2.77.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du auf Gilde > Mitglieder bei einem Mitglied mit Amisia auf einen Beruf klickst (die Maus darauf zeigt grau "Klick: Rezepte ansehen"), dann öffnet sich Berufe mit "<Beruf> - Rezepte von <Name>", darunter "Skill: 165/225 · 65 Rezepte · Stand heute", und die Liste zeigt nur seine Rezepte ("N von M Rezepten").
- Prüfung: Wenn du dort etwas suchst oder im Filter "Bekannt: Unbekannt" wählst, dann bleiben nur seine Rezepte, die passen; ein Klick auf ein Rezept zeigt rechts Details, Reagenzien und die Gildenmitglieder wie sonst.
- Prüfung: Wenn du auf den Chip "Von: <Name>" klickst, "Alle Rezepte" wählst oder in der Leiste einen anderen Beruf, dann siehst du wieder alle Rezepte; "Zurück zu Mitglieder" oben rechts führt zur Mitgliederliste zurück.
- Prüfung: Wenn du auf einen Beruf klickst, den nur die Gildennotiz nennt ("laut Gildennotiz"), oder mit der rechten Maustaste auf einen Beruf, dann öffnet sich wie bisher das Menü mit Flüstern und Einladen.
- Prüfung: Wenn du auf einen Beruf deines eigenen Charakters oder Twinks klickst, dann zeigt Berufe die Rezepte dieses Charakters.
- Notiz: DECISIONS D-114. Keine neue Nachricht, kein neuer gespeicherter Schlüssel: die Ansicht liest, was der Rezept-Austausch schon speichert (`Crafters.KnownOf`). Ohne Spec (README: kleine Erweiterung ohne neue Daten oder Nachrichten).

### F-181 Fenster bei Gegenständen, die eine Quest starten
- Version: 2.76.0
- Status: gebaut
- Prüfung: Wenn du einen Gegenstand plünderst, der eine Quest startet, die du weder im Log noch abgeschlossen hast (z. B. eine Zeichnung oder einen Brief), dann öffnet sich nach einem Augenblick oberhalb der Bildmitte ein kleines Fenster mit seinem Namen, seinem Symbol mit gelbem "!" und "Klick auf das Symbol startet die Quest."
- Prüfung: Wenn du auf das Symbol klickst, dann öffnet sich das Questfenster des Spiels; nimmst du die Quest an, schließt Amisias Fenster (bitte melden, wenn der Klick nichts tut oder "Aktion blockiert" erscheint).
- Prüfung: Wenn du das Fenster mit dem x schließt und danach plünderst oder Taschen umräumst, dann kommt es für diesen Gegenstand nicht wieder; nach `/reload` erscheint es einmal wieder, solange die Quest offen ist.
- Prüfung: Wenn du so einen Gegenstand im Kampf bekommst, dann erscheint das Fenster erst nach dem Kampf; beginnt ein Kampf bei offenem Fenster, dann bleibt es stehen, das x schreibt "Schließt nach dem Kampf." und es kommt keine Fehlermeldung.
- Prüfung: Wenn du "Fenster bei Gegenständen, die eine Quest starten" (Einstellungen, Quests) ausschaltest, dann erscheint nichts mehr.
- Notiz: Spec `docs/specs/2026-11-11-quest-start-item.md`; DECISIONS D-113. Ob der Client für Startgegenstände den Quest-Vermerk liefert und Addons den Gegenstand per sicherem Knopf benutzen lässt, sagt `/amisia selbsttest gruppe` ("Quest-Startgegenstände"); lehnt er ab, informiert das Fenster nur ("Rechtsklick auf den Gegenstand in der Tasche ...").

### F-180 Lauf-Fenster: Zeit, Mob-XP, Gold, Bosse und Rare
- Version: 2.76.2
- Status: gebaut
- Prüfung: Wenn du in den Todesminen den ersten Kampf beginnst, dann öffnet sich "Lauf-Zeiten" mit "Zeit", "Mob-XP" und "Gold" nebeneinander, darunter acht runde Bossporträts in Farbe und unter "Rare" drei zurückgenommene Porträts; "Gold" zeigt Zahlen mit Münzsymbolen (z. B. 36 Silber, 76 Kupfer), und der Griff unten rechts zieht das Fenster kleiner oder größer (bleibt nach `/reload` so).
- Prüfung: Wenn du Mobs tötest und Geld plünderst, dann wachsen "Mob-XP" und "Gold"; gibst du eine Quest ab oder verkaufst und reparierst beim Händler, dann ändern sich beide nicht (bitte melden, wenn ein Wert springt oder nach einem Boss fehlt).
- Prüfung: Wenn du einen Boss tötest, dann wird sein Porträt blasser und rot durchgekreuzt, und die Maus darauf zeigt seinen Namen und "Zwischenzeit m:ss" (im zweiten Lauf grün oder rot "... zum besten Lauf").
- Prüfung: Wenn du einen Rare (z. B. Marisa du'Paige) tot im Ziel hast oder seine Leiche plünderst, dann wird sein Porträt unter "Rare" rot durchgekreuzt; nach `/reload` stehen Zeit, Mob-XP, Gold und die Kreuze noch da.
- Prüfung: Wenn du in Schwarzfelstiefen kämpfst, dann stehen die 21 Bosse in drei Reihen im Fenster, nichts ragt heraus; in der Halle der Thane gibt es keine Reihe "Rare".
- Notiz: Spec `docs/specs/2026-11-11-lauf-fenster.md`; DECISIONS D-112. Rare-Daten (AllTheThings) für 12 Dungeons; die neuen Forever-Dungeons und Raids haben keine. Seit 2.76.2 (D-112 Nachtrag, nach Bildern des Nutzers): lebende Bosse in Farbe, getötete durchgekreuzt; Münzsymbole selbst gesetzt; Größengriff. Vorher blieben die Kreise im Fenster schwarz (Schleier und Entsättigung der Modelle).

### F-179 Dungeonquest-Geber auf der Weltkarte
- Version: 2.76.0
- Status: gebaut
- Prüfung: Wenn du (Allianz, Stufe 20) die Weltkarte auf Sturmwind öffnest, dann steht bei Shoni ein kleines gelbes "!" mit Dungeon-Zeichen rechts oberhalb ihres Punktes; die Maus darauf zeigt eine Zeile "[D20] ..." mit den Todesminen und eine "[D30] ..." mit Gnomeregan.
- Prüfung: Wenn du auf diesen Pin klickst, dann öffnet Amisia unter der Weltkarte die Todesminen im Teil Quests mit dem Questweg der Quest; Shift-Klick setzt stattdessen das Ziel auf den Geber.
- Prüfung: Wenn du eine der Quests annimmst oder eine Stufe aufsteigst, dann ändern sich Zeilen und Pins nach einer halben Sekunde; eine Quest bis zwei Stufen über dir steht mit "ab N" da, ihr "!" grau, solange keine andere Quest des Gebers schon geht.
- Prüfung: Wenn du die Karte auf den Kontinent stellst, dann stehen dort keine dieser Pins; die Zonenkarte zeigt sie wieder.
- Prüfung: Wenn du "Dungeonquest-Geber auf der Karte" (Einstellungen, Karte und Wegpunkt) oder im Rechtsklick-Menü "Dungeonquest-Geber ausblenden" wählst, dann sind diese Pins weg und die übrigen bleiben.
- Notiz: Spec `docs/specs/2026-11-11-dungeonquest-geber-karte.md`; DECISIONS D-111. Ob der Client das Questlog-Abzeichen `questlog-questtypeicon-dungeon` hat, sagt `/amisia selbsttest` (sonst das Dungeon-Zeichen der Karte). Graue Quests, Starts im Dungeon oder durch einen Gegenstand und Geber ohne bekannten Ort bekommen keinen Pin.

### F-178 Gruppen-Queststatus im Dungeon
- Version: 2.76.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du mit einem zweiten Amisia in einer Gruppe die Todesminen (oder einen anderen Dungeon) betrittst und auf der Seite Dungeons den Teil Quests öffnest, dann steht rechts in jeder Zeile sein Anfangsbuchstabe in Klassenfarbe mit dem Questzeichen seines Stands; die Maus auf der Zeile nennt unter "Gruppe:", wer sie im Log hat, abgeben kann, erledigt hat oder braucht.
- Prüfung: Wenn ein Mitglied kein Amisia hat (oder "Meinen Dungeon-Queststand mit der Gruppe teilen" aus hat), dann steht es grau mit "?" da und im Tooltip unter "Unbekannt (kein Amisia oder Teilen aus)", nie unter "Fehlt".
- Prüfung: Wenn du eine Quest im Log hast, die dem anderen fehlt, dann zeigt die Dungeon-Leiste bei Quests "· 1 teilen", ihre Liste "fehlt 1", der Tooltip "Kannst du teilen: <Name>", und ein Klick auf "Teilen" in der Zeile (außerhalb des Kampfes) teilt sie.
- Prüfung: Wenn der andere die Quest annimmt oder fertig macht, dann ändert sich sein Zeichen nach wenigen Sekunden (graues "?" im Log, gelbes "?" fertig).
- Prüfung: Wenn ihr draußen steht und du den Teil Quests eines Dungeons öffnest, dann kommen die Zeichen der anderen auch ohne Betreten.
- Notiz: Spec docs/specs/2026-11-11-gruppen-queststatus.md; DECISIONS D-110. Nur in einer eigenen Gruppe (PARTY), nicht im Raid. Ob der Client Quests teilen kann ("Teilen" erscheint nur dann), sagt `/amisia selbsttest gruppe` ("Gruppen-Queststand, Quest teilen").

### F-177 Dungeonquests aus dem eigenen Quest-Scan
- Version: 2.76.0
- Status: gebaut
- Prüfung: Wenn du (Allianz) auf der Seite Dungeons "Gefängnis von Alcaz" öffnest, Teil Quests, dann stehen dort Quests wie "Das geheime Gefängnis" und "Das Tagebuch des Drachen", ohne Ort in der Zeile; die Maus darauf zeigt "Nur aus dem Quest-Scan: Questgeber und Ort noch unbekannt" und keine leere Zeile "Start:".
- Prüfung: Wenn du "Schwarzschlundfeste" öffnest, dann steht "Die Wurzel des Problems" genau einmal da (Allianz: die Quest für Darnassus, Horde: die für Thunder Bluff), und "Terrasse des Formers" zeigt fünf Quests, "Feste Krol'dok" als Allianz sechs, als Horde fünf (vorher zwei für die Allianz).
- Prüfung: Wenn du eine dieser Quests anklickst, dann sagt der Questweg "Annehmen: Ort unbekannt; Amisia lernt ihn, sobald du die Quest siehst" und "Abgeben: noch unbekannt", ohne Knopf "Karte", und trägt unten die Marke "nur aus dem Quest-Scan".
- Prüfung: Wenn du einen der drei neuen Dungeons betrittst, dann zeigt die Dungeon-Leiste bei "Quests" diese Quests; ein Klick auf eine öffnet ihren Questweg.
- Prüfung: Wenn du eine solche Quest beim Questgeber siehst und danach `build.py data` läuft, dann nennt der Questweg den Geber und seinen Ort.
- Notiz: DECISIONS D-109, Spec `docs/specs/2026-11-11-dungeonquests-aus-scan.md`. Die Liste der nicht gesetzten Quests mit Grund schreibt der Datenbau nach `~/addons/_cache/dungeonquest_scan_report.txt`. Ein englischer Client zeigt "Quest <Nummer>", bis er die Quest geladen hat.

### F-176 Twitch und Discord in der Fußzeile
- Version: 2.75.0
- Status: gebaut
- Prüfung: Wenn du das Amisia-Fenster öffnest, dann stehen unten rechts neben "Offiziersansicht · Version ..." zwei kleine Symbole, Twitch und Discord; die Maus darauf nennt den Namen und "Klick: zeigt den Link zum Kopieren.".
- Prüfung: Wenn du auf das Discord-Symbol klickst, dann öffnet sich ein kleines Fenster "Discord" mit dem Link https://discord.gg/mxhvFBSXSf, schon markiert; Strg+C kopiert ihn, Tippen ändert ihn nicht, Escape schließt das Fenster. Das Twitch-Symbol zeigt https://www.twitch.tv/mrvulo.
- Notiz: DECISIONS D-108. Neue Texturen: nach dem Release WoW ganz neu starten.

### F-175 Ausrüstungsplaner: Items ohne bekannte Quelle zuschaltbar
- Version: 2.75.0
- Status: gebaut
- Prüfung: Wenn du mit einem Priester der Stufe 42 im Ausrüstungsplaner auf den Platz Waffenhand klickst (Meine Stufe), dann steht am Ende der Vorschläge grau "+ N weitere ohne bekannte Quelle"; ein Klick darauf zeigt sie in der Liste nach Zuwachs einsortiert, darunter "Schattenlichtathame" mit "Stufe 40 · Quelle unbekannt", ihrem Zuwachs in Prozent und einem grauen "?" statt des Quellsymbols; die Zeile am Ende heißt dann "ohne bekannte Quelle ausblenden".
- Prüfung: Wenn du die Maus auf "Schattenlichtathame" hältst, dann steht im Tooltip "Amisia kennt die Werte aus dem Item-Scan, aber nicht, woher es kommt. Tötet jemand mit Amisia den Boss oder gibt eine Quest es als Belohnung, lernt Amisia die Quelle."; ein Klick auf das "?" öffnet nichts.
- Prüfung: Wenn du "Optionen" anklickst, dann steht dort "Items ohne bekannte Quelle" mit Haken, solange sie gezeigt werden; ein Klick schaltet um, und nach `/reload` ist die Wahl noch da (auch unter Einstellungen > Ausrüstung und Wünsche > "Items ohne bekannte Quelle vorschlagen", aus von Haus aus).
- Prüfung: Wenn du bei "Schattenlichtathame" auf den grauen Stern klickst, dann wird er gold und das Item steht unter "Wunschliste" mit "Waffenhand · Stufe 40 · Quelle unbekannt"; ein zweiter Klick nimmt es wieder weg.
- Prüfung: Wenn du einen Spielstil wie "Solo machbar" einschaltest, dann verschwindet die Zeile "+ N weitere ..." (eine unbekannte Quelle besteht keinen Schalter außer "Jetzt holbar").
- Notiz: DECISIONS D-107, erweitert D-59 (F-132). Keine Spec (kein neuer gespeicherter Schlüssel, kein neuer Abschnitt: die Einstellung `bis.noSource` steht im Abschnitt "bis"). Die Daten: `Data/GearNoSource.lua` (lazy `GEAR_NOSRC`, 1670 Items, 189 KB Text) aus dem Item-Scan, nur die Ausrüstung, die keine Quelle nennt; Test- und Platzhalter-Items (215), Qualität unter Ungewöhnlich, Items ohne gewerteten Wert und alte Raid-Ausrüstung fallen weg. Bekommt ein Item später eine Quelle (ein Kill, eine Questbelohnung des Quest-Scans, AllTheThings), steht es nach dem nächsten Datenbau normal in den Vorschlägen. Nur die Vorschläge zeigen sie; Ziele, Sets und die Suche nach Namen nicht (ein Item-Link oder eine ID in der Suche geht wie bisher).

### F-174 Scharlachrotes Kloster als vier Dungeons
- Version: 2.75.0
- Status: gebaut
- Prüfung: Wenn du die Seite Dungeons öffnest, dann stehen dort statt eines Klosters vier Karten "Scharlachrotes Kloster: Friedhof" (Stufe 30-38), "...: Bibliothek" (33-41), "...: Waffenkammer" (36-44) und "...: Kathedrale" (38-46); Waffenkammer und Kathedrale tragen in der Spalte Schlüssel das Symbol von "The Scarlet Key" (grau, solange du ihn nicht hast), Friedhof und Bibliothek keins.
- Prüfung: Wenn du einen Flügel öffnest (Teil Übersicht), dann stehen links nur seine Bosse in der Reihenfolge des Spiels, jeder mit Porträt: Friedhof Interrogator Vishas und Bloodmage Thalnos (dazu die Seltenen Ironspine, Azshir the Sleepless, Fallen Champion und Scorn mit Beute), Bibliothek Houndmaster Loksey und Arcanist Doan, Waffenkammer Herod, Kathedrale High Inquisitor Fairbanks, High Inquisitor Whitemane und Scarlet Commander Mograine.
- Prüfung: Wenn du in der Waffenkammer auf Herod klickst, dann stehen rechts seine drei Items (eine Zweihandaxt, Schultern und ein Helm, Stufe 37), und im Friedhof, in der Bibliothek und der Kathedrale kommt Herod nicht vor.
- Prüfung: Wenn du (Allianz) in der Bibliothek den Teil Quests öffnest, dann steht dort "Mythology of the Titans", im Friedhof nicht; "In the Name of the Light" steht in Bibliothek, Waffenkammer und Kathedrale (ihre Bosse stehen in diesen drei Flügeln).
- Prüfung: Wenn du im Spiel einen Flügel betrittst, dann heißt die Dungeon-Leiste zuerst "Scharlachrotes Kloster" mit "Bosse 7" (die Liste zeigt alle vier Flügel), und nach dem ersten Boss heißt sie wie der Flügel (z. B. "Scharlachrotes Kloster: Bibliothek") mit "Bosse 1/2"; die Lauf-Zeiten stehen danach unter diesem Flügel.
- Notiz: DECISIONS D-106. Keine Spec (kein neuer gespeicherter Schlüssel; die alten Daten unter "sm" verschiebt Schritt 6 von `Core/Migrate.lua`). Die Stufen der Flügel sind die des Bildschirmfotos des Nutzers (keine Tabelle kennt sie); der Name des Klosters kommt aus dem Client (Gebiet 796), die Flügel aus der Übersetzung. Der Client sagt nicht, durch welche Tür man kam (eine Karte 189, ein Gebiet): bis zum ersten Kill rät Amisia den ersten Flügel ohne Kill. Ein gemeinsamer Eingangs-Pin für alle vier (AllTheThings kennt nur einen Eingang).
- Notiz: Dieselbe Regel gilt jetzt für die beiden Hälften von Blackrock Spire: jede hat nur noch ihre eigenen Bosse in der Reihenfolge (die Karte zeigt "n/9" bzw. "n/5" statt "n/14"), Lower endet mit Overlord Wyrmthalak, und Beute der oberen Bosse, die bisher auch unter Lower stand, steht nur noch unter Upper; "General Drakkisath's Demise" steht jetzt unter Upper.

### F-173 Questgegenstände aufräumen: sicher, wahrscheinlich, unklar
- Version: 2.74.0
- Status: gebaut
- Prüfung: Wenn du `/amisia questitems` eingibst (oder auf der Seite Quests oben rechts "Aufräumen" klickst), dann öffnet sich "Questgegenstände aufräumen" mit deinen Questgegenständen unter "Sicher überflüssig", "Wahrscheinlich überflüssig" und "Unklar", jeder mit Symbol, Anzahl und Grund ("startet die Quest ... (abgeschlossen)", "laut Daten für ...", "Quest ... nicht im Log"); keine Rüstung, kein Schlüssel, nichts aus der Bank.
- Prüfung: Wenn du die Maus auf einen Questgegenstand hältst (Tasche oder Liste), dann steht im Tooltip "Quest: Name (abgeschlossen)" bzw. "(im Log)" oder "(nicht im Log)", bei einem überflüssigen grün "wird nicht mehr gebraucht" oder gelb "wahrscheinlich nicht mehr gebraucht"; Einstellungen > Quests > "Questgegenstände im Tooltip" aus nimmt die Zeile weg.
- Prüfung: Wenn du bei einem sicheren Gegenstand auf "Löschen" klickst, dann fragt ein Fenster mit Name, Anzahl, Grund und "Gelöschte Questgegenstände lassen sich nicht zurückholen."; "Abbrechen" löscht nichts, "Löschen" einen Stapel, danach steht im Chat "Gelöscht: Name xN." (oder, wenn das Spiel es Addons verbietet, einmal "Das Spiel lässt Addons keine Gegenstände löschen: ..." und die Knöpfe verschwinden: bitte melden, welches von beiden kam).
- Prüfung: Wenn du von einem Questgegenstand mehr gesammelt hast als nötig und die Quest abgibst, dann steht der Rest nach etwa einer Sekunde unter "Sicher überflüssig" mit "war Ziel der Quest ... (abgeschlossen), von Amisia gesehen".
- Prüfung: Wenn du auf eine Zeile rechtsklickst und "Behalten" wählst, dann steht sie unter "Behalten" und "Nächsten sicheren löschen (N)" zählt sie nicht mehr; "Nicht mehr behalten" holt sie zurück.
- Notiz: Spec docs/specs/2026-11-10-questgegenstaende.md; DECISIONS D-105. Gelöscht wird nur aus "sicher", nur im Klick, ein Stapel je Klick, nie im Kampf, nie bei offener Bank, Post oder Handel. Ob Forever Addons `DeleteCursorItem` erlaubt, ist offen: `/amisia selbsttest` nennt unter "Wahlweise vorhanden" `DeleteCursorItem`, `GetCursorInfo` und `C_Container.GetContainerItemQuestInfo`. Nichts wird gesendet.

### F-172 Daten per Nummer: Datenprüfung, Quest-Scan, NPC-Scan
- Version: 2.75.1
- Status: gebaut
- Prüfung: Wenn du `/amisia selbsttest daten` eingibst (nicht im Kampf), dann steht nach etwa 5 Sekunden im Selbsttest-Fenster ein Bericht mit "NPC-Namen per Nummer", "Quests per Nummer", "Modell per Nummer", "Weitere Quellen" und am Ende "Urteil" (z. B. "NPC per Nummer: geht (sofort)" oder "geht nicht"); bitte den ganzen Bericht (Strg+A, Strg+C) an uns schicken.
- Prüfung: Wenn du `/amisia scan quests` eingibst (oder in den Werkzeugen, Expertenmodus, auf "Quest-Scan" klickst), dann steht im Chat "Quest-Scan gestartet: 6626 von 6626 Quests offen, 20 pro Sekunde, etwa 6 min" und auf der Seite Werkzeuge "Quest-Scan läuft: ..." mit der Restzeit; `/amisia scan stop` hält an, ein zweiter Aufruf macht weiter; zum Schluss "Quest-Scan fertig: N Quests gespeichert.", dann `/reload`.
- Prüfung: Wenn du `/amisia scan npcs` eingibst, dann läuft Phase A (2133 NPCs, etwa 8 Minuten) mit "NPC-Scan Phase A gestartet ..." im Chat, oder, wenn der Client keine Namen nennt, steht nur "Der Client nennt keine NPC-Namen per Nummer: NPC-Scan beendet." da; nach Phase A fragt ein zweiter `/amisia scan npcs` mit einem Fenster ("Phase B fragt 34814 Nummern in 11 Bereichen ab ... bis zu ...") und startet erst mit "Starten"; in Phase B kommt die Zeile "NPC-Scan Phase B läuft: ..." nur etwa alle 13 Minuten (alle 2000 abgefragten Nummern), nicht bei jeder Nummer (ab 2.75.1).
- Prüfung: Wenn nach den Scans ein `/reload` gemacht ist, der N100 die Daten gebaut hat (`python3 tools/build.py data`) und die neue Version veröffentlicht ist, dann zeigen die Seiten Dungeons und Quests bei Quests, die der Client noch nicht geladen hat, den deutschen Titel und die Stufe, und beim nächsten Login meldet "Scan aufgeräumt ..." auch "Dazu N Quests und M NPC-Namen der Scans per Nummer.".
- Notiz: Spec `docs/specs/2026-11-10-quest-und-npc-scan.md`, DECISIONS D-104. Die SavedVariables kommen von selbst über Syncthing zum N100; besser werden die Daten erst nach dem nächsten Datenbau und Release. Ob NPC-Namen per Nummer auf Forever gehen, hat öffentlich niemand bestätigt: die Datenprüfung zeigt es, und der NPC-Scan schaltet sich still ab, wenn der Client nicht antwortet.
- Prüfung: Wenn du (nach dem nächsten Release) `/amisia selbsttest daten` eingibst, dann steht im Bericht ein Abschnitt "Questbelohnungen per Nummer" mit jeder Belohnungsfunktion und wo es sie gibt ("global", "C_QuestLog"), je Quest den Werten ("Belohnungen 1; Auswahl ... Geld ...; EP ..."), jeder Zeile des Quest-Tooltips und den Zeilendaten, und im Urteil "Questbelohnungen per Nummer: geht (Funktion ...)" oder "geht nicht" und "Quest-EP per Nummer: ..."; bitte den ganzen Bericht schicken.
- Notiz: Nicht veröffentlicht (nach 2.74.0): die Datenprüfung fragt auch die Belohnungen einer Quest per Nummer (Urteile `questReward`, `questXP`); mit "geht" speichert der Quest-Scan Belohnungen, Auswahl, Geld und EP (Layout 2: ein Scan von 2.74.0 läuft einmal neu), und der Datenbau macht die Questbelohnungen zur Quelle der Items, die noch keine Questquelle haben. Nachtrag der Spec vom 2026-11-10, D-104, D-107. Heute: 5496 der 6626 Quests von QuestV2 haben in unseren Quellen keine Belohnung (Belohnungsitems nennt AllTheThings für 1126 von ihnen, der Sammler für 97; viele Quests geben aber gar kein Item); 1462 der 6591 Items der Ausrüstungsdaten haben eine Questquelle.
- Notiz: Heute fehlt die Stufe bei 482 von 527 Dungeonquests und 745 von 748 Questquellen der Ausrüstung; 2133 NPCs unserer Daten haben nur englische Namen. Boss-Nummern aus dem Scan (Overseer Wrex, King Op, Lady Illucia Barov) braucht bei einem deutschen Client einmal `python3 tools/build.py tables --tables DungeonEncounter --locale deDE` auf dem N100; die drei Rares der Drowned City (Gill, Umbra, Zin'aka) haben keine Begegnung und keinen deutschen Namen in einer Tabelle: dafür braucht es einen englischen Client oder eine Sichtung.

### F-171 Flugpunkte aus den Daten des Spiels
- Version: 2.74.0
- Status: gebaut
- Prüfung: Wenn du unter Einstellungen > Karte und Wegpunkt "Flugmeister auf der Karte" einschaltest und als Horde die Weltkarte von Riverglades öffnest, dann steht dort ein Flugpunkt-Symbol bei Rog'mar (etwa 59.6, 45.1) mit dem Tooltip "Rog'mar, Riverglades" und "Flugmeister · Horde" (vorher fehlte er); als Allianz steht dort stattdessen nur Farholde Keep (Gretchen Mayberry).
- Prüfung: Wenn du die Karte der Östlichen Pestländer öffnest, dann steht der Flugpunkt von Light's Hope Chapel deiner Fraktion (Allianz Khaelyn Steelwing etwa 71.7, 49.6; Horde Georgia etwa 70.5, 47.6) im Tooltip mit dem Namen des Flugmeisters und darunter "Light's Hope Chapel, Eastern Plaguelands"; bitte melden, ob das Symbol beim echten Flugmeister steht (vorher stand es bei 81.6, 59.2 und 80.2, 57.0, wo der Flugmeister in Classic steht).
- Prüfung: Wenn du die Karte von Mount Hyjal öffnest, dann stehen dort für beide Fraktionen die Flugpunkte Summit of Eternity und Tainted Foothills; die Karte von Moonglade zeigt nur noch die normalen Flugmeister (Sindrayl für die Allianz, Faustron für die Horde), nicht mehr die der Druiden.
- Prüfung: Wenn du die Maus auf die Flugpunkte von Freewind Post, Thalanaar, Feathermoon oder Camp Mojache hältst, dann steht oben der Ortsname ("Freewind Post, Thousand Needles") statt eines Flugmeisters; die Zeppeline und Schiffe (Einstellung "Zeppeline und Schiffe auf der Karte") sind unverändert.
- Notiz: DECISIONS D-102. Keine Spec (neue Daten aus einer Client-Tabelle, die Form von `F` bleibt, ein sechstes Feld kommt dazu). Für 1.60.1.70888: 65 Flugpunkte statt 64, von den 101 Zeilen der Tabelle 36 weggelassen (Questflüge, Transporte, Testorte, die zzOLD-Kopien, Alterac Valley, die Druiden-Flüge von Nighthaven, die Türme der Pestländer; Powderfuse Port und Tidegear Coast zeigt der Client keiner Seite: bitte melden, wenn es dort einen Flugmeister gibt). Die sechs Flugmeister von Hand fallen weg, die Tabelle hat sie alle.
- Notiz: DECISIONS D-103, nur auf dem N100 (nichts davon im Spiel): `tools/auto_data.py` schaut zusätzlich höchstens einmal am Tag bei wago.tools nach einem neuen `wowf`-Build, lädt dessen Tabellen und baut ihn wie einen Export des PCs auf `auto/data-<build>`; aus mit `~/addons/_auto/amisia-wago.off`. Wenn ein neuer Build gebaut wurde, dann stehen am Ende von `~/addons/_auto/amisia-data.txt` die ersten Zeilen von "Neu in diesem Build" (Items, Quests, Dungeons, Bosse, Flugpunkte, Zauber) und der ganze Bericht in `~/addons/_auto/amisia-data-diff.txt`; wenn der Blick nichts Neues fand oder scheiterte, dann steht dort eine Zeile "wago.tools (täglich, ...)". Von Hand: `python3 tools/build.py diff [ALT NEU]`.

### F-170 Boss-Porträts für alle Dungeons, Drowned City
- Version: 2.74.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Dungeons das Scharlachrote Kloster (Scarlet Monastery) öffnest (Teil Übersicht), dann stehen links alle sieben Bosse in der Reihenfolge des Spiels (Interrogator Vishas bis High Inquisitor Whitemane), jeder mit dem runden Porträt seines Modells statt des Totenkopfs; ein Boss ohne Beute für dich steht grau mit "N Items · nichts für dich" oder "keine Beute bekannt" da.
- Prüfung: Wenn du Lower und Upper Blackrock Spire öffnest, dann hat jede nur ihre eigenen Bosse (unten Highlord Omokk bis Overlord Wyrmthalak, oben Pyroguard Emberseer bis Lord Valthalak), alle mit Porträt.
- Prüfung: Wenn du die Drowned City öffnest, dann steht dort Stufe 35-40, oben ihr eigener Ladebildschirm statt des allgemeinen Bildes, und links stehen Zul'Alai, Var'Taka, Captain Dreadrise, Deathless Guardians, Primeval Elemental und Min'loth the Serpent (die Reihenfolge des Spiels) mit Porträt; Teil Quests zeigt ihre Quests (auch "The Saltseer Captain" und "The Web of Magic"); in der Drowned City zeigt sich die Dungeon-Leiste mit "Bosse 0/6".
- Prüfung: Wenn du Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold oder Shaper's Terrace öffnest, dann zeigt jeder oben seinen eigenen Ladebildschirm und links seine Bosse in der Reihenfolge des Spiels mit Porträt; in Alcaz Prison steht Overseer Wrex als erster Boss neu dabei, in Shaper's Terrace King Op nach Cinder, beide noch mit dem Totenkopf (keine Quelle nennt ihr NPC; bitte melden, ob die Reihenfolge stimmt).
- Prüfung: Wenn ein Boss trotz Namen noch den Totenkopf zeigt, dann kennt das Spiel sein Modell vielleicht noch nicht (es zeigt nur Kreaturen, die der Client schon gesehen hat): bitte melden, welcher Boss in welchem Dungeon, auch nach einem Lauf dort.
- Notiz: DECISIONS D-100. Keine Spec (neue Daten aus den bekannten Quellen). Vorher hatten 164 von 214 Bossen der Reihenfolgen ein NPC, jetzt 231 von 232; ohne bleibt Lady Illucia Barov (Scholomance: keine Quelle nennt ihr NPC). Die Seltenen der Drowned City aus dem Bildschirmfoto (Gill, Umbra, Zin'aka) fehlen, weil keine erlaubte Quelle sie kennt. Barrow Deeps und Hyjal Summit haben noch keine Bosse in den Quellen.
- Notiz: DECISIONS D-101 (2026-11-10, "nimm alle Quellen die du bekommen kannst"): die Client-Tabellen jetzt auch als CSV-Export von wago.tools (Build 1.60.1.70888, `build.py tables`), je Tabelle die neueste und vollste Kopie (`tools/client_tables.py`). Damit haben die fünf neuen Forever-Dungeons die Reihenfolge und Begegnungen des Spiels (die Handreihenfolge der Drowned City und die Reihenfolge aus AllTheThings sind weg), ihre Stufe aus dem Client und ihren Ladebildschirm; 231 von 234 Bossen haben ein NPC (neu ohne: Overseer Wrex, King Op). Items und Werte unverändert. Etagenkarten der Dungeons hat auch der neue Build nicht.

### F-169 Spieler-Tooltip: Gearscore, Itemstufe und Berufe
- Version: 2.74.0
- Status: gebaut
- Prüfung: Wenn du die Maus auf deinen eigenen Charakter hältst (oder ihn als Ziel nimmst und die Maus auf das Zielfenster hältst), dann steht im Tooltip unter den Zeilen des Spiels grau "Gearscore N · Itemstufe N", die Gearscore-Zahl in der Farbe deiner Ausrüstung (grün, blau, lila), die Itemstufe weiß und gleich der Zahl im Charakterfenster (bitte melden, wenn sie abweicht oder eine Fehlermeldung kommt).
- Prüfung: Wenn du einen Beruf im Berufsfenster einmal geöffnet hast und dich wieder mit der Maus ansiehst, dann steht über der Gearscore-Zeile eine Reihe kleiner Berufssymbole, die Hauptberufe vor Kochen, Erste Hilfe und Angeln; bei einem Gildenmitglied mit Berufen in der Gildennotiz (oder im Rezeptaustausch) ebenso.
- Prüfung: Wenn du die Maus auf einen anderen Spieler in deiner Nähe hältst (braucht: einen anderen Spieler in der Nähe), dann erscheint die Gearscore-Zeile nach einem kurzen Moment von selbst, ohne dass sich das Betrachten-Fenster öffnet; ein zweites Mal sofort; ist das Betrachten-Fenster offen oder bist du im Kampf, bleibt sie weg.
- Prüfung: Wenn du unter Einstellungen > Allgemein > Oberfläche "Dafür Spieler unter der Maus ansehen" ausschaltest, dann kommt die Zeile nur noch bei dir und bei Spielern, die Amisia in den letzten zehn Minuten schon angesehen hat; "Gearscore und Itemstufe im Spieler-Tooltip" aus nimmt die Zeile ganz weg, "Berufe im Spieler-Tooltip" aus die Symbole.
- Notiz: DECISIONS D-99. Keine Spec (keine neue Nachricht, kein gespeicherter Schlüssel, keine Seite, kein neuer Abschnitt). Gearscore ist Amisias eigene Rechnung (Summe aus Itemstufe mal Gewicht des Platzes), nicht die Zahl eines anderen Addons. Gearscore-Zeile auch auf TBC und Era, die Berufe nur auf Forever. Ob Forever `GetInventoryItemID`, `CheckInteractDistance` und `C_Item.GetDetailedItemLevelInfo` hat, sagt `/amisia selbsttest`.

### F-168 Dungeon-Leiste: Bosse, Quests, Zeit und Route
- Version: 2.74.0
- Status: gebaut
- Prüfung: Wenn du allein einen Dungeon betrittst, dann steht oben in der Mitte eine kleine Leiste mit seinem Namen, "Bosse 0/n" und (wenn du dort Quests hast oder bekommen kannst) "Quests n"; läufst du hinaus, ist sie weg (bitte melden, wenn sie etwas verdeckt oder eine Fehlermeldung kommt).
- Prüfung: Wenn du den ersten Boss tötest, dann steht "Bosse 1/n"; ein Klick auf "Bosse" zeigt darunter die Liste mit Haken beim ersten und dem nächsten gold "als Nächstes"; ein Klick auf einen Boss öffnet die Seite Dungeons auf ihm; ein zweiter Klick auf "Bosse" oder Escape schließt die Liste, die Leiste bleibt.
- Prüfung: Wenn du eine Quest dieses Dungeons im Log hast und sie fertig ist, dann steht grün "(1 fertig)" hinter "Quests n", in der Liste steht sie oben mit dem gelben "?", und ein Klick öffnet ihren Weg im Quest-Journal der Seite Dungeons.
- Prüfung: Wenn im Dungeon der erste Kampf beginnt, dann steht "Zeit 0:00" in der Leiste und läuft; ein Klick darauf verbirgt das Fenster "Lauf-Zeiten", ein zweiter zeigt es wieder.
- Prüfung: Wenn du die Leiste am Namen verschiebst, `/reload` machst und wieder einen Dungeon betrittst, dann steht sie am neuen Platz; das rote x verbirgt sie, `/amisia leiste` zeigt sie wieder, "Fensterposition zurücksetzen" stellt sie oben in die Mitte.
- Notiz: Spec docs/specs/2026-11-10-dungeon-leiste.md; DECISIONS D-98. "Route 2/5" erscheint, solange du einer eigenen Route folgst (F-167, Rechtsklick: nächster Stopp); in Raids nur mit "Auch in Raids" (Einstellungen, Dungeon-Leiste). Nichts wird gesendet.

### F-167 Eigene Routen auf der Karte: Stopps, Zeichnen, Teilen
- Version: 2.74.0
- Status: gebaut
- Prüfung: Wenn du die Weltkarte öffnest, dann steht unten links eine kleine Leiste "Route"; nach einem Klick darauf, "Stopp" und drei Klicks auf die Karte stehen die Stopps 1, 2, 3, mit einer goldenen Linie verbunden; ist "Route" wieder aus, lässt sich die Karte ziehen und klicken wie immer (bitte melden, wenn die Leiste falsch sitzt, Stopps an der falschen Stelle landen oder eine Fehlermeldung "blockiert"/"tainted" kommt).
- Prüfung: Wenn du "Zeichnen" wählst und mit gedrückter linker Maustaste ziehst, dann folgt eine blaue Linie der Maus; "Rückgängig" nimmt erst die Linie, dann den letzten Stopp; ein Klick auf einen Stopp bietet "Beschriften", "Früher", "Später", "Löschen", "Punkt teilen" (steht statt Linien nur eine Punktreihe, bitte melden).
- Prüfung: Wenn du einen Namen ins Feld tippst, "Speichern" klickst, `/reload` machst und auf der Karte "Route", dann "Laden" öffnest, dann steht die Route unter der Zone und lädt mit einem Klick; "Mehr" > "Gespeicherte Route löschen" fragt erst.
- Prüfung: Wenn du "Mehr" > "Route folgen" klickst, dann ist "Stopp 1/3" dein Ziel (Wegpunkt oder Pfeil); läufst du hin, wird Stopp 2 das Ziel, nach dem letzten steht "Route ... zu Ende: alle 3 Stopps erreicht."; in einem Dungeon geht es mit `/amisia route weiter`.
- Prüfung: Wenn du in einer Gruppe (Braucht: Gruppe) mit einem zweiten Amisia "Teilen" klickst, dann steht bei ihm "<Dein Name> teilt die Route ..." und erst nach `/amisia route annehmen` steht sie auf seiner Karte; "Punkt teilen" an einem Stopp schreibt "Amisia-Punkt: <Zone> 45.2, 63.1 (...)" in den Gruppenchat und er kann ihn mit `/amisia route punkt` als Ziel nehmen.
- Notiz: Spec docs/specs/2026-11-10-eigene-routen.md; DECISIONS D-97. Die ersten vier Prüfungen gehen allein; die fünfte (Teilen) braucht eine Gruppe mit einem zweiten Amisia (Braucht: Gruppe), darum steht keine Zeile "Braucht", die die anderen in der Testliste verstecken würde. Neu: der Kanal PARTY für diese Nachrichten (ändert D-19). Ob Forever Linien (CreateLine) und den Kartenlink hat, sagt `/amisia selbsttest gruppe` ("Routen: Kartenlink, Position").

### F-166 Lauf-Zeiten: Zwischenzeit je Boss, Bestzeit, Verlauf
- Version: 2.74.0
- Status: gebaut
- Prüfung: Wenn du allein einen Dungeon betrittst und eine Minute am Eingang wartest, dann ist kein Fenster offen; beim ersten Kampf geht das Fenster "Lauf-Zeiten" mit dem Namen des Dungeons auf und die Zeit läuft (bitte melden, wenn es sich im Kampf nicht öffnet oder eine Fehlermeldung kommt).
- Prüfung: Wenn du den ersten Boss tötest, dann wird sein Porträt farbig und die Maus darauf zeigt "Zwischenzeit m:ss" (seit F-180); tötest du den letzten Boss, dann steht im Chat "<Dungeon> in m:ss (erste gemessene Zeit)." und im Fenster grün "Erste gemessene Zeit"; beim Rauslaufen schließt es sich.
- Prüfung: Wenn du den Dungeon zurücksetzt und noch einmal läufst, dann zeigt die Maus auf dem nächsten Boss grau "Ziel: m:ss (bester Lauf)", nach jedem Kill sein Tooltip grün "-m:ss" oder rot "+m:ss zum besten Lauf", am Ende "Neue Bestzeit!" oder rot "+m:ss zur Bestzeit" und im Chat "(Bestzeit m:ss, ...)".
- Prüfung: Wenn du während eines Laufs `/amisia zeiten stop` tippst, dann steht "Uhr angehalten: der Lauf zählt als nicht beendet.", das Fenster geht zu, und unter Dungeons, Reiter "Zeiten" steht der Lauf als "nicht beendet · n/m Bosse"; "Bester Lauf" bleibt.
- Prüfung: Wenn du das Fenster verschiebst und `/reload` machst, dann steht es nach dem nächsten Kampfbeginn bzw. `/amisia zeiten` am selben Platz; draußen öffnet `/amisia zeiten` den Reiter "Zeiten" der zuletzt gemessenen Instanz, "Zeiten löschen" fragt erst.
- Notiz: Spec docs/specs/2026-11-10-lauf-zeiten.md; DECISIONS D-96. In Raids dasselbe (Einstellung "Zeitfenster auch in Raids"); eine Gruppe ändert nur die Spalte "Gruppe". Nichts wird gesendet.

### F-165 Raid-Rollen: Haupttanks, Assistenten, Plündermeister
- Version: 2.74.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier unter Aufstellung oben "Rollen" klickst, bei "Assistenten" zwei Namen aus dem Raid mit Komma einträgst, Enter drückst und als Raidleiter "Rollen jetzt setzen" klickst, dann sind beide Assistent, und im Chat steht "Rollen: Assistenten: 2 befördert." (bzw. "... schon Assistent", "... nicht im Raid").
- Prüfung: Wenn du bei "Haupttanks, in Reihenfolge" "Aus dem Planer" klickst und dann "Rollen jetzt setzen", dann sind die Tanks im Raidfenster Haupttank, und im Chat steht "Haupttanks: N gesetzt"; lässt das Spiel es nicht zu, steht stattdessen "Haupttanks: Das Spiel lässt Addons das nicht setzen. Setze sie im Raidfenster von Hand." (bitte genau diese Zeile und die Meldung des Spiels über ein blockiertes Addon melden).
- Prüfung: Wenn bei "Plündermeister" zuerst ein Name steht, der nicht im Raid ist, dann einer im Raid, und die Plündergrenze "Rar (blau)" ist, dann ist nach "Rollen jetzt setzen" der zweite Plündermeister ab Rar, und im Chat steht "Plündermeister: <Name>, ab Rar (blau)"; ein zweiter Klick setzt nichts neu ("ist es schon"). Kommt "Plündermeister: Das Spiel lässt Addons das nicht setzen ...", die Zeile melden.
- Prüfung: Wenn du nur Assistent bist, dann steht auf dem grauen Knopf "Nur als Raidleiter"; im Kampf "Nicht im Kampf".
- Prüfung: Wenn "Automatisch setzen, wenn jemand beitritt" an ist und ein Genannter dem Raid beitritt, dann hat er etwa 2 Sekunden später seine Rolle und im Chat steht eine Zeile "Rollen: ..."; tritt jemand Ungenanntes bei, steht nichts. Vorher `/amisia selbsttest gruppe`: die Zeile "Rollen: Haupttank, Plündermeister" sagt, welche Funktionen das Spiel hat.
- Notiz: Spec docs/specs/2026-11-10-raid-rollen.md; DECISIONS D-95. Nimmt nichts weg: niemand wird herabgestuft, kein Haupttank entfernt. Ob Forever Addons Haupttanks und Plündermeister setzen lässt, ist ungeprüft; ein verweigerter Teil wird bis /reload nicht mehr versucht.

### F-164 Pull- und Pausen-Timer
- Version: 2.74.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du allein `/amisia pull` tippst, dann steht im Chat "Pull in 10 Sekunden (nur bei dir: du bist in keiner Gruppe)", unten links in Amisia zählt "Pull in 9 s" herunter, und nach 10 Sekunden steht "Pull!" im Chat.
- Prüfung: Wenn du als Gruppenleiter `/amisia pull 15` tippst, dann sieht jeder der Gruppe die großen Zahlen des Spiels (falls der Client sie hat, `/amisia selbsttest gruppe` sagt es unter "Pull-Countdown") und im Gruppenchat "Pull in 15 Sekunden"; ohne die Zahlen des Spiels zählt der Chat 5 4 3 2 1 und "Pull!".
- Prüfung: Wenn du als Gruppenleiter unten links auf die Statuszeile klickst und "Pause (5 min)" wählst, dann steht im Gruppenchat "Pause: 5 Minuten (bis HH:MM)", eine Minute vor Ende "Pause: noch 1 Minute" und am Ende "Pause vorbei"; im Menü heißt der Eintrag solange "Pause abbrechen".
- Prüfung: Wenn du im Kampf `/amisia pull` tippst, dann steht "Nicht im Kampf" und nichts geht an die Gruppe; `/amisia pull stop` bricht einen laufenden ab ("Pull abgebrochen!").
- Notiz: Spec docs/specs/2026-11-10-pull-timer.md; DECISIONS D-94. Der Befehl der Pause heißt `/amisia raidpause` (en `break`), weil `/amisia pause` schon die Aufnahme pausiert; `/amisia pause 5` (mit Zahl) ist die Pause.

### F-163 Einladen: Gilde nach Rang, eigene Stichwörter, Einladungen annehmen
- Version: 2.74.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du als Offizier unter Aufstellung (auch ohne Liste) "Einladen" klickst, "bis Veteran" wählst und "Gilde einladen" klickst, dann fragt Amisia "N Gildenmitglieder bis Rang Veteran einladen?" und lädt nach "Einladen" einen nach dem anderen ein; die Liste zeigt sie mit "eingeladen" und "über Gilde einladen".
- Prüfung: Wenn du unter Einstellungen, Raid-Aufstellung "Stichwörter zum Einladen" auf "raid, komm" setzt, "Einladen auf Flüstern" anschaltest und dir ein Gildenmitglied "komm" flüstert, dann wird es eingeladen; "inv" lädt dann nicht mehr ein.
- Prüfung: Wenn du unter Einstellungen, Gruppeneinladungen "Einladungen von Gilde und Freunden annehmen" anschaltest und dich ein Gildenmitglied einlädt, dann bist du ohne Klick in der Gruppe, das Fenster des Spiels ist zu, und im Chat steht "Einladung von <Name> angenommen (Gilde)."; die Einladung eines Fremden fragt das Spiel wie immer.
- Notiz: Spec docs/specs/2026-11-10-einladen-gilde.md; DECISIONS D-93. "Gilde einladen" nutzt dieselben Grenzen wie "Alle einladen": einer alle 0,5 Sekunden, Raid nach dem ersten Beitritt, 3 Einladungen pro Name und Abend, nur heute, nie im Kampf, nur als Leiter oder Assistent.

### F-162 Autor-Charakter: Aufstellung und Raid-Check ohne Offiziersrang
- Version: 2.73.1
- Status: gebaut
- Prüfung: Wenn du mit Vulo Vultrox einloggst (auch ohne Offiziersrang), dann stehen im Reiter Raid links "Aufstellung" und "Raid-Check", und unter Einstellungen gibt es "Raid-Aufstellung".
- Prüfung: Wenn du mit Vulo Vultrox unten links "Zur Raider-Ansicht" wählst, dann fehlen beide Seiten wieder.
- Notiz: DECISIONS D-92. Nur die eigenen Seiten: was andere Clients annehmen (Abgleich, Vergaben, Punkte), hängt weiter am Offiziersrang in der Gilde.

### F-161 Raid-Aufstellung: Vorlagen, aus dem Raid, Spielerliste, Leeren, Export
- Version: 2.73.0
- Status: gebaut
- Prüfung: Wenn du als Offizier unter Aufstellung in einer Nacht ohne Liste "Planer" klickst, dann siehst du die leeren Gruppen und darunter die Spieler der Gilde; klickst du einen Namen an und dann einen freien Platz, steht der Spieler dort und im Raster grau mit der Gruppennummer.
- Prüfung: Wenn du "Vorlagen" klickst, oben links "Stamm" eintippst und "Speichern" klickst, dann steht "Stamm" mit Größe und Spielerzahl in der Liste, auch nach /reload; wählst du eine andere Nacht, die Zeile "Stamm" und "Laden", dann zeigt der Planer dieselben Gruppen.
- Prüfung: Wenn du "Mehr" > "Als Text exportieren" klickst, dann steht ein Block, der mit "#AMISIA-RAID 1 forever" beginnt; kopierst du ihn, wählst eine leere Nacht (oder leerst die Gruppen) und fügst ihn unter "Einfügen" ein, dann stehen alle wieder in ihren Gruppen.
- Prüfung: Wenn du "Mehr" > "Gruppen leeren" klickst und "Leeren" bestätigst, dann sind alle Gruppen frei, und im Planer (ohne "Spieler") stehen alle unter "Nicht eingeteilt".
- Prüfung: Wenn du allein bist und "Mehr" klickst, dann ist "Aus dem Raid übernehmen" grau; im Planer mit "Spieler" und der Quelle "Raid" steht "Du bist in keinem Raid.".
- Notiz: Braucht: Raid: Wenn du in einem Raid "Mehr" > "Aus dem Raid übernehmen" klickst, dann steht jeder Raider im Planer in seiner Raidgruppe, und der Chat sagt "Aus dem Raid: N eingeteilt, ...".
- Notiz: Spec docs/specs/2026-11-10-aufstellung-vorlagen.md; DECISIONS D-91. Höchstens 12 Vorlagen. Nichts davon lädt ein oder verschiebt im Spiel; das tun weiter "Alle einladen" und "Gruppen sortieren" (F-084).

### F-160 Berufe: woher ein Reagenz kommt
- Version: 2.72.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Berufe in einem Rezept auf ein Reagenz klickst (z. B. Kupfererz), dann öffnet sich "Woher kommt Kupfererz?" mit den Sammelzonen ("Sammeln (Bergbau): Dun Morogh" …), und ein Klick auf eine Zone öffnet ihre Weltkarte.
- Prüfung: Wenn du auf ein Händler-Reagenz klickst (z. B. Grobes Garn) und im Menü auf "Händler: …", dann steht der Wegpunkt beim Händler; Händler mit Ort und Preis, der nächste zuerst.
- Prüfung: Wenn du auf ein hergestelltes Reagenz klickst (z. B. Leinenstoffballen) und auf "Herstellen: …", dann öffnet sich dieses Rezept.
- Prüfung: Wenn du in der Herstellliste oder in der Einkaufsliste der Route auf ein Material klickst, dann öffnet sich dasselbe Menü; die Quelle darunter sagt jetzt auch "sammeln: Kräuterkunde", "Drop" oder "Weltdrop".
- Notiz: D-90; Daten `PROFESSIONS.RS` aus AllTheThings. Etwa 120 Reagenzien (meist Raid-Drops) bleiben "Quelle unbekannt".

### F-159 Herstellliste mit Bank und Twinks, Herstellbar-Zahl
- Version: 2.72.0
- Status: gebaut
- Prüfung: Wenn du ein bekanntes Rezept ansiehst, für das die Taschen reichen, dann steht in der Rezeptliste "(n)" in Grün hinter dem Namen und im Kopf der Reagenzien "herstellbar: n" (mit "(m mit Bank)", wenn die Bank mehr hergibt).
- Prüfung: Wenn ein Twink (gleicher Realm, gleiche Fraktion, einmal eingeloggt) ein Reagenz hat und dir selbst etwas fehlt, dann steht bei dem Reagenz "4+6 / 10" in Orange, und der Tooltip nennt "Bei deinen Twinks:" mit Name und Anzahl (Bankanteil in Klammern).
- Prüfung: Wenn du die Herstellliste öffnest, dann steht unter jedem Material "Twinks: n", sofern ein Twink etwas davon hat, und hinter jedem bekannten Rezept "(n)", grün, wenn es für die gewünschte Anzahl reicht.
- Notiz: D-90. Twinks zählen ab ihrem nächsten Login alle Reagenzien, nicht nur die ihrer eigenen Berufe.

### F-158 Item-Anzeige verschieben und gestalten
- Version: 2.71.0
- Status: im Spiel geprüft (2026-11-09)
- Prüfung: Wenn du unter Einstellungen den Abschnitt "Item-Anzeige" öffnest und "Anzeige verschieben" klickst, dann erscheint die Anzeige mit dunklem Rahmen und Beispielzeilen; du ziehst sie mit der Maus woanders hin, klickst "Fertig", und neue Beute erscheint dort, auch nach /reload.
- Prüfung: Wenn du Schriftart (z. B. Morpheus), Umriss "Dick", Ausrichtung "Rechts" oder die Größe änderst und "Anzeige ausprobieren" klickst, dann sieht das Beispiel so aus.
- Prüfung: Wenn du Anzeigedauer 6 s und Bewegung "Sinkt nach unten" wählst, dann bleiben die Zeilen länger und sinken beim Ausblenden.
- Prüfung: Wenn du "Position zurücksetzen" klickst, dann steht die Anzeige wieder links über der Bildschirmmitte.
- Notiz: Wunsch des Nutzers 2026-11-09; D-89. Deine bisherigen Einstellungen (an/aus, Gold, Größe, Qualität) werden übernommen.

### F-157 Quellensymbol im Ausrüstungsplaner öffnet Boss oder Rezept
- Version: 2.70.0
- Status: im Spiel geprüft (2026-11-09)
- Prüfung: Wenn du im Ausrüstungsplaner bei einem Vorschlag aus einem Dungeon auf das Dungeon-Symbol rechts klickst, dann öffnet sich Dungeons mit diesem Dungeon (Teil Übersicht), links ist der Boss gewählt, der das Item fallen lässt, und rechts ist die Zeile des Items markiert.
- Prüfung: Wenn du bei einem Vorschlag aus einem Raid auf das Raid-Symbol klickst, dann öffnet sich die Seite Raids genauso beim Boss.
- Prüfung: Wenn du bei einem hergestellten Item auf das Berufssymbol klickst, dann öffnet sich Berufe mit dem Rezept, das das Item herstellt.
- Prüfung: Wenn du die Maus auf das Symbol hältst, dann nennt der Tooltip die Quelle und was ein Klick öffnet.
- Notiz: Wunsch des Nutzers 2026-11-08 mit einem Bildschirmfoto eines anderen Addons; D-88.

### F-156 Offiziersansicht nur für Offiziere
- Version: 2.69.0
- Status: im Spiel geprüft (2026-11-09)
- Braucht: Gilde
- Prüfung: Wenn ein Gildenmitglied ohne Offiziersrang /amisia öffnet, dann steht unten "Raider-Ansicht", im Menü der Statuszeile fehlt "Zur Offiziersansicht", unter Einstellungen, Oberfläche fehlt "Ansicht", und `/amisia ansicht offizier` meldet "Die Offiziersansicht haben nur Offiziere der Gilde."
- Prüfung: Wenn ein Offizier (Rang Offizier oder höher) /amisia öffnet, dann steht unten "Offiziersansicht", und das Menü wechselt zur Raider-Ansicht und zurück.
- Prüfung: Wenn du mit Vulo Vultrox einloggst, dann hast du die Offiziersansicht, auch ohne Offiziersrang.
- Notiz: Wunsch des Nutzers 2026-11-08; D-87. Die Rechte prüfte Amisia schon vorher am Rang, nur die Ansicht war frei wählbar.

### F-155 Berufslehrer lesen: echte Lernstufen
- Version: 2.68.0
- Status: gebaut
- Prüfung: Wenn du einen Bergbaulehrer ansprichst und danach auf der Seite Berufe, Bergbau "Zinn verhütten" öffnest, dann steht in Details "lernbar ab <Wert des Lehrers> (vom Lehrer)" und "Gelernt bei" nennt den Lehrer mit Ort und Wegpunkt.
- Prüfung: Wenn du einen Beruf öffnest, dessen Lehrer du noch nicht angesprochen hast, dann steht im Kopf "N Lernstufen geschätzt (?)" und in Details hinter der Lernstufe ein "?".
- Prüfung: Wenn du im Lehrerfenster Filter (z. B. nur verfügbare) eingestellt hast und den Lehrer erneut ansprichst, dann sind die Filter danach wie vorher.
- Prüfung: Wenn du `/amisia lehrer` eingibst, dann meldet der Chat "Lehrer: N gelesen, M Angebote (noch nicht in den Daten)".
- Notiz: Spec docs/specs/2026-11-08-lehrer-lesen.md, D-86. Nach dem Besuch: `build.py data` übernimmt die Lesungen in tools/trainer_archive.json.

### F-154 Dungeons und Raids: Bosse mit Porträt, Beute mit Symbolen
- Version: 2.76.1
- Status: gebaut
- Prüfung: Wenn du auf der Seite Dungeons einen Dungeon öffnest (Teil Übersicht), dann stehen links die Bosse untereinander, jeder mit rundem Porträt im Goldring (das Modell des Bosses, ohne Modell der Totenkopf des Spiels), "1. Name" und darunter grau "4 Items · 1 Upgrade"; rechts steht der gewählte Boss groß mit Porträt, Name und "Boss 1 von 6", darunter seine Beute: Symbol im Rahmen der Qualität, Name, Slot und Zuwachs, Dropchance und der Stern.
- Prüfung: Wenn du links auf einen anderen Boss klickst, dann zeigt die rechte Seite seine Beute; die Maus auf einem Boss zeigt ihn im Bild oben, Rechtsklick markiert ihn als getötet oder nicht.
- Prüfung: Wenn du auf den Stern einer Beutezeile klickst, dann kommt das Item auf die Wunschliste (der Stern leuchtet), ein zweiter Klick nimmt es wieder herunter; Strg-Klick auf die Zeile zeigt die Anprobe, Rechtsklick das Menü.
- Prüfung: Wenn du einen Raid auf der Seite Raids öffnest, dann sieht die Übersicht genauso aus.
- Prüfung: Wenn du (ab 2.76.1) Onyxia auf der Seite Raids oder einen Dungeon öffnest, dann zeigt der runde Rahmen jeder Bosszeile das Modell des Bosses und bleibt nicht schwarz, auch nach Schließen und erneutem Öffnen des Fensters; dasselbe gilt für die Porträts im Fenster "Lauf-Zeiten".
- Notiz: Wunsch des Nutzers 2026-11-08 mit einem Bildschirmfoto eines anderen Addons ("die inis sollen auch da die bosse mit ihren icons anzeigen und die items die sie dropen auch mit den icons"); D-85, ersetzt die aufklappbare Bossliste von F-144. Neue Textur `ui/boss_ring.tga`: nach dem Release WoW ganz neu starten.

### F-153 Berufe: Favoriten und Herstellliste
- Version: 2.66.0
- Status: gebaut
- Prüfung: Wenn du im Rezept oben rechts auf den Stern klickst und dann den Reiter "Favoriten" öffnest, dann steht das Rezept dort (auch aus anderen Berufen); ein zweiter Klick auf den Stern nimmt es wieder heraus.
- Prüfung: Wenn du im Rezept die Anzahl wählst und "+ Liste" klickst, dann zeigt der Reiter "Herstellliste" das Rezept mit der Anzahl und daneben alle Reagenzien mit hast/brauchst und dem nächsten Händler; "Entfernen" und "Liste leeren" nehmen sie wieder heraus.
- Notiz: D-82. Je Charakter gespeichert; Herstellen selbst geht nur im Berufsfenster des Spiels.

### F-152 Anzeige erhaltener Items beim Looten und bei Questbelohnungen
- Version: 2.67.0
- Status: gebaut
- Prüfung: Wenn du etwas lootest oder eine Quest mit Belohnung abgibst, dann steht kurz "+Name" mit dem Symbol des Items in seiner Qualitätsfarbe links über der Bildschirmmitte und blendet aus.
- Prüfung: Wenn du unter Einstellungen, Oberfläche "Erhaltene Items anzeigen" ausschaltest, dann erscheint nichts mehr; "Ab Qualität" blendet schlechtere Items aus; "Anzeige ausprobieren" zeigt ein Beispiel.
- Prüfung: Wenn du Gold lootest oder für eine Quest bekommst, dann steht kurz "+1g 2s 3c" mit Münzen in Gold-, Silber- und Kupferfarbe da; unter Einstellungen, Oberfläche schaltet "Erhaltenes Gold anzeigen" das ab und "Schriftgröße der Anzeige" macht Text und Symbol größer oder kleiner.
- Notiz: D-79. Ohne Spec: eine kleine Anzeige ohne Daten und Nachrichten (docs/specs/README).
- Prüfung: Wenn du beim Händler etwas kaufst oder verkaufst, Post abholst oder handelst, dann erscheint nichts.

### F-151 Berufe mit Übersicht und Berufsliste in der Leiste
- Version: 2.68.0
- Status: gebaut
- Prüfung: Wenn du im Reiter Berufe links auf "Übersicht" klickst (oder `/amisia berufe übersicht` eingibst), dann zeigt die Seite "Deine Berufe" mit Rang und bekannten Rezepten, "Alle Berufe" mit ihrer Rezeptzahl und "Weiteres" mit Lager und Händlergunst als Kacheln.
- Prüfung: Wenn du links unter "Übersicht" schaust, dann stehen dort die Berufe mit ihrem Symbol, darunter Lager und Händlergunst mit deiner Gunst als Zahl; die gezeigte Ansicht ist hervorgehoben.
- Prüfung: Wenn du auf eine Berufskachel oder links auf einen Beruf klickst, dann öffnet sich "Alle Rezepte": oben das Berufssymbol und "Schneiderei – Alle Rezepte", links die Rezepte mit Symbol, Farbbalken und Punkten, rechts die Kästen Details, Reagenzien und Gildenmitglieder; der Trichter neben der Suche öffnet die Filter.
- Prüfung: Wenn du den Reiter Berufe zum ersten Mal nach einem /reload öffnest, dann steht die Übersicht da, mit vier Kacheln je Zeile und unten "Nächste Lehrer" (je Beruf ein Lehrer deiner Fraktion mit Zone und Kartenknopf, der den Wegpunkt setzt).
- Notiz: Spec docs/specs/2026-11-08-hub-reiter.md; D-78 mit Nachtrag (Start, vier Spalten, Lehrer aus AllTheThings).
- Prüfung: Wenn du links "Lager" oder oben "Händlergunst" wählst und ein Eintrag anklickst, dann steht er rechts in denselben Kästen wie ein Rezept (Details, Reagenzien mit hast/brauchst, Gildenmitglieder, Stern und "+ Liste"); ein Lagerobjekt nennt in Details zuerst Plätze, was es ersetzt und seine Beschreibung.

### F-150 Talente mit Klassen und Plänen in der Leiste
- Version: 2.64.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Talente öffnest, dann stehen links die neun Klassen mit Wappen (deine gewählt), darunter "Plan 1: Primär"/"Plan 2: Sekundär" und "Eigene laden", "Plan leeren", "Build importieren", "Build exportieren" mit Symbol.
- Prüfung: Wenn du rechts schaust, dann steht oben "Stufe: 60 · Verfügbar: 51 · Verteilt: 0 · Übrig: 51" über die Breite verteilt, darunter die drei Bäume in goldbraunem Rahmen auf dem Bild der Klasse, unten rechts "Linksklick + · Rechtsklick -".
- Prüfung: Wenn du links eine andere Klasse oder Plan 2 klickst, dann zeigt die Seite deren Plan und die Leiste wählt sie.
- Prüfung: Wenn du "Build exportieren" klickst, dann ist der Code im Feld markiert und Strg+C kopiert ihn; "Build importieren" leert das Feld, ein eingefügter Code oder Link mit Enter wird übernommen.
- Prüfung: Wenn du das Hauptfenster breiter oder höher ziehst, dann werden die Bäume breiter bzw. höher; der Talentrechner (Leistenzeile) hat weiter Klasse, Plan-Reiter und Knöpfe.
- Notiz: Spec docs/specs/2026-11-08-hub-reiter.md; D-76.

### F-149 Ausrüstungsplaner: Modell mit Plätzen, Vorschläge je Platz, Sets in der Leiste
- Version: 2.66.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Ausrüstung öffnest, dann siehst du zuerst den Ausrüstungsplaner: links dein Modell auf dem Bild der Anprobe (beim breiteren Fenster breiter) mit acht Plätzen links (mit Hemd und Wappenrock), acht rechts und den Waffen darunter, oben dein Name, deine Stufe und die Spezialisierung zum Wählen.
- Prüfung: Wenn du einen Platz anklickst, dann zeigt die Liste rechts seine Vorschläge mit Symbol, Name in Qualitätsfarbe (Questbelohnung mit gelbem "!"), "Stufe 25 · Dungeon - Boss", "Stufe 32 · Schneiderei 150" oder "Quest: Titel", Zuwachs in Prozent ("neu" ohne angelegtes Item), Quellsymbol (Beruf: sein Symbol) und grauem Stern; "Quellen" schaltet Quellen ab; "Alle" oder andere Stufen zeigen die Items dieses Bereichs, "Alle Items suchen ..." findet Items nach Namen.
- Prüfung: Wenn du eine Zeile anklickst, dann wird sie deine Wahl für den Platz und steht am Modell; ein zweiter Klick hebt sie auf, "Zurücksetzen" fragt erst und nimmt dann alle deine Wahlen weg; der Stern wird beim Klick gold und das Item steht unter "Wunschliste".
- Prüfung: Wenn du "Ziele" wählst, dann stehen "N/17 Ziele", der Balken, die Filter und deine Plätze nach Abschnitt; ein Klick auf einen Platz zeigt seine Vorschläge, oben "Deine Wahl" mit X und "Übernehmen". Unter dem Modell wechseln "Ziele | Angelegt", die Wertung zeigt im Tooltip das Beste und die Wertänderungen; das Quadrat neben einem Platz listet die Verzauberungen.
- Prüfung: Wenn du links unter den Seiten auf "Dungeon-Sets" (oder Raid-, PvP-, Handwerks-, Welt-Sets, Ruf) klickst, dann stehen rechts die Sets dieser Art; ein Klick öffnet ein Set, der Reiter "Vorschläge" führt zurück.
- Notiz: Spec docs/specs/2026-11-08-hub-reiter.md; D-77. Im Spiel prüfen: der Hintergrund der Anprobe deiner Rasse und das Warnzeichen.

### F-148 Dungeons & Raids als Tabelle mit Stufenbereichen
- Version: 2.63.0
- Status: gebaut
- Prüfung: Wenn du "Dungeons" öffnest, dann siehst du eine Tabelle mit Dungeon, Stufe, Gebiet, Zone, Schlüssel, Quests und Aktionen, gruppiert nach Stufenbereichen; ein Klick auf einen Spaltenkopf sortiert.
- Prüfung: Wenn du links auf einen Stufenbereich klickst, dann springt die Tabelle dorthin.
- Prüfung: Wenn du auf das Kartensymbol einer Zeile klickst, dann wird ein Wegpunkt zum Eingang gesetzt; das Wappen zeigt Allianz, Horde oder umkämpft.
- Notiz: Spec docs/specs/2026-11-08-hub-reiter.md, Schritt 2; D-74. Ersetzt die Kacheln von F-143.

### F-147 Hub: Bildkopf, Reiter oben, Leiste je Reiter, Fußzeile
- Version: 2.68.0
- Status: gebaut
- Prüfung: Wenn du /amisia öffnest, dann hat das Fenster den Rahmen der Spielfenster mit Titel "Amisia", rotem X und rotem Minimieren-Knopf; darunter stehen das Logo, "Amisia" und ein Streifen eines Ladebilds, rechts Suchfeld und Feedback, darunter die Reiter Ausrüstung, Dungeons & Raids, Berufe, Talente, Raid, Gilde und das Zahnrad.
- Prüfung: Wenn du einen Reiter klickst, dann zeigt die linke Leiste oben dessen Symbol und Namen und nur seine Seiten, und seine zuletzt gewählte Seite öffnet sich.
- Prüfung: Wenn du unten links auf den Aufnahmezustand klickst, dann öffnet sich das Menü mit Aufnahme und Ansicht; rechts unten stehen Ansicht und Version.
- Notiz: Spec docs/specs/2026-11-08-hub-reiter.md, Schritt 1; D-73. Ersetzt die Leiste mit allen Gruppen von F-145.

### F-146 Dungeon- und Raid-Journal nach dem Vorbild: Filter, Reiter, Lauf, Karte
- Version: 2.63.0
- Status: gebaut
- Prüfung: Wenn du eine Instanz betrittst, dann öffnet die Seite Dungeons bzw. Raids deren Detailseite, und ein Boss-Kill setzt den Haken und zählt "x/y Bosse" hoch.
- Prüfung: Wenn du auf der Startseite suchst oder Passend/Quests wählst, dann bleiben nur passende Zeilen.
- Prüfung: Wenn ein Teil aus deiner Wunschliste fällt, dann kommt eine Meldung mit Ton.
- Prüfung: Wenn der Client eine Karte für die Instanz hat, dann zeigt der Reiter Karte sie mit Ebenen und Zoom.
- Notiz: Spec docs/specs/2026-11-07-hauptfenster-journal.md, Schritte 3 bis 5.

### F-145 Hauptfenster nach dem Vorbild: Kopf mit Logo, Symbolzeilen, Breite, Minimieren
- Version: 2.63.0
- Status: gebaut
- Prüfung: Wenn du am Griff unten rechts ziehst, dann ändern sich Breite und Höhe; nach einem /reload bleibt die Größe, und Listenseiten nutzen die Breite.
- Prüfung: Wenn du auf Minimieren klickst, dann bleibt nur eine kleine Leiste; ein Klick darauf öffnet das Fenster an derselben Stelle wieder.
- Notiz: Spec docs/specs/2026-11-07-hauptfenster-journal.md, Schritte 1 und 2. Die Leiste mit allen Gruppen (Schritt 1) ersetzt F-147 schon in derselben Version.

### F-144 Aufklappbare Bosszeilen mit Beutesymbolen
- Version: 2.62.0
- Status: gebaut
- Prüfung: Wenn du auf der Detailseite eines Dungeons (Teil Bosse) oder eines Raids bist, dann ist jeder Boss eine Zeile mit dem Plus oder Minus des Questlogs vor dem Namen; Bosse mit einem Upgrade für dich sind aufgeklappt (ihre Items darunter wie bisher), die anderen zugeklappt mit bis zu sechs kleinen Itemsymbolen im Rahmen ihrer Qualität rechts in der Zeile und "+N", wenn es mehr sind.
- Prüfung: Wenn du auf einen Boss oder eines seiner Symbole klickst, dann klappt er auf oder zu; die Maus auf einem Symbol zeigt den Tooltip des Items, Strg-Klick darauf die Anprobe, Shift-Klick den Link im Chat und Rechtsklick das Menü wie in der Itemzeile; das Bild oben zeigt dabei den Boss.
- Prüfung: Wenn du rechts neben Bosse/Quests (Raids: links von Wegpunkt) auf "Alle aufklappen" klickst, dann klappen alle Bosse auf und der Link heißt "Alle zuklappen"; im Teil Quests und im Questjournal fehlt der Link.
- Prüfung: Wenn du einen anderen Dungeon öffnest und zurückkommst oder das Fenster höher ziehst, dann bleibt jeder Boss so auf- oder zugeklappt, wie du ihn gelassen hast; nach einem /reload gilt wieder die Vorgabe.
- Notiz: Schritt 4 von 4 der UI-Überholung (Nutzer 2026-11-07: "mach die nächsten schritte"); D-69. Ohne Spec: nur Aussehen und Ablauf der Bossliste (docs/specs/README). Der Zustand liegt nur im Speicher, je Seite und Dungeon (Raid).
- Notiz: Die Übersicht hat seit F-154 (D-85) zwei Spalten statt der aufklappbaren Liste; die Prüfungen hier gelten nicht mehr.

### F-143 Startseite mit Kacheln und Detailseite: Dungeons und Raids
- Version: 2.62.0
- Status: gebaut
- Prüfung: Wenn du zum ersten Mal in der Sitzung die Seite Dungeons öffnest, dann siehst du unter dem nächsten Dungeon alle Dungeons als Kacheln, drei nebeneinander: oben ihr Bild mit dem Namen in Gold, darunter Level und Passung und "N Upgrades · +X je Lauf · Wert V"; der empfohlene trägt rechts oben ein grünes "Empfohlen", zu hohe oder zu leichte sind grau.
- Prüfung: Wenn du auf eine Kachel klickst, dann steht oben links "< Alle Dungeons" vor der Spezialisierung, direkt darunter das Bild des Dungeons mit "Lauf planen" und "Alle auf Karte", darunter Bosse/Quests mit Wegpunkt und die Liste bis zum unteren Rand; "< Alle Dungeons" bringt dich zu den Kacheln zurück.
- Prüfung: Wenn du einen Dungeon über die Suche oder seinen Eingang auf der Weltkarte öffnest, dann landest du direkt auf seiner Detailseite; ein Raid ebenso auf der Seite Raids, deren Kacheln Größe, Passung und deine Raid-ID zeigen.
- Prüfung: Wenn du das Fenster am Griff höher ziehst, dann zeigt die Startseite mehr Reihen Kacheln.
- Notiz: Schritt 3 von 4 der UI-Überholung (Nutzer 2026-11-07: "mach die nächsten schritte"); D-69. Ohne Spec: nur Aussehen und Ablauf der zwei Seiten (docs/specs/README). Die Ansicht (Start oder Detail) merkt sich Amisia nur bis zum /reload.
- Notiz: Die Kacheln ersetzt in 2.63.0 die Tabelle von F-148 (D-74); die Detailseite bleibt.

### F-142 Seitenkopf: Name, eine Zeile und goldene Linie über jeder Seite
- Version: 2.62.0
- Status: gebaut
- Prüfung: Wenn du eine Seite öffnest, dann steht über ihr groß und gold ihr Name, darunter grau eine Zeile, wozu sie da ist, und darunter eine dünne goldene Linie, die zu den Rändern hin ausläuft.
- Prüfung: Wenn du auf Karte oder Quests bist, dann sitzen das "i" und das Zahnrad rechts in diesem Seitenkopf, nicht mehr oben im Fensterkopf.
- Notiz: Schritt 2 von 4 der UI-Überholung (Nutzer 2026-11-07: "mach die nächsten schritte"); D-69. Ohne Spec: nur Aussehen und Layout (docs/specs/README). Das Fenster ist dafür 38 px höher (598), die Seite bleibt 602 x 478.

### F-141 Eine Seitenleiste: Gruppen wie im Auktionshaus, Seitenfenster darin, Höhe ziehbar
- Version: 2.62.0
- Status: gebaut
- Prüfung: Wenn du das Fenster öffnest, dann hängen keine Reiter mehr unter dem Fenster und keine Seitenreiter rechts daneben, und links stehen die Gruppen Raid, Charakter, Welt, Gilde und Amisia als Balken mit Plus oder Minus.
- Prüfung: Wenn du auf eine zugeklappte Gruppe klickst, dann klappt die vorher offene zu und die zuletzt gewählte Seite der neuen Gruppe öffnet sich; ein Klick auf die offene Gruppe klappt sie zu und die Seite bleibt.
- Prüfung: Wenn du unter Charakter auf "Ausrüstungstabelle" klickst, dann öffnet sich das Fenster, die Zeile ist weiß, solange es offen ist, und ein zweiter Klick schließt es.
- Prüfung: Wenn du das Fenster am Griff unten rechts höher ziehst und `/reload` machst, dann hat es dieselbe Höhe und lange Listen (Dungeons, Quests, Mitglieder) reichen bis zum unteren Rand.
- Prüfung: Wenn du in die Suche "dead" tippst und einen Treffer anklickst, dann klappt dessen Gruppe auf und die Seite ist darin gewählt.
- Notiz: Spec `docs/specs/2026-11-07-seitenleiste.md`, Schritt 1 von 4 der UI-Überholung; Wunsch des Nutzers 2026-11-07 ("ich brauche eine ui overhall ... im WoW Forever classic style", dann "Passt").

### F-140 Aufgeräumte Oberfläche: Fensterkopf, Hilfe, Textreiter, ein roter Knopf je Ansicht
- Version: 2.61.0
- Status: gebaut
- Prüfung: Wenn du das Fenster öffnest, dann stehen oben keine roten Knöpfe mehr: in der Mitte der Raid-Status mit einem kleinen Pfeil (ein Klick: Menü mit "Aufnahme pausieren" und "Zur Offiziersansicht"), rechts das Zahnrad (nur auf Seiten mit Einstellungen) und das "i" der Hilfe.
- Prüfung: Wenn du auf Karte, Quests, Berufe oder Dungeons mit der Maus über das "i" oben rechts fährst, dann stehen dort die Erklärungen, die vorher grau unten standen, und die Liste reicht bis an den unteren Rand.
- Prüfung: Wenn du auf Ausrüstung, Dungeons, Berufe oder Aufstellung die Ansichten wechselst (Ziele/Hier/Wunschliste, Bosse/Quests, Rezepte/Route, Abgleich/Planer/Einladen), dann sind das goldene Wörter, das gewählte weiß und unterstrichen, und Filter wie "Quests" oder "Lernbar" haben ein kleines Häkchenfeld.
- Prüfung: Wenn du über eine Zeile auf Karte, Quests, Ausrüstung (Hier), im Lauf-Planer oder in "Einladen" fährst, dann erscheint ihr Knopf ("Karte", "Wegpunkt", "Wunsch", "Einladen"); ohne Maus ist die Liste reiner Text.
- Prüfung: Wenn du die Übersicht ansiehst, dann hat keine Karte einen roten Knopf; ein Klick irgendwo auf eine Karte öffnet ihre Seite, und unter Einstellungen sind Auswahlen wie "Ansagekanal" Dropdowns.
- Notiz: Schritt 3 räumte auch die Seitenfenster auf (Ausrüstungstabelle, Ziele, Anmeldung, Raid-Kalender, Soft-Reserve-Import, Einrichtung, Offiziers-Würfelfenster, Vergabe-Dialog); prüfen beim nächsten Raid: "Vergeben" steht beim Gewinner immer, bei den anderen unter der Maus.
- Notiz: Wunsch des Nutzers 2026-11-06 ("finde das ganze ui zu unübersichtlich keine klare linie und so ist so voll nicht aufgeräumt", dann "Ja, Schritt 1", dann "Erst Schritt 2"); D-67. Schritt 3 auf "Erst Schritt 3". Rote Knöpfe und Chips auf den Seitenbildern: 1471 vorher, 280 nach Schritt 2, 147 nach Schritt 3 (`ui_layout.py red`, seit Schritt 3 mit den Seitenfenstern: 200 auf 273 Bildern).

### F-126 Raid-Teil auf TBC Anniversary und Classic Era
- Version: 2.57.0
- Status: gebaut
- Prüfung: Wenn du dich auf TBC Anniversary oder Classic Era einloggst, dann lädt Amisia ohne "veraltet", und unten stehen nur Raid, Gilde, Kalender, Amisia, alle innerhalb der Fensterbreite.
- Prüfung: Wenn du dort Einstellungen, Raid, Aufnahme öffnest, dann stehen "20:00" und das Feld "60" mit sichtbaren Pfeilen bündig untereinander, und das rote X steht direkt rechts neben dem Häkchen.
- Prüfung: Wenn du auf TBC/Era mit der Maus über ein soft-reserviertes Item fährst, dann steht die SR-Zeile im Tooltip.
- Prüfung: Wenn du auf Forever das Fenster öffnest, dann sieht alles aus wie vorher, nur das rote X steht neben seinem Feld.
- Prüfung: Wenn du auf TBC Anniversary oder Classic Era als Lootleitung eine Würfelrunde ansagst, dann steht die Ansage im Raidchat.
- Notiz: Spec `docs/specs/2026-10-25-raid-auf-tbc-und-era.md` (freigegeben 2026-10-25). Auf TBC/Era aus: Export, Handel-Helfer, Raid-Check-Buffs.

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
- Version: 2.57.0
- Status: gebaut
- Prüfung: Wenn du `/amisia` öffnest, dann hängen unten am Fenster die Reiter "Raid", "Ausrüstung", "Gilde", "Kalender" und "Amisia" im Stil der Reiter unter dem Charakterfenster; der gewählte ist hell, und links stehen nur seine Seiten (bei "Raid" Übersicht, Raid-Log, Vergaben, Statistik, Soft-Reserves; in der Offiziersansicht auch Rolls, Punkte, Raid-Archiv und Export).
- Prüfung: Wenn du auf "Ausrüstung" klickst, dort "Karte" wählst, auf "Raid" und wieder auf "Ausrüstung" klickst, dann öffnet sich wieder "Karte"; nach `/reload` öffnet `/amisia` den Reiter "Ausrüstung" mit "Karte". Fällt eine Seite durch einen Wechsel der Ansicht auf die Übersicht zurück, bleibt die gemerkte Seite des Reiters.
- Prüfung: Wenn du `/amisia einstellungen` eingibst, dann ist der Reiter "Amisia" gewählt und links stehen Einstellungen und "Über und Befehle"; `/amisia statistik` wählt "Raid".
- Prüfung: Wenn du die Ansicht auf "Raider" stellst, dann fehlen unter "Raid" die Seiten Raid-Archiv und Export; die Reiter passen auch auf einem englischen Client nebeneinander ("Raid", "Gear", "Guild", "Calendar", "Amisia").
- Prüfung: Wenn du als Offizier den Reiter Raid öffnest, dann stehen die Seiten in der Reihenfolge eines Raidabends: Übersicht, Aufstellung, Soft-Reserves, Raid-Check, Rolls, Vergaben, Raid-Log, Punkte, Statistik, Raid-Archiv, Export.
- Notiz: Spec docs/specs/2026-10-11-fenster-reiter-kalender.md; DECISIONS D-45. Die Reiter sind die Vorlage des Spiels (`PanelTabButtonTemplate`); ein Reiter ohne sichtbare Seite fehlt. Gemerkt in `settings.window.tab` und `pages`.
- Notiz: 2.29.0: die Seiten links unter den Reitern stehen als Balken der Kategorienliste des Auktionshauses (21 px, ohne Symbole); in der Suche ist eine Gruppe ein Balken, ihre Treffer eingerückte Unterbalken (D-06, Nachtrag D-45).
- Notiz: 2.57.0: Reiter Raid in der Reihenfolge einer Raidnacht (davor, währenddessen, danach); die Offiziersseite "Raids" heißt "Raid-Archiv", Export steht daneben im Reiter Raid (Nachtrag D-45).

### F-095 Suchfeld oben links im Hauptfenster
- Version: 2.57.0
- Status: gebaut
- Prüfung: Wenn du oben links ins Suchfeld "experten" tippst, dann wird die Seitenliste zur Ergebnisliste mit der Leiste "Einstellungen 1" und dem Eintrag "Expertenmodus"; ein Klick öffnet die Einstellungen mit "Expertenmodus" im Suchfeld der Seite, und das Suchfeld oben links ist wieder leer.
- Prüfung: Wenn du "ra" tippst, dann stehen unter "Seiten" die passenden Seiten (in der Offiziersansicht "Raid-Archiv" und "Raid-Log"), unter "Einstellungen" höchstens 8 Einträge und in der Offiziersansicht unter "Spieler" Namen aus deinen Raids; ein Klick auf einen Spieler öffnet die Statistik mit ihm unter der Liste.
- Prüfung: Wenn du den Namen eines Items tippst, das in deinen Raids fiel (mindestens drei Buchstaben), dann steht es unter "Items"; die Maus darauf zeigt seinen Tooltip, ein Klick setzt den Link in die Chatzeile.
- Prüfung: Wenn du nur einen Buchstaben tippst, dann bleibt die Seitenliste; bei "qqqxx" steht "Nichts gefunden."; Escape oder das X im Feld leeren es und die Seitenliste kommt zurück. Ein Klick auf einen Reiter (auch den gewählten) leert es ebenso und zeigt die Seiten dieses Reiters.
- Prüfung: Wenn du im Suchfeld "dkp" tippst, dann findet die Suche die Seite Punkte; bei "version" steht auch die Gruppe "Befehle", und ein Klick schreibt den Befehl in die Chatzeile.
- Notiz: DECISIONS D-45. Items nur mit Namen, die der Client schon kennt (keine Frage an den Server); die Spielersuche gibt es nur in der Offiziersansicht (D-36).
- Notiz: 2.57.0: Stichwörter auf Deutsch und Englisch ("dkp" findet Punkte, "wegpunkt" die Karte), Gruppe "Befehle" (ab 3 Zeichen, ein Klick schreibt den Befehl in die Chatzeile), Tooltip am Suchfeld, Treffer behalten beim Auffrischen ihre Scrollstelle.

### F-002 Einheitliches Seitengerüst
- Version: 2.12.0
- Status: gebaut
- Prüfung: Wenn du jede Seite der Seitenliste einmal öffnest, dann haben alle denselben Aufbau (Kopfzeile, Filter, Liste, Fußzeile), und kein Text oder Knopf ragt über den Rand oder ist abgeschnitten.
- Prüfung: Wenn eine Seite nichts zu zeigen hat (z. B. Statistik ohne Raid: "Noch kein Raid aufgezeichnet"), dann steht ein Leerzustand mit Erklärung in der Mitte statt einer leeren Liste.
- Notiz: Seit 2.27.0 stehen die Seiten unter ihren Reitern (F-094); "jede Seite der Seitenliste" heißt: jeden Reiter durchklicken. Die Kalender-Seite (F-096) ist mit demselben Gerüst gebaut.

### F-003 Übersicht mit Karten
- Version: 2.57.0
- Status: gebaut
- Prüfung: Wenn du die Seite Übersicht öffnest, dann stehen dort Karten (Raid, Soft-Reserves, Ausrüstung, Vergaben) mit dem Knopf "Öffnen", oder "Noch nichts zu zeigen", solange es nichts gibt.
- Prüfung: Wenn du bei der Karte Ausrüstung auf "Öffnen" klickst, dann öffnet sich die Seite Ausrüstung bei Ziele.
- Prüfung: Wenn du im Hauptfenster oben links auf das Porträt klickst, dann öffnet sich die Übersicht.

### F-004 Minimap-Button und Schnellmenü
- Version: 2.57.0
- Status: gebaut
- Prüfung: Wenn du mit der Maus über den runden Amisia-Button an der Minimap fährst, dann zeigt der Tooltip "Linksklick: Amisia-Fenster" und "Rechtsklick: Schnellmenü".
- Prüfung: Wenn du ihn rechts anklickst, dann öffnet sich das Schnellmenü mit den Reitern des Hauptfensters ("Raid ...", "Ausrüstung ..." usw.), "Einstellungen" und dem Schalter für die Aufnahme; ein Klick auf einen Reiter zeigt seine Seiten im selben Menü, mit "Zurück", und jede Seite öffnet sich.
- Prüfung: Wenn du `/amisia minimap` eingibst, dann verschwindet der Button; noch einmal holt ihn zurück.
- Notiz: 2.57.0: das Schnellmenü folgt den Reitern des Fensters; ein Reiter zeigt seine Seiten im selben Menü, mit "Zurück".

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

### F-130 Feedback-Seite: Bugs und Wünsche an den Autor
- Version: 2.52.0
- Status: gebaut
- Prüfung: Wenn du "Feedback" im Reiter Amisia öffnest, dann stehen dort "Bug"/"Wunsch", ein Textfeld mit Zähler "0/500", "Abschicken" (ausgegraut ohne Text) und darunter, was automatisch mitgeht.
- Prüfung: Wenn ein anderer Spieler (gleicher Server, gleiche Fraktion) eine Meldung abschickt, während Vulo online ist, dann steht sie innerhalb weniger Sekunden in Vulos "Eingang", und beim Absender steht "angekommen" und im Chat "Deine Meldung ist beim Autor angekommen." (braucht: zweiter Spieler)
- Prüfung: Wenn Vulo offline ist, dann bleibt sie beim Absender "wartet" und kommt an, sobald beide gleichzeitig online sind (auch nach `/reload` oder neuem Login des Absenders). (braucht: zweiter Spieler)
- Prüfung: Wenn Vulo eine Meldung "Erledigt" klickt, dann ist sie grau und unter "Offen" nicht mehr da; nach `/reload` bleibt das so.
- Prüfung: Wenn ein Spieler mehr als 3 Meldungen an einem Tag schicken will, dann sagt Amisia "Höchstens 3 Meldungen am Tag." und schickt nichts.
- Notiz: Spec `docs/specs/2026-11-05-feedback.md`, freigegeben 2026-11-05 ("Passt, bauen"); Empfänger Vulo Vultrox.

### F-103 Einstellungen nach Reitern, Knopf "Einstellungen", Zurücksetzen
- Version: 2.57.0
- Status: gebaut
- Prüfung: Wenn du die Einstellungen öffnest, dann stehen in der Seitenliste links unter "Einstellungen" die Gruppen Raid, Ausrüstung, Gilde, Kalender und Allgemein, unter der gewählten ihre Abschnitte; ein Klick auf einen Abschnitt zeigt rechts nur dessen Zeilen; ein Klick auf die offene Gruppe (z. B. "Raid") klappt sie zu und wieder auf, ein Klick auf "Einstellungen" alle Gruppen, der Abschnitt rechts bleibt.
- Prüfung: Wenn du auf der Seite Karte oben links neben der Ansicht "Einstellungen" klickst, dann zeigen die Einstellungen nur "Karte und Wegpunkt", oben "Zurück zu Karte"; der Knopf bringt dich zur Karte zurück.
- Prüfung: Wenn du in einem Abschnitt etwas änderst und oben "Zurücksetzen" klickst, dann fragt Amisia nach und setzt nur diesen Abschnitt auf den Standard; der Abschnitt trägt vorher in der Liste den goldenen Punkt.
- Prüfung: Wenn du unter Allgemein, Oberfläche "Alle Einstellungen zurücksetzen" klickst und bestätigst, dann meldet der Chat "N Einstellungen auf den Standard gesetzt.", und deine Raids und Listen sind noch da.
- Prüfung: Wenn du als Raider (Ansicht "Raider") die Einstellungen öffnest, dann fehlen die Offiziersabschnitte, und auf einer Seite ohne eigene Einstellungen (z. B. Talente) fehlt der Knopf; die Einstellungen der Seite Rolls zeigen auch Raidern "Wer braucht das?" und "Loot-Prio".
- Notiz: Spec `docs/specs/2026-10-13-dungeons-einstellungen.md`, Teil B, D-49.

## Addon: Raid und Loot

### F-013 Raid-Aufnahme (Anwesenheit, Bosse, Loot)
- Version: 2.57.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du mit einer Raidgruppe eine Raidinstanz betrittst, dann meldet der Chat "Aufnahme gestartet: <Zone>. /amisia zeigt die Liste.", und `/amisia status` nennt Zone und Zahl der Raider.
- Prüfung: Wenn du `/amisia pause` eingibst, dann meldet der Chat "Aufnahme pausiert."; noch einmal: "Aufnahme aktiv.".
- Prüfung: Wenn der Raid vorbei ist, dann steht er auf der Seite Raid-Archiv mit Datum, Raidern, Bossen und dem blauen und epischen Loot.
- Prüfung: Wenn du als Offizier auf der Seite Raid-Archiv nichts angekreuzt hast, dann ist "Löschen (0)" ausgegraut; "Alle wählen" kreuzt alle Raids an und heißt danach "Keine wählen".

### F-014 Zu-spät-Markierung
- Version: 1.2.3
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du `/amisia spaet 20:00` eingibst, dann meldet der Chat "Raidbeginn 20:00 ...", und unter Einstellungen, Aufnahme steht "Raidbeginn (zu spät ab)" auf 20:00.
- Prüfung: Wenn jemand nach 20:00 zum ersten Mal in den Raid kommt, dann zeigt die Seite Raid-Archiv "1 zu spät"; wer von der Ersatzbank kommt, ist nie zu spät.
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
- Version: 2.57.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier nach dem Raid die Seite Export öffnest, dann steht dort "1 Raid(s) neu oder geändert" und ein Text, der mit `#AMISIA 2` beginnt.
- Prüfung: Wenn du den Text (Strg+A, Strg+C) auf der Website im Reiter Import einfügst, dann zeigt die Vorschau Raider, Bosse und Vergaben des Abends.
- Prüfung: Wenn du danach noch einmal exportierst, dann steht "Nichts Neues seit dem letzten Export ...".
- Prüfung: Wenn als Offizier eine Aufnahme endet und ein Raid noch nicht exportiert ist, dann meldet der Chat "1 Raid ist noch nicht auf der Website. Seite Export oder /amisia export." (abschaltbar unter Aufnahme, "An nicht exportierte Raids erinnern").
- Prüfung: Wenn du die Seite Export (Reiter Raid, neben Raid-Archiv) öffnest, bevor du exportiert hast, dann steht im Feld "Noch kein Exporttext" mit einer Erklärung, und der Knopf zeigt "Angekreuzte (N)" mit der Zahl der im Raid-Archiv angekreuzten Raids.

### F-018 Loot-Ansage durch die Lootleitung
- Version: 1.6.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Plündermeister eine Boss-Leiche öffnest, dann sagt Amisia die Items einmal im Raidchat an; Materialien werden nie angesagt.
- Prüfung: Wenn zwei Offiziere Amisia haben, dann sagt nur die Lootleitung an, nicht beide.
- Prüfung: Wenn du `/amisia ansage` eingibst, dann wird das offene Lootfenster noch einmal angesagt.

### F-019 Soft-Reserves
- Version: 2.62.1
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du auf der Seite Soft-Reserves eine softres.it-CSV einfügst und "Importieren" klickst, dann steht dort "N Reservierungen, vom <Datum>", und "Prüfen" zeigt, wer nicht im Raid oder ohne Reserve ist.
- Prüfung: Wenn ein Raider `!sr` flüstert, dann antwortet die Lootleitung per Flüstern mit seinen Reservierungen.
- Prüfung: Wenn du "Erinnern" klickst, dann bekommt jeder im Raid ohne Reservierung nach einer Rückfrage einmal ein Flüstern.
- Prüfung: Wenn ein Raider von einem verbundenen Realm `!sr <Item>` flüstert, dann steht seine Reservierung auf der Seite Soft-Reserves (vorher verworfen, wenn das Spiel den Namen mit "-Realm" schrieb).
- Prüfung: Wenn du auf TBC Anniversary oder Classic Era im Raid ein Lootfenster mit einem reservierten Item öffnest, dann trägt dessen Knopf die SR- oder HR-Markierung wie auf Forever.
- Notiz: 2.25.2 (2026-10-11): die heutige softres.it-CSV hat den Namen in "Raider Name"; vorher kamen 0 Reservierungen an.
- Notiz: Den Code von softres.it (Knopf "Gargul") liest F-091 (2.26.0).
- Notiz: 2.62.1 (2026-11-07, Code-Audit): SR/HR-Markierungen auch an den klassischen Lootknöpfen (TBC, Era).

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
- Version: 2.57.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn ein Gildenmitglied der Lootleitung `!bench` flüstert, dann antwortet sie "Amisia: Du stehst auf der Ersatzbank (...)", und es steht auf dem Raid-Log unter Ersatzbank.
- Prüfung: Wenn du als Offizier `/amisia ersatz <Name>` eingibst, dann steht der Spieler auf der Ersatzbank; `/amisia ersatz weg <Name>` trägt ihn aus.
- Prüfung: Wenn ein Raider von einem verbundenen Realm `!bench` flüstert, dann steht er auf der Ersatzbank.

### F-024 Discord-Text des Raids
- Version: 1.7.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier nach dem Raid `/amisia discord` eingibst (oder "Discord-Text" im Raid-Log), dann öffnet sich ein Text mit Bossen, Raidern, Ersatzbank, Verspätungen und Vergaben zum Kopieren.
- Prüfung: Wenn du ihn in Discord einfügst, dann pingt er niemanden (keine @-Erwähnung wird ausgelöst).

### F-025 Raid-Abgleich zwischen Offizieren (Hüter)
- Version: 2.62.1
- Status: gebaut
- Braucht: Gilde, Raid
- Prüfung: Wenn zwei Offiziere mit Amisia im selben Raid sind und die Lootleitung etwas vergibt, dann steht die Vergabe nach wenigen Sekunden auch beim anderen auf der Seite Vergaben.
- Prüfung: Wenn der andere Offizier eine Vergabe ändert, dann geht die Änderung an den Hüter und kommt bei beiden gleich an; `/amisia sync` zeigt den gleichen Stand.
- Prüfung: Wenn jemand außerhalb der Gilde Amisia-Nachrichten schickt, dann ändert das nichts.
- Prüfung: Wenn ein Offizier in der Raider-Ansicht ist, während die Lootleitung eine Notiz an eine Vergabe schreibt, und danach zur Offiziersansicht wechselt, dann sieht er die Notiz nach wenigen Sekunden; übernimmt er später die Lootleitung, bleiben die Notizen bei allen erhalten.
- Notiz: 2.62.1 (2026-11-07, Code-Audit): ein Offizier in der Raider-Ansicht löschte über den Abgleich Notizen, Erstgewinner und "von Hand" für den ganzen Raid (D-18 Nachtrag).

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
- Prüfung: Wenn ein Twink im Raid ist, dann steht er auf der Seite Raid-Archiv als "(Twink von <Main>)", und Plus-Eins und Statistik zählen für den Main.

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
- Version: 2.57.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn die Website (Reiter Points) DKP oder EPGP einstellt und du "Copy for the addon" auf der Seite Punkte bei "Einfügen" einfügst, dann zeigt die Seite Punkte den Stand jedes Spielers und "Website vom <Datum>".
- Prüfung: Wenn du `/amisia punkte` eingibst, dann nennt der Chat deinen Punktestand; flüstert dir ein Raider von einem verbundenen Realm `!dkp`, dann antwortet Amisia ihm mit seinen Punkten.
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
- Version: 2.62.1
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn du unter Lootregeln "An Offiziere senden" klickst, dann sieht ein anderer Offizier mit Amisia "Neue Lootregeln von <Name> (N Regeln): ..." und unter Einstellungen, Lootregeln "Neue Lootregeln von <Name>: N neu, M geändert, K entfernt" mit "Übernehmen" und "Ablehnen"; seine eigenen Regeln bleiben, bis er "Übernehmen" klickt.
- Prüfung: Wenn ein Offizier sich nach dem Senden erst einloggt, dann bekommt er den Vorschlag etwa eine Minute nach dem Login.
- Prüfung: Wenn ein Raider ohne Offiziersrang Regeln sendet (z. B. mit einem veränderten Addon), dann erscheint bei niemandem ein Vorschlag.
- Prüfung: Wenn du so viele Regeln anlegst, dass der Satz nicht mehr in die Nachricht an die Offiziere passt, dann lehnt Amisia die neue Regel gleich beim Anlegen mit einer Meldung ab, statt erst beim Senden zu scheitern.
- Notiz: 2.62.1 (2026-11-07, Code-Audit): Regelsätze über 4 Nachrichtenteile werden beim Anlegen abgelehnt.

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
- Version: 2.58.0
- Status: gebaut
- Prüfung: Wenn du als Vulo Pala (Kalenderfenster zu, nicht im Kampf) im Fenster "Raid-Anmeldung" bei Vulo Hunts Ereignis mit Anmeldung "Anmelden" klickst, dann sagt der Chat "Raid-Anmeldung: ... angemeldet als ... Gesendet." und wenige Sekunden später "Spielkalender: angemeldet.", und im Kalenderfenster des Spiels steht Vulo Pala bei diesem Ereignis "Angemeldet"; im Fenster steht kein Hinweis "Bitte auch im Kalender eintragen.".
- Prüfung: Wenn du danach "Vorläufig" klickst, dann sagt der Chat "Spielkalender: vorläufig." und das Kalenderfenster zeigt "Vorläufig"; nach "Abmelden" sagt er "Spielkalender: entfernt." und Vulo Pala steht im Kalender nicht mehr angemeldet.
- Prüfung: Wenn du `/amisia anmelden h` eingibst, dann trägt derselbe Befehl dich auch im Kalender ein ("Spielkalender: angemeldet."); bei Vulo Hunts eigenem Ereignis sagt der Chat stattdessen "Spielkalender: du hast das Ereignis angelegt, dort bleibt dein Stand.".
- Prüfung: Wenn das Kalenderfenster des Spiels offen ist (oder du im Kampf bist) und du "Anmelden" klickst, dann sagt der Chat "Spielkalender: nicht eingetragen (Das Kalenderfenster des Spiels ist offen.) Bitte auch im Kalender eintragen.", und das Fenster zeigt "Bitte auch im Kalender eintragen." mit "Warum?" (Tooltip und Klick: der Grund und der Kalenderknopf an der Minimap). Ebenso ohne Kalender-Eintrag, aber mit dem Hinweis: mit "Auch im Spielkalender eintragen" (Einstellungen, "Raid-Anmeldung") aus.
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
- Version: 2.57.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn ein Gildenmitglied mit Offiziersrang als Plündermeister (ohne Master Loot: als Leiter) mit Gargul eine Runde startet ("You have 20 seconds to roll on [Item]" oder "Du hast 20 Sekunden um auf [Item] zu würfeln"), dann öffnet sich bei dir das Würfel-Fenster mit dem Item und oben "Runde von <Name> (Gargul)"; "Mainspec" würfelt 1-100, "Offspec" 1-99, "Passen" schließt nur.
- Prüfung: Wenn du selbst als Plündermeister in der Offiziersansicht mit Gargul eine Runde startest, dann öffnet sich Amisias Roll-Fenster mit dem Hinweis "Gargul-Runde: Gargul sagt den Gewinner an.", zeigt die Würfe der anderen, und Amisia schreibt nichts in den Chat; bei Gargul's "Stop your rolls!" endet die Runde, und "Ergebnis ansagen" bleibt aus.
- Prüfung: Wenn ein Raider ohne Leiter- oder Plündermeister-Rolle (oder ohne Offiziersrang) eine Gargul-Runde startet, dann öffnet sich bei dir kein Fenster.
- Prüfung: Wenn eine Amisia-Runde läuft und die Lootleitung dazu mit Gargul ein anderes Item startet, dann bleibt die Amisia-Runde, und der Chat der Lootleitung sagt "Gargul-Runde von <Name> auf [Item] erkannt, während eine Amisia-Runde läuft."
- Prüfung: Wenn in einer 5er-Gruppe (nicht im Raid) der Gruppenleiter mit einem anderen Loot-Addon eine Würfelrunde startet, dann öffnet sich das Würfel-Fenster.
- Notiz: Spec Teil B1 ("wer startet, entscheidet"); DECISIONS D-44. Du hast Gargul selbst installiert: in einer Gruppe mit einem Gildenmitglied, das Amisia hat, kannst du mit Gargul starten und beide Seiten prüfen. Einstellungen: Rolls und Vergabe, "Runden anderer Loot-Addons erkennen" (an); Würfel-Fenster, "Fenster auch bei Runden anderer Loot-Addons" (an). Amisia liest nur Gargul's Chatzeilen (Englisch und Deutsch) und sendet nichts an Gargul; im Bosskampf sind die Zeilen geheim, dann gibt es kein Fenster.

### F-093 Rundenansage auch auf Englisch
- Version: 2.26.0
- Status: gebaut
- Braucht: Gruppe
- Prüfung: Wenn du unter Einstellungen, Rolls und Vergabe "Rundenansage auch auf Englisch" einschaltest und in einer Gruppe als Lootleitung eine Runde startest, dann steht nach "Roll auf [Item]: /roll für Mainspec, /roll 99 für Offspec. 20 Sekunden." die Zeile "Roll on [Item]: /roll for main spec, /roll 99 for off spec. 20 seconds." (mit "Reserved by ..." bei reservierten Items).
- Prüfung: Wenn die Einstellung aus ist (Standard), dann kommt nur die deutsche Ansage.
- Notiz: Spec Teil B4; DECISIONS D-44. Für Raider mit Gargul oder englischem Client: sie würfeln mit `/roll` (MS) und `/roll 99` (OS), genau Gargul's Standardbereiche. Ein englischer Client sagt ohnehin Englisch an und schreibt keine zweite Zeile.

### F-107 Soft-Reserves mit der Gruppe teilen
- Version: 2.41.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn du als Offizier (Vulo Hunt) im Raid mit einem Gildenmitglied, das Amisia hat, eine Liste übernimmst, dann sagt die Ergebniszeile "… übernommen, … Mit der Gruppe geteilt.", und bei ihm zeigt nach höchstens 30 s die Seite Soft-Reserves "Liste vom … von Vulo Hunt" und der Tooltip eines reservierten Items "Reserviert: …".
- Prüfung: Wenn das Gildenmitglied erst danach in den Raid kommt (oder `/reload` macht), dann hat es die Liste nach höchstens 60 s.
- Prüfung: Wenn du danach "Löschen" klickst, dann ist die Liste beim Gildenmitglied nach höchstens 20 s weg.
- Prüfung: Wenn das Gildenmitglied ein Offizier mit eigener, älterer Liste ist, dann behält es seine Liste, bekommt die Chatzeile "Soft-Reserves: Vulo Hunt hat eine neuere Liste geteilt …" und auf der Seite "Neuere Liste von Vulo Hunt (…)" mit dem Knopf "Liste übernehmen".
- Notiz: Spec docs/specs/2026-10-17-softres-teilen-vorschau.md, Teil A; DECISIONS D-53. Nachrichten SV/SQ und Blob SR; geteilt wird nur im Raid, angenommen nur von Offizieren der eigenen Gilde. Einstellung Soft-Reserves "Liste mit dem Raid teilen" (an). Neue Dateien: nach dem Release WoW ganz neu starten.

### F-108 Soft-Reserves: Vorschau im Import-Fenster und Hard-Reserve-Ansage
- Version: 2.41.0
- Status: gebaut
- Prüfung: Wenn du in der Offiziersansicht auf der Seite Soft-Reserves "Importieren" klickst und den Beispielcode `eNpljzFPxDAMhf+L5wxNVdoj27EwggSIAXVwa1dEpMnJSVmq/ncSDkErMsXv6X1+XmHmhIQJwaxgCQzgoOuRQMEojInpnMDo7la3N1V+CpYLHWX9LQtaekooKf46bd0U590SsQczoYusgGwcg9CLuLwMNgUxTEk4snxyBPO2gseZs3f2HksNhzHr8CiWY8qCD6nY+XdxS3zwJZXX2MTzNV/O0KeTbja1H/oy/rDvwrBDv6KIDfLHfkb/ceDrf/yu6tqM7PN9KHTof/XrqlEwZaqBe+uId81Lagh+iRKcK5l++wJJR3km` einfügst, dann steht nach einem Moment unter dem Textfeld "Gargul-Code erkannt: 3 Reservierungen, 1 Hard-Reserve …", darunter der Kasten "Im Raid ohne Reserve" (ohne Raid und ohne aufgezeichneten Raid: "Kein Raid zum Abgleichen.") und die Liste "Vorschau" mit "2 Raider": oben rot umrandet "Hard-Reserves" mit einem Item-Symbol und "für Gilde", darunter Anna mit einem Symbol mit "2x" und Bob mit einem Symbol.
- Prüfung: Wenn du mit der Maus auf ein Item-Symbol gehst, dann zeigt der Tooltip das Item (beim Hard-Reserve dazu "Hard-Reserve für Gilde"), und Shift-Klick setzt den Link in die Chatzeile.
- Prüfung: Wenn du das Textfeld leerst und "Übernehmen" klickst, dann steht unten "Nichts eingefügt. Die geladene Liste bleibt; "Leeren" löscht sie.", und die geladene Liste bleibt.
- Notiz: Braucht: Raid (ab 2026-11-04, D-32): Wenn du im Raid eine Liste einfügst, dann stehen im Kasten "Im Raid ohne Reserve · N" die Raidmitglieder ohne Reserve in Klassenfarbe, und "Erinnern (N)"/"Im Raid posten" gehen erst nach "Übernehmen". Wenn du im Raid übernimmst, dann stehen im Raidchat "Soft-Reserves geladen: N Reservierungen von M Raidern. '!sr' an … flüstern zeigt deine." und, mit Hard-Reserves, "Hard-Reserves: [Item] für …"; der Chip "Ansagen" in der Hard-Reserve-Zeile sagt es noch einmal.
- Notiz: Spec docs/specs/2026-10-17-softres-teilen-vorschau.md, Teil B; DECISIONS D-53. Fenster jetzt UI/SoftResImport.lua (560 × 614). Einstellung Soft-Reserves "Beim Übernehmen im Raid ansagen" (an); Englisch dazu mit "Rundenansage auch auf Englisch".

### F-109 Soft-Reserves: Klassen-Abgleich
- Version: 2.41.0
- Status: gebaut
- Braucht: Raid
- Prüfung: Wenn auf softres.it bei einem Raider eine andere Klasse steht als im Raid, dann steht in der Vorschau des Import-Fensters orange "Klasse: softres <Klasse>, im Raid <Klasse>", in der Ansicht "Abgleich" der Seite die Zeile "Klasse: <Name>" mit "Klasse passt nicht: …" und in der Zeile darüber "1 Klasse falsch".
- Prüfung: Wenn ein Name auf softres.it einen Tippfehler hat, dann steht bei ihm "Name unklar, gemeint:" mit einem Vorschlag; ein Raidmitglied der Klasse von softres.it steht dabei vorne.
- Notiz: Spec docs/specs/2026-10-17-softres-teilen-vorschau.md, Teil C. Die Klasse kommt aus dem Gargul-Code oder der CSV-Spalte "Raider Class"; ein Hinweis, nichts wird gesperrt.

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
- Notiz: 2.57.0: Chip "Gilde (N)" mit Anzahl, ausgegraut und erklärt, solange niemand aus der Gilde teilt.

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

### F-133 Berufe aus Gildennotizen
- Version: 2.53.0
- Status: gebaut
- Braucht: Gilde
- Prüfung: Wenn ein Gildenmitglied ohne Amisia "Alchi 300 / Kräuter" in der Gildennotiz (oder der Offiziersnotiz) stehen hat, dann zeigt seine Zeile unter Gilde, Mitglieder die Kästchen Alchimie mit 300 und Kräuterkunde ohne Zahl.
- Prüfung: Wenn du mit der Maus auf so ein Kästchen gehst, dann steht dort "Alchimie 300, laut Gildennotiz" und "Aus der Gildennotiz; Amisia weiß nur, was dort steht."
- Prüfung: Wenn du im Dropdown Beruf "Alchimie" wählst, dann bleibt dieses Mitglied stehen; die Zahl "mit Amisia" unten zählt es nicht mit.
- Notiz: Wunsch des Nutzers 2026-11-05 ("Ja, Notizen lesen"), nachdem `/amisia hersteller` "0 aus der Gilde" meldete: niemand sonst in der Gilde hat Amisia. Liest deutsche und englische Namen und Kürzel (BS, VZ, LW, Ingi, EH, BB ...); der Rezept-Austausch geht vor, die Notiz ergänzt nur fehlende Berufe; keine Rezepte, keine neue Nachricht, kein neuer Schlüssel.

### F-106 Duelle: Verlauf, Rangliste, Klassen
- Version: 2.58.0
- Status: gebaut
- Prüfung: Wenn du ein Duell gewinnst oder verlierst, dann steht es im Reiter PvP auf der Seite Duelle im Verlauf mit Zeit, beiden Namen in Klassenfarbe mit Klasse, "Sieg" und dem Ort.
- Prüfung: Wenn zwei andere in deiner Nähe ein Duell beenden, dann steht auch ihr Duell im Verlauf.
- Prüfung: Wenn jemand aus einem Duell flieht (Abstand), dann steht es als "Flucht" mit ihm als Verlierer.
- Prüfung: Wenn ein Spieler "unbekannt" ist und du "Klassen suchen" klickst, dann sagt der Chat "Duelle: /who ... brachte N Klassen", seine Klasse steht danach in allen seinen Duellen (sofern /who ihn findet) und die Zahl auf dem Knopf sinkt. Öffnet das Spiel mit der Antwort seine /who-Liste, bleibt sie offen (Amisia schließt keine Fenster des Spiels), und auch danach kommt im Kampf kein "BLOCKIERT: Amisia".
- Prüfung: Wenn du die Ansicht Klassen öffnest, dann siehst du je Klasse Spiele, Spieler, S-N und Siegrate und unten, wie viel Prozent der Klassen bekannt sind; ein Klick auf eine Klasse zeigt sie gegen jede andere.
- Notiz: Spec `docs/specs/2026-10-16-duelle.md`; DECISIONS D-52. Nichts wird gesendet; Duelle der Gilde teilen wäre ein eigenes Feature.

### F-131 Duelle löschen
- Version: 2.50.1
- Status: im Spiel geprüft (2026-11-05)
- Prüfung: Wenn du `/amisia duelle leeren` eingibst (oder in den Einstellungen, Duelle "Alle Duelle löschen" klickst), dann fragt Amisia nach; nach "Löschen" meldet der Chat "N Duelle gelöscht.", Verlauf und Rangliste sind leer, und neue Duelle zählen wieder von vorn.
- Prüfung: Wenn du danach die Ansicht Klassen öffnest oder einem früheren Gegner neu begegnest, dann kennt Amisia seine Klasse noch (die bekannten Klassen bleiben).
- Notiz: Wunsch des Nutzers 2026-11-05 ("können wir die liste resetten", Bildschirmfoto der Rangliste mit 396 Spielern); Knopf in den Einstellungen, Duelle, und `/amisia duelle leeren`.

### F-114 Duelle: Klassensymbol und Spezialisierung
- Version: 2.42.0
- Status: gebaut
- Prüfung: Wenn du die Seite Duelle öffnest, dann steht vor jedem Namen mit bekannter Klasse das runde Klassensymbol und darunter "Klasse · Spezialisierung" (z. B. "Jäger · Treffsicherheit"), sobald die Spezialisierung bekannt ist; deine eigene sofort.
- Prüfung: Wenn ein Duell in deiner Nähe endet und ein Duellant dein Ziel ist oder seine Namensplakette zu sehen ist, dann steht nach ein paar Sekunden seine Spezialisierung in allen seinen Duellen, ohne dass ein Fenster aufgeht.
- Prüfung: Wenn dein Betrachten-Fenster offen ist oder du im Kampf bist, dann betrachtet Amisia niemanden; danach schon.
- Prüfung: Wenn du mit der Maus über einen Namen fährst, dann zeigt der Tooltip Klasse, Spezialisierung, seine Bilanz und "Gegen dich: S - N".
- Prüfung: Wenn du in der Ansicht Klassen über eine Klasse fährst, dann zeigt der Tooltip je Spezialisierung Duelle, S - N und Siegrate.
- Notiz: Spec `docs/specs/2026-10-16-duelle.md` (Entscheidungen, 2026-10-17); DECISIONS D-52 Nachtrag. Im Spiel offen: ob Forever das Betrachten der Talente (Inspect-Konfiguration) liefert.

### F-116 Duelle: Karte bei einer Duell-Anfrage
- Version: 2.42.0
- Status: gebaut
- Prüfung: Wenn dich jemand zum Duell fordert, dann steht unter dem Anfrage-Fenster eine Karte "Amisia · Duell-Anfrage" mit seinem Namen in Klassenfarbe, Klasse und Spezialisierung, seiner Bilanz, "Du gegen ihn: S - N" und seiner Serie (oder "Noch kein Duell von ihm aufgezeichnet.").
- Prüfung: Wenn du die Anfrage annimmst oder ablehnst, dann verschwindet die Karte mit dem Fenster.
- Notiz: Einstellung Duelle "Bilanz bei Duell-Anfragen zeigen" (an). Neue Datei UI/DuelInfo.lua: nach dem Release WoW ganz neu starten.

### F-117 Duelle: Bilanz im Spieler-Tooltip
- Version: 2.42.0
- Status: gebaut
- Prüfung: Wenn du mit der Maus über einen Spieler fährst, gegen den Duelle aufgezeichnet sind, dann steht im Tooltip "Duelle: S - N (Prozent)", bei eigenen Duellen gegen ihn "du S - N", ab zwei Siegen oder Niederlagen in Folge die Serie.
- Notiz: Einstellung Duelle "Duell-Bilanz im Spieler-Tooltip" (an).

### F-118 Duelle: Serien, Erzfeind, Lieblingsgegner
- Version: 2.42.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Duelle mit der Maus über einen Namen fährst, dann zeigt der Tooltip seine Bilanz, "Du gegen ihn", die Serie ("3 Siege in Folge"), die beste Serie sowie Erzfeind und Lieblingsgegner mit S - N.
- Prüfung: Wenn du auf einen Namen klickst, dann steht unten neben seiner Bilanz seine aktuelle Serie.

### F-119 Duelle: Zeitraum
- Version: 2.42.0
- Status: gebaut
- Prüfung: Wenn du im Auswahlfeld neben der Klasse "Heute" wählst, dann zeigen Verlauf, Rangliste und Klassen nur die Duelle seit Mitternacht; "Letzte 7 Tage" und "Letzte 30 Tage" entsprechend, "Alle Zeiten" wieder alle.

### F-120 Duelle: Klassen nach Spezialisierung
- Version: 2.42.0
- Status: gebaut
- Prüfung: Wenn du in der Ansicht Klassen "Nach Spezialisierung" einschaltest, dann steht jede Klasse je Spezialisierung in einer eigenen Zeile (z. B. "1. Jäger · Treffsicherheit") und unten "… Spezialisierungen bekannt".

## Addon: Ausrüstung und Welt

### F-038 Ausrüstungstabelle
- Version: 2.30.1
- Status: gebaut
- Prüfung: Wenn du unter Einstellungen "Upgrade erst ab (Prozent mehr Leistung)" auf 2 stellst, dann verschwinden in deiner Spalte der Tabelle die Upgrade-Punkte der kleinen Verbesserungen, genau wie ihr "Upgrade für dich" im Tooltip.
- Prüfung: Wenn du `/amisia gear` eingibst (oder auf der Seite Ausrüstung "Tabelle"), dann öffnet sich die Ausrüstungstabelle mit den besten Items aller Levelbereiche für jede Spezialisierung.
- Prüfung: Wenn du deine eigene Spalte ansiehst, dann plant sie für deine Stufe, nicht für das obere Ende des Levelbereichs.

### F-039 Ziele: beste Ausrüstung mit eigener Wertung
- Version: 2.57.0
- Status: gebaut
- Prüfung: Wenn du `/amisia bis` eingibst, dann öffnet sich die Seite Ausrüstung bei Ziele mit dem besten Item je Slot für deine Spezialisierung und Stufe, mit Quelle und Zuwachs gegen das Angelegte.
- Prüfung: Wenn du "Warum?" bei einem Item klickst, dann erklärt Amisia die Wertung; "Warum diese Gewichte" zeigt die Gewichte deiner Spezialisierung.
- Prüfung: Wenn du bei einem Item "Ausschließen" klickst, dann rückt die nächste Option auf; "zurücksetzen" hebt alle Ausschlüsse auf.
- Prüfung: Wenn du `/amisia bis plan 2h` (oder `dw`, `schild`) eingibst, dann plant die Seite die Waffen entsprechend.
- Prüfung: Wenn du über ein Item fährst, das der Client noch nicht geladen hat, dann steht im Tooltip nicht "der Server beschreibt dieses Item nicht", sondern nach kurzem Laden der normale Text.

### F-040 Hier: was es an diesem Ort für dich gibt
- Version: 2.5.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Ausrüstung "Hier" wählst, dann zeigt sie, was du in deiner Zone oder Instanz noch holen kannst (Upgrades und Wünsche, Besitz unten).
- Prüfung: Wenn du `/amisia bis hier` in einem Dungeon eingibst, dann zeigt die Liste die Upgrades dieses Dungeons.

### F-041 Upgrade-Prozent im Tooltip
- Version: 2.4.0
- Status: gebaut
- Prüfung: Wenn du mit der Maus über ein Item fährst, das für dich besser ist, dann steht im Tooltip "Upgrade für dich (Spezialisierung): +x,x % Schaden (Slot)" (seit 2.43 Prozent der ganzen Leistung, F-115).
- Prüfung: Wenn unter Einstellungen, Ausrüstung und Wünsche "Auch \"Kein Upgrade\" im Tooltip zeigen" an ist, dann steht bei schlechteren Items "Kein Upgrade für dich (Spezialisierung): -x,x % ...".
- Prüfung: Wenn eine Questbelohnung ein Upgrade ist, dann ist sie im Questfenster markiert.

### F-115 Genaues Upgrade für deine Spezialisierung
- Version: 2.43.0
- Status: gebaut
- Prüfung: Wenn du als Verstärkungs-Schamane über einen Umhang mit +5 Stärke, +5 Intelligenz, +5 Willenskraft fährst und einen Umhang ohne Werte trägst, dann steht "Upgrade für dich (Verstärkung): +x,x % Schaden (Rücken)" mit einer kleinen Zahl, nicht über 100 %.
- Prüfung: Wenn du Shift hältst, dann zeigt der Tooltip die Zerlegung, "Slot: +N %" und eine Zeile mit den anderen Spezialisierungen deiner Klasse.
- Prüfung: Wenn deine Trefferchance schon an der Grenze ist, dann bringt ein Item mit nur Trefferwertung 0 % und steht nicht als Upgrade da.
- Prüfung: Wenn du im Kampf über ein Item fährst, dann rechnet Amisia mit dem Stand von vor dem Kampf und zeigt keinen Fehler.
- Prüfung: Wenn du auf der Seite Ausrüstung, Ziele mit der Maus über die Erklärzeile unter der Slot-Liste fährst (oder `/amisia bis warum <Item-Link>` eingibst), dann stehen dort "Gesamt: +x,x % ..." mit deinen Ausgangswerten (z. B. Angriffskraft, Krit, Treffer) und was sich durch den Tausch ändert.
- Notiz: Spec `docs/specs/2026-10-17-upgrade-genau.md`; DECISIONS D-54. Im Spiel offen: ob `UnitStat`s posBuff auf Forever die Ausrüstung enthält (sonst bleibt der Prozent-Faktor für Talente bei 1) und ob Forever-Tooltips die Verzauberung als "Verzaubert: ..." schreiben (sonst fehlt die Shift-Zeile dazu).

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

### F-110 Fenster "Ausrüstungsziele" mit Puppe
- Version: 2.49.2
- Status: gebaut
- Prüfung: Wenn du auf der Seite Ausrüstung, Ziele "Ausrüstungsziele" klickst (oder `/amisia bis gross` eingibst), dann öffnet sich das Fenster "Ausrüstungsziele" mit deinem Charaktermodell, den 17 Slots links, rechts und darunter, der Liste in der Mitte und rechts der Leiste des ersten Slots mit Upgrade.
- Prüfung: Wenn du "Angelegt" wählst, dann tragen Modell und Slots deine jetzige Ausrüstung; mit "Ziele" die Ziele. Ziehen dreht, Mausrad zoomt, Rechtsklick setzt zurück.
- Prüfung: Wenn du `/amisia selbsttest` eingibst, dann steht dort eine Zeile "Charaktermodell" (DressUpModel, SetUnit, Undress, TryOn: vorhanden oder was fehlt).
- Prüfung: Wenn das Fenster offen ist und Items nachgeladen werden (Namen erscheinen nach und nach, ein Scan läuft oder du fährst über Items in den Taschen), dann bleibt das Charaktermodell ruhig stehen und flackert nicht; nur wenn ein Item der Puppe seinen Namen bekommt, zieht es sich einmal neu an.
- Prüfung: Wenn deine angelegten Items fast nichts wert sind (niedrige Stufe, Startausrüstung), dann steht bei einem viel besseren Ziel ">999 %" statt einer abgeschnittenen Zahl wie "+9070...".
- Notiz: Spec docs/specs/2026-10-17-ziele-fenster.md, Teil A. Offen im Spiel: ob Forevers DressUpModel SetUnit/Undress/TryOn hat (Selbsttest-Zeile "Charaktermodell"), ob TryOn die Hand (MAINHANDSLOT/SECONDARYHANDSLOT/RANGEDSLOT) annimmt, die leeren Slot-Bilder und der Stern-Atlas.
- Notiz: 2.49.2: Bildschirmfoto des Nutzers 2026-11-05 ("warum flakert der Charmodel"): jede Item-Antwort (GET_ITEM_INFO_RECEIVED) zog das Modell neu an (SetUnit, Undress, TryOn), und eine fehlgeschlagene Antwort fragte beim nächsten Refresh wieder; jetzt nur neu, wenn sich ein Link der Puppe ändert. Prozent über 999 gekürzt.
- Notiz: seit 2.65.0 im Ausrüstungsplaner (D-80): das Fenster gibt es nicht mehr.

### F-111 Ausrüstungsziele: Wertungs-Kopf
- Version: 2.44.0
- Status: gebaut
- Prüfung: Wenn du im Fenster eine eigene Wahl triffst, dann ändern sich "Wertung", "+N" und die Wertänderungen unter der Puppe; der Balken endet bei "Bestes auf Stufe N", das sich durch deine Wahl nicht ändert.
- Notiz: Spec docs/specs/2026-10-17-ziele-fenster.md, Teil B.
- Notiz: seit 2.65.0 im Ausrüstungsplaner (D-80): das Fenster gibt es nicht mehr.

### F-112 Ausrüstungsziele: Slot-Leiste und eigene Wahl
- Version: 2.44.0
- Status: gebaut
- Prüfung: Wenn du ein Item der Rangliste anklickst, dann trägt es den Stern, ist in der Liste, auf der Seite Ziele und als Pin auf der Weltkarte das Ziel dieses Slots, und nach `/reload` noch immer; ein zweiter Klick (oder das rote X unter "Deine Wahl") nimmt die Wahl weg.
- Prüfung: Wenn du einen Item-Link in das Feld der Leiste ziehst, der nicht in den Slot passt, dann sagt die Zeile darunter "Passt nicht in Kopf." und nichts ändert sich.
- Notiz: Spec docs/specs/2026-10-17-ziele-fenster.md, Teil C.
- Notiz: seit 2.65.0 im Ausrüstungsplaner (D-80): das Fenster gibt es nicht mehr.

### F-113 Ausrüstungsziele: Fortschritt und Filter
- Version: 2.44.0
- Status: gebaut
- Prüfung: Wenn du "Zu holen" wählst, dann zeigt die Liste nur Slots mit Ziel, das du nicht hast, der Chip sagt die Zahl; "Ohne Verzauberung" zeigt die angelegten Items in verzauberbaren Slots ohne Verzauberung.
- Notiz: Spec docs/specs/2026-10-17-ziele-fenster.md, Teil D.
- Notiz: seit 2.65.0 im Ausrüstungsplaner (D-80): das Fenster gibt es nicht mehr.

### F-124 Spielstil-Filter für die Ziele
- Version: 2.46.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Ausrüstung, Ziele "Spielstil" und dann "Keine Dungeons" anhakst, dann steht keine Quelle aus einem Dungeon oder Raid (auch kein "Trash (...)" und keine Quest aus einem Dungeon) mehr da, und der Knopf heißt "Spielstil (1)".
- Prüfung: Wenn du "Kaufbar" anhakst, dann bleiben nur Händlerware und Items, die beim Anlegen binden; bei einem solchen Drop steht als Quelle "Auktionshaus (bindet beim Anlegen)".
- Prüfung: Wenn ein Spielstil an ist und du mit der Maus über den Knopf "Spielstil (N)" fährst, dann listet der Tooltip unter "Spielstil blendet N Ziele aus:" die ausgeblendeten Items mit Grund (z. B. "Keine Dungeons" oder "Ruf: <Fraktion>, <Stufe> (du: <Stufe>)").
- Prüfung: Wenn "Fokus-Zone" an ist und du die Zone wechselst, dann zeigt die Liste nach einigen Sekunden nur Quellen der neuen Zone, Dungeons mit Eingang dort eingeschlossen; die Karten-Pins folgen.
- Prüfung: Wenn du `/amisia spielstil kaufbar` eingibst, dann meldet der Chat "Spielstil: Kaufbar."; `/amisia spielstil aus` schaltet alles ab.
- Notiz: Spec `docs/specs/2026-10-24-spielstil-slotklick.md` (freigegeben 2026-10-24); DECISIONS D-56. Ruf aus ItemSparse deckt erst 19 Items der Ausrüstungsdaten ab; Gruppenquests lernt Amisia aus dem eigenen Questlog (`AmisiaDB.questtags`) und übernimmt sie beim nächsten `build.py data`. Im Spiel offen: ob Forever `C_QuestLog.GetQuestTagInfo` und `C_Reputation.GetFactionDataByID` wie dokumentiert beantwortet.

### F-125 Rechtsklick auf den Charakter-Slot
- Version: 2.46.0
- Status: gebaut
- Prüfung: Wenn du im Charakterfenster mit rechts auf einen Slot (z. B. Hände) klickst, dann öffnet sich daneben die Karte "Upgrades: Hände" mit bis zu fünf Items; ein Klick auf eine Zeile meldet "Ziel ..." und setzt den Pfeil; ein zweiter Rechtsklick auf denselben Slot schließt sie.
- Prüfung: Wenn du mit rechts auf ein Schmuckstück mit Benutzen-Effekt klickst, dann benutzt das Spiel es wie immer und die Karte öffnet sich nicht; mit Alt+Rechtsklick öffnet sie sich.
- Prüfung: Wenn du mit der Maus über einen Slot fährst, dann steht unten im Tooltip "Rechtsklick: Upgrades (Amisia)" (bei Benutzen-Effekt "Alt+Rechtsklick: ..."), auch noch nachdem du Alt drückst.
- Prüfung: Wenn du `/amisia selbsttest` eingibst, dann steht dort "Charakterfenster-Slots: 17 Slot-Knöpfe, Rechtsklick an".
- Notiz: Spec `docs/specs/2026-10-24-spielstil-slotklick.md`; Einstellung "Rechtsklick auf Slots im Charakterfenster" (Ausrüstung und Wünsche). Shift- und Strg-Rechtsklick bleiben dem Spiel.

### F-045 Karte: Ziel, Pfeil und Pins
- Version: 2.58.0
- Status: gebaut
- Prüfung: Wenn du `/amisia karte <Item-Link>` eingibst, dann setzt Amisia das Ziel zur Quelle des Items ("Ziel ...") mit Wegpunkt und Pfeil; "Ziel erreicht" kommt am Ort.
- Prüfung: Wenn du die Weltkarte öffnest, dann stehen Pins mit Item-Symbol für deine Upgrades und Wünsche (abschaltbar unter Einstellungen, Karte und Wegpunkt).
- Prüfung: Wenn du auf der Seite Karte eine Zeile anklickst, dann wird sie das Ziel; Shift-Klick zeigt sie auf der Weltkarte.
- Prüfung: Wenn du auf der Seite Karte bei einer Zeile "Karte" klickst und die Weltkarte danach mit dem X schließt, dann öffnet sie sich in der Zone des Ziels, und beim Schließen kommt keine Fehlermeldung "hat versucht die geschützte Funktion ... aufzurufen" (auch nicht später in der Sitzung).
- Notiz: seit 2.55.0 auf eigener Pin-Ebene statt als Datenlieferant der Weltkarte (Taint-Fehler, DECISIONS D-64); seit 2.57.1 öffnet der Client die Karte selbst (`C_Map.OpenWorldMap`).
- Notiz: 2.57.0: Seite Karte öffnet auf "Alle Zonen" (nach Zonen, nächste zuerst), Chip "Quests" (nächster Questweg-Schritt, auch als "!" auf der Weltkarte, Einstellung `map.pinsQuests`), Ansicht "Ohne Ort", Zielkarte mit Richtung und Pfeil, Knopf "Karte" je Zeile, deutsche Namen aus eigener Beobachtung.

### F-105 Orte auf der Weltkarte (Eingänge, Flugmeister, Zeppeline, Schiffe)
- Version: 2.67.0
- Status: gebaut
- Prüfung: Wenn du die Weltkarte im Brachland öffnest, dann siehst du die Eingänge der Höhlen des Wehklagens und des Kral der Klingenhauer, aber keine Flugmeister, Zeppeline oder Schiffe (seit 2.67.0 aus). Schaltest du unter Karte und Wegpunkt "Flugmeister auf der Karte" und "Zeppeline und Schiffe auf der Karte" ein, dann kommen die Flugmeister deiner Fraktion und das Schiff in Ratschet dazu; der Tooltip des Schiffs sagt "Schiff nach Beutebucht"; in Durotar, im Sumpfland und in der Dunkelküste stehen Zeppelinturm und Anleger auf den Stegen.
- Prüfung: Wenn du auf den Eingang der Höhlen des Wehklagens klickst, dann öffnet sich Amisia auf der Seite Dungeons mit diesem Dungeon gewählt, die Weltkarte bleibt vorn; mit Shift setzt der Klick das Ziel zum Eingang (Chat "Ziel ...", Pfeil).
- Prüfung: Wenn du sie eingeschaltet hast und in den Einstellungen (Karte und Wegpunkt) "Flugmeister auf der Karte" wieder ausschaltest oder im Rechtsklick eines Pins "Flugmeister ausblenden" wählst, dann verschwinden die Flugmeister-Pins sofort, die Eingänge bleiben.
- Prüfung: Wenn du als Horde in Durotar und im Schlingendorntal schaust, dann siehst du keine Allianz-Flugmeister; in Beutebucht nur den deiner Fraktion.
- Prüfung: Wenn du `/amisia selbsttest` eingibst, dann stehen dort Zeilen zu C_TaxiMap und C_EncounterJournal und zu den Symbolen Dungeon/Raid; nach dem Betreten eines Dungeons ohne bekannten Eingang (z. B. Hall of Thanes) hat er nach dem nächsten Daten-Build einen Pin.
- Notiz: Spec `docs/specs/2026-10-16-karte-orte.md`; DECISIONS D-50 (gemerkte Eingänge), D-04 (seit 2026-11-04 Anleger und fehlende Flugmeister von Hand, eigene Symbole). Namen der Dungeons wie auf der Seite Dungeons (auf deutschen Clients teils englisch). Symbole: Flügelstiefel, Schiff in Fraktionsfarbe, Zeppelin (Media/Icons/place_*.tga), in 2.39.5/2.39.6 neu gezeichnet (glatter Rand, weicher Schatten).
- Notiz: seit 2.55.0 auf eigener Pin-Ebene statt als Datenlieferant der Weltkarte (Taint-Fehler, DECISIONS D-64).
- Notiz: Seit 2.67.0 sind Flugmeister, Zeppeline und Schiffe standardmäßig aus (D-83); die Eingänge bleiben.

### F-046 Dungeon-Planer: Rangliste, Kette, Quests
- Version: 2.4.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Ausrüstung "Dungeons" wählst und "Rangliste" sortierst, dann stehen die lohnendsten Dungeons für dich oben (offene Quests plus zwei Läufe).
- Prüfung: Wenn du "Kette" wählst, dann zeigt sie bis zu fünf Dungeons hintereinander, jeweils mit den Upgrades des vorigen als angelegt.
- Prüfung: Wenn du `/amisia dungeon quests <Dungeon>` eingibst, dann listet der Chat "Quests in <Dungeon>:" mit Vorquests und Start.
- Prüfung: Wenn du "Wegpunkt zum Eingang" klickst, dann zeigt der Pfeil zum nächsten Eingang.

### F-134 Dungeon-Quests: Status-Symbole und Karte
- Version: 2.54.2
- Status: gebaut
- Prüfung: Wenn du auf der Seite Dungeons "Quests" wählst, dann steht vor jeder Quest und Vorquest das Symbol wie im Spiel: gelbes "!" annehmbar, graues "!" noch zu niedrig oder Vorquest offen, graues "?" im Log, gelbes "?" im Log und fertig, grüner Haken erledigt, rotes Kreuz nicht mehr möglich.
- Prüfung: Wenn du auf eine Quest klickst, die du noch nicht hast, dann öffnet sich die Weltkarte in der Zone des Questgebers, dort steht nur ein gelbes "!" (ohne Raute, ohne Rahmen), Pfeil und Wegpunkt zeigen hin; Amisia bleibt offen.
- Prüfung: Wenn die Quest schon im Log und noch nicht fertig ist, dann öffnet der Klick die Karte am Dungeon-Eingang (Dungeon-Symbol ohne Rahmen, Chat "Ziel <Dungeon> (Eingang)"); ist sie fertig, wieder beim Questgeber.
- Prüfung: Wenn du in einem Dungeon auf eine Quest klickst, dann bleibt die Karte zu ("In Instanzen öffnet Amisia die Weltkarte nicht."), es kommt kein Lua-Fehler "tainted by 'Amisia'", und Amisias Ziel ist trotzdem gesetzt.
- Notiz: Wunsch des Nutzers 2026-11-05 ("können wir die quest besser markieren und die map direkt öffen wo man hin muss für die dungoen quest"; Antworten: Klick öffnet die Karte, Status mit Spiel-Symbolen). Vorbild war der Knopf "Karte" je Quest und Questschritt einer anderen Forever-Erweiterung (nur die Idee). Das graue "!" und "?" sind die gelben Symbole abgedunkelt.
- Notiz: 2.54.2: in einer Instanz, im Kampf und in der Kampfsperre öffnet der Klick die Karte nicht und setzt keinen Spiel-Wegpunkt (Fehler "tainted by 'Amisia'" im Objective Tracker, DECISIONS D-62).
- Notiz: 2.54.1: Questgeber-Pins nur noch als gelbes "!" ohne grünen Rahmen und Ring (Bildschirmfoto des Nutzers: das Karten-Symbol "QuestNormal" ist auf Forever eine Raute).

### F-135 Questweg für Dungeon-Quests
- Version: 2.55.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Dungeons bei "Quests" eine Quest mit Vorquests anklickst, dann zeigt Amisia ihre Schritte nummeriert von der ersten Vorquest bis zur Dungeon-Quest, jede mit Annehmen (wer, wo, Knopf "Karte"), Abgeben (oder "noch unbekannt") und Voraussetzung, und oben "Nächster Schritt: ...".
- Prüfung: Wenn du "Nächsten Schritt auf der Karte" klickst (draußen, nicht im Kampf), dann öffnet sich die Weltkarte beim Questgeber des nächsten offenen Schritts mit gelbem "!" und Wegpunkt.
- Prüfung: Wenn eine Quest oder ein Schritt im Dungeon startet, dann steht davor das Dungeon-Symbol und "im Dungeon".
- Prüfung: Wenn eine Vorquest durch ein Item startet, dann nennt ihr Schritt das Item und wo es fällt.
- Prüfung: Wenn du eine Quest annimmst, dann steht ihr Zieltext beim nächsten Öffnen des Questwegs unter dem Schritt, und nach dem Abgeben steht dort "Abgeben: bei <NPC>, <Zone> x, y".
- Notiz: Spec `docs/specs/2026-11-05-questweg.md` (freigegeben 2026-11-05).

### F-139 Lauf-Planer im Dungeon-Journal
- Version: 2.60.0
- Status: gebaut
- Prüfung: Wenn du das Journal eines Dungeons mit offenen Quests öffnest, dann steht im Bild "Lauf: +... EP" mit einem Balken, und sein Tooltip nennt deine Stufe nach dem Lauf.
- Prüfung: Wenn du links "Dein Lauf" (oder im Planer "Lauf planen") anklickst, dann stehen rechts die Halte vor dem Lauf nach Zonen, die Bosse in ihrer Reihenfolge mit den Quests daran und die Abgaben nach dem Lauf.
- Prüfung: Wenn du "Route: Halt 1/n auf der Karte" mehrmals klickst, dann springt der Wegpunkt von Halt zu Halt.
- Prüfung: Wenn du die Questliste ansiehst, dann steht bei jeder offenen Quest "Muss", "Lohnt", "Kann weg", "Später" oder "?" mit einem Balken, und der Tooltip erklärt den Wert.
- Prüfung: Wenn eine Belohnung ein Upgrade ist, dann steht in ihrer Kachel "statt <dein Item>" (oder "Platz leer"), und bei mehreren Belohnungen trägt die beste "beste Wahl".
- Notiz: Spec `docs/specs/2026-11-06-dungeon-run-planner.md` (Wunsch des Nutzers 2026-11-06: "du musst deutlich kreativer werden", dann "Ja, alles bauen"); Lohn und Graustufe D-66. Ohne Twinks (Amisia kennt ihre Ausrüstung nicht) und ohne Gruppen-Abstimmung (eigene Spec nötig).

### F-138 Quest-Journal eines Dungeons
- Version: 2.59.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Dungeons bei "Quests" eine Quest anklickst, dann stehen links alle Quests des Dungeons (die angeklickte hervorgehoben) und rechts ihr Titel, "Nächster Schritt", die Belohnungen als Kacheln mit Symbol, die EP und ihr Questweg.
- Prüfung: Wenn du links eine andere Quest anklickst, dann wechselt nur die rechte Seite.
- Prüfung: Wenn eine Belohnung ein Upgrade ist, dann steht in ihrer Kachel und in der Zeile der Quest links der Zuwachs in Grün.
- Prüfung: Wenn ein Schritt des Questwegs erledigt ist, dann zeigt seine Karte nur noch die Kopfzeile mit Haken.
- Prüfung: Wenn du "< Zurück zu den Dungeons" klickst, dann siehst du wieder die Dungeon-Liste mit den Quests.
- Notiz: Spec `docs/specs/2026-11-06-dungeon-quest-journal.md` (Wunsch des Nutzers 2026-11-06 mit Bild eines anderen Dungeon-Journals). Ersetzt die Ansicht des Questwegs von F-135 (dessen Schrittkarten stehen jetzt rechts im Journal).

### F-136 Questweg: Fundorte von Start-Gegenständen im Dungeon
- Version: 2.56.0
- Status: gebaut
- Prüfung: Wenn du als Horde auf der Seite Dungeons bei Ruins of Lordaeron unter "Quests" auf "Wappen von Lordaeron" klickst, dann steht unter "Annehmen: Gegenstand Wappen von Lordaeron aufheben oder benutzen, zu finden in Ruins of Lordaeron" die Zeile "Fundorte:" mit dem Aussehen des Wappens und fünf Stellen (Gruft nahe The Baron, zwei bei Bjork, zwei Türme) und darunter grau "nach Berichten von Spielern, von Amisia nicht selbst gesehen".
- Prüfung: Wenn du dort bei "Annehmen" auf "Karte" klickst (draußen, nicht im Kampf), dann öffnet sich die Weltkarte am Eingang von Ruins of Lordaeron.
- Prüfung: Wenn du dort auf die Zeile "Abgeben" schaust, dann steht "bei Oran Snakewrithe, Unterstadt 73, 32" mit Knopf "Karte".
- Notiz: Wunsch des Nutzers 2026-11-06 nach einer Websuche zu dieser Quest; Hinweise von Hand in `tools/quest_hints.json` (DECISIONS D-65).

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
- Notiz: 2.37.2: Boss-, Trash- und Questbeute der Dungeons zusätzlich aus OneForAll 5.6.0 (nur Items mit Forever-ID oder die der Client kennt; DECISIONS D-04); seit 2026-11-04 entfernt, die Beute lernt der Sammler.

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

### F-123 Ausrüstungsziele: Katalog mit Sets und Itemsuche
- Version: 2.45.0
- Status: gebaut
- Prüfung: Wenn du im Fenster Ausrüstungsziele "Katalog" klickst, dann stehen links Raid-Sets, Dungeon-Sets, PvP-Sets, Handwerks-Sets und Welt-Sets mit der Zahl ihrer Sets; leere grau.
- Prüfung: Wenn du Handwerks-Sets und dann "Devilsaur Armor" anklickst, dann stehen beide Teile mit Slot, Stufe, Zuwachs und Quelle darunter, und "Set anprobieren" zieht sie dem Modell an; "Anprobe leeren" wieder aus.
- Prüfung: Wenn du "Wolfs" in die Suche tippst und "Alle" klickst, dann listet Amisia jedes bekannte Item mit "Wolfs" im Namen, das beste für dich oben.
- Prüfung: Wenn du "Meine Stufe" klickst, dann steht im Bereich 1 bis deine Stufe und die Liste folgt.
- Prüfung: Wenn du ein Teil per Rechtsklick "Als meine Wahl" setzt, dann zeigt "Ziele" es in seinem Slot mit Stern.
- Notiz: Spec `docs/specs/2026-10-17-ziele-katalog.md` (freigegeben 2026-10-17); Wunsch mit zwei Bildschirmfotos eines anderen Addons.
- Notiz: 2.46.0: Kategorie "Ruf" (je Fraktion eine Gruppe der Items mit Rufbedingung aus ItemSparse, F-124).
- Notiz: seit 2.65.0 im Ausrüstungsplaner (D-80): das Fenster gibt es nicht mehr.

### F-129 Ausrüstungsziele: Stufen-Sets im Katalog
- Version: 2.50.0
- Status: gebaut
- Prüfung: Wenn du im Fenster Ausrüstungsziele "Katalog" klickst, dann steht links ganz oben "Stufen-Sets"; mit "Alle" (Stufe 1 bis 60) zeigt sie die Zahl 6, mit "Meine Stufe" nur die Bereiche bis zu deiner Stufe.
- Prüfung: Wenn du "Stufen-Sets" und "Alle" wählst, dann stehen dort "Stufe 1 bis 19", "Stufe 20 bis 29", "Stufe 30 bis 39", "Stufe 40 bis 49", "Stufe 50 bis 59" und "Auf Stufe 60", jedes mit "N/M" Teilen, die du schon hast.
- Prüfung: Wenn du ein Stufen-Set anklickst, dann stehen darunter je Slot das beste Item für deine Spezialisierung am oberen Ende des Bereichs, mit Slot, Stufe, Zuwachs und Quelle; der Tooltip des Sets sagt "Das Beste je Slot für deine Spezialisierung auf Stufe N."
- Prüfung: Wenn du eine andere Spezialisierung oder den Spielstil wechselst, dann ändern sich die Stufen-Sets mit; "Set anprobieren" zieht ein Stufen-Set dem Modell an, Rechtsklick auf ein Teil "Als meine Wahl" setzt es als deine Wahl.
- Notiz: Wunsch des Nutzers 2026-11-05 ("kannst du dich nach items set für gewisse lvl bereiche erstellen und unsere bis liste dafür aktualisieren"); Auswahl: im Katalog, berechnet, 10er-Schritte. Rechnet wie die Simulation (`ns.BisFor`) mit deiner Klasse, Spezialisierung, Fraktion, Quellen, Waffenplan und Ausschlüssen; die BiS-Empfehlungen (bis_picks.json) gehen vor. Neue Items aus `/amisia scan` kommen mit dem nächsten `build.py data` hinein.
- Notiz: seit 2.65.0 im Ausrüstungsplaner (D-80): das Fenster gibt es nicht mehr.

### F-132 Realistische Quellen und eigener Tooltip
- Version: 2.51.0
- Status: gebaut
- Prüfung: Wenn du die Ausrüstungstabelle (`/amisia gear`) oder die Ziele öffnest, dann ist der Chip "Weltdrops" aus und von Stufe 1 bis 50 stehen keine epischen Items mehr mit "?" und Stufe 1, sondern Quest-, Dungeon-, Handwerks- und Händler-Items.
- Prüfung: Wenn du "Weltdrops" einschaltest, dann kommen grüne und blaue Welt-Drops dazu, aber nie epische.
- Prüfung: Wenn du mit "AH" an ein Item kommst, dann hat es eine feste Quelle (z. B. hergestellt oder Dungeon-Drop, bindet beim Anlegen); ein Item, das nur im Auktionshaus gesehen wurde, kommt nicht.
- Prüfung: Wenn du im Katalog nach "Prophezeiung" suchst, dann zeigen die Items der Stufe 30 Namen und Symbol, und der Tooltip nennt Slot, Gegenstandsstufe, Werte, Quellen und "Aus Amisias Scan: der Server beschreibt dieses Item nicht (mehr)."
- Notiz: Wunsch des Nutzers 2026-11-05 ("können wir bei den set nur realistischge sachen rein machen die man würklich bekommt", Bildschirmfoto der Tabelle voller 288xxx-Epics). DECISIONS D-59.

### F-122 Seite Raids
- Version: 2.45.0
- Status: gebaut
- Prüfung: Wenn du den Reiter Ausrüstung öffnest, dann steht links "Raids" direkt unter "Dungeons", und die Seite listet Barrow Deeps (10), Hyjal Summit (20) und Onyxia's Lair (40), vor dem 09.12. mit "ab 09.12.".
- Prüfung: Wenn du auf der Seite Dungeons bist, dann steht dort kein Raid mehr, auch nicht mit Stufe 60.
- Prüfung: Wenn du Onyxia's Lair wählst, dann zeigt das Bild den Raid mit Onyxias Modell und darunter die bekannte Beute; "Wegpunkt" setzt das Kartenziel auf den Eingang in den Düstermarschen.
- Prüfung: Wenn du `/amisia raids` eingibst oder in der Suche einen Raid anklickst, dann öffnet sich die Seite Raids.
- Prüfung: Wenn du eine Raid-ID hast (braucht: Raid), dann steht in der Spalte ID "bis <Tag Uhrzeit>".
- Notiz: Spec `docs/specs/2026-10-17-raids-seite.md` (freigegeben 2026-10-17).

### F-128 Verzauberungs-Vorschläge je Slot
- Version: 2.48.0
- Status: gebaut
- Prüfung: Wenn du im Fenster Ausrüstungsziele einen Slot mit einem unverzauberten Item wählst, dann steht rechts "Verzauberung: Keine" in Rot und darunter höchstens fünf passende Verzauberungen, die mit dem größten Gewinn für deine Spezialisierung zuerst.
- Prüfung: Wenn das getragene Item verzaubert ist, dann steht der Name der Verzauberung oben, und jede Zeile darunter zeigt den Gewinn gegen diese; ist nichts besser, steht dort "Du hast schon die beste".
- Prüfung: Wenn du mit der Maus über eine Zeile fährst, dann nennt der Tooltip Quelle, Mindeststufe, Reagenzien mit der Zahl in deinen Taschen und die Gildenmitglieder, die das Rezept kennen.
- Prüfung: Wenn du einen Slot ohne mögliche Verzauberung wählst (Ring, Schmuck, Hals), dann gibt es keinen Abschnitt "Verzauberung".
- Prüfung: Wenn du mit Alt + Rechtsklick die Karte eines Slots am Charakterfenster öffnest, dann steht oben die Zeile "Verzauberung: ..."; ein Klick darauf öffnet das Fenster Ausrüstungsziele auf diesem Slot.
- Notiz: Spec `docs/specs/2026-10-31-verzauberungen.md`, freigegeben 2026-10-31 ("Passt").

### F-127 Talentrechner: Builds aus Links der Talentrechner-Seiten
- Version: 2.48.0
- Status: gebaut
- Prüfung: Wenn du einen Link von talentsforever.com in das Feld "Code" der Seite Talente einfügst und Enter drückst, dann zeigen die Bäume genau den Build der Seite (gleiche Talente, Ränge und Punkte je Baum), der Chat meldet "Code übernommen: <Klasse>, <Punkte> Punkte." und im Feld steht ein `AT1.`-Code.
- Prüfung: Wenn du dasselbe mit einem Link von wowforevertalents.com machst, dann gilt dasselbe.
- Prüfung: Wenn du `/amisia talente <Link>` eingibst, dann öffnet sich die Seite Talente mit diesem Build.
- Prüfung: Wenn du im Plan Sekundär einen Link übernimmst, dann bleibt Primär unverändert (auch nach `/reload`).
- Prüfung: Wenn du einen Link mit einem Fehler einfügst (z. B. eine Ziffer zu viel im ersten Baum), dann steht im Chat, warum es nicht geht, und der Plan bleibt, wie er war.
- Notiz: Spec `docs/specs/2026-10-31-talent-links.md`, freigegeben 2026-10-31 ("Passt"). Gebaut ohne Beispiel-Links nach den bekannten Formaten; ob die Bäume der Seiten in derselben Reihenfolge stehen wie im Spiel, zeigt erst die Prüfung im Spiel.

### F-121 Talentrechner: zwei Pläne je Klasse
- Version: 2.45.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Talente (oder im Fenster Talentrechner) unten den Knopf "Primär" klickst, dann steht dort "Sekundär", die Bäume zeigen den zweiten Plan der Klasse (beim ersten Mal leer) und unten steht "Plan Sekundär".
- Prüfung: Wenn du im Plan Sekundär Talente verteilst, zurück auf "Primär" und wieder auf "Sekundär" wechselst (auch nach `/reload`), dann sind beide Pläne noch so, wie du sie verlassen hast; Seite und Fenster zeigen denselben Plan.
- Notiz: Wunsch des Nutzers 2026-10-17 ("können wir bei Talentrechner 2 preset speichern", Bildschirmfoto der Reiter Primär/Sekundär). Gespeichert in `AmisiaDB.talents.plans2`; der erste Plan bleibt in `plans`, alte Pläne sind also Primär.

### F-081 Großes Talentfenster
- Version: 2.20.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Talente unten rechts "Talentrechner" klickst (oder `/amisia talente gross` eingibst, oder den Reiter mit dem Bogenschützen-Symbol rechts am Amisia-Fenster), dann öffnet sich das Fenster "Talentrechner" mit denselben drei Bäumen, größer (44-px-Symbole), mit Klasse, Stufe, Talentiert, Punkten, "Eigene laden", "Alles zurücksetzen", Code und dem Hinweis "Linksklick: +1 · Rechtsklick: -1 · Shift: alle Ränge"; kein Knopf und kein Rangschild berührt den Rand seines Baums.
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
- Notiz: 2.57.0: Filter "Bekannt: …" und "Quelle: …" als Auswahllisten, "N von M Rezepten", leere Liste nennt, welcher Filter Rezepte zurückbringt, mit "Filter zurücksetzen" (Bildschirmfoto des Nutzers mit 0 Rezepten bei Bekannt + Händlergunst + Gilde).

### F-137 Berufsroute mit Einkaufsliste
- Version: 2.58.0
- Status: gebaut
- Prüfung: Wenn du auf der Seite Berufe Schneiderei wählst und auf "Route" schaltest, dann zeigt die Route Schritte von deinem Rang bis zum Höchstrang mit Lehrerschritten an den Limits, jeder Rang in genau einem Schritt (wo kein Rezept mehr Punkte gibt, sagt der Schritt das); bei Alchimie kommt keine Transmutation in die Route.
- Prüfung: Wenn du einen Schritt herstellst und dabei einen Punkt bekommst, dann steht die Route danach auf dem neuen Rang, ohne `/reload`.
- Prüfung: Wenn du ein Material der Einkaufsliste in die Tasche legst, dann steigt "hast" und "fehlt" sinkt; bei genug wird die Zeile grün.
- Prüfung: Wenn du "auch Händler" wählst, dann kann ein Schritt "Rezept kaufen: ... bei <Händler>" in die Route kommen; ein Klick setzt den Wegpunkt zum Händler.
- Prüfung: Wenn ein Twink auf demselben Realm und derselben Fraktion Stoff in Taschen oder Bank hat und du dich mit ihm einloggst und einmal die Seite Berufe öffnest, dann steht die Menge danach bei deinem Hauptcharakter in der Einkaufsliste unter "Twinks"; ein Twink der anderen Fraktion zählt nicht.
- Notiz: Spec `docs/specs/2026-11-06-berufsroute.md`, freigegeben 2026-11-06.

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
