#!/bin/bash
# Hook omarchy-mac into the places Omarchy loads from. Everything points back at
# this checkout, so editing it and running `hyprctl reload` is the whole update.

set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
toggles="$HOME/.local/state/omarchy/toggles/hypr"
plugin="$HOME/.config/omarchy/plugins/mac-launchpad"

mkdir -p "$toggles" "$HOME/.local/bin" "$HOME/.config/omarchy/plugins" "$HOME/.local/state/omarchy-mac"

# Omarchy lists this directory with `find -type f`, which skips symlinks, so
# the toggle is a real file that loads the checkout.
rm -f "$toggles/omarchy-mac.lua"
printf -- '-- Written by omarchy-mac install.sh.\ndofile([[%s]])\n' "$repo/hypr/omarchy-mac.lua" > "$toggles/omarchy-mac.lua"
ln -sfn "$repo/bin/mac-keybindings" "$HOME/.local/bin/mac-keybindings"
ln -sfn "$repo/launchpad" "$plugin"

# The rescan finishes after it returns, so the first enable can find no plugin.
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
for _ in {1..20}; do
  omarchy plugin enable local.mac-launchpad >/dev/null 2>&1 && break
  sleep 0.25
done
omarchy plugin list | grep -q '^local.mac-launchpad *enabled' || {
  echo "could not enable local.mac-launchpad" >&2
  exit 1
}

# A new file in the toggles directory registers its bindings only on reload.
hyprctl reload >/dev/null
errors=$(hyprctl configerrors)
if [[ -n ${errors//[[:space:]]/} ]]; then
  echo "$errors" >&2
  exit 1
fi

echo "omarchy-mac installed."
