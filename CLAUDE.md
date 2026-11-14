# Amisia loot ledger

- **Read `docs/ARCHITECTURE.md` and `docs/DECISIONS.md` before changing anything.** Update them in the
  same commit when you change a protocol (addon message kind, blob art), an export line or paste-in
  block, a saved `AmisiaDB` key, a settings section, a TOC file or a decision. `tools/tests/test_contracts.py`
  fails when the code and the documents drift apart.
- Features and their status: `docs/FEATURES.md`; larger features get a spec in `docs/specs` first (README
  there). After a release relay the test list; record results with `build.py tested F-xxx`; game errors:
  `build.py errors`.
- Folders: the WoW Forever addon in three addons (F-202, D-130), each with its TOC at its root and copied by
  the release: `Amisia/` the core, `Amisia_Raid/` the raid module, `Amisia_Gear/` the gear module
  ("Ausrüstung & Dungeons", Forever only, with all generated `Data/*`); a file's folder says its part;
  `Amisia-Website/` the site (`index.html`, `data/*.js`, `Amisia.zip`, `supabase/` not deployed; GitHub
  Pages via `.github/workflows/pages.yml`, the only live copy; the claude.ai twin is unmaintained);
  `tests/` the addon's Lua tests; `tools/` builders and tool tests; `docs/` the documents.
- One entry point: `python3 tools/build.py check` (must stay green), `tables`, `data [--sv FILE] [--wago DIR]`,
  `snapshots [--out DIR] [--compare DIR]`, `release X.Y.Z -m "summary"`. Details in `tools/README.md`.
- Every user-visible change adds an English note under `## Unreleased` in `CHANGELOG.md`
  (`- type(scope): summary (F-xxx)`, a blank line, an indented paragraph); the release stops without one (D-60).
  Tests one by one: `~/.venvs/amisia/bin/python -m pytest tools/tests -q`,
  `~/.venvs/amisia/bin/python tests/run.py [name]`,
  `NODE_PATH=~/addons/VuloForeverUI/tools/node_modules node tests/syntax.cjs` (Node in `~/.local/node/bin`).
- New user-visible text: German inside `L["…"]`, English in `Locales/enUS_<area>.lua` of its part's folder;
  `python3 tools/l10n.py check` stays clean.
- Every addon file but `Locales/Locale.lua` and the generated `Data/*` puts its body in `ns.Load(function()`
  ... `end)` right after `local ADDON, ns = ...`: the bodies run on ADDON_LOADED, once the chosen language
  (`ui.language`) is known (D-128, `tools/tests/test_load_order.py`).
- UI: sizes, fonts, colours and allowed atlases from `UI/Theme.lua`; rows with `W.Row`/`W.Column`/`W.Grid`,
  chips with `W.FitChip`. Before and after a UI refactor: `build.py snapshots --out A`, then `--out B --compare A`.
- Lazy data: read generated tables with `ns.Data("GEAR")` etc., check with `ns.HasData`/`ns.DataSize`.
- Scan data (`AmisiaDB.scan`) lives for good in `tools/scan_archive.json`; `build.py data` joins the
  SavedVariables into it and writes `Data/ScanDone.lua`, after which the addon trims its file (D-34).
  Commit and push the archive: it is the only copy of what the addon trimmed.
- Bump `BUILD_ID` in `Amisia-Website/index.html` whenever an `Amisia-Website/data/*.js` file changes.
- Saving in the addon folders does not reach the game: only `tools/build.py release` (via
  `tools/release_addon.sh`) copies a committed version to the Syncthing release folder; then `/reload`.
  Machines and folders: ARCHITECTURE.md, "Machines".
- New client build: the PC exports the tables by itself and the N100 builds and checks them on branch
  `auto/data-<build>` (D-51). At the start of a session read `~/addons/_auto/amisia-data.txt` and tell the
  user when data is ready or red, and what its block "Spielstand vom ..." says is new or red (the SavedVariables
  built on `auto/sv-<date>`, D-122); release only when the user asks.
- Client tables may be fetched from wago.tools, but only by `python3 tools/build.py tables`
  (`tools/fetch_tables.py`: its API and CSV exports of product `wowf`, one request at a time, nothing twice;
  DECISIONS D-101, which changed D-03). `build.py data` never touches the network; it takes per table the
  newest and fullest copy on disk (`tools/client_tables.py`). Never download from Wowhead or foreverchanges
  by script, and never use another addon's code or data (D-03, D-04).
- Subagents only `opus-medium` or `sonnet-medium`, never Fable, no nested agents (DECISIONS D-31).
