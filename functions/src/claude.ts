import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";

let client: Anthropic | undefined;

function anthropic(): Anthropic {
  // The key comes from the ANTHROPIC_API_KEY function secret; it is never in the app or the zip.
  client ??= new Anthropic();
  return client;
}

export type Content = Anthropic.Messages.MessageParam["content"];

/**
 * Forced tool call with a strict schema, validated with zod, one retry on failure. Never parses free text.
 */
export async function structured<S extends z.ZodType>(opts: {
  model: string;
  system: string;
  content: Content;
  schema: S;
  toolName: string;
  maxTokens?: number;
}): Promise<z.infer<S>> {
  const inputSchema = z.toJSONSchema(opts.schema) as Anthropic.Messages.Tool.InputSchema;
  let lastError = "";

  for (let attempt = 0; attempt < 2; attempt++) {
    const retryNote = attempt === 0 ? "" : `\n\nYour previous output failed validation: ${lastError}. Fix it.`;
    const res = await anthropic().messages.create({
      model: opts.model,
      max_tokens: opts.maxTokens ?? 4096,
      system: opts.system + retryNote,
      messages: [{ role: "user", content: opts.content }],
      tools: [{ name: opts.toolName, description: "Return the result.", input_schema: inputSchema }],
      tool_choice: { type: "tool", name: opts.toolName },
    });
    const block = res.content.find((b) => b.type === "tool_use");
    const parsed = block && block.type === "tool_use" ? opts.schema.safeParse(block.input) : undefined;
    if (parsed?.success) return parsed.data;
    lastError = parsed ? parsed.error.message : "no tool call returned";
  }
  throw new Error(`Model output failed validation twice: ${lastError}`);
}
