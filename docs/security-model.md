# Security Model

## Architecture

```text
Lokalite encrypted DB/file
        ↓
Encrypted with app-generated symmetric key
        ↓
That key is stored/protected in Apple Keychain
```

Keychain protects the vault key, not individual secrets. The secrets themselves live in an encrypted local database.

---

## Why Keychain for the vault key

For the macOS-first MVP, Keychain provides:

* Native OS trust model
* Touch ID / password prompts without a custom master password
* No need for a master password initially
* Less custom crypto risk
* Better UX than asking users to remember another password

Apple explicitly positions Keychain for passwords, cryptographic keys, certificates, and other sensitive data.

---

## Why not store every secret as a Keychain item

Storing each secret directly in Keychain is possible but creates problems:

* Awkward search and filtering
* No metadata, tags, or descriptions
* Poor CLI ergonomics
* Harder to export or back up
* No cross-platform path

The better model: SQLite stores encrypted secret records, Keychain stores the encryption key.

---

## Cryptography

* **Encryption**: AES-256-GCM (authenticated encryption)
* **Key derivation** (portable/export path): Argon2id (3 iterations, 64 MiB memory, parallelism 1)
* **macOS primary path**: app-generated random key stored in Keychain

---

## Known risks and mitigations

### 1. Compromised Mac session

Keychain protects data at rest, but malware running as the user may trigger access. Mitigation: require Touch ID / password prompt before revealing secrets, app sandboxing.

### 2. Clipboard leakage

Copying secrets is the weakest point. Mitigations: auto-clear clipboard after a configurable timeout, do not support clipboard history integrations.

### 3. CLI exposure

`lokalite get OPENAI_API_KEY` can leak into shell history, logs, process output, and terminal scrollback. Mitigations: never echo secrets in plain text by default, pipe directly to clipboard or temp file, document safe usage patterns.

### 4. Backups and exports

Exporting secrets in plain text is dangerous. Mitigation: encrypted exports only by default; plain text export requires explicit confirmation.

### 5. Prompt fatigue

Over-frequent access prompts lead users to approve without thinking. Mitigation: session-based unlock with configurable timeout.

