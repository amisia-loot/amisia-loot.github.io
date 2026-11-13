# Spec: Drop-Austausch in der Gilde sichtbar machen

Stand: 2026-11-13 · Status: freigegeben (Nutzer 2026-11-13 auf der Seite Gilde > Werkzeuge, deren Teil "Drop-Daten"
sagte "40 Kills (40 eigene, 0 gehörte), 33 Bosse, neuester Tag 2026-11-11, letzter Austausch noch keiner.": "wie
können wir die werkzeuge und das scannen und übermittel der daten verbesserm"; von sieben Vorschlägen erst 1 bis 3
(F-186), dann "mach alle aber nach deinen vorschlag". Dies ist Vorschlag 7: "Austausch in der Gilde sichtbar machen:
Heute steht auf der Seite nur 'letzter Austausch noch keiner'. Stattdessen würde sie zeigen, welche Gildenmitglieder
Drop-Daten teilen und wann zuletzt abgeglichen wurde, dazu ein Link 'Jetzt abgleichen'.") · Feature: F-189

## Ziel

Heute sagt die Seite nur "letzter Austausch noch keiner", und niemand sieht, ob der Drop-Austausch läuft und mit
wem. Gelöst ist es, wenn die Seite zeigt, welche Gildenmitglieder seit dem Einloggen Drop-Daten angekündigt haben,
wie weit man mit jedem gleich ist, wann dieser Client sich zuletzt angekündigt und zuletzt Kills bekommen hat, und
wenn ein Klick "Jetzt abgleichen" den Austausch sofort anstößt und danach sagt, was kam.

## Was es tut

- **Gilde > Werkzeuge, Teil "Drop-Daten", Zeile oben** (zwei Zeilen Text): "40 Kills (40 eigene, 0 gehörte), 33
  Bosse, neuester Tag 2026-11-11." und dahinter "Angekündigt vor 5 Min., zuletzt Kills empfangen 13.11. 14:02."
  ("Noch nicht angekündigt", "noch nie"). Ist Teilen aus: "Teilen ist aus: Amisia tauscht keine Drop-Daten mit der
  Gilde.". Nach "Jetzt abgleichen" steht dort "Abgleich läuft ..." und danach (fünf Minuten lang) das Ergebnis:
  "Abgleich: 3 Mitglieder haben geantwortet, 12 neue Kills." bzw. "Abgleich: niemand hat geantwortet (wer schon
  gleich ist, meldet sich nicht).". Die Worte "letzter Austausch" entfallen (auch in `/amisia drops`).
- **Zeile der Schalter:** links "Mit der Gilde teilen" wie bisher; rechts zwei ruhige Links und der rote Knopf:
  "Wer teilt (n)", "Jetzt abgleichen", "Drops für die Website".
- **"Wer teilt (n)"** zeigt an der Stelle der Liste je Instanz und Boss (dieselben 10 Zeilen mit Scrollbalken, die
  Seite wird nicht höher) die Mitglieder, das zuletzt gehörte zuerst: links der Name in Klassenfarbe (aus der
  Gildenliste) und grau "vor 12 Min. gehört, 40 Kills", rechts der Vergleich: "gleich", "du holst gerade", "hat
  mehr: wartet", "hat andere: wartet", "3 Kills geholt", "geholt, nichts Neues dabei", "hat weniger als du", "hat 5
  Kills von dir geholt", "hat andere: beim nächsten Abgleich", "fragt bei dir an". Die Maus auf einer Zeile zeigt
  die Ankündigung (Kills der letzten vier Wochen, neuester Tag) und wie viele Kills in beide Richtungen gingen.
  Der Link heißt dann "Zur Liste". Ohne Mitglied: "Noch niemand gehört" / "Noch kein Gildenmitglied mit
  Drop-Daten gehört (seit dem Einloggen)." und der Grund, wenn einer bekannt ist (Teilen aus, keine Gilde, in
  einer Instanz, im Kampf, Kampfsperre, Raid-Abgleich, Schlachtfeld).
- **"Jetzt abgleichen"** kündigt diesen Client sofort an (dieselbe DV-Zeile an die Gilde wie die automatische) und
  holt bei den Mitgliedern, die schon angekündigt haben und noch auf ihren gestreuten Start warten, sofort; den Rest
  macht der normale Austausch. Grau mit Tooltip-Grund: "Wieder in 40 s." (höchstens einmal in der Minute nach der
  letzten Ankündigung), "Der Abgleich läuft schon.", "Teilen ist aus.", "Du bist in keiner Gilde.", "In Instanzen
  tauscht Amisia keine Drop-Daten." usw., "Keine Kills der letzten vier Wochen zum Ankündigen." (und niemand zum
  Holen).
- Befehl `/amisia drops sync` (auch `abgleichen`): wie der Link; Chat "Abgleich gestartet: ..." bzw. "Abgleich geht
  gerade nicht: <Grund>", später das Ergebnis im Chat. `/amisia drops` nennt "zuletzt Kills empfangen" und "Wer
  teilt: n".

## Was es ausdrücklich nicht tut

Keine neue Nachricht, kein neues Feld: das Protokoll bleibt Drop-Protokoll 2, Clients mit 2.81.0 merken nichts.
Kein Mitglied wird gebeten, sich anzukündigen: wer vor dir online war und seitdem nichts Neues hat, kündigt erst
nach seinem nächsten eigenen Kill wieder an (alle 30 Minuten höchstens) und steht bis dahin nicht in der Liste.
Die Liste wird nicht gespeichert und nirgends hin gesendet; die öffentliche Datei der Seite (F-187) bleibt ohne
Namen. Keine Wiederholung ohne Klick, kein Umgehen der Grenzen von `Core/Comm.lua` und DropSync.

## Abläufe

1. Der Spieler öffnet Gilde > Werkzeuge: "... Angekündigt vor 3 Min., zuletzt Kills empfangen noch nie." und
   "Wer teilt (2)".
2. Klick "Wer teilt (2)": Fraktur "gleich", Kim "hat mehr: wartet". Klick "Zur Liste": wieder die Bosse.
3. Klick "Jetzt abgleichen": die Zeile sagt "Abgleich läuft ...", der Link ist grau. Bei Kim steht gleich "du holst
   gerade"; wer etwas anderes hat, holt bei diesem Client.
4. Frühestens 45 Sekunden nach dem Klick, sobald nichts mehr geholt wird und keine Anfrage auf ihre Antwort wartet
   (spätestens nach 3 Minuten): "Abgleich: 2 Mitglieder haben geantwortet, 12 neue Kills."; bei Kim "12 Kills
   geholt". Eine Minute nach der Ankündigung ist der Link wieder da.
5. Bei den anderen: sie hören die Ankündigung wie die automatische und holen, was ihnen fehlt.

## Abnahmekriterien

- Wenn du Gilde > Werkzeuge öffnest (Expertenmodus), dann steht unter "Drop-Daten" "Angekündigt vor ... Min." (oder
  "Noch nicht angekündigt") und "zuletzt Kills empfangen ..." statt "letzter Austausch".
- Wenn ein zweites Gildenmitglied mit Amisia nach dir einloggt (oder "Jetzt abgleichen" klickt), dann steht es
  nach wenigen Minuten unter "Wer teilt (1)" mit "vor ... gehört", seinen Kills und dem Vergleich (braucht: Gilde).
- Wenn du "Jetzt abgleichen" klickst, dann steht "Abgleich läuft ..." und nach etwa einer Minute "Abgleich: ...
  geantwortet, ... neue Kills." oder "niemand hat geantwortet"; ein zweiter Klick gleich danach ist grau mit
  "Wieder in ... s." (braucht: Gilde).
- Wenn du in einer Instanz bist oder Teilen aus ist, dann ist "Jetzt abgleichen" grau und der Tooltip nennt den
  Grund; "Wer teilt" ohne Mitglieder nennt ihn auch.
- Wenn du `/amisia drops sync` eingibst, dann steht im Chat "Abgleich gestartet: ..." und später das Ergebnis.

## Sonderfälle

- `/reload` und Login: die Liste ist leer ("seit dem Einloggen"), das Ergebnis vergessen; die automatische
  Ankündigung kommt wie bisher 60 bis 180 Sekunden nach dem Login.
- Keine eigenen Kills der letzten vier Wochen: nichts anzukündigen; wartet ein gehörtes Mitglied, holt der Klick
  bei ihm, sonst ist der Link grau ("Keine Kills der letzten vier Wochen zum Ankündigen.").
- Ein Mitglied, das nur fragt (holt bei dir, ohne selbst angekündigt zu haben: es hat keine Kills), steht mit
  "fragt bei dir an" bzw. "hat n Kills von dir geholt" und "vor ... gefragt" in der Liste.
- Kampf, Kampfsperre, Raid-Abgleich, Instanz, Schlachtfeld: der Link ist grau mit dem Grund; ein laufender Abgleich
  endet nach seiner Zeit mit dem, was bis dahin kam.
- Sehr große Gilde: höchstens 40 Mitglieder im Speicher (das am längsten nicht mehr gesehene geht).
- Englischer Client: alle Texte übersetzt. Nicht Forever: das Modul lädt nicht (wie DropSync).

## Missbrauch/Vertrauen

Die Liste nimmt nur Absender, die der Server setzt, in der Schreibweise der Gildenliste (`ns.TrustName`), und nur
nach `ns.TrustWait(name, "member")`: ein Fremder auf dem Gildenkanal erscheint nie. Was eine Ankündigung sagt, bleibt
unvertraut: Comm prüft die Form (`DV`), die Zahl der Kills wird auf 0 bis 999999 begrenzt, der neueste Tag nur
innerhalb der behaltenen Tage genommen; die Liste ist auf 40 begrenzt. "Jetzt abgleichen" sendet dieselbe DV-Zeile
wie die automatische, höchstens einmal in der Minute nach der letzten Ankündigung (jeder Empfänger verwirft ohnehin
eine zweite DV desselben Absenders innerhalb von 60 Sekunden), innerhalb der Sitzungsbytes; alles Holen läuft über
die bisherigen Grenzen (30 Anfragen in der Stunde, eine offene Anfrage, Bytes je Sitzung und Fragendem). Ein
beschäftigter Absender (DW) wird nicht früher gefragt. Namen werden nur angezeigt, nie gespeichert oder gesendet
(D-25). Siehe D-12, D-18, D-19, D-26.

## Daten

Kein neuer `AmisiaDB`-Schlüssel, keine Einstellung, keine Nachrichtenart, keine Blob-Art, kein Export. Im Speicher:
die Mitglieder (Name, wann gehört, Kills, neuester Tag, Wochen, geholt, gegeben, wann zuletzt gefragt, geholt bzw.
abgedeckt nach der Ankündigung) und der Lauf von "Jetzt abgleichen". Neu in DropSync: `ns.DropSyncBlocked`,
`ns.DropSyncCanSync`, `ns.DropSyncNow`, `ns.DropSyncResultText`, `ns.DropSyncWhyText`, `ns.DropSyncMembers`,
`ns.DropSyncInfo`; Grenzen `membersMax` 40, `manualGap` 60, `manualMin` 45, `manualMax` 180, `manualShow` 300.
Internes Ereignis `DROPSYNC_CHANGED` (`ns.FireSoon`). Befehlswort `sync`/`abgleichen` von `/amisia drops`.
Entscheidung D-121.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-13: "mach alle aber nach deinen vorschlag".
- Annahme (nicht gefragt): das Protokoll bleibt, wie es ist. Grund: alles, was die Liste zeigt, sagt schon die
  Ankündigung (Kills, neuester Tag, Prüfsummen je Woche) und der Austausch selbst (wer fragt, wer antwortet, was
  ankam); 2.81.0-Clients merken nichts. Grenze: wer vor dir online war und nichts Neues hat, kündigt nicht von
  selbst wieder an und fehlt bis dahin in der Liste.
- Annahme (nicht gefragt): die Liste lebt nur in der Sitzung. Grund: D-25 (keine Spielernamen in Drop-Daten);
  "seit dem Einloggen" ist ehrlich und braucht keinen gespeicherten Schlüssel.
- Annahme (nicht gefragt): "Wer teilt" ersetzt auf Klick die Liste je Instanz und Boss (wie "Drops für die
  Website" den Text), statt einer eigenen Liste unter der Zeile. Grund: die Seite ist voll (F-188 nahm schon zwei
  Zeilen), so bleibt sie ruhig und die Mitglieder haben 10 Zeilen mit Scrollbalken statt 6 mit "+ n weitere".
- Annahme (nicht gefragt): "Jetzt abgleichen" höchstens einmal in der Minute nach der letzten Ankündigung (auch
  der automatischen). Grund: jeder Empfänger verwirft eine zweite DV desselben Absenders innerhalb von 60 Sekunden;
  die 30 Minuten der automatischen Ankündigung schützen den Gildenkanal vor Dauerfunk ohne Klick und bleiben.
- Annahme (nicht gefragt): "geantwortet" heißt: ein Mitglied hat in der Zeit des Laufs bei diesem Client gefragt
  (DQ, DR) oder ihm geantwortet (DI, DW, DK); wer schon gleich ist, sendet nichts und zählt nicht.
- Annahme (nicht gefragt): ein Lauf endet frühestens nach 45 Sekunden, sobald nichts mehr geholt wird und keine
  Anfrage auf ihre Antwort wartet, spätestens nach 3 Minuten; das Ergebnis bleibt 5 Minuten stehen.
