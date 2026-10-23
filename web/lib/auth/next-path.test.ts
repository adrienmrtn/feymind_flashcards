import { describe, expect, it } from "vitest";

import { safeAppPath } from "./next-path";

describe("safeAppPath", () => {
  it("garde une page de l'app, et l'offre qui suit le compte", () => {
    expect(safeAppPath("/app")).toBe("/app");
    expect(safeAppPath("/app/lecons/42?reviser=1")).toBe("/app/lecons/42?reviser=1");
    expect(safeAppPath("/commencer/offre")).toBe("/commencer/offre");
    expect(safeAppPath("/commencer/offre?x=1")).toBe("/commencer/offre?x=1");
  });

  it("refuse tout ce qui peut se relire comme un autre site", () => {
    // `\` devient `/` dans le navigateur : `/\evil.example` est `//evil.example`.
    expect(safeAppPath("/\\evil.example")).toBe("/app");
    expect(safeAppPath("//evil.example")).toBe("/app");
    expect(safeAppPath("/app@evil.example")).toBe("/app");
    expect(safeAppPath("/\t/evil.example")).toBe("/app");
    expect(safeAppPath("https://evil.example/app")).toBe("/app");
    expect(safeAppPath("/apple")).toBe("/app");
    expect(safeAppPath("/commencer/compte")).toBe("/app");
  });

  it("retombe sur la valeur demandée quand il n'y a rien à garder", () => {
    expect(safeAppPath(null, "/commencer/offre")).toBe("/commencer/offre");
    expect(safeAppPath("", "/commencer/offre")).toBe("/commencer/offre");
    expect(safeAppPath("/\\evil.example", "/commencer/offre")).toBe("/commencer/offre");
  });
});
