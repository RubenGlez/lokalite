# Compatibility gate

This directory is the durable, synthetic-only harness for Phase 0 Task 0.1.
It never discovers or opens Lokalite's production Vault, Keychain item, or
application-support directory. Every artifact is created below a fresh temporary
directory and deleted when the command exits.

The macOS oracle uses the shipped Swift module's CryptoKit, Argon2id, GRDB, and
registered migrations. The independent Rust harness uses pinned `aes-gcm`,
`argon2`, and `rusqlite` versions. They verify both directions:

1. Rust generates AES-GCM and Encrypted Export v2 fixtures; Swift decrypts them
   and rejects wrong keys, passphrases, and mutations.
2. Swift generates the same formats; Rust decrypts and authenticates them.
3. Swift/GRDB creates synthetic Vaults at `v1`, `v3`, `v4`, `v5`, `v6`, and
   `v7`; Rust verifies their migration history, UTF-8, nullable/BLOB contracts,
   writes only to copies, and Swift reopens those copies.

Run the complete oracle on macOS 14+:

```sh
bash scripts/compatibility.sh
```

Static/build checks that do not execute the oracle:

```sh
cargo fmt --manifest-path Compatibility/Cargo.toml -- --check
cargo check --all-targets --manifest-path Compatibility/Cargo.toml
swift build --build-tests
```

Fixture producers, algorithms, public parameters, and synthetic payloads are
recorded in the generated JSON. Generated fixture directories are CI artifacts,
not repository inputs, so a stale or hand-edited binary cannot satisfy the gate.
Changing a shipped format requires an additive test vector; existing cases must
not be rewritten.
