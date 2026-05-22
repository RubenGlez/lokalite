# Roadmap

Items beyond MVP, ordered roughly by priority.

---

## Environment Profiles ✓

Per-project environments (e.g. dev, staging, production). Each secret can carry a separate value per environment; the Default value serves as a fallback. Managed from the secrets manager window.

---

## Command Injection

Run applications with secrets automatically injected, without storing credentials in shell profiles or `.env` files.

```bash
lokalite run claude
lokalite run npm start
```

---

## Project Linking ✓

Secrets are organized under named projects, each an isolated namespace in the vault. Create, switch, and delete projects from the left sidebar in the secrets manager.

---

## Secret References

Allow applications to resolve secrets dynamically.

```json
{
  "apiKey": "lokalite://OPENAI_API_KEY"
}
```

---

## Agent & MCP Integration ✓

MCP stdio server (`lokalite mcp`) exposes `get_secret` and `list_secrets` by default. Write tools (`add_secret`, `set_secret`, `delete_secret`) are opt-in via `--read-write`. `lokalite install` registers the server in `~/.claude.json` automatically. Compatible with Claude Code, Codex, Cursor, Windsurf, and any MCP client.

---

## Cross-platform Support

Extend beyond macOS:

* Windows: Credential Manager / DPAPI
* Linux: Secret Service / libsecret
* Portable mode: master password + Argon2id
