import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * Le webhook RevenueCat : **le seul endroit qui décide qui est abonné.**
 *
 * Il est volontairement autonome — aucune dépendance partagée — parce que c'est le code dont on
 * veut pouvoir relire l'intégralité d'un trait avant de croire ce qu'il écrit.
 *
 * ## Ce qui fait qu'un droit multiplateforme marche
 *
 * Une seule règle : **`app_user_id` est l'`auth.users.id` de Supabase.** Un identifiant anonyme
 * généré par le SDK qu'on aliaserait plus tard est l'endroit où vivent tous les bugs de ce genre —
 * et il ne se voit pas, parce que tout marche pour celui qui vient d'acheter et rien pour lui le
 * lendemain sur l'autre appareil. Ici, un `app_user_id` qui n'est pas un UUID est donc **refusé
 * bruyamment** : c'est une erreur de configuration, et une erreur de configuration silencieuse en
 * facturation coûte des mois.
 *
 * ## L'authentification
 *
 * RevenueCat ne parle pas Supabase : il envoie l'en-tête `Authorization` qu'on lui a configuré.
 * Cette fonction se déploie donc **sans `verify_jwt`**, et fait son contrôle elle-même — c'est le
 * cas prévu, et le secret est comparé en temps constant pour ne pas se laisser deviner octet par
 * octet.
 *
 * ## Les états, et le seul qui piège
 *
 * **Une résiliation n'est pas une perte d'accès.** `CANCELLATION` veut dire « ne se renouvellera
 * pas » ; l'étudiant a payé jusqu'à son échéance et garde tout jusque-là. Fermer à l'annonce serait
 * lui retirer ce qu'il a acheté. C'est `EXPIRATION` qui ferme.
 *
 * Et un incident de paiement ne ferme pas non plus : RevenueCat gère une période de grâce, et
 * couper l'accès pendant qu'une banque réessaie punit quelqu'un qui n'a rien fait.
 */

interface RevenueCatEvent {
  id?: string;
  type?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  product_id?: string;
  period_type?: string;
  store?: string;
  environment?: string;
  entitlement_ids?: string[];
  expiration_at_ms?: number | null;
  event_timestamp_ms?: number;
}

/** L'entitlement qui donne accès à tout. Il est déjà nommé ainsi dans `docs/revenuecat.md`. */
const ENTITLEMENT_ID = "pro";

const UUID_SHAPE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Comparaison en temps constant : une comparaison qui s'arrête au premier octet différent se devine. */
function sameSecret(given: string, expected: string): boolean {
  if (given.length !== expected.length) return false;
  let difference = 0;
  for (let index = 0; index < given.length; index += 1) {
    difference |= given.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

/**
 * Ce que l'événement dit de l'accès.
 *
 * `null` veut dire « ne touche à rien » : un événement qu'on ne comprend pas ne doit pas décider à
 * la place de celui qu'on comprenait.
 */
function resolveAccess(event: RevenueCatEvent): { isPro: boolean; willRenew: boolean } | null {
  const type = (event.type ?? "").toUpperCase();

  // Un droit qui ne nous concerne pas ne dit rien de celui qui nous concerne.
  const ids = event.entitlement_ids ?? [];
  if (ids.length > 0 && !ids.includes(ENTITLEMENT_ID)) return null;

  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
    case "NON_RENEWING_PURCHASE":
    case "TRANSFER":
      return { isPro: true, willRenew: true };

    // Résilié, mais payé jusqu'au bout : l'accès reste, le renouvellement non.
    case "CANCELLATION":
      return { isPro: true, willRenew: false };

    // Incident de paiement : RevenueCat gère une période de grâce, on ne ferme pas.
    case "BILLING_ISSUE":
      return { isPro: true, willRenew: false };

    case "EXPIRATION":
    case "SUBSCRIPTION_PAUSED":
      return { isPro: false, willRenew: false };

    // `TEST` sert à vérifier le branchement depuis le tableau de bord, et ne doit rien écrire.
    default:
      return null;
  }
}

function normalizeStore(store: string | undefined): string | null {
  switch ((store ?? "").toUpperCase()) {
    case "APP_STORE":
    case "MAC_APP_STORE":
      return "app_store";
    case "PLAY_STORE":
      return "play_store";
    case "STRIPE":
    case "RC_BILLING":
      return "stripe";
    case "PROMOTIONAL":
      return "promotional";
    default:
      return null;
  }
}

function normalizePeriod(period: string | undefined): string | null {
  switch ((period ?? "").toUpperCase()) {
    case "TRIAL":
      return "trial";
    case "INTRO":
      return "intro";
    case "NORMAL":
      return "normal";
    default:
      return null;
  }
}

function reply(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return reply({ error: "Méthode refusée." }, 405);

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret) {
    // Sans secret configuré, on **refuse** au lieu de laisser ouvert. Un webhook de facturation
    // ouvert accepte des abonnements offerts par n'importe qui.
    return reply({ error: "Webhook non configuré." }, 503);
  }

  const given = request.headers.get("Authorization") ?? "";
  if (!sameSecret(given, secret)) return reply({ error: "Refusé." }, 401);

  let event: RevenueCatEvent;
  try {
    const body = (await request.json()) as { event?: RevenueCatEvent };
    event = body?.event ?? {};
  } catch {
    return reply({ error: "Corps illisible." }, 400);
  }

  const type = (event.type ?? "").toUpperCase();
  if (type === "TEST") return reply({ ok: true, note: "Branchement vérifié." });

  const userId = event.app_user_id ?? "";
  if (!UUID_SHAPE.test(userId)) {
    // Le refus est bruyant **exprès** : c'est le symptôme d'un SDK configuré sans
    // `appUserID`, et il vaut mieux le voir dans le tableau de bord de RevenueCat que le
    // découvrir en lisant les plaintes de gens qui ont payé deux fois.
    return reply(
      {
        error:
          "app_user_id n'est pas un identifiant Supabase. Le SDK doit être configuré avec l'auth.users.id.",
        received: userId.slice(0, 64),
      },
      422,
    );
  }

  const access = resolveAccess(event);
  if (!access) return reply({ ok: true, note: `Événement ${type} ignoré.` });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply({ error: "Environnement incomplet." }, 500);

  // Une échéance déjà passée l'emporte sur le type de l'événement : un renouvellement rejoué en
  // retard ne doit pas rouvrir un abonnement fini.
  const expiresAt = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;
  const expired = expiresAt !== null && expiresAt.getTime() < Date.now();

  const response = await fetch(`${url}/rest/v1/rpc/apply_entitlement`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      p_user: userId,
      p_is_pro: access.isPro && !expired,
      p_product_id: event.product_id ?? null,
      p_store: normalizeStore(event.store),
      p_period_type: normalizePeriod(event.period_type),
      p_expires_at: expiresAt?.toISOString() ?? null,
      p_will_renew: access.willRenew,
      p_event_at: event.event_timestamp_ms
        ? new Date(event.event_timestamp_ms).toISOString()
        : null,
      p_event_id: event.id ?? null,
    }),
  });

  if (!response.ok) {
    // On rend une erreur pour que RevenueCat **réessaie**. Avaler l'échec en 200 perdrait
    // l'événement, et un abonnement perdu ne se rattrape pas tout seul.
    return reply({ error: "Écriture refusée.", detail: await response.text() }, 502);
  }

  const rows = (await response.json()) as { applied: boolean; is_pro: boolean }[];
  return reply({ ok: true, ...(rows?.[0] ?? {}) });
});
