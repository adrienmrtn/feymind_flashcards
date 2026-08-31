import { createServerClient } from "@supabase/ssr";
import { type EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

import { oauthFailureMessage } from "@/lib/auth/oauth";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/config";

/**
 * Le retour d'un fournisseur ou d'un lien de courriel.
 *
 * Les cookies de session sont écrits **sur la redirection**, pas via `cookies()`
 * de Next : un `NextResponse.redirect` tout neuf les perdait, `getUser()`
 * suivant voyait personne, et on renvoyait au pays.
 *
 * Après un échange réussi, on ouvre l'app. **Supabase est le compte.** On ne
 * tranche plus « session GoTrue / compte Micabo » : c'est ce tri qui recréait
 * un parcours, puis un profil, pour une adresse déjà authentifiée.
 */
export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type");
  const next = appNext(url.searchParams.get("next"));

  if (!code && !(tokenHash && type)) {
    const error = url.searchParams.get("error_description") ?? url.searchParams.get("error");
    const detail = oauthFailureMessage("apple", error ?? "manquant");
    return NextResponse.redirect(
      new URL(`/commencer/compte?erreur=${encodeURIComponent(detail)}`, url.origin),
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

  return redirectTo;
}

function appNext(value: string | null): string {
  if (
    value &&
    value.startsWith("/app") &&
    !value.startsWith("//") &&
    !value.includes("\\") &&
    !value.includes("@")
  ) {
    return value;
  }
  return "/app";
}
