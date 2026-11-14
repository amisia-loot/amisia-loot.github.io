#!/usr/bin/env bash
# Copies the committed addon (HEAD of Amisia/, Amisia_Raid/ and Amisia_Gear/: the core and its modules,
# F-202) into the release folder that Syncthing sends to the PC, one subfolder each
# (_release/Amisia/Amisia, _release/Amisia/Amisia_Raid, _release/Amisia/Amisia_Gear). Work in progress
# stays on the N100; only a finished version reaches the game.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REL="${AMISIA_RELEASE:-$HOME/addons/_release/Amisia}"
FOLDERS=(Amisia Amisia_Raid Amisia_Gear)
cd "$ROOT"
if ! git diff --quiet HEAD -- "${FOLDERS[@]}"; then
    echo "${FOLDERS[*]}: uncommitted changes; commit them first" >&2
    exit 1
fi
mkdir -p "$REL"
# everything but the Syncthing marker and ignore file goes, then HEAD comes back
find "$REL" -mindepth 1 -maxdepth 1 ! -name .stfolder ! -name .stignore -exec rm -rf {} +
git archive HEAD "${FOLDERS[@]}" | tar -x -C "$REL"
echo "released $(grep -m1 '^## Version' Amisia/Amisia.toc | cut -d' ' -f3) ($(git rev-parse --short HEAD)) to $REL (${FOLDERS[*]})"
