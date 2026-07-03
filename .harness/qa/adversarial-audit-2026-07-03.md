# Lokalite — Adversarial Codebase Audit (2026-07-03)

Reviewer role: senior staff engineer + skeptical first-time user + adversarial
security reviewer. Target: `/home/user/lokalite` at commit `b45ad7d`
(branch `claude/codebase-adversarial-audit-wo8pbw`, default branch `main`).

Scope covered in full: crypto (`VaultCrypto`, `KeychainStore`), vault core
(`Vault`, `VaultStore` + query files, migrations), the Unix-socket daemon
(`VaultSocket`, `VaultWireProtocol`/dispatcher, `VaultService`,
`RemoteVaultService`), agent detection + peer code-signature verification, the
MCP tool surface + handoff, every CLI command, the menu-bar app
(`LokaliteApp`, `VaultViewModel`, `AgentApprovalCoordinator`, session/clipboard/
hotkey), release automation (`scripts/release.sh`, `.github/workflows/*`), and
the test suite. `.harness/adr/*` and `.harness/qa/report.md` are age-encrypted
in this repo (doctier self-hosting) and could not be read without a key — ADR
drift was assessed against `AGENTS.md` + code only (see Open Questions).

---

## 1. System map

### Processes and trust boundaries

- **Menu-bar app (`LokaliteApp`)** — the *vault daemon* and sole key owner
  (ADR 0014). Owns `Vault.shared`, holds the AES-256 key in memory when
  unlocked, and runs a `VaultSocketServer` on a Unix domain socket at
  `~/Library/Application Support/Lokalite/daemon.sock` (dir `0700`, socket
  `0600`). Gates *UI* unlock behind Touch ID (`VaultViewModel.unlock`).
- **CLI (`lokalite`)** — ArgumentParser tool. Two very different modes:
  - **In-process**: `withVault`/`withWorkspace` → `Vault.shared.unlock()` loads
    the key from the Keychain *into the CLI process*. Used by `get` (non-approval
    tier), `copy`, `list`, `shell`, `export`, `run` bulk injection, `backup`,
    `restore`, `import`, `seed`, `env`/`project`.
  - **Daemon-backed**: `RemoteVaultService` over the socket. Used by the
    approval-tier reveal route (`CLIReveal.fetchThroughDaemon`), `run`
    `lokalite://` reference resolution (default), and `mcp` (default).
- **MCP server (`lokalite mcp`)** — stdio JSON-RPC for coding agents. Default is
  daemon-backed (never holds key); `--local` opens `Vault.shared` in-process.
  Exposes read tools (`get_secret` via single-use shell handoff, `list_secrets`,
  `list_projects`, `list_environments`, `use_environment`) and, with
  `--read-write`, `add_secret`/`set_secret`/`delete_secret`.

Kernel-derived peer identity: `LOCAL_PEERPID` → `AgentDetection` process-tree
walk (agent token) and `PeerCodeVerifier` (Developer ID signature, attribution
only). The socket file mode `0600` restricts connections to the same UID.

### Encryption

- Per-value: `AES.GCM.seal(...).combined` with a random 256-bit key
  (`SymmetricKey(size:.bits256)`), stored per (secret, environment) as a BLOB.
  Nonce handled by CryptoKit (fresh per seal), stored in the combined box. Sound.
- Export/backup envelope (`0x02` magic): Argon2id (t=3, m=64 MiB, p=1) over a
  32-byte `SecRandomCopyBytes` salt → AES-GCM. KDF params are stored in the
  envelope and honored on decrypt. Passphrase zeroed with `memset_s` after use.
- Vault key at rest: Keychain generic-password `WhenUnlocked`, login (file)
  keychain, **no `SecAccessControl`** (documented tradeoff in `KeychainStore`).

### Key invariants (as intended)

1. Only the app holds the key; CLI/MCP broker through the daemon (ADR 0014).
2. Approval-tier (`requiresApproval`/`strict`) reads require consent for **every**
   caller, human included; enforcement is caller-independent (ADR 0018).
3. `blocked` secrets are never released to a detected agent.
4. A secret value never enters an agent's model context (MCP handoff principle).
5. One synced active environment across app/CLI/agent (ADR 0016).

Findings below show invariants **1 and 4** are only partially upheld by the code.

---

## 2. Findings (ranked)

### HIGH

---

**H1 — The daemon's `.unlock` request loads the vault key with no Touch ID, so
the app's unlock/lock/session-timeout UI is not a security boundary for
default-tier secrets.**
`Sources/LokaliteCore/VaultWireProtocol.swift:173` (`case .unlock`),
`Sources/LokaliteCore/Vault.swift:56` (`unlock()`),
`Sources/LokaliteCore/Keychain/KeychainStore.swift:33` (`load()`).

The app gates unlock behind Touch ID only in `VaultViewModel.unlock`. The
Keychain item is `kSecAttrAccessibleWhenUnlocked` with **no** access-control
flags, so loading it needs no biometric. `VaultRequest.unlock` →
`service.unlock()` → `Vault.unlock()` calls `KeychainStore.load()` unconditionally
and sets the in-memory key. The daemon is started at app launch regardless of
lock state (`LokaliteApp.startVaultDaemon`), and `RemoteVaultService.unlock`
(called at MCP/CLI startup via `SecretWorkspace.unlock`) issues `.unlock`.

Scenario (CONFIRMED by trace): any same-UID local process — the recommended
`lokalite mcp` server, or a hand-rolled socket client — connects to
`daemon.sock`, sends `{"unlock"}` then `{"list", …}`/`{"get", …}`, and reads
every `allowed`/default-tier secret in plaintext. No Touch ID, no app unlock,
even after the session auto-lock cleared the app's own key (a subsequent
`.unlock` reloads it). Daemon activity also never renews or is bounded by the
app's `SessionPolicy` timer.

Impact: the Touch ID unlock, the lock button, and the session timeout protect
only (a) what the app UI shows and (b) the approval-tier, which re-checks Touch
ID per read. For the default tier they are effectively cosmetic against local
processes. If "unlocked user session = trusted" is the real boundary, the UI
overstates protection; if it is not, this is an authentication bypass.
Recommended direction: require the app to be UI-unlocked (and optionally re-arm
the session timer) before the daemon services value-returning requests; or move
the key to a data-protection Keychain item guarded by
`SecAccessControlCreateWithFlags(.userPresence)` so a load itself requires
presence. At minimum, stop documenting the lock/timeout as a protection boundary
it does not enforce.

---

**H2 — `lokalite get`/`copy` let a detected agent exfiltrate any default-tier
secret to stdout/clipboard, defeating the MCP "value never enters agent context"
guarantee.**
`Sources/lokalite/Commands/GetCommand.swift:27` (`print(secret.value…)`),
`Sources/lokalite/Lokalite.swift:67` (`enforceAgentRevealPolicy` checks only
`blocksAgents`), vs. `Sources/lokalite/Lokalite.swift:53`
(`ensureNotAgentExfil`, applied only to `shell`/`export`).

The whole MCP design routes values through a single-use shell handoff so the raw
value never reaches the model context (`MCPServer.instructions`,
`MCPSecretHandoff`). But an agent in the calling process tree can simply run
`lokalite get OPENAI_API_KEY`, which prints the value to stdout — straight into
the agent's captured output/context. `get`/`copy` enforce only the `blocked`
tier (`enforceAgentRevealPolicy`); the blanket agent refusal `ensureNotAgentExfil`
guards `shell`/`export` but **not** `get`/`copy`. Default policy is `allowed`.

Scenario (CONFIRMED): agent shells out `lokalite get STRIPE_SECRET_KEY` for any
secret the user left at the default tier → value in context/logs. `copy` places
it on the shared clipboard. Impact: the product's headline no-context guarantee
holds only for secrets the user manually marked `blocked`/approval — the safe
default is the *un-safe* one for the CLI path. Recommended direction: apply the
same agent-exfil refusal (or a per-secret "print to stdout is an agent-reveal"
rule) to `get`/`copy`, or route agent `get` through the handoff like MCP; make
the default tier not silently printable to a detected agent.

---

**H3 — Agent-access policy governs reads only; a write-enabled agent can
overwrite or delete even `blocked`/`requiresApproval`/`strict` secrets with no
consent.**
`Sources/LokaliteCore/VaultWireProtocol.swift:212` (`.set`), `:214` (`.delete`)
— neither consults `caller.isAgent` or `agentAccess`;
`Sources/lokalite/MCP/LokaliteMCPTools.swift:161`/`182` (`set_secret`/
`delete_secret` gated only by `allowWrites`).

The dispatcher enforces policy on `.get`/`.list` but `.set` and `.delete` are
unconditional. `AgentAccessPolicy` is a read-governance model only.

Scenario (CONFIRMED): an agent using a `--read-write` MCP server (or driving the
CLI `set`/`delete`) runs `set_secret DEPLOY_KEY <attacker-value>` or
`delete_secret <a blocked secret>`. A `strict`/`blocked` secret the user believed
was protected is silently clobbered or destroyed — no Touch ID, no denial log.
Impact: integrity/availability of the most sensitive secrets. Recommended
direction: gate writes to `blocked`/approval-tier secrets behind the same consent
broker (or refuse agent writes to governed secrets), and audit-log agent writes.

---

### MEDIUM

---

**M1 — "The CLI and MCP server never hold the vault key" (ADR 0014 / AGENTS.md)
is false for the CLI's common paths.**
`Sources/lokalite/Lokalite.swift:38-48` (`withVault`/`withWorkspace` →
`Vault.shared.unlock()`), used by `list`, `get` (non-approval), `copy`, `shell`,
`export`, `run` bulk, `backup`, `restore`, `import`, `seed`.

Only the MCP default path and the approval-tier CLI reveal actually broker
through the daemon. Every other CLI invocation loads the key from the Keychain
directly into the CLI process. CONFIRMED. This is a load-bearing incoherence: the
security narrative (key isolation) does not match the dominant code path, and it
compounds H1 (any local process can obtain plaintext trivially). Recommended
direction: either route all value paths through the daemon, or restate the model
honestly as "local same-UID process = trusted; key isolation applies to
agent-facing MCP only."

---

**M2 — Dispatcher `.list` for agents filters only `blocked`, not the approval
tiers — contradicting its own "daemon enforces independently (defense in depth)"
comment.**
`Sources/LokaliteCore/VaultWireProtocol.swift:217-223`.

`.get` gates `requiresApproval`/`strict`; `.list` (which returns decrypted
values) only strips `blocksAgents` for agents. There is no test asserting
approval-tier exclusion from `.list` (`AgentAccessPolicyTests:94` covers only
`blocked`). Currently no shipped agent-reachable caller uses daemon `.list`
(MCP uses `listInfo`; CLI bulk uses in-process `bulkRevealSecrets`, which
excludes approval-tier), so this is **latent**, not live. PLAUSIBLE. But
`RemoteVaultService.list` is public and the dispatcher advertises independent
enforcement, so a future daemon-backed bulk read would leak `requiresApproval`/
`strict` plaintext to an agent with no prompt. Recommended direction: in the
`.list` agent branch, also drop `requiresApprovalForAgents` secrets (mirror the
`bulkRevealSecrets` exclusion), so the daemon is actually a chokepoint.

---

**M3 — A Touch ID approval prompt blocks the daemon's single serial dispatch
queue, stalling all clients and tripping the liveness/launch path.**
`Sources/LokaliteCore/VaultSocket.swift:137` (`dispatchQueue.sync { … handle }`),
`Sources/LokaliteApp/AgentApprovalCoordinator.swift:46-52` (`semaphore.wait()`).

All requests serialize on `dispatchQueue`; an approval-tier `.get` runs the
blocking Touch ID prompt *inside* that serial section. While the user deliberates,
every other client's request (any project/list/get) is queued. A concurrently
launching CLI/MCP does `VaultDaemonLauncher.ensureRunning`, whose liveness ping is
`.listProjects` with a 6 s deadline (`VaultDaemonLauncher.ensureRunning`,
`isAnswering`) — if the prompt outlives 6 s it concludes the daemon is down and
re-`open`s the app. CONFIRMED by reading. Impact: availability/UX under
concurrent use; spurious app relaunches. Recommended direction: run the approval
prompt outside the serial vault lock (resolve the secret, then broker consent
without holding `dispatchQueue`), or use a dedicated per-request queue so consent
does not head-of-line-block unrelated reads.

---

**M4 — Enforcement of the `blocked` tier still rides on best-effort agent
detection (pid tree walk), and peer identity is resolved post-accept (pid
reuse).**
`Sources/LokaliteCore/AgentDetection.swift:40` (name/path substring match over a
≤20-hop tree walk), `Sources/LokaliteCore/VaultSocket.swift:124-129` (peer PID
and signature resolved in `serve`, after `accept`).

ADR 0018 deliberately makes the *approval* tiers caller-independent to avoid
relying on detection — good — but the `blocked` tier and the `--local`
reference/`ensureNotAgentExfil` refusals are gated on `AgentDetection`, a
fixed substring list (`claude/cursor/windsurf/codex/copilot/aider/goose`). An
agent whose process name is not on the list, or that launders itself under a
generic parent (a shell, `make`, `xargs`), evades the block; a renamed binary
defeats it outright. Peer PID/signature are attribution-only (lower risk) but are
read after accept, so a reused pid could mislabel the audit entry. CONFIRMED
design limitation. Recommended direction: treat detection as advisory (as ADR
0018 does for approval) and lean on explicit per-secret policy for anything that
must actually be blocked; document that `blocked` is a courtesy guard, not a
control.

---

**M5 — Secret names are not shell-escaped in the MCP handoff / `shell` / app
export lines; a crafted name injects into the script the consumer `source`s.**
`Sources/lokalite/MCP/MCPSecretHandoff.swift:35` (`"export \($0.name)='…'"` —
only the *value* is escaped, `escape()` at `:68`), same pattern in
`ShellCommand.swift:40` and `EnvFileFormat.line` (`:2`, name interpolated raw).

A secret named e.g. `X'; rm -rf ~ #` or one containing a newline breaks out of
the `export NAME='…'` construct when the handoff/shell output is `source`d/`eval`d.
Names come from whoever added the secret; with `--read-write` an **agent** can
`add_secret` an arbitrary name and then `get_secret` it, injecting into the shell
it sources (self-directed, low), but a malicious/committed name also harms any
human who `eval $(lokalite shell)`. No name validation exists on `add`/`set`.
PLAUSIBLE→CONFIRMED (mechanics traced; impact depends on consumer). Recommended
direction: validate secret names against `[A-Za-z_][A-Za-z0-9_]*` on write, and/or
emit assignments via a form that cannot be reinterpreted (printf-quoted name).

---

### LOW

---

**L1 — `lokalite list` decrypts every secret value just to print names.**
`Sources/lokalite/Commands/ListCommand.swift:22` (`workspace.list`) — `list`
returns fully decrypted `Secret`s; the command uses only `.name`/`.description`.
No leak (only names printed), but it needlessly materializes all plaintext in the
CLI process and does N decrypts. Use `listInfo` (metadata only). CONFIRMED.

---

**L2 — `Vault.add` silently drops `description`/`icon`/`category` when the secret
already exists in another environment, and returns a `Secret` whose `category`
was never persisted.**
`Sources/LokaliteCore/Vault.swift:229-248`. When a same-named secret exists in a
different environment, the existing `SecretRecord` is reused as-is (metadata args
ignored) but the returned `Secret` reports the freshly `infer`-ed category
(`:225`, `:248`), which disagrees with the stored row. Minor correctness/label
incoherence; affects `add --description` on an existing multi-env secret and the
value returned to callers. Recommended: either update metadata on the reuse path
or document that add-in-new-environment is value-only, and return the persisted
category.

---

**L3 — MCP handoff plaintext lingers up to 120 s if never sourced.**
`Sources/lokalite/MCP/MCPSecretHandoff.swift:14` (`ttl = 120`), swept lazily on
the *next* `write`. A `0600` file in a `0700` dir under `NSTemporaryDirectory`
holds the value until the agent sources it (self-deletes) or the TTL sweep runs
on the next handoff. Same-UID exposure window only; acceptable but worth a shorter
TTL or an eager timer. CONFIRMED.

---

**L4 — `copy` clipboard auto-clear relies on a detached `/bin/sh` that polls for
30 s.**
`Sources/lokalite/Commands/CopyCommand.swift:45-56`. The digest (not the value)
is embedded, so no value leaks via the process list — good. But a short-lived CLI
spawns a lingering `sleep 30` subprocess per copy; if the CLI is scripted in a
loop, these accumulate. Minor. The app's own `ClipboardController` uses an
in-process `Task.sleep` and is cleaner.

---

**L5 — Migration numbering skips `v2`; `active_environment`/first-project seeding
is implicit.** `VaultStoreMigrations.swift:8,72` register `v1` then `v3`.
Harmless (GRDB keys migrations by string), but confusing; a reader may assume a
lost migration. Cosmetic.

---

### Documentation / release

**D1 — Release docs are accurate; two sharp edges already flagged in
`AGENTS.md` are real.** `scripts/release.sh` checks only `HEAD..origin/main`
(behind), never ahead (`:27`), and pushes only the tag (`:51`) — matches the
AGENTS.md warning. `release.yml` derives cask/appcast SHAs post-upload with
retries and gates signing/notarization on secret presence (`:37`, `:76`, `:264`),
matching the doc. `SUPublicEDKey` in `release.yml:144` is the hardcoded Sparkle
pubkey per docs. No drift found. One nit: `release.yml` commits Formula/Cask
unconditionally but appends the appcast item only when `SPARKLE_ED_PRIVATE_KEY`
is set (`:350`, `:382`) — so a release without the key ships a Homebrew bump with
no matching auto-update item, as documented.

**D2 — `.harness/adr/*` and `.harness/qa/report.md` are age-encrypted** and were
not readable in this environment, so ADR-vs-code drift beyond `AGENTS.md` is an
open question (see below). Developer-experience baseline is fine: `swift build`,
`swift test`, `make run/build/test/install` all match `Package.swift` and CI
(`ci.yml` runs `swift build` + `swift test`).

---

## 3. Design tensions

1. **Where is the real trust boundary — Touch ID, or the unlocked UID session?**
   The app invests in Touch ID unlock, a lock button, and a session timeout, yet
   the daemon `.unlock` path (H1) and the in-process CLI (M1) both obtain the key
   with neither biometric nor app-unlock. Either commit to "unlocked session =
   trusted" (and demote the Touch ID/lock UI to convenience, stop marketing it as
   protection) or make the daemon refuse value requests until the app is
   UI-unlocked and back the key with a presence-guarded Keychain ACL. Today the
   two stories coexist and mislead.

2. **Read-only governance vs. an agent that can write.** `AgentAccessPolicy`
   models reads exhaustively (allowed/blocked/approval/strict) but writes are
   ungoverned (H3). An adversarial agent doesn't need to *read* a `strict` secret
   to do damage — overwriting or deleting it is unguarded. A coherent model gates
   the *governed* secret on both axes.

3. **Detection-gated blocking inside a "detection-free enforcement" design.**
   ADR 0018's insight — don't let enforcement ride detection — is applied to the
   approval tiers but not to `blocked` or the CLI exfil refusals (M4). The result
   is a two-tier promise: approval is robust, `blocked` is best-effort, and
   nothing in the UI communicates that difference to the user choosing a tier.

4. **Two doors to the same value with opposite context guarantees.** MCP's
   handoff is carefully context-free, but `lokalite get` (H2) prints to stdout.
   The same agent can pick either door. A guarantee that one door upholds and the
   adjacent door breaks is not a guarantee. The tiers should behave identically
   across the MCP and CLI reveal surfaces.

5. **Serial vault queue vs. human-latency consent.** Consent is inherently
   slow (a person deciding) but is executed inside the daemon's serial critical
   section (M3). Blocking shared throughput on human latency guarantees
   head-of-line stalls and forces the liveness timeout to be generous. Consent
   should be brokered off the vault lock.

---

## 4. Expectation gaps ("I expected X, found Y")

- I expected the vault to be unreadable until Touch ID; I found any same-UID
  process can `.unlock` the daemon and read default-tier secrets with no
  biometric (H1).
- I expected "CLI never holds the key" (ADR 0014); I found `list`/`get`/`shell`/
  `export`/`run`/`backup`/`restore` load the key straight into the CLI (M1).
- I expected the MCP "value never enters agent context" principle to hold for
  agents; I found `lokalite get` prints default-tier values to stdout (H2).
- I expected `blocked`/`strict` to protect a secret end-to-end; I found writes
  (set/delete) ignore the policy entirely (H3).
- I expected the daemon to "enforce agent policy independently (defense in
  depth)" for bulk reads; I found `.list` only filters `blocked`, not the
  approval tiers (M2).
- I expected `blocked` to be a hard control; I found it rides a substring-based
  process-name list that a renamed/laundered agent evades (M4).
- I expected secret names to be validated; I found unescaped names interpolated
  into sourced/eval'd shell (M5) and no `[A-Za-z_]` check on write.
- I expected `list` to be cheap; I found it decrypts every value to print names
  (L1).

## 5. Open questions

1. Is "unlocked same-UID session = fully trusted" the intended threat model? If
   yes, H1/M1 are acceptable but the Touch ID/lock/timeout UI should be reframed;
   if no, they are bypasses. This is the single most important thing to confirm.
2. Do the encrypted ADRs (0003 unlock-model, 0014 daemon-broker, 0018) actually
   specify daemon-side re-authentication, or only UI-side? Could not read them
   (age-encrypted). If they claim the daemon requires an unlocked app, the code
   diverges (H1).
3. Is agent write access (`--read-write`) meant to bypass `blocked`/`strict`
   (H3), or was read-only governance an oversight when write tools were added?
4. Should `lokalite get`/`copy` be considered agent-reveal surfaces (H2), or is
   the intent that agents must use `run`/MCP and `get` is "human-only by
   convention"? If the latter, nothing enforces it.
5. Is anyone expected to reach the daemon `.list` path as an agent in the future
   (M2)? If bulk agent reads are on the roadmap, the exclusion must land first.
