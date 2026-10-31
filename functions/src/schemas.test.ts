import { describe, expect, it } from "vitest";
import { BulletRewrites, ParsedResume, inventsNumbers } from "./schemas";

describe("inventsNumbers", () => {
  it("allows numbers from the original bullet", () => {
    expect(inventsNumbers("Cut load time by 40%", "Reduced page load time by 40% for [N users]")).toBe(false);
  });
  it("allows bracket placeholders", () => {
    expect(
      inventsNumbers("Built an attendance app", "Built an attendance app used by [X] students, cutting roll-call time [Y%]"),
    ).toBe(false);
  });
  it("flags a made-up metric", () => {
    expect(inventsNumbers("Built an attendance app", "Built an attendance app serving 500 students")).toBe(true);
  });
});

describe("schemas", () => {
  it("requires exactly three rewrites", () => {
    const one = { text: "Led a team of [N] engineers", placeholders: ["N"], jdKeywordsUsed: [] };
    expect(BulletRewrites.safeParse({ rewrites: [one] }).success).toBe(false);
    expect(BulletRewrites.safeParse({ rewrites: [one, one, one] }).success).toBe(true);
  });
  it("rejects a resume without contact", () => {
    expect(ParsedResume.safeParse({ skills: [] }).success).toBe(false);
  });
});
