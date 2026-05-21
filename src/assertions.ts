import type { ScenarioLocale, TargetResponse } from "./types.ts";

export function assertExpectedToolCall(
  expected: ScenarioLocale["expect"],
  response: TargetResponse,
): { pass: true; detail: string } | { pass: false; detail: string } {
  const expectedName = expected.toolCall.name;
  const toolCall = response.toolCalls.find((candidate) => candidate.name === expectedName);

  if (toolCall) {
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
