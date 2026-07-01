# Lokalite — Roadmap & Competitive Positioning

_Last updated: 2026-07-01_

## Value proposition

**The local-first secrets manager for developer teams working with AI agents —
on every OS (macOS, Linux, Windows), organized by project and environment.**

Lokalite keeps API keys, tokens, and credentials in an encrypted vault on your
machine and hands them to AI agents through a one-time shell handoff, never into
the chat or the model's context. Every access is logged and governed per secret.

The two axes we own — **cross-platform** and **per-environment values** — are
exactly what our closest competitor cannot follow (see below).

## Competitive landscape

Our closest competitor is **NoxKey** (noxkey.ai / No-Box-Dev). It targets the
same niche almost exactly: a local-first macOS secrets manager with Touch ID, an
MCP server, an encrypted agent handoff, and a CLI. It matches or exceeds us on
most day-one features, so our differentiation is narrower than it looks and
depends on the two structural advantages below.

### Feature comparison (Lokalite vs NoxKey)

| Capability | Lokalite | NoxKey |
|---|---|---|
| CLI | ✅ | ✅ (`get/import/export/rotate/guard/audit/...`) |
| Menu bar app + Touch ID | ✅ | ✅ |
| Agent handoff (value stays out of model context) | ✅ | ✅ |
| Per-secret agent policy | ✅ `block`/`approve`/`allow` | ✅ `easy`/`normal`/`strict`/`off_limits` + per-request approval card |
| `.env` import/export | ✅ | ✅ + on-disk `.env` scan |
| Activity/audit log | ✅ agent-attributed dashboard | ✅ `noxkey audit` |
| Shell injection / session cache | ✅ | ✅ |
| Hierarchical organization | Projects | `org/project/KEY` + `shared/KEY` |
| **Per-environment values** (dev/staging/prod) | ✅ | ❌ not offered |
| **DLP output guard** (redact leaked values) | ✅ `lokalite guard` | ✅ `noxkey guard` |
| **Guided secret rotation** | ✅ `lokalite rotate` | ✅ `noxkey rotate` |
| **E2E secret sharing** | ✅ `lokalite share` (`.lok`) | ✅ `.noxkey` one-time files |
| **Developer ID signed / App Store** | ❌ (P0) | ✅ on the Mac App Store |
| **Cross-platform (Windows/Linux)** | 🟡 possible by design | ❌ architecturally blocked |

> Sourced from NoxKey's public GitHub, the NoBoxDev blog, and the Mac App Store
> listing. Items marked "not offered" / "not documented" should be re-verified
> hands-on before being cited publicly.

### Where our advantage is real

1. **Per-environment values.** NoxKey organizes secrets by `org/project/KEY`
   namespaces but has no concept of parallel environments (dev/staging/prod)
   with different values per environment — a core team dev workflow.

2. **Cross-platform is open to us and closed to NoxKey.** NoxKey's own docs
   state it is macOS-only *because its security model stores secrets directly in
   the macOS Keychain / Secure Enclave*, "which do not exist on Linux or
   Windows." Lokalite instead keeps its **own** encrypted vault (`vault.db`,
   AES-256-GCM) and stores only the *key* in the Keychain — so porting to
   Windows/Linux is a matter of swapping the key store (DPAPI / libsecret / TPM),
   not rewriting the model. This is our deepest moat: NoxKey would have to
   re-architect its core to follow us.

## Now — P0 (close the gaps that lose us deals)

- [ ] **Developer ID signing + notarization** (ideally Mac App Store).
      Requires an Apple Developer account, certificates, and CI secrets — a
      credentialed/manual step, tracked here but not code-only. Without it,
      Gatekeeper quarantines the app on first launch (`xattr -cr` workaround),
      which costs us trust and discoverability against an App Store competitor.
- [x] **DLP output guard** — `lokalite guard`: scan piped agent output for known
      secret values and redact them before they reach a model's context or a log.
      Reaches parity with `noxkey guard`.

## Next — P1 (feature parity)

- [x] **Guided secret rotation** (`lokalite rotate`) — supply or `--generate` a
      new value, with a reminder to revoke the old credential upstream.
- [x] **E2E secret sharing** (`lokalite share create` / `open`) — passphrase-
      encrypted `.lok` files (same envelope as encrypted backups) that import
      into the recipient's own vault; passphrase travels out of band.
- [ ] **Per-access `strict` tier** — Touch ID on every read (no session cache).
      App-side (needs the Touch ID broker), like notarization; not code-only.
- [ ] **Share hardening** — true single-use (burn-on-open) and app-side Touch ID
      import, to fully match NoxKey's `.noxkey` flow.

## Later — P2 (lean into the moat)

- [ ] **Linux/Windows support** — start with CLI + MCP (no app), key stored via
      the platform's native secret store. This is the differentiator NoxKey
      cannot match; begin early and market it.
- [ ] **Comparison page** positioning "cross-platform + per-environment".

## Shipped

See `CHANGELOG.md` for the full history. Recent highlights:

- **v2.1.0** (2026-07-01) — per-secret `requiresApproval` tier, agent-attributed
  access dashboard, per-environment agent workflow (`use_environment`), manager
  window in Cmd+Tab.
- **v2.0.0** (2026-06-30) — MCP `get_secret` no longer returns the value
  (one-time `source` handoff); app-brokered vault access; per-secret agent policy.
</content>
</invoke>
