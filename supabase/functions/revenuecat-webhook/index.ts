import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  type AccessRow,
  fetchProAccess,
  needsRevenueCatRecheck,
  reconcileAccess,
  resolveEventAccess,
  transferTargets,
} from "../_shared/revenuecat.ts";

/**
 * Le webhook RevenueCat : **le seul endroit qui décide qui est abonné.**
 *
 * Il est volontairement presque autonome — une seule dépendance partagée,
 * `_shared/revenuecat.ts` (testée) : la lecture d'un abonné chez RevenueCat, dont les
 * transferts et les fermetures ont besoin, et la traduction d'un événement en accès —
 * parce que c'est le code dont on veut pouvoir relire l'intégralité d'un trait avant de croire
 * ce qu'il écrit.
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
 * couper l'accès pendant qu'une banque réessaie punit quelqu'un qui n'a rien fait. Une pause
 * programmée sur le Play Store non plus : elle commence à l'échéance, avec son `EXPIRATION`.
 *
 * Enfin, un événement ne parle que d'**un** abonnement. Sur ceux qui retirent quelque chose
 * (`needsRevenueCatRecheck`), l'abonné est relu chez RevenueCat avant d'écrire : l'expiration
 * d'un magasin ne ferme pas la ligne d'un compte abonné dans l'autre.
 */

interface RevenueCatEvent {
  id?: string;
  type?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  transferred_from?: string[];
  transferred_to?: string[];
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

/** Le tableau de bord envoie parfois `Bearer <secret>`, parfois le secret nu. */
function authorizationMatches(header: string, expected: string): boolean {
  const trimmed = header.trim();
  const bearer = trimmed.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  return sameSecret(bearer ?? trimmed, expected);
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
  if (!authorizationMatches(given, secret)) return reply({ error: "Refusé." }, 401);

  let event: RevenueCatEvent;
  try {
    const body = (await request.json()) as { event?: RevenueCatEvent };
    event = body?.event ?? {};
  } catch {
    return reply({ error: "Corps illisible." }, 400);
  }

  const type = (event.type ?? "").toUpperCase();
  if (type === "TEST") return reply({ ok: true, note: "Branchement vérifié." });

  // Un transfert n'a pas d'`app_user_id` : il se lit sur ses deux listes, plus bas.
  if (type === "TRANSFER") return await handleTransfer(event);

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

  if (!event.event_timestamp_ms) {
    // Sans horodatage, `apply_entitlement` ne peut pas ordonner. On rend 502 pour que
    // RevenueCat réessaie : un événement sans date appliqué à la place d'un plus récent
    // ferme (ou ouvre) au hasard.
    return reply({ error: "Événement sans horodatage." }, 502);
  }

  const access = resolveEventAccess(event);
  if (!access) return reply({ ok: true, note: `Événement ${type} ignoré.` });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply({ error: "Environnement incomplet." }, 500);

  // Une échéance déjà passée l'emporte sur le type de l'événement : un renouvellement rejoué en
  // retard ne doit pas rouvrir un abonnement fini.
  const expiresAt = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;
  const expired = expiresAt !== null && expiresAt.getTime() < Date.now();
  const eventAt = new Date(event.event_timestamp_ms).toISOString();

  let row: AccessRow = {
    isPro: access.isPro && !expired,
    productId: event.product_id ?? null,
    store: normalizeStore(event.store),
    periodType: normalizePeriod(event.period_type),
    expiresAt: expiresAt?.toISOString() ?? null,
    willRenew: access.willRenew,
  };

  // **Un événement qui retire quelque chose parle d'un seul abonnement.** L'expiration de
  // l'App Store ne dit rien de l'abonnement Play Store qui court encore : on relit l'abonné
  // chez RevenueCat, comme pour un transfert, et un droit `pro` encore actif l'emporte.
  // RevenueCat injoignable rend 502 : il renverra l'événement, plutôt que d'écrire au hasard.
  if (needsRevenueCatRecheck(type)) {
    const current = await fetchProAccess(userId);
    if (current === undefined) {
      return reply({ error: "RevenueCat injoignable pour vérifier l'accès.", user: userId }, 502);
    }
    row = reconcileAccess(row, current);
  }

  const applied = await applyEntitlement(url, serviceKey, {
    userId,
    ...row,
    eventAt,
    eventId: event.id ?? null,
  });

  if (!applied.ok) {
    return reply({ error: "Écriture refusée.", detail: applied.detail }, 502);
  }

  return reply({ ok: true, ...applied.row });
});

/**
 * **Un transfert déplace les achats d'un compte à l'autre** — typiquement de l'invité vers le
 * vrai compte, à la connexion, ou d'un compte à l'autre sur une restauration.
 *
 * L'événement ne dit ni le produit, ni l'échéance : appliquer « Pro » à partir de lui seul
 * donnerait un droit sans fin à qui récupère un abonnement expiré depuis un an. Chaque compte
 * concerné est donc **relu chez RevenueCat**, et sa ligne recopie ce que RevenueCat dit
 * maintenant : Pro avec son échéance, ou fermé. RevenueCat qui ne répond pas rend 502, pour
 * qu'il renvoie l'événement plus tard, plutôt que d'écrire au hasard.
 */
async function handleTransfer(event: RevenueCatEvent): Promise<Response> {
  const ids = event.entitlement_ids ?? [];
  if (ids.length > 0 && !ids.includes(ENTITLEMENT_ID)) {
    return reply({ ok: true, note: "Événement TRANSFER ignoré." });
  }

  const { to, from } = transferTargets(event);
  if (to.length === 0 && from.length === 0) {
    // Même bruit que pour un `app_user_id` illisible : un transfert entre identifiants
    // anonymes est le symptôme d'un SDK configuré sans `appUserID`.
    return reply(
      {
        error: "TRANSFER sans identifiant Supabase, ni dans transferred_to ni dans transferred_from.",
        received: [...(event.transferred_to ?? []), ...(event.transferred_from ?? [])]
          .join(",").slice(0, 128),
      },
      422,
    );
  }

  if (!event.event_timestamp_ms) return reply({ error: "Événement sans horodatage." }, 502);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return reply({ error: "Environnement incomplet." }, 500);

  const eventAt = new Date(event.event_timestamp_ms).toISOString();
  const results: Record<string, unknown>[] = [];

  // Ceux qui reçoivent d'abord : un échec à mi-chemin laisse un compte de trop ouvert, jamais
  // l'acheteur fermé. RevenueCat renvoie l'événement, et le reste s'écrit au passage suivant.
  for (const [userId, side] of [
    ...to.map((id) => [id, "to"] as const),
    ...from.map((id) => [id, "from"] as const),
  ]) {
    const access = await fetchProAccess(userId);
    if (access === undefined) {
      return reply({ error: "RevenueCat injoignable pour le transfert.", user: userId }, 502);
    }

    const applied = await applyEntitlement(url, serviceKey, {
      userId,
      isPro: access !== null,
      productId: access?.productId ?? event.product_id ?? null,
      store: access?.store ?? normalizeStore(event.store),
      periodType: access?.periodType ?? null,
      expiresAt: access ? access.expiresAt : eventAt,
      willRenew: access?.willRenew ?? false,
      eventAt,
      eventId: event.id ? `${event.id}-transfer-${userId}` : null,
    });
    if (!applied.ok) {
      return reply({ error: "Écriture du transfert refusée.", user: userId, detail: applied.detail }, 502);
    }
    results.push({ user: userId, side, ...applied.row });
  }

  return reply({ ok: true, transfer: results });
}

async function applyEntitlement(
  url: string,
  serviceKey: string,
  input: {
    userId: string;
    isPro: boolean;
    productId: string | null;
    store: string | null;
    periodType: string | null;
    expiresAt: string | null;
    willRenew: boolean;
    eventAt: string;
    eventId: string | null;
  },
): Promise<{ ok: true; row: Record<string, unknown> } | { ok: false; detail: string }> {
  const response = await fetch(`${url}/rest/v1/rpc/apply_entitlement`, {
    method: "POST",
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      p_user: input.userId,
      p_is_pro: input.isPro,
      p_product_id: input.productId,
      p_store: input.store,
      p_period_type: input.periodType,
      p_expires_at: input.expiresAt,
      p_will_renew: input.willRenew,
      p_event_at: input.eventAt,
      p_event_id: input.eventId,
    }),
  });

  if (!response.ok) {
    return { ok: false, detail: await response.text() };
  }

  const rows = (await response.json()) as Record<string, unknown>[];
  return { ok: true, row: rows?.[0] ?? {} };
}
