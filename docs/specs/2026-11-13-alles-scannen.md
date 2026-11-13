# Spec: Alles Fehlende scannen

Stand: 2026-11-13 · Status: freigegeben (Nutzer 2026-11-13 auf der Seite Gilde > Werkzeuge: "wie können wir
die werkzeuge und das scannen und übermittel der daten verbesserm"; von sieben Vorschlägen erst 1 bis 3 (F-186),
dann "mach alle aber nach deinen vorschlag". Dies ist Vorschlag 4: "Ein Knopf 'Alles Fehlende scannen': Heute
startest du Ausrüstung, Quests und NPCs einzeln, und ein Scan, der in einer Instanz anhält, bleibt stehen, bis du
ihn von Hand fortsetzt. Mit dem Knopf würde Amisia die drei Scans nacheinander abarbeiten, in Instanzen und im
Kampf pausieren und danach von selbst weitermachen. Nach einem neuen Spiel-Build würde es von sich aus melden,
dass es Neues zu scannen gibt.") · Feature: F-188

## Ziel

Heute startet der Spieler Ausrüstung, Quests und NPCs einzeln, und ein Scan, den eine Instanz anhält, bleibt
stehen, bis er ihn von Hand fortsetzt. Gelöst ist es, wenn ein Klick alles Offene nacheinander scannt, nach
Instanz, Kampf und Kampfsperre von selbst weitermacht und ein neuer Spiel-Build sich im Chat meldet.

## Was es tut

- **Gilde > Werkzeuge**, über den vier Zeilen (Kopfzeile der Seite): links "Noch offen: Ausrüstung, Quests,
  NPCs." bzw. "Nichts offen.", rechts der ruhige Link "Alles Fehlende scannen" (kein roter Knopf, D-67; grau
  mit Tooltip "Es läuft schon ein Scan", solange ein Scan von Hand läuft; ohne Offenes kein Link).
- Läuft die Reihe: "Alles Fehlende: Ausrüstung läuft, danach Quests, NPCs." (wartet sie: "... wartet, danach
  ..."; im letzten Schritt "..., danach ist alles gescannt."), rechts "Anhalten". Die Zeilen zeigen ihren
  eigenen Stand wie bisher.
- **Was offen ist**, sagt jeder Scan selbst, mit dem, was er schon führt (keine zweite Buchführung):
  - Ausrüstung: die Liste des Ausrüstungsplaners (`/amisia scan gear`), offen, bis sie unter diesem Build ganz
    gefragt ist; die Items ohne Antwort ("Offene wiederholen") kommen ans Ende, wenn es welche gibt.
  - Quests: die Questliste des Clients (`Data/ScanLists.lua`, D-104), offen, solange `scan.quests.done` fehlt.
  - NPCs: nur Phase A (die NPCs unserer Daten), offen, solange `scan.npcs.doneA` fehlt. Phase B (neue NPCs per
    Nummer suchen, Stunden) gehört nie dazu: sie bleibt die eigene Wahl in der Zeile NPCs nach ihrer Frage.
    Ein Client ohne NPC-Namen (Urteil "none") hat nichts offen.
  - Ein fertiger Scan bekommt einen Stempel: Client-Build und Build der mitgelieferten Listen. Ein Scan, der
    unter einem anderen Build oder mit anderen Listen fertig wurde, ist wieder offen und fragt seine Liste von
    vorn (Quests ab der ersten, NPCs Phase A; die Ausrüstungsliste läuft ohnehin ganz).
- **Pause und weiter von selbst**, nur solange die Reihe läuft: hält eine Instanz den Scan an (wie bisher),
  geht er etwa 5 Sekunden nach dem Verlassen (`PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`) weiter; kann ein
  Schritt im Kampf oder in der Kampfsperre nicht starten, startet er nach `PLAYER_REGEN_ENABLED`,
  `ENCOUNTER_END` oder `ADDON_RESTRICTION_STATE_CHANGED`. Nie in einer Instanz. Die Ausrüstungsliste beginnt
  nach einer Instanz neu (die Liste lebt nur im Lauf), Quests und NPCs machen weiter, wo sie waren.
- "Nächster Schritt" stimmt dazu: wartet die Reihe, steht dort "Alles Fehlende geht außerhalb der Instanz von
  selbst weiter." (nach dem Kampf, nach der Kampfsperre, gleich), nie "in seiner Zeile fortsetzen".
- Befehl `/amisia scan all` (auch `alles`), `/amisia scan all stop`; `/amisia scan stop` beendet auch die
  Reihe.
- **Neuer Spiel-Build:** ist der Client neuer als der Build der mitgelieferten Listen und wurden die Scans
  zuletzt unter einem anderen Build fertig, sagt einmal je Login (12 Sekunden danach) eine ruhige Chatzeile:
  "Neuer Spiel-Build: es gibt Neues zu scannen (Gilde > Werkzeuge, \"Alles Fehlende scannen\")." Nur im
  Expertenmodus, abschaltbar (Einstellungen, Werkzeuge, "Neuen Spiel-Build melden"). Es startet nichts.

## Was es ausdrücklich nicht tut

Kein Start ohne Klick, auch nicht nach einem neuen Build. Keine Phase B, kein Bereichs-Scan per Nummer. Die
Reihe überlebt kein `/reload` und keinen Login. Keine schnelleren Raten: die Scans fragen so schnell, wie die
Einstellungen und der Client es erlauben. Die Übernahme der Daten bleibt, wie sie ist: erst nach dem Ausloggen
und dem Datenbau des N100 sind sie im Addon.

## Abläufe

1. Der Spieler öffnet Gilde > Werkzeuge: "Noch offen: Ausrüstung, Quests, NPCs." und "Alles Fehlende scannen".
2. Klick: "Alles Fehlende: Ausrüstung läuft, danach Quests, NPCs."; die Zeile Ausrüstung zeigt "Läuft: ...".
3. Ausrüstung fertig: eine Sekunde später startet der Quest-Scan von selbst.
4. Er geht in einen Dungeon: der Quest-Scan hält an, "Nächster Schritt: Alles Fehlende geht außerhalb der
   Instanz von selbst weiter.". Draußen geht er nach etwa 5 Sekunden weiter.
5. Danach NPCs Phase A, am Ende die Items ohne Antwort; Chat: "Alles Fehlende scannen: fertig. Ausloggen oder
   /reload, damit es gespeichert wird."; oben "Nichts offen.".
6. Neuer Spiel-Build: beim Login die Chatzeile; auf der Seite sind die drei Scans wieder offen.

## Abnahmekriterien

- Wenn du Gilde > Werkzeuge öffnest und Scans offen sind, dann steht oben "Noch offen: ..." mit dem Link "Alles
  Fehlende scannen"; ist nichts offen, steht dort "Nichts offen." ohne Link.
- Wenn du "Alles Fehlende scannen" klickst, dann steht oben "Alles Fehlende: Ausrüstung läuft, danach Quests,
  NPCs." und die Scans laufen nacheinander, ohne weiteren Klick.
- Wenn du während der Reihe in einen Dungeon gehst, dann steht "Nächster Schritt: Alles Fehlende geht außerhalb
  der Instanz von selbst weiter.", und draußen läuft der Scan nach wenigen Sekunden von selbst weiter.
- Wenn du in einer Zeile oder oben "Anhalten" klickst (oder `/amisia scan stop`), dann ist die Reihe aus und
  nichts startet von selbst wieder.
- Wenn der Client einen neuen Build hat und die Daten des Addons älter sind, dann steht beim Login einmal "Neuer
  Spiel-Build: es gibt Neues zu scannen ..." (nur im Expertenmodus; abschaltbar in Einstellungen, Werkzeuge).

## Sonderfälle

- `/reload` und Login: die Reihe ist vergessen (nur in der Sitzung); die Seite bietet den Link wieder an und
  sagt, was noch offen ist ("Noch offen: Quests, NPCs."). Ein angehaltener Quest- oder NPC-Scan macht beim
  nächsten Klick weiter, wo er war.
- Ein Scan, den der Spieler von Hand startet, während die Reihe wartet: die Reihe wartet, bis er endet; hält er
  ihn von Hand an, ist die Reihe aus. Läuft beim Klick schon ein Scan von Hand, startet die Reihe nicht.
- Ein Schritt, den sein Scan ablehnt (andere Sprache mit wartenden Einträgen, Client antwortet nicht auf
  Quest-Abfragen, keine NPC-Namen): seine Chatzeile, dann der nächste Schritt.
- Scans, die vor diesem Feature fertig wurden, haben keinen Stempel: beim Login gelten sie als unter dem
  jetzigen Build fertig (sonst wären sie gleich wieder offen).
- Englischer Client: alle Texte übersetzt. Nicht Forever: das Modul lädt nicht (wie die Scans).

## Missbrauch/Vertrauen

Nichts: keine Nachricht, kein fremder Inhalt; nur eigene Daten und eigene Scans.

## Daten

Neu gespeichert: der Stempel `"<Client-Build>/<Build der Listen>"` (`SB.Stamp()`) in `scan.gear` (die
Ausrüstungsliste ganz gefragt), `scan.quests.stamp` (mit `done`) und `scan.npcs.stamp` (mit `doneA`). Die Reihe
selbst nur im Speicher. Einstellung `tools.scanNotice` (Standard an). Befehlswort `all`/`alles` von `/amisia
scan`. Internes Ereignis `SCAN_ENDED` (`ns.Fire`: Lauf "gear", "retry", "list", "range", "quests", "npcs"; Art
"done", "instance", "stop", "fail"). Modul `Collect/ScanAll.lua` (`ns.ScanAll`), neu `ns.ScanGear`,
`ns.ScanGearOpen`, `QS.Open`/`QS.StartOpen`, `NS_.Open`/`NS_.StartOpen`, `SB.Stamp`, `SB.BuildNumber`,
`SB.ListsClient`. Keine Nachricht, kein Export. Entscheidung D-120.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-13: "mach alle aber nach deinen vorschlag".
- Annahme (nicht gefragt): Phase B der NPCs gehört nicht zu "Alles Fehlende". Grund: der Nutzer will, was ein
  neuer Build nötig macht, keinen blinden Lauf über alle Nummern; Phase B dauert Stunden und fragt heute vorher
  (W.Confirm). Sie bleibt in der Zeile NPCs.
- Annahme (nicht gefragt): die Reihe lebt nur in der Sitzung. Grund: die einfachste ehrliche Regel; nach einem
  Login soll nichts von selbst starten, und die Seite sagt, was noch offen ist.
- Annahme (nicht gefragt): ein Link statt eines roten Knopfs. Grund: die eine rote Aktion der Seite bleibt
  "Drops für die Website" (D-67, `tools/ui_red_budget.json` 1); der Link steht in der Kopfzeile der Seite.
- Annahme (nicht gefragt): "älter" heißt: die Build-Nummer der mitgelieferten Listen (`Data/ScanLists.lua`,
  Feld `client`, derselbe Build wie in `Data/ScanDone.lua`) ist kleiner als die des Clients. Die Listen statt
  `ScanDone` lesen, weil das Aufräumen beim Login `ScanDone` aus dem Speicher wirft (D-34) und die Listen ohnehin
  die Grundlage der Scans sind.
- Annahme (nicht gefragt): "fertig und übernommen" (F-186) und "fertig, wartet auf die Übernahme" sind beide
  nicht offen: zu scannen gibt es dann nichts.
- Annahme (nicht gefragt): die Chatzeile kommt einmal je Login, solange die Bedingung gilt (nicht nur einmal je
  Build): sie erinnert, bis gescannt ist; der Schalter stellt sie ab.
- Annahme (nicht gefragt): 5 Sekunden Wartezeit nach dem Ende des Grundes, 1 Sekunde zwischen zwei Schritten.
