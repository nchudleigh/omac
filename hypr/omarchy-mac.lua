-- omarchy-mac: Mac-style keys, scrolling and gestures for Omarchy.
--
-- install.sh loads this file from ~/.local/state/omarchy/toggles/hypr/, which
-- Omarchy loads after ~/.config/hypr/bindings.lua. Run `hyprctl reload` after
-- editing it.
--
-- Super is ⌘ here. With keyd mapping Left Alt to Super, that is the key next
-- to Space, where ⌘ sits on a Mac keyboard.
--
-- The ⌘-letter shortcuts and their terminal rule follow Macifier
-- (github.com/omeganter/macifier).

-- Same send technique as Omarchy's own clipboard bindings, including the
-- down/up split that works around Hyprland leaving synthetic key state stuck
-- (hyprwm/Hyprland#14099).
local function send_once(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end

-- Dynamic tags carry a trailing "*".
local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

-- --------------------------------------------------------------- ⌘ + letter
--
-- Each sends Ctrl + the same letter. In a terminal those control codes mean
-- something else (Ctrl+Z suspends, Ctrl+D closes the shell), so do nothing
-- there rather than the wrong thing.
local function forward(mods, key)
  return function()
    if active_window_is_terminal() then
      return
    end
    send_once(mods, key)
  end
end

o.bind("SUPER + A", "Select all", forward("CTRL", "A"))
o.bind("SUPER + B", "Bold", forward("CTRL", "B"))
o.bind("SUPER + D", "Duplicate / bookmark", forward("CTRL", "D"))
o.bind("SUPER + E", "Search / edit", forward("CTRL", "E"))
o.bind("SUPER + I", "Italic", forward("CTRL", "I"))
o.bind("SUPER + N", "New", forward("CTRL", "N"))
o.bind("SUPER + R", "Reload", forward("CTRL", "R"))
o.bind("SUPER + U", "Underline", forward("CTRL", "U"))
o.bind("SUPER + Y", "Redo (Windows-style)", forward("CTRL", "Y"))
o.bind("SUPER + Z", "Undo", forward("CTRL", "Z"))
o.bind("SUPER + SHIFT + Z", "Redo", forward("CTRL SHIFT", "Z"))

-- macOS quits the application. Hyprland has no notion of one, so closing the
-- window is the closest honest equivalent.
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- These letters hold Omarchy window bindings, which move to CTRL + ALT + the
-- same letter.
hl.unbind("SUPER + T")
o.bind("CTRL + ALT + T", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))
o.bind("SUPER + T", "New tab", forward("CTRL", "T"))

hl.unbind("SUPER + L")
o.bind("CTRL + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")
o.bind("SUPER + L", "Address bar", forward("CTRL", "L"))

-- ---------------------------------------------------------------- ⌘ + arrow
--
-- Caret moves as on a Mac: line start and end, document top and bottom, and
-- with ⇧ the same moves select. In a terminal only ⌘← and ⌘→ apply, as Home
-- and End, which shells and Claude Code read as line start and end.
local function caret(mods, key, in_terminal)
  return function()
    if active_window_is_terminal() and not in_terminal then
      return
    end
    send_once(mods, key)
  end
end

local arrows = {
  { key = "LEFT", dir = "l", to = "Home", where = "left", swap = "to the left" },
  { key = "RIGHT", dir = "r", to = "End", where = "right", swap = "to the right" },
  { key = "UP", dir = "u", to = "Home", ctrl = true, where = "above", swap = "up" },
  { key = "DOWN", dir = "d", to = "End", ctrl = true, where = "below", swap = "down" },
}

for _, a in ipairs(arrows) do
  -- Omarchy's window focus and swap move to CTRL + ALT, as ⌘T and ⌘L do.
  hl.unbind("SUPER + " .. a.key)
  hl.unbind("SUPER + SHIFT + " .. a.key)
  o.bind("CTRL + ALT + " .. a.key, "Focus on " .. a.where .. " window", hl.dsp.focus({ direction = a.dir }))
  o.bind("CTRL + ALT + SHIFT + " .. a.key, "Swap window " .. a.swap, hl.dsp.window.swap({ direction = a.dir }))

  local mods = a.ctrl and "CTRL" or ""
  local label = a.ctrl and (a.key == "UP" and "Document start" or "Document end")
    or (a.key == "LEFT" and "Line start" or "Line end")
  o.bind("SUPER + " .. a.key, label, caret(mods, a.to, not a.ctrl))
  o.bind("SUPER + SHIFT + " .. a.key, "Select to " .. label:lower(), caret(mods == "" and "SHIFT" or "CTRL SHIFT", a.to, false))
end

-- ⌥← and ⌥→ move by word, ⇧ to select. Linux spells that Ctrl+arrow, which
-- bash reads as a word move too, so the plain move also works in terminals.
for _, key in ipairs({ "LEFT", "RIGHT" }) do
  local side = key == "LEFT" and "back" or "forward"
  o.bind("ALT + " .. key, "Word " .. side, caret("CTRL", key, true))
  o.bind("ALT + SHIFT + " .. key, "Select word " .. side, caret("CTRL SHIFT", key, false))
end

-- Taking ⌥← and ⌥→ costs browsers their Alt+arrow back and forward, so give
-- them the Mac keys for it, ⌘[ and ⌘].
o.bind("SUPER + BRACKETLEFT", "Back", caret("ALT", "LEFT", false))
o.bind("SUPER + BRACKETRIGHT", "Forward", caret("ALT", "RIGHT", false))

-- ⇧⌘] and ⇧⌘[ switch tabs, as in Safari and Chrome on a Mac.
o.bind("SUPER + SHIFT + BRACKETRIGHT", "Next tab", caret("CTRL", "Tab", false))
o.bind("SUPER + SHIFT + BRACKETLEFT", "Previous tab", caret("CTRL SHIFT", "Tab", false))

-- ---------------------------------------------------------------------- ⌘W
--
-- Close the tab, or the window when no tab closed. Terminals use Ctrl+W to
-- delete a word, so there it closes the window.
local function close_tab_or_window()
  local window = hl.get_active_window()
  if not window then
    return
  end

  if active_window_is_terminal() then
    hl.dispatch(hl.dsp.window.close())
    return
  end

  local address, title = window.address, window.title
  send_once("CTRL", "W")

  -- Browsers close the window on the last tab themselves, and two tabs can share
  -- a title ("New Tab"), which would fool the check below.
  local class = (window.class or ""):lower()
  for _, browser in ipairs({ "helium", "chrom", "firefox", "brave", "zen" }) do
    if class:find(browser, 1, true) then
      return
    end
  end

  -- A closed tab changes the title, and a closed last tab or an unsaved-changes
  -- dialog moves focus. Same window with the same title means Ctrl+W did nothing.
  hl.timer(function()
    local now = hl.get_active_window()
    if now and now.address == address and now.title == title then
      hl.dispatch(hl.dsp.window.close())
    end
  end, { timeout = 300, type = "oneshot" })
end

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close tab", close_tab_or_window)

-- ---------------------------------------------------------------------- ⌘V
--
-- Omarchy's universal paste sends Shift+Insert in terminals, which only pastes
-- text. Terminal apps like Claude Code read a clipboard image on Ctrl+V, so
-- mac-paste sends that when the clipboard holds an image.
--
-- Never check the clipboard from here: wl-paste needs Hyprland to answer, so
-- waiting on it from the config freezes the whole desktop. mac-paste runs as
-- its own process and sends the keys back with hyprctl.
local function universal_paste()
  if active_window_is_terminal() then
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/mac-paste")
  else
    send_once("CTRL", "V")
  end
end

hl.unbind("SUPER + V")
o.bind("SUPER + V", "Universal paste", universal_paste)

-- -------------------------------------------------------------- Keybindings
--
-- The same list as Omarchy's, in Mac menu symbols: ⇧⌘↩, not
-- SUPER SHIFT + RETURN.
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keybindings", "mac-keybindings")

-- ------------------------------------------------------- Trackpad scrolling
--
-- macOS has shipped natural scrolling since 2011; Omarchy ships PC-style.
hl.config({ input = { touchpad = { natural_scroll = true } } })

-- ----------------------------------------------------------------- Gestures
--
-- Two fingers can never be a gesture: libinput reads them as scrolling, and
-- only three or more as a swipe.

-- Three fingers sideways moves between workspaces, following your fingers.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- As on a Mac, a slow drag is a peek: it snaps back unless it passes half the
-- screen. A quick flick commits however short it is. Hyprland's default flick
-- speed (30) is so high that short flicks snap back too.
hl.config({
  gestures = {
    workspace_swipe_min_speed_to_force = 10,
    workspace_swipe_cancel_ratio = 0.5,
  },
})

-- Omarchy turns workspace animations off, so a released swipe jumps the rest
-- of the way. Slide it home instead, ease-out cubic, in 180 ms (speed is in
-- tenths of a second). This also animates Super+1..9 switches.
hl.curve("easeOutCubic", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.8, bezier = "easeOutCubic", style = "slide" })
