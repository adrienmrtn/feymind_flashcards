/**
 * Les offres de Micabo Pro, portées depuis `Micabo/Features/Paywall/PaywallCatalog.swift`.
 *
 * **Deux offres sur le paywall, pas trois.** Un écran à trois colonnes fait comparer des
 * colonnes au lieu de faire choisir : l'annuel est celui qu'on recommande, l'hebdomadaire
 * existe pour celui qui a un partiel dans dix jours et ne veut pas s'engager plus loin que ça.
 *
 * Un troisième produit existe déjà dans ce fichier — l'annuel discount, 29,99 €, sans essai —
 * mais il n'est pas sur le paywall ordinaire : on y entre par l'offre cadeau.
 *
 * **La grille est celle des apps** : la ligne France de `store/pricing.json` (49,99 € l'an,
 * 4,99 € la semaine, 29,99 € le tarif réduit, trois jours d'essai sur l'annuel et
 * l'hebdomadaire), celle que `PaywallCatalog.swift` garde en repli et que
 * `store/play-subscriptions.json` pose sur Google Play. Un site qui annonce un autre prix que
 * l'app pour le même abonnement se lit comme une erreur — ou comme une arnaque.
 * `freemium-parity.test.ts` relit le Swift et tombe si les deux divergent.
 *
 * **Le paiement web reste fermé** (`CHECKOUT_MAINTENANCE`, `web/lib/stripe/checkout.ts`) : les
 * trois `price_…` Stripe de `STORE_PRODUCTS` sont encore ceux de l'ancienne grille (69,99 € /
 * 7,99 € / 39,99 €). Rouvrir demande de créer trois prix Stripe à la nouvelle grille, de les
 * rattacher à `pro` chez RevenueCat, et de remplacer leurs identifiants ici.
 *
 * Le point qui compte pour le site : **le pourcentage d'économie est calculé, jamais écrit.**
 * Une remise annoncée à côté de deux prix qui la contredisent est une allégation commerciale
 * fausse, et sur un site public elle est indexée.
 */

export type PlanKind = "yearly" | "weekly";
export type BillingPeriod = "year" | "week";

/**
 * Devise d'affichage **et** d'encaissement web.
 *
 * Les montants TRY sont écrits, pas convertis au cours du jour : ce sont ceux
 * de la Turquie dans `store/pricing.json` (tier D), ceux qu'Apple prélève à un
 * élève turc. Convertir l'euro chaque matin donnerait un chiffre qui bouge, et
 * un prix que l'app ne facture pas.
 *
 * Les `currency_options` des `price_…` Stripe portent encore l'ancienne grille
 * (3 899,99 ₺ / 449,99 ₺ / 2 199,99 ₺) : à refaire avec les nouveaux prix Stripe
 * avant de rouvrir le paiement web.
 */
export type PresentmentCurrency = "EUR" | "TRY";

export const DEFAULT_PRESENTMENT: PresentmentCurrency = "EUR";

export const TRY_AMOUNTS = {
  yearly: 1499.99,
  weekly: 149.99,
  yearly_discount: 899.99,
  /** 899,99 ÷ 12 = 74,999… : écrit pour ne pas dépendre d'un arrondi. */
  yearly_discount_monthly: 75,
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

/**
 * Le pays d'où l'on vient, ramené à une de nos langues. Rien d'exhaustif : seulement les
 * pays où l'on sait dire quelque chose, et où la langue ne se discute pas.
 */
const COUNTRY_LANGUAGE: Record<string, string> = {
  tr: "tr",
  fr: "fr",
  mc: "fr",
  de: "de",
  at: "de",
  es: "es",
  mx: "es",
  ar: "es",
  co: "es",
  cl: "es",
  pe: "es",
};

/**
 * **La langue de la page de paiement.**
 *
 * Ce qu'on répare : la locale envoyée à Checkout retombait sur « en » écrit en dur dès que la
 * requête ne disait rien de clair. Trois sessions turques sur trente-trois sont parties comme
 * ça - page **en anglais, prix en livres**, personne n'a payé. Un prix qu'on ne sait pas lire
 * à côté d'une langue qu'on n'a pas choisie, c'est deux raisons de fermer l'onglet.
 *
 * L'ordre, du plus dit au plus deviné :
 *
 * 1. **Le choix** - segment d'URL ou cookie. Qui lit Micabo en français paie en français, où
 *    qu'il soit. La page Stripe doit continuer la page d'où l'on vient, sinon le changement de
 *    langue au moment de sortir la carte se lit comme un changement de site.
 * 2. **Le navigateur**, quand il désigne une de nos langues. C'est un signal réel : la
 *    personne lit déjà Micabo dans cette langue-là.
 * 3. **Le pays**, en dernier - mais avant tout repli. C'est déjà lui qui décide de la devise ;
 *    un checkout en livres a plus de raisons d'être en turc qu'en anglais.
 *
 * Rend `undefined` quand rien ne parle : Stripe déduit alors la langue de l'en-tête du
 * navigateur, ce qui reste une meilleure supposition que la nôtre.
 */
export function checkoutLocale(input: {
  /** La langue choisie - URL ou cookie -, et non celle qu'on a supposée. */
  chosen?: string | null;
  /** La langue du navigateur, seulement si elle tombe sur une des nôtres. */
  navigator?: string | null;
  /** Le pays de scolarisation, `profiles.country_code`. */
  country?: string | null;
}): string | undefined {
  const said = [input.chosen, input.navigator]
    .map((value) => value?.trim().toLowerCase().split("-")[0])
    .find((value) => Boolean(value));
  if (said) return said;

  const land = input.country?.trim().toLowerCase();
  return land ? COUNTRY_LANGUAGE[land] : undefined;
}

/** Combien de fois par an la somme est prélevée. Sans ce ramené à l'année, « 4,99 € » a
 * l'air moins cher que « 49,99 € ». */
const OCCURRENCES_PER_YEAR: Record<BillingPeriod, number> = { year: 1, week: 52 };

/** Le mot qui suit la barre oblique : « 4,99 € / semaine ». */
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
   * ce qu'on annonce. 49,99 ÷ 12 fait 4,1658, que `Intl` rend « 4,17 € » : rien à forcer.
   */
  monthlyPrice?: number;
  /** Jours d'essai. Zéro : rien n'est offert, et le bouton ne doit pas le dire. */
  trialDays: number;
}

/** Les jours d'essai des apps (`TrialTimeline.freeDays`), sur l'annuel comme sur la semaine. */
const TRIAL_DAYS = 3;

export const YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly",
  title: "Annuel",
  price: 49.99,
  period: "year",
  trialDays: TRIAL_DAYS,
};

/**
 * Le tarif réduit, celui de l'offre cadeau.
 *
 * Il n'est **pas** sur le paywall ordinaire : on y entre par le cadeau posé
 * après le premier cours, et par lui seul. Il n'annonce pas de mensuel : son
 * paywall écrit la somme réellement prélevée, 29,99 € par an — 40 % de moins
 * que l'annuel, comme dans l'app.
 */
export const DISCOUNT_YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly.discount",
  title: "Annuel",
  price: 29.99,
  period: "year",
  trialDays: 0,
};

/**
 * **Trois jours offerts, comme l'annuel**, comme dans l'app (`PaywallCatalog.weekly`).
 * Apple et Google ne donnent qu'un essai par groupe : ces trois jours-là ne s'ajoutent jamais
 * à ceux de l'annuel.
 */
export const WEEKLY: Plan = {
  kind: "weekly",
  productId: "com.micabo.app.pro.weekly",
  title: "Hebdomadaire",
  price: 4.99,
  period: "week",
  trialDays: TRIAL_DAYS,
};

/**
 * Les produits chez RevenueCat, tous attachés à l'entitlement `pro`.
 *
 * **Six, pas neuf.** Trois offres × deux magasins. La livre n'ajoute
 * aucune ligne : elle vit dans les `currency_options` du `price_…` euro,
 * qui reste un seul objet Stripe. Un prix par devise obligerait à
 * réimporter un catalogue chez RevenueCat, à le rattacher à `pro`, et à
 * couper les graphiques en deux pour un produit qu'on ne vend qu'une
 * fois. Le discount ouvre le même droit — on ne crée pas un second
 * entitlement.
 */
export type StoreKind = "app_store" | "stripe";
export type CatalogPlan = "yearly" | "weekly" | "yearly_discount";

export interface StoreProduct {
  store: StoreKind;
  /** Tel que RevenueCat le montre. Apple : `com.micabo…`. Stripe : `price_…`. */
  id: string;
  plan: CatalogPlan;
}

export const STORE_PRODUCTS: readonly StoreProduct[] = [
  { store: "app_store", id: "com.micabo.app.pro.yearly", plan: "yearly" },
  { store: "app_store", id: "com.micabo.app.pro.weekly", plan: "weekly" },
  { store: "app_store", id: "com.micabo.app.pro.yearly.discount", plan: "yearly_discount" },
  { store: "stripe", id: "price_1UAqB547TFrcO0lvSacZ91Pp", plan: "yearly" },
  { store: "stripe", id: "price_1UAqBI47TFrcO0lvTLjtkffx", plan: "weekly" },
  { store: "stripe", id: "price_1UAqBJ47TFrcO0lvb1vDYAPj", plan: "yearly_discount" },
];

export function stripePriceId(plan: CatalogPlan): string {
  const found = STORE_PRODUCTS.find(
    (product) => product.store === "stripe" && product.plan === plan,
  );
  if (!found) throw new Error(`Prix Stripe manquant pour ${plan}`);
  return found.id;
}

/**
 * La devise passée à Checkout, en minuscules comme l'attend Stripe.
 *
 * Sans elle, Checkout devine la devise à l'adresse IP. Un Turc en
 * vacances paierait alors des euros après avoir lu des livres — et
 * c'est l'écart entre le prix affiché et le prix prélevé qui fait les
 * litiges.
 */
export function checkoutCurrency(currency: PresentmentCurrency): string {
  return currency.toLowerCase();
}

/** L'ordre de la liste est l'ordre d'affichage : l'offre recommandée d'abord. */
export const PLANS: readonly Plan[] = [YEARLY, WEEKLY];

/** Celle qui est cochée d'avance, et la seule que le premier paywall met en avant. */
export const RECOMMENDED_PLAN = YEARLY;

/** La durée de l'essai de l'annuel, la même que celle de l'hebdomadaire. Le discount n'en a pas. */
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
 * « 49,99 € », dans la seule forme qu'on affiche.
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
 * C'est **le seul chiffre qu'on sait comparer** : personne ne divise mentalement 49,99
 * par douze devant un paywall, et personne ne multiplie 4,99 par cinquante-deux. Le mois est
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
