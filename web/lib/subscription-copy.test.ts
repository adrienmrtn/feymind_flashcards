import { describe, expect, it } from "vitest";

import { pricing } from "@micabo/core";

import { fr } from "./i18n/catalogs";
import type { MessageTree } from "./i18n/format";
import { makeTranslator } from "./i18n/translate";
import {
  manageLabel,
  planTitleFor,
  subscriptionDetail,
  subscriptionHeadline,
  type SubscriptionView,
} from "./subscription-copy";

const t = makeTranslator("fr", fr as unknown as MessageTree, fr as unknown as MessageTree);
const locale = "fr" as const;

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
    expect(subscriptionHeadline(t, free)).toBe("Gratuit");
    expect(subscriptionDetail(t, locale, free)).toMatch(/Un cours offert/);
    expect(manageLabel(t, free)).toBe("Voir l'offre");
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
    expect(subscriptionHeadline(t, view)).toBe("Micabo Pro");
    expect(planTitleFor(t, view.productId)).toBe("Annuel");
    expect(subscriptionDetail(t, locale, view)).toMatch(/Pris sur le web/);
    expect(subscriptionDetail(t, locale, view)).toMatch(/12 octobre/);
    expect(manageLabel(t, view)).toBe("Gérer mon abonnement");
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
    expect(subscriptionDetail(t, locale, view)).toBe("Pris sur l'iPhone.");
    expect(manageLabel(t, view)).toBe("Gérer dans l'App Store");
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
    expect(subscriptionHeadline(t, view)).toBe("Accès offert");
    expect(manageLabel(t, view)).toBeNull();
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
    expect(subscriptionHeadline(t, view)).toBe("Essai Micabo Pro");
    expect(subscriptionDetail(t, locale, view)).toMatch(/Jusqu'au 4 septembre/);
  });
});
