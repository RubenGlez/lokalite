# Roadmap

---

## v1.1 — Quick wins

- **Remove free-form tags** — drop `--tag`/`--tags` from CLI, keep categories
- **Dark mode toggle** — remove forced dark, add System / Light / Dark picker in Settings
- **`lokalite status`** — active project, env, lock state, secret count, vault path, MCP registration status, unlinked directory warning; `--json` flag
- **`lokalite init`** — creates a project named after the current directory, prints 3 next steps

## v1.2 — Developer workflow

- **`lokalite import <file>`** — parse `.env`, skip existing by default, `--overwrite` flag, standard project/env resolution
- **`lokalite export --format env`** — stdout by default, `--output` for file
- **`lokalite shell`** — pure `export KEY=value` lines, `--keys`/`--project`/`--env` flags, documented security tradeoff
- **`lokalite project link` default** — infers current directory name when no argument given

## v1.3 — App experience

- **Recents in popover** — last 5 copied secrets, persisted in UserDefaults
- **Global keyboard shortcut** — toggle popover, configurable in Settings, default `⌘⇧Space`
- **Project linking in UI** — linked path field in project edit sheet
- **App onboarding** — full empty-state view with single "Create your first project" CTA

---

## Backlog

- Secret references (`lokalite://KEY_NAME` in config files)
- Cross-platform support (Windows, Linux)
