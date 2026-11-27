# Spec: Gildenbank-Protokoll und Zählung mit der Gilde abgleichen

Stand: 2026-11-26 · Status: freigegeben · Feature: F-238

## Ziel

Das Gildenbank-Protokoll (`Raid/BankLog.lua`, `AmisiaDB.bankLog`) und die letzte Zählung der Raidmaterialien
(`Raid/Record.lua`, `AmisiaDB.bank`) liest heute nur, wer die Gildenbank selbst öffnet. Jeder Amisia-Nutzer der
Gilde soll beides sehen, ohne an der Bank zu stehen: die Seite Gildenbank zeigt dieselben Einträge und dieselbe
Zählung wie beim Offizier, der zuletzt dort war.

## Was es tut

- Ein Offizier öffnet die Gildenbank: die Einträge, die bei diesem Lesen neu waren, gehen an die Gilde (`BE`); seine
  Zählung 5 Sekunden nach dem letzten Zählen (`BC`).
- Nach dem Login fragt jeder Client (mit Gildenbank, also TBC und Forever) einmal die Gilde, wer Einträge oder eine
  Zählung hat, die ihm fehlen (`BQ ?`); Offiziere mit mehr antworten mit einem Angebot (`BH`, Flüstern), der Client
  holt es bei einem einzigen (dem mit den meisten Einträgen) per Flüstern ab (`BQ L`/`C`), in Runden von höchstens
  100 Einträgen (bis zu 10 Runden).
- Seite Gildenbank > Protokoll: die abgeglichenen Einträge stehen wie die eigenen; eine Zeile unter den Filtern
  "Abgeglichen mit der Gilde · zuletzt von X um TT.MM. HH:MM" (oder dass der Abgleich aus ist); der Tooltip jedes
  Eintrags sagt "Gemeldet von X" oder "Selbst gelesen" und das Zeitfenster.
- Bestand: "Gezählt am ... von X ... · erhalten von Y", wenn die Zählung aus der Gilde kam.
- Einstellung `bank.share` "Gildenbank-Protokoll mit der Gilde abgleichen" (an) im Abschnitt Gildenbank, der jetzt
  für alle sichtbar ist.

## Was es ausdrücklich nicht tut

- Kein Senden durch Mitglieder ohne Offiziersrang, auch wenn ihr Rang Tabs sehen darf (siehe Entscheidungen 1).
- Kein Weiterreichen fremder Zählungen oder Einträge unter fremdem Namen: ein Eintrag trägt den Offizier, von dem
  er kam ("gemeldet von"), nicht den ursprünglichen Leser.
- Nichts im Raid-, Gruppen- oder Instanzchat; keine Blobs; kein Abgleich der Spendenzusagen (die hat `GP`).
- Keine Vollübertragung bei jeder Anmeldung: nur, was fehlt, gedeckelt.

## Abläufe

1. Offizier A öffnet die Bank. Amisia liest die Protokolle wie bisher; die neuen Einträge (höchstens die neuesten
   120) gehen als ein Satz `BE` in Teilen an die Gilde. Jeder Empfänger prüft A im eigenen Roster (Offiziersrang),
   setzt die Teile zusammen und mischt sie wie ein eigenes Lesen von A ein (Eins-zu-eins-Abgleich, Überlappung,
   Verengung). Doppelte Einträge entstehen nicht, auch wenn B dasselbe Protokoll gleich danach liest.
2. Mitglied C loggt ein. 40-70 s später `BQ ?` mit seiner Übersicht je Tab (Anzahl, neuester, ältester Eintrag) und
   der Zeit seiner Zählung. Jeder Offizier rechnet, was C fehlt (neuer als C's neuester, mehr Einträge im Bereich als
   C hat, älter als C's ältester) und flüstert ein Angebot. Nach 12 s wählt C den Offizier mit den meisten Einträgen
   und den mit der neuesten Zählung und holt per Flüstern ab. Bringt eine Antwort "mehr" und etwas Neues, folgt nach
   12 s die nächste Runde beim selben Offizier; antwortet er 60 s nicht, der nächste Anbieter.
3. Zählung: der neueste Stand (nach seiner Zeit) gewinnt; ältere werden verworfen.

## Abnahmekriterien

- Wenn ein Offizier die Gildenbank öffnet und neue Einträge liest, dann stehen sie beim anderen Spieler unter
  Gildenbank > Protokoll, mit "Gemeldet von <Offizier>" im Tooltip (braucht: Gilde, zwei Spieler).
- Wenn zwei Offiziere nacheinander dasselbe Protokoll lesen, dann steht beim dritten Spieler jeder Eintrag nur einmal
  (zwei gleiche Einzahlungen in derselben Stunde bleiben zwei) (braucht: Gilde, drei Spieler).
- Wenn ein Spieler einloggt, der eine Weile offline war, dann hat er nach etwa einer Minute die Einträge, die ein
  Offizier inzwischen gelesen hat, und unter den Filtern "Abgeglichen mit der Gilde · zuletzt von ..." (braucht: Gilde).
- Wenn ein Offizier die Gildenbank zählt, dann zeigt Bestand beim anderen Spieler "Gezählt am ... von <Offizier> ...
  · erhalten von <Offizier>" (braucht: Gilde).
- Wenn ein Spieler `bank.share` ausschaltet, dann kommt bei ihm nichts mehr an und, als Offizier, geht nichts hinaus.

## Sonderfälle

- Bosskampf/Kampfsperre: die Nachrichten warten in Comms Warteschlange (ttl 900 s); im Schlachtfeld geht nichts.
- Der Schalter "Sync" (Raid-Abgleich) hält nichts davon an (D-165): `ns.CommReady` und `bank.share`.
- Zwei PCs mit verschiedener Uhrzeit: auf der Leitung stehen Zeiten der Realm-Uhr (`GetServerTime`); jeder Client
  rechnet mit dem Unterschied seiner Uhr zur Realm-Uhr um. 120 s Spielraum beim Vergleich empfangener Fenster.
- Classic Era hat keine Gildenbank: kein Client fragt dort, keiner hat Einträge.
- Nachnamen (Forever): Namen mit Leerzeichen gehen als letztes Feld eines Eintrags; der Zähler mit `_`.
- `bank.log` aus: kein Protokoll, also auch keine empfangenen Einträge (die Zählung kommt weiter an, sie speist den
  Bedarf). `bank.count` aus: keine eigene Zählung, empfangene Zählungen kommen an.
- Ein Eintrag, der beim Sender aus dem 90-Tage-Fenster oder der 1000er-Grenze fällt, fällt beim Empfänger ebenso.

## Missbrauch/Vertrauen

- Es zählt nur der Absender, den der Server setzt, und sein Rang im eigenen Roster (`ns.TrustWait` "officer"); ein
  Mitglied, ein degradierter Offizier oder ein Fremder wird still verworfen.
- Jedes Feld wird geprüft (Comm `VALID` und `decode`): Art aus einer festen Liste, Tab 0-9, Gold ohne Item, Verschieben
  nur mit zwei Tabs, Alter höchstens 400 Tage, Fenster höchstens 8 Tage, Name 1-48 Bytes ohne Steuerzeichen und `|`,
  Zeit höchstens eine Stunde voraus; ein falsches Feld verwirft die ganze Nachricht.
- Deckel: 40 Teile je Satz, 2 offene Sätze je Absender, 6 insgesamt, 30 s Wartezeit je Teil; ein Antwortender gibt
  höchstens 8 Antworten in 10 Minuten; der Empfang je Absender bleibt in Comms Grenzen (40 Nachrichten in 10 s,
  20480 Bytes in 60 s); das Protokoll bleibt bei 1000 Einträgen.
- Ein Offizier kann erfundene Einträge senden. Das kann er heute schon über die Website-Exporte nicht verhindern;
  Offiziere sind vertraut (wie beim Bedarf, D-153 betrifft geteilte Daten ohne Rangprüfung).

## Daten

- Neue Nachrichten `BE`, `BQ`, `BH`, `BC` (Präfix `Amisia`, GUILD und WHISPER; Abstand `BQ` 10 s, eine geflüsterte
  Abholung eigene 10 s, sonst keiner),
  `docs/ARCHITECTURE.md` "Message kinds".
- `AmisiaDB.bankLog.got = {by, at, n}`, Eintragsfeld `r`; `AmisiaDB.bank.via`.
- Einstellung `bank.share` (an); der Abschnitt `bank` ist nicht mehr nur für Offiziere.
- Keine neue Exportzeile: empfangene Einträge gehen wie eigene als `BT` hinaus.

## Offene Fragen

Nichts.

## Entscheidungen

- 2026-11-26: Nutzer "ja bau" zum Abgleich von Protokoll und Zählung mit allen Amisia-Nutzern der Gilde.
- 2026-11-26: Frage 1 (wer sendet): "Mit Leserecht", sonst Offiziere. Geprüft: der Client sagt die Tab-Rechte eines
  anderen Rangs nur über `GetGuildBankTabPermissions(tab)` für den Rang, den `GuildControlSetRank` gewählt hat; diese
  Wahl teilt sich Amisia mit der Rangverwaltung des Spiels (Blizzard_GuildControlUI setzt sie selbst und zeigt die
  Bankrechte nur dem Gildenmeister). Nicht verlässlich für andere prüfbar -> Offiziersränge (D-171).
- 2026-11-26: Frage 2 (wer sieht): alle mit Amisia in der Gilde; die Seite Gildenbank ist schon für alle da.

## Nachtrag 2026-11-26 (Prüfung der Logik)

Eine Prüfung fand Lücken; behoben, jede mit einem Test in `tests/test_bank_share.lua` (R1-R9 und drei Zusätze):

- Die erste Abholung fiel dem Abstand von `BQ` beim Offizier zum Opfer, wenn das `?` in der eigenen Warteschlange
  wartete: die 12 s für die Angebote zählen jetzt ab dem Moment, in dem das `?` wirklich hinausging (Comm `sent`), und
  eine geflüsterte Abholung hat einen eigenen Abstand (`BQL`, 10 s). Ebenso zählen die 60 s für eine Antwort ab dem
  Senden der Abholung.
- `BQ` trägt den Horizont des Fragenden: ab wann er behält (`bank.logDays`, Realm-Uhr), wie viele Einträge er hat, sein
  ältester Eintrag, und statt der Übersicht je Tab die Einträge je Tag (Realm-Uhr, zwei Ziffern zur Basis 36, so viele
  Tage wie in eine Nachricht passen, höchstens 120). Der Offizier schickt einen Tag, wenn er dort mehr hat und auch über
  den Tag und seine beiden Nachbarn mehr (ein Eintrag auf der anderen Seite von Mitternacht), Tage neuer als die
  Übersicht, und ältere nur, wenn sie älter als der älteste des Fragenden sind. Nie, was der Fragende sofort verwirft:
  älter als sein Horizont, oder außerhalb seiner neuesten 1000 (Tage der Reihe nach, solange Platz ist). Ein
  Mischen zählt nur Einträge, die nach dem Kürzen bleiben; bringt eine Runde nichts Neues, endet die Abholung.
- Wer kein Protokoll führt (`bank.log` aus), fragt `?C`: nur nach der Zählung.
- Ein Empfänger, dessen Roster nicht lesbar ist (Kampfsperre, noch nicht geladen), hält die Teile eines `BE` oder
  `BC` unter dem rohen Absender und prüft ihn einmal je Satz (mit dem ersten Teil) über `ns.TrustWait`; ein Satz, der
  auf die Prüfung wartet, bleibt bis zu 60 s länger offen. Ein Offizier, dessen Roster beim Lesen der Bank noch nicht
  gebaut ist, sendet, sobald es seinen Rang sagt.
- Nur ein geflüsterter Satz beantwortet eine Abholung; ein Gildensatz desselben Offiziers beendet sie nicht.
- Antworten eines Offiziers: einem Fragenden höchstens 13 in 10 Minuten (ein ganzer Abgleich: 12 Runden und die
  Zählung), allen zusammen höchstens 40; ein Fragender ohne Rest bekommt auch kein Angebot. 12 statt 10 Runden, weil
  eine Runde den Tag, den die vorige geteilt hat, noch einmal ganz schickt; ein Protokoll von 1000 Einträgen kommt so
  ganz an.
- Seite Gildenbank > Protokoll: der Link "Jetzt abgleichen" in der Zeile des Abgleichs fragt sofort (D-167), höchstens
  einmal in der Minute; der Tooltip nennt die Grenzen und die Wartezeit.
- Namen werden auf 48 Bytes an einer Zeichengrenze gekürzt (UTF-8). Bestand zeigt eine empfangene Zählung auch, wenn
  der Empfänger noch kein Raidmaterial gelernt hat (die Gegenstände der Zählung sind dann die Liste).
- Grenze: die Tageszählung umfasst alle Tabs; fehlt dem Fragenden an einem Tag ein Eintrag, während er dort einen
  anderen hat, den der Offizier nicht hat, bleibt die Lücke bis zum nächsten eigenen Lesen. Bei `bank.logDays` über
  etwa 95 Tagen reicht die Übersicht nicht bis zum Horizont; ältere Einträge kommen nur, wenn sie älter als der älteste
  des Fragenden sind.

## Nachtrag 2 2026-11-27 (zweite Prüfung)

Eine zweite Prüfung fand weitere Lücken; behoben, jede mit einem Test in `tests/test_bank_share.lua` (S1-S8):

- S1: Ein Tag mit mehr als 100 Einträgen hielt die Abholung an (die Runde schickte nur Bekanntes, "nichts Neues"
  beendete sie), und jede Runde schickte den Tag, den die vorige geteilt hatte, noch einmal. Jetzt trägt jede Abholung
  einen Zeiger: das älteste Ende (Realm-Uhr, genau wie gesendet), das der Fragende in diesem Abgleich vom Offizier
  bekam, und wie viele Einträge dieses Endes (`-` in der ersten Runde); der Offizier schickt nur, was danach kommt, und
  jede Runde wiederholt die Übersicht der ersten. Ende: nichts mehr, der Zeiger steht, oder zwei Runden nacheinander
  ohne Neues. 1000 Einträge zu 60 am Tag: 10 Runden, jeder Eintrag einmal. Eine Antwort hat höchstens 15 Teile (Comms
  20480 Bytes in 60 s je Absender beim Empfänger), dafür bis zu 16 Runden.
- S2: Zählungen mit steigender Zeit in der Kampfsperre belegten Trust.lua's 20 Warteplätze (die teilen sich
  Raid-Abgleich, Würfelfenster und Bedarf). Jetzt prüft ein Empfänger einen rohen Absender einmal zur Zeit für alles,
  was er offen hat; höchstens 6 gehaltene Zählungen; bei unlesbarem Roster hält er nur GUILD-Nachrichten (dort sendet
  nur, wer in der Gilde ist) und das Flüstern des Offiziers, dessen Antwort er erwartet.
- S3: Sätze von Mitgliedern ohne Offiziersrang blieben bis zu 30 s offen und sperrten die Plätze. Jetzt fallen sie mit
  der Prüfung sofort, der Absender wird 30 s nicht gehört, und ein Platz bleibt dem abgeholten Offizier.
- S4: Ein Satz in einer Sperre über 60 s fiel, die Einträge kamen erst beim nächsten Login. Jetzt fragt der Client nach
  der Sperre einmal die Gilde (`BQ ?`, mit dessen Abstand).
- S5: Das Budget zählt Teile statt Antworten (einem Fragenden 260 in 10 Minuten, allen 780), und eine Abholung wird nur
  beantwortet, wenn der Offizier diesem Fragenden in den letzten 5 Minuten ein Angebot gab oder antwortete.
- S6: "Jetzt abgleichen" während eines Abgleichs ließ zwei Abholungen zugleich laufen; die nächste Runde prüft jetzt
  das Zeichen der Frage.
- S7: Ein Lesen schickte Einträge, die ein späterer Tab desselben Lesens schon weggekürzt hatte (1000er-Grenze).
- S8: Alte Einträge mit Fenstern über mehrere Tage zählen zwei Clients unter verschiedenen Tagen; jeder Login brachte
  eine nutzlose Runde. Ein Offizier, dessen Abgleich nichts brachte, wird bei gleichem Angebot 6 Stunden nicht wieder
  abgeholt (nur in dieser Sitzung gemerkt).
- `BH` geht mit normalem Vorrang (klein, und die 12 s für die Angebote warten darauf); ein Client ohne Offiziersrang
  prüft bei `BQ` niemanden.

