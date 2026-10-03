#!/bin/bash
# Remove everything install.sh put in place.

set -euo pipefail

rm -f "$HOME/.local/state/omarchy/toggles/hypr/omarchy-mac.lua"
rm -f "$HOME/.local/bin/mac-keybindings"
rm -f "$HOME/.local/bin/mac-paste"

hyprctl reload >/dev/null

echo "omarchy-mac removed."
