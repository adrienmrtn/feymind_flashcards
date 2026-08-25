import { cookies } from "next/headers";

import { createServerClient } from "@supabase/ssr";

import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Le client Supabase du serveur : composants serveur, routes, actions.
 *
 * Il porte **le jeton de l'utilisateur**, lu dans le cookie, et jamais la clé anonyme seule.
 * C'est ce qui fait fonctionner le cloisonnement : `auth.uid()` est lu depuis le jeton, donc
 * le site n'a aucun moyen de demander les cours de quelqu'un d'autre, même en trafiquant sa
 * requête. La leçon déjà écrite côté iOS vaut ici mot pour mot — **une requête qui compte sur
 * le cloisonnement pour ne pas ramasser les lignes des autres est une requête qu'une politique
 * ajoutée un jour recasse** : chaque lecture porte son filtre `user_id`, y compris sur une
 * table qui n'a qu'une seule politique.
 */
export async function createClient() {
  const store = await cookies();

  return createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return store.getAll();
      },
      setAll(items) {
        try {
          for (const { name, value, options } of items) {
            store.set(name, value, options);
          }
        } catch {
          // Un composant serveur ne peut pas écrire de cookie : seules une route et une action
          // le peuvent. Le rafraîchissement de session s'y fait donc, et l'ignorer ici est
          // correct plutôt que résigné — le middleware s'en charge au passage suivant.
        }
      },
    },
  });
}
