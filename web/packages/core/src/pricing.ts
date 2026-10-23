/**
 * Les offres de Micabo Pro, et **leur prix pays par pays** — ceux des apps.
 *
 * **Deux offres sur le paywall, pas trois.** Un écran à trois colonnes fait comparer des
 * colonnes au lieu de faire choisir : l'annuel est celui qu'on recommande, l'hebdomadaire
 * existe pour celui qui a un partiel dans dix jours et ne veut pas s'engager plus loin que ça.
 * Le troisième produit — l'annuel à tarif réduit, sans essai — n'est pas sur le paywall
 * ordinaire : on y entre par l'offre cadeau.
 *
 * **La grille est celle des apps, pays par pays.** `store/pricing.json` est la source : c'est
 * elle que l'action « Grille de prix iOS » pose dans App Store Connect, et la ligne France est
 * le repli que `PaywallCatalog.swift` écrit en dur (49,99 € / 4,99 € / 29,99 €).
 * `store/play-subscriptions.json` pose les mêmes montants sur Google Play. Un Espagnol lisait
 * 49,99 € sur le site et 39,99 € dans l'app ; un Américain des euros au lieu de $59.99. Un site
 * qui annonce un autre prix que l'app pour le même abonnement se lit comme une erreur — ou
 * comme une arnaque. `freemium-parity.test.ts` relit la grille et le Swift, et tombe si le web
 * diverge.
 *
 * **Le paiement web reste fermé** (`CHECKOUT_MAINTENANCE`, `web/lib/stripe/checkout.ts`). Les
 * prix Stripe à créer pour le rouvrir sont décrits par `stripePriceSpecs()` et listés dans
 * `docs/revenuecat.md` (§16) ; leurs identifiants arrivent par l'environnement
 * (`STRIPE_PRICE_ENV`).
 *
 * Le point qui compte pour le site : **le pourcentage d'économie est calculé, jamais écrit**,
 * et il l'est sur les prix du pays qu'on affiche. Une remise annoncée à côté de deux prix qui
 * la contredisent est une allégation commerciale fausse, et sur un site public elle est indexée.
 */

import { institutionCountryIso } from "./onboarding/countries";

export type PlanKind = "yearly" | "weekly";
export type BillingPeriod = "year" | "week";
/** Les trois produits du catalogue, tarif réduit compris. */
export type CatalogPlan = "yearly" | "weekly" | "yearly_discount";

/** Les jours d'essai des apps (`TrialTimeline.freeDays`), sur l'annuel comme sur la semaine. */
const TRIAL_DAYS = 3;

/**
 * Comment l'App Store fixe le prix d'un pays (`rule` dans `store/pricing.json`).
 *
 * - `price` : le montant est écrit, dans la devise du pays. Le site affiche exactement ça.
 * - `usd` : Apple vend l'équivalent local d'un prix en dollars. Le site affiche le prix en
 *   dollars, le seul que la grille écrit.
 * - `equalize` : Apple vend l'équivalent local du prix d'un autre pays (Canada → États-Unis,
 *   Pologne → Espagne). Le site affiche le prix de ce pays-là, dans sa devise.
 *
 * Dans les deux derniers cas, l'app lit la devise locale qu'Apple a choisie au moment de
 * poser la grille ; ce montant-là n'est écrit nulle part dans le dépôt, et l'inventer serait
 * pire qu'afficher la référence.
 */
export type StoreRule = "price" | "usd" | "equalize";

/**
 * Les prix Stripe à créer : un objet `price_…` par offre **et par groupe**. Un prix Stripe n'a
 * qu'un montant par devise — l'euro à 49,99 € et l'euro à 39,99 € sont donc deux objets, comme
 * le dollar à 59,99 $ et le dollar à 29,99 $. Les devises qui ne se disputent pas un montant
 * vivent ensemble dans les `currency_options` du groupe `standard`.
 */
export type StripePriceGroup = "standard" | "south" | "latam" | "emerging";

export interface RegionalPrices {
  /** Le palier de `store/pricing.json`. */
  tier: string;
  label: string;
  rule: StoreRule;
  /** Les pays, en ISO 3166-1 alpha-2 majuscules. */
  countries: readonly string[];
  /** ISO 4217, majuscules : la devise affichée, et celle que Stripe encaissera. */
  currency: string;
  /** Le prix de chaque offre, dans `currency`. */
  amounts: Readonly<Record<CatalogPlan, number>>;
  /** Jours d'essai de l'annuel et de l'hebdomadaire. Le tarif réduit n'en a jamais. */
  trialDays: number;
  stripeGroup: StripePriceGroup;
}

function row(
  tier: string,
  label: string,
  rule: StoreRule,
  countries: readonly string[],
  currency: string,
  [weekly, yearly, discount]: readonly [number, number, number],
  stripeGroup: StripePriceGroup,
): RegionalPrices {
  return {
    tier,
    label,
    rule,
    countries,
    currency,
    amounts: { yearly, weekly, yearly_discount: discount },
    trialDays: TRIAL_DAYS,
    stripeGroup,
  };
}

/**
 * **La France, et tout pays que la grille ne nomme pas.** Apple vend alors l'équivalent local
 * de ces prix ; le site les affiche en euros.
 */
export const BASE_PRICES: RegionalPrices = row(
  "B",
  "France",
  "price",
  ["FR"],
  "EUR",
  [4.99, 49.99, 29.99],
  "standard",
);

/**
 * **La grille de `store/pricing.json`, palier par palier, dans le même ordre.** Les montants
 * sont écrits dans l'ordre du fichier : hebdomadaire, annuel, tarif réduit.
 */
export const REGIONAL_PRICES: readonly RegionalPrices[] = [
  BASE_PRICES,
  row("A", "États-Unis", "price", ["US"], "USD", [7.99, 59.99, 35.99], "standard"),
  row("A", "Canada, Australie, Suisse", "equalize", ["CA", "AU", "CH"], "USD", [7.99, 59.99, 35.99], "standard"),
  row("B", "Zone euro du nord", "price", ["BE", "LU", "DE", "AT", "NL", "IE", "FI"], "EUR", [4.99, 49.99, 29.99], "standard"),
  row(
    "C",
    "Europe du Sud et zone euro de l'Est",
    "price",
    ["ES", "IT", "PT", "GR", "SK", "SI", "HR", "EE", "LV", "LT"],
    "EUR",
    [3.99, 39.99, 23.99],
    "south",
  ),
  row("C", "Europe de l'Est hors euro", "equalize", ["PL", "CZ", "HU", "RO", "BG"], "EUR", [3.99, 39.99, 23.99], "south"),
  row("D", "Turquie", "price", ["TR"], "TRY", [149.99, 1499.99, 899.99], "standard"),
  row("D", "Brésil", "price", ["BR"], "BRL", [14.9, 149.9, 89.9], "standard"),
  row("D", "Mexique", "price", ["MX"], "MXN", [59, 599, 359], "standard"),
  row("D", "Amérique latine", "usd", ["AR", "CO", "CL", "PE"], "USD", [2.99, 29.99, 17.99], "latam"),
  row(
    "E",
    "Afrique francophone, Égypte, Asie du Sud-Est",
    "usd",
    ["MA", "DZ", "TN", "SN", "CI", "EG", "ID", "PH", "VN", "PK", "NG"],
    "USD",
    [1.99, 19.99, 11.99],
    "emerging",
  ),
  row("E", "Inde", "price", ["IN"], "INR", [149, 1499, 899], "standard"),
];

/**
 * Un code pays tel qu'il arrive — `profiles.country_code` (`uk`, `other`), l'en-tête de
 * Vercel (`ES`), une région de navigateur — ramené à l'ISO alpha-2 majuscules, ou `null`.
 */
export function normalizeCountry(code: string | null | undefined): string | null {
  const iso = institutionCountryIso(code);
  return iso && /^[A-Z]{2}$/.test(iso) ? iso : null;
}

/** Les prix d'un pays ; la France pour un pays que la grille ne nomme pas, ou aucun pays. */
export function regionalPricesFor(country: string | null | undefined): RegionalPrices {
  const iso = normalizeCountry(country);
  if (!iso) return BASE_PRICES;
  return REGIONAL_PRICES.find((prices) => prices.countries.includes(iso)) ?? BASE_PRICES;
}

/**
 * La langue d'interface → le pays qu'elle désigne sans discussion, **en dernier recours**,
 * quand ni le compte, ni l'adresse IP, ni la région du navigateur ne disent rien. L'anglais
 * et le français n'y sont pas : ils se parlent dans trop de pays aux prix différents.
 */
const LANGUAGE_COUNTRY: Readonly<Record<string, string>> = {
  de: "DE",
  es: "ES",
  "es-419": "MX",
  it: "IT",
  pt: "PT",
  "pt-br": "BR",
  nl: "NL",
  pl: "PL",
  ro: "RO",
  cs: "CZ",
  sk: "SK",
  sl: "SI",
  hr: "HR",
  et: "EE",
  fi: "FI",
  hu: "HU",
  bg: "BG",
  el: "GR",
  tr: "TR",
};

/** Les régions nommées par un `Accept-Language`, dans l'ordre de préférence. */
function acceptLanguageTags(header: string | null | undefined): string[] {
  if (!header) return [];
  return header
    .split(",")
    .map((part, index) => {
      const [tag = "", ...params] = part.trim().split(";");
      const q = params.map((p) => p.trim()).find((p) => p.startsWith("q="));
      const weight = q ? Number(q.slice(2)) : 1;
      return { tag: tag.trim().replace(/_/g, "-"), weight: Number.isFinite(weight) ? weight : 0, index };
    })
    .filter((entry) => entry.tag && entry.tag !== "*" && entry.weight > 0)
    .sort((a, b) => b.weight - a.weight || a.index - b.index)
    .map((entry) => entry.tag);
}

/**
 * **Le pays dont on affiche les prix.** Du plus sûr au plus deviné :
 *
 * 1. **Le compte** — `profiles.country_code`, le pays de scolarisation déclaré au parcours.
 *    C'est lui que `startCheckout` lit, donc celui de la devise encaissée.
 * 2. **L'adresse IP** — `x-vercel-ip-country`. C'est ce que fait l'App Store : le prix est
 *    celui de la boutique du pays, pas celui de la langue qu'on lit.
 * 3. **La région du navigateur** — `es-ES`, `en-US` dans `Accept-Language`.
 * 4. **La langue**, quand elle ne désigne qu'un pays (le turc, l'italien).
 *
 * Rend `null` quand rien ne parle : la grille de base, la France.
 */
export function resolvePricingCountry(input: {
  profile?: string | null;
  geo?: string | null;
  acceptLanguage?: string | null;
  uiLocale?: string | null;
}): string | null {
  const declared = normalizeCountry(input.profile);
  if (declared) return declared;

  const geo = normalizeCountry(input.geo);
  if (geo) return geo;

  const tags = acceptLanguageTags(input.acceptLanguage);
  for (const tag of tags) {
    const region = tag.split("-").slice(1).find((part) => /^[a-z]{2}$/i.test(part));
    const iso = normalizeCountry(region);
    if (iso) return iso;
  }

  for (const tag of [input.uiLocale ?? "", ...tags]) {
    const lower = tag.trim().toLowerCase();
    const match = LANGUAGE_COUNTRY[lower] ?? LANGUAGE_COUNTRY[lower.split("-")[0] ?? ""];
    if (match) return match;
  }
  return null;
}

/**
 * **Ce qu'on affiche à ce lecteur** : les prix de son pays, écrits dans sa langue.
 *
 * La somme est celle du pays ; la manière de l'écrire est celle de la langue du site, comme
 * `PaywallPrice.text` dans l'app — « 39,99 € » pour qui lit le français, « €39.99 » pour qui
 * lit l'anglais.
 */
export interface Presentment {
  /** Le pays retenu (ISO alpha-2), ou `null` : la grille de base. */
  country: string | null;
  prices: RegionalPrices;
  /** Une locale BCP 47 (`fr`, `pt-BR`, `sr-Latn-RS`). */
  locale: string;
}

export function presentmentFor(country: string | null | undefined, locale = "fr-FR"): Presentment {
  const iso = normalizeCountry(country);
  return { country: iso, prices: regionalPricesFor(iso), locale };
}

/** La France, écrite en français : le repli de tout ce qui n'a pas de lecteur. */
export const DEFAULT_PRESENTMENT: Presentment = presentmentFor(null, "fr-FR");

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
  mx: "es-419",
  ar: "es-419",
  co: "es-419",
  cl: "es-419",
  pe: "es-419",
  it: "it",
  pt: "pt",
  br: "pt-BR",
  nl: "nl",
  pl: "pl",
  ro: "ro",
  se: "sv",
  dk: "da",
  fi: "fi",
  ee: "et",
  cz: "cs",
  sk: "sk",
  hu: "hu",
  hr: "hr",
  si: "sl",
  bg: "bg",
  gr: "el",
  ru: "ru",
};

/**
 * Les langues que Stripe Checkout sait afficher (`locale` de la session), parmi les nôtres.
 * Une locale hors de cette liste fait refuser la session : l'arabe et le serbe n'y sont pas,
 * et se taire laisse Stripe lire l'en-tête du navigateur.
 */
const STRIPE_CHECKOUT_LOCALES = new Set([
  "bg", "cs", "da", "de", "el", "en", "es", "es-419", "et", "fi", "fr", "hr", "hu", "it",
  "nl", "pl", "pt", "pt-BR", "ro", "ru", "sk", "sl", "sv", "tr",
]);

/** Une langue dite (`pt-BR`, `es-MX`, `fr-CA`) → la locale Stripe qui la sert, ou rien. */
function stripeLocaleOf(value: string | null | undefined): string | undefined {
  const tag = value?.trim().replace(/_/g, "-").toLowerCase();
  if (!tag) return undefined;
  if (tag === "pt-br") return "pt-BR";
  if (tag === "es-419") return "es-419";
  const primary = tag.split("-")[0]!;
  return STRIPE_CHECKOUT_LOCALES.has(primary) ? primary : undefined;
}

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
  const said = [input.chosen, input.navigator].find((value) => Boolean(value?.trim()));
  // Une langue dite mais que Stripe n'affiche pas (l'arabe) : on se tait plutôt que de
  // traduire la page de paiement dans une autre langue que celle qu'on lit.
  if (said) return stripeLocaleOf(said);

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
  /** Identifiant App Store Connect, et identifiant du produit côté RevenueCat. */
  productId: string;
  title: string;
  /**
   * Le prix **de la France**, comme dans `PaywallCatalog.swift` : un repli, jamais ce qu'on
   * affiche à un lecteur. Ce qu'on affiche passe par `presentmentAmount`, qui lit la ligne
   * du pays.
   */
  price: number;
  period: BillingPeriod;
  /** Jours d'essai. Zéro : rien n'est offert, et le bouton ne doit pas le dire. */
  trialDays: number;
}

export const YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly",
  title: "Annuel",
  price: BASE_PRICES.amounts.yearly,
  period: "year",
  trialDays: TRIAL_DAYS,
};

/**
 * Le tarif réduit, celui de l'offre cadeau.
 *
 * Il n'est **pas** sur le paywall ordinaire : on y entre par le cadeau, et par lui seul. Il
 * n'annonce pas de mensuel : son paywall écrit la somme réellement prélevée — 40 % de moins
 * que l'annuel du même pays, comme dans l'app.
 */
export const DISCOUNT_YEARLY: Plan = {
  kind: "yearly",
  productId: "com.micabo.app.pro.yearly.discount",
  title: "Annuel",
  price: BASE_PRICES.amounts.yearly_discount,
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
  price: BASE_PRICES.amounts.weekly,
  period: "week",
  trialDays: TRIAL_DAYS,
};

/** L'identifiant de catalogue d'une offre : c'est lui qui choisit la colonne de la grille. */
export function catalogPlanOf(plan: Plan): CatalogPlan {
  if (plan.productId === DISCOUNT_YEARLY.productId) return "yearly_discount";
  return plan.kind;
}

/**
 * Les produits chez RevenueCat, tous attachés à l'entitlement `pro`.
 *
 * Les trois `price_…` Stripe listés ici sont ceux de **l'ancienne grille** (69,99 € / 7,99 € /
 * 39,99 €) : gardés pour reconnaître un abonnement web déjà pris, **jamais vendus**. Les prix
 * de la grille actuelle n'ont pas encore d'identifiant : ils arrivent par l'environnement
 * (`STRIPE_PRICE_ENV`), le jour où le paiement web rouvre.
 */
export type StoreKind = "app_store" | "stripe";

export interface StoreProduct {
  store: StoreKind;
  /** Tel que RevenueCat le montre. Apple : `com.micabo…`. Stripe : `price_…`. */
  id: string;
  plan: CatalogPlan;
  /** Un prix d'une grille passée : reconnu, plus vendu. */
  legacy?: boolean;
}

export const STORE_PRODUCTS: readonly StoreProduct[] = [
  { store: "app_store", id: "com.micabo.app.pro.yearly", plan: "yearly" },
  { store: "app_store", id: "com.micabo.app.pro.weekly", plan: "weekly" },
  { store: "app_store", id: "com.micabo.app.pro.yearly.discount", plan: "yearly_discount" },
  { store: "stripe", id: "price_1UAqB547TFrcO0lvSacZ91Pp", plan: "yearly", legacy: true },
  { store: "stripe", id: "price_1UAqBI47TFrcO0lvTLjtkffx", plan: "weekly", legacy: true },
  { store: "stripe", id: "price_1UAqBJ47TFrcO0lvb1vDYAPj", plan: "yearly_discount", legacy: true },
];

/** Le `price_…` de l'ancienne grille, pour reconnaître un abonné web d'avant. */
export function legacyStripePriceId(plan: CatalogPlan): string {
  const found = STORE_PRODUCTS.find(
    (product) => product.store === "stripe" && product.plan === plan,
  );
  if (!found) throw new Error(`Prix Stripe manquant pour ${plan}`);
  return found.id;
}

/**
 * **Les variables d'environnement qui portent les `price_…` de la grille actuelle**, une par
 * offre et par groupe. Les trois du groupe `standard` gardent leur nom d'avant.
 */
export const STRIPE_PRICE_ENV: Readonly<Record<StripePriceGroup, Readonly<Record<CatalogPlan, string>>>> = {
  standard: {
    yearly: "STRIPE_PRICE_YEARLY",
    weekly: "STRIPE_PRICE_WEEKLY",
    yearly_discount: "STRIPE_PRICE_YEARLY_DISCOUNT",
  },
  south: {
    yearly: "STRIPE_PRICE_YEARLY_SOUTH",
    weekly: "STRIPE_PRICE_WEEKLY_SOUTH",
    yearly_discount: "STRIPE_PRICE_YEARLY_DISCOUNT_SOUTH",
  },
  latam: {
    yearly: "STRIPE_PRICE_YEARLY_LATAM",
    weekly: "STRIPE_PRICE_WEEKLY_LATAM",
    yearly_discount: "STRIPE_PRICE_YEARLY_DISCOUNT_LATAM",
  },
  emerging: {
    yearly: "STRIPE_PRICE_YEARLY_EMERGING",
    weekly: "STRIPE_PRICE_WEEKLY_EMERGING",
    yearly_discount: "STRIPE_PRICE_YEARLY_DISCOUNT_EMERGING",
  },
};

/** Le `price_…` posé dans l'environnement pour cette offre et ce groupe, ou `null`. */
export function stripePriceIdFromEnv(
  plan: CatalogPlan,
  group: StripePriceGroup,
  env: Readonly<Record<string, string | undefined>>,
): string | null {
  const value = env[STRIPE_PRICE_ENV[group][plan]]?.trim();
  return value ? value : null;
}

/** Un prix Stripe à créer : la devise par défaut, son montant, et les autres devises. */
export interface StripePriceSpec {
  group: StripePriceGroup;
  plan: CatalogPlan;
  env: string;
  interval: "year" | "week";
  currency: string;
  amount: number;
  /** Devise (minuscules, comme Stripe) → montant. */
  currencyOptions: Readonly<Record<string, number>>;
  countries: readonly string[];
}

const PLAN_INTERVAL: Record<CatalogPlan, "year" | "week"> = {
  yearly: "year",
  weekly: "week",
  yearly_discount: "year",
};

/**
 * **Les prix Stripe que la grille demande**, déduits d'elle et non recopiés. La première
 * ligne d'un groupe donne la devise par défaut ; chaque autre devise du groupe entre dans les
 * `currency_options`. Deux lignes d'un même groupe qui diraient deux montants dans la même
 * devise sont une erreur de grille : on la refuse.
 */
export function stripePriceSpecs(): StripePriceSpec[] {
  const specs: StripePriceSpec[] = [];
  const groups = [...new Set(REGIONAL_PRICES.map((prices) => prices.stripeGroup))];
  for (const group of groups) {
    const rows = REGIONAL_PRICES.filter((prices) => prices.stripeGroup === group);
    for (const plan of ["yearly", "weekly", "yearly_discount"] as const) {
      const byCurrency = new Map<string, number>();
      for (const prices of rows) {
        const known = byCurrency.get(prices.currency);
        const amount = prices.amounts[plan];
        if (known !== undefined && known !== amount) {
          throw new Error(`Groupe Stripe ${group} : deux montants ${prices.currency} pour ${plan}`);
        }
        byCurrency.set(prices.currency, amount);
      }
      const [first, ...others] = [...byCurrency.entries()];
      if (!first) continue;
      const [currency, amount] = first;
      specs.push({
        group,
        plan,
        env: STRIPE_PRICE_ENV[group][plan],
        interval: PLAN_INTERVAL[plan],
        currency: currency.toLowerCase(),
        amount,
        currencyOptions: Object.fromEntries(others.map(([code, value]) => [code.toLowerCase(), value])),
        countries: rows.flatMap((prices) => prices.countries),
      });
    }
  }
  return specs;
}

/**
 * La devise passée à Checkout, en minuscules comme l'attend Stripe.
 *
 * Sans elle, Checkout devine la devise à l'adresse IP. Un Turc en vacances paierait alors des
 * euros après avoir lu des livres — et c'est l'écart entre le prix affiché et le prix prélevé
 * qui fait les litiges.
 */
export function checkoutCurrency(presentment: Presentment): string {
  return presentment.prices.currency.toLowerCase();
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
 * On barre **l'annuel**, pas la somme de cinquante-deux semaines. Comparer une remise à
 * l'offre la plus chère du catalogue gonfle le pourcentage et se lit comme une remise inventée.
 */
export const DISCOUNT_REFERENCE = YEARLY;

/** Les jours d'essai de l'offre dans ce pays. Le tarif réduit n'en a nulle part. */
export function trialDays(plan: Plan, presentment: Presentment = DEFAULT_PRESENTMENT): number {
  return plan.trialDays > 0 ? presentment.prices.trialDays : 0;
}

export function hasTrial(plan: Plan, presentment: Presentment = DEFAULT_PRESENTMENT): boolean {
  return trialDays(plan, presentment) > 0;
}

/** Ce que l'offre coûte dans ce pays : la somme prélevée à chaque échéance. */
export function presentmentAmount(
  plan: Plan,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): number {
  return presentment.prices.amounts[catalogPlanOf(plan)];
}

/** Ce que l'offre coûte sur douze mois dans ce pays, quel que soit son rythme. */
export function annualCost(plan: Plan, presentment: Presentment = DEFAULT_PRESENTMENT): number {
  return presentmentAmount(plan, presentment) * OCCURRENCES_PER_YEAR[plan.period];
}

/**
 * Ce que `discounted` fait économiser sur `reference`, en pourcentage entier, **sur les prix
 * du pays** — comme `PaywallCatalog.savings` sur les prix de la boutique. Aux États-Unis
 * l'annuel vaut 7,5 hebdomadaires, en France 10 : un pourcentage calculé sur les prix
 * français dirait « −81 % » à un Américain qui lit $7.99 et $59.99, soit −86 %.
 */
export function savingsPercent(
  discounted: Plan = YEARLY,
  reference: Plan = WEEKLY,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): number {
  const full = annualCost(reference, presentment);
  if (full <= 0) return 0;
  return Math.round((1 - annualCost(discounted, presentment) / full) * 100);
}

/** Ce que le tarif réduit fait économiser sur l'annuel plein du pays, en pourcentage entier. */
export function discountSavingsPercent(presentment: Presentment = DEFAULT_PRESENTMENT): number {
  return savingsPercent(DISCOUNT_YEARLY, DISCOUNT_REFERENCE, presentment);
}

/** Le prix ramené au mois, pour les offres qui se paient d'un bloc : la somme du pays ÷ 12. */
export function presentmentMonthly(
  plan: Plan,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): number | null {
  if (plan.period !== "year") return null;
  return presentmentAmount(plan, presentment) / 12;
}

function numberFormat(locale: string, currency: string): Intl.NumberFormat {
  const options: Intl.NumberFormatOptions = {
    style: "currency",
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  };
  try {
    return new Intl.NumberFormat(locale, options);
  } catch {
    return new Intl.NumberFormat("en", options);
  }
}

/**
 * « 49,99 € », « $59.99 », « ₺1.499,99 » : la somme dans la devise du pays, écrite dans la
 * langue du lecteur.
 *
 * Les espaces fines sont ramenées à U+00A0, **insécable**, parce qu'un prix ne se coupe pas
 * en fin de ligne entre le nombre et son symbole — et parce que selon la version d'ICU, `Intl`
 * rend tantôt U+00A0 tantôt U+202F : un prix qui ne s'espace pas pareil en développement et
 * en production est une différence qu'on finit par chercher longtemps.
 */
export function priceText(
  amount: number,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): string {
  return numberFormat(presentment.locale, presentment.prices.currency)
    .format(amount)
    .replace(/[  ]/g, " ");
}

/** La somme prélevée à chaque échéance, écrite : « 39,99 € ». */
export function planPriceText(plan: Plan, presentment: Presentment = DEFAULT_PRESENTMENT): string {
  return priceText(presentmentAmount(plan, presentment), presentment);
}

/**
 * Le prix ramené au mois, pour les offres qui se paient d'un bloc.
 *
 * C'est **le seul chiffre qu'on sait comparer** : personne ne divise mentalement 49,99 par
 * douze devant un paywall, et personne ne multiplie 4,99 par cinquante-deux. Il se divise dans
 * la même monnaie que l'annuel affiché juste à côté.
 */
export function monthlyEquivalent(
  plan: Plan,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): string | null {
  const amount = presentmentMonthly(plan, presentment);
  return amount == null ? null : priceText(amount, presentment);
}

/** La ligne posée sous le nom de l'offre, dans la liste des plans. */
export function planCaption(
  plan: Plan,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): string {
  const monthly = monthlyEquivalent(plan, presentment);
  return monthly ? `${monthly} / mois` : `facturé chaque ${PERIOD_UNIT[plan.period]}`;
}

/**
 * Le prix affiché à droite de la carte : le mois pour l'annuel, la semaine pour
 * l'hebdomadaire. C'est l'unité dans laquelle on compare.
 */
export function planDisplayedPrice(
  plan: Plan,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): string {
  return monthlyEquivalent(plan, presentment) ?? planPriceText(plan, presentment);
}

/** L'unité collée sous ce prix : « / mois » ou « / semaine ». */
export function planDisplayedUnit(plan: Plan): string {
  return plan.period === "year" ? "/ mois" : `/ ${PERIOD_UNIT[plan.period]}`;
}

/**
 * La ligne sous le nom, sur le paywall. L'annuel dit ce qui sera prélevé après l'essai ;
 * l'hebdomadaire dit seulement qu'on peut partir.
 */
export function planRenewalCopy(
  plan: Plan,
  presentment: Presentment = DEFAULT_PRESENTMENT,
): string {
  if (plan.period === "year") {
    return `Puis ${planPriceText(plan, presentment)} par an, résiliable à tout moment`;
  }
  return "Résiliable à tout moment";
}

/** Le pastille de l'essai, ou rien. */
export function trialBadge(plan: Plan, presentment: Presentment = DEFAULT_PRESENTMENT): string | null {
  return hasTrial(plan, presentment) ? `${trialDays(plan, presentment)} jours gratuits` : null;
}

export function periodUnit(period: BillingPeriod): string {
  return PERIOD_UNIT[period];
}
