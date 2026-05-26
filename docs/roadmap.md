# Roadmap

Items planned beyond the current release, ordered roughly by priority.

---

## Secret References

Allow applications to resolve secrets dynamically without running `lokalite run`.

```json
{
  "apiKey": "lokalite://OPENAI_API_KEY"
}
```

---

## Cross-platform Support

Extend beyond macOS:

* Windows: Credential Manager / DPAPI
* Linux: Secret Service / libsecret
* Portable mode: master password + Argon2id
