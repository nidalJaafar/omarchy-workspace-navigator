import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "nidal.workspace-navigator"

  property int hoveredWorkspaceId: -1
  property var hoveredAnchor: root
  property bool popupOpen: false

  readonly property int minimumWorkspaces: Math.max(1, Math.min(10, Number(setting("minimumWorkspaces", 5))))
  readonly property int maximumPopupWindows: Math.max(1, Number(setting("maxPopupWindows", 6)))
  readonly property var hoveredWorkspace: workspaceById(hoveredWorkspaceId)
  readonly property int hoveredWindowCount: safeToplevels(hoveredWorkspace).length
  readonly property var hoveredWindows: {
    var values = safeToplevels(hoveredWorkspace)
    return values.slice(0, maximumPopupWindows)
  }
  readonly property int previewColumns: hoveredWindows.length <= 1 ? 1 : (hoveredWindows.length <= 4 ? 2 : 3)
  readonly property int previewRows: hoveredWindows.length > 0 ? Math.ceil(hoveredWindows.length / previewColumns) : 0
  readonly property real previewGap: Style.space(8)
  readonly property real previewCellWidth: previewColumns > 0
    ? Math.max(1, (popupColumn.width - previewGap * (previewColumns - 1)) / previewColumns)
    : 1
  readonly property real previewCellHeight: Math.max(
    Style.space(88),
    Math.min(Style.space(280), previewCellWidth * 9 / 16)
  )

  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Until Hyprland has written the file, the workspace a monitor shows is in
  // its own block.
  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  function safeToplevels(workspace) {
    try {
      if (!workspace || !workspace.toplevels) return []
      return workspace.toplevels.values || []
    } catch (error) {
      return []
    }
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var base = root.block * root.slots
    var ids = []
    for (var slot = 1; slot <= root.minimumWorkspaces; slot++) ids.push(base + slot)
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    closePopup()
    if (root.blockOf(id) === root.block) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  function waylandToplevel(toplevel) {
    try {
      if (!toplevel) return null
      var address = String(toplevel.address || "")
      var values = ToplevelManager.toplevels.values
      for (var i = 0; i < values.length; i++) {
        if (String(values[i].HyprlandToplevel.address || "") === address) return values[i]
      }
      return null
    } catch (error) {
      return null
    }
  }

  function activateWindow(toplevel) {
    if (!toplevel) return
    var wayland = waylandToplevel(toplevel)
    if (wayland) {
      wayland.activate()
    } else {
      var address = String(toplevel.address || "")
      if (address !== "") {
        var target = "address:" + (address.indexOf("0x") === 0 ? address : "0x" + address)
        if (Hyprland.usingLua)
          Hyprland.dispatch("hl.dsp.focus({ window = \"" + target + "\" })")
        else
          Hyprland.dispatch("focuswindow " + target)
      }
    }
    closePopup()
  }

  function windowTitle(toplevel) {
    if (!toplevel) return "Unknown window"
    var wayland = waylandToplevel(toplevel)
    return String(toplevel.title || (wayland ? wayland.title : "") || windowAppId(toplevel) || "Untitled window")
  }

  function windowAppId(toplevel) {
    if (!toplevel) return "Application"
    var wayland = waylandToplevel(toplevel)
    var ipc = toplevel.lastIpcObject || ({})
    return String((wayland ? wayland.appId : "") || ipc.class || ipc.initialClass || "Application")
  }

  function iconSource(toplevel) {
    var appId = toplevel ? String(toplevel.appId || "") : ""
    if (root.bar && root.bar.shell && root.bar.shell.appLibrary)
      return root.bar.shell.appLibrary.iconSource(appId)
    return Quickshell.iconPath(appId || "application-x-executable", true)
  }

  function beginHover(anchor, workspaceId) {
    closeTimer.stop()
    hoveredAnchor = anchor
    hoveredWorkspaceId = workspaceId
    if (popupOpen) return
    openTimer.restart()
  }

  function endHover() {
    openTimer.stop()
    closeTimer.restart()
  }

  function closePopup() {
    openTimer.stop()
    closeTimer.stop()
    popupOpen = false
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.closePopup()
      // Quickshell credits every workspace switch to the focused monitor, as
      // the event doesn't say which one switched, and misses the workspace a
      // monitor falls back to when its own is moved away. Moving workspaces
      // between monitors switches the others, so ask Hyprland for the truth.
      // A workspace that changes number is only learned by asking too. Every
      // bar shares what Hyprland answers, so one asks after a plain switch.
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  Timer {
    id: openTimer
    interval: Math.max(0, Number(root.setting("hoverDelayMs", 220)))
    onTriggered: root.popupOpen = root.hoveredWorkspaceId > 0
  }

  Timer {
    id: closeTimer
    interval: Math.max(0, Number(root.setting("closeDelayMs", 180)))
    onTriggered: {
      if (!popup.containsMouse) root.popupOpen = false
    }
  }

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      Item {
        id: workspaceButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property int windowCount: root.safeToplevels(workspace).length
        readonly property bool occupied: windowCount > 0
        readonly property bool focused: root.activeWorkspaceId() === modelData

        Layout.preferredWidth: root.vertical ? root.barSize : Style.space(20)
        Layout.preferredHeight: root.barSize

        Rectangle {
          anchors.centerIn: parent
          width: parent.width - Style.space(3)
          height: parent.height - Style.space(5)
          radius: Style.cornerRadius
          color: workspaceMouse.containsMouse ? Style.hoverFillFor(root.bar.barForeground, Color.accent) : "transparent"
          border.color: workspaceButton.focused ? root.bar.barForeground : "transparent"
          border.width: workspaceButton.focused ? Math.max(1, Style.space(1)) : 0

          Behavior on color { ColorAnimation { duration: Style.duration(120) } }
        }

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: workspaceButton.focused ? "\uDB85\uDCFB" : (root.slotOf(workspaceButton.modelData) === 10 ? "0" : String(root.slotOf(workspaceButton.modelData)))
          color: root.bar.barForeground
          opacity: workspaceButton.occupied || workspaceButton.focused ? 1 : 0.45
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        Rectangle {
          visible: workspaceButton.windowCount > 1
          width: Style.space(4)
          height: width
          radius: width / 2
          color: root.bar.barForeground
          opacity: 0.7
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(2)
        }

        MouseArea {
          id: workspaceMouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onEntered: root.beginHover(workspaceButton, workspaceButton.modelData)
          onExited: root.endHover()
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton && root.bar)
              root.bar.run("omarchy-shell shell toggle omarchy-overview")
            else
              root.focusWorkspace(workspaceButton.modelData)
          }
        }
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root.hoveredAnchor || root
    bar: root.bar
    owner: root
    triggerMode: "hover"
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(540))
    contentHeight: popup.cappedContentHeight(Style.space(390))

    onContainsMouseChanged: {
      if (containsMouse) closeTimer.stop()
      else if (root.popupOpen) closeTimer.restart()
    }

    Column {
      id: popupColumn
      anchors.fill: parent
      spacing: Style.space(8)

      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: "Workspace " + (root.slotOf(root.hoveredWorkspaceId) === 10 ? "0" : root.slotOf(root.hoveredWorkspaceId))
          color: root.bar.barForeground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          Layout.fillWidth: true
        }

        Text {
          textFormat: Text.PlainText
          text: root.hoveredWindows.length + (root.hoveredWindows.length === 1 ? " window" : " windows")
          color: Qt.darker(root.bar.barForeground, 1.35)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      PanelSeparator {
        foreground: root.bar.barForeground
      }

      Item {
        id: previewStage
        width: parent.width
        height: Style.space(280)

        Text {
          textFormat: Text.PlainText
          visible: root.hoveredWindows.length === 0
          anchors.centerIn: parent
          text: "No open windows"
          color: Qt.darker(root.bar.barForeground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        GridLayout {
          id: previewGrid
          visible: root.hoveredWindows.length > 0
          anchors.centerIn: parent
          width: parent.width
          columns: root.previewColumns
          columnSpacing: root.previewGap
          rowSpacing: root.previewGap

          Repeater {
            model: root.hoveredWindows

            Item {
              id: windowPreviewCard
              required property var modelData

              Layout.preferredWidth: root.previewCellWidth
              Layout.preferredHeight: root.previewCellHeight
              clip: true

              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: Color.background

                Image {
                  anchors.centerIn: parent
                  width: Math.min(parent.width, parent.height) * 0.32
                  height: width
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  source: root.iconSource(windowPreviewCard.modelData)
                  opacity: 0.65
                }
              }

              ScreencopyView {
                anchors.fill: parent
                captureSource: root.popupOpen ? root.waylandToplevel(windowPreviewCard.modelData) : null
                live: root.popupOpen
                layer.enabled: true
                layer.smooth: true
              }

              Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Style.space(38)
                color: "#C0000000"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(7)

                  Image {
                    Layout.preferredWidth: Style.space(20)
                    Layout.preferredHeight: Style.space(20)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: root.iconSource(windowPreviewCard.modelData)
                  }

                  Text {
          textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: root.windowTitle(windowPreviewCard.modelData)
                    color: "white"
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }

              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: previewMouse.containsMouse ? Style.hoverFillFor("white", Color.accent) : "transparent"
                border.color: previewMouse.containsMouse ? Color.accent : Color.popups.border
                border.width: previewMouse.containsMouse ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))

                Behavior on color { ColorAnimation { duration: Style.duration(120) } }
                Behavior on border.color { ColorAnimation { duration: Style.duration(120) } }
              }

              MouseArea {
                id: previewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activateWindow(windowPreviewCard.modelData)
              }
            }
          }
        }
      }

      Text {
          textFormat: Text.PlainText
        visible: root.hoveredWindowCount > root.maximumPopupWindows
        width: parent.width
        text: "+ " + Math.max(0, root.hoveredWindowCount - root.maximumPopupWindows) + " more"
        color: Qt.darker(root.bar.barForeground, 1.45)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
          textFormat: Text.PlainText
        width: parent.width
        text: "Click a window to focus · Right-click a workspace for overview"
        color: Qt.darker(root.bar.barForeground, 1.55)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }
}
