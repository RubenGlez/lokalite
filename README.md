<p align="center">
  <img src="assets/AppIcon.png" alt="Lokalite" width="120"/>
</p>

<h1 align="center">Lokalite</h1>

<p align="center">
  An open-source, local-first secrets workspace for developers.<br/>
  No cloud. No account. No subscription.
</p>

---

Lokalite is a macOS menu bar app and CLI for managing developer secrets locally. API keys, tokens, certificates, database passwords, all stored in an encrypted vault on your machine, protected by Apple Keychain.

## Features

- **Encrypted vault**: AES-256-GCM via CryptoKit, vault key stored in Apple Keychain
- **Touch ID unlock**: biometric authentication before accessing secrets
- **Menu bar app**: search, copy, and reveal secrets without leaving your workflow
- **Full CLI**: read, write, and inject secrets from the terminal
- **Projects**: group secrets by project; each project is an isolated namespace
- **Environments**: per-project environment profiles (e.g. dev, staging, production) with per-environment secret values; Default values serve as fallback for all environments
- **Clipboard auto-clear**: copied values are wiped after 30 seconds
- **Session timeout**: vault auto-locks after inactivity
- **Zero dependencies at runtime**: no cloud, no telemetry, no vendor lock-in

## Requirements

- macOS 13 or later
- Swift 5.9 or later

## Install

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
# Add a secret
lokalite add OPENAI_API_KEY sk-...

# Get a secret (prints to stdout, pipeable)
lokalite get OPENAI_API_KEY

# Copy to clipboard (auto-clears after 30s)
lokalite copy OPENAI_API_KEY

# List all secrets
lokalite list

# List by tag
lokalite list --tag ai

# Update a secret
lokalite set OPENAI_API_KEY sk-new-...

# Delete a secret
lokalite delete OPENAI_API_KEY

# Run a command with secrets injected as environment variables
lokalite run -- npm start
lokalite run --keys OPENAI_API_KEY,ANTHROPIC_API_KEY -- claude

# Export (encrypted by default)
lokalite export --output backup.lk
lokalite export --plain --output secrets.json
```

## Menu Bar App

```bash
swift run LokaliteApp
```

Click the dial icon in your menu bar to open the vault popover. Use **Manage Secrets** to open the full secrets manager window.

The secrets manager is a three-column view:
- **Left sidebar** — project list; create and switch between projects
- **Centre column** — environment switcher + searchable secrets list for the selected project
- **Right detail** — edit the selected secret's value; save or delete

## Security Model

```
Secrets stored in encrypted SQLite vault
        ↓
Each value encrypted with AES-256-GCM (CryptoKit)
        ↓
Vault key stored in Apple Keychain
        ↓
Keychain access gated by Touch ID / device password
```

See [docs/security-model.md](docs/security-model.md) for full details.

## Project Structure

```
Sources/
  LokaliteCore/    # vault logic, crypto, storage (shared library)
  lokalite/        # CLI (swift-argument-parser)
  LokaliteApp/     # menu bar app (SwiftUI)
docs/              # architecture, decisions, roadmap
```

## Claude Code / MCP Integration

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

The same config works for Codex, Cursor, Windsurf, and any other MCP-compatible agent.

By default the server is **read-only** and exposes two tools:

| Tool | Description |
|---|---|
| `list_secrets` | List secret names, tags, and descriptions (values never exposed) |
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

## Roadmap

- Command injection (`lokalite run <cmd>`)
- Project linking (associate secrets with a directory)
- Secret references (`lokalite://KEY_NAME` in config files)
- Cross-platform (Windows, Linux)

## License

MIT
