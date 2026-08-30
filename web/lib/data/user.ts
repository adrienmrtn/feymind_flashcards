import { cache } from "react";

import { createClient } from "@/lib/supabase/server";

/** Ce que l'app a besoin de savoir de la personne connectée, et rien de plus. */
export interface SessionUser {
  id: string;
  email: string | null;
}

/**
 * La session de **cette** requête, lue une seule fois.
 *
 * Deux choses en sortent - qui c'est, et avec quel jeton lire - et elles viennent du même
 * endroit exprès : ce sont deux faces du même cookie, et les séparer faisait décoder la
 * session deux fois par requête.
 *
 * **`getSession()` ne part pas sur le réseau.** Il lit le cookie, et ne rappelle Supabase
 * que dans les quatre-vingt-dix dernières secondes du jeton. C'est le remplaçant de
 * `getUser()`, qui interrogeait GoTrue à chaque lecture : une page en faisait un
 * aller-retour d'auth avant sa première requête utile, et l'app en fait une par écran
 * ouvert. La signature, elle, n'est pas oubliée - voir `currentUser()`.
 */
const sessionSnapshot = cache(async (): Promise<{ user: SessionUser; token: string } | null> => {
  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.access_token) return null;

  // **La signature est vérifiée, et il faut qu'elle le soit.** L'`id` sert de clé au cache
  // de Next : un jeton bricolé qui porterait le `sub` de quelqu'un d'autre lirait son
  // entrée de cache, et le cloisonnement de Postgres n'aurait rien à dire - la requête
  // n'aurait pas lieu. `getClaims()` fait ce contrôle **sur place** quand le projet signe
  // en asymétrique (clé publique, gardée en mémoire), et retombe sur `getUser()` sinon :
  // au pire on retrouve l'appel d'avant, au mieux il disparaît.
  const { data, error } = await supabase.auth.getClaims(session.access_token);
  const claims = data?.claims;
  if (error || !claims?.sub) return null;

  return {
    user: {
      id: claims.sub,
      email: typeof claims.email === "string" ? claims.email : null,
    },
    token: session.access_token,
  };
});

export const currentUser = cache(async (): Promise<SessionUser | null> => {
  const snapshot = await sessionSnapshot();
  return snapshot?.user ?? null;
});

export const currentUserId = cache(async (): Promise<string | null> => {
  const snapshot = await sessionSnapshot();
  return snapshot?.user.id ?? null;
});

/**
 * Le jeton, pour les lectures mises en cache hors du cookie.
 *
 * `unstable_cache` n'a pas le droit d'appeler `cookies()`. On passe donc le JWT en
 * en-tête, et on ne le met **pas** dans la clé de cache : il ne sert qu'au miss.
 */
export const currentAccessToken = cache(async (): Promise<string | null> => {
  const snapshot = await sessionSnapshot();
  return snapshot?.token ?? null;
});
