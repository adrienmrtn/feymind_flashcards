import { pricing } from "@micabo/core";

import type { Translator } from "./i18n/copy";
import type { UiLocale } from "./i18n/locales";

/**
 * Le texte des cartes d'offre, **hors du noyau**.
 *
 * `pricing.ts` calcule les montants et les formate. Les mots (Annuel,
 * résiliable, jours gratuits) vivent ici, pour que le turc, l'allemand et
 * l'espagnol ne restent pas collés au français du catalogue.
 */

export function presentmentFor(locale: UiLocale, country?: string | null): pricing.PresentmentCurrency {
  return pricing.presentmentCurrencyFor(locale, country);
}

export function planTitle(t: Translator, plan: pricing.Plan): string {
  return t(plan.kind === "weekly" ? "app.paywall.weekly" : "app.paywall.yearly");
}

export function planTitleFor(t: Translator, productId: string | null): string | null {
  if (!productId) return null;
  const listed = pricing.STORE_PRODUCTS.find((product) => product.id === productId);
  if (listed) return planTitle(t, pricing.catalogPlanFor(listed.plan));
  if (productId === pricing.YEARLY.productId) return t("app.paywall.yearly");
  if (productId === pricing.WEEKLY.productId) return t("app.paywall.weekly");
  if (productId === pricing.DISCOUNT_YEARLY.productId) return t("app.paywall.yearly");
  return null;
}

export function trialBadge(t: Translator, plan: pricing.Plan): string | null {
  return pricing.hasTrial(plan) ? t("app.paywall.trialBadge", { days: plan.trialDays }) : null;
}

export function planRenewalCopy(
  t: Translator,
  plan: pricing.Plan,
  currency: pricing.PresentmentCurrency,
): string {
  if (plan.period === "year") {
    return t("app.paywall.renewalYearly", {
      price: pricing.priceText(pricing.presentmentAmount(plan, currency), currency),
    });
  }
  return t("app.paywall.cancelAnytime");
}

export function planDisplayedUnit(t: Translator, plan: pricing.Plan): string {
  return pricing.monthlyEquivalent(plan) ? t("app.paywall.perMonthSlash") : t("app.paywall.perWeekSlash");
}

export function planCaption(
  t: Translator,
  plan: pricing.Plan,
  currency: pricing.PresentmentCurrency,
): string {
  const monthly = pricing.monthlyEquivalent(plan, currency);
  if (monthly) return `${monthly} ${t("app.paywall.perMonthSlash")}`;
  const unit = t(plan.period === "year" ? "app.paywall.periodYear" : "app.paywall.periodWeek");
  return t("app.paywall.billedEach", { unit });
}
