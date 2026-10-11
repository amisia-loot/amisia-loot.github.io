# Spec: softres.it-Exporte und gemischte Gilde mit Gargul

Stand: 2026-10-11 · Status: freigegeben (A2, B1, B4 gebaut für 2.26.0) ·
Feature: F-091 (A2, softres.it-Code), F-092 (B1, Gargul-Runden), F-093 (B4, Ansage auf Englisch); A1 war
eine Fehlerbehebung von F-019 (2.25.2).

Diese Spec nennt Gargul beim Namen, weil der Nutzer genau dieses Addon meint. Nach D-05 heißen andere
Addons in Entwürfen sonst "andere Loot-Addons". Ob das hier und in Amisias Texten gelockert wird,
fragt Frage 1.

Zwei Teile, einzeln baubar: **A** liest jeden Export von softres.it ein, **B** lässt Raider mit Gargul
und Raider mit Amisia im selben Raid würfeln. Die Fakten unten stammen aus dem Quelltext von Gargul
(GitHub `papa-smurf/Gargul`, Stand 2026-10-03, nur gelesen) und aus der Seite softres.it (eine Seite
und ihr Skript, von Hand gelesen; `robots.txt` erlaubt das). **Gargul hat keine freie Lizenz**
("All Rights Reserved"): Amisia übernimmt keine Zeile Code von dort. Amisia baut nur nach, was in den
Texten und Nachrichten steht, die Gargul in den Raid schickt.

**Ein Fehler, der schon heute stört:** softres.it schreibt in den CSV-Export inzwischen die Kopfzeile
`Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date`.
Amisia 2.25.1 sucht die Spalte `Name` und findet sie dort nicht. Eine solche CSV ergibt
**0 Reservierungen**: am 2026-10-11 mit dem Testprogramm des Addons geprüft, auf einer Kopie. Nur der
ältere "Weakaura"-Export (`Item,ItemId,From,Name,Class,Spec,Note,Plus,Date`) klappt noch. Teil A1
behebt das. Es ist eine Fehlerbehebung und braucht keine Freigabe.

## Ziel

**A:** Ein Offizier kopiert von softres.it irgendeinen Export: CSV, den kurzen Gargul-Code, den
LootReserve-Text oder den Weakaura-Text. Er fügt ihn in Amisias Fenster "Soft-Reserves" ein, und die
Liste stimmt. Gelöst ist es, wenn niemand mehr fragen muss, welcher Knopf auf softres.it der richtige
ist.

**B:** In einer Gilde mit beiden Addons kann jeder würfeln, egal wer die Runde startet. Amisia erkennt
Runden, die jemand mit Gargul startet: Amisia-Raider bekommen ihr Würfel-Fenster, und die Amisia der
Lootleitung schreibt die Würfe mit. Startet die Lootleitung mit Amisia, würfeln Gargul-Raider ganz
normal. Gelöst ist es, wenn nach jedem Item klar ist, wer gewonnen hat, und keiner "vergessen" wurde.

## Was es tut

### Teil A: alle softres.it-Exporte (F-091)

softres.it bietet vier Exporte und dazu "Copy Raiders" (nur Namen, keine Reservierungen). Keiner ist
eine öffentliche Schnittstelle: Die Seite holt die Texte aus ihrer eigenen internen API (`/api/raid/<id>/csv`, `/gargul`, `/lootreserve`, `/weakaura`). Ein Addon kann
nichts aus dem Netz laden. Es bleibt also beim Einfügen.

| Export auf softres.it | Wie er aussieht | Amisia heute | Mit dieser Spec |
|---|---|---|---|
| **CSV** (Spalten wählbar) | Kopfzeile mit Klartext-Namen (`Item ID`, `Raider Name`, ...), Zeilenende CRLF, Kommas in Anführungszeichen | **liest nichts** (Spalte `Name` fehlt) | A1: jede Kopfzeile mit einer Item-ID- und einer Namensspalte |
| **Weakaura** | alte CSV `Item,ItemId,From,Name,Class,Spec,Note,Plus,Date` | geht | bleibt |
| **LootReserve** | Text für "Import from CSV" eines anderen Addons; den genauen Aufbau sehe ich nur mit einem echten Raid (Frage 9) | unklar | A1 deckt ihn ab, wenn er eine Kopfzeile hat; sonst ein eigener kleiner Leser nach einem echten Beispiel |
| **Gargul** (kurzer Code) | eine lange Zeichenkette ohne Leerzeichen: Base64, darin zlib-gepackt, darin JSON | wird als "Zeilen nicht erkannt" gemeldet | A2: wird gelesen |

**A1 CSV, robust:** Amisia erkennt die Kopfzeile an einer Spalte, die (ohne Leerzeichen, klein)
`itemid` heißt. Den Namen nimmt sie aus der ersten Spalte, die `name`, `raidername`, `character` oder
`player` heißt (nie `discordname`). Wahlweise liest sie auch Klasse (`class`/`raiderclass`), Notiz
(`note`/`raidernote`) und `Plus`. Fehlt eine Spalte, weil der Offizier sie auf softres.it abgewählt
hat, sagt die Vorschau: "Spalte 'Raider Name' fehlt. Auf softres.it beim CSV-Export 'Raider Name' und
'Item ID' anhaken."

**A2 Gargul-Code:** Amisia entpackt den Code mit den Funktionen des Spiels:
`C_EncodingUtil.DecodeBase64` → `C_EncodingUtil.DecompressString(…, Enum.CompressionMethod.Zlib)` →
`C_EncodingUtil.DeserializeJSON`. Alle drei stehen in Forevers API-Beschreibung (Blizzards UI-Quellen,
Zweig `forever`, `EncodingUtilDocumentation.lua`). Gargul selbst packt auf Forever mit genau diesen
Funktionen. Es kommt **keine fremde Bibliothek** ins Addon, also auch keine neue Lizenzdatei und keine
neue TOC-Zeile. Dazu kommen etwa 150 Zeilen eigener Code in `Raid/SoftRes.lua`. Fehlt
`DeserializeJSON` im Spiel doch (Frage 2), liest ein eigener kleiner JSON-Leser (etwa 120 Zeilen,
eigener Code) den Text.

Was im Code steht (so liest Gargul ihn, `Classes/SoftRes.lua`, `importGargulData`):

```
{ "metadata": { "id", "createdAt", "updatedAt", "raidStartsAt", "hidden", "discordUrl", ... },
  "softreserves": [ { "name", "class", "note", "plusOnes", "items": [ { "id", ... } ] } ],
  "hardreserves": [ { "id", "for", "note" } ],
  "bonusrolls":   [ { "name", "bonus" } ] }
```

Amisia übernimmt daraus:

- Name und Item-IDs wie bisher. Ein doppelt reserviertes Item steht zweimal in `items` und zählt
  wie heute als "2x".
- Klasse (für den Namensabgleich, "Vulo" ist ein Priester) und Notiz. Die Notiz steht im Tooltip und
  im Würfel-Fenster, auf 60 Zeichen gekürzt.
- `plusOnes` von softres.it nur als Hinweis ("softres +1: 2"). Amisias Plus-Eins bleibt Amisias
  eigene Zählung (D-22) und wird nicht überschrieben (Frage 7).
- **Hard-Reserves** (Item gehört vorab jemandem, z. B. "für die Gilde"): Neu ist ein Vermerk "HR:
  Gilde" im Tooltip und im Lootfenster. Startet die Lootleitung eine Runde auf ein HR-Item, fragt
  Amisia erst "Hard-Reserve für Gilde. Trotzdem würfeln?". Lootregeln fassen ein HR-Item nie an (wie
  ein reserviertes, D-37) (Frage 8).
- Bonus-Würfe (`bonusrolls`, eine Bezahlfunktion von softres.it) übernimmt Amisia nicht. Die Vorschau
  sagt dann: "3 Bonus-Würfe nicht übernommen."
- Die softres-ID und `updatedAt`. Fügt man den Code desselben Raids später noch einmal ein, sagt die
  Vorschau "Gleicher Raid wie die geladene Liste, 2 neue Reservierungen" statt "neue Liste".

**Meldungen** (Vorschau unter dem Textfeld, wie heute zwei Zeilen):

- "Code erkannt (softres.it): 12 Raider, 23 Reservierungen, 1 Hard-Reserve."
- Fehler beim Entpacken: "Der Code ist unvollständig oder verändert. Auf softres.it 'Gargul' öffnen,
  'Copy to Clipboard', hier ohne weitere Zeichen einfügen."
- Ein Text ohne Reservierungen: "Code gelesen, aber keine Reservierungen darin."
- Ein Spiel ohne die nötigen Funktionen: "Dieser Client kann den Code nicht entpacken. Bitte den
  CSV-Export nehmen."

### Teil B: gemischte Gilde (F-092)

So läuft eine Gargul-Runde heute (Quelltext `Classes/RollOff.lua`, `Classes/Comm.lua`,
`Data/Constants.lua`, `Data/DefaultSettings.lua`, `Data/Localizations/chat.lua`):

- Gargul läuft auf Forever: Seine TOC hat `## Interface-Camelot: 16001`, der Code fragt
  `GL.isForever` ab. Ob die Gildenmitglieder es wirklich nutzen, zeigt Frage 3.
- **Start:** Der Starter schickt eine Addon-Nachricht mit dem Präfix **`GargulComm2`** in den Raid
  (Gargul nennt den Kanal GROUP, das ist RAID oder PARTY). Die Nachricht ist mit LibSerialize
  gepackt, mit LibDeflate (Deflate) komprimiert und für den Addon-Kanal umkodiert. Ist sie länger als
  255 Zeichen, teilt AceComm sie in Stücke. Inhalt: `a = 10` (startRollOff),
  `b = { item = "item:18814", time = 20, note, SupportedRolls, bth, g, b }`, `c` = Name des Senders,
  `m` = Mindestversion "8.0.0", `v` = Version. Ende: `a = 11` (stopRollOff).
- **Jeder Gargul-Raider** bekommt dann ein Fenster mit einem Knopf pro Würfelbereich, der
  `RandomRoll(min, max)` würfelt. Standard: **MS 1-100, OS 1-99**. Die Lootleitung kann die Bereiche
  ändern. "Pass" schließt nur das Fenster und sendet nichts.
- **Vertrauen:** Gargul prüft beim Start **nicht**, ob der Sender Plündermeister oder Leiter ist.
  Jeder in der Gruppe mit Gargul kann eine Runde starten. Beenden kann sie nur der, der sie
  gestartet hat.
- **Chat des Starters** (Standard englisch, auf Wunsch deutsch). Beim Start eine
  Schlachtzugswarnung "You have 20 seconds to roll on [Item]" (deutsch "Du hast 20 Sekunden um auf
  [Item] zu würfeln"), dahinter vielleicht " - Notiz". Danach im Raid "This item was reserved by:
  Anna, Bob" und am Ende "N seconds to roll" (5 bis 1). Zum Schluss wieder als Warnung "Stop your
  rolls!" ("Stopp deine Würfe!"), bei der Vergabe "[Item] was awarded to Anna. Congrats!".
- **Würfe:** Nur der Starter liest die Systemzeilen, mit derselben Spielvorlage wie Amisia
  (`RANDOM_ROLL_RESULT`). Bereiche, die er nicht kennt, zählen nicht.
- **Rangfolge** (Standard): Wer das Item reserviert hat, zuerst, egal welcher Bereich. Dann der
  Bereich nach seiner Priorität (MS vor OS), dann **weniger Plus-Eins zuerst, in jedem Bereich**,
  dann die höhere Zahl. Gargul führt seine Plus-Eins als eigene Liste: von Hand gepflegt oder aus
  softres.it übernommen.

Amisia hat dieselben Bereiche (D-21) und fast dieselbe Reihenfolge. Die Unterschiede: Amisias
Plus-Eins zählt nur MS-Gewinne und wirkt nur unter MS-Würfen, und das nur mit der Einstellung
"Plus-Eins in der Reihenfolge".

**Die Optionen:**

| | Was | Gewinn | Preis |
|---|---|---|---|
| **B1** | Amisia **liest den Chat**: Erkennt sie "You have N seconds to roll on [Item]" (oder die deutsche Fassung) als Schlachtzugswarnung der Lootleitung, öffnet jede Amisia ihr Würfel-Fenster selbst. Die Amisia der Lootleitung startet still eine **beobachtete Runde** (keine Ansage, kein `WS`) und liest die `/roll`-Zeilen wie immer. Ende bei "Stop your rolls!" oder nach Ablauf der Zeit. | Keine Kopplung an Gargul-Nachrichten, kein neues Präfix, kein Senden. Geht auch, wenn der Starter Gargul hat und sonst niemand. | Nur Englisch und Deutsch. Stellt der Starter Gargul auf eine andere Sprache um oder schaltet die Ansage ab, sieht Amisia nichts. Die Bereiche stehen nicht im Chat, Amisia nimmt 100/99 an. Im Bosskampf ist der Chat geheim (Forever), dann gibt es kein Fenster. |
| **B2** | Amisia **liest Gargul-Nachrichten** auf `GargulComm2`, nur lesen: Stücke zusammensetzen, umkodieren, mit `C_EncodingUtil` entpacken, LibSerialize-Format mit eigenem Leser lesen. Nur `a = 10` und `a = 11` werden beachtet. | Bereiche, Zeit und Notiz genau. Unabhängig von Sprache und Chat-Einstellung. | Ein drittes Präfix wird angemeldet (D-19 sagt "genau zwei"; gesendet wird darauf nichts), Frage 10. Etwa 300 Zeilen eigener Leser. Bricht, wenn Gargul sein Format ändert (dann bleibt B1). Der Präfixname enthält "Gargul" und verstößt gegen D-05 (Frage 1). |
| **B3** | Amisia **sendet** beim Start einer eigenen Runde zusätzlich eine Gargul-Startnachricht, damit Gargul-Raider ihr Fenster bekommen. | Gargul-Raider haben ihr gewohntes Fenster. | Braucht einen LibSerialize-Schreiber, Deflate, die Umkodierung und das Teilen, alles nachgebaut. Gibt sich als Gargul aus: Amisia müsste eine Versionsnummer und einen Absendernamen in Gargul-Form angeben, und der Name müsste zu Gargul passen. Bricht bei jeder Formatänderung, und **Gargul-Nutzer sehen bei einem Fehler Gargul-Warnungen**. Rechtlich ist es nur Nachbau eines Formats, kein Code. Trotzdem stört es Gargul-Nutzer, wenn es schiefgeht. |
| **B4** | Amisias Rundenansage bleibt, wie sie ist: "Roll auf [Item]: /roll für Mainspec, /roll 99 für Offspec. 20 Sekunden." Neu ist die Einstellung "Rundenansage auch auf Englisch". Gargul-Raider würfeln von Hand mit `/roll` oder `/roll 99`; das sind genau Gargul's Standardbereiche. | Nichts zu bauen außer einer Textzeile; jeder versteht es. | Ein Gargul-Fenster öffnet sich dadurch **nicht** (Gargul liest keinen Chat für Starts). |

**Ohne B3 haben trotzdem alle ein Fenster:** Die Lootleitung installiert **beide** Addons und startet
die Runde mit Gargul. Gargul-Raider bekommen ihr Gargul-Fenster. Amisia-Raider bekommen über B1/B2
ihr Amisia-Fenster. Amisia schreibt die Würfe mit und zeichnet die Vergabe wie immer aus Master Loot
auf. Startet die Lootleitung mit Amisia, würfeln Gargul-Raider per `/roll` (B4).

**Empfohlene Reihenfolge:** A1 sofort (Fehlerbehebung), dann A2. Danach **B1 + B4** und die Regel
"wer startet, entscheidet". Dann **B2**, falls die Gilde Gargul wirklich auf Forever nutzt und B1 im
Raid zu oft daneben liegt. **B3** nur, wenn der Nutzer es ausdrücklich will und Frage 3 zeigt, dass
Gargul-Raider Amisia-Runden sonst verpassen.

**Gemischte Runde: wer entscheidet?** Es entscheidet immer das Addon, das die Runde gestartet hat,
mit seinen eigenen Daten:

| | Amisia-Runde | Gargul-Runde (von Amisia beobachtet) |
|---|---|---|
| Bereiche | MS 1-100, OS 1-99 (D-21) | die der Lootleitung, Standard MS 1-100, OS 1-99 |
| Reserviert | zuerst (Amisias Liste) | zuerst (Gargul-Liste der Lootleitung) |
| Plus-Eins | Amisias Zählung, nur unter MS, nur mit Einstellung | Gargul-Liste, in jedem Bereich |
| Gewinner | Amisias Roll-Fenster, Ansage | Gargul der Lootleitung |
| Amisia-Fenster der Lootleitung | wie heute | zeigt die Würfe und Amisias Reihenfolge mit dem Hinweis "Gargul-Runde: Gargul sagt den Gewinner an." |

Mit gleicher Reservierungsliste und gleichen Bereichen (der Normalfall) kommt fast immer derselbe
Gewinner heraus. Abweichen kann es nur durch die verschiedenen Plus-Eins oder durch Bonus-Würfe
(Gargul "BR", eigene Bereiche wie 1-110). Amisia zeigt solche Würfe als "Bereich 1-110 (nicht in
Amisias Regeln)".

## Was es ausdrücklich nicht tut

- Kein Laden von softres.it, kein Link dorthin aus dem Addon, kein Abruf der internen API durch die
  Website (D-02, D-03 sinngemäß). softres.it wird nur als Quelle des eingefügten Textes genannt, wie
  heute.
- Kein Code aus Gargul, keine Gargul-Bibliotheken (LibDeflate, LibSerialize, AceComm) im Addon (D-19).
- Keine Bonus-Würfe, keine Übernahme von Gargul's oder softres.it's Plus-Eins in Amisias Zählung.
- Amisia antwortet nie auf Gargul-Nachrichten, auch nicht auf Versionsabfragen, Plus-Eins- oder
  Soft-Res-Anfragen. B2 liest nur Start und Ende einer Runde.
- Kein GDKP, keine Gargul-Auktionen.
- B3 nicht, solange der Nutzer es nicht ausdrücklich will.

## Abläufe

**A, Offizier vor dem Raid:** softres.it, Raid öffnen, Knopf "Gargul", "Copy to Clipboard". Im Spiel
Amisia, Soft-Reserves, "Importieren", einfügen. Die Vorschau zeigt "Code erkannt (softres.it):
12 Raider, 23 Reservierungen, 1 Hard-Reserve", dann "Übernehmen". Alles Weitere wie heute: Prüfen,
Erinnern, `!sr`.

**B1, Lootleitung startet mit Gargul:**
1. Die Lootleitung klickt in Gargul "Start". Gargul schickt die Startnachricht und die Warnung "You
   have 20 seconds to roll on [Item]".
2. Jeder Raider mit Amisia (Einstellung an) prüft: Kommt die Warnung vom Plündermeister oder
   Leiter? Ist er in meiner Gruppe und Offizier (Frage 6)? Läuft keine eigene Amisia-Runde? Dann
   öffnet sich das Würfel-Fenster mit dem Item, 20 Sekunden, "Mainspec", "Offspec" und "Passen".
   Oben steht klein "Runde von Vulo Hunt (Gargul)". "Passen" schließt nur das Fenster.
3. Die Amisia der Lootleitung (Offiziersansicht) legt eine beobachtete Runde an. Es kommt keine
   Ansage und kein `WS`, die Würfe werden gelesen. Ihr Roll-Fenster zeigt "Gargul-Runde".
4. Bei "Stop your rolls!" oder nach Ablauf: Fenster schließen, die Runde endet. Vergibt der
   Plündermeister das Item, erkennt Amisia wie heute, ob es MS, OS oder SR war (`ns.RollKind`).

**B, Lootleitung startet mit Amisia:** wie heute. Gargul-Raider lesen die Ansage und würfeln `/roll`
oder `/roll 99`. Mit B4 steht die Ansage zusätzlich auf Englisch da. Mit B3 (falls gebaut) öffnet
sich auch ihr Gargul-Fenster.

## Abnahmekriterien

- Wenn du die CSV von softres.it mit den Standardspalten (Kopfzeile `Item Name,Item ID,…,Raider
  Name,…`) einfügst, dann zeigt die Vorschau die richtige Zahl Raider und Reservierungen (heute 0).
  (allein)
- Wenn du diesen Gargul-Code einfügst, dann zeigt die Vorschau "Code erkannt (softres.it): 2 Raider,
  3 Reservierungen, 1 Hard-Reserve". Anna hat [Choker of the Fire Lord] doppelt reserviert, Bob
  [Bonereaver's Edge] mit Notiz "Tank". Erfundenes Beispiel, Inhalt siehe "Daten". (allein)
  `eNpljzFPxDAMhf+L5wxNVdoj27EwggSIAXVwa1dEpMnJSVmq/ncSDkErMsXv6X1+XmHmhIQJwaxgCQzgoOuRQMEojInpnMDo7la3N1V+CpYLHWX9LQtaekooKf46bd0U590SsQczoYusgGwcg9CLuLwMNgUxTEk4snxyBPO2gseZs3f2HksNhzHr8CiWY8qCD6nY+XdxS3zwJZXX2MTzNV/O0KeTbja1H/oy/rDvwrBDv6KIDfLHfkb/ceDrf/yu6tqM7PN9KHTof/XrqlEwZaqBe+uId81Lagh+iRKcK5l++wJJR3km`
- Wenn du aus dem Code ein Zeichen in der Mitte löschst, dann sagt die Vorschau "Der Code ist
  unvollständig oder verändert …" und übernimmt nichts. (allein)
- Wenn ein Gildenmitglied mit Gargul als Plündermeister eine Runde startet, dann öffnet sich bei dir
  das Amisia-Würfel-Fenster mit "(Gargul)". Ein Klick auf "Mainspec" würfelt 1-100, und das
  Roll-Fenster des Plündermeisters (falls er Amisia hat) zeigt den Wurf. (braucht: Gruppe und ein
  Gildenmitglied mit Gargul, ab 2026-11-04)
- Wenn ein Raider ohne Leiter-, Assistenten- oder Plündermeister-Rolle eine Gargul-Runde startet,
  dann öffnet sich bei dir kein Fenster. (braucht: Gruppe und Gargul)
- Wenn die Lootleitung mit Amisia eine Runde startet und ein Gargul-Raider `/roll 99` würfelt, dann
  zählt der Wurf als OS. (braucht: Gruppe)

## Sonderfälle

- **Bosskampf:** Chat und Würfe sind geheim. B1 sieht die Warnung nicht. B2 sieht die Nachricht,
  aber Würfeln geht erst nach dem Kampf ("Würfeln erst nach dem Kampf.", wie D-38). Eine Startwarnung,
  die vor mehr als 5 Sekunden kam, verfällt.
- **Zwei Runden gleichzeitig** (eine Amisia-, eine Gargul-Runde): Die eigene Amisia-Runde geht vor,
  denn es gibt nie zwei Runden (D-38). Die Gargul-Runde steht dann nur im Chat der Lootleitung:
  "Gargul-Runde von X auf [Item] erkannt, während eine Amisia-Runde läuft."
- **Lootleitung hat beide Addons und startet mit beiden:** B1/B2 erkennt ein gleiches Item innerhalb
  von 3 Sekunden als dieselbe Runde, also kein zweites Fenster.
- **`!sr`:** Jeder Gargul-Nutzer mit Liste antwortet auf `!sr`, Amisia nur als Lootleitung. Ein
  Raider kann also zwei Antworten bekommen. Amisia ändert daran nichts.
- **Namen:** Forever-Namen mit Nachnamen ("Vulo Pala"), softres.it meist nur "Vulo": Abgleich wie
  heute (Namenskorrekturen, `ns.SameNameIn`). Gargul-Namen mit "-Realm" werden gekürzt.
- **Client auf Englisch:** B1 kennt beide Sprachen der Gargul-Ansage, unabhängig von der Sprache des
  eigenen Clients.
- **Leere oder riesige Codes:** über 24 KB Text (bis zur Prüfung nach dem Bau 64 KB) oder über 256 KB entpackt: "Code zu groß". Höchstens
  2000 Reservierungen.
- **`/reload` während einer beobachteten Runde:** Die Runde ist weg, wie bei Amisia-Runden.

## Missbrauch/Vertrauen

- **Eingefügter Code (A):** gilt als unvertraut wie jeder Einfügeblock (D-26). Jedes Feld wird
  geprüft: Namen ohne Steuer- und Farbcodes, höchstens 48 Zeichen; Item-IDs 1-999999; Notiz ohne
  `|`-Codes, auf 60 Zeichen gekürzt; Zahlen nie negativ. Unbekannte Felder werden übergangen. Alles
  wird mit `pcall` entpackt, ein kaputter Code wirft nie einen Lua-Fehler.
- **Gefälschte Runde per Chat (B1):** Eine Schlachtzugswarnung können nur Leiter und Assistenten
  schicken. Amisia nimmt sie trotzdem nur vom Plündermeister oder, ohne Master Loot, vom Leiter.
  Der Absender ist immer der, den der Server setzt. Vorschlag: zusätzlich Offiziersrang wie D-38
  (Frage 6). Höchstens eine erkannte Runde pro Sekunde und Absender.
- **Gefälschte Gargul-Nachricht (B2):** Gargul selbst glaubt jedem in der Gruppe. Amisia ist
  strenger: dieselbe Prüfung wie B1. Das Feld `c` (Sendername in der Nachricht) zählt nie. Die
  Würfelzahl kommt weiter nur aus der Systemzeile (D-38). Eine gefälschte Runde kann also höchstens
  ein Fenster öffnen, nie einen Wurf erfinden. Nachrichten über 4 KB oder mit mehr als 16 Stücken
  verwirft Amisia ungelesen.
- **B3:** Amisia würde sich gegenüber Gargul als Gargul ausgeben. Gargul-Raider könnten nicht
  unterscheiden, ob Amisia oder ein echtes Gargul sendet. Deshalb nur nach ausdrücklicher Zustimmung
  und nur mit Offiziersrang.

## Daten

- `AmisiaDB.softres` bekommt Datenmodell 3 (`ns.MigrateSoftRes` legt die neuen Felder leer an):
  - `src`: `csv`, `code` oder `lines`;
  - `sid`: die softres-ID;
  - `updated`: Epoch aus `updatedAt`;
  - `notes = { [Name] = Notiz }`;
  - `classes = { [Name] = Klasse }`;
  - `plus = { [Name] = n }` (nur Hinweis);
  - `hard = { [itemID] = { for = Text, note = Text } }`.

  `raw` bleibt der eingefügte Text.
- Einstellungen, Abschnitt "Rolls und Vergabe" (`rolls`, Offiziere): `rolls.foreignWatch` ("Runden
  anderer Loot-Addons erkennen", Standard an) und `rolls.announceEnglish` ("Rundenansage auch auf
  Englisch", Standard aus, B4). Dazu in "Würfel-Fenster" (`rollwin`, für alle): `rollwin.foreign`
  ("Fenster auch bei Runden anderer Loot-Addons", Standard an). Mit B3 käme `rolls.foreignSend`
  dazu (Standard aus).
- Nachrichten: B1 keine. B2 meldet das Präfix `GargulComm2` an und sendet darauf **nie** etwas. In
  ARCHITECTURE.md kommt dafür eine eigene Tabelle "Fremde Präfixe (nur lesen)" mit Präfix, beachteten
  Aktionen 10/11, Deckel und Prüfung, und D-19 wird ergänzt (Frage 10). Keine neue Amisia-Nachricht,
  keine Blob-Art, keine Exportzeile, kein Einfügeblock, nichts auf der Website.
- Bibliotheken und Lizenzen: keine neuen. `Amisia/LICENSES` und die TOC bleiben, wie sie sind.
- Tests:
  - `tests/test_softres_export.lua` prüft die neue CSV-Kopfzeile, abgewählte Spalten, CRLF,
    Anführungszeichen und den Gargul-Code.
  - Der Test-Stub entpackt zlib nicht. Darum schreibt `run.py` beim Start die erfundenen Beispielcodes
    aus `tests/fixtures/softres_*.txt` mit Pythons `zlib` und `json` vor und reicht sie dem Stub
    (`STUB.inflate`). `DeserializeJSON` bekommt im Stub einen kleinen Lua-Leser.
  - `tools/tests/test_softres_samples.py` prüft, dass jedes Beispiel echt Base64 → zlib → JSON ist.
  - Für B2: Beispielbytes im LibSerialize-Format, nur in `tests/fixtures` erzeugt, nicht im
    Addon.
  - Beispielinhalt des Codes oben: `metadata.id = "ab12cd"`, Anna (Priest) 18814 zweimal, Bob
    (Warrior, Notiz "Tank", plusOnes 1) 17076, Hard-Reserve 17204 "für Gilde".
- D-05 (Namen anderer Addons) und `test_other_addons_are_not_named_in_the_addon` müssen für "gargul"
  eine Ausnahme bekommen: für die Chatmuster in B1, den Präfixnamen in B2 und die Beschriftungen
  (Frage 1).

## Offene Fragen

1. **D-05 lockern?** Amisia nennt andere Addons nie. Für diese Spec bräuchte es "Gargul" an drei
   Stellen. Erstens in der Vorschau ("Code erkannt (softres.it, Gargul-Export)"). Zweitens als
   Hinweis "(Gargul)" im Würfel-Fenster. Drittens intern im Präfix `GargulComm2` und in den
   Chatmustern. *Vorschlag:* Ausnahme nur für "Gargul", nur in diesen Texten und Dateien; der Test
   bekommt eine Liste erlaubter Stellen. Ohne Lockerung: in der Oberfläche "softres.it-Code" und
   "Runde eines anderen Loot-Addons". Die Muster und das Präfix stünden dann verschlüsselt im Code.
   Das wäre umständlich, also eher Lockerung.
2. **Kann der Forever-Client JSON lesen?** Im Spiel: `/run print(C_EncodingUtil.DeserializeJSON ~= nil,
   Enum.CompressionMethod.Zlib)`. Erwartet `true 1`. *Vorschlag:* Wenn nicht, den eigenen JSON-Leser
   nehmen. Der Selbsttest (`/amisia selbsttest`) bekommt diese Zeile dazu.
3. **Nutzt die Gilde Gargul auf Forever, und lädt es?** Ein Gildenmitglied mit Gargul tippt
   `/run print(C_AddOns.IsAddOnLoaded("Gargul"), C_ChatInfo.IsAddonMessagePrefixRegistered("GargulComm2"))`.
   Erwartet `true true`. *Vorschlag:* Erst dann B2/B3 bauen; B1 geht ohne.
4. **Auf welcher Sprache stehen die Gargul-Ansagen der Lootleitung?** Englisch ist Standard, Deutsch
   ist wählbar. *Vorschlag:* B1 kennt beide.
5. **Welche Optionen bauen?** *Vorschlag:* A1, A2, B1, B4 jetzt; B2 nach dem ersten Raid mit Gargul;
   B3 nein.
6. **Von wem zählt eine erkannte Gargul-Runde?** *Vorschlag:* nur vom Plündermeister (ohne Master
   Loot: Leiter) in der eigenen Gruppe **mit Offiziersrang**, wie D-38. Leitet ein Gast, zeigt
   Amisia kein Fenster.
7. **Plus-Eins aus softres.it:** nur anzeigen (Vorschlag) oder in Amisias Zählung übernehmen? D-22
   sagt heute: nur Amisias MS-Gewinne zählen.
8. **Hard-Reserves:** *Vorschlag:* Vermerk "HR" plus Rückfrage beim Rundenstart, und Lootregeln
   fassen das Item nicht an. Oder Hard-Reserves ganz übergehen?
9. **LootReserve-Export:** Bitte einmal den Text aus softres.it "LootReserve" (eines echten oder
   Test-Raids) schicken. Dann wird A1 oder ein eigener kleiner Leser daran geprüft.
10. **D-19 (genau zwei Präfixe):** für B2 ein drittes Präfix nur zum Lesen erlauben? *Vorschlag:* ja,
    mit eigener Tabelle "Fremde Präfixe" und dem Satz "auf fremden Präfixen wird nie gesendet". B3
    bräuchte zusätzlich "senden erlaubt".
11. **Wer entscheidet eine gemischte Runde?** *Vorschlag:* das Addon, das gestartet hat. Amisia zeigt
    bei einer Gargul-Runde ihre Reihenfolge nur zur Info.

## Entscheidungen

- 2026-10-11: Spec als Entwurf angelegt; noch keine Entscheidung des Nutzers.
- 2026-10-11, Prüfungen im Spiel (Client 70338): `C_EncodingUtil.DeserializeJSON` vorhanden,
  `Enum.CompressionMethod.Zlib` = 1 (Frage 2: ja, keine eigene JSON-Lesung nötig); Gargul ist beim
  Nutzer selbst installiert und geladen (`IsAddOnLoaded("Gargul")` = true true).
- 2026-10-11: A1 (CSV-Spalte "Raider Name") gebaut und in 2.25.2 veröffentlicht.
- 2026-10-11: Gebaut wird nach der Empfehlung: A2, B1 + B4 ("wer startet, entscheidet"); B2 erst bei
  Bedarf, B3 nicht. Vorschläge der offenen Fragen übernommen, solange der Nutzer nichts anderes sagt:
  D-05 erlaubt "Gargul" und "softres.it" an den nötigen Stellen (Vorschau, Würfel-Fenster, Muster),
  der Namenstest bekommt dafür eine Ausnahme; softres-+1 nur als Hinweis (D-22 bleibt); Hard-Reserves
  als "HR" markiert mit Rückfrage beim Start; eine erkannte Gargul-Runde zählt nur vom Plündermeister
  oder Leiter mit Offiziersrang in der eigenen Gruppe.
- 2026-10-11: A2, B1 und B4 gebaut (für 2.26.0, noch nicht veröffentlicht): F-091, F-092, F-093;
  DECISIONS D-44 und die Ausnahme in D-05 (der Namenstest erlaubt "gargul" nur in acht Dateien, dort nur
  in Kommentaren und Texten von `L[...]`). Abweichungen von der Spec: die Vorschau sagt, wie beauftragt,
  "Gargul-Code erkannt: N Reservierungen, M Hard-Reserves" (statt "Code erkannt (softres.it): ...");
  der Hard-Reserve-Eintrag heißt `{to, note}` (`for` ist in Lua ein Schlüsselwort); die Notiz steht im
  Tooltip, nicht im Würfel-Fenster (sie käme nur über `WS`); die Klasse wird gespeichert, aber noch
  nicht zum Namensabgleich benutzt; der Selbsttest bekommt die Zeile aus Frage 2 nicht (im Spiel schon
  geprüft).
- 2026-10-11, Prüfung nach dem Bau: höchstens 24 KB Code (zlib kann bis 1032:1 entpacken, und
  `DecompressString` kennt keine Grenze), JSON höchstens 20 Ebenen tief, Leerzeichen in linearer Zeit
  entfernt; Hand-Eingaben machen eine beobachtete Runde nicht "nicht angesagt"; die englische Ansage
  schneidet keine Reservierenden mehr ab; Zeilen von Raidern warten nicht auf die Gildenliste (D-44).
