import { pricing } from "@micabo/core";

import { localeBcp47, type Translator } from "./i18n/copy";
import type { UiLocale } from "./i18n/locales";

/**
 * Le texte des cartes d'offre, **hors du noyau**.
 *
 * `pricing.ts` calcule les montants et les formate. Les mots (Annuel,
 * résiliable, jours gratuits) vivent ici, pour que le turc, l'allemand et
 * l'espagnol ne restent pas collés au français du catalogue.
 */

/**
 * Les prix du pays (`country`, déjà résolu par `readPricingCountry`), écrits dans la langue
 * du site. Sans pays, la grille de base : la France.
 */
export function presentmentFor(locale: UiLocale, country?: string | null): pricing.Presentment {
  return pricing.presentmentFor(country, localeBcp47(locale));
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

export function trialBadge(
  t: Translator,
  plan: pricing.Plan,
  presentment: pricing.Presentment = pricing.DEFAULT_PRESENTMENT,
): string | null {
  return pricing.hasTrial(plan, presentment)
    ? t("app.paywall.trialBadge", { days: pricing.trialDays(plan, presentment) })
    : null;
}

export function planRenewalCopy(
  t: Translator,
  plan: pricing.Plan,
  presentment: pricing.Presentment,
): string {
  if (plan.period === "year") {
    return t("app.paywall.renewalYearly", { price: pricing.planPriceText(plan, presentment) });
  }
  return t("app.paywall.cancelAnytime");
}

export function planDisplayedUnit(t: Translator, plan: pricing.Plan): string {
  return pricing.monthlyEquivalent(plan) ? t("app.paywall.perMonthSlash") : t("app.paywall.perWeekSlash");
}

export function planCaption(
  t: Translator,
  plan: pricing.Plan,
  presentment: pricing.Presentment,
): string {
  const monthly = pricing.monthlyEquivalent(plan, presentment);
  if (monthly) return `${monthly} ${t("app.paywall.perMonthSlash")}`;
  const unit = t(plan.period === "year" ? "app.paywall.periodYear" : "app.paywall.periodWeek");
  return t("app.paywall.billedEach", { unit });
}

/**
 * **La phrase qu'on écrit sur la page Stripe**, au-dessus du bouton de paiement.
 *
 * Checkout est une page blanche à bouton bleu : on y arrive depuis une carte Micabo qui
 * annonçait « 125 ₺ / ay », et on y lit « 1 499,99 ₺ » sans transition. Les deux chiffres sont
 * vrais - l'un est le mensuel équivalent, l'autre ce qui sera prélevé -, mais celui qui les
 * découvre à cet instant-là n'a aucune raison de le savoir.
 *
 * Cette phrase dit les deux, dans la langue du lecteur : ce qu'il achète, ce qui est gratuit,
 * ce qui sera prélevé et quand. C'est le seul endroit de Checkout où l'on a le droit de parler.
 */
export function checkoutNote(
  t: Translator,
  plan: pricing.Plan,
  presentment: pricing.Presentment,
): string {
  const period = plan.period === "year" ? "Yearly" : "Weekly";
  const key = pricing.hasTrial(plan, presentment) ? `trial${period}` : period.toLowerCase();
  return t(`app.paywall.stripeNote.${key}`, {
    price: pricing.planPriceText(plan, presentment),
    days: pricing.trialDays(plan, presentment),
  });
}
