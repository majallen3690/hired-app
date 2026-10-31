import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { z } from "zod";

import { structured } from "./claude";
import { MAX_RESUME_BYTES, MODELS, REGION } from "./config";
import { BulletRewrites, ParsedResume, inventsNumbers } from "./schemas";

initializeApp();
const anthropicKey = defineSecret("ANTHROPIC_API_KEY");
const opts = { region: REGION, secrets: [anthropicKey], timeoutSeconds: 120 };

function requireUid(auth: { uid: string } | undefined): string {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return auth.uid;
}

export const parseResume = onCall(opts, async (req) => {
  const uid = requireUid(req.auth);
  const { storagePath } = z.object({ storagePath: z.string() }).parse(req.data);
  // Each user may only parse files inside their own folder.
  if (!storagePath.startsWith(`users/${uid}/`)) throw new HttpsError("permission-denied", "Not your file.");

  const [bytes] = await getStorage().bucket().file(storagePath).download();
  if (bytes.length > MAX_RESUME_BYTES) throw new HttpsError("invalid-argument", "PDF is larger than 8 MB.");

  return structured({
    model: MODELS.deep,
    system:
      "Extract the resume into the schema exactly as written. Copy bullets verbatim. Use null for anything absent. Never infer or invent.",
    content: [
      { type: "document", source: { type: "base64", media_type: "application/pdf", data: bytes.toString("base64") } },
      { type: "text", text: "Parse this resume." },
    ],
    schema: ParsedResume,
    toolName: "return_resume",
    maxTokens: 6000,
  });
});

export const rewriteBullet = onCall(opts, async (req) => {
  requireUid(req.auth);
  const { bullet, jd } = z.object({ bullet: z.string().min(5), jd: z.string().min(20) }).parse(req.data);

  const run = () =>
    structured({
      model: MODELS.fast,
      system:
        "Rewrite the resume bullet three ways. Each: strong action verb, a quantified result, the impact, and relevant keywords from the JD. " +
        "NEVER invent a number. Where a metric is missing write a bracket placeholder like [X%] or [N users] and list it in placeholders.",
      content: `Bullet:\n${bullet}\n\nJob description:\n${jd}`,
      schema: BulletRewrites,
      toolName: "return_rewrites",
    });

  // The "never invent metrics" rule is enforced in code, not only in the prompt.
  let out = await run();
  if (out.rewrites.some((r) => inventsNumbers(bullet, r.text))) out = await run();
  if (out.rewrites.some((r) => inventsNumbers(bullet, r.text))) {
    throw new HttpsError("internal", "Could not produce rewrites without invented numbers. Try again.");
  }
  return out;
});
