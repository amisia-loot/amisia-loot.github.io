# Spec: <Name des Features>

Stand: JJJJ-MM-TT · Status: Entwurf (wird "freigegeben", sobald der Nutzer "passt" sagt) ·
Feature: F-xxx (die nächste freie Nummer in `docs/FEATURES.md`)

Vorlage für `docs/specs/JJJJ-MM-TT-<kurzname>.md`. Jede Überschrift bleibt stehen
(`tools/tests/test_contracts.py` prüft das); gibt es zu einem Punkt nichts, steht dort "Nichts.".
Kurz halten: eine bis zwei Seiten. Deutsch, Namen aus dem Spiel und der Locale wie im Code.

## Ziel

Ein, zwei Sätze: welches Problem der Gilde oder des Spielers das löst, und woran man merkt, dass es
gelöst ist.

## Was es tut

Die sichtbaren Teile: Seiten, Knöpfe, Befehle (`/amisia ...`), Chatmeldungen, Tooltips, Website-Reiter.

## Was es ausdrücklich nicht tut

Was naheliegt, aber nicht dazugehört (und warum), damit es später nicht "nebenbei" hineinwächst.

## Abläufe

Schritt für Schritt aus Sicht des Spielers bzw. Offiziers: wer klickt was, was passiert bei ihm, was
bei den anderen (Raid, Gilde, Website).

## Abnahmekriterien

Jede Zeile "Wenn ..., dann ...", im Spiel (oder auf der Seite) prüfbar. Sie werden nach dem Release
die Prüfungen des Eintrags in `docs/FEATURES.md`. Was eine Gruppe, Gilde oder einen Raid braucht,
mit "(braucht: Gruppe)" usw. markieren.

- Wenn ..., dann ...

## Sonderfälle

Bosskampf (Kampfsperre, geheime Werte), Schlachtfeld, kein Gildenmitglied, Twinks, Nachnamen,
Client auf Englisch, leere Daten, zwei Offiziere gleichzeitig, Login mitten im Raid, `/reload`.

## Missbrauch/Vertrauen

Was andere Gildenmitglieder (oder Fremde) damit anstellen könnten und was dagegen hilft:
gefälschte Absender oder Inhalte (es zählt nur der Absender, den der Server setzt, und sein Rang),
Fluten und zu große Nachrichten (Drossel, Deckel), Aktionen nur für Offiziere, eingefügter Text
von der Website (unvertraut, Feld für Feld prüfen). Siehe DECISIONS D-12, D-18, D-19, D-26.

## Daten

Neue `AmisiaDB`-Schlüssel, Einstellungen, Nachrichtenarten (Präfix, Kanal, Abstand), Blob-Arten,
Exportzeilen, Einfügeblöcke, Website-Zustand. Alles davon kommt im selben Commit in
`docs/ARCHITECTURE.md` (die geprüften Tabellen) und, wenn es eine Regel ist, in `docs/DECISIONS.md`.

## Offene Fragen

Was der Nutzer entscheiden muss, als nummerierte Fragen mit Vorschlag.

1. ...

## Entscheidungen

Was der Nutzer gewählt hat, mit Datum und seinen Worten, z. B.:

- JJJJ-MM-TT: Frage 1: "..." -> ...
