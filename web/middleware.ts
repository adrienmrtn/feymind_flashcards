import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

import { ONBOARDING_REPLAY_COOKIE } from "@/lib/auth/onboarding-replay";
import { PRODUCTION_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Quatre choses, dans cet ordre :
 *
 * 1. Un aperçu renvoie au site. Une adresse `micabo-git-<branche>-…` reste
 *    servie longtemps après la fusion de sa branche **et reste figée sur son
 *    commit** : un onglet gardé dessus montre le produit d'avant, refus de
 *    rechargement forcé compris. On a perdu une soirée à croire que des
 *    correctifs ne passaient pas alors qu'ils étaient en ligne depuis des
 *    heures. Un aperçu n'est donc plus consultable : il redirige.
 * 2. Un `?code=` (ou un jeton de mail) tombé sur n'importe quelle page - la
 *    Site URL de Supabase, un ancien `/commencer/pays` - est renvoyé au
 *    callback. Sinon le code expire sur le premier écran du parcours.
 * 3. La session se rafraîchit, et les cookies voyagent avec la réponse.
 * 4. Une session ouverte n'a plus rien à faire sur le parcours : on ouvre
 *    l'app. Sauf si on rejoue l'accueil exprès (cookie posé depuis le profil).
 *    La landing reste visible - le bouton dit alors Dashboard.
 *
 * **Le point 3 se lisait `getUser()`, et c'était le péage de chaque clic.**
 * `getUser()` interroge GoTrue par le réseau, *à chaque fois*, et ce middleware
 * tourne sur chaque navigation - y compris les requêtes RSC d'un simple
 * changement d'onglet. Le rendu de la page n'attendait donc pas la base : il
 * attendait d'abord un aller-retour d'auth qui ne rapportait rien de neuf.
 * `getSession()` lit le cookie sur place et ne part sur le réseau que dans les
 * quatre-vingt-dix dernières secondes du jeton, c'est-à-dire une fois par
 * heure au lieu d'une fois par écran.
 *
 * Ce qu'on perd est nommable : le jeton n'est plus *vérifié* ici. C'est sans
 * effet, parce que rien de ce que fait ce fichier n'expose de donnée - il
 * redirige, et il repose des cookies. L'identité, elle, est établie une fois
 * par requête dans `currentUser()`, signature comprise, et chaque lecture
 * repasse ensuite par le cloisonnement de Postgres.
 */
export async function middleware(request: NextRequest) {
  const url = request.nextUrl;

  if (process.env.VERCEL_ENV === "preview") {
    const site = new URL(PRODUCTION_URL);
    site.pathname = url.pathname;
    site.search = url.search;
    return NextResponse.redirect(site);
  }

  if (url.pathname !== "/auth/callback") {
    const code = url.searchParams.get("code");
    const tokenHash = url.searchParams.get("token_hash");
    if (code || tokenHash) {
      const callback = url.clone();
      callback.pathname = "/auth/callback";
      const next = callback.searchParams.get("next");
      if (!next || next.startsWith("/commencer") || next === "/") {
        callback.searchParams.set("next", "/app");
      }
      return NextResponse.redirect(callback);
    }
  }

  let response = NextResponse.next({ request });

  const supabase = createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(items) {
        for (const { name, value } of items) {
          request.cookies.set(name, value);
        }
        response = NextResponse.next({ request });
        for (const { name, value, options } of items) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  const {
    data: { session },
  } = await supabase.auth.getSession();

  const path = url.pathname;
  const replaying = request.cookies.get(ONBOARDING_REPLAY_COOKIE)?.value === "1";
  if (session && !replaying && path.startsWith("/commencer")) {
    const redirect = NextResponse.redirect(new URL("/app", request.url));
    for (const cookie of response.cookies.getAll()) {
      redirect.cookies.set(cookie);
    }
    return redirect;
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|woff2?)$).*)",
  ],
};
