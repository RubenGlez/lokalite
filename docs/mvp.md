# MVP

## Desktop Application

Native desktop application for macOS.

---

## Vault

Single encrypted vault protected by Apple Keychain (Touch ID / system password). No separate master password required for macOS MVP.

---

## Secret Schema

```typescript
type Secret = {
  id: string;
  name: string;
  value: string;
  description?: string;
  tags?: string[];
};
```

---

## Secret Types

* API keys
* Tokens
* Passwords
* Certificates
* Arbitrary text values

---

## Core Features

### Search

Fast fuzzy search across all secrets.

### Copy

One-click secure copy to clipboard with auto-clear timeout.

### Reveal

Temporarily reveal secret values (requires Touch ID / password prompt).

### Tags

Group secrets by category:

* AI
* Cloud
* Personal
* Client A
* Client B

---

## CLI

The CLI is a first-class citizen alongside the desktop app.

### Read Secret

```bash
lokalite get OPENAI_API_KEY
```

### List Secrets

```bash
lokalite list
```

### Copy Secret

```bash
lokalite copy OPENAI_API_KEY
```

### Export

```bash
lokalite export
```

---

## Technical Stack (proposed)

### Desktop

* React
* TypeScript
* Tauri
* Vite

### Storage

* SQLite (plain, app-level encryption)

### Cryptography

* AES-256-GCM via Rust (`aes-gcm` crate or `ring`)
* Argon2id for key derivation on portable/export path
* Apple Keychain via `tauri-plugin-keychain` for vault key storage

### CLI

* Node.js
* TypeScript
* Shared core package with desktop

---

## Open questions

These need to be resolved before implementation starts. See `decisions.md`.
