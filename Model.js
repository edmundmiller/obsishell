function clean(value) {
  return String(value === undefined || value === null ? "" : value).trim()
}

function parseStatus(raw) {
  var text = clean(raw)
  if (text === "") return { ok: false, error: "Empty status response" }

  try {
    var data = JSON.parse(text)
    var state = clean(data.state)
    if (["missing", "unconfigured", "stopped", "running", "error"].indexOf(state) < 0) {
      return { ok: false, error: "Invalid status response" }
    }

    return {
      ok: true,
      state: state,
      installed: data.installed === true,
      nodeSupported: data.nodeSupported === true,
      version: clean(data.version),
      configured: data.configured === true,
      vaultCount: Math.max(0, Number(data.vaultCount) || 0),
      vaultName: clean(data.vaultName),
      vaultPath: clean(data.vaultPath),
      syncMode: clean(data.syncMode) || "bidirectional",
      serviceAvailable: data.serviceAvailable === true,
      serviceRunning: data.serviceRunning === true,
      serviceEnabled: data.serviceEnabled === true,
      serviceMatchesVault: data.serviceMatchesVault !== false,
      latestActivity: clean(data.latestActivity),
      error: clean(data.error)
    }
  } catch (error) {
    return { ok: false, error: "Invalid status response" }
  }
}

function statusText(status) {
  if (!status || status.ok !== true) return "Status unavailable"
  if (status.state === "missing") return "Headless client not installed"
  if (status.state === "unconfigured") return "No vault configured"
  if (status.state === "running") return "Continuous sync is running"
  if (status.state === "error") return status.error || "Sync needs attention"
  return "Continuous sync is stopped"
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    statusText: statusText
  }
}
