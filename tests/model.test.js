const assert = require("node:assert/strict")
const model = require("../Model.js")

const running = model.parseStatus(JSON.stringify({
  state: "running",
  installed: true,
  nodeSupported: true,
  configured: true,
  vaultCount: 2,
  vaultName: "Notes",
  vaultPath: "/home/test/Notes",
  syncMode: "pull-only",
  serviceAvailable: true,
  serviceRunning: true,
  serviceEnabled: true,
  serviceMatchesVault: true,
  latestActivity: "Fully synced",
  error: ""
}))

assert.equal(running.ok, true)
assert.equal(running.vaultName, "Notes")
assert.equal(running.vaultCount, 2)
assert.equal(model.statusText(running), "Continuous sync is running")
assert.deepEqual(model.parseStatus(""), { ok: false, error: "Empty status response" })
assert.deepEqual(model.parseStatus("{"), { ok: false, error: "Invalid status response" })
assert.deepEqual(model.parseStatus('{"state":"wat"}'), { ok: false, error: "Invalid status response" })

console.log("model tests passed")
