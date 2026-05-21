import type { TargetResponse } from "./types.ts";

export type ExecuteTargetInput = {
  target: string;
  scenarioId: string;
  locale: string;
  input: string;
};

export type ExecuteTargetResult =
  | { ok: true; response: TargetResponse }
  | { ok: false; detail: string };

export async function executeHttpTarget(input: ExecuteTargetInput): Promise<ExecuteTargetResult> {
  let response: Response;

  try {
    response = await fetch(input.target, {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        locale: input.locale,
        input: input.input,
        scenarioId: input.scenarioId,
      }),
    });
  } catch (error) {
    return { ok: false, detail: error instanceof Error ? error.message : "network error" };
  }

  if (!response.ok) {
    return { ok: false, detail: `HTTP ${response.status} from target` };
  }

  let body: unknown;

  try {
    body = await response.json();
  } catch {
    return { ok: false, detail: "invalid JSON response" };
  }

  return { ok: true, response: normalizeTargetResponse(body) };
}

function normalizeTargetResponse(body: unknown): TargetResponse {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return {
      text: "",
      toolCalls: [],
      structured: null,
    };
  }

  const record = body as Record<string, unknown>;

  return {
    text: typeof record.text === "string" ? record.text : "",
    toolCalls: normalizeToolCalls(record.toolCalls),
    structured: "structured" in record ? record.structured : null,
  };
}

function normalizeToolCalls(value: unknown): TargetResponse["toolCalls"] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object")
    .filter((item) => typeof item.name === "string")
    .map((item) => ({
      name: item.name as string,
      arguments: item.arguments,
    }));
}
