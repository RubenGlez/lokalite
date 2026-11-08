# Lokalite

## What it is

Lokalite is an open-source desktop application and CLI for managing developer secrets locally. It provides a single encrypted workspace where developers can securely store and access everything they need to build software — API keys, SSH keys, certificates, OAuth credentials, database passwords, cloud provider credentials, agent configuration, MCP tokens, and environment variables.

Lokalite is intentionally local-first: no cloud, no account, no subscription, no telemetry, no vendor lock-in. Secrets remain on the user's machine, encrypted at rest and accessible through a modern desktop application and developer-friendly CLI.

## Audience

**Indie Developers** — managing multiple side projects and APIs.

**Open Source Maintainers** — handling tokens, deployment credentials, and service accounts.

**AI Engineers** — managing credentials for OpenAI, Anthropic, Gemini, Groq, OpenRouter, MCP servers, and local agents.

**Consultants and Freelancers** — working across multiple clients and environments.

## Positioning

Lokalite is a local-first secrets workspace for developers — not another password manager.

Existing solutions fall into three buckets: general-purpose password managers designed for consumers, enterprise secret management systems requiring infrastructure, and cloud-first products with subscriptions and vendor lock-in. Lokalite targets the gap: a simple, local-first secret workspace designed specifically for individual developers.

**Core principles:**
- **Local First** — all data lives on the user's machine; no external servers required.
- **Developer Focused** — built around software development workflows, not personal password management.
- **Open Source** — encryption model, storage format, and implementation are fully transparent.
- **Portable** — users own their data and can export it at any time.
- **Minimal** — not a replacement for enterprise vault solutions; scoped to individual developers.

**Non-goals** (intentionally out of scope):
- Family password manager
- Browser password autofill solution
- Enterprise secret management platform
- Team collaboration product
- Cloud synchronization service

## Direction Assessment

Lokalite is a shipped, working product at v2.1.0. The core differentiation — local-first, no account, native macOS, MCP-native — is fully implemented and the feature set is complete for the individual-developer audience. Distribution via Homebrew (formula + cask) and an automated release pipeline means new versions can ship in minutes.

The product is differentiated from the cloud and enterprise options. 1Password and Doppler require cloud accounts; HashiCorp Vault requires infrastructure; `.env` files are unencrypted and project-scoped. Lokalite occupies the local-first, encrypted, developer-tooling corner of this space. As of 2026 it is no longer the only entrant in that corner: NoxKey (No-Box-Dev) is a near-identical free, open-source macOS competitor with built-in MCP, per-secret auth tiers, an identical transcript-safe handoff, and an agent-attributed audit log. After the v2.0–v2.1 governance releases, Lokalite's verified remaining differentiation is the per-environment agent workflow (including the environment dimension in the access log); consent-on-read, the handoff, and access logging are parity — see `competitors.md` (landscape check + corrections 2026-07-02). The agent-security category itself was validated in 2026 by 1Password Unified Access, Infisical Agent Vault, and official MCP servers from Keeper, Bitwarden, and HashiCorp; the highest-leverage work now is discoverability, not features. Distribution's install-friction half was closed in v2.2.1 (Developer ID signing + notarization, so the app installs without `xattr -cr`); what remains is being *found* — main-tap Homebrew, an App Store presence, and marketing surface beyond the README.

The ergonomics gaps that were the highest-leverage work — CLI search, an access-log view, a guided backup/restore workflow, and MCP context auto-resolution — shipped in v1.6.0. The remaining backlog (multiple vaults, secret versioning) is about scaling to more separated workspaces rather than core functionality. The architecture can support all of these without structural changes.

The risk of feature creep into team collaboration or cloud sync is real and should be resisted. The product's identity depends on staying local-first and individual-focused.

## Key Risks

**Direct competition and commoditization.** NoxKey is a near-identical free, open-source macOS secrets manager — same audience, same `.env`-replacement wedge, built-in MCP, per-secret auth tiers (including per-call Touch ID, stricter than Lokalite's session-scoped approval), an identical transcript-safe handoff, an agent-attributed audit log, and signed Mac App Store distribution. The "local-first MCP-native secrets manager" niche is no longer uncontested, and larger players moved in during 2026: 1Password Unified Access plus Anthropic's first-party 1Password integration in Claude Code threatens to make "just use 1Password" the default for existing subscribers, and Infisical Agent Vault offers free open-source exfiltration containment for headless agents. Lokalite's verified edges (per-environment agent workflow, environment-aware always-on access log, portable vault) are real but narrow. Sustained differentiation, not just feature parity, is required.

**Discoverability (distribution's install-friction half is now solved).** As of v2.2.1 the app, DMG, and CLI binary are Developer-ID-signed and notarized, so the `xattr -cr` quarantine friction and its trust-signal problem are gone; v2.3.0 added a Developer ID Installer cert so the CLI `.pkg` is signed + notarized too. Install friction is fully solved, and the app now self-updates in place (Sparkle). What remains is discoverability: Lokalite is on a third-party Homebrew tap, not the main tap, so developers who search `brew install lokalite` still won't find it, and it isn't in the Mac App Store. NoxKey compounds this with an SEO content operation (product site, category-keyword blog posts, a "best macOS secrets managers" roundup that omits Lokalite); Lokalite's only marketing surface is the GitHub README, so even users who would prefer it never find it.

**Prompt-injection positioning risk.** The MCP handoff keeps values out of the transcript, but a prompt-injected agent can still source a secret and exfiltrate it from its own shell. Infisical's proxy architecture answers that gap directly (the agent never holds the credential), so "transcript-safe" will read as the weaker claim as injection incidents accumulate. Positioning must lean on detection, attribution, and consent — never implied exfil-proofness.

**macOS lock-in.** The entire stack — Keychain, CryptoKit, SwiftUI, Carbon hotkey API — is macOS-specific. Cross-platform support is a nice-to-have on the roadmap but would require a near-complete rewrite of the storage, crypto, and UI layers. Any developer who moves to Linux loses access to their vault. Encrypted export provides an escape hatch but not a migration path.

**Touch ID fatigue and session security tension.** The session-based unlock model is the right UX trade-off today, but a long session window (e.g. "until Mac locks") means secrets are effectively always accessible to anyone who sits at an unlocked machine. As the user base grows, this will generate support questions and security concerns. The session timeout UI and defaults will need iteration.

**Single-vault design.** One vault per machine with no sync means a developer who works across multiple Macs (desktop + laptop) has to manage two separate vaults manually. Encrypted export/import is the current answer, but it is a manual workflow with no conflict resolution. This will become a friction point for users who try to adopt Lokalite as their primary secrets store.
