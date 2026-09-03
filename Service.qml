import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property string state: "checking"
  property bool installed: false
  property bool nodeSupported: false
  property string version: ""
  property bool configured: false
  property int vaultCount: 0
  property string vaultName: ""
  property string vaultPath: ""
  property string syncMode: "bidirectional"
  property bool serviceAvailable: false
  property bool serviceRunning: false
  property bool serviceEnabled: false
  property bool serviceMatchesVault: true
  property string latestActivity: ""
  property string statusText: "Checking…"
  property string actionStatus: ""
  property string lastError: ""
  property bool refreshing: false

  property string _statusOutput: ""
  property string _statusError: ""
  property string _actionOutput: ""
  property string _actionError: ""
  property bool _refreshPending: false
  property bool _statusTimedOut: false

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 15, 5, 3600)
  readonly property string requestedVaultPath: String(setting("vaultPath", "") || "").trim()
  readonly property bool busy: statusProcess.running || actionProcess.running
  readonly property string helperPath: localPath(Qt.resolvedUrl("scripts/obsishell.sh"))

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, minimum, maximum) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    return decodeURIComponent(value)
  }

  function elide(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 180 ? value.substring(0, 177) + "…" : value
  }

  function refresh() {
    if (statusProcess.running) {
      _refreshPending = true
      return
    }
    _statusOutput = ""
    _statusError = ""
    _statusTimedOut = false
    refreshing = true
    statusProcess.command = ["bash", helperPath, "status", requestedVaultPath]
    statusProcess.running = true
    statusWatchdog.restart()
  }

  function applyStatus(raw) {
    var status = Model.parseStatus(raw)
    if (!status.ok) {
      lastError = status.error
      statusText = "Status unavailable"
      return
    }

    state = status.state
    installed = status.installed
    nodeSupported = status.nodeSupported
    version = status.version
    configured = status.configured
    vaultCount = status.vaultCount
    vaultName = status.vaultName
    vaultPath = status.vaultPath
    syncMode = status.syncMode
    serviceAvailable = status.serviceAvailable
    serviceRunning = status.serviceRunning
    serviceEnabled = status.serviceEnabled
    serviceMatchesVault = status.serviceMatchesVault
    latestActivity = status.latestActivity
    statusText = Model.statusText(status)
    lastError = status.error
  }

  function runServiceAction(action) {
    if (actionProcess.running || vaultPath === "") return
    _actionOutput = ""
    _actionError = ""
    actionStatus = action === "service-start" ? "Starting continuous sync…" : "Stopping continuous sync…"
    actionProcess.command = ["bash", helperPath, action, vaultPath]
    actionProcess.running = true
  }

  function toggleContinuous() {
    runServiceAction(serviceRunning && serviceMatchesVault ? "service-stop" : "service-start")
  }

  function launchTerminal(action) {
    Quickshell.execDetached(["bash", helperPath, "terminal", action, vaultPath])
  }

  function install() { launchTerminal("install") }
  function setup() { launchTerminal("setup") }
  function syncOnce() { if (configured) launchTerminal("sync-once") }
  function showLogs() { launchTerminal("logs") }

  function openVault() {
    if (vaultPath !== "") Quickshell.execDetached(["uwsm-app", "--", "xdg-open", vaultPath])
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: delayedRefresh
    interval: 800
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: actionStatusTimer
    interval: 2500
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Timer {
    id: statusWatchdog
    interval: 10000
    repeat: false
    onTriggered: if (statusProcess.running) {
      root._statusTimedOut = true
      statusProcess.running = false
    }
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
      onStreamFinished: root._statusOutput = text
    }
    stderr: StdioCollector {
      id: statusStderr
      waitForEnd: true
      onStreamFinished: root._statusError = text
    }
    onExited: function(exitCode) {
      statusWatchdog.stop()
      root.refreshing = false
      var stdout = String(statusStdout.text || root._statusOutput || "")
      var stderr = String(statusStderr.text || root._statusError || "")
      if (root._statusTimedOut) root.lastError = "Status check timed out"
      else if (exitCode === 0) root.applyStatus(stdout)
      else root.lastError = root.elide(stderr || stdout || "Could not read Obsidian Sync status")

      if (root._refreshPending) {
        root._refreshPending = false
        Qt.callLater(root.refresh)
      }
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: actionStdout
      waitForEnd: true
      onStreamFinished: root._actionOutput = text
    }
    stderr: StdioCollector {
      id: actionStderr
      waitForEnd: true
      onStreamFinished: root._actionError = text
    }
    onExited: function(exitCode) {
      var stdout = String(actionStdout.text || root._actionOutput || "")
      var stderr = String(actionStderr.text || root._actionError || "")
      if (exitCode === 0) {
        root.lastError = ""
        root.actionStatus = root.elide(stdout || "Sync service updated")
      } else {
        root.lastError = root.elide(stderr || stdout || "Could not update the sync service")
        root.actionStatus = ""
      }
      actionStatusTimer.restart()
      delayedRefresh.restart()
    }
  }
}
