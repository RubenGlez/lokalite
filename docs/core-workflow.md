# Multilingual Agent Behavior Testing

## Goal

Keep Lokalite focused on the smallest useful workflow:

> A developer can define multilingual scenarios for an AI agent, run them locally or in CI, and see whether behavior changes across locales.

## Non-Goals

- Do not build a full translation management workflow.
- Do not build accounts, organizations, permissions, or billing.
- Do not build a generic observability platform.
- Do not support every agent framework at first.
- Do not rely only on LLM-as-judge checks when deterministic validation is possible.

## User Story

As a developer building an AI support agent, I want to run the same scenario in multiple languages, so that I can catch cases where the agent fails to call the right tool, returns invalid JSON, ignores glossary rules, or responds in the wrong language.

## Core Workflow

Lokalite runs explicit locale variants against an agent target, applies
deterministic assertions, and reports behavior drift by locale.

### 1. Direct CLI Run

Run one explicit scenario file against one HTTP target passed through the CLI.

Example:

```bash
npm run lokalite -- run ./examples/scenarios/refund-request.yaml --target http://127.0.0.1:3000/api/agent
```

The direct CLI workflow does not require a config file. A future
`lokalite.config.ts` or `lokalite.config.json` can add default locales, agents,
suites, and glossary settings.

### 2. Scenario Format

Support one YAML scenario file.

Minimum fields:

- `id`
- `agent`
- explicit `locales`
- `input` per locale
- `expect.toolCall.name` per locale

Example:

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

The format optimizes for explicitness over compactness. Shared expectations,
inheritance, generated translations, and shorthand syntax are future additions.

### 3. Runner

Run the scenario sequentially across its configured locales.

Required behavior:

- Execute each localized input against the target agent.
- Capture response text if returned.
- Capture tool calls if returned.
- Apply the required tool-call-name assertion.
- Print a plain terminal summary.
- Exit non-zero if any locale fails.

Target/runtime errors should become per-locale failures wherever possible:

- HTTP network error
- non-2xx response
- invalid JSON response
- missing or empty tool calls

Invalid scenario files should fail the run early.

### 4. Assertions

The core assertion is deterministic:

- `toolCall.name`: required tool call name.

Example:

```yaml
expect:
  toolCall:
    name: create_refund_ticket
```

Additional deterministic assertions:

- `noToolCall.name`: forbidden tool call name.
- required tool arguments
- forbidden or missing arguments
- `jsonSchema`: validate structured output.
- `language`: expected response language.
- `contains`: required substrings.
- `notContains`: forbidden substrings.
- `preserves`: required placeholders or exact terms.
- glossary preservation

Additional assertions:

- tone match
- semantic equivalence
- cultural appropriateness
- safety parity
- locale-specific policy checks

### 5. Terminal Report

Generate a plain, CI-readable terminal report.

Example:

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

Colors, spinners, rich diffs, and HTML reports are intentionally outside this
core workflow.

## HTTP Adapter

Use an HTTP adapter first.

Request shape:

```json
{
  "locale": "es",
  "input": "Me cobraron dos veces. Puedes ayudarme?",
  "scenarioId": "refund_request"
}
```

Recommended response shape:

```json
{
  "text": "Claro, puedo ayudarte con eso.",
  "toolCalls": [
    {
      "name": "create_refund_ticket",
      "arguments": {
        "reason": "duplicate_charge"
      }
    }
  ],
  "structured": {
    "status": "needs_refund_ticket"
  }
}
```

Fields may be omitted by the target, but Lokalite should normalize missing
`text`, `toolCalls`, and `structured` values to `""`, `[]`, and `null`.

This keeps Lokalite independent from any one agent framework while giving the
first runner a strict, predictable contract.

## Implementation

Lokalite uses Node and TypeScript with no runtime dependencies.

Key files:

- `src/cli.ts`
- `src/scenario.ts`
- `src/httpTarget.ts`
- `src/assertions.ts`
- `src/runner.ts`
- `src/reportTerminal.ts`
- `examples/support-agent/server.ts`
- `examples/scenarios/refund-request.yaml`
- `tests/scenario.test.ts`

Avoid a monorepo, database, web framework, or config loader until the CLI
workflow needs that complexity.

## Follow-On Scope

Planned expansions:

- `lokalite.config.ts` or `lokalite.config.json`
- multiple scenarios and suites
- JSON scenario files
- static HTML report
- JSON result output
- broader deterministic assertion set
- concurrency flag
- richer example scenarios

## Data Model Draft

If the web app stores results later:

- `projects`
- `locales`
- `agents`
- `suites`
- `scenarios`
- `scenario_variants`
- `assertions`
- `runs`
- `run_results`
- `tool_calls`
- `structured_outputs`
- `glossary_terms`

## Demo Project

The demo project contains a tiny fake support agent with one behavior:

- refund requests should call `create_refund_ticket`

One locale intentionally fails to show the value:

- English and Spanish refund paths call `create_refund_ticket`.
- French refund path answers directly without a tool call.

Additional demo scenarios can add password reset, malformed JSON, placeholder
corruption, and structured output validation.

The demo should make the product obvious in under one minute.

Run it with:

```bash
npm run example:agent
npm run lokalite -- run ./examples/scenarios/refund-request.yaml --target http://127.0.0.1:3000/api/agent
```

The command exits non-zero because the French locale fails by design.

## Success Criteria

Lokalite is successful when:

- It can be run from the terminal.
- It tests at least three locales.
- It catches at least one cross-language tool-call regression.
- The plain terminal output is understandable without reading source code.
- The README can explain the value in one screen.
