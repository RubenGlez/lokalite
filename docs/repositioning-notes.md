# Repositioning Notes

## Old Frame

Lokalite started as an open-source localization management platform for application translations.

That direction has value, but the category is crowded. Mature tools already cover translation management, file sync, review workflows, permissions, translation memory, machine translation, and integrations.

The old frame risks making Lokalite look like a small version of existing platforms.

## New Frame

Lokalite should focus on the parts of localization that are becoming more important because of AI agents:

- prompts
- tool descriptions
- tool calls
- structured outputs
- multilingual conversations
- agent traces
- safety behavior
- glossary and brand consistency
- locale-specific assumptions

The new frame makes Lokalite a test and QA tool for multilingual AI behavior.

## Why The Name Still Works

The name still suggests localization, but it is broad enough to support a modern interpretation:

- localizing agent behavior
- testing locale-specific interactions
- making AI apps reliable across locales
- keeping multilingual agent behavior lightweight and inspectable

## Suggested README Rewrite

Potential opening:

> Lokalite is an open-source i18n testing tool for AI agents. It helps developers catch cross-language regressions in prompts, tool calls, structured outputs, glossary rules, and agent behavior before they reach users.

Potential problem statement:

> Translating UI strings is no longer enough. AI products respond dynamically, call tools, produce structured data, and follow prompts that may behave differently across languages. Lokalite gives developers a lightweight way to test those behaviors across locales.

Potential audience:

> Built for developers shipping multilingual LLM apps, support agents, copilots, and agentic workflows.

## Product Principles

- Locale-first: every feature should help compare behavior across locales.
- Deterministic before magical: prefer schema, placeholder, glossary, and tool-call checks before LLM judging.
- Developer-local: the tool should work locally and in CI before requiring a hosted app.
- Framework-adaptable: integrate through adapters instead of owning the agent runtime.
- Report clearly: failures should explain what changed and why it matters.
- Small surface area: do not rebuild a translation management platform.

## Risks

- The product becomes too broad if it tries to support all eval types.
- LLM-as-judge features can become expensive, flaky, and hard to trust.
- Integrations can consume all project energy before the core value is proven.
- The current app architecture may be heavier than needed for a CLI-first tool.
- Users may not know they have this problem until they see concrete examples.

## Wedge

Start with one narrow, painful workflow:

> I have an AI agent that calls tools. I need to know whether Spanish, French, and Japanese users trigger the same actions as English users.

That wedge is specific, demonstrable, and not well covered by traditional i18n tools.

## Later Possibilities

- GitHub PR comments for multilingual agent regressions.
- MCP server for coding agents.
- Import traces from OpenAI Agents SDK, LangSmith, Langfuse, or Vercel AI SDK.
- Prompt localization review.
- Locale-specific synthetic test generation.
- Translation memory and glossary support for prompt and scenario variants.
- Visual dashboard for run history.
- CI badge or GitHub Action.
