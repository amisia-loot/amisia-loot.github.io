# Amisia: Berufe-Seite (Rezepte, Händlergunst, Lager)

Stand 2026-10-06. Nur WoW Forever 1.60.1 (TOC 16001, Client-Tabellen 1.60.1.70235, Spielcode-Kopie
1.60.1.70205). Keine Versionsänderung in diesem Schritt; die Version setzt der Release.

## Ziel

Der Nutzer wählte am 2026-10-06 die Berufe-Seite (Vorschlag 3 aus dem Vergleich): im Hauptfenster
eine Seite "Berufe" im Stil des Forever-Berufsfensters, mit allen Rezepten je Beruf, ihren
Quellen und Forevers neuen Berufssystemen (Händlergunst, Lager). Befehl `/amisia berufe [Beruf]`.

## Rahmen

- UI deutsch, Kommentare englisch, keine fremden Addons oder Fan-Seiten nennen oder verlinken.
- Daten nur aus den Client-Tabellen (eigener Export, `tools/export_db2.ps1`), den Forever-Daten von
  AllTheThings (MIT, Lizenztext liegt schon in `addon/Amisia/LICENSES/`), dem eigenen Quellen-Sammler
  (`Collector.lua`) und öffentlichen Fakten. Nichts aus anderen Addons.
- **Namen kommen deutsch aus dem Client**, nicht aus den Daten: Rezeptname `C_Spell.GetSpellName`
  (Zauber liegen lokal im Client, sofort da), Items `C_Item.GetItemInfo` (asynchron, wie auf der
  Karte: "Item 1234" bis `GET_ITEM_INFO_RECEIVED`), Zonen `C_Map.GetMapInfo`. Die Datei trägt nur
  Zahlen, plus englische NPC- und Questnamen aus AllTheThings (der Client kennt NPC-Namen nicht ohne
  Begegnung).

## Daten: `tools/build_professions.py` -> `addon/Amisia/ProfessionData.lua`

### Eingaben

| Quelle | Wofür | Heute vorhanden |
|---|---|---|
| `SkillLineAbility` | welches Rezept (Zauber) zu welchem Beruf gehört; Gelb-/Grau-Schwelle (`TrivialSkillLineRankLow/High`), `MinSkillLineRank`, `AcquireMethod` (1 = mit dem Beruf gelernt) | nur die Kopie in AllTheThings (`.config/.wago/SkillLineAbility.1.60.1.70170.csv`); ein eigener Export in `~/addons/_wago` hat Vorrang |
| `SpellEffect` | hergestelltes Item und Anzahl (Effekt 24), Verzauberung (Effekt 53), Platzier-Zauber der Lagerobjekte (Effekt 50/28 + Beschreibung) | ja |
| `ItemSparse` | Rezept-Items: nötiger Beruf und Rang (`RequiredSkill(Rank)`), Ruf (`MinFactionID`, `MinReputation`); Lagerobjekte; Zertifizierungen; Handwerksaufträge ("Craftsman's Writ: X") | ja |
| `ItemXItemEffect`, `ItemEffect` | Rezept-Item -> Rezept (Auslöser 6 "beim Lernen"), Lagerobjekt-Item -> Platzier-Zauber | ja |
| `SpellName`, `Spell` | nur im Build: Lagerobjekte erkennen ("Requires a Campfire nearby"), "May be placed over X" auflösen, Auftrag -> Item über den englischen Namen | ja |
| `SpellReagents` | Reagenzien und Anzahl je Rezept | **nein**: ohne sie liest die Seite die Reagenzien zur Laufzeit (`C_TradeSkillUI.GetRecipeSchematic`) |
| AllTheThings `.config/structures/*.lua` | Lehrer-Rezepte je Stufe (Lehrling bis Fachmann), Händlergunst-Rezepte mit Preis und Rufstufe je Fraktion | ja (Alchimie, Schmiedekunst, Verzauberkunst; Rest folgt dort) |
| AllTheThings `profession db/*.lua` | Rezept-Item -> Rezept (Gegenprobe) | teils |
| AllTheThings Zonen/Dungeons (`att_data.load`) | Händler, Drops, Quests der Rezept-Items; Händlergunst-Händler je Fraktion | ja |

Rezepte aus der Season-of-Discovery-Nummernreihe (Zauber 400000-999999), die AllTheThings für
Forever nicht führt, fallen weg (Runen-Gravuren, SoD-Phasen-Rezepte).

### Vom Nutzer zu exportieren (PC)

```
powershell -ExecutionPolicy Bypass -File tools\export_db2.ps1 -Tables SkillLineAbility,SpellReagents,SkillLine
```

`SkillLineAbility` (aktueller Build statt 70170), `SpellReagents` (Reagenzien ohne Client-Abfrage,
auch für die Seite der Gilde später), `SkillLine` (nur zur Kontrolle der Berufsnummern). Alle drei
sind in `export_db2.ps1` als optional eingetragen. Ohne sie läuft der Build mit dem, was da ist.

### Format (kompakt, Zeichenketten statt Tabellen)

```
ns.PROFESSIONS = {
  built, source, client,
  P = { { 164, "blacksmithing" }, ... },     -- Berufe in Anzeigereihenfolge
  R = { [164] = { "spell:item:count:learn:yellow:grey:src", ... } },
  I = { [recipeItem] = "spell:skillRank:faction:standing:quelle,quelle" },
  G = { [spell] = "item:n,item:n" },           -- nur mit SpellReagents
  N = { [npc] = "Name|uiMapID|A/H/" },         -- englisch, aus AllTheThings
  Q = { [quest] = "Name" },
  CAMP = { "item:skillLine:rank:useSpell:recipeSpell:slots:overItem", ... },
  FAVOR = { currency = 3402, cert = { [skillLine] = item }, writ = { [item] = writItem },
            vendor = { A = { npc, ... }, H = { npc, ... } } },
}
```

`src` eines Rezepts: `T1`-`T4` Lehrer der Stufe (Lehrling, Geselle, Experte, Fachmann), `T0`
Lehrer ohne Stufe, `A` mit dem Beruf gelernt, `I<item>` Rezept-Item (mehrere möglich). Quellen
eines Rezept-Items: `V<npc>` Händler, `F<preis>@<rufstufe><A|H>` Händlergunst, `D<npc>` Drop,
`Z<uiMapID>` Zonendrop, `W` Weltdrop, `Q<quest>` Questbelohnung. `learn` ist der Rang, ab dem das
Rezept lernbar ist (`RequiredSkillRank` des Rezept-Items, sonst `MinSkillLineRank`).

## Laufzeit: `Professions.lua`

- **Farben** wie der Client (Classic-Formel): unter `yellow` orange, unter `(yellow+grey)/2` gelb,
  unter `grey` grün, sonst grau; ein unbekanntes Rezept über dem eigenen Rang rot ("ab 125").
- **Eigene Berufe zuerst:** `GetProfessions()` + `GetProfessionInfo(i)` (7. Wert: Berufsnummer,
  3./4. Rang und Maximum; beides im Forever-Spielcode, `Blizzard_ProfessionsBook`). Kochen, Erste
  Hilfe und Angeln folgen, dann der Rest.
- **Bekannt:** ist das eigene Berufsfenster offen (`TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`,
  nicht `IsTradeSkillLinked`/`IsTradeSkillGuild`/`IsNPCCrafting`), liest Amisia
  `C_TradeSkillUI.GetAllRecipeIDs()` (sonst `GetFilteredRecipeIDs()`) und je Rezept
  `GetRecipeInfo(id).learned`, dazu `GetBaseProfessionInfo()` (Rang). `NEW_RECIPE_LEARNED` trägt
  nach. Gespeichert je Charakter in `AmisiaDB.prof.chars[name] = { [skillLine] = { rank, max, day,
  known = { [spell] = true } } }`. Ohne Stand sagt die Seite "Berufsfenster einmal öffnen".
- **Reagenzien:** aus `G`, sonst `C_TradeSkillUI.GetRecipeSchematic(spell, false)` (Mengen aus
  `reagentSlotSchematics[].quantityRequired`, Item aus `reagents[1].itemID`), zwischengespeichert;
  dazu die eigene Menge (`C_Item.GetItemCount`, mit Bank).
- **Quellen:** aus den Daten; dazu eigene Beobachtungen des Sammlers: Händler, die das Rezept-Item
  verkaufen (`AmisiaDB.collect.s`, mit Preis und Rufstufe), und NPCs, von denen es fiel
  (`collect.w`). Ein Index Item -> Beobachtungen, neu gebaut, wenn `ns.CollectGen()` sich ändert.
- **Upgrade-Marke:** für tragbare Ergebnisse (`C_Item.GetItemInfoInstant` -> equipLoc)
  `ns.UpgradeShort(ns.UpgradeOf(item))`, wie auf den anderen Seiten.

## Seite `Pages/Professions.lua` (Gruppe "Ausrüstung", nach "Karte")

- Kopf: Berufswahl (`W.Picker`: eigene Berufe mit Rang, dann alle; dazu die Einträge "Lager" und
  "Händlergunst"), Suchfeld (`W.SearchBox`, sucht deutschen Rezeptnamen und Ergebnis-Item), Chips
  "Bekannt", "Unbekannt", "Lernbar" (Rang reicht) und eine Wahl der Quelle (Alle, Lehrer, Händler,
  Händlergunst, Drop, Quest).
- Links die Rezeptliste (`W.List`) in Farben nach Schwierigkeit, rechts der Rang und die
  Upgrade-Marke; rechts daneben das Detail (`W.Inset`): Ergebnis mit Qualität, Fertigkeit
  "1 / 20 / 40 / 60" in den vier Farben, Reagenzien mit eigener Menge, Quellen, bekannt ja/nein,
  Händlergunst-Preis, "Handwerksauftrag möglich".
- **Lager:** alle Lagerobjekte je Beruf (Lagerfeuer mit Platzzahl, Objekte ab Rang 20/140/300),
  welches Objekt welches ersetzt, die Beschreibung des Platzier-Zaubers deutsch aus dem Client
  (`C_Spell.GetSpellDescription`; enthält den Buff und seine Werte), die Blaupause als Quelle.
- **Händlergunst:** eigener Stand der Währung 3402 (`C_CurrencyInfo.GetCurrencyInfo`), die Händler
  der eigenen Fraktion, alle Gunst-Rezepte mit Preis und Rufstufe, die Zertifizierungen (1000 Gunst,
  Rang 300, Titel für das Konto) und wie viele Handwerksaufträge es je Beruf gibt.

## Neue Berufssysteme: was die Daten tragen

- **Händlergunst** (Währung 3402, Fraktionen 2586 Azeroth Commerce Authority / 2587 Durotar Supply
  and Logistics): Rezepte mit Preis und Rufstufe, Zertifizierungen, Händler, Handwerksaufträge
  ("Craftsman's Writ: X", 104 Items, versiegelt in vier Stufen) und die Rufzauber der Lieferungen
  stehen in den Daten. **Nicht in den Daten:** wie viel Gunst eine Kiste oder ein Auftrag bringt
  (Server; öffentlich genannt sind 5 je Kiste, unbestätigt) und was in einer Kiste verlangt wird.
  Das zeigt die Seite nicht; der Sammler könnte es später beim Abgeben lernen.
- **Lager** (Camping): Lagerfeuer (Basic/Journeyman/Expert, 3/5/10 Plätze), je Beruf ein
  Grundobjekt (Rang 20, z. B. Schleifrad: Stärke), ein Objekt ab 140 und eins ab 300, das das
  Grundobjekt ersetzt und dessen Buff behält, plus Rezept-Stationen (Meisterschmiede, Webstuhl ...).
  Die Werte der Buffs hängen am Level (`$?$PL<24[6]...`); der Client löst das in der deutschen
  Beschreibung selbst auf, deshalb kommt sie aus dem Client. Gemeinsame Abklingzeit aller Objekte.
- **Gildenhandwerker** (wer kann es herstellen): die Seite der Gilde führt Handwerker nur fürs
  TBC-Archiv, das Addon tauscht keine Rezeptlisten. **Folgeaufgabe**: die bekannten Rezepte über
  den Gilden-Austausch teilen (wie der Sammler), dann hier "Kann: Name, Name".

## Selbsttest

Abschnitt "Berufe": die Funktionen (`GetProfessions`, `GetProfessionInfo`,
`C_TradeSkillUI.GetRecipeSchematic`, `GetRecipeInfo`, `GetAllRecipeIDs`, `GetFilteredRecipeIDs`,
`GetBaseProfessionInfo`, `IsTradeSkillLinked`, `IsTradeSkillGuild`, `IsNPCCrafting`,
`C_Spell.GetSpellName`, `C_Spell.GetSpellDescription`, `C_CurrencyInfo.GetCurrencyInfo`,
`IsPlayerSpell`), die Ereignisse, die eigenen Berufe mit Nummer und Rang, die Reagenzien eines
Lehrer-Rezepts (Kupferarmschienen 2663) ohne offenes Fenster, die Händlergunst, ob `IsPlayerSpell`
ein bekanntes Rezept erkennt, und ob die Berufsnummern der Daten zum Client passen.

## Tests

- `tools/tests/test_build_professions.py` mit Fixture-CSVs und einem AllTheThings-Fixture:
  Rezepte, Farben-Schwellen, Rezept-Items und Quellen, SoD-Filter, Lager, Händlergunst, Reagenzien
  mit und ohne `SpellReagents`, gültiges und deterministisches Lua, TOC.
- Addon (lupa): `test_professions.lua` (Daten lesen, Farben, Bekannt aus dem Berufsfenster, eigene
  Berufe zuerst, Reagenzien aus der Abfrage, Quellen mit Sammler, Suche und Filter),
  `test_professions_page.lua` (Seite, Detail, Lager, Händlergunst, Layout, Befehl),
  `test_professions_noapi.lua` (ohne `C_TradeSkillUI` und `GetProfessions`: keine Fehler).
