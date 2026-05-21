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

## Agent & MCP Integration

Provide a standard way for:

* Claude Code
* Codex
* MCP Servers
* Local agents
* Development tools

to consume secrets from Lokalite. This could become one of the project's most unique differentiators.

---

## Cross-platform Support

Extend beyond macOS:

* Windows: Credential Manager / DPAPI
* Linux: Secret Service / libsecret
* Portable mode: master password + Argon2id
