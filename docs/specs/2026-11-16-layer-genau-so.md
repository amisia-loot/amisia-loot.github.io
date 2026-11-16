# Spec: Layer verhält sich genau wie das verbreitete Layer-Addon

Stand: 2026-11-16 · Status: Entwurf ·
Feature: F-221

## Ziel

Nutzer 2026-11-16, nach 2.98.0 (F-220), mit dem eingefügten Quelltext jenes Addons (Version 1.14.25): "mach das layer
genau so". F-220 spricht schon sein Nachrichtenformat; hier geht es um das Verhalten: wann Amisia hilft, wie es den
Layer liest, wie es einen Wechsel beurteilt, was Knopf, Fenster und Leiste zeigen. Verglichen wurden 89 Punkte: 20
gleich, 51 anders, 18 fehlen (Notiz mit Zeilenangaben beider Seiten außerhalb des Repos, `~/addons/_research`,
2026-11-16, D-05). Gelöst ist es, wenn ein Nutzer beider Addons beim Fragen, Helfen und Wechseln keinen Unterschied im
Ablauf merkt; Aussehen und Texte bleiben Amisias (eigener Code, deutsche Texte, Amisias Fensterstil).

## Was es tut

**Teil 1, Helfen wie dort.**
- Jede eigene Frage ("Layer wechseln", Zeile, Befehl, Gilde) schaltet Helfen an, solange sie läuft und 4 Minuten nach
  einem gelungenen Wechsel (die Sperre läuft auch in Gruppe, Instanz, Kampf weiter und verlängert sich nicht). Ein Klick
  auf "Helfen: AUS" sagt dann im Fenster "Helfen bleibt noch 3:41 an." Danach schaltet Amisia es wieder aus, wenn es
  vorher aus war. Während die eigene Frage auf eine Einladung wartet, lädt Amisia niemanden ein (wie bisher).
- Helfen aus bleibt über `/reload` aus; erst ein echtes Einloggen schaltet es wieder an.
- Der Knopf zeigt "Helfen: AN 3:41" während der Sperre und "Helfen: PAUSIERT" (grau, klickbar) mit dem Grund: in der
  Gruppensuche oder Dungeonsuche, in einer Instanz, in einer fremden Gruppe, im Kampf (Einstellung), Neustart der Welt,
  Pause nach sechs Einladungen.
- Das "h" der Antwort heißt "hilft und kann gerade einladen", unabhängig vom Layer der Frage (so zählen die Fragenden
  jenes Addons Amisia-Helfer richtig und fragen sie notfalls ohne Layer noch einmal).
- Einladungen höchstens eine je Sekunde; offene Einladungen zählen 60 Sekunden zur vollen Gruppe; "ist schon in einer
  Gruppe"/"wurde schon eingeladen" gibt den Platz frei. Nimmt jemand eine Einladung an, nachdem Helfen aus ist (bis 5
  Minuten), entfernt Amisia ihn wieder. Die Beute geht auf die vorige Art zurück, wenn ein Nicht-Gast beitritt.

**Teil 2, den Layer lesen wie dort.**
- Ein bekannter Layer bleibt bis Zonenwechsel, Neustart oder Einloggen (nicht nur 5 Minuten). Amisia liest die
  Namensplaketten, Ziel und Maus selbst nach: 2, 5 und 12 Sekunden nach Einloggen, Neustart und Wechsel, wenn eine
  Frage kommt und der eigene Layer unbekannt ist, bei einer Frage ohne Layer bis zu dreimal im Abstand von 0,5 s; nie in
  den 15 Sekunden nach einer Zonengrenze.
- Kreaturen, die beim Wechsel (`SHARD_TRANSFER`) zu sehen waren, zählen 10 Sekunden nicht. Einen bekannten Layer
  ändern 3 der letzten 5 Lesungen, einen unbekannten 2.
- Die gesehenen Layer bleiben über `/reload` (1 Stunde).

**Teil 3, fragen wie dort.**
- `/who` mit dem Kartenfilter der Zone, dann je Klick eine Klasse (Krieger, Paladin, Jäger, Schurke, Priester,
  Schamane, Magier, Hexenmeister, Druide); geht der Kartenfilter nicht, die Zone mit dem Zonen-Kürzel des Clients (nicht
  fest "z-") und Stufenbereiche. Höchstens 49 Namen; Spieler der eigenen Zone zuerst; Gilde zuletzt (oder gar nicht mit
  "Gilde zuletzt fragen" aus); ist nur die Gilde da, sofort die Gilde.
- Wer in den letzten 6 Stunden gefragt wurde und nicht antwortete, wird nicht noch einmal gefragt (gespeichert,
  höchstens 3000). Bekannte Helfer (7 Tage, höchstens 300) zuerst; die Zeile des Spiels "Kein Spieler namens ..." für
  eigene Flüsterer verschwindet aus dem Chat und der Spieler ruht 10 Minuten.
- Ein Helfer, der von unserem Layer eingeladen hat, wird 20 Sekunden lang nicht gefragt.
- Die Flüsterer gehen in Runden zu 8 je Sekunde; die erste Einladung beendet sie. Nach 3 und 10 Sekunden bekommt ein
  Helfer, der "hilft" sagt, aber keinen Layer kennt, die Frage ohne Layer.
- Eine Frage gilt 120 Sekunden (statt 60), danach dieselben Sätze wie dort ("Niemand auf einem anderen Layer hat
  geantwortet. Klick noch einmal, um mehr Spieler zu fragen." usw.); war die Liste des Spiels voll, sagt der Satz, dass
  ein weiterer Klick andere Spieler erreicht.
- "Im Gildenchat fragen" schreibt die Zeile mit Zone, Layer und Position (`inv layer <LS ...>`) in die Chatzeile; die
  Helfer jenes Addons überspringen eine Gildenbitte ohne sie. Amisia-Helfer beantworten so eine Gildenzeile und
  schicken "heard" über die Gilde. (Berichtigt die Spec von F-220: jenes Addon nutzt Gildenbitten auf Forever weiter.)

**Teil 4, einen Wechsel beurteilen wie dort.**
- Nach dem Beitritt liest Amisia die Kreaturen nach 0, 1 und 3 Sekunden und dann alle 2 Sekunden. "Kein Wechsel"
  frühestens nach 5 Sekunden ohne Wechsel des Spiels und 3 frisch gelesenen Kreaturen des alten Layers; verlassen
  frühestens nach 15 Sekunden; nach 60 Sekunden hört das Prüfen auf.
- Nach etwa 5 Sekunden zählt der echte Gruppenleiter als Helfer (nicht der erste Einlader).
- `SHARD_TRANSFER` allein ist kein Erfolg: erst ein anderer Layer in derselben Zone. Ein Neustart, der auf demselben
  Layer lässt, heißt "nicht gewechselt". Endet die Gruppe vor dem Urteil, gilt ein Wechsel noch 30 Sekunden danach.
- Nach dem Wechsel verlässt Amisia die Gruppe nach 4 Sekunden (statt 5), von selbst nur, wenn der Helfer auf die
  Frage geantwortet hat.
- Warnungen bei einer Einladung: von einem Helfer, der uns in den letzten 10 Minuten nicht bewegt hat; von einem, dessen
  Antwort unseren Layer nannte ("ist auf deinem Layer - ablehnen und warten"); bei "Nur neue Layer" von einem auf einem
  schon gesehenen Layer.

**Teil 5, Fenster und Leiste wie dort.**
- Der Knopf "Layer wechseln" wird während der Suche zu "Suche stoppen" (erst nach 1 Sekunde klickbar), in der Gruppe
  eines Helfers zu "Gruppe verlassen" bzw., wenn er nicht bewegt hat, "Verlassen und neu fragen".
- Die Zeilen "Gesehen in dieser Zone" sind für alle klickbar (nicht nur in einer Gilde), der eigene Layer nicht; die
  gefragte Zeile sagt "fragt ...".
- Die Leiste gibt es auch ohne eingeklapptes Fenster (Einstellung "Leiste zeigen", an): Zeile 1 der Layer, Zeile 2 der
  Stand ("Helfen 3:41", "Pausiert", "Neustart in 4:12", "Frage, 3 gehört", "Verlasse in 4 s", "Helfen aus"); das Symbol
  gold beim Helfen, grau aus, grün bei eigener Frage; Klick öffnet das Fenster, Rechtsklick aufs Symbol die Layer-Liste,
  Rechtsklick sonst blendet sie aus; Hintergrund-Vorgabe 55 %.
- In einer Instanz: das Fenster sagt "Keine Layer in <Instanz>" statt den Knopf zu verweigern.
- Befehle dazu: `/amisia layer an`, `/amisia layer aus`, `/amisia layer status`.

## Was es ausdrücklich nicht tut

- Kein Code jenes Addons (D-145 bleibt: nur Format und Verhalten, eigener Code); sein Name nur in der Präfix-Zeile.
- Nicht übernommen: sein Protokoll im Speicher (1000 Einträge), Kanal-Zählung, Ping, Phasen-Proben, die Befehle
  `spot`/`phase`/`loot`; sein eigener Kanal und Kanal-Notizen (`claim`, `pos`, `zone`, `any`, `ping`); sein Minimap-
  Symbol und seine Optionsseite (Amisia hat ein Minimap-Symbol und den Abschnitt Layer); seine englischen Texte und sein
  Fensterlook; der Classic-Weg (NWB-Nummern).
- Buchstaben: Amisia nummeriert die Layer einer Zone weiter nach Kennung, damit Gildenmitglieder denselben Buchstaben
  sagen; dort zählt jeder für sich. Derselbe Layer kann also dort "Layer C" und bei Amisia "Layer A" heißen.

## Abläufe

1. Helfen aus, "Layer wechseln": Helfen geht an, die Suche läuft, ein Helfer lädt ein, der Wechsel gelingt, Amisia
   verlässt die Gruppe nach 4 s; der Knopf zeigt "Helfen: AN 3:56"; ein Klick darauf sagt "Helfen bleibt noch 3:55
   an."; nach 4 Minuten ist Helfen wieder aus.
2. Ein Helfer auf unserem Layer lädt ein: Warnung im Fenster; nimmt man an, sagt Amisia nach frühestens 15 s "hat dich
   nicht bewegt", verlässt die Gruppe, der Knopf heißt "Layer wechseln"; die nächste Suche fragt ihn 20 s nicht.
3. Neustart der Welt in der Gruppe, danach dieselbe Kennung: "nicht gewechselt" statt "Gewechselt".

## Abnahmekriterien

- Wenn du mit Helfen aus "Layer wechseln" klickst und der Wechsel gelingt, dann zeigt der Knopf "Helfen: AN" mit einer
  Uhr ab 4:00, ein Klick darauf schaltet nicht aus, und nach Ablauf ist Helfen wieder aus.
- Wenn du Helfen ausschaltest und `/reload` machst, dann bleibt es aus; nach neuem Einloggen ist es an.
- Wenn du "Layer wechseln" klickst, dann wird der Knopf zu "Suche stoppen"; in der Gruppe des Helfers zu "Gruppe
  verlassen".
- Wenn du nach einem Wechsel 10 Minuten still stehst und ein Nutzer jenes Addons fragt, dann lädt Amisia ihn ein (der
  Layer ist noch bekannt).
- Wenn du "Im Gildenchat fragen" klickst, dann steht `inv layer <LS ...>` in der Chatzeile, und ein Helfer jenes Addons
  aus der Gilde lädt ein.

## Sonderfälle

- Die Sperre läuft nur für den Charakter, der gewechselt hat; ein `/reload` oder Ausloggen in der Gruppe des Helfers
  zählt als gelungener Wechsel (sonst ließe sich die Sperre so umgehen).
- `SendWho` nimmt den Kartenfilter nicht: still auf die Zonen-Suche; das Fenster "Wer" des Spiels und die Liste der
  Gruppensuche bekommen die Antwort nicht, solange die eigene Frage läuft (außer sie sind offen).
- Ein älteres Amisia in der Gilde (bis 2.97) kennt den Server-Teil nicht (F-220): "kein Wechsel" nach 15 s fängt es ab.

## Missbrauch/Vertrauen

- Die Sperre lässt Fremde 4 Minuten nach jedem eigenen Wechsel um Einladungen bitten; die Grenzen bleiben (sechs in
  zehn Minuten, einer je Minute, nie in Instanzen, nicht in der Gruppensuche, eigene Zone).
- Gildenzeilen im fremden Format: nur die strenge Prüfung des `<LS ...>`-Teils, nur von Gildenmitgliedern, dieselben
  Grenzen; die Regel für schlichte Chatzeilen (höchstens 40 Zeichen) bleibt.
- Gespeicherte Namen: "gefragt ohne Antwort" (6 h, 3000) und bekannte Helfer (7 Tage, 300), nur Namen und Zeiten.

## Daten

- `AmisiaDB.layerHelp` = { off = true bis Ausloggen, lock = { untilAt, who }, forced = Name } (D-139 ändert sich).
- `AmisiaDB.layerAsked` = { [Name] = Zeit } (6 h, höchstens 3000); `AmisiaDB.layerHosts` höchstens 300, mit "hilft".
- `AmisiaDB.layerSeen` = die gesehenen Layer je Zone (1 h).
- Einstellungen (Abschnitt Layer): "Leiste zeigen" (an), Hintergrund 55 %; "Verlassen nach Sekunden" Vorgabe 4.
- DECISIONS: D-146 (ändert D-139 und D-145); ARCHITECTURE: Schlüssel, Einstellungen, Ablauf.

## Offene Fragen

1. Die 4-Minuten-Sperre von Helfen nach einem eigenen Wechsel übernehmen (Helfen geht auch an, wenn du es aus hattest)?
   Vorschlag: ja, genau wie dort.
2. Die Leiste von Anfang an zeigen (dort an), auch wenn das Fenster nie eingeklappt war? Vorschlag: ja.
3. Amisia nimmt die Einladung eines Antwortenden weiter von selbst an (dort klickt man selbst "Annehmen")? Vorschlag:
   ja, behalten; wer es wie dort will, schaltet "Einladung annehmen" aus.
4. Alles in einem Release? Vorschlag: ja, mit Selbsttest und den Tests je Teil.

## Entscheidungen

- (offen)
