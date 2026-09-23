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

## fill_quality.py

Writes the item quality into `data/<game>.js`, so names and icon frames get their colour.

```
python tools/fill_quality.py [tbc classic sod mop ...] [--all]
```

Only items without a quality are looked up, through the Wowhead tooltip endpoint; every answer is
kept in `tools/item-quality.json`, so a second run costs nothing. Epic is the page's default and
is not written. Bump `BUILD_ID` afterwards.

## sync_addon.ps1

Mirrors `addon/Amisia` into the AddOns folders of both clients (`_anniversary_` and
`_classic_beta_`): changed files are copied, files gone from the repository are deleted, folders
and files starting with a dot (editor and Claude Code settings) stay out.

```
pwsh -File tools/sync_addon.ps1 [-Watch] [-Quiet] [-NoCheck]
```

It parses the Lua files first (`addon/tests/syntax.cjs`) and copies nothing when one does not
parse, because a single broken file keeps the whole addon from loading; `-NoCheck` skips that.
`-Watch` copies again on every change, `AMISIA_WOW_ROOT` overrides the WoW folder. A running
client picks the files up at the next `/reload`.
