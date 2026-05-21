import type { ScenarioLocale, TargetResponse } from "./types.ts";

export function assertExpectedToolCall(
  expected: ScenarioLocale["expect"],
  response: TargetResponse,
): { pass: true; detail: string } | { pass: false; detail: string } {
  const forbiddenToolCallResult = assertForbiddenToolCall(expected.noToolCall?.name, response);

  if (!forbiddenToolCallResult.pass) {
    return forbiddenToolCallResult;
  }

  const expectedName = expected.toolCall.name;
  const toolCall = response.toolCalls.find((candidate) => candidate.name === expectedName);

  if (toolCall) {
    const argumentResult = assertExpectedArguments(expected.toolCall.arguments, toolCall.arguments);

    if (!argumentResult.pass) {
      return argumentResult;
    }

    return { pass: true, detail: expectedName };
  }

  if (response.toolCalls.length === 0) {
    return { pass: false, detail: `expected ${expectedName}, got no tool calls` };
  }

  return {
    pass: false,
    detail: `expected ${expectedName}, got ${response.toolCalls.map((call) => call.name).join(", ")}`,
  };
}

function assertForbiddenToolCall(
  forbiddenName: string | undefined,
  response: TargetResponse,
): { pass: true } | { pass: false; detail: string } {
  if (!forbiddenName) {
    return { pass: true };
  }

  const forbiddenToolCall = response.toolCalls.find((candidate) => candidate.name === forbiddenName);

  if (!forbiddenToolCall) {
    return { pass: true };
  }

  return { pass: false, detail: `forbidden tool call ${forbiddenName} was called` };
}

function assertExpectedArguments(
  expectedArguments: Record<string, string> | undefined,
  actualArguments: unknown,
): { pass: true } | { pass: false; detail: string } {
  if (!expectedArguments || Object.keys(expectedArguments).length === 0) {
    return { pass: true };
  }

  if (!actualArguments || typeof actualArguments !== "object" || Array.isArray(actualArguments)) {
    return { pass: false, detail: "expected tool arguments, got none" };
  }

  const actual = actualArguments as Record<string, unknown>;

  for (const [key, expectedValue] of Object.entries(expectedArguments)) {
    if (!(key in actual)) {
      return { pass: false, detail: `expected argument ${key}=${expectedValue}, got missing` };
    }

    if (actual[key] !== expectedValue) {
      return {
        pass: false,
        detail: `expected argument ${key}=${expectedValue}, got ${String(actual[key])}`,
      };
    }
  }

  return { pass: true };
}
