# Changelog

What changed in each release of the Amisia addon, from the commit subjects.

## 2.10.0 (2026-10-08)

- Loot council: per item an officers' note and priority list (#AMISIA-LC from the site, in-game edit dialog, LC export lines), shown in the roll window, award dialog, tooltip, roll frames and optionally the loot announcement, shared by the keeper (LV/LQ/LC, verified officers only)
- Site: Loot Council tab (prio and note per item, kept per game in state.lootPrio), the #AMISIA-LC block in Copy for the addon, the addon's LC lines taken over on the Import tab, backups keep it
- Group loot roll log: Need/Greed/Disenchant/Pass, numbers and winner per item, in the raid or a dungeon run
- Guild crafters: share known recipes in the guild (PV/PQ/PW, PK blob), "Hergestellt von" on the professions page, a "Gilde" filter, an ask-by-whisper button and a "Kann herstellen" tooltip line
- Statistik page: items won (MS/OS/SR), items per raid, attendance since first seen, bosses seen, streak and items per week per player over all characters, ranges 4 weeks/phase/all, class and role filters, sortable columns, hall of fame; raiders see their own row. Page list rows 20 high so 18 pages fit
- Site: Stats tab with loot and attendance per player (alts counted for their main, the bench rule of the Attendance tab), ranges, class and role filters, sortable columns, items per week and the hall of fame
- att_data: library books folder, quest givers of a header (aqd/hqd), quest maps, newer map constants
- Guild bank: needs with pledges and the guild bank log
- l10n: Item/Items only once (the stats page and the raid area both added them)
- Site prio test: the copy block's date is today, not a fixed day
- Mage scrolls: Comprehension page for mages (/amisia schriftrollen) from the client tables and AllTheThings
- Crafters: a sender speaks only of itself and its known alts; lists keep only indexed spells; caps per sender and for the store
- Bank needs: pledges only for needed materials, capped per name; a cleared list reaches who missed it; no revision from the future
- Loot prio dialog: the order field holds a whole list; the test stub enforces SetMaxLetters
- Bank log: rows older than bank.logDays are skipped, not counted as new on every open
- Loot prio: times more than a day ahead are refused (paste, site import); the LC list goes at the lowest priority; site prio names count bytes, a damaged prio renders
- Group roll log: one row per player, whatever spelling a roll line uses
- SelfTest: the guild bank log functions are optional; drop the unused ns.LootAnnounceAgain

## 2.9.6 (2026-10-07)

- Collector: a vendor price of 0 is unknown - a real price replaces it (prices recorded while the merchant API was missing stayed 0 forever)

## 2.9.5 (2026-10-07)

- Talents: 36 px icons, the frame 2 px outside the icon so its dark rim no longer covers it, less icon crop

## 2.9.4 (2026-10-07)

- Map: the main window stays open under the world map and comes back on top when the map closes

## 2.9.3 (2026-10-07)

- Talents: 34 px icons again, the action bar's thin rounded frame tinted by state

## 2.9.2 (2026-10-07)

- Questgeber-Wegpunkte und Pins nur aus eigenen Beobachtungen: Dungeon-Guide nimmt CollectQuestOwnStart, Berufe-Orte von der Gilde ohne Wegpunkt; Tests zuerst
- Talents: nodes as the client draws them - 30 px icon with the action bar's rounded mask, the state frame at 1.25x, room between neighbouring frames
- Quellen-Austausch schneller: 192 KB je Sitzung, halber Anteil je Fragendem, 120 Teile je 10 Minuten, ein Blob je 30 s, 90 Anfragen je Stunde, Ansagen eine Stunde gültig; Flusstest mit neuen Erwartungen und zwei Absendern je Stunde, Zahlen in der Spezifikation
- Händler im Sammler über C_MerchantFrame.GetItemInfo (Forever 1.60.1.70245 hat GetMerchantItemInfo nicht mehr), alte Funktion als Rückfall; Selbsttest: GetMerchantItemInfo optional, C_MerchantFrame.GetItemInfo nötig
- Lagerbeschreibung: Zauberdaten anfordern (C_Spell.RequestLoadSpellData), bei SPELL_DATA_LOAD_RESULT nachtragen, bis dahin "Beschreibung lädt ..."; Selbsttest meldet "noch nicht geladen" als WERT statt FEHLT, SPELL_DATA_LOAD_RESULT in der Ereignisliste

## 2.9.1 (2026-10-07)

- Data rebuilt from the user's own client export (talents identical, profession reagents from SpellReagents); build_talents accepts the export's Index column

## 2.9.0 (2026-10-07)

- Locales: ns.L with German keys and English for every other client locale (Locales/Locale.lua, enUS parts), ns.Num/FmtDay/FmtDate, N_ marker; English slash words (def.en, collisions are errors); run.py --locale enUS (text assertions shown, Lua errors and missing texts fail), tools/l10n.py scan/check, layout rules in deDE and enUS, build.py check runs both
- WIP l10n: partial English routing gathered from the area worktrees (SelfTest.lua mid-edit, not yet green)
- l10n: core, window, settings, overview, export, bank, tools, about and the self-test in English
- l10n: the raid area in English (awards, rolls, soft-reserves, raid log, bench, sync, announcements and chat in the sender's language)
- l10n: gear, BiS, dungeons, map, quests, professions, talents and the collector in English
- l10n: GuildWishes delete button uses the button key; README section on languages, CLAUDE.md note

## 2.8.0 (2026-10-07)

- UI snapshots and layout rules: the stub keeps the frame tree (kids, font objects, word wrap, the addon's own Show/Hide, template parts), GetStringWidth estimates per character and font (addon/tests/textwidth.py, shared with the rules); addon/tests/uidump.lua hands the tree over as JSON, addon/tests/ui_scene.lua is the world the shots show; tools/ui_layout.py solves the anchors, checks bounds, overlap, text fit, minimum widths, atlases and the page list, draws PNGs with an index.html and compares layout boxes
- UI/Theme.lua: the design tokens in one table (sizes, gaps, chip and button heights, padding, header and row heights, the main window's insets, card, menu and picker measures, font objects, colours, the atlas allow-list); Widgets, MainFrame, the pages and the side windows read them instead of literals. Layout helpers W.Row (from the left or the right edge, own gaps and offsets), W.Column, W.Grid and W.FitChip; the gear page's head and source chips, the dungeon sorts and parts, the simulation pickers, the quests, professions and talents heads, the settings rows, the overview cards and the gear window's spec chips use them. Every page and window lays out exactly as before (tools/ui_layout.py --compare: no box changed)
- Layout fixes the rules found: the gear page's Warum?/Simulation buttons overlapped the first option by 2 px (now 20 high between the list and the options); "Aus" sized to its text (36 -> 38 px, both buttons from the row's end); the weapon plan pickers cut "Waffen: automatisch" (128 -> 132 px on the goals, 124 -> 132 in the simulation); the talent rank text stuck 1 px out of the page in the fourth column (30 -> 26 px, the plate's width); the Merchant's Favor hint lost its end (680 px in 598: now two lines, the data line follows it); the roll window's "Vergeben" (64 -> fits, the winner mark 48 -> 44 px) and MS chip, the award dialog's MS/OS/SR chips (28 -> fit, picker 140 -> 136, gaps 2) and the gear window's source chips (Weltdrops 62 -> 64) sized to their text with W.FitChip. Snapshot text sits on its baseline
- build.py: check runs the layout rules of every page and window (step "layout rules"), snapshots draws them into PNGs with an index.html (--out, --compare, --scale, --mono); tools/tests/test_ui_layout.py tests each rule on a made-up tree, the anchors, the drawing and the comparison; README section on ui_layout.py, CLAUDE.md on the theme, the helpers and the snapshot comparison
- Lazy data: GearData, MapData, QuestData, ProfessionData and TalentData hand their table to ns.LazyData as one long string with the generator's count of entries (tools/lua_data.py lazy(), called by build_gear, build_map, build_quests, build_professions and build_talents; eager() and load() for the tools and tests that read a data file); Core/LazyData.lua builds a table on its first use (ns.Data, or a read of ns.KEY), ns.HasData and ns.DataSize answer availability checks without building, an assignment replaces what waits, ns.DropData lets go. Every consumer reads through ns.Data; Gear.Available, the map, professions and talents checks and the quest switch build nothing. In the stub the addon load drops from 98 ms and 8.3 MB to 59 ms and 5.7 MB, nothing is built at login, the first use costs 1-13 ms (tools/load_cost.py). Quests and professions rebuilt by their generators; map, gear and talent data put in the same form from the committed files (the N100's newer ATT cache and the missing Trait tables would change their content)
- Snapshots: a list cell wider than its column ends in an ellipsis where the client cuts it

## 2.7.1 (2026-10-07)

- Addon in folders: Core/, Raid/, Gear/, Collect/, Data/ (every generated file), UI/ and UI/Pages/ (git mv, TOC order unchanged); build scripts, tests, syntax.cjs (recursive) and the LICENSES head on the new paths
- Version only in the TOC: Core reads ## Version through C_AddOns.GetAddOnMetadata (fallback GetAddOnMetadata); the test stub answers from the TOC, test_version_toc covers the fallback and the missing literal
- luacheck: .luacheckrc (lua51, the client globals the addon reads, its own global writes) and its findings fixed without behaviour change: helpers shadowed by locals renamed (Sync isList, Collector rewardList, SoftRes splitLines), unused locals, captures and the dead Drops report() removed
- tools/build.py: one entry point - data (the builds in order, skips without client tables, diff summary), check (syntax, addon and tool tests, UTF-8, TOC against the folder, luacheck) and release (clean tree, TOC version, check, zip, CHANGELOG.md, commit, push, release_addon.sh; undone on failure); tests with a temporary repository; README and CLAUDE.md
- GitHub Actions: check.yml runs tools/build.py check (Python with lupa and pytest, node with luaparse, luacheck from apt) on push and pull request; deploys nothing, Pages unchanged
