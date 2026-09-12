# Lokalite — agent notes

## Release runbook

1. Pre-flight: clean tree on `main`, `swift test` green, QA report with no open issues. Prepend the `CHANGELOG.md` entry and commit it (the release script refuses a dirty tree; the link-reference list at the bottom of the changelog is stale, skip it).
2. **Push `main` before releasing.** `scripts/release.sh [patch|minor|major]` only pushes the tag, and its safety check only catches being *behind* `origin/main`, not *ahead* — unpushed local commits would otherwise exist only under the tag.
3. The tag triggers `.github/workflows/release.yml`: xcodebuild build, Sparkle framework embed/sign, DMG/PKG/ZIP + `SHA256SUMS`, GitHub Release, and a `homebrew/vX.Y.Z` branch updating `Formula/`, `Casks/`, and `appcast.xml` (new Sparkle item after `<!-- BEGIN ITEMS -->`).
4. Homebrew + appcast merge together in one PR off that branch. With `HOMEBREW_PR_TOKEN` set, the workflow opens it and auto-merges (squash) once `build-and-test` passes; if unset, open and merge manually. Until it merges, `brew` users get the previous version and the Sparkle feed (served from `appcast.xml` on `main` via raw.githubusercontent) still advertises the previous version.
5. Record the release in the roadmap (Shipped section, version + date).

## Non-obvious constraints

- Sparkle updater is inert in dev builds (no `SUFeedURL`, no embedded framework), so `swift run`/Xcode debugging never hits the release feed.
- `SUPublicEDKey` is hardcoded in the Info.plist the workflow generates; the matching EdDSA private key is the account-wide Sparkle key (login Keychain, via `generate_keys`), so `sign_update` reads it automatically for any local appcast re-signing.
- Signing identity is discovered from the imported cert at build time (no name hardcoded). `LokaliteApp.entitlements` is intentionally empty: not sandboxed (Carbon hotkey + Unix socket), no entitlement needed under hardened runtime.
- If signing/notarization secrets are missing, the workflow falls back to ad-hoc, un-notarized artifacts (users then need `xattr -cr`).

## Signing & notarization secrets (Team `67S22M7P3P`, account-wide Developer ID)

Canonical copies live in the `lokalite` vault's `Global` project; GitHub Actions secrets are the CI mirror (names match vault). Notarization runs only when both the app cert and the App Store Connect key are present.

- `MACOS_SIGN_P12`/`..._PASSWORD` — Developer ID **Application** cert (signs app bundle, nested `.bundle` resources, CLI binary).
- `MACOS_NOTARY_KEY`/`..._KEY_ID`/`..._ISSUER_ID` — App Store Connect API key (base64 `.p8`) for `notarytool`.
- `MACOS_SIGN_INSTALLER_P12`/`..._PASSWORD` — Developer ID **Installer** cert for `productsign`ing the CLI `.pkg` (issued 2026-07-03, exp 2031-07-04; the `.p12` bundles leaf + key + Apple G2 intermediate so the chain validates in CI).
- `SPARKLE_ED_PRIVATE_KEY` — base64 EdDSA seed signing each DMG for the appcast. **Not** account-wide (Lokalite's own); if unset, the release ships but that version has no appcast item/auto-update.
- `HOMEBREW_PR_TOKEN` — PAT (repo scope) enabling the auto-merged Homebrew PR; see runbook step 4.

<!-- doctier:begin -->
## Project context

Managed by doctier — do not edit between the markers.

Entry points (read these first):

- `.harness/engineering/architecture.md`
- `.harness/engineering/implementation-plan.md`
- `.harness/product/product.md`

Further docs, by directory:

- `.harness/adr/` (25 docs)
- `.harness/engineering/` (1 docs)
- `.harness/engineering/features/` (15 docs)
- `.harness/product/` (4 docs)
- `.harness/qa/` (5 docs)
<!-- doctier:end -->
