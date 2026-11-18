# Obsishell

Obsidian Headless Sync in the Omarchy bar. Obsishell installs and configures
the official `obsidian-headless` client, runs continuous sync as a systemd user
service, and shows every configured vault, local folder, sync mode, service
state, and latest continuous-sync activity in a color-coded panel.

## Install

```bash
omarchy plugin add https://github.com/edmundmiller/obsishell.git --enable
```

Open the Obsidian icon in the bar, then:

1. Select **Install Obsidian Headless**. This installs Node.js 22+ through
   Omarchy if needed, then installs `obsidian-headless` into `~/.local`.
2. Select **Log in** if needed, then **Reload vaults**. Choose a remote vault
   and local folder directly in the panel.
3. Select **Continue setup**. A short terminal prompt handles only confirmation,
   the end-to-end encryption password when required, and whether to enable
   continuous sync.
4. Use the switch to start or stop continuous sync.

An active [Obsidian Sync subscription](https://obsidian.md/sync) is required.
Obsidian Headless is currently an open beta.

> [!WARNING]
> Back up a vault before setting it up. Do not run Obsidian desktop Sync and
> Headless Sync on the same device; Obsidian warns that doing so can cause data
> conflicts.

## Controls

| Input | Action |
| --- | --- |
| Left click | Open or close the panel |
| Right click | Refresh status |
| Middle click | Run a one-time sync |
| `p` | Start or stop continuous sync |
| `s` | Run a one-time sync in a terminal |
| `o` | Open the local vault |
| `l` | Follow service logs |
| `r` | Refresh status |
| `q` / Escape | Close the panel |

The plugin exposes `open`, `close`, `toggle`, `refresh`, `start`, `stop`, and
`status` through the `io.github.edmundmiller.obsishell` shell IPC target.

## Multiple vaults

Obsishell manages one continuous-sync service at a time. By default it selects
the first vault returned by `ob sync-list-local --json`. Set `vaultPath` in the
widget settings to an absolute local vault path to select another configured
vault. Starting continuous sync for a different vault switches the service to
that vault.

Each vault card can open its local folder or launch a one-time sync. Obsidian
Headless currently exposes live activity only for the one vault managed by the
continuous-sync service; other cards therefore show configuration readiness
rather than invented file progress.

## What it changes

- Installs the official npm package under `~/.local` when requested.
- Stores the selected service vault and `ob` executable paths in
  `~/.config/obsishell/` with user-only permissions.
- Creates `~/.config/systemd/user/obsishell.service` when continuous sync is
  first enabled.
- Reads `ob`'s non-secret local and remote vault JSON, systemd state, and the
  latest journal line for display.

Authentication tokens and vault encryption keys remain owned by the official
client under `~/.config/obsidian-headless/`. Obsishell does not read, copy, log,
or pass credentials itself.

On service startup, Obsishell checks the native `better-sqlite3` addon in its
own `~/.local` installation. If a Node upgrade has made the addon incompatible,
it rebuilds that dependency with npm before starting sync. This can require
network access or build tools. Other client installations are not modified.
A failed or interrupted rebuild is attempted only once to avoid repeated npm
operations; check the service logs, reinstall Obsidian Headless using the panel,
and restart continuous sync. A successful native load clears the retry guard.
The generated service stops restarting on repair failure; existing service units
receive this setting the next time continuous sync is enabled through Obsishell.

The official Obsidian silhouette is rendered as a monochrome mask. Its color
follows the current Omarchy theme, dims while continuous sync is stopped, and
shows a small sync badge while continuous sync is running. It uses the theme's
urgent color when status checks fail.

## Remove

Remove the plugin-owned service first, preserving Obsidian credentials and all
vault data:

```bash
PLUGIN_DIR="$HOME/.config/omarchy/plugins/io.github.edmundmiller.obsishell"
bash "$PLUGIN_DIR/scripts/obsishell.sh" service-remove
omarchy plugin remove io.github.edmundmiller.obsishell
```

The official client and its configuration are intentionally left installed.
To remove those too, review and remove `~/.local/lib/node_modules/obsidian-headless`,
`~/.local/bin/ob`, and `~/.config/obsidian-headless` separately.

## Development

```bash
omarchy plugin validate .
node tests/model.test.js
bash tests/helper.test.sh
qmllint -I "$OMARCHY_PATH/shell" Panel.qml Service.qml
```

### Optional development lint tooling

Install with `npm --prefix tools/oxlint ci`, then run `npm --prefix tools/oxlint run lint` and `npm --prefix tools/oxlint run test:lint`. Tooling needs Node >=22.18 and has its own private package/lockfile; it does not change the QML runtime or CommonJS model tests. Existing model/helper/plugin checks above remain unchanged. Oxlint/editor configuration is `oxlint.config.mts` (use the executable under `tools/oxlint/node_modules/.bin`). Only owned `Model.js` and JavaScript tests are lint targets; QML and the separately installed official client are not reinterpreted as owned JS/TS. No TypeScript project or typecheck is introduced.

Ordinary lint is offline and never registers a model plugin. Edmund approved staged activation on 2026-11-16: original gates/severities are preserved, normal lint enables zero-conflict Core errors and seven advisory Fowler rules, and `npm --prefix tools/oxlint run lint:strict` keeps the full conflicting policy separately runnable as a proposal. This resolves staging, not full strict acceptance or authorization for source migration, permanent exemptions or publication. Unavailable QML/Omarchy validation tools remain a separate environment limitation.

Only explicitly running the package's `lint:jev`, `lint:jev:full`, or `lint:diff` opts into potentially paid review. No credentials or CI gates are provisioned. Changed-file Jev includes whole-file questions that can transmit untouched functions in changed files; function questions filter by changed overlaps. Diff review includes hunks, context, summaries and history, not changed lines only. Inspect inputs before configuring a provider or command backend. See [provenance and policy](tools/oxlint/anti-slop/UPSTREAM.md).

## License

MIT. Obsidian and Obsidian Sync are trademarks and services of Dynalist Inc.;
this community plugin is not affiliated with or endorsed by Dynalist Inc.
