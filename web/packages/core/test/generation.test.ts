import { describe, expect, it } from "vitest";

import {
  BLOCK_BOUNDS,
  DEFAULT_QUOTA,
  DEFAULT_SHEET_LENGTH,
  DEFAULT_VISIBILITY,
  PER_FORMAT_RANGE,
  SHEET_LENGTHS,
  TOTAL_RANGE,
  clampBlocks,
  clampQuota,
  defaultBlocks,
  isAtCap,
  isShared,
  lengthContaining,
  quotaTotal,
  readingHint,
} from "../src/index";

/**
 * Les invariants portés depuis l'app, et c'est tout l'intérêt de les écrire ici : le quota et la
 * longueur partent à la **même fonction Edge** depuis les deux clients. Deux plafonds différents,
 * et la même demande donnerait deux paquets selon l'appareil.
 */

describe("le quota par format", () => {
  it("part sur douze cartes en trois parts", () => {
    expect(quotaTotal(DEFAULT_QUOTA)).toBe(12);
    expect(DEFAULT_QUOTA).toEqual({ basic: 6, cloze: 3, choice: 3 });
  });

  it("retombe sur le recto verso quand on ne demande rien", () => {
    // Zéro carte n'est pas une commande : plutôt que de dépenser un appel pour rien, on rend le
    // seul format qui marche sur n'importe quel cours.
    expect(clampQuota({ basic: 0, cloze: 0, choice: 0 })).toEqual({
      basic: TOTAL_RANGE.min,
      cloze: 0,
      choice: 0,
    });
  });

  it("borne chaque format avant de regarder le total", () => {
    // L'ordre compte, et c'est celui de l'app : 40 recto verso deviennent 20, ce qui ramène le
    // total à 24 — sous le plafond. Rien de plus n'est rogné.
    expect(clampQuota({ basic: 40, cloze: 2, choice: 2 })).toEqual({
      basic: PER_FORMAT_RANGE.max,
      cloze: 2,
      choice: 2,
    });
  });

  it("rogne le format le plus nombreux d'abord", () => {
    // La petite commande est respectée à la carte près : ce sont les recto verso qui tombent,
    // pas les deux QCM qu'on a pris la peine de demander.
    const clamped = clampQuota({ basic: 20, cloze: 20, choice: 2 });
    expect(quotaTotal(clamped)).toBe(TOTAL_RANGE.max);
    expect(clamped.choice).toBe(2);
  });

  it("complète en recto verso sous le plancher", () => {
    expect(clampQuota({ basic: 0, cloze: 1, choice: 0 })).toEqual({
      basic: 2,
      cloze: 1,
      choice: 0,
    });
  });

  it("borne chaque format à vingt", () => {
    const clamped = clampQuota({ basic: 99, cloze: 99, choice: 99 });
    expect(quotaTotal(clamped)).toBe(TOTAL_RANGE.max);
  });

  it("éteint le bouton plus au plafond", () => {
    expect(isAtCap({ basic: 10, cloze: 10, choice: 10 })).toBe(true);
    expect(isAtCap(DEFAULT_QUOTA)).toBe(false);
  });
});

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
  it("part publique, comme l'app et comme la base", () => {
    expect(DEFAULT_VISIBILITY).toBe("public");
  });

  it("ne partage que ce qui n'est pas privé", () => {
    expect(isShared("public")).toBe(true);
    expect(isShared("friends")).toBe(true);
    expect(isShared("private")).toBe(false);
  });
});
