#!/usr/bin/env bash

set -euo pipefail

root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
fake_bin="$tmp/bin"
mkdir -p -- "$HOME" "$fake_bin"
export PATH="$fake_bin:/usr/bin:/bin"

cat >"$fake_bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'v22.12.0\n'
EOF

cat >"$fake_bin/ob" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) printf '0.0.14\n' ;;
  sync-list-local)
    printf '{"vaults":[{"id":"vault-1","path":"%s/Vault With Spaces","host":"sync.example"}]}\n' "$HOME"
    ;;
  sync-status)
    printf '{"vaultId":"vault-1","vaultName":"Notes","vaultPath":"%s/Vault With Spaces","syncMode":"bidirectional"}\n' "$HOME"
    ;;
  sync-list-remote)
    printf '{"vaults":[{"id":"vault-1","name":"Notes","region":"North America"}],"shared":[]}\n'
    ;;
  sync-setup) printf '<%s>\n' "$@" >"$HOME/setup-args" ;;
  sync) printf '%s\n' "$*" >"$HOME/sync-args" ;;
  *) exit 2 ;;
esac
EOF

cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOME/systemctl-calls"
if [[ $* == *"--property=LoadState"* ]]; then printf 'loaded\n'; fi
if [[ $* == *"--property=ActiveState"* ]]; then printf '%s\n' "${FAKE_ACTIVE_STATE:-inactive}"; fi
if [[ $* == *"--property=UnitFileState"* ]]; then printf '%s\n' "${FAKE_UNIT_STATE:-disabled}"; fi
EOF

cat >"$fake_bin/journalctl" <<'EOF'
#!/usr/bin/env bash
printf 'Fully synced\n'
EOF

chmod +x "$fake_bin/node" "$fake_bin/ob" "$fake_bin/systemctl" "$fake_bin/journalctl"

status="$(bash "$root/scripts/obsishell.sh" status)"
jq -e --arg path "$HOME/Vault With Spaces" '
  .state == "stopped"
  and .installed == true
  and .nodeSupported == true
  and .configured == true
  and .vaultName == "Notes"
  and .vaultPath == $path
  and .latestActivity == "Fully synced"
' <<<"$status" >/dev/null

remotes="$(bash "$root/scripts/obsishell.sh" remote-vaults)"
jq -e '.vaults[0].id == "vault-1" and .shared == []' <<<"$remotes" >/dev/null

printf 'y\nn\n\n' | bash "$root/scripts/obsishell.sh" run-terminal \
  setup-selected "vault id with spaces" "$HOME/New Vault" >/dev/null
cat >"$tmp/expected-setup-args" <<EOF
<sync-setup>
<--vault>
<vault id with spaces>
<--path>
<$HOME/New Vault>
EOF
diff -u "$tmp/expected-setup-args" "$HOME/setup-args"

bash "$root/scripts/obsishell.sh" service-start "$HOME/Vault With Spaces" >/dev/null
unit="$XDG_CONFIG_HOME/systemd/user/obsishell.service"
grep -Fxq '# Managed by obsishell' "$unit"
grep -Fq 'run-service' "$unit"
[[ $(<"$XDG_CONFIG_HOME/obsishell/vault-path") == "$HOME/Vault With Spaces" ]]
grep -Fq 'enable --now obsishell.service' "$HOME/systemctl-calls"

export FAKE_ACTIVE_STATE=active
export FAKE_UNIT_STATE=enabled
status="$(bash "$root/scripts/obsishell.sh" status "$HOME/Vault With Spaces")"
jq -e '.state == "running" and .serviceRunning == true and .serviceEnabled == true' \
  <<<"$status" >/dev/null

bash "$root/scripts/obsishell.sh" run-service
[[ $(<"$HOME/sync-args") == "sync --continuous --path $HOME/Vault With Spaces" ]]

bash "$root/scripts/obsishell.sh" service-stop >/dev/null
grep -Fq 'reset-failed obsishell.service' "$HOME/systemctl-calls"

bash "$root/scripts/obsishell.sh" service-remove >/dev/null
[[ ! -e $unit ]]

printf '[Unit]\nDescription=Someone else\n' >"$unit"
if bash "$root/scripts/obsishell.sh" service-start "$HOME/Vault With Spaces" \
  >"$tmp/unowned.out" 2>"$tmp/unowned.err"; then
  printf 'service-start unexpectedly replaced an unowned unit\n' >&2
  exit 1
fi
grep -Fq 'is not managed by obsishell' "$tmp/unowned.err"

printf 'helper tests passed\n'
