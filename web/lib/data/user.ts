import { cache } from "react";

import { createClient } from "@/lib/supabase/server";

/**
 * L'utilisateur de **cette** requête, et une seule fois.
 *
 * `getUser()` parle à GoTrue. Sans mémo, chaque lecture (cours, cartes, examens, droit)
 * le rappelait : une page d'accueil faisait huit allers-retours d'auth avant d'afficher
 * quoi que ce soit. Le layout, la page et les helpers partagent maintenant le même
 * résultat - le cloisonnement ne change pas, seul le bruit disparaît.
 */
export const currentUser = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
});

export const currentUserId = cache(async () => {
  const user = await currentUser();
  return user?.id ?? null;
});

/**
 * Le jeton, pour les lectures mises en cache hors du cookie.
 *
 * `unstable_cache` n'a pas le droit d'appeler `cookies()`. On passe donc le JWT en
 * en-tête, et on ne le met **pas** dans la clé de cache : il ne sert qu'au miss.
 */
export const currentAccessToken = cache(async () => {
  const supabase = await createClient();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  return session?.access_token ?? null;
});
