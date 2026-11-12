import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

import { ART_TARGET, POSES, VIEWBOX, artModule, poses } from "../scripts/sync-mika.mjs";
import { MIKA_POSES } from "../components/mika/mika-art";
import { MIKA_MOODS } from "../components/mika/moods";

/**
 * **Mika sur le site est Mika de l'app** (direction artistique V3.3).
 *
 * Le dessin est tiré de `design/mika-v3/mika.js` ; une copie non surveillée dérive. Si ce
 * test tombe : `node web/scripts/sync-mika.mjs`.
 */
describe("Mika", () => {
  it("le dessin copié est celui du design", () => {
    expect(readFileSync(ART_TARGET, "utf8")).toBe(artModule());
  });

  it("a une pose pour chacune des huit humeurs de l'app", () => {
    expect(MIKA_MOODS).toEqual(["idle", "wave", "happy", "sleep", "think", "surprise", "celebrate", "sad"]);
    for (const mood of MIKA_MOODS) {
      expect(Object.keys(POSES), mood).toContain(mood);
      expect(MIKA_POSES[mood], mood).toBeTruthy();
    }
  });

  it("son bleu suit le thème, et rien d'autre n'est embarqué", () => {
    expect(VIEWBOX).toBe("-10 -30 420 420");
    for (const [name, body] of Object.entries(poses())) {
      expect(body, name).toContain("var(--mika-body");
      expect(body, name).not.toContain("<script");
      expect(body, name).not.toContain("<style");
      expect(body, name).not.toMatch(/__MIKA_/);
    }
  });

  it("les poses diffèrent : la joie n'est pas le repos", () => {
    const art = poses();
    expect(art.happy).not.toBe(art.idle);
    expect(art.sleep).not.toBe(art.idle);
  });
});
