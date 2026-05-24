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

**Schema** (current, after v2 migration):

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
  environment_id TEXT REFERENCES environments(id) ON DELETE CASCADE,  -- NULL = Default
  encrypted_value BLOB NOT NULL,
  updated_at     TEXT NOT NULL,
  UNIQUE (secret_id, environment_id)
);

CREATE TABLE config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

Secrets are namespaced by project. Each secret can have a value per environment; a `NULL` `environment_id` in `secret_values` means the Default value, which serves as a fallback for all environments. `name`, `description` are plaintext for fast search; only `encrypted_value` is encrypted. WAL mode enabled for safe concurrent access between CLI and app.

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
lokalite add <name> <value> [--description <text>] [--tags <tag,...>]
lokalite set <name> <value>
lokalite delete <name>

lokalite get <name>              # prints value to stdout
lokalite copy <name>             # copies to clipboard, auto-clears after 30s
lokalite list [--tag <tag>]      # lists secret names (never values)

lokalite export [--output <file>]           # encrypted JSON (default)
lokalite export --plain [--output <file>]   # plaintext JSON, requires confirmation

lokalite run <command> [args...]  # injects secrets as env vars into subprocess
```

### `lokalite run` detail

Lokalite resolves the current project from `--project`, `LOKALITE_PROJECT`, a linked working directory, or the active project. It resolves the environment from `--env`, `LOKALITE_ENV`, or the project's active environment.

By default, `lokalite run` injects all secrets from that resolved project/environment. Use `--keys` to limit injection:

```bash
lokalite run -- npm start
lokalite run --keys OPENAI_API_KEY,ANTHROPIC_API_KEY -- claude
```

The subprocess receives secrets in its environment. They never appear in the parent shell.

---

## Menu Bar App

### Popover (`VaultPopover`)

```
┌─────────────────────────────┐
│ 🔍 Search secrets...        │
├─────────────────────────────┤
│ OPENAI_API_KEY          [⎘] │
│ ANTHROPIC_API_KEY       [⎘] │
│ SUPABASE_URL            [⎘] │
│ ...                         │
├─────────────────────────────┤
│ [Manage Secrets]  [Lock] 🔒 │
└─────────────────────────────┘
```

- Search filters by name and tags in real time
- Click row → copies value to clipboard (shows "Copied!" feedback)
- Click [⎘] → same as clicking row
- Long-press or secondary click → reveal value temporarily
- [Manage Secrets] opens the settings window
- [Lock] invalidates the session immediately

### Settings Window (`SettingsView`)

Full CRUD, three-column `NavigationSplitView`:

- **Left sidebar** — project list. Each project is a folder-like namespace. Create and delete projects; selected project highlighted in amber.
- **Centre column** — environment picker (dropdown, per project) + searchable secrets list. Secrets show name (monospaced) and optional description. Hover reveals a copy button. The Default environment's values serve as fallback for named environments.
- **Right detail** — selected secret's name, description, and value (masked by default with a reveal toggle). Inline Save button; Delete at the bottom as a destructive link.

Settings (session timeout, launch at login) are accessible via the gear icon in the toolbar.

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

Also compatible with `.env` format via `--format env`.

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

---

## Roadmap Items (not in MVP)

- Secret references (`lokalite://KEY_NAME` in config files)
- Cross-platform support (Windows Credential Manager, Linux Secret Service)
- iCloud Keychain sync (optional, opt-in)
