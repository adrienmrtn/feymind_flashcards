import { NextResponse, type NextRequest } from "next/server";

import { createClient } from "@/lib/supabase/server";

/**
 * Le retour d'un fournisseur, et le seul endroit où la session s'ouvre.
 *
 * C'est ici que le code PKCE s'échange contre une session, et que le cookie est posé — dans une
 * route, parce qu'un composant serveur ne peut pas écrire de cookie. Le jeton de rafraîchissement
 * ne passe donc jamais par du JavaScript de page : c'est la même exigence que le trousseau côté
 * iOS, avec les moyens du web.
 *
 * `next` dit où reprendre le parcours. Il est **vérifié** avant d'être suivi : un paramètre de
 * redirection qu'on suit sans le lire est une redirection ouverte, et c'est le moyen le plus simple
 * de transformer une page de connexion en tremplin vers un site d'hameçonnage.
 */
export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = safeNext(url.searchParams.get("next"));

  if (!code) {
    const error = url.searchParams.get("error_description") ?? url.searchParams.get("error");
    return NextResponse.redirect(
      new URL(`/commencer/compte?erreur=${encodeURIComponent(error ?? "manquant")}`, url.origin),
    );
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(
      new URL(`/commencer/compte?erreur=${encodeURIComponent(error.message)}`, url.origin),
    );
  }

  return NextResponse.redirect(new URL(next, url.origin));
}

/**
 * Une destination interne, ou rien.
 *
 * On n'accepte qu'un chemin absolu du site — pas d'URL complète, pas de `//`, qui est un chemin
 * relatif au protocole et mène ailleurs.
 */
function safeNext(value: string | null): string {
  if (!value || !value.startsWith("/") || value.startsWith("//")) return "/commencer/pays";
  return value;
}
