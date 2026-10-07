# Changelog

What changed in each release of the Amisia addon, from the commit subjects.

## 2.7.1 (2026-10-07)

- Addon in folders: Core/, Raid/, Gear/, Collect/, Data/ (every generated file), UI/ and UI/Pages/ (git mv, TOC order unchanged); build scripts, tests, syntax.cjs (recursive) and the LICENSES head on the new paths
- Version only in the TOC: Core reads ## Version through C_AddOns.GetAddOnMetadata (fallback GetAddOnMetadata); the test stub answers from the TOC, test_version_toc covers the fallback and the missing literal
- luacheck: .luacheckrc (lua51, the client globals the addon reads, its own global writes) and its findings fixed without behaviour change: helpers shadowed by locals renamed (Sync isList, Collector rewardList, SoftRes splitLines), unused locals, captures and the dead Drops report() removed
- tools/build.py: one entry point - data (the builds in order, skips without client tables, diff summary), check (syntax, addon and tool tests, UTF-8, TOC against the folder, luacheck) and release (clean tree, TOC version, check, zip, CHANGELOG.md, commit, push, release_addon.sh; undone on failure); tests with a temporary repository; README and CLAUDE.md
- GitHub Actions: check.yml runs tools/build.py check (Python with lupa and pytest, node with luaparse, luacheck from apt) on push and pull request; deploys nothing, Pages unchanged
