import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";

import { listedLandingSourceImages } from "./landing-source-images";

describe("listedLandingSourceImages", () => {
  const dir = join(process.cwd(), "public/landing/sources");
  const planted = join(dir, "notes-manuscrites.webp");

  afterEach(() => {
    rmSync(planted, { force: true });
  });

  it("ne liste que les extraits réellement déposés", () => {
    expect(listedLandingSourceImages()).not.toContain("notes-manuscrites");

    mkdirSync(dir, { recursive: true });
    writeFileSync(planted, "webp");

    expect(listedLandingSourceImages()).toEqual(["notes-manuscrites"]);
  });
});
