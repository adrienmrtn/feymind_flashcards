import { describe, expect, it } from "vitest";

import {
  BLOCK_BOUNDS,
  DEFAULT_SHEET_LENGTH,
  DEFAULT_VISIBILITY,
  SHEET_LENGTHS,
  asChoosableVisibility,
  choosableVisibilities,
  clampBlocks,
  defaultBlocks,
  isChoosableVisibility,
  isShared,
  lengthContaining,
  readingHint,
} from "../src/index";

/**
 * Les invariants portés depuis l'app, et c'est tout l'intérêt de les écrire ici : le quota et la
 * longueur partent à la **même fonction Edge** depuis les deux clients. Deux plafonds différents,
 * et la même demande donnerait deux paquets selon l'appareil.
 */

describe("la longueur de fiche", () => {
  it("nomme chaque nombre de blocs, sur toute la plage", () => {
    for (let blocks = BLOCK_BOUNDS.min; blocks <= BLOCK_BOUNDS.max; blocks += 1) {
      expect(SHEET_LENGTHS).toContain(lengthContaining(blocks));
    }
  });

  it("place le défaut de chaque format dans sa propre plage", () => {
    // C'est ce qui garantit qu'un aller-retour format → blocs → format ne dérive pas.
    for (const length of SHEET_LENGTHS) {
      expect(lengthContaining(defaultBlocks(length))).toBe(length);
    }
  });

  it("bascule aux frontières de l'app", () => {
    expect(lengthContaining(13)).toBe("brief");
    expect(lengthContaining(14)).toBe("standard");
    expect(lengthContaining(23)).toBe("standard");
    expect(lengthContaining(24)).toBe("deep");
  });

  it("garde le curseur dans ses bornes", () => {
    expect(clampBlocks(1)).toBe(BLOCK_BOUNDS.min);
    expect(clampBlocks(999)).toBe(BLOCK_BOUNDS.max);
    expect(clampBlocks(18)).toBe(18);
  });

  it("annonce une durée de lecture jamais nulle", () => {
    expect(readingHint(BLOCK_BOUNDS.min)).toBe("≈ 2 min");
    expect(readingHint(1)).toBe("≈ 1 min");
  });

  it("part sur la fiche équilibrée", () => {
    expect(DEFAULT_SHEET_LENGTH).toBe("standard");
  });
});

describe("la visibilité d'un cours", () => {
  it("part privée : on ne dépose plus un cours dans le catalogue public", () => {
    expect(DEFAULT_VISIBILITY).toBe("private");
  });

  it("ne propose plus le dépôt public", () => {
    expect(isChoosableVisibility("public")).toBe(false);
    expect(isChoosableVisibility("friends")).toBe(true);
    expect(isChoosableVisibility("private")).toBe(true);
    expect(asChoosableVisibility("public")).toBe("private");
    expect(choosableVisibilities().map((item) => item.value)).toEqual(["friends", "private"]);
    expect(choosableVisibilities("public").map((item) => item.value)).toEqual([
      "public",
      "friends",
      "private",
    ]);
  });

  it("ne partage que ce qui n'est pas privé", () => {
    expect(isShared("public")).toBe(true);
    expect(isShared("friends")).toBe(true);
    expect(isShared("private")).toBe(false);
  });
});
