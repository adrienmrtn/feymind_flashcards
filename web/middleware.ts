import { type NextRequest, NextResponse } from "next/server";

import { createServerClient } from "@supabase/ssr";

import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Le rafraîchissement de la session, au passage.
 *
 * Un composant serveur ne peut pas écrire de cookie : seules une route et une action le peuvent.
 * Sans ce passage, un jeton expiré resterait expiré et l'étudiant serait déconnecté au bout d'une
 * heure sans avoir rien fait. C'est le seul endroit du site qui rafraîchit, et c'est exactement le
 * pendant de `AuthController.validAccessToken()` côté iOS — personne d'autre n'a à savoir qu'un
 * jeton expire.
 *
 * `getUser()` et non `getSession()` : le second lit le cookie et le croit, le premier le fait
 * vérifier par le serveur. Sur une page rendue côté serveur, c'est la différence entre une session
 * et une session **prouvée**.
 */
export async function middleware(request: NextRequest) {
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

  await supabase.auth.getUser();

  return response;
}

export const config = {
  matcher: [
    // Tout sauf les fichiers statiques et les images : rafraîchir une session pour servir une
    // police est une requête de plus pour rien.
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|woff2?)$).*)",
  ],
};
