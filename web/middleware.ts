import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

import { verifyAccessToken } from "@/lib/auth/claims";
import { isOfferPath, onboardingGate, onboardingNeedsVerdict } from "@/lib/auth/onboarding-gate";
import { ONBOARDING_REPLAY_COOKIE } from "@/lib/auth/onboarding-replay";
import { expireCookies, sessionCookieNames, sessionIsGone } from "@/lib/auth/session-cookies";
import { PRODUCTION_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";
import { UI_LOCALE_COOKIE, type UiLocale } from "@/lib/i18n/locales";
import { LOCALE_HEADER, forwardedUrlLocale, resolveLocaleRequest } from "@/lib/i18n/paths";

/**
 * Cinq choses, dans cet ordre :
 *
 * 1. Un aperçu renvoie au site.
 * 2. Un `?code=` (ou un jeton de mail) est renvoyé au callback.
 * 3. **La langue de l'URL.** `/tr/methode` se réécrit en `/methode` et pose
 *    `x-micabo-locale: tr`. `/methode` pose `en`. Cookie et navigateur ne
 *    changent pas une page indexable. `/en/…` redirige vers la version nue.
 *    `/tr/app` redirige vers `/app` en posant le cookie : l'app n'a pas de
 *    préfixe. La réécriture relance le middleware sur le chemin nu : on
 *    garde le header de la première passe, sinon `/` écraserait `/fr`.
 * 4. La session se rafraîchit, ou s'efface quand GoTrue l'a oubliée.
 * 5. Une session ouverte **et vérifiée** n'a plus rien à faire sur le parcours - sauf sur
 *    l'offre (`/commencer/offre`), qui vient justement après le compte. Vérifiée, parce que
 *    `/app` vérifie : voir `lib/auth/onboarding-gate`.
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
      if (!next || (next.startsWith("/commencer") && !isOfferPath(next)) || next === "/") {
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

  const urlLocale = forwardedUrlLocale(request.headers.get(LOCALE_HEADER), locale.urlLocale);

  const rewriteUrl = url.clone();
  rewriteUrl.pathname = locale.pathname;
  const mustRewrite = locale.pathname !== url.pathname;

  /**
   * Les en-têtes transmis aux composants serveur, **relus à chaque appel**.
   *
   * Ils étaient copiés une fois, avant le rafraîchissement de la session. `setAll` écrivait
   * bien le nouveau jeton dans `request.cookies` - donc dans `request.headers` -, mais la copie,
   * elle, gardait l'ancien `cookie:` : les composants serveur relisaient un jeton expiré, le
   * rafraîchissaient une seconde fois avec un jeton de rafraîchissement déjà consommé, et
   * concluaient à « personne ». Le navigateur avait pourtant reçu la bonne session.
   */
  const forwardedHeaders = () => {
    const headers = new Headers(request.headers);
    if (urlLocale) headers.set(LOCALE_HEADER, urlLocale);
    return headers;
  };

  const passthrough = () => {
    const nextRequest = { headers: forwardedHeaders() };
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

  const { data: { session }, error } = await supabase.auth.getSession();

  /**
   * Oublier la session : sur la réponse (le navigateur efface ses cookies) **et** sur la requête
   * transmise (la page rendue derrière ne relit pas ce qu'on vient d'effacer).
   */
  const forgetSession = () => {
    const stale = sessionCookieNames(request);
    for (const name of stale) request.cookies.delete(name);
    const carried = response.cookies.getAll();
    response = passthrough();
    for (const cookie of carried) response.cookies.set(cookie);
    expireCookies(response, stale);
  };

  // Un jeton de rafraîchissement que GoTrue a oublié revient à chaque requête de la page tant
  // que le cookie est là. On l'expire donc ici : voir `lib/auth/session-cookies`.
  if (!session && sessionIsGone(error)) {
    forgetSession();
  }

  const replaying = request.cookies.get(ONBOARDING_REPLAY_COOKIE)?.value === "1";
  const visit = { pathname: locale.pathname, replaying, hasSession: Boolean(session) };
  const verdict =
    session && onboardingNeedsVerdict(visit)
      ? await verifyAccessToken(supabase.auth, session.access_token)
      : null;

  const gate = onboardingGate({ ...visit, verdict });
  if (gate === "forget") {
    // Le cookie a une session que Supabase refuse : `/app` ne la laissera pas entrer, donc
    // y renvoyer ferait la boucle. On l'efface, et la page de connexion s'affiche.
    forgetSession();
  }
  if (gate === "app") {
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
