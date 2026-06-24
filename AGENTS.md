# Lokalite — agent notes

## Release

1. Pre-flight: clean tree on `main`, `swift test` green, `.harness/qa/report.md` has no open issues.
2. Prepend the new entry to `CHANGELOG.md` and commit it (the release script refuses a dirty tree). The link-reference list at the bottom is stale; recent releases don't add to it.
3. Push the release commits to `main` (`git push origin main`). The release script only pushes the tag, not the branch — and its safety check only catches being *behind* `origin/main`, not *ahead* — so unpushed local commits would otherwise live only under the tag.
4. `scripts/release.sh [patch|minor|major]` — computes the next tag from the latest `v*` tag, tags, and pushes the tag.
5. The tag triggers `.github/workflows/release.yml`: builds the app with xcodebuild, creates DMG/PKG/ZIP + `SHA256SUMS`, publishes the GitHub Release, and pushes a `homebrew/vX.Y.Z` branch updating `Formula/lokalite.rb` and `Casks/lokalite.rb`.
6. `HOMEBREW_PR_TOKEN` is not configured in repo secrets, so the workflow does NOT open the Homebrew PR — create it manually from the `homebrew/vX.Y.Z` branch, wait for the `build-and-test` status, and merge it. Until that PR merges, `brew` users keep getting the previous version.
7. Record the release in `.harness/product/roadmap.md` (Shipped section, version + date).
