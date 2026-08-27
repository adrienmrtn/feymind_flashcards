import { createServerClient } from "@supabase/ssr";
import { type EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

import { hasExistingMicaboAccount } from "@/lib/auth/existing-account";
import { ONBOARDING_CREATE_COOKIE } from "@/lib/auth/onboarding-create";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Le retour d'un fournisseur ou d'un lien de courriel.
 *
 * Les cookies de session sont écrits **sur la redirection**, pas via `cookies()`
 * de Next : un `NextResponse.redirect` tout neuf les perdait, `getUser()`
 * suivant voyait personne, et on renvoyait au pays.
 *
 * Après un échange réussi on entre dans l'app, sauf une connexion
 * (`intent=login`) dont le compte Micabo n'existe pas encore : on ouvre
 * alors le parcours pour le créer.
 */
export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type");
  const next = appNext(url.searchParams.get("next"));
  const login = url.searchParams.get("intent") === "login";

  if (!code && !(tokenHash && type)) {
    const error = url.searchParams.get("error_description") ?? url.searchParams.get("error");
    return NextResponse.redirect(
      new URL(`/commencer/compte?erreur=${encodeURIComponent(error ?? "manquant")}`, url.origin),
    );
  }

  const redirectTo = NextResponse.redirect(new URL(next, url.origin));

  const supabase = createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(items) {
        for (const { name, value, options } of items) {
          redirectTo.cookies.set(name, value, options);
        }
      },
    },
  });

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      return NextResponse.redirect(
        new URL(`/commencer/compte?erreur=${encodeURIComponent(error.message)}`, url.origin),
      );
    }
  } else {
    const { error } = await supabase.auth.verifyOtp({
      type: type as EmailOtpType,
      token_hash: tokenHash!,
    });
    if (error) {
      return NextResponse.redirect(
        new URL(`/commencer/compte?erreur=${encodeURIComponent(error.message)}`, url.origin),
      );
    }
  }

  if (login) {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user && !(await hasExistingMicaboAccount(supabase, user.id))) {
      const create = NextResponse.redirect(new URL("/commencer/pays?inconnu=1", url.origin));
      for (const cookie of redirectTo.cookies.getAll()) {
        create.cookies.set(cookie);
      }
      create.cookies.set(ONBOARDING_CREATE_COOKIE, "1", {
        path: "/",
        httpOnly: true,
        sameSite: "lax",
        maxAge: 60 * 60 * 24,
      });
      return create;
    }
  }

  return redirectTo;
}

function appNext(value: string | null): string {
  if (value && value.startsWith("/app") && !value.startsWith("//")) return value;
  return "/app";
}
