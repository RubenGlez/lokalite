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
        arguments:
          reason: duplicate_charge
      noToolCall:
        name: escalate_to_human
`);

  assert.equal(scenario.id, "refund_request");
  assert.equal(scenario.agent, "support");
  assert.equal(scenario.locales.en.input, "I was charged twice.");
  assert.equal(scenario.locales.en.expect.toolCall.name, "create_refund_ticket");
  assert.deepEqual(scenario.locales.en.expect.toolCall.arguments, {
    reason: "duplicate_charge",
  });
  assert.equal(scenario.locales.en.expect.noToolCall?.name, "escalate_to_human");
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

test("fails when an expected tool call argument is missing", () => {
  const result = assertExpectedToolCall(
    {
      toolCall: {
        name: "create_refund_ticket",
        arguments: { reason: "duplicate_charge" },
      },
    },
    {
      text: "I can help.",
      toolCalls: [{ name: "create_refund_ticket", arguments: {} }],
      structured: null,
    },
  );

  assert.deepEqual(result, {
    pass: false,
    detail: "expected argument reason=duplicate_charge, got missing",
  });
});

test("fails when a forbidden tool call appears", () => {
  const result = assertExpectedToolCall(
    {
      toolCall: { name: "create_refund_ticket" },
      noToolCall: { name: "escalate_to_human" },
    },
    {
      text: "I need a person.",
      toolCalls: [{ name: "create_refund_ticket" }, { name: "escalate_to_human" }],
      structured: null,
    },
  );

  assert.deepEqual(result, {
    pass: false,
    detail: "forbidden tool call escalate_to_human was called",
  });
});

test("passes when a forbidden tool call is absent", () => {
  const result = assertExpectedToolCall(
    {
      toolCall: { name: "create_refund_ticket" },
      noToolCall: { name: "escalate_to_human" },
    },
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

test("fails when an expected tool call argument has the wrong value", () => {
  const result = assertExpectedToolCall(
    {
      toolCall: {
        name: "create_refund_ticket",
        arguments: { reason: "duplicate_charge" },
      },
    },
    {
      text: "I can help.",
      toolCalls: [{ name: "create_refund_ticket", arguments: { reason: "other" } }],
      structured: null,
    },
  );

  assert.deepEqual(result, {
    pass: false,
    detail: "expected argument reason=duplicate_charge, got other",
  });
});

test("passes when expected tool call arguments match", () => {
  const result = assertExpectedToolCall(
    {
      toolCall: {
        name: "create_refund_ticket",
        arguments: { reason: "duplicate_charge" },
      },
    },
    {
      text: "I can help.",
      toolCalls: [
        {
          name: "create_refund_ticket",
          arguments: { reason: "duplicate_charge", locale: "en" },
        },
      ],
      structured: null,
    },
  );

  assert.deepEqual(result, {
    pass: true,
    detail: "create_refund_ticket",
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
