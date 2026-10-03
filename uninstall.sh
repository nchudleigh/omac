#!/bin/bash
# Remove everything install.sh linked, and Launchpad's recents.

set -euo pipefail

omarchy plugin disable local.mac-launchpad >/dev/null 2>&1 || true

rm -f "$HOME/.local/state/omarchy/toggles/hypr/omarchy-mac.lua"
rm -f "$HOME/.local/bin/mac-keybindings"
rm -f "$HOME/.config/omarchy/plugins/mac-launchpad"
rm -rf "$HOME/.local/state/omarchy-mac"

hyprctl reload >/dev/null

echo "omarchy-mac removed."
