# Popover Refactor — Quick-Actions Launcher

Status: done. Refines [ADR 0009](../adr/0009-menu-bar-ux.md) (search-first popover, click to copy) — the skeleton stays, the tuning changes.

## Problem

The popover's job is to be the 3-second path for the actions a developer repeats all day. Today it behaves like a small browser of recents instead of a launcher:

- A project with secrets but no recents shows a large empty area under a "Recent" header — worst first impression for new users.
- Rows are mouse-only; there is no keyboard path from search to copy.
- Every row's primary line repeats the same "Project / Environment" text (the list is already scoped by the header), while the secret name — the thing being scanned for — is the muted subtitle.
- Copy only produces the raw value; devs usually need `KEY=value` or a whole `.env`.
- "Quit" occupies half the footer for a once-a-month action; there is no Lock action anywhere in the popover.

## Target action set

Everything in the popover must justify itself against this list; browsing/managing/editing stay in the main window.

1. Copy a secret value
2. Copy in dev formats (`KEY=value`, `export KEY=value`)
3. Copy a full `.env` for the current project + environment
4. Peek at a value without copying
5. Switch project / environment context
6. Add a secret quickly
7. Lock the vault

## Changes

### Batch 1 — low-risk fixes

- **Empty-recents fallback**: when the scope has secrets but no recents, show the full secret list (recents capped at ~5 on top, rest below under "All").
- **Row hierarchy**: secret name as the primary line (monospaced, matching the main window), category/description secondary. Drop the repeated "Project / Environment" line.
- **Footer**: add **Lock**; remove **Quit** (move to right-click menu on the menu bar icon, keep ⌘Q working).

### Batch 2 — launcher behavior

- **Keyboard flow end-to-end**: type → ↓/↑ selects → ⏎ copies and closes the popover. Highest-impact change overall.
- **Copy formats**: context menu and modifier keys (e.g. ⌥⏎) for `KEY=value`, `export KEY=value`, raw value.
- **Copy .env**: one-shot action for the current project + environment (reuses the CLI export path).

### Batch 3 — polish

- **Value peek**: eye icon on hover / Space to reveal inline; auto-hide when the popover closes.
- **Clipboard-clear feedback**: change the "Copied" flash to "Copied · clears in 30s" using the configured auto-clear timeout.

## Resolution

Decided 2026-06-11: the environment switcher stays a GUI-only viewing filter. `selectEnvironment` does not persist `activeEnvironment`; the switcher is framed as a filter (small filter glyph plus a "viewing filter" tooltip) rather than redesigned. No ADR needed.

## Implementation note

All three batches shipped together:

- Empty-recents fallback: full secret list under "All", recents (max 5) on top under "Recent"; list is scrollable.
- Row hierarchy inverted: secret name primary (monospaced 13), category/description secondary; "Project / Environment" line dropped.
- Footer: Lock (⌘L) and Copy .env added; Quit removed (now in the menu bar icon's right-click menu via an `NSEvent` monitor in `AppDelegate`; ⌘Q still works inside the popover through a hidden button).
- Keyboard flow: ↓/↑ move selection from the search field, ⏎ copies and closes the popover, ⌥⏎ copies `KEY="value"`, ⌃⏎ copies `export KEY="value"`.
- Copy formats: row context menu (Copy Value / as KEY=value / as export KEY=value) and ⌥/⌃-click variants; `VaultViewModel.copyToClipboard(_:format:)`.
- Copy .env: joins all secrets in the current scope using the shared `EnvFileFormat.line` helper in LokaliteCore (also used by the CLI `export --format env`); auto-clear applies.
- Value peek: eye icon on hover, Space toggles for the selected row when the search field is empty; reveal resets when the popover closes.
- Copied flash now reads "Copied · clears in Ns" from the configured auto-clear timeout.
