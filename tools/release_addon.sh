#!/usr/bin/env bash
# Copies the committed addon (HEAD of Amisia/) into the release folder that Syncthing sends to
# the PC. Work in progress stays on the N100; only a finished version reaches the game.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REL="${AMISIA_RELEASE:-$HOME/addons/_release/Amisia}"
cd "$ROOT"
if ! git diff --quiet HEAD -- Amisia; then
    echo "Amisia/ has uncommitted changes; commit them first" >&2
    exit 1
fi
mkdir -p "$REL"
# everything but the Syncthing marker and ignore file goes, then HEAD comes back
find "$REL" -mindepth 1 -maxdepth 1 ! -name .stfolder ! -name .stignore -exec rm -rf {} +
git archive HEAD Amisia | tar -x --strip-components=1 -C "$REL"
echo "released $(grep -m1 '^## Version' Amisia/Amisia.toc | cut -d' ' -f3) ($(git rev-parse --short HEAD)) to $REL"
