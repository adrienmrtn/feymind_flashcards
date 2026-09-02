/**
 * **Qui appelle, et a-t-il encore le droit.**
 *
 * Jusqu'ici, les quatre fonctions se contentaient de ce que la passerelle Supabase leur laissait
 * passer, c'est-à-dire n'importe quel jeton valide du projet — **y compris la clé publiable**. Ça
 * a tenu tant que le seul client était une app : la clé est enfouie dans un IPA, et il n'y a pas
 * de chemin navigateur. Publiée dans le paquet JavaScript d'un site, avec un CORS à `*` et aucun
 * plafond, c'est une facture que n'importe qui fait monter depuis une console.
 *
 * Ce module fait donc deux choses, et rien d'autre : il dit **qui** appelle, et il **décompte**.
 *
 * ## Pourquoi on ne vérifie pas la signature ici
 *
 * La passerelle l'a déjà fait : une fonction déployée avec `verify_jwt` ne voit jamais un jeton
 * dont la signature est fausse. La relire ici demanderait le secret JWT du projet dans
 * l'environnement de chaque fonction, pour un contrôle déjà fait un cran plus haut. On lit donc la
 * charge utile, et on y cherche ce que la passerelle ne regarde pas : **le rôle**.
 *
 * ## La transition, et pourquoi elle existe
 *
 * Les versions de l'app déjà installées envoient la clé publiable. Refuser d'un coup les
 * casserait toutes, y compris celles qu'on ne peut plus mettre à jour. `ANON_GRACE` les laisse
 * donc passer, sans quota — et le jour où la version qui envoie le jeton de l'utilisateur est
 * majoritaire, ce drapeau tombe. Une transition qui n'a pas de date de fin écrite n'en est pas
 * une : elle est nommée, isolée sur une ligne, et c'est tout ce qu'il y a à supprimer.
 */

export const ANON_GRACE = true;

/**
 * Date à laquelle la transition doit être close.
 *
 * Les versions déjà installées envoient encore la clé publiable. Tant que ce drapeau
 * est vrai, elles passent. Passé cette date, `ANON_GRACE` doit passer à `false` :
 * une grâce sans échéance n'est plus une transition, c'est une porte ouverte.
 */
export const ANON_GRACE_UNTIL = "2026-12-01";

/** Plafond d'appels au modèle, par utilisateur, par jour et par fonction. */
export const DAILY_CEILING = 20;

/**
 * Même compteur, pour un abonné. Assez haut pour qu'un usage humain ne le
 * voie jamais, assez bas pour qu'une boucle ne vide pas le compte. Ce n'est
 * **pas** un palier commercial : le nombre ne s'écrit nulle part à l'écran.
 */
export const PRO_DAILY_CEILING = 2_000;

/** Refus sans chiffre : le plafond n'est pas un argument de vente. */
export const QUOTA_EXHAUSTED_MESSAGE =
  "Trop de générations aujourd'hui. Réessaie demain.";

export class CallerError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export interface Caller {
  /** L'identifiant de l'utilisateur, ou `null` pendant la transition. */
  userId: string | null;
  /** Vrai quand l'appel arrive avec la clé publiable, tolérée le temps d'une version. */
  legacy: boolean;
}

interface Claims {
  sub?: string;
  role?: string;
}

function decodeClaims(token: string): Claims | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), "=");
    return JSON.parse(atob(padded)) as Claims;
  } catch {
    return null;
  }
}

/**
 * Lit l'appelant depuis l'en-tête `Authorization`.
 *
 * Un jeton d'utilisateur porte `role: "authenticated"` et un `sub` ; la clé publiable porte
 * `role: "anon"` et **aucun** `sub`. C'est cette différence, et elle seule, qui distingue
 * « quelqu'un » de « n'importe qui ».
 */
export function readCaller(request: Request): Caller {
  const header = request.headers.get("Authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : "";

  if (!token) {
    throw new CallerError("Connecte-toi pour utiliser Micabo.", 401);
  }

  const claims = decodeClaims(token);
  if (!claims) {
    throw new CallerError("Jeton illisible.", 401);
  }

  if (claims.role === "service_role") {
    throw new CallerError("Connecte-toi pour utiliser Micabo.", 401);
  }

  if (claims.role === "authenticated" && claims.sub) {
    return { userId: claims.sub, legacy: false };
  }

  if (ANON_GRACE && claims.role === "anon") {
    return { userId: null, legacy: true };
  }

  throw new CallerError("Connecte-toi pour utiliser Micabo.", 401);
}

/**
 * Prend une unité de quota, ou refuse.
 *
 * Le décompte est fait par `consume_ai_quota`, en base, parce qu'il doit être **atomique** : deux
 * appels lancés en même temps liraient sinon le même compteur et passeraient tous les deux.
 *
 * Un appel de transition ne décompte pas — on n'a personne à qui l'attribuer. C'est le prix de la
 * transition, et c'est la raison de la finir.
 *
 * Et si le décompte lui-même échoue — base indisponible, secret manquant — **on laisse passer**.
 * Un fusible qui grille en fermant la porte transforme une panne de comptage en panne de produit,
 * et le produit n'a rien fait de mal.
 */
export async function consumeQuota(
  caller: Caller,
  fn: string,
  units = 1,
): Promise<void> {
  if (!caller.userId) return;

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  // Sans secret, on est en local : bloquer ici casserait tout essai. En production
  // les deux sont posés ; s'ils le sont et que le RPC tombe, on ferme.
  if (!url || !serviceKey) return;

  let allowed = true;

  try {
    const response = await fetch(`${url}/rest/v1/rpc/consume_ai_quota`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_user: caller.userId,
        p_fn: fn,
        p_ceiling: DAILY_CEILING,
        p_units: Math.max(1, Math.round(units)),
      }),
    });

    if (!response.ok) {
      throw new CallerError("Le quota est temporairement indisponible.", 503);
    }

    const rows = (await response.json()) as { allowed: boolean }[];
    const row = Array.isArray(rows) ? rows[0] : undefined;
    if (!row) {
      throw new CallerError("Le quota est temporairement indisponible.", 503);
    }

    allowed = row.allowed;
  } catch (error) {
    if (error instanceof CallerError) throw error;
    throw new CallerError("Le quota est temporairement indisponible.", 503);
  }

  if (!allowed) {
    throw new CallerError(QUOTA_EXHAUSTED_MESSAGE, 429);
  }
}

/** Les deux en une fois : c'est ce que chaque fonction appelle en première ligne. */
export async function authorize(
  request: Request,
  fn: string,
  options: { meter?: boolean } = {},
): Promise<Caller> {
  const caller = readCaller(request);
  if (options.meter !== false) await consumeQuota(caller, fn);
  return caller;
}

// MARK: - Les origines

/**
 * Les origines que le navigateur a le droit d'utiliser.
 *
 * `Access-Control-Allow-Origin: *` était sans conséquence tant que le seul client était une app :
 * un client natif ne fait pas de requête préalable et ne lit aucun de ces en-têtes. Avec un site,
 * c'est l'inverse — l'étoile invite n'importe quelle page ouverte dans le navigateur d'un étudiant
 * connecté à appeler ces fonctions avec son jeton.
 *
 * Le joker des prévisualisations est **borné à un segment** : chaque branche poussée reçoit son
 * URL, et sans lui on ne pourrait rien essayer avant la production.
 */
const ALLOWED_ORIGINS = [
  /^http:\/\/localhost:\d+$/,
  /^https:\/\/(www\.)?micabo\.app$/,
  // Uniquement les prévisualisations de ce projet, pas n'importe quel déploiement Vercel.
  /^https:\/\/micabo[a-z0-9-]*\.vercel\.app$/,
];

function allowedOrigin(origin: string | null): string | null {
  if (!origin) return null;
  return ALLOWED_ORIGINS.some((pattern) => pattern.test(origin)) ? origin : null;
}

/**
 * Enveloppe un gestionnaire et pose les bons en-têtes d'origine en sortie.
 *
 * On enveloppe plutôt que de passer les en-têtes à chaque construction de réponse : il y en a une
 * dizaine par fonction, et une seule oubliée suffit à laisser une porte ouverte. Ici il n'y a
 * qu'un endroit où l'origine est décidée, et il est traversé par tout ce qui sort.
 *
 * **Une origine absente n'est pas une origine refusée** : c'est un client natif, qui n'a jamais
 * envoyé d'`Origin` et ne lira pas la réponse à ces en-têtes. L'app continue donc de fonctionner
 * sans qu'on lui accorde quoi que ce soit.
 */
export async function withCors(
  request: Request,
  handler: () => Promise<Response>,
): Promise<Response> {
  const origin = allowedOrigin(request.headers.get("Origin"));

  const cors: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    // Sans `Vary`, un cache partagé servirait à une origine la réponse d'une autre.
    Vary: "Origin",
  };
  if (origin) cors["Access-Control-Allow-Origin"] = origin;

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const response = await handler();
  const headers = new Headers(response.headers);
  headers.delete("Access-Control-Allow-Origin");
  for (const [name, value] of Object.entries(cors)) headers.set(name, value);

  return new Response(response.body, { status: response.status, headers });
}
