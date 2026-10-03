# omarchy-mac

Mac-style keys, scrolling, gestures and Launchpad for my Omarchy setup.

Most of it is extracted from [Macifier](https://github.com/omeganter/macifier)
by Alvaro Antolinez (MIT, commit `cf9c0cd`), cut down to the parts I use and
merged with a few bindings of my own.

## What it does

Super is ⌘. With `keyd` mapping Left Alt to Super, that is the key next to
Space.

| Keys | Does |
|---|---|
| ⌘A ⌘B ⌘D ⌘E ⌘I ⌘N ⌘R ⌘U ⌘Y ⌘Z | Send Ctrl + the same letter (select all, bold, undo…) |
| ⌘⇧Z | Redo |
| ⌘T | New tab. Floating/tiling moves to Ctrl+Alt+T |
| ⌘L | Address bar. Workspace layout moves to Ctrl+Alt+L |
| ⌘Q | Close window |
| ⌘W | Close tab; closes the window when no tab closed |
| ⌘V | Paste, including images into terminal apps like Claude Code |
| ⌘K | Omarchy's keybindings list in Mac key names |
| ⌘⌥A | Launchpad |

In terminals the ⌘-letter keys do nothing, because Ctrl+Z, Ctrl+D and friends
mean something else there. ⌘W closes the terminal window, and ⌘V pastes text
with Shift+Insert unless the clipboard holds an image.

Trackpad:

- Natural scrolling.
- Three fingers sideways moves between workspaces.
- Four fingers pinched in opens Launchpad.

## Install

```bash
git clone git@github.com:nchudleigh/omarchy-mac.git ~/Development/omarchy-mac
~/Development/omarchy-mac/install.sh
```

`install.sh` links three things, so editing the checkout and running
`hyprctl reload` is the whole update:

| Link | Points at |
|---|---|
| `~/.local/state/omarchy/toggles/hypr/omarchy-mac.lua` | `hypr/omarchy-mac.lua`, loaded after `~/.config/hypr/bindings.lua` |
| `~/.local/bin/mac-keybindings` | `bin/mac-keybindings` |
| `~/.config/omarchy/plugins/mac-launchpad` | `launchpad/`, the Launchpad overlay |

QML changes to Launchpad need `omarchy restart shell`.

## Remove

```bash
~/Development/omarchy-mac/uninstall.sh
```

## Licence

MIT. See [LICENSE](LICENSE).
