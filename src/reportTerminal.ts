import type { RunResult } from "./types.ts";

export function formatTerminalReport(run: RunResult): string {
  const failed = run.results.filter((result) => result.status === "fail").length;
  const localeWidth = Math.max("Locale".length, ...run.results.map((result) => result.locale.length));
  const statusWidth = "Status".length;

  const lines = [
    "Lokalite run",
    "",
    `Scenario: ${run.scenarioId}`,
    `Target: ${run.target}`,
    "",
    `${pad("Locale", localeWidth)}  ${pad("Status", statusWidth)}  Detail`,
    ...run.results.map(
      (result) => `${pad(result.locale, localeWidth)}  ${pad(result.status, statusWidth)}  ${result.detail}`,
    ),
    "",
    `Result: ${failed === 0 ? "passed" : "failed"}, ${failed} of ${run.results.length} locales failed`,
  ];

  return `${lines.join("\n")}\n`;
}

function pad(value: string, width: number): string {
  return value.padEnd(width, " ");
}
