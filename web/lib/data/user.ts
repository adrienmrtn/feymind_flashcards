import { cache } from "react";

import { userFromToken, type SessionUser } from "@/lib/auth/claims";
import { createClient } from "@/lib/supabase/server";

export type { SessionUser } from "@/lib/auth/claims";

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
 * ouvert. La signature, elle, n'est pas oubliée : voir `userFromToken`.
 */
const sessionSnapshot = cache(async (): Promise<{ user: SessionUser; token: string } | null> => {
  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.access_token) return null;

  const user = await userFromToken(
    {
      getClaims: (token) => supabase.auth.getClaims(token),
      getUser: (token) => supabase.auth.getUser(token),
    },
    session.access_token,
  );
  if (!user) return null;

  return { user, token: session.access_token };
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
