# DeepSeek Demo

Lokalite can run against a real LLM-backed agent through the same HTTP target
contract used by the deterministic example.

The DeepSeek demo uses the official OpenAI-compatible Chat Completions API at
`https://api.deepseek.com/chat/completions` with function tools.

## Run The Demo

```bash
DEEPSEEK_API_KEY=... npm run example:deepseek-agent
```

In another terminal:

```bash
npm run lokalite -- run ./examples/scenarios/deepseek-refund-request.yaml --target http://127.0.0.1:3001/api/agent
```

Optional model override:

```bash
DEEPSEEK_MODEL=deepseek-v4-pro DEEPSEEK_API_KEY=... npm run example:deepseek-agent
```

The default model is `deepseek-v4-flash`.

## Run The Benchmark

```bash
DEEPSEEK_API_KEY=... npm run benchmark:deepseek
```

Optional iteration count:

```bash
ITERATIONS=5 DEEPSEEK_API_KEY=... npm run benchmark:deepseek
```

The benchmark writes:

```text
examples/deepseek-support-agent/benchmark-results.md
```

## What It Measures

The benchmark runs the same refund intent across English, Spanish, French, and
Japanese. Each locale must:

- call `create_refund_ticket`
- include `reason: duplicate_charge`
- avoid `escalate_to_human`

This is intentionally narrow. It measures whether a real model preserves the
same tool behavior across localized inputs.
