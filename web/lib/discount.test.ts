import { describe, expect, it } from "vitest";

import { discount } from "@micabo/core";

import { shouldOpenDiscount, shouldShowDiscountBadge } from "./discount";

const HOUR = 3_600_000;

describe("shouldOpenDiscount", () => {
  const base = { isPaid: false, courseCount: 1, seen: false, startedAt: null, now: 0 };

  it("s'ouvre au premier cours, une seule fois par fenêtre", () => {
    expect(shouldOpenDiscount(base)).toBe(true);
    expect(shouldOpenDiscount({ ...base, seen: true, startedAt: 0, now: HOUR })).toBe(false);
  });

  it("se représente quand « déjà vue » n'a jamais démarré de décompte", () => {
    // L'état bâtard d'une version qui marquait la carte vue sans poser son instant :
    // ni pop-up, ni pastille, et le tarif réduit devenait introuvable.
    expect(shouldOpenDiscount({ ...base, seen: true, startedAt: null })).toBe(true);
  });

  it("ne s'ouvre pas sans cours importé", () => {
    expect(shouldOpenDiscount({ ...base, courseCount: 0 })).toBe(false);
  });

  it("ne vend rien à un abonné", () => {
    expect(shouldOpenDiscount({ ...base, isPaid: true })).toBe(false);
    expect(shouldOpenDiscount({ ...base, isPaid: true, debug: false })).toBe(false);
  });

  it("se retire à la fin de la fenêtre, puis revient après son repos", () => {
    // Fenêtre en cours : la carte peut encore s'ouvrir tant qu'on ne l'a pas vue.
    expect(shouldOpenDiscount({ ...base, startedAt: 0, now: 23 * HOUR })).toBe(true);
    // Fenêtre finie : l'offre se tait pendant le repos.
    expect(shouldOpenDiscount({ ...base, startedAt: 0, now: 25 * HOUR })).toBe(false);
    expect(shouldOpenDiscount({ ...base, startedAt: 0, now: 71 * HOUR })).toBe(false);
    // Repos passé : elle revient, vue ou pas vue.
    expect(shouldOpenDiscount({ ...base, startedAt: 0, now: 72 * HOUR })).toBe(true);
    expect(shouldOpenDiscount({ ...base, seen: true, startedAt: 0, now: 72 * HOUR })).toBe(true);
    // Un abonné n'en revoit jamais, quel que soit le temps passé.
    expect(shouldOpenDiscount({ ...base, isPaid: true, startedAt: 0, now: 72 * HOUR })).toBe(false);
  });
});

describe("shouldShowDiscountBadge", () => {
  const base = { isPaid: false, courseCount: 1, seen: true, startedAt: 0, now: HOUR };

  it("prend le relais quand la pop-up s'est refermée", () => {
    expect(shouldShowDiscountBadge(base)).toBe(true);
    expect(shouldShowDiscountBadge({ ...base, seen: false })).toBe(false);
  });

  it("disparaît au bout des vingt-quatre heures", () => {
    expect(shouldShowDiscountBadge({ ...base, now: 24 * HOUR - 1000 })).toBe(true);
    expect(shouldShowDiscountBadge({ ...base, now: 24 * HOUR })).toBe(false);
  });

  it("n'apparaît jamais pour un abonné", () => {
    expect(shouldShowDiscountBadge({ ...base, isPaid: true })).toBe(false);
  });
});

describe("le repos", () => {
  it("sépare deux fenêtres de quarante-huit heures", () => {
    expect(discount.restSeconds).toBe(48 * 3600);
    expect(discount.hasRested(0, 24 * HOUR)).toBe(false);
    expect(discount.hasRested(0, 71 * HOUR)).toBe(false);
    expect(discount.hasRested(0, 72 * HOUR)).toBe(true);
  });
});

describe("la fenêtre, comptée sans être montrée", () => {
  it("court sur vingt-quatre heures depuis l'ouverture du cadeau", () => {
    expect(discount.windowSeconds).toBe(24 * 3600);
    expect(discount.windowRemaining(0, 0)).toBe(86_400);
    expect(discount.windowRemaining(0, 600_000)).toBe(85_800);

    // Deux heures plus tard, l'offre est toujours achetable.
    expect(discount.windowRemaining(0, 2 * HOUR)).toBe(79_200);
    expect(discount.isLive(0, 2 * HOUR)).toBe(true);

    // Au bout des vingt-quatre heures, elle se retire.
    expect(discount.windowRemaining(0, 24 * HOUR)).toBe(0);
    expect(discount.isLive(0, 24 * HOUR)).toBe(false);
  });

  it("n'invente jamais du temps quand l'horloge locale est en avance", () => {
    expect(discount.windowRemaining(1000, 0)).toBe(86_400);
  });

  it("ne s'écrit nulle part : plus un seul formateur de décompte", () => {
    // C'est le garde de la minuterie invisible. Réexporter un « 23:14:07 » suffirait à
    // le faire réapparaître dans un écran, et l'offre se remettrait à presser.
    for (const gone of [
      "countdown",
      "preciseCountdown",
      "countdownLabel",
      "urgencySeconds",
      "urgencyRemaining",
      "urgencyMillisRemaining",
      "windowMillisRemaining",
      "remainingMillis",
    ]) {
      expect(discount).not.toHaveProperty(gone);
    }
  });
});
