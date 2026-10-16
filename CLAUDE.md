# Amisia loot ledger

- **Read `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` before changing anything.** Update them in the
  same commit when you change a protocol (addon message kind, blob art), an export line or paste-in
  block, a saved `AmisiaDB` key, a settings section, a TOC file or a decision. `tools/tests/test_contracts.py`
  fails when the code and the documents drift apart.
- Features and their status: `docs/FEATURES.md`; larger features get a spec in `docs/specs` first (README
  there). After a release relay the test list; record results with `build.py tested F-xxx`; game errors:
  `build.py errors`.
- Folders: `Amisia/` the WoW Forever addon only (what the release copies, TOC at its root);
  `Amisia-Website/` the site (`index.html`, `data/*.js`, `Amisia.zip`, `supabase/` not deployed; GitHub
  Pages via `.github/workflows/pages.yml`, the only live copy; the claude.ai twin is unmaintained);
  `tests/` the addon's Lua tests; `tools/` builders and tool tests; `docs/` the documents.
- One entry point: `python3 tools/build.py check` (must stay green), `data [--sv FILE] [--wago DIR]`,
  `snapshots [--out DIR] [--compare DIR]`, `release X.Y.Z -m "summary"`. Details in `tools/README.md`.
  Tests one by one: `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
  `~/.venvs/amisia/bin/python tests/run.py [name]`,
  `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node tests/syntax.cjs` (Node in `~/.local/node/bin`).
- New user-visible text: German inside `L["…"]`, English in `Amisia/Locales/enUS_<area>.lua`;
  `python3 tools/l10n.py check` stays clean.
- UI: sizes, fonts, colours and allowed atlases from `UI/Theme.lua`; rows with `W.Row`/`W.Column`/`W.Grid`,
  chips with `W.FitChip`. Before and after a UI refactor: `build.py snapshots --out A`, then `--out B --compare A`.
- Lazy data: read generated tables with `ns.Data("GEAR")` etc., check with `ns.HasData`/`ns.DataSize`.
- Scan data (`AmisiaDB.scan`) lives for good in `tools/scan_archive.json`; `build.py data` joins the
  SavedVariables into it and writes `Data/ScanDone.lua`, after which the addon trims its file (D-34).
  Commit and push the archive: it is the only copy of what the addon trimmed.
- Bump `BUILD_ID` in `Amisia-Website/index.html` whenever an `Amisia-Website/data/*.js` file changes.
- Saving in `Amisia/` does not reach the game: only `tools/build.py release` (via
  `tools/release_addon.sh`) copies a committed version to the Syncthing release folder; then `/reload`.
  Machines and folders: ARCHITECTURE.md, "Machines".
- New client build: the PC exports the tables by itself and the N100 builds and checks them on branch
  `auto/data-<build>` (D-51). At the start of a session read `~/addons/_auto/amisia-data.txt` and tell the
  user when data is ready or red; release only when the user asks.
- Never download from wago.tools, Wowhead or foreverchanges by script (DECISIONS D-03): a missing client
  table goes into `tools/export_db2.ps1` and the user runs it on the PC.
- Subagents only `opus-medium` or `sonnet-medium`, never Fable, no nested agents (DECISIONS D-31).
