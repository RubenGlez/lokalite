# Roadmap

Items beyond MVP, ordered roughly by priority.

---

## Environment Profiles

Define reusable environments and activate them on demand.

```yaml
ai:
  OPENAI_API_KEY
  ANTHROPIC_API_KEY
  GEMINI_API_KEY

production:
  DATABASE_URL
  REDIS_URL
  JWT_SECRET
```

---

## Command Injection

Run applications with secrets automatically injected, without storing credentials in shell profiles or `.env` files.

```bash
lokalite run claude
lokalite run npm start
```

---

## Project Linking

Associate secrets with specific projects.

```text
samplebyte
 ├─ YOUTUBE_API_KEY
 ├─ SUPABASE_URL
 └─ SUPABASE_ANON_KEY
```

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
