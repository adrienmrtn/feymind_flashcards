import { describe, expect, it } from "vitest";

import { discount } from "@micabo/core";

import { countdownLabel, shouldOpenDiscount, shouldShowDiscountBadge } from "./discount";

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

  it("n'attend plus de cours : c'est le paywall refermé qui le fait tomber", () => {
    // `DiscountOffer.giftAfterCourses = 0` : le cadeau suit la fermeture d'un paywall, celui
    // du parcours d'accueil compris, avant même la première leçon.
    expect(discount.giftAfterCourses).toBe(0);
    expect(shouldOpenDiscount({ ...base, courseCount: 0 })).toBe(true);
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

describe("la rangée du profil", () => {
  it("garde le tarif atteignable pour qui n'est pas abonné, fenêtre ou pas", () => {
    // `DiscountOffer.isReachable` : le cadeau surgit une fois, la rangée reste.
    expect(discount.isReachable({ isPaid: false, courseCount: 0 })).toBe(true);
    expect(discount.isReachable({ isPaid: true, courseCount: 3 })).toBe(false);
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

describe("le décompte de la languette", () => {
  it("comptent les vingt-quatre heures de la fenêtre", () => {
    expect(discount.windowRemaining(0, 0)).toBe(86_400);

    // Au bout de dix minutes, la fenêtre a perdu dix minutes.
    expect(discount.windowRemaining(0, 600_000)).toBe(85_800);

    // Deux heures plus tard, l'offre court encore.
    expect(discount.windowRemaining(0, 2 * HOUR)).toBe(79_200);
    expect(discount.isLive(0, 2 * HOUR)).toBe(true);

    // Elle s'éteint à la fin des vingt-quatre heures.
    expect(discount.windowRemaining(0, 24 * HOUR)).toBe(0);
    expect(discount.isLive(0, 24 * HOUR)).toBe(false);
  });

  it("n'inventent jamais du temps quand l'horloge locale est en avance", () => {
    expect(discount.windowRemaining(1000, 0)).toBe(86_400);
  });

  it("écrivent le décompte sur une largeur qui ne bouge pas", () => {
    expect(discount.countdown(3600)).toBe("01:00:00");
    expect(discount.countdown(3599)).toBe("59:59");
    expect(discount.countdown(65)).toBe("01:05");
    expect(discount.countdown(0)).toBe("00:00");
    expect(discount.countdown(-40)).toBe("00:00");
  });

  it("n'exposent plus de formateur au centième", () => {
    // Le paywall du cadeau ne compte plus : un décompte posé sur un prix demande de
    // décider vite plutôt que de décider. Seule la languette compte encore, à la seconde.
    // Le garde porte sur le module, pas sur la vue : un formateur qui survit finit par
    // retrouver un écran.
    expect(discount).not.toHaveProperty("preciseCountdown");
    expect(discount).not.toHaveProperty("remainingMillis");
    expect(discount).not.toHaveProperty("urgencySeconds");
  });

  it("se lisent à voix haute, sans faute d'accord, dans la langue de la page", () => {
    const fr = (key: string, vars?: Record<string, string | number>) =>
      ({
        "app.paywall.offerEnded": "offre terminée",
        "app.paywall.countdownUnderMinute": "il reste moins d'une minute",
        "app.paywall.countdownLeft": `il reste ${vars?.time}`,
      })[key] ?? key;
    // `Intl` sépare le nombre de son unité par une espace insécable : c'est voulu, on la
    // ramène à une espace pour comparer.
    const said = (bcp47: string, seconds: number, t = fr) =>
      countdownLabel(t, bcp47, seconds).replace(/[\u00a0\u202f]/g, " ");
    expect(countdownLabel(fr, "fr-FR", 0)).toBe("offre terminée");
    expect(countdownLabel(fr, "fr-FR", 30)).toBe("il reste moins d'une minute");
    expect(said("fr-FR", 90)).toBe("il reste 1 minute");
    expect(said("fr-FR", 3600)).toBe("il reste 1 heure");
    expect(said("fr-FR", 86_400)).toBe("il reste 24 heures");
    expect(said("fr-FR", 3600 + 120)).toBe("il reste 1 heure et 2 minutes");

    // Le noyau ne parle plus français : il rend des nombres.
    expect(discount).not.toHaveProperty("countdownLabel");
    const tr = (key: string, vars?: Record<string, string | number>) =>
      key === "app.paywall.countdownLeft" ? `${vars?.time} kaldı` : key;
    expect(said("tr-TR", 7200 + 60, tr)).toBe("2 saat ve 1 dakika kaldı");
  });
});
