# Amisia: DKP und EPGP als Alternative zum Würfeln

Stand 2026-10-08. Gilt für das Addon (WoW Forever) und die Seite (`index.html`, Ledger in Supabase).

## Ziel

Die Gilde wählt pro Ledger **ein** Lootsystem: Würfeln (Standard, bleibt unverändert), DKP oder
EPGP. Wer nichts umstellt, merkt nichts: keine neuen Zeilen im Export, keine neuen Nachrichten im
Raid, kein anderer Ablauf im Roll-Fenster.

## Modelle

### DKP

- **Verdienen** (pro aufgezeichnetem Raid, also pro Sitzung):
  - `raid`: jeder, der in der Anwesenheit des Raids steht (Standard 10),
  - `boss`: pro Bosskill, bei dem der Spieler dabei war (`k.who` des Kills, Standard 5),
  - `time`: pünktlich (nicht als zu spät markiert; wer von der Ersatzbank kommt, ist pünktlich; Standard 5),
  - `bench`: auf der Ersatzbank des Raids und nicht im Raid gewesen (Standard 10; keine Bosspunkte).
- **Ausgeben**, zwei Arten (`mode`):
  - `bid` (Bieten, Standard): `!bid 50` im Flüstern an die Lootleitung oder im Raidchat.
    Offen (`seal=0`) oder verdeckt (`seal=1`, dann nur geflüstert). Mindestgebot `min` (10),
    Schritt `step` (5): offen muss ein Gebot das bisherige Höchstgebot um mindestens `step`
    übertreffen; verdeckt darf jeder sein Gebot nur erhöhen. Höchstens der eigene Kontostand
    (`max = Kontostand`). Der Gewinner zahlt sein Gebot (Erstpreis).
  - `fixed` (feste Preise): Raider sagen `!need` / `!greed`; der Preis kommt aus derselben Formel
    wie GP (siehe unten) mit `price` als Basis (Standard 50); Offspec zahlt `os` Prozent.
    Reihenfolge: Bedarf vor Gier, dann höherer Kontostand.
- **Verfall** `decay` Prozent pro Woche (Standard 10), angewandt auf der Seite.

### EPGP

- **EP** wie DKP-Verdienst: `raid`, `boss`, `time`, `bench` (Standard 10/10/5/10).
- **GP** pro Item: `GP = round(scale · 2^((ilvl − ref)/26) · Slotgewicht · 2^(Qualität − 4))`
  (`scale` 100, `ref` 66). Offspec (`!greed`) zahlt `os` Prozent (Standard 50).
  Slotgewichte (Addon und Seite gleich): Kopf, Brust, Beine 1; Schulter, Hände, Taille, Füße,
  Schmuck 0,75; Hals, Umhang, Handgelenk, Finger 0,5; Einhandwaffe 1,5; Zweihandwaffe 2;
  Nebenhand/Schild 0,5; Fernkampf, Relikt 0,5; alles ohne Slot (Marken, Token) 1.
  Die Lootleitung kann den Betrag in der Vergabe immer von Hand ändern.
- **Priorität** `PR = EP / (GP + base)` mit Grund-GP `base` (Standard 100), damit Neue nicht durch
  0 teilen und eine erste Vergabe nicht alles umwirft.
- **Mindest-EP** `minep` (Standard 0 = aus): wer darunter liegt, steht hinter allen, die es erreichen.
- **Verfall** `decay` Prozent pro Woche auf EP und GP (Grund-GP verfällt nicht, er wird erst bei PR addiert).

### Twinks

Punkte gehören dem Main (`Raid/Alts.lua`, `ns.MainOf`; auf der Seite `mainIdOf`). Was ein Twink
verdient, zählt für seinen Main; ein Twink bietet mit dem Kontostand seines Mains; eine Vergabe an
einen Twink belastet den Main. Die Rangliste zeigt nur Mains.

## Wahrheit und Datenfluss

- **Die Seite ist die Wahrheit.** `state.points` im Ledger-JSON (additiv, keine DB-Migration):
  `{ sys, cfg, log: [...], decays: [...], raids: {sid: {date, sys}} }`. Stände werden nie
  gespeichert, sondern aus dem Protokoll berechnet (`pointsStandings`): alle Einträge und Verfälle
  nach Zeit, ein Verfall multipliziert jeden Stand zu seinem Zeitpunkt. Damit bleiben Korrekturen und
  spät importierte Raids nachvollziehbar.
- Vergabekosten stehen an der Vergabe (`award.pts = {p: 'D'|'G', n}`). Wird die Vergabe gelöscht,
  ist die Belastung weg; wird sie einem anderen Raider gegeben, folgt die Belastung.
- **Das Addon rechnet live** während des Raids: Stand der Seite (eingefügter Block) plus alles, was
  die Seite noch nicht hat (Verdienst der Raids, die nicht im Block stehen; Kosten von Vergaben und
  Korrekturen, deren Id der Block nicht nennt).
- **Export**: neue Zeilentypen im `#AMISIA 2`-Text, keine bestehende Zeile ändert sich. In einem
  Raid-Block (`S` … `E`), nur wenn der Raid ein Punktesystem hatte:
  - `PS <D|E> <dkp|epgp> <on|off>` – das System dieses Raids (D: DKP, E: EP),
  - `PE <id> <Name> <Betrag> <R|B|T|N> <Epoche> [<Boss>]` – ein Verdienst (Raid, Boss, pünktlich,
    Ersatzbank); die Id ist eine Prüfsumme aus Raid, Name, Art und Boss, also bei jedem Export gleich,
  - `PA <Vergabe-Id> <D|G> <Betrag> <Epoche> <Offizier>` – die Kosten einer Vergabe.
  Außerhalb der Raids (wie `LC`): `PX <id> <Name> <D|E|G> <±Betrag> <Epoche> <Offizier> <Grund>` –
  eine Korrektur im Spiel.
  Die Seite ersetzt beim Import den Verdienst eines Raids ganz (pro `sid`), übernimmt Kosten pro
  Vergabe-Id (neuere Zeit gewinnt) und Korrekturen pro Id (einmalig).
- **Import auf der Seite** (Import-Tab, eigenes Feld „Punkte aus dem Addon“ wie bei der Loot-Prio),
  nur für Editoren.
- **Zurück ins Spiel**: „Copy for the addon“ hängt einen Block an Wünsche, Twinks und Prio:

  ```
  #AMISIA-PTS 1 forever <Datum> <roll|dkp|epgp> <Stand-Epoche>
  CFG raid=10 boss=5 time=5 bench=10 mode=bid seal=0 min=10 step=5 decay=10 price=50 base=100 minep=0 scale=100 ref=66 os=50 pub=1
  P <Main> <DKP>            (DKP)   bzw.   P <Main> <EP> <GP>   (EPGP)
  R <sid> <sid> …           Raids, deren Verdienst die Seite hat
  I <id> <id> …             Vergaben mit Kosten und Korrekturen, die die Seite hat
  #END
  ```

  Offiziere übernehmen damit auch System und Parameter in die Einstellungen des Addons; Raider sehen
  ihren Stand (und die Liste, wenn `pub=1`).

## Ablauf im Spiel

- **Raid**: eine neue Aufzeichnung friert System und Parameter ein (`s.points`), wie `lateAt`.
  `/amisia punkteraid aus` (en `raidpoints off`) nimmt einen Raid aus der Wertung (Trash-Abend).
- **Roll-Fenster**: Alt-Klick startet je nach System eine Würfel-, Gebots- oder Bedarfsrunde.
  - Gebot: Zeilen nach Gebot, Spalte „Stand“, abgelehnte Gebote grau mit Grund. Offene Gebote werden
    im Raid angesagt („Höchstgebot“), verdeckte nur mit einer Flüsterbestätigung beantwortet.
  - Bedarf (EPGP und DKP mit festen Preisen): Bedarf vor Gier, dann PR (bzw. Stand); Spalten EP/GP und PR.
  - Die Eingabezeile unten trägt im Bosskampf (geheimer Chat) Gebote bzw. Bedarf/Gier von Hand ein.
  - „Nochmal“ bei Gleichstand startet einen normalen Wurf unter den Gleichen.
- **Vergabe-Dialog**: Feld „DKP“ bzw. „GP“, vorbelegt mit dem Gewinnergebot, dem GP nach Art (MS voll,
  OS Anteil) oder dem festen Preis. Der Betrag landet an der Vergabe (`s.points.charges[id]`); auf der
  Seite Vergaben lässt er sich ändern. Rückgängig/Löschen/Umbenennen der Vergabe wirken mit, weil
  die Kosten nur zählen, solange die Vergabe lebt, und immer dem aktuellen Gewinner gelten.
- **Seite Punkte** (en „Points“): Rangliste (Offiziere: alle; Raider: eigener Stand, die Liste nur bei
  `pub=1`), Verlauf mit Gründen, Korrektur mit Pflicht-Grund (nur Offiziere), Einfügen des Blocks.
- **Befehle**: `/amisia punkte [Name]` (en `points`), `/amisia korrektur <Name> <±Zahl> [ep|gp] <Grund>`
  (en `adjust`), `/amisia punkteraid an|aus` (en `raidpoints`). Chat: `!bid`/`!gebot <Zahl>`,
  `!need`/`!bedarf`, `!greed`/`!gier`, `!dkp`/`!ep`/`!punkte` (Antwort mit dem eigenen Stand).

## Vertrauen

- Punkte ändern nur verifizierte Offiziere (Offiziersansicht und Gildenrang, `ns.IsOfficerView`);
  Korrekturen brauchen einen Grund.
- **Raid-Sync wie bei der Loot-Prio (LV/LQ/LC)**: der Sync-Keeper sagt `KV <Raid> <Hash> <n>` in den
  Raid; wer einen anderen Stand hat, fragt per Flüstern `KQ <Raid> <eigener Hash>`; der Keeper
  schickt den ganzen Stand als Blob `KS` (System, Parameter für Gebote, Stände, Kosten des Raids).
  Ein Offizier, der eine Vergabe mit Betrag versieht, schickt `KC <Raid> <Vergabe-Id> <D|G> <Betrag>
  <Epoche>` in den Raid; andere Offiziere übernehmen die neuere. Angenommen wird nur von verifizierten
  Offizieren der eigenen Gilde in der eigenen Gruppe; ein Blob wird ganz geprüft oder ganz verworfen.
- Chat-Eingaben (`!bid`) sind feindlich: Codes, Links, Kommazahlen, Vorzeichen, Exponenten, Hex,
  überlange Zahlen und Fremde außerhalb der Gruppe werden abgelehnt; Antworten sind gedrosselt
  (`ns.ReplyGate`). Nur der Client, der die Runde führt, wertet aus.
- Auf der Seite schreiben nur Editoren (`readOnly`), wie überall.

## Randfälle

- **Gleichstand**: Gebot – verdeckt gleiche Gebote: höherer Kontostand gewinnt, sonst Gleichstand
  (Nochmal = Würfeln unter den Gleichen); offen kann es keinen geben (Schritt). EPGP: gleiche PR →
  mehr EP, sonst Würfeln. DKP fest: gleicher Stand → Würfeln.
- **Negative Stände**: Gebote gehen nie über den Stand. Feste Preise, GP und Korrekturen dürfen
  einen DKP-Stand negativ machen; er wird dann angezeigt, wie er ist, und verfällt ebenso.
  Wer unter dem Mindestgebot steht, kann nicht bieten; dann würfelt man (normale Runde).
- **Zu spät / Ersatzbank**: zu spät = kein Pünktlich-Bonus; Ersatzbank nur `bench`; wer erst auf der
  Bank war und dann kam, zählt als anwesend und pünktlich. Nur der erste Raid eines Abends kennt
  „zu spät“ (bestehende Regel).
- **Korrekturen**: nie Änderung eines Eintrags, immer ein neuer Eintrag mit Grund; im Spiel wie auf
  der Seite. Ein falscher Eintrag wird durch eine Gegenbuchung ausgeglichen; auf der Seite kann ein
  Editor eine eigene Korrektur löschen (Protokoll bleibt in der Versionsgeschichte des Ledgers).
- **Verfall**: nur auf der Seite, per Knopf für Editoren, einmal pro Woche (ein zweiter innerhalb
  von 6 Tagen fragt nach). Ein später importierter Raid mit früherem Datum wird beim Rechnen
  so verfallen, als wäre er rechtzeitig da gewesen.
- **Runden**: alle Beträge ganze Zahlen; nach dem Verfall wird kaufmännisch gerundet (0,5 weg von 0).
  PR wird mit zwei Nachkommastellen angezeigt, verglichen wird exakt (Kreuzprodukt).
- **Systemwechsel**: ein laufender Raid behält sein System; das Protokoll bleibt, die Rangliste zeigt
  nur das aktive System (DKP-Einträge zählen nicht als EP).
- **Beta-Bug der SavedVariables** und Lockdown: wie bisher; Gebote im Bosskampf von Hand.
