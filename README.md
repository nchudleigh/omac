<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/icon-dark.svg">
    <img src="docs/images/icon-light.svg" width="72" height="72" alt="omac">
  </picture>
</p>

<h1 align="center">omac</h1>

<p align="center">
  <strong>Mac hands on Omarchy.</strong><br>
  ⌘ shortcuts, Mac caret movement and Mac-feel workspace swipes, in one file you can read.
</p>

<p align="center">
  <a href="https://github.com/tcballard/omarchy-badges"><img src="https://raw.githubusercontent.com/tcballard/omarchy-badges/85f859029e236e784e7b05ada6dbe73506d07a91/badges/v1/built-for-omarchy.svg" alt="Built for Omarchy"></a>
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#keys">Keys</a> ·
  <a href="#trackpad">Trackpad</a> ·
  <a href="#how-it-works">How it works</a>
</p>

Omarchy already gives you ⌘C, ⌘V and ⌘X. This adds the rest of what a Mac
user's hands reach for without thinking: select all, undo and redo, new tab, the
address bar, ⌘ and ⌥ arrows that move the caret, a ⌘W that closes the tab rather
than the window, and a ⌘V that pastes screenshots into Claude Code. Then the
trackpad scrolls the right way and workspaces swipe like they do on a Mac.

- **⌘ + letter.** Twelve Mac shortcuts, each sent to the app as Ctrl + the same letter.
- **Mac caret movement.** ⌘ arrows to line and document ends, ⌥ arrows by word, ⇧ to select.
- **Tab-aware ⌘W.** Closes the tab, and the window once there is no tab left to close.
- **Image paste in terminals.** ⌘V sends Ctrl+V when the clipboard holds an image.
- **Mac menu symbols.** ⌘K lists every shortcut as `⇧⌘↩`, not `SUPER SHIFT + RETURN`.
- **Workspace swipes that feel like a Mac.** A three-finger flick switches, a slow drag peeks and snaps back, and either way it slides home in 180 ms.
- **Natural scrolling.** Content follows your fingers.

Everything binds in one Lua file, [`hypr/omac.lua`](hypr/omac.lua), so what a
key does is one search away, and removing the file removes all of it.

## Install

Needs Omarchy 4 or newer, the release that configures Hyprland in Lua.

```bash
omarchy plugin add https://github.com/nchudleigh/omac --enable
```

The plugin runs [`install.sh`](install.sh) from its folder every time the shell
starts: the first run hooks the bindings into Hyprland, and later runs find
everything in place and do nothing. If something stops it, such as an Omarchy
without the Lua config, a desktop notification says why.

Without the plugin system, the same installer works on its own:

```bash
curl -fsSL https://raw.githubusercontent.com/nchudleigh/omac/main/install.sh | bash
```

That clones the repo into `~/.local/share/omac` and installs from there. Run it
again to update. To keep the checkout somewhere else, clone it yourself and run
its `install.sh`; the installer points back at whichever checkout ran it, so
`git pull` and `hyprctl reload` is the whole update.

<details>
<summary>What the installer touches</summary>

| Path | What it is |
|---|---|
| `~/.local/state/omarchy/toggles/hypr/omac.lua` | One line that loads `hypr/omac.lua` from the checkout |
| `~/.local/bin/mac-keybindings` | Link to `bin/mac-keybindings`, the ⌘K list |
| `~/.local/bin/mac-paste` | Link to `bin/mac-paste`, the terminal half of ⌘V |

Nothing is written to `~/.config/hypr` or `/usr/share/omarchy`.

</details>

## Remove

Installed as a plugin, run the uninstaller first, or the plugin hooks omac back
in on the next shell start:

```bash
~/.config/omarchy/plugins/io.github.nchudleigh.omac/uninstall.sh
omarchy plugin remove io.github.nchudleigh.omac
```

Installed with curl:

```bash
~/.local/share/omac/uninstall.sh && rm -rf ~/.local/share/omac
```

The uninstaller removes the three paths above and reloads Hyprland, which puts
Omarchy's own bindings back.

## Keys

Super is ⌘. On a Mac keyboard that is already the key beside Space; on a PC
keyboard it is the Windows key, unless you [move it](#putting--next-to-space).

| Keys | Does |
|---|---|
| ⌘A | Select all |
| ⌘Z / ⌘⇧Z / ⌘Y | Undo / redo / redo, Windows-style |
| ⌘B ⌘I ⌘U | Bold, italic, underline |
| ⌘N | New |
| ⌘T | New tab |
| ⌘L | Address bar |
| ⌘R | Reload |
| ⌘D | Duplicate, or bookmark in a browser |
| ⌘E | Search or edit, depending on the app |
| ⌘← / ⌘→ | Line start / line end |
| ⌘↑ / ⌘↓ | Document start / document end |
| ⇧⌘ + arrow | Select to the same place |
| ⌥← / ⌥→ | Word back / word forward, ⇧ to select |
| ⌘[ / ⌘] | Back / forward |
| ⇧⌘[ / ⇧⌘] | Previous tab / next tab |
| ⌘W | Close tab, then the window |
| ⌘Q | Close window |
| ⌘V | Paste, images included |
| ⌘K | Keybindings, in Mac menu symbols |

Some of these keys held Omarchy window bindings, which move to Ctrl+Alt rather
than disappearing:

| Omarchy action | Was | Now |
|---|---|---|
| Toggle floating/tiling | Super+T | Ctrl+Alt+T |
| Toggle workspace layout | Super+L | Ctrl+Alt+L |
| Focus window by direction | Super+arrows | Ctrl+Alt+arrows |
| Swap window by direction | Super+Shift+arrows | Ctrl+Alt+Shift+arrows |

⌥← and ⌥→ take Alt+arrow, which browsers use for back and forward, so ⌘[ and ⌘]
do that instead, as on a Mac.

### In terminals

The ⌘-letter keys do nothing in a terminal. Ctrl+Z suspends a job, Ctrl+D closes
the shell and Ctrl+A moves to the start of the line, so sending them would be
worse than doing nothing. ⌘← and ⌘→ still work there, as Home and End, and ⌥←
and ⌥→ still move by word, because bash reads Ctrl+arrow as a word move. "Terminal" means Omarchy's own `terminal` window tag,
the same one its clipboard bindings use.

⌘W closes the terminal window, because Ctrl+W there deletes a word. ⌘V pastes
text with Shift+Insert, as Omarchy does, unless the clipboard holds an image:
then it sends Ctrl+V, which is what Claude Code and other terminal apps read an
image on. The clipboard check runs in its own process, `bin/mac-paste`, and gives
up after half a second. It never runs inside Hyprland's config: `wl-paste` needs
Hyprland to answer, so waiting on it from there freezes the whole desktop.

### How ⌘W knows

Hyprland cannot see an app's tabs, so ⌘W sends Ctrl+W and looks again 300 ms
later. A closed tab changes the window title; a closed last tab, or an
unsaved-changes dialog, moves focus. Same window, same title means nothing
closed, and then it closes the window.

Browsers skip the second look. They close the window on the last tab themselves,
and two tabs called "New Tab" would otherwise read as nothing closing. The same
can happen in any other app with two identically titled tabs: ⌘W closes the
window instead of one of them.

### Putting ⌘ next to Space

On a PC keyboard, [`extras/keyd/mac-modifiers.conf`](extras/keyd/mac-modifiers.conf)
swaps Left Alt and the Windows key with [keyd](https://github.com/rvaiya/keyd), so
⌘ lands where a Mac keeps it:

```bash
omarchy pkg add keyd
sudo cp extras/keyd/mac-modifiers.conf /etc/keyd/default.conf
sudo systemctl enable --now keyd
```

It is not part of the install, because it changes every keyboard on the machine
and is wrong for an Apple one.

## Trackpad

| Gesture | Does |
|---|---|
| Two fingers | Scroll, naturally: content follows your fingers |
| Three fingers sideways | Move between workspaces, following your fingers. A quick flick switches; a slow drag peeks and snaps back unless it passes halfway |

When you let go, the workspace slides the rest of the way with an ease-out cubic in 180 ms. Omarchy ships workspace animations off, so this also animates Super+1–9.

Two fingers can never be a gesture here. libinput reads two fingers as scrolling
and only three or more as a swipe, so nothing in Hyprland ever sees a two-finger
swipe.

## How it works

Omarchy loads `~/.local/state/omarchy/toggles/hypr/` after your own
`~/.config/hypr/bindings.lua`, so the bindings here win where both claim a key,
and every key they take over is released with `hl.unbind` first rather than left
to fire twice.

The file in that directory is one `dofile` line rather than a symlink, because
Omarchy lists the directory with `find -type f`, which skips symlinks.

## Deliberately absent

- **⌘Tab app switching.** Super+Tab stays Omarchy's workspace switcher. Moving
  workspace cycling to Super+Alt+Tab collides with Omarchy's next-window-in-group.
- **⌘F, ⌘S, ⌘P, ⌘O, ⌘G.** Each holds an Omarchy window binding (full screen,
  scratchpad and so on) that people use daily. Copy the ⌘T pattern in the Lua
  file to take one.
- **Caps Lock as Caps Lock.** Omarchy makes it Compose, and the obvious fix, Compose
  on right ⌘, breaks anything bound to that key.
- **Media keys first on the top row.** That needs Apple's `hid_apple` driver and a
  root-owned file.

## Credits

Thanks to [Macifier](https://github.com/omeganter/macifier) by **Alvaro
Antolinez**, where this started. Its ⌘-letter shortcuts, the rule that keeps them
out of terminals, and the idea of a keybindings list in Mac terms shaped the first
version here. If you want a dock, a ⌘Tab switcher and a bar panel to flip it all,
Macifier has them.
