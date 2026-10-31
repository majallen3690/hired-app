import { z } from "zod";

export const ParsedResume = z.object({
  contact: z.object({
    name: z.string(),
    email: z.string().nullable(),
    phone: z.string().nullable(),
    links: z.array(z.string()),
  }),
  education: z.array(
    z.object({
      institution: z.string(),
      degree: z.string(),
      period: z.string().nullable(),
      score: z.string().nullable(),
    }),
  ),
  skills: z.array(z.string()),
  experience: z.array(
    z.object({
      company: z.string(),
      role: z.string(),
      period: z.string().nullable(),
      bullets: z.array(z.string()),
    }),
  ),
  projects: z.array(
    z.object({
      name: z.string(),
      tech: z.array(z.string()),
      bullets: z.array(z.string()),
    }),
  ),
  certifications: z.array(z.string()),
});
export type ParsedResume = z.infer<typeof ParsedResume>;

const Rewrite = z.object({
  text: z.string().min(10),
  // Placeholders such as [X%] the user must fill; never an invented number.
  placeholders: z.array(z.string()),
  jdKeywordsUsed: z.array(z.string()),
});

export const BulletRewrites = z.object({
  rewrites: z.array(Rewrite).length(3),
});
export type BulletRewrites = z.infer<typeof BulletRewrites>;

/** A rewrite must not contain a number that was not in the original bullet or inside a bracket placeholder. */
export function inventsNumbers(original: string, rewrite: string): boolean {
  const known = new Set(original.match(/\d+(?:\.\d+)?/g) ?? []);
  const withoutPlaceholders = rewrite.replace(/\[[^\]]*\]/g, "");
  const found = withoutPlaceholders.match(/\d+(?:\.\d+)?/g) ?? [];
  return found.some((n) => !known.has(n));
}
