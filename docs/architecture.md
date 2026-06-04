# Architecture

## Overview

Lokalite is a Swift-only project. A shared `LokaliteCore` library owns all vault logic, crypto, and storage. Two executables consume it: a CLI and a native macOS menu bar app.

```
lokalite/
  Sources/
    LokaliteCore/        # vault logic, crypto, storage (shared)
    lokalite/            # CLI target
    LokaliteApp/         # menu bar app target
  Tests/
    LokalitiCoreTests/
  Package.swift
```

---

## Project Structure

### `LokaliteCore`

The heart of the system. Exposes a clean Swift API consumed by both CLI and app. No UI dependencies.

Responsibilities:
- Vault open / close / lock
- Secret CRUD
- Encryption / decryption
- Keychain integration
- Export / import

### `lokalite` (CLI)

Swift executable. Parses arguments, calls `LokaliteCore`, writes output to stdout or clipboard.

### `LokaliteApp` (menu bar app)

SwiftUI app. `LSUIElement = true` (no dock icon). Two surfaces:
- `VaultPopover`: search, copy, reveal; anchored to `NSStatusItem`
- `SettingsWindow`: add, edit, delete secrets; triggered from popover footer

---

## Storage

**File**: `~/Library/Application Support/Lokalite/vault.db`

**Library**: GRDB.swift

**Schema** (current, after v4 migration):

```sql
CREATE TABLE projects (
  id                 TEXT PRIMARY KEY,
  name               TEXT NOT NULL UNIQUE,
  path               TEXT,
  active_environment TEXT,
  created_at         TEXT NOT NULL,
  updated_at         TEXT NOT NULL
);

CREATE TABLE environments (
  id         TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (project_id, name)
);

CREATE TABLE secrets (
  id         TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (project_id, name)
);

CREATE TABLE secret_values (
  id             TEXT PRIMARY KEY,
  secret_id      TEXT NOT NULL REFERENCES secrets(id) ON DELETE CASCADE,
  environment_id TEXT REFERENCES environments(id) ON DELETE CASCADE,
  encrypted_value BLOB NOT NULL,
  updated_at     TEXT NOT NULL,
  UNIQUE (secret_id, environment_id)
);

CREATE TABLE config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

Secrets are namespaced by project. Each secret has a value per environment; every project always has at least a "Default" environment (created automatically and set as the active environment on project creation). `name`, `description` are plaintext for fast search; only `encrypted_value` is encrypted. WAL mode enabled for safe concurrent access between CLI and app.

---

## Cryptography

**Library**: CryptoKit (Apple, on-device, no external dependency)

**Algorithm**: AES-256-GCM (authenticated encryption)

**Vault key**: 256-bit random key generated on first launch, stored as a Keychain item scoped to the Lokalite app.

**Encryption flow**:

```
secret value (String)
  → Data (UTF-8)
  → AES.GCM.seal(data, using: vaultKey)
  → AES.GCM.SealedBox (nonce + ciphertext + tag)
  → stored as BLOB in encrypted_value column
```

**Decryption flow**:

```
encrypted_value BLOB
  → AES.GCM.SealedBox
  → AES.GCM.open(sealedBox, using: vaultKey)
  → Data → String
```

Each value gets a fresh random nonce (handled automatically by CryptoKit).

---

## Keychain Integration

The vault key is stored as a single Keychain item:

```swift
kSecClass: kSecClassGenericPassword
kSecAttrService: "com.lokalite.vault"
kSecAttrAccount: "vault-key"
kSecAttrAccessControl: Touch ID / device passcode (biometryCurrentSet or devicePasscode)
```

**Access policy**: session-based. Keychain item is accessible after first Touch ID / password auth, until the Mac locks or the configured inactivity timeout fires. Configurable timeout stored in `UserDefaults`.

---

## Unlock Flow

1. CLI or app requests vault key from Keychain.
2. If session is active: key returned silently.
3. If session expired or first access: macOS prompts Touch ID / password.
4. Vault key decrypts secret values on demand.
5. Inactivity timer resets on each vault access. On timeout, session is invalidated (key cleared from memory).

---

## CLI Commands

```bash
lokalite init                              # create project from current directory name, set as active
lokalite status [--json]                   # active project/env, lock state, secret count, vault path, MCP status

lokalite add <name> <value> [--description <text>]
lokalite set <name> <value>
lokalite delete <name>

lokalite get <name>              # prints value to stdout
lokalite copy <name>             # copies to clipboard, auto-clears after 30s
lokalite list                    # lists secret names (never values)

lokalite import <file>                     # parse .env file, skip existing by default
lokalite import <file> --overwrite         # overwrite existing secrets

lokalite export [--output <file>]          # encrypted (default)
lokalite export --plain [--output <file>]  # plaintext JSON, requires confirmation
lokalite export --format env               # KEY="value" lines, stdout
lokalite export --format env --output .env

lokalite shell                             # export KEY='value' lines for eval
lokalite shell --keys KEY1,KEY2            # limit to specific keys

lokalite run <command> [args...]           # injects secrets as env vars into subprocess
lokalite run --keys KEY1,KEY2 -- <cmd>

lokalite project add <name> [--path <dir>] # create a new project
lokalite project list                      # list all projects
lokalite project use <name>               # set the active project
lokalite project link [<name>] [--path <dir>]   # link project to directory; defaults to cwd
lokalite project link --unlink <name>     # remove path association
lokalite project delete <name>            # delete project and all its secrets

lokalite env add <name>                    # add an environment to the active project
lokalite env list                          # list environments in the active project
lokalite env use <name>                    # set the active environment
lokalite env delete <name>                 # delete an environment and its secret values
```

### Project and environment resolution

All read/write commands resolve context in this order: `--project` flag → `LOKALITE_PROJECT` env var → linked working directory match → active project. Environment resolves via `--env` flag → `LOKALITE_ENV` → project's active environment.

### `lokalite run` and `lokalite shell`

`lokalite run` injects secrets into a subprocess's environment only. They never appear in the parent shell or `env` output.

`lokalite shell` outputs `export KEY='value'` lines intended for `eval`. Single-quotes are used; embedded single quotes are escaped as `'\''`. This makes secrets visible to all child processes for the duration of the session.

---

## Menu Bar App

### Architecture

The menu bar app uses `NSStatusItem` + `NSPopover` rather than SwiftUI's `MenuBarExtra`. This allows the popover to be shown and hidden programmatically in response to the global keyboard shortcut registered via Carbon's `RegisterEventHotKey`. `GlobalHotkeyManager` wraps the Carbon API and fires `onActivate` on the main thread when the hotkey is pressed.

`VaultViewModel` is an `@Observable @MainActor` class shared between the popover and settings window via SwiftUI's environment. It owns the session timer, clipboard auto-clear, and all vault I/O. It also persists user preferences (appearance mode, hotkey shortcut ID, recent secret names) in `UserDefaults`.

### Popover (`VaultPopover`)

```
┌─────────────────────────────┐
│ MyProject › Default      [+]│
├─────────────────────────────┤
│ 🔍 Search secrets...        │
├─────────────────────────────┤
│ Recent                      │
│ OPENAI_API_KEY          [⎘] │
│ All                         │
│ ANTHROPIC_API_KEY       [⎘] │
│ SUPABASE_URL            [⎘] │
│ ...                         │
├─────────────────────────────┤
│ [Manage]              [⏻]   │
└─────────────────────────────┘
```

- Header shows active project and environment as menus; switch context without leaving the popover
- Recent section shows the last 5 copied secrets (persisted in `UserDefaults`)
- Search filters by name, description, and category in real time
- Click a row → copies value to clipboard (auto-clears after configured timeout)
- `[+]` button opens the Add Secret sheet
- Manage opens the settings window; power button quits the app

### Settings Window (`SettingsView`)

Full CRUD, three-column `NavigationSplitView`:

- **Left sidebar**: project list. Create, rename, and delete projects; set emoji/SF Symbol icon and link to a local directory path for automatic project resolution.
- **Centre column**: environment picker (dropdown, per project) + searchable secrets list. Secrets show name (monospaced) and optional description. Hover reveals a copy button.
- **Right detail**: selected secret's name, description, category, and value (masked by default with a reveal toggle). Inline Save button; Delete at the bottom as a destructive link.

App-wide preferences are in the Settings tab (gear icon): session timeout, clipboard clear timeout, appearance (System / Light / Dark), global hotkey shortcut, and launch at login.

On first launch with no projects, an onboarding screen replaces the three-column layout with a single "Create your first project" CTA.

---

## Export Format

**Encrypted** (default): binary envelope, printed as base64 when no output file is provided.

Envelope layout:

```text
0x02
argon2id_iterations: UInt32BE
argon2id_memory_kib: UInt32BE
argon2id_parallelism: UInt32BE
salt: 32 bytes
aes_gcm_combined: nonce + ciphertext + tag
```

Current Argon2id parameters are 3 iterations, 64 MiB memory, and parallelism 1.

The plaintext being encrypted is a JSON object: `{ "NAME": "value", ... }`.

**Plain** (`--plain`):

```json
{
  "OPENAI_API_KEY": "sk-...",
  "ANTHROPIC_API_KEY": "sk-ant-..."
}
```

**Env** (`--format env`):

```
OPENAI_API_KEY="sk-..."
ANTHROPIC_API_KEY="sk-ant-..."
```

Key=double-quoted-value lines, one per secret. Values are not encrypted. Suitable for writing back to a `.env` file.

---

## Security Boundaries

| Threat | Mitigation |
|--------|------------|
| Vault file stolen | Values encrypted with AES-256-GCM; key not in the file |
| Keychain item stolen | Scoped to app, requires Touch ID / device passcode |
| CLI leaks into shell history | `get` documented; `copy` and `run` are safer defaults |
| Clipboard sniffing | Auto-clear after configurable timeout (default 30s) |
| Compromised Mac session | Touch ID prompt on session expiry; app sandboxing |
| Plain export leaked | Requires `--plain` flag + explicit confirmation |
| Backup exposure | vault.db is useless without the Keychain key |

