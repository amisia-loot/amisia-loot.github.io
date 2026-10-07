# Tools

## build.py

The one entry point for the addon's data, checks and releases. It needs `lupa` and `pytest`; when
the Python that starts it has no `lupa`, it starts again in `~/.venvs/amisia`, so on the N100
`python3 tools/build.py ...` is enough.

```
python3 tools/build.py data [--sv FILE] [--wago DIR] [--refresh-att]
python3 tools/build.py check
python3 tools/build.py release X.Y.Z [-m "summary"] [--no-push] [--no-copy]
```

- `data` runs the data builds in dependency order: `build_dungeons.py --wago`, `build_gear.py`,
  `build_map.py`, `build_dungeonquests.py`, `build_quests.py`, `build_professions.py`,
  `build_talents.py`, `build_dungeonart.py --wago`, `build_bis.py`. It stops at the first build
  that fails and ends with `git diff --stat` of `addon/Amisia/Data` and `tools`. `--wago` is the
  folder of the client tables (default `~/addons/_wago`); professions and talents are skipped with a
  note naming the missing tables (export them on the PC with `tools/export_db2.ps1 -Tables ...`),
  dungeons and dungeon art fall back to their kept snapshots. `--sv` goes to `build_gear.py` and
  `build_bis.py` (default: what each finds, e.g. `~/addons/_SavedVariables/Amisia.lua`);
  `--refresh-att` downloads the AllTheThings data first. Nothing is ever downloaded from wago.tools.
- `check` runs `addon/tests/syntax.cjs`, `addon/tests/run.py`, `pytest tools/tests` (which holds the
  "generated file is current" checks), a UTF-8 check of every addon text file (no byte order mark),
  the TOC against the addon folder (every listed file exists, every `.lua`/`.xml` is listed) and
  luacheck with `.luacheckrc`. One line per step; the exit code is 1 when one fails. A missing
  node/luaparse or luacheck is reported as `skip`.
- `release X.Y.Z` refuses a dirty tree (and untracked addon files), a version that is not newer and,
  unless `--no-push`, a branch other than main. It sets `## Version:` in the TOC (the only place the
  version stands; `Core/Core.lua` reads it with `C_AddOns.GetAddOnMetadata`), runs `check` and puts
  everything back when it fails, builds `addon/Amisia.zip` (tracked files under `Amisia/`, no
  dotfiles), adds the commit subjects since the last `Amisia X.Y.Z:` commit to `CHANGELOG.md`,
  commits `Amisia X.Y.Z: <summary>` (default summary: those subjects), pushes `origin main` and runs
  `tools/release_addon.sh`. `--no-push` and `--no-copy` leave out the push and the copy.

### luacheck

`.luacheckrc` in the repo root: Lua 5.1, the client globals the addon reads (`read_globals`), the
globals it writes (`AmisiaDB`, `SLASH_AMISIA1`, `AmisiaMapPinMixin`, the compartment callbacks,
`SlashCmdList`, `StaticPopupDialogs`). A new client API in the code needs its name in
`read_globals`. On the N100 luacheck 1.2.0 runs from the Debian packages unpacked without root into
`~/.local/luacheck` (`apt-get download lua-check lua5.1 liblua5.1-0 lua-filesystem lua-argparse`,
`dpkg -x` each into that folder) through the wrapper `~/.local/bin/luacheck`. GitHub Actions
installs `lua-check` with apt.

## Addon layout

`addon/Amisia/`: `Core/` (registry, core, names, chat queue, comm, trust, version, minimap button,
selftest), `Raid/` (alts, materials, awards, rolls, soft-reserves, loot lead, raid log, bench, sync,
raid text, need), `Collect/` (item scan, collector, drops and their guild exchange, quest XP),
`Gear/` (gear planner, BiS, dungeons, professions, quests, talents, guild wishes, comparison marks,
map and map pins), `Data/` (only generated files, from the build scripts below), `UI/` (widgets,
main window) and `UI/Pages/`, plus `Media/` and `LICENSES/`. The TOC loads them in dependency
order; `build.py check` fails when a file is missing from it.

## build_scan.py

Builds `data/forever.js`, the loot tables for World of Warcraft: Forever, from what the Amisia
addon saved.

1. In game, outside any instance: `/amisia scan 1 250000` (takes a while; `/amisia scan status`
   shows progress, `/amisia scan stop` pauses, `/amisia scan` resumes). Then log out so the
   client writes the file. On the Forever beta the file is written at logout but not read back,
   so a scan has to finish within one session.
2. Run the build with every officer's file that holds raid sessions:

   ```
   python tools/build_scan.py "C:/Program Files (x86)/World of Warcraft/_classic_beta_/WTF/Account/<account>/SavedVariables/Amisia.lua"
   ```

   `--no-icons` skips the Wowhead lookups and the sprite. `--out` changes the target.
   `--catalog` also lists every scanned epic (and rare from item level 60, `--catalog-ilvl`) without
   an observed drop under the boss "Unknown source", so loot can be awarded before the boss tables
   exist. `--listfile <community-listfile.csv>` (from wowdev/wow-listfile) names the icon file ids
   of the scan; the ones used are cached in `tools/icon-fileids.json`. `--no-wowhead` never asks
   Wowhead, which does not know Forever items.
3. Read the warnings: add unknown instances to `tools/forever_zones.json`, mark trash sources
   or rename bosses in `tools/forever_bosses.json`, run again.
4. Bump `BUILD_ID` in `index.html`, so browsers fetch the new `data/forever.js`, then commit and
   push. The `forever` entry of `GAMES` already points at the file.

The boss loot tables grow with the raids: every item that lay in an opened loot window is
listed under its source. Requires `lupa`; icons need `Pillow` and internet access.

### Drop records of the guild

The addon records every boss kill whose loot window a guild member opens in a dungeon or raid
(no player names) and shares the records in the guild. `build_scan.py` keeps all of them for good in
`tools/drop_obs.json` (committed) and writes the loot tables per boss into `data/forever.js`
(`obsBosses` with kills and per item the kills that had it, `obsZones`, `obsItems`, and
`obsThrough`, the newest day in the archive; the site adds only the kills it imported after it).
The records come from:

- the SavedVariables given for a full build (`drops.k`);
- `--drops <file>`: the addon's text "Drops für die Website" (`/amisia drops export`), saved to a file;
- `--obs <file>`: the site's "Download observations" (Loot Tables tab, editors only).

Without SavedVariables on the command line only the observations change: the records of
`~/addons/_SavedVariables/Amisia.lua` (when Syncthing brings the file to the N100), `--drops` and
`--obs` go into the archive and the observation keys of `data/forever.js` are replaced in place; the
item catalog of the last full build stays. This needs no WoW install and no client tables, so it
runs on the N100:

```
python tools/build_scan.py --obs amisia-drop-obs-2026-10-20.json
```

The file is rewritten only when the tables change; then bump `BUILD_ID`.

Tests: `python -m pytest tools/tests -q`.

## att_data.py

The shared reader of AllTheThings' hand-kept WoW Forever data for `build_gear.py`, `build_map.py`
and `build_dungeonquests.py`: the folder `.contrib/.db/forever` of
https://github.com/ATTWoWAddon/AllTheThings, MIT licence (Copyright (c) 2026 AllTheThings WoW Addon;
the licence text ships in `addon/Amisia/LICENSES/AllTheThings-MIT.txt`, approved by the user on
2026-10-06).

- `--refresh-att` (on each of the three builds) downloads through the GitHub API (the token of `gh`)
  into `~/addons/_cache/att`, outside the repo, with the commit in `COMMIT`: the Forever dungeons
  and zones, the Classic folders not yet moved (`zzOLD/01 - Dungeons Raids`, `zzOLD/02 - Outdoor
  Zones`), world drops, PvP gear, crafted items, the map constants, the item export
  `.config/exports/ItemDB.lua`, the client tables `UiMapAssignment`, `AreaTable`, `ContentTuning` and
  `SkillLineAbility` ATT ships, and for `build_professions.py` the recipe lists
  `.config/structures/` and `profession db/` (that build reads them itself, `load()` does not).
- Client tables (wago.tools CSV downloads) are read as `<Table>.csv` or `<Table>.<build>.csv`, the name
  wago.tools gives them (`UiMapAssignment.1.60.1.70235.csv`); of several builds in one folder the newest
  counts (`wago_csv()`). The user's folder `~/addons/_wago` comes first, ATT's copies second.
- The files are a Lua builder language. They run in a sandbox (lupa without its python bridge, an
  environment of a few safe functions, no `io`, `os`, `load`, `require`, `debug`) with stand-ins
  that only record what they are given. ATT's preprocessor (`-- #if SEASON_OF_DISCOVERY` ...) is
  applied first with the Forever build's tags; timelines decide what is in Forever 1.60.1 (an
  addition with Cataclysm or only in the 1.15 Era/SoD branch is not). Names come from the comments.
- Out comes one neutral form (see `load()`): quests (minimum level, faction, classes, givers with
  points, start object or item, pre-quests, rewards, zone, dungeon), NPCs (name, title, points,
  zone, faction, kind: boss, rare, vendor, giver, mob), boss and rare drops, zone drops with their
  mobs, vendor stock, world drops, PvP gear per faction, crafted items per profession, the items of
  the export, instances (name, area id, uiMaps, entrance, instance map id). A record of a Forever
  folder wins over the same quest or NPC in a zzOLD folder.
- What ATT does not give: a quest's own level (the minimum level stands in), NPC levels, recipe
  skill levels, spawn points of mobs it only names, measured entrances of some dungeons (the new
  ones carry the middle of their zone, which `build_map.py` does not take), and instance map ids
  of dungeons. Those come from the client tables: `UiMapAssignment` (uiMap -> instance map; Forever
  1.60.1's table holds the outdoor zones and battlegrounds only), then `AreaTable` (an area's
  `ContinentID` is the instance map for an area inside an instance; ATT gives the outdoor area of some,
  as Gnomeregan's in Dun Morogh, so those are found by the client's name of the instance). With ATT's
  `AreaTable` of 1.60.1.70170 every ATT instance but Onyxia's Lair (249 from the facts) has its id.

Tests: `tools/tests/test_att_data.py` on the hand-made fixture `tools/tests/fixtures/att`.

## build_gear.py

Builds `addon/Amisia/Data/GearData.lua` for the addon's gear window (`/amisia gear`, WoW Forever only):
every item a levelling character can wear and where it comes from. The stat weights
(`GearWeights.lua`) are Amisia's own and come from `build_bis.py`.

```
python tools/build_gear.py [--att DIR] [--refresh-att] [--wago DIR] [--sv FILE...] [--no-wowsrc] [--itemsparse CSV|DIR]
```

- What an item is (slot, armour or weapon type, required level, quality, bind, class limits): the
  Amisia item scan where there is one (the scan dumps in the repo root,
  `~/addons/_SavedVariables/Amisia.lua`, the installed Forever client's SavedVariables, or `--sv`),
  else what the last `GearData.lua` said (earlier scans; a quest-only item's level is set again from
  the quest), else ATT's item export. The stats (`ST`) are the scan's, else the last build's, so a
  rebuild without SavedVariables loses none.
- Where it comes from (`att_data.py`): quest rewards (minimum level, faction, zone, class limits,
  dungeon), boss drops per dungeon, rares, vendors (PvP rank quartermasters as `P`), zone drops
  (trash inside a dungeon, the named mobs outside), world drops, PvP rank gear, crafted items (the
  profession; the skill is 0 = unknown unless AtlasLoot or OneForAll name it); and the Amisia item
  collector (drops, merchants, quests, the auction house as players met them; German names).
- Optional, PC only, skipped with a note when missing: OneForAll (Forever dungeons, dungeon quests,
  Merchant's Favor recipes), AtlasLootClassic (Forever dungeon tables, Classic recipes with skill).
- wowsrc.com dungeon pages (drop chances) are kept in `tools/gear_wowsrc.json`;
  `--refresh-wowsrc` downloads them again, `--no-wowsrc` leaves them out.
- In game, `/amisia scan gear` (outside instances) asks the client for every item the planner lists
  plus the ids its sources name but no item table knows (`M` in GearData.lua, items Forever still
  hides until they are revealed). It stores each item's stats too. Log out, rebuild: the stats go
  into `GearData.lua` (`ST`), so the window needs no loading, and newly revealed items join.
- Items without scanned stats are read from the client when the window opens.
- The collector notes drops with NPC id and dungeon (`Drop: <mob> [<npcID>] @<place> #party:<instanceID>`)
  and quest rewards with quest id and the player's level, so the new Forever dungeons and quests fill
  in as the guild plays. Pass every officer's SavedVariables with `--sv` to merge them.
- The source collector (`AmisiaDB.collect`, `Collector.lua`, shared in the guild by `CollectSync.lua`)
  records quests (giver and turn-in NPC with places, rewards, choices, quest level, the lowest player
  level offered, faction), vendors (gear, recipes, limited goods) and drops of non-boss NPCs.
  `build_scan.collect_observed` reads it; `build_gear.py` uses it below ATT (a quest or NPC ATT knows
  keeps ATT's record, the observation adds what ATT lacks), `build_scan.py` adds it to the site's
  `via` line and the field drops.
- Vendors, rare mobs and named mobs carry the NPC id as their last field (V and P at 7, R at 5, W
  at 6), from ATT or the collector's `[npcID]`; `Gear.lua` does not read it, `build_map.py` keys the
  map points by it.
- Dungeon sources carry the instance id and area id, so the gear page can find "here" through
  `GetInstanceInfo()`. The area id is ATT's; the instance id comes from the `UiMapAssignment` and
  `AreaTable` client tables (`--wago`, default `~/addons/_wago`, then ATT's copies),
  `tools/forever_dungeons.json` with `tools/forever_dungeons_client.json`, or the collector's drop
  notes. Without one the dungeon is found by its English name only.
- `--itemsparse` takes the CSV or a folder with `ItemSparse[.<build>].csv` and rewrites
  `tools/gear_itemsparse.json` from it; ids the export does not hold lose their entry, so compare
  first (the 1.60.1.70235 download holds about 1,750 of the 2,340 cached weapon speeds and agrees on
  every one it has).
- Dungeon names are those of `tools/forever_dungeons.json` (ATT's and the other sources' spellings
  map to them through the names and aliases there).
- Forever raids: drops the site recorded in `data/forever.js` for a zone that
  `tools/forever_zones.json` marks `"raid": true` (with `"instance"` and `"area"` where known) become
  raid sources (`X`). Mark a new Forever raid there once the site has its loot, then rebuild.
- `GearData.lua` carries `game = "forever"`, `cap = 60`; it and `GearWeights.lua` are loaded through
  the TOC condition `[AllowLoadGameType camelot]`.

Runs on the N100. On the PC it also takes the scan and the PC-only sources. `AMISIA_WOW_ROOT`
overrides the WoW install path. Requires `lupa`.

Licences of the data: AllTheThings MIT (`GearData.lua`, `MapData.lua`, `DungeonQuestData.lua`;
`addon/Amisia/LICENSES/AllTheThings-MIT.txt`), AtlasLootClassic GPL-2.0 when used (to be checked in
the installed folder), wago.tools
exports and ATT's item export are Blizzard's game data (`gear_itemsparse.json`). Still open:
OneForAll's licence (check its installed folder on the PC) and wowsrc.com, whose pages state no
licence (its robots.txt allows crawling, which is not one); `--no-wowsrc` leaves it out. No QuestieDB
data: it has no licence.

## build_map.py

Builds `addon/Amisia/Data/MapData.lua` (WoW Forever) for the map: where each source of the gear data
stands, as up to four points `uiMapID:x:y` (x, y in hundredths of a percent) under a stable key per
source (`Q:<quest id>`, `V:`/`R:`/`W:<NPC name>`, `U:<NPC id>`, `I:<instance id>`,
`N:<dungeon name>`).

```
python tools/build_map.py [--att DIR] [--refresh-att] [--wago DIR]
```

- Places come from ATT's data (`att_data.py`): a quest's coordinates (where its giver or start
  object stands, else its givers' points), an NPC's own coordinates, those of the quests it gives,
  or for a mob only a drop names the drop's coordinates; dungeon and raid entrances from the
  instances' coordinates. A point on a dungeon's own map stands for its entrance; an entrance given
  as the middle of its zone (50, 50) is not measured and is left out.
- Which keys are needed comes from `GearData.lua`: quests by their quest id (quests started by an
  item have no place), vendors, rare and named mobs by NPC id or by name (an NPC in the source's
  zone wins, names found in several zones are reported), raids and dungeons by instance id (matched
  through the `UiMapAssignment` table) or by name.
- Several points: points within 2 % are one, then the four farthest apart are kept.
- The file is loaded through the TOC condition `[AllowLoadGameType camelot]`. Keys are sorted, so a
  second build gives the same file.
- The report lists per source kind how many have a place, ambiguous names, instance ids the data
  cannot place and quests without a place.

Runs on the N100 (no WoW install needed). Run it after every `build_gear.py`, then commit.
Requires `lupa`.
## build_dungeons.py

Builds `addon/Amisia/Data/DungeonData.lua` (`ns.DUNGEON_FACTS`, loaded through
`[AllowLoadGameType camelot]`) from `tools/forever_dungeons.json`, the hand-kept facts of the dungeon
planner: every dungeon and raid of WoW Forever with its level range, size, bosses known so far,
opening date and instance id where known. Facts only, never a loot table or a drop chance; every
entry names its source in `src`, explained in the file's `sources` block with the date of the check.

```
python tools/build_dungeons.py [--wago [DIR ...]]
```

- `--wago` reads the client tables (default `~/addons/_wago`, then ATT's copies in
  `~/addons/_cache/att/.config/.wago`) and rewrites `tools/forever_dungeons_client.json`: per dungeon of
  the facts the level the client tunes it to (`LFGDungeons` -> `ContentTuningID` -> `ContentTuning`
  `MinLevelSquish`, read by `tuning_levels`, which `build_bis.py` uses too) and its instance id
  (`AreaTable`). Forever's `LFGDungeons` (1.60.1.70235) has no level range, map or group size of its own; the tuning level is one number, the low end of the range
  (it equals the public minimum of Hall of Thanes, Ruins of Lordaeron, Excavation Site and City of
  Dalaran). Without `--wago` the JSON file is used as it is.
- The hand facts win: the client's values fill only what `forever_dungeons.json` leaves open (`lvl`, and
  `inst` where the facts have none); differences are printed. The addon takes `lvl` as the low end of a
  dungeon without a fact range and the required levels of its items for the high end ("~16-20").

- Forever's new dungeons and raids: public facts (Blizzard's announcements, the public dungeon list),
  checked by hand. Onyxia's instance and area id from `tools/forever_zones.json`.
- Classic dungeons: the names the repo's own data uses (`GearData.lua` dungeon sources and dungeon
  quests, `MapData.lua` entrances). Their level ranges stay empty in the facts; the client's level
  (`forever_dungeons_client.json`) and the required levels of the dungeon's items give an estimate,
  marked with "~".
- `build_bis.py` writes `ns.BIS.DG` (the same facts, with the bosses' NPC ids); the planner takes
  that table. This file stays as the fallback without `BisData.lua`.

Runs anywhere, no network. `tools/tests/test_build_dungeons.py` checks that the Lua file is current.

## build_bis.py

Builds `addon/Amisia/Data/GearWeights.lua` (Amisia's own weights, `ns.GEAR_WEIGHTS`) and
`addon/Amisia/Data/BisData.lua` (`ns.BIS`, `[AllowLoadGameType camelot]`). Runs on the N100, no WoW
install, no network:

```
python tools/build_bis.py [--wago ~/addons/_wago] [--measured tools/bis_measured.json]
                          [--werte "AMISIA-WERTE level=60 class=ROGUE agi=300 crit=10.3 cr_CRIT=28:2"]
                          [--sv ~/addons/_SavedVariables/Amisia.lua] [--att DIR] [--no-att]
                          [--picks tools/bis_picks.json]
```

Inputs:

- **Client tables** (CSV in wago.tools' format: `tools/export_db2.ps1` exports them from the WoW
  install on the PC, or they are downloaded by hand from wago.tools; Syncthing brings them to
  `~/addons/_wago`, files `<Table>.<build>.csv`; never committed). Read when present: `ItemSparse`,
  `Item`, `RandPropPoints`, `ItemSet`, `ItemSetSpell`, `SpellEffect`, `SpellItemEnchantment`,
  `LFGDungeons`, `ContentTuning`, `DungeonEncounter`, the damage tables `ItemDamageOneHand(Caster)` and
  `ItemDamageTwoHand(Caster)`, the armour tables `ItemArmorQuality`, `ItemArmorTotal`, `ItemArmorShield`
  and `ArmorLocation`, and the effect tables `ItemXItemEffect`, `ItemEffect`, `SpellName`, `Spell`
  (tooltip text) and `SpellMisc` (school). The used columns and rows go to `tools/bis_gamedata.json`
  (committed; items: the planner's items and the picks, with stats or not); without CSVs the build
  runs from that file. Forever has no `ItemRandomProperties`, `ItemRandomSuffix` or `gt*` table, and
  its `Journal*` tables are empty (1.60.1.70235). `ContentTuning` is read through
  `build_dungeons.tuning_levels` (one reader for both builds).
- `addon/Amisia/Data/GearData.lua` (items, sources, scanned stats; read only), `tools/forever_dungeons.json`
  (with the client's level and instance id of `build_dungeons.client_facts`, from the CSVs of this
  build when they are there, else `tools/forever_dungeons_client.json`), AllTheThings' Forever data
  (`tools/att_data.py`, MIT) for the bosses' NPC ids per dungeon, `tools/drop_obs.json` for the drop
  base stock, and the SavedVariables: the random suffixes the collector saw (`scan.suffix`) and the
  item scan (`scan.items`) of planner items and picks GearData.lua has no `ST` for (the check below).
- **Conversions** (agility and intellect per percent crit, rating per percent, mana per spirit) are
  documented defaults in the script (Classic's values; the level curve of ratings is TBC's). In-game
  measurements correct them: `tools/bis_measured.json` holds `samples` (raw values, e.g. from the
  self-test's `AMISIA-WERTE` line via `--werte`: `level`, `class`, `agi`, `int`, `crit`, `spellcrit`,
  `cr_<KIND>=<rating>:<bonus %>`) and optional `overrides` (`rating60`, `agiPerCritScale`,
  `intPerCritScale`, `manaPerSpirit5`). A measurement corrects a class's curve by its ratio.
  Only finite numbers count (`nan`, `inf`, `1e400` are dropped); a `--werte` line without a known
  class or with a level outside 1-60 is refused before the file is written (exit 2), and such a
  sample already in the file is skipped with a warning.

What it does:

- **Weights** per spec and level bracket (the 12 columns of the planner, Speedrun and Hardcore) from
  game mechanics: physical damage (white swings plus weapon specials, crit, hit, weapon speed above
  a reference speed), spell damage and healing (a reference spell per spec, coefficient, crit, hit,
  mana while it runs short), tanks (effective health; threat at 15 %). The reference character of a
  bracket wears the best gear of the bracket's entry level under these very weights (fixpoint with a
  shrinking step; the build stops when a weight does not settle within 1 %). Every spec has a unit,
  a German reason (`why`) and its reference values (`ref`) for "Warum diese Gewichte".
- **Computed stats** (`SC`) of items no scan has seen (`full_stats`): ItemSparse's allocations times
  RandPropPoints' budget; the **armour** (quality factor of `ItemArmorQuality` x the material's
  `ItemArmorTotal` of the item level x the slot's `ArmorLocation` share, rounded, a robe counts as a
  chest; shields their `ItemArmorShield` value, no quality factor; plus the extra armour of the
  allocations, which rings and weapons have alone); a **weapon's damage per second** (DPS of the
  `ItemDamage*` table of its kind, level and quality; average hit = DPS x speed, minimum floored,
  maximum rounded with `DmgVariance`, DPS = (min + max) / 2 / speed); a **caster weapon's spell power**
  (`Flags_4` & 0x200: 2 x the RandPropPoints budget of column 0; & 0x400, healing weapons: spell damage
  floor(2b x 0.625) and healing floor(2b x 1.88)); and the plain stats of **equip effects** (auras of
  attributes, armour, attack power, spell damage and healing, mana per five, spell penetration, percent
  hit and crit as level-60 rating). What Forever's base data does not say, measured on 2026-10-06
  against the scans (`DMG_FACTOR`): its caster tables are copies of the melee ones, the client's caster
  damage is 2/3 (one-hand) and 0.7435 (two-hand) of them (a caster table of its own, as an export with
  the hotfixes might have, is taken without a factor); bows, guns and crossbows 0.6 of the two-hand
  table, thrown weapons 0.9 of the one-hand table; wands follow none (no damage, no `SC`).
  **The check:** the same computation for every scanned item the tables know, compared as Gear.lua
  scores (damage to a thousandth), per kind (`item_kind`); a kind gets `SC` only when at least 98 % of
  at least 10 scanned items come out exactly. 2026-10-06 (1.60.1.70235, 2,021 scanned items the tables
  know, 99.8 %): armour 1,379/1,379, shields 60/60, jewellery 148/150, trinkets 15/15, melee weapons
  306/307, caster weapons 44/44, bows, guns and crossbows 59/60, thrown 6/6 (too few: no `SC`), wands not
  checked. The misses: common-quality items (RandPropPoints has no budget for them) and one bow of
  item level 5 (the ranged factor misses the lowest levels). The item scan covers most planner items,
  so `SC` holds the pick (Rage of the Storm: its damage, intellect and stamina) and items without a
  scan to come.
- **Effects** (`FX`, item -> German text) the scoring does not count, for the planner's items and the
  picks: `ItemXItemEffect` -> `ItemEffect` (trigger 0/5 "Benutzen", 1 "Anlegen", 2 "Chance bei
  Treffer") -> the spell's name (`SpellName`, English) and what its effects plainly say
  (`SpellEffect`, school from `SpellMisc`: "176 Feuerschaden", "+10 % Schaden: Stormstrike" with the
  ability named in the spell's tooltip text, a proc's triggered spell). An equip effect of plain stats
  goes into `SC` instead; an effect whose spell has no tooltip text (a hidden condition of another
  effect) is left out. No proc value: chances and durations are not in the exported tables
  (`SpellAuraOptions`, `SpellDuration`), so a proc stays unscored and named.
- **Encounters** (`EN`, encounter id -> boss NPC id): `DungeonEncounter` names matched to the
  dungeons' bosses (`bossNames`; a name two dungeons share by the encounter's map = instance id).
  A drop record known only by its encounter (NPC 0) counts under that boss in the base stock (`O`)
  and in the addon (`ns.DropsBossOf`: rates, the boss list, the dungeon planner).
- **Dungeon levels:** `LFGDungeons` -> `ContentTuning` gives Forever's dungeons one level each
  (MinLevelSquish = MaxLevelSquish); that is `lvl` (the low end), not a range. `DG`'s `min`/`max` take
  the client's values only where a table has a real range (none in 1.60.1.70235).
- **Sets** (`SET`), **random suffixes** seen on links (`RP`), **dungeons** (`DG`: the facts with
  `bosses` as NPC ids and `bossNames`), the **drop base stock** (`O`, `OT`, `OI`) and the **effort**
  per source kind (`EF`).

**BiS picks** (`tools/bis_picks.json`, hand-kept): best-in-slot items the stat scoring alone misses
(procs, equip effects), each with `class`, `spec` (the key of `SPECS`, e.g. `SHAMAN`/`enh`), `from`/`to`
(level range), `slot` (a planner row: `HEAD` … `MAINHAND`, `OFFHAND`, `RANGED`, `FINGER1`, `TRINKET2`),
`item`, a German `note` and an optional `source` (default "Quelle unbekannt"). The build checks every
pick (known spec, item in ItemSparse and the Item table, the item's inventory type fits the row, the
class can carry it at the range's end, its required level is not above `from`, no two picks of one spec
and row overlap) and stops with exit 2 before writing anything when one fails. `extract` keeps the
picked items' rows (name, slot, quality, item level, required level, bind, speed, class and subclass,
classes, stat allocations) in `bis_gamedata.json`, so later builds need the CSVs only for a new item.
It writes `PICK` (the picks) and `PI` (GearData's row, no sources, plus `name`, for picked items
GearData.lua lacks; the level is the table's required level, or the lowest `from` when the table says
less) into `BisData.lua`, and computed stats (`SC`) for a picked item GearData.lua has no scan of (as
any item of its kind; a pick of a kind without proof gets its allocations alone). Picks do not enter
the weights. In the addon `Gear.Best` puts a pick
first in its row for that spec and level (the weapon plan decides: a two-hand pick only with "auto" or
"Zweihand", which it then chooses; source filters do not apply), the computed options below; the own
targets, `ns.UpgradeOf`, `ns.BisGain` and the tooltip treat it as the row's target (an upgrade until
worn; while it is worn nothing else is an upgrade for that row). The setting `bis.picks`
("BiS-Empfehlungen zeigen", on) switches picks off.

`tools/tests/test_build_bis.py` (fixture CSVs) and `tools/tests/test_score_parity.py` (Python and
`Gear.Score` equal to 0.01 on 200 real items per spec).

## build_dungeonquests.py

Builds `addon/Amisia/Data/DungeonQuestData.lua` (`ns.DUNGEON_QUESTS`, loaded through
`[AllowLoadGameType camelot]`) for the quest list of the dungeon planner: per dungeon of
`tools/forever_dungeons.json` its quests, and per quest the level, faction, where it starts (quest
giver with up to four map points, inside the dungeon, or by an item), its pre-quests (each with its
own record) and its gear rewards.

```
python tools/build_dungeonquests.py [--att ~/addons/_cache/att] [--refresh-att] [--json FILE] [--empty]
```

- Source: AllTheThings' hand-kept Forever data, folder `.contrib/.db/forever` of
  https://github.com/ATTWoWAddon/AllTheThings, **MIT licence**. The copyright line and the licence
  text ship with the addon in `addon/Amisia/LICENSES/AllTheThings-MIT.txt` (approved by the user on
  2026-10-06; the UI does not name it). `--refresh-att` downloads it into `~/addons/_cache/att` (see
  `att_data.py`, the shared reader, which runs the files in its sandbox).
- Only the Forever folders count here (not the Classic zzOLD ones). A dungeon file is matched to the
  facts by its file name or the instance's area id; instances without facts are reported.
  Pre-quests are looked up in the zone files; one the download does not hold falls away.
- The input is pluggable: every reader produces one neutral form (see `NEUTRAL` in the script),
  `--json` reads that form directly, `--empty` writes the file without data (the addon then says
  "Questdaten fehlen noch.").
- No data of other quest databases goes in. The date alone does not rewrite the file.

Runs on the N100 (no WoW install needed). Rebuild with `--refresh-att` when the source has new
dungeons, then commit. Requires `lupa`. Tests: `tools/tests/test_build_dungeonquests.py` on a
hand-made fixture in the builder language (`tools/tests/fixtures/att`, no real data).

## build_professions.py

Builds `addon/Amisia/Data/ProfessionData.lua` (`ns.PROFESSIONS`, loaded through
`[AllowLoadGameType camelot]`) for the professions page (`/amisia berufe`): every recipe of every
profession with what it makes, its difficulty (`TrivialSkillLineRankLow` yellow,
`TrivialSkillLineRankHigh` grey, green between), how it is learned (with the profession, trainer
tier, recipe item) and where a recipe item comes from (vendor, Merchant's Favor with price and
standing per faction, drop, zone or world drop, quest); the camp objects (campfires with their
places, the objects per profession and rank, which one replaces which); Merchant's Favor (vendors,
certifications, the items a crafting order exists for). Spec:
`docs/superpowers/specs/2026-10-06-amisia-professions-design.md`.

```
python tools/build_professions.py [--wago ~/addons/_wago] [--att ~/addons/_cache/att] [--out FILE] [--empty]
```

- Client tables (`~/addons/_wago`): `SkillLineAbility`, `SpellEffect`, `ItemSparse`,
  `ItemXItemEffect`, `ItemEffect`, `SpellName`, `Spell`, optional `SpellReagents`. Without a
  `SkillLineAbility` of its own the build takes the copy AllTheThings ships
  (`.config/.wago/SkillLineAbility.1.60.1.70170.csv`). Without `SpellReagents` the file has no
  reagents and the addon asks the client (`C_TradeSkillUI.GetRecipeSchematic`). Export the missing
  ones on the PC: `export_db2.ps1 -Tables SkillLineAbility,SpellReagents,SkillLine`.
- AllTheThings (MIT, see `att_data.py`): `.config/structures/*.lua` (trainer lists per tier,
  Merchant's Favor lists per faction and standing; read as text after the preprocessor),
  `profession db/*.lua` (recipe item -> recipe), and the zone and dungeon files through
  `att_data.load()` (vendors, drops, quests of the recipe items; the favor vendors by the list
  their goods name).
- No names of recipes or items go in: the addon asks the client (German). NPC and quest names are
  AllTheThings' English ones. Spells 400000-999999 (Season of Discovery) that AllTheThings does not
  list for Forever are left out (134 in 1.60.1.70235).
- Size: about 180 KB for 2,400 recipes and 1,950 recipe items. The date alone does not rewrite the
  file.

Tests: `tools/tests/test_build_professions.py` on hand-made CSVs (`tools/tests/fixtures/wago_prof`)
and a hand-made AllTheThings fixture (`tools/tests/fixtures/att_prof`).

## build_talents.py

Builds `addon/Amisia/Data/TalentData.lua` (`ns.TALENTS`, loaded through `[AllowLoadGameType camelot]`)
for the talent calculator (`/amisia talente`): per class its trait tree, the three trees (node group,
name, icon), the row locks (counting groups) and the talents with row, column, ranks, prerequisites,
name and text (enUS, placeholders resolved; what changes per rank as `{1}` with the values per rank).

```
python tools/build_talents.py [--wago DIR ...] [--out FILE]
```

- Forever keeps its talents in the trait system (`C_Traits`): one `TraitTree` per class, split into
  three node groups. The old `Talent`/`TalentTab` tables still hold Classic's talents and are not
  read. Points: the tree's currency (`SourcedMax` 51, one per level 10-60); the legacy perk
  "Talented" only gives them earlier (rank k from level 10-k), never more.
- Client tables read (CSV in wago.tools' format, `--wago`, default `~/addons/_wago`; the first
  folder with a table wins): `TraitNode`, `TraitNodeEntry`, `TraitNodeXTraitNodeEntry`,
  `TraitDefinition`, `TraitDefinitionEffectPoints`, `CurvePoint`, `TraitEdge`, `TraitNodeGroup`,
  `TraitNodeGroupXTraitNode`, `TraitNodeGroupXTraitCond`, `TraitCond`, `TraitNodeGroupDisplayInfo`,
  `TraitCurrency`, `TraitCurrencySource`, `TraitTreeXTraitCurrency`, `SkillLineXTraitTree`,
  `SkillLine`, `SkillRaceClassInfo`, `ChrClasses`, `Spell`, `SpellName`, `SpellMisc`, `SpellEffect`;
  when present also `TraitNodeXTraitCond`, `ChrSpecialization`, `SpellDuration`, `SpellRadius`,
  `SpellAuraOptions`. A missing required table stops the build with the `export_db2.ps1 -Tables`
  line to run.
- Nodes far off the 600 grid (old, replaced ones the client parks out of sight) are left out and
  reported; so is a node that would share a cell.
- The addon shows the client's own German texts and names at runtime (`C_Traits.GetTraitDescription`,
  `C_Spell.GetSpellName`, `C_Traits.GetGroupDisplayInfoByTreeID`); the data is the fallback.

Runs on the N100. Tests: `tools/tests/test_build_talents.py` on hand-made fixture CSVs
(`tools/tests/fixtures/talents`, a mage, a warrior and a legacy tree).

## make_icons.py

Draws the addon's icons from scratch as genuine 32-bit TGAs: `Amisia.tga` (128x128, the window
portrait and the addon list icon: the golden A over the infinity loop of the guild logo on the
logo's turquoise stone) and `Minimap.tga` (64x64, the same with a gold rim). The A is set in Cinzel
(`tools/fonts/Cinzel.ttf`, SIL Open Font License 1.1, `tools/fonts/OFL.txt`); the font is only used
to draw the images and does not ship in the addon. `--preview DIR` also writes PNGs to look at. A
changed texture needs a full client restart before WoW shows it; `/reload` is not enough. Requires
Pillow.

## build_bossnames.py

Builds `data/bossnames.js`: the boss name a localized client shows, mapped to the name the loot
tables use. The addon exports the source name its own client gives it ("Illidan Sturmgrimm" on a
German client), and without this the site cannot tell which boss an item came from.

```
python tools/build_bossnames.py [<locale folder>...]
```

The pairs come from the locale files of the installed loot addon the tables were built from;
without an argument the copy under the WoW folder is read (`AMISIA_WOW_ROOT` overrides the path).
Names that stay untranslated are listed at the end. Bump `BUILD_ID` afterwards.

Archive only: `data/bossnames.js` holds just the TBC table (the read-only TBC archive of the site),
so this runs again only if the archive ever needs new names, which is practically never. It reads
the WoW install, so it runs on the PC.

## fill_quality.py

Writes the item quality into `data/tbc.js`, so names and icon frames get their colour. Archive
only: Forever gets its quality from the item scan (`build_scan.py`).

```
python tools/fill_quality.py [tbc] [--all]
```

Only items without a quality are looked up, through the Wowhead tooltip endpoint; every answer is
kept in `tools/item-quality.json`, so a second run costs nothing. Epic is the page's default and
is not written. Bump `BUILD_ID` afterwards.

## sync_addon.ps1

Mirrors `addon/Amisia` into the AddOns folder of the Forever client (`_classic_beta_`): changed
files are copied, files gone from the repository are deleted, folders and files starting with a
dot (editor and Claude Code settings) stay out. A junctioned target is skipped (the N100 sends
that copy through Syncthing), so on the N100 setup it has nothing to do.

```
pwsh -File tools/sync_addon.ps1 [-Watch] [-Quiet] [-NoCheck]
```

It parses the Lua files first (`addon/tests/syntax.cjs`) and copies nothing when one does not
parse, because a single broken file keeps the whole addon from loading; `-NoCheck` skips that.
`-Watch` copies again on every change, `AMISIA_WOW_ROOT` overrides the WoW folder. A running
client picks the files up at the next `/reload`.

## export_db2.ps1

Exports the Forever client tables the build scripts read (`ItemSparse`, `Item`, `ItemSet`,
`ItemSetSpell`, `ItemXItemEffect`, `ItemEffect`, `SpellEffect`, `SpellName`, `Spell`, `SpellMisc`,
`SpellItemEnchantment`, `RandPropPoints`, `LFGDungeons`, `ContentTuning`, `UiMapAssignment`,
`AreaTable`, `Map`, the `Journal*` and `DungeonEncounter` tables, plus the item damage and armour
tables `ItemDamage*`, `ItemArmor*` and `ArmorLocation`, which `build_bis.py` reads, and the talent
tables `Trait*`, `CurvePoint`, `SkillLine*`, `SkillRaceClassInfo`, `ChrClasses`, `ChrSpecialization`,
`SpellDuration`, `SpellRadius` and `SpellAuraOptions` for `build_talents.py`) as CSV straight from
the WoW install on the PC, instead of downloading them from wago.tools by hand. Runs on the PC only (it needs the WoW install).

It drives [wow.tools.local](https://github.com/Marlamin/wow.tools.local) (WTL), which reads the local
CASC storage (TACTSharp), decodes the DB2 files with DBCD and the WoWDBDefs definitions, and serves a
CSV export on localhost. Forever is the TACT product `wow_classic_beta`; the script reads it from
`_classic_beta_\.flavor.info` and the installed build from `.build.info`.

**Install (once):**

1. Download `Release-win-x64.zip` of wow.tools.local **0.9.9** or newer from
   <https://github.com/Marlamin/wow.tools.local/releases> (self-contained, no .NET install needed) and
   extract it to `%USERPROFILE%\Tools\wow.tools.local` (or set `AMISIA_WTL_DIR`, or pass `-WtlDir`).
2. Nothing else: on its first start WTL downloads the WoWDBDefs definitions, the community listfile
   and the TACT keys from GitHub (internet needed; the listfile is large), and keeps them for a day.

**Run** (WoW and the Battle.net launcher closed, so no files are locked):

```
powershell -ExecutionPolicy Bypass -File tools\export_db2.ps1
```

It starts WTL in the background on port 5077, waits until the build is loaded (minutes on the first
start), switches to the installed build if WTL picked a newer one from the patch server, writes
`<Table>.<build>.csv` (for example `ItemSparse.1.60.1.70235.csv`) into `%USERPROFILE%\VuloSync\wago`
and stops WTL again. Syncthing (folder `amisia-wago`) brings the files to `~/addons/_wago`, where
`build_bis.py`, `build_dungeons.py`, `build_gear.py` and `build_map.py` pick the newest build.

- Array columns are renamed from `Name[0]` to `Name_0`, the form wago.tools uses, so the files are
  drop-in replacements. String columns are `enUS` (`-Locale`).
- Idempotent: tables already exported for the installed build are skipped, so after a client patch
  only the new build is exported. `_export.<build>.txt` in the output folder records the result per
  table; a table the build has empty or lacks is not asked for again. `-Force` exports everything
  again, `-Tables ItemSparse,Item` only those.
- `-Hotfixes` applies the client's `DBCache.bin` hotfixes (log in once first); without it the base
  data of the build is exported, as on wago.tools.
- Other options: `-WowDir` (or `AMISIA_WOW_ROOT`), `-Flavor`, `-Product`, `-OutDir`, `-Port`,
  `-StartTimeoutMin`, `-IgnoreRunningGame`. A WTL already answering on the port is used and left
  running.
- Exit code 0 when everything is there, 1 on a setup error (message says what to fix), 2 when a
  table failed; then the WTL log (`%TEMP%\amisia-wtl.out.log`) is printed. Tables encrypted with a key
  WTL does not know come out without those rows.

Licences: wow.tools.local, TACTSharp and DBCD are MIT; the WoWDBDefs definitions are CC BY-SA 4.0
(code BSD-3-Clause). The tool is only run, nothing of it is shipped. The exported tables are
Blizzard's game data, as with the wago.tools downloads: read by the build scripts, never committed.
