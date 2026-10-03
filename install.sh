#!/bin/bash
# Hook omac into the places Omarchy loads from. Everything points back at this
# checkout, so editing it and running `hyprctl reload` is the whole update.
#
# The Omarchy plugin runs this on every shell start, so a run that finds
# everything already in place changes nothing and reloads nothing.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
toggles="$HOME/.local/state/omarchy/toggles/hypr"
bin="$HOME/.local/bin"

fail() { echo "omac: $*" >&2; exit 1; }

[[ -f $repo/hypr/omac.lua ]] || fail "run install.sh from an omac checkout"

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

mkdir -p "$toggles" "$bin"
changed=no

# Before the rename this was omarchy-mac; two hooks would bind every key twice.
if [[ -e $toggles/omarchy-mac.lua ]]; then
  rm -f "$toggles/omarchy-mac.lua"
  changed=yes
fi

# Omarchy lists this directory with `find -type f`, which skips symlinks, so
# the toggle is a real file that loads the checkout.
hook=$(printf -- '-- Written by omac install.sh.\ndofile([[%s]])' "$repo/hypr/omac.lua")
if [[ ! -f $toggles/omac.lua || $(<"$toggles/omac.lua") != "$hook" ]]; then
  printf '%s\n' "$hook" > "$toggles/omac.lua"
  changed=yes
fi

for tool in mac-keybindings mac-paste; do
  if [[ $(readlink "$bin/$tool" 2>/dev/null) != "$repo/bin/$tool" ]]; then
    ln -sfn "$repo/bin/$tool" "$bin/$tool"
    changed=yes
  fi
done

if [[ $changed == no ]]; then
  echo "omac is already installed."
  exit 0
fi

# A new file in the toggles directory registers its bindings only on reload.
hyprctl reload >/dev/null
errors=$(hyprctl configerrors)
if [[ -n ${errors//[[:space:]]/} ]]; then
  echo "$errors" >&2
  exit 1
fi

echo "omac installed."
