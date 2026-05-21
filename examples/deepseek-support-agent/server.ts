#!/usr/bin/env node
import { createServer } from "node:http";

const port = Number.parseInt(process.env.PORT ?? "3001", 10);
const host = "127.0.0.1";
const model = process.env.DEEPSEEK_MODEL ?? "deepseek-v4-flash";
const apiUrl = "https://api.deepseek.com/chat/completions";

const tools = [
  {
    type: "function",
    function: {
      name: "create_refund_ticket",
      description: "Create a support ticket when the user requests a refund for a duplicate charge.",
      parameters: {
        type: "object",
        properties: {
          reason: {
            type: "string",
            enum: ["duplicate_charge", "other"],
            description: "The reason the refund ticket is needed.",
          },
        },
        required: ["reason"],
      },
      strict: true,
    },
  },
  {
    type: "function",
    function: {
      name: "escalate_to_human",
      description: "Escalate only when the user explicitly asks for a human agent.",
      parameters: {
        type: "object",
        properties: {
          reason: {
            type: "string",
            description: "Why a human escalation is needed.",
          },
        },
        required: ["reason"],
      },
      strict: true,
    },
  },
];

const server = createServer(async (request, response) => {
  if (request.method !== "POST" || request.url !== "/api/agent") {
    sendJson(response, 404, { error: "not found" });
    return;
  }

  if (!process.env.DEEPSEEK_API_KEY) {
    sendJson(response, 500, { error: "DEEPSEEK_API_KEY is required" });
    return;
  }

  const body = await readJson(request);

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    sendJson(response, 400, { error: "expected JSON object" });
    return;
  }

  const payload = body as Record<string, unknown>;
  const locale = typeof payload.locale === "string" ? payload.locale : "en";
  const input = typeof payload.input === "string" ? payload.input : "";

  try {
    const completion = await callDeepSeek(locale, input);
    const message = completion.choices?.[0]?.message ?? {};

    sendJson(response, 200, {
      text: typeof message.content === "string" ? message.content : "",
      toolCalls: normalizeToolCalls(message.tool_calls),
      structured: {
        model,
        usage: completion.usage ?? null,
        finishReason: completion.choices?.[0]?.finish_reason ?? null,
      },
    });
  } catch (error) {
    sendJson(response, 502, {
      error: error instanceof Error ? error.message : "DeepSeek request failed",
    });
  }
});

server.listen(port, host, () => {
  console.log(`DeepSeek support agent listening on http://${host}:${port}/api/agent`);
  console.log(`Model: ${model}`);
});

async function callDeepSeek(locale: string, input: string): Promise<DeepSeekCompletion> {
  const response = await fetch(apiUrl, {
    method: "POST",
    headers: {
      "authorization": `Bearer ${process.env.DEEPSEEK_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content: [
            "You are a multilingual support-routing agent.",
            "If the user reports a duplicate charge or asks for a refund for being charged twice, call create_refund_ticket with reason duplicate_charge.",
            "Do not call escalate_to_human unless the user explicitly asks for a human agent.",
            `Respond naturally in locale ${locale}.`,
          ].join(" "),
        },
        {
          role: "user",
          content: input,
        },
      ],
      tools,
      tool_choice: "auto",
      thinking: { type: "disabled" },
      temperature: 0,
      stream: false,
    }),
  });

  const text = await response.text();

  if (!response.ok) {
    throw new Error(`DeepSeek HTTP ${response.status}: ${text}`);
  }

  return JSON.parse(text) as DeepSeekCompletion;
}

function normalizeToolCalls(value: unknown): Array<{ name: string; arguments: unknown }> {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item): item is DeepSeekToolCall => Boolean(item) && typeof item === "object")
    .filter((item) => item.type === "function" && typeof item.function?.name === "string")
    .map((item) => ({
      name: item.function.name,
      arguments: parseToolArguments(item.function.arguments),
    }));
}

function parseToolArguments(value: unknown): unknown {
  if (typeof value !== "string") {
    return {};
  }

  try {
    return JSON.parse(value);
  } catch {
    return {};
  }
}

function sendJson(
  response: import("node:http").ServerResponse,
  status: number,
  body: unknown,
): void {
  response.writeHead(status, { "content-type": "application/json" });
  response.end(JSON.stringify(body));
}

async function readJson(request: import("node:http").IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];

  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return null;
  }

  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    return null;
  }
}

type DeepSeekCompletion = {
  choices?: Array<{
    finish_reason?: string;
    message?: {
      content?: string | null;
      tool_calls?: unknown;
    };
  }>;
  usage?: unknown;
};

type DeepSeekToolCall = {
  type?: string;
  function?: {
    name?: string;
    arguments?: string;
  };
};
