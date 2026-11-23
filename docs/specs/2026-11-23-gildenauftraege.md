# Spec: Gildenaufträge (Herstellwünsche an die Gilde)

Stand: 2026-11-23 · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-231

## Ziel

Wer etwas hergestellt braucht, stellt einen Auftrag an die Gilde, statt im Gildenchat zu rufen oder Hersteller einzeln
anzuflüstern. Wer das Rezept kann, erfährt davon, nimmt den Auftrag an und meldet ihn fertig. Gelöst ist es, wenn ein
Auftrag ohne Chat-Hin-und-Her vom Wunsch bis "erhalten" läuft und beide jederzeit sehen, wo er steht. Drei verbreitete
Gildenaddons haben das (Recherche 2026-11-23); eigener Code, eigene Nachrichten, Amisias Stil.

Name: "Gildenauftrag", nie "Handwerksauftrag" (so heißen im Spiel schon die Aufträge der Händlergunst, F-051, Seite Berufe).

## Was es tut

- **Auf der Seite Berufe, in den Details eines Rezepts:** neben "Fragen" ein Knopf "Auftrag stellen". Er öffnet ein kleines
  Fenster: Anzahl (1-20), Material ("bringe ich mit" / "vom Hersteller" / "nach Absprache"), Notiz (60 Zeichen, z. B.
  "zahle 5g"), "Auftrag stellen".
- **Neuer Reiter "Aufträge" auf der Seite Berufe** (nach "Herstellliste"), zwei Teile:
  - "Meine Aufträge": eigene offene Aufträge mit Zustand ("offen", "angenommen von <Name>", "fertig: <Name>"), Knöpfe
    "Zurückziehen" und, wenn fertig, "Erhalten" (schließt ihn).
  - "Für mich herstellbar" und "Alle offenen": Aufträge der Gilde mit Rezept, Anzahl, Auftraggeber (Klassenfarbe,
    online/offline), Alter, Material, Notiz. Bei Rezepten, die einer meiner Charaktere kann, "Annehmen"; bei
    angenommenen meine "Fertig" und "Abgeben" (gibt ihn wieder frei). Die Reagenzien zeigt der Klick auf das Rezept wie
    sonst, mit "herstellbar: n" (F-159).
- **Hinweis für Hersteller:** kommt ein Auftrag für ein Rezept, das einer der eigenen Charaktere kann, eine Chatzeile
  "Amisia: Gildenauftrag von <Name>: 4x [Item]. /amisia auftraege" (abschaltbar), und die Zahl der offenen, für mich
  herstellbaren Aufträge im Tooltip des Minimap-Knopfs.
- **Beim Einloggen** eine Zeile, wenn Aufträge auf mich warten: "Amisia: 2 Gildenaufträge kannst du herstellen." (nur
  einmal je Sitzung).
- **Für den Auftraggeber** Chatzeilen bei "angenommen von" und "fertig von".
- **Optional:** "Im Gildenchat ankündigen" beim Stellen (aus als Vorgabe): eine Zeile "Suche Hersteller: 4x [Item]"
  im Gildenchat für Mitglieder ohne Amisia, vom Klick ausgelöst.
- `/amisia auftraege` öffnet den Reiter. Einstellungsabschnitt "Gildenaufträge" (Reiter Gilde).

## Was es ausdrücklich nicht tut

- Kein Gold, keine Bezahlung, kein Handel und keine Post: Amisia vermittelt nur; übergeben wird im Spiel (Notiz für
  Absprachen). Kein Auktionshauspreis (Nutzer 2026-11-06).
- Keine Aufträge an Fremde oder andere Gilden, keine Sammelaufträge ("bringe 20 Erz"): nur Rezepte aus den Berufsdaten.
- Keine Bewertungen, Ranglisten oder Statistiken über Hersteller.
- Nicht auf der Website (das ist F-069 Mats; später eine eigene Spec, wenn gewünscht).
- Nichts ändert den Rezept-Austausch (F-035): wer was kann, kommt weiter von dort.

## Abläufe

1. Anna sucht auf Berufe "Mondstoff-Robe", klickt "Auftrag stellen", wählt 1 Stück, "bringe ich mit", Notiz "Stoff hab
   ich", "Auftrag stellen". Amisia legt den Auftrag bei Anna an und sagt der Gilde den Auftrag (`OA`).
2. Ben (Schneider, kann das Rezept laut eigenem Berufsfenster) bekommt die Chatzeile; im Reiter "Aufträge" steht der
   Auftrag unter "Für mich herstellbar". Clara ohne das Rezept sieht ihn nur unter "Alle offenen".
3. Ben klickt "Annehmen": Amisia flüstert Anna (`OT`, nur wenn sie online ist; sonst ist der Knopf grau: "Anna ist
   offline"). Annas Client nimmt ihn an (der erste gewinnt), sagt der Gilde den neuen Stand (`OA` "angenommen von Ben"),
   und Anna liest "Ben hat deinen Auftrag angenommen". Bei Ben steht der Auftrag jetzt mit "Fertig" und "Abgeben".
4. Ben stellt her, handelt oder schickt die Robe und klickt "Fertig": Anna liest "Ben: Mondstoff-Robe ist fertig"; ihr
   Auftrag steht auf "fertig". Anna klickt "Erhalten": der Auftrag verschwindet bei allen (`OA` mit Zustand "zu").
5. Wer sich später einloggt, fragt einmal die Gilde (`OQ`); die Auftraggeber, die online sind, flüstern ihre offenen
   Aufträge zurück. Aufträge von Spielern, die offline sind, kennt jeder Client aus dem, was er schon gehört hat
   (gespeichert, mit "zuletzt gehört").

## Abnahmekriterien

- Wenn du auf Berufe bei einem Rezept "Auftrag stellen" klickst und den Auftrag stellst, dann steht er im Reiter
  "Aufträge" unter "Meine Aufträge" als "offen".
- Wenn ein Gildenmitglied mit Amisia einen Auftrag für ein Rezept stellt, das du kannst, dann steht im Chat
  "Gildenauftrag von <Name>: ..." und der Auftrag unter "Für mich herstellbar" (braucht: Gilde).
- Wenn du "Annehmen" klickst, dann steht beim Auftraggeber "angenommen von <dir>", und ein zweiter Hersteller kann ihn
  nicht mehr annehmen (braucht: Gilde).
- Wenn du "Fertig" klickst und der Auftraggeber "Erhalten", dann ist der Auftrag bei allen weg (braucht: Gilde).
- Wenn du dich einloggst, während ein Gildenmitglied einen offenen Auftrag hat, dann steht er binnen etwa einer Minute
  in "Alle offenen" (braucht: Gilde).

## Sonderfälle

- **Auftraggeber offline:** sein Auftrag bleibt sichtbar ("offline, zuletzt gehört vor 2 Std."), "Annehmen" ist grau.
  Annahme und "Fertig" brauchen ihn online, damit es nur einen Stand gibt (sein Client ist die Quelle).
- **Hersteller offline bei "Erhalten" o. Ä.:** der Auftraggeber schließt allein; der Hersteller sieht das beim nächsten
  Login (`OQ`) oder am Ablauf.
- **Ablauf:** ein Auftrag ohne Änderung schließt sich nach 14 Tagen von selbst; gehörte Aufträge, die 14 Tage nicht
  neu gehört wurden, fallen heraus.
- **Twinks:** der Auftraggeber ist der eingeloggte Charakter; "Für mich herstellbar" zählt alle eigenen Charaktere
  derselben Gilde (das Rezept kennt der Twink); eine Zeile nennt, welcher ("kann: Ben-Twink").
- **Instanz, Kampfsperre, Schlachtfeld:** wie der Rezept-Austausch: nichts geht in der Sperre oder in einem
  Schlachtfeld; in einer Instanz wartet es bis 5-15 s nach dem Verlassen (D-12, F-035). Kampf hält nichts auf.
- **Zwei Hersteller gleichzeitig:** der Client des Auftraggebers nimmt die erste `OT`, die zweite bekommt den Stand mit
  dem anderen Namen; bei ihm steht "schon angenommen von <Name>".
- **`/reload` und Login:** die eigenen Aufträge sind gespeichert; nach dem Login sagt der Client sie einmal der Gilde.
- **Client auf Englisch:** der Auftrag trägt Rezept- und Item-Nummer, nie den Namen.
- **TBC/Era:** nur wo die Seite Berufe läuft (Forever).

## Missbrauch/Vertrauen

- Nur GUILD und WHISPER, nur Gildenmitglieder nach dem Roster (`ns.TrustName`); der Auftraggeber ist der Absender des
  Servers, nie ein Feld. Ein `OA` ändert nur Aufträge seines Absenders.
- `OT` nimmt nur der Client des Auftraggebers an, nur für einen eigenen offenen Auftrag; der Name des Herstellers ist
  der Absender. Ob er das Rezept wirklich kann, prüft niemand (er könnte lügen, mehr nicht: es geht kein Gold).
- Deckel: 5 offene Aufträge je Auftraggeber, 100 gehörte insgesamt (die ältesten fallen), Notiz 60 Bytes ohne Balken
  und Steuerzeichen, Anzahl 1-20, nur Rezepte, die die eigenen Berufsdaten kennen (sonst verworfen).
- Fluten: Abstand je Absender (siehe Daten); die Chatzeile für Hersteller höchstens einmal je Auftrag und höchstens
  6 je Stunde.
- Die Gildenchat-Ankündigung geht nur vom eigenen Klick aus, nie von einer Nachricht.

## Daten

- **Nachrichtenart `OA`** (order announce), Auftraggeber -> GUILD bei jeder Änderung und einmal nach dem Login
  (20-60 s, low); WHISPER als Antwort auf `OQ` (0-10 s). Felder: Auftrags-ID (4 hex), Revision, Rezept-Spell, Anzahl
  1-20, Material `B`/`H`/`A`, Zustand `O` offen / `T` angenommen / `D` fertig / `X` zu, Hersteller oder `-`, Alter in
  Sekunden, Notiz (60 Bytes) oder `-`. Abstand 2 s je Absender, keyed je Auftrags-ID.
- **`OT`** Hersteller -> Auftraggeber WHISPER: Auftrags-ID, `T` annehmen / `R` abgeben / `D` fertig. Abstand keyed 3 s.
- **`OQ`** jeder -> GUILD einmal 30-60 s nach dem Login (low): 4 hex Nonce; beantwortet nur von Auftraggebern mit
  offenen Aufträgen. Abstand 300 s.
- **`AmisiaDB.orders`** = `{v = 1, own = {[id] = {rev, spell, n, mats, state, by, at, changed, note}}, heard =
  {[sender] = {[id] = {..., seen}}}}`, geprüft beim Laden (Deckel wie oben, 14 Tage).
- **Einstellungen** "Gildenaufträge" (Reiter Gilde): `orders.on` (an), `orders.chat` (Chatzeile für Hersteller, an),
  `orders.login` (an), `orders.announce` (Gildenchat beim Stellen, aus).
- Neue Datei `Amisia/Gear/GuildOrders.lua` (Logik) und der Reiter in `UI/Pages/Professions.lua`. ARCHITECTURE
  (Nachrichtenarten, AmisiaDB, Einstellungen) und eine neue Entscheidung D-162 im selben Commit.

## Offene Fragen

1. **Annehmen nur, wenn der Auftraggeber online ist?** Vorschlag: ja (ein Stand, kein Streit über zwei Annahmen);
   offline nur ansehen.
2. **Wer bekommt die Chatzeile?** Vorschlag: nur wer das Rezept kann (eigene Charaktere), nicht alle.
3. **Gildenchat-Ankündigung** für Mitglieder ohne Amisia: Vorschlag als Schalter, aus als Vorgabe.
4. **Ablauf 14 Tage?** Vorschlag: ja.
5. **Wo der Einstellungsabschnitt steht:** Vorschlag im Reiter Gilde (neben Aufrufe, Warteschlange).

## Entscheidungen

Noch keine.
