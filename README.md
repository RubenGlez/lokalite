<p align="center">
  <img src="assets/logo.svg" alt="Lokalite" width="600"/>
</p>

<p align="center">
  An open-source, local-first secrets workspace for developers.<br/>
  No cloud. No account. No subscription.
</p>

---

Lokalite is a macOS menu bar app and CLI for managing developer secrets locally. API keys, tokens, certificates, database passwords — stored in an encrypted vault on your machine, protected by Apple Keychain.

## Features

- **Encrypted vault** — AES-256-GCM encryption via CryptoKit, vault key stored in Apple Keychain
- **Touch ID unlock** — biometric authentication before accessing secrets
- **Menu bar app** — search, copy, and reveal secrets without leaving your workflow
- **Full CLI** — read, write, and inject secrets from the terminal
- **Clipboard auto-clear** — copied values are wiped after 30 seconds
- **Session timeout** — vault auto-locks after inactivity
- **Tag filtering** — organize secrets by category
- **Zero dependencies at runtime** — no cloud, no telemetry, no vendor lock-in

## Requirements

- macOS 13 or later
- Swift 5.9 or later

## Build

```bash
git clone https://github.com/RubenGlez/lokalite
cd lokalite
swift build -c release
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

Click the key icon in your menu bar to open the vault. Use **Manage Secrets** to add, edit, and delete secrets.

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
  LokaliteCore/    # vault logic, crypto, storage — shared library
  lokalite/        # CLI (swift-argument-parser)
  LokaliteApp/     # menu bar app (SwiftUI)
docs/              # architecture, decisions, roadmap
```

## Roadmap

- Environment profiles (`ai`, `production`, etc.)
- MCP server for Claude Code and local agent integration
- Project linking (associate secrets with a directory)
- Secret references (`lokalite://KEY_NAME` in config files)
- Cross-platform (Windows, Linux)

## License

MIT
