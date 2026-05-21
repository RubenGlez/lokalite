# Mission, Vision, And Principles

## Mission

Help developers verify that AI-powered products behave correctly across
languages, regions, and cultures.

## Vision

Lokalite should become a lightweight, open-source way to test localized AI
behavior before it reaches users.

The long-term vision is not to replace translation platforms or observability
platforms. It is to make locale-aware behavior testing a normal part of building
AI workflows.

## Point Of View

Localization for AI products is no longer only about translated strings.

AI workflows can:

- interpret user intent
- call tools
- choose arguments
- produce structured output
- retrieve context
- apply policy
- generate product copy
- adapt tone and formatting

If those behaviors change across locales, the product is not fully localized,
even if every static string has been translated.

Lokalite's perspective is:

> Localized AI experiences need behavior tests, not just translation checks.

## Values

### Behavior Over Text

Text matters, but behavior matters more. Lokalite should prioritize whether the
workflow did the right thing: selected the right tool, preserved structure,
followed policy, and respected locale expectations.

### Deterministic First

Trustworthy checks should come before impressive checks. Schema validation,
tool-call assertions, placeholder preservation, glossary rules, and explicit
locale expectations should be preferred before LLM-as-judge scoring.

### Locale As A First-Class Variable

Locale should not be a metadata field at the edge of the system. It should be a
core dimension in scenarios, reports, comparisons, and failures.

### Developer-Local Before Platform

The first useful version should run locally and in CI. A dashboard, hosted app,
or integrations can come later if the core harness proves useful.

### Complement Existing Tools

Lokalite should not try to replace translation management, tracing, or generic
LLM eval platforms. It should fill the focused gap between them: localized AI
behavior verification.

### Evidence Before Ambition

The project should produce investigations, examples, and measurable failures
before expanding into a larger product surface.

## Product Promise

Lokalite should make this kind of issue easy to see:

```text
Same intent, different locale, different behavior.
```

The first useful product promise is:

> Run localized scenarios against an AI workflow and catch behavior drift.

## Non-Goals

Lokalite should not start as:

- a hosted SaaS
- a full translation management system
- a prompt CMS
- a generic agent observability platform
- a translation memory system
- a subjective scoring dashboard
- a large framework with many required integrations

These may become adjacent opportunities later, but they are not the first
problem to solve.

## First Audience

The first audience is developers building multilingual AI workflows, especially
workflows that use:

- tool calling
- structured outputs
- support or commerce agents
- generated product copy
- locale-specific formatting
- policy-sensitive behavior

## Success Criteria

The project is worth continuing if Lokalite can help developers find failures
that would otherwise be invisible in normal English-first testing.

The clearest early success is:

> A developer runs Lokalite in CI and catches a locale-specific agent regression
> before shipping.

