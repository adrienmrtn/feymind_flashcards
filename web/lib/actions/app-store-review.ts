"use server";

import { APP_STORE_REVIEW_EMAIL, isAppStoreReviewEmail } from "@/lib/auth/app-store-review";
import { actionT } from "@/lib/i18n/action";
import { createClient } from "@/lib/supabase/server";

export type ReviewSignInResult = { status: "ok" } | { status: "error"; message: string };

/**
 * **Ouvrir la session de relecture d'Apple, côté serveur.**
 *
 * Le mot de passe est lu dans `APP_STORE_REVIEW_PASSWORD`, une variable sans préfixe
 * `NEXT_PUBLIC_` : Next ne la met jamais dans le paquet du navigateur. La connexion se fait
 * avec le client Supabase du serveur, qui écrit les cookies de session sur la réponse de
 * l'action - le navigateur repart donc connecté sans avoir jamais vu le secret.
 *
 * Variable absente : le chemin de relecture est **fermé**, pas ouvert par défaut. Mieux vaut
 * un relecteur qui demande de l'aide qu'un compte partagé ouvert par une configuration oubliée.
 *
 * L'adresse est revérifiée ici : une action serveur est une route publique, et le client qui
 * l'appelle n'est pas forcément notre page.
 */
export async function signInForAppStoreReview(email: string): Promise<ReviewSignInResult> {
  if (!isAppStoreReviewEmail(email)) {
    return { status: "error", message: await actionT("onboarding.emailUndeliverable") };
  }

  const password = process.env.APP_STORE_REVIEW_PASSWORD?.trim();
  if (!password) {
    return { status: "error", message: await actionT("app.errors.reviewSignInUnavailable") };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: APP_STORE_REVIEW_EMAIL,
    password,
  });
  if (error) {
    // Le détail reste dans les journaux : le message de GoTrue n'apprend rien au relecteur,
    // et il en apprendrait un peu trop à quelqu'un qui essaie des mots de passe.
    console.error("app-store-review.sign-in", error.status, error.code);
    return { status: "error", message: await actionT("app.errors.reviewSignInUnavailable") };
  }

  return { status: "ok" };
}
