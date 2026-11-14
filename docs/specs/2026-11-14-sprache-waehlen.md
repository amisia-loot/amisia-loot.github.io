# Spec: Sprache wählen (Deutsch oder Englisch, Standard: Clientsprache)

Stand: 2026-11-14 · Status: freigegeben ·
Feature: F-199

## Ziel

Amisia ist schon ganz zweisprachig, aber die Sprache entscheidet heute allein der Client (D-08: deDE
Deutsch, alles andere Englisch). Der Spieler soll Deutsch oder Englisch selbst wählen können. Ohne
Wahl bleibt es wie heute: die Sprache des Clients.

## Was es tut

- Einstellungen, Allgemein, Oberfläche: eine Auswahl "Sprache" mit "Wie der Client (Deutsch)" bzw.
  "Like the client (English)", "Deutsch", "English". Die Einträge "Deutsch" und "English" stehen immer
  in ihrer eigenen Sprache, damit man sie auch in der falschen Sprache findet.
- Nach einer Wahl fragt Amisia "Die Sprache wechselt nach dem Neuladen. Jetzt neu laden?" mit
  "Neu laden" (`ReloadUI`) und "Später".
- `/amisia sprache de`, `/amisia sprache en`, `/amisia sprache auto` (englisch auch `/amisia language ...`)
  setzen dasselbe und sagen im Chat, dass es nach `/reload` gilt.
- Alles, was Amisia selbst schreibt, folgt der Wahl: Seiten, Fenster, Tooltips, Chatmeldungen, Zahlen
  ("2,5" oder "2.5") und Daten ("07.10." oder "Oct 7"). Auch die Ansagen an Raid und Gilde gehen in der
  gewählten Sprache (wie heute in der Sprache des eigenen Clients).

## Was es ausdrücklich nicht tut

- Keine weiteren Sprachen (Französisch usw.): es gibt nur Deutsch und Englisch.
- Namen aus dem Spiel (Gegenstände, Zonen, Bosse, Quests, Klassen) liefert der Client in seiner Sprache;
  die bleiben so. Amisia übersetzt keine Spieldaten.
- Kein Wechsel ohne Neuladen (siehe "Abläufe": die Texte stehen beim Laden fest).
- Nachrichten zwischen Addons, Export, gespeicherte Schlüssel bleiben sprachfrei (D-08).

## Abläufe

1. Der Spieler wählt "English" in den Einstellungen; Amisia speichert `ui.language = "enUS"` und fragt
   nach dem Neuladen.
2. Nach "Neu laden" liest Amisia beim Laden zuerst die Wahl und baut erst dann seine Seiten, Fenster und
   Texte, alles auf Englisch.
3. "Wie der Client" nimmt wieder die Sprache des Clients.

Technisch (Frage 1): WoW lädt die gespeicherten Daten eines Addons erst, nachdem alle seine Dateien
gelaufen sind, und rund 1.700 Texte in 110 Dateien werden schon beim Laden übersetzt (Namen von Seiten,
Einstellungen, Tabellen). Vorschlag A: `Locales/Locale.lua` lädt wie heute zuerst; jede andere Datei legt
ihren Inhalt in `ns.Load(function() ... end)`, und Locale.lua führt diese Inhalte in derselben Reihenfolge
bei `ADDON_LOADED` von Amisia aus, nachdem es `AmisiaDB.settings.ui.language` gelesen hat. Das geschieht
im selben Ladebildschirm, vor `PLAYER_LOGIN`; ein Fehler in einer Datei hält wie heute nur diese Datei
an. Ein Test prüft, dass jede Datei der TOCs so beginnt und endet.

## Abnahmekriterien

- Wenn du auf einem deutschen Client in den Einstellungen "English" wählst und "Neu laden" klickst, dann
  ist Amisia ganz auf Englisch: Seitenleiste, Seiten, Einstellungen, Tooltips, Chatmeldungen, Datumsangaben.
- Wenn du danach `/amisia sprache auto` eingibst und `/reload` machst, dann ist alles wieder Deutsch.
- Wenn du die Sprache nie gewählt hast, dann ist Amisia so wie bisher in der Sprache des Clients.
- Wenn du nach dem Wechsel einloggst, `/reload` machst oder in einen Raid kommst, dann gibt es keine
  Lua-Fehler, und Minimap-Symbol, Addon-Menü und Tastenbelegungen funktionieren wie vorher.

## Sonderfälle

- Englischer Client, Wahl "Deutsch": dasselbe umgekehrt; Spieldaten bleiben englisch.
- Eine kaputte oder unbekannte Wahl im Spielstand zählt als "Wie der Client".
- `/reload` im Kampf: das Laden läuft wie heute vor dem Spiel weiter; nichts Geschütztes ändert sich.
- Gespeicherte Daten in Texten (z. B. Vorlagen der Raid-Notiz, eigene Notizen) bleiben, wie sie sind.
- Ein anderes Addon oder die Tests, die vor `ADDON_LOADED` auf Amisia zugreifen: nur die Locale-Datei
  ist dann geladen (die Tests feuern `ADDON_LOADED` wie der Client).

## Missbrauch/Vertrauen

Nichts. Die Wahl ist nur lokal, nichts wird gesendet.

## Daten

- Neuer Einstellungsschlüssel `ui.language` ("auto" Standard, "deDE", "enUS") in AmisiaDB.settings, im
  Abschnitt Oberfläche; Zeile in `docs/ARCHITECTURE.md`.
- DECISIONS: D-08 wird ergänzt ("die Client-Sprache entscheidet, außer der Spieler wählt") und eine neue
  Entscheidung D-128 zum Laden über `ns.Load`.
- Keine neue Nachricht, kein Export.

## Offene Fragen

1. Weg beim Laden: A (Vorschlag) jede Datei in `ns.Load(...)`, Inhalt läuft bei `ADDON_LOADED`; B ein
   zweites kleines Addon "Amisia_Sprache", das vor Amisia lädt und nur die Wahl speichert (ein zweiter
   Ordner im Release und auf CurseForge, am PC einmal eine neue Verknüpfung); C alle 1.700 Stellen
   einzeln auf "erst bei Gebrauch übersetzen" umbauen (sehr viel Umbau, leicht etwas zu übersehen).
2. Den Befehl `/amisia sprache de|en|auto` zusätzlich zur Einstellung? Vorschlag: ja, falls man sich
   in der falschen Sprache nicht zurechtfindet.

## Entscheidungen

- 2026-11-14: Frage 1: "A: Dateien warten" -> jede Datei in `ns.Load(...)`, Inhalt läuft bei `ADDON_LOADED`.
- 2026-11-14: Frage 2: "Ja" -> `/amisia sprache de|en|auto` zusätzlich zur Einstellung.
- 2026-11-14: Spec: "Passt, bauen".
