# Specs

Eine Spec ist ein kurzer Entwurf (eine bis zwei Seiten) eines größeren Features, bevor es gebaut wird.
Sie hält fest, was der Nutzer will, was ausdrücklich nicht, wie man es im Spiel abnimmt und was
andere Spieler damit anstellen könnten. Grund: DECISIONS D-35. Die älteren Entwürfe bis 2026-10-08
liegen unter `docs/superpowers/specs` und bleiben, wie sie sind.

## Wann eine Spec nötig ist

Eine Spec braucht jedes neue Feature, das mindestens eines davon bringt:

- eine neue Addon-Nachricht (Nachrichtenart, Blob-Art) oder eine neue Art Austausch mit anderen Spielern;
- einen neuen gespeicherten Schlüssel in `AmisiaDB` oder einen neuen Einstellungsabschnitt;
- eine neue Exportzeile, einen neuen Einfügeblock oder neuen Zustand der Website;
- eine neue Seite im Addon oder einen neuen Reiter auf der Website;
- alles, was andere Spieler betrifft oder ihnen etwas erlaubt: Vergaben, Punkte (Größe wie DKP/EPGP),
  Raid-Abgleich, Chat-Antworten, Offiziersaktionen.

Keine Spec brauchen: Fehlerbehebungen, Aussehen und Layout, Texte, neue Daten aus den bekannten
Quellen, ein neuer BiS-Pick, kleine Erweiterungen eines bestehenden Features ohne neue Daten oder
Nachrichten. Im Zweifel: fragen, ob eine kurze Spec gewünscht ist.

## Ablauf

1. **Spec schreiben:** `docs/specs/JJJJ-MM-TT-<kurzname>.md` aus [TEMPLATE.md](TEMPLATE.md), alle
   Überschriften behalten; offene Fragen mit Vorschlag. Committen.
2. **Nutzer sagt "passt":** die Antworten unter "Entscheidungen" mit Datum eintragen, Status
   "freigegeben", in `docs/FEATURES.md` einen Eintrag mit `Status: geplant` und `Version: -` anlegen.
   Ohne "passt" wird nicht gebaut.
3. **Bauen:** nach der Spec; ändert sich unterwegs etwas Wesentliches, erst die Spec ändern und kurz
   nachfragen. Neue Nachrichten, Schlüssel, Zeilen in `docs/ARCHITECTURE.md`, neue Regeln in
   `docs/DECISIONS.md` (gleicher Commit).
4. **Review:** Review gegen die Spec (vor allem "Missbrauch/Vertrauen" und "Sonderfälle"), Funde beheben,
   `python3 tools/build.py check` grün.
5. **Release:** vorher im FEATURES-Eintrag `Version: X.Y.Z` und `Status: gebaut` setzen, die
   Prüfungen aus den Abnahmekriterien übernehmen (höchstens fünf, die wichtigsten zuerst). Dann
   `python3 tools/build.py release X.Y.Z -m "..."`; die Testliste am Ende an den Nutzer weitergeben.
6. **Ergebnis:** meldet der Nutzer, dass es im Spiel klappt: `python3 tools/build.py tested F-xxx`
   (im echten Raid: `--raid`) und committen.
