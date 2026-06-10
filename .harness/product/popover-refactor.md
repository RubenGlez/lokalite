# Popover Refactor — Quick-Actions Launcher

Status: planned. Refines [ADR 0009](../adr/0009-menu-bar-ux.md) (search-first popover, click to copy) — the skeleton stays, the tuning changes.

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

## Open decision

The popover's environment switcher only changes the GUI viewing scope (`VaultViewModel.selectEnvironment` does not persist `activeEnvironment`), while the CLI keeps its own persistent active-environment marker. A user switching to "staging" in the popover may believe `lokalite run` now uses staging. Either the switcher should set the real active environment (and the dot becomes state), or it should be visually framed as a filter. Decide before Batch 2; if it becomes state-setting, record it as an ADR.
