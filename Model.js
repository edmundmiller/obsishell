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
      localVaults: Array.isArray(data.localVaults) ? data.localVaults.map(function(vault) {
        return {
          id: clean(vault && vault.id),
          name: clean(vault && vault.name) || "Unnamed vault",
          path: clean(vault && vault.path),
          host: clean(vault && vault.host),
          syncMode: clean(vault && vault.syncMode) || "bidirectional",
          selected: vault && vault.selected === true,
          serviceSelected: vault && vault.serviceSelected === true
        }
      }).filter(function(vault) { return vault.id !== "" && vault.path !== "" }) : [],
      error: clean(data.error)
    }
  } catch (error) {
    return { ok: false, error: "Invalid status response" }
  }
}

function parseRemoteVaults(raw) {
  var text = clean(raw)
  if (text === "") return { ok: false, error: "Empty remote vault response" }

  try {
    var data = JSON.parse(text)
    if (!Array.isArray(data.vaults) || !Array.isArray(data.shared)) {
      return { ok: false, error: "Invalid remote vault response" }
    }

    var vaults = []
    function append(items, shared) {
      for (var i = 0; i < items.length; i++) {
        var id = clean(items[i] && items[i].id)
        if (id === "") continue
        var name = clean(items[i].name) || id
        var region = clean(items[i].region)
        vaults.push({
          id: id,
          name: name,
          region: region,
          shared: shared,
          label: name + (shared ? " (shared)" : "") + (region ? " · " + region : "")
        })
      }
    }
    append(data.vaults, false)
    append(data.shared, true)
    return { ok: true, vaults: vaults }
  } catch (error) {
    return { ok: false, error: "Invalid remote vault response" }
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
    parseRemoteVaults: parseRemoteVaults,
    statusText: statusText
  }
}
