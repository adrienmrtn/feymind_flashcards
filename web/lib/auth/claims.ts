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
