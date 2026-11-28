# Spec: Hinweis, wenn eine Berufs-Abklingzeit bereit wird

Stand: 2026-11-28 · Status: freigegeben 2026-11-28 ·
Feature: F-241

## Ziel

Heute nennt Amisia bereite Abklingzeiten (Transmutation, Mondstoff ...) nur einmal beim Einloggen und auf
Berufe > Abklingzeiten (F-232). Wird eine Abklingzeit während des Spielens bereit, merkt man es nicht und
verschenkt Stunden. Gelöst ist es, wenn man im Moment des Bereitwerdens einen Hinweis bekommt und auf einen Blick
sieht, welche Abklingzeit als Nächstes kommt.

## Was es tut

- **Hinweis beim Bereitwerden.** Endet die Abklingzeit eines eigenen Charakters, während man spielt, kommt:
  - eine Chatzeile "Transmutation ist bereit (Vulo)." in Grün;
  - beim gerade gespielten Charakter zusätzlich ein Banner in der Bildschirmmitte (wie eine Schlachtzugswarnung,
    aber ohne den Kanal "Schlachtzug") und ein Ton.
- **Je Abklingzeit schaltbar.** Im Reiter Abklingzeiten trägt jede eigene Zeile eine Glocke (dieselbe Marke wie
  die gesuchten Rezepte). Ein Klick schaltet den Hinweis dieser Zeile (Charakter und Abklingzeit) aus und wieder an.
  Ausgeschaltete Zeilen nennt auch die Login-Zeile nicht mehr.
- **"Als Nächstes".** Über "Deine Charaktere" steht eine Zeile "Als Nächstes: Mondstoff (Kim) in 3 Std. 12 Min."
  (die eigene Zeile mit der kürzesten Restzeit, die noch nicht bereit ist). Dieselbe Zeile gibt
  `/amisia abklingzeiten` ohne die Seite im Chat aus.
- **Ton auch beim Login.** Nennt die Login-Zeile etwas Bereites, kommt einmal derselbe Ton (nur mit dem Ton an).
- **Zwei neue Einstellungen** unter Einstellungen > Berufe: "Hinweis, wenn eine Abklingzeit bereit wird" (an) und
  "Abklingzeit bereit: mit Ton" (an, wirkt nur mit dem Hinweis an).

## Was es ausdrücklich nicht tut

- Kein Hinweis für Gildenmitglieder: wer in der Gilde bereit wird, zeigt der Reiter und der Tooltip wie bisher.
  Ein Hinweis für jeden Transmutierer der Gilde wäre Lärm.
- Kein Fortschrittsbalken je Abklingzeit: die Restzeit steht schon als Text da.
- Keine neue Nachricht an die Gilde, kein neuer Weg zum Lesen der Restzeit: alles rechnet mit dem gespeicherten
  "bereit ab" aus F-232.
- Kein eigener Tonwähler: ein fester Ton des Spiels.

## Abläufe

1. Der Spieler transmutiert mit Vulo. F-232 speichert "bereit ab" in 23 Std.
2. Er spielt am nächsten Tag weiter. Sobald der Zeitpunkt vorbei ist (höchstens 5 s später, der bestehende
   Ticker), kommt die Chatzeile, das Banner und der Ton.
3. Ist er gerade im Kampf, in einem Bosskampf oder in der Kampfsperre, wartet der Hinweis, bis er aus dem Kampf
   ist; dann kommt er einmal.
4. Spielt er gerade Kim und Vulos Abklingzeit wird bereit, kommt nur die Chatzeile (Vulo kann es gerade nicht
   nutzen; Banner und Ton gibt es für den gespielten Charakter).
5. Will er Kims Mondstoff nicht mehr gemeldet haben, klickt er im Reiter auf die Glocke der Zeile; sie wird grau.

## Abnahmekriterien

- Wenn eine Abklingzeit des gespielten Charakters während des Spiels bereit wird, dann steht binnen 5 Sekunden
  "<Abklingzeit> ist bereit (<Name>)." im Chat, ein Banner in der Mitte, und ein Ton spielt.
- Wenn das im Kampf geschieht, dann kommt der Hinweis erst, wenn der Kampf vorbei ist, und nur einmal.
- Wenn du auf Berufe > Abklingzeiten die Glocke einer eigenen Zeile ausschaltest, dann kommt für sie kein Hinweis,
  und die Login-Zeile nennt sie nicht.
- Wenn eine eigene Abklingzeit läuft, dann steht über "Deine Charaktere" "Als Nächstes: <Abklingzeit> (<Name>)
  in ..." mit der kürzesten Restzeit.
- Wenn du "Abklingzeit bereit: mit Ton" ausschaltest, dann kommen Chatzeile und Banner ohne Ton.

## Sonderfälle

- **Bereit geworden, während man offline war:** kein neuer Hinweis, das sagt die Login-Zeile wie bisher. Gemeldet
  wird nur, was nach dem Einloggen (bzw. nach dem `/reload`) bereit wird.
- **`/reload`:** was schon vorher bereit war, wird nicht nochmal gemeldet (Zeitpunkt vor dem Laden).
- **Neue Lesung verschiebt den Zeitpunkt** (z. B. Talent kürzt die Abklingzeit): es zählt der gespeicherte
  Zeitpunkt; der Hinweis kommt einmal je Zeitpunkt.
- **Mehrere werden zugleich bereit:** eine Chatzeile je Abklingzeit, ein Banner und ein Ton für alle zusammen.
- **Bosskampf, Kampfsperre:** Banner, Chat und Ton warten (keine geheimen Werte nötig, nur eigene Daten).
- **Schlachtfeld, Instanz:** der Hinweis kommt außerhalb des Kampfes normal.
- **Andere Realm oder Fraktion:** nur Charaktere, die der Reiter zeigt (`PC.Own`, dieser Realm und diese Fraktion).
- **Client auf Englisch:** alle Texte in `L[...]`.
- **Ein verlernter Beruf:** seine Zeile ist weg (F-232), es gibt keinen Hinweis.

## Missbrauch/Vertrauen

Nichts: es kommt nur aus den eigenen gespeicherten Daten, nichts von anderen Spielern löst einen Hinweis aus.

## Daten

- Einstellungen im Abschnitt `prof`: `prof.cdAlert` (an), `prof.cdSound` (an).
- Neuer gespeicherter Schlüssel `prof.cdMute = { ["<Charakter>|<Zeile>"] = true }`, die Zeile wie in `PC.Own`
  (`c310` für Transmutationen, sonst die Spell-ID), beim Laden geprüft (nur eigene Charaktere aus `prof.cd`,
  höchstens 200 Einträge).
- Was schon gemeldet ist, steht nur im Speicher der Sitzung, nicht in `AmisiaDB`.
- Keine neue Nachrichtenart, keine Exportzeile, kein Einfügeblock.
- ARCHITECTURE: die Zeile von `Gear/ProfCooldowns.lua`, die Einstellungen `prof`, der Schlüssel `prof.cdMute`.
  DECISIONS: ein Eintrag D-175 (nur eigene Charaktere, Banner und Ton nur beim gespielten, kein Hinweis für
  Offline-Bereitgewordenes, Warten im Kampf).

## Offene Fragen

1. Banner und Ton nur beim gespielten Charakter, für Twinks nur die Chatzeile? Vorschlag: ja.
2. Hinweis und Ton standardmäßig an? Vorschlag: beides an (der Hinweis kommt höchstens ein paarmal am Tag).
3. Zusätzlich ein Hinweis, wenn ein bestimmtes Gildenmitglied bereit wird (z. B. wenn man einen Transmutierer
   braucht)? Vorschlag: nein, erst wenn jemand danach fragt.

## Entscheidungen

- 2026-11-28: alle drei Fragen: "Passt, bauen" -> Banner und Ton nur beim gespielten Charakter, Twinks nur die
  Chatzeile; Hinweis und Ton standardmäßig an; kein Hinweis für Gildenmitglieder.
- Beim Bauen: die Einstellungsseite kennt kein Ausgrauen einer Einstellung; der Ton wirkt nur mit dem Hinweis an.
  Ein Klick auf eine eigene Zeile schaltet wie die Glocke (eigene Zeilen hatten keinen Klick).
