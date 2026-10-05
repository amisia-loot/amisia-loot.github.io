# Amisia loot ledger

- The claude.ai artifact twin is built from `index.html` with `tools/build_twin.py`, never edited by hand.
- After changing `index.html`, `tools/build_twin.py`, anything in `data/`, `favicon.png` or `logo.png`, rebuild and republish the twin, then run `python tools/twin_stamp.py --published`.
- `python tools/twin_stamp.py` says whether the twin is behind; the pre-push hook prints the same warning.
- Bump `BUILD_ID` in `index.html` whenever a data file changes, or browsers keep the cached copy.
- Tests: `python -m pytest tools/tests -q`.
- Addon tests: `python addon/tests/run.py` and `node addon/tests/syntax.cjs`.

## Addon development on the N100 (since 2026-10-04)

- The working copy for the addon is `~/addons/Amisia` on the N100. Syncthing sends the release folder `~/addons/_release/Amisia` (send-only, folder `amisia`) to `C:\Users\aobiw\VuloSync\Amisia` on the PC; the `Amisia` folder in `_classic_beta_` is a junction on it (the `_anniversary_` one is gone: Amisia is WoW Forever only since 2.0, the TBC ledger lives on only as the read-only archive of the site).
- Saving in `addon/Amisia` does not reach the game (since 2026-10-04). A finished, committed version goes there with `tools/release_addon.sh`; then `/reload` in game shows it.
- Amisia's SavedVariables (`Amisia.lua`, Forever account) come back from the PC to `~/addons/_SavedVariables/Amisia.lua` through the receive-only Syncthing folder `vfui-savedvariables` (its `.stignore` lets `/Amisia.lua` through since 2026-10-05). Read only; build_scan.py and the drop archive can use it on the N100.
- `tools/sync_addon.ps1` skips junctioned targets, so the PC never writes into the received copy.
- On the N100 the tests run with the venv `~/.venvs/amisia`: `~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`, and `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs` (Node lives in `~/.local/node/bin`).
- What needs the PC: `tools/build_gear.py`, `tools/build_scan.py` and `tools/build_bossnames.py` (archive only) read the WoW install (QuestieDB, OneForAll, AtlasLoot, RXP, SavedVariables). The twin publish works from the N100 too (Artifact tool).
- The codex CLI is not installed on the N100. Subagents only as `opus-medium` (implementation, reviews) or `sonnet-medium` (simple tasks), defined in ~/.claude/agents; never Fable.
