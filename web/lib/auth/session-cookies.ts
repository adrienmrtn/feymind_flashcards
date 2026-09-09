import type { NextRequest, NextResponse } from "next/server";

/**
 * **Effacer une session que GoTrue a déjà oubliée.**
 *
 * Un jeton de rafraîchissement périmé ne s'use pas : il repart à chaque requête. Et une page
 * de l'app en fait plusieurs à la fois — le document, les vols RSC, les routes. Le 8 septembre
 * 2026, ça a donné dix-huit `refresh_token_not_found` en deux instants, depuis deux adresses :
 * pas dix-huit personnes déconnectées, deux rechargements dont chaque requête rejouait le même
 * jeton mort.
 *
 * `@supabase/ssr` expire bien le cookie de son côté, mais il le fait depuis un abonné
 * `onAuthStateChange` que le middleware ne peut pas attendre : la réponse est parfois déjà
 * partie. On le fait donc aussi ici, explicitement, sur la réponse qu'on rend.
 *
 * C'est le rôle de ce module, et il ne fait que ça : il ne décide pas de déconnecter, il
 * constate qu'il n'y a plus rien à garder.
 */

/** Les cookies de session posés par `@supabase/ssr`, dont les morceaux d'un jeton découpé. */
const AUTH_COOKIE = /^sb-.+-auth-token(\.\d+)?$/;

/**
 * Vrai quand le refus est définitif, et faux quand il peut ne pas l'être.
 *
 * Un `status` absent, c'est une panne de réseau ou un GoTrue injoignable : effacer la session
 * pour ça déconnecterait quelqu'un à cause d'une coupure de trois secondes. Un 5xx dit la même
 * chose. Seul un refus dans les 4xx dit que ce jeton-là ne vaudra jamais plus rien.
 */
export function sessionIsGone(error: { status?: number } | null): boolean {
  const status = error?.status;
  return typeof status === "number" && status >= 400 && status < 500;
}

/** Expire les cookies de session sur la réponse. Rend le nombre de cookies effacés. */
export function expireSessionCookies(request: NextRequest, response: NextResponse): number {
  let cleared = 0;
  for (const cookie of request.cookies.getAll()) {
    if (!AUTH_COOKIE.test(cookie.name)) continue;
    response.cookies.set(cookie.name, "", { path: "/", maxAge: 0 });
    cleared += 1;
  }
  return cleared;
}
