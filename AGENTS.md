# Lokalite — agent notes

## Release

1. Pre-flight: clean tree on `main`, `swift test` green, QA report shows no open issues.
2. Prepend the new entry to `CHANGELOG.md` and commit it (the release script refuses a dirty tree). The link-reference list at the bottom is stale; recent releases don't add to it.
3. Push the release commits to `main` (`git push origin main`). The release script only pushes the tag, not the branch — and its safety check only catches being *behind* `origin/main`, not *ahead* — so unpushed local commits would otherwise live only under the tag.
4. `scripts/release.sh [patch|minor|major]` — computes the next tag from the latest `v*` tag, tags, and pushes the tag.
5. The tag triggers `.github/workflows/release.yml`: builds the app with xcodebuild, creates DMG/PKG/ZIP + `SHA256SUMS`, publishes the GitHub Release, and pushes a `homebrew/vX.Y.Z` branch updating `Formula/lokalite.rb` and `Casks/lokalite-app.rb`.
6. `HOMEBREW_PR_TOKEN` is not configured in repo secrets, so the workflow does NOT open the Homebrew PR — create it manually from the `homebrew/vX.Y.Z` branch, wait for the `build-and-test` status, and merge it. Until that PR merges, `brew` users keep getting the previous version.
7. Record the release in the roadmap (Shipped section, version + date).

### Signing & notarization

The release workflow signs with Developer ID + hardened runtime and notarizes when these repo secrets are set; if any are missing it falls back to the old ad-hoc-signed, un-notarized artifacts (users then need `xattr -cr`). These are the account-wide Developer ID identity (Team `67S22M7P3P`), reused across projects — the same cert/key that signs any of the account's apps. Repo secrets (names match the vault's `Global` project):

- `MACOS_SIGN_P12` / `MACOS_SIGN_PASSWORD` — Developer ID **Application** cert+key as a base64 `.p12`, and its export password. Signs the app bundle, its nested `.bundle` resources, and the CLI binary.
- `MACOS_NOTARY_KEY` / `MACOS_NOTARY_KEY_ID` / `MACOS_NOTARY_ISSUER_ID` — App Store Connect API key (base64 `.p8`, Key ID, Issuer ID) for `notarytool`. Notarization runs only when both the app cert and this key are present.
- `MACOS_SIGN_INSTALLER_P12` / `MACOS_SIGN_INSTALLER_PASSWORD` — Developer ID **Installer** cert for signing the `.pkg`. Not currently set (no Installer cert exists), so the CLI pkg ships unsigned; everything else still signs and notarizes.

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
- `.harness/engineering/architecture.md`
- `.harness/engineering/features/access-dashboard.md`
- `.harness/engineering/features/caller-independent-approval.md`
- `.harness/engineering/features/client-agent-context.md`
- `.harness/engineering/features/env-import.md`
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
- `.harness/qa/report.md`
<!-- doctier:end -->
