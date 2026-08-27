/**
 * Les offres de Micabo Pro, portées depuis `Micabo/Features/Paywall/PaywallCatalog.swift`.
 *
 * **Deux offres, pas trois.** Un paywall à trois colonnes fait comparer des colonnes au lieu de
 * faire choisir : l'annuel est celui qu'on recommande, l'hebdomadaire existe pour celui qui a un
 * partiel dans dix jours et ne veut pas s'engager plus loin que ça.
 *
 * L'annuel a **deux tarifs**, et un seul est affiché à la fois : le plein (83,88 €, ramené à
 * 6,99 € / mois, avec essai) et l'étudiant (59,99 €, ramené à 4,99 € / mois, sans essai). La case
 * « je suis étudiant » permute l'un pour l'autre - ce n'est pas une troisième colonne.
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

/** Combien de fois par an la somme est prélevée. Sans ce ramené à l'année, « 7,99 € » a
 * l'air moins cher que « 83,88 € ». */
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
  /**
   * Le prix ramené au mois, **écrit** quand le calcul arrondirait autrement.
   *
   * 59,99 ÷ 12 fait 4,999… que `Intl` rend « 5,00 € ». L'offre étudiante s'annonce à 4,99 €
   * par mois : ce champ est la seule façon de ne pas mentir d'un centime à l'affichage.
   */
  monthlyPrice?: number;
  /** Jours d'essai. Zéro : rien n'est offert, et le bouton ne doit pas le dire. */
  trialDays: number;
}

export const YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly",
  title: "Annuel",
  price: 83.88,
  period: "year",
  monthlyPrice: 6.99,
  trialDays: 3,
};

export const STUDENT_YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly.student",
  title: "Annuel",
  price: 59.99,
  period: "year",
  monthlyPrice: 4.99,
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

/** L'ordre de la liste est l'ordre d'affichage : l'offre recommandée d'abord. */
export const PLANS: readonly Plan[] = [YEARLY, WEEKLY];

/** Celle qui est cochée d'avance, et la seule que le premier paywall met en avant. */
export const RECOMMENDED_PLAN = YEARLY;

/** La durée de l'essai du tarif plein. L'offre étudiante n'en a pas. */
export const FREE_TRIAL_DAYS = YEARLY.trialDays;

export function planFor(kind: PlanKind): Plan {
  return PLANS.find((plan) => plan.kind === kind) ?? RECOMMENDED_PLAN;
}

/** L'annuel qui s'affiche, selon la case « je suis étudiant ». */
export function yearlyFor(student: boolean): Plan {
  return student ? STUDENT_YEARLY : YEARLY;
}

/** Les deux cartes du paywall, dans l'ordre, pour un tarif donné. */
export function offersFor(student: boolean): readonly [Plan, Plan] {
  return [yearlyFor(student), WEEKLY];
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
 * « 59,99 € », dans la seule forme qu'on affiche.
 *
 * L'espace avant l'euro est **insécable**, parce que la typographie française l'exige : un prix
 * ne se coupe pas en fin de ligne entre le nombre et son symbole. Elle est ramenée à U+00A0 de
 * force, et ce n'est pas de la coquetterie - selon la version d'ICU, `Intl` rend tantôt U+00A0
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
 * C'est **le seul chiffre qu'un étudiant sait comparer** : personne ne divise mentalement 83,88
 * par douze devant un paywall, et personne ne multiplie 7,99 par cinquante-deux. Le mois est
 * l'unité dans laquelle un budget se pense.
 */
export function monthlyEquivalent(plan: Plan): string | null {
  if (plan.period !== "year") return null;
  return priceText(plan.monthlyPrice ?? plan.price / 12);
}

/** La ligne posée sous le nom de l'offre, dans la liste des plans. */
export function planCaption(plan: Plan): string {
  const monthly = monthlyEquivalent(plan);
  return monthly ? `${monthly} / mois` : `facturé chaque ${PERIOD_UNIT[plan.period]}`;
}

export function periodUnit(period: BillingPeriod): string {
  return PERIOD_UNIT[period];
}
