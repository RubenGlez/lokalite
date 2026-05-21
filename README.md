# Lokalite

Lokalite is a locale-aware eval harness for AI workflows.

Core belief:

> AI localization is moving from translated strings to localized behavior.

Traditional i18n asks whether the product text exists in another language.
Lokalite asks whether an AI workflow still behaves correctly when the user
speaks another language, uses another region, or expects another cultural norm.

## What It Tests

Lokalite helps developers detect cross-locale behavior drift in:

- agent tool calls
- tool arguments
- structured outputs
- generated product copy
- response language
- placeholders
- glossary and brand terms
- locale-specific formatting
- policy and safety behavior

## Why This Matters

AI-powered products do not only render strings. They make decisions, call tools,
produce structured data, and generate dynamic responses. Those behaviors can
change when the same user intent is expressed in another language.

Example:

```text
English user asks for refund  -> create_refund_ticket
Spanish user asks for refund  -> create_refund_ticket
French user asks for refund   -> no tool call
Japanese user asks for refund -> invalid structured output
```

That is the kind of failure Lokalite should make visible.

## What Works Today

Run a localized scenario against an HTTP agent endpoint:

```bash
npm run lokalite -- run ./examples/scenarios/refund-request.yaml --target http://127.0.0.1:3000/api/agent
```

Lokalite can:

- load an explicit YAML scenario
- call a strict HTTP agent target across multiple locales
- assert required tool calls and shallow tool arguments
- assert forbidden tool calls did not happen
- report pass/fail by locale in plain terminal output
- exit non-zero on failure
- run a tiny demo support agent with an intentional localized failure

## Try The Demo

Start the example support agent:

```bash
npm run example:agent
```

In another terminal, run the scenario:

```bash
npm run lokalite -- run ./examples/scenarios/refund-request.yaml --target http://127.0.0.1:3000/api/agent
```

Expected result:

```text
Lokalite run

Scenario: refund_request
Target: http://127.0.0.1:3000/api/agent

Locale  Status  Detail
en      pass    create_refund_ticket
es      pass    create_refund_ticket
fr      fail    expected create_refund_ticket, got no tool calls

Result: failed, 1 of 3 locales failed
```

The French failure is intentional. It demonstrates the first product promise:
same intent, different locale, different behavior.

## Real LLM Demo

Lokalite also includes a DeepSeek-backed support agent demo:

```bash
DEEPSEEK_API_KEY=... npm run benchmark:deepseek
```

See [DeepSeek Demo](docs/deepseek-demo.md).

## Documents

- [Mission, Vision, And Principles](docs/mission-vision-principles.md)
- [Agent i18n Product Notes](docs/agent-i18n-product-notes.md)
- [Research Brief](docs/research-brief-agent-i18n.md)
- [Core Workflow](docs/core-workflow.md)
- [DeepSeek Demo](docs/deepseek-demo.md)
- [Roadmap](docs/roadmap.md)

## Working Definition

Lokalite is successful if it becomes the simplest way for a developer to answer:

> Did this AI workflow still work when the user used another language?
