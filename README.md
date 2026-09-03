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

The official Obsidian silhouette is rendered as a monochrome mask. Its color
follows the current Omarchy theme, dims while continuous sync is stopped, and
uses the theme's urgent color when status checks fail.

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

## License

MIT. Obsidian and Obsidian Sync are trademarks and services of Dynalist Inc.;
this community plugin is not affiliated with or endorsed by Dynalist Inc.
