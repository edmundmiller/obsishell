import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.edmundmiller.obsishell"
  ipcTarget: "io.github.edmundmiller.obsishell"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color barIconColor: sync.lastError !== ""
    ? urgent
    : (sync.serviceRunning && sync.serviceMatchesVault ? barForeground : Qt.darker(barForeground, 1.55))
  readonly property string folderPickerScript: localPathFromUrl(
    Qt.resolvedUrl("scripts/folder-picker.sh"))
  property bool setupOpen: false
  property string selectedVaultId: ""
  property string selectedFolder: ""
  property string folderPickerOutput: ""
  property string folderPickerError: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    sync.refresh()
    maybeLoadRemoteVaults()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function maybeLoadRemoteVaults() {
    if (sync.installed && sync.nodeSupported && sync.remoteVaults.length === 0
        && (!sync.configured || setupOpen)) sync.loadRemoteVaults()
  }

  function localPathFromUrl(value) {
    var path = String(value || "")
    if (path.indexOf("file://") === 0) path = path.slice(7)
    return decodeURIComponent(path)
  }

  function openSetup() {
    setupOpen = true
    sync.loadRemoteVaults()
  }

  function browseForFolder() {
    if (folderPickerProcess.running) return
    folderPickerOutput = ""
    folderPickerError = ""
    folderPickerProcess.command = ["bash", folderPickerScript]
    close()
    folderPickerProcess.running = true
  }

  function finishSetup() {
    if (selectedVaultId === "" || selectedFolder === "") return
    sync.setupSelected(selectedVaultId, selectedFolder)
    close()
  }

  Service {
    id: sync
    settings: root.settings
  }

  Connections {
    target: sync
    function onInstalledChanged() { root.maybeLoadRemoteVaults() }
    function onConfiguredChanged() { root.maybeLoadRemoteVaults() }
    function onRemoteVaultsChanged() {
      var selectedStillExists = false
      for (var i = 0; i < sync.remoteVaults.length; i++) {
        if (sync.remoteVaults[i].id === root.selectedVaultId) selectedStillExists = true
      }
      if (!selectedStillExists) root.selectedVaultId = sync.remoteVaults.length > 0
        ? sync.remoteVaults[0].id : ""
    }
  }

  Process {
    id: folderPickerProcess
    command: []

    stdout: StdioCollector {
      id: folderPickerStdout
      waitForEnd: true
      onStreamFinished: root.folderPickerOutput = text
    }

    onExited: function(exitCode) {
      var selected = String(root.folderPickerOutput || folderPickerStdout.text || "").trim()
      if (exitCode === 0 && selected) {
        root.selectedFolder = root.localPathFromUrl(selected)
      } else if (exitCode !== 0) {
        root.folderPickerError = "Folder chooser failed. Try again."
      }
      Qt.callLater(function() {
        root.open()
      })
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { sync.refresh(); return "ok" }
    function start(): string { if (!sync.serviceRunning) sync.toggleContinuous(); return "ok" }
    function stop(): string { if (sync.serviceRunning) sync.toggleContinuous(); return "ok" }
    function status(): string { return sync.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: sync.lastError || sync.statusText
    iconComponent: Component {
      Item {
        ObsidianIcon {
          anchors.centerIn: parent
          iconSize: Style.space(14)
          color: root.barIconColor
          pulsing: sync.refreshing
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) sync.refresh()
      else if (buttonCode === Qt.MiddleButton && sync.configured) sync.syncOnce()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        var key = text.toLowerCase()
        if (key === "r") sync.refresh()
        else if (key === "p" && sync.configured) sync.toggleContinuous()
        else if (key === "s" && sync.configured) sync.syncOnce()
        else if (key === "o" && sync.configured) sync.openVault()
        else if (key === "l" && sync.serviceAvailable) sync.showLogs()
        else if (key === "q") root.close()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: sync.vaultName || "Obsidian Sync"
          meta: sync.statusText
          detail: sync.configured ? sync.syncMode : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: sync.installed ? 1.0 : 0.5
          iconComponent: Component {
            ObsidianIcon {
              iconSize: Style.font.display
              color: sync.lastError !== "" ? root.urgent : root.foreground
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              id: powerSwitch
              visible: sync.configured && !root.setupOpen
              checked: sync.serviceRunning && sync.serviceMatchesVault
              busy: sync.busy
              foreground: root.foreground
              onToggled: sync.toggleContinuous()
              PanelToolTip {
                visible: powerSwitch.containsMouse
                text: powerSwitch.checked ? "Stop continuous sync" : "Start continuous sync"
                fontFamily: root.fontFamily
              }
            }
          }
        }

        Text {
          visible: sync.actionStatus !== "" || sync.lastError !== ""
          width: parent.width
          text: sync.actionStatus !== "" ? sync.actionStatus : sync.lastError
          color: sync.lastError !== "" && sync.actionStatus === "" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: sync.installed && !sync.nodeSupported
          width: parent.width
          text: "Obsidian Headless requires Node.js 22 or later."
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Text {
          visible: sync.configured && !sync.serviceMatchesVault
          width: parent.width
          text: "Continuous sync is running for another vault. Starting this vault will switch the service."
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Column {
          visible: sync.configured && !root.setupOpen
          width: parent.width
          spacing: Style.space(5)

          PanelSectionHeader {
            text: "VAULT"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            text: sync.vaultPath
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideMiddle
          }

          Text {
            visible: sync.latestActivity !== ""
            width: parent.width
            text: sync.latestActivity
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Button {
          visible: !sync.installed || !sync.nodeSupported
          width: parent.width
          text: sync.installed ? "Repair installation" : "Install Obsidian Headless"
          iconText: "󰇚"
          bordered: true
          leftAlign: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: sync.install()
        }

        Button {
          visible: sync.installed && sync.configured && !root.setupOpen
          width: parent.width
          text: "Set up another vault"
          iconText: "󰒓"
          bordered: true
          leftAlign: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.openSetup()
        }

        Column {
          visible: sync.installed && sync.nodeSupported && (!sync.configured || root.setupOpen)
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "SET UP A VAULT"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            text: "Choose the remote vault and its local folder here. Passwords remain in the secure terminal prompt."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            visible: sync.remoteLoading || sync.remoteError !== "" || root.folderPickerError !== ""
            width: parent.width
            text: sync.remoteLoading
              ? "Loading remote vaults…"
              : (root.folderPickerError || sync.remoteError)
            color: sync.remoteError !== "" || root.folderPickerError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Dropdown {
            visible: sync.remoteOptions.length > 0
            width: parent.width
            label: "Remote vault"
            options: sync.remoteOptions
            value: root.selectedVaultId
            foreground: root.foreground
            fontFamily: root.fontFamily
            onChanged: function(value) { root.selectedVaultId = value }
          }

          Button {
            visible: root.selectedVaultId !== ""
            width: parent.width
            text: root.selectedFolder === "" ? "Choose local folder" : root.selectedFolder
            iconText: "󰉋"
            bordered: true
            leftAlign: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.browseForFolder()
          }

          Button {
            visible: root.selectedVaultId !== "" && root.selectedFolder !== ""
            width: parent.width
            text: "Continue setup"
            iconText: "󰄬"
            bordered: true
            leftAlign: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.finishSetup()
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Log in"
              iconText: "󰍂"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: sync.login()
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: sync.remoteLoading ? "Loading…" : "Reload vaults"
              iconText: "󰑐"
              iconSpinning: sync.remoteLoading
              enabled: !sync.remoteLoading
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: sync.loadRemoteVaults()
            }
          }

          Button {
            visible: sync.configured && root.setupOpen
            width: parent.width
            text: "Cancel"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.setupOpen = false
          }
        }

        Row {
          visible: sync.configured && !root.setupOpen
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Sync now"
            iconText: "󰑐"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: sync.syncOnce()
          }

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Open vault"
            iconText: "󰉋"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: sync.openVault()
          }
        }

        Row {
          visible: sync.configured && !root.setupOpen
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - parent.spacing) / 2
            text: sync.refreshing ? "Refreshing…" : "Refresh"
            iconText: "󰑐"
            iconSpinning: sync.refreshing
            enabled: !sync.refreshing
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: sync.refresh()
          }

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Service logs"
            iconText: "󰆍"
            enabled: sync.serviceAvailable
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: sync.showLogs()
          }
        }

        Text {
          width: parent.width
          text: "r refresh  ·  p power  ·  s sync  ·  o open  ·  l logs  ·  q close"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
