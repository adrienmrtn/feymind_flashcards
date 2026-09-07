import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

import { ONBOARDING_REPLAY_COOKIE } from "@/lib/auth/onboarding-replay";
import { PRODUCTION_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";
import { UI_LOCALE_COOKIE, type UiLocale } from "@/lib/i18n/locales";
import { LOCALE_HEADER, resolveLocaleRequest } from "@/lib/i18n/paths";

/**
 * Cinq choses, dans cet ordre :
 *
 * 1. Un aperçu renvoie au site.
 * 2. Un `?code=` (ou un jeton de mail) est renvoyé au callback.
 * 3. **La langue de l'URL.** `/tr/methode` se réécrit en `/methode` et pose
 *    `x-micabo-locale: tr`. `/methode` pose `fr`. Cookie et navigateur ne
 *    changent pas une page indexable. `/fr/…` redirige vers la version nue.
 *    `/tr/app` redirige vers `/app` en posant le cookie : l'app n'a pas de
 *    préfixe.
 * 4. La session se rafraîchit.
 * 5. Une session ouverte n'a plus rien à faire sur le parcours.
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

  const locale = resolveLocaleRequest(url.pathname);
  if (locale.action === "redirect") {
    const target = url.clone();
    target.pathname = locale.location;
    const redirect = NextResponse.redirect(target, locale.status);
    if (locale.setCookie) writeLocaleCookie(redirect, locale.setCookie);
    return redirect;
  }

  const requestHeaders = new Headers(request.headers);
  if (locale.urlLocale) {
    requestHeaders.set(LOCALE_HEADER, locale.urlLocale);
  }

  const rewriteUrl = url.clone();
  rewriteUrl.pathname = locale.pathname;
  const mustRewrite = locale.pathname !== url.pathname;

  const passthrough = () => {
    const nextRequest = { headers: requestHeaders };
    const response = mustRewrite
      ? NextResponse.rewrite(rewriteUrl, { request: nextRequest })
      : NextResponse.next({ request: nextRequest });
    if (locale.setCookie) writeLocaleCookie(response, locale.setCookie);
    return response;
  };

  let response = passthrough();

  const supabase = createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(items) {
        for (const { name, value } of items) {
          request.cookies.set(name, value);
        }
        response = passthrough();
        for (const { name, value, options } of items) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  const {
    data: { session },
  } = await supabase.auth.getSession();

  const replaying = request.cookies.get(ONBOARDING_REPLAY_COOKIE)?.value === "1";
  if (session && !replaying && locale.pathname.startsWith("/commencer")) {
    const redirect = NextResponse.redirect(new URL("/app", request.url));
    for (const cookie of response.cookies.getAll()) {
      redirect.cookies.set(cookie);
    }
    return redirect;
  }

  return response;
}

function writeLocaleCookie(response: NextResponse, locale: UiLocale) {
  response.cookies.set(UI_LOCALE_COOKIE, locale, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|google[^/]+\\.html|.*\\.(?:svg|png|jpg|jpeg|gif|webp|woff2?)$).*)",
  ],
};
