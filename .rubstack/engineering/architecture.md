# Architecture

## Overview

Lokalite is a local-first secrets manager for individual developers. The shipped product is a Swift-only macOS 14 application with an independent CLI/MCP surface, an app-owned daemon broker, an encrypted SQLite vault, four agent-access tiers, and an audit log. The target architecture replaces the Swift implementation with a Rust Cargo workspace and a Tauri 2 desktop shell for macOS 14+ and Windows 11, while preserving the current vault, encryption, backup, CLI, MCP, and policy contracts exactly for existing macOS users. The desktop application remains the sole owner of the unlocked vault key and daemon; the React frontend is an untrusted presentation layer over a narrow Rust command surface. Linux, mobile, cloud services, accounts, synchronization, and team features are outside the first multiplatform release.

The migration is paused as of 2026-11-08 (see the implementation plan's Status); the target architecture below describes where it resumes. It is developed incrementally behind the shipped Swift product, then released as a clean replacement. There is no public Swift/Rust hybrid and no supported state in which the old and new daemons run side by side.

```text
React + TypeScript UI
          |
    narrow Tauri commands
          |
  lokalite-desktop (Rust, vault owner)
          |
    lokalite-service
      /           \
local UI       versioned daemon IPC <---- lokalite-cli / MCP
      \           /
       domain + crypto + storage
                  |
       platform security adapters
      macOS                     Windows
 Keychain + LA          DPAPI + Windows Hello
 UDS + peer PID         named pipe + peer PID
```

## Components

### `lokalite-domain`

Platform-independent models and rules. It owns projects, environments, secrets, secret values, categories, activity records, validation, project/environment resolution, secret-reference parsing, and the four agent-access tiers: `allowed`, `requiresApproval`, `strict`, and `blocked`.

Policy decisions are defined here or in `lokalite-service`, never in the UI or platform adapters. Agent detection and process-signature results are attribution signals for prompts and audit records. They are never sufficient to grant access, and a missing or unverified identity never weakens a caller-independent approval rule.

### `lokalite-crypto`

Implements formats already persisted by the Swift release:

- Per-value AES-256-GCM with a fresh random nonce and the exact CryptoKit combined representation, `nonce || ciphertext || tag`.
- The existing version `0x02` encrypted backup/export envelope.
- Argon2id with 3 iterations, 64 MiB memory, parallelism 1, and a 32-byte salt for the portable backup path.
- Secret-bearing buffers wrapped with `secrecy` or equivalent types and cleared with `zeroize` where ownership permits.

Compatibility tests use fixtures produced by CryptoKit and the shipped backup implementation. A Rust round trip alone is not evidence of compatibility.

### `lokalite-storage`

Owns SQLite access through `rusqlite` with bundled SQLite and backup support. It opens the current platform vault path, preserves the existing schema and migrations, enables foreign keys and WAL behavior as today, and exposes explicit validation and backup operations used before migration.

The durable model remains:

- A project has many environments and secrets, one active environment, and an optional linked directory.
- A secret has metadata and one encrypted value per environment.
- Secret names and descriptions remain plaintext for search; only secret values are encrypted.
- The config table retains the globally active project and other existing durable settings.
- The activity log records read, create, update, delete, and deny events together with source and available caller attribution.

The Rust implementation must read and write the current database without a forced export/import. Schema changes, if any become necessary, use forward migrations that the first-launch backup protects. Raw vault copying between computers is unsupported because the vault key is bound to the source operating-system account.

### `lokalite-platform`

Defines narrow traits for capabilities that differ by operating system: key protection, user-presence verification, local IPC, caller PID and signature attribution, clipboard access and clearing, filesystem paths, autostart, application launch, and update integration.

The macOS adapter:

- Opens the exact existing Keychain generic-password item with service `com.lokalite.vault` and account `vault-key`.
- Uses LocalAuthentication for unlock and approval prompts.
- Uses a Unix domain socket and obtains the kernel-reported peer PID with `LOCAL_PEERPID`.
- Retains the existing application-support paths and preferences where they are part of compatibility.

The Windows adapter:

- Generates the same 32-byte vault key and protects it with user-scope DPAPI. `CRYPTPROTECT_LOCAL_MACHINE` is never used.
- Requires Windows Hello for unlock and protected approvals through `IUserConsentVerifierInterop::RequestVerificationForWindowAsync`, bound to the Tauri application HWND.
- Fails closed when Windows Hello is unavailable or not configured. Lokalite has no fallback password.
- Uses an owner-only named pipe and obtains the kernel-reported client PID with `GetNamedPipeClientProcessId`.
- Integrates Windows clipboard, paths, process identity/signature, autostart, launch, and Store update behavior behind the same capability boundaries.

### `lokalite-protocol`

Contains Serde request, response, envelope, approval, error, and version-negotiation types for the daemon protocol. The wire format remains newline-delimited JSON and can decode the current Swift JSON contract. The new daemon supports clients from the immediately previous release; new clients detect an older incompatible daemon and explain that the application must be updated or opened.

Protocol evolution is additive where possible and explicitly versioned where not. Neither the CLI nor MCP server may silently fall back to opening the vault locally when broker communication fails.

### `lokalite-service`

Is the only application layer allowed to combine storage, cryptography, policy, sessions, approvals, and audit behavior. It owns vault lock state, session timeout, project/environment resolution, per-secret agent-access enforcement, daemon request dispatch, approval grant caching, and activity recording.

The four access tiers preserve current semantics:

- `allowed` follows normal unlock/session rules.
- `requiresApproval` prompts every caller outside the owning desktop UI and caches consent for the session.
- `strict` prompts on every external read.
- `blocked` denies agent-classified callers.

Caller-independent approval remains the security boundary. Kernel-derived process identity, code-signature information, and the client's tighten-only agent hint improve attribution, but cannot bypass an approval or denial. Headless paths that require a GUI prompt fail closed.

### `lokalite-cli`

An independent Rust binary using `clap`. It preserves the shipped command names, arguments, output behavior, environment and linked-directory resolution, secret references, exit behavior, and MCP configuration contract. The `mcp` subcommand hosts the stdio JSON-RPC server in the same binary and preserves the existing read-only default plus explicit read-write opt-in.

Secret-bearing CLI operations use the daemon broker when policy or unlock requires desktop user presence. Bulk reveal paths continue to exclude approval-tier secrets. `run --local` remains an explicit headless mode whose approval-tier reads fail closed; it is not an automatic fallback.

`lokalite shell` preserves its current POSIX output on macOS. On Windows it emits PowerShell syntax by default and accepts `--shell powershell|posix|cmd`; this is an explicit platform adaptation, while `lokalite run` remains the safer platform-independent path.

### `lokalite-desktop`

A Tauri 2 application containing the Rust backend and a React + TypeScript + Vite frontend. It provides the system tray, global shortcut, manager window, onboarding, preferences, approvals, audit views, and vault lifecycle. Tauri single-instance, autostart, global-shortcut, and system-tray capabilities are used where package rules allow, with small platform-specific implementations where macOS or Microsoft Store behavior requires them.

The frontend may receive a decrypted value only for an explicit human reveal or copy action. It never receives the vault key, a database handle, raw database contents, a general decrypt primitive, or direct filesystem access to the vault. Copy operations should be performed in Rust when practical so a value need not cross the webview boundary merely to reach the clipboard.

The application preserves Lokalite's armadillo and terminal-vault identity. Layout and controls follow platform conventions, so the goal is capability and security parity rather than pixel parity.

### Workspace layout

```text
lokalite/
  Cargo.toml
  crates/
    lokalite-domain/
    lokalite-crypto/
    lokalite-storage/
    lokalite-platform/
    lokalite-protocol/
    lokalite-service/
    lokalite-cli/
    lokalite-desktop/
      src-tauri/
      ui/
  Sources/                 # retained only during private parity work
  Tests/                   # Swift reference tests/fixtures during migration
```

The exact physical nesting of `src-tauri` may follow Tauri tooling, but crate ownership and dependency direction remain as above. Domain, crypto, storage, protocol, and service crates do not depend on Tauri or React.

## Data flow

### Desktop unlock

```text
Human unlock action
  -> platform user-presence prompt
      macOS: LocalAuthentication
      Windows: Windows Hello bound to the app HWND
  -> platform key store returns/decrypts the 32-byte vault key
  -> service retains the key only for the configured session
  -> storage decrypts individual values on demand
  -> inactivity expiry clears key material from memory
```

The macOS adapter reads the current Keychain item rather than creating a replacement. Windows stores a DPAPI-protected key scoped to the current user. A locked daemon request that needs the key asks the desktop to authenticate; it never retrieves or creates the key without user presence.

### Brokered CLI or MCP read

```text
CLI/MCP request
  -> versioned JSON line over local IPC
  -> daemon derives client PID from the connection
  -> platform adapter gathers process/signature attribution
  -> service combines kernel attribution with tighten-only agent hint
  -> service resolves project, environment, secret, and access tier
  -> unlock/approval prompt when required
  -> storage reads ciphertext; crypto decrypts one value
  -> service records the outcome in the activity log
  -> value or structured denial returns to the caller
```

The pipe or socket is restricted to the owning user. Peer signature verification is recorded for attribution, not authorization. If the daemon is unavailable or incompatible, sensitive operations fail with a clear recovery instruction and do not open the database in the CLI process.

### Explicit desktop reveal or copy

The human invokes reveal or copy in the desktop UI. A narrow Tauri command asks the service for that one secret after normal unlock checks. Reveal may return that value to the webview for the visible control; copy should write it through the platform clipboard adapter and return only success. Clipboard data is cleared after the configured timeout when it still contains the copied value.

### First launch after the Swift application

1. Acquire single-instance ownership and ensure the old daemon is not running.
2. Discover the current macOS vault, preferences, and exact Keychain entry.
3. Create a preventive encrypted or database-level backup before any write.
4. Validate schema, migration history, ciphertext fixtures, and key access.
5. Apply only required forward migrations transactionally.
6. Revalidate the vault, then open the normal Tauri experience.
7. On failure, leave the original vault untouched and present recovery instructions.

The new application replaces the Swift application through a normal signed update. One Sparkle bridge release carries users from the old updater into the Tauri application. Later releases may use the Tauri updater. Side-by-side app ownership and dual-daemon writes are unsupported.

### Backup and cross-machine restore

Encrypted backups are the official transport between macOS and Windows. Export derives a key from the user's passphrase with the existing Argon2id parameters and writes the existing envelope. Its existing scope remains the active Project's Active Environment as a name/value set, including the current approval-tier exclusions; it is not expanded into a full-vault metadata format during this migration. Restore validates and decrypts that envelope, then imports those values into a destination Project and Environment under the destination system's local key. The raw SQLite vault and its OS-bound key are never presented as a portable pair.

### Distribution and updates

macOS builds retain Developer ID signing, hardened-runtime rules, notarization, and the existing Sparkle-to-Tauri bridge path. Windows builds target x64 and ARM64. Microsoft Store MSIX is the primary and supported Windows channel, providing Store signing and updates; an unsigned direct-download channel is not supported.

## Stack

- Language: stable Rust for domain, crypto, storage, service, protocol, CLI, and desktop backend; TypeScript for the desktop UI.
- Framework: Tauri 2 for the desktop shell; React + Vite for UI composition and bundling.
- Database / storage: SQLite through `rusqlite` with bundled SQLite and backup support; existing macOS Keychain item; user-scope Windows DPAPI.
- Key libraries: `serde` and `serde_json` for persisted and wire contracts; `aes-gcm`, `argon2`, and `rand` for compatible cryptography; `secrecy` and `zeroize` for key material; `tokio` for daemon concurrency and IPC; `clap` for the CLI; `tracing` for structured diagnostics without secret values; `windows` for DPAPI, Windows Hello, named pipes, and process APIs; `security-framework` and focused `objc2` bindings where needed for macOS Keychain, LocalAuthentication, and native APIs.
- Desktop capabilities: Tauri 2 system tray, single-instance, global-shortcut, and autostart plugins where compatible with the signed package model.
- Tests: Rust unit and integration tests; Swift-generated cross-language crypto, database, protocol, and backup fixtures; Vitest + Testing Library for React behavior; Playwright for desktop webview flows where practical; signed-package QA on real Windows 11 hardware before release.
- Build and distribution: Cargo workspace; pnpm for frontend dependencies; Apple Developer ID/notarization and a one-time Sparkle bridge on macOS; Store-signed MSIX packages for Windows x64 and ARM64.

## Key decisions

### Preserve formats and behavior instead of requiring migration by export

Existing macOS users keep the same database, schema history, AES-GCM byte layout, Keychain identity, backup envelope, CLI commands, MCP contract, paths, and data. A first-launch backup plus validation protects the only acceptable automatic migration path. This raises the fixture and compatibility-testing burden, but avoids forcing users to expose or reconstruct a secrets vault.

### Keep the desktop application as the sole vault and daemon owner

The CLI and MCP client remain independent executables, but broker key-needing work through the application-owned daemon. There is no silent local fallback and no supported dual-daemon state. This keeps GUI-bound authentication available at the authorization chokepoint and prevents multiple processes from independently owning the master key or writing the vault.

### Isolate platform security behind narrow adapters

The security guarantees are shared, while the mechanisms are native: Keychain and LocalAuthentication on macOS, user-scope DPAPI and Windows Hello on Windows; Unix domain sockets on macOS, owner-only named pipes on Windows. This gives capability and security parity without pretending the operating systems have identical APIs or visual conventions.

### Ship only supported, signed desktop channels

The first multiplatform release supports macOS 14+ and Windows 11 x64/ARM64. Windows ships through Microsoft Store MSIX so an individual developer can provide Store signing and updates without a recurring code-signing subscription. Linux and unsigned Windows downloads are deliberately out of scope.

## Security constraints

- No telemetry, account, cloud, or synchronization path receives secrets or key material.
- Logs and errors never include secret values, passphrases, decrypted backup payloads, vault keys, or full IPC frames that can contain them.
- The React/webview layer cannot enumerate raw ciphertext or call generic database/crypto operations.
- UI prompts are bound to the owning desktop window where the platform API supports it.
- Key-store scope and IPC ACLs are per user, never machine-wide.
- Agent identity and code signing are attribution-only. Authorization follows explicit policy and authenticated user presence.
- Backups are portable; raw vault files are not.

## Open questions

- Validate that the Microsoft Store MSIX package can expose the required `lokalite` app execution alias for the independent CLI binary and its `mcp` subcommand without unsupported installation-directory assumptions.
- Validate Windows Hello HWND interop from Tauri 2, including cancellation, unavailable, remote-session, and concurrent-prompt behavior.
- Validate Store-packaged tray and autostart lifecycle behavior across sign-in, update, suspend, and app termination.
- Validate every native dependency and bundled SQLite path on Windows ARM64, not only cross-compilation.
- Validate the one-time Sparkle update from the last Swift release to the correctly signed Tauri application, including rollback behavior if first-launch validation fails.
