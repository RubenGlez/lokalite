<p align="center">
  <img src="assets/banner.png" alt="Lokalite" width="100%"/>
</p>

Lokalite is a local-first secrets workspace for macOS — a menu bar app, CLI, and MCP server in one. Keep your API keys, tokens, and credentials in an encrypted vault on your machine, protected by Apple Keychain.

## Features

- **Encrypted vault**: AES-256-GCM via CryptoKit, vault key stored in Apple Keychain
- **Touch ID unlock**: biometric authentication before accessing any secret
- **Menu bar app**: search, copy, and reveal secrets without leaving your workflow; recent secrets surfaced at the top
- **Global keyboard shortcut**: open the popover from anywhere, configurable in Settings (default `⌘⇧Space`)
- **Full CLI**: read, write, and inject secrets from the terminal
- **Projects**: group secrets by project; link to a local directory for automatic resolution
- **Environments**: per-project environment profiles (dev, staging, production) with per-environment secret values; every project starts with a Default environment
- **`.env` import/export**: pull from an existing `.env` file or export back to one
- **Shell injection**: `eval $(lokalite shell)` exports secrets into the current session
- **Clipboard auto-clear**: copied values are wiped after 30 seconds
- **Session timeout**: vault auto-locks after inactivity
- **MCP integration**: expose your vault as tools to Claude Code, Cursor, Windsurf, and any other MCP-compatible agent
- **Zero runtime dependencies**: no cloud, no telemetry, no vendor lock-in

## Requirements

- macOS 14 or later

## Install

### Everything (recommended)

CLI, MCP server, and menu bar app via Homebrew:

```bash
brew tap RubenGlez/lokalite https://github.com/RubenGlez/lokalite
brew install lokalite
brew install --cask lokalite
lokalite install   # registers the MCP server in ~/.claude.json
```

### CLI and MCP only

If you don't need the menu bar app:

```bash
brew tap RubenGlez/lokalite https://github.com/RubenGlez/lokalite
brew install lokalite
lokalite install
```

### Menu bar app only

If you already have the CLI installed or don't need it:

```bash
brew tap RubenGlez/lokalite https://github.com/RubenGlez/lokalite
brew install --cask lokalite
```

### Without Homebrew

Download from the [Releases page](https://github.com/RubenGlez/lokalite/releases):

- **CLI**: run the `.pkg` installer, then `lokalite install`
- **Menu bar app**: drag the `.dmg` to Applications, then run `xattr -cr /Applications/Lokalite.app` once to clear the macOS quarantine flag (the app is open source and unsigned)

### Build from source

Requires Swift 5.9 or later.

```bash
git clone https://github.com/RubenGlez/lokalite
cd lokalite
make install
```

This builds a release binary, copies it to `/usr/local/bin/lokalite`, and registers it as an MCP server in `~/.claude.json`.

If `/usr/local/bin` requires elevated permissions:

```bash
swift build -c release
sudo .build/release/lokalite install
```

## CLI

```bash
# Initialise a project from the current directory
lokalite init

# Check vault state (active project, env, secret count, MCP status)
lokalite status
lokalite status --json

# Add a secret
lokalite add OPENAI_API_KEY sk-...

# Get a secret (prints to stdout, pipeable)
lokalite get OPENAI_API_KEY

# Copy to clipboard (auto-clears after 30s)
lokalite copy OPENAI_API_KEY

# List all secrets
lokalite list

# Update a secret
lokalite set OPENAI_API_KEY sk-new-...

# Delete a secret
lokalite delete OPENAI_API_KEY

# Run a command with secrets injected as environment variables
lokalite run -- npm start
lokalite run --keys OPENAI_API_KEY,ANTHROPIC_API_KEY -- claude

# Manage projects
lokalite project add MyProject
lokalite project list
lokalite project use MyProject
lokalite project link [<name>] [--path <dir>]   # link to a directory; defaults to cwd
lokalite project link --unlink <name>            # remove path association
lokalite project delete MyProject

# Manage environments
lokalite env add staging
lokalite env list
lokalite env use staging
lokalite env delete staging

# Import from a .env file
lokalite import .env
lokalite import .env --overwrite        # overwrite existing secrets

# Export
lokalite export --output backup.lk          # encrypted (default)
lokalite export --plain --output secrets.json
lokalite export --format env                # .env format, stdout
lokalite export --format env --output .env

# Inject secrets into the current shell session (see security note below)
eval $(lokalite shell)
eval $(lokalite shell --keys OPENAI_API_KEY,ANTHROPIC_API_KEY)
```

> **Shell injection note:** `eval $(lokalite shell)` makes secrets visible to all child processes and shows up in `env` output for the duration of your session. Use `lokalite run` to scope secrets to a single subprocess instead.

## Menu Bar App

Click the armadillo icon in your menu bar (or press the global shortcut, default `⌘⇧Space`) to open the vault popover. The popover shows recently copied secrets at the top, then all secrets for the active project and environment. Use the project and environment menus in the header to switch context, and click **Manage** in the footer to open the full secrets manager window.

The secrets manager is a three-column layout:
- **Left sidebar**: project list; create, rename, and delete projects; set icon and link to a local directory
- **Centre column**: environment switcher and searchable secrets list for the selected project
- **Right panel**: edit the selected secret's value; save or delete

On first launch, an onboarding screen guides you through creating your first project.

## MCP Integration

`lokalite install` registers the MCP server automatically. You can also add it manually to `~/.claude.json`:

```json
{
  "mcpServers": {
    "lokalite": {
      "command": "lokalite",
      "args": ["mcp"]
    }
  }
}
```

The same config works for Cursor, Windsurf, and any other MCP-compatible agent.

By default the server is **read-only** and exposes two tools:

| Tool | Description |
|---|---|
| `list_secrets` | List secret names, categories, and descriptions (values never exposed) |
| `get_secret` | Retrieve a secret value by name |

Pass `--read-write` to also expose write tools:

```json
{ "command": "lokalite", "args": ["mcp", "--read-write"] }
```

| Tool | Description |
|---|---|
| `add_secret` | Create a new secret |
| `set_secret` | Update an existing secret's value |
| `delete_secret` | Permanently delete a secret |

## Security

All secret values are encrypted with AES-256-GCM before being written to disk. The vault key lives exclusively in Apple Keychain and is gated behind Touch ID or your device password. Nothing leaves your machine.

See [docs/security-model.md](docs/security-model.md) for full details.

## License

MIT
