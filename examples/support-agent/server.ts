#!/usr/bin/env node
import { createServer } from "node:http";

const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const host = "127.0.0.1";

const server = createServer(async (request, response) => {
  if (request.method !== "POST" || request.url !== "/api/agent") {
    response.writeHead(404, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: "not found" }));
    return;
  }

  const body = await readJson(request);

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    response.writeHead(400, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: "expected JSON object" }));
    return;
  }

  const payload = body as Record<string, unknown>;
  const locale = typeof payload.locale === "string" ? payload.locale : "en";

  response.writeHead(200, { "content-type": "application/json" });

  if (locale === "fr") {
    response.end(
      JSON.stringify({
        text: "Je peux vous aider avec ce remboursement.",
        toolCalls: [],
        structured: null,
      }),
    );
    return;
  }

  response.end(
    JSON.stringify({
      text: locale === "es" ? "Claro, puedo ayudarte con eso." : "I can help with that refund.",
      toolCalls: [
        {
          name: "create_refund_ticket",
          arguments: {
            reason: "duplicate_charge",
          },
        },
      ],
      structured: {
        status: "needs_refund_ticket",
      },
    }),
  );
});

server.listen(port, host, () => {
  console.log(`Example support agent listening on http://${host}:${port}/api/agent`);
});

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
