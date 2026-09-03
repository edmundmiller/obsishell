#!/usr/bin/env bash

set -euo pipefail

service_name="obsishell.service"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}/obsishell"
systemd_root="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
service_file="$systemd_root/$service_name"
vault_file="$config_root/vault-path"
ob_file="$config_root/ob-path"
script_path="$(readlink -f -- "$0")"

fail() {
  printf 'Error: %s\n' "$*" >&2
  return 1
}

resolve_ob() {
  local executable=""
  executable="$(command -v ob 2>/dev/null || true)"
  if [[ -z $executable && -x $HOME/.local/bin/ob ]]; then
    executable="$HOME/.local/bin/ob"
  fi
  [[ -n $executable ]] || return 1
  readlink -f -- "$executable" 2>/dev/null || printf '%s\n' "$executable"
}

expand_home() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${1#\~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

canonical_path() {
  realpath -m -- "$(expand_home "$1")"
}

node_supported() {
  local major=""
  major="$(node --version 2>/dev/null || true)"
  major="${major#v}"
  major="${major%%.*}"
  [[ $major =~ ^[0-9]+$ && $major -ge 22 ]]
}

service_property() {
  systemctl --user show "$service_name" --property="$1" --value 2>/dev/null || true
}

unit_is_ours() {
  [[ -f $service_file && ! -L $service_file ]] || return 1
  grep -Fxq '# Managed by obsishell' "$service_file"
}

detect_status() {
  local requested_path="${1:-}" ob="" version="" list_json='{"vaults":[]}'
  local vault_count=0 selected_path="" selected_id="" status_json="{}"
  local vault_name="" sync_mode="bidirectional" configured=false error=""
  local installed=false supported=false state="missing"
  local load_state="not-found" active_state="inactive" unit_state="not-found"
  local service_path="" service_available=false service_running=false
  local service_enabled=false service_matches=true latest_activity=""

  if ob="$(resolve_ob)"; then
    installed=true
    version="$($ob --version 2>/dev/null || true)"
    node_supported && supported=true

    if list_json="$($ob sync-list-local --json 2>/dev/null)" \
      && jq -e '.vaults | type == "array"' >/dev/null 2>&1 <<<"$list_json"; then
      vault_count="$(jq '.vaults | length' <<<"$list_json")"
    else
      list_json='{"vaults":[]}'
      error="Could not read local Obsidian Sync configuration"
    fi

    if [[ -n $requested_path ]]; then
      selected_path="$(canonical_path "$requested_path")"
      selected_id="$(jq -r --arg path "$selected_path" \
        '.vaults[] | select(.path == $path) | .id' <<<"$list_json" | head -n 1)"
    elif (( vault_count > 0 )); then
      selected_id="$(jq -r '.vaults[0].id // ""' <<<"$list_json")"
      selected_path="$(jq -r '.vaults[0].path // ""' <<<"$list_json")"
    fi

    if [[ -n $selected_id && -n $selected_path ]]; then
      if status_json="$($ob sync-status --json --path "$selected_path" 2>/dev/null)" \
        && jq -e 'type == "object" and (.vaultPath | type == "string")' \
          >/dev/null 2>&1 <<<"$status_json"; then
        configured=true
        vault_name="$(jq -r '.vaultName // ""' <<<"$status_json")"
        sync_mode="$(jq -r '.syncMode // "bidirectional"' <<<"$status_json")"
      else
        error="Could not read the selected vault configuration"
      fi
    fi

    state="unconfigured"
  fi

  load_state="$(service_property LoadState)"
  active_state="$(service_property ActiveState)"
  unit_state="$(service_property UnitFileState)"
  [[ -n $load_state ]] || load_state="not-found"
  [[ -n $active_state ]] || active_state="inactive"
  [[ -n $unit_state ]] || unit_state="not-found"
  [[ $load_state != not-found ]] && service_available=true
  [[ $active_state == active ]] && service_running=true
  [[ $unit_state == enabled ]] && service_enabled=true

  if [[ -f $vault_file && ! -L $vault_file ]]; then
    IFS= read -r service_path <"$vault_file" || true
  fi
  if [[ -n $selected_path && -n $service_path ]]; then
    [[ $(canonical_path "$selected_path") == "$(canonical_path "$service_path")" ]] \
      || service_matches=false
  fi

  if [[ $service_available == true ]]; then
    latest_activity="$(journalctl --user -u "$service_name" -n 1 -o cat \
      --no-pager 2>/dev/null || true)"
  fi

  if [[ $installed == true && $configured == true ]]; then
    state="stopped"
    [[ $service_running == true && $service_matches == true ]] && state="running"
  fi
  if [[ -n $error ]]; then
    state="error"
  elif [[ $installed == false ]]; then
    state="missing"
  fi

  jq -n \
    --arg state "$state" \
    --arg version "$version" \
    --argjson installed "$installed" \
    --argjson nodeSupported "$supported" \
    --argjson configured "$configured" \
    --argjson vaultCount "$vault_count" \
    --arg vaultName "$vault_name" \
    --arg vaultPath "$selected_path" \
    --arg syncMode "$sync_mode" \
    --argjson serviceAvailable "$service_available" \
    --argjson serviceRunning "$service_running" \
    --argjson serviceEnabled "$service_enabled" \
    --argjson serviceMatchesVault "$service_matches" \
    --arg latestActivity "$latest_activity" \
    --arg error "$error" \
    '{
      state: $state,
      installed: $installed,
      nodeSupported: $nodeSupported,
      version: $version,
      configured: $configured,
      vaultCount: $vaultCount,
      vaultName: $vaultName,
      vaultPath: $vaultPath,
      syncMode: $syncMode,
      serviceAvailable: $serviceAvailable,
      serviceRunning: $serviceRunning,
      serviceEnabled: $serviceEnabled,
      serviceMatchesVault: $serviceMatchesVault,
      latestActivity: $latestActivity,
      error: $error
    }'
}

systemd_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

start_service() {
  local vault_path="${1:-}" ob="" temporary=""
  [[ -n $vault_path ]] || fail "No configured vault is selected"
  vault_path="$(canonical_path "$vault_path")"
  [[ $vault_path != *$'\n'* ]] || fail "Vault paths containing newlines are unsupported"
  ob="$(resolve_ob)" || fail "Obsidian Headless is not installed"
  "$ob" sync-status --json --path "$vault_path" >/dev/null \
    || fail "Run Headless Sync setup for this vault first"

  if [[ -e $service_file || -L $service_file ]]; then
    unit_is_ours || fail "$service_file exists and is not managed by obsishell"
  fi

  mkdir -p -- "$config_root" "$systemd_root"
  chmod 700 -- "$config_root"
  printf '%s\n' "$vault_path" >"$vault_file"
  printf '%s\n' "$ob" >"$ob_file"
  chmod 600 -- "$vault_file" "$ob_file"

  temporary="$(mktemp --tmpdir="$systemd_root" .obsishell.service.XXXXXX)"
  trap 'rm -f -- "${temporary:-}"' RETURN
  cat >"$temporary" <<EOF
# Managed by obsishell
[Unit]
Description=Obsidian Headless continuous sync
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bash $(systemd_quote "$script_path") run-service
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
  chmod 600 -- "$temporary"
  mv -- "$temporary" "$service_file"
  temporary=""

  systemctl --user daemon-reload
  systemctl --user enable --now "$service_name"
  printf 'Continuous sync started for %s\n' "$vault_path"
}

stop_service() {
  if [[ -e $service_file || -L $service_file ]]; then
    unit_is_ours || fail "$service_file is not managed by obsishell"
    systemctl --user disable --now "$service_name"
  fi
  printf 'Continuous sync stopped\n'
}

remove_service() {
  if [[ -e $service_file || -L $service_file ]]; then
    unit_is_ours || fail "$service_file is not managed by obsishell"
    systemctl --user disable --now "$service_name" || true
    rm -- "$service_file"
  fi
  rm -f -- "$vault_file" "$ob_file"
  systemctl --user daemon-reload
  printf 'Obsishell service removed; Obsidian credentials and vault data were preserved.\n'
}

run_service() {
  local vault_path="" ob=""
  [[ -f $vault_file && ! -L $vault_file ]] || fail "Obsishell vault configuration is missing"
  [[ -f $ob_file && ! -L $ob_file ]] || fail "Obsidian Headless executable configuration is missing"
  IFS= read -r vault_path <"$vault_file"
  IFS= read -r ob <"$ob_file"
  [[ -x $ob ]] || fail "Obsidian Headless executable is unavailable: $ob"
  exec "$ob" sync --continuous --path "$vault_path"
}

install_headless() {
  if ! node_supported; then
    command -v omarchy >/dev/null 2>&1 || fail "Omarchy is required to install Node.js"
    printf '\n==> Installing Node.js and npm through Omarchy\n'
    omarchy pkg add nodejs npm
  fi
  node_supported || fail "Node.js 22 or later is required"
  command -v npm >/dev/null 2>&1 || fail "npm is not installed"
  printf '\n==> Installing Obsidian Headless into ~/.local\n'
  npm install --global --prefix "$HOME/.local" obsidian-headless
  printf '\nInstalled %s\n' "$("$HOME/.local/bin/ob" --version)"
}

list_remote_vaults() {
  local ob=""
  ob="$(resolve_ob)" || fail "Install Obsidian Headless first"
  "$ob" sync-list-remote --json
}

setup_vault() {
  local ob="" answer="" vault="" vault_path=""
  ob="$(resolve_ob)" || fail "Install Obsidian Headless first"

  cat <<'EOF'
Back up your vault before continuing.
Do not run Obsidian desktop Sync and Headless Sync on the same device; using
both can cause conflicts. An active Obsidian Sync subscription is required.
EOF
  printf '\nContinue? [y/N] '
  IFS= read -r answer
  [[ $answer == y || $answer == Y ]] || return 0

  "$ob" login
  printf '\n'
  "$ob" sync-list-remote
  printf '\nRemote vault ID or exact name: '
  IFS= read -r vault
  [[ -n $vault ]] || fail "A remote vault is required"
  printf 'Local vault path: '
  IFS= read -r vault_path
  [[ -n $vault_path ]] || fail "A local vault path is required"
  vault_path="$(canonical_path "$vault_path")"
  mkdir -p -- "$vault_path"

  "$ob" sync-setup --vault "$vault" --path "$vault_path"
  printf '\nStart continuous sync at login? [Y/n] '
  IFS= read -r answer
  if [[ $answer != n && $answer != N ]]; then
    start_service "$vault_path"
  else
    printf '\nRun a one-time sync before opening this vault: ob sync --path %q\n' "$vault_path"
  fi
}

setup_selected_vault() {
  local vault="${1:-}" vault_path="${2:-}" ob="" answer=""
  [[ -n $vault ]] || fail "A remote vault is required"
  [[ -n $vault_path ]] || fail "A local vault path is required"
  [[ $vault != *$'\n'* ]] || fail "Vault IDs containing newlines are unsupported"
  [[ $vault_path != *$'\n'* ]] || fail "Vault paths containing newlines are unsupported"
  ob="$(resolve_ob)" || fail "Install Obsidian Headless first"
  vault_path="$(canonical_path "$vault_path")"

  cat <<'EOF'
Back up your vault before continuing.
Do not run Obsidian desktop Sync and Headless Sync on the same device; using
both can cause conflicts. An active Obsidian Sync subscription is required.
EOF
  printf '\nSet up Headless Sync in %s? [y/N] ' "$vault_path"
  IFS= read -r answer
  [[ $answer == y || $answer == Y ]] || return 0

  mkdir -p -- "$vault_path"
  "$ob" sync-setup --vault "$vault" --path "$vault_path"
  printf '\nStart continuous sync at login? [Y/n] '
  IFS= read -r answer
  if [[ $answer != n && $answer != N ]]; then
    start_service "$vault_path"
  else
    printf '\nRun a one-time sync before opening this vault: ob sync --path %q\n' "$vault_path"
  fi
}

run_in_terminal() {
  local action="${1:-}" argument="${2:-}" second_argument="${3:-}" result=0
  printf 'Obsidian Headless Sync for Omarchy\n'
  printf '%s\n\n' '----------------------------------'
  set +e
  case "$action" in
    install)
      (set -e; install_headless)
      result=$?
      ;;
    login)
      "$(resolve_ob)" login
      result=$?
      ;;
    setup)
      (set -e; setup_vault)
      result=$?
      ;;
    setup-selected)
      (set -e; setup_selected_vault "$argument" "$second_argument")
      result=$?
      ;;
    sync-once)
      if [[ -n $argument ]]; then
        "$(resolve_ob)" sync --path "$argument"
        result=$?
      else
        fail "No configured vault is selected"
        result=$?
      fi
      ;;
    logs)
      journalctl --user -u "$service_name" -f -o cat
      result=$?
      ;;
    *)
      fail "Unknown terminal action: $action"
      result=$?
      ;;
  esac
  set -e

  if (( result == 0 )); then
    printf '\nDone.\n'
  else
    printf '\nThe operation failed. Review the error above.\n' >&2
  fi
  printf 'Press Enter to close this terminal. '
  IFS= read -r _
  return "$result"
}

launch_terminal() {
  command -v uwsm-app >/dev/null 2>&1 || fail "uwsm-app is not installed"
  command -v xdg-terminal-exec >/dev/null 2>&1 || fail "xdg-terminal-exec is not installed"
  exec uwsm-app -- xdg-terminal-exec --title="Obsidian Headless Sync" -- \
    bash "$script_path" run-terminal "$@"
}

main() {
  local command="${1:-status}"
  shift || true
  case "$command" in
    status) detect_status "$@" ;;
    service-start) start_service "$@" ;;
    service-stop) stop_service ;;
    service-remove) remove_service ;;
    run-service) run_service ;;
    remote-vaults) list_remote_vaults ;;
    terminal) launch_terminal "$@" ;;
    run-terminal) run_in_terminal "$@" ;;
    *) fail "usage: ${0##*/} {status|remote-vaults|service-start|service-stop|service-remove|terminal}" ;;
  esac
}

main "$@"
