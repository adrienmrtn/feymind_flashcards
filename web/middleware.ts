import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Trois choses, dans cet ordre :
 *
 * 1. Un `?code=` (ou un jeton de mail) tombé sur n'importe quelle page — la
 *    Site URL de Supabase, un ancien `/commencer/pays` — est renvoyé au
 *    callback. Sinon le code expire sur le premier écran du parcours.
 * 2. La session se rafraîchit, et les cookies voyagent avec la réponse.
 * 3. Une session ouverte n'a plus rien à faire sur le parcours ni sur la
 *    landing : on ouvre l'app.
 */
export async function middleware(request: NextRequest) {
  const url = request.nextUrl;

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
    data: { user },
  } = await supabase.auth.getUser();

  const path = url.pathname;
  if (
    user &&
    (path === "/" || (path.startsWith("/commencer") && path !== "/commencer/compte"))
  ) {
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
