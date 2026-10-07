# Amisia loot ledger

- The old claude.ai artifact copy of the site (the "twin") is no longer maintained (since 2026-10-06); the live site on GitHub Pages is the only one.
- Bump `BUILD_ID` in `index.html` whenever a data file changes, or browsers keep the cached copy.
- Tests: `python -m pytest tools/tests -q`.
- Addon tests: `python addon/tests/run.py` and `node addon/tests/syntax.cjs`.

## Addon development on the N100 (since 2026-10-04)

- The working copy for the addon is `~/addons/Amisia` on the N100. Syncthing sends the release folder `~/addons/_release/Amisia` (send-only, folder `amisia`) to `C:\Users\aobiw\VuloSync\Amisia` on the PC; the `Amisia` folder in `_classic_beta_` is a junction on it (the `_anniversary_` one is gone: Amisia is WoW Forever only since 2.0, the TBC ledger lives on only as the read-only archive of the site).
- Saving in `addon/Amisia` does not reach the game (since 2026-10-04). A finished, committed version goes there with `tools/release_addon.sh`; then `/reload` in game shows it.
- Amisia's SavedVariables (`Amisia.lua`, Forever account) come back from the PC to `~/addons/_SavedVariables/Amisia.lua` through the receive-only Syncthing folder `vfui-savedvariables` (its `.stignore` lets `/Amisia.lua` through since 2026-10-05). Read only; build_scan.py and the drop archive can use it on the N100.
- The wago.tools client tables (CSV, downloaded by hand in the browser per Forever build) come from the PC to `~/addons/_wago` through the receive-only Syncthing folder `amisia-wago` (since 2026-10-06). `tools/build_bis.py --wago ~/addons/_wago` reads them.
- Never download from wago.tools (or wowhead, foreverchanges) by script or from the N100: its robots.txt forbids bots. Client tables come only from the user's own export (`tools/export_db2.ps1` on the PC, into `~/addons/_wago`); add a missing table to that script's lists and ask the user to run it.
- `tools/sync_addon.ps1` skips junctioned targets, so the PC never writes into the received copy.
- On the N100 the tests run with the venv `~/.venvs/amisia`: `~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`, and `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs` (Node lives in `~/.local/node/bin`).
- `tools/build_gear.py`, `tools/build_map.py` and `tools/build_dungeonquests.py` run on the N100 from the AllTheThings cache `~/addons/_cache/att` (MIT, read only through the sandboxed `tools/att_data.py`; `--refresh-att` updates it). No QuestieDB (it has no licence; removed 2026-10-06). PC-only inputs are optional: AtlasLoot, OneForAll, RXP and the SavedVariables; `tools/build_scan.py` and `tools/build_bossnames.py` (archive only) still read the WoW install.
- The codex CLI is not installed on the N100. Subagents only as `opus-medium` (implementation, reviews) or `sonnet-medium` (simple tasks), defined in ~/.claude/agents; never Fable.
