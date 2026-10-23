import type { entitlement } from "@micabo/core";

/**
 * **Le droit Pro, demandé à RevenueCat quand la table dit « gratuit ».**
 *
 * `entitlements` n'est écrite que par le webhook (et par la recopie des fonctions Edge,
 * `supabase/functions/_shared/revenuecat.ts`). Un webhook perdu laissait un abonné App Store ou
 * Google Play voir le paywall sur le site, alors que l'app le savait Pro. Quand la table ne dit
 * pas Pro, le site pose donc la question à la source — **une fois par requête au plus**, avec un
 * délai court et un cache par compte, pour qu'une panne de RevenueCat ne ralentisse pas chaque
 * page d'un compte gratuit.
 *
 * Lecture seule : le site n'écrit pas `entitlements` (il n'a pas la clé de service, et une
 * écriture depuis le site serait une seconde source de vérité). Les portes du serveur
 * (`begin_lesson`, les quotas) font leur propre recopie au moment de refuser.
 *
 * ## La clé
 *
 * `REVENUECAT_SECRET_KEY` (une clé secrète **v1** `sk_…`, serveur uniquement, jamais
 * `NEXT_PUBLIC_`) si elle est posée ; sinon `REVENUECAT_PUBLIC_KEY` ; sinon la clé publique iOS,
 * celle que l'app embarque et que les fonctions Edge utilisent déjà : elle suffit pour lire un
 * abonné, et c'est ce que fait le SDK. `REVENUECAT_WEB_FALLBACK=off` coupe la relecture.
 */

const SUBSCRIBERS_URL = "https://api.revenuecat.com/v1/subscribers/";
const PUBLIC_IOS_KEY = "appl_QPZdMsnXFsagHVwBpuvWMFjxKFm";
const ENTITLEMENT = "pro";

/** Assez court pour ne jamais faire attendre une page plus qu'un aller-retour lent. */
export const LOOKUP_TIMEOUT_MS = 1500;
/** Combien de temps une réponse vaut, par compte et par instance du serveur. */
export const POSITIVE_TTL_MS = 5 * 60_000;
export const NEGATIVE_TTL_MS = 5 * 60_000;
/** Une panne se redemande plus vite : elle ne dit rien de l'abonnement. */
export const FAILURE_TTL_MS = 60_000;
const MAX_ENTRIES = 5_000;

type Store = NonNullable<entitlement.Entitlement["store"]>;
type Period = NonNullable<entitlement.Entitlement["periodType"]>;

const STORES: Record<string, Store> = {
  app_store: "app_store",
  mac_app_store: "app_store",
  play_store: "play_store",
  stripe: "stripe",
  rc_billing: "stripe",
  promotional: "promotional",
};

const PERIODS = new Set<Period>(["trial", "intro", "normal"]);

/**
 * Lit la réponse `GET /v1/subscribers/{id}` : le droit `pro` actif, ou `null`.
 * Même règle que `activeProFrom` côté Edge : une échéance passée ne compte pas, une échéance
 * absente est un droit sans fin.
 */
export function proFromSubscriber(
  body: unknown,
  now = Date.now(),
): entitlement.Entitlement | null {
  const subscriber = (body as { subscriber?: Record<string, unknown> } | null)?.subscriber;
  const entitlements = subscriber?.entitlements as
    | Record<string, Record<string, unknown>>
    | undefined;
  const pro = entitlements?.[ENTITLEMENT];
  if (!pro) return null;

  const expires = typeof pro.expires_date === "string" ? pro.expires_date : null;
  let expiresAt: Date | null = null;
  if (expires !== null) {
    const time = Date.parse(expires);
    if (!Number.isFinite(time) || time <= now) return null;
    expiresAt = new Date(time);
  }

  const productId = typeof pro.product_identifier === "string" ? pro.product_identifier : null;
  const subscriptions = subscriber?.subscriptions as
    | Record<string, Record<string, unknown>>
    | undefined;
  const subscription = productId ? subscriptions?.[productId] : undefined;
  const rawStore = typeof subscription?.store === "string" ? subscription.store : null;
  const rawPeriod = typeof subscription?.period_type === "string" ? subscription.period_type : null;

  return {
    isPro: true,
    productId,
    store: rawStore ? STORES[rawStore] ?? null : null,
    periodType: rawPeriod && PERIODS.has(rawPeriod as Period) ? (rawPeriod as Period) : null,
    expiresAt,
    willRenew: subscription
      ? subscription.unsubscribe_detected_at == null &&
        subscription.billing_issues_detected_at == null
      : false,
  };
}

/** La clé à présenter à RevenueCat, ou `null` quand la relecture est coupée. */
export function revenueCatKey(env: Record<string, string | undefined>): string | null {
  const switchedOff = env.REVENUECAT_WEB_FALLBACK?.trim().toLowerCase();
  if (switchedOff === "off" || switchedOff === "0" || switchedOff === "false") return null;
  return env.REVENUECAT_SECRET_KEY?.trim() || env.REVENUECAT_PUBLIC_KEY?.trim() || PUBLIC_IOS_KEY;
}

type Fetch = (input: string, init: RequestInit) => Promise<Response>;

/**
 * Une relecture avec son cache. Fabriquée ici pour que les tests lui donnent leur propre
 * `fetch` et leur propre horloge ; le site n'en garde qu'une (`lookupRevenueCatPro`).
 */
export function createProLookup(options: {
  key: () => string | null;
  fetch?: Fetch;
  now?: () => number;
}) {
  const doFetch: Fetch = options.fetch ?? ((input, init) => fetch(input, init));
  const now = options.now ?? Date.now;
  const cache = new Map<string, { value: entitlement.Entitlement | null; until: number }>();

  return async function lookup(userId: string): Promise<entitlement.Entitlement | null> {
    const key = options.key();
    if (!key) return null;

    const cached = cache.get(userId);
    if (cached && cached.until > now()) {
      // Un droit en cache dont l'échéance vient de passer ne compte plus.
      const value = cached.value;
      if (value?.expiresAt && value.expiresAt.getTime() <= now()) return null;
      return value;
    }

    let value: entitlement.Entitlement | null = null;
    let ttl = FAILURE_TTL_MS;
    try {
      const response = await doFetch(SUBSCRIBERS_URL + encodeURIComponent(userId), {
        headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
        signal: AbortSignal.timeout(LOOKUP_TIMEOUT_MS),
        cache: "no-store",
      });
      if (response.ok) {
        value = proFromSubscriber(await response.json(), now());
        ttl = value ? POSITIVE_TTL_MS : NEGATIVE_TTL_MS;
      } else {
        console.warn(JSON.stringify({ revenuecat: "web-subscriber", status: response.status }));
      }
    } catch {
      console.warn(JSON.stringify({ revenuecat: "web-subscriber", status: "network" }));
    }

    if (cache.size >= MAX_ENTRIES) cache.clear();
    cache.set(userId, { value, until: now() + ttl });
    return value;
  };
}

/** La relecture du site, une par instance du serveur. */
export const lookupRevenueCatPro = createProLookup({ key: () => revenueCatKey(process.env) });
