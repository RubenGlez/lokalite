# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run

```bash
# Build all targets
swift build

# Build a specific target
swift build --target lokalite
swift build --target LokaliteApp

# Run the CLI (required — direct binary execution fails due to entitlements)
swift run lokalite <subcommand>

# Run the menu bar app
swift run LokaliteApp

# Run tests
swift test

# Run a single test class
swift test --filter VaultCryptoTests
```

Use `swift run` rather than executing binaries from `.build/` directly; the entitlement signing step only runs via `swift run`.

## Architecture

Three Swift targets share a single package:

- **LokaliteCore** — library; owns all vault logic, crypto, and storage. No UI dependencies. Both executables import this.
- **lokalite** — CLI executable; parses arguments via `swift-argument-parser`, calls `LokaliteCore`, writes to stdout/clipboard.
- **LokaliteApp** — menu bar app; SwiftUI with `MenuBarExtra(.window)`, no dock icon (`NSApp.setActivationPolicy(.accessory)`).

All targets use `swiftLanguageMode(.v5)` in `Package.swift`. New targets must include this setting or Swift 6 concurrency checks will break compilation.

## Core Data Flow

**Vault unlock** (CLI and app both call this before any secret access):
1. `Vault.shared.unlock()` checks `KeychainStore` for an existing vault key.
2. If none exists, generates a 256-bit `SymmetricKey` and stores it in Keychain (`com.lokalite.vault` / `vault-key`).
3. The key is held in memory on `Vault.shared`; `lock()` wipes it.

**Secret storage**: SQLite at `~/Library/Application Support/Lokalite/vault.db` via GRDB.swift. Only `encrypted_value` is encrypted (AES-256-GCM via CryptoKit). Name, tags, and description are plaintext to allow fast search. Tags are stored as a JSON array string.

**Encryption**: `VaultCrypto` wraps CryptoKit. Each `encrypt` call generates a fresh nonce; the sealed box (nonce + ciphertext + tag) is stored as a BLOB.

## Key Relationships

- `Vault` (singleton) is the only public API surface for `LokaliteCore`. All commands go through it.
- CLI commands use the `withVault { }` helper in `Lokalite.swift` which calls `unlock()` and passes the vault to the closure.
- `VaultViewModel` (app-only) wraps `Vault.shared` for SwiftUI, adds Touch ID via `LAContext`, session timeout via `Timer`, and clipboard auto-clear.
- The MCP server (`lokalite mcp`) calls `vault.unlock()` directly and serves JSON-RPC 2.0 over stdin/stdout.

## MCP Server

`Sources/lokalite/MCP/MCPServer.swift` implements the Model Context Protocol for Claude Code integration. Transport is stdio, JSON-RPC 2.0, protocol version `2024-11-05`. Notifications (no `id` field) are silently dropped; all other methods return a JSON-RPC response.

**Default (read-only):** exposes `get_secret` and `list_secrets`.  
**With `--read-write`:** also exposes `add_secret`, `set_secret`, and `delete_secret`.

`list_secrets` uses `vault.listInfo()` — metadata only, no decryption.

`MCPServer` takes an `allowWrites: Bool` parameter; `MCPCommand` passes it from the `--read-write` flag.

Claude Code config (written automatically by `lokalite install`):
```json
{
  "mcpServers": {
    "lokalite": { "command": "lokalite", "args": ["mcp"] }
  }
}
```

## Install Command

`Sources/lokalite/Commands/InstallCommand.swift` copies the running binary to `--bin-dir` (default `/usr/local/bin`) and writes the MCP server entry to `~/.claude.json`. Run via `make install` after a release build.
