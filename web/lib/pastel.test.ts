import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { TILE_PASTELS } from "@micabo/core";

import { APPEARANCE_SHADER, APPEARANCE_THEME_COLOR } from "./appearance";
import {
  PASTEL_BLUSH,
  PASTEL_MINT,
  PASTEL_POWDER,
  PASTEL_THEME_COLOR,
  WEBSITE_PASTEL,
} from "./pastel";

const here = dirname(fileURLToPath(import.meta.url));
const rootLayout = readFileSync(resolve(here, "../app/layout.tsx"), "utf8");
const appChrome = readFileSync(resolve(here, "../components/app/AppChrome.tsx"), "utf8");

describe("le pastel de l'app", () => {
  it("s'allume et s'éteint depuis un seul interrupteur", () => {
    expect(WEBSITE_PASTEL).toBe(true);
  });

  it("reprend les pastels des tuiles, pas une crème générique", () => {
    expect(TILE_PASTELS).toContain(PASTEL_MINT);
    expect(TILE_PASTELS).toContain(PASTEL_BLUSH);
    expect(TILE_PASTELS).toContain(PASTEL_POWDER);
    expect(PASTEL_THEME_COLOR.day).not.toBe("#f6f7f9");
    expect(PASTEL_THEME_COLOR.day).not.toMatch(/^#f4f1ea$/i);
  });

  it("ne teinte pas la landing ni l'onboarding", () => {
    expect(APPEARANCE_THEME_COLOR.day).toBe("#f6f7f9");
    expect(APPEARANCE_SHADER.day.back).toBe("#f6f7f9");
    expect(rootLayout).not.toContain("data-pastel");
    expect(rootLayout).not.toContain("PastelWash");
  });

  it("ne vit que dans le chrome de /app", () => {
    expect(appChrome).toContain('data-pastel');
    expect(appChrome).toContain("PastelWash");
    expect(appChrome).toContain("WEBSITE_PASTEL");
  });
});
