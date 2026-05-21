# Agent i18n Product Notes

## Thesis

Lokalite should not try to become another general-purpose translation management system. The stronger opportunity is to become an open-source i18n lab for AI agents and LLM applications.

Modern AI products do not only have localizable UI strings. They have prompts, tool descriptions, structured outputs, agent handoffs, safety policies, tone rules, retrieval snippets, and multi-turn behavior. Those surfaces can drift across languages in ways traditional localization tools do not catch.

The core question Lokalite should answer is:

> Will this agent behave correctly when the user speaks another language?

## Positioning

Lokalite is a multilingual behavior testing tool for AI agents.

Short version:

> Catch cross-language agent regressions before your users do.

Longer version:

> Lokalite helps developers test whether AI agents preserve intent, tool behavior, structured output, glossary rules, tone, and safety behavior across locales.

## What This Is Not

Lokalite should avoid competing directly with mature localization platforms.

It is not:

- A full translation management system.
- A Weblate, Tolgee, Lokalise, or Phrase replacement.
- A generic LLM eval dashboard.
- A translation-only wrapper around an LLM.

Those categories are already crowded and better served by established tools.

## The Gap

Existing i18n tools are good at managing translation assets. Existing AI eval tools are good at testing prompts, traces, and model outputs. The gap is the overlap:

- Does the same user intent trigger the same tool call across languages?
- Does a localized prompt preserve the original agent behavior?
- Do structured outputs stay valid in every locale?
- Are placeholders, product terms, legal terms, and glossary constraints preserved?
- Does safety behavior become weaker or stricter in some languages?
- Does the agent make locale-specific assumptions about currency, dates, addresses, names, or regulations?
- Does tone drift when translated into a culture with different register expectations?
- Do retrieval or support answers degrade for non-English users?

This is where Lokalite can be useful.

## Target Users

Primary users:

- Developers building AI agents or LLM-powered product workflows.
- Small teams shipping multilingual AI features without a localization department.
- OSS maintainers who want lightweight multilingual checks in CI.
- Builders using agent frameworks, tool calling, structured outputs, or MCP.

Secondary users:

- Localization engineers who want agent-specific QA.
- Prompt engineers who need to localize behavior, not just words.
- QA teams testing multilingual AI product behavior.

## Initial Product Shape

The product should be a developer tool, not a heavy web platform.

Recommended order:

1. CLI runner.
2. Scenario file format.
3. Local HTML report.
4. CI-friendly exit codes.
5. Optional web UI once the evaluation model is proven.
6. Optional MCP server so coding agents can call Lokalite.

## Example Workflow

```bash
lokalite run --config lokalite.config.ts
```

Example result:

```text
Suite: support-agent

refund_request
  en: pass
  es: pass
  fr: fail - expected tool call create_refund_ticket, got answer_only
  ja: fail - structured output validation failed

password_reset
  en: pass
  es: pass
  fr: pass
  ja: pass
```

## Core Concepts

- Project: A product or agent workspace.
- Locale: A language or regional variant under test.
- Agent target: The agent, endpoint, script, or adapter being tested.
- Scenario: A multilingual behavior test.
- Input variant: A user message for a locale.
- Expected behavior: Assertions about language, tool use, schema, content, safety, and glossary.
- Glossary: Product terms, forbidden terms, and locale-specific vocabulary.
- Run: One execution of a suite against one or more locales/models.
- Result: Pass/fail plus diagnostics, traces, and diffs.

## Core Assertions

The first version should support a focused set of checks:

- Response language matches expected locale.
- Required terms are preserved or translated according to glossary.
- Forbidden terms do not appear.
- Placeholders and interpolations are preserved.
- JSON or structured output matches a schema.
- Required tool call happened.
- Forbidden tool call did not happen.
- Locale-specific expected values are present, such as currency, date format, or region-specific wording.

## Example Scenario

```yaml
id: refund_request
agent: support
description: User asks for a refund after a failed payment.

locales:
  en:
    input: 'I was charged twice for my subscription. Can you refund one charge?'
    expect:
      language: en
      toolCall:
        name: create_refund_ticket
      glossary:
        preserve:
          - 'Lokalite'

  es:
    input: 'Me cobraron dos veces la suscripcion. Puedes devolverme uno de los cargos?'
    expect:
      language: es
      toolCall:
        name: create_refund_ticket
      glossary:
        preserve:
          - 'Lokalite'
```

## Possible Adapters

Lokalite can stay useful by integrating at the boundary rather than owning the whole agent stack.

Potential target adapters:

- HTTP endpoint adapter.
- Node function adapter.
- OpenAI Agents SDK trace adapter.
- LangChain or LangGraph adapter.
- Vercel AI SDK adapter.
- MCP tool/server adapter.
- Static transcript adapter for offline analysis.

## MCP Opportunity

An MCP server could let coding agents ask Lokalite to perform i18n-specific work:

- Extract user-facing strings from a diff.
- Generate missing locale variants for scenarios.
- Validate placeholders and glossary terms.
- Run multilingual agent evals.
- Summarize locale-specific regressions.
- Comment on a PR with i18n risks.

This would make Lokalite part of the agent ecosystem rather than only a standalone app.

## Strategic Test

This project is worth pursuing if it can make a developer say:

> I already have translations, but I have no idea whether my agent behaves the same way in Spanish, Japanese, and Arabic. This catches things my normal tests miss.

It is not worth pursuing if it collapses back into:

> Upload strings and translate them with AI.

That version is too crowded and not differentiated enough.

## Open Questions

- Should the CLI stay the primary interface, or should a report viewer become a near-term priority?
- Should scenarios be authored manually, generated from English, or both?
- How much should Lokalite depend on real model calls versus replayed traces?
- Should assertions be deterministic first, LLM-judged later, or both from day one?
- Which adapter gives the strongest demo with the least integration burden?
- Should the project support source-code string extraction, or avoid that until agent evals are proven?
- Should Lokalite store history, or should CI artifacts be enough initially?
