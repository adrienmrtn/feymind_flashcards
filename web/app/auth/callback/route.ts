import { type EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

import { resumePath } from "@/lib/auth/resume";
import { createClient } from "@/lib/supabase/server";

/**
 * Le retour d'un fournisseur ou d'un lien de courriel.
 *
 * C'est ici que le code PKCE (ou le jeton du mail) s'échange contre une session.
 * Après ça, on reprend le parcours — jamais la landing.
 */
export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type");
  const next = safeNext(url.searchParams.get("next"));

  const supabase = await createClient();

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      return NextResponse.redirect(
        new URL(`/commencer/compte?erreur=${encodeURIComponent(error.message)}`, url.origin),
      );
    }
  } else if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({
      type: type as EmailOtpType,
      token_hash: tokenHash,
    });
    if (error) {
      return NextResponse.redirect(
        new URL(`/commencer/compte?erreur=${encodeURIComponent(error.message)}`, url.origin),
      );
    }
  } else {
    const error = url.searchParams.get("error_description") ?? url.searchParams.get("error");
    return NextResponse.redirect(
      new URL(`/commencer/compte?erreur=${encodeURIComponent(error ?? "manquant")}`, url.origin),
    );
  }

  const destination = next === "/commencer/compte" || next === "/commencer" ? await resumePath() : next;
  return NextResponse.redirect(new URL(destination, url.origin));
}

function safeNext(value: string | null): string {
  if (!value || value === "/" || !value.startsWith("/") || value.startsWith("//")) {
    return "/commencer/pays";
  }
  return value;
}
