# Spec: Raid-Rollen (Haupttanks, Assistenten, Plündermeister)

Stand: 2026-11-10 · Status: freigegeben (Nutzer 2026-11-10 auf die Liste der neun Punkte: "1,2,3,5,8,9") ·
Feature: F-165

## Ziel

Der Raidleiter setzt die festen Rollen eines Abends mit einem Klick statt im Raidfenster von Hand:
Haupttanks in ihrer Reihenfolge, Assistenten nach Namensliste, Plündermeister mit Plündergrenze. Gelöst
ist es, wenn nach "Rollen jetzt setzen" alle Genannten, die im Raid sind, ihre Rolle haben, oder der Chat
klar sagt, was das Spiel nicht erlaubt hat.

## Was es tut

- Eine Ansicht "Rollen" auf der Seite Aufstellung (nur Offiziere, D-41), geöffnet mit dem Link "Rollen" in der
  Kopfzeile (wie "Vorlagen"; dort steht dann "Zurück"). Oben: "Setzt die Rollen im Raid, solange du Raidleiter
  bist. Namen mit Komma getrennt."
- Drei Listen, jede mit Schalter, Name, Textfeld und einer grauen Zeile darunter:
  - "Haupttanks, in Reihenfolge", daneben der Link "Aus dem Planer" (die Tanks, Rolle T, der gezeigten
    Nacht, die im Planer in einer Gruppe stehen, nach Gruppe geordnet);
  - "Assistenten";
  - "Plündermeister" (der Erste der Liste, der im Raid ist, bekommt es), daneben die Plündergrenze
    "Selten (grün)", "Rar (blau)", "Episch (lila)" (Standard Episch).
- Namen mit Komma, "Vorname Nachname" wie im Spiel, aufgeräumt wie die Namen der Aufstellung (keine
  Ziffern, doppelte weg), höchstens 10 pro Liste; was wegfällt, sagt eine Zeile ("Assistenten: 2 Namen, 1
  weggelassen ...").
- Die graue Zeile: "3 Namen, 2 im Raid, 1 haben es schon.", "Bekommt es: Cora Wind-Tal, ab Episch (lila).",
  "Aus: wird nicht gesetzt.", außerhalb eines Raids "3 Namen; im Raid setzt Amisia sie.".
- Der rote Knopf "Rollen jetzt setzen" (rechts in der Zeile unter den Zählungen): befördert die Genannten im Raid,
  die noch nicht Assistent sind; setzt die Genannten im Raid als Haupttank, der Reihe nach; stellt
  Plündermeister mit dem ersten Genannten im Raid und die Plündergrenze ein. Eine Zeile im Chat fasst
  zusammen: "Rollen: Assistenten: 1 befördert, 1 schon Assistent, 1 nicht im Raid · Haupttanks: 1 gesetzt,
  1 schon Haupttank · Plündermeister: Cora Wind-Tal, ab Episch (lila)."
- Ohne Führung, im Kampf oder außerhalb des eigenen Raids steht der Grund auf dem grauen Knopf ("Nur als
  Raidleiter", "Nicht im Kampf", "Nur im Raid") und rot in der Zeile darüber.
- Schalter "Automatisch setzen, wenn jemand beitritt" (aus): als Raidleiter 2 Sekunden nach einer Änderung
  der Gruppe dasselbe für die neu Beigetretenen, einmal pro Name und Raid, nicht im Kampf; eine Zeile nur,
  wenn es etwas gesetzt hat ("Rollen: Assistenten: 1 befördert.").
- Lässt das Spiel einen Teil nicht zu (Meldung ADDON_ACTION_FORBIDDEN oder _BLOCKED für Amisia), sagt der
  Chat einmal "Haupttanks: Das Spiel lässt Addons das nicht setzen. Setze sie im Raidfenster von Hand."
  (ebenso für Assistenten und Plündermeister), die graue Zeile zeigt es, und Amisia versucht diesen Teil
  bis zum nächsten /reload nicht mehr.
- `/amisia selbsttest gruppe` meldet unter "Rollen: Haupttank, Plündermeister", welche Funktionen das
  Spiel hat (nur nachgeschlagen, nicht aufgerufen).

## Was es ausdrücklich nicht tut

- Kein Herabstufen, kein Entfernen eines Haupttanks oder Assistenten, kein Zurückstellen der Plündermethode:
  es fügt nur hinzu.
- Keine Raidsymbole auf Spielern, keine Haupt-Assistenten-Markierung.
- Keine Nachricht an andere Amisia-Clients; jeder Offizier hat seine eigenen Listen.
- Die Lootregeln (Raid/LootRules.lua) bleiben, wie sie sind.

## Abläufe

- **Vor dem Raid:** Offizier öffnet Aufstellung, klickt oben "Rollen", tippt die Namen ein (Enter oder Feld verlassen
  speichert), klickt "Aus dem Planer" für die Tanks, wählt die Plündergrenze.
- **Im Raid als Leiter:** "Rollen jetzt setzen"; der Chat sagt, was gesetzt wurde. Mit dem Schalter
  "Automatisch" bekommen Nachzügler ihre Rolle 2 Sekunden nach dem Beitritt.
- **Das Spiel verweigert:** das Spiel zeigt seine eigene Meldung über ein blockiertes Addon, Amisia sagt
  einmal die Zeile oben, der Raidleiter setzt diesen Teil von Hand.

## Abnahmekriterien

- Wenn du als Raidleiter Namen bei "Assistenten" einträgst und "Rollen jetzt setzen" klickst, dann sind die
  Genannten im Raid Assistent, und der Chat sagt "Rollen: Assistenten: N befördert ..." (braucht: Raid).
- Wenn du Haupttanks einträgst und "Rollen jetzt setzen" klickst, dann sind sie im Raidfenster Haupttank, oder
  der Chat sagt "Haupttanks: Das Spiel lässt Addons das nicht setzen. Setze sie im Raidfenster von Hand."
  (braucht: Raid).
- Wenn bei "Plündermeister" zwei Namen stehen und nur der zweite im Raid ist, dann wird er Plündermeister mit der
  gewählten Plündergrenze (braucht: Raid).
- Wenn du nur Assistent bist, dann steht auf dem Knopf "Nur als Raidleiter"; im Kampf "Nicht im Kampf".
- Wenn "Automatisch setzen, wenn jemand beitritt" an ist und ein Genannter beitritt, dann hat er nach etwa 2
  Sekunden seine Rolle (braucht: Raid).

## Sonderfälle

- Bosskampf und Kampf: nichts wird gesetzt; das automatische Setzen holt es nach dem Kampf nach.
- Nachnamen: ein Vorname allein trifft, wenn genau ein Raider so heißt (wie beim Sortieren).
- Plündermeister schon richtig: die Methode wird nicht noch einmal gesetzt (die Lootregeln laufen weiter), nur
  eine andere Plündergrenze.
- Alte Clients nennen die Plündermethode "master", neue eine Zahl: beides zählt.
- Eine Schlachtfeld- oder Dungeonbrowsergruppe ist kein eigener Raid: "Nur im Raid".
- Englischer Client: alle Zeilen auf Englisch.
- `/reload`: die Listen bleiben (gespeichert), das "vom Spiel verweigert" vergisst Amisia.

## Missbrauch/Vertrauen

Nur der eigene Client, nur Offiziere sehen die Ansicht, nur der Raidleiter kann es; keine Nachricht wird
gesendet oder empfangen. Die gespeicherten Listen werden beim Laden geprüft.

## Daten

- `AmisiaDB.lineup.roles = { assist = { on, list }, tanks = { on, list }, ml = { on, list }, q = 2/3/4, auto }`
  (höchstens 10 Namen je Liste), geprüft in `ns.LineupLoaded`.
- Keine Einstellung, keine Nachricht, kein Export.
- Client: `C_PartyInfo.PromoteToAssistant` (sonst global), `SetPartyAssignment("MAINTANK", "raidN")`,
  `GetPartyAssignment`, `C_PartyInfo.SetLootMethod` (sonst global `SetLootMethod("master", Name)`),
  `SetLootThreshold`, `GetLootThreshold`, die Ereignisse `ADDON_ACTION_FORBIDDEN` und `ADDON_ACTION_BLOCKED`.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-10: Nutzer auf die Liste der neun Punkte: "1,2,3,5,8,9" -> Punkt 1 wie oben. D-95.
- Annahme (nicht gefragt): die Listen liegen unter `AmisiaDB.lineup.roles`, nicht in den Einstellungen, weil die
  Ansicht der einzige Ort ist, an dem man sie bearbeitet; auch der Schalter "Automatisch" liegt dort.
- Annahme (nicht gefragt): die Schalter der drei Listen stehen anfangs an (eine leere Liste tut nichts).
- Annahme (nicht gefragt): "Aus dem Planer" nimmt die gezeigte Nacht (meist heute).
- Annahme (nicht gefragt): "Rollen" ist ein Link in der Kopfzeile statt eines vierten Reiters neben Abgleich, Planer
  und Einladen: die Zeile der Reiter hat in der Ansicht "Einladen" mit "bis <Rang>", "Gilde einladen", "Nochmal
  einladen" und "Alle einladen" keinen Platz mehr (Seite 602 breit, die Layoutregeln fanden Überlappungen).
- Annahme (nicht gefragt): Haupttanks werden über die Raid-Einheit gesetzt (`raid3`), nicht über den Namen.
- Annahme (nicht gefragt): das automatische Setzen gibt den Plündermeister nur dem, der gerade beitritt (oder
  beim ersten Lauf in einem Raid); einen schon anwesenden Plündermeister setzt nur der Knopf.
