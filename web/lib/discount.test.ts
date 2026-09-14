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

describe("les deux minuteries", () => {
  it("montrent le même temps restant : vingt-quatre heures, pop-up et pastille", () => {
    expect(discount.urgencySeconds).toBe(discount.windowSeconds);
    expect(discount.urgencyRemaining(0, 0)).toBe(86_400);
    expect(discount.windowRemaining(0, 0)).toBe(86_400);

    // Au bout de dix minutes, les deux ont perdu dix minutes.
    expect(discount.urgencyRemaining(0, 600_000)).toBe(85_800);
    expect(discount.windowRemaining(0, 600_000)).toBe(85_800);

    // Deux heures plus tard, l'offre court encore : les deux horloges le disent.
    expect(discount.urgencyRemaining(0, 2 * HOUR)).toBe(79_200);
    expect(discount.windowRemaining(0, 2 * HOUR)).toBe(79_200);
    expect(discount.isLive(0, 2 * HOUR)).toBe(true);

    // Elles s'éteignent ensemble, à la fin des vingt-quatre heures.
    expect(discount.urgencyRemaining(0, 24 * HOUR)).toBe(0);
    expect(discount.windowRemaining(0, 24 * HOUR)).toBe(0);
    expect(discount.isLive(0, 24 * HOUR)).toBe(false);
  });

  it("n'inventent jamais du temps quand l'horloge locale est en avance", () => {
    expect(discount.urgencyRemaining(1000, 0)).toBe(86_400);
    expect(discount.windowRemaining(1000, 0)).toBe(86_400);
  });

  it("écrivent le décompte sur une largeur qui ne bouge pas", () => {
    expect(discount.countdown(3600)).toBe("01:00:00");
    expect(discount.countdown(3599)).toBe("59:59");
    expect(discount.countdown(65)).toBe("01:05");
    expect(discount.countdown(0)).toBe("00:00");
    expect(discount.countdown(-40)).toBe("00:00");
  });

  it("descendent au centième sur le paywall, et gardent leur ponctuation", () => {
    // Compter en secondes ferait bégayer un affichage à deux décimales : deux images de
    // suite tomberaient dans la même seconde, et la minuterie aurait l'air arrêtée.
    expect(discount.urgencyMillisRemaining(0, 0)).toBe(86_400_000);
    expect(discount.windowMillisRemaining(0, 0)).toBe(86_400_000);
    expect(discount.urgencyMillisRemaining(0, 310)).toBe(86_399_690);
    expect(discount.urgencyMillisRemaining(5000, 0)).toBe(86_400_000);
    expect(discount.urgencyMillisRemaining(0, 2 * HOUR)).toBe(79_200_000);
    expect(discount.urgencyMillisRemaining(0, 24 * HOUR)).toBe(0);

    expect(discount.preciseCountdown(86_400_000)).toBe("24 : 00 : 00 . 00");
    expect(discount.preciseCountdown(3_600_000)).toBe("01 : 00 : 00 . 00");
    expect(discount.preciseCountdown(1_788_690)).toBe("00 : 29 : 48 . 69");
    expect(discount.preciseCountdown(0)).toBe("00 : 00 : 00 . 00");
    expect(discount.preciseCountdown(-500)).toBe("00 : 00 : 00 . 00");
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
