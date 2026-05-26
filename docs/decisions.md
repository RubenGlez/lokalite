# Architecture Decisions

A record of the key decisions made during design and implementation, with rationale.

---

## D1: Storage encryption approach

Plain SQLite (GRDB.swift) + CryptoKit AES-256-GCM on the `encrypted_value` column. Secret values are encrypted before being written. Metadata (name, description, category) stays plaintext for fast search and filtering. Vault key stored in Keychain. No SQLCipher dependency.

---

## D2: CLI runtime

CLI, menu bar app, and shared core are all Swift. Single Swift Package with multiple targets. Native CryptoKit and Keychain access. No Node.js, no Tauri, no Bun.

---

## D3: Unlock model

Keychain-only. No master password. App unlocks via Touch ID / system auth. Session-based: stays unlocked until the Mac locks or the app quits. Configurable inactivity timeout available as a user setting.

---

## D4: Desktop-CLI vault sharing

Both CLI and menu bar app read and write the same `vault.db` file. SQLite WAL mode handles concurrent access. No daemon or IPC required.

---

## D5: First platform

CLI built first. Menu bar app is a native SwiftUI popover (no dock icon, `LSUIElement = true`). No Tauri, no React, no Electron.

---

## D6: CLI scope

Full CRUD from the CLI. Commands: `add`, `set`, `delete`, `get`, `copy`, `list`, `export`, `import`, `shell`, `run`, `status`, `init`, `project`. The desktop app is a convenience layer, not a requirement.

---

## D7: CLI output model

`lokalite get KEY` prints value to stdout (pipeable). `lokalite copy KEY` copies to clipboard with auto-clear. Two separate commands, user chooses.

---

## D8: Agent integration

`lokalite run <command>` injects resolved secrets as env vars into the subprocess. Secrets travel from Keychain → Lokalite memory → child process env. Nothing touches the shell.

`lokalite mcp` exposes read-only agent access by default (`get_secret`, `list_secrets`) and write tools only when explicitly started with `--read-write`.

---

## D9: Menu bar app UX

Search-first popover anchored to status bar icon. Click to copy. Separate settings window for add/edit/delete (triggered from popover footer). No dock icon.

---

## D10: Export format

`lokalite export` produces an encrypted file (Argon2id + AES-256-GCM, passphrase entered at export time). `lokalite export --plain` produces unencrypted JSON after explicit confirmation. `lokalite export --format env` produces `KEY="value"` lines for `.env` compatibility without a passphrase.
