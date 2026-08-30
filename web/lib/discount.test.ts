import { describe, expect, it } from "vitest";

import { discount } from "@micabo/core";

import { shouldOpenDiscount, shouldShowDiscountBadge } from "./discount";

const HOUR = 3_600_000;

describe("shouldOpenDiscount", () => {
  const base = { isPaid: false, courseCount: 1, seen: false, startedAt: null, now: 0 };

  it("s'ouvre au premier cours, une seule fois", () => {
    expect(shouldOpenDiscount(base)).toBe(true);
    expect(shouldOpenDiscount({ ...base, seen: true })).toBe(false);
  });

  it("ne s'ouvre pas sans cours importé", () => {
    expect(shouldOpenDiscount({ ...base, courseCount: 0 })).toBe(false);
  });

  it("ne vend rien à un abonné", () => {
    expect(shouldOpenDiscount({ ...base, isPaid: true })).toBe(false);
    expect(shouldOpenDiscount({ ...base, isPaid: true, debug: false })).toBe(false);
  });

  it("laisse tomber une offre commencée il y a plus de vingt-quatre heures", () => {
    expect(shouldOpenDiscount({ ...base, startedAt: 0, now: 23 * HOUR })).toBe(true);
    expect(shouldOpenDiscount({ ...base, startedAt: 0, now: 25 * HOUR })).toBe(false);
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

describe("les deux minuteries", () => {
  it("comptent depuis le même instant : une heure sur le paywall, un jour sur la pastille", () => {
    expect(discount.urgencyRemaining(0, 0)).toBe(3600);
    expect(discount.windowRemaining(0, 0)).toBe(86_400);

    // Au bout de dix minutes, le paywall en a perdu dix et la pastille aussi.
    expect(discount.urgencyRemaining(0, 600_000)).toBe(3000);
    expect(discount.windowRemaining(0, 600_000)).toBe(85_800);

    // La minuterie du paywall s'arrête à zéro ; l'offre, elle, court encore.
    expect(discount.urgencyRemaining(0, 2 * HOUR)).toBe(0);
    expect(discount.isLive(0, 2 * HOUR)).toBe(true);
  });

  it("n'inventent jamais du temps quand l'horloge locale est en avance", () => {
    expect(discount.urgencyRemaining(1000, 0)).toBe(3600);
    expect(discount.windowRemaining(1000, 0)).toBe(86_400);
  });

  it("écrivent le décompte sur une largeur qui ne bouge pas", () => {
    expect(discount.countdown(3600)).toBe("01:00:00");
    expect(discount.countdown(3599)).toBe("59:59");
    expect(discount.countdown(65)).toBe("01:05");
    expect(discount.countdown(0)).toBe("00:00");
    expect(discount.countdown(-40)).toBe("00:00");
  });

  it("se lisent à voix haute, sans faute d'accord", () => {
    expect(discount.countdownLabel(0)).toBe("offre terminée");
    expect(discount.countdownLabel(30)).toBe("il reste moins d'une minute");
    expect(discount.countdownLabel(90)).toBe("il reste 1 minute");
    expect(discount.countdownLabel(3600)).toBe("il reste 1 heure");
    expect(discount.countdownLabel(86_400)).toBe("il reste 24 heures");
    expect(discount.countdownLabel(3600 + 120)).toBe("il reste 1 heure et 2 minutes");
  });
});
