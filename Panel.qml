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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    sync.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: sync
    settings: root.settings
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
        Text {
          anchors.centerIn: parent
          text: "◆"
          color: root.barIconColor
          font.family: root.fontFamily
          font.pixelSize: Style.space(13)
          opacity: sync.refreshing ? 0.55 : 1.0

          SequentialAnimation on opacity {
            running: sync.refreshing
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 450 }
            NumberAnimation { to: 1.0; duration: 450 }
          }
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
            Text {
              text: "◆"
              color: sync.lastError !== "" ? root.urgent : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              id: powerSwitch
              visible: sync.configured
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
          visible: sync.configured
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
          visible: sync.installed
          width: parent.width
          text: sync.configured ? "Set up another vault" : "Log in and set up a vault"
          iconText: "󰒓"
          bordered: true
          leftAlign: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: sync.setup()
        }

        Row {
          visible: sync.configured
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
          visible: sync.configured
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
