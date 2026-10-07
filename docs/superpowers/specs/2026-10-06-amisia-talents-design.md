# Amisia: Talentrechner

Stand 2026-10-06. Vom Nutzer gewählter Vorschlag 2 aus dem Vergleich mit anderen Forever-Addons
(Talentrechner für alle Klassen). Ändert das Addon und die Build-Werkzeuge; keine Versionsnummer,
kein Release.

## Was der Client wirklich hat (geprüft)

- Forever (1.60.1, Interface 16001, Codename Camelot) hat **kein** altes Talentsystem mehr im UI:
  `GetTalentInfo`/`GetTalentTabInfo` fehlen, das Talentfenster ist `Blizzard_PlayerSpells/Camelot`
  auf `C_Traits`. Pro Klasse gibt es **einen** Talentbaum (`TraitTree`, eine Spezialisierung je
  Klasse, `ChrSpecialization` 1482-1491), aufgeteilt in drei Gruppen (`TraitNodeGroup`), die den
  drei klassischen Bäumen entsprechen (`TraitNodeGroupDisplayInfo`: Gruppe, `SkillLine` = Name des
  Baums, Reihenfolge).
- Die Tabellen `Talent`/`TalentTab` stehen noch im Build, enthalten aber die alten Classic-Talente
  (ohne Forevers neue wie Arcane Blast, Missile Barrage, Heating Up) und werden nicht genutzt.
- Knoten: `TraitNode` (PosX/PosY im 600er-Raster: Spalte, Reihe 0-6), `TraitNodeXTraitNodeEntry`
  → `TraitNodeEntry` (MaxRanks) → `TraitDefinition` (SpellID). Werte pro Rang:
  `TraitDefinitionEffectPoints` (EffectIndex, OperationType 0 = Setzen) mit `CurvePoint`
  (Rang → Wert). Pfeile: `TraitEdge` Typ 2/3 (Vorgänger muss voll geskillt sein), Typ 0 nur
  Optik. Reihensperren: `TraitNodeGroupXTraitCond` → `TraitCond` (Typ 0 "Available": X Punkte
  der Währung 3820 in der Zählgruppe, die die Knoten der Reihen darüber enthält: 5, 10, ... 30).
- Punkte: Währung 3820, `SourcedMax` 51, je ein Punkt pro Stufe 10-60 (`TraitCurrencySource`).
  Das Vermächtnis-Perk **Talentiert** (Spell 1225474, 5 Ränge) gibt **keine** zusätzlichen Punkte:
  Rang k gibt die Punkte schon ab Stufe 10-k ("you still may not have more than 51 total talent
  points"). Die Recherche-Notiz "+5 Punkte" ist damit widerlegt. Der Rechner plant also höchstens
  51 Punkte; Stufe und Talentiert-Rang bestimmen nur, wie viele Punkte bei einer Stufe frei sind.
- Ein paar Knoten liegen weit außerhalb des Rasters (z. B. PosY 39300, PosX 102800): alte,
  ersetzte Knoten (Improved Serpent Sting, Lightning Reflexes, Holy Specialization). Sie fallen
  weg.

## Daten

`tools/build_talents.py` liest die Client-Tabellen (CSV im wago.tools-Format, `--wago`, Standard
`~/addons/_wago`, über `att_data.wago_csv`) und schreibt `addon/Amisia/TalentData.lua`
(`ns.TALENTS`, nur `camelot`). Pro Klasse: Baum-ID, die drei Bäume (Gruppe, Name enUS, Symbol),
die Zählgruppen der Reihensperren und die Knoten als kompakte Liste
`{ Knoten, Eintrag, Spell, Symbol, Baum, Reihe, Spalte, MaxRang, Sperre, Vorgänger, Name, Text,
Werte }`. Der Text ist die Beschreibung mit aufgelösten Platzhaltern (`$s1`, `$m1`, `$d`, `$t1`,
`$a1`, `$u`, `$n`, `$h`, `$/1000;S1`, `${...}`, `$l...:...;`, `$?...[..][..]`, Werte anderer
Spells wie `$16191s1`); was pro Rang wechselt, steht als `{1}`, `{2}` im Text und die Werte pro Rang
in `Werte`. Nicht auflösbares bleibt als `?`. Die Tabellen sind enUS.

Im Spiel kommt der deutsche Text aus dem Client, die Daten sind nur Ersatz:
`C_Traits.GetTraitDescription(Eintrag, Rang)` (Text des Rangs), `C_Spell.GetSpellName(Spell)`,
`C_Traits.GetGroupDisplayInfoByTreeID(Baum)` (Baumnamen), `LOCALIZED_CLASS_NAMES_MALE`.

Gebraucht werden: TraitNode, TraitNodeEntry, TraitNodeXTraitNodeEntry, TraitDefinition,
TraitDefinitionEffectPoints, CurvePoint, TraitEdge, TraitNodeGroup, TraitNodeGroupXTraitNode,
TraitNodeGroupXTraitCond, TraitNodeXTraitCond, TraitCond, TraitNodeGroupDisplayInfo,
TraitCurrency, TraitCurrencySource, TraitTreeXTraitCurrency, SkillLineXTraitTree, SkillLine,
SkillRaceClassInfo, ChrClasses, ChrSpecialization und für die Texte Spell, SpellName, SpellMisc,
SpellEffect, SpellDuration, SpellRadius, SpellAuraOptions. `export_db2.ps1` bekommt sie als eigene
Liste (fehlt eine, nur Warnung).

## Rechner (`Talents.lua`, rein rechnend, testbar)

- Plan = Ränge pro Knoten einer Klasse. Punkt setzen geht, wenn: Rang < MaxRang, noch Punkte frei
  (Stufe/Talentiert), Sperre erfüllt (Punkte in der Zählgruppe ≥ Sperre), Vorgänger voll.
- Punkt entfernen geht nur, wenn danach jede geskillte Stelle noch gültig ist (Sperren und
  Vorgänger), wie im klassischen Talentfenster.
- Zurücksetzen pro Baum und alles.
- Punkte bei Stufe L: min(51, Anzahl der Quellen bis L); Mindeststufe eines Plans.
- Eigene Talente live: `C_ClassTalents.GetActiveConfigID()`, `C_Traits.GetNodeInfo(config,
  Knoten).ranksPurchased`, freie/ausgegebene Punkte aus `C_Traits.GetTreeCurrencyInfo`. Ohne API
  oder ohne Talentkonfiguration bleibt der Rechner nutzbar, nur ohne "Im Spiel".
- Teilen als eigener Kurzcode: `AT1.<KLASSE>.<Baum1>.<Baum2>.<Baum3>`, je Baum eine Ziffer pro
  Knoten in Reihen-/Spaltenfolge, Nullen am Ende gekürzt (z. B. `AT1.MAGE.2305.05.`). Import prüft
  Klasse, Länge, Ränge und baut den Plan Reihe für Reihe mit denselben Regeln nach; ein ungültiger
  Code ändert nichts und sagt warum.

## Seite "Talente" (Gruppe Ausrüstung) und `/amisia talente [Code]`

- Kopf: Klassenwahl (eigene Klasse zuerst), Stufe (Stepper 1-60, Standard 60),
  Talentiert-Rang 0-5, "x / y Punkte" und die Mindeststufe.
- Drei Bäume nebeneinander im klassischen Talentfenster-Stil: Kopfleiste mit Baumname, Punkten im
  Baum und Zurücksetzen-Knopf; darunter ein 4×7-Raster mit den Spell-Symbolen, Rang unten rechts
  ("2/5"), Rahmenfarbe: grün = verfügbar, gold = voll, grau = gesperrt (Symbol entsättigt);
  Linien mit Pfeilspitze für Vorgänger (gold, wenn erfüllt); links neben jeder gesperrten Reihe die
  nötigen Punkte.
- Linksklick +1, Rechtsklick -1, Shift-Klick alle/keine Ränge.
- Tooltip: Name, Rang x/y, Text des aktuellen Rangs (oder Rang 1), "Nächster Rang:", fehlende
  Voraussetzungen rot, "Im Spiel: Rang n", wenn abweichend.
- Fuß: Knöpfe "Eigene laden" (nur eigene Klasse, mit Live-Daten), "Alles zurücksetzen" und ein
  Codefeld: zeigt den Code des Plans zum Kopieren; Code einfügen + Enter importiert.
- Pläne pro Klasse bleiben in `AmisiaDB.talents` (Code-Text), dazu Klasse, Stufe, Talentiert.
- Beim ersten Öffnen der eigenen Klasse ohne Plan wird der Live-Stand übernommen.

## Selbsttest

Neue wahlweise Funktionen (`C_Traits.*`, `C_ClassTalents.*`, `C_Spell.GetSpellName`,
`C_Spell.GetSpellTexture`) und ein Abschnitt "Talente": aktive Konfiguration, Baum-ID gegen die
Daten, Knoten der Daten, die der Client kennt, deutscher Text für einen Knoten einer anderen
Klasse (ob `GetTraitDescription` ohne Konfiguration geht), Baumnamen einer anderen Klasse.

## Im Spiel zu prüfen

- Vorgänger-Regel: reicht ein Rang des Vorgängers oder muss er voll sein? (Hier: voll.)
- `GetTraitDescription` und `GetGroupDisplayInfoByTreeID` für fremde Klassen (Selbsttest).
- `ranksPurchased` stimmt mit dem Talentfenster überein.
