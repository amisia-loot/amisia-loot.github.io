# Spec: Dungeonquest-Geber auf der Weltkarte

Stand: 2026-11-11 · Status: freigegeben (Nutzer 2026-11-11: Punkt 5 der angebotenen Liste) ·
Feature: F-179

## Ziel

Auf der Weltkarte des Spiels sieht der Spieler, ohne Amisia zu öffnen, welche Questgeber Dungeon- oder
Raidquests haben, die er jetzt oder bald annehmen kann, für welchen Dungeon und welche Stufe, und kommt mit
einem Klick auf die Seite dieses Dungeons. Gelöst ist es, wenn er in einer Zone die Geber mit "!" sieht und
der Klick die Quests des Dungeons in Amisia zeigt.

## Was es tut

- **Pin je Geber und Ort** auf der Zonenkarte (Modul `Gear/QuestGiverPins.lua`, eine Pin-Art "giver" auf
  Amisias eigener Kartenebene, D-64): das gelbe "!" des Spiels (`Interface\GossipFrame\AvailableQuestIcon`,
  16 px) mit einem kleinen Abzeichen unten rechts, dem Dungeon- oder Raid-Zeichen des Questlogs
  (`questlog-questtypeicon-dungeon`/`-raid`, sonst das Dungeon-/Raid-Zeichen der Kartenlegende, sonst keins).
  Der Pin steht etwas rechts oberhalb des Punktes. Sind alle Quests des Gebers erst "bald", ist das "!" grau.
- **Welche Quests:** jede Quest der Dungeon-Listen der Questdaten (`DUNGEON_QUESTS.D`), deren eigener Stand
  (`D.OwnQuestState`, F-178) "kann annehmen" ist, oder "noch nicht", wenn allein die Stufe fehlt und es höchstens
  zwei Stufen sind (die Planer-Grenze "bald"). Nie: erledigt, im Log, nie möglich (Fraktion, Klasse, Volk, eine
  ausschließende Quest), eine offene Vorquest, schon grau für die eigene Stufe, Start im Dungeon, Start durch
  einen Gegenstand, kein bekannter Ort des Gebers (die Scan-Quests von F-177).
- **Tooltip:** Name des Gebers (aus den Daten, wo der Sammler ihn selbst sah auf Deutsch), Zone und
  Koordinaten, je Quest eine Zeile "[D35] <Titel>" (Raid "[R60]", unbekannte Stufe "[D?]") in der Farbe des
  Questlogs, rechts der Dungeon (und "· ab 18" für eine erst bald mögliche). Mehr als sechs: fünf und
  "... und N weitere". Darunter "Klick: <Dungeon> in Amisia öffnen. Shift-Klick: Ziel setzen." und
  "Rechtsklick: ausblenden.".
- **Klick:** links öffnet die erste Quest nach Stufe auf der Seite Dungeons (Teil Quests, ihr Questweg); eine
  Raidquest die Seite Raids, Teil Zugang. Die Weltkarte bleibt vorn (F-011). Shift-Klick setzt das Ziel auf den
  Geber; Rechtsklick: "In Amisia öffnen" je Dungeon, "Ziel setzen", "Dungeonquest-Geber ausblenden".
- **Einstellung** im Abschnitt "Karte und Wegpunkt" neben "Eingänge auf der Karte":
  `map.questGivers` "Dungeonquest-Geber auf der Karte", an; der Tooltip sagt, dass man es ausschalten kann,
  wenn ein anderes Addon die Questgeber schon zeigt.

## Was es ausdrücklich nicht tut

- Nichts auf der Kontinentkarte: in Städten und Lagern stehen viele Geber auf wenigen Punkten, auf dem
  Kontinent würden sie zum Teppich; dort zeigen die Eingänge, wohin es geht.
- Keine Quests außerhalb der Dungeon-Listen (keine gewöhnlichen Zonenquests), keine Vorquests als eigene Pins
  (das tun die Pins für Quest-Schritte, `map.pinsQuests`), kein Pin für Quests, die im Dungeon oder durch einen
  Gegenstand beginnen.
- Keine Pins der Karte selbst (kein Datenanbieter, kein Pin-Pool, kein Hook, D-64); nichts gespeichert,
  nichts gesendet.

## Abläufe

1. Der Spieler öffnet die Weltkarte auf seiner Zone. Amisias Ebene zeichnet beim nächsten Bild die Pins der
   Zone; ein Zonenwechsel der Karte zeichnet neu.
2. Maus auf einen Pin: der Tooltip nennt Geber, Ort und Quests mit Stufe und Dungeon.
3. Klick: das Amisia-Fenster öffnet unter der Karte auf dem Dungeon, Teil Quests, mit dem Questweg der ersten
   Quest. Im Kampf, wenn das Fenster nicht kommt, eine Chatzeile.
4. Nimmt er eine Quest an, gibt eine ab, bricht eine ab oder steigt eine Stufe, ändern sich die Pins eine
   halbe Sekunde später (nur während die Karte offen ist; sonst beim Öffnen).

## Abnahmekriterien

- Wenn du (Allianz, Stufe 20) die Weltkarte auf Sturmwind öffnest, dann steht bei Shoni ("Shoni the Shilent" in den Daten) ein kleines
  gelbes "!" mit Dungeon-Zeichen rechts oberhalb ihres Punktes; die Maus darauf zeigt zwei Zeilen, "[D20] ..."
  mit den Todesminen und "[D30] ..." mit Gnomeregan, und "Klick: Die Todesminen in Amisia öffnen".
- Wenn du auf den Pin klickst, dann öffnet Amisia unter der Karte die Todesminen, Teil Quests, mit dem
  Questweg der Quest.
- Wenn du eine der Quests annimmst, dann verschwindet ihre Zeile (oder der Pin) nach einer halben Sekunde.
- Wenn du die Karte auf den Kontinent stellst, dann stehen dort keine dieser Pins.
- Wenn du "Dungeonquest-Geber auf der Karte" ausschaltest (Einstellungen oder Rechtsklick), dann sind die
  Pins weg, die anderen Pins bleiben.

## Sonderfälle

- Bosskampf, Kampf: der Klick öffnet im Kampf nichts Geschütztes; kommt das Fenster nicht, eine Chatzeile.
- Client auf Englisch: Titel und Namen wie die Seite Dungeons sie zeigt (Client-Titel, Scan-Titel, Daten).
- Fehlt dem Client das Questlog-Abzeichen, steht das Dungeon-Zeichen der Kartenlegende da, fehlt auch das,
  das "!" allein (`/amisia selbsttest` nennt fehlende Atlanten).
- Ein Questaddon zeigt am selben Geber sein eigenes Zeichen: Amisias Pin ist kleiner und versetzt; sonst
  ausschalten. Die Pins für Quest-Schritte (`map.pinsQuests`) können am selben Geber mittig stehen.
- Stufenaufstieg: die Stufe wird beim Zeichnen gelesen, nicht aus dem Zwischenspeicher der Questoptionen.
- Leere Questdaten oder keine Kartendaten: keine Pins, kein Fehler.

## Missbrauch/Vertrauen

Nichts. Es kommt nichts von anderen Spielern; Orte und Namen stammen aus den mitgelieferten Daten und dem,
was der eigene Client selbst sah.

## Daten

- Neue Einstellung `map.questGivers` (Abschnitt `map`, an), in `docs/ARCHITECTURE.md`.
- Kein neuer `AmisiaDB`-Schlüssel, keine Nachrichtenart, keine Exportzeile.
- Zwei neue Atlanten in der Erlaubtliste (`ns.Theme.ATLASES`) und im Selbsttest:
  `questlog-questtypeicon-dungeon`, `questlog-questtypeicon-raid`. Größen und Farben in `ns.Theme.GIVER_PIN`.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-11: Nutzer: "Dungeonquest-Geber auf der Weltkarte mit Stufe, Klick öffnet die Dungeonseite."
  (Punkt 5 der angebotenen Liste) -> gebaut wie oben, DECISIONS D-111.
- Annahme (nicht gefragt): Einstellung standardmäßig an (der Nutzer wollte das Feature).
- Annahme (nicht gefragt): "bald" heißt höchstens zwei Stufen, nur wenn allein die Stufe fehlt (dieselbe
  Grenze wie "bald" im Dungeon-Planer); eine offene Vorquest zeigt nie früh.
- Annahme (nicht gefragt): graue Quests (keine Erfahrung mehr, `D.GreyAt`) bekommen keinen Pin, sonst stünden
  auf Stufe 60 in jeder Stadt die Geber längst überholter Dungeons.
- Annahme (nicht gefragt): nur Zonenkarten; nichts auf dem Kontinent.
- Annahme (nicht gefragt): ein Pin je Geber und Ort, höchstens 40 je Karte, die niedrigsten Quests zuerst.
- Annahme (nicht gefragt): eine Raidquest öffnet die Seite Raids im Teil Zugang (die Raidseite hat keinen
  Teil Quests).
- Annahme (nicht gefragt): Shift-Klick setzt das Ziel, Rechtsklick hat ein Menü, wie bei den Eingängen.
- Annahme (nicht gefragt): Quests, die an einem Objekt beginnen, bekommen einen Pin mit dem Namen des Objekts.
- Annahme (nicht gefragt): neben den Pins für Quest-Schritte (gleiche Stelle möglich) bleibt alles, wie es ist;
  der versetzte kleine Pin hält beide lesbar.
