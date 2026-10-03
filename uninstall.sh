#!/bin/bash
# Remove everything install.sh put in place. As an Omarchy plugin, run this
# before `omarchy plugin remove`, or the plugin installs omac again on the next
# shell start.

set -euo pipefail

rm -f "$HOME/.local/state/omarchy/toggles/hypr/omac.lua"
rm -f "$HOME/.local/bin/mac-keybindings" "$HOME/.local/bin/mac-paste"

hyprctl reload >/dev/null

echo "omac removed."
