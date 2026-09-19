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
3. Read the warnings: add unknown instances to `tools/forever_zones.json`, mark trash sources
   or rename bosses in `tools/forever_bosses.json`, run again.
4. In `index.html` give the `forever` entry of `GAMES` its `file: 'data/forever.js'`, drop
   `soon: true`, bump `BUILD_ID`, commit and push.

The boss loot tables grow with the raids: every item that lay in an opened loot window is
listed under its source. Requires `lupa`; icons need `Pillow` and internet access.

Tests: `python -m pytest tools/tests -q`.
