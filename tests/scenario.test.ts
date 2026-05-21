import assert from "node:assert/strict";
import test from "node:test";
import { assertExpectedToolCall } from "../src/assertions.ts";
import { parseScenario } from "../src/scenario.ts";

test("parses the explicit v0 scenario shape", () => {
  const scenario = parseScenario(`
id: refund_request
agent: support

locales:
  en:
    input: "I was charged twice."
    expect:
      toolCall:
        name: create_refund_ticket
`);

  assert.equal(scenario.id, "refund_request");
  assert.equal(scenario.agent, "support");
  assert.equal(scenario.locales.en.input, "I was charged twice.");
  assert.equal(scenario.locales.en.expect.toolCall.name, "create_refund_ticket");
});

test("fails when the expected tool call is missing", () => {
  const result = assertExpectedToolCall(
    { toolCall: { name: "create_refund_ticket" } },
    { text: "I can help.", toolCalls: [], structured: null },
  );

  assert.deepEqual(result, {
    pass: false,
    detail: "expected create_refund_ticket, got no tool calls",
  });
});

test("passes when the expected tool call appears", () => {
  const result = assertExpectedToolCall(
    { toolCall: { name: "create_refund_ticket" } },
    {
      text: "I can help.",
      toolCalls: [{ name: "create_refund_ticket" }],
      structured: null,
    },
  );

  assert.deepEqual(result, {
    pass: true,
    detail: "create_refund_ticket",
  });
});
