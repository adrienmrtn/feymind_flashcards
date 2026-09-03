import { pricing } from "@micabo/core";

import { formatDayMonth, type Translator } from "./i18n/copy";
import type { UiLocale } from "./i18n/locales";

/**
 * Le texte de la carte Abonnement, **décidé ici** pour que l'écran et les
 * tests disent la même chose.
 */

export type SubscriptionStore = "app_store" | "play_store" | "stripe" | "promotional" | null;

export interface SubscriptionView {
  paid: boolean;
  store: SubscriptionStore;
  periodType: "trial" | "intro" | "normal" | null;
  expiresAt: string | null;
  willRenew: boolean;
  productId: string | null;
}

export function planTitleFor(productId: string | null): string | null {
  if (!productId) return null;
  const listed = pricing.STORE_PRODUCTS.find((product) => product.id === productId);
  if (listed) return pricing.catalogPlanFor(listed.plan).title;
  if (productId === pricing.YEARLY.productId) return pricing.YEARLY.title;
  if (productId === pricing.WEEKLY.productId) return pricing.WEEKLY.title;
  if (productId === pricing.DISCOUNT_YEARLY.productId) return pricing.DISCOUNT_YEARLY.title;
  return null;
}

export function subscriptionHeadline(t: Translator, view: SubscriptionView): string {
  if (!view.paid) return t("app.subscription.free");
  if (view.store === "promotional") return t("app.subscription.gifted");
  if (view.periodType === "trial") return t("app.subscription.trial");
  return t("app.subscription.pro");
}

export function subscriptionDetail(
  t: Translator,
  locale: UiLocale,
  view: SubscriptionView,
): string {
  if (!view.paid) return t("app.subscription.freeDetail");
  if (view.store === "promotional") return t("app.subscription.giftedDetail");

  const origin =
    view.store === "app_store"
      ? t("app.subscription.fromIphone")
      : view.store === "play_store"
        ? t("app.subscription.fromPlay")
        : t("app.subscription.fromWeb");
  const when = renewalLine(t, locale, view);
  return when ? `${origin} ${when}` : origin;
}

export function manageLabel(t: Translator, view: SubscriptionView): string | null {
  if (!view.paid) return t("app.subscription.seeOffer");
  if (view.store === "promotional") return null;
  if (view.store === "app_store") return t("app.subscription.manageAppStore");
  if (view.store === "play_store") return t("app.subscription.managePlay");
  return t("app.subscription.manage");
}

function renewalLine(t: Translator, locale: UiLocale, view: SubscriptionView): string | null {
  if (!view.expiresAt) return null;
  const day = formatDayMonth(view.expiresAt, locale);
  if (!day) return null;
  if (view.periodType === "trial") return t("app.subscription.trialUntil", { day });
  if (view.willRenew) return t("app.subscription.renewOn", { day });
  return t("app.subscription.endsOn", { day });
}
