import { describe, expect, it } from "vitest";

import { HELD_PERCENT_CAP, heldPercentAt } from "./held-percent";

describe("heldPercentAt", () => {
  it("commence tout de suite, plafonne avant 100", () => {
    expect(heldPercentAt(0, 10_000)).toBe(1);
    expect(heldPercentAt(10_000, 10_000)).toBe(HELD_PERCENT_CAP);
    expect(heldPercentAt(30_000, 10_000)).toBe(HELD_PERCENT_CAP);
  });

  it("avance plus vite au début qu'à la fin", () => {
    const early = heldPercentAt(2_000, 10_000);
    const late = heldPercentAt(8_000, 10_000);
    expect(early).toBeGreaterThan(10);
    expect(late).toBeGreaterThan(early);
    expect(late).toBeLessThan(HELD_PERCENT_CAP);
  });
});
