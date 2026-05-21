import { assertExpectedToolCall } from "./assertions.ts";
import { executeHttpTarget } from "./httpTarget.ts";
import type { LocaleResult, RunResult, Scenario } from "./types.ts";

export async function runScenario(scenario: Scenario, target: string): Promise<RunResult> {
  const results: LocaleResult[] = [];

  for (const [locale, variant] of Object.entries(scenario.locales)) {
    const targetResult = await executeHttpTarget({
      target,
      scenarioId: scenario.id,
      locale,
      input: variant.input,
    });

    if (!targetResult.ok) {
      results.push({
        locale,
        status: "fail",
        detail: targetResult.detail,
      });
      continue;
    }

    const assertion = assertExpectedToolCall(variant.expect, targetResult.response);

    results.push({
      locale,
      status: assertion.pass ? "pass" : "fail",
      detail: assertion.detail,
      response: targetResult.response,
    });
  }

  return {
    scenarioId: scenario.id,
    target,
    results,
  };
}
