# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.0] - 2026-06-25

### Changed
- Visual refresh: semantic colors per secret category, a unified environment model across the app, and a refreshed terminal-vault identity
- Importing a `.env` to create a project in the menu bar app now sets it as the active project, matching the CLI

### Fixed
- Use a valid SF Symbol for the Secret category icon

## [1.7.1] - 2026-06-24

### Fixed
- The Project Info card counted one more environment than the project actually has
- The menu bar popover now closes when you click "Open Lokalite"

## [1.7.0] - 2026-06-24

### Added
- `lokalite init --from-env <file>` creates a project from a `.env` file (or a folder containing one), linked to that directory, and imports its keys. An optional name and `--env <name>` set the project name and target environment; `--overwrite` replaces existing secrets
- The menu bar app can import a `.env` through a guided form (project name, target environment, linked directory, overwrite, and a key list you can prune), reachable from onboarding, the sidebar's new-project menu, and a per-project "Import from .env" action — for both creating a new project and importing into an existing one

## [1.6.0] - 2026-06-24

### Added
- `lokalite list --search <term>` filters secrets by name or description (case-insensitive substring), bringing the app's real-time search to the terminal
- `lokalite log` shows the secret access log with timestamps, source (app / cli / mcp), project, environment, and secret name; supports `--limit` and `--source`
- `lokalite backup` writes a passphrase-encrypted backup of a project's active environment, and `lokalite restore` decrypts and re-imports it (skips existing secrets by default, `--overwrite` to replace)
- The MCP server now auto-resolves the project from the caller's working directory (optional `path` argument, falling back to the server's working directory) via the project path link, so callers no longer need to pass a project name; an explicit `project` still wins

## [1.5.0] - 2026-06-11

### Added
- Popover quick-actions launcher: the full secret list is always available (last 5 under Recent, the rest under All), with a keyboard-driven copy flow — arrows to select, Return copies the value, modifier variants copy `KEY=value` or `export KEY=value`
- Copy a ready-to-paste `.env` for the current project and environment, using the same formatting as the CLI export
- Value peek: reveal a secret in the popover via the hover eye or Space while the search field is empty
- Lock action in the popover footer (cmd-L)

### Changed
- Menu bar icon is the armadillo head again, replacing the curled-shell mark
- Secret rows show the monospaced name as primary text with category and description as secondary
- Quit moved from the popover footer to the menu bar icon's right-click menu
- The copied confirmation flash now shows the configured clipboard auto-clear timeout

## [1.4.3] - 2026-06-10

### Fixed
- The appearance preference in Settings (System / Light / Dark) now actually works: the color palette adapts to light and dark mode instead of staying hardcoded dark, and switching modes applies instantly to the popover and settings window without a restart

### Removed
- "Lokalite CLI" installed-status indicator removed from the settings window sidebar

## [1.4.2] - 2026-06-10

### Fixed
- The packaged menu bar app crashed at launch because `swift build`'s resource accessor cannot find bundles in `Contents/Resources`; the app is now built with `xcodebuild`, whose accessor resolves them correctly (affected the v1.4.0 and v1.4.1 app artifacts; the CLI was unaffected)

## [1.4.1] - 2026-06-10

### Fixed
- Release app bundle now includes the SPM resource bundles; v1.4.0's packaged app shipped without them, so the menu bar icon failed to load and the symbol picker was missing its symbol lists

### Changed
- Refined menu bar icon claws to better match the brand mark

## [1.4.0] - 2026-06-10

### Changed
- New menu bar icon: a curled armadillo shell mark drawn for small sizes, rendered as a macOS template image so it adapts to light/dark menu bars

## [1.3.0] - 2026-06-10

### Security
- App unlock now fails closed when device authentication is unavailable instead of opening the vault without a prompt
- `lokalite copy` no longer places the secret value in the clipboard-clear helper's process arguments (compares a SHA-256 digest instead)
- `lokalite add` and `lokalite set` can read the value from a hidden prompt or stdin (omit the value or pass `-`), keeping secrets out of shell history
- Clipboard copies are marked with `org.nspasteboard.ConcealedType` so clipboard managers skip recording them
- Export salt generation now fails loudly if the system random generator reports an error
- Removed the keychain `.userPresence` access control flag, which macOS silently ignores in the file-based login keychain; user-presence checks remain at the app layer via LocalAuthentication
- Pinned the argon2 dependency to an exact revision instead of tracking `master`
- Release artifacts now ship with a `SHA256SUMS` checksum file

## [1.2.4] - 2026-06-06

### Fixed
- Homebrew install reliability improvements

## [1.2.3] - 2026-06-06

### Fixed
- Homebrew formula checksums corrected after CDN propagation delay

## [1.2.2] - 2026-06-06

### Fixed
- Homebrew formula now tracks the menu bar icon resource correctly

## [1.2.1] - 2026-06-04

### Changed
- Menu bar icon updated to a rounded-square L lettermark

## [1.2.0] - 2026-06-04

### Added
- Environment-specific secrets: each environment now stores its own values independently, with no automatic fallback to a default
- Environments can be deleted through the app UI
- Activity log: secret operations (get, copy, shell, run) are recorded and surfaced in the manager
- Repository row in project info panel detects and displays the git remote for the linked directory
- Popover footer now includes Quit Lokalite shortcut (⌘Q)

### Changed
- Full UI redesign: new sidebar layout, settings overhaul, environment color indicators standardized across the app
- Default environment is now a concrete row that can be selected and managed like any other environment
- Sidebar selection style updated for visual consistency

### Fixed
- Vault unlock state and settings panel placement
- Unlock concurrency warning resolved
- Recent secrets section no longer shows arbitrary secrets when no actual recents exist
- Secret count per environment now counts only values in that environment, not total project secrets
- Moving a secret to another project now fails early if the destination already has the secret

## [1.1.2] - 2026-05-26

### Fixed
- Sidebar list selection highlight no longer bleeds through in certain display modes

## [1.1.1] - 2026-05-26

### Changed
- Menu bar icon simplified to a thick ring with notches

## [1.1.0] - 2026-05-26

### Added
- `lokalite status`: shows active project, environment, secret count, vault path, and MCP registration status; accepts `--json` for scripting
- `lokalite init`: creates a project named after the current directory, sets it active, and prints next steps
- Color scheme picker in Settings (System / Light / Dark); preference is persisted across sessions

### Changed
- Tags removed from the CLI and UI; projects and environments are now the primary organization mechanism

### Fixed
- Three SwiftUI bugs: global hotkey manager memory leak, recent secrets list not re-rendering on copy, and a duplicate sheet conflict in settings

## [1.0.17] - 2026-05-26

### Fixed
- Release pipeline stability improvement

## [1.0.16] - 2026-05-26

### Fixed
- Release pipeline: replaced broken artifact upload action with `gh` CLI

## [1.0.15] - 2026-05-26

### Fixed
- Popover secret list layout polish
- Project icon no longer fails to refresh after an update

## [1.0.14] - 2026-05-26

### Fixed
- All app windows and surfaces now close when the vault locks

## [1.0.13] - 2026-05-26

### Changed
- App selection styling refinement in the manager sidebar

## [1.0.12] - 2026-05-26

### Changed
- Manager UI overhaul: native toolbar controls, SwiftUI modernisation, project/env switchers, copy action, error alerts, and search focus improvements
- Manager window stays alive after the manager is closed (app remains in menu bar)

## [1.0.11] - 2026-05-24

### Added
- Projects and environments: secrets are now scoped to a project and can have per-environment values
- `lokalite project` and `lokalite env` subcommands for managing projects and environments
- All existing commands (`get`, `set`, `add`, `delete`, `list`, `copy`, `run`, `export`) gain `--project` and `--env` flags
- MCP server updated: `get_secret` and `list_secrets` accept optional `project` and `environment` arguments; write tools (`add_secret`, `set_secret`, `delete_secret`) available behind `--read-write` flag
- `lokalite install`: copies the binary to PATH and registers the MCP server in `~/.claude.json`
- Context menus for secrets, environments, and projects in the manager UI
- Inline secret editing in the manager
- Redesigned settings UI
- Argon2id used for encrypted exports (replaces previous export encryption)
- `lokalite import <file>`: parses `.env` files, skips existing secrets by default; `--overwrite` to replace
- `lokalite shell`: outputs `export KEY='value'` lines for eval in bash/zsh; supports `--keys`, `--project`, `--env`
- `lokalite export --format env`: writes `KEY="value"` lines to stdout or `--output` file, no passphrase required
- Recent secrets section in the popover: last 5 copied secrets shown above the full list
- Global keyboard shortcut to open the popover (default ⌘⇧Space); configurable in Settings
- Project linking in the manager UI: directory picker and Unlink action in the project edit sheet
- Onboarding screen shown when the vault is unlocked but has no projects yet

### Changed
- `lokalite project link` name now defaults to the current directory name; path defaults to cwd
- `lokalite project link --unlink` removes the link without a separate command

## [1.0.10] - 2026-05-22

### Fixed
- Manager unlock state and settings panel placement corrected
- Unlock concurrency warning resolved

## [1.0.9] - 2026-05-22

### Fixed
- Release build for custom menu bar icon

## [1.0.8] - 2026-05-22

### Fixed
- Menu bar icon visibility on light backgrounds

## [1.0.7] - 2026-05-22

### Fixed
- Menu bar icon type-check error in release builds

## [1.0.6] - 2026-05-22

### Changed
- Menu bar icon replaced with a custom combination dial design

## [1.0.5] - 2026-05-22

### Changed
- DMG uses a styled drag-to-Applications layout

## [1.0.4] - 2026-05-22

### Added
- Launch at Login toggle in Settings
- Quit button in popover footer

## [1.0.3] - 2026-05-22

### Changed
- Vault locks automatically when the popover is dismissed; manual lock button removed

## [1.0.2] - 2026-05-22

### Fixed
- App bundle ad-hoc signed to resolve Gatekeeper "damaged app" error on first launch

## [1.0.1] - 2026-05-22

### Added
- App icon added to the release bundle

## [1.0.0] - 2026-05-22

### Added
- CLI (`lokalite`) with `add`, `get`, `set`, `delete`, `copy`, `list`, `export`, and `run` commands
- Menu bar app (`LokaliteApp`) with secret list, search, and copy-to-clipboard
- AES-256-GCM encryption via CryptoKit; vault key stored in Apple Keychain
- Touch ID authentication with configurable session timeout and clipboard auto-clear
- MCP stdio server (`lokalite mcp`) for Claude Code integration: exposes `get_secret` and `list_secrets`
- Distributed via Homebrew

[1.2.4]: https://github.com/RubenGlez/lokalite/releases/tag/v1.2.4
[1.2.3]: https://github.com/RubenGlez/lokalite/releases/tag/v1.2.3
[1.2.2]: https://github.com/RubenGlez/lokalite/releases/tag/v1.2.2
[1.2.1]: https://github.com/RubenGlez/lokalite/releases/tag/v1.2.1
[1.2.0]: https://github.com/RubenGlez/lokalite/releases/tag/v1.2.0
[1.1.2]: https://github.com/RubenGlez/lokalite/releases/tag/v1.1.2
[1.1.1]: https://github.com/RubenGlez/lokalite/releases/tag/v1.1.1
[1.1.0]: https://github.com/RubenGlez/lokalite/releases/tag/v1.1.0
[1.0.17]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.17
[1.0.16]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.16
[1.0.15]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.15
[1.0.14]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.14
[1.0.13]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.13
[1.0.12]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.12
[1.0.11]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.11
[1.0.10]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.10
[1.0.9]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.9
[1.0.8]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.8
[1.0.7]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.7
[1.0.6]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.6
[1.0.5]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.5
[1.0.4]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.4
[1.0.3]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.3
[1.0.2]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.2
[1.0.1]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.1
[1.0.0]: https://github.com/RubenGlez/lokalite/releases/tag/v1.0.0
