# Tools

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

Tests: `python -m pytest tools/tests -q`.

## build_gear.py

Builds `addon/Amisia/GearData.lua` and `addon/Amisia/GearWeights.lua` for the addon's gear window
(`/amisia gear`, WoW Forever only): every item a levelling character can wear, where it comes from,
and the stat weights per class, spec and level.

```
python tools/build_gear.py
```

- What an item is (slot, armour or weapon type, required level, quality) comes from the Amisia item
  scan: the scan dumps in the repo root plus the installed Forever client's SavedVariables, or the
  files given with `--sv`. Items without a scan are left out.
- Where it comes from is joined from QuestieDB's Forever database (quests, vendors, NPC drops; read
  from the Classic Era AddOns folder), OneForAll (Forever dungeons, dungeon quests, Merchant's Favor
  recipes), AtlasLootClassic (Forever dungeon tables, Classic recipes), the wowsrc.com dungeon pages
  (kept in `tools/gear_wowsrc.json`, `--refresh-wowsrc` downloads them again) and the Amisia item
  collector.
- The DPS weights come from RestedXP's Forever `StatWeights.lua` (CC BY-NC-SA 4.0, so
  `GearWeights.lua` carries that licence); healer and tank weights are defined in the script.
- In game, `/amisia scan gear` (outside instances) asks the client for every item the planner lists
  plus the ids its sources name but no scan has seen (`M` in GearData.lua, items Forever still
  hides until they are revealed). It stores each item's stats too. Log out, rebuild: the stats go
  into `GearData.lua` (`ST`), so the window needs no loading, and newly revealed items join.
- Items without scanned stats are read from the client when the window opens.
- The collector notes drops with NPC id and dungeon (`Drop: <mob> [<npcID>] @<place> #party:<instanceID>`)
  and quest rewards with quest id and the player's level, so the new Forever dungeons and quests fill
  in as the guild plays. Pass every officer's SavedVariables with `--sv` to merge them.
- Rebuild after a scan, when the source addons update, or to pick up what the collector saw.
- Vendors, rare mobs and named mobs carry the NPC id as their last field (V and P at 7, R at 5, W
  at 6), from QuestieDB or the collector's `[npcID]`; `Gear.lua` does not read it, `build_map.py`
  keys the map points by it.
- Dungeon sources carry the instance id and area id (from AtlasLoot's `InstanceID`/`MapID` or
  Questie's zone tables), so the gear page can find "here" through `GetInstanceInfo()`.
- Forever raids: drops the site recorded in `data/forever.js` for a zone that
  `tools/forever_zones.json` marks `"raid": true` (with `"instance"` and `"area"` where known) become
  raid sources (`X`). Mark a new Forever raid there once the site has its loot, then rebuild.
- Both files carry `game = "forever"`, `cap = 60` and are loaded through the TOC condition
  `[AllowLoadGameType camelot]`.

It reads the WoW install (QuestieDB, OneForAll, AtlasLoot, RXP, SavedVariables), so it runs on the
PC. `AMISIA_WOW_ROOT` overrides the WoW install path. Requires `lupa`.

Licences of the data: QuestieDB GPL-3.0 and AtlasLootClassic GPL-2.0 (Forever tables,
`GearData.lua`), QuestieDB GPL-3.0 (`MapData.lua`, `map_questie.json`), RestedXP's Forever weights
CC BY-NC-SA 4.0 (`GearWeights.lua`), wago.tools exports are Blizzard's game data
(`gear_itemsparse.json`).

## build_map.py

Builds `addon/Amisia/MapData.lua` (WoW Forever) for the map: where each source of the gear data
stands, as up to four points `uiMapID:x:y` (x, y in hundredths of a percent) under a stable key per
source (`Q:<quest id>`, `V:`/`R:`/`W:<NPC name>`, `U:<NPC id>`, `I:<instance id>`,
`N:<dungeon name>`).

```
python tools/build_map.py [--refresh-questie] [--questie-ref REF]
```

- NPC and object spawns, quest starters, dungeon entrances and the zone tables (area id to uiMapID,
  instance id to area) come from QuestieDB (https://github.com/Questie/QuestieDB, GPL-3.0), its
  Forever databases. `--refresh-questie` downloads them from GitHub into
  `tools/cache/questiedb/forever/` (not in git, with the commit in `COMMIT`). Whenever that
  download is complete, what the gear data needs from it is written whole to
  `tools/map_questie.json` (in git), so a build without network gives the same file. Only the
  `[[return {...}]]` block of each database file is run; the dungeon file runs with the Era
  expansion, so only the Era corrections of the entrances apply.
- Which keys are needed comes from `GearData.lua`: quests by their quest id (quest giver or start
  object; quests started by an item have no place), vendors, rare and named mobs by name (an NPC in
  the source's zone wins, names found in several zones are reported) or by NPC id once
  `build_gear.py` writes it, raids and dungeons by their entrance. A spawn inside an instance
  stands for its entrance.
- Several spawns: spawns within 2 % are one point, then the four farthest apart are kept.
- The file is loaded through the TOC condition `[AllowLoadGameType camelot]`. Keys are sorted, so a
  second build gives the same file.
- The report lists per source kind how many have a place, areas without a map, ambiguous names and
  quests without a starter.

Runs on the N100 (no WoW install needed). After `build_gear.py` ran on the PC (NPC ids, instance
ids), run it again and commit. Requires `lupa`.

## make_minimap_icon.py

Draws `addon/Amisia/Media/Icons/Minimap.tga`, the round minimap button icon: the golden A of
`Amisia.tga` on the guild's turquoise stone with a gold rim, as a genuine 64x64 32-bit TGA.
`--preview out.png` writes an enlarged PNG to look at. A new or renamed texture needs a full client
restart before WoW shows it; `/reload` is not enough. Requires Pillow.

## build_twin.py and twin_stamp.py

The claude.ai copy of the ledger (the "twin") is built from `index.html`, never edited by hand.
It has no database, so everything that needs Supabase is cut out of it.

1. Read the twin's own `data.json` from the artifact, then build:

   ```
   python tools/build_twin.py <out>/index.html <the twin's data.json>
   ```

2. Publish the result to the artifact, together with every file under `data/`, `favicon.png` and
   `logo.png` that changed.
3. Record what was published:

   ```
   python tools/twin_stamp.py --published
   ```

`python tools/twin_stamp.py` without arguments lists what changed since the last publish. The
pre-push hook in `.githooks/pre-push` runs it and warns, but never blocks the push. Turn it on
once per clone with `git config core.hooksPath .githooks`.

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
