# Spec: Hub mit Reitern oben, Bildkopf und Tabellenlisten

Stand: 2026-11-08 · Status: freigegeben ·
Feature: F-147 (Fenster), F-148 (Dungeons & Raids als Tabelle), F-149 (Ausrüstung), F-150 (Talente)

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

**Ausrüstung (F-149) und Talente (F-150)** — "genau wie" das Vorbild; dafür brauche ich je ein Foto
dieser Reiter des Vorbilds (Frage 4). Bis dahin: nur in den neuen Rahmen setzen, Inhalt wie heute.

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

