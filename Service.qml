import Quickshell
import Quickshell.Io
import QtQuick

// The plugin's whole job: run install.sh from this folder when the shell
// starts. It hooks hypr/omac.lua into Hyprland and links the two helpers, and
// does nothing when they are already in place. The bindings themselves live
// in Hyprland, not here.
Item {
  id: root

  readonly property string installer: decodeURIComponent(Qt.resolvedUrl("install.sh").toString().replace(/^file:\/\//, ""))

  Process {
    id: install
    command: ["bash", root.installer]
    stderr: StdioCollector { id: errors }
    onExited: function (code) {
      if (code !== 0) {
        notify.command = ["notify-send", "-u", "critical", "omac could not install", errors.text.trim() || ("install.sh exited with " + code)]
        notify.running = true
      }
    }
  }

  Process { id: notify }

  Component.onCompleted: install.running = true
}
