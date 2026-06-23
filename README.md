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
- **Encrypted backup/restore**: `lokalite backup` writes a passphrase-encrypted file; `lokalite restore` reads it back
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
brew install RubenGlez/lokalite/lokalite
brew install --cask RubenGlez/lokalite/lokalite
lokalite install   # registers the MCP server in ~/.claude.json
```

### CLI and MCP only

If you don't need the menu bar app:

```bash
brew install RubenGlez/lokalite/lokalite
lokalite install
```

### Menu bar app only

If you already have the CLI installed or don't need it:

```bash
brew install --cask RubenGlez/lokalite/lokalite
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

## Release

The standard release flow is:

1. Run a local release bump from a clean checkout on `main`:

   ```bash
   make release BUMP=patch
   ```

   You can also use `minor` or `major` instead of `patch`.

2. The script creates an annotated tag and pushes it to GitHub.
3. GitHub Actions builds the release artifacts and publishes the GitHub release.
4. If the repository secret `HOMEBREW_PR_TOKEN` is configured, the workflow also opens a draft PR to update the Homebrew formula and cask.
5. Merge the Homebrew PR after CI passes. If the token is not configured, the workflow leaves the Homebrew branch pushed and prints the branch URL so you can open the PR manually.

That keeps `main` protected while still making releases a one-command local operation.

## CLI

```bash
# Initialise a project from the current directory
lokalite init

# Check vault state (active project, env, secret count, MCP status)
lokalite status
lokalite status --json

# View the secret access log (who read what, and from where)
lokalite log
lokalite log --limit 20
lokalite log --source cli       # filter by app, cli, or mcp

# Add a secret
lokalite add OPENAI_API_KEY sk-...
lokalite add OPENAI_API_KEY          # no value: prompts for it, keeping it out of shell history
echo -n "sk-..." | lokalite add OPENAI_API_KEY -   # or pipe it via stdin

# Get a secret (prints to stdout, pipeable)
lokalite get OPENAI_API_KEY

# Copy to clipboard (auto-clears after 30s)
lokalite copy OPENAI_API_KEY

# List all secrets
lokalite list

# Filter secrets by name or description (case-insensitive substring)
lokalite list --search openai

# Update a secret (also supports the prompt/stdin forms shown for `add`)
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

# Encrypted backup / restore (active project, current environment)
lokalite backup                             # prompts for a passphrase, writes a timestamped .lokalite file
lokalite backup --output backup.lokalite
lokalite restore backup.lokalite            # prompts for the passphrase, skips existing secrets
lokalite restore backup.lokalite --overwrite

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

When a tool call omits `project`, the server auto-resolves it from the caller's working directory using the project's linked path — the same way the CLI does. Pass an absolute `path` argument with the directory to resolve (preferred, since the server's own process may run elsewhere); otherwise it falls back to the server process's working directory. An explicit `project` argument (or `LOKALITE_PROJECT` in the server `env`) always wins.

Pass `--read-write` to also expose write tools:

```json
{ "command": "lokalite", "args": ["mcp", "--read-write"] }
```

| Tool | Description |
|---|---|
| `add_secret` | Create a new secret |
| `set_secret` | Update an existing secret's value |
| `delete_secret` | Permanently delete a secret |

> **Security note:** `get_secret` hands raw secret values to the connected agent with no per-access confirmation, so a prompt-injected agent can read any secret it can name (`list_secrets` gives it the names). Keep the server read-only (the default), scope it to a single project by setting `LOKALITE_PROJECT` in the server's `env` config, and prefer clients that ask for approval before tool calls. Every MCP access is recorded in the activity log.

## Security

- **Values**: every secret value is encrypted with AES-256-GCM before being written to disk. The 256-bit vault key is generated on first use and stored in your macOS login keychain — it is never written to the vault file.
- **Metadata**: secret names, descriptions, project names, linked paths, and the access activity log are stored unencrypted in `~/Library/Application Support/Lokalite/vault.db`. They reveal which services you use, not the credentials themselves; the file relies on home-directory permissions and FileVault.
- **App unlock**: the menu bar app requires Touch ID or your device password before showing secrets, and auto-locks after the session timeout.
- **CLI and MCP**: commands read the vault key from the login keychain without an extra prompt. The trust boundary is your unlocked macOS user session — anything running as your user with keychain access can read secrets, just like with `~/.aws/credentials` or `.env` files (which Lokalite improves on by encrypting values at rest and logging access).
- **Clipboard**: copies are marked with `org.nspasteboard.ConcealedType` so well-behaved clipboard managers skip them, and are auto-cleared after 30 seconds.
- Nothing leaves your machine: no cloud, no telemetry.

## License

MIT
