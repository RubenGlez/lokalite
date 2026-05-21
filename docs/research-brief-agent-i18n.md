# Research Brief: Agent i18n

## Purpose

This brief collects research signals that support Lokalite's proposed pivot:

> From translated strings to localized AI behavior.

The goal is not to prove that a product already exists. The goal is to show
that multilingual agent behavior is an active reliability problem, then identify
where an OSS developer tool could create value.

## Claim

AI localization is shifting from static asset translation toward behavior
verification. For agentic systems, a localized experience is only correct if the
agent preserves intent, tool use, structured output, safety behavior, and
locale-specific assumptions across languages.

## Research Signals

### 1. Multilingual Tool Calling Is An Emerging Benchmark Category

Recent benchmarks focus specifically on multilingual function/tool calling,
which suggests the problem is no longer theoretical.

- [International Tool Calling](https://huggingface.co/papers/2603.05515)
  evaluates LLMs on real APIs across languages and geographies. The paper page
  describes substantial gaps between open and closed models, especially for
  non-English queries, and positions cross-lingual tool-use robustness as a
  core benchmark goal.
- [MASSIVE-Agents](https://papers.cool/venue/2025.findings-emnlp.1099%40ACL)
  reformats the MASSIVE intent dataset for function-calling evaluation across
  52 languages, with 47k+ samples and 55 functions.
- [Ticket-Bench](https://openreview.net/forum?id=RrcWawfxSz) evaluates
  task-oriented agents across six languages in a ticket-purchase domain. Its
  authors report notable gaps between languages even for strong models.

Product implication:

Lokalite should not frame multilingual tool calls as a niche edge case. It is
already a benchmarked capability. The product opportunity is to bring this from
research benchmarks into everyday app and agent development.

### 2. Agent Evaluation Is Moving Below Final Text

Agent quality cannot be judged only from the final answer. Tool trajectories,
function names, arguments, missing parameters, and unnecessary calls matter.

- [Berkeley Function Calling Leaderboard / BFCL](https://www2.eecs.berkeley.edu/Pubs/TechRpts/2025/31680.html)
  evaluates whether models invoke the correct function calls across single-turn,
  live, and agentic settings.
- [HammerBench](https://aclanthology.org/2025.findings-acl.175.pdf) argues for
  fine-grained function-calling metrics such as function-name accuracy,
  parameter hallucination, missing parameters, and progress rate.

Product implication:

Lokalite should test localized behavior at the action boundary, not just the
response-text boundary. A useful MVP should inspect tool calls and structured
outputs directly.

### 3. Multilingual Agent Benchmarks Remain Incomplete

The research ecosystem is expanding, but the benchmark space is still uneven.
Some work focuses on one domain, one interaction style, or translated versions
of English tasks.

- [MAPS: A Multilingual Benchmark for Agent Performance and Security](https://aclanthology.org/2026.findings-eacl.42.pdf)
  argues that most existing agentic benchmarks remain English-only and that
  multilingual limitations can propagate into agent decision-making and tool
  execution. It also notes that many multilingual agentic benchmarks are still
  narrow in domain or interaction paradigm.

Product implication:

There is room for a practical, framework-adaptable tool that lets teams build
their own localized scenarios against their own agents, instead of relying only
on public benchmarks.

### 4. Safety Behavior Can Drift Across Languages

Localization is not only usability. It can also affect safety and policy
behavior.

- [All Languages Matter: On the Multilingual Safety of Large Language Models](https://huggingface.co/papers/2310.00905)
  introduces XSafety, a multilingual safety benchmark. The paper page reports
  that evaluated LLMs produced significantly more unsafe responses for
  non-English queries than English queries.
- MAPS also frames multilingual contexts as relevant to agent security,
  especially because agents use LLM outputs for decision-making and tool
  execution.

Product implication:

Lokalite should eventually support safety parity checks across locales. The MVP
can begin with deterministic guardrails, then later add review workflows or
judge-based checks.

### 5. Cross-Lingual Evaluation Itself Is Underdeveloped

Evaluating multilingual model outputs is difficult because reference answers,
human annotators, and model judges are often English-centered.

- [Cross-Lingual Auto Evaluation for Assessing Multilingual LLMs](https://huggingface.co/papers/2410.13394)
  describes a cross-lingual evaluation framework designed to reduce dependence
  on target-language reference answers and improve evaluation in lower-resource
  settings.

Product implication:

Lokalite should be careful with LLM-as-judge features. Deterministic assertions
should come first. Judge-based evaluation should be optional, transparent, and
treated as a complement rather than the foundation.

## What This Means For Lokalite

The research supports a focused north star:

> Lokalite is a locale-aware test harness for AI behavior.

The practical value is not "translate this string." The value is:

- compare behavior across locales
- detect tool-call drift
- detect schema and structured-output failures
- protect placeholders and product terms
- surface safety and policy differences
- make multilingual agent testing runnable in CI

## Strongest MVP Hypothesis

Developers will understand the value fastest if Lokalite catches a concrete
localized action failure:

```text
Scenario: refund_request

English input  -> create_refund_ticket ✅
Spanish input  -> create_refund_ticket ✅
French input   -> no tool call ❌
Japanese input -> invalid structured output ❌
```

This maps directly to the research trend: multilingual function calling and
agentic behavior evaluation.

## Research-Backed Product Principles

- Test behavior, not just text.
- Inspect tool calls and arguments directly.
- Prefer deterministic assertions before LLM judges.
- Treat locale as an experimental variable.
- Support user-owned scenarios, not only public benchmark tasks.
- Preserve structure, placeholders, and glossary terms.
- Track safety and policy parity as the product matures.

## Suggested Investigation Questions

These questions should guide future product experiments:

- How often do popular models change tool-call behavior when the same intent is
  expressed in different languages?
- Are failures more common in function name selection, argument extraction,
  missing required parameters, or structured output formatting?
- Which checks can be deterministic enough for CI?
- Which checks require human review or LLM judging?
- Can translated scenarios be generated reliably enough, or should users author
  locale-specific variants?
- Does a locale matrix report reveal failures faster than generic trace
  dashboards?
- Can Lokalite integrate with existing eval tools instead of replacing them?

## Tooling Gap

Existing observability and eval platforms can often be configured to test
localized cases. The gap for Lokalite is not raw capability. The gap is product
focus:

- locale-first scenario modeling
- behavior parity reports
- glossary and placeholder assertions
- tool-call and structured-output checks by locale
- lightweight CI usage
- possible MCP integration for coding agents

The product should win by being the simplest way to ask:

> Did this AI workflow still work when the user used another language?

## Sources

- [International Tool Calling](https://huggingface.co/papers/2603.05515)
- [MASSIVE-Agents](https://papers.cool/venue/2025.findings-emnlp.1099%40ACL)
- [Ticket-Bench](https://openreview.net/forum?id=RrcWawfxSz)
- [Berkeley Function Calling Leaderboard / BFCL](https://www2.eecs.berkeley.edu/Pubs/TechRpts/2025/31680.html)
- [HammerBench](https://aclanthology.org/2025.findings-acl.175.pdf)
- [MAPS](https://aclanthology.org/2026.findings-eacl.42.pdf)
- [All Languages Matter](https://huggingface.co/papers/2310.00905)
- [Cross-Lingual Auto Evaluation](https://huggingface.co/papers/2410.13394)
