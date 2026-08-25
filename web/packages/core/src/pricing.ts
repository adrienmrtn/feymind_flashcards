/**
 * Les offres de Micabo Pro, portées depuis `Micabo/Features/Paywall/PaywallCatalog.swift`.
 *
 * **Deux offres, pas trois.** Un paywall à trois colonnes fait comparer des colonnes au lieu de
 * faire choisir : l'annuel est celui qu'on recommande, l'hebdomadaire existe pour celui qui a un
 * partiel dans dix jours et ne veut pas s'engager plus loin que ça.
 *
 * Le point qui compte pour le site : **le pourcentage d'économie est calculé, jamais écrit.**
 * La spec du parcours d'accueil annonçait « Économise 60 % » ; aux prix du catalogue, l'annuel
 * fait économiser 86 %, et le jour où un prix bouge le nombre suit. Une remise annoncée à côté
 * de deux prix qui la contredisent est une allégation commerciale fausse, et sur un site public
 * elle est indexée.
 *
 * Les prix sont ici et pas lus depuis une boutique : aucun produit n'est encore publié. Quand
 * RevenueCat sera branché, ce sont ces objets-là qui se construiront depuis un `Package`.
 */

export type PlanKind = "yearly" | "weekly";
export type BillingPeriod = "year" | "week";

/** Combien de fois par an la somme est prélevée. Sans ce ramené à l'année, « 7,99 € » a
 * l'air moins cher que « 59,99 € ». */
const OCCURRENCES_PER_YEAR: Record<BillingPeriod, number> = { year: 1, week: 52 };

/** Le mot qui suit la barre oblique : « 7,99 € / semaine ». */
const PERIOD_UNIT: Record<BillingPeriod, string> = { year: "an", week: "semaine" };

export interface Plan {
  kind: PlanKind;
  /** Identifiant App Store Connect, et identifiant du produit côté RevenueCat. */
  productId: string;
  title: string;
  price: number;
  period: BillingPeriod;
}

export const YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly",
  title: "Annuel",
  price: 59.99,
  period: "year",
};

export const WEEKLY: Plan = {
  kind: "weekly",
  productId: "com.micabo.app.pro.weekly",
  title: "Hebdomadaire",
  price: 7.99,
  period: "week",
};

/** L'ordre de la liste est l'ordre d'affichage : l'offre recommandée d'abord. */
export const PLANS: readonly Plan[] = [YEARLY, WEEKLY];

/** Celle qui est cochée d'avance, et la seule que le premier paywall met en avant. */
export const RECOMMENDED_PLAN = YEARLY;

/** La durée de l'essai. Elle vient de la chronologie affichée deux écrans plus tôt. */
export const FREE_TRIAL_DAYS = 3;

export function planFor(kind: PlanKind): Plan {
  return PLANS.find((plan) => plan.kind === kind) ?? RECOMMENDED_PLAN;
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
 * « 59,99 € », dans la seule forme qu'on affiche.
 *
 * L'espace avant l'euro est **insécable**, parce que la typographie française l'exige : un prix
 * ne se coupe pas en fin de ligne entre le nombre et son symbole. Elle est ramenée à U+00A0 de
 * force, et ce n'est pas de la coquetterie — selon la version d'ICU, `Intl` rend tantôt U+00A0
 * tantôt U+202F, et un prix qui ne s'espace pas pareil en développement et en production est
 * une différence qu'on finit par chercher longtemps.
 */
export function priceText(amount: number): string {
  return new Intl.NumberFormat("fr-FR", {
    style: "currency",
    currency: "EUR",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
    .format(amount)
    .replace(/[\u202f\u2009]/g, "\u00a0");
}

/**
 * Le prix ramené au mois, pour les offres qui se paient d'un bloc.
 *
 * C'est **le seul chiffre qu'un étudiant sait comparer** : personne ne divise mentalement 59,99
 * par douze devant un paywall, et personne ne multiplie 7,99 par cinquante-deux. Le mois est
 * l'unité dans laquelle un budget se pense.
 */
export function monthlyEquivalent(plan: Plan): string | null {
  return plan.period === "year" ? priceText(plan.price / 12) : null;
}

/** La ligne posée sous le nom de l'offre, dans la liste des plans. */
export function planCaption(plan: Plan): string {
  const monthly = monthlyEquivalent(plan);
  return monthly ? `${monthly} / mois` : `facturé chaque ${PERIOD_UNIT[plan.period]}`;
}

export function periodUnit(period: BillingPeriod): string {
  return PERIOD_UNIT[period];
}
