#!/usr/bin/env node
import { loadScenario } from "./scenario.ts";
import { runScenario } from "./runner.ts";
import { formatTerminalReport } from "./reportTerminal.ts";

type CliOptions = {
  command: "run";
  scenarioPath: string;
  target: string;
};

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const scenario = await loadScenario(options.scenarioPath);
  const run = await runScenario(scenario, options.target);

  process.stdout.write(formatTerminalReport(run));

  if (run.results.some((result) => result.status === "fail")) {
    process.exitCode = 1;
  }
}

function parseArgs(args: string[]): CliOptions {
  if (args[0] !== "run") {
    throw new Error(usage());
  }

  const scenarioPath = args[1];
  const targetFlagIndex = args.indexOf("--target");
  const target = targetFlagIndex === -1 ? undefined : args[targetFlagIndex + 1];

  if (!scenarioPath || scenarioPath.startsWith("--") || !target) {
    throw new Error(usage());
  }

  return {
    command: "run",
    scenarioPath,
    target,
  };
}

function usage(): string {
  return "Usage: lokalite run <scenario.yaml> --target <url>";
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
});
