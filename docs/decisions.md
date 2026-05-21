# Open Decisions

Questions that need answers before implementation starts. Updated as decisions are made.

---

## Status key

* `open` — not yet decided
* `decided` — resolved, rationale recorded

---

## D1: Storage encryption approach

**Status**: decided — Option A

Plain SQLite (GRDB.swift) + CryptoKit AES-256-GCM on the `encrypted_value` column. Secret values are encrypted before being written. Metadata (name, tags, description) stays plaintext for fast search and filtering. Vault key stored in Keychain. No SQLCipher dependency.

---

## D2: CLI runtime

**Status**: decided — full Swift

CLI, menu bar app, and shared core are all Swift. Single Swift Package with multiple targets. Native CryptoKit and Keychain access. No Node.js, no Tauri, no Bun.

---

## D3: Unlock model

**Status**: decided — Option A with configurable timeout

Keychain-only. No master password. App unlocks via Touch ID / system auth. Session-based: stays unlocked until the Mac locks or the app quits. Configurable inactivity timeout available as a user setting. Master password not in scope for MVP.

---

## D4: Desktop-CLI vault sharing

**Status**: decided — single shared vault

Both CLI and menu bar app read and write the same `vault.db` file. SQLite WAL mode handles concurrent access. No daemon or IPC required for MVP.

---

## D5: First platform / surface

**Status**: decided — CLI first, Swift native menu bar app

CLI is built first. Menu bar app is a native SwiftUI popover (no dock icon, `LSUIElement = true`). No Tauri, no React, no Electron.

---

## D6: CLI scope

**Status**: decided — read-write

Full CRUD from the CLI. Commands: `add`, `set`, `delete`, `get`, `copy`, `list`, `export`, `run`. The desktop app is a convenience layer, not a requirement.

---

## D7: CLI output model

**Status**: decided — Option C

`lokalite get KEY` prints value to stdout (pipeable). `lokalite copy KEY` copies to clipboard with auto-clear. Two separate commands, user chooses.

---

## D8: Agent integration

**Status**: decided — `lokalite run` for MVP, MCP server on roadmap

`lokalite run <command>` injects resolved secrets as env vars into the subprocess. Secrets travel from Keychain → Lokalite memory → child process env. Nothing touches the shell. MCP server is a roadmap item.

---

## D9: Menu bar app UX

**Status**: decided — 1Password mini model

Search-first popover anchored to status bar icon. Click to copy. Separate settings window for add/edit/delete (triggered from popover footer). No dock icon.

---

## D10: Export format

**Status**: decided — Option C

`lokalite export` produces an encrypted JSON file (Argon2id + AES-256-GCM, passphrase entered at export time). `lokalite export --plain` produces unencrypted JSON after explicit confirmation. `--plain` output is `.env`-compatible.
