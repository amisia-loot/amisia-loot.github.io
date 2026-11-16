# Spec: Layer-Wechsel mit den Nutzern des verbreiteten Layer-Addons

Stand: 2026-11-16 · Status: Entwurf ·
Feature: F-220

## Ziel

Nutzer 2026-11-16, nach 2.94.0 (F-216): "und können wir das layer bei uns genau so machen wie bei <dem verbreiteten
Layer-Addon>", dann "will es genauso wie <es> und es soll damit auch gehen", und auf die Frage, ob dafür dessen Code
gelesen werden darf (nur das Nachrichtenformat, kein Code übernommen): "Ja, Ausnahme erlauben". Gelesen: Version
1.14.25 von CurseForge; die Notiz mit Zeilenangaben liegt außerhalb des Repos
(`~/addons/_research`, Notiz vom 2026-11-16, D-05).

Der Unterschied, den der Nutzer im Spiel merkt: jenes Addon hat Hunderttausende Nutzer, fast jede Zone hat einen,
der hilft; Amisia erreicht nur Amisia-Nutzer. Gelöst ist es, wenn "Layer wechseln" in Amisia auch die Helfer des
anderen Addons erreicht und von ihnen eingeladen wird, und wenn Amisia mit "Helfen" auch dessen Nutzer einlädt.

## Was es tut

**Teil 1, fragen wie dort (Forever).** "Layer wechseln" schickt an die Namen aus `/who` (wie bisher, eine Abfrage je
Klick) dieselbe leise Bitte wie jenes Addon: auf dessen Präfix, als Flüstern, die Zeile
`inv layer <LS {Zone} not {eigener Layer} {x},{y}>` (Zone = Karten-Id der Zone, Layer = `{Server}-{Zonen-Kennung}`
der Kreatur-GUID, Position in Prozent). Antworten `heard {ich}|{Layer}|{Zone}|{h oder -}` und `same` zählen wie
Amisias `ZA`: das Fenster zeigt "Erreicht: n · gehört: m · auf anderem Layer: k". Die Helfer jenes Addons laden von
selbst ein; Amisia nimmt mit "Einladung annehmen" (an) die erste Einladung eines Spielers an, der geantwortet hat
(nie eine andere). Die bisherige `ZQ` geht nur noch an Namen, die schon als Amisia-Nutzer geantwortet haben (die
neue Bitte erreicht auch Amisia ab dieser Version), damit nicht zwei Flüsterer je Name rausgehen.
"Layer B" und "Nur neue Layer" werden zu `want {Layer}` bzw. mehreren `not {Layer}`.

**Teil 2, helfen wie dort.** Amisia hört auf dessen Präfix und beantwortet jede solche Bitte aus der eigenen Zone
mit `heard` (auch bei Helfen aus, dann mit `-`), auf demselben Layer mit `same`. Mit Helfen an lädt es ein: mit
Amisias Grenzen (sechs in zehn Minuten, derselbe Spieler einmal je Minute, nie in Instanzen, nicht in der
Gruppensuche, optional nicht im Kampf, nur allein oder mit eigenen Wechsel-Gästen), Beute "Jeder gegen jeden".
Gäste werden nicht von selbst entfernt (wie dort; "Helfen aus" und `/amisia layer kick` entfernen sie).

**Teil 3, Layer gleich wie dort.** Jenes Addon zählt auf Forever seit 1.14 nur den Server-Teil der GUID als Layer
(`6843-8` und `6843-3` sind derselbe Layer; die Zonen-Kennung ändert sich bei einem Neustart der Welt). Amisia
nimmt bisher die Zonen-Kennung (D-117). Vorschlag: Amisia vergleicht ebenfalls über den Server-Teil, behält die
Buchstaben, und der Selbsttest zeigt beide Teile, damit wir es im Spiel bestätigen.

**Teil 4, Neustart der Welt.** `SHARD_TRANSFER_IMMINENT` mit `GetEvictionTimeRemaining()`: die Leiste und das
Fenster zeigen "Neustart in m:ss", danach 2 Minuten "gleich"; währenddessen lädt Helfen nicht ein (wie dort).
`SHARD_TRANSFER` zählt als Wechsel (schneller als die Kreaturen).

**Teil 5, die kleinen Teile.**
- "Gilde zuletzt fragen" (an): Gildenmitglieder aus `/who` erst, wenn sonst niemand antwortet.
- "Fragende in der Nähe überspringen" (aus, 50-200 Meter, Vorgabe 150): Bitten aus der Nähe lädt Helfen nicht ein;
  ohne Position im Text wird nicht eingeladen, solange die Einstellung an ist.
- Leiste: "Eine Zeile" (aus) und "Abdunkeln" (Regler) in den Einstellungen.
- Nach dem Wechsel verlässt Amisia die Gruppe nur, wenn der Einladende geantwortet hat (wie dort; Amisias eigene
  Bitten erfüllen das schon).

## Was es ausdrücklich nicht tut

- Kein Code jenes Addons im Repo; nur das Format seiner Nachrichten, eigener Code (D-145). Sein Name steht nur als
  Präfix-Konstante in genau einer Codezeile, nie in Texten, Kommentaren oder Commits.
- Keine Gilden- und Kanal-Bitten jenes Addons (`claim`, `pos`, `zone`, `any`, `ping`): auf Forever nutzt es sie
  nicht mehr; Amisia hat dafür seine eigenen Gildennachrichten.
- Kein Tausch von Buchstaben (sie bleiben bei beiden lokal).
- Era/TBC: unverändert (kein Layer-Wechsel dort).

## Abläufe

1. Ohne Gilde, Elwynn, Layer A: "Layer wechseln". `/who` findet 40 Spieler; 40 leise Bitten gehen raus (gedrosselt).
   12 antworten `heard`, 3 davon mit `h` auf anderem Layer; der erste lädt ein, Amisia nimmt an, ein NPC zeigt
   Layer B, nach 5 Sekunden verlässt Amisia die Gruppe.
2. Als Helfer: ein Nutzer jenes Addons bittet; Amisia antwortet `heard ...|h`, lädt ein, stellt "Jeder gegen
   jeden"; der Gast verlässt die Gruppe selbst.
3. Neustart der Welt angekündigt: "Neustart in 4:12" in der Leiste; Helfen lädt bis dahin nicht ein.

## Abnahmekriterien

- Wenn du in einer belebten Zone "Layer wechseln" klickst, dann steht im Fenster "gehört: n" mit n > 0, auch ohne
  andere Amisia-Nutzer, und ein Helfer auf einem anderen Layer lädt dich ein; nach einem angezielten NPC steht
  "Gewechselt: Layer B" (braucht: Gruppe).
- Wenn ein Nutzer jenes Addons in deiner Zone wechseln will und du hilfst, dann lädt Amisia ihn ein und er
  verlässt die Gruppe nach dem Wechsel von selbst (braucht: Gruppe).
- Wenn du auf demselben Layer bist wie der Fragende, dann lädt Amisia nicht ein.
- Wenn das Spiel einen Neustart der Welt ankündigt, dann zeigt die Leiste "Neustart in m:ss".
- Wenn du `/amisia selbsttest layer` tippst, dann zeigt der Bericht Server-Teil und Zonen-Kennung des Ziels und ob
  Bitten auf dem fremden Präfix rausgehen.

## Sonderfälle

- Jenes Addon ändert sein Format (sechsmal in zwei Monaten): unbekannte Antworten werden still verworfen; der
  Selbsttest und das Fenster ("gehört: 0" in belebten Zonen) zeigen es; dann ziehen wir nach.
- Ältere Versionen jenes Addons vergleichen die ganze Layer-Id: sie können einen Spieler vom selben Layer
  einladen. Amisia merkt "kein Wechsel" nach 15 Sekunden und verlässt die Gruppe (schon so).
- Mehrere Einladungen zugleich: die erste eines Antwortenden zählt, die anderen scheitern still im Spiel.
- Spieler mit Amisia und dem anderen Addon zugleich: Amisia antwortet nicht auf dessen Präfix, wenn das andere
  Addon geladen ist (sonst kämen zwei Antworten und zwei Einladungen).
- Bosskampf, Kampfsperre der Nachrichten: nichts geht raus (wie bisher).

## Missbrauch/Vertrauen

- Fremde dürfen auf diesem Präfix nur bitten (`inv layer <LS ...>`) und antworten (`heard`, `same`); alles andere
  wird verworfen. Felder werden geprüft (Zahlen, Länge höchstens 120 Zeichen, Zone, Position 0-100).
- Dieselben Grenzen wie bei Amisias Bitten: sechs Einladungen in zehn Minuten, einer je Minute, nur eigene Zone, nie
  in Instanzen; `heard` höchstens einmal je Fragendem in 10 Sekunden, 20 Antworten je Minute insgesamt.
- Flüstern an Fremde nur an Namen aus der eigenen `/who`-Liste der letzten 2 Minuten oder an Absender einer Bitte;
  höchstens 8 je Sekunde. Das Spiel kann viele Flüsterer bestrafen: Amisia schickt je Name höchstens eine Bitte.
- Amisia nimmt nur die Einladung eines Spielers an, der auf die eigene Bitte geantwortet hat.

## Daten

- Präfix jenes Addons registriert (zusätzlich zu Amisias eigenem), Nachrichten als Klartext (`WHISPER`), nicht über
  Amisias Kodierung.
- `AmisiaDB.layerHosts` bekommt die Antwortenden jenes Addons dazu (7 Tage, höchstens 200, wie bisher).
- Einstellungen (Abschnitt Layer): "Gilde zuletzt fragen" (an), "Fragende in der Nähe überspringen" (aus) mit
  Meter-Regler (150), "Eine Zeile" (aus), "Abdunkeln" (Regler), "Mit dem anderen Layer-Addon zusammenarbeiten" (an).
- DECISIONS D-145 (Ausnahme von D-04/D-05/D-117: Format gelesen, Präfix gesprochen); ARCHITECTURE: Nachrichten,
  Einstellungen; `tools/tests/test_contracts.py` erlaubt den Namen genau in der Präfix-Konstante.

## Offene Fragen

1. Teil 3: den Layer wie dort über den Server-Teil vergleichen? Vorschlag: ja, und den Selbsttest beide Teile
   zeigen lassen.
2. Amisias eigene `ZQ` an Fremde nur noch an bekannte Amisia-Helfer, sonst nur die Bitte im fremden Format?
   Vorschlag: ja (halb so viele Flüsterer; ältere Amisia-Versionen bis 2.97 hören die neue Bitte nicht, die
   Gilde fragt Amisia weiter mit `YQ`).
3. Amisia nimmt die Einladung eines Helfers jenes Addons von selbst an (dort klickt man selbst)? Vorschlag: ja, wie
   bei Amisias Helfern, nur von Antwortenden.
4. Alles in einem Release mit Selbsttest? Vorschlag: ja; was der Selbsttest als gesperrt meldet, schaltet Amisia ab.

## Entscheidungen

- (offen)
