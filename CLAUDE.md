# Amisia loot ledger

- The claude.ai artifact twin is built from `index.html` with `tools/build_twin.py`, never edited by hand.
- After changing `index.html`, `tools/build_twin.py`, anything in `data/`, `favicon.png` or `logo.png`, rebuild and republish the twin, then run `python tools/twin_stamp.py --published`.
- `python tools/twin_stamp.py` says whether the twin is behind; the pre-push hook prints the same warning.
- Bump `BUILD_ID` in `index.html` whenever a data file changes, or browsers keep the cached copy.
- Tests: `python -m pytest tools/tests -q`.
