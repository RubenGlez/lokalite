# Compatibility contracts (Phase 1, Task 1.2)

This directory freezes the behavior existing users and integrations depend on,
so it can be ported instead of remembered. It is the oracle the Rust
replacement is measured against; it is not a place to change behavior.

The shipped Swift application is the baseline. Every case here asserts what the
baseline *already does*, including behavior that looks like an accident. If a
contract case and the baseline disagree, the case is wrong until a deliberate
decision says otherwise.

No case may use a production Vault, Keychain item, or application-support
directory. Fixtures are synthetic and created below a temporary directory.

## What is already covered, and what is not

The repository has 181 test functions across 15 files. They are thorough about
*logic* — the dispatcher's policy branches, the grant cache, reference parsing,
migrations — and they exercise it through Swift APIs.

That is not the same as a frozen contract. A different implementation does not
call `VaultRequestDispatcher.handle`; it produces bytes. What is missing is the
**observable** surface:

| Observed by | Frozen here | Existing tests |
|---|---|---|
| A user's shell script | exit code, stdout, stderr | behavior, not the text |
| An MCP client | JSON-RPC frames | tool results, not the envelope |
| A daemon peer | request/response JSON encoding | round-trip, not the bytes |
| An existing install | on-disk schema and ciphertext | covered by `Compatibility/` |

So the work is not to re-test the logic. It is to pin the surface the logic is
seen through.

## Contract areas

### 1. CLI commands and output

**Surface**: 21 subcommands (`Sources/lokalite/Lokalite.swift:10`) declaring 133
options, flags, and arguments across `Sources/lokalite/Commands/`.

**Freeze**: for each command — exit code, stdout bytes, stderr bytes, and side
effects, for the success case and every named failure. Specifically:

- The stdout/stderr split is itself a contract. `shell` writes eval-safe output
  to stdout and its approval-tier skip notice to stderr; `run` gives stdout to
  the child (`Lokalite.swift:226`). A port that merges them breaks working
  scripts silently.
- `--shell powershell|posix|cmd` on Windows is new behavior, not a contract;
  the POSIX output on macOS is a contract and must stay byte-identical.
- Refusal messages are user-facing text with instructions in them
  (`Lokalite.swift:53`, `:70`, `:159`). They are contracts, not log lines.
- `importSummaryLine` (`Lokalite.swift:234`) has exact pluralization and an
  embedded hint; `approvalTierSkipNotice` (`:217`) switches on singular/plural.

**Risk**: highest volume, lowest existing coverage. No current test asserts CLI
stdout.

### 2. MCP tools and protocol

**Surface**: 8 tools — `get_secret`, `list_secrets`, `list_projects`,
`list_environments`, `use_environment`, `add_secret`, `set_secret`,
`delete_secret` (`Sources/lokalite/MCP/LokaliteMCPTools.swift:28`). JSON-RPC
2.0, `protocolVersion` `2024-11-05`, `serverInfo` `lokalite` / `1.0.0`
(`MCPServer.swift:70`).

**Freeze**: the `initialize` response; the `tools/list` schema for all 8 tools
verbatim; read-only mode exposing only the non-write tools; notifications
(messages with no `id`) being dropped silently; the `get_secret` handoff text
that must never contain the value (`LokaliteMCPTools.swift:56`); the
`[approval required]`, `[approval required every read]`, and
`[off-limits to agents]` markers in `list_secrets`.

**Existing**: `MCPToolsTests.swift` covers tool behavior but not the wire frames.

### 3. IPC messages

**Surface**: 13 `VaultRequest` cases and 9 `VaultResponse` cases
(`Sources/LokaliteCore/VaultWireProtocol.swift:15`, `:33`), wrapped in
`VaultEnvelope` with a **bare-frame fallback** for legacy clients (`:49`).

**Freeze**: the JSON encoding of every case, in both directions, as bytes. The
enum is `Codable`-synthesized, so the wire shape is an emergent property of
Swift's derivation — a hand-written Rust encoder will not match it by accident.
This is the single highest-risk item in the inventory.

Also frozen: the envelope's tighten-only merge (`:86`) — a client hint may add
agent classification, never remove it — and that `.unlock` is a reachability
handshake that deliberately does **not** unlock (`:208`).

**Existing**: `VaultWireTests.swift` round-trips through Swift's own coder,
which cannot catch a shape a second implementation would render differently.

### 4. Schema versions

**Surface**: migrations `v1`, `v3`, `v4`, `v5`, `v6`, `v7`
(`Sources/LokaliteCore/Storage/VaultStoreMigrations.swift`).

**Freeze**: **there is no `v2`** (`:72`). GRDB keys migrations by string, so the
gap is harmless — but only if the port also skips it. A port that renumbers to a
contiguous sequence will not open an existing vault.

Also frozen: the partial unique index on `secret_values(secret_id)` where
`environment_id IS NULL` (`:56`); the v1 seeding of a project literally named
`Default` plus the `active_project_id` config row (`:62`); v4 back-filling
per-project Default environments; the `NOT NULL DEFAULT` on `agent_access` and
`action`; the nullable additive `peer_team`.

**Existing**: `Compatibility/` already proves v1/v3–v7 fixtures open in both
directions. That gate is passed; this area mostly cross-references it.

### 5. Backups and export

**Surface**: `ExportCommand`, `BackupCommand`, `RestoreCommand`, and the Export
v2 Argon2id/AES-GCM envelope.

**Freeze**: the envelope bytes (already covered by `Compatibility/`); that
approval-tier secrets are **excluded** from `backup` and `export --format env`
with a skip notice naming them (`Lokalite.swift:188`); that a wrong passphrase
or damaged payload fails with no partial write.

### 6. Context resolution

**Surface**: `resolveContext` (`Lokalite.swift:244`) merging flags with
`LOKALITE_PROJECT` / `LOKALITE_ENV`, then `SecretWorkspace.resolveContext`.

**Freeze**: the precedence chain — explicit name, then linked directory, then
stored active project, then single-project fallback, then `noActiveProject` —
and that an env var loses to an explicit flag. Ten tests already cover the
resolution logic; the contract adds the environment-variable merge and the
error text.

### 7. Agent-governance outcomes

**Surface**: 4 tiers (`allowed`, `blocked`, `requiresApproval`, `strict`) across
read and write paths, for three caller kinds (human CLI, detected agent, MCP
client), in-process and daemon-brokered.

**Freeze**: the outcome matrix, and the two properties that are the whole point
of ADR 0018 —

- Approval tiers prompt for **every** caller, humans included
  (`VaultWireProtocol.swift:226`). This is not an agent feature.
- A refused reveal never decrypts: the guard runs before the fetch
  (`Lokalite.swift:111`).
- A write always prompts per call (`:320`), so a cached read grant never
  authorizes a destructive change.
- Detection is attribution-only; a detection miss costs a label, not
  enforcement.

**Existing**: the strongest area — `AgentAccessPolicyTests` and
`CallerIndependentApprovalTests` are 753 lines together. The contract's job is
to restate the outcomes as data a second implementation can be run against,
rather than as Swift assertions.

## Proposed shape

Each area gets a JSON fixture file of cases with asserted expected results, plus
a runner that feeds them to an implementation. The Swift baseline runs them
first and must pass unchanged — a case the baseline fails is a wrong case, not a
found bug.

Fixtures are inputs to both implementations, never outputs of one: a generated
file that only ever round-trips through its own producer proves nothing, which
is why `Compatibility/` treats generated fixture directories as CI artifacts
rather than repository inputs.

## Order of work

1. **IPC encodings** — highest risk, smallest surface, and it blocks Task 3.1.
2. **MCP frames** — a published integration surface with existing user configs.
3. **CLI output** — largest volume; user scripts depend on it byte-for-byte.
4. **Governance matrix** — restating outcomes that are already well covered.

Context resolution and backups fold into the CLI and the existing
`Compatibility/` gate respectively.
