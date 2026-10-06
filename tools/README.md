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
  `.config/exports/ItemDB.lua` and the client tables `UiMapAssignment`, `AreaTable` and `ContentTuning`
  ATT ships.
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

Builds `addon/Amisia/GearData.lua` and `addon/Amisia/GearWeights.lua` for the addon's gear window
(`/amisia gear`, WoW Forever only): every item a levelling character can wear, where it comes from,
and the stat weights per class, spec and level.

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
  Merchant's Favor recipes), AtlasLootClassic (Forever dungeon tables, Classic recipes with skill),
  RestedXP's Forever `StatWeights.lua` (without it `GearWeights.lua` stays as it is).
- wowsrc.com dungeon pages (drop chances) are kept in `tools/gear_wowsrc.json`;
  `--refresh-wowsrc` downloads them again, `--no-wowsrc` leaves them out.
- The DPS weights come from RestedXP's Forever `StatWeights.lua` (CC BY-NC-SA 4.0, so
  `GearWeights.lua` carries that licence); healer and tank weights are defined in the script.
- In game, `/amisia scan gear` (outside instances) asks the client for every item the planner lists
  plus the ids its sources name but no item table knows (`M` in GearData.lua, items Forever still
  hides until they are revealed). It stores each item's stats too. Log out, rebuild: the stats go
  into `GearData.lua` (`ST`), so the window needs no loading, and newly revealed items join.
- Items without scanned stats are read from the client when the window opens.
- The collector notes drops with NPC id and dungeon (`Drop: <mob> [<npcID>] @<place> #party:<instanceID>`)
  and quest rewards with quest id and the player's level, so the new Forever dungeons and quests fill
  in as the guild plays. Pass every officer's SavedVariables with `--sv` to merge them.
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
- Both files carry `game = "forever"`, `cap = 60` and are loaded through the TOC condition
  `[AllowLoadGameType camelot]`.

Runs on the N100. On the PC it also takes the scan and the PC-only sources. `AMISIA_WOW_ROOT`
overrides the WoW install path. Requires `lupa`.

Licences of the data: AllTheThings MIT (`GearData.lua`, `MapData.lua`, `DungeonQuestData.lua`;
`addon/Amisia/LICENSES/AllTheThings-MIT.txt`), AtlasLootClassic GPL-2.0 when used (to be checked in
the installed folder), RestedXP's Forever weights CC BY-NC-SA 4.0 (`GearWeights.lua`), wago.tools
exports and ATT's item export are Blizzard's game data (`gear_itemsparse.json`). Still open:
OneForAll's licence (check its installed folder on the PC) and wowsrc.com, whose pages state no
licence (its robots.txt allows crawling, which is not one); `--no-wowsrc` leaves it out. No QuestieDB
data: it has no licence.

## build_map.py

Builds `addon/Amisia/MapData.lua` (WoW Forever) for the map: where each source of the gear data
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

Builds `addon/Amisia/DungeonData.lua` (`ns.DUNGEON_FACTS`, loaded through
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
  `MinLevelSquish`) and its instance id (`AreaTable`). Forever's `LFGDungeons` (1.60.1.70235) has no
  level range, map or group size of its own; the tuning level is one number, the low end of the range
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
- Once `build_bis.py` writes `ns.BIS.DG` (the same facts, with the `LFGDungeons` ranges and the
  bosses' NPC ids), the planner takes that table and this file can go.

Runs anywhere, no network. `tools/tests/test_build_dungeons.py` checks that the Lua file is current.

## build_dungeonquests.py

Builds `addon/Amisia/DungeonQuestData.lua` (`ns.DUNGEON_QUESTS`, loaded through
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
