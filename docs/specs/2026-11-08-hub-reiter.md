# Spec: Hub mit Reitern oben, Bildkopf und Tabellenlisten

Stand: 2026-11-08 · Status: freigegeben ·
Feature: F-147 (Fenster), F-148 (Dungeons & Raids als Tabelle), F-149 (Ausrüstung), F-150 (Talente), F-151 (Berufe)

Nutzer am 2026-11-08 mit einem Bildschirmfoto des Hubs eines anderen Addons: "mach das addon/ui genau so
wie [das Vorbild], nur QoL, Hunter Pets und Library Books will ich nicht, aber dafür die Funktionen von
Amisia; Raid und Inis und Char Spec genau wie beim Vorbild". Das ersetzt die Navigation von D-68/D-70
(eine Seitenleiste mit allen Gruppen) und den Forever-Classic-Rahmen des Hauptfensters (D-70, Spec
2026-11-07). Übernommen werden nur Aufbau und Verhalten; Code, Texte und Grafiken kommen von uns oder
aus dem Spielclient (Lizenz des Vorbilds, D-04). Das Vorbild wird nirgends im Repo genannt.

## Ziel

Amisia sieht aus und bedient sich wie der Hub des Vorbilds: Bildkopf, Reiter oben, je Reiter eine
eigene Seitenleiste, Listen als Tabellen. Gelöst ist es, wenn das Fenster neben dem Foto des Vorbilds
"gleich gebaut" aussieht und jede Amisia-Seite über Reiter und Seitenleiste erreichbar ist.

## Was es tut

**Fenster (F-147)**

- **Rahmen:** dunkles Braunschwarz mit dünnem Goldrand und runden Ecken statt des Porträt-Rahmens des
  Clients. Farben und Maße als Tokens in `UI/Theme.lua` (`T.HUB`).
- **Bildkopf (~90 px):**
  - Links das Amisia-Logo rund im Goldring, daneben "Amisia" groß in Gold und darunter klein
    "LOOT · RAID · GEAR" (Frage 2).
  - Dahinter ein breites Bild aus dem Client, nach rechts ausgeblendet (Frage 3).
  - Rechts oben quadratische dunkle Knöpfe mit Goldrand: Feedback, Minimieren, Schließen.
- **Reiter oben** (dunkel, Goldrand; der gewählte heller mit goldener Unterlinie), je mit Symbol aus
  dem Client (D-70 Folge: keine Zauber- oder Itemsymbole):
  `Ausrüstung · Dungeons & Raids · Berufe · Talente · Raid · Gilde` und rechts ein Zahnrad-Reiter für
  die Einstellungen (Frage 1).
- **Seitenleiste je Reiter (~200 px):**
  - Kopf: Symbol des Reiters (32 px) und sein Name in Gold, darunter die goldene Linie.
  - Die Seiten des Reiters als Zeilen mit Symbol; die gewählte mit Goldbalken links und hellem Grund.
  - Darunter, wo die Seite Abschnitte hat, eine zweite Liste als Sprungmarken mit Zahl rechts
    (Dungeons: "Stufe 10 – 19 · 5"; Einstellungen: ihre Abschnitte).
  - Seitenfenster (Ausrüstungstabelle, Ziele, Talentrechner, Würfelfenster, SR-Import) bleiben Zeilen
    mit Fenster-Zeichen (D-68).
- **Seitenkopf:** Symbol (32 px), Titel in Gold, eine graue Zeile darunter; rechts das Suchfeld der
  Seite (D-69 bleibt, nur das Symbol kommt dazu).
- **Fußzeile:** links grau der Status (Aufnahme, Ansicht), rechts "Version x.y.z"; Größengriff unten
  rechts (D-71 bleibt: Breite und Höhe ziehbar, Minimieren zur Leiste).
- Die bisherige Gesamtsuche wandert als Suchfeld in den Kopf (neben den Knöpfen) statt oben in die Leiste.

**Dungeons & Raids (F-148)**

- Seitenleiste: Dungeons, Raids, Quests, Karte; darunter die Stufenbereiche mit Anzahl (bei Raids:
  Erweiterung/Stufe).
- Liste als Tabelle mit sortierbaren Spaltenköpfen (Klick: auf-/absteigend, kleines Dreieck):
  **Dungeon** (Titelbild der Instanz aus dem Client, ~118×44, mit Rahmen, und der Name in Gold; "NEU"
  grün für Forever-Instanzen, gelbes Warnzeichen bei Hinweisen) · **Stufe** (in Questfarbe zum eigenen
  Level) · **Gebiet** (Wappen Allianz/Horde/umkämpft) · **Zone** · **Schlüssel** (Symbole, grau wenn
  fehlend) · **Quests** (offen/abgabebereit oder "-") · **Aktionen** (Karten-Knopf: Wegpunkt zum
  Eingang).
- Stufenbereiche als aufklappbare Gruppenzeilen "˅ Stufe 20 – 29 … 7 Dungeons"; ein Klick in der
  Seitenleiste springt hin.
- Klick auf eine Zeile öffnet die Detailseite von F-146 (Reiter Übersicht, Karte, Quests, Wunschliste,
  Zugang); die Kacheln von F-143 entfallen. "Hier bist du" und "1/4 Bosse" stehen in der Zeile.

**Gemeinsam (D-75):** Eine Seite kann der Leiste Marken mit Symbol geben, eine gewählte Marke ist hervorgehoben,
eine Marke kann einen neuen Block mit goldener Linie beginnen. So entstehen die Klassen-, Set- und Berufslisten der
Fotos. Symbole der Marken dürfen die eigenen Symbole des Spiels für Klassen und Berufe sein (Klassenwappen,
Berufssymbol des Clients), keine Ersatzsymbole.

**Ausrüstung (F-149, D-77)** nach dem Foto des Reiters Armory:
- Leiste: die neue Seite "Ausrüstungsplaner" zuerst, dann die bisherige Seite Ausrüstung und die Fenster Tabelle und
  Ziele; darunter als Marken die Katalog-Kategorien Raid-Sets, Dungeon-Sets, PvP-Sets, Handwerks-Sets, Welt-Sets und
  (eigener Block) Ruf. Reittiere und Legendäres entfallen (keine Daten).
- Seite links: Kopf "Name Stufe N · Spezialisierung ˅" (der Spec-Wähler der Ausrüstung), das Modell zwischen den
  Platzspalten wie das Charakterfenster, die Waffen darunter, je Platz das Item im Rahmen seiner Qualität (grün =
  Ziel erreicht) und daneben die geplante Verzauberung (oder ein kleines "+", das die Verzauberungen des Platzes
  zeigt); unten "Zurücksetzen" (die eigenen Wahlen).
- Seite rechts: Reiter "Vorschläge | Wunschliste", ein Suchfeld über alle Items, der Name des gewählten Platzes,
  "Stufe [1] - [33]" und "Meine Stufe | Alle"; die Liste: Symbol, Name in Qualitätsfarbe, "Stufe 31 · Quelle", der
  Zuwachs "+89 %", das Symbol der Quelle (Dungeon, Beruf, Händler ...) und der Stern für die Wunschliste. Ein Klick
  macht die Zeile zur eigenen Wahl. Eine Set-Marke zeigt rechts die Sets dieser Kategorie (der Katalog).
- Die Daten kommen aus ns.BisTargets, ns.BisRanking, dem Katalog und den Verzauberungen; das Fenster
  "Ausrüstungsziele" bleibt.

**Talente (F-150, D-76)** nach dem Foto des Reiters Talent Trees:
- Leiste: die Seite Talente und das Fenster Talentrechner, darunter als Marken die Klassen mit ihrem Wappen (die
  gezeigte gewählt), ein Block "Plan 1"/"Plan 2" (Primär/Sekundär, der gezeigte gewählt) und ein Block mit den
  Aktionen "Eigene laden", "Plan zurücksetzen", "Build importieren", "Build exportieren".
- Seite: oben eine Zeile "Stufe: 9 · Verfügbar: 51 · Verteilt: 0 · Übrig: 51" über die Breite verteilt; die drei Bäume
  nebeneinander, jeder mit dem Hintergrundbild seiner Klasse aus dem Client, Name in Gold und "0 Punkte" oben,
  die Talente als Symbole mit "0/5" unten rechts, die Linien der Voraussetzungen; unten rechts "Linksklick + ·
  Rechtsklick -". Die Klassenauswahl und die Plan-Reiter der Seite selbst entfallen (sie stehen in der Leiste).

**Berufe (F-151, D-78)** nach dem Foto des Reiters Professions:
- Leiste: die Seiten Berufe und Schriftrollen; als Marken "Übersicht", dann jeder Beruf mit seinem Symbol, ein Block
  mit "Lager" und "Händlergunst" (die eigene Gunst als Zahl rechts).
- Übersicht: eine Zeile Erklärung; "Deine Berufe" als Kacheln (Symbol, Name, "Skill 75/150 | 0 bekannt"); "Alle
  Berufe" (Symbol, Name, "182 Rezepte | 0 bekannt"); "Weiteres" mit Lager und Händlergunst; "Nächste Lehrer" als
  Tabelle in drei Spalten (Beruf, Lehrer und Zone, Kartenknopf), soweit Amisia Lehrer mit Ort kennt. Ein Klick auf
  einen Beruf öffnet seine Rezepte wie bisher.

**Amisia-Reiter Raid und Gilde:** Inhalt wie heute, nur im neuen Rahmen; Listen bekommen nach und nach
die Tabellenköpfe von F-148.

## Was es ausdrücklich nicht tut

- Keine QoL-, Jägertier- und Bücher-Reiter (Nutzer).
- Keine Grafiken, Titelbilder, Wappen, Karten oder Texte des Vorbilds; fehlt im Client ein Bild, bleibt
  die Stelle leer bzw. dunkel.
- Kein Wasserzeichen, kein Skin-Wechsel, kein "made by"-Text.
- Keine neuen Daten, Nachrichten oder gespeicherten Raid-Werte: nur Oberfläche.
- TBC und Era (D-57) bekommen denselben Rahmen, aber nur die Reiter, die es dort heute gibt.

## Abläufe

1. `/amisia`: Bildkopf, Reiter oben, links die Leiste des zuletzt offenen Reiters.
2. Klick auf "Dungeons & Raids": Leiste zeigt Dungeons/Raids und die Stufenbereiche, rechts die Tabelle.
3. Klick auf "Stufe 20 – 29" links: die Tabelle springt zum Bereich. Klick auf "Zone": sortiert nach Zone.
4. Klick auf "Schattenfang": Detailseite mit Reitern; Zurück führt zur Tabelle an dieselbe Stelle.
5. Klick auf "Raid": Leiste mit Übersicht, Aufstellung, Soft-Reserves …, rechts die gewohnte Seite.

## Abnahmekriterien

- Wenn das Fenster offen ist, dann stehen oben der Bildkopf mit Logo und die Reiter Ausrüstung,
  Dungeons & Raids, Berufe, Talente, Raid, Gilde und das Zahnrad, und es gibt keine Reiter QoL,
  Jägertiere oder Bücher.
- Wenn du einen Reiter klickst, dann zeigt die linke Leiste dessen Kopf mit Symbol und seine Seiten,
  und die zuletzt gewählte Seite des Reiters öffnet sich.
- Wenn du "Dungeons" öffnest, dann siehst du eine Tabelle mit den Spalten Dungeon, Stufe, Gebiet, Zone,
  Schlüssel, Quests, Aktionen, gruppiert nach Stufenbereichen, und ein Klick auf einen Spaltenkopf
  sortiert.
- Wenn du links auf einen Stufenbereich klickst, dann springt die Tabelle dorthin.
- Wenn du auf das Karten-Symbol einer Zeile klickst, dann wird ein Wegpunkt zum Eingang gesetzt.
- Wenn du das Fenster breiter ziehst, dann wächst die Spalte Dungeon/Zone mit, Kopf und Reiter bleiben
  ganz.

## Sonderfälle

- **Bosskampf:** nur Oberfläche, keine geschützten Frames; Reiterwechsel geht auch im Kampf.
- **Raider-Ansicht:** Offiziersseiten fehlen in der Leiste; ein Reiter ohne sichtbare Seite fehlt.
- **Gespeicherte Werte:** `settings.window.tab`/`pages` gelten weiter, die Gruppen werden auf die neuen
  Reiter umgeschrieben (`char` → `gear`/`talents`/`prof`, `world` → `dungeons`, Rest bleibt).
- **Kleiner Bildschirm:** Mindestbreite steigt auf ~900, weil sieben Reiter nebeneinander passen müssen;
  die Höhe wie D-71.
- **Englischer Client:** alle neuen Texte in `L[...]` und `enUS_core.lua`.
- **Kein Titelbild im Client für eine Instanz:** dunkle Fläche mit dem Namen.

## Missbrauch/Vertrauen

Nichts. Nur Oberfläche, nichts wird gesendet.

## Daten

- `ns.PANEL_GROUPS` werden die Reiter: `gear`, `dungeons`, `prof`, `talents`, `raid`, `guild`, `amisia`
  (Zahnrad). Jede Seite bekommt ihr neues `group`, Symbol und (wo nötig) `sections` für die
  Sprungmarken.
- `settings.window.tab`: einmaliger Umzug der alten Gruppenschlüssel (Sonderfälle).
- `settings.bis.dsort`: Spalte und Richtung der Dungeon-Tabelle.
- Theme: neuer Block `T.HUB` (Rahmen, Kopf, Reiter, Leiste, Tabelle); `T.DCARD` fällt weg.
- ARCHITECTURE (MainFrame, Registry, Dungeons), DECISIONS: neue D-73 ersetzt D-68/D-70 in der
  Navigation und D-69/D-72 bei den Kacheln.

## Offene Fragen

1. **Reiter:** `Ausrüstung · Dungeons & Raids · Berufe · Talente · Raid · Gilde · ⚙`? Vorschlag: ja.
   Quests und Karte gehen unter Dungeons & Raids, Schriftrollen unter Berufe, Feedback/Über in den
   Kopf bzw. unter ⚙.
2. **Name im Kopf:** "Amisia" und darunter "LOOT · RAID · GEAR"? Oder ein anderer Untertitel?
3. **Kopfbild:** ein Ladebild des Clients (z. B. Kalimdor/Östliche Königreiche), zugeschnitten und nach
   rechts ausgeblendet? Vorschlag: ja, mit Prüfung im Spiel, ob Forever die Ladebilder hat. Sonst dunkler
   Verlauf mit Logo.
4. **Ausrüstung und Talente "genau wie":** Schick mir bitte je ein Foto der Reiter "Armory" und "Talent
   Trees" des Vorbilds, dann schreibe ich F-149/F-150 genau danach.
5. **Reihenfolge:** Vorschlag: zuerst die noch nicht committeten Journal-Schritte 3–5 (F-146) sichern,
   dann 1. Rahmen, Kopf, Reiter, Leiste, Fußzeile; 2. Dungeons & Raids als Tabelle; 3. Ausrüstung;
   4. Talente. Jeder Schritt einzeln getestet, mit Snapshots vorher/nachher.

## Entscheidungen

- 2026-11-08, beim Bauen der Berufe (D-78): Kacheln bei 602 px zu dritt (vier passen nicht), bei breitem Fenster
  bis zu vier; ohne gewählte Ansicht öffnet die Seite die Übersicht; "Nächste Lehrer" entfällt, weil Amisia keine
  Lehrer mit Ort kennt; der Berufswähler der Seite bleibt.

- 2026-11-08, Nutzer schickt die Fotos der Reiter Armory, Talent Trees und Professions: "mach gear so wie bei
  [dem Vorbild]", "Talente auch", "berufe auch". Damit gilt Frage 4; die Teile oben (D-75 bis D-78) sind danach
  festgelegt. Neue Features F-149 Ausrüstung, F-150 Talente, F-151 Berufe.
- 2026-11-08, beim Bauen des Teils Ausrüstung (D-77): Das Modell der Seite baut derselbe Bauer wie das Fenster
  Ausrüstungsziele; das Quadrat neben einem Platz zeigt die Verzauberung des angelegten Items (geplante speichert
  Amisia nicht); über der eigenen Stufe rechnet die Liste auf der oberen Stufe; Hemd und Wappenrock zeigen nur, was
  angelegt ist; der Filtertrichter des Fotos entfällt (die Quellen-Schalter stehen auf der Seite Ausrüstung); die
  Stufenfelder stehen ohne das Wort "Stufe" (ihr Tooltip nennt es) und der Reiter "Vorschläge" führt aus den Sets zurück,
  damit der Name des Platzes in 602 Breite passt.

- 2026-11-08, Nutzer: "Passt, los". Damit gelten die Vorschläge zu den Fragen 1 bis 3 und 5; Frage 4 wartet auf
  die Fotos der Reiter Armory und Talent Trees. Die Journal-Schritte 3 bis 5 sind vorher committet (d4f752e).
- 2026-11-08, beim Bauen von Schritt 1 (D-73):
  - Das Suchfeld steht als Feld im Kopf (statt einer Lupe), seine Treffer ersetzen die Leiste wie bisher.
  - Die Fußzeile trägt links den Aufnahmezustand mit seinem Menü, rechts Ansicht und Version.
  - Die Talente sind ein eigener Reiter, auch wenn er nur die Seite und den Talentrechner hat.
  - Die Mindestbreite bleibt 806: die sieben Reiter passen hinein.
- 2026-11-08, Nutzer: "Schritt 2 bauen". Beim Bauen (D-74):
  - Die Kopfzeile behält die Reihenfolgen Level/Wert/Kette; nur in Level gibt es die Stufenbereiche, ein Klick auf einen
    Spaltenkopf stellt auf Level.
  - "Neu" für Forever-Instanzen und das Warnzeichen entfallen: unsere Daten kennen beides nicht.
  - Das Gebiet kommt aus einer Liste der Zonen von Allianz und Horde, weil der Client es nur für die eigene Zone nennt.
  - Die Raids sind nach Größe gruppiert; die Leiste nennt dort die Größen.
- 2026-11-08, beim Bauen der Talente (D-76):
  - Die Aktionen sind Marken der Leiste mit Gossip- und Notizsymbolen des Clients; "Eigene laden" steht nur bei der eigenen Klasse. "Plan zurücksetzen" heißt "Plan leeren": der längere Name passt neben dem Symbol nicht in die Leiste.
  - "Build exportieren" markiert den Code im Feld für Strg+C (keine Zwischenablage für Addons); "Build importieren" leert das Feld für den Code oder Link.
  - Der Knopf "Talentrechner" der Seite entfällt: die Leiste hat seine Zeile. Stufe und Talentiert stehen unten links, das Feld Code in der Mitte.
  - Jeder Baum zeigt sein Drittel des Klassenbilds, auf seine Form zugeschnitten; die Seite wächst mit dem Fenster.
  - Das Fenster Talentrechner behält seine Bedienung (es hat keine Leiste), dazu die Zeile der Punkte.
