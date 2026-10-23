import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import { ART_TARGET, CSS_TARGET, artModule, cssCopy, extractArt } from "../scripts/sync-mika.mjs";
import { MIKA_MOODS } from "../components/mika/moods";

/**
 * **Mika sur le site est Mika du design.**
 *
 * Le dessin et ses humeurs sont copiés depuis `design/mika/` ; une copie non surveillée
 * dérive. Si ce test tombe : `node web/scripts/sync-mika.mjs`.
 */
describe("Mika", () => {
  it("le dessin copié est celui du design", () => {
    expect(readFileSync(ART_TARGET, "utf8")).toBe(artModule());
  });

  it("la feuille de style copiée est celle du design", () => {
    expect(readFileSync(CSS_TARGET, "utf8")).toBe(cssCopy());
  });

  it("le dessin garde ses calques et perd sa feuille embarquée", () => {
    const art = extractArt();
    expect(art.viewBox).toMatch(/^-?\d+ -?\d+ \d+ \d+$/);
    expect(art.body).not.toContain("<style");
    for (const layer of ["char", "squash", "face", "eye", "curl", "tail", "wing", "fx-think", "fx-confetti", "tear"]) {
      expect(art.body, layer).toMatch(new RegExp(`class="[^"]*\\b${layer}\\b`));
    }
  });

  it("connaît les huit humeurs de l'app, et le CSS les anime toutes sauf le repos", () => {
    expect(MIKA_MOODS).toEqual(["idle", "wave", "happy", "sleep", "think", "surprise", "celebrate", "sad"]);
    const css = cssCopy();
    for (const mood of MIKA_MOODS.filter((name) => name !== "idle")) {
      expect(css, mood).toContain(`.mico.s-${mood}`);
    }
    expect(css).toContain("prefers-reduced-motion");
  });
});
