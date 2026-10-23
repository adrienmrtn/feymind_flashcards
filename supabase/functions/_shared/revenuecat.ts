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
 * **L'identifiant d'événement d'une recopie.** `apply_entitlement` ignore un `p_event_id` déjà
 * vu, et un index unique le tient sur toute la table : un identifiant fixe n'écrivait que pour
 * le premier compte recopié, puis plus rien pour personne — en rendant quand même `true`.
 * Chaque recopie porte donc le sien.
 */
export function syncEventId(userId: string, now = Date.now()): string {
  return `revenuecat-sync-${userId}-${now}`;
}

/**
 * Ce que `apply_entitlement` a répondu : vrai seulement si la ligne a été écrite. Un tableau
 * vide, un objet inattendu, un `applied` à faux : rien n'a été écrit.
 */
export function wasApplied(body: unknown): boolean {
  const row = Array.isArray(body) ? body[0] : body;
  return (row as { applied?: unknown } | null | undefined)?.applied === true;
}

/**
 * **Ce que RevenueCat sait de ce compte, maintenant** : le droit `pro` actif, `null` s'il n'y en
 * a pas, `undefined` quand RevenueCat n'a pas pu répondre. `undefined` n'est pas « non ».
 * Ne lève jamais.
 */
export async function fetchProAccess(
  userId: string,
): Promise<RevenueCatAccess | null | undefined> {
  const key = Deno.env.get("REVENUECAT_PUBLIC_KEY")?.trim() || PUBLIC_IOS_KEY;
  try {
    const response = await fetch(SUBSCRIBERS_URL + encodeURIComponent(userId), {
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      signal: AbortSignal.timeout(6000),
    });
    if (!response.ok) {
      console.warn(JSON.stringify({ revenuecat: "subscriber", status: response.status }));
      return undefined;
    }
    return activeProFrom(await response.json());
  } catch (_error) {
    console.warn(JSON.stringify({ revenuecat: "subscriber", status: "network" }));
    return undefined;
  }
}

const UUID_SHAPE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * **Les comptes qu'un `TRANSFER` concerne.**
 *
 * RevenueCat envoie un transfert sans `app_user_id` : il porte `transferred_from` (qui perd les
 * achats) et `transferred_to` (qui les reçoit). C'est le cas d'un achat fait sur le compte
 * invité, puis rattaché au vrai compte à la connexion. Seuls les identifiants Supabase (des
 * UUID) comptent : un `$RCAnonymousID` n'a pas de ligne `entitlements`. Un compte présent des
 * deux côtés reste du côté qui reçoit. `app_user_id`, quand il est là, est rangé avec ceux qui
 * reçoivent, sauf s'il est déjà parmi ceux qui perdent.
 */
export function transferTargets(event: {
  app_user_id?: unknown;
  transferred_from?: unknown;
  transferred_to?: unknown;
}): { to: string[]; from: string[] } {
  const uuids = (value: unknown): string[] =>
    Array.isArray(value)
      ? value.filter((id): id is string => typeof id === "string" && UUID_SHAPE.test(id))
        .map((id) => id.toLowerCase())
      : [];

  const from = new Set(uuids(event.transferred_from));
  const to = new Set(uuids(event.transferred_to));
  for (const id of uuids([event.app_user_id])) {
    if (!from.has(id)) to.add(id);
  }
  for (const id of to) from.delete(id);
  return { to: [...to], from: [...from] };
}

/**
 * Vrai si RevenueCat dit Pro pour ce compte **et** que la ligne `entitlements` a bien été
 * écrite. Ne lève jamais.
 */
export async function syncProFromRevenueCat(userId: string): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return false;

  try {
    const access = await fetchProAccess(userId);
    if (!access) return false;

    const now = Date.now();
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
        p_event_at: new Date(now).toISOString(),
        p_event_id: syncEventId(userId, now),
      }),
      signal: AbortSignal.timeout(6000),
    });
    if (!written.ok) {
      console.warn(JSON.stringify({ revenuecat: "apply", status: written.status }));
      return false;
    }
    // Une recopie que la base n'a pas appliquée ne rend pas `true` : la porte redemanderait à
    // une base qui n'a pas changé, et refuserait quand même.
    if (!wasApplied(await written.json())) {
      console.warn(JSON.stringify({ revenuecat: "apply", status: "not_applied", user: userId }));
      return false;
    }
    console.log(JSON.stringify({ revenuecat: "synced", user: userId }));
    return true;
  } catch (_error) {
    console.warn(JSON.stringify({ revenuecat: "apply", status: "network" }));
    return false;
  }
}
