-- omarchy-mac: Mac-style keys, scrolling and gestures for Omarchy.
--
-- install.sh loads this file from ~/.local/state/omarchy/toggles/hypr/, which
-- Omarchy loads after ~/.config/hypr/bindings.lua. Run `hyprctl reload` after
-- editing it.
--
-- Super is ⌘ here. With keyd mapping Left Alt to Super, that is the key next
-- to Space, where ⌘ sits on a Mac keyboard.
--
-- The ⌘ keys, scrolling, gestures and the Keybindings screen come from
-- Macifier (github.com/omeganter/macifier, MIT), commit cf9c0cd.

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
-- text. Terminal apps like Claude Code read a clipboard image on Ctrl+V, so send
-- that when the clipboard holds an image.
local function clipboard_has_image()
  local pipe = io.popen("timeout 0.2 wl-paste --list-types 2>/dev/null")
  if not pipe then
    return false
  end
  local types = pipe:read("*a")
  pipe:close()
  return types:find("image/", 1, true) ~= nil
end

local function universal_paste()
  if active_window_is_terminal() and not clipboard_has_image() then
    send_once("SHIFT", "Insert")
  else
    send_once("CTRL", "V")
  end
end

hl.unbind("SUPER + V")
o.bind("SUPER + V", "Universal paste", universal_paste)

-- -------------------------------------------------------------- Keybindings
--
-- The same list as Omarchy's, worded in Mac key names: Shift-Command-Return,
-- not SUPER SHIFT + RETURN.
hl.unbind("SUPER + K")
o.bind("SUPER + K", "Keybindings", "mac-keybindings")

-- ---------------------------------------------------------------- Launchpad
o.bind("SUPER + ALT + A", "Launchpad", "omarchy-shell local.mac-launchpad toggle")

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

-- A quick flick commits, as on a Mac. Hyprland's defaults need a fast swipe
-- (speed 30) or half the screen dragged (ratio 0.5), so short flicks snap back.
hl.config({
  gestures = {
    workspace_swipe_min_speed_to_force = 5,
    workspace_swipe_cancel_ratio = 0.15,
  },
})

-- Four fingers pinched in opens Launchpad, as on a Mac.
hl.gesture({ fingers = 4, direction = "pinchin", action = function()
  hl.exec_cmd("omarchy-shell -q local.mac-launchpad toggle")
end })
