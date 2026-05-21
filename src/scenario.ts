import { readFile } from "node:fs/promises";
import type { Scenario, ScenarioLocale } from "./types.ts";

type Line = {
  indent: number;
  key: string;
  value: string;
  number: number;
};

export async function loadScenario(path: string): Promise<Scenario> {
  const source = await readFile(path, "utf8");
  return parseScenario(source, path);
}

export function parseScenario(source: string, path = "scenario"): Scenario {
  const lines = tokenize(source);
  const id = scalarAt(lines, 0, "id");
  const agent = scalarAt(lines, 0, "agent");
  const localesIndex = lines.findIndex((line) => line.indent === 0 && line.key === "locales");

  if (!id) {
    throw new Error(`${path}: missing required field "id"`);
  }

  if (!agent) {
    throw new Error(`${path}: missing required field "agent"`);
  }

  if (localesIndex === -1) {
    throw new Error(`${path}: missing required field "locales"`);
  }

  const locales = parseLocales(lines.slice(localesIndex + 1), path);

  if (Object.keys(locales).length === 0) {
    throw new Error(`${path}: expected at least one locale`);
  }

  return { id, agent, locales };
}

function parseLocales(lines: Line[], path: string): Record<string, ScenarioLocale> {
  const locales: Record<string, ScenarioLocale> = {};

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];

    if (line.indent <= 0) {
      break;
    }

    if (line.indent !== 2 || line.value !== "") {
      continue;
    }

    const locale = line.key;
    const nextLocaleIndex = lines.findIndex(
      (candidate, candidateIndex) =>
        candidateIndex > index && candidate.indent === 2 && candidate.value === "",
    );
    const blockEnd = nextLocaleIndex === -1 ? lines.length : nextLocaleIndex;
    const block = lines.slice(index + 1, blockEnd);
    const input = scalarAt(block, 4, "input");
    const toolName = nestedScalarAt(block, [4, 6, 8], ["expect", "toolCall", "name"]);
    const toolArguments = nestedMapAt(block, [4, 6, 8], ["expect", "toolCall", "arguments"], 10);
    const forbiddenToolName = nestedScalarAt(block, [4, 6, 8], ["expect", "noToolCall", "name"]);

    if (!input) {
      throw new Error(`${path}: locale "${locale}" is missing "input"`);
    }

    if (!toolName) {
      throw new Error(`${path}: locale "${locale}" is missing "expect.toolCall.name"`);
    }

    locales[locale] = {
      input,
      expect: {
        toolCall: {
          name: toolName,
          ...(Object.keys(toolArguments).length > 0 ? { arguments: toolArguments } : {}),
        },
        ...(forbiddenToolName ? { noToolCall: { name: forbiddenToolName } } : {}),
      },
    };

    index = blockEnd - 1;
  }

  return locales;
}

function tokenize(source: string): Line[] {
  return source
    .split(/\r?\n/)
    .map((raw, index) => ({ raw, number: index + 1 }))
    .filter(({ raw }) => raw.trim() !== "" && !raw.trimStart().startsWith("#"))
    .map(({ raw, number }) => {
      const indent = raw.match(/^ */)?.[0].length ?? 0;
      const trimmed = raw.trim();
      const separator = trimmed.indexOf(":");

      if (separator === -1) {
        throw new Error(`scenario line ${number}: expected "key: value"`);
      }

      return {
        indent,
        key: trimmed.slice(0, separator).trim(),
        value: trimmed.slice(separator + 1).trim(),
        number,
      };
    });
}

function scalarAt(lines: Line[], indent: number, key: string): string | undefined {
  const line = lines.find((candidate) => candidate.indent === indent && candidate.key === key);
  return line && line.value !== "" ? parseScalar(line.value, line.number) : undefined;
}

function nestedScalarAt(lines: Line[], indents: number[], keys: string[]): string | undefined {
  let start = 0;

  for (let index = 0; index < keys.length; index += 1) {
    const lineIndex = lines.findIndex(
      (line, candidateIndex) =>
        candidateIndex >= start && line.indent === indents[index] && line.key === keys[index],
    );

    if (lineIndex === -1) {
      return undefined;
    }

    if (index === keys.length - 1) {
      const line = lines[lineIndex];
      return line.value !== "" ? parseScalar(line.value, line.number) : undefined;
    }

    start = lineIndex + 1;
  }

  return undefined;
}

function nestedMapAt(
  lines: Line[],
  indents: number[],
  keys: string[],
  childIndent: number,
): Record<string, string> {
  let start = 0;

  for (let index = 0; index < keys.length; index += 1) {
    const lineIndex = lines.findIndex(
      (line, candidateIndex) =>
        candidateIndex >= start && line.indent === indents[index] && line.key === keys[index],
    );

    if (lineIndex === -1) {
      return {};
    }

    start = lineIndex + 1;
  }

  const entries: Record<string, string> = {};

  for (let index = start; index < lines.length; index += 1) {
    const line = lines[index];

    if (line.indent < childIndent) {
      break;
    }

    if (line.indent === childIndent && line.value !== "") {
      entries[line.key] = parseScalar(line.value, line.number);
    }
  }

  return entries;
}

function parseScalar(value: string, lineNumber: number): string {
  if (value.startsWith('"') && value.endsWith('"')) {
    try {
      return JSON.parse(value);
    } catch {
      throw new Error(`scenario line ${lineNumber}: invalid double-quoted string`);
    }
  }

  if (value.startsWith("'") && value.endsWith("'")) {
    return value.slice(1, -1).replaceAll("''", "'");
  }

  return value;
}
