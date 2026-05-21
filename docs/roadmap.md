# Roadmap

## North Star

Lokalite is a locale-aware eval harness for AI workflows.

Its purpose is to answer one question clearly:

> Given the same user intent across locales, does the AI workflow preserve
> behavior?

This means Lokalite should test localized AI behavior, not only translated
strings.

## Product Strategy

Build an investigation tool first, not a platform.

The first version should be useful for research, demos, and local developer
workflows. A dashboard, hosted service, prompt editor, trace ingestion, MCP
server, or translation management system can come later only if the core signal
is proven.

## Core Hypothesis

AI workflows can drift across languages in ways developers do not currently see.

The first product should help detect:

- tool-call drift
- missing or wrong tool arguments
- invalid structured outputs
- wrong response language
- corrupted placeholders
- glossary or product-term violations
- policy or safety differences
- locale-specific formatting mistakes

## Milestone 0: Exploration Branch

Status: in progress.

Goal:

Keep the repository as a clean research and planning space while the new product
shape is explored.

Deliverables:

- Product thesis.
- MVP notes.
- Repositioning notes.
- Research brief.
- Roadmap.

Success criteria:

- The repo explains why Lokalite should exist.
- The docs separate research evidence from product bets.
- The next implementation step is obvious.

## Milestone 1: Local Scenario Runner

Goal:

Run one localized scenario from the terminal against one HTTP target.

Example:

```bash
lokalite run ./examples/scenarios/refund-request.yaml --target http://localhost:3000/api/agent
```

Minimum scenario shape:

```yaml
id: refund_request
agent: support

locales:
  en:
    input: "I was charged twice. Can you refund one charge?"
    expect:
      toolCall:
        name: create_refund_ticket

  es:
    input: "Me cobraron dos veces. Puedes devolverme uno de los cargos?"
    expect:
      toolCall:
        name: create_refund_ticket

  fr:
    input: "J'ai ete facture deux fois. Pouvez-vous me rembourser un paiement?"
    expect:
      toolCall:
        name: create_refund_ticket
```

Deliverables:

- YAML scenario parser.
- HTTP target adapter with a strict request/response contract.
- CLI command.
- Required tool-call-name assertion.
- Plain terminal report.
- Non-zero exit code on failure.
- Tiny example support agent with an intentional French failure.

First target:

- HTTP endpoint target.

Deferred from this milestone:

- Config loader.
- Multiple suites.
- HTML report.
- JSON schema validation.
- Glossary and placeholder checks.
- Language detection.
- Parallel execution.

Success criteria:

- A developer can point Lokalite at a local agent endpoint.
- Lokalite can run the same intent across at least three locales.
- The output clearly shows pass/fail by locale.
- The demo shows a concrete cross-locale tool-call regression in under one
  minute.

## Milestone 2: Deterministic Assertions

Goal:

Make Lokalite trustworthy in CI by expanding the deterministic assertion set
after the first runner loop works.

Initial assertions:

- forbidden tool call name
- required tool arguments
- forbidden or missing arguments
- JSON schema validation
- expected response language
- `contains`
- `notContains`
- placeholder preservation
- glossary preservation

Avoid in this milestone:

- LLM-as-judge scoring
- subjective tone evaluation
- broad semantic equivalence claims

Success criteria:

- Lokalite can catch invalid structured output.
- Lokalite can catch placeholder or glossary corruption.
- Results are stable enough for CI.

## Milestone 3: Config, Suites, And Static Results

Goal:

Make local and CI usage convenient across more than one scenario.

Deliverables:

- `lokalite.config.ts` or `lokalite.config.json`.
- Multiple scenarios and suites.
- JSON scenario support.
- JSON result output.
- Optional concurrency flag.
- Static HTML report.

Success criteria:

- A developer can run a suite without passing every option on the command line.
- CI can archive machine-readable results and a human-readable report.
- Failures remain understandable at the locale and assertion level.

## Milestone 4: Research Mode

Goal:

Use Lokalite to investigate behavior drift across models, locales, and prompts.

Example:

```bash
lokalite compare --models gpt-4.1-mini,claude-haiku,qwen
```

Example output:

```text
Scenario: refund_request

Model           en   es   fr   ja
gpt-4.1-mini    ok   ok   fail ok
claude-haiku    ok   ok   ok   fail
qwen            ok   fail fail fail
```

Deliverables:

- Multiple model or target execution.
- Matrix report by locale and model.
- JSON result output for later analysis.
- Fixture scenarios suitable for repeatable experiments.

Success criteria:

- Lokalite can produce a small, publishable investigation.
- The investigation demonstrates at least one real cross-locale behavior drift.
- The results are understandable without reading the code.

## Milestone 5: Expanded Example Agent And Demo Suite

Goal:

Make the product value obvious in under one minute.

Demo agent behaviors:

- refund requests should call `create_refund_ticket`
- password reset requests should call `send_password_reset`
- billing status requests should return valid structured output

Intentional demo failures:

- one locale answers directly without calling the expected tool
- one locale returns malformed structured output
- one locale corrupts a placeholder or product term

Deliverables:

- Example HTTP agent.
- Example scenarios.
- Example schemas.
- Example terminal report.
- Optional static HTML report.

Success criteria:

- A new visitor can clone the repo and run a demo.
- The demo explains the product without a long README.
- The failure modes map directly to the research brief.

## Milestone 6: Rich Static Report

Goal:

Make failures easy to inspect and share.

Deliverables:

- Static HTML report.
- Locale matrix.
- Scenario detail pages.
- Raw response view.
- Tool call view.
- Structured output validation errors.
- Assertion failure explanations.

Success criteria:

- The report is useful as a CI artifact.
- The report makes behavior drift visible at a glance.

## Milestone 7: Integrations After Proof

Goal:

Integrate only after the core runner proves useful.

Possible integrations:

- OpenAI model target.
- Anthropic model target.
- Vercel AI SDK adapter.
- OpenAI Agents SDK adapter.
- LangChain or LangGraph adapter.
- Langfuse or LangSmith import/export.
- GitHub Action.
- MCP server.

Integration principle:

Lokalite should complement existing eval and observability tools, not replace
them.

Success criteria:

- At least one integration makes a real workflow simpler.
- The integration does not blur the locale-first product focus.

## Things To Avoid Early

Avoid building these until the core signal is proven:

- hosted app
- accounts and permissions
- full dashboard
- translation management system
- prompt CMS
- trace observability platform
- translation memory
- complex LLM judge framework
- broad "agent quality" scoring

## First Public Artifact

The first public artifact should be an investigation, not a product launch.

Suggested shape:

> We tested the same AI workflow in multiple languages and found behavior drift.
> Here is the OSS harness we used.

This gives Lokalite a reason to exist even before it becomes a polished tool.

## Definition Of Success

Lokalite is worth continuing if it can make this failure visible:

```text
English user asks for refund  -> create_refund_ticket
Spanish user asks for refund  -> create_refund_ticket
French user asks for refund   -> no tool call
Japanese user asks for refund -> invalid structured output
```

If Lokalite can reliably surface these differences, it has a real OSS niche.
