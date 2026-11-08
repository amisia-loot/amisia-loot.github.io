# Spec: Hauptfenster und Journal nach dem Vorbild

Stand: 2026-11-07 · Status: freigegeben ·
Feature: F-145 (Fenster), F-146 (Dungeon- und Raid-Journal)

## Ziel

Das Amisia-Fenster soll sich bedienen wie das Hub-Fenster des Vorbilds, aber im Forever-Classic-Rahmen
(D-68, D-69). Dungeons und Raid-Journal sollen den Aufbau des Journals des Vorbilds bekommen: Kacheln,
Filter, eine Detailseite mit Reitern und einen Fortschritt pro Lauf. Gelöst ist es, wenn man eine Instanz
mit zwei Klicks findet, im Dungeon sofort auf ihrer Seite landet und sieht, was noch fehlt.

Das Vorbild ist "All rights reserved": übernommen werden nur Aufbau und Verhalten. Code, Daten, Texte,
Karten und Grafiken kommen von uns oder aus dem Spielclient.

## Was es tut

**Fenster (F-145)**

- **Seitenleiste:**
  - Oben ein Kopf mit dem Amisia-Logo, dem Namen in Gold und der Version.
  - Darunter die Gruppen (Raid, Charakter, Welt, Gilde, Amisia) als goldene Überschriften in Großbuchstaben, getrennt durch die goldene Linie (`W.GoldRule`).
  - Jede Seite und jedes Seitenfenster ist eine Zeile mit Symbol und Namen. Die gewählte Zeile bekommt den Goldrand der Auktionshaus-Leiste.
  - Die Symbole sind Spielsymbole aus dem Client (Minimap-Verfolgung, Kartensymbole, Atlanten). Zauber- oder Gegenstandssymbole als Ersatz kommen nicht in Frage.
  - Was nicht passt, wird gescrollt; das ist Frage 1.
- **Breite:**
  - Der Griff unten rechts zieht jetzt Breite und Höhe, von 806 bis 1440 px Breite. Die Höhe bleibt bei 598–898 px.
  - Listen- und Detailseiten (`Scaffold:Detail`, `W.FillTo`) wachsen mit. Andere Seiten bleiben 602 px breit und stehen links.
  - Die Breite steht in `settings.window.w`. "Positionen zurücksetzen" setzt sie zurück.
- **Minimieren:**
  - Neben dem X sitzt der rote Knopf des Clients zum Verkleinern.
  - Er klappt das Fenster zu einer 214×36-Leiste im Tooltip-Rahmen zusammen: Logo, "Amisia" und der Name der offenen Seite.
  - Ein Klick auf die Leiste öffnet das Fenster wieder an derselben Ecke. Die Leiste lässt sich ziehen und hat ein eigenes X.
  - `/amisia` und das Minimap-Symbol öffnen das Fenster auch aus der Leiste. Nach einem `/reload` ist sie zu.

**Journal (F-146), für Dungeons und sinngemäß fürs Raid-Journal**

- **Startseite:**
  - Über den Kacheln: ein Suchfeld (sucht in Instanz, Zone, Boss, Beute und Quest), die Auswahl Alle / Passend / Quests und der Knopf "Wo bin ich".
  - Jede Kachel zeigt:
    - die getöteten Bosse dieses Laufs als "n/m";
    - die Zahl offener und abgabebereiter Quests;
    - bis zu zwei Schlüssel als Symbole (grau, wenn sie fehlen);
    - "Hier bist du" mit Goldrand, wenn man in der Instanz steht.
  - Kacheln weit außerhalb des eigenen Levels werden blass.
- **Öffnen:**
  - In einer Instanz öffnet das Journal direkt deren Seite.
  - Betritt man eine Instanz, während die Seite offen ist, springt sie dorthin.
- **Detailseite:**
  - Der Kopf bleibt wie in 2.62.0. Darunter kommen Reiter:
    - **Übersicht:** Bosse und Beute. Hier erscheinen "x/y Bosse" mit einem Balken, "Alle auf- und zuklappen" und "Lauf zurücksetzen".
    - **Karte**
    - **Quests**
    - **Wunschliste**
    - **Zugang:** nur, wenn die Instanz einen Schlüssel braucht.
  - Der letzte Reiter wird gemerkt.
- **Bosszeile:**
  - Ein rundes Porträt aus dem Modell des Bosses (die NPC-ID haben wir) und sein Level in Questfarbe.
  - Getötet heißt grauer Haken und entsättigt.
  - Rechtsklick öffnet: Auf der Karte zeigen / Als getötet markieren.
- **Lauf:**
  - Kills kommen aus ENCOUNTER_END und BOSS_KILL, die wir schon auswerten (Drops.lua, RaidIDs.lua).
  - Der Lauf fällt weg, wenn die Instanz zurückgesetzt wird oder man in eine frische Instanz kommt.
- **Karte:**
  - Die Karte der Instanz kommt aus dem Client (`C_Map.GetMapArtLayerTextures`).
  - Dazu kommen Ebenen mit Vor und Zurück, Zoom mit dem Mausrad und Ziehen.
  - Den Eingang zeigen wir als Pin. Bosspins gibt es, wenn wir Koordinaten haben (Frage 3).
- **Wunschliste:** die Wünsche und BiS-Teile des Charakters aus dieser Instanz, ein Klick springt zum Boss. Fällt ein gewünschtes Teil, kommt eine Meldung mit Ton.
- **Zugang:** pro Schlüssel eine Karte (nötig oder optional, vorhanden oder nicht) und die nummerierten Questschritte mit Wegpunkt.

## Was es ausdrücklich nicht tut

- **Fähigkeiten der Bosse:** Der Client hat keine Encounter-Journal-Tabellen für Forever, also haben wir keine Daten dafür.
- **Gruppenraster mit Questständen:** Es bräuchte eine neue Addon-Nachricht. Das kann später eine eigene Spec werden.
- **Routen zeichnen, Stempel, Teilen**
- **Journal über der Weltkarte, Dock und Mini-Fenster:** Hier besteht die Gefahr von Taint (D-62, D-64).
- **Speedrun-Timer, Spiele, Sprachpakete**
- **Wasserzeichen-Logo**
- **Freier Farbwechsel:** Der Rahmen bleibt Forever-Classic.
- **Gezeichnete Karten oder Titelbilder des Vorbilds:** Fehlt im Client eine Karte, steht dort "Keine Karte".

## Abläufe

1. Spieler öffnet `/amisia`: links der Kopf mit Logo, alle Gruppen mit Symbolzeilen. Er zieht das Fenster breiter; die Kacheln der Dungeons gehen auf vier Spalten.
2. Er klickt "Minimieren": das Fenster wird eine kleine Leiste; ein Klick, und es ist wieder da.
3. Er betritt den Kloster-Friedhof: die Dungeon-Seite springt auf ihn, Reiter Übersicht, "0/2 Bosse".
   Nach dem ersten Boss: Haken, "1/2"; auf der Startseite steht auf der Kachel "1/2" und "Hier bist du".
4. Reiter Karte: die Karte aus dem Client, Mausrad zoomt, Eingang als Pin.
5. Ein Teil aus der Wunschliste fällt: Meldung im Chat und Ton.

## Abnahmekriterien

- Wenn das Fenster offen ist, dann zeigt die Seitenleiste oben Logo und Version und jede Gruppe als Überschrift mit Symbolzeilen.
- Wenn man am Griff zieht, dann ändern sich Breite und Höhe in den Grenzen. Nach einem `/reload` bleibt die Größe, und Listenseiten nutzen die Breite.
- Wenn man auf Minimieren klickt, dann bleibt nur die Leiste. Ein Klick darauf öffnet das Fenster an derselben Stelle wieder.
- Wenn man eine Instanz betritt, dann öffnet die Dungeon- bzw. Raid-Seite deren Detailseite, und ein Boss-Kill setzt den Haken und zählt "x/y" hoch (braucht: Dungeon).
- Wenn man Suche oder Auswahl auf der Startseite nutzt, dann bleiben nur passende Kacheln.
- Wenn ein gewünschtes Teil fällt, dann kommt eine Meldung mit Ton (braucht: Dungeon).
- Wenn der Client eine Karte für die Instanz hat, dann zeigt der Reiter Karte sie mit Ebenen und Zoom.

## Sonderfälle

- **Bosskampf:**
  - Das Journal liest nur Ereignisse.
  - Minimieren und Größe sind ungeschützte Rahmen und gehen auch im Kampf.
  - Die Wunsch-Meldung nutzt keinen Chat, der im Encounter gesperrt ist; sie geht nur lokal raus.
- **Kleiner Bildschirm:** Breite und Höhe werden auf den Bildschirm begrenzt (wie die Höhe heute).
- **Englischer Client:** Alle Texte stehen in `L[...]` und `enUS_*`.
- **TBC und Era:** Die Journal-Seiten sind Forever-Daten. Auf den anderen Clients bleibt es bei dem, was `ns.GAME` heute zeigt (D-57).
- **Keine Kartendaten:** "Keine Karte". Fehlt die NPC-ID eines Bosses, steht dort sein Gegenstandssymbol statt des Porträts.
- **`/reload` mitten im Lauf:** Die Kills bleiben über die Instanz-ID erhalten.

## Missbrauch/Vertrauen

Nichts: Es gibt keine neue Nachricht und keinen Austausch. Die Wunsch-Meldung bleibt lokal.

## Daten

- **`settings.window.w`:** die gezogene Breite, nur gesetzt, wenn sie nicht der eigenen Breite entspricht.
- **`AmisiaDB.chars[<char>].run`:**
  - die Instanz und ihre ID;
  - die getöteten Encounter;
  - die Zeit.
- **`settings.journal.tab`:** der letzte Reiter.
- **Neue Datentabelle `DUNGEON_MAPS`:** Instanz → Ebenen (uiMapID, Name), aus `UiMapAssignment`/`UiMap`. Fehlt `UiMap` im Export, kommt es in `tools/export_db2.ps1` (D-03).
- **`DUNGEON_KEYS`:** Schlüssel und Questschritte als eigene Hand-JSON aus unseren Quest-Daten.
- Alles geht in ARCHITECTURE, eine neue Entscheidung D-70 (Breite der Seiten, Minimieren, Journal-Reiter) in DECISIONS.

## Offene Fragen

1. Gruppen in der Seitenleiste: alle offen mit Überschrift wie beim Vorbild (dann mit Scrollen), oder bleibt das Auf- und Zuklappen von 2.62.0? Vorschlag: alle offen; die Zeilen sind 21 px hoch, damit die meisten ohne Scrollen passen.
2. Reihenfolge: Vorschlag in fünf Schritten, jeder einzeln getestet:
   1. Seitenleiste
   2. Breite und Minimieren
   3. Journal-Start
   4. Detail mit Reitern, Lauf und Wunschliste
   5. Karte und Zugang
3. Bosspins auf der Karte: Koordinaten der Bosse gibt es in keiner unserer Quellen. Vorschlag: zuerst ohne Bosspins. Später lernt Amisia die Stelle eines Kills selbst (Spielerposition beim Kill), wie die Quest-Stellen.
4. Hat der Forever-Client überhaupt Dungeonkarten? Vorschlag: vor Schritt 5 einmal im Spiel `/dump C_Map.GetMapArtLayerTextures(<id>, 1)` für den Kloster-Friedhof; ich gebe dir die Zeile.

## Entscheidungen

- 2026-11-08, Nutzer: "Passt, Schritt 1". Damit gelten die Vorschläge zu allen vier Fragen:
  1. Alle Gruppen stehen offen untereinander, jede mit Überschrift; was nicht passt, wird gescrollt. Das Auf- und Zuklappen von 2.62.0 entfällt.
  2. Gebaut wird in fünf Schritten, jeder einzeln getestet. Schritt 1 ist die Seitenleiste.
  3. Die Karte kommt zuerst ohne Bosspins.
  4. Vor Schritt 5 wird im Spiel geprüft, ob der Client Dungeonkarten hat.
- 2026-11-08, beim Bauen der Schritte 3 bis 5 (Nutzer: "mach alle schritte fertig"):
  - Der Lauf liegt in `bis.chars[name].run` statt in `chars[].run`.
  - Der Reiter wird in `settings.bis.dpart`/`rpart` gemerkt statt in `settings.journal.tab`.
  - Die Meldung beim Drop eines Wunsches ist der bestehende Hinweis "Wunsch droppt!" mit Ton.
  - Einen Eingangspin auf der Instanzkarte gibt es nicht, weil Koordinaten innerhalb der Instanz fehlen.
  - Die Kartendaten (`maps`), Encounter-IDs (`enc`) und Schlüssel (`keys`) kommen über `tools/build_dungeons.py` in die Fakten. Die Schlüssel stehen in `tools/forever_dungeon_keys.json`. D-72.

