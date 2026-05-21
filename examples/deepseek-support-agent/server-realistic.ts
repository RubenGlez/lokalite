#!/usr/bin/env node
import { createServer } from "node:http";

const port = Number.parseInt(process.env.PORT ?? "3002", 10);
const host = "127.0.0.1";
const model = process.env.DEEPSEEK_MODEL ?? "deepseek-chat";
const apiUrl = "https://api.deepseek.com/chat/completions";

// Five realistic tools with similar-sounding descriptions.
// Correct answer for a duplicate-charge report is always create_refund_ticket.
// A model that only partially understands the input might pick:
//   - check_payment_status  (saw "charge" but missed "twice")
//   - request_account_review (billing issue but wrong action)
//   - escalate_to_human      (doesn't know what to do)
const tools = [
  {
    type: "function",
    function: {
      name: "create_refund_ticket",
      description:
        "Open a refund support ticket. Use when the customer has been incorrectly charged, overcharged, or billed twice for the same item.",
      parameters: {
        type: "object",
        properties: {
          reason: {
            type: "string",
            enum: ["duplicate_charge", "unauthorized_charge", "service_not_received", "other"],
            description: "The reason the refund is needed.",
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
      name: "check_payment_status",
      description:
        "Look up whether a specific outgoing payment went through successfully. Use only when the customer cannot find a payment they made and wants confirmation it was received.",
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "Brief description of the payment the customer is asking about.",
          },
        },
        required: ["query"],
      },
      strict: true,
    },
  },
  {
    type: "function",
    function: {
      name: "cancel_subscription",
      description:
        "Cancel the customer's active subscription immediately. Use only when the customer explicitly requests to cancel their subscription.",
      parameters: {
        type: "object",
        properties: {
          reason: {
            type: "string",
            description: "Why the customer wants to cancel.",
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
      name: "request_account_review",
      description:
        "Flag the account for a manual billing audit. Use for complex or recurring billing disputes that require deeper investigation.",
      parameters: {
        type: "object",
        properties: {
          notes: {
            type: "string",
            description: "Summary of the dispute for the review team.",
          },
        },
        required: ["notes"],
      },
      strict: true,
    },
  },
  {
    type: "function",
    function: {
      name: "escalate_to_human",
      description:
        "Transfer the conversation to a human support agent. Use only when the customer explicitly asks to speak with a person.",
      parameters: {
        type: "object",
        properties: {
          reason: {
            type: "string",
            description: "Why a human agent is needed.",
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
  console.log(`DeepSeek realistic agent listening on http://${host}:${port}/api/agent`);
  console.log(`Model: ${model}`);
});

async function callDeepSeek(locale: string, input: string): Promise<DeepSeekCompletion> {
  const response = await fetch(apiUrl, {
    method: "POST",
    headers: {
      authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "system",
          content: `You are a multilingual customer support agent. Use the available functions to handle the customer's request. Respond in locale ${locale}.`,
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
