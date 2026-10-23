/** Ce que l'app a besoin de savoir de la personne connectée, et rien de plus. */
export interface SessionUser {
  id: string;
  email: string | null;
}

/**
 * Les deux façons d'établir une identité à partir d'un jeton.
 *
 * `getClaims` vérifie la signature - **sur place** quand le projet signe en asymétrique, la clé
 * publique étant gardée en mémoire. `getUser` la fait vérifier par GoTrue, et c'est un
 * aller-retour réseau.
 */
export interface ClaimsSource {
  getClaims(token: string): Promise<{
    data: { claims: { sub?: string; email?: unknown } } | null;
    error: unknown;
  }>;
  getUser(token: string): Promise<{
    data: { user: { id: string; email?: string | null } | null };
    error: unknown;
  }>;
}

/**
 * Qui parle, à partir d'un jeton, **sans appeler le réseau quand on peut l'éviter**.
 *
 * L'ordre compte, et pour deux raisons opposées :
 *
 * - La signature est vérifiée avant toute chose. L'`id` qui sort d'ici sert de clé au cache de
 *   Next : un jeton bricolé qui porterait le `sub` de quelqu'un d'autre lirait son entrée de
 *   cache, et le cloisonnement de Postgres n'aurait rien à en dire - la requête n'aurait pas
 *   lieu. Un jeton refusé ne donne personne, jamais un doute qui passe.
 * - Un jeton *refusé* ne déclenche pas de deuxième tentative : c'est une réponse, et la
 *   redemander à GoTrue rendrait au refus le coût qu'on vient de retirer au succès.
 *
 * `getUser` ne sert donc qu'au cas où la vérification locale ne peut pas **conclure** - le
 * trousseau public injoignable, typiquement. Casser l'écran parce qu'une clé n'a pas pu être
 * relue serait un mauvais échange : GoTrue sait répondre, et il reste d'accord avec nous.
 */
export async function userFromToken(
  auth: ClaimsSource,
  token: string,
): Promise<SessionUser | null> {
  try {
    const { data, error } = await auth.getClaims(token);
    const claims = data?.claims;
    if (error || !claims?.sub) return null;
    return { id: claims.sub, email: typeof claims.email === "string" ? claims.email : null };
  } catch {
    const { data } = await auth.getUser(token);
    return data.user ? { id: data.user.id, email: data.user.email ?? null } : null;
  }
}

/** Ce qu'on sait d'un jeton : bon, refusé pour de bon, ou rien de sûr (réseau, GoTrue muet). */
export type TokenVerdict = "valid" | "refused" | "unknown";

/**
 * **Le même verdict que `userFromToken`, mais qui sait dire « je ne sais pas ».**
 *
 * Le middleware décidait sur `getSession()`, qui lit le cookie sans rien vérifier, pendant que
 * l'app décidait sur `getClaims()`. Après une déconnexion globale depuis l'iPhone, un compte
 * supprimé ou une clé de signature tournée, les deux n'étaient plus d'accord : l'app renvoyait
 * vers `/commencer/compte` (personne), le middleware renvoyait vers `/app` (un cookie), et le
 * navigateur tournait jusqu'à `ERR_TOO_MANY_REDIRECTS`.
 *
 * Le middleware pose donc la même question que l'app. Il a seulement besoin d'une nuance de
 * plus : un refus définitif (4xx : signature fausse, jeton expiré, session inconnue de GoTrue)
 * autorise à effacer les cookies ; une panne ne l'autorise pas - effacer une session pour trois
 * secondes de réseau coupé déconnecterait quelqu'un pour rien.
 */
export async function verifyAccessToken(
  auth: Pick<ClaimsSource, "getClaims">,
  token: string,
): Promise<TokenVerdict> {
  try {
    const { data, error } = await auth.getClaims(token);
    if (error) {
      const status = (error as { status?: unknown }).status;
      return typeof status === "number" && status >= 400 && status < 500 ? "refused" : "unknown";
    }
    return data?.claims?.sub ? "valid" : "refused";
  } catch {
    return "unknown";
  }
}
