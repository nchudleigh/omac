import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Launchpad — every installed application, in a grid, full screen.
// From Macifier (github.com/omeganter/macifier, MIT), commit cf9c0cd.
//
// The one Mac staple with nothing to adopt. Fifteen docks and a dozen Mission
// Controls exist for Omarchy; Launchpad has none published, so this is a build
// rather than a recommendation (docs/SETTINGS.md §8).
//
// It is also the cheapest of the big Mac surfaces to get right, because every
// hard part was already solved next door: the dock resolves .desktop icons and
// launches entries, and the switcher proved an overlay can hold exclusive
// keyboard focus. What is left is layout and scrolling.
//
// It scrolls down, not sideways. macOS 26 retired paged Launchpad for the Apps
// view: a row of recently opened apps on top, then everything else in one
// continuous list read top to bottom.
//
// Deliberately not a fuzzy launcher. Omarchy's menu and Spotlight both already
// do search-first; Launchpad's whole point is that you *look* rather than type,
// so the grid is the feature and the filter is the fallback.
Item {
  id: root

  property bool opened: false
  property var allApps: []
  property string query: ""

  // One index across Recents and the grid: 0..recents.length-1 is the Recents
  // row, everything after is the grid. A single number is what lets the arrow
  // keys cross from one to the other without either knowing about the other.
  property int index: 0

  // The selection square means "Enter launches this", so it only appears
  // once the keyboard is actually in play. Showing it from the moment
  // Launchpad opens marks an app nobody chose, and a Mac shows nothing
  // until you arrow or type either.
  property bool keyboardNav: false

  // Filled from the window, so the grid adapts to the display instead of
  // assuming the 7x5 a 16:10 Mac happens to use. Rows is only how much of the
  // list shows at once; the list itself scrolls.
  property int columns: 7
  property int rows: 5

  // Cell width carries the icon plus its label; 132 is the smallest that
  // fits two lines of a long application name without clipping. The pitch
  // adds the gap between tiles.
  readonly property int cell: Style.space(132)
  readonly property int pitch: cell + Style.space(10)

  readonly property color foreground: Color.foreground
  readonly property color background: Color.popups ? Color.popups.background : Color.background

  // Reading allApps and query inside the function is what makes this re-run
  // when either changes; QML tracks property reads during evaluation.
  readonly property var shown: root.filterApps()
  readonly property var recents: root.recentApps()
  readonly property int total: recents.length + shown.length

  function filterApps() {
    var q = String(query).trim().toLowerCase()
    if (q.length === 0) return allApps
    var out = []
    for (var i = 0; i < allApps.length; i++) {
      var a = allApps[i]
      // Match the name first and the id second: someone typing "files" means
      // the name, someone typing "nautilus" means the entry.
      if (a.name.toLowerCase().indexOf(q) >= 0 || a.id.toLowerCase().indexOf(q) >= 0) out.push(a)
    }
    return out
  }

  // Every visible application, once, sorted by name. NoDisplay entries are the
  // ones a desktop is explicitly asked not to show — MIME handlers, per-app
  // helpers — and a grid of them is what makes most Linux app menus unusable.
  function loadApps() {
    var vals = (DesktopEntries.applications && DesktopEntries.applications.values) || []
    var seen = ({})
    var out = []
    for (var i = 0; i < vals.length; i++) {
      var e = vals[i]
      if (!e || e.noDisplay) continue
      var id = String(e.id || "").replace(/\.desktop$/, "")
      if (id.length === 0 || seen[id]) continue
      seen[id] = true
      out.push({ id: id, name: String(e.name || id), entry: e })
    }
    out.sort(function(a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1 })
    root.allApps = out
  }

  function iconFor(app) {
    if (app && app.entry) {
      var p = Quickshell.iconPath(app.entry.icon, true)
      if (p && p.length > 0) return p
    }
    var d = Quickshell.iconPath(String(app ? app.id : "").toLowerCase(), true)
    return (d && d.length > 0) ? d : Quickshell.iconPath("application-x-executable", true)
  }

  // --- recents ---------------------------------------------------------------
  //
  // The apps you last opened, newest first — however you opened them. Recording
  // only Launchpad's own launches would miss the dock, the menu, Spotlight and
  // every keybinding, which is most launches, and the row would be a list of
  // what you happened to open *here*. So it listens to Hyprland instead: every
  // new window names its class, and the class resolves to a desktop entry the
  // same way the dock resolves it.
  //
  // Kept in ~/.local/state/omarchy-mac so it survives a shell restart.
  // uninstall.sh deletes it, so nothing is left behind.
  property var recentIds: []
  readonly property int recentsKept: 24

  function recentApps() {
    // Hidden while filtering: the results are what you are reading, and a
    // row of unrelated apps above them would only push them down.
    if (String(query).trim().length > 0) return []
    var byId = ({})
    for (var i = 0; i < allApps.length; i++) byId[allApps[i].id] = allApps[i]
    var out = []
    for (var j = 0; j < recentIds.length && out.length < columns; j++) {
      var a = byId[recentIds[j]]
      if (a) out.push(a)
    }
    return out
  }

  function noteOpened(id) {
    if (!id) return
    var next = [id]
    for (var i = 0; i < recentIds.length && next.length < recentsKept; i++)
      if (recentIds[i] !== id) next.push(recentIds[i])
    // A second window of the app already at the front changes nothing, and
    // rewriting the file for it would be a disk write per terminal tab.
    if (recentIds.length > 0 && recentIds[0] === id && next.length === recentIds.length) return
    recentIds = next
    recentsFile.setText(JSON.stringify({ recent: next }) + "\n")
  }

  // Window class to desktop id — the dock's resolver, minus its fallback to
  // the bare class. A window with no entry has nothing Launchpad could show.
  function entryForClass(cls) {
    var lc = String(cls || "").toLowerCase()
    if (lc.length === 0) return ""
    var tail = lc.indexOf(".") >= 0 ? lc.substring(lc.lastIndexOf(".") + 1) : lc
    var host = ""
    if (lc.indexOf("chrome-") === 0) {
      host = lc.substring(7)
      var cut = host.indexOf("__")
      if (cut > 0) host = host.substring(0, cut)
    }
    var vals = (DesktopEntries.applications && DesktopEntries.applications.values) || []
    var found = ""
    for (var j = 0; j < vals.length; j++) {
      var e = vals[j]
      if (!e || e.noDisplay) continue
      var id = String(e.id || "").replace(/\.desktop$/, "")
      var idl = id.toLowerCase()
      var sc = String(e.startupClass || "").toLowerCase()
      if (sc === lc || idl === lc) return id
      if (!found && idl === tail) found = id
      if (!found && host.length > 0 &&
          String(e.execString || e.command || "").toLowerCase().indexOf(host) >= 0) found = id
    }
    return found
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || event.name !== "openwindow") return
      // ADDRESS,WORKSPACE,CLASS,TITLE — the title may itself hold commas, the
      // class cannot, so split no further than the class.
      var parts = String(event.data || "").split(",")
      if (parts.length < 3) return
      root.noteOpened(root.entryForClass(parts[2]))
    }
  }

  // Seeds the row from what is already open, so it is not empty on first use
  // or after a reboot. Open windows go after what the file remembers, most
  // recently focused first — they are running, but the file knows better
  // which of them you opened last.
  function seedFrom(ids) {
    var next = recentIds.slice()
    for (var i = 0; i < ids.length && next.length < recentsKept; i++)
      if (ids[i] && next.indexOf(ids[i]) < 0) next.push(ids[i])
    if (next.length === recentIds.length) return
    recentIds = next
    recentsFile.setText(JSON.stringify({ recent: next }) + "\n")
  }

  Process {
    id: openWindowsProc
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        try { list = JSON.parse(text) } catch (e) { return }
        list.sort(function(a, b) { return (a.focusHistoryID || 0) - (b.focusHistoryID || 0) })
        var ids = []
        for (var i = 0; i < list.length; i++) ids.push(root.entryForClass(list[i] && list[i].class))
        root.seedFrom(ids)
      }
    }
  }

  // Seeding waits for the file either way, so what it remembers keeps its
  // order ahead of whatever happens to be open.
  FileView {
    id: recentsFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy-mac/launchpad-recents.json"
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        if (d && Array.isArray(d.recent)) root.recentIds = d.recent.map(String)
      } catch (e) {
        root.recentIds = []
      }
      openWindowsProc.running = true
    }
    onLoadFailed: openWindowsProc.running = true
  }

  // --- opening and launching -------------------------------------------------

  function open() {
    loadApps()
    query = ""
    index = 0
    keyboardNav = false
    opened = true
    scroller.toTop()
  }

  function close() { opened = false }
  function toggle() { if (opened) close(); else open() }

  function appAt(i) {
    if (i < recents.length) return recents[i]
    return shown[i - recents.length]
  }

  function launchAt(i) {
    if (i < 0 || i >= total) return
    var a = appAt(i)
    // Same two-step the dock uses: the entry knows how to start itself, and
    // gtk-launch is the fallback for entries Quickshell could not model.
    if (a.entry && a.entry.execute) a.entry.execute()
    else { launchProc.command = ["gtk-launch", a.id]; launchProc.running = true }
    close()
  }

  // --- keyboard --------------------------------------------------------------
  //
  // Left and right walk the one combined list, so the end of Recents runs
  // straight into the first app. Up and down go by row and keep the column,
  // with Recents as row -1 — which is what makes Down from a recent app land
  // under it rather than wherever the flat index happens to fall.

  function rowOf(i) {
    return i < recents.length ? -1 : Math.floor((i - recents.length) / columns)
  }

  function colOf(i) {
    return i < recents.length ? i : (i - recents.length) % columns
  }

  function indexAt(row, col) {
    if (row < 0) return Math.min(col, recents.length - 1)
    return Math.min(recents.length + row * columns + col, total - 1)
  }

  function select(i) {
    if (total === 0) return
    keyboardNav = true
    index = Math.max(0, Math.min(total - 1, i))
    scroller.reveal(index)
  }

  function step(delta) { select(index + delta) }

  function stepRows(delta) {
    if (total === 0) return
    var first = recents.length > 0 ? -1 : 0
    var last = rowOf(total - 1)
    var row = Math.max(first, Math.min(last, rowOf(index) + delta))
    select(indexAt(row, colOf(index)))
  }

  function typed(ch) {
    keyboardNav = true
    query += ch
    index = 0
    scroller.toTop()
  }

  function backspace() {
    if (query.length === 0) return
    query = query.substring(0, query.length - 1)
    index = 0
    scroller.toTop()
  }

  // --- scrolling -------------------------------------------------------------
  //
  // A Mac scroll has three parts and a stock Flickable gives none of them to a
  // trackpad on Wayland: the content tracks the fingers, keeps gliding after
  // they lift, and stretches past the ends and springs back. macOS generates
  // the glide itself, in the toolkit; libinput and Hyprland deliver only the
  // finger movement and a stop. So the glide is generated here, per frame.
  //
  // The GridView is non-interactive and never sees the wheel. Every wheel event
  // in the overlay lands in one handler and goes through this, so the grid, the
  // card margins and the dimmed desktop all scroll identically.
  QtObject {
    id: scroller

    // px per ms, in contentY terms. Positive moves down the list.
    property real velocity: 0
    property double lastEvent: 0

    // macOS's normal deceleration rate, per millisecond — the number behind
    // UIScrollView.DecelerationRate.normal. Lower stops sooner.
    readonly property real friction: 0.998

    readonly property real top: grid.originY
    readonly property real bottom: grid.originY + Math.max(0, grid.contentHeight - grid.height)

    function overshoot() {
      if (grid.contentY < top) return grid.contentY - top
      if (grid.contentY > bottom) return grid.contentY - bottom
      return 0
    }

    function halt() {
      glide.running = false
      settle.stop()
      velocity = 0
    }

    function toTop() {
      halt()
      grid.contentY = top
    }

    // Past an end the content moves less and less for the same finger travel,
    // the rubber band that says "this is the end" without a hard stop.
    function drag(dy) {
      var over = overshoot()
      if (over !== 0 && (dy > 0) === (over > 0)) {
        var give = 1 - Math.min(1, Math.abs(over) / (grid.height * 0.4))
        dy *= 0.5 * give * give
      }
      grid.contentY += dy
    }

    function trackpad(dy, now) {
      glide.running = false
      settle.stop()
      var dt = now - lastEvent
      var v = dt > 0 && dt < 100 ? dy / dt : 0
      // Smoothed, because trackpad events arrive unevenly and the last one
      // alone is a noisy reading of how fast the fingers were moving.
      velocity = dt < 100 ? velocity * 0.4 + v * 0.6 : v
      lastEvent = now
      drag(dy)
      fingersUp.restart()
    }

    // A mouse wheel has no fingers to track: each notch eases a row's worth,
    // and quick notches add up rather than queueing.
    function wheel(dy) {
      halt()
      var from = settle.running ? settle.to : grid.contentY
      settle.to = Math.max(top, Math.min(bottom, from + dy))
      settle.duration = 220
      settle.easing.type = Easing.OutCubic
      settle.start()
    }

    function release() {
      fingersUp.stop()
      if (Date.now() - lastEvent > 80) velocity = 0
      if (Math.abs(velocity) > 0.05) glide.running = true
      else springBack()
    }

    function springBack() {
      velocity = 0
      var over = overshoot()
      if (over === 0) return
      settle.to = over < 0 ? top : bottom
      settle.duration = 380
      settle.easing.type = Easing.OutQuint
      settle.start()
    }

    function reveal(i) {
      halt()
      if (i < root.recents.length) { grid.contentY = top; return }
      var before = grid.contentY
      grid.positionViewAtIndex(i - root.recents.length, GridView.Contain)
      // The top row of the grid is also the row under Recents; scrolling up to
      // it should bring Recents back into view, not stop just short of it.
      if (root.rowOf(i) === 0) grid.contentY = top
      var after = grid.contentY
      if (after === before) return
      grid.contentY = before
      settle.to = after
      settle.duration = 180
      settle.easing.type = Easing.OutCubic
      settle.start()
    }
  }

  // Hyprland reports the fingers lifting as an axis stop, which Qt does not
  // always pass on. A short silence is the reliable signal.
  Timer {
    id: fingersUp
    interval: 60
    onTriggered: scroller.release()
  }

  FrameAnimation {
    id: glide
    running: false
    onTriggered: {
      var dt = Math.min(frameTime * 1000, 50)
      grid.contentY += scroller.velocity * dt
      if (scroller.overshoot() !== 0) {
        // Past an end the glide brakes hard and hands over to the spring.
        scroller.velocity *= Math.pow(0.8, dt / 16)
        if (Math.abs(scroller.velocity) < 0.3) { running = false; scroller.springBack() }
      } else {
        scroller.velocity *= Math.pow(scroller.friction, dt)
        if (Math.abs(scroller.velocity) < 0.02) { running = false; scroller.velocity = 0 }
      }
    }
  }

  NumberAnimation {
    id: settle
    target: grid
    property: "contentY"
  }

  Process { id: launchProc; command: ["true"] }

  IpcHandler {
    target: "local.mac-launchpad"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
  }

  // One tile, for Recents and the grid alike, so the two rows cannot drift
  // apart in size or look.
  component AppTile: Item {
    id: tile
    required property var app
    required property int absolute

    readonly property bool selected: root.keyboardNav && absolute === root.index

    width: root.pitch
    height: root.pitch

    Item {
      anchors.centerIn: parent
      width: root.cell
      height: root.cell

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(6)
        radius: Style.space(16)
        color: tile.selected ? Qt.rgba(1, 1, 1, 0.18)
                             : (hover.hovered ? Qt.rgba(1, 1, 1, 0.09) : "transparent")
      }

      HoverHandler { id: hover }

      Column {
        anchors.centerIn: parent
        spacing: Style.space(8)

        // A plate under every icon. macOS needs none because every
        // Mac icon ships its own filled artwork; a Linux icon theme
        // is a mix, and the flat monochrome outlines in it — the
        // Avahi browsers, HDAJackRetask — disappear into a dark card
        // completely. The plate is what they sit on. It is faint
        // enough that a full-bleed icon like Chromium or Discord
        // still reads as itself rather than as a tile.
        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(72)
          height: Style.space(72)

          Rectangle {
            anchors.centerIn: parent
            width: Style.space(68)
            height: width
            radius: Style.space(18)
            color: root.foreground
            opacity: 0.07
          }

          Image {
            anchors.centerIn: parent
            width: Style.space(64)
            height: Style.space(64)
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 128
            sourceSize.height: 128
            source: root.iconFor(tile.app)
            smooth: true
          }
        }

        Text {
          width: root.cell - Style.space(16)
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: tile.app ? tile.app.name : ""
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          maximumLineCount: 2
          wrapMode: Text.WordWrap
        }
      }

      // Hovering deliberately does NOT move the selection. It used
      // to, and the selection then stuck to whatever tile the pointer
      // last crossed on its way to the search field or off the card
      // — a highlight sitting on an app the pointer had long left.
      // A Mac does not do this either: the highlight is the keyboard's
      // and the pointer has its own, fainter one.
      MouseArea {
        anchors.fill: parent
        onClicked: root.launchAt(tile.absolute)
        hoverEnabled: true
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "mac-launchpad"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Leaves room for the card's padding and its margin from the screen edge,
    // so the grid never pushes the surface wider than the display.
    onWidthChanged: root.columns = Math.max(4, Math.min(9, Math.floor((width - Style.space(240)) / root.cell)))
    onHeightChanged: root.rows = Math.max(3, Math.min(6, Math.floor((height - Style.space(300)) / root.cell)))

    // The scrim. macOS blurs the desktop behind Launchpad; Hyprland can blur a
    // layer surface, but only if the user has blur on, so this has to read
    // correctly as a plain dim as well.
    //
    // 0.72 rather than a gentler dim because of what the card is worth against
    // it. On a dark theme the popup background is near-black and so is a dimmed
    // dark wallpaper: measured here, 0.55 put rgb(26,27,38) against
    // rgb(12,12,17), a contrast ratio of 1.14:1, so the window read as a
    // hairline outline rather than a surface. Contrast compresses badly at the
    // dark end, so the scrim has to do the work the colours cannot.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.72)
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem

      // Anywhere in the overlay, not just over the grid: on a Mac the scroll
      // works wherever the pointer happens to be sitting.
      //
      // pixelDelta is what a trackpad reports and already carries the
      // natural-scrolling direction libinput was set to. angleDelta is the
      // mouse wheel, 120 per notch, scaled to about one row. A trackpad event
      // with neither is the fingers lifting.
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          if (event.pixelDelta.y !== 0) {
            scroller.trackpad(-event.pixelDelta.y, Date.now())
          } else if (event.angleDelta.y !== 0) {
            scroller.wheel(-event.angleDelta.y / 120 * root.pitch * 0.75)
          } else if (event.pixelDelta.x === 0 && event.angleDelta.x === 0) {
            scroller.release()
          }
        }
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          // Two-stage, as on a Mac: the first Escape clears what you typed,
          // the second closes. Closing on the first would throw away a search
          // the user is still reading the results of.
          if (root.query.length > 0) root.query = ""
          else root.close()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.launchAt(root.index); event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
          root.backspace(); event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          root.step(1); event.accepted = true
        } else if (event.key === Qt.Key_Left) {
          root.step(-1); event.accepted = true
        } else if (event.key === Qt.Key_Down) {
          root.stepRows(1); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.stepRows(-1); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          root.stepRows(root.rows); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.stepRows(-root.rows); event.accepted = true
        } else if (event.text && event.text.length === 1 && event.text >= " ") {
          root.typed(event.text); event.accepted = true
        }
      }

      // The surface the grid sits on. Without it the icons float directly on
      // the scrim, and on a dark theme a dark icon over a dimmed dark desktop
      // has nothing to sit against — you see the wallpaper through the gaps
      // rather than a thing you are choosing from. Same popup background and
      // hairline Macifier's switcher and dock use, so the
      // surfaces are recognisably one family in any theme.
      BorderSurface {
        id: card
        anchors.centerIn: parent
        width: Math.min(content.implicitWidth + Style.space(64), parent.width - Style.space(80))
        height: Math.min(content.implicitHeight + Style.space(64), parent.height - Style.space(80))
        radius: Style.cornerRadius > 0 ? Style.space(22) : 0
        color: root.background
        borderSpec: Border.surfaceSpec("popups", "border",
          Color.popups ? Color.popups.border : root.foreground, 2)

        // Clicks inside the card are not clicks outside it. Without this they
        // fall through to the scrim's MouseArea and close Launchpad, so any
        // miss between two icons would dismiss it.
        MouseArea { anchors.fill: parent }

        Column {
          id: content
          anchors.centerIn: parent
          spacing: Style.space(28)

          // The search field. Not focusable on its own — every keystroke is
          // already being read by the key catcher, so this only ever reports.
          // A second focus target would mean two places a key could land.
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(320)
            height: Style.space(40)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.14)

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                opacity: 0.7
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.query.length > 0 ? root.query : "Search"
                color: root.foreground
                opacity: root.query.length > 0 ? 1.0 : 0.55
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }

          // The grid itself: every match in one list, scrolled. A GridView
          // only instantiates the rows in view, so a few hundred applications
          // cost what a screenful does. The wrapper exists for the scroll
          // indicator — a child of the GridView would scroll away with the icons.
          Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: grid.width
            height: grid.height

            GridView {
              id: grid
              cellWidth: root.pitch
              cellHeight: root.pitch
              clip: true
              interactive: false

              // Sized to a whole screen, not to what matches. A short list
              // would otherwise shrink the card under you, and while filtering
              // every keystroke would resize the window. macOS keeps the grid
              // the same size and lets it be sparse, and it is right: the
              // surface you are navigating should not move while you navigate it.
              width: root.columns * cellWidth
              height: root.rows * cellHeight

              model: root.shown

              // Recents scroll with the list rather than staying pinned, as on
              // the Mac: they are the first row of the view, not a toolbar.
              header: Column {
                width: grid.width
                visible: root.recents.length > 0
                height: visible ? implicitHeight : 0

                Text {
                  x: Style.space(16)
                  text: "Recents"
                  color: root.foreground
                  opacity: 0.6
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.weight: Font.DemiBold
                }

                Row {
                  Repeater {
                    model: root.recents
                    delegate: AppTile {
                      required property var modelData
                      required property int index
                      app: modelData
                      absolute: index
                    }
                  }
                }

                // The line between what you used and what you have. Inset so
                // it reads as a divider inside the grid, not a card edge.
                Item {
                  width: parent.width
                  height: Style.space(20)
                  Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(32)
                    height: 1
                    color: root.foreground
                    opacity: 0.12
                  }
                }
              }

              delegate: AppTile {
                required property var modelData
                required property int index
                app: modelData
                absolute: root.recents.length + index
              }
            }

            // A thin scroll indicator on the right edge, the only sign that
            // the list goes on below. Gone when everything fits, and faint
            // otherwise — macOS shows almost nothing here either.
            Rectangle {
              visible: grid.visibleArea.heightRatio < 1
              anchors.right: parent.right
              anchors.rightMargin: -Style.space(14)
              width: Style.space(4)
              radius: width / 2
              y: Math.max(0, grid.visibleArea.yPosition) * grid.height
              height: Math.min(grid.height - y, grid.visibleArea.heightRatio * grid.height)
              color: root.foreground
              opacity: glide.running || fingersUp.running || settle.running ? 0.5 : 0.25
            }
          }

        }

        // Only ever seen while filtering, so it names the query rather than
        // saying "no results" into the void. Centred over the grid rather than
        // placed under it: as a row in the column it would add its own height
        // the moment it appeared, growing the card exactly when the user is
        // typing and least wants it moving.
        Text {
          // Centred on the card, not on the grid: the grid is a child of the
          // column, so it is not a sibling of this and cannot be anchored to.
          anchors.centerIn: parent
          visible: root.shown.length === 0
          textFormat: Text.PlainText
          text: "Nothing matches “" + root.query + "”"
          color: root.foreground
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
