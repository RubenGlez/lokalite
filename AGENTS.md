# Lokalite — agent notes

## Release

1. Pre-flight: clean tree on `main`, `swift test` green, QA report shows no open issues.
2. Prepend the new entry to `CHANGELOG.md` and commit it (the release script refuses a dirty tree). The link-reference list at the bottom is stale; recent releases don't add to it.
3. Push the release commits to `main` (`git push origin main`). The release script only pushes the tag, not the branch — and its safety check only catches being *behind* `origin/main`, not *ahead* — so unpushed local commits would otherwise live only under the tag.
4. `scripts/release.sh [patch|minor|major]` — computes the next tag from the latest `v*` tag, tags, and pushes the tag.
5. The tag triggers `.github/workflows/release.yml`: builds the app with xcodebuild, embeds + signs Sparkle.framework, creates DMG/PKG/ZIP + `SHA256SUMS`, publishes the GitHub Release, and pushes a `homebrew/vX.Y.Z` branch updating `Formula/lokalite.rb`, `Casks/lokalite-app.rb`, and `appcast.xml` (the signed Sparkle item for this version, prepended after the `<!-- BEGIN ITEMS -->` marker).
6. Homebrew + appcast merge together in one PR off the `homebrew/vX.Y.Z` branch. When `HOMEBREW_PR_TOKEN` is set, the workflow opens that PR and enables auto-merge (squash), so it merges itself once the branch's `build-and-test` status passes — no manual step. If the token is unset, the workflow only pushes the branch; open and merge the PR manually. Until it merges, `brew` users get the previous version **and** the Sparkle feed (served from `appcast.xml` on `main` via raw.githubusercontent) still advertises the previous version.
7. Record the release in the roadmap (Shipped section, version + date).

### In-app updates (Sparkle)

The app self-updates via [Sparkle](https://sparkle-project.org): a menu-bar "Check for Updates…" item (right-click the status icon, or Settings → Updates) plus automatic background checks after the user opts in on first launch. The updater only runs in signed release builds — `SoftwareUpdater` returns an inert controller in dev builds (no `SUFeedURL`, no embedded framework), so `swift run`/Xcode debugging never hits the release feed.

`SUFeedURL` points at `appcast.xml` on `main` served over raw.githubusercontent, so the feed advances only when the release PR (step 6) merges — same cadence as the cask. `SUPublicEDKey` is hardcoded in the Info.plist the workflow generates; the matching EdDSA private key signs each DMG via Sparkle's `sign_update` (key from `.build/artifacts` after `swift build`). The key pair is the account-wide Sparkle signing key (`generate_keys`, stored in the login Keychain); if the appcast ever needs re-signing locally, `sign_update` reads that key automatically.

### Signing & notarization

The release workflow signs with Developer ID + hardened runtime and notarizes when these repo secrets are set; if any are missing it falls back to the old ad-hoc-signed, un-notarized artifacts (users then need `xattr -cr`). These are the account-wide Developer ID identity (Team `67S22M7P3P`), reused across projects — the same cert/key that signs any of the account's apps. Repo secrets (names match the vault's `Global` project):

- `MACOS_SIGN_P12` / `MACOS_SIGN_PASSWORD` — Developer ID **Application** cert+key as a base64 `.p12`, and its export password. Signs the app bundle, its nested `.bundle` resources, and the CLI binary.
- `MACOS_NOTARY_KEY` / `MACOS_NOTARY_KEY_ID` / `MACOS_NOTARY_ISSUER_ID` — App Store Connect API key (base64 `.p8`, Key ID, Issuer ID) for `notarytool`. Notarization runs only when both the app cert and this key are present.
- `MACOS_SIGN_INSTALLER_P12` / `MACOS_SIGN_INSTALLER_PASSWORD` — Developer ID **Installer** cert+key (base64 `.p12`) + export password, for `productsign`ing the CLI `.pkg`. **Set (2026-07-03):** an Installer cert was issued (Team `67S22M7P3P`, G2, exp 2031-07-04); the `.p12` bundles leaf + private key + Apple G2 intermediate so the chain validates in CI (`find-identity -v` finds it once the signing keychain is in the search list). The pkg now `productsign`s + notarizes on release. Copies in the vault's `Global` project.
- `SPARKLE_ED_PRIVATE_KEY` — base64 EdDSA private seed (from `generate_keys -x`) that signs each DMG for the Sparkle appcast. Its public half is the hardcoded `SUPublicEDKey` in `release.yml`. If unset, the release still ships but the appcast item is skipped (no auto-update for that version). **Not** account-wide — it is Lokalite's own Sparkle key; keep a copy in the vault's `Global` project.
- `HOMEBREW_PR_TOKEN` — PAT (repo scope) used to open and auto-merge the Homebrew/appcast PR. If unset, the workflow only pushes the `homebrew/vX.Y.Z` branch.

The workflow maps these to descriptive internal job-env names; the signing identity itself is discovered from the imported cert at build time (no identity name is hardcoded). `LokaliteApp.entitlements` is intentionally empty — the app is not sandboxed (Carbon hotkey + Unix socket) and needs no special entitlement under the hardened runtime. Canonical copies of these credentials live in the `lokalite` vault's `Global` project; GitHub Actions secrets are the CI mirror.

<!-- doctier:begin -->
## Project context

Managed by doctier — do not edit between the markers.

Read these for project context:

- `.harness/adr/0001-storage-encryption.md`
- `.harness/adr/0002-cli-runtime.md`
- `.harness/adr/0003-unlock-model.md`
- `.harness/adr/0004-vault-sharing.md`
- `.harness/adr/0005-first-platform.md`
- `.harness/adr/0006-cli-scope.md`
- `.harness/adr/0007-cli-output-model.md`
- `.harness/adr/0008-agent-integration.md`
- `.harness/adr/0009-menu-bar-ux.md`
- `.harness/adr/0010-export-format.md`
- `.harness/adr/0011-distribution.md`
- `.harness/adr/0012-env-import-create-project.md`
- `.harness/adr/0013-mcp-inject-first-tool-surface.md`
- `.harness/adr/0014-daemon-broker-vault-access.md`
- `.harness/adr/0015-cli-local-process-boundary.md`
- `.harness/adr/0016-agent-environment-switching.md`
- `.harness/adr/0017-secret-references.md`
- `.harness/adr/0018-enforcement-never-rides-detection.md`
- `.harness/adr/0019-code-signature-peer-verification.md`
- `.harness/engineering/architecture.md`
- `.harness/engineering/features/access-dashboard.md`
- `.harness/engineering/features/caller-independent-approval.md`
- `.harness/engineering/features/client-agent-context.md`
- `.harness/engineering/features/env-import.md`
- `.harness/engineering/features/peer-code-signature-verification.md`
- `.harness/engineering/features/per-call-approval.md`
- `.harness/engineering/features/per-environment-agent-workflow.md`
- `.harness/engineering/features/popover-refactor.md`
- `.harness/engineering/features/requires-approval-tier.md`
- `.harness/engineering/features/secret-references.md`
- `.harness/engineering/implementation-plan.md`
- `.harness/product/CONTEXT.md`
- `.harness/product/competitors.md`
- `.harness/product/product.md`
- `.harness/product/roadmap.md`
- `.harness/product/ux.md`
- `.harness/qa/broker-qa-cowork.md`
- `.harness/qa/broker-qa-self.md`
- `.harness/qa/peer-verification-qa.md`
- `.harness/qa/report.md`
<!-- doctier:end -->
