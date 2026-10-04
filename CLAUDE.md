# Amisia loot ledger

- The claude.ai artifact twin is built from `index.html` with `tools/build_twin.py`, never edited by hand.
- After changing `index.html`, `tools/build_twin.py`, anything in `data/`, `favicon.png` or `logo.png`, rebuild and republish the twin, then run `python tools/twin_stamp.py --published`.
- `python tools/twin_stamp.py` says whether the twin is behind; the pre-push hook prints the same warning.
- Bump `BUILD_ID` in `index.html` whenever a data file changes, or browsers keep the cached copy.
- Tests: `python -m pytest tools/tests -q`.
- Addon tests: `python addon/tests/run.py` and `node addon/tests/syntax.cjs`.

## Addon development on the N100 (since 2026-10-04)

- The working copy for the addon is `~/addons/Amisia` on the N100. Syncthing sends `addon/Amisia` (send-only, folder `amisia`) to `C:\Users\aobiw\VuloSync\Amisia` on the PC; the `Amisia` folders in `_anniversary_` and `_classic_beta_` are junctions on it. Saving on the N100 is the deploy, `/reload` in game shows it.
- `tools/sync_addon.ps1` skips junctioned targets, so the PC never writes into the received copy.
- On the N100 the tests run with the venv `~/.venvs/amisia`: `~/.venvs/amisia/bin/python addon/tests/run.py`, `~/.venvs/amisia/bin/python -m pytest tools/tests -q`, and `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node addon/tests/syntax.cjs` (Node lives in `~/.local/node/bin`).
- What needs the PC: `tools/build_gear.py`, `tools/build_scan.py` and `tools/build_bossnames.py` read the WoW install (QuestieDB, OneForAll, AtlasLoot, RXP, SavedVariables), and the twin publish needs the claude.ai Artifact tool there.
- The codex CLI is not installed on the N100; implementation subagents run on the Fable lane there.
