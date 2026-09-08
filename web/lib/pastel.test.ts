import { describe, expect, it } from "vitest";

import { TILE_PASTELS } from "@micabo/core";

import { APPEARANCE_SHADER, APPEARANCE_THEME_COLOR } from "./appearance";
import {
  PASTEL_BLUSH,
  PASTEL_MINT,
  PASTEL_POWDER,
  PASTEL_SHADER,
  PASTEL_THEME_COLOR,
  WEBSITE_PASTEL,
} from "./pastel";

describe("le pastel du site", () => {
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

  it("teinte le papier et les lueurs tant que l'interrupteur est à true", () => {
    expect(APPEARANCE_THEME_COLOR).toEqual(PASTEL_THEME_COLOR);
    expect(APPEARANCE_SHADER).toEqual(PASTEL_SHADER);
    expect(APPEARANCE_SHADER.day.grain).toEqual(
      expect.arrayContaining([PASTEL_BLUSH, PASTEL_MINT, PASTEL_POWDER]),
    );
  });
});
