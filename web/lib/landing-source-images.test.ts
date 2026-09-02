import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";

import { listedLandingSourceImages } from "./landing-source-images";

describe("listedLandingSourceImages", () => {
  const dir = join(process.cwd(), "public/landing/sources");
  const planted = join(dir, "__probe__.webp");

  afterEach(() => {
    rmSync(planted, { force: true });
  });

  it("ne liste que les extraits réellement déposés", () => {
    expect(listedLandingSourceImages()).not.toContain("__probe__");

    mkdirSync(dir, { recursive: true });
    writeFileSync(planted, "webp");

    expect(listedLandingSourceImages()).toContain("__probe__");
  });
});
