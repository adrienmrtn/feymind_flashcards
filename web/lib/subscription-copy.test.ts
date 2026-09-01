import { describe, expect, it } from "vitest";

import { pricing } from "@micabo/core";

import {
  manageLabel,
  planTitleFor,
  subscriptionDetail,
  subscriptionHeadline,
  type SubscriptionView,
} from "./subscription-copy";

const free: SubscriptionView = {
  paid: false,
  store: null,
  periodType: null,
  expiresAt: null,
  willRenew: false,
  productId: null,
};

describe("subscription-copy", () => {
  it("nomme le gratuit et ouvre l'offre", () => {
    expect(subscriptionHeadline(free)).toBe("Gratuit");
    expect(subscriptionDetail(free)).toMatch(/Un cours offert/);
    expect(manageLabel(free)).toBe("Voir l'offre");
  });

  it("envoie un achat web vers Stripe", () => {
    const view: SubscriptionView = {
      paid: true,
      store: "stripe",
      periodType: "normal",
      expiresAt: "2026-10-12T12:00:00.000Z",
      willRenew: true,
      productId: pricing.stripePriceId("yearly"),
    };
    expect(subscriptionHeadline(view)).toBe("Micabo Pro");
    expect(planTitleFor(view.productId)).toBe("Annuel");
    expect(subscriptionDetail(view)).toMatch(/Pris sur le web/);
    expect(subscriptionDetail(view)).toMatch(/12 octobre/);
    expect(manageLabel(view)).toBe("Gérer mon abonnement");
  });

  it("envoie un achat iPhone vers l'App Store", () => {
    const view: SubscriptionView = {
      paid: true,
      store: "app_store",
      periodType: "normal",
      expiresAt: null,
      willRenew: true,
      productId: pricing.YEARLY.productId,
    };
    expect(subscriptionDetail(view)).toBe("Pris sur l'iPhone.");
    expect(manageLabel(view)).toBe("Gérer dans l'App Store");
  });

  it("ne propose rien à gérer pour un accès offert", () => {
    const view: SubscriptionView = {
      paid: true,
      store: "promotional",
      periodType: "normal",
      expiresAt: null,
      willRenew: false,
      productId: null,
    };
    expect(subscriptionHeadline(view)).toBe("Accès offert");
    expect(manageLabel(view)).toBeNull();
  });

  it("dit l'essai jusqu'à la date, pas un prélèvement", () => {
    const view: SubscriptionView = {
      paid: true,
      store: "stripe",
      periodType: "trial",
      expiresAt: "2026-09-04T12:00:00.000Z",
      willRenew: true,
      productId: pricing.stripePriceId("yearly"),
    };
    expect(subscriptionHeadline(view)).toBe("Essai Micabo Pro");
    expect(subscriptionDetail(view)).toMatch(/Jusqu'au 4 septembre/);
  });
});
