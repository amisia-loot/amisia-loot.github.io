#!/usr/bin/env bash
# Links the Amisia auto data timer into the systemd user manager and starts it (DECISIONS D-51).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dest="$HOME/.config/systemd/user"
mkdir -p "$dest"
for unit in amisia-auto-data.service amisia-auto-data.timer; do
    ln -sf "$here/$unit" "$dest/$unit"
done
systemctl --user daemon-reload
systemctl --user enable --now amisia-auto-data.timer
systemctl --user list-timers amisia-auto-data.timer --no-pager
