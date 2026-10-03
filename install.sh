#!/bin/bash
# Hook omarchy-mac into the places Omarchy loads from. Everything points back at
# this checkout, so editing it and running `hyprctl reload` is the whole update.

set -euo pipefail

# Empty when piped from curl: the script then has no file, and no checkout.
src=${BASH_SOURCE[0]:-}
repo=""
[[ -n $src && -f $src ]] && repo=$(cd "$(dirname "$src")" && pwd)
toggles="$HOME/.local/state/omarchy/toggles/hypr"

fail() { echo "omarchy-mac: $*" >&2; exit 1; }

# Piped from curl there is no checkout beside this script, so fetch one (or
# update it) and run the installer from there.
if [[ -z $repo || ! -f $repo/hypr/omarchy-mac.lua ]]; then
  command -v git >/dev/null || fail "missing git"
  dest=${OMARCHY_MAC_DIR:-$HOME/.local/share/omarchy-mac}
  if [[ -d $dest/.git ]]; then
    git -C "$dest" pull --ff-only -q || fail "could not update $dest"
  else
    git clone -q https://github.com/nchudleigh/omarchy-mac.git "$dest" || fail "could not clone into $dest"
  fi
  exec bash "$dest/install.sh"
fi

# Omarchy 4 configures Hyprland in Lua and loads the toggles directory last.
# Older, hyprland.conf-based releases have neither, and nothing here would load.
omarchy_path=${OMARCHY_PATH:-/usr/share/omarchy}
[[ -f $omarchy_path/default/hypr/toggles.lua ]] || fail "needs Omarchy 4 or newer (Lua Hyprland config)"
for cmd in hyprctl omarchy-menu-keybindings omarchy-menu-select wl-paste gawk; do
  command -v "$cmd" >/dev/null || fail "missing $cmd"
done

# Macifier binds the same keys from the same directory, so both would fire.
if compgen -G "$toggles/macifier-*.lua" >/dev/null; then
  fail "Macifier is active; run 'omarchy-macifier preset off' first"
fi

mkdir -p "$toggles" "$HOME/.local/bin"

# Omarchy lists this directory with `find -type f`, which skips symlinks, so
# the toggle is a real file that loads the checkout.
rm -f "$toggles/omarchy-mac.lua"
printf -- '-- Written by omarchy-mac install.sh.\ndofile([[%s]])\n' "$repo/hypr/omarchy-mac.lua" > "$toggles/omarchy-mac.lua"
ln -sfn "$repo/bin/mac-keybindings" "$HOME/.local/bin/mac-keybindings"
ln -sfn "$repo/bin/mac-paste" "$HOME/.local/bin/mac-paste"

# A new file in the toggles directory registers its bindings only on reload.
hyprctl reload >/dev/null
errors=$(hyprctl configerrors)
if [[ -n ${errors//[[:space:]]/} ]]; then
  echo "$errors" >&2
  exit 1
fi

echo "omarchy-mac installed."
