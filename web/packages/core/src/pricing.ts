/**
 * Les offres de Micabo Pro, portées depuis `Micabo/Features/Paywall/PaywallCatalog.swift`.
 *
 * **Deux offres sur le paywall, pas trois.** Un écran à trois colonnes fait comparer des
 * colonnes au lieu de faire choisir : l'annuel est celui qu'on recommande, l'hebdomadaire
 * existe pour celui qui a un partiel dans dix jours et ne veut pas s'engager plus loin que ça.
 *
 * Un troisième produit existe déjà dans ce fichier — l'annuel discount, 39,99 €, sans essai —
 * mais il n'est pas affiché. Le chemin pour l'ouvrir (lien, code, éligibilité) n'est pas encore
 * décidé : le garder ici évite de l'inventer le jour où on l'allumera.
 *
 * Le point qui compte pour le site : **le pourcentage d'économie est calculé, jamais écrit.**
 * Une remise annoncée à côté de deux prix qui la contredisent est une allégation commerciale
 * fausse, et sur un site public elle est indexée.
 *
 * Les prix sont ici et pas lus depuis une boutique : aucun produit n'est encore publié. Quand
 * RevenueCat sera branché, ce sont ces objets-là qui se construiront depuis un `Package`.
 */

export type PlanKind = "yearly" | "weekly";
export type BillingPeriod = "year" | "week";

/**
 * Devise d'affichage **et** d'encaissement web.
 *
 * Les montants TRY sont écrits, pas convertis au cours du jour. Convertir
 * 69,99 € chaque matin donnerait un chiffre qui bouge, et une allégation
 * qu'on ne facture pas. Les `price_…` Stripe TRY portent **ces** montants.
 * iOS n'a pas encore `localizedPriceString` : le catalogue reste le repli
 * App Store Turkey jusqu'à l'étape 8 de `docs/revenuecat.md`.
 *
 * Cours de référence (3 sept. 2026) : 1 € ≈ 56 ₺.
 * 69,99 × 56 ≈ 3 919 → 3 899,99 ₺. 7,99 × 56 ≈ 447 → 449,99 ₺.
 * 39,99 × 56 ≈ 2 239 → 2 199,99 ₺.
 */
export type PresentmentCurrency = "EUR" | "TRY";

export const DEFAULT_PRESENTMENT: PresentmentCurrency = "EUR";

export const TRY_AMOUNTS = {
  yearly: 3899.99,
  weekly: 449.99,
  yearly_discount: 2199.99,
  yearly_discount_monthly: 183.3,
} as const;

const CURRENCY_LOCALE: Record<PresentmentCurrency, string> = {
  EUR: "fr-FR",
  TRY: "tr-TR",
};

export function presentmentCurrencyFor(
  locale: string,
  country?: string | null,
): PresentmentCurrency {
  const lang = locale.trim().toLowerCase().split("-")[0];
  const land = country?.trim().toLowerCase();
  if (lang === "tr" || land === "tr") return "TRY";
  return "EUR";
}

/** Combien de fois par an la somme est prélevée. Sans ce ramené à l'année, « 7,99 € » a
 * l'air moins cher que « 69,99 € ». */
const OCCURRENCES_PER_YEAR: Record<BillingPeriod, number> = { year: 1, week: 52 };

/** Le mot qui suit la barre oblique : « 7,99 € / semaine ». */
const PERIOD_UNIT: Record<BillingPeriod, string> = { year: "an", week: "semaine" };

export interface Plan {
  kind: PlanKind;
  /** Identifiant App Store Connect, Stripe, et identifiant du produit côté RevenueCat. */
  productId: string;
  title: string;
  price: number;
  period: BillingPeriod;
  /**
   * Le prix ramené au mois, **écrit** seulement si le calcul arrondirait autrement que
   * ce qu'on annonce. 69,99 ÷ 12 fait 5,8325, que `Intl` rend « 5,83 € » : rien à forcer.
   */
  monthlyPrice?: number;
  /** Jours d'essai. Zéro : rien n'est offert, et le bouton ne doit pas le dire. */
  trialDays: number;
}

export const YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly",
  title: "Annuel",
  price: 69.99,
  period: "year",
  trialDays: 3,
};

/**
 * Le tarif réduit, celui de l'offre cadeau.
 *
 * Il n'est **pas** sur le paywall ordinaire : on y entre par le cadeau posé
 * après le premier cours, et par lui seul. `monthlyPrice` est écrit et non
 * calculé — 39,99 ÷ 12 fait 3,3325, qu'`Intl` rendrait « 3,33 € ». Le paywall
 * affiche donc 3,30 € / mois **et** la somme réellement prélevée juste à côté :
 * un prix mensuel sans son annuel serait une allégation qu'on ne facture pas.
 */
export const DISCOUNT_YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly.discount",
  title: "Annuel",
  price: 39.99,
  period: "year",
  monthlyPrice: 3.3,
  trialDays: 0,
};

export const WEEKLY: Plan = {
  kind: "weekly",
  productId: "com.micabo.app.pro.weekly",
  title: "Hebdomadaire",
  price: 7.99,
  period: "week",
  trialDays: 0,
};

/**
 * Les produits chez RevenueCat, tous attachés à l'entitlement `pro`.
 *
 * Trois offres × App Store, plus **deux** prix Stripe par offre (EUR et TRY).
 * Ce n'est pas trois produits : chaque magasin / chaque devise a **son**
 * identifiant. Le discount ouvre le même droit — on ne crée pas un second
 * entitlement.
 */
export type StoreKind = "app_store" | "stripe";
export type CatalogPlan = "yearly" | "weekly" | "yearly_discount";

export interface StoreProduct {
  store: StoreKind;
  /** Tel que RevenueCat le montre. Apple : `com.micabo…`. Stripe : `price_…`. */
  id: string;
  plan: CatalogPlan;
  /** Devise du `price_…` Stripe. Absent côté App Store. */
  currency?: PresentmentCurrency;
}

export const STORE_PRODUCTS: readonly StoreProduct[] = [
  { store: "app_store", id: "com.micabo.app.pro.yearly", plan: "yearly" },
  { store: "app_store", id: "com.micabo.app.pro.weekly", plan: "weekly" },
  { store: "app_store", id: "com.micabo.app.pro.yearly.discount", plan: "yearly_discount" },
  { store: "stripe", id: "price_1UAqB547TFrcO0lvSacZ91Pp", plan: "yearly", currency: "EUR" },
  { store: "stripe", id: "price_1UAqBI47TFrcO0lvTLjtkffx", plan: "weekly", currency: "EUR" },
  { store: "stripe", id: "price_1UAqBJ47TFrcO0lvb1vDYAPj", plan: "yearly_discount", currency: "EUR" },
  { store: "stripe", id: "price_1UBgT347TFrcO0lvNrHwbsOw", plan: "yearly", currency: "TRY" },
  { store: "stripe", id: "price_1UBgTC47TFrcO0lv1uQcZggk", plan: "weekly", currency: "TRY" },
  { store: "stripe", id: "price_1UBgTD47TFrcO0lvrOl7Z892", plan: "yearly_discount", currency: "TRY" },
];

export function stripePriceId(
  plan: CatalogPlan,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): string {
  const found = STORE_PRODUCTS.find(
    (product) =>
      product.store === "stripe" &&
      product.plan === plan &&
      (product.currency ?? DEFAULT_PRESENTMENT) === currency,
  );
  if (!found) throw new Error(`Prix Stripe manquant pour ${plan} (${currency})`);
  return found.id;
}

/** L'ordre de la liste est l'ordre d'affichage : l'offre recommandée d'abord. */
export const PLANS: readonly Plan[] = [YEARLY, WEEKLY];

/** Celle qui est cochée d'avance, et la seule que le premier paywall met en avant. */
export const RECOMMENDED_PLAN = YEARLY;

/** La durée de l'essai de l'annuel. L'hebdomadaire et le discount n'en ont pas. */
export const FREE_TRIAL_DAYS = YEARLY.trialDays;

export function planFor(kind: PlanKind): Plan {
  return PLANS.find((plan) => plan.kind === kind) ?? RECOMMENDED_PLAN;
}

/** L'offre derrière un identifiant de catalogue, discount compris. */
export function catalogPlanFor(plan: CatalogPlan): Plan {
  if (plan === "yearly_discount") return DISCOUNT_YEARLY;
  return planFor(plan);
}

/** Les deux cartes du paywall, dans l'ordre. Le discount n'y figure pas. */
export function offers(): readonly [Plan, Plan] {
  return [YEARLY, WEEKLY];
}

/**
 * Le prix barré à côté du tarif réduit : l'annuel plein.
 *
 * On barre **l'annuel**, pas la somme de cinquante-deux semaines. Comparer une
 * remise à l'offre la plus chère du catalogue gonfle le pourcentage et se lit
 * comme une remise inventée.
 */
export const DISCOUNT_REFERENCE = YEARLY;

/** Ce que le tarif réduit fait économiser sur l'annuel plein, en pourcentage entier. */
export function discountSavingsPercent(): number {
  return savingsPercent(DISCOUNT_YEARLY, DISCOUNT_REFERENCE);
}

export function hasTrial(plan: Plan): boolean {
  return plan.trialDays > 0;
}

/** Ce que l'offre coûte sur douze mois, quel que soit son rythme de prélèvement. */
export function annualCost(plan: Plan): number {
  return plan.price * OCCURRENCES_PER_YEAR[plan.period];
}

/** Ce que l'annuel fait économiser par rapport à l'hebdomadaire, en pourcentage entier. */
export function savingsPercent(
  discounted: Plan = YEARLY,
  reference: Plan = WEEKLY,
): number {
  const full = annualCost(reference);
  if (full <= 0) return 0;
  return Math.round((1 - annualCost(discounted) / full) * 100);
}

/**
 * « 69,99 € », dans la seule forme qu'on affiche.
 *
 * L'espace avant l'euro est **insécable**, parce que la typographie française l'exige : un prix
 * ne se coupe pas en fin de ligne entre le nombre et son symbole. Elle est ramenée à U+00A0 de
 * force, et ce n'est pas de la coquetterie - selon la version d'ICU, `Intl` rend tantôt U+00A0
 * tantôt U+202F, et un prix qui ne s'espace pas pareil en développement et en production est
 * une différence qu'on finit par chercher longtemps.
 */
export function presentmentAmount(
  plan: Plan,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): number {
  if (currency === "EUR") return plan.price;
  if (plan.productId === DISCOUNT_YEARLY.productId) return TRY_AMOUNTS.yearly_discount;
  return plan.kind === "weekly" ? TRY_AMOUNTS.weekly : TRY_AMOUNTS.yearly;
}

export function presentmentMonthly(
  plan: Plan,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): number | null {
  if (plan.period !== "year") return null;
  if (currency === "EUR") return plan.monthlyPrice ?? plan.price / 12;
  if (plan.productId === DISCOUNT_YEARLY.productId) return TRY_AMOUNTS.yearly_discount_monthly;
  return TRY_AMOUNTS.yearly / 12;
}

export function priceText(
  amount: number,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): string {
  return new Intl.NumberFormat(CURRENCY_LOCALE[currency], {
    style: "currency",
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
    .format(amount)
    .replace(/[\u202f\u2009]/g, "\u00a0");
}

/**
 * Le prix ramené au mois, pour les offres qui se paient d'un bloc.
 *
 * C'est **le seul chiffre qu'on sait comparer** : personne ne divise mentalement 69,99
 * par douze devant un paywall, et personne ne multiplie 7,99 par cinquante-deux. Le mois est
 * l'unité dans laquelle un budget se pense.
 */
export function monthlyEquivalent(
  plan: Plan,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): string | null {
  const amount = presentmentMonthly(plan, currency);
  return amount == null ? null : priceText(amount, currency);
}

/** La ligne posée sous le nom de l'offre, dans la liste des plans. */
export function planCaption(
  plan: Plan,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): string {
  const monthly = monthlyEquivalent(plan, currency);
  return monthly ? `${monthly} / mois` : `facturé chaque ${PERIOD_UNIT[plan.period]}`;
}

/**
 * Le prix affiché à droite de la carte : le mois pour l'annuel, la semaine
 * pour l'hebdomadaire. C'est l'unité dans laquelle on compare.
 */
export function planDisplayedPrice(
  plan: Plan,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): string {
  return monthlyEquivalent(plan, currency) ?? priceText(presentmentAmount(plan, currency), currency);
}

/** L'unité collée sous ce prix : « / mois » ou « / semaine ». */
export function planDisplayedUnit(plan: Plan): string {
  return monthlyEquivalent(plan) ? "/ mois" : `/ ${PERIOD_UNIT[plan.period]}`;
}

/**
 * La ligne sous le nom, sur le paywall. L'annuel dit ce qui sera prélevé
 * après l'essai ; l'hebdomadaire dit seulement qu'on peut partir.
 */
export function planRenewalCopy(
  plan: Plan,
  currency: PresentmentCurrency = DEFAULT_PRESENTMENT,
): string {
  if (plan.period === "year") {
    return `Puis ${priceText(presentmentAmount(plan, currency), currency)} par an, résiliable à tout moment`;
  }
  return "Résiliable à tout moment";
}

/** Le pastille de l'essai, ou rien. */
export function trialBadge(plan: Plan): string | null {
  return hasTrial(plan) ? `${plan.trialDays} jours gratuits` : null;
}

export function periodUnit(period: BillingPeriod): string {
  return PERIOD_UNIT[period];
}
