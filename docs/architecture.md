# Architecture

## Overview

Lokalite is a Swift-only project. A shared `LokaliteCore` library owns all vault logic, crypto, and storage. Two executables consume it: a CLI and a native macOS menu bar app.

```
lokalite/
  Sources/
    LokaliteCore/        # vault logic, crypto, storage — shared
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
- `VaultPopover` — search, copy, reveal; anchored to `NSStatusItem`
- `SettingsWindow` — add, edit, delete secrets; triggered from popover footer

---

## Storage

**File**: `~/Library/Application Support/Lokalite/vault.db`

**Library**: GRDB.swift

**Schema**:

```sql
CREATE TABLE secrets (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  description TEXT,
  tags        TEXT,             -- JSON array, e.g. ["ai", "cloud"]
  encrypted_value BLOB NOT NULL, -- CryptoKit AES-256-GCM sealed box
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
```

Metadata columns (`name`, `tags`, `description`) are plaintext for fast fuzzy search. Only the secret value is encrypted. WAL mode enabled for safe concurrent access between CLI and app.

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

Lokalite reads a project-local `.lokalite` file (or `--env` flag) listing which secrets to inject:

```yaml
# .lokalite
inject:
  - OPENAI_API_KEY
  - ANTHROPIC_API_KEY
```

Then spawns the subprocess with those secrets in its environment. They never appear in the parent shell.

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

### Settings Window (`SettingsWindow`)

Full CRUD. Two panels:
- **Secrets list** — add, edit, delete, tag
- **Settings** — clipboard clear timeout, session timeout, export / import

---

## Export Format

**Encrypted** (default):

```json
{
  "version": 1,
  "algorithm": "AES-256-GCM",
  "kdf": "Argon2id",
  "salt": "<base64>",
  "nonce": "<base64>",
  "ciphertext": "<base64>",
  "tag": "<base64>"
}
```

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

- MCP server (`lokalite serve`) for agent/Claude Code integration
- Environment profiles (`ai`, `production`, etc.)
- Project linking (associate secrets with a directory)
- Secret references (`lokalite://KEY_NAME` in config files)
- Cross-platform support (Windows Credential Manager, Linux Secret Service)
- iCloud Keychain sync (optional, opt-in)
