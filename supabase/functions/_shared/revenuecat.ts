/**
 * **Le droit Pro, demandé à RevenueCat quand la base n'en sait rien.**
 *
 * La base (`entitlements`) n'est écrite que par le webhook. Entre l'achat et son arrivée — ou
 * quand il se perd —, l'app voit Pro (le SDK) et le serveur non : l'élève qui vient de payer
 * importe un PDF et retombe sur le paywall. Avant de refuser pour « pas d'abonnement », la
 * porte pose donc la question à la source, avec l'identifiant du jeton (jamais un identifiant
 * venu du corps de la requête), et recopie la réponse dans `entitlements` : les quotas et les
 * appels suivants la lisent de là.
 *
 * La clé est la clé publique iOS, celle que l'app embarque : elle suffit à lire un abonné, et
 * c'est ce que fait le SDK. Une panne de RevenueCat rend `false` : la base reste la règle.
 */

const SUBSCRIBERS_URL = "https://api.revenuecat.com/v1/subscribers/";
const PUBLIC_IOS_KEY = "appl_QPZdMsnXFsagHVwBpuvWMFjxKFm";
const ENTITLEMENT = "pro";

export type RevenueCatAccess = {
  productId: string | null;
  store: string | null;
  periodType: string | null;
  expiresAt: string | null;
  willRenew: boolean;
};

const STORES: Record<string, string> = {
  app_store: "app_store",
  mac_app_store: "app_store",
  play_store: "play_store",
  stripe: "stripe",
  promotional: "promotional",
};

const PERIODS = new Set(["trial", "intro", "normal"]);

/** Lit la réponse `GET /v1/subscribers/{id}` : le droit `pro` actif, ou `null`. */
export function activeProFrom(body: unknown, now = Date.now()): RevenueCatAccess | null {
  const subscriber = (body as { subscriber?: Record<string, unknown> } | null)?.subscriber;
  const entitlements = subscriber?.entitlements as
    | Record<string, Record<string, unknown>>
    | undefined;
  const pro = entitlements?.[ENTITLEMENT];
  if (!pro) return null;

  const expires = typeof pro.expires_date === "string" ? pro.expires_date : null;
  if (expires !== null) {
    const time = Date.parse(expires);
    if (!Number.isFinite(time) || time <= now) return null;
  }

  const productId = typeof pro.product_identifier === "string" ? pro.product_identifier : null;
  const subscriptions = subscriber?.subscriptions as
    | Record<string, Record<string, unknown>>
    | undefined;
  const subscription = productId ? subscriptions?.[productId] : undefined;
  const store = typeof subscription?.store === "string" ? STORES[subscription.store] ?? null : null;
  const period = typeof subscription?.period_type === "string" ? subscription.period_type : null;

  return {
    productId,
    store,
    periodType: period !== null && PERIODS.has(period) ? period : null,
    expiresAt: expires,
    willRenew: subscription
      ? subscription.unsubscribe_detected_at == null &&
        subscription.billing_issues_detected_at == null
      : false,
  };
}

/**
 * Vrai si RevenueCat dit Pro pour ce compte ; la ligne `entitlements` est alors écrite.
 * Ne lève jamais.
 */
export async function syncProFromRevenueCat(userId: string): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return false;
  const key = Deno.env.get("REVENUECAT_PUBLIC_KEY")?.trim() || PUBLIC_IOS_KEY;

  try {
    const response = await fetch(SUBSCRIBERS_URL + encodeURIComponent(userId), {
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      signal: AbortSignal.timeout(6000),
    });
    if (!response.ok) {
      console.warn(JSON.stringify({ revenuecat: "subscriber", status: response.status }));
      return false;
    }
    const access = activeProFrom(await response.json());
    if (!access) return false;

    const written = await fetch(`${url}/rest/v1/rpc/apply_entitlement`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_user: userId,
        p_is_pro: true,
        p_product_id: access.productId,
        p_store: access.store,
        p_period_type: access.periodType,
        p_expires_at: access.expiresAt,
        p_will_renew: access.willRenew,
        p_event_at: new Date().toISOString(),
        p_event_id: "revenuecat-sync",
      }),
    });
    if (!written.ok) {
      console.warn(JSON.stringify({ revenuecat: "apply", status: written.status }));
    }
    console.log(JSON.stringify({ revenuecat: "synced", user: userId }));
    return true;
  } catch (_error) {
    console.warn(JSON.stringify({ revenuecat: "subscriber", status: "network" }));
    return false;
  }
}
