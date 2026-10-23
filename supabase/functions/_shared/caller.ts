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
 * donc passer — et le jour où la version qui envoie le jeton de l'utilisateur est
 * majoritaire, ce drapeau tombe. Une transition qui n'a pas de date de fin écrite n'en est pas
 * une : elle est nommée, isolée sur une ligne, et c'est tout ce qu'il y a à supprimer.
 *
 * **Passer ne veut plus dire passer sans compter.** La clé publiable est dans chaque IPA et
 * chaque APK : laissée sans plafond, elle ouvrait le modèle à quiconque l'avait lue. Les appels
 * sans compte partagent donc un budget commun, par fonction et par jour (`ANON_DAILY_CEILING`,
 * `consume_anon_ai_quota`), et les étapes lourdes — la conversion d'un cours, la lecture d'une
 * vidéo par le modèle, la transcription — leur sont fermées (`requireAccount`). Passé
 * `ANON_GRACE_UNTIL`, la clé publiable est refusée partout.
 */

export const ANON_GRACE = true;

/**
 * Date à laquelle la transition est close.
 *
 * Les versions déjà installées envoient encore la clé publiable. Tant que ce drapeau est vrai
 * **et** que cette date n'est pas passée (minuit UTC), elles passent. Avant, la date n'était
 * qu'un commentaire : rien ne la lisait, et une grâce sans échéance n'est plus une
 * transition, c'est une porte ouverte. `anonGraceOpen` la tient maintenant.
 */
export const ANON_GRACE_UNTIL = "2026-12-01";

/**
 * Le budget commun des appels sans compte, par fonction et par jour UTC, **toutes
 * installations confondues**. Assez pour les quelques versions anciennes qui restent, assez
 * bas pour qu'une boucle qui a lu la clé dans un IPA ne fasse pas la facture.
 */
export const ANON_DAILY_CEILING = 300;

/** Le refus d'un appel sans compte : ce que l'écran dit à une version trop ancienne. */
export const ANON_UPDATE_MESSAGE =
  "Mets Micabo à jour, ou connecte-toi, pour continuer : cette version n'est plus prise en charge.";

/** Vrai tant que la clé publiable est tolérée : `ANON_GRACE`, et avant `ANON_GRACE_UNTIL`. */
export function anonGraceOpen(now: Date = new Date()): boolean {
  if (!ANON_GRACE) return false;
  const until = Date.parse(`${ANON_GRACE_UNTIL}T00:00:00Z`);
  // Une date illisible ferme : une faute de frappe ne doit pas rouvrir la porte pour toujours.
  if (!Number.isFinite(until)) return false;
  return now.getTime() < until;
}

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
export function readCaller(request: Request, now: Date = new Date()): Caller {
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

  if (claims.role === "anon") {
    if (anonGraceOpen(now)) return { userId: null, legacy: true };
    throw new CallerError(ANON_UPDATE_MESSAGE, 401);
  }

  throw new CallerError("Connecte-toi pour utiliser Micabo.", 401);
}

/**
 * **Une étape lourde n'est pas pour la clé publiable.** La conversion d'un cours, la lecture
 * d'une vidéo par le modèle, la transcription d'un enregistrement coûtent chacune plusieurs
 * leçons : le budget commun des versions anciennes ne les couvre pas. Le refus est un 401
 * qui dit quoi faire, pas une panne.
 */
export function requireAccount(caller: Caller): asserts caller is Caller & { userId: string } {
  if (!caller.userId) throw new CallerError(ANON_UPDATE_MESSAGE, 401);
}

/**
 * Prend une unité de quota, ou refuse.
 *
 * Le décompte est fait par `consume_ai_quota`, en base, parce qu'il doit être **atomique** : deux
 * appels lancés en même temps liraient sinon le même compteur et passeraient tous les deux.
 *
 * Un appel de transition n'a personne à qui attribuer l'unité : il la prend sur le budget
 * commun des appels sans compte (`consume_anon_ai_quota`, plafond `anonCeiling`). Quand ce
 * budget est vide, toutes les versions anciennes attendent le lendemain — c'est le prix de la
 * transition, et c'est la raison de la finir.
 *
 * Sans secret de service, on est en local : on laisse passer. Avec, un décompte qui échoue
 * **ferme** (503) : un compteur qu'une panne suffit à contourner ne compte rien.
 */
export async function consumeQuota(
  caller: Caller,
  fn: string,
  units = 1,
  ceiling = DAILY_CEILING,
  proCeiling?: number,
  anonCeiling = ANON_DAILY_CEILING,
): Promise<void> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  // Sans secret, on est en local : bloquer ici casserait tout essai. En production
  // les deux sont posés ; s'ils le sont et que le RPC tombe, on ferme.
  if (!url || !serviceKey) return;

  const rpc = caller.userId ? "consume_ai_quota" : "consume_anon_ai_quota";
  const payload: Record<string, unknown> = caller.userId
    ? {
      p_user: caller.userId,
      p_fn: fn,
      p_ceiling: Math.max(1, Math.round(ceiling)),
      p_units: Math.max(1, Math.round(units)),
    }
    : {
      p_fn: fn,
      p_ceiling: Math.max(1, Math.round(anonCeiling)),
      p_units: Math.max(1, Math.round(units)),
    };
  // Le plafond Pro ne part que quand la fonction en fixe un — Mika, et elle seule. Les
  // autres gardent le fusible de la base, et leur appel à quatre paramètres reste valable
  // avant comme après la migration qui ajoute le cinquième.
  if (caller.userId && proCeiling !== undefined) {
    payload.p_pro_ceiling = Math.max(1, Math.round(proCeiling));
  }

  let allowed = true;

  try {
    const response = await fetch(`${url}/rest/v1/rpc/${rpc}`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(8_000),
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

/**
 * Les deux en une fois : c'est ce que chaque fonction appelle en première ligne.
 *
 * `ceiling` et `proCeiling` remplacent les plafonds du jour pour cette fonction ; sans eux,
 * c'est `DAILY_CEILING` et le fusible Pro de la base.
 */
export async function authorize(
  request: Request,
  fn: string,
  options: { meter?: boolean; ceiling?: number; proCeiling?: number; anonCeiling?: number } = {},
): Promise<Caller> {
  const caller = readCaller(request);
  if (options.meter !== false) {
    await consumeQuota(
      caller,
      fn,
      1,
      options.ceiling ?? DAILY_CEILING,
      options.proCeiling,
      options.anonCeiling ?? ANON_DAILY_CEILING,
    );
  }
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
