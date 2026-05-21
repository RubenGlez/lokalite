#!/usr/bin/env node
import { spawn } from "node:child_process";
import { once } from "node:events";
import { writeFile } from "node:fs/promises";

const scenarioPath = process.env.SCENARIO ?? "./examples/scenarios/deepseek-refund-request.yaml";
const target = "http://127.0.0.1:3001/api/agent";
const iterations = Number.parseInt(process.env.ITERATIONS ?? "3", 10);

if (!process.env.DEEPSEEK_API_KEY) {
  console.error("DEEPSEEK_API_KEY is required to run the DeepSeek benchmark.");
  process.exit(1);
}

const server = spawn(process.execPath, ["./examples/deepseek-support-agent/server.ts"], {
  env: { ...process.env, PORT: "3001" },
  stdio: ["ignore", "pipe", "pipe"],
});

let serverOutput = "";
server.stdout.on("data", (chunk) => {
  serverOutput += chunk.toString();
});
server.stderr.on("data", (chunk) => {
  serverOutput += chunk.toString();
});

try {
  await waitForServer();

  const runs: BenchmarkRun[] = [];

  for (let index = 0; index < iterations; index += 1) {
    const startedAt = performance.now();
    const run = await runLokalite();
    const durationMs = Math.round(performance.now() - startedAt);

    runs.push({
      iteration: index + 1,
      durationMs,
      exitCode: run.exitCode,
      output: run.output,
      summary: parseOutput(run.output),
    });
  }

  const report = renderReport(runs, scenarioPath);
  const scenarioSlug = scenarioPath.replace(/^.*\//, "").replace(/\.yaml$/, "");
  await writeFile(`./examples/deepseek-support-agent/benchmark-${scenarioSlug}.md`, report);
  process.stdout.write(report);
} finally {
  server.kill("SIGINT");
}

async function waitForServer(): Promise<void> {
  const deadline = Date.now() + 10_000;

  while (Date.now() < deadline) {
    if (serverOutput.includes("DeepSeek support agent listening")) {
      return;
    }

    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  throw new Error(`DeepSeek example server did not start.\n${serverOutput}`);
}

async function runLokalite(): Promise<{ exitCode: number; output: string }> {
  const child = spawn(
    process.execPath,
    ["./src/cli.ts", "run", scenarioPath, "--target", target],
    { stdio: ["ignore", "pipe", "pipe"] },
  );

  let output = "";
  child.stdout.on("data", (chunk) => {
    output += chunk.toString();
  });
  child.stderr.on("data", (chunk) => {
    output += chunk.toString();
  });

  const [exitCode] = (await once(child, "close")) as [number];

  return { exitCode, output };
}

function parseOutput(output: string): Record<string, "pass" | "fail"> {
  const summary: Record<string, "pass" | "fail"> = {};

  for (const line of output.split("\n")) {
    const match = line.match(/^([a-z]{2,5})\s+(pass|fail)\s+/);

    if (match) {
      summary[match[1]] = match[2] as "pass" | "fail";
    }
  }

  return summary;
}

function renderReport(runs: BenchmarkRun[], scenarioPath: string): string {
  const localeSet = new Set<string>();
  for (const run of runs) {
    for (const locale of Object.keys(run.summary)) {
      localeSet.add(locale);
    }
  }
  const locales = Array.from(localeSet);
  const passCounts = Object.fromEntries(locales.map((locale) => [locale, 0])) as Record<string, number>;

  for (const run of runs) {
    for (const locale of locales) {
      if (run.summary[locale] === "pass") {
        passCounts[locale] += 1;
      }
    }
  }

  const totalPasses = Object.values(passCounts).reduce((sum, count) => sum + count, 0);
  const totalChecks = runs.length * locales.length;
  const durations = runs.map((run) => run.durationMs);
  const averageDuration = Math.round(durations.reduce((sum, value) => sum + value, 0) / durations.length);

  return [
    "# DeepSeek Demo Benchmark",
    "",
    `Scenario: ${scenarioPath}`,
    `Model: ${process.env.DEEPSEEK_MODEL ?? "deepseek-v4-flash"}`,
    `Iterations: ${runs.length}`,
    `Total locale checks: ${totalChecks}`,
    `Pass rate: ${totalPasses}/${totalChecks} (${Math.round((totalPasses / totalChecks) * 100)}%)`,
    `Average run duration: ${averageDuration} ms`,
    "",
    "| Locale | Passes |",
    "| --- | ---: |",
    ...locales.map((locale) => `| ${locale} | ${passCounts[locale]}/${runs.length} |`),
    "",
    "## Runs",
    "",
    ...runs.flatMap((run) => [
      `### Iteration ${run.iteration}`,
      "",
      `Duration: ${run.durationMs} ms`,
      `Exit code: ${run.exitCode}`,
      "",
      "```text",
      run.output.trim(),
      "```",
      "",
    ]),
  ].join("\n");
}

type BenchmarkRun = {
  iteration: number;
  durationMs: number;
  exitCode: number;
  output: string;
  summary: Record<string, "pass" | "fail">;
};
