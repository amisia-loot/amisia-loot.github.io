# Amisia 2.2: Fenster im Forever-Stil

Stand 2026-10-05. Kein neuer Baustein, sondern ein Umbau der Oberfläche nach Baustein 7 (Sync, 2.1).
Baut auf Baustein 1 (`docs/superpowers/specs/2026-10-04-amisia-main-window-design.md`: Registry,
Widgets, Hauptfenster, Seiten) und auf 2.1 (`W.ArrowButton` mit dem Dropdown-Knopf des Clients) auf.
Ändert nur das Addon `addon/Amisia` und seine Tests (`addon/tests`). Export, Website, Twin und
Supabase ändern sich nicht (kein Neubau des Twins, `BUILD_ID` bleibt).

Wort-Hinweis: "Berufsfenster" heißt in diesem Entwurf das Berufsfenster von WoW Forever (deutscher
Client, etwa "Lederverarbeitung"), wie es der Nutzer am 2026-10-05 als Bildschirmfoto geschickt hat.
"Vorlage" ist ein virtuelles Template des Clients, das `CreateFrame` erbt. "Atlas" ist ein
benannter Ausschnitt einer Client-Textur (`texture:SetAtlas`). "Einsatz" (Inset) ist ein
eingelassenes Feld mit abgeschrägtem Rand. Quelle aller Namen: der Forever-Client 1.60.1.70205
(`src_forever` im Scratchpad, entspricht Gethe/wow-ui-source Zweig `forever`), geprüft am 2026-10-05.

## Ziel

Der Nutzer will, dass das ganze Amisia-Fenster aussieht wie das Berufsfenster von Forever:

- ein rundes Porträt, das oben links über die Ecke ragt;
- goldener Titel mittig auf einer dunklen Titelleiste, rechts ein roter quadratischer
  Schließen-Knopf mit goldenem X;
- dunkler, strukturierter Hintergrund;
- oben eine Statusleiste (im Berufsfenster: Fertigkeitsbalken "Lederverarbeitung 46/75" mit kleinem
  Knopf);
- links eine Liste mit gold-auf-dunkelbraunen Abschnittsbalken (fette goldene Schrift, rechts ein
  "-" zum Einklappen) und eingerückten weißen Einträgen; der gewählte Eintrag mit einem goldenen
  Leuchtbalken; eine dünne goldene Bildlaufleiste;
- ein Suchfeld mit Lupe und dem Platzhalter "Suchen", ein Knopf "Filter" mit goldenem Pfeil;
- rechts ein eingelassenes Feld mit abgeschrägtem Rand für die Einzelheiten;
- unten rote, abgeschrägte Aktionsknöpfe ("Alle erstellen", "Erstellen") und ein kleines Zahlenfeld
  mit Pfeilknöpfen;
- am rechten Rand außerhalb des Rahmens senkrechte Reiter mit Symbolen (die Berufsknöpfe).

Schon in 2.1 umgesetzt: Dropdowns und Pfeile nutzen den Dropdown-Knopf des Clients
(`W.ArrowButton`, Atlas `common-dropdown-a-button`). 2.2 zieht den Rest nach.

**Nur die Optik ändert sich.** Jede Funktion, jeder Befehl, jede gespeicherte Einstellung und jeder
Text bleibt, mit drei kleinen, begründeten Ausnahmen (siehe "Rahmen und Entscheidungen"): die
Abschnitte der Seitenliste lassen sich einklappen, drei Reiter am rechten Rand öffnen die
Nebenfenster, und der Schließen-Knopf schließt die Fenster jetzt auch im Kampf.

## Rahmen und Entscheidungen

- **Clients, Bibliotheken, Schrift:** nur Forever (TOC 16001, Spieltyp `camelot`). Keine fremden
  Bibliotheken, kein `UIDropDownMenu`/`EasyMenu`, auch nicht das neue Menüsystem des Clients
  (`MenuUtil`, `DropdownButton`): `W.Menu` und `W.Picker` bleiben eigene Frames, nur ihr Aussehen
  übernimmt die Atlanten des Client-Menüs. UI- und Chat-Texte deutsch und nur Latin-1 (ä ö ü ß und
  "·", kein Gedankenstrich, keine Auslassungspunkte, keine Pfeile), Code-Kommentare englisch. Keine
  anderen Addons nennen, weder in Texten, Chat, Kommentaren noch Commits.
- **Vorlagen des Clients erben statt nachbauen.** Wo der Client eine allgemeine Vorlage hat
  (`Blizzard_SharedXML`, `Blizzard_Menu`, beide immer geladen), erbt Amisia sie in `CreateFrame`.
  Damit stimmt das Aussehen genau und folgt künftigen Patches. Forever lädt die `Mainline`-Dateien
  dieser Vorlagen (`[Family]`) plus eigene `Camelot`-Anpassungen
  (`Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua`, `Camelot/SharedUIPanelTemplates.lua`):
  wer `PortraitFrameTemplate` erbt, bekommt also den Forever-Rahmen, nicht den des Hauptspiels.
- **Keine Vorlagen aus den Berufs-Addons.** `ProfessionsRecipeListCategoryTemplate`,
  `ProfessionsRankBarTemplate`, `ProfessionsGearSlotTemplate` und `SchematicFormCraftingTemplate`
  liegen in `Blizzard_Professions`/`Blizzard_ProfessionsTemplates` (`LoadOnDemand`, mit Mixins, die
  `C_TradeSkillUI` und PaperDoll-Funktionen aufrufen). Amisia lädt diese Addons nicht. Gebraucht
  werden nur ihre **Atlanten** (Client-Daten, unabhängig vom geladenen Addon) und die **allgemeinen
  Vorlagen**, auf denen sie aufbauen (`ListHeaderVisualTemplate`, `SharedButtonSmallTemplate`,
  `MinimalScrollBar`, `SearchBoxTemplate`).
- **Inhaltsfläche bleibt 602 x 478.** Das Fenster wächst von 800 x 540 auf **806 x 560**, damit die
  Seiten ihre Fläche behalten. Die Seiten ändern ihre Anordnung dadurch kaum; die Layout-Tests der
  Seiten (`layout.lua` mit `602, 478`) bleiben gültig. Geometrie unten.
- **Seitenliste links mit Abschnitten, nicht Reiter rechts.** Amisia hat 13 Seiten, ein Offizier
  sieht 12, mit Expertensicht 13. Die Reiter des Berufsfensters (`LargeSideTabButtonTemplate`, Höhe
  aus dem Atlas `common-sidetab`, im Berufsfenster acht Stück untereinander ab y = -60) passen bei
  560 px Höhe nicht für zwölf oder dreizehn Seiten und hätten keine Beschriftung. Die Liste links
  entspricht dagegen genau der Rezeptliste: Abschnittsbalken, eingerückte Einträge, gewählter Eintrag
  mit Leuchtbalken; jede Seite bleibt mit einem Klick erreichbar, wie heute. Abschnitte:

  | Abschnitt | Seiten (Reihenfolge wie heute nach `order`) |
  |---|---|
  | Raid | Übersicht, Raids, Raid-Log, Rolls, Vergaben, Soft-Reserves |
  | Ausrüstung | Ausrüstung, Karte |
  | Gilde | Export, Gildenbank, Werkzeuge |
  | Amisia | Einstellungen, Über und Befehle |

  Ein Abschnitt ohne sichtbare Seite fehlt (ein Raider sieht "Gilde" nicht). Die Abschnitte lassen
  sich einklappen (der "-" rechts, Klick auf den Balken); der Zustand steht in
  `AmisiaDB.settings.window.collapsed`. Die gerade gezeigte Seite bleibt beim Einklappen offen.
- **Reiter rechts für die Nebenfenster.** Die senkrechten Reiter gehören zum Bild, das der Nutzer
  will. Sie öffnen und schließen, was heute über Knöpfe auf den Seiten und im Schnellmenü erreichbar
  ist: "Ausrüstungstabelle" (`ns.ToggleGearFrame`, nur mit Ausrüstungsdaten), "Rolls"
  (`ns.ToggleRollFrame`, nur Offiziersicht), "Soft-Reserve-Import" (`ns.ToggleSoftResFrame`, nur
  Offiziersicht, wie der Import-Knopf der Seite). Der Reiter eines offenen Fensters ist markiert.
  Keine neue Funktion, nur ein weiterer Weg.
- **Schließen auch im Kampf.** `UIPanelCloseButton` ruft `HideUIPanel(parent)`; das prüft zuerst
  `CheckProtectedFunctionsAllowed()` (`Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`
  Zeile 854 und 920) und bricht im Kampf bei unsicherem Aufrufer ab ("Aktion blockiert"). Ein Knopf,
  den ein Addon anlegt, ist immer unsicher. Heute schließt das X der Amisia-Fenster im Kampf also
  nicht (Escape geht, weil `CloseSpecialWindows` direkt `Hide` ruft). 2.2 setzt auf jedem
  Schließen-Knopf `OnClick` auf `self:GetParent():Hide()`. Kein Amisia-Fenster kommt in
  `UIPanelWindows` (dann bräuchte es `ShowUIPanel`, das im Kampf ebenso gesperrt ist).
- **Eine Fensterfabrik `W.Window`.** Alle fünf Fenster (Hauptfenster, Ausrüstungstabelle,
  Roll-Fenster, Vergabe-Dialog, Soft-Reserve-Import) entstehen über eine Funktion in Widgets.lua:
  Vorlage, Titel, Porträt oder nicht, Hintergrund, Schließen-Fix, Ziehen, `SetClampedToScreen`,
  `UISpecialFrames`, Schicht. Scheitert das Erben (Vorlage fehlt nach einem Patch: `CreateFrame`
  wirft einen Fehler), baut sie über `pcall` das heutige flache Fenster (dunkel, goldener Rand,
  eigener Schließen-Knopf). `W.Flat` und `W.Border` bleiben dafür.
- **Ausrüstungstabelle mit Porträt, Dialoge ohne.** Die Ausrüstungstabelle ist ein großes Fenster wie
  das Hauptfenster und trägt das Amisia-Porträt. Roll-Fenster, Vergabe-Dialog und
  Soft-Reserve-Import sind kleine Dialoge: Rahmen ohne Porträt (Layout
  `ButtonFrameTemplateNoPortrait`), Titel mittig.
- **Keine Item-Knöpfe des Clients in 2.2.** `ItemButton` (intrinsisch,
  `Blizzard_ItemButton/Shared/ItemButtonTemplate.xml`) ist 37 px groß und bringt Zähler, Suche und
  Kontext-Overlays mit. Amisias Item-Symbole sitzen in Zeilen von 18 bis 26 px; ein Umbau auf 37 px
  verschiebt jede Seite. Die Symbole bleiben Texturen. Siehe "Später".
- **Zahlenfeld: eigener Aufbau statt `NumericInputSpinnerTemplate`.** Die Vorlage des Clients
  (`InputBoxTemplates.xml` Zeile 273) erlaubt nur drei Ziffern (`letters="3"`) und Schritte von 1;
  Amisias Regler haben Schritte von 5 und 10 und Höchstwerte bis 1000 (`tools.scanRate`). `W.Stepper`
  bekommt das Aussehen des Berufsfensters (Feld mit Eingaberand, Pfeilknöpfe links und rechts) aus
  `InputBoxTemplate`-Atlanten und zwei `W.ArrowButton`, behält aber seine Logik.
- **Rote Knöpfe überall.** `W.Button` erbt `SharedButtonSmallTemplate` (Atlas `128-RedButton`), genau
  die Vorlage, die das Berufsfenster für "Erstellen" und "Alle erstellen" nimmt
  (`Blizzard_Professions/Camelot/Blizzard_ProfessionsCrafting.lua`, `GetButtonTemplate`). Bisher
  erbte `W.Button` `UIPanelButtonTemplate` (Dateitexturen `UI-Panel-Button-*`). Alle direkten
  `UIPanelButtonTemplate`-Knöpfe in RollFrame.lua und SoftRes.lua werden `W.Button`.
- **Version 2.2.0** (TOC `## Version`, `ns.VERSION` in Core.lua).

## Vorlagen und Atlanten des Clients

### Wie das Berufsfenster gebaut ist

`ProfessionsFrame` (`Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.xml`) erbt
`ProfessionsFrameBase` = `PortraitFrameTemplate, TabSystemOwnerTemplate`, Größe 673 x 594 (Forever
überschreibt die Breite mit `professionsFrameWidthOverride = 750`). `ProfessionsMixin:OverrideArt`
setzt den Hintergrund `Bg` auf den Atlas `Profession-Background-Overview` und blendet
`TopTileStreaks` aus. Die Berufsknöpfe rechts sind `LargeSideTabButtonTemplate`, angeheftet an
`TOPRIGHT` des Fensters, y = -60, Abstand 2. Die Rezeptliste (`ProfessionsRecipeListTemplate`,
x = 5, y = -72, 304 breit) hat den Hintergrund-Atlas `Professions-background-summarylist`, ein
`SearchBoxTemplate`, einen `WowStyle1FilterDropdownTemplate`-Knopf und eine `MinimalScrollBar`;
Abschnittsbalken sind `ListHeaderVisualTemplate` (25 hoch), gewählte Einträge zeigen
`Professions_Recipe_Active`, überfahrene `Professions_Recipe_Hover` (Alpha 0.5). Das Feld rechts
(`SchematicFormCraftingTemplate`, Camelot) hat als Rand den Atlas `common-insideframe`. Die Knöpfe
unten sind `SharedButtonSmallTemplate`, das Zahlenfeld `NumericInputSpinnerTemplate`, die
Statusleiste `ProfessionsRankBarTemplate` mit `Professions-skillbar-bg` und
`Professions-skillbar-frame`.

### Vorlagen, die Amisia erbt

| Vorlage | Datei im Client | Nutzen in Amisia | Hinweise |
|---|---|---|---|
| `PortraitFrameTemplate` | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` 658 (Basis 566, 624) | Hauptfenster, Ausrüstungstabelle, Dialoge (Porträt aus) | Teile: `NineSlice` (Layout `PortraitFrameTemplate`, Ebene 500), `Bg` (Fels-Kachel), `TopTileStreaks`, `PortraitContainer.portrait` (62 x 62, runde Maske, bei -5, +7), `TitleContainer.TitleText` (GameFontNormal, gold, mittig zwischen x 58 und -24), `CloseButton`. Methoden über `PortraitFrameMixin`/`TitledPanelMixin` (`PortraitFrame.lua`): `SetPortraitToAsset`, `SetPortraitShown`, `SetBorder`, `SetTitle`, `SetTitleOffsets`. Benannte Kinder (`$parentCloseButton`, `$parentBg`, `$parentPortrait`, `$parentTitleText`) werden mit Fensternamen globale Namen mit Präfix `Amisia...`; unbedenklich. Keine `OnLoad`/`OnShow`-Skripte in der Basis, Amisias eigene Skripte überschreiben nichts. |
| `UIPanelCloseButton` (über `UIPanelCloseButtonDefaultAnchors`) | dieselbe Datei 134-157 | Teil der Fenstervorlage | Atlanten `RedButton-Exit`, `-pressed`, `-Disabled`, `RedButton-Highlight`; Camelot setzt die Lage auf `TOPRIGHT -2, 1`. `OnClick` wird überschrieben (Kampf, siehe oben). |
| `ListHeaderVisualTemplate, ListHeaderCodeTemplate` | `Blizzard_SharedXML/ListTemplates.xml` | Abschnittsbalken der Seitenliste, Abschnitte der Einstellungen | Atlas `common-button-list-collapseExpand`, Schrift `Game15Font_Shadow`, `CollapseButton` mit `common-button-list-minus`/`-plus`. Kombination von Blizzard selbst genutzt (`SocialUISharedTemplates.xml` 73). Klick über `SetClickHandler` (nicht `SetScript("OnClick")`, sonst gehen Mixin-Skripte verloren); Farbe über `SetTitleColor(false, NORMAL_FONT_COLOR)` wie in der Rezeptliste. |
| `SharedButtonSmallTemplate` | `Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml` 87 | `W.Button` | Drei Teile aus `128-RedButton-Left/-Right/_128-RedButton-Center`, Zustände `-Pressed`, `-Disabled`, Glanz `-Highlight`; skaliert die Ränder auf die Höhe (`UpdateScale`), also auch bei 20 und 22 px. Schrift `GameFontNormal` (gold), gedrückt versetzt. Vorlage setzt `OnMouseDown/Up`, `OnShow`, `OnEnable/Disable`, `OnEnter/Leave`, `OnSizeChanged`: Amisia darf an diesen Knöpfen nur `HookScript` nutzen, ausgenommen `OnEnter`/`OnLeave` (die Vorlage zeigt dort nur `self.tooltip`; `W.Tooltip` darf sie ersetzen). `motionScriptsWhileDisabled`: Tooltips erscheinen auch an gesperrten Knöpfen. |
| `LargeSideTabButtonTemplate` | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` 1008 | Reiter rechts | Ein `Frame` (kein Button). Größe aus dem Atlas `common-sidetab` (`SidePanelTabButtonMixin.CalculateTabSizeBasedOnTabArt`), Camelot verschiebt das Symbol um -4. `Icon`, `SelectedTexture`, `SetChecked`, `tooltipText`, Klick über `SetCustomOnMouseUpHandler(fn)` (prüfen: `button == "LeftButton" and upInside`). `fillToInterior = true` wie die Berufsreiter. |
| `SearchBoxTemplate` | `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml` 206 | neues `W.SearchBox` (Seite Vergaben) | Lupe `common-search-magnifyingglass`, Löschknopf `common-search-clearbutton`, Platzhalter `Instructions` (Text aus `SEARCH`, im deutschen Client "Suchen"; Amisia setzt eigenen Text). Eigene Skripte nur mit `HookScript` (`OnTextChanged`, `OnEditFocusGained/Lost` der Vorlage zeigen Platzhalter und Löschknopf). |
| `InputBoxTemplate` | dieselbe Datei 70 (Optik 43) | `W.LineEdit`, `W.TimeBox`, Feld von `W.Stepper` | Rand aus `common-search-border-left/-middle/-right`; der linke Teil sitzt 5 px **links außerhalb** des Felds. Amisia setzt ihn auf x = 0 und rückt den Text mit `SetTextInsets(6, 4, 0, 0)` ein, damit alles innerhalb der Feldgrenzen bleibt (Layout-Tests). Die Vorlagenskripte (`OnEscapePressed`, `OnEditFocusGained/Lost`, `OnTabPressed`) ersetzt Amisias `editBox` wie heute durch eigene; das Markieren beim Fokus entfällt dadurch wie bisher. |
| `MinimalScrollBar` | `Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml` 15 | alle Bildlaufleisten | 8 px breit, Atlanten `minimal-scrollbar-track-*`, `minimal-scrollbar-small-thumb-*`. An einem `ScrollFrame` über `ScrollUtil.InitScrollFrameWithScrollBar(sf, bar)` (`ScrollUtil.lua` 215; setzt `OnVerticalScroll`, `OnScrollRangeChanged`, `OnMouseWheel` des ScrollFrames, die Amisia dann nicht selbst setzen darf). An `W.List` direkt: `SetVisibleExtentPercentage`, `SetPanExtentPercentage`, `SetScrollPercentage`, `RegisterCallback(BaseScrollBoxEvents.OnScroll, fn, owner)`, `SetHideIfUnscrollable(true)`. Ersetzt `UIPanelScrollFrameTemplate` (`SecureScrollTemplates.xml`, laut Client-Kommentar "No longer to be used"). |
| `MinimalCheckboxTemplate` | `Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml` 74 | `W.Toggle` | Das Häkchenfeld des Berufsfensters (`CheckboxWithLabelTemplate` erbt dieselbe Optik): `checkbox-minimal`, `checkmark-minimal`, `checkmark-minimal-disabled`. Ein `CheckButton` schaltet sich beim Klick **selbst** um, bevor `OnClick` läuft: `W.Toggle` liest in `OnClick` nur noch `self:GetChecked()` (heute schaltet es selbst um; mit einem CheckButton wäre das doppelt). |
| `TooltipBackdropTemplate` | `Blizzard_SharedXML/SharedTooltipTemplates.xml` 111 | Upgrade-Hinweis (`AmisiaBisToast`) | Rand und Grund wie ein Client-Tooltip (Layout `TooltipDefaultLayout`). |

Geprüft und **nicht** genommen:

| Vorlage | Grund |
|---|---|
| `ButtonFrameTemplate` | bringt ein festes `Inset` (4, -60 bis -6, 26) und eine Knopfleiste mit, die zu Amisias Anordnung nicht passen. Die Dialoge nehmen `PortraitFrameTemplate` mit `SetBorder("ButtonFrameTemplateNoPortrait")`, `SetPortraitShown(false)`, `SetTitleOffsets(0, 0)`; das ist genau, was `ButtonFrameTemplate_HidePortrait` tut, ohne das Inset. |
| `InsetFrameTemplate` | Forever selbst zeichnet seine Einsätze mit dem Atlas `common-insideframe` (Camelot-Berufsfeld, `Camelot/CharacterFrame.xml`, `Camelot/PaperDollFrame.xml`, Gruppensuche) und blendet das NineSlice des Insets aus (`ProfessionsCraftingPageMixin:OverrideArt`). Amisia folgt dem. |
| `NumericInputSpinnerTemplate` | drei Ziffern, Schritt 1 (siehe oben); dazu alte Dateitexturen `UI-SpellbookIcon-*`. |
| `WowStyle1FilterDropdownTemplate`, `WowStyle1DropdownTemplate` | `DropdownButton` mit dem Menüsystem des Clients; Amisia behält `W.Picker`/`W.Menu` (Filterfeld, Freitext, Schließen nach zwei Sekunden). Ihre Atlanten nimmt Amisia trotzdem (unten). |
| `UICheckButtonTemplate` | ältere Dateitexturen; das Berufsfenster nimmt die Minimal-Variante. |
| `ScrollingEditBoxTemplate`, `WowScrollBoxList` | ScrollBox-Technik mit Datenanbietern; der Umbau von `W.List` und `W.EditArea` darauf wäre eine Verhaltensänderung (Fokus, Zeilenwiederverwendung, Tests). `MinimalScrollBar` geht auch an einem einfachen `ScrollFrame`. |
| alle `Professions*`-Vorlagen | LoadOnDemand, Berufs-Mixins (siehe oben). |
| `ItemButton` | siehe Entscheidungen. |

### Atlanten, die Amisia direkt setzt

Alle Namen stehen im Forever-Quelltext an der genannten Stelle; Atlanten sind Client-Daten und auch
ohne das jeweilige Blizzard-Addon vorhanden. Im Spiel prüft ein Einzeiler, ob alle da sind (siehe
"Offene Punkte").

| Atlas | Fundstelle | Amisia |
|---|---|---|
| `Profession-Background-Overview` | `Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua` 126 | Hintergrund `Bg` von Hauptfenster und Ausrüstungstabelle |
| `Professions-background-summarylist` | `Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRecipeList.xml` 10 | Grund der Seitenliste |
| `Professions_Recipe_Active` | dieselbe Datei 192 | gewählte Zeile (Seitenliste und `W.SelectBar` in allen Listen) |
| `Professions_Recipe_Hover` | dieselbe Datei 199 (Alpha 0.5) | überfahrene Zeile der Seitenliste |
| `common-insideframe` | `Blizzard_ProfessionsTemplates/Camelot/Blizzard_ProfessionsRecipeSchematicForm.xml` 8, `Blizzard_UIPanels_Game/Camelot/CharacterFrame.xml` 134 | Rand von `W.Inset` (Inhaltsfeld, Seitenliste, Übersichtskarten) |
| `Professions-skillbar-bg`, `Professions-skillbar-frame` | `Blizzard_ProfessionsTemplates/Blizzard_ProfessionsRankBar.xml` 9, 39 (453 x 18 und 451 x 29) | Statusleiste im Kopf des Hauptfensters |
| `common-dropdown-a-button` und Zustände (`-hover`, `-pressed`, `-pressedhover`, `-open`, `-disabled`, je auch `-shadowless`) | `Blizzard_Menu/Mainline/MenuTemplates.lua` 5-34 | `W.ArrowButton` (seit 2.1, unverändert) |
| `common-dropdown-b-button` und `-hover`, `-pressed`, `-pressedhover`, `-open`, `-disabled` | `Blizzard_Menu/Mainline/MenuConstants.lua` 1-6 | `W.Chip` und `W.Choice` (der Knopf "Filter" des Berufsfensters) |
| `common-dropdown-bg` | `Blizzard_Menu/Mainline/MenuTemplates.lua` 55 (Lage -10, 3 / 10, -3, Alpha 0.925) | Grund von `W.Menu` und dem Picker-Feld |
| Textur `Interface\QuestFrame\UI-QuestTitleHighlight` (ADD) | `Blizzard_Menu/MenuVariants.lua` 46 | überfahrene Zeile in `W.Menu` und Picker |

Die Atlanten der geerbten Vorlagen (`128-RedButton-*`, `RedButton-Exit*`, `common-sidetab*`,
`common-search-*`, `minimal-scrollbar-*`, `checkbox-minimal`, `common-button-list-*`) setzt der Client
selbst; Amisia nennt sie nicht.

### Taint und Sicherheit

- Keine der geerbten Vorlagen ist geschützt oder sicher (`Secure...`); keine ruft geschützte
  Funktionen. Amisias Fenster bleiben normale Frames, auch im Kampf zu zeigen, zu verschieben und zu
  schließen.
- Einzige gefundene Falle: `UIPanelCloseButton_OnClick` -> `HideUIPanel` (Kampfsperre, siehe oben).
  Behoben durch eigenes `OnClick`.
- Nicht verwendet: `ShowUIPanel`, `UIPanelWindows`, `ToggleUIPanel`, das Menüsystem, `LoadAddOn` der
  Berufs-Addons.
- `ScrollUtil.InitScrollFrameWithScrollBar` und die Mixins sind gewöhnlicher Lua-Code ohne
  `securecall`-Abhängigkeiten. `ScrollUtil` schreibt Felder (`panExtent`, `GetPanExtent`) in Amisias
  ScrollFrame: unbedenklich.
- `PortraitFrameBaseTemplate` bringt `FocusFramesInterfaceMixin` und Gamepad-Sprunghinweise mit, aber
  ohne Skripte; nichts meldet das Fenster beim Gamepad-Manager an.
- Prüfung im Spiel mit `/console taintLog 1` (siehe "Offene Punkte").

## Dateien

```
addon/Amisia/Widgets.lua        W.Window (Fensterfabrik), W.Inset, W.SelectBar, W.SectionHeader,
                                W.SearchBox, W.Scroll; W.Button, W.Chip, W.Choice, W.Toggle,
                                W.Stepper, editBox (LineEdit/TimeBox), W.EditArea, W.ScrollText,
                                W.List (Leiste, Kopfzeilen), W.Card, W.Menu, W.Picker im neuen Stil
addon/Amisia/Registry.lua       Feld group an RegisterPanel, ns.PANEL_GROUPS, ns.PanelGroup(p)
addon/Amisia/MainFrame.lua      Fenster 806 x 560 über W.Window, Kopf mit Statusleiste, Seitenliste
                                mit Abschnitten, Inhaltsfeld, Reiter rechts, ns.UpdateSideTabs
addon/Amisia/GearFrame.lua      W.Window mit Porträt, eigene flat/border/chip-Kopien entfallen
                                (W.Flat, W.Chip), Klassenreihe ab x = 64
addon/Amisia/RollFrame.lua      W.Window ohne Porträt, W.Button statt UIPanelButtonTemplate,
                                Zeitanzeige aus der Titelleiste in die Kopfzeile
addon/Amisia/AwardDialog.lua    W.Window ohne Porträt
addon/Amisia/SoftRes.lua        Import-Fenster: W.Window ohne Porträt, W.EditArea statt eigenem
                                Scrollfeld, W.Button
addon/Amisia/Bis.lua            Upgrade-Hinweis erbt TooltipBackdropTemplate
addon/Amisia/Pages/*.lua        Feld group; r.sel über W.SelectBar; Listen mit Leiste; Seite-
                                Vergaben-Suche über W.SearchBox; Einstellungen mit W.SectionHeader
                                und W.Scroll; Übersicht CARD_W 295
addon/Amisia/Amisia.toc         Version 2.2.0
addon/Amisia/Core.lua           ns.VERSION = "2.2.0"
addon/tests/wow_stub.lua        Vorlagen-Register, CheckButton, ScrollUtil, C_Texture.GetAtlasInfo,
                                SEARCH, NORMAL_FONT_COLOR
addon/tests/layout.lua          L.inside(fr) (ganz in der Wurzel), Breite aus Vorlagenteilen
addon/tests/test_style.lua      NEU
addon/tests/*                   bestehende Tests an Geometrie und Widgets angepasst
```

Unverändert: Map.lua (der Pfeil `AmisiaArrow` ist ein Bildschirmelement ohne Rahmen), MapPins.lua
(Pins der Weltkarte), Minimap.lua, alle Datendateien, Export, Website, Twin.

## Gespeicherte Werte

Nur ein neuer Schlüssel: `AmisiaDB.settings.window.collapsed = { [group] = true }` (eingeklappte
Abschnitte der Seitenliste; fehlt er, ist alles offen). Kein Umzug nötig. `ns.ResetPositions` lässt
ihn stehen. Keine neuen Einstellungen im Abschnitt "Oberfläche".

## Registry (Registry.lua)

- `ns.RegisterPanel{ ..., group = "raid" | "gear" | "guild" | "amisia" }`. Fehlt `group`, gilt nach
  `order`: unter 50 "raid", unter 60 "gear", unter 900 "guild", sonst "amisia" (Testseiten mit
  `order = 5` landen damit unter "Raid").
- `ns.PANEL_GROUPS = { { key = "raid", label = "Raid" }, { key = "gear", label = "Ausrüstung" },
  { key = "guild", label = "Gilde" }, { key = "amisia", label = "Amisia" } }`.
- Das Feld `bottom` (Einstellungen, Über) wird nicht mehr gebraucht, bleibt aber erlaubt.
- Jede Seite setzt `group` ausdrücklich (Tabelle oben).

## Widgets (Widgets.lua)

Die Signaturen bleiben, damit die Seiten unverändert aufrufen. Felder, die Tests lesen (`r.sel`,
`st.plus`, `st.minus`, `c.label`, `p.arrow`, `box`, `scroll`, `fs`, `items`, `offset`), bleiben.

- **`W.Window(name, width, height, opts)`** -> Frame. `opts.portrait` (Texturpfad oder nil),
  `opts.title`, `opts.strata`, `opts.background` (Atlas oder nil = Vorlagen-Hintergrund),
  `opts.onShow`. Erbt `PortraitFrameTemplate` über `pcall(CreateFrame, "Frame", name, UIParent,
  "PortraitFrameTemplate")`. Mit Porträt: `SetPortraitToAsset`. Ohne: `SetBorder(
  "ButtonFrameTemplateNoPortrait")`, `SetPortraitShown(false)`, `SetTitleOffsets(0, 0)`.
  Hintergrund: ist `C_Texture.GetAtlasInfo(opts.background)` gesetzt, `Bg:SetAtlas(atlas)` (gestreckt
  auf die Fläche wie im Berufsfenster) und `TopTileStreaks:Hide()`; sonst bleibt die Fels-Kachel.
  `CloseButton:SetScript("OnClick", function(b) b:GetParent():Hide() end)`. Dazu wie heute:
  `SetToplevel`, `SetClampedToScreen`, `SetMovable`, `EnableMouse`, Ziehen mit links,
  `UISpecialFrames`. Ohne Vorlage (Fehler im `pcall`): flaches Fenster wie heute (`W.Flat` mit `W.BG`,
  `W.Border` gold, Titel als FontString links, `UIPanelCloseButton` mit demselben `OnClick`), Felder
  `TitleContainer.TitleText`, `CloseButton` und Methoden `SetTitle`, `SetPortraitToAsset` als kleine
  Ersatzfunktionen, damit die Aufrufer nicht unterscheiden. Konstante `W.TITLE_H = 24`: Inhalt
  beginnt frühestens 24 px unter der Oberkante.
- **`W.Inset(parent)`** -> Frame mit Textur `BORDER` = `common-insideframe` auf `SetAllPoints`,
  ohne eigene Füllung (der Fensterhintergrund scheint durch, wie im Berufsfeld). `inset.fill(atlas)`
  setzt optional einen Grund (Seitenliste: `Professions-background-summarylist`).
- **`W.SelectBar(row)`** -> Textur auf `OVERLAY` mit `Professions_Recipe_Active`, auf die Zeile
  gestreckt, versteckt. Ersetzt `W.Flat(r, GOLD..., 0.18/0.22, "BORDER")` überall, wo eine Zeile als
  gewählt markiert wird; die Seiten weisen sie weiter `r.sel` zu.
- **`W.SectionHeader(parent, label, collapsible, onToggle)`** -> Button mit
  `ListHeaderVisualTemplate, ListHeaderCodeTemplate`, Höhe 25, `SetHeaderText(label)`,
  `SetTitleColor(false, NORMAL_FONT_COLOR)`. Ohne `collapsible` wird `CollapseButton` versteckt.
  `h:SetCollapsed(on)` ruft `UpdateCollapsedState`. Klick über `SetClickHandler`.
- **`W.Button(parent, label, width, onClick)`**: erbt `SharedButtonSmallTemplate`, Höhe 22, sonst
  wie heute. `W.Button(..., { height = 20 })` für die Zeilenknöpfe im Roll-Fenster und auf Seiten mit
  18-20 px Zeilen (optionales fünftes Argument).
- **`W.Chip`**: Hintergrund-Textur mit den `common-dropdown-b-button`-Atlanten, Zustand wie bei
  `W.ArrowButton` (über, gedrückt, gesperrt); an = `-open` und Schrift gold (`GOLD`), aus =
  Normalzustand und Schrift grau (0.6). Kein goldener Rahmen mehr; `b.edges`/`b.bg` entfallen
  (`b.bg` bleibt als Name der Hintergrundtextur). Größe und Text wie heute; der Atlas liegt auf
  `SetAllPoints`, nicht wie in der Vorlage 4 px außerhalb (dort berühren sich Chips mit 3-4 px
  Abstand sonst).
- **`W.Choice`**: wie Chip (unverändert die Logik).
- **`W.Toggle`**: `CreateFrame("CheckButton", nil, parent, "MinimalCheckboxTemplate")`, Größe 18 x 18
  wie heute; `OnClick` ruft `onChange(self:GetChecked())`. `SetChecked`/`GetChecked` sind die des
  CheckButtons; das Feld `checked` spiegelt den Wert weiter (Tests).
- **`W.Stepper`**: Feld in der Mitte als Frame mit den drei `common-search-border-*`-Atlanten und dem
  Wert als FontString (`ChatFontNormal`, mittig); `f.minus` = `W.ArrowButton(f, "left", 20)`, `f.plus`
  = `W.ArrowButton(f, "right", 20)` an den Enden. Logik (Grenzen, Schritt, Shift mal zehn, Mausrad)
  unverändert.
- **`editBox` (`W.LineEdit`, `W.TimeBox`)**: erbt `InputBoxTemplate`; `Left` auf x = 0 gesetzt,
  `SetTextInsets(6, 4, 0, 0)`; `W.Flat`/`W.Border` des Felds entfallen. Skripte wie heute.
- **`W.SearchBox(parent, width, onCommit, hint)`** NEU: erbt `SearchBoxTemplate`, `Left` auf x = 0,
  `Instructions:SetText(hint or SEARCH or "Suchen")`. Gleiches Verhalten wie `W.LineEdit` (Enter oder
  Fokusverlust übergibt einmal, Escape stellt wieder her), alle eigenen Skripte über `HookScript`.
- **`W.Scroll(scrollFrame, parent)`** NEU: legt `MinimalScrollBar` 8 px breit rechts neben den
  ScrollFrame (4 px Abstand), ruft `ScrollUtil.InitScrollFrameWithScrollBar`, `SetHideIfUnscrollable
  (true)`. Ohne `ScrollUtil` (Test ohne Stub-Teil) bleibt das Mausrad wie heute.
- **`W.EditArea`, `W.ScrollText`**: einfacher `ScrollFrame` statt `UIPanelScrollFrameTemplate`, Leiste
  über `W.Scroll`; der Grund von `W.EditArea` ist ein `W.Inset` mit dunkler Füllung (0, 0, 0, 0.35).
  Rechter Rand des Textes: heute -28 (Platz für die alte Leiste), künftig -16 (Leiste 8 + 4 + 4).
- **`W.List(parent, rowCount, rowHeight, build, fill, opts)`**: Zeilen bekommen statt der
  abwechselnden Weißtöne einen sehr leichten Wechsel (1, 1, 1, 0.025 / 0.045) und als Hover
  `Professions_Recipe_Hover` mit Alpha 0.5. Neu `f.bar` (`MinimalScrollBar`), außerhalb der Liste
  rechts angeheftet (`TOPLEFT` an `TOPRIGHT` + 4, `BOTTOMLEFT` an `BOTTOMRIGHT` + 4, Breite 8),
  versteckt, solange alles passt. `SetItems` und das Mausrad setzen `SetVisibleExtentPercentage(
  rowCount / #items)`, `SetPanExtentPercentage(1 / (#items - rowCount))`,
  `SetScrollPercentage(offset / (#items - rowCount))`; der Rückruf `OnScroll` setzt `offset` gerundet
  und zeichnet neu. `opts.bar = false` schaltet die Leiste ab (Listen, die nie scrollen).
- **`W.Card`**: `W.Inset` statt Fläche und Rand; Titel gold, Knopf `W.Button`.
- **`W.Menu`**: Grund `common-dropdown-bg` (Lage und Alpha wie `MenuStyle1Mixin`), Zeilen-Hover
  `UI-QuestTitleHighlight` (ADD); goldener Rand entfällt. Verhalten gleich.
- **`W.Picker`**: Feld mit denselben `common-search-border-*`-Teilen wie `W.LineEdit` (einheitliche
  Felder), Pfeil rechts wie in 2.1. Das Auswahlfeld (`AmisiaPicker`) mit Grund `common-dropdown-bg`,
  Filterzeile als `W.SearchBox` (Platzhalter "Suchen"), Liste mit Leiste (die Zeilen enden 18 statt 6
  px vor dem Rand). **Ebene:** heute `top:GetFrameLevel() + 10`; der Rahmen einer
  `PortraitFrameTemplate` liegt auf Ebene 500, Titel und Schließen auf 510. Das Auswahlfeld muss
  darüber: `math.min(9000, math.max(top, self) + 520)`. Gilt auch für `W.Menu`, wenn sein Besitzer in
  einem Amisia-Fenster derselben Schicht liegt.
- **`W.Text`, `W.Tooltip`, `W.ArrowButton`, `W.Flat`, `W.Border`** bleiben. `W.BG` bleibt für den
  Rückfall.

## Hauptfenster (MainFrame.lua)

### Geometrie

```
x:   0   6        182 184                                              800 806
y:   0  +---------------------- Titelleiste (0 bis -21) ---------------------+
        | (O) Porträt 62 px      Amisia 2.2.0 (gold, mittig)              [X] |
   -28  |      [ Statusleiste 453 x 18, Text mittig ]        [ Pausieren ]   |
   -62  | +-Seitenliste-+ +--------------- Inhaltsfeld ---------------------+ |
        | | Raid      - | |  Seite 602 x 478 (7 px Rand im Feld)           | |   [Reiter]
        | |  Übersicht  | |                                                | |   [Reiter]
        | |  ...        | |                                                | |   [Reiter]
    -554| +-------------+ +------------------------------------------------+ |
   -560 +--------------------------------------------------------------------+
```

| Teil | Lage (relativ zum Fenster) | Größe |
|---|---|---|
| Fenster `AmisiaFrame` | wie heute gespeichert, Schicht `FULLSCREEN` | 806 x 560 |
| Porträt | Vorlage (-5, +7) | 62 x 62, rund |
| Titel | Vorlage, mittig zwischen x 58 und -24 | "Amisia \|cff8f86a32.2.0\|r" |
| Statusleiste | `TOPLEFT` (66, -28) | Grund 453 x 18, Rahmen 451 x 29 (beide `TOPLEFT`, Atlasgröße wie `ProfessionsRankBarTemplate`) |
| Statustext | mittig in der Statusleiste, y -3 | Breite 433, `GameFontHighlightSmall` |
| Knopf "Pausieren"/"Fortsetzen" | `TOPRIGHT` (-10, -26) | 110 x 22, `W.Button` |
| Seitenliste (`W.Inset`, Grund `Professions-background-summarylist`) | `TOPLEFT` (6, -62), `BOTTOMLEFT` (6, 6) | 176 x 492 |
| Inhaltsfeld (`W.Inset`) | `TOPLEFT` (184, -62), `BOTTOMRIGHT` (-6, 6) | 616 x 492 |
| Inhalt (`content`, Eltern der Seiten) | im Inhaltsfeld (7, -7) bis (-7, 7) | **602 x 478** (wie heute) |
| Reiter | erster `TOPLEFT` an Fenster-`TOPRIGHT` (0, -60), weitere 2 px darunter | Atlasgröße `common-sidetab` |

Die Statusleiste hat keine Füllung (der Fortschrittsbalken eines Berufs hätte in Amisia keine
Entsprechung); sie ist der Rahmen für den Statustext wie heute ("· Zone · 25 Raider · 2 zu spät",
"Keine Aufnahme, startet im Raid", "Aufnahme pausiert"), Farben wie heute. Linie unter dem Kopf und
Trennstrich zur Seitenliste entfallen (die Einsätze trennen).

`SetClampRectInsets(0, -tabWidth, 0, 0)` mit der Breite des ersten Reiters, damit die Reiter beim
Verschieben nicht aus dem Bildschirm rutschen. Skalierung (`ui.scale`) wirkt aufs ganze Fenster wie
heute.

### Seitenliste

- Ein Frame im Inset (6, -6 bis -6, 6), 164 breit. Aufbau bei `updateNav` je Abschnitt aus
  `ns.PANEL_GROUPS`: ein `W.SectionHeader` (25 hoch, einklappbar) und darunter die sichtbaren Seiten
  als Zeilen von 22 px, um 8 px eingerückt: Symbol 16 x 16 (Rand beschnitten wie heute) bei x = 4,
  Name `GameFontHighlight` weiß ab x = 26, Breite 130. Gewählt: `W.SelectBar`; überfahren:
  `Professions_Recipe_Hover` (0.5). 4 px Abstand nach jedem Abschnitt.
- Höchstens 4 Balken und 13 Zeilen: 4 x 25 + 13 x 22 + 4 x 4 = 402 px von 480. Kein Scrollen nötig;
  sollten es künftig mehr werden, bekommt die Liste eine `MinimalScrollBar` (nicht in 2.2).
- Ein Pool von 4 Balken und 14 Zeilen (`NAV_MAX` bleibt 14); `updateNav` setzt sie wie heute neu.
- Klick auf eine Zeile: `ns.ShowPage(key)`. Klick auf einen Balken: Abschnitt ein- oder ausklappen,
  `AmisiaDB.settings.window.collapsed[group]` umschalten, `updateNav`.

### Reiter rechts

`LargeSideTabButtonTemplate`, `fillToInterior = true`, Symbole:

| Reiter | Symbol | Sichtbar | Klick | Markiert |
|---|---|---|---|---|
| "Ausrüstungstabelle" | `Interface\Icons\INV_Chest_Chain_05` | `Gear.Available()` und `ns.ToggleGearFrame` | `ns.ToggleGearFrame()` | `AmisiaGearFrame` sichtbar |
| "Rolls" | `Interface\Buttons\UI-GroupLoot-Dice-Up` | `ns.IsOfficerView()` | `ns.ToggleRollFrame()` | `AmisiaRollFrame` sichtbar |
| "Soft-Reserve-Import" | `Interface\Icons\INV_Scroll_03` | `ns.IsOfficerView()` | `ns.ToggleSoftResFrame()` | `AmisiaSoftResFrame` sichtbar |

`ns.UpdateSideTabs()` richtet Sichtbarkeit, Lage (lückenlos untereinander) und Markierung neu; es
läuft in `ns.Refresh` und in `OnShow`/`OnHide` der drei Fenster (je eine `HookScript`-Zeile in
`W.Window` über `opts.onVisibility = ns.UpdateSideTabs`, damit die Fenster MainFrame.lua nicht kennen
müssen).

### Unverändert

`ns.ShowPage`, `ns.Refresh`, `ns.ToggleMain`, `ns.Toggle`, Fehlerseite, Aufbau beim ersten Öffnen,
Position speichern und zurücksetzen, `ns.ApplyScale`, Befehl `einstellungen`, Escape.

## Seiten

Die Inhaltsfläche bleibt 602 x 478. Je Seite ändert sich nur:

| Seite | Änderungen |
|---|---|
| Übersicht | Karten als `W.Inset`; `CARD_W` 296 -> 295 (heute ragt die rechte Karte 2 px über 602 hinaus: 2 x 296 + 12 = 604; mit sichtbarem Rand fiele das auf) |
| Raids | `r.sel` -> `W.SelectBar`; Häkchen `r.box` -> neuer `W.Toggle`; `f.detail` mit Leiste; Liste mit Leiste (rechter Rand prüfen) |
| Raid-Log | `V.list`, `B.list` mit `W.SelectBar` und Leiste; `V.detail` (ScrollText) und `D.area` (EditArea) mit Leiste; `B.note` neues Feld |
| Rolls | Liste (12 x 22) mit Leiste |
| Vergaben | `O.list`, `A.list`, `R.list` mit `W.SelectBar` und Leiste; `O.search` -> `W.SearchBox(O, 172, ..., "Name oder Item")`, `O.searchHint` und seine zwei Hooks entfallen (der Platzhalter der Vorlage tut dasselbe); Konfliktleiste `B`: `W.Inset` mit goldener Füllung 0.16 statt Fläche und Rand |
| Soft-Reserves | Liste mit `W.SelectBar` (eigene Zeile gold markiert wie heute) und Leiste |
| Ausrüstung | `G.list`, `Hh.list`, `V.list`, `U.list` mit Leiste; `G`-Zeilen `r.sel` -> `W.SelectBar`; Optionszeilen `G.opts` mit `Professions_Recipe_Hover`; `V.area`, `U.area` mit Leiste; Spaltenköpfe (`col(h, ...)`) bleiben Text wie heute |
| Karte | Liste mit Leiste; Spaltenköpfe unverändert |
| Export | `W.EditArea` mit Leiste |
| Gildenbank | Liste mit Leiste; `f.add.box` neues Feld |
| Werkzeuge | nur neue Knöpfe |
| Einstellungen | Abschnittstitel -> `W.SectionHeader(child, label, false)` (25 hoch statt 24, ohne Einklappen); ScrollFrame ohne Vorlage, Leiste über `W.Scroll` (rechter Rand -24 -> -16); `W.Toggle`, `W.Stepper`, `W.TimeBox`, `W.LineEdit`, `W.Choice`, Rücksetz-Chip "x" im neuen Stil; Zeilenbreite 560 bleibt |
| Über und Befehle | Liste mit Leiste; `f.text` (ScrollText) mit Leiste |

**Regel für Listen mit Leiste:** die Leiste liegt 4 bis 12 px rechts neben der Liste. Endet eine Liste
heute an der rechten Kante (602) oder weniger als 12 px vor einem Nachbarn, wird sie 12 px schmaler;
Teile, die an `RIGHT` der Zeile hängen (Knöpfe, rechtsbündige Zahlen), rücken mit, Teile an `LEFT`
bleiben. Jede Aufgabe prüft das je Liste im Layout-Test (`L.row(..., list, list.bar)`, Leiste
innerhalb von 602). Listen, die nie mehr Einträge als Zeilen haben können, bekommen `opts.bar = false` und bleiben, wie
sie sind. `G.list` (Ausrüstung, Ziele) zeigt 11 von 17 Slots und bekommt die Leiste.

Welche Listen an der Kante enden, klärt die jeweilige Aufgabe mit den Layout-Tests; der Entwurf legt
die Regel fest, nicht jede Zahl.

## Andere Fenster

| Fenster | Heute | 2.2 |
|---|---|---|
| Ausrüstungstabelle `AmisiaGearFrame` (820 x 640, `FULLSCREEN`) | Logo 30 px und Titel links, flache Fläche | `W.Window` mit Porträt `Amisia.tga`, Hintergrund `Profession-Background-Overview`; Titel (`titleText`, heute dynamisch gesetzt) über `F:SetTitle`. Die Klassenreihe (y -42) läge unter dem Porträt (es reicht bis x 57, y -55): sie beginnt bei x = 64 statt 14 (9 Klassen x 36 = 324, endet bei 388). Zweite und dritte Reihe (y -82, -108) liegen unter dem Porträt und bleiben. Eigene Kopien `text`, `flat`, `border`, `setBorderColor`, `chip` entfallen zugunsten von `W.Text`, `W.Flat`, `W.Chip` (Widgets.lua lädt vorher). Klassenknöpfe: Rand `W.Border` bleibt (Klassenfarbe). Zellen und Listen: `W.SelectBar` statt goldener Fläche, Leiste wo die Liste scrollt. |
| Roll-Fenster `AmisiaRollFrame` (360 breit) | Titel "Amisia Rolls" bei (12, -10), Zeitanzeige oben rechts (-40, -8) | `W.Window` ohne Porträt, Titel "Amisia Rolls" in der Titelleiste. Die Zeitanzeige läge unter dem Schließen-Knopf: sie rückt in die Kopfzeile (`TOPRIGHT` -12, -28, rechtsbündig), `header` bleibt bei (12, -30) mit Breite 330 -> 220, damit beide nebeneinander passen. Alle `UIPanelButtonTemplate` -> `W.Button` (Zeilenknopf "Vergeben" 64 x 18 mit `height`). Zeilen bleiben (keine Liste mit Leiste: 12 feste Zeilen). |
| Vergabe-Dialog `AmisiaAwardDialog` (380 x 248) | Titel "Vergabe" bei (12, -10) | `W.Window` ohne Porträt, Titel in der Leiste; alles andere liegt schon ab y -32 und bleibt. |
| Soft-Reserve-Import `AmisiaSoftResFrame` (440 x 380) | Titel bei (12, -10), eigenes Scrollfeld mit `UIPanelScrollFrameTemplate` | `W.Window` ohne Porträt; das Textfeld wird `W.EditArea` (gleiche Lage 12, -50 bis -12, `BOX_BOTTOM`; `F.editBox` = `area.box`, `F.box` = `area`); Knöpfe `W.Button`. Der globale Name `AmisiaSoftResScroll` entfällt (prüfen, dass ihn nichts liest). |
| Upgrade-Hinweis `AmisiaBisToast` (320 x 58) | Fläche und goldener Rand | erbt `TooltipBackdropTemplate`; Rest gleich. |
| Pfeil `AmisiaArrow` | Textur ohne Rahmen | unverändert |
| Menü `AmisiaMenu`, Picker `AmisiaPicker` | siehe Widgets | |

Alle Fenster behalten Namen, Schicht, Größe (außer dem Hauptfenster), Position und Verhalten.

## Fehlerbehandlung

- Fehlt eine Vorlage (Patch), baut `W.Window` das flache Fenster; einzelne Widgets fallen ebenso über
  `pcall(CreateFrame, ...)` auf ihren heutigen Aufbau zurück (`W.Button` auf
  `UIPanelButtonTemplate`, `W.Toggle` auf den eigenen Kasten, `W.SearchBox` auf `W.LineEdit` mit
  Hinweistext, `W.Scroll` auf "nur Mausrad"). Ein Fehler wird nicht gemeldet (kein Chat), das Fenster
  bleibt bedienbar.
- Fehlt ein Atlas (`C_Texture.GetAtlasInfo` gibt nil), bleibt die Fläche leer bzw. die
  Vorlagen-Textur; `W.SelectBar` fällt auf die goldene Fläche von heute zurück (gewählte Zeilen müssen
  sichtbar bleiben).
- Teile der Vorlage werden nur mit Prüfung benutzt (`if F.Bg then`, `if h.CollapseButton then`).

## Leistung

- Aufbau bleibt verzögert (Seiten beim ersten Öffnen, Fenster beim ersten Zeigen).
- Etwa 60 rote Knöpfe: `UpdateScale` läuft nur bei Größenänderung und `OnShow`; unbedeutend.
- 17 Bildlaufleisten (`EventFrame` mit Rückruf): `SetItems` setzt drei Werte; kein `OnUpdate`.
- Atlanten statt Farbtexturen: gleiche Zahl an Texturen, keine zusätzlichen Frames außer Leisten,
  Abschnittsbalken (4) und Reitern (3).
- Kein neues `OnUpdate`. Die Statusleiste wird wie heute nur in `ns.Refresh` gesetzt.

## Tests

### Stub (`wow_stub.lua`)

- **Vorlagen-Register:** `CreateFrame(kind, name, parent, template)` zerlegt `template` an Kommas,
  speichert `f.inherits = { [name] = true }` und `f.template`, und baut für bekannte Vorlagen die
  Teile, die Amisia anfasst. **Unbekannte Vorlage -> Fehler** (wie im Client), damit ein Tippfehler
  im Test auffällt; ein Test kann über `STUB.missingTemplates[name] = true` eine Vorlage fehlen
  lassen (Rückfall-Tests). Bekannt:
  - `PortraitFrameTemplate`: `NineSlice`, `Bg`, `TopTileStreaks`, `PortraitContainer.portrait`,
    `TitleContainer.TitleText`, `CloseButton` (Button, ohne `OnClick`); Methoden `SetPortraitToAsset`
    (merkt `portraitAsset`), `SetPortraitShown`, `SetBorder` (merkt `border`), `SetTitle` (setzt den
    Text von `TitleText`), `GetTitleText`, `SetTitleOffsets`.
  - `UIPanelCloseButton`, `UIPanelButtonTemplate` (für den Rückfall), `SharedButtonSmallTemplate`
    (`Text`, `Left`, `Right`, `Center`).
  - `ListHeaderVisualTemplate`, `ListHeaderCodeTemplate`: `ButtonText`, `CollapseButton` mit `Icon`,
    `SetHeaderText`, `SetTitleColor`, `UpdateCollapsedState` (merkt `collapsed`), `SetClickHandler`
    (Klick ruft den Handler).
  - `LargeSideTabButtonTemplate`: `Icon`, `SelectedTexture`, `SetChecked` (merkt), Größe 43 x 50,
    `SetCustomOnMouseUpHandler`; `STUB.clickTab(tab)` ruft den Handler mit `"LeftButton", true`.
  - `InputBoxTemplate`, `SearchBoxTemplate`: `Left`, `Middle`, `Right`, `Instructions`, `searchIcon`,
    `clearButton`.
  - `MinimalScrollBar`: merkt `visible`, `pan`, `scroll`, Rückrufe aus `RegisterCallback`;
    `STUB.scrollBar(bar, pct)` ruft sie; `SetHideIfUnscrollable`; Breite 8.
  - `MinimalCheckboxTemplate`: nur mit `kind == "CheckButton"`.
  - `TooltipBackdropTemplate`: `NineSlice`.
  - Bestehende Vorlagen, die Amisia weiter nutzt (etwa `AmisiaMapPinTemplate` über die Pin-Pools).
- **CheckButton:** `Click()` schaltet `checked` um, dann `OnClick` (wie im Client).
- **Atlanten:** `SetAtlas` merkt den Namen (`tex.atlas`); `C_Texture.GetAtlasInfo(name)` gibt für die
  Atlanten aus der Tabelle oben `{ width, height }`, sonst nil; `STUB.missingAtlases[name]` lässt
  einen fehlen.
- **Sonstiges:** `ScrollUtil.InitScrollFrameWithScrollBar` (merkt das Paar, setzt `OnMouseWheel`),
  `BaseScrollBoxEvents = { OnScroll = "OnScroll" }`, `SEARCH = "Suchen"`,
  `NORMAL_FONT_COLOR` mit `GetRGB`/`GetRGBA`, `InCombatLockdown` über `STUB.combat`.

### `layout.lua`

- `L.inside(name, fr)`: ein Teil liegt ganz in der Wurzel (für Leisten und Felder).
- Breite einer Vorlage ohne `SetWidth` aus dem Stub (Leiste 8, Reiter 43), damit `span` sie kennt.

### Neu: `test_style.lua`

- Jedes Widget erbt die richtige Vorlage (`inherits`): Button, Toggle (CheckButton), LineEdit,
  TimeBox, SearchBox, Picker-Filter, Abschnittsbalken, Fenster.
- Jeder Atlas, den Amisia setzt, steht in der Tabelle "Atlanten, die Amisia direkt setzt" (Stub
  zählt alle `SetAtlas`-Aufrufe aller Tests in dieser Datei mit; Prüfung gegen die Liste).
- Hauptfenster: Porträt `Media\Icons\Amisia`, Titel "Amisia " .. Version, Hintergrund-Atlas.
  Layout mit `layout.lua(AmisiaFrame, 806, 560)`: Kopf `L.row(statusBar, pauseBtn)`, Spalte
  Seitenliste und Inhaltsfeld nebeneinander ohne Überlappung, `content` genau 602 x 478 bei
  (191, -69), Statusleiste unter der Titelleiste (y <= -24) und rechts vom Porträt (x >= 58).
- Seitenliste: Abschnitte und Reihenfolge für Raider, Offizier, Experte (Raider ohne "Gilde");
  Einklappen per Klick, Zustand in `AmisiaDB.settings.window.collapsed`, gezeigte Seite bleibt;
  gewählte Zeile mit `Professions_Recipe_Active`; 4 Balken + 13 Zeilen passen in 480.
- Reiter: Sichtbarkeit je Rolle und mit/ohne Ausrüstungsdaten; Klick öffnet und schließt das Fenster;
  Markierung folgt `OnShow`/`OnHide`; Reiter liegen rechts außerhalb des Fensters.
- Schließen: `STUB.combat = true`, Klick auf `CloseButton` jedes Fensters -> versteckt, ohne Aufruf
  von `HideUIPanel` (Stub-`HideUIPanel` wirft im Kampf).
- Rückfall: `STUB.missingTemplates.PortraitFrameTemplate = true` -> Fenster entsteht flach, Titel
  gesetzt, Schließen geht; fehlender Atlas `Professions_Recipe_Active` -> `W.SelectBar` sichtbar als
  Fläche.
- Liste mit Leiste: 30 Einträge in 12 Zeilen -> `visible == 12/30`; Mausrad setzt `scroll`;
  `STUB.scrollBar(bar, 1)` zeigt das Ende; 5 Einträge -> Leiste versteckt.
- Picker-Ebene: Picker im Vergabe-Dialog liegt über Ebene 510 des Dialogs.
- Dialoge: Titel in `TitleText`, kein eigener FontString bei (12, -10) mehr; nichts beginnt über
  y = -24 außer Titel und Schließen; Roll-Fenster `L.row(header, timer)`.
- Alle neuen Texte ("Raid", "Ausrüstung", "Gilde", "Amisia", "Ausrüstungstabelle", "Rolls",
  "Soft-Reserve-Import", "Name oder Item", "Suchen") Latin-1 (Byte-Prüfung wie in den Seitentests).

### Angepasste Tests

- `test_widgets.lua`: Toggle über `Click()` am CheckButton; Stepper über `st.plus`/`st.minus` (jetzt
  Pfeilknöpfe, gleiche Felder); Chip-Zustände über `bg.atlas`; EditArea/ScrollText mit Leiste.
- `test_mainframe.lua`: wie heute, dazu Größe 806 x 560 und Inhalt 602 x 478.
- Seiten-Layout-Tests (`test_pages.lua`, `test_map_page*.lua`, `test_bis_page*.lua`,
  `test_softres_page.lua`, `test_raidlog_page.lua`, `test_award_*`, `test_sync_ui.lua`,
  `test_review21_ui.lua`, `test_export.lua`, `test_raidtext.lua`, `test_raidlog.lua`): Wurzel bleibt
  602 x 478; jede `L.row`, die eine Liste enthält, nimmt `list.bar` als letztes Glied auf, wo die
  Liste eine Leiste hat; geänderte Breiten (Liste -12) in den Erwartungen.
- `test_arrows.lua`: Picker-Feld mit neuen Randteilen, Pfeil wie bisher.
- Tests, die `rows[i].sel:IsShown()` prüfen, bleiben unverändert (Feld `sel` bleibt).
- Tests, die `O.searchHint` lesen (Seite Vergaben), prüfen stattdessen `O.search.Instructions`.

Am Ende eine unabhängige Prüfung über alle Änderungen (Skill adversarial-review) mit Augenmerk auf
Taint (Schließen, Ebenen, Skripte der Vorlagen, die eigene `SetScript`-Aufrufe überschreiben könnten)
und auf Seiten, deren Teile durch die Leiste verdeckt werden.

Befehle (N100): `~/.venvs/amisia/bin/python addon/tests/run.py`,
`~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
`NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs`.

## Vorschlag für den Plan (7 Aufgaben)

1. **Stub und Werkzeuge:** Vorlagen-Register, CheckButton, Atlanten mit `GetAtlasInfo`, `ScrollUtil`,
   `SEARCH`, `NORMAL_FONT_COLOR`, `STUB.combat`, `STUB.missingTemplates`/`missingAtlases`;
   `layout.lua` mit `L.inside` und Vorlagenbreiten. Alle bestehenden Tests bleiben grün (noch erbt
   Amisia fast nichts; `UIPanelButtonTemplate`, `UIPanelCloseButton`, `UIPanelScrollFrameTemplate`
   stehen vorerst im Register).
2. **Widgets:** `W.Window`, `W.Inset`, `W.SelectBar`, `W.SectionHeader`, `W.SearchBox`, `W.Scroll`;
   neue Optik für `W.Button`, `W.Chip`, `W.Choice`, `W.Toggle`, `W.Stepper`, `editBox`, `W.EditArea`,
   `W.ScrollText`, `W.Card`, `W.Menu`, `W.Picker` (mit Ebene über 510); `W.List` mit Leiste und
   `opts.bar`; Rückfälle. `test_widgets.lua`, `test_arrows.lua`, Teil von `test_style.lua`.
3. **Hauptfenster und Registry:** Feld `group`, `ns.PANEL_GROUPS`; MainFrame.lua mit Geometrie oben,
   Statusleiste, Seitenliste mit Abschnitten und Einklappen, Inhaltsfeld 602 x 478, Reiter rechts,
   `ns.UpdateSideTabs`, Schließen-Fix; `group` in allen Seiten. `test_mainframe.lua`, Teil von
   `test_style.lua`.
4. **Raid-Seiten:** Übersicht, Raids, Raid-Log, Rolls, Vergaben (mit `W.SearchBox`), Soft-Reserves:
   `W.SelectBar`, Leisten nach der Regel, Konfliktleiste; Layout-Tests dieser Seiten.
5. **Übrige Seiten:** Ausrüstung, Karte, Export, Gildenbank, Werkzeuge, Einstellungen (Abschnitts-
   balken, `W.Scroll`), Über; Layout-Tests (`test_pages.lua`, `test_map_page*.lua`,
   `test_bis_page*.lua`, `test_settings_features.lua`).
6. **Nebenfenster:** Ausrüstungstabelle (Porträt, Klassenreihe ab x 64, Kopien entfernt),
   Roll-Fenster (Zeitanzeige, Knöpfe), Vergabe-Dialog, Soft-Reserve-Import (`W.EditArea`),
   Upgrade-Hinweis (`TooltipBackdropTemplate`); Hooks für die Reiter; Rest von `test_style.lua`,
   betroffene Tests (`test_rollframe.lua`, `test_award_dialog.lua`, `test_softres.lua`,
   `test_gear.lua`, `test_bis_score.lua`).
7. **Auslieferung:** Version 2.2.0 (TOC, `ns.VERSION`), alle Tests, unabhängige Prüfung
   (adversarial-review), Korrekturen, Commits. Speichern auf dem N100 ist die Auslieferung
   (Syncthing); keine neuen Dateien außer Lua, also genügt im Spiel `/reload`. Danach die Prüfliste
   aus "Offene Punkte" im Spiel.

## Auslieferung

Version 2.2.0. Commits lokal pro Aufgabe, nach der unabhängigen Prüfung Push. Keine neue Textur, keine
neue XML-Datei: `/reload` genügt (der PC muss an sein). Website, Export und Twin bleiben unverändert.

## Ideen und Später

Übernommen: Porträt, Titelleiste und roter Schließen-Knopf des Clients; Hintergrund und Listen-Atlanten
des Berufsfensters; Abschnittsbalken mit Einklappen; Leuchtbalken für gewählte Zeilen; dünne
Bildlaufleisten; Suchfeld mit Lupe; rote Aktionsknöpfe; Zahlenfeld mit Pfeilen; Reiter am rechten Rand.

Später:
- Item-Knöpfe des Clients (`ItemButton`, 37 px) für die Item-Felder der Ausrüstungstabelle und des
  Vergabe-Dialogs, mit Qualitätsrand (`SetItemButtonQuality`); braucht eine neue Anordnung dieser
  Fenster.
- Ein Filter-Knopf wie im Berufsfenster (`WowStyle1FilterDropdownTemplate` mit dem Menüsystem des
  Clients) statt der Chip-Reihen in Ausrüstung und Ausrüstungstabelle.
- Gamepad-Navigation über die Vorlagen (`FocusFramesInterfaceMixin`).
- Suchfeld über der Seitenliste, falls es einmal deutlich mehr Seiten werden.

## Nicht in 2.2

Neue Funktionen, neue Einstellungen, geänderte Texte (außer den Abschnitts- und Reiternamen und dem
Platzhalter der Suche), Minimap-Knopf und Schnellmenü (`W.Menu` bekommt nur die neue Optik), Pins und
Pfeil der Karte, Export, Website, Twin, Supabase, das Menüsystem des Clients, Berufs-Addons des
Clients laden.

## Offene Punkte

Nur im Spiel zu klären (Prüfliste nach dem `/reload`):

- **Atlanten vorhanden:** `/run for _,a in ipairs({"Profession-Background-Overview",
  "Professions-background-summarylist","Professions_Recipe_Active","Professions_Recipe_Hover",
  "common-insideframe","Professions-skillbar-bg","Professions-skillbar-frame","common-dropdown-b-button",
  "common-dropdown-b-button-open","common-dropdown-bg"}) do print(a, C_Texture.GetAtlasInfo(a) and
  "ok" or "FEHLT") end`. Fehlt einer, greift der Rückfall; der Name wird im Code ersetzt.
- **Hintergrund:** ob `Profession-Background-Overview` auf 806 x 560 (Hauptfenster) und 820 x 640
  (Ausrüstungstabelle) gestreckt gut aussieht. Wenn nicht: Fels-Kachel der Vorlage (`opts.background
  = nil`).
- **Rote Knöpfe bei 22 und 18-20 px:** Schrift lesbar, Ränder nicht abgeschnitten (`UpdateScale`).
  Wenn 18 px zu klein wirkt: Zeilenknöpfe 20 px.
- **Chips:** ob die `common-dropdown-b-button`-Atlanten auf 20 px mit `SetAllPoints` gut aussehen (der
  Atlas hat einen Schattenrand); sonst 2 px Überstand.
- **`common-insideframe`** auf beliebigen Größen (Karten 295 x 112, Inhaltsfeld 616 x 492,
  Seitenliste 176 x 492): Ecken nicht verzerrt (in Forever selbst gestreckt benutzt, etwa in der
  Wer-Liste).
- **Häkchen** `MinimalCheckboxTemplate` bei 18 x 18 (Vorlage 30 x 29, Atlasgröße): ob die Textur
  mitskaliert; sonst 22 x 22 und die Zeile prüfen.
- **Reiter:** Symbol mittig (Camelot-Versatz -4), Tooltip, Klemmen am Bildschirmrand.
- **Bildlaufleisten:** erscheinen nur bei Bedarf, Ziehen und Pfeile gehen.
- **Ebenen:** Picker-Feld im Vergabe-Dialog liegt über dem Rahmen; Inhalt am Rand wird vom
  Metallrahmen (Ebene 500) überdeckt, nicht umgekehrt.
- **Schließen im Kampf:** X im Kampf schließt alle fünf Fenster ohne "Aktion blockiert".
- **Taint:** `/console taintLog 1`, `/reload`, Fenster im Kampf öffnen, Seiten wechseln, Knöpfe
  drücken, schließen; danach in `Logs/taint.log` keine Zeile mit Amisia.
- **Suchfeld:** Platzhalter "Name oder Item" erscheint und verschwindet wie der alte Hinweis;
  Löschknopf leert und übergibt.
- **Abschnittsbalken:** Schrift `Game15Font_Shadow` passt in 164 px ("Ausrüstung" ist der längste).

Entschieden: Fenster 806 x 560 mit Inhaltsfläche 602 x 478; Seitenliste links mit vier
einklappbaren Abschnitten; Reiter rechts für Ausrüstungstabelle, Rolls und Soft-Reserve-Import;
Vorlagen des Clients erben, Berufs-Vorlagen nicht laden; `W.Button` rot (`SharedButtonSmallTemplate`);
eigenes Zahlenfeld statt `NumericInputSpinnerTemplate`; Einsätze mit `common-insideframe` statt
`InsetFrameTemplate`; Schließen-Knopf ruft `Hide` direkt; keine Item-Knöpfe des Clients in 2.2;
Rückfall auf das flache Aussehen, wenn eine Vorlage fehlt.
