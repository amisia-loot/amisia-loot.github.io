# Layer-Wechsel mit allen Spielern und der Layer-Selbsttest (F-191, F-192)

Datum: 2026-11-13. Entscheidung: DECISIONS D-124 (ändert D-117 in einem Punkt). Baut auf
`docs/specs/2026-11-12-layer.md` auf.

## Ziel

Nutzer 2026-11-13: "das layer ding soll auch mit anderen spieler und addons gehen nicht nur mit
gildenmitgliedern". Bis 2.82.0 endete der Wechsel an der Gildengrenze (D-117). Im selben Zug der Selbsttest
für den Layer ("Erst Punkt 2"): nichts am Layer ist bisher im Spiel bestätigt.

## Was es tut

**Teil 1, Wechsel mit Spielern außerhalb der Gilde (F-191).** Der Weg ist die Chat-Zeile, die Spieler mit und
ohne Layer-Addon schreiben ("inv layer", `SW.IsRequestLine` aus F-185 Teil 6), nichts sonst.

- **Fragen (jeder, ohne Einstellung):** "Im Kanal fragen" im Fenster Layer öffnet die Chatzeile mit
  `/<layer.channel> <layer.chatText>` (Kanal 1, "inv layer"); der Spieler schickt sie mit Enter ab. 60 Sekunden
  lang gilt die nächste Einladung als der Wechsel, egal von wem; mit `layer.autoAccept` nimmt Amisia sie an.
- **Helfen (`layer.others`, aus):** Eine Bitte, die irgendein Spieler flüstert oder in einen Kanal schreibt, in
  dem man ist (`CHAT_MSG_CHANNEL`), bekommt die Frage "<Name> (nicht in der Gilde) bittet im Chat um einen
  Layer-Wechsel. Einladen?". Ein Gildenmitglied im Kanal wird behandelt wie im Gildenchat.
- **Ohne Frage (`layer.othersAuto`, aus):** nur für eine Bitte in einem Kanal der eigenen Zone (Allgemein,
  Lokale Verteidigung: `zoneChannelID` 1 und 22), weil der Bittende dann sicher in derselben Zone steht.

**Teil 2, `/amisia selbsttest layer` (F-192).** `Core/SelfTestLayer.lua`, nur Forever. Der Bericht im
Selbsttest-Fenster:

1. Funktionen: was Lesen, Einladen/Annehmen/Verlassen und der Chat brauchen.
2. Jetzt: Zone, GUID des Ziels, aktueller Layer, bekannte Layer der Zone.
3. Namensplaketten: jede Plakette in Sicht: Kreaturen, von Spielern Gesteuertes, geheime GUIDs, die
   Zonen-Kennungen mit ihrer Zahl.
4. Diese Sitzung: gelesene Einheiten je Quelle (`LY.Stats`), Layer-Wechsel ohne Zonenwechsel (wie viele in einer
   Gruppe, wie viele Hin und Her), die letzten Wechsel mit Uhrzeit, was Amisias Einladungen, Annahmen und
   Verlassen taten (`SW.Trace`), die Wechsel über Amisia, die im Chat gesehenen Bitten je Kanal.
5. Kanäle und Einstellungen.
6. Aufrufe ohne Tastendruck (aus Timern, wie der Wechsel sie macht): eine Einladung an den Namen, den niemand
   hat; nur allein und ohne offene Einladung `AcceptGroup` und `LeaveParty`, die dann nichts tun. Es zählt, ob
   das Spiel Amisia sperrt (`ADDON_ACTION_BLOCKED`/`FORBIDDEN`).
7. Ergebnis in Worten und darunter, wie man einen echten Wechsel prüft.

## Was es ausdrücklich nicht tut

- Amisias eigene Nachrichten (YQ, YA, YI) bleiben in der Gilde: außerhalb gibt es keinen Kanal, über den zwei
  fremde Amisia-Clients sich finden.
- Die versteckten Nachrichten eines anderen Layer-Addons spricht Amisia nicht (D-04: dafür müsste dessen Code
  gelesen werden).
- Sagen und Schreien werden nie gelesen. Ohne `layer.others` schaut Amisia keine Kanalzeile an.
- Amisia schreibt nichts selbst in den Chat: die Bitte schickt der Spieler ab.
- Der Selbsttest speichert nichts und sendet nichts.

## Abläufe

1. Fragen: Fenster Layer, "Im Kanal fragen", Enter. Ein Spieler (oder sein Addon) lädt ein, Amisia nimmt an, in
   der Gruppe einen NPC anzielen: "Gewechselt: Layer B".
2. Helfen: ein Fremder schreibt "inv layer" in Allgemein; mit `layer.others` kommt die Frage, mit
   `layer.othersAuto` die Einladung sofort.
3. Prüfen: `/amisia selbsttest layer`, Bericht kopieren und schicken.

## Abnahmekriterien

- Ohne `layer.others` gibt die Bitte eines Fremden nichts, und keine Kanalzeile wird gezählt.
- Mit `layer.others`: Flüstern und Kanal fragen; der Klick lädt ein; ein zweiter Fremder binnen 5 Sekunden
  bekommt keine Frage; derselbe Spieler binnen einer Minute keine zweite Einladung.
- `layer.othersAuto` lädt nur im Zonenkanal ohne Frage ein; `layer.autoInvite` allein lädt keinen Fremden ein.
- "Im Kanal fragen" öffnet `/<Kanal> <Text>`; danach wird die Einladung eines Fremden angenommen, nach "Im
  Gildenchat fragen" nicht.
- Der Selbsttest ruft in einer Gruppe weder Annehmen noch Verlassen auf, im Kampf und in einer Instanz nichts,
  und lädt nur den Namen ein, den niemand hat.

## Sonderfälle

- Ohne Gilde: kein Warten auf die Gildenliste; das Fenster zeigt den Hinweis auf den Kanal.
- Die Antwort der Gildenliste kommt spät: eine Bitte, die älter als 10 Sekunden ist, gilt nicht mehr.
- Der Spieler ist in keinem Kanal der eingestellten Nummer: "Du bist in keinem Kanal n ...".
- Der Bittende ist schon in der eigenen Gruppe: nichts.
- Wer selbst gerade fragt (Gilde gefragt, Einladung erbeten, im Chat gefragt, in der Wechselgruppe), lädt
  niemanden ein: sonst lüden sich zwei Fragende im Zonenkanal gegenseitig ein.
- Kanalzeilen warten nie auf die Gildenliste (sie kommen in Mengen): kann die Liste gerade nicht antworten,
  wird die Zeile übergangen.
- Nach "Im Kanal fragen" ersetzt die Einladung eines zweiten Spielers die nicht angenommene des ersten; eine
  neue Bitte beginnt ohne die alte. In einer Instanz nimmt Amisia nie an, auch wenn die Bitte noch läuft.
- `layer.chat` aus, `layer.others` an: das Flüstern eines Gildenmitglieds gilt wie das eines Fremden (nur die
  Frage).
- Eine offene Einladung beim Selbsttest: `AcceptGroup` wird nicht aufgerufen (es nähme sie an). Als offen gilt
  auch eine Einladung der letzten zwei Minuten (ein anderes Addon kann ihr Fenster versteckt haben) und ein
  Client, der nicht sagen kann, ob das Fenster zu sehen ist.
- Namensplaketten mit geheimen GUIDs, Begleiter von Spielern: zählen nicht als Kreaturen.

## Missbrauch/Vertrauen

- Fragen von Fremden nur mit `layer.others`; höchstens eine in 5 Sekunden; Einladungen: derselbe Spieler einmal
  in der Minute, sechs in zehn Minuten, nie in Instanzen (D-117).
- Nach "Im Kanal fragen" nimmt Amisia eine Minute lang jede Einladung an, auch eine, die nichts mit der Bitte zu
  tun hat; nur wer allein ist, und nur mit `layer.autoAccept`. Der Tooltip sagt das.
- Eine Zeile mit "?", mit Farbcodes, über 40 Zeichen oder mit "[" vorn ist keine Bitte (F-185).

## Daten

Keine gespeicherten Daten, kein neues Nachrichtenformat. Einstellungen im Abschnitt `layer`: `layer.others`
(aus), `layer.othersAuto` (aus), `layer.channel` (1 bis 10, Vorgabe 1). In der Sitzung: `LY.Stats()` (Lesungen
je Quelle, 30 Wechsel des aktuellen Layers), `SW.Trace()` (Aufrufe, Sperren, Beitritte, Wechsel, Bitten je
Kanal).

## Offene Fragen

- Gibt der Forever-Client Kanalzeilen an Addons, und ist Kanal 1 dort Allgemein? (Der Selbsttest listet die
  Kanäle und zählt die gesehenen Bitten.)
- Soll Amisia das versteckte Format eines anderen Layer-Addons sprechen? Dafür müsste dessen Code gelesen
  werden (D-04 verbietet das): Entscheidung des Nutzers.

## Entscheidungen

DECISIONS D-124. Annahmen (nicht gefragt): Helfen ist aus; ohne Frage nur im Zonenkanal; Kanal 1 als Vorgabe.
Tests: `tests/test_layer_others.lua`, `tests/test_selftest_layer.lua`; Prüfzeilen in FEATURES F-191, F-192.
